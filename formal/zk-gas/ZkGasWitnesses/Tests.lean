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
def sha256Line (supplied left : String) (success : Bool) (zk : String) (ok : Bool := true) :
    String :=
  "{\"e\":\"precompile\",\"addr\":\"0x0000000000000000000000000000000000000002\",\"supplied\":\"" ++
    supplied ++ "\",\"left\":\"" ++ left ++ "\",\"success\":" ++ toString success ++
    ",\"zk\":\"" ++ zk ++ "\",\"ok\":" ++ toString ok ++ "}"

/-- A JSON Lines file: one line per event, each ending in a newline. -/
def lines (ls : List String) : String := String.join (ls.map (· ++ "\n"))

def blockVector (expected : String) : String :=
  "{\"layer\":\"block\",\"input\":{},\"expected\":" ++ expected ++ "}"

def harnessVector (limit expected : String) : String :=
  "{\"layer\":\"harness\",\"input\":{\"zk_block_limit\":\"" ++ limit ++ "\"},\"expected\":" ++
    expected ++ "}"

/-- Checks the fixture trace `events` against `vector`, by default with the Unzen step model. -/
def run (vector : String) (events : List String) (model : Model := stepModel) :
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
  fun p => .ok { gasAfter := p.gas - staticGas p.op - extra,
                 outcome := if p.op = 0 then .success else .continue, branch := "static" }

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

-- The smoke traces pass with the step model, which decides every step.
#guard run (blockVector smokeBlockExpected) smokeBlock =
  .ok { events := 5, steps := 1, branches := ["static_stop_halt"] }
-- A model is consulted on every step; its gas_after must match the trace.
#guard run smokeHarnessVector smokeHarness (staticModel 0) =
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
-- Every step of a committed trace is metered: a step with charged false would leave its charge
-- out of both the formula and the frame total (here ADD's 0x39 of the smoke frame's 0x6f).
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x36\",\"status\":\"success\"}")
  ((smokeHarness.set 2 (stepLine 1 4 0x01 "0x1869a" 2 "\"0x2\",\"0x1\"" "0x18697" "0x0"
    (charged := false))).set 4 (frameEndLine "success" "\"0x36\""))) "event 2: charged false"

-- A CALL spawn step charges its estimate (12500 * 20) and keeps 99,900 - 65,535 = 0x863d gas
-- after its static 100 and the 0xffff it forwards; the precompile it runs follows it, and the
-- frame continues at the same depth with the 0xffc3 the precompile left: 0x863d + 0xffc3.
def callStep (gas : String := "0x186a0") (gasAfter : String := "0x863d") (zk : String := "0x3d090")
    (spawn : Bool := true) : String :=
  stepLine 1 0 0xf1 gas 7 "\"0xffff\",\"0x2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\""
    gasAfter zk "\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null"
    (spawn := spawn)

def callHarness : List String :=
  [callStep, sha256Line "0xffff" "0xffc3" true "0x258",
   stepLine 1 1 0x00 "0x18600" 1 "" "0x18600" "0x0", frameEndLine "success" "\"0x3d2e8\""]

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
#guard failsWith (run callVector (callHarness.set 1 (sha256Line "0xffff" "0x10000" true "0x0")))
  "event 1: left 0x10000 exceeds supplied 0xffff"
-- A direct call ends the frame as its precompile run ended, unless the meter rejected the
-- charge: a run that halts (all 0x186a0 gas spent, 0xf4240 zk gas) halts the frame, and a run
-- that returns does not.
def directVector (status : String) : String :=
  harnessVector "0x5f5e100" ("{\"frame_zk_gas\":\"0xf4240\",\"status\":\"" ++ status ++ "\"}")

#guard (run (directVector "halt")
  [sha256Line "0x186a0" "0x0" false "0xf4240", frameEndLine "halt" "\"0xf4240\""]).isOk
#guard failsWith (run (directVector "success")
  [sha256Line "0x186a0" "0x0" false "0xf4240", frameEndLine "success" "\"0xf4240\""])
  "event 1: status success, but the direct precompile call halted"
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x258\",\"status\":\"halt\"}")
  [sha256Line "0x186a0" "0x18664" true "0x258", frameEndLine "halt" "\"0x258\""])
  "event 1: status halt, but the direct precompile call returned"
-- Order: a precompile follows a CALL-family spawn step, depth rises only after a spawn step,
-- and a harness trace ends with frame_end.
-- A CALL with 99 gas cannot pay its static 100 (20 * 99 zk gas) and opens no frame.
#guard failsWith (run callVector (callHarness.set 0 (callStep "0x63" "0x0" "0x7bc" false)))
  "event 1: precompile"
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

-- A refused charge whose product overflows a u64 is recorded as 2^64 - 1, as alethia-reth and
-- taiko-geth saturate it, and the meter rejects it even under the largest limit a vector can
-- set. KECCAK256 of 2^64 - 1 bytes cannot pay its word cost and spends all 2^60 gas, at 31 zk
-- gas each; a halted sha256 run spends all 2^61 gas, at 10 each.
def overflowVector : String :=
  harnessVector "0xffffffffffffffff" "{\"frame_zk_gas\":null,\"status\":\"zk_limit\"}"

def overflowStep (zk : String := "0xffffffffffffffff") (ok : Bool := false) : String :=
  stepLine 1 0 0x20 "0x1000000000000000" 2 "\"0x0\",\"0xffffffffffffffff\"" "0x0" zk (ok := ok)

def overflowRun (zk : String := "0xffffffffffffffff") : String :=
  sha256Line "0x2000000000000000" "0x0" false zk (ok := false)

#guard (run overflowVector [overflowStep, frameEndLine "zk_limit" "null"]).isOk
#guard (run overflowVector [overflowRun, frameEndLine "zk_limit" "null"]).isOk
-- The unsaturated product is not the schema's encoding, and an overflowing charge never fits.
#guard failsWith (run overflowVector
  [overflowStep "0x1f000000000000000", frameEndLine "zk_limit" "null"]) "event 0: zk"
#guard failsWith (run overflowVector
  [overflowRun "0x14000000000000000", frameEndLine "zk_limit" "null"]) "event 0: zk"
#guard failsWith (run overflowVector [overflowStep (ok := true), frameEndLine "zk_limit" "null"])
  "event 0: ok true, but the meter rejects"

-- Block abort: the second tx's step exceeds what the block has left. The block keeps the
-- anchor's zk gas and ends at the aborted tx.
def abortBlock : List String :=
  [intrinsicLine, anchorStop, txEndLine 0, intrinsicLine,
   -- KECCAK256 of 2^64 - 1 bytes cannot pay its word cost and spends all 10,000,000 gas: 31 zk
   -- gas each.
   stepLine 1 0 0x20 "0x989680" 2 "\"0x0\",\"0xffffffffffffffff\"" "0x0" "0x127a3980" (ok := false),
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
-- A tx is aborted exactly when the meter rejects one of its charges, and the block total is the
-- meter's.
#guard failsWith (run (blockVector abortExpected)
  [intrinsicLine, anchorStop, txEndLine 0, intrinsicLine, txEndLine 1 "aborted" "null"])
  "event 4: status aborted, but the meter rejected none of the tx's charges"
#guard failsWith (run (blockVector
    (smokeBlockExpected.replace "\"block_zk_gas\":\"0x76a70\"" "\"block_zk_gas\":\"0x76a71\""))
  smokeBlock) "expected block_zk_gas 0x76a71, but meterBlock gives 0x76a70"
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
  .ok { events := 6, steps := 1, branches := ["static_stop_halt"] }
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
checker counts them), and expects that line's `gas_after`, the given outcome and branch. For a
step that opens a frame, `gas_after` is the gas left after the gas it forwards. Every branch has
at least one guard. Constructed pre-states after the trace lines pin checks whose order the traces
cannot show and each EIP-7702 delegate stage at its boundaries. -/

/-- Whether `stepOutcome` on the single step event `line` gives the line's `gas_after`, outcome
`outcome`, branch `branch` and, for a step that opens a frame, `forwarded` as the gas it
forwards, agrees with the line's `spawn`, and `branch.name` is the constructor's name. A spawn
guard's `forwarded` is read off the committed trace: the new frame's first step's `gas`, or the
precompile run's `supplied`, less a value transfer's 2,300 stipend; when the new frame ran no
step, the gas its frame resumes with less the spawn step's `gas_after` and the stipend. -/
def stepAgrees (line : String) (outcome : Outcome) (branch : BranchId) (forwarded : Nat := 0) :
    Bool :=
  match parseTrace line with
  | .ok [.step pre out] =>
    stepOutcome .unzen pre == .ok { gasAfter := out.gasAfter, outcome, branch, forwarded } &&
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
-- sload.sload.warm_static_oog, event 4: SLOAD of a warm slot with 99 of its 100 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":84,\"gas\":\"0x63\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x129\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- sload.sload.underflow_static_oog, event 0: SLOAD on an empty stack with 99 gas: the static gas check comes before the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":84,\"gas\":\"0x63\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x129\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- sload.sload.underflow, event 0: SLOAD on an empty stack pays its static 100 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":84,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863c\",\"spawn\":false,\"zk\":\"0x12c\",\"ok\":true,\"charged\":true}"
  .haltKeep .sload_sload_underflow_preserve
-- sload.sload.warm_exact_gas, event 4: SLOAD of a warm slot with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":84,\"gas\":\"0x64\",\"static\":false,\"sl\":1,\"stack\":[\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x12c\",\"ok\":true,\"charged\":true}"
  .continue .sload_sload_warm_success
-- sload.sload.child_cold_load_warms_slot, event 12: The caller's SLOAD of the slot its DELEGATECALL helper loaded pays no surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":84,\"gas\":\"0x17430\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true},\"gas_after\":\"0x173cc\",\"spawn\":false,\"zk\":\"0x12c\",\"ok\":true,\"charged\":true}"
  .continue .sload_sload_warm_success
-- sload.sload.cold_surcharge_oog, event 1: SLOAD of a cold slot 1 gas short of 100 + 2,000: the skipped cold load spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":84,\"gas\":\"0x833\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1899\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .sload_sload_cold_surcharge_oog_spend_all
-- sload.sload.cold_exact_gas, event 1: SLOAD of a cold slot with exactly 100 + 2,000 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":84,\"gas\":\"0x834\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x189c\",\"ok\":true,\"charged\":true}"
  .continue .sload_sload_cold_success
-- sload.sload.child_cold_oog_leaves_slot_cold, event 11: The caller's SLOAD of the slot whose cold load failed in its DELEGATECALL helper pays the surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":84,\"gas\":\"0x17431\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false},\"gas_after\":\"0x16bfd\",\"spawn\":false,\"zk\":\"0x189c\",\"ok\":true,\"charged\":true}"
  .continue .sload_sload_cold_success
-- account.extcodesize.warm_static_oog, event 4: EXTCODESIZE of a warm account with 99 of its 100 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":59,\"gas\":\"0x63\",\"static\":false,\"sl\":1,\"stack\":[\"0xda7a\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x18c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- account.balance.underflow, event 0: BALANCE on an empty stack pays its static 100 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":49,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863c\",\"spawn\":false,\"zk\":\"0x190\",\"ok\":true,\"charged\":true}"
  .haltKeep .account_access_underflow_preserve
