import EtnaModel.Current

/-! Current permanent bond registry. Public calls are closed; cryptographic adapters
are deployment immutables, never evidence arguments. -/
namespace Etna.Design.Current.RegistryMachine

structure Config where
  exitDelay : Nat := 1
  withdrawalDelay : Nat := 50400
  slashBountyBps : Nat := 1000
  forfeitBps : Nat := 1000
  owner : Nat := 1
  inbox : Nat := 2
  deriving DecidableEq, Repr

structure State where
  ledger : Registry.State
  config : Config := {}
  verify : Hash → Staking.Vote → Hash → Bool := fun _ _ _ => false
  /-- Canonical key decoding and owner/amount-bound registration PoP. -/
  registerAuth : Hash → Nat → Nat → Hash → Bool := fun _ _ _ _ => false
  /-- Canonical stored-public-key entryKey derivation (FORF-4.4-2). -/
  entryKey : Hash → Hash := id
  forfeited : List Hash := []
  history : List RegistryHistory.Snapshot := []

structure InboxView where
  domain : Domain
  generation : Nat
  snapshot : Nat
  initialized : Bool
  entered : Bool
  timestamp : Nat := 0
  deriving DecidableEq, Repr

/-- Slots, not permanent bond ids, index the complete election view. -/
def entries (s : State) : List Committee.Entry :=
  (List.range 4096).map fun slot =>
    match s.ledger.slots slot with
    | none => ⟨0,0,0,0⟩
    | some id => match s.ledger.bonds id with
      | none => ⟨0,0,0,0⟩
      | some b => Staking.toEntry b.value

def finish (before : State) (now : Nat) (after : State) : State :=
  { after with history := if entries after = entries before then before.history
    else RegistryHistory.recordSnapshot now (entries after) before.history }

def Evidence (s : State) (v : InboxView) (key : Hash)
    (a b : Staking.Vote) (sigA sigB : Hash) : Prop :=
  s.verify key a sigA = true ∧ s.verify key b sigB = true ∧
    Staking.doubleSign v.domain v.generation a b = true
instance (s : State) (v : InboxView) (key : Hash) (a b : Staking.Vote) (x y : Hash) :
    Decidable (Evidence s v key a b x y) := inferInstanceAs (Decidable (_ ∧ _))

inductive Action where
  | register (key caller amount pop : Nat)
  | requestExit (id caller : Nat)
  | topUp (id caller amount : Nat)
  | activateTopUp (id : Nat)
  | confirm (id : Nat)
  | withdraw (id caller to : Nat)
  | slash (id : Nat) (a b : Staking.Vote) (sigA sigB : Hash)
  | forfeit (id caller entryKey incidentId validUntil : Nat)
  /-- Internal recovery operation: all identities checked before any write. -/
  | exclude (caller snapshot : Nat) (xs : List (Nat × Hash))
  | recheck (caller snapshot : Nat)
  deriving DecidableEq, Repr

/-- Internal liability plumbing; callers cannot substitute a key or an edit function. -/
def writeValue (s : Registry.State) (id : Nat) (old : Registry.Bond)
    (value : Staking.Bond) : Registry.State :=
  Registry.updateBond s id ⟨{ value with key := old.value.key },old.slot⟩

def editValue (s : State) (id : Nat) (f : Staking.Bond → Option Staking.Bond) : Option State :=
  if id < s.ledger.nextId then
    (s.ledger.bonds id).bind fun b => (f b.value).map fun value =>
      { s with ledger := writeValue s.ledger id b value }
  else none

def bondEdit (s : State) (v : InboxView) (now : Nat) (b : Staking.Bond) : Action → Option Staking.Bond
  | .requestExit _ caller => Staking.requestExit b caller now s.config.exitDelay
  | .topUp _ caller amount =>
    if caller = b.owner ∧ b.released = false ∧ b.activeFrom ≤ now ∧ 0 < b.stake ∧
      b.exitAt = Staking.noExit ∧ b.pendingTopUp = 0 ∧ 0 < amount ∧
      b.balance+amount < limit256 ∧ 0 < s.ledger.activationDelay ∧
      now+s.ledger.activationDelay < limit48 then
      some { b with pendingTopUp := amount, topUpReadyAtL1 := now+s.ledger.activationDelay }
    else none
  | .activateTopUp _ =>
    if b.released = false ∧ 0 < b.pendingTopUp ∧ b.exitAt = Staking.noExit ∧
      b.topUpReadyAtL1 ≤ now ∧ b.balance < limit256 then
      some { b with stake := b.balance, pendingTopUp := 0, topUpReadyAtL1 := 0 }
    else none
  | .confirm _ =>
    if v.initialized = true ∧ b.released = false ∧ b.exitAt ≠ Staking.noExit ∧
      b.exitAt ≤ v.snapshot then
      some { b with confirmedAt := some (b.confirmedAt.getD now) }
    else none
  | .slash _ a z sa sz =>
    if v.initialized = true ∧ b.released = false ∧ 0 < b.balance ∧
      s.config.slashBountyBps ≤ 10000 ∧ Evidence s v b.key a z sa sz then
      some { b with stake := 0, pendingTopUp := 0, topUpReadyAtL1 := 0, exitAt := min b.exitAt now }
    else none
  | .forfeit _ caller key _ validUntil =>
    if v.initialized = true ∧ caller = s.config.owner ∧ b.released = false ∧
      key = s.entryKey b.key ∧ key ∉ s.forfeited ∧ 0 < b.balance ∧
      v.timestamp ≤ validUntil ∧ 0 < s.config.forfeitBps ∧ s.config.forfeitBps ≤ 10000 then
      let penalty := Staking.forfeitPenalty b.balance s.config.forfeitBps
      let pending := b.pendingTopUp-(penalty-b.stake)
      some { b with stake := b.stake-penalty, pendingTopUp := pending, topUpReadyAtL1 := if pending = 0 then 0 else b.topUpReadyAtL1, exitAt := min b.exitAt now }
    else none
  | _ => none

