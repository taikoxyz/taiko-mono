package beaconsync

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// Syncer responsible for letting the L2 execution engine catching up with protocol's latest
// verified block through P2P beacon sync.
type Syncer struct {
	ctx             context.Context
	rpc             *rpc.Client
	state           *state.State
	progressTracker *SyncProgressTracker // Sync progress tracker
}

// NewSyncer creates a new syncer instance.
func NewSyncer(
	ctx context.Context,
	rpc *rpc.Client,
	state *state.State,
	progressTracker *SyncProgressTracker,
) *Syncer {
	return &Syncer{ctx, rpc, state, progressTracker}
}

// TriggerBeaconSync triggers the L2 execution engine to start performing a beacon sync, if the
// latest verified block has changed.
func (s *Syncer) TriggerBeaconSync(blockID uint64) error {
	// If we don't need to trigger another beacon sync, just return.
	needResync, err := s.progressTracker.NeedReSync(new(big.Int).SetUint64(blockID))
	if err != nil {
		return err
	}
	if !needResync {
		return nil
	}

	if s.progressTracker.Triggered() && s.progressTracker.lastSyncProgress == nil {
		log.Info(
			"Syncing beacon headers, please check L2 execution engine logs for progress",
			"currentSyncHead", s.progressTracker.LastSyncedBlockID(),
			"newBlockID", blockID,
		)
	}

	headPayload, err := s.getBlockPayload(s.ctx, blockID)
	if err != nil {
		return err
	}

	status, err := s.rpc.L2Engine.NewPayload(s.ctx, headPayload)
	if err != nil {
		return err
	}

	if status.Status != engine.SYNCING && status.Status != engine.VALID {
		return fmt.Errorf("unexpected NewPayload response status: %s", status.Status)
	}

	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(s.ctx, &engine.ForkchoiceStateV1{
		HeadBlockHash: headPayload.BlockHash,
	}, nil)
	if err != nil {
		return err
	}
	if fcRes.PayloadStatus.Status != engine.SYNCING {
		return fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	// Update sync status.
	s.progressTracker.UpdateMeta(new(big.Int).SetUint64(blockID), headPayload.BlockHash)

	log.Info(
		"⛓️ Beacon sync triggered",
		"newHeadID", blockID,
		"newHeadHash", s.progressTracker.LastSyncedBlockHash(),
	)

	return nil
}

// getBlockPayload fetches the block's header, and converts it to an Engine API executable data,
// which will be used to let the node start beacon syncing.
func (s *Syncer) getBlockPayload(ctx context.Context, blockID uint64) (*engine.ExecutableData, error) {
	block, err := s.rpc.L2CheckPoint.BlockByNumber(s.ctx, new(big.Int).SetUint64(blockID))
	if err != nil {
		return nil, err
	}

	log.Info("Block to sync retrieved", "number", block.Number(), "hash", block.Hash())

	return engine.BlockToExecutableData(block, nil, nil, nil).ExecutionPayload, nil
}
