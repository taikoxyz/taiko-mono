package blocksinserter

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/rlp"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
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
	// Insert a TaikoAnchor.anchorV3 transaction at transactions list head,
	// then encode the transactions list.
	txListBytes, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, meta.Txs...))
	if err != nil {
		log.Error("Encode txList error", "blockID", meta.BlockID, "error", err)
		return nil, fmt.Errorf("failed to encode transaction list for block %d: %w", meta.BlockID, err)
	}

	// Increase the gas limit for the anchor block.
	meta.GasLimit += consensus.AnchorV3GasLimit

	// Update execution payload id for the L1 origin.
	var (
		txListHash = crypto.Keccak256Hash(txListBytes)
		args       = &miner.BuildPayloadArgs{
			Parent:       meta.ParentHash,
			Timestamp:    meta.Timestamp,
			FeeRecipient: meta.SuggestedFeeRecipient,
			Random:       meta.Difficulty,
			Withdrawals:  make([]*types.Withdrawal, 0),
			Version:      engine.PayloadV2,
			TxListHash:   &txListHash,
		}
	)
	meta.L1Origin.BuildPayloadArgsID = args.Id()

	// Create a new execution payload and set the chain head.
	return createExecutionPayloadsAndSetHead(ctx, rpc, meta.createExecutionPayloadsMetaData, txListBytes)
}

// createExecutionPayloadsAndSetHead creates a new execution payloads through Engine APIs,
// and sets the head block to the L2 execution engine's local block chain.
func createExecutionPayloadsAndSetHead(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createExecutionPayloadsMetaData,
	txListBytes []byte,
) (payloadData *engine.ExecutableData, err error) {
	// Create a new execution payload.
	payload, err := createExecutionPayloads(ctx, rpc, meta, txListBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution payloads: %w", err)
	}

	var lastVerifiedBlockHash common.Hash
	lastVerifiedTS, err := rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch last verified block: %w", err)
	}

	if meta.BlockID.Uint64() > lastVerifiedTS.BlockId {
		lastVerifiedBlockHash = lastVerifiedTS.Ts.BlockHash
	}

	fc := &engine.ForkchoiceStateV1{
		HeadBlockHash:      payload.BlockHash,
		SafeBlockHash:      lastVerifiedBlockHash,
		FinalizedBlockHash: lastVerifiedBlockHash,
	}

	// Update the fork choice.
	fcRes, err := rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to update fork choice: %w", err)
	}
	if fcRes.PayloadStatus.Status != engine.VALID {
		return nil, fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	return payload, nil
}

// createExecutionPayloads creates a new execution payloads through Engine APIs.
func createExecutionPayloads(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createExecutionPayloadsMetaData,
	txListBytes []byte,
) (payloadData *engine.ExecutableData, err error) {
	attributes := &engine.PayloadAttributes{
		Timestamp:             meta.Timestamp,
		Random:                meta.Difficulty,
		SuggestedFeeRecipient: meta.SuggestedFeeRecipient,
		Withdrawals:           meta.Withdrawals,
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: meta.SuggestedFeeRecipient,
			GasLimit:    meta.GasLimit,
			Timestamp:   meta.Timestamp,
			TxList:      txListBytes,
			MixHash:     meta.Difficulty,
			ExtraData:   meta.ExtraData,
		},
		BaseFeePerGas: meta.BaseFee,
		L1Origin:      meta.L1Origin,
	}

	log.Debug(
		"Payload attributes",
		"blockID", meta.BlockID,
		"timestamp", attributes.Timestamp,
		"random", attributes.Random,
		"suggestedFeeRecipient", attributes.SuggestedFeeRecipient,
		"withdrawals", len(attributes.Withdrawals),
		"gasLimit", attributes.BlockMetadata.GasLimit,
		"timestamp", attributes.BlockMetadata.Timestamp,
		"mixHash", attributes.BlockMetadata.MixHash,
		"baseFee", utils.WeiToGWei(attributes.BaseFeePerGas),
		"extraData", common.Bytes2Hex(attributes.BlockMetadata.ExtraData),
		"l1OriginHeight", attributes.L1Origin.L1BlockHeight,
		"l1OriginHash", attributes.L1Origin.L1BlockHash,
		"signature", common.Bytes2Hex(attributes.L1Origin.Signature[:]),
	)

	// Step 1, prepare a payload
	fcRes, err := rpc.L2Engine.ForkchoiceUpdate(
		ctx,
		&engine.ForkchoiceStateV1{HeadBlockHash: meta.ParentHash},
		attributes,
	)
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

