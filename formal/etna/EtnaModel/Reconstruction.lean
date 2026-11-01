import EtnaModel.Settlement
import EtnaModel.Recovery

/-! Public EL-only reconstruction. Bytes denote complete finite byte strings, including
state/code images. No private block, Comet header, vote, envelope or witness is an
executable input. The proof-only ProjectionLaws below connects the older guest model.
Canonical L1 authentication, original-blob availability, codecs, crypto and the full
EL implementation are external contracts; these definitions do not implement them. -/
namespace Etna.Design.Reconstruction

abbrev Bytes := List UInt8

/-- Full encoded EL header, not BlockValidity.Header. The body preserves the exact order
and full EIP-2718 bytes, including the legacy transaction's encoding. -/
structure PublicBlock where
  header : Bytes
  transactions : List Bytes
  deriving DecidableEq, Repr

/-- Only the fields the algorithm reads; all other fork-dependent fields remain in the
complete header bytes passed to hashing and full-block execution. -/
structure HeaderFields where
  height : Nat
  parentHash : Hash
  stateRoot : Hash
  timestamp : Nat
  parentBeaconRoot : Hash
  deriving DecidableEq, Repr

structure Point where
  height : Nat
  elHash : Hash
  deriving DecidableEq, Repr

structure Landing where
  order : Nat
  generation : Nat
  origin : Origin
  current : Checkpoint
  parent : Checkpoint
  input : LandInput
  blobHashes : List Hash
  version : Nat
  /-- None represents unavailable original material, not an empty decoded batch. -/
  original : Option (List Bytes)
  /-- Canonical L1 transactions/events/headers and authentication openings, all public. -/
  l1Evidence : Bytes
  deriving DecidableEq, Repr

structure RecoveryRecord where
  order : Nat
  generation : Nat
  origin : Origin
  current : Checkpoint
  nextOrigin : Origin
  l1Evidence : Bytes
  deriving DecidableEq, Repr

inductive Record where
  | landing : Landing → Record
  | recovery : RecoveryRecord → Record
  deriving DecidableEq, Repr

structure Start where
  generation : Nat
  origin : Origin
  checkpoint : Checkpoint
  stateRoot : Hash
  order : Nat
  configuration : Bytes
  ruleVersion : Nat
  l1Evidence : Bytes
  deriving DecidableEq, Repr

/-- Fixed deployment interfaces, never selected separately for each landing. Full-block
execution includes the fork's pre-execution EIP-4788 beacon-root and EIP-2935 parent-hash
writes, then ordered transactions and remaining EL processing/validation. It consumes
all header bytes, not just time or transactions. Unsupported rules/headers fail closed.
Truth of these interpretations, canonical codecs and hash binding is external. -/
structure Primitives where
  configuration : Bytes
  ruleVersion : Nat
  readHeader : Bytes → Option HeaderFields
  headerHash : Bytes → Hash
  stateRoot : Bytes → Hash
  versionedHash : Bytes → Hash
  decodePayload : Nat → List Bytes → Option (List PublicBlock)
  executeFullBlock : Bytes → PublicBlock → Option Bytes
  authenticateStart : Start → Bool
  authenticateRecord : Record → Bool

structure Rebuilt where
  generation : Nat
  origin : Origin
  checkpoint : Checkpoint
  baseHeight : Nat
  state : Bytes
  /-- EL hash at every already reconstructed height, including the starting point. -/
  archive : List (Nat × Bytes)
  /-- Audit of state applications, not of overlap verification reads. -/
  applied : List Nat
  order : Nat
  deriving DecidableEq, Repr

structure Executed where
  point : Point
  state : Bytes
  headers : List (Nat × Bytes)
  applied : List Nat
  deriving DecidableEq, Repr

def initializeState (el : Primitives) (a : Start) (header state : Bytes) : Option Rebuilt := do
  if el.authenticateStart a = false then none else do
  let h ← el.readHeader header
  if a.configuration = el.configuration ∧ a.ruleVersion = el.ruleVersion ∧
      h.height = a.checkpoint.height ∧ el.headerHash header = a.checkpoint.elHash ∧
      h.stateRoot = a.stateRoot ∧ el.stateRoot state = a.stateRoot then
    some ⟨a.generation,a.origin,a.checkpoint,h.height,state,[(h.height,header)],[],a.order⟩
  else none

