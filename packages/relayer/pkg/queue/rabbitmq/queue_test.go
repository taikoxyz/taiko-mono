package rabbitmq

import (
	"testing"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/stretchr/testify/require"
)

func TestLogNotifyCloseHandlesNilError(t *testing.T) {
	require.NotPanics(t, func() {
		logNotifyClose("rabbitmq notify close connection", nil)
	})
}

func TestLogNotifyCloseHandlesNonNilError(t *testing.T) {
	require.NotPanics(t, func() {
		logNotifyClose("rabbitmq notify close channel", &amqp.Error{Reason: "channel closed"})
	})
}
