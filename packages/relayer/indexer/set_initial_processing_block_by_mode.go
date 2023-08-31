package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (i *Indexer) setInitialProcessingBlockByMode(
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

		startingBlock = stateVars.GenesisHeight
	}

	switch mode {
	case Sync:
		// get most recently processed block height from the DB
		latestProcessedBlock, err := i.blockRepo.GetLatestBlockProcessedForEvent(
			eventName,
			chainID,
		)
		if err != nil {
			return errors.Wrap(err, "svc.blockRepo.GetLatestBlock()")
		}

		if latestProcessedBlock.Height != 0 {
			startingBlock = latestProcessedBlock.Height
		}

		i.processingBlockHeight = startingBlock

		return nil
	case Resync:
		i.processingBlockHeight = startingBlock
		return nil
	default:
		return relayer.ErrInvalidMode
	}
}
