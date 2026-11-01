import EtnaProofs.Locking
import EtnaWitnesses.Regressions.CanonicalHistory

/-! Concrete four-key histories. B/10 has a round-0 PoLC that nobody uses to lock.
A/20 has a round-1 PoLC, but only key 1 locks, so there is no A commit. At round 2
keys 2/3/4 certify nil; key 1 prevotes its A lock, then unlocks at precommit. B
commits at both rounds 3 and 4. This exercises conflicting candidates, withheld
PoLC delivery, nil unlock, skipped phases, and genuinely different commit rounds. -/
namespace Etna.Design.LockingRegression
open Locking

def members : List Committee.Entry := [⟨1,1,0,1000⟩,⟨2,1,0,1000⟩,⟨3,1,0,1000⟩,⟨4,1,0,1000⟩]
def keys : List Hash := [1,2,3,4]
def honest (_ : Hash) : Bool := true

def action (k r : Nat) : RoundAction :=
  match r with
  | 0 => { prevote := some (some 10) }
  | 1 => { prevote := some (some 20), precommit := if k = 1 then some (some 20) else none }
  | 2 => { prevote := some (if k = 1 then some 20 else none), precommit := some none, nilCertificate := true }
  | 3 => { prevote := some (some 10), precommit := some (some 10) }
  | 4 => { prevote := some (some 10), precommit := some (some 10) }
  | _ => {}

def lock (k r : Nat) : Lock :=
  match r with
  | 0 | 1 | 3 => none
  | 2 => if k = 1 then some (1,20) else none
  | 4 => some (3,10)
  | _ => some (4,10)

def execution : Execution where
  prevotes := fun k r v => (action k r).prevote = some v
  precommits := fun k r v => (action k r).precommit = some v
  actions := action
  locks := lock

private theorem polc0 : PoLC 1 members execution 0 (some 10) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem polc1 : PoLC 1 members execution 1 (some 20) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem polc2 : PoLC 1 members execution 2 none := by
  refine ⟨[2,3,4],by unfold Quorum; decide +kernel,?_⟩
  intro k mem
  simp only [List.mem_cons,List.not_mem_nil,or_false] at mem
  rcases mem with rfl | rfl | rfl <;> rfl
private theorem polc3 : PoLC 1 members execution 3 (some 10) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem polc4 : PoLC 1 members execution 4 (some 10) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩

/-- A full nontrivial markdown-mode execution satisfies the actual transition rules. -/
theorem multiround_execution : HonestRules 1 members honest true execution := by
  constructor
  · intro k _; rfl
  · intro k _ r
    cases r with
    | zero => simp [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action,lock]
    | succ r => cases r with
      | zero =>
        by_cases one : k = 1 <;>
          simp [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action,lock,one]
        exact polc1
      | succ r => cases r with
        | zero =>
          by_cases one : k = 1 <;>
            simp [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action,lock,one]
          all_goals exact polc2
        | succ r => cases r with
          | zero =>
            simpa [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action,lock] using polc3
          | succ r => cases r with
            | zero =>
              simpa [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action,lock] using polc4
            | succ r => simp [RoundStep,UnlockAllowed,afterPrevote,execution,action,lock]
  · intro k _ r v vote; exact vote
  · intro k _ r v vote; exact vote

/-- Nil unlock occurs after key 1's locked-block prevote, never before it. -/
theorem nil_certificate_unlocks :
    execution.locks 1 2 = some (1,20) ∧ execution.prevotes 1 2 (some 20) ∧
    PoLC 1 members execution 2 none ∧ execution.precommits 1 2 none ∧ execution.locks 1 3 = none :=
  ⟨rfl,rfl,polc2,rfl,rfl⟩

theorem differing_round_commits :
    Commit 1 members execution 3 10 ∧ Commit 1 members execution 4 10 ∧
    PoLC 1 members execution 0 (some 10) ∧ PoLC 1 members execution 1 (some 20) ∧ (10 : Hash) ≠ 20 :=
  ⟨⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩,
    ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩,polc0,polc1,by decide⟩

def staleAction : RoundAction :=
  { prevote := some (some 10), precommit := some (some 10), justification := some (0,some 10) }

