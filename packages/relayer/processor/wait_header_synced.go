package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

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

	ticker := time.NewTicker(time.Duration(p.headerSyncIntervalSeconds) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			slog.Info("waitHeaderSynced checking if tx is processable",
				"blockNumber", blockNum,
			)

			event, err := p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater(
				ctx,
				hopChainId,
				chainId.Uint64(),
				blockNum,
			)
			if err != nil {
				return nil, errors.Wrap(err, "p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater")
			}

			if event != nil {
				slog.Info("waitHeaderSynced done waiting",
					"blockNumToWaitToBeSynced", blockNum,
					"blockNumFromDB", event.BlockID,
					"eventSyncedBlock", event.SyncedInBlockID,
				)

				return event, nil
			}

			latestBlockID, err := p.eventRepo.LatestChainDataSyncedEvent(
				ctx,
				hopChainId,
				chainId.Uint64(),
			)
			if err != nil {
				return nil, err
			}

			slog.Info("waitHeaderSynced waiting to be caughtUp",
				"eventOccuredBlockNum", blockNum,
				"latestSyncedBlockID", latestBlockID,
				"srcChainID", chainId.Uint64(),
				"destChainId", hopChainId,
			)
		}
	}
}
