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
  /-- The frame ends successfully and keeps its remaining gas: STOP (revm `Stop`), RETURN
  (`Return`) or SELFDESTRUCT (`SelfDestruct`). Frame status `success`. -/
  | success
  /-- REVERT ends the frame and keeps its remaining gas (revm `Revert`). Frame status
  `revert`. -/
  | revert
  /-- The frame halts and keeps its remaining gas: a halt other than out of gas (stack
  underflow or overflow, an invalid jump, an opcode not activated or not defined, an operand of
  2^64 or more (`InvalidOperandOOG`), a memory expansion the frame cannot pay (`MemoryOOG`), a
  return data range out of bounds (`OutOfOffset`), SSTORE's reentrancy sentry
  (`ReentrancySentryOOG`), a LOG, SSTORE, TSTORE, SELFDESTRUCT, CREATE or CREATE2 in a static
  frame (`StateChangeDuringStaticCall`), a CALL with value in a static frame
  (`CallNotAllowedInsideStatic`), an initcode above the EIP-3860 limit
  (`CreateInitCodeSizeLimit`)). `Interpreter::halt` spends the remaining gas only for
  `OutOfGas`. Frame status `halt`. -/
  | haltKeep
  /-- The frame halts out of gas, which spends all its remaining gas (`Interpreter::halt` on
  `OutOfGas`, which a skipped cold account or slot load also is); the step's gas after is 0.
  Frame status `halt`. -/
  | haltSpendAll
  /-- The step opens a new frame: a CALL or CREATE family instruction pays its charges, takes
  the gas it forwards and installs `InterpreterAction::NewFrame` (`Suspend`). alethia-reth
  charges it its spawn estimate instead of the measured step gas. Whatever the frame then does
  (it may run no code, or fail on the depth, balance, nonce or address checks of the handler)
  does not change this outcome. -/
  | newFrame
  deriving Repr, DecidableEq

/-- The model branch that decided a step: one constructor per opcode group × stage × outcome.

A branch is named after the phase-1 coverage cell (`testdata/zk_gas_vectors/coverage.json`) it
models, with the dots replaced by underscores. Where one branch models several cells, or no cell
names the branch, the constructor's comment lists the cells it covers; new names keep the
cells' `group_opcode_outcome` shape.

