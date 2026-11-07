import EtnaProofs.Current

/-! Current 4096-slot admission, independently of the historical registry vectors. -/
namespace Etna.Design.Current.Registry

theorem search_member (s : State) (best : Nat) (slots : List Nat) :
    search s best slots = best ∨ search s best slots ∈ slots := by
  induction slots generalizing best with
  | nil => exact Or.inl rfl
  | cons slot rest ih =>
    simp only [search]
    split
    · exact Or.inl rfl
    · split
      · rcases ih slot with equal | member
        · exact Or.inr (by simp [equal])
        · exact Or.inr (List.mem_cons_of_mem _ member)
      · rcases ih best with equal | member
        · exact Or.inl equal
        · exact Or.inr (List.mem_cons_of_mem _ member)

theorem search_minimum (s : State) (best : Nat) (slots : List Nat) :
    slotValue s (search s best slots) ≤ slotValue s best ∧
      ∀ slot ∈ slots, slotValue s (search s best slots) ≤ slotValue s slot := by
  induction slots generalizing best with
  | nil => exact ⟨Nat.le_refl _,by simp⟩
  | cons slot rest ih =>
    by_cases zero : slotValue s best = 0
    · simp [search,zero]
    · by_cases less : slotValue s slot < slotValue s best
      · simp only [search,ite_eq_right zero,ite_eq_left less]
        have smaller := ih slot
        refine ⟨Nat.le_trans smaller.1 (Nat.le_of_lt less),?_⟩
        intro i member
        rcases List.mem_cons.mp member with rfl | member
        · exact smaller.1
        · exact smaller.2 i member
      · simp only [search,ite_eq_right zero,ite_eq_right less]
        have smaller := ih best
        refine ⟨smaller.1,?_⟩
        intro i member
        rcases List.mem_cons.mp member with rfl | member
        · exact Nat.le_trans smaller.1 (Nat.le_of_not_gt less)
        · exact smaller.2 i member

theorem search_improves (s : State) (best : Nat) (slots : List Nat) :
    search s best slots = best ∨ slotValue s (search s best slots) < slotValue s best := by
  induction slots generalizing best with
  | nil => exact Or.inl rfl
  | cons slot rest ih =>
    by_cases zero : slotValue s best = 0
    · simp [search,zero]
    · by_cases less : slotValue s slot < slotValue s best
      · simp only [search,ite_eq_right zero,ite_eq_left less]
        exact Or.inr (Nat.lt_of_le_of_lt (search_minimum s slot rest).1 less)
      · simpa only [search,ite_eq_right zero,ite_eq_right less] using ih best

theorem search_first_minimum (s : State) (best : Nat) (slots : List Nat)
    (ordered : (best::slots).Pairwise (· < ·)) :
    ∀ i ∈ best::slots, search s best slots ≤ i ∨
      slotValue s (search s best slots) < slotValue s i := by
  induction slots generalizing best with
  | nil => simp [search]
  | cons slot rest ih =>
    obtain ⟨earlier,tail⟩ := List.pairwise_cons.mp ordered
    by_cases zero : slotValue s best = 0
    · simp only [search,ite_eq_left zero]
      intro i member
      rcases List.mem_cons.mp member with rfl | member
      · exact Or.inl (Nat.le_refl _)
      · exact Or.inl (Nat.le_of_lt (earlier i member))
    · by_cases less : slotValue s slot < slotValue s best
      · simp only [search,ite_eq_right zero,ite_eq_left less]
        intro i member
        rcases List.mem_cons.mp member with rfl | member
        · exact Or.inr (Nat.lt_of_le_of_lt (search_minimum s slot rest).1 less)
        · exact ih slot tail i member
      · simp only [search,ite_eq_right zero,ite_eq_right less]
        have shortened : (best::rest).Pairwise (· < ·) := List.pairwise_cons.mpr
          ⟨fun i member => earlier i (List.mem_cons_of_mem _ member),(List.pairwise_cons.mp tail).2⟩
        intro i member
        rcases List.mem_cons.mp member with equal | member
        · subst i; exact ih best shortened best List.mem_cons_self
        · rcases List.mem_cons.mp member with equal | member
          · subst i
            rcases search_improves s best rest with same | improved
            · exact Or.inl (by rw [same]; exact Nat.le_of_lt (earlier slot List.mem_cons_self))
            · exact Or.inr (Nat.lt_of_lt_of_le improved (Nat.le_of_not_gt less))
          · exact ih best shortened i (List.mem_cons_of_mem _ member)

