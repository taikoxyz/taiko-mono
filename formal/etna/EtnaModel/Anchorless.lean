import EtnaModel.Common

/-! Design-only ANCHORLESS §§2–4,7–8. Canonical L1 roots, decoded storage-proof
soundness, identical EL pre-execution and atomic decoded upgrade transactions are
primitive boundaries. This is not an EIP bytecode, MPT, Bridge payout or production
refinement. Canonical history excludes merely preconfirmed/future-invalid blocks. -/
namespace Etna.Design.Anchorless

structure Header where
  timestamp : Nat
  anchorNumber : Nat
  encodedNumber : Nat
  root : Nat
  extraBytes : Nat
  deriving DecidableEq

structure Entry where
  timestamp : Nat
  root : Nat
  deriving DecidableEq

abbrev Ring := Nat → Option Entry

/-- Ideal upstream write, including zero roots before Etna; no code silently does nothing.
Genesis has no write. A write replaces the whole timestamp/root pair at this slot. -/
def write (code : Bool) (ring : Ring) (h : Header) : Ring :=
  if code then fun slot => if slot = h.timestamp % 8191 then some ⟨h.timestamp,h.root⟩ else ring slot
  else ring

/-- Ideal EIP getter for decoded 32-byte input. It rejects timestamp zero and absent/
overwritten timestamp pairs, but does not reject zero roots or impose an age/future guard. -/
def beaconGet (code : Bool) (ring : Ring) (timestamp : Nat) : Option Nat :=
  if code && decide (timestamp ≠ 0) then
    match ring (timestamp % 8191) with
    | some entry => if entry.timestamp = timestamp then some entry.root else none
    | none => none
  else none

structure RootState where
  clock : Nat
  code : Bool
  ring : Ring
  /-- Current VERSION checkpoints only; flat storage is deliberately not consulted. -/
  checkpoints : Nat → Option Nat
  flatCheckpoints : Nat → Option Nat

def initialRoots : RootState := ⟨0,false,fun _ => none,fun _ => none,fun _ => none⟩

def execute (s : RootState) (h : Header) : RootState :=
  { s with clock := h.timestamp, ring := write s.code s.ring h }

/-- EL shape checks alone are insufficient. Post-fork accepted canonical headers also
bind the decoded anchor number and root to ideal authenticated L1 ancestry. No proposal/
default-manifest production rules are inferred from the stale part of ANCHORLESS. -/
def ValidHeader (l1 : Nat → Nat) (fork : Nat) (h : Header) : Prop :=
  if h.timestamp < fork then h.root = 0 ∧ h.extraBytes = 7
  else h.root ≠ 0 ∧ h.extraBytes = 13 ∧ h.encodedNumber = h.anchorNumber ∧ h.root = l1 h.anchorNumber

inductive RootStep (l1 : Nat → Nat) (fork : Nat) : RootState → RootState → Prop
  /-- Overapproximate arbitrary legacy-layout bytes; current authorization never reads
  them. This event grants no ability to mutate VERSION checkpoints or the EIP ring. -/
  | legacyStorage (s : RootState) (flat : Nat → Option Nat) :
      RootStep l1 fork s { s with flatCheckpoints := flat }
  | deploy (s : RootState) : RootStep l1 fork s { s with code := true }
  | block {s : RootState} (h : Header) (later : s.clock < h.timestamp)
      (valid : ValidHeader l1 fork h) : RootStep l1 fork s (execute s h)
  /-- Decoded pre-fork anchor calldata authenticated against canonical L1 ancestry.
  This is the original guest boundary, not trust in the public golden-touch key. -/
  | checkpoint {s : RootState} (number root : Nat) (before : s.clock < fork)
      (range : number < limit48) (binding : root = l1 number) :
      RootStep l1 fork s { s with checkpoints := fun n => if n = number then some root else s.checkpoints n }

inductive RootRun (l1 : Nat → Nat) (fork : Nat) : RootState → Prop
  | genesis : RootRun l1 fork initialRoots
  | step {s t : RootState} (prior : RootRun l1 fork s) (event : RootStep l1 fork s t) : RootRun l1 fork t

