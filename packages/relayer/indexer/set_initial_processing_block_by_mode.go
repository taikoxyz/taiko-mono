package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (svc *Service) setInitialProcessingBlockByMode(
	ctx context.Context,
	mode relayer.Mode,
	chainID *big.Int,
) error {
	switch mode {
	case relayer.SyncMode:
		// get most recently processed block height from the DB
		latestProcessedBlock, err := svc.blockRepo.GetLatestBlockProcessedForEvent(
			eventName,
			chainID,
		)
		if err != nil {
			return errors.Wrap(err, "svc.blockRepo.GetLatestBlock()")
		}

		svc.processingBlockHeight = latestProcessedBlock.Height
		if svc.processingBlockHeight == 0 && svc.taikol1 != nil {
			genesis, _, _, _, err := svc.taikol1.GetStateVariables(nil)
			if err != nil {
				return errors.Wrap(err, "svc.taikoL1.GetStateVariables")
			}

			svc.processingBlockHeight = genesis
		}

		return nil
	case relayer.ResyncMode:
		svc.processingBlockHeight = 0
		return nil
	default:
		return relayer.ErrInvalidMode
	}
}
