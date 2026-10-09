import Lean
import TaikoSpec

/-!
# Axiom gate

Fails unless every declaration defined in a `TaikoSpec` module depends only on Lean's standard
axioms: `propext`, `Classical.choice` and `Quot.sound`. That rules out unproved goals
(`sorryAx`), compiler-trusted proofs (`Lean.ofReduceBool`) and any added assumption.
Usage: `lake exe checkaxioms`.
-/

open Lean

/-- The only axioms a spec declaration may depend on. -/
def allowed : List Name := [``propext, ``Classical.choice, ``Quot.sound]

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := `TaikoSpec }] {}
  let modules := env.header.moduleNames
  let fromSpec (n : Name) : Bool :=
    match env.getModuleIdxFor? n with
    | some idx => (`TaikoSpec).isPrefixOf modules[idx.toNat]!
    | none => false
  let decls := env.constants.map₁.fold (fun acc n _ => if fromSpec n then acc.push n else acc) #[]
  let ctx : Core.Context := { fileName := "checkaxioms", fileMap := default }
  let mut violations : Array String := #[]
  for n in decls do
    let (axioms, _) ← (collectAxioms n : CoreM (Array Name)).toIO ctx { env }
    for a in axioms do
      unless allowed.contains a do
        violations := violations.push s!"{n} depends on {a}"
  if violations.isEmpty then
    IO.println s!"checkaxioms: all {decls.size} TaikoSpec declarations use only {allowed}"
    return 0
  for v in violations do
    IO.eprintln v
  return 1
