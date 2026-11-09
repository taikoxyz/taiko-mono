import EtnaModel.CurrentBlocks
import EtnaModel.CurrentFinality
import EtnaModel.CurrentRegistryPayments
import EtnaModel.CurrentArchive

/-! The current transaction machine. Historical state records are data types only: every
current public transition is defined here, with S-relative grids, anchored rule schedules,
permanent bonds, atomic token effects and transaction-complete L1 snapshots. -/
namespace Etna.Design.Current.Protocol

structure Core where
  domain : Domain
  owner : Nat
  originWriter : Nat
  unzenInbox : Nat
  forkTime : Nat
  slashSink : Nat
  deriving DecidableEq, Repr

structure Parameters where
  gridK : Nat
  epochLen : Nat
  genesisCutoff : Nat
  committee : CommitteeConfig
  forcedDelay : Nat
  maxAnchorAge : Nat
  maxBatchBlocks : Nat
  forcedFee : Nat
  forcedThreshold : Nat
  treasury : Nat
  deriving DecidableEq, Repr

def Parameters.valid (p : Parameters) : Bool :=
  Committee.configOK p.gridK p.epochLen p.committee.unsettled &&
  decide (0 < p.forcedDelay ∧ 1152 ≤ p.maxAnchorAge ∧ p.gridK ≤ p.maxBatchBlocks ∧
    0 < p.forcedFee ∧ 0 < p.forcedThreshold ∧ p.treasury ≠ 0 ∧ Committee.minUnit ≤ p.committee.unit ∧
    p.committee.unit ≤ p.committee.minimum ∧ 1 ≤ p.committee.nMax ∧ p.committee.nMax ≤ 4096)

def install (s : Etna.Design.State) (p : Parameters) (configHash : List Encoding.Word → Hash) : Etna.Design.State :=
  { s with gridK := p.gridK, epochLen := p.epochLen, genesisCutoff := p.genesisCutoff,     configuration := p.committee, committeeConfig := configHash (Encoding.configWords s.domain.l2ChainId       s.domain.registry p.committee.unit p.committee.minimum p.committee.nMax p.committee.unsettled),     forcedDelay := p.forcedDelay, maxAnchorAge := p.maxAnchorAge, maxBatchBlocks := p.maxBatchBlocks,     forcedFee := p.forcedFee, forcedThreshold := p.forcedThreshold, protocolFeeRecipient := p.treasury }

structure StartData where
  height : Nat
  hash : Hash
  stateRoot : Hash
  deriving DecidableEq, Repr

structure Node where
  signer : Signer.State
  generationWatermark : Nat
  target : Option (Nat × Checkpoint)
  importedHeaders : List Nat
  trusted : Bool
  restartNeeded : Bool
  halted : Bool

structure Snapshot where
  number : Nat
  timestamp : Nat
  inbox : Etna.Design.State
  schedule : Rules.Schedule
  start : Option StartData
  registryHistory : List RegistryHistory.Snapshot
  queue : List (Nat × Forced.Entry)
  deriving DecidableEq, Repr

structure Environment where
  core : Core
  parameters : Parameters
  genesisHeader : Blocks.Header
  initialSigner : Signer.State
  time : Nat → Nat
  stateRoot : Snapshot → Hash
  /-- Hash of the supplied complete closed prefix through the numbered reference. -/
  blockHash : List Snapshot → Nat → Hash
  headerHash : Blocks.Header → Hash
  committeeHash : Committee.Record → Hash
  configHash : List Encoding.Word → Hash
  signature : Consensus.Vote → Prop
  txHash : Blocks.Bytes → Hash
  unzenNextProposal : Nat
  timestampOf : Hash → Nat
  catalogue : Blocks.RulesetCatalogue
  payload : List Hash → List Blocks.Block → Bool
  /-- Accepted proof bytes under the selected verifier code and declared guest image. -/
  verify : Nat → Backend → Hash → Hash → StatementData → Bool
  imageRules : Hash → List Nat
  /-- Existing Unzen proof/header authentication, not Etna custody or finality. -/
  unzenValid : Nat → Blocks.Header → Hash → Bool
  unzenRoot : Blocks.Header → Prop
  startImplementation : Hash → Bool
  /-- Original Comet block/DataHash/metadata scan under an authenticated L1 cut. -/
  importValid : Nat → Checkpoint → Import.Candidate → Bool
  signBytes : SigningBridge.SignMessage → Hash
  token : RegistryPayments.PaymentEnvironment
  /-- Existing TAIKO balances and approvals at deployment, not newly minted principal. -/
  initialToken : RegistryPayments.TokenState := ⟨fun _ => 0,fun _ _ => 0⟩
  evidenceWindow : Nat := 50400
  /-- Fixed decoded physical parentHash projection, indexed by the EL header hash. -/
  headerParent : Hash → Hash := fun _ => 0
  /-- Decode the Unzen proof boundary parent at the finalized proposal offset. -/
  unzenParent : Nat → Nat → Blocks.Header → Hash → Hash := fun _ _ _ _ => 0

