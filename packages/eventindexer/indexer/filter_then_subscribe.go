package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
)

func (i *Indexer) filter(
	ctx context.Context,
	filter FilterFunc,
) error {
	n, err := i.eventRepo.FindLatestBlockID(i.srcChainID)
	if err != nil {
		return err
	}

	i.latestIndexedBlockNumber = n

	header, err := i.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.HeaderByNumber")
	}

	// the end block is the latest header.
	endBlockID := header.Number.Uint64()

	slog.Info("getting batch of events",
		"startBlock", i.latestIndexedBlockNumber,
		"endBlock", header.Number.Int64(),
		"batchSize", i.blockBatchSize,
	)

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += i.blockBatchSize {
		end := i.latestIndexedBlockNumber + i.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > endBlockID {
			end = endBlockID
		}

		slog.Info("block batch", "start", j, "end", end)

		filterOpts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: ctx,
		}

		if err := filter(ctx, new(big.Int).SetUint64(i.srcChainID), i, filterOpts); err != nil {
			return errors.Wrap(err, "filter")
		}

		i.latestIndexedBlockNumber = end
	}

	return nil
}
