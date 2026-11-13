# Unzen zk gas vectors

Shared test vectors for Unzen zk gas metering. alethia-reth generates every expected value, and taiko-geth is checked against those values. Each vector is one JSON file in `cases/`, and every vector belongs to at least one cell of the coverage matrix in `coverage.json`.

| File                | Contents                                                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `cases/<id>.json`   | One vector per file; the file name is the vector `id`.                                                                |
| `traces/<id>.jsonl` | The zk gas trace of one vector (see [Trace schema v1](#trace-schema-v1)).                                             |
| `coverage.json`     | The coverage matrix. Each cell is one opcode (or group of opcodes with the same shape) × execution phase × outcome.   |
| `reference.json`    | The alethia-reth commit and revm versions that generated the expected values, and the taiko-geth commit last checked. |
| `check.py`          | Format and coverage checker (Python 3 standard library only).                                                         |
| `test_check.py`     | Tests for `check.py`.                                                                                                 |

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

## Trace schema v1

A trace records the zk gas events of one vector's run on alethia-reth: `traces/<id>.jsonl`, one JSON object per line, ending with a newline. Traces are generated by alethia-reth together with the expected values and are never edited by hand. [`formal/zk-gas`](../../formal/zk-gas) re-checks every trace against its Lean metering model and the vector's expected values (`lake exe check-traces`).

The examples below are taken from the generated traces. `traces/smoke.block.transfer.jsonl` (the anchor runs its STOP stub, then a plain transfer runs no code):

```text
{"e":"intrinsic","zk":"0x3b538","ok":true}
{"e":"step","d":1,"pc":0,"op":0,"gas":"0xeeff8","static":false,"sl":0,"stack":[],"mem":"0x0","facts":{},"gas_after":"0xeeff8","spawn":false,"zk":"0x0","ok":true,"charged":true}
{"e":"tx_end","index":0,"status":"committed","tx_zk":"0x3b538"}
{"e":"intrinsic","zk":"0x3b538","ok":true}
{"e":"tx_end","index":1,"status":"committed","tx_zk":"0x3b538"}
```

`traces/smoke.harness.add.jsonl` (PUSH1 1, PUSH1 2, ADD, STOP):

```text
{"e":"step","d":1,"pc":0,"op":96,"gas":"0x186a0","static":false,"sl":0,"stack":[],"mem":"0x0","facts":{},"gas_after":"0x1869d","spawn":false,"zk":"0x1b","ok":true,"charged":true}
{"e":"step","d":1,"pc":2,"op":96,"gas":"0x1869d","static":false,"sl":1,"stack":[],"mem":"0x0","facts":{},"gas_after":"0x1869a","spawn":false,"zk":"0x1b","ok":true,"charged":true}
{"e":"step","d":1,"pc":4,"op":1,"gas":"0x1869a","static":false,"sl":2,"stack":["0x2","0x1"],"mem":"0x0","facts":{},"gas_after":"0x18697","spawn":false,"zk":"0x39","ok":true,"charged":true}
{"e":"step","d":1,"pc":5,"op":0,"gas":"0x18697","static":false,"sl":1,"stack":[],"mem":"0x0","facts":{},"gas_after":"0x18697","spawn":false,"zk":"0x0","ok":true,"charged":true}
{"e":"frame_end","status":"success","frame_zk":"0x6f"}
```

Two lines of `traces/precompile.point_evaluation.bad_input.jsonl`: a STATICCALL step charged its spawn estimate (`3500 * 23`), then the point evaluation run it opened, which fails on its invalid input and is charged all 51,000 gas it was given (`(51000 - 0) * 859`):

```text
{"e":"step","d":1,"pc":18,"op":250,"gas":"0xf4202","static":false,"sl":6,"stack":["0xc738","0xa","0x0","0xbf","0x0","0x0"],"mem":"0xc0","facts":{"account_warm":true,"account_empty":true,"delegate_warm":null},"gas_after":"0xe7a66","spawn":true,"zk":"0x13a74","ok":true,"charged":true}
{"e":"precompile","addr":"0x000000000000000000000000000000000000000a","supplied":"0xc738","left":"0x0","success":false,"zk":"0x29c78e8","ok":true}
```

### Events

Each event has exactly these fields, in this order, so that traces diff line by line:

| Event        | Fields                                                                                                            |
| ------------ | ----------------------------------------------------------------------------------------------------------------- |
| `intrinsic`  | `e`, `zk`, `ok`                                                                                                   |
| `step`       | `e`, `d`, `pc`, `op`, `gas`, `static`, `sl`, `stack`, `mem`, `facts`, `gas_after`, `spawn`, `zk`, `ok`, `charged` |
| `precompile` | `e`, `addr`, `supplied`, `left`, `success`, `zk`, `ok`                                                            |
| `tx_end`     | `e`, `index`, `status`, `tx_zk`                                                                                   |
| `frame_end`  | `e`, `status`, `frame_zk`                                                                                         |

- `pc`, `d`, `op`, `sl` and `index` are JSON integers, and `addr` is a 20-byte lowercase address. Every other quantity is canonical 0x hex, as in the vectors.
- `intrinsic` starts a block tx with its 243,000 intrinsic zk gas.
- `step` is one interpreter step. `d` is the call depth (a tx's top frame is 1), `pc` the program counter, `op` the opcode, `gas` the frame's remaining gas before the step, `static` whether the frame is static, `sl` the stack length and `mem` the memory size in bytes. `stack` holds the top `min(sl, inputs(op))` items, top first, with `inputs(op)` from the table below. `facts` holds the state facts listed under [Facts](#facts).
- `gas_after` is the gas the meter sees after the step. `spawn` is true when the step opened a new frame (the CALL and CREATE families), which charges the opcode's spawn estimate instead; `gas_after` is then only for reference and is not compared or checked.
- `zk` is the zk gas the event charged. `ok` is false when the meter refused the charge because it exceeded the limit; `zk` then holds the amount it tried to charge. `charged` is false only for a step the client did not meter at all, whose `zk` is `0x0`.
- `precompile` is one precompile run: `addr` is the call's bytecode (code) address, the one alethia-reth meters, which for DELEGATECALL and CALLCODE is the called code's address, not the storage context. `supplied` is the gas it was given and `left` the gas it had left. `success` is true when the precompile returned without halting (a revert, which keeps its unspent gas, counts); a halt leaves no gas, so `left` is `0x0` when `success` is false. `zk` is `(supplied - left)` times the precompile's multiplier.
- `tx_end` ends a block tx: `index` is its input index and `status` is `committed`, `aborted` (a charge exceeded the block zk gas limit) or `skipped` (invalid for another reason; its charges are discarded). `tx_zk` is a committed tx's total, intrinsic included, and `null` otherwise. A tx that alethia-reth rejects before charging its intrinsic zk gas, because its gas limit exceeds the gas the block has left, has a lone `tx_end` with status `skipped` and no other event.
- `frame_end` ends a harness run: `status` is the vector's `status`, and `frame_zk` the frame's total, `null` for `zk_limit`.

### Scope and order

- A block trace records only the events inside txs, from each tx's `intrinsic` to its `tx_end` (or the lone `tx_end` of a tx skipped before its intrinsic charge). The system calls before the first tx (EIP-4788 and EIP-2935) are not recorded. Every input tx appears in order from the anchor, up to the aborted tx (`truncated_at`) or the last one. `traces/metering.block.tx_gas_above_remaining.jsonl` holds a lone skipped `tx_end`.
- A harness trace runs from the top frame's first step to `frame_end`, with no `intrinsic`. A call to an account without code runs no step, so its trace is the `frame_end` alone, as in `traces/metering.harness.empty_code_target.jsonl`.
- A step that opens a frame comes first, then the precompile event or the child frame's steps, one depth deeper. A tx or harness run whose `to` is a precompile has one `precompile` event and no step.
- A tx's or harness run's first step has depth 1, and the depth rises by one only right after a step with `spawn` true.
- After a charge with `ok` false, only the `tx_end` (status `aborted`) or `frame_end` (status `zk_limit`) follows.

### Facts

Only the opcodes below record facts. Each is read before the step runs and without side effects: reading a fact must not warm an account or slot. A step whose stack holds fewer than `inputs(op)` items halts on stack underflow and records `{}`.

| Opcode                                         | `facts` keys                                                                                         |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| JUMP, JUMPI                                    | `jumpdest_valid`: whether `stack[0]` is a valid JUMPDEST                                             |
| RETURNDATACOPY                                 | `returndata_size`                                                                                    |
| SLOAD                                          | `slot_warm`                                                                                          |
| SSTORE                                         | `slot_warm`, `original`, `current`                                                                   |
| BALANCE, EXTCODESIZE, EXTCODEHASH, EXTCODECOPY | `account_warm`                                                                                       |
| CALL, CALLCODE, DELEGATECALL, STATICCALL       | `account_warm`, `account_empty`, `delegate_warm` (`null` when the target has no EIP-7702 delegation) |
| SELFDESTRUCT                                   | `account_warm`, `account_empty`, `self_balance`                                                      |

`jumpdest_valid`, `slot_warm`, `account_warm`, `account_empty` and `delegate_warm` are booleans; `returndata_size`, `original`, `current` and `self_balance` are canonical 0x hex.

### Stack inputs

`inputs(op)` is revm-bytecode 43.0.0's `OpCode::inputs()`, as in [`ZkGasModel/Tables.lean`](../../formal/zk-gas/ZkGasModel/Tables.lean) (row: high nibble, column: low nibble). Opcodes revm does not define (`–`) have no inputs.

|      | `_0` | `_1` | `_2` | `_3` | `_4` | `_5` | `_6` | `_7` | `_8` | `_9` | `_a` | `_b` | `_c` | `_d` | `_e` | `_f` |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| `0_` | 0    | 2    | 2    | 2    | 2    | 2    | 2    | 2    | 3    | 3    | 2    | 2    | –    | –    | –    | –    |
| `1_` | 2    | 2    | 2    | 2    | 2    | 1    | 2    | 2    | 2    | 1    | 2    | 2    | 2    | 2    | 1    | –    |
| `2_` | 2    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    |
| `3_` | 0    | 1    | 0    | 0    | 0    | 1    | 0    | 3    | 0    | 3    | 0    | 1    | 4    | 0    | 3    | 1    |
| `4_` | 1    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 1    | 0    | 0    | –    | –    | –    | –    |
| `5_` | 1    | 1    | 2    | 2    | 1    | 2    | 1    | 2    | 0    | 0    | 0    | 0    | 1    | 2    | 3    | 0    |
| `6_` | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    |
| `7_` | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    |
| `8_` | 1    | 2    | 3    | 4    | 5    | 6    | 7    | 8    | 9    | 10   | 11   | 12   | 13   | 14   | 15   | 16   |
| `9_` | 2    | 3    | 4    | 5    | 6    | 7    | 8    | 9    | 10   | 11   | 12   | 13   | 14   | 15   | 16   | 17   |
| `a_` | 2    | 3    | 4    | 5    | 6    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    |
| `b_` | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    |
| `c_` | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    |
| `d_` | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    | –    |
| `e_` | –    | –    | –    | –    | –    | –    | 0    | 0    | 0    | –    | –    | –    | –    | –    | –    | –    |
| `f_` | 3    | 7    | 7    | 2    | 6    | 4    | –    | –    | –    | –    | 6    | –    | –    | 2    | 0    | 1    |

### Trace checks

`check.py` checks the files: once `traces/` exists, `--require-expected` requires a trace for every vector; a trace needs a vector; each line is one event with exactly its fields in order, and its integer fields are JSON integers; and the first event is `intrinsic` (block) or `step`, `precompile` or `frame_end` (harness). `check-traces` (run by `bash scripts/gate.sh` in `formal/zk-gas`) checks everything else and reports the first failure with the vector id and the event index (lines counted from 0):

- the scope and order rules above, and every field's encoding, `stack` length and `facts` keys;
- each step's `zk`: the spawn estimate times the opcode multiplier for a spawn step, else `(gas - gas_after)` times the multiplier; each precompile's `zk`; and the intrinsic charge;
- each `ok` against the meter, and the model's block or frame metering against `tx_end`, `frame_end` and the vector's expected values: per-tx status and `tx_zk`, `included`, `truncated_at`, `cumulative_zk_gas`, `block_zk_gas`, or `frame_zk_gas` and `status`;
- where the step model covers a step, its `gas_after` (unless the step spawns) and `spawn`.

### Comparing client traces

taiko-geth exports the same trace when built with the `zkgastrace` tag and compares it with the committed trace event by event (see [Running the clients](#running-the-clients)). Every field of every event must be equal, except a step's `gas_after` when the step spawns on both sides. A difference in a step's state before it runs (`d`, `pc`, `op`, `gas`, `static`, `sl`, `stack`, `mem` or `facts`) is reported as a setup divergence. Any other difference is a zk gas mismatch: a step's `gas_after`, `spawn`, `zk`, `ok` or `charged`, any field of another event, or an event that one trace has and the other lacks. Each report names the vector id and the event index (lines counted from 0).

Two differences that cannot change zk gas are normalized, and nothing else is:

- **A skipped tx's discarded intrinsic charge**, on both traces before comparing. A skipped tx carries no zk gas, and a client may reject it either before or after charging its intrinsic zk gas, which is then discarded. So a tx whose `tx_end` is `skipped` and whose only other event is an accepted `intrinsic` charge (`ok` true) is reduced to its lone `tx_end`. A refused charge or a step inside a skipped tx is still compared.
- **The STOP step of a frame opened on empty code**, on the committed trace only. alethia-reth runs a CREATE with empty initcode through the interpreter, which executes one implicit STOP; taiko-geth runs no step for empty code. So a committed step with `op` 0 (STOP), `pc` 0, `zk` `0x0` and `gas_after` equal to `gas`, right after a step with `spawn` true one depth up, is skipped when the client trace has no step of that depth at that position. STOP has static gas 0 and multiplier 0, so such a step can never change zk gas or the limit check. The same STOP with any other `zk`, `pc` or `gas_after`, and a step the client trace has and the committed trace lacks, are still compared.

## Authoring rules

- Expected values and traces come only from alethia-reth. Never edit them by hand, and never change a vector, its expected values or its trace to make a client or the model pass.
- Cover each cell with at least one vector, including the boundaries on both sides (gas exactly enough, and one short).
- Use the block layer for the tx and block wrapping: the per-tx intrinsic charge, commit, abort and truncation. Opcode-level cells, including a step whose charge reaches the zk gas limit, use the harness layer, which runs the same interpreter and zk gas meter as block execution. Every opcode category also has a block vector that runs its main failure classes inside a real block: `<category>.block.failure_classes` for most categories, `precompile.block.direct_and_nested` for precompiles, and the `sstore` and `account` block vectors for `sload` and `selfdestruct`.
- Vector code may execute `BLOCKHASH` (and, in the harness layer, `CHAINID`), but no state write or control flow may depend on the value it returns. The runners' environments legitimately differ in the parent hash, and in the harness chain id. Those values change results, not zk gas.
- In a block vector, a `BLOCKHASH` argument must not resolve to an existing block. Block 1 can see only genesis, so the argument must not be 0; the current block number (`NUMBER`) or a future one returns 0 on every runner. Traces record each step's stack inputs, so the genesis hash, which differs between the runners by design, would appear in the step that consumes it.
- No alloc may hold the EIP-2935 history contract (`0x0000F90827F1C53a10cb7A02335B175320002935`, any letter case). It stores the parent hash, so the post-state would differ between the runners by design. `check.py` rejects it.
- No alloc account may be fully empty: balance 0, nonce 0, no code and no non-zero storage. Clients may set up such pre-state accounts differently, and they play no part in zk gas. `check.py` rejects them.
- A truncated block vector's sentinel must not depend on the dropped tx: sign it with a different, funded signer, not with the next nonce of the dropped tx's signer. Otherwise "building stopped" cannot be told apart from "skipped an invalid tx".
- No EIP-7702 delegation may point at the delegating account itself. A CALL-family step records `delegate_warm` before it runs, but revm loads the target, which warms it, before its delegate, so for a self-delegated target the fact is not the warmth revm charges, and the Lean step model would charge the step 2,500 gas more than revm. This is a limitation of the model's facts, not a client behavior.

### Not covered

- A block whose anchor alone exceeds the block zk gas limit. The anchor's gas limit is fixed at 1,000,000 and `anchorV4` runs a fixed code path (a bounded ancestor-hash loop, two hashes over a fixed buffer and at most one checkpoint write), so its zk gas stays far below the limit: sampled anchor-only blocks on Taiko mainnet and Hoodi carry 1,160,742 to 1,750,342 zk gas, under 2% of 100,000,000.
- The fail-safe multiplier of a precompile missing from the multiplier table. Every precompile active in Unzen (0x01 to 0x11 and 0x0100) has a multiplier, so no call reaches it; the opcode fail-safe multiplier is covered by the `notactivated` and `undefined` cells.

## Running the clients

All runners find the corpus through `ZK_GAS_VECTORS_DIR`, set to the absolute path of this directory. With it unset, the corpus tests skip, except that they fail in alethia-reth write mode and when `ZK_GAS_VECTORS_REQUIRED=1`. With it set, a runner that finds no vector of its layer fails.

| Variable                         | Effect                                                                                                                                                                                                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ZK_GAS_VECTORS_DIR`             | Absolute path to this directory.                                                                                                                                                                                                                                               |
| `ZK_GAS_VECTORS_REQUIRED`        | `1` makes each corpus test fail instead of skip when `ZK_GAS_VECTORS_DIR` is unset. The client CI workflows set it.                                                                                                                                                            |
| `ZK_GAS_VECTORS_WRITE`           | alethia-reth only: `1` makes the expected-value tests write `expected` into the vector files, and the trace tests write `traces/<id>.jsonl`, instead of asserting. Refused when `CI` is set: the test fails.                                                                   |
| `ZK_GAS_VECTORS_KNOWN_DIVERGENT` | taiko-geth only, for local investigation: comma-separated vector ids that are known to diverge. The block runner skips each listed vector and prints its id; the harness runner still runs it and prints the result without failing. Refused when `CI` is set: the test fails. |
| `ZK_GAS_TRACE_DUMP_DIR`          | taiko-geth only, with the `zkgastrace` tag: the trace tests also write each geth trace to `<dir>/<id>.jsonl`, for diffing against the committed trace by hand.                                                                                                                 |

Generate expected values and traces in alethia-reth, then rerun without `ZK_GAS_VECTORS_WRITE` to assert them:

```sh
export ZK_GAS_VECTORS_DIR=/path/to/taiko-mono/testdata/zk_gas_vectors
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-evm harness_vectors_match_expected
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_vectors_match_expected
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-evm harness_trace_matches_committed
ZK_GAS_VECTORS_WRITE=1 cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_trace_matches_committed
cargo test -p alethia-reth-evm harness_vectors_match_expected
cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_vectors_match_expected
cargo test -p alethia-reth-evm harness_trace_matches_committed
cargo test -p alethia-reth-payload --features alethia-reth-block/prover block_trace_matches_committed
```

The trace exporter is test-only code: it compiles for alethia-reth-evm's own tests and, through the `zk-gas-trace` feature that alethia-reth-payload's dev-dependency turns on, for the block runner. In assert mode the trace tests regenerate every trace and fail when a committed trace is missing or differs from the generated one, naming the first line that differs (lines counted from 0).

After generating, format the vector files with prettier before committing (the writer's JSON layout differs from prettier's), then check them. Trace files are not formatted: commit them exactly as written.

```sh
pnpm exec prettier --write testdata/zk_gas_vectors/cases
python3 testdata/zk_gas_vectors/check.py --require-expected
```

The harness runner checks that the plain and inspector execution paths agree. The block runner also imports the built block and checks that the prover path selects the same txs with the same zk gas.

A trace takes its charges from the plain (production) path: the harness run, or the block build. The facts of each step come from a run of the same input on the inspector path, whose inner inspector reads them before the step without side effects; for a block, the inspector run replays every tx from the same parent state. Both runs must report exactly the same charges, and each traced run must produce the same expected values as an untraced one, so reading facts cannot change what is metered.

Check taiko-geth against them:

```sh
export ZK_GAS_VECTORS_DIR=/path/to/taiko-mono/testdata/zk_gas_vectors
go test ./core/vm -run '^TestZkGasHarnessVectors$' -count=1 -v
go test ./miner -run '^TestZkGasBlockVectors$' -count=1 -v
```

Built with the `zkgastrace` tag, taiko-geth also traces every vector and compares the trace with the committed one ([Comparing client traces](#comparing-client-traces)). The trace exporter is test tooling: without the tag its hooks sit behind a false constant and compile out. `TestZkGasHarnessTraces` and `TestZkGasBlockTraces` run each vector traced (for a block vector, its block build) and require both the expected values and the trace. The untraced result comparison runs in that build too, so a fact read that changed what is metered would fail one of them.

```sh
go test -tags zkgastrace ./core/vm -run '^TestZkGasHarness(Vectors|Traces)$' -count=1 -v
go test -tags zkgastrace ./miner -run '^TestZkGasBlock(Vectors|Traces)$' -count=1 -v
```

## Continuous integration

- taiko-mono: `.github/workflows/repo--zk-gas-vectors.yml` runs `test_check.py` and `check.py --require-expected` on pull requests and pushes to `main` that change this directory or the workflow.
- alethia-reth and taiko-geth: each repository has `.github/workflows/zk-gas-vectors.yml` and a `zk-gas-vectors.ref` file at its root. The ref file holds one full 40-hex taiko-mono commit. The workflow checks out only this directory of taiko-mono at that commit, sets `ZK_GAS_VECTORS_DIR` to it and `ZK_GAS_VECTORS_REQUIRED=1`, and runs the client's corpus tests in assert mode. Each step selects one test by its exact name and fails unless that test ran and passed: `harness_vectors_match_expected`, `block_vectors_match_expected`, `harness_trace_matches_committed` and `block_trace_matches_committed` through `cargo nextest run --no-tests=fail` in alethia-reth, and `TestZkGasHarnessVectors` and `TestZkGasBlockVectors` in taiko-geth, whose workflow also runs the other `TestZkGas` tests of `core/vm` and `miner`. taiko-geth runs all of them twice: once in the default build, and once with the `zkgastrace` tag, where its steps also require `TestZkGasHarnessTraces` and `TestZkGasBlockTraces`.
- alethia-reth runs the workflow on pull requests, and on pushes to `main`, that change `crates/evm`, `crates/block`, `crates/payload`, `crates/consensus`, `crates/chainspec`, `crates/primitives`, `Cargo.toml`, `Cargo.lock`, the ref file or the workflow. taiko-geth runs it on pull requests to `taiko`, and on pushes to `taiko`, that change `core`, `miner`, `params`, `consensus`, `go.mod`, `go.sum`, the ref file or the workflow.

A corpus change reaches a client's CI only when that client's `zk-gas-vectors.ref` moves. At publish time each ref is replaced with the taiko-mono commit that merged the corpus, and after each later corpus change it is moved to the commit that merged that change.

## Coverage statistics

The matrix has 340 cells, covered by 438 vectors: 413 harness vectors and 25 block vectors. 122 cells are covered by both layers, 210 only by harness vectors and 8 only by block vectors. Update this section when the corpus changes.

| Category       | Cells | Harness and block | Harness only | Block only | Harness vectors | Block vectors |
| -------------- | ----: | ----------------: | -----------: | ---------: | --------------: | ------------: |
| `metering`     |    11 |                 2 |            3 |          6 |               9 |             5 |
| `static`       |    24 |                11 |           13 |          0 |              36 |             2 |
| `jump`         |     8 |                 5 |            3 |          0 |               8 |             1 |
| `exp`          |     5 |                 4 |            1 |          0 |               5 |             1 |
| `notactivated` |     5 |                 5 |            0 |          0 |               6 |             2 |
| `undefined`    |     2 |                 2 |            0 |          0 |               2 |             1 |
| `memory`       |    28 |                10 |           18 |          0 |              29 |             2 |
| `keccak`       |    10 |                 5 |            5 |          0 |              12 |             1 |
| `copy`         |    37 |                11 |           26 |          0 |              44 |             1 |
| `return`       |    10 |                 6 |            4 |          0 |              10 |             1 |
| `log`          |    30 |                10 |           20 |          0 |              45 |             1 |
| `sload`        |     7 |                 3 |            4 |          0 |               8 |             0 |
| `sstore`       |    17 |                 9 |            7 |          1 |              20 |             1 |
| `transient`    |     8 |                 6 |            2 |          0 |               9 |             1 |
| `account`      |    12 |                 7 |            5 |          0 |              16 |             1 |
| `selfdestruct` |    11 |                 3 |            8 |          0 |              14 |             0 |
| `call`         |    46 |                 8 |           38 |          0 |              51 |             1 |
| `precompile`   |    44 |                 6 |           38 |          0 |              44 |             1 |
| `create`       |    25 |                 9 |           15 |          1 |              44 |             1 |
| `smoke`        |     0 |                 0 |            0 |          0 |               1 |             1 |
| Total          |   340 |               122 |          210 |          8 |             413 |            25 |

Cells are grouped by the first word of their id, and vectors by the first word of the vector id (`smoke` holds the two format smoke vectors). A block vector may cover cells of several categories, so a category can have cells covered by block vectors without having a block vector of its own.

### Cells covered only by harness vectors

These cells follow the layer rule in [Authoring rules](#authoring-rules). `coverage.json` allows only the harness layer for `call.depth.deepest_frame_created`, `call.depth.limit_short_circuit_spawn_estimate`, `create.family.depth_deepest_frame_created`, `create.family.depth_limit_spawn_estimate`: reaching call depth 1024 under the 63/64 gas rule needs far more gas than a block gas limit allows. Every other cell below may also take a block vector.

- `metering` (3): `metering.failing_step.limit_exact_halt`, `metering.failing_step.limit_exceeded_aborted`, `metering.frame.empty_code_no_steps`
- `static` (13): `static.bitwise.underflow_halt`, `static.swap.underflow_halt`, `static.dup.underflow_halt`, `static.blobhash.underflow_halt`, `static.jump.underflow_halt`, `static.pop.underflow_halt`, `static.calldataload.underflow_halt`, `static.dup.overflow_halt`, `static.env.overflow_halt`, `static.env.selfbalance_static_oog_spend_all`, `static.env.selfbalance_overflow_preserve`, `static.env.blockhash_static_oog_spend_all`, `static.env.blockhash_underflow_preserve`
- `jump` (3): `jump.jump.dupn_immediate_target_success`, `jump.jumpi.taken_success`, `jump.jumpi.not_taken_success`
- `exp` (1): `exp.exp.zero_byte_exponent_success`
- `memory` (18): `memory.step.underflow_halt`, `memory.mload.end_overflow_preserve`, `memory.mload.word_rounding_overflow_preserve`, `memory.mload.size_above_cap_preserve`, `memory.mstore.offset_above_u64_preserve`, `memory.mstore.size_above_cap_preserve`, `memory.mstore8.memory_oog_preserve`, `memory.mstore8.end_overflow_preserve`, `memory.mstore8.size_above_cap_preserve`, `memory.mcopy.overlap_success`, `memory.mcopy.zero_size_no_expansion`, `memory.mcopy.memory_oog_preserve`, `memory.mcopy.dst_above_u64_preserve`, `memory.mcopy.src_above_u64_preserve`, `memory.mcopy.end_overflow_preserve`, `memory.mcopy.word_rounding_overflow_preserve`, `memory.mcopy.size_above_cap_preserve`, `memory.mcopy.copy_oog_before_memory_checks_spend_all`
- `keccak` (5): `keccak.keccak256.zero_size_no_expansion`, `keccak.keccak256.end_overflow_preserve`, `keccak.keccak256.word_rounding_overflow_preserve`, `keccak.keccak256.size_above_cap_preserve`, `keccak.keccak256.word_oog_before_memory_checks_spend_all`
- `copy` (26): `copy.calldatacopy.zero_size_no_expansion`, `copy.calldatacopy.size_above_u64_preserve`, `copy.calldatacopy.offset_above_u64_preserve`, `copy.calldatacopy.copy_oog_before_memory_checks_spend_all`, `copy.codecopy.zero_size_no_expansion`, `copy.codecopy.size_above_u64_preserve`, `copy.codecopy.copy_oog_spend_all`, `copy.codecopy.memory_oog_preserve`, `copy.codecopy.copy_oog_before_memory_checks_spend_all`, `copy.calldatacopy.shared_buffer_success`, `copy.source.offset_above_u64_success`, `copy.returndatacopy.zero_size_no_expansion`, `copy.returndatacopy.size_above_u64_preserve`, `copy.returndatacopy.memory_oog_preserve`, `copy.returndatacopy.offset_above_u64_preserve`, `copy.returndatacopy.out_of_bounds_before_charges_preserve`, `copy.returndatacopy.copy_oog_before_memory_checks_spend_all`, `copy.extcodecopy.zero_size_cold_success`, `copy.extcodecopy.size_above_u64_preserve`, `copy.extcodecopy.copy_oog_spend_all`, `copy.extcodecopy.memory_oog_preserve`, `copy.extcodecopy.offset_above_u64_preserve`, `copy.extcodecopy.end_overflow_preserve`, `copy.extcodecopy.size_above_cap_preserve`, `copy.extcodecopy.failed_copy_leaves_account_cold`, `copy.extcodecopy.copy_oog_before_memory_checks_spend_all`
- `return` (4): `return.return.zero_size_success`, `return.return.offset_above_u64_halt`, `return.revert.zero_size_revert`, `return.revert.size_above_u64_halt`
- `log` (20): `log.logn.zero_size_success`, `log.logn.static_oog_spend_all`, `log.logn.stack_underflow_preserve`, `log.logn.topic_oog_spend_all`, `log.logn.offset_above_u64_preserve`, `log.logn.end_overflow_preserve`, `log.logn.word_rounding_overflow_preserve`, `log.logn.size_above_cap_preserve`, `log.logn.data_oog_before_memory_checks_spend_all`, `log.topics.zero_size_underflow_preserve`, `log.topics.static_oog_before_underflow_spend_all`, `log.topics.size_above_u64_before_underflow_preserve`, `log.topics.data_oog_before_underflow_spend_all`, `log.topics.memory_oog_before_underflow_preserve`, `log.topics.memory_range_halt_before_underflow_preserve`, `log.static_frame.dynamic_oog_halt_preserve`, `log.static_frame.static_oog_spend_all`, `log.static_frame.stack_underflow_preserve`, `log.static_frame.size_above_u64_preserve`, `log.static_frame.size_above_cap_preserve`
- `sload` (4): `sload.sload.static_oog_spend_all`, `sload.sload.underflow_preserve`, `sload.sload.failed_cold_load_leaves_slot_cold`, `sload.sload.child_cold_load_warms_slot`
- `sstore` (7): `sstore.noop.warm_success`, `sstore.fresh.warm_success`, `sstore.modify.warm_success`, `sstore.clear.warm_success`, `sstore.sentry.min_gas_passes`, `sstore.sstore.underflow_preserve`, `sstore.dynamic.failed_store_leaves_slot_cold`
- `transient` (2): `transient.tload.underflow_preserve`, `transient.tstore.static_oog_spend_all`
- `account` (5): `account.extcodesize.warm_success`, `account.extcodesize.cold_surcharge_oog_spend_all`, `account.extcodehash.cold_surcharge_oog_spend_all`, `account.access.static_oog_spend_all`, `account.access.failed_cold_load_leaves_account_cold`
- `selfdestruct` (8): `selfdestruct.selfdestruct.warm_success`, `selfdestruct.selfdestruct.cold_success`, `selfdestruct.new_account.warm_success`, `selfdestruct.selfdestruct.static_oog_spend_all`, `selfdestruct.selfdestruct.cold_load_skipped_spend_all`, `selfdestruct.selfdestruct.underflow_preserve`, `selfdestruct.selfdestruct.child_success_warms_beneficiary`, `selfdestruct.selfdestruct.failed_step_leaves_beneficiary_cold`
- `call` (38): `call.callcode.new_frame_spawn_estimate`, `call.delegatecall.new_frame_spawn_estimate`, `call.staticcall.new_frame_spawn_estimate`, `call.family.warm_target_spawn`, `call.family.static_oog_spend_all`, `call.family.cold_target_spawn`, `call.family.underflow_preserve`, `call.family.delegated_to_precompile_empty_code`, `call.family.warm_target_warm_delegate_spawn`, `call.family.warm_target_cold_delegate_spawn`, `call.family.cold_target_cold_delegate_spawn`, `call.value.warm_target_warm_delegate_spawn`, `call.value.warm_target_cold_delegate_spawn`, `call.value.cold_target_warm_delegate_spawn`, `call.value.cold_target_cold_delegate_spawn`, `call.family.delegate_read_oog_spend_all`, `call.family.delegate_cold_surcharge_oog_spend_all`, `call.family.spawn_limit_exact_committed`, `call.family.spawn_limit_exceeded_aborted`, `call.family.input_expansion_spawn`, `call.family.input_memory_oog_preserve`, `call.family.output_expansion_spawn`, `call.family.input_size_above_u64_preserve`, `call.family.input_offset_above_u64_preserve`, `call.family.output_size_above_u64_keeps_input_charge`, `call.family.output_offset_above_u64_keeps_input_charge`, `call.family.output_end_above_u64_keeps_input_charge`, `call.family.output_word_rounding_overflow_keeps_input_charge`, `call.family.output_size_above_cap_keeps_input_charge`, `call.family.zero_size_no_expansion`, `call.call.static_frame_zero_value_allowed`, `call.callcode.static_frame_value_allowed`, `call.value.transfer_success`, `call.value.transfer_oog_spend_all`, `call.call.new_account_oog_spend_all`, `call.callcode.value_no_new_account_charge`, `call.depth.deepest_frame_created`, `call.depth.limit_short_circuit_spawn_estimate`
- `precompile` (38): `precompile.ecrecover.failure_all_supplied`, `precompile.sha256.success_gas_used`, `precompile.sha256.failure_all_supplied`, `precompile.ripemd160.success_gas_used`, `precompile.ripemd160.failure_all_supplied`, `precompile.identity.success_gas_used`, `precompile.identity.failure_all_supplied`, `precompile.modexp.success_gas_used`, `precompile.modexp.failure_all_supplied`, `precompile.bn254_add.failure_all_supplied`, `precompile.bn254_mul.success_gas_used`, `precompile.bn254_mul.failure_all_supplied`, `precompile.bn254_pairing.success_gas_used`, `precompile.bn254_pairing.failure_all_supplied`, `precompile.blake2f.success_gas_used`, `precompile.blake2f.failure_all_supplied`, `precompile.point_evaluation.success_gas_used`, `precompile.point_evaluation.failure_all_supplied`, `precompile.bls12_g1add.success_gas_used`, `precompile.bls12_g1add.failure_all_supplied`, `precompile.bls12_g1msm.success_gas_used`, `precompile.bls12_g1msm.failure_all_supplied`, `precompile.bls12_g2add.success_gas_used`, `precompile.bls12_g2add.failure_all_supplied`, `precompile.bls12_g2msm.success_gas_used`, `precompile.bls12_g2msm.failure_all_supplied`, `precompile.bls12_pairing.success_gas_used`, `precompile.bls12_pairing.failure_all_supplied`, `precompile.bls12_map_fp_to_g1.success_gas_used`, `precompile.bls12_map_fp_to_g1.failure_all_supplied`, `precompile.bls12_map_fp2_to_g2.success_gas_used`, `precompile.bls12_map_fp2_to_g2.failure_all_supplied`, `precompile.p256verify.success_gas_used`, `precompile.p256verify.failure_all_supplied`, `precompile.ecrecover.invalid_signature_gas_used`, `precompile.p256verify.invalid_signature_gas_used`, `precompile.charge.limit_exact_committed`, `precompile.charge.limit_exceeded_aborted`
- `create` (15): `create.family.initcode_at_limit_spawn`, `create.family.initcode_word_cost_oog_spend_all`, `create.family.memory_oog_preserve_after_initcode`, `create.family.zero_size_no_initcode_charges`, `create.create2.hash_oog_spend_all`, `create.family.offset_above_u64_preserve_after_initcode`, `create.family.size_above_u64_preserve`, `create.family.underflow_preserve`, `create.family.spawn_limit_exact_committed`, `create.family.spawn_limit_exceeded_aborted`, `create.family.depth_deepest_frame_created`, `create.family.depth_limit_spawn_estimate`, `create.family.initcode_revert_gas_returned`, `create.family.initcode_halt_gas_consumed`, `create.family.code_deposit_in_frame_return`
