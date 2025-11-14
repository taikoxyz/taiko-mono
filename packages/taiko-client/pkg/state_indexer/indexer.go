package shasta_indexer

import (
	"context"
	"fmt"
	"math/big"
	"sort"
	"sync"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	cmap "github.com/orcaman/concurrent-map/v2"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	eventiterator "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/chain_iterator/event_iterator"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	// maxBlocksPerFilter defines the maximum number of blocks to filter in a single RPC query.
	maxBlocksPerFilter uint64 = 1000
	// reorgSafetyDepth defines how many blocks back to rewind when a reorg is detected.
	reorgSafetyDepth = new(big.Int).SetUint64(64)
	// bufferSizeMultiplier determines how many times the buffer size to keep for historical data.
	bufferSizeMultiplier uint64 = 2
	// maxHistoricalProposalFetchConcurrency caps how many proposal ranges we fetch in parallel.
	maxHistoricalProposalFetchConcurrency = 64
)

// ProposalPayload represents the payload in a Shasta Proposed event.
type ProposalPayload struct {
	Proposal         *shastaBindings.IInboxProposal
	CoreState        *shastaBindings.IInboxCoreState
	Derivation       *shastaBindings.IInboxDerivation
	BondInstructions []shastaBindings.LibBondsBondInstruction
	RawBlockHash     common.Hash
	RawBlockHeight   *big.Int
	Log              *types.Log
}

// TransitionPayload represents the payload in a Shasta Proved event.
type TransitionPayload struct {
	ProposalId        *big.Int
	Transition        *shastaBindings.IInboxTransition
	TransitionRecord  *shastaBindings.IInboxTransitionRecord
	RawBlockHash      common.Hash
	RawBlockHeight    *big.Int
	RawBlockTimeStamp uint64
}

// Indexer saves the state of the Shasta protocol.
type Indexer struct {
	ctx                     context.Context
	rpc                     *rpc.Client
	proposals               cmap.ConcurrentMap[uint64, *ProposalPayload]
	transitionRecords       cmap.ConcurrentMap[uint64, *TransitionPayload]
	shastaForkTime          uint64
	bufferSize              uint64
	finalizationGracePeriod uint64

	mutex                    sync.RWMutex
	lastIndexedBlock         *types.Header
	historicalFetchCompleted bool
}

// New creates a new Shasta state indexer instance.
func New(
	ctx context.Context,
	rpc *rpc.Client,
	shastaForkTime uint64,
) (*Indexer, error) {
	config, err := rpc.ShastaClients.Inbox.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get Shasta inbox config: %w", err)
	}
	return &Indexer{
		ctx:                     ctx,
		rpc:                     rpc,
		bufferSize:              config.RingBufferSize.Uint64(),
		finalizationGracePeriod: config.FinalizationGracePeriod.Uint64(),
		shastaForkTime:          shastaForkTime,
		proposals: cmap.NewWithCustomShardingFunction[
			uint64, *ProposalPayload,
		](func(key uint64) uint32 { return uint32(key) }),
		transitionRecords: cmap.NewWithCustomShardingFunction[
			uint64, *TransitionPayload,
		](func(key uint64) uint32 { return uint32(key) }),
	}, nil
}

// Start starts the Shasta state indexing.
func (s *Indexer) Start() error {
	head, err := s.rpc.L1.HeaderByNumber(s.ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get the latest L1 block header: %w", err)
	}

	log.Info("Starting Shasta state indexing", "head", head.Number, "hash", head.Hash())

	// Fetch historical proposals.
	if err := s.fetchHistoricalProposals(head, s.bufferSize); err != nil {
		return fmt.Errorf("failed to fetch historical Shasta proposals: %w", err)
	}

	log.Info("Finished fetching historical Shasta proposals", "cached", s.ProposalsCount())
	// Fetch historical transition records from the last finalized proposal.
	if s.ProposalsCount() != 0 {
		log.Info("Last indexed Shasta proposal", "proposal", s.GetLastProposal().Proposal.Id)
		id := s.GetLastProposal().CoreState.LastFinalizedProposalId.Uint64()
		lastFinalizedProposal, err := s.GetProposalByID(id)
		if err != nil {
			return fmt.Errorf("last finalized proposal not found: %s",
				s.GetLastProposal().CoreState.LastFinalizedProposalId.String())
		}

		log.Info(
			"Last finalized Shasta proposal",
			"proposalId", lastFinalizedProposal.Proposal.Id,
			"proposedAt", lastFinalizedProposal.RawBlockHeight,
		)

		from, err := s.rpc.L1.HeaderByNumber(s.ctx, lastFinalizedProposal.RawBlockHeight)
		if err != nil {
			return fmt.Errorf("failed to get header at height %s: %w", lastFinalizedProposal.RawBlockHeight.String(), err)
		}
		if err := s.fetchHistoricalTransitionRecords(from, head); err != nil {
			return fmt.Errorf("failed to fetch historical Shasta transition records: %w", err)
		}
	}

	go func() {
		if err := s.liveIndexing(); err != nil {
			log.Error("Live indexing Shasta proposals error", "error", err)
		}
	}()

	return nil
}

