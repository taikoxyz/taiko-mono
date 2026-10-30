import EtnaModel.TrustedSnapshot
import EtnaProofs.SigningEscrow

/-! Exclusion of a confirmed key under a trusted slot 284. When slot 284 is not ahead of the
cutoff of the committee active at lastCheckpoint, a key whose exit was confirmed is absent from
every committee the context built on the same World activates at or above lastCheckpoint. The
theorem speaks about that World only: it says nothing about later Worlds, withdrawals, commits or
slashing, and it does not prove that a trusted restore satisfies the condition.
`UntrustedRollback` shows the conclusion fails after an untrusted rollback. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Under `SnapshotTrusted`, a confirmed exit's key is absent from every committee that the
context built on the same World activates at or above lastCheckpoint. The trace may start from
any registry with unique keys and visible exits, for example a zero-slot one
(`unallocated_keys_well_formed`) or the initialized deployment's. -/
theorem confirmed_key_absent_above_checkpoint {initial w : World} {id c h : Nat}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    (prior : Trace initial w) (core : Core initial)
    (keys : KeysWellFormed initial.registry) (visible : ExitVisible initial.registry)
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
  exact selected_excludes_confirmed_key built (trace_exit_visible prior core keys visible id range nonzero finite)
    (Nat.le_trans (covered id c confirmed)
      (Nat.le_trans trusted (Consensus.active_cutoff_monotone ctx genesis anchors above)))

end Etna.Design.SigningEscrow
