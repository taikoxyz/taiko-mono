#!/usr/bin/env python3
"""Build an alloc-only Etna genesis for a new network.

Only alloc changes, except the derived top-level stateRoot is discarded. All other non-alloc
fields remain identical to the base genesis JSON. The alloc gains the Taiko L2 predeploys that
`pnpm genesis:gen` generated for the Etna network, replacing any account at the same address, and
the canonical EIP-4788 and EIP-2935 system contracts.

The predeploy configuration must give the Anchor `etnaTimestamp` 0x0: on a new network every block
is an Etna block, and an Anchor without that gate keeps `anchorV4` callable with the public golden
touch key, which would let anyone save a forged L1 checkpoint. Its `remoteSignalService` must be
the deployed L1 SignalService passed as `--l1-signal-service`, which `SignalServiceL2` proves
against. Predeploy accounts are reduced to the fields execution clients accept (balance, nonce,
code, storage), dropping the generator's `contractName`, with storage keys and values written as
32-byte words.

The configuration file can disagree with the alloc, for example when it was edited without rerunning
the generator, so the same values are also checked in the emitted bytecode, against the artifacts in
`--artifacts` (`out/layer2`, written with their AST by `pnpm genesis:gen`). The Anchor and
SignalService proxy accounts must hold exactly the compiled `ERC1967Proxy` runtime and point at
their implementations. Each implementation's code must be the runtime of the compiled `Anchor` or
`SignalServiceL2`, differing only in immutables; these contracts link no library, so an artifact
with a library link is refused. Then the immutables are read at the compiler's offsets: the
Anchor's `etnaTimestamp` must be 0 and its `checkpointStore` the SignalService proxy, and
SignalServiceL2's `_authorizedSyncer` must be the Anchor proxy and its `_remoteSignalService` the
L1 SignalService.
"""

import argparse
import copy
import json
from pathlib import Path
import re

ROOTS = "0x000f3df6d732807ef1319fb7b8bb8522d0beac02"
HISTORY = "0x0000f90827f1c53a10cb7a02335b175320002935"
ZERO_ADDRESS = "0x" + "00" * 20
# Canonical runtimes copied from taikoxyz/alethia-reth at
# 1e25b4849259320fca1123de362bc38b0b090ece:crates/node/tests/fixtures/etna-genesis.json.
ROOTS_RUNTIME = "0x3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500"
HISTORY_RUNTIME = "0x3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500"
# Predeploys the Etna root path depends on: the Anchor gates anchorV4 and resolves L1 state roots,
# and SignalServiceL2 proves L1 signals against them.
REQUIRED_PREDEPLOYS = ("TaikoAnchor", "TaikoAnchorImpl", "SignalService", "SignalServiceImpl")
# Genesis account fields execution clients accept; alethia-reth rejects any other key.
ACCOUNT_FIELDS = ("balance", "nonce", "code", "storage")
# Generator bookkeeping that is not part of the account.
GENERATOR_FIELDS = ("contractName",)
# The ERC-1967 implementation slot of the predeploy proxies.
IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
# The `pnpm genesis:gen` artifacts: `pnpm compile:l2` writes them with their AST.
DEFAULT_ARTIFACTS = Path(__file__).resolve().parents[2] / "out" / "layer2"


def address(value):
    """Normalize one 20-byte alloc address without accepting truncation or padding."""
    if not isinstance(value, str):
        raise ValueError("address must be a string")
    value = value.lower().removeprefix("0x")
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("alloc addresses must contain exactly 20 hex bytes")
    return "0x" + value


def word(value, label):
    """Normalize a hex quantity of at most 32 bytes to a 0x-prefixed 32-byte word."""
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]{1,64}", value):
        raise ValueError(label + " must be a 0x-prefixed hex string of at most 32 bytes")
    return "0x" + value[2:].lower().rjust(64, "0")


def genesis_account(account, label):
    """Reduce one generated predeploy to the genesis account fields execution clients accept."""
    if not isinstance(account, dict):
        raise ValueError(label + " must be an object")
    unknown = sorted(set(account) - set(ACCOUNT_FIELDS) - set(GENERATOR_FIELDS))
    if unknown:
        raise ValueError(label + " has unknown fields: " + ", ".join(unknown))
    if "balance" not in account:
        raise ValueError(label + " has no balance")
    result = {key: account[key] for key in ACCOUNT_FIELDS if key in account}
    if "code" in result:
        code = result["code"]
        if not isinstance(code, str) or not re.fullmatch(r"0x(?:[0-9a-fA-F]{2})*", code):
            raise ValueError(label + " code must be 0x-prefixed hex bytes")
        result["code"] = code.lower()
    if "storage" in result:
        storage = {}
        for key, value in result["storage"].items():
            slot = word(key, label + " storage key")
            if slot in storage:
                raise ValueError(label + " has a duplicate storage slot: " + slot)
            storage[slot] = word(value, label + " storage value")
        result["storage"] = storage
    return result


