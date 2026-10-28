import EtnaWitnesses.NonVacuity.Premises

/-! Scope counterexample: what the dropped `trustedRollback` premise protected. This is not a
failure of H1–H3; it shows that H2's "slashable" conclusion only bites while the stake is live,
and that the stake stays live only if the rollback restores a trusted snapshot.

§8 "Verifier failure" (EN L457): the rollback restores "activeCommitteeSnapshot (284) to the
values written by the last trusted landing ... if there is none, restore the initialization
values", and "the registry re-checks every exit confirmation against the restored snapshot".
4.1 (EN L141): "confirmExit ... the Inbox must have activeCommitteeSnapshot ≥ exitEffectiveL1";
4.1 (EN L142): "Confirmation requires that a landed committee no longer includes the stake".
The model's rollback step takes any snapshot (`ProtocolState.Step.rollback`): which value the DAO
restores is a governance trust boundary. A `trustedRollback` premise (`SoundStep.rollback`:
snapshot below the rollback's block) was considered and dropped because H1–H3 do not use it; the spec's real
duty (restore the last trusted landing's value) is stronger still.

The run, from the non-vacuity deployment (one validator, key 7, the whole committee):
1. L1 block 15: key 7's owner requests an exit (effective at L1 block 16).
2. L1 block 16: a rollback restores checkpoint 0 with slot 284 = 1000, above its own block
   (no landing ever wrote 1000; the trusted value is genesisCutoff 12).
3. L1 block 16: the exit is confirmed (16 ≤ 1000); under the trusted value 12 it is rejected.
4. L1 block 17: after the withdrawal delay the owner withdraws the whole stake.
On the final World the rules the deployment builds still make key 7 the whole active committee,
and if key 7 signs two blocks at height 1, round 0, both commits are valid. For such signers
H2's accountability conjunct concludes `Slashable`: every live staked bond with the key loses its
stake. Here no bond holds key 7 any more and a slash of its old slot fails with any evidence, so
that conclusion constrains nothing. H2's accountability bites only if rollbacks restore trusted
snapshots. The registry's withdrawal delay here is 1 block; a realistic withdrawalDelay only
postpones the escape: the bond stays slashable until the delay ends, then withdraws the same way. -/
namespace Etna.Design.UntrustedRollback
open Etna.Statements NonVacuity

/-- L1 block 15: key 7's owner (51) requests an exit; exitEffectiveL1 = 16. -/
def exitRequested : RegistryHistory.State :=
  (RegistryHistory.edit world0.registry world0.inbox 0 15 (.requestExit 51)).getD world0.registry
def worldA : ProtocolState.World := ProtocolState.registered world0 exitRequested 15

/-- L1 block 16: a rollback to checkpoint 0 that restores slot 284 = 1000. -/
def worldB : ProtocolState.World := ProtocolState.rollback worldA record0 1000 16

/-- The same rollback restoring the trusted value, genesisCutoff 12 (no landing yet). -/
def trustedB : ProtocolState.World := ProtocolState.rollback worldA record0 12 16

/-- L1 block 16: anyone confirms the exit. -/
def confirmed : RegistryHistory.State := (RegistryHistory.edit worldB.registry worldB.inbox 0 16 .confirm).getD worldB.registry
def worldC : ProtocolState.World := ProtocolState.registered worldB confirmed 16

/-- L1 block 17: the owner withdraws (the registry's withdrawal delay is 1 block here). -/
def withdrawn : RegistryHistory.State :=
  (RegistryHistory.edit worldC.registry worldC.inbox 0 17 (.withdraw 51)).getD worldC.registry
def worldD : ProtocolState.World := ProtocolState.registered worldC withdrawn 17

/-- Key 7's holder signs whatever it likes. -/
def byzantine : Environment := { relations with signature := fun v => v.key = 7 }

def archiveD : List Nat := [14,15]
def rulesD : BlockValidity.Rules := rulesFor byzantine worldD archiveD 16 1600
instance : DecidablePred rulesD.signature := fun v => inferInstanceAs (Decidable (v.key = 7))

private theorem rollback_trace : ProtocolState.Trace world0 worldD :=
  .step (.step (.step (.step (.refl _)
    (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl)))
    (.rollback record0 1000 16 (by decide) (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)))
    (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))

/-- An untrusted rollback snapshot lets a committee member withdraw before it can be slashed.
Along a protocol trace from the deployment: the rollback restores slot 284 = 1000, not below its
own L1 block (16), where the trusted value is 12; under 12 the exit confirmation is rejected,
under 1000 it succeeds and the owner withdraws. On the final World key 7 still is the whole
active committee of the rules the deployment builds, two commits it signed for different blocks
at height 1, round 0 are both valid, yet no slot holds any stake and a slash of key 7's old slot
fails with any evidence. -/
theorem untrusted_snapshot_frees_committee_stake :
    ProtocolState.Trace world0 worldD ∧ worldB.l1Block ≤ worldB.inbox.snapshot ∧ trustedB.inbox.snapshot < trustedB.l1Block ∧
    (RegistryHistory.edit trustedB.registry trustedB.inbox 0 16 .confirm).isNone = true ∧
    (RegistryHistory.edit worldB.registry worldB.inbox 0 16 .confirm).isSome = true ∧
    worldD.registry.nextId = 1 ∧ worldD.registry.slots 0 = ⟨0,0,0,0,0,true,none⟩ ∧
    (∀ a b sigA sigB, RegistryHistory.edit worldD.registry worldD.inbox 0 18 (.slash a b sigA sigB) = none) ∧
    Built byzantine worldD rulesD ∧ (Consensus.activeAt rulesD.consensus 1).members.map Committee.Entry.key = [7] ∧
    Consensus.CommitValid rulesD.consensus rulesD.signature 1 0 201 [vote 0 1 201] ∧
    Consensus.CommitValid rulesD.consensus rulesD.signature 1 0 202 [vote 0 1 202] := by
  have slot : worldD.registry.slots 0 = ⟨0,0,0,0,0,true,none⟩ := by decide +kernel
  refine ⟨rollback_trace,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,slot,?_,
    ⟨archiveD,16,1600,build_rulesFor (by decide +kernel) (by decide +kernel)⟩,by decide +kernel,by decide +kernel,
    by decide +kernel⟩
  intro a b sigA sigB
  unfold RegistryHistory.edit RegistryHistory.editBond
  rw [slot]
  simp [Staking.slashDouble]

end Etna.Design.UntrustedRollback
