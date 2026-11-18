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

/-- A checked block's signing set, the CometBFT set the replay holds for its height, is the
registry committee active at that height. -/
theorem checked_block_signers {r : Blocks.Policy} {addressOf : Hash → Nat} {hash : Snapshot → Hash}
    {s t : CommitState} {b : Blocks.Block} (ok : checkBlock r addressOf hash s b = some t) :
    membership s.current = membership ⟨selected r.consensus addressOf
      (Consensus.activeAt r.consensus b.header.height),none⟩ := by
  unfold checkBlock at ok
  split at ok
  next => contradiction
  next guard =>
    by_cases same : membership s.current = membership ⟨selected r.consensus addressOf
        (Consensus.activeAt r.consensus b.header.height),none⟩
    · exact same
    · exact False.elim (guard (Or.inr (Or.inr (Or.inl same))))

/-- In an accepted replay every block was signed by the registry committee active at its
height, and its committed hash is that of its own computed state. -/
theorem checked_run_signers {r : Blocks.Policy} {addressOf : Hash → Nat}
    {hash : Snapshot → Hash} {s final : CommitState} {bs : List Blocks.Block}
    (ok : checkRun r addressOf hash s bs = some final) :
    ∀ b ∈ bs, ∃ before after,
      checkBlock r addressOf hash before b = some after ∧
      membership before.current = membership ⟨selected r.consensus addressOf
        (Consensus.activeAt r.consensus b.header.height),none⟩ ∧
      after.height = b.header.height ∧ hash (snapshot after) = b.header.valStateHash := by
  induction bs generalizing s with
  | nil => simp
  | cons a rest ih =>
    obtain ⟨t,head,tail⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨step,height,hashed⟩ := checked_block head
    intro b member
    rcases List.mem_cons.mp member with rfl | later
    · exact ⟨s,t,head,checked_block_signers head,(commit_pipeline step).1.trans height.symm,hashed⟩
    · exact ih tail b later

/-- A nonempty replay ends in the state of its last block: the batch's terminal header carries
that state's height and hash. -/
theorem checked_run_terminal {r : Blocks.Policy} {addressOf : Hash → Nat}
    {hash : Snapshot → Hash} {s final : CommitState} {bs : List Blocks.Block}
    (ok : checkRun r addressOf hash s bs = some final) (nonempty : bs ≠ []) (p : Blocks.Header) :
    hash (snapshot final) = (Blocks.terminal p bs).valStateHash ∧
      final.height = (Blocks.terminal p bs).height := by
  induction bs generalizing s p with
  | nil => exact absurd rfl nonempty
  | cons b rest ih =>
    obtain ⟨t,head,tail⟩ := Option.bind_eq_some_iff.mp ok
    cases rest with
    | nil =>
      have equal : t = final := Option.some.inj tail
      subst equal
      obtain ⟨step,height,hashed⟩ := checked_block head
      exact ⟨hashed,(commit_pipeline step).1.trans height.symm⟩
    | cons c more => exact ih tail (List.cons_ne_nil c more) b.header

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

/-- With validator replay in the guest (`ReplaySound`), an accepted landing's certificate
replays the validator state from its generation's genesis or retained preimage: the checkpoint
the landing writes commits to the final replayed state at its own height, and every landed block
was signed by the registry committee active at its height. -/
theorem accepted_replay {env : Protocol.Environment} {initial w t : Protocol.World}
    {a : Protocol.Landing} {addressOf : Hash → Nat} {hash : Snapshot → Hash}
    (soundness : ReplaySound env initial addressOf hash) (reach : Protocol.Trace env initial w)
    (ok : Protocol.land env w a = some t) :
    ∃ archive p bs supplied final,
      Certificate env w (Protocol.statement env w a) archive p bs addressOf hash supplied final ∧
      hash (snapshot final) = t.inbox.checkpoint.valStateHash ∧
      final.height = t.inbox.checkpoint.height ∧
      ∀ b ∈ bs, ∃ before after : CommitState,
        membership before.current = membership ⟨selected
          (Protocol.policy env (Protocol.certificateWorld env w a.input.l1ReferenceBlockNumber) archive
            a.input.l1ReferenceBlockNumber).consensus addressOf
          (Consensus.activeAt (Protocol.policy env (Protocol.certificateWorld env w a.input.l1ReferenceBlockNumber)
            archive a.input.l1ReferenceBlockNumber).consensus b.header.height),none⟩ ∧
        after.height = b.header.height ∧ hash (snapshot after) = b.header.valStateHash := by
  obtain ⟨sound,cover,verify⟩ := soundness
  obtain ⟨checks,rfl⟩ := Protocol.land_success ok
  obtain ⟨item,member,good⟩ := cover _ checks.proofs
  obtain ⟨proof,present,rfl⟩ := List.mem_map.mp member
  have all : ∀ x ∈ a.proofs.map (fun p => (p.backend,
      decide (p.image ∈ w.images) && env.verify w.verifier p.backend p.image p.bytes (Protocol.statement env w a))),
      x.2 = true := by
    have accepted := checks.proofs
    simp only [Protocol.proofsAccepted,dualOK,Bool.and_eq_true,List.all_eq_true] at accepted
    exact accepted.1.1.2
  have verified := all _ (List.mem_map_of_mem present)
  have bytes : env.verify w.verifier proof.backend proof.image proof.bytes (Protocol.statement env w a) = true := by
    simp only [Bool.and_eq_true] at verified
    exact verified.2
  obtain ⟨archive,p,bs,supplied,final,cert⟩ := verify w reach a _ proof ok present good bytes
  obtain ⟨_,fresh,start,_,_,run⟩ := cert.2
  have input := congrArg StatementData.input cert.1.1.2.2.1
  have parent : a.input.parentHeight = p.height := congrArg LandInput.parentHeight input
  have last : a.input.lastHeight = (Blocks.terminal p bs).height := congrArg LandInput.lastHeight input
  have valState : a.input.lastValStateHash = (Blocks.terminal p bs).valStateHash :=
    congrArg LandInput.lastValStateHash input
  have nonempty : bs ≠ [] := by
    rintro rfl
    have progress := checks.progress
    have frontier := checks.parentBeforeFrontier
    change a.input.lastHeight = p.height at last
    omega
  obtain ⟨hashed,height⟩ := checked_run_terminal run nonempty p
  refine ⟨archive,p,bs,supplied,final,cert,hashed.trans valState.symm,height.trans last.symm,?_⟩
  intro b present
  obtain ⟨before,after,_,signers,afterHeight,afterHash⟩ := checked_run_signers run b present
  exact ⟨before,after,signers,afterHeight,afterHash⟩

end Etna.Design.Current.ValidatorState
