"""Synthetic inputs for the Etna genesis builder tests (stdlib only).

The predeploys are stand-in Anchor and SignalServiceL2 implementations behind stand-in ERC-1967
proxies. Each account's code is a small artifact's runtime with its immutables filled in the way
`pnpm genesis:gen` fills them, so the builder can check the emitted bytecode against the
artifacts. Run as a script, it writes the inputs to a temporary directory and runs the builder
CLI, so the Solidity test exercises the same path as an operator.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

PROTOCOL = Path(__file__).resolve().parents[3]
SCRIPT = PROTOCOL / "script/layer2/build_etna_genesis.py"
CHAIN_ID = 167001
L1_CHAIN_ID = 3151908
L1_SIGNAL_SERVICE = "0x00000000000000000000000000000000000100aa"
OWNER = "0x00000000000000000000000000000000000a11ce"
IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADDRESSES = {
    "TaikoAnchor": "0x1670010000000000000000000000000000010001",
    "TaikoAnchorImpl": "0x0167001000000000000000000000000000010001",
    "SignalService": "0x1670010000000000000000000000000000000005",
    "SignalServiceImpl": "0x0167001000000000000000000000000000000005",
    "SharedResolver": "0x1670010000000000000000000000000000000006",
}
# AST ids of the stand-in immutables: UUPS `__self`, EssentialContract `__resolver`, the Anchor's
# and SignalService's own.
IDS = {
    "checkpointStore": 11, "etnaTimestamp": 12, "__self": 13, "__resolver": 14, "l1ChainId": 15,
    "_authorizedSyncer": 21, "_remoteSignalService": 22, "pauser": 23,
}


def word(value):
    """A 32-byte word holding the integer `value`."""
    return "0x" + format(value, "064x")


def address_word(value):
    """A 20-byte address left-padded to a 32-byte word."""
    return "0x" + value.removeprefix("0x").lower().rjust(64, "0")


def _artifact(name, declared, layout, bases=(), body="00"):
    """An artifact whose runtime has a marker byte before each 32-byte immutable in `layout`, then
    `body`."""
    code, immutables = "", {}
    for index, immutable in enumerate(layout):
        code += format(0x60 + index, "02x")
        immutables.setdefault(str(IDS[immutable]), []).append({"start": len(code) // 2, "length": 32})
        code += "00" * 32
    code += body
    contract = {
        "nodeType": "ContractDefinition",
        "name": name,
        "baseContracts": [{"baseName": {"name": base}} for base in bases],
        "nodes": [
            {"nodeType": "VariableDeclaration", "name": variable, "id": IDS[variable],
             "mutability": "immutable"}
            for variable in declared
        ],
    }
    return {
        "ast": {"nodeType": "SourceUnit", "nodes": [contract]},
        "deployedBytecode": {
            "object": "0x" + code,
            "immutableReferences": immutables,
            "linkReferences": {},
        },
    }


def artifacts():
    """The stand-in ERC1967Proxy, UUPSUpgradeable, EssentialContract, Anchor, SignalService and
    SignalServiceL2 artifacts. The proxy has no immutables, both implementations also carry the
    inherited `__self` and `__resolver`, the Anchor reads `etnaTimestamp` twice, and
    SignalServiceL2 inherits SignalService's immutables."""
    return {
        "ERC1967Proxy": _artifact("ERC1967Proxy", (), (), body="363d3d373d3d3d363d00"),
        "UUPSUpgradeable": _artifact("UUPSUpgradeable", ("__self",), ("__self",)),
        "EssentialContract": _artifact("EssentialContract", ("__resolver",), ("__resolver",),
                                       bases=("UUPSUpgradeable",)),
        "Anchor": _artifact(
            "Anchor", ("checkpointStore", "etnaTimestamp", "l1ChainId"),
            ("checkpointStore", "etnaTimestamp", "__self", "etnaTimestamp", "__resolver",
             "l1ChainId"),
            bases=("EssentialContract",),
        ),
        "SignalService": _artifact(
            "SignalService", ("_authorizedSyncer", "_remoteSignalService", "pauser"),
            ("_authorizedSyncer", "_remoteSignalService", "pauser"),
            bases=("EssentialContract",),
        ),
        "SignalServiceL2": _artifact(
            "SignalServiceL2", (), ("_authorizedSyncer", "_remoteSignalService", "pauser",
                                    "_remoteSignalService", "__self", "__resolver"),
            bases=("SignalService",),
        ),
    }


