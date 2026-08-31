package queue

import (
	"context"
	"errors"
	"sync"

	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var (
	ErrClosed = errors.New("queue connection closed")
)

type Queue interface {
	Start(ctx context.Context, queueName string) error
	Close(ctx context.Context)
	Publish(
		ctx context.Context,
		queueName string,
		msg []byte,
		headers map[string]interface{},
		expiration *string,
	) error
	Notify(ctx context.Context, wg *sync.WaitGroup) error
	Subscribe(ctx context.Context, msgs chan<- Message, wg *sync.WaitGroup) error
	Ack(ctx context.Context, msg Message) error
	Nack(ctx context.Context, msg Message, requeue bool) error
}

type QueueMessageSentBody struct {
	Event        *bridge.BridgeMessageSent
	ID           int
	TimesRetried uint64
	// TimesRequeued counts transient failures, separately from TimesRetried. The two bound
	// nothing in common: TimesRetried gives up at MAX_MESSAGE_RETRIES because an unprofitable
	// message stays unprofitable, while a transient failure says nothing about whether the claim
	// is good, so it is retried for as long as it keeps failing and this only records how often.
	TimesRequeued uint64
}

type Message struct {
	Body     []byte
	Internal interface{}
}

type NewQueueOpts struct {
	Username      string
	Password      string
	Host          string
	Port          string
	PrefetchCount uint64
}
