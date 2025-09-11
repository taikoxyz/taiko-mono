package flags

import "github.com/urfave/cli/v2"

// required flags
var (
	APIRPCUrl = &cli.StringFlag{
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
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Required: false,
		Value:    "*",
		Category: indexerCategory,
	}
)

var APIFlags = MergeFlags(CommonFlags, []cli.Flag{
	APIRPCUrl,
	HTTPPort,
	CORSOrigins,
})
