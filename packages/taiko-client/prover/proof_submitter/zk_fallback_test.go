package submitter

import (
	"context"
	"errors"
	"math/big"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/stretchr/testify/suite"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// fakeZKBacklog is a programmable ZKBacklogController for unit tests.
type fakeZKBacklog struct {
	clearCalls  atomic.Int32
	clearErr    error
	risc0Idle   bool
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

func (f *fakeZKBacklog) Risc0Idle(_ context.Context) (bool, error) {
	f.statusCalls.Add(1)
	return f.risc0Idle, f.statusErr
}

func newZKFallbackSubmitter(backlog proofProducer.ZKBacklogController) *ProofSubmitter {
	return &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkBacklog:                  backlog,
		proofPollingInterval:       time.Millisecond,
		// fireClearAsync reads s.ctx; the breach tests trigger it indirectly.
		ctx: context.Background(),
	}
}

type ZKFallbackTestSuite struct {
	suite.Suite
}

func TestZKFallbackTestSuite(t *testing.T) {
	suite.Run(t, new(ZKFallbackTestSuite))
}

func (s *ZKFallbackTestSuite) TestMarkFallbackOnlyFirstCallerWins() {
	sub := &ProofSubmitter{}
	s.False(sub.inFallback())
	s.True(sub.markFallback())  // first caller latches
	s.False(sub.markFallback()) // already latched
	s.True(sub.inFallback())

	sub.resumeZK()
	s.False(sub.inFallback())
	s.True(sub.markFallback()) // can latch again after a resume
}

func (s *ZKFallbackTestSuite) TestMarkFallbackConcurrentSingleWinner() {
	sub := &ProofSubmitter{}
	const n = 50
	var (
		wg      sync.WaitGroup
		winners atomic.Int32
	)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			if sub.markFallback() {
				winners.Add(1)
			}
		}()
	}
	wg.Wait()
	s.Equal(int32(1), winners.Load())
	s.True(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKDistanceZeroSkipsZK() {
	// distance 0 preserves the pre-#21795 stateless behavior: never use ZK, and the
	// drain/resume machine stays inactive (no latch, no clear).
	sub := &ProofSubmitter{maxZKProofProposalDistance: big.NewInt(0), zkBacklog: &fakeZKBacklog{}}
	s.False(sub.decideUseZK(context.Background(), big.NewInt(1000), big.NewInt(1)))
	s.False(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKNilBacklogFallsBackToStateless() {
	sub := &ProofSubmitter{maxZKProofProposalDistance: big.NewInt(30)} // zkBacklog nil
	// 40 <= 10+30 stays ZK; 41 > 10+30 skips ZK; neither latches without a control-plane client.
	s.True(sub.decideUseZK(context.Background(), big.NewInt(40), big.NewInt(10)))
	s.False(sub.decideUseZK(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.False(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKWithinDistanceStaysZK() {
	sub := newZKFallbackSubmitter(&fakeZKBacklog{})
	s.True(sub.decideUseZK(context.Background(), big.NewInt(40), big.NewInt(10)))
	s.False(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKBreachLatchesAndClearsOnce() {
	fake := &fakeZKBacklog{cleared: make(chan struct{}, 1)}
	sub := newZKFallbackSubmitter(fake)

	s.False(sub.decideUseZK(context.Background(), big.NewInt(41), big.NewInt(10))) // breach
	s.True(sub.inFallback())

	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		s.FailNow("clear was not called")
	}

	// A second breach while latched must not clear again.
	s.False(sub.decideUseZK(context.Background(), big.NewInt(50), big.NewInt(10)))
	s.Equal(int32(1), fake.clearCalls.Load())
}

func (s *ZKFallbackTestSuite) TestFireClearAsyncRetriesThenGivesUp() {
	fake := &fakeZKBacklog{clearErr: errors.New("clear failed")}
	sub := newZKFallbackSubmitter(fake)

	// Distance breach: 41 > 10 + 30 -> latch + fireClearAsync (which will keep failing).
	s.False(sub.decideUseZK(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.True(sub.inFallback())

	// fireClearAsync retries 1 + clearBackoffMaxRetries times, then gives up.
	s.Eventually(func() bool {
		return fake.clearCalls.Load() == int32(clearBackoffMaxRetries)+1
	}, 2*time.Second, 5*time.Millisecond)

	// Still latched after clear ultimately failed (best-effort; resume is gated elsewhere).
	s.True(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKResumeWhenDrainedAndRisc0Idle() {
	fake := &fakeZKBacklog{risc0Idle: true}
	sub := newZKFallbackSubmitter(fake)
	s.True(sub.markFallback())

	// (A) 11 <= 10+1 holds and risc0 is idle -> resume ZK.
	s.True(sub.decideUseZK(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.False(sub.inFallback())
	s.Equal(int32(1), fake.statusCalls.Load())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKStaysInFallbackWhenNotDrained() {
	fake := &fakeZKBacklog{risc0Idle: true}
	sub := newZKFallbackSubmitter(fake)
	s.True(sub.markFallback())

	// (A) fails (20 > 10+1) -> stay in fallback; status must not be queried until (A) holds.
	s.False(sub.decideUseZK(context.Background(), big.NewInt(20), big.NewInt(10)))
	s.True(sub.inFallback())
	s.Equal(int32(0), fake.statusCalls.Load())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKStaysInFallbackWhenRisc0Busy() {
	fake := &fakeZKBacklog{risc0Idle: false}
	sub := newZKFallbackSubmitter(fake)
	s.True(sub.markFallback())

	s.False(sub.decideUseZK(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.True(sub.inFallback())
	s.Equal(int32(1), fake.statusCalls.Load())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKDegradesOnStatusError() {
	fake := &fakeZKBacklog{statusErr: errors.New("status endpoint absent")}
	sub := newZKFallbackSubmitter(fake)
	s.True(sub.markFallback())

	// (A) holds but status errors -> degrade -> resume on backlog-drained alone.
	s.True(sub.decideUseZK(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.False(sub.inFallback())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKConcurrentBreachClearsOnce() {
	fake := &fakeZKBacklog{cleared: make(chan struct{}, 1)}
	sub := newZKFallbackSubmitter(fake)

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
			if sub.decideUseZK(context.Background(), big.NewInt(41), big.NewInt(10)) {
				nonBreach.Add(1)
			}
		}()
	}
	wg.Wait()

	s.Equal(int32(0), nonBreach.Load()) // every caller saw the breach
	s.True(sub.inFallback())
	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		s.FailNow("clear was not called")
	}
	s.Equal(int32(1), fake.clearCalls.Load())
}

func (s *ZKFallbackTestSuite) TestDecideUseZKBreachClearsLocalZKBuffers() {
	const zkType = proofProducer.ProofTypeZKR0
	buffer := proofProducer.NewProofBuffer(8)
	cache := cmap.New[*proofProducer.ProofResponse]()

	// One buffered proof and one cached proof of the ZK type.
	_, err := buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(5), Meta: newShastaMetaForTest(5)})
	s.NoError(err)
	cache.Set("6", &proofProducer.ProofResponse{BatchID: big.NewInt(6), Meta: newShastaMetaForTest(6)})

	fake := &fakeZKBacklog{cleared: make(chan struct{}, 1)}
	ch := make(chan *proofProducer.ProofRequestBody, 8)
	sub := &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkBacklog:                  fake,
		proofPollingInterval:       time.Millisecond,
		ctx:                        context.Background(),
		proofBuffers:               map[proofProducer.ProofType]*proofProducer.ProofBuffer{zkType: buffer},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			zkType: cache,
		},
		proofSubmissionCh: ch,
	}

	// Breach (41 > 10+30): latch, flush local ZK buffer/cache, resend, clear raiko.
	s.False(sub.decideUseZK(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.True(sub.inFallback())
	s.Equal(0, buffer.Len())
	s.Equal(0, cache.Count())

	resent := map[uint64]bool{}
	for i := 0; i < 2; i++ {
		select {
		case req := <-ch:
			resent[req.Meta.GetProposalID().Uint64()] = true
		case <-time.After(time.Second):
			s.FailNow("expected resend on proofSubmissionCh")
		}
	}
	s.True(resent[5])
	s.True(resent[6])

	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		s.FailNow("expected raiko backlog clear")
	}
}