-- account.extcodehash.underflow, event 0: EXTCODEHASH on an empty stack: its fork gate passes, then the pop fails.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":63,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863c\",\"spawn\":false,\"zk\":\"0x2bc\",\"ok\":true,\"charged\":true}"
  .haltKeep .account_access_underflow_preserve
-- account.balance.warm_exact_gas, event 4: BALANCE of a warm account with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":49,\"gas\":\"0x64\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x190\",\"ok\":true,\"charged\":true}"
  .continue .account_access_warm_success
-- account.extcodesize.warm_exact_gas, event 4: EXTCODESIZE of a warm account with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":59,\"gas\":\"0x64\",\"static\":false,\"sl\":1,\"stack\":[\"0xda7a\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x190\",\"ok\":true,\"charged\":true}"
  .continue .account_access_warm_success
-- account.extcodehash.warm_exact_gas, event 4: EXTCODEHASH of a warm account with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":63,\"gas\":\"0x64\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x2bc\",\"ok\":true,\"charged\":true}"
  .continue .account_access_warm_success
-- account.balance.cold_surcharge_oog, event 1: BALANCE of a cold account 1 gas short of 100 + 2,500: the skipped cold load spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":49,\"gas\":\"0xa27\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x289c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .account_access_cold_surcharge_oog_spend_all
-- account.extcodehash.cold_surcharge_oog, event 1: EXTCODEHASH of a cold account 1 gas short of 100 + 2,500.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":63,\"gas\":\"0xa27\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4711\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .account_access_cold_surcharge_oog_spend_all
-- account.balance.cold_exact_gas, event 1: BALANCE of a cold account with exactly 100 + 2,500 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":49,\"gas\":\"0xa28\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x28a0\",\"ok\":true,\"charged\":true}"
  .continue .account_access_cold_success
-- account.extcodesize.cold_exact_gas, event 1: EXTCODESIZE of a cold account with exactly 100 + 2,500 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":59,\"gas\":\"0xa28\",\"static\":false,\"sl\":1,\"stack\":[\"0xda7a\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x28a0\",\"ok\":true,\"charged\":true}"
  .continue .account_access_cold_success
-- account.extcodehash.cold_exact_gas, event 1: EXTCODEHASH of a cold account with exactly 100 + 2,500 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":63,\"gas\":\"0xa28\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4718\",\"ok\":true,\"charged\":true}"
  .continue .account_access_cold_success
-- sstore.static_frame.halt, event 9: SSTORE in a static frame halts before any charge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":85,\"gas\":\"0x752b\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x0\",\"current\":\"0x0\"},\"gas_after\":\"0x752b\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .sstore_static_frame_halt_preserve
-- sstore.sstore.underflow, event 1: SSTORE on one item halts before any charge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":85,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .sstore_sstore_underflow_preserve
-- sstore.sentry.cold_noop_at_2300, event 2: SSTORE with exactly 2,300 gas halts on the sentry, keeping it all.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":85,\"gas\":\"0x8fc\",\"static\":false,\"sl\":2,\"stack\":[\"0x5\",\"0x3\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x3\",\"current\":\"0x3\"},\"gas_after\":\"0x8fc\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .sstore_sentry_halt_preserve
-- sstore.sentry.warm_modify_at_2300, event 5: SSTORE of a warm slot with exactly 2,300 gas halts on the sentry.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":85,\"gas\":\"0x8fc\",\"static\":false,\"sl\":2,\"stack\":[\"0x1\",\"0x6\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x5\",\"current\":\"0x5\"},\"gas_after\":\"0x8fc\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .sstore_sentry_halt_preserve
-- sstore.noop.warm, event 5: SSTORE of a warm slot's current value pays only the 100 base gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":85,\"gas\":\"0x17e61\",\"static\":false,\"sl\":2,\"stack\":[\"0x5\",\"0x3\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x3\",\"current\":\"0x3\"},\"gas_after\":\"0x17dfd\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_warm_success
-- sstore.restore.original_values, event 5: SSTORE that sets a slot written earlier in the tx back to its zero original pays only the 100 base gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":85,\"gas\":\"0x13041\",\"static\":false,\"sl\":2,\"stack\":[\"0x3\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x0\",\"current\":\"0x1\"},\"gas_after\":\"0x12fdd\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_warm_success
-- sstore.restore.original_values, event 11: SSTORE that sets a slot written earlier in the tx back to its non-zero original pays only the 100 base gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":18,\"op\":85,\"gas\":\"0x11c49\",\"static\":false,\"sl\":2,\"stack\":[\"0x4\",\"0x8\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x8\",\"current\":\"0x9\"},\"gas_after\":\"0x11be5\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_warm_success
-- sstore.dirty.third_value, event 5: SSTORE of a third value into a slot written earlier in the tx pays only the 100 base gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":85,\"gas\":\"0x13042\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x2\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x0\",\"current\":\"0x1\"},\"gas_after\":\"0x12fde\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_warm_success
-- sstore.dirty.third_value, event 11: SSTORE that rewrites a slot cleared earlier in the tx pays only the 100 base gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":85,\"gas\":\"0x11c4b\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x9\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x7\",\"current\":\"0x0\"},\"gas_after\":\"0x11be7\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_warm_success
-- sstore.sentry.cold_noop_at_2301, event 2: SSTORE of a cold slot's current value with 2,301 gas passes the sentry and pays 100 + 2,100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":85,\"gas\":\"0x8fd\",\"static\":false,\"sl\":2,\"stack\":[\"0x5\",\"0x3\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x3\",\"current\":\"0x3\"},\"gas_after\":\"0x65\",\"spawn\":false,\"zk\":\"0x2af8\",\"ok\":true,\"charged\":true}"
  .continue .sstore_nowrite_cold_success
-- sstore.fresh.warm_exact_gas, event 5: SSTORE of a non-zero value into a warm zero slot with exactly 100 + 19,900 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":85,\"gas\":\"0x4e20\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x0\",\"current\":\"0x0\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x186a0\",\"ok\":true,\"charged\":true}"
  .continue .sstore_fresh_warm_success
-- sstore.fresh.cold_exact_gas, event 2: SSTORE of a non-zero value into a cold zero slot with exactly 100 + 2,100 + 19,900 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":85,\"gas\":\"0x5654\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x0\",\"current\":\"0x0\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1afa4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_fresh_cold_success
-- sstore.modify.warm_exact_gas, event 5: SSTORE of a new non-zero value into a warm non-zero slot with exactly 100 + 2,800 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":85,\"gas\":\"0xb54\",\"static\":false,\"sl\":2,\"stack\":[\"0x1\",\"0x6\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x5\",\"current\":\"0x5\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x38a4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_modify_warm_success
-- sstore.clear.warm_exact_gas, event 5: SSTORE of zero into a warm non-zero slot pays the same 100 + 2,800 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":85,\"gas\":\"0xb54\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x7\",\"current\":\"0x7\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x38a4\",\"ok\":true,\"charged\":true}"
  .continue .sstore_modify_warm_success
-- sstore.modify.cold_exact_gas, event 2: SSTORE of a new non-zero value into a cold non-zero slot with exactly 100 + 2,100 + 2,800 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":85,\"gas\":\"0x1388\",\"static\":false,\"sl\":2,\"stack\":[\"0x1\",\"0x6\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x5\",\"current\":\"0x5\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x61a8\",\"ok\":true,\"charged\":true}"
  .continue .sstore_modify_cold_success
-- sstore.clear.cold_exact_gas, event 2: SSTORE of zero into a cold non-zero slot with exactly 100 + 2,100 + 2,800 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":85,\"gas\":\"0x1388\",\"static\":false,\"sl\":2,\"stack\":[\"0x2\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x7\",\"current\":\"0x7\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x61a8\",\"ok\":true,\"charged\":true}"
  .continue .sstore_modify_cold_success
-- sstore.fresh.cold_dynamic_oog, event 2: SSTORE into a cold zero slot 1 gas short of 100 + 2,100 + 19,900.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":85,\"gas\":\"0x5653\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":false,\"original\":\"0x0\",\"current\":\"0x0\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1af9f\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .sstore_dynamic_oog_spend_all
-- sstore.fresh.warm_dynamic_oog, event 5: SSTORE into a warm zero slot 1 gas short of 100 + 19,900.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":85,\"gas\":\"0x4e1f\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x0\",\"current\":\"0x0\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1869b\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .sstore_dynamic_oog_spend_all
-- sstore.sentry.warm_modify_at_2301, event 5: SSTORE of a warm slot with 2,301 gas passes the sentry but cannot pay 100 + 2,800.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":85,\"gas\":\"0x8fd\",\"static\":false,\"sl\":2,\"stack\":[\"0x1\",\"0x6\"],\"mem\":\"0x0\",\"facts\":{\"slot_warm\":true,\"original\":\"0x5\",\"current\":\"0x5\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x2cf1\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .sstore_dynamic_oog_spend_all
-- selfdestruct.selfdestruct.warm_static_oog, event 4: SELFDESTRUCT with 4,999 of its 5,000 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":255,\"gas\":\"0x1387\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- selfdestruct.static_frame.halt, event 8: SELFDESTRUCT in a static frame halts after its static gas, before loading the beneficiary.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":255,\"gas\":\"0x752d\",\"static\":true,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"self_balance\":\"0x1\"},\"gas_after\":\"0x61a5\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .selfdestruct_static_frame_halt_preserve
-- selfdestruct.selfdestruct.underflow, event 0: SELFDESTRUCT on an empty stack pays its static 5,000 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":255,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17318\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .selfdestruct_selfdestruct_underflow_preserve
-- selfdestruct.selfdestruct.cold_load_skipped, event 1: SELFDESTRUCT to a cold beneficiary 1 gas short of 5,000 + 2,600: the skipped load spends all gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":255,\"gas\":\"0x1daf\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .selfdestruct_selfdestruct_cold_load_skipped_spend_all
-- selfdestruct.new_account.cold_charge_oog, event 1: SELFDESTRUCT with value to a cold empty beneficiary 1 gas short of 5,000 + 2,600 + 25,000.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":255,\"gas\":\"0x7f57\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .selfdestruct_new_account_charge_oog_spend_all
-- selfdestruct.new_account.warm_charge_oog, event 1: SELFDESTRUCT with value to a warm empty beneficiary 1 gas short of 5,000 + 25,000.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":255,\"gas\":\"0x752f\",\"static\":false,\"sl\":1,\"stack\":[\"0xc0ffee\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .selfdestruct_new_account_charge_oog_spend_all
-- selfdestruct.selfdestruct.warm_exact_gas, event 4: SELFDESTRUCT to a warm beneficiary with exactly its static 5,000 gas ends the frame successfully.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":255,\"gas\":\"0x1388\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .selfdestruct_selfdestruct_warm_success
-- selfdestruct.selfdestruct.cold_exact_gas, event 1: SELFDESTRUCT to a cold beneficiary with exactly 5,000 + 2,600 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":255,\"gas\":\"0x1db0\",\"static\":false,\"sl\":1,\"stack\":[\"0xbeef\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .selfdestruct_selfdestruct_cold_success
-- selfdestruct.selfdestruct.cold_empty_zero_value, event 1: SELFDESTRUCT of a contract holding no value to a cold empty beneficiary pays no new-account charge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":255,\"gas\":\"0x1db0\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"self_balance\":\"0x0\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .selfdestruct_selfdestruct_cold_success
-- selfdestruct.new_account.warm_exact_gas, event 1: SELFDESTRUCT with value to a warm empty beneficiary with exactly 5,000 + 25,000 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":255,\"gas\":\"0x7530\",\"static\":false,\"sl\":1,\"stack\":[\"0xc0ffee\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .selfdestruct_new_account_warm_success
-- selfdestruct.new_account.cold_exact_gas, event 1: SELFDESTRUCT with value to a cold empty beneficiary with exactly 5,000 + 2,600 + 25,000 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":255,\"gas\":\"0x7f58\",\"static\":false,\"sl\":1,\"stack\":[\"0xdead\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"self_balance\":\"0x1\"},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .success .selfdestruct_new_account_cold_success
-- transient.tload.static_oog, event 1: TLOAD with 99 of its 100 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":92,\"gas\":\"0x63\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x63\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- transient.tstore.static_oog, event 5: TSTORE with 99 of its 100 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":93,\"gas\":\"0x63\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1ef\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- transient.static_frame.tstore_static_oog, event 9: TSTORE in a static frame with 99 gas: the static gas check comes before the static-context check.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":93,\"gas\":\"0x63\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1ef\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- transient.tload.underflow, event 0: TLOAD on an empty stack pays its static 100 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":92,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863c\",\"spawn\":false,\"zk\":\"0x64\",\"ok\":true,\"charged\":true}"
  .haltKeep .transient_tload_underflow_preserve
