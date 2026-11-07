import EtnaProofs.CurrentRegistryPayments

namespace Etna.Design.Current.RegistryPayments.Tests
-- A rejected token transfer must roll back the principal edit and lifetime flag together.
example (env : PaymentEnvironment) (s : State) (v : RegistryMachine.InboxView)
    (now caller : Nat) (action : RegistryMachine.Action)
    (failed : executeTransaction env s v now caller action = none) :
    transact env s v now caller action = s := by
  exact failure_atomic failed
end Etna.Design.Current.RegistryPayments.Tests

namespace Etna.Design.Current.RegistryPayments.Tests
set_option maxRecDepth 20000
set_option maxHeartbeats 2000000

def view : RegistryMachine.InboxView := ⟨⟨1,2,3,4⟩,7,100,true,false,100⟩
def voteA : Staking.Vote := ⟨view.domain,1,20,2,2,11⟩
def voteB : Staking.Vote := ⟨view.domain,1,20,2,2,12⟩
def oldBond : Registry.Bond := ⟨⟨1,4,10,1,5,false,some 1,0,0⟩,none⟩
def replacement : Registry.Bond := ⟨⟨2,4,20,1,Staking.noExit,false,none,0,0⟩,some 0⟩
def registry : RegistryMachine.State :=
  { ledger := { nextId := 2, bonds := fun i => if i = 0 then some oldBond else if i = 1 then some replacement else none, slots := fun i => if i = 0 then some 1 else none, keyId := fun key => if key = 1 then some 0 else if key = 2 then some 1 else none },
    config := {withdrawalDelay := 2}, verify := fun key _ sig => key == sig,
    registerAuth := fun _ _ _ _ => true }
def token : TokenState :=
  { balances := fun a => if a = 100 then 30 else if a = 4 then 40 else 0,
    allowances := fun owner spender => if owner = 4 ∧ spender = 100 then 40 else 0 }
def initial : State := ⟨registry,token⟩
def env : PaymentEnvironment := standardEnvironment 100 200
def sinkRejects : PaymentEnvironment :=
  { env with transfer := fun s p => if p.recipient = 200 then none else standardTransfer 100 s p }
def forfeiture : RegistryMachine.Action := .forfeit 0 1 1 99 100

-- Real inner principal edit succeeds, deducting ceil(10*1000/10000)=1.
example : ((RegistryMachine.execute registry view 10 forfeiture).bind fun s =>
    (s.ledger.bonds 0).map (fun b => b.value.stake)) = some 9 := by decide
example : (executeTransaction sinkRejects initial view 10 1 forfeiture).isNone = true := by decide
example : transact sinkRejects initial view 10 1 forfeiture = initial := by
  apply failure_atomic
  rfl
example : (transact sinkRejects initial view 10 1 forfeiture).registry.forfeited = [] := by decide
example : ((transact sinkRejects initial view 10 1 forfeiture).registry.ledger.bonds 0).map
    (fun b => b.value.stake) = some 10 := by decide
-- Successful responsibility forfeiture sends only the fixed penalty to the sink.
example : (executeTransaction env initial view 10 1 forfeiture).map Prod.snd =
    some [⟨100,200,1,false⟩] := by decide
example : (transact env initial view 10 1 forfeiture).registry.forfeited = [1] := by decide

-- Displacement changes slot ownership, never withdrawal destination or principal ownership.
example : (executeTransaction env initial view 10 4 (.withdraw 0 4 9)).map Prod.snd =
    some [⟨100,9,10,false⟩] := by decide
example : (transact env initial view 10 4 (.withdraw 0 4 9)).token.balances 9 = 10 := by decide
example : (transact env initial view 10 4 (.withdraw 0 4 9)).registry.ledger.slots 0 = some 1 := by decide
example : (executeTransaction env initial view 10 9 (.withdraw 0 4 9)).isNone = true := by decide
example : (executeTransaction env initial view 10 9 forfeiture).isNone = true := by decide

-- Slash bounty goes to the authenticated outer caller and remainder to the fixed sink.
def slash : RegistryMachine.Action := .slash 0 voteA voteB 1 1
example : (executeTransaction env initial view 10 8 slash).map Prod.snd =
    some [⟨100,8,1,false⟩,⟨100,200,9,false⟩] := by decide
example : (transact env initial view 10 8 slash).token.balances 8 = 1 := by decide
example : (transact env initial view 10 8 slash).token.balances 200 = 9 := by decide
-- Rejecting the second transfer also reverses the first bounty and the principal edit.
example : transact sinkRejects initial view 10 8 slash = initial := by
  apply failure_atomic
  rfl
example : (transact sinkRejects initial view 10 8 slash).token.balances 8 = 0 := by decide

-- Incoming deposits debit the authenticated caller and require token approval.
example : (executeTransaction env initial view 10 4 (.register 3 4 30 3)).map Prod.snd =
    some [⟨4,100,30,true⟩] := by decide
example : (transact env initial view 10 4 (.register 3 4 30 3)).token.balances 4 = 10 := by decide
example : (executeTransaction env initial view 10 4 (.topUp 1 4 5)).map Prod.snd =
    some [⟨4,100,5,true⟩] := by decide
example : (executeTransaction env {initial with token := {token with allowances := fun _ _ => 0}}
    view 10 4 (.topUp 1 4 5)).isNone = true := by decide
example : (executeTransaction env initial view 10 9 (.register 3 4 30 3)).isNone = true := by decide

-- minStake zero is a permitted deployment: strict slot admission still requires a
-- positive deposit, which must transfer the actual approved tokens atomically.
def zeroMinimum : State := {initial with registry := {registry with ledger := {registry.ledger with minStake := 0}}}
example : (executeTransaction env zeroMinimum view 10 4 (.register 3 4 1 3)).map Prod.snd =
    some [⟨4,100,1,true⟩] := by decide
example : (transact env zeroMinimum view 10 4 (.register 3 4 1 3)).token.balances 4 = 39 := by decide
example : (transact env zeroMinimum view 10 4 (.register 3 4 1 3)).token.balances 100 = 31 := by decide
example : ((transact env zeroMinimum view 10 4 (.register 3 4 1 3)).registry.ledger.bonds 2).map
    (fun b => b.value.balance) = some 1 := by decide
example : (executeTransaction env zeroMinimum view 10 4 (.register 3 4 0 3)).isNone = true := by decide
-- #22335: self-reporting uses the same floor bounty and retains a positive sink share.
def slashFixture (balance rate : Nat) : State :=
  let bond : Registry.Bond := ⟨{ oldBond.value with stake := balance },none⟩
  let ledger := { registry.ledger with bonds := fun i => if i = 0 then some bond else none }
  let machine := { registry with config := { registry.config with slashBountyBps := rate }, ledger := ledger }
  let funded := { token with balances := fun a => if a = 100 then balance else 0 }
  ⟨machine,funded⟩
example : (executeTransaction env (slashFixture 1001 1000) view 10 4 slash).map Prod.snd =
    some [⟨100,4,100,false⟩,⟨100,200,901,false⟩] := by decide
example : (executeTransaction env (slashFixture 1 9999) view 10 4 slash).map Prod.snd =
    some [⟨100,4,0,false⟩,⟨100,200,1,false⟩] := by decide
example : (executeTransaction env (slashFixture 10 0) view 10 4 slash).map Prod.snd =
    some [⟨100,4,0,false⟩,⟨100,200,10,false⟩] := by decide
example : (executeTransaction env (slashFixture 10 10000) view 10 4 slash).isNone = true := by decide
end Etna.Design.Current.RegistryPayments.Tests
