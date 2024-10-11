package flags

import (
	"github.com/urfave/cli/v2"
)

// Optional flags used by driver.
var (
	StressStartingBlockID = &cli.Uint64Flag{
		Name:     "stress.startingBlockID",
		Usage:    "Start block id of the L1 chain",
		Value:    380000,
		Category: stressCategory,
	}
	StressEndingBlockID = &cli.Uint64Flag{
		Name:     "stress.endingBlockID",
		Usage:    "End block id of the L1 chain",
		Value:    400000,
		Category: stressCategory,
	}
	StressZkType = &cli.StringFlag{
		Name:     "stress.zkType",
		Usage:    "ZkType is the type of zk proof to generate.",
		Value:    "risc0",
		Category: stressCategory,
	}
	StressDBPath = &cli.StringFlag{
		Name:     "stress.dbPath",
		Usage:    "Path to the stress test database.",
		Value:    "./db",
		Category: stressCategory,
	}
	StressLogPath = &cli.StringFlag{
		Name:     "stress.logPath",
		Usage:    "Path to the stress test log file.",
		Value:    "./logs",
		Category: stressCategory,
	}
)

// StressFlags All stress test flags.
var StressFlags = MergeFlags(CommonFlags, []cli.Flag{
	StressStartingBlockID,
	StressEndingBlockID,
	StressZkType,
})
