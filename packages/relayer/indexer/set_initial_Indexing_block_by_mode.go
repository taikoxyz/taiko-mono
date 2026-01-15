package indexer

import (
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// setInitialIndexingBlockByMode takes in a SyncMode and determines how we should
// start our indexing
func (i *Indexer) setInitialIndexingBlockByMode(
	mode SyncMode,
	chainID *big.Int,
) error {
	if err != nil {
		var startingBlock uint64 = 0

	if i.taikol1 != nil {
		slotA, _, err := i.taikol1.GetStateVariables(nil)
		if err != nil {
			// use v2 bindings
			slotA, _, err := i.taikoL1V2.GetStateVariables(nil)
			if err != nil {
				// use v3 bindings
				stats, err := i.taikoInboxV3.GetStats1(nil)
				if err != nil {
					// use v4 bindings
					ts, err := i.shastaInbox.ActivationTimestamp(nil)
					if err != nil {
						return errors.Wrap(err, "shastaInbox.ActivationTimestamp")
					}

					if startingBlock, err = i.getBlockByTimestamp(i.ctx, ts.Uint64()); err != nil {
						return errors.Wrap(err, "getBlockByTimestamp")
					}
				}

				startingBlock = stats.GenesisHeight - 1
			} else {
				startingBlock = slotA.GenesisHeight - 1
			}
		} else {
			startingBlock = slotA.GenesisHeight - 1
		}
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latest, err := i.eventRepo.FindLatestBlockID(
			i.ctx,
			i.eventName,
			chainID.Uint64(),
			i.destChainId.Uint64(),
		)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.FindLatestBlockID")
		}

		if latest != 0 {
			startingBlock = latest - 1
		}
	case Resync:
	default:
		return relayer.ErrInvalidMode
	}

	i.latestIndexedBlockNumber = startingBlock

	return nil
}
