package indexer

import (
	"database/sql"
	"strings"

	"github.com/ethereum/go-ethereum/common"
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
	RPCUrl                  string
	MetricsHTTPPort         uint64
	ETHClientTimeout        uint64
	L1TaikoAddress          common.Address
	BridgeAddress           common.Address
	AssignmentHookAddress   common.Address
	SgxVerifierAddress      common.Address
	SwapAddresses           []common.Address
	BlockBatchSize          uint64
	SubscriptionBackoff     uint64
	SyncMode                SyncMode
	IndexNFTs               bool
	Layer                   string
	OpenDBFunc              func() (DB, error)
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	// swapAddresses is a comma-delinated list of addresses to index, so we need to
	// parse that from a single string.
	swapAddresses := strings.Split(c.String(flags.SwapAddresses.Name), ",")

	swaps := make([]common.Address, 0)

	for _, v := range swapAddresses {
		swaps = append(swaps, common.HexToAddress(v))
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
		ETHClientTimeout:        c.Uint64(flags.ETHClientTimeout.Name),
		L1TaikoAddress:          common.HexToAddress(c.String(flags.L1TaikoAddress.Name)),
		BridgeAddress:           common.HexToAddress(c.String(flags.BridgeAddress.Name)),
		AssignmentHookAddress:   common.HexToAddress(c.String(flags.AssignmentHookAddress.Name)),
		SgxVerifierAddress:      common.HexToAddress(flags.SgxVerifierAddress.Name),
		SwapAddresses:           swaps,
		BlockBatchSize:          c.Uint64(flags.BlockBatchSize.Name),
		SubscriptionBackoff:     c.Uint64(flags.SubscriptionBackoff.Name),
		RPCUrl:                  c.String(flags.IndexerRPCUrl.Name),
		SyncMode:                SyncMode(c.String(flags.SyncMode.Name)),
		IndexNFTs:               c.Bool(flags.IndexNFTs.Name),
		Layer:                   c.String(flags.Layer.Name),
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
