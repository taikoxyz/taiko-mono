package state

import (
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledBlockID atomic.Uint64
	l1Current          atomic.Value
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return new(SharedState)
}

// GetLastHandledBlockID returns the last handled block ID.
func (s *SharedState) GetLastHandledBlockID() uint64 {
	return s.lastHandledBlockID.Load()
}

// SetLastHandledBlockID sets the last handled block ID.
func (s *SharedState) SetLastHandledBlockID(blockID uint64) {
	s.lastHandledBlockID.Store(blockID)
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
