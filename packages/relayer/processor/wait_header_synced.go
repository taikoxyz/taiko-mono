package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// waitHeaderSynced waits for an event to appear in the database from the indexer
// for the type "ChainDataSynced" to be greater or less than the given blockNum.
// this is used to make sure a valid proof can be generated and verified on chain.
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

	event, err := p.findSyncedEvent(ctx, hopChainId, chainId.Uint64(), blockNum)
	if err != nil {
		return nil, err
	}

	if event != nil {
		slog.Info("chainDataSynced done",
			"syncedBlockID", event.BlockID,
			"blockIDWaitingFor", blockNum,
		)

		return event, nil
	}

	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			event, err := p.findSyncedEvent(ctx, hopChainId, chainId.Uint64(), blockNum)
			if err != nil {
				return nil, err
			}

			if event != nil {
				slog.Info("chainDataSynced done",
					"syncedBlockID", event.BlockID,
					"blockIDWaitingFor", blockNum,
				)

				return event, nil
			}
		}
	}
}

// findSyncedEvent attempts to locate either a legacy ChainDataSynced event or
// a v4 CheckpointSaved event for the given chain pairing, trying both chainId
// orientations to accommodate existing deployments.
func (p *Processor) findSyncedEvent(
	ctx context.Context,
	chainId uint64,
	syncedChainId uint64,
	blockNum uint64,
) (*relayer.Event, error) {
	event, err := p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater(
		ctx,
		chainId,
		syncedChainId,
		blockNum,
	)
	if err != nil {
		return nil, err
	}

	if event != nil {
		return event, nil
	}

	event, err = p.eventRepo.CheckpointSyncedEventByBlockNumberOrGreater(
		ctx,
		chainId,
		syncedChainId,
		blockNum,
	)
	if err != nil {
		return nil, err
	}

	return event, nil
}

func (p *Processor) latestSyncedBlockID(
	ctx context.Context,
	chainId uint64,
	syncedChainId uint64,
) (uint64, error) {
	blockID, err := p.eventRepo.LatestChainDataSyncedEvent(ctx, chainId, syncedChainId)
	if err != nil {
		return 0, err
	}

	checkpointBlockID, err := p.eventRepo.LatestCheckpointSyncedEvent(ctx, chainId, syncedChainId)
	if err != nil {
		return 0, err
	}

	if checkpointBlockID > blockID {
		return checkpointBlockID, nil
	}

	return blockID, nil
}
