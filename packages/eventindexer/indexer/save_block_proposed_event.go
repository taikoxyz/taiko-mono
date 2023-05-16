package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (svc *Service) saveBlockProposedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProposedIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no blockProposed events")
		return nil
	}

	for {
		event := events.Event

		if event.Raw.Removed {
			continue
		}

		tx, _, err := svc.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
		if err != nil {
			return errors.Wrap(err, "svc.ethClient.TransactionByHash")
		}

		sender, err := svc.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
		if err != nil {
			return errors.Wrap(err, "svc.ethClient.TransactionSender")
		}

		log.Infof("blockProposed by: %v", sender.Hex())

		if err := svc.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
			eventindexer.BlockProposedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveBlockProposedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveBlockProposedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProposed,
	sender common.Address,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockProposed,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameBlockProposed,
		Address: sender.Hex(),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}
