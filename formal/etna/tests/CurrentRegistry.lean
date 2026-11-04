import EtnaProofs.CurrentRegistry

-- The raw STAKE-4.1-26 fence, with no caller-supplied live/unconfirmed premise:
-- a selected bond cannot begin its evidence clock before the landed snapshot
-- reaches its effective exit.
example (s : Etna.Design.Current.RegistryMachine.State)
    (v : Etna.Design.Current.RegistryMachine.InboxView) (now cutoff id : Nat)
    (bond : Etna.Design.Current.Registry.Bond)
    (found : s.ledger.bonds id = some bond)
    (selected : cutoff < bond.value.exitAt) (settlement : v.snapshot ≤ cutoff) :
    Etna.Design.Current.RegistryMachine.execute s v now (.confirm id) = none :=
  Etna.Design.Current.RegistryMachine.confirm_blocked_above_snapshot found selected settlement

open Etna.Design Etna.Design.Current
namespace CurrentRegistryTests
open RegistryMachine
example (s : RegistryMachine.State) (v : InboxView) (now id : Nat) (b : Registry.Bond)
    (issued : id < s.ledger.nextId) (found : s.ledger.bonds id = some b)
    (initialized : v.initialized = true) (free : v.entered = false)
    (live : b.value.released = false) (positive : 0 < b.value.balance)
    (rate : s.config.slashBountyBps < 10000)
    (a z : Staking.Vote) (sa sz : Hash)
    (auth : Evidence s v b.value.key a z sa sz) :
    ∃ t, execute s v now (.slash id a z sa sz) = some t := by
  exact slash_enabled issued found initialized free live positive rate auth
end CurrentRegistryTests

namespace CurrentRegistryTests
open Etna.Design Etna.Design.Current RegistryMachine
set_option maxRecDepth 30000
set_option maxHeartbeats 8000000

def domain : Domain := ⟨1,2,3,4⟩
def view : InboxView := ⟨domain,7,100,true,false,100⟩
def voteA : Staking.Vote := ⟨domain,1,20,2,2,11⟩
def voteB : Staking.Vote := ⟨domain,1,20,2,2,12⟩
def bond (key stake : Nat) (slot : Option Nat) : Registry.Bond :=
  ⟨⟨key,4,stake,1,Staking.noExit,false,none,0,0⟩,slot⟩
def populated : Registry.State :=
  { nextId := 4096, bonds := fun i => if i < 4096 then some (bond (i+1) 10 (some i)) else none, slots := fun i => if i < 4096 then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ 4096 then some (k-1) else none }
def initial : RegistryMachine.State :=
  { ledger := populated,config := {withdrawalDelay := 2},
    verify := fun key _ sig => key == sig,registerAuth := fun _ _ _ _ => true }
def registered : RegistryMachine.State := (execute initial view 10 (.register 9000 8 11 9000)).getD initial
-- Small explicit post-displacement fixture; independent of subsequent slash semantics.
def displaced : RegistryMachine.State :=
  { initial with ledger := { nextId := 2, bonds := fun i => if i = 0 then some ⟨{(bond 1 10 none).value with exitAt := 10},none⟩
        else if i = 1 then some (bond 9000 11 (some 0)) else none, slots := fun i => if i = 0 then some 1 else none, keyId := fun k => if k = 1 then some 0 else if k = 9000 then some 1 else none } }

def keyAt (s : RegistryMachine.State) (id : Nat) : Option Hash := (s.ledger.bonds id).map (fun b => b.value.key)
def stakeAt (s : RegistryMachine.State) (id : Nat) : Option Nat := (s.ledger.bonds id).map (fun b => b.value.stake)
def resultStake (r : Option RegistryMachine.State) (id : Nat) : Option Nat := r.bind (fun s => stakeAt s id)

-- Real admission displaces bond zero but retains its permanent liability.
example : ((registered.ledger.bonds 0).map (fun b => b.slot)) = some none := by decide
example : keyAt displaced 0 = some 1 := by decide
example : resultStake (execute displaced view 11 (.slash 0 voteA voteB 1 1)) 0 = some 0 := by decide
-- The old-generation evidence remains admissible; a foreign deployment does not.
example : resultStake (execute displaced view 11 (.slash 0 {voteA with generation := 8} voteB 1 1)) 0 = none := by decide
example : resultStake (execute displaced view 11 (.slash 0 {voteA with domain := ⟨9,2,3,4⟩} voteB 1 1)) 0 = none := by decide
example : resultStake (execute displaced view 11 (.slash 0 voteA voteB 999 1)) 0 = none := by decide

