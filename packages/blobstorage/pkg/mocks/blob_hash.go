package mocks

import (
	"github.com/stretchr/testify/mock"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage"
)

type MockBlobHashRepo struct {
	mock.Mock
}

func (m *MockBlobHashRepo) FirstByBlobHash(blobHash string) (*blobstorage.BlobHash, error) {
	args := m.Called(blobHash)
	if item, ok := args.Get(0).(*blobstorage.BlobHash); ok {
		return item, args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockBlobHashRepo) Save(opts blobstorage.SaveBlobHashOpts) error {
	return m.Called(opts).Error(0)
}

func (m *MockBlobHashRepo) DeleteAllAfterBlockID(blockID uint64) error {
	return m.Called(blockID).Error(0)
}
