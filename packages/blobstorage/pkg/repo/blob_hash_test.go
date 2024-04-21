package repo

import (
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/mocks"
	"gorm.io/gorm"
)

func TestBlobHashRepository_Save(t *testing.T) {
	testCases := []struct {
		name      string
		opts      blobstorage.SaveBlobHashOpts
		setupMock func(mock sqlmock.Sqlmock)
		wantErr   bool
	}{
		{
			name: "successful to save a blob_hash",
			opts: blobstorage.SaveBlobHashOpts{
				BlobHash:      "hash123",
				KzgCommitment: "commitment123",
				BlobData:      "data123",
			},
			setupMock: func(mock sqlmock.Sqlmock) {
				mock.ExpectBegin()
				mock.ExpectExec("INSERT INTO `blob_hashes`").
					WithArgs("hash123", "commitment123", "data123").
					WillReturnResult(sqlmock.NewResult(1, 1))
				mock.ExpectCommit()
			},
			wantErr: false,
		},
		{
			name: "failed to save a blob_hash",
			opts: blobstorage.SaveBlobHashOpts{
				BlobHash:      "hash123",
				KzgCommitment: "commitment123",
				BlobData:      "data123",
			},
			setupMock: func(mock sqlmock.Sqlmock) {
				mock.ExpectBegin()
				mock.ExpectExec("INSERT INTO `blob_hashes`").
					WithArgs("hash123", "commitment123", "data123").
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

			repository, err := NewBlobHashRepository(mockDB)
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

func TestBlobHashRepo_FirstByBlobHash(t *testing.T) {
	testCases := []struct {
		name      string
		blobHash  string
		setupMock func(mock sqlmock.Sqlmock)
		wantErr   bool
	}{
		{
			name:     "successful to get a blob_hash by blobHash",
			blobHash: "hash123",
			setupMock: func(mock sqlmock.Sqlmock) {
				expected_rows := sqlmock.NewRows(
					[]string{"blob_hash",
						"kzg_commitment",
						"blob_data"}).
					AddRow("hash123", "commitment123", "data123")

				query := "SELECT * FROM `blob_hashes` WHERE blob_hash = ? ORDER BY `blob_hashes`.`blob_hash` LIMIT 1"
				mock.ExpectQuery(regexp.QuoteMeta(query)).
					WithArgs("hash123").
					WillReturnRows(expected_rows)

			},
			wantErr: false,
		},
		{
			name:     "failed to get a blob_hash by blobHash",
			blobHash: "hash123",
			setupMock: func(mock sqlmock.Sqlmock) {
				query := "SELECT * FROM `blob_hashes` WHERE blob_hash = ? ORDER BY `blob_hashes`.`blob_hash` LIMIT 1"
				mock.ExpectQuery(regexp.QuoteMeta(query)).
					WithArgs("hash123").
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

			repository, err := NewBlobHashRepository(mockDB)
			if err != nil {
				t.Fatalf("TestBlobHashRepo_FirstByBlobHash : %s", err)
			}

			tc.setupMock(mock)

			_, err = repository.FirstByBlobHash(tc.blobHash)
			if (err != nil) != tc.wantErr {
				t.Errorf("TestBlobHashRepo_FirstByBlobHash: expected error %v, got %v", tc.wantErr, err)
			}

			if err := mock.ExpectationsWereMet(); err != nil {
				t.Errorf("TestBlobHashRepo_FirstByBlobHash : %s", err)
			}
			mockDB.AssertExpectations(t)
		})
	}
}

func TestBlobHashRepo_DeleteAllAfterBlockID(t *testing.T) {
	testCases := []struct {
		name      string
		blockID   uint64
		setupMock func(mock sqlmock.Sqlmock)
		wantErr   bool
	}{
		{
			name:    "successful to delete a blob_hashes starting from a blockID",
			blockID: 123,
			setupMock: func(mock sqlmock.Sqlmock) {
				query := `DELETE FROM blob_hashes WHERE blob_hash IN \(\s*SELECT blob_hashes\.blob_hash FROM blob_hashes INNER JOIN block_meta ON blob_hashes\.blob_hash = block_meta\.blob_hash WHERE block_meta\.block_id >= \?\s*\)`
				mock.ExpectExec(query).
					WithArgs(123).
					WillReturnResult(sqlmock.NewResult(0, 1))
			},
			wantErr: false,
		},
		{
			name:    "delete to to delete a blob_hashes starting from a blockID",
			blockID: 123,
			setupMock: func(mock sqlmock.Sqlmock) {
				query := `DELETE FROM blob_hashes WHERE blob_hash IN \(\s*SELECT blob_hashes\.blob_hash FROM blob_hashes INNER JOIN block_meta ON blob_hashes\.blob_hash = block_meta\.blob_hash WHERE block_meta\.block_id >= \?\s*\)`
				mock.ExpectExec(query).
					WithArgs(123).
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

			repository, err := NewBlobHashRepository(mockDB)
			if err != nil {
				t.Fatalf("TestBlobHashRepo_DeleteAllAfterBlockID : %s", err)
			}

			tc.setupMock(mock)

			err = repository.DeleteAllAfterBlockID(tc.blockID)
			if (err != nil) != tc.wantErr {
				t.Errorf("TestBlobHashRepo_DeleteAllAfterBlockID: expected error %v, got %v", tc.wantErr, err)
			}

			if err := mock.ExpectationsWereMet(); err != nil {
				t.Errorf("TestBlobHashRepo_DeleteAllAfterBlockID : %s", err)
			}
			mockDB.AssertExpectations(t)
		})
	}
}

func TestNewBlobHash_InvalidDB(t *testing.T) {
	repo, err := NewBlobHashRepository(nil)
	assert.Nil(t, repo)
	assert.Error(t, err)
	assert.Equal(t, ErrNoDB, err)
}
