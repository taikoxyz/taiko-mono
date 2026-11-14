import ZkGasModel.Step.Memory

/-!
# LOG0..LOG4

revm-interpreter 43.0.1 `src/instructions/host.rs` `log::<N>` (`:332`), with `log_cost` of
revm-context-interface 43.0.1 `src/cfg/gas_params.rs:633`. The body gets `gas`, the frame's gas
after the 375 static gas `Interpreter::step` charges first (`instructions.rs:471`), so a LOG that
cannot pay it halts out of gas before any check below.
-/
namespace TaikoSpec.ZkGas

/-- `logdata` (`gas::LOGDATA`): gas per data byte. -/
def logDataGas : Nat := 8

/-- `logtopic` (`gas::LOGTOPIC`): gas per topic. -/
def logTopicGas : Nat := 375

/-- `log_cost(n, len)`: `8.saturating_mul(len).saturating_add(375 * n)`, one charge for the data
and the topics. -/
def logCost (n len : Nat) : Nat := satU64 (satU64 (logDataGas * len) + logTopicGas * n)

/-- LOGn with `n` topics: `require_non_staticcall!` halts a static frame with
`StateChangeDuringStaticCall` before anything else (`:333`); it pops the offset and length
(`:335`), checks the length (`:336`) and charges `log_cost` (`:337`); only for a non-zero length
does it check the offset (`:344`) and resize memory to offset + len (`:348`); it pops the `n`
topics last (`:351`), so a missing topic halts with `StackUnderflow` after every charge. The
halts other than the `log_cost` charge keep the gas. -/
def logStep (pre : Pre) (gas n : Nat) : Except String StepResult := do
  if pre.static then return haltKeeping gas .log_static_frame_halt_preserve
  if pre.stackLen < 2 then return haltKeeping gas .log_logn_stack_underflow_preserve
  let offset ← stackItem pre 0
  let len ← stackItem pre 1
  if len ≥ usizeBound then return haltKeeping gas .log_logn_size_above_u64_preserve
  let cost := logCost n len
  if gas < cost then return haltSpendingAll .log_logn_cost_oog_spend_all
  let mut gas := gas - cost
  if len ≠ 0 then
    if offset ≥ usizeBound then return haltKeeping gas .log_logn_offset_above_u64_preserve
    match ← expandMemory pre gas offset len with
    | none => return haltKeeping gas .log_logn_memory_oog_preserve
    | some left => gas := left
  if pre.stackLen < 2 + n then return haltKeeping gas .log_topics_underflow_preserve
  return continueWith gas .log_logn_success

end TaikoSpec.ZkGas
