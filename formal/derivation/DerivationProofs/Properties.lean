import DerivationProofs.Header

/-!
# Properties of Unzen derivation

Detailed public properties are retained here. Review headline propositions and premises in
`DerivationStatements/Claims.lean`, their proofs in `Claims.lean`, and concrete instances in
`DerivationWitnesses/Examples.lean`.
-/

namespace TaikoSpec.Derivation

open TaikoSpec Proofs

variable (c : ChainParams) (ctx : ProposalCtx) (p : Parent)

/-! ## 1. Cardinality -/

/-- Every source contributes at least one block and at most
`UNZEN_DERIVATION_SOURCE_MAX_BLOCKS`; a forced inclusion contributes exactly one. -/
theorem source_block_count (src : Source) (payload : Option ByteArray) :
    1 ≤ (sourceBlocks c ctx p src payload).length ∧
      (sourceBlocks c ctx p src payload).length ≤ UNZEN_DERIVATION_SOURCE_MAX_BLOCKS ∧
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

/-! ## 8. Proposer preservation and progress -/

/-- A non-forced source is accepted with exactly its original manifest, preserving every field
and the full ordered transaction-candidate lists, precisely when that manifest validates. -/
theorem proposer_source_accepted_iff (src : Source) (m : Option (List BlockManifest))
    (bs : List BlockManifest) (hf : src.isForcedInclusion = false) :
    finalizeSource c ctx p src m = .accepted bs ↔
      m = some bs ∧ validate c ctx p false bs = true :=
  finalizeSource_nonforced_accepted_iff m bs hf

/-- A proposer's (non-forced) source that keeps its own blocks raises the anchor above the
parent's. -/
theorem proposer_source_advances_anchor (src : Source) (m : Option (List BlockManifest))
    (bs : List BlockManifest) (h : finalizeSource c ctx p src m = .accepted bs)
    (hf : src.isForcedInclusion = false) :
    ∃ b ∈ bs, p.anchorBlockNumber < b.anchorBlockNumber :=
  finalizeSource_progress h hf

/-! ## 9. Forced inclusions -/

/-- A forced inclusion whose manifest is one block has an accepted outcome exactly when
(a) the timestamp window is not used up, (b) the parent's anchor is at most `MAX_ANCHOR_OFFSET`
behind the origin block and not past it, and (c) the parent's gas limit is within its own
bounds. Exact preservation of its transaction candidates is stated separately in
`forced_inclusion_preserves_transactions_iff`. Otherwise it becomes the default block: forced
inclusions *can* be dropped, unlike what `Derivation.md` states. -/
theorem forced_inclusion_accepted_iff (src : Source) (b : BlockManifest)
    (hf : src.isForcedInclusion = true) :
    (finalizeSource c ctx p src (some [b])).isAccepted = true ↔
      lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
      ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
      p.anchorBlockNumber ≤ ctx.originBlockNumber ∧
      (gasBounds (effectiveGasLimit p)).1 ≤ effectiveGasLimit p ∧
      effectiveGasLimit p ≤ (gasBounds (effectiveGasLimit p)).2 :=
  forced_accepted_iff b hf

/-- Accepted one-block forced sources have exactly inherited metadata and retain the entire
original ordered transaction-candidate list. This does not assert candidate execution. -/
theorem forced_inclusion_preserves_transactions_iff (src : Source) (b : BlockManifest)
    (hf : src.isForcedInclusion = true) :
    finalizeSource c ctx p src (some [b]) =
        .accepted [{ defaultBlock c ctx p with transactions := b.transactions }] ↔
      Statements.ForcedAcceptance c ctx p := by
  unfold Statements.ForcedAcceptance
  rw [← forced_inclusion_accepted_iff c ctx p src b hf]
  simp only [finalizeSource, hf, ite_true]
  split <;> simp [SourceOutcome.isAccepted, inherit, defaultBlock]

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

/-- The Rust driver turns a failed extraction into one all-zero block and then inherits it; the
Go driver and this spec use the default block directly. Both give the same blocks. -/
theorem rust_failure_agrees (src : Source) :
    (finalizeSourceRust c ctx p src (some [emptyBlock])).blocks =
      (finalizeSource c ctx p src none).blocks :=
  finalizeSourceRust_failure

/-! ## 11. Unzen header plans -/

/-- Every header plan reserves anchor gas on top of the manifest gas, carries seven bytes of extra
data, and places the system anchor for the block's own anchor number ahead of the manifest's
candidates in their original order. -/
theorem header_plan_layout (hc : HeaderContext) (b : DerivedBlock) :
    Statements.UnzenHeader hc (buildHeader hc b) :=
  buildHeader_unzen hc b

/-- The proposal field of the extra data keeps the proposal ID's low six bytes, so it equals the
proposal ID throughout the uint48 domain. -/
theorem extra_data_proposal_roundtrip (sharing : UInt8) (proposal : Nat)
    (hp : proposal < uint48Limit) :
    decodeExtraDataProposal (encodeExtraData sharing proposal) = some proposal := by
  rw [extraData_proposal, Nat.mod_eq_of_lt hp]

/-- Header plans keep the whole derived sequence, including transactions and forced flags. -/
theorem proposal_headers_preserve_derivation (hc : HeaderContext)
    (sources : List (Source × Option ByteArray)) :
    (deriveHeaders c ctx hc p sources).map (·.block) = deriveSources c ctx p sources :=
  deriveHeaders_blocks hc p sources

/-- After each block's anchor transaction, the Anchor contract's recorded anchor block number
equals that block's anchor number: `anchorV4` stores only greater numbers, and derived anchors
never decrease from the parent's recorded one. -/
theorem anchor_state_follows_derivation (hc : HeaderContext)
    (sources : List (Source × Option ByteArray)) :
    recordedAnchors p.anchorBlockNumber
        ((deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber)) =
      (deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber) :=
  deriveHeaders_recordedAnchors hc p sources

/-- The parent the drivers rebuild after a proposal, from the last header's number, timestamp
and gas limit and from the anchor the Anchor contract recorded, is the parent derivation
continues from. -/
theorem next_parent_from_headers (hc : HeaderContext)
    (sources : List (Source × Option ByteArray)) :
    rebuiltParent p (deriveHeaders c ctx hc p sources) = parentAfter c ctx p sources :=
  deriveHeaders_rebuiltParent hc p sources

/-- The next proposal recovers each block's manifest gas from its header gas limit. -/
theorem header_gas_recovers_manifest_gas (hc : HeaderContext) (b : DerivedBlock)
    (hn : b.number ≠ 0) :
    effectiveGasLimit (headerParent (buildHeader hc b)) = b.gasLimit := by
  simp [effectiveGasLimit, headerParent, buildHeader, hn]

/-- On an Unzen parent every derived block is an Unzen block. The execution engines pick header
rules by each block's own timestamp, so they apply Unzen rules to all of them. -/
theorem blocks_after_unzen (hc : HeaderContext) (sources : List (Source × Option ByteArray))
    (hp : c.unzenForkTime ≤ p.timestamp) :
    ∀ h ∈ deriveHeaders c ctx hc p sources, c.unzenForkTime ≤ h.block.timestamp :=
  deriveHeaders_after_unzen hc p sources hp

end TaikoSpec.Derivation
