package event

import (
	"context"
	"fmt"
	"math/big"
	"net/url"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	anchorTxConstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	blocksInserter "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/blocks_inserter"
	shastaManifest "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	txlistFetcher "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_fetcher"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	eventIterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Syncer responsible for letting the L2 execution engine catching up with protocol's latest
// pending block through deriving L1 calldata.
type Syncer struct {
	ctx                context.Context
	rpc                *rpc.Client
	state              *state.State
	progressTracker    *beaconsync.SyncProgressTracker        // Sync progress tracker
	txListDecompressor *txListDecompressor.TxListDecompressor // Transactions list decompressor

	// Blocks inserters
	blocksInserterPacaya blocksInserter.Inserter // Pacaya blocks inserter
	blocksInserterShasta blocksInserter.Inserter // Shasta blocks inserter

	lastInsertedBatchID *big.Int
	reorgDetectedFlag   bool

	// Shasta derivation source fetcher
	derivationSourceFetcher *shastaManifest.ShastaDerivationSourceFetcher
}

// NewSyncer creates a new syncer instance.
func NewSyncer(
	ctx context.Context,
	client *rpc.Client,
	state *state.State,
	progressTracker *beaconsync.SyncProgressTracker,
	blobServerEndpoint *url.URL,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) (*Syncer, error) {
	constructor, err := anchorTxConstructor.New(client)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize anchor constructor: %w", err)
	}

	var (
		blobDataSource     = rpc.NewBlobDataSource(ctx, client, blobServerEndpoint)
		txListDecompressor = txListDecompressor.NewTxListDecompressor(rpc.BlockMaxTxListBytes)
	)

	return &Syncer{
		ctx:                ctx,
		rpc:                client,
		state:              state,
		progressTracker:    progressTracker,
		txListDecompressor: txListDecompressor,
		blocksInserterPacaya: blocksInserter.NewBlocksInserterPacaya(
			client,
			progressTracker,
			blobDataSource,
			txListDecompressor,
			constructor,
			txlistFetcher.NewCalldataFetcher(client),
			txlistFetcher.NewBlobFetcher(client, blobDataSource),
			latestSeenProposalCh,
		),
		blocksInserterShasta: blocksInserter.NewBlocksInserterShasta(
			client,
			progressTracker,
			constructor,
			latestSeenProposalCh,
		),
		derivationSourceFetcher: shastaManifest.NewDerivationSourceFetcher(client, blobDataSource),
	}, nil
}

