import EtnaModel.Staking
import EtnaModel.Recovery

/-! L1 registry specification state. Keys are canonical abstract registration identities
(the real key/address/PoP binding is external). Historical snapshots contain election
entries only: owner and exit confirmation metadata never enter entriesRoot. -/
namespace Etna.Design.RegistryHistory

structure Snapshot where
  block : Nat
  entries : List Committee.Entry
  deriving DecidableEq, Repr, Inhabited

/-- Newest checkpoint first. An entry-changing transaction in the same L1 block replaces
that block's checkpoint; finalized later blocks never mutate an older snapshot. -/
def recordSnapshot (now : Nat) (entries : List Committee.Entry) : List Snapshot → List Snapshot
  | [] => [⟨now,entries⟩]
  | head :: rest => if head.block = now then ⟨now,entries⟩ :: rest else ⟨now,entries⟩ :: head :: rest

def latestSnapshot (history : List Snapshot) (cutoff : Nat) : Option Snapshot :=
  history.find? (fun cp => decide (cp.block ≤ cutoff))

def Ordered (history : List Snapshot) : Prop := history.Pairwise (fun a b => b.block < a.block)

instance (history : List Snapshot) : Decidable (Ordered history) :=
  inferInstanceAs (Decidable (history.Pairwise (fun a b => b.block < a.block)))

def vacant : Staking.Bond := ⟨0,0,0,0,0,true,none,0,0⟩

structure State where
  nextId : Nat
  free : List Nat
  slots : Nat → Staking.Bond
  usedKeys : List Hash
  history : List Snapshot
  /-- Fixed signature adapter; public edit actions cannot choose or replace it. -/
  verify : Hash → Staking.Vote → Hash → Bool := fun _ _ _ => false
  /-- Registry immutable `slashBountyBps` (spec: ≤ 10000, suggested 1000; slashing fails
  for an out-of-range value). Slash callers cannot choose it. -/
  slashBountyBps : Nat := 1000
  /-- §11 registry immutables, in L1 blocks: `minStake` and the activation, exit and
  withdrawal delays (§10: positive activation/exit delays; withdrawalDelay suggested
  ≥ 50,400 blocks). register, requestExit and withdraw read them; no call input carries them. -/
  minStake : Nat := 1
  activationDelay : Nat := 1
  exitDelay : Nat := 1
  withdrawalDelay : Nat := 50400
  /-- Fixed responsibility-forfeiture rate, validated at deployment and execution. -/
  forfeitBps : Nat := 1000
  /-- Lifetime entry-key flags; release, reuse and rollback never clear them. -/
  forfeited : List Hash := []

def empty : State := { nextId := 0,free := [],slots := fun _ => vacant,usedKeys := [],history := [] }

def entries (s : State) : List Committee.Entry :=
  (List.range s.nextId).map (fun id => Staking.toEntry (s.slots id))

def lastBlock (s : State) : Nat := ((s.history.head?).getD default).block

/-- Metadata-only changes do not write a registry checkpoint. -/
def finish (before : State) (now : Nat) (after : State) : State :=
  { after with history := if entries after = entries before then before.history
    else recordSnapshot now (entries after) before.history }

def writeSlot (s : State) (id : Nat) (b : Staking.Bond) : State :=
  { s with slots := fun i => if i = id then b else s.slots i }

/-- Freed slots are used before allocating another of the 4096 slots. -/
def allocation (s : State) : Nat × List Nat × Nat :=
  match s.free with
  | [] => (s.nextId,[],s.nextId+1)
  | id :: rest => (id,rest,s.nextId)

/-- `amount ≥ minStake` and the activation delay are the registry's own immutables. -/
def RegisterAllowed (s : State) (key amount now : Nat) : Prop :=
  let (id,_,next) := allocation s
  lastBlock s ≤ now ∧ key ≠ 0 ∧ key ∉ s.usedKeys ∧ s.minStake ≤ amount ∧ 0 < s.minStake ∧
  0 < s.activationDelay ∧ now+s.activationDelay < Staking.noExit ∧ id < next ∧ next ≤ 4096 ∧
  (s.slots id).released = true

instance (s : State) (key amount now : Nat) :
    Decidable (RegisterAllowed s key amount now) := inferInstanceAs (Decidable (_ ∧ _))

/-- Key possession/canonical decoding has been authenticated before this decoded operation.
The owner, amount and activation range are then fixed by this registry transition; the
minimum and activation delay are registry immutables, not call inputs. -/
def register (s : State) (key owner amount now : Nat) : Option State :=
  if RegisterAllowed s key amount now then
    let (id,free,next) := allocation s
    let fresh : Staking.Bond := ⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩
    some (finish s now { writeSlot s id fresh with nextId := next,free := free,usedKeys := key :: s.usedKeys })
  else none

/-- Public calls carry no Inbox-initialization flag, bounty or delay: the registry reads
the Inbox state and its own immutables. -/
inductive Edit where
  | requestExit (caller : Nat)
  | confirm
  | withdraw (caller : Nat)
  | topUp (caller amount : Nat)
  | activateTopUp
  | forfeit (entryKey incidentId validUntil timestamp : Nat) (owner externalOK : Bool)
  | slash (a b : Staking.Vote) (sigA sigB : Hash)
  | forceExit
  | recheck (snapshot : Nat)
  deriving DecidableEq, Repr