structure World where
  inbox : Etna.Design.State
  initialized : Bool
  start : Option StartData
  schedule : Rules.Schedule
  registry : RegistryPayments.State
  queue : List (Nat × Forced.Entry)
  activeRecords : List Checkpoint
  legacySignals : List Signal
  unzen : Start.Unzen
  unzenHeader : Option Blocks.Header
  images : List Hash
  verifier : Nat
  node : Node
  number : Nat
  history : List Snapshot
  configurations : List (Nat × Parameters)
  everLanded : Bool
  receipts : List RegistryPayments.Payment
  /-- Ghost provenance of the selection snapshot written with each retained record. -/
  activeSnapshots : List (Checkpoint × Nat) := []

abbrev Header := Blocks.Header
abbrev Block := Blocks.Block

def bareInbox (core : Core) : Etna.Design.State where
  domain := core.domain
  committeeConfig := 0
  gridK := 1
  generation := 0
  origin := ⟨0,0,0⟩
  origins := []
  checkpoint := default
  records := []
  head := 0
  tail := 0
  snapshot := 0
  ethBalance := 0
  feeAdmissions := 0
  forcedETH := 0
  swept := 0
  signals := []

def empty (env : Environment) (registry : RegistryMachine.State) : World :=
  ⟨install (bareInbox env.core) env.parameters env.configHash,false,none,⟨0,0,0,0,0⟩,
    ⟨registry,env.initialToken⟩,[],[],[],⟨env.unzenNextProposal,0,0,false,0,0,0⟩,none,[],0,
    ⟨{ env.initialSigner with ready := false },env.initialSigner.activeGeneration,none,[],false,false,false⟩,
    0,[],[],false,[],[]⟩

/-- An L1 reference commits only completed blocks at or before it, never later calls. -/
def referencePrefix (w : World) (number : Nat) : List Snapshot := w.history.take (number+1)

def referenceHash (env : Environment) (w : World) (number : Nat) : Hash :=
  env.blockHash (referencePrefix w number) number

/-- Ideal collision separation for the decoded canonical L1 prefix commitment. -/
def ReferenceBinding (env : Environment) : Prop :=
  ∀ a b number, env.blockHash a number = env.blockHash b number → a = b

def registryView (env : Environment) (w : World) : RegistryMachine.InboxView :=
  ⟨w.inbox.domain,w.inbox.generation,w.inbox.snapshot,w.initialized,w.inbox.entered,env.time w.number⟩

def registryWorld (env : Environment) (w : World) : RegistryMachine.World :=
  ⟨w.registry.registry,registryView env w,w.number⟩

def snapshot (env : Environment) (w : World) (number : Nat) : Snapshot :=
  ⟨number,env.time number,w.inbox,w.schedule,w.start,w.registry.registry.history,w.queue⟩

def anchor (env : Environment) (s : Snapshot) : BlockValidity.Anchor :=
  ⟨s.number,s.timestamp,env.stateRoot s,s.inbox.checkpoint.height,s.inbox.checkpoint.elHash,
    s.inbox.generation,s.inbox.tail⟩

