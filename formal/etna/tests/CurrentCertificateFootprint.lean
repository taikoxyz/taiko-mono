import EtnaWitnesses.NonVacuity.Current

namespace Etna.CurrentCertificateFootprintRegression
open Etna.Design Etna.Design.Current Protocol
open Etna.Design.Current.Protocol.NonVacuity
set_option maxRecDepth 30000
set_option maxHeartbeats 8000000

-- The sound accepting deployment derives the complete live footprint.
example : CertificateFootprint env (source env) landing.input.l1ReferenceBlockNumber :=
  Journal.accepted_landing_footprint registry_genesis verifier_sound (source_reachable env) source_landing_accepted

/-- A deliberately unsound backend exposes exactly what the public landing guards
permit. It is not an accepting witness for the protocol's soundness premises. -/
def unchecked : Environment := { env with verify := fun _ _ _ _ _ => true }
def stale : Landing := { recoveredLanding with input :=
  { recoveredLanding.input with l1ReferenceBlockNumber := 2 } }

theorem first_accepted : land unchecked (source unchecked) landing =
    some (landed (source unchecked) landing) := by
  have checks : LandingChecks unchecked (source unchecked) landing := by decide +kernel
  simp only [Protocol.land,checks,ite_true]

theorem reachable : Trace unchecked (empty unchecked registry) (recoveredSource unchecked) := by
  have first : Trace unchecked (empty unchecked registry) (landed (source unchecked) landing) := by
    have actual : Protocol.transact unchecked (source unchecked) (.land landing) = landed (source unchecked) landing := by
      simp only [Protocol.transact,Protocol.execute,first_accepted,Option.getD_some]
    exact actual ▸ .step (source_reachable unchecked) (.call _ (.land landing))
  exact .step (.step (.step first (.call _ (.advance 4))) (.call _ (.recover recoveryRequest)))
    (.call _ (.advance 5))

-- Public guards alone permit a pre-recovery reference in the next generation.
example : land unchecked (recoveredSource unchecked) stale =
    some (landed (recoveredSource unchecked) stale) := by
  have checks : LandingChecks unchecked (recoveredSource unchecked) stale := by decide +kernel
  simp only [Protocol.land,checks,ite_true]

theorem stale_has_no_footprint : ¬ CertificateFootprint unchecked (recoveredSource unchecked) 2 := by
  intro footprint
  have generation := congrArg Finality.Config.generation footprint.configuration
  change 0 = 1 at generation
  cases generation

-- The actual statement's bound generation rules out this stale-reference certificate.
example : ¬ Certifies unchecked (recoveredSource unchecked)
    (statement unchecked (recoveredSource unchecked) stale) := by
  intro certificate
  exact stale_has_no_footprint (certified_statement_footprint registry_genesis reachable certificate)

end Etna.CurrentCertificateFootprintRegression
