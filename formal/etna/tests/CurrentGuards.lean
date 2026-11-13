import EtnaModel.CurrentProtocol

namespace Etna.CurrentGuardRegression
open Etna.Design Etna.Design.Current Protocol

/-! Executable guard regressions, separate from the joint-premise witnesses. These
finite adapters intentionally accept every proof; they test the deployed action and
normative upgrade guards, not global verifier soundness. The individually corrupted
Unzen records below test the fence formula and do not assert reachability. -/
def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,10,0,0,1,⟨0,1,0,0,100,0,0⟩,0⟩
def legacy : Header := ⟨1,101,11,201,0,1,⟨0,1,0,0,100,0,0⟩,0⟩
def registry : RegistryMachine.State :=
  { ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,1,1⟩,config := { inbox := 3 } }
def env : Environment where
  core := ⟨domain,7,8,99,2,9⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := ⟨domain,0,0,[],false,[]⟩
  time := id
  stateRoot := Snapshot.number
  blockHash := fun _ n => 1000+n
  headerHash := BlockValidity.Header.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun _ => True
  txHash := fun _ => 0
  unzenNextProposal := 2
  timestampOf := fun _ => 1
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => true
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => true
  unzenRoot := fun _ => True
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := ⟨4,9,RegistryPayments.standardTransfer 4⟩

def initial := empty env registry
def advanced := transact env initial (.advance 2)
def initialized := transact env advanced (.initializeInbox 7)
def proven := transact env initialized (.unzenProve 1 legacy 77)
def started := transact env proven (.setOrigin 8 1 101 11)
def imaged := transact env started (.image 7 11 true)
def source := transact env imaged (.advance 3)
def landing : Landing := ⟨⟨1,2,102,202,33,22,2,0,0⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def firstLanded := transact env source (.land landing)
def restored := transact env firstLanded (.rollback 7 source.inbox.checkpoint 0)

example : initialized.initialized = true ∧ source.start = some ⟨1,101,11⟩ ∧
    firstFence env source = true ∧ (land env source landing).isSome = true ∧
    firstLanded.inbox.checkpoint.height = 2 := by decide +kernel

-- The start record holds validator-state hash 0 (STOR-B-9); a landing writes its
-- lastValStateHash into the new slot 285 record (6.1 step 7, #22338).
example : (recordAt source.inbox 1).map Checkpoint.valStateHash = some 0 ∧
    (recordAt firstLanded.inbox 2).map Checkpoint.valStateHash = some 33 := by decide +kernel

-- Repeating the origin write must be rejected even before a first landing.
example : (setOrigin env source 8 1 101 11).isNone = true := by decide +kernel

-- START-10-5a: the origin write waits for the fork time. At L1 block 1 (time 1, before
-- forkTime 2) it is refused; the same initialized world one block later accepts it.
def early := transact env (transact env initial (.advance 1)) (.initializeInbox 7)
example : early.initialized = true ∧ (setOrigin env early 8 1 101 11).isNone = true ∧
    (setOrigin env (transact env early (.advance 2)) 8 1 101 11).isSome = true := by decide +kernel

-- START-10-5c: a start correction before any landing opens generation 1 and appends its
-- origin after generation 0's.
example : ((correctStart env source 7 1 102 12).map fun w =>
    (w.inbox.generation,w.inbox.origins.map Prod.fst)) = some (1,[0,1]) := by decide +kernel

-- Rollback removes newer signals but must not reopen the pre-landing correction gate.
example : restored.inbox.checkpoint.height = 1 ∧ restored.inbox.signals = [] ∧
    restored.everLanded = true := by decide +kernel
example : (correctStart env restored 7 1 101 11).isNone = true := by decide +kernel

-- The trusted checkpoint and selection snapshot must be a saved pair.
example : (rollback env firstLanded 7 source.inbox.checkpoint 999).isNone = true := by
  decide +kernel

example : firstFence env { source with unzen := { source.unzen with nextProposal := 3 } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with finalizedHash := 0 } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with checkpointExists := false } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with checkpointHeight := 0 } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with checkpointHash := 0 } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with checkpointRoot := 0 } } = false := by
  decide +kernel

-- LAND-6.1-8a reads the SignalService checkpoint at S. A start S = 5 written with the hash and
-- stateRoot of the Unzen block at height 10 is refused. Every other landing check passes: the
-- same world with the checkpoint's height set to 5 lands, as this world did before the model
-- recorded that height.
def legacy10 : Header := { legacy with height := 10 }
def proven10 := transact env initialized (.unzenProve 1 legacy10 77)
def shiftedStarted := transact env proven10 (.setOrigin 8 5 101 11)
def shiftedImaged := transact env shiftedStarted (.image 7 11 true)
def shiftedSource := transact env shiftedImaged (.advance 3)
def shiftedLanding : Landing := ⟨⟨5,6,102,202,33,22,2,0,0⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩

example : shiftedSource.start = some ⟨5,101,11⟩ ∧ shiftedSource.unzen.checkpointHeight = 10 ∧
    shiftedSource.unzen.checkpointHash = 101 ∧ shiftedSource.unzen.checkpointRoot = 11 ∧
    firstFence env shiftedSource = false ∧ (land env shiftedSource shiftedLanding).isNone = true := by
  decide +kernel
example : (land env { shiftedSource with unzen := { shiftedSource.unzen with checkpointHeight := 5 } }
    shiftedLanding).isSome = true := by
  decide +kernel

end Etna.CurrentGuardRegression
