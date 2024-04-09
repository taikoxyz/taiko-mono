package flags

import "github.com/urfave/cli/v2"

var (
	DisperserPrivateKey = &cli.StringFlag{
		Name:     "disperserPrivateKey",
		Usage:    "Disperser private key which contains TTKO",
		Required: true,
		Category: disperserCategory,
		EnvVars:  []string{"DISPERSER_PRIVATE_KEY"},
	}
	RPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"RPC_URL"},
	}
)

var DisperserFlags = MergeFlags(CommonFlags, []cli.Flag{
	DisperserPrivateKey,
	RPCUrl,
})
