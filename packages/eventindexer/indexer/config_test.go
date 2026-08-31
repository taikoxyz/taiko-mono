package indexer

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/urfave/cli/v2"
)

var (
	metricsHttpPort         = "1001"
	shastaInboxAddress      = "0x53FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	bridgeAddress           = "0x73FaC9201494f0bd17B9892B9fae4d52fe3BD377"
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
		assert.Equal(t, common.HexToAddress(shastaInboxAddress), c.ShastaInboxAddress)
		assert.Equal(t, common.HexToAddress(bridgeAddress), c.BridgeAddress)
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
		"--" + flags.ShastaInboxAddress.Name, shastaInboxAddress,
		"--" + flags.BridgeAddress.Name, bridgeAddress,
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

func TestConfigValidate(t *testing.T) {
	tests := []struct {
		name    string
		cfg     *Config
		wantErr error
	}{
		{
			name: "l1 requires Shasta inbox",
			cfg: &Config{
				Layer:    Layer1,
				SyncMode: Sync,
			},
			wantErr: eventindexer.ErrNoShastaInboxAddress,
		},
		{
			name: "l1 accepts Shasta inbox",
			cfg: &Config{
				Layer:              Layer1,
				SyncMode:           Sync,
				ShastaInboxAddress: common.HexToAddress(shastaInboxAddress),
			},
		},
		{
			name: "l2 does not require Shasta inbox",
			cfg: &Config{
				Layer:    Layer2,
				SyncMode: Sync,
			},
		},
		{
			name: "invalid sync mode",
			cfg: &Config{
				Layer:    Layer2,
				SyncMode: SyncMode("invalid"),
			},
			wantErr: eventindexer.ErrInvalidMode,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.validate()
			if tt.wantErr == nil {
				assert.NoError(t, err)
				return
			}

			assert.ErrorIs(t, err, tt.wantErr)
		})
	}
}

func TestConfigValidateRejectsInvalidLayer(t *testing.T) {
	err := (&Config{
		Layer:    "L1",
		SyncMode: Sync,
	}).validate()

	assert.ErrorIs(t, err, eventindexer.ErrInvalidLayer)
}

func TestInitFromConfigValidatesBeforeOpeningDatabase(t *testing.T) {
	databaseOpened := false
	cfg := &Config{
		Layer:    Layer1,
		SyncMode: Sync,
		OpenDBFunc: func() (db.DB, error) {
			databaseOpened = true
			return nil, nil
		},
	}

	err := InitFromConfig(context.Background(), new(Indexer), cfg)

	assert.ErrorIs(t, err, eventindexer.ErrNoShastaInboxAddress)
	assert.False(t, databaseOpened)
}

func TestInitFromConfigRejectsInvalidLayerBeforeOpeningDatabase(t *testing.T) {
	databaseOpened := false
	cfg := &Config{
		Layer:    "L1",
		SyncMode: Sync,
		OpenDBFunc: func() (db.DB, error) {
			databaseOpened = true
			return nil, assert.AnError
		},
	}

	err := InitFromConfig(context.Background(), new(Indexer), cfg)

	assert.ErrorIs(t, err, eventindexer.ErrInvalidLayer)
	assert.False(t, databaseOpened)
}
