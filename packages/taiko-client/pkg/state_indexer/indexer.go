package shasta_indexer

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sort"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
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
	maxHistoricalProposalFetchConcurrency = 32
	shastaProposedEventTopic              common.Hash
	shastaProvedEventTopic                common.Hash
)

// Initialize event topics from ABI.
func init() {
	abi, err := shastaBindings.ShastaInboxClientMetaData.GetAbi()
	if err != nil {
		log.Crit("Failed to parse Shasta inbox ABI", "err", err)
	}
	proposedEvent, ok := abi.Events["Proposed"]
	if !ok {
		log.Crit("Proposed event not found in Shasta inbox ABI")
	}
	provedEvent, ok := abi.Events["Proved"]
	if !ok {
		log.Crit("Proved event not found in Shasta inbox ABI")
	}
	shastaProposedEventTopic = proposedEvent.ID
	shastaProvedEventTopic = provedEvent.ID
}

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
	ProposalId       *big.Int
	Transition       *shastaBindings.IInboxTransition
	TransitionRecord *shastaBindings.IInboxTransitionRecord
	RawBlockHash     common.Hash
	RawBlockHeight   *big.Int
}

// proposalRange represents the L1 block interval processed within a batch.
type proposalRange struct {
	startHeight *big.Int
	endHeight   *big.Int
}

// rangeLogs groups the proposed and proved logs fetched for a proposal range.
type rangeLogs struct {
	proposed []types.Log
	proved   []types.Log
}

// rangeRequestMeta keeps metadata for a specific batch request entry.
type rangeRequestMeta struct {
	typ      string
	rangeIdx int
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

	// Fetch historical proposals and transition records.
	if err := s.fetchHistorical(head, s.bufferSize); err != nil {
		return fmt.Errorf("failed to fetch historical Shasta events: %w", err)
	}
	log.Info(
		"Finished fetching historical Shasta events",
		"proposals", s.ProposalsCount(),
		"transitionRecords", s.transitionRecords.Count(),
	)

	go func() {
		if err := s.liveIndexing(); err != nil {
			log.Error("Live indexing Shasta events error", "error", err)
		}
	}()

	return nil
}

