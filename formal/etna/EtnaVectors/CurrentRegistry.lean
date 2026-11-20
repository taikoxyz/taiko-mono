import EtnaModel.CurrentRegistryPayments
import EtnaVectors.Json

/-! Executable current admission vectors (`testdata/etna_current_conformance`).
Key numbers denote valid distinct test keys; PoP, vote signatures and token adapters have their
stated meanings. -/
namespace Etna.Vectors.CurrentRegistry
open Etna.Design Etna.Design.Current

/-- Every token amount is a multiple of 25,000 TAIKO (`25000 × 10^18` base units), so
minStake is 250,000 TAIKO and 4096 × minStake > 10^27, the deployment bound of
STAKE-4.1-14a and PARAM-11-11; the one exception is the below-minimum amount minStake − 1. -/
def tokenUnit : Nat := 25000 * 10^18

def minStake : Nat := 10*tokenUnit

/-- Opening bonds 0 to `bonds - 1` hold the slots with the same numbers. Bond `low` has
`lowStake` and `pending`; it is withdrawn when `vacant`, or slashed to zero when `slashed`. -/
structure Seed where
  bonds : Nat := 4096
  low : Nat := 4095
  lowStake : Nat := minStake
  pending : Nat := 0
  vacant : Bool := false
  slashed : Bool := false

def defaultStake : Nat := 20*tokenUnit

/-- Caller 8's balance and its allowance to the registry. -/
def callerFunds : Nat := 100*tokenUnit

def initialBond (seed : Seed) (i : Nat) : Registry.Bond :=
  let pending := if i = seed.low then seed.pending else 0
  let value : Staking.Bond :=
    ⟨i+1,7,(if i = seed.low then seed.lowStake else defaultStake),1,Staking.noExit,false,none,
      pending,(if pending = 0 then 0 else 2)⟩
  ⟨value,some i⟩

def ledger (seed : Seed) : Registry.State :=
  { nextId := seed.bonds,
    bonds := fun i => if i < seed.bonds then some (initialBond seed i) else none,
    slots := fun i => if i < seed.bonds then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ seed.bonds then some (k-1) else none,
    minStake := minStake }

def registry (seed : Seed) : RegistryMachine.State :=
  let raw : RegistryMachine.State :=
    { ledger := ledger seed,config := { inbox := 3,withdrawalDelay := 3 },
      verify := fun _ _ _ => true,registerAuth := fun _ _ _ _ => true }
  { raw with history := [⟨0,RegistryMachine.entries raw⟩] }

def funded (seed : Seed) : RegistryPayments.State :=
  let reserve := (List.range seed.bonds).foldl (fun total i => total+(initialBond seed i).value.balance) 0
  ⟨registry seed,⟨fun a => if a = 4 then reserve else if a = 8 then callerFunds else 0,
    fun payer recipient => if payer = 8 ∧ recipient = 4 then callerFunds else 0⟩⟩

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

/-- Two precommits by one key for different blocks at one height and round, in the
deployment's own domain and generation. -/
def slashVote (blockId : Nat) : Staking.Vote := ⟨⟨1,2,3,4⟩,0,5,0,2,blockId⟩

/-- Reporter 6 slashes bond `low` at block 1. -/
def slashing (seed : Seed) :=
  RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
    (funded seed) (view 0) 1 6 (.slash seed.low (slashVote 1) (slashVote 2) (seed.low+1) (seed.low+1))

/-- The vacant-slot and slashed fixtures use actual exit, confirmation, paid withdrawal and
slashing calls. The regression checks each success, retained lifetime identity, metadata and
reserve. -/
def opening (seed : Seed) : RegistryPayments.State :=
  if seed.vacant then ((vacancyWithdrawal seed).map Prod.fst).getD (funded seed)
  else if seed.slashed then ((slashing seed).map Prod.fst).getD (funded seed)
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

def renderVote (v : Staking.Vote) : JVal := jObj [
  ("generation",jNat v.generation),("height",jNat v.height),("round",jNat v.round),
  ("kind",jNat v.kind),("blockId",jNat v.blockId)]