-- transient.tload.exact_gas, event 1: TLOAD with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":92,\"gas\":\"0x64\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x64\",\"ok\":true,\"charged\":true}"
  .continue .transient_tload_success
-- transient.tstore.underflow, event 1: TSTORE on one item pays its static 100 gas and keeps the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":93,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1863a\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .haltKeep .transient_tstore_underflow_preserve
-- transient.tstore.exact_gas, event 5: TSTORE with exactly its static 100 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":93,\"gas\":\"0x64\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .continue .transient_tstore_success
-- transient.static_frame.tstore_gas_100, event 9: TSTORE in a static frame with exactly 100 gas pays it, then halts on the static-context check.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":93,\"gas\":\"0x64\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .haltKeep .transient_static_frame_tstore_halt_preserve
-- transient.static_frame.tstore_surplus_gas, event 9: TSTORE in a static frame keeps the gas left after its static 100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":93,\"gas\":\"0x3e3\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x37f\",\"spawn\":false,\"zk\":\"0x1f4\",\"ok\":true,\"charged\":true}"
  .haltKeep .transient_static_frame_tstore_halt_preserve

-- call.staticcall.warm_static_oog, event 9: STATICCALL with 99 of its 100 static gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":250,\"gas\":\"0x63\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0d2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x8e5\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .static_step_static_oog_spend_all
-- call.call.underflow, event 6: CALL on six items pays its static 100 gas, pops the gas limit, target and value, then runs out at the memory operands.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":241,\"gas\":\"0x18694\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18630\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_underflow_preserve
-- call.call.static_frame_value_warm, event 17: CALL of value 1 in a static frame pays its static 100 gas and halts keeping the rest.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":10,\"op\":241,\"gas\":\"0x2700\",\"static\":true,\"sl\":7,\"stack\":[\"0x0\",\"0xc0d1\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x269c\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_call_static_frame_value_halt_preserve
-- call.call.static_frame_value_size_above_u64, event 14: CALL of value 1 in a static frame with an input length of 2^64: the static check comes before the memory operands.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":19,\"op\":241,\"gas\":\"0x26ff\",\"static\":true,\"sl\":7,\"stack\":[\"0x0\",\"0xc0d1\",\"0x1\",\"0x0\",\"0x10000000000000000\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x269b\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_call_static_frame_value_halt_preserve
-- call.call.static_frame_value_cold_low_gas, event 14: CALL of value 1 in a static frame to a cold target with less than the 2,500 surcharge: the static check comes before the target load.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":10,\"op\":241,\"gas\":\"0x3d8\",\"static\":true,\"sl\":7,\"stack\":[\"0x0\",\"0xc0d1\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x374\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_call_static_frame_value_halt_preserve
-- call.family.input_size_above_u64, event 6: STATICCALL with an input length of 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":18,\"op\":250,\"gas\":\"0x18692\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x10000000000000000\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x1862e\",\"spawn\":false,\"zk\":\"0x8fc\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_input_size_above_u64_preserve
-- call.family.input_offset_above_u64, event 7: CALLCODE with an input offset of 2^64 and length 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":242,\"gas\":\"0x1868f\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x10000000000000000\",\"0x1\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x1862b\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_input_offset_above_u64_preserve
-- call.family.input_expand_memory_oog, event 7: CALL with 2 gas left after its static 100 cannot pay the 3-gas expansion of its 32-byte input.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":241,\"gas\":\"0x66\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x0\",\"0x20\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x2\",\"spawn\":false,\"zk\":\"0x7d0\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_input_memory_oog_preserve
-- call.family.output_size_above_u64, event 7: CALL with an output length of 2^64 halts after paying its input expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":241,\"gas\":\"0x1868f\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x0\",\"0x20\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x18628\",\"spawn\":false,\"zk\":\"0x80c\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_size_above_u64_keeps_input_charge
-- call.family.output_offset_above_u64, event 7: CALLCODE with an output offset of 2^64 and length 1 halts after paying its input expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":21,\"op\":242,\"gas\":\"0x1868e\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x0\",\"0x20\",\"0x10000000000000000\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x18627\",\"spawn\":false,\"zk\":\"0x80c\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_offset_above_u64_keeps_input_charge
-- call.family.output_expand_memory_oog, event 6: DELEGATECALL pays its input expansion to 64 bytes, then cannot pay the output expansion to 96.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":244,\"gas\":\"0x69\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x20\",\"0x20\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x2\",\"spawn\":false,\"zk\":\"0x6d7\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_memory_oog_keeps_input_charge
-- call.family.output_end_above_u64, event 6: STATICCALL with an output range ending past 2^64 halts after paying its input expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":19,\"op\":250,\"gas\":\"0x18690\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x20\",\"0xffffffffffffffff\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x18629\",\"spawn\":false,\"zk\":\"0x941\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_memory_oog_keeps_input_charge
-- call.family.output_word_rounding_above_u64, event 6: DELEGATECALL with an output range whose end rounds up past 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":19,\"op\":244,\"gas\":\"0x18690\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x20\",\"0xfffffffffffffffe\",\"0x1\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x18629\",\"spawn\":false,\"zk\":\"0x6d7\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_memory_oog_keeps_input_charge
-- call.family.output_size_above_cap, event 7: CALL with a 2^37-byte output range.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":16,\"op\":241,\"gas\":\"0x1868f\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x0\",\"0x20\",\"0x0\",\"0x2000000000\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x18628\",\"spawn\":false,\"zk\":\"0x80c\",\"ok\":true,\"charged\":true}"
  .haltKeep .call_family_output_memory_oog_keeps_input_charge
-- call.value.transfer_oog, event 10: CALL of value 1 with 8,999 gas left after its static 100 cannot pay the 9,000 transfer cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":241,\"gas\":\"0x238b\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0d2\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x2c6dc\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_value_transfer_oog_spend_all
-- call.staticcall.cold_surcharge_oog, event 6: STATICCALL to a cold target with 2,499 gas left after its static 100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":250,\"gas\":\"0xa27\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0d2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xe981\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_cold_surcharge_oog_spend_all
-- call.callcode.value_to_empty_oog, event 7: CALLCODE of value 1 to a cold empty target with 11,599 gas: the transfer cost comes before the cold load, which is then skipped.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":242,\"gas\":\"0x2d4f\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xdead\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x38a2c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_cold_surcharge_oog_spend_all
-- call.call.new_account_oog, event 7: CALL of value 1 to a cold empty target with 36,599 gas, one short of 100 + 9,000 + 2,500 + 25,000.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x8ef7\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xdead\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xb2b4c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_call_new_account_oog_spend_all
-- call.staticcall.warm_exact_gas, event 9: STATICCALL to a warm target with exactly its static 100 gas opens a frame with 0 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":250,\"gas\":\"0x64\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0d2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0x0)
-- call.family.zero_size_huge_offsets, event 6: STATICCALL with zero-length ranges at offsets 2^256 - 1 expands nothing.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":73,\"op\":250,\"gas\":\"0x64\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0x0)
-- call.family.input_expand_exact_gas, event 7: CALL with value 0 to a warm empty target with exactly 100 + 3 for its input expansion: no new-account cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":241,\"gas\":\"0x67\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x0\",\"0x20\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0x0)
-- call.family.output_expand_exact_gas, event 6: DELEGATECALL with exactly 100 + 3 + 3 for its input and then its output expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":244,\"gas\":\"0x6a\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0ffee\",\"0x0\",\"0x20\",\"0x20\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0xe86c\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0x0)
-- call.family.empty_code, event 25: CALLCODE to a warm account without code forwards all but one 64th of what is left, up to its gas limit 0xffff.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":37,\"op\":242,\"gas\":\"0x1721c\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xbeef\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x71b9\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0xffff)
-- call.depth.limit_at_1024, event 8199: The CALL of the deepest frame installs its frame; the handler then refuses it for depth and the frame goes on at the same depth.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1025,\"pc\":7,\"op\":241,\"gas\":\"0x18dfe\",\"static\":false,\"sl\":7,\"stack\":[\"0x18dfe\",\"0xc0de\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x636\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_spawn (forwarded := 0x18764)
-- call.call.new_frame, event 7: CALL to a cold target pays its 2,500 surcharge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":241,\"gas\":\"0x18690\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xc0d1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x7c69\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xffff)
-- call.callcode.new_frame, event 7: CALLCODE to a cold target.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":242,\"gas\":\"0x18690\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xc0d1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x7c69\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xffff)
-- call.delegatecall.new_frame, event 6: DELEGATECALL to a cold target.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":244,\"gas\":\"0x18692\",\"static\":false,\"sl\":6,\"stack\":[\"0xffff\",\"0xc0d1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x7c6b\",\"spawn\":true,\"zk\":\"0xe86c\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xffff)
-- call.staticcall.cold_exact_gas, event 6: STATICCALL to a cold target with exactly 100 + 2,500 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":8,\"op\":250,\"gas\":\"0xa28\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xc0d2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0x0)
-- call.family.empty_code, event 7: CALL with value 0 to a cold account not in the state: no new-account cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":241,\"gas\":\"0x18690\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xdead\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x7c69\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xffff)
-- call.family.static_frame_allowed_calls, event 14: CALL with value 0 in a static frame opens its frame.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":10,\"op\":241,\"gas\":\"0xc340\",\"static\":true,\"sl\":7,\"stack\":[\"0xff\",\"0xc0d1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0xb819\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xff)
-- call.family.spawn_exceeds_limit, event 6: STATICCALL to a cold target whose spawn estimate the meter rejects still installs its frame.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":250,\"gas\":\"0x18692\",\"static\":false,\"sl\":6,\"stack\":[\"0xffff\",\"0xc0d2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x7c6b\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":false,\"charged\":true}"
  .newFrame .call_family_cold_target_spawn (forwarded := 0xffff)
