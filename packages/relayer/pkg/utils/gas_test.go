package utils

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/pkg/errors"
	"gotest.tools/assert"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_IsMaxPriorityFeePerGasNotFoundError(t *testing.T) {
	assert.Equal(t,
		false,
		IsMaxPriorityFeePerGasNotFoundError(errors.New("asdf")))

	assert.Equal(t,
		true,
		IsMaxPriorityFeePerGasNotFoundError(ErrMaxPriorityFeePerGasNotFound))
}

func Test_SetGasTipOrPrice(t *testing.T) {
	auth := &bind.TransactOpts{}

	err := SetGasTipOrPrice(context.Background(),
		auth,
		&mock.EthClient{})

	assert.NilError(t, err)

	assert.Equal(t, auth.GasTipCap.Uint64(), uint64(100))
}

type maxPriorityFeeUnsupportedClient struct {
	mock.EthClient
}

func (c *maxPriorityFeeUnsupportedClient) SuggestGasTipCap(ctx context.Context) (*big.Int, error) {
	return nil, ErrMaxPriorityFeePerGasNotFound
}

func Test_SetGasTipOrPriceKeepsFallbackGasTip(t *testing.T) {
	auth := &bind.TransactOpts{}

	err := SetGasTipOrPrice(context.Background(), auth, &maxPriorityFeeUnsupportedClient{})

	assert.NilError(t, err)
	assert.Equal(t, auth.GasTipCap, FallbackGasTipCap)
	assert.Equal(t, auth.GasPrice, (*big.Int)(nil))
}

// gasTipCapUnpricedClient fails SuggestGasTipCap with an error unrelated to the method being
// missing, which is the branch that falls back to a full legacy gas price.
type gasTipCapUnpricedClient struct {
	mock.EthClient
	gasPriceErr error
}

func (c *gasTipCapUnpricedClient) SuggestGasTipCap(ctx context.Context) (*big.Int, error) {
	return nil, errors.New("execution reverted")
}

func (c *gasTipCapUnpricedClient) SuggestGasPrice(ctx context.Context) (*big.Int, error) {
	if c.gasPriceErr != nil {
		return nil, c.gasPriceErr
	}

	return big.NewInt(4200), nil
}

func Test_SetGasTipOrPriceFallsBackToGasPrice(t *testing.T) {
	auth := &bind.TransactOpts{}

	err := SetGasTipOrPrice(context.Background(), auth, &gasTipCapUnpricedClient{})

	assert.NilError(t, err)
	assert.Equal(t, auth.GasPrice.Uint64(), uint64(4200))

	// The two must not both be set: a leftover tip would be signed into a dynamic-fee transaction
	// the node has just said it cannot price.
	assert.Equal(t, auth.GasTipCap, (*big.Int)(nil))
}

func Test_SetGasTipOrPriceReturnsTheGasPriceError(t *testing.T) {
	auth := &bind.TransactOpts{}

	err := SetGasTipOrPrice(
		context.Background(),
		auth,
		&gasTipCapUnpricedClient{gasPriceErr: errors.New("no gas price either")},
	)

	// Neither price is available, so the caller has to hear about it rather than send at zero.
	assert.ErrorContains(t, err, "no gas price either")
	assert.Equal(t, auth.GasPrice, (*big.Int)(nil))
	assert.Equal(t, auth.GasTipCap, (*big.Int)(nil))
}

func Test_EstimateGasReturnsTheGasOnTheTransaction(t *testing.T) {
	key, err := crypto.HexToECDSA("8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f")
	assert.NilError(t, err)

	called := false

	gas, err := EstimateGas(
		context.Background(),
		key,
		[32]byte{},
		big.NewInt(167001),
		func() (*types.Transaction, error) {
			called = true

			return types.NewTx(&types.DynamicFeeTx{Gas: 31_000}), nil
		},
	)

	assert.NilError(t, err)
	assert.Equal(t, called, true)
	assert.Equal(t, gas, uint64(31_000))
}

func Test_EstimateGasWrapsTheCallError(t *testing.T) {
	key, err := crypto.HexToECDSA("8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f")
	assert.NilError(t, err)

	gas, err := EstimateGas(
		context.Background(),
		key,
		[32]byte{},
		big.NewInt(167001),
		func() (*types.Transaction, error) {
			return nil, errors.New("execution reverted")
		},
	)

	// A failed estimate must not read as a zero-gas transaction.
	assert.ErrorContains(t, err, "execution reverted")
	assert.Equal(t, gas, uint64(0))
}

func Test_EstimateGasRejectsAMissingChainID(t *testing.T) {
	key, err := crypto.HexToECDSA("8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f")
	assert.NilError(t, err)

	called := false

	// Without a chain ID the transactor cannot build a replay-protected signer, so this has to
	// fail before the call rather than sign against the wrong chain.
	gas, err := EstimateGas(
		context.Background(),
		key,
		[32]byte{},
		nil,
		func() (*types.Transaction, error) {
			called = true

			return types.NewTx(&types.DynamicFeeTx{Gas: 31_000}), nil
		},
	)

	assert.ErrorContains(t, err, "bind.NewKeyedTransactorWithChainID")
	assert.Equal(t, called, false)
	assert.Equal(t, gas, uint64(0))
}
