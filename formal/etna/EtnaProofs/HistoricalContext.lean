import EtnaModel.HistoricalContext
import EtnaProofs.RegistryHistory
import EtnaProofs.Consensus

/-! Proofs about `EtnaModel.HistoricalContext`. -/
namespace Etna.Design.HistoricalContext

/-- Independent unfolded contracts: deleting a readiness check (e.g. `3 ≤ cfg.epochLen`) or
changing a derived field must fail here. They constrain the modeled definitions only. -/
theorem ready_contract (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) :
    _root_.Etna.Design.HistoricalContext.Ready s registry cfg archive ↔
      (_root_.Etna.Design.HistoricalContext.fixedOrigin s = some s.origin ∧ s.checkpoint.height < archive.length ∧
        archive.Pairwise (· ≤ ·) ∧ _root_.Etna.Design.RegistryHistory.Ordered registry.history ∧
        (_root_.Etna.Design.RegistryHistory.latestSnapshot registry.history
          (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block)).isSome = true ∧
        (_root_.Etna.Design.Committee.election cfg.unit cfg.minimum
          (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block) cfg.nMax
          (_root_.Etna.Design.HistoricalContext.registryAt registry
            (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block))).isSome = true ∧
        3 ≤ cfg.epochLen ∧ cfg.genesisCutoff ≤ s.origin.l1Block) := Iff.rfl

theorem build_contract (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) :
    _root_.Etna.Design.HistoricalContext.build s registry cfg archive =
      (if _root_.Etna.Design.HistoricalContext.Ready s registry cfg archive then
        some (_root_.Etna.Design.HistoricalContext.derive s registry cfg archive) else none) ∧
    _root_.Etna.Design.HistoricalContext.derive s registry cfg archive =
      ⟨s.domain,s.generation,s.origin.height,s.origin.l1Block,cfg.genesisCutoff,cfg.epochLen,cfg.unit,cfg.minimum,
        cfg.nMax,_root_.Etna.Design.HistoricalContext.registryAt registry,
        _root_.Etna.Design.HistoricalContext.anchorAt archive⟩ ∧
    _root_.Etna.Design.HistoricalContext.fixedOrigin s =
      (s.origins.find? (fun pair => pair.1 == s.generation)).map Prod.snd := ⟨rfl,rfl,rfl⟩

theorem build_success {s : State} {registry : RegistryHistory.State} {cfg : Parameters} {archive : List Nat}
    {c : Consensus.Context} (ok : build s registry cfg archive = some c) :
    Ready s registry cfg archive ∧ c = derive s registry cfg archive := by
  unfold build at ok
  split at ok
  · rename_i ready
    exact ⟨ready,(Option.some.inj ok).symm⟩
  · contradiction

theorem missing_origin_rejected (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat)
    (missing : fixedOrigin s = none) : build s registry cfg archive = none := by
  apply ite_eq_right
  intro h
  have origin := h.1
  rw [missing] at origin
  contradiction

theorem fixed_origin_not_checkpoint {s : State} {registry : RegistryHistory.State} {cfg : Parameters} {archive : List Nat}
    {c : Consensus.Context} (ok : build s registry cfg archive = some c) :
    c.domain = s.domain ∧ c.generation = s.generation ∧ c.originHeight = s.origin.height ∧
    c.originBlock = s.origin.l1Block := by
  rw [(build_success ok).2]
  exact ⟨rfl,rfl,rfl,rfl⟩

theorem context_uses_latest_snapshot {s : State} {registry : RegistryHistory.State} {cfg : Parameters}
    {archive : List Nat} {c : Consensus.Context} {cutoff : Nat} {snapshot : RegistryHistory.Snapshot}
    (ok : build s registry cfg archive = some c)
    (found : RegistryHistory.latestSnapshot registry.history cutoff = some snapshot) :
    c.registry cutoff = snapshot.entries ∧ snapshot.block ≤ cutoff ∧
    ∀ candidate ∈ registry.history, candidate.block ≤ cutoff → candidate.block ≤ snapshot.block := by
  have info := build_success ok
  rw [info.2]
  refine ⟨?_,(RegistryHistory.snapshot_is_at_or_before found).2,
    RegistryHistory.snapshot_is_latest info.1.2.2.2.1 found⟩
  simp [derive,registryAt,found]

theorem context_initial_election {s : State} {registry : RegistryHistory.State} {cfg : Parameters}
    {archive : List Nat} {c : Consensus.Context} (ok : build s registry cfg archive = some c) :
    Consensus.ElectionValid c (Consensus.initial c) := by
  have info := build_success ok
  have nonempty := info.1.2.2.2.2.2.1
  rw [info.2]
  change Committee.election cfg.unit cfg.minimum
    (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block) cfg.nMax
    (registryAt registry (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block)) =
    some (Committee.chosen cfg.unit cfg.minimum
      (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block) cfg.nMax
      (registryAt registry (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block)))
  cases result : Committee.election cfg.unit cfg.minimum
      (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block) cfg.nMax
      (registryAt registry (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block)) with
  | none => simp [result] at nonempty
  | some members => rw [← Committee.election_chosen result]

