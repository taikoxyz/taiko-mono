package blocksinserter

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/holiman/uint256"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	shastaManifest "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// errBatchNotKnown is returned when a batch is not known in the canonical chain.
var errBatchNotKnown = errors.New("batch not known in canonical chain")

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
	// Insert a TaikoAnchor.anchorV3 / ShastaAnchor.anchorV4 transaction at transactions list head,
	// then encode the transactions list.
	txListBytes, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, meta.Txs...))
	if err != nil {
		log.Error("Encode txList error", "blockID", meta.BlockID, "error", err)
		return nil, fmt.Errorf("failed to encode transaction list for block %d: %w", meta.BlockID, err)
	}

	// Increase the gas limit for the anchor block.
	meta.GasLimit += consensus.AnchorV3V4GasLimit

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
	return createExecutionPayloadsAndSetHead(
		ctx,
		rpc,
		meta.createExecutionPayloadsMetaData,
		txListBytes,
		meta.VerifiedCheckpoint,
	)
}

// createExecutionPayloadsAndSetHead creates a new execution payloads through Engine APIs,
// and sets the head block to the L2 execution engine's local block chain.
func createExecutionPayloadsAndSetHead(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createExecutionPayloadsMetaData,
	txListBytes []byte,
	safeCheckpoint *verifiedCheckpoint,
) (payloadData *engine.ExecutableData, err error) {
	// Create a new execution payload.
	payload, err := createExecutionPayloads(ctx, rpc, meta, txListBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution payloads: %w", err)
	}

	var lastVerifiedBlockHash common.Hash
	if safeCheckpoint != nil && safeCheckpoint.BlockID != nil && meta.BlockID.Cmp(safeCheckpoint.BlockID) > 0 {
		lastVerifiedBlockHash = safeCheckpoint.BlockHash
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
			BatchID:     meta.BatchID,
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

// isKnownCanonicalBatchPacaya checks if all blocks in the given Pacaya batch are in the canonical chain already,
// and returns the header of the last block in the batch if it is.
func isKnownCanonicalBatchPacaya(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	allTxs []*types.Transaction,
	parent *types.Header,
) (*types.Header, bool, error) {
	var (
		headers = make([]*types.Header, len(metadata.Pacaya().GetBlocks()))
		g       = new(errgroup.Group)
	)

	// Check each block in the batch, and if all blocks are preconfirmed, return the header of the last block.
	for i := 0; i < len(metadata.Pacaya().GetBlocks()); i++ {
		g.Go(func() error {
			parentHeader, err := rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(parent.Number.Uint64()+uint64(i)))
			if err != nil {
				if errors.Is(err, ethereum.NotFound) {
					return errBatchNotKnown
				}
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

			var known bool
			if headers[i], known, err = isKnownCanonicalBlock(
				ctx,
				rpc,
				&createPayloadAndSetHeadMetaData{
					createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
					Parent:                          parentHeader,
				},
				b,
				anchorTx,
			); err != nil {
				return err
			}
			if !known {
				return errBatchNotKnown
			}
			return nil
		})
	}

	// Wait for all goroutines to finish, and check for errors.
	if err := g.Wait(); err != nil {
		if errors.Is(err, errBatchNotKnown) {
			return nil, false, nil
		}
		return nil, false, err
	}

	return headers[len(headers)-1], true, nil
}

// isKnownCanonicalBatchShasta checks if all blocks in the given Shasta batch are in the canonical chain already,
// and returns the header of the last block in the batch if it is.
func isKnownCanonicalBatchShasta(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	parent *types.Header,
) (*types.Header, bool, error) {
	if !metadata.IsShasta() {
		return nil, false, fmt.Errorf("metadata is not for Shasta fork blocks")
	}
	var (
		headers = make([]*types.Header, len(sourcePayload.BlockPayloads))
		g       = new(errgroup.Group)
	)

	// Check each block in the batch, and if all blocks are preconfirmed, return the header of the last block.
	for i := 0; i < len(sourcePayload.BlockPayloads); i++ {
		g.Go(func() error {
			parentHeader, err := rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(parent.Number.Uint64()+uint64(i)))
			if err != nil {
				if errors.Is(err, ethereum.NotFound) {
					return errBatchNotKnown
				}
				return fmt.Errorf("failed to get parent block by number %d: %w", parent.Number.Uint64()+uint64(i), err)
			}

			createExecutionPayloadsMetaData, anchorTx, err := assembleCreateExecutionPayloadMetaShasta(
				ctx,
				rpc,
				anchorConstructor,
				metadata,
				sourcePayload,
				parentHeader,
				i,
			)
			if err != nil {
				return fmt.Errorf("failed to assemble Shasta execution payload creation metadata: %w", err)
			}

			b, err := rlp.EncodeToBytes(append([]*types.Transaction{anchorTx}, createExecutionPayloadsMetaData.Txs...))
			if err != nil {
				return fmt.Errorf("failed to RLP encode tx list: %w", err)
			}

			var known bool
			if headers[i], known, err = isKnownCanonicalBlock(
				ctx,
				rpc,
				&createPayloadAndSetHeadMetaData{
					createExecutionPayloadsMetaData: createExecutionPayloadsMetaData,
					Parent:                          parentHeader,
				},
				b,
				anchorTx,
			); err != nil {
				return err
			}
			if !known {
				return errBatchNotKnown
			}
			return nil
		})
	}

	// Wait for all goroutines to finish, and check for errors.
	if err := g.Wait(); err != nil {
		if errors.Is(err, errBatchNotKnown) {
			return nil, false, nil
		}
		return nil, false, err
	}

	return headers[len(headers)-1], true, nil
}

// isKnownCanonicalBlock checks if the block is in canonical chain already.
func isKnownCanonicalBlock(
	ctx context.Context,
	rpc *rpc.Client,
	meta *createPayloadAndSetHeadMetaData,
	txListBytes []byte,
	anchorTx *types.Transaction,
) (*types.Header, bool, error) {
	var blockID = new(big.Int).Add(meta.Parent.Number, common.Big1)
	block, err := rpc.L2.BlockByNumber(ctx, blockID)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return nil, false, fmt.Errorf("failed to get block by number %d: %w", blockID, err)
	}

	// Helper function to log unknown block reasons.
	logUnknown := func(reason string) {
		fields := []interface{}{"blockID", blockID, "reason", reason}
		if block != nil {
			fields = append(fields, "coinbase", block.Coinbase())
		}
		log.Warn("Unknown block for the canonical chain", fields...)
	}

	if block == nil {
		logUnknown("block not found")
		return nil, false, nil
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
		return nil, false, fmt.Errorf("failed to get L1Origin by ID %d: %w", blockID, err)
	}
	// If L1Origin is not found, it means this block is synced from beacon sync.
	if l1Origin == nil {
		logUnknown("L1Origin not found")
		return nil, false, nil
	}

	if block.ParentHash() != meta.Parent.Hash() {
		logUnknown(fmt.Sprintf("parent hash mismatch: %s != %s", block.ParentHash(), meta.Parent.Hash()))
		return nil, false, nil
	}
	if block.Transactions().Len() == 0 {
		logUnknown("transactions list is empty")
		return nil, false, nil
	}
	if block.Transactions()[0].Hash() != anchorTx.Hash() {
		logUnknown(fmt.Sprintf("anchor transaction mismatch: %s != %s", block.Transactions()[0].Hash(), anchorTx.Hash()))
		return nil, false, nil
	}
	if block.UncleHash() != types.EmptyUncleHash {
		logUnknown(fmt.Sprintf("uncle hash mismatch: %s != %s", block.UncleHash(), types.EmptyUncleHash))
		return nil, false, nil
	}
	if block.Coinbase() != meta.SuggestedFeeRecipient {
		logUnknown(fmt.Sprintf("coinbase mismatch: %s != %s", block.Coinbase(), meta.SuggestedFeeRecipient))
		return nil, false, nil
	}
	if block.Difficulty().Cmp(common.Big0) != 0 {
		logUnknown(fmt.Sprintf("difficulty mismatch: %s != 0", block.Difficulty()))
		return nil, false, nil
	}
	if block.MixDigest() != meta.Difficulty {
		logUnknown(fmt.Sprintf("mixDigest mismatch: %s != %s", block.MixDigest(), meta.Difficulty))
		return nil, false, nil
	}
	if block.Number().Uint64() != meta.BlockID.Uint64() {
		logUnknown(fmt.Sprintf("block number mismatch: %d != %d", block.Number(), meta.BlockID))
		return nil, false, nil
	}
	if block.GasLimit() != meta.GasLimit+consensus.AnchorV3V4GasLimit {
		logUnknown(fmt.Sprintf("gas limit mismatch: %d != %d", block.GasLimit(), meta.GasLimit+consensus.AnchorV3V4GasLimit))
		return nil, false, nil
	}
	if block.Time() != meta.Timestamp {
		logUnknown(fmt.Sprintf("timestamp mismatch: %d != %d", block.Time(), meta.Timestamp))
		return nil, false, nil
	}
	if !bytes.Equal(block.Extra(), meta.ExtraData) {
		logUnknown(fmt.Sprintf("extra data mismatch: %s != %s", block.Extra(), meta.ExtraData))
		return nil, false, nil
	}
	if block.BaseFee().Cmp(meta.BaseFee) != 0 {
		logUnknown(fmt.Sprintf("base fee mismatch: %s != %s", block.BaseFee(), meta.BaseFee))
		return nil, false, nil
	}
	if block.Withdrawals().Len() != 0 {
		logUnknown(fmt.Sprintf("withdrawals mismatch: %d != 0", block.Withdrawals().Len()))
		return nil, false, nil
	}
	// If the payload ID matches, it means this block is already in the canonical chain.
	if l1Origin.BuildPayloadArgsID != [8]byte{} && !bytes.Equal(l1Origin.BuildPayloadArgsID[:], id[:]) {
		logUnknown(fmt.Sprintf(
			"payload ID mismatch: l1Origin payload id: %s, current payload id %s, parentHash: %s, "+
				"timestamp: %d, suggestedFeeRecipient: %s, difficulty: %s, txListHash: %s",
			engine.PayloadID(l1Origin.BuildPayloadArgsID),
			id,
			meta.Parent.Hash().Hex(),
			meta.Timestamp,
			meta.SuggestedFeeRecipient.Hex(),
			meta.Difficulty.Hex(),
			txListHash.Hex(),
		))
		return nil, false, nil
	}

	return block.Header(), true, nil
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
	baseFee, err := rpc.CalculateBaseFeePacaya(ctx, parent, timestamp, meta.GetBaseFeeConfig())
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
		BatchID:               meta.GetBatchID(),
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

// assembleCreateExecutionPayloadMetaShasta assembles the metadata for creating an execution payload,
// and the `ShastaAnchor.anchorV4` transaction for the given Shasta block.
func assembleCreateExecutionPayloadMetaShasta(
	ctx context.Context,
	rpc *rpc.Client,
	anchorConstructor *anchorTxConstructor.AnchorTxConstructor,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
	parent *types.Header,
	blockIndex int,
) (*createExecutionPayloadsMetaData, *types.Transaction, error) {
	if !metadata.IsShasta() {
		return nil, nil, fmt.Errorf("metadata is not for Shasta fork")
	}
	if blockIndex >= len(sourcePayload.BlockPayloads) {
		return nil, nil, fmt.Errorf("block index %d out of bounds (%d)", blockIndex, len(sourcePayload.BlockPayloads))
	}

	var (
		meta          = metadata.Shasta()
		blockID       = new(big.Int).Add(parent.Number, common.Big1)
		blockInfo     = sourcePayload.BlockPayloads[blockIndex]
		anchorBlockID = new(big.Int).SetUint64(blockInfo.AnchorBlockNumber)
	)
	difficulty, err := encoding.CalculateShastaDifficulty(parent.Difficulty, blockID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate difficulty: %w", err)
	}

	baseFee, err := rpc.CalculateBaseFeeShasta(ctx, parent)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to calculate base fee: %w", err)
	}

	log.Info("L2 baseFee", "blockID", blockID, "basefee", utils.WeiToGWei(baseFee))

	latestState, err := rpc.ShastaClients.Anchor.GetBlockState(&bind.CallOpts{Context: ctx, BlockHash: parent.Hash()})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to fetch latest anchor state: %w", err)
	}

	anchorBlockHeader, err := rpc.L1.HeaderByNumber(ctx, anchorBlockID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to fetch anchor block: %w", err)
	}
	var (
		anchorBlockHeaderHash = anchorBlockHeader.Hash()
		anchorBlockHeaderRoot = anchorBlockHeader.Root
	)

	log.Info(
		"L2 anchor block",
		"number", anchorBlockID,
		"latestStateAnchorBlockNumber", latestState.AnchorBlockNumber,
		"hash", anchorBlockHeaderHash,
		"root", anchorBlockHeaderRoot,
	)

	anchorTx, err := anchorConstructor.AssembleAnchorV4Tx(
		ctx,
		parent,
		anchorBlockID,
		anchorBlockHeaderHash,
		anchorBlockHeaderRoot,
		meta.GetEventData().EndOfSubmissionWindowTimestamp,
		blockID,
		baseFee,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create ShastaAnchor.anchorV4 transaction: %w", err)
	}

	// Encode extraData with basefeeSharingPctg and proposal ID.
	extraData, err := encodeShastaExtraData(meta.GetEventData().BasefeeSharingPctg, meta.GetEventData().Id)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to encode extraData: %w", err)
	}

	// Set batchID only for the last block in the proposal
	var batchID *big.Int
	if len(sourcePayload.BlockPayloads)-1 == blockIndex {
		batchID = meta.GetEventData().Id
	}

	return &createExecutionPayloadsMetaData{
		BlockID:               blockID,
		BatchID:               batchID,
		ExtraData:             extraData,
		SuggestedFeeRecipient: blockInfo.Coinbase,
		GasLimit:              blockInfo.GasLimit,
		Difficulty:            common.BytesToHash(difficulty),
		Timestamp:             blockInfo.Timestamp,
		ParentHash:            parent.Hash(),
		L1Origin: &rawdb.L1Origin{
			BlockID:       blockID,
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: meta.GetRawBlockHeight(),
			L1BlockHash:   meta.GetRawBlockHash(),
		},
		Txs:         blockInfo.Transactions,
		Withdrawals: make([]*types.Withdrawal, 0),
		BaseFee:     baseFee,
	}, anchorTx, nil
}

