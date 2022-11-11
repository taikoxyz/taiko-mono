package relayer

import (
	"context"
	"fmt"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
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

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(ctx context.Context, client *ethclient.Client, tx *types.Transaction) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			receipt, err := client.TransactionReceipt(ctx, tx.Hash())
			if err != nil {
				continue
			}

			if receipt.Status != types.ReceiptStatusSuccessful {
				return nil, fmt.Errorf("transaction reverted, hash: %s", tx.Hash())
			}

			return receipt, nil
		}
	}
}
