package bindingTypes

import (
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ForcedInclusionPacaya is a wrapper for the pacaya forced inclusion store.
type ForcedInclusionPacaya struct {
	*pacayaBindings.IForcedInclusionStoreForcedInclusion
}

// NewForcedInclusionPacaya creates a new ForcedInclusionPacaya instance.
func NewForcedInclusionPacaya(i *pacayaBindings.IForcedInclusionStoreForcedInclusion) *ForcedInclusionPacaya {
	return &ForcedInclusionPacaya{IForcedInclusionStoreForcedInclusion: i}
}

// BlobHash returns the blob hash of the forced inclusion.
func (f *ForcedInclusionPacaya) BlobHash() [32]byte {
	return f.IForcedInclusionStoreForcedInclusion.BlobHash
}

// FeeInGwei returns the fee in gwei of the forced inclusion.
func (f *ForcedInclusionPacaya) FeeInGwei() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.FeeInGwei
}

// CreatedAtBatchId returns the created at batch ID of the forced inclusion.
func (f *ForcedInclusionPacaya) CreatedAtBatchId() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.CreatedAtBatchId
}

// BlobByteOffset returns the blob byte offset of the forced inclusion.
func (f *ForcedInclusionPacaya) BlobByteOffset() uint32 {
	return f.IForcedInclusionStoreForcedInclusion.BlobByteOffset
}

// BlobByteSize returns the blob byte size of the forced inclusion.
func (f *ForcedInclusionPacaya) BlobByteSize() uint32 {
	return f.IForcedInclusionStoreForcedInclusion.BlobByteOffset
}

// BlobCreatedIn returns the blob created in of the forced inclusion.
func (f *ForcedInclusionPacaya) BlobCreatedIn() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.BlobCreatedIn
}

// ForcedInclusionShasta is a wrapper for the shasta forced inclusion store.
type ForcedInclusionShasta struct {
	*shastaBindings.IForcedInclusionStoreForcedInclusion
}

// NewForcedInclusionShasta creates a new ForcedInclusionShasta instance.
func NewForcedInclusionShasta(i *shastaBindings.IForcedInclusionStoreForcedInclusion) *ForcedInclusionShasta {
	return &ForcedInclusionShasta{IForcedInclusionStoreForcedInclusion: i}
}

// BlobHash returns the blob hash of the forced inclusion.
func (f *ForcedInclusionShasta) BlobHash() [32]byte {
	return f.IForcedInclusionStoreForcedInclusion.BlobHash
}

// FeeInGwei returns the fee in gwei of the forced inclusion.
func (f *ForcedInclusionShasta) FeeInGwei() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.FeeInGwei
}

// CreatedAtBatchId returns the created at batch ID of the forced inclusion.
func (f *ForcedInclusionShasta) CreatedAtBatchId() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.CreatedAtBatchId
}

// BlobByteOffset returns the blob byte offset of the forced inclusion.
func (f *ForcedInclusionShasta) BlobByteOffset() uint32 {
	return f.IForcedInclusionStoreForcedInclusion.BlobByteOffset
}

// BlobByteSize returns the blob byte size of the forced inclusion.
func (f *ForcedInclusionShasta) BlobByteSize() uint32 {
	return f.IForcedInclusionStoreForcedInclusion.BlobByteSize
}

// BlobCreatedIn returns the blob created in of the forced inclusion.
func (f *ForcedInclusionShasta) BlobCreatedIn() uint64 {
	return f.IForcedInclusionStoreForcedInclusion.BlobCreatedIn
}
