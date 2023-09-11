package flags

import "github.com/urfave/cli/v2"

var (
	GenesisDate = &cli.StringFlag{
		Name:     "genesisDate",
		Usage:    "Genesis date to start genrating data from, YYYY-MM-DD",
		Required: true,
		Category: generatorCategory,
		EnvVars:  []string{"GENESIS_DATE"},
	}
)
var GeneratorFlags = MergeFlags(CommonFlags, []cli.Flag{
	GenesisDate,
})
