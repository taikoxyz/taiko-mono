import ZkGasModel.Step.Basic

/-!
# BALANCE, EXTCODESIZE, EXTCODEHASH and SELFDESTRUCT

revm-interpreter 43.0.1 `src/instructions/host.rs` (`load_account`, `balance`, `extcodesize`,
`extcodehash`, `selfdestruct`), with the costs of revm-context-interface 43.0.1
`src/cfg/gas_params.rs` on Unzen (`SpecId::OSAKA`, mainnet gas params) and the journal of
revm-context 43.0.2 (`src/journal/inner.rs`). Each body gets `gas`, the frame's gas after the
static charge: 100 for BALANCE, EXTCODESIZE and EXTCODEHASH (the warm access cost), 5,000 for
SELFDESTRUCT.

A cold account costs a surcharge inside the instruction. Before loading it, the instruction
compares the gas left with the surcharge and asks the journal to skip a cold load it cannot pay
(`skip_cold_load`); the journal then fails with `ColdLoadSkipped` before warming the account
(`journal/inner.rs:917` `load_account_mut_optional`, `journal/warm_addresses.rs:162`
`check_is_cold`), which is `OutOfGas` (`instruction_result.rs:154`) and spends all gas. Because
the skip test uses the surcharge itself, a cold load that is not skipped always pays it. Whether
the account is warm before the step is the `account_warm` fact (access list, precompiles and
coinbase included); nothing in these bodies before the load changes it.
-/
namespace TaikoSpec.ZkGas

/-- `cold_account_additional_cost` from Berlin on (`gas_params.rs:264`,
`gas::COLD_ACCOUNT_ACCESS_COST_ADDITIONAL`): `COLD_ACCOUNT_ACCESS_COST` 2,600 minus the 100 warm
access cost already in the opcode's static gas. -/
def coldAccountGas : Nat := 2500

/-- The branches of `load_account`'s three outcomes. -/
structure LoadBranches where
  warm : BranchId
  coldOog : BranchId
  cold : BranchId

/-- `load_account` (`host.rs:21`) with `gas` left: a warm account costs nothing more; a cold one
is skipped with less than the 2,500 surcharge left (`:28`), which fails with `ColdLoadSkipped`
and spends all gas, and otherwise costs the surcharge (`:30`), which it can then always pay. -/
def loadAccount (pre : Pre) (gas : Nat) (b : LoadBranches) : Except String StepResult := do
  if ← requireFact "account_warm" pre.facts.accountWarm then return continueWith gas b.warm
  if gas < coldAccountGas then return haltSpendingAll b.coldOog
  return continueWith (gas - coldAccountGas) b.cold

/-- BALANCE (`host.rs:39`), EXTCODESIZE (`:62`) and EXTCODEHASH (`:72`; its PETERSBURG gate
passes on Unzen): `popn_top!` takes the address `stack[0]` (`:40`, `:63`, `:74`;
`StackUnderflow` on an empty stack, keeping the gas), then `load_account` (`:42`, `:65`, `:76`).
Loading the code for EXTCODESIZE charges nothing more. -/
def accountAccessStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.stackLen < 1 then return haltKeeping gas .account_access_underflow_preserve
  loadAccount pre gas
    { warm := .account_access_warm_success
      coldOog := .account_access_cold_surcharge_oog_spend_all
      cold := .account_access_cold_success }

/-- `selfdestruct_cold_cost` (`gas_params.rs:458`): `cold_account_additional_cost` plus
`warm_storage_read_cost`, 2,500 + 100. SELFDESTRUCT charges nothing for a warm beneficiary. -/
def selfdestructColdGas : Nat := 2600

/-- `new_account_cost_for_selfdestruct` from Tangerine on (`gas_params.rs:241`,
`gas::NEWACCOUNT`). -/
def newAccountGas : Nat := 25000

/-- SELFDESTRUCT (`host.rs:368`). `require_non_staticcall!` halts a static frame with
`StateChangeDuringStaticCall` before anything else (`:369`); it pops the beneficiary (`:370`).
The journal's `selfdestruct` (`journal/inner.rs:655`) loads the beneficiary (`:663`), skipping a
cold one when less than 2,600 gas is left (`host.rs:376`), which is `OutOfGas` and spends all
gas. It reports whether the executing account had value (`had_value`, `:748`: its balance, the
`self_balance` fact, is non-zero) and whether the beneficiary exists (`target_exists`, `:749`:
it is not empty under EIP-161, `:665`, the `account_empty` fact). Then one charge
(`host.rs:390`) of `selfdestruct_cost` (`gas_params.rs:464`): 25,000 when value moves to an
empty beneficiary (`host.rs:384`) plus 2,600 when it was cold. A cold load that is not skipped
always pays its 2,600, so the charge can fail, spending all gas, only when it includes the
25,000. The refund it records is not gas. Last, `Err(SelfDestruct)` (`:413`) ends the frame
successfully, keeping its gas (`SelfDestruct` is a successful result,
`instruction_result.rs:167`). SELFDESTRUCT's Unzen multiplier is 0, so its zk gas is 0 whatever
the branch. -/
def selfdestructStep (pre : Pre) (gas : Nat) : Except String StepResult := do
  if pre.static then return haltKeeping gas .selfdestruct_static_frame_halt_preserve
  if pre.stackLen < 1 then return haltKeeping gas .selfdestruct_selfdestruct_underflow_preserve
  let warm ← requireFact "account_warm" pre.facts.accountWarm
  if !warm && gas < selfdestructColdGas then
    return haltSpendingAll .selfdestruct_selfdestruct_cold_load_skipped_spend_all
  let selfBalance ← requireFact "self_balance" pre.facts.selfBalance
  let empty ← requireFact "account_empty" pre.facts.accountEmpty
  let topup := selfBalance != 0 && empty
  let cost := (if topup then newAccountGas else 0) + (if warm then 0 else selfdestructColdGas)
  if gas < cost then return haltSpendingAll .selfdestruct_new_account_charge_oog_spend_all
  let branch : BranchId := match topup, warm with
    | false, true => .selfdestruct_selfdestruct_warm_success
    | false, false => .selfdestruct_selfdestruct_cold_success
    | true, true => .selfdestruct_new_account_warm_success
    | true, false => .selfdestruct_new_account_cold_success
  return succeedWith (gas - cost) branch

end TaikoSpec.ZkGas
