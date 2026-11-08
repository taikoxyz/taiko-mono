import EtnaProofs.CurrentRecoveryTrap
import EtnaWitnesses.Traps.RollbackGrid

/-! The rollback-across-K-change trap that `LiveAt.grid` excludes: an off-grid frontier never
lands again without a rollback, and such a state is reachable in the model, here under a failed
verifier. Kept apart from tests/CurrentRecovery.lean so the H4 statement pins never depend on a
witness build. -/
namespace Etna.CurrentRecoveryTrapRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

example := @Etna.Design.Current.Protocol.Recovery.offgrid_no_landing
example : ∃ env registry w, Trace env (empty env registry) w ∧
    (∀ u, CallTrace env NoRollback w u → ∀ a, land env u a = none) ∧
    ∃ u a t, Trace env w u ∧ land env u a = some t :=
  Etna.Design.Current.Protocol.RollbackGridTrap.rollback_grid_trap

-- The trapped state: c = 2 is off the K = 3 grid, in generation 1 whose origin 6 is above c.
example : RollbackGridTrap.trapped.inbox.checkpoint.height = 2 ∧ RollbackGridTrap.trapped.inbox.gridK = 3 ∧
    RollbackGridTrap.trapped.inbox.generation = 1 ∧ RollbackGridTrap.trapped.inbox.origin.height = 6 := by
  decide +kernel

end Etna.CurrentRecoveryTrapRegression
