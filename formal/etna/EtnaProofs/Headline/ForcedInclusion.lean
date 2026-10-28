import EtnaProofs.Headline.ChainOfCustody

/-! H3, forced-inclusion integrity (`Etna.Statements.ForcedInclusionIntegrity`), in three parts.
- Queue entries: every protocol step keeps every queue entry, except that a governance recovery
  blanks the entries its fiToClear lists (`queue_step_keeps_entries`).
- FI head: along every trace from the initialized World, record cursors are monotone in record
  height (`trace_record_cursors_monotone`), so every retained record's cursor is at most the
  head. A step that does not advance lastCheckpoint therefore never advances the head: rollback
  restores a retained record's cursor, and every other such step leaves the head as it is
  (`head_advances_only_in_landings`).
- Consumption: a submitted landing's certified batch, restarted at the current checkpoint, walks
  the FI cursor from the head to the new head one entry per block, and every block consumes
  entry c exactly when `Forced.step` accepts an inclusion or legal skip from a witness that shows
  the World's own queue entry c (`Premises.authenticatedInputs`); a due entry is always consumed
  (`landing_consumes_queue`). -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- Every protocol step keeps every FI queue entry, or it is a governance recovery whose
fiToClear lists the entry's index and which blanks it (txHash becomes keccak256(""), timestamp
and L1 block stay). Landings, registry steps, fee sweeps and rollback leave the queue as it is;
an enqueue appends; recovery rewrites exactly the listed entries (`Recovery.clearedQueue`). -/
theorem queue_step_keeps_entries {w t : ProtocolState.World} (change : ProtocolState.Step w t) :
    ∀ j entry, (j,entry) ∈ w.queue → (j,entry) ∈ t.queue ∨ Blanks w t j entry := by
  intro j entry mem
  cases change with
  | landing => exact Or.inl mem
  | registration => exact Or.inl mem
  | modification => exact Or.inl mem
  | enqueue => exact Or.inl (List.mem_append_left _ mem)
  | sweep => exact Or.inl mem
  | @recovery s a r owner externalOK _ ok =>
    have kept : (j,if a.fiToClear.contains j then Forced.clear w.adapters.recovery.emptyHash entry else entry) ∈
        (ProtocolState.recovered w a r s).queue := by
      obtain ⟨_,rfl⟩ := Recovery.recover_success ok
      exact List.mem_map_of_mem (f := fun (pair : Nat × Forced.Entry) =>
        (pair.1,if a.fiToClear.contains pair.1 then Forced.clear w.adapters.recovery.emptyHash pair.2 else pair.2)) mem
    by_cases listed : a.fiToClear.contains j = true
    · rw [ite_eq_left listed] at kept
      exact Or.inr ⟨a,r,owner,externalOK,s,ok,rfl,List.contains_iff_mem.mp listed,kept⟩
    · rw [ite_eq_right listed] at kept
      exact Or.inl kept
  | rollback => exact Or.inl mem

/-- The landing records' FI cursors are monotone in record height. -/
private def CursorsMonotone (records : List Checkpoint) : Prop :=
  ∀ a ∈ records, ∀ b ∈ records, a.height ≤ b.height → a.cursor ≤ b.cursor

/-- With monotone cursors, every retained record's cursor is at most the FI head: the
checkpoint record is retained, sits at the greatest height and carries the head
(`Settlement.StateValid`). -/
private theorem cursors_below_head {s : State} (valid : Settlement.StateValid s)
    (monotone : CursorsMonotone s.records) : ∀ a ∈ s.records, a.cursor ≤ s.head := by
  intro a mem
  obtain ⟨record,cursor,_,_,below⟩ := valid
  rw [← cursor]
  exact monotone a mem _ (List.mem_of_find?_eq_some record) (below a mem)

