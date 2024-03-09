// callbacks.go

package logic

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"log/slog"
	"math/big"
	"net/http"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/taikol1"
	"go.mongodb.org/mongo-driver/bson"
)

type Response struct {
	Data []struct {
		Index            string `json:"index"`
		Blob             string `json:"blob"`
		KzgCommitment    string `json:"kzg_commitment"`
		KzgCommitmentHex []byte `json:"-"`
	} `json:"data"`
}

// Callback functions

// BlockProposedCallback is a callback for the "BlockProposed" event.
func BlockProposedCallback(rpcURL, beaconURL, networkName string, log types.Log) {

	contractAbi, err := abi.JSON(strings.NewReader(taikol1.TaikoL1ABI))
	if err != nil {
		slog.Error("Could not initiate reader")
	}

	eventData := taikol1.TaikoL1BlockProposed{}

	err = contractAbi.UnpackIntoInterface(&eventData, "BlockProposed", log.Data)
	if err != nil {
		slog.Error("Could not unpack log.Data")
	}

	// Some debug logs for now.
	// fmt.Println("Block id is:")
	// fmt.Println(log.Topics[1])

	if eventData.Meta.BlobUsed {
		// in LibPropose we assign block.height-1 to l1Height, which is the parent block.
		l1BlobHeight := eventData.Meta.L1Height + 1
		blobHash := hex.EncodeToString(eventData.Meta.BlobHash[:])

		if err = storeBlob(rpcURL, beaconURL, networkName, strconv.Itoa(int(l1BlobHeight)), blobHash); err != nil {
			slog.Error("Error storing blob:", err)
		}
	}
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
	commitment := kzg4844.Commitment(common.FromHex(commitmentStr))
	blobHash := kzg4844.CalcBlobHashV1(
		sha256.New(),
		&commitment)
	blobHashString := hex.EncodeToString(blobHash[:])
	return blobHashString
}

func storeBlob(rpcURL, beaconURL, networkName, blockID, blobHashInMeta string) error {
	cfg, err := GetConfig()
	if err != nil {
		log.Fatal("Error loading config:", err)
	}
	// url := fmt.Sprintf("https://l1beacon.internal.taiko.xyz/eth/v1/beacon/blob_sidecars/%s", blockID)
	url := fmt.Sprintf("%s/%s", beaconURL, blockID)
	response, err := http.Get(url)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	body, err := ioutil.ReadAll(response.Body)
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
				slog.Info("TIMESTAMP issue")
				return errors.New("TIMESTAMP issue")
			}
			// Debug prints
			slog.Info("The blobHash:", ("0x" + blobHashInMeta))
			// fmt.Println("The block:", blockNrBig)
			// fmt.Println("The kzg commitment:", data.KzgCommitment)
			// fmt.Println("The corresponding timestamp:", blockTs)
			// fmt.Println("The blob:", data.Blob[0:100])
			slog.Info("The networkName:", networkName)
			// Store blob data in MongoDB
			err = storeBlobMongoDB(cfg, blockID, ("0x" + blobHashInMeta), data.KzgCommitment, data.Blob, blockTs)
			if err != nil {
				log.Println("Error storing blob in MongoDB:", err)
			}

			return nil
		}
	}

	return errors.New("BLOB not found")
}

func storeBlobMongoDB(cfg *Config, blockID, blobHashInMeta, kzgCommitment, blob string, blockTs uint64) error {
	// Connect and store to MongoDB
	mongoClient, err := NewMongoDBClient(cfg.MongoDB)
	if err != nil {
		return err
	}
	defer mongoClient.Close()

	// Get MongoDB collection
	collection := mongoClient.Client.Database(cfg.MongoDB.Database).Collection("blobs")

	// Insert blob data into MongoDB
	_, err = collection.InsertOne(context.Background(), bson.M{
		//"block_id":       blockID, -> Not needed
		"blob_hash":      blobHashInMeta,
		"kzg_commitment": kzgCommitment,
		"timestamp":      blockTs,
		"blob_data":      blob, // Assuming this is the blob data field
	})
	if err != nil {
		return err
	}

	log.Println("Blob data inserted into MongoDB successfully")

	return err
}

// Add more functions as needed
