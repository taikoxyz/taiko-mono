package builder

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/params"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BuildProposalParams builds the proposal params for the given forced inclusion.
func BuildProposalParams[
	T *shastaBindings.IForcedInclusionStoreForcedInclusion | *pacayaBindings.IForcedInclusionStoreForcedInclusion,
](
	ctx context.Context,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	revertProtectionEnabled bool,
	proposer common.Address,
	txBatch []types.Transactions,
	forcedInclusion T,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) ([]byte, []byte, error) {
	var (
		forcedInclusionblobParams  params.ITaikoInboxBlobParams
		forcedInclusionblockParams []params.ITaikoInboxBlockParams
		forcedInclusionBatchParams params.ITaikoInboxBatchParams
		blockParams                []params.ITaikoInboxBlockParams
		batchParams                params.ITaikoInboxBatchParams
		allTxs                     types.Transactions
	)

	if proverSetAddress != rpc.ZeroAddress {
		proposer = proverSetAddress
	}

	if !revertProtectionEnabled {
		parentMetahash = common.Hash{}
	}

	for _, txs := range txBatch {
		allTxs = append(allTxs, txs...)
		blockParams = append(blockParams, params.NewBlockParams(uint16(len(txs)), 0, make([][32]byte, 0)))
	}

	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode and compress transactions list: %w", err)
	}

	if forcedInclusion != nil {
		forcedInclusionblobParams, forcedInclusionblockParams = buildParamsForForcedInclusion[T](
			forcedInclusion,
			minTxsPerForcedInclusion,
		)

		switch any(forcedInclusion).(type) {
		case *pacayaBindings.IForcedInclusionStoreForcedInclusion:
			forcedInclusionBatchParams = params.NewBatchParamsPacaya(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				forcedInclusionblobParams,
				forcedInclusionblockParams,
			)
			// TODO: move to outside of the if statement
			batchParams = params.NewBatchParamsPacaya(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				params.NewBlobParams([][32]byte{}, 0, 0, 0, uint32(len(txListsBytes)), 0),
				blockParams,
			)
		case *shastaBindings.IForcedInclusionStoreForcedInclusion:
			forcedInclusionBatchParams = params.NewBatchParamsShasta(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				forcedInclusionblobParams,
				forcedInclusionblockParams,
				[]byte{},
			)
			batchParams = params.NewBatchParamsShasta(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				params.NewBlobParams([][32]byte{}, 0, 0, 0, uint32(len(txListsBytes)), 0),
				blockParams,
				nil,
			)
		}
	}

	encodedParams, err := encoding.EncodeBatchParamsWithForcedInclusion(forcedInclusionBatchParams, batchParams)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode batch params: %w", err)
	}

	return encodedParams, txListsBytes, nil
}
