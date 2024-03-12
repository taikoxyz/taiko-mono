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
		stateVars, err := i.taikol1.GetStateVariables(nil)
		if err != nil {
			return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
		}

		startingBlock = stateVars.A.GenesisHeight - 1
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latestProcessedBlock, err := i.blockRepo.GetLatestBlockProcessedForEvent(
			i.eventName,
			chainID,
			i.destChainId,
		)
		if err != nil {
			return errors.Wrap(err, "svc.blockRepo.GetLatestBlock()")
		}

		if latestProcessedBlock.Height != 0 {
			startingBlock = latestProcessedBlock.Height - 1
		}
	case Resync:
	default:
		return relayer.ErrInvalidMode
	}

	i.latestIndexedBlockNumber = startingBlock

	return nil
}
