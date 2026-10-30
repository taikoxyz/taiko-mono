import EtnaProofs.BackPressure

/-! The settled prefix stays: along every trace without verifier-failure rollback, the records
at or below the starting lastCheckpoint never change and SignalService checkpoints are only
appended. Section 1 promises that nothing at or below a checkpoint is rolled back except by a
DAO upgrade after verifier failure; this is the Inbox side of that promise for every step other
than that rollback. -/
namespace Etna.Design.ProtocolState

/-- A step other than verifier-failure rollback keeps every record at or below its starting
lastCheckpoint: a landing writes only above it, and no other transaction touches the records. -/
theorem ordinary_step_preserves_settled_records {w t : World} (change : OrdinaryStep w t)
    (h : Nat) (old : h ≤ w.inbox.checkpoint.height) : recordAt t.inbox h = recordAt w.inbox h := by
  cases change with
  | landing _ ok => exact Settlement.landing_preserves_old_records ok h old
  | registration => rfl
  | modification => rfl
  | enqueue _ _ _ ok => unfold Forced.enqueue at ok; dsimp only at ok; split at ok <;> cases ok; rfl
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; rfl
  | recovery _ ok => obtain ⟨_,rfl⟩ := Recovery.recover_success ok; rfl
  | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; rfl

/-- The records at or below the starting lastCheckpoint never change along an ordinary trace. -/
theorem ordinary_trace_preserves_settled_records {w t : World} (trace : OrdinaryTrace w t) (h : Nat)
    (old : h ≤ w.inbox.checkpoint.height) : recordAt t.inbox h = recordAt w.inbox h := by
  induction trace with
  | refl => rfl
  | step prior change ih =>
    rw [ordinary_step_preserves_settled_records change h
      (Nat.le_trans old (ordinary_trace_checkpoint_monotone prior)), ih]

/-- A step other than verifier-failure rollback only appends SignalService checkpoints. -/
theorem ordinary_step_signals_prefix {w t : World} (change : OrdinaryStep w t) :
    w.inbox.signals <+: t.inbox.signals := by
  cases change with
  | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; exact List.prefix_append _ _
  | registration => exact List.prefix_refl _
  | modification => exact List.prefix_refl _
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok; dsimp only at ok; split at ok <;> cases ok; exact List.prefix_refl _
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact List.prefix_refl _
  | recovery _ ok => obtain ⟨_,rfl⟩ := Recovery.recover_success ok; exact List.prefix_refl _
  | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact List.prefix_refl _

/-- SignalService checkpoints are only appended along an ordinary trace, so every state root
withdrawals could use stays available. -/
theorem ordinary_trace_signals_prefix {w t : World} (trace : OrdinaryTrace w t) :
    w.inbox.signals <+: t.inbox.signals := by
  induction trace with
  | refl => exact List.prefix_refl _
  | step _ change ih => exact ih.trans (ordinary_step_signals_prefix change)

/-- A block whose valid anchor shows the lastCheckpoint of World `u`: along every later ordinary
trace, the record at the checkpoint height the anchor shows is unchanged, and the block stays
within U of the later lastCheckpoint (6.4). -/
theorem anchored_checkpoint_stays {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {b : BlockValidity.Block} {u t : World} (valid : BlockValidity.AnchorValid r p b)
    (shows : b.header.anchor.checkpointHeight = u.inbox.checkpoint.height) (trace : OrdinaryTrace u t) :
    b.header.height - t.inbox.checkpoint.height ≤ r.unsettled ∧
      recordAt t.inbox b.header.anchor.checkpointHeight = recordAt u.inbox b.header.anchor.checkpointHeight :=
  ⟨anchored_unsettled_bound valid (Nat.le_of_eq shows) trace,
    ordinary_trace_preserves_settled_records trace _ (Nat.le_of_eq shows)⟩

end Etna.Design.ProtocolState
