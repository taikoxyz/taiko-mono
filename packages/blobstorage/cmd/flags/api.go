package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	apiCategory = "API"
)

var (
	Port = &cli.UintFlag{
		Name:     "httpPort",
		Usage:    "Port to run server on",
		Category: apiCategory,
		EnvVars:  []string{"HTTP_PORT"},
	}
)

var APIFlags = MergeFlags(DatabaseFlags, CommonFlags, []cli.Flag{
	Port,
})
