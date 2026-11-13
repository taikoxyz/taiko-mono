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

/-- A model that charges exactly each opcode's static gas (plus `extra`) and ends the frame
successfully at STOP, right for the smoke harness trace when `extra` is 0. -/
def staticModel (extra : Nat := 0) : Model :=
  fun p => .ok (some (p.gas - staticGas p.op - extra, if p.op = 0 then .success else .continue,
    "static"))

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
branch has at least one guard; `memory_step_underflow_halt`, which no corpus step reaches, has
guards on constructed pre-states after the trace lines. -/

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
-- smoke.harness.add, event 3: STOP ends the frame successfully keeping its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":0,\"gas\":\"0x18697\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18697\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .static_stop_halt
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

-- log.log0.static_oog, event 3: LOG0 with 374 of its 375 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":160,\"gas\":\"0x176\",\"static\":false,\"sl\":2,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x462\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- log.static_frame.log0_static_oog, event 9: LOG0 in a static frame with 374 gas: the static gas comes before the static-context check.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":160,\"gas\":\"0x176\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x462\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- memory.mload.expand_exact_gas, event 7: MLOAD at 0xfc00 with exactly its static 3 gas and the expansion from 0x8020 to 0xfc20 bytes.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":81,\"gas\":\"0x22a8\",\"static\":false,\"sl\":1,\"stack\":[\"0xfc00\"],\"mem\":\"0x8020\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x26fd0\",\"ok\":true,\"charged\":true}"
  .continue .memory_access_expansion_success
-- memory.mload.expand_exact_gas, event 4: MLOAD inside current memory pays only its static 3 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":81,\"gas\":\"0x22b0\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x8020\",\"facts\":{},\"gas_after\":\"0x22ad\",\"spawn\":false,\"zk\":\"0x36\",\"ok\":true,\"charged\":true}"
  .continue .memory_access_expansion_success
-- memory.mstore8.expand_exact_gas, event 8: MSTORE8 with exactly its static 3 gas and the expansion of the one word its byte needs.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":14,\"op\":83,\"gas\":\"0x51c\",\"static\":false,\"sl\":2,\"stack\":[\"0x2c40\",\"0xef\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x3318\",\"ok\":true,\"charged\":true}"
  .continue .memory_access_expansion_success
-- memory.mstore.expand_memory_oog, event 8: MSTORE 1 gas short of its expansion keeps the gas after its static 3.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":14,\"op\":82,\"gas\":\"0xc63\",\"static\":false,\"sl\":2,\"stack\":[\"0x5a00\",\"0xef\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0xc60\",\"spawn\":false,\"zk\":\"0x57\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_access_memory_oog_preserve
-- memory.mload.size_above_cap, event 1: MLOAD whose memory size is above 0x1FFFFFFFE0 bytes: the saturated cost cannot be paid.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":81,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x2000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x36\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_access_memory_oog_preserve
-- memory.mload.word_rounding_above_u64, event 1: MLOAD whose size rounds up to 2^64 bytes.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":81,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0xffffffffffffffdf\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x36\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_access_memory_oog_preserve
-- memory.mstore8.offset_above_u64, event 2: MSTORE8 at offset 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":83,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x10000000000000000\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18697\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_access_offset_above_u64_preserve
-- memory.mcopy.size_above_u64, event 3: MCOPY of 2^64 bytes halts before its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":94,\"gas\":\"0x18699\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0xc\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_mcopy_size_above_u64_preserve
-- memory.mcopy.copy_oog, event 11: MCOPY that cannot pay 3 gas per word spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":94,\"gas\":\"0x4a\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x1000\",\"0x300\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x128\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .memory_mcopy_copy_oog_spend_all
-- memory.mcopy.dst_above_u64_copy_oog, event 3: MCOPY to dst 2^64 that cannot pay its copy cost: the copy cost comes first.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":94,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x10000000000000000\",\"0x0\",\"0x1000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x61a60\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .memory_mcopy_copy_oog_spend_all
-- memory.mcopy.zero_size_huge_operands, event 3: MCOPY of length 0 with dst and src 2^256 - 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":67,\"op\":94,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0xc\",\"ok\":true,\"charged\":true}"
  .continue .memory_mcopy_zero_size_no_expansion
