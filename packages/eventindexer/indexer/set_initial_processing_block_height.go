package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (svc *Service) setInitialProcessingBlockByMode(
	ctx context.Context,
	mode eventindexer.Mode,
	chainID *big.Int,
) error {
	stateVars, err := svc.taikol1.GetStateVariables(nil)
	if err != nil {
		return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
	}

	startingBlock := stateVars.GenesisHeight

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

		svc.processingBlockHeight = startingBlock

		return nil
	case eventindexer.ResyncMode:
		svc.processingBlockHeight = startingBlock
		return nil
	default:
		return eventindexer.ErrInvalidMode
	}
}
