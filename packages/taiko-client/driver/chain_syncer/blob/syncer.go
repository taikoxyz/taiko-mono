package blob

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/url"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"

	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
)

// Syncer responsible for letting the L2 execution engine catching up with protocol's latest
// pending block through deriving L1 calldata.
type Syncer struct {
	ctx                context.Context
	rpc                *rpc.Client
	state              *state.State
	progressTracker    *beaconsync.SyncProgressTracker          // Sync progress tracker
	anchorConstructor  *anchorTxConstructor.AnchorTxConstructor // TaikoL2.anchor transactions constructor
	txListDecompressor *txListDecompressor.TxListDecompressor   // Transactions list decompressor
	// Used by BlockInserter
	lastInsertedBlockID *big.Int
	reorgDetectedFlag   bool
	maxRetrieveExponent uint64
	blobDatasource      *rpc.BlobDataSource
}

// NewSyncer creates a new syncer instance.
func NewSyncer(
	ctx context.Context,
	client *rpc.Client,
	state *state.State,
	progressTracker *beaconsync.SyncProgressTracker,
	maxRetrieveExponent uint64,
	blobServerEndpoint *url.URL,
	socialScanEndpoint *url.URL,
) (*Syncer, error) {
	constructor, err := anchorTxConstructor.New(client)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize anchor constructor: %w", err)
	}

	return &Syncer{
		ctx:               ctx,
		rpc:               client,
		state:             state,
		progressTracker:   progressTracker,
		anchorConstructor: constructor,
		txListDecompressor: txListDecompressor.NewTxListDecompressor(
			uint64(encoding.GetProtocolConfig(client.L2.ChainID.Uint64()).BlockMaxGasLimit),
			rpc.BlockMaxTxListBytes,
			client.L2.ChainID,
		),
		maxRetrieveExponent: maxRetrieveExponent,
		blobDatasource: rpc.NewBlobDataSource(
			ctx,
			client,
			blobServerEndpoint,
			socialScanEndpoint,
		),
	}, nil
}

// ProcessL1Blocks fetches all `TaikoL1.BlockProposed` events between given
// L1 block heights, and then tries inserting them into L2 execution engine's blockchain.
func (s *Syncer) ProcessL1Blocks(ctx context.Context) error {
	for {
		if err := s.processL1Blocks(ctx); err != nil {
			return err
		}

		// If the L1 chain has been reorged, we process the new L1 blocks again with
		// the new L1Current cursor.
		if s.reorgDetectedFlag {
			s.reorgDetectedFlag = false
			continue
		}

		return nil
	}
}

// processL1Blocks is the inner method which responsible for processing
// all new L1 blocks.
func (s *Syncer) processL1Blocks(ctx context.Context) error {
	l1End := s.state.GetL1Head()
	startL1Current := s.state.GetL1Current()
	// If there is a L1 reorg, sometimes this will happen.
	if startL1Current.Number.Uint64() >= l1End.Number.Uint64() && startL1Current.Hash() != l1End.Hash() {
		newL1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).Sub(l1End.Number, common.Big1))
		if err != nil {
			return err
		}

		log.Info(
			"Reorg detected",
			"oldL1CurrentHeight", startL1Current.Number,
			"oldL1CurrentHash", startL1Current.Hash(),
			"newL1CurrentHeight", newL1Current.Number,
			"newL1CurrentHash", newL1Current.Hash(),
			"l1Head", l1End.Number,
		)

		s.state.SetL1Current(newL1Current)
		s.lastInsertedBlockID = nil
	}

	iter, err := eventIterator.NewBlockProposedIterator(ctx, &eventIterator.BlockProposedIteratorConfig{
		Client:               s.rpc.L1,
		TaikoL1:              s.rpc.TaikoL1,
		StartHeight:          s.state.GetL1Current().Number,
		EndHeight:            l1End.Number,
		FilterQuery:          nil,
		OnBlockProposedEvent: s.onBlockProposed,
	})
	if err != nil {
		return err
	}

	if err := iter.Iter(); err != nil {
		return err
	}

	// If there is a L1 reorg, we don't update the L1Current cursor.
	if !s.reorgDetectedFlag {
		s.state.SetL1Current(l1End)
		metrics.DriverL1CurrentHeightGauge.Set(float64(s.state.GetL1Current().Number.Uint64()))
	}

	return nil
}

