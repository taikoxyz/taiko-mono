/-!
# The state a step runs from

`Pre` is what the step model sees of the interpreter right before one opcode runs: the frame's
remaining gas, the top of the stack, the memory size and the few state facts the opcode's gas
depends on. Trace step events carry exactly these fields (trace schema v1 in
`testdata/zk_gas_vectors/README.md`); `ZkGasTraces` parses them.
-/
namespace TaikoSpec.ZkGas

/-- State facts a step reads before it runs. Each field is `none` unless the opcode's trace
step records it (`jumpdest_valid` for JUMP and JUMPI, `slot_warm`, `original` and `current` for
SSTORE, and so on; see the schema). -/
structure Facts where
  /-- JUMP, JUMPI: whether the target `stack[0]` is a valid JUMPDEST. -/
  jumpdestValid : Option Bool := none
  /-- RETURNDATACOPY: the size of the current return data buffer. -/
  returndataSize : Option Nat := none
  /-- SLOAD, SSTORE: whether the slot `stack[0]` is warm. -/
  slotWarm : Option Bool := none
  /-- SSTORE: the slot's value at the start of the transaction. -/
  original : Option Nat := none
  /-- SSTORE: the slot's current value. -/
  current : Option Nat := none
  /-- Account-access opcodes, the CALL family and SELFDESTRUCT: whether the target account is
  warm. -/
  accountWarm : Option Bool := none
  /-- The CALL family and SELFDESTRUCT: whether the target account is empty. -/
  accountEmpty : Option Bool := none
  /-- The CALL family: whether the target's EIP-7702 delegate is warm before the step (`some
  none` when the target has no delegation). `delegateIsTarget` tells the model whether the
  target load warms this address before the delegate access. -/
  delegateWarm : Option (Option Bool) := none
  /-- The CALL family: the EIP-7702 delegate is the target itself. The target load warms the
  delegate before its access. Absent in older traces, which contain no self-delegation. -/
  delegateIsTarget : Bool := false
  /-- SELFDESTRUCT: the executing account's balance. -/
  selfBalance : Option Nat := none
  deriving Repr, DecidableEq

/-- The interpreter state right before a step. -/
structure Pre where
  /-- The opcode byte. -/
  op : Nat
  /-- The frame's call depth; a transaction's top frame is 1. -/
  depth : Nat
  /-- The program counter of the opcode. -/
  pc : Nat
  /-- The frame's remaining gas before the step. -/
  gas : Nat
  /-- Whether the frame is static (STATICCALL context). -/
  static : Bool
  /-- The stack length. -/
  stackLen : Nat
  /-- The top `min stackLen (inputs op)` stack items, top first. -/
  stack : List Nat
  /-- The memory size in bytes. -/
  mem : Nat
  /-- The state facts the opcode records. -/
  facts : Facts
  deriving Repr, DecidableEq

end TaikoSpec.ZkGas
