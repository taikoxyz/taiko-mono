package state

import (
	"errors"
	"reflect"
	"testing"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

func TestFindBatchForBlockIDByCountEmptyBatches(t *testing.T) {
	_, err := findBatchForBlockIDByCount(10, 0, func(uint64) (*pacayaBindings.ITaikoInboxBatch, error) {
		t.Fatal("getBatchByID should not be called when numBatches is zero")
		return nil, nil
	})
	if err == nil || err.Error() != "no batches found" {
		t.Fatalf("expected no batches found error, got: %v", err)
	}
}

func TestFindBatchForBlockIDFromLatestOneBatchNoUnderflow(t *testing.T) {
	calls := make([]uint64, 0, 1)
	getBatchByID := func(batchID uint64) (*pacayaBindings.ITaikoInboxBatch, error) {
		calls = append(calls, batchID)
		if batchID != 0 {
			t.Fatalf("unexpected batch ID: %d", batchID)
		}
		return &pacayaBindings.ITaikoInboxBatch{
			BatchId:     0,
			LastBlockId: 100,
		}, nil
	}

	batch, err := findBatchForBlockIDByCount(50, 1, getBatchByID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if batch == nil || batch.BatchId != 0 {
		t.Fatalf("unexpected batch: %+v", batch)
	}
	if !reflect.DeepEqual(calls, []uint64{0}) {
		t.Fatalf("unexpected call sequence: %+v", calls)
	}
}

func TestFindBatchForBlockIDFromLatestReturnsLastMatchedBatch(t *testing.T) {
	batches := map[uint64]*pacayaBindings.ITaikoInboxBatch{
		2: {BatchId: 2, LastBlockId: 30},
		1: {BatchId: 1, LastBlockId: 20},
		0: {BatchId: 0, LastBlockId: 10},
	}
	calls := make([]uint64, 0, 2)

	getBatchByID := func(batchID uint64) (*pacayaBindings.ITaikoInboxBatch, error) {
		calls = append(calls, batchID)
		b, ok := batches[batchID]
		if !ok {
			return nil, errors.New("missing batch")
		}
		return b, nil
	}

	batch, err := findBatchForBlockIDFromLatest(25, 2, getBatchByID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if batch == nil || batch.BatchId != 2 {
		t.Fatalf("expected batch 2, got: %+v", batch)
	}
	if !reflect.DeepEqual(calls, []uint64{2, 1}) {
		t.Fatalf("unexpected call sequence: %+v", calls)
	}
}

func TestFindBatchForBlockIDFromLatestStopsAtZeroBoundary(t *testing.T) {
	batches := map[uint64]*pacayaBindings.ITaikoInboxBatch{
		2: {BatchId: 2, LastBlockId: 30},
		1: {BatchId: 1, LastBlockId: 29},
		0: {BatchId: 0, LastBlockId: 28},
	}
	calls := make([]uint64, 0, 3)

	getBatchByID := func(batchID uint64) (*pacayaBindings.ITaikoInboxBatch, error) {
		calls = append(calls, batchID)
		b, ok := batches[batchID]
		if !ok {
			return nil, errors.New("missing batch")
		}
		return b, nil
	}

	batch, err := findBatchForBlockIDFromLatest(28, 2, getBatchByID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if batch == nil || batch.BatchId != 0 {
		t.Fatalf("expected batch 0, got: %+v", batch)
	}
	if !reflect.DeepEqual(calls, []uint64{2, 1, 0}) {
		t.Fatalf("unexpected call sequence: %+v", calls)
	}
}
