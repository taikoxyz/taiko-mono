package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// CalldataTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type CalldataTransactionBuilder struct {
	taikoL1Address common.Address
	gasLimit       uint64
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	taikoL1Address common.Address,
	gasLimit uint64,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		taikoL1Address,
		gasLimit,
	}
}

// BuildUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *CalldataTransactionBuilder) BuildUnsigned(
	_ context.Context,
	_ []byte,
	_ uint32,
	_ uint64,
	_ common.Address,
	_ [32]byte,
) (*types.Transaction, error) {
	return &types.Transaction{}, nil
}
