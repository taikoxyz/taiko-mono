package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (indxr *Indexer) saveTransitionContestedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1TransitionContestedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no transitionContested events")
		return nil
	}

	for {
		event := events.Event

		if err := indxr.detectAndHandleReorg(
			ctx,
			eventindexer.EventNameTransitionContested,
			event.BlockId.Int64(),
		); err != nil {
			return errors.Wrap(err, "indxr.detectAndHandleReorg")
		}

		if err := indxr.saveTransitionContestedEvent(ctx, chainID, event); err != nil {
			eventindexer.TransitionContestedEventsProcessedError.Inc()

			return errors.Wrap(err, "indxr.saveBlockProvenEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (indxr *Indexer) saveTransitionContestedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1TransitionContested,
) error {
	slog.Info("transitionContested event found",
		"blockID", event.BlockId.Int64(),
		"contestBond", event.ContestBond.String(),
		"contester", event.Contester.Hex(),
		"tier", event.Tier,
	)

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	block, err := indxr.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
	}

	_, err = indxr.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameTransitionContested,
		Data:         string(marshaled),
		ChainID:      chainID,
		Event:        eventindexer.EventNameTransitionContested,
		Address:      event.Contester.Hex(),
		BlockID:      &blockID,
		TransactedAt: time.Unix(int64(block.Time()), 0),
		Tier:         &event.Tier,
	})
	if err != nil {
		return errors.Wrap(err, "indxr.eventRepo.Save")
	}

	eventindexer.TransitionContestedEventsProcessed.Inc()

	return nil
}
