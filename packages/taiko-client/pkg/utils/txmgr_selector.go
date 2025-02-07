package utils

import (
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/modern-go/reflect2"
)

var (
	defaultPrivateTxMgrRetryInterval = 5 * time.Minute
)

// TxMgrSelector is responsible for selecting the correct transaction manager,
// it will choose the transaction manager for a private mempool if it is available and works well,
// otherwise it will choose the normal transaction manager.
type TxMgrSelector struct {
	txMgr                     txmgr.TxManager
	privateTxMgr              txmgr.TxManager
	privateTxMgrFailedAt      *time.Time
	privateTxMgrRetryInterval time.Duration
}

// NewTxMgrSelector creates a new TxMgrSelector instance.
func NewTxMgrSelector(
	txMgr txmgr.TxManager,
	privateTxMgr txmgr.TxManager,
	privateTxMgrRetryInterval *time.Duration,
) *TxMgrSelector {
	retryInterval := defaultPrivateTxMgrRetryInterval
	if privateTxMgrRetryInterval != nil {
		retryInterval = *privateTxMgrRetryInterval
	}

	return &TxMgrSelector{
		txMgr:                     txMgr,
		privateTxMgr:              privateTxMgr,
		privateTxMgrFailedAt:      nil,
		privateTxMgrRetryInterval: retryInterval,
	}
}

// Select selects a transaction manager based on the current state.
func (s *TxMgrSelector) Select() (txmgr.TxManager, bool) {
	// If there is no private transaction manager, return the normal transaction manager.
	if reflect2.IsNil(s.privateTxMgr) {
		return s.txMgr, false
	}

	// If the private transaction manager has failed, check if it is time to retry.
	if s.privateTxMgrFailedAt == nil || time.Now().After(s.privateTxMgrFailedAt.Add(s.privateTxMgrRetryInterval)) {
		return s.privateTxMgr, true
	}

	// Otherwise, return the normal transaction manager.
	return s.txMgr, false
}

// RecordPrivateTxMgrFailed records the time when the private transaction manager has failed.
func (s *TxMgrSelector) RecordPrivateTxMgrFailed() {
	now := time.Now()
	s.privateTxMgrFailedAt = &now
}

// TxMgrmethod returns the inner transaction manager.
func (s *TxMgrSelector) TxMgr() txmgr.TxManager {
	return s.txMgr
}

// PrivateTxMgr returns the private transaction manager.
func (s *TxMgrSelector) PrivateTxMgr() txmgr.TxManager {
	return s.privateTxMgr
}
