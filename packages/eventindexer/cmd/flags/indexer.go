package flags

import "github.com/urfave/cli/v2"

// required flags
var (
	RPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"RPC_URL"},
	}
)

// optional flags
var (
	HTTPPort = &cli.Uint64Flag{
		Name:     "http.port",
		Usage:    "Port to run http server on",
		Category: indexerCategory,
		Required: false,
		Value:    4102,
		EnvVars:  []string{"HTTP_PORT"},
	}
	MetricsHTTPPort = &cli.Uint64Flag{
		Name:     "metrics.port",
		Usage:    "Port to run metrics http server on",
		Category: indexerCategory,
		Required: false,
		Value:    6061,
		EnvVars:  []string{"METRICS_HTTP_PORT"},
	}
	ETHClientTimeout = &cli.Uint64Flag{
		Name:     "ethClientTimeout",
		Usage:    "Timeout for eth client and contract binding calls",
		Category: indexerCategory,
		Required: false,
		Value:    10,
		EnvVars:  []string{"ETH_CLIENT_TIMEOUT"},
	}
	L1TaikoAddress = &cli.StringFlag{
		Name:     "l1TaikoAddress",
		Usage:    "Address of the TaikoL1 contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"L1_TAIKO_ADDRESS"},
	}
	BridgeAddress = &cli.StringFlag{
		Name:     "bridgeAddress",
		Usage:    "Address of the Bridge contract",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"BRIDGE_ADDRESS"},
	}
	SwapAddresses = &cli.StringFlag{
		Name:     "swapAddresses",
		Usage:    "Comma-delinated list of Swap contract addresses",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"SWAP_ADDRESSES"},
	}
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Required: false,
		Value:    "*",
		Category: indexerCategory,
	}
	BlockBatchSize = &cli.Uint64Flag{
		Name:     "blockBatchSize",
		Usage:    "Block batch size when iterating through blocks",
		Value:    10,
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"BLOCK_BATCH_SIZE"},
	}
	SubscriptionBackoff = &cli.Uint64Flag{
		Name:     "subscriptionBackoff",
		Usage:    "Subscription backoff in seconds",
		Value:    30,
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"SUBSCRIPTION_BACKOFF_IN_SECONDS"},
	}
	SyncMode = &cli.StringFlag{
		Name:     "syncMode",
		Usage:    "Mode of syncing. Pass in 'sync' to continue, and 'resync' to start from genesis again.",
		Value:    "sync",
		Category: indexerCategory,
		EnvVars:  []string{"SYNC_MODE"},
	}
	WatchMode = &cli.StringFlag{
		Name: "watchMode",
		Usage: `Mode of watching the chain. Options are:
		filter: only filter the chain, when caught up, exit
		subscribe: do not filter the chain, only subscribe to new events
		filter-and-subscribe: the default behavior, filter the chain and subscribe when caught up
		`,
		Value:    "filter-and-subscribe",
		Category: indexerCategory,
		EnvVars:  []string{"SYNC_MODE"},
	}
	IndexNFTs = &cli.BoolFlag{
		Name:     "indexNfts",
		Usage:    "Whether to index nft transfer events orn ot",
		Required: false,
		Category: indexerCategory,
		EnvVars:  []string{"INDEX_NFTS"},
	}
	Layer = &cli.StringFlag{
		Name:     "layer",
		Usage:    "Which layer indexing is occurring on",
		Required: false,
		Value:    "l1",
		Category: indexerCategory,
		EnvVars:  []string{"LAYER"},
	}
)

var IndexerFlags = MergeFlags(CommonFlags, []cli.Flag{
	RPCUrl,
	// optional
	ETHClientTimeout,
	L1TaikoAddress,
	HTTPPort,
	MetricsHTTPPort,
	BridgeAddress,
	SwapAddresses,
	CORSOrigins,
	BlockBatchSize,
	SubscriptionBackoff,
	SyncMode,
	WatchMode,
	IndexNFTs,
	Layer,
})
