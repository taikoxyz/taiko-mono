package utils

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
)

var (
	ErrMaxPriorityFeePerGasNotFound = errors.New(
		"Method eth_maxPriorityFeePerGas not found",
	)

	// FallbackGasTipCap is the default fallback gasTipCap used when we are
	// unable to query an L1 backend for a suggested gasTipCap.
	FallbackGasTipCap = big.NewInt(1500000000)
)

type ethClient interface {
	SuggestGasPrice(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
}

// IsMaxPriorityFeePerGasNotFoundError returns true if the provided error
// signals that the backend does not support the eth_maxPriorityFeePerGas
// method. In this case, the caller should fallback to using the constant above.
func IsMaxPriorityFeePerGasNotFoundError(err error) bool {
	return strings.Contains(
		err.Error(), ErrMaxPriorityFeePerGasNotFound.Error(),
	)
}

func SetGasTipOrPrice(ctx context.Context, auth *bind.TransactOpts, ethClient ethClient) error {
	gasTipCap, err := ethClient.SuggestGasTipCap(ctx)
	if err != nil {
		if IsMaxPriorityFeePerGasNotFoundError(err) {
			auth.GasTipCap = FallbackGasTipCap
		} else {
			gasPrice, err := ethClient.SuggestGasPrice(context.Background())
			if err != nil {
				return errors.Wrap(err, "w.destBridge.SuggestGasPrice")
			}

			auth.GasPrice = gasPrice
		}
	}

	auth.GasTipCap = gasTipCap

	return nil
}

func EstimateGas(
	ctx context.Context,
	ecdsaKey *ecdsa.PrivateKey,
	msgHash [32]byte,
	destChainID *big.Int,
	f func() (*types.Transaction, error),
) (uint64, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(ecdsaKey, destChainID)
	if err != nil {
		return 0, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.NoSend = true

	auth.Context = ctx

	tx, err := f()

	if err != nil {
		return 0, errors.Wrap(err, "p.destBridge.SuspendMessages")
	}

	return tx.Gas(), nil
}
