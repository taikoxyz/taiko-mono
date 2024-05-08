package beaconsync

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/eth/downloader"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

// Syncer responsible for letting the L2 execution engine catching up with protocol's latest
// verified block through P2P beacon sync.
type Syncer struct {
	ctx             context.Context
	rpc             *rpc.Client
	state           *state.State
	syncMode        string
	progressTracker *SyncProgressTracker // Sync progress tracker
}

// NewSyncer creates a new syncer instance.
func NewSyncer(
	ctx context.Context,
	rpc *rpc.Client,
	state *state.State,
	syncMode string,
	progressTracker *SyncProgressTracker,
) *Syncer {
	return &Syncer{ctx, rpc, state, syncMode, progressTracker}
}

// TriggerBeaconSync triggers the L2 execution engine to start performing a beacon sync, if the
// latest verified block has changed.
func (s *Syncer) TriggerBeaconSync(blockID uint64) error {
	latestVerifiedHeadPayload, err := s.getVerifiedBlockPayload(s.ctx, blockID)
	if err != nil {
		return err
	}

	if !s.progressTracker.HeadChanged(new(big.Int).SetUint64(blockID)) {
		log.Debug("Verified head has not changed", "blockID", blockID, "hash", latestVerifiedHeadPayload.BlockHash)
		return nil
	}

	if s.progressTracker.Triggered() {
		if s.progressTracker.lastSyncProgress == nil {
			log.Info(
				"Syncing beacon headers, please check L2 execution engine logs for progress",
				"currentSyncHead", s.progressTracker.LastSyncedBlockID(),
				"newBlockID", blockID,
			)
		}
	}

	status, err := s.rpc.L2Engine.NewPayload(s.ctx, latestVerifiedHeadPayload)
	if err != nil {
		return err
	}

	if status.Status != engine.SYNCING && status.Status != engine.VALID {
		return fmt.Errorf("unexpected NewPayload response status: %s", status.Status)
	}

	fcRes, err := s.rpc.L2Engine.ForkchoiceUpdate(s.ctx, &engine.ForkchoiceStateV1{
		HeadBlockHash:      latestVerifiedHeadPayload.BlockHash,
		SafeBlockHash:      latestVerifiedHeadPayload.BlockHash,
		FinalizedBlockHash: latestVerifiedHeadPayload.BlockHash,
	}, nil)
	if err != nil {
		return err
	}
	if fcRes.PayloadStatus.Status != engine.SYNCING {
		return fmt.Errorf("unexpected ForkchoiceUpdate response status: %s", fcRes.PayloadStatus.Status)
	}

	// Update sync status.
	s.progressTracker.UpdateMeta(new(big.Int).SetUint64(blockID), latestVerifiedHeadPayload.BlockHash)

	log.Info(
		"⛓️ Beacon sync triggered",
		"newHeadID", blockID,
		"newHeadHash", s.progressTracker.LastSyncedBlockHash(),
	)

	return nil
}

// getVerifiedBlockPayload fetches the latest verified block's header, and converts it to an Engine API executable data,
// which will be used to let the node start beacon syncing.
func (s *Syncer) getVerifiedBlockPayload(ctx context.Context, blockID uint64) (*engine.ExecutableData, error) {
	header, err := s.rpc.L2CheckPoint.HeaderByNumber(s.ctx, new(big.Int).SetUint64(blockID))
	if err != nil {
		return nil, err
	}

	if s.syncMode == downloader.FullSync.String() {
		blockInfo, err := s.rpc.GetL2BlockInfo(ctx, new(big.Int).SetUint64(blockID))
		if err != nil {
			return nil, err
		}
		ts, err := s.rpc.GetTransition(ctx, new(big.Int).SetUint64(blockInfo.BlockId), blockInfo.VerifiedTransitionId)
		if err != nil {
			return nil, err
		}
		if header.Hash() != ts.BlockHash {
			return nil, fmt.Errorf(
				"latest verified block hash mismatch: %s != %s",
				header.Hash(),
				common.BytesToHash(ts.BlockHash[:]),
			)
		}
	}

	log.Info("Latest verified block header retrieved", "hash", header.Hash())

	return encoding.ToExecutableData(header), nil
}
