import TaikoSpec.Chain
import TaikoSpec.Derivation.Derive
import TaikoSpec.Derivation.RustOrder

/-!
# Per-source lemmas

Facts about one finalized source, used by `Proofs/Derive.lean` and `Properties.lean`.
-/

namespace TaikoSpec.Derivation.Proofs

open TaikoSpec TaikoSpec.Derivation

variable {c : ChainParams} {ctx : ProposalCtx} {p : Parent} {src : Source}

/-! ## Validation, rule by rule -/

theorem validate_eq_true {forced : Bool} {bs : List BlockManifest} :
    validate c ctx p forced bs = true ↔
      bs ≠ [] ∧ timestampsValid c ctx p.timestamp bs = true ∧
        anchorsValid c ctx p.anchorBlockNumber bs = true ∧
        (forced = true ∨ ∃ b ∈ bs, p.anchorBlockNumber < b.anchorBlockNumber) ∧
        gasLimitsValid (effectiveGasLimit p) bs = true := by
  simp [validate, List.any_eq_true, and_assoc]

theorem timestampsValid_chain :
    ∀ {a : Nat} {bs : List BlockManifest}, timestampsValid c ctx a bs = true →
      Chain (· < ·) a (bs.map (·.timestamp))
  | _, [], _ => trivial
  | _, _ :: _, h => by
    simp only [timestampsValid, Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨hlow, -⟩, hrest⟩ := h
    refine ⟨?_, timestampsValid_chain hrest⟩
    simp only [lowerBound] at hlow
    dsimp only
    omega

theorem timestampsValid_le :
    ∀ {a : Nat} {bs : List BlockManifest}, timestampsValid c ctx a bs = true →
      ∀ b ∈ bs, b.timestamp ≤ ctx.timestamp
  | _, [], _ => by simp
  | _, _ :: _, h => by
    simp only [timestampsValid, Bool.and_eq_true, decide_eq_true_eq] at h
    intro x hx
    rcases List.mem_cons.1 hx with rfl | hx
    · exact h.1.2
    · exact timestampsValid_le h.2 x hx

theorem anchorsValid_chain :
    ∀ {a : Nat} {bs : List BlockManifest}, anchorsValid c ctx a bs = true →
      Chain (· ≤ ·) a (bs.map (·.anchorBlockNumber))
  | _, [], _ => trivial
  | _, _ :: _, h => by
    simp only [anchorsValid, Bool.and_eq_true, decide_eq_true_eq] at h
    exact ⟨h.1.1.1, anchorsValid_chain h.2⟩

theorem anchorsValid_le :
    ∀ {a : Nat} {bs : List BlockManifest}, anchorsValid c ctx a bs = true →
      ∀ b ∈ bs, b.anchorBlockNumber ≤ ctx.originBlockNumber
  | _, [], _ => by simp
  | _, _ :: _, h => by
    simp only [anchorsValid, Bool.and_eq_true, decide_eq_true_eq] at h
    intro x hx
    rcases List.mem_cons.1 hx with rfl | hx
    · exact h.1.1.2
    · exact anchorsValid_le h.2 x hx

theorem gasBounds_fst_ge {g : Nat} (h : MIN_BLOCK_GAS_LIMIT ≤ g) :
    MIN_BLOCK_GAS_LIMIT ≤ (gasBounds g).1 := by
  simp only [gasBounds, MIN_BLOCK_GAS_LIMIT, MAX_BLOCK_GAS_LIMIT, GAS_LIMIT_DENOMINATOR,
    BLOCK_GAS_LIMIT_MAX_CHANGE] at *
  omega

theorem gasBounds_snd_le (g : Nat) : (gasBounds g).2 ≤ MAX_BLOCK_GAS_LIMIT := by
  simp only [gasBounds, MAX_BLOCK_GAS_LIMIT]
  omega

theorem gasBounds_self {g : Nat} (h₁ : MIN_BLOCK_GAS_LIMIT ≤ g) (h₂ : g ≤ MAX_BLOCK_GAS_LIMIT) :
    (gasBounds g).1 ≤ g ∧ g ≤ (gasBounds g).2 := by
  simp only [gasBounds, MIN_BLOCK_GAS_LIMIT, MAX_BLOCK_GAS_LIMIT, GAS_LIMIT_DENOMINATOR,
    BLOCK_GAS_LIMIT_MAX_CHANGE] at *
  omega

theorem gasLimitsValid_range :
    ∀ {g : Nat} {bs : List BlockManifest}, gasLimitsValid g bs = true →
      MIN_BLOCK_GAS_LIMIT ≤ g →
      ∀ b ∈ bs, MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT
  | _, [], _, _ => by simp
  | g, b :: _, h, hg => by
    simp only [gasLimitsValid, Bool.and_eq_true, decide_eq_true_eq] at h
    have hb : MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT :=
      ⟨Nat.le_trans (gasBounds_fst_ge hg) h.1.1, Nat.le_trans h.1.2 (gasBounds_snd_le g)⟩
    intro x hx
    rcases List.mem_cons.1 hx with rfl | hx
    · exact hb
    · exact gasLimitsValid_range h.2 hb.1 x hx

theorem inherit_length :
    ∀ (a : Nat) (bs : List BlockManifest), (inherit c ctx p a bs).length = bs.length
  | _, [] => rfl
  | _, _ :: bs => by simp [inherit, inherit_length _ bs]

/-! ## Finalized sources -/

/-- A finalized source kept blocks that passed validation, or is the default block. -/
theorem finalizeSource_cases (m : Option (List BlockManifest)) :
    (∃ bs, validate c ctx p src.isForcedInclusion bs = true ∧
        finalizeSource c ctx p src m = .accepted bs) ∨
      finalizeSource c ctx p src m = .defaulted (defaultBlock c ctx p) := by
  cases m with
  | none => exact Or.inr rfl
  | some bs =>
    simp only [finalizeSource]
    generalize (if src.isForcedInclusion = true then inherit c ctx p p.timestamp bs else bs) = bs'
    split
    · exact Or.inl ⟨bs', ‹_›, rfl⟩
    · exact Or.inr rfl

theorem finalizeSource_timestamps (m : Option (List BlockManifest)) :
    Chain (· < ·) p.timestamp ((finalizeSource c ctx p src m).blocks.map (·.timestamp)) := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs, hv, h⟩ | h <;> rw [h]
  · exact timestampsValid_chain (validate_eq_true.1 hv).2.1
  · exact ⟨by simp only [defaultBlock, lowerBound]; omega, trivial⟩

theorem chain_of_le {K F : Nat} :
    ∀ {a : Nat} {xs : List Nat}, (∀ x ∈ xs, x ≤ K) →
      Chain (fun prev x => x ≤ max K (max (prev + 1) F)) a xs
  | _, [], _ => trivial
  | _, x :: _, h =>
    ⟨by have := h x (by simp); omega, chain_of_le fun y hy => h y (by simp [hy])⟩

/-- Accepted blocks are no later than the proposal timestamp; the default block is no later
than one second after the parent, or the fork time, or the proposal timestamp. -/
theorem finalizeSource_drift (m : Option (List BlockManifest)) :
    Chain (fun prev x => x ≤ max ctx.timestamp (max (prev + 1) c.shastaForkTime)) p.timestamp
      ((finalizeSource c ctx p src m).blocks.map (·.timestamp)) := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs, hv, h⟩ | h <;> rw [h]
  · have hle := timestampsValid_le (validate_eq_true.1 hv).2.1
    exact chain_of_le (by simpa [SourceOutcome.blocks] using hle)
  · exact ⟨by simp only [defaultBlock, lowerBound]; omega, trivial⟩

theorem finalizeSource_accepted_le {m : Option (List BlockManifest)} {bs : List BlockManifest}
    (h : finalizeSource c ctx p src m = .accepted bs) : ∀ b ∈ bs, b.timestamp ≤ ctx.timestamp := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs', hv, h'⟩ | h' <;> rw [h'] at h
  · cases h
    exact timestampsValid_le (validate_eq_true.1 hv).2.1
  · cases h