// ProcessL1Blocks fetches all `TaikoInbox.BatchProposed` events between given
// L1 block heights, and then tries inserting them into L2 execution engine's blockchain.
func (s *Syncer) ProcessL1Blocks(ctx context.Context) error {
	for {
		if err := s.processL1Blocks(ctx); err != nil {
			return fmt.Errorf("failed to process L1 blocks: %w", err)
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
	var (
		l1End          = s.state.GetL1Head()
		startL1Current = s.state.GetL1Current()
	)
	// If there is a L1 reorg, sometimes this will happen.
	if startL1Current.Number.Uint64() >= l1End.Number.Uint64() && startL1Current.Hash() != l1End.Hash() {
		newL1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).Sub(l1End.Number, common.Big1))
		if err != nil {
			return fmt.Errorf("failed to fetch L1 header during reorg detection: %w", err)
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
		s.lastInsertedBatchID = nil
	}

	iter, err := eventIterator.NewBatchProposedIterator(ctx, &eventIterator.BatchProposedIteratorConfig{
		RpcClient:            s.rpc,
		StartHeight:          s.state.GetL1Current().Number,
		EndHeight:            l1End.Number,
		OnBatchProposedEvent: s.onBatchProposed,
	})
	if err != nil {
		return fmt.Errorf("failed to create event iterator: %w", err)
	}

	if err := iter.Iter(); err != nil {
		return fmt.Errorf("failed to iterate through events: %w", err)
	}

	// If there is a L1 reorg, we don't update the L1Current cursor.
	if !s.reorgDetectedFlag {
		s.state.SetL1Current(l1End)
		metrics.DriverL1CurrentHeightGauge.Set(float64(s.state.GetL1Current().Number.Uint64()))
	}

	return nil
}

// onBatchProposed is a `BatchProposed` event callback which responsible for
// inserting the proposed block one by one to the L2 execution engine.
func (s *Syncer) onBatchProposed(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) error {
	if meta.IsPacaya() {
		return s.processPacayaBatch(ctx, meta, endIter)
	}
	return s.processShastaProposal(ctx, meta, endIter)
}

// processShastaProposal processes a Shasta proposal event, and tries inserting
// the proposed blocks to the L2 execution engine.
func (s *Syncer) processShastaProposal(
	ctx context.Context,
	metadata metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) error {
	var (
		meta   = metadata.Shasta()
		parent *types.Block
		err    error
	)

	// We simply ignore the genesis Shasta block's `Proposed` event.
	if meta.GetEventData().Id.Cmp(common.Big0) == 0 {
		// Reset the lastInsertedBatchID when processing the genesis Shasta proposal.
		s.lastInsertedBatchID = common.Big0
		log.Debug("Ignore genesis Shasta proposal event", "proposalID", meta.GetEventData().Id)
		return nil
	}

	// If we are not inserting a block whose parent block is the latest verified block in protocol,
	// and the node hasn't just finished the P2P sync, we check if the L1 chain has been reorged.
	if !s.progressTracker.Triggered() {
		reorgCheckResult, err := s.checkReorgShasta(ctx, meta.GetEventData().Id)
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
				"lastInsertedBlockIDOld", s.lastInsertedBatchID,
				"lastInsertedBlockIDNew", reorgCheckResult.LastHandledBatchIDToReset,
			)
			s.state.SetL1Current(reorgCheckResult.L1CurrentToReset)
			s.lastInsertedBatchID = reorgCheckResult.LastHandledBatchIDToReset
			s.reorgDetectedFlag = true
			endIter()

			return nil
		}
	}

	// Ignore those already inserted batches.
	if s.lastInsertedBatchID != nil && meta.GetEventData().Id.Cmp(s.lastInsertedBatchID) <= 0 {
		log.Debug(
			"Skip already inserted batch",
			"batchID", meta.GetEventData().Id,
			"lastInsertedBatchID", s.lastInsertedBatchID,
		)
		return nil
	}

	log.Info(
		"New Shasta Proposed event",
		"proposalID", meta.GetEventData().Id,
		"proposer", meta.GetEventData().Proposer,
		"derivationSources", len(meta.GetEventData().Sources),
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
	)

	// If the event's timestamp is in the future, we wait until the timestamp is reached, should
	// only happen when testing.
	if meta.GetTimestamp() > uint64(time.Now().Unix()) {
		log.Warn(
			"Future L2 block, waiting",
			"L2BlockTimestamp", meta.GetTimestamp(),
			"now", time.Now().Unix(),
		)
		time.Sleep(time.Until(time.Unix(int64(meta.GetTimestamp()), 0)))
	}

	if meta.GetEventData().Id.Cmp(common.Big1) == 0 {
		// For the first Shasta proposal, its parent block is the last Pacaya block.
		lastPacayaBlockID := common.Big0
		if s.rpc.ShastaClients.ForkTime > 0 {
			if lastPacayaBlockID, err = s.rpc.LastPacayaBlockID(ctx); err != nil {
				return fmt.Errorf("failed to fetch last Pacaya block ID: %w", err)
			}
		}
		log.Info(
			"First Shasta proposal, fetch last Pacaya block as parent",
			"proposalID", meta.GetEventData().Id,
			"proposer", meta.GetEventData().Proposer,
			"lastPacayaBlockID", lastPacayaBlockID,
		)
		if parent, err = s.rpc.L2.BlockByNumber(ctx, lastPacayaBlockID); err != nil {
			return fmt.Errorf("failed to fetch the last Pacaya block: %w", err)
		}
	} else {
		// Fetch the parent block, here we try to find the L1 origin of the previous proposal at first,
		// if not found, which means either the previous proposal is genesis or the L2 EE just finishes the
		// P2P sync, then we just use the latest block as parent block in this case.
		// If the error is taiko.ErrProposalLastBlockUncertain, return the error as well and rely on a retry.
		l1Origin, err := s.rpc.L2.LastL1OriginByBatchID(ctx, new(big.Int).Sub(meta.GetEventData().Id, common.Big1))
		if err != nil && err.Error() != ethereum.NotFound.Error() {
			return fmt.Errorf("failed to fetch last L1 origin by batch ID: %w", err)
		}
		if l1Origin != nil {
			if parent, err = s.rpc.L2.BlockByNumber(ctx, l1Origin.BlockID); err != nil {
				return err
			}
		} else {
			if parent, err = s.rpc.L2.BlockByNumber(ctx, nil); err != nil {
				return err
			}
			log.Info(
				"No L1 origin found for the previous proposal, using the latest block as parent",
				"proposalID", meta.GetEventData().Id,
				"proposer", meta.GetEventData().Proposer,
				"parentBlockID", parent.Number(),
			)
		}
	}

	// Prefetch all derivation source payloads.
	var (
		sourcePayloads = make([]*shastaManifest.ShastaDerivationSourcePayload, len(meta.GetEventData().Sources))
	)
	if len(meta.GetEventData().Sources) > 0 {
		// Fetch all derivation source payloads.
		for i := 0; i < len(meta.GetEventData().Sources); i++ {
			p, err := s.derivationSourceFetcher.Fetch(ctx, meta, i)
			if err != nil {
				return fmt.Errorf("failed to fetch Shasta derivation payload for index %d: %w", i, err)
			}
			sourcePayloads[i] = p
		}
	}

	for derivationIdx := range meta.GetEventData().Sources {
		log.Info(
			"Processing Shasta derivation source",
			"proposalID", meta.GetEventData().Id,
			"proposer", meta.GetEventData().Proposer,
			"index", derivationIdx,
			"l1Height", meta.GetRawBlockHeight(),
			"l1Hash", meta.GetRawBlockHash(),
		)
		// Reuse the prefetched derivation payload.
		sourcePayload := sourcePayloads[derivationIdx]
		if sourcePayload == nil {
			return fmt.Errorf("missing Shasta derivation payload for index %d", derivationIdx)
		}
		sourcePayload.ParentBlock = parent
		isForcedInclusion := meta.GetEventData().Sources[derivationIdx].IsForcedInclusion

		log.Info(
			"Parent block info for Shasta derivation payload",
			"proposalID", meta.GetEventData().Id,
			"blocks", len(sourcePayload.BlockPayloads),
			"parentBlockID", sourcePayload.ParentBlock.Number(),
			"parentHash", sourcePayload.ParentBlock.Hash(),
			"parentGasLimit", sourcePayload.ParentBlock.GasLimit(),
			"parentTimestamp", sourcePayload.ParentBlock.Time(),
		)

		latestBlockState, err := s.rpc.GetShastaAnchorState(
			&bind.CallOpts{BlockHash: sourcePayload.ParentBlock.Hash(), Context: ctx},
		)
		if err != nil {
			return err
		}
		lastAnchorBlockNumber := latestBlockState.AnchorBlockNumber.Uint64()
		if meta.GetEventData().Id.Cmp(common.Big1) == 0 && sourcePayload.ParentBlock.Number().Cmp(common.Big0) != 0 {
			if _, lastAnchorBlockNumber, _, err = s.rpc.GetSyncedL1SnippetFromAnchor(
				sourcePayload.ParentBlock.Transactions()[0],
			); err != nil {
				return err
			}
		}

		// If the derivation source is forced inclusion, we apply inherited metadata first.
		if isForcedInclusion {
			shastaManifest.ApplyInheritedMetadata(
				sourcePayload,
				meta.GetEventData(),
				meta.GetTimestamp(),
				lastAnchorBlockNumber,
				s.rpc.ShastaClients.ForkTime,
			)
		}

		// If the derivation source payload's metadata is invalid, we replace it with default metadata.
		if !shastaManifest.ValidateMetadata(
			s.rpc,
			sourcePayload,
			meta.GetEventData(),
			meta.GetTimestamp(),
			meta.GetRawBlockHeight().Uint64()-1,
			lastAnchorBlockNumber,
			isForcedInclusion,
		) {
			sourcePayload.Default = true
			sourcePayload.BlockPayloads = []*shastaManifest.ShastaBlockPayload{
				{BlockManifest: manifest.BlockManifest{Transactions: types.Transactions{}}},
			}
			shastaManifest.ApplyInheritedMetadata(
				sourcePayload,
				meta.GetEventData(),
				meta.GetTimestamp(),
				lastAnchorBlockNumber,
				s.rpc.ShastaClients.ForkTime,
			)
			log.Info(
				"Use default Shasta derivation payload",
				"proposalID", meta.GetEventData().Id,
				"proposer", meta.GetEventData().Proposer,
				"anchorBlockNumber", lastAnchorBlockNumber,
			)
		}

		// Insert new blocks to L2 EE's chain.
		lastInsertedBlockID, err := s.blocksInserterShasta.InsertBlocksWithManifest(
			ctx,
			metadata,
			sourcePayload,
			endIter,
		)
		if err != nil {
			return fmt.Errorf("failed to insert Shasta blocks: %w", err)
		}
		if parent, err = s.rpc.WaitL2Block(ctx, lastInsertedBlockID); err != nil {
			log.Warn("Failed to fetch the new parent block", "error", err)
			return err
		}
	}
	metrics.DriverL1CurrentHeightGauge.Set(float64(meta.GetRawBlockHeight().Uint64()))
	s.lastInsertedBatchID = meta.GetEventData().Id

	if s.progressTracker.Triggered() {
		s.progressTracker.ClearMeta()
	}
	return nil
}

