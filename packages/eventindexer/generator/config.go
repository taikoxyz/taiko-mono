package generator

import (
	"database/sql"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/urfave/cli/v2"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}

type Config struct {
	// db configs
	DatabaseUsername        string
	DatabasePassword        string
	DatabaseName            string
	DatabaseHost            string
	DatabaseMaxIdleConns    uint64
	DatabaseMaxOpenConns    uint64
	DatabaseMaxConnLifetime uint64
	MetricsHTTPPort         uint64
	GenesisDate             time.Time
	Regenerate              bool
	OpenDBFunc              func() (DB, error)
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	date, err := time.Parse("2006-01-02", c.String(flags.GenesisDate.Name))
	if err != nil {
		return nil, err
	}

	return &Config{
		DatabaseUsername:        c.String(flags.DatabaseUsername.Name),
		DatabasePassword:        c.String(flags.DatabasePassword.Name),
		DatabaseName:            c.String(flags.DatabaseName.Name),
		DatabaseHost:            c.String(flags.DatabaseHost.Name),
		DatabaseMaxIdleConns:    c.Uint64(flags.DatabaseMaxIdleConns.Name),
		DatabaseMaxOpenConns:    c.Uint64(flags.DatabaseMaxOpenConns.Name),
		DatabaseMaxConnLifetime: c.Uint64(flags.DatabaseConnMaxLifetime.Name),
		MetricsHTTPPort:         c.Uint64(flags.MetricsHTTPPort.Name),
		GenesisDate:             date,
		Regenerate:              c.Bool(flags.Regenerate.Name),
		OpenDBFunc: func() (DB, error) {
			return db.OpenDBConnection(db.DBConnectionOpts{
				Name:            c.String(flags.DatabaseUsername.Name),
				Password:        c.String(flags.DatabasePassword.Name),
				Database:        c.String(flags.DatabaseName.Name),
				Host:            c.String(flags.DatabaseHost.Name),
				MaxIdleConns:    c.Uint64(flags.DatabaseMaxIdleConns.Name),
				MaxOpenConns:    c.Uint64(flags.DatabaseMaxOpenConns.Name),
				MaxConnLifetime: c.Uint64(flags.DatabaseConnMaxLifetime.Name),
				OpenFunc: func(dsn string) (*db.DB, error) {
					gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
						Logger: logger.Default.LogMode(logger.Silent),
					})
					if err != nil {
						return nil, err
					}

					return db.New(gormDB), nil
				},
			})
		},
	}, nil
}
