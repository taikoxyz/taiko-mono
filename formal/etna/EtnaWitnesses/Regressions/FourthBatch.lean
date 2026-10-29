import EtnaWitnesses.Regressions.ThirdBatch
import EtnaWitnesses.Regressions.Examples

/-! Kernel-checked regressions for the third review's model fixes: deployment immutables are
read from the Inbox/registry state, the §10 step 5 initial state (`Deployment.Genesis`) of the
deployed Worlds, its consequences along traces, and a deployed committee with several members
of different stakes whose commits need more than one signer. `decide +kernel` cannot unfold
`List.mergeSort` beyond one entry, so the election is evaluated once with
`List.mergeSort_of_pairwise`/`List.mergeSort_pair` and rewritten before kernel checks. -/
namespace Etna.Design.FourthBatch

/-! Immutables are state: no landing, FI or registry call input carries them. -/

/-- The (0, 18] landing needs maxBatchBlocks ≥ 18 in the Inbox itself. -/
theorem batch_limit_is_inbox_immutable :
    land { Examples.initial with maxBatchBlocks := 17 } Examples.full (Examples.leavesFor Examples.full)
      (Examples.environment Examples.full) = none ∧
    land { Examples.initial with maxBatchBlocks := 18 } Examples.full (Examples.leavesFor Examples.full)
      (Examples.environment Examples.full) =
        some (applyLanding { Examples.initial with maxBatchBlocks := 18 } Examples.full) := by decide +kernel

/-- minStake and the activation, exit and withdrawal delays come from the registry: the same
calls are rejected or take effect later under other registry immutables. -/
theorem registry_parameters_are_immutables :
    (RegistryHistory.register { SecondBatch.emptyRegistry with minStake := 101 } 7 51 100 10).isNone = true ∧
    ((RegistryHistory.register SecondBatch.emptyRegistry 7 51 100 10).map (fun s => (s.slots 0).activeFrom)) = some 12 ∧
    ((RegistryHistory.register { SecondBatch.emptyRegistry with activationDelay := 5 } 7 51 100 10).map
      (fun s => (s.slots 0).activeFrom)) = some 15 ∧
    ((RegistryHistory.edit SecondBatch.registered SecondBatch.settled 0 12 (.requestExit 51)).map
      (fun s => (s.slots 0).exitAt)) = some 13 ∧
    ((RegistryHistory.edit { SecondBatch.registered with exitDelay := 7 } SecondBatch.settled 0 12 (.requestExit 51)).map
      (fun s => (s.slots 0).exitAt)) = some 19 ∧
    (RegistryHistory.edit SecondBatch.confirmed SecondBatch.settled 0 15 (.withdraw 51)).isSome = true ∧
    (RegistryHistory.edit { SecondBatch.confirmed with withdrawalDelay := 2 } SecondBatch.settled 0 15
      (.withdraw 51)).isNone = true := by decide +kernel

/-- The mixed SecondBatch lifecycle keeps the slash bounty, minStake, delays, FI fee,
threshold and recipient with every other immutable, including across its two recoveries. -/
theorem mixed_lifecycle_keeps_immutables : SecondBatch.editedWorld.registry.slashBountyBps = 1000 ∧
    SecondBatch.editedWorld.registry.activationDelay = 2 ∧ SecondBatch.editedWorld.registry.withdrawalDelay = 1 ∧
    SecondBatch.editedWorld.inbox.forcedFee = 1 ∧ SecondBatch.editedWorld.inbox.protocolFeeRecipient = 9 ∧
    SecondBatch.editedWorld.adapters.recovery = SecondBatch.recoveryConfig :=
  have imm := ProtocolState.trace_preserves_immutables SecondBatch.mixed_lifecycle_trace
  ⟨imm.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,imm.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,
    imm.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2,imm.2.2.2.2.2.2.2.2.2.2.2.1,imm.2.2.2.2.2.2.2.2.2.2.2.2.2.1,
    congrArg ProtocolState.Adapters.recovery imm.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1⟩

/-! §10 step 5: ThirdBatch's deployed World is an initialized Inbox on block 0 (hash 1000,
stateRoot 10000). -/

theorem deployed_genesis : Deployment.Genesis ThirdBatch.deployed 1000 10000 := by
  refine ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
    ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,
    by unfold Deployment.GenesisElected; decide +kernel,by decide +kernel,rfl⟩
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · unfold RegistryHistory.IdentitiesValid
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel

/-- From genesis the recovery's `below` premise is derived: slot 284 (12) is below R = 20,
and the first generation-1 landing then stores R. -/
theorem deployed_recovery_from_genesis : ThirdBatch.deployed.inbox.snapshot < ThirdBatch.origin1.l1Block ∧
    ThirdBatch.deployed.inbox.snapshot ≤ ThirdBatch.landed1.snapshot := by
  obtain ⟨c,context,result⟩ := (Deployment.build_success ThirdBatch.generation_one_rules_built).2.2.2.2.2.2.2
  have same : c = ThirdBatch.rules1.consensus := by rw [result]
  subst same
  have both := Deployment.genesis_snapshot_monotone_across_recovery deployed_genesis (.refl _) (by decide)
    ThirdBatch.deployed_recover context
    (finish := ThirdBatch.landed1)
    (.step (s := ThirdBatch.recoveredWorld.inbox) (i := ThirdBatch.statement1.input) (leaves := [])
      (e := ThirdBatch.env1) (.refl _) (by decide +kernel) rfl ThirdBatch.generation_one_valid_batch rfl)
  exact ⟨both.1,both.2.1⟩

