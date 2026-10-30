import EtnaVectors.Machine

/-! Client conformance families: each vector is the whole input of one pure node rule and the
model's decision on it. Unlike the Inbox families there are no setup calls: the input is all the
state the rule reads. The Rust client (`packages/taiko-client-rs`) runs them. -/
namespace Etna.Vectors

/-- A client-rule vector before rendering. `spec` marks a hand-written case (an English spec
line). -/
structure ClientCase where
  label : String
  spec : Option String := none
  input : List (String × JVal)
  expect : List (String × JVal)

def renderClientCase (family : String) (c : ClientCase) : JVal :=
  jObj ([("id", jStr c.label), ("family", jStr family),
      ("source", jStr (if c.spec.isSome then "handwritten" else "generated"))] ++
    (match c.spec with | some s => [("spec", jStr s)] | none => []) ++
    [("input", jLine c.input), ("expect", jLine c.expect)])

/-- One client family file. Labels are unique and every hand-written vector cites a spec line.
`header` holds the family's shared tables. The file records only what the model decides; the
client harness keeps its own list of known divergences. -/
def clientFile (family : String) (provenance : Option String) (header : List (String × JVal))
    (cases : List ClientCase) : Except String String := do
  let labels := cases.map (·.label)
  unless decide labels.Nodup do throw (family ++ ": duplicate vector ids")
  for c in cases do
    if c.spec.isNone && (c.label.splitOn ".hw.").length > 1 then
      throw (c.label ++ ": a hand-written vector needs a spec line")
  let vectors := cases.map (renderClientCase family)
  let head : List (String × JVal) := [("schema", jStr "etna-client-conformance-1"), ("family", jStr family),
    ("generator", jStr "formal/etna: lake exe etna-vectors --write testdata/etna_conformance")]
  let prov : List (String × JVal) := match provenance with
    | some sha => [("provenance", jLine [("formalCommit", jStr sha)])]
    | none => []
  pure (jObj (head ++ prov ++ header ++ [("vectorCount", jNat vectors.length), ("vectors", jArr vectors)]) 0 ++ "\n")

end Etna.Vectors
