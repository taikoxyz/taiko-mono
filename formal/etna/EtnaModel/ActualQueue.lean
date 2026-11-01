import EtnaModel.CanonicalHistory
import EtnaModel.AnchorHonesty

/-! Semantic L1 time and end-block openings supplement the original decoded transition
machine. `states` retains transaction order, including multiple calls in one L1 block.
An opening splits that same journal after every transaction at its block. The primitive
hash/parser/singleton functions below are ideal interfaces, not implementation proofs. -/
namespace Etna.Design.ActualQueue
open ProtocolState

/-- The EVM records block.timestamp on admission; no other transaction chooses a timestamp. -/
inductive EnqueueTime (time : Nat → Nat) : {w t : World} → Step w t → Prop
  | landing {w : World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (order : w.l1Block ≤ e.blockNumber) (ok : Etna.Design.land w.inbox i leaves e = some s) :
      EnqueueTime time (.landing order ok)
  | registration {w : World} {s : RegistryHistory.State} {key owner amount now : Nat}
      (order : w.l1Block ≤ now) (ok : RegistryHistory.register w.registry key owner amount now = some s) :
      EnqueueTime time (.registration order ok)
  | modification {w : World} {s : RegistryHistory.State} {id now : Nat} {action : RegistryHistory.Edit}
      (order : w.l1Block ≤ now) (callable : publicEdit action = true)
      (ok : RegistryHistory.edit w.registry w.inbox id now action = some s) :
      EnqueueTime time (.modification order callable ok)
  | enqueue {w : World} {s : State} {hash timestamp now raw paid : Nat} {refund : Bool}
      (order : w.l1Block ≤ now) (blockRange : now < limit48) (timestampRange : timestamp < limit48)
      (ok : Forced.enqueue w.inbox raw paid refund = some s) (clock : timestamp = time now) :
      EnqueueTime time (.enqueue (hash := hash) order blockRange timestampRange ok)
  | sweep {w : World} {s : State} {now : Nat} {transfer : Bool}
      (order : w.l1Block ≤ now) (ok : Forced.sweep w.inbox transfer = some s) :
      EnqueueTime time (.sweep order ok)
  | recovery {w : World} {s : Recovery.World} {a : Recovery.Request} {r : Origin}
      {owner externalOK : Bool} (order : w.l1Block ≤ r.l1Block)
      (ok : Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK = some s) :
      EnqueueTime time (.recovery order ok)
  | invalidation {w : World} {s : State} {expected now : Nat} {owner : Bool}
      (order : w.l1Block ≤ now)
      (ok : Recovery.invalidateRecoveryNonce w.inbox expected owner = some s) :
      EnqueueTime time (.invalidation order ok)
  | rollback {w : World} (trusted : Checkpoint) (snapshot now : Nat)
      (order : w.l1Block ≤ now) (retained : recordAt w.inbox trusted.height = some trusted)
      (authorized : Recovery.NonceMutable w.inbox) :
      EnqueueTime time (.rollback trusted snapshot now order retained authorized)

/-- Ordered original calls with the one missing environmental timestamp binding. -/
inductive Transactions (time : Nat → Nat) : World → List World → World → Prop
  | nil (w : World) : Transactions time w [] w
  | step {first w t : World} {states : List World}
      (prior : Transactions time first states w) (call : Step w t)
      (timestamp : EnqueueTime time call) : Transactions time first (states ++ [t]) t

/-- A timestamp annotation on an existing original trace, including a canonical Run's
unchanged run_trace projection. It retains each original transition constructor. -/
inductive TraceTime (time : Nat → Nat) : {initial current : World} → Trace initial current → Prop
  | refl (w : World) : TraceTime time (.refl w)
  | step {initial w t : World} {trace : Trace initial w} (prior : TraceTime time trace)
      (call : Step w t) (timestamp : EnqueueTime time call) : TraceTime time (.step trace call)

/-- A raw end-of-block state opening on one fixed transaction journal. Strict `after`
includes all same-block transactions in the prefix; neither queue timing nor coverage
is asserted. The L1/header/storage adapter supplies this cut and the two decoded fields. -/
structure EndBlock (time : Nat → Nat) (initial current : World) (states : List World)
    (anchor : BlockValidity.Anchor) where
  snapshot : World
  priorStates : List World
  laterStates : List World
  order : priorStates ++ laterStates = states
  before : Transactions time initial priorStates snapshot
  later : Transactions time snapshot laterStates current
  closed : snapshot.l1Block ≤ anchor.number
  after : ∀ state ∈ laterStates, anchor.number < state.l1Block
  timestamp : anchor.timestamp = time anchor.number
  tail : anchor.tail = snapshot.inbox.tail

/-- The guest's generation origin is read from the current Inbox, as Deployment.build
specifies. This raw field binding is independent of queue service or anchor coverage. -/
def OriginMatches (rules : BlockValidity.Rules) (current : World) : Prop :=
  rules.consensus.originBlock = current.inbox.origin.l1Block

/-- All accepted L1 roots open the same original journal, not a separately chosen queue. -/
def Anchors (time : Nat → Nat) (initial current : World) (states : List World)
    (r : BlockValidity.Rules) : Prop :=
  ∀ anchor, r.anchorAuthenticated anchor = true → Nonempty (EndBlock time initial current states anchor)

abbrev Bytes := List UInt8

/-- Ideal complete decoding and deterministic singleton EL execution. The singleton
context is the actual parent/header, without a caller-chosen execution-result field. -/
structure Primitives where
  hashBytes : Bytes → Hash
  canonical : Bytes → Bool
  buildSingleton : BlockValidity.Header → BlockValidity.Header → Bytes → Forced.Singleton

/-- Actual byte decoding and deterministic EL result under the exact local context. -/
def PayloadFields (primitive : Primitives) (parent : BlockValidity.Header)
    (block : BlockValidity.Block) (witness : Forced.Witness) (raw : Bytes) (first : Option Bytes) : Prop :=
  witness.rawBytes = raw.length ∧ witness.rawHash = primitive.hashBytes raw ∧
  witness.canonical = primitive.canonical raw ∧
  witness.firstHash = first.map primitive.hashBytes ∧
  witness.firstCanonical = (first.map primitive.canonical).getD false ∧
  witness.firstBytes = (first.map List.length).getD 0 ∧
  block.singleton = primitive.buildSingleton parent block.header raw

/-- Low-level storage and decoded-payload truth. Storage opens the same end-block
snapshot; raw/position-zero bytes and complete singleton execution fix the flags.
No acceptance, due-ness or cursor advancement is asserted. -/
def WitnessOpening (primitive : Primitives) (snapshot : World) (parent : BlockValidity.Header)
    (block : BlockValidity.Block) (witness : Forced.Witness) : Prop :=
  ∃ (raw : Bytes) (first : Option Bytes),
    (witness.index,witness.stored) ∈ snapshot.queue ∧ witness.storageAuthenticated = true ∧
    PayloadFields primitive parent block witness raw first

/-- Included canonical position-zero bytes, or hash-bound raw bytes whose canonical parse
fails or whose completed singleton is empty. A timeout/retained singleton is not a skip. -/
def ByteAction (primitive : Primitives) (parent : BlockValidity.Header)
    (block : BlockValidity.Block) (entry : Forced.Entry) (raw : Bytes) (first : Option Bytes) : Prop :=
  (∃ tx, first = some tx ∧ primitive.hashBytes tx = entry.txHash ∧
    primitive.canonical tx = true ∧ tx.length ≤ 8192) ∨
  (primitive.hashBytes raw = entry.txHash ∧ raw.length ≤ 8192 ∧
    (primitive.canonical raw = false ∨ primitive.buildSingleton parent block.header raw = .completedEmpty))

/-- Soundness of the named storage and payload adapters, including local unlanded blocks.
This is an ideal L1/crypto/EL boundary, separate from the seven headline premises and
from InputsAuthenticated (which quantifies only over submitted landings). -/
def Openings (primitive : Primitives) (time : Nat → Nat) (initial current : World)
    (states : List World) (r : BlockValidity.Rules) : Prop :=
  ∀ parent block witness, r.anchorAuthenticated block.header.anchor = true →
    r.executionValid parent block = true → r.payloadValid block = true → r.forcedAuthenticated block.header.anchor witness = true →
    block.forced = some witness →
    ∃ cut : EndBlock time initial current states block.header.anchor,
      WitnessOpening primitive cut.snapshot parent block witness

end Etna.Design.ActualQueue
