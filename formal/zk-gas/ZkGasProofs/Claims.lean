import ZkGasStatements

/-!
# Metering proofs

Lemmas about `meterCharges`, `meterTx` and `meterBlockFrom`, and the three headline theorems,
whose types are exactly the statements in `ZkGasStatements/Claims.lean`.
-/
namespace TaikoSpec.ZkGas.Proofs

open Statements

/-- A metered total is the starting total plus every charge. -/
theorem meterCharges_eq_sum (budget : Nat) :
    ∀ (total : Nat) (cs : List Nat) (n : Nat),
      meterCharges budget total cs = some n → n = total + cs.sum := by
  intro total cs
  induction cs generalizing total with
  | nil => intro n h; simp [meterCharges] at h ⊢; omega
  | cons c cs ih =>
    intro n h
    simp only [meterCharges] at h
    split at h
    · simp at h
    · have := ih (total + c) n h
      simp only [List.sum_cons]
      omega

/-- A metered total starting within the budget stays within it. -/
theorem meterCharges_le (budget : Nat) :
    ∀ (total : Nat) (cs : List Nat) (n : Nat),
      total ≤ budget → meterCharges budget total cs = some n → n ≤ budget := by
  intro total cs
  induction cs generalizing total with
  | nil => intro n hle h; simp [meterCharges] at h; omega
  | cons c cs ih =>
    intro n hle h
    simp only [meterCharges] at h
    split at h
    · simp at h
    · exact ih (total + c) n (by omega) h

/-- A committed transaction's total is the sum of its charges and fits what the block has
left. -/
theorem meterTx_some (s : Schedule) (used : Nat) (cs : List Nat) (n : Nat)
    (h : meterTx s used cs = some n) : n = cs.sum ∧ n ≤ s.blockLimit - used := by
  unfold meterTx at h
  exact ⟨by have := meterCharges_eq_sum _ 0 cs n h; omega,
    meterCharges_le _ 0 cs n (Nat.zero_le _) h⟩

/-- Metering from a used amount within the limit ends within the limit. -/
theorem meterBlockFrom_le (s : Schedule) :
    ∀ (used : Nat) (txs : List (List Nat)),
      used ≤ s.blockLimit → (meterBlockFrom s used txs).2 ≤ s.blockLimit := by
  intro used txs
  induction txs generalizing used with
  | nil => intro h; simpa [meterBlockFrom] using h
  | cons tx txs ih =>
    intro h
    simp only [meterBlockFrom]
    split
    · exact h
    · rename_i n hn
      have := (meterTx_some s used tx n hn).2
      exact ih (used + n) (by omega)

/-- The total after metering is the starting amount plus the committed totals. -/
theorem meterBlockFrom_total (s : Schedule) :
    ∀ (used : Nat) (txs : List (List Nat)),
      (meterBlockFrom s used txs).2 = used + ((meterBlockFrom s used txs).1.filterMap id).sum := by
  intro used txs
  induction txs generalizing used with
  | nil => simp [meterBlockFrom]
  | cons tx txs ih =>
    simp only [meterBlockFrom]
    split
    · simp
    · rename_i n _
      simp only [List.filterMap_cons, id, List.sum_cons]
      rw [ih (used + n)]
      omega

/-- Each committed result is the sum of its transaction's charges. -/
theorem meterBlockFrom_result (s : Schedule) :
    ∀ (used : Nat) (txs : List (List Nat)) (i n : Nat),
      (meterBlockFrom s used txs).1[i]? = some (some n) → txs[i]?.map List.sum = some n := by
  intro used txs
  induction txs generalizing used with
  | nil => intro i n h; simp [meterBlockFrom] at h
  | cons tx txs ih =>
    intro i n h
    simp only [meterBlockFrom] at h
    split at h
    · cases i <;> simp at h
    · rename_i m hm
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at h
        subst h
        simp [(meterTx_some s used tx m hm).1]
      | succ i =>
        simp only [List.getElem?_cons_succ] at h ⊢
        exact ih (used + m) i n h

/-- After committed transactions, a transaction that does not fit ends the block unchanged. -/
theorem meterBlockFrom_abort (s : Schedule) (tx : List Nat) (rest : List (List Nat)) :
    ∀ (used : Nat) (pre : List (List Nat)),
      none ∉ (meterBlockFrom s used pre).1 →
      meterTx s (meterBlockFrom s used pre).2 tx = none →
      meterBlockFrom s used (pre ++ tx :: rest) =
        ((meterBlockFrom s used pre).1 ++ [none], (meterBlockFrom s used pre).2) := by
  intro used pre
  induction pre generalizing used with
  | nil =>
    intro _ h
    simp only [meterBlockFrom, List.nil_append] at h ⊢
    simp [h]
  | cons p pre ih =>
    intro hpre h
    simp only [meterBlockFrom] at hpre h ⊢
    simp only [List.cons_append, meterBlockFrom]
    split
    · rename_i hp
      simp [hp] at hpre
    · rename_i n hp
      simp only [hp, List.mem_cons, reduceCtorEq, false_or] at hpre h
      rw [ih (used + n) hpre h]
      simp

/-- A block never uses more zk gas than its limit. -/
theorem block_within_limit : BlockWithinLimit := fun s txs =>
  meterBlockFrom_le s 0 txs (Nat.zero_le _)

/-- A transaction that exceeds what the block has left contributes nothing, and the
transactions after it are not executed. -/
theorem abort_contributes_nothing : AbortContributesNothing := fun s pre tx rest =>
  meterBlockFrom_abort s tx rest 0 pre

/-- Committed totals are charge sums, and the block total is their sum. -/
theorem total_is_sum : TotalIsSum := fun s txs =>
  ⟨meterBlockFrom_result s 0 txs, by
    have := meterBlockFrom_total s 0 txs
    unfold meterBlock
    omega⟩

end TaikoSpec.ZkGas.Proofs