def normalized_alloc(alloc, label):
    """Normalize alloc keys, rejecting two keys that name the same address."""
    result = {}
    for key, account in alloc.items():
        normalized = address(key)
        if normalized in result:
            raise ValueError("duplicate " + label + " address after normalization: " + normalized)
        result[normalized] = account
    return result


def check_predeploy_config(config, base, predeploys, l1_signal_service):
    """Check that the generator configuration describes an Etna network matching the base."""
    etna_timestamp = config.get("etnaTimestamp")
    if not isinstance(etna_timestamp, str) or not re.fullmatch(r"0x[0-9a-fA-F]+", etna_timestamp):
        raise ValueError("predeploy config: etnaTimestamp must be a 0x-prefixed hex string")
    if int(etna_timestamp, 16) != 0:
        raise ValueError(
            "predeploy config: etnaTimestamp must be 0x0 on a new Etna network, or anchorV4 "
            "stays callable with the public golden touch key; set it in "
            "test/genesis/data/genesis_config.js and rerun `pnpm genesis:gen`"
        )
    remote = address(config.get("remoteSignalService"))
    if remote == ZERO_ADDRESS or remote != address(l1_signal_service):
        raise ValueError(
            "predeploy config: remoteSignalService must be the L1 SignalService " + l1_signal_service
        )
    chain_id = config.get("chainId")
    if not isinstance(chain_id, int) or chain_id != base.get("config", {}).get("chainId"):
        raise ValueError("predeploy config: chainId differs from the base genesis chain id")
    addresses = config.get("contractAddresses", {})
    for name in REQUIRED_PREDEPLOYS:
        if name not in addresses:
            raise ValueError("predeploy config: no " + name + " address")
        account = predeploys.get(address(addresses[name]))
        if not account or not account.get("code", "0x").removeprefix("0x"):
            raise ValueError("predeploys: no code at the configured " + name + " address")


def address_word(value):
    """Left-pad a 20-byte address to the 32-byte word an immutable or storage slot holds."""
    return "0x" + address(value).removeprefix("0x").rjust(64, "0")


def load_artifact(artifacts, name):
    """Load the Foundry artifact of contract `name` from the artifacts directory."""
    path = Path(artifacts) / (name + ".sol") / (name + ".json")
    if not path.is_file():
        raise ValueError("artifacts: no " + str(path) + "; run `pnpm genesis:gen`")
    return load(path)


def immutable_id(artifacts, contract, name):
    """Return the AST id of the immutable `name` that `contract` declares.

    Solidity identifies immutables by AST id in `immutableReferences`; the generator patches them
    by the same lookup.
    """
    ast = load_artifact(artifacts, contract).get("ast")
    if not isinstance(ast, dict):
        raise ValueError("artifacts: " + contract + " has no AST; rebuild with `pnpm genesis:gen`")
    for node in ast.get("nodes", []):
        if node.get("nodeType") != "ContractDefinition" or node.get("name") != contract:
            continue
        for member in node.get("nodes", []):
            if (member.get("nodeType") == "VariableDeclaration" and member.get("name") == name
                    and member.get("mutability") == "immutable"):
                return str(member["id"])
    raise ValueError("artifacts: " + contract + " declares no immutable " + name)


def runtime_code(account, artifacts, contract, label):
    """Require the account code to be `contract`'s compiled runtime, filled in only at its
    immutables, and return it as bytes."""
    deployed = load_artifact(artifacts, contract).get("deployedBytecode", {})
    if deployed.get("linkReferences"):
        raise ValueError("artifacts: " + contract + " links a library, which the genesis check "
                         "does not cover")
    expected = bytes.fromhex(deployed.get("object", "").removeprefix("0x"))
    code = bytes.fromhex(account["code"].removeprefix("0x"))
    filled = set()
    for references in deployed.get("immutableReferences", {}).values():
        for reference in references:
            filled.update(range(reference["start"], reference["start"] + reference["length"]))
    if not expected or len(code) != len(expected) or any(
        code[i] != expected[i] for i in range(len(code)) if i not in filled
    ):
        raise ValueError(
            "predeploys: " + label + " is not the compiled " + contract + " runtime in "
            + str(artifacts) + "; rerun `pnpm genesis:gen`, or pass the artifacts it used with "
            "--artifacts"
        )
    return code


