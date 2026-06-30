package blocksinserter

import (
	"context"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/sync/singleflight"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const checkpointCacheTTL = 3 * time.Minute // Approximate half an epoch based on one proposal per epoch.

// checkpointLoader loads the latest checkpoint from the underlying RPC source.
type checkpointLoader func(context.Context) (*verifiedCheckpoint, error)

// checkpointCache stores the latest checkpoint snapshot and refresh metadata.
type checkpointCache struct {
	maxAge         time.Duration
	mu             sync.RWMutex
	checkpoint     *verifiedCheckpoint
	updatedAt      time.Time
	refreshPending atomic.Bool
	refreshGroup   singleflight.Group
}

var (
	// Keep one process-wide cache. We only need the latest checkpoint snapshot.
	checkpointCacheSingleton = newCheckpointCache(checkpointCacheTTL)
)

// newCheckpointCache creates a cache instance with the given staleness threshold.
func newCheckpointCache(maxAge time.Duration) *checkpointCache {
	return &checkpointCache{maxAge: maxAge}
}

// getOrFetch returns the current checkpoint snapshot, refreshing it synchronously on cache miss.
func (c *checkpointCache) getOrFetch(ctx context.Context, loader checkpointLoader) (*verifiedCheckpoint, error) {
	snapshot, stale := c.load()
	if snapshot != nil {
		if stale {
			// Serve the current snapshot immediately and refresh it in the background.
			c.refreshAsync(loader)
		}
		return snapshot, nil
	}

	return c.refreshSync(ctx, loader)
}

// load returns the cached checkpoint together with whether the snapshot is stale.
func (c *checkpointCache) load() (*verifiedCheckpoint, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.checkpoint == nil {
		return nil, false
	}

	return c.checkpoint, time.Since(c.updatedAt) >= c.maxAge
}

// store updates the cache when the new checkpoint does not move backwards.
func (c *checkpointCache) store(checkpoint *verifiedCheckpoint) {
	if checkpoint == nil {
		return
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	if isOlderCheckpoint(checkpoint, c.checkpoint) {
		return
	}

	c.checkpoint = checkpoint
	c.updatedAt = time.Now()
}

// refreshAsync triggers a background refresh when one is not already running.
func (c *checkpointCache) refreshAsync(loader checkpointLoader) {
	if !c.refreshPending.CompareAndSwap(false, true) {
		return
	}

	go func() {
		defer c.refreshPending.Store(false)

		ctx, cancel := context.WithTimeout(context.Background(), rpc.DefaultRpcTimeout)
		defer cancel()

		_, _ = c.refreshSync(ctx, loader)
	}()
}

// refreshSync refreshes the checkpoint through singleflight to deduplicate concurrent loads.
func (c *checkpointCache) refreshSync(ctx context.Context, loader checkpointLoader) (*verifiedCheckpoint, error) {
	value, err, _ := c.refreshGroup.Do("checkpoint", func() (any, error) {
		checkpoint, err := loader(ctx)
		if err != nil {
			return nil, err
		}

		if checkpoint != nil {
			c.store(checkpoint)
		}

		return checkpoint, nil
	})
	if err != nil {
		return nil, err
	}
	if value == nil {
		return nil, nil
	}

	return value.(*verifiedCheckpoint), nil
}

// getCheckpointCache returns the process-wide checkpoint cache.
func getCheckpointCache() *checkpointCache {
	return checkpointCacheSingleton
}

// getCheckpoint returns the latest cached or freshly loaded checkpoint.
// The caller must pass the rpc.Client for the target L1 environment. In particular,
// cli must not come from a different L1 network, because the cached checkpoint is only
// valid for the chain context behind that client.
func getCheckpoint(ctx context.Context, cli *rpc.Client) (*verifiedCheckpoint, error) {
	return getCheckpointCache().getOrFetch(ctx, func(ctx context.Context) (*verifiedCheckpoint, error) {
		return tryLastFinalizedCheckpoint(
			ctx,
			nil,
			cli.GetCoreState,
			cli.L2Engine.LastBlockIDByBatchID,
			cli.L2.HeaderByNumber,
		)
	})
}

// isOlderCheckpoint reports whether the new checkpoint would move the cache backwards.
func isOlderCheckpoint(newCheckpoint, currentCheckpoint *verifiedCheckpoint) bool {
	if newCheckpoint == nil ||
		newCheckpoint.BlockID == nil ||
		currentCheckpoint == nil ||
		currentCheckpoint.BlockID == nil {
		return false
	}

	// Ignore refresh results that would move the cached checkpoint backwards.
	return newCheckpoint.BlockID.Cmp(currentCheckpoint.BlockID) < 0
}
