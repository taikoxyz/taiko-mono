package api

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

var (
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	HTTPPort                = "1000"
	destTaikoAddress        = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.APIFlags
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
		assert.Equal(t, []string{"*"}, c.CORSOrigins)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(1000), c.HTTPPort)
		assert.Equal(t, "srcRpcUrl", c.SrcRPCUrl)
		assert.Equal(t, "destRpcUrl", c.DestRPCUrl)
		assert.Equal(t, 5*time.Minute, c.ETHClientRequestTimeout)
		assert.Equal(t, destTaikoAddress, c.DestTaikoAddress.Hex())

		c.OpenDBFunc = func() (db.DB, error) {
			return &mock.DB{}, nil
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
		"--" + flags.CORSOrigins.Name, "*",
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.HTTPPort.Name, HTTPPort,
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.DestTaikoAddress.Name, destTaikoAddress,
	}))
}

func TestAPIName(t *testing.T) {
	assert.Equal(t, "api", new(API).Name())
}

func TestNewConfigFromCliContextSplitsMultipleCORSOrigins(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)

		// The flag arrives as one comma-separated string, and each origin has to reach the
		// middleware separately or only the first one is allowed through.
		assert.Equal(t, []string{"https://bridge.taiko.xyz", "http://localhost:3000"}, c.CORSOrigins)
		assert.InDelta(t, 1.25, c.ProcessingFeeMultiplier, 0.0001)

		return err
	}

	assert.Nil(t, app.Run([]string{
		"TestNewConfigFromCliContextSplitsMultipleCORSOrigins",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.CORSOrigins.Name, "https://bridge.taiko.xyz,http://localhost:3000",
		"--" + flags.ProcessingFeeMultiplier.Name, "1.25",
		"--" + flags.HTTPPort.Name, HTTPPort,
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.DestTaikoAddress.Name, destTaikoAddress,
	}))
}
