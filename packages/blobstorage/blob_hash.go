package blobstorage

type BlobHash struct {
	BlobHash       string
	KzgCommitment  string
	BlobData       string
	BlockID        uint64
	EmittedBlockID uint64
}

type SaveBlobHashOpts struct {
	BlobHash       string
	KzgCommitment  string
	BlobData       string
	BlockID        uint64
	EmittedBlockID uint64
}

type BlobHashRepository interface {
	Save(opts SaveBlobHashOpts) error
	FirstByBlobHash(blobHash string) (*BlobHash, error)
	FindLatestBlockID() (uint64, error)
	DeleteAllAfterBlockID(blockID uint64) error
}