def immutable_word(code, artifact, reference_id, label):
    """Return the one 32-byte value written at every offset of an immutable."""
    references = artifact["deployedBytecode"].get("immutableReferences", {}).get(reference_id)
    if not references:
        raise ValueError("artifacts: " + label + " has no offsets in the runtime; the artifacts "
                         "may come from different builds, so rebuild them with `pnpm genesis:gen`")
    if any(r["length"] != 32 for r in references):
        raise ValueError("artifacts: " + label + " is not a 32-byte immutable")
    values = {code[r["start"]:r["start"] + 32] for r in references}
    if len(values) != 1:
        raise ValueError("predeploys: " + label + " differs between its offsets")
    return "0x" + values.pop().hex()


def check_predeploy_code(config, predeploys, artifacts, l1_signal_service):
    """Check the Etna root path in the emitted bytecode rather than in the configuration."""
    addresses = {name: address(config["contractAddresses"][name]) for name in REQUIRED_PREDEPLOYS}
    for proxy, implementation in (("TaikoAnchor", "TaikoAnchorImpl"),
                                  ("SignalService", "SignalServiceImpl")):
        # Calls land at the proxy, so its code must be the plain proxy, not an implementation.
        runtime_code(predeploys[addresses[proxy]], artifacts, "ERC1967Proxy", proxy)
        storage = predeploys[addresses[proxy]].get("storage", {})
        if storage.get(IMPLEMENTATION_SLOT) != address_word(addresses[implementation]):
            raise ValueError("predeploys: the " + proxy + " proxy does not point at the "
                             "configured " + implementation)
    expected = (
        ("TaikoAnchorImpl", "Anchor", (
            ("Anchor", "etnaTimestamp", "0x" + "00" * 32),
            ("Anchor", "checkpointStore", address_word(addresses["SignalService"])),
        )),
        ("SignalServiceImpl", "SignalServiceL2", (
            ("SignalService", "_authorizedSyncer", address_word(addresses["TaikoAnchor"])),
            ("SignalService", "_remoteSignalService", address_word(l1_signal_service)),
        )),
    )
    for name, contract, immutables in expected:
        artifact = load_artifact(artifacts, contract)
        code = runtime_code(predeploys[addresses[name]], artifacts, contract, name)
        for declaring, immutable, value in immutables:
            label = name + " " + immutable
            reference_id = immutable_id(artifacts, declaring, immutable)
            actual = immutable_word(code, artifact, reference_id, label)
            if actual != value:
                raise ValueError("predeploys: " + label + " is " + actual + ", not " + value)


def build(base, predeploys, predeploy_config, l1_signal_service, artifacts=DEFAULT_ARTIFACTS):
    """Overlay the predeploys, install the system contracts and drop the stale state root."""
    genesis = copy.deepcopy(base)
    genesis.pop("stateRoot", None)
    alloc = normalized_alloc(genesis.get("alloc", {}), "alloc")
    overlay = {
        key: genesis_account(account, "predeploy " + key)
        for key, account in normalized_alloc(copy.deepcopy(predeploys), "predeploy").items()
    }
    check_predeploy_config(predeploy_config, genesis, overlay, l1_signal_service)
    check_predeploy_code(predeploy_config, overlay, artifacts, l1_signal_service)
    alloc.update(overlay)
    for target, deployed in ((ROOTS, ROOTS_RUNTIME), (HISTORY, HISTORY_RUNTIME)):
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
    """Load JSON, requiring unique keys in every nested object."""
    return json.loads(Path(path).read_text(), object_pairs_hook=_unique_object)


def main():
    """Read the explicit input paths and emit the alloc-only genesis."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True, help="canonical devnet genesis JSON")
    parser.add_argument(
        "--predeploys", type=Path, required=True,
        help="test/genesis/data/genesis_alloc.json from `pnpm genesis:gen`",
    )
    parser.add_argument(
        "--predeploy-config", type=Path, required=True,
        help="test/genesis/data/genesis_config.json from the same `pnpm genesis:gen` run",
    )
    parser.add_argument(
        "--l1-signal-service", required=True,
        help="the deployed L1 SignalService proxy (SIGNAL_SERVICE from deployInboxProxy())",
    )
    parser.add_argument(
        "--artifacts", type=Path, default=DEFAULT_ARTIFACTS,
        help="the Foundry artifacts the predeploys were generated from (default: this package's "
             "out/layer2, wherever the command runs)",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    genesis = build(
        load(args.base), load(args.predeploys), load(args.predeploy_config), args.l1_signal_service,
        args.artifacts,
    )
    write(genesis, args.output)


if __name__ == "__main__":
    main()
