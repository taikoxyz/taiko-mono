#!/usr/bin/env python3
"""Build an alloc-only Etna genesis from canonical devnet JSON and exported vault runtime.

Only alloc changes. This does not activate Taiko forks: the pinned EL rejects the Etna override
for altered genesis hashes. Execution-client support and real block-0 acceptance are prerequisites
for starting this genesis, tracked separately from the exporter.
"""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

ROOTS = "0x000f3df6d732807ef1319fb7b8bb8522d0beac02"
HISTORY = "0x0000f90827f1c53a10cb7a02335b175320002935"
# Canonical runtimes copied from taikoxyz/alethia-reth at
# 1e25b4849259320fca1123de362bc38b0b090ece:crates/node/tests/fixtures/etna-genesis.json.
ROOTS_RUNTIME = "0x3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500"
HISTORY_RUNTIME = "0x3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500"
ROOTS_SHA256 = "cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d"


def address(value):
    """Normalize one 20-byte alloc address without accepting truncation or padding."""
    value = value.lower().removeprefix("0x")
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("alloc and Inbox addresses must contain exactly 20 hex bytes")
    return "0x" + value


def bytecode(value):
    """Require concrete nonempty bytecode, rejecting unresolved immutable placeholders."""
    if not isinstance(value, str) or not re.fullmatch(r"0x(?:[0-9a-fA-F]{2})+", value):
        raise ValueError("runtime must be nonempty 0x-prefixed concrete bytecode")
    return value.lower()


def build(base, runtime):
    """Copy the base genesis and replace only alloc with normalized predeploy entries."""
    roots = bytecode(ROOTS_RUNTIME)
    if hashlib.sha256(bytes.fromhex(roots[2:])).hexdigest() != ROOTS_SHA256:
        raise ValueError("canonical EIP-4788 runtime hash mismatch")
    if int(runtime["l1ChainId"]) <= 0 or int(address(runtime["l1Inbox"]), 16) == 0:
        raise ValueError("exported L1 chain and Inbox must be nonzero")
    code = bytecode(runtime["runtime"])
    chain_id = int(base["config"]["chainId"])
    prefix = str(chain_id)
    if chain_id <= 0 or len(prefix) > 35:
        raise ValueError("L2 chainId cannot form an EL treasury address")
    vault = "0x" + prefix + "0" * (40 - len(prefix) - 5) + "10001"
    genesis = copy.deepcopy(base)
    alloc = {}
    for key, account in genesis.get("alloc", {}).items():
        normalized = address(key)
        if normalized in alloc:
            raise ValueError("duplicate alloc address after normalization: " + normalized)
        alloc[normalized] = account
    for target, deployed in ((vault, code), (ROOTS, roots), (HISTORY, bytecode(HISTORY_RUNTIME))):
        alloc[target] = {"balance": "0x0", "nonce": "0x1", "code": deployed}
    genesis["alloc"] = alloc
    return genesis


def write(genesis, output):
    """Write deterministic, sorted JSON with one terminating newline."""
    Path(output).write_text(json.dumps(genesis, sort_keys=True, indent=2) + "\n")


def _unique_object(pairs):
    """Reject duplicate literal keys before JSON decoding can discard earlier values."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key: " + repr(key))
        result[key] = value
    return result


def load(path):
    """Load base or runtime JSON, requiring unique keys in every nested object."""
    return json.loads(Path(path).read_text(), object_pairs_hook=_unique_object)


def main():
    """Read explicit input paths and emit the alloc-only genesis."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True, help="canonical devnet genesis JSON")
    parser.add_argument("--runtime", type=Path, required=True, help="ExportEtnaGenesis JSON")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    write(build(load(args.base), load(args.runtime)), args.output)


if __name__ == "__main__":
    main()
