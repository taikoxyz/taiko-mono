package relayer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

var (
	ZeroHash = common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000")
)

// IsInSlice determines whether v is in slice s
func IsInSlice[T comparable](v T, s []T) bool {
	for _, e := range s {
		if v == e {
			return true
		}
	}

	return false
}

type confirmer interface {
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
}

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(ctx context.Context, confirmer confirmer, txHash common.Hash) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				continue
			}

			if receipt.Status != types.ReceiptStatusSuccessful {
				return nil, fmt.Errorf("transaction reverted, hash: %s", txHash)
			}

			return receipt, nil
		}
	}
}

// WaitConfirmations won't return before N blocks confirmations have been seen
// on destination chain.
func WaitConfirmations(ctx context.Context, confirmer confirmer, confirmations uint64, txHash common.Hash) error {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				if err == ethereum.NotFound {
					continue
				}

				return err
			}

			latest, err := confirmer.BlockNumber(ctx)
			if err != nil {
				return err
			}

			if latest < receipt.BlockNumber.Uint64()+confirmations {
				continue
			}

			return nil
		}
	}
}

type CanonicalToken struct {
	// nolint
	ChainId  *big.Int       `json:"chainId"`
	Addr     common.Address `json:"addr"`
	Decimals uint8          `json:"decimals"`
	Symbol   string         `json:"symbol"`
	Name     string         `json:"name"`
}

type EthClient interface {
	BlockNumber(ctx context.Context) (uint64, error)
	ChainID(ctx context.Context) (*big.Int, error)
}
