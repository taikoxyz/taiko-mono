import EtnaModel.ActualQueue
import EtnaProofs.CanonicalHistory
import EtnaProofs.Headline.AnchoredQueue

namespace Etna.Design.ActualQueue
open ProtocolState AnchorHonesty

/-- Forget time annotations only: every journal entry is the original accepted call. -/
theorem transactions_trace {time : Nat → Nat} {initial w : World} {states : List World}
    (history : Transactions time initial states w) : Trace initial w := by
  induction history with
  | nil => exact .refl _
  | step _ call _ ih => exact .step ih call

private theorem trace_journal {time : Nat → Nat} {initial w : World} {trace : Trace initial w}
    (timed : TraceTime time trace) : ∃ states, Transactions time initial states w := by
  induction timed with
  | refl => exact ⟨[],.nil _⟩
  | @step w t trace prior call timestamp ih =>
    obtain ⟨states,history⟩ := ih
    exact ⟨states ++ [t],.step history call timestamp⟩

/-- A compatible lift of Task 1's exact canonical provenance. The only annotation adds
the EVM admission timestamp binding; no prior canonical constructor or API is changed. -/
theorem canonical_journal {time : Nat → Nat} {initial w : World} {archive : List Nat}
    (run : CanonicalHistory.Run initial w archive)
    (timed : TraceTime time (CanonicalHistory.run_trace run)) :
    ∃ states, Transactions time initial states w := trace_journal timed

private theorem time_step {time : Nat → Nat} {w t : World} {call : Step w t}
    (annotation : EnqueueTime time call) (timed : QueueTimed time w) : QueueTimed time t := by
  cases annotation with
  | landing => exact timed
  | registration => exact timed
  | modification => exact timed
  | enqueue _ _ _ _ clock =>
    intro j entry member
    rcases List.mem_append.mp member with old | added
    · exact timed j entry old
    · simp only [List.mem_singleton,Prod.mk.injEq] at added
      rw [added.2]
      exact clock
  | sweep => exact timed
  | recovery _ ok =>
    obtain ⟨_,rfl⟩ := Recovery.recover_success ok
    intro j entry member
    obtain ⟨⟨k,old⟩,queued,equal⟩ := List.mem_map.mp member
    cases equal
    split <;> exact timed j old queued
  | invalidation => exact timed
  | rollback => exact timed

/-- Queue timing is an induction from an empty initialized queue and original timestamped
admissions. Recovery blanking and verifier rollback preserve admission metadata. -/
theorem history_queue_timed {time : Nat → Nat} {initial w : World} {states : List World}
    {hash root : Hash} (init : Deployment.Genesis initial hash root)
    (history : Transactions time initial states w) : QueueTimed time w := by
  have empty : initial.queue = [] := init.2.2.2.2.2.2.1
  have start : QueueTimed time initial := by intro j entry member; simp [empty] at member
  induction history with
  | nil => exact start
  | step _ _ annotation ih => exact time_step annotation ih

private theorem old_admission {w t : World} (call : Step w t) {number : Nat}
    (later : number < t.l1Block) :
    ∀ j entry, (j,entry) ∈ t.queue → entry.l1Block ≤ number →
      ∃ old, (j,old) ∈ w.queue ∧ old.l1Block = entry.l1Block := by
  cases call with
  | landing => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | registration => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | modification => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | enqueue =>
    intro j entry member before
    rcases List.mem_append.mp member with old | added
    · exact ⟨entry,old,rfl⟩
    · simp only [List.mem_singleton,Prod.mk.injEq] at added
      rw [added.2] at before
      exact False.elim (by exact (Nat.not_le_of_gt later) before)
  | sweep => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | recovery _ ok =>
    obtain ⟨_,rfl⟩ := Recovery.recover_success ok
    intro j entry member _
    obtain ⟨⟨k,old⟩,queued,equal⟩ := List.mem_map.mp member
    cases equal
    refine ⟨old,queued,?_⟩
    split <;> rfl
  | invalidation => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | rollback => exact fun _ e mem _ => ⟨e,mem,rfl⟩

