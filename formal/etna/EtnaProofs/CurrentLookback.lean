import EtnaProofs.CurrentArchive

/-! Bounded extraction from the full ordinary EL ancestry. The input remains a
complete linked prefix from the generation origin. This does not implement or refine
the guest certificate relation using only the extracted suffix. -/
namespace Etna.Design.Current.Archive

private theorem decision_before_parent (cfg : Finality.Config) (p : Header) :
    Finality.decisionLookback cfg (p.height+1) ≤ p.height := by
  have bound := Finality.decision_lookback_before cfg (p.height+1)
  omega

/-- Every position of a complete physical ancestry has its consecutive EL height. -/
theorem linked_heights {parentOf : Hash → Hash} {root : Header} {prior : List Header}
    (linked : Linked parentOf root prior) :
    (root :: prior).map BlockValidity.Header.height = List.range' root.height (prior.length+1) := by
  induction prior generalizing root with
  | nil => rfl
  | cons h rest ih =>
    have tail := ih linked.2.2
    change root.height :: (h :: rest).map BlockValidity.Header.height = _
    rw [tail,linked.1]
    rfl

/-- The suffix contains exactly the consecutive interval max(origin,D) through p. -/
theorem decisionWindow_heights {cfg : Finality.Config} {parentOf : Hash → Hash}
    {root p : Header} {prior : List Header} (linked : Linked parentOf root prior)
    (last : terminal root prior = p) :
    (decisionWindow cfg root prior p).map BlockValidity.Header.height =
      List.range' (max root.height (Finality.decisionLookback cfg (p.height+1)))
        (p.height+1-max root.height (Finality.decisionLookback cfg (p.height+1))) := by
  have heights := linked_terminal_height linked
  rw [last] at heights
  unfold decisionWindow
  rw [List.map_drop,linked_heights linked,List.drop_range']
  have first : root.height+(Finality.decisionLookback cfg (p.height+1)-root.height)*1 =
      max root.height (Finality.decisionLookback cfg (p.height+1)) := by omega
  have count : prior.length+1-(Finality.decisionLookback cfg (p.height+1)-root.height) =
      p.height+1-max root.height (Finality.decisionLookback cfg (p.height+1)) := by omega
  rw [first,count]

/-- The L+2 bound counts D itself as well as every later historical header through p.
It follows from quotient/remainder arithmetic, not an archive-size assumption. -/
theorem decisionWindow_length_le {cfg : Finality.Config} {parentOf : Hash → Hash}
    {root p : Header} {prior : List Header} (positive : 0 < cfg.epochLen)
    (linked : Linked parentOf root prior) (last : terminal root prior = p) :
    (decisionWindow cfg root prior p).length ≤ cfg.epochLen+2 := by
  have heights := linked_terminal_height linked
  rw [last] at heights
  have remainder := Nat.mod_lt p.height positive
  have decomposition : p.height % cfg.epochLen + p.height/cfg.epochLen*cfg.epochLen = p.height := by
    simpa only [Nat.mul_comm] using Nat.mod_add_div p.height cfg.epochLen
  simp only [decisionWindow,List.length_drop,List.length_cons,Finality.decisionLookback,
    Finality.epoch,Nat.add_sub_cancel]
  omega

/-- The extraction never loses every header: D cannot lie above the batch parent. -/
theorem decisionWindow_head_height {cfg : Finality.Config} {parentOf : Hash → Hash}
    {root p : Header} {prior : List Header} (linked : Linked parentOf root prior)
    (last : terminal root prior = p) :
    (decisionWindow cfg root prior p).head?.map BlockValidity.Header.height =
      some (max root.height (Finality.decisionLookback cfg (p.height+1))) := by
  have heights := linked_terminal_height linked
  rw [last] at heights
  have before := decision_before_parent cfg p
  have nonempty : p.height+1-max root.height (Finality.decisionLookback cfg (p.height+1)) ≠ 0 := by
    omega
  have head := congrArg List.head? (decisionWindow_heights (cfg := cfg) linked last)
  simpa only [List.head?_map,List.head?_range',nonempty,ite_false] using head

private theorem linked_drop {parentOf : Hash → Hash} {root : Header} {prior : List Header}
    (linked : Linked parentOf root prior) (n : Nat) {first : Header} {rest : List Header}
    (shape : (root :: prior).drop n = first :: rest) :
    Linked parentOf first rest ∧ terminal first rest = terminal root prior := by
  induction n generalizing root prior with
  | zero =>
    obtain ⟨rfl,rfl⟩ := List.cons.inj shape
    exact ⟨linked,rfl⟩
  | succ n ih =>
    cases prior with
    | nil => simp at shape
    | cons h later =>
      have reduced : (h :: later).drop n = first :: rest := by
        simpa only [List.drop_succ_cons] using shape
      exact ih (root := h) (prior := later) linked.2.2 reduced

/-- All retained physical parent edges and the exact terminal survive extraction. -/
theorem decisionWindow_ancestry {cfg : Finality.Config} {parentOf : Hash → Hash}
    {root p first : Header} {prior rest : List Header} (linked : Linked parentOf root prior)
    (last : terminal root prior = p) (shape : decisionWindow cfg root prior p = first :: rest) :
    Linked parentOf first rest ∧ terminal first rest = p := by
  obtain ⟨ancestry,ends⟩ := linked_drop linked _ shape
  exact ⟨ancestry,ends.trans last⟩

/-- Extraction preserves each original header's hash authentication. It introduces no
new authentication assumption and cannot authenticate a supplied suffix on its own. -/
theorem decisionWindow_hash_bound {cfg : Finality.Config} {hash : Header → Hash}
    {root p : Header} {prior : List Header}
    (bound : ∀ h ∈ root :: prior, hash h = h.elHash) :
    ∀ h ∈ decisionWindow cfg root prior p, hash h = h.elHash := by
  intro h member
  exact bound h (List.mem_of_mem_drop member)

/-- For D above the origin the retained head is exactly the full archive's D header;
the subtraction by one reflects that `prior` starts at origin+1. -/
theorem decisionWindow_head_eq_decision {cfg : Finality.Config} {root p : Header} {prior : List Header}
    (origin : root.height = cfg.originHeight)
    (after : cfg.originHeight < Finality.decisionLookback cfg (p.height+1)) :
    (decisionWindow cfg root prior p).head? =
      prior[Finality.decisionLookback cfg (p.height+1)-cfg.originHeight-1]? := by
  unfold decisionWindow
  rw [List.head?_drop]
  have offset : Finality.decisionLookback cfg (p.height+1)-root.height =
      (Finality.decisionLookback cfg (p.height+1)-cfg.originHeight-1)+1 := by omega
  rw [offset,List.getElem?_cons_succ]

/-- A post-origin decision is present, with its exact height and original archive
position. Completeness comes from the full linked prefix ending at p. -/
theorem decisionWindow_decision_header {cfg : Finality.Config} {parentOf : Hash → Hash}
    {root p : Header} {prior : List Header} (linked : Linked parentOf root prior)
    (last : terminal root prior = p) (origin : root.height = cfg.originHeight)
    (after : cfg.originHeight < Finality.decisionLookback cfg (p.height+1)) :
    ∃ h, (decisionWindow cfg root prior p).head? = some h ∧
      prior[Finality.decisionLookback cfg (p.height+1)-cfg.originHeight-1]? = some h ∧
      h.height = Finality.decisionLookback cfg (p.height+1) := by
  have head := decisionWindow_head_height (cfg := cfg) linked last
  rw [origin,Nat.max_eq_right (Nat.le_of_lt after)] at head
  cases found : (decisionWindow cfg root prior p).head? with
  | none => simp [found] at head
  | some h =>
    have height : h.height = Finality.decisionLookback cfg (p.height+1) := by
      simpa only [found,Option.map_some,Option.some.injEq] using head
    exact ⟨h,rfl,(decisionWindow_head_eq_decision origin after).symm.trans found,height⟩

/-- The full ordinary archive and its bounded window project the same decision anchor
when D is post-origin. This is an exact decoded lookup, not guest-byte refinement. -/
theorem decisionWindow_anchor_eq {cfg : Finality.Config} {root p : Header} {prior : List Header}
    (origin : root.height = cfg.originHeight)
    (after : cfg.originHeight < Finality.decisionLookback cfg (p.height+1)) :
    Finality.anchorAt cfg prior (Finality.decisionLookback cfg (p.height+1)) =
      ((decisionWindow cfg root prior p).head?.map (fun h => h.anchor.number)).getD cfg.originBlock := by
  rw [decisionWindow_head_eq_decision origin after]
  simp only [Finality.anchorAt,Nat.not_le.mpr after,ite_false]

/-- The same extracted anchor gives the ordinary decision's exact cutoff, including
the origin L1 floor. This is still a consequence of the full semantic ancestry. -/
theorem decisionWindow_cutoff_eq {cfg : Finality.Config} {root p : Header} {prior : List Header}
    (origin : root.height = cfg.originHeight)
    (after : cfg.originHeight < Finality.decisionLookback cfg (p.height+1)) :
    Finality.cutoff cfg prior (p.height+1) =
      max (((decisionWindow cfg root prior p).head?.map (fun h => h.anchor.number)).getD cfg.originBlock)
        cfg.originBlock := by
  have normal : cfg.originHeight < Finality.epoch cfg (p.height+1)*cfg.epochLen-1 := by
    unfold Finality.decisionLookback at after
    omega
  simp only [Finality.cutoff,normal,ite_true]
  rw [decisionWindow_anchor_eq origin after]

/-- At or below the origin the anchor is the origin L1 floor. The origin header's
own anchor is deliberately not substituted for this value. -/
theorem decisionWindow_origin_floor {cfg : Finality.Config} {root p : Header} {prior : List Header}
    (origin : root.height = cfg.originHeight)
    (early : Finality.decisionLookback cfg (p.height+1) ≤ cfg.originHeight) :
    decisionWindow cfg root prior p = root :: prior ∧
      Finality.anchorAt cfg prior (Finality.decisionLookback cfg (p.height+1)) = cfg.originBlock := by
  have offset : Finality.decisionLookback cfg (p.height+1)-root.height = 0 := by omega
  simp only [decisionWindow,offset,List.drop_zero,Finality.anchorAt,early,ite_true,and_self]

end Etna.Design.Current.Archive
