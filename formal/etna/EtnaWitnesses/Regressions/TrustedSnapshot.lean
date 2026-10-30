import EtnaProofs.TrustedSnapshot
import EtnaWitnesses.Counterexamples.UntrustedRollback

/-! `SnapshotTrusted` is satisfiable and does exclude the untrusted rollback: the initialized
World satisfies it under the deployment's rules, and the World after the rollback that restored
slot 284 = 1000 violates it. -/
namespace Etna.Design.UntrustedRollback
open SigningEscrow

/-- The untrusted rollback's final World has slot 284 above the active committee's cutoff. -/
theorem untrusted_rollback_not_trusted : ¬ SnapshotTrusted rulesD.consensus worldD := by
  unfold SnapshotTrusted
  decide +kernel

/-- The initialized World's slot 284 is exactly the genesis cutoff, so it is trusted. -/
theorem initialized_snapshot_trusted : SnapshotTrusted rulesD.consensus NonVacuity.world0 := by
  unfold SnapshotTrusted
  decide +kernel

end Etna.Design.UntrustedRollback
