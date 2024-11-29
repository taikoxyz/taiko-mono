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
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) saveTransitionProvedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1TransitionProvedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no transitionProved events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			if err := i.saveTransitionProvedEvent(ctx, chainID, event); err != nil {
				eventindexer.TransitionProvedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveBlockProvenEvent")
			}

			return nil
		})

		if !events.Next() {
			break
		}
	}

	if err := wg.Wait(); err != nil {
		return err
	}

	return nil
}

func (i *Indexer) saveTransitionProvedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1TransitionProved,
) error {
	slog.Info("transitionProved event found",
		"blockID", event.BlockId.Int64(),
		"prover", event.Prover.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameTransitionProved,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameTransitionProved,
		Address:        event.Prover.Hex(),
		BlockID:        &blockID,
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		Tier:           &event.Tier,
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.TransitionProvedEventsProcessed.Inc()

	return nil
}

func (i *Indexer) saveTransitionProvedEventsV2(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1TransitionProvedV2Iterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no transitionProved events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			if err := i.saveTransitionProvedEventV2(ctx, chainID, event); err != nil {
				eventindexer.TransitionProvedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveBlockProvenEvent")
			}

			return nil
		})

		if !events.Next() {
			break
		}
	}

	if err := wg.Wait(); err != nil {
		return err
	}

	return nil
}

func (i *Indexer) saveTransitionProvedEventV2(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1TransitionProvedV2,
) error {
	slog.Info("transitionProved event found",
		"blockID", event.BlockId.Int64(),
		"prover", event.Prover.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameTransitionProved,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameTransitionProved,
		Address:        event.Prover.Hex(),
		BlockID:        &blockID,
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		Tier:           &event.Tier,
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.TransitionProvedEventsProcessed.Inc()

	return nil
}
