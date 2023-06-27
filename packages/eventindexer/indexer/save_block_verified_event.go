package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (svc *Service) saveBlockVerifiedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockVerifiedIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no BlockVerified events")
		return nil
	}

	for {
		event := events.Event

		log.Infof("new blockVerified event, blockId: %v", event.Id)

		if err := svc.detectAndHandleReorg(ctx, eventindexer.EventNameBlockVerified, event.Id.Int64()); err != nil {
			return errors.Wrap(err, "svc.detectAndHandleReorg")
		}

		if err := svc.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockVerifiedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveBlockVerifiedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveBlockVerifiedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockVerified,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.Id.Int64()

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockVerified,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameBlockVerified,
		Address: "",
		BlockID: &blockID,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.BlockVerifiedEventsProcessed.Inc()

	if err := svc.updateAverageBlockReward(ctx, event); err != nil {
		return errors.Wrap(err, "svc.updateAverageBlockReward")
	}

	return nil
}

func (svc *Service) updateAverageBlockReward(ctx context.Context, event *taikol1.TaikoL1BlockVerified) error {
	reward := event.Reward

	stat, err := svc.statRepo.Find(ctx)
	if err != nil {
		return errors.Wrap(err, "svc.statRepo.Find")
	}

	avg, ok := new(big.Int).SetString(stat.AverageProofReward, 10)
	if !ok {
		return errors.New("unable to convert average proof reward to string")
	}

	newAverageProofReward := calcNewAverage(
		avg,
		new(big.Int).SetUint64(stat.NumVerifiedBlocks),
		new(big.Int).SetUint64(reward),
	)
	log.Infof("blockVerified reward update. id: %v, newAvg: %v, oldAvg: %v, reward: %v",
		event.Id.String(),
		newAverageProofReward.String(),
		avg.String(),
		reward,
	)

	_, err = svc.statRepo.Save(ctx, eventindexer.SaveStatOpts{
		ProofReward: newAverageProofReward,
	})
	if err != nil {
		return errors.Wrap(err, "svc.statRepo.Save")
	}

	return nil
}
