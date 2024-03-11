package server

import (
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/cmd/flags"
	"github.com/urfave/cli/v2"
)

type Config struct {
	DBHost     string
	DBPort     int
	DBUsername string
	DBPassword string
	DBDatabase string
	Port       uint
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	return &Config{
		DBHost:     c.String(flags.DBHost.Name),
		DBPort:     c.Int(flags.DBPort.Name),
		DBUsername: c.String(flags.DBUsername.Name),
		DBPassword: c.String(flags.DBPassword.Name),
		DBDatabase: c.String(flags.DBDatabase.Name),
		Port:       c.Uint(flags.Port.Name),
	}, nil
}