// fetchHistoricalProposals fetches historical proposals from the Shasta contract.
func (s *Indexer) fetchHistoricalProposals(toBlock *types.Header, bufferSize uint64) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Reset proposals map before fetching historical proposals.
	s.proposals.Clear()

	var (
		currentHeader  = toBlock
		maxFilterRange = new(big.Int).SetUint64(maxBlocksPerFilter)
		stopRequested  = false
	)

	for currentHeader.Number.Cmp(common.Big0) > 0 {
		// Bail out quickly if the context is cancelled (e.g. shutdown).
		if err := s.ctx.Err(); err != nil {
			return err
		}

		// Assemble up to maxHistoricalProposalFetchConcurrency ranges for the next batch.
		var (
			batch []proposalRange
			err   error
		)
		for len(batch) < maxHistoricalProposalFetchConcurrency && currentHeader.Number.Cmp(common.Big0) > 0 {
			if s.shouldStopHistoricalProposalFetch(bufferSize) {
				stopRequested = true
				break
			}

			// Walk backwards in windows of maxBlocksPerFilter blocks.
			startHeight := new(big.Int)
			if currentHeader.Number.Cmp(maxFilterRange) <= 0 {
				startHeight.SetUint64(0)
			} else {
				startHeight.Sub(currentHeader.Number, maxFilterRange)
			}
			endHeight := new(big.Int).Set(currentHeader.Number)

			log.Info("Fetching Shasta Proposed events", "from", startHeight, "to", endHeight)

			batch = append(batch, proposalRange{startHeight: startHeight, endHeight: endHeight})

			if startHeight.Cmp(common.Big0) == 0 {
				log.Info("Reached the genesis block, stop fetching historical proposals", "cached", s.proposals.Count())
				stopRequested = true
				break
			}

			if currentHeader, err = s.rpc.L1.HeaderByNumber(s.ctx, startHeight); err != nil {
				return fmt.Errorf("failed to get header at height %s: %w", startHeight.String(), err)
			}
		}

		if len(batch) == 0 {
			log.Info("No more Shasta proposal ranges to fetch")
			break
		}

		// Kick off the batch concurrently and wait before scheduling the next one.
		batchGroup, batchCtx := errgroup.WithContext(s.ctx)
		for _, r := range batch {
			log.Info("Scheduling Shasta Proposed events fetch", "from", r.startHeight, "to", r.endHeight)
			batchGroup.Go(func() error { return s.iterateHistoricalProposalsRange(batchCtx, r.startHeight, r.endHeight) })
		}
		if err := batchGroup.Wait(); err != nil {
			return fmt.Errorf("failed to fetch historical Shasta proposals: %w", err)
		}

		// Stop queuing new work once any termination condition has been triggered.
		if stopRequested {
			break
		}
	}

	s.lastIndexedBlock = toBlock
	s.historicalFetchCompleted = true
	return nil
}

// iterateHistoricalProposalsRange streams proposed events between the provided heights.
func (s *Indexer) iterateHistoricalProposalsRange(ctx context.Context, startHeight, endHeight *big.Int) error {
	iter, err := eventiterator.NewBatchProposedIterator(ctx, &eventiterator.BatchProposedIteratorConfig{
		RpcClient:             s.rpc,
		MaxBlocksReadPerEpoch: &maxBlocksPerFilter,
		StartHeight:           startHeight,
		EndHeight:             endHeight,
		OnBatchProposedEvent:  s.onProposedEvent,
	})
	if err != nil {
		return fmt.Errorf("failed to create Shasta Proposed event iterator: %w", err)
	}
	if err := iter.Iter(); err != nil {
		return fmt.Errorf("failed to iterate Shasta Proposed events: %w", err)
	}
	return nil
}

