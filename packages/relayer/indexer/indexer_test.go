package indexer

import (
	"context"
	"sync"
	"time"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
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

		wg: &sync.WaitGroup{},

		ctx: context.Background(),

		srcChainId:  mock.MockChainID,
		destChainId: mock.MockChainID,

		ethClientTimeout: 10 * time.Second,
	}, b
}
