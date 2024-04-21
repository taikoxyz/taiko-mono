package repo

import (
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
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

/* Save a blob_hash record */
func (r *BlobHashRepository) Save(opts blobstorage.SaveBlobHashOpts) error {
	b := &blobstorage.BlobHash{
		BlobHash:      opts.BlobHash,
		KzgCommitment: opts.KzgCommitment,
		BlobData:      opts.BlobData,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

/* Get a block_hash record by a blobHash */
func (r *BlobHashRepository) FirstByBlobHash(blobHash string) (*blobstorage.BlobHash, error) {
	var b blobstorage.BlobHash

	if err := r.startQuery().Where("blob_hash = ?", blobHash).First(&b).Error; err != nil {
		return nil, err
	}

	return &b, nil
}

/* Delete all records from block_hash tables starting from a blockID */
func (r *BlobHashRepository) DeleteAllAfterBlockID(blockID uint64) error {
	query := `
        DELETE FROM blob_hashes
        WHERE blob_hash IN (
            SELECT blob_hashes.blob_hash
            FROM blob_hashes
            INNER JOIN block_meta ON blob_hashes.blob_hash = block_meta.blob_hash
            WHERE block_meta.block_id >= ?
        )`

	if err := r.startQuery().Exec(query, blockID).Error; err != nil {
		return err
	}

	return nil
}
