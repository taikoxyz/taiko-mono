import EtnaModel.Landing
import EtnaProofs.Common

namespace Etna.Design

theorem land_success {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) : LandingAllowed s i w e ∧ t = applyLanding s i := by
  simp only [land] at ok
  split at ok
  · rename_i h
    exact ⟨h, (Option.some.inj ok).symm⟩
  · contradiction

/-- Landings start and end on grid points, so every checkpoint height is one. -/
theorem land_on_grid {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) :
    i.parentHeight % s.gridK = 0 ∧ i.lastHeight % s.gridK = 0 ∧ t.checkpoint.height % s.gridK = 0 ∧
    t.gridK = s.gridK := by
  obtain ⟨h, rfl⟩ := land_success ok
  exact ⟨h.1.1.2.2.2.2.2.1,h.1.1.2.2.2.2.2.2.1,h.1.1.2.2.2.2.2.2.1,rfl⟩

theorem off_grid_rejected (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (off : i.parentHeight % s.gridK ≠ 0 ∨ i.lastHeight % s.gridK ≠ 0) : land s i w e = none := by
  apply ite_eq_right
  intro h
  rcases off with a | b
  · exact a h.1.1.2.2.2.2.2.1
  · exact b h.1.1.2.2.2.2.2.2.1

theorem wrong_leaf_count_rejected (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (count : w.length ≠ gridCount s.gridK i.parentHeight i.lastHeight) : land s i w e = none := by
  apply ite_eq_right
  intro h
  exact count h.1.2.1

theorem settled_target_rejected (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (done : i.lastHeight ≤ s.checkpoint.height) : land s i w e = none := by
  apply ite_eq_right
  intro h
  have := h.1.1.2.2.2.1
  omega

theorem land_extends_checkpoint {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) :
    s.checkpoint.height < t.checkpoint.height ∧ t.checkpoint.parent = s.checkpoint.height ∧
    t.checkpoint.generation = s.generation ∧ t.records = t.checkpoint :: s.records ∧
    t.signals = s.signals ++ [⟨t.checkpoint.height,t.checkpoint.elHash,i.lastStateRoot⟩] := by
  obtain ⟨h, rfl⟩ := land_success ok
  exact ⟨h.1.1.2.2.2.1,rfl,rfl,rfl,rfl⟩

theorem land_fi_bound {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) :
    s.head ≤ t.head ∧ t.head ≤ s.tail ∧ t.head-s.head ≤ t.checkpoint.height-s.checkpoint.height := by
  obtain ⟨h, rfl⟩ := land_success ok
  rcases h.1.1 with ⟨_,_,_,_,_,_,_,_,_,_,a,b,c,_⟩
  exact ⟨a,b,c⟩

/-- `land` is nonpayable and moves no ETH: balance and fee ghosts are framed. -/
theorem land_fee_frame {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) :
    t.ethBalance = s.ethBalance ∧ t.feeAdmissions = s.feeAdmissions ∧
    t.forcedETH = s.forcedETH ∧ t.swept = s.swept ∧
    t.origins = s.origins ∧ t.origin = s.origin ∧ t.generation = s.generation := by
  obtain ⟨_, rfl⟩ := land_success ok
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Slot 284 holds the proven snapshot of the committee that governs h. -/
theorem land_stores_proven_snapshot {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) : t.snapshot = i.activeCommitteeSnapshot := by
  obtain ⟨_, rfl⟩ := land_success ok
  rfl

/-- Chaining the derivation rules to slot 284: if `cutoffOf` gives the cutoff of the
committee governing each height and is monotone (`Committee.heightCutoff_monotone`), the
stored value tracks the committee at c, and a sound proof reports the committee at h,
then after landing the stored value tracks the committee at the new c and did not
decrease (c < h). This is 4.1's "`activeCommitteeSnapshot` never decreases" (spec L152) under sound
proofs, with no on-chain max. -/
theorem stored_snapshot_tracks_cutoff {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    {cutoffOf : Nat → Nat} (ok : land s i w e = some t)
    (monotone : ∀ a b, a ≤ b → cutoffOf a ≤ cutoffOf b)
    (stored : s.snapshot = cutoffOf s.checkpoint.height)
    (sound : i.activeCommitteeSnapshot = cutoffOf i.lastHeight) :
    t.snapshot = cutoffOf t.checkpoint.height ∧ s.snapshot ≤ t.snapshot := by
  have adv := (land_extends_checkpoint ok).1
  obtain ⟨_, rfl⟩ := land_success ok
  refine ⟨sound, ?_⟩
  show s.snapshot ≤ i.activeCommitteeSnapshot
  rw [stored, sound]
  exact monotone _ _ (Nat.le_of_lt adv)

/-- The proof certifies that the snapshot is at most the reference block (6.1; land itself
does not check it). Given that, the stored snapshot is below the landing's own L1 block, so a
later recovery block R always exceeds it. -/
theorem land_snapshot_below_block {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) (certified : i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber) :
    t.snapshot < e.blockNumber := by
  obtain ⟨h, rfl⟩ := land_success ok
  rcases h.1.1 with ⟨_,_,_,_,_,_,_,_,_,_,_,_,_,ref,_⟩
  show i.activeCommitteeSnapshot < e.blockNumber
  omega

theorem failed_land_rollback (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (failed : land s i w e = none) : transact s (land s i w e) = s := by simp [transact, failed]

theorem landing_certificate {s : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : LandingAllowed s i w e) :
    e.certificate = statementData s i (leavesHash s i w) e := ok.2.2

theorem certificate_generation_rejected (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (stale : e.certificate.generation ≠ s.generation) : land s i w e = none := by
  apply ite_eq_right
  intro h
  exact stale (congrArg StatementData.generation (landing_certificate h))

/-- The certificate does not name c: frontier movement leaves the statement unchanged. -/
theorem statement_frontier_independent (s t : State) (i : LandInput) (r : CutHash) (e : LandingEnv)
    (domain : s.domain = t.domain) (generation : s.generation = t.generation)
    (config : s.committeeConfig = t.committeeConfig)
    (parent : recordAt s i.parentHeight = recordAt t i.parentHeight) :
    statementData s i r e = statementData t i r e := by
  simp only [statementData,domain,generation,config,parent]

theorem gridLeaves_length (k p h : Nat) (table : List Cut) :
    (gridLeaves k p h table).length = gridCount k p h := by
  simp [gridLeaves]

theorem gridLeaves_getD (k p h : Nat) (table : List Cut) (j : Nat) (hj : j < gridCount k p h) :
    (gridLeaves k p h table).getD j default = cutLeaf (p+k*(j+1)) (table.getD (k*(j+1)) default) := by
  simp [gridLeaves, List.getD_eq_getElem?_getD, hj]

/-- For grid points p < c < h of any interval K > 0, the leaf of c sits at index (c−p)/K − 1. -/
theorem grid_frontier_index {k p c h : Nat} (kpos : 0 < k) (pg : p % k = 0) (cg : c % k = 0)
    (hg : h % k = 0) (pc : p < c) (ch : c < h) :
    (c-p)/k-1 < gridCount k p h ∧ p+k*((c-p)/k-1+1) = c ∧ k*((c-p)/k-1+1) = c-p := by
  have dc : k ∣ c-p := Nat.dvd_sub (Nat.dvd_of_mod_eq_zero cg) (Nat.dvd_of_mod_eq_zero pg)
  have dh : k ∣ h-p := Nat.dvd_sub (Nat.dvd_of_mod_eq_zero hg) (Nat.dvd_of_mod_eq_zero pg)
  have ec : k*((c-p)/k) = c-p := Nat.mul_div_cancel' dc
  have eh : k*((h-p)/k) = h-p := Nat.mul_div_cancel' dh
  have apos : 0 < (c-p)/k := Nat.div_pos (Nat.le_of_dvd (by omega) dc) kpos
  have altb : (c-p)/k < (h-p)/k := Nat.lt_of_mul_lt_mul_left (by rw [ec, eh]; omega)
  have succ : (c-p)/k-1+1 = (c-p)/k := by omega
  unfold gridCount
  refine ⟨by omega, ?_, ?_⟩
  · rw [succ, ec]; omega
  · rw [succ, ec]

/-- Any accepted leaf list is exactly the certified grid-leaf list. -/
theorem accepted_leaves_are_certified {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    {table : List Cut} (ok : land s i w e = some t) (sound : CertifiedTable s.gridK e.certificate table) :
    w = gridLeaves s.gridK i.parentHeight i.lastHeight table := by
  have cert := landing_certificate (land_success ok).1
  have committed := sound.2.1
  rw [cert] at committed
  simp only [statementData, leavesHash, tableHash, CutHash.mk.injEq] at committed
  exact committed.2.2.2

/-- The leaf at c (or, when c = p, the statement's origin) pins the certified cut at c to
`landings[c]` and the FI head: the proven chain passes through the current checkpoint, so
(c, h] extends it. Needs c on the grid (`OnGrid`, preserved by land, recover and rollback). -/
theorem accepted_frontier_on_certified_table {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    {table : List Cut} (ok : land s i w e = some t) (sound : CertifiedTable s.gridK e.certificate table)
    (kpos : 0 < s.gridK) (grid : s.checkpoint.height % s.gridK = 0) :
    table.getD (s.checkpoint.height-i.parentHeight) default =
      ⟨(currentRecord s).elHash,(currentRecord s).cometHash,s.head⟩ := by
  have allowed := (land_success ok).1
  have base := allowed.1.1
  have leavesOK := allowed.1.2
  have hHead : (currentRecord s).cursor = s.head := leavesOK.2.2
  have pc : i.parentHeight ≤ s.checkpoint.height := base.2.2.1
  have ch : s.checkpoint.height < i.lastHeight := base.2.2.2.1
  rcases Nat.lt_or_eq_of_le pc with lt | eq
  · have hLeaf := leavesOK.2.1 lt
    rw [accepted_leaves_are_certified ok sound] at hLeaf
    obtain ⟨idx, pos, off⟩ := grid_frontier_index kpos base.2.2.2.2.2.1 grid base.2.2.2.2.2.2.1 lt ch
    rw [gridLeaves_getD _ _ _ _ _ idx, pos, off] at hLeaf
    simp only [cutLeaf, Leaf.cut.injEq, true_and] at hLeaf
    rw [hLeaf, hHead]
  · have cert := landing_certificate allowed
    have hd := sound.2.2.1
    rw [cert] at hd
    simp only [statementData] at hd
    have hrec : (recordAt s i.parentHeight).getD default = currentRecord s := by
      simp only [currentRecord, eq]
    rw [hrec, hHead] at hd
    rw [← eq, Nat.sub_self]
    cases table with
    | nil => simp at hd
    | cons x xs =>
      simp only [List.head?_cons, Option.some.injEq] at hd
      simp [hd]

/-- No window choice (6.1 step 3): the honest grid-leaf list passes the leaf checks at every
grid frontier c in [p, h) whose record lies on the certified chain.
`honest_fi_advance_at_any_frontier` covers the other c-dependent check (step 4). -/
theorem honest_leaves_pass_any_grid_frontier (s : State) (i : LandInput) (table : List Cut)
    (kpos : 0 < s.gridK) (pg : i.parentHeight % s.gridK = 0) (hg : i.lastHeight % s.gridK = 0)
    (cg : s.checkpoint.height % s.gridK = 0) (ch : s.checkpoint.height < i.lastHeight)
    (onChain : table.getD (s.checkpoint.height-i.parentHeight) default =
      ⟨(currentRecord s).elHash,(currentRecord s).cometHash,(currentRecord s).cursor⟩)
    (head : (currentRecord s).cursor = s.head) :
    LeavesOK s i (gridLeaves s.gridK i.parentHeight i.lastHeight table) := by
  refine ⟨gridLeaves_length _ _ _ _, ?_, head⟩
  intro lt
  obtain ⟨idx, pos, off⟩ := grid_frontier_index kpos pg cg hg lt ch
  rw [gridLeaves_getD _ _ _ _ _ idx, pos, off, onChain]

theorem cursorSteps_bound : ∀ (t : List Cut), cursorSteps t = true → ∀ i j, i ≤ j → j < t.length →
    (t.getD i default).cursor ≤ (t.getD j default).cursor ∧
    (t.getD j default).cursor ≤ (t.getD i default).cursor+(j-i)
  | [], _, _, _, _, hj => by simp at hj
  | [a], _, i, j, hij, hj => by
    simp at hj
    have : i = 0 := by omega
    subst this; subst hj
    simp
  | a :: b :: rest, steps, i, j, hij, hj => by
    simp only [cursorSteps, Bool.and_eq_true, decide_eq_true_eq] at steps
    have ih := cursorSteps_bound (b :: rest) steps.2
    cases i with
    | zero =>
      cases j with
      | zero => simp
      | succ j =>
        have h := ih 0 j (Nat.zero_le _) (by simp at hj ⊢; omega)
        simp only [List.getD_cons_succ, List.getD_cons_zero] at h ⊢
        omega
    | succ i =>
      cases j with
      | zero => omega
      | succ j =>
        have h := ih i j (by omega) (by simp at hj ⊢; omega)
        simp only [List.getD_cons_succ] at h ⊢
        omega

theorem getD_last (t : List Cut) (x : Cut) (last : t.getLast? = some x) :
    t.getD (t.length-1) default = x := by
  rw [List.getLast?_eq_getElem?] at last
  simp [List.getD_eq_getElem?_getD, last]

/-- 6.1 step 4 against any frontier: under a sound certificate, from the cut at any c in
[p, h] the proven FI head is reachable within h − c steps, so after a competing landing moves
c (and the FI head to the cut at c) the honest transaction's FI check still passes. -/
theorem honest_fi_advance_at_any_frontier {k : Nat} {d : StatementData} {table : List Cut}
    (sound : CertifiedTable k d table) (c : Nat) (pc : d.input.parentHeight ≤ c) (ch : c ≤ d.input.lastHeight) :
    (table.getD (c-d.input.parentHeight) default).cursor ≤ d.input.forcedInclusionHead ∧
    d.input.forcedInclusionHead-(table.getD (c-d.input.parentHeight) default).cursor ≤ d.input.lastHeight-c := by
  have len := sound.1
  have last := getD_last table _ sound.2.2.2.1
  have b := cursorSteps_bound table sound.2.2.2.2.1 (c-d.input.parentHeight) (table.length-1)
    (by omega) (by omega)
  rw [last] at b
  simp only at b
  omega

/-- An Inbox/guest K mismatch fails closed: any accepted landing whose certificate is sound for a
guest interval k forces k = the Inbox's K (the leaf counts (h−p)/k − 1 and (h−p)/K − 1 agree and
k, K both divide h − p). -/
theorem accepted_landing_fixes_guest_k {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    {k : Nat} {table : List Cut} (ok : land s i w e = some t) (sound : CertifiedTable k e.certificate table)
    (kpos : 0 < k) (Kpos : 0 < s.gridK) : k = s.gridK := by
  have allowed := (land_success ok).1
  have base := allowed.1.1
  have count : w.length = gridCount s.gridK i.parentHeight i.lastHeight := allowed.1.2.1
  have cert := landing_certificate allowed
  have input : e.certificate.input = i := by rw [cert]; rfl
  have committed := sound.2.1
  rw [cert] at committed
  simp only [statementData, leavesHash, tableHash, CutHash.mk.injEq] at committed
  have hw : w = gridLeaves k i.parentHeight i.lastHeight table := committed.2.2.2
  have pk : i.parentHeight % k = 0 := by have := sound.2.2.2.2.2.1; rwa [input] at this
  have hk : i.lastHeight % k = 0 := by have := sound.2.2.2.2.2.2; rwa [input] at this
  have pK : i.parentHeight % s.gridK = 0 := base.2.2.2.2.2.1
  have hK : i.lastHeight % s.gridK = 0 := base.2.2.2.2.2.2.1
  have ph : i.parentHeight < i.lastHeight := by have := base.2.2.1; have := base.2.2.2.1; omega
  rw [hw, gridLeaves_length] at count
  unfold gridCount at count
  have dk : k ∣ i.lastHeight-i.parentHeight := Nat.dvd_sub (Nat.dvd_of_mod_eq_zero hk) (Nat.dvd_of_mod_eq_zero pk)
  have dK : s.gridK ∣ i.lastHeight-i.parentHeight :=
    Nat.dvd_sub (Nat.dvd_of_mod_eq_zero hK) (Nat.dvd_of_mod_eq_zero pK)
  have ak : 0 < (i.lastHeight-i.parentHeight)/k := Nat.div_pos (Nat.le_of_dvd (by omega) dk) kpos
  have aK : 0 < (i.lastHeight-i.parentHeight)/s.gridK := Nat.div_pos (Nat.le_of_dvd (by omega) dK) Kpos
  have same : (i.lastHeight-i.parentHeight)/k = (i.lastHeight-i.parentHeight)/s.gridK := by omega
  have ek := Nat.mul_div_cancel' dk
  have eK := Nat.mul_div_cancel' dK
  rw [same] at ek
  exact Nat.eq_of_mul_eq_mul_right aK (by rw [ek, eK])

theorem land_preserves_grid {s t : State} {i : LandInput} {w : List Leaf} {e : LandingEnv}
    (ok : land s i w e = some t) (grid : OnGrid s) : OnGrid t := by
  have g := land_on_grid ok
  obtain ⟨_, rfl⟩ := land_success ok
  refine ⟨g.2.2.1, ?_⟩
  intro r mem
  simp only [applyLanding, List.mem_cons] at mem
  rcases mem with rfl | old
  · exact g.2.1
  · exact grid.2 r old

/-- §10/§11 maxBatchBlocks ≥ K: below one grid segment no landing is possible at all. The
limit is the Inbox's own immutable; no landing input carries it. -/
theorem batch_limit_below_grid_blocks_landing (s : State) (i : LandInput) (w : List Leaf) (e : LandingEnv)
    (small : s.maxBatchBlocks < s.gridK) : land s i w e = none := by
  apply ite_eq_right
  intro h
  have b := h.1.1
  have pc : i.parentHeight ≤ s.checkpoint.height := b.2.2.1
  have ch : s.checkpoint.height < i.lastHeight := b.2.2.2.1
  have pg : i.parentHeight % s.gridK = 0 := b.2.2.2.2.2.1
  have hg : i.lastHeight % s.gridK = 0 := b.2.2.2.2.2.2.1
  have batch : i.lastHeight-i.parentHeight ≤ s.maxBatchBlocks := b.2.2.2.2.2.2.2.1
  have dh : s.gridK ∣ i.lastHeight-i.parentHeight :=
    Nat.dvd_sub (Nat.dvd_of_mod_eq_zero hg) (Nat.dvd_of_mod_eq_zero pg)
  have := Nat.le_of_dvd (by omega) dh
  omega

end Etna.Design
