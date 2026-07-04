package utils

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"gotest.tools/assert"
	"math/big"
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
