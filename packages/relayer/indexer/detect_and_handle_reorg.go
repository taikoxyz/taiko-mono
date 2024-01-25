package indexer

import (
	"context"

	"github.com/pkg/errors"

	"log/slog"
)

func (i *Indexer) detectAndHandleReorg(ctx context.Context, eventType string, msgHash string) error {
	// dont check on crawling past blocks, it will be a secondary indexer.
	// we expect to see duplicates in this mode.
	if i.watchMode == CrawlPastBlocks {
		return nil
	}

	e, err := i.eventRepo.FirstByEventAndMsgHash(ctx, eventType, msgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FirstByMsgHash")
	}

	if e == nil || e.MsgHash == "" || e.Event != eventType {
		return nil
	}

	// reorg detected
	slog.Info("reorg detected", "msgHash", msgHash, "eventType", eventType)

	err = i.eventRepo.Delete(ctx, e.ID)
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Delete")
	}

	return nil
}
