package state

import (
	"context"
	"crypto/rand"
	"math"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type DriverStateTestSuite struct {
	testutils.ClientTestSuite
	ctx    context.Context
	cancel context.CancelFunc
	s      *State
}

func (s *DriverStateTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	s.ctx, s.cancel = context.WithCancel(context.Background())
	state, err := New(s.ctx, s.RPCClient)
	s.Nil(err)
	s.s = state
}

func (s *DriverStateTestSuite) TearDownTest() {
	defer s.ClientTestSuite.TearDownTest()
	if s.ctx.Err() == nil {
		s.cancel()
	}
	if s.s != nil {
		s.s.Close()
	}
}

func (s *DriverStateTestSuite) TestGetL1Head() {
	l1Head := s.s.GetL1Head()
	s.NotNil(l1Head)
}

func (s *DriverStateTestSuite) TestClose() {
	s.cancel()
	s.NotPanics(s.s.Close)
}

func (s *DriverStateTestSuite) TestGetL2Head() {
	testHeight := RandUint64(nil)

	s.s.setL2Head(nil)
	s.s.setL2Head(&types.Header{Number: new(big.Int).SetUint64(testHeight)})
	h := s.s.GetL2Head()
	s.Equal(testHeight, h.Number.Uint64())
}

func (s *DriverStateTestSuite) TestSubL1HeadsFeed() {
	s.NotNil(s.s.SubL1HeadsFeed(make(chan *types.Header)))
}

func (s *DriverStateTestSuite) TestUpdateL1HeadIfChanged() {
	s.cancel()
	s.s.Close()

	head := testHeader(100, "a")
	s.s.setL1Head(head)
	l1HeadCh := make(chan *types.Header, 1)
	sub := s.s.SubL1HeadsFeed(l1HeadCh)
	defer sub.Unsubscribe()

	s.False(s.s.updateL1HeadIfChanged(types.CopyHeader(head)))
	s.Equal(head.Hash(), s.s.GetL1Head().Hash())
	assertNoHeader(s.T(), l1HeadCh)

	changedHead := testHeader(101, "b")
	s.True(s.s.updateL1HeadIfChanged(changedHead))
	s.Equal(changedHead.Hash(), s.s.GetL1Head().Hash())
	assertHeader(s.T(), l1HeadCh, changedHead)

	s.False(s.s.updateL1HeadIfChanged(types.CopyHeader(changedHead)))
	s.Equal(changedHead.Hash(), s.s.GetL1Head().Hash())
	assertNoHeader(s.T(), l1HeadCh)

	s.False(s.s.updateL1HeadIfChanged(nil))
	s.Equal(changedHead.Hash(), s.s.GetL1Head().Hash())
	assertNoHeader(s.T(), l1HeadCh)
}

func (s *DriverStateTestSuite) TestUpdateL2HeadIfChanged() {
	s.cancel()
	s.s.Close()

	head := testHeader(200, "a")
	s.s.setL2Head(head)

	s.False(s.s.updateL2HeadIfChanged(types.CopyHeader(head)))
	s.Equal(head.Hash(), s.s.GetL2Head().Hash())

	changedHead := testHeader(201, "b")
	s.True(s.s.updateL2HeadIfChanged(changedHead))
	s.Equal(changedHead.Hash(), s.s.GetL2Head().Hash())

	s.False(s.s.updateL2HeadIfChanged(nil))
	s.Equal(changedHead.Hash(), s.s.GetL2Head().Hash())
}

func (s *DriverStateTestSuite) TestPollingHeadTrackerPollUpdatesAndDedupes() {
	s.cancel()
	s.s.Close()

	ctx := context.Background()
	l1Head, err := s.RPCClient.L1.HeaderByNumber(ctx, nil)
	s.Nil(err)
	l2Head, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Nil(err)

	staleL1Head := testHeader(l1Head.Number.Uint64()+1000, "stale-l1")
	staleL2Head := testHeader(l2Head.Number.Uint64()+1000, "stale-l2")
	s.s.setL1Head(staleL1Head)
	s.s.setL2Head(staleL2Head)

	l1HeadCh := make(chan *types.Header, 1)
	sub := s.s.SubL1HeadsFeed(l1HeadCh)
	defer sub.Unsubscribe()

	tracker := &pollingHeadTracker{s: s.s, closeCh: make(chan struct{})}
	tracker.poll(ctx)

	s.NotEqual(staleL1Head.Hash(), s.s.GetL1Head().Hash())
	s.NotEqual(staleL2Head.Hash(), s.s.GetL2Head().Hash())
	assertHeader(s.T(), l1HeadCh, s.s.GetL1Head())

	polledL1Head := types.CopyHeader(s.s.GetL1Head())
	polledL2Head := types.CopyHeader(s.s.GetL2Head())
	tracker.poll(ctx)

	s.True(sameHeader(polledL1Head, s.s.GetL1Head()))
	s.True(sameHeader(polledL2Head, s.s.GetL2Head()))
	assertNoHeader(s.T(), l1HeadCh)
}

func (s *DriverStateTestSuite) TestPollingHeadTrackerRecoversAfterPollError() {
	s.cancel()
	s.s.Close()

	ctx := context.Background()
	l1Head, err := s.RPCClient.L1.HeaderByNumber(ctx, nil)
	s.Nil(err)
	l2Head, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Nil(err)

	staleL1Head := testHeader(l1Head.Number.Uint64()+1000, "stale-l1")
	staleL2Head := testHeader(l2Head.Number.Uint64()+1000, "stale-l2")
	s.s.setL1Head(staleL1Head)
	s.s.setL2Head(staleL2Head)

	tracker := &pollingHeadTracker{s: s.s, closeCh: make(chan struct{})}
	canceledCtx, cancel := context.WithCancel(ctx)
	cancel()
	tracker.poll(canceledCtx)

	s.Equal(staleL1Head.Hash(), s.s.GetL1Head().Hash())
	s.Equal(staleL2Head.Hash(), s.s.GetL2Head().Hash())

	tracker.poll(ctx)

	s.NotEqual(staleL1Head.Hash(), s.s.GetL1Head().Hash())
	s.NotEqual(staleL2Head.Hash(), s.s.GetL2Head().Hash())
}

func (s *DriverStateTestSuite) TestNewDriverContextErr() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	state, err := New(ctx, s.RPCClient)
	s.Nil(state)
	s.ErrorContains(err, "context canceled")
}

