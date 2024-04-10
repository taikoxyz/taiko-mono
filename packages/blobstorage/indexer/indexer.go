package indexer

import (
	"context"
	"crypto/sha256"
	"errors"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/bindings/taikol1"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/repo"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/utils"
)

// Indexer struct holds the configuration and state for the Ethereum chain listener.
type Indexer struct {
	ethClient                *ethclient.Client
	startHeight              *uint64
	taikoL1                  *taikol1.TaikoL1
	db                       DB
	repositories             *repo.Repositories
	cfg                      *Config
	wg                       *sync.WaitGroup
	ctx                      context.Context
	latestIndexedBlockNumber uint64
	beaconClient             *BeaconClient
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

	repositories, err := repo.NewRepositories(db)
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

	l1BeaconClient, err := NewBeaconClient(cfg, utils.DefaultTimeout)
	if err != nil {
		return err
	}

	i.repositories = repositories
	i.ethClient = client
	i.taikoL1 = taikoL1
	i.startHeight = cfg.StartingBlockID
	i.db = db
	i.wg = &sync.WaitGroup{}
	i.ctx = ctx
	i.cfg = cfg

	i.beaconClient = l1BeaconClient

	return nil
}

func (i *Indexer) Start() error {
	if err := i.setInitialIndexingBlock(i.ctx); err != nil {
		return err
	}

	i.wg.Add(1)

	go i.eventLoop(i.ctx, i.latestIndexedBlockNumber)

	return nil
}

func (i *Indexer) setInitialIndexingBlock(
	ctx context.Context,
) error {
	// get most recently processed block height from the DB
	// latest, err := i.blobHashRepo.FindLatestBlockID()
	latest, err := i.repositories.BlockMetaRepo.FindLatestBlockID()
	// latest, err := i.blockMetaRepo.FindLatestBlockID()
	if err != nil {
		return err
	}

	// if its non-zero ,we use that. if it is zero, it means we havent
	// processed any blobs, so we should get the state variables below.
	if latest != 0 {
		i.latestIndexedBlockNumber = latest

		return nil
	}

	// and then start from the genesis height.
	slotA, _, err := i.taikoL1.GetStateVariables(nil)
	if err != nil {
		return err
	}

	i.latestIndexedBlockNumber = slotA.GenesisHeight - 1

	return nil
}

// eventLoop runs on an interval ticker, every N seconds we will check
// the latest processed block, and the latest header, and filter every block in between
// for BlockProposed events, if we are not already filtering. This lets us avoid
// unreliable subscription issues.
func (i *Indexer) eventLoop(ctx context.Context, startBlockID uint64) {
	defer i.wg.Done()

	t := time.NewTicker(10 * time.Second)
	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("event loop context done")
			return
		case <-t.C:
			if err := i.filter(ctx); err != nil {
				slog.Error("error filtering", "error", err)
				return
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
		backoff.WithContext(
			backoff.WithMaxRetries(backoff.NewConstantBackOff(i.cfg.BackOffRetryInterval), i.cfg.BackOffMaxRetries),
			i.ctx,
		),
	)
}

func (i *Indexer) filter(ctx context.Context) error {
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

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += defaultBlockBatchSize + 1 {
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		end := utils.Min(j+defaultBlockBatchSize, endBlockID)

		slog.Info("block batch", "start", j, "end", end)

		opts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: i.ctx,
		}

		group, _ := errgroup.WithContext(i.ctx)

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
				return i.withRetry(func() error { return i.storeBlob(ctx, event) })
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

func calculateBlobHash(commitmentStr string) common.Hash {
	// As per: https://eips.ethereum.org/EIPS/eip-4844
	c := common.FromHex(commitmentStr)

	var b [48]byte

	copy(b[:], c)

	commitment := kzg4844.Commitment(b)

	blobHash := kzg4844.CalcBlobHashV1(
		sha256.New(),
		&commitment,
	)

	return common.BytesToHash(blobHash[:])
}

func (i *Indexer) checkReorg(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	// n, err := i.blockMetaRepo.FindLatestBlockID()
	n, err := i.repositories.BlockMetaRepo.FindLatestBlockID()
	if err != nil {
		return err
	}

	if n >= event.Raw.BlockNumber {
		slog.Info("reorg detected", "event emitted in", event.Raw.BlockNumber, "latest emitted block id from db", n)
		// reorg detected, we have seen a higher block number than this already.
		return i.repositories.DeleteAllAfterBlockID(ctx, event.Raw.BlockNumber)
	}

	return nil
}

func (i *Indexer) storeBlob(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	slot, err := i.beaconClient.timeToSlot(event.Meta.Timestamp)
	if err != nil {
		return err
	}

	slog.Info("blockProposed event found",
		"slot", slot,
		"emittedIn", event.Raw.BlockNumber,
		"blobUsed", event.Meta.BlobUsed,
		"timesStamp", event.Meta.Timestamp,
	)

	if !event.Meta.BlobUsed {
		return nil
	}

	blobsResponse, err := i.beaconClient.getBlobs(ctx, slot)
	if err != nil {
		return err
	}

	for _, data := range blobsResponse.Data {
		data.KzgCommitmentHex = common.FromHex(data.KzgCommitment)

		metaBlobHash := common.BytesToHash(event.Meta.BlobHash[:])
		// Comparing the hex strings of meta.blobHash (blobHash)
		if calculateBlobHash(data.KzgCommitment) == metaBlobHash {
			saveBlockMetaOpts := &blobstorage.SaveBlockMetaOpts{
				BlobHash:       metaBlobHash.String(),
				BlockID:        event.BlockId.Uint64(),
				EmittedBlockID: event.Raw.BlockNumber,
			}
			saveBlobHashOpts := &blobstorage.SaveBlobHashOpts{
				BlobHash:      metaBlobHash.String(),
				KzgCommitment: data.KzgCommitment,
				BlobData:      data.Blob,
			}

			err := i.repositories.SaveBlobAndBlockMeta(ctx, saveBlockMetaOpts, saveBlobHashOpts)
			if err != nil {
				slog.Error("Error storing Blob and BlockMeta in DB", "error", err)
				return err
			}

			return nil
		}
	}

	return errors.New("BLOB not found")
}
