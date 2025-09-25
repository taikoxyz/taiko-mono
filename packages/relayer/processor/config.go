package processor

import (
	"crypto/ecdsa"
	"errors"
	"fmt"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/relayer/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue/rabbitmq"
)

// hopConfig is a config struct that must be provided for an individual
// hop, when the processor is not configured to only process srcChain => destChain.
// for instance, when going from L2A to L2B, we have a hop of the shared "L1".
// the hopConfig in this case should be the L1 signalServiceAddress, taikoAddress,
// and rpcURL. If we have multiple hops, such as an L3 deployed on L2A to L2B,
// the hops would be L2A and L1, and multiple configs should be passed in.
type hopConfig struct {
	signalServiceAddress common.Address
	taikoAddress         common.Address
	rpcURL               string
}

// Config is a struct used to initialize a processor.
type Config struct {
	// address configs
	SrcSignalServiceAddress common.Address
	DestBridgeAddress       common.Address
	DestERC721VaultAddress  common.Address
	DestERC20VaultAddress   common.Address
	DestERC1155VaultAddress common.Address
	DestTaikoAddress        common.Address
	DestQuotaManagerAddress common.Address

	// private key
	ProcessorPrivateKey *ecdsa.PrivateKey

	TargetTxHash *common.Hash

	// processing configs
	HeaderSyncInterval   uint64
	Confirmations        uint64
	ConfirmationsTimeout uint64
	ProfitableOnly       bool
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
	OpenDBFunc       func() (db.DB, error)

	hopConfigs []hopConfig

	CacheOption                        int
	UnprofitableMessageQueueExpiration *string

	TxmgrConfigs *txmgr.CLIConfig

	MaxMessageRetries uint64
	MinFeeToProcess   uint64
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	processorPrivateKey, err := crypto.ToECDSA(
		common.Hex2Bytes(c.String(flags.ProcessorPrivateKey.Name)),
	)
	if err != nil {
		return nil, fmt.Errorf("invalid processorPrivateKey: %w", err)
	}

	hopSignalServiceAddresses := c.StringSlice(flags.HopSignalServiceAddresses.Name)
	hopTaikoAddresses := c.StringSlice(flags.HopTaikoAddresses.Name)
	hopRPCUrls := c.StringSlice(flags.HopRPCUrls.Name)

	if len(hopSignalServiceAddresses) != len(hopTaikoAddresses) ||
		len(hopSignalServiceAddresses) != len(hopRPCUrls) ||
		len(hopTaikoAddresses) != len(hopRPCUrls) {
		return nil, errors.New("all hop parameters must be of same length")
	}

	hopConfigs := []hopConfig{}
	for i, hopSignalServiceAddress := range hopSignalServiceAddresses {
		hopConfigs = append(hopConfigs, hopConfig{
			signalServiceAddress: common.HexToAddress(hopSignalServiceAddress),
			rpcURL:               hopRPCUrls[i],
			taikoAddress:         common.HexToAddress(hopTaikoAddresses[i]),
		})
	}

	var targetTxHash *common.Hash

	if c.IsSet(flags.TargetTxHash.Name) {
		hash := common.HexToHash(c.String(flags.TargetTxHash.Name))
		targetTxHash = &hash
	}

	var unprofitableMessageQueueExpiration *string

	if c.IsSet(flags.UnprofitableMessageQueueExpiration.Name) {
		u := c.String(flags.UnprofitableMessageQueueExpiration.Name)
		unprofitableMessageQueueExpiration = &u
	}

	var destQuotaManagerAddress common.Address
	if c.IsSet(flags.DestQuotaManagerAddress.Name) {
		destQuotaManagerAddress = common.HexToAddress(c.String(flags.DestQuotaManagerAddress.Name))
	}

	return &Config{
		hopConfigs:                         hopConfigs,
		ProcessorPrivateKey:                processorPrivateKey,
		SrcSignalServiceAddress:            common.HexToAddress(c.String(flags.SrcSignalServiceAddress.Name)),
		DestTaikoAddress:                   common.HexToAddress(c.String(flags.DestTaikoAddress.Name)),
		DestBridgeAddress:                  common.HexToAddress(c.String(flags.DestBridgeAddress.Name)),
		DestERC721VaultAddress:             common.HexToAddress(c.String(flags.DestERC721VaultAddress.Name)),
		DestERC20VaultAddress:              common.HexToAddress(c.String(flags.DestERC20VaultAddress.Name)),
		DestERC1155VaultAddress:            common.HexToAddress(c.String(flags.DestERC1155VaultAddress.Name)),
		DestQuotaManagerAddress:            destQuotaManagerAddress,
		DatabaseUsername:                   c.String(flags.DatabaseUsername.Name),
		DatabasePassword:                   c.String(flags.DatabasePassword.Name),
		DatabaseName:                       c.String(flags.DatabaseName.Name),
		DatabaseHost:                       c.String(flags.DatabaseHost.Name),
		DatabaseMaxIdleConns:               c.Uint64(flags.DatabaseMaxIdleConns.Name),
		DatabaseMaxOpenConns:               c.Uint64(flags.DatabaseMaxOpenConns.Name),
		DatabaseMaxConnLifetime:            c.Uint64(flags.DatabaseConnMaxLifetime.Name),
		QueueUsername:                      c.String(flags.QueueUsername.Name),
		QueuePassword:                      c.String(flags.QueuePassword.Name),
		QueuePort:                          c.Uint64(flags.QueuePort.Name),
		QueueHost:                          c.String(flags.QueueHost.Name),
		QueuePrefetch:                      c.Uint64(flags.QueuePrefetchCount.Name),
		SrcRPCUrl:                          c.String(flags.SrcRPCUrl.Name),
		DestRPCUrl:                         c.String(flags.DestRPCUrl.Name),
		HeaderSyncInterval:                 c.Uint64(flags.HeaderSyncInterval.Name),
		Confirmations:                      c.Uint64(flags.Confirmations.Name),
		ConfirmationsTimeout:               c.Uint64(flags.ConfirmationTimeout.Name),
		EnableTaikoL2:                      c.Bool(flags.EnableTaikoL2.Name),
		ProfitableOnly:                     c.Bool(flags.ProfitableOnly.Name),
		BackoffRetryInterval:               c.Uint64(flags.BackOffRetryInterval.Name),
		BackOffMaxRetrys:                   c.Uint64(flags.BackOffMaxRetrys.Name),
		ETHClientTimeout:                   c.Uint64(flags.ETHClientTimeout.Name),
		TargetTxHash:                       targetTxHash,
		CacheOption:                        c.Int(flags.CacheOption.Name),
		UnprofitableMessageQueueExpiration: unprofitableMessageQueueExpiration,
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.DestRPCUrl.Name),
			processorPrivateKey,
			c,
		),
		MaxMessageRetries: c.Uint64(flags.MaxMessageRetries.Name),
		MinFeeToProcess:   c.Uint64(flags.MinFeeToProcess.Name),
		OpenDBFunc: func() (db.DB, error) {
			return db.OpenDBConnection(db.DBConnectionOpts{
				Name:            c.String(flags.DatabaseUsername.Name),
				Password:        c.String(flags.DatabasePassword.Name),
				Database:        c.String(flags.DatabaseName.Name),
				Host:            c.String(flags.DatabaseHost.Name),
				MaxIdleConns:    c.Uint64(flags.DatabaseMaxIdleConns.Name),
				MaxOpenConns:    c.Uint64(flags.DatabaseMaxOpenConns.Name),
				MaxConnLifetime: c.Uint64(flags.DatabaseConnMaxLifetime.Name),
				OpenFunc: func(dsn string) (db.DB, error) {
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
	}, nil
}
