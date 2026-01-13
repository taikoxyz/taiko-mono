package producer

import (
	"errors"
	"sync"
	"time"
)

var (
	ErrBufferOverflow = errors.New("proof buffer overflow")
	ErrNotEnoughProof = errors.New("not enough proof")
	ErrNilBatchID     = errors.New("batch ID cannot be nil")
)

// ProofBuffer caches all single proof with a fixed size.
type ProofBuffer struct {
	MaxLength     uint64
	buffer        []*ProofResponse
	firstItemAt   time.Time
	isAggregating bool
	mutex         sync.RWMutex
	lastInsertID  uint64
}

// NewProofBuffer creates a new ProofBuffer instance.
func NewProofBuffer(maxLength uint64) *ProofBuffer {
	return &ProofBuffer{
		buffer:      make([]*ProofResponse, 0, maxLength),
		MaxLength:   maxLength,
	}
}

// Write adds new item to the buffer.
func (pb *ProofBuffer) Write(item *ProofResponse) (int, error) {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	// Validate that BatchID is not nil
	if item.BatchID == nil {
		return len(pb.buffer), ErrNilBatchID
	}

	// Check for duplicate BatchID (idempotency check)
	// If duplicate found, return success without adding the item
	for _, existingItem := range pb.buffer {
		if existingItem.BatchID.Cmp(item.BatchID) == 0 {
			return len(pb.buffer), nil
		}
	}

	if len(pb.buffer)+1 > int(pb.MaxLength) {
		return len(pb.buffer), ErrBufferOverflow
	}

	if len(pb.buffer) == 0 {
		pb.firstItemAt = time.Now()
	}
	pb.buffer = append(pb.buffer, item)
	pb.lastInsertID = item.BatchID.Uint64()
	return len(pb.buffer), nil
}

// Read returns the content with given length in the buffer.
func (pb *ProofBuffer) Read(length int) ([]*ProofResponse, error) {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	if length > len(pb.buffer) {
		return nil, ErrNotEnoughProof
	}

	data := make([]*ProofResponse, length)
	copy(data, pb.buffer[:length])
	return data, nil
}

// ReadAll returns all the content in the buffer.
func (pb *ProofBuffer) ReadAll() ([]*ProofResponse, error) {
	return pb.Read(pb.Len())
}

// Len returns current length of the buffer.
func (pb *ProofBuffer) Len() int {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return len(pb.buffer)
}

// AvailableCapacity returns current available capacity of the buffer.
func (pb *ProofBuffer) AvailableCapacity() uint64 {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return pb.MaxLength - uint64(len(pb.buffer))
}

// FirstItemAt returns the first item updated time of the buffer, only makes sense when Len() is greater than 0.
func (pb *ProofBuffer) FirstItemAt() time.Time {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return pb.firstItemAt
}

// LastInsertID returns the last item insert batch ID.
func (pb *ProofBuffer) LastInsertID() uint64 {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return pb.lastInsertID
}

// ClearItems clears items that has given block ids in the buffer.
func (pb *ProofBuffer) ClearItems(blockIDs ...uint64) int {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	clearMap := make(map[uint64]bool)
	for _, blockID := range blockIDs {
		clearMap[blockID] = true
	}

	newBuffer := make([]*ProofResponse, 0, len(pb.buffer))
	clearedCount := 0

	for _, b := range pb.buffer {
		if !clearMap[b.BatchID.Uint64()] {
			newBuffer = append(newBuffer, b)
		} else {
			clearedCount++
		}
	}

	pb.buffer = newBuffer
	if len(pb.buffer) == 0 {
		pb.firstItemAt = time.Time{}
		pb.lastInsertID = 0
	} else {
		pb.lastInsertID = pb.buffer[len(pb.buffer)-1].BatchID.Uint64()
	}
	pb.isAggregating = false
	return clearedCount
}

// MarkAggregatingIfNot marks the proofs in this buffer are aggregating if not.
func (pb *ProofBuffer) MarkAggregatingIfNot() bool {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	if pb.isAggregating {
		return false
	}
	pb.isAggregating = true
	return true
}

// IsAggregating returns if the proofs in this buffer are aggregating.
func (pb *ProofBuffer) IsAggregating() bool {
	pb.mutex.RLock()
	defer pb.mutex.RUnlock()
	return pb.isAggregating
}