// updateL1OriginForBatchPacaya updates the L1 origin for the given batch of blocks.
func updateL1OriginForBatchPacaya(
	ctx context.Context,
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
) error {
	if !metadata.IsPacaya() {
		return fmt.Errorf("metadata is not for Pacaya fork")
	}

	meta := metadata.Pacaya()
	return updateL1OriginForBlocks(
		ctx,
		rpc,
		len(meta.GetBlocks()),
		func(i int) *big.Int {
			return new(big.Int).SetUint64(meta.GetLastBlockID() - uint64(len(meta.GetBlocks())-1-i))
		},
		func() *big.Int { return meta.GetBatchID() },
		meta.GetRawBlockHeight(),
		meta.GetRawBlockHash(),
	)
}

// updateL1OriginForBlocks updates L1 origin for a batch of blocks with given parameters.
func updateL1OriginForBlocks(
	ctx context.Context,
	rpc *rpc.Client,
	blockCount int,
	getBlockID func(i int) *big.Int,
	getBatchID func() *big.Int,
	l1BlockHeight *big.Int,
	l1BlockHash common.Hash,
) error {
	g := new(errgroup.Group)

	for i := 0; i < blockCount; i++ {
		g.Go(func() error {
			blockID := getBlockID(i)

			header, err := rpc.L2.HeaderByNumber(ctx, blockID)
			if err != nil {
				return fmt.Errorf("failed to get block by number %d: %w", blockID, err)
			}

			l1Origin := &rawdb.L1Origin{
				BlockID:       blockID,
				L2BlockHash:   header.Hash(),
				L1BlockHeight: l1BlockHeight,
				L1BlockHash:   l1BlockHash,
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
			if i == blockCount-1 {
				log.Info(
					"Update head L1 origin",
					"blockID", blockID,
					"batchID", getBatchID(),
					"L2BlockHash", l1Origin.L1BlockHash,
					"L1BlockHeight", l1Origin.L1BlockHeight,
					"L1BlockHash", l1Origin.L1BlockHash,
				)
				if _, err := rpc.L2Engine.SetHeadL1Origin(ctx, l1Origin.BlockID); err != nil {
					return fmt.Errorf("failed to write head L1 origin: %w", err)
				}
				if _, err := rpc.L2Engine.SetBatchToLastBlock(ctx, getBatchID(), blockID); err != nil {
					return fmt.Errorf("failed to write batch to block mapping: %w", err)
				}
			}

			return nil
		})
	}
	return g.Wait()
}

// updateL1OriginForBatchShasta updates the L1 origin for the given batch of blocks.
func updateL1OriginForBatchShasta(
	ctx context.Context,
	rpc *rpc.Client,
	parentHeader *types.Header,
	metadata metadata.TaikoProposalMetaData,
	sourcePayload *shastaManifest.ShastaDerivationSourcePayload,
) error {
	if !metadata.IsShasta() {
		return fmt.Errorf("metadata is not for Shasta fork blocks")
	}

	meta := metadata.Shasta()
	lastBlockID := parentHeader.Number.Uint64() + uint64(len(sourcePayload.BlockPayloads))

	return updateL1OriginForBlocks(
		ctx,
		rpc,
		len(sourcePayload.BlockPayloads),
		func(i int) *big.Int {
			return new(big.Int).SetUint64(lastBlockID - uint64(len(sourcePayload.BlockPayloads)-1-i))
		},
		func() *big.Int { return meta.GetEventData().Id },
		meta.GetRawBlockHeight(),
		meta.GetRawBlockHash(),
	)
}

// encodeShastaExtraData encodes basefeeSharingPctg and proposal ID into extraData.
func encodeShastaExtraData(
	basefeeSharingPctg uint8,
	proposalID *big.Int,
) ([]byte, error) {
	if proposalID == nil {
		return nil, errors.New("proposal ID is nil")
	}
	if proposalID.Sign() < 0 {
		return nil, fmt.Errorf("proposal ID is negative: %s", proposalID.String())
	}
	if proposalID.BitLen() > params.ExtraDataProposalIDLength*8 {
		return nil, fmt.Errorf("proposal ID too large for extraData: %s", proposalID.String())
	}

	extraData := make([]byte, params.ShastaExtraDataLen)

	// First byte: basefeeSharingPctg.
	extraData[params.ExtraDataBasefeeSharingPctgIndex] = basefeeSharingPctg

	// Bytes 1..6: proposal ID (uint48, big-endian).
	proposalBytes := proposalID.Bytes()
	offset := params.ExtraDataProposalIDIndex + params.ExtraDataProposalIDLength - len(proposalBytes)
	copy(extraData[offset:offset+len(proposalBytes)], proposalBytes)

	return extraData, nil
}

// InsertPreconfBlockFromEnvelope the inner method to insert a preconfirmation block from
// the given envelope.
func InsertPreconfBlockFromEnvelope(
	ctx context.Context,
	cli *rpc.Client,
	envelope *preconf.Envelope,
) (*types.Header, error) {
	var signature [65]byte
	if envelope.Signature != nil {
		signature = *envelope.Signature
	}

	log.Debug(
		"Inserting preconfirmation block from execution payload envelope",
		"blockID", uint64(envelope.Payload.BlockNumber),
		"blockHash", envelope.Payload.BlockHash,
		"parentHash", envelope.Payload.ParentHash,
		"timestamp", envelope.Payload.Timestamp,
		"feeRecipient", envelope.Payload.FeeRecipient,
		"signature", common.Bytes2Hex(signature[:]),
	)

	// Ensure the preconfirmation block number is greater than the current head L1 origin block ID.
	headL1Origin, err := cli.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return nil, fmt.Errorf("failed to fetch head L1 origin: %w", err)
	}

	// When the chain only has the genesis block, we shall skip this check.
	if headL1Origin != nil {
		if uint64(envelope.Payload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
			return nil, fmt.Errorf(
				"preconfirmation block ID (%d, %s) is less than or equal to the current head L1 origin block ID (%d)",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				headL1Origin.BlockID,
			)
		}

		ok, err := IsBasedOnCanonicalChain(ctx, cli, envelope, headL1Origin)
		if err != nil {
			return nil, fmt.Errorf(
				"failed to check if preconfirmation block (%d, %s) is in canonical chain: %w",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				err,
			)
		}
		if !ok {
			return nil, fmt.Errorf(
				"preconfirmation block (%d, %s) is not in the canonical chain, head L1 origin: (%d, %s)",
				envelope.Payload.BlockNumber,
				envelope.Payload.BlockHash,
				headL1Origin.BlockID,
				headL1Origin.L2BlockHash,
			)
		}
	}

	if len(envelope.Payload.Transactions) == 0 {
		return nil, fmt.Errorf("no transactions data in the payload")
	}

	// Decompress the transactions list.
	decompressedTxs, err := utils.Decompress(envelope.Payload.Transactions[0])
	if err != nil {
		return nil, fmt.Errorf("failed to decompress transactions list bytes: %w", err)
	}
	var (
		txListHash = crypto.Keccak256Hash(decompressedTxs)
		args       = &miner.BuildPayloadArgs{
			Parent:       envelope.Payload.ParentHash,
			Timestamp:    uint64(envelope.Payload.Timestamp),
			FeeRecipient: envelope.Payload.FeeRecipient,
			Random:       common.Hash(envelope.Payload.PrevRandao),
			Withdrawals:  make([]*types.Withdrawal, 0),
			Version:      engine.PayloadV2,
			TxListHash:   &txListHash,
		}
	)

	payloadID := args.Id()

	var u256BaseFee = uint256.Int(envelope.Payload.BaseFeePerGas)

	log.Debug(
		"Payload arguments",
		"blockID", uint64(envelope.Payload.BlockNumber),
		"parent", args.Parent.Hex(),
		"timestamp", args.Timestamp,
		"feeRecipient", args.FeeRecipient.Hex(),
		"random", args.Random.Hex(),
		"txListHash", args.TxListHash.Hex(),
		"id", payloadID.String(),
		"signature", common.Bytes2Hex(signature[:]),
	)

	payload, err := createExecutionPayloadsAndSetHead(
		ctx,
		cli,
		&createExecutionPayloadsMetaData{
			BlockID:               new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber)),
			ExtraData:             envelope.Payload.ExtraData,
			SuggestedFeeRecipient: envelope.Payload.FeeRecipient,
			GasLimit:              uint64(envelope.Payload.GasLimit),
			Difficulty:            common.Hash(envelope.Payload.PrevRandao),
			Timestamp:             uint64(envelope.Payload.Timestamp),
			ParentHash:            envelope.Payload.ParentHash,
			L1Origin: &rawdb.L1Origin{
				BlockID:            new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber)),
				L2BlockHash:        common.Hash{}, // Will be set by taiko-geth.
				L1BlockHeight:      nil,
				L1BlockHash:        common.Hash{},
				Signature:          signature,
				IsForcedInclusion:  envelope.IsForcedInclusion,
				BuildPayloadArgsID: payloadID,
			},
			BaseFee:     u256BaseFee.ToBig(),
			Withdrawals: make([]*types.Withdrawal, 0),
		},
		decompressedTxs,
		nil, // We don't need to progress safe / finalized block when inserting preconf blocks.
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution data: %w", err)
	}

	metrics.DriverL2PreconfHeadHeightGauge.Set(float64(envelope.Payload.BlockNumber))

	return cli.L2.HeaderByHash(ctx, payload.BlockHash)
}

// IsBasedOnCanonicalChain checks if the given executable data is based on the canonical chain.
func IsBasedOnCanonicalChain(
	ctx context.Context,
	cli *rpc.Client,
	envelope *preconf.Envelope,
	headL1Origin *rawdb.L1Origin,
) (bool, error) {
	canonicalParent, err := cli.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(envelope.Payload.BlockNumber-1)))
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return false, fmt.Errorf("failed to fetch canonical parent block: %w", err)
	}
	// If the parent hash of the executable data matches the canonical parent block hash, it is in the canonical chain.
	if canonicalParent != nil && canonicalParent.Hash() == envelope.Payload.ParentHash {
		return true, nil
	}

	return false, nil
}
