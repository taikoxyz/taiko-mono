import TaikoSpec.Proofs.Derive
import TaikoSpec.Proofs.Header

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
    (h₁ : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit c p)
    (h₂ : effectiveGasLimit c p ≤ MAX_BLOCK_GAS_LIMIT) :
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
      (gasBounds (effectiveGasLimit c p)).1 ≤ effectiveGasLimit c p ∧
      effectiveGasLimit c p ≤ (gasBounds (effectiveGasLimit c p)).2 :=
  forced_accepted_iff b hf

/-- When the parent's gas limit is in range (see theorem 7), condition (c) always holds: a
one-block forced inclusion is dropped only when the timestamp window is used up or the parent's
anchor is too far behind (or past) the origin block. -/
theorem forced_inclusion_accepted_iff_of_gas (src : Source) (b : BlockManifest)
    (hf : src.isForcedInclusion = true)
    (h₁ : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit c p)
    (h₂ : effectiveGasLimit c p ≤ MAX_BLOCK_GAS_LIMIT) :
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

/-! ## 11. Checked Etna headers -/

/-- Every successful Etna header has a nonzero root, thirteen extra-data bytes, and exactly the
manifest candidates in their original order, without a system anchor. -/
theorem etna_header_invariants (hc : HeaderContext) (hp : HeaderParent) (b : DerivedBlock)
    (h : HeaderPlan) (etna : isEtna c b.timestamp = true)
    (ok : buildHeader c hc hp b = .ok h) :
    (∃ root, h.beaconRoot = some root ∧ root ≠ 0) ∧ h.extraData.length = 13 ∧
    h.transactions = b.transactions.map TransactionPlanEntry.manifest ∧
    TransactionPlanEntry.systemAnchor ∉ h.transactions :=
  ⟨buildHeader_etna_nonzero etna ok, buildHeader_etna_layout etna ok,
    buildHeader_etna_transactions etna ok⟩

/-- Earlier headers select Unzen's zero root or the pre-Unzen absent root using the child
block's timestamp; they retain the seven-byte layout and prepend one system anchor. -/
theorem pre_etna_header_invariants (hc : HeaderContext) (hp : HeaderParent) (b : DerivedBlock)
    (h : HeaderPlan) (etna : isEtna c b.timestamp = false)
    (ok : buildHeader c hc hp b = .ok h) :
    h.beaconRoot = (if isUnzen c b.timestamp then some 0 else none) ∧
    h.transactions = .systemAnchor :: b.transactions.map TransactionPlanEntry.manifest ∧
    h.extraData.length = 7 := buildHeader_preEtna etna ok

/-- Etna rejects overflowing proposal IDs and anchor numbers instead of truncating them. -/
theorem etna_extra_data_overflow (sharing : UInt8) (proposal anchor : Nat) :
    (uint48Limit ≤ proposal →
      encodeEtnaExtraData sharing proposal anchor = .error .proposalOverflow) ∧
    (proposal < uint48Limit → uint48Limit ≤ anchor →
      encodeEtnaExtraData sharing proposal anchor = .error .anchorOverflow) :=
  ⟨etna_proposal_overflow sharing proposal anchor, etna_anchor_overflow sharing proposal anchor⟩

/-- Both six-byte integer fields round-trip throughout their valid uint48 domain. Non-genesis
anchor decoding requires the Etna layout; genesis instead always reports anchor zero. -/
theorem etna_extra_data_roundtrip (sharing : UInt8) (proposal anchor number : Nat)
    (hp : proposal < uint48Limit) (ha : anchor < uint48Limit) (hn : number ≠ 0) :
    (encodeEtnaExtraData sharing proposal anchor).toOption.bind decodeExtraDataProposal = some proposal ∧
    (encodeEtnaExtraData sharing proposal anchor).toOption.bind
      (decodeEtnaAnchorBlockNumber number) = some anchor :=
  ⟨etna_proposal_roundtrip sharing proposal anchor hp ha,
    etna_anchor_roundtrip sharing proposal anchor number hp ha hn⟩

/-- Header construction retains all derived blocks, including transactions and forced flags.
The next parent's header gas recovers the manifest gas for a non-genesis derived block. -/
theorem header_preserves_derived_block (hc : HeaderContext) (hp : HeaderParent)
    (b : DerivedBlock) (h : HeaderPlan) (hn : b.number ≠ 0)
    (ok : buildHeader c hc hp b = .ok h) :
    h.block = b ∧ effectiveGasLimit c (advanceHeader h).core = b.gasLimit :=
  ⟨(buildHeader_fields ok).1, advanceHeader_manifest_gas hn ok⟩

/-- A successful proposal preserves its entire normalized derived sequence. -/
theorem proposal_headers_preserve_derivation (hc : HeaderContext) (hp : HeaderParent)
    (sources : List (Source × Option ByteArray)) (hs : List HeaderPlan)
    (ok : deriveHeaders c ctx hc hp sources = .ok hs) :
    hs.map (·.block) = deriveSources c ctx hp.core sources := deriveHeaders_blocks ok

/-- Sound available L1 lookups and an initially authenticated Etna parent suffice for all
successful proposal headers, and their final parent, to commit to canonical L1 roots.
A reused anchor need not be available in the executable lookup. -/
theorem proposal_header_roots_authenticated (hc : HeaderContext) (hp : HeaderParent)
    (history : Nat → Root) (sources : List (Source × Option ByteArray)) (hs : List HeaderPlan)
    (lookups : LookupsSound hc history) (initial : ParentCommits c history hp)
    (ok : deriveHeaders c ctx hc hp sources = .ok hs) :
    (∀ h ∈ hs, HeaderCommits c history h) ∧
      ParentCommits c history (hs.foldl (fun _ h => advanceHeader h) hp) :=
  buildHeaders_correspondence lookups initial ok

