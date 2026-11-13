import ZkGasModel

/-!
# Table and metering regressions

Executable `#guard` checks of the generated Unzen and revm tables and of the meter. They run
during compilation and are not kernel proofs. The table values are spot checks against
`packages/protocol/docs/zk_gas_spec.md` (Appendix B) and revm's Osaka gas table.
-/

open TaikoSpec.ZkGas

-- Tables: ADD and PUSH1 multipliers, point_evaluation and an unlisted precompile (fail-safe).
#guard unzen.opcodeMult[0x01]! = 19
#guard unzen.opcodeMult[0x60]! = 9
#guard precompileMult unzen 0x0a = 859
#guard precompileMult unzen 0x12 = 65535
-- revm static gas: ADD is 3; CREATE's table entry is 0 (revm charges CREATE's base dynamically).
#guard staticGas 0x01 = 3 ∧ staticGas 0xf0 = 0

-- Meter: a transaction that fits returns its total, intrinsic charge included.
#guard meterTx unzen 0 [243000, 111] = some 243111
-- A charge one above what the block has left aborts the transaction.
#guard meterTx unzen 99757001 [243000] = none
-- The aborted second transaction adds nothing to the block total.
#guard (meterBlock unzen [[243000], [243000, 99757001]]).2 = 243000

-- Boundaries: a total exactly at the block limit fits; the results end at the abort, so a
-- third transaction is not executed.
#guard meterTx unzen 99757000 [243000] = some 243000
#guard (meterBlock unzen [[243000], [243000, 99757001], [243000]]) = ([some 243000, none], 243000)
-- Table shape: 256 opcode multipliers, the fail-safe for an undefined opcode, spawn estimates
-- only for spawn opcodes, and revm's stack inputs.
#guard unzen.opcodeMult.size = 256 ∧ unzen.opcodeMult[0x0c]! = 65535
#guard unzen.spawnEstimate 0xf1 = some 12500 ∧ unzen.spawnEstimate 0x01 = none
#guard inputs 0xf1 = 7 ∧ inputs 0x01 = 2 ∧ inputs 0x0c = 0
