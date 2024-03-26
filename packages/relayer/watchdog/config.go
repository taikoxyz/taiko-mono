package watchdog

import (
	"crypto/ecdsa"
	"fmt"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue/rabbitmq"
	"github.com/urfave/cli/v2"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	pkgFlags "github.com/taikoxyz/taiko-mono/packages/relayer/pkg/flags"
)

type Config struct {
	// address configs
	SrcBridgeAddress  common.Address
	DestBridgeAddress common.Address

	// private key
	WatchdogPrivateKey *ecdsa.PrivateKey

	// processing configs
	Confirmations        uint64
	ConfirmationsTimeout uint64
	EnableTaikoL2        bool

	// backoff configs
	BackoffRetryInterval uint64
	BackOffMaxRetrys     uint64

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
	QueuePrefetch uint64
	// rpc configs
	SrcRPCUrl        string
	DestRPCUrl       string
	ETHClientTimeout uint64
	OpenQueueFunc    func() (queue.Queue, error)
	OpenDBFunc       func() (DB, error)

	TxmgrConfigs *txmgr.CLIConfig
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	watchdogPrivateKey, err := crypto.ToECDSA(
		common.Hex2Bytes(c.String(flags.WatchdogPrivateKey.Name)),
	)
	if err != nil {
		return nil, fmt.Errorf("invalid watchdogPrivateKey: %w", err)
	}

	return &Config{
		WatchdogPrivateKey:      watchdogPrivateKey,
		DestBridgeAddress:       common.HexToAddress(c.String(flags.DestBridgeAddress.Name)),
		SrcBridgeAddress:        common.HexToAddress(c.String(flags.SrcBridgeAddress.Name)),
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
		QueuePrefetch:           c.Uint64(flags.QueuePrefetchCount.Name),
		SrcRPCUrl:               c.String(flags.SrcRPCUrl.Name),
		DestRPCUrl:              c.String(flags.DestRPCUrl.Name),
		Confirmations:           c.Uint64(flags.Confirmations.Name),
		ConfirmationsTimeout:    c.Uint64(flags.ConfirmationTimeout.Name),
		EnableTaikoL2:           c.Bool(flags.EnableTaikoL2.Name),
		BackoffRetryInterval:    c.Uint64(flags.BackOffRetryInterval.Name),
		BackOffMaxRetrys:        c.Uint64(flags.BackOffMaxRetrys.Name),
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
				Username:      c.String(flags.QueueUsername.Name),
				Password:      c.String(flags.QueuePassword.Name),
				Host:          c.String(flags.QueueHost.Name),
				Port:          c.String(flags.QueuePort.Name),
				PrefetchCount: c.Uint64(flags.QueuePrefetchCount.Name),
			}

			q, err := rabbitmq.NewQueue(opts)
			if err != nil {
				return nil, err
			}

			return q, nil
		},
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.SrcRPCUrl.Name),
			watchdogPrivateKey,
			c,
		),
	}, nil
}
