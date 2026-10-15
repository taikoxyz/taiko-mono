module
public import Etna.Landing.Proofs
@[expose] public section
namespace Etna.Landing

def exampleWorld : World := {
  inbox := 100
  active := true
  maxBatchBlocks := 40
  checkpoint := ⟨10, 1000⟩
  head := 2
  tail := 5
  fee := fun n => if n = 2 then 7 else if n = 3 then 11 else 19
  signal := []
  inboxBalance := 1000000000000000000
  transfers := []
  logs := []
  guard := false }
def exampleInput : LandInput := ⟨13, 291, 1110, 19999, 4, 48879, 51966⟩
def exampleEnvironment : Environment := ⟨20000, 2748, true, 32, 2748, [1,2]⟩
def exampleExternal : ExternalOutcomes := ⟨exampleEnvironment, true, true, true, .none, fun _ => 0⟩

theorem normal_nonvacuity : (execLandSteps exampleWorld exampleInput exampleExternal).error = none := by decide

theorem nonzero_payment_nonvacuity :
    (execLandSteps exampleWorld exampleInput exampleExternal).journal.current.transfers =
      [⟨48879, 18000000000⟩] := by rfl

theorem verifier_failure_after_writes :
    let r := execLandSteps exampleWorld exampleInput { exampleExternal with verifierReturnsNormally := false }
    r.error = some .verifier ∧ r.journal.current.head.val = 4 ∧
    r.journal.current.checkpoint.height = 13 ∧ r.journal.current.signal.length = 1 ∧
    r.journal.current.logs.length = 2 := by decide

theorem signal_failure_after_writes :
    let r := execLandSteps exampleWorld exampleInput { exampleExternal with signalAuthorized := false }
    r.error = some .signalUnauthorized ∧ r.journal.current.head.val = 4 ∧
    r.journal.current.checkpoint.height = 13 ∧ r.journal.current.signal = [] := by decide

theorem payment_failure_after_verifier :
    let r := execLandSteps exampleWorld exampleInput { exampleExternal with paymentReturnsNormally := false }
    r.error = some .payment ∧ r.journal.current.head.val = 4 ∧
    r.journal.current.signal.length = 1 ∧ r.journal.current.logs.length = 2 := by decide

theorem zero_fee_skips_callback :
    (execLandSteps { exampleWorld with fee := fun _ => 0 } exampleInput
      { exampleExternal with paymentReturnsNormally := false, reentry := .landUncaught }).error = none := by decide

theorem caught_reentry_nonvacuity :
    (execLandSteps exampleWorld exampleInput { exampleExternal with reentry := .landCaught }).error = none ∧
    nestedGuard exampleWorld.inbox { exampleWorld with guard := true } = some .reentrant := by decide

theorem static_verifier_guard_nonvacuity :
    (execLandSteps exampleWorld exampleInput { exampleExternal with reentry := .verifierLand }).error = none := by decide

theorem reference_boundaries_nonvacuity :
    referenceHash exampleEnvironment 19744 = .ok (.blockhash, 2748) ∧
    referenceHash exampleEnvironment 19743 = .ok (.history, 2748) ∧
    referenceHash exampleEnvironment 11809 = .ok (.history, 2748) ∧
    referenceHash exampleEnvironment 11808 = .error .anchorUnavailable ∧
    referenceHash exampleEnvironment 20000 = .error .anchorUnavailable ∧
    referenceHash exampleEnvironment 20001 = .error .anchorUnavailable := by norm_num [referenceHash, exampleEnvironment]

theorem malformed_history_nonvacuity :
    referenceHash { exampleEnvironment with historyLength := 31 } 19743 = .error .anchorUnavailable ∧
    referenceHash { exampleEnvironment with historyLength := 33 } 19743 = .error .anchorUnavailable ∧
    referenceHash { exampleEnvironment with historyLength := 0 } 19743 = .error .anchorUnavailable := by norm_num [referenceHash, exampleEnvironment]

theorem ordered_blobs_nonvacuity :
    actualBlobs exampleEnvironment = [1,2] ∧
    actualBlobs { exampleEnvironment with blobHashes := [2,1] } = [2,1] ∧
    actualBlobs { exampleEnvironment with blobHashes := [1,0,2] } = [1] ∧
    environmentCheck { exampleEnvironment with blobHashes := [] } exampleInput = some .blobsRequired := by decide

/-- Local separation has a finite satisfiable instance; no assertion of global Keccak injectivity. -/
theorem local_separation_nonvacuity (s : LandStatement) :
    LocalHashSeparation (fun _ => 0) s s := by intro impossible; exact False.elim (impossible rfl)
end Etna.Landing
