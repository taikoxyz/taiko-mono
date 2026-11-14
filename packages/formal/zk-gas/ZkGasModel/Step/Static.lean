import ZkGasModel.Step.Basic

/-!
# Instructions with only static gas

The bodies of the opcodes whose only cost is the static gas `Interpreter::step` charges before
them: STOP, the arithmetic and bitwise opcodes except EXP, POP, PUSH0..PUSH32, DUP, SWAP, the
environment reads, and the opcodes that halt as soon as they run (not activated on Unzen, INVALID
and undefined). Each body gets `gas`, the frame's gas after the static charge. A body can only
continue, end the frame (STOP) or halt keeping `gas`: none of these instructions charges more
gas. Paths are
revm-interpreter 43.0.1 `src/`.

The fork gates these bodies check (`check!`: SHANGHAI for PUSH0, ISTANBUL for CHAINID and
SELFBALANCE, BYZANTIUM for RETURNDATASIZE, LONDON for BASEFEE, CANCUN for BLOBHASH and
BLOBBASEFEE, PETERSBURG for SHL, SHR and SAR, OSAKA for CLZ) all pass on Unzen (Osaka); only the
AMSTERDAM gates of SLOTNUM, DUPN, SWAPN and EXCHANGE fail.
-/
namespace TaikoSpec.ZkGas

/-- STOP (`instructions/control.rs` `stop`): ends the frame successfully keeping its gas. -/
def stopStep (gas : Nat) : StepResult := succeedWith gas .static_stop_halt

/-- A body whose only check is popping `n` stack items (`popn!` or `popn_top!`, which fail with
`StackUnderflow` when the stack has fewer than `n`): ADD..SIGNEXTEND except EXP
(`instructions/arithmetic.rs`), LT..SAR and CLZ (`instructions/bitwise.rs`), POP
(`instructions/stack.rs` `pop`), CALLDATALOAD (`instructions/system.rs` `calldataload`),
BLOBHASH (`instructions/tx_info.rs` `blob_hash`) and BLOCKHASH (`instructions/host.rs`
`blockhash`, whose block lookup charges nothing). -/
def popStep (pre : Pre) (gas n : Nat) (underflow success : BranchId) : StepResult :=
  if pre.stackLen < n then haltKeeping gas underflow else continueWith gas success

/-- A body whose only check is pushing one item (`push!`, or `push_slice` for PUSH1..PUSH32,
which fail with `StackOverflow` when the stack would exceed `STACK_LIMIT`): PUSH0..PUSH32
(`instructions/stack.rs`), the push-only environment reads (`instructions/block_info.rs`,
`instructions/tx_info.rs`, `instructions/system.rs`, `instructions/control.rs` `pc`,
`instructions/memory.rs` `msize`) and SELFBALANCE (`instructions/host.rs` `selfbalance`, whose
balance read of the executing account charges nothing). -/
def pushStep (pre : Pre) (gas : Nat) (overflow success : BranchId) : StepResult :=
  if pre.stackLen + 1 > stackLimit then haltKeeping gas overflow else continueWith gas success

/-- DUPn (`instructions/stack.rs` `dup`): `Stack::dup(n)` fails, reported as `StackOverflow`,
when the stack has fewer than `n` items or is full. -/
def dupStep (pre : Pre) (gas n : Nat) : StepResult :=
  if pre.stackLen < n then haltKeeping gas .static_dup_underflow_halt
  else if pre.stackLen + 1 > stackLimit then haltKeeping gas .static_dup_overflow_halt
  else continueWith gas .static_stack_success

/-- SWAPn (`instructions/stack.rs` `swap`): `Stack::exchange(0, n)` fails with
`StackUnderflow` when `n` is not below the stack length. -/
def swapStep (pre : Pre) (gas n : Nat) : StepResult :=
  if n ≥ pre.stackLen then haltKeeping gas .static_swap_underflow_halt
  else continueWith gas .static_stack_success

/-- SLOTNUM (`instructions/block_info.rs` `slot_num`), DUPN, SWAPN and EXCHANGE
(`instructions/stack.rs`) check `AMSTERDAM` first and halt with `NotActivated` on Unzen, before
reading their immediate or the stack; INVALID (`instructions/control.rs` `invalid`) halts with
`InvalidFEOpcode` and an undefined opcode (`unknown`) with `OpcodeNotFound`. All keep the gas
left after the static charge. -/
def haltStep (gas : Nat) (branch : BranchId) : StepResult := haltKeeping gas branch

end TaikoSpec.ZkGas
