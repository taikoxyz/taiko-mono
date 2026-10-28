import EtnaModel.Consensus
import EtnaProofs.Committee

/-! Proofs about `EtnaModel.Consensus`. -/
namespace Etna.Design.Consensus

/-- Independent unfolded election contract: weakening ElectionValid to True must fail.
This constrains this modeled definition, not its correspondence to every source rule.
Every global name is `_root_`-qualified so a nearer declaration cannot capture it. -/
theorem election_valid_iff (c : _root_.Etna.Design.Consensus.Context)
    (r : _root_.Etna.Design.Committee.Record) :
    _root_.Etna.Design.Consensus.ElectionValid c r ↔
      _root_.Etna.Design.Committee.election c.unit c.minimum r.cutoff c.nMax (c.registry r.cutoff) =
        _root_.Option.some r.members := Iff.rfl

theorem active_before_switch (c : Context) (h : Nat)
    (old : switchHeight c (epoch c h) ≤ c.originHeight) : activeAt c h = initial c := by
  simp [activeAt, Nat.not_lt.mpr old]

theorem active_at_handover (c : Context) (t : Nat) (positive : 0 < c.epochLen)
    (occurred : c.originHeight < switchHeight c t) : activeAt c (t*c.epochLen+1) = normal c t := by
  have ep : epoch c (t*c.epochLen+1) = t := by
    simp [epoch, positive]
  simp [activeAt, ep, occurred]

private theorem before_epoch {t l : Nat} (tp : 0 < t) (lp : 3 ≤ l) :
    (t*l-2)/l = t-1 ∧ (t*l-1)/l = t-1 := by
  cases t with
  | zero => omega
  | succ t =>
    rw [Nat.succ_mul]
    have a : t*l+l-2 = t*l+(l-2) := by omega
    have b : t*l+l-1 = t*l+(l-1) := by omega
    rw [a,b]
    simp [Nat.add_div, show 0 < l by omega,
      Nat.div_eq_of_lt (show l-2 < l by omega), Nat.div_eq_of_lt (show l-1 < l by omega)] <;> omega

theorem switch_keeps_old_authority (c : Context) (t : Nat) (tp : 0 < t) (lp : 3 ≤ c.epochLen) :
    activeAt c (t*c.epochLen-1) = activeAt c (t*c.epochLen) := by
  have epochs := before_epoch tp lp
  have sub : t*c.epochLen-1-1 = t*c.epochLen-2 := by omega
  simp only [activeAt, epoch, sub, epochs.1, epochs.2]

theorem recovery_initial_until_switch (c : Context) (h : Nat) (recovery : c.generation ≠ 0)
    (notOccurred : switchHeight c (epoch c h) ≤ c.originHeight) :
    (activeAt c h).cutoff = c.originBlock := by
  rw [active_before_switch c h notOccurred]
  simp [initial,selected,recovery]

theorem commit_authorizes_actual_committee {c : Context} {signature : Vote → Prop}
    {h round block : Nat} {votes : List Vote} (ok : CommitValid c signature h round block votes) :
    ElectionValid c (activeAt c h) ∧ (votes.map Vote.key).Nodup ∧
    ∀ v ∈ votes, v.domain = c.domain ∧ v.generation = c.generation ∧ v.height = h ∧
      v.round = round ∧ v.kind = 2 ∧ v.blockId = block ∧
      v.key ∈ ((activeAt c h).members.map Committee.Entry.key) ∧ signature v :=
  ⟨ok.2.1,ok.2.2.1,ok.2.2.2.1⟩

theorem commit_strict_quorum {c : Context} {signature : Vote → Prop}
    {h round block : Nat} {votes : List Vote} (ok : CommitValid c signature h round block votes) :
    2*Committee.totalPower c.unit (activeAt c h).members <
      3*signedPower c (activeAt c h).members (votes.map Vote.key) := ok.2.2.2.2

theorem signed_power_bounded (c : Context) (members : List Committee.Entry) (keys : List Hash) :
    signedPower c members keys ≤ Committee.totalPower c.unit members := by
  induction members with
  | nil => simp [signedPower,Committee.totalPower]
  | cons a rest ih =>
    simp only [signedPower,Committee.totalPower,List.filter_cons,List.map_cons,List.sum_cons] at *
    split <;> simp_all <;> omega

theorem foreign_generation_rejected {c : Context} {signature : Vote → Prop}
    {h round block : Nat} {votes : List Vote} {v : Vote} (member : v ∈ votes)
    (foreign : v.generation ≠ c.generation) : ¬ CommitValid c signature h round block votes := by
  intro ok
  exact foreign ((ok.2.2.2.1 v member).2.1)

/-- Monotone authenticated anchor history and the genesis/recovery cutoff rule imply
monotone active snapshots, including the initial-to-normal handover. -/
theorem active_cutoff_monotone (c : Context)
    (genesis : c.genesisCutoff ≤ c.originBlock)
    (anchors : ∀ a b, a ≤ b → c.anchorAt a ≤ c.anchorAt b)
    {a b : Nat} (order : a ≤ b) : (activeAt c a).cutoff ≤ (activeAt c b).cutoff := by
  have ep : epoch c a ≤ epoch c b := Nat.div_le_div_right (by omega)
  have prod : epoch c a*c.epochLen ≤ epoch c b*c.epochLen := Nat.mul_le_mul_right c.epochLen ep
  have sw : switchHeight c (epoch c a) ≤ switchHeight c (epoch c b) := by
    unfold switchHeight
    omega
  have anc := anchors (epoch c a*c.epochLen-2) (epoch c b*c.epochLen-2) (by omega)
  unfold activeAt
  dsimp only
  split <;> split
  · simp only [normal,selected]
    omega
  · omega
  · have first : (initial c).cutoff ≤ c.originBlock := by
      simp only [initial,selected]
      split <;> omega
    simp only [normal,selected]
    omega
  · exact Nat.le_refl _

end Etna.Design.Consensus
