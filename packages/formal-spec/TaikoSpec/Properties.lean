import TaikoSpec.Proofs.Derive

/-!
# Properties of Shasta derivation

Reviewers only need to read this file: whether each statement says what we want. The proofs are
in `Proofs/` and Lean's kernel checks them. CI rejects proofs with gaps or extra assumptions
(`scripts/gate.sh`, `lake exe checkaxioms`).

Every theorem with preconditions has a witness at the end of the file, concrete inputs that
satisfy them, so no theorem holds vacuously.
-/

namespace TaikoSpec.Derivation

open TaikoSpec Proofs

variable (c : ChainParams) (ctx : ProposalCtx) (p : Parent)

/-! ## 1. Cardinality -/

/-- Every source contributes at least one block and at most `maxBlocks`; a forced inclusion
contributes exactly one. -/
theorem source_block_count (src : Source) (payload : Option ByteArray) :
    1 ≤ (sourceBlocks c ctx p src payload).length ∧
      (sourceBlocks c ctx p src payload).length ≤ maxBlocks c ctx.timestamp ∧
      (src.isForcedInclusion = true → (sourceBlocks c ctx p src payload).length = 1) :=
  sourceBlocks_count payload

/-! ## 2. Source isolation -/

/-- Deriving `xs ++ ys` derives `xs`, then derives `ys` on top of the last block of `xs`. -/
theorem derive_append (xs ys : List (Source × Option ByteArray)) :
    deriveSources c ctx p (xs ++ ys) =
      deriveSources c ctx p xs ++ deriveSources c ctx (parentAfter c ctx p xs) ys :=
  deriveSources_append p xs ys

/-- Later sources cannot change the blocks of earlier ones. `Inbox.sol` places every forced
inclusion before the proposer's source, so nothing in the proposer's source affects them. -/
theorem earlier_sources_unaffected (xs ys : List (Source × Option ByteArray)) :
    (deriveSources c ctx p (xs ++ ys)).take (deriveSources c ctx p xs).length =
      deriveSources c ctx p xs := by
  rw [derive_append]
  simp

/-! ## 3. Block numbers -/

/-- Block numbers continue from the parent's, one at a time. -/
theorem numbers_consecutive (srcs : List (Source × Option ByteArray)) :
    Chain (fun a b => b = a + 1) p.number ((deriveSources c ctx p srcs).map (·.number)) :=
  deriveSources_numbers p srcs

/-! ## 4. Timestamps -/

/-- Timestamps strictly increase: each block is at least one second after the one before it,
and the first is after the parent. -/
theorem timestamps_increasing (srcs : List (Source × Option ByteArray)) :
    Chain (· < ·) p.timestamp ((deriveSources c ctx p srcs).map (·.timestamp)) :=
  deriveSources_timestamps p srcs

/-! ## 5. Timestamp drift -/

/-- Block `i` of a proposal (counting from 0) is at most `i + 1` seconds after the latest of the
proposal timestamp, the parent's timestamp and the fork time. -/
theorem timestamp_drift (srcs : List (Source × Option ByteArray)) (i : Nat)
    (h : i < (deriveSources c ctx p srcs).length) :
    (deriveSources c ctx p srcs)[i].timestamp ≤
      max ctx.timestamp (max p.timestamp c.shastaForkTime) + i + 1 := by
  have := chain_drift_bound (deriveSources_drift p srcs) i (by simpa using h)
  simpa using this

/-- A source that keeps its own blocks never places them after the proposal timestamp; only a
default block can be later. -/
theorem accepted_not_after_proposal (src : Source) (m : Option (List BlockManifest))
    (bs : List BlockManifest) (h : finalizeSource c ctx p src m = .accepted bs) :
    ∀ b ∈ bs, b.timestamp ≤ ctx.timestamp :=
  finalizeSource_accepted_le h

/-! ## 6. Anchors -/

/-- Anchors never decrease, starting from the parent's anchor. -/
theorem anchors_nondecreasing (srcs : List (Source × Option ByteArray)) :
    Chain (· ≤ ·) p.anchorBlockNumber ((deriveSources c ctx p srcs).map (·.anchorBlockNumber)) :=
  deriveSources_anchors p srcs

/-- If the parent's anchor is not past the origin block, no derived anchor is. -/
theorem anchors_not_after_origin (srcs : List (Source × Option ByteArray))
    (hp : p.anchorBlockNumber ≤ ctx.originBlockNumber) :
    ∀ b ∈ deriveSources c ctx p srcs, b.anchorBlockNumber ≤ ctx.originBlockNumber :=
  deriveSources_anchor_le p srcs hp

/-! ## 7. Gas limits -/

/-- If the parent's effective gas limit is within `[MIN_BLOCK_GAS_LIMIT, MAX_BLOCK_GAS_LIMIT]`,
every derived block's gas limit is too. -/
theorem gas_limits_in_range (srcs : List (Source × Option ByteArray))
    (h₁ : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit p)
    (h₂ : effectiveGasLimit p ≤ MAX_BLOCK_GAS_LIMIT) :
    ∀ b ∈ deriveSources c ctx p srcs,
      MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT :=
  deriveSources_gas p srcs h₁ h₂

