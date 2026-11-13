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
def skippedExpected : String :=
  "{\"raw_txs\":[\"0x02\",\"0x02\",\"0x02\"],\"included\":[0,2],\"truncated_at\":null," ++
    "\"cumulative_zk_gas\":[\"0x3b538\",\"0x76a70\"],\"block_zk_gas\":\"0x76a70\"}"

#guard (run (blockVector skippedExpected)
  (smokeBlock.take 3 ++ [intrinsicLine, txEndLine 1 "skipped" "null", intrinsicLine,
   txEndLine 2])).isOk
-- A tx rejected before its intrinsic charge (its gas limit exceeds the gas the block has left)
-- is a lone skipped tx_end. A committed or aborted tx still needs its intrinsic, and no tx, not
-- even a lone skipped one, follows the aborted tx.
#guard (run (blockVector skippedExpected)
  (smokeBlock.take 3 ++ [txEndLine 1 "skipped" "null", intrinsicLine, txEndLine 2])) =
  .ok { events := 6, steps := 1, branches := [] }
#guard failsWith (run (blockVector skippedExpected)
  (smokeBlock.take 3 ++ [txEndLine 1 "committed" "\"0x0\"", intrinsicLine, txEndLine 2]))
  "event 3: a block tx starts with intrinsic, got tx_end with status committed"
#guard failsWith (run (blockVector abortExpected) (smokeBlock.take 3 ++ [txEndLine 1 "aborted" "null"]))
  "event 3: a block tx starts with intrinsic, got tx_end with status aborted"
#guard failsWith (run (blockVector abortExpected) (abortBlock ++ [txEndLine 2 "skipped" "null"]))
  "event 6: a tx after aborted tx 1"
-- A harness call to an account without code runs no step: the trace is its frame_end alone.
#guard (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x0\",\"status\":\"success\"}")
  [frameEndLine "success" "\"0x0\""]) = .ok { events := 1, steps := 0, branches := [] }

/-! ## Step model

Each `stepAgrees` guard runs `stepOutcome` on one step line copied verbatim from a committed
reth trace, `testdata/zk_gas_vectors/traces/<vector>.jsonl` (events counted from 0, as the
checker counts them), and expects that line's `gas_after`, the given outcome and branch. Every
branch has at least one guard. -/

/-- Whether `stepOutcome` on the single step event `line` gives the line's `gas_after`, outcome
`outcome` and branch `branch` and agrees with the line's `spawn`, and `branch.name` is the
constructor's name. -/
def stepAgrees (line : String) (outcome : Outcome) (branch : BranchId) : Bool :=
  match parseTrace line with
  | .ok [.step pre out] =>
    stepOutcome .unzen pre == .ok (some { gasAfter := out.gasAfter, outcome, branch }) &&
      (outcome == .newFrame) == out.spawn &&
      some branch.name == ((reprStr branch).splitOn ".").getLast?
  | _ => false

-- static.arith.add_static_oog, event 2: ADD with 2 gas cannot pay its static 3: the halt spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":1,\"gas\":\"0x2\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x26\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- static.arith.add_underflow_static_oog, event 1: ADD on one item with 2 gas: the static gas check comes before the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":1,\"gas\":\"0x2\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x26\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- static.stack.push1_overflow_static_oog, event 1024: PUSH1 on a full stack with 2 gas: the static gas check comes before the overflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":96,\"gas\":\"0x2\",\"static\":false,\"sl\":1024,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x12\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- static.env.selfbalance_static_oog, event 0: SELFBALANCE with 4 of its 5 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":71,\"gas\":\"0x4\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xd0\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- static.env.blockhash_static_oog, event 8: BLOCKHASH with 19 of its 20 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":64,\"gas\":\"0x13\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x72\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- notactivated.dupn.static_oog, event 0: DUPN with 2 of its 3 static gas: the static gas check comes before the fork gate.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":230,\"gas\":\"0x2\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1fffe\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- smoke.harness.add, event 3: STOP ends the frame keeping its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":0,\"gas\":\"0x18697\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18697\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_stop_halt
-- static.arith.add_exact_gas, event 2: ADD with exactly its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":1,\"gas\":\"0x3\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x39\",\"ok\":true,\"charged\":true}"
  .continue .static_arith_success
-- static.arith.every_opcode, event 35: ADDMOD pays its static 8 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":54,\"op\":8,\"gas\":\"0x18633\",\"static\":false,\"sl\":3,\"stack\":[\"0x9\",\"0x7\",\"0x5\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1862b\",\"spawn\":false,\"zk\":\"0x1a0\",\"ok\":true,\"charged\":true}"
  .continue .static_arith_success
