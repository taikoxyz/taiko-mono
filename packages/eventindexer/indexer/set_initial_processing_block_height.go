package indexer

import (
	"context"
	"log/slog"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (indxr *Indexer) setInitialProcessingBlockByMode(
	ctx context.Context,
	mode SyncMode,
	chainID *big.Int,
) error {
	var startingBlock uint64 = 0
	// only check stateVars on L1, otherwise sync from 0
	if indxr.taikol1 != nil {
		stateVars, err := indxr.taikol1.GetStateVariables(nil)
		if err != nil {
			return errors.Wrap(err, "indxr.taikoL1.GetStateVariables")
		}

		startingBlock = stateVars.GenesisHeight
	}

	switch mode {
	case Sync:
		latestProcessedBlock, err := indxr.processedBlockRepo.GetLatestBlockProcessed(
			chainID,
		)
		if err != nil {
			return errors.Wrap(err, "indxr.processedBlockRepo.GetLatestBlock()")
		}

		if latestProcessedBlock.Height != 0 {
			startingBlock = latestProcessedBlock.Height
		}

		slog.Info("set processingBlockHeight", "startingBlock", startingBlock)

		indxr.processingBlockHeight = startingBlock

		return nil
	case Resync:
		indxr.processingBlockHeight = startingBlock
		return nil
	default:
		return eventindexer.ErrInvalidMode
	}
}
