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

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/event"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/bindings/taikol1"
	mongodb "github.com/taikoxyz/taiko-mono/packages/blob-storage/pkg/db"
	"github.com/urfave/cli/v2"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
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
	beaconURL   string
	ethClient   *ethclient.Client
	startHeight *uint64
	taikoL1     *taikol1.TaikoL1
	db          *mongodb.MongoDBClient
	cfg         *Config
	wg          *sync.WaitGroup
	ctx         context.Context
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
	client, err := ethclient.Dial(cfg.RPCURL)
	if err != nil {
		return err
	}

	taikoL1, err := taikol1.NewTaikoL1(cfg.ContractAddress, client)
	if err != nil {
		return err
	}

	db, err := mongodb.NewMongoDBClient(mongodb.MongoDBConfig{
		Host:     cfg.DBHost,
		Port:     cfg.DBPort,
		Username: cfg.DBUsername,
		Password: cfg.DBPassword,
		Database: cfg.DBDatabase,
	})
	if err != nil {
		return err
	}

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

	var processingBlockHeight uint64

	if i.startHeight != nil {
		processingBlockHeight = *i.startHeight
	} else {
		n, err := i.getLatestBlockID()
		if err != nil {
			return err
		}

		processingBlockHeight = n
	}

	// get the latest header
	header, err := i.ethClient.HeaderByNumber(i.ctx, nil)
	if err != nil {
		return err
	}

	// the end block is the latest header.
	endBlockID := header.Number.Uint64()

	var defaultBlockBatchSize uint64 = 50

	slog.Info("fetching batch block events",
		"startHeight", processingBlockHeight,
		"endblock", endBlockID,
		"batchsize", defaultBlockBatchSize,
	)

	for j := processingBlockHeight; j < endBlockID; j += defaultBlockBatchSize {
		end := processingBlockHeight + uint64(defaultBlockBatchSize)
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > endBlockID {
			end = endBlockID
		}

		// filter exclusive of the end block.
		// we use "end" as the next starting point of the batch, and
		// process up to end - 1 for this batch.
		filterEnd := end - 1

		slog.Info("block batch", "start", j, "end", filterEnd)

		opts := &bind.FilterOpts{
			Start:   processingBlockHeight,
			End:     &filterEnd,
			Context: i.ctx,
		}

		group, groupCtx := errgroup.WithContext(i.ctx)

		events, err := i.taikoL1.FilterBlockProposed(opts, nil, nil)
		if err != nil {
			return err
		}

		for events.Next() {
			event := events.Event
			group.Go(func() error {
				if err := i.storeBlob(groupCtx, event); err != nil {
					slog.Error("error storing blob", "error", err)
				}

				return nil
			})
		}

		// wait for the last of the goroutines to finish
		if err := group.Wait(); err != nil {
			return err
		}

		processingBlockHeight += defaultBlockBatchSize
	}
	slog.Info(
		"indexer fully caught up",
	)

	return i.subscribe(context.Background())
}

func (i *Indexer) subscribe(ctx context.Context) error {
	defer func() {
		i.wg.Done()
	}()

	slog.Info("subscribing to new events")

	errChan := make(chan error)

	go i.subscribeBlockProposed(ctx, errChan)

	// nolint: gosimple
	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return nil
		case err := <-errChan:
			slog.Info("error encountered during subscription", "error", err)

			return err
		}
	}
}

func (i *Indexer) subscribeBlockProposed(ctx context.Context, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProposed)

	sub := event.ResubscribeErr(1*time.Second, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			slog.Error("event.ResubscribeErr", "error", err)
		}

		slog.Info("resubscribing to TaikoL1BlockProposed events")

		return i.taikoL1.WatchBlockProposed(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			slog.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- err
		case e := <-sink:
			slog.Info("blockProposed event found", "blockId", e.BlockId, "blobUsed", e.Meta.BlobUsed)
			go func() {
				if err := i.storeBlob(ctx, e); err != nil {
					slog.Error("error countered storing blob", "error", err)
				}
			}()
		}
	}
}

func (i *Indexer) Close(ctx context.Context) {
	if err := i.db.Close(ctx); err != nil {
		slog.Error("error closing db connection", "error", err)
	}

	i.wg.Wait()
}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) onBlockProposed(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	slog.Info("blockProposed event", "blobUsed", event.Meta.BlobUsed, "l1BlobHeight", event.Meta.L1Height+1)
	if event.Meta.BlobUsed {
		if err := i.storeBlob(ctx, event); err != nil {
			slog.Error("Error storing blob", "error", err)
			return err
		}
	}

	return nil
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

func (i *Indexer) storeBlob(ctx context.Context, event *taikol1.TaikoL1BlockProposed) error {
	slog.Info("storing blob", "blockID", event.Meta.L1Height+1)

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

			err = i.storeBlobMongoDB(fmt.Sprintf("%v%v", "0x", metaBlobHash), data.KzgCommitment, data.Blob, blockTs, event.BlockId.Uint64())
			if err != nil {
				slog.Error("Error storing blob in MongoDB", "error", err)
				return err
			}

			return nil
		}
	}

	return errors.New("BLOB not found")
}

func (i *Indexer) getLatestBlockID() (uint64, error) {
	var result struct {
		BlockID uint64 `bson:"block_id"`
	}

	// Create a descending sort option on the "block_id" field
	findOptions := options.FindOne().SetSort(bson.D{{Key: "block_id", Value: -1}})

	collection := i.db.Client.Database(i.cfg.DBDatabase).Collection("blobs")

	// Perform the query to find the latest document
	err := collection.FindOne(context.Background(), bson.D{}, findOptions).Decode(&result)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return 0, nil
		}

		return 0, err
	}

	return result.BlockID, nil
}

func (i *Indexer) storeBlobMongoDB(blobHashInMeta, kzgCommitment, blob string, blockTs uint64, blockID uint64) error {
	// Get MongoDB collection
	collection := i.db.Client.Database(i.cfg.DBDatabase).Collection("blobs")

	// Insert blob data into MongoDB
	_, err := collection.InsertOne(context.Background(), bson.M{
		"blob_hash":      blobHashInMeta,
		"kzg_commitment": kzgCommitment,
		"timestamp":      blockTs,
		"blob_data":      blob, // Assuming this is the blob data field
		"block_id":       blockID,
	})
	if err != nil {
		return err
	}

	slog.Info("Blob data inserted into MongoDB successfully")

	return err
}
