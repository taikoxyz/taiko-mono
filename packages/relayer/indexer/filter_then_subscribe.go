package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

var (
	eventName = relayer.EventNameMessageSent
)

// FilterThenSubscribe gets the most recent block height that has been indexed, and works it's way
// up to the latest block. As it goes, it tries to process messages.
// When it catches up, it then starts to Subscribe to latest events as they come in.
func (svc *Service) FilterThenSubscribe(ctx context.Context) error {
	chainID, err := svc.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.ChainID()")
	}

	// get most recently processed block height from the DB
	latestProcessedBlock, err := svc.blockRepo.GetLatestBlockProcessedForEvent(
		eventName,
		chainID,
	)
	if err != nil {
		return errors.Wrap(err, "s.blockRepo.GetLatestBlock()")
	}

	log.Infof("latest processed block: %v", latestProcessedBlock.Height)

	if err != nil {
		return errors.Wrap(err, "bridge.FilterMessageSent")
	}

	header, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.HeaderByNumber")
	}

	// if we have already done the latest block, exit early
	// TODO: call SubscribeMessageSent, as we can now just watch the chain for new blocks
	if latestProcessedBlock.Height == header.Number.Uint64() {
		return svc.subscribe(ctx, chainID)
	}

	const batchSize = 1000

	svc.processingBlock = latestProcessedBlock

	log.Infof("getting events between %v and %v in batches of %v",
		svc.processingBlock.Height,
		header.Number.Int64(),
		batchSize,
	)

	// todo: parallelize/concurrently catch up. don't think we need to do this in order.
	// use WaitGroup.
	// we get a timeout/EOF if we don't batch.
	for i := latestProcessedBlock.Height; i < header.Number.Uint64(); i += batchSize {
		var end uint64 = svc.processingBlock.Height + batchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > header.Number.Uint64() {
			end = header.Number.Uint64()
		}

		log.Infof("batch from %v to %v", i, end)

		events, err := svc.bridge.FilterMessageSent(&bind.FilterOpts{
			Start:   latestProcessedBlock.Height + uint64(1),
			End:     &end,
			Context: ctx,
		}, nil)
		if err != nil {
			return errors.Wrap(err, "bridge.FilterMessageSent")
		}

		if !events.Next() || events.Event == nil {
			if err := svc.handleNoEventsInBatch(ctx, chainID, int64(end)); err != nil {
				return errors.Wrap(err, "s.handleNoEventsInBatch")
			}

			continue
		}

		log.Info("found events")

		for {
			if err := svc.handleEvent(ctx, chainID, events.Event); err != nil {
				return errors.Wrap(err, "svc.handleEvent")
			}

			if !events.Next() {
				if err := svc.handleNoEventsRemaining(ctx, chainID, events); err != nil {
					return errors.Wrap(err, "svc.handleNoEventsRemaining")
				}

				break
			}
		}
	}

	log.Info("indexer fully caught up, checking latest block number to see if it's advanced")

	latestBlock, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethclient.HeaderByNumber")
	}

	if svc.processingBlock.Height < latestBlock.Number.Uint64() {
		return svc.FilterThenSubscribe(ctx)
	}

	return svc.subscribe(ctx, chainID)
}

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	sink := make(chan *contracts.BridgeMessageSent)

	sub, err := svc.bridge.WatchMessageSent(&bind.WatchOpts{}, sink, nil)
	if err != nil {
		return errors.Wrap(err, "svc.bridge.WatchMessageSent")
	}

	defer sub.Unsubscribe()

	for {
		select {
		case err := <-sub.Err():
			return err
		case event := <-sink:
			if err := svc.handleEvent(ctx, chainID, event); err != nil {
				return errors.Wrap(err, "svc.handleEvent")
			}
		}
	}
}

