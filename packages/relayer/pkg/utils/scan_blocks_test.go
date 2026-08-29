package utils

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// headSubscription is a subscription whose error channel the test drives.
type headSubscription struct {
	errChan      chan error
	unsubscribed bool
}

func (s *headSubscription) Err() <-chan error { return s.errChan }
func (s *headSubscription) Unsubscribe()      { s.unsubscribed = true }

// fakeHeadSubscriber stands in for a node. subscribed closes once ScanBlocks has handed over its
// channel, which is what lets a test push headers without racing the goroutine.
type fakeHeadSubscriber struct {
	sub        *headSubscription
	err        error
	headers    chan<- *types.Header
	subscribed chan struct{}
}

func newFakeHeadSubscriber() *fakeHeadSubscriber {
	return &fakeHeadSubscriber{
		sub:        &headSubscription{errChan: make(chan error, 1)},
		subscribed: make(chan struct{}),
	}
}

func (f *fakeHeadSubscriber) SubscribeNewHead(
	_ context.Context,
	ch chan<- *types.Header,
) (ethereum.Subscription, error) {
	if f.err != nil {
		return nil, f.err
	}

	f.headers = ch
	close(f.subscribed)

	return f.sub, nil
}

// runScanBlocks starts ScanBlocks and returns a channel carrying its error once it returns.
func runScanBlocks(ctx context.Context, client headSubscriber, wg *sync.WaitGroup) chan error {
	done := make(chan error, 1)

	go func() { done <- ScanBlocks(ctx, client, wg) }()

	return done
}

func TestScanBlocks_ReturnsTheSubscribeError(t *testing.T) {
	client := newFakeHeadSubscriber()
	client.err = errors.New("dial tcp: connect: connection refused")

	var wg sync.WaitGroup

	err := ScanBlocks(context.Background(), client, &wg)

	require.ErrorContains(t, err, "connection refused")

	// The deferred Done has to run even on the early return, or a caller's Close would hang on a
	// WaitGroup that never drains.
	waitTimeout(t, &wg)
}

func TestScanBlocks_CountsEveryNewHead(t *testing.T) {
	client := newFakeHeadSubscriber()

	var wg sync.WaitGroup

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := runScanBlocks(ctx, client, &wg)

	<-client.subscribed

	before := testutil.ToFloat64(relayer.BlocksScanned)

	for i := 0; i < 3; i++ {
		client.headers <- &types.Header{}
	}

	// A fourth send only returns once the third has been received, so by the time it does the
	// counter for all three is already incremented.
	client.headers <- &types.Header{}

	cancel()

	require.NoError(t, <-done, "a cancelled context is a clean shutdown, not a failure")
	assert.GreaterOrEqual(t, testutil.ToFloat64(relayer.BlocksScanned)-before, float64(3))

	waitTimeout(t, &wg)
}

func TestScanBlocks_ReturnsTheSubscriptionError(t *testing.T) {
	client := newFakeHeadSubscriber()

	var wg sync.WaitGroup

	done := runScanBlocks(context.Background(), client, &wg)

	<-client.subscribed

	// A subscription that drops has to surface, not leave the caller scanning nothing forever.
	client.sub.errChan <- errors.New("subscription closed")

	require.ErrorContains(t, <-done, "subscription closed")

	waitTimeout(t, &wg)
}

// waitTimeout fails the test if wg does not drain promptly.
func waitTimeout(t *testing.T, wg *sync.WaitGroup) {
	t.Helper()

	drained := make(chan struct{})

	go func() {
		wg.Wait()
		close(drained)
	}()

	select {
	case <-drained:
	case <-time.After(5 * time.Second):
		t.Fatal("WaitGroup never drained")
	}
}
