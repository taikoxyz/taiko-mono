package repo

import (
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/mocks"
	"gorm.io/gorm"
)

func TestBlockMetaRepo_Save(t *testing.T) {
	testCases := []struct {
		name      string
		opts      blobstorage.SaveBlockMetaOpts
		setupMock func(mock sqlmock.Sqlmock)
		wantErr   bool
	}{
		{
			name: "successful to save a block_meta",
			opts: blobstorage.SaveBlockMetaOpts{
				BlobHash:       "hash123",
				BlockID:        1,
				EmittedBlockID: 2,
			},
			setupMock: func(mock sqlmock.Sqlmock) {
				mock.ExpectBegin()
				mock.ExpectExec("INSERT INTO `blocks_meta`").
					WithArgs("hash123", 1, 2).
					WillReturnResult(sqlmock.NewResult(1, 1))
				mock.ExpectCommit()
			},
			wantErr: false,
		},
		{
			name: "failed to save a block_meta",
			opts: blobstorage.SaveBlockMetaOpts{
				BlobHash:       "hash123",
				BlockID:        1,
				EmittedBlockID: 2,
			},
			setupMock: func(mock sqlmock.Sqlmock) {
				mock.ExpectBegin()
				mock.ExpectExec("INSERT INTO `blocks_meta`").
					WithArgs("hash123", 1, 2).
					WillReturnError(gorm.ErrInvalidDB)
				mock.ExpectRollback()
			},
			wantErr: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			mockDB, mock, gormDB, closeDB := mocks.NewMockDB(t)
			defer closeDB()

			mockDB.On("GormDB").Return(gormDB)

			repository, err := NewBlockMetaRepository(mockDB)
			if err != nil {
				t.Fatalf("TestBlobHashRepo_Save : %s", err)
			}

			tc.setupMock(mock)

			err = repository.Save(tc.opts)
			if (err != nil) != tc.wantErr {
				t.Errorf("TestBlobHashRepo_Save: expected error %v, got %v", tc.wantErr, err)
			}

			if err := mock.ExpectationsWereMet(); err != nil {
				t.Errorf("TestBlobHashRepo_Save : %s", err)
			}
			mockDB.AssertExpectations(t)
		})
	}
}

func TestBlockMetaRepo_FindLatestBlockID(t *testing.T) {
	testCases := []struct {
		name      string
		mockSetup func(mock sqlmock.Sqlmock)
		expected  uint64
		wantErr   bool
	}{
		{
			name: "successfully find latest block ID",
			mockSetup: func(mock sqlmock.Sqlmock) {
				query := `SELECT COALESCE\(MAX\(emitted_block_id\), 0\) FROM blocks_meta`
				expected_rows := sqlmock.NewRows([]string{"emitted_block_id"}).AddRow(5)
				mock.ExpectQuery(query).
					WillReturnRows(expected_rows)
			},
			expected: 5,
			wantErr:  false,
		},
		{
			name: "error finding latest block ID",
			mockSetup: func(mock sqlmock.Sqlmock) {
				query := `SELECT COALESCE\(MAX\(emitted_block_id\), 0\) FROM blocks_meta`
				mock.ExpectQuery(query).
					WillReturnError(gorm.ErrInvalidDB)
			},
			expected: 0,
			wantErr:  true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			mockDB, mock, gormDB, closeDB := mocks.NewMockDB(t)
			defer closeDB()

			mockDB.On("GormDB").Return(gormDB)

			repository, err := NewBlockMetaRepository(mockDB)
			if err != nil {
				t.Fatalf("TestBlockMetaRepo_FindLatestBlockID : %s", err)
			}

			tc.mockSetup(mock)

			result, err := repository.FindLatestBlockID()
			if (err != nil) != tc.wantErr {
				t.Errorf("TestBlockMetaRepo_FindLatestBlockID: expected error %v, got %v", tc.wantErr, err)
			}

			if result != tc.expected {
				t.Errorf("TestBlockMetaRepo_FindLatestBlockID : %s", err)
			}

			if err := mock.ExpectationsWereMet(); err != nil {
				t.Errorf("TestBlockMetaRepo_FindLatestBlockID: %s", err)
			}
		})
	}
}

func TestBlockMetaRepository_DeleteAllAfterBlockID(t *testing.T) {
	testCases := []struct {
		name      string
		blockID   uint64
		mockSetup func(mock sqlmock.Sqlmock)
		wantErr   bool
	}{
		{
			name:    "successfully delete after block ID",
			blockID: 10,
			mockSetup: func(mock sqlmock.Sqlmock) {
				query := `DELETE FROM blob_hashes WHERE block_id >= \?`
				mock.ExpectExec(query).
					WithArgs(10).
					WillReturnResult(sqlmock.NewResult(0, 3))
			},
			wantErr: false,
		},
		{
			name:    "failed to delete after block ID",
			blockID: 10,
			mockSetup: func(mock sqlmock.Sqlmock) {
				query := `DELETE FROM blob_hashes WHERE block_id >= \?`
				mock.ExpectExec(query).
					WithArgs(10).
					WillReturnError(gorm.ErrInvalidDB)
			},
			wantErr: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			mockDB, mock, gormDB, closeDB := mocks.NewMockDB(t)
			defer closeDB()

			mockDB.On("GormDB").Return(gormDB)

			repository, err := NewBlockMetaRepository(mockDB)
			if err != nil {
				t.Fatalf("TestBlockMetaRepo_FindLatestBlockID : %s", err)
			}

			tc.mockSetup(mock)

			err = repository.DeleteAllAfterBlockID(tc.blockID)
			if (err != nil) != tc.wantErr {
				t.Errorf("TestBlockMetaRepo_FindLatestBlockID: expected error %v, got %v", tc.wantErr, err)
			}

			if err := mock.ExpectationsWereMet(); err != nil {
				t.Errorf("TestBlockMetaRepo_FindLatestBlockID : %s", err)
			}
		})
	}
}

func TestNewBlockMetaRepository_InvalidDB(t *testing.T) {
	repo, err := NewBlockMetaRepository(nil)
	assert.Nil(t, repo)
	assert.Error(t, err)
	assert.Equal(t, ErrNoDB, err)
}