-- call.family.delegated_to_precompile, event 7: CALL to a cold target delegated to identity (warm): 2,500 + 100 for the delegate.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":241,\"gas\":\"0x1868f\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xe0a\",\"0x0\",\"0x0\",\"0x20\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x7c01\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_warm_delegate_spawn (forwarded := 0xffff)
-- call.value.transfer_exact_gas, event 10: CALL of value 1 to a warm contract with exactly 100 + 9,000 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":241,\"gas\":\"0x238c\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xc0d2\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_warm_target_spawn (forwarded := 0x0)
-- call.family.static_frame_allowed_calls, event 27: CALLCODE of value 1 in a static frame opens its frame.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":23,\"op\":242,\"gas\":\"0xb8fc\",\"static\":true,\"sl\":7,\"stack\":[\"0xff\",\"0xc0d1\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x9471\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_warm_target_spawn (forwarded := 0xff)
-- call.callcode.value_to_empty_exact_gas, event 7: CALLCODE of value 1 to a cold empty target with exactly 100 + 9,000 + 2,500: no new-account cost.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":242,\"gas\":\"0x2d50\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xdead\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_cold_target_spawn (forwarded := 0x0)
-- call.value.insufficient_balance, event 7: CALL of value 1 to a cold contract the caller cannot pay: the balance check is the handler's.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":241,\"gas\":\"0x1868f\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0xc0d1\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x5940\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_cold_target_spawn (forwarded := 0xffff)
-- call.value.insufficient_balance, event 25: CALL of value 1 to identity, warm and empty: 9,000 + 25,000.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":40,\"op\":241,\"gas\":\"0x14784\",\"static\":false,\"sl\":7,\"stack\":[\"0xffff\",\"0x4\",\"0x1\",\"0x0\",\"0x20\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x309\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_call_new_account_warm_target_spawn (forwarded := 0xbf44)
-- precompile.call_value.stipend, event 7: CALL of value 1 and gas limit 0 to ecrecover: 9,000 + 25,000, and nothing forwarded beyond the stipend.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":241,\"gas\":\"0x18690\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0x1\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x1015c\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_call_new_account_warm_target_spawn (forwarded := 0x0)
-- call.call.new_account_exact_gas, event 7: CALL of value 1 to a cold empty target with exactly 100 + 9,000 + 2,500 + 25,000.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x8ef8\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xdead\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_call_new_account_cold_target_spawn (forwarded := 0x0)
-- create.family.static_frame_constant_shortfall, event 10: CREATE in a static frame with less than its 32,000 base halts keeping all its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":4,\"op\":240,\"gas\":\"0x7cff\",\"static\":true,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x7cff\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_static_frame_halt_preserve
-- create.family.static_frame_enough_gas, event 23: CREATE2 in a static frame that could pay every charge halts keeping all its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":5,\"op\":245,\"gas\":\"0xfff6\",\"static\":true,\"sl\":4,\"stack\":[\"0x0\",\"0x0\",\"0x20\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0xfff6\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_static_frame_halt_preserve
-- create.family.static_frame_underflow, event 10: CREATE2 in a static frame on three items: the static check comes before the pops.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":4,\"op\":245,\"gas\":\"0xfff8\",\"static\":true,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0xfff8\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_static_frame_halt_preserve
-- create.create.underflow, event 2: CREATE on two items.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":240,\"gas\":\"0x1869c\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869c\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_underflow_preserve
-- create.create2.underflow_two_operands, event 2: CREATE2 on two items.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":245,\"gas\":\"0x1869b\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869b\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_underflow_preserve
-- create.create.size_above_u64, event 3: CREATE with a length of 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":240,\"gas\":\"0x18699\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x10000000000000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18699\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_size_above_u64_preserve
-- create.create.initcode_above_limit, event 3: CREATE of 49,153 bytes halts on the initcode limit keeping all its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":240,\"gas\":\"0x18699\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc001\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18699\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_initcode_above_limit_preserve
-- create.create.initcode_above_limit_offset_above_u64, event 3: CREATE of 49,153 bytes at an offset of 2^64: the limit comes before the offset.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":14,\"op\":240,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x10000000000000000\",\"0xc001\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18698\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_initcode_above_limit_preserve
-- create.create2.initcode_above_limit_low_gas, event 4: CREATE2 of 49,153 bytes with less than its base left: the limit comes before any charge.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":245,\"gas\":\"0x4e17\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x0\",\"0xc001\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x4e17\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_initcode_above_limit_preserve
-- create.create.initcode_word_cost_oog, event 3: CREATE of 49,152 bytes with 3,071 gas cannot pay 2 gas for each of its 1,536 words.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":240,\"gas\":\"0xbff\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xbff\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_family_initcode_word_cost_oog_spend_all
-- create.create2.three_operands_word_cost_oog, event 3: CREATE2 on three items that cannot pay its initcode word cost: the charge comes before the salt.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":245,\"gas\":\"0xbff\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xbff\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_family_initcode_word_cost_oog_spend_all
-- create.create2.offset_above_u64, event 4: CREATE2 of 49,152 bytes at an offset of 2^64 pays its initcode word cost, then halts.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":245,\"gas\":\"0x18696\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x10000000000000000\",\"0xc000\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x17a96\",\"spawn\":false,\"zk\":\"0xc00\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_offset_above_u64_preserve_after_initcode
-- create.create.memory_oog_dynamic, event 3: CREATE of 32 bytes at offset 1,000,000 pays its initcode word cost, then cannot pay the expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":240,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0xf4240\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0x2\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create.end_above_u64, event 3: CREATE whose range ends past 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":240,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0xfffffffffffffff0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0x2\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create.word_rounding_above_u64, event 3: CREATE whose range end rounds up past 2^64.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":240,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0xffffffffffffffd8\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0x2\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create.memory_above_cap, event 3: CREATE whose range is above any payable memory size.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":240,\"gas\":\"0x18698\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x10000000000\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18696\",\"spawn\":false,\"zk\":\"0x2\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create.initcode_word_cost_paid_memory_oog, event 3: CREATE of 49,152 bytes with 3,073 gas pays its 3,072 initcode word cost and keeps 1.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":240,\"gas\":\"0xc01\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1\",\"spawn\":false,\"zk\":\"0xc00\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create2.three_operands_memory_oog, event 3: CREATE2 on three items that cannot pay its expansion: the expansion comes before the salt.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":245,\"gas\":\"0xc01\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1\",\"spawn\":false,\"zk\":\"0xc00\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_family_memory_oog_preserve_after_initcode
-- create.create2.salt_underflow, event 3: CREATE2 of 1,024 bytes on three items pays 64 + 98 for its initcode words and expansion, then halts on the salt.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":245,\"gas\":\"0x18699\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x400\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x185f7\",\"spawn\":false,\"zk\":\"0xa2\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_create2_salt_underflow_after_charges_preserve
-- create.create2.salt_underflow_zero_size, event 3: CREATE2 of 0 bytes on three items halts on the salt keeping all its gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":245,\"gas\":\"0x1869a\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .create_create2_salt_underflow_after_charges_preserve
-- create.create.base_oog, event 3: CREATE of 32 bytes with 32,004 gas pays 2 + 3 for its initcode word and expansion, then cannot pay the 32,000 base.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":240,\"gas\":\"0x7d04\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x7d04\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_create_base_oog_spend_all
-- create.create.base_oog_low_gas, event 3: CREATE of 32 bytes with 20,000 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":240,\"gas\":\"0x4e20\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4e20\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_create_base_oog_spend_all
-- create.create.zero_size_base_oog, event 3: CREATE of 0 bytes with 31,999 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":240,\"gas\":\"0x7cff\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x7cff\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_create_base_oog_spend_all
-- create.create2.hash_oog, event 4: CREATE2 of 1,024 bytes with 32,353 gas pays 64 + 98, then cannot pay 32,000 + 6 for each of its 32 words.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":245,\"gas\":\"0x7e61\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x0\",\"0x400\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x7e61\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .create_create2_hash_oog_spend_all
-- create.create.new_frame_exact_gas, event 3: CREATE of 32 bytes with exactly 2 + 3 + 32,000 opens a frame with 0 gas.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":240,\"gas\":\"0x7d05\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create_new_frame_spawn_estimate (forwarded := 0x0)
-- create.create.zero_size_exact_gas, event 3: CREATE of 0 bytes with exactly its 32,000 base.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":240,\"gas\":\"0x7d00\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create_new_frame_spawn_estimate (forwarded := 0x0)
-- create.family.initcode_at_limit, event 3: CREATE of exactly 49,152 bytes passes the limit and forwards all but one 64th of what is left.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":240,\"gas\":\"0x30d39\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0xc000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x980\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create_new_frame_spawn_estimate (forwarded := 0x256b9)
-- create.family.depth_limit_at_1024, event 8199: The CREATE of the deepest frame installs its frame; the handler then refuses it for depth and the frame goes on at the same depth.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1025,\"pc\":7,\"op\":240,\"gas\":\"0x1676bf\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x14\"],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x57e6\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create_new_frame_spawn_estimate (forwarded := 0x15a1d7)
-- create.create2.new_frame_exact_gas, event 4: CREATE2 of 1,024 bytes with exactly 64 + 98 + 32,000 + 192.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":245,\"gas\":\"0x7e62\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x0\",\"0x400\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0xadd4\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create2_new_frame_spawn_estimate (forwarded := 0x0)
-- create.family.initcode_at_limit, event 10: CREATE2 of exactly 49,152 bytes inside current memory: no expansion.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":245,\"gas\":\"0x2602e\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0x0\",\"0xc000\",\"0x0\"],\"mem\":\"0xc000\",\"facts\":{},\"gas_after\":\"0x6cc\",\"spawn\":true,\"zk\":\"0xadd4\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create2_new_frame_spawn_estimate (forwarded := 0x1ac62)
-- create.family.zero_size_huge_offset, event 10: CREATE2 of 0 bytes at offset 2^256 - 1: no initcode charges and no offset check.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":73,\"op\":245,\"gas\":\"0x1098e\",\"static\":false,\"sl\":4,\"stack\":[\"0x0\",\"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x232\",\"spawn\":true,\"zk\":\"0xadd4\",\"ok\":true,\"charged\":true}"
  .newFrame .create_create2_new_frame_spawn_estimate (forwarded := 0x8a5c)

-- memory.step.underflow_halt, event 7: MLOAD on an empty stack pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":81,\"gas\":\"0x3e8\",\"static\":true,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e5\",\"spawn\":false,\"zk\":\"0x36\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 17: MSTORE on 1 item pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":1,\"op\":82,\"gas\":\"0x3e6\",\"static\":true,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e3\",\"spawn\":false,\"zk\":\"0x57\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 27: MSTORE8 on 1 item pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":1,\"op\":83,\"gas\":\"0x3e6\",\"static\":true,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e3\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 38: MCOPY on 2 items pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":94,\"gas\":\"0x3e4\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e1\",\"spawn\":false,\"zk\":\"0xc\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 48: KECCAK256 on 1 item pays its static 30 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":1,\"op\":32,\"gas\":\"0x3e6\",\"static\":true,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3c8\",\"spawn\":false,\"zk\":\"0x3a2\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 59: CALLDATACOPY on 2 items pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":55,\"gas\":\"0x3e4\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e1\",\"spawn\":false,\"zk\":\"0x27\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 70: CODECOPY on 2 items pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":57,\"gas\":\"0x3e4\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e1\",\"spawn\":false,\"zk\":\"0x24\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 81: RETURNDATACOPY on 2 items pays its static 3 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":62,\"gas\":\"0x3e4\",\"static\":true,\"sl\":2,\"stack\":[\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e1\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 93: EXTCODECOPY on 3 items pays its static 100 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":60,\"gas\":\"0x3e2\",\"static\":true,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x37e\",\"spawn\":false,\"zk\":\"0x190\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 103: RETURN on 1 item pays its static 0 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":1,\"op\":243,\"gas\":\"0x3e6\",\"static\":true,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e6\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- memory.step.underflow_halt, event 113: REVERT on 1 item pays its static 0 gas and halts on the underflow.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":2,\"pc\":1,\"op\":253,\"gas\":\"0x3e6\",\"static\":true,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3e6\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}"
  .haltKeep .memory_step_underflow_halt
