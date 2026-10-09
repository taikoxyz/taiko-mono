import Tests.Helpers
import TaikoSpec.Derivation.Derive

/-!
# Derivation tests

Whole proposals: sources in order, each building on the previous source's last block.
-/

open TaikoSpec TaikoSpec.Derivation Tests

/-- A proposal at timestamp 2000 whose origin block is 500. -/
def proposal : ProposalCtx := { proposer := addr 0x99, timestamp := 2000, originBlockNumber := 500 }

/-- A non-genesis parent: block 10 at timestamp 1900, 30M effective gas limit, anchor 400. -/
def parent : Parent :=
  { number := 10, timestamp := 1900, gasLimit := 31_000_000, anchorBlockNumber := 400 }

/-- Number, timestamp, anchor, gas limit and forced flag of each derived block. -/
def summary (bs : List DerivedBlock) : List (Nat × Nat × Nat × Nat × Bool) :=
  bs.map fun b => (b.number, b.timestamp, b.anchorBlockNumber, b.gasLimit, b.isForcedInclusion)

/-- A forced inclusion; its metadata is inherited. -/
def forcedSource : Source × Option ByteArray := (src (forced := true), some (payloadOf [blk 0 0 0]))

/-- A valid proposer source with two blocks. -/
def proposerSource : Source × Option ByteArray :=
  (src, some (payloadOf [blk 1950 450 30_000_000, blk 1960 460 30_000_000]))

/-- A proposer source that does not raise the anchor. -/
def staleProposerSource : Source × Option ByteArray :=
  (src, some (payloadOf [blk 1950 400 30_000_000]))

-- The forced inclusion inherits; the proposer's blocks follow it with consecutive numbers.
#guard summary (deriveSources devnet proposal parent [forcedSource, proposerSource]) ==
  [(11, 1901, 400, 30_000_000, true), (12, 1950, 450, 30_000_000, false),
    (13, 1960, 460, 30_000_000, false)]
-- A proposer source that fails validation becomes one default block.
#guard summary (deriveSources devnet proposal parent [forcedSource, staleProposerSource]) ==
  [(11, 1901, 400, 30_000_000, true), (12, 1902, 400, 30_000_000, false)]
-- An undecodable forced inclusion becomes one default block.
#guard summary (deriveSources devnet proposal parent [(src (forced := true), none)]) ==
  [(11, 1901, 400, 30_000_000, true)]
/-- A well-formed legacy transfer: nonce 0, gas price 1, 21000 gas, value 0, v = 27. -/
def transfer : Rlp.Item :=
  .list [.bytes ⟨#[]⟩, .bytes ⟨#[1]⟩, .bytes ⟨#[0x52, 0x08]⟩, .bytes (addr 0x42), .bytes ⟨#[]⟩,
    .bytes ⟨#[]⟩, .bytes ⟨#[27]⟩, .bytes ⟨#[1]⟩, .bytes ⟨#[1]⟩]

/-- A forced inclusion carrying `transfer`. -/
def forcedTransfer : Source × Option ByteArray :=
  (src (forced := true), some (payloadOf [{ blk 0 0 0 with transactions := [transfer] }]))

-- A forced inclusion keeps its transaction while the parent's anchor (400) is at most 128 blocks
-- behind the origin, and becomes a default block without transactions once it is 129 behind.
#guard (deriveSources devnet { proposal with originBlockNumber := 528 } parent
  [forcedTransfer]).map (·.transactions.length) == [1]
#guard (deriveSources devnet { proposal with originBlockNumber := 529 } parent
  [forcedTransfer]).map (·.transactions.length) == [0]
