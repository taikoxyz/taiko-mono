package submitter

import (
	"context"
	"math/big"
	"sync"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// clearBackoffMaxRetries bounds the best-effort retries of POST /v3/prover/clear
// when entering SP1 fallback mode.
const clearBackoffMaxRetries uint64 = 5

// sp1Fallback tracks whether the submitter is draining the RISC0 backlog via SP1.
// It is shared across the concurrent RequestProof goroutines, so all access is
// guarded by mu.
type sp1Fallback struct {
	mu    sync.Mutex
	inSP1 bool
}

// markSP1Fallback latches into SP1 fallback mode. It returns true only for the
// first caller that performs the transition; that caller is responsible for
// clearing the RISC0 backlog exactly once.
func (s *ProofSubmitter) markSP1Fallback() bool {
	s.sp1Fallback.mu.Lock()
	defer s.sp1Fallback.mu.Unlock()
	if s.sp1Fallback.inSP1 {
		return false
	}
	s.sp1Fallback.inSP1 = true
	metrics.ProverZKBacklogModeGauge.Set(1)
	return true
}

// inSP1Fallback reports whether the submitter is currently draining via SP1.
func (s *ProofSubmitter) inSP1Fallback() bool {
	s.sp1Fallback.mu.Lock()
	defer s.sp1Fallback.mu.Unlock()
	return s.sp1Fallback.inSP1
}

// resumeRisc0 unlatches SP1 fallback mode so subsequent proposals use RISC0 again.
// It returns true only for the caller that performed the transition.
func (s *ProofSubmitter) resumeRisc0() bool {
	s.sp1Fallback.mu.Lock()
	defer s.sp1Fallback.mu.Unlock()
	if !s.sp1Fallback.inSP1 {
		return false
	}
	s.sp1Fallback.inSP1 = false
	metrics.ProverZKBacklogModeGauge.Set(0)
	return true
}

// decideZKProofType applies the RISC0 backlog drain/resume state machine and
// reports whether this proposal should be proven via RISC0 or SP1. It has side
// effects: it latches into SP1 fallback mode (and fires a one-off backlog clear)
// on the first distance breach, and unlatches when the backlog is drained.
func (s *ProofSubmitter) decideZKProofType(
	ctx context.Context,
	proposalID *big.Int,
	lastFinalizedProposalID *big.Int,
) proofProducer.ProofType {
	if s.forceSP1Proof {
		return proofProducer.ProofTypeZKSP1
	}

	// Machine inactive: no positive distance configured, or no control-plane client.
	// Preserve stateless behavior: nil = use RISC0, 0 = always use SP1,
	// N = RISC0 within N proposals. When risc0Backlog is nil this also guarantees
	// the machine paths below never dereference it (canResumeRisc0/fireClearAsync).
	if s.maxRisc0ProofProposalDistance == nil ||
		s.maxRisc0ProofProposalDistance.Sign() <= 0 ||
		s.risc0Backlog == nil {
		if s.shouldUseRisc0Proof(proposalID, lastFinalizedProposalID) {
			return proofProducer.ProofTypeZKR0
		}
		return proofProducer.ProofTypeZKSP1
	}

	if s.inSP1Fallback() {
		if s.canResumeRisc0(ctx, proposalID, lastFinalizedProposalID) {
			if s.resumeRisc0() {
				log.Info(
					"RISC0 backlog drained, resuming RISC0 proofs",
					"proposalID", proposalID,
					"lastFinalizedProposalID", lastFinalizedProposalID,
				)
			}
			return proofProducer.ProofTypeZKR0
		}
		return proofProducer.ProofTypeZKSP1
	}

	if !s.shouldUseRisc0Proof(proposalID, lastFinalizedProposalID) {
		if s.markSP1Fallback() {
			log.Warn(
				"RISC0 proof backlog detected, clearing RISC0 backlog and falling back to SP1",
				"proposalID", proposalID,
				"lastFinalizedProposalID", lastFinalizedProposalID,
				"maxRisc0ProofProposalDistance", s.maxRisc0ProofProposalDistance,
			)
			s.clearRisc0ProofBuffersAndResend()
			s.fireClearAsync()
		}
		return proofProducer.ProofTypeZKSP1
	}
	return proofProducer.ProofTypeZKR0
}

// canResumeRisc0 reports whether SP1 fallback mode can switch back to RISC0. It checks
// the cheap local "backlog drained" condition first and only queries the RISC0
// backend status when that holds. A status error (e.g. the endpoint is absent)
// degrades to resuming on the backlog-drained condition alone.
func (s *ProofSubmitter) canResumeRisc0(
	ctx context.Context,
	proposalID *big.Int,
	lastFinalizedProposalID *big.Int,
) bool {
	// (A) backlog drained: proposalID <= lastFinalizedProposalID + 1.
	if proposalID.Cmp(new(big.Int).Add(lastFinalizedProposalID, common.Big1)) > 0 {
		return false
	}
	// (B) RISC0 backend idle.
	clean, err := s.risc0Backlog.StatusClean(ctx)
	if err != nil {
		log.Warn(
			"RISC0 prover status unavailable, resuming RISC0 on backlog-drained condition alone",
			"proposalID", proposalID,
			"error", err,
		)
		return true
	}
	return clean
}

// fireClearAsync clears the RISC0 backlog in the background with bounded retries.
// It is best-effort: clearing only accelerates the drain, so a final failure is
// logged and otherwise ignored. It uses the submitter's long-lived context
// (s.ctx), so the goroutine outlives the triggering proposal's RequestProof call.
func (s *ProofSubmitter) fireClearAsync() {
	// Defensive: decideZKProofType already guards against a nil risc0Backlog.
	if s.risc0Backlog == nil {
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
		if err := backoff.Retry(func() error { return s.risc0Backlog.ClearBacklog(s.ctx) }, bo); err != nil {
			log.Warn("Failed to clear RISC0 backlog after retries", "error", err)
			return
		}
		log.Info("Cleared RISC0 backlog after entering SP1 fallback mode")
	}()
}

// risc0ProofTypes are the RISC0 proof types whose local buffers and caches are
// flushed when entering SP1 fallback mode.
var risc0ProofTypes = []proofProducer.ProofType{
	proofProducer.ProofTypeZKR0,
}

// clearRisc0ProofBuffersAndResend discards any buffered or cached RISC0 proofs
// and re-enqueues their proposals so they are re-proven via SP1 while draining.
// This prevents a partially-filled RISC0 proof batch from stranding once new
// RISC0 requests stop.
func (s *ProofSubmitter) clearRisc0ProofBuffersAndResend() {
	for _, proofType := range risc0ProofTypes {
		s.clearProofBufferAndResend(proofType)
	}
}

// clearProofBufferAndResend flushes the buffer and cache for the given proof type
// and resends each cleared proposal to the submission channel.
func (s *ProofSubmitter) clearProofBufferAndResend(proofType proofProducer.ProofType) {
	proofBuffer, ok := s.proofBuffers[proofType]
	if !ok {
		return
	}
	cacheMap, ok := s.proofCacheMaps[proofType]
	if !ok {
		return
	}

	buffered, err := proofBuffer.ReadAll()
	if err != nil {
		log.Warn("Failed to read RISC0 proof buffer for resend", "proofType", proofType, "error", err)
		return
	}

	resend := make([]*proofProducer.ProofResponse, 0, len(buffered)+cacheMap.Count())
	batchIDs := make([]uint64, 0, len(buffered))
	for _, proof := range buffered {
		if proof == nil || proof.BatchID == nil {
			continue
		}
		resend = append(resend, proof)
		batchIDs = append(batchIDs, proof.BatchID.Uint64())
	}
	proofBuffer.ClearItems(batchIDs...)

	for item := range cacheMap.IterBuffered() {
		if item.Val != nil {
			resend = append(resend, item.Val)
		}
		cacheMap.Remove(item.Key)
	}

	for _, proof := range resend {
		if proof.Meta == nil {
			continue
		}
		s.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: proof.Meta}
	}
	if len(resend) > 0 {
		log.Info(
			"Cleared RISC0 proof buffer and resent proposals for SP1 fallback",
			"proofType", proofType,
			"count", len(resend),
		)
	}
}
