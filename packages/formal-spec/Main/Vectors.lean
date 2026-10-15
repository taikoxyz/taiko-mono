import TaikoSpec.Derivation.Manifest
import Lean.Data.Json

/-!
# Shared vector runner

Runs `testdata/derivation_vectors/manifest_cases.json` (schema version 1), the corpus the Go and
Rust drivers also run, against the spec. Usage: `lake exe vectors [path]`.
-/

open Lean TaikoSpec TaikoSpec.Derivation

/-- Every case is decoded as the Go adapter does: a devnet proposal at timestamp 1000, from a
non-forced source that has blobs. -/
def vectorCtx : ProposalCtx where
  proposer := ⟨Array.replicate 20 0⟩
  timestamp := 1000
  originBlockNumber := 0

/-- One corpus case. -/
structure Case where
  name : String
  family : String
  payload : String
  offset : Nat
  expectDefault : Bool
  expectedRlp : String
  engineTxList : Option String
  engineDecodable : Option Bool

def Case.ofJson (j : Json) : Except String Case := do
  return {
    name := ← j.getObjValAs? String "name"
    family := ← j.getObjValAs? String "family"
    payload := ← j.getObjValAs? String "payload_hex"
    offset := ← j.getObjValAs? Nat "offset"
    expectDefault := ← j.getObjValAs? Bool "expect_default"
    expectedRlp := ← j.getObjValAs? String "expected_manifest_rlp_hex"
    engineTxList := (j.getObjValAs? String "engine_tx_list_hex").toOption
    engineDecodable := (j.getObjValAs? Bool "engine_decodable").toOption }

/-- Whether every transaction in an engine transaction list is well formed. -/
def engineListWellFormed (bytes : ByteArray) : Bool :=
  match Rlp.decode bytes with
  | some (.list txs) => txs.all Tx.wellFormed
  | _ => false

/-- The reasons a case fails; empty when it passes. A default result is compared as the default
manifest, one zero-valued block without transactions. -/
def check (v : Case) : List String :=
  let manifest :=
    match fromHex? v.payload, fromHex? v.expectedRlp with
    | some payload, some expected =>
      let src : Source := { isForcedInclusion := false, hasBlobs := true, offset := v.offset }
      let got := extractManifest devnet vectorCtx src (some payload)
      let rlp := encodeManifest (got.getD [emptyBlock])
      (if got.isNone == v.expectDefault then []
        else [s!"expect_default is {v.expectDefault} but the spec's is {got.isNone}"]) ++
      (if rlp == expected then [] else [s!"manifest RLP differs: spec gives {toHex rlp}"])
    | _, _ => ["payload_hex or expected_manifest_rlp_hex is not hex"]
  let engine :=
    match v.engineTxList, v.engineDecodable with
    | some list, some decodable =>
      match fromHex? list with
      | some bytes =>
        let ok := engineListWellFormed bytes
        if ok == decodable then []
        else [s!"engine_decodable is {decodable} but the spec's grammar says {ok}"]
      | none => ["engine_tx_list_hex is not hex"]
    | _, _ => []
  manifest ++ engine

def main (args : List String) : IO UInt32 := do
  let path := args.headD "../../testdata/derivation_vectors/manifest_cases.json"
  let json ← IO.ofExcept (Json.parse (← IO.FS.readFile path))
  let version ← IO.ofExcept (json.getObjValAs? Nat "schema_version")
  unless version == 1 do
    throw <| IO.userError s!"unsupported schema_version {version}"
  let cases ← IO.ofExcept (json.getObjValAs? (Array Json) "cases")
  let mut failed := 0
  for j in cases do
    let v ← IO.ofExcept (Case.ofJson j)
    let errors := check v
    unless errors.isEmpty do
      failed := failed + 1
      IO.eprintln s!"FAIL {v.family}/{v.name}: {String.intercalate "; " errors}"
  IO.println s!"{cases.size - failed}/{cases.size} vectors passed"
  return if failed == 0 then 0 else 1
