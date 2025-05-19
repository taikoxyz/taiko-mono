package builder

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ProposeBatchTransactionBuilder is an interface for building a TaikoInbox.proposeBatch
// transaction.
type ProposeBatchTransactionBuilder interface {
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
		minTxsPerForcedInclusion *big.Int,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
	BuildShasta(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion *shastaBindings.IForcedInclusionStoreForcedInclusion,
		minTxsPerForcedInclusion *big.Int,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
}

// buildParamsForForcedInclusion builds the blob params and the block params
// for the given forced inclusion.
func buildParamsForForcedInclusion[
	T *pacayaBindings.IForcedInclusionStoreForcedInclusion | *shastaBindings.IForcedInclusionStoreForcedInclusion,
	U pacayaBindings.ITaikoInboxBlockParams | shastaBindings.ITaikoInboxBlockParams,
](
	forcedInclusion T,
	minTxsPerForcedInclusion *big.Int,
) (*encoding.BlobParams, []U) {
	if forcedInclusion == nil {
		return nil, nil
	}

	var parems *encoding.BlobParams
	switch s := any(forcedInclusion).(type) {
	case *pacayaBindings.IForcedInclusionStoreForcedInclusion:
		parems = &encoding.BlobParams{
			BlobHashes: [][32]byte{s.BlobHash},
			NumBlobs:   0,
			ByteOffset: s.BlobByteOffset,
			ByteSize:   s.BlobByteSize,
			CreatedIn:  s.BlobCreatedIn,
		}
	case *shastaBindings.IForcedInclusionStoreForcedInclusion:
		parems = &encoding.BlobParams{
			BlobHashes: [][32]byte{s.BlobHash},
			NumBlobs:   0,
			ByteOffset: s.BlobByteOffset,
			ByteSize:   s.BlobByteSize,
			CreatedIn:  s.BlobCreatedIn,
		}
	}
	return parems, []U{
		{
			NumTransactions: uint16(minTxsPerForcedInclusion.Uint64()),
			TimeShift:       0,
			SignalSlots:     make([][32]byte, 0),
		},
	}
}

// func BuildShastaParams[
// 	T *shastaBindings.IForcedInclusionStoreForcedInclusion | *pacayaBindings.IForcedInclusionStoreForcedInclusion,
// 	U shastaBindings.ITaikoInboxBlockParams | pacayaBindings.ITaikoInboxBlockParams,
// 	V *encoding.BatchParamsShasta | *encoding.BatchParamsPacaya,
// ](
// 	ctx context.Context,
// 	taikoWrapperAddress common.Address,
// 	proverSetAddress common.Address,
// 	l2SuggestedFeeRecipient common.Address,
// 	revertProtectionEnabled bool,
// 	proposer common.Address,
// 	txBatch []types.Transactions,
// 	forcedInclusion T,
// 	minTxsPerForcedInclusion *big.Int,
// 	parentMetahash common.Hash,
// ) ([]byte, []byte, error) {
// 	// ABI encode the TaikoWrapper.v4ProposeBatch / ProverSet.v4ProposeBatch parameters.
// 	var (
// 		to                    = taikoWrapperAddress
// 		data                  []byte
// 		encodedParams         []byte
// 		forcedInclusionParams V
// 		allTxs                types.Transactions
// 		blobParams            *encoding.BlobParams
// 		blockParams           []U
// 	)

// 	if proverSetAddress != rpc.ZeroAddress {
// 		to = proverSetAddress
// 		proposer = proverSetAddress
// 	}

// 	if forcedInclusion != nil {
// 		blobParams, blockParams = buildParamsForForcedInclusion[T, U](forcedInclusion, minTxsPerForcedInclusion)
// 		forcedInclusionParams = &encoding.BatchParamsShasta{
// 			Proposer:                 proposer,
// 			Coinbase:                 l2SuggestedFeeRecipient,
// 			RevertIfNotFirstProposal: revertProtectionEnabled,
// 			BlobParams:               *blobParams,
// 			Blocks:                   blockParams,
// 		}
// 	}

// 	for _, txs := range txBatch {
// 		allTxs = append(allTxs, txs...)
// 		blockParams = append(blockParams, shastaBindings.ITaikoInboxBlockParams{
// 			NumTransactions: uint16(len(txs)),
// 			TimeShift:       0,
// 			SignalSlots:     make([][32]byte, 0),
// 		})
// 	}

// 	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
// 	if err != nil {
// 		return nil, nil, err
// 	}

// 	params := &encoding.BatchParamsShasta{
// 		Proposer:                 proposer,
// 		Coinbase:                 b.l2SuggestedFeeRecipient,
// 		RevertIfNotFirstProposal: b.revertProtectionEnabled,
// 		BlobParams: encoding.BlobParams{
// 			ByteOffset: 0,
// 			ByteSize:   uint32(len(txListsBytes)),
// 		},
// 		Blocks: blockParams,
// 	}

// 	if b.revertProtectionEnabled {
// 		if forcedInclusionParams != nil {
// 			forcedInclusionParams.ParentMetaHash = parentMetahash
// 		} else {
// 			params.ParentMetaHash = parentMetahash
// 		}
// 	}

// 	if encodedParams, err = encoding.EncodeBatchParamsShastaWithForcedInclusion(
// 		forcedInclusionParams,
// 		params,
// 	); err != nil {
// 		return nil, err
// 	}
// }
