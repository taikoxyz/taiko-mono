package balanceMonitor

import (
	"context"
	"fmt"
	"math"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

type ethClient interface {
	BalanceAt(ctx context.Context, account common.Address, blockNumber *big.Int) (*big.Int, error)
	CallContract(ctx context.Context, call ethereum.CallMsg, blockNumber *big.Int) ([]byte, error)
	CodeAt(ctx context.Context, account common.Address, blockNumber *big.Int) ([]byte, error)
	PendingCodeAt(ctx context.Context, account common.Address) ([]byte, error)
	PendingNonceAt(ctx context.Context, account common.Address) (uint64, error)
	EstimateGas(ctx context.Context, call ethereum.CallMsg) (uint64, error)
	SendTransaction(ctx context.Context, tx *types.Transaction) error
	FilterLogs(ctx context.Context, query ethereum.FilterQuery) ([]types.Log, error)
	SubscribeFilterLogs(ctx context.Context, query ethereum.FilterQuery, ch chan<- types.Log) (ethereum.Subscription, error)
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
	BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error)
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	ChainID(ctx context.Context) (*big.Int, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
}

type BalanceMonitor struct {
	l1EthClient    ethClient
	l2EthClient    ethClient
	Addresses      []common.Address
	ERC20Addresses []common.Address
	Interval       int
	wg             *sync.WaitGroup
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
	b.ERC20Addresses = cfg.ERC20Addresses
	b.Interval = cfg.Interval

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

	ticker := time.NewTicker(time.Duration(b.Interval) * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		for _, address := range b.Addresses {
			// Check L1 ETH balance
			l1Balance, err := b.GetEthBalance(context.Background(), b.l1EthClient, address)
			if err != nil {
				slog.Info("Failed to get L1 ETH balance for address", "address", address.Hex(), "error", err)
				continue
			}
			l1BalanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(l1Balance), big.NewFloat(1e18)).Float64()
			l1EthBalanceGauge.WithLabelValues(address.Hex()).Set(l1BalanceFloat)
			slog.Info("L1 ETH Balance", "address", address.Hex(), "balance", l1BalanceFloat)

			// Check L2 ETH balance
			l2Balance, err := b.GetEthBalance(context.Background(), b.l2EthClient, address)
			if err != nil {
				slog.Info("Failed to get L2 ETH balance for address", "address", address.Hex(), "error", err)
				continue
			}
			l2BalanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(l2Balance), big.NewFloat(1e18)).Float64()
			l2EthBalanceGauge.WithLabelValues(address.Hex()).Set(l2BalanceFloat)
			slog.Info("L2 ETH Balance", "address", address.Hex(), "balance", l2BalanceFloat)

			// Check ERC-20 token balances
			for _, tokenAddress := range b.ERC20Addresses {
				// Check L1 ERC-20 balance
				l1TokenBalance, err := b.GetERC20Balance(context.Background(), b.l1EthClient, tokenAddress, address)
				if err != nil {
					slog.Info("Failed to get L1 ERC-20 balance for address", "address", address.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
					continue
				}
				l1TokenDecimals, err := b.GetERC20Decimals(context.Background(), b.l1EthClient, tokenAddress)
				if err != nil {
					slog.Info("Failed to get L1 ERC-20 decimals for token", "tokenAddress", tokenAddress.Hex(), "error", err)
					continue
				}
				l1TokenBalanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(l1TokenBalance), big.NewFloat(math.Pow(10, float64(l1TokenDecimals)))).Float64()
				l1Erc20BalanceGauge.WithLabelValues(tokenAddress.Hex(), address.Hex()).Set(l1TokenBalanceFloat)
				slog.Info("L1 ERC-20 Balance", "tokenAddress", tokenAddress.Hex(), "address", address.Hex(), "balance", l1TokenBalanceFloat)

				// Check L2 ERC-20 balance
				l2TokenBalance, err := b.GetERC20Balance(context.Background(), b.l2EthClient, tokenAddress, address)
				if err != nil {
					slog.Info("Failed to get L2 ERC-20 balance for address", "address", address.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
					continue
				}
				l2TokenDecimals, err := b.GetERC20Decimals(context.Background(), b.l2EthClient, tokenAddress)
				if err != nil {
					slog.Info("Failed to get L2 ERC-20 decimals for token", "tokenAddress", tokenAddress.Hex(), "error", err)
					continue
				}
				l2TokenBalanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(l2TokenBalance), big.NewFloat(math.Pow(10, float64(l2TokenDecimals)))).Float64()
				l2Erc20BalanceGauge.WithLabelValues(tokenAddress.Hex(), address.Hex()).Set(l2TokenBalanceFloat)
				slog.Info("L2 ERC-20 Balance", "tokenAddress", tokenAddress.Hex(), "address", address.Hex(), "balance", l2TokenBalanceFloat)
			}
		}
	}

	return nil
}

const erc20ABI = `[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]`

type ERC20 interface {
	BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error)
}

func (b *BalanceMonitor) GetEthBalance(ctx context.Context, client ethClient, address common.Address) (*big.Int, error) {
	balance, err := client.BalanceAt(ctx, address, nil)
	if err != nil {
		return nil, err
	}

	return balance, nil
}

func (b *BalanceMonitor) GetERC20Balance(ctx context.Context, client ethClient, tokenAddress, holderAddress common.Address) (*big.Int, error) {
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return nil, err
	}

	tokenContract := bind.NewBoundContract(tokenAddress, parsedABI, client, client, client)

	var result []interface{}
	err = tokenContract.Call(&bind.CallOpts{
		Context: ctx,
	}, &result, "balanceOf", holderAddress)

	if err != nil {
		return nil, err
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no result from token contract call")
	}

	balance, ok := result[0].(*big.Int)
	if !ok {
		return nil, fmt.Errorf("unexpected type for balanceOf result")
	}

	return balance, nil
}

func (b *BalanceMonitor) GetERC20Decimals(ctx context.Context, client ethClient, tokenAddress common.Address) (uint8, error) {
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return 0, err
	}

	tokenContract := bind.NewBoundContract(tokenAddress, parsedABI, client, client, client)

	var result []interface{}
	err = tokenContract.Call(&bind.CallOpts{
		Context: ctx,
	}, &result, "decimals")

	if err != nil {
		return 0, err
	}

	if len(result) == 0 {
		return 0, fmt.Errorf("no result from token contract call")
	}

	decimals, ok := result[0].(uint8)
	if !ok {
		return 0, fmt.Errorf("unexpected type for decimals result")
	}

	return decimals, nil
}
