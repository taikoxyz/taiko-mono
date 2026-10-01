package beaconsync

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
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
		return fmt.Errorf("failed to check if resync is needed: %w", err)
	}
	if !needResync {
		return nil
	}

	if s.progressTracker.Triggered() && s.progressTracker.LastSyncProgress() == nil {
		log.Info(
			"Syncing beacon headers, please check L2 execution engine logs for progress",
			"currentSyncHead", s.progressTracker.LastSyncedBlockID(),
			"newBlockID", blockID,
		)
	}

	headPayload, headBeaconRoot, err := s.getBlockPayload(s.ctx, blockID)
	if err != nil {
		return fmt.Errorf("failed to get block payload: %w", err)
	}

	var status *engine.PayloadStatusV1
	if headBeaconRoot != nil {
		status, err = s.rpc.L2Engine.NewPayloadV4(s.ctx, headPayload, *headBeaconRoot)
	} else {
		status, err = s.rpc.L2Engine.NewPayload(s.ctx, headPayload)
	}
	if err != nil {
		return fmt.Errorf("failed to call NewPayload: %w", err)
	}

	if status.Status != engine.SYNCING && status.Status != engine.VALID {
		return fmt.Errorf("unexpected NewPayload response status: %s", status.Status)
	}

	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(s.ctx, &engine.ForkchoiceStateV1{
		HeadBlockHash: headPayload.BlockHash,
	}, nil)
	if err != nil {
		return fmt.Errorf("failed to call ForkchoiceUpdate: %w", err)
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
// which will be used to let the node start beacon syncing. For an Etna block it also returns the
// block's parentBeaconBlockRoot, which engine_newPayloadV4 takes as a separate parameter.
func (s *Syncer) getBlockPayload(ctx context.Context, blockID uint64) (*engine.ExecutableData, *common.Hash, error) {
	block, err := s.rpc.L2CheckPoint.BlockByNumber(s.ctx, new(big.Int).SetUint64(blockID))
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get block %d: %w", blockID, err)
	}

	log.Info("Block to sync retrieved", "number", block.Number(), "hash", block.Hash())

	// From Unzen on, the header difficulty records the block's zk gas. It is passed explicitly because
	// engine.BlockToExecutableData only reports a non-zero value, and an empty Etna block uses no zk gas.
	envelope := engine.BlockToExecutableData(block, nil, nil, nil)
	payload, err := rpc.NormalizeExecutableData(s.rpc.L2.ChainID, envelope.ExecutionPayload, block.Difficulty())
	if err != nil {
		return nil, nil, err
	}

	if !rpc.IsEtna(s.rpc.L2.ChainID, block.Time()) {
		return payload, nil, nil
	}
	if block.BeaconRoot() == nil {
		return nil, nil, fmt.Errorf("missing parentBeaconBlockRoot in Etna block %d", blockID)
	}
	return payload, block.BeaconRoot(), nil
}
