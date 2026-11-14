# Lean-generated meter conformance vectors

Implement the user-approved Meter layer: Lean generates inputs and expected results; alethia-reth
and taiko-geth assert against them using their production meters.

## Shared contract

`testdata/zk_gas_vectors/meter-vectors.json` is generated deterministically by Lean 4.34.1's
`generate-meter-vectors` executable. Its top-level fields are `schema_version: 1`,
`schedule: "unzen"`, and a nonempty `vectors` array. Every vector has a unique `id`, canonical
hexadecimal u64 `block_limit`, nonempty `actions` and equally long `expected` arrays.

Actions have `kind` plus the following fields:

- `opcode`: JSON integer `op` in 0..255 and canonical hex u64 `gas` (raw gas consumed).
- `spawn`: JSON integer `op`, restricted to the six spawn opcodes; uses the schedule estimate.
- `precompile`: lowercase 20-byte `address` and canonical hex u64 `gas` (raw gas consumed).
- `intrinsic`, `commit`, `reset`: no additional fields.

Each expected entry contains `ok`, canonical hex u64 `tx_zk` and `block_zk` after that action.
Rejected charges preserve both totals. Commit moves transaction usage into the block and clears
it; reset discards transaction usage. Neither implicitly charges intrinsic gas. Sequences may
continue after rejection to test the meter API; transaction orchestration remains integration scope.

Lean computes Unzen fees, rejecting multiplication and cumulative additions above u64::MAX before
checking the configured block budget. Only the block limit is overridden per vector. No client may
write expectations. The fixed corpus covers every opcode, every listed precompile, a full-width
unlisted precompile, six spawn estimates, intrinsic, zero gas, exact/short limits, overflow,
commit/reset and rejection recovery. Include nonzero existing tx/block usage at addition boundaries.

## Implementation boundaries

The pure action interpreter belongs to the audited model; deterministic JSON and IO belong to the
trace library. Preserve seven existing propositions and their pins. Model witnesses use literal
hand-derived results; mono CI regenerates and compares the exact committed bytes.

Both client runners read `ZK_GAS_VECTORS_DIR/meter-vectors.json` and invoke public meter APIs.
Reth uses `charge_spawn_opcode`; geth passes its production `SpawnEstimate` to `ChargeOpcode`.
Precompile inputs supply gas already consumed at the meter boundary: reth calls
`charge_precompile(address, gas)` and geth calls `ChargePrecompile(address, gas, 0, nil)`.
Deriving EVM gas, precompile results and executing opcodes remain outside this layer.

Unknown schemas/actions, missing/empty corpus files, malformed action/expectation lengths and
outcome/snapshot mismatches fail. A corpus directory unset outside CI may skip, following existing
runner conventions. Client workflows explicitly require the new test; corpus refs must point to a
published mono commit containing the new file before their CI can pass. Local runs share one directory.
