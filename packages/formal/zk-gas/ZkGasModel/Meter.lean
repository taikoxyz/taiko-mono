import ZkGasModel.Tables

/-!
# Unzen schedule and zk gas metering

`Schedule` mirrors alethia-reth's `ZkGasSchedule` (`crates/evm/src/zk_gas/schedule.rs`) and
`unzen` its `UNZEN_ZK_GAS_SCHEDULE`. `meterTx` and `meterBlock` transcribe how `ZkGasMeter`
(`meter.rs`) accounts one block's charges, with every amount as an unbounded `Nat`.

A transaction is a list of charges in the order the meter applies them. The first is the
transaction's intrinsic charge (`TX_INTRINSIC_ZK_GAS`): reth charges it through the same meter
as every opcode and precompile charge, so it can abort the transaction like any other charge.
How a charge's amount is computed from an opcode or precompile is outside this file.
-/
namespace TaikoSpec.ZkGas

/-- A zk gas schedule: the block limit, the intrinsic charge, the multiplier tables and the
spawn estimates. -/
structure Schedule where
  /-- The zk gas one block may use. -/
  blockLimit : Nat
  /-- The zk gas charged to every block transaction before its first opcode or precompile. -/
  txIntrinsic : Nat
  /-- The multiplier of each opcode, indexed by opcode byte. -/
  opcodeMult : Array Nat
  /-- The multiplier of each listed precompile, keyed by full address. -/
  precompileMult : List (Nat × Nat)
  /-- The raw gas a spawn opcode is charged when it opens child work; `none` for any other
  opcode. -/
  spawnEstimate : Nat → Option Nat

/-- The Unzen schedule used by Devnet, Hoodi and Mainnet. -/
def unzen : Schedule where
  blockLimit := unzenBlockLimit
  txIntrinsic := unzenTxIntrinsic
  opcodeMult := unzenOpcodeMultipliers
  precompileMult := unzenPrecompileMultipliers
  spawnEstimate := fun op => unzenSpawnEstimates.lookup op

/-- The multiplier of the precompile at `addr`: its listed value, else the fail-safe 65535
(`ZkGasSchedule::precompile_multiplier`). -/
def precompileMult (s : Schedule) (addr : Nat) : Nat :=
  (s.precompileMult.lookup addr).getD failsafeMultiplier

/-- How a block transaction ended. -/
inductive TxStatus
  /-- Its charges fit the block's zk gas budget; its zk gas is added to the block's. -/
  | committed
  /-- A charge exceeded the block's zk gas budget. The transaction's state changes and zk gas
  are discarded, and no later transaction of the block runs. -/
  | aborted
  /-- Invalid for a reason other than zk gas; never metered. -/
  | skipped
  deriving Repr, DecidableEq

/-- One zk gas charge applied to the meter. -/
structure Charge where
  /-- The zk gas the charge adds to the transaction's total. -/
  amount : Nat
  deriving Repr, DecidableEq

/-- Adds `charges` in order to the transaction total `total`, failing as soon as the total
exceeds `budget`. -/
def meterCharges (budget : Nat) : Nat → List Nat → Option Nat
  | total, [] => some total
  | total, c :: cs => if total + c > budget then none else meterCharges budget (total + c) cs

/-- Meters one transaction's charges when the block has already used `used` zk gas.
Returns the transaction's total, intrinsic charge included, or `none` when the total exceeds
`blockLimit - used` at any charge. reth rejects a charge greater than the remaining budget,
`blockLimit - used - total` (saturating), which is the same condition. -/
def meterTx (s : Schedule) (used : Nat) (charges : List Nat) : Option Nat :=
  meterCharges (s.blockLimit - used) 0 charges

/-- Meters a block's transactions from `used` zk gas. Stops at the first transaction that
does not fit: it gets `none`, and the transactions after it get no result. -/
def meterBlockFrom (s : Schedule) : Nat → List (List Nat) → List (Option Nat) × Nat
  | used, [] => ([], used)
  | used, tx :: txs =>
    match meterTx s used tx with
    | none => ([none], used)
    | some n =>
      let rest := meterBlockFrom s (used + n) txs
      (some n :: rest.1, rest.2)

/-- Meters a block's transactions: each one's total (`some`) or abort (`none`), in block order
and ending at the first abort, and the block's total zk gas. -/
def meterBlock (s : Schedule) (txs : List (List Nat)) : List (Option Nat) × Nat :=
  meterBlockFrom s 0 txs

end TaikoSpec.ZkGas
