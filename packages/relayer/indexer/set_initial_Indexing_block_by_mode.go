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
	i.latestIndexedBlockNumber = 0

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
			i.latestIndexedBlockNumber = latest - 1
		}
	case Resync:
		if i.taikol1 != nil {
			slotA, _, err := i.taikol1.GetStateVariables(nil)
			if err != nil {
				return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
			}

			i.latestIndexedBlockNumber = slotA.GenesisHeight - 1
		}
	default:
		return relayer.ErrInvalidMode
	}

	return nil
}
