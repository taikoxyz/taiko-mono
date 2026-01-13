package preconfblocks

import (
	"reflect"

	"github.com/ethereum/go-ethereum/common"
)

func (s *PreconfBlockAPIServerTestSuite) TestLookheadMergeRangesEmpty() {
	s.Len(mergeRanges([]SlotRange{}), 0, "expected empty slice")
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadMergeRangesNonOverlapping() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 10, End: 15}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, input), "expected %v, got %v", input, got)
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadMergeRangesOverlapping() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 3, End: 10}, {Start: 8, End: 12}}
	want := []SlotRange{{Start: 0, End: 12}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadMergeRangesAdjacent() {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 5, End: 8}}
	want := []SlotRange{{Start: 0, End: 8}}
	got := mergeRanges(input)
	s.True(reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadSequencingWindowSplit() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	w.Push(0, addr, other) // addr is curr at epoch 0
	w.Push(1, other, addr) // addr is next at epoch 1

	currRanges := w.SequencingWindowSplit(addr, true, handoverSlots)
	nextRanges := w.SequencingWindowSplit(addr, false, handoverSlots)

	s.True(reflect.DeepEqual(currRanges,
		[]SlotRange{
			{Start: 0, End: 28},
		}), "currRanges = %v", currRanges)
	s.True(reflect.DeepEqual(nextRanges, []SlotRange{{Start: 60, End: 64}}), "nextRanges = %v", nextRanges)
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadSequencingWindowSplitWithDualEpochPush() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	w.Push(0, addr, other) // addr is curr at epoch 0
	w.Push(1, other, addr) // addr is next at epoch 1
	w.Push(2, addr, other) // addr is curr again at epoch 2

	currRanges := w.SequencingWindowSplit(addr, true, handoverSlots)
	nextRanges := w.SequencingWindowSplit(addr, false, handoverSlots)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 0, End: 28},
		{Start: 64, End: 92},
	}), "currRanges addr = %v", currRanges)

	s.True(reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 60, End: 64},
	}), "nextRanges addr = %v", nextRanges)

	currRanges = w.SequencingWindowSplit(other, true, handoverSlots)
	nextRanges = w.SequencingWindowSplit(other, false, handoverSlots)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 32, End: 60},
	}), "currRanges other = %v", currRanges)

	s.True(reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 28, End: 32},
		{Start: 92, End: 96},
	}), "nextRanges other = %v", nextRanges)
}

func (s *PreconfBlockAPIServerTestSuite) TestLookheadSequencingWindowSplitCurrRange() {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	w.Push(0, addr, addr)
	w.Push(1, addr, common.Address{})

	currRanges := w.SequencingWindowSplit(addr, true, handoverSlots)
	nextRanges := w.SequencingWindowSplit(addr, false, handoverSlots)

	s.True(reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 0, End: 28},
		{Start: 32, End: 60},
	}), "currRanges = %v", currRanges)

	s.True(reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 28, End: 32},
	}), "nextRanges = %v", nextRanges)
}