-- static.arith.div_underflow, event 0: DIV on an empty stack pays its static 5 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":4,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x17c\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_arith_underflow_halt
-- static.arith.add_underflow_exact_gas, event 1: ADD on one item with exactly 3 gas pays it, then halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":1,\"gas\":\"0x3\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x39\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_arith_underflow_halt
-- static.bitwise.every_opcode, event 2: LT pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":16,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0xf\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18697\",\"spawn\":false,\"zk\":\"0x39\",\"ok\":true,\"charged\":true}"
  .continue .static_bitwise_success
-- static.bitwise.every_opcode, event 55: CLZ (active on Osaka) pays its static 5 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":82,\"op\":30,\"gas\":\"0x18609\",\"static\":false,\"sl\":1,\"stack\":[\"0xf\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18604\",\"spawn\":false,\"zk\":\"0x46\",\"ok\":true,\"charged\":true}"
  .continue .static_bitwise_success
-- static.bitwise.clz_underflow, event 0: CLZ on an empty stack pays its static 5 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":30,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x46\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_bitwise_underflow_halt
-- static.stack.every_opcode, event 0: PUSH0 pays its static 2 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}"
  .continue .static_stack_success
-- static.stack.every_opcode, event 32: PUSH32 pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":528,\"op\":127,\"gas\":\"0x18641\",\"static\":false,\"sl\":32,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863e\",\"spawn\":false,\"zk\":\"0x39\",\"ok\":true,\"charged\":true}"
  .continue .static_stack_success
-- static.stack.every_opcode, event 33: DUP1 pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":561,\"op\":128,\"gas\":\"0x1863e\",\"static\":false,\"sl\":33,\"stack\":[\"0x102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863b\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .continue .static_stack_success
-- static.stack.every_opcode, event 49: SWAP1 pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":577,\"op\":144,\"gas\":\"0x1860e\",\"static\":false,\"sl\":49,\"stack\":[\"0x102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20\",\"0x102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1860b\",\"spawn\":false,\"zk\":\"0x5d\",\"ok\":true,\"charged\":true}"
  .continue .static_stack_success
-- static.stack.every_opcode, event 65: POP pays its static 2 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":593,\"op\":80,\"gas\":\"0x185de\",\"static\":false,\"sl\":49,\"stack\":[\"0x102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x185dc\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}"
  .continue .static_stack_success
-- static.stack.pop_underflow, event 0: POP on an empty stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":80,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_pop_underflow_halt
-- static.stack.dup16_underflow, event 15: DUP16 on 15 items.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":143,\"gas\":\"0x18682\",\"static\":false,\"sl\":15,\"stack\":[\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1867f\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_dup_underflow_halt
-- static.stack.dup1_overflow, event 1024: DUP1 on a full stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":128,\"gas\":\"0x17ea0\",\"static\":false,\"sl\":1024,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17e9d\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_dup_overflow_halt
-- static.stack.swap16_underflow, event 16: SWAP16 on 16 items.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":159,\"gas\":\"0x18680\",\"static\":false,\"sl\":16,\"stack\":[\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1867d\",\"spawn\":false,\"zk\":\"0x5d\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_swap_underflow_halt
-- static.stack.push0_overflow, event 1024: PUSH0 on a full stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":95,\"gas\":\"0x17ea0\",\"static\":false,\"sl\":1024,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17e9e\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_push_overflow_halt
-- static.stack.push1_overflow_exact_gas, event 1024: PUSH1 on a full stack with exactly 3 gas pays it, then halts on the overflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":96,\"gas\":\"0x3\",\"static\":false,\"sl\":1024,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_push_overflow_halt
-- static.env.every_opcode, event 0: ADDRESS pays its static 2 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":48,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x26\",\"ok\":true,\"charged\":true}"
  .continue .static_env_success
-- static.env.every_opcode, event 11: DIFFICULTY (PREVRANDAO) pays its static 2 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":68,\"gas\":\"0x1868a\",\"static\":false,\"sl\":11,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18688\",\"spawn\":false,\"zk\":\"0x54\",\"ok\":true,\"charged\":true}"
  .continue .static_env_success
-- static.env.every_opcode, event 18: GAS pays its static 2 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":18,\"op\":90,\"gas\":\"0x1867c\",\"static\":false,\"sl\":18,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1867a\",\"spawn\":false,\"zk\":\"0x16\",\"ok\":true,\"charged\":true}"
  .continue .static_env_success
