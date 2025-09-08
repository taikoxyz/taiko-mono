package state

import (
	"sync"
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"

	taikoTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledBatchID      atomic.Uint64
	l1Current               atomic.Value
	m                       sync.RWMutex
	batchesRollbackedRanges taikoTypes.BatchesRollbackedRanges
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return new(SharedState)
}

// GetLastHandledBatchID returns the last handled batch ID.
func (s *SharedState) GetLastHandledBatchID() uint64 {
	return s.lastHandledBatchID.Load()
}

// SetLastHandledBatchID sets the last handled batch ID.
func (s *SharedState) SetLastHandledBatchID(batchID uint64) {
	s.lastHandledBatchID.Store(batchID)
}

// GetL1Current returns the current L1 header cursor.
func (s *SharedState) GetL1Current() *types.Header {
	if val := s.l1Current.Load(); val != nil {
		return val.(*types.Header)
	}
	return nil
}

// SetL1Current sets the current L1 header cursor.
func (s *SharedState) SetL1Current(header *types.Header) {
	s.l1Current.Store(header)
}

// GetBatchesRollbackedRanges returns the batches rollbacked ranges.
func (s *SharedState) GetBatchesRollbackedRanges() taikoTypes.BatchesRollbackedRanges {
	s.m.RLock()
	defer s.m.RUnlock()
	return s.batchesRollbackedRanges
}

// AddBatchesRollbackedRange adds a new batches rollbacked range to the shared state.
func (s *SharedState) AddBatchesRollbackedRange(rollbackedRange taikoTypes.BatchesRollbacked) {
	s.m.Lock()
	defer s.m.Unlock()
	s.batchesRollbackedRanges = append(s.batchesRollbackedRanges, rollbackedRange)
}
