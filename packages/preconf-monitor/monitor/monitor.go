package monitor

import (
	"context"
	"log/slog"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/bindings/preconfwhitelist"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/encoding"
	"github.com/urfave/cli/v2"
)

type Monitor struct {
	l1EthClient *ethclient.Client
	txmgr       txmgr.TxManager
	cfg         *Config
	ctx         context.Context
	wl          *preconfwhitelist.PreconfWhitelist
}

// InitFromCli inits a new Monitor from command line or environment variables.
func (m *Monitor) InitFromCli(ctx context.Context, cliContext *cli.Context) error {
	cfg, err := NewConfigFromCliContext(cliContext)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, m, cfg)
}

func InitFromConfig(ctx context.Context, m *Monitor, cfg *Config) (err error) {
	m.l1EthClient, err = ethclient.Dial(cfg.L1RPCUrl)
	if err != nil {
		return err
	}

	m.wl, err = preconfwhitelist.NewPreconfWhitelist(cfg.WhitelistAddress, m.l1EthClient)
	if err != nil {
		return err
	}

	if m.txmgr, err = txmgr.NewSimpleTxManager(
		"Monitor",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	m.cfg = cfg
	m.ctx = ctx

	return nil
}

func (m *Monitor) Name() string {
	return "monitor"
}

func (m *Monitor) Close(ctx context.Context) {
	m.l1EthClient.Close()
}

func (m *Monitor) Start() error {
	ticker := time.NewTicker(m.cfg.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return nil
		case <-ticker.C:
			if err := m.monitor(); err != nil {
				slog.Error("consolidate error", "err", err)
			}
		}
	}

}

// monitor the block sequencing and proposing, remove operators
// if they're found to not be sequencing and/or proposing blocks.
func (m *Monitor) monitor() error {
	if err := m.monitorSequencing(); err != nil {
		return err
	}

	if err := m.monitorProposing(); err != nil {
		return err
	}

	return nil
}

func (m *Monitor) monitorSequencing() error {
	return nil
}

func (m *Monitor) monitorProposing() error {
	return nil
}

func (m *Monitor) sendRemoveOperator(operator common.Address) (*types.Receipt, error) {
	txData, err := encoding.PreconfWhitelistABI.Pack("removeOperator", operator, true)
	if err != nil {
		return nil, err
	}

	candidate := txmgr.TxCandidate{
		TxData: txData,
		Blobs:  nil,
		To:     &m.cfg.WhitelistAddress,
	}

	return m.txmgr.Send(m.ctx, candidate)
}
