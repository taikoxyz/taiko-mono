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

// fakeRisc0Backlog is a programmable Risc0BacklogController for unit tests.
type fakeRisc0Backlog struct {
	clearCalls  atomic.Int32
	clearErr    error
	clean       bool
	statusErr   error
	statusCalls atomic.Int32
	cleared     chan struct{}
}

func (f *fakeRisc0Backlog) ClearBacklog(_ context.Context) error {
	f.clearCalls.Add(1)
	if f.cleared != nil {
		select {
		case f.cleared <- struct{}{}:
		default:
		}
	}
	return f.clearErr
}

func (f *fakeRisc0Backlog) StatusClean(_ context.Context) (bool, error) {
	f.statusCalls.Add(1)
	return f.clean, f.statusErr
}

func newRisc0SP1FallbackSubmitter(backlog proofProducer.Risc0BacklogController) *ProofSubmitter {
	return &ProofSubmitter{
		maxRisc0ProofProposalDistance: big.NewInt(30),
		risc0Backlog:                  backlog,
		proofPollingInterval:          time.Millisecond,
		// fireClearAsync reads s.ctx; the breach tests trigger it indirectly.
		ctx: context.Background(),
	}
}

type Risc0SP1FallbackTestSuite struct {
	suite.Suite
}

func TestRisc0SP1FallbackTestSuite(t *testing.T) {
	suite.Run(t, new(Risc0SP1FallbackTestSuite))
}

func (s *Risc0SP1FallbackTestSuite) TestMarkSP1FallbackOnlyFirstCallerWins() {
	sub := &ProofSubmitter{}
	s.False(sub.inSP1Fallback())
	s.True(sub.markSP1Fallback())  // first caller latches
	s.False(sub.markSP1Fallback()) // already latched
	s.True(sub.inSP1Fallback())

	sub.resumeRisc0()
	s.False(sub.inSP1Fallback())
	s.True(sub.markSP1Fallback()) // can latch again after a resume
}

