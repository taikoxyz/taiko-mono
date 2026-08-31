package indexer

import (
	"context"
	"log"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

// filter dispatches on eventName, and this sentinel matches no case, which keeps
// the test on the block-range arithmetic. The real event names cannot be used
// here: newTestService leaves cfg nil and withRetry dereferences it.
const noIndexedEventName = "no-event"

func TestFilterCrawlPastBlocksClampsCrawlWindowsToAvailableHistory(t *testing.T) {
	// mock.LatestBlockNumber is the source-chain head seen by filter.
	head := mock.LatestBlockNumber.Uint64()

	tests := []struct {
		name       string
		start      uint64
		end        uint64
		wantCursor uint64
	}{
		{
			// the reported bug: the subtraction wrapped to ~2^64 and the crawler
			// silently indexed nothing.
			"start window longer than the chain",
			50_400,
			3,
			head - 3,
		},
		{
			"start window exactly the chain height",
			head,
			3,
			head - 3,
		},
		{
			"mature chain, both windows inside the history",
			4,
			1,
			head - 1,
		},
		{
			// production defaults on a chain shorter than the end window: every
			// block is still unripe, so the crawler must index nothing rather
			// than run past its own exclusion window.
			"end window longer than the chain",
			50_400,
			300,
			0,
		},
		{
			"end window exactly the chain height",
			50_400,
			head,
			0,
		},
		{
			"no windows configured",
			0,
			0,
			head,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			i, _ := newTestService(Resync, CrawlPastBlocks)
			i.eventName = noIndexedEventName
			i.numLatestBlocksStartWhenCrawling = tt.start
			i.numLatestBlocksEndWhenCrawling = tt.end

			err := i.filter(context.Background())

			require.NoError(t, err)
			assert.Equal(t, tt.wantCursor, i.latestIndexedBlockNumber)
		})
	}
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
