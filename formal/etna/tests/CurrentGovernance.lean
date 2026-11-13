import EtnaProofs.CurrentGovernance
import EtnaProofs.CurrentEncoding
namespace Etna.Design.Current.Protocol.GovernanceReview
open Etna.Design Etna.Design.Current Governance

def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,Committee.minUnit,1⟩
  config := { inbox := 3 }

def h5 : Header := ⟨5,101,15,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def h10 : Header := ⟨10,102,20,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
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

-- The rollback duty (RECOV-8-24 to 8-28): trusted and every record below it are trusted, and
-- the first retained record above it is bad.
example (initial w : World) (trusted : Checkpoint) (snapshot : Nat) :
    Governance.RollbackAuthorized env initial w trusted snapshot =
      (trusted ∈ w.activeRecords ∧ (trusted,snapshot) ∈ w.activeSnapshots ∧
        (∀ r ∈ w.activeRecords, r.height ≤ trusted.height →
          Custody.Certified env initial r ∨ Custody.Pending env w r) ∧
        ∃ bad ∈ w.activeRecords, trusted.height < bad.height ∧
          ¬ Custody.Certified env initial bad ∧ ¬ Custody.Pending env w bad ∧
          ∀ r ∈ w.activeRecords, r.height < bad.height → r.height ≤ trusted.height) := rfl

example (initial w : World) (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    Governance.UpgradeAuthorized env initial w (.rollback caller trusted snapshot) =
      Governance.RollbackAuthorized env initial w trusted snapshot := rfl

-- Restoring the retained start record with its own snapshot meets the two physical duties,
-- and the raw owner action succeeds, but nothing above it is bad: no verifier failure
-- happened, so the rollback is not authorized.
def unfailedHistory : Governance.DeployedTrace env initial
    (Governance.transact env initialized (.rollback 7 checkpoint 1)) :=
  .call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7)) (.rollback 7 checkpoint 1)

theorem no_bad_record_not_authorized :
    checkpoint ∈ initialized.activeRecords ∧ (checkpoint,1) ∈ initialized.activeSnapshots ∧
    (Governance.rawRollback env initialized 7 checkpoint 1).isSome = true ∧
    ¬ Governance.UpgradeAuthorized env initial initialized (.rollback 7 checkpoint 1) := by
  refine ⟨by decide +kernel,by decide +kernel,by decide +kernel,fun authorized => ?_⟩
  change Governance.RollbackAuthorized env initial initialized checkpoint 1 at authorized
  obtain ⟨_,_,_,bad,retained,above,_⟩ := authorized
  have below : ∀ r ∈ initialized.activeRecords, r.height ≤ checkpoint.height := by decide +kernel
  exact absurd (below bad retained) (Nat.not_le.mpr above)

theorem unfailed_history_not_authorized : ¬ Governance.AuthorizedUpgrades unfailedHistory := by
  intro authorization
  unfold unfailedHistory initialized advanced at authorization
  rw [Governance.AuthorizedUpgrades.eq_2] at authorization
  have ok : Governance.execute env initialized (.rollback 7 checkpoint 1) =
      some ((Governance.rawRollback env initialized 7 checkpoint 1).getD initialized) := by
    rfl
  exact no_bad_record_not_authorized.2.2.2 (authorization.2 _ ok)

theorem authorized_raw_rollback_bridge :
    rollback env initialized 7 checkpoint 1 =
      Governance.rawRollback env initialized 7 checkpoint 1 := by
  have authorized : checkpoint ∈ initialized.activeRecords ∧
      (checkpoint,1) ∈ initialized.activeSnapshots := by decide +kernel
  exact Governance.raw_rollback_refines authorized (show Governance.rawRollback env initialized
    7 checkpoint 1 = some ((Governance.rawRollback env initialized 7 checkpoint 1).getD initialized) by rfl)

theorem wrong_snapshot_not_authorized :
    (Governance.rawRollback env initialized 7 checkpoint 999).isSome = true ∧
    (rollback env initialized 7 checkpoint 999).isNone = true ∧
    ¬ Governance.UpgradeAuthorized env initial initialized (.rollback 7 checkpoint 999) := by
  refine ⟨by decide +kernel,by decide +kernel,fun authorized => ?_⟩
  change Governance.RollbackAuthorized env initial initialized checkpoint 999 at authorized
  exact absurd authorized.2.1 (by decide +kernel)

def invalidHistory : Governance.DeployedTrace env initial
    (Governance.transact env initialized (.rollback 7 checkpoint 999)) :=
  .call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7)) (.rollback 7 checkpoint 999)

example : ¬ Governance.AuthorizedUpgrades invalidHistory := by
  intro authorization
  unfold invalidHistory initialized advanced at authorization
  rw [Governance.AuthorizedUpgrades.eq_2] at authorization
  have ok : Governance.execute env initialized (.rollback 7 checkpoint 999) =
      some ((Governance.rawRollback env initialized 7 checkpoint 999).getD initialized) := by
    rfl
  exact wrong_snapshot_not_authorized.2.2 (authorization.2 _ ok)