func (s *Risc0SP1FallbackTestSuite) TestMarkSP1FallbackConcurrentSingleWinner() {
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
			if sub.markSP1Fallback() {
				winners.Add(1)
			}
		}()
	}
	wg.Wait()
	s.Equal(int32(1), winners.Load())
	s.True(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeDistanceZeroUsesSP1() {
	// distance 0 preserves stateless behavior: never use RISC0, and the
	// drain/resume machine stays inactive (no latch, no clear).
	sub := &ProofSubmitter{maxRisc0ProofProposalDistance: big.NewInt(0), risc0Backlog: &fakeRisc0Backlog{}}
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(1000), big.NewInt(1)))
	s.False(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeForceSP1DoesNotClearBacklog() {
	fake := &fakeRisc0Backlog{cleared: make(chan struct{}, 1)}
	sub := &ProofSubmitter{
		maxRisc0ProofProposalDistance: big.NewInt(30),
		risc0Backlog:                  fake,
		forceSP1Proof:                 true,
		ctx:                           context.Background(),
	}

	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.False(sub.inSP1Fallback())
	s.Equal(int32(0), fake.clearCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeNilBacklogFallsBackToStateless() {
	sub := &ProofSubmitter{maxRisc0ProofProposalDistance: big.NewInt(30)} // risc0Backlog nil
	// 40 <= 10+30 stays RISC0; 41 > 10+30 uses SP1; neither latches without a control-plane client.
	s.Equal(proofProducer.ProofTypeZKR0, sub.decideZKProofType(context.Background(), big.NewInt(40), big.NewInt(10)))
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.False(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeWithinDistanceStaysRisc0() {
	sub := newRisc0SP1FallbackSubmitter(&fakeRisc0Backlog{})
	s.Equal(proofProducer.ProofTypeZKR0, sub.decideZKProofType(context.Background(), big.NewInt(40), big.NewInt(10)))
	s.False(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeBreachLatchesAndClearsOnce() {
	fake := &fakeRisc0Backlog{cleared: make(chan struct{}, 1)}
	sub := newRisc0SP1FallbackSubmitter(fake)

	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10))) // breach
	s.True(sub.inSP1Fallback())

	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		s.FailNow("clear was not called")
	}

	// A second breach while latched must not clear again.
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(50), big.NewInt(10)))
	s.Equal(int32(1), fake.clearCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestFireClearAsyncRetriesThenGivesUp() {
	fake := &fakeRisc0Backlog{clearErr: errors.New("clear failed")}
	sub := newRisc0SP1FallbackSubmitter(fake)

	// Distance breach: 41 > 10 + 30 -> latch + fireClearAsync (which will keep failing).
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.True(sub.inSP1Fallback())

	// fireClearAsync retries 1 + clearBackoffMaxRetries times, then gives up.
	s.Eventually(func() bool {
		return fake.clearCalls.Load() == int32(clearBackoffMaxRetries)+1
	}, 2*time.Second, 5*time.Millisecond)

	// Still latched after clear ultimately failed (best-effort; resume is gated elsewhere).
	s.True(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeResumeWhenDrainedAndClean() {
	fake := &fakeRisc0Backlog{clean: true}
	sub := newRisc0SP1FallbackSubmitter(fake)
	s.True(sub.markSP1Fallback())

	// (A) 11 <= 10+1 holds and status is clean -> resume RISC0.
	s.Equal(proofProducer.ProofTypeZKR0, sub.decideZKProofType(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.False(sub.inSP1Fallback())
	s.Equal(int32(1), fake.statusCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeStaysSP1WhenNotDrained() {
	fake := &fakeRisc0Backlog{clean: true}
	sub := newRisc0SP1FallbackSubmitter(fake)
	s.True(sub.markSP1Fallback())

	// (A) fails (20 > 10+1) -> stay SP1; status must not be queried until (A) holds.
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(20), big.NewInt(10)))
	s.True(sub.inSP1Fallback())
	s.Equal(int32(0), fake.statusCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeStaysSP1WhenNotClean() {
	fake := &fakeRisc0Backlog{clean: false}
	sub := newRisc0SP1FallbackSubmitter(fake)
	s.True(sub.markSP1Fallback())

	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.True(sub.inSP1Fallback())
	s.Equal(int32(1), fake.statusCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeDegradesOnStatusError() {
	fake := &fakeRisc0Backlog{statusErr: errors.New("status endpoint absent")}
	sub := newRisc0SP1FallbackSubmitter(fake)
	s.True(sub.markSP1Fallback())

	// (A) holds but status errors -> degrade -> resume on backlog-drained alone.
	s.Equal(proofProducer.ProofTypeZKR0, sub.decideZKProofType(context.Background(), big.NewInt(11), big.NewInt(10)))
	s.False(sub.inSP1Fallback())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeConcurrentBreachClearsOnce() {
	fake := &fakeRisc0Backlog{cleared: make(chan struct{}, 1)}
	sub := newRisc0SP1FallbackSubmitter(fake)

	const n = 50
	var (
		wg          sync.WaitGroup
		nonFallback atomic.Int32
	)
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			// 41 > 10 + 30 -> every caller sees a breach and must use SP1.
			if sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10)) != proofProducer.ProofTypeZKSP1 {
				nonFallback.Add(1)
			}
		}()
	}
	wg.Wait()

	s.Equal(int32(0), nonFallback.Load()) // every caller saw the breach
	s.True(sub.inSP1Fallback())
	select {
	case <-fake.cleared:
	case <-time.After(time.Second):
		s.FailNow("clear was not called")
	}
	s.Equal(int32(1), fake.clearCalls.Load())
}

func (s *Risc0SP1FallbackTestSuite) TestDecideZKProofTypeBreachClearsLocalRisc0Buffers() {
	const risc0Type = proofProducer.ProofTypeZKR0
	risc0Buffer := proofProducer.NewProofBuffer(8)
	risc0Cache := cmap.New[*proofProducer.ProofResponse]()
	sp1Buffer := proofProducer.NewProofBuffer(8)
	sp1Cache := cmap.New[*proofProducer.ProofResponse]()

	// One buffered proof and one cached proof of the RISC0 type.
	_, err := risc0Buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(5), Meta: newShastaMetaForTest(5)})
	s.NoError(err)
	risc0Cache.Set("6", &proofProducer.ProofResponse{BatchID: big.NewInt(6), Meta: newShastaMetaForTest(6)})
	_, err = sp1Buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(7), Meta: newShastaMetaForTest(7)})
	s.NoError(err)
	sp1Cache.Set("8", &proofProducer.ProofResponse{BatchID: big.NewInt(8), Meta: newShastaMetaForTest(8)})

	fake := &fakeRisc0Backlog{cleared: make(chan struct{}, 1)}
	ch := make(chan *proofProducer.ProofRequestBody, 8)
	sub := &ProofSubmitter{
		maxRisc0ProofProposalDistance: big.NewInt(30),
		risc0Backlog:                  fake,
		proofPollingInterval:          time.Millisecond,
		ctx:                           context.Background(),
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			risc0Type:                    risc0Buffer,
			proofProducer.ProofTypeZKSP1: sp1Buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			risc0Type:                    risc0Cache,
			proofProducer.ProofTypeZKSP1: sp1Cache,
		},
		proofSubmissionCh: ch,
	}

	// Breach (41 > 10+30): latch, flush local RISC0 buffer/cache, resend, clear raiko.
	s.Equal(proofProducer.ProofTypeZKSP1, sub.decideZKProofType(context.Background(), big.NewInt(41), big.NewInt(10)))
	s.True(sub.inSP1Fallback())
	s.Equal(0, risc0Buffer.Len())
	s.Equal(0, risc0Cache.Count())
	s.Equal(1, sp1Buffer.Len())
	s.Equal(1, sp1Cache.Count())

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
