module

public import Mathlib.Data.Fin.Basic
public import Lean.Elab.Tactic.Omega

public section

namespace Etna

abbrev Word48 := Fin (2 ^ 48)
abbrev Word64 := Fin (2 ^ 64)
abbrev Word256 := Fin (2 ^ 256)

/-- Checked conversion; never silently reduces modulo the machine width. -/
def checkedWord (bits n : Nat) : Option (Fin (2 ^ bits)) :=
  if h : n < 2 ^ bits then some ⟨n, h⟩ else none

theorem checkedWord_some_iff (bits n : Nat) :
    (∃ word, checkedWord bits n = some word) ↔ n < 2 ^ bits := by
  unfold checkedWord
  split <;> simp_all

theorem word64_add_fits128 (a b : Word64) : a.val + b.val < 2 ^ 128 := by
  have ha := a.isLt
  have hb := b.isLt
  omega

inductive Failure where
  | authentication | encoding | arithmetic | malformedExecution | invalidHistory
  | verifier | signal | payment | reentrant
  deriving DecidableEq, Repr

inductive Blocked where
  | needsSkip | timeout | cancelled | missingHistory | rpcError
  deriving DecidableEq, Repr

/-- The caller must carry the authenticated tail when committing consumption. -/
structure ConsumedIndex where
  index : Word64
  deriving DecidableEq, Repr

structure Accepted where
  consumed : Option ConsumedIndex
  deriving DecidableEq, Repr

inductive Outcome where
  | failure (reason : Failure)
  | blocked (reason : Blocked)
  | accepted (result : Accepted)
  deriving DecidableEq, Repr

structure BatchSummary where
  firstHeight : Word48
  lastHeight : Word48
  headBefore : Word64
  headAfter : Word64
  blocks : Nat
  feesGwei : Word256
  deriving DecidableEq, Repr

end Etna
