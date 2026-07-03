package beaconsync

import (
	"context"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	syncProgressCheckInterval = 12 * time.Second
	gapToResync               = new(big.Int).SetUint64(64)
)

// SyncProgressTracker is responsible for tracking the L2 execution engine's sync progress, after
// a beacon sync is triggered, and check whether the L2 execution is not able to sync through P2P (due to no
// connected peer or some other reasons).
type SyncProgressTracker struct {
	// RPC client
	client *rpc.EthClient

	// Meta data
	triggered           bool
	lastSyncedBlockID   *big.Int
	lastSyncedBlockHash common.Hash

	// Sync progress tracking
	lastSyncProgress *ethereum.SyncProgress
	ticker           *time.Ticker

	// A marker to indicate whether the beacon sync has been finished.
	finished bool

	// Read-write mutex
	mutex sync.RWMutex
}

// NewSyncProgressTracker creates a new SyncProgressTracker instance.
func NewSyncProgressTracker(c *rpc.EthClient) *SyncProgressTracker {
	return &SyncProgressTracker{client: c, ticker: time.NewTicker(syncProgressCheckInterval)}
}

// Track starts the inner event loop, to monitor the sync progress.
func (t *SyncProgressTracker) Track(ctx context.Context) {
	defer t.ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.ticker.C:
			t.track(ctx)
		}
	}
}

// track is the internal implementation of MonitorSyncProgress, tries to
// track the L2 execution engine's beacon sync progress.
func (t *SyncProgressTracker) track(ctx context.Context) {
	t.mutex.Lock()
	defer t.mutex.Unlock()

	if !t.triggered {
		log.Debug("Beacon sync not triggered")
		return
	}

	if t.finished {
		return
	}

	progress, err := t.client.SyncProgress(ctx)
	if err != nil {
		log.Error("Get L2 execution engine sync progress error", "error", err)
		return
	}

	if progress != nil {
		log.Info("L2 execution engine sync progress", "progress", progress)
	}

	if progress == nil {
		headHeight, err := t.client.BlockNumber(ctx)
		if err != nil {
			log.Error("Get L2 execution engine head height error", "error", err)
			return
		}

		if new(big.Int).SetUint64(headHeight).Cmp(t.lastSyncedBlockID) >= 0 {
			log.Info(
				"L2 execution engine has finished the P2P sync work, all verified blocks synced, "+
					"will switch to insert pending blocks one by one",
				"lastSyncedBlockID", t.lastSyncedBlockID,
				"lastSyncedBlockHash", t.lastSyncedBlockHash,
			)
			return
		}

		log.Info("L2 execution engine has not started P2P syncing yet")
	}

	t.lastSyncProgress = progress
}

// UpdateMeta updates the inner beacon sync metadata.
func (t *SyncProgressTracker) UpdateMeta(id *big.Int, blockHash common.Hash) {
	t.mutex.Lock()
	defer t.mutex.Unlock()

	log.Debug("Update sync progress tracker meta", "id", id, "hash", blockHash)

	t.triggered = true
	t.lastSyncedBlockID = id
	t.lastSyncedBlockHash = blockHash
}

// ClearMeta cleans the inner beacon sync metadata.
func (t *SyncProgressTracker) ClearMeta() {
	t.mutex.Lock()
	defer t.mutex.Unlock()

	log.Debug("Clear sync progress tracker meta")

	t.triggered = false
	t.lastSyncedBlockID = nil
	t.lastSyncedBlockHash = common.Hash{}
}

// NeedReSync checks if a new beacon sync request will be needed:
// 1, if the beacon sync has not been triggered yet
// 2, if there is 64 blocks gap between the last head to sync and the new block
// 3, if the last triggered beacon sync is finished, but there are still new blocks
func (t *SyncProgressTracker) NeedReSync(newID *big.Int) (bool, error) {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	// If the beacon sync has not been triggered yet, we will simply trigger it.
	if !t.triggered {
		return true, nil
	}

	if t.lastSyncedBlockID == nil {
		return true, nil
	}

	// If the new block is 64 blocks ahead of the last synced block, we will trigger a new beacon sync.
	if new(big.Int).Sub(newID, t.lastSyncedBlockID).Cmp(gapToResync) >= 0 {
		return true, nil
	}

	head, err := t.client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		return false, err
	}

	// If the last triggered beacon sync is finished, we will trigger a new beacon sync.
	if t.lastSyncProgress != nil &&
		(t.lastSyncProgress.CurrentBlock >= t.lastSyncedBlockID.Uint64() ||
			head.Number.Uint64() >= t.lastSyncedBlockID.Uint64()) {
		return true, nil
	}

	return false, nil
}

// Triggered returns tracker.triggered.
func (t *SyncProgressTracker) Triggered() bool {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	return t.triggered
}

// LastSyncedBlockID returns tracker.lastSyncedBlockID.
func (t *SyncProgressTracker) LastSyncedBlockID() *big.Int {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	if t.lastSyncedBlockID == nil {
		return nil
	}

	return new(big.Int).Set(t.lastSyncedBlockID)
}

// LastSyncedBlockHash returns tracker.lastSyncedBlockHash.
func (t *SyncProgressTracker) LastSyncedBlockHash() common.Hash {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	return t.lastSyncedBlockHash
}

// LastSyncProgress returns tracker.lastSyncProgress.
func (t *SyncProgressTracker) LastSyncProgress() *ethereum.SyncProgress {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	return t.lastSyncProgress
}

// MarkFinished marks the current beacon sync as finished.
func (t *SyncProgressTracker) MarkFinished() {
	t.mutex.Lock()
	defer t.mutex.Unlock()

	t.finished = true
}

// Finished returns whether the current beacon sync has been finished.
func (t *SyncProgressTracker) Finished() bool {
	t.mutex.RLock()
	defer t.mutex.RUnlock()

	return t.finished
}
