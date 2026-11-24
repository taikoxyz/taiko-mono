#!/usr/bin/env python3
"""Build an alloc-only Etna genesis for a new network.

Only alloc changes, except the derived top-level stateRoot is discarded. All other non-alloc
fields remain identical to the base genesis JSON. The alloc gains the Taiko L2 predeploys that
`pnpm genesis:gen` generated for the Etna network, replacing any account at the same address, and
the canonical EIP-4788 and EIP-2935 system contracts.

The L2 SignalService must be the `EtnaSignalService`, which L1 also runs and which stores only state
roots, and the predeploy configuration must give it `usesBeaconRoots` = true (Etna SPEC
START-10-5): it then accepts a checkpoint only in a block whose own EIP-4788 root is zero, and on a
new network every block after genesis is an Etna block, with a nonzero root. A SignalService
without it keeps its checkpoint store open there, so anyone could save a forged L1 checkpoint
through `anchorV4` with the public golden touch key, and it never resolves proofs through EIP-4788.
No L2 contract holds the fork time. Its `remoteSignalService` must be the deployed L1 SignalService
passed as `--l1-signal-service`, which the L2 SignalService proves against. Predeploy accounts are
reduced to the fields execution clients accept (balance, nonce, code, storage), dropping the
generator's `contractName`, with storage keys and values written as 32-byte words.

The configuration file can disagree with the alloc, for example when it was edited without rerunning
the generator, so the same values are also checked in the emitted bytecode, against the artifacts in
`--artifacts` (`out/layer2`, written with their AST by `pnpm genesis:gen`). The Anchor and
SignalService proxy accounts must hold exactly the compiled `ERC1967Proxy` runtime and point at
their implementations. Each implementation's code must be the runtime of the compiled `Anchor` or
`EtnaSignalService`, differing only in immutables; these contracts link no library, so an artifact
with a library link is refused. Then the immutables are read at the compiler's offsets: the
SignalService's `usesBeaconRoots` must be true (a `bool` immutable is a 32-byte word, here 1), its
`_authorizedSyncer` the Anchor proxy and its `_remoteSignalService` the L1 SignalService, and the
Anchor's `checkpointStore` must be the SignalService proxy. Every other immutable of both
implementations is pinned to the value the generator writes (UUPS `__self` the implementation's own
address, the Anchor's `l1ChainId` the configured one, its resolver zero, the SignalService's
resolver the SharedResolver proxy and its `pauser` zero), and an immutable the builder does not know
is refused. The proxies' storage may hold only what the generator initializes: initialized, not
paused, the configured owner and the implementation slot. No predeploy address, nor an L1 address
passed to the builder, may be a precompile or system contract address, and no L1 address may be an
L2 predeploy.

A new Etna network also predeploys EtnaStaking and its stake token, bridged TAIKO, so the
configuration must carry the generator's `etna` block, with EtnaStaking at
`getConstantAddress(chainId, 10003)`, where the EL and the clients call it, and bridged TAIKO at
`getConstantAddress(chainId, 7)` (each implementation under the prefix "0" + chainId). A predeploy
runs no constructor, so the builder refuses what EtnaStaking's constructor refuses, in the
configuration and again in the immutables read from the bytecode, and a withdrawalDelay below
etna.unsettledLimit + 2 + etna.evidenceWindowBlocks. EtnaStaking's `inbox` must be `--l1-inbox`, its
`token` the bridged TAIKO proxy and its other immutables the configured values; the token's
`erc20Vault` must be the ERC20Vault proxy, which must map it to `--l1-taiko-token` on `l1ChainId`.
A premint, which is L2 TAIKO that no L1 TAIKO backs, needs `etna.devnet` true, which is refused on
chains 167000, 167009 and 167013, and may not exceed TAIKO's 10^27 supply. Outside a devnet the
staking owner, the DAO's execution address on L2, must hold code in the genesis. Both proxies may
hold only what deploying them and calling `init` writes, and the token also what minting the
premint writes: its balances, total supply and votes checkpoint. Both implementations may hold
only the `_initialized` 255 their constructors leave.

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
# Predeploys a new Etna network depends on. On the root path, the Anchor saves checkpoints before
# the fork, and the SignalService closes its checkpoint store and proves L1 signals against
# EIP-4788 roots from it; on a new network every block after genesis is an Etna block. The EL calls
# EtnaStaking at the start of every block, stakers bond bridged TAIKO, and the ERC20Vault's storage
# maps L1 TAIKO to it.
REQUIRED_PREDEPLOYS = (
    "TaikoAnchor", "TaikoAnchorImpl", "SignalService", "SignalServiceImpl",
    "EtnaStaking", "EtnaStakingImpl", "BridgedTaikoToken", "BridgedTaikoTokenImpl", "ERC20Vault",
)
# The generator's `getConstantAddress(prefix, suffix)` of each Etna predeploy, as (name, the prefix
# before the chain id, suffix).
ETNA_CONSTANT_ADDRESSES = (
    ("EtnaStaking", "", 10003), ("EtnaStakingImpl", "0", 10003),
    ("BridgedTaikoToken", "", 7), ("BridgedTaikoTokenImpl", "0", 7),
)
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
# false in slot 0, `_owner` in slot 51, and the flags in slot 201. The TaikoAnchor and SignalService
# proxies hold `__reentry` and `__paused` both 1 (false) there. The EtnaStaking and bridged TAIKO
# proxies hold what `init` writes, which sets only `__paused` (the reentry lock is transient).
INITIALIZED_SLOT = "0x" + format(0, "064x")
OWNER_SLOT = "0x" + format(51, "064x")
FLAGS_SLOT = "0x" + format(201, "064x")
LEGACY_FLAGS = "0x" + format(0x0101, "064x")
INIT_FLAGS = "0x" + format(0x0100, "064x")
ZERO_WORD = "0x" + "00" * 32
# An implementation's `_initialized` after its constructor's `_disableInitializers()`.
DISABLED_INITIALIZERS = "0x" + format(255, "064x")
# BridgedTaikoToken slots (ERC20, EIP712 and ERC20Votes upgradeable layouts): `_balances`,
# `_totalSupply`, the ERC-20 `_name` and `_symbol`, the EIP-712 `_name` and `_version`, and the
# `_totalSupplyCheckpoints` array.
BALANCES_SLOT = 301
TOTAL_SUPPLY_SLOT = 303
NAME_SLOT = 304
SYMBOL_SLOT = 305
EIP712_NAME_SLOT = 353
EIP712_VERSION_SLOT = 354
CHECKPOINTS_SLOT = 456
TOKEN_NAME = "Taiko Token"
TOKEN_SYMBOL = "TAIKO"
TOKEN_DECIMALS = 18
# The ERC20Vault's `bridgedToCanonical` and `canonicalToBridged` mappings.
BRIDGED_TO_CANONICAL_SLOT = 301
CANONICAL_TO_BRIDGED_SLOT = 302
# The bounds EtnaStaking's constructor enforces.
TAIKO_SUPPLY = 10**27
MAX_SEATS = 128
MIN_VP_UNIT = 867_361_738
BPS = 10_000
DELAY_BOUND = 2**48
# The Inbox's bound on its unsettledLimit.
MAX_UNSETTLED_LIMIT = 262_144
# EtnaStaking's numeric immutables, which the configuration gives as decimal strings.
STAKING_NUMBERS = ("minStake", "vpUnit", "nMax", "withdrawalDelay", "slashBountyBps",
                   "forfeitBps")
# The public Taiko networks, which must never hold the devnet premint's unbacked TAIKO.
PUBLIC_CHAIN_IDS = (167000, 167009, 167013)
# Keccak-f[1600] round constants and rotation offsets (by lane x, then y). The stdlib has no
# keccak256: hashlib's sha3_256 pads differently.
KECCAK_ROUND_CONSTANTS = (
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
)
KECCAK_ROTATIONS = (
    (0, 36, 3, 41, 18), (1, 44, 10, 45, 2), (62, 6, 43, 15, 61), (28, 55, 25, 21, 56),
    (27, 20, 39, 8, 14),
)


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


def number_word(value):
    """Return a non-negative integer as a 0x-prefixed 32-byte word."""
    return "0x" + format(value, "064x")


def keccak256(data):
    """Return Solidity's keccak256 of `data` as 32 bytes."""
    rate = 136
    padded = bytearray(data) + bytes(rate - len(data) % rate)
    padded[len(data)] ^= 0x01
    padded[-1] ^= 0x80
    lanes = [0] * 25
    for offset in range(0, len(padded), rate):
        for i in range(rate // 8):
            lanes[i] ^= int.from_bytes(padded[offset + 8 * i:offset + 8 * i + 8], "little")
        _keccak_f1600(lanes)
    return b"".join(lane.to_bytes(8, "little") for lane in lanes[:4])


def _keccak_f1600(lanes):
    """Apply the 24 Keccak-f[1600] rounds in place to the 25 lanes, lane x + 5y at (x, y)."""
    mask = (1 << 64) - 1

    def rotate(value, shift):
        return ((value << shift) | (value >> (64 - shift))) & mask

    for constant in KECCAK_ROUND_CONSTANTS:
        parity = [lanes[x] ^ lanes[x + 5] ^ lanes[x + 10] ^ lanes[x + 15] ^ lanes[x + 20]
                  for x in range(5)]
        for x in range(5):
            mixed = parity[(x - 1) % 5] ^ rotate(parity[(x + 1) % 5], 1)
            for y in range(0, 25, 5):
                lanes[x + y] ^= mixed
        moved = [0] * 25
        for x in range(5):
            for y in range(5):
                moved[y + 5 * ((2 * x + 3 * y) % 5)] = rotate(lanes[x + 5 * y],
                                                              KECCAK_ROTATIONS[x][y])
        for y in range(0, 25, 5):
            for x in range(5):
                lanes[x + y] = moved[x + y] ^ (~moved[(x + 1) % 5 + y] & moved[(x + 2) % 5 + y])
        lanes[0] ^= constant


def mapping_slot(key, slot):
    """Return the storage slot of a mapping entry: keccak256 of the key word, then the slot word."""
    return "0x" + keccak256(bytes.fromhex(key[2:]) + bytes.fromhex(slot[2:])).hex()


def short_string(text):
    """Return the storage word of a Solidity string of at most 31 bytes: the bytes left-aligned
    and twice the length in the lowest byte."""
    data = text.encode()
    return "0x" + (data + bytes(31 - len(data))).hex() + format(2 * len(data), "02x")


def constant_address(prefix, suffix):
    """Return the generator's `getConstantAddress(prefix, suffix)`: both numbers' decimal digits,
    zero-filled between them to 20 bytes."""
    prefix, suffix = str(prefix), str(suffix)
    return "0x" + prefix + "0" * (40 - len(prefix) - len(suffix)) + suffix


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


def l1_address(value, flag, predeploys, expected):
    """Normalize an L1 address flag, refusing a reserved address or an L2 predeploy's."""
    normalized = check_not_reserved(value, flag)
    if normalized in predeploys:
        raise ValueError(flag + " " + normalized + " is an L2 predeploy address; pass " + expected)
    return normalized


def nonzero_address(value, label):
    """Normalize a configured 20-byte address, refusing a missing or zero one."""
    if (not isinstance(value, str) or not re.fullmatch(r"(?:0x)?[0-9a-fA-F]{40}", value)
            or int(value[-40:], 16) == 0):
        raise ValueError("predeploy config: " + label + " must be a non-zero address")
    return address(value)


def decimal(value, label):
    """Parse a configured non-negative integer, which must be a decimal string, so that no amount
    passes through a lossy JSON number."""
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ValueError("predeploy config: " + label + " must be a decimal string")
    return int(value)


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


def check_predeploy_config(config, base, alloc, predeploys, l1_signal_service, l1_inbox,
                           l1_taiko_token):
    """Check that the generator configuration describes an Etna network matching the base, and
    return its `etna` block parsed."""
    uses_beacon_roots = config.get("usesBeaconRoots")
    if not isinstance(uses_beacon_roots, bool):
        raise ValueError("predeploy config: usesBeaconRoots must be a JSON boolean")
    if not uses_beacon_roots:
        raise ValueError(
            "predeploy config: usesBeaconRoots must be true on a new Etna network, or the "
            "checkpoint store stays open to the public golden touch key; set it in the Etna "
            "configuration, as test/genesis/data/genesis_config_etna.js does, and rerun "
            "`pnpm genesis:gen`"
        )
    l1 = l1_address(l1_signal_service, "--l1-signal-service", predeploys,
                    "the L1 SignalService that deployInboxProxy() deployed")
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
    if not isinstance(config.get("etna"), dict):
        raise ValueError("predeploy config: etna must be an object: a new Etna network predeploys "
                         "EtnaStaking and bridged TAIKO, as in "
                         "test/genesis/data/genesis_config_etna.js")
    addresses = config.get("contractAddresses", {})
    for name in REQUIRED_PREDEPLOYS + ("SharedResolver",):
        if name not in addresses:
            raise ValueError("predeploy config: no " + name + " address")
    for name in REQUIRED_PREDEPLOYS:
        check_not_reserved(addresses[name], "predeploy config: " + name)
        account = predeploys.get(address(addresses[name]))
        if not account or not account.get("code", "0x").removeprefix("0x"):
            raise ValueError("predeploys: no code at the configured " + name + " address")
    return check_etna_config(config, alloc, predeploys, l1_inbox, l1_taiko_token)


def check_staking_numbers(values, label, least_delay):
    """Refuse EtnaStaking parameters its constructor refuses, or a withdrawalDelay below
    `least_delay`. `label` prefixes each parameter's name in the diagnostic."""
    def in_range(name, low, high):
        if not low <= values[name] <= high:
            raise ValueError(label + name + " " + str(values[name]) + " is not in ["
                             + str(low) + ", " + str(high) + "]")

    in_range("nMax", 1, MAX_SEATS)
    if values["vpUnit"] < MIN_VP_UNIT:
        raise ValueError(label + "vpUnit " + str(values["vpUnit"]) + " is below "
                         + str(MIN_VP_UNIT))
    if values["minStake"] < values["vpUnit"]:
        raise ValueError(label + "minStake " + str(values["minStake"]) + " is below vpUnit "
                         + str(values["vpUnit"]))
    if values["minStake"] * values["nMax"] < TAIKO_SUPPLY:
        raise ValueError(label + "minStake " + str(values["minStake"]) + " times nMax "
                         + str(values["nMax"]) + " is below 10^27, TAIKO's supply")
    in_range("slashBountyBps", 0, BPS - 1)
    in_range("forfeitBps", 1, BPS)
    in_range("withdrawalDelay", 1, DELAY_BOUND - 1)
    # No single contract sees both the Inbox's unsettledLimit and the delay, so the deployment
    # checks the bound.
    if values["withdrawalDelay"] < least_delay:
        raise ValueError(label + "withdrawalDelay " + str(values["withdrawalDelay"]) + " is below "
                         "etna.unsettledLimit + 2 + etna.evidenceWindowBlocks = "
                         + str(least_delay))


def has_code(account_address, alloc, predeploys):
    """Whether the genesis gives `account_address` code, a predeploy replacing a base account."""
    account = predeploys.get(account_address, alloc.get(account_address))
    code = account.get("code") if isinstance(account, dict) else None
    return isinstance(code, str) and code.lower().removeprefix("0x") != ""


def check_etna_config(config, alloc, predeploys, l1_inbox, l1_taiko_token):
    """Check the `etna` block as the generator does, because a predeploy runs no constructor, and
    return it with addresses normalized and numbers as integers."""
    etna = config["etna"]
    inbox = l1_address(l1_inbox, "--l1-inbox", predeploys, "the Etna Inbox proxy on L1")
    taiko = l1_address(l1_taiko_token, "--l1-taiko-token", predeploys, "the TAIKO token on L1")
    params = {name: nonzero_address(etna.get(name), "etna." + name)
              for name in ("inbox", "l1TaikoToken", "stakingOwner", "slashSink")}
    if params["inbox"] != inbox:
        raise ValueError("predeploy config: etna.inbox must be the L1 Inbox " + l1_inbox
                         + " passed as --l1-inbox")
    if params["l1TaikoToken"] != taiko:
        raise ValueError("predeploy config: etna.l1TaikoToken must be the L1 TAIKO token "
                         + l1_taiko_token + " passed as --l1-taiko-token")
    for name in STAKING_NUMBERS + ("unsettledLimit", "evidenceWindowBlocks"):
        params[name] = decimal(etna.get(name), "etna." + name)
    if not 1 <= params["unsettledLimit"] <= MAX_UNSETTLED_LIMIT:
        raise ValueError("predeploy config: etna.unsettledLimit " + str(params["unsettledLimit"])
                         + " is not in [1, " + str(MAX_UNSETTLED_LIMIT) + "]")
    if params["evidenceWindowBlocks"] == 0:
        raise ValueError("predeploy config: etna.evidenceWindowBlocks must be positive")
    params["leastDelay"] = params["unsettledLimit"] + 2 + params["evidenceWindowBlocks"]
    check_staking_numbers(params, "predeploy config: etna.", params["leastDelay"])

    devnet = etna.get("devnet")
    if not isinstance(devnet, bool):
        raise ValueError("predeploy config: etna.devnet must be a JSON boolean")
    if devnet and config["chainId"] in PUBLIC_CHAIN_IDS:
        raise ValueError("predeploy config: etna.devnet is refused on chain "
                         + str(config["chainId"]))
    if not isinstance(etna.get("premint"), list):
        raise ValueError("predeploy config: etna.premint must be an array")
    premint = {}
    for entry in etna["premint"]:
        if not isinstance(entry, dict) or len(entry) != 1:
            raise ValueError("predeploy config: each etna.premint entry must be one "
                             "{address: amount} pair")
        [(key, value)] = entry.items()
        account = nonzero_address(key, "an etna.premint account")
        if account in premint:
            raise ValueError("predeploy config: etna.premint lists " + account + " twice")
        premint[account] = decimal(value, "etna.premint amount of " + account)
        if premint[account] == 0:
            raise ValueError("predeploy config: etna.premint amount of " + account
                             + " must be positive")
    if premint and not devnet:
        raise ValueError("predeploy config: etna.premint needs etna.devnet true: it mints L2 "
                         "TAIKO that no L1 TAIKO backs")
    if sum(premint.values()) > TAIKO_SUPPLY:
        raise ValueError("predeploy config: etna.premint totals " + str(sum(premint.values()))
                         + ", above 10^27, TAIKO's supply")
    params["premint"] = premint

    for name, prefix, suffix in ETNA_CONSTANT_ADDRESSES:
        configured = address(config["contractAddresses"][name])
        expected = constant_address(prefix + str(config["chainId"]), suffix)
        if configured != expected:
            raise ValueError("predeploy config: " + name + " " + configured + " is not "
                             "getConstantAddress(" + prefix + str(config["chainId"]) + ", "
                             + str(suffix) + ") = " + expected + ", where the EL and the "
                             "clients expect it")
    # The staking token is the BridgedTaikoToken proxy. A bridged token may refuse transfers to
    # its own address, so the constructor refuses it as the slash sink.
    token = address(config["contractAddresses"]["BridgedTaikoToken"])
    if params["slashSink"] == token:
        raise ValueError("predeploy config: etna.slashSink must not be the staking token, the "
                         "BridgedTaikoToken proxy " + token)
    if not devnet and not has_code(params["stakingOwner"], alloc, predeploys):
        raise ValueError("predeploy config: etna.stakingOwner " + params["stakingOwner"]
                         + " holds no code in the genesis; outside a devnet it must be the DAO's "
                         "execution address on L2, a contract")
    return params


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


def check_storage(label, account, expected):
    """Allow only the `expected` storage words; any other non-zero word is refused."""
    storage = account.get("storage", {})
    for slot in sorted(set(storage) | set(expected)):
        actual = storage.get(slot, ZERO_WORD)
        wanted = expected.get(slot, ZERO_WORD)
        if actual != wanted:
            raise ValueError("predeploys: " + label + " storage slot " + slot + " is " + actual
                             + ", not " + wanted + " as `pnpm genesis:gen` writes it")


def check_proxy_storage(name, account, implementation, owner, flags, extra=None):
    """Allow only the storage the generator writes into a proxy, with `flags` in slot 201 and any
    `extra` words; any other non-zero word, such as a seeded received signal, checkpoint or pause
    flag, is refused."""
    expected = {
        INITIALIZED_SLOT: number_word(1),
        OWNER_SLOT: address_word(owner),
        FLAGS_SLOT: flags,
        IMPLEMENTATION_SLOT: address_word(implementation),
    }
    expected.update(extra or {})
    if account.get("storage", {}).get(IMPLEMENTATION_SLOT) != expected[IMPLEMENTATION_SLOT]:
        raise ValueError("predeploys: the " + name + " proxy does not point at the configured "
                         + name + "Impl")
    check_storage("the " + name + " proxy's", account, expected)


def read_immutables(code, artifacts, name, contract, immutables):
    """Return the words of `contract`'s `immutables` in `name`'s code, by immutable name, refusing
    an immutable of `contract` that `immutables` does not list."""
    artifact = artifacts.get(contract)
    words, checked = {}, set()
    for declaring, immutable, _ in immutables:
        reference_id = immutable_id(artifacts, declaring, immutable)
        checked.add(reference_id)
        words[immutable] = immutable_word(code, artifact, reference_id, name + " " + immutable)
    unchecked = sorted(set(artifact["deployedBytecode"].get("immutableReferences", {})) - checked)
    if unchecked:
        raise ValueError("artifacts: " + contract + " has immutables the builder does not "
                         "check (AST ids " + ", ".join(unchecked) + "); extend "
                         "build_etna_genesis.py before using it")
    return words


def pin_immutables(name, words, immutables):
    """Require each immutable word to be its expected value, in the order `immutables` lists."""
    for _, immutable, value in immutables:
        if words[immutable] != value:
            raise ValueError("predeploys: " + name + " " + immutable + " is " + words[immutable]
                             + ", not " + value + "; if the configuration changed, rerun "
                             "`pnpm genesis:gen` so the alloc matches it")


def check_predeploy_code(config, predeploys, artifacts, l1_signal_service, etna):
    """Check the Etna root path and the Etna predeploys in the emitted bytecode rather than in the
    configuration."""
    addresses = {name: address(config["contractAddresses"][name])
                 for name in REQUIRED_PREDEPLOYS + ("SharedResolver",)}
    for proxy in ("TaikoAnchor", "SignalService"):
        # Calls land at the proxy, so its code must be the plain proxy, not an implementation.
        runtime_code(predeploys[addresses[proxy]], artifacts, "ERC1967Proxy", proxy)
        check_proxy_storage(proxy, predeploys[addresses[proxy]], addresses[proxy + "Impl"],
                            config["contractOwner"], LEGACY_FLAGS)
    expected = (
        ("TaikoAnchorImpl", "Anchor", (
            ("UUPSUpgradeable", "__self", address_word(addresses["TaikoAnchorImpl"])),
            ("EssentialContract", "__resolver", ZERO_WORD),
            ("Anchor", "checkpointStore", address_word(addresses["SignalService"])),
            ("Anchor", "l1ChainId", "0x" + format(config["l1ChainId"], "064x")),
        )),
        # `usesBeaconRoots` first: an alloc generated with `false` is named by the immutable that
        # keeps the checkpoint store open, whatever else differs. A `bool` immutable is a 32-byte
        # word, 1 for true. EtnaSignalService inherits the other immutables from SignalService.
        ("SignalServiceImpl", "EtnaSignalService", (
            ("EtnaSignalService", "usesBeaconRoots", "0x" + format(1, "064x")),
            ("UUPSUpgradeable", "__self", address_word(addresses["SignalServiceImpl"])),
            ("EssentialContract", "__resolver", address_word(addresses["SharedResolver"])),
            ("SignalService", "_authorizedSyncer", address_word(addresses["TaikoAnchor"])),
            ("SignalService", "_remoteSignalService", address_word(l1_signal_service)),
            ("SignalService", "pauser", ZERO_WORD),
        )),
    )
    for name, contract, immutables in expected:
        code = runtime_code(predeploys[addresses[name]], artifacts, contract, name)
        pin_immutables(name, read_immutables(code, artifacts, name, contract, immutables),
                       immutables)
    check_etna_predeploys(config, predeploys, artifacts, addresses, etna)


def token_storage(etna):
    """Return the bridged TAIKO proxy's words beyond the proxy's own, as `init` and minting the
    premint leave them: the ERC-20 and EIP-712 names, symbol and version, and the balances, the
    total supply and, with a premint, one total-supply checkpoint (fromBlock 0, the premint's
    votes above it)."""
    total = sum(etna["premint"].values())
    words = {
        number_word(TOTAL_SUPPLY_SLOT): number_word(total),
        number_word(NAME_SLOT): short_string(TOKEN_NAME),
        number_word(SYMBOL_SLOT): short_string(TOKEN_SYMBOL),
        number_word(EIP712_NAME_SLOT): short_string(TOKEN_NAME),
        number_word(EIP712_VERSION_SLOT): short_string("1"),
    }
    for account, amount in etna["premint"].items():
        words[mapping_slot(address_word(account), number_word(BALANCES_SLOT))] = number_word(amount)
    if total:
        words[number_word(CHECKPOINTS_SLOT)] = number_word(1)
        words["0x" + keccak256(bytes.fromhex(number_word(CHECKPOINTS_SLOT)[2:])).hex()] = (
            number_word(total << 32))
    return words


def check_vault_mapping(vault, token, l1_chain_id, l1_taiko_token):
    """Require the ERC20Vault to map the bridged TAIKO predeploy to L1 TAIKO both ways, as the
    generator writes it: `bridgedToCanonical[token]` (the chain id, address and decimals packed in
    one word, then the symbol and the name) and `canonicalToBridged[l1ChainId][L1 TAIKO]`."""
    struct = mapping_slot(address_word(token), number_word(BRIDGED_TO_CANONICAL_SLOT))
    reverse = mapping_slot(number_word(l1_chain_id), number_word(CANONICAL_TO_BRIDGED_SLOT))
    expected = {
        struct: number_word(TOKEN_DECIMALS << 224 | int(l1_taiko_token, 16) << 64 | l1_chain_id),
        number_word((int(struct, 16) + 1) % 2**256): short_string(TOKEN_SYMBOL),
        number_word((int(struct, 16) + 2) % 2**256): short_string(TOKEN_NAME),
        mapping_slot(address_word(l1_taiko_token), reverse): address_word(token),
    }
    storage = vault.get("storage", {})
    for slot, wanted in expected.items():
        actual = storage.get(slot, ZERO_WORD)
        if actual != wanted:
            raise ValueError("predeploys: the ERC20Vault must map the bridged TAIKO predeploy to "
                             "the L1 TAIKO token " + l1_taiko_token + " on chain "
                             + str(l1_chain_id) + ", but its storage slot " + slot + " is "
                             + actual + ", not " + wanted)


def check_etna_predeploys(config, predeploys, artifacts, addresses, etna):
    """Check the EtnaStaking and bridged TAIKO accounts against what deploying and initializing
    them leaves, and the ERC20Vault's mapping to the token."""
    proxies = (("EtnaStaking", etna["stakingOwner"], None),
               ("BridgedTaikoToken", config["contractOwner"], token_storage(etna)))
    for proxy, owner, extra in proxies:
        runtime_code(predeploys[addresses[proxy]], artifacts, "ERC1967Proxy", proxy)
        check_proxy_storage(proxy, predeploys[addresses[proxy]], addresses[proxy + "Impl"], owner,
                            INIT_FLAGS, extra)
    staking = (
        ("EtnaStaking", "token", address_word(addresses["BridgedTaikoToken"])),
        ("EtnaStaking", "l1ChainId", number_word(config["l1ChainId"])),
        ("EtnaStaking", "inbox", address_word(etna["inbox"])),
        *(("EtnaStaking", name, number_word(etna[name])) for name in STAKING_NUMBERS),
        ("EtnaStaking", "slashSink", address_word(etna["slashSink"])),
        ("UUPSUpgradeable", "__self", address_word(addresses["EtnaStakingImpl"])),
        ("EssentialContract", "__resolver", ZERO_WORD),
    )
    token = (
        ("BridgedTaikoToken", "erc20Vault", address_word(addresses["ERC20Vault"])),
        ("UUPSUpgradeable", "__self", address_word(addresses["BridgedTaikoTokenImpl"])),
        ("EssentialContract", "__resolver", ZERO_WORD),
    )
    for name, contract, immutables in (("EtnaStakingImpl", "EtnaStaking", staking),
                                       ("BridgedTaikoTokenImpl", "BridgedTaikoToken", token)):
        account = predeploys[addresses[name]]
        code = runtime_code(account, artifacts, contract, name)
        words = read_immutables(code, artifacts, name, contract, immutables)
        if contract == "EtnaStaking":
            # The constructor's bounds first, so an alloc no constructor would deploy is named
            # by the bound it breaks.
            check_staking_numbers({number: int(words[number], 16) for number in STAKING_NUMBERS},
                                  "predeploys: EtnaStakingImpl ", etna["leastDelay"])
        pin_immutables(name, words, immutables)
        check_storage(name + "'s", account, {INITIALIZED_SLOT: DISABLED_INITIALIZERS})
    check_vault_mapping(predeploys[addresses["ERC20Vault"]], addresses["BridgedTaikoToken"],
                        config["l1ChainId"], etna["l1TaikoToken"])


def build(base, predeploys, predeploy_config, l1_signal_service, l1_inbox, l1_taiko_token,
          artifacts=DEFAULT_ARTIFACTS):
    """Overlay the predeploys, install the system contracts and drop the stale state root."""
    genesis = copy.deepcopy(base)
    genesis.pop("stateRoot", None)
    alloc = normalized_alloc(genesis.get("alloc", {}), "alloc")
    overlay = {
        key: genesis_account(account, "predeploy " + key)
        for key, account in normalized_alloc(copy.deepcopy(predeploys), "predeploy").items()
    }
    etna = check_predeploy_config(predeploy_config, genesis, alloc, overlay, l1_signal_service,
                                  l1_inbox, l1_taiko_token)
    check_predeploy_code(predeploy_config, overlay, Artifacts(artifacts), l1_signal_service, etna)
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
        "--l1-inbox", required=True,
        help="the deployed Etna Inbox proxy on L1 (INBOX_PROXY from deployInboxProxy()), which "
             "EtnaStaking's chain domain binds",
    )
    parser.add_argument(
        "--l1-taiko-token", required=True,
        help="the TAIKO token on L1, which the L2 ERC20Vault maps to the bridged TAIKO predeploy",
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
            args.l1_signal_service, args.l1_inbox, args.l1_taiko_token, args.artifacts,
        )
        write(genesis, args.output)
    except (OSError, ValueError) as error:
        sys.exit("build_etna_genesis.py: error: " + str(error))


if __name__ == "__main__":
    main()