Opcodes that run the same sequence of checks share a branch per check that ends the step and
outcome (MLOAD, MSTORE and MSTORE8; CALLDATACOPY and CODECOPY; RETURN and REVERT until they
end; LOG0..LOG4; BALANCE, EXTCODESIZE and EXTCODEHASH). Cells that differ only in the operands
that make one check fail (a memory size that is one gas short, passes 2^64, rounds up to 2^64
or is above 0x1FFFFFFFE0 bytes all fail the expansion charge) share that check's branch. A zero
length that returns early is its own branch; one that only skips the memory checks before a
later check (RETURN and REVERT, LOG, EXTCODECOPY, the CALL family's ranges, CREATE and CREATE2)
shares the branch of the check that ends the step.

Where the state facts decide what a charge includes (a cold surcharge, SSTORE's set or reset
cost, SELFDESTRUCT's new-account charge, the CALL family's new-account and EIP-7702 delegate
costs), each combination it can include is its own success branch, and the charge failing is one
branch whatever it included; a cold load skipped for lack of gas before the charge is a branch of
its own. A charge that only some steps pay (the CALL family's value transfer) splits the success
branches the same way. A step that opens a new frame has its success branches too (`..._spawn`,
`..._spawn_estimate`). Cells about the accounts or slots a frame leaves warm span several steps;
the comment of each step's branch names them.

The four CALL-family opcodes share their branches where they run the same checks: DELEGATECALL
and STATICCALL pop no value and so never transfer one; only CALL checks a value in a static
frame and charges a new account. CREATE and CREATE2 share their branches up to CREATE2's salt. -/
inductive BranchId
  /-- Any modeled opcode that cannot pay its static gas: `Interpreter::step` returns `OutOfGas`
  before the instruction runs, and the halt spends all remaining gas. Cells
  `static.step.static_oog_spend_all`, `static.env.selfbalance_static_oog_spend_all`,
  `static.env.blockhash_static_oog_spend_all`, `notactivated.dupn.static_oog_spend_all`,
  `log.logn.static_oog_spend_all`, `log.topics.static_oog_before_underflow_spend_all`,
  `log.static_frame.static_oog_spend_all`, `sload.sload.static_oog_spend_all`,
  `account.access.static_oog_spend_all`, `selfdestruct.selfdestruct.static_oog_spend_all`,
  `transient.tload.static_oog_spend_all`, `transient.tstore.static_oog_spend_all`,
  `transient.static_frame.tstore_static_oog_spend_all`, `call.family.static_oog_spend_all`, and
  the out-of-gas half of `static.step.oog_before_underflow` and
  `static.step.oog_before_overflow`. SSTORE, CREATE and CREATE2 have no static gas. -/
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
  /-- SLOAD on an empty stack, after its 100 static gas. -/
  | sload_sload_underflow_preserve
  /-- SLOAD of a warm slot: only its 100 static gas; also the caller's later SLOAD in
  `sload.sload.child_cold_load_warms_slot`. -/
  | sload_sload_warm_success
  /-- SLOAD of a cold slot with less than the 2,000 surcharge left after its static gas: the
  skipped cold load spends all gas; also the helper's SLOAD in
  `sload.sload.failed_cold_load_leaves_slot_cold`. -/
  | sload_sload_cold_surcharge_oog_spend_all
  /-- SLOAD of a cold slot that pays the 2,000 surcharge; also the helper's SLOAD in
  `sload.sload.child_cold_load_warms_slot`, and the caller's later SLOAD in
  `sload.sload.failed_cold_load_leaves_slot_cold` and
  `sstore.dynamic.failed_store_leaves_slot_cold`. -/
  | sload_sload_cold_success
  /-- SSTORE in a static frame: `StateChangeDuringStaticCall` before any pop or charge, keeping
  all the gas. -/
  | sstore_static_frame_halt_preserve
  /-- SSTORE on fewer than two stack items, before the sentry and any charge. -/
  | sstore_sstore_underflow_preserve
  /-- SSTORE with 2,300 gas or less: the reentrancy sentry halts before any charge, keeping all
  the gas. With more, the sentry passes (`sstore.sentry.min_gas_passes`) and the step ends in
  one of the branches below. -/
  | sstore_sentry_halt_preserve
  /-- SSTORE of a warm slot that pays no write cost, only the 100 base: the new value is the
  current one, or the slot was already written in the tx (current ≠ original) (new name; cells
  `sstore.noop.warm_success`, `sstore.restore.warm_success` and `sstore.dirty.warm_success`).
  The refund of a restore is not part of the step's gas (`sstore.refund.block_gas_only`). -/
  | sstore_nowrite_warm_success
  /-- SSTORE of a cold slot that pays no write cost: 100 + 2,100 (new name; cell
  `sstore.noop.cold_success` and the cold step of `sstore.sentry.min_gas_passes`). -/
  | sstore_nowrite_cold_success
  /-- SSTORE of a non-zero value into a warm zero slot not written yet in the tx: 100 + 19,900. -/
  | sstore_fresh_warm_success
  /-- SSTORE of a non-zero value into a cold zero slot: 100 + 2,100 + 19,900. -/
  | sstore_fresh_cold_success
  /-- SSTORE of a new value into a warm non-zero slot not written yet in the tx: 100 + 2,800;
  also `sstore.clear.warm_success` (the new value is 0). -/
  | sstore_modify_warm_success
  /-- SSTORE of a new value into a cold non-zero slot: 100 + 2,100 + 2,800; also
  `sstore.clear.cold_success`, whose clearing refund is not part of the step's gas
  (`sstore.refund.block_gas_only`). -/
  | sstore_modify_cold_success
  /-- SSTORE past the sentry that cannot pay its 100 base plus its cold and set or reset cost:
  the halt spends all gas; also the warm step of `sstore.sentry.min_gas_passes` and the helper's
  SSTORE in `sstore.dynamic.failed_store_leaves_slot_cold`. -/
  | sstore_dynamic_oog_spend_all
  /-- TLOAD on an empty stack, after its 100 static gas. -/
  | transient_tload_underflow_preserve
  /-- TLOAD: only its 100 static gas. -/
  | transient_tload_success
  /-- TSTORE in a static frame: `StateChangeDuringStaticCall` after its 100 static gas, before
  the pops. -/
  | transient_static_frame_tstore_halt_preserve
  /-- TSTORE on fewer than two stack items, after its 100 static gas. -/
  | transient_tstore_underflow_preserve
  /-- TSTORE: only its 100 static gas. -/
  | transient_tstore_success
  /-- BALANCE, EXTCODESIZE or EXTCODEHASH on an empty stack, after its 100 static gas. -/
  | account_access_underflow_preserve
  /-- BALANCE, EXTCODESIZE or EXTCODEHASH of a warm account: only its 100 static gas (new name;
  cells `account.balance.warm_success`, `account.extcodesize.warm_success` and
  `account.extcodehash.warm_success`, and the caller's later BALANCE in
  `selfdestruct.selfdestruct.child_success_warms_beneficiary`). -/
  | account_access_warm_success
  /-- BALANCE, EXTCODESIZE or EXTCODEHASH of a cold account with less than the 2,500 surcharge
  left after its static gas: the skipped cold load spends all gas (new name; cells
  `account.balance.cold_surcharge_oog_spend_all`,
  `account.extcodesize.cold_surcharge_oog_spend_all` and
  `account.extcodehash.cold_surcharge_oog_spend_all`, and the child's BALANCE in
  `account.access.failed_cold_load_leaves_account_cold`). -/
  | account_access_cold_surcharge_oog_spend_all
  /-- BALANCE, EXTCODESIZE or EXTCODEHASH of a cold account that pays the 2,500 surcharge (new
  name; cells `account.balance.cold_success`, `account.extcodesize.cold_success` and
  `account.extcodehash.cold_success`, and the caller's later BALANCE in
  `account.access.failed_cold_load_leaves_account_cold`, `selfdestruct.static_frame.halt_preserve`
  and `selfdestruct.selfdestruct.failed_step_leaves_beneficiary_cold`). -/
  | account_access_cold_success
  /-- SELFDESTRUCT in a static frame: `StateChangeDuringStaticCall` after its 5,000 static gas,
  before the pop and the beneficiary load. -/
  | selfdestruct_static_frame_halt_preserve
  /-- SELFDESTRUCT on an empty stack, after its 5,000 static gas. -/
  | selfdestruct_selfdestruct_underflow_preserve
  /-- SELFDESTRUCT to a cold beneficiary with less than 2,600 gas left after its static gas: the
  skipped load spends all gas; also the child's SELFDESTRUCT in one case of
  `selfdestruct.selfdestruct.failed_step_leaves_beneficiary_cold`. -/
  | selfdestruct_selfdestruct_cold_load_skipped_spend_all
  /-- SELFDESTRUCT of a contract holding value to an empty beneficiary that cannot pay the 25,000
  new-account charge (plus 2,600 when the beneficiary was cold) after the load: the halt spends
  all gas; also the child's SELFDESTRUCT in the other case of
  `selfdestruct.selfdestruct.failed_step_leaves_beneficiary_cold`. -/
  | selfdestruct_new_account_charge_oog_spend_all
  /-- SELFDESTRUCT to a warm beneficiary with no new-account charge: only its 5,000 static gas;
  the frame ends successfully. -/
  | selfdestruct_selfdestruct_warm_success
  /-- SELFDESTRUCT to a cold beneficiary with no new-account charge (the beneficiary is not
  empty, or the contract holds no value): 5,000 + 2,600; also the child's SELFDESTRUCT in
  `selfdestruct.selfdestruct.child_success_warms_beneficiary`. -/
  | selfdestruct_selfdestruct_cold_success
  /-- SELFDESTRUCT of a contract holding value to a warm, empty beneficiary: 5,000 + 25,000. -/
  | selfdestruct_new_account_warm_success
  /-- SELFDESTRUCT of a contract holding value to a cold, empty beneficiary:
  5,000 + 2,600 + 25,000. -/
  | selfdestruct_new_account_cold_success
  /-- A CALL-family opcode whose stack runs out at either of its pops (the gas limit, the target
  and, for CALL and CALLCODE, the value; then the four memory operands), after its 100 static
  gas and before any charge. -/
  | call_family_underflow_preserve
  /-- CALL with a non-zero value in a static frame: `CallNotAllowedInsideStatic` after it pops
  the gas limit, the target and the value and before it pops the memory operands, keeping the
  gas left after its 100 static gas. -/
  | call_call_static_frame_value_halt_preserve
  /-- A CALL-family input length of 2^64 or more, before any charge. -/
  | call_family_input_size_above_u64_preserve
  /-- A CALL-family input offset of 2^64 or more with a non-zero length, before any charge. -/
  | call_family_input_offset_above_u64_preserve
  /-- A CALL-family input range whose expansion the frame cannot pay: `MemoryOOG`, keeping the
  gas. -/
  | call_family_input_memory_oog_preserve
  /-- A CALL-family output length of 2^64 or more, after the input expansion. -/
  | call_family_output_size_above_u64_keeps_input_charge
  /-- A CALL-family output offset of 2^64 or more with a non-zero length, after the input
  expansion. -/
  | call_family_output_offset_above_u64_keeps_input_charge
  /-- A CALL-family output range whose expansion, from the memory size after the input
  expansion, the frame cannot pay: `MemoryOOG`, keeping the gas; also
  `call.family.output_end_above_u64_keeps_input_charge`,
  `call.family.output_word_rounding_overflow_keeps_input_charge` and
  `call.family.output_size_above_cap_keeps_input_charge`. -/
  | call_family_output_memory_oog_keeps_input_charge
  /-- CALL or CALLCODE with a non-zero value that cannot pay the 9,000 transfer cost after its
  memory: the halt spends all gas. -/
  | call_value_transfer_oog_spend_all
  /-- A CALL-family opcode to a cold target with less than the 2,500 surcharge left after its
  memory and transfer cost: the skipped cold load spends all gas; also the CALLCODE step of
  `call.callcode.value_no_new_account_charge` one gas short of 9,000 + 2,500. -/
  | call_family_cold_surcharge_oog_spend_all
  /-- CALL with a non-zero value to an empty target that cannot pay the 25,000 new-account cost
  (plus 2,500 when the target was cold): the halt spends all gas. -/
  | call_call_new_account_oog_spend_all
  /-- A CALL-family opcode to an EIP-7702 delegated target with less than the 100 delegate read
  (plus 2,500 when the target was cold) left: the delegate load fails with `ColdLoadSkipped`,
  which spends all gas (new name; no cell, and no corpus step). -/
  | call_family_delegate_read_oog_spend_all
  /-- A CALL-family opcode to an EIP-7702 delegated target whose cold delegate's 2,500
  surcharge does not fit after the delegate read: the skipped cold load spends all gas (new
  name; no cell, and no corpus step). -/
  | call_family_delegate_cold_surcharge_oog_spend_all
  /-- A CALL-family opcode without a value transfer to a warm target without a delegation opens
  its frame: no charge beyond its 100 static gas and its memory. Cell
  `call.family.warm_target_spawn`; also the warm-target steps of the four
  `call.*.new_frame_spawn_estimate` cells and of `call.family.empty_code_spawn_estimate`, and
  `call.family.input_expansion_spawn`, `call.family.output_expansion_spawn`,
  `call.family.zero_size_no_expansion`, `call.family.precompile_spawn_estimate`,
  `call.depth.deepest_frame_created` and `call.depth.limit_short_circuit_spawn_estimate`. A CALL
  with value 0 to an empty target pays no new-account cost. -/
  | call_family_warm_target_spawn
  /-- The same to a cold target: the 2,500 surcharge. Cell `call.family.cold_target_spawn`; also
  the cold-target steps of the four `call.*.new_frame_spawn_estimate` cells and of
  `call.family.empty_code_spawn_estimate`, and `call.call.static_frame_zero_value_allowed`,
  `call.family.spawn_limit_exact_committed` and `call.family.spawn_limit_exceeded_aborted`. -/
  | call_family_cold_target_spawn
  /-- No value transfer, a warm target delegated to a warm address: the 100 delegate read (new
  name; no cell, and no corpus step). -/
  | call_family_warm_target_warm_delegate_spawn
  /-- No value transfer, a warm target delegated to a cold address: 100 + 2,500 for the
  delegate (new name; no cell, and no corpus step). -/
  | call_family_warm_target_cold_delegate_spawn
  /-- No value transfer, a cold target delegated to a warm address: 2,500 + 100 (new name; cell
  `call.family.delegated_to_precompile_empty_code`). -/
  | call_family_cold_target_warm_delegate_spawn
  /-- No value transfer, a cold target delegated to a cold address: 2,500 + 100 + 2,500 (new
  name; no cell, and no corpus step). -/
  | call_family_cold_target_cold_delegate_spawn
  /-- CALL or CALLCODE with a non-zero value to a warm target without a delegation, and no
  new-account cost: 9,000 (new name; cells `call.value.transfer_success` and
  `call.callcode.static_frame_value_allowed`, and warm steps of
  `call.value.insufficient_balance_no_frame`). -/
  | call_value_warm_target_spawn
  /-- The same to a cold target: 9,000 + 2,500 (new name; cell
  `call.callcode.value_no_new_account_charge`: CALLCODE to an empty target pays no new-account
  cost; and cold steps of `call.value.insufficient_balance_no_frame`). -/
  | call_value_cold_target_spawn
  /-- CALL with a non-zero value to a warm empty target (a precompile included):
  9,000 + 25,000 (new name; the CALL steps of `precompile.call_value.stipend_counts_as_supplied`
  and one step of `call.value.insufficient_balance_no_frame`). -/
  | call_call_new_account_warm_target_spawn
  /-- CALL with a non-zero value to a cold empty target: 9,000 + 2,500 + 25,000 (new name; cell
  `call.call.new_account_success`). -/
  | call_call_new_account_cold_target_spawn
  /-- A value transfer to a warm target delegated to a warm address: 9,000 + 100 (new name; no
  cell, and no corpus step). -/
  | call_value_warm_target_warm_delegate_spawn
  /-- A value transfer to a warm target delegated to a cold address: 9,000 + 100 + 2,500 (new
  name; no cell, and no corpus step). -/
  | call_value_warm_target_cold_delegate_spawn
  /-- A value transfer to a cold target delegated to a warm address: 9,000 + 2,500 + 100 (new
  name; no cell, and no corpus step). -/
  | call_value_cold_target_warm_delegate_spawn
  /-- A value transfer to a cold target delegated to a cold address: 9,000 + 2,500 + 100 +
  2,500 (new name; no cell, and no corpus step). -/
  | call_value_cold_target_cold_delegate_spawn
  /-- CREATE or CREATE2 in a static frame: `StateChangeDuringStaticCall` before any pop or
  charge, keeping all the gas. -/
  | create_family_static_frame_halt_preserve
  /-- CREATE or CREATE2 with fewer than three stack items (value, offset, length). -/
  | create_family_underflow_preserve
  /-- CREATE or CREATE2 with a length of 2^64 or more, before any charge. -/
  | create_family_size_above_u64_preserve
  /-- CREATE or CREATE2 with an initcode longer than 49,152 bytes: `CreateInitCodeSizeLimit`
  before any charge, keeping all the gas. -/
  | create_family_initcode_above_limit_preserve
  /-- CREATE or CREATE2 that cannot pay the 2 gas per initcode word: the halt spends all gas. -/
  | create_family_initcode_word_cost_oog_spend_all
  /-- CREATE or CREATE2 at an offset of 2^64 or more with a non-zero length, after the initcode
  word cost. -/
  | create_family_offset_above_u64_preserve_after_initcode
  /-- CREATE or CREATE2 that pays the initcode word cost but not its expansion: `MemoryOOG`,
  keeping the gas. -/
  | create_family_memory_oog_preserve_after_initcode
  /-- CREATE2 with exactly three stack items: the missing salt halts after the initcode word
  cost and expansion (none for a zero length), keeping the gas. -/
  | create_create2_salt_underflow_after_charges_preserve
  /-- CREATE that cannot pay its 32,000 base after its initcode word cost and expansion (none
  for a zero length): the halt spends all gas. -/
  | create_create_base_oog_spend_all
  /-- CREATE2 that cannot pay its one charge of the 32,000 base plus 6 gas per initcode word
  after its initcode word cost and expansion: the halt spends all gas. -/
  | create_create2_hash_oog_spend_all
  /-- CREATE that pays its initcode word cost, expansion and base and opens its frame; also
  `create.family.zero_size_no_initcode_charges` (a zero length skips the initcode charges and
  the offset), `create.family.initcode_at_limit_spawn`,
  `create.family.spawn_limit_exact_committed`, `create.family.spawn_limit_exceeded_aborted`, the
  frame-level failures `create.family.insufficient_balance_spawn_estimate`,
  `create.family.nonce_overflow_spawn_estimate`, `create.family.collision_spawn_estimate`,
  `create.family.depth_deepest_frame_created` and `create.family.depth_limit_spawn_estimate`,
  and the CREATE steps of `create.family.initcode_revert_gas_returned` and
  `create.family.code_deposit_in_frame_return`. -/
  | create_create_new_frame_spawn_estimate
  /-- CREATE2 that pays its initcode word cost, expansion, base and hashing cost and opens its
  frame; also the CREATE2 steps of the cells `create_create_new_frame_spawn_estimate` lists, and
  `create.family.initcode_halt_gas_consumed`. -/
  | create_create2_new_frame_spawn_estimate
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
  | .sload_sload_underflow_preserve => "sload_sload_underflow_preserve"
  | .sload_sload_warm_success => "sload_sload_warm_success"
  | .sload_sload_cold_surcharge_oog_spend_all => "sload_sload_cold_surcharge_oog_spend_all"
  | .sload_sload_cold_success => "sload_sload_cold_success"
  | .sstore_static_frame_halt_preserve => "sstore_static_frame_halt_preserve"
  | .sstore_sstore_underflow_preserve => "sstore_sstore_underflow_preserve"
  | .sstore_sentry_halt_preserve => "sstore_sentry_halt_preserve"
  | .sstore_nowrite_warm_success => "sstore_nowrite_warm_success"
  | .sstore_nowrite_cold_success => "sstore_nowrite_cold_success"
  | .sstore_fresh_warm_success => "sstore_fresh_warm_success"
  | .sstore_fresh_cold_success => "sstore_fresh_cold_success"
  | .sstore_modify_warm_success => "sstore_modify_warm_success"
  | .sstore_modify_cold_success => "sstore_modify_cold_success"
  | .sstore_dynamic_oog_spend_all => "sstore_dynamic_oog_spend_all"
  | .transient_tload_underflow_preserve => "transient_tload_underflow_preserve"
  | .transient_tload_success => "transient_tload_success"
  | .transient_static_frame_tstore_halt_preserve => "transient_static_frame_tstore_halt_preserve"
  | .transient_tstore_underflow_preserve => "transient_tstore_underflow_preserve"
  | .transient_tstore_success => "transient_tstore_success"
  | .account_access_underflow_preserve => "account_access_underflow_preserve"
  | .account_access_warm_success => "account_access_warm_success"
  | .account_access_cold_surcharge_oog_spend_all => "account_access_cold_surcharge_oog_spend_all"
  | .account_access_cold_success => "account_access_cold_success"
  | .selfdestruct_static_frame_halt_preserve => "selfdestruct_static_frame_halt_preserve"
  | .selfdestruct_selfdestruct_underflow_preserve => "selfdestruct_selfdestruct_underflow_preserve"
  | .selfdestruct_selfdestruct_cold_load_skipped_spend_all =>
    "selfdestruct_selfdestruct_cold_load_skipped_spend_all"
  | .selfdestruct_new_account_charge_oog_spend_all =>
    "selfdestruct_new_account_charge_oog_spend_all"
  | .selfdestruct_selfdestruct_warm_success => "selfdestruct_selfdestruct_warm_success"
  | .selfdestruct_selfdestruct_cold_success => "selfdestruct_selfdestruct_cold_success"
  | .selfdestruct_new_account_warm_success => "selfdestruct_new_account_warm_success"
  | .selfdestruct_new_account_cold_success => "selfdestruct_new_account_cold_success"
  | .call_family_underflow_preserve => "call_family_underflow_preserve"
  | .call_call_static_frame_value_halt_preserve => "call_call_static_frame_value_halt_preserve"
  | .call_family_input_size_above_u64_preserve => "call_family_input_size_above_u64_preserve"
  | .call_family_input_offset_above_u64_preserve => "call_family_input_offset_above_u64_preserve"
  | .call_family_input_memory_oog_preserve => "call_family_input_memory_oog_preserve"
  | .call_family_output_size_above_u64_keeps_input_charge =>
    "call_family_output_size_above_u64_keeps_input_charge"
  | .call_family_output_offset_above_u64_keeps_input_charge =>
    "call_family_output_offset_above_u64_keeps_input_charge"
  | .call_family_output_memory_oog_keeps_input_charge =>
    "call_family_output_memory_oog_keeps_input_charge"
  | .call_value_transfer_oog_spend_all => "call_value_transfer_oog_spend_all"
  | .call_family_cold_surcharge_oog_spend_all => "call_family_cold_surcharge_oog_spend_all"
  | .call_call_new_account_oog_spend_all => "call_call_new_account_oog_spend_all"
  | .call_family_delegate_read_oog_spend_all => "call_family_delegate_read_oog_spend_all"
  | .call_family_delegate_cold_surcharge_oog_spend_all =>
    "call_family_delegate_cold_surcharge_oog_spend_all"
  | .call_family_warm_target_spawn => "call_family_warm_target_spawn"
  | .call_family_cold_target_spawn => "call_family_cold_target_spawn"
  | .call_family_warm_target_warm_delegate_spawn => "call_family_warm_target_warm_delegate_spawn"
  | .call_family_warm_target_cold_delegate_spawn => "call_family_warm_target_cold_delegate_spawn"
  | .call_family_cold_target_warm_delegate_spawn => "call_family_cold_target_warm_delegate_spawn"
  | .call_family_cold_target_cold_delegate_spawn => "call_family_cold_target_cold_delegate_spawn"
  | .call_value_warm_target_spawn => "call_value_warm_target_spawn"
  | .call_value_cold_target_spawn => "call_value_cold_target_spawn"
  | .call_call_new_account_warm_target_spawn => "call_call_new_account_warm_target_spawn"
  | .call_call_new_account_cold_target_spawn => "call_call_new_account_cold_target_spawn"
  | .call_value_warm_target_warm_delegate_spawn => "call_value_warm_target_warm_delegate_spawn"
  | .call_value_warm_target_cold_delegate_spawn => "call_value_warm_target_cold_delegate_spawn"
  | .call_value_cold_target_warm_delegate_spawn => "call_value_cold_target_warm_delegate_spawn"
  | .call_value_cold_target_cold_delegate_spawn => "call_value_cold_target_cold_delegate_spawn"
  | .create_family_static_frame_halt_preserve => "create_family_static_frame_halt_preserve"
  | .create_family_underflow_preserve => "create_family_underflow_preserve"
  | .create_family_size_above_u64_preserve => "create_family_size_above_u64_preserve"
  | .create_family_initcode_above_limit_preserve => "create_family_initcode_above_limit_preserve"
  | .create_family_initcode_word_cost_oog_spend_all =>
    "create_family_initcode_word_cost_oog_spend_all"
  | .create_family_offset_above_u64_preserve_after_initcode =>
    "create_family_offset_above_u64_preserve_after_initcode"
  | .create_family_memory_oog_preserve_after_initcode =>
    "create_family_memory_oog_preserve_after_initcode"
  | .create_create2_salt_underflow_after_charges_preserve =>
    "create_create2_salt_underflow_after_charges_preserve"
  | .create_create_base_oog_spend_all => "create_create_base_oog_spend_all"
  | .create_create2_hash_oog_spend_all => "create_create2_hash_oog_spend_all"
  | .create_create_new_frame_spawn_estimate => "create_create_new_frame_spawn_estimate"
  | .create_create2_new_frame_spawn_estimate => "create_create2_new_frame_spawn_estimate"
  | .undefined_opcode_zero_gas_halt => "undefined_opcode_zero_gas_halt"
  | .undefined_invalid_zero_gas_halt => "undefined_invalid_zero_gas_halt"

/-- A modeled step: the frame's gas after it, how it ended and the branch that decided it.
When the step opens a new frame, `gasAfter` is the gas left after the gas it forwards; the
meter does not use it (it charges the spawn estimate), so the trace checker does not compare
it. -/
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
