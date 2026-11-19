import EtnaProofs.Current

namespace Etna.CurrentRegression
open Etna.Design.Current

theorem timestamp_boundary : Rules.select ⟨1,2,100,0⟩ 99 = 1 ∧
    Rules.select ⟨1,2,100,0⟩ 100 = 2 := by decide +kernel

theorem crossing_batch_accepted : Rules.covers [1,2] ⟨1,2,100,0⟩ [99,100,101] = true ∧
    Rules.covers [1] ⟨1,2,100,0⟩ [99,100] = false := by decide +kernel

-- START-10.1-14d: a block is invalid once its parent's timestamp reaches stopTime, at any
-- height; one second earlier it is valid, and stopTime = 0 schedules no stop.
theorem planned_stop_boundary : Rules.stopped ⟨0,0,0,100⟩ 100 = true ∧
    Rules.stopped ⟨0,0,0,100⟩ 99 = false ∧ Rules.stopped ⟨0,0,0,0⟩ 100 = false := by decide +kernel

theorem rule_schedule_deadline :
    Rules.scheduleRules ⟨true,7,10⟩ ⟨0,1,100,0⟩ 7 90 1 200 = none ∧
    (Rules.scheduleRules ⟨true,7,10⟩ ⟨0,1,100,0⟩ 7 89 1 200).isSome = true := by decide +kernel

-- START-10.1-5b: an existing stop changes only while now + maxAnchorAge < stopTime, and a new
-- nonzero stop is at least now + maxAnchorAge.
theorem stop_deadline :
    Rules.scheduleStop ⟨true,7,10⟩ ⟨0,0,0,100⟩ 7 90 0 = none ∧
    (Rules.scheduleStop ⟨true,7,10⟩ ⟨0,0,0,100⟩ 7 89 0).isSome = true ∧
    Rules.scheduleStop ⟨true,7,10⟩ ⟨0,0,0,0⟩ 7 89 98 = none ∧
    Rules.scheduleStop ⟨true,7,10⟩ ⟨0,0,0,0⟩ 7 89 99 = some ⟨0,0,0,99⟩ := by decide +kernel

theorem absolute_epoch : Start.epochHeight 4 3 = 13 := by decide +kernel

theorem first_anchor_uses_origin : Start.anchorAllowed 8 1 20 8 8 = true ∧
    Start.anchorAllowed 8 2 20 8 8 = false := by decide +kernel

theorem unzen_fence : Start.firstLanding true 5 5 70 80 ⟨4,3,70,true,5,70,80⟩ = true ∧
    Start.firstLanding true 5 5 70 80 ⟨5,3,70,true,5,70,80⟩ = false ∧
    Start.firstLanding true 5 5 70 80 ⟨4,3,70,true,5,70,81⟩ = false := by decide +kernel

-- LAND-6.1-8a reads the SignalService checkpoint at S: matching hash and stateRoot saved at
-- another height do not pass.
theorem unzen_fence_checkpoint_height :
    Start.firstLanding true 5 5 70 80 ⟨4,3,70,true,10,70,80⟩ = false := by decide +kernel

theorem cancelling_stop_checks_arithmetic_not_unstored_field_width :
    Rules.scheduleStop ⟨true,7,10⟩ ⟨0,0,0,0⟩ 7 (Etna.Design.limit48-10) 0 =
      some ⟨0,0,0,0⟩ := by decide +kernel

end Etna.CurrentRegression

namespace Etna.CurrentRegression
open Etna.Design.Current

def emptyRegistry : Registry.State := ⟨0,fun _ => none,fun _ => none,fun _ => none,1,1⟩
def firstRegistry : Registry.State := ((Registry.register emptyRegistry 11 7 10 1).getD (emptyRegistry,0)).1

theorem bond_zero_is_present : firstRegistry.nextId = 1 ∧ firstRegistry.keyId 11 = some 0 ∧
    firstRegistry.slots 0 = some 0 := by decide +kernel

def lowBond : Registry.Bond := ⟨⟨11,7,10,2,Etna.Design.Staking.noExit,false,none,3,20⟩,some 17⟩
def fullRegistry : Registry.State := ⟨4096,fun id => if id = 17 then some lowBond else
    some ⟨⟨100+id,8,100,2,Etna.Design.Staking.noExit,false,none,0,0⟩,some id⟩,
  fun slot => some slot,fun key => if key = 11 then some 17 else none,1,1⟩

