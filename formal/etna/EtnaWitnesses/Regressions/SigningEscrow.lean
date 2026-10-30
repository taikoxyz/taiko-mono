import EtnaProofs.SigningEscrow
import EtnaWitnesses.Counterexamples.HistoricalEscrow

namespace Etna.Design.SigningEscrowRegression
open Etna.Statements NonVacuity

/-- The Byzantine 1/6-power member's already-admissible evidence burns all its principal. -/
def evidenceA : Staking.Vote := Accountability.evidence (minorityVote 9 101)
def evidenceB : Staking.Vote := Accountability.evidence (minorityVote 9 102)
def burned : RegistryHistory.State :=
  (RegistryHistory.edit minorityWorld.registry minorityWorld.inbox 2 15 (.slash evidenceA evidenceB 0 0)).getD minorityWorld.registry
def afterBurn : ProtocolState.World := ProtocolState.registered minorityWorld burned 15
def rules : BlockValidity.Rules := rulesFor minorityEnv afterBurn [14] 16 1600
instance : DecidablePred rules.signature := fun v => inferInstanceAs (Decidable (signedMinority v))

private theorem old_entries : HistoricalContext.registryAt afterBurn.registry 12 = minorityMembers := by
  decide +kernel

private theorem chosen : Committee.chosen 1000000000 1000000000000000000 12 3 minorityMembers = minorityMembers := by
  unfold Committee.chosen
  rw [show minorityMembers.filter (Committee.eligible 1000000000 1000000000000000000 12) = minorityMembers by decide +kernel,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := Committee.rank) (by decide +kernel),
    show minorityMembers.take 3 = minorityMembers from rfl,
    List.mergeSort_of_pairwise (l := minorityMembers) (le := fun a b => decide (a.key ≤ b.key)) (by decide +kernel)]

private theorem elected : Committee.election 1000000000 1000000000000000000 12 3 minorityMembers = some minorityMembers := by
  unfold Committee.election
  rw [chosen]
  decide +kernel

private theorem active : Consensus.activeAt rules.consensus 1 = minorityZero := by
  change (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 3
    (HistoricalContext.registryAt afterBurn.registry 12)⟩ : Committee.Record) = minorityZero
  rw [old_entries,chosen]
  rfl

private theorem built : Built minorityEnv afterBurn rules := by
  have election : Deployment.GenesisElected afterBurn.inbox afterBurn.registry afterBurn.inbox.configuration := by
    change Committee.election 1000000000 1000000000000000000 12 3
      (HistoricalContext.registryAt afterBurn.registry 12) = some minorityMembers
    rw [old_entries,elected]
  refine ⟨[14],16,1600,build_rulesFor ⟨by decide +kernel,rfl,by decide +kernel,?_,election,by decide +kernel,
    by decide +kernel⟩ ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,?_,
    by decide,by decide⟩⟩
  · change (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 3
      (HistoricalContext.registryAt afterBurn.registry 12)⟩ : Committee.Record) = minorityZero
    rw [old_entries,chosen]
    rfl
  · change (Committee.election 1000000000 1000000000000000000 12 3
      (HistoricalContext.registryAt afterBurn.registry 12)).isSome = true
    rw [old_entries,elected]
    rfl

/-- A real accepted slash, not a free context input. Key 9 retains 1/6 of the fixed
committee's power above checkpoint 0 in current generation 0, while its principal is
already zero. This refutes continual positive capital backing, not the <1/3 safety rule
(recorded as SPEC section 12 item 19). -/
theorem current_voting_power_survives_full_slash :
    ProtocolState.Step minorityWorld afterBurn ∧
    ProtocolState.Trace minorityWorld afterBurn ∧
    Premises minorityWorld minorityEnv ∧ Built minorityEnv afterBurn rules ∧
    afterBurn.inbox.checkpoint.height = 0 ∧ afterBurn.inbox.generation = 0 ∧
    rules.consensus.generation = afterBurn.inbox.generation ∧
    afterBurn.inbox.checkpoint.height < 1 ∧
    member9 ∈ (Consensus.activeAt rules.consensus 1).members ∧
    Committee.power rules.consensus.unit member9 = 1000000000 ∧
    (afterBurn.registry.slots 2).key = 9 ∧ (afterBurn.registry.slots 2).released = false ∧
    (afterBurn.registry.slots 2).balance = 0 ∧
    (afterBurn.registry.slots 2).confirmedAt = none ∧
    Consensus.CommitValid rules.consensus rules.signature 1 0 101
      [minorityVote 7 101,minorityVote 8 101,minorityVote 9 101] ∧
    Staking.withdraw afterBurn.inbox (afterBurn.registry.slots 2) 53 1000000 1 = none := by
  have change : ProtocolState.Step minorityWorld afterBurn :=
    .modification (id := 2) (action := .slash evidenceA evidenceB 0 0) (by decide) rfl (by rfl)
  have member : member9 ∈ (Consensus.activeAt rules.consensus 1).members := by
    rw [active]
    decide +kernel
  have commit : Consensus.CommitValid rules.consensus rules.signature 1 0 101
      [minorityVote 7 101,minorityVote 8 101,minorityVote 9 101] := by
    unfold Consensus.CommitValid Consensus.VoteValid
    rw [active]
    refine ⟨by decide +kernel,?_,by decide +kernel⟩
    change Committee.election 1000000000 1000000000000000000 12 3
      (HistoricalContext.registryAt afterBurn.registry 12) = some minorityMembers
    rw [old_entries,elected]
  exact ⟨change,.step (.refl _) change,minority_premises,built,by decide +kernel,by decide +kernel,
    rfl,by decide +kernel,member,by decide +kernel,by decide +kernel,by decide +kernel,
    by decide +kernel,by decide +kernel,commit,by decide +kernel⟩

/-- Switching and reopening in a later domain cannot revive the retired generation. -/
def signer0 : Signer.State := ⟨FirstBatch.deployment,0,1,[],true,[]⟩
def signer1 : Signer.State := Signer.switchDomain signer0 FirstBatch.deployment 1 3 true true

theorem retired_generation_stays_closed_after_reopening :
    signer1.ready = false ∧ signer1.retired = [0] ∧
    (Signer.openSession signer1 1 true true).ready = true ∧
    Signer.sign (Signer.openSession signer1 1 true true)
      ⟨FirstBatch.deployment,0,true,⟨3,0,2⟩,101⟩ 55 true = none ∧
    (Signer.sign (Signer.openSession signer1 1 true true)
      ⟨FirstBatch.deployment,1,true,⟨3,0,2⟩,101⟩ 55 true).isSome = true := by
  decide +kernel

end Etna.Design.SigningEscrowRegression
