package utils

import (
	"context"
	"os"
	"os/signal"
	"syscall"
)

// DefaultInterruptSignals is a set of default interrupt signals.
var DefaultInterruptSignals = []os.Signal{
	os.Interrupt,
	os.Kill,
	syscall.SIGTERM,
	syscall.SIGQUIT,
}

// BlockOnInterruptsContext blocks until a SIGTERM is received.
// Passing in signals will override the default signals.
// The function will stop blocking if the context is closed.
func BlockOnInterruptsContext(ctx context.Context, signals ...os.Signal) {
	if len(signals) == 0 {
		signals = DefaultInterruptSignals
	}
	interruptChannel := make(chan os.Signal, 1)
	signal.Notify(interruptChannel, signals...)
	select {
	case <-interruptChannel:
	case <-ctx.Done():
		signal.Stop(interruptChannel)
	}
}