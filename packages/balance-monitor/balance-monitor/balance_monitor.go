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
	"github.com/prometheus/client_golang/prometheus"
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
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
}

type BalanceMonitor struct {
	l1EthClient        ethClient
	l2EthClient        ethClient
	addresses          []common.Address
	erc20Addresses     []common.Address
	interval           int
	wg                 *sync.WaitGroup
	erc20DecimalsCache map[common.Address]uint8
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
	b.addresses = cfg.Addresses
	b.erc20Addresses = cfg.ERC20Addresses
	b.interval = cfg.Interval
	b.erc20DecimalsCache = make(map[common.Address]uint8)

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

	ticker := time.NewTicker(time.Duration(b.interval) * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		for _, address := range b.addresses {
			b.checkEthBalance(context.Background(), b.l1EthClient, l1EthBalanceGauge, "L1", address)
			b.checkEthBalance(context.Background(), b.l2EthClient, l2EthBalanceGauge, "L2", address)

			// Check ERC-20 token balances
			for _, tokenAddress := range b.erc20Addresses {
				b.checkErc20Balance(context.Background(), b.l1EthClient, l1Erc20BalanceGauge, "L1", tokenAddress, address)
				b.checkErc20Balance(context.Background(), b.l2EthClient, l2Erc20BalanceGauge, "L2", tokenAddress, address)
			}
			// Add a 1 second sleep between address checks
			time.Sleep(time.Second)
		}
	}

	return nil
}

func (b *BalanceMonitor) checkEthBalance(ctx context.Context, client ethClient, gauge *prometheus.GaugeVec, clientLabel string, address common.Address) {
	balance, err := b.getEthBalance(ctx, client, address)
	if err != nil {
		slog.Info(fmt.Sprintf("Failed to get %s ETH balance for address", clientLabel), "address", address.Hex(), "error", err)
		return
	}
	balanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(balance), big.NewFloat(1e18)).Float64()
	gauge.WithLabelValues(address.Hex()).Set(balanceFloat)
	slog.Info(fmt.Sprintf("%s ETH Balance", clientLabel), "address", address.Hex(), "balance", balanceFloat)
}

func (b *BalanceMonitor) checkErc20Balance(ctx context.Context, client ethClient, gauge *prometheus.GaugeVec, clientLabel string, tokenAddress, holderAddress common.Address) {
	tokenBalance, err := b.getErc20Balance(ctx, client, tokenAddress, holderAddress)
	if err != nil {
		slog.Info(fmt.Sprintf("Failed to get %s ERC-20 balance for address", clientLabel), "address", holderAddress.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
		return
	}

	// Check the cache for the token decimals
	tokenDecimals, ok := b.erc20DecimalsCache[tokenAddress]
	if !ok {
		// If not in the cache, fetch the decimals from the contract
		tokenDecimals, err = b.getErc20Decimals(ctx, client, tokenAddress)
		if err != nil {
			slog.Info(fmt.Sprintf("Failed to get %s ERC-20 decimals for token", clientLabel), "tokenAddress", tokenAddress.Hex(), "error", err)
			return
		}
		// Cache the fetched decimals
		b.erc20DecimalsCache[tokenAddress] = tokenDecimals
	}

	tokenBalanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(tokenBalance), big.NewFloat(math.Pow(10, float64(tokenDecimals)))).Float64()
	gauge.WithLabelValues(tokenAddress.Hex(), holderAddress.Hex()).Set(tokenBalanceFloat)
	slog.Info(fmt.Sprintf("%s ERC-20 Balance", clientLabel), "tokenAddress", tokenAddress.Hex(), "address", holderAddress.Hex(), "balance", tokenBalanceFloat)
}

const erc20ABI = `[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]`

type ERC20 interface {
	BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error)
}

func (b *BalanceMonitor) getEthBalance(ctx context.Context, client ethClient, address common.Address) (*big.Int, error) {
	balance, err := client.BalanceAt(ctx, address, nil)
	if err != nil {
		return nil, err
	}

	return balance, nil
}

func (b *BalanceMonitor) getErc20Balance(ctx context.Context, client ethClient, tokenAddress, holderAddress common.Address) (*big.Int, error) {
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

func (b *BalanceMonitor) getErc20Decimals(ctx context.Context, client ethClient, tokenAddress common.Address) (uint8, error) {
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
