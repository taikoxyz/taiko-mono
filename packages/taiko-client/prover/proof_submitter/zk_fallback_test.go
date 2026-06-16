package submitter

import (
	"context"
	"errors"
	"math/big"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func TestMarkSGXFallbackOnlyFirstCallerWins(t *testing.T) {
	s := &ProofSubmitter{}
	require.False(t, s.inSGXFallback())
	require.True(t, s.markSGXFallback())  // first caller latches
	require.False(t, s.markSGXFallback()) // already latched
	require.True(t, s.inSGXFallback())

	s.resumeZK()
	require.False(t, s.inSGXFallback())
	require.True(t, s.markSGXFallback()) // can latch again after a resume
}

func TestMarkSGXFallbackConcurrentSingleWinner(t *testing.T) {
	s := &ProofSubmitter{}
	const n = 50
	var (
		wg      sync.WaitGroup
		winners atomic.Int32
	)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			if s.markSGXFallback() {
				winners.Add(1)
			}
		}()
	}
	wg.Wait()
	require.Equal(t, int32(1), winners.Load())
	require.True(t, s.inSGXFallback())
}

// fakeZKBacklog is a programmable ZKBacklogController for unit tests.
type fakeZKBacklog struct {
	clearCalls  atomic.Int32
	clearErr    error
	clean       bool
	statusErr   error
	statusCalls atomic.Int32
	cleared     chan struct{}
}

func (f *fakeZKBacklog) ClearBacklog(_ context.Context) error {
	f.clearCalls.Add(1)
	if f.cleared != nil {
		select {
		case f.cleared <- struct{}{}:
		default:
		}
	}
	return f.clearErr
}

func (f *fakeZKBacklog) StatusClean(_ context.Context) (bool, error) {
	f.statusCalls.Add(1)
	return f.clean, f.statusErr
}

func newZKFallbackSubmitter(backlog proofProducer.ZKBacklogController) *ProofSubmitter {
	return &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkBacklog:                  backlog,
		proofPollingInterval:       time.Millisecond,
		// fireClearAsync now reads s.ctx; the breach tests trigger it indirectly.
		ctx: context.Background(),
	}
}

func TestDecideUseZKMachineDisabled(t *testing.T) {
	s := &ProofSubmitter{maxZKProofProposalDistance: big.NewInt(0), zkBacklog: &fakeZKBacklog{}}
	require.True(t, s.decideUseZK(t.Context(), big.NewInt(1000), big.NewInt(1)))
	require.False(t, s.inSGXFallback())
}

func TestDecideUseZKNilBacklogFallsBackToStateless(t *testing.T) {
	s := &ProofSubmitter{maxZKProofProposalDistance: big.NewInt(30)}             // zkBacklog nil
	require.True(t, s.decideUseZK(t.Context(), big.NewInt(40), big.NewInt(10)))  // 40 <= 10+30
	require.False(t, s.decideUseZK(t.Context(), big.NewInt(41), big.NewInt(10))) // 41 > 10+30
	require.False(t, s.inSGXFallback())                                          // never latches without control plane
}

func TestDecideUseZKWithinDistanceStaysZK(t *testing.T) {
	s := newZKFallbackSubmitter(&fakeZKBacklog{})
	require.True(t, s.decideUseZK(t.Context(), big.NewInt(40), big.NewInt(10)))
	require.False(t, s.inSGXFallback())
}

func TestDecideUseZKBreachLatchesAndClearsOnce(t *testing.T) {
	fake := &fakeZKBacklog{cleared: make(chan struct{}, 1)}
	s := newZKFallbackSubmitter(fake)

	require.False(t, s.decideUseZK(t.Context(), big.NewInt(41), big.NewInt(10))) // breach
	require.True(t, s.inSGXFallback())

	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		t.Fatal("clear was not called")
	}

	// A second breach while latched must not clear again.
	require.False(t, s.decideUseZK(t.Context(), big.NewInt(50), big.NewInt(10)))
	require.Equal(t, int32(1), fake.clearCalls.Load())
}

func TestFireClearAsyncRetriesThenGivesUp(t *testing.T) {
	fake := &fakeZKBacklog{clearErr: errors.New("clear failed")}
	s := newZKFallbackSubmitter(fake)
	s.ctx = t.Context()

	// Distance breach: 41 > 10 + 30 -> latch + fireClearAsync.
	require.False(t, s.decideUseZK(t.Context(), big.NewInt(41), big.NewInt(10)))
	require.True(t, s.inSGXFallback()) // latched even though clear will fail

	// fireClearAsync retries 1 + clearBackoffMaxRetries times, then gives up.
	require.Eventually(t, func() bool {
		return fake.clearCalls.Load() == int32(clearBackoffMaxRetries)+1
	}, 2*time.Second, 5*time.Millisecond)

	// Still latched after clear ultimately failed (best-effort; resume is gated elsewhere).
	require.True(t, s.inSGXFallback())
}

func TestDecideUseZKResumeWhenDrainedAndClean(t *testing.T) {
	fake := &fakeZKBacklog{clean: true}
	s := newZKFallbackSubmitter(fake)
	require.True(t, s.markSGXFallback())

	require.True(t, s.decideUseZK(t.Context(), big.NewInt(11), big.NewInt(10))) // (A) 11<=10+1, clean
	require.False(t, s.inSGXFallback())
	require.Equal(t, int32(1), fake.statusCalls.Load())
}

func TestDecideUseZKStaysSGXWhenNotDrained(t *testing.T) {
	fake := &fakeZKBacklog{clean: true}
	s := newZKFallbackSubmitter(fake)
	require.True(t, s.markSGXFallback())

	require.False(t, s.decideUseZK(t.Context(), big.NewInt(20), big.NewInt(10))) // (A) fails
	require.True(t, s.inSGXFallback())
	require.Equal(t, int32(0), fake.statusCalls.Load()) // status not queried until (A) holds
}

func TestDecideUseZKStaysSGXWhenNotClean(t *testing.T) {
	fake := &fakeZKBacklog{clean: false}
	s := newZKFallbackSubmitter(fake)
	require.True(t, s.markSGXFallback())

	require.False(t, s.decideUseZK(t.Context(), big.NewInt(11), big.NewInt(10)))
	require.True(t, s.inSGXFallback())
	require.Equal(t, int32(1), fake.statusCalls.Load())
}

func TestDecideUseZKDegradesOnStatusError(t *testing.T) {
	fake := &fakeZKBacklog{statusErr: errors.New("status endpoint absent")}
	s := newZKFallbackSubmitter(fake)
	require.True(t, s.markSGXFallback())

	require.True(t, s.decideUseZK(t.Context(), big.NewInt(11), big.NewInt(10))) // (A) holds, status errors -> degrade -> resume
	require.False(t, s.inSGXFallback())
}

func TestDecideUseZKConcurrentBreachClearsOnce(t *testing.T) {
	fake := &fakeZKBacklog{cleared: make(chan struct{}, 1)}
	s := newZKFallbackSubmitter(fake)

	const n = 50
	var (
		wg        sync.WaitGroup
		nonBreach atomic.Int32
	)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			// 41 > 10 + 30 -> every caller sees a breach and must not use ZK.
			if s.decideUseZK(t.Context(), big.NewInt(41), big.NewInt(10)) {
				nonBreach.Add(1)
			}
		}()
	}
	wg.Wait()

	require.Equal(t, int32(0), nonBreach.Load()) // every caller saw the breach
	require.True(t, s.inSGXFallback())
	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		t.Fatal("clear was not called")
	}
	require.Equal(t, int32(1), fake.clearCalls.Load())
}
