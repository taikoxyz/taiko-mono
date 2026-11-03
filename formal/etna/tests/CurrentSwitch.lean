import EtnaWitnesses.NonVacuity.CurrentSwitch

namespace Etna.CurrentSwitchRegression
open Etna.Design Etna.Design.Current Protocol
open _root_.Etna.Design.Current.Protocol.CurrentSwitch

-- The accepting switch really executes the S fence; recovery did not bypass it.
example : (source env).inbox.checkpoint.height = ((source env).start.map StartData.height).getD 0 ∧
    firstFence env (source env) = true := by decide +kernel

-- All fourteen premises hold in the same switching environment, with a global
-- verifier relation accepting a single fixed reference-local statement.
example : Etna.Statements.Current.Premises env _root_.Etna.Design.Current.Protocol.NonVacuity.registry _root_.Etna.Design.Current.Protocol.NonVacuity.engine := premises

theorem landed_reachable : Trace env (empty env _root_.Etna.Design.Current.Protocol.NonVacuity.registry) (landed (source env) landing) := by
  have actual : Protocol.transact env (source env) (.land landing) = landed (source env) landing := by
    simp only [Protocol.transact,Protocol.execute,source_landing_accepted,Option.getD_some]
  exact actual ▸ .step (source_reachable env) (.call _ (.land landing))

-- The global two-lane theorem is exercised by this fully realized switching run.
example : Custody.LegacyEtnaDisjoint (landed (source env) landing) :=
  Custody.trace_legacy_etna_disjoint (by decide) primitives unzen_extension verifier_sound landed_reachable

end Etna.CurrentSwitchRegression
