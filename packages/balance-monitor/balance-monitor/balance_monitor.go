package balanceMonitor

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/urfave/cli/v2"
)

type BalanceMonitor struct {
	l1EthClient        *ethclient.Client
	l2EthClient        *ethclient.Client
	addresses          []common.Address
	erc20Addresses     []common.Address
	interval           time.Duration
	erc20DecimalsCache map[common.Address]uint8
	ctx                context.Context
}

// InitFromCli initializes a BalanceMonitor from command line or environment variables.
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
	b.ctx = ctx

	return nil
}

func (b *BalanceMonitor) Name() string {
	return "BalanceMonitor"
}

func (b *BalanceMonitor) Close(ctx context.Context) {
}

func (b *BalanceMonitor) Start() error {
	ticker := time.NewTicker(b.interval)
	defer ticker.Stop()

	for {
		select {
		case <-b.ctx.Done():
			return nil
		case <-ticker.C:
			for _, address := range b.addresses {
				// Create context with timeout for RPC calls to ensure graceful shutdown
				ctx, cancel := context.WithTimeout(b.ctx, 30*time.Second)
				b.checkEthBalance(ctx, b.l1EthClient, l1EthBalanceGauge, "L1", address)
				b.checkEthBalance(ctx, b.l2EthClient, l2EthBalanceGauge, "L2", address)

				// Check ERC-20 token balances
				var balance float64 = 0
				for _, tokenAddress := range b.erc20Addresses {
					balance = balance + b.checkErc20Balance(ctx, b.l1EthClient, "L1", tokenAddress, address)
					balance = balance + b.checkErc20Balance(ctx, b.l2EthClient, "L2", tokenAddress, address)

				}
				cancel()
				l1Erc20BalanceGauge.WithLabelValues(address.Hex()).Set(balance)
				slog.Info("ERC-20 Balance", "address", address.Hex(), "balance", balance)
			}
		}
	}
}

func (b *BalanceMonitor) checkEthBalance(ctx context.Context, client *ethclient.Client, gauge *prometheus.GaugeVec, clientLabel string, address common.Address) {
	balance, err := b.getEthBalance(ctx, client, address)
	if err != nil {
		slog.Warn(fmt.Sprintf("Failed to get %s ETH balance for address", clientLabel), "address", address.Hex(), "error", err)
		return
	}
	balanceFloat, _ := new(big.Float).Quo(new(big.Float).SetInt(balance), big.NewFloat(1e18)).Float64()
	gauge.WithLabelValues(address.Hex()).Set(balanceFloat)
	slog.Info(fmt.Sprintf("%s ETH Balance", clientLabel), "address", address.Hex(), "balance", balanceFloat)
}

func (b *BalanceMonitor) checkErc20Balance(ctx context.Context, client *ethclient.Client, clientLabel string, tokenAddress, holderAddress common.Address) float64 {
	// Check the cache for the token decimals
	tokenDecimals, ok := b.erc20DecimalsCache[tokenAddress]
	if !ok {
		// If not in the cache, fetch the decimals from the contract
		tokenDecimals, err := b.getErc20Decimals(ctx, client, tokenAddress)
		if err != nil {
			slog.Warn(fmt.Sprintf("Failed to get %s ERC-20 decimals for token. Use default value: 18", clientLabel), "tokenAddress", tokenAddress.Hex(), "error", err)
			tokenDecimals = 18
		}
		// Cache the fetched decimals
		b.erc20DecimalsCache[tokenAddress] = tokenDecimals
	}

	var tokenBalanceFloat float64 = 0
	tokenBalance, err := b.getErc20Balance(ctx, client, tokenAddress, holderAddress)
	if err != nil {
		slog.Warn(fmt.Sprintf("Failed to get %s ERC-20 balance for address", clientLabel), "address", holderAddress.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
		tokenBalanceFloat = 0
	} else {
		tokenBalanceFloat, _ = new(big.Float).Quo(new(big.Float).SetInt(tokenBalance), big.NewFloat(math.Pow(10, float64(tokenDecimals)))).Float64()
	}

	var tokenBondBalanceFloat float64 = 0
	tokenBondBalance, err := b.getErc20BondBalance(ctx, client, tokenAddress, holderAddress)
	if err != nil {
		slog.Warn(fmt.Sprintf("Failed to get %s ERC-20 bond balance for address", clientLabel), "address", holderAddress.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
		tokenBondBalanceFloat = 0
	} else {
		tokenBondBalanceFloat, _ = new(big.Float).Quo(new(big.Float).SetInt(tokenBondBalance), big.NewFloat(math.Pow(10, float64(tokenDecimals)))).Float64()
	}

	balance := tokenBalanceFloat + tokenBondBalanceFloat
	slog.Info(fmt.Sprintf("%s ERC-20 Balance", clientLabel), "tokenAddress", tokenAddress.Hex(), "address", holderAddress.Hex(), "balance", balance)
	return balance
}

const erc20BalanceOfABI = `[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]`
const erc20BondBalanceOfABI = `[{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"bondBalanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]`

type ERC20 interface {
	BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error)
}

func (b *BalanceMonitor) getEthBalance(ctx context.Context, client *ethclient.Client, address common.Address) (*big.Int, error) {
	balance, err := client.BalanceAt(ctx, address, nil)
	if err != nil {
		return nil, err
	}

	return balance, nil
}

func (b *BalanceMonitor) getTokenBalance(ctx context.Context, client *ethclient.Client, tokenAddress, holderAddress common.Address, methodName string, abiDef string) (*big.Int, error) {
	parsedABI, err := abi.JSON(strings.NewReader(abiDef))
	if err != nil {
		return nil, err
	}

	tokenContract := bind.NewBoundContract(tokenAddress, parsedABI, client, client, client)

	var result []interface{}
	err = tokenContract.Call(&bind.CallOpts{
		Context: ctx,
	}, &result, methodName, holderAddress)

	if err != nil {
		return nil, err
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no result from token contract call")
	}

	balance, ok := result[0].(*big.Int)
	if !ok {
		if val, ok := result[0].(big.Int); ok {
			return &val, nil
		}
		return nil, fmt.Errorf("unexpected type for balance result: %T", result[0])
	}

	return balance, nil
}

func (b *BalanceMonitor) getErc20Balance(ctx context.Context, client *ethclient.Client, tokenAddress, holderAddress common.Address) (*big.Int, error) {
	return b.getTokenBalance(ctx, client, tokenAddress, holderAddress, "balanceOf", erc20BalanceOfABI)
}

func (b *BalanceMonitor) getErc20BondBalance(ctx context.Context, client *ethclient.Client, tokenAddress, holderAddress common.Address) (*big.Int, error) {
	return b.getTokenBalance(ctx, client, tokenAddress, holderAddress, "bondBalanceOf", erc20BondBalanceOfABI)
}

func (b *BalanceMonitor) getErc20Decimals(ctx context.Context, client *ethclient.Client, tokenAddress common.Address) (uint8, error) {
	parsedABI, err := abi.JSON(strings.NewReader(erc20BalanceOfABI))
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