def runtime(artifact, values):
    """The artifact's runtime with each immutable set from `values` (by name)."""
    deployed = artifact["deployedBytecode"]
    code = bytearray.fromhex(deployed["object"].removeprefix("0x"))
    names = {str(i): name for name, i in IDS.items()}
    for reference_id, references in deployed["immutableReferences"].items():
        value = bytes.fromhex(values[names[reference_id]].removeprefix("0x"))
        for reference in references:
            code[reference["start"]:reference["start"] + 32] = value
    return "0x" + code.hex()


def proxy(implementation, extra=None):
    """A stand-in ERC-1967 proxy pointing at `implementation`, with the storage the generator
    writes: initialized, the owner, not paused or entered, then any `extra` words."""
    storage = {
        word(0): word(1),
        word(51): address_word(OWNER),
        word(201): word(0x0101),
        IMPLEMENTATION_SLOT: address_word(implementation),
    }
    storage.update(extra or {})
    return {"balance": "0x0", "code": runtime(artifacts()["ERC1967Proxy"], {}),
            "storage": storage}


def predeploys(**overrides):
    """The four root-path predeploys as the generator writes them for a new Etna network, with
    immutable words replaced by name from `overrides` in both implementations."""
    shared = {
        "checkpointStore": address_word(ADDRESSES["SignalService"]),
        "etnaTimestamp": word(0),
        "l1ChainId": word(L1_CHAIN_ID),
        "_authorizedSyncer": address_word(ADDRESSES["TaikoAnchor"]),
        "_remoteSignalService": address_word(L1_SIGNAL_SERVICE),
        "pauser": word(0),
    }
    anchor = dict(shared, __self=address_word(ADDRESSES["TaikoAnchorImpl"]), __resolver=word(0))
    signal = dict(shared, __self=address_word(ADDRESSES["SignalServiceImpl"]),
                  __resolver=address_word(ADDRESSES["SharedResolver"]))
    anchor.update(overrides)
    signal.update(overrides)
    stand_ins = artifacts()
    # The generator also writes the Anchor's `_blockState` (slots 256 and 257) as zeros.
    return {
        ADDRESSES["TaikoAnchor"]: proxy(ADDRESSES["TaikoAnchorImpl"],
                                        {word(256): word(0), word(257): word(0)}),
        ADDRESSES["TaikoAnchorImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["Anchor"], anchor)},
        ADDRESSES["SignalService"]: proxy(ADDRESSES["SignalServiceImpl"]),
        ADDRESSES["SignalServiceImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["SignalServiceL2"], signal)},
    }


def config():
    """The generator configuration of the same run."""
    return {
        "contractOwner": OWNER,
        "chainId": CHAIN_ID,
        "l1ChainId": L1_CHAIN_ID,
        "etnaTimestamp": "0x0",
        "remoteSignalService": L1_SIGNAL_SERVICE,
        "contractAddresses": dict(ADDRESSES),
    }


def write_artifacts(directory, contracts):
    """Write `contracts` in Foundry's `<name>.sol/<name>.json` layout under `directory`."""
    for name, artifact in contracts.items():
        path = Path(directory) / (name + ".sol") / (name + ".json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(artifact))


def main():
    """Write the inputs to a temporary directory and run the builder CLI on them."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        inputs = Path(directory)
        (inputs / "base.json").write_text(
            json.dumps({"config": {"chainId": CHAIN_ID}, "timestamp": "0x0", "alloc": {}}))
        (inputs / "predeploys.json").write_text(json.dumps(predeploys()))
        (inputs / "config.json").write_text(json.dumps(config()))
        write_artifacts(inputs / "artifacts", artifacts())
        subprocess.run([sys.executable, str(SCRIPT), "--base", str(inputs / "base.json"),
                        "--predeploys", str(inputs / "predeploys.json"),
                        "--predeploy-config", str(inputs / "config.json"),
                        "--l1-signal-service", L1_SIGNAL_SERVICE,
                        "--artifacts", str(inputs / "artifacts"),
                        "--output", str(args.output)], check=True)


if __name__ == "__main__":
    main()
