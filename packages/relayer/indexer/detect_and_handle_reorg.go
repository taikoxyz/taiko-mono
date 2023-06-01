package indexer

import (
	"context"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (svc *Service) detectAndHandleReorg(ctx context.Context, eventType string, msgHash string) error {
	events, err := svc.eventRepo.FindAllByMsgHash(ctx, msgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FindAllByMsgHash")
	}

	if events == nil {
		return nil
	}

	var existingEvent *relayer.Event

	for _, e := range events {
		if e.Event == eventType && e.MsgHash == msgHash {
			existingEvent = e
			break
		}
	}

	if existingEvent != nil {
		// reorg detected
		err := svc.eventRepo.Delete(ctx, existingEvent.ID)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Delete")
		}
	}

	return nil
}