/-- Issued withdrawn bonds remain authentic; unissued default storage never does. -/
def exclusionsValid (s : State) (xs : List (Nat × Hash)) : Bool :=
  xs.all fun (id,key) => decide (id < s.ledger.nextId) &&
    ((s.ledger.bonds id).map fun b => s.entryKey b.value.key == key).getD false

def excludedLedger (s : State) (xs : List (Nat × Hash)) (snapshot : Nat) : Registry.State :=
  { s.ledger with bonds := fun id => (s.ledger.bonds id).map fun b =>
      if (xs.any (fun x => x.1 == id)) then ⟨Staking.exclude b.value snapshot,b.slot⟩ else b }

def recheckedLedger (s : State) (snapshot : Nat) : Registry.State :=
  { s.ledger with bonds := fun id => (s.ledger.bonds id).map fun b =>
      ⟨Staking.rollbackBySnapshot snapshot b.value,b.slot⟩ }

/-- Atomic decoded successful calls. Failure produces no state, flag or checkpoint. -/
def execute (s : State) (v : InboxView) (now : Nat) (action : Action) : Option State :=
  if v.entered = false then
    let result : Option State := match action with
      | .register key caller amount pop =>
          if s.registerAuth key caller amount pop = true then
            (Registry.register s.ledger key caller amount now).map fun p => { s with ledger := p.1 }
          else none
      | .withdraw id caller _ =>
          (Registry.withdraw s.ledger id caller now s.config.withdrawalDelay).map fun p =>
            { s with ledger := p.1 }
      | .exclude caller snapshot xs =>
          if caller = s.config.inbox ∧ v.initialized = true ∧ exclusionsValid s xs = true then
            some { s with ledger := excludedLedger s xs snapshot }
          else none
      | .recheck caller snapshot =>
          if caller = s.config.inbox then some { s with ledger := recheckedLedger s snapshot }
          else none
      | .forfeit id _ key _ _ =>
          (editValue s id (fun b => bondEdit s v now b action)).map fun t =>
            { t with forfeited := key :: s.forfeited }
      | .requestExit id _ | .topUp id _ _ | .activateTopUp id | .confirm id | .slash id _ _ _ _ =>
          editValue s id (fun b => bondEdit s v now b action)
    result.map (finish s now)
  else none

structure World where
  registry : State
  inbox : InboxView
  now : Nat

/-- Frames transport Inbox context only. The encompassing protocol authenticates its snapshot. -/
inductive Step : World → World → Prop
  | call {s t : State} {v : InboxView} {now : Nat} (action : Action)
      (ok : execute s v now action = some t) : Step ⟨s,v,now⟩ ⟨t,v,now⟩
  | frame (s : State) (v w : InboxView) (now later : Nat)
      (domain : w.domain = v.domain) (generation : v.generation ≤ w.generation)
      (initialized : v.initialized = true → w.initialized = true)
      (time : now ≤ later) (timestamp : v.timestamp ≤ w.timestamp) :
      Step ⟨s,v,now⟩ ⟨s,w,later⟩
  | rollback {s t : State} (v w : InboxView) (now : Nat)
      (domain : w.domain = v.domain) (generation : v.generation ≤ w.generation)
      (initialized : v.initialized = true → w.initialized = true)
      (timestamp : v.timestamp ≤ w.timestamp)
      (ok : execute s v now (.recheck s.config.inbox w.snapshot) = some t) :
      Step ⟨s,v,now⟩ ⟨t,w,now⟩

inductive Trace : World → World → Prop
  | refl (w : World) : Trace w w
  | step {first s t : World} (prior : Trace first s) (change : Step s t) : Trace first t

structure LedgerStable (s t : Registry.State) : Prop where
  next : s.nextId ≤ t.nextId
  minimum : t.minStake = s.minStake
  activation : t.activationDelay = s.activationDelay
  keys : ∀ key id, s.keyId key = some id → t.keyId key = some id
  bonds : ∀ id b, id < s.nextId → s.bonds id = some b →
    ∃ c, t.bonds id = some c ∧ c.value.key = b.value.key

structure Stable (s t : State) : Prop where
  config : t.config = s.config
  verify : t.verify = s.verify
  registration : t.registerAuth = s.registerAuth
  entryKey : t.entryKey = s.entryKey
  ledger : LedgerStable s.ledger t.ledger

structure WorldStable (s t : World) : Prop where
  registry : Stable s.registry t.registry
  domain : t.inbox.domain = s.inbox.domain
  generation : s.inbox.generation ≤ t.inbox.generation
  initialized : s.inbox.initialized = true → t.inbox.initialized = true
  time : s.now ≤ t.now
  timestamp : s.inbox.timestamp ≤ t.inbox.timestamp

end Etna.Design.Current.RegistryMachine