-- memory.mcopy.dst_above_u64, event 3: MCOPY to dst 2^64 halts after its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":94,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x10000000000000000\",\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18692\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_mcopy_dst_above_u64_preserve
-- memory.mcopy.src_above_u64, event 3: MCOPY from src 2^64 halts after its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":94,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x10000000000000000\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18692\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_mcopy_src_above_u64_preserve
-- memory.mcopy.expand_memory_oog, event 11: MCOPY that pays its copy cost but not its expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":94,\"gas\":\"0x236\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x1000\",\"0x300\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x1eb\",\"spawn\":false,\"zk\":\"0x12c\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_mcopy_memory_oog_preserve
-- memory.mcopy.expand_exact_gas, event 11: MCOPY with exactly its static, copy and expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":94,\"gas\":\"0x237\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x1000\",\"0x300\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x8dc\",\"ok\":true,\"charged\":true}"
  .continue .memory_mcopy_expansion_success
-- memory.mcopy.overlap, event 6: MCOPY of 32 bytes from offset 0 to offset 1 pays one word of copy cost and one word of expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":40,\"op\":94,\"gas\":\"0x1868d\",\"static\":false,\"sl\":3,\"stack\":[\"0x1\",\"0x0\",\"0x20\"],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x18684\",\"spawn\":false,\"zk\":\"0x24\",\"ok\":true,\"charged\":true}"
  .continue .memory_mcopy_expansion_success
-- keccak.keccak256.size_above_u64, event 2: KECCAK256 of 2^64 bytes halts before its word cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":32,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1867d\",\"spawn\":false,\"zk\":\"0x3a2\",\"ok\":true,\"charged\":true}"
  .haltKeep .keccak_keccak256_size_above_u64_preserve
-- keccak.keccak256.word_oog, event 10: KECCAK256 that cannot pay 6 gas per word spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":32,\"gas\":\"0x31d\",\"static\":false,\"sl\":2,\"stack\":[\"0x40\",\"0x1000\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x6083\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .keccak_keccak256_word_oog_spend_all
-- keccak.keccak256.offset_above_u64_word_oog, event 2: KECCAK256 at offset 2^64 that cannot pay its word cost: the word cost comes first.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":32,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x10000000000000000\",\"0x100000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x2f4ca6\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .keccak_keccak256_word_oog_spend_all
-- keccak.keccak256.zero_size_huge_offset, event 2: KECCAK256 of length 0 at offset 2^256 - 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":34,\"op\":32,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1867d\",\"spawn\":false,\"zk\":\"0x3a2\",\"ok\":true,\"charged\":true}"
  .continue .keccak_keccak256_zero_size_no_expansion
-- keccak.keccak256.offset_above_u64, event 2: KECCAK256 at offset 2^64 halts after its word cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":32,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x10000000000000000\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18676\",\"spawn\":false,\"zk\":\"0x45c\",\"ok\":true,\"charged\":true}"
  .haltKeep .keccak_keccak256_offset_above_u64_preserve
-- keccak.keccak256.expand_memory_oog, event 10: KECCAK256 that pays its word cost but not its expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":32,\"gas\":\"0x4be\",\"static\":false,\"sl\":2,\"stack\":[\"0x40\",\"0x1000\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x1a0\",\"spawn\":false,\"zk\":\"0x60a2\",\"ok\":true,\"charged\":true}"
  .haltKeep .keccak_keccak256_memory_oog_preserve
-- keccak.keccak256.end_above_u64, event 2: KECCAK256 whose offset + len passes 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":32,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0xffffffffffffffff\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18676\",\"spawn\":false,\"zk\":\"0x45c\",\"ok\":true,\"charged\":true}"
  .haltKeep .keccak_keccak256_memory_oog_preserve
-- keccak.keccak256.expand_exact_gas, event 10: KECCAK256 with exactly its static, word and expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":32,\"gas\":\"0x4bf\",\"static\":false,\"sl\":2,\"stack\":[\"0x40\",\"0x1000\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x9321\",\"ok\":true,\"charged\":true}"
  .continue .keccak_keccak256_expansion_success
