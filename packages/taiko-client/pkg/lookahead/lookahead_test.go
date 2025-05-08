package lookahead

import (
	"reflect"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

type LookaheadTestSuite struct {
	testutils.ClientTestSuite
}

func (s *LookaheadTestSuite) TestLookheadMergeRangesEmpty() {
	s.Len(mergeRanges([]SlotRange{}), 0, "expected empty slice")
}

func (s *LookaheadTestSuite) TestLookheadMergeRangesNonOverlapping() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 10, End: 15}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, input), "expected %v, got %v", input, got)
}

func (s *LookaheadTestSuite) TestLookheadMergeRangesOverlapping() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 3, End: 10}, {Start: 8, End: 12}}
	want := []SlotRange{{Start: 0, End: 12}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func (s *LookaheadTestSuite) TestLookheadMergeRangesAdjacent() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 5, End: 8}}
	want := []SlotRange{{Start: 0, End: 8}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func (s *LookaheadTestSuite) TestLookheadSequencingWindowSplit() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(handoverSlots, slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	w.Push(0, addr, other) // addr is curr at epoch 0
	w.Push(1, other, addr) // addr is next at epoch 1

	currRanges := w.SequencingWindowSplit(addr, true)
	nextRanges := w.SequencingWindowSplit(addr, false)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{{Start: 0, End: 28}}), "currRanges = %v", currRanges)
	s.True(reflect.DeepEqual(nextRanges, []SlotRange{{Start: 60, End: 64}}), "nextRanges = %v", nextRanges)
}

func (s *LookaheadTestSuite) TestLookheadSequencingWindowSplitWithDualEpochPush() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(handoverSlots, slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	w.Push(0, addr, other) // addr is curr at epoch 0
	w.Push(1, other, addr) // addr is next at epoch 1
	w.Push(2, addr, other) // addr is curr again at epoch 2

	currRanges := w.SequencingWindowSplit(addr, true)
	nextRanges := w.SequencingWindowSplit(addr, false)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 0, End: 28},
		{Start: 64, End: 92},
	}), "currRanges = %v", currRanges)

	s.True(reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 60, End: 64},
	}), "nextRanges = %v", nextRanges)
}

func (s *LookaheadTestSuite) TestLookheadSequencingWindowSplitCurrRange() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(handoverSlots, slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	w.Push(0, addr, addr)
	w.Push(1, addr, common.Address{})

	currRanges := w.SequencingWindowSplit(addr, true)
	nextRanges := w.SequencingWindowSplit(addr, false)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 0, End: 28},
		{Start: 32, End: 60},
	}), "currRanges = %v", currRanges)

	s.True(reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 28, End: 32},
	}), "nextRanges = %v", nextRanges)
}
