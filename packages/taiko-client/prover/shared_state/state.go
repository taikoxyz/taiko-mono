package state

import (
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledShastaProposalID atomic.Uint64
	l1Current                atomic.Value
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return new(SharedState)
}

// GetLastHandledShastaProposalID returns the last handled Shasta proposal ID.
func (s *SharedState) GetLastHandledShastaProposalID() uint64 {
	return s.lastHandledShastaProposalID.Load()
}

// SetLastHandledShastaProposalID sets the last handled Shasta proposal ID.
func (s *SharedState) SetLastHandledShastaProposalID(proposalID uint64) {
	s.lastHandledShastaProposalID.Store(proposalID)
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