-- static.env.every_opcode, event 20: CALLDATALOAD with its input pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":53,\"gas\":\"0x18678\",\"static\":false,\"sl\":20,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18675\",\"spawn\":false,\"zk\":\"0x42\",\"ok\":true,\"charged\":true}"
  .continue .static_env_success
-- static.env.every_opcode, event 22: BLOBHASH with its input pays its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":22,\"op\":73,\"gas\":\"0x18673\",\"static\":false,\"sl\":21,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18670\",\"spawn\":false,\"zk\":\"0x27\",\"ok\":true,\"charged\":true}"
  .continue .static_env_success
-- static.env.coinbase_overflow, event 1024: COINBASE on a full stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":65,\"gas\":\"0x17ea0\",\"static\":false,\"sl\":1024,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17e9e\",\"spawn\":false,\"zk\":\"0x24\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_env_overflow_halt
-- static.env.selfbalance_exact_gas, event 0: SELFBALANCE with exactly its static 5 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":71,\"gas\":\"0x5\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x104\",\"ok\":true,\"charged\":true}"
  .continue .static_env_selfbalance_success
-- static.env.selfbalance_overflow, event 1024: SELFBALANCE on a full stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1024,\"op\":71,\"gas\":\"0x17ea0\",\"static\":false,\"sl\":1024,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17e9b\",\"spawn\":false,\"zk\":\"0x104\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_env_selfbalance_overflow_preserve
-- static.env.blockhash_exact_gas, event 1: BLOCKHASH pays only its static 20 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":64,\"gas\":\"0x47\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x33\",\"spawn\":false,\"zk\":\"0x78\",\"ok\":true,\"charged\":true}"
  .continue .static_env_blockhash_success
-- static.env.blockhash_underflow, event 0: BLOCKHASH on an empty stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":64,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1868c\",\"spawn\":false,\"zk\":\"0x78\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_env_blockhash_underflow_preserve
-- static.env.calldataload_underflow, event 0: CALLDATALOAD on an empty stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":53,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869d\",\"spawn\":false,\"zk\":\"0x42\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_calldataload_underflow_halt
-- static.env.blobhash_underflow, event 0: BLOBHASH on an empty stack.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":73,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869d\",\"spawn\":false,\"zk\":\"0x27\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_blobhash_underflow_halt
-- static.control.jump_underflow, event 0: JUMP on an empty stack pays its static 8 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":86,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18698\",\"spawn\":false,\"zk\":\"0x20\",\"ok\":true,\"charged\":true}"
  .haltKeep .static_jump_underflow_halt
-- jump.jump.valid_target, event 1: JUMP to a JUMPDEST.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":86,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x4\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":true},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x20\",\"ok\":true,\"charged\":true}"
  .continue .jump_jump_valid_target_success
-- jump.jump.dupn_immediate_target, event 1: JUMP to a 0x5b right after a DUPN byte.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":86,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x4\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":true},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x20\",\"ok\":true,\"charged\":true}"
  .continue .jump_jump_valid_target_success
-- jump.jump.push_data_target, event 1: JUMP to a 0x5b inside PUSH data.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":86,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x5\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":false},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x20\",\"ok\":true,\"charged\":true}"
  .haltKeep .jump_jump_invalid_target_halt
-- jump.jump.target_above_u64, event 1: JUMP to a target above 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":86,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x1000000000000000c\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":false},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x20\",\"ok\":true,\"charged\":true}"
  .haltKeep .jump_jump_invalid_target_halt
-- jump.jump.valid_target, event 2: The JUMPDEST pays its static 1 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":91,\"gas\":\"0x18695\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18694\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}"
  .continue .jump_jumpdest_success
-- jump.jumpi.underflow, event 1: JUMPI on one item pays its static 10 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":87,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18693\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}"
  .haltKeep .jump_jumpi_underflow_halt
-- jump.jumpi.not_taken, event 2: JUMPI with condition 0 ignores its invalid target.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":87,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":false},\"gas_after\":\"0x18690\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}"
  .continue .jump_jumpi_not_taken_success
-- jump.jumpi.taken, event 2: JUMPI with condition 1 to a JUMPDEST.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":87,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x7\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":true},\"gas_after\":\"0x18690\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}"
  .continue .jump_jumpi_taken_success
-- jump.jumpi.invalid_target, event 2: JUMPI with condition 1 to a non-JUMPDEST.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":87,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"jumpdest_valid\":false},\"gas_after\":\"0x18690\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}"
  .haltKeep .jump_jumpi_invalid_target_halt
