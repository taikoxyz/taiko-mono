package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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
	opts BuildUnsignedOpts,
) (*types.Transaction, error) {
	encodedParams := make([][]byte, 0)

	blobs := make([]*eth.Blob, 0)

	var offset uint64 = 0

	for i, opt := range opts.BlockOpts {
		txListBytes, err := signedTransactionsToTxListBytes(opt.SignedTransactions)
		if err != nil {
			return nil, err
		}

		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			return nil, err
		}

		params := &encoding.BlockParams{
			Coinbase:           common.HexToAddress(opt.Coinbase),
			ExtraData:          rpc.StringToBytes32(opt.ExtraData),
			Signature:          []byte{}, // no longer checked
			L1StateBlockNumber: opt.L1StateBlockNumber,
			Timestamp:          opt.Timestamp,
		}

		if opts.MultipleBlobs {
			var blob = &eth.Blob{}
			if err := blob.FromData(compressedTxListBytes); err != nil {
				return nil, err
			}

			blobs = append(blobs, blob)

			params.BlobIndex = uint8(i)
			params.BlobTxListLength = uint64(len(compressedTxListBytes))
			params.BlobTxListOffset = 0
		} else {
			params.BlobIndex = 0
			params.BlobTxListOffset = offset
			params.BlobTxListLength = uint64(len(compressedTxListBytes))

			offset += uint64(len(compressedTxListBytes))
		}

		encoded, err := encoding.EncodeBlockParams(params)
		if err != nil {
			return nil, err
		}

		encodedParams = append(encodedParams, encoded)
	}

	data, err := encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, [][]byte{})
	if err != nil {
		return nil, err
	}

	sidecar, blobHashes, err := txmgr.MakeSidecar(blobs)
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
