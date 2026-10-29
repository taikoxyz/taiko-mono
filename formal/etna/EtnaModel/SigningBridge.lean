import EtnaModel.Deployment
import EtnaModel.Signer

/-! Typed refinement of the existing signer and node inputs. No signer/contract guard is
changed. A verified adapter must bind these fields to actual L1/EL data, Comet requests,
canonical sign bytes and the immutable device key. In particular, own-finalized truth
and the request engine's membership/next-height discipline are explicit boundaries.
No key exclusion, positive collateral or selected-cutoff inequality is a field. -/
namespace Etna.Design.SigningBridge

inductive SignPhase | proposalMsg | prevoteMsg | precommitMsg
  deriving DecidableEq, Repr

def phaseStep : SignPhase → Nat
  | .proposalMsg => 1
  | .prevoteMsg => 2
  | .precommitMsg => 3

/-- blockId zero represents a nil vote. Retained candidates use their original block id;
all phases are bound to the same domain/generation/height/round as the actual request. -/
structure SignMessage where
  domain : Domain
  generation : Nat
  height : Nat
  round : Nat
  phase : SignPhase
  blockId : Hash
  deriving DecidableEq, Repr

def messageRequest (encode : SignMessage → Hash) (m : SignMessage) (trusted : Bool) : Signer.Request :=
  ⟨m.domain,m.generation,trusted,⟨m.height,m.round,phaseStep m.phase⟩,encode m⟩

structure KeyedDevice where
  key : Hash
  state : Signer.State
  encode : SignMessage → Hash
  signatureRelation : Hash → SignMessage → Hash → Prop

/-- Selection coordinates from one authenticated chain archive. Registry histories may
advance after settlement; their whole functions need not be equal. -/
def SameSigningHistory (a b : Consensus.Context) : Prop :=
  a.domain = b.domain ∧ a.generation = b.generation ∧ a.originHeight = b.originHeight ∧
  a.originBlock = b.originBlock ∧ a.genesisCutoff = b.genesisCutoff ∧
  a.epochLen = b.epochLen ∧ a.anchorAt = b.anchorAt