// handleEvent handles an individual MessageSent event
func (svc *Service) handleEvent(ctx context.Context, chainID *big.Int, event *contracts.BridgeMessageSent) error {
	log.Infof("event found. signal:%v for block: %v", common.Hash(event.Signal).Hex(), event.Raw.BlockNumber)

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	raw := event.Raw

	// handle chain re-org by checking Removed property, no need to
	// return error, just continue and do not process.
	if raw.Removed {
		return nil
	}

	// save event to database for later processing outside
	// the indexer
	log.Info("saving event to database")

	eventStatus := relayer.EventStatusNew
	// if gasLimit is 0, relayer can not process this.
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		eventStatus = relayer.EventStatusNewOnlyOwner
	}

	e, err := svc.eventRepo.Save(ctx, relayer.SaveEventOpts{
		Name:    eventName,
		Data:    string(marshaled),
		ChainID: chainID,
		Status:  eventStatus,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	// we can not process, exit early
	if eventStatus == relayer.EventStatusNewOnlyOwner && event.Message.Owner != svc.relayerAddr {
		log.Infof("gasLimit == 0 and owner is not the current relayer key, can not process. continuing loop")
		return nil
	}

	messageStatus, err := svc.destBridge.GetMessageStatus(nil, event.Signal)
	if err != nil {
		return errors.Wrap(err, "svc.destBridge.GetMessageStatus")
	}

	if messageStatus == uint8(relayer.EventStatusNew) {
		log.Info("message not processed yet, attempting processing")
		// process the message
		if err := svc.processor.ProcessMessage(ctx, event, e); err != nil {
			// TODO: handle error here, update in eventRepo, continue on in processing
			return errors.Wrap(err, "svc.processMessage")
		}
	}

	// if the block number of the event is higher than the block we are processing,
	// we can now consider that previous block processed. save it to the DB
	// and bump the block number.
	if raw.BlockNumber > svc.processingBlock.Height {
		log.Info("raw blockNumber > processingBlock.height")
		log.Infof("saving new latest processed block to DB: %v", raw.BlockNumber)

		if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
			Height:    svc.processingBlock.Height,
			Hash:      common.HexToHash(svc.processingBlock.Hash),
			ChainID:   chainID,
			EventName: eventName,
		}); err != nil {
			return errors.Wrap(err, "svc.blockRepo.Save")
		}

		svc.processingBlock = &relayer.Block{
			Height: raw.BlockNumber,
			Hash:   raw.BlockHash.Hex(),
		}
	}

	return nil
}

// handleNoEventsRemaining is used when the batch had events, but is now finished, and we need to
// update the latest block processed
func (svc *Service) handleNoEventsRemaining(
	ctx context.Context,
	chainID *big.Int,
	events *contracts.BridgeMessageSentIterator,
) error {
	log.Info("no events remaining to be processed")

	if events.Error() != nil {
		return errors.Wrap(events.Error(), "events.Error")
	}

	log.Infof("saving new latest processed block to DB: %v", events.Event.Raw.BlockNumber)

	if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
		Height:    events.Event.Raw.BlockNumber,
		Hash:      events.Event.Raw.BlockHash,
		ChainID:   chainID,
		EventName: eventName,
	}); err != nil {
		return errors.Wrap(err, "svc.blockRepo.Save")
	}

	return nil
}

// handleNoEventsInBatch is used when an entire batch call has no events in the entire response,
// and we need to update the latest block processed
func (svc *Service) handleNoEventsInBatch(ctx context.Context, chainID *big.Int, blockNumber int64) error {
	log.Infof("no events in batch")

	header, err := svc.ethClient.HeaderByNumber(ctx, big.NewInt(blockNumber))
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.HeaderByNumber")
	}

	log.Infof("setting last processed block to height: %v, hash: %v", blockNumber, header.Hash().Hex())

	if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
		Height:    uint64(blockNumber),
		Hash:      header.Hash(),
		ChainID:   chainID,
		EventName: eventName,
	}); err != nil {
		return errors.Wrap(err, "svc.blockRepo.Save")
	}

	svc.processingBlock = &relayer.Block{
		Height: uint64(blockNumber),
		Hash:   header.Hash().Hex(),
	}

	return nil
}
