import EtnaModel
import EtnaVectors.Json

/-! The conformance-vector machine: a deployment, the calls a vector makes, the model
transition each call runs and the observable state a harness compares.

Every expectation comes from the model's executable transitions on `ProtocolState.World`
(`ProtocolState.land`, `Forced.enqueue`/`sweep`/`extraETH`, `ProtocolState.recover`,
`RegistryHistory.register`/`edit`). The model's hashes are atoms (`Hash = Nat`); the harness
maps an atom `n` to `bytes32(n)`, a registry key `k` to the consensus key of private key `k`, a
caller `n` to a fixed address and a signature atom to "signed by private key `n`". The
generator's own choices of model inputs (the encodings) are documented in the README of
`testdata/etna_conformance`. -/
namespace Etna.Vectors
open Etna.Design

/-- The deployment immutables a vector varies. Every other deployment value is fixed below. -/
structure Deploy where
  /-- false: the Inbox proxy stays on its bootstrap implementation (registry vectors only). -/
  initialized : Bool := true
  maxBatchBlocks : Nat := 18
  feeGwei : Nat := 1
  threshold : Nat := 2
  /-- false: `protocolFeeRecipient` is a contract that rejects ETH. -/
  recipientAccepts : Bool := true
  minStake : Nat := 10
  activationDelay : Nat := 10
  exitDelay : Nat := 20
  withdrawalDelay : Nat := 30
  bountyBps : Nat := 1000
  forfeitBps : Nat := 1000
  /-- Fixture-only persistent nonce override for width-boundary tests; ordinary deployment is zero. -/
  recoveryNonce : Nat := 0
  /-- Bootstrap entries registered in one L1 block; default one, capacity fixture 4096. -/
  registrySize : Nat := 1
  /-- U, committed in the committee configuration hash only. -/
  unsettled : Nat := 3600

/-- K: the contract fixes `GRID_INTERVAL = 6`. -/
def landGrid : Nat := 6
/-- The L1 block of the genesis validator's registration: the registry's first checkpoint and
the genesis cutoff. -/
def registeredAt : Nat := 10
/-- The L1 block of `init` (L1_0). -/
def initAt : Nat := 11
def timestampBase : Nat := 1700000000
/-- Every call at L1 block `b` runs at timestamp `timestampBase + 12 b`. -/
def timestampOf (block : Nat) : Nat := timestampBase + 12*block
def genesisKey : Nat := 1
def genesisOwner : Nat := 1
def epochLength : Nat := 10
def fiDelay : Nat := 3600
def anchorAge : Nat := 7200
def vpUnit : Nat := 1000000000
def gwei : Nat := 1000000000

/-- keccak256(""): what recovery writes over a blanked entry, and the hash of an empty
submission. -/
def blankHash : Hash := 1
/-- The hash the reference block has when it is available. -/
def referenceHash : Hash := 7
/-- Hash atoms of the chain a generation commits at height `x`. -/
def elAtom (g x : Nat) : Hash := 100000*g + 10000 + x
def cometAtom (g x : Nat) : Hash := if g = 0 ∧ x = 0 then 0 else 100000*g + 20000 + x
def rootAtom (g x : Nat) : Hash := 100000*g + 30000 + x
/-- A leaf word at a grid point that has no landing record (not a cutLeaf preimage). -/
def wordAtom (g x : Nat) : Hash := 100000*g + 40000 + x
/-- The txHash of the non-empty submission at queue index `i`. -/
def txAtom (i : Nat) : Hash := 50000 + i

def deployment : Domain := ⟨1, 2, 3, 4⟩
/-- The domain of a vote signed under another deployment's chain id. -/
def foreignDeployment : Domain := ⟨1, 5, 3, 4⟩

def registry0 (d : Deploy) : RegistryHistory.State :=
  { RegistryHistory.empty with
    verify := fun key _ sig => sig == key, slashBountyBps := d.bountyBps, minStake := d.minStake,
    activationDelay := d.activationDelay, exitDelay := d.exitDelay, withdrawalDelay := d.withdrawalDelay, forfeitBps := d.forfeitBps }

/-- The recovery constants: keccak256("") and the released-slot key (a released slot's key
atom is 0). The two commitment hashes are not observed. -/
def adapters : ProtocolState.Adapters := ⟨fun _ => 0, fun _ => 0, ⟨blankHash, 0⟩⟩

