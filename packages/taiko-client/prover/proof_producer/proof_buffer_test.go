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
	b.ResetAggregating()
	require.False(t, b.IsAggregating())
}
