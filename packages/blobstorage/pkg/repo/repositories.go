package repo

import (
	"context"
	"log/slog"

	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"gorm.io/gorm"
)

type DBTransaction interface {
	Begin() *DB
}

type Repositories struct {
	BlobHashRepo  *BlobHashRepository
	BlockMetaRepo *BlockMetaRepository
	dbTransaction DB
}

func NewRepositories(db DB) (*Repositories, error) {
	if db == nil {
		return nil, ErrNoDB
	}
	blobHashRepo, err := NewBlobHashRepository(db)
	if err != nil {
		return nil, err
	}

	blockMetaRepo, err := NewBlockMetaRepository(db)
	if err != nil {
		return nil, err
	}

	return &Repositories{
		BlobHashRepo:  blobHashRepo,
		BlockMetaRepo: blockMetaRepo,
		dbTransaction: db,
	}, nil
}

// Database transaction to store blobs and blocks meta
// func (r *Repositories) SaveBlobAndBlockMeta(ctx context.Context, opts *blobstorage.SaveBlobAndBlockMetaOpts) error {
func (r *Repositories) SaveBlobAndBlockMeta(
	ctx context.Context,
	saveBlockMetaOpts *blobstorage.SaveBlockMetaOpts,
	saveBlobHashOpts *blobstorage.SaveBlobHashOpts,
) error {
	tx := r.dbTransaction.GormDB().Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// store blob in db, if not found
	_, err := r.BlobHashRepo.FirstByBlobHash(saveBlobHashOpts.BlobHash)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			err = r.storeBlobInDB(
				saveBlobHashOpts.BlobHash,
				saveBlobHashOpts.KzgCommitment,
				saveBlobHashOpts.BlobData,
			)
			if err != nil {
				slog.Error("Error storing blob in DB", "error", err)
				return err
			}
		} else {
			slog.Error("Error fetching blob from db", "error", err)
			return err
		}
	}

	// store blockMeta in db
	err = r.storeBlockMetaInDB(
		saveBlockMetaOpts.BlobHash,
		saveBlockMetaOpts.BlockID,
		saveBlockMetaOpts.EmittedBlockID,
	)
	if err != nil {
		slog.Error("Error storing blockMeta in DB", "error", err)
		return err
	}

	return tx.Commit().Error
}

func (r *Repositories) storeBlobInDB(blobHashInMeta, kzgCommitment, blob string) error {
	slog.Info("Storing blob in db", "blobHash", blobHashInMeta)
	return r.BlobHashRepo.Save(blobstorage.SaveBlobHashOpts{
		BlobHash:      blobHashInMeta,
		KzgCommitment: kzgCommitment,
		BlobData:      blob,
	})
}

func (r *Repositories) storeBlockMetaInDB(blobHash string, blockID uint64, emittedBlockID uint64) error {
	slog.Info("Storing blockMeta in db", "blockID", blockID)
	return r.BlockMetaRepo.Save(blobstorage.SaveBlockMetaOpts{
		BlobHash:       blobHash,
		BlockID:        blockID,
		EmittedBlockID: emittedBlockID,
	})
}

// Database transaction to delete all blobs and blocks meta after a block id
func (r *Repositories) DeleteAllAfterBlockID(ctx context.Context, blockID uint64) error {
	tx := r.dbTransaction.GormDB().Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()
	if err := r.BlobHashRepo.DeleteAllAfterBlockID(blockID); err != nil {
		tx.Rollback()
		return err
	}

	if err := r.BlockMetaRepo.DeleteAllAfterBlockID(blockID); err != nil {
		tx.Rollback()
		return err
	}

	return tx.Commit().Error
}
