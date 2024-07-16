package builder

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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

// BuildBlockUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *CalldataTransactionBuilder) BuildBlockUnsigned(
	_ context.Context,
	opts BuildBlockUnsignedOpts,
) (*types.Transaction, error) {
	txListBytes, err := signedTransactionsToTxListBytes(opts.SignedTransactions)
	if err != nil {
		return nil, err
	}

	compressedTxListBytes, err := utils.Compress(txListBytes)
	if err != nil {
		return nil, err
	}

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParams(&encoding.BlockParams{
		Coinbase:           common.HexToAddress(opts.Coinbase),
		ExtraData:          rpc.StringToBytes32(opts.ExtraData),
		Signature:          []byte{}, // no longer checked
		L1StateBlockNumber: opts.L1StateBlockNumber,
		Timestamp:          opts.Timestamp,
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

// BuildBlockUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction for a tx with multiple blocks,
// intended for preconfirmations.
func (b *CalldataTransactionBuilder) BuildBlocksUnsigned(
	_ context.Context,
	opts BuildBlocksUnsignedOpts,
) (*types.Transaction, error) {
	encodedParams := make([][]byte, 0)

	txLists := make([][]byte, 0)

	for _, opt := range opts.BlockOpts {
		txListBytes, err := signedTransactionsToTxListBytes(opt.SignedTransactions)
		if err != nil {
			return nil, err
		}

		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			return nil, err
		}

		// ABI encode the TaikoL1.proposeBlock parameters.
		encoded, err := encoding.EncodeBlockParams(&encoding.BlockParams{
			Coinbase:           common.HexToAddress(opt.Coinbase),
			ExtraData:          rpc.StringToBytes32(opt.ExtraData),
			Signature:          []byte{}, // no longer checked
			L1StateBlockNumber: opt.L1StateBlockNumber,
			Timestamp:          opt.Timestamp,
		})
		if err != nil {
			return nil, err
		}

		encodedParams = append(encodedParams, encoded)

		txLists = append(txLists, compressedTxListBytes)
	}

	data, err := encoding.TaikoL1ABI.Pack("proposeBlocks", encodedParams, txLists)
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
