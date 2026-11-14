import DerivationModel.Derivation.Manifest
import DerivationModel.Derivation.Header
import Lean.Data.Json

/-!
# Shared vector runner

Runs `testdata/derivation_vectors/manifest_cases.json` (schema version 1), the corpus the Go and
Rust drivers also run, against the spec. Usage: `lake exe vectors [path]`.
-/

open Lean TaikoSpec TaikoSpec.Derivation

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
      -- Every case is decoded as the Go adapter does: a non-forced source that has blobs.
      let src : Source := { isForcedInclusion := false, hasBlobs := true, offset := v.offset }
      let got := extractManifest src (some payload)
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

namespace Boundary

/-- The parent representation shared with the production client adapters. -/
structure ParentView where
  number : Nat
  timestamp : Nat
  gas_limit : Nat
  anchor_block_number : Nat
  deriving FromJson, ToJson, BEq, Inhabited

/-- Proposal inputs; fork parameters are selected by the actual chain ID. -/
structure Proposal where
  timestamp : Nat
  origin_block_number : Nat
  proposer : String
  proposal_id : Nat
  basefee_sharing_pctg : Nat
  deriving FromJson, ToJson, Inhabited

/-- One source after blob field-element decoding, which remains outside the model. -/
structure SourceInput where
  is_forced_inclusion : Bool
  has_blobs : Bool
  offset : Nat
  payload_hex : Option String
  deriving FromJson, ToJson, Inhabited

/-- Observable metadata and ordered manifest candidates for one derived block. -/
structure BlockView where
  number : Nat
  timestamp : Nat
  coinbase : String
  anchor_block_number : Nat
  gas_limit : Nat
  transactions_rlp_hex : String
  is_forced_inclusion : Bool
  deriving FromJson, ToJson, BEq, Inhabited

/-- Header plan, with its anchor target separate from signed transaction encoding. -/
structure HeaderView where
  gas_limit : Nat
  extra_data_hex : String
  anchor_block_number : Nat
  transactions_rlp_hex : String
  anchor_first : Bool
  deriving FromJson, ToJson, BEq, Inhabited

/-- The same normalized outputs are checked by Lean, Go and Rust. -/
structure Output where
  source_block_counts : List Nat
  extracted_manifests_rlp_hex : List String
  blocks : List BlockView
  headers : List HeaderView
  next_parent : ParentView
  deriving FromJson, ToJson, BEq, Inhabited

/-- Inputs to the executable model, without any supplied expected output. -/
structure Input where
  name : String
  category : String
  chain_id : Nat
  proposal : Proposal
  parent : ParentView
  sources : List SourceInput
  deriving FromJson, ToJson, Inhabited

/-- An independently authored boundary case, not an output blessed by a client. -/
structure Vector where
  name : String
  category : String
  chain_id : Nat
  proposal : Proposal
  parent : ParentView
  sources : List SourceInput
  expected : Output
  deriving FromJson, Inhabited

/-- Project a golden vector to its inputs so evaluation cannot inspect its expected output. -/
def Vector.input (v : Vector) : Input :=
  ⟨v.name, v.category, v.chain_id, v.proposal, v.parent, v.sources⟩

def parentView (p : Parent) : ParentView :=
  ⟨p.number, p.timestamp, p.gasLimit, p.anchorBlockNumber⟩

def sourceInput (s : SourceInput) : Except String (Source × Option ByteArray) := do
  let bytes ← match s.payload_hex with
    | none => pure none
    | some hex => match fromHex? hex with
      | none => throw "invalid payload hex"
      | some bytes => pure (some bytes)
  let src : Source :=
    { isForcedInclusion := s.is_forced_inclusion
      hasBlobs := s.has_blobs
      offset := s.offset }
  return (src, bytes)

def headerView (h : HeaderPlan) : Except String HeaderView := do
  let .anchor target :: tail := h.transactions | throw "header anchor is not first"
  let candidates ← tail.mapM fun
    | .manifest item => pure item
    | .anchor _ => throw "second anchor in header plan"
  return ⟨h.gasLimit, toHex ⟨h.extraData.toArray⟩, target,
    toHex (Rlp.encode (.list candidates)), true⟩

