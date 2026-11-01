import EtnaModel.TrustState

/-! Conditional §10.1 boundary gate. No DAO/timelock activation mechanism is supplied.
`none` is the unavailable production authority. A supplied ideal authority authenticates
exact decoded plans and the current finalized checkpoint; real enforcement is external.
This is not an extension of the original fixed-version ProtocolState.Trace. -/
namespace Etna.Design.UpgradeBoundary
open SigningBridge

/-- Rule/image metadata, not a native vote field or a new chain_id/app_version. -/
structure Version where
  client : Nat
  execution : Nat
  config : Hash
  images : List Hash
  grid : Nat
  deriving DecidableEq, Repr

/-- Arbitrary prior piecewise history. Boundaries remain significant if IDs recur. -/
structure Schedule where
  versionAt : Nat → Version
  boundaries : List Nat

def extendSchedule (s : Schedule) (height : Nat) (next : Version) : Schedule :=
  ⟨fun h => if h ≤ height then s.versionAt h else next, s.boundaries ++ [height]⟩

structure Plan where
  domain : Domain
  generation : Nat
  height : Nat
  previous : Version
  next : Version
  deriving DecidableEq, Repr

/-- Named ideal authentication inputs only. There is deliberately no constructor that
obtains these from a registered image, manifest, operator agreement or local flags. -/
structure Authority where
  plan : Plan → Bool
  checkpoint : Domain → Checkpoint → Bool

structure Job where
  deployment : Domain
  generation : Nat
  first : Nat
  last : Nat
  version : Version
  image : Hash
  statement : StatementData
  deriving DecidableEq, Repr

inductive Status | pending | settled | invalidated deriving DecidableEq, Repr
structure Work where
  job : Job
  status : Status
  deriving DecidableEq, Repr

structure System where
  world : ProtocolState.World
  node : TrustState.Node
  schedule : Schedule
  material : List Version
  jobs : List Work
  staged : Option Plan
  /-- Highest represented produced block in this generation, including unsigned blocks.
  This and the device log are local evidence, not global all-signer coordination. -/
  produced : Nat

/-- All old boundaries are retained and checked independently of version equality. -/
def noCrossing (s : Schedule) (p h : Nat) : Bool :=
  s.boundaries.all fun b => decide (h ≤ b ∨ b ≤ p)

def batchAllowed (s : System) (j : Job) : Bool :=
  decide (j.deployment = s.world.inbox.domain ∧ j.generation = s.world.inbox.generation ∧
    j.first < j.last ∧ j.version = s.schedule.versionAt (j.first+1) ∧
    j.version = s.schedule.versionAt j.last ∧ j.version.config = s.world.inbox.committeeConfig ∧
    j.image ∈ j.version.images ∧ j.first % j.version.grid = 0 ∧ j.last % j.version.grid = 0) &&
  noCrossing s.schedule j.first j.last &&
  (List.range' (j.first+1) (j.last-j.first)).all (fun h => decide (s.schedule.versionAt h = j.version)) &&
  (match s.staged with | none => true | some p => decide (j.last ≤ p.height))

/-- Full job identity is established before accepting a landing. Image/verifier truth
is still the original ideal verifier boundary; this gate only enforces policy metadata. -/
def settle (s : System) (index : Nat) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) : Option System :=
  match s.jobs[index]? with
  | none => none
  | some w =>
    if w.status = .pending ∧ batchAllowed s w.job = true ∧
        w.job.first = i.parentHeight ∧ w.job.last = i.lastHeight ∧
        w.job.generation = e.certificate.generation ∧ w.job.version.config = e.certificate.config ∧
        w.job.statement = e.certificate ∧ s.world.l1Block ≤ e.blockNumber then
      (land s.world.inbox i leaves e).map fun inbox =>
        { s with
          world := ProtocolState.landed s.world inbox e.blockNumber
          jobs := s.jobs.modify index fun old => { old with status := .settled } }
    else none

/-- Explicit invalidation changes status only, never the version/range/statement. -/
def invalidate (s : System) (index : Nat) : System :=
  { s with jobs := s.jobs.modify index fun w => { w with status := .invalidated } }

/-- Material registration has no activation effect. -/
def retainMaterial (s : System) (version : Version) : System :=
  { s with material := version :: s.material }

def logBelow (s : System) (height : Nat) : Bool :=
  s.node.signer.log.all fun r => decide (r.generation ≠ s.world.inbox.generation ∨ r.position.height ≤ height)

