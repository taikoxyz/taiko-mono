package rabbitmq

import (
	"context"
	"errors"
	"testing"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

func TestDescribeRedeclareFailureExplainsAPreconditionFailure(t *testing.T) {
	// What the broker answers when a durable queue already exists with different arguments. The
	// raw text says only that they are not equivalent, which leaves an operator upgrading past
	// this release with a relayer that will not start and no idea why.
	err := describeRedeclareFailure("l1-l2-MessageSent-queue", &amqp.Error{
		Code:   amqp.PreconditionFailed,
		Reason: "inequivalent arg 'x-dead-letter-routing-key'",
	})

	require.Error(t, err)
	assert.Contains(t, err.Error(), "l1-l2-MessageSent-queue", "the operator has to know which queue")
	assert.Contains(t, err.Error(), "drain and delete", "and what to do about it")
	assert.Contains(t, err.Error(), "inequivalent arg", "without losing what the broker said")
}

func TestDescribeRedeclareFailurePassesEverythingElseThrough(t *testing.T) {
	// Only the argument mismatch has this explanation. Anything else must reach the caller as it
	// was, or a connection failure would be reported as a migration problem.
	original := errors.New("dial tcp: connection refused")

	assert.Equal(t, original, describeRedeclareFailure("queue", original))
}

func TestForwardDeliveryHandsTheDeliveryToTheConsumer(t *testing.T) {
	r := &RabbitMQ{subscriptionCtx: context.Background()}

	msgChan := make(chan queue.Message)

	delivery := amqp.Delivery{
		Body:      []byte(`{"id":1}`),
		MessageId: "msg-1",
	}

	taken := make(chan queue.Message, 1)

	go func() {
		taken <- <-msgChan
	}()

	stopped, err := r.forwardDelivery(context.Background(), msgChan, delivery)

	require.NoError(t, err)
	assert.False(t, stopped, "a delivery the consumer took is no reason to stop")

	msg := <-taken
	assert.Equal(t, delivery.Body, msg.Body)

	internal, ok := msg.Internal.(amqp.Delivery)
	require.True(t, ok, "Ack and Nack need the delivery back to acknowledge it")
	assert.Equal(t, delivery.MessageId, internal.MessageId)
}

// A cancelled processor context leaves the consumer gone, so nothing will ever read msgChan. Before
// forwardDelivery existed the send was unconditional: it stayed parked on the unbuffered channel
// forever, Subscribe never reached its deferred wg.Done, and Processor.Close's wg.Wait waited on it
// forever — a shutdown that only SIGKILL ends.
func TestForwardDeliveryGivesUpWhenTheProcessorContextIsCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	r := &RabbitMQ{subscriptionCtx: context.Background()}

	// Nothing reads this channel: the event loop has already returned.
	msgChan := make(chan queue.Message)

	cancel()

	stopped, err := forwardDeliveryResult(t, r, ctx, msgChan)

	assert.True(t, stopped, "the loop has to end rather than wait for a receiver that is gone")
	assert.NoError(t, err, "a cancelled processor context is the graceful stop, not a failure")
}

func TestForwardDeliveryReportsACancelledSubscription(t *testing.T) {
	subscriptionCtx, cancelSubscription := context.WithCancel(context.Background())

	r := &RabbitMQ{subscriptionCtx: subscriptionCtx}

	msgChan := make(chan queue.Message)

	cancelSubscription()

	stopped, err := forwardDeliveryResult(t, r, context.Background(), msgChan)

	assert.True(t, stopped, "the loop has to end rather than wait for a receiver that is gone")
	assert.ErrorIs(t, err, queue.ErrClosed, "which is what makes the backoff retry resubscribe")
}

// forwardDeliveryResult runs forwardDelivery with no reader on msgChan and fails the test rather
// than hanging the suite if it does not come back.
func forwardDeliveryResult(
	t *testing.T,
	r *RabbitMQ,
	ctx context.Context,
	msgChan chan queue.Message,
) (bool, error) {
	t.Helper()

	type result struct {
		stopped bool
		err     error
	}

	done := make(chan result, 1)

	go func() {
		stopped, err := r.forwardDelivery(ctx, msgChan, amqp.Delivery{Body: []byte(`{"id":1}`)})

		done <- result{stopped: stopped, err: err}
	}()

	select {
	case res := <-done:
		return res.stopped, res.err
	case <-time.After(5 * time.Second):
		t.Fatal("forwardDelivery is still parked on an unbuffered send with no reader")

		return false, nil
	}
}
