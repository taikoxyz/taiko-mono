package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	serverCategory = "SERVER"
)

var (
	Port = &cli.UintFlag{
		Name:     "port",
		Usage:    "Port to run server on",
		Category: indexerCategory,
		EnvVars:  []string{"PORT"},
	}
)

var ServerFlags = MergeFlags(DatabaseFlags, CommonFlags, []cli.Flag{
	Port,
})
