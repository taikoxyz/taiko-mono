import EtnaWitnesses.Counterexamples.NoVerifierSoundness

/-! Scope counterexample (an open design issue): a governance-recovery authorization that a landing
voided becomes executable again after a verifier-failure rollback.

8.1 (spec L469): "expectedC is set to the current c and fixed at authorization, so any landing
after that makes the call unexecutable"; 8.3 (spec L483): "Landing first invalidates an old
authorization ... Inbox need not cancel old authorizations individually"; §8 "Verifier failure"
(spec L457): "The rollback returns c to an earlier value, so the DAO also cancels every
unexecuted recovery authorization". The Inbox binds an authorization only to (generation, c), and
a rollback restores an earlier c without changing the generation, so cancelling is left to the
DAO. Taiko's DAO has no cancel for an approved proposal, and optimistic proposals do not
expire, so the spec's mitigation is not available as written. The model cannot express a DAO
proposal's lifecycle; it shows the Inbox side: the same `recover` call is rejected after the
landing and accepted after the rollback.

The run, from the non-vacuity deployment:
1. L1 block 14: the DAO authorizes `recover(0, 0, [], [])`; it would execute then.
2. L1 block 15: the forged landing of `NoVerifierSoundness` moves c to 1; the authorization
   is now unexecutable with any origin.
3. L1 block 16: the verifier-failure rollback restores block 0's record and the trusted slot
   284 value (genesisCutoff 12, below the rollback's block).
4. L1 block 17: the stale authorization executes and starts generation 1 at c = 0.
Caveat: this deployment has one validator, so the DAO's 8.1 committee check (spec L470, no party
at or above 1/3) would not pass on it; that precondition is irrelevant here, since the revival
depends only on the (generation, c) binding the Inbox checks. -/
namespace Etna.Design.StaleDaoAuthorization
open Etna.Statements NonVacuity NoVerifierSoundness

/-- The DAO's authorization, bound to generation 0 and c = 0. -/
def request : Recovery.Request := ⟨0,0,[],[]⟩

/-- L1 block 16: rollback to block 0's record with the trusted snapshot 12. -/
def rolledBack : ProtocolState.World := ProtocolState.rollback forgedWorld record0 12 16

/-- L1 block 17: the stale authorization executes (R = 17). -/
def origin : Origin := ⟨0,17,17⟩
def revived : ProtocolState.World :=
  ProtocolState.recovered rolledBack request origin
    (Recovery.applyRecovery (ProtocolState.recoveryView rolledBack) request SecondBatch.recoveryConfig origin)

/-- A voided recovery authorization revives across a rollback. The authorization executes on the
deployed World; after a landing it is rejected for every origin and caller; after a rollback that
restores c = 0 with a trusted snapshot (below the rollback's block, the value initialization
wrote), the same authorization executes along a protocol trace and starts generation 1. -/
theorem stale_authorization_revives :
    (ProtocolState.recover world0 request ⟨0,14,14⟩ true true).isSome = true ∧
    (∀ r owner externalOK, ProtocolState.recover forgedWorld request r owner externalOK = none) ∧
    rolledBack.inbox.checkpoint = world0.inbox.checkpoint ∧ rolledBack.inbox.snapshot = world0.inbox.snapshot ∧
    rolledBack.inbox.snapshot < rolledBack.l1Block ∧
    ProtocolState.Trace world0 revived ∧ revived.inbox.generation = 1 ∧ revived.inbox.origin = origin := by
  have voided : ∀ r owner externalOK, ProtocolState.recover forgedWorld request r owner externalOK = none := by
    intro r owner externalOK
    unfold ProtocolState.recover
    rw [Recovery.stale_checkpoint_rejected _ _ _ _ _ _ (by decide +kernel)]
    rfl
  have trace : ProtocolState.Trace world0 revived :=
    .step (.step (.step (.refl _)
      (.landing (i := forgedInput) (leaves := []) (e := forgedEnv) (by decide) (by decide +kernel)))
      (.rollback record0 12 16 (by decide) (by decide +kernel)))
      (.recovery (owner := true) (externalOK := true) (by decide) (by decide +kernel))
  exact ⟨by decide +kernel,voided,by decide +kernel,by decide +kernel,by decide +kernel,trace,by decide +kernel,
    by decide +kernel⟩

end Etna.Design.StaleDaoAuthorization