theorem full_registry_admits_nobody : Registry.admissionSlot fullRegistry = none ∧
    Registry.register fullRegistry 55 9 1000 20 = none := by decide +kernel

def slashedRegistry : Registry.State := (Registry.slash fullRegistry true true 17 20 1000).getD emptyRegistry

theorem zero_balance_keeps_slot :
    ((slashedRegistry.bonds 17).map (fun b => (b.value.balance,b.value.exitAt,b.slot))) = some (0,20,some 17) ∧
    slashedRegistry.slots 17 = some 17 ∧ Registry.register slashedRegistry 55 9 1000 21 = none := by decide +kernel

def confirmedRegistry : Registry.State :=
  (Registry.confirm slashedRegistry true 20 17 21).getD emptyRegistry

theorem init_without_origin_can_confirm_exited_bond :
    ((confirmedRegistry.bonds 17).map (fun b => b.value.confirmedAt)) = some (some 21) ∧
    Registry.confirm slashedRegistry false 20 17 21 = none := by decide +kernel

-- Anyone may withdraw a zero-balance bond; withdrawal frees its own slot and no other.
def withdrawnRegistry : Registry.State :=
  ((Registry.withdraw confirmedRegistry 17 99 31 10).getD (emptyRegistry,0)).1

theorem withdrawn_id_survives_and_slot_frees :
    ((withdrawnRegistry.bonds 17).map (fun b => (b.value.key,b.value.exitAt,b.value.released,b.slot))) =
      some (11,20,true,none) ∧
    withdrawnRegistry.slots 17 = none ∧ withdrawnRegistry.slots 0 = some 0 ∧ withdrawnRegistry.keyId 11 = some 17 ∧
    (Registry.exclude withdrawnRegistry 17 11 40).isSome = true ∧
    Registry.exclude withdrawnRegistry 4097 0 40 = none := by decide +kernel

def reused : Registry.State := ((Registry.register withdrawnRegistry 55 9 14 32).getD (emptyRegistry,0)).1

theorem withdrawn_slot_reused : Registry.admissionSlot withdrawnRegistry = some 17 ∧
    reused.slots 17 = some 4096 ∧ reused.nextId = 4097 ∧
    ((reused.bonds 17).map (fun b => b.slot)) = some none := by decide +kernel

theorem recover_number_and_pending_schedule :
    Rules.recover ⟨1,2,100,80⟩ 2 = none ∧
    Rules.recover ⟨1,2,100,80⟩ 3 = some ⟨3,3,0,0⟩ ∧
    Rules.recover ⟨1,2,100,80⟩ 0 = some ⟨1,2,100,0⟩ := by decide +kernel

def initializedOrigin : Start.State := ⟨true,none,0,fun _ => none,7,8,100⟩
def writtenOrigin : Start.State :=
  (Start.setOrigin initializedOrigin 7 100 9 5 70 80).getD initializedOrigin

theorem start_write_and_correction :
    Start.setOrigin initializedOrigin 7 99 9 5 70 80 = none ∧
    writtenOrigin.start = some (5,70,80) ∧
    Start.setOrigin writtenOrigin 7 101 10 6 71 81 = none ∧
    ((Start.correct writtenOrigin true true 5 6 71 81 10 101).map (fun s =>
      (s.generation,s.origins 0,s.origins 1))) = some (1,some ⟨5,9,100⟩,some ⟨6,10,101⟩) := by decide +kernel

def candidate : Import.Candidate := ⟨2,5,400,70,70,true,true,true,true,true,true,true,true⟩

theorem import_authentication_priority :
    Import.inspect { candidate with envelopeEL := 71, dataHashAuthenticated := false } 2 = .reject ∧
    Import.inspect { candidate with envelopeEL := 71, valStateAuthenticated := false } 2 = .halt ∧
    Import.inspect { candidate with envelopeEL := 71, materialAvailable := false } 2 = .halt ∧
    Import.inspect { candidate with materialAvailable := false } 2 = .retry ∧
    Import.inspect candidate 3 = .reject := by decide +kernel

/-- A checkpoint known only from a publisher claim, with no record landed on L1. -/
def unlanded : Import.Candidate :=
  { candidate with checkpointAuthenticated := false, checkpointFinalized := false }

