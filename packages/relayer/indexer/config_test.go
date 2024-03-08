package indexer

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/urfave/cli/v2"
)

var (
	srcTaikoAddr            = "0x53FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	srcBridgeAddr           = "0x73FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	destBridgeAddr          = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	ethClientTimeout        = "10"
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	blockBatchSize          = "100"
	numGoroutines           = "10"
	subscriptionBackoff     = "30"
	syncMode                = "sync"
	watchMode               = "filter"
	eventName               = relayer.EventNameMessageSent
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.IndexerFlags
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
		assert.Equal(t, common.HexToAddress(srcTaikoAddr), c.SrcTaikoAddress)
		assert.Equal(t, uint64(10), c.ETHClientTimeout)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(100), c.BlockBatchSize)
		assert.Equal(t, uint64(10), c.NumGoroutines)
		assert.Equal(t, uint64(30), c.SubscriptionBackoff)
		assert.Equal(t, SyncMode(syncMode), c.SyncMode)
		assert.Equal(t, WatchMode(watchMode), c.WatchMode)
		assert.Equal(t, eventName, c.EventName)

		c.OpenDBFunc = func() (DB, error) {
			return &mock.DB{}, nil
		}

		c.OpenQueueFunc = func() (queue.Queue, error) {
			return &mock.Queue{}, nil
		}

		// assert.Nil(t, InitFromConfig(context.Background(), new(Indexer), c))

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
		"--" + flags.SrcTaikoAddress.Name, srcTaikoAddr,
		"--" + flags.ETHClientTimeout.Name, ethClientTimeout,
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.BlockBatchSize.Name, blockBatchSize,
		"--" + flags.MaxNumGoroutines.Name, numGoroutines,
		"--" + flags.SubscriptionBackoff.Name, subscriptionBackoff,
		"--" + flags.SyncMode.Name, syncMode,
		"--" + flags.WatchMode.Name, watchMode,
		"--" + flags.EventName.Name, eventName,
	}))
}
