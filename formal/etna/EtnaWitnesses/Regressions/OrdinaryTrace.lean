import EtnaProofs.Permanence
import EtnaWitnesses.NonVacuity.Premises

/-! `OrdinaryTrace` tells verifier-failure rollback apart by its operation, not by its result.
A legal owner nonce invalidation on the initialized World leaves the same World as a rollback
that keeps the current checkpoint and snapshot (both only increment the recovery nonce there),
so a definition that excluded every step whose result equals some rollback's result would drop
it. It is an ordinary step, and the settled-prefix and back-pressure theorems cover traces that
contain it. -/
namespace Etna.Design.OrdinaryTraceRegression
open ProtocolState NonVacuity

/-- The initialized World after the owner invalidates the current recovery nonce. -/
def invalidated : World := landed world0 (Recovery.applyInvalidation world0.inbox) world0.l1Block

private theorem owner_invalidation :
    Recovery.invalidateRecoveryNonce world0.inbox world0.inbox.recoveryNonce true =
      some (Recovery.applyInvalidation world0.inbox) := by
  unfold Recovery.invalidateRecoveryNonce
  exact ite_eq_left (by decide +kernel)

private theorem registry_rechecked : RegistryHistory.recheckAll world0.registry world0.inbox.snapshot = world0.registry := by
  unfold RegistryHistory.recheckAll
  congr 1
  funext id
  by_cases zero : id = 0
  · subst zero
    decide +kernel
  · change Staking.rollbackBySnapshot _ (if id = 0 then _ else RegistryHistory.vacant) =
      (if id = 0 then _ else RegistryHistory.vacant)
    rw [ite_eq_right zero]
    decide +kernel

/-- A legal owner nonce invalidation on the initialized World is an ordinary trace, although
its result equals the rollback that keeps the current checkpoint and snapshot. -/
theorem invalidation_is_ordinary :
    OrdinaryTrace world0 invalidated ∧
      invalidated = applyRollback world0 world0.inbox.checkpoint world0.inbox.snapshot world0.l1Block := by
  refine ⟨.step (.refl _) (.invalidation (expected := world0.inbox.recoveryNonce) (owner := true)
    (Nat.le_refl _) owner_invalidation), ?_⟩
  have inbox : Recovery.applyInvalidation world0.inbox =
      Recovery.rollbackInbox world0.inbox world0.inbox.checkpoint world0.inbox.snapshot := by
    decide +kernel
  unfold invalidated landed applyRollback
  rw [inbox, registry_rechecked]

end Etna.Design.OrdinaryTraceRegression
