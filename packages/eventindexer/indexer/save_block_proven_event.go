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

func (indxr *Indexer) saveBlockProvenEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProvenIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no blockProven events")
		return nil
	}

	for {
		event := events.Event

		if err := indxr.detectAndHandleReorg(ctx, eventindexer.EventNameBlockProven, event.BlockId.Int64()); err != nil {
			return errors.Wrap(err, "indxr.detectAndHandleReorg")
		}

		if err := indxr.saveBlockProvenEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockProvenEventsProcessedError.Inc()

			return errors.Wrap(err, "indxr.saveBlockProvenEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (indxr *Indexer) saveBlockProvenEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProven,
) error {
	slog.Info("blockProven event found",
		"blockID", event.BlockId.Int64(),
		"prover", event.Prover.Hex())

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
		Name:         eventindexer.EventNameBlockProven,
		Data:         string(marshaled),
		ChainID:      chainID,
		Event:        eventindexer.EventNameBlockProven,
		Address:      event.Prover.Hex(),
		BlockID:      &blockID,
		TransactedAt: time.Unix(int64(block.Time()), 0),
	})
	if err != nil {
		return errors.Wrap(err, "indxr.eventRepo.Save")
	}

	eventindexer.BlockProvenEventsProcessed.Inc()

	if event.Prover.Hex() != systemProver.Hex() && event.Prover.Hex() != oracleProver.Hex() {
		if err := indxr.updateAverageProofTime(ctx, event); err != nil {
			return errors.Wrap(err, "indxr.updateAverageProofTime")
		}
	}

	return nil
}

func (indxr *Indexer) updateAverageProofTime(ctx context.Context, event *taikol1.TaikoL1BlockProven) error {
	block, err := indxr.taikol1.GetBlock(nil, event.BlockId.Uint64())
	// will be unable to GetBlock for older blocks, just return nil, we dont
	// care about averageProofTime that much to be honest for older blocks
	if err != nil {
		slog.Error("getBlock error", "err", err.Error())

		return nil
	}

	eventBlock, err := indxr.ethClient.BlockByHash(ctx, event.Raw.BlockHash)
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.BlockByHash")
	}

	stat, err := indxr.statRepo.Find(ctx)
	if err != nil {
		return errors.Wrap(err, "indxr.statRepo.Find")
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

	_, err = indxr.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofTime: newAverageProofTime,
	})
	if err != nil {
		return errors.Wrap(err, "indxr.statRepo.Save")
	}

	return nil
}

func calcNewAverage(a, t, n *big.Int) *big.Int {
	m := new(big.Int).Mul(a, t)
	added := new(big.Int).Add(m, n)

	return new(big.Int).Div(added, t.Add(t, big.NewInt(1)))
}
