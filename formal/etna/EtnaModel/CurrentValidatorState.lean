import EtnaModel.CurrentBlocks
import EtnaModel.CurrentProtocol

/-! Executable validator-state arithmetic from CometBFT v0.40.0:
types/validator_set.go, types/validator.go, state/state.go and state/execution.go.
Keys and their authenticated secp256k1eth addresses are decoded inputs. Hashing the
snapshot is a separate adapter; no Go execution or ABI/Keccak refinement is assumed. -/
namespace Etna.Design.Current.ValidatorState

def maxInt : Int := 2^63-1
def minInt : Int := -(2^63)
def maxPower : Nat := (2^63-1)/8

structure Validator where
  key : Hash
  address : Nat
  power : Nat
  priority : Int
  deriving DecidableEq, Repr, Inhabited

structure Change where
  key : Hash
  address : Nat
  power : Nat
  deriving DecidableEq, Repr

structure ValSet where
  members : List Validator
  /-- Address of the stored proposer, not a fresh search for the largest priority. -/
  proposer : Option Nat
  deriving DecidableEq, Repr, Inhabited

structure CommitState where
  /-- Logical committed height. At genesis this is Etna's origin, even though stock
  LastBlockHeight is zero until its first commit at InitialHeight = origin + 1. -/
  height : Nat
  current : ValSet
  next : ValSet
  last : ValSet := default
  deriving DecidableEq, Repr, Inhabited

def total (xs : List Validator) : Nat := (xs.map Validator.power).sum
def clip (n : Int) : Int := max minInt (min maxInt n)
def wrap (n : Int) : Int := (n+2^63) % (2^64) - 2^63

/-- Go's signed /, unlike big.Int.Div, truncates toward zero. -/
def truncate (n d : Int) : Int := n.tdiv d

/-- big.Int.Div by positive len floors, including for a negative sum. -/
def average (xs : List Validator) : Int := (xs.map Validator.priority).sum / xs.length

def validMembers (xs : List Validator) : Bool := decide
  (xs ≠ [] ∧ (xs.map Validator.address).Nodup ∧ (xs.map Validator.key).Nodup ∧
    total xs ≤ maxPower ∧ ∀ v ∈ xs,
      v.key < limit256 ∧ v.address < 2^160 ∧ 0 < v.power ∧
      minInt ≤ v.priority ∧ v.priority ≤ maxInt)

def insertOrdered (a : Validator) : List Validator → List Validator
  | [] => [a]
  | b :: rest => if b.power < a.power ∨ (a.power = b.power ∧ a.address ≤ b.address)
    then a :: b :: rest else b :: insertOrdered a rest

def ordered : List Validator → List Validator
  | [] => []
  | a :: rest => insertOrdered a (ordered rest)

/-- Int64 wrap in computeMaxMinPriorityDiff and its ratio numerator is explicit.
A zero divisor that would panic in Go refuses the decoded input instead. -/
def normalize (xs : List Validator) : Option (List Validator) := do
  let first ← xs.head?
  let low := xs.foldl (fun p v => min p v.priority) first.priority
  let high := xs.foldl (fun p v => max p v.priority) first.priority
  let raw := wrap (high-low)
  let diff := if raw < 0 then wrap (-raw) else raw
  let window : Int := 2 * total xs
  let ratio := truncate (wrap (diff+window-1)) window
  let scaled ← if 0 < window ∧ window < diff then
      if ratio = 0 then none
      else some (xs.map fun v => { v with priority := truncate v.priority ratio })
    else some xs
  let mean := average scaled
  return scaled.map fun v => { v with priority := clip (v.priority-mean) }

def better (a b : Validator) : Validator :=
  if b.priority < a.priority ∨ (a.priority = b.priority ∧ a.address < b.address)
  then a else b

def roundStep (s : ValSet) : Option ValSet := do
  let raised := s.members.map fun v => { v with priority := clip (v.priority+v.power) }
  let first ← raised.head?
  let chosen := raised.foldl better first
  return ⟨raised.map (fun v => if v.address = chosen.address then
    { v with priority := clip (v.priority-total s.members) } else v),some chosen.address⟩

def rounds (s : ValSet) : Nat → Option ValSet
  | 0 => some s
  | n+1 => (roundStep s).bind fun t => rounds t n

