import ZkGasTraces.Json
import ZkGasModel.MeterVectors

/-!
# Deterministic meter conformance corpus

Inputs are enumerated here and expectations come only from the checked model. JSON contains
snapshots of production meter API calls, not client-generated golden values or EVM execution.
-/
namespace TaikoSpec.ZkGas.Traces.MeterExport

open MeterVectors

/-- A generated input; its expected snapshots are computed when it is serialized. -/
structure Vector where
  id : String
  blockLimit : Nat
  actions : List Action

/-- Represent a u64 quantity using the shared canonical hexadecimal encoding. -/
def hex (n : Nat) : Lean.Json := .str (hexString n)

/-- Encode a full 20-byte address, including its leading zeros. -/
def addressJson (n : Nat) : Lean.Json :=
  let digits := (hexString n).toList.drop 2
  .str ("0x" ++ String.ofList (List.replicate (40 - digits.length) '0' ++ digits))

/-- The schema's tagged input action; no expectation is accepted as input. -/
def actionJson : Action → Lean.Json
  | .opcode op gas =>
    .mkObj [("kind", .str "opcode"), ("op", .num op), ("gas", hex gas)]
  | .spawn op => .mkObj [("kind", .str "spawn"), ("op", .num op)]
  | .precompile address gas =>
    .mkObj [("kind", .str "precompile"), ("address", addressJson address), ("gas", hex gas)]
  | .intrinsic => .mkObj [("kind", .str "intrinsic")]
  | .commit => .mkObj [("kind", .str "commit")]
  | .reset => .mkObj [("kind", .str "reset")]

/-- Observable usage after an action, with no duplicated cost formula in the exporter. -/
def snapshotJson (out : Snapshot) : Lean.Json :=
  .mkObj [("ok", .bool out.ok), ("tx_zk", hex out.txZk), ("block_zk", hex out.blockZk)]

/-- Compute every expectation through the model with only the block limit overridden. -/
def vectorJson (v : Vector) : Lean.Json :=
  let schedule := { unzen with blockLimit := v.blockLimit }
  .mkObj [("id", .str v.id), ("block_limit", hex v.blockLimit),
          ("actions", .arr (v.actions.map actionJson).toArray),
          ("expected", .arr ((runActions schedule v.actions).map snapshotJson).toArray)]

/-- Per-multiplier boundary inputs: zero, exact/short budgets, reset and both addition paths. -/
def chargeCases (stem : String) (mult : Nat) (make : Nat → Action) : List Vector :=
  let cost := 3 * mult
  let ordinary :=
    [{ id := stem ++ ".zero", blockLimit := 0, actions := [make 0, .commit, make 0] },
     { id := stem ++ ".exact", blockLimit := cost,
       actions := [make 3, .commit, make 0, make 1] },
     { id := stem ++ ".reset", blockLimit := cost,
       actions := [make 3, make 1, .reset, make 3, .commit] }]
  if mult = 0 then
    ordinary ++ [{ id := stem ++ ".max_zero", blockLimit := 0,
                   actions := [make maxU64, .commit, make maxU64] }]
  else
    let boundary := maxU64 / mult
    let cases :=
      [{ id := stem ++ ".short", blockLimit := cost - 1,
         actions := [make 3, .reset, make 1, .commit] },
       { id := stem ++ ".block_add_overflow", blockLimit := maxU64,
         actions := [make boundary, .commit, make 1] },
       { id := stem ++ ".tx_add_overflow", blockLimit := maxU64,
         actions := [make boundary, make 1, .reset, make 1, .commit] }]
    ordinary ++ cases ++
      if mult > 1 then
        [{ id := stem ++ ".mul_overflow", blockLimit := maxU64,
           actions := [make (boundary + 1), .reset, make 1, .commit] }]
      else []

/-- Exercise each fixed spawn estimate at a fitting budget, one below it, and after reset. -/
def spawnCases (op : Nat) : List Vector :=
  let action := Action.spawn op
  let cost := (actionAmount unzen action).getD 0
  let stem := "spawn." ++ hexString op
  [{ id := stem ++ ".exact", blockLimit := cost, actions := [action, .commit, action] },
   { id := stem ++ ".short", blockLimit := cost - 1, actions := [action, .reset] },
   { id := stem ++ ".reset", blockLimit := cost,
     actions := [action, action, .reset, action, .commit] }]

/-- All opcode/precompile entries and API interactions, with high-byte address alias protection. -/
def vectors : List Vector :=
  let opcodes := (List.range 256).flatMap fun op ↦
    chargeCases ("opcode." ++ hexString op) (unzen.opcodeMult.getD op failsafeMultiplier)
      (Action.opcode op)
  let addresses := (unzen.precompileMult.map Prod.fst) ++ [0x12, 2 ^ 159 + 2]
  let precompiles := addresses.flatMap fun address ↦
    chargeCases ("precompile." ++ hexString address) (precompileMult unzen address)
      (Action.precompile address)
  let intrinsic := unzen.txIntrinsic
  opcodes ++ precompiles ++ ([0xf0, 0xf1, 0xf2, 0xf4, 0xf5, 0xfa].flatMap spawnCases) ++
    [{ id := "intrinsic.exact", blockLimit := intrinsic,
       actions := [.intrinsic, .commit, .intrinsic] },
     { id := "intrinsic.short", blockLimit := intrinsic - 1, actions := [.intrinsic, .reset] },
     { id := "intrinsic.reset", blockLimit := intrinsic,
       actions := [.intrinsic, .intrinsic, .reset, .intrinsic, .commit] },
     { id := "intrinsic.two_transactions", blockLimit := 2 * intrinsic,
       actions := [.intrinsic, .commit, .intrinsic, .commit, .intrinsic, .reset] },
     { id := "mixed.transaction", blockLimit := unzen.blockLimit,
       actions := [.intrinsic, .opcode 0x01 3, .precompile 2 5, .spawn 0xf1, .commit,
                   .intrinsic, .reset, .opcode 0x01 1, .commit] },
     { id := "addition.block_and_transaction", blockLimit := maxU64,
       actions := [.opcode 0x01 1, .commit, .opcode 0x01 1,
                   .opcode 0x01 (maxU64 / 19 - 1), .reset,
                   .opcode 0x01 (maxU64 / 19 - 1), .commit, .opcode 0x01 1] },
     { id := "budget.block_and_transaction", blockLimit := 100,
       actions := [.opcode 0x01 3, .commit, .opcode 0x01 2, .opcode 0x01 1,
                   .reset, .opcode 0x01 2, .commit] },
     { id := "empty.transaction", blockLimit := 0,
       actions := [.commit, .reset, .commit, .opcode 0 maxU64, .commit] }]

/-- Stable JSON bytes, one vector per line; both inputs and expectations are generated in Lean. -/
def corpusText : String :=
  "{\n  \"schema_version\": 1,\n  \"schedule\": \"unzen\",\n  \"vectors\": [\n" ++
  ",\n".intercalate (vectors.map fun v ↦ "    " ++ (vectorJson v).compress) ++ "\n  ]\n}\n"

end TaikoSpec.ZkGas.Traces.MeterExport
