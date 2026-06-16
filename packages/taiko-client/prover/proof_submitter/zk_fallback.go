package submitter

import (
	"sync"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// clearBackoffMaxRetries bounds the best-effort retries of POST /v3/prover/clear
// when entering SGX-draining mode.
const clearBackoffMaxRetries uint64 = 5

// zkFallback tracks whether the submitter is draining the ZK backlog via SGX.
// It is shared across the concurrent RequestProof goroutines, so all access is
// guarded by mu.
type zkFallback struct {
	mu    sync.Mutex
	inSGX bool
}

// markSGXFallback latches into SGX-draining mode. It returns true only for the
// first caller that performs the transition; that caller is responsible for
// clearing the ZK backlog exactly once.
func (s *ProofSubmitter) markSGXFallback() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	if s.zkFallback.inSGX {
		return false
	}
	s.zkFallback.inSGX = true
	metrics.ProverZKBacklogModeGauge.Set(1)
	return true
}

// inSGXFallback reports whether the submitter is currently draining via SGX.
func (s *ProofSubmitter) inSGXFallback() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	return s.zkFallback.inSGX
}

// resumeZK unlatches SGX-draining mode so subsequent proposals use ZK again.
func (s *ProofSubmitter) resumeZK() {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	if !s.zkFallback.inSGX {
		return
	}
	s.zkFallback.inSGX = false
	metrics.ProverZKBacklogModeGauge.Set(0)
}
