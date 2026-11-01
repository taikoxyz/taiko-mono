import EtnaModel.Locking
import EtnaProofs.RoundSafety
import EtnaProofs.HistoricalContext

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

/-- Etna design safety at its actual activeAt committee, independent of commit rounds.
The bridge's nonnil/crypto attribution and honest-key engine rules remain explicit. -/
theorem commitValid_agreement {c : Consensus.Context} {signature : Consensus.Vote → Prop} {h : Nat}
    {honest : Hash → Bool} {mode : Bool} {e : Execution}
    (rules : HonestRules c.unit (Consensus.activeAt c h).members honest mode e)
    (minority : Minority c.unit (Consensus.activeAt c h).members honest)
    {ra rb a b : Nat} {votesA votesB : List Consensus.Vote}
    (attributedA : CommitAttribution e ra a votesA) (attributedB : CommitAttribution e rb b votesB)
    (ca : Consensus.CommitValid c signature h ra a votesA)
    (cb : Consensus.CommitValid c signature h rb b votesB) : a = b :=
  commit_agreement rules minority (commitValid_bridge attributedA ca) (commitValid_bridge attributedB cb)

private theorem registry_from_raw_prefix {a b : RegistryHistory.State} {cutoff : Nat}
    (shared : a.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      b.history.filter (fun cp => decide (cp.block ≤ cutoff))) :
    HistoricalContext.registryAt a cutoff = HistoricalContext.registryAt b cutoff := by
  have heads := congrArg List.head? shared
  simp only [List.head?_filter] at heads
  simp only [HistoricalContext.registryAt,RegistryHistory.latestSnapshot,heads]

/-- Derived contexts agree at this height from the common decoded archive common and
raw finalized registry entries through its cutoff. The build checks and raw inputs are
not a proof of header/MPT authentication; callers must supply that adapter boundary.
No assumption equates chosen committees or already-derived registry lookup functions. -/
theorem active_committee_prefix {sa sb : State} {registryA registryB : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {common moreA moreB : List Nat} {h : Nat}
    {ca cb : Consensus.Context}
    (builtA : HistoricalContext.build sa registryA cfg (common ++ moreA) = some ca)
    (builtB : HistoricalContext.build sb registryB cfg (common ++ moreB) = some cb)
    (sameInstance : SameInstance sa sb) (covered : requiredPrefix sa cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff sa cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff sa cfg common h))) :
    ca.domain = cb.domain ∧ ca.generation = cb.generation ∧ ca.unit = cb.unit ∧
      Consensus.activeAt ca h = Consensus.activeAt cb h := by
  rw [(HistoricalContext.build_success builtA).2,(HistoricalContext.build_success builtB).2]
  obtain ⟨domain,generation,origin⟩ := sameInstance
  refine ⟨domain,generation,rfl,?_⟩
  have registry := registry_from_raw_prefix registryPrefix
  unfold Consensus.activeAt Consensus.epoch Consensus.switchHeight HistoricalContext.derive
  dsimp only
  rw [← origin]
  by_cases normal : sa.origin.height < (h-1)/cfg.epochLen*cfg.epochLen-1
  · have index : (h-1)/cfg.epochLen*cfg.epochLen-2 < common.length := by
      have count : (h-1)/cfg.epochLen*cfg.epochLen-2+1 ≤ common.length := by
        simpa [requiredPrefix,normal] using covered
      omega
    have anchorA := HistoricalContext.prefix_append_stable 0 common moreA _ index
    have anchorB := HistoricalContext.prefix_append_stable 0 common moreB _ index
    simp only [normal,ite_true,Consensus.normal,Consensus.selected,
      HistoricalContext.anchorAt,anchorA,anchorB]
    simpa [HistoricalContext.cutoff,normal,HistoricalContext.anchorAt] using congrArg
      (fun es => Committee.Record.mk ((h-1)/cfg.epochLen)
        (max (HistoricalContext.anchorAt common ((h-1)/cfg.epochLen*cfg.epochLen-2)) sa.origin.l1Block)
        (Committee.chosen cfg.unit cfg.minimum
          (max (HistoricalContext.anchorAt common ((h-1)/cfg.epochLen*cfg.epochLen-2)) sa.origin.l1Block) cfg.nMax es)) registry
  · simp only [normal,ite_false,Consensus.initial,Consensus.selected,← generation]
    simpa [HistoricalContext.cutoff,normal] using congrArg
      (fun es => Committee.Record.mk (if sa.generation = 0 then 0 else sa.origin.height/cfg.epochLen)
        (if sa.generation = 0 then cfg.genesisCutoff else sa.origin.l1Block)
        (Committee.chosen cfg.unit cfg.minimum
          (if sa.generation = 0 then cfg.genesisCutoff else sa.origin.l1Block) cfg.nMax es)) registry

