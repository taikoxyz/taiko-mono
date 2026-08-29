package utils

import (
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
)

// DefaultPrivateTxMgrRetryInterval is how long a private endpoint stays out of rotation once it has
// been tripped.
const DefaultPrivateTxMgrRetryInterval = 5 * time.Minute

// DefaultPrivateTxMgrFailureThreshold is how many consecutive failures take a private endpoint out
// of rotation.
//
// One failure is not enough. A relay that drops a single transaction — because that transaction
// would revert, say, which is exactly what happens when a competitor already claimed the message —
// is still healthy for every other message. Tripping on it would route unrelated claims through the
// public mempool, which is the thing this is meant to avoid.
const DefaultPrivateTxMgrFailureThreshold = 3

// PublicTxMgrIndex is the index Select reports when it picked the public transaction manager.
const PublicTxMgrIndex = -1

// TxMgrSelector picks which transaction manager sends the next transaction.
//
// processMessage is permissionless and pays its fee to whoever lands it first, so a transaction
// waiting in the public mempool hands competitors the message and proof they need to take that fee,
// leaving this relayer to pay gas for a call that then reverts. A private endpoint passes the
// transaction to block builders without gossiping it, which closes that window.
//
// Private endpoints are tried in the order they were configured. One that fails the threshold
// number of times in a row is taken out of rotation for retryInterval, so the next
// message falls through to the endpoint behind it and finally to the public one; once the interval
// elapses it is tried again with a fresh budget. A single success clears the count, so only an
// endpoint that is actually failing loses its turn.
type TxMgrSelector struct {
	public           txmgr.TxManager
	private          []txmgr.TxManager
	failures         []int
	failedAt         []time.Time
	failureThreshold int
	retryInterval    time.Duration
	now              func() time.Time
	mu               sync.Mutex
}

// NewTxMgrSelector creates a selector over the public transaction manager and any private ones.
// private is in priority order and may be empty, in which case every send goes through public.
// A nil or non-positive retryInterval means DefaultPrivateTxMgrRetryInterval.
func NewTxMgrSelector(
	public txmgr.TxManager,
	private []txmgr.TxManager,
	retryInterval *time.Duration,
) *TxMgrSelector {
	interval := DefaultPrivateTxMgrRetryInterval
	if retryInterval != nil && *retryInterval > 0 {
		interval = *retryInterval
	}

	return &TxMgrSelector{
		public:           public,
		private:          private,
		failures:         make([]int, len(private)),
		failedAt:         make([]time.Time, len(private)),
		failureThreshold: DefaultPrivateTxMgrFailureThreshold,
		retryInterval:    interval,
		now:              time.Now,
	}
}

// Select returns the transaction manager to send the next transaction with, along with its index in
// the private list, or PublicTxMgrIndex when no private endpoint is currently in rotation. Pass the
// index back to RecordSuccess or RecordFailure once the send finishes.
func (s *TxMgrSelector) Select() (txmgr.TxManager, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()

	for i, mgr := range s.private {
		if s.failedAt[i].IsZero() {
			return mgr, i
		}

		if now.Sub(s.failedAt[i]) >= s.retryInterval {
			// Back from a trip, with a fresh budget of attempts rather than the spent one that
			// would otherwise trip it again on its first failure.
			s.failedAt[i] = time.Time{}
			s.failures[i] = 0

			return mgr, i
		}
	}

	return s.public, PublicTxMgrIndex
}

// RecordFailure counts a failed send against the private endpoint at index, taking it out of
// rotation once it has failed failureThreshold times in a row. An index outside the private list is
// ignored, PublicTxMgrIndex included: there is nothing behind the public endpoint to fall back to.
func (s *TxMgrSelector) RecordFailure(index int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if index < 0 || index >= len(s.private) {
		return
	}

	s.failures[index]++

	if s.failures[index] >= s.failureThreshold {
		s.failedAt[index] = s.now()
	}
}

// RecordSuccess clears the failure count for the private endpoint at index. Only consecutive
// failures trip an endpoint, so one transaction it could not land does not cost it its turn. An
// index outside the private list is ignored.
func (s *TxMgrSelector) RecordSuccess(index int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if index < 0 || index >= len(s.private) {
		return
	}

	s.failures[index] = 0
}

// NumPrivateTxMgrs returns how many private endpoints the selector was configured with.
func (s *TxMgrSelector) NumPrivateTxMgrs() int {
	return len(s.private)
}
