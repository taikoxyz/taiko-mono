import EtnaProofs.Encoding
import EtnaProofs.Recovery
import EtnaProofs.Signer
import EtnaProofs.Fees
import EtnaProofs.Budget

/-! Reachable positive traces and rejection/counterexample witnesses.
All finite checks use kernel `decide`, never native_decide. -/
namespace Etna.Design.Examples

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

def deployment : Domain := ⟨1,167001,100,200⟩

/-- The committed chain's cut at every height 0..18; the FI cursor steps at multiples of 6. -/
def cutAt (x : Nat) : Cut := ⟨100+x,if x = 0 then 0 else 200+x,x/6⟩
def table : List Cut := (List.range 19).map cutAt
def genesis : Checkpoint := ⟨0,100,0,0,0,0⟩
def initial : State :=
  { domain := deployment,committeeConfig := 500,gridK := 6,generation := 0,
    origin := ⟨0,2,10⟩,origins := [(0,⟨0,2,10⟩)],checkpoint := genesis,records := [genesis],
    head := 0,tail := 3,snapshot := 1,ethBalance := 0,feeAdmissions := 0,forcedETH := 0,swept := 0,
    signals := [⟨0,100,30⟩],epochLen := 3,genesisCutoff := 1,configuration := ⟨10,10,2,3600⟩,
    maxBatchBlocks := 1024,forcedFee := 1,forcedThreshold := 50,protocolFeeRecipient := 99 }

/-- The example state models an Inbox initialized at L1_0 = 2 with genesisCutoff = 1, so
slot 284 starts at 1 (the model has no initialization transition). -/
theorem initial_snapshot_is_genesis_cutoff : initial.snapshot = 1 ∧ initial.snapshot < initial.origin.l1Block := by
  decide

/-- Landings (0, h] at grid points h = 6, 12, 18, all proved from p = 0. -/
def landTo (h : Nat) : LandInput := ⟨0,h,100+h,200+h,300+h,10,h/6,4⟩
def one : LandInput := landTo 6
def two : LandInput := landTo 12
def full : LandInput := landTo 18

/-- A sound dual proof's statement for (0, i.lastHeight] on grid interval k. -/
def certificateK (k : Nat) (i : LandInput) : StatementData :=
  ⟨deployment,0,500,100,0,0,i,999,[111],tableHash k 0 0 i.lastHeight (table.take (i.lastHeight+1))⟩
def environmentK (k : Nat) (i : LandInput) : LandingEnv :=
  ⟨11,999,true,[111],[(.risc0,true),(.sp1,true)],certificateK k i⟩
/-- The honest leaf list: the grid points strictly inside (0, h). -/
def leavesK (k : Nat) (i : LandInput) : List Leaf := gridLeaves k 0 i.lastHeight (table.take (i.lastHeight+1))

/-- The main traces use K = 6. -/
def certificate := certificateK 6
def environment := environmentK 6
def leavesFor := leavesK 6

def afterOne := applyLanding initial one
def afterTwo := applyLanding afterOne two
def afterThree := applyLanding afterTwo full

theorem certificates_certify_table :
    CertifiedTable 6 (certificate one) (table.take 7) ∧ CertifiedTable 6 (certificate two) (table.take 13) ∧
    CertifiedTable 6 (certificate full) table := by decide +kernel

theorem grid_leaf_lists :
    leavesFor one = [] ∧ leavesFor two = [cutLeaf 6 (cutAt 6)] ∧
    leavesFor full = [cutLeaf 6 (cutAt 6),cutLeaf 12 (cutAt 12)] := by decide +kernel

theorem overlapping_landings_from_one_origin :
    land initial one (leavesFor one) (environment one) = some afterOne ∧
    land afterOne two (leavesFor two) (environment two) = some afterTwo ∧
    land afterTwo full (leavesFor full) (environment full) = some afterThree := by decide +kernel

/-- No window choice: the same (0, 18] transaction lands whether c is 0, 6 or 12, so a
competing landing below 18 cannot make it fail. -/
theorem same_transaction_lands_at_any_grid_frontier :
    land initial full (leavesFor full) (environment full) = some (applyLanding initial full) ∧
    land afterOne full (leavesFor full) (environment full) = some (applyLanding afterOne full) ∧
    land afterTwo full (leavesFor full) (environment full) = some afterThree := by decide +kernel

