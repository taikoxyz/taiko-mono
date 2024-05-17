package balanceMonitor

import (
	"context"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

type ethClient interface {
	BalanceAt(ctx context.Context, account common.Address, blockNumber *big.Int) (*big.Int, error)
}

type BalanceMonitor struct {
	l1EthClient ethClient
	l2EthClient ethClient

	Addresses []common.Address

	wg *sync.WaitGroup
}

// InitFromCli inits a new Indexer from command line or environment variables.
func (b *BalanceMonitor) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, b, cfg)
}

func InitFromConfig(ctx context.Context, b *BalanceMonitor, cfg *Config) (err error) {
	l1EthClient, err := ethclient.Dial(cfg.L1RPCUrl)
	if err != nil {
		return err
	}

	l2EthClient, err := ethclient.Dial(cfg.L2RPCUrl)
	if err != nil {
		return err
	}

	b.l1EthClient = l1EthClient
	b.l2EthClient = l2EthClient

	b.Addresses = cfg.Addresses

	return nil
}

func (b *BalanceMonitor) Name() string {
	return "BalanceMonitor"
}

func (b *BalanceMonitor) Close(ctx context.Context) {
	b.wg.Wait()
}

func (b *BalanceMonitor) Start() error {
	slog.Info("hello from balance monitor")

	for _, address := range b.Addresses {
		balance, err := b.GetEthBalance(context.Background(), address)
		if err != nil {
			slog.Info("Failed to get balance for address", "address", address.Hex(), "error", err)
			continue
		}
		slog.Info("Balance", "address", address.Hex(), "balance", balance.String())
	}

	return nil
}

func (b *BalanceMonitor) GetEthBalance(ctx context.Context, address common.Address) (*big.Int, error) {
	balance, err := b.l1EthClient.BalanceAt(ctx, address, nil)
	if err != nil {
		return nil, err
	}

	return balance, nil
}
