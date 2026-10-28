import EtnaWitnesses.NonVacuity.Premises

/-! Scope counterexample (an open design issue): stake registered after the DAO authorizes a
governance recovery can join, and here capture, the recovery committee.

8.1 (EN L470): before authorizing, the DAO "checks a nonempty intended set, more than 2/3 online
power, no party at or above 1/3"; 8 step 5 (EN L463): nodes "select the committee directly from
the registry snapshot at execution block R under 4.3 ... other already active candidates may
enter"; 4.1 (EN L128): a registration activates after `activationDelay` L1 blocks, which §10
only requires to be positive. The call `recover(expectedGeneration, expectedC, exclusions,
fiToClear)` binds no registry bound, so the committee the DAO checked and the one R elects can
differ by every registration that activates between authorization and execution. The exclusion
list cannot help: it is fixed at authorization, and each entry must still match an existing,
unreleased bond (8 step 2, EN L460), which the late stake was not yet. L470 asks for the check
"before scheduling and executing", but a check at execution cannot change the outcome: the DAO
cannot stop a scheduled call then (Taiko's DAO has no cancel for an approved proposal; see
`StaleDaoAuthorization`), and the call's exclusion list is fixed.

The deployment: n_max = 5, and four honest parties (keys 7-10) with 1 TAIKO each make up
committee 0. The run:
1. L1 block 14: the DAO authorizes `recover(0, 0, [], [])`. The committee R would elect then is
   the four parties, nonempty and each holding 1/4 of the power, below 1/3: L470's check passes
   (online power is not modelled). Key 66 has never registered.
2. L1 block 15: key 66 registers 9 TAIKO (active from block 17).
3. L1 block 20: the same authorization executes with R = 20 (nothing it binds has changed).
The model's own election at R (the recovery schedule, and the rules the deployment builds for
generation 1) gives keys 7-10 and 66, and key 66 holds 9/13 of the power, more than 2/3: its
precommit alone is a valid commit. A suggested spec fix: bind the authorization to a registry
bound, e.g. a `maxActiveFromL1` in the recover call so that only entries active by the DAO's
checked block are eligible at R. -/
namespace Etna.Design.RecoveryCapture
open Etna.Statements NonVacuity

/-- The deployed configuration: vp_unit 10^9, s_min 1 TAIKO, n_max 5, U = 100. -/
def cfgR : Deployment.Config := ⟨1000000000,1000000000000000000,5,100⟩

/-- An honest party: key `key`, 1 TAIKO, active from L1 block 12, no exit. -/
def party (key : Nat) : Committee.Entry := ⟨key,1000000000000000000,12,Staking.noExit⟩
def parties : List Committee.Entry := [party 7,party 8,party 9,party 10]

/-- The late registrant as the election reads it: key 66, 9 TAIKO, active from L1 block 17. -/
def late : Committee.Entry := ⟨66,9000000000000000000,17,Staking.noExit⟩

/-- Keys 7-10 (owners 51-54) register 1 TAIKO each in L1 block 10. -/
def honestRegistry : RegistryHistory.State :=
  let empty := SecondBatch.emptyRegistry
  let r7 := (RegistryHistory.register empty 7 51 1000000000000000000 10).getD empty
  let r8 := (RegistryHistory.register r7 8 52 1000000000000000000 10).getD r7
  let r9 := (RegistryHistory.register r8 9 53 1000000000000000000 10).getD r8
  (RegistryHistory.register r9 10 54 1000000000000000000 10).getD r9

def configWordsR : List Encoding.Word :=
  Encoding.configWords FirstBatch.deployment.l2ChainId FirstBatch.deployment.registry cfgR.unit cfgR.minimum
    cfgR.nMax cfgR.unsettled

def zeroRecordR : Committee.Record := ⟨0,12,parties⟩

