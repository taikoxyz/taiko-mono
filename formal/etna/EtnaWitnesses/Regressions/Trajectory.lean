import EtnaProofs.Accounting
import EtnaWitnesses.Counterexamples.HistoricalEscrow

/-! The money observer also applies to a properly initialized, deployment-built ordinary
rotation with a valid decoded block chain, not only the comprehensive accounting fixture.
Actual EL/storage/token adapters keep their documented implementation boundaries. -/
namespace Etna.Design.TrajectoryRegression
open Etna.Statements NonVacuity
open HistoricalEscrow

/-- The initialized registry is an accepted registration over genuinely empty slots. -/
theorem initial_released_zero : Accounting.ReleasedZero world0.registry := by
  apply Accounting.register_preserves_released_zero (s := NonVacuity.emptyRegistry)
    (key := 7) (owner := 51) (amount := 1000000000000000000) (now := 10)
  · intro id _
    rfl
  · rfl

/-- Exact receipt categories on the real ordinary-exit example. A standby deposits one
TAIKO and the old validator later withdraws one TAIKO; request/landing/confirmation are
zero-principal-flow operations. -/
theorem ordinary_exit_accounted :
    Accounting.Trace world0 worldE ⟨1000000000000000000,1000000000000000000,0,0⟩ := by
  have deposit : Accounting.Step world0 worldA ⟨1000000000000000000,0,0,0⟩ :=
    .registration (w := world0) (s := standby) (key := 8) (owner := 52)
      (amount := 1000000000000000000) (now := 15) (by decide) rfl
  have exit : Accounting.Step worldA worldB Accounting.Flow.zero :=
    .modification (w := worldA) (s := requested) (id := 0) (now := 16)
      (action := .requestExit 51) (by decide) rfl rfl
  have landing : Accounting.Step worldB worldC Accounting.Flow.zero :=
    .landing (w := worldB) (s := applyLanding worldB.inbox statement.input)
      (i := statement.input) (leaves := leaves) (e := landingEnv) (by decide) (by decide +kernel)
  have confirmation : Accounting.Step worldC worldD Accounting.Flow.zero :=
    .modification (w := worldC) (s := confirmed) (id := 0) (now := 29)
      (action := .confirm) (by decide) rfl rfl
  have withdrawal : Accounting.Step worldD worldE ⟨0,1000000000000000000,0,0⟩ :=
    .modification (w := worldD) (s := withdrawn) (id := 0) (now := 30)
      (action := .withdraw 51) (by decide) rfl rfl
  exact .step (.step (.step (.step (.step (.refl _) deposit) exit) landing) confirmation) withdrawal


/-- This initialized example simultaneously has an actual valid rotation chain and an
independently recorded, conserved principal flow; the standby's principal remains held. -/
theorem initialized_rotation_principal_conserved :
    Deployment.Genesis world0 genesisHeader.elHash genesisHeader.stateRoot ∧
    BlockValidity.Chain rules genesisHeader blocks ∧
    Accounting.held world0.registry = 1000000000000000000 ∧
    Accounting.held worldE.registry = 1000000000000000000 ∧
    Accounting.held world0.registry+1000000000000000000 =
      Accounting.held worldE.registry+1000000000000000000 := by
  refine ⟨NonVacuity.premises.genesis.1,ordinary_rotation_chain,by decide +kernel,by decide +kernel,?_⟩
  exact Accounting.trajectory_conservation initial_released_zero ordinary_exit_accounted

end Etna.Design.TrajectoryRegression