/-- SPEC 5.3 vectors 4.m, 4.n and 4.f: a record landed only in an unfinalized L1 block leaves
the import retrying, even when its envelope would conflict; once the record finalizes the same
candidate stages; a checkpoint with no landed record rejects. -/
theorem import_checkpoint_finality :
    Import.inspect { candidate with checkpointFinalized := false } 2 = .retry ∧
    Import.inspect { candidate with checkpointFinalized := false, envelopeEL := 71 } 2 = .retry ∧
    Import.inspect candidate 2 = .staged ∧
    Import.inspect unlanded 2 = .reject := by decide +kernel

/-- DATA-5.4-3/5: a preimage of valStateHash(s − 1) that, with the EL hash of s − 1, does not
give header(s)'s app_hash rejects when there is no finalized envelope conflict; one that does but whose sets differ
from header(s)'s validators_hash or next_validators_hash halts once the record is finalized; a
committee derived under 4.3 that differs from the derived sets halts, but only after the
window is available and authenticated. -/
theorem import_validator_state :
    Import.inspect { candidate with valStateAuthenticated := false } 2 = .reject ∧
    Import.inspect { candidate with valStateAuthenticated := false, validatorSetsMatch := false } 2 = .reject ∧
    Import.inspect { candidate with validatorSetsMatch := false } 2 = .halt ∧
    Import.inspect { candidate with validatorSetsMatch := false, checkpointFinalized := false } 2 = .retry ∧
    Import.inspect { candidate with committeesMatch := false } 2 = .halt ∧
    Import.inspect { candidate with committeesMatch := false, materialAvailable := false } 2 = .retry ∧
    Import.inspect { candidate with committeesMatch := false, metadataAuthenticated := false } 2 = .reject := by
  decide +kernel

/-- A snapshot at the origin itself (s = o). -/
def atOrigin : Import.Candidate := { candidate with height := 5 }

/-- DATA-5.4-1 and vector 5.4 1.b: a snapshot at s = o takes the 8.4 genesis path, whose
validator state CometBFT builds from this generation's genesis, so the three validator-state
results do not matter there; the envelope and finality checks still apply. One block later,
s = o + 1, the preimage check applies again. -/
theorem import_genesis_path :
    Import.inspect { atOrigin with valStateAuthenticated := false } 2 = .staged ∧
    Import.inspect { atOrigin with validatorSetsMatch := false } 2 = .staged ∧
    Import.inspect { atOrigin with committeesMatch := false } 2 = .staged ∧
    Import.inspect { atOrigin with valStateAuthenticated := false, envelopeEL := 71 } 2 = .halt ∧
    Import.inspect { atOrigin with valStateAuthenticated := false, checkpointFinalized := false } 2 = .retry ∧
    Import.inspect { candidate with height := 6, valStateAuthenticated := false } 2 = .reject ∧
    Import.inspect { candidate with height := 6, committeesMatch := false } 2 = .halt := by
  decide +kernel

/-- DATA-5.4-4 (#22338): the import retains EL headers from max(o, s - U + 1) through s. -/
theorem import_retained_window :
    Import.retainedFrom candidate 1 = 400 ∧ Import.retainedFrom candidate 4 = 397 ∧
    Import.retainedFrom candidate 396 = 5 ∧ Import.retainedFrom candidate 1000 = 5 := by decide

theorem interrupted_import_unpublished (signer : Etna.Design.Signer.State) :
    Import.publish candidate 2 1 signer false = none := by rfl

end Etna.CurrentRegression

namespace Etna.CurrentRegression
open Etna.Design.Current

theorem unissued_default_storage_cannot_authenticate :
    Registry.exclude { emptyRegistry with bonds := fun _ => some lowBond } 0 11 40 = none := by decide +kernel

def gapRegistry : Registry.State := { fullRegistry with slots := fun slot => if slot = 1 ∨ 4 ≤ slot then none else some slot }

theorem lowest_empty_slot_wins : Registry.admissionSlot gapRegistry = some 1 := by decide +kernel

theorem field_overflow_and_cancellation :
    Rules.scheduleRules ⟨true,7,10⟩ ⟨0,0,0,0⟩ 7 0 1 Etna.Design.limit48 = none ∧
    Rules.scheduleRules ⟨true,7,10⟩ ⟨0,1,100,0⟩ 7 89 1 (Etna.Design.limit48-1) =
      some ⟨0,1,Etna.Design.limit48-1,0⟩ := by decide +kernel
end Etna.CurrentRegression
