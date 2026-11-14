import ZkGasModel.Tables
import ZkGasModel.Step.Basic
import ZkGasModel.Step.Static
import ZkGasModel.Step.Jump
import ZkGasModel.Step.Exp
import ZkGasModel.Step.Memory
import ZkGasModel.Step.Copy
import ZkGasModel.Step.Return
import ZkGasModel.Step.Log
import ZkGasModel.Step.Account
import ZkGasModel.Step.Storage
import ZkGasModel.Step.Call
import ZkGasModel.Step.Create

/-!
# The step model

`stepOutcome f pre` is the outcome of the one interpreter step that runs from `pre`: the
frame's gas after it, how it ended and the model branch that decided it. Every opcode is
modeled. It is an error when `pre` lacks a fact or stack item the model reads.
The result types are in `ZkGasModel.Step.Basic`; each opcode category's instruction body
is in its own file `ZkGasModel/Step/<Category>.lean`.

The model follows alethia-reth's metered loop (`crates/evm/src/zk_gas/runtime.rs`,
`run_metered_plain`, lines 48-62), which calls revm-interpreter 43.0.1's `Interpreter::step`
(`src/interpreter.rs:295`) and materializes an exceptional halt before charging the step. Every
step goes through the same stages:

1. `classify` picks the opcode's category; every opcode has one.
2. `step` charges the opcode's static gas `staticGas op` with `record_cost_unsafe`
   (`interpreter.rs:312`). When the frame cannot pay it, `step` returns `OutOfGas` before the
   instruction runs (`interpreter.rs:314`), and `Interpreter::halt` spends all remaining gas
   (`interpreter.rs:207-209`): gas after 0, branch `static_step_static_oog_spend_all`. Static
   gas comes before any stack, fork or jump check.
3. The instruction body runs with the gas left after the static charge (`body`). Its checks
   return `StackUnderflow`, `StackOverflow`, `InvalidJump`, `NotActivated`, `InvalidFEOpcode`,
   `OpcodeNotFound`, `InvalidOperandOOG`, `MemoryOOG`, `OutOfOffset`, `ReentrancySentryOOG`,
   `StateChangeDuringStaticCall`, `CallNotAllowedInsideStatic` or `CreateInitCodeSizeLimit`,
   which halt keeping the gas; a `gas!` charge that cannot be paid, and a cold account or slot
   load skipped for lack of gas, return `OutOfGas`, which spends all of it. STOP, RETURN,
   REVERT and SELFDESTRUCT end the frame keeping the gas. A CALL or CREATE family instruction
   that passes its checks installs `NewFrame` and returns `Suspend`: the step opens a new
   frame.

Each category has a `Category` constructor, its `classify` case, a body file and a `body` case;
the stages above are the same for all of them.
-/
namespace TaikoSpec.ZkGas

