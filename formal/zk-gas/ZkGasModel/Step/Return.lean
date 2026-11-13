import ZkGasModel.Step.Memory

/-!
# RETURN and REVERT

revm-interpreter 43.0.1 `src/instructions/control.rs` `return_inner` (`:73`), which RETURN
(`ret`, `:101`) and REVERT (`revert`, `:110`; its BYZANTIUM gate passes on Unzen) share. Both
have static gas 0, so each body gets the frame's whole gas. `return_inner` pops the offset and
length (`:78`) and checks the length (`:79`); only for a non-zero length does it check the
offset (`:83`) and resize memory to offset + len (`:84`). Then it sets the frame's return action
and ends the step with `Return` or `Revert` (`:88-95`), so alethia-reth's loop does not halt the
frame again: the frame keeps its gas. Its halts keep the gas too and end the frame with status
halt.
-/
namespace TaikoSpec.ZkGas

/-- RETURN (`revert` false) or REVERT (`revert` true). -/
def returnStep (pre : Pre) (gas : Nat) (revert : Bool) : Except String StepResult := do
  if pre.stackLen < 2 then return haltKeeping gas .memory_step_underflow_halt
  let offset ← stackItem pre 0
  let len ← stackItem pre 1
  if len ≥ usizeBound then return haltKeeping gas .return_inner_size_above_u64_halt
  let mut gas := gas
  if len ≠ 0 then
    if offset ≥ usizeBound then return haltKeeping gas .return_inner_offset_above_u64_halt
    match ← expandMemory pre gas offset len with
    | none => return haltKeeping gas .return_inner_memory_oog_halt
    | some left => gas := left
  if revert then return revertWith gas .return_revert_expansion_revert
  return succeedWith gas .return_return_expansion_success

end TaikoSpec.ZkGas
