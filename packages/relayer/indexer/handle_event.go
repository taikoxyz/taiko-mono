package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

// handleEvent handles an individual MessageSent event
func (svc *Service) handleEvent(
	ctx context.Context,
	wg *sync.WaitGroup,
	errChan chan error,
	chainID *big.Int,
	event *contracts.BridgeMessageSent,
) {
	if wg != nil {
		wg.Add(1)
		defer wg.Done()
	}

	raw := event.Raw

	// handle chain re-org by checking Removed property, no need to
	// return error, just continue and do not process.
	if raw.Removed {
		return
	}

	eventStatus := relayer.EventStatusNew
	// if gasLimit is 0, relayer can not process this.
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		eventStatus = relayer.EventStatusNewOnlyOwner
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		errChan <- errors.Wrap(err, "json.Marshal(event)")
	}

	e, err := svc.eventRepo.Save(relayer.SaveEventOpts{
		Name:    eventName,
		Data:    string(marshaled),
		ChainID: chainID,
		Status:  eventStatus,
	})
	if err != nil {
		errChan <- errors.Wrap(err, "svc.eventRepo.Save")
		return
	}

	// we can not process, exit early
	if eventStatus == relayer.EventStatusNewOnlyOwner && event.Message.Owner != svc.relayerAddr {
		log.Infof("gasLimit == 0 and owner is not the current relayer key, can not process. continuing loop")
		errChan <- nil
	}

	messageStatus, err := svc.destBridge.GetMessageStatus(nil, event.Signal)
	if err != nil {
		errChan <- errors.Wrap(err, "svc.destBridge.GetMessageStatus")
		return
	}

	if messageStatus == uint8(relayer.EventStatusNew) {
		// ctx, cancelFunc := context.WithTimeout(ctx, 90*time.Second)
		// defer cancelFunc()
		log.Info("message not processed yet, attempting processing")
		// process the message
		if err := svc.processor.ProcessMessage(ctx, event, e); err != nil {
			errChan <- errors.Wrap(err, "svc.processMessage")
			return
		}
	}

	// if the block number of the event is higher than the block we are processing,
	// we can now consider that previous block processed. save it to the DB
	// and bump the block number.
	if raw.BlockNumber > svc.processingBlock.Height {
		log.Infof("saving new latest processed block to DB: %v", raw.BlockNumber)

		if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
			Height:    svc.processingBlock.Height,
			Hash:      common.HexToHash(svc.processingBlock.Hash),
			ChainID:   chainID,
			EventName: eventName,
		}); err != nil {
			errChan <- errors.Wrap(err, "svc.blockRepo.Save")
			return
		}

		svc.processingBlock = &relayer.Block{
			Height: raw.BlockNumber,
			Hash:   raw.BlockHash.Hex(),
		}
	}
}
