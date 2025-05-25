package bindingTypes

// BlobParams should be same with ITaikoInbox.BlobParams.
type BlobParams struct {
	blobHashes     [][32]byte
	firstBlobIndex uint8
	numBlobs       uint8
	byteOffset     uint32
	byteSize       uint32
	createdIn      uint64
}

// NewBlobParams creates a new BlobParams instance.
func NewBlobParams(
	blobHashes [][32]byte,
	firstBlobIndex uint8,
	numBlobs uint8,
	byteOffset uint32,
	byteSize uint32,
	createdIn uint64,
) *BlobParams {
	return &BlobParams{
		blobHashes:     blobHashes,
		firstBlobIndex: firstBlobIndex,
		numBlobs:       numBlobs,
		byteOffset:     byteOffset,
		byteSize:       byteSize,
		createdIn:      createdIn,
	}
}

// BlobHashes returns the blob hashes.
func (b *BlobParams) BlobHashes() [][32]byte {
	return b.blobHashes
}

// FirstBlobIndex returns the first blob index.
func (b *BlobParams) FirstBlobIndex() uint8 {
	return b.firstBlobIndex
}

// NumBlobs returns the number of blobs.
func (b *BlobParams) NumBlobs() uint8 {
	return b.numBlobs
}

// ByteOffset returns the byte offset.
func (b *BlobParams) ByteOffset() uint32 {
	return b.byteOffset
}

// ByteSize returns the byte size.
func (b *BlobParams) ByteSize() uint32 {
	return b.byteSize
}

// CreatedIn returns the created in block number.
func (b *BlobParams) CreatedIn() uint64 {
	return b.createdIn
}

// ITaikoInboxBlockParams should be same with ITaikoInbox.BlockParams.
type BlockParams struct {
	numTransactions uint16
	timeShift       uint8
	signalSlots     [][32]byte
}

// NewBlockParams creates a new BlockParams instance.
func NewBlockParams(
	numTransactions uint16,
	timeShift uint8,
	signalSlots [][32]byte,
) *BlockParams {
	return &BlockParams{
		numTransactions: numTransactions,
		timeShift:       timeShift,
		signalSlots:     signalSlots,
	}
}

// NumTransactions returns the number of transactions in this block.
func (b *BlockParams) NumTransactions() uint16 {
	return b.numTransactions
}

// TimeShift returns the time shift of this block.
func (b *BlockParams) TimeShift() uint8 {
	return b.timeShift
}

// SignalSlots returns the signal slots of this block.
func (b *BlockParams) SignalSlots() [][32]byte {
	return b.signalSlots
}
