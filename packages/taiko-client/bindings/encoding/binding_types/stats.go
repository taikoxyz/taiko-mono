package bindingTypes

import (
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// InboxStatsPacaya is a struct that implements the ITaikoInboxStats interface for
// the Pacaya fork.
type InboxStatsPacaya struct {
	*pacayaBindings.ITaikoInboxStats1
	*pacayaBindings.ITaikoInboxStats2
}

// NewInboxStatsPacaya creates a new InboxStatsPacaya instance.
func NewInboxStatsPacaya(s1 *pacayaBindings.ITaikoInboxStats1, s2 *pacayaBindings.ITaikoInboxStats2) *InboxStatsPacaya {
	return &InboxStatsPacaya{ITaikoInboxStats1: s1, ITaikoInboxStats2: s2}
}

// GenesisHeight returns the genesis L1 height.
func (s *InboxStatsPacaya) GenesisHeight() uint64 {
	return s.ITaikoInboxStats1.GenesisHeight
}

// LastSyncedBatchId returns the last synced batch ID.
func (s *InboxStatsPacaya) LastSyncedBatchId() uint64 {
	return s.ITaikoInboxStats1.LastSyncedBatchId
}

// LastSyncedAt returns the last synced at timestamp.
func (s *InboxStatsPacaya) LastSyncedAt() uint64 {
	return s.ITaikoInboxStats1.LastSyncedAt
}

// NumBatches returns the number of batches.
func (s *InboxStatsPacaya) NumBatches() uint64 {
	return s.ITaikoInboxStats2.NumBatches
}

// LastVerifiedBatchId returns the last verified batch ID.
func (s *InboxStatsPacaya) LastVerifiedBatchId() uint64 {
	return s.ITaikoInboxStats2.LastVerifiedBatchId
}

// Paused returns true if the inbox is paused.
func (s *InboxStatsPacaya) Paused() bool {
	return s.ITaikoInboxStats2.Paused
}

// LastProposedIn returns the last proposed in block number.
func (s *InboxStatsPacaya) LastProposedIn() uint64 {
	return s.ITaikoInboxStats2.LastProposedIn.Uint64()
}

// LastUnpausedAt returns the last unpaused at timestamp.
func (s *InboxStatsPacaya) LastUnpausedAt() uint64 {
	return s.ITaikoInboxStats2.LastUnpausedAt
}

// InboxStatsPacaya is a struct that implements the ITaikoInboxStats interface for
// the Shasta fork.
type InboxStatsShasta struct {
	*shastaBindings.ITaikoInboxStats1
	*shastaBindings.ITaikoInboxStats2
}

// NewInboxStatsShasta creates a new InboxStatsShasta instance.
func NewInboxStatsShasta(s1 *shastaBindings.ITaikoInboxStats1, s2 *shastaBindings.ITaikoInboxStats2) *InboxStatsShasta {
	return &InboxStatsShasta{ITaikoInboxStats1: s1, ITaikoInboxStats2: s2}
}

// GenesisHeight returns the genesis L1 height.
func (s *InboxStatsShasta) GenesisHeight() uint64 {
	return s.ITaikoInboxStats1.GenesisHeight
}

// LastSyncedBatchId returns the last synced batch ID.
func (s *InboxStatsShasta) LastSyncedBatchId() uint64 {
	return s.ITaikoInboxStats1.LastSyncedBatchId
}

// LastSyncedAt returns the last synced at timestamp.
func (s *InboxStatsShasta) LastSyncedAt() uint64 {
	return s.ITaikoInboxStats1.LastSyncedAt
}

// NumBatches returns the number of batches.
func (s *InboxStatsShasta) NumBatches() uint64 {
	return s.ITaikoInboxStats2.NumBatches
}

// LastVerifiedBatchId returns the last verified batch ID.
func (s *InboxStatsShasta) LastVerifiedBatchId() uint64 {
	return s.ITaikoInboxStats2.LastVerifiedBatchId
}

// Paused returns true if the inbox is paused.
func (s *InboxStatsShasta) Paused() bool {
	return s.ITaikoInboxStats2.Paused
}

// LastProposedIn returns the last proposed in block number.
func (s *InboxStatsShasta) LastProposedIn() uint64 {
	return s.ITaikoInboxStats2.LastProposedIn.Uint64()
}

// LastUnpausedAt returns the last unpaused at timestamp.
func (s *InboxStatsShasta) LastUnpausedAt() uint64 {
	return s.ITaikoInboxStats2.LastUnpausedAt
}
