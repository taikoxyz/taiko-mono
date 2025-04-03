package consolidator

import (
	"context"
	"fmt"
	"log/slog"
	"math/big"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	txmgrMetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/bindings/preconfwhitelist"
	"github.com/taikoxyz/taiko-mono/packages/preconf-monitor/encoding"
	"github.com/urfave/cli/v2"
)

type Consolidator struct {
	l1EthClient *ethclient.Client
	txmgr       txmgr.TxManager
	cfg         *Config
	ctx         context.Context
	wl          *preconfwhitelist.PreconfWhitelist
}

// InitFromCli inits a new Consolidator from command line or environment variables.
func (c *Consolidator) InitFromCli(ctx context.Context, cliContext *cli.Context) error {
	cfg, err := NewConfigFromCliContext(cliContext)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, c, cfg)
}

func InitFromConfig(ctx context.Context, c *Consolidator, cfg *Config) (err error) {
	c.l1EthClient, err = ethclient.Dial(cfg.L1RPCUrl)
	if err != nil {
		return err
	}

	c.wl, err = preconfwhitelist.NewPreconfWhitelist(cfg.WhitelistAddress, c.l1EthClient)
	if err != nil {
		return err
	}

	if c.txmgr, err = txmgr.NewSimpleTxManager(
		"consolidator",
		log.Root(),
		new(txmgrMetrics.NoopTxMetrics),
		*cfg.TxmgrConfigs,
	); err != nil {
		return err
	}

	c.cfg = cfg
	c.ctx = ctx

	return nil
}

func (c *Consolidator) Name() string {
	return "consolidator"
}

func (c *Consolidator) Close(ctx context.Context) {
	c.l1EthClient.Close()
}

func (c *Consolidator) Start() error {
	ticker := time.NewTicker(c.cfg.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			return nil
		case <-ticker.C:
			if err := c.consolidate(); err != nil {
				slog.Error("consolidate error", "err", err)
			}
		}
	}

}

func (c *Consolidator) consolidate() error {
	perfectOperators, err := c.wl.HavingPerfectOperators(&bind.CallOpts{
		Context: c.ctx,
	})

	if err != nil {
		return err
	}

	// do nothing, no need to consolidate
	if perfectOperators {
		return nil
	}

	// otherwise, iterator over the operators, and determine if one is
	// ready to be removed or added.

	operatorCount, err := c.wl.OperatorCount(&bind.CallOpts{
		Context: c.ctx,
	})
	if err != nil {
		return err
	}

	for i := uint8(0); i < operatorCount; i++ {
		operator, err := c.wl.OperatorMapping(&bind.CallOpts{
			Context: c.ctx,
		}, big.NewInt(int64(i)))
		if err != nil {
			return err
		}

		opInfo, err := c.wl.Operators(&bind.CallOpts{
			Context: c.ctx,
		}, operator)
		if err != nil {
			return err
		}

		currentEpoch, err := c.wl.EpochStartTimestamp(&bind.CallOpts{
			Context: c.ctx,
		}, common.Big0)
		if err != nil {
			return err
		}

		if opInfo.InactiveSince != 0 && opInfo.InactiveSince <= currentEpoch {
			receipt, err := c.sendConsolidateTx()
			if err != nil {
				return err
			}

			slog.Info("consolidate tx sent", "txHash", receipt.TxHash.String())

			if receipt.Status != types.ReceiptStatusSuccessful {
				return fmt.Errorf("consolidate tx failed: %v", receipt.Status)
			}

			// we return here, we dont need to continue looping
			return nil
		}
	}

	return nil
}

func (c *Consolidator) sendConsolidateTx() (*types.Receipt, error) {
	txData, err := encoding.PreconfWhitelistABI.Pack("consolidate", nil)
	if err != nil {
		return nil, err
	}

	candidate := txmgr.TxCandidate{
		TxData: txData,
		Blobs:  nil,
		To:     &c.cfg.WhitelistAddress,
	}

	return c.txmgr.Send(c.ctx, candidate)
}
