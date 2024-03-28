package flags

import (
	"time"

	"github.com/urfave/cli/v2"
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
	}
	L2WSEndpoint = &cli.StringFlag{
		Name:     "l2.ws",
		Usage:    "Websocket RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: commonCategory,
	}
	L1HTTPEndpoint = &cli.StringFlag{
		Name:     "l1.http",
		Usage:    "HTTP RPC endpoint of a L1 ethereum node",
		Required: true,
		Category: commonCategory,
	}
	L1BeaconEndpoint = &cli.StringFlag{
		Name:     "l1.beacon",
		Usage:    "HTTP RPC endpoint of a L1 beacon node",
		Category: commonCategory,
	}
	L2HTTPEndpoint = &cli.StringFlag{
		Name:     "l2.http",
		Usage:    "HTTP RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: commonCategory,
	}
	TaikoL1Address = &cli.StringFlag{
		Name:     "taikoL1",
		Usage:    "TaikoL1 contract `address`",
		Required: true,
		Category: commonCategory,
	}
	TaikoL2Address = &cli.StringFlag{
		Name:     "taikoL2",
		Usage:    "TaikoL2 contract `address`",
		Required: true,
		Category: commonCategory,
	}
	TaikoTokenAddress = &cli.StringFlag{
		Name:     "taikoToken",
		Usage:    "TaikoToken contract `address`",
		Required: true,
		Category: commonCategory,
	}
	// Optional flags used by all client software.
	// Logging
	Verbosity = &cli.IntFlag{
		Name:     "verbosity",
		Usage:    "Logging verbosity: 0=silent, 1=error, 2=warn, 3=info, 4=debug, 5=detail",
		Value:    3,
		Category: loggingCategory,
	}
	LogJSON = &cli.BoolFlag{
		Name:     "log.json",
		Usage:    "Format logs with JSON",
		Category: loggingCategory,
	}
	// Metrics
	MetricsEnabled = &cli.BoolFlag{
		Name:     "metrics",
		Usage:    "Enable metrics collection and reporting",
		Category: metricsCategory,
		Value:    false,
	}
	MetricsAddr = &cli.StringFlag{
		Name:     "metrics.addr",
		Usage:    "Metrics reporting server listening address",
		Category: metricsCategory,
		Value:    "0.0.0.0",
	}
	MetricsPort = &cli.IntFlag{
		Name:     "metrics.port",
		Usage:    "Metrics reporting server listening port",
		Category: metricsCategory,
		Value:    6060,
	}
	BackOffMaxRetrys = &cli.Uint64Flag{
		Name:     "backoff.maxRetrys",
		Usage:    "Max retry times when there is an error",
		Category: commonCategory,
		Value:    10,
	}
	BackOffRetryInterval = &cli.DurationFlag{
		Name:     "backoff.retryInterval",
		Usage:    "Retry interval in seconds when there is an error",
		Category: commonCategory,
		Value:    12 * time.Second,
	}
	RPCTimeout = &cli.DurationFlag{
		Name:     "rpc.timeout",
		Usage:    "Timeout in seconds for RPC calls",
		Category: commonCategory,
		Value:    12 * time.Second,
	}
	WaitReceiptTimeout = &cli.DurationFlag{
		Name:     "rpc.waitReceiptTimeout",
		Usage:    "Timeout for waiting for receipts for RPC transactions",
		Category: commonCategory,
		Value:    1 * time.Minute,
	}
)

// CommonFlags All common flags.
var CommonFlags = []cli.Flag{
	// Required
	L1WSEndpoint,
	TaikoL1Address,
	TaikoL2Address,
	// Optional
	Verbosity,
	LogJSON,
	MetricsEnabled,
	MetricsAddr,
	MetricsPort,
	BackOffMaxRetrys,
	BackOffRetryInterval,
	RPCTimeout,
	WaitReceiptTimeout,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}
	return merged
}