/-- The Inbox right after `init` (`Deployment.Genesis`), or an uninitialized one, which stores
no checkpoint yet (slot 271 is zero until `init`). -/
def inbox0 (d : Deploy) : State :=
  let origin : Origin := if d.initialized then ⟨0, initAt, timestampOf initAt⟩ else ⟨0, 0, 0⟩
  let genesis : Checkpoint := ⟨0, elAtom 0 0, 0, 0, 0, 0⟩
  { domain := deployment, committeeConfig := 0, gridK := landGrid, generation := 0, recoveryNonce := d.recoveryNonce, origin := origin,
    origins := if d.initialized then [(0, origin)] else [],
    checkpoint := if d.initialized then genesis else ⟨0, 0, 0, 0, 0, 0⟩,
    records := if d.initialized then [genesis] else [],
    head := 0, tail := 0, snapshot := if d.initialized then registeredAt else 0,
    ethBalance := 0, feeAdmissions := 0, forcedETH := 0, swept := 0,
    signals := if d.initialized then [⟨0, elAtom 0 0, rootAtom 0 0⟩] else [],
    epochLen := epochLength, genesisCutoff := registeredAt,
    configuration := ⟨vpUnit, vpUnit, 128, d.unsettled⟩, forcedDelay := fiDelay, maxAnchorAge := anchorAge,
    maxBatchBlocks := d.maxBatchBlocks, forcedFee := d.feeGwei, forcedThreshold := d.threshold,
    protocolFeeRecipient := 1 }

/-- Uniform same-block registrations as a bootstrap fixture. This direct construction
avoids repeatedly traversing a chain of 4096 slot-update closures; it has the same entry,
key and single-checkpoint projection as registering every key at block 10. -/
def bootstrapRegistry (d : Deploy) (r : RegistryHistory.State) : RegistryHistory.State :=
  if d.registrySize = 1 then r else
    let full : RegistryHistory.State := { r with
      nextId := d.registrySize
      slots := fun id => if id < d.registrySize then
        { r.slots 0 with key := id+1, owner := id+1 } else RegistryHistory.vacant
      usedKeys := ((List.range d.registrySize).map (·+1)).reverse }
    { full with history := [⟨registeredAt, RegistryHistory.entries full⟩] }

/-- The deployment fixture registers keys/owners 1 through registrySize at block 10,
then initializes at block 11 with genesis cutoff 10 (or stays uninitialized). -/
def world0 (d : Deploy) : Option ProtocolState.World :=
  if 1 ≤ d.registrySize ∧ d.registrySize ≤ 4096 then
    (RegistryHistory.register (registry0 d) genesisKey genesisOwner d.minStake registeredAt).map fun r =>
      { inbox := inbox0 d, registry := bootstrapRegistry d r, queue := [], schedule := ⟨⟨0, registeredAt, []⟩, none⟩,
        l1Block := if d.initialized then initAt else registeredAt, adapters := adapters }
  else none

/-- A vote as the harness builds it. The model's vote carries the domain; `foreign` signs it
under another deployment's chain id. `signer` is the model's signature atom: the harness signs
with private key `signer`, and the registry verifier accepts exactly the bond's own key. -/
structure VoteIn where
  kind : Nat := 2
  height : Nat := 1000
  round : Nat := 3
  blockId : Nat := 11
  generation : Nat := 0
  foreign : Bool := false
  signer : Nat := 1

/-- One contract call. Callers and recipients are numbered accounts. -/
inductive Op where
  | land (i : LandInput) (leaves : List Leaf) (refAvailable : Bool) (blobs : Nat) (proofsOK : Bool)
  | enqueue (caller rawBytes paid : Nat) (refundOK : Bool)
  | sweep (caller : Nat)
  | forceETH (amount : Nat)
  | recover (owner : Bool) (request : Recovery.Request)
  | invalidateRecoveryNonce (owner : Bool) (expected : Nat)
  /-- Fixture upgrade restoring the trusted initialization checkpoint/snapshot. -/
  | rollbackGenesis
  | register (caller key amount : Nat)
  | topUp (caller bondId amount : Nat) (transferOK : Bool)
  | activateTopUp (caller bondId : Nat)
  | forfeit (owner : Bool) (bondId entryKey incidentId validUntil : Nat) (externalOK : Bool)
  | requestExit (caller bondId : Nat)
  | confirmExit (caller bondId : Nat)
  | withdraw (caller bondId recipient : Nat)
  | slash (caller bondId : Nat) (a b : VoteIn)