private theorem suffix_admission {time : Nat → Nat} {snapshot w : World} {states : List World}
    (history : Transactions time snapshot states w) {number : Nat}
    (after : ∀ state ∈ states, number < state.l1Block) :
    ∀ j entry, (j,entry) ∈ w.queue → entry.l1Block ≤ number →
      ∃ old, (j,old) ∈ snapshot.queue ∧ old.l1Block = entry.l1Block := by
  induction history with
  | nil => exact fun _ e mem _ => ⟨e,mem,rfl⟩
  | @step prior current states history call _ ih =>
    intro j entry member before
    obtain ⟨old,queued,same⟩ := old_admission call
      (after current (List.mem_append_right _ (by simp))) j entry member before
    obtain ⟨original,present,equal⟩ := ih (fun s mem => after s (List.mem_append_left _ mem))
      j old queued (same ▸ before)
    exact ⟨original,present,equal.trans same⟩

/-- The actual end-block tail covers all later entries admitted no later than that block.
Strict suffix order is essential even when several transactions share a block number. -/
theorem end_block_covers {time : Nat → Nat} {initial w : World} {states : List World}
    {hash root : Hash} {anchor : BlockValidity.Anchor} (init : Deployment.Genesis initial hash root)
    (cut : EndBlock time initial w states anchor) : AnchorCovers time w anchor := by
  refine ⟨cut.timestamp,fun j entry member before => ?_⟩
  obtain ⟨old,queued,_⟩ := suffix_admission cut.later cut.after j entry member before
  have core := (Deployment.genesis_trace_invariants init (transactions_trace cut.before)).1
  have index := List.mem_map_of_mem (f := Prod.fst) queued
  rw [core.queue,List.mem_range] at index
  rw [cut.tail]
  exact index

private theorem step_after_origin {w t : World} (call : Step w t) {number : Nat}
    (after : number < t.l1Block) (origin : t.inbox.origin.l1Block ≤ number) :
    w.inbox.origin = t.inbox.origin ∧ ∀ j entry, (j,entry) ∈ w.queue → (j,entry) ∈ t.queue := by
  cases call with
  | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; exact ⟨rfl,fun _ _ mem => mem⟩
  | registration => exact ⟨rfl,fun _ _ mem => mem⟩
  | modification => exact ⟨rfl,fun _ _ mem => mem⟩
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok <;> cases ok
    exact ⟨rfl,fun _ _ mem => List.mem_append_left _ mem⟩
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact ⟨rfl,fun _ _ mem => mem⟩
  | recovery _ ok =>
    obtain ⟨_,rfl⟩ := Recovery.recover_success ok
    exact False.elim (Nat.not_le_of_gt after origin)
  | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact ⟨rfl,fun _ _ mem => mem⟩
  | rollback => exact ⟨rfl,fun _ _ mem => mem⟩

private theorem suffix_preserves {time : Nat → Nat} {snapshot w : World} {states : List World}
    (history : Transactions time snapshot states w) {number : Nat}
    (after : ∀ state ∈ states, number < state.l1Block) (origin : w.inbox.origin.l1Block ≤ number) :
    ∀ j entry, (j,entry) ∈ snapshot.queue → (j,entry) ∈ w.queue := by
  induction history with
  | nil => exact fun _ _ mem => mem
  | @step prior current states history call _ ih =>
    obtain ⟨same,preserve⟩ := step_after_origin call
      (after current (List.mem_append_right _ (by simp))) origin
    intro j entry member
    apply preserve j entry
    exact ih (fun s mem => after s (List.mem_append_left _ mem)) (same ▸ origin) j entry member

