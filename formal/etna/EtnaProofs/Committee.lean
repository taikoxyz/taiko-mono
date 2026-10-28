import EtnaModel.Committee
import EtnaProofs.Common

namespace Etna.Design.Committee

theorem election_chosen {unit minimum cutoff nMax : Nat} {entries members : List Entry}
    (ok : election unit minimum cutoff nMax entries = some members) :
    members = chosen unit minimum cutoff nMax entries := by
  unfold election at ok
  dsimp only at ok
  split at ok
  · exact (Option.some.inj ok).symm
  · contradiction

theorem chosen_eligible (unit minimum cutoff nMax : Nat) (entries : List Entry) (e : Entry)
    (selected : e ∈ chosen unit minimum cutoff nMax entries) :
    e ∈ entries ∧ e.activeFrom ≤ cutoff ∧ cutoff < e.exitAt ∧ max minimum unit ≤ e.stake := by
  have m := List.mem_of_mem_take (List.mem_mergeSort.mp selected)
  have f := List.mem_filter.mp (List.mem_mergeSort.mp m)
  exact ⟨f.1, by simpa [eligible] using f.2⟩

theorem exited_not_chosen (unit minimum cutoff nMax : Nat) (entries : List Entry) (e : Entry)
    (exited : e.exitAt ≤ cutoff) : e ∉ chosen unit minimum cutoff nMax entries := by
  intro h
  have := (chosen_eligible unit minimum cutoff nMax entries e h).2.2.1
  omega

theorem chosen_size (unit minimum cutoff nMax : Nat) (entries : List Entry) :
    (chosen unit minimum cutoff nMax entries).length ≤ nMax := by
  simp only [chosen,List.length_mergeSort]
  exact List.length_take_le _ _

theorem canonical_keys (unit minimum cutoff nMax : Nat) (entries : List Entry) :
    (chosen unit minimum cutoff nMax entries).Pairwise (fun a b => a.key ≤ b.key) := by
  unfold chosen
  have h := List.pairwise_mergeSort (le := fun a b : Entry => decide (a.key ≤ b.key))
    (fun a b c hab hbc => by
      have ab : a.key ≤ b.key := of_decide_eq_true hab
      have bc : b.key ≤ c.key := of_decide_eq_true hbc
      exact decide_eq_true (Nat.le_trans ab bc))
    (fun a b => by
      rcases Nat.le_total a.key b.key with h | h
      · simp [h]
      · simp [h])
    (((entries.filter (eligible unit minimum cutoff)).mergeSort rank).take nMax)
  simpa only [decide_eq_true_eq] using h

theorem ranked_by_stake_then_key (unit minimum cutoff : Nat) (entries : List Entry) :
    ((entries.filter (eligible unit minimum cutoff)).mergeSort rank).Pairwise
      (fun a b => b.stake < a.stake ∨ (a.stake = b.stake ∧ a.key ≤ b.key)) := by
  have trans : ∀ a b c, rank a b = true → rank b c = true → rank a c = true := by
    intro a b c ab bc
    have hab : b.stake < a.stake ∨ (a.stake = b.stake ∧ a.key ≤ b.key) := of_decide_eq_true ab
    have hbc : c.stake < b.stake ∨ (b.stake = c.stake ∧ b.key ≤ c.key) := of_decide_eq_true bc
    have hac : c.stake < a.stake ∨ (a.stake = c.stake ∧ a.key ≤ c.key) := by
      rcases hab with hab | ⟨hab,kab⟩
      · rcases hbc with hbc | ⟨hbc,_⟩
        · exact Or.inl (Nat.lt_trans hbc hab)
        · exact Or.inl (by simpa [← hbc] using hab)
      · rcases hbc with hbc | ⟨hbc,kbc⟩
        · exact Or.inl (by simpa [hab] using hbc)
        · exact Or.inr ⟨hab.trans hbc,Nat.le_trans kab kbc⟩
    exact decide_eq_true hac
  have total : ∀ a b, (rank a b || rank b a) = true := by
    intro a b
    rcases Nat.lt_trichotomy a.stake b.stake with h | h | h
    · simp [rank,h,Nat.ne_of_lt h]
    · rcases Nat.le_total a.key b.key with k | k <;> simp [rank,h,k]
    · simp [rank,h,Nat.ne_of_lt h]
  have h := List.pairwise_mergeSort trans total (entries.filter (eligible unit minimum cutoff))
  simpa only [rank,decide_eq_true_eq] using h

