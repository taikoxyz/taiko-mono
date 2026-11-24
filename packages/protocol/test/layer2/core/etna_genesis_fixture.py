"""Synthetic inputs for the Etna genesis builder tests (stdlib only).

The predeploys are stand-in Anchor, EtnaSignalService, EtnaStaking and BridgedTaikoToken
implementations behind stand-in ERC-1967 proxies, and an ERC20Vault proxy that holds the bridged
TAIKO mapping. Each implementation's code is a small artifact's runtime with its immutables filled
in the way `pnpm genesis:gen` fills them, so the builder can check the emitted bytecode against the
artifacts. The token is a devnet one with a premint. Mapping slots are written out as
`cast index` computes them, so the builder's own hashing is checked against them. Run as a script,
it writes the inputs to a temporary directory and runs the builder CLI, so the Solidity test
exercises the same path as an operator.
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
L1_INBOX = "0x00000000000000000000000000000000000100bb"
L1_TAIKO_TOKEN = "0x00000000000000000000000000000000000100cc"
OWNER = "0x00000000000000000000000000000000000a11ce"
STAKING_OWNER = "0x0000000000000000000000000000000000000da0"
SLASH_SINK = "0x00000000000000000000000000000000000051a5"
ERC20_VAULT_IMPL = "0x0167001000000000000000000000000000000002"
IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADDRESSES = {
    "TaikoAnchor": "0x1670010000000000000000000000000000010001",
    "TaikoAnchorImpl": "0x0167001000000000000000000000000000010001",
    "SignalService": "0x1670010000000000000000000000000000000005",
    "SignalServiceImpl": "0x0167001000000000000000000000000000000005",
    "SharedResolver": "0x1670010000000000000000000000000000000006",
    "ERC20Vault": "0x1670010000000000000000000000000000000002",
    "BridgedTaikoToken": "0x1670010000000000000000000000000000000007",
    "BridgedTaikoTokenImpl": "0x0167001000000000000000000000000000000007",
    "EtnaStaking": "0x1670010000000000000000000000000000010003",
    "EtnaStakingImpl": "0x0167001000000000000000000000000000010003",
}
# The example devnet's EtnaStaking parameters, as the configuration writes them: decimal strings.
STAKING = {
    "minStake": "7812500000000000000000000",
    "vpUnit": "1000000000",
    "nMax": "128",
    "withdrawalDelay": "302402",
    "slashBountyBps": "1000",
    "forfeitBps": "1000",
}
# The devnet premint: one minStake to each of two accounts, with the account's `_balances` slot,
# `cast index address <account> 301`.
PREMINT = (
    ("0x00000000000000000000000000000000000b0b01", 7_812_500 * 10**18,
     "0xb43779fb31257a5e2eabd4e39d4171a06a27f87597d295849362041ab97313a9"),
    ("0x00000000000000000000000000000000000b0b02", 7_812_500 * 10**18,
     "0xa383dce1425d05d1db447f980875e8c15a802f482b633fa02175ff234984440f"),
)
# An account outside the premint, and its `_balances` slot.
OTHER_ACCOUNT = "0x00000000000000000000000000000000000ca401"
OTHER_BALANCE_SLOT = "0x153c7b7ea981f9e6ff544915013566ee8cd7a62195cf037e75c92d7894b13dcd"
# `cast keccak` of slot 456: the token's first total-supply checkpoint.
CHECKPOINT_SLOT = "0x8cdee82cb3ac6d59f1f417405a3eecf497b31f3d06d4c506f96deb67789f61e9"
# The ERC20Vault's `bridgedToCanonical[bridged TAIKO]` struct, `cast index address <token> 301`,
# and `canonicalToBridged[L1_CHAIN_ID][L1_TAIKO_TOKEN]`, the address index into
# `cast index uint256 3151908 302`.
CANONICAL_SLOT = "0x2828bdcf09ddee99ec7f9f6aa10bdcd0a1ff5817f60a46ad8fc4f04a713816ad"
BRIDGED_SLOT = "0x43598beea7f739cd835268351273b0b7718e965243455a90bd5f7ee089a46ad4"
# Solidity's storage words of the short strings "Taiko Token", "TAIKO" and "1": the bytes
# left-aligned and twice the length in the lowest byte.
TAIKO_TOKEN_WORD = "0x5461696b6f20546f6b656e000000000000000000000000000000000000000016"
TAIKO_WORD = "0x5441494b4f00000000000000000000000000000000000000000000000000000a"
VERSION_WORD = "0x3100000000000000000000000000000000000000000000000000000000000002"
# The EtnaStaking namespace's first word, its snapshot height.
STAKING_NAMESPACE = "0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00"
# AST ids of the stand-in immutables, by the contract that declares them: UUPS `__self`,
# EssentialContract `__resolver`, then each implementation's own. EtnaSignalService declares
# `usesBeaconRoots` and inherits the other SignalService immutables.
IDS = {
    "UUPSUpgradeable": {"__self": 13},
    "EssentialContract": {"__resolver": 14},
    "Anchor": {"checkpointStore": 11, "l1ChainId": 15},
    "SignalService": {"_authorizedSyncer": 21, "_remoteSignalService": 22, "pauser": 23},
    "EtnaSignalService": {"usesBeaconRoots": 24},
    "EtnaStaking": {"token": 31, "l1ChainId": 32, "inbox": 33, "minStake": 34, "vpUnit": 35,
                    "nMax": 36, "withdrawalDelay": 39, "slashBountyBps": 40, "slashSink": 41,
                    "forfeitBps": 42},
    "BridgedTaikoToken": {"erc20Vault": 51},
}


def word(value):
    """A 32-byte word holding the integer `value`."""
    return "0x" + format(value, "064x")


def address_word(value):
    """A 20-byte address left-padded to a 32-byte word."""
    return "0x" + value.removeprefix("0x").lower().rjust(64, "0")


def _artifact(name, layout, bases=(), body="00"):
    """An artifact declaring `name`'s own immutables, whose runtime has a marker byte before each
    32-byte immutable in `layout`, its own or one of `bases`', then `body`."""
    ids = {}
    for contract in ("UUPSUpgradeable", "EssentialContract", *bases, name):
        ids.update(IDS.get(contract, {}))
    code, immutables = "", {}
    for index, immutable in enumerate(layout):
        code += format(0x60 + index, "02x")
        reference = {"start": len(code) // 2, "length": 32}
        immutables.setdefault(str(ids[immutable]), []).append(reference)
        code += "00" * 32
    code += body
    contract = {
        "nodeType": "ContractDefinition",
        "name": name,
        "baseContracts": [{"baseName": {"name": base}} for base in bases],
        "nodes": [
            {"nodeType": "VariableDeclaration", "name": variable, "id": ast_id,
             "mutability": "immutable"}
            for variable, ast_id in IDS.get(name, {}).items()
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
    """The stand-in ERC1967Proxy, UUPSUpgradeable, EssentialContract, Anchor, SignalService,
    EtnaSignalService, EtnaStaking and BridgedTaikoToken artifacts. The proxy has no immutables,
    every implementation also carries the inherited `__self` and `__resolver`, EtnaSignalService
    the inherited SignalService immutables, and EtnaSignalService reads `usesBeaconRoots` twice,
    EtnaStaking `inbox` and the token `erc20Vault`."""
    return {
        "ERC1967Proxy": _artifact("ERC1967Proxy", (), body="363d3d373d3d3d363d00"),
        "UUPSUpgradeable": _artifact("UUPSUpgradeable", ("__self",)),
        "EssentialContract": _artifact("EssentialContract", ("__resolver",),
                                       bases=("UUPSUpgradeable",)),
        "Anchor": _artifact(
            "Anchor", ("checkpointStore", "__self", "__resolver", "l1ChainId"),
            bases=("EssentialContract",),
        ),
        "SignalService": _artifact(
            "SignalService",
            ("_authorizedSyncer", "_remoteSignalService", "pauser", "__self", "__resolver"),
            bases=("EssentialContract",),
        ),
        "EtnaSignalService": _artifact(
            "EtnaSignalService",
            ("_authorizedSyncer", "usesBeaconRoots", "_remoteSignalService", "pauser",
             "usesBeaconRoots", "__self", "__resolver"),
            bases=("SignalService",),
        ),
        "EtnaStaking": _artifact(
            "EtnaStaking",
            ("inbox", "token", "l1ChainId", "minStake", "vpUnit", "nMax", "withdrawalDelay",
             "slashBountyBps", "slashSink", "forfeitBps", "__self", "__resolver", "inbox"),
            bases=("EssentialContract",),
        ),
        "BridgedTaikoToken": _artifact(
            "BridgedTaikoToken", ("erc20Vault", "__self", "__resolver", "erc20Vault"),
            bases=("EssentialContract",),
        ),
    }


def runtime(artifact, values):
    """The artifact's runtime with each immutable set from `values` (by name)."""
    deployed = artifact["deployedBytecode"]
    code = bytearray.fromhex(deployed["object"].removeprefix("0x"))
    names = {str(i): name for declared in IDS.values() for name, i in declared.items()}
    for reference_id, references in deployed["immutableReferences"].items():
        value = bytes.fromhex(values[names[reference_id]].removeprefix("0x"))
        for reference in references:
            code[reference["start"]:reference["start"] + 32] = value
    return "0x" + code.hex()


def proxy(implementation, owner=OWNER, flags=0x0101, extra=None):
    """A stand-in ERC-1967 proxy pointing at `implementation`, with the storage the generator
    writes: initialized, the owner, the flags word (by default not paused or entered), then any
    `extra` words."""
    storage = {
        word(0): word(1),
        word(51): address_word(owner),
        word(201): word(flags),
        IMPLEMENTATION_SLOT: address_word(implementation),
    }
    storage.update(extra or {})
    return {"balance": "0x0", "code": runtime(artifacts()["ERC1967Proxy"], {}),
            "storage": storage}


def token_storage(premint=PREMINT):
    """The bridged TAIKO proxy's words beyond the proxy's own, as `init` and the premint's `_mint`
    calls leave them: the balances, the total supply, the ERC-20 name and symbol (slots 303 to
    305), the EIP-712 name and version (353, 354) and, with a premint, one total-supply checkpoint
    (456 its length, then fromBlock 0 below the votes)."""
    total = sum(amount for _, amount, _ in premint)
    storage = {word(303): word(total), word(304): TAIKO_TOKEN_WORD, word(305): TAIKO_WORD,
               word(353): TAIKO_TOKEN_WORD, word(354): VERSION_WORD}
    for _, amount, slot in premint:
        storage[slot] = word(amount)
    if total:
        storage[word(456)] = word(1)
        storage[CHECKPOINT_SLOT] = word(total << 32)
    return storage


def vault_mapping():
    """The ERC20Vault words that map the bridged TAIKO predeploy to L1 TAIKO: the
    `CanonicalERC20` struct (chain id, address and 18 decimals packed in one word, then the symbol
    and the name) and the reverse mapping."""
    struct = int(CANONICAL_SLOT, 16)
    return {
        CANONICAL_SLOT: word(18 << 224 | int(L1_TAIKO_TOKEN, 16) << 64 | L1_CHAIN_ID),
        word(struct + 1): TAIKO_WORD,
        word(struct + 2): TAIKO_TOKEN_WORD,
        BRIDGED_SLOT: address_word(ADDRESSES["BridgedTaikoToken"]),
    }


def predeploys(staking=None, token=None, premint=PREMINT, **overrides):
    """The predeploys as the generator writes them for a new Etna devnet: the four root-path
    predeploys, with immutable words replaced by name from `overrides` in both implementations;
    EtnaStaking and bridged TAIKO, with immutable words replaced from the `staking` and `token`
    dicts and `premint` minted; and the ERC20Vault proxy with its TAIKO mapping."""
    shared = {
        "checkpointStore": address_word(ADDRESSES["SignalService"]),
        "l1ChainId": word(L1_CHAIN_ID),
        "_authorizedSyncer": address_word(ADDRESSES["TaikoAnchor"]),
        "_remoteSignalService": address_word(L1_SIGNAL_SERVICE),
        "pauser": word(0),
        # A `bool` immutable is a 32-byte word: 1 for true.
        "usesBeaconRoots": word(1),
    }
    anchor = dict(shared, __self=address_word(ADDRESSES["TaikoAnchorImpl"]), __resolver=word(0))
    signal = dict(shared, __self=address_word(ADDRESSES["SignalServiceImpl"]),
                  __resolver=address_word(ADDRESSES["SharedResolver"]))
    anchor.update(overrides)
    signal.update(overrides)
    staking_values = {
        "token": address_word(ADDRESSES["BridgedTaikoToken"]),
        "l1ChainId": word(L1_CHAIN_ID),
        "inbox": address_word(L1_INBOX),
        "slashSink": address_word(SLASH_SINK),
        "__self": address_word(ADDRESSES["EtnaStakingImpl"]),
        "__resolver": word(0),
    }
    staking_values.update({name: word(int(value)) for name, value in STAKING.items()})
    staking_values.update(staking or {})
    token_values = {
        "erc20Vault": address_word(ADDRESSES["ERC20Vault"]),
        "__self": address_word(ADDRESSES["BridgedTaikoTokenImpl"]),
        "__resolver": word(0),
    }
    token_values.update(token or {})
    stand_ins = artifacts()
    # An implementation's constructor leaves `_initialized` 255, so it can never be initialized.
    disabled = {word(0): word(255)}
    return {
        # The generator also writes the Anchor's `_blockState` (slots 256 and 257) as zeros.
        ADDRESSES["TaikoAnchor"]: proxy(ADDRESSES["TaikoAnchorImpl"],
                                        extra={word(256): word(0), word(257): word(0)}),
        ADDRESSES["TaikoAnchorImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["Anchor"], anchor)},
        ADDRESSES["SignalService"]: proxy(ADDRESSES["SignalServiceImpl"]),
        ADDRESSES["SignalServiceImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["EtnaSignalService"], signal)},
        # `init` writes only `__paused` (1, not paused) in slot 201 of the two Etna proxies.
        ADDRESSES["EtnaStaking"]: proxy(ADDRESSES["EtnaStakingImpl"], owner=STAKING_OWNER,
                                        flags=0x0100),
        ADDRESSES["EtnaStakingImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["EtnaStaking"], staking_values),
            "storage": dict(disabled)},
        ADDRESSES["BridgedTaikoToken"]: proxy(ADDRESSES["BridgedTaikoTokenImpl"], flags=0x0100,
                                              extra=token_storage(premint)),
        ADDRESSES["BridgedTaikoTokenImpl"]: {
            "balance": "0x0", "code": runtime(stand_ins["BridgedTaikoToken"], token_values),
            "storage": dict(disabled)},
        # A paused vault, as the generator writes it, holding the TAIKO mapping.
        ADDRESSES["ERC20Vault"]: proxy(ERC20_VAULT_IMPL, flags=0x0201, extra=vault_mapping()),
    }


def config(premint=PREMINT):
    """The generator configuration of the same run, an Etna devnet that premints `premint`."""
    etna = {
        "inbox": L1_INBOX,
        "l1TaikoToken": L1_TAIKO_TOKEN,
        "stakingOwner": STAKING_OWNER,
        "unsettledLimit": "151200",
        "evidenceWindowBlocks": "151200",
        "slashSink": SLASH_SINK,
        "devnet": True,
        "premint": [{account: str(amount)} for account, amount, _ in premint],
    }
    etna.update(STAKING)
    return {
        "contractOwner": OWNER,
        "chainId": CHAIN_ID,
        "l1ChainId": L1_CHAIN_ID,
        "usesBeaconRoots": True,
        "remoteSignalService": L1_SIGNAL_SERVICE,
        "contractAddresses": dict(ADDRESSES),
        "etna": etna,
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
                        "--l1-inbox", L1_INBOX,
                        "--l1-taiko-token", L1_TAIKO_TOKEN,
                        "--artifacts", str(inputs / "artifacts"),
                        "--output", str(args.output)], check=True)


if __name__ == "__main__":
    main()
