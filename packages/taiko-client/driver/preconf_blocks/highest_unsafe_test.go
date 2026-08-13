package preconfblocks

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
)

func TestReconciledHighestUnsafeFollowsLiveHeadDown(t *testing.T) {
	if got := reconciledHighestUnsafe(&types.Header{Number: big.NewInt(9_973_923)}, 9_973_936); got != 9_973_923 {
		t.Fatalf("expected the marker to follow the live head down, got %d", got)
	}
}

func TestReconciledHighestUnsafeFollowsLiveHeadUp(t *testing.T) {
	if got := reconciledHighestUnsafe(&types.Header{Number: big.NewInt(9_973_940)}, 9_973_936); got != 9_973_940 {
		t.Fatalf("expected the marker to follow the live head up, got %d", got)
	}
}

func TestReconciledHighestUnsafeKeepsCurrentWhenHeadUnavailable(t *testing.T) {
	if got := reconciledHighestUnsafe(nil, 9_973_936); got != 9_973_936 {
		t.Fatalf("expected the current marker to be kept when the head cannot be read, got %d", got)
	}
}
