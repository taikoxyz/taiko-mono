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
			return errors.Wrap(err, "s.blockRepo.GetLatestBlock()")
		}

		svc.processingBlock = latestProcessedBlock

		return nil
	case relayer.ResyncMode:
		header, err := svc.ethClient.HeaderByNumber(ctx, big.NewInt(0))
		if err != nil {
			return errors.Wrap(err, "s.blockRepo.GetLatestBlock()")
		}

		svc.processingBlock = &relayer.Block{
			Height: header.Number.Uint64(),
			Hash:   header.Hash().Hex(),
		}

		return nil
	default:
		return relayer.ErrInvalidMode
	}
}
