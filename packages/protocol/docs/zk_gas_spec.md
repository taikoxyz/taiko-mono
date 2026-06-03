# [Specs] ZK Gas

## Objective

Cap proving time per block with a protocol constant `BLOCK_ZK_GAS_LIMIT`

## Protocol Constants

| Constant | Value | Description |
| --- | --- | --- |
| `BLOCK_ZK_GAS_LIMIT` | 100,000,000 | Maximum zk gas allowed per block. See [Appendix C](#appendix-c-block_zk_gas_limit-rationale) for rationale. |
| `TX_INTRINSIC_ZK_GAS` | 243,000 | Fixed zk gas charged once per transaction, primarily covering sender ecrecovery cost. |

## Core Idea

`zk gas` is a weighted gas metric — the gas consumed by each opcode and precompile is scaled by a proving-cost multiplier.

Each block transaction also pays `TX_INTRINSIC_ZK_GAS` before opcode or precompile metering begins.

Each block has a `BLOCK_ZK_GAS_LIMIT`. If cumulative zk gas exceeds this limit during execution, the offending tx is aborted (all state changes discarded, as if the tx was never executed) and all remaining txs are skipped. Txs that completed before the offending one are kept.

Three areas require special handling:
- Transaction intrinsic cost — see [Pseudocode](#pseudocode)
- Spawn opcodes (`CALL`, `CREATE` family) — see [Problem with Spawn Opcodes](#problem-with-spawn-opcodes)
- Precompile calls — see [Precompile Metering](#precompile-metering)

## Multiplier Source

Multipliers are derived from per-opcode proving time benchmarks based on the methodology in [Measuring Per-Opcode Proving Time](https://ethresear.ch/t/measuring-per-opcode-proving-time/23955).

Reference table:

- Full in-doc snapshot: [Appendix B: Full ZK Multipliers](#appendix-b-full-zk-multipliers)
- Raw data: [Google Sheets](https://docs.google.com/spreadsheets/d/1WLH9Wgz6ktfnns5tTI1mF3xMG_CqDyQTnhlD3al-9oM/edit?usp=sharing)

Example rows:

```text
Operation              Multiplier
modexp (precompile)    923
point_evaluation       859
bls12_pairing          365
blake2f                166
mulmod (opcode)        113
...
```

## Pseudocode

Definitions:

- `step_gas`: the total gas charged by the EVM for executing one opcode, including both the static cost (from the opcode gas table) and any dynamic cost (memory expansion, storage access charges, etc.). Measured as `gas_spent_after - gas_spent_before` across a single opcode execution.
- `SPAWN_OPCODES`: `CALL`, `CALLCODE`, `DELEGATECALL`, `STATICCALL`, `CREATE`, `CREATE2`
- `child_frame_created`: true only when a spawn opcode creates a child EVM execution frame.
- `precompile_invoked`: true when a CALL-family opcode (`CALL`, `CALLCODE`, `DELEGATECALL`, `STATICCALL`) resolves to an active precompile and executes it.
- `tx_intrinsic_zk_gas`: transaction-level zk gas charged once per transaction, equal to `TX_INTRINSIC_ZK_GAS`.
- `opcode_multiplier[opcode]`: per-opcode proving-cost multiplier. All valid opcodes are listed in [Appendix B](#appendix-b-full-zk-multipliers). Unlisted opcodes default to `max(uint16)` (fail-safe).
- `precompile_multiplier[addr]`: per-precompile proving-cost multiplier, indexed by the low byte of the precompile address. All active precompiles are listed in [Appendix B](#appendix-b-full-zk-multipliers). Unlisted precompiles default to `max(uint16)` (fail-safe).
- Multiplier values are listed in [Appendix B](#appendix-b-full-zk-multipliers).
- **Arithmetic**: all zk gas arithmetic uses unsigned 64-bit integers. If any intermediate multiplication or addition overflows, the transaction is treated as having exceeded its limit and execution is halted immediately.

```python
# --- Types ---
# uint64: unsigned 64-bit integer
# uint16: unsigned 16-bit integer
# opcode_multiplier: array[256] of uint16, indexed by opcode byte (0x00..0xFF)
# precompile_multiplier: array[256] of uint16, indexed by low byte of precompile address

# --- Transaction-level constants ---
TX_INTRINSIC_ZK_GAS = 243_000

# --- Spawn estimation constants ---
SPAWN_ESTIMATE = {
    CALL:         12_500,
    CALLCODE:     12_500,
    DELEGATECALL:  3_500,
    STATICCALL:    3_500,
    CREATE:       37_000,
    CREATE2:      44_500,
}

# --- Per-opcode hook (called for every EVM opcode execution) ---

def on_opcode(opcode: uint8, step_gas: uint64, child_frame_created: bool, precompile_invoked: bool):
    # child_frame_created is True only for real child EVM frame creation.
    # precompile_invoked is True for CALL-family dispatch to precompiles.
    # If both are false, the opcode short-circuited at call-site and step_gas is used.
    if opcode in SPAWN_OPCODES and (child_frame_created or precompile_invoked):
        raw_gas: uint64 = SPAWN_ESTIMATE[opcode]
    else:
        raw_gas: uint64 = step_gas

    tx_zk_gas_used += raw_gas * opcode_multiplier[opcode]

    if block_zk_gas_used + tx_zk_gas_used > BLOCK_ZK_GAS_LIMIT:
        halt_execution()  # stop immediately, do not execute further opcodes


# --- Precompile hook (called when a CALL-family opcode resolves to a precompile) ---

def on_precompile(precompile_address: uint8, gas_used: uint64):
    tx_zk_gas_used += gas_used * precompile_multiplier[precompile_address]

    if block_zk_gas_used + tx_zk_gas_used > BLOCK_ZK_GAS_LIMIT:
        halt_execution()


# --- Block-level validation ---
# All transactions in the block are metered, including the anchor transaction.

def execute_block(txs, BLOCK_ZK_GAS_LIMIT: uint64):
    block_zk_gas_used: uint64 = 0

    for tx in txs:
        tx_zk_gas_used: uint64 = 0

        tx_zk_gas_used += TX_INTRINSIC_ZK_GAS
        if block_zk_gas_used + tx_zk_gas_used > BLOCK_ZK_GAS_LIMIT:
            halt_execution()

        if was_halted():                # zk gas limit exceeded before tx execution
            abort_tx(tx)               # discard ALL state changes for the entire tx
            break                      # skip all remaining txs

        execute_tx(tx)  # triggers on_opcode / on_precompile hooks above

        if was_halted():                # zk gas limit exceeded mid-tx
            abort_tx(tx)               # discard ALL state changes for the entire tx
            break                      # skip all remaining txs

        block_zk_gas_used += tx_zk_gas_used
```

## Precompile Metering

Precompile calls do not execute opcodes — the EVM runs them directly and returns a result without creating a child execution frame. The per-opcode metering loop never sees precompile work, so precompiles must be metered explicitly.

Precompile detection is implementation-defined (e.g. checking the active precompile set for the current fork). The multiplier is indexed by the low byte of the precompile address.

When a CALL-family opcode targets a precompile address:

- The CALL-family opcode itself is metered via `on_opcode` with `precompile_invoked = True` and uses `SPAWN_ESTIMATE[opcode]` as raw gas (not `step_gas`). This covers only opcode-side spawn overhead.
- `precompile_zk = precompile_gas_used * precompile_multiplier[low_byte]`
- `precompile_gas_used` is the gas charged by the precompile's own gas schedule (`base_cost + data_cost`), excluding the CALL-family opcode's own costs (cold account access, memory expansion, value transfer stipend). This is the value deducted from the calling frame's gas counter when the precompile runs.
- The charge is applied after the precompile executes, since gas cost is only known after execution. Since precompiles are atomic (no child opcodes), the block limit check fires before any subsequent opcode.

## Problem with Spawn Opcodes

*Spawn opcodes* are opcodes that open a child execution frame (`CALL`, `CALLCODE`, `DELEGATECALL`, `STATICCALL`, `CREATE`, `CREATE2`), and they pre-charge parent gas with child budget before child execution. If we meter parent step gas naively and also meter child execution, some child path gets counted twice.

Illustration:

```text
TX
└── Frame L0
    ├── CALL step raw-gas delta includes:
    │   CALL overhead + *forwarded child budget*
    ├── Frame L1 child steps are also metered
    └── result: overlap between parent CALL reserved-child component and child-frame metered execution
```

In practice, the CALL opcode step can look very large (for example ~10_700) because it includes forwarded gas, not just CALL overhead.

### Chosen Solution

For spawn opcodes, do not use the observed opcode-step raw gas delta, because it includes forwarded child budget.
Instead, use a fixed spawn estimate per opcode type.
Meter child-frame opcode/precompile execution normally.

With this design, no return-time reconciliation or post-return correction is needed.

Spawn estimation constants:

| Opcode | Estimated raw gas |
| --- | ---: |
| `CALL` | 12,500 |
| `CALLCODE` | 12,500 |
| `DELEGATECALL` | 3,500 |
| `STATICCALL` | 3,500 |
| `CREATE` | 37,000 |
| `CREATE2` | 44,500 |

Each constant is the base cost (assuming cold state access, worst case) plus headroom to account for typical input/output/initcode lengths. CALL/CALLCODE/DELEGATECALL/STATICCALL include 500 gas of headroom; CREATE/CREATE2 include more to cover max-size contracts (24KB per EIP-170). See [Appendix A](#appendix-a-spawn-estimation-details) for derivation.

### Alternative Considered: Reconciliation

Direction:

- Meter parent spawn step with observed raw gas.
- Meter child execution directly.
- On child return, compute and subtract correction to remove overlap.

Why not chosen now:

1. Complexity is much higher (frame metadata + return-time correction).
2. It introduces temporary double counting between spawn and return. Temporary double counting can trigger limit checks too early unless enforcement is carefully delayed/structured.

For current benchmarking and block-level budgeting, spawn estimation is simpler operationally than reconciliation while reducing coarse fixed-cost error.

## Appendix A: Spawn Estimation Details

### Base costs

Base terms assume **cold state access** (worst case) to be conservative:

- `CALL`/`CALLCODE` 12,000 = cold access (2,600) + value transfer (9,000) + base (100) + rounding
- `DELEGATECALL`/`STATICCALL` 3,000 = cold access (2,600) + base (100) + rounding (no value transfer)
- `CREATE` 35,000 = base (32,000) + cold access (2,600) + rounding
- `CREATE2` 38,000 = base (32,000) + cold access (2,600) + minimum hashing + rounding

### Headroom

Each constant includes headroom above the base cost to account for input/output/initcode lengths:

- `CALL`/`CALLCODE` (+500): covers ~5,300 bytes of combined input+output.
- `DELEGATECALL`/`STATICCALL` (+500): same.
- `CREATE` (+2,000): ~32,000 bytes of initcode (at 2 gas per 32-byte word).
- `CREATE2` (+6,500): ~26,000 bytes of initcode (at 8 gas per 32-byte word).

Caveats:

- This remains an estimation model, not exact EVM gas replay.
- Fixed constants trade precision for simplicity. Calls with very large payloads (>5KB) will be slightly underestimated.

## Appendix B: Full ZK Multipliers

All valid opcodes and all active precompiles are listed below. Unlisted opcodes or precompiles (e.g. added by future hard forks) default to `max(uint16)`, which will immediately exceed the block limit and make missing entries obvious.

### Precompile Multipliers

Indexed by the low byte of the precompile address. Sorted by multiplier descending.

| Precompile | Address | Multiplier |
| --- | --- | ---: |
| modexp | 0x05 | 923 |
| point_evaluation | 0x0a | 859 |
| bls12_pairing | 0x0f | 365 |
| bls12_map_fp_to_g1 | 0x10 | 246 |
| bls12_g2add | 0x0d | 230 |
| bls12_map_fp2_to_g2 | 0x11 | 208 |
| bls12_g1add | 0x0b | 201 |
| blake2f | 0x09 | 166 |
| p256verify | 0x100 | 163 |
| bls12_g1msm | 0x0c | 93 |
| bls12_g2msm | 0x0e | 71 |
| bn128_mul | 0x07 | 58 |
| bn128_pairing | 0x08 | 54 |
| ecrecover | 0x01 | 47 |
| bn128_add | 0x06 | 19 |
| sha256 | 0x02 | 10 |
| identity | 0x04 | 6 |
| ripemd160 | 0x03 | 4 |

### Opcode Multipliers

Indexed by opcode byte. Sorted by multiplier descending.

| Opcode | Byte | Multiplier |
| --- | --- | ---: |
| mulmod | 0x09 | 113 |
| sdiv | 0x05 | 78 |
| div | 0x04 | 76 |
| mod | 0x06 | 66 |
| addmod | 0x08 | 52 |
| selfbalance | 0x47 | 52 |
| prevrandao | 0x44 | 42 |
| eq | 0x14 | 36 |
| swap15 | 0x9e | 36 |
| swap6 | 0x95 | 34 |
| swap11 | 0x9a | 33 |
| swap5 | 0x94 | 33 |
| swap12 | 0x9b | 32 |
| swap3 | 0x92 | 32 |
| swap9 | 0x98 | 32 |
| keccak256 | 0x20 | 31 |
| swap1 | 0x90 | 31 |
| swap10 | 0x99 | 31 |
| swap13 | 0x9c | 31 |
| swap14 | 0x9d | 31 |
| swap16 | 0x9f | 31 |
| swap4 | 0x93 | 31 |
| swap7 | 0x96 | 31 |
| swap2 | 0x91 | 30 |
| swap8 | 0x97 | 30 |
| mstore | 0x52 | 29 |
| push30 | 0x7d | 29 |
| push29 | 0x7c | 28 |
| smod | 0x07 | 28 |
| push24 | 0x77 | 24 |
| push26 | 0x79 | 24 |
| shl | 0x1b | 24 |
| staticcall | 0xfa | 23 |
| calldataload | 0x35 | 22 |
| push23 | 0x76 | 22 |
| push25 | 0x78 | 22 |
| shr | 0x1c | 22 |
| sub | 0x03 | 22 |
| exp | 0x0a | 21 |
| origin | 0x32 | 21 |
| push15 | 0x6e | 21 |
| sar | 0x1d | 21 |
| call | 0xf1 | 20 |
| callcode | 0xf2 | 20 |
| jumpdest | 0x5b | 20 |
| or | 0x17 | 20 |
| push17 | 0x70 | 20 |
| push19 | 0x72 | 20 |
| push20 | 0x73 | 20 |
| slt | 0x12 | 20 |
| add | 0x01 | 19 |
| address | 0x30 | 19 |
| and | 0x16 | 19 |
| gt | 0x11 | 19 |
| lt | 0x10 | 19 |
| mul | 0x02 | 19 |
| push32 | 0x7f | 19 |
| sgt | 0x13 | 19 |
| caller | 0x33 | 18 |
| coinbase | 0x41 | 18 |
| mload | 0x51 | 18 |
| push18 | 0x71 | 18 |
| push21 | 0x74 | 18 |
| xor | 0x18 | 18 |
| byte | 0x1a | 17 |
| delegatecall | 0xf4 | 17 |
| push14 | 0x6d | 17 |
| push28 | 0x7b | 17 |
| signextend | 0x0b | 17 |
| iszero | 0x15 | 16 |
| push27 | 0x7a | 16 |
| push31 | 0x7e | 16 |
| blobbasefee | 0x4a | 15 |
| gasprice | 0x3a | 15 |
| not | 0x19 | 15 |
| push12 | 0x6b | 15 |
| push13 | 0x6c | 15 |
| push8 | 0x67 | 15 |
| basefee | 0x48 | 14 |
| push22 | 0x75 | 14 |
| blobhash | 0x49 | 13 |
| calldatacopy | 0x37 | 13 |
| calldatasize | 0x36 | 13 |
| gaslimit | 0x45 | 13 |
| msize | 0x59 | 13 |
| pc | 0x58 | 13 |
| push0 | 0x5f | 13 |
| push16 | 0x6f | 13 |
| push9 | 0x68 | 13 |
| codecopy | 0x39 | 12 |
| number | 0x43 | 12 |
| push10 | 0x69 | 12 |
| push11 | 0x6a | 12 |
| push6 | 0x65 | 12 |
| returndatasize | 0x3d | 12 |
| callvalue | 0x34 | 11 |
| chainid | 0x46 | 11 |
| codesize | 0x38 | 11 |
| dup5 | 0x84 | 11 |
| gas | 0x5a | 11 |
| dup1 | 0x80 | 10 |
| dup10 | 0x89 | 10 |
| dup11 | 0x8a | 10 |
| dup16 | 0x8f | 10 |
| dup4 | 0x83 | 10 |
| dup8 | 0x87 | 10 |
| mstore8 | 0x53 | 10 |
| pop | 0x50 | 10 |
| push4 | 0x63 | 10 |
| push7 | 0x66 | 10 |
| returndatacopy | 0x3e | 10 |
| timestamp | 0x42 | 10 |
| dup12 | 0x8b | 9 |
| dup13 | 0x8c | 9 |
| dup3 | 0x82 | 9 |
| dup9 | 0x88 | 9 |
| push1 | 0x60 | 9 |
| push3 | 0x62 | 9 |
| push5 | 0x64 | 9 |
| dup14 | 0x8d | 8 |
| dup15 | 0x8e | 8 |
| dup2 | 0x81 | 8 |
| dup6 | 0x85 | 8 |
| dup7 | 0x86 | 8 |
| push2 | 0x61 | 8 |
| extcodehash | 0x3f | 7 |
| blockhash | 0x40 | 6 |
| jumpi | 0x57 | 5 |
| sstore | 0x55 | 5 |
| tstore | 0x5d | 5 |
| balance | 0x31 | 4 |
| extcodecopy | 0x3c | 4 |
| extcodesize | 0x3b | 4 |
| jump | 0x56 | 4 |
| mcopy | 0x5e | 4 |
| log0 | 0xa0 | 3 |
| log1 | 0xa1 | 3 |
| sload | 0x54 | 3 |
| log2 | 0xa2 | 2 |
| log3 | 0xa3 | 2 |
| log4 | 0xa4 | 2 |
| create | 0xf0 | 1 |
| create2 | 0xf5 | 1 |
| tload | 0x5c | 1 |
| invalid | 0xfe | 0 |
| return | 0xf3 | 0 |
| revert | 0xfd | 0 |
| selfdestruct | 0xff | 0 |
| stop | 0x00 | 0 |

Terminal opcodes (`stop`, `return`, `revert`, `selfdestruct`, `invalid`) have multiplier `0` — execution ends at these opcodes so no further zk gas cost is incurred.

## Appendix C: BLOCK_ZK_GAS_LIMIT Rationale

The initial value of 100M is a placeholder derived from the following model:

- **Proving setup**: 4× GPUs, 1-second block times, 384 blocks per proposal (one epoch = 12 × 32 slots).
- **Target proving deadline**: ~12 hours → total budget of ~43.2B zk gas across 384 blocks → ~112.5M per block.
- 100M is a conservative round-down from 112.5M.

The table below shows how the per-block limit scales with proving deadline, assuming 384 blocks per proposal. Values in the EVM Gas columns show the equivalent conventional gas budget if every opcode in the block were of that single type.

| Proving Deadline | Total ZK Budget | ZK_GAS_LIMIT (÷384) | EVM Gas (modexp@923×) | EVM Gas (keccak256@31×) | EVM Gas (add@19×) | EVM Gas (push1@9×) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 hours | 7.2B | 18.75M | 20.3K | 604.8K | 986.8K | 2.08M |
| 4 hours | 14.4B | 37.5M | 40.6K | 1.21M | 1.97M | 4.17M |
| 6 hours | 21.6B | 56.25M | 60.9K | 1.81M | 2.96M | 6.25M |
| 8 hours | 28.8B | 75M | 81.3K | 2.42M | 3.95M | 8.33M |
| 12 hours | 43.2B | 112.5M | 121.9K | 3.63M | 5.92M | 12.50M |
| 24 hours | 86.4B | 225M | 243.8K | 7.26M | 11.84M | 25.00M |

**This value is a placeholder and will almost certainly change.** Factors that will influence the final value include: number of GPUs available, prover software improvements and target proving deadline chosen for production.

`BLOCK_ZK_GAS_LIMIT` is a protocol-level constraint designed to prevent the case where the protocol completely stalls due to unprovable blocks. Preconfers and/or provers may set a stricter custom zk gas limit based on their own proving setup.