/-- A call at an L1 block. Its timestamp is `timestampOf block` unless the scenario sets it. -/
structure Call where
  block : Nat
  op : Op

/-- The landing environment: the reference hash and blob hashes the call supplies, two
successful proofs (one SGX, one SP1) unless `proofsOK` is false, and a certificate equal to the
statement the Inbox builds, which is what a verifier that accepts every proof means. -/
def landEnv (s : State) (i : LandInput) (leaves : List Leaf) (block : Nat) (refAvailable : Bool)
    (blobs : Nat) (proofsOK : Bool) : LandingEnv :=
  let proofs := if proofsOK then [(Backend.sgx, true), (Backend.sp1, true)] else [(Backend.sgx, true)]
  let draft : LandingEnv := ⟨block, referenceHash, refAvailable, (List.range blobs).map (· + 1), proofs,
    ⟨deployment, 0, 0, 0, 0, 0, i, 0, [], ⟨0, 0, 0, []⟩⟩⟩
  { draft with certificate := statementData s i (leavesHash s i leaves) draft }

def toVote (v : VoteIn) : Staking.Vote :=
  ⟨if v.foreign then foreignDeployment else deployment, v.generation, v.height, v.round, v.kind, v.blockId⟩

/-- The World after a successful call and the call's results, or `none` for a revert. -/
abbrev Outcome := Option (ProtocolState.World × List (String × Nat))

def editWith (w : ProtocolState.World) (id now : Nat) (action : RegistryHistory.Edit)
    (result : List (String × Nat)) : Outcome :=
  (RegistryHistory.edit w.registry w.inbox id now action).map fun r => (ProtocolState.registered w r now, result)

/-- The model transition of one call at timestamp `ts`. An enqueue also needs the block and
timestamp ranges of `ProtocolState.Step.enqueue`. A sweep's transfer succeeds when the
recipient accepts ETH or the balance is zero (no transfer is made). -/
def exec (d : Deploy) (w : ProtocolState.World) (c : Call) (ts : Nat) : Outcome :=
  match c.op with
  | .land i leaves ref blobs ok =>
    (ProtocolState.land w i leaves (landEnv w.inbox i leaves c.block ref blobs ok)).map fun t => (t, [])
  | .enqueue _ raw paid refund =>
    if c.block < limit48 ∧ ts < limit48 then
      (Forced.enqueue w.inbox raw paid refund).map fun s =>
        let fee := s.feeAdmissions - w.inbox.feeAdmissions
        (ProtocolState.enqueued w s (if raw = 0 then blankHash else txAtom w.inbox.tail) ts c.block,
          [("feeWei", fee), ("refund", paid - fee)])
    else none
  | .sweep _ =>
    (Forced.sweep w.inbox (d.recipientAccepts || w.inbox.ethBalance == 0)).map fun s =>
      (ProtocolState.landed w s c.block, [("swept", w.inbox.ethBalance)])
  | .forceETH amount => some ({ w with inbox := Forced.extraETH w.inbox amount, l1Block := c.block }, [])
  | .recover owner a =>
    (ProtocolState.recover w a ⟨w.inbox.checkpoint.height, c.block, ts⟩ owner true).map
      fun t => (t, [])
  | .invalidateRecoveryNonce owner expected =>
    (ProtocolState.invalidateRecoveryNonce w expected c.block owner).map fun t => (t, [])
  | .rollbackGenesis =>
    (ProtocolState.rollback w (inbox0 d).checkpoint (inbox0 d).snapshot c.block).map fun t => (t, [])
  | .register caller key amount =>
    (RegistryHistory.register w.registry key caller amount c.block).map fun r =>
      (ProtocolState.registered w r c.block, [("bondId", (RegistryHistory.allocation w.registry).1)])
  | .topUp caller id amount transferOK =>
    if transferOK then editWith w id c.block (.topUp caller amount) [] else none
  | .activateTopUp _ id => editWith w id c.block .activateTopUp []
  | .forfeit owner id key incident validUntil externalOK =>
    let penalty := Staking.forfeitPenalty (w.registry.slots id).balance w.registry.forfeitBps
    editWith w id c.block (.forfeit key incident validUntil ts owner externalOK) [("toSink", penalty)]
  | .requestExit caller id => editWith w id c.block (.requestExit caller) []
  | .confirmExit _ id => editWith w id c.block .confirm []
  | .withdraw caller id _ => editWith w id c.block (.withdraw caller) [("paid", (w.registry.slots id).balance)]
  | .slash _ id a b =>
    let stake := (w.registry.slots id).balance
    let bounty := Staking.fraction stake w.registry.slashBountyBps
    editWith w id c.block (.slash (toVote a) (toVote b) a.signer b.signer) [("bounty", bounty), ("toSink", stake-bounty)]

