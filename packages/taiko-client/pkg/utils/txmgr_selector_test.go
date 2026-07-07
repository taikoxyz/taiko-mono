package utils

import (
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/stretchr/testify/require"
)

func TestNewTxMgrSelector(t *testing.T) {
	selector := NewTxMgrSelector(&txmgr.SimpleTxManager{}, nil, nil)
	require.Equal(t, defaultPrivateTxMgrRetryInterval, selector.privateTxMgrRetryInterval)
}

func TestSelect(t *testing.T) {
	normalTxMgr := &txmgr.SimpleTxManager{}
	selector := NewTxMgrSelector(normalTxMgr, nil, nil)

	selectedTxMgr, isPrivate := selector.Select()
	require.Same(t, normalTxMgr, selectedTxMgr)
	require.False(t, isPrivate)
}

func TestSelectPrivateTxMgr(t *testing.T) {
	normalTxMgr := &txmgr.SimpleTxManager{}
	privateTxMgr := &txmgr.SimpleTxManager{}
	selector := NewTxMgrSelector(normalTxMgr, privateTxMgr, nil)

	selectedTxMgr, isPrivate := selector.Select()
	require.Same(t, privateTxMgr, selectedTxMgr)
	require.True(t, isPrivate)
}

func TestSelectNormalTxMgrAfterPrivateFailure(t *testing.T) {
	normalTxMgr := &txmgr.SimpleTxManager{}
	privateTxMgr := &txmgr.SimpleTxManager{}
	selector := NewTxMgrSelector(normalTxMgr, privateTxMgr, nil)
	selector.RecordPrivateTxMgrFailed()

	selectedTxMgr, isPrivate := selector.Select()
	require.Same(t, normalTxMgr, selectedTxMgr)
	require.False(t, isPrivate)
}

func TestSelectRetriesPrivateTxMgrAfterRetryInterval(t *testing.T) {
	normalTxMgr := &txmgr.SimpleTxManager{}
	privateTxMgr := &txmgr.SimpleTxManager{}
	retryInterval := time.Minute
	selector := NewTxMgrSelector(normalTxMgr, privateTxMgr, &retryInterval)
	failedAt := time.Now().Add(-retryInterval - time.Second)
	selector.privateTxMgrFailedAt = &failedAt

	selectedTxMgr, isPrivate := selector.Select()
	require.Same(t, privateTxMgr, selectedTxMgr)
	require.True(t, isPrivate)
}

func TestRecordPrivateTxMgrFailed(t *testing.T) {
	selector := NewTxMgrSelector(&txmgr.SimpleTxManager{}, nil, nil)
	require.Nil(t, selector.privateTxMgrFailedAt)
	selector.RecordPrivateTxMgrFailed()
	require.NotNil(t, selector.privateTxMgrFailedAt)
}
