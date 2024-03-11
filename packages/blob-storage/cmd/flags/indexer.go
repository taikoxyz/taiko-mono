package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	indexerCategory = "INDEXER"
)

var (
	IndexPastBlocks = &cli.BoolFlag{
		Name:     "indexPastEvents",
		Usage:    "Index past events",
		Value:    false,
		Category: indexerCategory,
		EnvVars:  []string{"INDEX_PAST_EVENTS"},
	}
	StartingBlockID = &cli.Uint64Flag{
		Name:     "startingBlockID",
		Usage:    "Block ID to start indexing from",
		Category: indexerCategory,
		EnvVars:  []string{"STARTING_BLOCK_ID"},
	}
	RPCUrl = &cli.StringFlag{
		Name:     "rpcURL",
		Usage:    "Websockets RPC Url",
		Category: indexerCategory,
		Required: true,
		EnvVars:  []string{"RPC_URL"},
	}
	BeaconURL = &cli.StringFlag{
		Name:     "beaconURL",
		Usage:    "Websockets Beacon Url",
		Category: indexerCategory,
		Required: true,
		EnvVars:  []string{"BEACON_URL"},
	}
	ContractAddress = &cli.StringFlag{
		Name:     "contractAddress",
		Usage:    "Contract address",
		Category: indexerCategory,
		Required: true,
		EnvVars:  []string{"TAIKO_L1_CONTRACT_ADDRESS"},
	}
	EventHash = &cli.StringFlag{
		Name:     "eventHash",
		Usage:    "Event Hash",
		Category: indexerCategory,
		Required: true,
		EnvVars:  []string{"EVENT_HASH"},
	}
)

var IndexerFlags = MergeFlags(DatabaseFlags, []cli.Flag{
	IndexPastBlocks,
	StartingBlockID,
	RPCUrl,
	BeaconURL,
	ContractAddress,
	EventHash,
})
