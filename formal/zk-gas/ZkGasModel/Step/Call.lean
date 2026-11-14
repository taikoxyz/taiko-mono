import ZkGasModel.Step.Memory
import ZkGasModel.Step.Account

/-!
# CALL, CALLCODE, DELEGATECALL and STATICCALL

revm-interpreter 43.0.1 `src/instructions/contract.rs` `call` (`:166`) and
`src/instructions/contract/call_helpers.rs` (`get_memory_input_and_out_ranges`,
`resize_memory`, `load_acc_and_calc_gas`, `load_account_delegated`), with the costs of
revm-context-interface 43.0.1 `src/cfg/gas_params.rs` on Unzen (`SpecId::OSAKA`, mainnet gas
params). The body gets `gas`, the frame's gas after the 100 static gas (the warm access cost).
The operand and memory stages are those of `ZkGasModel.Step.Memory`; the cold load is that of
`ZkGasModel.Step.Account`.

An instruction that passes every check takes the gas it forwards and installs
`InterpreterAction::NewFrame` (`contract.rs:227-246`): the outcome is `newFrame`, whatever the
handler then does with the frame (the depth limit, the caller's balance, an empty code or a
precompile target are checked there). The EIP-8037 state gas of `load_acc_and_calc_gas`
(`call_helpers.rs:86`) is 0: `enable_amsterdam_eip8037` is off before Amsterdam (revm-context
43.0.2 `cfg.rs:238`), and alethia-reth does not set it.

Whether the target `stack[1]` is warm and empty and whether its EIP-7702 delegate is warm are
the step's facts `account_warm`, `account_empty` and `delegate_warm`, read before the step.
revm loads the target, which warms it, before the delegate (`call_helpers.rs:162`, `:189`).
The optional `delegate_is_target` fact records when these addresses alias: after a successful
target load the delegate is warm even when its initial `delegate_warm` was false.
-/
namespace TaikoSpec.ZkGas

/-- `transfer_value_cost` (`gas_params.rs:694`, `gas::CALLVALUE`). -/
def callValueGas : Nat := 9000

/-- `new_account_cost(is_spurious_dragon, transfers_value)` with a transfer
(`gas_params.rs:718`, `gas::NEWACCOUNT`); without one it is 0 from Spurious Dragon on. -/
def callNewAccountGas : Nat := 25000

/-- `warm_storage_read_cost` from Berlin on (`gas_params.rs:736`,
`gas::WARM_STORAGE_READ_COST`): the read of an EIP-7702 delegate. -/
def delegateReadGas : Nat := 100

/-- `call_stipend_reduction` (`gas_params.rs:688`): all but one 64th of `gas` (EIP-150). -/
def allButOne64th (gas : Nat) : Nat := gas - gas / 64

/-- The success branch of a call that opens its frame without a delegate: by whether it
transfers value and whether its target was warm. -/
def callSpawnBranch : Bool → Bool → BranchId
  | false, true => .call_family_warm_target_spawn
  | false, false => .call_family_cold_target_spawn
  | true, true => .call_value_warm_target_spawn
  | true, false => .call_value_cold_target_spawn

/-- The success branch of a call to an EIP-7702 delegated target: by whether it transfers
value, whether its target was warm and whether the delegate was warm. -/
def callDelegateSpawnBranch : Bool → Bool → Bool → BranchId
  | false, true, true => .call_family_warm_target_warm_delegate_spawn
  | false, true, false => .call_family_warm_target_cold_delegate_spawn
  | false, false, true => .call_family_cold_target_warm_delegate_spawn
  | false, false, false => .call_family_cold_target_cold_delegate_spawn
  | true, true, true => .call_value_warm_target_warm_delegate_spawn
  | true, true, false => .call_value_warm_target_cold_delegate_spawn
  | true, false, true => .call_value_cold_target_warm_delegate_spawn
  | true, false, false => .call_value_cold_target_cold_delegate_spawn

/-- A call that pays its charges with `gas` left opens its frame, forwarding all but one 64th
of `gas` up to its gas limit, `stack[0]` saturated to `u64` (`contract.rs:188`;
`call_helpers.rs:92-101`). The 2,300 stipend of a value transfer is added to the forwarded gas
after this charge (`:104-106`), so the frame keeps what is left. -/
def callSpawn (pre : Pre) (gas : Nat) (branch : BranchId) : Except String StepResult := do
  let gasLimit := min (← stackItem pre 0) u64Max
  let forwarded := min (allButOne64th gas) gasLimit
  return { gasAfter := gas - forwarded, outcome := .newFrame, branch, forwarded }

/-- One memory range of `get_memory_input_and_out_ranges` (`call_helpers.rs:42-45`), `len`
bytes at `offset` of a memory of `words` words with `gas` left: a length of 2^64 or more halts
(branch `size`); only a non-zero length checks its offset (`offset`) and expansion (`oog`). These
halts keep the gas. Otherwise the gas and the memory size in words after the range. -/
def callRange (gas words offset len : Nat) (size offsetAbove oog : BranchId) :
    StepResult ⊕ (Nat × Nat) :=
  if len ≥ usizeBound then .inl (haltKeeping gas size)
  else if len = 0 then .inr (gas, words)
  else if offset ≥ usizeBound then .inl (haltKeeping gas offsetAbove)
  else match resizeMemory words gas offset len with
    | none => .inl (haltKeeping gas oog)
    | some left => .inr left