/-- S(t) = t*epochLen-1 signals an update; H+2 = t*epochLen+1 uses it.
Exactly the first t*epochLen-1 archive entries suffice, including header S(t)-1. -/
theorem handover_prefix_length (s : State) (cfg : HistoricalContext.Parameters)
    (registry : RegistryHistory.State) (archive : List Nat) (t : Nat) (positive : 0 < cfg.epochLen)
    (occurred : s.origin.height < t*cfg.epochLen-1) :
    requiredPrefix s cfg (t*cfg.epochLen+1) = t*cfg.epochLen-1 ∧
      Consensus.activeAt (HistoricalContext.derive s registry cfg archive) (t*cfg.epochLen+1) =
        Consensus.normal (HistoricalContext.derive s registry cfg archive) t := by
  constructor
  · simp only [requiredPrefix,Nat.add_sub_cancel,Nat.mul_div_cancel _ positive,occurred,ite_true]
    omega
  · exact Consensus.active_at_handover _ t positive occurred

/-- Before this generation's first occurred switch, recovery bootstrap needs no archive
entry: its registry cutoff is the authenticated fixed origin, not the current checkpoint. -/
theorem recovery_bootstrap_prefix (s : State) (cfg : HistoricalContext.Parameters)
    (registry : RegistryHistory.State) (archive : List Nat) (h : Nat) (recovery : s.generation ≠ 0)
    (bootstrap : (h-1)/cfg.epochLen*cfg.epochLen-1 ≤ s.origin.height) :
    requiredPrefix s cfg h = 0 ∧
      (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) h).cutoff = s.origin.l1Block := by
  refine ⟨by simp [requiredPrefix,Nat.not_lt.mpr bootstrap],?_⟩
  exact Consensus.recovery_initial_until_switch _ h recovery bootstrap

/-- Two locally built Etna contexts compose with one locking execution only after their
raw same-instance inputs derive the same committee. Numerical height alone is insufficient. -/
theorem shared_history_commitValid_agreement {sa sb : State} {registryA registryB : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {common moreA moreB : List Nat} {h : Nat}
    {ca cb : Consensus.Context}
    (builtA : HistoricalContext.build sa registryA cfg (common ++ moreA) = some ca)
    (builtB : HistoricalContext.build sb registryB cfg (common ++ moreB) = some cb)
    (sameInstance : SameInstance sa sb) (covered : requiredPrefix sa cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff sa cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff sa cfg common h)))
    {honest : Hash → Bool} {mode : Bool} {e : Execution} {sigA sigB : Consensus.Vote → Prop}
    (rules : HonestRules ca.unit (Consensus.activeAt ca h).members honest mode e)
    (minority : Minority ca.unit (Consensus.activeAt ca h).members honest)
    {ra rb a b : Nat} {votesA votesB : List Consensus.Vote}
    (attributedA : CommitAttribution e ra a votesA) (attributedB : CommitAttribution e rb b votesB)
    (validA : Consensus.CommitValid ca sigA h ra a votesA)
    (validB : Consensus.CommitValid cb sigB h rb b votesB) : a = b := by
  obtain ⟨_,_,unit,committee⟩ := active_committee_prefix builtA builtB sameInstance covered registryPrefix
  have lowerB := commitValid_bridge attributedB validB
  rw [← unit,← committee] at lowerB
  exact commit_agreement rules minority (commitValid_bridge attributedA validA) lowerB

end Etna.Design.Locking