-- copy.codecopy.size_above_u64, event 3: CODECOPY of 2^64 bytes halts before its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":57,\"gas\":\"0x18699\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0x24\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_datacopy_size_above_u64_preserve
-- copy.calldatacopy.copy_oog, event 11: CALLDATACOPY that cannot pay 3 gas per word spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":17,\"op\":55,\"gas\":\"0x1e2\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x1400\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x187a\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_datacopy_copy_oog_spend_all
-- copy.codecopy.size_above_cap_copy_oog, event 3: CODECOPY above the memory cap that cannot pay its copy cost: the copy cost comes first.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":57,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x2000000000\",\"0x0\",\"0x1000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x124f20\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_datacopy_copy_oog_spend_all
-- copy.codecopy.zero_size_huge_offset, event 3: CODECOPY of length 0 at memory offset 2^256 - 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":67,\"op\":57,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x24\",\"ok\":true,\"charged\":true}"
  .continue .copy_datacopy_zero_size_no_expansion
-- copy.calldatacopy.offset_above_u64, event 3: CALLDATACOPY to memory offset 2^64 halts after its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":55,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x10000000000000000\",\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18692\",\"spawn\":false,\"zk\":\"0x4e\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_datacopy_offset_above_u64_preserve
-- copy.codecopy.expand_memory_oog, event 11: CODECOPY that pays its copy cost but not its expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":17,\"op\":57,\"gas\":\"0x3f5\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x1400\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x212\",\"spawn\":false,\"zk\":\"0x16a4\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_datacopy_memory_oog_preserve
-- copy.calldatacopy.expand_exact_gas, event 11: CALLDATACOPY with exactly its static, copy and expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":17,\"op\":55,\"gas\":\"0x3f6\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x1400\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x337e\",\"ok\":true,\"charged\":true}"
  .continue .copy_datacopy_expansion_success
-- copy.codecopy.expand_exact_gas, event 11: CODECOPY with exactly its static, copy and expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":17,\"op\":57,\"gas\":\"0x3f6\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x1400\"],\"mem\":\"0x60\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x2f88\",\"ok\":true,\"charged\":true}"
  .continue .copy_datacopy_expansion_success
-- copy.returndatacopy.size_above_u64, event 17: RETURNDATACOPY of 2^64 bytes halts before the range check.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":22,\"op\":62,\"gas\":\"0x17c4f\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x17c4c\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_returndatacopy_size_above_u64_preserve
-- copy.returndatacopy.range_past_end, event 17: RETURNDATACOPY of a range ending one byte past the return data.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":62,\"gas\":\"0x17c4e\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x21\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x17c4b\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_returndatacopy_out_of_bounds_preserve
-- copy.returndatacopy.out_of_bounds_copy_unpayable, event 17: An out-of-bounds RETURNDATACOPY whose copy cost could not be paid: the range check comes first.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":62,\"gas\":\"0x4\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x21\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x1\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_returndatacopy_out_of_bounds_preserve
-- copy.returndatacopy.copy_oog, event 25: RETURNDATACOPY of an in-bounds range that cannot pay its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":27,\"op\":62,\"gas\":\"0x8\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x40\"],\"mem\":\"0x60\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x50\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_returndatacopy_copy_oog_spend_all
-- copy.returndatacopy.zero_size_at_end, event 17: RETURNDATACOPY of length 0 at the end of the return data.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":46,\"op\":62,\"gas\":\"0x17c4e\",\"static\":false,\"sl\":3,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x40\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x17c4b\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .continue .copy_returndatacopy_zero_size_no_expansion
-- copy.returndatacopy.offset_above_u64, event 17: RETURNDATACOPY to memory offset 2^64 halts after its copy cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":23,\"op\":62,\"gas\":\"0x17c4e\",\"static\":false,\"sl\":3,\"stack\":[\"0x10000000000000000\",\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x17c48\",\"spawn\":false,\"zk\":\"0x3c\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_returndatacopy_offset_above_u64_preserve
-- copy.returndatacopy.expand_memory_oog, event 25: RETURNDATACOPY that pays its copy cost but not its expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":27,\"op\":62,\"gas\":\"0xe\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x40\"],\"mem\":\"0x60\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x5\",\"spawn\":false,\"zk\":\"0x5a\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_returndatacopy_memory_oog_preserve
-- copy.returndatacopy.expand_exact_gas, event 25: RETURNDATACOPY with exactly its static, copy and expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":27,\"op\":62,\"gas\":\"0xf\",\"static\":false,\"sl\":3,\"stack\":[\"0x60\",\"0x0\",\"0x40\"],\"mem\":\"0x60\",\"facts\":{\"returndata_size\":\"0x40\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x96\",\"ok\":true,\"charged\":true}"
  .continue .copy_returndatacopy_expansion_success