/-- A snapshot has either the exact initialization/recovery floor or a real accepted
batch source under this same decoded consensus history. The floor constructor reads a
specific stored value; it is not an arbitrary future-cutoff or exclusion hypothesis. -/
inductive SnapshotSource (s : State) (ctx : Consensus.Context) : Prop
  | atFloor (stored : s.snapshot = Settlement.floor ctx) : SnapshotSource s ctx
  | acceptedBatch {before : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      {r : BlockValidity.Rules} {parent : BlockValidity.Header} {blocks : List BlockValidity.Block}
      {blobs : List Hash} (accepted : land before i leaves e = some s)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (sameHistory : SameSigningHistory r.consensus ctx) : SnapshotSource s ctx
  | carriedBatch {before settled : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      {r : BlockValidity.Rules} {parent : BlockValidity.Header} {blocks : List BlockValidity.Block}
      {blobs : List Hash} (accepted : land before i leaves e = some settled)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (sameHistory : SameSigningHistory r.consensus ctx)
      (checkpointKept : s.checkpoint = settled.checkpoint) (snapshotKept : s.snapshot = settled.snapshot) :
      SnapshotSource s ctx
  | extendedArchive {before settled historyState : State} {i : LandInput} {leaves : List Leaf}
      {e : LandingEnv} {r : BlockValidity.Rules} {parent : BlockValidity.Header}
      {blocks : List BlockValidity.Block} {blobs : List Hash}
      {oldRegistry newRegistry : RegistryHistory.State} {params : HistoricalContext.Parameters}
      {oldArchive more : List Nat} (accepted : land before i leaves e = some settled)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (oldHistory : r.consensus = HistoricalContext.derive historyState oldRegistry params oldArchive)
      (newHistory : ctx = HistoricalContext.derive historyState newRegistry params (oldArchive ++ more))
      (covered : settled.checkpoint.height < oldArchive.length)
      (checkpointKept : s.checkpoint = settled.checkpoint) (snapshotKept : s.snapshot = settled.snapshot) :
      SnapshotSource s ctx
  | beforeRecovery {before settled : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      {r : BlockValidity.Rules} {parent : BlockValidity.Header} {blocks : List BlockValidity.Block}
      {blobs : List Hash} (accepted : land before i leaves e = some settled)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (referenceBound : i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber)
      (newGeneration : ctx.generation ≠ 0) (precedesOrigin : e.blockNumber ≤ ctx.originBlock)
      (checkpointKept : s.checkpoint = settled.checkpoint) (snapshotKept : s.snapshot = settled.snapshot) :
      SnapshotSource s ctx

def headerMatches (cp : Checkpoint) (h : BlockValidity.Header) : Prop :=
  h.height = cp.height ∧ h.elHash = cp.elHash ∧ h.cometHash = cp.cometHash ∧ h.cursor = cp.cursor

def prefixHeader (origin : BlockValidity.Header) (blocks : List BlockValidity.Block) (height : Nat) :
    Option BlockValidity.Header :=
  (origin :: blocks.map BlockValidity.Block.header).find? (fun h => h.height == height)

def prefixHash (origin : BlockValidity.Header) (blocks : List BlockValidity.Block) (height : Nat) : Hash :=
  ((prefixHeader origin blocks height).map BlockValidity.Header.elHash).getD 0

def parentPairs (origin : BlockValidity.Header) (blocks : List BlockValidity.Block) :
    List (BlockValidity.Header × BlockValidity.Block) :=
  (origin :: blocks.map BlockValidity.Block.header).zip blocks

/-- Replay starts at the authenticated fixed origin and exactly matches BOTH checkpoint
hashes. Its validated extension, shared anchor archive and committee schedule are used
by the actual signing request. Own-finalized/header/storage/EL authentication is supplied
by the adapter, not inferred from a boolean or prefix maximum. -/
structure TrustedPrefix (view : ProtocolState.World) where
  cfg : HistoricalContext.Parameters
  archive : List Nat
  rules : BlockValidity.Rules
  fixedConfiguration : cfg = Deployment.parameters view.inbox view.inbox.configuration
  constructed : HistoricalContext.build view.inbox view.registry cfg archive = some rules.consensus
  referenceFinalized : rules.referenceNumber ≤ view.l1Block
  origin : BlockValidity.Header
  replay : List BlockValidity.Block
  extension : List BlockValidity.Block
  originHeight : origin.height = view.inbox.origin.height
  originRecord : ∃ cp, recordAt view.inbox view.inbox.origin.height = some cp ∧ headerMatches cp origin
  replayValid : BlockValidity.Chain rules origin replay
  extensionValid : BlockValidity.Chain rules (BlockValidity.terminal origin replay) extension
  checkpoint : headerMatches view.inbox.checkpoint (BlockValidity.terminal origin replay)
  archiveCovered : (BlockValidity.terminal (BlockValidity.terminal origin replay) extension).height < archive.length
  snapshotSource : SnapshotSource view.inbox rules.consensus
  ownFinalized : BlockValidity.Anchor → Prop
  nodeAccepted : ∀ pair ∈ parentPairs origin (replay ++ extension),
    BlockValidity.NodeValid rules (prefixHash origin (replay ++ extension)) ownFinalized pair.1 pair.2 ∧
    (prefixHeader origin (replay ++ extension) pair.2.header.anchor.checkpointHeight).isSome = true

def TrustedPrefix.tip {view : ProtocolState.World} (p : TrustedPrefix view) : BlockValidity.Header :=
  BlockValidity.terminal (BlockValidity.terminal p.origin p.replay) p.extension

/-- A confirmation checkpoint is actually on the replayed chain, with its source batch
bound to the same decoded history. This is stronger than comparing naked heights.
It does not claim a lagging own-finalized view contains a newer confirmation. -/
structure IncludedCheckpoint (confirmed : ProtocolState.World) {view : ProtocolState.World}
    (p : TrustedPrefix view) where
  before : List BlockValidity.Block
  remaining : List BlockValidity.Block
  decomposition : p.replay = before ++ remaining
  checkpointBinding : headerMatches confirmed.inbox.checkpoint (BlockValidity.terminal p.origin before)
  source : SnapshotSource confirmed.inbox p.rules.consensus

/-- The Comet/application refinement required of the request producer. Nil votes and
retained candidates at the active height use the same membership rule. This predicate
is not a new gate in Signer.sign and is not derived from Request.trusted alone. -/
def EngineRequest {view : ProtocolState.World} (p : TrustedPrefix view) (key : Hash) (m : SignMessage) : Prop :=
  m.domain = p.rules.consensus.domain ∧ m.generation = p.rules.consensus.generation ∧
  m.height = p.tip.height+1 ∧
  ∃ e ∈ (Consensus.activeAt p.rules.consensus m.height).members, e.key = key

/-- An actual successful call of the existing Signer.sign, observed at a later protocol
World. A changed durable log denotes a new modeled signing event; unchanged cached
returns are separate. The encoding/key authentication fields are adapter obligations. -/
structure ObservedCall {view : ProtocolState.World} (p : TrustedPrefix view) where
  device : KeyedDevice
  message : SignMessage
  request : Signer.Request
  decoded : request = messageRequest device.encode message request.trusted
  observed : ProtocolState.World
  viewToObservation : ProtocolState.Trace view observed
  supplied : Hash
  persisted : Bool
  after : Signer.State
  returned : Hash
  result : Signer.sign device.state request supplied persisted = some (after,returned)
  authentic : device.signatureRelation device.key message returned

end Etna.Design.SigningBridge
