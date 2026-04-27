package proposer

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

const nonceModeEnv = "NONCE_MODE"

func nonceModeFromEnv() (string, error) {
	mode := strings.TrimSpace(strings.ToLower(os.Getenv(nonceModeEnv)))
	if mode == "" {
		return "latest", nil
	}
	switch mode {
	case "pending", "latest":
		return mode, nil
	default:
		return "", fmt.Errorf("invalid %s: %s (expected pending or latest)", nonceModeEnv, mode)
	}
}

func selectNonce(
	ctx context.Context,
	addr common.Address,
	pendingFn func(context.Context, common.Address) (uint64, error),
	latestFn func(context.Context, common.Address) (uint64, error),
) (uint64, error) {
	mode, err := nonceModeFromEnv()
	if err != nil {
		return 0, err
	}
	if mode == "pending" {
		return pendingFn(ctx, addr)
	}
	return latestFn(ctx, addr)
}

func TestNonceModeFromEnv_DefaultsToLatest(t *testing.T) {
	t.Setenv(nonceModeEnv, "")

	mode, err := nonceModeFromEnv()

	require.NoError(t, err)
	require.Equal(t, "latest", mode)
}

func TestNonceModeFromEnv_Latest(t *testing.T) {
	t.Setenv(nonceModeEnv, "latest")

	mode, err := nonceModeFromEnv()

	require.NoError(t, err)
	require.Equal(t, "latest", mode)
}

func TestNonceModeFromEnv_Invalid(t *testing.T) {
	t.Setenv(nonceModeEnv, "nope")

	_, err := nonceModeFromEnv()

	require.Error(t, err)
}

func TestSelectNonce_UsesPending(t *testing.T) {
	t.Setenv(nonceModeEnv, "pending")

	calledPending := false
	pendingFn := func(ctx context.Context, addr common.Address) (uint64, error) {
		calledPending = true
		return 7, nil
	}
	latestFn := func(ctx context.Context, addr common.Address) (uint64, error) {
		return 9, nil
	}

	nonce, err := selectNonce(context.Background(), common.Address{}, pendingFn, latestFn)

	require.NoError(t, err)
	require.True(t, calledPending)
	require.Equal(t, uint64(7), nonce)
}

func TestSelectNonce_UsesLatest(t *testing.T) {
	t.Setenv(nonceModeEnv, "latest")

	calledLatest := false
	pendingFn := func(ctx context.Context, addr common.Address) (uint64, error) {
		return 7, nil
	}
	latestFn := func(ctx context.Context, addr common.Address) (uint64, error) {
		calledLatest = true
		return 9, nil
	}

	nonce, err := selectNonce(context.Background(), common.Address{}, pendingFn, latestFn)

	require.NoError(t, err)
	require.True(t, calledLatest)
	require.Equal(t, uint64(9), nonce)
}
