import DerivationWitnesses.Tests.Helpers
import DerivationModel.Derivation.Validate

/-!
# Validation tests

Ported from the Rust driver's `validation.rs` tests and the Go driver's source fetcher tests.
-/

open TaikoSpec TaikoSpec.Derivation Tests

/-- Hoodi with Shasta active from genesis, as the Rust tests assume. -/
def hoodi0 : ChainParams := { hoodi with shastaForkTime := 0 }

/-- A proposal at `timestamp` whose origin block is `origin`. -/
def ctx (timestamp origin : Nat) : ProposalCtx :=
  { proposer := addr 0x99, timestamp, originBlockNumber := origin }

/-- A non-genesis parent at timestamp 1000 with a 30M effective gas limit. -/
def parentWithAnchor (anchor : Nat) : Parent :=
  { number := 2, timestamp := 1000, gasLimit := 31_000_000, anchorBlockNumber := anchor }

-- Timestamps must be in [lowerBound parent, proposal timestamp].
example : (!timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 2100 0 0]) = true := by decide
example : (!timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 1000 0 0]) = true := by decide
example : (timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 1006 0 0]) = true := by decide
-- The lower bound respects the fork time and each chain's offset window.
example : (lowerBound { hoodi with shastaForkTime := 1500 } (ctx 2000 0) 1000 == 1500) = true := by decide
example : (lowerBound { hoodi with shastaForkTime := 1200 } (ctx 1100 0) 1000 == 1200) = true := by decide
example : (lowerBound hoodi0 (ctx 10000 0) 100 == 8464) = true := by decide
example : (lowerBound { mainnet with shastaForkTime := 0 } (ctx 10000 0) 100 == 3856) = true := by decide

-- Anchors: no regression and not past the origin; a proposer source must raise the anchor.
example : (!validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 50 30_000_000]) = true := by decide
example : (validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 80 30_000_000]) = true := by decide
example : (!validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 101 30_000_000]) = true := by decide
example : (!validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 60 30_000_000]) = true := by decide
example : (validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) true [blk 1001 60 30_000_000]) = true := by decide
-- An anchor more than MAX_ANCHOR_OFFSET (128 on Hoodi) behind the origin fails, even forced.
example : (validate hoodi0 (ctx 1010 1000) (parentWithAnchor 872) true [blk 1001 872 30_000_000]) = true := by decide
example : (!validate hoodi0 (ctx 1010 1000) (parentWithAnchor 871) true [blk 1001 871 30_000_000]) = true := by decide

/-- A parent at height `number` with a 30M header gas limit. -/
def parentAtHeight (number : Nat) : Parent :=
  { number, timestamp := 0, gasLimit := 30_000_000, anchorBlockNumber := 0 }

-- Before Etna, the parent's effective limit drops anchor gas unless it is genesis.
example : (effectiveGasLimit devnet (parentAtHeight 1) == 29_000_000) = true := by decide
example : (effectiveGasLimit devnet (parentAtHeight 0) == 30_000_000) = true := by decide
example : (gasBounds 29_000_000 == (28_994_200, 29_005_800)) = true := by decide
example : (gasBounds 45_000_000 == (44_991_000, 45_000_000)) = true := by decide
example : (gasBounds 10_000_000 == (10_000_000, 10_002_000)) = true := by decide
example : (!gasLimitsValid 29_000_000 [blk 0 0 60_000_000]) = true := by decide
example : (!gasLimitsValid 29_000_000 [blk 0 0 0]) = true := by decide
example : (gasLimitsValid 29_000_000 [blk 0 0 29_000_000]) = true := by decide

-- An empty manifest, or a block that repeats the parent timestamp, fails validation.
example : (!validate hoodi0 (ctx 1010 1000) (parentWithAnchor 0) false []) = true := by decide
example : (!validate hoodi0 (ctx 1010 1000) (parentWithAnchor 0) false [blk 1000 0 0]) = true := by decide

-- Inheritance: proposer as coinbase, the parent's anchor and effective gas limit, and
-- timestamps that advance from the lower bound.
example : (fields (inherit { hoodi with shastaForkTime := 1500 } (ctx 2000 0)
  { number := 10, timestamp := 1000, gasLimit := 30_000_000, anchorBlockNumber := 900 } 1000
  [blk 0 0 0, blk 0 0 0]) == [(1500, 900, 29_000_000), (1501, 900, 29_000_000)]) = true := by decide

-- The default block on a genesis parent (Go `TestManifestVectorsInheritedMetadata`).
example : (
  let b := defaultBlock devnet (ctx 101 0)
    { number := 0, timestamp := 100, gasLimit := 10_000_000, anchorBlockNumber := 4 }
  (b.timestamp, b.anchorBlockNumber, b.gasLimit, b.transactions.length, b.coinbase == addr 0x99)
    == (101, 4, 10_000_000, 0, true)) = true := by decide

namespace EtnaValidation

/-- Etna activates at timestamp 2000; Unzen remains active from genesis. -/
def etnaChain : ChainParams := { devnet with etnaForkTime := some 2000 }

/-- The final pre-Etna parent includes the 1M anchor reserve. -/
def unzenParent : Parent :=
  { number := 10, timestamp := 1999, gasLimit := 31_000_000, anchorBlockNumber := 400 }

/-- An Etna parent has a 30M header and manifest gas limit. -/
def etnaParent : Parent :=
  { unzenParent with number := 11, timestamp := 2000, gasLimit := 30_000_000 }

-- Etna removes the unconditional 1M subtraction from non-genesis parents.
example : (effectiveGasLimit etnaChain { parentAtHeight 1 with timestamp := 2000 } == 30_000_000) = true := by decide
-- Parent timestamp, rather than proposal time, selects the gas basis.
example : (effectiveGasLimit etnaChain unzenParent == 30_000_000) = true := by decide
example : (effectiveGasLimit etnaChain etnaParent == 30_000_000) = true := by decide
example : (effectiveGasLimit etnaChain { etnaParent with number := 0 } == 30_000_000) = true := by decide
example : (validate etnaChain (ctx 2001 500) etnaParent false [blk 2001 450 30_000_000]) = true := by decide
example : (!validate etnaChain (ctx 2001 500) etnaParent false [blk 2001 450 29_000_000]) = true := by decide
-- Inclusive fork boundaries and an unscheduled fork preserve pre-Etna behavior.
example : (!isEtna etnaChain 1999) = true := by decide
example : (isEtna etnaChain 2000) = true := by decide
example : (anchorGasReserve etnaChain 1999 == 1_000_000) = true := by decide
example : (anchorGasReserve etnaChain 2000 == 0) = true := by decide
example : (!isEtna devnet 2000) = true := by decide
example : (maxBlocks etnaChain 1999 == UNZEN_DERIVATION_SOURCE_MAX_BLOCKS) = true := by decide
example : (maxBlocks { devnet with unzenForkTime := some 2000 } 1999 == DERIVATION_SOURCE_MAX_BLOCKS) = true := by decide
example : (maxBlocks { devnet with unzenForkTime := some 2000 } 2000 == UNZEN_DERIVATION_SOURCE_MAX_BLOCKS) = true := by decide
example : (maxBlocks { devnet with unzenForkTime := none } 2000 == DERIVATION_SOURCE_MAX_BLOCKS) = true := by decide

end EtnaValidation
