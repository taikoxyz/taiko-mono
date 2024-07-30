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
		Usage:    "The rpc endpoint of L1 preconfer",
		Category: preconfAPICategory,
		Value:    1 * time.Second,
		EnvVars:  []string{"POLLING_INTERVAL"},
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
}
