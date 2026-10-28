import DerivationStatements.Authentication

/-!
# Reviewable derivation claims

These propositions describe normalized source derivation and checked header construction.
They do not assume availability of every L1 root, nor claim transaction execution, eventual
forced inclusion, or security of the consensus/proof system. All parameters range over the
executable model; chain-configuration authenticity is outside these claims.
-/
namespace TaikoSpec.Derivation.Statements

/-- The initial bounds needed only for upper-bounded anchors and in-range manifest gas.
No bound is needed for the unconditional sequence and source-isolation properties. -/
structure InitialParentBounds (c : ChainParams) (ctx : ProposalCtx) (p : Parent) : Prop where
  /-- The parent's anchor does not lie beyond this proposal's L1 origin. -/
  anchorNotAfterOrigin : p.anchorBlockNumber ≤ ctx.originBlockNumber
  /-- The parent's effective (manifest) gas is at least the protocol minimum. -/
  gasMinimum : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit c p
  /-- The parent's effective (manifest) gas is at most the protocol maximum. -/
  gasMaximum : effectiveGasLimit c p ≤ MAX_BLOCK_GAS_LIMIT

/-- Available lookups and an inherited non-genesis Etna commitment must be authenticated
against the same canonical history. Unavailable lookups are allowed: construction can fail,
and a reused anchor does not need a lookup. Genesis does not authenticate a parent root. -/
structure HeaderPremises (c : ChainParams) (hc : HeaderContext) (hp : HeaderParent)
    (history : Nat → Root) : Prop where
  lookupsSound : LookupsSound hc history
  parentAuthenticated : ParentCommits c history hp

/-- Source bounds and isolation, consecutive numbers, increasing timestamps with bounded
fallback drift, monotone anchors, and (under initial parent bounds) bounded anchors and gas.
The cardinality clause includes the exact one-block bound for forced sources. -/
def DerivationSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (p : Parent),
    (∀ src payload,
      1 ≤ (sourceBlocks c ctx p src payload).length ∧
      (sourceBlocks c ctx p src payload).length ≤ maxBlocks c ctx.timestamp ∧
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
    (InitialParentBounds c ctx p → ∀ sources, ∀ b ∈ deriveSources c ctx p sources,
      b.anchorBlockNumber ≤ ctx.originBlockNumber ∧
      MIN_BLOCK_GAS_LIMIT ≤ b.gasLimit ∧ b.gasLimit ≤ MAX_BLOCK_GAS_LIMIT)

/-- The fork policy of one returned header, expressed using its own child block timestamp.
Etna retains exactly the candidate order and has no system anchor. Earlier forks prepend
one system anchor and choose Unzen's zero root or the pre-Unzen absent root. -/
def HeaderForkPolicy (c : ChainParams) (h : HeaderPlan) : Prop :=
  (isEtna c h.block.timestamp = true →
    (∃ root, h.beaconRoot = some root ∧ root ≠ 0) ∧ h.extraData.length = 13 ∧
    h.transactions = h.block.transactions.map TransactionPlanEntry.manifest ∧
    TransactionPlanEntry.systemAnchor ∉ h.transactions) ∧
  (isEtna c h.block.timestamp = false →
    h.beaconRoot = (if isUnzen c h.block.timestamp then some 0 else none) ∧
    h.transactions = .systemAnchor :: h.block.transactions.map TransactionPlanEntry.manifest ∧
    h.extraData.length = 7)

/-- Every successful proposal preserves the whole derived sequence and applies the child's
fork policy to every returned header. Under authenticated inputs all Etna commitments and the
final rolling parent agree with canonical L1 history. The first two conclusions do not need
those authentication premises. This is a safety statement, not a guarantee of success. -/
def HeaderSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (hc : HeaderContext) (hp : HeaderParent)
    (sources : List (Source × Option ByteArray)) (hs : List HeaderPlan),
    deriveHeaders c ctx hc hp sources = .ok hs →
      hs.map (·.block) = deriveSources c ctx hp.core sources ∧
      (∀ h ∈ hs, HeaderForkPolicy c h) ∧
      (∀ history, HeaderPremises c hc hp history →
        (∀ h ∈ hs, HeaderCommits c history h) ∧
        ParentCommits c history (hs.foldl (fun _ h => advanceHeader h) hp))

/-- Exact validity condition for the inherited metadata of a one-block forced manifest.
An exhausted timestamp window, stale/future anchor, or out-of-bounds inherited gas can cause
fallback. Forced-source metadata is inherited; its original metadata is not this condition. -/
def ForcedAcceptance (c : ChainParams) (ctx : ProposalCtx) (p : Parent) : Prop :=
  lowerBound c ctx p.timestamp ≤ ctx.timestamp ∧
  ctx.originBlockNumber - c.maxAnchorOffset ≤ p.anchorBlockNumber ∧
  p.anchorBlockNumber ≤ ctx.originBlockNumber ∧
  (gasBounds (effectiveGasLimit c p)).1 ≤ effectiveGasLimit c p ∧
  effectiveGasLimit c p ≤ (gasBounds (effectiveGasLimit c p)).2

/-- A one-block forced manifest is accepted exactly under `ForcedAcceptance`, and otherwise
becomes the precise empty default block. Missing manifests also default. Later sources cannot
alter the earlier prefix, including forced sources placed before the proposer by the inbox.
No deadline or eventual inclusion conclusion is asserted. -/
def ForcedInclusionSafety : Prop :=
  ∀ (c : ChainParams) (ctx : ProposalCtx) (p : Parent),
    (∀ (src : Source) (b : BlockManifest), src.isForcedInclusion = true →
      ((finalizeSource c ctx p src (some [b])).isAccepted = true ↔ ForcedAcceptance c ctx p) ∧
      (finalizeSource c ctx p src (some [b]) = .defaulted (defaultBlock c ctx p) ↔
        ¬ ForcedAcceptance c ctx p)) ∧
    (∀ src, finalizeSource c ctx p src none = .defaulted (defaultBlock c ctx p)) ∧
    (∀ xs ys,
      (deriveSources c ctx p (xs ++ ys)).take (deriveSources c ctx p xs).length =
        deriveSources c ctx p xs)

/-- The three headline safety claims; detailed stronger properties remain separately available. -/
def Claims : Prop := DerivationSafety ∧ HeaderSafety ∧ ForcedInclusionSafety

end TaikoSpec.Derivation.Statements
