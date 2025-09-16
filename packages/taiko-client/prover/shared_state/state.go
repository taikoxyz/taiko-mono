package state

import (
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledBatchID       atomic.Uint64
	lastHandledShastaBatchID atomic.Uint64
	l1Current                atomic.Value
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return new(SharedState)
}

// GetLastHandledPacayaBatchID returns the last handled batch ID.
func (s *SharedState) GetLastHandledPacayaBatchID() uint64 {
	return s.lastHandledBatchID.Load()
}

// SetLastHandledPacayaBatchID sets the last handled batch ID.
func (s *SharedState) SetLastHandledPacayaBatchID(batchID uint64) {
	s.lastHandledBatchID.Store(batchID)
}

// GetLastHandledShastaBatchID returns the last handled Shasta batch ID.
func (s *SharedState) GetLastHandledShastaBatchID() uint64 {
	return s.lastHandledShastaBatchID.Load()
}

// SetLastHandledShastaBatchID sets the last handled Shasta batch ID.
func (s *SharedState) SetLastHandledShastaBatchID(batchID uint64) {
	s.lastHandledShastaBatchID.Store(batchID)
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