// processPacayaBatch processes a Pacaya batch event, and tries inserting
// the proposed blocks to the L2 execution engine.
func (s *Syncer) processPacayaBatch(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	endIter eventIterator.EndBatchProposedEventIterFunc,
) error {
	var (
		timestamp = meta.Pacaya().GetLastBlockTimestamp()
	)

	// We simply ignore the genesis block's `BatchesProposed` event.
	if meta.Pacaya().GetBatchID().Cmp(common.Big0) == 0 {
		return nil
	}

	// If we are not inserting a block whose parent block is the latest verified block in protocol,
	// and the node hasn't just finished the P2P sync, we check if the L1 chain has been reorged.
	if !s.progressTracker.Triggered() {
		reorgCheckResult, err := s.checkReorgPacaya(ctx, meta.Pacaya().GetBatchID())
		if err != nil {
			return fmt.Errorf("failed to check for reorg: %w", err)
		}

		if reorgCheckResult.IsReorged {
			log.Info(
				"Reset L1Current cursor due to L1 reorg",
				"l1CurrentHeightOld", s.state.GetL1Current().Number,
				"l1CurrentHashOld", s.state.GetL1Current().Hash(),
				"l1CurrentHeightNew", reorgCheckResult.L1CurrentToReset.Number,
				"l1CurrentHashNew", reorgCheckResult.L1CurrentToReset.Hash(),
				"lastInsertedBlockIDOld", s.lastInsertedBatchID,
				"lastInsertedBlockIDNew", reorgCheckResult.LastHandledBatchIDToReset,
			)
			s.state.SetL1Current(reorgCheckResult.L1CurrentToReset)
			s.lastInsertedBatchID = reorgCheckResult.LastHandledBatchIDToReset
			s.reorgDetectedFlag = true
			endIter()

			return nil
		}
	}

	// Ignore those already inserted batches.
	if s.lastInsertedBatchID != nil && meta.Pacaya().GetBatchID().Cmp(s.lastInsertedBatchID) <= 0 {
		log.Debug(
			"Skip already inserted batch",
			"batchID", meta.Pacaya().GetBatchID(),
			"lastInsertedBatchID", s.lastInsertedBatchID,
		)
		return nil
	}

	// If the event's timestamp is in the future, we wait until the timestamp is reached, should
	// only happen when testing.
	if timestamp > uint64(time.Now().Unix()) {
		log.Warn(
			"Future L2 block, waiting",
			"L2BlockTimestamp", timestamp,
			"now", time.Now().Unix(),
		)
		time.Sleep(time.Until(time.Unix(int64(timestamp), 0)))
	}

	// Insert new blocks to L2 EE's chain.
	log.Info(
		"New BatchProposed event",
		"l1Height", meta.GetRawBlockHeight(),
		"l1Hash", meta.GetRawBlockHash(),
		"batchID", meta.Pacaya().GetBatchID(),
		"lastBlockID", meta.Pacaya().GetLastBlockID(),
		"lastTimestamp", meta.Pacaya().GetLastBlockTimestamp(),
		"blocks", len(meta.Pacaya().GetBlocks()),
	)
	pacayaInserter := s.BlocksInserterPacaya()
	// Fetch txList bytes before taking the inserter lock to avoid blocking preconf inserts on slow blob downloads.
	txListBytes, err := pacayaInserter.FetchTxListBytes(ctx, meta.Pacaya())
	if err != nil {
		return fmt.Errorf("failed to fetch tx list bytes: %w", err)
	}
	if err := pacayaInserter.InsertBlocksWithTxListBytes(ctx, meta, txListBytes); err != nil {
		return fmt.Errorf("failed to insert Pacaya blocks: %w", err)
	}

	metrics.DriverL1CurrentHeightGauge.Set(float64(meta.GetRawBlockHeight().Uint64()))
	s.lastInsertedBatchID = meta.Pacaya().GetBatchID()

	if s.progressTracker.Triggered() {
		s.progressTracker.ClearMeta()
	}

	return nil
}

