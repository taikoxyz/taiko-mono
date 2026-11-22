import EtnaProofs.PerBlockGuest

namespace Etna.PerBlockGuestRegression
open Etna.Design Etna.Design.PerBlockCommittee Etna.Design.PerBlockGuest

set_option maxRecDepth 20000

private def a : Hash := compressedKey 2 17
private def b : Hash := compressedKey 2 19
private def c : Hash := compressedKey 3 23
private def d : Hash := compressedKey 3 29

private def committeeRules : Rules :=
  ⟨fun _ ↦ true, fun keys ↦ if keys = [a] then 10 else 11⟩
private def origin : GenerationOrigin := ⟨40, 100, 200, 10⟩
private def initial : List Member := [⟨a, 1⟩]
private def at43 : List Member := [⟨b, 3⟩]
private def at44 : List Member := [⟨d, 5⟩]

private def openHeader : Hash → Option CometHeader
  | 741 => some ⟨41, 101, 101⟩
  | 742 => some ⟨42, 101, 102⟩
  | _ => none

private def openDecision (height : Nat) (hash : Hash) : Option DecisionInput := do
  let seat ← if height = 41 ∧ hash = 641 then some (packSnapshotSeat 2 19 3)
    else if height = 42 ∧ hash = 642 then some (packSnapshotSeat 3 29 5)
    else none
  return ⟨⟨height, 120, seat :: List.replicate 127 default⟩, ⟨120, 11⟩, [c]⟩

private def guestRules : BoundaryRules :=
  ⟨committeeRules, openHeader, openDecision,
    fun members ↦ if members = initial then 101 else if members = at43 then 102 else 0⟩

-- At generation origin there is no current-generation header or LastCommit. At the
-- first checkpoint past origin, only p+1 still uses the origin's fallback list.
example : boundarySets guestRules origin [a] ⟨40, 0, 0⟩ ⟨[], []⟩ =
      some ⟨none, initial, initial⟩ ∧
    boundarySets guestRules origin [a] ⟨41, 641, 741⟩ ⟨initial, []⟩ =
      some ⟨some initial, initial, at43⟩ ∧
    boundarySets guestRules origin [] ⟨42, 642, 742⟩ ⟨initial, at43⟩ =
      some ⟨some initial, at43, at44⟩ := by decide +kernel

example : boundarySets guestRules origin [a] ⟨42, 642, 740⟩ ⟨initial, at43⟩ = none ∧
    boundarySets guestRules origin [a] ⟨42, 642, 741⟩ ⟨initial, at43⟩ = none ∧
    boundarySets guestRules origin [a] ⟨42, 641, 742⟩ ⟨initial, at43⟩ = none ∧
    boundarySets guestRules origin [a] ⟨42, 642, 742⟩ ⟨at43, at43⟩ = none ∧
    boundarySets guestRules origin [a] ⟨42, 642, 742⟩ ⟨initial, at44⟩ = none := by
  decide +kernel

private def committee : List Member := [⟨a, 2⟩, ⟨b, 1⟩, ⟨c, 1⟩]
private def chainId := "etna-generation-3"
private def blockId : BlockId := ⟨801, 1, 901⟩

private def verify : VerifyVote := fun domain vote ↦
  domain == chainId && vote.timestamp == 92 && vote.signature == [38]

private def precommit (key : Hash) : Vote := ⟨key, 2, 43, 1, some blockId, 92, [38]⟩
private def commit : Commit := ⟨43, 1, blockId, [precommit a, precommit b]⟩

example : validCommit committeeRules verify chainId 43 801 committee commit = true ∧
    validCommit committeeRules verify chainId 43 799 committee commit = false ∧
    validCommit committeeRules verify "etna-generation-2" 43 801 committee commit = false ∧
    validCommit committeeRules verify chainId 44 801 committee commit = false := by decide +kernel

-- Distinct power must exceed, rather than equal, two-thirds.
example : validCommit committeeRules verify chainId 43 801 [⟨a, 2⟩, ⟨b, 1⟩]
      { commit with votes := [precommit a, precommit a] } = false ∧
    validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a, precommit a, precommit d] } = false := by decide +kernel

example : validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a, { precommit b with round := 2 }] } = false ∧
    validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a, { precommit b with blockId := none }] } = false ∧
    validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a, { precommit b with voteType := 1 }] } = false ∧
    validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a, { precommit b with timestamp := 93 }] } = false ∧
    validCommit committeeRules verify chainId 43 801 committee
      { commit with votes := [precommit a,
        { precommit b with blockId := some { blockId with partSetHash := 902 } }] } = false := by
  decide +kernel

example : checkRequiredCommit committeeRules verify chainId 43 801
      false committee committee.reverse none = true ∧
    checkRequiredCommit committeeRules verify chainId 43 801
      true committee committee.reverse none = false ∧
    checkRequiredCommit committeeRules verify chainId 43 801
      false committee [⟨a, 2⟩, ⟨b, 1⟩, ⟨c, 2⟩] none = false ∧
    checkRequiredCommit committeeRules verify chainId 43 801
      false committee [⟨a, 2⟩, ⟨b, 1⟩, ⟨c, 2⟩] (some commit) = true := by decide +kernel

end Etna.PerBlockGuestRegression
