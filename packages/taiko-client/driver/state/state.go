package state

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"sync/atomic"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	l1HeadPollInterval = time.Second
	l1LogPollMaxRange  = uint64(1000)
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
	s.ShastaForkTime = s.rpc.ShastaClients.ForkTime

	log.Info("Genesis L1 height", "height", s.GenesisL1Height)
	log.Info("OnTake fork height", "blockID", s.OnTakeForkHeight)
	log.Info("Pacaya fork height", "blockID", s.PacayaForkHeight)
	log.Info("Shasta fork timestamp", "time", s.ShastaForkTime)

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
		l2HeadCh = make(chan *types.Header, 10)

		// Subscriptions.
		l2HeadSub = rpc.SubscribeChainHead(s.rpc.L2, l2HeadCh)
	)

	defer func() {
		l2HeadSub.Unsubscribe()
	}()

	l1HeadPoller := time.NewTicker(l1HeadPollInterval)
	defer l1HeadPoller.Stop()

	lastL1HeadNumber := s.GetL1Head().Number.Uint64()
	lastL1HeadHash := s.GetL1Head().Hash()
	lastL1EventBlock := lastL1HeadNumber

	for {
		select {
		case <-ctx.Done():
			return
		case <-l1HeadPoller.C:
			latest, err := s.rpc.L1.BlockNumber(ctx)
			if err != nil {
				log.Warn("Failed to poll L1 head number", "error", err)
				continue
			}
			header, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(latest))
			if err != nil {
				log.Warn("Failed to fetch L1 head header", "error", err, "height", latest)
				continue
			}
			sameHeight := latest == lastL1HeadNumber
			sameHash := header.Hash() == lastL1HeadHash
			if sameHeight && sameHash {
				continue
			}
			start := lastL1EventBlock + 1
			if latest < lastL1EventBlock {
				log.Warn(
					"L1 head regressed; rewinding L1 event polling cursor",
					"latest", latest,
					"lastL1EventBlock", lastL1EventBlock,
				)
				start = latest
			} else if sameHeight && !sameHash {
				log.Warn(
					"L1 head hash changed; rewinding L1 event polling cursor",
					"height", latest,
					"hash", header.Hash(),
					"previous", lastL1HeadHash,
				)
				start = latest
			}
			lastL1HeadNumber = latest
			lastL1HeadHash = header.Hash()
			s.setL1Head(header)
			s.l1HeadsFeed.Send(header)
			if start <= latest {
				if err := s.pollL1Events(ctx, start, latest); err != nil {
					log.Warn("Failed to poll L1 protocol events", "error", err)
				} else {
					lastL1EventBlock = latest
				}
			}
		case newHead := <-l2HeadCh:
			s.setL2Head(newHead)
		}
	}
}

func (s *State) pollL1Events(ctx context.Context, start, end uint64) error {
	if start > end {
		return nil
	}
	for from := start; from <= end; {
		to := from + l1LogPollMaxRange - 1
		if to < from || to > end {
			to = end
		}
		if err := s.handleL1EventRange(ctx, from, to); err != nil {
			return err
		}
		if to == end {
			break
		}
		from = to + 1
	}
	return nil
}

func (s *State) handleL1EventRange(ctx context.Context, start, end uint64) error {
	endHeight := end
	opts := &bind.FilterOpts{Start: start, End: &endHeight, Context: ctx}

	verifiedIter, err := s.rpc.PacayaClients.TaikoInbox.FilterBatchesVerified(opts)
	if err != nil {
		return err
	}
	defer verifiedIter.Close()
	for verifiedIter.Next() {
		e := verifiedIter.Event
		log.Info(
			"📈 Pacaya batches verified",
			"lastVerifiedBatchID", e.BatchId,
			"lastVerifiedBlockHash", common.Hash(e.BlockHash),
		)
	}
	if err := verifiedIter.Error(); err != nil {
		return err
	}

	provedIter, err := s.rpc.PacayaClients.TaikoInbox.FilterBatchesProved(opts)
	if err != nil {
		return err
	}
	defer provedIter.Close()
	for provedIter.Next() {
		e := provedIter.Event
		log.Info("✅ Pacaya batches proven", "batchIDs", e.BatchIds, "verifier", e.Verifier)
	}
	if err := provedIter.Error(); err != nil {
		return err
	}

	shastaProvedIter, err := s.rpc.ShastaClients.Inbox.FilterProved(opts, nil)
	if err != nil {
		return err
	}
	defer shastaProvedIter.Close()
	for shastaProvedIter.Next() {
		e := shastaProvedIter.Event
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
	}
	if err := shastaProvedIter.Error(); err != nil {
		return err
	}

	return nil
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
