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
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
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

	// If the Pacaya block is preconfirmed, we don't need to insert it again.
	if meta.BlockID.Cmp(new(big.Int).SetUint64(rpc.PacayaClients.ForkHeight)) >= 0 {
		header, err := isBlockPreconfirmed(ctx, rpc, meta)
		if err != nil {
			log.Debug("Failed to check if the block is preconfirmed", "error", err)
		} else if header != nil {
			if _, err := rpc.L2.WriteL1Origin(ctx, meta.L1Origin); err != nil {
				return nil, fmt.Errorf("failed to write L1 origin: %w", err)
			}
			if _, err := rpc.L2.WriteHeadL1Origin(ctx, meta.L1Origin.BlockID); err != nil {
				return nil, fmt.Errorf("failed to write head L1 origin: %w", err)
			}

			log.Info(
				"🧬 The block is preconfirmed",
				"blockID", meta.BlockID,
				"hash", header.Hash(),
				"coinbase", header.Coinbase,
				"timestamp", header.Time,
				"anchorBlockID", meta.AnchorBlockID,
				"anchorBlockHash", meta.AnchorBlockHash,
				"baseFee", utils.WeiToEther(header.BaseFee),
			)

			return encoding.ToExecutableData(header), nil
		}
	}
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
func isBlockPreconfirmed(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createPayloadAndSetHeadMetaData,
) (*types.Header, error) {
	var blockID = new(big.Int).Add(meta.Parent.Number, common.Big1)
	header, err := rpc.L2.HeaderByNumber(ctx, blockID)
	if err != nil {
		log.Error("Failed to get header by number", "error", err, "number", blockID)
		return nil, fmt.Errorf("failed to get header by number %d: %w", blockID, err)
	}

	if header == nil {
		log.Error("Header not found", "blockID", blockID)
		return nil, fmt.Errorf("header not found for block number %d", blockID)
	}

	var (
		args = &miner.BuildPayloadArgs{
			Parent:       meta.Parent.Hash(),
			Timestamp:    header.Time,
			FeeRecipient: header.Coinbase,
			Random:       header.MixDigest,
			Withdrawals:  make([]*types.Withdrawal, 0),
			Version:      engine.PayloadV2,
		}
		id = args.Id()
	)
	executableData, err := rpc.L2Engine.GetPayload(ctx, &id)
	if err != nil {
		log.Error("Failed to get payload", "error", err)
		return nil, fmt.Errorf("failed to get payload: %w", err)
	}

	if executableData.BlockHash == header.Hash() {
		return header, nil
	}

	return nil, nil
}
