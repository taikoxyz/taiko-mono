import EtnaModel.RoundSafety
import EtnaProofs.Headline.AccountableFinality

/-! Agreement at one height across all rounds. Same-round agreement is H2's finality argument,
restated for any consensus context; different rounds use `CrossRoundAccountable`, an explicit
hypothesis for CometBFT's locking rules. -/
namespace Etna.Design.Consensus

/-- Same-round agreement in any context: if the members that sign conflicting precommits at
height `h` and `round` hold less than 1/3 of the active committee's power, two valid commits
there are for the same block. -/
theorem same_round_agreement {c : Context} {signature : Vote → Prop} {h round : Nat} {honest : Hash → Bool}
    (clean : ∀ m ∈ (activeAt c h).members, honest m.key = true →
      ¬ Etna.Statements.Equivocates c signature h round m.key)
    (minority : 3*Committee.totalPower c.unit ((activeAt c h).members.filter fun m => !honest m.key) <
      Committee.totalPower c.unit (activeAt c h).members)
    {a b : Nat} {votesA votesB : List Vote}
    (okA : CommitValid c signature h round a votesA) (okB : CommitValid c signature h round b votesB) :
    a = b := by
  by_cases same : a = b
  · exact same
  exfalso
  have dishonest : ∀ m ∈ (activeAt c h).members,
      ((votesA.map Vote.key).contains m.key && (votesB.map Vote.key).contains m.key) = true →
      (!honest m.key) = true := by
    intro m member both
    simp only [Bool.and_eq_true,List.contains_iff_mem] at both
    obtain ⟨va,inA,keyA⟩ := List.mem_map.mp both.1
    obtain ⟨vb,inB,keyB⟩ := List.mem_map.mp both.2
    have validA := okA.2.2.2.1 va inA
    have validB := okB.2.2.2.1 vb inB
    cases hm : honest m.key with
    | false => rfl
    | true =>
      exact absurd ⟨va,vb,validA.2.2.2.2.2.2.2,validB.2.2.2.2.2.2.2,keyA,keyB,validA.1,validB.1,validA.2.1,
        validB.2.1,validA.2.2.1,validB.2.2.1,validA.2.2.2.1,validB.2.2.2.1,validA.2.2.2.2.1,validB.2.2.2.2.1,
        fun ids => same (validA.2.2.2.2.2.1.symm.trans (ids.trans validB.2.2.2.2.2.1))⟩ (clean m member hm)
  have overlap := Accountability.conflicting_commits_overlap okA okB
  have covered := Etna.Proofs.selected_power_le c.unit _ dishonest
  omega

/-- Agreement at one height across all rounds: under CometBFT's cross-round accountability, if
the members that sign conflicting precommits in some round or break the locking rules hold less
than 1/3 of the active committee's power, every two valid commits at height `h` are for the same
block, whatever their rounds. Only same-round faults are slashable (4.1). -/
theorem height_agreement {c : Context} {signature : Vote → Prop} {violates : Nat → Hash → Bool}
    {honest : Hash → Bool}
    (crossRound : CrossRoundAccountable c signature violates) (h : Nat)
    (sameRound : ∀ round, ∀ m ∈ (activeAt c h).members, honest m.key = true →
      ¬ Etna.Statements.Equivocates c signature h round m.key)
    (locking : ∀ m ∈ (activeAt c h).members, honest m.key = true → violates h m.key = false)
    (minority : 3*Committee.totalPower c.unit ((activeAt c h).members.filter fun m => !honest m.key) <
      Committee.totalPower c.unit (activeAt c h).members) :
    ∀ ra rb a b votesA votesB, CommitValid c signature h ra a votesA → CommitValid c signature h rb b votesB →
      a = b := by
  intro ra rb a b votesA votesB okA okB
  by_cases rounds : ra = rb
  · subst rounds
    exact same_round_agreement (sameRound ra) minority okA okB
  by_cases same : a = b
  · exact same
  exfalso
  have many := crossRound h ra rb a b votesA votesB okA okB rounds same
  have breakers : ∀ m ∈ (activeAt c h).members, violates h m.key = true → (!honest m.key) = true := by
    intro m member broke
    cases hm : honest m.key with
    | false => rfl
    | true => rw [locking m member hm] at broke; exact absurd broke (by decide)
  have covered := Etna.Proofs.selected_power_le c.unit _ breakers
  omega

end Etna.Design.Consensus
