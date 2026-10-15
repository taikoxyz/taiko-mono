import Etna.Common.Words
import Lean
set_option pp.universes false
set_option pp.explicit true
set_option pp.fullNames true
-- CORE-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.checkedWord_some_iff
  unless info.isTheorem do throwError "Etna.checkedWord_some_iff is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (bits n : Nat), (∃ word, Etna.checkedWord bits n = some word) ↔ n < 2 ^ bits))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.checkedWord_some_iff: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.checkedWord_some_iff
-- CORE-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.word64_add_fits128
  unless info.isTheorem do throwError "Etna.word64_add_fits128 is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Etna.Word64), a.val + b.val < 2 ^ 128))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.word64_add_fits128: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.word64_add_fits128
