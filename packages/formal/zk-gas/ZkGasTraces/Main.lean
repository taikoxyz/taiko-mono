import Std.Data.HashMap
import ZkGasTraces.Check

/-!
# Trace checker entry point

`lake exe check-traces <corpus-dir>` checks every vector's trace, `traces/<id>.jsonl`, against
the vector `cases/<id>.json` with `checkVectorText` and the Unzen step model `stepModel`. Every
vector needs a trace, and every trace a vector. It stops at the first failure, printing the
vector id and the reason (with the event index, counted from 0, where one event is at fault), and
exits 1.

Then the coverage gate: it prints how many steps of the corpus each branch of `allBranches`
decided, and fails, listing them, when a branch that `unreachableBranches` does not list has no
step, when a listed one has, or when a step reports a branch outside `allBranches`
(`coverageErrors`).
-/
open TaikoSpec.ZkGas TaikoSpec.ZkGas.Traces

def usage : String := "usage: check-traces <corpus-dir>"

/-- The ids of the files with extension `ext` in `dir`, sorted; dot files are skipped. -/
def stems (dir : System.FilePath) (ext : String) : IO (List String) := do
  let entries ← dir.readDir
  let names := entries.toList.filterMap fun entry =>
    let path : System.FilePath := entry.fileName
    if entry.fileName.startsWith "." || path.extension != some ext then none else path.fileStem
  return names.mergeSort fun a b => decide (a ≤ b)

def fail (message : String) : IO UInt32 := do
  IO.eprintln s!"check-traces: {message}"
  return 1

def main (args : List String) : IO UInt32 := do
  let [dir] := args | do
    IO.eprintln usage
    return 2
  let root : System.FilePath := dir
  let cases := root / "cases"
  let traces := root / "traces"
  unless ← traces.isDir do
    return ← fail s!"{traces} does not exist; every vector needs a trace"
  let ids ← stems cases "json"
  if ids.isEmpty then return ← fail s!"no vectors in {cases}"
  for id in ← stems traces "jsonl" do
    unless ids.contains id do return ← fail s!"traces/{id}.jsonl has no vector cases/{id}.json"
  let mut events := 0
  let mut steps := 0
  let mut hits : Std.HashMap String Nat := {}
  for id in ids do
    let tracePath := traces / s!"{id}.jsonl"
    unless ← tracePath.pathExists do return ← fail s!"{id}: missing trace traces/{id}.jsonl"
    let vector ← IO.FS.readFile (cases / s!"{id}.json")
    let trace ← IO.FS.readFile tracePath
    match checkVectorText vector trace stepModel with
    | .error e => return ← fail s!"{id}: {e}"
    | .ok report =>
      events := events + report.events
      steps := steps + report.steps
      for branch in report.branches do
        hits := hits.insert branch (hits.getD branch 0 + 1)
  for b in allBranches do
    IO.println s!"check-traces: branch {b.name}: {hits.getD b.name 0} steps"
  let hit := (allBranches.filter fun b => hits.getD b.name 0 > 0).length
  IO.println s!"check-traces: {ids.length} vectors, {events} events, {steps} steps checked by the model; {hit} of {allBranches.length} branches hit, {unreachableBranches.length} unreachable"
  let errors := coverageErrors hits.toList
  unless errors.isEmpty do
    return ← fail s!"coverage gate: {"; ".intercalate errors}"
  return 0
