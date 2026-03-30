package state

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"sync/atomic"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	realtimeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/realtime"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/fork"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// State contains all states which will be used by driver.
type State struct {
	// Feeds
	l1HeadsFeed event.Feed // L1 new heads notification feed

	l1Head    atomic.Value // Latest known L1 head
	l2Head    atomic.Value // Current L2 execution engine's local chain head
	l1Current atomic.Value // Current L1 block sync cursor

	// Constants
	GenesisL1Height  *big.Int
	OnTakeForkHeight *big.Int
	PacayaForkHeight *big.Int
	ShastaForkTime   uint64

	// Fork identifier
	Fork string

	// RPC clients
	rpc *rpc.Client

	wg sync.WaitGroup
}

// New creates a new driver state instance.
func New(ctx context.Context, rpc *rpc.Client, fork string) (*State, error) {
	s := &State{rpc: rpc, Fork: fork}

	if err := s.init(ctx); err != nil {
		return nil, fmt.Errorf("failed to initialize driver state: %w", err)
	}

	go s.eventLoop(ctx)

	return s, nil
}

// Close closes all inner subscriptions.
func (s *State) Close() {
	s.wg.Wait()
}

// init fetches the latest status and initializes the state instance.
func (s *State) init(ctx context.Context) error {
	s.initGenesisHeight()

	log.Info("Genesis L1 height", "height", s.GenesisL1Height)

	switch s.Fork {
	case fork.Pacaya:
		s.OnTakeForkHeight = new(big.Int).SetUint64(s.rpc.PacayaClients.ForkHeights.Ontake)
		s.PacayaForkHeight = new(big.Int).SetUint64(s.rpc.PacayaClients.ForkHeights.Pacaya)
		log.Info("OnTake fork height", "blockID", s.OnTakeForkHeight)
		log.Info("Pacaya fork height", "blockID", s.PacayaForkHeight)
	case fork.Shasta:
		s.ShastaForkTime = s.rpc.ShastaClients.ForkTime
		log.Info("Shasta fork timestamp", "time", s.ShastaForkTime)
	case fork.RealTime:
		// No additional fork constants needed for RealTime
	}

	// Set the L2 head's latest known L1 origin as current L1 sync cursor.
	latestL2KnownL1Header, err := s.rpc.LatestL2KnownL1Header(ctx)
	if err != nil {
		return fmt.Errorf("failed to get latest L2 known L1 header: %w", err)
	}
	s.l1Current.Store(latestL2KnownL1Header)

	// L1 head
	l1Head, err := s.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L1 head: %w", err)
	}
	s.setL1Head(l1Head)

	// L2 head
	l2Head, err := s.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L2 head: %w", err)
	}

	log.Info("L2 execution engine head", "blockID", l2Head.Number, "hash", l2Head.Hash())
	s.setL2Head(l2Head)

	return nil
}

