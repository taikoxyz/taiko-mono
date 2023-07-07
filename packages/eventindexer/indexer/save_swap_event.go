package indexer

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
)

func (svc *Service) saveSwapEvents(
	ctx context.Context,
	chainID *big.Int,
	events *swap.SwapSwapIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no Swap events")
		return nil
	}

	for {
		event := events.Event

		if err := svc.saveSwapEvent(ctx, chainID, event); err != nil {
			eventindexer.SwapEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveSwapEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveSwapEvent(
	ctx context.Context,
	chainID *big.Int,
	event *swap.SwapSwap,
) error {
	log.Infof("swap event for sender 0x%v",
		common.Bytes2Hex(event.Raw.Topics[2].Bytes()[12:]),
	)

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameSwap,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameSwap,
		Address: fmt.Sprintf("0x%v", common.Bytes2Hex(event.Raw.Topics[2].Bytes()[12:])),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.SwapEventsProcessed.Inc()

	return nil
}
