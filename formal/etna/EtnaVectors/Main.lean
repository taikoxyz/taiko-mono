import EtnaVectors.CurrentRegistry

/-! `lake exe etna-vectors --write <dir>` writes the current-model conformance vectors
(`registry_admission.json`). The output depends only on the model and this generator, so two
runs are byte-identical. -/
namespace Etna.Vectors

def usage : String := "usage: etna-vectors --write <dir>"

def run : List String → IO UInt32
  | ["--write", dir] => do
    IO.FS.createDirAll dir
    IO.FS.writeFile (System.FilePath.mk dir / "registry_admission.json") CurrentRegistry.file
    IO.println ("etna-vectors: wrote current registry admission vectors to " ++ dir)
    return 0
  | _ => do
    IO.eprintln usage
    return 2

end Etna.Vectors

/-- The executable's entry point; Lake needs it to be the root `main`, the one declaration of
the package outside the `Etna` namespace (scripts/EtnaAudit.lean). -/
def main (args : List String) : IO UInt32 := Etna.Vectors.run args
