package utils

import (
	"testing"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/stretchr/testify/require"
)

var (
	testTxMgr    = &txmgr.SimpleTxManager{}
	testSelector = NewTxMgrSelector(testTxMgr, nil, nil)
)

func TestNewTxMgrSelector(t *testing.T) {
	require.Equal(t, defaultPrivateTxMgrRetryInterval, testSelector.privateTxMgrRetryInterval)
}

func TestSelect(t *testing.T) {
	txMgr, isPrivate := testSelector.Select()
	require.NotNil(t, txMgr)
	require.False(t, isPrivate)
}

func TestRecordPrivateTxMgrFailed(t *testing.T) {
	require.Nil(t, testSelector.privateTxMgrFailedAt)
	testSelector.RecordPrivateTxMgrFailed()
	require.NotNil(t, testSelector.privateTxMgrFailedAt)
}
