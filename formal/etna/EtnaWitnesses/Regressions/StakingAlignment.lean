import EtnaProofs.RegistryHistory

/-! SPEC 4.1 and 4.4 lifecycle and ordering regressions. Principal expectations are
hand-computed, and timestamp expiry is tested independently from block readiness. -/
namespace Etna.Design.StakingAlignment

def inbox : State :=
  { domain := ⟨1,2,3,4⟩,committeeConfig := 0,gridK := 1,generation := 0,
    origin := ⟨0,1,1⟩,origins := [(0,⟨0,1,1⟩)],checkpoint := default,records := [],
    head := 0,tail := 0,snapshot := 100,ethBalance := 0,feeAdmissions := 0,
    forcedETH := 0,swept := 0,signals := [] }

def bond : Staking.Bond := ⟨7,9,100,10,Staking.noExit,false,none,0,0⟩
def pending : Staking.Bond := { bond with pendingTopUp := 21,topUpReadyAtL1 := 30 }
def confirmedPending : Staking.Bond :=
  { pending with stake := 0,exitAt := 20,confirmedAt := some 25 }
def registry : RegistryHistory.State :=
  { nextId := 1,free := [],slots := fun _ => bond,usedKeys := [7],
    history := [⟨10,[Staking.toEntry bond]⟩],activationDelay := 10,withdrawalDelay := 5 }

theorem deposit_before_inbox_init :
    Staking.topUp { inbox with origins := [] } bond 9 21 20 10 = some pending := by decide +kernel

theorem deposit_guards :
    Staking.topUp inbox bond 8 21 20 10 = none ∧
    Staking.topUp inbox bond 9 0 20 10 = none ∧
    Staking.topUp inbox bond 9 21 9 10 = none ∧
    Staking.topUp inbox pending 9 1 20 10 = none ∧
    Staking.topUp inbox { bond with stake := 0 } 9 21 20 10 = none ∧
    Staking.topUp inbox { bond with exitAt := 40 } 9 21 20 10 = none ∧
    Staking.topUp { inbox with entered := true } bond 9 21 20 10 = none := by decide +kernel

theorem deposit_rejects_overflow :
    Staking.topUp inbox bond 9 (limit256-100) 20 10 = none ∧
    Staking.topUp inbox bond 9 21 (limit48-10) 10 = none := by decide +kernel

theorem explicit_activation_boundary :
    Staking.activateTopUp inbox pending 29 = none ∧
    Staking.activateTopUp { inbox with origins := [] } pending 30 =
      some { bond with stake := 121 } ∧
    Staking.activateTopUp inbox { pending with exitAt := 40 } 30 = none := by decide +kernel

theorem pending_only_owner_withdrawal :
    Staking.withdraw inbox confirmedPending 8 30 5 = none ∧
    Staking.withdraw inbox confirmedPending 9 30 5 =
      some (⟨0,0,0,0,0,true,none,0,0⟩,21) := by decide +kernel

theorem pending_only_double_sign_liability :
    Staking.slashDouble inbox confirmedPending 30 1000 =
      some ({ confirmedPending with pendingTopUp := 0,topUpReadyAtL1 := 0 },2,19) := by decide +kernel

theorem ceiling_forfeit_preserves_confirmation :
    Staking.forfeit inbox { pending with confirmedAt := some 12 } 7 20 100 100 1000 true true true =
      some ({ pending with stake := 87,exitAt := 20,confirmedAt := some 12 },13) := by decide +kernel

theorem forfeit_spills_into_pending :
    Staking.forfeit inbox { pending with stake := 1 } 7 20 100 100 1000 true true true =
      some ({ pending with stake := 0,pendingTopUp := 19,exitAt := 20 },3) ∧
    Staking.forfeit inbox pending 7 20 100 100 10000 true true true =
      some ({ pending with stake := 0,pendingTopUp := 0,topUpReadyAtL1 := 0,exitAt := 20 },121) := by decide +kernel

