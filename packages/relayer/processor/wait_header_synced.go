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
	pairs := [][2]uint64{
		{chainId, syncedChainId},
		{syncedChainId, chainId},
	}

	for _, pair := range pairs {
		event, err := p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater(
			ctx,
			pair[0],
			pair[1],
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
			pair[0],
			pair[1],
			blockNum,
		)
		if err != nil {
			return nil, err
		}

		if event != nil {
			return event, nil
		}
	}

	return nil, nil
}

func (p *Processor) latestSyncedBlockID(
	ctx context.Context,
	chainId uint64,
	syncedChainId uint64,
) (uint64, error) {
	var maxBlockID uint64

	pairs := [][2]uint64{
		{chainId, syncedChainId},
		{syncedChainId, chainId},
	}

	for _, pair := range pairs {
		blockID, err := p.eventRepo.LatestChainDataSyncedEvent(ctx, pair[0], pair[1])
		if err != nil {
			return 0, err
		}

		if blockID > maxBlockID {
			maxBlockID = blockID
		}

		checkpointBlockID, err := p.eventRepo.LatestCheckpointSyncedEvent(ctx, pair[0], pair[1])
		if err != nil {
			return 0, err
		}

		if checkpointBlockID > maxBlockID {
			maxBlockID = checkpointBlockID
		}
	}

	return maxBlockID, nil
}
