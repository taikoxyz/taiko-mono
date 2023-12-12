package healthchecker

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/mock"
	"github.com/urfave/cli/v2"
)

var (
	guardianProverAddress   = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	HTTPPort                = "1000"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.HealthCheckFlags
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
		assert.Equal(t, "l1RpcUrl", c.L1RPCUrl)
		assert.Equal(t, "l2RpcUrl", c.L2RPCUrl)
		assert.Equal(t, guardianProverAddress, c.GuardianProverContractAddress)
		assert.Equal(t, []string{"*"}, c.CORSOrigins)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(1000), c.HTTPPort)

		c.OpenDBFunc = func() (DB, error) {
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
		"--" + flags.L1RPCUrl.Name, "l1RpcUrl",
		"--" + flags.L2RPCUrl.Name, "l2RpcUrl",
		"--" + flags.CORSOrigins.Name, "*",
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.HTTPPort.Name, HTTPPort,
		"--" + flags.GuardianProverContractAddress.Name, guardianProverAddress,
	}))
}
