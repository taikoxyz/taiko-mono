package indexer

import (
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func newTestService(syncMode SyncMode, watchMode WatchMode) (*Indexer, relayer.Bridge) {
	b := &mock.Bridge{}

	return &Indexer{
		blockRepo:     &mock.BlockRepository{},
		eventRepo:     &mock.EventRepository{},
		bridge:        b,
		destBridge:    b,
		srcEthClient:  &mock.EthClient{},
		numGoroutines: 10,

		processingBlockHeight: 0,
		blockBatchSize:        100,

		queue: &mock.Queue{},

		syncMode:  syncMode,
		watchMode: watchMode,
	}, b
}
