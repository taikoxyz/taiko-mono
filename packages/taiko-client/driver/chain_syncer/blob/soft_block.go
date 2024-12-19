package blob

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	softblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/soft_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// InsertSoftBlockFromTransactionsBatch inserts a soft block into the L2 execution engine's blockchain
// from the given transactions batch.
func (s *Syncer) InsertSoftBlockFromTransactionsBatch(
	ctx context.Context,
	blockID uint64,
	batchID uint64,
	txListBytes []byte,
	batchMarker softblocks.TransactionBatchMarker,
	blockParams *softblocks.SoftBlockParams,
) (*types.Header, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	parent, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).Sub(new(big.Int).SetUint64(blockID), common.Big1))
	if err != nil {
		return nil, err
	}

	if parent.Number.Uint64()+1 != blockID {
		return nil, fmt.Errorf("parent block number (%d) is not equal to blockID - 1 (%d)", parent.Number.Uint64(), blockID)
	}

	// Calculate the other block parameters
	difficultyHashPaylaod, err := encoding.EncodeDifficultyCalcutionParams(blockID)
	if err != nil {
		return nil, fmt.Errorf("failed to encode `block.difficulty` calculation parameters: %w", err)
	}
	protocolConfigs, err := rpc.GetProtocolConfigs(s.rpc.TaikoL1, &bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch protocol configs: %w", err)
	}

	var (
		txList     []*types.Transaction
		fc         = &engine.ForkchoiceStateV1{HeadBlockHash: parent.Hash()}
		difficulty = crypto.Keccak256Hash(difficultyHashPaylaod)
		extraData  = encoding.EncodeBaseFeeConfig(&protocolConfigs.BaseFeeConfig)
	)

	if err := rlp.DecodeBytes(txListBytes, &txList); err != nil {
		return nil, fmt.Errorf("failed to RLP decode txList bytes: %w", err)
	}

	baseFee, err := s.rpc.CalculateBaseFee(
		ctx,
		parent,
		new(big.Int).SetUint64(blockParams.AnchorBlockID),
		true,
		&protocolConfigs.BaseFeeConfig,
		blockParams.Timestamp,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate base fee: %w", err)
	}

	// Insert the anchor transaction at the head of the transactions list.
	if batchID == 0 {
		// Assemble a TaikoL2.anchorV2 transaction.
		anchorTx, err := s.anchorConstructor.AssembleAnchorV2Tx(
			ctx,
			new(big.Int).SetUint64(blockParams.AnchorBlockID),
			blockParams.AnchorStateRoot,
			parent.GasUsed,
			&protocolConfigs.BaseFeeConfig,
			new(big.Int).SetUint64(blockID),
			baseFee,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to create TaikoL2.anchorV2 transaction: %w", err)
		}

		txList = append([]*types.Transaction{anchorTx}, txList...)
	} else {
		prevSoftBlock, err := s.rpc.L2.BlockByNumber(ctx, new(big.Int).SetUint64(blockID))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch previous soft block (%d): %w", blockID, err)
		}

		// Ensure the previous soft block is the current chain head.
		blockNums, err := s.rpc.L2.BlockNumber(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch the chain block number: %w", err)
		}

		if prevSoftBlock.Number().Uint64() != blockNums {
			return nil, fmt.Errorf(
				"soft block (%d) to update is not the current chain head (%d)",
				prevSoftBlock.Number().Uint64(),
				blockNums,
			)
		}

		// Check baseFee
		if prevSoftBlock.BaseFee().Cmp(baseFee) != 0 {
			return nil, fmt.Errorf(
				"baseFee is not equal to the latest soft block's, expect: %s, actual: %s",
				prevSoftBlock.BaseFee().String(),
				baseFee.String(),
			)
		}

		// Check the previous soft block status.
		l1Origin, err := s.rpc.L2.L1OriginByID(ctx, prevSoftBlock.Number())
		if err != nil {
			return nil, fmt.Errorf("failed to fetch L1 origin for block %d: %w", blockID, err)
		}
		if l1Origin.BatchID == nil {
			return nil, fmt.Errorf("batch ID is nil for block %d", blockID)
		}
		if l1Origin.BatchID.Uint64()+1 != batchID {
			return nil, fmt.Errorf("batch ID mismatch: expected %d, got %d", l1Origin.BatchID.Uint64()+1, batchID)
		}
		if l1Origin.EndOfBlock {
			return nil, fmt.Errorf("soft block %d has already been marked as ended", blockID)
		}
		if l1Origin.EndOfPreconf {
			return nil, fmt.Errorf("preconfirmation from %s has already been marked as ended", blockParams.Coinbase)
		}

		txList = append(prevSoftBlock.Transactions(), txList...)
	}

	if txListBytes, err = rlp.EncodeToBytes(txList); err != nil {
		log.Error("Encode txList error", "blockID", blockID, "error", err)
		return nil, err
	}

	attributes := &engine.PayloadAttributes{
		Timestamp:             blockParams.Timestamp,
		Random:                difficulty,
		SuggestedFeeRecipient: blockParams.Coinbase,
		Withdrawals:           []*types.Withdrawal{},
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: blockParams.Coinbase,
			GasLimit:    uint64(protocolConfigs.BlockMaxGasLimit) + consensus.AnchorGasLimit,
			Timestamp:   blockParams.Timestamp,
			TxList:      txListBytes,
			MixHash:     difficulty,
			ExtraData:   extraData[:],
		},
		BaseFeePerGas: baseFee,
		L1Origin: &rawdb.L1Origin{
			BlockID:       new(big.Int).SetUint64(blockID),
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: nil,           // No L1 block height for soft blocks.
			L1BlockHash:   common.Hash{}, // No L1 block hash for soft blocks.
			BatchID:       new(big.Int).SetUint64(batchID),
			EndOfBlock:    batchMarker == softblocks.BatchMarkerEOB,
			EndOfPreconf:  batchMarker == softblocks.BatchMarkerEOP,
			Preconfer:     blockParams.Coinbase,
		},
	}

	log.Info(
		"Soft block payloadAttributes",
		"blockID", blockID,
		"batchID", batchID,
		"timestamp", attributes.Timestamp,
		"random", attributes.Random,
		"suggestedFeeRecipient", attributes.SuggestedFeeRecipient,
		"withdrawals", len(attributes.Withdrawals),
		"gasLimit", attributes.BlockMetadata.GasLimit,
		"timestamp", attributes.BlockMetadata.Timestamp,
		"mixHash", attributes.BlockMetadata.MixHash,
		"baseFee", utils.WeiToGWei(attributes.BaseFeePerGas),
		"extraData", common.Bytes2Hex(attributes.BlockMetadata.ExtraData),
		"transactions", len(txList),
	)

	// Step 1, prepare a payload
	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(ctx, fc, attributes)
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
	payload, err := s.rpc.L2Engine.GetPayload(ctx, fcRes.PayloadID)
	if err != nil {
		return nil, fmt.Errorf("failed to get payload: %w", err)
	}

	log.Info(
		"Soft block payload",
		"blockID", blockID,
		"batchID", batchID,
		"baseFee", utils.WeiToGWei(payload.BaseFeePerGas),
		"number", payload.Number,
		"hash", payload.BlockHash,
		"gasLimit", payload.GasLimit,
		"gasUsed", payload.GasUsed,
		"timestamp", payload.Timestamp,
		"withdrawalsHash", payload.WithdrawalsHash,
	)

	// Step 3, execute the payload
	execStatus, err := s.rpc.L2Engine.NewPayload(ctx, payload)
	if err != nil {
		return nil, fmt.Errorf("failed to create a new payload: %w", err)
	}
	if execStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected NewPayload response status: %s", execStatus.Status)
	}

	lastVerifiedBlockHash, err := s.rpc.GetLastVerifiedBlockHash(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch last verified block hash: %w", err)
	}

	canonicalHead, err := s.rpc.L2.HeadL1Origin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch canonical head: %w", err)
	}

	// Step 4, update the fork choice
	fc = &engine.ForkchoiceStateV1{
		HeadBlockHash:      payload.BlockHash,
		SafeBlockHash:      canonicalHead.L2BlockHash,
		FinalizedBlockHash: lastVerifiedBlockHash,
	}
	fcRes, err = s.rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
	if err != nil {
		return nil, err
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	header, err := s.rpc.L2.HeaderByHash(ctx, payload.BlockHash)
	if err != nil {
		return nil, err
	}

	log.Info(
		"⏰ New soft L2 block inserted",
		"blockID", blockID,
		"batchID", batchID,
		"hash", header.Hash(),
		"transactions", len(payload.Transactions),
		"baseFee", utils.WeiToGWei(header.BaseFee),
		"withdrawals", len(payload.Withdrawals),
		"endOfBlock", attributes.L1Origin.EndOfBlock,
		"endOfPreconf", attributes.L1Origin.EndOfPreconf,
	)

	return header, nil
}

// RemoveSoftBlocks removes soft blocks from the L2 execution engine's blockchain.
func (s *Syncer) RemoveSoftBlocks(ctx context.Context, newLastBlockID uint64) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	newHead, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(newLastBlockID))
	if err != nil {
		return err
	}

	fc := &engine.ForkchoiceStateV1{HeadBlockHash: newHead.Hash()}
	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
	if err != nil {
		return err
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	return nil
}
