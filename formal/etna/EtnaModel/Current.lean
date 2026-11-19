import EtnaModel.RegistryHistory
import EtnaModel.Signer

/-! Current decoded rules at main 9c832234b4. The old machine is a historical reference;
these definitions do not silently extend its headline theorems to the current design.
Crypto, authenticated L1 storage and stock EL/Comet adapters remain external. -/
namespace Etna.Design.Current

namespace Rules
structure Schedule where
  active : Nat
  next : Nat
  time : Nat
  stopTime : Nat
  deriving DecidableEq, Repr

structure Control where
  initialized : Bool
  owner : Nat
  maxAge : Nat
  deriving DecidableEq, Repr

def select (s : Schedule) (timestamp : Nat) : Nat :=
  if s.time ≤ timestamp then s.next else s.active

def fits (s : Schedule) : Prop := s.active < limit48 ∧ s.next < limit48 ∧
  s.time < limit48 ∧ s.stopTime < limit48
instance (s : Schedule) : Decidable (fits s) := inferInstanceAs (Decidable (_ ∧ _))

def replacement (s : Schedule) (now rules time : Nat) : Schedule :=
  { s with active := if s.time ≤ now then s.next else s.active, next := rules, time := time }

def scheduleRules (c : Control) (s : Schedule) (caller now rules time : Nat) : Option Schedule :=
  let next := replacement s now rules time
  if c.initialized = true ∧ caller = c.owner ∧
      (s.time ≤ now ∨ now+c.maxAge < s.time) ∧
      (rules = s.next ∨ rules = s.next+1) ∧ now+c.maxAge ≤ time ∧
      now+c.maxAge < limit48 ∧ fits next then some next else none

/-- START-10.1-5b: an existing stop can be changed only while it is more than maxAnchorAge
away; the new time is 0 (cancel) or at least maxAnchorAge ahead. -/
def scheduleStop (c : Control) (s : Schedule) (caller now time : Nat) : Option Schedule :=
  let next := { s with stopTime := time }
  if c.initialized = true ∧ caller = c.owner ∧
      (s.stopTime = 0 ∨ now+c.maxAge < s.stopTime) ∧
      (time = 0 ∨ now+c.maxAge ≤ time) ∧
      now+c.maxAge < limit256 ∧ fits next then some next else none

/-- START-10.1-14d: with a stop scheduled at the block's anchor, the block is invalid when its
parent's timestamp has reached `stopTime`, at any height. -/
def stopped (s : Schedule) (parentTime : Nat) : Bool :=
  decide (s.stopTime ≠ 0 ∧ s.stopTime ≤ parentTime)

/-- A flat accepted image set may cover a batch spanning the timestamp boundary. -/
def covers (implemented : List Nat) (s : Schedule) (timestamps : List Nat) : Bool :=
  timestamps.all (fun t => decide (select s t ∈ implemented))

/-- `recover` always clears the stop. A nonzero rules argument installs a new ruleset
for the new generation; zero preserves the pending/current rule schedule. -/
def recover (s : Schedule) (rules : Nat) : Option Schedule :=
  if rules = 0 then some { s with stopTime := 0 }
  else if rules = s.next+1 ∧ rules < limit48 then some ⟨rules,rules,0,0⟩ else none

inductive Trace (c : Control) : Schedule → Schedule → Prop
  | refl (s : Schedule) : Trace c s s
  | rules {first s t : Schedule} (prior : Trace c first s) (caller now rule time : Nat)
      (ok : scheduleRules c s caller now rule time = some t) : Trace c first t
  | stop {first s t : Schedule} (prior : Trace c first s) (caller now time : Nat)
      (ok : scheduleStop c s caller now time = some t) : Trace c first t
end Rules

namespace Registry
/-- Permanent identity and liabilities; an optional slot is separate from the bond id. -/
structure Bond where
  value : Staking.Bond
  slot : Option Nat
  deriving DecidableEq, Repr

structure State where
  nextId : Nat
  bonds : Nat → Option Bond
  slots : Nat → Option Nat
  keyId : Hash → Option Nat
  minStake : Nat := 1
  activationDelay : Nat := 1

