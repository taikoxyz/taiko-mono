package flags

import (
	"github.com/urfave/cli/v2"
)

// optional
var (
	HTTPPort = &cli.Uint64Flag{
		Name:     "http.port",
		Usage:    "Port to run http server on",
		Category: indexerCategory,
		Value:    4102,
		EnvVars:  []string{"HTTP_PORT"},
	}
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Category: indexerCategory,
		Value:    "*",
		EnvVars:  []string{"HTTP_CORS_ORIGINS"},
	}
	ProcessingFeeMultiplier = &cli.Float64Flag{
		Name:     "processingFeeMultiplier",
		Usage:    "Processing fee multiplier",
		Category: indexerCategory,
		Value:    2.5,
		EnvVars:  []string{"PROCESSING_FEE_MULTIPLIER"},
	}
)

var APIFlags = MergeFlags(CommonFlags, []cli.Flag{
	// optional
	HTTPPort,
	CORSOrigins,
	ProcessingFeeMultiplier,
	DestTaikoAddress,
})
