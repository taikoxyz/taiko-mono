package indexer

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Indexer struct holds the configuration and state for the Ethereum chain listener.
type Indexer struct {
	rpcURL            string
	beaconURL         string
	networkName       string
	contractAddress   common.Address
	eventHash         common.Hash
	startHeight       *big.Int
	eventCallbackFunc func(string, string, string, types.Log)
}

// NewIndexer creates a new Indexer instance.
func NewIndexer(rpcURL, beaconURL, networkName, contractAddress string, pastEvents bool, startBlockNumber *big.Int) *Indexer {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		log.Fatal("Failed to connect to the Ethereum client:", err)
	}

	if pastEvents == false {
		header, err := client.HeaderByNumber(context.Background(), nil)
		if err != nil {
			log.Fatal(err)
		}
		startBlockNumber = header.Number
	}

	fmt.Println(client.Client())

	return &Indexer{
		rpcURL:          rpcURL,
		beaconURL:       beaconURL,
		networkName:     networkName,
		contractAddress: common.HexToAddress(contractAddress),
		startHeight:     startBlockNumber,
	}
}

// SubscribeEvent subscribes to the specified event.
func (indexer *Indexer) SubscribeEvent(eventHash string, callbackFunc func(string, string, string, types.Log)) {
	indexer.eventHash = common.HexToHash(eventHash)
	indexer.eventCallbackFunc = callbackFunc
}

// Start starts the Ethereum chain listener/indexer.
func (indexer *Indexer) Start() {
	client, err := ethclient.Dial(indexer.rpcURL)
	if err != nil {
		log.Fatal("Failed to connect to the Ethereum client:", err)
	}

	query := ethereum.FilterQuery{
		Addresses: []common.Address{indexer.contractAddress},
		FromBlock: indexer.startHeight,
	}

	logsCh := make(chan types.Log)
	sub, err := client.SubscribeFilterLogs(context.Background(), query, logsCh)
	if err != nil {
		log.Fatal("Failed to subscribe to logs:", err)
	}

	log.Println("Indexer for ", indexer.networkName, " started.")

	log.Println("Scraping from blockheight: ", indexer.startHeight)

	for {
		select {
		case err := <-sub.Err():
			log.Fatal("Subscription error:", err)
		case log := <-logsCh:
			if log.Topics[0] == indexer.eventHash {
				go indexer.HandleEvent(log)
			}
		}
	}
}

// HandleEvent handles the incoming Ethereum event.
func (indexer *Indexer) HandleEvent(log types.Log) {
	indexer.eventCallbackFunc(indexer.rpcURL, indexer.beaconURL, indexer.networkName, log)
}
