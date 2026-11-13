import ZkGasModel.Pre

/-!
# Step outcomes, branches and results

The shared interface of the per-step model `stepOutcome` (`ZkGasModel.Step`): the fork whose
interpreter it follows, how a step ends, the model branch that decided it and the step's result.
The category files `ZkGasModel/Step/*.lean` build their results with the helpers at the end.

The model reproduces one metered step of alethia-reth (`crates/evm/src/zk_gas/runtime.rs`,
`run_metered_plain`), which runs revm-interpreter 43.0.1's `Interpreter::step` and materializes
an exceptional halt before the step's zk gas charge: the step's gas is the frame's remaining
gas before it minus the remaining gas after it, the halt included.
-/
namespace TaikoSpec.ZkGas

/-- The fork whose interpreter the step model follows. -/
inductive Fork
  /-- Unzen: alethia-reth on revm `SpecId::OSAKA` (`crates/evm/src/spec.rs`). -/
  | unzen
  deriving Repr, DecidableEq

/-- How a step ends. -/
inductive Outcome
  /-- The frame goes on to its next opcode. -/
  | continue
  /-- The frame ends and keeps its remaining gas: STOP, or a halt other than out of gas (stack
  underflow or overflow, an invalid jump, an opcode not activated or not defined).
  `Interpreter::halt` spends the remaining gas only for `OutOfGas`. -/
  | haltKeep
  /-- The frame halts out of gas, which spends all its remaining gas (`Interpreter::halt` on
  `OutOfGas`); the step's gas after is 0. -/
  | haltSpendAll
  /-- The step opens a new frame (CALL or CREATE family); it is charged its spawn estimate. -/
  | newFrame
  deriving Repr, DecidableEq

/-- The model branch that decided a step: one constructor per opcode group × stage × outcome.

