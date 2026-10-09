/-!
# Chains

`Chain R a xs` states that `R` relates each element of `xs` to the next, starting with `a` and
the first element. For example, `Chain (· < ·) a xs` says `xs` is strictly increasing and starts
above `a`.
-/

namespace TaikoSpec

/-- `R a x₁ ∧ R x₁ x₂ ∧ … ∧ R xₙ₋₁ xₙ` for `xs = [x₁, …, xₙ]`. -/
def Chain (R : Nat → Nat → Prop) : Nat → List Nat → Prop
  | _, [] => True
  | a, x :: xs => R a x ∧ Chain R x xs

/-- The last element of `xs`, or `a` when `xs` is empty. -/
def lastOr : Nat → List Nat → Nat
  | a, [] => a
  | _, x :: xs => lastOr x xs

theorem Chain.append {R : Nat → Nat → Prop} :
    ∀ {a : Nat} {xs ys : List Nat},
      Chain R a (xs ++ ys) ↔ Chain R a xs ∧ Chain R (lastOr a xs) ys
  | _, [], _ => by simp [Chain, lastOr]
  | _, x :: xs, _ => by simp [Chain, lastOr, Chain.append (xs := xs), and_assoc]

theorem lastOr_mem_of_forall {P : Nat → Prop} :
    ∀ {a : Nat} {xs : List Nat}, P a → (∀ x ∈ xs, P x) → P (lastOr a xs)
  | _, [], ha, _ => ha
  | _, x :: xs, _, h => by
    show P (lastOr x xs)
    exact lastOr_mem_of_forall (h x (by simp)) fun y hy => h y (by simp [hy])

end TaikoSpec
