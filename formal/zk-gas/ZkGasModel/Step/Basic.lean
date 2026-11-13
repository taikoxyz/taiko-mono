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

/-- How a step ends. A frame that ends keeps its remaining gas unless it halts out of gas; the
frame-ending outcomes differ in the status the frame ends with (a harness trace's `frame_end`
status: `success`, `revert` or `halt`). -/
inductive Outcome
  /-- The frame goes on to its next opcode. -/
  | continue
  /-- The frame ends successfully and keeps its remaining gas: STOP (revm `Stop`) or RETURN
  (`Return`). Frame status `success`. -/
  | success
  /-- REVERT ends the frame and keeps its remaining gas (revm `Revert`). Frame status
  `revert`. -/
  | revert
  /-- The frame halts and keeps its remaining gas: a halt other than out of gas (stack
  underflow or overflow, an invalid jump, an opcode not activated or not defined, an operand of
  2^64 or more (`InvalidOperandOOG`), a memory expansion the frame cannot pay (`MemoryOOG`), a
  return data range out of bounds (`OutOfOffset`), a LOG in a static frame).
  `Interpreter::halt` spends the remaining gas only for `OutOfGas`. Frame status `halt`. -/
  | haltKeep
  /-- The frame halts out of gas, which spends all its remaining gas (`Interpreter::halt` on
  `OutOfGas`); the step's gas after is 0. Frame status `halt`. -/
  | haltSpendAll
  /-- The step opens a new frame (CALL or CREATE family); it is charged its spawn estimate. -/
  | newFrame
  deriving Repr, DecidableEq

/-- The model branch that decided a step: one constructor per opcode group × stage × outcome.

A branch is named after the phase-1 coverage cell (`testdata/zk_gas_vectors/coverage.json`) it
models, with the dots replaced by underscores. Where one branch models several cells, or no cell
names the branch, the constructor's comment lists the cells it covers; new names keep the
cells' `group_opcode_outcome` shape.

