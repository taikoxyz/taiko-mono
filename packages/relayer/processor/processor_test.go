package processor

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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
	mu                  sync.Mutex
	publishErr          error
	ackErr              error
	nackErr             error
	publishedBody       []byte
	publishedQueue      string
	publishedExpiration *string
	acked               int
	nacked              int
	requeued            bool
}

// counts reads the tallies under the lock, for tests where the queue is driven from the
// goroutine eventLoop spawns rather than from the test's own.
func (q *recordingQueue) counts() (acked, nacked int) {
	q.mu.Lock()
	defer q.mu.Unlock()

	return q.acked, q.nacked
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
	q.mu.Lock()
	defer q.mu.Unlock()

	q.publishedQueue = queueName
	q.publishedBody = msg
	q.publishedExpiration = expiration

	return q.publishErr
}
func (q *recordingQueue) Ack(ctx context.Context, msg queue.Message) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.acked++

	return q.ackErr
}
func (q *recordingQueue) Nack(ctx context.Context, msg queue.Message, requeue bool) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.nacked++
	q.requeued = requeue

	return q.nackErr
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

func TestHandleProcessMessageResultParksTransientErrors(t *testing.T) {
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

	// Requeuing instead would hand the message straight back to a consumer that prefetches one
	// at a time, so a claim that keeps failing would be all the replica ever looks at.
	assert.Equal(t, 1, q.acked, "the copy on the transient queue replaces this delivery")
	assert.Equal(t, 0, q.nacked)
	assert.Equal(t, p.queueName()+"-transient", q.publishedQueue,
		"the exact queue matters: a name nothing is bound to is dropped by the broker, not parked")
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

func TestHandleProcessMessageResultRequeuesDeadlineExceeded(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	// shouldRequeue is false on the send path, so the claim only survives if the error is
	// recognised as transient. "context deadline exceeded" matches none of the strings the
	// classifier looks for, which is how a timed-out send used to lose a claim outright.
	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		false,
		0,
		context.DeadlineExceeded,
	)

	assert.Equal(t, 1, q.acked)
	assert.Equal(t, 0, q.nacked)
	assert.Equal(t, p.queueName()+"-transient", q.publishedQueue)
}

func TestHandleProcessMessageResultCountsAndDelaysTransientRequeues(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	body, err := json.Marshal(queue.QueueMessageSentBody{TimesRequeued: 4})
	require.NoError(t, err)

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: body},
		false,
		0,
		context.DeadlineExceeded,
	)

	var published queue.QueueMessageSentBody

	require.NoError(t, json.Unmarshal(q.publishedBody, &published))

	// Counted but never capped: a transient failure says nothing about whether the claim is good,
	// so it keeps coming back and this is what makes a message that never resolves visible.
	assert.Equal(t, uint64(5), published.TimesRequeued)
	assert.Equal(t, DefaultTransientErrorQueueExpiration, *q.publishedExpiration,
		"a message parked with no expiration would never come back")
}

func TestHandleProcessMessageResultParksForTheConfiguredExpiration(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	configured := "45000"
	p.cfg.TransientErrorQueueExpiration = &configured

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		false,
		0,
		errors.New("i/o timeout"),
	)

	// Without this the fallback branch is the only one any test reaches, and the configured value
	// could be ignored entirely.
	assert.Equal(t, configured, *q.publishedExpiration)
}

func TestHandleProcessMessageResultRequeuesWhenTheTransientParkFails(t *testing.T) {
	q := &recordingQueue{publishErr: errors.New("broker unreachable")}
	p := newTestProcessor(false)
	p.queue = q

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		false,
		0,
		errors.New("i/o timeout"),
	)

	// The wait is an optimisation; failing to take it must not cost the claim.
	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.True(t, q.requeued)
}

func TestHandleProcessMessageResultRequeuesUndecodableTransientMessages(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`not json`)},
		false,
		0,
		errors.New("i/o timeout"),
	)

	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.True(t, q.requeued, "an undecodable body is still a claim worth another attempt")
}

func TestHandleProcessMessageResultRetriesANonceTooLowAbort(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	// What the transaction manager returns once a claim has lost its nonce: it gives up after
	// SafeAbortNonceTooLowCount refusals and wraps the sentinel. The claim itself is untouched —
	// nobody processed that message — so it has to be signed again under a fresh nonce rather than
	// dead-lettered onto a queue with no consumer.
	err := fmt.Errorf("aborted tx send due to critical error: %w", core.ErrNonceTooLow)

	p.handleProcessMessageResult(context.Background(), queue.Message{Body: []byte(`{}`)}, false, 0, err)

	assert.Equal(t, 1, q.acked, "parked for another attempt, not dead-lettered")
	assert.Equal(t, 0, q.nacked)
	assert.Equal(t, p.queueName()+"-transient", q.publishedQueue)
}

