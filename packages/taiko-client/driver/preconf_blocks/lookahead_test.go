package preconfblocks

import (
	"reflect"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
)

func TestMergeRanges_Empty(t *testing.T) {
	got := mergeRanges([]SlotRange{})
	assert.Len(t, got, 0, "expected empty slice")
}

func TestMergeRanges_NonOverlapping(t *testing.T) {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 10, End: 15}}
	got := mergeRanges(input)
	assert.True(t, reflect.DeepEqual(got, input), "expected %v, got %v", input, got)
}

func TestMergeRanges_Overlapping(t *testing.T) {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 3, End: 10}, {Start: 8, End: 12}}
	want := []SlotRange{{Start: 0, End: 12}}
	got := mergeRanges(input)
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func TestMergeRanges_Adjacent(t *testing.T) {
	input := []SlotRange{{Start: 0, End: 5}, {Start: 5, End: 8}}
	want := []SlotRange{{Start: 0, End: 8}}
	got := mergeRanges(input)
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func TestSequencingWindowSplit(t *testing.T) {
	handoverSlots := uint64(4)
	slotsPerEpoch := uint64(32)

	w := NewOpWindow(handoverSlots, slotsPerEpoch)
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	w.Push(0, addr, other) // addr is curr at epoch 0
	w.Push(1, other, addr) // addr is next at epoch 1

	currRanges := w.SequencingWindowSplit(addr, true)
	nextRanges := w.SequencingWindowSplit(addr, false)

	assert.True(t, reflect.DeepEqual(currRanges, []SlotRange{{Start: 0, End: 28}}), "currRanges = %v", currRanges)
	assert.True(t, reflect.DeepEqual(nextRanges, []SlotRange{{Start: 60, End: 64}}), "nextRanges = %v", nextRanges)
}

func TestSequencingWindowSplit_WithDualEpochPush(t *testing.T) {
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

	assert.True(t, reflect.DeepEqual(currRanges, []SlotRange{
		{Start: 0, End: 28},
		{Start: 64, End: 92},
	}), "currRanges = %v", currRanges)

	assert.True(t, reflect.DeepEqual(nextRanges, []SlotRange{
		{Start: 60, End: 64},
	}), "nextRanges = %v", nextRanges)
}
