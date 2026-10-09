package submitter

import (
	"math/big"

	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// SP1ProofShareCycle is the number of consecutive proposals --prover.sp1ProofPercentage
// applies to: the first sp1ProofPercentage proposals of every cycle are proven with SP1,
// and the rest go through the RISC0-to-SP1 fallback flow (see risc0_sp1_fallback.go).
const SP1ProofShareCycle uint64 = 100

// inSP1ProofShare reports whether the proposal falls in the fixed SP1 share of its cycle.
// It depends only on the proposal ID, so the choice is stable across RequestProof
// re-polls and prover restarts.
func (s *ProofSubmitter) inSP1ProofShare(proposalID *big.Int) bool {
	if s.sp1ProofPercentage == 0 || proposalID == nil {
		return false
	}
	return proposalID.Uint64()%SP1ProofShareCycle < s.sp1ProofPercentage
}

// endsProofShareRun reports whether proposalID is the last proposal of a fixed run of
// proofType: the SP1 share ends at sp1ProofPercentage - 1 and the RISC0 share at the end
// of the cycle. It only applies while a cycle mixes both proof types and no other mode
// overrides the RISC0/SP1 selection.
func (s *ProofSubmitter) endsProofShareRun(proposalID uint64, proofType proofProducer.ProofType) bool {
	if s.forceSP1Proof || s.forceSGXProof || s.zkOnlyProofs ||
		s.sp1ProofPercentage == 0 || s.sp1ProofPercentage >= SP1ProofShareCycle {
		return false
	}
	offset := proposalID % SP1ProofShareCycle
	if proofType == proofProducer.ProofTypeZKSP1 {
		return offset == s.sp1ProofPercentage-1
	}
	if proofType == proofProducer.ProofTypeZKR0 {
		return offset == SP1ProofShareCycle-1
	}
	return false
}
