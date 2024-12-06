package state

import (
	"context"
	"math/big"
	"sync"
	"sync/atomic"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// State contains all states which will be used by driver.
type State struct {
	// Feeds
	l1HeadsFeed event.Feed // L1 new heads notification feed

	l1Head        atomic.Value // Latest known L1 head
	l2Head        atomic.Value // Current L2 execution engine's local chain head
	l2HeadBlockID atomic.Value // Latest known L2 block ID in protocol
	l1Current     atomic.Value // Current L1 block sync cursor

	// Constants
	GenesisL1Height  *big.Int
	OnTakeForkHeight *big.Int

	// RPC clients
	rpc *rpc.Client

	wg sync.WaitGroup
}

// New creates a new driver state instance.
func New(ctx context.Context, rpc *rpc.Client) (*State, error) {
	s := &State{rpc: rpc}

	if err := s.init(ctx); err != nil {
		return nil, err
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
	stateVars, err := s.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: ctx})
	if err != nil {
		return err
	}

	protocolConfigs, err := rpc.GetProtocolConfigs(s.rpc.TaikoL1, &bind.CallOpts{Context: ctx})
	if err != nil {
		return err
	}

	s.GenesisL1Height = new(big.Int).SetUint64(stateVars.A.GenesisHeight)
	s.OnTakeForkHeight = new(big.Int).SetUint64(protocolConfigs.OntakeForkHeight)

	log.Info("Genesis L1 height", "height", stateVars.A.GenesisHeight)
	log.Info("OnTake fork height", "height", s.OnTakeForkHeight)

	// Set the L2 head's latest known L1 origin as current L1 sync cursor.
	latestL2KnownL1Header, err := s.rpc.LatestL2KnownL1Header(ctx)
	if err != nil {
		return err
	}
	s.l1Current.Store(latestL2KnownL1Header)

	// L1 head
	l1Head, err := s.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return err
	}
	s.setL1Head(l1Head)

	// L2 head
	l2Head, err := s.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return err
	}

	log.Info("L2 execution engine head", "height", l2Head.Number, "hash", l2Head.Hash())
	s.setL2Head(l2Head)

	s.setHeadBlockID(new(big.Int).SetUint64(stateVars.B.NumBlocks - 1))

	return nil
}