theorem forfeit_guards_and_atomicity :
    Staking.forfeit inbox pending 8 20 100 100 1000 true true true = none ∧
    Staking.forfeit inbox pending 7 20 101 100 1000 true true true = none ∧
    Staking.forfeit inbox pending 7 20 100 100 0 true true true = none ∧
    Staking.forfeit inbox pending 7 20 100 100 10001 true true true = none ∧
    Staking.forfeit inbox pending 7 20 100 100 1000 false true true = none ∧
    Staking.forfeit inbox pending 7 20 100 100 1000 true false true = none ∧
    Staking.forfeit inbox pending 7 20 100 100 1000 true true false = none ∧
    Staking.forfeit { inbox with origins := [] } pending 7 20 100 100 1000 true true true = none ∧
    Staking.forfeit { inbox with entered := true } pending 7 20 100 100 1000 true true true = none := by decide +kernel

def deposited : RegistryHistory.State :=
  (RegistryHistory.edit registry { inbox with origins := [] } 0 20 (.topUp 9 21)).getD registry
def activated : RegistryHistory.State :=
  (RegistryHistory.edit deposited inbox 0 30 .activateTopUp).getD deposited

theorem deposit_and_maturity_do_not_checkpoint :
    (RegistryHistory.edit registry { inbox with origins := [] } 0 20 (.topUp 9 21)).isSome = true ∧
    deposited.history = registry.history ∧ (deposited.slots 0).stake = 100 ∧
    (deposited.slots 0).pendingTopUp = 21 ∧
    RegistryHistory.entries deposited = RegistryHistory.entries registry ∧
    RegistryHistory.edit deposited inbox 0 29 .activateTopUp = none := by decide +kernel

theorem activation_writes_only_current_history :
    (RegistryHistory.edit deposited inbox 0 30 .activateTopUp).isSome = true ∧
    (activated.slots 0).stake = 121 ∧ (activated.slots 0).pendingTopUp = 0 ∧
    (activated.history.head?).map RegistryHistory.Snapshot.block = some 30 ∧
    RegistryHistory.latestSnapshot activated.history 29 = some ⟨10,[Staking.toEntry bond]⟩ ∧
    Committee.power 1 (Staking.toEntry (deposited.slots 0)) = 100 := by decide +kernel

theorem full_registry_still_accepts_top_up :
    (RegistryHistory.edit { registry with nextId := 4096 } inbox 4095 20 (.topUp 9 21)).isSome = true := by
  decide +kernel

def punishable : RegistryHistory.State :=
  { registry with
    slots := fun _ => { pending with exitAt := 20,confirmedAt := some 25 }
    history := [⟨20,[Staking.toEntry { pending with exitAt := 20 }]⟩] }
def forfeited : RegistryHistory.State :=
  (RegistryHistory.edit punishable inbox 0 30 (.forfeit 7 55 100 100 true true)).getD punishable
def withdrawn : RegistryHistory.State :=
  (RegistryHistory.edit forfeited inbox 0 30 (.withdraw 9)).getD forfeited
def reused : RegistryHistory.State :=
  (RegistryHistory.register withdrawn 8 9 100 31).getD withdrawn

theorem forfeit_then_withdraw_keeps_lifetime_flag :
    (RegistryHistory.edit punishable inbox 0 30 (.forfeit 7 55 100 100 true true)).isSome = true ∧
    (forfeited.slots 0).balance = 108 ∧ (forfeited.slots 0).confirmedAt = some 25 ∧
    (forfeited.slots 0).exitAt = 20 ∧ forfeited.forfeited = [7] ∧
    (RegistryHistory.edit forfeited inbox 0 30 (.withdraw 9)).isSome = true ∧
    (withdrawn.slots 0).released = true ∧ (withdrawn.slots 0).balance = 0 ∧
    withdrawn.forfeited = [7] ∧
    (RegistryHistory.register withdrawn 8 9 100 31).isSome = true ∧
    (reused.slots 0).key = 8 ∧ reused.forfeited = [7] ∧
    RegistryHistory.edit reused inbox 0 32 (.forfeit 7 55 100 100 true true) = none := by decide +kernel

theorem forfeit_replay_expiry_effect_failure_are_atomic :
    RegistryHistory.edit forfeited inbox 0 30 (.forfeit 7 56 100 100 true true) = none ∧
    RegistryHistory.edit punishable inbox 0 30 (.forfeit 7 55 100 101 true true) = none ∧
    RegistryHistory.edit punishable inbox 0 30 (.forfeit 7 55 100 100 true false) = none ∧
    punishable.forfeited = [] ∧ (punishable.slots 0).balance = 121 ∧
    (punishable.slots 0).confirmedAt = some 25 := by decide +kernel