/-- An existing earlier B certificate cannot unlock the later A lock. -/
theorem stale_certificate_rejected :
    PoLC 1 members execution 0 (some 10) ∧
    ¬ RoundStep true (PoLC 1 members execution) 2 (some (1,20)) staleAction (some (2,10)) := by
  refine ⟨polc0,?_⟩
  intro step
  obtain ⟨lr,b,same,floor,_⟩ := step.1
  have pair := Option.some.inj same
  cases pair
  omega

/-- A concrete asynchronous interleaving: key 1's round-3 vote appears before key 2's
round-2 vote, while every key's own phase/round order increases. These observations
belong to the same execution; certificates do not force simultaneous delivery. -/
def interleaving : List (Hash × Nat × Nat) := [(1,2,1),(1,2,2),(1,3,1),(2,2,1),(2,2,2),(2,3,1)]

theorem asynchronous_interleaving :
    interleaving.Pairwise (fun a b => a.1 = b.1 → 2*a.2.1+a.2.2 < 2*b.2.1+b.2.2) ∧
    ¬ interleaving.Pairwise (fun a b => a.2.1 ≤ b.2.1) ∧
    execution.prevotes 1 3 (some 10) ∧ execution.prevotes 2 2 none := by
  unfold execution action
  decide +kernel

def cfg : HistoricalContext.Parameters := ⟨1,3,1,1,4⟩
def registryA : RegistryHistory.State := { RegistryHistory.empty with history := [⟨1,members⟩] }
def registryB : RegistryHistory.State :=
  { registryA with history := ⟨50,[⟨9,4,0,1000⟩]⟩ :: registryA.history }
def contextA : Consensus.Context := HistoricalContext.derive FirstBatch.inbox registryA cfg [10,11,12]
def contextB : Consensus.Context := HistoricalContext.derive FirstBatch.inbox registryB cfg [10,11,20]
def vote (r b k : Nat) : Consensus.Vote := ⟨FirstBatch.deployment,0,4,r,2,b,k⟩
def votes (r b : Nat) : List Consensus.Vote := keys.map (vote r b)

private theorem chosen_members (cutoff : Nat) (live : cutoff < 1000) :
    Committee.chosen 1 1 cutoff 4 members = members := by
  have eligible : members.filter (Committee.eligible 1 1 cutoff) = members := by
    simp [members,Committee.eligible,live]
  unfold Committee.chosen
  have ranked : members.mergeSort Committee.rank = members := List.mergeSort_of_pairwise (by decide +kernel)
  rw [eligible,ranked]
  change members.mergeSort (fun a b => decide (a.key ≤ b.key)) = members
  exact List.mergeSort_of_pairwise (by decide +kernel : members.Pairwise (fun a b => decide (a.key ≤ b.key)))

private theorem election_members (cutoff : Nat) (live : cutoff < 1000) :
    Committee.election 1 1 cutoff 4 members = some members := by
  have eligible : members.filter (Committee.eligible 1 1 cutoff) = members := by
    simp [members,Committee.eligible,live]
  simp only [Committee.election,chosen_members cutoff live,eligible]
  decide +kernel

private theorem activeA : Consensus.activeAt contextA 4 = ⟨1,11,members⟩ := by
  change Committee.Record.mk 1 11 (Committee.chosen 1 1 11 4 members) = _
  rw [chosen_members 11 (by decide)]
private theorem activeB : Consensus.activeAt contextB 4 = ⟨1,11,members⟩ := by
  change Committee.Record.mk 1 11 (Committee.chosen 1 1 11 4 members) = _
  rw [chosen_members 11 (by decide)]

