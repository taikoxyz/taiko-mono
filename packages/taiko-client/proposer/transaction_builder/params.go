package builder

import (
	"context"
	"fmt"

	"github.com/ethereum-optimism/optimism/op-service/eth"
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
	parentMetahash common.Hash,
	isShasta bool,
	blobUsed bool,
) ([]byte, []byte, []*eth.Blob, error) {
	var (
		forcedInclusionblobParams  bindingTypes.ITaikoInboxBlobParams
		forcedInclusionblockParams []bindingTypes.ITaikoInboxBlockParams
		forcedInclusionBatchParams bindingTypes.ITaikoInboxBatchParams
		blockParams                []bindingTypes.ITaikoInboxBlockParams
		batchParams                bindingTypes.ITaikoInboxBatchParams
		allTxs                     types.Transactions
		blobs                      []*eth.Blob
		numBlobs                   uint8
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
		numBlobs = uint8(len(blobs))
	}

	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to encode and compress transactions list: %w", err)
	}

	if blobUsed {
		if blobs, err = SplitToBlobs(txListsBytes); err != nil {
			return nil, nil, nil, fmt.Errorf("failed to split transactions bytes into blobs: %w", err)
		}
	}

	if isShasta {
		// TODO: need to find a specific anchor ID for shasta fork
		batchParams = bindingTypes.NewBatchParamsShasta(
			proposer,
			l2SuggestedFeeRecipient,
			parentMetahash,
			0,
			0,
			revertProtectionEnabled,
			bindingTypes.NewBlobParams([][32]byte{}, 0, numBlobs, 0, uint32(len(txListsBytes)), 0),
			blockParams,
			[]byte{},
		)
	} else {
		batchParams = bindingTypes.NewBatchParamsPacaya(
			proposer,
			l2SuggestedFeeRecipient,
			parentMetahash,
			0,
			0,
			revertProtectionEnabled,
			bindingTypes.NewBlobParams([][32]byte{}, 0, numBlobs, 0, uint32(len(txListsBytes)), 0),
			blockParams,
		)
	}
	if forcedInclusion != nil {
		forcedInclusionblobParams, forcedInclusionblockParams = buildParamsForForcedInclusion(
			forcedInclusion,
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
		}
	}

	encodedParams, err := encoding.EncodeBatchParamsWithForcedInclusion(forcedInclusionBatchParams, batchParams)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to encode batch params: %w", err)
	}

	return encodedParams, txListsBytes, blobs, nil
}

// SplitToBlobs splits the txListBytes into multiple blobs.
func SplitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
	var blobs []*eth.Blob
	for start := 0; start < len(txListBytes); start += eth.MaxBlobDataSize {
		end := start + eth.MaxBlobDataSize
		if end > len(txListBytes) {
			end = len(txListBytes)
		}

		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}
