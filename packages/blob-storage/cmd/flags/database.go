package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	dbCategory = "DATABASE"
)

var (
	DatabaseUsername = &cli.StringFlag{
		Name:     "db.username",
		Usage:    "Database connection username",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_USER"},
	}
	DatabasePassword = &cli.StringFlag{
		Name:     "db.password",
		Usage:    "Database connection password",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_PASSWORD"},
	}
	DatabaseHost = &cli.StringFlag{
		Name:     "db.host",
		Usage:    "Database connection host",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_HOST"},
	}
	DatabaseName = &cli.StringFlag{
		Name:     "db.name",
		Usage:    "Database connection name",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_NAME"},
	}
	DatabaseMaxIdleConns = &cli.Uint64Flag{
		Name:     "db.maxIdleConns",
		Usage:    "Database max idle connections",
		Value:    50,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_MAX_IDLE_CONNS"},
	}
	DatabaseMaxOpenConns = &cli.Uint64Flag{
		Name:     "db.maxOpenConns",
		Usage:    "Database max open connections",
		Value:    200,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_MAX_OPEN_CONNS"},
	}
	DatabaseConnMaxLifetime = &cli.Uint64Flag{
		Name:     "db.connMaxLifetime",
		Usage:    "Database connection max lifetime in seconds",
		Value:    10,
		Category: commonCategory,
		EnvVars:  []string{"DATABASE_CONN_MAX_LIFETIME"},
	}
)

var DatabaseFlags = []cli.Flag{
	DatabaseHost,
	DatabaseUsername,
	DatabasePassword,
	DatabaseName,
	DatabaseConnMaxLifetime,
	DatabaseMaxOpenConns,
	DatabaseMaxIdleConns,
}