-- call.delegate.warm_target_warm_delegate_exact_gas, event 12: DELEGATECALL to a warm target delegated to a warm address with exactly 100 + 100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":18,\"op\":244,\"gas\":\"0xc8\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xde1e\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0xe86c\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_warm_delegate_spawn (forwarded := 0x0)
-- call.delegate.warm_target_warm_delegate_read_oog, event 12: DELEGATECALL one gas short of 100 + 100: the delegate read fails.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":18,\"op\":244,\"gas\":\"0xc7\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xde1e\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xd37\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_delegate_read_oog_spend_all
-- call.delegate.warm_target_cold_delegate_exact_gas, event 9: STATICCALL to a warm target delegated to a cold address with exactly 100 + 2,600.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":250,\"gas\":\"0xa8c\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xde1e\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_warm_target_cold_delegate_spawn (forwarded := 0x0)
-- call.delegate.warm_target_cold_delegate_cold_surcharge_oog, event 9: STATICCALL one gas short of 100 + 2,600: the cold delegate is skipped.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":250,\"gas\":\"0xa8b\",\"static\":false,\"sl\":6,\"stack\":[\"0x0\",\"0xde1e\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0xf27d\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_delegate_cold_surcharge_oog_spend_all
-- call.delegate.cold_target_cold_delegate_exact_gas, event 7: CALL of value 0 to a cold target delegated to a cold address with exactly 100 + 5,100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":241,\"gas\":\"0x1450\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_family_cold_target_cold_delegate_spawn (forwarded := 0x0)
-- call.delegate.value_warm_target_warm_delegate_exact_gas, event 13: CALL of value 1 to a warm target delegated to a warm address with exactly 100 + 9,100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":20,\"op\":241,\"gas\":\"0x23f0\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_warm_target_warm_delegate_spawn (forwarded := 0x0)
-- call.delegate.value_warm_target_cold_delegate_exact_gas, event 10: CALLCODE of value 1 to a warm target delegated to a cold address with exactly 100 + 11,600.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":242,\"gas\":\"0x2db4\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_warm_target_cold_delegate_spawn (forwarded := 0x0)
-- call.delegate.value_cold_target_warm_delegate_exact_gas, event 10: CALLCODE of value 1 to a cold target delegated to a warm address with exactly 100 + 11,600.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":242,\"gas\":\"0x2db4\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_cold_target_warm_delegate_spawn (forwarded := 0x0)
-- call.delegate.value_cold_target_warm_delegate_read_oog, event 10: CALLCODE of value 1 one gas short of 100 + 11,600: the delegate read fails after the transfer and cold target costs.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":242,\"gas\":\"0x2db3\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":true},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x391fc\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_delegate_read_oog_spend_all
-- call.delegate.value_cold_target_cold_delegate_exact_gas, event 7: CALL of value 1 to a cold target delegated to a cold address with exactly 100 + 14,100.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x3778\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}"
  .newFrame .call_value_cold_target_cold_delegate_spawn (forwarded := 0x0)
-- call.delegate.value_cold_target_cold_delegate_cold_surcharge_oog, event 7: CALL of value 1 one gas short of 100 + 14,100: the cold delegate is skipped.
#guard stepAgrees
  "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x3777\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x4554c\",\"ok\":true,\"charged\":true}"
  .haltSpendAll .call_family_delegate_cold_surcharge_oog_spend_all

/-- A JUMP pre-state with `sl` stack items (target 4) and facts `facts`. -/
def jumpPre (sl : Nat) (facts : Facts) : Pre :=
  { op := 0x56, depth := 1, pc := 0, gas := 100, static := false, stackLen := sl,
    stack := (List.replicate (min sl 1) 4), mem := 0, facts }

-- The model needs the facts it reads: a JUMP whose stack holds its target but that records no
-- jumpdest_valid is an error, as is a recorded stack shorter than the model reads.
#guard failsWith (stepOutcome .unzen (jumpPre 1 {})) "jumpdest_valid"
#guard stepOutcome .unzen (jumpPre 1 { jumpdestValid := some true }) =
  .ok { gasAfter := 92, outcome := .continue, branch := .jump_jump_valid_target_success }
#guard failsWith (stepOutcome .unzen { jumpPre 2 {} with op := 0x57 }) "stack"
-- An underflowing JUMP reads no fact.
#guard stepOutcome .unzen (jumpPre 0 {}) =
  .ok { gasAfter := 92, outcome := .haltKeep, branch := .static_jump_underflow_halt }
-- Every opcode is modeled: the opcodes `classify` maps to `undefined_opcode_zero_gas_halt` are
-- exactly those revm-bytecode does not define, and on an empty stack with 100 gas each opcode
-- ends its step without needing a fact.
#guard (List.range 256).all fun op =>
  (classify op == .halt .undefined_opcode_zero_gas_halt) == (staticGasEntries.lookup op).isNone
#guard (List.range 256).all fun op =>
  match stepOutcome .unzen { jumpPre 0 {} with op } with
  | .ok _ => true
  | _ => false
-- MLOAD..RETURN and REVERT on an empty stack each pay their static gas (100 for EXTCODECOPY, 30
-- for KECCAK256, 3 or 0 for the rest) and halt.
#guard [(0x51, 97), (0x52, 97), (0x53, 97), (0x5e, 97), (0x20, 70), (0x37, 97), (0x39, 97),
    (0x3e, 97), (0x3c, 0), (0xf3, 100), (0xfd, 100)].all fun (op, gasAfter) =>
  stepOutcome .unzen { jumpPre 0 {} with op } ==
    .ok { gasAfter, outcome := .haltKeep, branch := .memory_step_underflow_halt }
-- RETURN with one of its two items.
#guard stepOutcome .unzen { jumpPre 1 {} with op := 0xf3 } =
  .ok { gasAfter := 100, outcome := .haltKeep, branch := .memory_step_underflow_halt }
-- RETURNDATACOPY needs returndata_size and EXTCODECOPY account_warm once their operands are on
-- the stack; a memory size that is not whole words is an error.
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x3e, stackLen := 3, stack := [0, 0, 1] }) "returndata_size"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x3c, gas := 3000, stackLen := 4, stack := [1, 0, 0, 1] })
  "account_warm"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x51, stackLen := 1, stack := [0], mem := 33 }) "mem"
-- The state-access opcodes read their facts only once their operands are on the stack: SLOAD
-- needs slot_warm, BALANCE, EXTCODESIZE and EXTCODEHASH need account_warm.
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x54, gas := 3000, stackLen := 1, stack := [0] }) "slot_warm"
#guard [0x31, 0x3b, 0x3f].all fun op => failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op, gas := 3000, stackLen := 1, stack := [0] }) "account_warm"
-- SSTORE reads no fact before the sentry: with 2,300 gas it halts keeping all of it; with
-- 2,301 it needs slot_warm, original and current.
#guard stepOutcome .unzen
    { jumpPre 0 {} with op := 0x55, gas := 2300, stackLen := 2, stack := [0, 1] } =
  .ok { gasAfter := 2300, outcome := .haltKeep, branch := .sstore_sentry_halt_preserve }
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x55, gas := 2301, stackLen := 2, stack := [0, 1] }) "slot_warm"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x55, gas := 2301, stackLen := 2, stack := [0, 1],
                      facts := { slotWarm := some true } }) "original"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0x55, gas := 2301, stackLen := 2, stack := [0, 1],
                      facts := { slotWarm := some true, original := some 0 } }) "current"
-- SSTORE pops before the sentry: on one item with 2,300 gas it halts on the underflow.
#guard stepOutcome .unzen
    { jumpPre 0 {} with op := 0x55, gas := 2300, stackLen := 1, stack := [0] } =
  .ok { gasAfter := 2300, outcome := .haltKeep, branch := .sstore_sstore_underflow_preserve }
-- SSTORE, TSTORE and SELFDESTRUCT check the static context before popping: in a static frame
-- on an empty stack each halts on it, keeping the gas left after its static gas.
#guard [(0x55, 6000), (0x5d, 5900), (0xff, 1000)].all fun (op, gasAfter) =>
  stepOutcome .unzen { jumpPre 0 {} with op, gas := 6000, static := true } ==
    .ok { gasAfter, outcome := .haltKeep,
                branch := if op = 0x55 then .sstore_static_frame_halt_preserve
                  else if op = 0x5d then .transient_static_frame_tstore_halt_preserve
                  else .selfdestruct_static_frame_halt_preserve }
-- SELFDESTRUCT reads account_warm at the beneficiary load; a skipped cold load reads nothing
-- more, a load that goes on needs self_balance and account_empty for the new-account charge.
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xff, gas := 7600, stackLen := 1, stack := [0xdead] }) "account_warm"
#guard stepOutcome .unzen
    { jumpPre 0 {} with op := 0xff, gas := 7599, stackLen := 1, stack := [0xdead],
                        facts := { accountWarm := some false } } =
  .ok { gasAfter := 0, outcome := .haltSpendAll,
              branch := .selfdestruct_selfdestruct_cold_load_skipped_spend_all }
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xff, gas := 7600, stackLen := 1, stack := [0xdead],
                      facts := { accountWarm := some false } }) "self_balance"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xff, gas := 7600, stackLen := 1, stack := [0xdead],
                      facts := { accountWarm := some false, selfBalance := some 1 } })
  "account_empty"
/-- A CALL-family pre-state of opcode `op` with `gas` and the stack `stack` (top first), whose
target is warm or not, not empty, and delegated (EIP-7702) to an address of warmth `delegate`
when that is given. -/
def callPre (op gas : Nat) (stack : List Nat) (warm : Bool) (delegate : Option Bool := none) :
    Pre :=
  { op, depth := 1, pc := 0, gas, static := false, stackLen := stack.length, stack, mem := 0,
    facts := { accountWarm := some warm, accountEmpty := some false,
               delegateWarm := some delegate } }

-- Every delegate stage on constructed pre-states: DELEGATECALL without and CALL with a value of
-- 1, gas limit 0 (nothing forwarded), static 100 plus the listed charges. With exactly that gas
-- the frame opens with 0 left, and with 7 gas more it keeps the 7; one gas short, a warm delegate
-- fails its 100 read and a cold one is skipped (both `ColdLoadSkipped`, spending all gas).
def delegateCases : List (Bool × Bool × Bool × Nat × BranchId) :=
  [(false, true, true, 100, .call_family_warm_target_warm_delegate_spawn),
   (false, true, false, 2600, .call_family_warm_target_cold_delegate_spawn),
   (false, false, true, 2600, .call_family_cold_target_warm_delegate_spawn),
   (false, false, false, 5100, .call_family_cold_target_cold_delegate_spawn),
   (true, true, true, 9100, .call_value_warm_target_warm_delegate_spawn),
   (true, true, false, 11600, .call_value_warm_target_cold_delegate_spawn),
   (true, false, true, 11600, .call_value_cold_target_warm_delegate_spawn),
   (true, false, false, 14100, .call_value_cold_target_cold_delegate_spawn)]