def lowBond (before : RegistryPayments.State) (seed : Seed) : JVal :=
  match before.registry.ledger.bonds seed.low with
  | none => jNull
  | some b => renderBond b

def vector (name : String) (seed : Seed) (amount : Nat) : JVal :=
  let before := opening seed
  let id := before.registry.ledger.nextId
  let snapshot := if seed.vacant then 2 else 0
  let result := RegistryPayments.executeTransaction (RegistryPayments.standardEnvironment 4 5)
    before (view snapshot) 10 8 (.register 9000 8 amount 9000)
  jObj [
    ("id",jStr name),("rules",jRow [jStr "STAKE-4.1-13a",jStr "STAKE-4.1-14a"]),
    ("setup",jObj [("slotCount",jNat 4096),("openingBonds",jNat seed.bonds),
      ("minStake",jNat minStake),("defaultStake",jNat defaultStake),
      ("lowIndex",jNat seed.low),("lowStake",jNat seed.lowStake),("lowPending",jNat seed.pending),
      ("secondLowIndex",jNull),("vacantLow",jBool seed.vacant),("slashedLow",jBool seed.slashed),
      ("landedSnapshot",jNat snapshot),
      ("vacancyLifecycle",if seed.vacant then jObj [
        ("requestBlock",jNat 1),("exitAt",jNat 2),("confirmBlock",jNat 2),
        ("withdrawBlock",jNat 5),("recipient",jNat 7),
        ("withdrawnBond",lowBond before seed)] else jNull),
      ("slashLifecycle",if seed.slashed then jObj [
        ("block",jNat 1),("reporter",jNat 6),("voteA",renderVote (slashVote 1)),
        ("voteB",renderVote (slashVote 2)),("slashedBond",lowBond before seed)] else jNull)]),
    ("call",jObj [("fn",jStr "register"),("block",jNat 10),("caller",jNat 8),
      ("key",jNat 9000),("amount",jNat amount)]),
    ("expect",match result with
      | none => jObj [("revert",jBool true),("stateUnchanged",jBool true)]
      | some (after,receipts) =>
        let slot := (after.registry.ledger.bonds id).bind Registry.Bond.slot
        let occupant := slot.bind before.registry.ledger.slots
        jObj [
        ("revert",jBool false),("selectedSlot",optionNat slot),("bondId",jNat id),
        ("oldBondId",optionNat occupant),
        ("oldBond",match occupant.bind after.registry.ledger.bonds with | none => jNull | some b => renderBond b),
        ("newBond",match after.registry.ledger.bonds id with | none => jNull | some b => renderBond b),
        ("nextId",jNat after.registry.ledger.nextId),
        ("slot4096",optionNat (after.registry.ledger.slots 4096)),
        ("callerBalance",jNat (after.token.balances 8)),("registryBalance",jNat (after.token.balances 4)),
        ("receiptCount",jNat receipts.length),
        ("latestCheckpointBlock",optionNat (after.registry.history.head?.map RegistryHistory.Snapshot.block))])]

def file : String :=
  jObj [
    ("schema",jStr "etna-current-registry-admission-1"),
    ("authorityCommit",jStr "3fe7350119f2efe38cf588c145a9913bf9b3b398"),
    ("model",jStr "Etna.Design.Current.RegistryPayments.executeTransaction"),
    ("keyMeaning",jStr "Distinct valid test keys with valid PoP and valid vote signatures; numbers are fixture identities, not raw public-key bytes."),
    ("vectors",jArr [
      vector "empty-last-slot" {vacant := true} minStake,
      vector "lowest-empty-slot" {bonds := 4,low := 1,vacant := true} minStake,
      vector "full-registry-rejected" {} (21*tokenUnit),
      vector "zero-balance-bond-not-replaced" {low := 17,slashed := true} (21*tokenUnit),
      vector "withdrawn-slot-reused" {low := 17,vacant := true} minStake,
      vector "pending-topup-irrelevant" {bonds := 4,low := 1,pending := 3*tokenUnit} minStake,
      vector "below-minimum-rejected" {bonds := 4,low := 1} (minStake-1)])
  ] 0 ++ "\n"

end Etna.Vectors.CurrentRegistry
