package processor

import (
	"context"
	"errors"
	"math"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestWaitProofTargetUsesCheckpointSaved(t *testing.T) {
	ethc := &mock.EthClient{}
	repo := &mock.EventRepository{}

	p := &Processor{
		eventRepo:                 repo,
		headerSyncIntervalSeconds: 1,
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	target, err := p.waitProofTarget(ctx, ethc, 2, 1)
	if err != nil {
		t.Fatalf("waitProofTarget err: %v", err)
	}

	if target == nil || target.etna != nil || target.checkpoint == nil ||
		target.checkpoint.ChainID != mock.MockChainID.Int64() {
		t.Fatalf("unexpected target: %#v", target)
	}
}

// chainIDErrClient fails the chain ID lookup, which is the first thing the wait needs.
type chainIDErrClient struct {
	mock.EthClient
}

func (c *chainIDErrClient) ChainID(_ context.Context) (*big.Int, error) {
	return nil, errors.New("dial tcp: connect: connection refused")
}

func TestWaitProofTargetReturnsTheChainIDError(t *testing.T) {
	p := newTestProcessor(false)

	// Without a chain ID the checkpoint lookup would be against the wrong chain, so this has to
	// fail rather than fall through to the poll loop.
	ev, err := p.waitProofTarget(context.Background(), &chainIDErrClient{}, 2, 1)

	require.ErrorContains(t, err, "connection refused")
	assert.Nil(t, ev)
}

func TestWaitProofTargetReturnsTheRepositoryError(t *testing.T) {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		return nil, errors.New("db is down")
	}

	p := newTestProcessor(false)
	p.eventRepo = repo

	ev, err := p.waitProofTarget(context.Background(), &mock.EthClient{}, 2, 1)

	require.ErrorContains(t, err, "db is down")
	assert.Nil(t, ev)
}

func TestWaitProofTargetPollsUntilTheCheckpointAppears(t *testing.T) {
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

	ev, err := p.waitProofTarget(ctx, &mock.EthClient{}, 2, 1)

	require.NoError(t, err)
	require.NotNil(t, ev)
	require.NotNil(t, ev.checkpoint)
	assert.Equal(t, uint64(42), ev.checkpoint.BlockID)
	assert.Equal(t, 3, calls)
}

func TestWaitProofTargetReturnsTheRepositoryErrorFromThePollLoop(t *testing.T) {
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

	ev, err := p.waitProofTarget(ctx, &mock.EthClient{}, 2, 1)

	require.ErrorContains(t, err, "db went away")
	assert.Nil(t, ev)
}

func TestWaitProofTargetGivesUpWhenTheContextIsCancelled(t *testing.T) {
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
	ev, err := p.waitProofTarget(ctx, &mock.EthClient{}, 2, 1)

	require.ErrorIs(t, err, context.DeadlineExceeded)
	assert.Nil(t, ev)
}

// testContext returns a context that ends the test's wait after five seconds, so a proof that
// can never be built fails the test instead of hanging it.
func testContext(t *testing.T) context.Context {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)

	return ctx
}

// countingCheckpointRepo returns a checkpoint row when found is true and counts the lookups.
func countingCheckpointRepo(found bool, calls *int) *mock.EventRepository {
	repo := &mock.EventRepository{}
	repo.CheckpointSyncedEventByBlockNumberOrGreaterFunc = func(
		_ context.Context, _, _, _ uint64,
	) (*relayer.Event, error) {
		*calls++

		if !found {
			return nil, nil
		}

		return &relayer.Event{BlockID: 7}, nil
	}

	return repo
}

func TestWaitProofTargetIgnoresTheL2HeadWithoutAnEtnaTimestamp(t *testing.T) {
	p, l2, l1, anchor := etnaFixture(testEtnaTimestamp)
	anchor.etnaErr = errors.New("execution reverted")

	var calls int
	p.eventRepo = countingCheckpointRepo(true, &calls)

	target, err := p.waitProofTarget(testContext(t), l1, 2, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, target)
	require.NotNil(t, target.checkpoint)
	assert.Nil(t, target.etna)
	assert.Equal(t, 1, calls)
	// An L2→L1 processor reaches the same branch through the Inbox's revert: it never reads the
	// L1 head as if it were an L2 head.
	assert.Zero(t, l2.reads)
}

func TestWaitProofTargetUsesCheckpointsUntilTheForkGuard(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	// The head and the clock are more than etnaForkGuardSeconds before the fork.
	head := etnaHeader(10, testEtnaTimestamp-etnaForkGuardSeconds-1, testAnchorBase, testRoot(0))
	l2.heads = []*types.Header{head}
	atTime(p, head.Time)

	var calls int
	p.eventRepo = countingCheckpointRepo(true, &calls)

	target, err := p.waitProofTarget(testContext(t), l1, 2, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, target)
	require.NotNil(t, target.checkpoint)
	assert.Equal(t, uint64(7), target.checkpoint.BlockID)
	assert.Equal(t, 1, calls)
}

