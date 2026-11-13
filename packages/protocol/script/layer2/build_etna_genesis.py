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
L1 SignalService. Every other immutable of both implementations is pinned to the value the
generator writes (UUPS `__self` the implementation's own address, the Anchor's `l1ChainId` the
configured one, its resolver zero, SignalServiceL2's resolver the SharedResolver proxy and its
`pauser` zero), and an immutable the builder does not know is refused. The proxies' storage may
hold only what the generator initializes: initialized, not paused, the configured owner and the
implementation slot. No root-path address, nor the L1 SignalService, may be a precompile or system
contract address, and the L1 SignalService may not be an L2 predeploy.

Needs Python 3.9 or later. Errors print one line to stderr and exit 1; `--output` is written only
by a successful run, and an existing file there is removed first so a failed run leaves none.
"""

import argparse
import copy
import json
import os
from pathlib import Path
import re
import sys
import tempfile

if sys.version_info < (3, 9):
    raise SystemExit("build_etna_genesis.py needs Python 3.9 or later")

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
# Precompiles occupy the lowest addresses and the EVM keeps adding them there: a root-path contract
# at 0x02 would run SHA-256 and return a 32-byte "state root" for any input.
RESERVED_ADDRESS_LIMIT = 0xFFFF
# The generator's proxy storage (EssentialContract layout): `_initialized` 1 and `_initializing`
# false in slot 0, `_owner` in slot 51, and `__reentry` and `__paused` both 1 (false) in slot 201.
INITIALIZED_SLOT = "0x" + format(0, "064x")
OWNER_SLOT = "0x" + format(51, "064x")
FLAGS_SLOT = "0x" + format(201, "064x")
ZERO_WORD = "0x" + "00" * 32


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


def check_not_reserved(value, label):
    """Refuse a precompile or system contract address, where code would not run as written."""
    normalized = address(value)
    if int(normalized, 16) <= RESERVED_ADDRESS_LIMIT or normalized in (ROOTS, HISTORY):
        raise ValueError(label + " " + normalized + " is a precompile or system contract address")
    return normalized


def chain_id(value, label):
    """Require a positive integer chain id; JSON `true` is not one."""
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValueError(label + " must be a positive integer")
    return value


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
    l1 = check_not_reserved(l1_signal_service, "--l1-signal-service")
    if l1 in predeploys:
        raise ValueError("--l1-signal-service " + l1 + " is an L2 predeploy address; pass the L1 "
                         "SignalService that deployInboxProxy() deployed")
    remote = address(config.get("remoteSignalService"))
    if remote == ZERO_ADDRESS or remote != l1:
        raise ValueError(
            "predeploy config: remoteSignalService must be the L1 SignalService " + l1_signal_service
        )
    l2 = chain_id(config.get("chainId"), "predeploy config: chainId")
    if l2 != chain_id(base.get("config", {}).get("chainId"), "base genesis: config.chainId"):
        raise ValueError("predeploy config: chainId differs from the base genesis chain id")
    if chain_id(config.get("l1ChainId"), "predeploy config: l1ChainId") == l2:
        raise ValueError("predeploy config: l1ChainId equals the L2 chain id")
    owner = config.get("contractOwner")
    if owner is None or address(owner) == ZERO_ADDRESS:
        raise ValueError("predeploy config: contractOwner must be a non-zero address")
    addresses = config.get("contractAddresses", {})
    for name in REQUIRED_PREDEPLOYS + ("SharedResolver",):
        if name not in addresses:
            raise ValueError("predeploy config: no " + name + " address")
    for name in REQUIRED_PREDEPLOYS:
        check_not_reserved(addresses[name], "predeploy config: " + name)
        account = predeploys.get(address(addresses[name]))
        if not account or not account.get("code", "0x").removeprefix("0x"):
            raise ValueError("predeploys: no code at the configured " + name + " address")


def address_word(value):
    """Left-pad a 20-byte address to the 32-byte word an immutable or storage slot holds."""
    return "0x" + address(value).removeprefix("0x").rjust(64, "0")


class Artifacts:
    """The Foundry artifacts in one directory, each read once per build."""

    def __init__(self, directory):
        self.directory = Path(directory)
        self._loaded = {}

    def get(self, name):
        """Return the artifact of contract `name`."""
        if name not in self._loaded:
            path = self.directory / (name + ".sol") / (name + ".json")
            if not path.is_file():
                raise ValueError("artifacts: no " + str(path) + "; run `pnpm genesis:gen`")
            self._loaded[name] = load(path)
        return self._loaded[name]


def immutable_id(artifacts, contract, name):
    """Return the AST id of the immutable `name` that `contract` declares.

    Solidity identifies immutables by AST id in `immutableReferences`; the generator patches them
    by the same lookup.
    """
    ast = artifacts.get(contract).get("ast")
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
    deployed = artifacts.get(contract).get("deployedBytecode", {})
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
            + str(artifacts.directory) + "; rerun `pnpm genesis:gen`, or pass the artifacts it "
            "used with --artifacts"
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


def check_proxy_storage(name, account, implementation, owner):
    """Allow only the storage the generator writes into a proxy; any other non-zero word, such as
    a seeded received signal, checkpoint or pause flag, is refused."""
    expected = {
        INITIALIZED_SLOT: "0x" + format(1, "064x"),
        OWNER_SLOT: address_word(owner),
        FLAGS_SLOT: "0x" + format(0x0101, "064x"),
        IMPLEMENTATION_SLOT: address_word(implementation),
    }
    storage = account.get("storage", {})
    if storage.get(IMPLEMENTATION_SLOT) != expected[IMPLEMENTATION_SLOT]:
        raise ValueError("predeploys: the " + name + " proxy does not point at the configured "
                         + name + "Impl")
    for slot in sorted(set(storage) | set(expected)):
        actual = storage.get(slot, ZERO_WORD)
        wanted = expected.get(slot, ZERO_WORD)
        if actual != wanted:
            raise ValueError("predeploys: the " + name + " proxy's storage slot " + slot + " is "
                             + actual + ", not " + wanted + " as `pnpm genesis:gen` writes it")


def check_predeploy_code(config, predeploys, artifacts, l1_signal_service):
    """Check the Etna root path in the emitted bytecode rather than in the configuration."""
    addresses = {name: address(config["contractAddresses"][name])
                 for name in REQUIRED_PREDEPLOYS + ("SharedResolver",)}
    for proxy in ("TaikoAnchor", "SignalService"):
        # Calls land at the proxy, so its code must be the plain proxy, not an implementation.
        runtime_code(predeploys[addresses[proxy]], artifacts, "ERC1967Proxy", proxy)
        check_proxy_storage(proxy, predeploys[addresses[proxy]], addresses[proxy + "Impl"],
                            config["contractOwner"])
    expected = (
        ("TaikoAnchorImpl", "Anchor", (
            ("UUPSUpgradeable", "__self", address_word(addresses["TaikoAnchorImpl"])),
            ("EssentialContract", "__resolver", ZERO_WORD),
            ("Anchor", "checkpointStore", address_word(addresses["SignalService"])),
            ("Anchor", "l1ChainId", "0x" + format(config["l1ChainId"], "064x")),
            ("Anchor", "etnaTimestamp", ZERO_WORD),
        )),
        ("SignalServiceImpl", "SignalServiceL2", (
            ("UUPSUpgradeable", "__self", address_word(addresses["SignalServiceImpl"])),
            ("EssentialContract", "__resolver", address_word(addresses["SharedResolver"])),
            ("SignalService", "_authorizedSyncer", address_word(addresses["TaikoAnchor"])),
            ("SignalService", "_remoteSignalService", address_word(l1_signal_service)),
            ("SignalService", "pauser", ZERO_WORD),
        )),
    )
    for name, contract, immutables in expected:
        artifact = artifacts.get(contract)
        code = runtime_code(predeploys[addresses[name]], artifacts, contract, name)
        checked = set()
        for declaring, immutable, value in immutables:
            label = name + " " + immutable
            reference_id = immutable_id(artifacts, declaring, immutable)
            checked.add(reference_id)
            actual = immutable_word(code, artifact, reference_id, label)
            if actual != value:
                raise ValueError("predeploys: " + label + " is " + actual + ", not " + value
                                 + "; if the configuration changed, rerun `pnpm genesis:gen` "
                                 "so the alloc matches it")
        unchecked = sorted(set(artifact["deployedBytecode"].get("immutableReferences", {}))
                           - checked)
        if unchecked:
            raise ValueError("artifacts: " + contract + " has immutables the builder does not "
                             "check (AST ids " + ", ".join(unchecked) + "); extend "
                             "build_etna_genesis.py before using it")


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
    check_predeploy_code(predeploy_config, overlay, Artifacts(artifacts), l1_signal_service)
    alloc.update(overlay)
    for target, deployed in ((ROOTS, ROOTS_RUNTIME), (HISTORY, HISTORY_RUNTIME)):
        alloc[target] = {"balance": "0x0", "nonce": "0x1", "code": deployed}
    genesis["alloc"] = alloc
    return genesis


def write(genesis, output):
    """Write deterministic, sorted JSON with one terminating newline, atomically: a reader never
    sees a partial file."""
    output = Path(output)
    handle, temporary = tempfile.mkstemp(dir=output.parent, prefix=output.name + ".", suffix=".tmp")
    try:
        with os.fdopen(handle, "w") as stream:
            stream.write(json.dumps(genesis, sort_keys=True, indent=2) + "\n")
        os.replace(temporary, output)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


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
    parser.add_argument(
        "--output", type=Path, required=True,
        help="the genesis to write; an existing file is removed first, so only a successful run "
             "leaves one",
    )
    args = parser.parse_args()
    try:
        args.output.unlink(missing_ok=True)
        genesis = build(
            load(args.base), load(args.predeploys), load(args.predeploy_config),
            args.l1_signal_service, args.artifacts,
        )
        write(genesis, args.output)
    except (OSError, ValueError) as error:
        sys.exit("build_etna_genesis.py: error: " + str(error))


if __name__ == "__main__":
    main()