/-- Normalize once per invocation, then run the requested number of rounds. A commit
always calls this with 1; historical lookup's single call with n is different. -/
def increment (s : ValSet) (n : Nat) : Option ValSet :=
  if validMembers s.members ∧ 0 < n then
    (normalize s.members).bind fun xs => rounds ⟨xs,s.proposer⟩ n
  else none

def changeValid (changes : List Change) : Bool := decide
  ((changes.map Change.address).Nodup ∧ ∀ c ∈ changes,
    c.key < limit256 ∧ c.address < 2^160 ∧ c.power ≤ maxPower)

def update (s : ValSet) (changes : List Change) : Option ValSet := do
  if changes = [] then return s
  if !changeValid changes then none else do
    if !(changes.all fun c => c.power != 0 || s.members.any (·.address == c.address)) then
      none
    else do
      let positive := changes.filter (fun c => c.power != 0)
      let added := (positive.map Change.power).sum
      let replaced := (s.members.filter fun v => positive.any (·.address == v.address))
        |>.map Validator.power |>.sum
      let before := total s.members+added-replaced
      let kept := s.members.filterMap fun v =>
        match changes.find? (·.address == v.address) with
        | none => some v
        | some c => if c.power = 0 then none else some { v with key := c.key,power := c.power }
      let fresh := (positive.filter fun c => !s.members.any (·.address == c.address)).map fun c =>
        (⟨c.key,c.address,c.power,-(Int.ofNat (before+before/8))⟩ : Validator)
      let xs := kept ++ fresh
      if !validMembers xs then none else do
        let normalized ← normalize xs
        return ⟨ordered normalized,s.proposer⟩

def newSet (xs : List Validator) : Option ValSet := do
  let s ← update ⟨[],none⟩ (xs.map fun v => ⟨v.key,v.address,v.power⟩)
  increment s 1

def genesis (origin : Nat) (xs : List Validator) : Option CommitState := do
  let current ← newSet xs
  let next ← increment current 1
  return ⟨origin,current,next,default⟩

/-- updateState: H's changes affect NextValidators for H+2, not Validators for H+1. -/
def commit (s : CommitState) (changes : List Change) : Option CommitState := do
  let updated ← update s.next changes
  let next ← increment updated 1
  return ⟨s.height+1,s.next,next,s.current⟩

def replay (s : CommitState) : List (List Change) → Option CommitState
  | [] => some s
  | changes :: rest => (commit s changes).bind fun t => replay t rest

def selected (c : Consensus.Context) (addressOf : Hash → Nat) (record : Committee.Record) :
    List Validator := ordered (record.members.map fun e =>
      ⟨e.key,addressOf e.key,e.stake/c.unit,0⟩)

def genesisFor (c : Consensus.Context) (addressOf : Hash → Nat) : Option CommitState :=
  genesis c.originHeight (selected c addressOf (Consensus.initial c))

def changesFor (old target : List Validator) : List Change :=
  target.map (fun v => ⟨v.key,v.address,v.power⟩) ++
    (old.filter fun v => !target.any (·.address == v.address)).map fun v => ⟨v.key,v.address,0⟩

/-- FinalizeBlock at S(t)=H(t)-2 emits the selected committee's changes. -/
def scheduled (c : Consensus.Context) (addressOf : Hash → Nat) (s : CommitState) : List Change :=
  if (s.height+2) % c.epochLen = 0 then
    changesFor s.next.members
      (selected c addressOf (Consensus.normal c ((s.height+2)/c.epochLen)))
  else []

/-- The appendix A payload contains both ordered sets, signed priorities and proposer
indexes. Key decoding and ABI/Keccak are external; last validators are not committed. -/
structure Snapshot where
  height : Nat
  current : ValSet
  next : ValSet
  deriving DecidableEq, Repr

def snapshot (s : CommitState) : Snapshot := ⟨s.height,s.current,s.next⟩

def validSet (s : ValSet) : Bool := validMembers s.members &&
  decide (ordered s.members = s.members) &&
  s.proposer.any (fun address => s.members.any (·.address == address))

def validState (s : CommitState) : Bool := validSet s.current && validSet s.next

