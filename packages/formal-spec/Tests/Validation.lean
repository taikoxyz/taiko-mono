import Tests.Helpers
import TaikoSpec.Derivation.Validate

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
#guard !timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 2100 0 0]
#guard !timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 1000 0 0]
#guard timestampsValid hoodi0 (ctx 2000 0) 1000 [blk 1006 0 0]
-- The lower bound respects the fork time and each chain's offset window.
#guard lowerBound { hoodi with shastaForkTime := 1500 } (ctx 2000 0) 1000 == 1500
#guard lowerBound { hoodi with shastaForkTime := 1200 } (ctx 1100 0) 1000 == 1200
#guard lowerBound hoodi0 (ctx 10000 0) 100 == 8464
#guard lowerBound { mainnet with shastaForkTime := 0 } (ctx 10000 0) 100 == 3856

-- Anchors: no regression and not past the origin; a proposer source must raise the anchor.
#guard !validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 50 30_000_000]
#guard validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 80 30_000_000]
#guard !validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 101 30_000_000]
#guard !validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) false [blk 1001 60 30_000_000]
#guard validate hoodi0 (ctx 1010 100) (parentWithAnchor 60) true [blk 1001 60 30_000_000]
-- An anchor more than MAX_ANCHOR_OFFSET (128 on Hoodi) behind the origin fails, even forced.
#guard validate hoodi0 (ctx 1010 1000) (parentWithAnchor 872) true [blk 1001 872 30_000_000]
#guard !validate hoodi0 (ctx 1010 1000) (parentWithAnchor 871) true [blk 1001 871 30_000_000]

/-- A parent at height `number` with a 30M header gas limit. -/
def parentAtHeight (number : Nat) : Parent :=
  { number, timestamp := 0, gasLimit := 30_000_000, anchorBlockNumber := 0 }

-- Before Etna, the parent's effective limit drops anchor gas unless it is genesis.
#guard effectiveGasLimit devnet (parentAtHeight 1) == 29_000_000
#guard effectiveGasLimit devnet (parentAtHeight 0) == 30_000_000
#guard gasBounds 29_000_000 == (28_994_200, 29_005_800)
#guard gasBounds 45_000_000 == (44_991_000, 45_000_000)
#guard gasBounds 10_000_000 == (10_000_000, 10_002_000)
#guard !gasLimitsValid 29_000_000 [blk 0 0 60_000_000]
#guard !gasLimitsValid 29_000_000 [blk 0 0 0]
#guard gasLimitsValid 29_000_000 [blk 0 0 29_000_000]

-- An empty manifest, or a block that repeats the parent timestamp, fails validation.
#guard !validate hoodi0 (ctx 1010 1000) (parentWithAnchor 0) false []
#guard !validate hoodi0 (ctx 1010 1000) (parentWithAnchor 0) false [blk 1000 0 0]

-- Inheritance: proposer as coinbase, the parent's anchor and effective gas limit, and
-- timestamps that advance from the lower bound.
#guard fields (inherit { hoodi with shastaForkTime := 1500 } (ctx 2000 0)
  { number := 10, timestamp := 1000, gasLimit := 30_000_000, anchorBlockNumber := 900 } 1000
  [blk 0 0 0, blk 0 0 0]) == [(1500, 900, 29_000_000), (1501, 900, 29_000_000)]

-- The default block on a genesis parent (Go `TestManifestVectorsInheritedMetadata`).
#guard
  let b := defaultBlock devnet (ctx 101 0)
    { number := 0, timestamp := 100, gasLimit := 10_000_000, anchorBlockNumber := 4 }
  (b.timestamp, b.anchorBlockNumber, b.gasLimit, b.transactions.length, b.coinbase == addr 0x99)
    == (101, 4, 10_000_000, 0, true)

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
#guard effectiveGasLimit etnaChain { parentAtHeight 1 with timestamp := 2000 } == 30_000_000
-- Parent timestamp, rather than proposal time, selects the gas basis.
#guard effectiveGasLimit etnaChain unzenParent == 30_000_000
#guard effectiveGasLimit etnaChain etnaParent == 30_000_000
#guard effectiveGasLimit etnaChain { etnaParent with number := 0 } == 30_000_000
#guard validate etnaChain (ctx 2001 500) etnaParent false [blk 2001 450 30_000_000]
#guard !validate etnaChain (ctx 2001 500) etnaParent false [blk 2001 450 29_000_000]
-- Inclusive fork boundaries and an unscheduled fork preserve pre-Etna behavior.
#guard !isEtna etnaChain 1999
#guard isEtna etnaChain 2000
#guard anchorGasReserve etnaChain 1999 == 1_000_000
#guard anchorGasReserve etnaChain 2000 == 0
#guard !isEtna devnet 2000
#guard maxBlocks etnaChain 1999 == UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
#guard maxBlocks { devnet with unzenForkTime := some 2000 } 1999 == DERIVATION_SOURCE_MAX_BLOCKS
#guard maxBlocks { devnet with unzenForkTime := some 2000 } 2000 == UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
#guard maxBlocks { devnet with unzenForkTime := none } 2000 == DERIVATION_SOURCE_MAX_BLOCKS

end EtnaValidation