// shouldStopHistoricalProposalFetch returns true when backfilling has met a terminal condition.
func (s *Indexer) shouldStopHistoricalProposalFetch(bufferSize uint64) bool {
	if bufferSize > 0 && uint64(s.proposals.Count()) >= bufferSize {
		log.Info("Cached enough Shasta proposals, stop fetching historical proposals", "cached", s.proposals.Count())
		return true
	}
	if proposal, ok := s.proposals.Get(0); ok && proposal != nil && proposal.Proposal != nil {
		if proposal.Proposal.Id.Cmp(common.Big0) == 0 {
			log.Info("Reached genesis Shasta proposal, stop fetching historical proposals", "forkTime", s.shastaForkTime)
			return true
		}
	}
	return false
}

// proposalRange represents the L1 block interval processed within a batch.
type proposalRange struct {
	startHeight *big.Int
	endHeight   *big.Int
}

// fetchHistoricalTransitionRecords fetches historical transition records from the Shasta contract.
func (s *Indexer) fetchHistoricalTransitionRecords(fromBlock, toBlock *types.Header) error {
	log.Info("Fetching historical Shasta transition records", "from", fromBlock.Number, "to", toBlock.Number)

	// Reset transition records map before fetching historical transition records.
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.transitionRecords.Clear()
	currentHeader := fromBlock

	for currentHeader.Number.Cmp(toBlock.Number) < 0 {
		if s.ctx.Err() != nil {
			return s.ctx.Err()
		}
		var endHeight *big.Int
		if new(big.Int).Sub(toBlock.Number, currentHeader.Number).Cmp(new(big.Int).SetUint64(maxBlocksPerFilter)) <= 0 {
			endHeight = toBlock.Number
		} else {
			endHeight = new(big.Int).Add(currentHeader.Number, new(big.Int).SetUint64(maxBlocksPerFilter))
		}

		log.Debug("Fetching Shasta Proved events", "from", currentHeader.Number, "to", endHeight)

		iter, err := eventiterator.NewShastaProvedIterator(s.ctx, &eventiterator.ShastaProvedIteratorConfig{
			RpcClient:             s.rpc,
			MaxBlocksReadPerEpoch: &maxBlocksPerFilter,
			StartHeight:           currentHeader.Number,
			EndHeight:             endHeight,
			OnShastaProvedEvent:   s.onProvedEvent,
		})
		if err != nil {
			return fmt.Errorf("failed to create Shasta Proved event iterator: %w", err)
		}
		if err := iter.Iter(); err != nil {
			return fmt.Errorf("failed to iterate Shasta Proved events: %w", err)
		}

		// Break if we've reached the toBlock
		if endHeight.Cmp(toBlock.Number) == 0 {
			break
		}

		// Update currentHeader for next iteration
		currentHeader, err = s.rpc.L1.HeaderByNumber(s.ctx, endHeight)
		if err != nil {
			return fmt.Errorf("failed to get header at height %s: %w", endHeight.String(), err)
		}
	}

	return nil
}

// onProvedEvent handles the Proved event.
// NOT THREAD-SAFE
func (s *Indexer) onProvedEvent(
	ctx context.Context,
	meta *shastaBindings.IInboxProvedEventPayload,
	eventLog *types.Log,
	endFunc eventiterator.EndShastaProvedEventIterFunc,
) error {
	var (
		transition = meta.Transition
		record     = meta.TransitionRecord
	)
	header, err := s.rpc.L1.HeaderByHash(ctx, eventLog.BlockHash)
	if err != nil {
		return fmt.Errorf("failed to get block header by hash %s: %w", eventLog.BlockHash.String(), err)
	}

	log.Debug(
		"New indexed Shasta transition record",
		"proposalId", meta.ProposalId,
		"transitionHash", common.Hash(record.TransitionHash),
		"parentTransitionHash", common.Hash(transition.ParentTransitionHash),
		"checkpoint", transition.Checkpoint.BlockNumber,
		"checkpointBlockHash", common.Hash(transition.Checkpoint.BlockHash),
		"checkpointStateRoot", common.Hash(transition.Checkpoint.StateRoot),
		"bondInstructions", len(record.BondInstructions),
		"timeStamp", header.Time,
	)
	s.transitionRecords.Set(meta.ProposalId.Uint64(), &TransitionPayload{
		ProposalId:        meta.ProposalId,
		Transition:        &transition,
		TransitionRecord:  &record,
		RawBlockHash:      eventLog.BlockHash,
		RawBlockHeight:    new(big.Int).SetUint64(eventLog.BlockNumber),
		RawBlockTimeStamp: header.Time,
	})
	return nil
}

