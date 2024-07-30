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
)

// PreconfAPIFlags contains all preconfirmations API flags
var PreconfAPIFlags = []cli.Flag{
	TaikoL1Address,
	TxGasLimit,
	PreconfAPIHTTPServerPort,
	BlobAllowed,
	PollingInterval,
	L2HTTPEndpoint,
	Verbosity,
	LogJSON,
	DBPath,
}