-- A verifier failure (RECOV-8-24): every proof is accepted, and no header with EL hash 999 is
-- hash-bound, so the landing that writes 999 at height 1 is bad. No landing is trusted, so the
-- last trusted landing is the start record (RECOV-8-28), and restoring it is authorized.
def failEnv : Environment :=
  { env with verify := fun _ _ _ _ _ => true,
             headerHash := fun h => if h.elHash = 999 then 0 else headerCommitment h }
def failInitial := empty failEnv registry
def failAdvanced := Governance.transact failEnv failInitial (.advance 2)
def failStarted := Governance.transact failEnv failAdvanced (.initializeInbox 7)
def failImaged := Governance.transact failEnv failStarted (.image 7 11 true)
def failSource := Governance.transact failEnv failImaged (.advance 3)
def badLanding : Landing := ⟨⟨0,1,999,0,0,999,2,0,1⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
def failed := Governance.transact failEnv failSource (.land badLanding)
def startRecord := failStarted.inbox.checkpoint
def badRecord := failed.inbox.checkpoint

theorem bad_landing_accepted : (land failEnv failSource badLanding).isSome = true ∧
    failed.activeRecords = [badRecord,startRecord] ∧ (startRecord,1) ∈ failed.activeSnapshots ∧
    startRecord.height = 0 ∧ badRecord.height = 1 ∧ badRecord.elHash = 999 := by
  decide +kernel

theorem start_certified : Custody.Certified failEnv failInitial startRecord := by
  have reach : Trace failEnv failInitial failAdvanced := .step (.refl _) (.call _ (.advance 2))
  have path : Custody.Path failEnv failInitial failEnv.genesisHeader :=
    .genesis 7 reach (show initializeInbox failEnv failAdvanced 7 = some failStarted from rfl) rfl
  unfold Custody.Certified
  refine ⟨failEnv.genesisHeader,?_,?_,path⟩
  · unfold Custody.HeaderOf
    decide +kernel
  · unfold HashBound
    decide +kernel

theorem bad_uncertified : ¬ Custody.Certified failEnv failInitial badRecord := by
  intro certified
  unfold Custody.Certified Custody.HeaderOf at certified
  obtain ⟨h,⟨_,cut⟩,bound,_⟩ := certified
  have hash : h.elHash = 999 := by
    have same := congrArg Cut.elHash cut
    simp only [BlockValidity.Header.cut] at same
    rw [same]
    exact bad_landing_accepted.2.2.2.2.2
  have unbound : failEnv.headerHash h = if h.elHash = 999 then 0 else headerCommitment h := rfl
  rw [HashBound,unbound,hash] at bound
  simp at bound

theorem bad_unpending : ¬ Custody.Pending failEnv failed badRecord := by
  intro pending
  unfold Custody.Pending at pending
  exact pending.1 rfl

theorem failure_rollback_authorized :
    Governance.RollbackAuthorized failEnv failInitial failed startRecord 1 := by
  obtain ⟨_,records,snapshot,low,high,_⟩ := bad_landing_accepted
  refine ⟨by rw [records]; exact List.mem_cons_of_mem _ List.mem_cons_self,snapshot,?_,
    badRecord,by rw [records]; exact List.mem_cons_self,by omega,bad_uncertified,bad_unpending,?_⟩
  · intro r retained below
    rw [records] at retained
    rcases List.mem_cons.mp retained with rfl | retained
    · omega
    · rw [List.mem_singleton.mp retained]
      exact Or.inl start_certified
  · intro r _ lower
    omega

def failedHistory : Governance.DeployedTrace failEnv failInitial
    (Governance.transact failEnv failed (.rollback 7 startRecord 1)) :=
  .call (.call (.call (.call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7))
    (.image 7 11 true)) (.advance 3)) (.land badLanding)) (.rollback 7 startRecord 1)

theorem failed_history_authorized : Governance.AuthorizedUpgrades failedHistory := by
  unfold failedHistory failed failSource failImaged failStarted failAdvanced
  rw [Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_1]
  refine ⟨⟨⟨⟨⟨⟨True.intro,?_⟩,?_⟩,?_⟩,?_⟩,?_⟩,?_⟩
  · intro t _; trivial
  · intro t _; trivial
  · intro t _; trivial
  · intro t _; trivial
  · intro t _; trivial
  · intro t _
    exact failure_rollback_authorized

example : Trace failEnv failInitial (Governance.transact failEnv failed (.rollback 7 startRecord 1)) :=
  Governance.authorized_trace_refines failedHistory failed_history_authorized

-- The authorized rollback restores the start record and voids the bad record.
example : ((Governance.rawRollback failEnv failed 7 startRecord 1).map fun t =>
    (t.inbox.checkpoint,t.inbox.snapshot,t.activeRecords)) = some (startRecord,1,[startRecord]) := by
  decide +kernel