theorem finalizeSource_anchors (m : Option (List BlockManifest)) :
    Chain (· ≤ ·) p.anchorBlockNumber
      ((finalizeSource c ctx p src m).blocks.map (·.anchorBlockNumber)) := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs, hv, h⟩ | h <;> rw [h]
  · exact anchorsValid_chain (validate_eq_true.1 hv).2.2.1
  · simp [SourceOutcome.blocks, Chain, defaultBlock]

theorem finalizeSource_anchor_le (m : Option (List BlockManifest))
    (hp : p.anchorBlockNumber ≤ ctx.originBlockNumber) :
    ∀ b ∈ (finalizeSource c ctx p src m).blocks,
      b.anchorBlockNumber ≤ ctx.originBlockNumber := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs, hv, h⟩ | h <;> rw [h]
  · exact anchorsValid_le (validate_eq_true.1 hv).2.2.1
  · simpa [SourceOutcome.blocks, defaultBlock] using hp

theorem finalizeSource_gas (m : Option (List BlockManifest))
    (h₁ : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit p)
    (h₂ : effectiveGasLimit p ≤ MAX_BLOCK_GAS_LIMIT) :
    ∀ b ∈ (finalizeSource c ctx p src m).blocks,
      MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs, hv, h⟩ | h <;> rw [h]
  · exact gasLimitsValid_range (validate_eq_true.1 hv).2.2.2.2 h₁
  · simpa [SourceOutcome.blocks, defaultBlock] using ⟨h₁, h₂⟩