/-- Current-generation origin validity rules out every later recovery in this suffix.
Thus an authenticated stored entry remains byte-for-byte the current entry; no arbitrary
InputsAuthenticated predicate and no submitted landing is needed. -/
theorem end_block_entry_current {time : Nat → Nat} {initial w : World} {states : List World}
    {anchor : BlockValidity.Anchor} (cut : EndBlock time initial w states anchor)
    (origin : w.inbox.origin.l1Block ≤ anchor.number) {j : Nat} {entry : Forced.Entry}
    (opened : (j,entry) ∈ cut.snapshot.queue) : (j,entry) ∈ w.queue :=
  suffix_preserves cut.later cut.after origin j entry opened

private theorem queue_unique : ∀ {queue : List (Nat × Forced.Entry)}, (queue.map Prod.fst).Nodup →
    ∀ {j : Nat} {a b : Forced.Entry}, (j,a) ∈ queue → (j,b) ∈ queue → a = b
  | [], _, _, _, _, ma, _ => absurd ma List.not_mem_nil
  | x :: rest, nodup, j, a, b, ma, mb => by
    rw [List.map_cons,List.nodup_cons] at nodup
    rcases List.mem_cons.mp ma with ha | ha <;> rcases List.mem_cons.mp mb with hb | hb
    · rw [← ha] at hb; exact (Prod.mk.inj hb).2.symm
    · subst ha; exact absurd (List.mem_map_of_mem (f := Prod.fst) hb) nodup.1
    · subst hb; exact absurd (List.mem_map_of_mem (f := Prod.fst) ha) nodup.1
    · exact queue_unique nodup.2 ha hb