example (t : World) (ok : Governance.rawRollback failEnv failed 7 startRecord 1 = some t) :
    ∀ cp ∈ t.activeRecords, Custody.Certified failEnv failInitial cp ∨ Custody.Pending failEnv t cp :=
  (Governance.authorized_rollback_restores failure_rollback_authorized ok).2.2.2.2

-- The duty leaves no choice: every authorized target here is at the start record's height.
example (target : Checkpoint) (snapshot : Nat)
    (authorized : Governance.RollbackAuthorized failEnv failInitial failed target snapshot) :
    target.height = 0 :=
  (Governance.rollback_target_unique authorized failure_rollback_authorized).trans
    bad_landing_accepted.2.2.2.1

-- The bad record itself is never a rollback target.
example : ¬ Governance.RollbackAuthorized failEnv failInitial failed badRecord 1 := by
  intro authorized
  exact (authorized.2.2.1 badRecord authorized.1 (Nat.le_refl _)).elim bad_uncertified bad_unpending

-- A corrected switching origin retains the old physical mapping entry while
-- replacing its ghost retained lineage. Physical existence does not authorize it.
def switchEnv : Environment := { env with core := { env.core with unzenInbox := 99 } }
def switchInitial := empty switchEnv registry
def switchAdvanced := Governance.transact switchEnv switchInitial (.advance 2)
def switchInitialized := Governance.transact switchEnv switchAdvanced (.initializeInbox 7)
def firstOrigin := Governance.transact switchEnv switchInitialized (.setOrigin 8 5 101 15)
def oldCheckpoint := firstOrigin.inbox.checkpoint
def correctedOrigin := Governance.transact switchEnv firstOrigin (.correctStart 7 10 102 20)

def correctedHistory : Governance.DeployedTrace switchEnv switchInitial correctedOrigin :=
  .call (.call (.call (.call (.refl _) (.advance 2)) (.initializeInbox 7))
    (.setOrigin 8 5 101 15)) (.correctStart 7 10 102 20)

theorem corrected_prefix_authorized : Governance.AuthorizedUpgrades correctedHistory := by
  unfold correctedHistory correctedOrigin firstOrigin switchInitialized switchAdvanced
  rw [Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_2,Governance.AuthorizedUpgrades.eq_2,
    Governance.AuthorizedUpgrades.eq_1]
  refine ⟨⟨⟨⟨True.intro,?_⟩,?_⟩,?_⟩,?_⟩
  · intro t _; trivial
  · intro t _; trivial
  · intro t _; trivial
  · intro t _
    change firstOrigin.everLanded = false
    decide +kernel

example : Trace switchEnv switchInitial correctedOrigin :=
  Governance.authorized_trace_refines correctedHistory corrected_prefix_authorized

theorem archived_target_raw_success_normative_refusal :
    recordAt correctedOrigin.inbox oldCheckpoint.height = some oldCheckpoint ∧
    oldCheckpoint ∉ correctedOrigin.activeRecords ∧
    (Governance.rawRollback switchEnv correctedOrigin 7 oldCheckpoint 1).isSome = true ∧
    (rollback switchEnv correctedOrigin 7 oldCheckpoint 1).isNone = true ∧
    ¬ Governance.UpgradeAuthorized switchEnv switchInitial correctedOrigin (.rollback 7 oldCheckpoint 1) := by
  have archived : oldCheckpoint ∉ correctedOrigin.activeRecords := by decide +kernel
  refine ⟨by decide +kernel,archived,by decide +kernel,by decide +kernel,fun authorized => ?_⟩
  change Governance.RollbackAuthorized switchEnv switchInitial correctedOrigin oldCheckpoint 1 at authorized
  exact archived authorized.1

def archivedRollbackHistory : Governance.DeployedTrace switchEnv switchInitial
    (Governance.transact switchEnv correctedOrigin (.rollback 7 oldCheckpoint 1)) :=
  .call correctedHistory (.rollback 7 oldCheckpoint 1)

theorem archived_history_not_authorized : ¬ Governance.AuthorizedUpgrades archivedRollbackHistory := by
  intro authorization
  unfold archivedRollbackHistory at authorization
  rw [Governance.AuthorizedUpgrades.eq_2] at authorization
  have duty : ∀ t, Governance.execute switchEnv correctedOrigin (.rollback 7 oldCheckpoint 1) = some t →
      Governance.UpgradeAuthorized switchEnv switchInitial correctedOrigin (.rollback 7 oldCheckpoint 1) :=
    authorization.2
  have ok : Governance.execute switchEnv correctedOrigin (.rollback 7 oldCheckpoint 1) =
      some ((Governance.rawRollback switchEnv correctedOrigin 7 oldCheckpoint 1).getD correctedOrigin) := by
    rfl
  exact archived_target_raw_success_normative_refusal.2.2.2.2 (duty _ ok)

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
