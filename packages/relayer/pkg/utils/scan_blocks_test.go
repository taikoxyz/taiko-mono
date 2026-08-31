package utils

import (
	"context"
	"math/big"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type pollingHeadClient struct {
	calls      atomic.Int64
	headNumber atomic.Int64
}

func (c *pollingHeadClient) HeaderByNumber(context.Context, *big.Int) (*types.Header, error) {
	headNumber := c.headNumber.Load()
	c.calls.Add(1)
	return &types.Header{Number: big.NewInt(headNumber)}, nil
}

func TestScanBlocksCountsObservedHeadChanges(t *testing.T) {
	client := new(pollingHeadClient)
	client.headNumber.Store(42)
	ctx, cancel := context.WithCancel(context.Background())
	before := testutil.ToFloat64(relayer.BlocksScanned)
	errCh := make(chan error, 1)

	go func() {
		errCh <- scanBlocks(ctx, client, time.Millisecond, time.Second)
	}()

	require.Eventually(t, func() bool {
		return client.calls.Load() >= 1
	}, time.Second, time.Millisecond)
	client.headNumber.Store(43)
	require.Eventually(t, func() bool {
		return testutil.ToFloat64(relayer.BlocksScanned)-before == 1
	}, time.Second, time.Millisecond)
	cancel()

	require.NoError(t, <-errCh)
	require.Equal(t, float64(1), testutil.ToFloat64(relayer.BlocksScanned)-before)
}

func TestScanBlocksPollsHeadWithoutDoubleCountingUnchangedHead(t *testing.T) {
	client := new(pollingHeadClient)
	ctx, cancel := context.WithCancel(context.Background())
	before := testutil.ToFloat64(relayer.BlocksScanned)
	errCh := make(chan error, 1)

	go func() {
		errCh <- scanBlocks(ctx, client, time.Millisecond, time.Second)
	}()

	require.Eventually(t, func() bool {
		return client.calls.Load() >= 2
	}, time.Second, time.Millisecond)
	cancel()

	require.NoError(t, <-errCh)
	require.Equal(t, float64(0), testutil.ToFloat64(relayer.BlocksScanned)-before)
}

type blockingHeadClient struct{}

func (*blockingHeadClient) HeaderByNumber(ctx context.Context, _ *big.Int) (*types.Header, error) {
	<-ctx.Done()
	return nil, ctx.Err()
}

func TestScanBlocksBoundsEachHeadRequest(t *testing.T) {
	started := time.Now()
	err := scanBlocks(context.Background(), new(blockingHeadClient), time.Hour, 20*time.Millisecond)

	require.ErrorIs(t, err, context.DeadlineExceeded)
	require.Less(t, time.Since(started), time.Second)
}
