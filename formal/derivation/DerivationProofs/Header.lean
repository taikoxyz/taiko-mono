import DerivationStatements.Claims
import DerivationProofs.Derive
import DerivationProofs.ExtraData

/-!
# Header plan lemmas

Facts about `buildHeader` and `deriveHeaders`: each plan has the Unzen layout, plans keep the
derived blocks, the Anchor contract's recorded anchor follows the derived anchors, and the
parent rebuilt from the last header and the recorded anchor is the parent derivation continues
from.
-/

namespace TaikoSpec.Derivation.Proofs

open TaikoSpec TaikoSpec.Derivation Statements

variable {c : ChainParams} {ctx : ProposalCtx}

/-- Every header plan has the Unzen layout. -/
theorem buildHeader_unzen (hc : HeaderContext) (b : DerivedBlock) :
    UnzenHeader hc (buildHeader hc b) :=
  ⟨rfl, by simp [buildHeader], rfl, extraData_proposal _ _, rfl⟩

/-- Header plans keep the derived blocks, in order. -/
theorem deriveHeaders_blocks (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) :
    (deriveHeaders c ctx hc p sources).map (·.block) = deriveSources c ctx p sources := by
  simp [deriveHeaders, buildHeader, Function.comp_def]

theorem deriveHeaders_unzen (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) :
    ∀ h ∈ deriveHeaders c ctx hc p sources, UnzenHeader hc h := by
  intro h hh
  obtain ⟨b, -, rfl⟩ := List.mem_map.1 hh
  exact buildHeader_unzen hc b

/-! ## The recorded anchor -/

/-- Along nondecreasing anchors, `anchorV4` records every block's own anchor number. -/
theorem recordedAnchors_of_chain :
    ∀ {a : Nat} {xs : List Nat}, Chain (· ≤ ·) a xs → recordedAnchors a xs = xs
  | _, [], _ => rfl
  | _, _ :: _, ⟨hx, hc⟩ => by
    simp only [recordedAnchors, Nat.max_eq_right hx, recordedAnchors_of_chain hc]

theorem deriveHeaders_recordedAnchors (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) :
    recordedAnchors p.anchorBlockNumber
        ((deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber)) =
      (deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber) := by
  have h : (deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber) =
      (deriveSources c ctx p sources).map (·.anchorBlockNumber) := by
    simp [deriveHeaders, buildHeader, Function.comp_def]
  rw [h]
  exact recordedAnchors_of_chain (deriveSources_anchors p sources)

/-! ## Reading the parent back -/

theorem toDerived_headerParent (hc : HeaderContext) (f : Bool) :
    ∀ (p : Parent) (bs : List BlockManifest),
      (toDerived f p bs).foldl (fun _ b => headerParent (buildHeader hc b)) p = bs.foldl advance p
  | _, [] => rfl
  | p, b :: bs => by
    simp only [toDerived, List.foldl_cons]
    exact toDerived_headerParent hc f (advance p b) bs

theorem deriveSources_headerParent (hc : HeaderContext) :
    ∀ (p : Parent) (sources : List (Source × Option ByteArray)),
      (deriveSources c ctx p sources).foldl (fun _ b => headerParent (buildHeader hc b)) p =
        parentAfter c ctx p sources
  | _, [] => rfl
  | p, (src, payload) :: rest => by
    simp only [deriveSources, parentAfter, List.foldl_append, toDerived_headerParent]
    exact deriveSources_headerParent hc _ rest

/-- Folding `headerParent` over the header plans gives the parent derivation continues from. -/
theorem deriveHeaders_headerParent (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) :
    (deriveHeaders c ctx hc p sources).foldl (fun _ h => headerParent h) p =
      parentAfter c ctx p sources := by
  rw [deriveHeaders, List.foldl_map]
  exact deriveSources_headerParent hc p sources

theorem foldl_headerParent_anchor :
    ∀ (p : Parent) (hs : List HeaderPlan),
      (hs.foldl (fun _ h => headerParent h) p).anchorBlockNumber =
        lastOr p.anchorBlockNumber (hs.map (·.block.anchorBlockNumber))
  | _, [] => rfl
  | _, h :: hs => foldl_headerParent_anchor (headerParent h) hs

/-- The parent rebuilt from the last header plan and the recorded anchor, or `p` when there is
no header plan, is the parent derivation continues from. -/
theorem deriveHeaders_rebuiltParent (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) :
    rebuiltParent p (deriveHeaders c ctx hc p sources) = parentAfter c ctx p sources := by
  rw [← deriveHeaders_headerParent hc p sources]
  simp only [rebuiltParent, deriveHeaders_recordedAnchors, ← foldl_headerParent_anchor]

/-! ## Unzen blocks -/

/-- Every block planned on top of an Unzen parent is itself after Unzen activation. -/
theorem deriveHeaders_after_unzen (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)) (hp : c.unzenForkTime ≤ p.timestamp) :
    ∀ h ∈ deriveHeaders c ctx hc p sources, c.unzenForkTime ≤ h.block.timestamp := by
  intro h hh
  obtain ⟨b, hb, rfl⟩ := List.mem_map.1 hh
  have := Chain.lt_of_mem (deriveSources_timestamps p sources) b.timestamp (List.mem_map_of_mem hb)
  simp only [buildHeader]
  omega

end TaikoSpec.Derivation.Proofs
