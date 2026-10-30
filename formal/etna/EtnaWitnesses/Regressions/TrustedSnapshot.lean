import EtnaProofs.TrustedSnapshot
import EtnaWitnesses.Counterexamples.UntrustedRollback
import EtnaWitnesses.Regressions.SigningBridge

/-! `SnapshotTrusted` excludes the untrusted rollback and holds together with every hypothesis of
`confirmed_key_absent_above_checkpoint`. The World after the rollback that restored slot 284 = 1000
violates it under the rules built on that World. On `HistoricalEscrow`'s ordinary run from the
initialized deployment (a second registration, key 7's exit request, an accepted twelve-block
landing that rotates key 7 out, the confirmation), the context built on the confirming World
satisfies it, and the theorem excludes key 7 at and above lastCheckpoint. -/
namespace Etna.Design.TrustedSnapshotRegression
open SigningEscrow

/-- The untrusted rollback's final World has slot 284 above the active committee's cutoff. -/
theorem untrusted_rollback_not_trusted :
    ¬ SnapshotTrusted UntrustedRollback.rulesD.consensus UntrustedRollback.worldD := by
  unfold SnapshotTrusted
  decide +kernel

/-- The history parameters stored on the confirming World. -/
def confirmingParameters : HistoricalContext.Parameters :=
  Deployment.parameters HistoricalEscrow.worldD.inbox HistoricalEscrow.worldD.inbox.configuration

/-- The consensus context built on the confirming World. -/
def confirmingContext : Consensus.Context :=
  HistoricalContext.derive HistoricalEscrow.worldD.inbox HistoricalEscrow.worldD.registry confirmingParameters
    HistoricalEscrow.archive

private theorem confirming_context_built :
    HistoricalContext.build HistoricalEscrow.worldD.inbox HistoricalEscrow.worldD.registry confirmingParameters
      HistoricalEscrow.archive = some confirmingContext := by
  unfold HistoricalContext.build
  exact ite_eq_left (by decide +kernel)

private theorem confirming_snapshot_trusted : SnapshotTrusted confirmingContext HistoricalEscrow.worldD := by
  unfold SnapshotTrusted
  decide +kernel

/-- Every hypothesis of `confirmed_key_absent_above_checkpoint` holds on the confirming World of
an ordinary run, with the context built on that World: key 7's exit is confirmed and covered,
slot 284 is trusted, and key 7 is absent from every committee active at or above lastCheckpoint. -/
theorem confirmed_exit_trusted_snapshot :
    HistoricalContext.build HistoricalEscrow.worldD.inbox HistoricalEscrow.worldD.registry confirmingParameters
        HistoricalEscrow.archive = some confirmingContext ∧
      (HistoricalEscrow.worldD.registry.slots 0).key = 7 ∧
      (HistoricalEscrow.worldD.registry.slots 0).confirmedAt = some 29 ∧ Covered HistoricalEscrow.worldD ∧
      SnapshotTrusted confirmingContext HistoricalEscrow.worldD ∧
      ∀ h, HistoricalEscrow.worldD.inbox.checkpoint.height ≤ h →
        ∀ e ∈ (Consensus.activeAt confirmingContext h).members, e.key ≠ 7 := by
  refine ⟨confirming_context_built, by decide +kernel, by decide +kernel,
    SigningBridgeRegression.confirmation_covered, confirming_snapshot_trusted, ?_⟩
  intro h above
  exact confirmed_key_absent_above_checkpoint (id := 0) (c := 29)
    (snapshot_trace_projects SigningBridgeRegression.confirmation_trajectory)
    (Deployment.genesis_core NonVacuity.premises.genesis.1)
    SigningBridgeRegression.initial_keys SigningBridgeRegression.initial_visible
    (by decide +kernel) (by decide +kernel) SigningBridgeRegression.confirmation_covered
    (by decide +kernel) (by decide +kernel) confirming_context_built confirming_snapshot_trusted above

end Etna.Design.TrustedSnapshotRegression
