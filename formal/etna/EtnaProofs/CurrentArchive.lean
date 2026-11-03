import EtnaModel.CurrentArchive
import EtnaProofs.CurrentFinality

namespace Etna.Design.Current.Archive

/-- A full archive splits at its real physical terminal, including an empty prefix. -/
theorem linked_append (parentOf : Hash → Hash) (root : Header) (as bs : List Header) :
    Linked parentOf root (as ++ bs) ↔ Linked parentOf root as ∧ Linked parentOf (terminal root as) bs := by
  induction as generalizing root with
  | nil => simp [Linked,terminal]
  | cons a rest ih => simp only [List.cons_append,Linked,terminal,ih,and_assoc]

theorem linked_terminal_height {parentOf : Hash → Hash} {root : Header} {headers : List Header}
    (linked : Linked parentOf root headers) : (terminal root headers).height = root.height+headers.length := by
  induction headers generalizing root with
  | nil => simp [terminal]
  | cons h rest ih =>
    have tail := ih linked.2.2
    have first := linked.1
    simp only [terminal,List.length_cons]
    omega

theorem terminal_append (root : Header) (as bs : List Header) :
    terminal root (as ++ bs) = terminal (terminal root as) bs := by
  induction as generalizing root with
  | nil => rfl
  | cons a rest ih => exact ih a

theorem terminal_block_headers (p : Header) (bs : List Block) :
    terminal p (bs.map Blocks.Block.header) = Blocks.terminal p bs := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih => exact ih b.header

/-- A fixed physical decoder determines every ancestor hash backwards from the
terminal hash. No injectivity or complete-header equality is assumed here. -/
theorem ancestor_hashes {parentOf : Hash → Hash} {rootA rootB : Header} {as bs : List Header}
    (linkedA : Linked parentOf rootA as) (linkedB : Linked parentOf rootB bs)
    (lengths : as.length = bs.length)
    (last : (terminal rootA as).elHash = (terminal rootB bs).elHash) :
    (rootA :: as).map (fun h => h.elHash) = (rootB :: bs).map (fun h => h.elHash) := by
  induction as generalizing rootA rootB bs with
  | nil =>
    have empty : bs = [] := List.length_eq_zero_iff.mp lengths.symm
    subst bs
    simpa [terminal] using congrArg (fun hash : Hash => [hash]) last
  | cons a rest ih =>
    cases bs with
    | nil => simp at lengths
    | cons b more =>
      have tailLengths : rest.length = more.length := by simpa using lengths
      have tailHashes := ih linkedA.2.2 linkedB.2.2 tailLengths last
      have heads : a.elHash = b.elHash := (List.cons.inj tailHashes).1
      have roots : rootA.elHash = rootB.elHash :=
        linkedA.2.1.symm.trans ((congrArg parentOf heads).trans linkedB.2.1)
      simp only [List.map_cons]
      rw [roots]
      exact congrArg (List.cons rootB.elHash) tailHashes

/-- The physical hash refinement binds the archived anchor fields too. -/
theorem anchor_numbers_of_hashes {hash : Header → Hash} {as bs : List Header}
    (separation : ∀ a b, hash a = a.elHash → hash b = b.elHash → a.elHash = b.elHash →
      a.anchor.number = b.anchor.number)
    (boundA : ∀ h ∈ as, hash h = h.elHash) (boundB : ∀ h ∈ bs, hash h = h.elHash)
    (same : as.map (fun h => h.elHash) = bs.map (fun h => h.elHash)) :
    as.map (fun h => h.anchor.number) = bs.map (fun h => h.anchor.number) := by
  induction as generalizing bs with
  | nil =>
    cases bs with
    | nil => rfl
    | cons b rest => simp at same
  | cons a rest ih =>
    cases bs with
    | nil => simp at same
    | cons b more =>
      obtain ⟨heads,tails⟩ := List.cons.inj same
      have anchors := separation a b (boundA a List.mem_cons_self) (boundB b List.mem_cons_self) heads
      simp only [List.map_cons,anchors]
      exact congrArg (List.cons b.anchor.number) (ih
        (fun h mem => boundA h (List.mem_cons_of_mem _ mem))
        (fun h mem => boundB h (List.mem_cons_of_mem _ mem)) tails)

theorem anchorAt_eq_of_anchor_numbers {cfg : Finality.Config} {as bs : List Header}
    (same : as.map (fun h => h.anchor.number) = bs.map (fun h => h.anchor.number)) (height : Nat) :
    Finality.anchorAt cfg as height = Finality.anchorAt cfg bs height := by
  unfold Finality.anchorAt
  split
  · rfl
  · have atHeight := congrArg (fun ns : List Nat => ns[height-cfg.originHeight-1]?) same
    simpa only [List.getElem?_map] using congrArg (fun n : Option Nat => n.getD cfg.originBlock) atHeight

