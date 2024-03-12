package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	commonCategory string = "COMMON"
)
var (
	MetricsHTTPPort = &cli.Uint64Flag{
		Name:     "metrics.port",
		Usage:    "Port to run metrics http server on",
		Category: commonCategory,
		Value:    6061,
		EnvVars:  []string{"METRICS_HTTP_PORT"},
	}
)

var CommonFlags = []cli.Flag{
	MetricsHTTPPort,
}

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}

	return merged
}
