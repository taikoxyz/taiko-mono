package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// waitHeaderSynced waits for a CheckpointSaved event to appear in the database
// from the indexer that is greater or equal to the given blockNum.
// This is used to make sure a valid proof can be generated and verified on chain.
// While it waits, a processor that reveals checkpoints asks for one covering blockNum,
// since after the Etna fork no anchor transaction saves it.
func (p *Processor) waitHeaderSynced(
	ctx context.Context,
	ethClient ethClient,
	hopChainId uint64,
	blockNum uint64,
) (*relayer.Event, error) {
	chainId, err := ethClient.ChainID(ctx)
	if err != nil {
		return nil, err
	}

	event, err := p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(ctx, hopChainId, chainId.Uint64(), blockNum)
	if err != nil {
		return nil, err
	}

	if event != nil {
		slog.Info("checkpointSynced done",
			"syncedBlockID", event.BlockID,
			"blockIDWaitingFor", blockNum,
		)

		return event, nil
	}

	p.tryRevealCheckpoint(ctx, blockNum)

	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			event, err := p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(ctx, hopChainId, chainId.Uint64(), blockNum)
			if err != nil {
				return nil, err
			}

			if event != nil {
				slog.Info("checkpointSynced done",
					"syncedBlockID", event.BlockID,
					"blockIDWaitingFor", blockNum,
				)

				return event, nil
			}

			p.tryRevealCheckpoint(ctx, blockNum)
		}
	}
}

// tryRevealCheckpoint asks the checkpoint revealer, when there is one, for a checkpoint covering
// blockNum. A failed reveal is logged and counted but never fails the wait: the message keeps
// waiting, and a later attempt may succeed. Failures caused by the processor shutting down are not
// counted.
func (p *Processor) tryRevealCheckpoint(ctx context.Context, blockNum uint64) {
	if p.checkpointRevealer == nil {
		return
	}

	if err := p.checkpointRevealer.reveal(ctx, blockNum); err != nil {
		if ctx.Err() != nil {
			return
		}

		relayer.CheckpointRevealErrors.Inc()

		slog.Warn("Failed to reveal an L1 checkpoint",
			"blockIDWaitingFor", blockNum,
			"error", err,
		)
	}
}
