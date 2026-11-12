# Unzen zk gas vectors

Shared test vectors for Unzen zk gas metering. alethia-reth generates every expected value, and taiko-geth is checked against those values. Each vector is one JSON file in `cases/`, and every vector belongs to at least one cell of the coverage matrix in `coverage.json`.

| File              | Contents                                                                                                              |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| `cases/<id>.json` | One vector per file; the file name is the vector `id`.                                                                |
| `coverage.json`   | The coverage matrix. Each cell is one opcode (or group of opcodes with the same shape) × execution phase × outcome.   |
| `reference.json`  | The alethia-reth commit and revm versions that generated the expected values, and the taiko-geth commit last checked. |
| `check.py`        | Format and coverage checker (Python 3 standard library only).                                                         |
| `test_check.py`   | Tests for `check.py`.                                                                                                 |

## Checking the corpus

Run from the repository root:

```sh
python3 -m unittest testdata/zk_gas_vectors/test_check.py
python3 testdata/zk_gas_vectors/check.py                     # inputs and any expected values present
python3 testdata/zk_gas_vectors/check.py --require-expected  # every vector must carry expected values
```

`check.py` exits with status 1 and prints one line per error when the corpus is invalid.

## Coverage matrix

```json
{
  "schema_version": 1,
  "reference": "revm-interpreter 43.0.1",
  "cells": [
    {
      "id": "static.arith.success",
      "layers": ["block", "harness"],
      "source": "…",
      "description": "…"
    }
  ]
}
```

- `id` is dot-separated lowercase words (`[a-z0-9_]`). Vector ids follow the same rule.
- `layers` lists the layers whose vectors may cover the cell.
- `source` points at the code that defines the behavior, for example a revm-interpreter file and line.
- `reference` must name the `revm_interpreter` version in `reference.json`, so line numbers in `source` stay tied to one revm version.
- Every cell needs at least one vector, and every vector may only list cells that allow its layer.

## Encoding

- Integer-valued fields are canonical 0x hex: lowercase, no leading zeros, and zero is `0x0`. These are `nonce`, `gas`, `balance`, `value`, `max_fee`, `max_priority_fee`, the integer `env` fields, `frame_gas`, `zk_block_limit`, storage keys and storage values, and every zk gas value in `expected`. Runners parse them as numbers.
- Byte-valued fields are even-length 0x hex and keep their leading zeros: `data`, `code`, `raw_txs`, `state_root`, `prev_randao` (32 bytes), `extra_data` (7 bytes) and addresses (20 bytes; letter case is not checked).
- Tx indices (`included`, `truncated_at`) and `signer` are JSON integers.
- Unknown fields and duplicate JSON keys are errors.

### Accounts

`alloc` maps an address to `{ "balance", "nonce", "code", "storage" }`. `balance` is required. A missing `nonce` is `0x0`, a missing `code` is empty and a missing `storage` is empty. `storage` maps slot to value. Addresses that differ only in letter case are duplicates.

### Signers

`signer` is either `"golden_touch"` or a JSON integer `k` with `1 <= k < 2^32`. The golden touch account (`0x0000777735367b36bC9B61C50022d9D0700dB4Ec`) signs only the anchor, at index 0. For an integer `k`, the private key is `k` as a 32-byte big-endian number; get the address with `cast wallet address --private-key <k as 32-byte 0x hex>`. For example, `k = 1` is `0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf`. Never write a full private key into this directory.

### Transactions

Every tx is EIP-1559 (type 2) with no access list: `{ "signer", "nonce", "to", "gas", "max_fee", "max_priority_fee", "value", "data" }`. `to: null` is a contract creation. Blob txs, access lists and a `type` field are rejected.

## Block layer

A block vector builds one block on top of genesis and imports it.

```json
{
  "schema_version": 1,
  "id": "smoke.block.transfer",
  "layer": "block",
  "cells": ["metering.intrinsic.charged"],
  "description": "…",
  "input": {
    "env": {
      "chain_id": "0x28c59",
      "number": "0x1",
      "timestamp": "0xc",
      "base_fee": "0x17d7840",
      "coinbase": "0x…",
      "gas_limit": "0x2faf080",
      "prev_randao": "0x…",
      "extra_data": "0x…"
    },
    "alloc": { "0x…": { "balance": "0x…" } },
    "txs": [{ "signer": "golden_touch", "…": "…" }]
  },
  "expected": { "…": "…" }
}
```

The environment is fixed, and `check.py` enforces it:

- Chain id 167001 (`0x28c59`), with Shasta and Unzen active from genesis. The parent block is genesis (timestamp 0), so `number` is `0x1` and `timestamp` must be greater than zero.
- `base_fee` is 25,000,000 (`0x17d7840`), the Shasta initial base fee under a genesis parent.
- `extra_data` is exactly 7 bytes: the base fee sharing percentage followed by a 6-byte proposal id.
- `txs[0]` is the anchor: signer `golden_touch`, nonce `0x0`, `to` = `0x1670010000000000000000000000000000010001`, `data` = `0x523e6854` (the `anchorV4((uint48,bytes32,bytes32))` selector with no arguments), gas 1,000,000 (`0xf4240`), `max_priority_fee` `0x0`, `max_fee` equal to the base fee and value `0x0`.
- `alloc` holds a STOP stub (`"code": "0x00"`) at the anchor address.

