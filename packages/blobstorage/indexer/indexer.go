package indexer

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/ethclient"
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/bindings/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/repo"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
	"golang.org/x/sync/errgroup"
)

type Response struct {
	Data []struct {
		Index            string `json:"index"`
		Blob             string `json:"blob"`
		KzgCommitment    string `json:"kzg_commitment"`
		KzgCommitmentHex []byte `json:"-"`
	} `json:"data"`
}

// Indexer struct holds the configuration and state for the Ethereum chain listener.
type Indexer struct {
	beaconURL                string
	ethClient                *ethclient.Client
	startHeight              *uint64
	taikoL1                  *taikol1.TaikoL1
	db                       DB
	blobHashRepo             blobstorage.BlobHashRepository
	cfg                      *Config
	wg                       *sync.WaitGroup
	ctx                      context.Context
	latestIndexedBlockNumber uint64
}

func (i *Indexer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, i, cfg)
}

// InitFromConfig inits a new Indexer from a provided Config struct
func InitFromConfig(ctx context.Context, i *Indexer, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	blobHashRepo, err := repo.NewBlobHashRepository(db)
	if err != nil {
		return err
	}

	client, err := ethclient.Dial(cfg.RPCURL)
	if err != nil {
		return err
	}

	taikoL1, err := taikol1.NewTaikoL1(cfg.ContractAddress, client)
	if err != nil {
		return err
	}

	i.blobHashRepo = blobHashRepo
	i.ethClient = client
	i.beaconURL = cfg.BeaconURL
	i.taikoL1 = taikoL1
	i.startHeight = cfg.StartingBlockID
	i.db = db
	i.wg = &sync.WaitGroup{}
	i.ctx = ctx
	i.cfg = cfg

	return nil
}

func (i *Indexer) Start() error {
	i.wg.Add(1)

	go i.eventLoop(i.ctx, i.latestIndexedBlockNumber)

	return nil
}

// eventLoop runs on an interval ticker, every N seconds we will check
// the latest processed block, and the latest header, and filter every block in between
// for BlockProposed events, if we are not already filtering. This lets us avoid
// unreliable subscription issues.
func (i *Indexer) eventLoop(ctx context.Context, startBlockID uint64) error {
	defer func() {
		i.wg.Done()
	}()

	t := time.NewTicker(10 * time.Second)
	defer t.Stop()

	var filtering bool = false

	for {
		select {
		case <-ctx.Done():
			slog.Info("event loop context done")
			return nil
		case <-t.C:
			func() {
				defer func() {
					filtering = false
				}()
			}()

			if filtering {
				continue
			}

			filtering = true

			if err := i.withRetry(func() error { return i.filter(ctx) }); err != nil {
				return err
			}
		}
	}
}

// withRetry retries the given function with prover backoff policy.
func (i *Indexer) withRetry(f func() error) error {
	return backoff.Retry(
		func() error {
			if i.ctx.Err() != nil {
				slog.Error("Context is done, aborting", "error", i.ctx.Err())
				return nil
			}
			return f()
		},
		backoff.WithMaxRetries(backoff.NewConstantBackOff(i.cfg.BackOffRetryInterval), i.cfg.BackOffMaxRetries),
	)
}

func (i *Indexer) filter(ctx context.Context) error {
	n, err := i.blobHashRepo.FindLatestBlockID()
	if err != nil {
		return err
	}

	i.latestIndexedBlockNumber = n

	// get the latest header
	header, err := i.ethClient.HeaderByNumber(i.ctx, nil)
	if err != nil {
		return err
	}

	// the end block is the latest header.
	endBlockID := header.Number.Uint64()

	var defaultBlockBatchSize uint64 = 50

	slog.Info("fetching batch block events",
		"latestIndexBlockNumber", i.latestIndexedBlockNumber,
		"endblock", endBlockID,
		"batchsize", defaultBlockBatchSize,
	)

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += defaultBlockBatchSize {
		end := j + uint64(defaultBlockBatchSize)
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > endBlockID {
			end = endBlockID
		}

		slog.Info("block batch", "start", j, "end", end)

		opts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: i.ctx,
		}

		group, groupCtx := errgroup.WithContext(i.ctx)

		events, err := i.taikoL1.FilterBlockProposed(opts, nil, nil)
		if err != nil {
			return err
		}

		first := true

		for events.Next() {
			event := events.Event
			if first {
				first = false
				if err := i.checkReorg(ctx, event); err != nil {
					return err
				}
			}

			group.Go(func() error {
				if err := i.withRetry(func() error { return i.filter(groupCtx) }); err != nil {
					return err
				}

				return nil
			})
		}

		// wait for the last of the goroutines to finish
		if err := group.Wait(); err != nil {
			return err
		}

		i.latestIndexedBlockNumber = end
	}

	return nil
}