private theorem actual_validA (r b : Nat) : Consensus.CommitValid contextA FirstBatch.auth 4 r b (votes r b) := by
  unfold Consensus.CommitValid
  rw [activeA]
  refine ⟨by decide,?_,?_,?_,?_⟩
  · exact election_members 11 (by decide)
  · change keys.Nodup
    decide +kernel
  · intro v mem
    simp only [votes,keys,List.map_cons,List.map_nil,List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl | rfl <;>
      simp only [Consensus.VoteValid,activeA] <;>
      simp [vote,contextA,HistoricalContext.derive,FirstBatch.inbox,members,FirstBatch.auth]
  · change 2*Committee.totalPower 1 members < 3*power 1 members keys
    decide +kernel

private theorem actual_validB (r b : Nat) : Consensus.CommitValid contextB FirstBatch.auth 4 r b (votes r b) := by
  unfold Consensus.CommitValid
  rw [activeB]
  refine ⟨by decide,?_,?_,?_,?_⟩
  · exact election_members 11 (by decide)
  · change keys.Nodup
    decide +kernel
  · intro v mem
    simp only [votes,keys,List.map_cons,List.map_nil,List.mem_cons,List.not_mem_nil,or_false] at mem
    rcases mem with rfl | rfl | rfl | rfl <;>
      simp only [Consensus.VoteValid,activeB] <;>
      simp [vote,contextB,HistoricalContext.derive,FirstBatch.inbox,members,FirstBatch.auth]
  · change 2*Committee.totalPower 1 members < 3*power 1 members keys
    decide +kernel

private theorem builtA : HistoricalContext.build FirstBatch.inbox registryA cfg ([10,11] ++ [12]) = some contextA := by
  unfold HistoricalContext.build
  rw [ite_eq_left (by
    refine ⟨by decide,by decide,by decide,by decide,by decide,?_,by decide,by decide⟩
    change (Committee.election 1 1 1 4 members).isSome = true
    rw [election_members 1 (by decide)]
    rfl)]
  rfl
private theorem builtB : HistoricalContext.build FirstBatch.inbox registryB cfg ([10,11] ++ [20]) = some contextB := by
  unfold HistoricalContext.build
  rw [ite_eq_left (by
    refine ⟨by decide,by decide,by decide,by decide,by decide,?_,by decide,by decide⟩
    change (Committee.election 1 1 1 4 members).isSome = true
    rw [election_members 1 (by decide)]
    rfl)]
  rfl

/-- Actual CommitValid certificates in different rounds and different local contexts,
using the ordinary H+2 committee, with decoded history equality below the cutoff only. -/
theorem actual_shared_history_commits :
    Consensus.CommitValid contextA FirstBatch.auth 4 3 10 (votes 3 10) ∧
    Consensus.CommitValid contextB FirstBatch.auth 4 4 10 (votes 4 10) ∧
    CommitAttribution execution 3 10 (votes 3 10) ∧ CommitAttribution execution 4 10 (votes 4 10) ∧
    Consensus.activeAt contextA 4 = Consensus.activeAt contextB 4 ∧ (10 : Hash) = 10 := by
  have va : Consensus.CommitValid contextA FirstBatch.auth 4 3 10 (votes 3 10) := actual_validA 3 10
  have vb : Consensus.CommitValid contextB FirstBatch.auth 4 4 10 (votes 4 10) := actual_validB 4 10
  have aa : CommitAttribution execution 3 10 (votes 3 10) := by intro v _; rfl
  have ab : CommitAttribution execution 4 10 (votes 4 10) := by intro v _; rfl
  have scope : SameInstance FirstBatch.inbox FirstBatch.inbox := ⟨rfl,rfl,rfl⟩
  have covered : requiredPrefix FirstBatch.inbox cfg 4 ≤ [10,11].length := by decide +kernel
  have raw : registryA.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff FirstBatch.inbox cfg [10,11] 4)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ HistoricalContext.cutoff FirstBatch.inbox cfg [10,11] 4)) := by decide +kernel
  refine ⟨va,vb,aa,ab,(active_committee_prefix builtA builtB scope covered raw).2.2.2,?_⟩
  exact shared_history_commitValid_agreement builtA builtB scope covered raw
    (by rw [activeA]; exact multiround_execution)
    (by rw [activeA]; unfold Minority; decide +kernel) aa ab va vb

/-- Existing CommitValid can accept a decoded zero block ID for a nil quorum, but the
per-certificate bridge refuses to reinterpret nil events as nonnil block `some 0`. -/
theorem nil_is_not_block_zero :
    Consensus.CommitValid contextA FirstBatch.auth 4 2 0 (votes 2 0) ∧
    execution.precommits 1 2 none ∧ ¬ CommitAttribution execution 2 0 (votes 2 0) := by
  refine ⟨actual_validA 2 0,rfl,?_⟩
  intro attribution
  have impossible := attribution (vote 2 0 1) (by decide +kernel)
  cases impossible

