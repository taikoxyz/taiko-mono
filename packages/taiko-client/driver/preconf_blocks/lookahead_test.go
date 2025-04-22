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

func TestSequencingWindow_SingleEpoch(t *testing.T) {
	w := NewOpWindow()
	addr := common.HexToAddress("0xabc")
	other := common.HexToAddress("0xdef")
	// only curr matches
	w.Push(1, addr, other)
	got := w.SequencingWindow(addr, 10, 100)
	want := []SlotRange{{Start: 100, End: 190}}
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func TestSequencingWindow_MultipleEpochs(t *testing.T) {
	w := NewOpWindow()
	addr := common.HexToAddress("0xabc")
	// epoch0: curr, epoch1: next
	w.Push(0, addr, common.Address{})
	w.Push(1, common.Address{}, addr)
	got := w.SequencingWindow(addr, 10, 100)
	want := []SlotRange{{Start: 0, End: 90}, {Start: 100, End: 190}}
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func TestSequencingWindow_AdjacentEpochsMerged(t *testing.T) {
	w := NewOpWindow()
	addr := common.HexToAddress("0xabc")
	w.Push(0, addr, common.Address{})
	w.Push(1, addr, common.Address{})
	got := w.SequencingWindow(addr, 0, 100)
	want := []SlotRange{{Start: 0, End: 200}}
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}

func TestSequencingWindow_Gaps(t *testing.T) {
	w := NewOpWindow()
	addr := common.HexToAddress("0xabc")
	// non‑adjacent epochs 0 and 2
	w.Push(0, addr, common.Address{})
	w.Push(2, addr, common.Address{})
	got := w.SequencingWindow(addr, 0, 100)
	want := []SlotRange{{Start: 0, End: 100}, {Start: 200, End: 300}}
	assert.True(t, reflect.DeepEqual(got, want), "expected %v, got %v", want, got)
}
