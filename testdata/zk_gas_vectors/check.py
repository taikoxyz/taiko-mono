#!/usr/bin/env python3
"""Checks the zk gas vector corpus: file format, the fixed block environment, coverage and traces.

Usage: python3 testdata/zk_gas_vectors/check.py [--require-expected]

See README.md in this directory for the format. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

LAYERS = ("block", "harness")
NAME = re.compile(r"[a-z0-9_]+(?:\.[a-z0-9_]+)*")
CANONICAL_INT = re.compile(r"0x(?:0|[1-9a-f][0-9a-f]*)")
HEX_BYTES = re.compile(r"0x(?:[0-9a-fA-F]{2})*")
FULL_SHA = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")

U64_MAX = 2**64 - 1
U128_MAX = 2**128 - 1
U256_MAX = 2**256 - 1

# Fixed block-layer environment: chain 167001 with Shasta and Unzen active from genesis,
# parent = genesis (timestamp 0), block number 1.
CHAIN_ID = 167001
BLOCK_NUMBER = 1
BASE_FEE = 25_000_000
EXTRA_DATA_LEN = 7
BLOCK_ZK_GAS_LIMIT = 100_000_000

# The anchor tx at index 0. The anchor address holds a STOP stub in alloc.
GOLDEN_TOUCH = "golden_touch"
ANCHOR_TO = "0x1670010000000000000000000000000000010001"
ANCHOR_FIELDS = (
    ("signer", GOLDEN_TOUCH),
    ("nonce", "0x0"),
    ("gas", hex(1_000_000)),
    ("max_fee", hex(BASE_FEE)),
    ("max_priority_fee", "0x0"),
    ("value", "0x0"),
)
ANCHOR_DATA = "0x523e6854"  # anchorV4((uint48,bytes32,bytes32)) selector, no arguments
ANCHOR_STUB_CODE = "0x00"

# The EIP-2935 history contract stores the parent hash, which differs between the runners by design.
HISTORY_CONTRACT = "0x0000f90827f1c53a10cb7a02335b175320002935"

SIGNER_MAX = 2**32 - 1
TX_FIELDS = ("signer", "nonce", "to", "gas", "max_fee", "max_priority_fee", "value", "data")
TX_FORBIDDEN = ("type", "access_list", "blob_versioned_hashes")
ENV_FIELDS = ("chain_id", "number", "timestamp", "base_fee", "coinbase", "gas_limit", "prev_randao", "extra_data")
BLOCK_EXPECTED_FIELDS = (
    "raw_txs",
    "included",
    "truncated_at",
    "cumulative_zk_gas",
    "block_zk_gas",
    "state_root",
    "import_built",
    "import_extended",
    "import_wrong_difficulty",
)

HARNESS_INPUT_FIELDS = ("alloc", "caller", "to", "frame_gas", "zk_block_limit", "number", "timestamp", "coinbase")
# The harness tx gas limit is frame_gas plus the 21,000 base cost of an empty-calldata call.
HARNESS_FRAME_GAS_MAX = U64_MAX - 21_000
HARNESS_STATUSES = ("success", "revert", "halt", "zk_limit")

# Trace schema v1: the fields of each event, in the order they are written. The Lean checker
# (formal/zk-gas, `lake exe check-traces`) checks the values and the event order.
TRACE_FIELDS = {
    "intrinsic": ("e", "zk", "ok"),
    "step": ("e", "d", "pc", "op", "gas", "static", "sl", "stack", "mem", "facts", "gas_after", "spawn", "zk",
             "ok", "charged"),
    "precompile": ("e", "addr", "supplied", "left", "success", "zk", "ok"),
    "tx_end": ("e", "index", "status", "tx_zk"),
    "frame_end": ("e", "status", "frame_zk"),
}
# Trace fields that are JSON integers; every other quantity is canonical 0x hex.
TRACE_INTEGERS = ("d", "pc", "op", "sl", "index")
# A block trace starts with a tx's intrinsic charge; a harness trace with the top frame's first
# step, or with the precompile run when the harness calls a precompile directly.
TRACE_FIRST = {"block": ("intrinsic",), "harness": ("step", "precompile")}


def check_fields(errors, where, obj, required, optional=()):
    """Records unknown and missing fields; returns True for an object with every required field."""
    if not isinstance(obj, dict):
        errors.append(f"{where}: must be an object")
        return False
    for key in obj:
        if key not in required and key not in optional:
            errors.append(f"{where}: unknown field {key!r}")
    missing = [key for key in required if key not in obj]
    for key in missing:
        errors.append(f"{where}: missing field {key!r}")
    return not missing


def check_int(errors, where, value, maximum=U64_MAX):
    """Returns the value of a canonical 0x-hex integer, or None after recording an error."""
    if not isinstance(value, str) or not CANONICAL_INT.fullmatch(value):
        errors.append(f"{where}: {value!r} is not canonical 0x hex (lowercase, no leading zeros, zero is 0x0)")
        return None
    number = int(value, 16)
    if number > maximum:
        errors.append(f"{where}: {value} exceeds {hex(maximum)}")
        return None
    return number


def check_bytes(errors, where, value, length=None):
    """Returns the lowercased value of an even-length 0x-hex byte string, or None after recording an error."""
    if not isinstance(value, str) or not HEX_BYTES.fullmatch(value):
        errors.append(f"{where}: {value!r} is not even-length 0x hex")
        return None
    size = (len(value) - 2) // 2
    if length is not None and size != length:
        errors.append(f"{where}: must be {length} bytes, got {size}")
        return None
    return value.lower()


def check_address(errors, where, value):
    return check_bytes(errors, where, value, 20)


def check_text(errors, where, value):
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{where}: must be a non-empty string")


def is_index(value):
    return type(value) is int  # bool is an int subclass but not a valid index


def check_schema_version(errors, where, value):
    if not is_index(value) or value != 1:
        errors.append(f"{where}: must be 1")


def check_alloc(errors, where, alloc):
    """Returns the accounts keyed by lowercased address."""
    accounts = {}
    if not isinstance(alloc, dict):
        errors.append(f"{where}: must be an object")
        return accounts
    for address, account in alloc.items():
        at = f"{where}.{address}"
        lower = check_address(errors, at, address)
        if lower is None:
            continue
        if lower in accounts:
            errors.append(f"{at}: duplicate address (addresses are case-insensitive)")
            continue
        accounts[lower] = account
        if lower == HISTORY_CONTRACT:
            errors.append(
                f"{at}: the EIP-2935 history contract must not be in alloc "
                "(it stores the parent hash, which differs between the runners by design)"
            )
        if not check_fields(errors, at, account, ("balance",), ("nonce", "code", "storage")):
            continue
        balance = check_int(errors, f"{at}.balance", account["balance"], U256_MAX)
        nonce = check_int(errors, f"{at}.nonce", account["nonce"]) if "nonce" in account else 0
        code = check_bytes(errors, f"{at}.code", account["code"]) if "code" in account else "0x"
        storage = account.get("storage", {})
        if not isinstance(storage, dict):
            errors.append(f"{at}.storage: must be an object")
            continue
        values = []
        for slot, value in storage.items():
            check_int(errors, f"{at}.storage key {slot!r}", slot, U256_MAX)
            values.append(check_int(errors, f"{at}.storage.{slot}", value, U256_MAX))
        if balance == 0 and nonce == 0 and code == "0x" and all(value == 0 for value in values):
            errors.append(
                f"{at}: fully empty account (balance 0, nonce 0, no code, no non-zero storage) is not allowed "
                "(clients may set up empty pre-state accounts differently)"
            )
    return accounts


def check_tx(errors, where, index, tx):
    if not isinstance(tx, dict):
        errors.append(f"{where}: must be an object")
        return
    for key in TX_FORBIDDEN:
        if key in tx:
            errors.append(
                f"{where}: field {key!r} is not allowed: every tx is EIP-1559 (type 2) without access list or blobs"
            )
    fields = {key: value for key, value in tx.items() if key not in TX_FORBIDDEN}
    if not check_fields(errors, where, fields, TX_FIELDS):
        return
    signer = tx["signer"]
    if signer == GOLDEN_TOUCH:
        if index != 0:
            errors.append(f"{where}.signer: golden_touch may only sign the anchor at index 0")
    elif not is_index(signer) or not 1 <= signer <= SIGNER_MAX:
        errors.append(f'{where}.signer: {signer!r} must be "golden_touch" or a JSON integer k with 1 <= k < 2^32')
    check_int(errors, f"{where}.nonce", tx["nonce"])
    if tx["to"] is not None:
        check_address(errors, f"{where}.to", tx["to"])
    check_int(errors, f"{where}.gas", tx["gas"])
    check_int(errors, f"{where}.max_fee", tx["max_fee"], U128_MAX)
    check_int(errors, f"{where}.max_priority_fee", tx["max_priority_fee"], U128_MAX)
    check_int(errors, f"{where}.value", tx["value"], U256_MAX)
    check_bytes(errors, f"{where}.data", tx["data"])


def check_anchor(errors, where, tx):
    if not isinstance(tx, dict):
        return
    for field, want in ANCHOR_FIELDS:
        if field in tx and tx[field] != want:
            errors.append(f"{where}.{field}: anchor {field} must be {want!r}")
    if "to" in tx and (not isinstance(tx["to"], str) or tx["to"].lower() != ANCHOR_TO):
        errors.append(f"{where}.to: anchor to must be {ANCHOR_TO}")
    if "data" in tx and (not isinstance(tx["data"], str) or tx["data"].lower() != ANCHOR_DATA):
        errors.append(f"{where}.data: anchor data must be exactly the anchorV4 selector {ANCHOR_DATA}")


def check_block_env(errors, where, env):
    if not check_fields(errors, where, env, ENV_FIELDS):
        return
    for field, want in (("chain_id", CHAIN_ID), ("number", BLOCK_NUMBER), ("base_fee", BASE_FEE)):
        value = check_int(errors, f"{where}.{field}", env[field])
        if value is not None and value != want:
            errors.append(f"{where}.{field}: must be {hex(want)} (fixed block environment)")
    if check_int(errors, f"{where}.timestamp", env["timestamp"]) == 0:
        errors.append(f"{where}.timestamp: must be after the genesis parent's timestamp 0")
    check_int(errors, f"{where}.gas_limit", env["gas_limit"])
    check_address(errors, f"{where}.coinbase", env["coinbase"])
    check_bytes(errors, f"{where}.prev_randao", env["prev_randao"], 32)
    check_bytes(errors, f"{where}.extra_data", env["extra_data"], EXTRA_DATA_LEN)


def check_block_input(errors, rel, data):
    """Returns the number of input txs, or None when txs is not a list."""
    where = f"{rel}: input"
    if not check_fields(errors, where, data, ("env", "alloc", "txs")):
        return None
    check_block_env(errors, f"{where}.env", data["env"])
    accounts = check_alloc(errors, f"{where}.alloc", data["alloc"])
    stub = accounts.get(ANCHOR_TO)
    code = stub.get("code") if isinstance(stub, dict) else None
    if not isinstance(code, str) or code.lower() != ANCHOR_STUB_CODE:
        errors.append(f"{where}.alloc: {ANCHOR_TO} must hold the anchor's STOP stub (code {ANCHOR_STUB_CODE})")
    txs = data["txs"]
    if not isinstance(txs, list) or not txs:
        errors.append(f"{where}.txs: must be a non-empty list starting with the anchor")
        return None
    for index, tx in enumerate(txs):
        check_tx(errors, f"{where}.txs[{index}]", index, tx)
    check_anchor(errors, f"{where}.txs[0]", txs[0])
    return len(txs)


def check_block_expected(errors, rel, expected, tx_count):
    where = f"{rel}: expected"
    if not check_fields(errors, where, expected, BLOCK_EXPECTED_FIELDS):
        return

    raw_txs = expected["raw_txs"]
    if not isinstance(raw_txs, list):
        errors.append(f"{where}.raw_txs: must be a list")
    else:
        if tx_count is not None and len(raw_txs) != tx_count:
            errors.append(f"{where}.raw_txs: has {len(raw_txs)} entries, want one per input tx ({tx_count})")
        for index, raw in enumerate(raw_txs):
            raw = check_bytes(errors, f"{where}.raw_txs[{index}]", raw)
            if raw is not None and not raw.startswith("0x02"):
                errors.append(f"{where}.raw_txs[{index}]: must be a type-2 (EIP-1559) envelope")

    included = expected["included"]
    if not isinstance(included, list) or not included or not all(is_index(i) for i in included):
        errors.append(f"{where}.included: must be a non-empty list of JSON integers")
        included = None
    else:
        if included[0] != 0:
            errors.append(f"{where}.included: must start with 0 (the anchor)")
        if any(b <= a for a, b in zip(included, included[1:])):
            errors.append(f"{where}.included: must be strictly increasing")
        if tx_count is not None and max(included) >= tx_count:
            errors.append(f"{where}.included: index out of range for {tx_count} input txs")

    truncated_at = expected["truncated_at"]
    if truncated_at is not None:
        if not is_index(truncated_at):
            errors.append(f"{where}.truncated_at: must be null or a JSON integer")
        else:
            if included is not None and truncated_at <= max(included):
                errors.append(f"{where}.truncated_at: must be greater than every included index")
            if tx_count is not None and truncated_at >= tx_count - 1:
                errors.append(
                    f"{where}.truncated_at: at least one input tx must follow the truncation point (sentinel)"
                )

    cumulative = expected["cumulative_zk_gas"]
    totals = None
    if not isinstance(cumulative, list):
        errors.append(f"{where}.cumulative_zk_gas: must be a list")
    else:
        totals = [check_int(errors, f"{where}.cumulative_zk_gas[{i}]", v) for i, v in enumerate(cumulative)]
        if None in totals:
            totals = None
        else:
            if included is not None and len(totals) != len(included):
                errors.append(f"{where}.cumulative_zk_gas: must have one entry per included tx ({len(included)})")
            if any(b <= a for a, b in zip(totals, totals[1:])):
                errors.append(f"{where}.cumulative_zk_gas: must be strictly increasing")
            if totals and totals[-1] > BLOCK_ZK_GAS_LIMIT:
                errors.append(f"{where}.cumulative_zk_gas: exceeds the block zk gas limit {hex(BLOCK_ZK_GAS_LIMIT)}")

    block_zk_gas = check_int(errors, f"{where}.block_zk_gas", expected["block_zk_gas"])
    if block_zk_gas is not None and totals and block_zk_gas != totals[-1]:
        errors.append(f"{where}.block_zk_gas: must equal the last cumulative_zk_gas entry")

    check_bytes(errors, f"{where}.state_root", expected["state_root"], 32)
    if expected["import_built"] != "accept":
        errors.append(f'{where}.import_built: must be "accept"')
    want_extended = "reject" if truncated_at is not None else None
    if expected["import_extended"] != want_extended:
        errors.append(
            f"{where}.import_extended: must be {json.dumps(want_extended)} "
            f"when truncated_at is {json.dumps(truncated_at)}"
        )
    if expected["import_wrong_difficulty"] != "reject":
        errors.append(f'{where}.import_wrong_difficulty: must be "reject"')


def check_harness_input(errors, rel, data):
    where = f"{rel}: input"
    if not check_fields(errors, where, data, HARNESS_INPUT_FIELDS):
        return
    check_alloc(errors, f"{where}.alloc", data["alloc"])
    for field in ("caller", "to", "coinbase"):
        check_address(errors, f"{where}.{field}", data[field])
    check_int(errors, f"{where}.frame_gas", data["frame_gas"], HARNESS_FRAME_GAS_MAX)
    for field in ("zk_block_limit", "number", "timestamp"):
        check_int(errors, f"{where}.{field}", data[field])


def check_harness_expected(errors, rel, expected):
    where = f"{rel}: expected"
    if not check_fields(errors, where, expected, ("frame_zk_gas", "status")):
        return
    status = expected["status"]
    if status not in HARNESS_STATUSES:
        errors.append(f"{where}.status: {status!r} must be one of {', '.join(HARNESS_STATUSES)}")
    frame_zk_gas = expected["frame_zk_gas"]
    if status == "zk_limit":
        if frame_zk_gas is not None:
            errors.append(f"{where}.frame_zk_gas: must be null when status is zk_limit")
    elif frame_zk_gas is None:
        errors.append(f"{where}.frame_zk_gas: may be null only when status is zk_limit")
    else:
        check_int(errors, f"{where}.frame_zk_gas", frame_zk_gas, U256_MAX)


def check_vector(errors, rel, stem, vector, cells, covered, require_expected):
    if not check_fields(errors, rel, vector, ("schema_version", "id", "layer", "cells", "description", "input"),
                        ("expected",)):
        return
    check_schema_version(errors, f"{rel}: schema_version", vector["schema_version"])
    vector_id = vector["id"]
    if vector_id != stem:
        errors.append(f"{rel}: id: {vector_id!r} does not match the file name ({stem!r})")
    elif not NAME.fullmatch(stem):
        errors.append(f"{rel}: id: must be dot-separated [a-z0-9_] words")

    layer = vector["layer"]
    if layer not in LAYERS:
        errors.append(f"{rel}: layer: {layer!r} must be one of {', '.join(LAYERS)}")
        return

    refs = vector["cells"]
    if (not isinstance(refs, list) or not refs or not all(isinstance(r, str) for r in refs)
            or len(set(refs)) != len(refs)):
        errors.append(f"{rel}: cells: must be a non-empty list of distinct coverage cell ids")
    else:
        for cell_id in refs:
            if cell_id not in cells:
                errors.append(f"{rel}: cells: unknown cell {cell_id!r}")
                continue
            covered.add(cell_id)
            if layer not in cells[cell_id]:
                errors.append(f"{rel}: cells: layer {layer!r} is not allowed for cell {cell_id!r} "
                              f"(allowed: {', '.join(cells[cell_id]) or 'none'})")
    check_text(errors, f"{rel}: description", vector["description"])

    if layer == "block":
        tx_count = check_block_input(errors, rel, vector["input"])
        if "expected" in vector:
            check_block_expected(errors, rel, vector["expected"], tx_count)
    else:
        check_harness_input(errors, rel, vector["input"])
        if "expected" in vector:
            check_harness_expected(errors, rel, vector["expected"])
    if require_expected and "expected" not in vector:
        errors.append(f"{rel}: missing expected (generate it with the alethia-reth runner's write mode)")


def check_reference(errors, reference):
    """Returns the revm-interpreter version, or None when it is invalid."""
    where = "reference.json"
    if not check_fields(errors, where, reference, ("alethia_reth", "taiko_geth_checked")):
        return None
    interpreter = None
    reth = reference["alethia_reth"]
    if check_fields(errors, f"{where}: alethia_reth", reth, ("commit", "revm", "revm_interpreter")):
        if not isinstance(reth["commit"], str) or not FULL_SHA.fullmatch(reth["commit"]):
            errors.append(f"{where}: alethia_reth.commit: must be a full 40-hex lowercase commit SHA")
        for field in ("revm", "revm_interpreter"):
            if not isinstance(reth[field], str) or not VERSION.fullmatch(reth[field]):
                errors.append(f"{where}: alethia_reth.{field}: must be a crate version such as 43.0.1")
            elif field == "revm_interpreter":
                interpreter = reth[field]
    checked = reference["taiko_geth_checked"]
    if not isinstance(checked, str) or not FULL_SHA.fullmatch(checked):
        errors.append(f"{where}: taiko_geth_checked: must be a full 40-hex lowercase commit SHA")
    return interpreter


def check_coverage(errors, coverage, interpreter):
    """Returns the allowed layers of each cell, keyed by cell id."""
    where = "coverage.json"
    cells = {}
    if not check_fields(errors, where, coverage, ("schema_version", "reference", "cells")):
        return cells
    check_schema_version(errors, f"{where}: schema_version", coverage["schema_version"])
    if interpreter is not None and coverage["reference"] != f"revm-interpreter {interpreter}":
        errors.append(f"{where}: reference: must be 'revm-interpreter {interpreter}' to match reference.json")
    if not isinstance(coverage["cells"], list):
        errors.append(f"{where}: cells: must be a list")
        return cells
    for index, cell in enumerate(coverage["cells"]):
        at = f"{where}: cells[{index}]"
        if not check_fields(errors, at, cell, ("id", "layers", "source", "description")):
            continue
        cell_id = cell["id"]
        if not isinstance(cell_id, str) or not NAME.fullmatch(cell_id):
            errors.append(f"{at}.id: {cell_id!r} must be dot-separated [a-z0-9_] words")
            continue
        if cell_id in cells:
            errors.append(f"{at}.id: duplicate cell id {cell_id!r}")
            continue
        layers = cell["layers"]
        if (not isinstance(layers, list) or not layers or not all(layer in LAYERS for layer in layers)
                or len(set(layers)) != len(layers)):
            errors.append(f"{at}.layers: must be a non-empty list of distinct layers from {', '.join(LAYERS)}")
            layers = []
        check_text(errors, f"{at}.source", cell["source"])
        check_text(errors, f"{at}.description", cell["description"])
        cells[cell_id] = layers
    return cells


def _reject_duplicate_keys(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError(f"duplicate key {key!r}")
        obj[key] = value
    return obj


def _reject_constant(name):
    raise ValueError(f"{name} is not valid JSON")


def load_object(errors, root, rel):
    """Returns the JSON object in root/rel, or None after recording an error."""
    try:
        data = json.loads(
            (root / rel).read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (OSError, ValueError) as error:
        errors.append(f"{rel}: cannot load: {error}")
        return None
    if not isinstance(data, dict):
        errors.append(f"{rel}: must contain a JSON object")
        return None
    return data


def check_trace(errors, root, rel, layer):
    """Checks that each line of the trace file root/rel is one schema event with its fields in order
    and its integer fields as JSON integers, and that the first event fits the layer."""
    try:
        text = (root / rel).read_text(encoding="utf-8")
    except (OSError, ValueError) as error:
        errors.append(f"{rel}: cannot read: {error}")
        return
    if not text:
        errors.append(f"{rel}: empty trace")
        return
    if not text.endswith("\n"):
        errors.append(f"{rel}: must end with a newline")
    lines = text.split("\n")
    if lines[-1] == "":
        lines.pop()
    for number, line in enumerate(lines, 1):
        where = f"{rel}: line {number}"
        if not line:
            errors.append(f"{where}: empty line")
            continue
        try:
            event = json.loads(line, object_pairs_hook=_reject_duplicate_keys, parse_constant=_reject_constant)
        except ValueError as error:
            errors.append(f"{where}: cannot parse: {error}")
            continue
        if not isinstance(event, dict):
            errors.append(f"{where}: must be a JSON object")
            continue
        kind = event.get("e")
        fields = TRACE_FIELDS.get(kind) if isinstance(kind, str) else None
        if fields is None:
            errors.append(f"{where}: unknown event {kind!r} (events: {', '.join(TRACE_FIELDS)})")
            continue
        if tuple(event) != fields:
            errors.append(f"{where}: fields must be {', '.join(fields)} in this order, got {', '.join(event)}")
        for key in TRACE_INTEGERS:
            if key in event and not is_index(event[key]):
                errors.append(f"{where}: {key} must be a JSON integer, got {json.dumps(event[key])}")
        if number == 1 and layer in TRACE_FIRST and kind not in TRACE_FIRST[layer]:
            errors.append(f"{where}: first event must be {' or '.join(TRACE_FIRST[layer])} ({layer} layer), got {kind}")


def check_traces(errors, root, layers, require_expected):
    """Checks traces/: one <id>.jsonl per vector once the directory exists (required with
    require_expected), and none without a vector. layers maps each vector id to its layer, or
    None when the vector is invalid."""
    traces = root / "traces"
    if not traces.is_dir():
        return
    for path in sorted(traces.iterdir()):
        if path.name.startswith("."):
            continue
        rel = f"traces/{path.name}"
        if path.suffix != ".jsonl" or not path.is_file():
            errors.append(f"{rel}: not a trace file (traces/ holds only <id>.jsonl files)")
        elif path.stem not in layers:
            errors.append(f"{rel}: no vector cases/{path.stem}.json")
        else:
            check_trace(errors, root, rel, layers[path.stem])
    if require_expected:
        for vector_id in layers:
            if not (traces / f"{vector_id}.jsonl").is_file():
                errors.append(
                    f"cases/{vector_id}.json: missing trace traces/{vector_id}.jsonl "
                    "(generate it with the alethia-reth runner's write mode)"
                )


def check(root: Path, require_expected: bool) -> list[str]:
    """Returns every format and coverage error in the corpus at root; an empty list means it passes."""
    root = Path(root)
    errors = []
    reference = load_object(errors, root, "reference.json")
    interpreter = check_reference(errors, reference) if reference is not None else None
    coverage = load_object(errors, root, "coverage.json")
    cells = check_coverage(errors, coverage, interpreter) if coverage is not None else {}

    covered = set()
    cases = root / "cases"
    vectors = 0
    layers = {}
    for path in sorted(cases.iterdir()) if cases.is_dir() else []:
        if path.name.startswith("."):
            continue
        rel = f"cases/{path.name}"
        if path.suffix != ".json" or not path.is_file():
            errors.append(f"{rel}: not a vector file (cases/ holds only <id>.json files)")
            continue
        vectors += 1
        vector = load_object(errors, root, rel)
        layers[path.stem] = None
        if vector is not None:
            check_vector(errors, rel, path.stem, vector, cells, covered, require_expected)
            layers[path.stem] = vector.get("layer")
    if vectors == 0:
        errors.append("cases: no vectors")
    check_traces(errors, root, layers, require_expected)
    for cell_id in cells:
        if cell_id not in covered:
            errors.append(f"coverage.json: cell {cell_id!r} has no vector")
    return errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Check the zk gas vector corpus.")
    parser.add_argument(
        "--require-expected",
        action="store_true",
        help="also require every vector to carry generated expected values, and a trace once traces/ exists",
    )
    args = parser.parse_args(argv)
    errors = check(ROOT, args.require_expected)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print(f"{len(errors)} error(s)", file=sys.stderr)
        return 1
    print("zk gas vectors: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