/-- The example trace stays on the grid; a cursor jump of 2 in one block is not certifiable. -/
theorem example_states_on_grid_and_cursor_steps :
    (OnGrid initial ∧ OnGrid afterOne ∧ OnGrid afterThree) ∧
    cursorSteps [⟨100,0,0⟩,⟨101,201,2⟩] = false := by
  unfold OnGrid
  decide +kernel

/-- Three-word records of actual edges; the state root only in SignalService. -/
theorem landing_records_actual_edges :
    afterThree.records.map (fun r => (r.parent,r.height)) = [(12,18),(6,12),(0,6),(0,0)] ∧
    afterThree.signals.getLast? = some ⟨18,118,318⟩ ∧ afterThree.head = 3 ∧ afterThree.snapshot = 4 := by
  decide +kernel

theorem settled_original_target_rejected :
    land afterThree full (leavesFor full) (environment full) = none := by decide +kernel

/-- The leaf at c must equal cutLeaf(c) computed from landings[c]: a wrong Comet hash or a
wrong height inside the leaf is rejected before proof verification. -/
theorem corrupt_frontier_leaf_rejected :
    land afterTwo full [cutLeaf 6 (cutAt 6),cutLeaf 12 ⟨112,999,2⟩] (environment full) = none ∧
    land afterTwo full [cutLeaf 6 (cutAt 6),cutLeaf 13 (cutAt 12)] (environment full) = none := by
  decide +kernel

/-- A corrupted leaf away from c passes the pre-proof checks but not the proof. -/
theorem corrupt_inner_leaf_fails_proof :
    Precheck afterTwo full [cutLeaf 6 ⟨106,999,1⟩,cutLeaf 12 (cutAt 12)] (environment full) ∧
    land afterTwo full [cutLeaf 6 ⟨106,999,1⟩,cutLeaf 12 (cutAt 12)] (environment full) = none := by
  decide +kernel

theorem wrong_leaf_count_and_off_grid_rejected :
    land afterTwo full [cutLeaf 6 (cutAt 6)] (environment full) = none ∧
    land afterTwo full (leavesFor full ++ [cutLeaf 18 (cutAt 18)]) (environment full) = none ∧
    land afterOne { two with lastHeight := 13 } (leavesFor two) (environment two) = none := by decide +kernel

theorem foreign_generation_proof_rejected :
    land { afterTwo with generation := 1,origin := ⟨12,2,90⟩ } full (leavesFor full)
      (environment full) = none := by decide +kernel

/-- The same rules at K = 3, another allowed value: (0, 6] carries the leaf at 3 and lands
from c = 0 and from c = 3. Leaves built for K = 3 do not land on a K = 6 Inbox (the general
statement is `accepted_landing_fixes_guest_k`). -/
theorem k3_same_transaction_lands_at_any_grid_frontier :
    let initial3 := { initial with gridK := 3 }
    let three := landTo 3
    let afterThree3 := applyLanding initial3 three
    leavesK 3 one = [cutLeaf 3 (cutAt 3)] ∧
    land initial3 three (leavesK 3 three) (environmentK 3 three) = some afterThree3 ∧
    land initial3 one (leavesK 3 one) (environmentK 3 one) = some (applyLanding initial3 one) ∧
    land afterThree3 one (leavesK 3 one) (environmentK 3 one) = some (applyLanding afterThree3 one) ∧
    land initial one (leavesK 3 one) (environmentK 3 one) = none := by decide +kernel

/-- 10.1 changing K at an upgrade: after settling to H = 18 on K = 6, switching the Inbox to
K = 4 leaves no landable origin. p = 18 is off the new grid, and from the grid origins 12 and 0
the honest K = 4 leaf at index (18−p)/4 − 1 is the cut at 16, not 18, so the check at c = 18
fails. -/
theorem k_change_at_upgrade_deadlocks :
    let switched := { afterThree with gridK := 4 }
    let fromEighteen : LandInput := ⟨18,20,120,220,320,10,3,4⟩
    let fromTwelve : LandInput := ⟨12,20,120,220,320,10,3,4⟩
    let fromZero : LandInput := ⟨0,20,120,220,320,10,3,4⟩
    land switched fromEighteen [] (environmentK 4 fromEighteen) = none ∧
    land switched fromTwelve [cutLeaf 16 (cutAt 16)] (environmentK 4 fromTwelve) = none ∧
    land switched fromZero ((List.range 4).map fun j => cutLeaf (4*(j+1)) (cutAt (4*(j+1))))
      (environmentK 4 fromZero) = none := by decide +kernel

