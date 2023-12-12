package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// required flags
var (
	GuardianProverContractAddress = &cli.StringFlag{
		Name:     "guardianProverContractAddress",
		Usage:    "Address of the GuardianProver contract",
		Category: healthCheckCategory,
		EnvVars:  []string{"GUARDIAN_PROVER_CONTRACT_ADDRESS"},
		Required: true,
	}
	L1RPCUrl = &cli.StringFlag{
		Name:     "l1RpcUrl",
		Usage:    "L1 RPC Url",
		Category: healthCheckCategory,
		EnvVars:  []string{"L1_RPC_URL"},
		Required: true,
	}
	L2RPCUrl = &cli.StringFlag{
		Name:     "l2RpcUrl",
		Usage:    "L2 RPC Url",
		Category: healthCheckCategory,
		EnvVars:  []string{"L2_RPC_URL"},
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
)

var HealthCheckFlags = MergeFlags(CommonFlags, []cli.Flag{
	HTTPPort,
	CORSOrigins,
	Backoff,
	GuardianProverContractAddress,
	L1RPCUrl,
	L2RPCUrl,
})
