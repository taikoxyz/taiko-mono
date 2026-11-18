import ZkGasModel.Step.Basic

/-!
# EXP

revm-interpreter 43.0.1 `src/instructions/arithmetic.rs` `exp`, with the exponent cost of
revm-context-interface 43.0.1 `src/cfg/gas_params.rs` `exp_cost`. The body gets `gas`, the
frame's gas after EXP's static 10.
-/
namespace TaikoSpec.ZkGas

/-- `exp_byte_gas` from Spurious Dragon on (EIP-160; `gas_params.rs`), so on Unzen. -/
def expByteGas : Nat := 50

/-- `exp_cost`: 0 for exponent 0, else `exp_byte_gas * (log2floor(power) / 8 + 1)`, which is
`exp_byte_gas` per byte of the exponent. -/
def expCost (exponent : Nat) : Nat :=
  if exponent = 0 then 0 else expByteGas * (exponent.log2 / 8 + 1)

/-- EXP (`exp`): `popn_top!` pops the base and leaves the exponent `stack[1]` on top
(`StackUnderflow`, keeping the gas, below two items), then `gas!` charges `exp_cost`; when the
gas left cannot pay it, `OutOfGas` spends all gas. -/
def expStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 2 then return haltKeeping gas .exp_exp_underflow_halt
  let exponent ← stackItem pre 1
  if exponent = 0 then return continueWith gas .exp_exp_zero_byte_exponent_success
  let cost := expCost exponent
  if gas < cost then return haltSpendingAll .exp_exp_dynamic_oog_spend_all
  return continueWith (gas - cost) .exp_exp_exponent_bytes_success

end TaikoSpec.ZkGas
