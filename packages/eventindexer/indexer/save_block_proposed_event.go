package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (indxr *Indexer) saveBlockProposedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProposedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no blockProposed events")
		return nil
	}

	for {
		event := events.Event

		if err := indxr.detectAndHandleReorg(ctx, eventindexer.EventNameBlockProposed, event.BlockId.Int64()); err != nil {
			return errors.Wrap(err, "indxr.detectAndHandleReorg")
		}

		tx, _, err := indxr.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.TransactionByHash")
		}

		sender, err := indxr.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.TransactionSender")
		}

		if err := indxr.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
			eventindexer.BlockProposedEventsProcessedError.Inc()

			return errors.Wrap(err, "indxr.saveBlockProposedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (indxr *Indexer) saveBlockProposedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProposed,
	sender common.Address,
) error {
	slog.Info("blockProposed", "proposer", sender.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	assignedProver := event.Prover.Hex()

	block, err := indxr.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
	}

	proposerReward, err := indxr.updateAverageProposerReward(ctx, event)
	if err != nil {
		return errors.Wrap(err, "indxr.updateAverageProposerReward")
	}

	proverReward, err := indxr.updateAverageProverReward(ctx, event)
	if err != nil {
		return errors.Wrap(err, "indxr.updateAverageProposerReward")
	}

	_, err = indxr.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBlockProposed,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBlockProposed,
		Address:        sender.Hex(),
		BlockID:        &blockID,
		AssignedProver: &assignedProver,
		TransactedAt:   time.Unix(int64(block.Time()), 0).UTC(),
		Amount:         event.Reward,
		ProposerReward: proposerReward,
		ProofReward:    proverReward,
	})
	if err != nil {
		return errors.Wrap(err, "indxr.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}

func (indxr *Indexer) updateAverageProposerReward(
	ctx context.Context,
	event *taikol1.TaikoL1BlockProposed,
) (*big.Int, error) {
	stat, err := indxr.statRepo.Find(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "indxr.statRepo.Find")
	}

	reward := event.Reward

	avg, ok := new(big.Int).SetString(stat.AverageProposerReward, 10)
	if !ok {
		return nil, errors.New("unable to convert average proposer to string")
	}

	newAverageProposerReward := calcNewAverage(
		avg,
		new(big.Int).SetUint64(stat.NumProposerRewards),
		reward,
	)

	slog.Info("newAverageProposerReward update",
		"id",
		event.BlockId.Int64(),
		"prover",
		event.Prover.Hex(),
		"avg",
		avg.String(),
		"newAvg",
		newAverageProposerReward.String(),
	)

	_, err = indxr.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProposerReward: newAverageProposerReward,
	})
	if err != nil {
		return nil, errors.Wrap(err, "indxr.statRepo.Save")
	}

	return reward, err
}

func (indxr *Indexer) updateAverageProverReward(
	ctx context.Context,
	event *taikol1.TaikoL1BlockProposed,
) (*big.Int, error) {
	stat, err := indxr.statRepo.Find(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "indxr.statRepo.Find")
	}

	tx, _, err := indxr.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
	if err != nil {
		return nil, errors.Wrap(err, "indxr.ethClient.TransactionByHash")
	}

	reward := tx.Value()

	avg, ok := new(big.Int).SetString(stat.AverageProofReward, 10)
	if !ok {
		return nil, errors.New("unable to convert average proof time to string")
	}

	newAverageProofReward := calcNewAverage(
		avg,
		new(big.Int).SetUint64(stat.NumProofs),
		reward,
	)

	slog.Info("newAverageProofReward update",
		"id",
		event.BlockId.Int64(),
		"prover",
		event.Prover.Hex(),
		"avg",
		avg.String(),
		"newAvg",
		newAverageProofReward.String(),
	)

	_, err = indxr.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofReward: newAverageProofReward,
	})
	if err != nil {
		return nil, errors.Wrap(err, "indxr.statRepo.Save")
	}

	return reward, nil
}
