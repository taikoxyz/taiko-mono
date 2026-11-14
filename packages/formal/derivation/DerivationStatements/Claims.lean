import DerivationModel

/-!
# Reviewable derivation claims

These propositions describe Unzen source derivation and pre-execution header plans. They do not
claim transaction execution, eventual forced inclusion, or security of the consensus/proof
system. All parameters range over the executable model; chain-configuration authenticity and the
authenticity of L1 inputs are outside these claims.
-/
namespace TaikoSpec.Derivation.Statements

/-- The initial bounds needed only for upper-bounded anchors and in-range manifest gas.
No bound is needed for the unconditional sequence and source-isolation properties. -/
structure InitialParentBounds (ctx : ProposalCtx) (p : Parent) : Prop where
  /-- The parent's anchor does not lie beyond this proposal's L1 origin. -/
  anchorNotAfterOrigin : p.anchorBlockNumber ≤ ctx.originBlockNumber
  /-- The parent's effective (manifest) gas is at least the protocol minimum. -/
  gasMinimum : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit p
  /-- The parent's effective (manifest) gas is at most the protocol maximum. -/
  gasMaximum : effectiveGasLimit p ≤ MAX_BLOCK_GAS_LIMIT

/-- Source bounds and isolation, consecutive numbers, increasing timestamps with bounded
fallback drift, monotone anchors, and (under initial parent bounds) bounded anchors and gas.
The cardinality clause includes the exact one-block bound for forced sources. A non-forced
source is accepted with precisely its input manifest when that manifest passes validation;
this preserves every metadata field and transaction candidate in its original order. -/
def DerivationSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (p : Parent),
    (∀ src payload,
      1 ≤ (sourceBlocks c ctx p src payload).length ∧
      (sourceBlocks c ctx p src payload).length ≤ UNZEN_DERIVATION_SOURCE_MAX_BLOCKS ∧
      (src.isForcedInclusion = true → (sourceBlocks c ctx p src payload).length = 1)) ∧
    (∀ xs ys,
      deriveSources c ctx p (xs ++ ys) =
        deriveSources c ctx p xs ++ deriveSources c ctx (parentAfter c ctx p xs) ys ∧
      (deriveSources c ctx p (xs ++ ys)).take (deriveSources c ctx p xs).length =
        deriveSources c ctx p xs) ∧
    (∀ sources,
      Chain (fun a b => b = a + 1) p.number ((deriveSources c ctx p sources).map (·.number)) ∧
      Chain (· < ·) p.timestamp ((deriveSources c ctx p sources).map (·.timestamp)) ∧
      (∀ i (hi : i < (deriveSources c ctx p sources).length),
        (deriveSources c ctx p sources)[i].timestamp ≤
          max ctx.timestamp (max p.timestamp c.shastaForkTime) + i + 1) ∧
      Chain (· ≤ ·) p.anchorBlockNumber
        ((deriveSources c ctx p sources).map (·.anchorBlockNumber))) ∧
    (InitialParentBounds ctx p → ∀ sources, ∀ b ∈ deriveSources c ctx p sources,
      b.anchorBlockNumber ≤ ctx.originBlockNumber ∧
      MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT) ∧
    (∀ (src : Source) (m : Option (List BlockManifest)) (bs : List BlockManifest),
      src.isForcedInclusion = false →
      (finalizeSource c ctx p src m = .accepted bs ↔
        m = some bs ∧ validate c ctx p false bs = true))

/-- The driver-derived fields of one Unzen header plan: the anchor gas reserve on top of the
manifest gas, seven bytes of extra data holding the sharing percentage and the proposal's low six
bytes, and the system anchor for the block's own anchor number ahead of the manifest's
candidates in their original order. -/
def UnzenHeader (hc : HeaderContext) (h : HeaderPlan) : Prop :=
  h.gasLimit = h.block.gasLimit + ANCHOR_GAS_LIMIT ∧
  h.extraData.length = 7 ∧
  h.extraData.head? = some hc.baseFeeSharing ∧
  decodeExtraDataProposal h.extraData = some (hc.proposalId % uint48Limit) ∧
  h.transactions =
    .anchor h.block.anchorBlockNumber :: h.block.transactions.map TransactionPlanEntry.manifest

/-- Header plans preserve the derived sequence and have the Unzen layout. Each anchor
transaction leaves the Anchor contract's recorded anchor equal to its block's anchor number, and
the parent rebuilt from the last header and the recorded anchor is exactly the parent derivation
continues from. With an Unzen parent, every planned block is an Unzen block. -/
def HeaderSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (hc : HeaderContext) (p : Parent)
    (sources : List (Source × Option ByteArray)),
    (deriveHeaders c ctx hc p sources).map (·.block) = deriveSources c ctx p sources ∧
    (∀ h ∈ deriveHeaders c ctx hc p sources, UnzenHeader hc h) ∧
    recordedAnchors p.anchorBlockNumber
        ((deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber)) =
      (deriveHeaders c ctx hc p sources).map (·.block.anchorBlockNumber) ∧
    rebuiltParent p (deriveHeaders c ctx hc p sources) = parentAfter c ctx p sources ∧
    (c.unzenForkTime ≤ p.timestamp →
      ∀ h ∈ deriveHeaders c ctx hc p sources, c.unzenForkTime ≤ h.block.timestamp)

/-- Exact validity condition for the inherited metadata of a one-block forced manifest.
An exhausted timestamp window, stale/future anchor, or out-of-bounds inherited gas can cause
fallback. Forced-source metadata is inherited; its original metadata is not this condition. -/
def ForcedAcceptance (c : ChainParams) (ctx : ProposalCtx) (p : Parent) : Prop :=
  lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
  ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
  p.anchorBlockNumber ≤ ctx.originBlockNumber ∧
  (gasBounds (effectiveGasLimit p)).1 ≤ effectiveGasLimit p ∧
  effectiveGasLimit p ≤ (gasBounds (effectiveGasLimit p)).2

/-- A one-block forced manifest is accepted exactly under `ForcedAcceptance`, with inherited
metadata and precisely its original transaction candidates in their original order; otherwise
it becomes the precise empty default block. Missing manifests also default. Later sources
cannot alter the earlier prefix, including forced sources placed before the proposer by the
inbox. Candidate preservation is pre-execution; no execution, deadline, or eventual inclusion
conclusion is asserted. -/
def ForcedInclusionSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (p : Parent),
    (∀ (src : Source) (b : BlockManifest), src.isForcedInclusion = true →
      ((finalizeSource c ctx p src (some [b])).isAccepted = true ↔ ForcedAcceptance c ctx p) ∧
      (finalizeSource c ctx p src (some [b]) =
          .accepted [{ defaultBlock c ctx p with transactions := b.transactions }] ↔
        ForcedAcceptance c ctx p) ∧
      (finalizeSource c ctx p src (some [b]) = .defaulted (defaultBlock c ctx p) ↔
        ¬ ForcedAcceptance c ctx p)) ∧
    (∀ src, finalizeSource c ctx p src none = .defaulted (defaultBlock c ctx p)) ∧
    (∀ xs ys,
      (deriveSources c ctx p (xs ++ ys)).take (deriveSources c ctx p xs).length =
        deriveSources c ctx p xs)

/-- The three headline safety claims; detailed stronger properties remain separately available. -/
def Claims : Prop := DerivationSafety ∧ HeaderSafety ∧ ForcedInclusionSafety

end TaikoSpec.Derivation.Statements
