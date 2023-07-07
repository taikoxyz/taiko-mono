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

var (
	systemProver = common.HexToAddress("0x0000000000000000000000000000000000000001")
	oracleProver = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

func (svc *Service) saveBlockProvenEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProvenIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no blockProven events")
		return nil
	}

	for {
		event := events.Event

		if err := svc.detectAndHandleReorg(ctx, eventindexer.EventNameBlockProven, event.Id.Int64()); err != nil {
			return errors.Wrap(err, "svc.detectAndHandleReorg")
		}

		log.Infof("blockProven by: %v", event.Prover.Hex())

		if err := svc.saveBlockProvenEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockProvenEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveBlockProvenEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveBlockProvenEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProven,
) error {
	log.Infof("blockProven event found, id: %v", event.Id.Int64())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.Id.Int64()

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockProven,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameBlockProven,
		Address: event.Prover.Hex(),
		BlockID: &blockID,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.BlockProvenEventsProcessed.Inc()

	if event.Prover.Hex() != systemProver.Hex() && event.Prover.Hex() != oracleProver.Hex() {
		if err := svc.updateAverageProofTime(ctx, event); err != nil {
			return errors.Wrap(err, "svc.updateAverageProofTime")
		}
	}

	return nil
}

func (svc *Service) updateAverageProofTime(ctx context.Context, event *taikol1.TaikoL1BlockProven) error {
	block, err := svc.taikol1.GetBlock(nil, event.Id)
	// will be unable to GetBlock for older blocks, just return nil, we dont
	// care about averageProofTime that much to be honest for older blocks
	if err != nil {
		return nil
	}

	eventBlock, err := svc.ethClient.BlockByHash(ctx, event.Raw.BlockHash)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.BlockByHash")
	}

	stat, err := svc.statRepo.Find(ctx)
	if err != nil {
		return errors.Wrap(err, "svc.statRepo.Find")
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

	log.Infof("avgProofTime update: id: %v, prover: %v, proposedAt: %v, provenAt: %v, proofTIme: %v, avg: %v, newAvg: %v",
		event.Id.Int64(),
		event.Prover.Hex(),
		proposedAt,
		provenAt,
		proofTime,
		avg.String(),
		newAverageProofTime.String(),
	)

	_, err = svc.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofTime: newAverageProofTime,
	})
	if err != nil {
		return errors.Wrap(err, "svc.statRepo.Save")
	}

	return nil
}

func calcNewAverage(a, t, n *big.Int) *big.Int {
	m := new(big.Int).Mul(a, t)
	added := new(big.Int).Add(m, n)

	return new(big.Int).Div(added, t.Add(t, big.NewInt(1)))
}
