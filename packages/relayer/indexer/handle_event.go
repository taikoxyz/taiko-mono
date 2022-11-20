package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
)

// handleEvent handles an individual MessageSent event
func (svc *Service) handleEvent(
	ctx context.Context,
	chainID *big.Int,
	event *contracts.BridgeMessageSent,
) error {
	log.Infof("event found for signal: %v", common.Hash(event.Signal).Hex())

	raw := event.Raw

	// handle chain re-org by checking Removed property, no need to
	// return error, just continue and do not process.
	if raw.Removed {
		return nil
	}

	eventStatus, err := svc.eventStatusFromSignal(ctx, event.Message.GasLimit, event.Signal)
	if err != nil {
		return errors.Wrap(err, "svc.eventStatusFromSignal")
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	e, err := svc.eventRepo.Save(relayer.SaveEventOpts{
		Name:    eventName,
		Data:    string(marshaled),
		ChainID: chainID,
		Status:  eventStatus,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	if !canProcessMessage(ctx, eventStatus, event.Message.Owner, svc.relayerAddr) {
		return nil
	}

	// process the message
	if err := svc.processor.ProcessMessage(ctx, event, e); err != nil {
		return errors.Wrap(err, "svc.processMessage")
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
			return errors.Wrap(err, "svc.blockRepo.Save")
		}

		svc.processingBlock = &relayer.Block{
			Height: raw.BlockNumber,
			Hash:   raw.BlockHash.Hex(),
		}
	}

	return nil
}

func canProcessMessage(
	ctx context.Context,
	eventStatus relayer.EventStatus,
	messageOwner common.Address,
	relayerAddress common.Address,
) bool {
	// we can not process, exit early
	if eventStatus == relayer.EventStatusNewOnlyOwner {
		if messageOwner != relayerAddress {
			log.Infof("gasLimit == 0 and owner is not the current relayer key, can not process. continuing loop")
			return false
		}

		return true
	}

	if eventStatus == relayer.EventStatusNew {
		return true
	}

	return false
}

func (svc *Service) eventStatusFromSignal(
	ctx context.Context,
	gasLimit *big.Int,
	signal [32]byte,
) (relayer.EventStatus, error) {
	var eventStatus relayer.EventStatus

	// if gasLimit is 0, relayer can not process this.
	if gasLimit == nil || gasLimit.Cmp(common.Big0) == 0 {
		eventStatus = relayer.EventStatusNewOnlyOwner
	} else {
		messageStatus, err := svc.destBridge.GetMessageStatus(nil, signal)
		if err != nil {
			return 0, errors.Wrap(err, "svc.destBridge.GetMessageStatus")
		}

		eventStatus = relayer.EventStatus(messageStatus)
	}

	return eventStatus, nil
}
