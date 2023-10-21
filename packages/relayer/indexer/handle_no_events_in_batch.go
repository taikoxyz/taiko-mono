package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// handleNoEventsInBatch is used when an entire batch call has no events in the entire response,
// and we need to update the latest block processed
func (i *Indexer) handleNoEventsInBatch(
	ctx context.Context,
	chainID *big.Int,
	blockNumber int64,
) error {
	header, err := i.srcEthClient.HeaderByNumber(ctx, big.NewInt(blockNumber))
	if err != nil {
		return errors.Wrap(err, "i.srcEthClient.HeaderByNumber")
	}

	slog.Info("setting last processed block", "blockNum", blockNumber, "headerHash", header.Hash().Hex())

	if err := i.blockRepo.Save(relayer.SaveBlockOpts{
		Height:    uint64(blockNumber),
		Hash:      header.Hash(),
		ChainID:   chainID,
		EventName: eventName,
	}); err != nil {
		return errors.Wrap(err, "svc.blockRepo.Save")
	}

	relayer.BlocksProcessed.Inc()

	i.processingBlockHeight = uint64(blockNumber)

	return nil
}
