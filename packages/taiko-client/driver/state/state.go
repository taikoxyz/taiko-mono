package state

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// State contains all states which will be used by driver.
type State struct {
	// l1HeadsFeed broadcasts changed L1 heads to sync consumers.
	l1HeadsFeed event.Feed

	// l1Head stores the latest known L1 head.
	l1Head atomic.Value
	// l2Head stores the current L2 execution engine's local chain head.
	l2Head atomic.Value
	// l1Current stores the current L1 block sync cursor.
	l1Current atomic.Value

	// GenesisL1Height is the L1 activation height for the current inbox.
	GenesisL1Height *big.Int

	// rpc contains the L1/L2 RPC clients used by the state.
	rpc *rpc.Client

	// headTracker updates cached L1/L2 heads from subscriptions or polling.
	headTracker headTracker
	// wg waits for the tracker event loop to exit.
	wg sync.WaitGroup
}

// New creates a new driver state instance.
func New(ctx context.Context, rpc *rpc.Client) (*State, error) {
	s := &State{rpc: rpc}

	if err := s.init(ctx); err != nil {
		return nil, fmt.Errorf("failed to initialize driver state: %w", err)
	}

	s.headTracker = newHeadTracker(s)
	s.wg.Add(1)
	go s.eventLoop(ctx)

	return s, nil
}

// Close closes all inner subscriptions.
func (s *State) Close() {
	if s.headTracker != nil {
		s.headTracker.Close()
	}
	s.wg.Wait()
}

// init fetches the latest status and initializes the state instance.
func (s *State) init(ctx context.Context) error {
	if err := s.initGenesisHeight(ctx); err != nil {
		return fmt.Errorf("failed to initialize genesis height: %w", err)
	}

	log.Info("Genesis L1 height", "height", s.GenesisL1Height)

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

// eventLoop starts the configured head tracker in the given state instance.
func (s *State) eventLoop(ctx context.Context) {
	defer s.wg.Done()

	if s.headTracker != nil {
		s.headTracker.Start(ctx)
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

// updateL1HeadIfChanged updates and broadcasts an L1 head only when it changed.
func (s *State) updateL1HeadIfChanged(l1Head *types.Header) bool {
	if l1Head == nil {
		s.setL1Head(l1Head)
		return false
	}

	if sameHeader(s.GetL1Head(), l1Head) {
		return false
	}

	s.setL1Head(l1Head)
	s.l1HeadsFeed.Send(l1Head)
	return true
}

// GetL1Head reads the L1 head concurrent safely.
func (s *State) GetL1Head() *types.Header {
	return s.l1Head.Load().(*types.Header)
}

// SetL2Head exposes setL2Head to callers outside this package.
// Used by the chain syncer to refresh the cached L2 head from RPC when the
// `newHeads` subscription has not observed an engine-API-driven backfill.
func (s *State) SetL2Head(l2Head *types.Header) {
	s.setL2Head(l2Head)
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

// updateL2HeadIfChanged updates the cached L2 head only when it changed.
func (s *State) updateL2HeadIfChanged(l2Head *types.Header) bool {
	if l2Head == nil {
		s.setL2Head(l2Head)
		return false
	}

	if sameHeader(s.GetL2Head(), l2Head) {
		return false
	}

	s.setL2Head(l2Head)
	return true
}

// GetL2Head reads the L2 head concurrent safely.
func (s *State) GetL2Head() *types.Header {
	return s.l2Head.Load().(*types.Header)
}

// SubL1HeadsFeed registers a subscription of new L1 heads.
func (s *State) SubL1HeadsFeed(ch chan *types.Header) event.Subscription {
	return s.l1HeadsFeed.Subscribe(ch)
}

// initGenesisHeight fetches the L1 activation height for the current inbox.
func (s *State) initGenesisHeight(ctx context.Context) error {
	// GetActivationBlockNumber returns the L1 block number whose timestamp matches the
	// inbox activation timestamp.
	genesisHeight, err := s.rpc.GetActivationBlockNumber(ctx)
	if err != nil {
		return fmt.Errorf("failed to get activation block number: %w", err)
	}

	s.GenesisL1Height = genesisHeight
	return nil
}

// sameHeader reports whether two headers identify the same block.
func sameHeader(a, b *types.Header) bool {
	if a == nil || b == nil {
		return a == b
	}

	if a.Number == nil || b.Number == nil {
		return a.Number == b.Number && a.Hash() == b.Hash()
	}

	return a.Number.Cmp(b.Number) == 0 && a.Hash() == b.Hash()
}