// liveIndexing starts live indexing proposals and transitions from the Shasta contract.
func (s *Indexer) liveIndexing() error {
	var (
		indexNotify = make(chan struct{}, 1)
		l1HeadCh    = make(chan *types.Header, 1)
		sub         = rpc.SubscribeChainHead(s.rpc.L1, l1HeadCh)
	)
	defer sub.Unsubscribe()

	l1Head, err := s.rpc.L1.HeaderByNumber(s.ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get the latest L1 block header: %w", err)
	}

	reqIndexing := func() {
		select {
		case indexNotify <- struct{}{}:
		default:
		}
	}

	reqIndexing()

	for {
		select {
		case <-s.ctx.Done():
			return s.ctx.Err()
		case head := <-l1HeadCh:
			log.Debug("New L1 head received for live indexing Shasta proposals", "blockID", head.Number, "hash", head.Hash())
			l1Head = head
			reqIndexing()
		case <-indexNotify:
			if err := backoff.Retry(
				func() error {
					if err := s.liveIndex(l1Head); err != nil {
						return err
					}
					return nil
				},
				backoff.WithContext(backoff.NewExponentialBackOff(), s.ctx),
			); err != nil {
				log.Error("Live indexing Shasta proposals error", "error", err)
			}
		}
	}
}

// onProposedEvent handles the Proposed event.
// NOT THREAD-SAFE
func (s *Indexer) onProposedEvent(
	ctx context.Context,
	meta metadata.TaikoProposalMetaData,
	endFunc eventiterator.EndBatchProposedEventIterFunc,
) error {
	if !meta.IsShasta() {
		return nil
	}
	var (
		proposal         = meta.Shasta().GetProposal()
		coreState        = meta.Shasta().GetCoreState()
		derivation       = meta.Shasta().GetDerivation()
		bondInstructions = meta.Shasta().GetBondInstructions()
	)

	payload := &ProposalPayload{
		Proposal:         &proposal,
		CoreState:        &coreState,
		Derivation:       &derivation,
		BondInstructions: bondInstructions,
		RawBlockHash:     meta.GetRawBlockHash(),
		RawBlockHeight:   meta.GetRawBlockHeight(),
		Log:              meta.Shasta().GetLog(),
	}
	s.proposals.Set(proposal.Id.Uint64(), payload)

	log.Debug(
		"New indexed Shasta proposal",
		"proposalId", proposal.Id,
		"timeStamp", proposal.Timestamp,
		"proposer", proposal.Proposer,
		"bondInstructions", len(bondInstructions),
		"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
		"lastFinalizedTransitionHash", common.Bytes2Hex(coreState.LastFinalizedTransitionHash[:]),
		"proposedAt", meta.GetRawBlockHeight(),
	)
	return nil
}

// cleanupAfterEvents performs maintenance cleanup on proposals and transition records.
// NOT THREAD-SAFE
func (s *Indexer) cleanupAfterEvents() {
	// Determine the latest proposal ID and the last finalized proposal ID
	var lastProposalId uint64
	var lastFinalizedId uint64
	s.proposals.IterCb(func(_ uint64, p *ProposalPayload) {
		if p == nil || p.Proposal == nil || p.CoreState == nil {
			return
		}
		id := p.Proposal.Id.Uint64()
		if id > lastProposalId {
			lastProposalId = id
			lastFinalizedId = p.CoreState.LastFinalizedProposalId.Uint64()
		}
	})

	if lastFinalizedId != 0 {
		s.cleanupFinalizedTransitionRecords(lastFinalizedId)
	}
	if lastProposalId != 0 {
		s.cleanupLegacyProposals(lastProposalId)
	}
}