// isKnownCanonicalBatch checks if all blocks in the given batch are in the canonical chain already.,
// and returns the header of the last block in the batch if it is.
func isKnownCanonicalBatch(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	allTxs []*types.Transaction,
	txListBytes []byte,
	parent *types.Header,
) (*types.Header, error) {
	var (
		headers = make([]*types.Header, len(metadata.Pacaya().GetBlocks()))
		g       = new(errgroup.Group)
	)

	// Check each block in the batch, and if the all blocks are preconfirmed, return the header of the last block.
	for i := 0; i < len(metadata.Pacaya().GetBlocks()); i++ {
		g.Go(func() error {
			parentHeader, err := rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(parent.Number.Uint64()+uint64(i)))
			if err != nil {
				return fmt.Errorf("failed to get parent block by number %d: %w", parent.Number.Uint64()+uint64(i), err)
			}

			createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaPacaya(
				ctx,
				rpc,
				anchorConstructor,
				metadata,
				allTxs,
				parentHeader,
				i,
			)
			if err != nil {
				return fmt.Errorf("failed to assemble execution payload creation metadata: %w", err)
			}

			b, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, createExecutionPayloadsMetaData.Txs...))
			if err != nil {
				return fmt.Errorf("failed to RLP encode tx list: %w", err)
			}

			if headers[i], err = isKnownCanonicalBlock(
				ctx,
				rpc,
				&createPayloadAndSetHeadMetaData{
					createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
					AnchorBlockID:                   new(big.Int).SetUint64(metadata.Pacaya().GetAnchorBlockID()),
					AnchorBlockHash:                 metadata.Pacaya().GetAnchorBlockHash(),
					BaseFeeConfig:                   metadata.Pacaya().GetBaseFeeConfig(),
					Parent:                          parentHeader,
				},
				b,
				anchorTx,
			); err != nil {
				return fmt.Errorf("block %d is an unknown block, reason: %w", createExecutionPayloadsMetaData.BlockID, err)
			}

			return nil
		})
	}

	return headers[len(headers)-1], g.Wait()
}

