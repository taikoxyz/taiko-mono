package bindingTypes

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// InboxBatchPacaya represents a batch from TaikoInbox for the Pacaya fork.
type InboxBatchPacaya struct {
	*pacayaBindings.ITaikoInboxBatch
}

// NewInboxBatchPacaya creates a new InboxBatchPacaya instance.
func NewInboxBatchPacaya(batch *pacayaBindings.ITaikoInboxBatch) *InboxBatchPacaya {
	return &InboxBatchPacaya{ITaikoInboxBatch: batch}
}

// MetaHash returns the meta hash of the batch.
func (b *InboxBatchPacaya) MetaHash() common.Hash {
	return b.ITaikoInboxBatch.MetaHash
}

// LastBlockID returns the last block ID of the batch.
func (b *InboxBatchPacaya) LastBlockID() uint64 {
	return b.ITaikoInboxBatch.LastBlockId
}

// LivenessBond returns the liveness bond of the batch.
func (b *InboxBatchPacaya) LivenessBond() *big.Int {
	return b.ITaikoInboxBatch.LivenessBond
}

// BatchId returns the batch ID.
func (b *InboxBatchPacaya) BatchId() uint64 {
	return b.ITaikoInboxBatch.BatchId
}

// LastBlockTimestamp returns the last block timestamp.
func (b *InboxBatchPacaya) LastBlockTimestamp() uint64 {
	return b.ITaikoInboxBatch.LastBlockTimestamp
}

// AnchorBlockId returns the anchor block ID.
func (b *InboxBatchPacaya) AnchorBlockId() uint64 {
	return b.ITaikoInboxBatch.AnchorBlockId
}

// NextTransitionId returns the next transition ID.
func (b *InboxBatchPacaya) NextTransitionId() *big.Int {
	return b.ITaikoInboxBatch.NextTransitionId
}

// VerifiedTransitionId returns the verified transition ID.
func (b *InboxBatchPacaya) VerifiedTransitionId() *big.Int {
	return b.ITaikoInboxBatch.VerifiedTransitionId
}

// InboxBatchShasta represents a batch from TaikoInbox for the Shasta fork.
type InboxBatchShasta struct {
	*shastaBindings.ITaikoInboxBatch
}

// NewInboxBatchShasta creates a new InboxBatchShasta instance.
func NewInboxBatchShasta(batch *shastaBindings.ITaikoInboxBatch) *InboxBatchShasta {
	return &InboxBatchShasta{ITaikoInboxBatch: batch}
}

// MetaHash returns the meta hash of the batch.
func (b *InboxBatchShasta) MetaHash() common.Hash {
	return b.ITaikoInboxBatch.MetaHash
}

// LastBlockID returns the last block ID of the batch.
func (b *InboxBatchShasta) LastBlockID() uint64 {
	return b.ITaikoInboxBatch.LastBlockId
}

// LivenessBond returns the liveness bond of the batch.
func (b *InboxBatchShasta) LivenessBond() *big.Int {
	return b.ITaikoInboxBatch.LivenessBond
}

// BatchId returns the batch ID.
func (b *InboxBatchShasta) BatchId() uint64 {
	return b.ITaikoInboxBatch.BatchId
}

// LastBlockTimestamp returns the last block timestamp.
func (b *InboxBatchShasta) LastBlockTimestamp() uint64 {
	return b.ITaikoInboxBatch.LastBlockTimestamp
}

// AnchorBlockId returns the anchor block ID.
func (b *InboxBatchShasta) AnchorBlockId() uint64 {
	return b.ITaikoInboxBatch.AnchorBlockId
}

// NextTransitionId returns the next transition ID.
func (b *InboxBatchShasta) NextTransitionId() *big.Int {
	return b.ITaikoInboxBatch.NextTransitionId
}

// VerifiedTransitionId returns the verified transition ID.
func (b *InboxBatchShasta) VerifiedTransitionId() *big.Int {
	return b.ITaikoInboxBatch.VerifiedTransitionId
}
