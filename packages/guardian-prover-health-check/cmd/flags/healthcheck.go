package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// required flags
var (
	GuardianProverEndpoints = &cli.StringSliceFlag{
		Name:     "guardianProverEndpoints",
		Usage:    "List of guardian prover endpoints",
		Category: healthCheckCategory,
		EnvVars:  []string{"GUARDIAN_PROVER_ENDPOINTS"},
		Required: true,
	}
	GuardianProverContractAddress = &cli.StringFlag{
		Name:     "guardianProverContractAddress",
		Usage:    "Address of the GuardianProver contract",
		Category: healthCheckCategory,
		EnvVars:  []string{"GUARDIAN_PROVER_CONTRACT_ADDRESS"},
		Required: true,
	}
	RPCUrl = &cli.StringFlag{
		Name:     "rpcUrl",
		Usage:    "RPC Url",
		Category: healthCheckCategory,
		EnvVars:  []string{"RPC_URL"},
		Required: true,
	}
)
var (
	Backoff = &cli.DurationFlag{
		Name:     "backoff",
		Usage:    "Backoff in time units (ie: 5s)",
		Value:    1 * time.Second,
		Category: healthCheckCategory,
		EnvVars:  []string{"BACKOFF"},
	}
	HTTPPort = &cli.Uint64Flag{
		Name:     "http.port",
		Usage:    "Port to run http server on",
		Category: healthCheckCategory,
		Value:    4102,
		EnvVars:  []string{"HTTP_PORT"},
	}
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Category: healthCheckCategory,
		Value:    "*",
		EnvVars:  []string{"HTTP_CORS_ORIGINS"},
	}
	Interval = &cli.DurationFlag{
		Name:     "interval",
		Usage:    "Health check interval duration",
		Category: healthCheckCategory,
		Value:    12 * time.Second,
		EnvVars:  []string{"INTERVAL"},
	}
)

var HealthCheckFlags = MergeFlags(CommonFlags, []cli.Flag{
	HTTPPort,
	CORSOrigins,
	Backoff,
	GuardianProverEndpoints,
	GuardianProverContractAddress,
	Interval,
	RPCUrl,
})
