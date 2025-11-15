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
	var startingBlock uint64 = 0
	// only check stateVars on L1, otherwise sync from 0
	if i.taikol1 != nil {
		slotA, _, err := i.taikol1.GetStateVariables(nil)
		if err != nil {
			// check v2
			slotA, _, err := i.taikol1V2.GetStateVariables(nil)
			if err != nil {
				// check v3
				stats1, err := i.taikoInbox.GetStats1(nil)
				if err != nil {
					return errors.Wrap(err, "i.taikoInbox.GetStats1")
				}

				if stats1.GenesisHeight > 0 {
					startingBlock = stats1.GenesisHeight - 1
				} else {
					startingBlock = 0
				}
			} else {
				if slotA.GenesisHeight > 0 {
					startingBlock = slotA.GenesisHeight - 1
				} else {
					startingBlock = 0
				}
			}
		} else {
			if slotA.GenesisHeight > 0 {
				startingBlock = slotA.GenesisHeight - 1
			} else {
				startingBlock = 0
			}
		}
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