// eventLoop initializes and starts all subscriptions and callbacks in the given state instance.
func (s *State) eventLoop(ctx context.Context) {
	s.wg.Add(1)
	defer s.wg.Done()

	// Shared channels (always active).
	l1HeadCh := make(chan *types.Header, 10)
	l2HeadCh := make(chan *types.Header, 10)
	l1HeadSub := rpc.SubscribeChainHead(s.rpc.L1, l1HeadCh)
	l2HeadSub := rpc.SubscribeChainHead(s.rpc.L2, l2HeadCh)

	// Fork-specific channels and subscriptions (nil channels are never selected).
	var (
		batchesProvedPacayaCh          chan *pacayaBindings.TaikoInboxClientBatchesProved
		batchesVerifiedPacayaCh        chan *pacayaBindings.TaikoInboxClientBatchesVerified
		proposedShastaCh               chan *shastaBindings.ShastaInboxClientProposed
		provedShastaCh                 chan *shastaBindings.ShastaInboxClientProved
		proposedAndProvedRealTimeCh    chan *realtimeBindings.RealTimeInboxClientProposedAndProved
		l2BatchesVerifiedPacayaSub     event.Subscription
		l2BatchesProvedPacayaSub       event.Subscription
		l2ProposedShastaSub            event.Subscription
		l2ProvedShastaSub              event.Subscription
		l2ProposedAndProvedRealTimeSub event.Subscription
	)

	switch s.Fork {
	case fork.Pacaya:
		batchesProvedPacayaCh = make(chan *pacayaBindings.TaikoInboxClientBatchesProved, 10)
		batchesVerifiedPacayaCh = make(chan *pacayaBindings.TaikoInboxClientBatchesVerified, 10)
		l2BatchesVerifiedPacayaSub = rpc.SubscribeBatchesVerifiedPacaya(
			s.rpc.PacayaClients.TaikoInbox,
			batchesVerifiedPacayaCh,
		)
		l2BatchesProvedPacayaSub = rpc.SubscribeBatchesProvedPacaya(s.rpc.PacayaClients.TaikoInbox, batchesProvedPacayaCh)
	case fork.Shasta:
		proposedShastaCh = make(chan *shastaBindings.ShastaInboxClientProposed, 10)
		provedShastaCh = make(chan *shastaBindings.ShastaInboxClientProved, 10)
		l2ProposedShastaSub = rpc.SubscribeProposedShasta(s.rpc.ShastaClients.Inbox, proposedShastaCh)
		l2ProvedShastaSub = rpc.SubscribeProvedShasta(s.rpc.ShastaClients.Inbox, provedShastaCh)
	case fork.RealTime:
		proposedAndProvedRealTimeCh = make(chan *realtimeBindings.RealTimeInboxClientProposedAndProved, 10)
		l2ProposedAndProvedRealTimeSub = rpc.SubscribeProposedAndProvedRealTime(
			s.rpc.RealTimeClients.Inbox,
			proposedAndProvedRealTimeCh,
		)
	}

	defer func() {
		l1HeadSub.Unsubscribe()
		l2HeadSub.Unsubscribe()
		if l2BatchesVerifiedPacayaSub != nil {
			l2BatchesVerifiedPacayaSub.Unsubscribe()
		}
		if l2BatchesProvedPacayaSub != nil {
			l2BatchesProvedPacayaSub.Unsubscribe()
		}
		if l2ProposedShastaSub != nil {
			l2ProposedShastaSub.Unsubscribe()
		}
		if l2ProvedShastaSub != nil {
			l2ProvedShastaSub.Unsubscribe()
		}
		if l2ProposedAndProvedRealTimeSub != nil {
			l2ProposedAndProvedRealTimeSub.Unsubscribe()
		}
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case e := <-batchesProvedPacayaCh:
			log.Info("✅ Pacaya batches proven", "batchIDs", e.BatchIds, "verifier", e.Verifier)
		case e := <-provedShastaCh:
			coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
			if err != nil {
				log.Error("Failed to get Shasta core state", "err", err)
				continue
			}
			header, err := s.rpc.L2.HeaderByHash(ctx, coreState.LastFinalizedBlockHash)
			if err != nil {
				log.Error("Failed to get Shasta finalized block header", "err", err)
				continue
			}
			log.Info(
				"📈 Shasta batches proven and verified",
				"firstBatchID", e.FirstNewProposalId,
				"lastBatchID", e.LastProposalId,
				"checkpointNumber", header.Number,
				"checkpointHash", common.Hash(coreState.LastFinalizedBlockHash),
			)
		case e := <-batchesVerifiedPacayaCh:
			log.Info(
				"📈 Pacaya batches verified",
				"lastVerifiedBatchID", e.BatchId,
				"lastVerifiedBlockHash", common.Hash(e.BlockHash),
			)
		case e := <-proposedAndProvedRealTimeCh:
			if e != nil {
				log.Info(
					"✅ RealTime proposed and proved",
					"proposalHash", common.Hash(e.ProposalHash),
					"lastFinalizedBlockHash", common.Hash(e.LastFinalizedBlockHash),
					"checkpointBlockNumber", e.Checkpoint.BlockNumber,
					"checkpointBlockHash", common.Hash(e.Checkpoint.BlockHash),
					"checkpointStateRoot", common.Hash(e.Checkpoint.StateRoot),
				)
			}
		case newHead := <-l1HeadCh:
			s.setL1Head(newHead)
			s.l1HeadsFeed.Send(newHead)
		case newHead := <-l2HeadCh:
			s.setL2Head(newHead)
		}
	}
}

// setL1Head sets the L1 head concurrent safely.
func (s *State) setL1Head(l1Head *types.Header) {
	if l1Head == nil {
		log.Warn("Empty new L1 head")
		return
	}

	log.Debug("New L1 head", "height", l1Head.Number, "hash", l1Head.Hash(), "timestamp", l1Head.Time)
	metrics.DriverL1HeadHeightGauge.Set(float64(l1Head.Number.Int64()))

	s.l1Head.Store(l1Head)
}

// GetL1Head reads the L1 head concurrent safely.
func (s *State) GetL1Head() *types.Header {
	return s.l1Head.Load().(*types.Header)
}

// setL2Head sets the L2 head concurrent safely.
func (s *State) setL2Head(l2Head *types.Header) {
	if l2Head == nil {
		log.Warn("Empty new L2 head")
		return
	}

	log.Trace("New L2 head", "blockID", l2Head.Number, "hash", l2Head.Hash(), "timestamp", l2Head.Time)

	s.l2Head.Store(l2Head)
}

// GetL2Head reads the L2 head concurrent safely.
func (s *State) GetL2Head() *types.Header {
	return s.l2Head.Load().(*types.Header)
}

// SubL1HeadsFeed registers a subscription of new L1 heads.
func (s *State) SubL1HeadsFeed(ch chan *types.Header) event.Subscription {
	return s.l1HeadsFeed.Subscribe(ch)
}

// IsPacaya returns whether num is either equal to the Pacaya block or greater.
func (s *State) IsPacaya(num *big.Int) bool {
	if s.PacayaForkHeight == nil || num == nil {
		return false
	}
	return s.PacayaForkHeight.Cmp(num) <= 0
}

// initGenesisHeight reads the genesis L1 height from the RPC client, which was
// set during client initialization (from contract for pacaya, from config for shasta/realtime).
func (s *State) initGenesisHeight() {
	s.GenesisL1Height = new(big.Int).SetUint64(s.rpc.GenesisL1Height)
}
