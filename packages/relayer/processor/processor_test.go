package processor

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"

func newTestProcessor(profitableOnly bool) *Processor {
	privateKey, _ := crypto.HexToECDSA(dummyEcdsaKey)

	prover, _ := proof.New(
		&mock.Blocker{},
	)

	return &Processor{
		eventRepo:                 &mock.EventRepository{},
		destBridge:                &mock.Bridge{},
		srcEthClient:              &mock.EthClient{},
		destEthClient:             &mock.EthClient{},
		destERC20Vault:            &mock.TokenVault{},
		srcSignalService:          &mock.SignalService{},
		ecdsaKey:                  privateKey,
		prover:                    prover,
		srcCaller:                 &mock.Caller{},
		profitableOnly:            profitableOnly,
		headerSyncIntervalSeconds: 1,
		confTimeoutInSeconds:      900,
		confirmations:             1,
		queue:                     &mock.Queue{},
		backOffRetryInterval:      1 * time.Second,
		backOffMaxRetries:         1,
		ethClientTimeout:          10 * time.Second,
		srcChainId:                mock.MockChainID,
		destChainId:               mock.MockChainID,
		txmgr:                     &mock.TxManager{},
		cfg: &Config{
			DestBridgeAddress: common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
		},
		maxMessageRetries:  5,
		destQuotaManager:   &mock.QuotaManager{},
		processingTxHashes: make(map[common.Hash]bool, 0),
	}
}

type recordingQueue struct {
	publishErr     error
	publishedBody  []byte
	publishedQueue string
	acked          int
	nacked         int
	requeued       bool
}

func (q *recordingQueue) Start(ctx context.Context, queueName string) error { return nil }
func (q *recordingQueue) Close(ctx context.Context)                         {}
func (q *recordingQueue) Notify(ctx context.Context, wg *sync.WaitGroup) error {
	return nil
}
func (q *recordingQueue) Subscribe(ctx context.Context, msgs chan<- queue.Message, wg *sync.WaitGroup) error {
	return nil
}
func (q *recordingQueue) Publish(
	ctx context.Context,
	queueName string,
	msg []byte,
	headers map[string]interface{},
	expiration *string,
) error {
	q.publishedQueue = queueName
	q.publishedBody = msg

	return q.publishErr
}
func (q *recordingQueue) Ack(ctx context.Context, msg queue.Message) error {
	q.acked++
	return nil
}
func (q *recordingQueue) Nack(ctx context.Context, msg queue.Message, requeue bool) error {
	q.nacked++
	q.requeued = requeue

	return nil
}

func TestHandleProcessMessageResultNacksWhenUnprofitableRepublishFails(t *testing.T) {
	q := &recordingQueue{publishErr: errors.New("publish failed")}
	p := newTestProcessor(false)
	p.queue = q

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		false,
		2,
		relayer.ErrUnprofitable,
	)

	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.True(t, q.requeued)
}

func TestHandleProcessMessageResultNacksTransientErrors(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		false,
		0,
		errors.New("i/o timeout"),
	)

	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.True(t, q.requeued)
}

func TestHandleProcessMessageResultPersistsUnprofitableRetryCount(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	body, err := json.Marshal(queue.QueueMessageSentBody{TimesRetried: 2})
	assert.NoError(t, err)

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: body},
		false,
		2,
		relayer.ErrUnprofitable,
	)

	var published queue.QueueMessageSentBody

	assert.NoError(t, json.Unmarshal(q.publishedBody, &published))
	assert.Equal(t, uint64(3), published.TimesRetried)
	assert.Equal(t, 1, q.acked)
	assert.Equal(t, 0, q.nacked)
}
