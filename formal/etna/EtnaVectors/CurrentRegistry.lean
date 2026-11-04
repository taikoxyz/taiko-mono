import EtnaModel.CurrentRegistryPayments
import EtnaVectors.Json

/-! Executable current displacement vectors. Historical conformance files are unchanged.
Key numbers denote valid distinct test keys; PoP and token adapters have their stated meanings. -/
namespace Etna.Vectors.CurrentRegistry
open Etna.Design Etna.Design.Current

structure Seed where
  low : Nat := 4095
  lowStake : Nat := 10
  pending : Nat := 0
  second : Option Nat := none
  vacant : Bool := false

def initialBond (seed : Seed) (i : Nat) : Registry.Bond :=
  let selected := i = seed.low ∨ seed.second = some i
  let pending := if i = seed.low then seed.pending else 0
  let value : Staking.Bond :=
    ⟨i+1,7,(if selected then seed.lowStake else 20),1,Staking.noExit,false,none,
      pending,(if pending = 0 then 0 else 2)⟩
  ⟨value,some i⟩

def ledger (seed : Seed) : Registry.State :=
  { nextId := 4096,
    bonds := fun i => if i < 4096 then some (initialBond seed i) else none,
    slots := fun i => if i < 4096 then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ 4096 then some (k-1) else none }

def registry (seed : Seed) : RegistryMachine.State :=
  let raw : RegistryMachine.State :=
    { ledger := ledger seed,config := { inbox := 3,withdrawalDelay := 3 },
      verify := fun _ _ _ => false,registerAuth := fun _ _ _ _ => true }
  { raw with history := [⟨0,RegistryMachine.entries raw⟩] }

def funded (seed : Seed) : RegistryPayments.State :=
  let reserve := (List.range 4096).foldl (fun total i => total+(initialBond seed i).value.balance) 0
  ⟨registry seed,⟨fun a => if a = 4 then reserve else if a = 8 then 100 else 0,
    fun payer recipient => if payer = 8 ∧ recipient = 4 then 100 else 0⟩⟩

def view (snapshot : Nat) : RegistryMachine.InboxView := ⟨⟨1,2,3,4⟩,0,snapshot,true,false,10⟩

def vacancyRequest (seed : Seed) :=
  RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
    (funded seed) (view 0) 1 7 (.requestExit seed.low 7)

def vacancyConfirmation (seed : Seed) :=
  (vacancyRequest seed).bind fun (s,_) =>
    RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
      s (view 2) 2 7 (.confirm seed.low)

def vacancyWithdrawal (seed : Seed) :=
  (vacancyConfirmation seed).bind fun (s,_) =>
    RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
      s (view 2) 5 7 (.withdraw seed.low 7 7)

/-- The vacant-slot fixture uses actual exit, confirmation and paid withdrawal calls.
The regression checks each success, retained lifetime identity, metadata and reserve. -/
def opening (seed : Seed) : RegistryPayments.State :=
  if seed.vacant then ((vacancyWithdrawal seed).map Prod.fst).getD (funded seed)
  else funded seed

def optionNat : Option Nat → JVal
  | none => jNull
  | some n => jNat n

def renderBond (b : Registry.Bond) : JVal := jObj [
  ("key",jNat b.value.key),("owner",jNat b.value.owner),("stake",jNat b.value.stake),
  ("pending",jNat b.value.pendingTopUp),("balance",jNat b.value.balance),
  ("activeFrom",jNat b.value.activeFrom),("exitAt",jNat b.value.exitAt),
  ("released",jBool b.value.released),("confirmedAt",optionNat b.value.confirmedAt),
  ("readyAt",jNat b.value.topUpReadyAtL1),("slot",optionNat b.slot)]

def vector (name : String) (seed : Seed) (amount : Nat) : JVal :=
  let before := opening seed
  let slot := Registry.admissionSlot before.registry.ledger
  let occupant := before.registry.ledger.slots slot
  let snapshot := if seed.vacant then 2 else 0
  let result := RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
    before (view snapshot) 10 8 (.register 9000 8 amount 9000)
  jObj [
    ("id",jStr name),("rules",jRow [jStr "STAKE-4.1-13a",jStr "STAKE-4.1-14a"]),
    ("setup",jObj [("slotCount",jNat 4096),("defaultStake",jNat 20),
      ("lowIndex",jNat seed.low),("lowStake",jNat seed.lowStake),("lowPending",jNat seed.pending),
      ("secondLowIndex",optionNat seed.second),("vacantLow",jBool seed.vacant),
      ("landedSnapshot",jNat snapshot),
      ("vacancyLifecycle",if seed.vacant then jObj [
        ("requestBlock",jNat 1),("exitAt",jNat 2),("confirmBlock",jNat 2),
        ("withdrawBlock",jNat 5),("recipient",jNat 7),
        ("withdrawnBond",match before.registry.ledger.bonds seed.low with
          | none => jNull | some b => renderBond b)] else jNull)]),
    ("call",jObj [("fn",jStr "register"),("block",jNat 10),("caller",jNat 8),
      ("key",jNat 9000),("amount",jNat amount)]),
    ("expect",match result with
      | none => jObj [("revert",jBool true),("stateUnchanged",jBool true)]
      | some (after,receipts) => jObj [
        ("revert",jBool false),("selectedSlot",jNat slot),("bondId",jNat before.registry.ledger.nextId),
        ("oldBondId",optionNat occupant),
        ("oldBond",match occupant.bind after.registry.ledger.bonds with | none => jNull | some b => renderBond b),
        ("newBond",match after.registry.ledger.bonds before.registry.ledger.nextId with | none => jNull | some b => renderBond b),
        ("nextId",jNat after.registry.ledger.nextId),
        ("slot4096",optionNat (after.registry.ledger.slots 4096)),
        ("callerBalance",jNat (after.token.balances 8)),("registryBalance",jNat (after.token.balances 4)),
        ("receiptCount",jNat receipts.length),
        ("latestCheckpointBlock",optionNat (after.registry.history.head?.map RegistryHistory.Snapshot.block))])]

def file : String :=
  jObj [
    ("schema",jStr "etna-current-registry-admission-1"),
    ("authorityCommit",jStr "1135c9b24fd03f50cb48eab250879435fd54f528"),
    ("model",jStr "Etna.Design.Current.RegistryPayments.executeTransaction"),
    ("keyMeaning",jStr "Distinct valid test keys with valid PoP; numbers are fixture identities, not raw public-key bytes."),
    ("vectors",jArr [
      vector "last-slot-minimum-displacement" {} 11,
      vector "strict-equal-minimum-rejected" {} 10,
      vector "below-minimum-rejected" {} 9,
      vector "nonzero-tied-minimum-lowest-index" {low := 17,second := some 4095} 11,
      vector "pending-principal-changes-minimum" {low := 17,pending := 1,second := some 4095} 11,
      vector "all-positive-tie-slot-zero" {lowStake := 20} 21,
      vector "empty-last-slot" {vacant := true} 1,
      vector "displaced-pending-principal-retained" {lowStake := 7,pending := 3} 11])
  ] 0 ++ "\n"

end Etna.Vectors.CurrentRegistry