// isKnownCanonicalBlock checks if the block is in canonical chain already.
func isKnownCanonicalBlock(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createPayloadAndSetHeadMetaData,
	txListBytes []byte,
	anchorTx *types.Transaction,
) (*types.Header, error) {
	var blockID = new(big.Int).Add(meta.Parent.Number, common.Big1)
	block, err := rpc.L2.BlockByNumber(ctx, blockID)
	if err != nil {
		return nil, fmt.Errorf("failed to get block by number %d: %w", blockID, err)
	}

	if block == nil {
		return nil, fmt.Errorf("block not found by number %d", blockID)
	}

	var (
		txListHash = crypto.Keccak256Hash(txListBytes[:])
		args       = &miner.BuildPayloadArgs{
			Parent:       meta.Parent.Hash(),
			Timestamp:    meta.Timestamp,
			FeeRecipient: meta.SuggestedFeeRecipient,
			Random:       meta.Difficulty,
			Withdrawals:  make([]*types.Withdrawal, 0),
			Version:      engine.PayloadV2,
			TxListHash:   &txListHash,
		}
		id = args.Id()
	)

	log.Info(
		"Check if block is known in canonical chain",
		"blockID", blockID,
		"blockHash", block.Hash(),
		"args", args,
	)

	l1Origin, err := rpc.L2.L1OriginByID(ctx, blockID)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return nil, fmt.Errorf("failed to get L1Origin by ID %d: %w", blockID, err)
	}
	// If L1Origin is not found, it means this block is synced from beacon sync.
	if l1Origin == nil {
		return nil, fmt.Errorf("L1Origin not found by ID %d", blockID)
	}
	// If the payload ID matches, it means this block is already in the canonical chain.
	if l1Origin.BuildPayloadArgsID != [8]byte{} && !bytes.Equal(l1Origin.BuildPayloadArgsID[:], id[:]) {
		return nil, fmt.Errorf(
			`payload ID for block %d mismatch,
			l1Origin payload id: %s,
			current payload id %s,
			parentHash: %s,
			timestamp: %d,
			suggestedFeeRecipient: %s,
			difficulty: %s,
			txListHash: %s`,
			blockID,
			engine.PayloadID(l1Origin.BuildPayloadArgsID),
			id,
			meta.Parent.Hash().Hex(),
			meta.Timestamp,
			meta.SuggestedFeeRecipient.Hex(),
			meta.Difficulty.Hex(),
			txListHash.Hex(),
		)
	}
	defer func() {
		if err != nil {
			log.Warn("Unknown block for the canonical chain", "blockID", blockID, "coinbase", block.Coinbase(), "reason", err)
		}
	}()

	if block.ParentHash() != meta.Parent.Hash() {
		err = fmt.Errorf("parent hash mismatch: %s != %s", block.ParentHash(), meta.Parent.Hash())
		return nil, err
	}
	if block.Transactions().Len() == 0 {
		err = errors.New("transactions list is empty")
		return nil, err
	}
	if block.Transactions()[0].Hash() != anchorTx.Hash() {
		err = fmt.Errorf("anchor transaction mismatch: %s != %s", block.Transactions()[0].Hash(), anchorTx.Hash())
		return nil, err
	}
	if block.UncleHash() != types.EmptyUncleHash {
		err = fmt.Errorf("uncle hash mismatch: %s != %s", block.UncleHash(), types.EmptyUncleHash)
		return nil, err
	}
	if block.Coinbase() != meta.SuggestedFeeRecipient {
		err = fmt.Errorf("coinbase mismatch: %s != %s", block.Coinbase(), meta.SuggestedFeeRecipient)
		return nil, err
	}
	if block.Difficulty().Cmp(common.Big0) != 0 {
		err = fmt.Errorf("difficulty mismatch: %s != 0", block.Difficulty())
		return nil, err
	}
	if block.MixDigest() != meta.Difficulty {
		err = fmt.Errorf("mixDigest mismatch: %s != %s", block.MixDigest(), meta.Difficulty)
		return nil, err
	}
	if block.Number().Uint64() != meta.BlockID.Uint64() {
		err = fmt.Errorf("block number mismatch: %d != %d", block.Number(), meta.BlockID)
		return nil, err
	}
	if block.GasLimit() != meta.GasLimit+consensus.AnchorV3GasLimit {
		err = fmt.Errorf("gas limit mismatch: %d != %d", block.GasLimit(), meta.GasLimit+consensus.AnchorV3GasLimit)
		return nil, err
	}
	if block.Time() != meta.Timestamp {
		err = fmt.Errorf("timestamp mismatch: %d != %d", block.Time(), meta.Timestamp)
		return nil, err
	}
	if !bytes.Equal(block.Extra(), meta.ExtraData) {
		err = fmt.Errorf("extra data mismatch: %s != %s", block.Extra(), meta.ExtraData)
		return nil, err
	}
	if block.BaseFee().Cmp(meta.BaseFee) != 0 {
		err = fmt.Errorf("base fee mismatch: %s != %s", block.BaseFee(), meta.BaseFee)
		return nil, err
	}
	if block.Withdrawals().Len() != 0 {
		err = fmt.Errorf("withdrawals mismatch: %d != 0", block.Withdrawals().Len())
		return nil, err
	}

	return block.Header(), nil
}

