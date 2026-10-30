import EtnaProofs.ProtocolState

/-! Registry-visible lifecycle facts on the combined machine: the Inbox initialization
state the registry reads never reverts, and the section 8 rollback keeps a confirmation
exactly when the restored snapshot covers the exit. -/
namespace Etna.Design.Lifecycle
open ProtocolState

/-- Once initialized, the Inbox stays initialized on every combined trace, including
recovery and exceptional rollback: the generation-0 origin record is never removed. -/
theorem trace_keeps_inbox_initialized {w t : ProtocolState.World} (trace : ProtocolState.Trace w t)
    (initialized : Staking.inboxInitialized w.inbox = true) : Staking.inboxInitialized t.inbox = true := by
  obtain ⟨extra,origins⟩ := trace_keeps_origin_archive trace
  simp only [Staking.inboxInitialized,origins,List.any_append,Bool.or_eq_true] at initialized ⊢
  exact Or.inl initialized

/-- Exact §8 re-check: every slot is unchanged when the restored snapshot covers its exit
and otherwise loses only its confirmation. -/
theorem rollback_confirmation_exact (w : ProtocolState.World) (trusted : Checkpoint) (snapshot now id : Nat) :
    (ProtocolState.applyRollback w trusted snapshot now).registry.slots id =
      if (w.registry.slots id).exitAt ≤ snapshot then w.registry.slots id
      else { w.registry.slots id with confirmedAt := none } := by
  simp only [applyRollback,RegistryHistory.recheckAll,Staking.rollbackBySnapshot]
  split
  · split
    · rw [ite_eq_right (by omega)]
    · rw [ite_eq_left (by omega)]
  · split
    · rfl
    · cases slot : w.registry.slots id
      simp_all

/-- Converse of `rollback_rechecks_confirmations`: a confirmation covered by the restored
snapshot survives the rollback unchanged. -/
theorem rollback_keeps_covered_confirmation (w : ProtocolState.World) (trusted : Checkpoint) (snapshot now id atL1 : Nat)
    (confirmed : (w.registry.slots id).confirmedAt = some atL1) (covered : (w.registry.slots id).exitAt ≤ snapshot) :
    ((ProtocolState.applyRollback w trusted snapshot now).registry.slots id).confirmedAt = some atL1 := by
  rw [rollback_confirmation_exact,ite_eq_left covered]
  exact confirmed

end Etna.Design.Lifecycle
