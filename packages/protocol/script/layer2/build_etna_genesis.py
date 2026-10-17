#!/usr/bin/env python3
"""Build an alloc-only Etna genesis from canonical devnet JSON and exported vault runtime.

Only alloc changes, except the derived top-level stateRoot is discarded. All other non-alloc
fields remain identical to canonical devnet JSON.
The pinned EL dependency (alethia-reth PR #251) supports this strict custom genesis with an
explicit Etna activation override, restores the canonical fork table and rebuilds its genesis
header/hash. The client harness checks the actual block-0 hash/root and installed runtimes.
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
    if not isinstance(value, str):
        raise ValueError("address must be a string")
    value = value.lower().removeprefix("0x")
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("alloc and Inbox addresses must contain exactly 20 hex bytes")
    return "0x" + value


def bytecode(value):
    """Require concrete nonempty hex; immutable binding is checked against the artifact below."""
    if not isinstance(value, str) or not re.fullmatch(r"0x(?:[0-9a-fA-F]{2})+", value):
        raise ValueError("runtime must be nonempty 0x-prefixed concrete bytecode")
    return value.lower()


VAULT_SOURCE = "contracts/layer2/core/L2FeeVault.sol"
VAULT_NAME = "L2FeeVault"


def vault_runtime(runtime, artifact):
    """Bind full runtime to a trusted same-profile compiler artifact and explicit L1 identity.

    The current source constructor only checks nonzero inputs and assigns the two immutables.
    This reconstructs those assignments, not arbitrary EVM constructor execution. The artifact
    must come from a trusted fresh local build, never from the untrusted runtime's producer.
    """
    chain = runtime["l1ChainId"]
    if not (type(chain) is int or isinstance(chain, str) and re.fullmatch(r"[0-9]+", chain)):
        raise ValueError("L1 chain ID must be a uint256 integer")
    chain = int(chain)
    inbox = int(address(runtime["l1Inbox"]), 16)
    if not 0 < chain < 2**256 or inbox == 0:
        raise ValueError("exported L1 chain and Inbox must be nonzero and fit their types")
    code = bytecode(runtime["runtime"])
    try:
        ast = artifact["ast"]
        if (ast["nodeType"] != "SourceUnit" or ast["absolutePath"] != VAULT_SOURCE
                or artifact["metadata"]["settings"]["compilationTarget"]
                != {VAULT_SOURCE: VAULT_NAME}):
            raise ValueError("artifact must target the trusted L2FeeVault source")
        contracts = [node for node in ast["nodes"]
                     if node["nodeType"] == "ContractDefinition" and node["name"] == VAULT_NAME]
        if len(contracts) != 1:
            raise ValueError("artifact must contain exactly one L2FeeVault definition")
        contract = contracts[0]
        if (type(contract["id"]) is not int or contract["id"] <= 0
                or contract["linearizedBaseContracts"] != [contract["id"]]
                or ast["exportedSymbols"][VAULT_NAME] != [contract["id"]]):
            raise ValueError("unexpected vault inheritance or AST identity")
        expected = {"l1ChainId": ("uint256", chain), "l1Inbox": ("address", inbox)}
        declarations = {}
        names = set()
        for node in contract["nodes"]:
            if node.get("mutability") != "immutable":
                continue
            name = node["name"]
            if (name not in expected or name in names or node["nodeType"] != "VariableDeclaration"
                    or node["stateVariable"] is not True or node["scope"] != contract["id"]
                    or node["typeDescriptions"]["typeString"] != expected[name][0]
                    or node["typeName"]["nodeType"] != "ElementaryTypeName"
                    or node["typeName"]["name"] != expected[name][0]
                    or type(node["id"]) is not int or node["id"] <= 0
                    or str(node["id"]) in declarations):
                raise ValueError("unexpected immutable declaration")
            names.add(name)
            declarations[str(node["id"])] = expected[name][1].to_bytes(32, "big")
        if names != expected.keys():
            raise ValueError("missing vault immutable declarations")
        deployed = artifact["deployedBytecode"]
        if deployed["linkReferences"] != {}:
            raise ValueError("vault artifact must not contain library links")
        template = bytearray.fromhex(bytecode(deployed["object"])[2:])
        references = deployed["immutableReferences"]
        if not isinstance(references, dict) or references.keys() != declarations.keys():
            raise ValueError("immutable references must cover exactly the declared vault identity")
        patches = []
        for ast_id, locations in references.items():
            if not isinstance(locations, list) or not locations:
                raise ValueError("immutable references must be nonempty lists")
            for location in locations:
                start, length = location["start"], location["length"]
                if (type(start) is not int or type(length) is not int or length != 32
                        or start < 0 or start + length > len(template)):
                    raise ValueError("immutable reference outside runtime or not a 32-byte word")
                patches.append((start, declarations[ast_id]))
        end = 0
        for start, value in sorted(patches):
            if start < end:
                raise ValueError("overlapping immutable references")
            template[start:start + 32] = value
            end = start + 32
    except (KeyError, TypeError, AttributeError, IndexError) as error:
        raise ValueError("malformed vault compiler artifact") from error
    if bytes(template) != bytes.fromhex(code[2:]):
        raise ValueError("exported runtime does not match artifact and L1 identity")
    return code


def build(base, runtime, artifact):
    """Replace alloc using validated code and discard the now-stale derived state root."""
    roots = bytecode(ROOTS_RUNTIME)
    if hashlib.sha256(bytes.fromhex(roots[2:])).hexdigest() != ROOTS_SHA256:
        raise ValueError("canonical EIP-4788 runtime hash mismatch")
    code = vault_runtime(runtime, artifact)
    chain_id = int(base["config"]["chainId"])
    prefix = str(chain_id)
    if chain_id <= 0 or len(prefix) > 35:
        raise ValueError("L2 chainId cannot form an EL treasury address")
    vault = "0x" + prefix + "0" * (40 - len(prefix) - 5) + "10001"
    genesis = copy.deepcopy(base)
    genesis.pop("stateRoot", None)
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
    parser.add_argument("--vault-artifact", type=Path, required=True,
                        help="trusted fresh layer2 L2FeeVault compiler JSON with AST and immutable references")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    write(build(load(args.base), load(args.runtime), load(args.vault_artifact)), args.output)


if __name__ == "__main__":
    main()
