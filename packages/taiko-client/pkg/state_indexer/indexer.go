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
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	// maxBlocksPerFilter defines the maximum number of blocks to filter in a single RPC query.
	maxBlocksPerFilter uint64 = 1000
	// reorgSafetyDepth defines how many blocks back to rewind when a reorg is detected.
	reorgSafetyDepth = new(big.Int).SetUint64(64)
	// bufferSizeMultiplier determines how many times the buffer size to keep for historical data.
	bufferSizeMultiplier uint64 = 2
	// parallelFetchWorkers limits concurrent historical filtering goroutines.
	parallelFetchWorkers int = 64
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
	proposals               map[uint64]*ProposalPayload
	transitionRecords       map[uint64]*TransitionPayload
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
		proposals:               make(map[uint64]*ProposalPayload),
		transitionRecords:       make(map[uint64]*TransitionPayload),
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
	// Build chunk waves backward and fetch in parallel with a concurrency cap.
	type rng struct{ start, end *big.Int }

	var (
		localProposals = make(map[uint64]*ProposalPayload)
		currentHeader  = toBlock
		reachedGenesis bool
		reachedFork    bool
	)

	for currentHeader.Number.Cmp(common.Big0) > 0 && !reachedFork {
		// Build up to parallelFetchWorkers ranges for this wave.
		var ranges []rng
		for len(ranges) < parallelFetchWorkers && currentHeader.Number.Cmp(common.Big0) > 0 {
			var startHeight *big.Int
			if currentHeader.Number.Cmp(new(big.Int).SetUint64(maxBlocksPerFilter)) <= 0 {
				startHeight = common.Big0
			} else {
				startHeight = new(big.Int).Sub(currentHeader.Number, new(big.Int).SetUint64(maxBlocksPerFilter))
			}
			ranges = append(ranges, rng{start: startHeight, end: new(big.Int).Set(currentHeader.Number)})

			if startHeight.Cmp(common.Big0) == 0 {
				reachedGenesis = true
			}

			// Move cursor for next range and check fork boundary
			hdr, err := s.rpc.L1.HeaderByNumber(s.ctx, startHeight)
			if err != nil {
				return fmt.Errorf("failed to get header at height %s: %w", startHeight.String(), err)
			}
			currentHeader = hdr
			if s.shastaForkTime > 0 && hdr.Time < s.shastaForkTime {
				reachedFork = true
				break
			}
			if reachedGenesis {
				break
			}
		}

		// Fetch ranges in parallel with semaphore limiting to parallelFetchWorkers.
		var mu sync.Mutex
		g, _ := errgroup.WithContext(s.ctx)
		sem := make(chan struct{}, parallelFetchWorkers)

		for _, r := range ranges {
			startHeight := new(big.Int).Set(r.start)
			endHeight := new(big.Int).Set(r.end)
			g.Go(func() error {
				sem <- struct{}{}
				defer func() { <-sem }()

				log.Info("Fetching Shasta Proposed events", "from", startHeight, "to", endHeight)
				end := endHeight.Uint64()
				iter, err := s.rpc.ShastaClients.Inbox.FilterProposed(
					&bind.FilterOpts{Start: startHeight.Uint64(), End: &end, Context: s.ctx})
				if err != nil {
					return fmt.Errorf("failed to filter Shasta Proposed events: %w", err)
				}
				defer iter.Close()
				for iter.Next() {
					event := iter.Event
					decoded, err := s.rpc.DecodeProposedEventPayload(&bind.CallOpts{Context: s.ctx}, event.Data)
					if err != nil {
						return fmt.Errorf("failed to decode proposed event data: %w", err)
					}
					if decoded == nil {
						return fmt.Errorf("decoded proposed event payload is nil")
					}

					proposal := decoded.Proposal
					coreState := decoded.CoreState
					derivation := decoded.Derivation
					bondInstructions := decoded.BondInstructions

					payload := &ProposalPayload{
						Proposal:         &proposal,
						CoreState:        &coreState,
						Derivation:       &derivation,
						BondInstructions: bondInstructions,
						RawBlockHash:     event.Raw.BlockHash,
						RawBlockHeight:   new(big.Int).SetUint64(event.Raw.BlockNumber),
						Log:              &event.Raw,
					}

					mu.Lock()
					localProposals[payload.Proposal.Id.Uint64()] = payload
					mu.Unlock()
				}
				if err := iter.Error(); err != nil {
					return fmt.Errorf("error iterating Shasta Proposed events: %w", err)
				}
				return nil
			})
		}

		if err := g.Wait(); err != nil {
			return err
		}

		// If we’ve cached enough proposals, we can stop early.
		if uint64(len(localProposals)) >= bufferSize {
			break
		}

		if reachedGenesis {
			break
		}
	}

	s.mutex.Lock()
	s.proposals = localProposals
	s.lastIndexedBlock = toBlock
	s.historicalFetchCompleted = true
	s.mutex.Unlock()
	return nil
}