def nextPoint (el : Primitives) (p : Point) (b : PublicBlock) : Option Point := do
  let h ← el.readHeader b.header
  if h.height = p.height+1 ∧ h.parentHash = p.elHash then
    some ⟨h.height,el.headerHash b.header⟩ else none

/-- Verification only: there is intentionally no state argument or EL call. -/
def verifyOverlap (el : Primitives) (archive : List (Nat × Bytes)) :
    Point → List PublicBlock → Option Point
  | p, [] => some p
  | p, b :: bs => do
    let q ← nextPoint el p b
    if (archive.lookup q.height).map el.headerHash = some q.elHash then verifyOverlap el archive q bs else none

/-- Apply each new public block once, with its complete public context. -/
def executeSuffix (el : Primitives) : Point → Bytes → List PublicBlock → Option Executed
  | p, state, [] => some ⟨p,state,[],[]⟩
  | p, state, b :: bs => do
    let q ← nextPoint el p b
    let h ← el.readHeader b.header
    let next ← el.executeFullBlock state b
    if el.stateRoot next = h.stateRoot then
      let out ← executeSuffix el q next bs
      some { out with headers := (q.height,b.header) :: out.headers, applied := q.height :: out.applied }
    else none

def Landing.metadata (s : Rebuilt) (l : Landing) : Prop :=
  s.baseHeight ≤ l.input.parentHeight ∧ s.order < l.order ∧ s.generation = l.generation ∧ s.origin = l.origin ∧
  s.checkpoint = l.current ∧ l.origin.height ≤ l.input.parentHeight ∧
  l.parent.height = l.input.parentHeight ∧ l.input.parentHeight ≤ l.current.height ∧
  l.current.height < l.input.lastHeight ∧
  (l.parent.generation = l.generation ∨ l.parent.height = l.origin.height) ∧
  (s.archive.lookup l.parent.height).map (fun raw => raw) ≠ none

instance (s : Rebuilt) (l : Landing) : Decidable (l.metadata s) :=
  inferInstanceAs (Decidable (_ ∧ _))

def Landing.checkpoint (l : Landing) : Checkpoint :=
  ⟨l.input.lastHeight,l.input.lastBlockHash,l.input.lastCometHash,
    l.input.forcedInclusionHead,l.generation,l.current.height⟩

def finish (s : Rebuilt) (l : Landing) (out : Executed) : Rebuilt :=
  { s with
    checkpoint := l.checkpoint
    state := out.state
    archive := out.headers.reverse ++ s.archive
    applied := s.applied ++ out.applied
    order := l.order }

def reconstructLanding (el : Primitives) (s : Rebuilt) (l : Landing) : Option Rebuilt := do
  if l.metadata s ∧ l.version = 6 ∧
      (s.archive.lookup l.parent.height).map el.headerHash = some l.parent.elHash then
    let raw ← l.original
    if raw.map el.versionedHash = l.blobHashes then
      let blocks ← el.decodePayload l.version raw
      if blocks.length = l.input.lastHeight-l.input.parentHeight then
        let overlap ← verifyOverlap el s.archive ⟨l.parent.height,l.parent.elHash⟩
          (blocks.take (l.current.height-l.input.parentHeight))
        if overlap = ⟨l.current.height,l.current.elHash⟩ then
          let out ← executeSuffix el overlap s.state (blocks.drop (l.current.height-l.input.parentHeight))
          if out.point = ⟨l.input.lastHeight,l.input.lastBlockHash⟩ ∧
              el.stateRoot out.state = l.input.lastStateRoot then
            some (finish s l out)
          else none
        else none
      else none
    else none
  else none

/-- Ordinary recovery keeps the authenticated EL frontier/state. Its new fixed origin
is c, while later proof origins p may advance independently. Exceptional rollback is
not silently treated as ordinary recovery; it requires a separately authenticated start. -/
def recover (s : Rebuilt) (r : RecoveryRecord) : Option Rebuilt :=
  if s.order < r.order ∧ s.generation = r.generation ∧ s.origin = r.origin ∧
      s.checkpoint = r.current ∧ r.nextOrigin.height = r.current.height ∧
      r.origin.l1Block ≤ r.nextOrigin.l1Block then
    some { s with generation := s.generation+1, origin := r.nextOrigin, order := r.order }
  else none

