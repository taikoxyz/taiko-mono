package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// createPayloadAndSetHead tries to insert a new head block to the L2 execution engine's local
// block chain through Engine APIs.
func createPayloadAndSetHead(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createPayloadAndSetHeadMetaData,
	anchorTx *types.Transaction,
) (*engine.ExecutableData, error) {
	log.Debug(
		"Try to insert a new L2 head block",
		"parentNumber", meta.Parent.Number,
		"parentHash", meta.Parent.Hash(),
		"l1Origin", meta.L1Origin,
	)

	var lastVerifiedBlockHash common.Hash
	lastVerifiedTS, err := rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		lastVerifiedBlockInfo, err := rpc.GetLastVerifiedBlockOntake(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch last verified block: %w", err)
		}

		if meta.BlockID.Uint64() > lastVerifiedBlockInfo.BlockId {
			lastVerifiedBlockHash = lastVerifiedBlockInfo.BlockHash
		}
	} else {
		if meta.BlockID.Uint64() > lastVerifiedTS.BlockId {
			lastVerifiedBlockHash = lastVerifiedTS.Ts.BlockHash
		}
	}

	payload, err := createExecutionPayloads(
		ctx,
		rpc,
		meta.createExecutionPayloadsMetaData,
		anchorTx,
		lastVerifiedBlockHash,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution payloads: %w", err)
	}

	// If the Pacaya block is preconfirmed, we don't need to insert it again.
	if meta.BlockID.Cmp(new(big.Int).SetUint64(rpc.PacayaClients.ForkHeight)) >= 0 {
		preconfirmed, err := isBlockPreconfirmed(ctx, rpc, payload)
		if err != nil {
			log.Debug("Failed to check if the block is preconfirmed", "error", err)
		} else {
			if preconfirmed {
				log.Info("The block is preconfirmed", "blockID", meta.BlockID, "hash", payload.BlockHash)
				return payload, nil
			}
		}
	}

	fc := &engine.ForkchoiceStateV1{
		HeadBlockHash:      payload.BlockHash,
		SafeBlockHash:      lastVerifiedBlockHash,
		FinalizedBlockHash: lastVerifiedBlockHash,
	}

	// Update the fork choice
	fcRes, err := rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
	if err != nil {
		return nil, err
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	return payload, nil
}

// createExecutionPayloads creates a new execution payloads through
// Engine APIs.
func createExecutionPayloads(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createExecutionPayloadsMetaData,
	anchorTx *types.Transaction,
	lastVerfiiedBlockHash common.Hash,
) (payloadData *engine.ExecutableData, err error) {
	// Insert a TaikoL2.anchor / TaikoL2.anchorV2 transaction at transactions list head
	txListBytes, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, meta.Txs...))
	if err != nil {
		log.Error("Encode txList error", "blockID", meta.BlockID, "error", err)
		return nil, err
	}

	fc := &engine.ForkchoiceStateV1{
		HeadBlockHash:      meta.ParentHash,
		SafeBlockHash:      lastVerfiiedBlockHash,
		FinalizedBlockHash: lastVerfiiedBlockHash,
	}
	attributes := &engine.PayloadAttributes{
		Timestamp:             meta.Timestamp,
		Random:                meta.Difficulty,
		SuggestedFeeRecipient: meta.SuggestedFeeRecipient,
		Withdrawals:           meta.Withdrawals,
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: meta.SuggestedFeeRecipient,
			GasLimit:    meta.GasLimit + consensus.AnchorGasLimit,
			Timestamp:   meta.Timestamp,
			TxList:      txListBytes,
			MixHash:     meta.Difficulty,
			ExtraData:   meta.ExtraData,
		},
		BaseFeePerGas: meta.BaseFee,
		L1Origin:      meta.L1Origin,
	}

	log.Debug(
		"PayloadAttributes",
		"blockID", meta.BlockID,
		"timestamp", attributes.Timestamp,
		"random", attributes.Random,
		"suggestedFeeRecipient", attributes.SuggestedFeeRecipient,
		"withdrawals", len(attributes.Withdrawals),
		"gasLimit", attributes.BlockMetadata.GasLimit,
		"timestamp", attributes.BlockMetadata.Timestamp,
		"mixHash", attributes.BlockMetadata.MixHash,
		"baseFee", utils.WeiToGWei(attributes.BaseFeePerGas),
		"extraData", string(attributes.BlockMetadata.ExtraData),
		"l1OriginHeight", attributes.L1Origin.L1BlockHeight,
		"l1OriginHash", attributes.L1Origin.L1BlockHash,
	)

	// Step 1, prepare a payload
	fcRes, err := rpc.L2Engine.ForkchoiceUpdate(ctx, fc, attributes)
	if err != nil {
		return nil, fmt.Errorf("failed to update fork choice: %w", err)
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}
	if fcRes.PayloadID == nil {
		return nil, errors.New("empty payload ID")
	}

	// Step 2, get the payload
	payload, err := rpc.L2Engine.GetPayload(ctx, fcRes.PayloadID)
	if err != nil {
		return nil, fmt.Errorf("failed to get payload: %w", err)
	}

	log.Debug(
		"Payload",
		"blockID", meta.BlockID,
		"baseFee", utils.WeiToGWei(payload.BaseFeePerGas),
		"number", payload.Number,
		"hash", payload.BlockHash,
		"gasLimit", payload.GasLimit,
		"gasUsed", payload.GasUsed,
		"timestamp", payload.Timestamp,
		"withdrawalsHash", payload.WithdrawalsHash,
	)

	// Step 3, execute the payload
	execStatus, err := rpc.L2Engine.NewPayload(ctx, payload)
	if err != nil {
		return nil, fmt.Errorf("failed to create a new payload: %w", err)
	}
	if execStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected NewPayload response status: %s", execStatus.Status)
	}

	return payload, nil
}

// isBlockPreconfirmed checks if the block is preconfirmed.
func isBlockPreconfirmed(ctx context.Context, rpc *rpc.Client, payload *engine.ExecutableData) (bool, error) {
	header, err := rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(payload.Number))
	if err != nil {
		return false, fmt.Errorf("failed to get header by number %d: %w", payload.Number, err)
	}

	if header == nil {
		return false, fmt.Errorf("header not found for block number %d", payload.Number)
	}

	return header.Hash() == payload.BlockHash, nil
}
