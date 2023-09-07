package flags

import "github.com/urfave/cli/v2"

var GeneratorFlags = MergeFlags(CommonFlags, []cli.Flag{})
