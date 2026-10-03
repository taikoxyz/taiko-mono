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

// headClient reports head as the L1 head and counts the BlockNumber calls. Like recordingRevealer,
// it answers with the queued errors in order first, where a nil entry is a call that succeeds.
type headClient struct {
	mock.EthClient
	head  uint64
	errs  []error
	calls int
}

func (c *headClient) BlockNumber(_ context.Context) (uint64, error) {
	c.calls++

	if len(c.errs) > 0 {
		err := c.errs[0]
		c.errs = c.errs[1:]

		if err != nil {
			return 0, err
		}
	}

	return c.head, nil
}

// checkpointIndex stands in for the indexed CheckpointSaved rows: its lookups find nothing the
// first misses times and event after that. It records the block number each lookup asks for.
type checkpointIndex struct {
	misses  int
	event   *relayer.Event
	lookups []uint64
}

// repository returns an event repository whose checkpoint lookups go to the index.
func (i *checkpointIndex) repository() *mock.EventRepository {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, blockNumber uint64,
	) (*relayer.Event, error) {
		i.lookups = append(i.lookups, blockNumber)

		if len(i.lookups) <= i.misses {
			return nil, nil
		}

		return i.event, nil
	}

	return repo
}

func TestWaitHeaderSyncedDoesNotReadTheL1HeadWithoutReveals(t *testing.T) {
	index := &checkpointIndex{misses: 1, event: &relayer.Event{BlockID: 950}}
	client := &headClient{head: 1_000}

	p := newTestProcessor(false)
	p.eventRepo = index.repository()
	p.headerSyncIntervalSeconds = 1

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// With checkpoint reveal off the wait is unchanged: it asks for the message's own block and
	// never reads the head.
	ev, err := p.waitHeaderSynced(ctx, client, 2, 800)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, []uint64{800, 800}, index.lookups)
	assert.Zero(t, client.calls)
}

func TestWaitHeaderSyncedRequiresARecentCheckpointWithReveals(t *testing.T) {
	// Only checkpoints below 904 are indexed. One of them may still cover the message's block 800,
	// but it is more than maxCheckpointAge blocks behind the head of 1,000, where the L1 node may
	// no longer serve a proof. The checkpoint the revealer is asked for is indexed by the first tick.
	index := &checkpointIndex{misses: 1, event: &relayer.Event{BlockID: 950}}
	client := &headClient{head: 1_000}
	revealer := &recordingRevealer{}

	p := newTestProcessor(false)
	p.eventRepo = index.repository()
	p.headerSyncIntervalSeconds = 1
	p.checkpointRevealer = revealer

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, client, 2, 800)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, uint64(950), ev.BlockID)
	assert.Equal(t, []uint64{904, 904}, index.lookups)
	assert.Equal(t, []uint64{904}, revealer.calls)
	assert.Equal(t, 2, client.calls, "the head is read before the first lookup and again on the tick")
}

func TestWaitHeaderSyncedAcceptsTheMessageBlockWhenItIsRecent(t *testing.T) {
	index := &checkpointIndex{event: &relayer.Event{BlockID: 950}}

	p := newTestProcessor(false)
	p.eventRepo = index.repository()
	p.checkpointRevealer = &recordingRevealer{}

	// Block 950 is within maxCheckpointAge of the head, so a checkpoint covering it is recent enough.
	ev, err := p.waitHeaderSynced(context.Background(), &headClient{head: 1_000}, 2, 950)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, []uint64{950}, index.lookups)
}

func TestWaitHeaderSyncedAcceptsTheMessageBlockOnAShortChain(t *testing.T) {
	index := &checkpointIndex{event: &relayer.Event{BlockID: 7}}

	p := newTestProcessor(false)
	p.eventRepo = index.repository()
	p.checkpointRevealer = &recordingRevealer{}

	// The whole chain is shorter than maxCheckpointAge blocks, so every checkpoint is recent enough.
	ev, err := p.waitHeaderSynced(context.Background(), &headClient{head: 50}, 2, 7)

	require.NoError(t, err)
	require.NotNil(t, ev)
	assert.Equal(t, []uint64{7}, index.lookups)
}

func TestWaitHeaderSyncedHandlesL1HeadErrors(t *testing.T) {
	t.Run("before the first lookup", func(t *testing.T) {
		index := &checkpointIndex{event: &relayer.Event{BlockID: 950}}

		p := newTestProcessor(false)
		p.eventRepo = index.repository()
		p.checkpointRevealer = &recordingRevealer{}

		// Without the head the wait cannot tell which checkpoints are recent enough.
		client := &headClient{errs: []error{errors.New("dial tcp: connect: connection refused")}}
		ev, err := p.waitHeaderSynced(context.Background(), client, 2, 800)

		require.ErrorContains(t, err, "connection refused")
		assert.Nil(t, ev)
		assert.Empty(t, index.lookups)
	})

	t.Run("while polling", func(t *testing.T) {
		index := &checkpointIndex{misses: 1, event: &relayer.Event{BlockID: 950}}

		// The first read succeeds and the L1 node is unreachable by the first tick. Falling back to
		// the message's block would accept a stale checkpoint, so the wait keeps asking for 904.
		client := &headClient{head: 1_000, errs: []error{nil, errors.New("dial tcp: connect: connection refused")}}

		p := newTestProcessor(false)
		p.eventRepo = index.repository()
		p.headerSyncIntervalSeconds = 1
		p.checkpointRevealer = &recordingRevealer{}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		ev, err := p.waitHeaderSynced(ctx, client, 2, 800)

		require.NoError(t, err)
		require.NotNil(t, ev)
		assert.Equal(t, uint64(950), ev.BlockID)
		assert.Equal(t, []uint64{904, 904}, index.lookups)
		assert.Equal(t, 2, client.calls)
	})
}
