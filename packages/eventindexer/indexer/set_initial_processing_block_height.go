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
	startingBlock, err := i.initialIndexingBlockByMode(ctx, mode)
	if err != nil {
		return err
	}

	slog.Info("startingBlock", "startingBlock", startingBlock)
	i.latestIndexedBlockNumber = startingBlock

	return nil
}

// initialIndexingBlockByMode resolves the cursor to start indexing from. The
// result is the last *processed* block, so filtering resumes at the block after
// it. See Indexer.nextFilterStartBlock.
func (i *Indexer) initialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
) (uint64, error) {
	switch mode {
	case Sync, Resync:
	default:
		return 0, eventindexer.ErrInvalidMode
	}

	if mode == Sync {
		checkpoint, found, err := i.nftCursorRepo.FindCheckpoint(ctx, i.srcChainID)
		if err != nil {
			return 0, errors.Wrap(err, "read NFT checkpoint")
		}

		if found {
			return checkpoint, nil
		}

		latest, err := i.nftCursorRepo.FindLatestBlockID(ctx,
			i.srcChainID,
		)
		if err != nil {
			return 0, errors.Wrap(err, "svc.nftCursorRepo.FindLatestBlockID")
		}

		if latest != 0 {
			return latest - 1, nil
		}
	}

	return 0, nil
}
