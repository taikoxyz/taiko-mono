package repo

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage"

	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/mocks"
	"gorm.io/gorm"
)

func TestNewRepositories(t *testing.T) {
	mockDB, _, _, closeDB := mocks.NewMockDB(t)
	defer closeDB()

	mockBlobHashRepo := new(mocks.MockBlobHashRepo)
	mockBlockMetaRepo := new(mocks.MockBlockMetaRepo)

	repos := &Repositories{
		BlobHashRepo:  mockBlobHashRepo,
		BlockMetaRepo: mockBlockMetaRepo,
		dbTransaction: mockDB,
	}

	repos, err := NewRepositories(mockDB)
	assert.NoError(t, err)
	assert.NotNil(t, repos)
}

func TestSaveBlobAndBlockMeta(t *testing.T) {
	mockDB, mockSql, gormDB, closeDB := mocks.NewMockDB(t)
	defer closeDB()

	mockDB.On("GormDB").Return(gormDB)
	mockSql.ExpectBegin()
	mockSql.ExpectCommit()

	mockBlobHashRepo := new(mocks.MockBlobHashRepo)
	mockBlockMetaRepo := new(mocks.MockBlockMetaRepo)

	repos := &Repositories{
		BlobHashRepo:  mockBlobHashRepo,
		BlockMetaRepo: mockBlockMetaRepo,
		dbTransaction: mockDB,
	}

	ctx := context.Background()

	blobHash := "somehash"
	mockBlobHashRepo.On("FirstByBlobHash", blobHash).
		Return(nil, gorm.ErrRecordNotFound).
		Once()

	mockBlobHashRepo.On("Save", mock.IsType(blobstorage.SaveBlobHashOpts{})).
		Return(nil).
		Once()

	mockBlockMetaRepo.On("Save", mock.IsType(blobstorage.SaveBlockMetaOpts{})).
		Return(nil).
		Once()

	saveBlobHashOpts := &blobstorage.SaveBlobHashOpts{
		BlobHash:      blobHash,
		KzgCommitment: "somecommitment",
		BlobData:      "somedata",
	}

	saveBlockMetaOpts := &blobstorage.SaveBlockMetaOpts{
		BlobHash:       blobHash,
		BlockID:        123,
		EmittedBlockID: 456,
	}

	err := repos.SaveBlobAndBlockMeta(ctx, saveBlockMetaOpts, saveBlobHashOpts)
	assert.NoError(t, err)
	mockBlobHashRepo.AssertExpectations(t)
	mockBlockMetaRepo.AssertExpectations(t)
	mockDB.AssertExpectations(t)
}

func TestDeleteAllAfterBlockID(t *testing.T) {
	mockDB, mockSql, gormDB, closeDB := mocks.NewMockDB(t)
	defer closeDB()

	mockDB.On("GormDB").Return(gormDB)
	mockSql.ExpectBegin()
	mockSql.ExpectCommit()
	mockSql.ExpectRollback()

	mockBlobHashRepo := new(mocks.MockBlobHashRepo)
	mockBlockMetaRepo := new(mocks.MockBlockMetaRepo)

	repos := &Repositories{
		BlobHashRepo:  mockBlobHashRepo,
		BlockMetaRepo: mockBlockMetaRepo,
		dbTransaction: mockDB,
	}

	ctx := context.Background()
	blockID := uint64(123)

	mockBlobHashRepo.On("DeleteAllAfterBlockID", blockID).
		Return(nil).
		Once()

	mockBlockMetaRepo.On("DeleteAllAfterBlockID", blockID).
		Return(nil).
		Once()

	err := repos.DeleteAllAfterBlockID(ctx, blockID)

	assert.NoError(t, err)
	mockBlobHashRepo.AssertExpectations(t)
	mockBlockMetaRepo.AssertExpectations(t)
	mockDB.AssertExpectations(t)

	mockSql.ExpectBegin()
	mockSql.ExpectRollback()
	mockBlobHashRepo.On("DeleteAllAfterBlockID", blockID).
		Return(gorm.ErrRecordNotFound).
		Once()

	err = repos.DeleteAllAfterBlockID(ctx, blockID)
	assert.ErrorIs(t, err, gorm.ErrRecordNotFound)

	mockDB.AssertExpectations(t)
}
