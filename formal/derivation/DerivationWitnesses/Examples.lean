import DerivationProofs

namespace TaikoSpec.Derivation
open TaikoSpec Proofs

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

/-- The initial parent bounds hold, so the bounded-anchor and gas conclusions are not vacuous. -/
example : Statements.InitialParentBounds proposal parent :=
  ⟨by decide, by decide, by decide⟩

/-- A two-source proposal on an Unzen parent: an inherited forced inclusion and a defaulted
proposer source give two headers with the Unzen layout. -/
def headerContext : HeaderContext := { baseFeeSharing := 100, proposalId := 7 }

def twoSources : List (Source × Option ByteArray) := [(source true, none), (source false, none)]

example : (deriveHeaders devnet proposal headerContext parent twoSources).map
    (fun h => (h.block.number, h.block.timestamp, h.block.anchorBlockNumber, h.gasLimit,
      h.extraData)) =
    [(11, 1901, 400, 31_000_000, [100, 0, 0, 0, 0, 0, 7]),
      (12, 1902, 400, 31_000_000, [100, 0, 0, 0, 0, 0, 7])] := by decide

/-- The parent rebuilt after the second header. -/
example :
    let q := rebuiltParent parent (deriveHeaders devnet proposal headerContext parent twoSources)
    (q.number, q.timestamp, q.gasLimit, q.anchorBlockNumber) = (12, 1902, 31_000_000, 400) := by
  decide

end Witness

end TaikoSpec.Derivation
