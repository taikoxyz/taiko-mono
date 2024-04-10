package repo

import (
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"gorm.io/gorm"
)

type BlockMetaRepository struct {
	db DB
}

func NewBlockMetaRepository(db DB) (*BlockMetaRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &BlockMetaRepository{
		db: db,
	}, nil
}

func (r *BlockMetaRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("blocks_meta")
}

func (r *BlockMetaRepository) Save(opts blobstorage.SaveBlockMetaOpts) error {
	b := &blobstorage.BlockMeta{
		BlobHash:       opts.BlobHash,
		BlockID:        opts.BlockID,
		EmittedBlockID: opts.EmittedBlockID,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *BlockMetaRepository) FindLatestBlockID() (uint64, error) {
	q := `SELECT COALESCE(MAX(emitted_block_id), 0)
	FROM blocks_meta`

	var b uint64

	if err := r.startQuery().Raw(q).Scan(&b).Error; err != nil {
		return 0, err
	}

	return b, nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *BlockMetaRepository) DeleteAllAfterBlockID(blockID uint64) error {
	query := `
DELETE FROM blob_hashes
WHERE block_id >= ?`

	if err := r.startQuery().Exec(query, blockID).Error; err != nil {
		return err
	}

	return nil
}
