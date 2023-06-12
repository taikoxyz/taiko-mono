package indexer

import (
	"context"

	"github.com/pkg/errors"
)

func (svc *Service) detectAndHandleReorg(ctx context.Context, eventType string, msgHash string) error {
	e, err := svc.eventRepo.FirstByMsgHash(ctx, msgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FirstByMsgHash")
	}

	if e == nil || e.MsgHash == "" {
		return nil
	}

	// reorg detected
	err = svc.eventRepo.Delete(ctx, e.ID)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Delete")
	}

	return nil
}