-- copy.extcodecopy.size_above_u64, event 4: EXTCODECOPY of 2^64 bytes halts before its copy cost and the cold surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":60,\"gas\":\"0x18696\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x0\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x18632\",\"spawn\":false,\"zk\":\"0x190\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_extcodecopy_size_above_u64_preserve
-- copy.extcodecopy.copy_oog, event 4: EXTCODECOPY that cannot pay 3 gas per word spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":60,\"gas\":\"0x69\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x20\",\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1a4\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_extcodecopy_copy_oog_spend_all
-- copy.extcodecopy.offset_above_u64, event 4: EXTCODECOPY to memory offset 2^64 halts after its copy cost, before the cold surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":60,\"gas\":\"0x18695\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x10000000000000000\",\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x1862e\",\"spawn\":false,\"zk\":\"0x19c\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_extcodecopy_offset_above_u64_preserve
-- copy.extcodecopy.cold_memory_oog, event 4: EXTCODECOPY of a cold account that cannot pay its expansion halts before the cold surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":60,\"gas\":\"0x72\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x20\",\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x8\",\"spawn\":false,\"zk\":\"0x1a8\",\"ok\":true,\"charged\":true}"
  .haltKeep .copy_extcodecopy_memory_oog_preserve
-- copy.extcodecopy.cold_surcharge_oog, event 4: EXTCODECOPY 1 gas short of the cold surcharge after its copy and expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":60,\"gas\":\"0xa36\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x20\",\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x28d8\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_extcodecopy_cold_surcharge_oog_spend_all
-- copy.extcodecopy.zero_size_cold_surcharge_oog, event 4: EXTCODECOPY of length 0 short of the cold surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":38,\"op\":60,\"gas\":\"0xa27\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x289c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .copy_extcodecopy_cold_surcharge_oog_spend_all
-- copy.extcodecopy.cold_exact_gas, event 4: EXTCODECOPY of a cold account with exactly 100 + copy + expansion + 2,500 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":60,\"gas\":\"0xa37\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x20\",\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x28dc\",\"ok\":true,\"charged\":true}"
  .continue .copy_extcodecopy_cold_success
-- copy.extcodecopy.zero_size_cold, event 4: EXTCODECOPY of length 0 at memory offset 2^256 - 1 still pays the cold surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":38,\"op\":60,\"gas\":\"0x18696\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x17c6e\",\"spawn\":false,\"zk\":\"0x28a0\",\"ok\":true,\"charged\":true}"
  .continue .copy_extcodecopy_cold_success
-- copy.extcodecopy.warm_exact_gas, event 7: EXTCODECOPY of a warm account pays no surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":60,\"gas\":\"0x73\",\"static\":false,\"sl\":4,\"stack\":[\"0xda7a\",\"0x20\",\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1cc\",\"ok\":true,\"charged\":true}"
  .continue .copy_extcodecopy_warm_success
