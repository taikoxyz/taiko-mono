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

/-- Conflicting valid commits expose a selected member key `k` with a precommit under `k` in
each commit; the two are accepted double-sign evidence for this deployment and generation
(same height/round/kind, different blocks). -/
theorem conflicting_commits_double_sign {c : Consensus.Context} {signature : Consensus.Vote → Prop} {h round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (okA : Consensus.CommitValid c signature h round a votesA) (okB : Consensus.CommitValid c signature h round b votesB)
    (conflict : a ≠ b) :
    ∃ k ∈ (Consensus.activeAt c h).members.map Committee.Entry.key,
      ∃ va ∈ votesA.filter (fun v => v.key == k), ∃ vb ∈ votesB.filter (fun v => v.key == k),
      signature va ∧ signature vb ∧ Staking.doubleSign c.domain c.generation (evidence va) (evidence vb) = true := by
  have overlap := conflicting_commits_overlap okA okB
  obtain ⟨e,mem⟩ : ∃ e, e ∈ (activeAt c h).members.filter
      (fun e => (votesA.map Vote.key).contains e.key && (votesB.map Vote.key).contains e.key) := by
    cases found : (activeAt c h).members.filter
        (fun e => (votesA.map Vote.key).contains e.key && (votesB.map Vote.key).contains e.key) with
    | nil => rw [found] at overlap; simp [Committee.totalPower] at overlap
    | cons e _ => exact ⟨e,List.mem_cons_self⟩
  obtain ⟨member,both⟩ := List.mem_filter.mp mem
  simp only [Bool.and_eq_true,List.contains_iff_mem] at both
  obtain ⟨va,inA,keyA⟩ := List.mem_map.mp both.1
  obtain ⟨vb,inB,keyB⟩ := List.mem_map.mp both.2
  have validA := okA.2.2.2.1 va inA
  have validB := okB.2.2.2.1 vb inB
  refine ⟨e.key,List.mem_map.mpr ⟨e,member,rfl⟩,va,List.mem_filter.mpr ⟨inA,beq_iff_eq.mpr keyA⟩,
    vb,List.mem_filter.mpr ⟨inB,beq_iff_eq.mpr keyB⟩,validA.2.2.2.2.2.2.2,validB.2.2.2.2.2.2.2,?_⟩
  apply decide_eq_true
  simp only [evidence]
  refine ⟨validA.1,validB.1,validA.2.1.trans validB.2.1.symm,Nat.le_of_eq validA.2.1,
    validA.2.2.1.trans validB.2.2.1.symm,validA.2.2.2.1.trans validB.2.2.2.1.symm,
    validA.2.2.2.2.1.trans validB.2.2.2.2.1.symm,Or.inr validA.2.2.2.2.1,?_⟩
  rw [validA.2.2.2.2.2.1,validB.2.2.2.2.2.1]
  exact conflict

end Etna.Design.Accountability
