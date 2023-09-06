package flags

import "github.com/urfave/cli/v2"

// required flags
var (
	RPCUrl = &cli.StringFlag{
		Name:     "srcRpcUrl",
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
		Category: commonCategory,
		Required: false,
		Value:    6061,
		EnvVars:  []string{"METRICS_HTTP_PORT"},
	}
	ETHClientTimeout = &cli.Uint64Flag{
		Name:     "ethClientTimeout",
		Usage:    "Timeout for eth client and contract binding calls",
		Category: commonCategory,
		Required: false,
		Value:    10,
		EnvVars:  []string{"ETH_CLIENT_TIMEOUT"},
	}
	L1TaikoAddress = &cli.StringFlag{
		Name:     "l1TaikoAddress",
		Usage:    "Address of the TaikoL1 contract",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L1_TAIKO_ADDRESS"},
	}
	BridgeAddress = &cli.StringFlag{
		Name:     "bridgeAddress",
		Usage:    "Address of the Bridge contract",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"BRIDGE_ADDRESS"},
	}
	SwapAddresses = &cli.StringFlag{
		Name:     "swapAddresses",
		Usage:    "Comma-delinated list of Swap contract addresses",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"SWAP_ADDRESSES"},
	}
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Required: false,
		Value:    "*",
		Category: indexerCategory,
	}
)

var IndexerFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1TaikoAddress,
	// optional
	HTTPPort,
	SrcTaikoAddress,
	BlockBatchSize,
	MaxNumGoroutines,
	SubscriptionBackoff,
	SyncMode,
	WatchMode,
})
