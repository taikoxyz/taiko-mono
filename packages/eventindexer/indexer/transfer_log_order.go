package indexer

import (
	"cmp"
	"slices"

	"github.com/ethereum/go-ethereum/core/types"
)

// orderedTransferLogs preserves the caller's slice and equal-key order while
// ordering balance mutations by block, transaction, and log position.
func orderedTransferLogs(logs []types.Log) []types.Log {
	ordered := slices.Clone(logs)
	slices.SortStableFunc(ordered, func(a, b types.Log) int {
		return cmp.Or(cmp.Compare(a.BlockNumber, b.BlockNumber),
			cmp.Compare(a.TxIndex, b.TxIndex), cmp.Compare(a.Index, b.Index))
	})

	return ordered
}
