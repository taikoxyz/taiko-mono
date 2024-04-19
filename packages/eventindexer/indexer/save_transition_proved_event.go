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

var (
	systemProver = common.HexToAddress("0x0000000000000000000000000000000000000001")
	oracleProver = common.HexToAddress("0x0000000000000000000000000000000000000000")
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

	for {
		event := events.Event

		if err := i.saveTransitionProvedEvent(ctx, chainID, event); err != nil {
			eventindexer.TransitionProvedEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveBlockProvenEvent")
		}

		if !events.Next() {
			return nil
		}
	}
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

	if event.Prover.Hex() != systemProver.Hex() && event.Prover.Hex() != oracleProver.Hex() {
		if err := i.updateAverageProofTime(ctx, event); err != nil {
			return errors.Wrap(err, "i.updateAverageProofTime")
		}
	}

	return nil
}

func (i *Indexer) updateAverageProofTime(ctx context.Context, event *taikol1.TaikoL1TransitionProved) error {
	block, err := i.taikol1.GetBlock(nil, event.BlockId.Uint64())
	// will be unable to GetBlock for older blocks, just return nil, we dont
	// care about averageProofTime that much to be honest for older blocks
	if err != nil {
		slog.Error("getBlock error", "err", err.Error())

		return nil
	}

	eventBlock, err := i.ethClient.BlockByHash(ctx, event.Raw.BlockHash)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByHash")
	}

	stat, err := i.statRepo.Find(ctx, eventindexer.StatTypeProofTime, nil)
	if err != nil {
		return errors.Wrap(err, "i.statRepo.Find")
	}

	proposedAt := block.ProposedAt

	provenAt := eventBlock.Time()

	proofTime := provenAt - proposedAt

	avg, ok := new(big.Int).SetString(stat.AverageProofTime, 10)
	if !ok {
		return errors.New("unable to convert average proof time to string")
	}

	newAverageProofTime := calcNewAverage(
		avg,
		new(big.Int).SetUint64(stat.NumProofs),
		new(big.Int).SetUint64(proofTime),
	)

	slog.Info("avgProofWindow update",
		"id",
		event.BlockId.Int64(),
		"prover",
		event.Prover.Hex(),
		"proposedAt",
		proposedAt,
		"provenAt",
		provenAt,
		"proofTime",
		proofTime,
		"avg",
		avg.String(),
		"newAvg",
		newAverageProofTime.String(),
	)

	_, err = i.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofTime: newAverageProofTime,
		StatType:  eventindexer.StatTypeProofTime,
	})
	if err != nil {
		return errors.Wrap(err, "i.statRepo.Save")
	}

	return nil
}

func calcNewAverage(a, t, n *big.Int) *big.Int {
	m := new(big.Int).Mul(a, t)
	added := new(big.Int).Add(m, n)

	return new(big.Int).Div(added, t.Add(t, big.NewInt(1)))
}