// liveIndex live indexes proposals from the last indexed block to the new head.
func (s *Indexer) liveIndex(newHead *types.Header) error {
	// Snapshot current cursor under lock, then release for RPC work
	s.mutex.Lock()
	defer s.mutex.Unlock()
	lastIndexed := s.lastIndexedBlock

	// Check for reorg by comparing block hash at the same height
	// Get the block at the same height as lastIndexedBlock from the chain
	currentBlockAtHeight, err := s.rpc.L1.HeaderByNumber(s.ctx, lastIndexed.Number)
	if err != nil {
		return fmt.Errorf("failed to get block at height %s: %w", lastIndexed.Number.String(), err)
	}

	// If hashes don't match, a reorg occurred
	if currentBlockAtHeight.Hash() != lastIndexed.Hash() {
		log.Debug(
			"Chain reorganization detected",
			"height", lastIndexed.Number,
			"oldHash", lastIndexed.Hash(),
			"newHash", currentBlockAtHeight.Hash(),
		)

		// Find the most recent proposal that is still valid on the current L1 chain
		var (
			lastValidProposal = s.findLastValidProposal()
			safeHeight        = new(big.Int).Sub(lastIndexed.Number, reorgSafetyDepth)
		)

		if safeHeight.Cmp(common.Big0) < 0 {
			safeHeight = common.Big0
		}

		if lastValidProposal != nil {
			// Use the height of the last valid proposal as our reorg recovery point
			safeHeight = lastValidProposal.RawBlockHeight
			log.Debug(
				"Using last valid proposal for reorg recovery",
				"proposalId", lastValidProposal.Proposal.Id,
				"safeHeight", safeHeight,
				"proposalHash", lastValidProposal.RawBlockHash,
			)
		} else {
			log.Debug(
				"No valid proposal found for reorg recovery, using default safety depth",
				"safeHeight", safeHeight,
			)
		}

		// Get the block at the safe height from the current chain
		commonAncestor, err := s.rpc.L1.HeaderByNumber(s.ctx, safeHeight)
		if err != nil {
			return fmt.Errorf("failed to get block at safe height %s: %w", safeHeight.String(), err)
		}

		log.Debug(
			"Reverting to safe height after reorg",
			"safeHeight", commonAncestor.Number,
			"hash", commonAncestor.Hash(),
			"reorgDepth", new(big.Int).Sub(lastIndexed.Number, safeHeight),
		)

		s.cleanupAfterReorg(safeHeight)
		s.lastIndexedBlock = commonAncestor
	}

	startHeight := s.lastIndexedBlock.Number

	log.Debug("Live indexing Shasta events", "from", startHeight, "to", newHead.Number)

	// Run proposed and proved indexing in parallel.
	g, _ := errgroup.WithContext(s.ctx)

	// Proposed events iterator
	g.Go(func() error {
		iter, err := eventiterator.NewBatchProposedIterator(s.ctx, &eventiterator.BatchProposedIteratorConfig{
			RpcClient:             s.rpc,
			MaxBlocksReadPerEpoch: &maxBlocksPerFilter,
			StartHeight:           startHeight,
			EndHeight:             newHead.Number,
			OnBatchProposedEvent:  s.onProposedEvent,
		})
		if err != nil {
			return fmt.Errorf("failed to create Shasta Proposed event iterator: %w", err)
		}
		if err := iter.Iter(); err != nil {
			return fmt.Errorf("failed to iterate Shasta Proposed events: %w", err)
		}
		return nil
	})

	// Proved events iterator
	g.Go(func() error {
		iterProved, err := eventiterator.NewShastaProvedIterator(s.ctx, &eventiterator.ShastaProvedIteratorConfig{
			RpcClient:             s.rpc,
			MaxBlocksReadPerEpoch: &maxBlocksPerFilter,
			StartHeight:           startHeight,
			EndHeight:             newHead.Number,
			OnShastaProvedEvent:   s.onProvedEvent,
		})
		if err != nil {
			return fmt.Errorf("failed to create Shasta Proved event iterator: %w", err)
		}
		if err := iterProved.Iter(); err != nil {
			return fmt.Errorf("failed to iterate Shasta Proved events: %w", err)
		}
		return nil
	})

	if err := g.Wait(); err != nil {
		return err
	}

	s.lastIndexedBlock = newHead
	s.cleanupAfterEvents()

	return nil
}

