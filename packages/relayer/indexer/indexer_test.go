package indexer

import (
	"context"
	"log"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
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

func TestHandleMessageProcessedEventSkipsIgnoredMessageHash(t *testing.T) {
	ignoredHash := common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000001")
	i, b := newTestService(Sync, Filter)
	mockBridge := b.(*mock.Bridge)
	eventRepo := i.eventRepo.(*mock.EventRepository)
	i.eventName = relayer.EventNameMessageProcessed
	i.srcChainId = big.NewInt(1)
	i.ignoredMsgHashes = map[common.Hash]struct{}{
		ignoredHash: {},
	}

	err := i.handleMessageProcessedEvent(
		context.Background(),
		i.srcChainId,
		&bridge.BridgeMessageProcessed{
			MsgHash: ignoredHash,
			Message: bridge.IBridgeMessage{
				DestChainId: 1,
				Value:       big.NewInt(0),
			},
		},
		false,
	)

	assert.NoError(t, err)
	assert.Equal(t, 0, mockBridge.IsMessageSentCalls)
	assert.Equal(t, 0, eventRepo.SavedCount())
}
