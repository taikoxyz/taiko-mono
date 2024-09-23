package submitter

import (
	"errors"
	"sync"

	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	errBufferOverflow = errors.New("proof buffer overflow")
	errNotEnoughProof = errors.New("not enough proof")
)

type ProofBuffer struct {
	MaxLength uint64
	buffer    []*producer.ProofWithHeader
	mutex     sync.Mutex
}

func NewProofBuffer(maxLength uint64) *ProofBuffer {
	return &ProofBuffer{
		buffer:    make([]*producer.ProofWithHeader, 0, maxLength),
		MaxLength: maxLength,
	}
}

func (pb *ProofBuffer) Write(item *producer.ProofWithHeader) (int, error) {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	if len(pb.buffer)+1 > int(pb.MaxLength) {
		return len(pb.buffer), errBufferOverflow
	}

	pb.buffer = append(pb.buffer, item)
	return len(pb.buffer), nil
}

func (pb *ProofBuffer) Read(length int) ([]*producer.ProofWithHeader, error) {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	if length > len(pb.buffer) {
		return nil, errNotEnoughProof
	}

	data := make([]*producer.ProofWithHeader, length)
	copy(data, pb.buffer[:length])
	pb.buffer = pb.buffer[length:]
	return data, nil
}

func (pb *ProofBuffer) ReadAll() ([]*producer.ProofWithHeader, error) {
	return pb.Read(len(pb.buffer))
}

func (pb *ProofBuffer) Len() int {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()
	return len(pb.buffer)
}

func (pb *ProofBuffer) Clear() {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()
	pb.buffer = pb.buffer[:0]
}

func (pb *ProofBuffer) ClearItems(items ...*producer.ProofWithHeader) int {
	pb.mutex.Lock()
	defer pb.mutex.Unlock()

	clearMap := make(map[uint64]bool)
	for _, e := range items {
		clearMap[e.Meta.GetBlockID().Uint64()] = true
	}

	newBuffer := make([]*producer.ProofWithHeader, 0, len(pb.buffer))
	clearedCount := 0

	for _, b := range pb.buffer {
		if !clearMap[b.Meta.GetBlockID().Uint64()] {
			newBuffer = append(newBuffer, b)
		} else {
			clearedCount++
		}
	}

	pb.buffer = newBuffer
	return clearedCount
}
