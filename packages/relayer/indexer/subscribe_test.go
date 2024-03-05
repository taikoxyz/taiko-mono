package indexer

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_subscribe(t *testing.T) {
	svc, bridge := newTestService(Sync, Subscribe)

	go func() {
		_ = svc.subscribe(context.Background(), mock.MockChainID, new(big.Int).Add(mock.MockChainID, big.NewInt(1)))
	}()

	<-time.After(6 * time.Second)

	b := bridge.(*mock.Bridge)

	assert.Equal(t, 1, b.MessagesSent)
	assert.Equal(t, 1, b.MessageStatusesChanged)
	assert.Equal(t, 2, b.ErrorsSent)
}