def step (el : Primitives) (s : Rebuilt) (record : Record) : Option Rebuilt :=
  if el.authenticateRecord record then
    match record with | .landing l => reconstructLanding el s l | .recovery r => recover s r
  else none

def reconstruct (el : Primitives) : Rebuilt → List Record → Option Rebuilt
  | s, [] => some s
  | s, r :: rs => (step el s r).bind fun t => reconstruct el t rs

/-- Public entry point always authenticates/recomputes the complete starting image
before consuming canonical records; Rebuilt is only the incremental machine state. -/
def reconstructPublic (el : Primitives) (start : Start) (header state : Bytes)
    (records : List Record) : Option Rebuilt :=
  (initializeState el start header state).bind fun s => reconstruct el s records

/-- Proof-side local semantics, not executable input or an assumed reconstruction result.
Each transition supplies the independently specified full-block EL primitive result. -/
inductive Execution (el : Primitives) : Point → Bytes → List PublicBlock → Executed → Prop
  | nil (p state) : Execution el p state [] ⟨p,state,[],[]⟩
  | cons {p state b bs q h next out}
      (header : el.readHeader b.header = some h)
      (height : h.height = p.height+1) (parent : h.parentHash = p.elHash)
      (hash : q = ⟨h.height,el.headerHash b.header⟩)
      (execution : el.executeFullBlock state b = some next)
      (root : el.stateRoot next = h.stateRoot)
      (rest : Execution el q next bs out) :
      Execution el p state (b :: bs)
        { out with headers := (q.height,b.header) :: out.headers, applied := q.height :: out.applied }

/-- Proof-side full encoded private-parent/public-header binding. -/
def HeaderEncoding (el : Primitives) (p : BlockValidity.Header) : Prop :=
  ∃ raw h, el.readHeader raw = some h ∧ el.headerHash raw = p.elHash ∧
    h.height = p.height ∧ h.stateRoot = p.stateRoot

/-- The projection is proof-side only. Its raw header/transaction bytes come from the
public executionBlock. These laws must be established by a real codec/crypto/EL adapter;
the old batchPayloadValid/executionValid flags alone do not imply them. In particular,
fullEL includes EIP-4788/2935 system effects, not only user transaction evaluation. -/
structure ProjectionLaws (el : Primitives) where
  /-- Rules whose legacy validity predicates truthfully implement this fixed EL/codec. -/
  guestRules : BlockValidity.Rules → Prop
  project : BlockValidity.Block → PublicBlock
  parentBytes : BlockValidity.Header → Bytes
  parent : ∀ r p bs hashes, Settlement.BatchValid r p bs hashes → guestRules r →
    ∃ h, el.readHeader (parentBytes p) = some h ∧ el.headerHash (parentBytes p) = p.elHash ∧
      h.height = p.height ∧ h.stateRoot = p.stateRoot
  fields : ∀ r p b, BlockValidity.Valid r p b → guestRules r →
    el.readHeader (project b).header = some
      ⟨b.header.height,b.parentHash,b.header.stateRoot,b.header.timestamp,b.parentBeaconRoot⟩
  headerBound : ∀ r p b, BlockValidity.Valid r p b → guestRules r → el.headerHash (project b).header = b.header.elHash
  payload : ∀ r p bs hashes raw, Settlement.BatchValid r p bs hashes → guestRules r →
    raw.map el.versionedHash = hashes → el.decodePayload 6 raw = some (bs.map project)
  fullEL : ∀ r p b state, BlockValidity.Valid r p b → guestRules r → el.stateRoot state = p.stateRoot →
    ∃ next, el.executeFullBlock state (project b) = some next ∧ el.stateRoot next = b.header.stateRoot

/-- Collision-free comparison of canonical public EL headers is the named crypto
primitive, restricted to the finite saved/incoming headers of this comparison. It is
not a claim of global finite-width hash injectivity or that whole histories agree. -/
def HeaderSeparation (el : Primitives) (saved incoming : List Bytes) : Prop :=
  ∀ a ∈ saved, ∀ b ∈ incoming, el.readHeader a ≠ none → el.readHeader b ≠ none →
    el.headerHash a = el.headerHash b → a = b

