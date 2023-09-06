package processor

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
	"github.com/urfave/cli/v2"
)

var (
	destBridgeAddr = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.ProcessorFlags
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}

	return app
}

func TestNewConfigFromCliContext(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)
		assert.Equal(t, "dbuser", c.DatabaseUsername)
		assert.Equal(t, "dbpass", c.DatabasePassword)
		assert.Equal(t, "dbname", c.DatabaseName)
		assert.Equal(t, "dbhost", c.DatabaseHost)
		assert.Equal(t, "queuename", c.QueueUsername)
		assert.Equal(t, "queuepassword", c.QueuePassword)
		assert.Equal(t, "queuehost", c.QueueHost)
		assert.Equal(t, uint64(5555), c.QueuePort)
		assert.Equal(t, "srcRpcUrl", c.SrcRPCUrl)
		assert.Equal(t, "destRpcUrl", c.DestRPCUrl)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestBridgeAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.SrcSignalServiceAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC20VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC721VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC1155VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestTaikoAddress)

		c.OpenDBFunc = func() (DB, error) {
			return &mock.DB{}, nil
		}

		c.OpenQueueFunc = func() (queue.Queue, error) {
			return &mock.Queue{}, nil
		}

		// assert.Nil(t, InitFromConfig(context.Background(), new(Processor), c))

		return err
	}

	assert.Nil(t, app.Run([]string{
		"TestNewConfigFromCliContext",
		"-" + flags.DatabaseUsername.Name, "dbuser",
		"-" + flags.DatabasePassword.Name, "dbpass",
		"-" + flags.DatabaseHost.Name, "dbhost",
		"-" + flags.DatabaseName.Name, "dbname",
		"-" + flags.QueueUsername.Name, "queuename",
		"-" + flags.QueuePassword.Name, "queuepassword",
		"-" + flags.QueueHost.Name, "queuehost",
		"-" + flags.QueuePort.Name, "5555",
		"-" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"-" + flags.DestRPCUrl.Name, "destRpcUrl",
		"-" + flags.DestBridgeAddress.Name, destBridgeAddr,
		"-" + flags.SrcSignalServiceAddress.Name, destBridgeAddr,
		"-" + flags.DestERC721VaultAddress.Name, destBridgeAddr,
		"-" + flags.DestERC20VaultAddress.Name, destBridgeAddr,
		"-" + flags.DestERC1155VaultAddress.Name, destBridgeAddr,
		"-" + flags.DestTaikoAddress.Name, destBridgeAddr,
		"-" + flags.ProcessorPrivateKey.Name, dummyEcdsaKey,
	}))
}