/-! ## 8. Proposer progress -/

/-- A proposer's (non-forced) source that keeps its own blocks raises the anchor above the
parent's. -/
theorem proposer_source_advances_anchor (src : Source) (m : Option (List BlockManifest))
    (bs : List BlockManifest) (h : finalizeSource c ctx p src m = .accepted bs)
    (hf : src.isForcedInclusion = false) :
    ∃ b ∈ bs, p.anchorBlockNumber < b.anchorBlockNumber :=
  finalizeSource_progress h hf

/-! ## 9. Forced inclusions -/

/-- A forced inclusion whose manifest is one block keeps its transactions exactly when
(a) the timestamp window is not used up, (b) the parent's anchor is at most `MAX_ANCHOR_OFFSET`
behind the origin block and not past it, and (c) the parent's gas limit is within its own
bounds. Otherwise it becomes the default block: forced inclusions *can* be dropped, unlike what
`Derivation.md` states. -/
theorem forced_inclusion_accepted_iff (src : Source) (b : BlockManifest)
    (hf : src.isForcedInclusion = true) :
    (finalizeSource c ctx p src (some [b])).isAccepted = true ↔
      lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
      ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
      p.anchorBlockNumber ≤ ctx.originBlockNumber ∧
      (gasBounds (effectiveGasLimit p)).1 ≤ effectiveGasLimit p ∧
      effectiveGasLimit p ≤ (gasBounds (effectiveGasLimit p)).2 :=
  forced_accepted_iff b hf

/-- When the parent's gas limit is in range (see theorem 7), condition (c) always holds: a
one-block forced inclusion is dropped only when the timestamp window is used up or the parent's
anchor is too far behind (or past) the origin block. -/
theorem forced_inclusion_accepted_iff_of_gas (src : Source) (b : BlockManifest)
    (hf : src.isForcedInclusion = true)
    (h₁ : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit p)
    (h₂ : effectiveGasLimit p ≤ MAX_BLOCK_GAS_LIMIT) :
    (finalizeSource c ctx p src (some [b])).isAccepted = true ↔
      lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
      ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
      p.anchorBlockNumber ≤ ctx.originBlockNumber := by
  rw [forced_inclusion_accepted_iff c ctx p src b hf]
  have hg := gasBounds_self h₁ h₂
  exact ⟨fun h => ⟨h.1, h.2.1, h.2.2.1⟩, fun h => ⟨h.1, h.2.1, h.2.2, hg.1, hg.2⟩⟩

/-! ## 10. The Rust driver's order -/

/-- The Rust driver inherits metadata before validation for manifests that look exactly like
the default one; the Go driver (and this spec) validates them as they are. Both give the same
result. -/
theorem rust_order_agrees (src : Source) (m : Option (List BlockManifest)) :
    finalizeSourceRust c ctx p src m = finalizeSource c ctx p src m :=
  finalizeSourceRust_eq m

/-! ## Witnesses -/

namespace Witness

/-- A devnet proposal at timestamp 2000 whose origin block is 500. -/
def proposal : ProposalCtx :=
  { proposer := ⟨Array.replicate 20 0x99⟩, timestamp := 2000, originBlockNumber := 500 }

/-- Block 10 at timestamp 1900, 31M header gas limit (30M effective), anchor 400. -/
def parent : Parent :=
  { number := 10, timestamp := 1900, gasLimit := 31_000_000, anchorBlockNumber := 400 }

/-- A source with blobs. -/
def source (forced : Bool) : Source := { isForcedInclusion := forced, hasBlobs := true, offset := 0 }

/-- A block without transactions. -/
def block (timestamp anchor gasLimit : Nat) : BlockManifest :=
  { timestamp, coinbase := ⟨Array.replicate 20 0⟩, anchorBlockNumber := anchor, gasLimit,
    transactions := [] }

/-- Theorems 6 and 7: the parent's anchor and gas limit satisfy the preconditions. -/
example : parent.anchorBlockNumber ≤ proposal.originBlockNumber ∧
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit parent ∧
    effectiveGasLimit parent ≤ MAX_BLOCK_GAS_LIMIT := by decide

/-- Theorems 5 and 8: a proposer's source can keep its own blocks. -/
example : (finalizeSource devnet proposal parent (source false)
    (some [block 1950 450 30_000_000])).isAccepted = true := by decide

/-- Theorem 9: this forced inclusion is kept, and the same one is dropped once the origin block
is 129 blocks past the parent's anchor. -/
example : (finalizeSource devnet proposal parent (source true) (some [block 0 0 0])).isAccepted =
    true := by decide
example : (finalizeSource devnet { proposal with originBlockNumber := 529 } parent (source true)
    (some [block 0 0 0])).isAccepted = false := by decide

/-- Theorem 5: a default block can be later than the proposal timestamp. -/
example : (defaultBlock devnet { proposal with timestamp := 1900 } parent).timestamp > 1900 := by
  decide

end Witness

end TaikoSpec.Derivation
