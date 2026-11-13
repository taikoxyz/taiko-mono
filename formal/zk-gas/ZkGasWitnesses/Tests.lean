import ZkGasModel
import ZkGasTraces.Check

/-!
# Table and metering regressions

Executable `#guard` checks of the generated Unzen and revm tables and of the meter. They run
during compilation and are not kernel proofs. The table values are spot checks against
`packages/protocol/docs/zk_gas_spec.md` (Appendix B) and revm's Osaka gas table.
-/

open TaikoSpec.ZkGas

-- Tables: ADD and PUSH1 multipliers, point_evaluation and an unlisted precompile (fail-safe).
#guard unzen.opcodeMult[0x01]! = 19
#guard unzen.opcodeMult[0x60]! = 9
#guard precompileMult unzen 0x0a = 859
#guard precompileMult unzen 0x12 = 65535
-- revm static gas: ADD is 3; CREATE's table entry is 0 (revm charges CREATE's base dynamically).
#guard staticGas 0x01 = 3 ∧ staticGas 0xf0 = 0

-- Meter: a transaction that fits returns its total, intrinsic charge included.
#guard meterTx unzen 0 [243000, 111] = some 243111
-- A charge one above what the block has left aborts the transaction.
#guard meterTx unzen 99757001 [243000] = none
-- The aborted second transaction adds nothing to the block total.
#guard (meterBlock unzen [[243000], [243000, 99757001]]).2 = 243000

-- Boundaries: a total exactly at the block limit fits; the results end at the abort, so a
-- third transaction is not executed.
#guard meterTx unzen 99757000 [243000] = some 243000
#guard (meterBlock unzen [[243000], [243000, 99757001], [243000]]) = ([some 243000, none], 243000)
-- Table shape: 256 opcode multipliers, the fail-safe for an undefined opcode, spawn estimates
-- only for spawn opcodes, and revm's stack inputs.
#guard unzen.opcodeMult.size = 256 ∧ unzen.opcodeMult[0x0c]! = 65535
#guard unzen.spawnEstimate 0xf1 = some 12500 ∧ unzen.spawnEstimate 0x01 = none
#guard inputs 0xf1 = 7 ∧ inputs 0x01 = 2 ∧ inputs 0x0c = 0

/-! ## Trace parser and checker

