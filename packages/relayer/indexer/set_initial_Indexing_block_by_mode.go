package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// setInitialIndexingBlockByMode takes in a SyncMode and determines how we should
// start our indexing
func (i *Indexer) setInitialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
	chainID *big.Int,
) error {
	var startingBlock uint64 = 0

	if i.taikol1 != nil {
		slotA, _, err := i.taikol1.GetStateVariables(nil)
		if err != nil {
			return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
		}

		startingBlock = slotA.GenesisHeight - 1
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latest, err := i.eventRepo.FindLatestBlockID(
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