// OnBlockProposed is a `BlockProposed` event callback which responsible for
// inserting the proposed block one by one to the L2 execution engine.
func (s *Syncer) onBlockProposed(
	ctx context.Context,
	meta metadata.TaikoBlockMetaData,
	endIter eventIterator.EndBlockProposedEventIterFunc,
) error {
	// We simply ignore the genesis block's `BlockProposed` event.
	if meta.GetBlockID().Cmp(common.Big0) == 0 {
		return nil
	}

	// If we are not inserting a block whose parent block is the latest verified block in protocol,
	// and the node hasn't just finished the P2P sync, we check if the L1 chain has been reorged.
	if !s.progressTracker.Triggered() {
		reorgCheckResult, err := s.checkReorg(ctx, meta.GetBlockID())
		if err != nil {
			return err
		}

		if reorgCheckResult.IsReorged {
			log.Info(
				"Reset L1Current cursor due to L1 reorg",
				"l1CurrentHeightOld", s.state.GetL1Current().Number,
				"l1CurrentHashOld", s.state.GetL1Current().Hash(),
				"l1CurrentHeightNew", reorgCheckResult.L1CurrentToReset.Number,
				"l1CurrentHashNew", reorgCheckResult.L1CurrentToReset.Hash(),
				"lastInsertedBlockIDOld", s.lastInsertedBlockID,
				"lastInsertedBlockIDNew", reorgCheckResult.LastHandledBlockIDToReset,
			)
			s.state.SetL1Current(reorgCheckResult.L1CurrentToReset)
			s.lastInsertedBlockID = reorgCheckResult.LastHandledBlockIDToReset
			s.reorgDetectedFlag = true
			endIter()

			return nil
		}
	}
	// Ignore those already inserted blocks.
	if s.lastInsertedBlockID != nil && meta.GetBlockID().Cmp(s.lastInsertedBlockID) <= 0 {
		return nil
	}

	log.Info(
		"New BlockProposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"blockID", meta.GetBlockID(),
	)

	// If the event's timestamp is in the future, we wait until the timestamp is reached, should
	// only happen when testing.
	if meta.GetTimestamp() > uint64(time.Now().Unix()) {
		log.Warn("Future L2 block, waiting", "L2BlockTimestamp", meta.GetTimestamp(), "now", time.Now().Unix())
		time.Sleep(time.Until(time.Unix(int64(meta.GetTimestamp()), 0)))
	}

	// Fetch the L2 parent block, if the node is just finished a P2P sync, we simply use the tracker's
	// last synced verified block as the parent, otherwise, we fetch the parent block from L2 EE.
	var (
		parent *types.Header
		err    error
	)
	if s.progressTracker.Triggered() {
		// Already synced through beacon sync, just skip this event.
		if meta.GetBlockID().Cmp(s.progressTracker.LastSyncedBlockID()) <= 0 {
			return nil
		}

		parent, err = s.rpc.L2.HeaderByHash(ctx, s.progressTracker.LastSyncedBlockHash())
	} else {
		parent, err = s.rpc.L2ParentByBlockID(ctx, meta.GetBlockID())
	}
	if err != nil {
		return fmt.Errorf("failed to fetch L2 parent block: %w", err)
	}

	log.Debug(
		"Parent block",
		"height", parent.Number,
		"hash", parent.Hash(),
		"beaconSyncTriggered", s.progressTracker.Triggered(),
	)

	tx, err := s.rpc.L1.TransactionInBlock(ctx, meta.GetRawBlockHash(), meta.GetTxIndex())
	if err != nil {
		return fmt.Errorf("failed to fetch original TaikoL1.proposeBlock transaction: %w", err)
	}

	// Decode transactions list.
	var txListFetcher txlistFetcher.TxListFetcher
	if meta.GetBlobUsed() {
		txListFetcher = txlistFetcher.NewBlobTxListFetcher(s.rpc.L1Beacon, s.blobDatasource)
	} else {
		txListFetcher = txlistFetcher.NewCalldataFetch(s.rpc)
	}
	txListBytes, err := txListFetcher.Fetch(ctx, tx, meta)
	if err != nil {
		return fmt.Errorf("failed to fetch tx list: %w", err)
	}

	var decompressedTxListBytes []byte
	if s.rpc.L2.ChainID.Cmp(params.HeklaNetworkID) == 0 {
		decompressedTxListBytes = s.txListDecompressor.TryDecompressHekla(
			meta.GetBlockID(),
			txListBytes,
			meta.GetBlobUsed(),
		)
	} else {
		decompressedTxListBytes = s.txListDecompressor.TryDecompress(meta.GetBlockID(), txListBytes, meta.GetBlobUsed())
	}

	// Decompress the transactions list and try to insert a new head block to L2 EE.
	payloadData, err := s.insertNewHead(
		ctx,
		meta,
		parent,
		decompressedTxListBytes,
		&rawdb.L1Origin{
			BlockID:       meta.GetBlockID(),
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: meta.GetRawBlockHeight(),
			L1BlockHash:   meta.GetRawBlockHash(),
		},
	)
	if err != nil {
		return fmt.Errorf("failed to insert new head to L2 execution engine: %w", err)
	}

	log.Debug("Payload data", "hash", payloadData.BlockHash, "txs", len(payloadData.Transactions))

	log.Info(
		"🔗 New L2 block inserted",
		"blockID", meta.GetBlockID(),
		"height", payloadData.Number,
		"hash", payloadData.BlockHash,
		"transactions", len(payloadData.Transactions),
		"baseFee", utils.WeiToGWei(payloadData.BaseFeePerGas),
		"withdrawals", len(payloadData.Withdrawals),
	)

	metrics.DriverL1CurrentHeightGauge.Set(float64(meta.GetRawBlockHeight().Uint64()))
	s.lastInsertedBlockID = meta.GetBlockID()

	if s.progressTracker.Triggered() {
		s.progressTracker.ClearMeta()
	}

	return nil
}

