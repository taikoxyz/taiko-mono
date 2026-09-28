import TaikoSpec.Rlp

/-!
# Derivation inputs and outputs
-/

namespace TaikoSpec.Derivation

/-- One entry of the `Proposed` event's `sources`, reduced to what derivation reads. -/
structure Source where
  /-- `DerivationSource.isForcedInclusion`. -/
  isForcedInclusion : Bool
  /-- Whether `blobSlice.blobHashes` is non-empty. -/
  hasBlobs : Bool
  /-- `blobSlice.offset`. -/
  offset : Nat

/-- Proposal-level inputs, read from the `Proposed` event and its L1 block. -/
structure ProposalCtx where
  /-- `Proposed.proposer`, a 20-byte address. -/
  proposer : ByteArray
  /-- Timestamp of the L1 block that emitted `Proposed`. -/
  timestamp : Nat
  /-- Number of the L1 block before the one that emitted `Proposed`. -/
  originBlockNumber : Nat

/-- The L2 block the next derived block builds on. -/
structure Parent where
  number : Nat
  timestamp : Nat
  /-- Header gas limit. Every non-genesis header includes `ANCHOR_GAS_LIMIT`. -/
  gasLimit : Nat
  /-- The anchor block number recorded by this block (the parent anchor). -/
  anchorBlockNumber : Nat

/-- One block of a derivation source manifest (`LibManifest.BlockManifest`). -/
structure BlockManifest where
  timestamp : Nat
  /-- A 20-byte address. -/
  coinbase : ByteArray
  anchorBlockNumber : Nat
  /-- Gas limit without the anchor gas; the header gas limit adds `ANCHOR_GAS_LIMIT`. -/
  gasLimit : Nat
  /-- Transaction items that passed `Tx.wellFormed`, kept as decoded. -/
  transactions : List Rlp.Item

/-- The block the default manifest consists of: every field zero, no transactions. -/
def emptyBlock : BlockManifest where
  timestamp := 0
  coinbase := ⟨Array.replicate 20 0⟩
  anchorBlockNumber := 0
  gasLimit := 0
  transactions := []

/-- How a source was finalized: its own validated blocks, or one default block. -/
inductive SourceOutcome where
  | accepted (blocks : List BlockManifest)
  | defaulted (block : BlockManifest)

namespace SourceOutcome

/-- The blocks a finalized source contributes. -/
def blocks : SourceOutcome → List BlockManifest
  | .accepted bs => bs
  | .defaulted b => [b]

/-- Whether the source kept its own blocks. -/
def isAccepted : SourceOutcome → Bool
  | .accepted _ => true
  | .defaulted _ => false

end SourceOutcome

/-- A derived L2 block. The header gas limit is `gasLimit + ANCHOR_GAS_LIMIT`. -/
structure DerivedBlock where
  number : Nat
  timestamp : Nat
  coinbase : ByteArray
  anchorBlockNumber : Nat
  gasLimit : Nat
  transactions : List Rlp.Item
  isForcedInclusion : Bool

end TaikoSpec.Derivation
