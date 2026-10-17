module
public import Etna.Common.Words
@[expose] public section
namespace Etna.FI

inductive Error where
  | missingWitness (cursor : Nat) | unexpectedWitness | wrongIndex (expected got : Nat)
  | tooLarge (size : Nat) | hashMismatch | needsSingleton | retained | cursorOverflow
  | malformed | wrongContext
  deriving DecidableEq, Repr

inductive Decision where
  | ordinary | included (index : Nat) | skippedInvalid (index : Nat) | needsSkip (index : Nat)
  deriving DecidableEq, Repr

structure ForcedFacts where
  cursor : Nat
  timestamp : Nat
  delay : Nat
  anchorTimestamp : Nat
  preimageLen : Nat
  preimageHashMatches : Bool
  preimageCanonical : Bool
  firstMatches : Bool
  deriving DecidableEq, Repr

/-- These are adapter outcomes; only authenticated completed-empty can resolve a skip. -/
inductive SingletonOutcome where
  | unavailable | retained | malformed | wrongContext | completedEmpty
  deriving DecidableEq, Repr

def pending (cursor tail : Nat) (witness : Option Nat) : Except Error Bool :=
  if cursor ≥ tail then
    match witness with
    | none => .ok false
    | some _ => .error .unexpectedWitness
  else
    match witness with
    | none => .error (.missingWitness cursor)
    | some got => if got ≠ cursor then .error (.wrongIndex cursor got) else .ok true

def checkPreimage (size : Nat) (hashMatches : Bool) : Except Error Unit :=
  if size > 8192 then .error (.tooLarge size)
  else if size ≠ 0 then
    if hashMatches then .ok () else .error .hashMismatch
  else .ok ()

def isDue (timestamp delay anchor : Nat) : Bool := decide (timestamp + delay ≤ anchor)

def classify (f : ForcedFacts) : Except Error Decision := do
  checkPreimage f.preimageLen f.preimageHashMatches
  if f.firstMatches then return .included f.cursor
  if isDue f.timestamp f.delay f.anchorTimestamp then
    if f.preimageHashMatches then
      if f.preimageCanonical then return .needsSkip f.cursor
      else return .skippedInvalid f.cursor
    else Except.error .hashMismatch
  else return .ordinary

def resolve (d : Decision) (outcome : SingletonOutcome) : Except Error (Option Nat) :=
  match d with
  | .ordinary => .ok none
  | .included i | .skippedInvalid i => .ok (some i)
  | .needsSkip i => match outcome with
    | .unavailable => .error .needsSingleton
    | .retained => .error .retained
    | .malformed => .error .malformed
    | .wrongContext => .error .wrongContext
    | .completedEmpty => .ok (some i)

def advance (cursor : Nat) (consumed : Option Nat) : Except Error Nat :=
  match consumed with
  | none => .ok cursor
  | some got =>
    if got ≠ cursor then .error (.wrongIndex cursor got)
    else if cursor + 1 < 2^64 then .ok (cursor + 1) else .error .cursorOverflow

abbrev Bytes := List (Fin 256)

/-- Only the stored fields used by FI. Historical bytes are bound separately by local separation. -/
structure Entry where
  timestamp : Word64
  digest : Nat
  deriving DecidableEq

structure Context where
  parent : Nat
  attributes : Nat
  anchorHash : Nat
  stateRoot : Nat
  inbox : Nat
  cursor : Word64
  tail : Word48
  anchorTimestamp : Word64
  delay : Word64
  deriving DecidableEq

structure Witness where
  index : Nat
  entry : Entry
  preimage : Bytes
  proof : Bytes
  deriving DecidableEq

/-- An explicit ordered pair: the storage-slot derivation itself is an external boundary. -/
def entrySlots (slot : Nat → Nat) (index : Nat) : List Nat := [slot index, slot index + 1]

structure Authentication where
  committedParent : Nat
  expectedAttributes : Nat → Nat → Nat
  committedRoot : Nat → Nat
  anchorTime : Nat → Nat
  queueTail : Nat → Nat → Nat
  storageEntry : Nat → Nat → List Nat → Option Entry
  verify : Nat → Nat → List Nat → Entry → Bytes → Bool
  slot : Nat → Nat
  /-- MPT soundness at this root, account and exact ordered storage-key pair. -/
  sound : ∀ root inbox slots entry proof,
    verify root inbox slots entry proof = true → storageEntry root inbox slots = some entry

/-- Evidence binds the caller's root, time and tail to the selected authenticated anchor. -/
structure ContextEvidence (a : Authentication) (c : Context) : Prop where
  parent : c.parent = a.committedParent
  attributes : c.attributes = a.expectedAttributes c.parent c.anchorHash
  root : c.stateRoot = a.committedRoot c.anchorHash
  time : c.anchorTimestamp.val = a.anchorTime c.anchorHash
  tail : c.tail.val = a.queueTail c.stateRoot c.inbox

structure Codec where
  decodeEnvelope : Bytes → Option (Option Witness × List Bytes)
  hash : Bytes → Nat
  canonical : Bytes → Bool

def firstMatches (codec : Codec) (entry : Entry) (txs : List Bytes) : Bool :=
  match txs with
  | [] => false
  | tx :: _ => decide (tx.length ≤ 8192) && codec.canonical tx && decide (codec.hash tx = entry.digest)

