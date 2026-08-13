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

func TestReorgDetectionBaselineUsesHeadWhenNotAboveProposalTip(t *testing.T) {
	head := &types.Header{Number: big.NewInt(9_973_900)}
	headerByNumber := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number != nil {
			t.Fatalf("only the latest header should be fetched when the head does not exceed the proposal tip")
		}
		return head, nil
	}

	baseline := reorgDetectionBaseline(context.Background(), headerByNumber, big.NewInt(9_973_923))
	if baseline != head {
		t.Fatalf("expected the current head to be the baseline, got %+v", baseline)
	}
}

func TestReorgDetectionBaselineUsesOverlapWhenHeadAboveProposalTip(t *testing.T) {
	var (
		proposalTip = big.NewInt(9_973_923)
		head        = &types.Header{Number: big.NewInt(9_973_935)}
		overlap     = &types.Header{Number: big.NewInt(9_973_923), Time: 1}
	)
	headerByNumber := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number == nil {
			return head, nil
		}
		if number.Cmp(proposalTip) != 0 {
			t.Fatalf("expected the overlap header to be fetched at the proposal tip, got %s", number)
		}
		return overlap, nil
	}

	baseline := reorgDetectionBaseline(context.Background(), headerByNumber, proposalTip)
	if baseline != overlap {
		t.Fatalf("expected the canonical header at the proposal tip to be the baseline, got %+v", baseline)
	}
}

func TestReorgDetectionBaselineNilOnHeadFetchError(t *testing.T) {
	headerByNumber := func(context.Context, *big.Int) (*types.Header, error) {
		return nil, errors.New("connection refused")
	}

	if baseline := reorgDetectionBaseline(context.Background(), headerByNumber, big.NewInt(1)); baseline != nil {
		t.Fatalf("expected no baseline when the head cannot be fetched, got %+v", baseline)
	}
}

func TestReorgDetectionBaselineNilOnOverlapFetchError(t *testing.T) {
	headerByNumber := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number == nil {
			return &types.Header{Number: big.NewInt(9_973_935)}, nil
		}
		return nil, errors.New("connection refused")
	}

	if baseline := reorgDetectionBaseline(context.Background(), headerByNumber, big.NewInt(9_973_923)); baseline != nil {
		t.Fatalf("expected no baseline when the overlap header cannot be fetched, got %+v", baseline)
	}
}

// TestIsChainReorgedFalseWhenDescendantsLoseCanonicalMarkersAboveIdenticalTip pins the
// geth-style scenario: the pre-insertion head is above the proposal tip, and re-inserting
// the identical proposal rewinds forkchoice to the tip, removing the canonical markers of
// the higher descendants. Since the baseline is captured at the overlap height, the
// unchanged prefix must still be reported as not reorged.
func TestIsChainReorgedFalseWhenDescendantsLoseCanonicalMarkersAboveIdenticalTip(t *testing.T) {
	var (
		proposalTip = big.NewInt(9_973_923)
		head        = &types.Header{Number: big.NewInt(9_973_935)}
		overlap     = &types.Header{Number: big.NewInt(9_973_923), Time: 1}
	)
	preInsert := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number == nil {
			return head, nil
		}
		return overlap, nil
	}
	postInsert := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number == nil || number.Cmp(proposalTip) > 0 {
			// The canonical markers above the proposal tip were removed by the rewind.
			return nil, ethereum.NotFound
		}
		return overlap, nil
	}

	baseline := reorgDetectionBaseline(context.Background(), preInsert, proposalTip)
	if baseline == nil {
		t.Fatalf("expected a baseline header to be captured")
	}
	if isChainReorged(context.Background(), postInsert, baseline) {
		t.Fatalf("expected no reorg when the overlapping canonical prefix is unchanged")
	}
}

func TestIsChainReorgedTrueWhenOverlappingBlockReplaced(t *testing.T) {
	var (
		proposalTip = big.NewInt(9_973_923)
		head        = &types.Header{Number: big.NewInt(9_973_935)}
		overlap     = &types.Header{Number: big.NewInt(9_973_923), Time: 1}
		replacement = &types.Header{Number: big.NewInt(9_973_923), Time: 2}
	)
	preInsert := func(_ context.Context, number *big.Int) (*types.Header, error) {
		if number == nil {
			return head, nil
		}
		return overlap, nil
	}
	postInsert := func(context.Context, *big.Int) (*types.Header, error) {
		return replacement, nil
	}

	baseline := reorgDetectionBaseline(context.Background(), preInsert, proposalTip)
	if baseline == nil {
		t.Fatalf("expected a baseline header to be captured")
	}
	if !isChainReorged(context.Background(), postInsert, baseline) {
		t.Fatalf("expected a reorg when an overlapping canonical block was replaced")
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
