package indexer

import (
	"context"
	"log"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	signalservice "github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func newTestService(syncMode SyncMode, watchMode WatchMode) (*Indexer, relayer.Bridge) {
	b := &mock.Bridge{}

	ethClient := &mock.EthClient{}

	ss, err := signalservice.NewSignalService(common.Address{}, ethClient)
	if err != nil {
		log.Fatal(err)
	}

	return &Indexer{
		eventRepo:     &mock.EventRepository{},
		bridge:        b,
		destBridge:    b,
		srcEthClient:  ethClient,
		signalService: ss,
		numGoroutines: 10,

		latestIndexedBlockNumber: 0,
		blockBatchSize:           100,

		queue: &mock.Queue{},

		syncMode:  syncMode,
		watchMode: watchMode,

		ctx: context.Background(),

		srcChainId:  mock.MockChainID,
		destChainId: mock.MockChainID,

		ethClientTimeout: 10 * time.Second,
		eventName:        relayer.EventNameMessageSent,
	}, b
}
