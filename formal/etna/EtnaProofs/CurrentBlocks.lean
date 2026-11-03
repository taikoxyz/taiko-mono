import EtnaModel.CurrentBlocks
import EtnaProofs.ActualQueue
import EtnaProofs.BlockValidity

namespace Etna.Design.Current.Blocks

theorem first_anchor_witness {r : GenerationPolicy} {p : Header} {b : Block}
    (first : p.height = r.consensus.originHeight) (ok : AnchorValid r p b) :
    b.body.anchorWitness = true := by
  simpa [ParentAnchorValid,first] using ok.parent

theorem later_anchor_rules {r : GenerationPolicy} {p : Header} {b : Block}
    (later : p.height ≠ r.consensus.originHeight) (ok : AnchorValid r p b) :
    p.anchor.number ≤ b.header.anchor.number ∧ r.consensus.anchorAt p.height = p.anchor.number ∧
    b.body.anchorWitness = decide (p.anchor.number ≠ b.header.anchor.number) ∧
    (p.anchor.number = b.header.anchor.number → p.anchor = b.header.anchor) := by
  simpa [ParentAnchorValid,later] using ok.parent

theorem unknown_rules_refused {r : GenerationPolicy} {p : Header} {b : Block}
    (unknown : r.catalogue (selectedRules b) = none) : ¬Valid r p b := by
  intro ok
  have selected := ok.selected
  rw [unknown] at selected
  cases selected

theorem valid_parent_links {r : GenerationPolicy} {p : Header} {b : Block} (ok : Valid r p b) :
    b.header.height = p.height+1 ∧ b.body.parentHash = p.elHash ∧
    b.body.lastBlockId = (if p.height = r.consensus.originHeight then none else some p.cometHash) :=
  ⟨ok.header.1,ok.header.2.1,ok.header.2.2.1⟩

theorem valid_cursor_step {r : GenerationPolicy} {p : Header} {b : Block} (ok : Valid r p b) :
    p.cursor ≤ b.header.cursor ∧ b.header.cursor ≤ p.cursor+1 := by
  have step := Forced.step_one_or_zero ok.forced
  rcases step with h | h <;> omega

