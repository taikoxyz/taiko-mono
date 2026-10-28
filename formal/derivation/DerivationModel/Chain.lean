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

end TaikoSpec