func (s *DriverStateTestSuite) TestDriverInitContextErr() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := s.s.init(ctx)
	s.ErrorContains(err, "context canceled")
}

func TestDriverStateTestSuite(t *testing.T) {
	suite.Run(t, new(DriverStateTestSuite))
}

func TestNewHeadTracker(t *testing.T) {
	subscriptionState := &State{rpc: &rpc.Client{UseSubscriptions: true}}
	if _, ok := newHeadTracker(subscriptionState).(*subscriptionHeadTracker); !ok {
		t.Fatal("expected subscription head tracker")
	}

	pollingState := &State{rpc: &rpc.Client{UseSubscriptions: false}}
	if _, ok := newHeadTracker(pollingState).(*pollingHeadTracker); !ok {
		t.Fatal("expected polling head tracker")
	}
}

func TestPollingHeadTrackerStartStopsOnCanceledContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	done := make(chan struct{})
	tracker := &pollingHeadTracker{closeCh: make(chan struct{})}
	go func() {
		tracker.Start(ctx)
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("polling head tracker did not stop after context cancellation")
	}
}

func TestSameHeader(t *testing.T) {
	head := testHeader(100, "a")

	tests := []struct {
		name string
		a    *types.Header
		b    *types.Header
		want bool
	}{
		{name: "both nil", want: true},
		{name: "left nil", b: head},
		{name: "right nil", a: head},
		{name: "same number and hash", a: head, b: types.CopyHeader(head), want: true},
		{name: "different number", a: head, b: testHeader(101, "a")},
		{name: "different hash", a: head, b: testHeader(100, "b")},
		{name: "both nil numbers and same hash", a: &types.Header{}, b: &types.Header{}, want: true},
		{name: "one nil number", a: &types.Header{}, b: testHeader(0, "")},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := sameHeader(tt.a, tt.b); got != tt.want {
				t.Fatalf("sameHeader() = %v, want %v", got, tt.want)
			}
		})
	}
}

func testHeader(number uint64, extra string) *types.Header {
	return &types.Header{Number: new(big.Int).SetUint64(number), Extra: []byte(extra)}
}

func assertHeader(t *testing.T, ch <-chan *types.Header, want *types.Header) {
	t.Helper()

	select {
	case got := <-ch:
		if !sameHeader(got, want) {
			t.Fatalf("got header %v, want %v", got.Hash(), want.Hash())
		}
	default:
		t.Fatal("expected L1 head feed event")
	}
}

func assertNoHeader(t *testing.T, ch <-chan *types.Header) {
	t.Helper()

	select {
	case got := <-ch:
		t.Fatalf("unexpected L1 head feed event: %v", got.Hash())
	default:
	}
}

// RandUint64 returns a random uint64 number.
func RandUint64(max *big.Int) uint64 {
	if max == nil {
		max = new(big.Int)
		max.SetUint64(math.MaxUint64)
	}
	num, _ := rand.Int(rand.Reader, max)

	return num.Uint64()
}
