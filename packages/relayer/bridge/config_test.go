package bridge

import (
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/urfave/cli/v2"
)

func TestNewConfigFromCliContextSetsRPCRequestTimeout(t *testing.T) {
	app := cli.NewApp()
	app.Flags = flags.BridgeFlags
	app.Action = func(ctx *cli.Context) error {
		config, err := NewConfigFromCliContext(ctx)
		assert.NoError(t, err)
		assert.Equal(t, 5*time.Minute, config.ETHClientRequestTimeout)

		return err
	}

	err := app.Run([]string{
		"TestNewConfigFromCliContextSetsRPCRequestTimeout",
		"--" + flags.BridgePrivateKey.Name, "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f",
		"--" + flags.BridgeMessageValue.Name, "1",
		"--" + flags.SrcBridgeAddress.Name, "0x53FaC9201494f0bd17B9892B9fae4d52fe3BD377",
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

	assert.NoError(t, err)
}

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

func Test_parseRequiredAddress(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		wantErr string
	}{
		{
			name:  "a valid address",
			value: "0xC4279588B8dA563D264e286E2ee7CE8c244444d6",
		},
		{
			name:  "lowercase is accepted, checksum casing is not required",
			value: "0xc4279588b8da563d264e286e2ee7ce8c244444d6",
		},
		{
			name:    "not hex at all",
			value:   "not-an-address",
			wantErr: "invalid test address",
		},
		{
			name:    "hex but the wrong length",
			value:   "0xC4279588B8dA563D264e286E2ee7CE8c2444",
			wantErr: "invalid test address",
		},
		{
			// HexToAddress would happily return the zero address here, and a bridge pointed at it
			// would burn every message it was given, so this has to be rejected rather than
			// defaulted.
			name:    "the zero address",
			value:   "0x0000000000000000000000000000000000000000",
			wantErr: "zero address",
		},
		{
			name:    "empty",
			value:   "",
			wantErr: "invalid test address",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			address, err := parseRequiredAddress(tt.value, "test address")

			if tt.wantErr != "" {
				assert.ErrorContains(t, err, tt.wantErr)
				assert.Equal(t, common.Address{}, address)

				return
			}

			assert.NoError(t, err)
			assert.Equal(t, common.HexToAddress(tt.value), address)
		})
	}
}

func TestBridgeName(t *testing.T) {
	assert.Equal(t, "bridge", new(Bridge).Name())
}
