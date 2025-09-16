package types

type BatchesRollbacked struct {
	StartBatchID uint64
	EndBatchID   uint64
	L1Height     uint64
	L1LogIndex   uint
}

type BatchesRollbackedRanges []BatchesRollbacked

// Contains check if the given batch ID is in the batches rollbacked ranges.
// Since the batch id will be reused, we need to ensure that the batch id is
// from an older L1 block/log index.
func (r BatchesRollbackedRanges) Contains(batchID uint64, l1Height uint64, l1LogIndex uint) bool {
	for _, interval := range r {
		if batchID >= interval.StartBatchID && batchID <= interval.EndBatchID {
			if l1Height < interval.L1Height {
				return true
			} else if l1Height == interval.L1Height {
				// Equal L1 height, use the log index to determine the order.
				if l1LogIndex < interval.L1LogIndex {
					return true
				}
			}
		}
	}
	return false
}
