package watchdog

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/urfave/cli/v2"
)

var (
	dummyEcdsaKey           = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"
	destBridgeAddr          = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	srcBridgeAddr           = "0x33FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	confirmations           = "10"
	confirmationTimeout     = "30"
	backoffRetryInterval    = "20"
	backOffMaxRetrys        = "10"
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	ethClientTimeout        = "10"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.WatchdogFlags
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
		assert.Equal(t, common.HexToAddress(srcBridgeAddr), c.SrcBridgeAddress)
		assert.Equal(t, uint64(10), c.Confirmations)
		assert.Equal(t, uint64(30), c.ConfirmationsTimeout)
		assert.Equal(t, uint64(20), c.BackoffRetryInterval)
		assert.Equal(t, uint64(10), c.BackOffMaxRetrys)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(10), c.ETHClientTimeout)
		assert.Equal(t, uint64(100), c.QueuePrefetch)

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
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.QueueUsername.Name, "queuename",
		"--" + flags.QueuePassword.Name, "queuepassword",
		"--" + flags.QueueHost.Name, "queuehost",
		"--" + flags.QueuePort.Name, "5555",
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.DestBridgeAddress.Name, destBridgeAddr,
		"--" + flags.SrcBridgeAddress.Name, srcBridgeAddr,
		"--" + flags.WatchdogPrivateKey.Name, dummyEcdsaKey,
		"--" + flags.Confirmations.Name, confirmations,
		"--" + flags.ConfirmationTimeout.Name, confirmationTimeout,
		"--" + flags.BackOffRetryInterval.Name, backoffRetryInterval,
		"--" + flags.BackOffMaxRetrys.Name, backOffMaxRetrys,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.ETHClientTimeout.Name, ethClientTimeout,
		"--" + flags.QueuePrefetchCount.Name, "100",
	}))
}
