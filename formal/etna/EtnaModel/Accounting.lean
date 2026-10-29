import EtnaModel.ProtocolState

/-! Logical TAIKO-principal observer. The ledger records accepted deposit inputs and
the payout values returned by the staking operations; it never infers transfers from
balance differences. ETH/FI fees are a separate asset and are not included here.

`held` is an allocated-slot liability, not a measured ERC20 custody balance. Relating
this theorem to a token contract requires exact successful incoming/outgoing transfers,
atomic failure, and an initial custody endowment equal to the modeled liabilities. -/
namespace Etna.Design.Accounting

structure Flow where
  deposits : Nat := 0
  withdrawals : Nat := 0
  bounty : Nat := 0
  sink : Nat := 0
  deriving DecidableEq, Repr

def Flow.zero : Flow := {}
def Flow.add (a b : Flow) : Flow :=
  ⟨a.deposits+b.deposits,a.withdrawals+b.withdrawals,a.bounty+b.bounty,a.sink+b.sink⟩
def Flow.outgoing (a : Flow) : Nat := a.withdrawals+a.bounty+a.sink

def sumBalances (f : Nat → Nat) : Nat → Nat
  | 0 => 0
  | n+1 => sumBalances f n+f n

/-- Effective stake plus pending deposits, over exactly the allocated registry slots. -/
def held (s : RegistryHistory.State) : Nat :=
  sumBalances (fun id => (s.slots id).balance) s.nextId

/-- Needed because registration overwrites released slots. This is global, including
the next never-allocated slot, and is proved from `RegistryHistory.empty` below. -/
def ReleasedZero (s : RegistryHistory.State) : Prop :=
  ∀ id, (s.slots id).released = true → (s.slots id).balance = 0

/-- The empty deployment has no hidden principal outside its allocated range. This
stronger lifecycle invariant is useful for interpreting the initial endowment. -/
def UnallocatedZero (s : RegistryHistory.State) : Prop :=
  ∀ id, s.nextId ≤ id → (s.slots id).balance = 0

def SlotGood (s : RegistryHistory.State) : Prop := ReleasedZero s ∧ UnallocatedZero s

/-- Same decoded bond operations as `RegistryHistory.editBond`, retaining payouts. -/
def bondEffect (r : RegistryHistory.State) (inbox : State) (now : Nat)
    (b : Staking.Bond) : RegistryHistory.Edit → Option (Staking.Bond × Flow)
  | .requestExit caller => (Staking.requestExit b caller now r.exitDelay).map (·,Flow.zero)
  | .confirm => (Staking.confirmExit inbox b now).map (·,Flow.zero)
  | .withdraw caller => (Staking.withdraw inbox b caller now r.withdrawalDelay).map
      (fun (out,amount) => (out,⟨0,amount,0,0⟩))
  | .topUp caller amount => (Staking.topUp inbox b caller amount now r.activationDelay).map
      (fun out => (out,⟨amount,0,0,0⟩))
  | .activateTopUp => (Staking.activateTopUp inbox b now).map (·,Flow.zero)
  | .forfeit key _ validUntil timestamp owner externalOK =>
      (Staking.forfeit inbox b key now timestamp validUntil r.forfeitBps owner
        (decide (key ∉ r.forfeited)) externalOK).map (fun (out,penalty) => (out,⟨0,0,0,penalty⟩))
  | .slash a v sigA sigB =>
      if r.verify b.key a sigA = true ∧ r.verify b.key v sigB = true ∧
          Staking.doubleSign inbox.domain inbox.generation a v = true then
        (Staking.slashDouble inbox b now r.slashBountyBps).map
          (fun (out,bounty,sink) => (out,⟨0,0,bounty,sink⟩))
      else none
  | .forceExit => if b.released = false then some (Staking.exclude b now,Flow.zero) else none
  | .recheck snapshot => some (Staking.rollbackBySnapshot snapshot b,Flow.zero)

def edited (s : RegistryHistory.State) (id now : Nat) (action : RegistryHistory.Edit)
    (b : Staking.Bond) : RegistryHistory.State :=
  RegistryHistory.finish s now { RegistryHistory.writeSlot s id b with
    free := if b.released && !(s.slots id).released then s.free ++ [id] else s.free,
    forfeited := RegistryHistory.forfeitFlags s action }

def editEffect (s : RegistryHistory.State) (inbox : State) (id now : Nat)
    (action : RegistryHistory.Edit) : Option (RegistryHistory.State × Flow) :=
  if id < s.nextId ∧ RegistryHistory.lastBlock s ≤ now ∧ inbox.entered = false then
    (bondEffect s inbox now (s.slots id) action).map (fun (b,f) => (edited s id now action b,f))
  else none

/-- An unsuccessful observed transaction keeps both its state and its zero flow. This
operator applies equally to failed registration, edit, landing, FI, recovery or rollback. -/
def attempt (before : α) (result : Option (α × Flow)) : α × Flow :=
  result.getD (before,Flow.zero)

