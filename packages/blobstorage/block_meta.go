package blobstorage

type BlockMeta struct {
	BlobHash       string
	BlockID        uint64
	EmittedBlockID uint64
}

type SaveBlockMetaOpts struct {
	BlobHash       string
	BlockID        uint64
	EmittedBlockID uint64
}

type BlockMetaRepository interface {
	Save(opts SaveBlockMetaOpts) error
	FindLatestBlockID() (uint64, error)
	DeleteAllAfterBlockID(blockID uint64) error
}