-- return.revert.size_above_u64, event 2: REVERT of 2^64 bytes.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":253,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .return_inner_size_above_u64_halt
-- return.return.offset_above_u64, event 2: RETURN at offset 2^64 with a non-zero length.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":243,\"gas\":\"0x1869a\",\"static\":false,\"sl\":2,\"stack\":[\"0x10000000000000000\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .return_inner_offset_above_u64_halt
-- return.revert.expand_memory_oog, event 5: REVERT 1 gas short of its expansion halts.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":253,\"gas\":\"0x17\",\"static\":false,\"sl\":2,\"stack\":[\"0x10\",\"0x200\"],\"mem\":\"0x120\",\"facts\":{},\"gas_after\":\"0x17\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .return_inner_memory_oog_halt
-- return.return.expand_exact_gas, event 5: RETURN with exactly its expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":243,\"gas\":\"0x18\",\"static\":false,\"sl\":2,\"stack\":[\"0x10\",\"0x200\"],\"mem\":\"0x120\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .return_return_expansion_success
-- return.return.zero_size_huge_offset, event 2: RETURN of length 0 at offset 2^256 - 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":34,\"op\":243,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .return_return_expansion_success
-- return.revert.expand_exact_gas, event 5: REVERT with exactly its expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":253,\"gas\":\"0x18\",\"static\":false,\"sl\":2,\"stack\":[\"0x10\",\"0x200\"],\"mem\":\"0x120\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .revert .return_revert_expansion_revert
-- log.static_frame.log2_dynamic_oog, event 11: LOG2 in a static frame short of its dynamic costs pays only its 375 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":7,\"op\":162,\"gas\":\"0x66a\",\"static\":true,\"sl\":4,\"stack\":[\"0x0\",\"0x40\",\"0xa0\",\"0xa1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x4f3\",\"spawn\":false,\"zk\":\"0x2ee\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_static_frame_halt_preserve
-- log.static_frame.log0_underflow, event 8: LOG0 in a static frame on one item: the static-context check comes before the pops.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":160,\"gas\":\"0x270d\",\"static\":true,\"sl\":1,\"stack\":[\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x2596\",\"spawn\":false,\"zk\":\"0x465\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_static_frame_halt_preserve
-- log.log0.underflow, event 1: LOG0 on one item pays its static gas, then halts on the offset and length pops.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":160,\"gas\":\"0x1869d\",\"static\":false,\"sl\":1,\"stack\":[\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18526\",\"spawn\":false,\"zk\":\"0x465\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_logn_stack_underflow_preserve
-- log.log2.size_above_u64, event 4: LOG2 of 2^64 bytes halts before its topic and data cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":162,\"gas\":\"0x18695\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x10000000000000000\",\"0xa0\",\"0xa1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1851e\",\"spawn\":false,\"zk\":\"0x2ee\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_logn_size_above_u64_preserve
-- log.log2.zero_size_topic_oog, event 10: LOG2 of length 0 that cannot pay 2 * 375 for its topics.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":162,\"gas\":\"0x464\",\"static\":false,\"sl\":4,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\",\"0xa0\",\"0xa1\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x8c8\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .log_logn_cost_oog_spend_all
-- log.log1.inside_memory_data_oog, event 7: LOG1 inside current memory that cannot pay its topic and data cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":161,\"gas\":\"0x475\",\"static\":false,\"sl\":3,\"stack\":[\"0x8\",\"0x31\",\"0xa0\"],\"mem\":\"0x40\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xd5f\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .log_logn_cost_oog_spend_all
-- log.log1.offset_above_u64, event 3: LOG1 at offset 2^64 halts after its topic and data cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":14,\"op\":161,\"gas\":\"0x18697\",\"static\":false,\"sl\":3,\"stack\":[\"0x10000000000000000\",\"0x20\",\"0xa0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x182a9\",\"spawn\":false,\"zk\":\"0xbca\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_logn_offset_above_u64_preserve
-- log.log3.expand_memory_oog, event 11: LOG3 that pays its topic and data cost but not its expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":163,\"gas\":\"0x5f1\",\"static\":false,\"sl\":5,\"stack\":[\"0x3f\",\"0x2\",\"0xa0\",\"0xa1\",\"0xa2\"],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x5\",\"spawn\":false,\"zk\":\"0xbd8\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_logn_memory_oog_preserve
-- log.log4.topics_underflow, event 2: LOG4 with its offset and length but too few topics pays every cost, then halts on the topic pop.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":164,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x40\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17d42\",\"spawn\":false,\"zk\":\"0x12b2\",\"ok\":true,\"charged\":true}"
  .haltKeep .log_topics_underflow_preserve
-- log.log4.expand_exact_gas, event 13: LOG4 with exactly 375 + 4 * 375 + 8 per byte + expansion gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":25,\"op\":164,\"gas\":\"0xb53\",\"static\":false,\"sl\":6,\"stack\":[\"0x80\",\"0x80\",\"0xa0\",\"0xa1\",\"0xa2\",\"0xa3\"],\"mem\":\"0x100\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x16a6\",\"ok\":true,\"charged\":true}"
  .continue .log_logn_success
-- log.log0.zero_size_exact_gas, event 3: LOG0 of length 0 pays only its static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":160,\"gas\":\"0x177\",\"static\":false,\"sl\":2,\"stack\":[\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x465\",\"ok\":true,\"charged\":true}"
  .continue .log_logn_success

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
-- Opcodes of the later categories are not modeled yet: SLOAD, BALANCE, CALL.
#guard [0x54, 0x31, 0xf1].all fun op =>
  stepOutcome .unzen { jumpPre 0 {} with op } == .ok none
-- No corpus step pops too few items for MLOAD..RETURN and REVERT; on an empty stack each pays
-- its static gas (100 for EXTCODECOPY, 30 for KECCAK256, 3 or 0 for the rest) and halts.
#guard [(0x51, 97), (0x52, 97), (0x53, 97), (0x5e, 97), (0x20, 70), (0x37, 97), (0x39, 97),
    (0x3e, 97), (0x3c, 0), (0xf3, 100), (0xfd, 100)].all fun (op, gasAfter) =>
  stepOutcome .unzen { jumpPre 0 {} with op } ==
    .ok (some { gasAfter, outcome := .haltKeep, branch := .memory_step_underflow_halt })
