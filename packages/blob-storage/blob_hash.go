package blobstorage

type BlobHash struct {
	BlobHash       string
	KzgCommitment  string
	BlockTimestamp uint64
	BlobData       string
	BlockID        uint64
}

type SaveBlobHashOpts struct {
	BlobHash       string
	KzgCommitment  string
	BlockTimestamp uint64
	BlobData       string
	BlockID        uint64
}

type BlobHashRepository interface {
	Save(opts SaveBlobHashOpts) error
	FirstByBlobHash(blobHash string) (*BlobHash, error)
	FindLatestBlockID() (uint64, error)
}