/-- Actual saved history: each new header links to the preceding stored header, and
only the full-block primitive advances state. No prefix-equality conclusion is a field. -/
inductive Stored (el : Primitives) (base : Nat) : Point → Bytes → List (Nat × Bytes) → Prop
  | start {raw h state} (header : el.readHeader raw = some h) (height : h.height = base)
      (root : el.stateRoot state = h.stateRoot) :
      Stored el base ⟨h.height,el.headerHash raw⟩ state [(h.height,raw)]
  | next {p state archive b h next} (prior : Stored el base p state archive)
      (header : el.readHeader b.header = some h) (height : h.height = p.height+1)
      (parent : h.parentHash = p.elHash) (execution : el.executeFullBlock state b = some next)
      (root : el.stateRoot next = h.stateRoot) :
      Stored el base ⟨h.height,el.headerHash b.header⟩ next ((h.height,b.header) :: archive)

/-- Public record projection of the real Inbox landing; original material and public L1
proof bytes are separate availability/authentication inputs. -/
def landingRecord (s : State) (i : LandInput) (e : LandingEnv)
    (order : Nat) (raw : Option (List Bytes)) (evidence : Bytes) : Landing :=
  ⟨order,s.generation,s.origin,s.checkpoint,(recordAt s i.parentHeight).getD default,
    i,e.blobHashes,6,raw,evidence⟩

/-- Proof-only certificate and canonical-history inputs. Every data field here is absent
from reconstructLanding/step/reconstruct. No field asserts reconstruction success, overlap equality,
or the resulting state. Original availability and finite compared-header collision
exclusion are explicit, independent assumptions. -/
structure Certification (el : Primitives) (laws : ProjectionLaws el) (s : Rebuilt) (l : Landing) where
  inbox : State
  after : State
  rules : BlockValidity.Rules
  parent : BlockValidity.Header
  blocks : List BlockValidity.Block
  hashes : List Hash
  leaves : List Leaf
  environment : LandingEnv
  order : Nat
  raw : List Bytes
  evidence : Bytes
  accepted : Etna.Design.land inbox l.input leaves environment = some after
  valid : Settlement.BatchValid rules parent blocks hashes
  soundRules : laws.guestRules rules
  binding : environment.certificate = Settlement.statement rules parent blocks hashes
  projected : l = landingRecord inbox l.input environment order (some raw) evidence
  aligned : s.generation = inbox.generation ∧ s.origin = inbox.origin ∧ s.checkpoint = inbox.checkpoint
  stored : Stored el s.baseHeight ⟨s.checkpoint.height,s.checkpoint.elHash⟩ s.state s.archive
  stateValid : Settlement.StateValid inbox
  grid : inbox.gridK = rules.gridK
  positive : 0 < inbox.gridK
  base : s.baseHeight ≤ parent.height
  fresh : s.order < order
  available : raw.map el.versionedHash = environment.blobHashes
  authenticated : el.authenticateRecord (.landing l) = true
  separation : HeaderSeparation el (s.archive.map Prod.snd)
    (laws.parentBytes parent :: blocks.map (fun b => (laws.project b).header))

/-- Trace composition retains genuine accepted batch projections and their ordinary
full-EL semantic execution, never an assumed success result. -/
inductive ProjectionTrace (el : Primitives) (laws : ProjectionLaws el) :
    Rebuilt → List Record → Rebuilt → Prop
  | nil (s) : ProjectionTrace el laws s [] s
  | landing {s l out records t} (certificate : Certification el laws s l)
      (execution : Execution el ⟨s.checkpoint.height,s.checkpoint.elHash⟩ s.state
        ((certificate.blocks.drop (s.checkpoint.height-certificate.parent.height)).map laws.project) out)
      (rest : ProjectionTrace el laws (finish s l out) records t) :
      ProjectionTrace el laws s (.landing l :: records) t
  | recovery {s r records t}
      (authentication : el.authenticateRecord (.recovery r) = true)
      (fresh : s.order < r.order) (generation : s.generation = r.generation)
      (origin : s.origin = r.origin) (checkpoint : s.checkpoint = r.current)
      (height : r.nextOrigin.height = r.current.height) (later : r.origin.l1Block ≤ r.nextOrigin.l1Block)
      (rest : ProjectionTrace el laws
        { s with generation := s.generation+1, origin := r.nextOrigin, order := r.order } records t) :
      ProjectionTrace el laws s (.recovery r :: records) t

end Etna.Design.Reconstruction
