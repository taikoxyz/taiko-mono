import EtnaModel.RegistryHistory
import EtnaModel.Signer

/-! Current decoded rules at main 1135c9b. The old machine is a historical reference;
these definitions do not silently extend its headline theorems to the current design.
Crypto, authenticated L1 storage and stock EL/Comet adapters remain external. -/
namespace Etna.Design.Current

namespace Rules
structure Schedule where
  active : Nat
  next : Nat
  time : Nat
  stopTime : Nat
  stopGrid : Nat
  deriving DecidableEq, Repr

structure Control where
  initialized : Bool
  owner : Nat
  maxAge : Nat
  grid : Nat
  deriving DecidableEq, Repr

def select (s : Schedule) (timestamp : Nat) : Nat :=
  if s.time ≤ timestamp then s.next else s.active

def fits (s : Schedule) : Prop := s.active < limit48 ∧ s.next < limit48 ∧
  s.time < limit48 ∧ s.stopTime < limit48 ∧ s.stopGrid < limit48
instance (s : Schedule) : Decidable (fits s) := inferInstanceAs (Decidable (_ ∧ _))

def replacement (s : Schedule) (now rules time : Nat) : Schedule :=
  { s with active := if s.time ≤ now then s.next else s.active, next := rules, time := time }

def scheduleRules (c : Control) (s : Schedule) (caller now rules time : Nat) : Option Schedule :=
  let next := replacement s now rules time
  if c.initialized = true ∧ caller = c.owner ∧
      (s.time ≤ now ∨ now+c.maxAge < s.time) ∧
      (rules = s.next ∨ rules = s.next+1) ∧ now+c.maxAge ≤ time ∧
      now+c.maxAge < limit48 ∧ fits next then some next else none

def scheduleStop (c : Control) (s : Schedule) (caller now time grid : Nat) : Option Schedule :=
  let next := { s with stopTime := time, stopGrid := grid }
  if c.initialized = true ∧ caller = c.owner ∧
      (s.stopTime = 0 ∨ now+c.maxAge < s.stopTime) ∧
      ((time = 0 ∧ grid = 0) ∨
        (now+c.maxAge ≤ time ∧ 0 < grid ∧ 0 < c.grid ∧ grid % c.grid = 0)) ∧
      now+c.maxAge < limit256 ∧ fits next then some next else none

def stopped (s : Schedule) (start parentHeight parentTime : Nat) : Bool :=
  decide (s.stopTime ≠ 0 ∧ start ≤ parentHeight ∧
    (parentHeight-start) % s.stopGrid = 0 ∧ s.stopTime ≤ parentTime)

/-- A flat accepted image set may cover a batch spanning the timestamp boundary. -/
def covers (implemented : List Nat) (s : Schedule) (timestamps : List Nat) : Bool :=
  timestamps.all (fun t => decide (select s t ∈ implemented))

/-- `recover` always clears the stop. A nonzero rules argument installs a new ruleset
for the new generation; zero preserves the pending/current rule schedule. -/
def recover (s : Schedule) (rules : Nat) : Option Schedule :=
  if rules = 0 then some { s with stopTime := 0, stopGrid := 0 }
  else if rules = s.next+1 ∧ rules < limit48 then some ⟨rules,rules,0,0,0⟩ else none

inductive Trace (c : Control) : Schedule → Schedule → Prop
  | refl (s : Schedule) : Trace c s s
  | rules {first s t : Schedule} (prior : Trace c first s) (caller now rule time : Nat)
      (ok : scheduleRules c s caller now rule time = some t) : Trace c first t
  | stop {first s t : Schedule} (prior : Trace c first s) (caller now time grid : Nat)
      (ok : scheduleStop c s caller now time grid = some t) : Trace c first t
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

/-- A vacant slot has value zero; pending deposits count for admission, not elections. -/
def slotValue (s : State) (slot : Nat) : Nat :=
  match s.slots slot with
  | none => 0
  | some id => ((s.bonds id).map (fun b => b.value.balance)).getD 0

def search (s : State) (best : Nat) : List Nat → Nat
  | [] => best
  | slot :: rest => if slotValue s best = 0 then best else
      search s (if slotValue s slot < slotValue s best then slot else best) rest