/-- Every state reachable from the deployed genesis keeps Core, the §10 constraints and
committee 0's registry snapshot. -/
theorem deployed_trace_from_genesis : ProtocolState.Core ThirdBatch.landedWorld1 ∧
    Deployment.Constraints ThirdBatch.landedWorld1.inbox ThirdBatch.landedWorld1.inbox.configuration ∧
    Deployment.RegistryConstraints ThirdBatch.landedWorld1.registry :=
  have facts := Deployment.genesis_trace_invariants deployed_genesis ThirdBatch.deployed_trace
  ⟨facts.1,facts.2.1,facts.2.2.1⟩

/-! A deployed committee of two out of three registrants with different stakes. -/

/-- Keys 9, 7, 8 with 3, 2 and 1 TAIKO register in L1 block 10 and activate at 12. -/
def trio : RegistryHistory.State :=
  let one := (RegistryHistory.register SecondBatch.emptyRegistry 9 51 3000000000000000000 10).getD SecondBatch.emptyRegistry
  let two := (RegistryHistory.register one 7 52 2000000000000000000 10).getD one
  (RegistryHistory.register two 8 53 1000000000000000000 10).getD two
def e9 : Committee.Entry := ⟨9,3000000000000000000,12,Staking.noExit⟩
def e7 : Committee.Entry := ⟨7,2000000000000000000,12,Staking.noExit⟩
def e8 : Committee.Entry := ⟨8,1000000000000000000,12,Staking.noExit⟩
/-- n_max = 2 keeps the two largest stakes, ordered by key. -/
def cfgM : Deployment.Config := ⟨1000000000,1000000000000000000,2,100⟩
def membersM : List Committee.Entry := [e7,e9]
def zeroRecordM : Committee.Record := ⟨0,12,membersM⟩
def inboxM : State := { ThirdBatch.deployedInbox with configuration := cfgM,committeeZeroRecord := zeroRecordM }
def configHashM (words : List Encoding.Word) : Hash := if words = Deployment.words inboxM cfgM then 77 else 78
def worldM : ProtocolState.World :=
  ⟨inboxM,trio,[],Committee.recoverySchedule zeroRecordM,14,⟨configHashM,fun _ => 12,SecondBatch.recoveryConfig⟩⟩
def archiveM : List Nat := [14,15]
def contextM : Consensus.Context := HistoricalContext.derive inboxM trio (Deployment.parameters inboxM cfgM) archiveM
def rulesM : BlockValidity.Rules :=
  { SecondBatch.historicalRules with
    consensus := contextM,gridK := inboxM.gridK,committeeConfig := inboxM.committeeConfig,
    maxAnchorAge := inboxM.maxAnchorAge,forcedDelay := inboxM.forcedDelay,unsettled := cfgM.unsettled,
    configHash := configHashM,committeeHash := fun _ => 12 }
instance : DecidablePred rulesM.signature := fun _ => inferInstanceAs (Decidable True)

theorem trio_snapshot : HistoricalContext.registryAt trio 12 = [e9,e7,e8] := by decide +kernel

theorem trio_chosen : Committee.chosen 1000000000 1000000000000000000 12 2 [e9,e7,e8] = membersM := by
  have eligible : [e9,e7,e8].filter (Committee.eligible 1000000000 1000000000000000000 12) = [e9,e7,e8] := by
    decide +kernel
  have ranked : [e9,e7,e8].mergeSort Committee.rank = [e9,e7,e8] := List.mergeSort_of_pairwise (by decide +kernel)
  unfold Committee.chosen
  rw [eligible,ranked,show [e9,e7,e8].take 2 = [e9,e7] from rfl,List.mergeSort_pair]
  decide +kernel

theorem trio_election : Committee.election 1000000000 1000000000000000000 12 2 [e9,e7,e8] = some membersM := by
  unfold Committee.election
  simp only [trio_chosen]
  decide +kernel

theorem active_members (h : Nat) (early : h ≤ 2) : Consensus.activeAt contextM h = zeroRecordM := by
  have before : Consensus.activeAt contextM h = Consensus.initial contextM :=
    Consensus.active_before_switch contextM h (by
      change ((h-1)/3)*3-1 ≤ 0
      omega)
  rw [before]
  show (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 2 (HistoricalContext.registryAt trio 12)⟩ :
    Committee.Record) = zeroRecordM
  rw [trio_snapshot,trio_chosen]
  rfl

theorem election_valid_m : Consensus.ElectionValid contextM zeroRecordM := by
  show Committee.election 1000000000 1000000000000000000 12 2 (HistoricalContext.registryAt trio 12) = some membersM
  rw [trio_snapshot,trio_election]

