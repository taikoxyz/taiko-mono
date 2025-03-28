package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

var (
	consolidatorCategory = "CONSOLIDATOR"
)

var (
	Interval = &cli.DurationFlag{
		Name:     "interval",
		Usage:    "Interval to check for new blocks",
		Required: false,
		Value:    12 * time.Second,
		Category: consolidatorCategory,
		EnvVars:  []string{"INTERVAL"},
	}
)
var ConsolidatorFlags = MergeFlags(CommonFlags, []cli.Flag{
	Interval,
})