/-! Observable state. Keys of the objects inside arrays are in alphabetical order, so a
Solidity harness can decode each array into a struct array in one read. -/

/-- Schema 2 preserves exact uint256 boundaries without lossy JSON doubles. -/
def uintJ (n : Nat) : JVal := if n < 9007199254740992 then jNat n else jStr (Nat.repr n)

def currentFee (s : State) : Nat := Forced.admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head)

def recordJ (r : Checkpoint) : JVal :=
  jLine [("cometHash", jNat r.cometHash), ("elHash", jNat r.elHash), ("generation", jNat r.generation),
    ("head", jNat r.cursor), ("height", jNat r.height), ("parentHeight", jNat r.parent)]

def signalJ (g : Signal) : JVal :=
  jLine [("hash", jNat g.hash), ("height", jNat g.height), ("stateRoot", jNat g.stateRoot)]

def originJ (o : Nat × Origin) : JVal :=
  jLine [("generation", jNat o.1), ("height", jNat o.2.height), ("l1Block", jNat o.2.l1Block),
    ("timestamp", jNat o.2.timestamp)]

def queueJ (e : Nat × Forced.Entry) : JVal :=
  jLine [("blank", jBool (e.2.txHash == blankHash)), ("index", jNat e.1), ("l1Block", jNat e.2.l1Block),
    ("timestamp", jNat e.2.timestamp)]

def inboxJ (w : ProtocolState.World) : JVal :=
  let s := w.inbox
  jObj [("checkpointHeight", jNat s.checkpoint.height), ("checkpointHash", jNat s.checkpoint.elHash),
    ("generation", jNat s.generation), ("recoveryNonce", uintJ s.recoveryNonce), ("head", jNat s.head), ("tail", jNat s.tail),
    ("snapshot", jNat s.snapshot), ("ethBalance", jNat s.ethBalance), ("swept", jNat s.swept),
    ("feeGwei", jNat (currentFee s / gwei)),
    ("records", jArr ((s.records.mergeSort fun a b => decide (a.height ≤ b.height)).map recordJ)),
    ("signals", jArr (s.signals.map signalJ)), ("origins", jArr (s.origins.map originJ)),
    ("queue", jArr (w.queue.map queueJ))]

def sumBalances (r : RegistryHistory.State) : Nat := ((List.range r.nextId).map fun id => (r.slots id).balance).sum

def bondJ (r : RegistryHistory.State) (id : Nat) : JVal :=
  let b := r.slots id
  jLine [("activeFrom", jNat b.activeFrom), ("confirmedAt", jNat (b.confirmedAt.getD 0)), ("exitAt", jNat b.exitAt),
    ("id", jNat id), ("key", jNat b.key), ("owner", jNat b.owner), ("pendingTopUp", uintJ b.pendingTopUp),
    ("stake", uintJ b.stake), ("topUpReadyAtL1", jNat b.topUpReadyAtL1)]

/-- Election snapshots expose effective fields only; pending principal is metadata. -/
def entryJ (e : Committee.Entry) : JVal :=
  jLine [("activeFrom", jNat e.activeFrom), ("exitAt", jNat e.exitAt), ("key", jNat e.key), ("stake", uintJ e.stake)]

def checkpointJ (cp : RegistryHistory.Snapshot) : JVal :=
  jLine [("block", jNat cp.block), ("entries", jRow (cp.entries.map entryJ))]

def registryJ (r : RegistryHistory.State) : JVal :=
  let last := r.history.head?.getD default
  jObj [("entryCount", jNat r.nextId), ("freeCount", jNat r.free.length), ("stakeHeld", uintJ (sumBalances r)),
    ("checkpointCount", jNat r.history.length), ("lastCheckpointBlock", jNat last.block),
    ("lastCheckpointCount", jNat last.entries.length), ("checkpoints", jArr (r.history.map checkpointJ)),
    ("forfeitedKeys", jNats r.forfeited), ("bonds", jArr ((List.range r.nextId).map (bondJ r)))]

