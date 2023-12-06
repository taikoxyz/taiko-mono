package flags

import "github.com/urfave/cli/v2"

var (
	GenesisDate = &cli.StringFlag{
		Name:     "genesisDate",
		Usage:    "Genesis date to start generating data from, YYYY-MM-DD",
		Required: true,
		Category: generatorCategory,
		EnvVars:  []string{"GENESIS_DATE"},
	}
	Regenerate = &cli.StringFlag{
		Name:     "regenerate",
		Usage:    "True to delete all existing data and regenerate from genesis, false to not",
		Required: false,
		Category: generatorCategory,
		EnvVars:  []string{"REGENERATE"},
	}
)
var GeneratorFlags = MergeFlags(CommonFlags, []cli.Flag{
	GenesisDate,
	Regenerate,
})
