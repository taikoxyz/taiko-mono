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
def exampleInput : LandInput := ⟨13, 291, 1110, 19999, 4, 48879, 57005, 123456, 51966⟩
def exampleEnvironment : Environment := ⟨20000, 2748, true, 32, 2748, [1,2]⟩
/-- A constant toy reward hash, not Keccak; it makes every recorded commitment nonzero. -/
def exampleExternal : ExternalOutcomes := ⟨exampleEnvironment, true, true, true, .none, fun _ => 0, fun _ => 7⟩

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
    r.journal.current.signal.length = 1 ∧ r.journal.current.logs.length = 3 ∧
    r.journal.current.rewardCommitments 7 = 7 ∧ r.journal.rollback.rewardCommitments 7 = 0 := by decide

/-- The receipt is recorded after the verifier, at its id, with its event before the FI event. -/
theorem reward_recorded_nonvacuity :
    let r := execLandSteps exampleWorld exampleInput exampleExternal
    r.error = none ∧ r.journal.current.rewardCommitments 7 = 7 ∧ r.journal.current.logs.length = 4 ∧
    r.trace = [.entry, .checked, .statement, .head, .checkpoint, .signal, .batchEvent, .verifier, .reward,
      .payment, .consumed, .unlock] := by decide

/-- An occupied slot reverts the whole landing after the verifier and before any payment. -/
theorem occupied_reward_slot_reverts :
    let w := { exampleWorld with rewardCommitments := fun _ => 1 }
    let r := execLandSteps w exampleInput exampleExternal
    r.error = some .rewardAlreadyRecorded ∧ r.stage = .reward ∧ r.journal.current.transfers = [] ∧
    (runTransaction w r).world.head = w.head := by decide

theorem zero_reward_recipient_rejected :
    (execLandSteps exampleWorld { exampleInput with rewardRecipient := 0 } exampleExternal).error =
      some .zeroRewardRecipient := by decide

/-- A zero base-fee amount is still recorded: `claim` later consumes it without a transfer. -/
theorem zero_base_fee_recorded :
    let r := execLandSteps exampleWorld { exampleInput with baseFeeAmount := 0 } exampleExternal
    r.error = none ∧ r.journal.current.rewardCommitments 7 = 7 := by decide

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
/-- A finite two-point crypto witness, not Keccak: it separates32 and64byte preimages. -/
def exampleInnerHash (bytes : List Byte) : Word256 :=
  if bytes.length = 32 then 1 else 2

def withBlobPrefix (x : ExternalOutcomes) (blobs : List Word256) : ExternalOutcomes :=
  { x with environment := { x.environment with blobHashes := blobs }, keccakBlobBytes := exampleInnerHash }

/-- Both local assumptions are satisfiable together on different-length actual prefixes,
and the resulting outer hashes differ. The conclusion is derived, not an assumed blob equality. -/
theorem composed_unequal_length_nonvacuity (w : World) (i : LandInput) (x : ExternalOutcomes) :
    ∃ outerHash : Vector Byte 640 → Word256,
      LocalInnerHashSeparation exampleInnerHash
        (actualBlobs (withBlobPrefix x [1]).environment)
        (actualBlobs (withBlobPrefix x [1,2]).environment) ∧
      LocalHashSeparation outerHash
        (computedStatement w i (withBlobPrefix x [1]))
        (computedStatement w i (withBlobPrefix x [1,2])) ∧
      outerHash (encodeStatement (computedStatement w i (withBlobPrefix x [1]))) ≠
        outerHash (encodeStatement (computedStatement w i (withBlobPrefix x [1,2]))) := by
  have inner : LocalInnerHashSeparation exampleInnerHash
      (actualBlobs (withBlobPrefix x [1]).environment)
      (actualBlobs (withBlobPrefix x [1,2]).environment) := by
    simp [LocalInnerHashSeparation, withBlobPrefix, actualBlobs, exampleInnerHash, serializeBlobPrefix_length]
  have different : computedStatement w i (withBlobPrefix x [1]) ≠
      computedStatement w i (withBlobPrefix x [1,2]) := by
    intro equal
    have wordEqual := congrArg LandStatement.blobCommitment equal
    have typed : natWord 1 = natWord 2 := by
      simpa [computedStatement, makeStatement, withBlobPrefix, actualBlobs,
        exampleInnerHash, serializeBlobPrefix_length] using wordEqual
    have impossible := natWord_injective 1 2 (by decide) (by decide) typed
    omega
  obtain ⟨outer, separated⟩ := local_separation_distinct_nonvacuity _ _ different
  refine ⟨outer, inner, separated, ?_⟩
  apply separated
  intro equal
  exact different ((statement_complete _ _).mp equal)

/-- The review's constant-hash counterexample is explicitly excluded by the inner premise. -/
theorem constant_inner_hash_not_separated :
    ¬LocalInnerHashSeparation (fun _ => 0) [1] [1,2] := by
  intro separation
  have different : serializeBlobPrefix [1] ≠ serializeBlobPrefix [1,2] := by
    intro equal
    have lengths := congrArg List.length equal
    norm_num [serializeBlobPrefix_length] at lengths
  exact separation different rfl

/-- All composed theorem premises also hold on a successful matching pair whose raw
transaction environments differ after the first zero. Only the actual prefix is bound. -/
theorem composed_binding_success_nonvacuity (w : World) (i : LandInput) (x : ExternalOutcomes) :
    computedStatement w i (withBlobPrefix x [1,2]) =
      computedStatement w i (withBlobPrefix x [1,2,0,3]) ∧
    actualBlobs (withBlobPrefix x [1,2]).environment =
      actualBlobs (withBlobPrefix x [1,2,0,3]).environment := by
  apply composed_statement_blob_binding (fun _ => 0) w w i i
    (withBlobPrefix x [1,2]) (withBlobPrefix x [1,2,0,3]) rfl
  · simp [LocalInnerHashSeparation, withBlobPrefix, actualBlobs]
  · simp [LocalHashSeparation, computedStatement, withBlobPrefix, actualBlobs, referenceHash]
    rfl
  · rfl

end Etna.Landing
