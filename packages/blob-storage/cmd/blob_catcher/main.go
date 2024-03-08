package main

import (
	"flag"
	"fmt"
	"log"
	"math/big"
	"os"
	"strconv"

	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/indexer"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/logic"
	"github.com/urfave/cli/v2"
)

func main() {
	// Define command-line flags
	pastEvents := flag.Bool("past_events", false, "Enable indexing past events")
	startBlock := flag.String("start_block", "", "Block number to start indexing from")

	app := cli.NewApp()

	log.SetOutput(os.Stdout)

	// All supported sub commands.
	app.Commands = []*cli.Command{
		{
			Name:        "pastEvents",
			Usage:       "If true it means indexing past events",
			Description: "If true, can indicate at which blockheight it shall start from",
			Args:        false,
		},
		{
			Name:        "startBlock",
			Usage:       "Specific blockheight",
			Description: "Shall be used together with pastEvents cli",
			ArgsUsage:   "--startBlock 121",
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

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
