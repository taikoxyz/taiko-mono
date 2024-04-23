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
	TaikoTokenAddress = &cli.StringFlag{
		Name:     "taikoTokenAddress",
		Usage:    "Address of the TaikoToken contract",
		Required: true,
		Category: disperserCategory,
		EnvVars:  []string{"TAIKO_TOKEN_ADDRESS"},
	}
	DispersalAmount = &cli.StringFlag{
		Name:     "dispersalAmount",
		Usage:    "Dispersal amount in wei",
		Required: true,
		Category: disperserCategory,
		EnvVars:  []string{"DISPERSAL_AMOUNT"},
	}
	RPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"RPC_URL"},
	}
)

var DisperserFlags = MergeFlags(CommonFlags, TxmgrFlags, []cli.Flag{
	DisperserPrivateKey,
	TaikoTokenAddress,
	DispersalAmount,
	RPCUrl,
})
