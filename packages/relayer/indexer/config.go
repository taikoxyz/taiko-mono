package indexer

import (
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue/rabbitmq"
	"github.com/urfave/cli/v2"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Config struct {
	// address configs
	SrcBridgeAddress  common.Address
	SrcTaikoAddress   common.Address
	DestBridgeAddress common.Address
	// db configs
	DatabaseUsername        string
	DatabasePassword        string
	DatabaseName            string
	DatabaseHost            string
	DatabaseMaxIdleConns    uint64
	DatabaseMaxOpenConns    uint64
	DatabaseMaxConnLifetime uint64
	// queue configs
	QueueUsername string
	QueuePassword string
	QueueHost     string
	QueuePort     uint64
	// rpc configs
	SrcRPCUrl           string
	DestRPCUrl          string
	ETHClientTimeout    uint64
	CORSOrigins         []string
	BlockBatchSize      uint64
	NumGoroutines       uint64
	SubscriptionBackoff uint64
	SyncMode            SyncMode
	WatchMode           WatchMode
	HTTPPort            uint64
	OpenQueueFunc       func() (queue.Queue, error)
	OpenDBFunc          func() (DB, error)
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	return &Config{
		SrcBridgeAddress:        common.HexToAddress(c.String(flags.SrcBridgeAddress.Name)),
		SrcTaikoAddress:         common.HexToAddress(c.String(flags.SrcTaikoAddress.Name)),
		DestBridgeAddress:       common.HexToAddress(c.String(flags.DestBridgeAddress.Name)),
		DatabaseUsername:        c.String(flags.DatabaseUsername.Name),
		DatabasePassword:        c.String(flags.DatabasePassword.Name),
		DatabaseName:            c.String(flags.DatabaseName.Name),
		DatabaseHost:            c.String(flags.DatabaseHost.Name),
		DatabaseMaxIdleConns:    c.Uint64(flags.DatabaseMaxIdleConns.Name),
		DatabaseMaxOpenConns:    c.Uint64(flags.DatabaseMaxOpenConns.Name),
		DatabaseMaxConnLifetime: c.Uint64(flags.DatabaseConnMaxLifetime.Name),
		QueueUsername:           c.String(flags.QueueUsername.Name),
		QueuePassword:           c.String(flags.QueuePassword.Name),
		QueuePort:               c.Uint64(flags.QueuePort.Name),
		QueueHost:               c.String(flags.QueueHost.Name),
		SrcRPCUrl:               c.String(flags.SrcRPCUrl.Name),
		DestRPCUrl:              c.String(flags.DestRPCUrl.Name),
		CORSOrigins:             strings.Split(c.String(flags.CORSOrigins.Name), ","),
		BlockBatchSize:          c.Uint64(flags.BlockBatchSize.Name),
		NumGoroutines:           c.Uint64(flags.MaxNumGoroutines.Name),
		SubscriptionBackoff:     c.Uint64(flags.SubscriptionBackoff.Name),
		WatchMode:               WatchMode(c.String(flags.WatchMode.Name)),
		SyncMode:                SyncMode(c.String(flags.SyncMode.Name)),
		HTTPPort:                c.Uint64(flags.HTTPPort.Name),
		ETHClientTimeout:        c.Uint64(flags.ETHClientTimeout.Name),
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
		OpenQueueFunc: func() (queue.Queue, error) {
			opts := queue.NewQueueOpts{
				Username: c.String(flags.QueueUsername.Name),
				Password: c.String(flags.QueuePassword.Name),
				Host:     c.String(flags.QueueHost.Name),
				Port:     c.String(flags.QueuePort.Name),
			}

			q, err := rabbitmq.NewQueue(opts)
			if err != nil {
				return nil, err
			}

			return q, nil
		},
	}, nil
}
