import EtnaModel.BackPressure
import EtnaProofs.ProtocolState

/-! Section 6.4: the anchor-based unsettled count never undercounts, and the L2 height stays
within U of every later lastCheckpoint, along every trace without verifier-failure rollback.
Rollback, the stated exception, restores the trusted record as lastCheckpoint. -/
namespace Etna.Design.ProtocolState

/-- No original step other than verifier-failure rollback lowers lastCheckpoint: a landing
advances it, and every other transaction leaves it unchanged. -/
theorem ordinary_step_checkpoint_monotone {w t : World} (change : Step w t)
    (ordinary : ∀ trusted snapshot now, t ≠ applyRollback w trusted snapshot now) :
    w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height := by
  cases change with
  | landing _ ok => exact Nat.le_of_lt (land_extends_checkpoint ok).1
  | registration => exact Nat.le_refl _
  | modification => exact Nat.le_refl _
  | enqueue _ _ _ ok => unfold Forced.enqueue at ok; dsimp only at ok; split at ok <;> cases ok; exact Nat.le_refl _
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact Nat.le_refl _
  | recovery _ ok => obtain ⟨_,rfl⟩ := Recovery.recover_success ok; exact Nat.le_refl _
  | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact Nat.le_refl _
  | rollback trusted snapshot now => exact absurd rfl (ordinary trusted snapshot now)

/-- lastCheckpoint.height never decreases along a trace without verifier-failure rollback. -/
theorem ordinary_trace_checkpoint_monotone {w t : World} (trace : OrdinaryTrace w t) :
    w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height := by
  induction trace with
  | refl => exact Nat.le_refl _
  | step _ change ordinary ih => exact Nat.le_trans ih (ordinary_step_checkpoint_monotone change ordinary)

/-- 6.4 "never undercounts": if a block's anchor shows the checkpoint of World `w`, then for
every later World `t` without an intervening verifier-failure rollback, the block's height
above `t`'s lastCheckpoint is at most its height above the anchor's checkpoint. -/
theorem anchored_count_not_undercounted {b : BlockValidity.Block} {w t : World}
    (shows : b.header.anchor.checkpointHeight ≤ w.inbox.checkpoint.height)
    (trace : OrdinaryTrace w t) :
    b.header.height - t.inbox.checkpoint.height ≤ b.header.height - b.header.anchor.checkpointHeight := by
  have monotone := ordinary_trace_checkpoint_monotone trace
  omega

/-- 6.4: a block with a valid anchor, whose anchor shows the checkpoint of World `w`, is at
most U blocks above the lastCheckpoint of every later World on a trace without
verifier-failure rollback. A landing stall therefore permits at most U further blocks. -/
theorem anchored_unsettled_bound {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {b : BlockValidity.Block} {w t : World} (valid : BlockValidity.AnchorValid r p b)
    (shows : b.header.anchor.checkpointHeight ≤ w.inbox.checkpoint.height)
    (trace : OrdinaryTrace w t) :
    b.header.height - t.inbox.checkpoint.height ≤ r.unsettled := by
  obtain ⟨_,_,_,_,_,_,_,bound,_⟩ := valid
  have counted := anchored_count_not_undercounted shows trace
  omega

/-- 6.4's exception: verifier-failure rollback makes the trusted retained record
lastCheckpoint, which may be lower than the checkpoint it replaces. -/
theorem rollback_restores_trusted_checkpoint (w : World) (trusted : Checkpoint) (snapshot now : Nat) :
    (applyRollback w trusted snapshot now).inbox.checkpoint = trusted := rfl

end Etna.Design.ProtocolState