def scalarFacts (codec : Codec) (c : Context) (w : Witness) (txs : List Bytes) : ForcedFacts :=
  ⟨c.cursor.val, w.entry.timestamp.val, c.delay.val, c.anchorTimestamp.val,
    w.preimage.length, decide (codec.hash w.preimage = w.entry.digest),
    codec.canonical w.preimage, firstMatches codec w.entry txs⟩

/-- The model checks witness/index and MPT before checking the preimage or first transaction. -/
def evaluate (a : Authentication) (codec : Codec) (c : Context)
    (w : Option Witness) (txs : List Bytes) : Except Error Decision := do
  let hasPending ← pending c.cursor.val c.tail.val (w.map Witness.index)
  if !hasPending then return .ordinary
  match w with
  | none => Except.error (.missingWitness c.cursor.val)
  | some witness =>
    if a.verify c.stateRoot c.inbox (entrySlots a.slot c.cursor.val)
        witness.entry witness.proof then
      classify (scalarFacts codec c witness txs)
    else Except.error .malformed

/-- Trace-local binding, never global hash injectivity. -/
def LocallySeparated (hash : Bytes → Nat) (admitted candidate : Bytes) : Prop :=
  admitted ≠ candidate → hash admitted ≠ hash candidate

structure BuildRequest where
  parent : Nat
  attributes : Nat
  anchorHash : Nat
  transactions : List Bytes
  deriving DecidableEq

def singletonRequest (c : Context) (tx : Bytes) : BuildRequest :=
  ⟨c.parent, c.attributes, c.anchorHash, [tx]⟩

/-- Unavailable, malformed and incorrect-context responses cannot masquerade as empty execution. -/
inductive BuildResponse where
  | unavailable | malformed
  | completed (request : BuildRequest) (retained : List Bytes)
  deriving DecidableEq

/-- Authenticity of completed execution is an explicit external relation over the exact request. -/
structure Execution where
  run : BuildRequest → BuildResponse
  validExecution : BuildRequest → List Bytes → Prop
  sound : ∀ request returned retained,
    run request = .completed returned retained → validExecution returned retained

def singletonOutcome (request : BuildRequest) : BuildResponse → SingletonOutcome
  | .unavailable => .unavailable
  | .malformed => .malformed
  | .completed actual retained =>
    if actual ≠ request then .wrongContext
    else if retained.isEmpty then .completedEmpty else .retained

/-- Adapter outcome tied to the exact authenticated candidate singleton request. -/
def outcomeFor (execution : Execution) (c : Context) (w : Option Witness) : SingletonOutcome :=
  match w with
  | none => .unavailable
  | some witness =>
    let request := singletonRequest c witness.preimage
    singletonOutcome request (execution.run request)

/-- Cold finalization recomputes classification and execution evidence. -/
def execute (a : Authentication) (codec : Codec) (execution : Execution)
    (c : Context) (w : Option Witness) (txs : List Bytes) : Except Error Nat := do
  let d ← evaluate a codec c w txs
  let consumed ← resolve d (outcomeFor execution c w)
  advance c.cursor.val consumed

/-- A successful committed step carries concrete authenticated context and checked execution.
    Advancement is the checked reducer result, not an assumed conservation equation. -/
structure ValidStep (before after : Nat) (consumed : Option Nat) where
  authentication : Authentication
  codec : Codec
  execution : Execution
  context : Context
  witness : Option Witness
  transactions : List Bytes
  authenticated : ContextEvidence authentication context
  parentCursor : context.cursor.val = before
  decision : Decision
  classified : evaluate authentication codec context witness transactions = .ok decision
  resolved : resolve decision (outcomeFor execution context witness) = .ok consumed
  advancement : advance before consumed = .ok after

inductive ValidTrace : Nat → List (Option Nat) → Nat → Prop where
  | nil (cursor) : ValidTrace cursor [] cursor
  | cons {before middle after consumed rest} :
    ValidStep before middle consumed → ValidTrace middle rest after →
      ValidTrace before (consumed :: rest) after

def consumptionCount (steps : List (Option Nat)) : Nat :=
  (steps.filter Option.isSome).length

structure CacheEntry where
  context : Context
  envelope : Bytes
  decision : Decision
  outcome : SingletonOutcome
  deriving DecidableEq

/-- Exact canonical envelope equality is the model contract; production uses a locally-bound hash. -/
def cacheUsable (cache : CacheEntry) (c : Context) (envelope : Bytes) : Bool :=
  decide (cache.context = c ∧ cache.envelope = envelope)

/-- Hot finalization reuses checked intermediate values and still performs cursor advancement. -/
def finalizeCached (cache : CacheEntry) (c : Context) (envelope : Bytes) : Except Error Nat := do
  if !cacheUsable cache c envelope then Except.error .wrongContext else
    let consumed ← resolve cache.decision cache.outcome
    advance c.cursor.val consumed

/-- Cache evidence is about intermediate validation/execution, never the desired final cursor. -/
structure CacheEvidence (a : Authentication) (codec : Codec) (execution : Execution)
    (c : Context) (w : Option Witness) (txs : List Bytes) (cache : CacheEntry) : Prop where
  authenticated : ContextEvidence a c
  decoded : codec.decodeEnvelope cache.envelope = some (w, txs)
  classified : evaluate a codec c w txs = .ok cache.decision
  executed : cache.outcome = outcomeFor execution c w

/-- Successful durable writes round-trip; this law does not assert availability or termination. -/
structure DurableStore (Store : Type) where
  write : Store → Nat → Except Error Store
  reopen : Store → Except Error Nat
  roundtrip : ∀ before after cursor, write before cursor = .ok after → reopen after = .ok cursor

end Etna.FI
