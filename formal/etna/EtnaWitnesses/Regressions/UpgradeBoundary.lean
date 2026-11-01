import EtnaProofs.UpgradeBoundary
import EtnaWitnesses.Regressions.Reconstruction
import EtnaWitnesses.Regressions.TrustState

/-! Actual land and stock signing calls, with finite exact-plan/checkpoint authority.
This authority is a witness to the conditional interface, not a DAO implementation. -/
namespace Etna.Design.UpgradeBoundaryRegression
open UpgradeBoundary SigningBridge

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

def oldVersion : Version := ⟨1,1,77,[11],1⟩
def newVersion : Version := ⟨2,2,77,[22],2⟩
def earlierVersion : Version := ⟨0,0,77,[10],1⟩
def upgrade : Plan := ⟨FirstBatch.deployment,0,2,oldVersion,newVersion⟩
def message (height block : Nat) : SignMessage := ⟨FirstBatch.deployment,0,height,0,.precommitMsg,block⟩
def encode := SigningBridgeRegression.messageCode

def logEntry : Signer.Signed := ⟨0,⟨2,0,3⟩,encode (message 2 1002),777⟩
def device : Signer.State := ⟨FirstBatch.deployment,0,1,[],true,[logEntry]⟩
def node : TrustState.Node := { TrustState.startup device with trusted := true, signer := device }
def oldJob : Job := ⟨FirstBatch.deployment,0,0,2,oldVersion,11,ReconstructionRegression.statement2⟩
def initial : System :=
  ⟨{ NonVacuity.world0 with inbox := { FirstBatch.inbox with configuration := ⟨1,1,1,6⟩ } },
    node,⟨fun _ => oldVersion,[]⟩,[oldVersion],[⟨oldJob,.pending⟩],none,2⟩
def auth : Authority :=
  ⟨fun p => decide (p = upgrade),fun domain cp => decide
    (domain = FirstBatch.deployment ∧ cp = ReconstructionRegression.inbox2.checkpoint)⟩
def stopped : System := prepare (some auth) initial upgrade
def landed : System :=
  { stopped with
    world := ProtocolState.landed stopped.world (applyLanding stopped.world.inbox ReconstructionRegression.statement2.input) ReconstructionRegression.environment2.blockNumber
    jobs := [⟨oldJob,.settled⟩] }
def switched : System := applySwitch landed upgrade

def successfulBoundary : Prop :=
  stopped.staged = some upgrade ∧ settle stopped 0 ReconstructionRegression.statement2.input
      ReconstructionRegression.firstCertificate.leaves ReconstructionRegression.environment2 = some landed ∧
  (activate (some auth) landed true).world.inbox.gridK = 2 ∧
  (activate (some auth) landed true).node.signer.log = [logEntry] ∧
  (activate (some auth) landed true).jobs = [⟨oldJob,.settled⟩]

theorem switch_success : successfulBoundary := ⟨rfl,rfl,rfl,rfl,rfl⟩

def historicalRetry : Prop :=
  sign switched encode (message 2 1002) oldVersion 999 false = some (device,777)

theorem cached_old_rules : historicalRetry := by unfold historicalRetry; decide +kernel

theorem fresh_new_rules :
    sign switched encode (message 3 1003) newVersion 888 true =
      some ({ device with log := ⟨0,⟨3,0,3⟩,encode (message 3 1003),888⟩ :: device.log },888) ∧
    sign switched encode (message 3 1003) oldVersion 888 true = none ∧
    sign stopped encode (message 3 1003) oldVersion 888 true = none := by decide +kernel

theorem conflicting_cached_bytes : sign switched encode (message 2 9999) oldVersion 888 true = none := by
  decide +kernel

theorem closed_trust_refuses :
    sign { switched with node := TrustState.close switched.node } encode (message 2 1002) oldVersion 888 true = none ∧
    sign { switched with node := TrustState.timeout switched.node } encode (message 2 1002) oldVersion 888 true = none := by
  decide +kernel

def prior : Schedule := ⟨fun h => if h ≤ 1 then earlierVersion else oldVersion,[1]⟩
def priorHistory : Prop :=
  (extendSchedule prior 2 newVersion).versionAt 1 = earlierVersion ∧
  (extendSchedule prior 2 newVersion).versionAt 2 = oldVersion ∧
  (extendSchedule prior 2 newVersion).versionAt 3 = newVersion ∧
  (extendSchedule prior 2 newVersion).boundaries = [1,2]

theorem prior_history_preserved : priorHistory := by unfold priorHistory; decide +kernel

