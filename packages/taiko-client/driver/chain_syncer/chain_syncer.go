package chainsyncer

import (
	"context"
	"fmt"
	"math/big"
	"net/url"
	"time"

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
		if err := s.beaconSyncer.TriggerBeaconSync(blockIDToSync); err != nil {
			return fmt.Errorf("trigger beacon sync error: %w", err)
		}

		return nil
	}

	// Mark the beacon sync progress as finished, to make sure that
	// we will only check and trigger P2P sync progress once right after the driver starts.
	s.progressTracker.MarkFinished()

	// We have triggered at least a beacon sync in L2 execution engine, we should reset the L1Current
	// cursor at first, then try to import the pending preconfirmation blocks from the cache, before
	// start inserting pending L2 batches one by one.
	if s.progressTracker.Triggered() {
		log.Info(
			"Switch to insert pending batches one by one",
			"p2pEnabled", s.p2pSync,
			"p2pOutOfSync", s.progressTracker.OutOfSync(),
		)

		if err := s.SetUpEventSync(blockIDToSync); err != nil {
			return fmt.Errorf("failed to set up event synchronization: %w", err)
		}
	}

	// Mark the preconfirmation block server as ready to insert blocks.
	if s.preconfBlockServer != nil {
		log.Info("Mark preconfirmation block server as ready to insert blocks")
		s.preconfBlockServer.SetSyncReady(true)
	}

	// Insert the proposed batches one by one.
	return s.eventSyncer.ProcessL1Blocks(s.ctx)
}

// SetUpEventSync resets the L1Current cursor to the latest L2 execution engine's chain head,
// and tries to import the pending preconfirmation blocks from the cache, this method should only be
// called after the L2 execution engine's chain has just finished a beacon sync.
func (s *L2ChainSyncer) SetUpEventSync(blockIDToSync uint64) error {
	var headNumber = new(big.Int).SetUint64(blockIDToSync)
	if s.progressTracker.OutOfSync() {
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

	// If the preconfirmation block server is enabled, we should try to insert the pending
	// preconfirmation blocks from the cache.
	if s.preconfBlockServer != nil {
		log.Info(
			"Try importing pending preconfirmation blocks",
			"currentL2HeadNumber", l2Head.Number,
			"currentL2HeadHash", l2Head.Hash(),
		)
		if err := s.preconfBlockServer.ImportPendingBlocksFromCache(s.ctx); err != nil {
			log.Warn(
				"Failed to import the pending preconfirmation blocks from cache, skip the import",
				"currentL2HeadNumber", l2Head.Number,
				"currentL2HeadHash", l2Head.Hash(),
				"error", err,
			)
		}
	}

	return nil
}

// AheadOfHeadToSync checks whether the L2 chain is ahead of the head to sync in protocol.
func (s *L2ChainSyncer) AheadOfHeadToSync(heightToSync uint64) bool {
	log.Info(
		"Checking whether the execution engine is ahead of the head to sync",
		"heightToSync", heightToSync,
		"executionEngineHead", s.state.GetL2Head().Number,
	)
	if heightToSync > 0 {
		// If head height is equal to L2 execution engine's synced head height minus one,
		// we also mark the triggered P2P sync progress as finished to prevent a potential `InsertBlockWithoutSetHead` in
		// execution engine, which may cause errors since we do not pass all transactions in ExecutePayload when calling
		// `NewPayloadV1`.
		heightToSync--
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
