package processor

import (
	"context"
	"log/slog"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// waitHeaderSynced waits for a event to appear in the database from the indexer
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

	// check once before ticker interval
	event, err := p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater(
		ctx,
		hopChainId,
		chainId.Uint64(),
		blockNum,
	)
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
			event, err := p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater(
				ctx,
				hopChainId,
				chainId.Uint64(),
				blockNum,
			)
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
