import EtnaWitnesses.NonVacuity.Current
import EtnaProofs.CurrentProtocolFinality

/-! A separate honest execution profile for the same fully realized environment.
The authenticated environment, registry and proof relation are unchanged. This finite
normalization witnesses the model's honest-locking premise; it does not refine a
running production CometBFT implementation. -/
namespace Etna.Design.Current.Protocol.HonestAgreement
open Etna.Design Etna.Design.Current Protocol
open _root_.Etna.Design.Current.Protocol.NonVacuity (env registry genesis source)
set_option maxRecDepth 30000
set_option maxHeartbeats 400000
set_option linter.unusedSimpArgs false

def chosenValue (generation : Nat) : Hash := if generation = 0 then 201 else 202

def action (generation round : Nat) : Locking.RoundAction :=
  if round = 0 then
    { prevote := some (some (chosenValue generation)),precommit := some (some (chosenValue generation)) }
  else {}

def execution (generation : Nat) : Locking.Execution where
  prevotes := fun _ round value => round = 0 ∧ value = some (chosenValue generation)
  precommits := fun _ round value => round = 0 ∧ value = some (chosenValue generation)
  actions := fun _ round => action generation round
  locks := fun _ round => if round = 0 then none else some (0,chosenValue generation)

def honestEngine : Finality.Engine := ⟨fun generation _ => execution generation,fun _ _ _ => true,false⟩

 theorem positive_committee {c : Consensus.Context} {signature : Consensus.Vote → Prop}
    {height round value : Nat} {votes : List Consensus.Vote}
    (valid : Consensus.CommitValid c signature height round value votes) :
    0 < Committee.totalPower c.unit (Consensus.activeAt c height).members := by
  have quorum := Consensus.commit_strict_quorum valid
  have bounded := Consensus.signed_power_bounded c (Consensus.activeAt c height).members (votes.map Consensus.Vote.key)
  omega

 theorem all_member_quorum (unit : Nat) (members : List Committee.Entry)
    (positive : 0 < Committee.totalPower unit members) :
    Locking.Quorum unit members (members.map Committee.Entry.key) := by
  have full : members.filter (fun e => (members.map Committee.Entry.key).contains e.key) = members := by
    apply List.filter_eq_self.mpr
    intro entry member
    simpa only [List.contains_iff_mem] using List.mem_map_of_mem (f := Committee.Entry.key) member
  unfold Locking.Quorum Locking.power
  rw [full]
  omega

 theorem polc (unit : Nat) (members : List Committee.Entry) (generation : Nat)
    (positive : 0 < Committee.totalPower unit members) :
    Locking.PoLC unit members (execution generation) 0 (some (chosenValue generation)) := by
  exact ⟨members.map Committee.Entry.key,all_member_quorum unit members positive,fun _ _ => ⟨rfl,rfl⟩⟩

 theorem honest_rules (unit : Nat) (members : List Committee.Entry) (generation : Nat)
    (positive : 0 < Committee.totalPower unit members) :
    Locking.HonestRules unit members (fun _ => true) false (execution generation) := by
  constructor
  · intro key _
    rfl
  · intro key _ round
    by_cases first : round = 0
    · subst round
      simpa [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,Locking.VoteAllowed,
        execution,action] using polc unit members generation positive
    · simp [Locking.RoundStep,Locking.UnlockAllowed,Locking.afterPrevote,execution,action,first]
  · intro key _ round value signed
    obtain ⟨rfl,rfl⟩ := signed
    rfl
  · intro key _ round value signed
    obtain ⟨rfl,rfl⟩ := signed
    rfl

 theorem honest_at {cfg : Finality.Config} {c : Consensus.Context} {height : Nat}
    (positive : 0 < Committee.totalPower c.unit (Consensus.activeAt c height).members) :
    Finality.HonestAt honestEngine cfg c height := by
  constructor
  · exact honest_rules c.unit (Consensus.activeAt c height).members cfg.generation positive
  · change 3 * Committee.totalPower c.unit
      ((Consensus.activeAt c height).members.filter (fun _ => false)) <
        Committee.totalPower c.unit (Consensus.activeAt c height).members
    have empty : (Consensus.activeAt c height).members.filter (fun _ => false) = [] := by
      apply List.filter_eq_nil_iff.mpr
      intro entry member
      simp
    rw [empty]
    simpa [Committee.totalPower] using positive

 theorem honest_executions (w : World) : ProtocolFinality.HonestExecutions honestEngine env w := by
  intro origin blocks reference _ chain pair member
  have valid := Blocks.chain_pairs_valid chain pair member
  exact honest_at (positive_committee valid.commit)

 theorem vote_attribution_of_authenticated {c : Consensus.Context} {height round value : Nat}
    {v : Consensus.Vote} (valid : Consensus.VoteValid c env.signature height round value v) :
    (execution c.generation).precommits v.key round (some value) := by
  obtain ⟨_,generation,_,sameRound,_,sameValue,_,signature⟩ := valid
  change v = NonVacuity.vote ∨ v = NonVacuity.recoveredVote at signature
  change round = 0 ∧ some value = some (chosenValue c.generation)
  rcases signature with rfl | rfl
  · have gen : c.generation = 0 := generation.symm
    have rnd : round = 0 := sameRound.symm
    have val : value = 201 := sameValue.symm
    simp [gen,rnd,val,chosenValue]
  · have gen : c.generation = 1 := generation.symm
    have rnd : round = 0 := sameRound.symm
    have val : value = 202 := sameValue.symm
    simp [gen,rnd,val,chosenValue]

 theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution honestEngine env w := by
  intro origin blocks reference _ chain pair member v present
  have valid := Blocks.chain_pairs_valid chain pair member
  exact vote_attribution_of_authenticated (valid.commit.2.2.2.1 v present)

 theorem premises : Etna.Statements.Current.Premises env registry honestEngine := by
  have original := NonVacuity.premises
  exact {
    currentPrimitives := original.currentPrimitives
    currentVerifierSound := original.currentVerifierSound
    currentStandardToken := original.currentStandardToken
    currentSignatureAgreement := original.currentSignatureAgreement
    currentBountyBound := original.currentBountyBound
    currentCodec := original.currentCodec
    currentVoteAttribution := fun w _ => vote_attribution w
    currentClock := original.currentClock
    currentCatalogueHash := original.currentCatalogueHash
    currentReferenceBinding := original.currentReferenceBinding
    currentRegistryGenesis := original.currentRegistryGenesis
    currentSignatureSound := original.currentSignatureSound
    currentSelfAllowance := original.currentSelfAllowance
    currentUnzenExtension := original.currentUnzenExtension
    currentEvidenceWindow := original.currentEvidenceWindow }

 theorem current_agreement : ProtocolFinality.CurrentAgreement env (source env) :=
  (ProtocolFinality.current_h2 (engine := honestEngine) (NonVacuity.source_reachable env)
    premises.currentStandardToken premises.currentSignatureAgreement
    (by decide +kernel) premises.currentBountyBound
    (premises.currentCodec _ (NonVacuity.source_reachable env))
    (honest_executions _) (vote_attribution _)).2

 theorem first_chain :
    Blocks.Chain (policy env (source env) ([NonVacuity.block].map Blocks.Block.header) 2)
      genesis [NonVacuity.block] :=
  ⟨NonVacuity.first_valid,True.intro⟩

/-- An actual nonempty valid chain reaches the current agreement theorem under all
fifteen original environment premises and an honest, attributed execution profile. -/
theorem nonempty_honest_agreement :
    Etna.Statements.Current.Premises env registry honestEngine ∧
    Trace env (empty env registry) (source env) ∧
    ProtocolFinality.HonestExecutions honestEngine env (source env) ∧
    ProtocolFinality.CurrentAgreement env (source env) ∧
    [NonVacuity.block] ≠ [] ∧
    Blocks.Chain (policy env (source env) ([NonVacuity.block].map Blocks.Block.header) 2)
      genesis [NonVacuity.block] ∧
    Finality.HeaderAgreement ([NonVacuity.block].map Blocks.Block.header)
      ([NonVacuity.block].map Blocks.Block.header) := by
  refine ⟨premises,NonVacuity.source_reachable env,honest_executions _,current_agreement,by simp,first_chain,?_⟩
  exact current_agreement genesis [NonVacuity.block] [NonVacuity.block] 2 2 (by decide +kernel) first_chain first_chain

end Etna.Design.Current.Protocol.HonestAgreement
