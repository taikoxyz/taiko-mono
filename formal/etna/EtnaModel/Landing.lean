import EtnaModel.Common

namespace Etna.Design

/-- The cut at one height x: EL block hash, CometBFT block hash and FI cursor (the fields of
cutLeaf(x) after the height, ENC-A-29). No cut holds a validator-state hash (ENC-A-29a). -/
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

/-- cutLeaf(x) = keccak256(abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x))),
four words; the height is part of the leaf. -/
def cutLeaf (x : Nat) (c : Cut) : Leaf := .cut x c

/-- The certified inner list (ENC-A-30, ENC-A-31): cutLeaf of every height p+1, …, h−1 strictly
inside (p, h), read from the cut table of heights p..h (index x−p). It has h−p−1 leaves and is
empty when h = p+1 (ENC-A-32). -/
def innerLeaves (p h : Nat) (table : List Cut) : List Leaf :=
  (List.range (h-p-1)).map fun j => cutLeaf (p+(j+1)) (table.getD (j+1) default)

/-- cutHash = keccak256(ETNA_LAND_CUTS_V1, generation, p, h, keccak256(abi.encodePacked(leaves))),
kept as fields. -/
structure CutHash where
  generation : Nat
  parentHeight : Nat
  lastHeight : Nat
  leaves : List Leaf
  deriving DecidableEq, Repr, Inhabited

def tableHash (generation p h : Nat) (table : List Cut) : CutHash := ⟨generation,p,h,innerLeaves p h table⟩

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

/-- Decoded public statement (ENC-A-35). Real hashing/verifier binding is an explicit boundary.
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

/-! Guest boundary. -/

/-- Guest item 10: the FI cursor advances by 0 or 1 per block. -/
def cursorSteps : List Cut → Bool
  | a :: b :: rest => decide (a.cursor ≤ b.cursor ∧ b.cursor ≤ a.cursor+1) && cursorSteps (b :: rest)
  | _ => true

end Etna.Design