/-- The opcode categories the step model covers. -/
inductive Category
  /-- STOP. -/
  | stop
  /-- ADD..SIGNEXTEND except EXP. -/
  | arith
  /-- EXP. -/
  | exp
  /-- LT..SAR and CLZ. -/
  | bitwise
  /-- POP. -/
  | pop
  /-- PUSH0..PUSH32. -/
  | push
  /-- DUPn. -/
  | dup (n : Nat)
  /-- SWAPn. -/
  | swap (n : Nat)
  /-- The push-only environment reads (`envReads`). -/
  | env
  /-- SELFBALANCE. -/
  | selfbalance
  /-- CALLDATALOAD. -/
  | calldataload
  /-- BLOBHASH. -/
  | blobhash
  /-- BLOCKHASH. -/
  | blockhash
  /-- JUMP. -/
  | jump
  /-- JUMPI. -/
  | jumpi
  /-- JUMPDEST. -/
  | jumpdest
  /-- MLOAD and MSTORE (`len` 32) and MSTORE8 (`len` 1). -/
  | memoryAccess (len : Nat)
  /-- MCOPY. -/
  | mcopy
  /-- KECCAK256. -/
  | keccak
  /-- CALLDATACOPY and CODECOPY. -/
  | dataCopy
  /-- RETURNDATACOPY. -/
  | returndatacopy
  /-- EXTCODECOPY. -/
  | extcodecopy
  /-- RETURN (`revert` false) and REVERT (`revert` true). -/
  | ret (revert : Bool)
  /-- LOG0..LOG4 with `n` topics. -/
  | log (n : Nat)
  /-- BALANCE, EXTCODESIZE and EXTCODEHASH. -/
  | accountAccess
  /-- SELFDESTRUCT. -/
  | selfdestruct
  /-- SLOAD. -/
  | sload
  /-- SSTORE. -/
  | sstore
  /-- TLOAD. -/
  | tload
  /-- TSTORE. -/
  | tstore
  /-- CALL, CALLCODE, DELEGATECALL and STATICCALL. -/
  | call
  /-- CREATE (`create2` false) and CREATE2 (`create2` true). -/
  | create (create2 : Bool)
  /-- An opcode that halts as soon as its body runs (not activated on Unzen, INVALID or
  undefined), with the branch it reports. -/
  | halt (branch : BranchId)
  deriving Repr, DecidableEq

/-- The environment reads whose body only pushes one item: ADDRESS, ORIGIN, CALLER, CALLVALUE,
CALLDATASIZE, CODESIZE, GASPRICE, RETURNDATASIZE, COINBASE, TIMESTAMP, NUMBER, DIFFICULTY,
GASLIMIT, CHAINID, BASEFEE, BLOBBASEFEE, PC, MSIZE and GAS. -/
def envReads : List Nat :=
  [0x30, 0x32, 0x33, 0x34, 0x36, 0x38, 0x3a, 0x3d, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x48,
   0x4a, 0x58, 0x59, 0x5a]

/-- The category of opcode `op`. The opcodes no case names are those revm-bytecode does not
define (`staticGasEntries` has no entry, as a guard in `ZkGasWitnesses` checks for every opcode
byte); revm's instruction table maps exactly those opcodes to `unknown`
(`src/instructions.rs`). -/
def classify (op : Nat) : Category :=
  if op = 0x00 then .stop
  else if op = 0x0a then .exp
  else if 0x01 ≤ op ∧ op ≤ 0x0b then .arith
  else if 0x10 ≤ op ∧ op ≤ 0x1e then .bitwise
  else if op = 0x35 then .calldataload
  else if op = 0x40 then .blockhash
  else if op = 0x47 then .selfbalance
  else if op = 0x49 then .blobhash
  else if envReads.contains op then .env
  else if op = 0x50 then .pop
  else if op = 0x56 then .jump
  else if op = 0x57 then .jumpi
  else if op = 0x5b then .jumpdest
  else if op = 0x51 ∨ op = 0x52 then .memoryAccess 32
  else if op = 0x53 then .memoryAccess 1
  else if op = 0x5e then .mcopy
  else if op = 0x20 then .keccak
  else if op = 0x37 ∨ op = 0x39 then .dataCopy
  else if op = 0x3e then .returndatacopy
  else if op = 0x3c then .extcodecopy
  else if op = 0xf3 then .ret false
  else if op = 0xfd then .ret true
  else if 0xa0 ≤ op ∧ op ≤ 0xa4 then .log (op - 0xa0)
  else if op = 0x31 ∨ op = 0x3b ∨ op = 0x3f then .accountAccess
  else if op = 0xff then .selfdestruct
  else if op = 0x54 then .sload
  else if op = 0x55 then .sstore
  else if op = 0x5c then .tload
  else if op = 0x5d then .tstore
  else if op = 0xf1 ∨ op = 0xf2 ∨ op = 0xf4 ∨ op = 0xfa then .call
  else if op = 0xf0 then .create false
  else if op = 0xf5 then .create true
  else if 0x5f ≤ op ∧ op ≤ 0x7f then .push
  else if 0x80 ≤ op ∧ op ≤ 0x8f then .dup (op - 0x7f)
  else if 0x90 ≤ op ∧ op ≤ 0x9f then .swap (op - 0x8f)
  else if op = 0x4b then .halt .notactivated_slotnum_static_then_halt
  else if op = 0xe6 then .halt .notactivated_dupn_static_then_halt
  else if op = 0xe7 then .halt .notactivated_swapn_static_then_halt
  else if op = 0xe8 then .halt .notactivated_exchange_static_then_halt
  else if op = 0xfe then .halt .undefined_invalid_zero_gas_halt
  else .halt .undefined_opcode_zero_gas_halt