/-- At the generation origin use freshly derived genesis, irrespective of the retained
old-generation hash. Elsewhere require the input preimage at that exact height. -/
def openOrigin (hash : Snapshot → Hash) (origin height stored : Nat)
    (fresh supplied : CommitState) : Option CommitState :=
  if height = origin then
    if fresh.height = origin ∧ validState fresh = true then some fresh else none
  else if origin < height ∧ supplied.height = height ∧ validState supplied = true ∧
      hash (snapshot supplied) = stored then
    some supplied
  else none

def membership (s : ValSet) : List (Hash × Nat) := s.members.map fun v => (v.key,v.power)

/-- Executable concretization of an existing decoded block, not a trusted Boolean
standing for its post-state: compute the update and compare the committed hash. -/
def checkBlock (r : Blocks.Policy) (addressOf : Hash → Nat) (hash : Snapshot → Hash)
    (s : CommitState) (b : Blocks.Block) : Option CommitState := do
  if validState s = false ∨ b.header.height ≠ s.height+1 ∨
      membership s.current ≠ membership ⟨selected r.consensus addressOf
        (Consensus.activeAt r.consensus b.header.height),none⟩ ∨
      membership s.next ≠ membership ⟨selected r.consensus addressOf
        (Consensus.activeAt r.consensus (b.header.height+1)),none⟩ then none
  else do
    let after ← commit s (scheduled r.consensus addressOf s)
    if hash (snapshot after) = b.header.valStateHash then some after else none

def checkRun (r : Blocks.Policy) (addressOf : Hash → Nat) (hash : Snapshot → Hash)
    (s : CommitState) : List Blocks.Block → Option CommitState
  | [] => some s
  | b :: rest => (checkBlock r addressOf hash s b).bind fun t => checkRun r addressOf hash t rest

/-- A concrete semantic batch refines the existing BatchValid, adding actual genesis /
preimage admission and per-height priority replay. H1–H4 retain their old statements. -/
def Batch (r : Blocks.Policy) (addressOf : Hash → Nat) (hash : Snapshot → Hash)
    (p : Blocks.Header) (bs : List Blocks.Block) (blobs : List Hash)
    (supplied final : CommitState) : Prop :=
  Blocks.BatchValid r p bs blobs ∧ ∃ fresh initial,
    genesisFor r.consensus addressOf = some fresh ∧
    openOrigin hash r.consensus.originHeight p.height p.valStateHash fresh supplied = some initial ∧
    checkRun r addressOf hash initial bs = some final

/-- Strengthen an existing closed-prefix guest certificate with concrete validator
replay. This is a new refinement obligation, not a silent change to VerifierSound. -/
def Certificate (env : Protocol.Environment) (w : Protocol.World) (d : StatementData)
    (archive : List Blocks.Header) (p : Blocks.Header) (bs : List Blocks.Block)
    (addressOf : Hash → Nat) (hash : Snapshot → Hash) (supplied final : CommitState) : Prop :=
  Protocol.BatchCertificate env w d archive p bs ∧
    Batch (Protocol.policy env (Protocol.certificateWorld env w d.input.l1ReferenceBlockNumber)
      archive d.input.l1ReferenceBlockNumber) addressOf hash p bs d.blobHashes supplied final

/-- Guest soundness with validator replay: in the shape of `Protocol.VerifierSound`, a sound
backend's accepted proof for an accepted landing certifies its statement with a batch that also
replays the validator state, under the deployment's key-to-address map `addressOf` and snapshot
hash `hash`. H1–H4 do not assume it: the joint H1–H4 witnesses would then need H4's
`ProofComplete` for replayed batches, and the recovery path would have to build them. -/
def ReplaySound (env : Protocol.Environment) (initial : Protocol.World) (addressOf : Hash → Nat)
    (hash : Snapshot → Hash) : Prop :=
  ∃ sound : Backend → Prop,
    (∀ proofs, dualOK proofs = true → ∃ backend ∈ proofs, sound backend.1) ∧
    ∀ w, Protocol.Trace env initial w → ∀ a t proof, Protocol.land env w a = some t → proof ∈ a.proofs →
      sound proof.backend →
      env.verify w.verifier proof.backend proof.image proof.bytes (Protocol.statement env w a) = true →
      ∃ archive p bs supplied final,
        Certificate env w (Protocol.statement env w a) archive p bs addressOf hash supplied final

end Etna.Design.Current.ValidatorState