/-- `get_memory_input_and_out_ranges` (`call_helpers.rs:16`) on a memory of `words` words with
`gas` left: the input range (`:22`), then the output range from the memory size the input range
leaves (`:29`). The step's halt, or the gas left after both. -/
def callRanges (gas words inOffset inLen outOffset outLen : Nat) : StepResult ⊕ Nat :=
  match callRange gas words inOffset inLen .call_family_input_size_above_u64_preserve
      .call_family_input_offset_above_u64_preserve .call_family_input_memory_oog_preserve with
  | .inl r => .inl r
  | .inr (gas, words) =>
    match callRange gas words outOffset outLen
        .call_family_output_size_above_u64_keeps_input_charge
        .call_family_output_offset_above_u64_keeps_input_charge
        .call_family_output_memory_oog_keeps_input_charge with
    | .inl r => .inl r
    | .inr (gas, _) => .inr gas

/-- `load_account_delegated` (`call_helpers.rs:145`) and the cost's `gas!` (`:83`) with `gas`
left after the transfer cost, then the frame (`callSpawn`). A cold target is skipped with less
than 2,500 left (`:161`), which spends all gas, and otherwise costs 2,500 (`:163-165`). For CALL
(`create_empty_account`) to an empty target, the cost adds the new-account cost, 25,000 with a
value transfer and 0 without, and stops there (`:169-177`): an empty account has no code.
Otherwise a target whose code is an EIP-7702 delegation adds the 100 delegate read (`:180-182`)
and fails with `ColdLoadSkipped` when the cost passes the gas left (`:183-185`); a cold delegate
is skipped when the cost plus 2,500 passes the gas left (`:188-190`) and otherwise adds 2,500
(`:192-194`). Both failures spend all gas. Last, one `gas!` of the cost: only a cost with the
new-account charge can fail it, since every other part was checked against the gas left; its
shortfall spends all gas. -/
def callTarget (pre : Pre) (gas : Nat) (transfer : Bool) : Except String StepResult := do
  let warm ← requireFact "account_warm" pre.facts.accountWarm
  if !warm && gas < coldAccountGas then
    return haltSpendingAll .call_family_cold_surcharge_oog_spend_all
  let cost := if warm then 0 else coldAccountGas
  if pre.op = 0xf1 then
    if ← requireFact "account_empty" pre.facts.accountEmpty then
      if !transfer then return ← callSpawn pre (gas - cost) (callSpawnBranch false warm)
      let cost := cost + callNewAccountGas
      if gas < cost then return haltSpendingAll .call_call_new_account_oog_spend_all
      return ← callSpawn pre (gas - cost)
        (if warm then .call_call_new_account_warm_target_spawn
         else .call_call_new_account_cold_target_spawn)
  match ← requireFact "delegate_warm" pre.facts.delegateWarm with
  | none => callSpawn pre (gas - cost) (callSpawnBranch transfer warm)
  | some delegateWarm =>
    let delegateWarm := delegateWarm || pre.facts.delegateIsTarget
    let cost := cost + delegateReadGas
    if cost > gas then return haltSpendingAll .call_family_delegate_read_oog_spend_all
    if !delegateWarm && gas < cost + coldAccountGas then
      return haltSpendingAll .call_family_delegate_cold_surcharge_oog_spend_all
    let cost := if delegateWarm then cost else cost + coldAccountGas
    callSpawn pre (gas - cost) (callDelegateSpawnBranch transfer warm delegateWarm)

/-- The CALL family (`contract.rs:166`; the HOMESTEAD gate of DELEGATECALL and the BYZANTIUM
gate of STATICCALL pass on Unzen):

1. CALL and CALLCODE pop the gas limit, the target and the value; DELEGATECALL and STATICCALL
   the gas limit and the target, with value 0 (`:179-185`).
2. CALL with a non-zero value in a static frame halts with `CallNotAllowedInsideStatic`
   (`:191`), keeping the gas.
3. `get_memory_input_and_out_ranges` (`callRanges`) pops the input offset and length and the
   output offset and length (`call_helpers.rs:20`), then resizes memory for the input range and
   then for the output range; its halts keep the gas.
4. `load_acc_and_calc_gas` (`call_helpers.rs:61`): a non-zero value pays the 9,000 transfer
   cost (`:69-74`), a `gas!` whose shortfall spends all gas; then the target (`callTarget`).
5. The step opens its frame (`callSpawn`). -/
def callStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  let pops := if pre.op = 0xf1 ∨ pre.op = 0xf2 then 3 else 2
  if pre.stackLen < pops then return haltKeeping gas .call_family_underflow_preserve
  let value ← if pops = 3 then stackItem pre 2 else pure 0
  let transfer := value != 0
  if pre.op == 0xf1 && pre.static && transfer then
    return haltKeeping gas .call_call_static_frame_value_halt_preserve
  if pre.stackLen < pops + 4 then return haltKeeping gas .call_family_underflow_preserve
  let inOffset ← stackItem pre pops
  let inLen ← stackItem pre (pops + 1)
  let outOffset ← stackItem pre (pops + 2)
  let outLen ← stackItem pre (pops + 3)
  match callRanges gas (← memoryWords pre) inOffset inLen outOffset outLen with
  | .inl r => return r
  | .inr gas =>
    if !transfer then return ← callTarget pre gas false
    if gas < callValueGas then return haltSpendingAll .call_value_transfer_oog_spend_all
    callTarget pre (gas - callValueGas) true

end TaikoSpec.ZkGas
