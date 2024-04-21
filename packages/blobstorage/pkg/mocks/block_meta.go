package mocks

import (
	"github.com/stretchr/testify/mock"
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blobstorage"
)

type MockBlockMetaRepo struct {
	mock.Mock
}

func (m *MockBlockMetaRepo) Save(opts blobstorage.SaveBlockMetaOpts) error {
	return m.Called(opts).Error(0)
}

func (m *MockBlockMetaRepo) FindLatestBlockID() (uint64, error) {
	args := m.Called()
	return args.Get(0).(uint64), args.Error(1)
}

func (m *MockBlockMetaRepo) DeleteAllAfterBlockID(blockID uint64) error {
	return m.Called(blockID).Error(0)
}
