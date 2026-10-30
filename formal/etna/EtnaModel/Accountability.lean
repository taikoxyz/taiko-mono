import EtnaModel.Consensus
import EtnaModel.Staking

/-! Accountable safety of decoded commits. Two valid commits at one height and round for
different blocks are only possible if selected signers holding more than one third of the
active voting power signed both, and any such pair of precommits is the registry's
double-sign evidence. Signature soundness and evidence delivery to L1 remain external. -/
namespace Etna.Design.Accountability
open Consensus

/-- The registry's evidence view of a consensus vote: everything except the signer key,
which the registry takes from the bond instead. -/
def evidence (v : Consensus.Vote) : Staking.Vote := ⟨v.domain,v.generation,v.height,v.round,v.kind,v.blockId⟩

end Etna.Design.Accountability