func TestWaitProofTargetBuildsNothingWithinTheForkGuard(t *testing.T) {
	tests := []struct {
		name string
		// head and clock are how many seconds before the fork the L2 head and the wall clock are.
		head  uint64
		clock uint64
	}{
		{name: "at the guard", head: etnaForkGuardSeconds, clock: etnaForkGuardSeconds},
		{name: "a second before the fork", head: 1, clock: 1},
		// The node lags: its head is an hour old, but a claim sent now lands by the wall clock.
		{name: "lagging node", head: 3600, clock: 300},
		// The wall clock is behind the head, which a claim cannot land before.
		{name: "clock behind the head", head: 300, clock: 3600},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, l2, l1, _ := etnaFixture(testEtnaTimestamp)
			l2.heads = []*types.Header{etnaHeader(10, testEtnaTimestamp-tt.head, testAnchorBase, testRoot(0))}
			atTime(p, testEtnaTimestamp-tt.clock)

			var calls int
			p.eventRepo = countingCheckpointRepo(true, &calls)

			ctx, cancel := context.WithTimeout(context.Background(), 2500*time.Millisecond)
			defer cancel()

			// A legacy proof now could land after the fork and revert, and an Etna one cannot be
			// built yet, so the wait builds neither — even though a checkpoint is indexed.
			target, err := p.waitProofTarget(ctx, l1, 2, testAnchorBase)

			require.ErrorIs(t, err, context.DeadlineExceeded)
			assert.Nil(t, target)
			assert.Zero(t, calls)
			assert.GreaterOrEqual(t, l2.headReads, 2)
			// Only the head is read: the guard does not look for an Etna block either.
			assert.Equal(t, l2.headReads, l2.reads)
		})
	}
}

func TestWaitProofTargetUsesTheEtnaAnchorAfterTheFork(t *testing.T) {
	p, _, l1, _ := etnaFixture(testEtnaTimestamp)

	var calls int
	p.eventRepo = countingCheckpointRepo(true, &calls)

	target, err := p.waitProofTarget(testContext(t), l1, 2, testAnchorBase+2)

	require.NoError(t, err)
	require.NotNil(t, target)
	assert.Nil(t, target.checkpoint)
	assert.Equal(t, &etnaAnchor{
		l2Timestamp: testEtnaTimestamp + 6,
		l1Block:     testAnchorBase + 3,
		stateRoot:   testRoot(3),
	}, target.etna)
	// Checkpoints saved before the fork no longer verify after it, so they are not consulted.
	assert.Zero(t, calls)
}

func TestWaitProofTargetWaitsForAnEtnaBlockCoveringTheMessage(t *testing.T) {
	p, _, l1, _ := etnaFixture(testEtnaTimestamp)

	var calls int
	p.eventRepo = countingCheckpointRepo(true, &calls)

	ctx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
	defer cancel()

	// The settled block anchors to testAnchorBase + 3, below the message. A checkpoint is indexed,
	// but after the fork it would not verify, so the wait holds out for a later Etna block.
	target, err := p.waitProofTarget(ctx, l1, 2, testAnchorBase+4)

	require.ErrorIs(t, err, context.DeadlineExceeded)
	assert.Nil(t, target)
	assert.Zero(t, calls)
}

func TestWaitProofTargetSwitchesToEtnaWhenTheForkPassesMidWait(t *testing.T) {
	p, l2, l1, _ := etnaFixture(testEtnaTimestamp)

	// The first round sees a pre-fork head and no checkpoint yet; the next sees the Etna chain.
	preFork := etnaHeader(10, testEtnaTimestamp-etnaForkGuardSeconds-10, testAnchorBase, testRoot(0))
	l2.heads = []*types.Header{preFork, l2.headers[9]}
	atTime(p, preFork.Time)

	var calls int
	p.eventRepo = countingCheckpointRepo(false, &calls)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	target, err := p.waitProofTarget(ctx, l1, 2, testAnchorBase+2)

	require.NoError(t, err)
	require.NotNil(t, target)
	require.NotNil(t, target.etna)
	assert.Equal(t, testAnchorBase+3, target.etna.l1Block)
	assert.Equal(t, 1, calls)
}

func TestWaitProofTargetKeepsWaitingOnEtnaReadErrors(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(l2 *l2Chain, anchor *fakeAnchor)
	}{
		{
			name: "Etna timestamp unreadable",
			mutate: func(_ *l2Chain, anchor *fakeAnchor) {
				anchor.etnaErr = errors.New("dial tcp: connect: connection refused")
			},
		},
		{
			name: "L2 head unreadable",
			mutate: func(l2 *l2Chain, _ *fakeAnchor) {
				l2.headErr = errors.New("dial tcp: connect: connection refused")
			},
		},
		{
			name: "EIP-4788 root mismatch",
			mutate: func(_ *l2Chain, anchor *fakeAnchor) {
				anchor.roots[testEtnaTimestamp+6] = common.HexToHash("0xbad")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, l2, l1, anchor := etnaFixture(testEtnaTimestamp)
			tt.mutate(l2, anchor)

			var calls int
			p.eventRepo = countingCheckpointRepo(true, &calls)

			ctx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
			defer cancel()

			// None of these ends the wait as a message error, and none falls back to a
			// checkpoint that might not verify.
			target, err := p.waitProofTarget(ctx, l1, 2, testAnchorBase)

			require.ErrorIs(t, err, context.DeadlineExceeded)
			assert.Nil(t, target)
			assert.Zero(t, calls)
		})
	}
}

func TestWaitProofTargetHandlesTheExtremeEtnaTimestamps(t *testing.T) {
	// Etna from genesis: every block is an Etna block.
	p, _, l1, _ := etnaFixture(0)

	target, err := p.waitProofTarget(testContext(t), l1, 2, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, target)
	require.NotNil(t, target.etna)
	assert.Equal(t, uint64(6), target.etna.l2Timestamp)

	// Etna never activates.
	p, _, l1, anchor := etnaFixture(testEtnaTimestamp)
	anchor.etnaTimestamp = math.MaxUint64

	var calls int
	p.eventRepo = countingCheckpointRepo(true, &calls)

	target, err = p.waitProofTarget(testContext(t), l1, 2, testAnchorBase)

	require.NoError(t, err)
	require.NotNil(t, target)
	assert.NotNil(t, target.checkpoint)
	assert.Equal(t, 1, calls)
}
