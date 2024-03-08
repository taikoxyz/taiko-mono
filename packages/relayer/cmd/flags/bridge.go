package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	BridgePrivateKey = &cli.StringFlag{
		Name:     "bridgePrivateKey",
		Usage:    "Private key to send a bridge",
		Required: true,
		Category: watchdogCategory,
		EnvVars:  []string{"BRIDGE_PRIVATE_KEY"},
	}
)

var BridgeFlags = MergeFlags(CommonFlags, QueueFlags, []cli.Flag{
	BridgePrivateKey,
	// optional
	Confirmations,
	ConfirmationTimeout,
	BackOffRetryInterval,
	BackOffMaxRetrys,
	QueuePrefetchCount,
	DestBridgeAddress,
	SrcBridgeAddress,
})
