package p2p

import (
	"context"
	"log/slog"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func Test_Network(t *testing.T) {
	n, err := NewNetwork(context.Background(), "", 0)
	assert.Nil(t, err)
	defer n.Close()

	n2, err := NewNetwork(context.Background(), n.localFullAddr, 0)
	assert.Nil(t, err)
	defer n2.Close()

	time.Sleep(2 * time.Second) // Allow discovery to propagate

	assert.Equal(t, 1, len(n2.peers))

	assert.Equal(t, 1, len(n.peers))

	ctx, cancel := context.WithCancel(context.Background())

	defer cancel()

	assert.Nil(t, JoinTopic(context.Background(), n, "test", func(_ context.Context, data []byte) error {
		slog.Info("Node n received message", "data", string(data))
		assert.Equal(t, data, []byte("hello"))
		return nil
	}))

	assert.Nil(t, JoinTopic(context.Background(), n2, "test", func(_ context.Context, data []byte) error {
		slog.Info("Node n2 received message", "data", string(data))
		assert.Equal(t, data, []byte("hello"))
		return nil
	}))

	go func() {
		assert.Nil(t, SubscribeToTopic[[]byte](ctx, n, "test"))
	}()

	assert.Nil(t, Publish(context.Background(), n2, "test", []byte("hello")))

	time.Sleep(3 * time.Second)
	assert.Equal(t, 1, n.receivedMessages)
}
