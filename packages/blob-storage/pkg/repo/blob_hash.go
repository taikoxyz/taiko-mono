package repo

import (
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blob-storage"
	"gorm.io/gorm"
)

type BlobHashRepository struct {
	db DB
}

func NewBlobHashRepository(db DB) (*BlobHashRepository, error) {
	if db == nil {
		return nil, ErrNoDB
	}

	return &BlobHashRepository{
		db: db,
	}, nil
}

func (r *BlobHashRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("blob_hashes")
}

func (r *BlobHashRepository) Save(opts blobstorage.SaveBlobHashOpts) error {
	b := &blobstorage.BlobHash{
		BlobHash:       opts.BlobHash,
		KzgCommitment:  opts.KzgCommitment,
		BlockTimestamp: opts.BlockTimestamp,
		BlobData:       opts.BlobData,
		BlockID:        opts.BlockID,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *BlobHashRepository) FindLatestBlockID() (uint64, error) {
	q := `SELECT COALESCE(MAX(block_id), 0)
	FROM blob_hashes`

	var b *blobstorage.BlobHash

	if err := r.startQuery().Raw(q).Scan(&b).Error; err != nil {
		return 0, err
	}

	return b.BlockID, nil
}

func (r *BlobHashRepository) FirstByBlobHash(blobHash string) (*blobstorage.BlobHash, error) {
	var b *blobstorage.BlobHash

	if err := r.startQuery().Where("blob_hash = ?", blobHash).First(b).Error; err != nil {
		return nil, err
	}

	return b, nil
}

// DeleteAllAfterBlockID is used when a reorg is detected
func (r *BlobHashRepository) DeleteAllAfterBlockID(blockID uint64) error {
	query := `
DELETE FROM blob_hashes
WHERE block_id >= ?`

	if err := r.startQuery().Exec(query, blockID).Error; err != nil {
		return err
	}

	return nil
}
