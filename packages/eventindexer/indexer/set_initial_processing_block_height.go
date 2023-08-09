package indexer

import (
	"context"
	"log/slog"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (svc *Service) setInitialProcessingBlockByMode(
	ctx context.Context,
	mode eventindexer.Mode,
	chainID *big.Int,
) error {
	var startingBlock uint64 = 0
	// only check stateVars on L1, otherwise sync from 0
	if svc.taikol1 != nil {
		stateVars, err := svc.taikol1.GetStateVariables(nil)
		if err != nil {
			return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
		}

		startingBlock = stateVars.GenesisHeight
	}

	switch mode {
	case eventindexer.SyncMode:
		latestProcessedBlock, err := svc.blockRepo.GetLatestBlockProcessed(
			chainID,
		)
		if err != nil {
			return errors.Wrap(err, "svc.blockRepo.GetLatestBlock()")
		}

		if latestProcessedBlock.Height != 0 {
			startingBlock = latestProcessedBlock.Height
		}

		slog.Info("set processingBlockHeight", "startingBlock", startingBlock)

		svc.processingBlockHeight = startingBlock

		return nil
	case eventindexer.ResyncMode:
		svc.processingBlockHeight = startingBlock
		return nil
	default:
		return eventindexer.ErrInvalidMode
	}
}