/-- Evaluate only inputs, using the same model functions as the independent vector checks. -/
def evaluateInput (v : Input) : Except String Output := do
  let c ← match v.chain_id with
    | 167001 => pure devnet
    | 167000 => pure mainnet
    | 167013 => pure hoodi
    | _ => throw "unsupported chain ID"
  unless c.unzenForkTime ≤ v.proposal.timestamp do throw "proposal predates Unzen"
  unless v.proposal.proposal_id < uint48Limit do throw "proposal ID exceeds uint48"
  unless v.proposal.basefee_sharing_pctg < 256 do throw "sharing percentage exceeds uint8"
  let some proposer := fromHex? v.proposal.proposer | throw "invalid proposer hex"
  unless proposer.size = 20 do throw "proposer must be 20 bytes"
  let ctx : ProposalCtx := ⟨proposer, v.proposal.timestamp, v.proposal.origin_block_number⟩
  let p : Parent := ⟨v.parent.number, v.parent.timestamp, v.parent.gas_limit,
    v.parent.anchor_block_number⟩
  let hc : HeaderContext := ⟨UInt8.ofNat v.proposal.basefee_sharing_pctg, v.proposal.proposal_id⟩
  let sources ← v.sources.mapM sourceInput
  let extracted := sources.map fun (s, bytes) =>
    toHex (encodeManifest ((extractManifest s bytes).getD [emptyBlock]))
  let (_, counts) := sources.foldl (fun (p, counts) (s, bytes) =>
    let bs := sourceBlocks c ctx p s bytes
    (bs.foldl advance p, counts ++ [bs.length])) (p, ([] : List Nat))
  let blocks := (deriveSources c ctx p sources).map fun b =>
    { number := b.number, timestamp := b.timestamp, coinbase := toHex b.coinbase,
      anchor_block_number := b.anchorBlockNumber, gas_limit := b.gasLimit,
      transactions_rlp_hex := toHex (Rlp.encode (.list b.transactions)),
      is_forced_inclusion := b.isForcedInclusion : BlockView }
  let plans := deriveHeaders c ctx hc p sources
  let headers ← plans.mapM headerView
  return ⟨counts, extracted, blocks, headers, parentView (rebuiltParent p plans)⟩

/-- Run the executable model, including extraction before metadata can mask a decode failure. -/
def evaluate (v : Vector) : Except String Output := evaluateInput v.input

/-- Emit a client-compatible corpus whose expected outputs come exclusively from the model.
Inputs with expected outputs, empty or duplicate names, and existing output files are rejected.
All cases are evaluated before publishing a file, so a failed case never yields a partial corpus. -/
def emit (inputPath outputPath : System.FilePath) : IO UInt32 := do
  if ← outputPath.pathExists then
    throw (IO.userError "output already exists; refusing to overwrite a fixture")
  let json ← IO.ofExcept (Json.parse (← IO.FS.readFile inputPath))
  unless (← IO.ofExcept (json.getObjValAs? Nat "schema_version")) == 1 do
    throw (IO.userError "unsupported boundary schema")
  let cases ← IO.ofExcept (json.getObjValAs? (List Json) "cases")
  unless !cases.isEmpty do throw (IO.userError "empty boundary inputs")
  let mut names : List String := []
  let mut outputs : Array Json := #[]
  for j in cases do
    if (j.getObjVal? "expected").isOk then
      throw (IO.userError "model inputs must not contain expected outputs")
    let v ← IO.ofExcept (fromJson? j : Except String Input)
    unless !v.name.isEmpty && !v.category.isEmpty do
      throw (IO.userError "case name and category must not be empty")
    if names.contains v.name then throw (IO.userError s!"duplicate case: {v.name}")
    names := v.name :: names
    let expected ← IO.ofExcept ((evaluateInput v).mapError fun e => s!"{v.name}: {e}")
    outputs := outputs.push ((toJson v).mergeObj (Json.mkObj [("expected", toJson expected)]))
  let corpus := Json.mkObj [("schema_version", toJson (1 : Nat)), ("cases", toJson outputs)]
  IO.FS.writeFile outputPath (corpus.compress ++ "\n")
  IO.println s!"{outputs.size} model-generated boundary vectors written to {outputPath}"
  return 0

