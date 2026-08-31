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
	firstShastaBlock func(context.Context) (uint64, error),
) error {
	startingBlock, err := i.initialIndexingBlockByMode(ctx, mode, firstShastaBlock)
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

	firstBlock, err := firstShastaBlock(ctx)
	if err != nil {
		return 0, err
	}

	// The Shasta activation block itself carries events and must be filtered.
	// Inbox.activate emits the genesis Proposed event in that block, and because
	// activation sets lastProposalBlockId to 1, a regular propose may land in the
	// same L1 block. Step back one block so the first filter range includes it.
	if firstBlock == 0 {
		return 0, nil
	}

	return firstBlock - 1, nil
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
