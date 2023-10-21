package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory    = "COMMON"
	indexerCategory   = "INDEXER"
	processorCategory = "PROCESSOR"
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
	QueueUsername = &cli.StringFlag{
		Name:     "queue.username",
		Usage:    "Queue connection username",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_USER"},
	}
	QueuePassword = &cli.StringFlag{
		Name:     "queue.password",
		Usage:    "Queue connection password",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_PASSWORD"},
	}
	QueueHost = &cli.StringFlag{
		Name:     "queue.host",
		Usage:    "Queue connection host",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_HOST"},
	}
	QueuePort = &cli.Uint64Flag{
		Name:     "queue.port",
		Usage:    "Queue connection port",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_PORT"},
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
	DestBridgeAddress = &cli.StringFlag{
		Name:     "destBridgeAddress",
		Usage:    "Bridge address for the destination chain",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DEST_BRIDGE_ADDRESS"},
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
)

// All common flags.
var CommonFlags = []cli.Flag{
	// required
	DatabaseUsername,
	DatabasePassword,
	DatabaseHost,
	DatabaseName,
	QueueUsername,
	QueuePassword,
	QueueHost,
	QueuePort,
	SrcRPCUrl,
	DestRPCUrl,
	DestBridgeAddress,
	// optional
	DatabaseMaxIdleConns,
	DatabaseConnMaxLifetime,
	DatabaseMaxOpenConns,
	MetricsHTTPPort,
	ETHClientTimeout,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}

	return merged
}