func TestHandleProcessMessageResultAcksUnprocessableMessages(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	// An unprocessable message will never succeed, so requeuing it would spin forever. It is
	// acked away deliberately.
	p.handleProcessMessageResult(
		context.Background(),
		queue.Message{Body: []byte(`{}`)},
		true,
		0,
		errUnprocessable,
	)

	assert.Equal(t, 1, q.acked)
	assert.Equal(t, 0, q.nacked)
}

func TestHandleProcessMessageResultRespectsShouldRequeueOnUnknownErrors(t *testing.T) {
	for _, shouldRequeue := range []bool{true, false} {
		t.Run(fmt.Sprintf("shouldRequeue=%v", shouldRequeue), func(t *testing.T) {
			q := &recordingQueue{}
			p := newTestProcessor(false)
			p.queue = q

			// An error the classifier does not recognise leaves the decision to the caller, which
			// knows whether the message is worth another attempt.
			p.handleProcessMessageResult(
				context.Background(),
				queue.Message{Body: []byte(`{}`)},
				shouldRequeue,
				0,
				errors.New("execution reverted"),
			)

			assert.Equal(t, 0, q.acked)
			assert.Equal(t, 1, q.nacked)
			assert.Equal(t, shouldRequeue, q.requeued)
		})
	}
}

func TestHandleProcessMessageResultAcksOnSuccess(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	p.handleProcessMessageResult(context.Background(), queue.Message{Body: []byte(`{}`)}, false, 0, nil)

	assert.Equal(t, 1, q.acked)
	assert.Equal(t, 0, q.nacked)
}

func TestHandleProcessMessageResultRequeuesOnSuccessWhenAsked(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	// No error, but the caller knows the message is not done — a message waiting on quota, say.
	p.handleProcessMessageResult(context.Background(), queue.Message{Body: []byte(`{}`)}, true, 0, nil)

	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.True(t, q.requeued)
}

func TestHandleUnprofitableMessageNacksUndecodableBodies(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	// A body that will not decode cannot be republished with an incremented retry count, and
	// requeuing it unchanged would loop on the same decode failure.
	p.handleUnprofitableMessage(context.Background(), queue.Message{Body: []byte(`not json`)}, 0)

	assert.Equal(t, 0, q.acked)
	assert.Equal(t, 1, q.nacked)
	assert.False(t, q.requeued)
	assert.Nil(t, q.publishedBody, "nothing should reach the unprofitable queue")
}

func TestHandleUnprofitableMessagePublishesToTheUnprofitableQueue(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q

	p.handleUnprofitableMessage(context.Background(), queue.Message{Body: []byte(`{}`)}, 4)

	assert.Equal(t, p.queueName()+"-unprofitable", q.publishedQueue)
	assert.Equal(t, 1, q.acked)
	assert.Equal(t, 0, q.nacked)

	var published queue.QueueMessageSentBody

	assert.NoError(t, json.Unmarshal(q.publishedBody, &published))
	assert.Equal(t, uint64(5), published.TimesRetried)
}

func TestIsTransientProcessMessageError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{name: "cancelled context", err: context.Canceled, want: true},
		{
			// A send that ran out of time matches none of the substrings below, so it needs the
			// explicit case; without it a slow endpoint silently loses the claim.
			name: "deadline exceeded",
			err:  context.DeadlineExceeded,
			want: true,
		},
		{
			name: "deadline exceeded, wrapped",
			err:  fmt.Errorf("send failed: %w", context.DeadlineExceeded),
			want: true,
		},
		{name: "i/o timeout", err: errors.New("read tcp: i/o timeout"), want: true},
		{name: "connection refused", err: errors.New("dial tcp: connect: connection refused"), want: true},
		{
			// A relay refusing one transaction is transient for the message, which is retried
			// against the endpoint behind it.
			name: "relay would not take the transaction",
			err:  errors.New("failed to get tx into the mempool"),
			want: true,
		},
		{
			// A revert will revert again. Retrying it burns gas on every attempt.
			name: "execution reverted",
			err:  errors.New("execution reverted"),
			want: false,
		},
		{
			// The bare text is not the sentinel, and only the sentinel is classified. A message
			// whose error merely reads this way carries no proof the nonce was lost.
			name: "the words nonce too low, unwrapped",
			err:  errors.New("nonce too low"),
			want: false,
		},
		{
			// The sentinel itself, wrapped the way sendTx wraps it. This is the claim that lost a
			// race for its nonce with nobody having processed the message, so it is retried.
			name: "the nonce too low sentinel",
			err:  fmt.Errorf("aborted tx send due to critical error: %w", core.ErrNonceTooLow),
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, isTransientProcessMessageError(tt.err))
		})
	}
}

