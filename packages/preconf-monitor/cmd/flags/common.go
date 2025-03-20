package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory = "COMMON"
	txmgrCategory  = "TX_MANAGER"
)

var (
	L1RPCUrl = &cli.StringFlag{
		Name:     "l1RpcUrl",
		Usage:    "RPC URL for the L1 chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L1_RPC_URL"},
	}
	WhitelistAddress = &cli.StringFlag{
		Name:     "whitelistAddress",
		Usage:    "Whitelist address",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"WHITELIST_ADDRESS"},
	}
	PrivateKey = &cli.StringFlag{
		Name:     "privateKey",
		Usage:    "Private key",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"PRIVATE_KEY"},
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

var CommonFlags = MergeFlags([]cli.Flag{
	L1RPCUrl,
	WhitelistAddress,
	PrivateKey,
	MetricsHTTPPort,
}, TxmgrFlags)

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}

	return merged
}