/-- The stack of a delegate case: CALL of value 1 or DELEGATECALL, both with zero-length
ranges. -/
def delegatePre (transfer warm delegate : Bool) (gas : Nat) : Pre :=
  if transfer then callPre 0xf1 gas [0, 0xd, 1, 0, 0, 0, 0] warm (some delegate)
  else callPre 0xf4 gas [0, 0xd, 0, 0, 0, 0] warm (some delegate)

#guard delegateCases.all fun (transfer, warm, delegate, cost, branch) =>
  [0, 7].all fun extra =>
    stepOutcome .unzen (delegatePre transfer warm delegate (100 + cost + extra)) ==
      .ok { gasAfter := extra, outcome := .newFrame, branch }
#guard delegateCases.all fun (transfer, warm, delegate, cost, _) =>
  stepOutcome .unzen (delegatePre transfer warm delegate (100 + cost - 1)) ==
    .ok { gasAfter := 0, outcome := .haltSpendAll,
                branch := if delegate then .call_family_delegate_read_oog_spend_all
                  else .call_family_delegate_cold_surcharge_oog_spend_all }
-- CALL checks a value in a static frame after its first pop and before the memory operands:
-- on three items it halts on the value, on two on the stack, and with value 0 on the missing
-- memory operands; all keep the gas left after the static 100.
#guard [(2, 1, BranchId.call_family_underflow_preserve),
    (3, 1, .call_call_static_frame_value_halt_preserve),
    (3, 0, .call_family_underflow_preserve)].all fun (sl, value, branch) =>
  stepOutcome .unzen
      { jumpPre 0 {} with op := 0xf1, gas := 1000, static := true, stackLen := sl,
                          stack := [0, 0xd, value].take sl } ==
    .ok { gasAfter := 900, outcome := .haltKeep, branch }
-- The input range is checked before the output range, and both before the transfer cost and
-- the cold load: CALL of value 1 to a cold target with 1 gas left after its static gas and both
-- lengths 2^64 halts on the input length; with a 32-byte input it halts on the expansion.
#guard stepOutcome .unzen (callPre 0xf1 101 [0, 0xd, 1, 0, 2^64, 0, 2^64] false) =
  .ok { gasAfter := 1, outcome := .haltKeep,
              branch := .call_family_input_size_above_u64_preserve }
#guard stepOutcome .unzen (callPre 0xf1 102 [0, 0xd, 1, 0, 32, 0, 0] false) =
  .ok { gasAfter := 2, outcome := .haltKeep,
              branch := .call_family_input_memory_oog_preserve }
-- The output range expands from the memory the input range left: an output inside the
-- 64-byte input costs nothing more.
#guard stepOutcome .unzen (callPre 0xf4 106 [0, 0xd, 0, 64, 0, 32] true) =
  .ok { gasAfter := 0, outcome := .newFrame, branch := .call_family_warm_target_spawn }
-- The frame gets all but one 64th of the gas left, capped by the gas limit saturated to u64.
#guard stepOutcome .unzen (callPre 0xfa 6500 [2^256 - 1, 0xd, 0, 0, 0, 0] true) =
  .ok { gasAfter := 100, outcome := .newFrame, branch := .call_family_warm_target_spawn,
        forwarded := 6300 }
#guard stepOutcome .unzen (callPre 0xfa 6500 [6000, 0xd, 0, 0, 0, 0] true) =
  .ok { gasAfter := 400, outcome := .newFrame, branch := .call_family_warm_target_spawn,
        forwarded := 6000 }
-- The CALL family reads account_warm at the target load; only CALL reads account_empty, and
-- a CALL to an empty target stops there, so only the other cases read delegate_warm.
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xfa, gas := 3000, stackLen := 6, stack := [0, 0xd, 0, 0, 0, 0] })
  "account_warm"
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xf1, gas := 20000, stackLen := 7, stack := [0, 0xd, 1, 0, 0, 0, 0],
                      facts := { accountWarm := some true } }) "account_empty"
-- The transfer cost comes before the target load: CALL of value 1 with 2,900 gas left after its
-- static gas halts on it without reading a fact.
#guard stepOutcome .unzen
    { jumpPre 0 {} with op := 0xf1, gas := 3000, stackLen := 7, stack := [0, 0xd, 1, 0, 0, 0, 0] } =
  .ok { gasAfter := 0, outcome := .haltSpendAll,
              branch := .call_value_transfer_oog_spend_all }
#guard failsWith (stepOutcome .unzen
  { jumpPre 0 {} with op := 0xfa, gas := 3000, stackLen := 6, stack := [0, 0xd, 0, 0, 0, 0],
                      facts := { accountWarm := some true } }) "delegate_warm"
#guard stepOutcome .unzen
    { jumpPre 0 {} with op := 0xf1, gas := 3000, stackLen := 7, stack := [0, 0xd, 0, 0, 0, 0, 0],
                        facts := { accountWarm := some true, accountEmpty := some true } } =
  .ok { gasAfter := 2900, outcome := .newFrame, branch := .call_family_warm_target_spawn }
-- The CALL fixture with the step model: its spawn step keeps 0x863d after forwarding 0xffff,
-- and the frame resumes with that plus the 0xffc3 the precompile left.
#guard run callVector callHarness =
  .ok { events := 4, steps := 2, branches := ["call_family_warm_target_spawn", "static_stop_halt"] }
-- The checker compares a spawn step's gas_after with the model's too.
#guard failsWith (run callVector (callHarness.set 0 (callStep (gasAfter := "0x863e"))))
  "event 0: model branch call_family_warm_target_spawn: gas_after 0x863d, trace gas_after 0x863e"
-- The smoke harness trace with the step model: every step is modeled.
#guard run smokeHarnessVector smokeHarness =
  .ok { events := 5, steps := 4,
        branches := ["static_stack_success", "static_stack_success", "static_arith_success",
                     "static_stop_halt"] }

/-- A JUMP step event with gas 100 that pays its static 8 (4 zk gas each) and whose pre-state
has the facts `facts`. -/
def jumpEvent (facts : Facts) : Event :=
  .step (jumpPre 1 facts) { gasAfter := 92, spawn := false, zk := 32, ok := true, charged := true }

-- No step may go unchecked: a hand-made JUMP whose pre-state lacks the jumpdest_valid fact the
-- model reads (a step the parser rejects) fails the check; with the fact it passes.
#guard failsWith (checkVectorEvents smokeHarnessVector [jumpEvent {}, .frameEnd "halt" 32] stepModel)
  "event 0: facts: the step records no jumpdest_valid, which the model needs"
#guard checkVectorEvents (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x20\",\"status\":\"halt\"}")
    [jumpEvent { jumpdestValid := some false }, .frameEnd "halt" 32] stepModel =
  .ok { events := 2, steps := 1, branches := ["jump_jump_invalid_target_halt"] }

/-! ### Outcomes against the trace

The checker holds each modeled step's outcome to the event after it: a step that continues is
followed by a step at its depth; a step that ends a child frame by a step one depth up, and one
that ends the top frame by the end of the tx or frame, where a harness trace's `frame_end` has
the status of its outcome; a step that opens a frame by a step one deeper, a precompile or a
step at its depth, never by the end. A step whose charge the meter rejects ends the tx and is not
checked. Most guards flip one modeled step's outcome in a trace the step model passes. -/

/-- `model` with the outcome of the step at depth `d` and pc `pc` replaced by `o`. -/
def flipAt (d pc : Nat) (o : Outcome) (model : Model := stepModel) : Model := fun p => do
  let m ← model p
  pure { m with outcome := if p.depth = d ∧ p.pc = pc then o else m.outcome }

-- PUSH1 that ends its frame, though the frame goes on at its depth.
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 0 .haltKeep))
  "event 0: model branch static_stack_success: outcome haltKeep ends a frame at depth 1, but the next event is a step at depth 1"
-- STOP that continues, though frame_end follows; STOP that ends with another status.
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .continue))
  "event 3: model branch static_stop_halt: outcome continue, but the next event is frame_end"
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .revert))
  "event 3: model branch static_stop_halt: outcome revert ends the top frame with status revert, but frame_end has status success"
#guard failsWith (run smokeHarnessVector smokeHarness (flipAt 1 5 .haltSpendAll))
  "event 3: model branch static_stop_halt: outcome haltSpendAll ends the top frame with status halt, but frame_end has status success"
-- The anchor's STOP in a block trace: tx_end follows it, so it cannot continue.
#guard (run (blockVector smokeBlockExpected) smokeBlock).isOk
#guard failsWith (run (blockVector smokeBlockExpected) smokeBlock (flipAt 1 0 .continue))
  "event 1: model branch static_stop_halt: outcome continue, but the next event is tx_end"
-- A rejected charge ends the frame whatever the step's outcome: ADD continues, frame_end follows.
#guard (run zkLimitVector zkLimitHarness).isOk

/-- The CALL of `callStep` at depth `d` and pc `pc`, which opens a frame. With its default gas it
forwards 0xffff; inside the frame a CALL at depth 1 opens (gas 0xffff, `gas_after` 0x3fe), it
forwards 0xfb9d, all but one 64th of the 0xff9b left after its static 100. -/
def callAt (d pc : Nat) (gas : String := "0x186a0") (gasAfter : String := "0x863d") : String :=
  stepLine d pc 0xf1 gas 7 "\"0xffff\",\"0x2\",\"0x0\",\"0x0\",\"0x0\",\"0x0\",\"0x0\""
    gasAfter "0x3d090" "\"account_warm\":true,\"account_empty\":false,\"delegate_warm\":null"
    (spawn := true)

/-- A harness vector whose expected values the guards below never reach. -/
def anyHarness : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x0\",\"status\":\"success\"}"

-- A spawn step followed by a step at a smaller depth fails.
#guard failsWith (run anyHarness
  [callAt 1 0, callAt 2 0 "0xffff" "0x3fe", stepLine 1 1 0x00 "0x186a0" 1 "" "0x186a0" "0x0"])
  "event 1: model branch call_family_warm_target_spawn: outcome newFrame, but the next event is a step at depth 1"
-- A step that ends a child frame resumes exactly the frame one depth up: a STOP at depth 3
-- followed by a step at depth 1, and a STOP at depth 2 followed by frame_end, fail.
#guard failsWith (run anyHarness
  [callAt 1 0, callAt 2 0 "0xffff" "0x3fe", stepLine 3 0 0x00 "0xfb9d" 0 "" "0xfb9d" "0x0",
   stepLine 1 1 0x00 "0x186a0" 1 "" "0x186a0" "0x0"])
  "event 2: model branch static_stop_halt: outcome success ends a frame at depth 3, but the next event is a step at depth 1"
#guard failsWith (run anyHarness
  [callAt 1 0, stepLine 2 0 0x00 "0xffff" 0 "" "0xffff" "0x0", frameEndLine "success" "\"0x3d090\""])
  "event 1: model branch static_stop_halt: outcome success ends a frame at depth 2, but the next event is frame_end"
