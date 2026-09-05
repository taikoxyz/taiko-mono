package rabbitmq

import (
	"errors"
	"testing"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