def forfeited : RegistryMachine.State := (execute displaced view 11 (.forfeit 0 1 1 99 100)).getD displaced
example : stakeAt forfeited 0 = some 9 := by decide
example : resultStake (execute forfeited view 12 (.slash 0 voteA voteB 1 1)) 0 = some 0 := by decide
example : (execute forfeited view 12 (.forfeit 0 1 1 100 100)).isNone = true := by decide

def slashed : RegistryMachine.State := (execute forfeited view 12 (.slash 0 voteA voteB 1 1)).getD forfeited
example : (execute slashed view 13 (.slash 0 voteA voteB 1 1)).isNone = true := by decide

def confirmed : RegistryMachine.State := (execute displaced view 12 (.confirm 0)).getD displaced
def withdrawn : RegistryMachine.State := (execute confirmed view 14 (.withdraw 0 4 8)).getD confirmed
example : (execute confirmed view 13 (.withdraw 0 4 8)).isNone = true := by decide
example : ((execute confirmed view 13 (.confirm 0)).bind fun s =>
    (s.ledger.bonds 0).map (fun b => b.value.confirmedAt)) = some (some 12) := by decide
example : withdrawn.ledger.slots 0 = some 1 := by decide
example : keyAt withdrawn 1 = some 9000 := by decide
example : keyAt withdrawn 0 = some 1 := by decide
example : withdrawn.ledger.keyId 1 = some 0 := by decide
example : (execute withdrawn view 15 (.register 1 4 20 1)).isNone = true := by decide
example : (execute withdrawn view 15 (.exclude 2 5 [(0,1)])).isSome = true := by decide
example : (execute withdrawn view 15 (.exclude 2 5 [(6000,0)])).isNone = true := by decide
-- Atomic list validation: the valid first identity is not changed if a later one is absent.
example : (execute withdrawn view 15 (.exclude 2 5 [(0,1),(6000,0)])).isNone = true := by decide
-- Actual initialization, not an archival origin, gates evidence and confirmation.
example : (execute displaced {view with initialized := false} 12 (.slash 0 voteA voteB 1 1)).isNone = true := by decide
example : (execute displaced {view with initialized := false} 12 (.confirm 0)).isNone = true := by decide
-- Trusted rollback rechecks against the restored snapshot, not confirmation block time.
example : ((execute confirmed view 13 (.recheck 2 5)).bind fun s =>
    (s.ledger.bonds 0).map (fun b => b.value.confirmedAt)) = some none := by decide
example : ((execute confirmed view 13 (.recheck 2 10)).bind fun s =>
    (s.ledger.bonds 0).map (fun b => b.value.confirmedAt)) = some (some 12) := by decide
def rechecked := (execute confirmed view 13 (.recheck 2 5)).getD confirmed
def reconfirmed := (execute rechecked view 14 (.confirm 0)).getD rechecked
example : (execute rechecked view 14 (.withdraw 0 4 8)).isNone = true := by decide
example : (execute reconfirmed view 15 (.withdraw 0 4 8)).isNone = true := by decide
example : (execute reconfirmed view 16 (.withdraw 0 4 8)).isSome = true := by decide
end CurrentRegistryTests

namespace CurrentRegistryTests
open Etna.Design Etna.Design.Current RegistryMachine
set_option maxRecDepth 30000
set_option maxHeartbeats 8000000

def phantom : RegistryMachine.State :=
  { initial with ledger := { nextId := 0, bonds := fun _ => some (bond 0 0 none), slots := fun _ => none, keyId := fun _ => none } }
example : (execute phantom view 20 (.exclude 2 5 [(0,0)])).isNone = true := by decide

def active : RegistryMachine.State :=
  { initial with ledger := { nextId := 1, bonds := fun i => if i = 0 then some (bond 1 10 (some 0)) else none, slots := fun i => if i = 0 then some 0 else none, keyId := fun k => if k = 1 then some 0 else none } }
def topped : RegistryMachine.State :=
  (execute active {view with initialized := false} 10 (.topUp 0 4 5)).getD active
example : stakeAt topped 0 = some 10 := by decide
example : resultStake (execute topped {view with initialized := false} 11 (.activateTopUp 0)) 0 = some 15 := by decide
example : (execute topped view 10 (.activateTopUp 0)).isNone = true := by decide
example : (execute displaced view 12 (.topUp 0 4 5)).isNone = true := by decide
example : (execute active {view with entered := true} 12 (.requestExit 0 4)).isNone = true := by decide
-- Metadata-only confirmations must not add an election checkpoint.
example : confirmed.history = displaced.history := by decide
-- Generic checkpoint replacement holds with slot-projected current entries as payloads.
example : RegistryHistory.recordSnapshot 10 (entries active)
    [⟨10,entries displaced⟩,⟨9,[]⟩] = [⟨10,entries active⟩,⟨9,[]⟩] := rfl
end CurrentRegistryTests
