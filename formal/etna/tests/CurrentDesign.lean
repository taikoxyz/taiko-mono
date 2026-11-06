import EtnaProofs.Current

namespace Etna.CurrentRegression
open Etna.Design.Current

theorem timestamp_boundary : Rules.select ⟨1,2,100,0,0⟩ 99 = 1 ∧
    Rules.select ⟨1,2,100,0,0⟩ 100 = 2 := by decide +kernel

theorem crossing_batch_accepted : Rules.covers [1,2] ⟨1,2,100,0,0⟩ [99,100,101] = true ∧
    Rules.covers [1] ⟨1,2,100,0,0⟩ [99,100] = false := by decide +kernel

theorem offset_stop : Rules.stopped ⟨0,0,0,100,6⟩ 5 11 100 = true ∧
    Rules.stopped ⟨0,0,0,100,6⟩ 5 12 100 = false := by decide +kernel

theorem rule_schedule_deadline :
    Rules.scheduleRules ⟨true,7,10,3⟩ ⟨0,1,100,0,0⟩ 7 90 1 200 = none ∧
    (Rules.scheduleRules ⟨true,7,10,3⟩ ⟨0,1,100,0,0⟩ 7 89 1 200).isSome = true := by decide +kernel

theorem stop_deadline :
    Rules.scheduleStop ⟨true,7,10,3⟩ ⟨0,0,0,100,6⟩ 7 90 0 0 = none ∧
    (Rules.scheduleStop ⟨true,7,10,3⟩ ⟨0,0,0,100,6⟩ 7 89 0 0).isSome = true := by decide +kernel

theorem offset_grid_and_absolute_epoch : Start.onGrid 5 3 8 = true ∧
    Start.onGrid 5 3 6 = false ∧ Start.onGrid 5 3 2 = false ∧
    Start.epochHeight 4 3 = 13 := by decide +kernel

theorem first_anchor_uses_origin : Start.anchorAllowed 8 1 20 8 8 = true ∧
    Start.anchorAllowed 8 2 20 8 8 = false := by decide +kernel

theorem unzen_fence : Start.firstLanding true 5 5 70 80 ⟨4,3,70,true,70,80⟩ = true ∧
    Start.firstLanding true 5 5 70 80 ⟨5,3,70,true,70,80⟩ = false ∧
    Start.firstLanding true 5 5 70 80 ⟨4,3,70,true,70,81⟩ = false := by decide +kernel

theorem cancelling_stop_checks_arithmetic_not_unstored_field_width :
    Rules.scheduleStop ⟨true,7,10,3⟩ ⟨0,0,0,0,0⟩ 7 (Etna.Design.limit48-10) 0 0 =
      some ⟨0,0,0,0,0⟩ := by decide +kernel

end Etna.CurrentRegression

namespace Etna.CurrentRegression
open Etna.Design.Current

def emptyRegistry : Registry.State := ⟨0,fun _ => none,fun _ => none,fun _ => none,1,1⟩
def firstRegistry : Registry.State := ((Registry.register emptyRegistry 11 7 10 1).getD (emptyRegistry,0)).1

theorem bond_zero_is_present : firstRegistry.nextId = 1 ∧ firstRegistry.keyId 11 = some 0 ∧
    firstRegistry.slots 0 = some 0 := by decide +kernel

def displacedBond : Registry.Bond := ⟨⟨11,7,10,2,Etna.Design.Staking.noExit,false,none,3,20⟩,some 0⟩
def fullRegistry : Registry.State := ⟨4096,fun id => if id = 0 then some displacedBond else
    some ⟨⟨100+id,8,100,2,Etna.Design.Staking.noExit,false,none,0,0⟩,some id⟩,
  fun slot => some slot,fun key => if key = 11 then some 0 else none,1,1⟩
def replacement : Registry.State := ((Registry.register fullRegistry 55 9 14 20).getD (emptyRegistry,0)).1

theorem pending_counts_and_ties_keep_low_slot : Registry.admissionSlot fullRegistry = 0 ∧
    Registry.register fullRegistry 55 9 13 20 = none := by decide +kernel

theorem displacement_keeps_liability :
    ((replacement.bonds 0).map (fun b => (b.value.key,b.value.owner,b.value.balance,b.value.exitAt,b.slot))) =
      some (11,7,13,20,none) ∧ replacement.slots 0 = some 4096 ∧ replacement.keyId 11 = some 0 ∧
      replacement.nextId = 4097 := by decide +kernel