A branch is named after the phase-1 coverage cell (`testdata/zk_gas_vectors/coverage.json`) it
models, with the dots replaced by underscores. Where one branch models several cells, or no cell
names the branch, the constructor's comment lists the cells it covers; new names keep the
cells' `group_opcode_outcome` shape. -/
inductive BranchId
  /-- Any modeled opcode that cannot pay its static gas: `Interpreter::step` returns `OutOfGas`
  before the instruction runs, and the halt spends all remaining gas. Cells
  `static.step.static_oog_spend_all`, `static.env.selfbalance_static_oog_spend_all`,
  `static.env.blockhash_static_oog_spend_all`, `notactivated.dupn.static_oog_spend_all`, and
  the out-of-gas half of `static.step.oog_before_underflow` and
  `static.step.oog_before_overflow`. -/
  | static_step_static_oog_spend_all
  /-- STOP ends the frame keeping its gas (new name; no cell). -/
  | static_stop_halt
  /-- ADD..SIGNEXTEND except EXP with their stack inputs. -/
  | static_arith_success
  /-- ADD..SIGNEXTEND except EXP on too few stack items; also the paid half of
  `static.step.oog_before_underflow`. -/
  | static_arith_underflow_halt
  /-- LT..SAR and CLZ with their stack inputs. -/
  | static_bitwise_success
  /-- LT..SAR and CLZ on too few stack items. -/
  | static_bitwise_underflow_halt
  /-- POP, PUSH0..PUSH32, DUP1..DUP16 and SWAP1..SWAP16 that succeed. -/
  | static_stack_success
  /-- POP on an empty stack. -/
  | static_pop_underflow_halt
  /-- DUPn on fewer than n items (revm reports a stack overflow). -/
  | static_dup_underflow_halt
  /-- DUPn on a full 1024-item stack. -/
  | static_dup_overflow_halt
  /-- SWAPn on fewer than n + 1 items. -/
  | static_swap_underflow_halt
  /-- PUSH0..PUSH32 on a full 1024-item stack; also the paid half of
  `static.step.oog_before_overflow`. -/
  | static_push_overflow_halt
  /-- An environment read that only pushes (ADDRESS, ORIGIN, CALLER, CALLVALUE, CALLDATASIZE,
  CODESIZE, GASPRICE, RETURNDATASIZE, COINBASE..CHAINID, BASEFEE, BLOBBASEFEE, PC, MSIZE,
  GAS), or CALLDATALOAD or BLOBHASH with their stack input. -/
  | static_env_success
  /-- An environment read that only pushes, on a full 1024-item stack. -/
  | static_env_overflow_halt
  /-- SELFBALANCE: only its static gas. -/
  | static_env_selfbalance_success
  /-- SELFBALANCE on a full 1024-item stack. -/
  | static_env_selfbalance_overflow_preserve
  /-- BLOCKHASH of any block number: only its static gas. -/
  | static_env_blockhash_success
  /-- BLOCKHASH on an empty stack. -/
  | static_env_blockhash_underflow_preserve
  /-- CALLDATALOAD on an empty stack. -/
  | static_calldataload_underflow_halt
  /-- BLOBHASH on an empty stack. -/
  | static_blobhash_underflow_halt
  /-- JUMP on an empty stack. -/
  | static_jump_underflow_halt
  /-- JUMP to a valid JUMPDEST; also `jump.jump.dupn_immediate_target_success`. -/
  | jump_jump_valid_target_success
  /-- JUMP to a target that is not a valid JUMPDEST; also `jump.jump.oversized_target_halt`
  (the `jumpdest_valid` fact saturates the target as revm does). -/
  | jump_jump_invalid_target_halt
  /-- JUMPDEST: only its static gas (new name; the JUMPDEST of `jump.jump.valid_target_success`
  and `jump.jumpi.taken_success`). -/
  | jump_jumpdest_success
  /-- JUMPI on fewer than two stack items. -/
  | jump_jumpi_underflow_halt
  /-- JUMPI with a zero condition: the target is not checked. -/
  | jump_jumpi_not_taken_success
  /-- JUMPI with a non-zero condition to a valid JUMPDEST. -/
  | jump_jumpi_taken_success
  /-- JUMPI with a non-zero condition to a target that is not a valid JUMPDEST. -/
  | jump_jumpi_invalid_target_halt
  /-- EXP on fewer than two stack items, before any exponent cost. -/
  | exp_exp_underflow_halt
  /-- EXP with exponent 0: no exponent cost. -/
  | exp_exp_zero_byte_exponent_success
  /-- EXP with a non-zero exponent that pays 50 gas per exponent byte (new name; cells
  `exp.exp.one_byte_exponent_success` and `exp.exp.thirty_two_byte_exponent_success`). -/
  | exp_exp_exponent_bytes_success
  /-- EXP that pays its static gas but not its exponent bytes: the halt spends all gas. -/
  | exp_exp_dynamic_oog_spend_all
  /-- SLOTNUM (0x4b): static gas, then not activated before Amsterdam. -/
  | notactivated_slotnum_static_then_halt
  /-- DUPN (0xe6): static gas, then not activated before Amsterdam. -/
  | notactivated_dupn_static_then_halt
  /-- SWAPN (0xe7): static gas, then not activated before Amsterdam. -/
  | notactivated_swapn_static_then_halt
  /-- EXCHANGE (0xe8): static gas, then not activated before Amsterdam. -/
  | notactivated_exchange_static_then_halt
  /-- An opcode revm does not define (no static gas): `OpcodeNotFound`. -/
  | undefined_opcode_zero_gas_halt
  /-- INVALID (0xfe, no static gas): `InvalidFEOpcode`. -/
  | undefined_invalid_zero_gas_halt
  deriving Repr, DecidableEq