-- A step that opens a frame is never followed by the end of its tx or frame (its frame resumes
-- with a step, or a rejected charge ends the trace), nor by the next tx's intrinsic charge.
#guard failsWith (run callVector [callStep, frameEndLine "success" "\"0x3d090\""])
  "event 0: model branch call_family_warm_target_spawn: outcome newFrame, but the next event is frame_end"
#guard failsWith (run (blockVector smokeBlockExpected)
  [intrinsicLine, callStep, txEndLine 0 "committed" "\"0x785c8\"", intrinsicLine, txEndLine 1])
  "event 1: model branch call_family_warm_target_spawn: outcome newFrame, but the next event is tx_end"
#guard failsWith (run (blockVector smokeBlockExpected)
  [intrinsicLine, callStep, intrinsicLine, txEndLine 0, intrinsicLine, txEndLine 1])
  "event 2: intrinsic before the previous tx's tx_end"
-- A step that ends its frame is never followed by a precompile run: the top frame's STOP, and a
-- child frame's STOP.
#guard failsWith (run smokeHarnessVector
  (smokeHarness.take 4 ++ [sha256Line "0xffff" "0xffc3" true "0x258", frameEndLine]))
  "event 4: precompile event must follow a CALL-family spawn step"
#guard failsWith (run anyHarness
  [callAt 1 0, stepLine 2 0 0x00 "0xffff" 0 "" "0xffff" "0x0", sha256Line "0xffff" "0xffc3" true "0x258"])
  "event 2: precompile event must follow a CALL-family spawn step"

/-! ### The gas a frame gets back

A frame that opened a child resumes with its spawn step's `gas_after` plus what the child gives
back: the child's gas left when its last step's outcome is `success` or `revert` (less a
CREATE's code deposit), and nothing when it halts; after a precompile, the gas the precompile
left. The traces below are committed reth traces, copied verbatim; each guard flips the outcome
of a child's last step, or changes what a precompile left, and the checker rejects it. -/

/-- The committed trace of `call.delegate.value_cold_target_cold_delegate_exact_gas`. -/
def stipendReturnTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x3788\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3786\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":95,\"gas\":\"0x3786\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3784\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":95,\"gas\":\"0x3784\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3782\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":95,\"gas\":\"0x3782\",\"static\":false,\"sl\":3,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3780\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":96,\"gas\":\"0x3780\",\"static\":false,\"sl\":4,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x377d\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":97,\"gas\":\"0x377d\",\"static\":false,\"sl\":5,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x377a\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":95,\"gas\":\"0x377a\",\"static\":false,\"sl\":6,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x3778\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x3778\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xde1e\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":false},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":0,\"gas\":\"0x8fc\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8fc\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":0,\"gas\":\"0x8fc\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8fc\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x3d145\"}"]

/-- The vector `call.delegate.value_cold_target_cold_delegate_exact_gas`'s zk block limit and expected values. -/
def stipendReturnVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x3d145\",\"status\":\"success\"}"

/-- The committed trace of `log.static_frame.log0_underflow`. -/
def haltReturnTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":95,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869c\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":95,\"gas\":\"0x1869c\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":95,\"gas\":\"0x1869a\",\"static\":false,\"sl\":3,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18698\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":97,\"gas\":\"0x18698\",\"static\":false,\"sl\":4,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18695\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":97,\"gas\":\"0x18695\",\"static\":false,\"sl\":5,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x18692\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":250,\"gas\":\"0x18692\",\"static\":false,\"sl\":6,\"stack\":[\"0x2710\",\"0xda7a\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":false,\"delegate_warm\":null},\"gas_after\":\"0x1555a\",\"spawn\":true,\"zk\":\"0x13a74\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":96,\"gas\":\"0x2710\",\"static\":true,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x270d\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":160,\"gas\":\"0x270d\",\"static\":true,\"sl\":1,\"stack\":[\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x2596\",\"spawn\":false,\"zk\":\"0x465\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":0,\"gas\":\"0x1555a\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1555a\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x13f8c\"}"]

/-- The vector `log.static_frame.log0_underflow`'s zk block limit and expected values. -/
def haltReturnVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x13f8c\",\"status\":\"success\"}"

/-- The committed trace of `create.family.spawn_reaches_limit`. -/
def createReturnTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":95,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869c\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":95,\"gas\":\"0x1869c\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":240,\"gas\":\"0x1869a\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x426\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":0,\"gas\":\"0x10574\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x10574\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":0,\"gas\":\"0x1099a\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1099a\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x90d6\"}"]

/-- The vector `create.family.spawn_reaches_limit`'s zk block limit and expected values. -/
def createReturnVector : String :=
  harnessVector "0x90d6" "{\"frame_zk_gas\":\"0x90d6\",\"status\":\"success\"}"

/-- The committed trace of `create.create.code_deposit_exact_gas`. -/
def depositReturnTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":99,\"gas\":\"0x9682\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x967f\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":95,\"gas\":\"0x967f\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x967d\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":82,\"gas\":\"0x967d\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x60205ff3\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x9677\",\"spawn\":false,\"zk\":\"0xae\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":96,\"gas\":\"0x9677\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x9674\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":96,\"gas\":\"0x9674\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x9671\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":95,\"gas\":\"0x9671\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x966f\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":240,\"gas\":\"0x966f\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x1c\",\"0x4\"],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x65\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":96,\"gas\":\"0x1908\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1905\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":95,\"gas\":\"0x1905\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1903\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":243,\"gas\":\"0x1903\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1900\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":96,\"gas\":\"0x65\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x62\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":87,\"gas\":\"0x62\",\"static\":false,\"sl\":2,\"stack\":[\"0x17\",\"0x8bbc3514477d75ec797bbe4e19d7961660bb849c\"],\"mem\":\"0x20\",\"facts\":{\"jumpdest_valid\":true},\"gas_after\":\"0x58\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":23,\"op\":91,\"gas\":\"0x58\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x57\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":24,\"op\":0,\"gas\":\"0x57\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x57\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x9254\"}"]

/-- The vector `create.create.code_deposit_exact_gas`'s zk block limit and expected values. -/
def depositReturnVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x9254\",\"status\":\"success\"}"

-- A CALL of value 1 whose child (a STOP) gives back its 2,300 stipend: a halt would give back
-- nothing.
#guard (run stipendReturnVector stipendReturnTrace).isOk
#guard failsWith (run stipendReturnVector stipendReturnTrace (flipAt 2 0 .haltKeep))
  "event 9: gas 0x8fc, but the frame resumes with gas_after 0x0 of its spawn step (event 7) plus [0x0], what its child gives back after outcome haltKeep with 0x8fc left (event 8, model branch static_stop_halt)"
#guard failsWith (run stipendReturnVector stipendReturnTrace (flipAt 2 0 .haltSpendAll)) "event 9: gas 0x8fc"
-- A LOG0 in a static frame halts keeping 0x2596 gas, which its caller does not get back: as a
-- success or revert it would.
#guard (run haltReturnVector haltReturnTrace).isOk
#guard failsWith (run haltReturnVector haltReturnTrace (flipAt 2 2 .success))
  "event 9: gas 0x1555a, but the frame resumes with gas_after 0x1555a of its spawn step (event 6) plus [0x2596], what its child gives back after outcome success with 0x2596 left (event 8, model branch log_static_frame_halt_preserve)"
#guard failsWith (run haltReturnVector haltReturnTrace (flipAt 2 2 .revert)) "event 9: gas 0x1555a"
-- A CREATE of empty initcode, whose implicit STOP gives back all the gas it forwarded.
#guard (run createReturnVector createReturnTrace).isOk
#guard failsWith (run createReturnVector createReturnTrace (flipAt 2 0 .haltKeep)) "event 5: gas 0x1099a"
-- A CREATE whose initcode RETURNs 32 bytes with exactly the 6,400 gas of their code deposit,
-- which it spends: the caller gets nothing back, as it would for a halt; a revert would give
-- back the 6,400.
#guard (run depositReturnVector depositReturnTrace).isOk
#guard (run depositReturnVector depositReturnTrace (flipAt 2 3 .haltKeep)).isOk
#guard failsWith (run depositReturnVector depositReturnTrace (flipAt 2 3 .revert))
  "event 10: gas 0x65, but the frame resumes with gas_after 0x65 of its spawn step (event 6) plus [0x1900]"
/-- The committed trace of `create.create.code_deposit_spare_gas`. -/
def depositSpareTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":99,\"gas\":\"0x98e4\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x98e1\",\"spawn\":false,\"zk\":\"0x1e\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":95,\"gas\":\"0x98e1\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x98df\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":82,\"gas\":\"0x98df\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x60205ff3\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x98d9\",\"spawn\":false,\"zk\":\"0xae\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":7,\"op\":96,\"gas\":\"0x98d9\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x98d6\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":96,\"gas\":\"0x98d6\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x98d3\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":95,\"gas\":\"0x98d3\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x98d1\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":240,\"gas\":\"0x98d1\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x1c\",\"0x4\"],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x6f\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":0,\"op\":96,\"gas\":\"0x1b60\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1b5d\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":2,\"op\":95,\"gas\":\"0x1b5d\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1b5b\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":2,\"pc\":3,\"op\":243,\"gas\":\"0x1b5b\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x20\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1b58\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":13,\"op\":96,\"gas\":\"0x2c7\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x2c4\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":15,\"op\":87,\"gas\":\"0x2c4\",\"static\":false,\"sl\":2,\"stack\":[\"0x17\",\"0x8bbc3514477d75ec797bbe4e19d7961660bb849c\"],\"mem\":\"0x20\",\"facts\":{\"jumpdest_valid\":true},\"gas_after\":\"0x2ba\",\"spawn\":false,\"zk\":\"0x32\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":23,\"op\":91,\"gas\":\"0x2ba\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x2b9\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":24,\"op\":0,\"gas\":\"0x2b9\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x20\",\"facts\":{},\"gas_after\":\"0x2b9\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x9254\"}"]

/-- The vector `create.create.code_deposit_spare_gas`'s zk block limit and expected values. -/
def depositSpareVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x9254\",\"status\":\"success\"}"

-- The same CREATE with 7,000 gas left at its RETURN of 32 bytes: it pays the 6,400 deposit and
-- gives back the other 600, so the creator resumes with 0x6f + 0x258. One gas more fails, and so
-- does a deposit left unpaid (a revert would give back all 0x1b58).
#guard (run depositSpareVector depositSpareTrace).isOk
#guard failsWith (run depositSpareVector
  (depositSpareTrace.set 10 ((((depositSpareTrace.getD 10 "").replace "\"gas\":\"0x2c7\"" "\"gas\":\"0x2c8\"").replace
    "\"gas_after\":\"0x2c4\"" "\"gas_after\":\"0x2c5\""))))
  "event 10: gas 0x2c8, but the frame resumes with gas_after 0x6f of its spawn step (event 6) plus [0x258, 0x0]"
#guard failsWith (run depositSpareVector depositSpareTrace (flipAt 2 3 .revert))
  "event 10: gas 0x2c7, but the frame resumes with gas_after 0x6f of its spawn step (event 6) plus [0x1b58]"