/-- Only the verifying timestamp selects the meaning of blockId; numeric domains may overlap.
The provider flag models a missing getL1StateRoot implementation/failed external call. -/
def resolve (fork : Nat) (s : RootState) (provider : Bool) (blockId : Nat) : Option Nat := do
  if !provider then none else do
    let root ← if s.clock < fork then
      if blockId < limit48 then s.checkpoints blockId else none
    else if fork ≤ blockId then beaconGet s.code s.ring blockId else none
    if root ≠ 0 then some root else none

def anchorV4 (fork now : Nat) (ancestorsPass : Bool) : Bool :=
  decide (now < fork) && ancestorsPass

structure SourceDomain where
  chain : Nat
  signalService : Nat
  deriving DecidableEq

structure HopProof where
  blockId : Nat
  root : Nat
  chain : Nat
  account : Nat
  slot : Nat
  deriving DecidableEq

/-- Fixed deployment domain and requested signal slot are checked independently of the
untrusted proof's own root, account and storage coordinates. `verify` is the ideal decoded
account/storage proof checker; its cryptographic soundness is stated separately. -/
def checkProof (fork : Nat) (s : RootState) (provider : Bool) (domain : SourceDomain)
    (verify : HopProof → Bool) (slot : Nat) (p : HopProof) : Bool :=
  decide (resolve fork s provider p.blockId = some p.root) &&
    decide (p.chain = domain.chain) && decide (p.account = domain.signalService) &&
    decide (p.slot = slot) && verify p

/-- Primitive storage-proof soundness at canonical L1 roots; no authorization/cache
conclusion appears in this boundary. `stored number chain account slot` is the actual
source-state fact under that canonical root. Real MPT and address/slot encoding are external. -/
def StorageSound (l1 : Nat → Nat) (verify : HopProof → Bool)
    (stored : Nat → Nat → Nat → Nat → Prop) : Prop :=
  ∀ p number, verify p = true → p.root = l1 number → stored number p.chain p.account p.slot

structure Cache where
  flat : List Nat
  current : List Nat
  deriving DecidableEq

/-- New SignalServiceL2 authorization reads only VERSION, even before the timestamp fork. -/
def cached (cache : Cache) (slot : Nat) : Bool := decide (slot ∈ cache.current)

/-- Only the off-chain prover's parent-checkpoint reader may use the old flat fallback. -/
def proverCheckpoint (current flat : Nat → Option Nat) (number : Nat) : Option Nat :=
  match current number with
  | some root => some root
  | none => flat number

inductive CacheRun (l1 : Nat → Nat) (fork : Nat) (domain : SourceDomain) (verify : HopProof → Bool) :
    RootState → Cache → Prop
  | initial (flat : List Nat) : CacheRun l1 fork domain verify initialRoots ⟨flat,[]⟩
  | roots {s t : RootState} {cache : Cache} (prior : CacheRun l1 fork domain verify s cache)
      (event : RootStep l1 fork s t) : CacheRun l1 fork domain verify t cache
  | prove {s : RootState} {cache : Cache} (prior : CacheRun l1 fork domain verify s cache)
      (slot : Nat) (p : HopProof) (accepted : checkProof fork s true domain verify slot p = true) :
      CacheRun l1 fork domain verify s { cache with current := slot :: cache.current }

/-- Migration prerequisites are actual completed stages, not arbitrary authorization flags.
Atomicity of decoded DAO/DelegateController transactions is an external primitive; this
model neither creates owner authority nor verifies transport/transaction implementation. -/
structure Installation where
  forkTime : Nat
  clock : Nat
  identicalCalls : Bool
  historyCode : Bool
  beaconCode : Bool
  dualReaders : Bool
  images : Bool
  anchor : Bool
  signal : Bool
  deriving DecidableEq

def initialInstallation (fork : Nat) : Installation := ⟨fork,0,false,false,false,false,false,false,false⟩

/-- Image trust precedes proxies. The final Anchor timestamp probe is represented by
anchorOK; a missing upgrade or any failed action reverts both proxies atomically. -/
def pairedUpgrade (s : Installation) (anchorOK signalOK : Bool) : Installation :=
  if s.identicalCalls && s.historyCode && s.beaconCode && s.dualReaders && s.images && anchorOK && signalOK && decide (s.clock < s.forkTime)
  then { s with anchor := true, signal := true } else s

/-- A rollback to flat code would revive stale checkpoints/cache, so it is prohibited. -/
def rollbackFlat (s : Installation) : Option Installation :=
  if s.signal then none else some s

