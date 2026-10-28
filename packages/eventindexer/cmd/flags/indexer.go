package flags

import "github.com/urfave/cli/v2"

// required flags
var (
	IndexerRPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"RPC_URL"},
	}
)

// optional flags
var (
	BlockBatchSize = &cli.Uint64Flag{
		Name:     "blockBatchSize",
		Usage:    "Block batch size when iterating through blocks",
		Value:    10,
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"BLOCK_BATCH_SIZE"},
	}

	SyncMode = &cli.StringFlag{
		Name:     "syncMode",
		Usage:    "Mode of syncing. Pass in 'sync' to continue, and 'resync' to start from genesis again.",
		Value:    "sync",
		Category: indexerCategory,
		EnvVars:  []string{"SYNC_MODE"},
	}
	IndexNFTs = &cli.BoolFlag{
		Name:     "indexNfts",
		Usage:    "Whether to index nft transfer events or not",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"INDEX_NFTS"},
	}
	AllowUnclaimedBalanceReplay = &cli.BoolFlag{
		Name: "allowUnclaimedBalanceReplay",
		Usage: "Start even when balances predate the transfer log claim table, " +
			"accepting a single double count on this restart",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"ALLOW_UNCLAIMED_BALANCE_REPLAY"},
	}
)

var IndexerFlags = MergeFlags(CommonFlags, []cli.Flag{
	IndexerRPCUrl,
	// optional
	BlockBatchSize,
	SyncMode,
	IndexNFTs,
	AllowUnclaimedBalanceReplay,
})