/-- Every protocol step keeps record cursors monotone. A landing adds a record above every old
one whose cursor, the new head, is at least the old head and so at least every old cursor;
rollback keeps a subset; every other step keeps the records. -/
private theorem step_cursors_monotone {w t : ProtocolState.World} (core : ProtocolState.Core w)
    (monotone : CursorsMonotone w.inbox.records) (change : ProtocolState.Step w t) :
    CursorsMonotone t.inbox.records := by
  have after := ProtocolState.step_preserves_core core change
  cases change with
  | landing _ ok =>
    obtain ⟨higher,_,_,records,_⟩ := land_extends_checkpoint ok
    have head := (land_fi_bound ok).1
    obtain ⟨_,newCursor,_,_,_⟩ := after.inbox.settled
    have old := cursors_below_head core.inbox.settled monotone
    have below := core.inbox.settled.2.2.2.2
    show CursorsMonotone (ProtocolState.landed w _ _).inbox.records
    simp only [ProtocolState.landed] at higher head newCursor ⊢
    rw [records]
    intro a ma b mb le
    rcases List.mem_cons.mp ma with rfl | ma <;> rcases List.mem_cons.mp mb with rfl | mb
    · exact Nat.le_refl _
    · have := below b mb
      omega
    · have := old a ma
      omega
    · exact monotone a ma b mb le
  | registration => exact monotone
  | modification => exact monotone
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok
    · cases ok
      exact monotone
    · contradiction
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok
    · cases ok
      exact monotone
    · contradiction
  | @recovery s _ _ _ _ _ ok =>
    show CursorsMonotone s.inbox.records
    rw [(Recovery.recovery_preserves_settled_prefix ok).2.1]
    exact monotone
  | rollback =>
    intro a ma b mb le
    exact monotone a (List.mem_filter.mp ma).1 b (List.mem_filter.mp mb).1 le

/-- Along every trace from an initialized World, a landing record at a greater height carries
an FI cursor at least as large. The initialized World has one record; each landing's record sits
above every old one with the new head as cursor (6.1: the head only moves forward in land);
rollback keeps the records at or below the trusted height. -/
theorem trace_record_cursors_monotone {w0 w : ProtocolState.World} {hash root : Hash}
    (init : Deployment.Genesis w0 hash root) (trace : ProtocolState.Trace w0 w) :
    ∀ a ∈ w.inbox.records, ∀ b ∈ w.inbox.records, a.height ≤ b.height → a.cursor ≤ b.cursor := by
  induction trace with
  | refl =>
    intro a ma b mb _
    rw [init.2.2.1,List.mem_singleton] at ma mb
    rw [ma,mb]
    exact Nat.le_refl _
  | step prior change ih =>
    exact step_cursors_monotone (Deployment.genesis_trace_invariants init prior).1 ih change

/-- Along every trace from an initialized World, a step that does not advance lastCheckpoint
never advances the FI head. Registration, registry edits, FI admission (it moves only the tail),
fee sweeps and recovery (`Recovery.recovery_preserves_settled_prefix`) keep the head; rollback
sets it to a retained record's cursor, which is at most the head
(`trace_record_cursors_monotone`); a landing always advances lastCheckpoint. -/
theorem head_advances_only_in_landings {w0 w t : ProtocolState.World} {hash root : Hash}
    (init : Deployment.Genesis w0 hash root) (trace : ProtocolState.Trace w0 w) (change : ProtocolState.Step w t)
    (settled : t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height) : t.inbox.head ≤ w.inbox.head := by
  have core := (Deployment.genesis_trace_invariants init trace).1
  have monotone := trace_record_cursors_monotone init trace
  cases change with
  | landing _ ok => exact absurd settled (Nat.not_le_of_lt (land_extends_checkpoint ok).1)
  | registration => exact Nat.le_refl _
  | modification => exact Nat.le_refl _
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok
    · cases ok
      exact Nat.le_refl _
    · contradiction
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok
    · cases ok
      exact Nat.le_refl _
    · contradiction
  | recovery _ ok => exact Nat.le_of_eq (Recovery.recovery_preserves_settled_prefix ok).2.2.1
  | rollback trusted _ _ _ retained =>
    show trusted.cursor ≤ w.inbox.head
    exact cursors_below_head core.inbox.settled monotone trusted (List.mem_of_find?_eq_some retained)

