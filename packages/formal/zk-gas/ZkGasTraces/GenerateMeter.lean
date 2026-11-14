import ZkGasTraces.MeterVectors

/-! CLI for exporting the Lean-generated meter corpus or checking committed bytes for drift. -/
open TaikoSpec.ZkGas.Traces.MeterExport

/-- Generate the shared corpus, or compare it without rewriting any existing expectation. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | ["--check", path] =>
    unless ← (System.FilePath.mk path).pathExists do
      IO.eprintln s!"meter vectors missing: {path}"
      return 1
    unless (← IO.FS.readFile path) == corpusText do
      IO.eprintln s!"meter vectors drift: regenerate {path} with generate-meter-vectors"
      return 1
    IO.println s!"meter vectors: {vectors.length} Lean-generated cases match"
    return 0
  | [path] =>
    if path.startsWith "--" then
      IO.eprintln "usage: generate-meter-vectors [--check] <meter-vectors.json>"
      return 2
    IO.FS.writeFile path corpusText
    IO.println s!"meter vectors: wrote {vectors.length} Lean-generated cases to {path}"
    return 0
  | _ =>
    IO.eprintln "usage: generate-meter-vectors [--check] <meter-vectors.json>"
    return 2
