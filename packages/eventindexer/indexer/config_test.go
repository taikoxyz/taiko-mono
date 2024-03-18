package indexer

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/urfave/cli/v2"
)

var (
	metricsHttpPort         = "1001"
	l1TaikoAddress          = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	bridgeAddress           = "0x73FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	assignmentHookAddress   = "0x83FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	swapAddresses           = "0x33FaC9201494f0bd17B9892B9fae4d52fe3BD377,0x13FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	ethClientTimeout        = "30"
	blockBatchSize          = "100"
	subscriptionBackoff     = "30"
	syncMode                = "sync"
	layer                   = "l1"
	rpcUrl                  = "rpcUrl"
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
		assert.Equal(t, "rpcUrl", c.RPCUrl)
		assert.Equal(t, uint64(1001), c.MetricsHTTPPort)
		assert.Equal(t, common.HexToAddress(l1TaikoAddress), c.L1TaikoAddress)
		assert.Equal(t, common.HexToAddress(bridgeAddress), c.BridgeAddress)
		assert.Equal(t, common.HexToAddress(assignmentHookAddress), c.AssignmentHookAddress)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(30), c.ETHClientTimeout)
		assert.Equal(t, uint64(100), c.BlockBatchSize)
		assert.Equal(t, uint64(30), c.SubscriptionBackoff)
		assert.Equal(t, SyncMode(syncMode), c.SyncMode)
		assert.Equal(t, true, c.IndexNFTs)
		assert.Equal(t, layer, c.Layer)
		assert.Equal(t, rpcUrl, c.RPCUrl)
		assert.NotNil(t, c.OpenDBFunc)

		// assert.Nil(t, InitFromConfig(context.Background(), new(Indexer), c))

		return err
	}

	assert.Nil(t, app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.L1TaikoAddress.Name, l1TaikoAddress,
		"--" + flags.BridgeAddress.Name, bridgeAddress,
		"--" + flags.SwapAddresses.Name, swapAddresses,
		"--" + flags.AssignmentHookAddress.Name, assignmentHookAddress,
		"--" + flags.MetricsHTTPPort.Name, metricsHttpPort,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.ETHClientTimeout.Name, ethClientTimeout,
		"--" + flags.BlockBatchSize.Name, blockBatchSize,
		"--" + flags.SubscriptionBackoff.Name, subscriptionBackoff,
		"--" + flags.SyncMode.Name, syncMode,
		"--" + flags.IndexNFTs.Name,
		"--" + flags.Layer.Name, layer,
		"--" + flags.IndexerRPCUrl.Name, rpcUrl,
	}))
}