/-- `Forced.step` advances the cursor past c only while entry c is pending (c < tail): with
nothing pending it accepts only the unchanged cursor. -/
private theorem forced_advance_pending {c tail anchor delay : Nat} {w : Option Forced.Witness}
    {x : Forced.Singleton} (ok : Forced.step c tail anchor delay w x = .accepted (c+1)) : c < tail := by
  refine Nat.lt_of_not_le fun done => ?_
  simp only [Forced.step,show c ≥ tail from done,ite_true] at ok
  split at ok <;> simp_all

/-- While entry c is pending, an accepted `Forced.step` carries a witness for index c, and if
that witness's stored entry is due under the anchor, the cursor advances to c+1 (inclusion at
position 0 or a legal skip; 7.2). -/
private theorem forced_pending_witness {c tail anchor delay next : Nat} {w : Option Forced.Witness}
    {x : Forced.Singleton} (ok : Forced.step c tail anchor delay w x = .accepted next) (pending : c < tail) :
    ∃ wit, w = some wit ∧ wit.index = c ∧ (wit.stored.timestamp+delay ≤ anchor → next = c+1) := by
  cases w with
  | none => simp [Forced.step,show ¬c ≥ tail by omega] at ok
  | some wit =>
    refine ⟨wit,rfl,?_,fun due => ?_⟩
    · refine Classical.byContradiction fun other => ?_
      simp [Forced.step,show ¬c ≥ tail by omega,other] at ok
    · cases x <;> simp only [Forced.step,show ¬c ≥ tail by omega,ite_false] at ok <;>
        (repeat' split at ok) <;> simp_all <;> omega

/-- A queue whose indices are distinct holds at most one entry per index. -/
private theorem queue_entry_unique : ∀ {queue : List (Nat × Forced.Entry)}, (queue.map Prod.fst).Nodup →
    ∀ {j : Nat} {a b : Forced.Entry}, (j,a) ∈ queue → (j,b) ∈ queue → a = b
  | [], _, _, _, _, ma, _ => absurd ma List.not_mem_nil
  | x :: rest, nodup, j, a, b, ma, mb => by
    rw [List.map_cons,List.nodup_cons] at nodup
    rcases List.mem_cons.mp ma with ha | ha <;> rcases List.mem_cons.mp mb with hb | hb
    · rw [← ha] at hb
      exact (Prod.mk.inj hb).2.symm
    · subst ha
      exact absurd (List.mem_map_of_mem (f := Prod.fst) hb) nodup.1
    · subst hb
      exact absurd (List.mem_map_of_mem (f := Prod.fst) ha) nodup.1
    · exact queue_entry_unique nodup.2 ha hb

/-- Every (parent header, block) pair of a valid chain is a valid block on its parent. -/
private theorem chain_pairs_valid {r : BlockValidity.Rules} :
    ∀ {q : BlockValidity.Header} {bs : List BlockValidity.Block}, BlockValidity.Chain r q bs →
      ∀ x ∈ pairs q bs, BlockValidity.Valid r x.1 x.2 := by
  intro q bs
  induction bs generalizing q with
  | nil => exact fun _ x mem => absurd mem List.not_mem_nil
  | cons b rest ih =>
    intro ok x mem
    change x ∈ (q,b) :: pairs b.header rest at mem
    rcases List.mem_cons.mp mem with rfl | later
    · exact ok.1
    · exact ih ok.2 x later

/-- Along a valid chain the FI cursor moves by 0 or 1 per block, so every cursor value from the
first header's up to the last header's is stepped from j to j+1 by some pair of the chain. -/
private theorem chain_cursor_walk {r : BlockValidity.Rules} :
    ∀ {q : BlockValidity.Header} {bs : List BlockValidity.Block}, BlockValidity.Chain r q bs →
      ∀ j, q.cursor ≤ j → j < (BlockValidity.terminal q bs).cursor →
        ∃ x ∈ pairs q bs, x.1.cursor = j ∧ x.2.header.cursor = j+1 := by
  intro q bs
  induction bs generalizing q with
  | nil => exact fun _ j low high => absurd (Nat.lt_of_le_of_lt low high) (Nat.lt_irrefl _)
  | cons b rest ih =>
    intro ok j low high
    have step := BlockValidity.valid_cursor_step ok.1
    by_cases here : j < b.header.cursor
    · exact ⟨(q,b),List.mem_cons_self,show q.cursor = j by omega,show b.header.cursor = j+1 by omega⟩
    · obtain ⟨x,mem,start,next⟩ := ih ok.2 j (by omega) high
      exact ⟨x,List.mem_cons_of_mem _ mem,start,next⟩

/-- A submitted landing that the Inbox accepts on a World some run reaches settles blocks valid
under rules the deployment builds on that World, from the current checkpoint (FI cursor = head)
to the new one, and those blocks consume exactly the entries [head, new head), each by a block
that `Forced.step` lets include or legally skip it from a witness showing the World's own queue
entry, and every block consumes a pending due entry.
- The certified batch (`submitted_landing_certified`), restarted at the current checkpoint
  (`chain_suffix`, `Settlement.accepted_frontier_from_valid_chain`), starts at the head and ends
  at the new head; each block moves the cursor by 0 or 1 (`BlockValidity.valid_cursor_step`).
- A block's witness is authenticated under its anchor, which lies in the current generation and
  at or below the landing's reference block (`BlockValidity.AnchorValid`), so it shows the
  World's queue entry (`Premises.authenticatedInputs`); queue indices are distinct
  (`ProtocolState.Core`), so that is the one entry at its index. -/
theorem landing_consumes_queue {env : Environment} {w0 w : ProtocolState.World} {s : State}
    {i : LandInput} {leaves : List Leaf} {e : LandingEnv} (premises : Premises w0 env) (run : Run env w0 w)
    (submitted : env.submits w i leaves e) (ok : Etna.Design.land w.inbox i leaves e = some s) :
    ∃ r q bs, Built env w r ∧ Links r w.inbox.checkpoint s.checkpoint i.lastStateRoot q bs ∧
      q.cursor = w.inbox.head ∧
      (∀ j, w.inbox.head ≤ j → j < s.head → ∃ x ∈ pairs q bs, x.1.cursor = j ∧ x.2.header.cursor = j+1) ∧
      ∀ x ∈ pairs q bs, ServesQueue w r x.1 x.2 := by
  obtain ⟨r,p,bs,blobs,built,valid,binding⟩ := submitted_landing_certified premises run submitted ok
  -- The built rules read the World's K and origin and the environment's authentication relations.
  have rules : r.gridK = w.inbox.gridK ∧ r.anchorAuthenticated = env.anchorAuthenticated ∧
      r.forcedAuthenticated = env.forcedAuthenticated ∧ r.consensus.originBlock = w.inbox.origin.l1Block := by
    obtain ⟨_,_,_,construction⟩ := built
    obtain ⟨_,_,_,_,_,_,_,c,context,rfl⟩ := Deployment.build_success construction
    rw [(HistoricalContext.build_success context).2]
    exact ⟨rfl,rfl,rfl,rfl⟩
  obtain ⟨core,constraints,_⟩ := Deployment.genesis_trace_invariants premises.genesis.1 (run_trace run)
  obtain ⟨record,cursor,⟨grid,_⟩,_,_⟩ := core.inbox.settled
  have positive : 0 < w.inbox.gridK := (of_decide_eq_true constraints.1).1
  have nodup : (w.queue.map Prod.fst).Nodup := core.queue ▸ List.nodup_range
  have input := Settlement.accepted_input ok binding
  subst input
  obtain ⟨⟨⟨⟨_,_,parentBelow,advance,_,parentGrid,lastGrid,_,_,_,_,_,_,reference,_⟩,_⟩,_,_⟩,rfl⟩ := land_success ok
  have frontier := Settlement.accepted_frontier_from_valid_chain ok valid binding (by rw [rules.1]; exact parentGrid)
    (by rw [rules.1]; exact lastGrid) rules.1.symm positive grid record
  change p.height ≤ _ at parentBelow
  change _ < (BlockValidity.terminal p bs).height at advance
  have heights := BlockValidity.chain_height valid.1
  -- The batch restarted at the current checkpoint c.
  obtain ⟨x,_,cut,height,chain,last⟩ := chain_suffix (w.inbox.checkpoint.height-p.height) valid.1 (by omega)
  have start : x.cut = ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.checkpoint.cursor⟩ := by
    rw [cut,frontier,cursor]
  have startCursor : x.cursor = w.inbox.head := (congrArg Cut.cursor start).trans cursor
  -- An authenticated witness under a block's anchor shows the World's queue entry.
  have shown : ∀ y ∈ pairs x (bs.drop (w.inbox.checkpoint.height-p.height)), ∀ wit, y.2.forced = some wit →
      wit.index < y.2.header.anchor.tail → (wit.index,wit.stored) ∈ w.queue := by
    intro y mem wit carried below
    have blockValid := chain_pairs_valid chain y mem
    obtain ⟨_,origin,referenced,_,_,_,_,_,_,_,_,_,anchored⟩ := blockValid.2.2.2.1
    have authenticated : r.forcedAuthenticated y.2.header.anchor wit = true := by
      have external := blockValid.2.2.2.2.2.2.2.2.2.1
      rw [carried] at external
      exact external
    rw [rules.2.1] at anchored
    rw [rules.2.2.1] at authenticated
    rw [rules.2.2.2] at origin
    exact premises.authenticatedInputs w _ leaves e _ submitted ok _ wit anchored authenticated origin
      (Nat.lt_of_le_of_lt referenced reference) below
  refine ⟨r,x,bs.drop (w.inbox.checkpoint.height-p.height),built,⟨chain,by omega,start,?_,?_,?_⟩,startCursor,?_,?_⟩
  · rw [last]
    rfl
  · rw [last]
    rfl
  · rw [last]
    rfl
  · intro j low high
    exact chain_cursor_walk chain j (startCursor ▸ low) (by rw [last]; exact high)
  · intro y mem
    have stepped := (chain_pairs_valid chain y mem).2.2.2.2.2.2.1
    refine ⟨fun next => ?_,fun entry queued pending due => ?_⟩
    · rw [next] at stepped
      have pending := forced_advance_pending stepped
      obtain ⟨wit,carried,index,_⟩ := forced_pending_witness stepped pending
      have stored := shown y mem wit carried (index ▸ pending)
      rw [index] at stored
      exact ⟨stepped,wit,carried,index,stored⟩
    · obtain ⟨wit,carried,index,consumed⟩ := forced_pending_witness stepped pending
      have stored := shown y mem wit carried (index ▸ pending)
      rw [index] at stored
      rw [queue_entry_unique nodup stored queued] at consumed
      exact consumed due

/-- H3, forced-inclusion integrity: see `Etna.Statements.ForcedInclusionIntegrity`. -/
theorem forced_inclusion_integrity : ForcedInclusionIntegrity := by
  intro env w0 premises
  exact ⟨fun _ _ _ change => queue_step_keeps_entries change,
    fun _ _ trace change settled => head_advances_only_in_landings premises.genesis.1 trace change settled,
    fun _ _ _ _ _ run submitted _ ok => landing_consumes_queue premises run submitted ok⟩

end Etna.Proofs
