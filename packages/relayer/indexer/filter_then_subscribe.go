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
func (s *Service) FilterThenSubscribe(ctx context.Context, eventName string, bridgeAddress string, crossLayerBridgeAddress string, caughtUp chan struct{}) error {
	log.Info("indexing starting")
	chainID, err := s.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.ChainID()")
	}

	// get most recently processed block height from the DB
	latestProcessedBlock, err := s.blockRepo.GetLatestBlockProcessedForEvent(
		eventName,
		chainID,
	)
	if err != nil {
		return errors.Wrap(err, "s.blockRepo.GetLatestBlock()")
	}
	log.Infof("latest processed block: %v", latestProcessedBlock.Height)

	header, err := s.ethClient.HeaderByNumber(ctx, nil)
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

	// instantiate bridge contract and filter for messages
	// starting from the most recently processed block,
	// and ending at the latest.
	bridge, err := contracts.NewBridge(common.HexToAddress(bridgeAddress), s.ethClient)
	if err != nil {
		return errors.Wrap(err, "contracts.NewBridge")
	}

	crossLayerBridge, err := contracts.NewBridge(common.HexToAddress(crossLayerBridgeAddress), s.crossLayerEthClient)
	if err != nil {
		return errors.Wrap(err, "contracts.NewBridge")
	}
	const batchSize = 1000
	processingBlock := latestProcessedBlock
	log.Infof("getting events between %v and %v in batches of %v", processingBlock.Height, header.Number.Int64(), batchSize)

	// todo: parallelize/concurrently catch up. don't think we need to do this in order.
	// use WaitGroup.
	// we get a timeout/EOF if we don't batch.
	for i := latestProcessedBlock.Height; i < header.Number.Uint64(); i += batchSize {
		var end uint64 = processingBlock.Height + batchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > header.Number.Uint64() {
			end = header.Number.Uint64()
		}
		log.Infof("batch from %v to %v", i, end)
		events, err := bridge.FilterMessageSent(&bind.FilterOpts{
			Start:   latestProcessedBlock.Height + uint64(1),
			End:     &end,
			Context: ctx,
		}, nil)
		if err != nil {
			return errors.Wrap(err, "bridge.FilterMessageSent")
		}

		if !events.Next() || events.Event == nil {
			log.Infof("no events in batch")
			header, err := s.ethClient.HeaderByNumber(ctx, big.NewInt(int64(end)))
			if err != nil {
				return errors.Wrap(err, "s.ethClient.HeaderByNumber")
			}
			log.Infof("setting last processed block to height: %v, hash: %v", end, header.Hash().Hex())
			if err := s.blockRepo.Save(relayer.SaveBlockOpts{
				Height:    end,
				Hash:      header.Hash(),
				ChainID:   chainID,
				EventName: eventName,
			}); err != nil {
				return errors.Wrap(err, "s.blockRepo.Save")
			}
			processingBlock = &relayer.Block{
				Height: end,
				Hash:   header.Hash().Hex(),
			}
			continue
		}

		log.Info("found events")

		for {
			event := events.Event
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
			e, err := s.eventRepo.Save(relayer.SaveEventOpts{
				Name:    eventName,
				Data:    string(marshaled),
				ChainID: chainID,
			})
			if err != nil {
				return errors.Wrap(err, "s.eventRepo.Save")
			}

			status, err := crossLayerBridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
			if err != nil {
				return errors.Wrap(err, "bridge.GetMessageStatus")
			}

			if status == uint8(relayer.EventStatusNew) {
				log.Info("message not processed yet, attempting processing")
				// process the message
				if err := s.processMessage(ctx, event, e, crossLayerBridgeAddress); err != nil {
					return errors.Wrap(err, "s.processMessage")
				}

			}

			// if the block number is higher than the one we are processing,
			// we can now consider that one processed. save it to the DB
			// and bump the block number.
			if raw.BlockNumber > processingBlock.Height {
				log.Info("raw blockNumber > processingBlock.height")
				log.Infof("saving new latest processed block to DB: %v", raw.BlockNumber)
				if err := s.blockRepo.Save(relayer.SaveBlockOpts{
					Height:    processingBlock.Height,
					Hash:      common.HexToHash(processingBlock.Hash),
					ChainID:   chainID,
					EventName: eventName,
				}); err != nil {
					return errors.Wrap(err, "s.blockRepo.Save")
				}
				processingBlock = &relayer.Block{
					Height:    raw.BlockNumber,
					Hash:      raw.BlockHash.Hex(),
					EventName: eventName,
				}
			}

			if !events.Next() {
				log.Info("no events remaining to be processed")
				if events.Error() != nil {
					return errors.Wrap(err, "events.Error")
				}
				log.Infof("saving new latest processed block to DB: %v", raw.BlockNumber)
				if err := s.blockRepo.Save(relayer.SaveBlockOpts{
					Height:    raw.BlockNumber,
					Hash:      raw.BlockHash,
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
	caughtUp <- struct{}{}

	return nil
}
