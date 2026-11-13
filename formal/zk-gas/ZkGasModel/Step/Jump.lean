import ZkGasModel.Step.Basic

/-!
# JUMP, JUMPI and JUMPDEST

revm-interpreter 43.0.1 `src/instructions/control.rs`. Each body gets `gas`, the frame's gas
after the static charge (JUMP 8, JUMPI 10, JUMPDEST 1); none charges more. A jump target is
valid when the trace's `jumpdest_valid` fact says so: alethia-reth saturates `stack[0]` to
`usize` and looks it up in the bytecode's jump table, as `jump_inner` does
(`as_usize_saturated!`, then `is_valid_legacy_jump`).
-/
namespace TaikoSpec.ZkGas

/-- JUMP (`jump`): pops its target (`popn!`, `StackUnderflow` on an empty stack), then halts
with `InvalidJump` unless the target is a valid JUMPDEST. Both halts keep the gas. -/
def jumpStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 1 then return haltKeeping gas .static_jump_underflow_halt
  if ← requireFact "jumpdest_valid" pre.facts.jumpdestValid then
    return continueWith gas .jump_jump_valid_target_success
  return haltKeeping gas .jump_jump_invalid_target_halt

/-- JUMPI (`jumpi`): pops its target and condition (`popn!`), then checks the target only when
the condition `stack[1]` is non-zero. -/
def jumpiStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 2 then return haltKeeping gas .jump_jumpi_underflow_halt
  if (← stackItem pre 1) = 0 then return continueWith gas .jump_jumpi_not_taken_success
  if ← requireFact "jumpdest_valid" pre.facts.jumpdestValid then
    return continueWith gas .jump_jumpi_taken_success
  return haltKeeping gas .jump_jumpi_invalid_target_halt

/-- JUMPDEST (`jumpdest`): does nothing. -/
def jumpdestStep (gas : Nat) : StepResult := continueWith gas .jump_jumpdest_success

end TaikoSpec.ZkGas