// assembleCreateExecutionPayloadMetaPacaya assembles the metadata for creating an execution payload,
// and the `TaikoAnchor.anchorV3` transaction for the given Pacaya block.
func assembleCreateExecutionPayloadMetaPacaya(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	allTxsInBatch []*types.Transaction,
	parent *types.Header,
	blockIndex int,
) (*createExecutionPayloadsMetaData, *types.Transaction, error) {
	if !metadata.IsPacaya() {
		return nil, nil, fmt.Errorf("metadata is not for Pacaya fork")
	}
	if blockIndex >= len(metadata.Pacaya().GetBlocks()) {
		return nil, nil, fmt.Errorf("block index %d out of bounds", blockIndex)
	}

	var (
		meta         = metadata.Pacaya()
		blockID      = new(big.Int).Add(parent.Number, common.Big1)
		blockInfo    = meta.GetBlocks()[blockIndex]
		txListCursor = 0
	)
	difficulty, err := encoding.CalculatePacayaDifficulty(blockID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate difficulty: %w", err)
	}
	timestamp := meta.GetLastBlockTimestamp()
	for i := len(meta.GetBlocks()) - 1; i > blockIndex; i-- {
		timestamp = timestamp - uint64(meta.GetBlocks()[i].TimeShift)
	}
	baseFee, err := rpc.CalculateBaseFee(ctx, parent, meta.GetBaseFeeConfig(), timestamp)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate base fee: %w", err)
	}

	log.Info(
		"L2 baseFee",
		"blockID", blockID,
		"baseFee", utils.WeiToGWei(baseFee),
		"parentnumber", parent.Number,
		"parentHash", parent.Hash(),
		"parentGasUsed", parent.GasUsed,
		"batchID", meta.GetBatchID(),
		"indexInBatch", blockIndex,
	)

	// Assemble a TaikoAnchor.anchorV3 transaction
	anchorBlockHeader, err := rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
	if err != nil {
		return nil, nil, fmt.Errorf("failed to fetch anchor block: %w", err)
	}

	anchorTx, err := anchorConstructor.AssembleAnchorV3Tx(
		ctx,
		new(big.Int).SetUint64(meta.GetAnchorBlockID()),
		anchorBlockHeader.Root,
		parent,
		meta.GetBaseFeeConfig(),
		meta.GetBlocks()[blockIndex].SignalSlots,
		blockID,
		baseFee,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create TaikoAnchor.anchorV3 transaction: %w", err)
	}

	for i := 0; i < blockIndex; i++ {
		txListCursor += int(meta.GetBlocks()[i].NumTransactions)
	}

	// Get transactions in the block.
	txs := types.Transactions{}
	if txListCursor+int(blockInfo.NumTransactions) <= len(allTxsInBatch) {
		txs = allTxsInBatch[txListCursor : txListCursor+int(blockInfo.NumTransactions)]
	} else if txListCursor < len(allTxsInBatch) {
		txs = allTxsInBatch[txListCursor:]
	}

	return &createExecutionPayloadsMetaData{
		BlockID:               blockID,
		ExtraData:             meta.GetExtraData(),
		SuggestedFeeRecipient: meta.GetCoinbase(),
		GasLimit:              uint64(meta.GetGasLimit()),
		Difficulty:            common.BytesToHash(difficulty),
		Timestamp:             timestamp,
		ParentHash:            parent.Hash(),
		L1Origin: &rawdb.L1Origin{
			BlockID:       blockID,
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: meta.GetRawBlockHeight(),
			L1BlockHash:   meta.GetRawBlockHash(),
		},
		Txs:         txs,
		Withdrawals: make([]*types.Withdrawal, 0),
		BaseFee:     baseFee,
	}, anchorTx, nil
}

// updateL1OriginForBatch updates the L1 origin for the given batch of blocks.
func updateL1OriginForBatch(
	ctx context.Context,
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
) error {
	if !metadata.IsPacaya() {
		return fmt.Errorf("metadata is not for Pacaya fork")
	}

	var (
		meta = metadata.Pacaya()
		g    = new(errgroup.Group)
	)

	for i := 0; i < len(meta.GetBlocks()); i++ {
		g.Go(func() error {
			blockID := new(big.Int).SetUint64(meta.GetLastBlockID() - uint64(len(meta.GetBlocks())-1-i))

			header, err := rpc.L2.HeaderByNumber(ctx, blockID)
			if err != nil {
				return fmt.Errorf("failed to get block by number %d: %w", blockID, err)
			}

			l1Origin := &rawdb.L1Origin{
				BlockID:       blockID,
				L2BlockHash:   header.Hash(),
				L1BlockHeight: meta.GetRawBlockHeight(),
				L1BlockHash:   meta.GetRawBlockHash(),
			}
			// Fetch the original L1Origin to get the BuildPayloadArgsID.
			originalL1Origin, err := rpc.L2.L1OriginByID(ctx, blockID)
			if err != nil && !errors.Is(err, ethereum.NotFound) {
				return fmt.Errorf("failed to get L1Origin by ID %d: %w", blockID, err)
			}
			// If L1Origin is not found, it means this block is synced from beacon sync,
			// and we also won't set the `BuildPayloadArgsID` value and related fields.
			if originalL1Origin != nil {
				l1Origin.BuildPayloadArgsID = originalL1Origin.BuildPayloadArgsID
				l1Origin.Signature = originalL1Origin.Signature
				l1Origin.IsForcedInclusion = originalL1Origin.IsForcedInclusion
			}

			if _, err := rpc.L2Engine.UpdateL1Origin(ctx, l1Origin); err != nil {
				return fmt.Errorf("failed to update L1Origin: %w", err)
			}

			// If this is the most recent block, update the HeadL1Origin.
			if i == len(meta.GetBlocks())-1 {
				log.Info("Update head L1 origin", "blockID", blockID, "l1Origin", l1Origin)
				if _, err := rpc.L2Engine.SetHeadL1Origin(ctx, l1Origin.BlockID); err != nil {
					return fmt.Errorf("failed to write head L1 origin: %w", err)
				}
			}

			return nil
		})
	}
	return g.Wait()
}