func TestProcessorName(t *testing.T) {
	assert.Equal(t, "processor", newTestProcessor(false).Name())
}

func TestEventLoopProcessesQueuedMessages(t *testing.T) {
	q := &recordingQueue{}
	p := newTestProcessor(false)
	p.queue = q
	p.msgCh = make(chan queue.Message, 1)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})

	go func() {
		p.eventLoop(ctx)
		close(done)
	}()

	// A body with no event decodes but has nothing to process, which resolves without touching a
	// chain — enough to prove the loop hands messages to the result handler.
	p.msgCh <- queue.Message{Body: []byte(`{}`)}

	require.Eventually(t, func() bool {
		_, nacked := q.counts()

		return nacked == 1
	}, 5*time.Second, 10*time.Millisecond, "the loop should have handled the message")

	cancel()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("eventLoop did not return on a cancelled context")
	}

	// The loop registers itself on the WaitGroup that Close waits on, so a shutdown cannot race
	// past a loop that is still running.
	p.wg.Wait()
}

func TestCloseCancelsAndDrains(t *testing.T) {
	p := newTestProcessor(false)

	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel

	p.wg.Add(1)

	go func() {
		<-ctx.Done()
		p.wg.Done()
	}()

	p.Close(context.Background())

	// Close must cancel the work it started and wait for it before closing the db underneath it.
	assert.ErrorIs(t, ctx.Err(), context.Canceled)
}

func TestHandleProcessMessageResultSurvivesQueueErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
	}{
		{name: "ack path", err: errUnprocessable},
		{name: "transient nack path", err: errors.New("i/o timeout")},
		{name: "default nack path", err: errors.New("execution reverted")},
		{name: "no error", err: nil},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			q := &recordingQueue{
				ackErr:  errors.New("channel closed"),
				nackErr: errors.New("channel closed"),
			}
			p := newTestProcessor(false)
			p.queue = q

			// A queue that will not take the acknowledgement is logged and moved past. Panicking
			// here would take down the worker over a message that is already handled.
			assert.NotPanics(t, func() {
				p.handleProcessMessageResult(
					context.Background(),
					queue.Message{Body: []byte(`{}`)},
					false,
					0,
					tt.err,
				)
			})

			acked, nacked := q.counts()
			assert.Equal(t, 1, acked+nacked)
		})
	}
}

func TestHandleUnprofitableMessageSurvivesQueueErrors(t *testing.T) {
	q := &recordingQueue{
		publishErr: errors.New("channel closed"),
		nackErr:    errors.New("channel closed"),
	}
	p := newTestProcessor(false)
	p.queue = q

	assert.NotPanics(t, func() {
		p.handleUnprofitableMessage(context.Background(), queue.Message{Body: []byte(`{}`)}, 0)
	})

	_, nacked := q.counts()
	assert.Equal(t, 1, nacked)
}

func TestDialPrivateSenders(t *testing.T) {
	t.Run("no endpoints configured", func(t *testing.T) {
		senders, err := dialPrivateSenders(context.Background(), nil)

		require.NoError(t, err)
		assert.Empty(t, senders)
	})

	t.Run("order is preserved and no endpoint is contacted", func(t *testing.T) {
		// Nothing is listening on either port. http clients are built without dialling, so this
		// has to succeed — a private relay being down must never stop the processor starting.
		senders, err := dialPrivateSenders(context.Background(), []string{
			"http://127.0.0.1:1",
			"https://127.0.0.1:2",
		})

		require.NoError(t, err)
		assert.Len(t, senders, 2)
	})

	t.Run("a failing endpoint closes the ones already opened", func(t *testing.T) {
		// A scheme the RPC client has no transport for fails after the first client is already
		// open. Nothing owns that client yet, so it has to be closed here or it leaks for the
		// life of the process.
		senders, err := dialPrivateSenders(context.Background(), []string{
			"http://127.0.0.1:1",
			"ftp://127.0.0.1:2",
		})

		require.Error(t, err)
		assert.Nil(t, senders, "a partial list would leave the relayer believing it is private")
	})
}
