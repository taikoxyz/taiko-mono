package submitter

import (
	"context"
	"math/big"
	"sync"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

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
// It returns true only for the caller that performed the transition.
func (s *ProofSubmitter) resumeZK() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	if !s.zkFallback.inSGX {
		return false
	}
	s.zkFallback.inSGX = false
	metrics.ProverZKBacklogModeGauge.Set(0)
	return true
}

// decideUseZK applies the ZK backlog drain/resume state machine and reports
// whether this proposal should be proven via ZK. It has side effects: it latches
// into SGX-draining mode (and fires a one-off backlog clear) on the first
// distance breach, and unlatches when the backlog is drained.
func (s *ProofSubmitter) decideUseZK(
	ctx context.Context,
	proposalID *big.Int,
	lastFinalizedProposalID *big.Int,
) bool {
	// Machine inactive: no positive distance configured, or no control-plane client.
	// Preserve the stateless behavior from #21782 (nil = use ZK, 0 = skip ZK,
	// N = within N proposals). When zkBacklog is nil this also guarantees the machine
	// paths below never dereference it (canResumeZK/fireClearAsync).
	if s.maxZKProofProposalDistance == nil ||
		s.maxZKProofProposalDistance.Sign() <= 0 ||
		s.zkBacklog == nil {
		return s.shouldUseZKProof(proposalID, lastFinalizedProposalID)
	}

	if s.inSGXFallback() {
		if s.canResumeZK(ctx, proposalID, lastFinalizedProposalID) {
			if s.resumeZK() {
				log.Info(
					"ZK backlog drained, resuming ZK proofs",
					"proposalID", proposalID,
					"lastFinalizedProposalID", lastFinalizedProposalID,
				)
			}
			return true
		}
		return false
	}

	if !s.shouldUseZKProof(proposalID, lastFinalizedProposalID) {
		if s.markSGXFallback() {
			log.Warn(
				"ZK proof backlog detected, clearing ZK backlog and draining via SGX",
				"proposalID", proposalID,
				"lastFinalizedProposalID", lastFinalizedProposalID,
				"maxZKProofProposalDistance", s.maxZKProofProposalDistance,
			)
			s.fireClearAsync()
		}
		return false
	}
	return true
}

// canResumeZK reports whether SGX-draining mode can switch back to ZK. It checks
// the cheap local "backlog drained" condition first and only queries the ZK
// backend status when that holds. A status error (e.g. the endpoint is absent)
// degrades to resuming on the backlog-drained condition alone.
func (s *ProofSubmitter) canResumeZK(
	ctx context.Context,
	proposalID *big.Int,
	lastFinalizedProposalID *big.Int,
) bool {
	// (A) backlog drained: proposalID <= lastFinalizedProposalID + 1.
	if proposalID.Cmp(new(big.Int).Add(lastFinalizedProposalID, common.Big1)) > 0 {
		return false
	}
	// (B) ZK backend idle.
	clean, err := s.zkBacklog.StatusClean(ctx)
	if err != nil {
		log.Warn(
			"ZK prover status unavailable, resuming ZK on backlog-drained condition alone",
			"proposalID", proposalID,
			"error", err,
		)
		return true
	}
	return clean
}

// fireClearAsync clears the ZK backlog in the background with bounded retries.
// It is best-effort: clearing only accelerates the drain, so a final failure is
// logged and otherwise ignored. It uses the submitter's long-lived context
// (s.ctx), so the goroutine outlives the triggering proposal's RequestProof call.
func (s *ProofSubmitter) fireClearAsync() {
	// Defensive: decideUseZK already guards against a nil zkBacklog.
	if s.zkBacklog == nil {
		return
	}
	metrics.ProverZKBacklogClearCounter.Add(1)
	go func() {
		bo := backoff.WithContext(
			backoff.WithMaxRetries(
				backoff.NewConstantBackOff(s.proofPollingInterval),
				clearBackoffMaxRetries,
			),
			s.ctx,
		)
		if err := backoff.Retry(func() error { return s.zkBacklog.ClearBacklog(s.ctx) }, bo); err != nil {
			log.Warn("Failed to clear ZK backlog after retries", "error", err)
			return
		}
		log.Info("Cleared ZK backlog after entering SGX-draining mode")
	}()
}
