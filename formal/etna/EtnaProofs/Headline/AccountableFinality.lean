import EtnaStatements
import EtnaProofs.Accountability
import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity
import EtnaModel
import EtnaProofs.RegistryHistory
import EtnaProofs.Consensus
import EtnaProofs.Landing
import EtnaProofs.Forced
import EtnaModel.Encoding

/-! H2, accountable finality (`Etna.Statements.AccountableFinality`). The per-context results
(`Accountability.conflicting_commits_overlap`, the registry's `slash_of_double_sign`) are lifted
to the rules `Deployment.build` derives on a World that a trace reaches from the initialized
World: the built context's domain and generation are the World's own, its signature relation is
the environment's, and `Premises.signatureAgreement` turns a consensus-signed vote into one the
registry's own verifier accepts. -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- Power counted by a filter grows with the filter: if every member that `p` selects is also
selected by `q`, the members `p` selects hold at most the power of those `q` selects. -/
theorem selected_power_le (unit : Nat) (members : List Committee.Entry) {p q : Committee.Entry → Bool}
    (sub : ∀ e ∈ members, p e = true → q e = true) :
    Committee.totalPower unit (members.filter p) ≤ Committee.totalPower unit (members.filter q) := by
  induction members with
  | nil => exact Nat.le_refl _
  | cons e rest ih =>
    have tail := ih (fun x mem => sub x (List.mem_cons_of_mem _ mem))
    have head := sub e List.mem_cons_self
    simp only [Committee.totalPower,List.filter_cons] at tail ⊢
    cases hp : p e <;> cases hq : q e <;> simp_all <;> omega

end Etna.Proofs