Fixture traces are written inline. `smokeBlock` and `smokeHarness` are the traces of the corpus
vectors `smoke.block.transfer` (the anchor's STOP, then a plain transfer) and `smoke.harness.add`
(PUSH1 1, PUSH1 2, ADD, STOP), checked against those vectors' committed expected values. -/

open TaikoSpec.ZkGas.Traces

deriving instance DecidableEq for Except

/-- Whether `r` failed with a message containing `needle`. -/
def failsWith (r : Except String α) (needle : String) : Bool :=
  match r with
  | .error e => e.contains needle
  | .ok _ => false

/-- A trace step line. `stack` and `facts` are spliced into the array and the object. -/
def stepLine (d pc op : Nat) (gas : String) (sl : Nat) (stack : String) (gasAfter zk : String)
    (facts : String := "") (spawn : Bool := false) (ok : Bool := true) (charged : Bool := true) :
    String :=
  "{\"e\":\"step\",\"d\":" ++ toString d ++ ",\"pc\":" ++ toString pc ++ ",\"op\":" ++
    toString op ++ ",\"gas\":\"" ++ gas ++ "\",\"static\":false,\"sl\":" ++ toString sl ++
    ",\"stack\":[" ++ stack ++ "],\"mem\":\"0x0\",\"facts\":{" ++ facts ++ "},\"gas_after\":\"" ++
    gasAfter ++ "\",\"spawn\":" ++ toString spawn ++ ",\"zk\":\"" ++ zk ++ "\",\"ok\":" ++
    toString ok ++ ",\"charged\":" ++ toString charged ++ "}"

def intrinsicLine (zk : String := "0x3b538") (ok : Bool := true) : String :=
  "{\"e\":\"intrinsic\",\"zk\":\"" ++ zk ++ "\",\"ok\":" ++ toString ok ++ "}"

def txEndLine (index : Nat) (status : String := "committed") (txZk : String := "\"0x3b538\"") :
    String :=
  "{\"e\":\"tx_end\",\"index\":" ++ toString index ++ ",\"status\":\"" ++ status ++
    "\",\"tx_zk\":" ++ txZk ++ "}"

def frameEndLine (status : String := "success") (frameZk : String := "\"0x6f\"") : String :=
  "{\"e\":\"frame_end\",\"status\":\"" ++ status ++ "\",\"frame_zk\":" ++ frameZk ++ "}"

/-- A precompile event of sha256 (0x02, multiplier 10). -/
def sha256Line (supplied left : String) (success : Bool) (zk : String) : String :=
  "{\"e\":\"precompile\",\"addr\":\"0x0000000000000000000000000000000000000002\",\"supplied\":\"" ++
    supplied ++ "\",\"left\":\"" ++ left ++ "\",\"success\":" ++ toString success ++
    ",\"zk\":\"" ++ zk ++ "\",\"ok\":true}"

/-- A JSON Lines file: one line per event, each ending in a newline. -/
def lines (ls : List String) : String := String.join (ls.map (· ++ "\n"))

def blockVector (expected : String) : String :=
  "{\"layer\":\"block\",\"input\":{},\"expected\":" ++ expected ++ "}"

def harnessVector (limit expected : String) : String :=
  "{\"layer\":\"harness\",\"input\":{\"zk_block_limit\":\"" ++ limit ++ "\"},\"expected\":" ++
    expected ++ "}"

/-- Checks the fixture trace `events` against `vector`, by default with every step unmodeled. -/
def run (vector : String) (events : List String) (model : Model := unmodeled) :
    Except String Report :=
  checkVectorText vector (lines events) model

def smokeBlockExpected : String :=
  "{\"raw_txs\":[\"0x02\",\"0x02\"],\"included\":[0,1],\"truncated_at\":null," ++
    "\"cumulative_zk_gas\":[\"0x3b538\",\"0x76a70\"],\"block_zk_gas\":\"0x76a70\"}"

def anchorStop : String := stepLine 1 0 0x00 "0xeefe8" 0 "" "0xeefe8" "0x0"

def smokeBlock : List String :=
  [intrinsicLine, anchorStop, txEndLine 0, intrinsicLine, txEndLine 1]

def push1 (pc sl : Nat) (gas gasAfter : String) : String :=
  stepLine 1 pc 0x60 gas sl "" gasAfter "0x1b"

def addStep (ok : Bool := true) : String :=
  stepLine 1 4 0x01 "0x1869a" 2 "\"0x2\",\"0x1\"" "0x18697" "0x39" (ok := ok)

def smokeHarness : List String :=
  [push1 0 0 "0x186a0" "0x1869d", push1 2 1 "0x1869d" "0x1869a", addStep,
   stepLine 1 5 0x00 "0x18697" 1 "" "0x18697" "0x0", frameEndLine]

def smokeHarnessVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x6f\",\"status\":\"success\"}"

/-- A model that charges exactly each opcode's static gas (plus `extra`), right for the smoke
harness trace when `extra` is 0. -/
def staticModel (extra : Nat := 0) : Model :=
  fun p => .ok (some (p.gas - staticGas p.op - extra, false, "static"))

-- Canonical hex: zero is `0x0`; leading zeros, uppercase and a bare `0x` are rejected;
-- 2^256 - 1 parses.
#guard parseHex "0x0" = .ok 0
#guard parseHex "0x00" matches .error _
#guard parseHex "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" = .ok (2^256 - 1)
#guard parseHex "0x1b" = .ok 27 ∧ parseHex "0x186a0" = .ok 100000
#guard failsWith (parseHex "0x01") "canonical" ∧ failsWith (parseHex "0xAB") "canonical"
#guard failsWith (parseHex "0x") "canonical" ∧ failsWith (parseHex "12") "canonical"

-- Records: unknown events, missing and unknown fields, JSON integers, stack shape and facts.
#guard (parseTrace "{\"e\":\"bogus\"}") matches .error _
#guard failsWith (parseTrace "{\"e\":\"bogus\"}") "event 0: unknown event bogus"
#guard failsWith (parseTrace "{\"e\":\"intrinsic\",\"zk\":\"0x3b538\"}") "missing field ok"
#guard failsWith (parseTrace "{\"e\":\"intrinsic\",\"zk\":\"0x3b538\",\"ok\":true,\"x\":1}")
  "unknown field x"
#guard failsWith (parseTrace "[1]") "object"
#guard failsWith (parseTrace "") "no events"
#guard failsWith (parseTrace (lines [intrinsicLine, ""])) "event 1"
#guard failsWith (parseTrace (anchorStop.replace "\"pc\":0" "\"pc\":\"0x0\"")) "pc"
#guard failsWith (parseTrace (anchorStop.replace "\"pc\":0" "\"pc\":1.5")) "pc"
#guard parseTrace (lines [intrinsicLine, txEndLine 0]) =
  .ok [.intrinsic 243000 true, .txEnd 0 .committed 243000]
-- ADD reads two stack items; a stack word above 2^256 - 1 is rejected.
#guard failsWith (parseTrace (stepLine 1 4 0x01 "0x1869a" 2 "\"0x2\"" "0x18697" "0x39")) "stack"
#guard failsWith (parseTrace (stepLine 1 4 0x01 "0x1869a" 2
  "\"0x2\",\"0x10000000000000000000000000000000000000000000000000000000000000000\"" "0x18697" "0x39"))
  "stack"
