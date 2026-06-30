package state

import (
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledProposalID atomic.Uint64
	l1Current             atomic.Value
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return new(SharedState)
}

// GetLastHandledProposalID returns the last handled proposal ID.
func (s *SharedState) GetLastHandledProposalID() uint64 {
	return s.lastHandledProposalID.Load()
}

// SetLastHandledProposalID sets the last handled proposal ID.
func (s *SharedState) SetLastHandledProposalID(proposalID uint64) {
	s.lastHandledProposalID.Store(proposalID)
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