/-- Authentication of a constructed header is preserved when it becomes the next parent. -/
theorem authenticated_header_advances (history : Nat → Root) (h : HeaderPlan)
    (commitment : HeaderCommits c history h) : ParentCommits c history (advanceHeader h) :=
  advanceHeader_correspondence commitment

/-! ## Witnesses -/

namespace Witness

/-- A devnet proposal at timestamp 2000 whose origin block is 500. -/
def proposal : ProposalCtx :=
  { proposer := ⟨Array.replicate 20 0x99⟩, timestamp := 2000, originBlockNumber := 500 }

/-- Block 10 at timestamp 1900, 31M header gas limit (30M effective), anchor 400. -/
def parent : Parent :=
  { number := 10, timestamp := 1900, gasLimit := 31_000_000, anchorBlockNumber := 400 }

/-- A source with blobs. -/
def source (forced : Bool) : Source :=
  { isForcedInclusion := forced, hasBlobs := true, offset := 0 }

/-- A block without transactions. -/
def block (timestamp anchor gasLimit : Nat) : BlockManifest :=
  { timestamp, coinbase := ⟨Array.replicate 20 0⟩, anchorBlockNumber := anchor, gasLimit,
    transactions := [] }

/-- Theorems 6 and 7: the parent's anchor and gas limit satisfy the preconditions. -/
example : parent.anchorBlockNumber ≤ proposal.originBlockNumber ∧
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit devnet parent ∧
    effectiveGasLimit devnet parent ≤ MAX_BLOCK_GAS_LIMIT := by decide

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

/-- A scheduled Etna fork supplies witnesses on both sides of activation. -/
def etnaChain : ChainParams := { devnet with etnaForkTime := some 2000 }

def etnaParent : Parent :=
  { parent with number := 11, timestamp := 2000, gasLimit := 30_000_000 }

example : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit etnaChain parent ∧
    effectiveGasLimit etnaChain parent ≤ MAX_BLOCK_GAS_LIMIT ∧
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit etnaChain etnaParent ∧
    effectiveGasLimit etnaChain etnaParent ≤ MAX_BLOCK_GAS_LIMIT := by decide

example : (advance etnaChain parent (block 1999 450 30_000_000)).gasLimit = 31_000_000 ∧
    (advance etnaChain parent (block 2000 450 30_000_000)).gasLimit = 30_000_000 := by decide

example : (finalizeSource etnaChain { proposal with timestamp := 2001 } etnaParent
    (source true) (some [block 0 0 0])).isAccepted = true := by decide

/-- Checked header witnesses use a nonzero canonical root with no available lookup. -/
def headerContext : HeaderContext :=
  { baseFeeSharing := 50, proposalId := 7, l1StateRoot := fun _ => none }

def canonicalHistory (_ : Nat) : Root := 17

def headerParent : HeaderParent := { core := etnaParent, beaconRoot := some 17 }

def derivedHeaderBlock : DerivedBlock :=
  { number := 12, timestamp := 2001, coinbase := ⟨Array.replicate 20 0x99⟩,
    anchorBlockNumber := 400, gasLimit := 30_000_000, transactions := [], isForcedInclusion := false }

def headerPlan : HeaderPlan :=
  { block := derivedHeaderBlock, gasLimit := 30_000_000, beaconRoot := some 17,
    extraData := [50, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1, 144], transactions := [] }

example : LookupsSound headerContext canonicalHistory := by
  intro a r lookup
  cases lookup

example : ParentCommits etnaChain canonicalHistory headerParent := by
  intro _ _
  rfl

example : buildHeader etnaChain headerContext headerParent derivedHeaderBlock = .ok headerPlan := rfl

example : derivedHeaderBlock.number ≠ 0 ∧ isEtna etnaChain derivedHeaderBlock.timestamp = true ∧
    7 < uint48Limit ∧ 123456 < uint48Limit := by decide

example : (encodeEtnaExtraData 50 7 123456).toOption.bind (decodeEtnaAnchorBlockNumber 12) =
    some 123456 := by decide

/-- Two finalized defaults inherit the authenticated commitment without any lookup. -/
def headerProposal : ProposalCtx := { proposal with timestamp := 2002 }

def nextHeaderPlan : HeaderPlan :=
  { headerPlan with block := { derivedHeaderBlock with number := 13, timestamp := 2002 } }

example : deriveHeaders etnaChain headerProposal headerContext headerParent
    [(source false, none), (source false, none)] = .ok [headerPlan, nextHeaderPlan] := rfl

example : HeaderCommits etnaChain canonicalHistory headerPlan := by
  intro _
  rfl

example : uint48Limit ≤ 281474976710656 ∧ 7 < uint48Limit ∧
    isEtna etnaChain 1999 = false := by decide

example : buildHeader etnaChain headerContext
    { headerParent with core.timestamp := 1998, core.gasLimit := 31_000_000 }
    { derivedHeaderBlock with timestamp := 1999 } = .ok
    { headerPlan with
      block := { derivedHeaderBlock with timestamp := 1999 }
      gasLimit := 31_000_000
      beaconRoot := some 0
      extraData := [50, 0, 0, 0, 0, 0, 7]
      transactions := [.systemAnchor] } := rfl

end Witness

end TaikoSpec.Derivation
