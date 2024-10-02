package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// Required flags used by preconfirmations api.
var (
	PreconfAPIHTTPServerPort = &cli.Uint64Flag{
		Name:     "preconfapi.port",
		Usage:    "Port to expose for http server",
		Category: preconfAPICategory,
		Value:    9871,
		EnvVars:  []string{"PRECONFAPI_PORT"},
	}
	PollingInterval = &cli.DurationFlag{
		Name:     "preconfapi.pollingInterval",
		Usage:    "Interval at which to poll",
		Category: preconfAPICategory,
		Value:    1 * time.Second,
		EnvVars:  []string{"POLLING_INTERVAL"},
	}
	DBPath = &cli.StringFlag{
		Name:     "preconfapi.dbPath",
		Usage:    "DB Path",
		Category: preconfAPICategory,
		Value:    "/tmp/badgerdb",
		EnvVars:  []string{"DB_PATH"},
	}
	CORSOrigins = &cli.StringSliceFlag{
		Name:     "preconfapi.corsOrigins",
		Usage:    "Cors Origins",
		Category: preconfAPICategory,
		EnvVars:  []string{"CORS_ORIGINS"},
		Required: true,
	}
	PreconfTaskManagerAddress = &cli.StringFlag{
		Name:     "preconfTaskManager",
		Usage:    "preconfTaskManager address",
		Required: true,
		Category: preconfAPICategory,
		EnvVars:  []string{"PRECONF_TASK_MANAGER"},
	}
)

// PreconfAPIFlags contains all preconfirmations API flags
var PreconfAPIFlags = MergeFlags(CommonFlags, []cli.Flag{
	TxGasLimit,
	PreconfAPIHTTPServerPort,
	BlobAllowed,
	PollingInterval,
	L2HTTPEndpoint,
	DBPath,
	CORSOrigins,
	PreconfTaskManagerAddress,
})