// fetchHistoricalTransitionRecords fetches historical transition records from the Shasta contract.
func (s *Indexer) fetchHistoricalTransitionRecords(fromBlock, toBlock *types.Header) error {
	log.Info("Fetching historical Shasta transition records", "from", fromBlock.Number, "to", toBlock.Number)

	// Build chunk ranges first (no global lock while querying)
	var ranges [][2]*big.Int
	current := new(big.Int).Set(fromBlock.Number)
	for current.Cmp(toBlock.Number) < 0 {
		var endHeight *big.Int
		if new(big.Int).Sub(toBlock.Number, current).Cmp(new(big.Int).SetUint64(maxBlocksPerFilter)) <= 0 {
			endHeight = new(big.Int).Set(toBlock.Number)
		} else {
			endHeight = new(big.Int).Add(current, new(big.Int).SetUint64(maxBlocksPerFilter))
		}
		ranges = append(ranges, [2]*big.Int{new(big.Int).Set(current), endHeight})
		if endHeight.Cmp(toBlock.Number) == 0 {
			break
		}
		current = endHeight
	}

	// Collect results concurrently
	records := make(map[uint64]*TransitionPayload)
	var mu sync.Mutex

	g, _ := errgroup.WithContext(s.ctx)
	sem := make(chan struct{}, 64)
	for _, r := range ranges {
		startHeight := new(big.Int).Set(r[0])
		endHeight := new(big.Int).Set(r[1])
		g.Go(func() error {
			sem <- struct{}{}
			defer func() { <-sem }()
			if s.ctx.Err() != nil {
				return s.ctx.Err()
			}
			end := endHeight.Uint64()
			iter, err := s.rpc.ShastaClients.Inbox.FilterProved(
				&bind.FilterOpts{Start: startHeight.Uint64(), End: &end, Context: s.ctx})
			if err != nil {
				return fmt.Errorf("failed to filter Shasta Proved events: %w", err)
			}
			defer iter.Close()
			for iter.Next() {
				event := iter.Event
				provedEventPayload, err := s.rpc.DecodeProvedEventPayload(&bind.CallOpts{Context: s.ctx}, event.Data)
				if err != nil {
					return fmt.Errorf("failed to decode Shasta Proved event data: %w", err)
				}
				if provedEventPayload == nil {
					return fmt.Errorf("decoded proved event payload is nil")
				}

				// Build payload (inline of onProvedEvent to avoid shared-state writes here)
				header, err := s.rpc.L1.HeaderByHash(s.ctx, event.Raw.BlockHash)
				if err != nil {
					return fmt.Errorf("failed to get block header by hash %s: %w", event.Raw.BlockHash.String(), err)
				}

				transition := provedEventPayload.Transition
				record := provedEventPayload.TransitionRecord
				payload := &TransitionPayload{
					ProposalId:        provedEventPayload.ProposalId,
					Transition:        &transition,
					TransitionRecord:  &record,
					RawBlockHash:      event.Raw.BlockHash,
					RawBlockHeight:    new(big.Int).SetUint64(event.Raw.BlockNumber),
					RawBlockTimeStamp: header.Time,
				}

				mu.Lock()
				records[payload.ProposalId.Uint64()] = payload
				mu.Unlock()
			}
			if err := iter.Error(); err != nil {
				return fmt.Errorf("error iterating Shasta Proved events: %w", err)
			}
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return err
	}

	// Publish collected results under lock
	s.mutex.Lock()
	defer s.mutex.Unlock()
	s.transitionRecords = records
	return nil
}

// onProvedEvent handles the Proved event.
// NOT THREAD-SAFE
func (s *Indexer) onProvedEvent(
	ctx context.Context,
	meta *shastaBindings.IInboxProvedEventPayload,
	eventLog *types.Log,
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
	s.transitionRecords[meta.ProposalId.Uint64()] = &TransitionPayload{
		ProposalId:        meta.ProposalId,
		Transition:        &transition,
		TransitionRecord:  &record,
		RawBlockHash:      eventLog.BlockHash,
		RawBlockHeight:    new(big.Int).SetUint64(eventLog.BlockNumber),
		RawBlockTimeStamp: header.Time,
	}
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
	s.proposals[proposal.Id.Uint64()] = payload

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
	for _, p := range s.proposals {
		if p == nil || p.Proposal == nil || p.CoreState == nil {
			continue
		}
		id := p.Proposal.Id.Uint64()
		if id > lastProposalId {
			lastProposalId = id
			lastFinalizedId = p.CoreState.LastFinalizedProposalId.Uint64()
		}
	}

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

	// Proposed events via contract FilterProposed
	g.Go(func() error {
		end := newHead.Number.Uint64()
		iter, err := s.rpc.ShastaClients.Inbox.FilterProposed(
			&bind.FilterOpts{Start: startHeight.Uint64(), End: &end, Context: s.ctx})
		if err != nil {
			return fmt.Errorf("failed to filter Shasta Proposed events: %w", err)
		}
		defer iter.Close()
		for iter.Next() {
			event := iter.Event
			payload, err := s.rpc.DecodeProposedEventPayload(&bind.CallOpts{Context: s.ctx}, event.Data)
			if err != nil {
				return fmt.Errorf("failed to decode proposed event data: %w", err)
			}
			if payload == nil {
				return fmt.Errorf("decoded proposed event payload is nil")
			}
			meta := metadata.NewTaikoProposalMetadataShasta(payload, event.Raw)
			if err := s.onProposedEvent(s.ctx, meta); err != nil {
				return fmt.Errorf("failed to handle proposed event: %w", err)
			}
		}
		if err := iter.Error(); err != nil {
			return fmt.Errorf("error iterating Shasta Proposed events: %w", err)
		}
		return nil
	})

	// Proved events via contract FilterProved
	g.Go(func() error {
		end := newHead.Number.Uint64()
		iter, err := s.rpc.ShastaClients.Inbox.FilterProved(
			&bind.FilterOpts{Start: startHeight.Uint64(), End: &end, Context: s.ctx})
		if err != nil {
			return fmt.Errorf("failed to filter Shasta Proved events: %w", err)
		}
		defer iter.Close()
		for iter.Next() {
			event := iter.Event
			provedEventPayload, err := s.rpc.DecodeProvedEventPayload(&bind.CallOpts{Context: s.ctx}, event.Data)
			if err != nil {
				return fmt.Errorf("failed to decode Shasta Proved event data: %w", err)
			}
			if provedEventPayload == nil {
				return fmt.Errorf("decoded proved event payload is nil")
			}
			if err := s.onProvedEvent(s.ctx, provedEventPayload, &event.Raw); err != nil {
				return fmt.Errorf("failed to handle Shasta Proved event: %w", err)
			}
		}
		if err := iter.Error(); err != nil {
			return fmt.Errorf("error iterating Shasta Proved events: %w", err)
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
	for key := range s.transitionRecords {
		if key+threshold < lastFinalizedProposalId {
			log.Trace("Cleaning up finalized Shasta transition record", "proposalId", key)
			delete(s.transitionRecords, key)
		}
	}
}

// cleanupLegacyProposals cleans up proposals that are older than the last proposal ID minus the buffer size.
// NOT THREAD-SAFE
func (s *Indexer) cleanupLegacyProposals(lastProposalId uint64) {
	// We keep bufferSizeMultiplier times the buffer size of proposals to avoid future reorg handling.
	threshold := s.bufferSize * bufferSizeMultiplier
	for key := range s.proposals {
		if key+threshold < lastProposalId {
			log.Trace("Cleaning up legacy Shasta proposal", "proposalId", key)
			delete(s.proposals, key)
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
	var (
		maxID    uint64
		maxIDKey uint64
	)
	for key, p := range s.proposals {
		if p == nil {
			continue
		}
		if p.Proposal == nil {
			continue
		}
		if p.Proposal.Id.Uint64() > maxID {
			maxID = p.Proposal.Id.Uint64()
			maxIDKey = key
		}
	}

	proposal := s.proposals[maxIDKey]

	return proposal
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
	for _, proposal := range s.proposals {
		if proposal != nil {
			proposals = append(proposals, proposal)
		}
	}

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
	for key, proposal := range s.proposals {
		if proposal.RawBlockHeight.Cmp(safeHeight) > 0 {
			delete(s.proposals, key)
			removedProposals++
		}
	}

	// Clean up invalid transition records
	for key, transition := range s.transitionRecords {
		if transition.RawBlockHeight.Cmp(safeHeight) > 0 {
			delete(s.transitionRecords, key)
			removedTransitions++
		}
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
	transition, ok := s.transitionRecords[proposalID]
	if !ok {
		return nil
	}
	return transition
}

// GetProposalByID retrieves a proposal by its ID.
func (s *Indexer) GetProposalByID(proposalID uint64) (*ProposalPayload, error) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	proposal, ok := s.proposals[proposalID]
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
		nextSlotProposal, ok := s.proposals[nextKey]
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
		transition, ok := s.transitionRecords[lastFinalizedProposalId+i]
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
	return len(s.proposals)
}
