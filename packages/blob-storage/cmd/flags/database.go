package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	dbCategory = "DATABASE"
)

var (
	DBHost = &cli.StringFlag{
		Name:     "db.host",
		Usage:    "Database host",
		Required: true,
		Category: dbCategory,
		EnvVars:  []string{"DB_HOST"},
	}
	DBPort = &cli.StringFlag{
		Name:     "db.port",
		Usage:    "Database port",
		Required: true,
		Category: dbCategory,
		EnvVars:  []string{"DB_PORT"},
	}
	DBUsername = &cli.StringFlag{
		Name:     "db.username",
		Usage:    "Database username",
		Required: true,
		Category: dbCategory,
		EnvVars:  []string{"DB_USERNAME"},
	}
	DBPassword = &cli.StringFlag{
		Name:     "db.password",
		Usage:    "Database password",
		Required: true,
		Category: dbCategory,
		EnvVars:  []string{"DB_PASSWORD"},
	}

	DBDatabase = &cli.StringFlag{
		Name:     "db.database",
		Usage:    "Database name",
		Required: true,
		Category: dbCategory,
		EnvVars:  []string{"DB_DATABASE"},
	}
)

var DatabaseFlags = []cli.Flag{
	DBHost,
	DBPort,
	DBUsername,
	DBPassword,
	DBDatabase,
}