def releasedFirst : RegistryHistory.State :=
  (RegistryHistory.edit punishable inbox 0 30 (.withdraw 9)).getD punishable
def doubleVote (blockId : Hash) : Staking.Vote := ⟨inbox.domain,0,1,0,2,blockId⟩
def slashable : RegistryHistory.State := { punishable with verify := fun _ _ _ => true }
def slashedFirst : RegistryHistory.State :=
  (RegistryHistory.edit slashable inbox 0 30 (.slash (doubleVote 1) (doubleVote 2) 0 0)).getD slashable

theorem withdrawal_or_double_sign_first_blocks_forfeit :
    (RegistryHistory.edit punishable inbox 0 30 (.withdraw 9)).isSome = true ∧
    RegistryHistory.edit releasedFirst inbox 0 30 (.forfeit 7 55 100 100 true true) = none ∧
    (RegistryHistory.edit slashable inbox 0 30 (.slash (doubleVote 1) (doubleVote 2) 0 0)).isSome = true ∧
    (slashedFirst.slots 0).balance = 0 ∧
    RegistryHistory.edit slashedFirst inbox 0 30 (.forfeit 7 55 100 100 true true) = none ∧
    (RegistryHistory.edit slashedFirst inbox 0 30 (.withdraw 8)).isSome = true := by decide +kernel

theorem old_double_sign_evidence_survives_deposit_and_forfeit :
    (RegistryHistory.edit { deposited with verify := fun _ _ _ => true } inbox 0 30
      (.slash (doubleVote 1) (doubleVote 2) 0 0)).map (fun s => (s.slots 0).balance) = some 0 ∧
    (RegistryHistory.edit { forfeited with verify := fun _ _ _ => true } { inbox with generation := 2 } 0 30
      (.slash (doubleVote 1) (doubleVote 2) 0 0)).map (fun s => (s.slots 0).balance) = some 0 := by decide +kernel

theorem recovery_and_rollback_preserve_principal_and_flag :
    ((RegistryHistory.forceExclusions deposited [⟨0,7⟩] 25).slots 0).balance = 121 ∧
    ((RegistryHistory.forceExclusions forfeited [⟨0,7⟩] 31).slots 0).balance = 108 ∧
    (RegistryHistory.forceExclusions forfeited [⟨0,7⟩] 31).forfeited = [7] ∧
    (RegistryHistory.recheckAll forfeited 0).forfeited = [7] ∧
    ((RegistryHistory.recheckAll forfeited 0).slots 0).balance = 108 ∧
    RegistryHistory.edit (RegistryHistory.recheckAll forfeited 0) inbox 0 31
      (.forfeit 7 99 100 100 true true) = none := by decide +kernel

theorem same_incident_different_entries :
    (RegistryHistory.edit { registry with
      nextId := 2
      slots := fun i => { bond with key := i+7 }
      forfeited := [7] } inbox 1 20 (.forfeit 8 55 100 100 true true)).isSome = true := by decide +kernel

theorem registry_reentrancy_blocks_every_action (action : RegistryHistory.Edit) :
    RegistryHistory.edit registry { inbox with entered := true } 0 20 action = none :=
  RegistryHistory.edit_rejects_reentrancy _ _ _ _ _ rfl

theorem authorization_counts_later_deposit :
    (Staking.forfeit inbox bond 7 30 100 100 1000 true true true).map Prod.snd = some 10 ∧
    (Staking.forfeit inbox (deposited.slots 0) 7 30 100 100 1000 true true true).map Prod.snd = some 13 := by
  decide +kernel

theorem recovery_first_does_not_invalidate_forfeiture :
    (RegistryHistory.edit (RegistryHistory.forceExclusions deposited [⟨0,7⟩] 25)
      { inbox with generation := 2 } 0 30 (.forfeit 7 55 100 100 true true)).map
      (fun s => ((s.slots 0).balance,(s.slots 0).exitAt,s.forfeited)) = some (108,25,[7]) := by
  decide +kernel

end Etna.Design.StakingAlignment
