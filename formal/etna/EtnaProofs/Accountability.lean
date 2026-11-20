import EtnaModel.Accountability
import EtnaProofs.Consensus
import EtnaProofs.Staking

/-! Proofs about `EtnaModel.Accountability`. -/
namespace Etna.Design.Accountability
open Consensus

/-- Power counted by two filters is at most the total plus the power counted by both. -/
theorem overlap_power (unit : Nat) (members : List Committee.Entry) (p q : Committee.Entry → Bool) :
    Committee.totalPower unit (members.filter p) + Committee.totalPower unit (members.filter q) ≤
      Committee.totalPower unit members + Committee.totalPower unit (members.filter (fun e => p e && q e)) := by
  induction members with
  | nil => simp [Committee.totalPower]
  | cons e rest ih =>
    simp only [Committee.totalPower,List.filter_cons,List.map_cons,List.sum_cons] at *
    cases hp : p e <;> cases hq : q e <;> simp_all <;> omega

/-- Strict >2/3 quorum intersection: the selected signers of two valid commits at the same
height and round hold more than one third of the active committee's voting power. -/
theorem conflicting_commits_overlap {c : Consensus.Context} {signature : Consensus.Vote → Prop} {h round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (okA : Consensus.CommitValid c signature h round a votesA) (okB : Consensus.CommitValid c signature h round b votesB) :
    Committee.totalPower c.unit (Consensus.activeAt c h).members <
      3*Committee.totalPower c.unit ((Consensus.activeAt c h).members.filter
        (fun e => (votesA.map Consensus.Vote.key).contains e.key && (votesB.map Consensus.Vote.key).contains e.key)) := by
  have quorumA := okA.2.2.2.2
  have quorumB := okB.2.2.2.2
  have overlap := overlap_power c.unit (activeAt c h).members
    (fun e => (votesA.map Vote.key).contains e.key) (fun e => (votesB.map Vote.key).contains e.key)
  unfold signedPower at quorumA quorumB
  omega

end Etna.Design.Accountability
