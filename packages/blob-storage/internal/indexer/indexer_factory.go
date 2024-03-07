package indexer

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/logic"
)

// Initialize and starts all the indexers from config.
func InitFromConfig(cfg *logic.Config, pastEvents bool, startBlockNumber *big.Int) error {
	// Initialize listeners for each network
	for _, network := range cfg.Networks {
		for _, event := range network.IndexedEvents {
			indexer := NewIndexer(network.RPCURL, network.BeaconURL, network.NetworkName, event.Contract, pastEvents, startBlockNumber)

			indexer.SubscribeEvent(event.EventHash, event.Callback)

			// Run the event listener for each network
			go indexer.Start()
		}

	}
	select {}
}
