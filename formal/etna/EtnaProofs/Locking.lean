import EtnaModel.Locking
import EtnaModel.Consensus
import EtnaProofs.Headline.AccountableFinality
import EtnaModel.RegistryHistory
import EtnaProofs.RegistryHistory
import EtnaProofs.Consensus

/-! Cross-round safety derived from per-key prevote/PoLC/lock transitions. No
CrossRoundAccountable premise and no cross-round automatic slashing conclusion. -/
namespace Etna.Design.Locking

private theorem honest_intersection {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    (minority : Minority unit members honest) {a b : List Hash}
    (qa : Quorum unit members a) (qb : Quorum unit members b) :
    ∃ m ∈ members, honest m.key = true ∧ m.key ∈ a ∧ m.key ∈ b := by
  apply Classical.byContradiction
  intro absent
  have sub : ∀ m ∈ members, (a.contains m.key && b.contains m.key) = true → (!honest m.key) = true := by
    intro m mem both
    simp only [Bool.and_eq_true,List.contains_iff_mem] at both
    cases hm : honest m.key with
    | false => rfl
    | true => exact False.elim (absent ⟨m,mem,hm,both⟩)
  have covered := Etna.Proofs.selected_power_le unit members sub
  have overlap := Accountability.overlap_power unit members (fun m => a.contains m.key) (fun m => b.contains m.key)
  unfold Minority at minority
  unfold Quorum power at qa qb
  omega

/-- Weighted same-round prevote-certificate uniqueness, including nil. -/
theorem polc_unique {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    {mode : Bool} {e : Execution} (rules : HonestRules unit members honest mode e)
    (minority : Minority unit members honest) {r : Nat} {a b : Value}
    (ca : PoLC unit members e r a) (cb : PoLC unit members e r b) : a = b := by
  obtain ⟨ka,qa,pa⟩ := ca
  obtain ⟨kb,qb,pb⟩ := cb
  obtain ⟨m,_,hm,ma,mb⟩ := honest_intersection minority qa qb
  exact Option.some.inj ((rules.prevote m.key hm r a (pa _ ma)).symm.trans
    (rules.prevote m.key hm r b (pb _ mb)))

/-- A nonnil commit contains an honest precommit that acquired its current-round lock. -/
theorem commit_has_polc {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    {mode : Bool} {e : Execution} (rules : HonestRules unit members honest mode e)
    (minority : Minority unit members honest) {r b : Nat} (commit : Commit unit members e r b) :
    PoLC unit members e r (some b) := by
  obtain ⟨keys,quorum,signed⟩ := commit
  obtain ⟨m,_,hm,mem,_⟩ := honest_intersection minority quorum quorum
  have step := (rules.steps m.key hm r).2.2
  rw [rules.precommit m.key hm r (some b) (signed _ mem)] at step
  exact step.1

private theorem compatible_block {mode : Bool} {a b : Hash} (safe : Compatible mode a (some b)) : b = a := by
  rcases safe with equal | ⟨_,impossible⟩
  · exact Option.some.inj equal
  · contradiction

private theorem cannot_unlock {mode : Bool} {cert : Nat → Value → Prop} {r start lr a : Nat}
    {justification : Option (Nat × Value)} (lower : start ≤ lr)
    (safe : ∀ q v, start ≤ q → q < r → cert q v → Compatible mode a v)
    (allowed : UnlockAllowed mode cert r (some (lr,a)) justification) : justification = none := by
  cases justification with
  | none => rfl
  | some j =>
    obtain ⟨q,v⟩ := j
    obtain ⟨l,b,same,floor,prior,polc,different,relevant⟩ := allowed
    have pair := Option.some.inj same
    cases pair
    have good := safe q v (Nat.le_trans lower floor) prior polc
    rcases good with equal | ⟨paper,nil⟩
    · exact False.elim (different equal)
    · rcases relevant with markdown | nonnil
      · rw [paper] at markdown; contradiction
      · exact False.elim (nonnil nil)

private theorem step_keeps_lock {mode : Bool} {cert : Nat → Value → Prop} {r start lr a : Nat}
    {action : RoundAction} {after : Lock} (lower : start ≤ lr) (now : start ≤ r)
    (safe : ∀ q v, start ≤ q → q ≤ r → cert q v → Compatible mode a v)
    (step : RoundStep mode cert r (some (lr,a)) action after) :
    ∃ next, start ≤ next ∧ after = some (next,a) := by
  have noUnlock := cannot_unlock lower (fun q v lo hi => safe q v lo (Nat.le_of_lt hi)) step.1
  have held : afterPrevote (some (lr,a)) action = some (lr,a) := by simp [afterPrevote,noUnlock]
  have pc := step.2.2
  cases hpc : action.precommit with
  | none => rw [hpc,held] at pc; exact ⟨lr,lower,pc⟩
  | some v =>
    cases v with
    | some b =>
      rw [hpc] at pc
      have same := compatible_block (safe r (some b) now (Nat.le_refl _) pc.1)
      exact ⟨r,now,same ▸ pc.2⟩
    | none =>
      rw [hpc] at pc
      by_cases clear : (mode && action.nilCertificate) = true
      · have parts := Bool.and_eq_true_iff.mp clear
        have good := safe r none now (Nat.le_refl _) (pc.1 parts.2)
        rcases good with impossible | ⟨paper,_⟩
        · contradiction
        · rw [parts.1] at paper; contradiction
      · exact ⟨lr,lower,by simpa [clear,held] using pc.2⟩

private theorem later_prevote {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    {mode : Bool} {e : Execution} (rules : HonestRules unit members honest mode e)
    {k start r a : Nat} {v : Value} (hk : honest k = true)
    (pc : e.precommits k start (some a)) (pv : e.prevotes k r v) (later : start < r)
    (safe : ∀ q w, start ≤ q → q < r → PoLC unit members e q w → Compatible mode a w) :
    Compatible mode a v := by
  have locked : e.locks k (start+1) = some (start,a) := by
    have step := (rules.steps k hk start).2.2
    rw [rules.precommit k hk start (some a) pc] at step
    exact step.2
  have persists : ∀ t, start+1 ≤ t → t ≤ r → ∃ lr, start ≤ lr ∧ e.locks k t = some (lr,a) := by
    intro t
    induction t with
    | zero => intro lo hi; omega
    | succ t ih =>
      intro lo hi
      by_cases first : t = start
      · subst t; exact ⟨start,Nat.le_refl _,locked⟩
      · obtain ⟨lr,lower,held⟩ := ih (by omega) (by omega)
        have step := rules.steps k hk t
        rw [held] at step
        exact step_keeps_lock lower (by omega) (fun q w qlo qhi => safe q w qlo (by omega)) step
  obtain ⟨lr,lower,held⟩ := persists r (by omega) (Nat.le_refl _)
  have step := rules.steps k hk r
  rw [held] at step
  have noUnlock := cannot_unlock lower safe step.1
  have vote := step.2.1 v (rules.prevote k hk r v pv)
  simpa [afterPrevote,noUnlock,VoteAllowed,Compatible] using vote

/-- Minimal-round induction excludes every later conflicting certificate. The local
lock invariant used here is derived from RoundStep, not postulated as accountability. -/
theorem polc_after_commit {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    {mode : Bool} {e : Execution} (rules : HonestRules unit members honest mode e)
    (minority : Minority unit members honest) {start a : Nat} (commit : Commit unit members e start a) :
    ∀ r v, start ≤ r → PoLC unit members e r v → Compatible mode a v := by
  intro r
  induction r using Nat.strongRecOn with
  | ind r ih =>
    intro v order cert
    by_cases same : r = start
    · subst r
      exact Or.inl (polc_unique rules minority cert (commit_has_polc rules minority commit))
    · obtain ⟨kc,qc,pc⟩ := commit
      obtain ⟨kv,qv,pv⟩ := cert
      obtain ⟨m,_,hm,mc,mv⟩ := honest_intersection minority qc qv
      exact later_prevote rules hm (pc _ mc) (pv _ mv) (by omega)
        (fun q w lo hi cq => ih q hi w lo cq)

/-- Round-independent nonnil commit agreement in either coupled pinned-source reading. -/
theorem commit_agreement {unit : Nat} {members : List Committee.Entry} {honest : Hash → Bool}
    {mode : Bool} {e : Execution} (rules : HonestRules unit members honest mode e)
    (minority : Minority unit members honest) {ra rb a b : Nat}
    (ca : Commit unit members e ra a) (cb : Commit unit members e rb b) : a = b := by
  rcases Nat.le_total ra rb with order | order
  · exact (compatible_block (polc_after_commit rules minority ca rb (some b) order
      (commit_has_polc rules minority cb))).symm
  · exact compatible_block (polc_after_commit rules minority cb ra (some a) order
      (commit_has_polc rules minority ca))

/-- Actual CommitValid quorum and vote checks supply the lower-level nonnil certificate. -/
theorem commitValid_bridge {c : Consensus.Context} {signature : Consensus.Vote → Prop} {h : Nat}
    {e : Execution} {r b : Nat} {votes : List Consensus.Vote}
    (attributed : CommitAttribution e r b votes)
    (valid : Consensus.CommitValid c signature h r b votes) :
    Commit c.unit (Consensus.activeAt c h).members e r b := by
  refine ⟨votes.map Consensus.Vote.key,valid.2.2.2.2,?_⟩
  intro k mem
  obtain ⟨v,member,key⟩ := List.mem_map.mp mem
  rw [← key]
  exact attributed v member

end Etna.Design.Locking
