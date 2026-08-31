package blocksinserter

import (
	"context"
	"math/big"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
)

func TestCheckpointCacheReturnsCachedValueWithoutReload(t *testing.T) {
	cache := newCheckpointCache(5 * time.Minute)

	var calls atomic.Int32
	loader := func(context.Context) (*verifiedCheckpoint, error) {
		calls.Add(1)
		return &verifiedCheckpoint{
			BlockID:   big.NewInt(11),
			BlockHash: common.HexToHash("0x11"),
		}, nil
	}

	checkpoint, err := cache.getOrFetch(context.Background(), loader)
	if err != nil {
		t.Fatalf("getOrFetch() error = %v", err)
	}
	if checkpoint == nil || checkpoint.BlockID.Cmp(big.NewInt(11)) != 0 {
		t.Fatalf("unexpected checkpoint after first fetch: %+v", checkpoint)
	}

	checkpoint, err = cache.getOrFetch(context.Background(), loader)
	if err != nil {
		t.Fatalf("getOrFetch() second call error = %v", err)
	}
	if checkpoint == nil || checkpoint.BlockID.Cmp(big.NewInt(11)) != 0 {
		t.Fatalf("unexpected checkpoint after second fetch: %+v", checkpoint)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("expected loader to be called once, got %d", got)
	}
}

func TestCheckpointCacheRefreshesStaleValueAsynchronously(t *testing.T) {
	cache := newCheckpointCache(0)
	cache.store(&verifiedCheckpoint{
		BlockID:   big.NewInt(7),
		BlockHash: common.HexToHash("0x07"),
	})

	var calls atomic.Int32
	releaseRefresh := make(chan struct{})
	loader := func(context.Context) (*verifiedCheckpoint, error) {
		calls.Add(1)
		<-releaseRefresh
		return &verifiedCheckpoint{
			BlockID:   big.NewInt(8),
			BlockHash: common.HexToHash("0x08"),
		}, nil
	}

	checkpoint, err := cache.getOrFetch(context.Background(), loader)
	if err != nil {
		t.Fatalf("getOrFetch() error = %v", err)
	}
	if checkpoint == nil || checkpoint.BlockID.Cmp(big.NewInt(7)) != 0 {
		t.Fatalf("expected stale checkpoint to be returned immediately, got %+v", checkpoint)
	}

	refreshStarted := false
	startDeadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(startDeadline) {
		if calls.Load() == 1 {
			refreshStarted = true
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !refreshStarted {
		t.Fatalf("expected async refresh to start once, got %d", calls.Load())
	}

	close(releaseRefresh)

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		snapshot, _ := cache.load()
		if snapshot != nil && snapshot.BlockID.Cmp(big.NewInt(8)) == 0 {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}

	lastSnapshot, _ := cache.load()
	t.Fatalf("timed out waiting for cache refresh, last snapshot = %+v", lastSnapshot)
}
