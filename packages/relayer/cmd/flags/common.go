package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory    = "COMMON"
	metricsCategory   = "METRICS"
	indexerCategory   = "INDEXER"
	processorCategory = "PROCESSOR"
)

var (
	DatabaseUsername = &cli.StringFlag{
		Name:     "db.username",
		Usage:    "Database connection username",
		Required: true,
		Category: commonCategory,
	}
	DatabasePassword = &cli.StringFlag{
		Name:     "db.password",
		Usage:    "Database connection password",
		Required: true,
		Category: commonCategory,
	}
	DatabaseHost = &cli.StringFlag{
		Name:     "db.host",
		Usage:    "Database connection host",
		Required: true,
		Category: commonCategory,
	}
	DatabaseName = &cli.StringFlag{
		Name:     "db.name",
		Usage:    "Database connection name",
		Required: true,
		Category: commonCategory,
	}
	QueueUsername = &cli.StringFlag{
		Name:     "queue.username",
		Usage:    "Queue connection username",
		Required: true,
		Category: commonCategory,
	}
	QueuePassword = &cli.StringFlag{
		Name:     "queue.password",
		Usage:    "Queue connection password",
		Required: true,
		Category: commonCategory,
	}
	QueueHost = &cli.StringFlag{
		Name:     "queue.host",
		Usage:    "Queue connection host",
		Required: true,
		Category: commonCategory,
	}
	QueuePort = &cli.StringFlag{
		Name:     "queue.port",
		Usage:    "Queue connection port",
		Required: true,
		Category: commonCategory,
	}
)

// optional
var (
	CORSOrigins = &cli.StringFlag{
		Name:     "http.corsOrigins",
		Usage:    "Comma-delinated list of cors origins",
		Required: false,
		Category: commonCategory,
	}
)

// All common flags.
var CommonFlags = []cli.Flag{
	DatabaseUsername,
	DatabasePassword,
	DatabaseHost,
	DatabaseName,
	QueueUsername,
	QueuePassword,
	QueueHost,
	QueuePort,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}
	return merged
}