-- JUMP records jumpdest_valid; PUSH1 records no facts; an underflowing JUMP records none.
#guard failsWith (parseTrace (stepLine 1 0 0x56 "0x64" 1 "\"0x5\"" "0x5c" "0x20"))
  "missing fact jumpdest_valid"
#guard parseTrace (stepLine 1 0 0x56 "0x64" 1 "\"0x5\"" "0x5c" "0x20" "\"jumpdest_valid\":true") =
  .ok [.step { op := 0x56, depth := 1, pc := 0, gas := 100, static := false, stackLen := 1,
               stack := [5], mem := 0, facts := { jumpdestValid := some true } }
             { gasAfter := 92, spawn := false, zk := 32, ok := true, charged := true }]
#guard failsWith (parseTrace (stepLine 1 0 0x60 "0x64" 0 "" "0x61" "0x1b" "\"slot_warm\":true"))
  "fact slot_warm not allowed"
#guard failsWith (parseTrace (stepLine 1 0 0x56 "0x64" 0 "" "0x5c" "0x20" "\"jumpdest_valid\":true"))
  "fact jumpdest_valid not allowed"
#guard (parseTrace (stepLine 1 0 0x56 "0x64" 0 "" "0x5c" "0x20")).isOk
-- A CALL target without an EIP-7702 delegation records delegate_warm null.
#guard ((parseTrace (stepLine 1 0 0xf1 "0x186a0" 7
    "\"0xffff\",\"0x2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"" "0x1" "0x3d090"
    "\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null" (spawn := true))).map
  fun es => es.map fun | .step p _ => some p.facts | _ => none) =
  .ok [some { accountWarm := some true, accountEmpty := some false, delegateWarm := some none }]

-- The smoke traces pass with every step unmodeled, and fail without that allowance.
#guard run (blockVector smokeBlockExpected) smokeBlock = .ok { events := 5, steps := 1, branches := [] }
#guard run smokeHarnessVector smokeHarness = .ok { events := 5, steps := 4, branches := [] }
#guard failsWith (run smokeHarnessVector smokeHarness (requireModeled unmodeled))
  "event 0: opcode 0x60 is not modeled"