/-- The first of `count` slots from `slot` that no bond holds. Occupancy alone decides;
a held slot stays held whatever its bond's balance, including zero. -/
def firstEmpty (s : State) (slot : Nat) : Nat → Option Nat
  | 0 => none
  | count+1 => if s.slots slot = none then some slot else firstEmpty s (slot+1) count

/-- STAKE-4.1-14a: the lowest-numbered empty slot of 4096, or none when every slot is held. -/
def admissionSlot (s : State) : Option Nat := firstEmpty s 0 4096

def updateBond (s : State) (id : Nat) (bond : Bond) : State :=
  { s with bonds := fun i => if i = id then some bond else s.bonds i }

/-- Successful issuance never reuses an id. Admission takes the lowest empty slot and never
moves or removes another bond; with every slot held, registration fails whatever the amount. -/
def register (s : State) (key owner amount now : Nat) : Option (State × Nat) :=
  match admissionSlot s with
  | none => none
  | some slot =>
    if s.keyId key = none ∧ key ≠ 0 ∧ s.minStake ≤ amount ∧ amount < limit256 ∧
        0 < s.activationDelay ∧ now+s.activationDelay < Staking.noExit then
      let fresh : Bond := ⟨⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩,some slot⟩
      some ({ updateBond s s.nextId fresh with
        nextId := s.nextId+1,
        slots := fun i => if i = slot then some s.nextId else s.slots i,
        keyId := fun k => if k = key then some s.nextId else s.keyId k },s.nextId)
    else none

/-- Every mutation, including internal recovery exclusions, authenticates issued ids. -/
def modify (s : State) (id : Nat) (f : Bond → Option Bond) : Option State :=
  if id < s.nextId then
    (s.bonds id).bind fun b => (f b).map (updateBond s id)
  else none

/-- This primitive changes only the bond. Withdrawal additionally clears its own slot, the
only way a bond leaves its slot; it never erases another bond's slot. -/
def withdrawn (b : Bond) : Bond :=
  ⟨{ b.value with owner := 0, stake := 0, pendingTopUp := 0, topUpReadyAtL1 := 0, released := true, confirmedAt := none },none⟩

def withdraw (s : State) (id caller now delay : Nat) : Option (State × Nat) :=
  if id < s.nextId then
    (s.bonds id).bind fun b => match b.value.confirmedAt with
    | none => none
    | some atL1 =>
      if b.value.released = false ∧ atL1+delay ≤ now ∧ atL1+delay < limit256 ∧
          (b.value.balance = 0 ∨ caller = b.value.owner) then
        let result := updateBond s id (withdrawn b)
        some ({ result with slots := fun slot => if b.slot = some slot ∧ s.slots slot = some id then none else s.slots slot },b.value.balance)
      else none
  else none

/-- Initialization is a separate authenticated storage fact, not origin-record presence. -/
def confirm (s : State) (initialized : Bool) (snapshot id now : Nat) : Option State :=
  modify s id fun b =>
    if initialized = true ∧ b.value.released = false ∧ b.value.exitAt ≠ Staking.noExit ∧
        b.value.exitAt ≤ snapshot then
      some ⟨{ b.value with confirmedAt := some (b.value.confirmedAt.getD now) },b.slot⟩
    else none

def exclude (s : State) (id key now : Nat) : Option State :=
  modify s id fun b => if b.value.key = key then some ⟨Staking.exclude b.value now,b.slot⟩ else none

/-- Reuse the exact principal-only slashing arithmetic after separately checking the
current initialized storage fact and fixed-adapter evidence. Slot possession is irrelevant. -/
def slash (s : State) (initialized evidence : Bool) (id now bounty : Nat) : Option State :=
  modify s id fun b =>
    if initialized = true ∧ evidence = true ∧ b.value.released = false ∧
        0 < b.value.balance ∧ bounty < 10000 then
      some ⟨{ b.value with stake := 0, pendingTopUp := 0, topUpReadyAtL1 := 0, exitAt := min b.value.exitAt now },b.slot⟩
    else none

