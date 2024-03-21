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

	proverReward, err := i.updateAverageProverReward(ctx, event)
	if err != nil {
		return errors.Wrap(err, "i.updateAverageProverReward")
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
		Amount:          proverReward,
		ProofReward:     proverReward,
		FeeTokenAddress: &feeToken,
		EmittedBlockID:  event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}

func (i *Indexer) updateAverageProverReward(
	ctx context.Context,
	event *assignmenthook.AssignmentHookBlockAssigned,
) (*big.Int, error) {
	feeToken := event.Assignment.FeeToken.Hex()

	stat, err := i.statRepo.Find(ctx, eventindexer.StatTypeProofReward, &feeToken)
	if err != nil {
		return nil, errors.Wrap(err, "i.statRepo.Find")
	}

	avg, ok := new(big.Int).SetString(stat.AverageProofReward, 10)
	if !ok {
		return nil, errors.New("unable to convert average proof time to string")
	}

	var proverFee *big.Int

	tiers := event.Assignment.TierFees
	minTier := event.Meta.MinTier

	for _, tier := range tiers {
		if tier.Tier == minTier {
			proverFee = tier.Fee
			break
		}
	}

	newAverageProofReward := calcNewAverage(
		avg,
		new(big.Int).SetUint64(stat.NumProofs),
		proverFee,
	)

	slog.Info("newAverageProofReward update",
		"prover",
		event.AssignedProver.Hex(),
		"proverFee",
		proverFee.String(),
		"tiers",
		event.Assignment.TierFees,
		"minTier",
		event.Meta.MinTier,
		"avg",
		avg.String(),
		"newAvg",
		newAverageProofReward.String(),
	)

	_, err = i.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofReward:     newAverageProofReward,
		StatType:        eventindexer.StatTypeProofReward,
		FeeTokenAddress: &feeToken,
	})
	if err != nil {
		return nil, errors.Wrap(err, "i.statRepo.Save")
	}

	return big.NewInt(0), nil
}