-- A model is consulted on every step; its gas_after must match the trace.
#guard run smokeHarnessVector smokeHarness (requireModeled (staticModel 0)) =
  .ok { events := 5, steps := 4, branches := ["static", "static", "static", "static"] }
#guard failsWith (run smokeHarnessVector smokeHarness (staticModel 1)) "event 0: model branch static"

-- Intrinsic: the first event of every block tx, charged exactly the schedule's intrinsic.
#guard failsWith (run (blockVector smokeBlockExpected)
  [intrinsicLine "0x3b539", anchorStop, txEndLine 0 "committed" "\"0x3b539\"", intrinsicLine,
   txEndLine 1]) "event 0: intrinsic"
#guard failsWith (run (blockVector smokeBlockExpected)
  [anchorStop, txEndLine 0, intrinsicLine, txEndLine 1]) "event 0: a block tx starts with intrinsic"
-- The trace's totals must agree with each other and with the vector's expected values.
#guard failsWith (run (blockVector (smokeBlockExpected.replace "0x76a70\"]" "0x76a71\"]"))
  smokeBlock) "cumulative_zk_gas"
#guard failsWith (run (blockVector smokeBlockExpected)
  [intrinsicLine, anchorStop, txEndLine 0 "committed" "\"0x3b539\"", intrinsicLine, txEndLine 1])
  "event 2: tx_zk"
#guard failsWith (run smokeHarnessVector (smokeHarness.take 4 ++ [frameEndLine "success" "\"0x70\""]))
  "event 4: frame_zk"
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x70\",\"status\":\"success\"}")
  smokeHarness) "frame_zk_gas"
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x6f\",\"status\":\"revert\"}")
  smokeHarness) "status"
-- Step charges: (gas - gas_after) * multiplier, or the spawn estimate for a spawn step.
#guard failsWith (run smokeHarnessVector
  (smokeHarness.set 0 (stepLine 1 0 0x60 "0x186a0" 0 "" "0x1869d" "0x1c"))) "event 0: zk"
#guard failsWith (run smokeHarnessVector
  (smokeHarness.set 0 (stepLine 1 0 0x60 "0x186a0" 0 "" "0x1869d" "0x1b" (spawn := true))))
  "event 0: spawn"
#guard failsWith (run smokeHarnessVector
  (smokeHarness.set 0 (stepLine 1 0 0x60 "0x186a0" 0 "" "0x186a1" "0x0"))) "event 0: gas_after"

-- A CALL spawn step charges its estimate (12500 * 20), the precompile it runs follows it, and
-- the frame continues at the same depth.
def callStep (spawn : Bool := true) (gasAfter : String := "0x1") : String :=
  stepLine 1 0 0xf1 "0x186a0" 7 "\"0xffff\",\"0x2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\""
    gasAfter "0x3d090" "\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null"
    (spawn := spawn)

def callHarness : List String :=
  [callStep, sha256Line "0xffff" "0xffc3" true "0x258",
   stepLine 1 1 0x00 "0x186a0" 1 "" "0x186a0" "0x0", frameEndLine "success" "\"0x3d2e8\""]

def callVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x3d2e8\",\"status\":\"success\"}"

#guard (run callVector callHarness).isOk
-- A direct call to a precompile has no CALL step.
#guard (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x258\",\"status\":\"success\"}")
  [sha256Line "0x186a0" "0x18664" true "0x258", frameEndLine "success" "\"0x258\""]).isOk
-- Precompile charges: (supplied - left) * multiplier; a failed call leaves no gas.
#guard failsWith (run callVector (callHarness.set 1 (sha256Line "0xffff" "0xffc3" true "0x259")))
  "event 1: zk"