def planFits (s : System) (p : Plan) : Bool :=
  decide (p.domain = s.world.inbox.domain ∧ p.generation = s.world.inbox.generation ∧
    s.node.signer.domain = p.domain ∧ s.node.signer.activeGeneration = p.generation ∧
    p.previous = s.schedule.versionAt (p.height+1) ∧ p.previous = s.schedule.versionAt p.height ∧ p.previous.grid = s.world.inbox.gridK ∧
    p.previous.config = s.world.inbox.committeeConfig ∧ p.next.config = s.world.inbox.committeeConfig ∧
    (1 ≤ p.previous.grid ∧ p.previous.grid ≤ 6) ∧ (1 ≤ p.next.grid ∧ p.next.grid ≤ 6) ∧ p.next.images ≠ [] ∧
    p.height % p.previous.grid = 0 ∧ p.height % p.next.grid = 0 ∧
    p.next.grid ≤ s.world.inbox.configuration.unsettled ∧
    s.world.inbox.configuration.unsettled % p.next.grid = 0 ∧
    p.next.grid ≤ s.world.inbox.maxBatchBlocks ∧
    s.world.inbox.checkpoint.height ≤ p.height ∧ s.produced ≤ p.height) &&
  s.schedule.boundaries.all (fun b => decide (b < p.height)) && logBelow s p.height

/-- Staging authenticates the exact plan and installs a fresh-signing ceiling. A stopped
plan cannot be replaced; replanning needs a separate explicitly specified lifecycle. -/
def prepare (authority : Option Authority) (s : System) (p : Plan) : System :=
  match authority with
  | none => s
  | some auth => if s.staged.isNone && auth.plan p && planFits s p then { s with staged := some p } else s

def readyToSwitch (auth : Authority) (s : System) (p : Plan) : Bool :=
  auth.plan p && planFits s p &&
  auth.checkpoint s.world.inbox.domain s.world.inbox.checkpoint &&
  decide (s.world.inbox.checkpoint.height = p.height) &&
  s.jobs.all (fun w => w.status != .pending)

/-- Code K may change; every other field of the existing Inbox/World is kept. Materials,
old job identities, the complete node/session (including HRS log), and history ≤ H stay.
The persistence flag models an atomic decoded switching transaction, not EVM verification. -/
def applySwitch (s : System) (p : Plan) : System :=
  { s with
    world := { s.world with inbox := { s.world.inbox with gridK := p.next.grid } }
    schedule := extendSchedule s.schedule p.height p.next,
    material := p.next :: s.material, staged := none }

def activate (authority : Option Authority) (s : System) (persisted : Bool) : System :=
  match authority, s.staged with
  | some auth, some p => if persisted && readyToSwitch auth s p then applySwitch s p else s
  | _, _ => s

/-- Classification reads the pre-call durable head, before any signature persistence. -/
def cached (s : System) (encode : SignMessage → Hash) (m : SignMessage) : Bool :=
  match Signer.latest s.node.signer m.generation with
  | none => false
  | some old => decide (old.position = (messageRequest encode m true).position ∧ old.bytes = encode m)

def signingAllowed (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version) : Bool :=
  decide (m.domain = s.world.inbox.domain ∧ m.generation = s.world.inbox.generation ∧
    v = s.schedule.versionAt m.height ∧ v ∈ s.material) &&
  (cached s encode m || (match s.staged with | none => true | some p => decide (m.height ≤ p.height)))

/-- Boundary gate over the existing TrustState session, with its existing fixed encoder,
trust/restart and Signer authorization. The rule tag is job/application metadata only.
Denial never calls Signer.sign and never triggers the trust-timeout restart transition. -/
def sign (s : System) (encode : SignMessage → Hash) (m : SignMessage) (v : Version)
    (signature : Hash) (persisted : Bool) : Option (Signer.State × Hash) :=
  if signingAllowed s encode m v then TrustState.sign s.node encode m signature persisted else none

/-- Preparation/activation traces with fixed settlement history. A later successful
boundary requires separate settlement progress; the general per-switch theorem accepts
any prior schedule. Ordinary trust/EL/settlement events are separate checked bridges. -/
inductive SwitchTrace (authority : Option Authority) : System → System → Prop
  | refl (s : System) : SwitchTrace authority s s
  | stage {s t : System} (prior : SwitchTrace authority s t) (p : Plan) :
      SwitchTrace authority s (prepare authority t p)
  | switch {s t : System} (prior : SwitchTrace authority s t) (persisted : Bool) :
      SwitchTrace authority s (activate authority t persisted)

end Etna.Design.UpgradeBoundary