/-! Calls as JSON. -/

def leafJ : Leaf → JVal
  | .cut x c => jLine [("comet", jNat c.cometHash), ("cut", jBool true), ("el", jNat c.elHash),
      ("head", jNat c.cursor), ("height", jNat x), ("word", jNat 0)]
  | .word n => jLine [("comet", jNat 0), ("cut", jBool false), ("el", jNat 0), ("head", jNat 0),
      ("height", jNat 0), ("word", jNat n)]

def voteJ (v : VoteIn) : JVal :=
  jLine [("blockId", jNat v.blockId), ("foreign", jBool v.foreign), ("generation", jNat v.generation),
    ("height", jNat v.height), ("kind", jNat v.kind), ("round", jNat v.round), ("signer", jNat v.signer)]

def opJ : Op → String × List (String × JVal)
  | .land i leaves ref blobs ok => ("land",
      [("parentHeight", jNat i.parentHeight), ("lastHeight", jNat i.lastHeight),
       ("lastBlockHash", jNat i.lastBlockHash), ("lastCometHash", jNat i.lastCometHash),
       ("lastStateRoot", jNat i.lastStateRoot), ("l1ReferenceBlockNumber", jNat i.l1ReferenceBlockNumber),
       ("forcedInclusionHead", jNat i.forcedInclusionHead), ("activeCommitteeSnapshot", jNat i.activeCommitteeSnapshot),
       ("refAvailable", jBool ref), ("blobs", jNat blobs), ("proofsOK", jBool ok),
       ("leafCount", jNat leaves.length), ("leaves", jRow (leaves.map leafJ))])
  | .enqueue caller raw paid refund => ("saveForcedInclusion",
      [("caller", jNat caller), ("rawBytes", jNat raw), ("paid", jNat paid), ("refundOK", jBool refund)])
  | .sweep caller => ("sweepProtocolFees", [("caller", jNat caller)])
  | .forceETH amount => ("forceETH", [("amount", jNat amount)])
  | .recover owner a => ("recover",
      [("owner", jBool owner), ("expectedGeneration", jNat a.generation), ("expectedC", jNat a.checkpoint),
       ("expectedRecoveryNonce", uintJ a.nonce), ("validUntil", uintJ a.validUntil),
       ("exclusionCount", jNat a.exclusions.length),
       ("exclusions", jRow (a.exclusions.map fun x => jLine [("bondId", jNat x.bondId), ("key", jNat x.entryKey)])),
       ("fiToClear", jNats a.fiToClear)])
  | .invalidateRecoveryNonce owner expected => ("invalidateRecoveryNonce",
      [("owner", jBool owner), ("expectedRecoveryNonce", uintJ expected)])
  | .rollbackGenesis => ("verifierFailureRollback", [])
  | .register caller key amount => ("register",
      [("caller", jNat caller), ("key", jNat key), ("amount", uintJ amount)])
  | .topUp caller id amount transferOK => ("topUp",
      [("caller", jNat caller), ("bondId", jNat id), ("amount", uintJ amount), ("transferOK", jBool transferOK)])
  | .activateTopUp caller id => ("activateTopUp", [("caller", jNat caller), ("bondId", jNat id)])
  | .forfeit owner id key incident validUntil externalOK => ("forfeit",
      [("owner", jBool owner), ("bondId", jNat id), ("entryKey", jNat key), ("incidentId", jNat incident),
       ("validUntil", uintJ validUntil), ("externalOK", jBool externalOK)])
  | .requestExit caller id => ("requestExit", [("caller", jNat caller), ("bondId", jNat id)])
  | .confirmExit caller id => ("confirmExit", [("caller", jNat caller), ("bondId", jNat id)])
  | .withdraw caller id recipient => ("withdraw",
      [("caller", jNat caller), ("bondId", jNat id), ("to", jNat recipient)])
  | .slash caller id a b => ("slashDoubleSign",
      [("caller", jNat caller), ("bondId", jNat id), ("voteA", voteJ a), ("voteB", voteJ b)])

/-- One call on one line. -/
def callJ (c : Call) (ts : Nat) : JVal :=
  let (fn, args) := opJ c.op
  jLine [("block", jNat c.block), ("timestamp", jNat ts), ("fn", jStr fn), ("args", jLine args)]

