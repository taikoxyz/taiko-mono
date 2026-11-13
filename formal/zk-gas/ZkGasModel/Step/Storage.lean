import ZkGasModel.Step.Static

/-!
# SLOAD, SSTORE, TLOAD and TSTORE

revm-interpreter 43.0.1 `src/instructions/host.rs` (`sload`, `sstore`,
`sstore_with_gas_accounting`, `sstore_default_gas_accounting`, `tload`, `tstore`), with the
costs of revm-context-interface 43.0.1 `src/cfg/gas_params.rs` on Unzen (`SpecId::OSAKA`,
mainnet gas params: the Berlin table, `:262`). Each body gets `gas`, the frame's gas after the
static charge: 100 for SLOAD, TLOAD and TSTORE, 0 for SSTORE, which charges its costs inside the
instruction.

A cold slot load is skipped like a cold account load (`ZkGasModel.Step.Account`): the journal
fails with `ColdLoadSkipped` before warming the slot (revm-context-interface
`src/journaled_state/account.rs:187`, `:202`), which is `OutOfGas` and spends all gas. Whether
the slot `stack[0]` of the executing account is warm before the step is the `slot_warm` fact;
`original` is its value at the start of the transaction and `current` its present value.

TLOAD and TSTORE check `CANCUN` first (`host.rs:320`, `:307`), which passes on Unzen.
-/
namespace TaikoSpec.ZkGas

/-- `cold_storage_additional_cost` from Berlin on (`gas_params.rs:266`): `COLD_SLOAD_COST` 2,100
minus the 100 warm read already in SLOAD's static gas. -/
def coldSloadSurchargeGas : Nat := 2000

/-- SLOAD (`host.rs:165`): `popn_top!` takes the slot (`:166`; `StackUnderflow` on an empty
stack, keeping the gas). A cold slot is skipped with less than the 2,000 surcharge left (`:172`,
`:175`), which spends all gas, and otherwise costs the surcharge (`:177`), which it can then
always pay. A warm slot costs nothing more. -/
def sloadStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 1 then return haltKeeping gas .sload_sload_underflow_preserve
  if ← requireFact "slot_warm" pre.facts.slotWarm then
    return continueWith gas .sload_sload_warm_success
  if gas < coldSloadSurchargeGas then
    return haltSpendingAll .sload_sload_cold_surcharge_oog_spend_all
  return continueWith (gas - coldSloadSurchargeGas) .sload_sload_cold_success

/-- `call_stipend` (`gas_params.rs:226`, `gas::CALL_STIPEND`): SSTORE's EIP-2200 reentrancy
sentry. -/
def callStipend : Nat := 2300

/-- `sstore_static` from Berlin on (`gas_params.rs:263`, `gas::WARM_STORAGE_READ_COST`): the base
every SSTORE that passes the sentry pays. -/
def sstoreBaseGas : Nat := 100

/-- `cold_storage_cost` from Berlin on (`gas_params.rs:268`, `gas::COLD_SLOAD_COST`). -/
def coldSloadGas : Nat := 2100

/-- `sstore_set_without_load_cost` from Berlin on (`gas_params.rs:273`): `SSTORE_SET` 20,000
minus the 100 base. -/
def sstoreSetGas : Nat := 19900

/-- `sstore_reset_without_cold_load_cost` from Berlin on (`gas_params.rs:271`):
`WARM_SSTORE_RESET` 2,900 minus the 100 base. -/
def sstoreResetGas : Nat := 2800

/-- SSTORE (`host.rs:193`, `sstore_with_gas_accounting` `:203`). `require_non_staticcall!` halts
a static frame with `StateChangeDuringStaticCall` before anything else (`:216`); it pops the
slot and the new value `stack[1]` (`:217`); with 2,300 gas or less left the EIP-2200 sentry
halts with `ReentrancySentryOOG` (`:224-228`), which keeps the gas (`Interpreter::halt` spends
it only for `OutOfGas`). None of these reads a fact. Past the sentry, more than 2,300 gas is
left, so the 100 base charge (`:230`) cannot fail, and neither can the slot load
(`sstore_skip_cold_load`, `:236-240`), which is skipped only below 2,100 gas. Then
`sstore_default_gas_accounting` (`:252`) charges `sstore_dynamic_gas` (`:265`;
`gas_params.rs:545`, Istanbul and later): 2,100 for a cold slot (`:559`), plus, when the new
value changes a slot not yet written in the transaction (`current = original`, `:564`), 19,900
to set a zero slot or 2,800 to reset a non-zero one (`:565-572`). A frame that cannot pay it
halts out of gas, spending all its gas. The refund it records (`:295`) is not gas. -/
def sstoreStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.static then return haltKeeping gas .sstore_static_frame_halt_preserve
  if pre.stackLen < 2 then return haltKeeping gas .sstore_sstore_underflow_preserve
  if gas ≤ callStipend then return haltKeeping gas .sstore_sentry_halt_preserve
  let gas := gas - sstoreBaseGas
  let new ← stackItem pre 1
  let warm ← requireFact "slot_warm" pre.facts.slotWarm
  let original ← requireFact "original" pre.facts.original
  let current ← requireFact "current" pre.facts.current
  let (writeCost, branch) : Nat × BranchId :=
    if new ≠ current ∧ original = current then
      if original = 0 then
        (sstoreSetGas, if warm then .sstore_fresh_warm_success else .sstore_fresh_cold_success)
      else
        (sstoreResetGas, if warm then .sstore_modify_warm_success else .sstore_modify_cold_success)
    else (0, if warm then .sstore_nowrite_warm_success else .sstore_nowrite_cold_success)
  let cost := (if warm then 0 else coldSloadGas) + writeCost
  if gas < cost then return haltSpendingAll .sstore_dynamic_oog_spend_all
  return continueWith (gas - cost) branch

/-- TLOAD (`host.rs:319`): `popn_top!` takes the slot (`:321`); the transient read charges
nothing. -/
def tloadStep (pre : Pre) (gas : Nat) : StepResult :=
  popStep pre gas 1 .transient_tload_underflow_preserve .transient_tload_success

/-- TSTORE (`host.rs:306`): `require_non_staticcall!` halts a static frame with
`StateChangeDuringStaticCall` (`:308`) before it pops the slot and value (`:309`); the transient
write charges nothing. Both halts keep the gas left after the static 100. -/
def tstoreStep (pre : Pre) (gas : Nat) : StepResult :=
  if pre.static then haltKeeping gas .transient_static_frame_tstore_halt_preserve
  else popStep pre gas 2 .transient_tstore_underflow_preserve .transient_tstore_success

end TaikoSpec.ZkGas
