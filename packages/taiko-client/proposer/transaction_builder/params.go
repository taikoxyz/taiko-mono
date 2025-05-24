package builder

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BuildProposalParams builds the proposal params for the given forced inclusion.
func BuildProposalParams(
	ctx context.Context,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	revertProtectionEnabled bool,
	proposer common.Address,
	txBatch []types.Transactions,
	forcedInclusion bindingTypes.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) ([]byte, []byte, error) {
	var (
		forcedInclusionblobParams  bindingTypes.ITaikoInboxBlobParams
		forcedInclusionblockParams []bindingTypes.ITaikoInboxBlockParams
		forcedInclusionBatchParams bindingTypes.ITaikoInboxBatchParams
		blockParams                []bindingTypes.ITaikoInboxBlockParams
		batchParams                bindingTypes.ITaikoInboxBatchParams
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
		blockParams = append(blockParams, bindingTypes.NewBlockParams(uint16(len(txs)), 0, make([][32]byte, 0)))
	}

	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode and compress transactions list: %w", err)
	}

	if forcedInclusion != nil {
		forcedInclusionblobParams, forcedInclusionblockParams = buildParamsForForcedInclusion(
			forcedInclusion,
			minTxsPerForcedInclusion,
		)

		switch any(forcedInclusion).(type) {
		case *pacayaBindings.IForcedInclusionStoreForcedInclusion:
			forcedInclusionBatchParams = bindingTypes.NewBatchParamsPacaya(
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
			batchParams = bindingTypes.NewBatchParamsPacaya(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				bindingTypes.NewBlobParams([][32]byte{}, 0, 0, 0, uint32(len(txListsBytes)), 0),
				blockParams,
			)
		case *shastaBindings.IForcedInclusionStoreForcedInclusion:
			forcedInclusionBatchParams = bindingTypes.NewBatchParamsShasta(
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
			batchParams = bindingTypes.NewBatchParamsShasta(
				proposer,
				l2SuggestedFeeRecipient,
				parentMetahash,
				0,
				0,
				revertProtectionEnabled,
				bindingTypes.NewBlobParams([][32]byte{}, 0, 0, 0, uint32(len(txListsBytes)), 0),
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
