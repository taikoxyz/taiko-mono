package blobstorage

type BlobHash struct {
	BlobHash      string
	KzgCommitment string
	BlobData      string
}

type SaveBlobHashOpts struct {
	BlobHash      string
	KzgCommitment string
	BlobData      string
}

type BlobHashRepository interface {
	Save(opts SaveBlobHashOpts) error
	FirstByBlobHash(blobHash string) (*BlobHash, error)
	DeleteAllAfterBlockID(blockID uint64) error
}