-- RETURN with one of its two items.
#guard stepOutcome .unzen { jumpPre 1 {} with op := 0xf3 } =
  .ok (some { gasAfter := 100, outcome := .haltKeep, branch := .memory_step_underflow_halt })
-- RETURNDATACOPY needs returndata_size and EXTCODECOPY account_warm once their operands are on
-- the stack; a memory size that is not whole words is an error.
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x3e, stackLen := 3, stack := [0, 0, 1] }) "returndata_size"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x3c, gas := 3000, stackLen := 4, stack := [1, 0, 0, 1] })
  "account_warm"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x51, stackLen := 1, stack := [0], mem := 33 }) "mem"
-- The smoke harness trace with the step model: every step is modeled.
#guard run smokeHarnessVector smokeHarness (requireModeled stepModel) =
  .ok { events := 5, steps := 4,
        branches := ["static_stack_success", "static_stack_success", "static_arith_success",
                     "static_stop_halt"] }

/-! ### Outcomes against the trace

The checker holds each modeled step's outcome to the event after it: a step that continues is
followed by a step at its depth; a step that ends its frame by a step at a smaller depth or the
end of the tx or frame, and in a harness trace a top frame's end has the `frame_end` status of
its outcome; a step that opens a frame by a step one deeper, a precompile, a step at its depth or
the end. A step whose charge the meter rejects ends the tx and is not checked. Each guard flips
one modeled step's outcome in a trace the step model passes. -/

/-- `model` with the outcome of the step at depth `d` and pc `pc` replaced by `o`. -/
def flipAt (d pc : Nat) (o : Outcome) (model : Model := stepModel) : Model := fun p => do
  match ← model p with
  | some (gasAfter, outcome, branch) =>
    pure (some (gasAfter, if p.depth = d ∧ p.pc = pc then o else outcome, branch))
  | none => pure none

-- PUSH1 that ends its frame, though the frame goes on at its depth.
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 0 .haltKeep))
  "event 0: model branch static_stack_success: outcome haltKeep ends the frame, but the next event is a step at depth 1"
-- STOP that continues, though frame_end follows; STOP that ends with another status.
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .continue))
  "event 3: model branch static_stop_halt: outcome continue, but the next event is frame_end"
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .revert))
  "event 3: model branch static_stop_halt: outcome revert ends the top frame with status revert, but frame_end has status success"
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .haltSpendAll))
  "event 3: model branch static_stop_halt: outcome haltSpendAll ends the top frame with status halt, but frame_end has status success"
-- The anchor's STOP in a block trace: tx_end follows it, so it cannot continue.
#guard (run (blockVector smokeBlockExpected) smokeBlock (requireModeled stepModel)).isOk
#guard failsWith (run (blockVector smokeBlockExpected) smokeBlock (flipAt 1 0 .continue))
  "event 1: model branch static_stop_halt: outcome continue, but the next event is tx_end"
-- A rejected charge ends the frame whatever the step's outcome: ADD continues, frame_end follows.
#guard (run zkLimitVector zkLimitHarness (requireModeled stepModel)).isOk

/-- A model of the CALL family as opening a frame, `stepModel` for the rest. -/
def spawnModel : Model := fun p =>
  if callFamily p.op then .ok (some (0, .newFrame, "spawn")) else stepModel p

/-- A CALL step at depth `d` and pc `pc` that spawns. -/
def callAt (d pc : Nat) : String :=
  stepLine d pc 0xf1 "0x186a0" 7 "\"0xffff\",\"0x2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\""
    "0x1" "0x3d090" "\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null"
    (spawn := true)

-- A spawn step followed by its precompile passes; one followed by a step at a smaller depth
-- fails.
#guard (run callVector callHarness spawnModel).isOk
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x7a120\",\"status\":\"success\"}")
  [callAt 1 0, callAt 2 0, stepLine 1 1 0x00 "0x186a0" 1 "" "0x186a0" "0x0",
   frameEndLine "success" "\"0x7a120\""] spawnModel)
  "event 1: model branch spawn: outcome newFrame, but the next event is a step at depth 1"