// cleanupFinalizedTransitionRecords cleans up transition records that are older than the last finalized proposal ID
// minus the buffer size.
// NOT THREAD-SAFE
func (s *Indexer) cleanupFinalizedTransitionRecords(lastFinalizedProposalId uint64) {
	// We keep bufferSizeMultiplier times the buffer size of transition records to avoid future reorg handling.
	threshold := s.bufferSize * bufferSizeMultiplier
	for _, key := range s.transitionRecords.Keys() {
		if key+threshold < lastFinalizedProposalId {
			log.Trace("Cleaning up finalized Shasta transition record", "proposalId", key)
			s.transitionRecords.Remove(key)
		}
	}
}

// cleanupLegacyProposals cleans up proposals that are older than the last proposal ID minus the buffer size.
// NOT THREAD-SAFE
func (s *Indexer) cleanupLegacyProposals(lastProposalId uint64) {
	// We keep bufferSizeMultiplier times the buffer size of proposals to avoid future reorg handling.
	threshold := s.bufferSize * bufferSizeMultiplier
	for _, key := range s.proposals.Keys() {
		if key+threshold < lastProposalId {
			log.Trace("Cleaning up legacy Shasta proposal", "proposalId", key)
			s.proposals.Remove(key)
		}
	}
}

// BufferSize returns the buffer size.
func (s *Indexer) BufferSize() uint64 {
	return s.bufferSize
}

// GetLastIndexedBlock returns the last indexed block header in a thread-safe manner.
func (s *Indexer) GetLastIndexedBlock() *types.Header {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.lastIndexedBlock
}

// GetLastProposal returns the latest proposal based on the highest proposal ID.
func (s *Indexer) GetLastProposal() *ProposalPayload {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	var latest *ProposalPayload
	for _, key := range s.proposals.Keys() {
		proposal, ok := s.proposals.Get(key)
		if !ok || proposal == nil || proposal.Proposal == nil {
			continue
		}

		if latest == nil || proposal.Proposal.Id.Cmp(latest.Proposal.Id) > 0 {
			latest = proposal
		}
	}
	return latest
}

// GetLastCoreState returns the core state of the latest proposal.
func (s *Indexer) GetLastCoreState() *shastaBindings.IInboxCoreState {
	lastProposal := s.GetLastProposal()
	if lastProposal == nil {
		return nil
	}
	return lastProposal.CoreState
}

// findLastValidProposal finds the most recent proposal still valid on current L1 chain.
// NOT THREAD-SAFE
func (s *Indexer) findLastValidProposal() *ProposalPayload {
	var proposals []*ProposalPayload

	// Collect all proposals
	s.proposals.IterCb(func(_ uint64, proposal *ProposalPayload) {
		if proposal != nil && proposal.Proposal != nil {
			proposals = append(proposals, proposal)
		}
	})

	// Sort by ID descending (highest first)
	sort.Slice(proposals, func(i, j int) bool {
		return proposals[i].Proposal.Id.Cmp(proposals[j].Proposal.Id) > 0
	})

	// Find first valid proposal (highest ID that's still on L1)
	for _, proposal := range proposals {
		header, err := s.rpc.L1.HeaderByNumber(s.ctx, proposal.RawBlockHeight)
		if err == nil && header.Hash() == proposal.RawBlockHash {
			log.Debug(
				"Found valid proposal for reorg recovery",
				"proposalId", proposal.Proposal.Id,
				"height", proposal.RawBlockHeight,
			)
			return proposal
		}
	}

	return nil
}

