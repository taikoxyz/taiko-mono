package state

import (
	"sync/atomic"

	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

// SharedState represents the internal state of a prover.
type SharedState struct {
	lastHandledBlockID atomic.Uint64
	l1Current          atomic.Value
	tiers              []*rpc.TierProviderTierWithID
}

// New creates a new prover shared state instance.
func New() *SharedState {
	return &SharedState{}
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

// GetTiers returns the current proof tiers.
func (s *SharedState) GetTiers() []*rpc.TierProviderTierWithID {
	return s.tiers
}

// SetTiers sets the current proof tiers.
func (s *SharedState) SetTiers(tiers []*rpc.TierProviderTierWithID) {
	s.tiers = tiers
}