/-- The contract stores the proven snapshot as is: monotonicity of slot 284 comes from
sound committee derivation, not from an on-chain max. -/
theorem snapshot_stored_as_proven :
    let i := { full with activeCommitteeSnapshot := 2 }
    let e := { environment full with certificate := { certificate full with input := i } }
    let s := { afterTwo with snapshot := 4 }
    land s i (leavesFor full) e = some (applyLanding s i) ∧ (applyLanding s i).snapshot = 2 := by
  decide +kernel

def alice : Committee.Entry := ⟨1,100,1,1000⟩
def bob : Committee.Entry := ⟨2,200,1,1000⟩
def exited : Committee.Entry := ⟨3,10000,1,5⟩
def active : Committee.Record := ⟨0,1,[alice]⟩
def pending : Committee.Record := ⟨1,2,[bob]⟩

theorem election_stake_order_and_exit :
    Committee.chosen 10 10 5 1 [alice,exited,bob] = [bob] := by
  simp [Committee.chosen,Committee.eligible,Committee.rank,alice,bob,exited]

theorem election_tie_key_order :
    Committee.chosen 10 10 5 1 [alice,{ bob with stake := 100 }] = [alice] := by
  simp [Committee.chosen,Committee.eligible,Committee.rank,alice,bob]

/-- K ≤ U ≤ 65,536 with U a multiple of K, and 1 ≤ K ≤ 6. -/
theorem config_u_range :
    Committee.configOK 6 3 6 = true ∧ Committee.configOK 6 3 3600 = true ∧
    Committee.configOK 6 3 65532 = true ∧ Committee.configOK 6 3 65536 = false ∧
    Committee.configOK 4 3 65536 = true ∧ Committee.configOK 1 3 1 = true ∧
    Committee.configOK 6 3 3601 = false ∧ Committee.configOK 6 3 1 = false ∧
    Committee.configOK 7 3 3605 = false ∧ Committee.configOK 0 3 3600 = false := by decide +kernel

theorem new_witness_uses_switch_root :
    Committee.witnessOK 7 9 400 ⟨400,9⟩ ∧ ¬Committee.witnessOK 7 9 400 ⟨300,9⟩ := by
  simp [Committee.witnessOK,Committee.normalCutoff]

/-- §3.4 rule 3 after a recovery at R = 11 on top of c whose anchor was 5: the first
anchor must be at least 11; c's own anchor no longer matters. -/
theorem anchor_floor_is_generation_origin :
    Committee.anchorOK 5 11 11 = true ∧ Committee.anchorOK 5 11 10 = false ∧
    Committee.anchorOK 12 11 11 = false ∧ Committee.anchorChain 11 5 [11,11,14] = true ∧
    Committee.anchorChain 11 5 [11,10] = false := by decide +kernel

theorem proposer_fee_routing :
    Fees.extraData 100 5 7 = [100,0,0,0,0,0,5,0,0,0,0,0,7] ∧
    Fees.blockCredits 100 25 [⟨41,2,21000⟩,⟨7,1,50000⟩] = (27*21000+26*50000,0) := by decide +kernel

def bond : Staking.Bond := ⟨1,51,100,0,5,false,none⟩
def settledInbox : State := { afterThree with snapshot := 6 }
def confirmedBond : Staking.Bond := { bond with confirmedAt := some 100 }
def cleared : Staking.Bond := ⟨0,0,0,0,0,true,none⟩

theorem confirmation_starts_new_timer :
    Staking.confirmExit settledInbox bond 100 = some confirmedBond ∧
    Staking.withdraw settledInbox confirmedBond 51 109 10 = none ∧
    Staking.withdraw settledInbox confirmedBond 51 110 10 = some (cleared,100) ∧
    Staking.withdraw settledInbox confirmedBond 52 110 10 = none := by decide +kernel

theorem reconfirmation_does_not_reset_timer :
    Staking.confirmExit settledInbox confirmedBond 999 = some confirmedBond := by decide +kernel

theorem uncovered_or_preinit_exit_cannot_confirm :
    Staking.confirmExit { settledInbox with snapshot := 4 } bond 100 = none ∧
    Staking.confirmExit { settledInbox with origins := [] } bond 100 = none ∧
    Staking.confirmExit settledInbox { bond with exitAt := Staking.noExit } 100 = none := by decide +kernel