/-- Signature authentication is the only evidence adapter boundary. In particular the
verified signer identity must equal the slot's current occupant before slashing. The
verifier, bounty and exit/withdrawal delays are the fixed values of registry `r` (`edit`
passes its own State). -/
def editBond (r : State) (inbox : Etna.Design.State) (now : Nat) (b : Staking.Bond) : Edit → Option Staking.Bond
  | .requestExit caller => Staking.requestExit b caller now r.exitDelay
  | .confirm => Staking.confirmExit inbox b now
  | .withdraw caller => (Staking.withdraw inbox b caller now r.withdrawalDelay).map Prod.fst
  | .topUp caller amount => Staking.topUp inbox b caller amount now r.activationDelay
  | .activateTopUp => Staking.activateTopUp inbox b now
  | .forfeit key _ validUntil timestamp owner externalOK =>
      (Staking.forfeit inbox b key now timestamp validUntil r.forfeitBps owner
        (decide (key ∉ r.forfeited)) externalOK).map Prod.fst
  | .slash a v sigA sigB =>
      if r.verify b.key a sigA = true ∧ r.verify b.key v sigB = true ∧ Staking.doubleSign inbox.domain inbox.generation a v = true then
        (Staking.slashDouble inbox b now r.slashBountyBps).map (fun x => x.1)
      else none
  | .forceExit => if b.released = false then some (Staking.exclude b now) else none
  | .recheck snapshot => some (Staking.rollbackBySnapshot snapshot b)

/-- Called only after the corresponding bond edit succeeds; attribution identifiers do
not deduplicate separate entries. Every other operation preserves the lifetime flags. -/
def forfeitFlags (s : State) : Edit → List Hash
  | .forfeit key _ _ _ _ _ => key :: s.forfeited
  | _ => s.forfeited

def edit (s : State) (inbox : Etna.Design.State) (id now : Nat) (action : Edit) : Option State :=
  if id < s.nextId ∧ lastBlock s ≤ now ∧ inbox.entered = false then
    (editBond s inbox now (s.slots id) action).map fun b =>
      finish s now { writeSlot s id b with
        free := if b.released && !(s.slots id).released then s.free ++ [id] else s.free,
        forfeited := forfeitFlags s action }
  else none

/-- Registry-side rollback changes confirmation metadata only; it never rewinds entries,
principal transfers, lifetime key identity or historical election checkpoints. -/
def recheckAll (s : State) (snapshot : Nat) : State :=
  { s with slots := fun id => Staking.rollbackBySnapshot snapshot (s.slots id) }

def KeysValid (s : State) : Prop := s.nextId ≤ 4096 ∧ s.usedKeys.Nodup

def IdentitiesValid (s : State) : Prop :=
  ∀ id, id < s.nextId → (s.slots id).released = false → (s.slots id).key ∈ s.usedKeys

/-- Full allocated-slot view; array position is the bond id, including zeroed released slots. -/
def registryView (s : State) : List (Nat × Committee.Entry) :=
  (List.range s.nextId).map (fun id => (id,Staking.toEntry (s.slots id)))

/-- Internal recovery journal operation; not a separate public force-exit entrypoint. -/
def forceExclusions (s : State) (xs : List Recovery.Exclusion) (now : Nat) : State :=
  finish s now { s with slots := fun id =>
    if Recovery.exclusionApplies xs id (s.slots id).key then Staking.exclude (s.slots id) now else s.slots id }

inductive FutureTrace (cutoff : Nat) : State → State → Prop
  | refl (s : State) : FutureTrace cutoff s s
  | registration {first s t : State} {key owner amount now : Nat}
      (prior : FutureTrace cutoff first s) (past : cutoff < now)
      (ok : register s key owner amount now = some t) : FutureTrace cutoff first t
  | modification {first s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
      (prior : FutureTrace cutoff first s) (past : cutoff < now)
      (ok : edit s inbox id now action = some t) : FutureTrace cutoff first t
  | recovery {first s : State} (xs : List Recovery.Exclusion) (now : Nat)
      (prior : FutureTrace cutoff first s) (past : cutoff < now) : FutureTrace cutoff first (forceExclusions s xs now)
  | rollback {first s : State} (snapshot : Nat) (prior : FutureTrace cutoff first s) :
      FutureTrace cutoff first (recheckAll s snapshot)

def CurrentSnapshot (s : State) : Prop :=
  (s.history.head?).map Snapshot.entries = some (entries s) ∨ (s.nextId = 0 ∧ s.history = [])

inductive Step : State → State → Prop
  | registration {s t : State} {key owner amount now : Nat}
      (ok : register s key owner amount now = some t) : Step s t
  | modification {s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
      (ok : edit s inbox id now action = some t) : Step s t
  | rollback (s : State) (snapshot : Nat) : Step s (recheckAll s snapshot)

inductive Trace : State → State → Prop
  | refl (s : State) : Trace s s
  | step {first s t : State} (prior : Trace first s) (change : Step s t) : Trace first t

end Etna.Design.RegistryHistory
