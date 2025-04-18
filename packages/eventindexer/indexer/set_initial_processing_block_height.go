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
				return errors.Wrap(err, "i.taikol1.GetStateVariables")
			}

			startingBlock = slotA.GenesisHeight
		} else {
			startingBlock = slotA.GenesisHeight
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
