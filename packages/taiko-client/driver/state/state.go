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
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
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
	ShastaForkHeight *big.Int

	// RPC clients
	rpc *rpc.Client

	wg sync.WaitGroup
}

// New creates a new driver state instance.
func New(ctx context.Context, rpc *rpc.Client) (*State, error) {
	s := &State{rpc: rpc}

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
	if err := s.initGenesisHeight(ctx); err != nil {
		return fmt.Errorf("failed to initialize genesis height: %w", err)
	}
	s.OnTakeForkHeight = new(big.Int).SetUint64(s.rpc.PacayaClients.ForkHeights.Ontake)
	s.PacayaForkHeight = new(big.Int).SetUint64(s.rpc.PacayaClients.ForkHeights.Pacaya)
	s.ShastaForkHeight = new(big.Int).SetUint64(s.rpc.ShastaClients.ForkHeight.Uint64())

	log.Info("Genesis L1 height", "height", s.GenesisL1Height)
	log.Info("OnTake fork height", "blockID", s.OnTakeForkHeight)
	log.Info("Pacaya fork height", "blockID", s.PacayaForkHeight)
	log.Info("Shasta fork height", "blockID", s.ShastaForkHeight)

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

	var (
		// Channels for subscriptions.
		l1HeadCh                = make(chan *types.Header, 10)
		l2HeadCh                = make(chan *types.Header, 10)
		batchesProvedPacayaCh   = make(chan *pacayaBindings.TaikoInboxClientBatchesProved, 10)
		batchesVerifiedPacayaCh = make(chan *pacayaBindings.TaikoInboxClientBatchesVerified, 10)
		proposedShastaCh        = make(chan *shastaBindings.ShastaInboxClientProposed, 10)
		provedShastaCh          = make(chan *shastaBindings.ShastaInboxClientProved, 10)

		// Subscriptions.
		l1HeadSub                  = rpc.SubscribeChainHead(s.rpc.L1, l1HeadCh)
		l2HeadSub                  = rpc.SubscribeChainHead(s.rpc.L2, l2HeadCh)
		l2BatchesVerifiedPacayaSub = rpc.SubscribeBatchesVerifiedPacaya(
			s.rpc.PacayaClients.TaikoInbox,
			batchesVerifiedPacayaCh,
		)
		l2BatchesProvedPacayaSub = rpc.SubscribeBatchesProvedPacaya(s.rpc.PacayaClients.TaikoInbox, batchesProvedPacayaCh)
		l2ProposedShastaSub      = rpc.SubscribeProposedShasta(s.rpc.ShastaClients.Inbox, proposedShastaCh)
		l2ProvedShastaSub        = rpc.SubscribeProvedShasta(s.rpc.ShastaClients.Inbox, provedShastaCh)

		// Last finalized Shasta proposal ID
		lastFinalizedShastaProposalId *big.Int
	)

	defer func() {
		l1HeadSub.Unsubscribe()
		l2HeadSub.Unsubscribe()
		l2BatchesVerifiedPacayaSub.Unsubscribe()
		l2BatchesProvedPacayaSub.Unsubscribe()
		l2ProposedShastaSub.Unsubscribe()
		l2ProvedShastaSub.Unsubscribe()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case e := <-batchesProvedPacayaCh:
			log.Info("✅ Pacaya batches proven", "batchIDs", e.BatchIds, "verifier", e.Verifier)
		case e := <-provedShastaCh:
			payload, err := s.rpc.DecodeProvedEventPayload(&bind.CallOpts{Context: ctx}, e.Data)
			if err != nil {
				log.Error("Failed to decode proved payload", "err", err)
				continue
			}
			log.Info(
				"✅ Shasta batches proven",
				"batchIDs", payload.ProposalId,
				"checkpointNumber", payload.Transition.Checkpoint.BlockNumber,
				"checkpointHash", common.Hash(payload.Transition.Checkpoint.BlockHash),
			)
		case e := <-batchesVerifiedPacayaCh:
			log.Info(
				"📈 Pacaya batches verified",
				"lastVerifiedBatchId", e.BatchId,
				"lastVerifiedBlockHash", common.Hash(e.BlockHash),
			)
		case e := <-proposedShastaCh:
			payload, err := s.rpc.DecodeProposedEventPayload(&bind.CallOpts{Context: ctx}, e.Data)
			if err != nil {
				log.Error("Failed to decode proposed payload", "err", err)
				continue
			}
			if lastFinalizedShastaProposalId != nil &&
				payload.CoreState.LastFinalizedProposalId.Cmp(lastFinalizedShastaProposalId) > 0 {
				log.Info(
					"📈 Shasta batches verified",
					"lastVerifiedBatchId", payload.CoreState.LastFinalizedProposalId,
					"lastFinalizedTransitionHash", common.Hash(payload.CoreState.LastFinalizedTransitionHash[:]),
				)
			}
			lastFinalizedShastaProposalId = payload.CoreState.LastFinalizedProposalId
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

// initGenesisHeight fetches the genesis height from the current protocol.
func (s *State) initGenesisHeight(ctx context.Context) error {
	stateVars, err := s.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		return fmt.Errorf("failed to get protocol state variables: %w", err)
	}

	s.GenesisL1Height = new(big.Int).SetUint64(stateVars.Stats1.GenesisHeight)
	return nil
}