def deployJ (d : Deploy) : JVal :=
  jLine [("activationDelay", jNat d.activationDelay), ("bountyBps", jNat d.bountyBps), ("exitDelay", jNat d.exitDelay),
    ("feeGwei", jNat d.feeGwei), ("forfeitBps", jNat d.forfeitBps), ("initialized", jBool d.initialized), ("maxBatchBlocks", jNat d.maxBatchBlocks),
    ("minStake", uintJ d.minStake), ("recoveryNonce", uintJ d.recoveryNonce), ("registrySize", jNat d.registrySize), ("recipientAccepts", jBool d.recipientAccepts), ("threshold", jNat d.threshold),
    ("unsettled", jNat d.unsettled), ("withdrawalDelay", jNat d.withdrawalDelay)]

/-! Scenarios. A step computes its call from the World it runs on, so a setup can land the
chain it has, cover an exit it requested or pay the current fee. -/

abbrev CaseStep := ProtocolState.World → Call

/-- A vector before rendering. `spec` marks a hand-written case (an English spec line). -/
structure Scenario where
  label : String
  spec : Option String := none
  deploy : Deploy := {}
  setup : List CaseStep := []
  call : CaseStep
  inbox : Bool := true
  registry : Bool := false
  /-- The final call's timestamp, if not `timestampOf` its block. -/
  callTimestamp : Option Nat := none

def later (k : Nat) (op : Op) : CaseStep := fun w => ⟨w.l1Block+k, op⟩

def atBlock (b : Nat) (op : Op) : CaseStep := fun _ => ⟨b, op⟩

/-- Caller 2 enqueues a `raw`-byte transaction paying exactly the current fee. -/
def enqueueExact (raw : Nat := 32) : CaseStep := fun w => ⟨w.l1Block+1, .enqueue 2 raw (currentFee w.inbox) true⟩

def fill (n : Nat) : List CaseStep := (List.range n).map fun _ => enqueueExact

/-- The honest leaves of (p, h): a landing record's cut where one exists (the frontier c
included), a word at every other grid point. -/
def chainLeaves (s : State) (p h : Nat) : List Leaf :=
  (List.range (gridCount landGrid p h)).map fun j =>
    let x := p + landGrid*(j+1)
    match recordAt s x with
    | some r => cutLeaf x ⟨r.elHash, r.cometHash, r.cursor⟩
    | none => .word (wordAtom s.generation x)

/-- The landing input for (p, h] of the current generation's chain, with reference block
`block - 1`. -/
def chainInput (s : State) (p h head snapshot block : Nat) : LandInput :=
  ⟨p, h, elAtom s.generation h, cometAtom s.generation h, rootAtom s.generation h, block-1, head, snapshot⟩

/-- Land (c, h] from p = c at the next block (or `atLeast`), consuming `consume` entries and
proving `snapshot` (default: the current one). -/
def landTo (h : Nat) (consume : Nat := 0) (snapshot : Option Nat := none) (atLeast : Nat := 0) : CaseStep := fun w =>
  let s := w.inbox
  let b := max (w.l1Block+1) atLeast
  let c := s.checkpoint.height
  ⟨b, .land (chainInput s c h (s.head+consume) (snapshot.getD s.snapshot) b) (chainLeaves s c h) true 1 true⟩

/-- Land one grid segment proving bond `id`'s exit block as the snapshot, after that block. -/
def coverExit (id : Nat) : CaseStep := fun w =>
  let exit := (w.registry.slots id).exitAt
  landTo (w.inbox.checkpoint.height+landGrid) 0 (some exit) (exit+1) w

/-- Withdraw bond `id` at the first block its withdrawal delay allows. -/
def withdrawWhenDue (id caller recipient : Nat) : CaseStep := fun w =>
  let due := (w.registry.slots id).confirmedAt.getD 0 + w.registry.withdrawalDelay
  ⟨max (w.l1Block+1) due, .withdraw caller id recipient⟩

/-- The owner exits bond `id`, a landing covers the exit, caller 9 confirms it and the owner
withdraws to itself. -/
def release (id owner : Nat) : List CaseStep :=
  [later 1 (.requestExit owner id), coverExit id, later 1 (.confirmExit 9 id), withdrawWhenDue id owner owner]

/-- The owner recovers at the next block with the current generation and checkpoint. -/
def recoverNow (exclusions : List Recovery.Exclusion := []) (fi : List Nat := []) : CaseStep := fun w =>
  ⟨w.l1Block+1, .recover true ⟨w.inbox.generation, w.inbox.checkpoint.height, exclusions, fi, w.inbox.recoveryNonce, limit256-1⟩⟩