// fetchHistorical replays historical proposals and transitions from the Shasta contract.
func (s *Indexer) fetchHistorical(toBlock *types.Header, bufferSize uint64) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Reset caches before fetching historical events.
	s.proposals.Clear()
	s.transitionRecords.Clear()

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
				log.Info("Queued final Shasta proposal range (reached genesis)", "cached", s.proposals.Count())
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

		if err := s.batchFetchHistoricalRanges(s.ctx, batch); err != nil {
			return fmt.Errorf("failed to fetch historical Shasta events: %w", err)
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

// batchFetchHistoricalRanges fetches logs for the provided ranges via a single batch request and replays them locally.
func (s *Indexer) batchFetchHistoricalRanges(ctx context.Context, ranges []proposalRange) error {
	if len(ranges) == 0 {
		return nil
	}

	start := time.Now()
	var (
		results = make([]rangeLogs, len(ranges))
		reqs    = make([]gethrpc.BatchElem, 0)
		metas   = make([]rangeRequestMeta, 0)
	)
	// Prepare batch requests for proposed and proved events.
	for i, r := range ranges {
		reqs = append(reqs, gethrpc.BatchElem{
			Method: "eth_getLogs",
			Args:   []interface{}{s.buildShastaFilterArg(shastaProposedEventTopic, r.startHeight, r.endHeight)},
			Result: &results[i].proposed,
		})
		metas = append(metas, rangeRequestMeta{typ: "proposed", rangeIdx: i})

		reqs = append(reqs, gethrpc.BatchElem{
			Method: "eth_getLogs",
			Args:   []interface{}{s.buildShastaFilterArg(shastaProvedEventTopic, r.startHeight, r.endHeight)},
			Result: &results[i].proved,
		})
		metas = append(metas, rangeRequestMeta{typ: "proved", rangeIdx: i})
	}

	if err := s.rpc.L1.BatchCallContext(ctx, reqs); err != nil {
		return err
	}
	log.Info("Historical RPC batch completed", "ranges", len(ranges), "duration", time.Since(start))
	for idx, req := range reqs {
		if req.Error != nil {
			return fmt.Errorf(
				"failed to fetch Shasta %s logs between %s and %s: %w",
				metas[idx].typ,
				ranges[metas[idx].rangeIdx].startHeight.String(),
				ranges[metas[idx].rangeIdx].endHeight.String(),
				req.Error,
			)
		}
	}

	g, gCtx := errgroup.WithContext(ctx)
	for _, rangeLogs := range results {
		g.Go(func() error {
			if err := s.handleProposedLogs(gCtx, rangeLogs.proposed); err != nil {
				return err
			}
			return s.handleProvedLogs(gCtx, rangeLogs.proved)
		})
	}

	if err := g.Wait(); err != nil {
		return err
	}
	log.Info("Historical decode batch completed", "ranges", len(ranges), "duration", time.Since(start))
	return nil
}

// buildShastaFilterArg constructs an eth_getLogs argument for the given topic and block interval.

func (s *Indexer) buildShastaFilterArg(topic common.Hash, startHeight, endHeight *big.Int) map[string]interface{} {
	return map[string]interface{}{
		"address":   []common.Address{s.rpc.ShastaClients.InboxAddress},
		"topics":    [][]common.Hash{{topic}},
		"fromBlock": hexutil.EncodeBig(startHeight),
		"toBlock":   hexutil.EncodeBig(endHeight),
	}
}

// handleProposedLogs decodes Proposed event logs and feeds them through the standard callback.
func (s *Indexer) handleProposedLogs(
	ctx context.Context,
	logs []types.Log,
) error {
	for _, logEntry := range logs {
		if logEntry.Removed {
			continue
		}
		payloadData, err := extractEventPayload(logEntry.Data)
		if err != nil {
			return fmt.Errorf("failed to extract Shasta proposed event payload: %w", err)
		}
		payload, err := s.rpc.DecodeProposedEventPayload(&bind.CallOpts{Context: ctx}, payloadData)
		if err != nil {
			return fmt.Errorf("failed to decode Shasta proposed event: %w", err)
		}
		if payload == nil {
			return errors.New("decoded Shasta proposed event payload is nil")
		}
		if err := s.onProposedEvent(
			ctx,
			metadata.NewTaikoProposalMetadataShasta(payload, logEntry),
			func() {},
		); err != nil {
			return fmt.Errorf("failed to process Shasta proposed event: %w", err)
		}
	}
	return nil
}

// handleProvedLogs decodes Proved event logs and feeds them through the standard callback.
func (s *Indexer) handleProvedLogs(ctx context.Context, logs []types.Log) error {
	for _, logEntry := range logs {
		if logEntry.Removed {
			continue
		}
		payloadData, err := extractEventPayload(logEntry.Data)
		if err != nil {
			return fmt.Errorf("failed to extract Shasta proved event payload: %w", err)
		}
		payload, err := s.rpc.DecodeProvedEventPayload(&bind.CallOpts{Context: ctx}, payloadData)
		if err != nil {
			return fmt.Errorf("failed to decode Shasta proved event: %w", err)
		}
		if err := s.onProvedEvent(ctx, payload, &logEntry, func() {}); err != nil {
			return fmt.Errorf("failed to process Shasta proved event: %w", err)
		}
	}
	return nil
}

// extractEventPayload strips the ABI encoding of a single `bytes` field from an event log.
func extractEventPayload(data []byte) ([]byte, error) {
	if len(data) < 64 {
		return nil, fmt.Errorf("invalid event data length %d", len(data))
	}
	length := new(big.Int).SetBytes(data[32:64]).Uint64()
	end := 64 + length
	if uint64(len(data)) < end {
		return nil, fmt.Errorf("invalid event payload length %d for data size %d", length, len(data))
	}
	return data[64:end], nil
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

	log.Debug(
		"New indexed Shasta transition record",
		"proposalId", meta.ProposalId,
		"transitionHash", common.Hash(record.TransitionHash),
		"parentTransitionHash", common.Hash(transition.ParentTransitionHash),
		"checkpoint", transition.Checkpoint.BlockNumber,
		"checkpointBlockHash", common.Hash(transition.Checkpoint.BlockHash),
		"checkpointStateRoot", common.Hash(transition.Checkpoint.StateRoot),
		"bondInstructions", len(record.BondInstructions),
	)
	s.transitionRecords.Set(meta.ProposalId.Uint64(), &TransitionPayload{
		ProposalId:       meta.ProposalId,
		Transition:       &transition,
		TransitionRecord: &record,
		RawBlockHash:     eventLog.BlockHash,
		RawBlockHeight:   new(big.Int).SetUint64(eventLog.BlockNumber),
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
	var (
		lastProposalId  uint64
		lastFinalizedId uint64
	)
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