// checkLastVerifiedBlockMismatchPacaya checks if there is a mismatch between protocol's last verified block hash and
// the corresponding L2 EE block hash.
func (s *Syncer) checkLastVerifiedBlockMismatchPacaya(ctx context.Context) (*rpc.ReorgCheckResult, error) {
	// Fetch the latest verified block hash.
	ts, err := s.rpc.GetLastVerifiedTransitionPacaya(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get last verified transition: %w", err)
	}

	var (
		reorgCheckResult    = new(rpc.ReorgCheckResult)
		lastVerifiedBatchID = ts.BatchId
	)

	// If the current L2 chain is behind of the last verified block, we skip the check.
	if s.state.GetL2Head().Number.Uint64() < ts.BlockId ||
		(s.lastInsertedBatchID != nil && s.lastInsertedBatchID.Uint64() < ts.BlockId) {
		return reorgCheckResult, nil
	}

	header, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(ts.BlockId))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch L2 header by number: %w", err)
	}

	// If the last verified block hash matches the L2 EE block hash, we skip the check.
	if header.Hash() == ts.Ts.BlockHash {
		return reorgCheckResult, nil
	}

	for {
		batch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastVerifiedBatchID))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch batch by ID: %w", err)
		}
		previousBatch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastVerifiedBatchID-1))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch previous batch by ID: %w", err)
		}

		if batch.VerifiedTransitionId.Cmp(common.Big0) == 0 {
			lastVerifiedBatchID = previousBatch.BatchId
			continue
		}
		ts, err := s.rpc.PacayaClients.TaikoInbox.GetBatchVerifyingTransition(&bind.CallOpts{Context: ctx}, batch.BatchId)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch Pacaya transition: %w", err)
		}
		if header, err = s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(batch.LastBlockId)); err != nil {
			return nil, fmt.Errorf("failed to fetch L2 header by number: %w", err)
		}

		if header.Hash() == ts.BlockHash {
			log.Info(
				"Verified block matched, start reorging",
				"currentHeightToCheck", batch.LastBlockId,
				"chainBlockHash", header.Hash(),
				"transitionBlockHash", common.Hash(ts.BlockHash),
			)
			reorgCheckResult.IsReorged = true
			if reorgCheckResult.L1CurrentToReset, err = s.rpc.L1.HeaderByNumber(
				ctx,
				new(big.Int).SetUint64(batch.AnchorBlockId),
			); err != nil {
				return nil, fmt.Errorf("failed to fetch L1 header by number: %w", err)
			}
			reorgCheckResult.LastHandledBatchIDToReset = header.Number
			return reorgCheckResult, nil
		}

		log.Info(
			"Verified block mismatch",
			"currentHeightToCheck", batch.LastBlockId,
			"chainBlockHash", header.Hash(),
			"transitionBlockHash", common.Hash(ts.BlockHash),
		)

		lastVerifiedBatchID = previousBatch.BatchId
	}
}