/-- The non-vacuity Inbox (block 0's header, L = 10) with this configuration and committee 0. -/
def inboxD : State :=
  { inbox0 with committeeConfig := configHash configWordsR,configuration := cfgR,committeeZeroRecord := zeroRecordR }

/-- The initialized World at L1 block 14. -/
def deployed : ProtocolState.World :=
  ⟨inboxD,honestRegistry,[],Committee.recoverySchedule zeroRecordR,14,⟨configHash,fun _ => 12,SecondBatch.recoveryConfig⟩⟩

/-- The DAO's authorization: generation 0, checkpoint 0, no exclusions, no FI blanking. -/
def request : Recovery.Request := ⟨0,0,[],[]⟩

/-- L1 block 15: key 66 (owner 99) registers 9 TAIKO. -/
def lateRegistry : RegistryHistory.State :=
  (RegistryHistory.register deployed.registry 66 99 9000000000000000000 15).getD deployed.registry
def worldLate : ProtocolState.World := ProtocolState.registered deployed lateRegistry 15

/-- L1 block 20: the authorized recovery executes (R = 20). -/
def origin : Origin := ⟨0,20,20⟩
def worldR : ProtocolState.World :=
  ProtocolState.recovered worldLate request origin
    (Recovery.applyRecovery (ProtocolState.recoveryView worldLate) request SecondBatch.recoveryConfig origin)

/-- Key 66's holder signs whatever it likes; nobody else signs. -/
def attacker : Environment := { relations with signature := fun v => v.key = 66 }

def rulesR : BlockValidity.Rules := rulesFor attacker worldR [14] 21 2100
instance : DecidablePred rulesR.signature := fun v => inferInstanceAs (Decidable (v.key = 66))

/-- Key 66's precommit for Comet block 666 at height 1 of generation 1. -/
def lateVote : Consensus.Vote := ⟨FirstBatch.deployment,1,1,0,2,666,66⟩

/-! `decide +kernel` cannot unfold `List.mergeSort` beyond one entry, so each election is
computed once: a sorted permutation of the input is the `mergeSort` result
(`List.Perm.eq_of_pairwise`), and both orders the election uses are total and transitive. -/

private theorem sorted_eq {α : Type} {le : α → α → Bool} {l target : List α}
    (trans : ∀ a b c, le a b = true → le b c = true → le a c = true) (total : ∀ a b, (le a b || le b a) = true)
    (antisym : ∀ a ∈ target, ∀ b ∈ target, le a b = true → le b a = true → a = b)
    (sorted : target.Pairwise fun a b => le a b = true) (perm : l.Perm target) : l.mergeSort le = target :=
  have same : (l.mergeSort le).Perm target := (List.mergeSort_perm l le).trans perm
  List.Perm.eq_of_pairwise (fun a b ha hb => antisym a (same.subset ha) b hb) (List.pairwise_mergeSort trans total l)
    sorted same

private theorem rank_trans :
    ∀ a b c, Committee.rank a b = true → Committee.rank b c = true → Committee.rank a c = true := by
  intro a b c ab bc
  simp only [Committee.rank,decide_eq_true_eq] at ab bc ⊢
  rcases ab with ab | ⟨ab,kab⟩ <;> rcases bc with bc | ⟨bc,kbc⟩
  · exact Or.inl (Nat.lt_trans bc ab)
  · exact Or.inl (bc ▸ ab)
  · exact Or.inl (ab ▸ bc)
  · exact Or.inr ⟨ab.trans bc,Nat.le_trans kab kbc⟩

private theorem rank_total : ∀ a b, (Committee.rank a b || Committee.rank b a) = true := by
  intro a b
  simp only [Committee.rank,Bool.or_eq_true,decide_eq_true_eq]
  rcases Nat.lt_trichotomy a.stake b.stake with lt | eq | gt
  · exact Or.inr (Or.inl lt)
  · rcases Nat.le_total a.key b.key with k | k
    · exact Or.inl (Or.inr ⟨eq,k⟩)
    · exact Or.inr (Or.inr ⟨eq.symm,k⟩)
  · exact Or.inl (Or.inl gt)

private theorem key_trans : ∀ a b c : Committee.Entry, decide (a.key ≤ b.key) = true →
    decide (b.key ≤ c.key) = true → decide (a.key ≤ c.key) = true := by
  intro a b c ab bc
  simp only [decide_eq_true_eq] at ab bc ⊢
  exact Nat.le_trans ab bc

private theorem key_total : ∀ a b : Committee.Entry, (decide (a.key ≤ b.key) || decide (b.key ≤ a.key)) = true := by
  intro a b
  simp only [Bool.or_eq_true,decide_eq_true_eq]
  exact Nat.le_total a.key b.key

/-- Before key 66 activates, a cutoff that admits the parties elects them (they are already in
both orders: equal stakes, keys ascending). -/
private theorem chosen_parties (cutoff : Nat)
    (eligible : parties.filter (Committee.eligible 1000000000 1000000000000000000 cutoff) = parties) :
    Committee.chosen 1000000000 1000000000000000000 cutoff 5 parties = parties := by
  unfold Committee.chosen
  rw [eligible,List.mergeSort_of_pairwise (l := parties) (le := Committee.rank) (by decide +kernel),
    show parties.take 5 = parties from rfl,
    List.mergeSort_of_pairwise (l := parties) (le := fun a b => decide (a.key ≤ b.key)) (by decide +kernel)]

private theorem election_parties (cutoff : Nat)
    (eligible : parties.filter (Committee.eligible 1000000000 1000000000000000000 cutoff) = parties) :
    Committee.election 1000000000 1000000000000000000 cutoff 5 parties = some parties := by
  unfold Committee.election
  simp only [chosen_parties cutoff eligible,eligible]
  decide +kernel

/-- At R the stake order puts key 66 first, and the key order puts it last. -/
private theorem chosen_at_r :
    Committee.chosen 1000000000 1000000000000000000 20 5 (parties ++ [late]) = parties ++ [late] := by
  unfold Committee.chosen
  rw [show (parties ++ [late]).filter (Committee.eligible 1000000000 1000000000000000000 20) = parties ++ [late] by
      decide +kernel,
    sorted_eq (target := late :: parties) rank_trans rank_total (by decide +kernel) (by decide +kernel)
      (by decide +kernel),
    show (late :: parties).take 5 = late :: parties from rfl,
    sorted_eq (target := parties ++ [late]) key_trans key_total (by decide +kernel) (by decide +kernel)
      (by decide +kernel)]

private theorem election_at_r :
    Committee.election 1000000000 1000000000000000000 20 5 (parties ++ [late]) = some (parties ++ [late]) := by
  unfold Committee.election
  simp only [chosen_at_r]
  decide +kernel

private theorem deployed_at_cutoff : HistoricalContext.registryAt deployed.registry 12 = parties := by decide +kernel
private theorem recovered_at_cutoff : HistoricalContext.registryAt worldR.registry 12 = parties := by decide +kernel
private theorem recovered_at_r : HistoricalContext.registryAt worldR.registry 20 = parties ++ [late] := by
  decide +kernel

private theorem genesis_elected :
    Deployment.GenesisElected deployed.inbox deployed.registry deployed.inbox.configuration := by
  show Committee.election 1000000000 1000000000000000000 12 5 (HistoricalContext.registryAt deployed.registry 12) =
    some parties
  rw [deployed_at_cutoff,election_parties 12 (by decide +kernel)]

private theorem deployed_genesis : Deployment.Genesis deployed genesisHeader.elHash genesisHeader.stateRoot := by
  refine ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,by decide,rfl,by unfold FeeConserved; decide +kernel,
    ⟨?_,?_,?_,?_,by decide +kernel⟩,rfl,by decide +kernel,by decide +kernel,by decide +kernel,rfl,rfl,rfl,
    genesis_elected,by decide +kernel⟩
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · unfold RegistryHistory.IdentitiesValid
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel

private theorem active_at_one : Consensus.activeAt rulesR.consensus 1 = ⟨0,20,parties ++ [late]⟩ := by
  rw [Consensus.active_before_switch _ 1 (by decide +kernel)]
  show (⟨0,20,Committee.chosen 1000000000 1000000000000000000 20 5 (HistoricalContext.registryAt worldR.registry 20)⟩ :
    Committee.Record) = _
  rw [recovered_at_r,chosen_at_r]

private theorem built : Built attacker worldR rulesR := by
  refine ⟨[14],21,2100,build_rulesFor ⟨by decide +kernel,rfl,by decide +kernel,?_,?_,rfl,by decide +kernel⟩
    ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,?_,by decide,
      by decide⟩⟩
  · show (⟨0,12,Committee.chosen 1000000000 1000000000000000000 12 5 (HistoricalContext.registryAt worldR.registry 12)⟩ :
      Committee.Record) = zeroRecordR
    rw [recovered_at_cutoff,chosen_parties 12 (by decide +kernel)]
    rfl
  · show Committee.election 1000000000 1000000000000000000 12 5 (HistoricalContext.registryAt worldR.registry 12) =
      some parties
    rw [recovered_at_cutoff,election_parties 12 (by decide +kernel)]
  · show (Committee.election 1000000000 1000000000000000000 20 5 (HistoricalContext.registryAt worldR.registry 20)).isSome
      = true
    rw [recovered_at_r,election_at_r]
    rfl

/-- Stake registered after the DAO's recovery authorization captures the recovery committee.
The deployment is initialized (committee 0 = the four parties). At authorization (L1 block 14)
the recovery would elect the four parties, each below 1/3 of the power, and key 66 is
unregistered. Key 66 registers; along a protocol trace the same authorization executes with
R = 20 and starts generation 1. Its committee, both the recovery schedule and the rules the
deployment builds for generation 1, is the four parties and key 66, which holds more than 2/3 of
the power, so key 66's precommit alone is a valid commit. -/
theorem late_stake_captures_recovery_committee :
    Deployment.Genesis deployed genesisHeader.elHash genesisHeader.stateRoot ∧
    (ProtocolState.recover deployed request ⟨0,14,14⟩ true true).isSome = true ∧
    Recovery.selection (ProtocolState.recoveryView deployed) request ⟨0,14,14⟩ = some parties ∧
    (∀ m ∈ parties, 3*Committee.power 1000000000 m < Committee.totalPower 1000000000 parties) ∧
    66 ∉ deployed.registry.usedKeys ∧ ProtocolState.Trace deployed worldR ∧ worldR.inbox.generation = 1 ∧
    worldR.schedule.current.members = parties ++ [late] ∧
    2*Committee.totalPower 1000000000 (parties ++ [late]) < 3*Committee.power 1000000000 late ∧
    Built attacker worldR rulesR ∧ (Consensus.activeAt rulesR.consensus 1).members = parties ++ [late] ∧
    Consensus.CommitValid rulesR.consensus rulesR.signature 1 0 666 [lateVote] := by
  have trace : ProtocolState.Trace deployed worldR :=
    .step (.step (.refl _) (.registration (key := 66) (owner := 99) (amount := 9000000000000000000) (by decide) rfl))
      (.recovery (by decide) (Recovery.recover_of_allowed (by decide +kernel)))
  have intended : Recovery.selection (ProtocolState.recoveryView deployed) request ⟨0,14,14⟩ = some parties := by
    show Committee.election 1000000000 1000000000000000000 14 5
      ((Recovery.excludedRegistry (ProtocolState.recoveryView deployed) [] 14).map Prod.snd) = _
    rw [show (Recovery.excludedRegistry (ProtocolState.recoveryView deployed) [] 14).map Prod.snd = parties by
      decide +kernel,election_parties 14 (by decide +kernel)]
  have schedule : worldR.schedule.current.members = parties ++ [late] := by
    show ((Committee.election 1000000000 1000000000000000000 20 5
      ((Recovery.excludedRegistry (ProtocolState.recoveryView worldLate) [] 20).map Prod.snd)).getD []) = _
    rw [show (Recovery.excludedRegistry (ProtocolState.recoveryView worldLate) [] 20).map Prod.snd = parties ++ [late] by
      decide +kernel,election_at_r]
    rfl
  have commit : Consensus.CommitValid rulesR.consensus rulesR.signature 1 0 666 [lateVote] := by
    unfold Consensus.CommitValid Consensus.VoteValid
    rw [active_at_one]
    refine ⟨by decide +kernel,?_,by decide +kernel⟩
    show Committee.election 1000000000 1000000000000000000 20 5 (HistoricalContext.registryAt worldR.registry 20) =
      some (parties ++ [late])
    rw [recovered_at_r,election_at_r]
  refine ⟨deployed_genesis,by decide +kernel,intended,by decide +kernel,by decide +kernel,trace,by decide +kernel,
    schedule,by decide +kernel,built,by rw [active_at_one],commit⟩

end Etna.Design.RecoveryCapture
