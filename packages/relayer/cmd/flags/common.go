package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory    = "COMMON"
	indexerCategory   = "INDEXER"
	processorCategory = "PROCESSOR"
	watchdogCategory  = "WATCHDOG"
	bridgeCategory    = "BRIDGE"
	txmgrCategory     = "TX_MANAGER"
)

var (
	DatabaseUsername = &cli.StringFlag{
		Name:     "db.username",
		Usage:    "Database connection username",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_USER"},
	}
	DatabasePassword = &cli.StringFlag{
		Name:     "db.password",
		Usage:    "Database connection password",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_PASSWORD"},
	}
	DatabaseHost = &cli.StringFlag{
		Name:     "db.host",
		Usage:    "Database connection host",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_HOST"},
	}
	DatabaseName = &cli.StringFlag{
		Name:     "db.name",
		Usage:    "Database connection name",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_NAME"},
	}
	SrcRPCUrl = &cli.StringFlag{
		Name:     "srcRpcUrl",
		Usage:    "RPC URL for the source chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"SRC_RPC_URL"},
	}
	DestRPCUrl = &cli.StringFlag{
		Name:     "destRpcUrl",
		Usage:    "RPC URL for the destination chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DEST_RPC_URL"},
	}
)

var (
	DatabaseMaxIdleConns = &cli.Uint64Flag{
		Name:     "db.maxIdleConns",
		Usage:    "Database max idle connections",
		Value:    50,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_MAX_IDLE_CONNS"},
	}
	DatabaseMaxOpenConns = &cli.Uint64Flag{
		Name:     "db.maxOpenConns",
		Usage:    "Database max open connections",
		Value:    200,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_MAX_OPEN_CONNS"},
	}
	DatabaseConnMaxLifetime = &cli.Uint64Flag{
		Name:     "db.connMaxLifetime",
		Usage:    "Database connection max lifetime in seconds",
		Value:    10,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_CONN_MAX_LIFETIME"},
	}
	MetricsHTTPPort = &cli.Uint64Flag{
		Name:     "metrics.port",
		Usage:    "Port to run metrics http server on",
		Category: commonCategory,
		Value:    6061,
		EnvVars:  []string{"METRICS_HTTP_PORT"},
	}
	ETHClientTimeout = &cli.Uint64Flag{
		Name:     "ethClientTimeout",
		Usage:    "Timeout for eth client and contract binding calls",
		Category: commonCategory,
		Value:    10,
		EnvVars:  []string{"ETH_CLIENT_TIMEOUT"},
	}
	SrcSignalServiceAddress = &cli.StringFlag{
		Name:     "srcSignalServiceAddress",
		Usage:    "SignalService address for the source chain",
		Category: commonCategory,
		EnvVars:  []string{"SRC_SIGNAL_SERVICE_ADDRESS"},
	}
	BackOffRetryInterval = &cli.Uint64Flag{
		Name:     "backoff.retryInterval",
		Usage:    "Retry interval in seconds when there is an error",
		Category: processorCategory,
		Value:    12,
	}
	BackOffMaxRetrys = &cli.Uint64Flag{
		Name:     "backoff.maxRetrys",
		Usage:    "Max retry times when there is an error",
		Category: processorCategory,
		Value:    3,
	}
)

// All common flags.
var CommonFlags = []cli.Flag{
	// required
	DatabaseUsername,
	DatabasePassword,
	DatabaseHost,
	DatabaseName,
	SrcRPCUrl,
	DestRPCUrl,
	// optional
	DatabaseMaxIdleConns,
	DatabaseConnMaxLifetime,
	DatabaseMaxOpenConns,
	MetricsHTTPPort,
	ETHClientTimeout,
	SrcSignalServiceAddress,
	BackOffMaxRetrys,
	BackOffRetryInterval,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}

	return merged
}
