package indexer

import (
	"context"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/indexer/http"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func newTestService(syncMode SyncMode, watchMode WatchMode) (*Indexer, relayer.Bridge) {
	b := &mock.Bridge{}
	srv, _ := http.NewServer(http.NewServerOpts{
		Echo:          echo.New(),
		EventRepo:     &mock.EventRepository{},
		BlockRepo:     &mock.BlockRepository{},
		SrcEthClient:  &ethclient.Client{},
		DestEthClient: &ethclient.Client{},
		CorsOrigins:   []string{},
	})

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
		httpPort:  4102,
		srv:       srv,

		wg: &sync.WaitGroup{},

		ctx: context.Background(),

		srcChainId:  mock.MockChainID,
		destChainId: mock.MockChainID,

		ethClientTimeout: 10 * time.Second,
	}, b
}