inductive InstallStep : Installation → Installation → Prop
  | advance (s : Installation) (now : Nat) (later : s.clock ≤ now) :
      InstallStep s { s with clock := now }
  | engines (s : Installation) : InstallStep s { s with identicalCalls := true }
  | history {s : Installation} (ready : s.identicalCalls = true) : InstallStep s { s with historyCode := true }
  | beacon {s : Installation} (ready : s.historyCode = true) : InstallStep s { s with beaconCode := true }
  | readers {s : Installation} (ready : s.beaconCode = true) : InstallStep s { s with dualReaders := true }
  | images {s : Installation} (ready : s.dualReaders = true) : InstallStep s { s with images := true }
  | pair (s : Installation) (anchorOK signalOK : Bool) : InstallStep s (pairedUpgrade s anchorOK signalOK)
  | rollback {s t : Installation} (accepted : rollbackFlat s = some t) : InstallStep s t

inductive InstallRun (fork : Nat) : Installation → Prop
  | initial : InstallRun fork (initialInstallation fork)
  | step {s t : Installation} (prior : InstallRun fork s) (event : InstallStep s t) : InstallRun fork t

/-- Timestamp scheduling remains a parameter. Activation requires identical client/Anchor
times as well as completed prerequisite deployment; mismatched schedules fail this design
readiness check and may cause real liveness failure, not arbitrary authorization. -/
def activate (s : Installation) (clientFork : Nat) : Bool :=
  s.identicalCalls && s.historyCode && s.beaconCode && s.dualReaders && s.images &&
    s.anchor && s.signal && decide (s.forkTime = clientFork) && decide (s.forkTime ≤ s.clock)

/-- Only the new service's authorization entry point is modeled. Empty proofs read its
current namespace; uncached proofs use the actually installed Anchor provider. Legacy
service authorization and message payouts are outside this interface. -/
def authorize (installation : Installation) (s : RootState) (cache : Cache)
    (domain : SourceDomain) (verify : HopProof → Bool) (slot : Nat) (proof : Option HopProof) : Bool :=
  installation.signal && match proof with
    | none => cached cache slot
    | some p => checkProof installation.forkTime s installation.anchor domain verify slot p

/-- The service fixes its source deployment and ideal slot adapter for its entire history.
No request chooses a raw slot or replaces the adapter. Real Keccak/ABI encoding and
collision resistance remain external; the isolation results explicitly require separation. -/
structure ServiceConfig where
  domain : SourceDomain
  slotOf : Nat → Nat → Nat → Nat

structure ServiceRequest where
  sourceChain : Nat
  app : Nat
  signal : Nat
  deriving DecidableEq

def requestSlot (config : ServiceConfig) (request : ServiceRequest) : Nat :=
  config.slotOf request.sourceChain request.app request.signal

def serviceAuthorize (config : ServiceConfig) (installation : Installation) (s : RootState)
    (cache : Cache) (verify : HopProof → Bool) (request : ServiceRequest) (proof : Option HopProof) : Bool :=
  decide (request.sourceChain = config.domain.chain) &&
    authorize installation s cache config.domain verify (requestSlot config request) proof

/-- Raw service requests use one immutable adapter/deployment, real installed proxies and
their actual derived slots. Root writes and legacy bytes cannot change the service config. -/
inductive ServiceRun (config : ServiceConfig) (l1 : Nat → Nat) (fork : Nat) (verify : HopProof → Bool) :
    RootState → Cache → Prop
  | initial (flat : List Nat) : ServiceRun config l1 fork verify initialRoots ⟨flat,[]⟩
  | roots {s t : RootState} {cache : Cache} (prior : ServiceRun config l1 fork verify s cache)
      (event : RootStep l1 fork s t) : ServiceRun config l1 fork verify t cache
  | prove {s : RootState} {cache : Cache} (prior : ServiceRun config l1 fork verify s cache)
      (installation : Installation) (migration : InstallRun fork installation)
      (time : installation.clock ≤ s.clock) (request : ServiceRequest) (p : HopProof)
      (accepted : serviceAuthorize config installation s cache verify request (some p) = true) :
      ServiceRun config l1 fork verify s { cache with current := requestSlot config request :: cache.current }

end Etna.Design.Anchorless
