package balanceMonitor

import (
	"context"
	"fmt"
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
			balance, err := b.GetEthBalance(context.Background(), address)
			if err != nil {
				slog.Info("Failed to get ETH balance for address", "address", address.Hex(), "error", err)
				continue
			}
			slog.Info("ETH Balance", "address", address.Hex(), "balance", balance.String())

			// Check balance for each ERC-20 token address
			for _, tokenAddress := range b.ERC20Addresses {
				tokenBalance, err := b.GetERC20Balance(context.Background(), tokenAddress, address)
				if err != nil {
					slog.Info("Failed to get ERC-20 balance for address", "address", address.Hex(), "tokenAddress", tokenAddress.Hex(), "error", err)
					continue
				}
				slog.Info("ERC-20 Balance", "tokenAddress", tokenAddress.Hex(), "address", address.Hex(), "balance", tokenBalance.String())
			}
		}
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

const erc20ABI = `[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}]`

type ERC20 interface {
	BalanceOf(opts *bind.CallOpts, account common.Address) (*big.Int, error)
}

func (b *BalanceMonitor) GetERC20Balance(ctx context.Context, tokenAddress, holderAddress common.Address) (*big.Int, error) {
	// Parse the ERC-20 ABI
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return nil, err
	}

	// Create an instance of the token contract
	tokenContract := bind.NewBoundContract(tokenAddress, parsedABI, b.l1EthClient, b.l1EthClient, b.l1EthClient)

	// Prepare the call to the balanceOf method
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