// checkLastVerifiedBlockMismatchShasta checks if there is a mismatch between protocol's last verified block hash and
// the corresponding L2 EE block hash.
func (s *Syncer) checkLastVerifiedBlockMismatchShasta(ctx context.Context) (*rpc.ReorgCheckResult, error) {
	var (
		reorgCheckResult = new(rpc.ReorgCheckResult)
	)

	coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Shasta core state: %w", err)
	}

	// If there is no finalized proposal yet, we skip the check.
	if coreState.LastFinalizedProposalId.Cmp(common.Big0) == 0 {
		return reorgCheckResult, nil
	}

	lastBlockInBatch, err := s.rpc.L2.LastL1OriginByBatchID(ctx, coreState.LastFinalizedProposalId)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return nil, fmt.Errorf("failed to fetch last block in batch: %w", err)
	}
	// If the current L2 chain is behind of the last verified block, or the hash matches, return directly.
	if lastBlockInBatch == nil || lastBlockInBatch.L2BlockHash == coreState.LastFinalizedBlockHash {
		return reorgCheckResult, nil
	}

	log.Info(
		"Verified block mismatch",
		"currentHeightToCheck", lastBlockInBatch.BlockID,
		"chainBlockHash", lastBlockInBatch.L2BlockHash,
		"transitionBlockHash", common.Hash(coreState.LastFinalizedBlockHash),
	)

	// For Shasta, we simply reset to genesis if there is a mismatch.
	reorgCheckResult.IsReorged = true
	if reorgCheckResult.L1CurrentToReset, err = s.rpc.L1.HeaderByNumber(ctx, common.Big0); err != nil {
		return nil, fmt.Errorf("failed to fetch L1 header by number: %w", err)
	}
	reorgCheckResult.LastHandledBatchIDToReset = common.Big0
	return reorgCheckResult, nil
}

