import DerivationModel.Chain

namespace TaikoSpec

theorem Chain.append {R : Nat → Nat → Prop} :
    ∀ {a : Nat} {xs ys : List Nat},
      Chain R a (xs ++ ys) ↔ Chain R a xs ∧ Chain R (lastOr a xs) ys
  | _, [], _ => by simp [Chain, lastOr]
  | _, x :: xs, _ => by simp [Chain, lastOr, Chain.append (xs := xs), and_assoc]

theorem Chain.lt_of_mem : ∀ {a : Nat} {xs : List Nat}, Chain (· < ·) a xs → ∀ x ∈ xs, a < x
  | _, [], _ => by simp
  | _, _ :: _, ⟨hx, hc⟩ => by
    intro y hy
    rcases List.mem_cons.1 hy with rfl | hy
    · exact hx
    · exact Nat.lt_trans hx (Chain.lt_of_mem hc y hy)

theorem lastOr_mem_of_forall {P : Nat → Prop} :
    ∀ {a : Nat} {xs : List Nat}, P a → (∀ x ∈ xs, P x) → P (lastOr a xs)
  | _, [], ha, _ => ha
  | _, x :: xs, _, h => by
    show P (lastOr x xs)
    exact lastOr_mem_of_forall (h x (by simp)) fun y hy => h y (by simp [hy])

end TaikoSpec