inductive Trace : State → State → Prop
  | refl (s : State) : Trace s s
  | registration {first s t : State} (prior : Trace first s) (key owner amount now id : Nat)
      (ok : register s key owner amount now = some (t,id)) : Trace first t
  | modification {first s t : State} (prior : Trace first s) (id : Nat) (f : Bond → Option Bond)
      (ok : modify s id f = some t) : Trace first t
  | withdrawal {first s t : State} (prior : Trace first s) (id caller now delay payout : Nat)
      (ok : withdraw s id caller now delay = some (t,payout)) : Trace first t
end Registry

namespace Start
/-- Epochs remain absolute, even on switching networks. -/
def epochHeight (epoch len : Nat) : Nat := 1+epoch*len

def anchorAllowed (origin index parentAnchor anchor originL1 : Nat) : Bool :=
  decide (originL1 ≤ anchor ∧ (index = 1 ∨ parentAnchor ≤ anchor) ∧ origin < limit48)

/-- The Unzen Inbox's core state (`getCoreState()`) and the SignalService checkpoint saved by its
last accepted proof: its L2 height, block hash and stateRoot. The model keeps only that latest
checkpoint, whose hash is the last finalized hash. The contract reads the checkpoint stored at
S, which an earlier proof may have saved. LAND-6.1-8a also requires the last finalized hash to
be the start hash, so the two readings agree whenever a block hash fixes the block's height. -/
structure Unzen where
  nextProposal : Nat
  finalizedProposal : Nat
  finalizedHash : Hash
  checkpointExists : Bool
  checkpointHeight : Nat
  checkpointHash : Hash
  checkpointRoot : Hash
  deriving DecidableEq, Repr

/-- LAND-6.1-8a: while c is S on a switching network, every Unzen proposal is finalized, the
last finalized hash is the start hash, and the SignalService checkpoint at S
(`getCheckpoint(uint48(S))`) exists with the start hash and stateRoot. -/
def firstLanding (switching : Bool) (start checkpoint hash root : Nat) (u : Unzen) : Bool :=
  !switching || checkpoint != start || decide (u.nextProposal = u.finalizedProposal+1 ∧
    u.finalizedHash = hash ∧ u.checkpointExists = true ∧ u.checkpointHeight = start ∧
    u.checkpointHash = hash ∧ u.checkpointRoot = root)

structure Origin where
  height : Nat
  l1Block : Nat
  timestamp : Nat
  deriving DecidableEq, Repr

structure State where
  initialized : Bool
  start : Option (Nat × Hash × Hash)
  generation : Nat
  origins : Nat → Option Origin
  writer : Nat
  unzenInbox : Nat
  forkTime : Nat

def setOrigin (s : State) (caller now l1Block height hash root : Nat) : Option State :=
  if s.initialized = true ∧ s.start = none ∧ s.generation = 0 ∧
      caller = s.writer ∧ s.unzenInbox ≠ 0 ∧ s.forkTime ≤ now ∧
      0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 ∧ l1Block < limit48 then
    some { s with start := some (height,hash,root), origins := fun g => if g = 0 then some ⟨height,l1Block,now⟩ else s.origins g }
  else none

/-- A corrected start is a new generation, only before any landing. The original
origin record is retained. Authentication of the replacement Unzen state is external. -/
def correct (s : State) (owner authenticated : Bool) (checkpoint height hash root l1Block now : Nat) : Option State :=
  s.start.bind fun old =>
    if owner = true ∧ authenticated = true ∧ checkpoint = old.1 ∧
        0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 ∧
        s.generation+1 < limit48 ∧ l1Block < limit48 then
      some { s with start := some (height,hash,root), generation := s.generation+1, origins := fun g => if g = s.generation+1 then some ⟨height,l1Block,now⟩ else s.origins g }
    else none
inductive Trace : State → State → Prop
  | refl (s : State) : Trace s s
  | correction {first s t : State} (prior : Trace first s) (owner authenticated : Bool)
      (checkpoint height hash root l1Block now : Nat)
      (ok : correct s owner authenticated checkpoint height hash root l1Block now = some t) : Trace first t
end Start

