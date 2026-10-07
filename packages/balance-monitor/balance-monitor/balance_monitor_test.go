package balanceMonitor

import (
	"context"
	"testing"
	"time"
)

// TestStartReturnsImmediately proves the fix for the shutdown deadlock: Start
// must return right away and run the check loop in a background goroutine.
//
// Pre-fix, Start ran the loop on the caller's goroutine and only returned once
// the context was cancelled, so the CLI wrapper could never reach its signal
// handling or deferred Close. On the pre-fix code this test times out.
func TestStartReturnsImmediately(t *testing.T) {
	b := &BalanceMonitor{interval: time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	b.ctx = ctx

	done := make(chan error, 1)
	go func() { done <- b.Start() }()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("Start() returned unexpected error: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Start() blocked; it must return immediately and run the loop in a goroutine")
	}
}

// TestCloseWaitsForEventLoop proves the graceful-shutdown half: after Start,
// Close must block until the background loop exits on context cancellation, so
// the RPC clients are not closed while the loop is still using them.
//
// Pre-fix, Close had no WaitGroup and returned immediately, so the "Close must
// not have returned yet" assertion fails against the original code.
func TestCloseWaitsForEventLoop(t *testing.T) {
	b := &BalanceMonitor{interval: time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	b.ctx = ctx

	if err := b.Start(); err != nil {
		t.Fatalf("Start() returned error: %v", err)
	}

	// Close must block while the event loop is still running.
	closed := make(chan struct{})
	go func() {
		b.Close(context.Background())
		close(closed)
	}()

	select {
	case <-closed:
		t.Fatal("Close() returned before the event loop exited; it must wait for the loop")
	case <-time.After(200 * time.Millisecond):
		// Expected: Close is still waiting.
	}

	// Cancelling the context lets the loop exit, after which Close returns.
	cancel()

	select {
	case <-closed:
	case <-time.After(2 * time.Second):
		t.Fatal("Close() blocked after context cancellation; the loop did not exit")
	}
}
