package producer

import (
	"math/big"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestProofBuffer(t *testing.T) {
	// Initialize the buffer.
	bufferSize := 5
	b := NewProofBuffer(uint64(bufferSize))
	require.Zero(t, b.Len())
	require.Less(t, b.FirstItemAt(), time.Now())
	require.False(t, b.IsAggregating())

	// Write items to the buffer.
	for i := 0; i < bufferSize; i++ {
		_, err := b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(uint64(i))})
		require.NoError(t, err)
		require.Equal(t, i+1, b.Len())
	}

	// Mark its aggregating status.
	b.MarkAggregatingIfNot()
	require.True(t, b.IsAggregating())

	// Clear items from the buffer.
	blockIDs := []uint64{}
	for i := 0; i < bufferSize; i++ {
		blockIDs = append(blockIDs, uint64(i))
	}
	require.Equal(t, bufferSize, b.ClearItems(blockIDs...))
	require.Zero(t, b.Len())
	require.False(t, b.IsAggregating())
}

func TestProofBuffer_DuplicateBatchID(t *testing.T) {
	b := NewProofBuffer(10)

	// Test 1: Add an item with BatchID 1
	batchID1 := new(big.Int).SetUint64(1)
	_, err := b.Write(&ProofResponse{BatchID: batchID1})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len())

	// Test 2: Try to add another item with the same BatchID 1 - should succeed without adding
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(1)})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len()) // Length should remain 1 (idempotent)

	// Test 3: Add an item with different BatchID 2 - should succeed
	batchID2 := new(big.Int).SetUint64(2)
	_, err = b.Write(&ProofResponse{BatchID: batchID2})
	require.NoError(t, err)
	require.Equal(t, 2, b.Len())

	// Test 4: Try to add duplicate BatchID 2 - should succeed without adding
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(2)})
	require.NoError(t, err)
	require.Equal(t, 2, b.Len())

	// Test 5: Add multiple unique BatchIDs
	for i := 3; i <= 5; i++ {
		_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(uint64(i))})
		require.NoError(t, err)
	}
	require.Equal(t, 5, b.Len())

	// Test 6: Try to add duplicate in the middle - should succeed without adding
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(3)})
	require.NoError(t, err)
	require.Equal(t, 5, b.Len())
}

func TestProofBuffer_DuplicateBatchID_AfterClear(t *testing.T) {
	b := NewProofBuffer(10)

	// Add items with BatchID 1, 2, 3
	for i := 1; i <= 3; i++ {
		_, err := b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(uint64(i))})
		require.NoError(t, err)
	}
	require.Equal(t, 3, b.Len())

	// Clear item with BatchID 2
	clearedCount := b.ClearItems(2)
	require.Equal(t, 1, clearedCount)
	require.Equal(t, 2, b.Len())

	// Now we should be able to add BatchID 2 again
	_, err := b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(2)})
	require.NoError(t, err)
	require.Equal(t, 3, b.Len())

	// BatchID 1 is still in buffer, so adding it should succeed without increasing length
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(1)})
	require.NoError(t, err)
	require.Equal(t, 3, b.Len())
}

func TestProofBuffer_NilBatchID(t *testing.T) {
	b := NewProofBuffer(10)

	// Test 1: Add item with nil BatchID - should fail
	_, err := b.Write(&ProofResponse{BatchID: nil})
	require.ErrorIs(t, err, ErrNilBatchID)
	require.Equal(t, 0, b.Len())

	// Test 2: Add another item with nil BatchID - should fail again
	_, err = b.Write(&ProofResponse{BatchID: nil})
	require.ErrorIs(t, err, ErrNilBatchID)
	require.Equal(t, 0, b.Len())

	// Test 3: Add item with valid BatchID - should succeed
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(1)})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len())

	// Test 4: Try to add nil BatchID after valid one - should still fail
	_, err = b.Write(&ProofResponse{BatchID: nil})
	require.ErrorIs(t, err, ErrNilBatchID)
	require.Equal(t, 1, b.Len())

	// Test 5: Try to add duplicate valid BatchID - should succeed without adding
	_, err = b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(1)})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len())
}

func TestProofBuffer_LargeBatchID(t *testing.T) {
	b := NewProofBuffer(10)

	// Test with large BatchID values
	largeBatchID1 := new(big.Int)
	largeBatchID1.SetString("123456789012345678901234567890", 10)

	_, err := b.Write(&ProofResponse{BatchID: largeBatchID1})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len())

	// Try to add the same large BatchID - should succeed without adding
	largeBatchID2 := new(big.Int)
	largeBatchID2.SetString("123456789012345678901234567890", 10)
	_, err = b.Write(&ProofResponse{BatchID: largeBatchID2})
	require.NoError(t, err)
	require.Equal(t, 1, b.Len())

	// Add a different large BatchID - should succeed
	largeBatchID3 := new(big.Int)
	largeBatchID3.SetString("987654321098765432109876543210", 10)
	_, err = b.Write(&ProofResponse{BatchID: largeBatchID3})
	require.NoError(t, err)
	require.Equal(t, 2, b.Len())
}

func TestProofBuffer_DuplicateWhenFull(t *testing.T) {
	b := NewProofBuffer(3)

	for i := 1; i <= 3; i++ {
		_, err := b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(uint64(i))})
		require.NoError(t, err)
	}
	require.Equal(t, 3, b.Len())

	_, err := b.Write(&ProofResponse{BatchID: new(big.Int).SetUint64(2)})
	require.NoError(t, err)
	require.Equal(t, 3, b.Len())
}
