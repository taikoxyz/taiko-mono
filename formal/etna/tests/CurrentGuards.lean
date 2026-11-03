import EtnaModel.CurrentProtocol

namespace Etna.CurrentGuardRegression
open Etna.Design Etna.Design.Current Protocol

/-! Executable guard regressions, separate from the joint-premise witnesses. These
finite adapters intentionally accept every proof; they test the deployed action and
normative upgrade guards, not global verifier soundness. The individually corrupted
Unzen records below test the fence formula and do not assert reachability. -/
def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,10,0,0,1,⟨0,1,0,0,100,0,0⟩⟩
def legacy : Header := ⟨1,101,11,201,0,1,⟨0,1,0,0,100,0,0⟩⟩
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
  archiveAuthenticated := fun _ _ _ => true
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
def landing : Landing := ⟨⟨1,2,102,202,22,2,0,0⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def firstLanded := transact env source (.land landing)
def restored := transact env firstLanded (.rollback 7 source.inbox.checkpoint 0)

example : initialized.initialized = true ∧ source.start = some ⟨1,101,11⟩ ∧
    firstFence env source = true ∧ (land env source landing).isSome = true ∧
    firstLanded.inbox.checkpoint.height = 2 := by decide +kernel

-- Repeating the origin write must be rejected even before a first landing.
example : (setOrigin env source 8 1 101 11).isNone = true := by decide +kernel

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
example : firstFence env { source with unzen := { source.unzen with checkpointHash := 0 } } = false := by
  decide +kernel
example : firstFence env { source with unzen := { source.unzen with checkpointRoot := 0 } } = false := by
  decide +kernel

end Etna.CurrentGuardRegression
