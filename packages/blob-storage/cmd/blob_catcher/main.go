package main

import (
	"flag"
	"log"
	"math/big"
	"strconv"

	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/indexer"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/logic"
)

func main() {
	// Define command-line flags
	pastEvents := flag.Bool("past_events", false, "Enable indexing past events")
	startBlock := flag.String("start_block", "", "Block number to start indexing from")

	// Parse command-line flags
	flag.Parse()

	// Convert start block number to *big.Int if provided
	var startBlockNumber *big.Int
	if *startBlock != "" {
		n, err := strconv.ParseInt(*startBlock, 10, 64)
		if err != nil {
			log.Fatalf("Invalid start block number: %v", err)
		}
		startBlockNumber = big.NewInt(n)
	}

	// Load configuration
	cfg, err := logic.GetConfig()
	if err != nil {
		log.Fatal("Error loading config:", err)
	}

	// Initialize indexer with optional parameters
	if err := indexer.InitFromConfig(cfg, *pastEvents, startBlockNumber); err != nil {
		log.Fatal("Error running indexer:", err)
	}
}
