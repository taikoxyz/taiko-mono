package state

import (
	"context"
	"sync"
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledProposalID    atomic.Uint64
	lastDispatchedProposalID atomic.Uint64
	l1Current                atomic.Value
	proposalCursorMu         sync.Mutex
	retryProposalIDs         sync.Map
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

// NeedsProposalProcessing returns whether a proposal has not been dispatched or
// has been marked for retry after a failed processing attempt.
func (s *SharedState) NeedsProposalProcessing(proposalID uint64) bool {
	if _, ok := s.retryProposalIDs.Load(proposalID); ok {
		return true
	}
	return proposalID > s.lastDispatchedProposalID.Load()
}

// MarkProposalProcessing marks a proposal as dispatched for processing.
func (s *SharedState) MarkProposalProcessing(proposalID uint64) {
	s.retryProposalIDs.Delete(proposalID)
	for {
		current := s.lastDispatchedProposalID.Load()
		if current >= proposalID || s.lastDispatchedProposalID.CompareAndSwap(current, proposalID) {
			return
		}
	}
}

// WithProposalCursor runs fn while holding the proposal cursor lock.
func (s *SharedState) WithProposalCursor(fn func() error) error {
	s.proposalCursorMu.Lock()
	defer s.proposalCursorMu.Unlock()

	return fn()
}

// RollbackProposalCursor registers a failed proposal for retry and rolls both
// proposal cursors back atomically relative to a proposal scan. The proposal
// cursor is lowered to the ID immediately before the failed proposal. It never
// advances either cursor and returns false for ID zero or if the context is
// canceled before the state is mutated.
func (s *SharedState) RollbackProposalCursor(
	ctx context.Context,
	proposalID uint64,
	header *types.Header,
) bool {
	if proposalID == 0 || ctx.Err() != nil {
		return false
	}

	rolledBack := false
	_ = s.WithProposalCursor(func() error {
		if ctx.Err() != nil {
			return nil
		}

		s.retryProposalIDs.Store(proposalID, struct{}{})
		s.lowerLastHandledProposalID(proposalID - 1)
		s.lowerL1Current(header)
		rolledBack = true
		return nil
	})

	return rolledBack
}

// LowerLastHandledProposalID rolls the last handled proposal ID back to the given
// value, it never advances the cursor.
func (s *SharedState) LowerLastHandledProposalID(proposalID uint64) {
	s.lowerLastHandledProposalID(proposalID)
}

func (s *SharedState) lowerLastHandledProposalID(proposalID uint64) {
	for {
		current := s.lastHandledProposalID.Load()
		if current <= proposalID || s.lastHandledProposalID.CompareAndSwap(current, proposalID) {
			return
		}
	}
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

// LowerL1Current rolls the L1 cursor back to the given header, it never advances
// the cursor.
func (s *SharedState) LowerL1Current(header *types.Header) {
	s.lowerL1Current(header)
}

func (s *SharedState) lowerL1Current(header *types.Header) {
	for {
		val := s.l1Current.Load()
		if val == nil {
			// atomic.Value.CompareAndSwap panics on a nil old value, and the cursor
			// is always initialized before event handlers run, so a plain store is fine.
			s.l1Current.Store(header)
			return
		}
		if val.(*types.Header).Number.Cmp(header.Number) <= 0 || s.l1Current.CompareAndSwap(val, header) {
			return
		}
	}
}