// insertNewHead tries to insert a new head block to the L2 execution engine's local
// block chain through Engine APIs.
func (s *Syncer) insertNewHead(
	ctx context.Context,
	meta metadata.TaikoBlockMetaData,
	parent *types.Header,
	txListBytes []byte,
	l1Origin *rawdb.L1Origin,
) (*engine.ExecutableData, error) {
	log.Debug(
		"Try to insert a new L2 head block",
		"parentNumber", parent.Number,
		"parentHash", parent.Hash(),
		"l1Origin", l1Origin,
	)

	// Insert a TaikoL2.anchor / TaikoL2.anchorV2 transaction at transactions list head
	var (
		txList   []*types.Transaction
		anchorTx *types.Transaction
		baseFee  *big.Int
		err      error
	)
	if len(txListBytes) != 0 {
		if err := rlp.DecodeBytes(txListBytes, &txList); err != nil {
			log.Error("Invalid txList bytes", "blockID", meta.GetBlockID())
			return nil, err
		}
	}

	if baseFee, err = s.rpc.CalculateBaseFee(
		ctx,
		parent,
		new(big.Int).SetUint64(meta.GetAnchorBlockID()),
		meta.IsOntakeBlock(),
		meta.GetBaseFeeConfig(),
		meta.GetTimestamp(),
	); err != nil {
		return nil, err
	}

	if !meta.IsOntakeBlock() {
		// Assemble a TaikoL2.anchor transaction
		anchorTx, err = s.anchorConstructor.AssembleAnchorTx(
			ctx,
			new(big.Int).SetUint64(meta.GetAnchorBlockID()),
			meta.GetAnchorBlockHash(),
			new(big.Int).Add(parent.Number, common.Big1),
			baseFee,
			parent.GasUsed,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to create TaikoL2.anchor transaction: %w", err)
		}
	} else {
		// Assemble a TaikoL2.anchorV2 transaction
		anchorBlockHeader, err := s.rpc.L1.HeaderByHash(ctx, meta.GetAnchorBlockHash())
		if err != nil {
			return nil, fmt.Errorf("failed to fetch anchor block: %w", err)
		}
		anchorTx, err = s.anchorConstructor.AssembleAnchorV2Tx(
			ctx,
			new(big.Int).SetUint64(meta.GetAnchorBlockID()),
			anchorBlockHeader.Root,
			parent.GasUsed,
			meta.GetBaseFeeConfig(),
			new(big.Int).Add(parent.Number, common.Big1),
			baseFee,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to create TaikoL2.anchorV2 transaction: %w", err)
		}
	}

	log.Info(
		"L2 baseFee",
		"blockID", meta.GetBlockID(),
		"baseFee", utils.WeiToGWei(baseFee),
		"syncedL1Height", meta.GetRawBlockHeight(),
		"parentGasUsed", parent.GasUsed,
	)

	// Insert the anchor transaction at the head of the transactions list
	txList = append([]*types.Transaction{anchorTx}, txList...)
	if txListBytes, err = rlp.EncodeToBytes(txList); err != nil {
		log.Error("Encode txList error", "blockID", meta.GetBlockID(), "error", err)
		return nil, err
	}

	payload, err := s.createExecutionPayloads(
		ctx,
		meta,
		parent.Hash(),
		l1Origin,
		txListBytes,
		baseFee,
		make(types.Withdrawals, 0),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution payloads: %w", err)
	}

	var lastVerifiedBlockHash common.Hash
	if lastVerifiedBlockHash, err = s.rpc.GetLastVerifiedBlockHash(ctx); err != nil {
		log.Debug("Failed to fetch last verified block hash", "error", err)

		stateVars, err := s.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
		if err != nil {
			return nil, fmt.Errorf("failed to fetch protocol state variables: %w", err)
		}

		lastVerifiedBlockHeader, err := s.rpc.L2.HeaderByNumber(
			ctx,
			new(big.Int).SetUint64(stateVars.B.LastVerifiedBlockId),
		)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch last verified block: %w", err)
		}

		lastVerifiedBlockHash = lastVerifiedBlockHeader.Hash()
	}

	fc := &engine.ForkchoiceStateV1{
		HeadBlockHash:      payload.BlockHash,
		SafeBlockHash:      lastVerifiedBlockHash,
		FinalizedBlockHash: lastVerifiedBlockHash,
	}

	// Update the fork choice
	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(ctx, fc, nil)
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
func (s *Syncer) createExecutionPayloads(
	ctx context.Context,
	meta metadata.TaikoBlockMetaData,
	parentHash common.Hash,
	l1Origin *rawdb.L1Origin,
	txListBytes []byte,
	baseFee *big.Int,
	withdrawals types.Withdrawals,
) (payloadData *engine.ExecutableData, err error) {
	fc := &engine.ForkchoiceStateV1{HeadBlockHash: parentHash}
	attributes := &engine.PayloadAttributes{
		Timestamp:             meta.GetTimestamp(),
		Random:                meta.GetDifficulty(),
		SuggestedFeeRecipient: meta.GetCoinbase(),
		Withdrawals:           withdrawals,
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: meta.GetCoinbase(),
			GasLimit:    uint64(meta.GetGasLimit()) + consensus.AnchorGasLimit,
			Timestamp:   meta.GetTimestamp(),
			TxList:      txListBytes,
			MixHash:     meta.GetDifficulty(),
			ExtraData:   meta.GetExtraData(),
		},
		BaseFeePerGas: baseFee,
		L1Origin:      l1Origin,
	}

	log.Debug(
		"PayloadAttributes",
		"blockID", meta.GetBlockID(),
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

	log.Debug(
		"Payload",
		"blockID", meta.GetBlockID(),
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

	return payload, nil
}

// checkLastVerifiedBlockMismatch checks if there is a mismatch between protocol's last verified block hash and
// the corresponding L2 EE block hash.
func (s *Syncer) checkLastVerifiedBlockMismatch(ctx context.Context) (*rpc.ReorgCheckResult, error) {
	var (
		reorgCheckResult = new(rpc.ReorgCheckResult)
		err              error
	)

	stateVars, err := s.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, err
	}

	if s.state.GetL2Head().Number.Uint64() < stateVars.B.LastVerifiedBlockId {
		return reorgCheckResult, nil
	}

	genesisL1Header, err := s.rpc.GetGenesisL1Header(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch genesis L1 header: %w", err)
	}
	reorgCheckResult, err = s.retrievePastBlock(ctx, stateVars.B.LastVerifiedBlockId, 0, genesisL1Header)
	if err != nil {
		return nil, err
	}

	return reorgCheckResult, nil
}

