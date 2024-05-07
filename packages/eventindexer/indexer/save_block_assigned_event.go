package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/assignmenthook"
)

func (i *Indexer) saveBlockAssignedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *assignmenthook.AssignmentHookBlockAssignedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no blockAssigned events")
		return nil
	}

	for {
		event := events.Event

		if err := i.saveBlockAssignedEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockAssignedEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveBlockAssignedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveBlockAssignedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *assignmenthook.AssignmentHookBlockAssigned,
) error {
	slog.Info("blockAssigned event", "prover", event.AssignedProver.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	assignedProver := event.AssignedProver.Hex()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	feeToken := event.Assignment.FeeToken.Hex()

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:            eventindexer.EventNameBlockAssigned,
		Data:            string(marshaled),
		ChainID:         chainID,
		Event:           eventindexer.EventNameBlockAssigned,
		Address:         "",
		AssignedProver:  &assignedProver,
		TransactedAt:    time.Unix(int64(block.Time()), 0).UTC(),
		Amount:          big.NewInt(0),
		ProofReward:     big.NewInt(0),
		FeeTokenAddress: &feeToken,
		EmittedBlockID:  event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}
