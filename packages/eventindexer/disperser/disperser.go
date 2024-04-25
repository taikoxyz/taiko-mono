package disperser

import (
	"context"
	"log/slog"
	"math/big"
	"os"

	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/encoding"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"
)

var (
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

// Disperser is a subcommand which is intended to be run on an interval, like
// a cronjob, to parse the indexed data from the database, and generate
// time series data that can easily be displayed via charting libraries.
type Disperser struct {
	db                DB
	dispersalAmount   *big.Int
	taikoTokenAddress common.Address
	txmgr             txmgr.TxManager
}

func (d *Disperser) InitFromCli(ctx context.Context, c *cli.Context) error {
	config, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, d, config)
}

func InitFromConfig(ctx context.Context, d *Disperser, cfg *Config) error {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	if d.txmgr, err = txmgr.NewSimpleTxManager(
		"disperser",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	d.db = db

	d.dispersalAmount = cfg.DispersalAmount
	d.taikoTokenAddress = cfg.TaikoTokenAddress

	return nil
}

func (d *Disperser) Name() string {
	return "disperser"
}

func (d *Disperser) Start() error {
	addresses, err := d.findAllAddresses()
	if err != nil {
		return err
	}

	for _, address := range addresses {
		slog.Info("dispersing to", "address", address)

		data, err := encoding.TaikoTokenABI.Pack("transfer", common.HexToAddress(address), d.dispersalAmount)
		if err != nil {
			return err
		}

		candidate := txmgr.TxCandidate{
			TxData: data,
			Blobs:  nil,
			To:     &d.taikoTokenAddress,
		}

		receipt, err := d.txmgr.Send(context.Background(), candidate)
		if err != nil {
			slog.Warn("Failed to send transfer transaction", "error", err.Error())
			return err
		}

		slog.Info("sent tx", "tx", receipt.TxHash.Hex())
	}

	os.Exit(0)

	return nil
}

func (d *Disperser) findAllAddresses() ([]string, error) {
	var addresses []string
	// Execute raw SQL query to find distinct addresses where event is 'InstanceAdded'
	err := d.db.GormDB().Raw("SELECT DISTINCT address FROM events WHERE event = ?", "InstanceAdded").Scan(&addresses).Error

	if err != nil {
		return nil, err
	}

	return addresses, nil
}

func (d *Disperser) Close(ctx context.Context) {
	sqlDB, err := d.db.DB()
	if err != nil {
		slog.Error("error getting sqldb when closing Disperser", "err", err.Error())
	}

	if err := sqlDB.Close(); err != nil {
		slog.Error("error closing sqlbd connection", "err", err.Error())
	}
}