Opcodes that run the same sequence of checks share a branch per check that ends the step and
outcome (MLOAD, MSTORE and MSTORE8; CALLDATACOPY and CODECOPY; RETURN and REVERT until they
end; LOG0..LOG4). Cells that differ only in the operands that make one check fail (a memory
size that is one gas short, passes 2^64, rounds up to 2^64 or is above 0x1FFFFFFFE0 bytes all
fail the expansion charge) share that check's branch. A zero length that returns early is its
own branch; one that only skips the memory checks before a later check (RETURN and REVERT, LOG,
EXTCODECOPY) shares the branch of the check that ends the step. -/
inductive BranchId
  /-- Any modeled opcode that cannot pay its static gas: `Interpreter::step` returns `OutOfGas`
  before the instruction runs, and the halt spends all remaining gas. Cells
  `static.step.static_oog_spend_all`, `static.env.selfbalance_static_oog_spend_all`,
  `static.env.blockhash_static_oog_spend_all`, `notactivated.dupn.static_oog_spend_all`,
  `log.logn.static_oog_spend_all`, `log.topics.static_oog_before_underflow_spend_all`,
  `log.static_frame.static_oog_spend_all`, and the out-of-gas half of
  `static.step.oog_before_underflow` and `static.step.oog_before_overflow`. -/
  | static_step_static_oog_spend_all
  /-- STOP ends the frame successfully keeping its gas (new name; no cell). -/
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
  /-- MLOAD, MSTORE, MSTORE8, MCOPY, KECCAK256, CALLDATACOPY, CODECOPY, RETURNDATACOPY,
  EXTCODECOPY, RETURN or REVERT on fewer stack items than it pops (`popn!` or `popn_top!`:
  `StackUnderflow`, before any dynamic charge), keeping the gas left after the static charge
  (new name; no cell, and no corpus step). -/
  | memory_step_underflow_halt
  /-- MLOAD, MSTORE or MSTORE8 that pays the expansion to its offset + 32 (offset + 1 for
  MSTORE8), or needs none inside current memory (new name; cells `memory.mload.expansion_success`,
  `memory.mstore.expansion_success` and `memory.mstore8.expansion_success`). -/
  | memory_access_expansion_success
  /-- MLOAD, MSTORE or MSTORE8 at an offset of 2^64 or more: `InvalidOperandOOG`, keeping the
  gas (new name; cells `memory.mload.offset_above_u64_preserve`,
  `memory.mstore.offset_above_u64_preserve` and `memory.mstore8.offset_above_u64_preserve`). -/
  | memory_access_offset_above_u64_preserve
  /-- MLOAD, MSTORE or MSTORE8 that cannot pay its expansion: `MemoryOOG`, keeping the gas (new
  name; cells `memory.mload.memory_oog_preserve`, `memory.mload.end_overflow_preserve`,
  `memory.mload.word_rounding_overflow_preserve`, `memory.mload.size_above_cap_preserve`,
  `memory.mstore.memory_oog_preserve`, `memory.mstore.size_above_cap_preserve`,
  `memory.mstore8.memory_oog_preserve`, `memory.mstore8.end_overflow_preserve` and
  `memory.mstore8.size_above_cap_preserve`). -/
  | memory_access_memory_oog_preserve
  /-- MCOPY of 2^64 bytes or more, before its copy cost. -/
  | memory_mcopy_size_above_u64_preserve
  /-- MCOPY that cannot pay its copy cost; also
  `memory.mcopy.copy_oog_before_memory_checks_spend_all`. -/
  | memory_mcopy_copy_oog_spend_all
  /-- MCOPY of length 0: its copy cost is 0 and it checks neither offset. -/
  | memory_mcopy_zero_size_no_expansion
  /-- MCOPY with dst of 2^64 or more, after its copy cost. -/
  | memory_mcopy_dst_above_u64_preserve
  /-- MCOPY with src of 2^64 or more, after its copy cost. -/
  | memory_mcopy_src_above_u64_preserve
  /-- MCOPY that pays its copy cost but not its expansion; also
  `memory.mcopy.end_overflow_preserve`, `memory.mcopy.word_rounding_overflow_preserve` and
  `memory.mcopy.size_above_cap_preserve`. -/
  | memory_mcopy_memory_oog_preserve
  /-- MCOPY that pays its copy cost and expansion; also `memory.mcopy.overlap_success`. -/
  | memory_mcopy_expansion_success
  /-- KECCAK256 of 2^64 bytes or more, before its word cost. -/
  | keccak_keccak256_size_above_u64_preserve
  /-- KECCAK256 that cannot pay its word cost; also
  `keccak.keccak256.word_oog_before_memory_checks_spend_all`. -/
  | keccak_keccak256_word_oog_spend_all
  /-- KECCAK256 of length 0: no word cost and no offset check. -/
  | keccak_keccak256_zero_size_no_expansion
  /-- KECCAK256 at an offset of 2^64 or more, after its word cost. -/
  | keccak_keccak256_offset_above_u64_preserve
  /-- KECCAK256 that pays its word cost but not its expansion; also
  `keccak.keccak256.end_overflow_preserve`, `keccak.keccak256.word_rounding_overflow_preserve`
  and `keccak.keccak256.size_above_cap_preserve`. -/
  | keccak_keccak256_memory_oog_preserve
  /-- KECCAK256 that pays its word cost and expansion. -/
  | keccak_keccak256_expansion_success
  /-- CALLDATACOPY or CODECOPY of 2^64 bytes or more, before its copy cost (new name; cells
  `copy.calldatacopy.size_above_u64_preserve` and `copy.codecopy.size_above_u64_preserve`). -/
  | copy_datacopy_size_above_u64_preserve
  /-- CALLDATACOPY or CODECOPY that cannot pay its copy cost (new name; cells
  `copy.calldatacopy.copy_oog_spend_all`,
  `copy.calldatacopy.copy_oog_before_memory_checks_spend_all`, `copy.codecopy.copy_oog_spend_all`
  and `copy.codecopy.copy_oog_before_memory_checks_spend_all`). -/
  | copy_datacopy_copy_oog_spend_all
  /-- CALLDATACOPY or CODECOPY of length 0 (new name; cells
  `copy.calldatacopy.zero_size_no_expansion` and `copy.codecopy.zero_size_no_expansion`). -/
  | copy_datacopy_zero_size_no_expansion
  /-- CALLDATACOPY or CODECOPY to a memory offset of 2^64 or more, after its copy cost (new name;
  cells `copy.calldatacopy.offset_above_u64_preserve` and
  `copy.codecopy.offset_above_u64_preserve`). -/
  | copy_datacopy_offset_above_u64_preserve
  /-- CALLDATACOPY or CODECOPY that pays its copy cost but not its expansion (new name; cells
  `copy.calldatacopy.memory_oog_preserve` and `copy.codecopy.memory_oog_preserve`). -/
  | copy_datacopy_memory_oog_preserve
  /-- CALLDATACOPY or CODECOPY that pays its copy cost and expansion; the source offset,
  saturated, charges nothing (new name; cells `copy.calldatacopy.expansion_success`,
  `copy.codecopy.expansion_success`, `copy.calldatacopy.shared_buffer_success` and the
  CALLDATACOPY and CODECOPY steps of `copy.source.offset_above_u64_success`). -/
  | copy_datacopy_expansion_success
  /-- RETURNDATACOPY of 2^64 bytes or more, before the range check. -/
  | copy_returndatacopy_size_above_u64_preserve
  /-- RETURNDATACOPY whose source range passes the end of the return data: `OutOfOffset`,
  before its copy cost; also `copy.returndatacopy.out_of_bounds_before_charges_preserve`. -/
  | copy_returndatacopy_out_of_bounds_preserve
  /-- RETURNDATACOPY of an in-bounds range that cannot pay its copy cost; also
  `copy.returndatacopy.copy_oog_before_memory_checks_spend_all`. -/
  | copy_returndatacopy_copy_oog_spend_all
  /-- RETURNDATACOPY of length 0 inside the return data. -/
  | copy_returndatacopy_zero_size_no_expansion
  /-- RETURNDATACOPY of an in-bounds range to a memory offset of 2^64 or more, after its copy
  cost. -/
  | copy_returndatacopy_offset_above_u64_preserve
  /-- RETURNDATACOPY of an in-bounds range that pays its copy cost but not its expansion. -/
  | copy_returndatacopy_memory_oog_preserve
  /-- RETURNDATACOPY of an in-bounds range that pays its copy cost and expansion. -/
  | copy_returndatacopy_expansion_success
  /-- EXTCODECOPY of 2^64 bytes or more, before its copy cost. -/
  | copy_extcodecopy_size_above_u64_preserve
  /-- EXTCODECOPY that cannot pay its copy cost; also
  `copy.extcodecopy.copy_oog_before_memory_checks_spend_all`. -/
  | copy_extcodecopy_copy_oog_spend_all
  /-- EXTCODECOPY to a memory offset of 2^64 or more with a non-zero length, after its copy cost
  and before the account load. -/
  | copy_extcodecopy_offset_above_u64_preserve
  /-- EXTCODECOPY that pays its copy cost but not its expansion, before the account load (which
  leaves the account cold); also `copy.extcodecopy.end_overflow_preserve`,
  `copy.extcodecopy.size_above_cap_preserve` and
  `copy.extcodecopy.failed_copy_leaves_account_cold`. -/
  | copy_extcodecopy_memory_oog_preserve
  /-- EXTCODECOPY of a cold account, of any length, that pays its copy cost and expansion but
  not the 2,500 cold surcharge: the skipped cold load is `OutOfGas`. -/
  | copy_extcodecopy_cold_surcharge_oog_spend_all
  /-- EXTCODECOPY of a cold account that pays its copy cost, expansion and cold surcharge; also
  `copy.extcodecopy.zero_size_cold_success` (length 0 skips the memory checks, not the account
  load) and the EXTCODECOPY step of `copy.source.offset_above_u64_success`. -/
  | copy_extcodecopy_cold_success
  /-- EXTCODECOPY of a warm account: its copy cost and expansion, no surcharge. -/
  | copy_extcodecopy_warm_success
  /-- RETURN or REVERT of 2^64 bytes or more (`return_inner`; new name; cells
  `return.return.size_above_u64_halt` and `return.revert.size_above_u64_halt`). -/
  | return_inner_size_above_u64_halt
  /-- RETURN or REVERT at an offset of 2^64 or more with a non-zero length (new name; cells
  `return.return.offset_above_u64_halt` and `return.revert.offset_above_u64_halt`). -/
  | return_inner_offset_above_u64_halt
  /-- RETURN or REVERT that cannot pay its expansion: `MemoryOOG`, status halt (new name; cells
  `return.return.memory_oog_halt` and `return.revert.memory_oog_halt`). -/
  | return_inner_memory_oog_halt
  /-- RETURN that pays its expansion; also `return.return.zero_size_success` (length 0 skips the
  offset and memory, then returns). -/
  | return_return_expansion_success
  /-- REVERT that pays its expansion; also `return.revert.zero_size_revert`. -/
  | return_revert_expansion_revert
  /-- LOG0..LOG4 in a static frame: `StateChangeDuringStaticCall` before any pop or dynamic
  charge, keeping the gas after the 375 static gas; also
  `log.static_frame.dynamic_oog_halt_preserve`,
  `log.static_frame.stack_underflow_preserve`, `log.static_frame.size_above_u64_preserve` and
  `log.static_frame.size_above_cap_preserve`. -/
  | log_static_frame_halt_preserve
  /-- LOG0..LOG4 on fewer than two stack items (offset and length). -/
  | log_logn_stack_underflow_preserve
  /-- LOG0..LOG4 of 2^64 bytes or more, before its topic and data cost; also
  `log.topics.size_above_u64_before_underflow_preserve`. -/
  | log_logn_size_above_u64_preserve
  /-- LOG0..LOG4 that cannot pay its topic and data cost, one saturating charge (new name; cells
  `log.logn.topic_oog_spend_all`, `log.logn.data_oog_spend_all`,
  `log.logn.data_oog_before_memory_checks_spend_all` and
  `log.topics.data_oog_before_underflow_spend_all`). -/
  | log_logn_cost_oog_spend_all
  /-- LOG0..LOG4 at an offset of 2^64 or more with a non-zero length, after its topic and data
  cost; also the offset half of `log.topics.memory_range_halt_before_underflow_preserve`. -/
  | log_logn_offset_above_u64_preserve
  /-- LOG0..LOG4 that pays its topic and data cost but not its expansion; also
  `log.logn.end_overflow_preserve`, `log.logn.word_rounding_overflow_preserve`,
  `log.logn.size_above_cap_preserve`, `log.topics.memory_oog_before_underflow_preserve` and the
  memory half of `log.topics.memory_range_halt_before_underflow_preserve`. -/
  | log_logn_memory_oog_preserve
  /-- LOG1..LOG4 with its offset and length but too few topics, popped last after every charge;
  also `log.topics.zero_size_underflow_preserve`. -/
  | log_topics_underflow_preserve
  /-- LOG0..LOG4 that pays its topic and data cost and expansion (new name; cells
  `log.log0.success`, `log.log1.success`, `log.log2.success`, `log.log3.success`,
  `log.log4.success` and `log.logn.zero_size_success`). -/
  | log_logn_success
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
  | .memory_step_underflow_halt => "memory_step_underflow_halt"
  | .memory_access_expansion_success => "memory_access_expansion_success"
  | .memory_access_offset_above_u64_preserve => "memory_access_offset_above_u64_preserve"
  | .memory_access_memory_oog_preserve => "memory_access_memory_oog_preserve"
  | .memory_mcopy_size_above_u64_preserve => "memory_mcopy_size_above_u64_preserve"
  | .memory_mcopy_copy_oog_spend_all => "memory_mcopy_copy_oog_spend_all"
  | .memory_mcopy_zero_size_no_expansion => "memory_mcopy_zero_size_no_expansion"
  | .memory_mcopy_dst_above_u64_preserve => "memory_mcopy_dst_above_u64_preserve"
  | .memory_mcopy_src_above_u64_preserve => "memory_mcopy_src_above_u64_preserve"
  | .memory_mcopy_memory_oog_preserve => "memory_mcopy_memory_oog_preserve"
  | .memory_mcopy_expansion_success => "memory_mcopy_expansion_success"
  | .keccak_keccak256_size_above_u64_preserve => "keccak_keccak256_size_above_u64_preserve"
  | .keccak_keccak256_word_oog_spend_all => "keccak_keccak256_word_oog_spend_all"
  | .keccak_keccak256_zero_size_no_expansion => "keccak_keccak256_zero_size_no_expansion"
  | .keccak_keccak256_offset_above_u64_preserve => "keccak_keccak256_offset_above_u64_preserve"
  | .keccak_keccak256_memory_oog_preserve => "keccak_keccak256_memory_oog_preserve"
  | .keccak_keccak256_expansion_success => "keccak_keccak256_expansion_success"
  | .copy_datacopy_size_above_u64_preserve => "copy_datacopy_size_above_u64_preserve"
  | .copy_datacopy_copy_oog_spend_all => "copy_datacopy_copy_oog_spend_all"
  | .copy_datacopy_zero_size_no_expansion => "copy_datacopy_zero_size_no_expansion"
  | .copy_datacopy_offset_above_u64_preserve => "copy_datacopy_offset_above_u64_preserve"
  | .copy_datacopy_memory_oog_preserve => "copy_datacopy_memory_oog_preserve"
  | .copy_datacopy_expansion_success => "copy_datacopy_expansion_success"
  | .copy_returndatacopy_size_above_u64_preserve => "copy_returndatacopy_size_above_u64_preserve"
  | .copy_returndatacopy_out_of_bounds_preserve => "copy_returndatacopy_out_of_bounds_preserve"
  | .copy_returndatacopy_copy_oog_spend_all => "copy_returndatacopy_copy_oog_spend_all"
  | .copy_returndatacopy_zero_size_no_expansion => "copy_returndatacopy_zero_size_no_expansion"
  | .copy_returndatacopy_offset_above_u64_preserve =>
    "copy_returndatacopy_offset_above_u64_preserve"
  | .copy_returndatacopy_memory_oog_preserve => "copy_returndatacopy_memory_oog_preserve"
  | .copy_returndatacopy_expansion_success => "copy_returndatacopy_expansion_success"
  | .copy_extcodecopy_size_above_u64_preserve => "copy_extcodecopy_size_above_u64_preserve"
  | .copy_extcodecopy_copy_oog_spend_all => "copy_extcodecopy_copy_oog_spend_all"
  | .copy_extcodecopy_offset_above_u64_preserve => "copy_extcodecopy_offset_above_u64_preserve"
  | .copy_extcodecopy_memory_oog_preserve => "copy_extcodecopy_memory_oog_preserve"
  | .copy_extcodecopy_cold_surcharge_oog_spend_all =>
    "copy_extcodecopy_cold_surcharge_oog_spend_all"
  | .copy_extcodecopy_cold_success => "copy_extcodecopy_cold_success"
  | .copy_extcodecopy_warm_success => "copy_extcodecopy_warm_success"
  | .return_inner_size_above_u64_halt => "return_inner_size_above_u64_halt"
  | .return_inner_offset_above_u64_halt => "return_inner_offset_above_u64_halt"
  | .return_inner_memory_oog_halt => "return_inner_memory_oog_halt"
  | .return_return_expansion_success => "return_return_expansion_success"
  | .return_revert_expansion_revert => "return_revert_expansion_revert"
  | .log_static_frame_halt_preserve => "log_static_frame_halt_preserve"
  | .log_logn_stack_underflow_preserve => "log_logn_stack_underflow_preserve"
  | .log_logn_size_above_u64_preserve => "log_logn_size_above_u64_preserve"
  | .log_logn_cost_oog_spend_all => "log_logn_cost_oog_spend_all"
  | .log_logn_offset_above_u64_preserve => "log_logn_offset_above_u64_preserve"
  | .log_logn_memory_oog_preserve => "log_logn_memory_oog_preserve"
  | .log_topics_underflow_preserve => "log_topics_underflow_preserve"
  | .log_logn_success => "log_logn_success"
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

/-- The frame ends successfully keeping `gas`. -/
def succeedWith (gas : Nat) (branch : BranchId) : StepResult :=
  { gasAfter := gas, outcome := .success, branch }

/-- The frame ends reverting, keeping `gas`. -/
def revertWith (gas : Nat) (branch : BranchId) : StepResult :=
  { gasAfter := gas, outcome := .revert, branch }

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
