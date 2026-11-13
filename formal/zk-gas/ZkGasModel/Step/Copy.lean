import ZkGasModel.Step.Memory
import ZkGasModel.Step.Account

/-!
# CALLDATACOPY, CODECOPY, RETURNDATACOPY and EXTCODECOPY

revm-interpreter 43.0.1 `src/instructions/system.rs` (`calldatacopy`, `codecopy`,
`returndatacopy` and their shared `copy_cost_and_memory_resize`) and `src/instructions/host.rs`
(`extcodecopy`). Each body gets `gas`, the frame's gas after the static charge (3, or 100 for
EXTCODECOPY). The operand, word cost and memory stages are those of `ZkGasModel.Step.Memory`.
The source offset is saturated (`as_usize_saturated!`) and charges nothing; copying past the end
of calldata or code fills zeros.
-/
namespace TaikoSpec.ZkGas

/-- The branches of the stages of `copy_cost_and_memory_resize` that end a step. -/
structure CopyBranches where
  copyOog : BranchId
  zeroSize : BranchId
  offsetAboveU64 : BranchId
  memoryOog : BranchId
  success : BranchId

/-- `copy_cost_and_memory_resize` (`system.rs:247`) for `len` bytes (below 2^64) to memory
offset `memOffset`: 3 gas per word (`:254`), a zero length returns (`:255`), then the memory
offset check (`:258`) and the resize to offset + len (`:259`). -/
def copyCostAndResize (pre : Pre) (gas memOffset len : Nat) (b : CopyBranches) :
    Except String StepResult := do
  let cost := wordCost copyWordGas len
  if gas < cost then return haltSpendingAll b.copyOog
  let gas := gas - cost
  if len = 0 then return continueWith gas b.zeroSize
  if memOffset ≥ usizeBound then return haltKeeping gas b.offsetAboveU64
  match ← expandMemory pre gas memOffset len with
  | none => return haltKeeping gas b.memoryOog
  | some gas => return continueWith gas b.success

/-- CALLDATACOPY (`system.rs:156`) and CODECOPY (`:88`): pop the memory offset, the source
offset and the length (`:157`, `:89`), check the length (`:158`, `:90`), then
`copy_cost_and_memory_resize` (`:159`, `:91`). -/
def dataCopyStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 3 then return haltKeeping gas .memory_step_underflow_halt
  let memOffset ← stackItem pre 0
  let len ← stackItem pre 2
  if len ≥ usizeBound then return haltKeeping gas .copy_datacopy_size_above_u64_preserve
  copyCostAndResize pre gas memOffset len
    { copyOog := .copy_datacopy_copy_oog_spend_all
      zeroSize := .copy_datacopy_zero_size_no_expansion
      offsetAboveU64 := .copy_datacopy_offset_above_u64_preserve
      memoryOog := .copy_datacopy_memory_oog_preserve
      success := .copy_datacopy_expansion_success }

/-- RETURNDATACOPY (`system.rs:200`; its BYZANTIUM gate passes on Unzen): pops the memory
offset, the source offset and the length (`:202`) and checks the length (`:204`); then, before
any charge, the source range: the source offset saturated to `usize` (`:205`) plus the length,
saturating (`:208`), must not pass the return data, whose size is the `returndata_size` fact,
or the step halts with `OutOfOffset` (`:209`), keeping the gas; then
`copy_cost_and_memory_resize` (`:213`). -/
def returndatacopyStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 3 then return haltKeeping gas .memory_step_underflow_halt
  let memOffset ← stackItem pre 0
  let dataOffset ← stackItem pre 1
  let len ← stackItem pre 2
  if len ≥ usizeBound then return haltKeeping gas .copy_returndatacopy_size_above_u64_preserve
  let size ← requireFact "returndata_size" pre.facts.returndataSize
  if satU64 (min dataOffset u64Max + len) > size then
    return haltKeeping gas .copy_returndatacopy_out_of_bounds_preserve
  copyCostAndResize pre gas memOffset len
    { copyOog := .copy_returndatacopy_copy_oog_spend_all
      zeroSize := .copy_returndatacopy_zero_size_no_expansion
      offsetAboveU64 := .copy_returndatacopy_offset_above_u64_preserve
      memoryOog := .copy_returndatacopy_memory_oog_preserve
      success := .copy_returndatacopy_expansion_success }

/-- EXTCODECOPY (`host.rs:90`): pops the address, the memory offset, the code offset and the
length (`:91`), checks the length (`:97`) and charges 3 gas per word (`:98`); only for a
non-zero length does it check the memory offset (`:107`) and resize memory (`:111`). Then
`load_account` (`:114`; `loadAccount` in `ZkGasModel.Step.Account`) loads the target: a warm
one costs nothing more, a cold one the 2,500 surcharge, and a cold load with less than 2,500 gas
left is skipped, which spends all gas. -/
def extcodecopyStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 4 then return haltKeeping gas .memory_step_underflow_halt
  let memOffset ← stackItem pre 1
  let len ← stackItem pre 3
  if len ≥ usizeBound then return haltKeeping gas .copy_extcodecopy_size_above_u64_preserve
  let cost := wordCost copyWordGas len
  if gas < cost then return haltSpendingAll .copy_extcodecopy_copy_oog_spend_all
  let mut gas := gas - cost
  if len ≠ 0 then
    if memOffset ≥ usizeBound then
      return haltKeeping gas .copy_extcodecopy_offset_above_u64_preserve
    match ← expandMemory pre gas memOffset len with
    | none => return haltKeeping gas .copy_extcodecopy_memory_oog_preserve
    | some left => gas := left
  loadAccount pre gas
    { warm := .copy_extcodecopy_warm_success
      coldOog := .copy_extcodecopy_cold_surcharge_oog_spend_all
      cold := .copy_extcodecopy_cold_success }

end TaikoSpec.ZkGas
