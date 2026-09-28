import TaikoSpec.Proofs.Source

/-!
# Whole-proposal lemmas

Facts about `deriveSources`, proved by induction over the sources: each source's blocks satisfy
the per-source lemmas, and the parent after a source is its last block.
-/

namespace TaikoSpec.Derivation.Proofs

open TaikoSpec TaikoSpec.Derivation

variable {c : ChainParams} {ctx : ProposalCtx}

/-! ## Numbering and the parent after a source -/

theorem toDerived_timestamps : ∀ (f : Bool) (p : Parent) (bs : List BlockManifest),
    (toDerived f p bs).map (·.timestamp) = bs.map (·.timestamp)
  | _, _, [] => rfl
  | f, p, b :: bs => by simp [toDerived, toDerived_timestamps f (advance p b) bs]

theorem toDerived_anchors : ∀ (f : Bool) (p : Parent) (bs : List BlockManifest),
    (toDerived f p bs).map (·.anchorBlockNumber) = bs.map (·.anchorBlockNumber)
  | _, _, [] => rfl
  | f, p, b :: bs => by simp [toDerived, toDerived_anchors f (advance p b) bs]

theorem toDerived_gasLimits : ∀ (f : Bool) (p : Parent) (bs : List BlockManifest),
    (toDerived f p bs).map (·.gasLimit) = bs.map (·.gasLimit)
  | _, _, [] => rfl
  | f, p, b :: bs => by simp [toDerived, toDerived_gasLimits f (advance p b) bs]

theorem toDerived_numbers : ∀ (f : Bool) (p : Parent) (bs : List BlockManifest),
    Chain (fun a b => b = a + 1) p.number ((toDerived f p bs).map (·.number)) ∧
      lastOr p.number ((toDerived f p bs).map (·.number)) = (bs.foldl advance p).number
  | _, _, [] => ⟨trivial, rfl⟩
  | f, p, b :: bs => by
    obtain ⟨h₁, h₂⟩ := toDerived_numbers f (advance p b) bs
    exact ⟨⟨rfl, h₁⟩, h₂⟩

theorem foldl_advance_timestamp : ∀ (p : Parent) (bs : List BlockManifest),
    (bs.foldl advance p).timestamp = lastOr p.timestamp (bs.map (·.timestamp))
  | _, [] => rfl
  | p, b :: bs => foldl_advance_timestamp (advance p b) bs

theorem foldl_advance_anchor : ∀ (p : Parent) (bs : List BlockManifest),
    (bs.foldl advance p).anchorBlockNumber = lastOr p.anchorBlockNumber (bs.map (·.anchorBlockNumber))
  | _, [] => rfl
  | p, b :: bs => foldl_advance_anchor (advance p b) bs

theorem foldl_advance_effectiveGasLimit : ∀ (p : Parent) (bs : List BlockManifest),
    effectiveGasLimit (bs.foldl advance p) = lastOr (effectiveGasLimit p) (bs.map (·.gasLimit))
  | _, [] => rfl
  | p, b :: bs => by
    have h : effectiveGasLimit (advance p b) = b.gasLimit := by
      simp [effectiveGasLimit, advance, ANCHOR_GAS_LIMIT]
    rw [List.foldl_cons, foldl_advance_effectiveGasLimit (advance p b) bs, h]
    rfl

/-! ## Whole proposals -/

theorem deriveSources_append : ∀ (p : Parent) (xs ys : List (Source × Option ByteArray)),
    deriveSources c ctx p (xs ++ ys) =
      deriveSources c ctx p xs ++ deriveSources c ctx (parentAfter c ctx p xs) ys
  | _, [], _ => by simp [deriveSources, parentAfter]
  | p, (src, payload) :: xs, ys => by
    simp [deriveSources, parentAfter, deriveSources_append _ xs ys]

theorem deriveSources_numbers : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    Chain (fun a b => b = a + 1) p.number ((deriveSources c ctx p srcs).map (·.number))
  | _, [] => trivial
  | p, (src, payload) :: rest => by
    simp only [deriveSources, List.map_append]
    obtain ⟨h₁, h₂⟩ := toDerived_numbers src.isForcedInclusion p (sourceBlocks c ctx p src payload)
    rw [Chain.append, h₂]
    exact ⟨h₁, deriveSources_numbers _ rest⟩

theorem deriveSources_timestamps : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    Chain (· < ·) p.timestamp ((deriveSources c ctx p srcs).map (·.timestamp))
  | _, [] => trivial
  | p, (src, payload) :: rest => by
    simp only [deriveSources, List.map_append, toDerived_timestamps]
    rw [Chain.append, ← foldl_advance_timestamp]
    exact ⟨finalizeSource_timestamps _, deriveSources_timestamps _ rest⟩