theorem repeated_rules_still_cross :
    noCrossing ⟨fun _ => oldVersion,[1]⟩ 0 2 = false ∧
    batchAllowed { initial with schedule := ⟨fun _ => oldVersion,[1]⟩ } oldJob = false := by decide +kernel

theorem jobs_and_old_only_image :
    batchAllowed switched { oldJob with first := 2,last := 4 } = false ∧
    batchAllowed switched { oldJob with first := 2,last := 4,version := newVersion } = false ∧
    batchAllowed switched { oldJob with first := 2,last := 4,version := newVersion,image := 22 } = true ∧
    batchAllowed switched { oldJob with last := 4,version := newVersion,image := 22 } = false ∧
    (invalidate stopped 0).jobs = [⟨oldJob,.invalidated⟩] := by decide +kernel

theorem unclosed_job_blocks :
    (activate (some auth) { landed with jobs := [⟨oldJob,.pending⟩] } true).staged = some upgrade ∧
    (activate (some auth) (invalidate { landed with jobs := [⟨oldJob,.pending⟩] } 0) true).staged = none := by
  decide +kernel

theorem wrong_statement_rejected :
    settle { stopped with jobs := [⟨{ oldJob with statement := FirstBatch.publicStatement },.pending⟩] }
      0 ReconstructionRegression.statement2.input ReconstructionRegression.firstCertificate.leaves
      ReconstructionRegression.environment2 = none := by decide +kernel

theorem disabled_and_failed :
    (prepare none (retainMaterial initial newVersion) upgrade).staged = none ∧
    (activate none landed true).staged = some upgrade ∧
    (activate (some auth) landed false).node.signer.log = [logEntry] ∧
    (activate (some auth) stopped true).staged = some upgrade := by decide +kernel

theorem wrong_plan_auth_checkpoint :
    (prepare (some auth) initial { upgrade with height := 4 }).staged = none ∧
    (activate (some { auth with checkpoint := fun _ _ => false }) landed true).staged = some upgrade ∧
    (activate (some { auth with plan := fun _ => false }) landed true).staged = some upgrade := by decide +kernel

theorem incompatible_grid_and_configuration :
    planFits initial { upgrade with height := 3 } = false ∧
    planFits initial { upgrade with next := { newVersion with grid := 4 } } = false ∧
    planFits initial { upgrade with next := { newVersion with config := 999 } } = false ∧
    planFits { initial with world := { initial.world with inbox := { initial.world.inbox with maxBatchBlocks := 1 } } } upgrade = false := by
  decide +kernel

theorem existing_above_boundary_refuses :
    planFits { initial with produced := 3 } upgrade = false ∧
    planFits { initial with node := { node with signer := { device with log := [⟨0,⟨3,0,3⟩,0,0⟩] } } } upgrade = false := by
  decide +kernel

/-- A higher HRS from an older generation is preserved but does not block this generation. -/
def retiredHigh : System :=
  { landed with
    world := { landed.world with inbox := { landed.world.inbox with generation := 1 } }
    node := { node with signer := { device with activeGeneration := 1, retired := [0],log := [⟨0,⟨99,0,3⟩,123,456⟩] } }
    staged := some { upgrade with generation := 1 } }
def nextAuth : Authority := { auth with plan := fun p => decide (p = { upgrade with generation := 1 }) }

theorem retired_high_log_kept :
    (activate (some nextAuth) retiredHigh true).staged = none ∧
    (activate (some nextAuth) retiredHigh true).node.signer.log = [⟨0,⟨99,0,3⟩,123,456⟩] ∧
    (activate (some nextAuth) retiredHigh true).node.signer.activeGeneration = 1 := by decide +kernel

/-- Genuine Task2 authenticated/replayed/open session; gate calls its exact actual sign. -/
def trustedVersion : Version := ⟨1,1,HistoricalEscrow.worldD.inbox.committeeConfig,[11],1⟩
def trustedSystem : System :=
  ⟨HistoricalEscrow.worldD,TrustStateRegression.session0,⟨fun _ => trustedVersion,[]⟩,
    [trustedVersion],[],none,12⟩

theorem existing_session_composition :
    TrustStateRegression.DeviceReachable trustedSystem.node ∧
    sign trustedSystem TrustStateRegression.bytes0 (TrustStateRegression.message0 .precommitMsg true)
      trustedVersion (TrustStateRegression.bytes0 (TrustStateRegression.message0 .precommitMsg true)+8) true =
      some ((TrustStateRegression.signed0 .precommitMsg true).signer,
        TrustStateRegression.bytes0 (TrustStateRegression.message0 .precommitMsg true)+8) :=
  ⟨TrustStateRegression.session0_reachable,rfl⟩

end Etna.Design.UpgradeBoundaryRegression
