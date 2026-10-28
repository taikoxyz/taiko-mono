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

structure LandingEnv where
  blockNumber : Nat
  referenceHash : Hash
  referenceHashAvailable : Bool
  blobHashes : List Hash
  proofs : List (Backend × Bool)
  certificate : StatementData
  deriving DecidableEq, Repr

def statementData (s : State) (i : LandInput) (root : CutHash) (e : LandingEnv) : StatementData :=
  let p := (recordAt s i.parentHeight).getD default
  ⟨s.domain,s.generation,s.committeeConfig,p.elHash,p.cometHash,p.cursor,i,e.referenceHash,e.blobHashes,root⟩

/-- `landings[c]`: the slot 285 record at the current checkpoint height (all zero if absent,
like an unwritten mapping entry). -/
def currentRecord (s : State) : Checkpoint := (recordAt s s.checkpoint.height).getD default

/-- Range, grid and origin checks, FI head, reference block and blobs (6.1 steps 1-2, 4-5). -/
def BaseOK (s : State) (i : LandInput) (e : LandingEnv) : Prop :=
  let p := (recordAt s i.parentHeight).getD default
  let c := s.checkpoint.height
  s.entered = false ∧
  s.origin.height ≤ i.parentHeight ∧ i.parentHeight ≤ c ∧ c < i.lastHeight ∧ i.lastHeight < limit48 ∧
  i.parentHeight % s.gridK = 0 ∧ i.lastHeight % s.gridK = 0 ∧
  i.lastHeight-i.parentHeight ≤ s.maxBatchBlocks ∧
  (recordAt s i.parentHeight).isSome = true ∧
  (p.generation = s.generation ∨ i.parentHeight = s.origin.height) ∧
  s.head ≤ i.forcedInclusionHead ∧ i.forcedInclusionHead ≤ s.tail ∧
  i.forcedInclusionHead-s.head ≤ i.lastHeight-c ∧
  i.l1ReferenceBlockNumber < e.blockNumber ∧
  e.blockNumber-i.l1ReferenceBlockNumber ≤ 8191 ∧ e.referenceHashAvailable = true ∧
  1 ≤ e.blobHashes.length ∧ e.blobHashes.length ≤ 6

/-- Leaf checks (6.1 step 3): exactly the grid leaves of (p, h); when c > p, the leaf at c
equals cutLeaf(c) computed from `landings[c]`; that record's FI cursor equals the FI head. -/
def LeavesOK (s : State) (i : LandInput) (leaves : List Leaf) : Prop :=
  let c := s.checkpoint.height
  let cur := currentRecord s
  leaves.length = gridCount s.gridK i.parentHeight i.lastHeight ∧
  (i.parentHeight < c →
    leaves.getD ((c-i.parentHeight)/s.gridK-1) default = cutLeaf c ⟨cur.elHash,cur.cometHash,cur.cursor⟩) ∧
  cur.cursor = s.head

instance (s : State) (i : LandInput) (e : LandingEnv) : Decidable (BaseOK s i e) :=
  inferInstanceAs (Decidable (_ ∧ _))

instance (s : State) (i : LandInput) (leaves : List Leaf) : Decidable (LeavesOK s i leaves) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- Checks that do not depend on proof verification; failure reverts before verifying. -/
def Precheck (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) : Prop :=
  BaseOK s i e ∧ LeavesOK s i leaves

instance (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) :
    Decidable (Precheck s i leaves e) := inferInstanceAs (Decidable (_ ∧ _))

/-- The contract's cutHash for the supplied leaves (6.1 step 6). -/
def leavesHash (s : State) (i : LandInput) (leaves : List Leaf) : CutHash :=
  ⟨s.generation,i.parentHeight,i.lastHeight,leaves⟩

/-- Structural Inbox requirements. MPT/EL/commit truth is not supplied by this predicate:
it requires the separate guest relation `CertifiedTable`. -/
def LandingAllowed (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) : Prop :=
  Precheck s i leaves e ∧ dualOK e.proofs = true ∧
  e.certificate = statementData s i (leavesHash s i leaves) e

instance (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) :
    Decidable (LandingAllowed s i leaves e) := inferInstanceAs (Decidable (_ ∧ _))

/-- Slot 285 record of the actual edge c→h (three words); the proof origin p is not recorded. -/
def landedCheckpoint (s : State) (i : LandInput) : Checkpoint :=
  ⟨i.lastHeight,i.lastBlockHash,i.lastCometHash,i.forcedInclusionHead,s.generation,s.checkpoint.height⟩

/-- SignalService checkpoint of h: (height, hash, stateRoot). -/
def landedSignal (i : LandInput) : Signal := ⟨i.lastHeight,i.lastBlockHash,i.lastStateRoot⟩

/-- The update never depends on c's position among the grid points. The proven snapshot is
stored as is (6.1, spec L318: `activeCommitteeSnapshot = input.activeCommitteeSnapshot`); no landing
timestamp is written. -/
def applyLanding (s : State) (i : LandInput) : State :=
  { s with
    checkpoint := landedCheckpoint s i,
    records := landedCheckpoint s i :: s.records,
    head := i.forcedInclusionHead,
    snapshot := i.activeCommitteeSnapshot,
    signals := s.signals ++ [landedSignal i] }

def land (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) : Option State :=
  if LandingAllowed s i leaves e then some (applyLanding s i) else none

/-- A failed call commits no tentative state: named EVM journal boundary. -/
def transact (s : State) (result : Option State) : State := result.getD s

/-! Guest boundary and grid soundness/completeness. -/

/-- Guest item 10: the FI cursor advances by 0 or 1 per block. -/
def cursorSteps : List Cut → Bool
  | a :: b :: rest => decide (a.cursor ≤ b.cursor ∧ b.cursor ≤ a.cursor+1) && cursorSteps (b :: rest)
  | _ => true

/-- What a sound dual proof (on the guest's grid interval k) establishes about its full cut
table (6.2 items 9-10): one cut per height p..h, the committed grid-leaf hash, the
authenticated origin and end, cursor steps of 0 or 1, and p, h on the grid. -/
def CertifiedTable (k : Nat) (d : StatementData) (table : List Cut) : Prop :=
  table.length = d.input.lastHeight-d.input.parentHeight+1 ∧
  d.cutHash = tableHash k d.generation d.input.parentHeight d.input.lastHeight table ∧
  table.head? = some ⟨d.parentHash,d.parentCometHash,d.headBefore⟩ ∧
  table.getLast? = some ⟨d.input.lastBlockHash,d.input.lastCometHash,d.input.forcedInclusionHead⟩ ∧
  cursorSteps table = true ∧ d.input.parentHeight % k = 0 ∧ d.input.lastHeight % k = 0

instance (k : Nat) (d : StatementData) (table : List Cut) : Decidable (CertifiedTable k d table) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- Every checkpoint and retained record sits on the grid. -/
def OnGrid (s : State) : Prop := s.checkpoint.height % s.gridK = 0 ∧ ∀ r ∈ s.records, r.height % s.gridK = 0

end Etna.Design