// cleanupAfterReorg removes invalid proposals and transition records after a reorg.
// It removes all data based on L1 blocks higher than safeHeight.
// NOT THREAD-SAFE
func (s *Indexer) cleanupAfterReorg(safeHeight *big.Int) {
	var removedProposals, removedTransitions int

	// Clean up invalid proposals
	var proposalKeysToRemove []uint64
	s.proposals.IterCb(func(key uint64, proposal *ProposalPayload) {
		if proposal != nil && proposal.RawBlockHeight.Cmp(safeHeight) > 0 {
			proposalKeysToRemove = append(proposalKeysToRemove, key)
		}
	})
	for _, key := range proposalKeysToRemove {
		s.proposals.Remove(key)
		removedProposals++
	}

	// Clean up invalid transition records
	var transitionKeysToRemove []uint64
	s.transitionRecords.IterCb(func(key uint64, transition *TransitionPayload) {
		if transition != nil && transition.RawBlockHeight.Cmp(safeHeight) > 0 {
			transitionKeysToRemove = append(transitionKeysToRemove, key)
		}
	})
	for _, key := range transitionKeysToRemove {
		s.transitionRecords.Remove(key)
		removedTransitions++
	}

	log.Debug(
		"Cleaned up invalid data after reorg",
		"safeHeight", safeHeight,
		"removedProposals", removedProposals,
		"removedTransitions", removedTransitions,
	)
}

// GetTransitionRecordByProposalID retrieves a transition record by its proposal ID.
func (s *Indexer) GetTransitionRecordByProposalID(proposalID uint64) *TransitionPayload {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	transition, ok := s.transitionRecords.Get(proposalID)
	if !ok {
		return nil
	}
	return transition
}

// GetProposalByID retrieves a proposal by its ID.
func (s *Indexer) GetProposalByID(proposalID uint64) (*ProposalPayload, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	proposal, ok := s.proposals.Get(proposalID)
	if !ok || proposal == nil || proposal.Proposal == nil {
		return nil, fmt.Errorf("proposal ID %d not found in cache", proposalID)
	}
	if proposalID != proposal.Proposal.Id.Uint64() {
		return nil, fmt.Errorf("proposal ID %d not found in cache", proposalID)
	}
	return proposal, nil
}

// GetProposalsInput returns the last proposal and the transitions needed for finalization.
func (s *Indexer) GetProposalsInput(
	maxFinalizationCount uint64,
) ([]*ProposalPayload, []*TransitionPayload, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	lastProposals := []*ProposalPayload{s.GetLastProposal()}
	if lastProposals[0] == nil {
		return nil, nil, fmt.Errorf("no on-chain Shasta proposal events cached")
	}
	if lastProposals[0].Proposal.Id.Uint64()+1 >= s.bufferSize {
		nextKey := lastProposals[0].Proposal.Id.Uint64() - (s.bufferSize - 1)
		nextSlotProposal, ok := s.proposals.Get(nextKey)
		if !ok {
			return nil, nil, fmt.Errorf(
				"missing cached proposal, ID: %d", lastProposals[0].Proposal.Id.Uint64()+1,
			)
		}
		lastProposals = append(lastProposals, nextSlotProposal)
	}

	return lastProposals,
		s.getTransitionsForFinalization(
			lastProposals[0].CoreState.LastFinalizedProposalId.Uint64(),
			lastProposals[0].CoreState.LastFinalizedTransitionHash,
			maxFinalizationCount,
		),
		nil
}

// getTransitionsForFinalization retrieves the transitions needed for finalization.
// NOT THREAD-SAFE
func (s *Indexer) getTransitionsForFinalization(
	lastFinalizedProposalId uint64,
	lastFinalizedTransitionHash common.Hash,
	maxFinalizationCount uint64,
) []*TransitionPayload {
	var transitions []*TransitionPayload
	for i := uint64(1); i <= maxFinalizationCount; i++ {
		transition, ok := s.transitionRecords.Get(lastFinalizedProposalId + i)
		if ok {
			log.Info(
				"Checking transition for finalization",
				"proposalId", lastFinalizedProposalId+i,
				"lastFinalizedTransitionHash", common.Bytes2Hex(lastFinalizedTransitionHash[:]),
				"parentTransitionHash", common.Bytes2Hex(transition.Transition.ParentTransitionHash[:]),
			)
		}

		if !ok || transition.Transition.ParentTransitionHash != lastFinalizedTransitionHash {
			break
		}
		transitions = append(transitions, transition)
		lastFinalizedTransitionHash = transition.TransitionRecord.TransitionHash
	}

	return transitions
}

// IsHistoricalFetchCompleted returns whether the historical data has been fetched.
func (s *Indexer) IsHistoricalFetchCompleted() bool {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.historicalFetchCompleted
}

// ProposalsCount returns number of cached proposals.
func (s *Indexer) ProposalsCount() int {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.proposals.Count()
}
