package utils

import (
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
)

// DefaultPrivateTxMgrRetryInterval is how long a private endpoint is taken out of rotation after a
// send through it fails.
const DefaultPrivateTxMgrRetryInterval = 5 * time.Minute

// PublicTxMgrIndex is the index Select reports when it picked the public transaction manager.
const PublicTxMgrIndex = -1

// TxMgrSelector picks which transaction manager sends the next transaction.
//
// processMessage is permissionless and pays its fee to whoever lands it first, so a transaction
// waiting in the public mempool hands competitors the message and proof they need to take that fee,
// leaving this relayer to pay gas for a call that then reverts. A private endpoint passes the
// transaction to block builders without gossiping it, which closes that window.
//
// Private endpoints are tried in the order they were configured. One whose send fails is taken out
// of rotation for retryInterval, so the next message falls through to the endpoint behind it and
// finally to the public one; once the interval elapses it is tried again. The processor requeues a
// message whose send failed, so a failover costs a retry rather than the message.
type TxMgrSelector struct {
	public        txmgr.TxManager
	private       []txmgr.TxManager
	failedAt      []time.Time
	retryInterval time.Duration
	now           func() time.Time
	mu            sync.Mutex
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
		public:        public,
		private:       private,
		failedAt:      make([]time.Time, len(private)),
		retryInterval: interval,
		now:           time.Now,
	}
}

// Select returns the transaction manager to send the next transaction with, along with its index in
// the private list, or PublicTxMgrIndex when no private endpoint is currently in rotation. Pass the
// index back to RecordFailure when the send fails.
func (s *TxMgrSelector) Select() (txmgr.TxManager, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()

	for i, mgr := range s.private {
		if s.failedAt[i].IsZero() || now.Sub(s.failedAt[i]) >= s.retryInterval {
			return mgr, i
		}
	}

	return s.public, PublicTxMgrIndex
}

// RecordFailure takes the private endpoint at index out of rotation for the retry interval. An
// index outside the private list is ignored, PublicTxMgrIndex included: there is nothing behind the
// public endpoint to fall back to.
func (s *TxMgrSelector) RecordFailure(index int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if index < 0 || index >= len(s.private) {
		return
	}

	s.failedAt[index] = s.now()
}

// NumPrivateTxMgrs returns how many private endpoints the selector was configured with.
func (s *TxMgrSelector) NumPrivateTxMgrs() int {
	return len(s.private)
}