private theorem pending_witness {c tail anchor delay next : Nat} {w : Option Forced.Witness}
    {x : Forced.Singleton} (ok : Forced.step c tail anchor delay w x = .accepted next) (pending : c < tail) :
    ∃ wit, w = some wit ∧ wit.index = c ∧ (wit.stored.timestamp+delay ≤ anchor → next = c+1) := by
  cases w with
  | none => simp [Forced.step,show ¬c ≥ tail by omega] at ok
  | some wit =>
    refine ⟨wit,rfl,?_,fun due => ?_⟩
    · exact Classical.byContradiction (fun other => by simp [Forced.step,show ¬c ≥ tail by omega,other] at ok)
    · cases x <;> simp only [Forced.step,show ¬c ≥ tail by omega,ite_false] at ok <;>
        (repeat' split at ok) <;> simp_all <;> omega

/-- Every valid local block serves its own parent cursor using an opening under its actual
historical anchor. This covers unlanded blocks; it makes no claim that later blocks must
consume the already-serviced L1 head again. -/
theorem local_block_service {time : Nat → Nat} {initial w : World} {states : List World}
    {hash root : Hash} {r : BlockValidity.Rules} {p : BlockValidity.Header} {b : BlockValidity.Block}
    {primitive : Primitives} (init : Deployment.Genesis initial hash root)
    (history : Transactions time initial states w)
    (origin : OriginMatches r w)
    (openings : Openings primitive time initial w states r) (valid : BlockValidity.Valid r p b) :
    Etna.Statements.ServesQueue w r p b := by
  have stepped := valid.2.2.2.2.2.2.1
  have anchored := valid.2.2.2.1
  have external := valid.2.2.2.2.2.2.2
  have core := (Deployment.genesis_trace_invariants init (transactions_trace history)).1
  have unique : (w.queue.map Prod.fst).Nodup := core.queue ▸ List.nodup_range
  have shown : ∀ wit, b.forced = some wit → (wit.index,wit.stored) ∈ w.queue := by
    intro wit carried
    have auth := external.2.2.1
    rw [carried] at auth
    obtain ⟨cut,raw,first,stored,_⟩ := openings p b wit anchored.2.2.2.2.2.2.2.2.2.2.2.2
      external.1 external.2.1 auth carried
    exact end_block_entry_current cut (origin ▸ anchored.2.1) stored
  refine ⟨fun next => ?_,fun entry queued pending due => ?_⟩
  · rw [next] at stepped
    have pending : p.cursor < b.header.anchor.tail := by
      refine Nat.lt_of_not_le fun h => ?_
      simp only [Forced.step,show p.cursor ≥ b.header.anchor.tail by omega,ite_true] at stepped
      split at stepped <;> simp_all
    obtain ⟨wit,carried,index,_⟩ := pending_witness stepped pending
    exact ⟨stepped,wit,carried,index,index ▸ shown wit carried⟩
  · obtain ⟨wit,carried,index,consumed⟩ := pending_witness stepped pending
    have stored := shown wit carried
    rw [index] at stored
    rw [queue_unique unique stored queued] at consumed
    exact consumed due

private theorem pair_valid {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} (chain : BlockValidity.Chain r p bs) :
    ∀ x ∈ Etna.Statements.pairs p bs, BlockValidity.Valid r x.1 x.2 := by
  induction bs generalizing p with
  | nil => simp [Etna.Statements.pairs]
  | cons b rest ih =>
    intro x member
    rcases List.mem_cons.mp member with rfl | later
    · exact chain.1
    · exact ih chain.2 x later

/-- Compose the existing inclusive anchor-age bound with actual-history timing, actual
end-block tails and low-level openings. For every block of a local chain, the current
parent-cursor entry is consumed at timestamp ≥ enqueueTime + delay + maxAge. The chain
need not have been landed or submitted, and there is no wall-clock liveness conclusion. -/
theorem local_chain_service {time : Nat → Nat} {initial w : World} {states : List World}
    {hash root : Hash} {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {primitive : Primitives} (init : Deployment.Genesis initial hash root)
    (history : Transactions time initial states w) (clock : ClockMonotone time)
    (positive : 0 < r.forcedDelay) (origin : OriginMatches r w)
    (anchors : Anchors time initial w states r) (openings : Openings primitive time initial w states r)
    (chain : BlockValidity.Chain r p bs) :
    ∀ x ∈ Etna.Statements.pairs p bs, Etna.Statements.ServesQueue w r x.1 x.2 ∧
      ∀ entry, (x.1.cursor,entry) ∈ w.queue →
        entry.timestamp+r.forcedDelay+r.maxAnchorAge ≤ x.2.header.timestamp →
        x.2.header.cursor = x.1.cursor+1 := by
  have honest : ∀ A, r.anchorAuthenticated A = true → AnchorCovers time w A := by
    intro A accepted
    obtain ⟨cut⟩ := anchors A accepted
    exact end_block_covers init cut
  intro x member
  have serves := local_block_service init history origin openings (pair_valid chain x member)
  refine ⟨serves,fun entry queued late => ?_⟩
  obtain ⟨pending,due⟩ := Etna.Proofs.honest_anchor_chain_sees_due chain positive clock
    (history_queue_timed init history) honest x member entry queued late
  exact serves.2 entry queued pending due

/-- Decode an accepted cursor advance into actual include/skip semantics. This is where
the explicit hash, parser and deterministic singleton contracts are used. -/
theorem opened_advance_action {primitive : Primitives} {p : BlockValidity.Header}
    {b : BlockValidity.Block} {wit : Forced.Witness} {raw : Bytes} {first : Option Bytes} {delay : Nat}
    (fields : PayloadFields primitive p b wit raw first)
    (accepted : Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp delay
      (some wit) b.singleton = .accepted (p.cursor+1)) :
    ByteAction primitive p b wit.stored raw first := by
  have flags : (wit.firstHash = some wit.stored.txHash ∧ wit.firstCanonical = true ∧ wit.firstBytes ≤ 8192) ∨
      (wit.rawHash = wit.stored.txHash ∧ wit.rawBytes ≤ 8192 ∧
        (wit.canonical = false ∨ b.singleton = .completedEmpty)) := by
    cases result : b.singleton <;> rw [result] at accepted <;>
      simp only [Forced.step] at accepted <;> (repeat' split at accepted) <;> simp_all <;> omega
  obtain ⟨size,hash,parse,firstHash,firstParse,firstSize,result⟩ := fields
  rcases flags with included | skipped
  · apply Or.inl
    rw [firstHash,firstParse,firstSize] at included
    cases first with
    | none => simp at included
    | some tx => exact ⟨tx,rfl,Option.some.inj included.1,included.2⟩
  · exact Or.inr ⟨hash ▸ skipped.1,size ▸ skipped.2.1,
      skipped.2.2.elim (fun invalid => Or.inl (parse ▸ invalid)) (fun empty => Or.inr (result ▸ empty))⟩

/-- The full byte-level service composition: every due local-cursor entry is advanced,
and the very authenticated raw/position-zero bytes describe either inclusion or a legal
invalid/empty skip. This does not rely on any submitted landing or arbitrary parser flag. -/
theorem local_chain_byte_service {time : Nat → Nat} {initial w : World} {states : List World}
    {hash root : Hash} {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {primitive : Primitives} (init : Deployment.Genesis initial hash root)
    (history : Transactions time initial states w) (clock : ClockMonotone time)
    (positive : 0 < r.forcedDelay) (origin : OriginMatches r w)
    (anchors : Anchors time initial w states r) (openings : Openings primitive time initial w states r)
    (chain : BlockValidity.Chain r p bs) :
    ∀ x ∈ Etna.Statements.pairs p bs, ∀ entry, (x.1.cursor,entry) ∈ w.queue →
      entry.timestamp+r.forcedDelay+r.maxAnchorAge ≤ x.2.header.timestamp →
      x.2.header.cursor = x.1.cursor+1 ∧
      ∃ wit raw first, x.2.forced = some wit ∧ wit.index = x.1.cursor ∧ wit.stored = entry ∧
        PayloadFields primitive x.1 x.2 wit raw first ∧ ByteAction primitive x.1 x.2 entry raw first := by
  intro x member entry queued late
  have valid := pair_valid chain x member
  have service := local_chain_service init history clock positive origin anchors openings chain x member
  have next := service.2 entry queued late
  obtain ⟨accepted,wit,carried,index,stored⟩ := service.1.1 next
  have core := (Deployment.genesis_trace_invariants init (transactions_trace history)).1
  have same := queue_unique (core.queue ▸ List.nodup_range) stored queued
  have anchored := valid.2.2.2.1
  have external := valid.2.2.2.2.2.2.2
  have auth := external.2.2.1
  rw [carried] at auth
  obtain ⟨cut,raw,first,_,_,fields⟩ := openings x.1 x.2 wit anchored.2.2.2.2.2.2.2.2.2.2.2.2
    external.1 external.2.1 auth carried
  rw [carried] at accepted
  exact ⟨next,wit,raw,first,carried,index,same,fields,same ▸ opened_advance_action fields accepted⟩

/-- An eligible, omitted transaction whose deterministic singleton retains it cannot be
skipped when due. The low-level opening fixes both the parser flag and singleton result. -/
theorem eligible_nonempty_forbids_skip {primitive : Primitives} {snapshot : World}
    {p : BlockValidity.Header} {b : BlockValidity.Block} {wit : Forced.Witness} {delay : Nat}
    (opening : WitnessOpening primitive snapshot p b wit)
    (pending : p.cursor < b.header.anchor.tail) (due : wit.stored.timestamp+delay ≤ b.header.anchor.timestamp)
    (eligible : wit.canonical = true) (retained : b.singleton = .completedRetained)
    (omitted : ¬(wit.firstHash = some wit.stored.txHash ∧ wit.firstCanonical = true ∧ wit.firstBytes ≤ 8192)) :
    Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp delay (some wit) b.singleton = .rejected := by
  obtain ⟨raw,first,_,auth,_⟩ := opening
  simp only [Forced.step,show ¬p.cursor ≥ b.header.anchor.tail by omega,ite_false]
  repeat' split
  all_goals simp_all <;> omega

end Etna.Design.ActualQueue
