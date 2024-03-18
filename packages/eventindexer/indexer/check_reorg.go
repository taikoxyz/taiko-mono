package indexer

import (
	"context"
	"log/slog"
)

func (i *Indexer) checkReorg(ctx context.Context, emittedInBlockNumber uint64) error {
	n, err := i.eventRepo.FindLatestBlockID(i.srcChainID)
	if err != nil {
		return err
	}

	if n >= emittedInBlockNumber {
		slog.Info("reorg detected", "event emitted in", emittedInBlockNumber, "latest emitted block id from db", n)
		// reorg detected, we have seen a higher block number than this already.
		return i.eventRepo.DeleteAllAfterBlockID(emittedInBlockNumber, i.srcChainID)
	}

	return nil
}
