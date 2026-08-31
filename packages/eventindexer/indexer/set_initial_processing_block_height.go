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
	startingBlock, err := i.initialIndexingBlockByMode(
		ctx,
		mode,
		i.getFirstShastaBlockHeight,
	)
	if err != nil {
		return err
	}

	slog.Info("startingBlock", "startingBlock", startingBlock)
	i.latestIndexedBlockNumber = startingBlock

	return nil
}

func (i *Indexer) initialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
	firstShastaBlock func(context.Context) (uint64, error),
) (uint64, error) {
	switch mode {
	case Sync, Resync:
	default:
		return 0, eventindexer.ErrInvalidMode
	}

	if mode == Sync {
		latest, err := i.eventRepo.FindLatestBlockID(ctx,
			i.srcChainID,
		)
		if err != nil {
			return 0, errors.Wrap(err, "svc.eventRepo.FindLatestBlockID")
		}

		if latest != 0 {
			return latest - 1, nil
		}
	}

	if i.layer == Layer2 {
		return 0, nil
	}

	return firstShastaBlock(ctx)
}

// getFirstShastaBlockHeight returns the first Shasta block height.
func (i *Indexer) getFirstShastaBlockHeight(ctx context.Context) (uint64, error) {
	if i.inbox == nil {
		return 0, errors.New("inbox contract not configured")
	}

	ts, err := i.inbox.ActivationTimestamp(nil)
	if err != nil {
		return 0, errors.Wrap(err, "inbox.ActivationTimestamp")
	}

	blockNum, err := i.getBlockByTimestamp(ctx, ts.Uint64())
	if err != nil {
		return 0, errors.Wrap(err, "getBlockByTimestamp")
	}

	return blockNum, nil
}
