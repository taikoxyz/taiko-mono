import EtnaModel.CurrentValidatorState

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

theorem checked_block {r : Blocks.Policy} {addressOf : Hash → Nat} {hash : Snapshot → Hash}
    {s t : CommitState} {b : Blocks.Block} (ok : checkBlock r addressOf hash s b = some t) :
    commit s (scheduled r.consensus addressOf s) = some t ∧
      b.header.height = s.height+1 ∧ hash (snapshot t) = b.header.valStateHash := by
  unfold checkBlock at ok
  split at ok
  next => contradiction
  next guard =>
    obtain ⟨u,hu,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next matched =>
      cases Option.some.inj ok
      refine ⟨hu,?_,matched⟩
      by_cases h : b.header.height = s.height+1
      · exact h
      · exact False.elim (guard (Or.inr (Or.inl h)))
    next => contradiction

theorem checked_run_append (r : Blocks.Policy) (addressOf : Hash → Nat)
    (hash : Snapshot → Hash) (s : CommitState) (as bs : List Blocks.Block) :
    checkRun r addressOf hash s (as ++ bs) =
      (checkRun r addressOf hash s as).bind (fun t => checkRun r addressOf hash t bs) := by
  induction as generalizing s with
  | nil => rfl
  | cons a rest ih =>
    simp only [List.cons_append,checkRun]
    cases step : checkBlock r addressOf hash s a with
    | none => rfl
    | some t => simpa only [step,Option.bind_some] using ih t

theorem checked_run_height {r : Blocks.Policy} {addressOf : Hash → Nat}
    {hash : Snapshot → Hash} {s final : CommitState} {bs : List Blocks.Block}
    (ok : checkRun r addressOf hash s bs = some final) :
    final.height = s.height+bs.length := by
  induction bs generalizing s with
  | nil => cases Option.some.inj ok; simp
  | cons b rest ih =>
    obtain ⟨t,head,tail⟩ := Option.bind_eq_some_iff.mp ok
    have step := (commit_pipeline (checked_block head).1).1
    have later := ih tail
    simp only [List.length_cons]
    omega

/-- The state witnessing a block's hash is reached by its actual checked prefix.
This identifies a replay source for durable SYNC-9-5c records at every height. -/
theorem checked_run_prefix {r : Blocks.Policy} {addressOf : Hash → Nat}
    {hash : Snapshot → Hash} {s final : CommitState} {before after : List Blocks.Block}
    {b : Blocks.Block}
    (ok : checkRun r addressOf hash s (before ++ b :: after) = some final) :
    ∃ prior next,
      checkRun r addressOf hash s before = some prior ∧
      checkBlock r addressOf hash prior b = some next ∧
      checkRun r addressOf hash next after = some final ∧
      next.height = s.height+before.length+1 ∧ hash (snapshot next) = b.header.valStateHash := by
  rw [checked_run_append] at ok
  obtain ⟨prior,prefixRun,ok⟩ := Option.bind_eq_some_iff.mp ok
  obtain ⟨next,head,tail⟩ := Option.bind_eq_some_iff.mp ok
  have h := checked_run_height prefixRun
  have step := (commit_pipeline (checked_block head).1).1
  refine ⟨prior,next,prefixRun,head,tail,?_,(checked_block head).2.2⟩
  omega

/-- Every member of an accepted concrete replay has its own computed commit state;
the hash is never inferred merely from committee keys/powers or a terminal hash. -/
theorem checked_run_records {r : Blocks.Policy} {addressOf : Hash → Nat}
    {hash : Snapshot → Hash} {s final : CommitState} {bs : List Blocks.Block}
    (ok : checkRun r addressOf hash s bs = some final) :
    ∀ b ∈ bs, ∃ before after,
      checkBlock r addressOf hash before b = some after ∧
      after.height = b.header.height ∧ hash (snapshot after) = b.header.valStateHash := by
  induction bs generalizing s with
  | nil => simp
  | cons a rest ih =>
    obtain ⟨t,head,tail⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨step,height,hashed⟩ := checked_block head
    intro b member
    rcases List.mem_cons.mp member with rfl | later
    · exact ⟨s,t,head,(commit_pipeline step).1.trans height.symm,hashed⟩
    · exact ih tail b later

theorem batch_refines {r : Blocks.Policy} {addressOf : Hash → Nat} {hash : Snapshot → Hash}
    {p : Blocks.Header} {bs : List Blocks.Block} {blobs : List Hash} {supplied final : CommitState}
    (ok : Batch r addressOf hash p bs blobs supplied final) : Blocks.BatchValid r p bs blobs :=
  ok.1

theorem batch_records {r : Blocks.Policy} {addressOf : Hash → Nat} {hash : Snapshot → Hash}
    {p : Blocks.Header} {bs : List Blocks.Block} {blobs : List Hash} {supplied final : CommitState}
    (ok : Batch r addressOf hash p bs blobs supplied final) :
    ∀ b ∈ bs, ∃ before after,
      checkBlock r addressOf hash before b = some after ∧
      after.height = b.header.height ∧ hash (snapshot after) = b.header.valStateHash := by
  obtain ⟨_,fresh,initial,_,_,replayed⟩ := ok
  exact checked_run_records replayed

theorem certificate_refines {env : Protocol.Environment} {w : Protocol.World} {d : StatementData}
    {archive : List Blocks.Header} {p : Blocks.Header} {bs : List Blocks.Block}
    {addressOf : Hash → Nat} {hash : Snapshot → Hash} {supplied final : CommitState}
    (ok : Certificate env w d archive p bs addressOf hash supplied final) :
    Protocol.Certifies env w d := ⟨archive,p,bs,ok.1⟩

theorem trust_cut_at_origin (origin : Nat) (h : Blocks.Header) (cp : Checkpoint)
    (height : h.height = origin) :
    Protocol.trustCut origin h cp ↔
      h.elHash = cp.elHash ∧ h.cometHash = cp.cometHash ∧ h.cursor = cp.cursor := by
  simp [Protocol.trustCut,height]

theorem trust_cut_after_origin (origin : Nat) (h : Blocks.Header) (cp : Checkpoint)
    (height : h.height ≠ origin) :
    Protocol.trustCut origin h cp ↔
      h.elHash = cp.elHash ∧ h.cometHash = cp.cometHash ∧ h.cursor = cp.cursor ∧
        h.valStateHash = cp.valStateHash := by
  simp [Protocol.trustCut,height]

end Etna.Design.Current.ValidatorState
