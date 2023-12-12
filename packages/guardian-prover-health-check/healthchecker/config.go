package healthchecker

import (
	"database/sql"
	"strings"

	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
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
	DatabaseUsername              string
	DatabasePassword              string
	DatabaseName                  string
	DatabaseHost                  string
	DatabaseMaxIdleConns          uint64
	DatabaseMaxOpenConns          uint64
	DatabaseMaxConnLifetime       uint64
	CORSOrigins                   []string
	Backoff                       uint64
	HTTPPort                      uint64
	GuardianProverContractAddress string
	L1RPCUrl                      string
	L2RPCUrl                      string
	OpenDBFunc                    func() (DB, error)
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	return &Config{
		DatabaseUsername:              c.String(flags.DatabaseUsername.Name),
		DatabasePassword:              c.String(flags.DatabasePassword.Name),
		DatabaseName:                  c.String(flags.DatabaseName.Name),
		DatabaseHost:                  c.String(flags.DatabaseHost.Name),
		DatabaseMaxIdleConns:          c.Uint64(flags.DatabaseMaxIdleConns.Name),
		DatabaseMaxOpenConns:          c.Uint64(flags.DatabaseMaxOpenConns.Name),
		DatabaseMaxConnLifetime:       c.Uint64(flags.DatabaseConnMaxLifetime.Name),
		CORSOrigins:                   strings.Split(c.String(flags.CORSOrigins.Name), ","),
		GuardianProverContractAddress: c.String(flags.GuardianProverContractAddress.Name),
		L1RPCUrl:                      c.String(flags.L1RPCUrl.Name),
		L2RPCUrl:                      c.String(flags.L2RPCUrl.Name),
		HTTPPort:                      c.Uint64(flags.HTTPPort.Name),
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
