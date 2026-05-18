package indexer

import (
	"context"
	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (i *Indexer) setInitialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
) error {
	startingBlock, err := i.getFirstShastaBlockHeight(ctx)
	if err != nil {
		return err
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latest, err := i.eventRepo.FindLatestBlockID(ctx,
			i.srcChainID,
		)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.FindLatestBlockID")
		}

		if latest != 0 {
			startingBlock = latest - 1
		}

	case Resync:
	default:
		return eventindexer.ErrInvalidMode
	}

	slog.Info("startingBlock", "startingBlock", startingBlock)

	i.latestIndexedBlockNumber = startingBlock

	return nil
}

// getFirstShastaBlockHeight returns the first Shasta block height.
func (i *Indexer) getFirstShastaBlockHeight(ctx context.Context) (uint64, error) {
	if i.shastaInbox == nil {
		return 0, errors.New("no compatible TaikoL1 contract version found")
	}

	ts, err := i.shastaInbox.ActivationTimestamp(nil)
	if err != nil {
		return 0, errors.Wrap(err, "shastaInbox.ActivationTimestamp")
	}

	blockNum, err := i.getBlockByTimestamp(ctx, ts.Uint64())
	if err != nil {
		return 0, errors.Wrap(err, "getBlockByTimestamp")
	}

	return blockNum, nil
}
