package utils

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"gotest.tools/assert"
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
