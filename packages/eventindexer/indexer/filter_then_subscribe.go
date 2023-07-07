package indexer

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (svc *Service) FilterThenSubscribe(
	ctx context.Context,
	mode eventindexer.Mode,
	watchMode eventindexer.WatchMode,
	filter FilterFunc,
) error {
	chainID, err := svc.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.ChainID()")
	}

	if watchMode == eventindexer.SubscribeWatchMode {
		return svc.subscribe(ctx, chainID)
	}

	if err := svc.setInitialProcessingBlockByMode(ctx, mode, chainID); err != nil {
		return errors.Wrap(err, "svc.setInitialProcessingBlockByMode")
	}

	header, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.HeaderByNumber")
	}

	if svc.processingBlockHeight == header.Number.Uint64() {
		log.Infof("chain ID %v caught up, subscribing to new incoming events", chainID.Uint64())
		return svc.subscribe(ctx, chainID)
	}

	log.Infof("chain ID %v getting events between %v and %v in batches of %v",
		chainID.Uint64(),
		svc.processingBlockHeight,
		header.Number.Int64(),
		svc.blockBatchSize,
	)

	for i := svc.processingBlockHeight; i < header.Number.Uint64(); i += svc.blockBatchSize {
		end := svc.processingBlockHeight + svc.blockBatchSize
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
			Start:   svc.processingBlockHeight,
			End:     &filterEnd,
			Context: ctx,
		}

		if err := filter(ctx, chainID, svc, filterOpts); err != nil {
			return errors.Wrap(err, "filter")
		}

		header, err := svc.ethClient.HeaderByNumber(ctx, big.NewInt(int64(end)))
		if err != nil {
			return errors.Wrap(err, "svc.ethClient.HeaderByNumber")
		}

		log.Infof("setting last processed block to height: %v, hash: %v", end, header.Hash().Hex())

		if err := svc.blockRepo.Save(eventindexer.SaveBlockOpts{
			Height:  uint64(end),
			Hash:    header.Hash(),
			ChainID: chainID,
		}); err != nil {
			return errors.Wrap(err, "svc.blockRepo.Save")
		}

		eventindexer.BlocksProcessed.Inc()

		svc.processingBlockHeight = uint64(end)
	}

	log.Infof(
		"chain id %v indexer fully caught up, checking latest block number to see if it's advanced",
		chainID.Uint64(),
	)

	latestBlock, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethclient.HeaderByNumber")
	}

	if svc.processingBlockHeight < latestBlock.Number.Uint64() {
		return svc.FilterThenSubscribe(ctx, eventindexer.SyncMode, watchMode, filter)
	}

	// we are caught up and specified not to subscribe, we can return now
	if watchMode == eventindexer.FilterWatchMode {
		return nil
	}

	return svc.subscribe(ctx, chainID)
}
