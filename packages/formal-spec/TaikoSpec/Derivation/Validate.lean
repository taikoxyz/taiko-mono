import TaikoSpec.Derivation.Params
import TaikoSpec.Derivation.Types

/-!
# Metadata validation, inheritance and the default source

A source's blocks are validated against the parent block. A forced inclusion first inherits
its timestamp, coinbase, anchor and gas limit. A source that fails validation, or has no
manifest, becomes one default block with inherited metadata and no transactions.
-/

namespace TaikoSpec.Derivation

variable (c : ChainParams) (ctx : ProposalCtx)

/-- The earliest timestamp allowed after a block with timestamp `prev`:
`max(prev + 1, proposal.timestamp - TIMESTAMP_MAX_OFFSET, SHASTA_FORK_TIME)`. Subtraction
truncates at zero, which matches the clients' "only when the proposal timestamp exceeds the
offset" branch. -/
def lowerBound (prev : Nat) : Nat :=
  max (prev + 1) (max (ctx.timestamp - c.timestampMaxOffset) c.shastaForkTime)

/-- The allowed gas limits after a block with gas limit `parent`: within ±0.02% of it,
never above `MAX_BLOCK_GAS_LIMIT`, and not below `MIN_BLOCK_GAS_LIMIT` unless the upper bound
is. Returns `(lower, upper)`. -/
def gasBounds (parent : Nat) : Nat × Nat :=
  let upper := min
    (parent * (GAS_LIMIT_DENOMINATOR + BLOCK_GAS_LIMIT_MAX_CHANGE) / GAS_LIMIT_DENOMINATOR)
    MAX_BLOCK_GAS_LIMIT
  let lower := min
    (max (parent * (GAS_LIMIT_DENOMINATOR - BLOCK_GAS_LIMIT_MAX_CHANGE) / GAS_LIMIT_DENOMINATOR)
      MIN_BLOCK_GAS_LIMIT)
    upper
  (lower, upper)

/-- The parent's gas limit without the anchor gas that every non-genesis header includes.
Subtraction truncates at zero; a non-genesis header always has at least `ANCHOR_GAS_LIMIT`. -/
def effectiveGasLimit (p : Parent) : Nat :=
  if p.number = 0 then p.gasLimit else p.gasLimit - ANCHOR_GAS_LIMIT

/-- Each timestamp is in `[lowerBound prev, proposal.timestamp]`, where `prev` is the previous
block's timestamp (the parent's for the first block). -/
def timestampsValid : Nat → List BlockManifest → Bool
  | _, [] => true
  | prev, b :: bs =>
    lowerBound c ctx prev ≤ b.timestamp && b.timestamp ≤ ctx.timestamp &&
      timestampsValid b.timestamp bs

/-- Each anchor is at least the previous one (the parent's for the first block), at most the
origin block, and at least `origin - MAX_ANCHOR_OFFSET`. -/
def anchorsValid : Nat → List BlockManifest → Bool
  | _, [] => true
  | prev, b :: bs =>
    prev ≤ b.anchorBlockNumber && b.anchorBlockNumber ≤ ctx.originBlockNumber &&
      ctx.originBlockNumber - c.maxAnchorOffset ≤ b.anchorBlockNumber &&
      anchorsValid b.anchorBlockNumber bs

/-- Each gas limit is within `gasBounds` of the previous one (the parent's effective gas limit
for the first block). -/
def gasLimitsValid : Nat → List BlockManifest → Bool
  | _, [] => true
  | prev, b :: bs =>
    (gasBounds prev).1 ≤ b.gasLimit && b.gasLimit ≤ (gasBounds prev).2 &&
      gasLimitsValid b.gasLimit bs

/-- A source's blocks are valid when there is at least one, their timestamps, anchors and gas
limits are in bounds, and, unless the source is a forced inclusion, some block raises the
anchor above the parent's. -/
def validate (p : Parent) (forced : Bool) (bs : List BlockManifest) : Bool :=
  !bs.isEmpty && timestampsValid c ctx p.timestamp bs &&
    anchorsValid c ctx p.anchorBlockNumber bs &&
    (forced || bs.any fun b => p.anchorBlockNumber < b.anchorBlockNumber) &&
    gasLimitsValid (effectiveGasLimit p) bs

/-- Overwrites each block's metadata with inherited values: the smallest allowed timestamp, the
proposer as coinbase, the parent's anchor and the parent's effective gas limit. Transactions
are kept. -/
def inherit (p : Parent) : Nat → List BlockManifest → List BlockManifest
  | _, [] => []
  | prev, b :: bs =>
    let timestamp := lowerBound c ctx prev
    { b with
      timestamp
      coinbase := ctx.proposer
      anchorBlockNumber := p.anchorBlockNumber
      gasLimit := effectiveGasLimit p } :: inherit p timestamp bs

/-- The default source's single block: inherited metadata and no transactions. -/
def defaultBlock (p : Parent) : BlockManifest where
  timestamp := lowerBound c ctx p.timestamp
  coinbase := ctx.proposer
  anchorBlockNumber := p.anchorBlockNumber
  gasLimit := effectiveGasLimit p
  transactions := []

/-- Finalizes a source given its extracted manifest (`none` = default manifest). A forced
inclusion inherits its metadata before validation; a source that fails validation becomes the
default block. -/
def finalizeSource (p : Parent) (src : Source) : Option (List BlockManifest) → SourceOutcome
  | none => .defaulted (defaultBlock c ctx p)
  | some bs =>
    let bs := if src.isForcedInclusion then inherit c ctx p p.timestamp bs else bs
    if validate c ctx p src.isForcedInclusion bs then .accepted bs
    else .defaulted (defaultBlock c ctx p)

end TaikoSpec.Derivation
