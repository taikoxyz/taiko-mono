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

	type blobInfo struct {
		index  uint8
		offset uint64
		length uint64
	}

	blobInfos := make([]blobInfo, 0)

	var totalBytes []byte

	var idx uint8

	for i, opt := range opts.BlockOpts {
		txListBytes, err := signedTransactionsToTxListBytes(opt.SignedTransactions)
		if err != nil {
			return nil, err
		}

		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			return nil, err
		}

		totalWithCurrentTxList := append(totalBytes, compressedTxListBytes...)

		// if we have exceeded max blob data size, we can make a blob with all the data
		// *except* this one.
		if len(totalWithCurrentTxList) >= eth.MaxBlobDataSize {
			var blob = &eth.Blob{}
			if err := blob.FromData(totalBytes); err != nil {
				return nil, err
			}

			blobs = append(blobs, blob)

			// clear the bytes array and increment the blob index for next iterations of the loop
			totalBytes = []byte{}
			idx++
		}

		// create a new blobInfos to be attached to a BlockParams after.
		blobInfos = append(blobInfos, blobInfo{
			index:  idx,
			offset: uint64(len(totalBytes)),
			length: uint64(len(compressedTxListBytes)),
		})

		totalBytes = append(totalBytes, compressedTxListBytes...)

		// and finally check if we are at the end of the list.
		if i == len(opts.BlockOpts)-1 {
			// we need to make a final blob with the remaining txList,
			// or all the txLists summed together. regardless, there will be a
			// blob to make here: either the only blob, or the final blob.
			var blob = &eth.Blob{}
			if err := blob.FromData(totalBytes); err != nil {
				return nil, err
			}

			blobs = append(blobs, blob)
		}
	}

	for i, opt := range opts.BlockOpts {
		params := &encoding.BlockParams{
			Coinbase:           common.HexToAddress(opt.Coinbase),
			ExtraData:          rpc.StringToBytes32(opt.ExtraData),
			Signature:          []byte{}, // no longer checked
			L1StateBlockNumber: opt.L1StateBlockNumber,
			Timestamp:          opt.Timestamp,
			BlobIndex:          blobInfos[i].index,
			BlobTxListOffset:   blobInfos[i].offset,
			BlobTxListLength:   blobInfos[i].length,
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
