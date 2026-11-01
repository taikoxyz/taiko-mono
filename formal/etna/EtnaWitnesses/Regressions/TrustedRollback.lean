import EtnaProofs.TrustedRollback
import EtnaWitnesses.NonVacuity.Premises
import EtnaWitnesses.Regressions.SigningBridge

/-! A rollback done as section 8 says, on the non-vacuity run. After the landings of (0, 1] in
L1 block 17 and (1, 2] in block 19, a verifier-failure rollback in block 19 restores the
checkpoint and slot 284 that the first landing wrote. Every hypothesis of
`trusted_rollback_snapshot_trusted` and `trusted_rollback_excludes_confirmed_keys` holds, the
rollback is an actual protocol step, and on the context built on the restored World slot 284
equals the active committee's cutoff at the restored checkpoint. Restoring the same checkpoint
with a snapshot no landing wrote (1000) breaks `SnapshotTrusted` there. The run's registry has
no exit and its later landing is honest, so the exclusion conclusion holds vacuously here and a
forged later landing is not exercised. -/
namespace Etna.Design.TrustedRollbackRegression
open SigningEscrow NonVacuity

/-- What the first landing wrote. -/
def landing1 : State := applyLanding worldQ.inbox statement1.input

/-- The World after the rollback that restores the first landing's values. -/
def restored : ProtocolState.World := ProtocolState.applyRollback world2 landing1.checkpoint landing1.snapshot 19

def restoredParameters : HistoricalContext.Parameters :=
  Deployment.parameters restored.inbox restored.inbox.configuration

def restoredContext : Consensus.Context :=
  HistoricalContext.derive restored.inbox restored.registry restoredParameters archive0

/-- The same checkpoint restored with a snapshot no landing wrote. -/
def untrusted : ProtocolState.World := ProtocolState.applyRollback world2 landing1.checkpoint 1000 19

def untrustedContext : Consensus.Context :=
  HistoricalContext.derive untrusted.inbox untrusted.registry
    (Deployment.parameters untrusted.inbox untrusted.inbox.configuration) archive0

private theorem restored_built :
    HistoricalContext.build restored.inbox restored.registry restoredParameters archive0 = some restoredContext := by
  unfold HistoricalContext.build
  exact ite_eq_left (by decide +kernel)

/-- The first landing's certificate is the statement of the rules built on `worldQ` (its own
guest view) from archive [14, 15]. -/
private theorem construction :
    Deployment.build (Statements.guestView worldQ worldQ.inbox.configuration worldQ.inbox.committeeZeroRecord)
      worldQ.inbox.configuration archive0 (relations.template 16 1600) = some rules0 :=
  build_rulesFor (by decide +kernel) (by decide +kernel)

private theorem later : ProtocolState.Trace (ProtocolState.landed worldQ landing1 env1.blockNumber) world2 :=
  .step (.refl _) (.landing (by decide) steps_accepted.2.2.1)

/-- The trusted rollback is an actual step, satisfies every hypothesis of both theorems, and
keeps slot 284 equal to the active cutoff at the restored checkpoint; an untrusted snapshot at
the same checkpoint is not trusted. -/
theorem trusted_rollback_keeps_snapshot :
    ProtocolState.Step world2 restored ∧ restored.inbox.checkpoint.height = 1 ∧
    world2.inbox.checkpoint.height = 2 ∧
    SnapshotTrusted restoredContext restored ∧
    restored.inbox.snapshot = (Consensus.activeAt restoredContext restored.inbox.checkpoint.height).cutoff ∧
    (∀ id c h, id < restored.registry.nextId → (restored.registry.slots id).confirmedAt = some c →
      (restored.registry.slots id).key ≠ 0 → (restored.registry.slots id).exitAt ≠ Staking.noExit →
      landing1.checkpoint.height ≤ h →
      ∀ m ∈ (Consensus.activeAt restoredContext h).members, m.key ≠ (restored.registry.slots id).key) ∧
    HistoricalContext.build untrusted.inbox untrusted.registry
      (Deployment.parameters untrusted.inbox untrusted.inbox.configuration) archive0 = some untrustedContext ∧
    ¬ SnapshotTrusted untrustedContext untrusted := by
  have rollback : ProtocolState.Step world2 restored :=
    .rollback landing1.checkpoint landing1.snapshot 19 (by decide) (by decide +kernel) (by decide +kernel)
  have trusted := trusted_rollback_snapshot_trusted (now := 19) steps_accepted.2.1 construction rfl later
    (by decide +kernel) restored.inbox.configuration archive0 restoredContext (fun _ _ => rfl) restored_built
  have before : ProtocolState.Trace world0 worldQ :=
    .step (.refl _) (.enqueue (by decide) (by decide) (by decide) steps_accepted.1)
  refine ⟨rollback,by decide +kernel,by decide +kernel,trusted.1,trusted.2,?_,?_,?_⟩
  · exact trusted_rollback_excludes_confirmed_keys before (Deployment.genesis_core premises.genesis.1)
      SigningBridgeRegression.initial_keys SigningBridgeRegression.initial_visible (by decide) steps_accepted.2.1
      construction rfl later rollback (.refl _) rfl rfl (by decide +kernel) restored.inbox.configuration archive0
      restoredContext (fun _ _ => rfl) restored_built
  · unfold HistoricalContext.build
    exact ite_eq_left (by decide +kernel)
  · unfold SnapshotTrusted
    decide +kernel

end Etna.Design.TrustedRollbackRegression
