package chainsyncer

import (
	"context"
	"fmt"
	"math/big"
	"net/url"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	preconfBlocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// L2ChainSyncer is responsible for keeping the L2 execution engine's local chain in sync with the one
// in TaikoInbox contract.
type L2ChainSyncer struct {
	ctx   context.Context
	state *state.State // Driver's state
	rpc   *rpc.Client  // L1/L2 RPC clients

	// Syncers
	beaconSyncer *beaconsync.Syncer
	eventSyncer  *event.Syncer

	// Preconfirmation server
	preconfBlockServer *preconfBlocks.PreconfBlockAPIServer

	// Monitors
	progressTracker *beaconsync.SyncProgressTracker

	// If this flag is activated, will try P2P beacon sync if current node is behind of the protocol's
	// the latest verified block head
	p2pSync bool

	// True after a beacon sync trigger until the first event sync writes head L1 origin.
	postBeaconSyncPending bool
}

// New creates a new chain syncer instance.
func New(
	ctx context.Context,
	rpc *rpc.Client,
	state *state.State,
	p2pSync bool,
	p2pSyncTimeout time.Duration,
	blobServerEndpoint *url.URL,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) (*L2ChainSyncer, error) {
	tracker := beaconsync.NewSyncProgressTracker(rpc.L2, p2pSyncTimeout)
	go tracker.Track(ctx)

	beaconSyncer := beaconsync.NewSyncer(ctx, rpc, state, tracker)
	eventSyncer, err := event.NewSyncer(ctx, rpc, state, tracker, blobServerEndpoint, latestSeenProposalCh)
	if err != nil {
		return nil, fmt.Errorf("failed to create event syncer: %w", err)
	}

	return &L2ChainSyncer{
		ctx:             ctx,
		rpc:             rpc,
		state:           state,
		beaconSyncer:    beaconSyncer,
		eventSyncer:     eventSyncer,
		progressTracker: tracker,
		p2pSync:         p2pSync,
	}, nil
}

// Sync performs a sync operation to L2 execution engine's local chain.
func (s *L2ChainSyncer) Sync() error {
	blockIDToSync, needNewBeaconSyncTriggered, err := s.needNewBeaconSyncTriggered()
	if err != nil {
		return fmt.Errorf("failed to check if beacon sync is needed: %w", err)
	}

	// If current L2 execution engine's chain is behind of the block head to sync, and the
	// `P2PSync` flag is set, try triggering a beacon sync in L2 execution engine to catch up the
	// head.
	if needNewBeaconSyncTriggered {
		// Mark the preconfirmation block server as not ready to insert blocks.
		if s.preconfBlockServer != nil {
			log.Info("Mark preconfirmation block server as not ready to insert blocks")
			s.preconfBlockServer.SetSyncReady(false)
		}
		s.postBeaconSyncPending = true
		if err := s.beaconSyncer.TriggerBeaconSync(blockIDToSync); err != nil {
			return fmt.Errorf("trigger beacon sync error: %w", err)
		}

		return nil
	}

	// Mark the beacon sync progress as finished, to make sure that
	// we will only check and trigger P2P sync progress once right after the driver starts.
	s.progressTracker.MarkFinished()

	// We have triggered at least a beacon sync in L2 execution engine, we should reset the L1Current
	// cursor before we start inserting pending L2 proposals one by one.
	if s.progressTracker.Triggered() {
		log.Info(
			"Switch to insert pending proposals one by one",
			"p2pEnabled", s.p2pSync,
			"p2pOutOfSync", s.progressTracker.OutOfSync(),
		)

		if err := s.SetUpEventSync(blockIDToSync); err != nil {
			return fmt.Errorf("failed to set up event synchronization: %w", err)
		}
	}

	// Mark the preconfirmation block server as ready to insert blocks unless we are
	// waiting for the first event sync to establish head L1 origin after beacon sync.
	if s.preconfBlockServer != nil && !s.postBeaconSyncPending {
		log.Info("Mark preconfirmation block server as ready to insert blocks")
		s.preconfBlockServer.SetSyncReady(true)
	}

	// Insert the proposed proposals one by one.
	if err := s.eventSyncer.ProcessL1Blocks(s.ctx); err != nil {
		return err
	}

	// After beacon sync, only enable preconf imports once head L1 origin has been written by the first
	// successful event sync. This avoids importing cached forks before the L1 origin base exists.
	if s.preconfBlockServer != nil && s.postBeaconSyncPending {
		headL1Origin, err := s.rpc.L2.HeadL1Origin(s.ctx)
		if err != nil && err.Error() != ethereum.NotFound.Error() {
			return fmt.Errorf("failed to fetch head L1 origin after event sync: %w", err)
		}
		if headL1Origin != nil {
			log.Info("Head L1 origin written after event sync, enable preconf imports")
			s.preconfBlockServer.SetSyncReady(true)
			if err := s.preconfBlockServer.ImportPendingBlocksFromCache(s.ctx); err != nil {
				log.Warn("Failed to import pending preconfirmation blocks from cache, skip the import", "error", err)
			}
			s.postBeaconSyncPending = false
		} else {
			log.Info("Head L1 origin not set after event sync, keep preconf imports disabled")
		}
	}
	return nil
}

// SetUpEventSync resets the L1Current cursor to the latest L2 execution engine's chain head.
// This method should only be called after the L2 execution engine's chain has just finished a beacon sync.
func (s *L2ChainSyncer) SetUpEventSync(blockIDToSync uint64) error {
	var headNumber = new(big.Int).SetUint64(blockIDToSync)
	// Fall back to the live EE head when either:
	//   - the tracker is flagged OutOfSync (the existing timeout path), or
	//   - blockIDToSync is 0, which happens once needNewBeaconSyncTriggered
	//     short-circuits via Finished()=true. Without this guard,
	//     HeaderByNumber(0) returns genesis and ResetL1Current(0) walks the
	//     L1Current cursor back to the genesis L1 height (see
	//     state/l1_current.go), kicking off a full proposal-by-proposal
	//     re-anchor from the start of the chain even though the EE is
	//     already at the live tip. The patched 2026-05-15 run on gavin's
	//     devnet showed this firing 5 times for NMC and 1 for reth without
	//     the guard.
	if s.progressTracker.OutOfSync() || blockIDToSync == 0 {
		headNumber = nil
	}
	log.Info(
		"Setting up event synchronization",
		"blockIDToSync", blockIDToSync,
		"outOfSync", s.progressTracker.OutOfSync(),
		"headNumber", headNumber,
	)
	l2Head, err := s.rpc.L2.HeaderByNumber(s.ctx, headNumber)
	if err != nil {
		return fmt.Errorf("failed to get L2 chain head: %w", err)
	}

	log.Info(
		"L2 head information",
		"number", l2Head.Number,
		"hash", l2Head.Hash(),
		"lastSyncedBlockID", s.progressTracker.LastSyncedBlockID(),
		"lastSyncedBlockHash", s.progressTracker.LastSyncedBlockHash(),
	)

	// Reset the L1Current cursor.
	if err := s.state.ResetL1Current(s.ctx, l2Head.Number); err != nil {
		return fmt.Errorf("failed to reset L1 current cursor: %w", err)
	}

	// Reset to the latest L2 execution engine's chain status.
	s.progressTracker.UpdateMeta(l2Head.Number, l2Head.Hash())

	return nil
}

// syncProgressGracePeriod is the block-count tolerance applied by AheadOfHeadToSync.
// The EE is treated as "ahead enough" when it trails the checkpoint head by no more
// than this many blocks, in which case the driver hands off to event-sync rather
// than re-trigger beacon-sync.
//
// Beacon-sync over a small residual gap stalls in practice: the per-trigger Engine
// API overhead (NewPayload + ForkchoiceUpdate + peer discovery for the new pivot)
// dominates the work for gaps in the low single digits, and an EE that has just
// caught up can wait indefinitely without making forward progress on the next
// pivot. Event-sync, which inserts proposals one at a time, closes these short
// gaps reliably. 64 matches gapToResync in the tracker — the threshold below which
// NeedReSync already declines to re-trigger beacon-sync mid-flight — keeping both
// decisions consistent. The previous 1-block tolerance was originally introduced
// to avoid InsertBlockWithoutSetHead in the EE; that concern is still covered by
// a strictly larger tolerance.
const syncProgressGracePeriod uint64 = 64

// AheadOfHeadToSync checks whether the L2 chain is ahead of the head to sync in protocol.
func (s *L2ChainSyncer) AheadOfHeadToSync(heightToSync uint64) bool {
	log.Info(
		"Checking whether the execution engine is ahead of the head to sync",
		"heightToSync", heightToSync,
		"executionEngineHead", s.state.GetL2Head().Number,
	)
	if heightToSync >= syncProgressGracePeriod {
		heightToSync -= syncProgressGracePeriod
	} else if heightToSync > 0 {
		heightToSync = 0
	}

	// If the L2 execution engine's chain is behind of the block head to sync,
	// we should keep the beacon sync.
	if s.state.GetL2Head().Number.Uint64() < heightToSync {
		log.Info(
			"L2 execution engine is behind of the head to sync",
			"heightToSync", heightToSync,
			"executionEngineHead", s.state.GetL2Head().Number,
		)
		return false
	}

	// If the L2 execution engine's chain is ahead of the block head to sync,
	// we can mark the beacon sync progress as finished.
	if s.progressTracker.LastSyncedBlockID() != nil {
		log.Info(
			"L2 execution engine is ahead of the head to sync",
			"heightToSync", heightToSync,
			"executionEngineHead", s.state.GetL2Head().Number,
			"lastSyncedBlockID", s.progressTracker.LastSyncedBlockID(),
		)
		return s.state.GetL2Head().Number.Uint64() >= s.progressTracker.LastSyncedBlockID().Uint64()
	}

	return true
}

// needNewBeaconSyncTriggered checks whether the current L2 execution engine needs to trigger
// another new beacon sync, the following conditions should be met:
// 1. The `--p2p.sync` flag is set.
// 2. The protocol's (last verified) block head is not zero.
// 3. The L2 execution engine's chain is behind of the protocol's (latest verified) block head.
// 4. The L2 execution engine's chain has met a sync timeout issue.
func (s *L2ChainSyncer) needNewBeaconSyncTriggered() (uint64, bool, error) {
	// If the flag is not set or there was a finished beacon sync, we simply return false.
	if !s.p2pSync || s.progressTracker.Finished() {
		return 0, false, nil
	}

	// Refresh the cached L2 head directly from the execution engine before
	// making the beacon-sync decision. The `newHeads` subscription (see
	// driver/state/state.go eventLoop) does not fire for blocks acquired
	// through engine-API-driven beacon-sync backfill, so the cached head can
	// lag the engine's actual head and cause us to repeatedly retrigger
	// beacon sync against a block the engine already has.
	if header, err := s.rpc.L2.HeaderByNumber(s.ctx, nil); err != nil {
		log.Warn("Failed to refresh L2 head for beacon-sync decision", "error", err)
	} else if header != nil {
		s.state.SetL2Head(header)
	}

	head, err := s.rpc.L2CheckPoint.HeadL1Origin(s.ctx)
	if err != nil {
		return 0, false, fmt.Errorf("failed to get L2 checkpoint head L1 origin: %w", err)
	}

	// If the protocol's block head is zero, we simply return false.
	if head.BlockID.Cmp(common.Big0) == 0 {
		return 0, false, nil
	}

	return head.BlockID.Uint64(), !s.AheadOfHeadToSync(head.BlockID.Uint64()) &&
		!s.progressTracker.OutOfSync(), nil
}

// BeaconSyncer returns the inner beacon syncer.
func (s *L2ChainSyncer) BeaconSyncer() *beaconsync.Syncer {
	return s.beaconSyncer
}

// EventSyncer returns the inner event syncer.
func (s *L2ChainSyncer) EventSyncer() *event.Syncer {
	return s.eventSyncer
}

// SetPreconfBlockServer sets the preconfirmation block server.
func (s *L2ChainSyncer) SetPreconfBlockServer(server *preconfBlocks.PreconfBlockAPIServer) {
	s.preconfBlockServer = server
}