def confirmedReplacement : Registry.State :=
  (Registry.confirm replacement true 20 0 21).getD emptyRegistry

theorem init_without_origin_can_confirm_displaced_bond :
    ((confirmedReplacement.bonds 0).map (fun b => b.value.confirmedAt)) = some (some 21) ∧
    Registry.confirm replacement false 20 0 21 = none := by decide +kernel

def withdrawnRegistry : Registry.State :=
  ((Registry.withdraw confirmedReplacement 0 7 31 10).getD (emptyRegistry,0)).1

theorem withdrawn_id_and_replacement_survive :
    ((withdrawnRegistry.bonds 0).map (fun b => (b.value.key,b.value.exitAt,b.value.released))) = some (11,20,true) ∧
    withdrawnRegistry.slots 0 = some 4096 ∧ withdrawnRegistry.keyId 11 = some 0 ∧
    (Registry.exclude withdrawnRegistry 0 11 40).isSome = true ∧
    Registry.exclude withdrawnRegistry 4097 0 40 = none := by decide +kernel

theorem displaced_slash_still_applies :
    (((Registry.slash replacement true true 0 20 1000).getD emptyRegistry).bonds 0).map
      (fun b => b.value.balance) = some 0 := by decide +kernel

theorem recover_number_and_pending_schedule :
    Rules.recover ⟨1,2,100,80,3⟩ 2 = none ∧
    Rules.recover ⟨1,2,100,80,3⟩ 3 = some ⟨3,3,0,0,0⟩ ∧
    Rules.recover ⟨1,2,100,80,3⟩ 0 = some ⟨1,2,100,0,0⟩ := by decide +kernel

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

/-- DATA-5.4-3/5 (#22338): a validator-state preimage that does not hash to s's record value
rejects, before any contradiction; one that does but whose set for s + 1 disagrees with
header(s) halts once the record is finalized; a committee derived from the authenticated
window that disagrees with the preimage halts, but only after the window is available and
authenticated. -/
theorem import_validator_state :
    Import.inspect { candidate with valStateAuthenticated := false } 2 = .reject ∧
    Import.inspect { candidate with valStateAuthenticated := false, nextValidatorsMatch := false } 2 = .reject ∧
    Import.inspect { candidate with nextValidatorsMatch := false } 2 = .halt ∧
    Import.inspect { candidate with nextValidatorsMatch := false, checkpointFinalized := false } 2 = .retry ∧
    Import.inspect { candidate with committeesMatch := false } 2 = .halt ∧
    Import.inspect { candidate with committeesMatch := false, materialAvailable := false } 2 = .retry ∧
    Import.inspect { candidate with committeesMatch := false, metadataAuthenticated := false } 2 = .reject := by
  decide +kernel

/-- A snapshot at the origin itself (s = o). -/
def atOrigin : Import.Candidate := { candidate with height := 5 }

/-- DATA-5.4-1 and vector 5.4 1.b: a snapshot at s = o takes the 8.4 genesis path. Its record
holds 0 at S and the old generation's value at a recovery origin, so the three validator-state
results do not matter there; the envelope and finality checks still apply. One block later,
s = o + 1, the preimage check applies again. -/
theorem import_genesis_path :
    Import.inspect { atOrigin with valStateAuthenticated := false } 2 = .staged ∧
    Import.inspect { atOrigin with nextValidatorsMatch := false } 2 = .staged ∧
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
    Registry.exclude { emptyRegistry with bonds := fun _ => some displacedBond } 0 11 40 = none := by decide +kernel

def tiedRegistry : Registry.State := { fullRegistry with bonds := fun id => some ⟨{ displacedBond.value with key := 100+id },some id⟩ }

theorem equal_value_admission_uses_lowest_slot : Registry.admissionSlot tiedRegistry = 0 := by decide +kernel

theorem field_overflow_and_cancellation :
    Rules.scheduleRules ⟨true,7,10,3⟩ ⟨0,0,0,0,0⟩ 7 0 1 Etna.Design.limit48 = none ∧
    Rules.scheduleRules ⟨true,7,10,3⟩ ⟨0,1,100,0,0⟩ 7 89 1 (Etna.Design.limit48-1) =
      some ⟨0,1,Etna.Design.limit48-1,0,0⟩ := by decide +kernel
end Etna.CurrentRegression
