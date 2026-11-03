import EtnaProofs.CurrentGovernance
import EtnaProofs.CurrentEncoding
namespace Etna.Design.Current.Protocol.GovernanceReview
open Etna.Design Etna.Design.Current Governance

def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩⟩
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,Committee.minUnit,1⟩
  config := { inbox := 3 }

def h5 : Header := ⟨5,101,15,0,0,1,⟨0,0,0,0,0,0,0⟩⟩
def h10 : Header := ⟨10,102,20,0,0,1,⟨0,0,0,0,0,0,0⟩⟩
def headerCommitment (h : Header) : Hash :=
  Encoding.relabel [Encoding.header genesis,Encoding.header h5,Encoding.header h10]
    Encoding.Tree.code (Encoding.header h)+100

def env : Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := ⟨1,10,1,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := id
  stateRoot := fun _ => 0
  blockHash := fun _ _ => 0
  headerHash := headerCommitment
  committeeHash := fun _ => 0
  configHash := fun _ => 0
  signature := fun _ => False
  txHash := fun _ => 0
  unzenNextProposal := 3
  archiveAuthenticated := fun _ _ _ => false
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => false
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => []
  unzenValid := fun p h _ => decide ((p = 2 ∨ p = 3) ∧ (h = h5 ∨ h = h10))
  unzenParent := fun boundary proposal _ _ => if boundary < proposal then 0 else 102
  unzenRoot := fun h => h = h5 ∨ h = h10
  startImplementation := fun _ => false
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := ⟨4,9,RegistryPayments.standardTransfer 4⟩

def initial := empty env registry
def advanced := Governance.transact env initial (.advance 2)
def initialized := Governance.transact env advanced (.initializeInbox 7)
def checkpoint := initialized.inbox.checkpoint

def validHistory : Governance.DeployedTrace env initial
    (Governance.transact env initialized (.rollback 7 checkpoint 1)) :=
  .call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7)) (.rollback 7 checkpoint 1)

theorem valid_authorization : Governance.AuthorizedUpgrades validHistory := by
  unfold validHistory initialized advanced
  rw [Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_1]
  refine ⟨⟨⟨True.intro,?_⟩,?_⟩,?_⟩
  · intro t _; trivial
  · intro t _; trivial
  · intro t _
    change (checkpoint,1) ∈ initialized.activeSnapshots
    decide +kernel

example : Trace env initial (Governance.transact env initialized (.rollback 7 checkpoint 1)) :=
  Governance.authorized_trace_refines validHistory valid_authorization

example : (Governance.rawRollback env initialized 7 checkpoint 999).isSome = true ∧
    (rollback env initialized 7 checkpoint 999).isNone = true ∧
    ¬ Governance.UpgradeAuthorized initialized (.rollback 7 checkpoint 999) := by
  constructor
  · decide +kernel
  constructor
  · decide +kernel
  · change ¬ (checkpoint,999) ∈ initialized.activeSnapshots
    decide +kernel

def invalidHistory : Governance.DeployedTrace env initial
    (Governance.transact env initialized (.rollback 7 checkpoint 999)) :=
  .call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7)) (.rollback 7 checkpoint 999)

example : ¬ Governance.AuthorizedUpgrades invalidHistory := by
  intro authorization
  unfold invalidHistory initialized advanced at authorization
  rw [Governance.AuthorizedUpgrades.eq_2] at authorization
  have duty := authorization.2
  have ok : Governance.execute env initialized (.rollback 7 checkpoint 999) =
      some ((Governance.rawRollback env initialized 7 checkpoint 999).getD initialized) := by
    rfl
  have impossible := duty _ ok
  exact (show ¬ Governance.UpgradeAuthorized initialized (.rollback 7 checkpoint 999) from by
    change ¬ (checkpoint,999) ∈ initialized.activeSnapshots
    decide +kernel) impossible

def recoveryRequest : RecoveryRequest := ⟨7,0,0,0,100,[],[],0,none⟩
def recovered : World := (recover env initialized recoveryRequest).getD initialized

theorem recovery_accepted : recover env initialized recoveryRequest = some recovered := by rfl

example : recovered.inbox.generation = initialized.inbox.generation+1 ∧
    recovered.inbox.origin = ⟨initialized.inbox.checkpoint.height,initialized.number,env.time initialized.number⟩ ∧
    recovered.inbox.origins = initialized.inbox.origins ++
      [(initialized.inbox.generation+1,⟨initialized.inbox.checkpoint.height,initialized.number,env.time initialized.number⟩)] ∧
    recovered.inbox.checkpoint = initialized.inbox.checkpoint ∧
    recovered.inbox.records = initialized.inbox.records ∧ recovered.inbox.head = initialized.inbox.head :=
  Governance.recover_origin_exact recovery_accepted

end Etna.Design.Current.Protocol.GovernanceReview
