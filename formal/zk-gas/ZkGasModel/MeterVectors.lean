import ZkGasModel.Meter

/-!
# Checked meter API semantics

An action starts at the production meter boundary: raw EVM gas is already known. This model
computes the fee and the observable transaction/block totals, including checked u64 arithmetic.
It deliberately exposes commit/reset rather than executing transactions or interpreting opcodes.
-/
namespace TaikoSpec.ZkGas.MeterVectors

/-- The largest amount representable by the client meters. -/
def maxU64 : Nat := 18446744073709551615

/-- One production meter API call. Precompile gas has already been consumed by its execution. -/
inductive Action where
  | opcode (op gas : Nat)
  | spawn (op : Nat)
  | precompile (address gas : Nat)
  | intrinsic
  | commit
  | reset
  deriving Repr, DecidableEq

/-- Observable meter usage; rejected charges leave both fields unchanged. -/
structure State where
  txZk : Nat := 0
  blockZk : Nat := 0
  deriving Repr, DecidableEq

/-- A call's verdict and the observable usage after it returns. -/
structure Snapshot where
  ok : Bool
  txZk : Nat
  blockZk : Nat
  deriving Repr, DecidableEq

/-- Attach a call's verdict to its resulting state. -/
def snapshot (ok : Bool) (state : State) : Snapshot :=
  { ok, txZk := state.txZk, blockZk := state.blockZk }

/-- The unbounded attempted charge, or no amount for malformed or non-charge actions. -/
def actionAmount (s : Schedule) : Action → Option Nat
  | .opcode op gas =>
    if op < 256 ∧ gas ≤ maxU64 then
      some (gas * s.opcodeMult.getD op failsafeMultiplier)
    else none
  | .spawn op => (s.spawnEstimate op).map (· * s.opcodeMult.getD op failsafeMultiplier)
  | .precompile address gas =>
    if address < 2 ^ 160 ∧ gas ≤ maxU64 then some (gas * precompileMult s address) else none
  | .intrinsic => some s.txIntrinsic
  | .commit | .reset => none

/-- Apply checked multiplication/addition and the block limit before mutating usage. -/
def charge (s : Schedule) (state : State) (amount : Nat) : Snapshot :=
  let nextTx := state.txZk + amount
  let projected := state.blockZk + nextTx
  if amount > maxU64 ∨ nextTx > maxU64 ∨ projected > maxU64 ∨ projected > s.blockLimit then
    snapshot false state
  else snapshot true { state with txZk := nextTx }

/-- Execute one meter action. Failed charges preserve usage; reset restores discarded budget. -/
def applyAction (s : Schedule) (state : State) (action : Action) : Snapshot :=
  match action with
  | .reset => snapshot true { state with txZk := 0 }
  | .commit =>
    let total := state.blockZk + state.txZk
    if total > maxU64 ∨ total > s.blockLimit then snapshot false state
    else snapshot true { txZk := 0, blockZk := total }
  | _ =>
    match actionAmount s action with
    | some amount => charge s state amount
    | none => snapshot false state

/-- Execute an action sequence from a supplied state, retaining a snapshot after every action. -/
def runFrom (s : Schedule) (state : State) : List Action → List Snapshot
  | [] => []
  | action :: rest =>
    let result := applyAction s state action
    result :: runFrom s { txZk := result.txZk, blockZk := result.blockZk } rest

/-- Start a fresh production meter and execute all actions, including those after a rejection. -/
def runActions (s : Schedule) (actions : List Action) : List Snapshot := runFrom s {} actions

end TaikoSpec.ZkGas.MeterVectors
