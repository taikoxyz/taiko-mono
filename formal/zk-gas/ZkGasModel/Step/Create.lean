import ZkGasModel.Step.Call

/-!
# CREATE and CREATE2

revm-interpreter 43.0.1 `src/instructions/contract.rs` `create::<IS_CREATE2>` (`:26`), with
the costs of revm-context-interface 43.0.1 `src/cfg/gas_params.rs` on Unzen (`SpecId::OSAKA`,
mainnet gas params). CREATE and CREATE2 have static gas 0 and charge everything inside the
instruction, so the body gets the frame's whole gas. The operand, word cost and memory stages
are those of `ZkGasModel.Step.Memory`, and the gas a frame gets is the CALL family's
`allButOne64th` (`ZkGasModel.Step.Call`).

An instruction that passes every check takes all but one 64th of the gas left (`:140-152`) and
installs `InterpreterAction::NewFrame` (`:156-162`): the outcome is `newFrame`, whatever the
handler then does with the frame (the depth limit, the creator's balance and nonce and an
address collision are checked there). The EIP-8037 block (`:101-138`) is skipped:
`enable_amsterdam_eip8037` is off before Amsterdam (revm-context 43.0.2 `cfg.rs:238`), and
alethia-reth does not set it.
-/
namespace TaikoSpec.ZkGas

/-- `max_initcode_size` (revm-context 43.0.2 `cfg.rs:472`): with neither limit configured, which
alethia-reth does not, it is EIP-3860's `MAX_INITCODE_SIZE` before Amsterdam, twice EIP-170's
24,576 bytes (revm-primitives 43.0.0 `eip3860.rs:10`). -/
def maxInitcodeSize : Nat := 49152

/-- `initcode_per_word` (`gas::INITCODE_WORD_COST`): gas per initcode word (EIP-3860). -/
def initcodeWordGas : Nat := 2

/-- `create` (`gas::CREATE`): the base of CREATE and CREATE2. -/
def createGas : Nat := 32000

/-- Step 3 of `createStep` for a length `len` below 2^64 at `offset`, with `gas` left: a zero
length charges nothing and checks no offset. Otherwise a length above `maxInitcodeSize` halts
with `CreateInitCodeSizeLimit` (`:52`), keeping the gas; then 2 gas per initcode word
(`initcode_cost`, `gas_params.rs:660`, `:55`), whose shortfall spends all gas; then the offset
check (`:61`) and the resize to offset + length (`:62-64`), which keep the gas. The step's halt,
or the gas left. -/
def createInitcode (pre : Pre) (gas offset len : Nat) : Except String (StepResult ⊕ Nat) := do
  if len = 0 then return .inr gas
  if len > maxInitcodeSize then
    return .inl (haltKeeping gas .create_family_initcode_above_limit_preserve)
  let cost := wordCost initcodeWordGas len
  if gas < cost then return .inl (haltSpendingAll .create_family_initcode_word_cost_oog_spend_all)
  let gas := gas - cost
  if offset ≥ usizeBound then
    return .inl (haltKeeping gas .create_family_offset_above_u64_preserve_after_initcode)
  match ← expandMemory pre gas offset len with
  | none => return .inl (haltKeeping gas .create_family_memory_oog_preserve_after_initcode)
  | some left => return .inr left

/-- Step 4 of `createStep` with `gas` left: CREATE2 pops its salt (`:77`), which halts after the
initcode charges on three items, and pays one charge of 32,000 plus 6 gas per initcode word
(`create2_cost`, `gas_params.rs:673`, `:79`); CREATE pays the 32,000 base (`create_cost`, `:85`).
A shortfall spends all gas. The step's halt, or the gas left. -/
def createBase (pre : Pre) (gas len : Nat) (create2 : Bool) : StepResult ⊕ Nat :=
  if create2 then
    if pre.stackLen < 4 then
      .inl (haltKeeping gas .create_create2_salt_underflow_after_charges_preserve)
    else
      let cost := satU64 (createGas + wordCost keccakWordGas len)
      if gas < cost then .inl (haltSpendingAll .create_create2_hash_oog_spend_all)
      else .inr (gas - cost)
  else if gas < createGas then .inl (haltSpendingAll .create_create_base_oog_spend_all)
  else .inr (gas - createGas)

/-- CREATE (`create2` false) and CREATE2 (`create2` true; its PETERSBURG gate passes on Unzen):

1. `require_non_staticcall!` halts a static frame with `StateChangeDuringStaticCall` before
   anything else (`:32`), keeping the gas.
2. It pops the value, the offset and the length (`:39`) and checks the length (`:40`).
3. Only for a non-zero length (`:43`), the initcode limit, word cost and memory
   (`createInitcode`).
4. The salt of CREATE2 and the base and hashing cost (`createBase`).
5. The step opens its frame, forwarding all but one 64th of the gas left (`:150-152`). -/
def createStep (pre : Pre) (gas : Nat) (create2 : Bool) : Except String StepResult := do
  if pre.static then return haltKeeping gas .create_family_static_frame_halt_preserve
  if pre.stackLen < 3 then return haltKeeping gas .create_family_underflow_preserve
  let offset ← stackItem pre 1
  let len ← stackItem pre 2
  if len ≥ usizeBound then return haltKeeping gas .create_family_size_above_u64_preserve
  match ← createInitcode pre gas offset len with
  | .inl r => return r
  | .inr gas =>
    match createBase pre gas len create2 with
    | .inl r => return r
    | .inr gas =>
      return { gasAfter := gas - allButOne64th gas, outcome := .newFrame,
               branch := if create2 then .create_create2_new_frame_spawn_estimate
                 else .create_create_new_frame_spawn_estimate }

end TaikoSpec.ZkGas
