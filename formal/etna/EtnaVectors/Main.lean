import EtnaVectors.ForcedInclusion
import EtnaVectors.Registry
import EtnaVectors.Land
import EtnaVectors.Recover
import EtnaVectors.ForcedStep
import EtnaVectors.Schedule
import EtnaVectors.Random

/-! `lake exe etna-vectors --write <dir> [--provenance <formal commit>] [--families <f>,…]` writes
one JSON file per family: four Inbox families for the contracts and four client-rule families for
the Rust client, or only the named families. The output depends only on the model and this
generator, so two runs are byte-identical. `--random <seed> [--count <n>]` instead writes only the
opt-in random files of `EtnaVectors.Random` (default count 100); `--provenance` and `--families`
do not apply to it, and `--count` needs it. Nothing is written unless every file renders. -/
namespace Etna.Vectors

def families (provenance : Option String) : List (String × Except String String) := [
  ("forced.json", familyFile "forced" provenance forcedScenarios),
  ("registry.json", familyFile "registry" provenance registryScenarios),
  ("land.json", familyFile "land" provenance landScenarios),
  ("recover.json", familyFile "recover" provenance recoverScenarios),
  ("forced_step.json", forcedStepFile provenance),
  ("schedule.json", scheduleFile provenance),
  ("block_rules.json", blockRulesFile provenance),
  ("block_size.json", blockSizeFile provenance)]

def usage : String :=
  "usage: etna-vectors --write <dir> [--provenance <formal commit>] [--families <family>,...] " ++
  "| --write <dir> --random <seed> [--count <n>]"

structure Options where
  dir : Option String := none
  provenance : Option String := none
  /-- none: every family. -/
  only : Option (List String) := none
  /-- some seed: write only the random files. -/
  random : Option Nat := none
  /-- Random vectors per file; only with `random` (default 100). -/
  count : Option Nat := none

def parseOptions : Options → List String → Option Options
  | o, [] => some o
  | o, "--write" :: d :: rest => parseOptions { o with dir := some d } rest
  | o, "--provenance" :: s :: rest => parseOptions { o with provenance := some s } rest
  | o, "--families" :: fs :: rest => parseOptions { o with only := some (fs.splitOn ",") } rest
  | o, "--random" :: s :: rest => match s.toNat? with
    | some n => parseOptions { o with random := some n } rest
    | none => none
  | o, "--count" :: s :: rest => match s.toNat? with
    | some n => parseOptions { o with count := some n } rest
    | none => none
  | _, _ => none

/-- `forced_step.json` names the family `forced_step`. -/
def familyName (file : String) : String := (file.splitOn ".").headD file

def run (args : List String) : IO UInt32 := do
  let some o := parseOptions {} args
    | IO.eprintln usage
      return 2
  let some dir := o.dir
    | IO.eprintln usage
      return 2
  if o.random.isSome && o.only.isSome then
    IO.eprintln "etna-vectors: --families does not apply to --random"
    return 2
  if o.random.isSome && o.provenance.isSome then
    IO.eprintln "etna-vectors: --provenance does not apply to --random"
    return 2
  if o.random.isNone && o.count.isSome then
    IO.eprintln "etna-vectors: --count needs --random"
    return 2
  let all := match o.random with
    | some seed => randomFiles seed (o.count.getD 100)
    | none => families o.provenance
  let names := all.map fun (file, _) => familyName file
  let chosen := match o.only with
    | none => all
    | some fs => all.filter fun (file, _) => fs.contains (familyName file)
  if let some fs := o.only then
    for f in fs do
      unless names.contains f do
        IO.eprintln ("etna-vectors: unknown family " ++ f)
        return 2
  let mut rendered : List (String × String) := []
  for (name, file) in chosen do
    match file with
    | .error e =>
      IO.eprintln ("etna-vectors: " ++ e)
      return 1
    | .ok text => rendered := rendered ++ [(name, text)]
  IO.FS.createDirAll dir
  for (name, text) in rendered do
    IO.FS.writeFile (System.FilePath.mk dir / name) text
  IO.println ("etna-vectors: wrote " ++ Nat.repr chosen.length ++ " files to " ++ dir)
  return 0

end Etna.Vectors

/-- The executable's entry point; Lake needs it to be the root `main`, the one declaration of
the package outside the `Etna` namespace (scripts/EtnaAudit.lean). -/
def main (args : List String) : IO UInt32 := Etna.Vectors.run args