/-- `Deployment.build` succeeds on the deployed World whose committee 0 is the two-member
election, and that World is an initialized genesis. -/
theorem multi_member_build : Deployment.build worldM cfgM archiveM SecondBatch.historicalRules = some rulesM ∧
    Deployment.Genesis worldM 1000 10000 := by
  have genesis : Deployment.genesis inboxM trio cfgM archiveM = zeroRecordM := by
    show (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 2 (HistoricalContext.registryAt trio 12)⟩ :
      Committee.Record) = zeroRecordM
    rw [trio_snapshot,trio_chosen]
    rfl
  have elected : Deployment.GenesisElected inboxM trio cfgM := by
    show Committee.election 1000000000 1000000000000000000 12 2 (HistoricalContext.registryAt trio 12) = some membersM
    rw [trio_snapshot,trio_election]
  have ready : HistoricalContext.Ready worldM.inbox worldM.registry (Deployment.parameters worldM.inbox cfgM) archiveM := by
    refine ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,?_,
      by decide,by decide⟩
    show (Committee.election 1000000000 1000000000000000000 12 2 (HistoricalContext.registryAt trio 12)).isSome = true
    rw [trio_snapshot,trio_election]
    rfl
  refine ⟨?_,⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
    ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,elected,
    by decide +kernel,rfl⟩⟩
  · unfold Deployment.build
    rw [ite_eq_left (⟨by decide +kernel,rfl,by decide +kernel,genesis,elected,rfl,by decide +kernel⟩ :
      Deployment.Constraints worldM.inbox cfgM ∧ cfgM = worldM.inbox.configuration ∧
      worldM.inbox.committeeConfig = worldM.adapters.configHash (Deployment.words worldM.inbox cfgM) ∧
      Deployment.genesis worldM.inbox worldM.registry cfgM archiveM = worldM.inbox.committeeZeroRecord ∧
      Deployment.GenesisElected worldM.inbox worldM.registry cfgM ∧
      worldM.inbox.committeeZero = worldM.adapters.recordHash worldM.inbox.committeeZeroRecord ∧
      Deployment.RegistryConstraints worldM.registry)]
    unfold HistoricalContext.build
    rw [ite_eq_left ready]
    rfl
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · unfold RegistryHistory.IdentitiesValid
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel

def voteM (key : Hash) : Consensus.Vote := ⟨FirstBatch.deployment,0,1,0,2,201,key⟩
/-- SecondBatch's height-1 block on the same archive, signed by both members. -/
def blockM : BlockValidity.Block := { SecondBatch.historicalBlock with votes := [voteM 7,voteM 9] }

/-- Power 2·10^9 + 3·10^9: key 9 alone (3/5) is not above 2/3, keys 7 and 9 together are;
key 8, registered but outside n_max, cannot sign. -/
theorem multi_member_commit :
    Consensus.CommitValid rulesM.consensus rulesM.signature 1 0 201 [voteM 7,voteM 9] ∧
    ¬ Consensus.CommitValid rulesM.consensus rulesM.signature 1 0 201 [voteM 9] ∧
    ¬ Consensus.CommitValid rulesM.consensus rulesM.signature 1 0 201 [voteM 7,voteM 9,voteM 8] := by
  have active : Consensus.activeAt rulesM.consensus 1 = zeroRecordM := active_members 1 (by decide)
  refine ⟨?_,?_,?_⟩
  · unfold Consensus.CommitValid Consensus.VoteValid
    rw [active]
    exact ⟨by decide,election_valid_m,by decide +kernel⟩
  · intro valid
    have quorum := Consensus.commit_strict_quorum valid
    rw [active] at quorum
    exact absurd quorum (by decide +kernel)
  · intro valid
    have signer := (valid.2.2.2.1 (voteM 8) (by decide)).2.2.2.2.2.2.1
    rw [active] at signer
    exact absurd signer (by decide +kernel)

/-- The built rules accept the two-signer block and reject it with only the larger stake's
signature: a block-level deployed regression with several eligible members. -/
theorem multi_member_block :
    BlockValidity.Valid rulesM SecondBatch.parentHeader blockM ∧
    ¬ BlockValidity.Valid rulesM SecondBatch.parentHeader { blockM with votes := [voteM 9] } := by
  refine ⟨⟨by decide +kernel,by decide,by decide +kernel,by decide +kernel,by decide +kernel,
    multi_member_commit.1,by decide +kernel,by decide +kernel⟩,fun valid => multi_member_commit.2.1 valid.2.2.2.2.2.1⟩

/-- Genesis consequences on the multi-member deployment: slot 284 fits the built context at
the generation-0 floor genesisCutoff = 12. -/
theorem multi_member_genesis_snapshot : Settlement.floor rulesM.consensus = 12 ∧
    Settlement.SnapshotFits rulesM.consensus worldM.inbox :=
  Deployment.genesis_snapshot_fits multi_member_build.2 multi_member_build.1

end Etna.Design.FourthBatch
