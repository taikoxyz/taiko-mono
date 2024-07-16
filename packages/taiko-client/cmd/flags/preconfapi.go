package flags

import (
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
)

// PreconfAPIFlags contains all preconfirmations API flags
var PreconfAPIFlags = []cli.Flag{
	TaikoL1Address,
	TxGasLimit,
	PreconfAPIHTTPServerPort,
	BlobAllowed,
}
