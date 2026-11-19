import EtnaModel.CurrentValidatorState
import EtnaProofs.CurrentReference

namespace Etna.Design.Current.ValidatorState

/-- A commit advances exactly one logical height and shifts the two-set pipeline.
Neither H's updates nor their proposer arithmetic can change the set signing H+1. -/
theorem commit_pipeline {s t : CommitState} {changes : List Change}
    (ok : commit s changes = some t) :
    t.height = s.height+1 ∧ t.current = s.next ∧ t.last = s.current ∧
      ∃ updated, update s.next changes = some updated ∧ increment updated 1 = some t.next := by
  unfold commit at ok
  obtain ⟨updated,hu,ok⟩ := Option.bind_eq_some_iff.mp ok
  obtain ⟨next,hn,equal⟩ := Option.bind_eq_some_iff.mp ok
  cases Option.some.inj equal
  exact ⟨rfl,rfl,rfl,updated,hu,hn⟩

/-- H's updated/incremented NextValidators become the set signing H+2. Changes
returned at H+1 cannot move their activation earlier or replace that signing set. -/
theorem hplus2 {s t u : CommitState} {atH atNext : List Change}
    (first : commit s atH = some t) (second : commit t atNext = some u) :
    t.current = s.next ∧ u.current = t.next ∧
      ∃ updated, update s.next atH = some updated ∧ increment updated 1 = some u.current := by
  obtain ⟨_,current,_,updated,hu,hn⟩ := commit_pipeline first
  have shifted := (commit_pipeline second).2.1
  exact ⟨current,shifted,updated,hu,shifted ▸ hn⟩

/-- Replaying a prefix and suffix is exactly replaying the same per-height calls.
This does not replace those calls by IncrementProposerPriority(number of heights). -/
theorem replay_append (s : CommitState) (as bs : List (List Change)) :
    replay s (as ++ bs) = (replay s as).bind (fun t => replay t bs) := by
  induction as generalizing s with
  | nil => rfl
  | cons a rest ih =>
    simp only [List.cons_append,replay]
    cases step : commit s a with
    | none => rfl
    | some t => simpa only [step,Option.bind_some] using ih t

theorem replay_height {s t : CommitState} {steps : List (List Change)}
    (ok : replay s steps = some t) : t.height = s.height+steps.length := by
  induction steps generalizing s with
  | nil => cases Option.some.inj ok; simp
  | cons a rest ih =>
    obtain ⟨u,hu,tail⟩ := Option.bind_eq_some_iff.mp ok
    have h := ih tail
    have step := (commit_pipeline hu).1
    simp only [List.length_cons]
    omega

/-- Recovery-origin admission reads fresh genesis and ignores both old inputs. -/
theorem origin_uses_genesis (hash : Snapshot → Hash) (origin stored : Nat)
    (fresh supplied : CommitState) (height : fresh.height = origin) (valid : validState fresh = true) :
    openOrigin hash origin origin stored fresh supplied = some fresh := by
  simp [openOrigin,height,valid]

theorem later_origin_authenticates {hash : Snapshot → Hash} {origin height stored : Nat}
    {fresh supplied initial : CommitState} (later : origin < height)
    (ok : openOrigin hash origin height stored fresh supplied = some initial) :
    initial = supplied ∧ supplied.height = height ∧ hash (snapshot supplied) = stored := by
  simp only [openOrigin,Nat.ne_of_gt later,↓reduceIte] at ok
  split at ok
  next guard => exact ⟨(Option.some.inj ok).symm,guard.2.1,guard.2.2.2⟩
  next => contradiction

end Etna.Design.Current.ValidatorState