def registerEffect (s : RegistryHistory.State) (key owner amount now : Nat) :
    Option (RegistryHistory.State × Flow) :=
  (RegistryHistory.register s key owner amount now).map (fun t => (t,⟨amount,0,0,0⟩))

/-- Rejected calls are genuine failures of the original decoded functions. They have
no modeled state effect; L1 time is observed at the next successful transition. -/
inductive Rejected (w : ProtocolState.World) : Prop
  | landing {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (failed : ProtocolState.land w i leaves e = none) : Rejected w
  | registration {key owner amount now : Nat}
      (failed : RegistryHistory.register w.registry key owner amount now = none) : Rejected w
  | modification {id now : Nat} {action : RegistryHistory.Edit}
      (failed : RegistryHistory.edit w.registry w.inbox id now action = none) : Rejected w
  | enqueue {raw paid : Nat} {refund : Bool}
      (failed : Forced.enqueue w.inbox raw paid refund = none) : Rejected w
  | sweep {transfer : Bool} (failed : Forced.sweep w.inbox transfer = none) : Rejected w
  | recovery {a : Recovery.Request} {r : Origin} {owner externalOK : Bool}
      (failed : ProtocolState.recover w a r owner externalOK = none) : Rejected w
  | invalidation {expected now : Nat} {owner : Bool}
      (failed : ProtocolState.invalidateRecoveryNonce w expected now owner = none) : Rejected w
  | rollback {trusted : Checkpoint} {snapshot now : Nat}
      (failed : ProtocolState.rollback w trusted snapshot now = none) : Rejected w

/-- Observer transitions cover every original constructor. No flow is a free input:
modifications read `editEffect` and registration reads its accepted amount. -/
inductive Step : ProtocolState.World → ProtocolState.World → Flow → Prop
  | rejectedCall {w : ProtocolState.World} (failed : Rejected w) : Step w w Flow.zero
  | landing {w : ProtocolState.World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (time : w.l1Block ≤ e.blockNumber) (ok : Etna.Design.land w.inbox i leaves e = some s) :
      Step w (ProtocolState.landed w s e.blockNumber) Flow.zero
  | registration {w : ProtocolState.World} {s : RegistryHistory.State} {key owner amount now : Nat}
      (time : w.l1Block ≤ now) (ok : RegistryHistory.register w.registry key owner amount now = some s) :
      Step w (ProtocolState.registered w s now) ⟨amount,0,0,0⟩
  | modification {w : ProtocolState.World} {s : RegistryHistory.State} {id now : Nat}
      {action : RegistryHistory.Edit} {f : Flow}
      (time : w.l1Block ≤ now) (callable : ProtocolState.publicEdit action = true)
      (ok : editEffect w.registry w.inbox id now action = some (s,f)) :
      Step w (ProtocolState.registered w s now) f
  | enqueue {w : ProtocolState.World} {s : State} {hash timestamp now raw paid : Nat} {refund : Bool}
      (time : w.l1Block ≤ now) (blockRange : now < limit48) (timestampRange : timestamp < limit48)
      (ok : Forced.enqueue w.inbox raw paid refund = some s) :
      Step w (ProtocolState.enqueued w s hash timestamp now) Flow.zero
  | sweep {w : ProtocolState.World} {s : State} {now : Nat} {transfer : Bool}
      (time : w.l1Block ≤ now) (ok : Forced.sweep w.inbox transfer = some s) :
      Step w (ProtocolState.landed w s now) Flow.zero
  | recovery {w : ProtocolState.World} {s : Recovery.World} {a : Recovery.Request} {r : Origin}
      {owner externalOK : Bool} (time : w.l1Block ≤ r.l1Block)
      (ok : Recovery.recover (ProtocolState.recoveryView w) a w.adapters.recovery r owner externalOK = some s) :
      Step w (ProtocolState.recovered w a r s) Flow.zero
  | invalidation {w : ProtocolState.World} {s : State} {expected now : Nat} {owner : Bool}
      (time : w.l1Block ≤ now)
      (ok : Recovery.invalidateRecoveryNonce w.inbox expected owner = some s) :
      Step w (ProtocolState.landed w s now) Flow.zero
  | rollback {w : ProtocolState.World} (trusted : Checkpoint) (snapshot now : Nat)
      (time : w.l1Block ≤ now) (retained : recordAt w.inbox trusted.height = some trusted)
      (authorized : Recovery.NonceMutable w.inbox) :
      Step w (ProtocolState.applyRollback w trusted snapshot now) Flow.zero

inductive Trace : ProtocolState.World → ProtocolState.World → Flow → Prop
  | refl (w : ProtocolState.World) : Trace w w Flow.zero
  | step {first w t : ProtocolState.World} {priorFlow nextFlow : Flow}
      (prior : Trace first w priorFlow) (change : Step w t nextFlow) :
      Trace first t (priorFlow.add nextFlow)

end Etna.Design.Accounting
