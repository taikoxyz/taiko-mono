import EtnaModel.BackPressure
import EtnaProofs.ProtocolState

/-! Section 6.4: the anchor-based unsettled count never undercounts, and the L2 height stays
within U of every later lastCheckpoint, along every trace without verifier-failure rollback.
Rollback, the stated exception, restores the trusted record as lastCheckpoint. -/
namespace Etna.Design.ProtocolState

/-- Every ordinary step is an original step with the same premises. -/
theorem ordinary_step_is_step {w t : World} (change : OrdinaryStep w t) : Step w t := by
  cases change with
  | landing time ok => exact .landing time ok
  | registration time ok => exact .registration time ok
  | modification time callable ok => exact .modification time callable ok
  | enqueue time blockRange timestampRange ok => exact .enqueue time blockRange timestampRange ok
  | sweep time ok => exact .sweep time ok
  | recovery time ok => exact .recovery time ok
  | invalidation time ok => exact .invalidation time ok

/-- Every original step is an ordinary step or a verifier-failure rollback: `OrdinaryStep`
leaves out exactly the rollback operation. -/
theorem step_ordinary_or_rollback {w t : World} (change : Step w t) :
    OrdinaryStep w t ∨ ∃ trusted snapshot now, t = applyRollback w trusted snapshot now := by
  cases change with
  | landing time ok => exact .inl (.landing time ok)
  | registration time ok => exact .inl (.registration time ok)
  | modification time callable ok => exact .inl (.modification time callable ok)
  | enqueue time blockRange timestampRange ok => exact .inl (.enqueue time blockRange timestampRange ok)
  | sweep time ok => exact .inl (.sweep time ok)
  | recovery time ok => exact .inl (.recovery time ok)
  | invalidation time ok => exact .inl (.invalidation time ok)
  | rollback trusted snapshot now => exact .inr ⟨trusted,snapshot,now,rfl⟩

/-- No original step other than verifier-failure rollback lowers lastCheckpoint: a landing
advances it, and every other transaction leaves it unchanged. -/
theorem ordinary_step_checkpoint_monotone {w t : World} (change : OrdinaryStep w t) :
    w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height := by
  cases change with
  | landing _ ok => exact Nat.le_of_lt (land_extends_checkpoint ok).1
  | registration => exact Nat.le_refl _
  | modification => exact Nat.le_refl _
  | enqueue _ _ _ ok => unfold Forced.enqueue at ok; dsimp only at ok; split at ok <;> cases ok; exact Nat.le_refl _
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact Nat.le_refl _
  | recovery _ ok => obtain ⟨_,rfl⟩ := Recovery.recover_success ok; exact Nat.le_refl _
  | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact Nat.le_refl _

/-- lastCheckpoint.height never decreases along a trace without verifier-failure rollback. -/
theorem ordinary_trace_checkpoint_monotone {w t : World} (trace : OrdinaryTrace w t) :
    w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height := by
  induction trace with
  | refl => exact Nat.le_refl _
  | step _ change ih => exact Nat.le_trans ih (ordinary_step_checkpoint_monotone change)

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
