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

// FilterThenSubscribe gets the most recent block height that has been indexed, and works it's way
// up to the latest block. As it goes, it tries to process messages.
// When it catches up, it then starts to Subscribe to latest events as they come in.
func (svc *Service) FilterThenSubscribe(ctx context.Context, eventName string, caughtUp chan struct{}) error {
	log.Info("indexing starting")
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

	header, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.HeaderByNumber")
	}

	log.Infof("latest header: %v", header.Number)

	// if we have already done the latest block, exit early
	if latestProcessedBlock.Height == header.Number.Uint64() {
		log.Info("already caught up")
		caughtUp <- struct{}{}
		return nil
	}

	const batchSize = 1000
	svc.processingBlock = latestProcessedBlock
	log.Infof("getting events between %v and %v in batches of %v", svc.processingBlock.Height, header.Number.Int64(), batchSize)

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
			if err := svc.handleNoEventsInBatch(ctx, eventName, chainID, int64(end)); err != nil {
				return errors.Wrap(err, "s.handleNoEventsInBatch")
			}
			continue
		}

		log.Info("found events")

		for {
			if err := svc.handleEvent(ctx, eventName, chainID, events.Event); err != nil {
				return errors.Wrap(err, "svc.handleEvent")
			}
			if !events.Next() {
				log.Info("no events remaining to be processed")
				if events.Error() != nil {
					return errors.Wrap(err, "events.Error")
				}
				log.Infof("saving new latest processed block to DB: %v", events.Event.Raw.BlockNumber)
				if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
					Height:    events.Event.Raw.BlockNumber,
					Hash:      events.Event.Raw.BlockHash,
					ChainID:   chainID,
					EventName: eventName,
				}); err != nil {
					return errors.Wrap(err, "s.blockRepo.Save")
				}
				break
			}
		}
	}

	log.Info("indexer fully caught up")
	// TODO: check latest block number. if its diff than our latest block number,
	// no new blocks came in while we were catching up. subscribe to recent events instead.
	// otherwise, recursively call FilterThenSubscribe now to catch up again. this will
	// repeat until we are actually caught up after a catch up, and we can then subscribe, knowing
	// we havent missed any past messages.
	caughtUp <- struct{}{}

	return nil
}

func (svc *Service) handleEvent(ctx context.Context, eventName string, chainID *big.Int, event *contracts.BridgeMessageSent) error {
	log.Infof("event found. signal:%v", common.Hash(event.Signal).Hex())
	log.Infof("for block number %v", event.Raw.BlockNumber)
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}
	raw := event.Raw

	// save event to database for later processing outside
	// the indexer
	log.Info("saving event to database")
	eventStatus := relayer.EventStatusNew
	// if gasLimit is 0, relayer can not process this.
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(big.NewInt(0)) == 0 {
		eventStatus = relayer.EventStatusNewOnlyOwner
	}
	e, err := svc.eventRepo.Save(relayer.SaveEventOpts{
		Name:    eventName,
		Data:    string(marshaled),
		ChainID: chainID,
		Status:  eventStatus,
	})
	if err != nil {
		return errors.Wrap(err, "s.eventRepo.Save")
	}

	// we can not process, exit early
	if eventStatus == relayer.EventStatusNewOnlyOwner {
		log.Infof("gasLimit == 0, can not process. continuing loop")
		return nil
	}

	messageStatus, err := svc.crossLayerBridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
	if err != nil {
		return errors.Wrap(err, "bridge.GetMessageStatus")
	}

	if messageStatus == uint8(relayer.EventStatusNew) {
		log.Info("message not processed yet, attempting processing")
		// process the message
		if err := svc.processMessage(ctx, event, e); err != nil {
			return errors.Wrap(err, "s.processMessage")
		}

	}

	// if the block number is higher than the one we are processing,
	// we can now consider that one processed. save it to the DB
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
			return errors.Wrap(err, "s.blockRepo.Save")
		}
		svc.processingBlock = &relayer.Block{
			Height:    raw.BlockNumber,
			Hash:      raw.BlockHash.Hex(),
			EventName: eventName,
		}
	}

	return nil
}

func (s *Service) handleNoEventsInBatch(ctx context.Context, eventName string, chainID *big.Int, blockNumber int64) error {
	log.Infof("no events in batch")
	header, err := s.ethClient.HeaderByNumber(ctx, big.NewInt(blockNumber))
	if err != nil {
		return errors.Wrap(err, "s.ethClient.HeaderByNumber")
	}
	log.Infof("setting last processed block to height: %v, hash: %v", blockNumber, header.Hash().Hex())
	if err := s.blockRepo.Save(relayer.SaveBlockOpts{
		Height:    uint64(blockNumber),
		Hash:      header.Hash(),
		ChainID:   chainID,
		EventName: eventName,
	}); err != nil {
		return errors.Wrap(err, "s.blockRepo.Save")
	}
	s.processingBlock = &relayer.Block{
		Height: uint64(blockNumber),
		Hash:   header.Hash().Hex(),
	}

	return nil
}
