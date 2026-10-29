import EtnaWitnesses.Counterexamples.NoVerifierSoundness

/-! Regression for the issue repaired by SPEC §8.3: rollback increments the current
recovery nonce, so restoring an earlier checkpoint cannot revive an old authorization.
The forged landing remains outside verifier soundness, as in NoVerifierSoundness. -/
namespace Etna.Design.StaleDaoAuthorization
open Etna.Statements NonVacuity NoVerifierSoundness

/-- Authorization at generation/checkpoint/nonce zero, with a finite uint256 deadline. -/
def request : Recovery.Request := ⟨0,0,[],[],0,limit256-1⟩

/-- Success-state view of the checked verifier-replacing upgrade at L1 block 16. -/
def rolledBack : ProtocolState.World := ProtocolState.applyRollback forgedWorld record0 12 16

/-- A later attempted execution, with checkpoint zero again. -/
def origin : Origin := ⟨0,17,17⟩

/-- The original bug's complete prefix now ends in rejection, despite restored checkpoint
and generation. The rollback uses the trusted genesis snapshot and consumes the nonce. -/
theorem stale_authorization_never_revives :
    (ProtocolState.recover world0 request ⟨0,14,14⟩ true true).isSome = true ∧
    (∀ r owner externalOK, ProtocolState.recover forgedWorld request r owner externalOK = none) ∧
    rolledBack.inbox.checkpoint = world0.inbox.checkpoint ∧ rolledBack.inbox.snapshot = world0.inbox.snapshot ∧
    rolledBack.inbox.snapshot < rolledBack.l1Block ∧
    ProtocolState.Trace world0 rolledBack ∧
    ProtocolState.recover rolledBack request origin true true = none ∧
    rolledBack.inbox.recoveryNonce = world0.inbox.recoveryNonce+1 := by
  have voided : ∀ r owner externalOK, ProtocolState.recover forgedWorld request r owner externalOK = none := by
    intro r owner externalOK
    unfold ProtocolState.recover
    rw [Recovery.stale_checkpoint_rejected _ _ _ _ _ _ (by decide +kernel)]
    rfl
  have trace : ProtocolState.Trace world0 rolledBack :=
    .step (.step (.refl _) (.landing (i := forgedInput) (leaves := []) (e := forgedEnv)
      (by decide) (by decide +kernel)))
      (.rollback record0 12 16 (by decide) (by decide +kernel) (by decide +kernel))
  exact ⟨by decide +kernel,voided,by decide +kernel,by decide +kernel,by decide +kernel,trace,
    by decide +kernel,by decide +kernel⟩

/-- No later sequence of landings, recoveries, registry edits or rollbacks revives it. -/
theorem stale_authorization_rejected_on_every_future {w : ProtocolState.World}
    (trace : ProtocolState.Trace rolledBack w) (r : Origin) (owner externalOK : Bool) :
    ProtocolState.recover w request r owner externalOK = none :=
  ProtocolState.consumed_authorization_never_revives trace request r owner externalOK (by decide +kernel)

/-- Deadline equality accepts; one second later rejects. -/
theorem recovery_deadline_boundary :
    (ProtocolState.recover world0 { request with validUntil := 14 } ⟨0,14,14⟩ true true).isSome = true ∧
    ProtocolState.recover world0 { request with validUntil := 14 } ⟨0,14,15⟩ true true = none := by decide +kernel

/-- Invalidation requires the initialized owner and exact nonce; overflow rejects. -/
theorem invalidation_checks :
    (Recovery.invalidateRecoveryNonce world0.inbox 0 true).isSome = true ∧
    Recovery.invalidateRecoveryNonce world0.inbox 0 false = none ∧
    Recovery.invalidateRecoveryNonce world0.inbox 1 true = none ∧
    Recovery.invalidateRecoveryNonce { world0.inbox with origins := [] } 0 true = none ∧
    Recovery.invalidateRecoveryNonce { world0.inbox with recoveryNonce := limit256-1 } (limit256-1) true = none := by decide +kernel

/-- Checked rollback and recovery cannot overflow the nonce, even with otherwise valid input. -/
theorem nonce_overflow_is_atomic :
    let w := { world0 with inbox := { world0.inbox with recoveryNonce := limit256-1 } }
    ProtocolState.rollback w record0 12 16 = none ∧
    ProtocolState.recover w { request with nonce := limit256-1 } ⟨0,14,14⟩ true true = none := by decide +kernel

/-- Nonce invalidation is a real public step in the same traces H1-H3 quantify over. -/
theorem invalidation_is_protocol_step :
    ProtocolState.Step world0 (ProtocolState.landed world0 (Recovery.applyInvalidation world0.inbox) 14) :=
  .invalidation (expected := 0) (owner := true) (by decide +kernel) (by decide +kernel)

end Etna.Design.StaleDaoAuthorization
