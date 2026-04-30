package state

import (
	"context"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const defaultHeadPollingInterval = 3 * time.Second

// headTracker keeps the cached L1/L2 heads fresh for the driver state.
type headTracker interface {
	// Start runs the tracker until the context is done or Close is called.
	Start(context.Context)
	// Close stops the tracker and releases any owned subscriptions.
	Close()
}

// newHeadTracker chooses the subscription or polling backend for the selected RPC endpoints.
func newHeadTracker(s *State) headTracker {
	if s.rpc.UseSubscriptions {
		return &subscriptionHeadTracker{s: s, closeCh: make(chan struct{})}
	}

	return &pollingHeadTracker{s: s, closeCh: make(chan struct{})}
}

// subscriptionHeadTracker updates heads from websocket subscriptions.
type subscriptionHeadTracker struct {
	// s is the driver state updated by subscription events.
	s *State
	// closeCh signals Start to exit.
	closeCh chan struct{}
	// close makes Close idempotent.
	close sync.Once
	// mu guards subs while Close may run concurrently with Start.
	mu sync.Mutex
	// subs contains all active websocket subscriptions owned by the tracker.
	subs []event.Subscription
}

// Start subscribes to L1/L2 heads and Shasta proof events.
func (t *subscriptionHeadTracker) Start(ctx context.Context) {
	var (
		// Channels for subscriptions.
		l1HeadCh = make(chan *types.Header, 10)
		l2HeadCh = make(chan *types.Header, 10)
		provedCh = make(chan *shastaBindings.ShastaInboxClientProved, 10)

		// Subscriptions.
		l1HeadSub         = rpc.SubscribeChainHead(t.s.rpc.L1, l1HeadCh)
		l2HeadSub         = rpc.SubscribeChainHead(t.s.rpc.L2, l2HeadCh)
		l2ProvedShastaSub = rpc.SubscribeProved(t.s.rpc.ShastaClients.Inbox, provedCh)
	)

	t.mu.Lock()
	t.subs = []event.Subscription{l1HeadSub, l2HeadSub, l2ProvedShastaSub}
	t.mu.Unlock()
	defer t.Close()

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.closeCh:
			return
		case e := <-provedCh:
			coreState, err := t.s.rpc.GetCoreState(&bind.CallOpts{Context: ctx})
			if err != nil {
				log.Error("Failed to get core state", "err", err)
				continue
			}
			header, err := t.s.rpc.L2.HeaderByHash(ctx, coreState.LastFinalizedBlockHash)
			if err != nil {
				log.Error("Failed to get finalized block header", "err", err)
				continue
			}
			log.Info(
				"📈 Proposals proven and verified",
				"firstProposalID", e.FirstNewProposalId,
				"lastProposalID", e.LastProposalId,
				"checkpointNumber", header.Number,
				"checkpointHash", common.Hash(coreState.LastFinalizedBlockHash),
			)
		case newHead := <-l1HeadCh:
			t.s.updateL1HeadIfChanged(newHead)
		case newHead := <-l2HeadCh:
			t.s.setL2Head(newHead)
		}
	}
}

// Close stops all active subscriptions and unblocks Start.
func (t *subscriptionHeadTracker) Close() {
	t.close.Do(func() {
		close(t.closeCh)
	})

	t.mu.Lock()
	defer t.mu.Unlock()
	for _, sub := range t.subs {
		sub.Unsubscribe()
	}
	t.subs = nil
}

// pollingHeadTracker updates heads by periodically polling latest headers.
type pollingHeadTracker struct {
	// s is the driver state updated by polling results.
	s *State
	// closeCh signals Start to exit.
	closeCh chan struct{}
	// close makes Close idempotent.
	close sync.Once
}

// Start polls latest L1/L2 heads until the context is done or Close is called.
func (t *pollingHeadTracker) Start(ctx context.Context) {
	ticker := time.NewTicker(defaultHeadPollingInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-t.closeCh:
			return
		case <-ticker.C:
			t.poll(ctx)
		}
	}
}

// Close unblocks Start and stops future polling.
func (t *pollingHeadTracker) Close() {
	t.close.Do(func() {
		close(t.closeCh)
	})
}

// poll fetches latest L1/L2 heads once and applies changed values to state.
func (t *pollingHeadTracker) poll(ctx context.Context) {
	l1Head, err := t.s.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		log.Warn("Failed to poll L1 head", "err", err)
	} else {
		t.s.updateL1HeadIfChanged(l1Head)
	}

	l2Head, err := t.s.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		log.Warn("Failed to poll L2 head", "err", err)
	} else {
		t.s.updateL2HeadIfChanged(l2Head)
	}
}
