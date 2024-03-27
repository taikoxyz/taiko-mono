package mock

import (
	"context"
	"sync"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

type Queue struct {
}

func (r *Queue) Start(ctx context.Context, queueName string) error {
	return nil
}

func (r *Queue) Close(ctx context.Context) {

}

func (r *Queue) Notify(ctx context.Context, wg *sync.WaitGroup) error {
	return nil
}

func (r *Queue) Publish(ctx context.Context, queueName string, msg []byte, expiration *string) error {
	return nil
}

func (r *Queue) Ack(ctx context.Context, msg queue.Message) error {
	return nil
}

func (r *Queue) Nack(ctx context.Context, msg queue.Message, requeue bool) error {
	return nil
}

func (r *Queue) Subscribe(
	ctx context.Context,
	msgChan chan<- queue.Message,
	wg *sync.WaitGroup,
) error {
	return nil
}
