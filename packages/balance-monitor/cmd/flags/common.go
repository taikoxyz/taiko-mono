package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory = "COMMON"
)

var (
	Addresses = &cli.StringSliceFlag{
		Name:     "addresses",
		Usage:    "Comma-delinated list of Ethereum addresses to monitor",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"ADDRESSES"},
	}
	L1RPCUrl = &cli.StringFlag{
		Name:     "l1RpcUrl",
		Usage:    "RPC URL for the L1 chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L1_RPC_URL"},
	}
	L2RPCUrl = &cli.StringFlag{
		Name:     "l2RpcUrl",
		Usage:    "RPC URL for the L2 chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L2_RPC_URL"},
	}
	ERC20Addresses = &cli.StringSliceFlag{
		Name:     "erc20Addresses",
		Usage:    "Comma-delimited list of ERC-20 token contract addresses",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"ERC20_ADDRESSES"},
	}
	Interval = &cli.IntFlag{
		Name:     "interval",
		Usage:    "Interval in seconds to check the balances",
		Required: false,
		Value:    10, // default value
		Category: commonCategory,
		EnvVars:  []string{"INTERVAL"},
	}
	MetricsHTTPPort = &cli.Uint64Flag{
		Name:     "metrics.port",
		Usage:    "Port to run metrics http server on",
		Required: false,
		Value:    6061,
		Category: commonCategory,
		EnvVars:  []string{"METRICS_HTTP_PORT"},
	}
)

var CommonFlags = []cli.Flag{
	Addresses,
	L1RPCUrl,
	L2RPCUrl,
	ERC20Addresses,
	Interval,
	MetricsHTTPPort,
}
