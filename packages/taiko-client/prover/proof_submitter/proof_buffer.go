package submitter

import (
	"errors"
	"sync"
	"time"

	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	errBufferOverflow = errors.New("proof buffer overflow")
	errNotEnoughProof = errors.New("not enough proof")
)

// ProofBuffer caches all single proof with a fixed size.
type ProofBuffer struct {
	MaxLength     uint64
	buffer        []*producer.ProofResponse
	lastUpdatedAt time.Time
	isAggregating bool
	mutex         sync.RWMutex
}

// NewProofBuffer creates a new ProofBuffer instance.
func NewProofBuffer(maxLength uint64) *ProofBuffer {
	return &ProofBuffer{
		buffer:        make([]*producer.ProofResponse, 0, maxLength),
		lastUpdatedAt: time.Now(),
		MaxLength:     maxLength,
	}
}

// Write adds new item to the buffer.
func (pb *ProofBuffer) Write(item *producer.ProofResponse) (int, error) {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	if len(pb.buffer)+1 > int(pb.MaxLength) {
		return len(pb.buffer), errBufferOverflow
	}

	pb.buffer = append(pb.buffer, item)
	pb.lastUpdatedAt = time.Now()
	return len(pb.buffer), nil
}

// Read returns the content with given length in the buffer.
func (pb *ProofBuffer) Read(length int) ([]*producer.ProofResponse, error) {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	if length > len(pb.buffer) {
		return nil, errNotEnoughProof
	}

	data := make([]*producer.ProofResponse, length)
	copy(data, pb.buffer[:length])
	return data, nil
}

// ReadAll returns all the content in the buffer.
func (pb *ProofBuffer) ReadAll() ([]*producer.ProofResponse, error) {
	return pb.Read(pb.Len())
}

// Len returns current length of the buffer.
func (pb *ProofBuffer) Len() int {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return len(pb.buffer)
}

// LastUpdatedAt returns the last updated time of the buffer.
func (pb *ProofBuffer) LastUpdatedAt() time.Time {
	return pb.lastUpdatedAt
}

// LastUpdatedAt returns the last updated time of the buffer.
func (pb *ProofBuffer) UpdateLastUpdatedAt() {
	pb.lastUpdatedAt = time.Now()
}

// ClearItems clears items that has given block ids in the buffer.
func (pb *ProofBuffer) ClearItems(blockIDs ...uint64) int {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	clearMap := make(map[uint64]bool)
	for _, blockID := range blockIDs {
		clearMap[blockID] = true
	}

	newBuffer := make([]*producer.ProofResponse, 0, len(pb.buffer))
	clearedCount := 0

	for _, b := range pb.buffer {
		if !clearMap[b.Meta.Ontake().GetBlockID().Uint64()] {
			newBuffer = append(newBuffer, b)
		} else {
			clearedCount++
		}
	}

	pb.buffer = newBuffer
	pb.isAggregating = false
	return clearedCount
}

// MarkAggregating marks the proofs in this buffer are aggregating.
func (pb *ProofBuffer) MarkAggregating() {
	pb.isAggregating = true
}

// IsAggregating returns if the proofs in this buffer are aggregating.
func (pb *ProofBuffer) IsAggregating() bool {
	return pb.isAggregating
}

// Enabled returns if the buffer is enabled.
func (pb *ProofBuffer) Enabled() bool {
	return pb.MaxLength > 1
}