theorem zero_stake_still_waits :
    Staking.withdraw settledInbox { bond with stake := 0 } 999 1000 10 = none ∧
    Staking.withdraw settledInbox { confirmedBond with stake := 0 } 999 109 10 = none ∧
    Staking.withdraw settledInbox { confirmedBond with stake := 0 } 999 110 10 = some (cleared,0) := by
  decide +kernel

/-- The released slot has no confirmation; a new occupant starts unconfirmed and cannot
withdraw on the old occupant's timer. -/
theorem slot_reuse_starts_fresh :
    Staking.register cleared 7 52 200 200 5 = some ⟨7,52,200,205,Staking.noExit,false,none⟩ ∧
    Staking.withdraw settledInbox ⟨7,52,200,205,Staking.noExit,false,none⟩ 52 10000 10 = none ∧
    Staking.register bond 7 52 200 200 5 = none := by decide +kernel

theorem exit_request_rules :
    let fresh : Staking.Bond := ⟨1,51,100,40,Staking.noExit,false,none⟩
    Staking.requestExit fresh 51 30 20 = some { fresh with exitAt := 60 } ∧
    Staking.requestExit fresh 52 30 20 = none ∧
    Staking.requestExit { fresh with exitAt := 60 } 51 30 20 = none ∧
    Staking.requestExit (Staking.exclude fresh 11) 51 30 20 = none := by decide +kernel

theorem double_sign_then_release :
    Staking.slashDouble settledInbox bond 3 1000 =
      some ({ bond with stake := 0,exitAt := 3 },10,90) ∧
    Staking.slashDouble { settledInbox with origins := [] } bond 3 1000 = none := by decide +kernel

