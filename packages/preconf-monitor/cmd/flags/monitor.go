package flags

import "github.com/urfave/cli/v2"

var (
	L2RPCUrl = &cli.StringFlag{
		Name:     "l2RpcUrl",
		Usage:    "RPC URL for the L2 chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L2_RPC_URL"},
	}
)

var MonitorFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2RPCUrl,
})
