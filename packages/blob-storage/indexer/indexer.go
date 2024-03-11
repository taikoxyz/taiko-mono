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
	"strconv"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/bindings/taikol1"
	mongodb "github.com/taikoxyz/taiko-mono/packages/blob-storage/pkg/db"
	"github.com/urfave/cli/v2"
	"go.mongodb.org/mongo-driver/bson"
	"golang.org/x/exp/slog"
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

	return nil
}

func (i *Indexer) Start() error {
	var opts *bind.FilterOpts

	if i.startHeight != nil {
		opts = &bind.FilterOpts{
			Start: *i.startHeight,
		}
	}

	iter, err := i.taikoL1.FilterBlockProposed(opts, nil, nil)
	if err != nil {
		return err
	}

	return nil
}

func (i *Indexer) Close(ctx context.Context) {

}

func (i *Indexer) Name() string {
	return "indexer"
}

func (i *Indexer) onBlockProposed(rpcURL string, beaconURL string, event *taikol1.TaikoL1BlockProposed) error {
	slog.Info("blockProposed event", "blobUsed", event.Meta.BlobUsed, "l1BlobHeight", event.Meta.L1Height+1)
	if event.Meta.BlobUsed {
		// in LibPropose we assign block.height-1 to l1Height, which is the parent block.
		l1BlobHeight := event.Meta.L1Height + 1

		blobHash := hex.EncodeToString(event.Meta.BlobHash[:])

		if err := i.storeBlob(rpcURL, beaconURL, strconv.Itoa(int(l1BlobHeight)), blobHash); err != nil {
			slog.Error("Error storing blob", "error", err)
			return err
		}
	}

	return nil
}

func getBlockTimestamp(rpcURL string, blockNumber *big.Int) (uint64, error) {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return 0, err
	}
	defer client.Close()

	block, err := client.BlockByNumber(context.Background(), blockNumber)
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

func (i *Indexer) storeBlob(rpcURL, beaconURL, blockID, blobHashInMeta string) error {
	url := fmt.Sprintf("%s/%s", beaconURL, blockID)
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

		// Comparing the hex strings of meta.blobHash (blobHash)
		if calculateBlobHash(data.KzgCommitment) == blobHashInMeta {
			n := new(big.Int)

			blockNrBig, ok := n.SetString(blockID, 10)
			if !ok {
				slog.Info("SetString: error")
				return errors.New("SetString: error")
			}

			blockTs, err := getBlockTimestamp(rpcURL, blockNrBig)
			if err != nil {
				slog.Info("error getting block timestamp", "error", err)
				return err
			}

			slog.Info("blockHash", "blobHash", fmt.Sprintf("%v%v", "0x", blobHashInMeta))

			err = i.storeBlobMongoDB(blockID, fmt.Sprintf("%v%v", "0x", blobHashInMeta), data.KzgCommitment, data.Blob, blockTs)
			if err != nil {
				slog.Error("Error storing blob in MongoDB", "error", err)
				return err
			}

			return nil
		}
	}

	return errors.New("BLOB not found")
}

func (i *Indexer) storeBlobMongoDB(blockID, blobHashInMeta, kzgCommitment, blob string, blockTs uint64) error {
	// Get MongoDB collection
	collection := i.db.Client.Database(i.cfg.DBDatabase).Collection("blobs")

	// Insert blob data into MongoDB
	_, err := collection.InsertOne(context.Background(), bson.M{
		//"block_id":       blockID, -> Not needed
		"blob_hash":      blobHashInMeta,
		"kzg_commitment": kzgCommitment,
		"timestamp":      blockTs,
		"blob_data":      blob, // Assuming this is the blob data field
	})
	if err != nil {
		return err
	}

	slog.Info("Blob data inserted into MongoDB successfully")

	return err
}