theorem finalizeSource_progress {m : Option (List BlockManifest)} {bs : List BlockManifest}
    (h : finalizeSource c ctx p src m = .accepted bs) (hf : src.isForcedInclusion = false) :
    ∃ b ∈ bs, p.anchorBlockNumber < b.anchorBlockNumber := by
  rcases finalizeSource_cases (c := c) (ctx := ctx) (p := p) (src := src) m with
    ⟨bs', hv, h'⟩ | h' <;> rw [h'] at h
  · cases h
    rcases (validate_eq_true.1 hv).2.2.2.1 with hf' | hb
    · simp [hf] at hf'
    · exact hb
  · cases h

theorem maxBlocks_pos (c : ChainParams) (t : Nat) : 1 ≤ maxBlocks c t := by
  unfold maxBlocks
  split
  · split <;> decide
  · decide

theorem extractManifest_limits {payload : Option ByteArray} {bs : List BlockManifest}
    (h : extractManifest c ctx src payload = some bs) :
    bs.length ≤ maxBlocks c ctx.timestamp ∧ (src.isForcedInclusion = true → bs.length = 1) := by
  unfold extractManifest at h
  split at h
  · simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h
    obtain ⟨_, _, _, _, _, _, blocks, _, hc⟩ := h
    unfold checkLimits at hc
    split at hc
    · cases hc
      assumption
    · cases hc
  · cases h

theorem sourceBlocks_count (payload : Option ByteArray) :
    1 ≤ (sourceBlocks c ctx p src payload).length ∧
      (sourceBlocks c ctx p src payload).length ≤ maxBlocks c ctx.timestamp ∧
      (src.isForcedInclusion = true → (sourceBlocks c ctx p src payload).length = 1) := by
  unfold sourceBlocks
  cases hx : extractManifest c ctx src payload with
  | none =>
    simp [finalizeSource, SourceOutcome.blocks, maxBlocks_pos]
  | some bs =>
    have hl := extractManifest_limits hx
    simp only [finalizeSource]
    generalize hbs :
      (if src.isForcedInclusion = true then inherit c ctx p p.timestamp bs else bs) = bs'
    have hlen : bs'.length = bs.length := by
      rw [← hbs]
      split <;> simp [inherit_length]
    split
    · rename_i hv
      have hne := (validate_eq_true.1 hv).1
      simp only [SourceOutcome.blocks]
      refine ⟨?_, by rw [hlen]; exact hl.1, fun hf => by rw [hlen]; exact hl.2 hf⟩
      cases bs' with
      | nil => exact absurd rfl hne
      | cons => simp
    · simp [SourceOutcome.blocks, maxBlocks_pos]

theorem forced_accepted_iff (b : BlockManifest) (hf : src.isForcedInclusion = true) :
    (finalizeSource c ctx p src (some [b])).isAccepted = true ↔
      lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
      ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
      p.anchorBlockNumber ≤ ctx.originBlockNumber ∧
      (gasBounds (effectiveGasLimit p)).1 ≤ effectiveGasLimit p ∧
      effectiveGasLimit p ≤ (gasBounds (effectiveGasLimit p)).2 := by
  have : (finalizeSource c ctx p src (some [b])).isAccepted =
      validate c ctx p true (inherit c ctx p p.timestamp [b]) := by
    cases hv : validate c ctx p true (inherit c ctx p p.timestamp [b]) <;>
      simp [finalizeSource, hf, hv, SourceOutcome.isAccepted]
  rw [this]
  simp [validate, inherit, timestampsValid, anchorsValid, gasLimitsValid]
  omega

theorem finalizeSourceRust_eq (m : Option (List BlockManifest)) :
    finalizeSourceRust c ctx p src m = finalizeSource c ctx p src m := by
  cases m with
  | none => rfl
  | some bs =>
    cases hf : src.isForcedInclusion
    · cases hd : looksLikeDefault bs
      · simp [finalizeSourceRust, finalizeSource, hf, hd]
      · match bs, hd with
        | [b], hd =>
          have hts : b.timestamp = 0 := by
            simp only [looksLikeDefault, Bool.and_eq_true, beq_iff_eq] at hd
            exact hd.1.1.1.1
          have hRust : validate c ctx p false (inherit c ctx p p.timestamp [b]) = false := by
            simp [validate, inherit]
          have hGo : validate c ctx p false [b] = false := by
            simp [validate, timestampsValid, lowerBound, hts]
          simp [finalizeSourceRust, finalizeSource, hf, hd, hRust, hGo]
        | [], hd => simp [looksLikeDefault] at hd
        | _ :: _ :: _, hd => simp [looksLikeDefault] at hd
    · simp [finalizeSourceRust, finalizeSource, hf]

end TaikoSpec.Derivation.Proofs