/-- A real checkpoint's EL hash determines the decision anchors in every authenticated
ancestry reaching it. Only raw parent/hash refinements are premises. -/
theorem cutoff_agrees_at_ancestor {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {rootA rootB : Header} {as bs : List Header}
    (separation : ∀ a b, hash a = a.elHash → hash b = b.elHash → a.elHash = b.elHash →
      a.anchor.number = b.anchor.number)
    (linkedA : Linked parentOf rootA as) (linkedB : Linked parentOf rootB bs)
    (boundA : ∀ h ∈ rootA :: as, hash h = h.elHash)
    (boundB : ∀ h ∈ rootB :: bs, hash h = h.elHash)
    (lengths : as.length = bs.length)
    (last : (terminal rootA as).elHash = (terminal rootB bs).elHash) (height : Nat) :
    Finality.cutoff cfg as height = Finality.cutoff cfg bs height := by
  have hashes := ancestor_hashes linkedA linkedB lengths last
  have anchors := (List.cons.inj (anchor_numbers_of_hashes separation boundA boundB hashes)).2
  unfold Finality.cutoff
  rw [anchorAt_eq_of_anchor_numbers anchors]

theorem actual_linked {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs) :
    Linked parentOf p (bs.map Blocks.Block.header) := by
  obtain ⟨root,prior,_,_,_,shape,last,linked,_⟩ := auth
  rw [shape] at linked
  simpa [last] using ((linked_append parentOf root prior _).mp linked).2

theorem authenticated_origin {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs) :
    ∃ root, root.height = cfg.originHeight ∧ root.cut = origin ∧ hash root = root.elHash := by
  obtain ⟨root,_,height,cut,bound,_⟩ := auth
  exact ⟨root,height,cut,bound⟩

theorem actual_member {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (b : Block) (member : b ∈ bs) : b.header ∈ archive := by
  obtain ⟨_,prior,_,_,_,shape,_⟩ := auth
  rw [shape]
  exact List.mem_append_right prior (List.mem_map.mpr ⟨b,member,rfl⟩)

theorem actual_hash_bound {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (b : Block) (member : b ∈ bs) : hash b.header = b.header.elHash := by
  have present := actual_member auth b member
  obtain ⟨_,_,_,_,_,_,_,_,bound,_⟩ := auth
  exact bound b.header present

theorem archived_hash_bound {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (h : Header) (member : h ∈ archive) : hash h = h.elHash := by
  obtain ⟨_,_,_,_,_,_,_,_,bound,_⟩ := auth
  exact bound h member

theorem actual_body_parent {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (b : Block) (member : b ∈ bs) : parentOf b.header.elHash = b.body.parentHash := by
  obtain ⟨_,_,_,_,_,_,_,_,_,parents,_⟩ := auth
  exact parents b member

theorem archived_anchor_bounded {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (h : Header) (member : h ∈ archive) : h.anchor.number ≤ reference := by
  obtain ⟨_,_,_,_,_,_,_,_,_,_,_,bound⟩ := auth
  exact bound h member

/-- Every total lookback result is within the closed reference, including the
pre-origin floor and unavailable indices (completeness is separately required by Ready). -/
theorem anchor_bounded {cfg : Finality.Config} {archive : List Header} {reference : Nat}
    (origin : cfg.originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference) (height : Nat) :
    Finality.anchorAt cfg archive height ≤ reference := by
  unfold Finality.anchorAt
  split
  · exact origin
  · cases found : archive[height-cfg.originHeight-1]? with
    | none => simpa [found] using origin
    | some h => simpa [found] using bounds h (List.mem_of_getElem? found)

/-- Actual ordered archive positions give monotone lookback anchors. Coverage is
needed only through the later queried position; no future archive is assumed. -/
theorem anchor_monotone {cfg : Finality.Config} {archive : List Header}
    (floor : ∀ h ∈ archive, cfg.originBlock ≤ h.anchor.number)
    (ordered : (archive.map (fun h => h.anchor.number)).Pairwise (· ≤ ·))
    {a b : Nat} (order : a ≤ b) (covered : b-cfg.originHeight ≤ archive.length) :
    Finality.anchorAt cfg archive a ≤ Finality.anchorAt cfg archive b := by
  by_cases earlyB : b ≤ cfg.originHeight
  · have earlyA : a ≤ cfg.originHeight := Nat.le_trans order earlyB
    simp [Finality.anchorAt,earlyA,earlyB]
  · have ib : b-cfg.originHeight-1 < archive.length := by omega
    by_cases earlyA : a ≤ cfg.originHeight
    · simpa [Finality.anchorAt,earlyA,earlyB,List.getElem?_eq_getElem ib] using
        floor archive[b-cfg.originHeight-1] (List.getElem_mem ib)
    · have ia : a-cfg.originHeight-1 < archive.length := by omega
      simp only [Finality.anchorAt,earlyA,earlyB,ite_false,List.getElem?_eq_getElem ia,
        List.getElem?_eq_getElem ib,Option.map_some,Option.getD_some]
      rcases Nat.eq_or_lt_of_le order with same | lt
      · subst b; exact Nat.le_refl _
      · have indices : a-cfg.originHeight-1 < b-cfg.originHeight-1 := by omega
        have imapA : a-cfg.originHeight-1 < (archive.map (fun h => h.anchor.number)).length := by simpa using ia
        have imapB : b-cfg.originHeight-1 < (archive.map (fun h => h.anchor.number)).length := by simpa using ib
        simpa using ordered.rel_getElem_of_lt imapA imapB indices

/-- Selection snapshots do not decrease as heights advance within one authenticated
generation. This derives the ordering from archive positions and activation arithmetic. -/
theorem cutoff_monotone {cfg : Finality.Config} {registry : RegistryMachine.State}
    {archive : List Header} {a b : Nat} (order : a ≤ b)
    (ready : Finality.Ready cfg registry archive b) :
    Finality.cutoff cfg archive a ≤ Finality.cutoff cfg archive b := by
  have epochs : Finality.epoch cfg a*cfg.epochLen ≤ Finality.epoch cfg b*cfg.epochLen :=
    Nat.mul_le_mul_right cfg.epochLen (Nat.div_le_div_right (Nat.sub_le_sub_right order 1))
  by_cases normalB : cfg.originHeight < Finality.epoch cfg b*cfg.epochLen-1
  · by_cases normalA : cfg.originHeight < Finality.epoch cfg a*cfg.epochLen-1
    · have enough : Finality.decisionLookback cfg b-cfg.originHeight ≤ archive.length := by
        simpa [Finality.requiredPrefix,normalB] using ready.2.2.2.2.2.2.1
      have lookback : Finality.decisionLookback cfg a ≤ Finality.decisionLookback cfg b :=
        Nat.sub_le_sub_right epochs 2
      have anchors := anchor_monotone (cfg := cfg) (fun h mem => (ready.2.2.2.1 h mem).2)
        ready.2.2.2.2.1 lookback enough
      simp only [Finality.cutoff,normalA,normalB,ite_true]
      exact Nat.max_le.mpr ⟨Nat.le_trans anchors (Nat.le_max_left _ _),Nat.le_max_right _ _⟩
    · have initial : Finality.initialCutoff cfg ≤ cfg.originBlock := by
        unfold Finality.initialCutoff
        split
        · exact ready.2.1
        · exact Nat.le_refl _
      simp only [Finality.cutoff,normalA,normalB,ite_true,ite_false]
      exact Nat.le_trans initial (Nat.le_max_right _ _)
  · have normalA : ¬ cfg.originHeight < Finality.epoch cfg a*cfg.epochLen-1 := by omega
    simp [Finality.cutoff,normalA,normalB]

theorem active_cutoff_monotone {cfg : Finality.Config} {registry : RegistryMachine.State}
    {archive : List Header} {a b : Nat} (order : a ≤ b)
    (ready : Finality.Ready cfg registry archive b) :
    (Consensus.activeAt (Finality.derive cfg registry archive) a).cutoff ≤
      (Consensus.activeAt (Finality.derive cfg registry archive) b).cutoff := by
  rw [Finality.active_cutoff,Finality.active_cutoff]
  exact cutoff_monotone order ready

/-- Every derived cutoff uses only the origin floor or a bounded archived anchor. -/
theorem active_cutoff_at_bounded {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block} {registry : RegistryMachine.State}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (genesis : cfg.genesisCutoff ≤ cfg.originBlock) (height : Nat) :
    (Consensus.activeAt (Finality.derive cfg registry archive) height).cutoff ≤ reference := by
  obtain ⟨_,_,_,_,_,_,_,_,_,_,before,bounds⟩ := auth
  rw [Finality.active_cutoff]
  unfold Finality.cutoff Finality.initialCutoff
  split
  · exact Nat.max_le.mpr ⟨anchor_bounded before bounds _,before⟩
  · split
    · exact Nat.le_trans genesis before
    · exact before

/-- The public activeCommitteeSnapshot bound follows from concrete authenticated
ancestry and the derived activation schedule; it is never a certificate premise. -/
theorem active_cutoff_bounded {hash : Header → Hash} {parentOf : Hash → Hash}
    {cfg : Finality.Config} {origin : Cut} {reference : Nat}
    {archive : List Header} {p : Header} {bs : List Block} {registry : RegistryMachine.State}
    (auth : Authenticated hash parentOf cfg origin reference archive p bs)
    (ready : Finality.Ready cfg registry archive (Blocks.terminal p bs).height) :
    (Consensus.activeAt (Finality.derive cfg registry archive) (Blocks.terminal p bs).height).cutoff ≤ reference :=
  active_cutoff_at_bounded auth ready.2.1 _

end Etna.Design.Current.Archive