/-- 867,361,738 = ⌈10^27 / MAX⌉ exactly. -/
theorem min_unit_is_ceiling : (minUnit-1)*maxPower < supply ∧ supply ≤ minUnit*maxPower := by decide

/-- Floors never sum above the floor of the sum. -/
theorem total_power_le_div (unit : Nat) (u : 0 < unit) (entries : List Entry) :
    totalPower unit entries ≤ (entries.map Entry.stake).sum/unit := by
  induction entries with
  | nil => simp [totalPower]
  | cons e es ih =>
    simp only [totalPower, power, List.map_cons, List.sum_cons] at *
    apply (Nat.le_div_iff_mul_le u).mpr
    have a := Nat.div_mul_le_self e.stake unit
    have b := (Nat.le_div_iff_mul_le u).mp ih
    rw [Nat.add_mul]
    omega

/-- 4.3: with the fixed supply and vp_unit ≥ ⌈10^27/MAX⌉, all registered power together
stays within CometBFT's MAX, so registration can never trigger the overflow rejection. -/
theorem supply_bounds_total_power {unit : Nat} (floor : minUnit ≤ unit) (entries : List Entry)
    (locked : (entries.map Entry.stake).sum ≤ supply) : totalPower unit entries ≤ maxPower := by
  have u : 0 < unit := by unfold minUnit at floor; omega
  have h₁ := total_power_le_div unit u entries
  have h₂ : (entries.map Entry.stake).sum/unit ≤ supply/minUnit :=
    Nat.le_trans (Nat.div_le_div_right locked) (Nat.div_le_div_left floor (by decide))
  have h₃ : supply/minUnit ≤ maxPower := by decide
  omega

/-- Every anchor a generation uses is at or above its origin block and the anchors never
decrease, whatever the anchor inherited from before the origin. -/
theorem anchor_chain_from_origin {originBlock parent : Nat} {anchors : List Nat}
    (chain : anchorChain originBlock parent anchors = true) :
    (∀ a ∈ anchors, originBlock ≤ a ∧ parent ≤ a) ∧ anchors.Pairwise (· ≤ ·) := by
  induction anchors generalizing parent with
  | nil => simp
  | cons a rest ih =>
    simp only [anchorChain, Bool.and_eq_true] at chain
    obtain ⟨ok, tail⟩ := chain
    have ⟨hp, ho⟩ := of_decide_eq_true ok
    have ⟨later, sorted⟩ := ih tail
    refine ⟨?_, List.pairwise_cons.mpr ⟨fun b mem => (later b mem).2, sorted⟩⟩
    intro b mem
    rcases List.mem_cons.mp mem with rfl | rest
    · exact ⟨ho, hp⟩
    · exact ⟨(later b rest).1, Nat.le_trans hp (later b rest).2⟩

/-- After a recovery the first block's anchor is checked against max(c's anchor, R), and
c's anchor is older than R (it is at most the reference of the landing that settled c), so
only R matters: the new generation never depends on c's L1 anchor. -/
theorem origin_floor_dominates {cAnchor r a : Nat} (older : cAnchor ≤ r) :
    anchorOK cAnchor r a = decide (r ≤ a) := by
  simp only [anchorOK]
  by_cases h : r ≤ a
  · simp [h, Nat.le_trans older h]
  · simp [h]

/-- Normal-switch cutoffs grow with the derivation anchor and never fall below the
generation origin, so successive committee snapshots never decrease. -/
theorem normalCutoff_monotone {d₁ d₂ r : Nat} (le : d₁ ≤ d₂) : normalCutoff d₁ r ≤ normalCutoff d₂ r := by
  simp only [normalCutoff]
  omega

theorem normalCutoff_ge_origin (d r : Nat) : r ≤ normalCutoff d r := Nat.le_max_right _ _

