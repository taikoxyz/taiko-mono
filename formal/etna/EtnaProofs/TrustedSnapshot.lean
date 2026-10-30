import EtnaModel.TrustedSnapshot
import EtnaProofs.SigningEscrow

/-! Accountability after rollback. With a trusted slot 284, a key whose exit was confirmed is
absent from every committee active at or above lastCheckpoint, so it cannot sign a valid commit
there after withdrawing. `UntrustedRollback` shows the conclusion fails without the condition. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Under a trusted slot 284, a confirmed exit's key is absent from every committee that the
rules built on the World activate at or above lastCheckpoint. -/
theorem confirmed_key_absent_above_checkpoint {initial w : World} {id c h : Nat}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    (prior : Trace initial w) (core : Core initial) (empty : initial.registry.nextId = 0)
    (range : id < w.registry.nextId)
    (confirmed : (w.registry.slots id).confirmedAt = some c) (covered : Covered w)
    (nonzero : (w.registry.slots id).key ≠ 0) (finite : (w.registry.slots id).exitAt ≠ Staking.noExit)
    (built : HistoricalContext.build w.inbox w.registry cfg archive = some ctx)
    (trusted : SnapshotTrusted ctx w) (above : w.inbox.checkpoint.height ≤ h) :
    ∀ e ∈ (Consensus.activeAt ctx h).members, e.key ≠ (w.registry.slots id).key := by
  have info := HistoricalContext.build_success built
  have genesis : ctx.genesisCutoff ≤ ctx.originBlock := by
    rw [info.2]
    exact info.1.2.2.2.2.2.2.2
  have anchors : ∀ x y, x ≤ y → ctx.anchorAt x ≤ ctx.anchorAt y := by
    intro x y order
    rw [info.2]
    exact HistoricalContext.derived_anchors_monotone _ _ _ _ order
  exact confirmed_key_absent_later_cutoff prior core empty (.refl _) range confirmed covered nonzero finite
    built (Nat.le_trans trusted (Consensus.active_cutoff_monotone ctx genesis anchors above))

end Etna.Design.SigningEscrow
