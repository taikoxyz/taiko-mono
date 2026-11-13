import EtnaStatements.Current
import EtnaProofs.CurrentRecoveryTrap
import EtnaWitnesses.Traps.RollbackGrid

/-! The rollback-across-K-change trap: an off-grid frontier never lands again along calls with
no rollback and no structural recovery, such a state is reachable in the model, here under a
failed verifier, and a structural recovery that installs a K whose grid holds the frontier exits
it, as SPEC 8.3 allows. H4's call class `RecoveryCall` admits that exit, so H4's conclusion
holds at the trapped state. Kept apart from tests/CurrentRecovery.lean so the H4 statement pins
never depend on a witness build. -/
namespace Etna.CurrentRecoveryTrapRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

-- The trap's call class: rollback and structural recoveries are out; a plain recovery and the
-- catch-all arm are in.
example (w : World) (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    ¬ NoRollbackOrUpgrade w (.rollback caller trusted snapshot) := id
example (w : World) (r : RecoveryRequest) (p : Current.Protocol.Parameters) :
    ¬ NoRollbackOrUpgrade w (.recover { r with upgrade := some p }) := fun h => nomatch h
example (w : World) (r : RecoveryRequest) (plain : r.upgrade = none) : NoRollbackOrUpgrade w (.recover r) := plain
example (w : World) (n : Nat) : NoRollbackOrUpgrade w (.advance n) := trivial

example : ∀ {env : Environment} {registry : RegistryMachine.State} {w : World} {start : StartData},
    Trace env (empty env registry) w → w.start = some start → w.everLanded = true →
    Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = false →
    ∀ u, CallTrace env NoRollbackOrUpgrade w u → ∀ a, land env u a = none :=
  Etna.Design.Current.Protocol.Recovery.offgrid_no_landing
example : ∃ env registry w, Trace env (empty env registry) w ∧
    (∀ u, CallTrace env NoRollbackOrUpgrade w u → ∀ a, land env u a = none) ∧
    ∃ u a t, Trace env w u ∧ land env u a = some t :=
  Etna.Design.Current.Protocol.RollbackGridTrap.rollback_grid_trap
example : ∃ env registry w start, Trace env (empty env registry) w ∧ w.start = some start ∧
    w.everLanded = true ∧ Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = false ∧
    w.schedule.stopTime = 0 ∧
    ∃ request u a t, request.upgrade = some { parametersOf w.inbox with gridK := 2 } ∧
      request.rules = w.schedule.next+1 ∧ recover env w request = some u ∧ land env u a = some t :=
  Etna.Design.Current.Protocol.RollbackGridTrap.rollback_grid_escape

-- The trapped state: c = 2 is off the K = 3 grid, in generation 1 whose origin 6 is above c.
example : RollbackGridTrap.trapped.inbox.checkpoint.height = 2 ∧ RollbackGridTrap.trapped.inbox.gridK = 3 ∧
    RollbackGridTrap.trapped.inbox.generation = 1 ∧ RollbackGridTrap.trapped.inbox.origin.height = 6 := by
  decide +kernel

-- After the structural recovery: generation 2 starts at c = 2 on the K = 2 grid, and the
-- recovery used ruleset 2 = nextRules + 1.
example : RollbackGridTrap.restarted.inbox.gridK = 2 ∧ RollbackGridTrap.restarted.inbox.generation = 2 ∧
    RollbackGridTrap.restarted.inbox.origin.height = 2 ∧ RollbackGridTrap.restarted.schedule.active = 2 := by
  decide +kernel

-- H4's call class admits the escape: it changes only K and has no exclusions and no blanking.
example : RecoveryCall RollbackGridTrap.trapped (.recover RollbackGridTrap.structural) := ⟨rfl,rfl,.inr ⟨2,rfl⟩⟩

-- So H4's conclusion holds at the trapped state: a `RecoveryTrace` (that recovery) reaches the
-- accepted 2 → 4 landing, above the trapped c = 2. The environment meets no premise record, so
-- this is the conclusion only, not H4 applied.
example : Etna.Statements.Current.RecoverableAt RollbackGridTrap.env RollbackGridTrap.trapped := by
  have checks : LandingChecks RollbackGridTrap.env RollbackGridTrap.restarted (RollbackGridTrap.batch 2 4) := by
    decide +kernel
  refine ⟨RollbackGridTrap.restarted,RollbackGridTrap.batch 2 4,
    landed RollbackGridTrap.restarted (RollbackGridTrap.batch 2 4),
    .call (.refl _) (.recover RollbackGridTrap.structural) ⟨rfl,rfl,.inr ⟨2,rfl⟩⟩,?_,fun _ => ?_⟩
  · simp only [Protocol.land,checks,ite_true]
  · decide +kernel

end Etna.CurrentRecoveryTrapRegression
