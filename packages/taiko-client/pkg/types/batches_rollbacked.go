package types

type BatchesRollbacked struct {
	StartBatchID uint64
	EndBatchID   uint64
}

type BatchesRollbackedRanges []BatchesRollbacked

// Contains check if the given batch ID is in the batches rollbacked ranges.
func (r BatchesRollbackedRanges) Contains(batchID uint64) bool {
	for _, interval := range r {
		if batchID >= interval.StartBatchID && batchID <= interval.EndBatchID {
			return true
		}
	}
	return false
}
