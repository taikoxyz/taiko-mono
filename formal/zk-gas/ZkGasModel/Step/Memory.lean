import ZkGasModel.Tables
import ZkGasModel.Step.Basic

/-!
# Memory expansion, MLOAD, MSTORE, MSTORE8, MCOPY and KECCAK256

revm-interpreter 43.0.1 `src/instructions/memory.rs` (MLOAD, MSTORE, MSTORE8, MCOPY) and
`src/instructions/system.rs` `keccak256`, with the costs of revm-context-interface 43.0.1
`src/cfg/gas_params.rs` on Unzen (`SpecId::OSAKA`, mainnet gas params). Each body gets `gas`, the
frame's gas after the static charge (3 for MLOAD, MSTORE, MSTORE8 and MCOPY, 30 for KECCAK256).

The stages these bodies share, which the copy, RETURN/REVERT and LOG bodies reuse:

- **Operands.** `as_usize_or_fail!` (`instructions/macros.rs:131`) halts with
  `InvalidOperandOOG` on an operand of 2^64 or more (`usize` on alethia-reth's 64-bit hosts);
  the halt keeps the gas.
- **Word costs.** A `gas!` charge (`macros.rs:47`) that the frame cannot pay is `OutOfGas`,
  which spends all gas. The per-word costs are `per_word.saturating_mul(num_words(len))`
  (`gas_params.rs:492` `mcopy_cost`, `:641` `keccak256_cost`, `:742` `copy_cost`).
- **Memory expansion.** `resize_memory` (`interpreter/shared_memory.rs:565`): the new size is
  `num_words(offset.saturating_add(len))` words (`:572`); when it is above the current size
  `resize_memory_cold` charges `memory_cost(new) - memory_cost(current)` (`:593-598`), and a frame
  that cannot pay it halts with `MemoryOOG` (`:600`), keeping its gas. `memory_cost`
  (`gas_params.rs:648`) is `3 * words + words * words / 512`, saturating at `u64::MAX`; past
  2^32 - 1 words (0x1FFFFFFFE0 bytes) the square saturates and the cost is beyond any gas.
  With revm's `memory_limit` feature, a size above the configured limit halts first with
  `MemoryLimitOOG` (`:589`), which also keeps the gas: the step's gas is the same.

The step's `mem` is the frame's memory size in bytes, which revm keeps at whole words
(`SharedMemory::resize` to `new_num_words * 32`, `:603`), so the current size is `mem / 32`
words.
-/
namespace TaikoSpec.ZkGas

/-- The smallest operand `as_usize_or_fail!` rejects: 2^64. -/
def usizeBound : Nat := 2 ^ 64

/-- `u64::MAX`, where revm's saturating gas arithmetic stops. -/
def u64Max : Nat := 2 ^ 64 - 1

/-- `n` saturated at `u64::MAX`. -/
def satU64 (n : Nat) : Nat := min n u64Max

/-- `num_words` (`shared_memory.rs:559`): `len` bytes rounded up to 32-byte words. -/
def numWords (len : Nat) : Nat := (len + 31) / 32

/-- `memory_linear_cost` (`gas::MEMORY`). -/
def memoryWordGas : Nat := 3

/-- `memory_quadratic_reduction`. -/
def memoryQuadraticReduction : Nat := 512

/-- `memory_cost` (`gas_params.rs:648`) of `words` words of memory. -/
def memoryCost (words : Nat) : Nat :=
  satU64 (satU64 (memoryWordGas * words) + satU64 (words * words) / memoryQuadraticReduction)

/-- `per_word.saturating_mul(num_words(len))` for a length below 2^64. -/
def wordCost (perWord len : Nat) : Nat := satU64 (perWord * numWords len)

/-- `copy_per_word` and `mcopy_per_word` (`gas::COPY`). -/
def copyWordGas : Nat := 3

/-- `keccak256_per_word` (`gas::KECCAK256WORD`). -/
def keccakWordGas : Nat := 6

/-- The step's memory size in words. -/
def memoryWords (pre : Pre) : Except String Nat :=
  if pre.mem % 32 = 0 then .ok (pre.mem / 32)
  else .error s!"mem: {pre.mem} bytes is not a whole number of 32-byte words"

/-- `resize_memory` for `len` bytes at `offset`, both below 2^64, with `gas` left: the gas left
after the expansion, or `none` when the frame cannot pay it (`MemoryOOG`, keeping `gas`). -/
def expandMemory (pre : Pre) (gas offset len : Nat) : Except String (Option Nat) := do
  let current ← memoryWords pre
  let words := numWords (satU64 (offset + len))
  if words ≤ current then return some gas
  let cost := memoryCost words - memoryCost current
  return if gas < cost then none else some (gas - cost)

/-- MLOAD (`memory.rs:11`), MSTORE (`:29`) and MSTORE8 (`:45`), which access `len` bytes (32,
or 1 for MSTORE8) at their offset `stack[0]`: they pop their `inputs op` items (`popn_top!` or
`popn!`), check the offset (`as_usize_or_fail!`, `:13`, `:31`, `:47`) and resize memory to the
offset + `len` (`:14`, `:34`, `:50`). -/
def memoryAccessStep (pre : Pre) (gas len : Nat) : Except String StepResult := do
  if pre.stackLen < inputs pre.op then return haltKeeping gas .memory_step_underflow_halt
  let offset ← stackItem pre 0
  if offset ≥ usizeBound then return haltKeeping gas .memory_access_offset_above_u64_preserve
  match ← expandMemory pre gas offset len with
  | none => return haltKeeping gas .memory_access_memory_oog_preserve
  | some gas => return continueWith gas .memory_access_expansion_success

/-- MCOPY (`memory.rs:69`; its CANCUN gate passes on Unzen): pops `dst`, `src` and `len`
(`:71`), checks `len` (`:74`) and charges its copy cost (`:76`) before anything else; a zero
length returns there (`:81`); then it checks `dst` (`:85`) and `src` (`:86`) and resizes memory
to `max(dst, src) + len` (`:88`). -/
def mcopyStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 3 then return haltKeeping gas .memory_step_underflow_halt
  let dst ← stackItem pre 0
  let src ← stackItem pre 1
  let len ← stackItem pre 2
  if len ≥ usizeBound then return haltKeeping gas .memory_mcopy_size_above_u64_preserve
  let cost := wordCost copyWordGas len
  if gas < cost then return haltSpendingAll .memory_mcopy_copy_oog_spend_all
  let gas := gas - cost
  if len = 0 then return continueWith gas .memory_mcopy_zero_size_no_expansion
  if dst ≥ usizeBound then return haltKeeping gas .memory_mcopy_dst_above_u64_preserve
  if src ≥ usizeBound then return haltKeeping gas .memory_mcopy_src_above_u64_preserve
  match ← expandMemory pre gas (max dst src) len with
  | none => return haltKeeping gas .memory_mcopy_memory_oog_preserve
  | some gas => return continueWith gas .memory_mcopy_expansion_success

/-- KECCAK256 (`system.rs:18`): `popn_top!` pops the offset `stack[0]` and leaves the length
`stack[1]` (`:19`), checks the length (`:20`) and charges 6 gas per word (`:21`); a zero length
hashes nothing and skips the offset (`:25`); then it checks the offset (`:28`) and resizes
memory to offset + len (`:29`). -/
def keccakStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 2 then return haltKeeping gas .memory_step_underflow_halt
  let offset ← stackItem pre 0
  let len ← stackItem pre 1
  if len ≥ usizeBound then return haltKeeping gas .keccak_keccak256_size_above_u64_preserve
  let cost := wordCost keccakWordGas len
  if gas < cost then return haltSpendingAll .keccak_keccak256_word_oog_spend_all
  let gas := gas - cost
  if len = 0 then return continueWith gas .keccak_keccak256_zero_size_no_expansion
  if offset ≥ usizeBound then return haltKeeping gas .keccak_keccak256_offset_above_u64_preserve
  match ← expandMemory pre gas offset len with
  | none => return haltKeeping gas .keccak_keccak256_memory_oog_preserve
  | some gas => return continueWith gas .keccak_keccak256_expansion_success

end TaikoSpec.ZkGas