The block-level zk gas limit is 100,000,000 and every tx is charged 243,000 intrinsic zk gas.

### Expected values

| Field                     | Meaning                                                                                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `raw_txs`                 | The signed EIP-2718 bytes of each input tx, one per entry of `input.txs`.                                                                      |
| `included`                | Input indices of the txs in the built block, strictly increasing, starting with 0 (the anchor).                                                |
| `truncated_at`            | The first input index dropped because the tx exceeded the block zk gas limit; `null` when nothing was truncated.                               |
| `cumulative_zk_gas`       | The block zk gas total after each included tx (one entry per `included` index), strictly increasing and within the block limit.                |
| `block_zk_gas`            | The block total, equal to the last `cumulative_zk_gas` entry and to the header `difficulty`.                                                   |
| `state_root`              | The post-block state root. A runner whose state root differs has a setup divergence, reported apart from zk gas divergences.                   |
| `import_built`            | Always `"accept"`: importing the built block succeeds.                                                                                         |
| `import_extended`         | `"reject"` when `truncated_at` is set: the built block plus `txs[truncated_at]`, with the same difficulty, must fail import. Otherwise `null`. |
| `import_wrong_difficulty` | Always `"reject"`: the built block with `difficulty + 1` must fail import.                                                                     |

**Sentinel rule.** A client that only sees which txs a block includes cannot tell a truncated tx from one skipped as invalid. Every truncated vector therefore keeps at least one valid tx after `truncated_at`; its absence from `included` shows that block building stopped there. `truncated_at` must also be greater than every included index.

## Harness layer

A harness vector runs a single call frame without building a block.

```json
{
  "schema_version": 1,
  "id": "smoke.harness.add",
  "layer": "harness",
  "cells": ["static.arith.success"],
  "description": "…",
  "input": {
    "alloc": { "0x…": { "balance": "0x0", "code": "0x600160020100" } },
    "caller": "0x…",
    "to": "0x…",
    "frame_gas": "0x186a0",
    "zk_block_limit": "0x5f5e100",
    "number": "0x1",
    "timestamp": "0xc",
    "coinbase": "0x…"
  },
  "expected": { "frame_zk_gas": "0x…", "status": "success" }
}
```

The run is equivalent to one tx from `caller` to `to` with empty calldata, value 0, gas price 0 and base fee 0:

- The top frame gets `frame_gas` gas. On alethia-reth the tx gas limit is `frame_gas + 21,000`, so `frame_gas` may be at most `2^64 - 1 - 21,000`.
- The warm set is `caller`, `to`, `coinbase` and every precompile.
- The tx gas cap and the block gas limit are both raised to `2^64 - 1`. The block zk gas limit is `zk_block_limit`.
- `frame_zk_gas` excludes the 243,000 intrinsic zk gas.
- `status` is `success`, `revert`, `halt` or `zk_limit`. For `zk_limit`, `frame_zk_gas` is `null` and only `status` is compared, because the clients record the partial zk gas of an aborted tx differently by design.

## Authoring rules

- Expected values come only from the alethia-reth runners' write mode. Never edit them by hand, and never change a vector or its expected values to make a client pass.
- Cover each cell with at least one vector, including the boundaries on both sides (gas exactly enough, and one short).
- Use the block layer when a valid block can reach the cell, and the harness layer otherwise.
- Vector code may execute `BLOCKHASH` (and, in the harness layer, `CHAINID`), but no state write or control flow may depend on the value it returns. The runners' environments legitimately differ in the parent hash, and in the harness chain id. Those values change results, not zk gas.

## Running the clients

All runners find the corpus through `ZK_GAS_VECTORS_DIR`, set to the absolute path of this directory. With it unset, the corpus tests skip, except that the alethia-reth block runner fails in write mode. With it set, a runner that finds no vector of its layer fails.

| Variable                         | Effect                                                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `ZK_GAS_VECTORS_DIR`             | Absolute path to this directory.                                                                                               |
| `ZK_GAS_VECTORS_WRITE`           | alethia-reth only: `1` writes `expected` into the vector files instead of asserting. Refused when `CI` is set: the test fails. |
| `ZK_GAS_VECTORS_KNOWN_DIVERGENT` | taiko-geth only: comma-separated vector ids to skip; the runner prints each skipped id. For local investigation only.          |

Generate expected values in alethia-reth, then rerun without `ZK_GAS_VECTORS_WRITE` to assert them:

```sh
export ZK_GAS_VECTORS_DIR=/path/to/taiko-mono/testdata/zk_gas_vectors
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-evm harness_vectors_match_expected
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_vectors_match_expected
cargo test -p alethia-reth-evm harness_vectors_match_expected
cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_vectors_match_expected
```

After generating, format the vector files with prettier before committing (the writer's JSON layout differs from prettier's), then check them:

```sh
pnpm exec prettier --write testdata/zk_gas_vectors/cases
python3 testdata/zk_gas_vectors/check.py --require-expected
```

The harness runner checks that the plain and inspector execution paths agree. The block runner also imports the built block and checks that the prover path selects the same txs with the same zk gas.

Check taiko-geth against them:

```sh
export ZK_GAS_VECTORS_DIR=/path/to/taiko-mono/testdata/zk_gas_vectors
go test ./core/vm -run '^TestZkGasHarnessVectors$' -count=1 -v
go test ./miner -run '^TestZkGasBlockVectors$' -count=1 -v
```
