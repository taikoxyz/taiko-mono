package indexer

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"
	"testing"
)

func TestOrderedTransferLogsPureStable(t *testing.T) {
	logs := []types.Log{
		{BlockNumber: 2, TxIndex: 0, Index: 0},
		{BlockNumber: 1, TxIndex: 2, Index: 1},
		{BlockNumber: 1, TxIndex: 1, Index: 2, TxHash: common.HexToHash("0x1")},
		{BlockNumber: 1, TxIndex: 1, Index: 2, TxHash: common.HexToHash("0x2")},
		{BlockNumber: 1, TxIndex: 1, Index: 1},
	}
	original := append([]types.Log(nil), logs...)
	ordered := orderedTransferLogs(logs)
	require.Equal(t, original, logs)
	require.Equal(t, []types.Log{logs[4], logs[2], logs[3], logs[1], logs[0]}, ordered)
	ordered[0].Index = 99

	require.Equal(t, original, logs)
	require.Empty(t, orderedTransferLogs(nil))
}
