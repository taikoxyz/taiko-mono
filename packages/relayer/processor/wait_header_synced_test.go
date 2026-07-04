package processor

import (
	"context"
	"testing"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestWaitHeaderSyncedUsesCheckpointSaved(t *testing.T) {
	ethc := &mock.EthClient{}
	repo := &mock.EventRepository{}

	p := &Processor{
		eventRepo:                 repo,
		headerSyncIntervalSeconds: 1,
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	ev, err := p.waitHeaderSynced(ctx, ethc, 2, 1)
	if err != nil {
		t.Fatalf("waitHeaderSynced err: %v", err)
	}

	if ev == nil || ev.ChainID != mock.MockChainID.Int64() {
		t.Fatalf("unexpected event: %#v", ev)
	}
}