def admissionSlot (s : State) : Nat := search s 0 (List.range' 1 4095)

def updateBond (s : State) (id : Nat) (bond : Bond) : State :=
  { s with bonds := fun i => if i = id then some bond else s.bonds i }

/-- Successful issuance never reuses an id. Displacement changes only slot ownership
and the old bond's exit; the old principal and key remain reachable by its lifetime id. -/
def register (s : State) (key owner amount now : Nat) : Option (State × Nat) :=
  let slot := admissionSlot s
  if s.keyId key = none ∧ key ≠ 0 ∧ 0 < s.minStake ∧ s.minStake ≤ amount ∧
      slotValue s slot < amount ∧ amount < limit256 ∧
      0 < s.activationDelay ∧ now+s.activationDelay < Staking.noExit then
    let displaced := match s.slots slot with
      | none => s
      | some id => match s.bonds id with
        | none => s
        | some b => updateBond s id ⟨Staking.exclude b.value now,none⟩
    let fresh : Bond := ⟨⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩,some slot⟩
    some ({ updateBond displaced s.nextId fresh with
      nextId := s.nextId+1,
      slots := fun i => if i = slot then some s.nextId else s.slots i,
      keyId := fun k => if k = key then some s.nextId else s.keyId k },s.nextId)
  else none

/-- Every mutation, including internal recovery exclusions, authenticates issued ids. -/
def modify (s : State) (id : Nat) (f : Bond → Option Bond) : Option State :=
  if id < s.nextId then
    (s.bonds id).bind fun b => (f b).map (updateBond s id)
  else none

/-- This primitive changes only the bond. Withdrawal additionally clears its own slot;
it must never erase a replacement bond's slot after displacement. -/
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
        0 < b.value.balance ∧ bounty ≤ 10000 then
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
/-- The subtraction guard matters: Nat subtraction alone accepts heights below S. -/
def onGrid (start grid height : Nat) : Bool :=
  decide (0 < grid ∧ start ≤ height ∧ (height-start) % grid = 0)

/-- Epochs remain absolute, even on switching networks. -/
def epochHeight (epoch len : Nat) : Nat := 1+epoch*len

def anchorAllowed (origin index parentAnchor anchor originL1 : Nat) : Bool :=
  decide (originL1 ≤ anchor ∧ (index = 1 ∨ parentAnchor ≤ anchor) ∧ origin < limit48)

structure Unzen where
  nextProposal : Nat
  finalizedProposal : Nat
  finalizedHash : Hash
  checkpointExists : Bool
  checkpointHash : Hash
  checkpointRoot : Hash
  deriving DecidableEq, Repr

def firstLanding (switching : Bool) (start checkpoint hash root : Nat) (u : Unzen) : Bool :=
  !switching || checkpoint != start || decide (u.nextProposal = u.finalizedProposal+1 ∧
    u.finalizedHash = hash ∧ u.checkpointExists = true ∧
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
arbitrary peer assertions. This boundary does not prove those adapter implementations. -/
structure Candidate where
  generation : Nat
  origin : Nat
  height : Nat
  checkpointEL : Hash
  envelopeEL : Hash
  checkpointAuthenticated : Bool
  dataHashAuthenticated : Bool
  metadataAuthenticated : Bool
  materialAvailable : Bool
  deriving DecidableEq, Repr

inductive Decision where
  | reject | retry | halt | staged
  deriving DecidableEq, Repr

def inspect (c : Candidate) (currentGeneration : Nat) : Decision :=
  if c.generation ≠ currentGeneration ∨ c.height < c.origin ∨
      c.checkpointAuthenticated = false ∨ c.dataHashAuthenticated = false then .reject
  else if c.envelopeEL ≠ c.checkpointEL then .halt
  else if c.materialAvailable = false then .retry
  else if c.metadataAuthenticated = false then .reject
  else .staged

structure Installed where
  generation : Nat
  height : Nat
  headerNumbers : List Nat
  signer : Signer.State
  trusted : Bool

/-- An interrupted staging phase publishes nothing. Current generation is rechecked
at publication; existing signer state is preserved in full, and import grants no trust. -/
def publish (c : Candidate) (currentGeneration : Nat) (signer : Signer.State)
    (durable : Bool) : Option Installed :=
  if durable = true ∧ inspect c currentGeneration = .staged then
    some ⟨c.generation,c.height,List.range' c.origin (c.height-c.origin+1),signer,false⟩
  else none
end Import
end Etna.Design.Current
