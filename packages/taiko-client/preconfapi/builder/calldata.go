package builder

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
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
	txListBytes []byte,
	l1StateBlockNumber uint32,
	timestamp uint64,
	coinbase common.Address,
	extraData [32]byte,
) (*types.Transaction, error) {
	compressedTxListBytes, err := utils.Compress(txListBytes)
	if err != nil {
		return nil, err
	}

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParams(&encoding.BlockParams{
		ExtraData:          extraData,
		Coinbase:           coinbase,
		Signature:          []byte{}, // no longer checked
		L1StateBlockNumber: l1StateBlockNumber,
		Timestamp:          timestamp,
	})
	if err != nil {
		return nil, err
	}

	data, err := encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, compressedTxListBytes)
	if err != nil {
		return nil, err
	}

	// Create the transaction
	tx := types.NewTransaction(
		0,
		b.taikoL1Address,
		nil,
		b.gasLimit,
		big.NewInt(0),
		data,
	)

	return tx, nil
}