/-- §8 rollback re-checks against the restored snapshot, not block numbers. A trusted
landing (c = 1, snapshot 4) and an untrusted one (verifier failure: snapshot 9 is not the
real cutoff) land in the same L1 block 11. A confirmation in block 11 is possible only
because of the untrusted snapshot. A block-number rule ("later than the last trusted
landing") would keep it, and withdrawal does not re-read the snapshot; the spec's re-check
against the restored snapshot 4 clears it. -/
theorem rollback_compares_snapshots_not_blocks :
    let bad := { two with activeCommitteeSnapshot := 9 }
    let badEnv := { environment two with certificate := { certificate two with input := bad } }
    let exiting : Staking.Bond := ⟨1,51,100,0,6,false,none⟩
    let confirmed := { exiting with confirmedAt := some 11 }
    (environment one).blockNumber = 11 ∧ badEnv.blockNumber = 11 ∧
    land afterOne bad (leavesFor two) badEnv = some (applyLanding afterOne bad) ∧
    Staking.confirmExit afterOne exiting 11 = none ∧
    Staking.confirmExit (applyLanding afterOne bad) exiting 11 = some confirmed ∧
    Staking.rollbackAfter 11 confirmed = confirmed ∧
    Staking.withdraw afterOne confirmed 51 21 10 = some (cleared,100) ∧
    (Staking.rollbackBySnapshot afterOne.snapshot confirmed).confirmedAt = none ∧
    Staking.rollbackBySnapshot afterOne.snapshot { confirmed with exitAt := 3 } =
      { confirmed with exitAt := 3 } := by decide +kernel

def world : Recovery.World :=
  ⟨initial,[(0,alice),(1,bob)],[(0,⟨123,20,2⟩),(1,⟨124,21,3⟩),(2,⟨125,22,4⟩)],⟨active,some (3,pending)⟩⟩
def cfg : Recovery.Config := ⟨77,88⟩
def request : Recovery.Request := ⟨0,0,[],[]⟩
def origin : Origin := ⟨0,11,61⟩
def recovered : Recovery.World := Recovery.applyRecovery world request cfg origin

/-- No time threshold: the owner can execute as soon as the expected values match; only
the DAO's own authorization path delays it. -/
theorem recover_needs_owner_and_expected_values :
    Recovery.recover world request cfg origin true true = some recovered ∧
    Recovery.recover world request cfg origin false true = none ∧
    Recovery.recover world { request with generation := 1 } cfg origin true true = none :=
  ⟨Recovery.recover_of_allowed (by decide +kernel),by decide +kernel,by decide +kernel⟩

theorem landing_voids_old_authorization :
    Recovery.recover { world with inbox := afterOne } request cfg origin true true = none := by decide +kernel

theorem repeated_recovery_at_same_c_needs_new_generation :
    Recovery.recover recovered request cfg ⟨0,12,62⟩ true true = none ∧
    (Recovery.recover recovered { request with generation := 1 } cfg ⟨0,12,62⟩ true true).isSome = true := by
  decide +kernel

def excludeBob : Recovery.Request := { request with exclusions := [⟨1,2⟩],fiToClear := [0] }

/-- Exclusion is a forced exit only: bob's stake stays 200, his exit moves to R = 11. -/
theorem exclusion_and_fi_clear_atomic :
    let t := Recovery.applyRecovery world excludeBob cfg origin
    Recovery.recover world excludeBob cfg origin true true = some t ∧
    t.registry = [(0,alice),(1,{ bob with exitAt := 11 })] ∧
    t.queue = [(0,⟨77,20,2⟩),(1,⟨124,21,3⟩),(2,⟨125,22,4⟩)] ∧
    t.schedule.pending = none :=
  ⟨Recovery.recover_of_allowed (by decide +kernel),by decide +kernel,by decide +kernel,rfl⟩

/-- Released slots (all zero, same zero key) do not trip the duplicate-key rule. -/
theorem released_slots_do_not_block_election :
    Recovery.selection { world with registry := world.registry ++ [(2,⟨88,0,0,0⟩),(3,⟨88,0,0,0⟩)] }
      request origin = some [alice,bob] := by
  simp [Recovery.selection,Recovery.excludedRegistry,Recovery.exclusionApplies,Committee.election,
    Committee.chosen,Committee.eligible,Committee.rank,Committee.totalPower,Committee.power,
    world,initial,request,origin,alice,bob,Committee.maxPower]

theorem exclusion_removes_from_recovery_committee :
    Recovery.selection world excludeBob origin = some [alice] := by
  simp [Recovery.selection,Recovery.excludedRegistry,Recovery.exclusionApplies,Committee.election,
    Committee.chosen,Committee.eligible,Committee.totalPower,Committee.power,
    excludeBob,world,initial,request,origin,alice,bob,Committee.maxPower]

theorem released_slot_exclusion_rejected :
    Recovery.recover { world with registry := world.registry ++ [(2,⟨88,0,0,0⟩)] }
      { request with exclusions := [⟨2,88⟩] } cfg origin true true = none := by decide +kernel

theorem stale_exclusion_identity_rejected :
    Recovery.recover world { request with exclusions := [⟨1,999⟩] } cfg origin true true = none := by decide +kernel

/-- The Inbox does not check the R election (a DAO pre-authorization check): excluding
everyone still executes, leaving a generation with no starting committee until another
recovery at the same c. -/
def excludeAll : Recovery.Request := { request with exclusions := [⟨0,1⟩,⟨1,2⟩] }

theorem empty_election_is_not_an_inbox_check :
    let t := Recovery.applyRecovery world excludeAll cfg origin
    Recovery.recover world excludeAll cfg origin true true = some t ∧
    Recovery.selection world excludeAll origin = none ∧
    (Recovery.recover t { request with generation := 1 } cfg ⟨0,12,62⟩ true true).isSome = true := by
  refine ⟨Recovery.recover_of_allowed (by decide +kernel),?_,by decide +kernel⟩
  simp [Recovery.selection,Recovery.excludedRegistry,Recovery.exclusionApplies,Committee.election,
    Committee.chosen,Committee.eligible,excludeAll,world,initial,request,origin,alice,bob]

def exitWorld : Recovery.World :=
  { world with registry := [(0,alice),(1,bob),(2,exited)],inbox := { initial with snapshot := 6 } }

/-- A confirmed exit (exitAt 5 ≤ landed snapshot 6 < R = 11) is never re-selected, even
with the largest stake and without being listed. -/
theorem confirmed_exit_skipped_at_r :
    Recovery.selection exitWorld request origin = some [alice,bob] := by
  simp [Recovery.selection,Recovery.excludedRegistry,Recovery.exclusionApplies,Committee.election,
    Committee.chosen,Committee.eligible,Committee.rank,Committee.totalPower,Committee.power,
    exitWorld,world,initial,request,origin,alice,bob,exited,Committee.maxPower]

/-- §8 rollback after a recovery executed on a forged checkpoint: landing (6,12] was
untrusted and a recovery ran at c = 12 (generation 1, origin height 12). Restoring c = 6 keeps
generation 1, voids record 12 and its SignalService checkpoint, blocks landing (origin above c),
and a new recovery from c = 6 into generation 2 is allowed. -/
theorem rollback_then_recover_again :
    let forged := (Recovery.applyRecovery { world with inbox := afterTwo } ⟨0,12,[],[]⟩ cfg ⟨12,12,62⟩).inbox
    let rolled := Recovery.rollbackInbox forged afterOne.checkpoint 4
    forged.generation = 1 ∧ rolled.generation = 1 ∧
    rolled.records.map (·.height) = [6,0] ∧ rolled.signals.map (·.height) = [0,6] ∧
    land rolled one (leavesFor one) (environment one) = none ∧
    (Recovery.recover { world with inbox := rolled } ⟨1,6,[],[]⟩ cfg ⟨6,13,63⟩ true true).isSome = true := by
  decide +kernel

/-- §8 rollback target. Landing (0,6] passes a broken verifier with honest hashes and FI
cursor but an inflated snapshot 9. The honest landing (0,12] still lands (the leaf check at
c = 6 passes) and writes the honest snapshot 4, so the 8.1 pre-check at c = 12 sees a consistent
landing and a recovery runs there. Rolling back to the last landing before the first bad one
(block 0) voids the honest record 12 and leaves generation 1 unable to land, forcing a recovery
from 0 that discards (0, 12]. Repairing at the honest landing 12 keeps every record and the
generation's origin. -/
theorem rollback_before_first_bad_discards_honest_settlement :
    let bad := { one with activeCommitteeSnapshot := 9 }
    let badEnv := { environment one with certificate := { certificate one with input := bad } }
    let afterBad := applyLanding initial bad
    let afterHonest := applyLanding afterBad two
    let recovered := (Recovery.applyRecovery { world with inbox := afterHonest } ⟨0,12,[],[]⟩ cfg ⟨12,12,62⟩).inbox
    land initial bad (leavesFor one) badEnv = some afterBad ∧
    land afterBad two (leavesFor two) (environment two) = some afterHonest ∧
    afterBad.snapshot = 9 ∧ afterHonest.snapshot = 4 ∧
    (Recovery.rollbackInbox recovered genesis 1).records.map (·.height) = [0] ∧
    (Recovery.rollbackInbox recovered genesis 1).checkpoint.height < recovered.origin.height ∧
    (Recovery.rollbackInbox recovered afterHonest.checkpoint 4).records.map (·.height) = [12,6,0] ∧
    recovered.origin.height ≤ (Recovery.rollbackInbox recovered afterHonest.checkpoint 4).checkpoint.height := by
  decide +kernel

theorem cleared_pending_does_not_activate_at_old_height :
    Committee.authority recovered.schedule 3 = recovered.schedule.current := rfl

theorem recovery_first_switch_still_h_plus_two :
    let s := Committee.announce recovered.schedule 2 pending
    Committee.authority s 2 = recovered.schedule.current ∧
    Committee.authority s 3 = recovered.schedule.current ∧ Committee.authority s 4 = pending :=
  ⟨rfl,rfl,rfl⟩

theorem missing_origin_record_refused :
    Recovery.bootstrap { afterThree with records := [afterThree.checkpoint] } active = none := by decide +kernel

theorem bootstrap_uses_fixed_origin_not_latest_checkpoint :
    (Recovery.bootstrap afterThree active).map Recovery.Bootstrap.appHash = some 100 := by decide +kernel

def signing : Signer.State := ⟨deployment,0,1,[],true,[⟨0,⟨20,1,2⟩,55,66⟩]⟩
def signingRequest : Signer.Request := ⟨deployment,0,true,⟨20,1,2⟩,55⟩
def switched : Signer.State := Signer.switchDomain signing deployment 1 1 true true

theorem signer_retry_and_conflict :
    Signer.sign signing signingRequest 99 false = some (signing,66) ∧
    Signer.sign signing { signingRequest with bytes := 56 } 99 true = none := by decide +kernel

theorem retired_signer_and_pre_start_denied :
    Signer.sign switched signingRequest 99 true = none ∧
    Signer.sign (Signer.openSession switched 1 true true)
      { signingRequest with generation := 1,position := ⟨0,0,1⟩ } 99 true = none := by decide +kernel

theorem new_domain_can_start_below_old_highest_hrs :
    let s := Signer.openSession switched 1 true true
    (Signer.sign s { signingRequest with generation := 1,position := ⟨1,0,1⟩ } 99 true).isSome = true ∧
    s.log = signing.log := by decide +kernel

theorem unpersisted_switch_stays_closed :
    (Signer.switchDomain signing deployment 1 1 true false).ready = false := by decide +kernel

def forcedWitness : Forced.Witness :=
  ⟨0,⟨123,20,2⟩,true,123,100,true,none,false,0⟩

theorem fi_transient_failure_is_waiting :
    Forced.step 0 1 30 10 (some forcedWitness) .unavailable = .waiting := by decide +kernel

theorem fi_completed_empty_consumes_only_head :
    Forced.step 0 1 30 10 (some forcedWitness) .completedEmpty = .accepted 1 ∧
    Forced.step 0 1 30 10 (some { forcedWitness with index := 1 }) .completedEmpty = .rejected := by decide +kernel

theorem fi_due_executable_transaction_cannot_be_omitted :
    Forced.step 0 1 30 10 (some forcedWitness) .completedRetained = .rejected := by decide +kernel

theorem fi_included_before_due :
    Forced.step 0 1 20 10 (some { forcedWitness with
      firstHash := some 123,firstCanonical := true,firstBytes := 100 }) .unavailable = .accepted 1 := by decide +kernel

/-- A recovery-cleared entry: skipped once due with no EL build, waits before. -/
theorem fi_cleared_entry :
    let w : Forced.Witness := ⟨0,⟨77,20,2⟩,true,77,0,false,none,false,0⟩
    Forced.step 0 1 30 10 (some w) .unavailable = .accepted 1 ∧
    Forced.step 0 1 29 10 (some w) .unavailable = .accepted 0 := by decide +kernel

def fee : Nat := Forced.admissionFee 1 50 3
def funded : State := { initial with tail := 4,feeAdmissions := fee,ethBalance := fee }

/-- The fee and threshold are the Inbox's immutables: a deployment with a doubled fee charges
more for the same queue, and no call argument can lower it. -/
theorem fi_admission_refund_failure_atomic :
    Forced.enqueue initial 100 (fee+1) false = none ∧
    Forced.enqueue initial 100 fee true = some funded ∧
    Forced.enqueue { initial with forcedFee := 2 } 100 fee true = none := by decide +kernel

theorem protocol_fee_is_preserved_by_landing :
    land funded one (leavesFor one) (environment one) = some (applyLanding funded one) ∧
    (applyLanding funded one).ethBalance = fee := by decide +kernel

/-- Anyone can sweep; the whole balance (FI fees plus 5 wei forced in) goes to the Inbox's
fixed recipient; a deployment with a zero recipient or a failed transfer reverts. -/
theorem sweep_whole_balance :
    let s := Forced.extraETH funded 5
    Forced.sweep s true = some { s with ethBalance := 0,swept := fee+5 } ∧
    Forced.sweep { s with protocolFeeRecipient := 0 } true = none ∧ Forced.sweep s false = none := by decide +kernel

/-- Checklist example: 900 entries at base 0.01 ETH (10^7 gwei), threshold 50, head fixed. -/
theorem fi_backlog_example_cost :
    ((List.range 900).map (Forced.admissionFee 10000000 50)).sum = 8991 * 10^16 := by decide +kernel

theorem dual_proof_shape_rejects_single_sgx_or_duplicate_backend :
    dualOK [(.sgx,true)] = false ∧ dualOK [(.sgx,true),(.sgx,true)] = false ∧
    dualOK [(.risc0,true),(.risc0,true)] = false ∧ dualOK [(.sgx,true),(.sp1,true)] = true := by decide +kernel

theorem backpressure_boundary :
    Committee.backPressure 3599 0 3600 = true ∧ Committee.backPressure 3600 0 3600 = true ∧
    Committee.backPressure 3601 0 3600 = false := by decide +kernel

theorem fi_unexpired_nonempty_wrong_hash_rejected :
    Forced.step 0 1 20 10 (some { forcedWitness with rawHash := 999 }) .unavailable = .rejected := by decide +kernel

theorem fi_included_nonempty_wrong_hash_rejected :
    Forced.step 0 1 20 10 (some { forcedWitness with
      rawHash := 999,firstHash := some 123,firstCanonical := true,firstBytes := 100 }) .unavailable = .rejected := by decide +kernel

end Etna.Design.Examples
