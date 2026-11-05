import EtnaModel.Common

namespace Etna.Design

/-- The cut at one height x: EL block hash, CometBFT block hash and FI cursor (the fields of
cutLeaf(x) after the height). -/
structure Cut where
  elHash : Hash
  cometHash : Hash
  cursor : Nat
  deriving DecidableEq, Repr, Inhabited

/-- A bytes32 leaf as land receives it: a real cutLeaf preimage or any other word. Free
terms: keccak collision resistance makes `cut` injective and disjoint from other words. -/
inductive Leaf where
  | cut : Nat → Cut → Leaf
  | word : Nat → Leaf
  deriving DecidableEq, Repr

instance : Inhabited Leaf := ⟨.word 0⟩

/-- cutLeaf(x) = keccak256(abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x)));
the height is part of the leaf. -/
def cutLeaf (x : Nat) (c : Cut) : Leaf := .cut x c

/-- Number of grid points strictly between p and h: (h−p)/K − 1. -/
def gridCount (k p h : Nat) : Nat := (h-p)/k-1

/-- The certified leaf list: cutLeaf of the grid points p+K, …, h−K, read from the cut table
of heights p..h (index x−p). -/
def gridLeaves (k p h : Nat) (table : List Cut) : List Leaf :=
  (List.range (gridCount k p h)).map fun j => cutLeaf (p+k*(j+1)) (table.getD (k*(j+1)) default)

/-- cutHash = keccak256(ETNA_LAND_CUTS_V1, generation, p, h, keccak256(abi.encodePacked(leaves))),
kept as fields. -/
structure CutHash where
  generation : Nat
  parentHeight : Nat
  lastHeight : Nat
  leaves : List Leaf
  deriving DecidableEq, Repr, Inhabited

def tableHash (k generation p h : Nat) (table : List Cut) : CutHash := ⟨generation,p,h,gridLeaves k p h table⟩

/-- Exactly the eight LandInput fields; caller is neither a field nor a beneficiary. -/
structure LandInput where
  parentHeight : Nat
  lastHeight : Nat
  lastBlockHash : Hash
  lastCometHash : Hash
  lastStateRoot : Hash
  l1ReferenceBlockNumber : Nat
  forcedInclusionHead : Nat
  activeCommitteeSnapshot : Nat
  deriving DecidableEq, Repr

/-- Decoded public statement. Real hashing/verifier binding is an explicit boundary.
The certificate binds the whole proof range through cutHash, never execution-time c. -/
structure StatementData where
  domain : Domain
  generation : Nat
  config : Hash
  parentHash : Hash
  parentCometHash : Hash
  headBefore : Nat
  input : LandInput
  referenceHash : Hash
  blobHashes : List Hash
  cutHash : CutHash
  deriving DecidableEq, Repr

/-! Guest boundary and grid soundness/completeness. -/

/-- Guest item 10: the FI cursor advances by 0 or 1 per block. -/
def cursorSteps : List Cut → Bool
  | a :: b :: rest => decide (a.cursor ≤ b.cursor ∧ b.cursor ≤ a.cursor+1) && cursorSteps (b :: rest)
  | _ => true

end Etna.Design
