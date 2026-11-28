import EtnaModel.PerBlockGuest

namespace Etna.Design.PerBlockGuest
open PerBlockCommittee

/-- No previous validator set is needed at origin. Both initial sets use its fixed list. -/
theorem boundary_origin (rules : BoundaryRules) (origin : GenerationOrigin) (originKeys : List Hash)
    (p : ProofCheckpoint) (openings : ValidatorOpenings) (atOrigin : p.height = origin.height) :
    boundarySets rules origin originKeys p openings =
      (fallback rules.committee origin.fallbackKeysHash originKeys).map
        (fun initial ↦ ⟨none, initial, initial⟩) := by
  simp only [boundarySets, ite_eq_left atOrigin]
  cases fallback rules.committee origin.fallbackKeysHash originKeys <;> rfl

/-- At a later checkpoint, each boundary set is linked to its specified authenticated source. -/
theorem boundary_after_origin {rules : BoundaryRules} {origin : GenerationOrigin}
    {originKeys : List Hash} {p : ProofCheckpoint} {openings : ValidatorOpenings}
    {sets : BoundarySets} (later : origin.height < p.height)
    (accepted : boundarySets rules origin originKeys p openings = some sets) :
    ∃ header input parent,
      rules.openCometHeader p.cometHash = some header ∧ header.height = p.height ∧
      openValidators rules header.validatorsHash openings.current = some parent ∧
      sets.parent = some parent ∧
      (if p.height = origin.height + 1 then
        fallback rules.committee origin.fallbackKeysHash originKeys
      else openValidators rules header.nextValidatorsHash openings.next) = some sets.first ∧
      rules.openParentDecision p.height p.elHash = some input ∧
      decision rules.committee p.height input.snapshot input.anchor input.fallbackKeys =
        some sets.second := by
  unfold boundarySets at accepted
  rw [ite_eq_right (by omega), ite_eq_left later] at accepted
  obtain ⟨header, headerAt, rest⟩ := Option.bind_eq_some_iff.mp accepted
  split at rest
  · contradiction
  next heightOk =>
    obtain ⟨parent, parentAt, rest⟩ := Option.bind_eq_some_iff.mp rest
    obtain ⟨first, firstAt, rest⟩ := Option.bind_eq_some_iff.mp rest
    obtain ⟨input, inputAt, rest⟩ := Option.bind_eq_some_iff.mp rest
    obtain ⟨second, secondAt, equal⟩ := Option.bind_eq_some_iff.mp rest
    cases Option.some.inj equal
    exact ⟨header, input, parent, headerAt, Decidable.not_not.mp heightOk,
      parentAt, rfl, firstAt, inputAt, secondAt⟩

/-- An opening carries exactly the supplied members, with a matching stock commitment. -/
theorem openValidators_checked {rules : BoundaryRules} {expected : Hash}
    {members selected : List Member} (accepted : openValidators rules expected members =
      some selected) : selected = members ∧ rules.hashValidatorSet selected = expected ∧
      validMembers rules.committee selected = true := by
  unfold openValidators at accepted
  split at accepted
  next checks =>
    cases Option.some.inj accepted
    exact ⟨rfl, checks.1, checks.2⟩
  next => contradiction

/-- The commitment count uses only actual members with matching, authenticated precommits. -/
theorem signingMembers_exact (verify : VerifyVote) (chainId : String) (members : List Member)
    (commit : Commit) (member : Member) :
    member ∈ signingMembers verify chainId members commit ↔
      member ∈ members ∧ ∃ vote ∈ commit.votes,
        vote.key = member.key ∧ vote.voteType = 2 ∧ vote.height = commit.height ∧
        vote.round = commit.round ∧ vote.blockId = some commit.blockId ∧
        verify chainId vote = true := by
  simp [signingMembers, counts, and_assoc]

/-- A qualifying commit binds the target header and strictly exceeds two-thirds of power.
The counted members have distinct keys, irrespective of how many input entries matched. -/
theorem validCommit_quorum {rules : Rules} {verify : VerifyVote} {chainId : String}
    {height : Nat} {headerHash : Hash} {members : List Member} {commit : Commit}
    (accepted : validCommit rules verify chainId height headerHash members commit = true) :
    commit.height = height ∧ commit.blockId.hash = headerHash ∧
    ((signingMembers verify chainId members commit).map Member.key).Nodup ∧
    2 * votingPower members < 3 * votingPower (signingMembers verify chainId members commit) := by
  simp only [validCommit, Bool.and_eq_true, decide_eq_true_eq] at accepted
  obtain ⟨⟨membersOk, heightAt, _, _, _, hashAt, _, _⟩, quorum⟩ := accepted
  simp only [validMembers, Bool.and_eq_true, decide_eq_true_eq] at membersOk
  have distinct := membersOk.1.2.2.1
  have subset : List.Sublist (signingMembers verify chainId members commit) members :=
    List.filter_sublist
  exact ⟨heightAt, hashAt, (subset.map Member.key).nodup distinct, quorum⟩

/-- A change in order alone leaves the same signing set. -/
theorem sameSigningSet_iff (current next : List Member) : sameSigningSet current next = true ↔
    ∀ member : Member, member ∈ current ↔ member ∈ next := by
  simp only [sameSigningSet, Bool.and_eq_true, List.all_eq_true, List.contains_iff_mem]
  exact ⟨fun ⟨forward, backward⟩ member ↦ ⟨forward member, backward member⟩,
    fun same ↦ ⟨fun member ↦ (same member).mp, fun member ↦ (same member).mpr⟩⟩

/-- At a terminal height or set change, an accepted input carries a qualifying commit. -/
theorem requiredCommit_qualifies {rules : Rules} {verify : VerifyVote} {chainId : String}
    {height : Nat} {headerHash : Hash} {terminal : Bool} {current next : List Member}
    {proof : Option Commit} (required : terminal = true ∨ sameSigningSet current next = false)
    (accepted : checkRequiredCommit rules verify chainId height headerHash terminal current next
      proof = true) :
    ∃ commit, proof = some commit ∧
      validCommit rules verify chainId height headerHash current commit = true := by
  have needsCommit : commitRequired terminal current next = true := by
    rcases required with yes | changed
    · simp [commitRequired, yes]
    · simp [commitRequired, changed]
  simp only [checkRequiredCommit, ite_eq_left needsCommit] at accepted
  cases proof with
  | none => contradiction
  | some commit => exact ⟨commit, rfl, accepted⟩

end Etna.Design.PerBlockGuest
