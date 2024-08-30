package flags

import (
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	commonCategory   = "COMMON"
	metricsCategory  = "METRICS"
	loggingCategory  = "LOGGING"
	driverCategory   = "DRIVER"
	proposerCategory = "PROPOSER"
	proverCategory   = "PROVER"
	txmgrCategory    = "TX_MANAGER"
)

// Required flags used by all client software.
var (
	L1WSEndpoint = &cli.StringFlag{
		Name:     "l1.ws",
		Usage:    "Websocket RPC endpoint of a L1 ethereum node",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L1_WS"},
	}
	L1PrivateTxEndpoint = &cli.StringFlag{
		Name:     "l1.privateTx",
		Usage:    "RPC endpoint of a L1 private tx ethereum node",
		Category: commonCategory,
		EnvVars:  []string{"L1_PRIVATE_TX"},
	}
	L2WSEndpoint = &cli.StringFlag{
		Name:     "l2.ws",
		Usage:    "Websocket RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L2_WS"},
	}
	L1BeaconEndpoint = &cli.StringFlag{
		Name:     "l1.beacon",
		Usage:    "HTTP RPC endpoint of a L1 beacon node",
		Category: commonCategory,
		EnvVars:  []string{"L1_BEACON"},
	}
	L2HTTPEndpoint = &cli.StringFlag{
		Name:     "l2.http",
		Usage:    "HTTP RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L2_HTTP"},
	}
	L2AuthEndpoint = &cli.StringFlag{
		Name:     "l2.auth",
		Usage:    "Authenticated HTTP RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"L2_AUTH"},
	}
	JWTSecret = &cli.StringFlag{
		Name:     "jwtSecret",
		Usage:    "Path to a JWT secret to use for authenticated RPC endpoints",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"JWT_SECRET"},
	}
	TaikoL1Address = &cli.StringFlag{
		Name:     "taikoL1",
		Usage:    "TaikoL1 contract `address`",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"TAIKO_L1"},
	}
	TaikoL2Address = &cli.StringFlag{
		Name:     "taikoL2",
		Usage:    "TaikoL2 contract `address`",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"TAIKO_L2"},
	}
	TaikoTokenAddress = &cli.StringFlag{
		Name:     "taikoToken",
		Usage:    "TaikoToken contract `address`",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"TAIKO_TOKEN"},
	}

	// Optional flags used by all client software.
	// Logging
	Verbosity = &cli.IntFlag{
		Name:     "verbosity",
		Usage:    "Logging verbosity: 0=silent, 1=error, 2=warn, 3=info, 4=debug, 5=detail",
		Value:    3,
		Category: loggingCategory,
		EnvVars:  []string{"VERBOSITY"},
	}
	LogJSON = &cli.BoolFlag{
		Name:     "log.json",
		Usage:    "Format logs with JSON",
		Category: loggingCategory,
		EnvVars:  []string{"LOG_JSON"},
	}
	// Metrics
	MetricsEnabled = &cli.BoolFlag{
		Name:     "metrics",
		Usage:    "Enable metrics collection and reporting",
		Category: metricsCategory,
		Value:    false,
		EnvVars:  []string{"METRICS"},
	}
	MetricsAddr = &cli.StringFlag{
		Name:     "metrics.addr",
		Usage:    "Metrics reporting server listening address",
		Category: metricsCategory,
		Value:    "0.0.0.0",
		EnvVars:  []string{"METRICS_ADDR"},
	}
	MetricsPort = &cli.IntFlag{
		Name:     "metrics.port",
		Usage:    "Metrics reporting server listening port",
		Category: metricsCategory,
		Value:    6060,
		EnvVars:  []string{"METRICS_PORT"},
	}
	BackOffMaxRetries = &cli.Uint64Flag{
		Name:     "backoff.maxRetries",
		Usage:    "Max retry times when there is an error",
		Category: commonCategory,
		Value:    10,
		EnvVars:  []string{"BACKOFF_MAX_RETRIES"},
	}
	BackOffRetryInterval = &cli.DurationFlag{
		Name:     "backoff.retryInterval",
		Usage:    "Retry interval in seconds when there is an error",
		Category: commonCategory,
		Value:    backoff.DefaultMaxInterval,
		EnvVars:  []string{"BACKOFF_RETRY_INTERVAL"},
	}
	RPCTimeout = &cli.DurationFlag{
		Name:     "rpc.timeout",
		Usage:    "Timeout in seconds for RPC calls",
		Category: commonCategory,
		Value:    12 * time.Second,
		EnvVars:  []string{"RPC_TIMEOUT"},
	}
	ProverSetAddress = &cli.StringFlag{
		Name:     "proverSet",
		Usage:    "ProverSet contract `address`",
		Value:    rpc.ZeroAddress.Hex(),
		Category: commonCategory,
		EnvVars:  []string{"PROVER_SET"},
	}
)

// CommonFlags All common flags.
var CommonFlags = []cli.Flag{
	// Required
	L1WSEndpoint,
	TaikoL1Address,
	TaikoL2Address,
	// Optional
	ProverSetAddress,
	Verbosity,
	LogJSON,
	MetricsEnabled,
	MetricsAddr,
	MetricsPort,
	BackOffMaxRetries,
	BackOffRetryInterval,
	RPCTimeout,
	L1PrivateTxEndpoint,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}
	return merged
}