/-- Every one of the 4096 slots participates, and no outside slot can be selected. -/
theorem admission_minimum (s : State) :
    admissionSlot s < 4096 ∧
      ∀ slot, slot < 4096 → slotValue s (admissionSlot s) ≤ slotValue s slot := by
  have member := search_member s 0 (List.range' 1 4095)
  have least := search_minimum s 0 (List.range' 1 4095)
  constructor
  · rcases member with equal | member
    · simp [admissionSlot,equal]
    · have bounds := List.mem_range'_1.mp member
      change search s 0 (List.range' 1 4095) < 4096
      omega
  · intro slot bounded
    by_cases zero : slot = 0
    · subst slot; exact least.1
    · have low : 1 ≤ slot := by omega
      have high : slot < 1+4095 := by omega
      have present : slot ∈ List.range' 1 4095 := List.mem_range'_1.mpr ⟨low,high⟩
      exact least.2 slot present

/-- Equal-value minima are resolved by the lowest slot index, including nonzero minima. -/
theorem admission_lowest_tie (s : State) (slot : Nat) (bounded : slot < 4096)
    (tied : slotValue s (admissionSlot s) = slotValue s slot) : admissionSlot s ≤ slot := by
  have ordered : (0::List.range' 1 4095).Pairwise (· < ·) := List.pairwise_cons.mpr
    ⟨fun i member => by have bounds := List.mem_range'_1.mp member; omega,List.pairwise_lt_range'⟩
  have member : slot ∈ 0::List.range' 1 4095 := by
    by_cases zero : slot = 0
    · simp [zero]
    · exact List.mem_cons_of_mem _ (List.mem_range'_1.mpr ⟨by omega,by omega⟩)
  rcases search_first_minimum s 0 _ ordered slot member with least | strict
  · exact least
  · change slotValue s (admissionSlot s) < slotValue s slot at strict
    omega

/-- A successful displacement selects a genuine minimum among all 4096 slots,
reuses that slot and keeps the displaced bond's entire principal and identity. -/
theorem displacement_selects_global_minimum {s t : State} {key owner amount now id oldId : Nat}
    {old : Bond} (ok : register s key owner amount now = some (t,id))
    (occupied : s.slots (admissionSlot s) = some oldId) (found : s.bonds oldId = some old)
    (issued : oldId < s.nextId) :
    ∃ slot, slot < 4096 ∧
      (∀ i, i < 4096 → slotValue s slot ≤ slotValue s i) ∧
      slotValue s slot < amount ∧ t.slots slot = some id ∧
      t.bonds oldId = some ⟨Staking.exclude old.value now,none⟩ ∧
      (t.bonds oldId).map (fun b => (b.value.key,b.value.owner,b.value.balance)) =
        some (old.value.key,old.value.owner,old.value.balance) := by
  have retained := displacement_keeps_old_bond ok occupied found issued
  have minimum := admission_minimum s
  have selected : slotValue s (admissionSlot s) < amount ∧ t.slots (admissionSlot s) = some id := by
    unfold register at ok
    dsimp only at ok
    split at ok
    next guard =>
      obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
      exact ⟨guard.2.2.2.1,by simp⟩
    next => simp at ok
  refine ⟨admissionSlot s,minimum.1,minimum.2,selected.1,selected.2,retained,?_⟩
  simp [retained,Staking.exclude,Staking.Bond.balance]

end Etna.Design.Current.Registry