def recoveryState : State :=
  { FirstBatch.inbox with generation := 1, origin := ⟨2,50,50⟩, origins := [(1,⟨2,50,50⟩)] }
def recoveryContext : Consensus.Context := HistoricalContext.derive recoveryState registryB cfg [10,11,20]

/-- The same numerical height belongs to different committee instances across recovery. -/
theorem recovery_is_a_new_instance :
    ¬ SameInstance FirstBatch.inbox recoveryState ∧
    requiredPrefix recoveryState cfg 4 = 0 ∧
    (Consensus.activeAt recoveryContext 4).cutoff = 50 ∧
    (Consensus.activeAt recoveryContext 4).members ≠ (Consensus.activeAt contextA 4).members := by
  rw [activeA]
  unfold SameInstance
  decide +kernel

/-- The existing initialized accepted history supplies a real recovery-generation prefix;
appending different later anchor numbers cannot alter its height-23 active committee. -/
theorem canonical_recovery_prefix :
    CanonicalHistory.Run NonVacuity.world0 CanonicalHistoryRegression.finish NormalSigningRegression.archive1 ∧
    CanonicalHistoryRegression.finish.inbox.generation = 1 ∧
    Consensus.activeAt (HistoricalContext.derive CanonicalHistoryRegression.finish.inbox
      CanonicalHistoryRegression.finish.registry CanonicalHistoryRegression.signingPrefix.cfg
      (NormalSigningRegression.archive1 ++ [50])) 23 =
    Consensus.activeAt (HistoricalContext.derive CanonicalHistoryRegression.finish.inbox
      CanonicalHistoryRegression.finish.registry CanonicalHistoryRegression.signingPrefix.cfg
      (NormalSigningRegression.archive1 ++ [51])) 23 := by
  refine ⟨CanonicalHistoryRegression.complete_history,rfl,?_⟩
  apply (active_committee_prefix (h := 23) (common := NormalSigningRegression.archive1)
    (moreA := [50]) (moreB := [51])
    (sa := CanonicalHistoryRegression.finish.inbox) (sb := CanonicalHistoryRegression.finish.inbox)
    (registryA := CanonicalHistoryRegression.finish.registry) (registryB := CanonicalHistoryRegression.finish.registry)
    (cfg := CanonicalHistoryRegression.signingPrefix.cfg)
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)])
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)])
    ⟨rfl,rfl,rfl⟩ (by decide +kernel) rfl).2.2.2

-- Paper mode uses the other coupled nil rule: a nil PoLC after a commit retains locks.
def paperAction (_ r : Nat) : RoundAction :=
  if r = 0 then { prevote := some (some 10), precommit := some (some 10) }
  else if r = 1 then { prevote := some none, precommit := some none, nilCertificate := true }
  else {}
def paperExecution : Execution where
  prevotes := fun k r v => (paperAction k r).prevote = some v
  precommits := fun k r v => (paperAction k r).precommit = some v
  actions := paperAction
  locks := fun _ r => if r = 0 then none else some (0,10)

/-- A later nil certificate is possible in paper mode, but cannot release its commit locks. -/
theorem paper_nil_retains_lock :
    HonestRules 1 members honest false paperExecution ∧
    Commit 1 members paperExecution 0 10 ∧ PoLC 1 members paperExecution 1 none ∧
    paperExecution.locks 1 2 = some (0,10) := by
  have c0 : PoLC 1 members paperExecution 0 (some 10) :=
    ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
  have c1 : PoLC 1 members paperExecution 1 none :=
    ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
  refine ⟨?_,⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩,c1,rfl⟩
  constructor
  · intro k _; rfl
  · intro k _ r
    by_cases zero : r = 0
    · subst r
      simpa [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,paperExecution,paperAction] using c0
    · by_cases one : r = 1
      · subst r
        simpa [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,paperExecution,paperAction] using c1
      · simp [RoundStep,UnlockAllowed,afterPrevote,paperExecution,paperAction,zero,one]
  · intro k _ r v pv; exact pv
  · intro k _ r v pc; exact pc

end Etna.Design.LockingRegression
