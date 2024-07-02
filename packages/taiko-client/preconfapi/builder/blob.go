package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
)

// BlobTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	taikoL1Address common.Address
	gasLimit       uint64
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	taikoL1Address common.Address,
	gasLimit uint64,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		taikoL1Address,
		gasLimit,
	}
}

// BuildUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *BlobTransactionBuilder) BuildUnsigned(
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

	var blob = &eth.Blob{}
	if err := blob.FromData(compressedTxListBytes); err != nil {
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

	data, err := encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, []byte{})
	if err != nil {
		return nil, err
	}

	sidecar, blobHashes, err := txmgr.MakeSidecar([]*eth.Blob{blob})
	if err != nil {
		return nil, err
	}

	blobTx := &types.BlobTx{
		To:         b.taikoL1Address,
		Value:      nil, // maxFee / prover selecting no longer happens
		Gas:        b.gasLimit,
		Data:       data,
		Sidecar:    sidecar,
		BlobHashes: blobHashes,
	}

	tx := types.NewTx(blobTx)

	return tx, nil
}