theorem chain_height {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    (terminal p bs).height = p.height+bs.length := by
  induction bs generalizing p with
  | nil => simp [terminal]
  | cons b rest ih =>
    have height := ok.1.header.1
    have tail := ih ok.2
    simp only [terminal,List.length_cons]
    omega

theorem chain_parent_hashes {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    bs.map (fun b => b.body.parentHash) = ((p :: bs.map Block.header).dropLast).map BlockValidity.Header.elHash := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    have link := ok.1.header.2.1
    have tail := ih ok.2
    cases rest with
    | nil => simp [link]
    | cons c more =>
      simp only [List.map_cons,List.dropLast_cons_cons] at tail ⊢
      rw [link,tail]

theorem chain_append {r : GenerationPolicy} (p : Header) (as bs : List Block) :
    Chain r p (as ++ bs) ↔ Chain r p as ∧ Chain r (terminal p as) bs := by
  induction as generalizing p with
  | nil => simp [Chain,terminal]
  | cons a rest ih => simp only [List.cons_append,Chain,terminal,ih,and_assoc]

theorem terminal_append (p : Header) (as bs : List Block) :
    terminal p (as ++ bs) = terminal (terminal p as) bs := by
  induction as generalizing p with
  | nil => rfl
  | cons a rest ih => exact ih a.header

theorem chain_suffix {r : GenerationPolicy} {p : Header} {bs : List Block}
    (ok : Chain r p bs) (n : Nat) :
    Chain r p (bs.take n) ∧ Chain r (headerAt p bs n) (bs.drop n) := by
  apply (chain_append p (bs.take n) (bs.drop n)).mp
  simpa using ok

theorem suffix_terminal (p : Header) (bs : List Block) (n : Nat) :
    terminal (headerAt p bs n) (bs.drop n) = terminal p bs := by
  rw [headerAt,← terminal_append,List.take_append_drop]

theorem headerAt_height {r : GenerationPolicy} {p : Header} {bs : List Block}
    (ok : Chain r p bs) {n : Nat} (bound : n ≤ bs.length) :
    (headerAt p bs n).height = p.height+n := by
  have height := chain_height (chain_suffix ok n).1
  simpa [headerAt,List.length_take,Nat.min_eq_left bound] using height

theorem cuts_length (p : Header) (bs : List Block) : (cuts p bs).length = bs.length+1 := by simp [cuts]

theorem cuts_origin (p : Header) (bs : List Block) : (cuts p bs).head? = some p.cut := rfl

theorem cuts_terminal (p : Header) (bs : List Block) :
    (cuts p bs).getLast? = some (terminal p bs).cut := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    simpa only [cuts,List.map_cons,List.getLast?_cons_cons,terminal] using ih b.header

theorem cuts_getD (p : Header) (bs : List Block) (n : Nat) (bound : n ≤ bs.length) :
    (cuts p bs).getD n default = (headerAt p bs n).cut := by
  induction bs generalizing p n with
  | nil =>
    have : n = 0 := by simpa using bound
    subst n
    rfl
  | cons b rest ih =>
    cases n with
    | zero => rfl
    | succ n =>
      have hn : n ≤ rest.length := by simpa using bound
      simpa [cuts,headerAt,terminal,List.getD] using ih b.header n hn

theorem headerAt_getD (p : Header) (bs : List Block) (n : Nat) (bound : n ≤ bs.length) :
    (p :: bs.map Block.header).getD n p = headerAt p bs n := by
  induction bs generalizing p n with
  | nil =>
    have : n = 0 := by simpa using bound
    subst n
    rfl
  | cons b rest ih =>
    cases n with
    | zero => rfl
    | succ n =>
      have hn : n ≤ rest.length := by simpa using bound
      have h := ih b.header n hn
      have len : n < (b.header :: rest.map Block.header).length := by simp; omega
      simpa [headerAt,terminal,List.getD_eq_getElem?_getD,List.getElem?_eq_getElem len] using h

theorem pair_valid {r : GenerationPolicy} {p : Header} {bs : List Block} (chain : Chain r p bs) :
    ∀ x ∈ pairs p bs, Valid r x.1 x.2 := by
  induction bs generalizing p with
  | nil => simp [pairs]
  | cons b rest ih =>
    intro x member
    rcases List.mem_cons.mp member with rfl | later
    · exact chain.1
    · exact ih chain.2 x later

theorem pairs_append (p : Header) (as bs : List Block) :
    pairs p (as ++ bs) = pairs p as ++ pairs (terminal p as) bs := by
  induction as generalizing p with
  | nil => rfl
  | cons a rest ih => simp [pairs,terminal,ih]

theorem pairs_suffix (p : Header) (bs : List Block) (n : Nat) :
    pairs p bs = pairs p (bs.take n) ++ pairs (headerAt p bs n) (bs.drop n) := by
  rw [headerAt,← pairs_append,List.take_append_drop]

theorem chain_cursor_walk {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    ∀ edge ∈ cursorWalk p bs, edge.1 ≤ edge.2 ∧ edge.2 ≤ edge.1+1 := by
  intro edge member
  obtain ⟨pair,mem,rfl⟩ := List.mem_map.mp member
  exact valid_cursor_step (pair_valid ok pair mem)

theorem chain_cursor_steps {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    cursorSteps (cuts p bs) = true := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    change decide (p.cursor ≤ b.header.cursor ∧ b.header.cursor ≤ p.cursor+1) &&
      cursorSteps (cuts b.header rest) = true
    simp only [Bool.and_eq_true,decide_eq_true_eq]
    exact ⟨valid_cursor_step ok.1,ih ok.2⟩

theorem chain_cursor_bounds {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    p.cursor ≤ (terminal p bs).cursor ∧ (terminal p bs).cursor ≤ p.cursor+bs.length := by
  induction bs generalizing p with
  | nil => simp [terminal]
  | cons b rest ih =>
    have first := valid_cursor_step ok.1
    have tail := ih ok.2
    simp only [terminal,List.length_cons]
    omega

theorem statement_endpoints (r : GenerationPolicy) (p : Header) (bs : List Block) (blobs : List Hash) :
    (statement r p bs blobs).input.parentHeight = p.height ∧
    (statement r p bs blobs).input.lastHeight = (terminal p bs).height ∧
    (statement r p bs blobs).input.lastBlockHash = (terminal p bs).elHash ∧
    (statement r p bs blobs).input.lastStateRoot = (terminal p bs).stateRoot ∧
    (statement r p bs blobs).input.forcedInclusionHead = (terminal p bs).cursor ∧
    (statement r p bs blobs).cutHash = tableHash r.gridK r.consensus.generation p.height
      (terminal p bs).height (cuts p bs) := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- A pending accepted step exposes its own authenticated entry and inclusive due rule. -/
theorem pending_witness {c tail anchor delay next : Nat} {w : Option Forced.Witness}
    {x : Forced.Singleton} (ok : Forced.step c tail anchor delay w x = .accepted next) (pending : c < tail) :
    ∃ wit, w = some wit ∧ wit.index = c ∧ (wit.stored.timestamp+delay ≤ anchor → next = c+1) := by
  cases w with
  | none => simp [Forced.step,show ¬c ≥ tail by omega] at ok
  | some wit =>
    refine ⟨wit,rfl,?_,fun due => ?_⟩
    · exact Classical.byContradiction (fun other => by simp [Forced.step,show ¬c ≥ tail by omega,other] at ok)
    · cases x <;> simp only [Forced.step,show ¬c ≥ tail by omega,ite_false] at ok <;>
        (repeat' split at ok) <;> simp_all <;> omega

theorem valid_advance_action {r : GenerationPolicy} {p : Header} {b : Block} (ok : Valid r p b)
    (next : b.header.cursor = p.cursor+1) :
    ∃ w, b.body.forced = some w ∧ w.index = p.cursor ∧
      ActualQueue.ByteAction (definition r b).bytes p b.body w.stored b.raw b.first := by
  have stepped := ok.forced
  rw [next] at stepped
  have pending : p.cursor < b.header.anchor.tail := by
    apply Nat.lt_of_not_le
    intro le
    simp only [Forced.step,le,ite_true] at stepped
    split at stepped <;> simp_all
  obtain ⟨w,carried,index,_⟩ := pending_witness stepped pending
  refine ⟨w,carried,index,?_⟩
  rw [carried] at stepped
  exact ActualQueue.opened_advance_action (ok.fields w carried) stepped

theorem valid_due_action {r : GenerationPolicy} {p : Header} {b : Block} {w : Forced.Witness}
    (ok : Valid r p b) (pending : p.cursor < b.header.anchor.tail)
    (carried : b.body.forced = some w) (due : w.stored.timestamp+r.forcedDelay ≤ b.header.anchor.timestamp) :
    b.header.cursor = p.cursor+1 ∧ w.index = p.cursor ∧
      ActualQueue.ByteAction (definition r b).bytes p b.body w.stored b.raw b.first := by
  obtain ⟨wit,equal,index,advance⟩ := pending_witness ok.forced pending
  rw [carried] at equal
  have same := Option.some.inj equal
  subst wit
  have next := advance due
  obtain ⟨other,found,_,action⟩ := valid_advance_action ok next
  rw [carried] at found
  have same := Option.some.inj found
  subst other
  exact ⟨next,index,action⟩

/-- Age transports the actual inclusive due timestamp to the authenticated L1 anchor.
The caller supplies only actual entry visibility, never a queue-service assertion. -/
theorem valid_late_action {r : GenerationPolicy} {p : Header} {b : Block} {w : Forced.Witness}
    (ok : Valid r p b) (pending : p.cursor < b.header.anchor.tail)
    (carried : b.body.forced = some w)
    (late : w.stored.timestamp+r.forcedDelay+r.maxAnchorAge ≤ b.header.timestamp) :
    b.header.cursor = p.cursor+1 ∧ w.index = p.cursor ∧
      ActualQueue.ByteAction (definition r b).bytes p b.body w.stored b.raw b.first :=
  valid_due_action ok pending carried
    (Forced.overdue_from_block_time _ _ _ _ _ ok.anchor.age ok.anchor.timestamp late)

theorem chain_pairs_valid {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    ∀ x ∈ pairs p bs, Valid r x.1 x.2 := pair_valid ok

theorem headerAt_cut (p : Header) (bs : List Block) (n : Nat) (bound : n ≤ bs.length) :
    (headerAt p bs n).cut = (cuts p bs).getD n default := (cuts_getD p bs n bound).symm

/-- Zero-or-one arithmetic gives exact FIFO order over actual accepted block pairs. -/
theorem chain_consumed_indices {r : GenerationPolicy} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    (consumingPairs p bs).map (fun x => x.1.cursor) =
      List.range' p.cursor ((terminal p bs).cursor-p.cursor) := by
  induction bs generalizing p with
  | nil => simp [consumingPairs,pairs,terminal]
  | cons b rest ih =>
    have step := Forced.step_one_or_zero ok.1.forced
    have tail := ih ok.2
    have bound := (chain_cursor_bounds ok.2).1
    rcases step with same | next
    · have no : ¬b.header.cursor = p.cursor+1 := by omega
      simp only [consumingPairs,pairs,List.filter_cons,decide_eq_true_eq,ite_eq_right no] at ⊢
      change (consumingPairs b.header rest).map (fun x => x.1.cursor) = _
      rw [tail,same]
      rfl
    · simp only [consumingPairs,pairs,List.filter_cons,decide_eq_true_eq,ite_eq_left next,List.map_cons] at ⊢
      change p.cursor :: (consumingPairs b.header rest).map (fun x => x.1.cursor) = _
      rw [tail]
      have distance : (terminal b.header rest).cursor-p.cursor =
          ((terminal b.header rest).cursor-b.header.cursor)+1 := by omega
      simp only [terminal,distance,List.range'_succ,next]

/-- The exact FIFO walk is attached to its primitive-bound bytes and direct validity. -/
theorem consuming_pair_action {r : GenerationPolicy} {p : Header} {bs : List Block}
    (ok : Chain r p bs) {x : Header × Block} (mem : x ∈ consumingPairs p bs) :
    Valid r x.1 x.2 ∧ x.2.header.cursor = x.1.cursor+1 ∧
    ∃ w, x.2.body.forced = some w ∧ w.index = x.1.cursor ∧
      ActualQueue.ByteAction (definition r x.2).bytes x.1 x.2.body w.stored x.2.raw x.2.first := by
  obtain ⟨member,advanced⟩ := List.mem_filter.mp mem
  have valid := pair_valid ok x member
  have next := of_decide_eq_true advanced
  exact ⟨valid,next,valid_advance_action valid next⟩

end Etna.Design.Current.Blocks
