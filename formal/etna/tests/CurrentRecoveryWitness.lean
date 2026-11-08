import EtnaWitnesses

/-! The premises of H1–H4 can hold of one deployment (design 4.6): a single environment,
registry and engine satisfy H1–H3's `Premises` and H4's `RecoveryPremises` together, with a
reachable initialized world that satisfies `LiveAt`. -/
namespace Etna.CurrentRecoveryWitnessRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

example : ∃ e registry engine w, Etna.Statements.Current.Premises e registry engine ∧
    Etna.Statements.Current.RecoveryPremises e registry ∧
    Trace e (empty e registry) w ∧ w.initialized = true ∧ Etna.Statements.Current.LiveAt e w :=
  Etna.Design.Current.Protocol.RecoveryNonVacuity.all_premises_satisfiable

-- The world: one bond for the online key, initialized at S = 0 on K = 1 at L1 block 2, nothing
-- landed yet, on the initial rulesets 0/0.
example : RecoveryNonVacuity.live.registry.registry.ledger.nextId = 1 ∧ RecoveryNonVacuity.live.number = 2 ∧
    RecoveryNonVacuity.live.inbox.checkpoint.height = 0 ∧ RecoveryNonVacuity.live.inbox.gridK = 1 ∧
    RecoveryNonVacuity.live.everLanded = false ∧ RecoveryNonVacuity.live.schedule.active = 0 ∧
    RecoveryNonVacuity.live.schedule.next = 0 := by
  decide +kernel

end Etna.CurrentRecoveryWitnessRegression
