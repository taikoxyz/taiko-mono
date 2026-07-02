package indexer

import (
	"context"
	"log"
	"math/big"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	signalservice "github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
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

type indexerRecordingQueue struct {
	publishedCount int
}

func (q *indexerRecordingQueue) Start(ctx context.Context, queueName string) error { return nil }
func (q *indexerRecordingQueue) Close(ctx context.Context)                         {}
func (q *indexerRecordingQueue) Notify(ctx context.Context, wg *sync.WaitGroup) error {
	return nil
}
func (q *indexerRecordingQueue) Subscribe(ctx context.Context, msgs chan<- queue.Message, wg *sync.WaitGroup) error {
	return nil
}
func (q *indexerRecordingQueue) Publish(
	ctx context.Context,
	queueName string,
	msg []byte,
	headers map[string]interface{},
	expiration *string,
) error {
	q.publishedCount++
	return nil
}
func (q *indexerRecordingQueue) Ack(ctx context.Context, msg queue.Message) error { return nil }
func (q *indexerRecordingQueue) Nack(ctx context.Context, msg queue.Message, requeue bool) error {
	return nil
}

func TestHandleMessageProcessedEventSkipsWrongSourceChain(t *testing.T) {
	q := &indexerRecordingQueue{}
	i, _ := newTestService(Sync, Filter)
	i.queue = q
	i.eventName = relayer.EventNameMessageProcessed
	i.srcChainId = big.NewInt(1)
	i.destChainId = big.NewInt(2)

	err := i.handleMessageProcessedEvent(
		context.Background(),
		i.srcChainId,
		&bridge.BridgeMessageProcessed{
			Message: bridge.IBridgeMessage{
				SrcChainId:  3,
				DestChainId: 1,
				Value:       big.NewInt(0),
			},
		},
		false,
	)

	assert.NoError(t, err)
	assert.Equal(t, 0, q.publishedCount)
}

func TestHandleMessageProcessedEventSkipsIgnoredMessageHash(t *testing.T) {
	ignoredHash := common.HexToHash("0x1")
	q := &indexerRecordingQueue{}
	i, _ := newTestService(Sync, Filter)
	i.queue = q
	i.eventName = relayer.EventNameMessageProcessed
	i.srcChainId = big.NewInt(1)
	i.destChainId = big.NewInt(2)
	i.ignoredMsgHashes = map[common.Hash]struct{}{
		ignoredHash: {},
	}

	err := i.handleMessageProcessedEvent(
		context.Background(),
		i.srcChainId,
		&bridge.BridgeMessageProcessed{
			MsgHash: ignoredHash,
			Message: bridge.IBridgeMessage{
				SrcChainId:  2,
				DestChainId: 1,
				Value:       big.NewInt(0),
			},
		},
		false,
	)

	assert.NoError(t, err)
	assert.Equal(t, 0, q.publishedCount)
}
