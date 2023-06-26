package indexer

import (
	"context"

	"github.com/pkg/errors"

	log "github.com/sirupsen/logrus"
)

func (svc *Service) detectAndHandleReorg(ctx context.Context, eventType string, msgHash string) error {
	e, err := svc.eventRepo.FirstByEventAndMsgHash(ctx, eventType, msgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FirstByMsgHash")
	}

	if e == nil || e.MsgHash == "" || e.Event != eventType {
		return nil
	}

	// reorg detected
	log.Infof("reorg detected for msgHash %v and eventType %v", msgHash, eventType)

	err = svc.eventRepo.Delete(ctx, e.ID)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Delete")
	}

	return nil
}
