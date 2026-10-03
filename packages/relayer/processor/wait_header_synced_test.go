package processor

import (
	"context"
	"errors"
	"math/big"
	"sync"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestWaitHeaderSyncedUsesCheckpointSaved(t *testing.T) {
	ethc := &mock.EthClient{}
	repo := &mock.EventRepository{}

	p := &Processor{
		eventRepo:                 repo,
		headerSyncIntervalSeconds: 1,
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, ethc, 2, 1)
	if err != nil {
		t.Fatalf("waitHeaderSynced err: %v", err)
	}

	if ev == nil || ev.ChainID != mock.MockChainID.Int64() {
		t.Fatalf("unexpected event: %#v", ev)
	}
}

// chainIDErrClient fails the chain ID lookup, which is the first thing the wait needs.
type chainIDErrClient struct {
	mock.EthClient
}

func (c *chainIDErrClient) ChainID(_ context.Context) (*big.Int, error) {
	return nil, errors.New("dial tcp: connect: connection refused")
}

func TestWaitHeaderSyncedReturnsTheChainIDError(t *testing.T) {
	p := newTestProcessor(false)

	// Without a chain ID the checkpoint lookup would be against the wrong chain, so this has to
	// fail rather than fall through to the poll loop.
	ev, err := p.waitHeaderSynced(context.Background(), &chainIDErrClient{}, 2, 1)

	require.ErrorContains(t, err, "connection refused")
	assert.Nil(t, ev)
}

func TestWaitHeaderSyncedReturnsTheRepositoryError(t *testing.T) {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		return nil, errors.New("db is down")
	}

	p := newTestProcessor(false)
	p.eventRepo = repo

	ev, err := p.waitHeaderSynced(context.Background(), &mock.EthClient{}, 2, 1)

	require.ErrorContains(t, err, "db is down")
	assert.Nil(t, ev)
}

func TestWaitHeaderSyncedPollsUntilTheCheckpointAppears(t *testing.T) {
	var calls int

	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		calls++

		// Not synced yet on the first look. The proof cannot be generated until it is, so the
		// wait has to keep polling rather than give up.
		if calls < 3 {
			return nil, nil
		}

		return &relayer.Event{BlockID: 42}, nil
	}

	p := newTestProcessor(false)
	p.eventRepo = repo
	p.headerSyncIntervalSeconds = 1

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, &mock.EthClient{}, 2, 1)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, uint64(42), ev.BlockID)
	assert.Equal(t, 3, calls)
}

func TestWaitHeaderSyncedReturnsTheRepositoryErrorFromThePollLoop(t *testing.T) {
	var calls int

	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		calls++

		if calls == 1 {
			return nil, nil
		}

		return nil, errors.New("db went away")
	}

	p := newTestProcessor(false)
	p.eventRepo = repo
	p.headerSyncIntervalSeconds = 1

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, &mock.EthClient{}, 2, 1)

	require.ErrorContains(t, err, "db went away")
	assert.Nil(t, ev)
}

// recordingRevealer records the blocks it is asked to reveal and returns the queued errors in
// order, then nil.
type recordingRevealer struct {
	mu    sync.Mutex
	calls []uint64
	errs  []error
}

func (r *recordingRevealer) reveal(_ context.Context, minL1Block uint64) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.calls = append(r.calls, minL1Block)

	if len(r.errs) == 0 {
		return nil
	}

	err := r.errs[0]
	r.errs = r.errs[1:]

	return err
}

// cancellingRevealer stands for a reveal interrupted by shutdown: it cancels the processor's
// context and fails with the context's error.
type cancellingRevealer struct {
	cancel context.CancelFunc
}

func (r *cancellingRevealer) reveal(ctx context.Context, _ uint64) error {
	r.cancel()

	return ctx.Err()
}

func TestWaitHeaderSyncedDoesNotRevealAnIndexedCheckpoint(t *testing.T) {
	revealer := &recordingRevealer{}

	p := newTestProcessor(false)
	p.checkpointRevealer = revealer

	ev, err := p.waitHeaderSynced(context.Background(), &mock.EthClient{}, 2, 1)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Empty(t, revealer.calls)
}

func TestWaitHeaderSyncedRevealsWhileWaiting(t *testing.T) {
	var lookups int

	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		lookups++

		// After Etna nothing saves the checkpoint until a reveal does, and the indexer stores
		// the revealed one a little later.
		if lookups < 3 {
			return nil, nil
		}

		return &relayer.Event{BlockID: 42}, nil
	}

	// A failed reveal must not end the wait: the message keeps waiting and the next attempt may
	// succeed.
	revealer := &recordingRevealer{errs: []error{errors.New("sending revealCheckpoint: nonce too low")}}

	p := newTestProcessor(false)
	p.eventRepo = repo
	p.headerSyncIntervalSeconds = 1
	p.checkpointRevealer = revealer

	errorsBefore := testutil.ToFloat64(relayer.CheckpointRevealErrors)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, &mock.EthClient{}, 2, 7)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, uint64(42), ev.BlockID)
	assert.Equal(t, []uint64{7, 7}, revealer.calls)
	assert.Equal(t, errorsBefore+1, testutil.ToFloat64(relayer.CheckpointRevealErrors))
}

func TestWaitHeaderSyncedDoesNotCountRevealsInterruptedByShutdown(t *testing.T) {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		return nil, nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	p := newTestProcessor(false)
	p.eventRepo = repo
	p.headerSyncIntervalSeconds = 1
	p.checkpointRevealer = &cancellingRevealer{cancel: cancel}

	errorsBefore := testutil.ToFloat64(relayer.CheckpointRevealErrors)

	ev, err := p.waitHeaderSynced(ctx, &mock.EthClient{}, 2, 1)

	require.ErrorIs(t, err, context.Canceled)
	assert.Nil(t, ev)
	assert.Equal(t, errorsBefore, testutil.ToFloat64(relayer.CheckpointRevealErrors))
}

func TestWaitHeaderSyncedGivesUpWhenTheContextIsCancelled(t *testing.T) {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		return nil, nil
	}

	p := newTestProcessor(false)
	p.eventRepo = repo
	p.headerSyncIntervalSeconds = 1

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	// A shutdown must not be blocked by a checkpoint that is never going to arrive.
	ev, err := p.waitHeaderSynced(ctx, &mock.EthClient{}, 2, 1)

	require.ErrorIs(t, err, context.DeadlineExceeded)
	assert.Nil(t, ev)
}
