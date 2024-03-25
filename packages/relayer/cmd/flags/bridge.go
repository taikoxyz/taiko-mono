package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	BridgePrivateKey = &cli.StringFlag{
		Name:     "bridgePrivateKey",
		Usage:    "Private key to send a bridge",
		Required: true,
		Category: bridgeCategory,
		EnvVars:  []string{"BRIDGE_PRIVATE_KEY"},
	}
	BridgeMessageValue = &cli.StringFlag{
		Name:     "bridgeMessageValue",
		Usage:    "Value in the bridge message",
		Required: true,
		Category: bridgeCategory,
		EnvVars:  []string{"BRIDGE_MESSAGE_VALUE"},
	}
)

var BridgeFlags = MergeFlags(CommonFlags, QueueFlags, []cli.Flag{
	BridgePrivateKey,
	BridgeMessageValue,
	SrcBridgeAddress,
	DestBridgeAddress,
	SrcTaikoAddress,
})