theorem prefix_floor (floor : Nat) (archive : List Nat) (h : Nat) : floor ≤ prefixAnchor floor archive h := by
  induction archive generalizing floor h with
  | nil => simp [prefixAnchor]
  | cons a rest ih =>
    cases h
    · exact Nat.le_max_left _ _
    · exact Nat.le_trans (Nat.le_max_left _ _) (ih _ _)

theorem prefix_monotone (floor : Nat) (archive : List Nat) {a b : Nat} (order : a ≤ b) :
    prefixAnchor floor archive a ≤ prefixAnchor floor archive b := by
  induction archive generalizing floor a b with
  | nil => simp [prefixAnchor]
  | cons head rest ih =>
    cases a with
    | zero => cases b with
      | zero => exact Nat.le_refl _
      | succ b => exact prefix_floor _ _ _
    | succ a => cases b with
      | zero => omega
      | succ b => exact ih _ (by omega)

theorem prefix_bounded (floor reference : Nat) (archive : List Nat) (h : Nat)
    (initial : floor ≤ reference) (bounded : ∀ a ∈ archive, a ≤ reference) :
    prefixAnchor floor archive h ≤ reference := by
  induction archive generalizing floor h with
  | nil => simpa [prefixAnchor] using initial
  | cons a rest ih =>
    have head := bounded a (by simp)
    have tail : ∀ b ∈ rest, b ≤ reference := fun b mem => bounded b (by simp [mem])
    cases h with
    | zero => exact Nat.max_le.mpr ⟨initial,head⟩
    | succ h => exact ih _ _ (Nat.max_le.mpr ⟨initial,head⟩) tail

theorem prefix_append_stable (floor : Nat) (before after : List Nat) (h : Nat) (covered : h < before.length) :
    prefixAnchor floor (before ++ after) h = prefixAnchor floor before h := by
  induction before generalizing floor h with
  | nil => simp at covered
  | cons a rest ih =>
    cases h with
    | zero => rfl
    | succ h => exact ih _ _ (by simpa using covered)

theorem prefix_matches_header (archive : List Nat) (floor h value : Nat)
    (sorted : archive.Pairwise (· ≤ ·)) (lower : ∀ a ∈ archive, floor ≤ a)
    (present : archive[h]? = some value) : prefixAnchor floor archive h = value := by
  induction archive generalizing floor h with
  | nil => simp at present
  | cons a rest ih =>
    have parts := List.pairwise_cons.mp sorted
    cases h with
    | zero =>
      have same : a = value := by simpa using present
      subst value
      exact Nat.max_eq_right (lower a (by simp))
    | succ h =>
      apply ih (max floor a) h parts.2
      · intro b mem
        exact Nat.max_le.mpr ⟨lower b (by simp [mem]),parts.1 b mem⟩
      · simpa using present

theorem covered_context_header {s : State} {registry : RegistryHistory.State} {cfg : Parameters} {archive : List Nat}
    {c : Consensus.Context} (ok : build s registry cfg archive = some c) (h : Nat) (covered : h < archive.length) :
    ∃ value, archive[h]? = some value ∧ c.anchorAt h = value := by
  refine ⟨archive[h],by simp [covered],?_⟩
  have info := build_success ok
  rw [info.2]
  exact prefix_matches_header archive 0 h _ info.1.2.2.1 (by intro _ _; omega) (by simp [covered])

theorem derived_anchors_monotone (s : State) (registry : RegistryHistory.State) (cfg : Parameters)
    (archive : List Nat) {a b : Nat} (order : a ≤ b) :
    (derive s registry cfg archive).anchorAt a ≤ (derive s registry cfg archive).anchorAt b :=
  prefix_monotone 0 archive order

theorem derived_cutoff (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) (h : Nat) :
    (Consensus.activeAt (derive s registry cfg archive) h).cutoff = cutoff s cfg archive h := by
  unfold Consensus.activeAt Consensus.epoch Consensus.switchHeight derive
  dsimp only
  split <;> simp_all [Consensus.normal,Consensus.initial,Consensus.selected,cutoff,anchorAt] <;> omega

theorem cutoff_bounded (s : State) (cfg : Parameters) (archive : List Nat) (h reference : Nat)
    (origin : s.origin.l1Block ≤ reference) (genesis : cfg.genesisCutoff ≤ reference)
    (anchors : ∀ a ∈ archive, a ≤ reference) : cutoff s cfg archive h ≤ reference := by
  unfold cutoff
  dsimp only
  split
  · exact Nat.max_le.mpr ⟨prefix_bounded 0 reference archive _ (Nat.zero_le _) anchors,origin⟩
  · split <;> assumption

theorem cutoff_prefix_stable (s : State) (cfg : Parameters) (before after : List Nat) (h : Nat)
    (covered : h < before.length) : cutoff s cfg (before ++ after) h = cutoff s cfg before h := by
  unfold cutoff
  dsimp only
  split
  · have div := Nat.div_mul_le_self (h-1) cfg.epochLen
    have index : (h-1)/cfg.epochLen*cfg.epochLen-2 < before.length := by omega
    simp only [anchorAt,prefix_append_stable 0 before after _ index]
  · rfl

end Etna.Design.HistoricalContext