def errors (v : Vector) : Except String (List String) := do
  let actual ← evaluate v
  return ([(actual.source_block_counts == v.expected.source_block_counts, "source counts"),
    (actual.extracted_manifests_rlp_hex == v.expected.extracted_manifests_rlp_hex, "extracted manifests"),
    (actual.blocks == v.expected.blocks, "blocks"),
    (actual.headers == v.expected.headers, "headers"),
    (actual.next_parent == v.expected.next_parent, "next parent")].filterMap fun (ok, field) =>
      if ok then none else some (field ++ " differ"))

/-- Rejection controls use a real multi-candidate case and mutate every output layer. -/
def mutations (cases : List Vector) : Except String Unit := do
  let some v := cases.find? (·.name == "ordered_candidates") | throw "missing ordered control"
  let e := v.expected
  let changeBlock (f : BlockView → BlockView) := { e with blocks := e.blocks.modifyHead f }
  let changeHeader (f : HeaderView → HeaderView) := { e with headers := e.headers.modifyHead f }
  let some first := e.blocks.head? | throw "empty ordered control"
  let some txs := fromHex? first.transactions_rlp_hex | throw "invalid ordered control RLP"
  let some (.list items) := Rlp.decode txs | throw "ordered candidates must be a list"
  unless 2 ≤ items.length do throw "ordered control needs distinct candidates"
  let reversed := toHex (Rlp.encode (.list items.reverse))
  unless reversed != first.transactions_rlp_hex do throw "ordered control needs distinct candidates"
  let changed : List Output := [
    { e with source_block_counts := e.source_block_counts.modifyHead (· + 1) },
    { e with extracted_manifests_rlp_hex := e.extracted_manifests_rlp_hex.modifyHead (· ++ "00") },
    changeBlock (fun b => { b with timestamp := b.timestamp + 1 }),
    changeBlock (fun b => { b with coinbase := "" }),
    changeBlock (fun b => { b with number := b.number + 1 }),
    changeBlock (fun b => { b with anchor_block_number := b.anchor_block_number + 1 }),
    changeBlock (fun b => { b with gas_limit := b.gas_limit + 1 }),
    changeBlock (fun b => { b with is_forced_inclusion := !b.is_forced_inclusion }),
    changeBlock (fun b => { b with transactions_rlp_hex := reversed }),
    changeHeader (fun h => { h with gas_limit := h.gas_limit + 1 }),
    changeHeader (fun h => { h with extra_data_hex := "00" }),
    changeHeader (fun h => { h with anchor_block_number := h.anchor_block_number + 1 }),
    changeHeader (fun h => { h with transactions_rlp_hex := reversed }),
    changeHeader (fun h => { h with anchor_first := false }),
    { e with next_parent := { e.next_parent with timestamp := e.next_parent.timestamp + 1 } }]
  for expected in changed do
    if (← errors { v with expected }).isEmpty then throw "boundary output mutation escaped"

def run (path : String) : IO UInt32 := do
  let json ← IO.ofExcept (Json.parse (← IO.FS.readFile path))
  unless (← IO.ofExcept (json.getObjValAs? Nat "schema_version")) == 1 do
    throw (IO.userError "unsupported boundary schema")
  let cases ← IO.ofExcept (json.getObjValAs? (List Vector) "cases")
  unless !cases.isEmpty do throw (IO.userError "empty boundary corpus")
  let mut failed := 0
  for v in cases do
    let failures ← IO.ofExcept (errors v)
    unless failures.isEmpty do
      failed := failed + 1
      IO.eprintln s!"FAIL boundary/{v.name}: {String.intercalate "; " failures}"
  IO.ofExcept (mutations cases)
  IO.println s!"{cases.length - failed}/{cases.length} boundary vectors passed; 15 output mutations rejected"
  return if failed == 0 then 0 else 1

end Boundary

def main (args : List String) : IO UInt32 := do
  if args.head? == some "--emit-boundaries" then
    match args with
    | [_, inputPath, outputPath] => return ← Boundary.emit inputPath outputPath
    | _ => throw (IO.userError "usage: vectors --emit-boundaries INPUT.json OUTPUT.json")
  if args.head? == some "--boundaries" then
    return ← Boundary.run (args[1]?.getD "../../testdata/derivation_vectors/boundary_cases.json")
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