theorem deriveSources_drift : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    Chain (fun prev x => x ≤ max ctx.timestamp (max (prev + 1) c.shastaForkTime)) p.timestamp
      ((deriveSources c ctx p srcs).map (·.timestamp))
  | _, [] => trivial
  | p, (src, payload) :: rest => by
    simp only [deriveSources, List.map_append, toDerived_timestamps]
    rw [Chain.append, ← foldl_advance_timestamp]
    exact ⟨finalizeSource_drift _, deriveSources_drift _ rest⟩

theorem chain_drift_bound {K F : Nat} :
    ∀ {a : Nat} {xs : List Nat}, Chain (fun prev x => x ≤ max K (max (prev + 1) F)) a xs →
      ∀ (i : Nat) (h : i < xs.length), xs[i] ≤ max K (max a F) + i + 1
  | _, [], _, _, h => by simp at h
  | _, _ :: _, ⟨hx, _⟩, 0, _ => by simp; omega
  | _, _ :: _, ⟨hx, hc⟩, i + 1, h => by
    have := chain_drift_bound hc i (by simpa using h)
    simp only [List.getElem_cons_succ]
    omega

theorem deriveSources_anchors : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    Chain (· ≤ ·) p.anchorBlockNumber ((deriveSources c ctx p srcs).map (·.anchorBlockNumber))
  | _, [] => trivial
  | p, (src, payload) :: rest => by
    simp only [deriveSources, List.map_append, toDerived_anchors]
    rw [Chain.append, ← foldl_advance_anchor]
    exact ⟨finalizeSource_anchors _, deriveSources_anchors _ rest⟩

theorem deriveSources_anchor_le : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    p.anchorBlockNumber ≤ ctx.originBlockNumber →
      ∀ b ∈ deriveSources c ctx p srcs, b.anchorBlockNumber ≤ ctx.originBlockNumber
  | _, [], _ => by simp [deriveSources]
  | p, (src, payload) :: rest, hp => by
    have hsrc := finalizeSource_anchor_le (c := c) (ctx := ctx) (p := p) (src := src)
      (extractManifest c ctx src payload) hp
    have hmap : ∀ a ∈ (sourceBlocks c ctx p src payload).map (·.anchorBlockNumber),
        a ≤ ctx.originBlockNumber := by
      simpa [sourceBlocks] using hsrc
    intro b hb
    simp only [deriveSources, List.mem_append] at hb
    rcases hb with hb | hb
    · have : b.anchorBlockNumber ∈ (toDerived src.isForcedInclusion p
          (sourceBlocks c ctx p src payload)).map (·.anchorBlockNumber) := List.mem_map_of_mem hb
      rw [toDerived_anchors] at this
      exact hmap _ this
    · refine deriveSources_anchor_le _ rest ?_ b hb
      rw [foldl_advance_anchor]
      exact lastOr_mem_of_forall (P := fun a => a ≤ ctx.originBlockNumber) hp hmap

theorem deriveSources_gas : ∀ (p : Parent) (srcs : List (Source × Option ByteArray)),
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit p → effectiveGasLimit p ≤ MAX_BLOCK_GAS_LIMIT →
      ∀ b ∈ deriveSources c ctx p srcs,
        MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT
  | _, [], _, _ => by simp [deriveSources]
  | p, (src, payload) :: rest, h₁, h₂ => by
    have hsrc := finalizeSource_gas (c := c) (ctx := ctx) (p := p) (src := src)
      (extractManifest c ctx src payload) h₁ h₂
    have hmap : ∀ g ∈ (sourceBlocks c ctx p src payload).map (·.gasLimit),
        MIN_BLOCK_GAS_LIMIT ≤ g ∧ g ≤ MAX_BLOCK_GAS_LIMIT := by
      simpa [sourceBlocks] using hsrc
    intro b hb
    simp only [deriveSources, List.mem_append] at hb
    rcases hb with hb | hb
    · have : b.gasLimit ∈ (toDerived src.isForcedInclusion p
          (sourceBlocks c ctx p src payload)).map (·.gasLimit) := List.mem_map_of_mem hb
      rw [toDerived_gasLimits] at this
      exact hmap _ this
    · have hnext := lastOr_mem_of_forall
        (P := fun g => MIN_BLOCK_GAS_LIMIT ≤ g ∧ g ≤ MAX_BLOCK_GAS_LIMIT) ⟨h₁, h₂⟩ hmap
      rw [← foldl_advance_effectiveGasLimit] at hnext
      exact deriveSources_gas _ rest hnext.1 hnext.2 b hb

end TaikoSpec.Derivation.Proofs
