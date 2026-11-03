import EtnaWitnesses.NonVacuity.Current

namespace Etna.CurrentPremisesRegression
open Etna.Design Etna.Design.Current Protocol
open Etna.Design.Current.Protocol.NonVacuity

-- A single environment satisfies the complete global premise record and lands an
-- actual nonzero FI entry with a real registered and token-funded principal.
example : AcceptingDeployment := accepting_deployment
example : ∃ e registry engine w t a, Etna.Statements.Current.Premises e registry engine ∧
    Trace e (empty e registry) w ∧ land e w a = some t ∧ w.inbox.head < t.inbox.head ∧
    ∀ x y, e.stateRoot x = e.stateRoot y → x = y := premises_satisfiable
example : Etna.Statements.Current.Premises env registry engine := premises
example : (source env).registry.registry.ledger.nextId = 1 ∧
    (source env).registry.token.balances 4 = unit ∧
    (source env).inbox.ethBalance = 1000000000 ∧ (source env).inbox.tail = 1 ∧
    (0,forcedEntry) ∈ (source env).queue := actual_funding_and_queue

-- The before-reference sibling changes the commitment; a later change keeps the
-- immutable old cut usable by the same genuine fixed proof bytes.
example : land env beforeReference landing = none := before_reference_old_proof_rejected
example : land env afterReference landing = some (landed afterReference landing) :=
  after_reference_landing_accepted

-- A number-only commitment cannot satisfy the global reference premise.
def numberOnly : Environment := { env with blockHash := fun _ number => number }
example : ¬ ReferenceBinding numberOnly := by
  intro binding
  have cut : referencePrefix beforeReference 2 = referencePrefix (source env) 2 :=
    binding (referencePrefix beforeReference 2) (referencePrefix (source env) 2) 2 rfl
  exact before_reference_changes_prefix cut

example : rollback env firstLanded 7 (source env).inbox.checkpoint 1 = some rolledBack := positive_rollback
example : land env rolledBack landing = some (landed rolledBack landing) := rollback_then_landing_accepted
example : (recover env rolledBack ⟨7,0,0,1,100,[],[],0,none⟩).isSome = true :=
  actual_recovery_after_rollback

-- Recovery is followed by a genuine accepted generation1 landing under the SAME
-- globally sound two-template verifier and complete premise record.
example : Etna.Statements.Current.Premises env registry engine ∧
    Trace env (empty env registry) (recoveredSource env) ∧
    (recoveredSource env).inbox.generation = 1 ∧
    land env (recoveredSource env) recoveredLanding = some (landed (recoveredSource env) recoveredLanding) ∧
    (recoveredSource env).inbox.checkpoint.height < (landed (recoveredSource env) recoveredLanding).inbox.checkpoint.height :=
  accepting_after_recovery

end Etna.CurrentPremisesRegression
