package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

var (
	indexerCategory = "INDEXER"
)

var (
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
	BackOffMaxRetrys = &cli.Uint64Flag{
		Name:     "backoff.maxRetrys",
		Usage:    "Max retry times when there is an error",
		Category: commonCategory,
		Value:    10,
		EnvVars:  []string{"BACKOFF_MAX_RETRIES"},
	}
	BackOffRetryInterval = &cli.DurationFlag{
		Name:     "backoff.retryInterval",
		Usage:    "Retry interval in seconds when there is an error",
		Category: commonCategory,
		Value:    12 * time.Second,
		EnvVars:  []string{"BACKOFF_RETRY_INTERVAL"},
	}
)

var IndexerFlags = MergeFlags(DatabaseFlags, CommonFlags, []cli.Flag{
	StartingBlockID,
	RPCUrl,
	BeaconURL,
	ContractAddress,
	BackOffMaxRetrys,
	BackOffRetryInterval,
})
