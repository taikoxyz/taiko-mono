package disperser

import (
	"context"
	"log/slog"
	"time"

	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"

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
	db          DB
	genesisDate time.Time
	regenerate  bool
	txmgr       txmgr.TxManager
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

	return nil
}

func (d *Disperser) Name() string {
	return "disperser"
}

func (d *Disperser) Start() error {
	return nil
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
