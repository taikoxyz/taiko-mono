package builder

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/lookahead"
)

// BlobTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	preconfTaskManagerAddress common.Address
	lookahead                 *lookahead.Lookahead
	ethClient                 *rpc.EthClient
	gasLimit                  uint64
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	preconfTaskManagerAddress common.Address,
	lookahead *lookahead.Lookahead,
	ethClient *rpc.EthClient,
	gasLimit uint64,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		preconfTaskManagerAddress,
		lookahead,
		ethClient,
		gasLimit,
	}
}

// BuildBlockUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *BlobTransactionBuilder) BuildBlockUnsigned(
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

	var blob = &eth.Blob{}
	if err := blob.FromData(compressedTxListBytes); err != nil {
		return nil, err
	}

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
		Coinbase:         common.HexToAddress(opts.Coinbase),
		AnchorBlockId:    uint64(opts.L1StateBlockNumber),
		Timestamp:        opts.Timestamp,
		BlobIndex:        0,
		BlobTxListOffset: 0,
		BlobTxListLength: uint32(len(compressedTxListBytes)),
	})
	if err != nil {
		return nil, err
	}

	// isLookaheadRequired, err := b.lookahead.IsLookaheadRequired()
	// if err != nil {
	// 	return nil, err
	// }

	// if isLookaheadRequired {
	// 	err := b.lookahead.ForcePushLookahead(ctx)
	// 	if err != nil {
	// 		return nil, err
	// 	}
	// }

	lookaheadPointer, err := b.lookahead.GetLookaheadBuffer(common.HexToAddress(opts.PreconferAddress))
	if err != nil {
		return nil, err
	}

	lookaheadSetParams := make([]bindings.IPreconfTaskManagerLookaheadSetParam, 0)

	lookaheadSetParam := bindings.IPreconfTaskManagerLookaheadSetParam{
		Timestamp: big.NewInt(0),
		Preconfer: common.HexToAddress(opts.PreconferAddress),
	}

	lookaheadSetParams = append(lookaheadSetParams, lookaheadSetParam)

	data, err := encoding.PreconfTaskManagerABI.Pack(
		"newBlockProposal",
		[][]byte{encodedParams},
		[][]byte{nil},
		new(big.Int).SetUint64(lookaheadPointer),
		lookaheadSetParams,
	)
	if err != nil {
		return nil, err
	}

	sidecar, blobHashes, err := txmgr.MakeSidecar([]*eth.Blob{blob})
	if err != nil {
		return nil, err
	}

	blobTx := &types.BlobTx{
		To:         b.preconfTaskManagerAddress,
		Value:      nil, // maxFee / prover selecting no longer happens
		Gas:        b.gasLimit,
		Data:       data,
		Sidecar:    sidecar,
		BlobHashes: blobHashes,
	}

	tx := types.NewTx(blobTx)

	return tx, nil
}

// BuildBlocksUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *BlobTransactionBuilder) BuildBlocksUnsigned(
	_ context.Context,
	opts BuildBlocksUnsignedOpts,
) (*types.Transaction, error) {
	encodedParams := make([][]byte, 0)

	blobs := make([]*eth.Blob, 0)

	type blobInfo struct {
		index  uint8
		offset uint32
		length uint32
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
		// if we have exceeded max blob data size, we can make a blob with all the data
		// *except* this one.
		if len(totalBytes)+len(compressedTxListBytes) >= eth.MaxBlobDataSize {
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
			offset: uint32(len(totalBytes)),
			length: uint32(len(compressedTxListBytes)),
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
		params := &encoding.BlockParamsV2{
			Coinbase:         common.HexToAddress(opt.Coinbase),
			AnchorBlockId:    uint64(opt.L1StateBlockNumber),
			Timestamp:        opt.Timestamp,
			BlobIndex:        blobInfos[i].index,
			BlobTxListOffset: blobInfos[i].offset,
			BlobTxListLength: blobInfos[i].length,
		}

		encoded, err := encoding.EncodeBlockParamsOntake(params)
		if err != nil {
			return nil, err
		}

		encodedParams = append(encodedParams, encoded)
	}

	emptyTxLists := make([][]byte, len(encodedParams))

	for i := range encodedParams {
		emptyTxLists[i] = []byte{}
	}

	// isLookaheadRequired, err := b.lookahead.IsLookaheadRequired()
	// if err != nil {
	// 	return nil, err
	// }

	// if isLookaheadRequired {
	// 	err := b.lookahead.ForcePushLookahead(ctx)
	// 	if err != nil {
	// 		return nil, err
	// 	}
	// }

	lookaheadPointer, err := b.lookahead.GetLookaheadBuffer(common.HexToAddress(opts.PreconferAddress))
	if err != nil {
		return nil, err
	}

	lookaheadSetParams := make([]bindings.IPreconfTaskManagerLookaheadSetParam, 0)

	lookaheadSetParam := bindings.IPreconfTaskManagerLookaheadSetParam{
		Timestamp: big.NewInt(0),
		Preconfer: common.HexToAddress(opts.PreconferAddress),
	}

	lookaheadSetParams = append(lookaheadSetParams, lookaheadSetParam)

	data, err := encoding.PreconfTaskManagerABI.Pack(
		"newBlockProposal",
		encodedParams,
		emptyTxLists,
		new(big.Int).SetUint64(lookaheadPointer),
		lookaheadSetParams,
	)
	if err != nil {
		return nil, err
	}
	sidecar, blobHashes, err := txmgr.MakeSidecar(blobs)
	if err != nil {
		return nil, err
	}

	blobTx := &types.BlobTx{
		To:         b.preconfTaskManagerAddress,
		Value:      nil, // maxFee / prover selecting no longer happens
		Gas:        b.gasLimit,
		Data:       data,
		Sidecar:    sidecar,
		BlobHashes: blobHashes,
	}

	tx := types.NewTx(blobTx)

	return tx, nil
}