/-- The branch's name, as the trace checker reports it: the constructor name. -/
def BranchId.name : BranchId → String
  | .static_step_static_oog_spend_all => "static_step_static_oog_spend_all"
  | .static_stop_halt => "static_stop_halt"
  | .static_arith_success => "static_arith_success"
  | .static_arith_underflow_halt => "static_arith_underflow_halt"
  | .static_bitwise_success => "static_bitwise_success"
  | .static_bitwise_underflow_halt => "static_bitwise_underflow_halt"
  | .static_stack_success => "static_stack_success"
  | .static_pop_underflow_halt => "static_pop_underflow_halt"
  | .static_dup_underflow_halt => "static_dup_underflow_halt"
  | .static_dup_overflow_halt => "static_dup_overflow_halt"
  | .static_swap_underflow_halt => "static_swap_underflow_halt"
  | .static_push_overflow_halt => "static_push_overflow_halt"
  | .static_env_success => "static_env_success"
  | .static_env_overflow_halt => "static_env_overflow_halt"
  | .static_env_selfbalance_success => "static_env_selfbalance_success"
  | .static_env_selfbalance_overflow_preserve => "static_env_selfbalance_overflow_preserve"
  | .static_env_blockhash_success => "static_env_blockhash_success"
  | .static_env_blockhash_underflow_preserve => "static_env_blockhash_underflow_preserve"
  | .static_calldataload_underflow_halt => "static_calldataload_underflow_halt"
  | .static_blobhash_underflow_halt => "static_blobhash_underflow_halt"
  | .static_jump_underflow_halt => "static_jump_underflow_halt"
  | .jump_jump_valid_target_success => "jump_jump_valid_target_success"
  | .jump_jump_invalid_target_halt => "jump_jump_invalid_target_halt"
  | .jump_jumpdest_success => "jump_jumpdest_success"
  | .jump_jumpi_underflow_halt => "jump_jumpi_underflow_halt"
  | .jump_jumpi_not_taken_success => "jump_jumpi_not_taken_success"
  | .jump_jumpi_taken_success => "jump_jumpi_taken_success"
  | .jump_jumpi_invalid_target_halt => "jump_jumpi_invalid_target_halt"
  | .exp_exp_underflow_halt => "exp_exp_underflow_halt"
  | .exp_exp_zero_byte_exponent_success => "exp_exp_zero_byte_exponent_success"
  | .exp_exp_exponent_bytes_success => "exp_exp_exponent_bytes_success"
  | .exp_exp_dynamic_oog_spend_all => "exp_exp_dynamic_oog_spend_all"
  | .notactivated_slotnum_static_then_halt => "notactivated_slotnum_static_then_halt"
  | .notactivated_dupn_static_then_halt => "notactivated_dupn_static_then_halt"
  | .notactivated_swapn_static_then_halt => "notactivated_swapn_static_then_halt"
  | .notactivated_exchange_static_then_halt => "notactivated_exchange_static_then_halt"
  | .undefined_opcode_zero_gas_halt => "undefined_opcode_zero_gas_halt"
  | .undefined_invalid_zero_gas_halt => "undefined_invalid_zero_gas_halt"

/-- A modeled step: the frame's gas after it, how it ended and the branch that decided it.
`gasAfter` is only for reference when the step opens a new frame. -/
structure StepResult where
  gasAfter : Nat
  outcome : Outcome
  branch : BranchId
  deriving Repr, DecidableEq

/-- revm's `STACK_LIMIT` (`src/interpreter/stack.rs`). -/
def stackLimit : Nat := 1024

/-- The frame goes on with `gas` left. -/
def continueWith (gas : Nat) (branch : BranchId) : StepResult :=
  { gasAfter := gas, outcome := .continue, branch }

/-- The frame halts keeping `gas`. -/
def haltKeeping (gas : Nat) (branch : BranchId) : StepResult :=
  { gasAfter := gas, outcome := .haltKeep, branch }

/-- The frame halts out of gas, spending all of it. -/
def haltSpendingAll (branch : BranchId) : StepResult :=
  { gasAfter := 0, outcome := .haltSpendAll, branch }

/-- Stack item `i` (0 is the top) of the step's recorded stack. -/
def stackItem (pre : Pre) (i : Nat) : Except String Nat :=
  match pre.stack[i]? with
  | some v => .ok v
  | none => .error s!"stack: the step records {pre.stack.length} items, the model needs item {i}"

/-- The fact `key` the step must record. -/
def requireFact (key : String) : Option α → Except String α
  | some v => .ok v
  | none => .error s!"facts: the step records no {key}, which the model needs"

end TaikoSpec.ZkGas
