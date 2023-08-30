package queue

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

type Queue interface {
	Start(ctx context.Context, queueName string) error
	Close(ctx context.Context)
	Publish(ctx context.Context, msg []byte) error
	Subscribe(ctx context.Context, msgs chan<- Message) error
	Ack(ctx context.Context, msg Message) error
}

type QueueMessageBody struct {
	Event *bridge.BridgeMessageSent
	ID    int
}

type Message struct {
	Body     []byte
	Internal interface{}
}

type NewQueueOpts struct {
	Username string
	Password string
	Host     string
	Port     string
}
