import EtnaModel.CanonicalHistory

/-! Section 9 app/session events. Authentication is a decoded input contract, not a
network/finality algorithm. Node stores raw progress and a grant; only matching replay
can grant trust. Durability, exclusive key use and truthful own-L1 inputs remain external.
No globally latest view or unconditional post-withdrawal signing exclusion is asserted. -/
namespace Etna.Design.TrustState
open SigningBridge

/-- Authenticated own-finalized target and fixed origin. Replay validity, checkpoint
matching and snapshot provenance are deliberately not fields of this input. -/
structure Target where
  view : ProtocolState.World
  cfg : HistoricalContext.Parameters
  archive : List Nat
  rules : BlockValidity.Rules
  fixedConfiguration : cfg = Deployment.parameters view.inbox view.inbox.configuration
  constructed : HistoricalContext.build view.inbox view.registry cfg archive = some rules.consensus
  referenceFinalized : rules.referenceNumber ≤ view.l1Block
  generation : rules.consensus.generation = view.inbox.generation
  origin : BlockValidity.Header
  originHeight : origin.height = view.inbox.origin.height
  originRecord : ∃ cp, recordAt view.inbox view.inbox.origin.height = some cp ∧ headerMatches cp origin
  ownFinalized : BlockValidity.Anchor → Prop

structure Node where
  target : Option Target
  replay : List BlockValidity.Block
  extension : List BlockValidity.Block
  trusted : Bool
  signer : Signer.State
  restartNeeded : Bool
  halted : Bool

/-- Startup retains the authoritative stock signer state, but always closes its session. -/
def startup (signer : Signer.State) : Node :=
  ⟨none,[],[],false,{ signer with ready := false },false,false⟩

def close (s : Node) : Node :=
  { s with trusted := false, signer := { s.signer with ready := false } }

def observe (s : Node) (target : Target) : Node :=
  { close s with target := some target, replay := [], extension := [] }

def timeout (s : Node) : Node := { close s with restartNeeded := true }

def restart (s : Node) : Node := startup s.signer

/-- An authorized rollback cannot reuse an old grant or rewind the signer log. The
rollback's restored target must subsequently be authenticated and replayed again. -/
def rollback (s : Node) : Node := startup s.signer

def recover (s : Node) (target : Target) (persisted : Bool) : Node :=
  { observe s target with signer := (Signer.switchDomain s.signer target.view.inbox.domain
      target.view.inbox.generation (target.view.inbox.origin.height+1) true persisted) }

def nodes (target : Target) (blocks : List BlockValidity.Block) : Prop :=
  ∀ pair ∈ parentPairs target.origin blocks,
    BlockValidity.NodeValid target.rules (prefixHash target.origin blocks) target.ownFinalized pair.1 pair.2 ∧
    (prefixHeader target.origin blocks pair.2.header.anchor.checkpointHeight).isSome = true

def Replayed (s : Node) : Prop :=
  ∀ target, s.target = some target →
    BlockValidity.Chain target.rules target.origin (s.replay ++ s.extension) ∧ nodes target (s.replay ++ s.extension)

def MatchesTarget (s : Node) : Prop :=
  ∃ target, s.target = some target ∧
    headerMatches target.view.inbox.checkpoint (BlockValidity.terminal target.origin s.replay) ∧
    (BlockValidity.terminal target.origin s.replay).height < target.archive.length ∧
    target.view.inbox.generation = s.signer.activeGeneration

/-- Exact historical cached retries need no new committee/height veto. The producer
must satisfy these coordinates and membership for a fresh signing operation. -/
def EngineRequest (s : Node) (key : Hash) (m : SignMessage) : Prop :=
  ∃ target, s.target = some target ∧ m.domain = target.rules.consensus.domain ∧
    m.generation = target.rules.consensus.generation ∧
    m.height = (BlockValidity.terminal (BlockValidity.terminal target.origin s.replay) s.extension).height+1 ∧
    ∃ e ∈ (Consensus.activeAt target.rules.consensus m.height).members, e.key = key

