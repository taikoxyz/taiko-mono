package utils

import (
	"sync"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// stubTxMgr stands in for a transaction manager. The embedded interface satisfies the type without
// implementing anything: the selector only ever hands the value back, it never calls into it.
type stubTxMgr struct {
	txmgr.TxManager
	name string
}

// newTestSelector builds a selector over one public and two private managers, with a clock the test
// controls so retry intervals can be exercised without sleeping.
func newTestSelector(t *testing.T, retryInterval *time.Duration) (
	s *TxMgrSelector,
	public *stubTxMgr,
	first *stubTxMgr,
	second *stubTxMgr,
	clock *time.Time,
) {
	t.Helper()

	public = &stubTxMgr{name: "public"}
	first = &stubTxMgr{name: "private-0"}
	second = &stubTxMgr{name: "private-1"}

	now := time.Date(2026, time.August, 29, 0, 0, 0, 0, time.UTC)
	clock = &now

	s = NewTxMgrSelector(public, []txmgr.TxManager{first, second}, retryInterval)
	s.now = func() time.Time { return *clock }

	return s, public, first, second, clock
}

func TestTxMgrSelector_SelectsPublicWhenNoPrivateConfigured(t *testing.T) {
	public := &stubTxMgr{name: "public"}
	s := NewTxMgrSelector(public, nil, nil)

	mgr, index := s.Select()

	assert.Same(t, public, mgr)
	assert.Equal(t, PublicTxMgrIndex, index)
	assert.Equal(t, 0, s.NumPrivateTxMgrs())
}

func TestTxMgrSelector_PrefersTheFirstPrivateEndpoint(t *testing.T) {
	s, _, first, _, _ := newTestSelector(t, nil)

	mgr, index := s.Select()

	assert.Same(t, first, mgr)
	assert.Equal(t, 0, index)
	assert.Equal(t, 2, s.NumPrivateTxMgrs())
}

func TestTxMgrSelector_FallsBackToTheNextPrivateEndpoint(t *testing.T) {
	s, _, _, second, _ := newTestSelector(t, nil)

	_, index := s.Select()
	s.RecordFailure(index)

	mgr, index := s.Select()

	assert.Same(t, second, mgr)
	assert.Equal(t, 1, index)
}

func TestTxMgrSelector_FallsBackToPublicOnceEveryPrivateEndpointHasFailed(t *testing.T) {
	s, public, _, _, _ := newTestSelector(t, nil)

	s.RecordFailure(0)
	s.RecordFailure(1)

	mgr, index := s.Select()

	assert.Same(t, public, mgr)
	assert.Equal(t, PublicTxMgrIndex, index)
}

func TestTxMgrSelector_ReturnsAPrivateEndpointToRotationAfterTheRetryInterval(t *testing.T) {
	s, _, first, second, clock := newTestSelector(t, nil)

	s.RecordFailure(0)

	mgr, _ := s.Select()
	require.Same(t, second, mgr, "the failed endpoint should be skipped straight away")

	// Just short of the interval it is still out of rotation.
	*clock = clock.Add(DefaultPrivateTxMgrRetryInterval - time.Nanosecond)
	mgr, _ = s.Select()
	assert.Same(t, second, mgr)

	// Exactly at the interval it is tried again.
	*clock = clock.Add(time.Nanosecond)
	mgr, index := s.Select()
	assert.Same(t, first, mgr)
	assert.Equal(t, 0, index)
}

func TestTxMgrSelector_TripsAnEndpointAgainWhenItFailsOnItsSecondChance(t *testing.T) {
	s, _, first, second, clock := newTestSelector(t, nil)

	s.RecordFailure(0)

	*clock = clock.Add(DefaultPrivateTxMgrRetryInterval)

	mgr, index := s.Select()
	require.Same(t, first, mgr)

	s.RecordFailure(index)

	mgr, _ = s.Select()
	assert.Same(t, second, mgr, "a repeat failure should take it out of rotation again")
}

func TestTxMgrSelector_RecordFailureIgnoresThePublicIndex(t *testing.T) {
	s, _, first, _, _ := newTestSelector(t, nil)

	// Nothing sits behind the public endpoint, so reporting it must not move anything out of
	// rotation and leave the relayer sending publicly from then on.
	s.RecordFailure(PublicTxMgrIndex)

	mgr, index := s.Select()

	assert.Same(t, first, mgr)
	assert.Equal(t, 0, index)
}

func TestTxMgrSelector_RecordFailureIgnoresAnOutOfRangeIndex(t *testing.T) {
	s, _, first, _, _ := newTestSelector(t, nil)

	assert.NotPanics(t, func() {
		s.RecordFailure(2)
		s.RecordFailure(-99)
	})

	mgr, _ := s.Select()
	assert.Same(t, first, mgr)
}

func TestTxMgrSelector_UsesTheDefaultRetryIntervalWhenNoneIsUsable(t *testing.T) {
	zero := time.Duration(0)
	negative := -time.Minute

	for name, retryInterval := range map[string]*time.Duration{
		"nil":      nil,
		"zero":     &zero,
		"negative": &negative,
	} {
		t.Run(name, func(t *testing.T) {
			s := NewTxMgrSelector(&stubTxMgr{}, []txmgr.TxManager{&stubTxMgr{}}, retryInterval)

			assert.Equal(t, DefaultPrivateTxMgrRetryInterval, s.retryInterval)
		})
	}
}

func TestTxMgrSelector_HonoursACustomRetryInterval(t *testing.T) {
	retryInterval := time.Minute
	s, public, first, _, clock := newTestSelector(t, &retryInterval)

	s.RecordFailure(0)
	s.RecordFailure(1)

	mgr, _ := s.Select()
	require.Same(t, public, mgr)

	*clock = clock.Add(retryInterval)

	mgr, _ = s.Select()
	assert.Same(t, first, mgr, "a shorter interval should bring the endpoint back sooner")
}

func TestTxMgrSelector_IsSafeUnderConcurrentUse(t *testing.T) {
	s, _, _, _, _ := newTestSelector(t, nil)

	var wg sync.WaitGroup

	for i := 0; i < 50; i++ {
		wg.Add(2)

		go func() {
			defer wg.Done()

			_, index := s.Select()
			_ = index
		}()

		go func(index int) {
			defer wg.Done()

			s.RecordFailure(index % 2)
		}(i)
	}

	wg.Wait()
}