-- The CALL fixture's sha256 run with one gas more left (the zk gas to match): its caller would
-- resume with 0x863d + 0xffc4.
#guard failsWith (run callVector (callHarness.set 1 (sha256Line "0xffff" "0xffc4" true "0x24e")))
  "event 2: a step at depth 1 with gas 0x18600, but the precompile run of event 1 leaves 0xffc4 to the spawn step of gas_after 0x863d, so its caller resumes at depth 1 with 0x18601"
-- The returned gas of each outcome.
#guard returnedGas false .success 5 7 = [5] ∧ returnedGas false .revert 5 0 = [5] ∧
  returnedGas false .haltKeep 5 0 = [0] ∧ returnedGas false .haltSpendAll 0 0 = [0]
#guard returnedGas true .success 6400 32 = [0, 0] ∧ returnedGas true .success 6399 32 = [0] ∧
  returnedGas true .success 7000 32 = [600, 0] ∧ returnedGas true .success 10 0 = [10] ∧
  returnedGas true .success (2^30) 24577 = [0]

/-! ### The gas a step hands on

Every step but a tx's or frame's first starts from the gas the event before it hands on: a step
that continues hands its `gas_after` to the next step at its depth; a step that opens a frame
gives the new frame the gas it forwards plus a value transfer's 2,300 stipend, which the frame's
first step starts with or the precompile run it opened is supplied, at the step's target address;
and when the new frame runs no step, the step's frame resumes with its `gas_after` plus that gas
(a CREATE, or a CALL with a value, may instead lose it). Each guard changes one gas value of a
committed reth trace, copied verbatim, or of the CALL fixture, and the checker rejects it. -/

-- The smoke trace's second PUSH1 with one gas more before and after it (its zk gas unchanged):
-- the first PUSH1 left 0x1869d.
#guard failsWith (run smokeHarnessVector (smokeHarness.set 1 (push1 2 1 "0x1869e" "0x1869b")))
  "event 0: model branch static_stack_success: outcome continue with gas_after 0x1869d, but the next step at its depth has gas 0x1869e"
-- A CALL of value 1 with gas limit 0 forwards nothing: its child starts with the 2,300 stipend,
-- not one gas more.
#guard failsWith (run stipendReturnVector
  (stipendReturnTrace.set 8 ((stipendReturnTrace.getD 8 "").replace "\"0x8fc\"" "\"0x8fd\"")))
  "event 7: model branch call_value_cold_target_cold_delegate_spawn: outcome newFrame opens a frame with 0x8fc gas (forwarded, plus a value transfer's stipend), but its first step has gas 0x8fd"
-- A CREATE of empty initcode forwards all but one 64th of the 0x1099a left after its 32,000
-- base: 0x10574, which its implicit STOP starts with.
#guard failsWith (run createReturnVector
  (createReturnTrace.set 4 ((createReturnTrace.getD 4 "").replace "\"0x10574\"" "\"0x10575\"")))
  "event 3: model branch create_create_new_frame_spawn_estimate: outcome newFrame opens a frame with 0x10574 gas (forwarded, plus a value transfer's stipend), but its first step has gas 0x10575"
-- The CALL fixture forwards 0xffff to sha256 at its target 0x2, with no value and so no stipend:
-- a run supplied one gas more, or a CALL to another target, fails.
#guard failsWith (run callVector (callHarness.set 1 (sha256Line "0x10000" "0xffc4" true "0x258")))
  "event 0: model branch call_family_warm_target_spawn: outcome newFrame opens a frame with 0xffff gas (forwarded, plus a value transfer's stipend), but the precompile run is supplied 0x10000"
#guard failsWith (run callVector
  (callHarness.set 0 (String.replace callStep "\"0xffff\",\"0x2\"" "\"0xffff\",\"0x3\"")))
  "event 0: model branch call_family_warm_target_spawn: outcome newFrame calls 0x3, but the precompile run is at 0x2"

/-- The committed trace of `call.call.new_account_exact_gas`. -/
def newAccountTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x8f08\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8f06\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":95,\"gas\":\"0x8f06\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8f04\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":95,\"gas\":\"0x8f04\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8f02\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":95,\"gas\":\"0x8f02\",\"static\":false,\"sl\":3,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8f00\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":96,\"gas\":\"0x8f00\",\"static\":false,\"sl\":4,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8efd\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":6,\"op\":97,\"gas\":\"0x8efd\",\"static\":false,\"sl\":5,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8efa\",\"spawn\":false,\"zk\":\"0x18\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":9,\"op\":95,\"gas\":\"0x8efa\",\"static\":false,\"sl\":6,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8ef8\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":10,\"op\":241,\"gas\":\"0x8ef8\",\"static\":false,\"sl\":7,\"stack\":[\"0x0\",\"0xdead\",\"0x1\",\"0x0\",\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{\"account_warm\":false,\"account_empty\":true,\"delegate_warm\":null},\"gas_after\":\"0x0\",\"spawn\":true,\"zk\":\"0x3d090\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":0,\"gas\":\"0x8fc\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x8fc\",\"spawn\":false,\"zk\":\"0x0\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"success\",\"frame_zk\":\"0x3d145\"}"]

/-- The vector `call.call.new_account_exact_gas`'s zk block limit and expected values. -/
def newAccountVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x3d145\",\"status\":\"success\"}"

/-- The committed trace of `create.create.collision_nonce`. -/
def collisionTrace : List String :=
  ["{\"e\":\"step\",\"d\":1,\"pc\":0,\"op\":95,\"gas\":\"0x186a0\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869e\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":1,\"op\":95,\"gas\":\"0x1869e\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869c\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":2,\"op\":95,\"gas\":\"0x1869c\",\"static\":false,\"sl\":2,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x1869a\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":3,\"op\":240,\"gas\":\"0x1869a\",\"static\":false,\"sl\":3,\"stack\":[\"0x0\",\"0x0\",\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x426\",\"spawn\":true,\"zk\":\"0x9088\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":4,\"op\":80,\"gas\":\"0x426\",\"static\":false,\"sl\":1,\"stack\":[\"0x0\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x424\",\"spawn\":false,\"zk\":\"0x14\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":5,\"op\":100,\"gas\":\"0x424\",\"static\":false,\"sl\":0,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x421\",\"spawn\":false,\"zk\":\"0x1b\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":11,\"op\":95,\"gas\":\"0x421\",\"static\":false,\"sl\":1,\"stack\":[],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x41f\",\"spawn\":false,\"zk\":\"0x1a\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"step\",\"d\":1,\"pc\":12,\"op\":32,\"gas\":\"0x41f\",\"static\":false,\"sl\":2,\"stack\":[\"0x0\",\"0x100000000\"],\"mem\":\"0x0\",\"facts\":{},\"gas_after\":\"0x0\",\"spawn\":false,\"zk\":\"0x7fc1\",\"ok\":true,\"charged\":true}",
   "{\"e\":\"frame_end\",\"status\":\"halt\",\"frame_zk\":\"0x110e0\"}"]

/-- The vector `create.create.collision_nonce`'s zk block limit and expected values. -/
def collisionVector : String :=
  harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x110e0\",\"status\":\"halt\"}"

-- A CALL of value 1 with gas limit 0 to an account without code: its frame runs no step and
-- hands back the 2,300 stipend, so the caller resumes with 0 + 0 + 0x8fc, not one gas more. A
-- CALL with a value may also lose that gas (a transfer that overflows the target's balance
-- halts), so resuming with its gas_after 0 alone passes.
#guard (run newAccountVector newAccountTrace).isOk
#guard failsWith (run newAccountVector
  (newAccountTrace.set 8 ((newAccountTrace.getD 8 "").replace "\"0x8fc\"" "\"0x8fd\"")))
  "event 7: model branch call_call_new_account_cold_target_spawn: outcome newFrame with gas_after 0x0 opens a frame of 0x8fc gas that runs no step, so its frame resumes with one of [0x8fc, 0x0], but the next step at its depth has gas 0x8fd"
#guard (run newAccountVector
  (newAccountTrace.set 8 ((newAccountTrace.getD 8 "").replace "\"0x8fc\"" "\"0x0\""))).isOk
-- The CALL fixture without its precompile run: a CALL without a value whose frame runs no step
-- hands back all 0xffff, so the caller resumes with 0x863d + 0xffff and cannot lose it.
#guard (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x3d090\",\"status\":\"success\"}")
  [callStep, stepLine 1 1 0x00 "0x1863c" 1 "" "0x1863c" "0x0", frameEndLine "success" "\"0x3d090\""]).isOk
#guard failsWith (run (harnessVector "0x5f5e100" "{\"frame_zk_gas\":\"0x3d090\",\"status\":\"success\"}")
  [callStep, stepLine 1 1 0x00 "0x863d" 1 "" "0x863d" "0x0", frameEndLine "success" "\"0x3d090\""])
  "event 0: model branch call_family_warm_target_spawn: outcome newFrame with gas_after 0x863d opens a frame of 0xffff gas that runs no step, so its frame resumes with one of [0x1863c], but the next step at its depth has gas 0x863d"
-- A CREATE whose address collides: its frame runs no step and the 0x10574 it forwarded is lost
-- (an address collision halts), so the creator resumes with its gas_after 0x426. It could also
-- get the gas back (the creator's balance, nonce or the depth limit), but never one gas more.
#guard (run collisionVector collisionTrace).isOk
#guard failsWith (run collisionVector
  (collisionTrace.set 4 (((collisionTrace.getD 4 "").replace "\"gas\":\"0x426\"" "\"gas\":\"0x427\"").replace
    "\"gas_after\":\"0x424\"" "\"gas_after\":\"0x425\"")))
  "event 3: model branch create_create_new_frame_spawn_estimate: outcome newFrame with gas_after 0x426 opens a frame of 0x10574 gas that runs no step, so its frame resumes with one of [0x1099a, 0x426], but the next step at its depth has gas 0x427"
-- The no-step resume of each opcode: only CREATE, CREATE2 and CALL with a value may lose the gas.
#guard noChildResume 0xf1 true 5 7 = [12, 5] ∧ noChildResume 0xf1 false 5 7 = [12] ∧
  noChildResume 0xf2 true 5 7 = [12] ∧ noChildResume 0xf4 false 5 7 = [12] ∧
  noChildResume 0xfa false 5 7 = [12] ∧ noChildResume 0xf0 false 5 7 = [12, 5] ∧
  noChildResume 0xf5 false 5 7 = [12, 5]

/-! ### The coverage gate -/

-- Every branch is listed once, and none is unreachable.
#guard allBranches.length = 158 ∧ allBranches.eraseDups.length = 158 ∧ unreachableBranches = []
-- The gate counts steps by branch name, so every name is its constructor's name and no two
-- branches share one.
#guard allBranches.all fun b => some b.name == ((reprStr b).splitOn ".").getLast?
#guard (allBranches.map (·.name)).eraseDups.length = allBranches.length
-- A corpus that reaches every branch passes; a branch without a step and a branch name outside
-- `allBranches` fail.
#guard coverageErrors (allBranches.map fun b => (b.name, 1)) = []
#guard coverageErrors ((allBranches.drop 1).map fun b => (b.name, 1)) =
  ["1 branch has no step: static_step_static_oog_spend_all"]
#guard coverageErrors (("bogus", 2) :: allBranches.map fun b => (b.name, 1)) =
  ["2 steps report branch bogus, which allBranches does not list"]
