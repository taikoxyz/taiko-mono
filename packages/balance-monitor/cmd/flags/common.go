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
)

var CommonFlags = []cli.Flag{
	Addresses,
	L1RPCUrl,
	L2RPCUrl,
}
