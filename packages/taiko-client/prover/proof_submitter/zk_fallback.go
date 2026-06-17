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
// when entering fallback mode.
const clearBackoffMaxRetries uint64 = 5

// zkFallback tracks whether the submitter is draining the ZK backlog via the
// fallback producer (SGX or SP1). It is shared across the concurrent RequestProof
// goroutines, so all access is guarded by mu.
type zkFallback struct {
	mu      sync.Mutex
	latched bool
}

// markFallback latches into fallback-draining mode. It returns true only for the
// first caller that performs the transition; that caller is responsible for
// clearing the ZK backlog exactly once.
func (s *ProofSubmitter) markFallback() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	if s.zkFallback.latched {
		return false
	}
	s.zkFallback.latched = true
	metrics.ProverZKBacklogModeGauge.Set(1)
	return true
}

// inFallback reports whether the submitter is currently draining via the fallback
// producer.
func (s *ProofSubmitter) inFallback() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	return s.zkFallback.latched
}

// resumeZK unlatches fallback-draining mode so subsequent proposals use ZK again.
// It returns true only for the caller that performed the transition.
func (s *ProofSubmitter) resumeZK() bool {
	s.zkFallback.mu.Lock()
	defer s.zkFallback.mu.Unlock()
	if !s.zkFallback.latched {
		return false
	}
	s.zkFallback.latched = false
	metrics.ProverZKBacklogModeGauge.Set(0)
	return true
}

// decideUseZK applies the ZK backlog drain/resume state machine and reports
// whether this proposal should be proven via ZK. It has side effects: it latches
// into fallback mode (and fires a one-off backlog clear) on the first
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

	if s.inFallback() {
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
		if s.markFallback() {
			log.Warn(
				"ZK proof backlog detected, clearing ZK backlog and draining via fallback",
				"proposalID", proposalID,
				"lastFinalizedProposalID", lastFinalizedProposalID,
				"maxZKProofProposalDistance", s.maxZKProofProposalDistance,
			)
			s.clearZKProofBuffersAndResend()
			s.fireClearAsync()
		}
		return false
	}
	return true
}

// canResumeZK reports whether fallback-draining mode can switch back to ZK. It
// checks the cheap local "backlog drained" condition first and only queries the ZK
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
	// (B) ZK backend risc0 idle.
	idle, err := s.zkBacklog.Risc0Idle(ctx)
	if err != nil {
		log.Warn(
			"ZK prover status unavailable, resuming ZK on backlog-drained condition alone",
			"proposalID", proposalID,
			"error", err,
		)
		return true
	}
	return idle
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
		log.Info("Cleared ZK backlog after entering fallback mode")
	}()
}

// zkProofTypes are the ZK proof types whose local buffers and caches are flushed
// when entering SGX-draining mode.
var zkProofTypes = []proofProducer.ProofType{
	proofProducer.ProofTypeZKR0,
	proofProducer.ProofTypeZKSP1,
}

// clearZKProofBuffersAndResend discards any buffered or cached ZK proofs and
// re-enqueues their proposals so they are re-proven via SGX while draining. This
// prevents a partially-filled ZK proof batch from stranding once new ZK requests
// stop.
func (s *ProofSubmitter) clearZKProofBuffersAndResend() {
	for _, proofType := range zkProofTypes {
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
		log.Warn("Failed to read ZK proof buffer for resend", "proofType", proofType, "error", err)
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
			"Cleared ZK proof buffer and resent proposals for SGX draining",
			"proofType", proofType,
			"count", len(resend),
		)
	}
}