// checkReorgPacaya checks whether the L1 chain has been reorged, and resets the L1Current cursor if necessary.
func (s *Syncer) checkReorgPacaya(ctx context.Context, batchID *big.Int) (*rpc.ReorgCheckResult, error) {
	// If the L2 chain is at genesis, we don't need to check L1 reorg.
	if s.state.GetL1Current().Number == s.state.GenesisL1Height {
		return new(rpc.ReorgCheckResult), nil
	}

	// 1. Check if the verified blocks in L2 EE have been reorged.
	reorgCheckResult, err := s.checkLastVerifiedBlockMismatchPacaya(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to check if the verified blocks in L2 EE have been reorged: %w", err)
	}

	// 2. If the verified blocks check is passed, we check the unverified blocks.
	if reorgCheckResult == nil || !reorgCheckResult.IsReorged {
		if reorgCheckResult, err = s.rpc.CheckL1Reorg(ctx, new(big.Int).Sub(batchID, common.Big1), false); err != nil {
			return nil, fmt.Errorf("failed to check whether L1 chain has been reorged: %w", err)
		}
	}

	return reorgCheckResult, nil
}

// checkReorgShasta checks whether the L1 chain has been reorged, and resets the L1Current cursor if necessary.
func (s *Syncer) checkReorgShasta(
	ctx context.Context,
	batchID *big.Int,
) (*rpc.ReorgCheckResult, error) {
	// 1. Check if the verified blocks in L2 EE have been reorged.
	reorgCheckResult, err := s.checkLastVerifiedBlockMismatchShasta(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to check if the verified blocks in L2 EE have been reorged: %w", err)
	}

	// 2. If the verified blocks check is passed, we check the unverified blocks.
	if reorgCheckResult == nil || !reorgCheckResult.IsReorged {
		if reorgCheckResult, err = s.rpc.CheckL1Reorg(ctx, new(big.Int).Sub(batchID, common.Big1), true); err != nil {
			return nil, fmt.Errorf("failed to check whether L1 chain has been reorged: %w", err)
		}
	}

	return reorgCheckResult, nil
}

// BlocksInserterPacaya returns the Pacaya blocks inserter.
func (s *Syncer) BlocksInserterPacaya() *blocksInserter.Pacaya {
	return s.blocksInserterPacaya.(*blocksInserter.Pacaya)
}

// BlocksInserterShasta returns the Shasta blocks inserter.
func (s *Syncer) BlocksInserterShasta() *blocksInserter.Shasta {
	return s.blocksInserterShasta.(*blocksInserter.Shasta)
}
