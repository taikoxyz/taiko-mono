"""Synthetic inputs for the Etna genesis builder tests (stdlib only).

The predeploys are stand-in Anchor and SignalServiceL2 implementations behind ERC-1967 proxies.
Each implementation's code is a small artifact's runtime with its immutables and a library link
filled in the way `pnpm genesis:gen` fills them, so the builder can check the emitted bytecode
against the artifacts. Run as a script, it writes the inputs to a temporary directory and runs the
builder CLI, so the Solidity test exercises the same path as an operator.
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
L1_SIGNAL_SERVICE = "0x00000000000000000000000000000000000000aa"
LIBRARY = "0x00000000000000000000000000000000000000bb"
IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADDRESSES = {
    "TaikoAnchor": "0x1670010000000000000000000000000000010001",
    "TaikoAnchorImpl": "0x0167001000000000000000000000000000010001",
    "SignalService": "0x1670010000000000000000000000000000000005",
    "SignalServiceImpl": "0x0167001000000000000000000000000000000005",
}
# AST ids of the stand-in immutables. `self` stands for UUPS `__self`, which the builder does not
# check, and `pauser` for an immutable it does not check either.
IDS = {
    "checkpointStore": 11, "etnaTimestamp": 12, "self": 13,
    "_authorizedSyncer": 21, "_remoteSignalService": 22, "pauser": 23,
}
# The placeholder solc leaves for an unlinked library address: 20 bytes as 40 characters.
PLACEHOLDER = "__$" + "0" * 34 + "$__"


def word(value):
    """A 32-byte word holding the integer `value`."""
    return "0x" + format(value, "064x")


def address_word(value):
    """A 20-byte address left-padded to a 32-byte word."""
    return "0x" + value.removeprefix("0x").lower().rjust(64, "0")


def _artifact(name, declared, layout, bases=(), links=0):
    """An artifact whose runtime has a marker byte before each 32-byte immutable in `layout`, then
    `links` PUSH20 library addresses, then STOP."""
    code, immutables, linked = "", {}, []
    for index, immutable in enumerate(layout):
        code += format(0x60 + index, "02x")
        immutables.setdefault(str(IDS[immutable]), []).append({"start": len(code) // 2, "length": 32})
        code += "00" * 32
    for _ in range(links):
        code += "73"
        linked.append({"start": len(code) // 2, "length": 20})
        code += PLACEHOLDER
    code += "00"
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
            "linkReferences": {"contracts/Lib.sol": {"Lib": linked}} if linked else {},
        },
    }


def artifacts():
    """The stand-in Anchor, SignalService and SignalServiceL2 artifacts. The Anchor reads
    `etnaTimestamp` twice; SignalServiceL2 inherits SignalService's immutables and links one
    library."""
    return {
        "Anchor": _artifact(
            "Anchor", ("checkpointStore", "etnaTimestamp", "self"),
            ("checkpointStore", "etnaTimestamp", "self", "etnaTimestamp"),
        ),
        "SignalService": _artifact(
            "SignalService", ("_authorizedSyncer", "_remoteSignalService", "pauser"),
            ("_authorizedSyncer", "_remoteSignalService", "pauser"),
        ),
        "SignalServiceL2": _artifact(
            "SignalServiceL2", (), ("_authorizedSyncer", "_remoteSignalService", "pauser",
                                    "_remoteSignalService"),
            bases=("SignalService",), links=1,
        ),
    }


def runtime(artifact, values):
    """The artifact's runtime with each immutable set from `values` (by name) and every library
    link set to `LIBRARY`."""
    deployed = artifact["deployedBytecode"]
    code = bytearray.fromhex(deployed["object"].removeprefix("0x").replace(PLACEHOLDER, "00" * 20))
    names = {str(i): name for name, i in IDS.items()}
    for reference_id, references in deployed["immutableReferences"].items():
        value = bytes.fromhex(values[names[reference_id]].removeprefix("0x"))
        for reference in references:
            code[reference["start"]:reference["start"] + 32] = value
    for libraries in deployed["linkReferences"].values():
        for references in libraries.values():
            for reference in references:
                code[reference["start"]:reference["start"] + 20] = bytes.fromhex(LIBRARY[2:])
    return "0x" + code.hex()


def proxy(implementation):
    """A stand-in ERC-1967 proxy pointing at `implementation`."""
    return {"balance": "0x0", "code": "0x6001",
            "storage": {IMPLEMENTATION_SLOT: address_word(implementation)}}


def predeploys(**overrides):
    """The four root-path predeploys as the generator writes them for a new Etna network, with
    immutable words replaced by name from `overrides`."""
    values = {
        "checkpointStore": address_word(ADDRESSES["SignalService"]),
        "etnaTimestamp": word(0),
        "self": address_word(ADDRESSES["TaikoAnchorImpl"]),
        "_authorizedSyncer": address_word(ADDRESSES["TaikoAnchor"]),
        "_remoteSignalService": address_word(L1_SIGNAL_SERVICE),
        "pauser": word(0),
    }
    values.update(overrides)
    stand_ins = artifacts()
    return {
        ADDRESSES["TaikoAnchor"]: proxy(ADDRESSES["TaikoAnchorImpl"]),
        ADDRESSES["TaikoAnchorImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["Anchor"], values)},
        ADDRESSES["SignalService"]: proxy(ADDRESSES["SignalServiceImpl"]),
        ADDRESSES["SignalServiceImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["SignalServiceL2"], values)},
    }


def config():
    """The generator configuration of the same run."""
    return {
        "chainId": CHAIN_ID,
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
