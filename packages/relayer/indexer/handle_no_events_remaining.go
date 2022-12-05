package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
)

// handleNoEventsRemaining is used when the batch had events, but is now finished, and we need to
// update the latest block processed
func (svc *Service) handleNoEventsRemaining(
	ctx context.Context,
	chainID *big.Int,
	events *contracts.BridgeMessageSentIterator,
) error {
	log.Info("no events remaining to be processed")

	if events.Error() != nil {
		return errors.Wrap(events.Error(), "events.Error")
	}

	if err := svc.blockRepo.Save(relayer.SaveBlockOpts{
		Height:    events.Event.Raw.BlockNumber,
		Hash:      events.Event.Raw.BlockHash,
		ChainID:   chainID,
		EventName: eventName,
	}); err != nil {
		return errors.Wrap(err, "svc.blockRepo.Save")
	}

	log.Infof("processing block: %v, chainID: %v", events.Event.Raw.BlockNumber, chainID.Int64())

	svc.processingBlock = &relayer.Block{
		Height: events.Event.Raw.BlockNumber,
		Hash:   events.Event.Raw.BlockHash.Hex(),
	}

	return nil
}
