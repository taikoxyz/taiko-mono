package indexer

import (
	"context"
	"fmt"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (indxr *Indexer) filterThenSubscribe(
	ctx context.Context,
	filter FilterFunc,
) error {
	chainID, err := indxr.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.ChainID()")
	}

	if indxr.watchMode == Subscribe {
		return indxr.subscribe(ctx, chainID)
	}

	if err := indxr.setInitialProcessingBlockByMode(ctx, indxr.syncMode, chainID); err != nil {
		return errors.Wrap(err, "indxr.setInitialProcessingBlockByMode")
	}

	header, err := indxr.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.HeaderByNumber")
	}

	if indxr.processingBlockHeight == header.Number.Uint64() {
		slog.Info("indexing caught up subscribing to new incoming events", "chainID", chainID.Uint64())
		return indxr.subscribe(ctx, chainID)
	}

	slog.Info("getting batch of events",
		"chainID", chainID.Uint64(),
		"startBlock", indxr.processingBlockHeight,
		"endBlock", header.Number.Int64(),
		"batchSize", indxr.blockBatchSize,
	)

	for i := indxr.processingBlockHeight; i < header.Number.Uint64(); i += indxr.blockBatchSize {
		end := indxr.processingBlockHeight + indxr.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > header.Number.Uint64() {
			end = header.Number.Uint64()
		}

		// filter exclusive of the end block.
		// we use "end" as the next starting point of the batch, and
		// process up to end - 1 for this batch.
		filterEnd := end - 1

		fmt.Printf("block batch from %v to %v", i, filterEnd)
		fmt.Println()

		filterOpts := &bind.FilterOpts{
			Start:   indxr.processingBlockHeight,
			End:     &filterEnd,
			Context: ctx,
		}

		if err := filter(ctx, chainID, indxr, filterOpts); err != nil {
			return errors.Wrap(err, "filter")
		}

		header, err := indxr.ethClient.HeaderByNumber(ctx, big.NewInt(int64(end)))
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.HeaderByNumber")
		}

		slog.Info("setting last processed block", "height", end, "hash", header.Hash().Hex())

		if err := indxr.processedBlockRepo.Save(eventindexer.SaveProcessedBlockOpts{
			Height:  uint64(end),
			Hash:    header.Hash(),
			ChainID: chainID,
		}); err != nil {
			return errors.Wrap(err, "indxr.blockRepo.Save")
		}

		eventindexer.BlocksProcessed.Inc()

		indxr.processingBlockHeight = uint64(end)
	}

	slog.Info(
		"fully caught up, checking blockNumber to see if advanced",
		"chainID", chainID.Uint64(),
	)

	latestBlock, err := indxr.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "indxr.ethclient.HeaderByNumber")
	}

	if indxr.processingBlockHeight < latestBlock.Number.Uint64() {
		return indxr.filterThenSubscribe(ctx, filter)
	}

	// we are caught up and specified not to subscribe, we can return now
	if indxr.watchMode == Filter {
		return nil
	}

	return indxr.subscribe(ctx, chainID)
}