// eventLoop initializes and starts all subscriptions and callbacks in the given state instance.
func (s *State) eventLoop(ctx context.Context) {
	s.wg.Add(1)
	defer s.wg.Done()

	var (
		// Channels for subscriptions.
		l1HeadCh             = make(chan *types.Header, 10)
		l2HeadCh             = make(chan *types.Header, 10)
		blockProposedCh      = make(chan *bindings.TaikoL1ClientBlockProposed, 10)
		transitionProvedCh   = make(chan *bindings.TaikoL1ClientTransitionProved, 10)
		blockVerifiedCh      = make(chan *bindings.TaikoL1ClientBlockVerified, 10)
		blockProposedV2Ch    = make(chan *bindings.TaikoL1ClientBlockProposedV2, 10)
		transitionProvedV2Ch = make(chan *bindings.TaikoL1ClientTransitionProvedV2, 10)
		blockVerifiedV2Ch    = make(chan *bindings.TaikoL1ClientBlockVerifiedV2, 10)

		// Subscriptions.
		l1HeadSub               = rpc.SubscribeChainHead(s.rpc.L1, l1HeadCh)
		l2HeadSub               = rpc.SubscribeChainHead(s.rpc.L2, l2HeadCh)
		l2BlockVerifiedSub      = rpc.SubscribeBlockVerified(s.rpc.TaikoL1, blockVerifiedCh)
		l2BlockProposedSub      = rpc.SubscribeBlockProposed(s.rpc.TaikoL1, blockProposedCh)
		l2TransitionProvedSub   = rpc.SubscribeTransitionProved(s.rpc.TaikoL1, transitionProvedCh)
		l2BlockVerifiedV2Sub    = rpc.SubscribeBlockVerifiedV2(s.rpc.TaikoL1, blockVerifiedV2Ch)
		l2BlockProposedV2Sub    = rpc.SubscribeBlockProposedV2(s.rpc.TaikoL1, blockProposedV2Ch)
		l2TransitionProvedV2Sub = rpc.SubscribeTransitionProvedV2(s.rpc.TaikoL1, transitionProvedV2Ch)
	)

	defer func() {
		l1HeadSub.Unsubscribe()
		l2HeadSub.Unsubscribe()
		l2BlockVerifiedSub.Unsubscribe()
		l2BlockProposedSub.Unsubscribe()
		l2TransitionProvedSub.Unsubscribe()
		l2BlockVerifiedV2Sub.Unsubscribe()
		l2BlockProposedV2Sub.Unsubscribe()
		l2TransitionProvedV2Sub.Unsubscribe()
	}()

	for {
		select {
		case <-ctx.Done():
			return
		case e := <-blockProposedCh:
			s.setHeadBlockID(e.BlockId)
		case e := <-blockProposedV2Ch:
			s.setHeadBlockID(e.BlockId)
		case e := <-transitionProvedCh:
			log.Info(
				"✅ Transition proven",
				"blockID", e.BlockId,
				"parentHash", common.Hash(e.Tran.ParentHash),
				"hash", common.Hash(e.Tran.BlockHash),
				"stateRoot", common.Hash(e.Tran.StateRoot),
				"prover", e.Prover,
			)
		case e := <-transitionProvedV2Ch:
			log.Info(
				"✅ Transition proven",
				"blockID", e.BlockId,
				"parentHash", common.Hash(e.Tran.ParentHash),
				"hash", common.Hash(e.Tran.BlockHash),
				"stateRoot", common.Hash(e.Tran.StateRoot),
				"prover", e.Prover,
			)
		case e := <-blockVerifiedCh:
			log.Info(
				"📈 Block verified",
				"blockID", e.BlockId,
				"hash", common.Hash(e.BlockHash),
				"stateRoot", common.Hash(e.StateRoot),
				"prover", e.Prover,
			)
		case e := <-blockVerifiedV2Ch:
			log.Info(
				"📈 Block verified",
				"blockID", e.BlockId,
				"hash", common.Hash(e.BlockHash),
				"prover", e.Prover,
			)
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

	log.Trace("New L2 head", "height", l2Head.Number, "hash", l2Head.Hash(), "timestamp", l2Head.Time)
	metrics.DriverL2HeadHeightGauge.Set(float64(l2Head.Number.Uint64()))

	s.l2Head.Store(l2Head)
}

// GetL2Head reads the L2 head concurrent safely.
func (s *State) GetL2Head() *types.Header {
	return s.l2Head.Load().(*types.Header)
}

// setHeadBlockID sets the last pending block ID concurrent safely.
func (s *State) setHeadBlockID(id *big.Int) {
	log.Debug("New head block ID", "ID", id)
	metrics.DriverL2HeadIDGauge.Set(float64(id.Uint64()))
	s.l2HeadBlockID.Store(id)
}

// GetHeadBlockID reads the last pending block ID concurrent safely.
func (s *State) GetHeadBlockID() *big.Int {
	return s.l2HeadBlockID.Load().(*big.Int)
}

// SubL1HeadsFeed registers a subscription of new L1 heads.
func (s *State) SubL1HeadsFeed(ch chan *types.Header) event.Subscription {
	return s.l1HeadsFeed.Subscribe(ch)
}

// IsOnTake returns whether num is either equal to the ontake block or greater.
func (s *State) IsOnTake(num *big.Int) bool {
	if s.OnTakeForkHeight == nil || num == nil {
		return false
	}
	return s.OnTakeForkHeight.Cmp(num) <= 0
}