/-! Rendering. -/

def runSetup (d : Deploy) : ProtocolState.World → List CaseStep → Nat → Except String (ProtocolState.World × List Call)
  | w, [], _ => .ok (w, [])
  | w, s :: rest, k =>
    let c := s w
    if c.block < w.l1Block then .error ("setup call " ++ Nat.repr k ++ " runs before the World clock")
    else match exec d w c (timestampOf c.block) with
      | none => .error ("setup call " ++ Nat.repr k ++ " is rejected by the model")
      | some (t, _) => (runSetup d t rest (k+1)).map fun (u, cs) => (u, c :: cs)

def resultJ (xs : List (String × Nat)) : JVal := jLine (xs.map fun (k, v) => (k, uintJ v))

def observableJ (sc : Scenario) (w : ProtocolState.World) : JVal :=
  jObj ((if sc.inbox then [("inbox", inboxJ w)] else []) ++
    (if sc.registry then [("registry", registryJ w.registry)] else []))

def renderScenario (family : String) (sc : Scenario) : Except String JVal := do
  let some w0 := world0 sc.deploy | throw (sc.label ++ ": the genesis registration is rejected")
  let (w, calls) ← (runSetup sc.deploy w0 sc.setup 0).mapError fun e => sc.label ++ ": " ++ e
  let c := sc.call w
  if c.block < w.l1Block then throw (sc.label ++ ": the call runs before the World clock")
  let ts := sc.callTimestamp.getD (timestampOf c.block)
  let (revert, post, result) := match exec sc.deploy w c ts with
    | none => (true, w, [])
    | some (t, r) => (false, t, r)
  pure <| jObj ([("id", jStr sc.label), ("family", jStr family),
      ("source", jStr (if sc.spec.isSome then "handwritten" else "generated"))] ++
    (match sc.spec with | some s => [("spec", jStr s)] | none => []) ++
    [("setup", jObj [("deployment", deployJ sc.deploy), ("callCount", jNat calls.length),
       ("calls", jArr (calls.map fun s => callJ s (timestampOf s.block)))]),
     ("call", callJ c ts),
     ("expect", jObj [("revert", jBool revert), ("result", resultJ result), ("observable", observableJ sc post)])])

def constantsJ : JVal :=
  jObj [("gridInterval", jNat landGrid), ("registeredAt", jNat registeredAt), ("initAt", jNat initAt),
    ("timestampBase", jNat timestampBase), ("timestampStep", jNat 12), ("genesisKey", jNat genesisKey),
    ("genesisOwner", jNat genesisOwner), ("epochLenL2", jNat epochLength), ("forcedInclusionDelay", jNat fiDelay),
    ("maxAnchorAge", jNat anchorAge), ("vpUnit", jNat vpUnit), ("sMin", jNat vpUnit), ("nMax", jNat 128),
    ("referenceHash", jNat referenceHash)]

/-- One family file. Labels are unique and every hand-written vector cites a spec line. The file
records only what the model decides; a consumer keeps its own list of known divergences. Its
header names the command that wrote it (`generator`). -/
def familyFileWith (generator family : String) (provenance : Option String) (scs : List Scenario) :
    Except String String := do
  let labels := scs.map (·.label)
  unless decide labels.Nodup do throw (family ++ ": duplicate vector ids")
  for sc in scs do
    if sc.spec.isNone && (sc.label.splitOn ".hw.").length > 1 then
      throw (sc.label ++ ": a hand-written vector needs a spec line")
  let vectors ← scs.mapM (renderScenario family)
  let head : List (String × JVal) := [("schema", jStr "etna-conformance-2"), ("family", jStr family),
    ("generator", jStr generator)]
  let prov : List (String × JVal) := match provenance with
    | some sha => [("provenance", jLine [("formalCommit", jStr sha)])]
    | none => []
  pure (jObj (head ++ prov ++ [("constants", constantsJ), ("vectorCount", jNat vectors.length),
    ("vectors", jArr vectors)]) 0 ++ "\n")

/-- A committed family file. -/
def familyFile (family : String) (provenance : Option String) (scs : List Scenario) : Except String String :=
  familyFileWith "formal/etna: lake exe etna-vectors --write testdata/etna_conformance" family provenance scs

end Etna.Vectors
