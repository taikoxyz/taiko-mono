package generator

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/flags"
	"github.com/urfave/cli/v2"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.GeneratorFlags
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

		d, err := time.Parse("2006-01-02", "2023-11-03")
		assert.Nil(t, err)

		assert.Equal(t, d, c.GenesisDate)

		c.OpenDBFunc = func() (DB, error) {
			return nil, nil
		}

		assert.Nil(t, InitFromConfig(context.Background(), new(Generator), c))

		return err
	}

	assert.Nil(t, app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.GenesisDate.Name, "2023-11-03",
	}))
}
