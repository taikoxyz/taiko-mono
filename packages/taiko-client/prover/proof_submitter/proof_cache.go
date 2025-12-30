package submitter

import (
	"errors"
	"sync"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var ErrCacheNotFound = errors.New("cache not found")

// ProofCache stores out-of-order proofs temporarily until they can be written
// to the ProofBuffer sequentially. This is necessary because proofs may arrive
// out of order (e.g., proof 5 before proof 3), but the buffer requires sequential
// insertion starting from lastFinalizedProposalID + 1.
//
// Thread-safety: All operations are protected by a RWMutex to allow concurrent
// reads and exclusive writes.
//
// Lifecycle:
// - Proofs are cached when they arrive out of order (not sequential with buffer)
// - Cached proofs are flushed to buffer when the gap is filled
// - Finalized proofs are cleaned up periodically by the background monitor
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
