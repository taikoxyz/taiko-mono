package submitter

import (
	"errors"
	"sync"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var ErrCacheNotFound = errors.New("cache not found")

// ProofCache wraps a proof response map with a mutex to allow safe concurrent access.
type ProofCache struct {
	mu    sync.RWMutex
	cache map[uint64]*proofProducer.ProofResponse
}

// NewProofCache creates a new proof cache with the provided initial capacity.
func NewProofCache(initialSize int) *ProofCache {
	return &ProofCache{
		cache: make(map[uint64]*proofProducer.ProofResponse, initialSize),
	}
}

// set caches the proof response by proposal ID.
func (pc *ProofCache) set(proposalID uint64, proof *proofProducer.ProofResponse) {
	if pc == nil {
		return
	}
	pc.mu.Lock()
	defer pc.mu.Unlock()
	pc.cache[proposalID] = proof
}