// retrievePastBlock find proper L1 header and L2 block id to reset when there is a mismatch
func (s *Syncer) retrievePastBlock(
	ctx context.Context,
	blockID uint64,
	retries uint64,
	genesisL1Header *types.Header) (*rpc.ReorgCheckResult, error) {
	if retries > s.maxRetrieveExponent {
		return &rpc.ReorgCheckResult{
			IsReorged:                 true,
			L1CurrentToReset:          genesisL1Header,
			LastHandledBlockIDToReset: new(big.Int).SetUint64(blockID),
		}, nil
	}

	var (
		reorgCheckResult = new(rpc.ReorgCheckResult)
		err              error
		currentBlockID   uint64
		l1HeaderToSet    = genesisL1Header
	)

	if val := uint64(1 << retries); blockID > val {
		currentBlockID = blockID - val + 1
	} else {
		currentBlockID = 0
	}

	blockNum := new(big.Int).SetUint64(currentBlockID)
	var blockInfo bindings.TaikoDataBlockV2
	if s.state.IsOnTake(blockNum) {
		blockInfo, err = s.rpc.GetL2BlockInfoV2(ctx, blockNum)
	} else {
		blockInfo, err = s.rpc.GetL2BlockInfo(ctx, blockNum)
	}

	if err != nil {
		return nil, err
	}
	ts, err := s.rpc.GetTransition(
		ctx,
		new(big.Int).SetUint64(blockInfo.BlockId),
		uint32(blockInfo.VerifiedTransitionId.Uint64()),
	)
	if err != nil {
		return nil, err
	}

	l2Header, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(currentBlockID))
	if err != nil {
		return nil, err
	}
	if ts.BlockHash == l2Header.Hash() {
		// To reduce the number of call contracts by bringing forward the termination condition judgement
		if retries == 0 {
			return nil, nil
		}
		l1Origin, err := s.rpc.L2.L1OriginByID(ctx, new(big.Int).SetUint64(currentBlockID))
		if err != nil {
			if err.Error() == ethereum.NotFound.Error() {
				log.Info(
					"L1Origin not found in retrievePastBlock because the L2 EE is just synced through P2P",
					"blockID",
					currentBlockID,
				)
				// Can't find l1Origin in L2 EE, so we call the contract to get block info
				blockInfo, err := s.rpc.TaikoL1.GetBlock(&bind.CallOpts{Context: ctx}, currentBlockID)
				if err != nil {
					return nil, err
				}
				if blockInfo.ProposedIn != 0 {
					l1HeaderToSet, err = s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(blockInfo.ProposedIn))
					if err != nil {
						return nil, err
					}
				}
			} else {
				return nil, err
			}
		} else {
			l1HeaderToSet, err = s.rpc.L1.HeaderByNumber(ctx, l1Origin.L1BlockHeight)
			if err != nil {
				return nil, err
			}
		}
		reorgCheckResult.IsReorged = retries > 0
		reorgCheckResult.L1CurrentToReset = l1HeaderToSet
		reorgCheckResult.LastHandledBlockIDToReset = new(big.Int).SetUint64(currentBlockID)
	} else {
		reorgCheckResult, err = s.retrievePastBlock(ctx, blockID, retries+1, genesisL1Header)
		if err != nil {
			return nil, err
		}
	}
	return reorgCheckResult, nil
}

// checkReorg checks whether the L1 chain has been reorged, and resets the L1Current cursor if necessary.
func (s *Syncer) checkReorg(
	ctx context.Context,
	blockID *big.Int,
) (*rpc.ReorgCheckResult, error) {
	// If the L2 chain is at genesis, we don't need to check L1 reorg.
	if s.state.GetL1Current().Number == s.state.GenesisL1Height {
		return new(rpc.ReorgCheckResult), nil
	}

	// 1. The latest verified block
	reorgCheckResult, err := s.checkLastVerifiedBlockMismatch(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to check if last verified block in L2 EE has been reorged: %w", err)
	}

	if reorgCheckResult == nil {
		// 2. Parent block
		reorgCheckResult, err = s.rpc.CheckL1Reorg(
			ctx,
			new(big.Int).Sub(blockID, common.Big1),
		)
		if err != nil {
			return nil, fmt.Errorf("failed to check whether L1 chain has been reorged: %w", err)
		}
	}

	return reorgCheckResult, nil
}