/-- An explicit block advance closes every preceding block after all of its calls. Empty
intervening blocks keep that final state, with their own fixed L1 timestamp. -/
def advance (env : Environment) (w : World) (number : Nat) : Option World :=
  if w.number < number ∧ number < limit48 ∧ env.time w.number ≤ env.time number then
    some { w with number := number,       history := w.history ++ (List.range' w.number (number-w.number)).map (snapshot env w) }
  else none

def writeRecord (records : List Checkpoint) (cp : Checkpoint) : List Checkpoint :=
  cp :: records.filter (fun r => r.height != cp.height)

def writeStart (w : World) (height hash root block timestamp generation : Nat) : World :=
  let origin : Etna.Design.Origin := ⟨height,block,timestamp⟩
  let cp : Checkpoint := ⟨height,hash,0,0,generation,height,0⟩
  { w with start := some ⟨height,hash,root⟩,     inbox := { w.inbox with generation := generation,origin := origin,       origins := w.inbox.origins ++ [(generation,origin)],checkpoint := cp,       records := writeRecord w.inbox.records cp },activeRecords := [cp],activeSnapshots := [(cp,w.inbox.snapshot)] }

def initializeInbox (env : Environment) (w : World) (caller : Nat) : Option World :=
  if caller = env.core.owner ∧ w.initialized = false ∧ w.inbox.generation = 0 ∧ env.parameters.valid = true ∧
      w.registry.registry.config.inbox = env.core.domain.inbox ∧
      env.parameters.genesisCutoff < w.number ∧
      w.registry.registry.config.valid w.registry.registry.ledger = true ∧
      env.token.registryAddress = env.core.domain.registry ∧ env.token.slashSink = env.core.slashSink ∧
      env.token.slashSink ≠ 0 then
    let initial := { w with initialized := true,       inbox := { w.inbox with snapshot := env.parameters.genesisCutoff },       configurations := [(0,env.parameters)] }
    if env.core.unzenInbox = 0 then
      if env.genesisHeader.height = 0 ∧ env.genesisHeader.cursor = 0 ∧ env.genesisHeader.cometHash = 0 ∧
          env.genesisHeader.valStateHash = 0 then
        let started := writeStart initial 0 env.genesisHeader.elHash env.genesisHeader.stateRoot
          w.number (env.time w.number) 0
        some { started with inbox := { started.inbox with           signals := [⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩] } }
      else none
    else some initial
  else none

def setOrigin (env : Environment) (w : World) (caller height hash root : Nat) : Option World :=
  if w.initialized = true ∧ w.start = none ∧ w.inbox.generation = 0 ∧ caller = env.core.originWriter ∧
      env.core.unzenInbox ≠ 0 ∧ env.core.forkTime ≤ env.time w.number ∧
      0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 then
    some (writeStart w height hash root w.number (env.time w.number) 0)
  else none

/-- Normative DAO implementation-upgrade action, not a deployed public entry point.
The everLanded guard constrains admissible history; it is not a bytecode storage check. -/
def correctStart (env : Environment) (w : World) (caller height hash root : Nat) : Option World :=
  w.start.bind fun old =>
    if caller = env.core.owner ∧ env.core.unzenInbox ≠ 0 ∧ w.everLanded = false ∧
        w.inbox.checkpoint.height = old.height ∧ w.inbox.signals = [] ∧
        0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 ∧ w.inbox.generation+1 < limit48 then
      some (writeStart w height hash root w.number (env.time w.number) (w.inbox.generation+1))
    else none

/-- Only actual public operations reach the payment wrapper. Internal exclusion and
confirmation recheck are invoked exclusively by recovery/rollback below. -/
def publicRegistry : RegistryMachine.Action → Bool
  | .exclude _ _ _ | .recheck _ _ => false
  | _ => true

def registryCall (env : Environment) (w : World) (caller : Nat) (a : RegistryMachine.Action) : Option World :=
  if publicRegistry a then
    (RegistryPayments.executeTransaction env.token w.registry (registryView env w) w.number caller a).map
      fun result => { w with registry := result.1,receipts := w.receipts ++ result.2 }
  else none

def enqueue (env : Environment) (w : World) (raw : Blocks.Bytes) (paid : Nat) (refund : Bool) : Option World :=
  if w.initialized = true ∧ w.start.isSome = true ∧ env.time w.number < limit48 then
    (Forced.enqueue w.inbox raw.length paid refund).map fun inbox =>
      { w with inbox := inbox,queue := w.queue ++ [(w.inbox.tail,⟨         env.txHash raw,         env.time w.number,w.number⟩)] }
  else none

def sweep (w : World) (transfer : Bool) : Option World :=
  (Forced.sweep w.inbox transfer).map fun inbox => { w with inbox := inbox }

def scheduleRules (env : Environment) (w : World) (caller rule time : Nat) : Option World :=
  (Rules.scheduleRules ⟨w.initialized,env.core.owner,w.inbox.maxAnchorAge,w.inbox.gridK⟩
    w.schedule caller (env.time w.number) rule time).map fun schedule => { w with schedule := schedule }

def scheduleStop (env : Environment) (w : World) (caller time grid : Nat) : Option World :=
  (Rules.scheduleStop ⟨w.initialized,env.core.owner,w.inbox.maxAnchorAge,w.inbox.gridK⟩
    w.schedule caller (env.time w.number) time grid).map fun schedule => { w with schedule := schedule }

structure RecoveryRequest where
  caller : Nat
  expectedGeneration : Nat
  expectedCheckpoint : Nat
  expectedNonce : Nat
  validUntil : Nat
  exclusions : List (Nat × Hash)
  clear : List Nat
  rules : Nat
  upgrade : Option Parameters := none
  deriving DecidableEq, Repr

/-- This fixed empty-hash adapter is shared by admission and every recovery. -/
def emptyHash (env : Environment) : Hash :=
  env.txHash []

def parametersOf (s : Etna.Design.State) : Parameters :=
  ⟨s.gridK,s.epochLen,s.genesisCutoff,s.configuration,s.forcedDelay,s.maxAnchorAge,
    s.maxBatchBlocks,s.forcedFee,s.forcedThreshold,s.protocolFeeRecipient⟩

def recover (env : Environment) (w : World) (a : RecoveryRequest) : Option World :=
  w.start.bind fun start =>
    let parameters := a.upgrade.getD (parametersOf w.inbox)
    let inbox := if a.upgrade.isSome then install w.inbox parameters env.configHash else w.inbox
    if a.caller = env.core.owner ∧ w.initialized = true ∧ w.inbox.entered = false ∧
        a.expectedGeneration = w.inbox.generation ∧ a.expectedCheckpoint = w.inbox.checkpoint.height ∧
        a.expectedNonce = w.inbox.recoveryNonce ∧ w.inbox.recoveryNonce+1 < limit256 ∧
        env.time w.number ≤ a.validUntil ∧ a.validUntil < limit256 ∧ w.inbox.generation+1 < limit48 ∧
        Start.onGrid start.height inbox.gridK w.inbox.checkpoint.height = true ∧
        a.exclusions.Pairwise (fun x y => x.1 < y.1) ∧ a.clear.Pairwise (· < ·) ∧
        (∀ i ∈ a.clear,w.inbox.head ≤ i ∧ i < w.inbox.tail) ∧
        -- SPEC 8.3's only grid check is RECOV-8.3-3a, the `onGrid` check above with the K this
        -- call installs. It has no planned-stop check: START-10.1-14e's stop is DAO procedure,
        -- and vector 14e.k recovers from a settled c below a stop point that cannot settle.
        (a.upgrade.isSome = true → parameters.valid = true ∧ a.rules ≠ 0 ∧
          -- genesisCutoff (slot 279) is committee 0's snapshot (COMM-4.3-9) and part of
          -- generation 0's genesis. It is set once at Inbox initialization (PARAM-11-4), and only
          -- a migration to a new Inbox changes it (START-10.1-2a), never a structural upgrade.
          parameters.genesisCutoff = w.inbox.genesisCutoff) then
      (Rules.recover w.schedule a.rules).bind fun schedule =>
      (RegistryMachine.execute w.registry.registry (registryView env w) w.number
        (.exclude w.registry.registry.config.inbox w.number a.exclusions)).map fun registry =>
      { w with inbox := { inbox with generation := w.inbox.generation+1,           recoveryNonce := w.inbox.recoveryNonce+1,           origin := ⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩,           origins := w.inbox.origins ++ [(w.inbox.generation+1,⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩)] },         registry := { w.registry with registry := registry },schedule := schedule,         queue := w.queue.map (fun (i,e) => (i,if i ∈ a.clear then Forced.clear (emptyHash env) e else e)),         configurations := (w.inbox.generation+1,parameters) :: w.configurations }
    else none

def invalidate (env : Environment) (w : World) (caller nonce : Nat) : Option World :=
  if caller = env.core.owner ∧ w.initialized = true ∧ w.inbox.entered = false ∧
      nonce = w.inbox.recoveryNonce ∧ nonce+1 < limit256 then
    some { w with inbox := { w.inbox with recoveryNonce := nonce+1 } }
  else none

/-- Normative DAO implementation-upgrade action, not a deployed public entry point.
activeSnapshots authenticates admissible historical provenance, not readable bytecode storage. -/
def rollback (env : Environment) (w : World) (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) : Option World :=
  if caller = env.core.owner ∧ w.initialized = true ∧ w.inbox.entered = false ∧
      trusted ∈ w.activeRecords ∧ trusted.height ≤ w.inbox.checkpoint.height ∧
      w.inbox.recoveryNonce+1 < limit256 ∧ (trusted,snapshot) ∈ w.activeSnapshots then
    (RegistryMachine.execute w.registry.registry (registryView env w) w.number
      (.recheck w.registry.registry.config.inbox snapshot)).map fun registry =>
    { w with registry := { w.registry with registry := registry },       inbox := { w.inbox with checkpoint := trusted,head := trusted.cursor,snapshot := snapshot,         recoveryNonce := w.inbox.recoveryNonce+1,         records := w.inbox.records.filter (fun r => r ∉ w.activeRecords ∨ r.height ≤ trusted.height),         signals := w.inbox.signals.filter (fun s => s.height ≤ trusted.height) },       activeRecords := w.activeRecords.filter (fun r => r.height ≤ trusted.height),activeSnapshots := w.activeSnapshots.filter (fun x => x.1.height ≤ trusted.height) }
  else none

/-- Configuration actually applicable to this generation, never a later initializeInboxr. -/
def config (w : World) : Finality.Config :=
  ⟨w.inbox.domain,w.inbox.generation,w.inbox.origin.height,w.inbox.origin.l1Block,
    w.inbox.genesisCutoff,w.inbox.epochLen,w.inbox.configuration.unit,
    w.inbox.configuration.minimum,w.inbox.configuration.nMax⟩

/-- A guest's storage context is the last completed snapshot of its committed reference
prefix. The empty fallback is fixed by deployment data, never by later mutable state. -/
def certificateWorld (env : Environment) (w : World) (reference : Nat) : World :=
  let registry : RegistryMachine.State :=
    { ledger := { nextId := 0,bonds := fun _ => none,slots := fun _ => none,keyId := fun _ => none } }
  let base := empty env registry
  let chainPrefix := referencePrefix w reference
  let last := chainPrefix.getLast?.getD (snapshot env base reference)
  { base with
    inbox := last.inbox
    start := last.start
    schedule := last.schedule
    registry := { base.registry with registry := { registry with history := last.registryHistory } }
    queue := last.queue
    number := reference+1
    history := chainPrefix }

def certificateOrigin (w : World) : Option Checkpoint := recordAt w.inbox (config w).originHeight

def certificateOriginCut (w : World) : Cut :=
  let cp := (certificateOrigin w).getD default
  ⟨cp.elHash,cp.cometHash,cp.cursor,cp.valStateHash⟩

/-- The raw live storage needed to apply a reference-local certificate. Registry changes
above the reference and all checkpoint/FI progress may differ. -/
structure CertificateStorage (source w : World) (reference : Nat) : Prop where
  configuration : config source = config w
  parameters : parametersOf source.inbox = parametersOf w.inbox
  committee : source.inbox.committeeConfig = w.inbox.committeeConfig
  start : source.start = w.start
  registry : source.registry.registry.history.filter (fun cp => decide (cp.block ≤ reference)) =
    w.registry.registry.history.filter (fun cp => decide (cp.block ≤ reference))
  ordered : RegistryHistory.Ordered w.registry.registry.history

abbrev CertificateFootprint (env : Environment) (w : World) (reference : Nat) : Prop :=
  CertificateStorage (certificateWorld env w reference) w reference

def matchingSnapshot (env : Environment) (w : World) (a : BlockValidity.Anchor) : Option Snapshot :=
  w.history.find? (fun s => anchor env s == a)

def policy (env : Environment) (w : World) (archive : List Header) (reference : Nat) : Blocks.Policy where
  consensus := Finality.derive (config w) w.registry.registry archive
  startHeight := (w.start.map StartData.height).getD 0
  gridK := w.inbox.gridK
  committeeConfig := w.inbox.committeeConfig
  maxAnchorAge := w.inbox.maxAnchorAge
  forcedDelay := w.inbox.forcedDelay
  unsettled := w.inbox.configuration.unsettled
  referenceNumber := reference
  referenceHash := referenceHash env w reference
  committeeHash := env.committeeHash
  signature := env.signature
  anchorAuthenticated := fun a => (matchingSnapshot env w a).isSome
  committeeAuthenticated := fun root record =>
    w.history.any fun s => env.stateRoot s == root &&
      decide (record.members = Committee.chosen w.inbox.configuration.unit w.inbox.configuration.minimum
        record.cutoff w.inbox.configuration.nMax
        (((RegistryHistory.latestSnapshot s.registryHistory record.cutoff).map RegistryHistory.Snapshot.entries).getD []))
  forcedAuthenticated := fun a witness =>
    ((matchingSnapshot env w a).map fun s => decide ((witness.index,witness.stored) ∈ s.queue) &&
      witness.storageAuthenticated).getD false
  scheduleAuthenticated := fun a schedule =>
    ((matchingSnapshot env w a).map fun s => decide (s.schedule = schedule)).getD false
  batchPayloadValid := env.payload
  configHash := env.configHash
  /- Concrete archive ancestry is checked by BatchCertificate, replacing the old oracle. -/
  historyAuthenticated := fun _ _ => true
  catalogue := env.catalogue

structure Proof where
  backend : Backend
  image : Hash
  bytes : Hash
  deriving DecidableEq, Repr

structure Landing where
  input : LandInput
  leaves : List Leaf
  blobs : List Hash
  proofs : List Proof
  deriving DecidableEq, Repr

def statement (env : Environment) (w : World) (a : Landing) : StatementData :=
  let origin := (recordAt w.inbox a.input.parentHeight).getD default
  ⟨w.inbox.domain,w.inbox.generation,w.inbox.committeeConfig,origin.elHash,origin.cometHash,origin.valStateHash,
    origin.cursor,
    a.input,referenceHash env w a.input.l1ReferenceBlockNumber,a.blobs,
    ⟨w.inbox.generation,a.input.parentHeight,a.input.lastHeight,a.leaves⟩⟩

def proofsAccepted (env : Environment) (w : World) (a : Landing) : Bool :=
  dualOK (a.proofs.map fun p => (p.backend,
    decide (p.image ∈ w.images) && env.verify w.verifier p.backend p.image p.bytes (statement env w a)))

def firstFence (env : Environment) (w : World) : Bool :=
  match w.start with
  | none => false
  | some start => Start.firstLanding (env.core.unzenInbox != 0) start.height w.inbox.checkpoint.height
      start.hash start.stateRoot w.unzen

structure LandingChecks (env : Environment) (w : World) (a : Landing) : Prop where
  initialized : w.initialized = true
  started : w.start.isSome = true
  entered : w.inbox.entered = false
  origin : w.inbox.origin.height ≤ a.input.parentHeight
  parentBeforeFrontier : a.input.parentHeight ≤ w.inbox.checkpoint.height
  progress : w.inbox.checkpoint.height < a.input.lastHeight
  height : a.input.lastHeight < limit48
  parentGrid : Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK a.input.parentHeight = true
  lastGrid : Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK a.input.lastHeight = true
  frontierGrid : Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK w.inbox.checkpoint.height = true
  batchSize : a.input.lastHeight-a.input.parentHeight ≤ w.inbox.maxBatchBlocks
  record : (recordAt w.inbox a.input.parentHeight).isSome = true
  generation : ((recordAt w.inbox a.input.parentHeight).getD default).generation = w.inbox.generation ∨
    a.input.parentHeight = w.inbox.origin.height
  leafCount : a.leaves.length = gridCount w.inbox.gridK a.input.parentHeight a.input.lastHeight
  frontier : a.input.parentHeight < w.inbox.checkpoint.height →
    a.leaves.getD ((w.inbox.checkpoint.height-a.input.parentHeight)/w.inbox.gridK-1) default =
      cutLeaf w.inbox.checkpoint.height
        ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head,w.inbox.checkpoint.valStateHash⟩
  cursor : ((recordAt w.inbox w.inbox.checkpoint.height).getD default).cursor = w.inbox.head
  head : w.inbox.head ≤ a.input.forcedInclusionHead
  tail : a.input.forcedInclusionHead ≤ w.inbox.tail
  service : a.input.forcedInclusionHead-w.inbox.head ≤ a.input.lastHeight-w.inbox.checkpoint.height
  reference : a.input.l1ReferenceBlockNumber < w.number
  referenceAge : w.number-a.input.l1ReferenceBlockNumber ≤ 8191
  blobs : 1 ≤ a.blobs.length ∧ a.blobs.length ≤ 6
  unzen : firstFence env w = true
  proofs : proofsAccepted env w a = true

instance (env : Environment) (w : World) (a : Landing) : Decidable (LandingChecks env w a) :=
  decidable_of_iff ((w.initialized = true) ∧
    (w.start.isSome = true) ∧
    (w.inbox.entered = false) ∧
    (w.inbox.origin.height ≤ a.input.parentHeight) ∧
    (a.input.parentHeight ≤ w.inbox.checkpoint.height) ∧
    (w.inbox.checkpoint.height < a.input.lastHeight) ∧
    (a.input.lastHeight < limit48) ∧
    (Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK a.input.parentHeight = true) ∧
    (Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK a.input.lastHeight = true) ∧
    (Start.onGrid ((w.start.map StartData.height).getD 0) w.inbox.gridK w.inbox.checkpoint.height = true) ∧
    (a.input.lastHeight-a.input.parentHeight ≤ w.inbox.maxBatchBlocks) ∧
    ((recordAt w.inbox a.input.parentHeight).isSome = true) ∧
    (((recordAt w.inbox a.input.parentHeight).getD default).generation = w.inbox.generation ∨ a.input.parentHeight = w.inbox.origin.height) ∧
    (a.leaves.length = gridCount w.inbox.gridK a.input.parentHeight a.input.lastHeight) ∧
    (a.input.parentHeight < w.inbox.checkpoint.height → a.leaves.getD ((w.inbox.checkpoint.height-a.input.parentHeight)/w.inbox.gridK-1) default = cutLeaf w.inbox.checkpoint.height
        ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head,w.inbox.checkpoint.valStateHash⟩) ∧
    (((recordAt w.inbox w.inbox.checkpoint.height).getD default).cursor = w.inbox.head) ∧
    (w.inbox.head ≤ a.input.forcedInclusionHead) ∧
    (a.input.forcedInclusionHead ≤ w.inbox.tail) ∧
    (a.input.forcedInclusionHead-w.inbox.head ≤ a.input.lastHeight-w.inbox.checkpoint.height) ∧
    (a.input.l1ReferenceBlockNumber < w.number) ∧
    (w.number-a.input.l1ReferenceBlockNumber ≤ 8191) ∧
    (1 ≤ a.blobs.length ∧ a.blobs.length ≤ 6) ∧
    (firstFence env w = true) ∧
    (proofsAccepted env w a = true))
    ⟨(fun h => ⟨h.1,h.2.1,h.2.2.1,h.2.2.2.1,h.2.2.2.2.1,h.2.2.2.2.2.1,h.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,h.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2⟩),
     (fun h => ⟨h.initialized,h.started,h.entered,h.origin,h.parentBeforeFrontier,h.progress,h.height,h.parentGrid,h.lastGrid,h.frontierGrid,h.batchSize,h.record,h.generation,h.leafCount,h.frontier,h.cursor,h.head,h.tail,h.service,h.reference,h.referenceAge,h.blobs,h.unzen,h.proofs⟩)⟩

/-- State written by L1 contains only decoded statement fields, never an assumed valid chain. -/
def landed (w : World) (a : Landing) : World :=
  let cp : Checkpoint := ⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastCometHash,
    a.input.forcedInclusionHead,w.inbox.generation,w.inbox.checkpoint.height,a.input.lastValStateHash⟩
  { w with inbox := { w.inbox with checkpoint := cp,records := writeRecord w.inbox.records cp,       head := a.input.forcedInclusionHead,snapshot := a.input.activeCommitteeSnapshot,       signals := w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩] },     activeRecords := cp :: w.activeRecords,activeSnapshots := (cp,a.input.activeCommitteeSnapshot) :: w.activeSnapshots,everLanded := true }

def land (env : Environment) (w : World) (a : Landing) : Option World :=
  if LandingChecks env w a then some (landed w a) else none

/-- An accepted legacy proof updates the original Unzen lane atomically. Once a start is
written, its SignalService gate rejects a checkpoint above S. -/
def unzenProve (env : Environment) (w : World) (proposal : Nat) (h : Header) (proof : Hash) : Option World :=
  if env.core.unzenInbox ≠ 0 ∧ env.unzenValid proposal h proof = true ∧
      w.unzen.finalizedProposal < proposal ∧ proposal < w.unzen.nextProposal ∧
      env.unzenParent w.unzen.finalizedProposal proposal h proof = w.unzen.finalizedHash ∧
      (w.start = none ∨ h.height ≤ (w.start.map StartData.height).getD 0) then
    some { w with unzen := ⟨w.unzen.nextProposal,proposal,h.elHash,true,h.height,h.elHash,h.stateRoot⟩,       unzenHeader := some h,legacySignals := w.legacySignals ++ [⟨h.height,h.elHash,h.stateRoot⟩] }
  else none

def observe (_env : Environment) (w : World) (number : Nat) : Option World :=
  (w.history.find? (fun s => s.number == number)).map fun s =>
    { w with node := { w.node with target := some (s.inbox.generation,s.inbox.checkpoint),       generationWatermark := max w.node.generationWatermark s.inbox.generation,trusted := false,       signer := { w.node.signer with ready := false } } }

def nodeImport (env : Environment) (w : World) (candidate : Import.Candidate) (durable : Bool) : Option World :=
  match w.node.target with
  | none => none
  | some (generation,checkpoint) =>
    if env.importValid generation checkpoint candidate = true ∧ candidate.height = checkpoint.height ∧
        candidate.checkpointEL = checkpoint.elHash ∧ generation = w.inbox.generation ∧
        candidate.origin = w.inbox.origin.height then
      (Import.publish candidate generation w.inbox.configuration.unsettled w.node.signer durable).map fun installed =>
        { w with node := { w.node with importedHeaders := installed.headerNumbers,           signer := { installed.signer with ready := false },trusted := false } }
    else none

def nodeRestart (w : World) : World :=
  { w with node := { w.node with target := none,trusted := false,restartNeeded := false,     signer := { w.node.signer with ready := false } } }

/-- Abstract validated replay, separate from snapshot publication. The fixed deployment
adapters authenticate the full origin; this is not a stock-store implementation. -/
def nodeTrust (env : Environment) (w : World) (archive : List Header) (blocks : List Block) : Prop :=
  w.initialized = true ∧ ∃ start, w.start = some start ∧
  ∃ generation cp, w.node.target = some (generation,cp) ∧ generation = w.inbox.generation ∧
    cp = w.inbox.checkpoint ∧ w.node.signer.activeGeneration = generation ∧
    w.node.generationWatermark ≤ generation ∧
    ∃ p origin, recordAt w.inbox w.inbox.origin.height = some origin ∧
      p.height = w.inbox.origin.height ∧ p.cut = ⟨origin.elHash,origin.cometHash,origin.cursor,origin.valStateHash⟩ ∧
      env.headerHash p = p.elHash ∧
      (p.height = start.height → p.stateRoot = start.stateRoot) ∧
      (env.core.unzenInbox ≠ 0 → cp.height = start.height →
        env.unzenRoot p ∧ env.startImplementation p.stateRoot = true ∧ p.timestamp < env.core.forkTime) ∧
      Blocks.Chain (policy env w archive w.number) p blocks ∧
      (Blocks.terminal p blocks).height = cp.height ∧ (Blocks.terminal p blocks).cut =
        ⟨cp.elHash,cp.cometHash,cp.cursor,cp.valStateHash⟩ ∧
      Archive.Authenticated env.headerHash env.headerParent (config w)
        ⟨origin.elHash,origin.cometHash,origin.cursor,origin.valStateHash⟩ w.number archive p blocks

/-- This is an explicit app validation event, not a caller-supplied trusted Boolean. -/
inductive NodeEvent (env : Environment) (w : World) : Node → Prop
  | trust (archive : List Header) (blocks : List Block)
      (verified : nodeTrust env w archive blocks) : NodeEvent env w
      { w.node with trusted := true }
  | missing : NodeEvent env w { w.node with trusted := false,signer := { w.node.signer with ready := false } }
  | timeout : NodeEvent env w { w.node with trusted := false,restartNeeded := true,       signer := { w.node.signer with ready := false } }
  | contradiction : NodeEvent env w { w.node with trusted := false,halted := true,       signer := { w.node.signer with ready := false } }

inductive Call where
  | advance (number : Nat)
  | initializeInbox (caller : Nat)
  | setOrigin (caller height hash root : Nat)
  | correctStart (caller height hash root : Nat)
  | registry (caller : Nat) (action : RegistryMachine.Action)
  | enqueue (raw : Blocks.Bytes) (paid : Nat) (refund : Bool)
  | sweep (transfer : Bool)
  | forcedETH (amount : Nat)
  | scheduleRules (caller rule time : Nat)
  | scheduleStop (caller time grid : Nat)
  | recover (request : RecoveryRequest)
  | invalidate (caller nonce : Nat)
  | rollback (caller : Nat) (trusted : Checkpoint) (snapshot : Nat)
  | land (a : Landing)
  | unzenProve (proposal : Nat) (header : Header) (proof : Hash)
  | image (caller image : Nat) (register : Bool)
  | verifier (caller version : Nat)
  | observe (number : Nat)
  | importSnapshot (candidate : Import.Candidate) (durable : Bool)
  | restart
  | openSigner (authoritative : Bool)
  | switchSigner (persisted : Bool)
  | sign (request : SigningBridge.SignMessage) (signature : Hash) (persisted : Bool)
  deriving Repr

def execute (env : Environment) (w : World) : Call → Option World
  | .advance number => advance env w number
  | .initializeInbox caller => initializeInbox env w caller
  | .setOrigin caller height hash root => setOrigin env w caller height hash root
  | .correctStart caller height hash root => correctStart env w caller height hash root
  | .registry caller action => registryCall env w caller action
  | .enqueue raw paid refund => enqueue env w raw paid refund
  | .sweep transfer => sweep w transfer
  | .forcedETH amount => some { w with inbox := Forced.extraETH w.inbox amount }
  | .scheduleRules caller rule time => scheduleRules env w caller rule time
  | .scheduleStop caller time grid => scheduleStop env w caller time grid
  | .recover a => recover env w a
  | .invalidate caller nonce => invalidate env w caller nonce
  | .rollback caller trusted snapshot => rollback env w caller trusted snapshot
  | .land a => land env w a
  | .unzenProve proposal header proof => unzenProve env w proposal header proof
  | .image caller image register => if caller = env.core.owner then
      some { w with images := if register then image :: w.images else w.images.filter (· != image) } else none
  | .verifier caller version => if caller = env.core.owner then some { w with verifier := version } else none
  | .observe number => observe env w number
  | .importSnapshot candidate durable => nodeImport env w candidate durable
  | .restart => some (nodeRestart w)
  | .openSigner authoritative =>
      some { w with node := { w.node with signer := Signer.openSession w.node.signer w.inbox.generation         (w.node.trusted && !w.node.restartNeeded && !w.node.halted &&           decide (w.node.generationWatermark ≤ w.node.signer.activeGeneration)) authoritative } }
  | .switchSigner persisted =>
      some { w with node := { w.node with trusted := false,         signer := Signer.switchDomain w.node.signer w.inbox.domain w.inbox.generation           (w.inbox.origin.height+1) (decide (w.node.target = some (w.inbox.generation,w.inbox.checkpoint))) persisted } }
  | .sign message signature persisted =>
      let request := SigningBridge.messageRequest env.signBytes message
        (w.node.trusted && !w.node.restartNeeded && !w.node.halted &&
          decide (w.node.generationWatermark ≤ w.node.signer.activeGeneration))
      (Signer.sign w.node.signer request signature persisted).map fun result =>
        { w with node := { w.node with signer := result.1 } }

/-- Reverting calls leave every contract, token balance, image and signer field unchanged. -/
def transact (env : Environment) (w : World) (call : Call) : World := (execute env w call).getD w

inductive Step (env : Environment) : World → World → Prop
  | call (w : World) (call : Call) : Step env w (transact env w call)
  | node {w : World} (after : Node) (validated : NodeEvent env w after) : Step env w { w with node := after }

inductive Trace (env : Environment) : World → World → Prop
  | refl (w : World) : Trace env w w
  | step {first w t : World} (prior : Trace env first w) (change : Step env w t) : Trace env first t

/-- Proof soundness is about individual accepted guest statements, not custody or queues. -/
def HashBound (env : Environment) (h : Header) : Prop := env.headerHash h = h.elHash

def LiveBatchCertificate (env : Environment) (w : World) (d : StatementData)
    (archive : List Header) (p : Header) (bs : List Block) : Prop :=
  Finality.Ready (config w) w.registry.registry archive (Blocks.terminal p bs).height ∧
    Blocks.BatchValid (policy env w archive d.input.l1ReferenceBlockNumber) p bs d.blobHashes ∧
    d = Blocks.statement (policy env w archive d.input.l1ReferenceBlockNumber) p bs d.blobHashes ∧
    HashBound env p ∧ (∀ b ∈ bs, HashBound env b.header) ∧
    (env.core.unzenInbox ≠ 0 → p.height = (w.start.map StartData.height).getD 0 →
      env.startImplementation p.stateRoot = true) ∧
    Archive.Authenticated env.headerHash env.headerParent (config w)
      (certificateOriginCut (certificateWorld env w d.input.l1ReferenceBlockNumber))
      d.input.l1ReferenceBlockNumber archive p bs

/-- Guest semantics use only the complete committed prefix, including its actual origin
record. They are independent of later landings, registry calls and verifier governance. -/
def BatchCertificate (env : Environment) (w : World) (d : StatementData)
    (archive : List Header) (p : Header) (bs : List Block) : Prop :=
  let closed := certificateWorld env w d.input.l1ReferenceBlockNumber
  LiveBatchCertificate env closed d archive p bs ∧
    (referencePrefix w d.input.l1ReferenceBlockNumber).map Snapshot.number =
      List.range (d.input.l1ReferenceBlockNumber+1) ∧
    (certificateOrigin closed).isSome = true

def Certifies (env : Environment) (w : World) (d : StatementData) : Prop :=
  ∃ archive p bs, BatchCertificate env w d archive p bs

/-- Operational view derived from the immutable certificate and raw live storage. -/
def LiveCertifies (env : Environment) (w : World) (d : StatementData) : Prop :=
  ∃ archive p bs, LiveBatchCertificate env w d archive p bs

/-- A sound guest certifies the batch only under rules that its declared image implements. -/
def ImageCertifies (env : Environment) (w : World) (image : Hash) (d : StatementData) : Prop :=
  ∃ archive p bs, BatchCertificate env w d archive p bs ∧
    ∀ b ∈ bs, Blocks.selectedRules b ∈ env.imageRules image

/-- Semantic certificate suffix extracted at the execution-time frontier. No public call
accepts such a value or assumes it; the soundness bridge derives its fields from proofs. -/
structure Suffix (env : Environment) (w : World) (a : Landing) where
  archive : List Header
  parent : Header
  blocks : List Block
  ready : Finality.Ready (config w) w.registry.registry archive (Blocks.terminal parent blocks).height
  valid : Blocks.Chain (policy env w archive a.input.l1ReferenceBlockNumber) parent blocks
  parentHeight : parent.height = w.inbox.checkpoint.height
  parentCut : parent.cut =
    ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head,w.inbox.checkpoint.valStateHash⟩
  terminalHeight : (Blocks.terminal parent blocks).height = a.input.lastHeight
  terminalCut : (Blocks.terminal parent blocks).cut =
    ⟨a.input.lastBlockHash,a.input.lastCometHash,a.input.forcedInclusionHead,a.input.lastValStateHash⟩
  terminalRoot : (Blocks.terminal parent blocks).stateRoot = a.input.lastStateRoot
  parentHashBound : HashBound env parent
  headerHashes : ∀ b ∈ blocks, HashBound env b.header


def VerifierSound (env : Environment) (initial : World) : Prop :=
  ∃ sound : Backend → Prop,
    (∀ proofs, dualOK proofs = true → ∃ backend ∈ proofs, sound backend.1) ∧
    ∀ w, Trace env initial w → ∀ a t proof, land env w a = some t → proof ∈ a.proofs →
      sound proof.backend →
      env.verify w.verifier proof.backend proof.image proof.bytes (statement env w a) = true →
      ImageCertifies env w proof.image (statement env w a)

end Etna.Design.Current.Protocol
