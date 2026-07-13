package submitter

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func TestRetryProofPollingRetriesExpectedErrors(t *testing.T) {
	attempts := 0
	err := retryProofPolling(context.Background(), time.Millisecond, func() error {
		attempts++
		if attempts < 3 {
			return proofProducer.ErrProofInProgress
		}
		return nil
	})
	require.NoError(t, err)
	require.Equal(t, 3, attempts)
}

func TestRetryProofPollingReturnsUnexpectedErrorImmediately(t *testing.T) {
	want := errors.New("raiko unavailable")
	attempts := 0
	err := retryProofPolling(context.Background(), time.Millisecond, func() error {
		attempts++
		return want
	})
	require.ErrorIs(t, err, want)
	require.Equal(t, 1, attempts)
}

func TestRetryProofPollingReturnsContextErrorOnCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	attempts := 0
	err := retryProofPolling(ctx, time.Millisecond, func() error {
		attempts++
		return nil
	})
	require.ErrorIs(t, err, context.Canceled)
	require.Equal(t, 0, attempts)
}

func TestRetryProofPollingReturnsContextErrorWhenCanceledDuringOperation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	err := retryProofPolling(ctx, time.Millisecond, func() error {
		cancel()
		return nil
	})
	require.ErrorIs(t, err, context.Canceled)
}