/-- With anchors monotone (rule 3, also across a recovery boundary since old anchors are
below R) and first ≤ origin (genesisCutoff < L1_0, or R = R), committee cutoffs never
decrease from epoch to epoch. -/
theorem generationCutoff_monotone {first origin t₀ : Nat} {anchorD : Nat → Nat}
    (start : first ≤ origin) (anchors : ∀ a b, a ≤ b → anchorD a ≤ anchorD b) :
    ∀ a b, a ≤ b → generationCutoff first origin t₀ anchorD a ≤ generationCutoff first origin t₀ anchorD b := by
  intro a b le
  simp only [generationCutoff]
  by_cases ha : a < t₀ <;> by_cases hb : b < t₀ <;> simp only [ha, hb, ite_true, ite_false]
  · exact Nat.le_refl _
  · exact Nat.le_trans start (normalCutoff_ge_origin _ _)
  · omega
  · exact normalCutoff_monotone (anchors a b le)

/-- By height: block h belongs to epoch ⌊(h−1)/L⌋, which is monotone in h. -/
theorem heightCutoff_monotone {first origin t₀ l : Nat} {anchorD : Nat → Nat}
    (start : first ≤ origin) (anchors : ∀ a b, a ≤ b → anchorD a ≤ anchorD b) :
    ∀ a b, a ≤ b → generationCutoff first origin t₀ anchorD ((a-1)/l) ≤
      generationCutoff first origin t₀ anchorD ((b-1)/l) := by
  intro a b le
  exact generationCutoff_monotone start anchors _ _ (Nat.div_le_div_right (by omega))

/-- An exit already covered by a landed snapshot stays out of every committee whose cutoff
is at least that snapshot (all later normal switches and any recovery at R). -/
theorem covered_exit_never_eligible {unit minimum stored cutoff : Nat} {e : Entry}
    (covered : e.exitAt ≤ stored) (later : stored ≤ cutoff) : eligible unit minimum cutoff e = false := by
  simp only [eligible, decide_eq_false_iff_not]
  omega

theorem covered_exit_never_chosen {unit minimum stored cutoff nMax : Nat} {entries : List Entry} {e : Entry}
    (covered : e.exitAt ≤ stored) (later : stored ≤ cutoff) : e ∉ chosen unit minimum cutoff nMax entries := by
  intro h
  have := (chosen_eligible unit minimum cutoff nMax entries e h).2.2.1
  omega

theorem witness_root_and_cutoff {d r root : Nat} {w : Witness} (ok : witnessOK d r root w) :
    w.proofRoot = root ∧ d ≤ w.cutoff ∧ r ≤ w.cutoff := by
  rcases ok with ⟨h,rfl⟩
  simp only [normalCutoff] at h
  exact ⟨rfl, by omega, by omega⟩

theorem h_plus_two (s : Schedule) (h : Nat) (r : Record) :
    authority (announce s h r) h = authority s h ∧
    authority (announce s h r) (h+1) = authority s h ∧
    authority (announce s h r) (h+2) = r := by
  simp [authority,announce,show ¬h+2 ≤ h by omega,show ¬h+2 ≤ h+1 by omega]

theorem recovery_cancels_pending (_old : Schedule) (r : Record) (h : Nat) :
    authority (recoverySchedule r) h = r ∧ (recoverySchedule r).pending = none := by
  simp [authority,recoverySchedule]

/-- With c and U on the grid, the last height back-pressure allows, c+U, is itself a grid
point at which a landing may end (arithmetic only). -/
theorem pause_point_on_grid {k c l u : Nat} (cg : c % k = 0) (ok : configOK k l u = true) :
    (c+u) % k = 0 := by
  have h := of_decide_eq_true ok
  have ug : u % k = 0 := h.2.2.2.2.2.2
  rw [Nat.add_mod, cg, ug]
  simp

/-- U = 3,600 is a valid choice for every allowed K. -/
theorem target_u_fits_every_k (k : Nat) (range : 1 ≤ k ∧ k ≤ 6) : configOK k 900 3600 = true := by
  have : k = 1 ∨ k = 2 ∨ k = 3 ∨ k = 4 ∨ k = 5 ∨ k = 6 := by omega
  rcases this with rfl | rfl | rfl | rfl | rfl | rfl <;> decide

theorem unsettled_bound {height checkpoint u : Nat} (ok : backPressure height checkpoint u = true) :
    height-checkpoint ≤ u := by simpa [backPressure] using ok

end Etna.Design.Committee