-- exp.exp.underflow, event 1: EXP on one item pays its static 10 gas and no exponent cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":10,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x2\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18693\",\"spawn\":false,\"zk\":\"0xd2\",\"ok\":true,\"charged\":true}"
  .haltKeep .exp_exp_underflow_halt
-- exp.exp.zero_exponent, event 2: EXP with exponent 0 pays only its static 10 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":10,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18690\",\"spawn\":false,\"zk\":\"0xd2\",\"ok\":true,\"charged\":true}"
  .continue .exp_exp_zero_byte_exponent_success
-- exp.exp.one_byte_exponent_exact_gas, event 2: EXP with a one-byte exponent and exactly 10 + 50 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":10,\"gas\":\"0x3c\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0xff\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4ec\",\"ok\":true,\"charged\":true}"
  .continue .exp_exp_exponent_bytes_success
-- exp.exp.full_exponent, event 2: EXP with a 32-byte exponent pays 10 + 1,600 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":35,\"op\":10,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x3\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18050\",\"spawn\":false,\"zk\":\"0x8412\",\"ok\":true,\"charged\":true}"
  .continue .exp_exp_exponent_bytes_success
-- exp.exp.one_byte_exponent_dynamic_oog, event 2: EXP with 59 gas pays its static 10 but not the 50 for its exponent byte.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":10,\"gas\":\"0x3b\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0xff\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4d7\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .exp_exp_dynamic_oog_spend_all
-- notactivated.slotnum.halt, event 0: SLOTNUM pays its static 2 gas, then is not activated.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":75,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x1fffe\",\"ok\":true,\"charged\":true}"
  .haltKeep .notactivated_slotnum_static_then_halt
-- notactivated.dupn.halt, event 1: DUPN pays its static 3 gas, then is not activated.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":230,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x2fffd\",\"ok\":true,\"charged\":true}"
  .haltKeep .notactivated_dupn_static_then_halt
-- notactivated.swapn.halt, event 2: SWAPN pays its static 3 gas, then is not activated.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":231,\"gas\":\"0x1869c\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18699\",\"spawn\":false,\"zk\":\"0x2fffd\",\"ok\":true,\"charged\":true}"
  .haltKeep .notactivated_swapn_static_then_halt
-- notactivated.exchange.halt, event 3: EXCHANGE pays its static 3 gas, then is not activated.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":232,\"gas\":\"0x1869a\",\"static\":false,\"sl\":3,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18697\",\"spawn\":false,\"zk\":\"0x2fffd\",\"ok\":true,\"charged\":true}"
  .haltKeep .notactivated_exchange_static_then_halt
-- undefined.opcode.0x0c, event 1: The undefined opcode 0x0c has no static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":12,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869d\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .undefined_opcode_zero_gas_halt
-- undefined.invalid.0xfe, event 1: INVALID has no static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":254,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869d\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .undefined_invalid_zero_gas_halt

/-- A JUMP pre-state with `sl` stack items (target 4) and facts `facts`. -/
def jumpPre (sl : Nat) (facts : Facts) : Pre :=
  { op := 0x56, depth := 1, pc := 0, gas := 100, static := false, stackLen := sl,
    stack := (List.replicate (min sl 1) 4), mem := 0, facts }

-- The model needs the facts it reads: a JUMP whose stack holds its target but that records no
-- jumpdest_valid is an error, as is a recorded stack shorter than the model reads.
#guard failsWith (stepOutcome .unzen (jumpPre 1 {})) "jumpdest_valid"
#guard stepOutcome .unzen (jumpPre 1 { jumpdestValid := some true }) =
  .ok (some { gasAfter := 92, outcome := .continue, branch := .jump_jump_valid_target_success })
#guard failsWith (stepOutcome .unzen { jumpPre 2 {} with op := 0x57 }) "stack"
-- An underflowing JUMP reads no fact.
#guard stepOutcome .unzen (jumpPre 0 {}) =
  .ok (some { gasAfter := 92, outcome := .haltKeep, branch := .static_jump_underflow_halt })
-- Opcodes of the later categories are not modeled yet: SLOAD, MLOAD, CALL.
#guard [0x54, 0x51, 0xf1].all fun op =>
  stepOutcome .unzen { jumpPre 0 {} with op } == .ok none
-- The smoke harness trace with the step model: every step is modeled.
#guard run smokeHarnessVector smokeHarness (requireModeled stepModel) =
  .ok { events := 5, steps := 4,
        branches := ["static_stack_success", "static_stack_success", "static_arith_success",
                     "static_stop_halt"] }
