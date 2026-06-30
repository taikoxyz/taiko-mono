package rpc

import (
	"context"
	"errors"
	"math/big"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

var (
	ZeroAddress         common.Address
	BlockMaxTxListBytes uint64 = (params.BlobTxBytesPerFieldElement - 1) * params.BlobTxFieldElementsPerBlob
	// DefaultInterruptSignals is a set of default interrupt signals.
	DefaultInterruptSignals = []os.Signal{
		os.Interrupt,
		os.Kill,
		syscall.SIGTERM,
		syscall.SIGQUIT,
	}
	ErrInvalidLength = errors.New("invalid length")
	ErrSlotBMarshal  = errors.New("abi: cannot marshal in to go type: length insufficient 160 require 192")
)

// SetHead makes a `debug_setHead` RPC call to set the chain's head, should only be used
// for testing purpose.
func SetHead(ctx context.Context, client *EthClient, headNum *big.Int) error {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	return client.SetHead(ctxWithTimeout, headNum)
}

// StringToBytes32 converts the given string to [32]byte.
func StringToBytes32(str string) [32]byte {
	var b [32]byte
	copy(b[:], []byte(str))

	return b
}

// CtxWithTimeoutOrDefault sets a context timeout if the deadline has not passed or is not set,
// and otherwise returns the context as passed in. cancel func is always set to an empty function
// so is safe to defer the cancel.
func CtxWithTimeoutOrDefault(ctx context.Context, defaultTimeout time.Duration) (context.Context, context.CancelFunc) {
	if utils.IsNil(ctx) {
		return context.WithTimeout(context.Background(), defaultTimeout)
	}
	if _, ok := ctx.Deadline(); !ok {
		return context.WithTimeout(ctx, defaultTimeout)
	}

	return ctx, func() {}
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