#guard failsWith (run callVector (callHarness.set 1 (sha256Line "0xffff" "0xffc3" false "0x258")))
  "event 1: a failed precompile"
-- Order: a precompile follows a CALL-family spawn step, depth rises only after a spawn step,
-- and a harness trace ends with frame_end.
#guard failsWith (run callVector (callHarness.set 0 (callStep false "0x155cc"))) "event 1: precompile"
#guard failsWith (run smokeHarnessVector
  (smokeHarness.set 1 (stepLine 2 2 0x60 "0x1869d" 1 "" "0x1869a" "0x1b"))) "event 1: depth"
#guard failsWith (run smokeHarnessVector (smokeHarness.take 4)) "frame_end"
#guard failsWith (run smokeHarnessVector (intrinsicLine :: smokeHarness)) "event 0"
#guard failsWith (run (blockVector smokeBlockExpected)
  [intrinsicLine, anchorStop, txEndLine 0, intrinsicLine, txEndLine 2]) "event 4: index"
#guard failsWith (run (blockVector smokeBlockExpected) (smokeBlock.take 4)) "tx_end"

-- Meter verdicts: the charge that exceeds the limit is rejected (ok false) and ends the frame;
-- for zk_limit only the status is compared.
def zkLimitVector : String :=
  harnessVector "0x6e" "{\"frame_zk_gas\":null,\"status\":\"zk_limit\"}"

def zkLimitHarness : List String :=
  [push1 0 0 "0x186a0" "0x1869d", push1 2 1 "0x1869d" "0x1869a", addStep false,
   frameEndLine "zk_limit" "null"]

#guard (run zkLimitVector zkLimitHarness).isOk
#guard failsWith (run zkLimitVector (zkLimitHarness.set 2 addStep)) "event 2: ok"
#guard failsWith (run smokeHarnessVector (smokeHarness.set 2 (addStep false))) "event 2: ok"
#guard failsWith (run zkLimitVector
  (zkLimitHarness.take 3 ++ [stepLine 1 5 0x00 "0x18697" 1 "" "0x18697" "0x0",
    frameEndLine "zk_limit" "null"])) "event 3"

-- Block abort: the second tx's step exceeds what the block has left. The block keeps the
-- anchor's zk gas and ends at the aborted tx.
def abortBlock : List String :=
  [intrinsicLine, anchorStop, txEndLine 0, intrinsicLine,
   stepLine 1 0 0x01 "0x989680" 2 "\"0x1\",\"0x2\"" "0x0" "0xb532b80" (ok := false),
   txEndLine 1 "aborted" "null"]

def abortExpected : String :=
  "{\"raw_txs\":[\"0x02\",\"0x02\",\"0x02\"],\"included\":[0],\"truncated_at\":1," ++
    "\"cumulative_zk_gas\":[\"0x3b538\"],\"block_zk_gas\":\"0x3b538\"}"

#guard (run (blockVector abortExpected) abortBlock).isOk
#guard failsWith (run (blockVector abortExpected)
  (abortBlock.set 5 (txEndLine 1 "committed" "\"0xb5684b8\""))) "event 5"
#guard failsWith (run (blockVector (abortExpected.replace "\"truncated_at\":1" "\"truncated_at\":null"))
  abortBlock) "truncated_at"
#guard failsWith (run (blockVector abortExpected) (abortBlock ++ [intrinsicLine, txEndLine 2]))
  "event 6"
-- A tx skipped as invalid adds nothing and does not end the block.
#guard (run (blockVector ("{\"raw_txs\":[\"0x02\",\"0x02\",\"0x02\"],\"included\":[0,2]," ++
    "\"truncated_at\":null,\"cumulative_zk_gas\":[\"0x3b538\",\"0x76a70\"]," ++
    "\"block_zk_gas\":\"0x76a70\"}"))
  (smokeBlock.take 3 ++ [intrinsicLine, txEndLine 1 "skipped" "null", intrinsicLine,
   txEndLine 2])).isOk