/-- Stage 3: the instruction body of category `c` on `pre`, with `gas` left after the static
charge. The arithmetic and bitwise opcodes pop `inputs op` items, the number revm-bytecode
gives them. -/
def body (pre : Pre) (gas : Nat) : Category → Except String StepResult
  | .stop => pure (stopStep gas)
  | .arith =>
    pure (popStep pre gas (inputs pre.op) .static_arith_underflow_halt .static_arith_success)
  | .exp => expStep pre gas
  | .bitwise =>
    pure (popStep pre gas (inputs pre.op) .static_bitwise_underflow_halt .static_bitwise_success)
  | .pop => pure (popStep pre gas 1 .static_pop_underflow_halt .static_stack_success)
  | .push => pure (pushStep pre gas .static_push_overflow_halt .static_stack_success)
  | .dup n => pure (dupStep pre gas n)
  | .swap n => pure (swapStep pre gas n)
  | .env => pure (pushStep pre gas .static_env_overflow_halt .static_env_success)
  | .selfbalance =>
    pure (pushStep pre gas .static_env_selfbalance_overflow_preserve
      .static_env_selfbalance_success)
  | .calldataload =>
    pure (popStep pre gas 1 .static_calldataload_underflow_halt .static_env_success)
  | .blobhash => pure (popStep pre gas 1 .static_blobhash_underflow_halt .static_env_success)
  | .blockhash =>
    pure (popStep pre gas 1 .static_env_blockhash_underflow_preserve
      .static_env_blockhash_success)
  | .jump => jumpStep pre gas
  | .jumpi => jumpiStep pre gas
  | .jumpdest => pure (jumpdestStep gas)
  | .memoryAccess len => memoryAccessStep pre gas len
  | .mcopy => mcopyStep pre gas
  | .keccak => keccakStep pre gas
  | .dataCopy => dataCopyStep pre gas
  | .returndatacopy => returndatacopyStep pre gas
  | .extcodecopy => extcodecopyStep pre gas
  | .ret revert => returnStep pre gas revert
  | .log n => logStep pre gas n
  | .accountAccess => accountAccessStep pre gas
  | .selfdestruct => selfdestructStep pre gas
  | .sload => sloadStep pre gas
  | .sstore => sstoreStep pre gas
  | .tload => pure (tloadStep pre gas)
  | .tstore => pure (tstoreStep pre gas)
  | .call => callStep pre gas
  | .create create2 => createStep pre gas create2
  | .halt branch => pure (haltStep gas branch)

/-- The outcome of the step that runs from `pre` on fork `f`. Stage 2, the static gas charge, is
the same for every opcode. -/
def stepOutcome : Fork → Pre → Except String StepResult
  | .unzen, pre =>
    let staticCost := staticGas pre.op
    if pre.gas < staticCost then pure (haltSpendingAll .static_step_static_oog_spend_all)
    else body pre (pre.gas - staticCost) (classify pre.op)

/-- The branches no execution reaches on Unzen, each with the reason. The coverage gate
(`lake exe check-traces`) requires the corpus to reach every other branch of `allBranches`, and
fails when it reaches one of these. Every branch is reachable, so the list is empty: each has a
vector in `testdata/zk_gas_vectors`. -/
def unreachableBranches : List (BranchId × String) := []

end TaikoSpec.ZkGas
