package submitter

import "math/big"

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
