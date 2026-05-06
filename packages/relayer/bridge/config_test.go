package bridge

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/urfave/cli/v2"
)

func TestNewConfigFromCliContextRejectsInvalidBridgeAddress(t *testing.T) {
	app := cli.NewApp()
	app.Flags = flags.BridgeFlags
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}

	err := app.Run([]string{
		"TestNewConfigFromCliContextRejectsInvalidBridgeAddress",
		"--" + flags.BridgePrivateKey.Name, "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f",
		"--" + flags.BridgeMessageValue.Name, "1",
		"--" + flags.SrcBridgeAddress.Name, "0x123",
		"--" + flags.DestBridgeAddress.Name, "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.QueueUsername.Name, "queueuser",
		"--" + flags.QueuePassword.Name, "queuepass",
		"--" + flags.QueueHost.Name, "queuehost",
		"--" + flags.QueuePort.Name, "5555",
	})

	assert.ErrorContains(t, err, "invalid srcBridgeAddress")
}
