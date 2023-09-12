package indexer

import (
	"context"

	"github.com/pkg/errors"
)

func (indx *Indexer) detectAndHandleReorg(ctx context.Context, event string, blockID int64) error {
	existingEvent, err := indx.eventRepo.FindByEventTypeAndBlockID(ctx, event, blockID)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FindByEventTypeAndBlockID")
	}

	if existingEvent != nil {
		// reorg detected
		err := indx.eventRepo.Delete(ctx, existingEvent.ID)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Delete")
		}
	}

	return nil
}
