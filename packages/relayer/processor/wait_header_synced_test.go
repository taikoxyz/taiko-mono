package processor

import (
	"context"
	"testing"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestWaitHeaderSyncedUsesChainDataSynced(t *testing.T) {
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

func TestLatestSyncedBlockIDPrefersCheckpoint(t *testing.T) {
	repo := &mock.EventRepository{}
	p := &Processor{
		eventRepo: repo,
	}

	blockID, err := p.latestSyncedBlockID(context.Background(), mock.MockChainID.Uint64(), mock.MockChainID.Uint64())
	if err != nil {
		t.Fatalf("latestSyncedBlockID err: %v", err)
	}

	if blockID != 5 {
		t.Fatalf("expected 5, got %d", blockID)
	}
}

func TestFindSyncedEventUsesBothSources(t *testing.T) {
	repo := &mock.EventRepository{}
	p := &Processor{
		eventRepo: repo,
	}

	ev, err := p.findSyncedEvent(context.Background(), mock.MockChainID.Uint64(), mock.MockChainID.Uint64(), 1)
	if err != nil {
		t.Fatalf("findSyncedEvent err: %v", err)
	}

	if ev == nil || ev.ChainID != mock.MockChainID.Int64() {
		t.Fatalf("unexpected event: %#v", ev)
	}
}