func (i *Indexer) Close(ctx context.Context) {
	i.wg.Wait()
}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) getBlockTimestamp(rpcURL string, blockNumber *big.Int) (uint64, error) {
	block, err := i.ethClient.BlockByNumber(context.Background(), blockNumber)
	if err != nil {
		return 0, err
	}

	return block.Time(), nil
}

func calculateBlobHash(commitmentStr string) string {
	// As per: https://eips.ethereum.org/EIPS/eip-4844
	c := common.FromHex(commitmentStr)

	var b [48]byte

	copy(b[:], c)

	commitment := kzg4844.Commitment(b)

	blobHash := kzg4844.CalcBlobHashV1(
		sha256.New(),
		&commitment,
	)

	blobHashString := hex.EncodeToString(blobHash[:])

	return blobHashString
}

func (i *Indexer) checkReorg(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	n, err := i.blobHashRepo.FindLatestBlockID()
	if err != nil {
		return err
	}

	if n >= event.Raw.BlockNumber {
		slog.Info("reorg detected", "event emitted in", event.Raw.BlockNumber, "latest emitted block id from db", n)
		// reorg detected, we have seen a higher block number than this already.
		return i.blobHashRepo.DeleteAllAfterBlockID(event.Raw.BlockNumber)
	}

	return nil
}

func (i *Indexer) storeBlob(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	slog.Info("blockProposed event found", "blockID", event.Meta.L1Height+1, "emittedIn", event.Raw.BlockNumber, "blobUsed", event.Meta.BlobUsed)

	if !event.Meta.BlobUsed {
		return nil
	}

	blockID := event.Meta.L1Height + 1
	url := fmt.Sprintf("%s/%v", i.beaconURL, blockID)
	response, err := http.Get(url)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return err
	}

	var responseData Response
	if err := json.Unmarshal(body, &responseData); err != nil {
		return err
	}

	for _, data := range responseData.Data {
		data.KzgCommitmentHex, err = hex.DecodeString(data.KzgCommitment[2:])
		if err != nil {
			return err
		}

		metaBlobHash := hex.EncodeToString(event.Meta.BlobHash[:])
		// Comparing the hex strings of meta.blobHash (blobHash)
		if calculateBlobHash(data.KzgCommitment) == metaBlobHash {
			blockTs, err := i.getBlockTimestamp(i.cfg.RPCURL, new(big.Int).SetUint64(blockID))
			if err != nil {
				slog.Info("error getting block timestamp", "error", err)
				return err
			}

			slog.Info("blockHash", "blobHash", fmt.Sprintf("%v%v", "0x", metaBlobHash))

			err = i.storeBlobInDB(fmt.Sprintf("%v%v", "0x", metaBlobHash), data.KzgCommitment, data.Blob, blockTs, event.BlockId.Uint64(), event.Raw.BlockNumber)
			if err != nil {
				slog.Error("Error storing blob in MongoDB", "error", err)
				return err
			}

			return nil
		}
	}

	return errors.New("BLOB not found")
}

func (i *Indexer) storeBlobInDB(blobHashInMeta, kzgCommitment, blob string, blockTs uint64, blockID uint64, emittedBlockID uint64) error {
	return i.blobHashRepo.Save(blobstorage.SaveBlobHashOpts{
		BlobHash:       blobHashInMeta,
		KzgCommitment:  kzgCommitment,
		BlockID:        blockID,
		BlobData:       blob,
		BlockTimestamp: blockTs,
		EmittedBlockID: emittedBlockID,
	})
}