namespace Import
/-- These facts are outputs of named fixed L1/MPT/stock-Comet/metadata adapters, not
arbitrary peer assertions. This boundary does not prove those adapter implementations.
`checkpointAuthenticated` means s's slot 285 record is landed in the node's own L1 view and
matches; `checkpointFinalized` means that L1 block is finalized in the same view (DATA-5.3-4).
The last three are the validator-state checks of DATA-5.4-3/5. `valStateAuthenticated`: the
supplied preimage of valStateHash(s − 1), with the EL hash of s − 1 (the parentHash of s's
authenticated EL header), gives header(s)'s app_hash (CONS-3.1-8). `validatorSetsMatch`: the
preimage's two sets, which sign s and s + 1, match header(s)'s validators_hash and
next_validators_hash. `committeesMatch`: the committees derived under 4.3 from the window and
the node's own L1 have the keys and powers of the sets that applying s's validator updates once
to the preimage derives for s + 1 and s + 2. No L1 record holds a validator-state hash; header(s)
is authenticated by the record's Comet hash. The three checks apply only for s > o. A snapshot
at s = o takes the existing 8.4 genesis path (DATA-5.4-1), with the validator state CometBFT
builds from this generation's genesis, so `inspect` does not read them there. -/
structure Candidate where
  generation : Nat
  origin : Nat
  height : Nat
  checkpointEL : Hash
  envelopeEL : Hash
  checkpointAuthenticated : Bool
  checkpointFinalized : Bool
  dataHashAuthenticated : Bool
  metadataAuthenticated : Bool
  materialAvailable : Bool
  valStateAuthenticated : Bool
  validatorSetsMatch : Bool
  committeesMatch : Bool
  deriving DecidableEq, Repr

inductive Decision where
  | reject | retry | halt | staged
  deriving DecidableEq, Repr

/-- A missing or mismatching record rejects; a record landed only in an unfinalized L1 block
leaves synchronization incomplete until it finalizes and verification is retried (DATA-5.3-4,
vectors 4.f and 4.m). A validator-state preimage that, with the EL hash of s − 1, does not
give header(s)'s app_hash is an invalid candidate. Only finalized, authenticated landing data
can prove a contradiction (DATA-5.4-5): an envelope EL hash that disagrees with the record; a
preimage that gives header(s)'s app_hash but whose two sets differ from header(s)'s
validators_hash or next_validators_hash; or a committee derived under 4.3 that differs from the
matching set derived from the preimage. The three validator-state checks apply only for s > o;
at s = o the genesis path ignores them. -/
def inspect (c : Candidate) (currentGeneration : Nat) : Decision :=
  if c.generation ≠ currentGeneration ∨ c.height < c.origin ∨
      c.checkpointAuthenticated = false ∨ c.dataHashAuthenticated = false ∨
      (c.origin < c.height ∧ c.valStateAuthenticated = false) then .reject
  else if c.checkpointFinalized = false then .retry
  else if c.envelopeEL ≠ c.checkpointEL ∨ (c.origin < c.height ∧ c.validatorSetsMatch = false) then .halt
  else if c.materialAvailable = false then .retry
  else if c.metadataAuthenticated = false then .reject
  else if c.origin < c.height ∧ c.committeesMatch = false then .halt
  else .staged

structure Installed where
  generation : Nat
  height : Nat
  headerNumbers : List Nat
  signer : Signer.State
  trusted : Bool

/-- First height whose EL header the import installs and retains: max(o, s - U + 1), with U the
unsettled bound (DATA-5.4-4). `s + 1 - U` is Nat subtraction, so it is 0 when U > s + 1. -/
def retainedFrom (c : Candidate) (unsettled : Nat) : Nat := max c.origin (c.height+1-unsettled)

/-- An interrupted staging phase publishes nothing. Current generation is rechecked
at publication; existing signer state is preserved in full, and import grants no trust. -/
def publish (c : Candidate) (currentGeneration unsettled : Nat) (signer : Signer.State)
    (durable : Bool) : Option Installed :=
  if durable = true ∧ inspect c currentGeneration = .staged then
    some ⟨c.generation,c.height,
      List.range' (retainedFrom c unsettled) (c.height+1-retainedFrom c unsettled),signer,false⟩
  else none
end Import
end Etna.Design.Current
