package blocksinserter

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/core/types"
)

func TestIsChainReorgedFalseWhenPreviousHeadStillCanonical(t *testing.T) {
	previousHead := &types.Header{Number: big.NewInt(9_973_935)}
	headerByNumber := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number.Cmp(previousHead.Number) != 0 {
			t.Fatalf("unexpected block number queried: %s", number)
		}
		return previousHead, nil
	}

	if isChainReorged(context.Background(), headerByNumber, previousHead) {
		t.Fatalf("expected no reorg when the previous head is still canonical at its height")
	}
}

func TestIsChainReorgedTrueWhenHashDiffersAtPreviousHeight(t *testing.T) {
	previousHead := &types.Header{Number: big.NewInt(9_973_935)}
	replacement := &types.Header{Number: big.NewInt(9_973_935), Time: 1}
	headerByNumber := func(context.Context, *big.Int) (*types.Header, error) {
		return replacement, nil
	}

	if !isChainReorged(context.Background(), headerByNumber, previousHead) {
		t.Fatalf("expected a reorg when a different header occupies the previous head's height")
	}
}

func TestIsChainReorgedTrueWhenPreviousHeightNoLongerExists(t *testing.T) {
	previousHead := &types.Header{Number: big.NewInt(9_973_935)}
	headerByNumber := func(context.Context, *big.Int) (*types.Header, error) {
		return nil, ethereum.NotFound
	}

	if !isChainReorged(context.Background(), headerByNumber, previousHead) {
		t.Fatalf("expected a reorg when the previous head's height is no longer on the canonical chain")
	}
}

func TestIsChainReorgedTrueWhenBaselineUnknown(t *testing.T) {
	headerByNumber := func(context.Context, *big.Int) (*types.Header, error) {
		t.Fatalf("headerByNumber should not be called without a baseline head")
		return nil, nil
	}

	if !isChainReorged(context.Background(), headerByNumber, nil) {
		t.Fatalf("expected the conservative reorged=true result when no baseline head was captured")
	}
}

func TestIsChainReorgedTrueOnFetchError(t *testing.T) {
	previousHead := &types.Header{Number: big.NewInt(9_973_935)}
	headerByNumber := func(context.Context, *big.Int) (*types.Header, error) {
		return nil, errors.New("connection refused")
	}

	if !isChainReorged(context.Background(), headerByNumber, previousHead) {
		t.Fatalf("expected the conservative reorged=true result when the canonical chain cannot be inspected")
	}
}