def sign (s : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (signature : Hash) (persisted : Bool) : Option (Signer.State × Hash) :=
  Signer.sign s.signer (messageRequest encode m (s.trusted && !s.restartNeeded)) signature persisted

/-- A persisted signing position is either still the cache head with identical bytes,
or a later HRS is now the cache head. This talks about the modeled durable log only. -/
def Protected (s : Node) (old : Signer.Signed) : Prop :=
  ∃ current, Signer.latest s.signer old.generation = some current ∧
    ((current.position = old.position ∧ current.bytes = old.bytes) ∨
      Signer.before old.position current.position = true)

def serve (s : Node) : Bool := s.trusted && !s.halted

/-- Missing material and timeouts are events, never replay success. Each progress event
validates actual accumulated blocks with NodeValid, including the local checkpoint fence.
A target change discards the previous grant even if its height happens to be equal.
The immutable device key/encoder parameterize the entire trace. `freshProducer` is a
logical precondition for permitting the call, not a post-write filter; implementations
must establish it before the durable signing operation. Exact cache returns are exempt
from fresh selection but still pass current session trust and stock authorization. -/
inductive Step (key : Hash) (encode : SignMessage → Hash) : Node → Node → Prop
  | observeEvent (s : Node) (target : Target) (running : s.halted = false) : Step key encode s (observe s target)
  | progress {s : Node} {target : Target} (more : List BlockValidity.Block)
      (selected : s.target = some target) (closed : s.trusted = false) (running : s.halted = false) (noExtension : s.extension = [])
      (valid : BlockValidity.Chain target.rules target.origin (s.replay ++ more))
      (accepted : nodes target (s.replay ++ more)) : Step key encode s { s with replay := s.replay ++ more }
  | extend {s : Node} {target : Target} (more : List BlockValidity.Block)
      (selected : s.target = some target) (ready : s.trusted = true) (running : s.halted = false)
      (valid : BlockValidity.Chain target.rules target.origin (s.replay ++ (s.extension ++ more)))
      (accepted : nodes target (s.replay ++ (s.extension ++ more))) :
      Step key encode s { s with extension := s.extension ++ more }
  | matched {s : Node} {target : Target} (selected : s.target = some target)
      (running : s.halted = false)
      (exactMatch : headerMatches target.view.inbox.checkpoint (BlockValidity.terminal target.origin s.replay))
      (covered : (BlockValidity.terminal target.origin s.replay).height < target.archive.length)
      (generation : target.view.inbox.generation = s.signer.activeGeneration) :
      Step key encode s { s with trusted := true }
  | missing (s : Node) : Step key encode s (close s)
  | timeoutEvent (s : Node) : Step key encode s (timeout s)
  | restartEvent (s : Node) (running : s.halted = false) : Step key encode s (restart s)
  | rollbackEvent (s : Node) : Step key encode s (rollback s)
  | recovery (s : Node) (target : Target) (persisted : Bool) (running : s.halted = false) :
      Step key encode s (recover s target persisted)
  | open (s : Node) (authoritative : Bool) :
      Step key encode s { s with signer := Signer.openSession s.signer s.signer.activeGeneration (s.trusted && !s.restartNeeded) authoritative }
  | signed {s : Node} (m : SignMessage)
      (signature returned : Hash) (persisted : Bool) (after : Signer.State)
      (result : sign s encode m signature persisted = some (after,returned))
      (freshProducer : after.log ≠ s.signer.log → EngineRequest s key m) :
      Step key encode s { s with signer := after }
  | contradiction (s : Node) : Step key encode s { close s with halted := true }

inductive Trace (key : Hash) (encode : SignMessage → Hash) : Node → Node → Prop
  | refl (s : Node) : Trace key encode s s
  | step {s t u : Node} (prior : Trace key encode s t) (event : Step key encode t u) : Trace key encode s u

def Reachable (key : Hash) (encode : SignMessage → Hash) (s : Node) : Prop :=
  ∃ initial, Trace key encode (startup initial) s

end Etna.Design.TrustState
