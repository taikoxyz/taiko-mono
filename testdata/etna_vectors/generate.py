#!/usr/bin/env python3
"""Regenerates testdata/etna_vectors/vectors.json (schema "4").

Run from the repository root with Foundry's `cast` and Go on PATH and the workspace's pnpm
dependencies installed (the output is formatted with the repository's prettier):

    python3 testdata/etna_vectors/generate.py

Every ABI encoding, hash and storage slot below is computed by `cast` (`abi-encode`, `keccak`,
`index`, `index-erc7201`, `format-bytes32-string`, `sig`, `calldata`, `wallet address`),
independently of the Solidity contracts and of taiko-client-rs, which both read the output. The
secp256k1 public keys come from a small pure-Python helper and are cross-checked against
`cast wallet address`; key decompression follows appendix A and is checked against the curve
equation. Proof-of-possession signatures come from `cast wallet sign --no-hash`, are checked with
`cast wallet verify` and a pure-Python ecrecover, and each digest is checked against cast's own
EIP-712 hashing (`cast wallet sign --data`). Vote sign bytes and their secp256k1eth signatures come
from stock CometBFT v0.40.0 (`votegen/`, run with `go run`); each sign-byte string must equal a
separate Python encoder written from appendix A, and each signature must recover to the key's
address over keccak256 of the sign bytes and equal cast's signature of that digest. Forced-inclusion
eligibility cases (spec 7.2) are RLP-encoded in Python and signed with `cast wallet sign --no-hash`
over `cast keccak` signing hashes (EIP-7702 tuples must equal `cast wallet sign-auth`); each case is
classified again from its bytes, an ineligible case must break only the rule it is labelled with,
and the written file is checked against go-ethereum v1.15.5 (`ficheck/`, run with `go run`). Only
the inputs, the packing table and the storage slot numbers are written by hand, following the Etna
spec's appendix A (encodings) and appendix B (storage layout). All integers are decimal strings so
that every value survives JSON parsing exactly.
"""

import base64
import functools
import json
import os
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUTPUT = HERE / "vectors.json"

WORD_MOD = 2**256
U48_MAX = 2**48 - 1
NO_EXIT = U48_MAX  # exitEffectiveL1 = 2^48 - 1 means no exit is set
K = 6  # landing grid interval

# secp256k1 curve parameters (SEC 2).
SECP_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
SECP_G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)

DEPLOYMENT = {
    "l1_chain_id": 1,
    "l2_chain_id": 167001,
    "inbox": "0x1111111111111111111111111111111111111111",
    "registry": "0x2222222222222222222222222222222222222222",
    "l2_block_gas_limit": 45_000_000,
}
OTHER_INBOX = "0x3333333333333333333333333333333333333333"

# Registration (spec 4.1, appendix A): EIP-712 domain and type, and the two registering owners.
EIP712_DOMAIN_TYPE = (
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)
EIP712_NAME = "EtnaStakingRegistry"
EIP712_VERSION = "1"
REGISTER_TYPE = "Register(address owner)"
OWNERS = ("0x" + "aa" * 20, "0x" + "bb" * 20)


def cast(*args):
    return subprocess.check_output(["cast", *map(str, args)], text=True).strip()


def keccak(data):
    return cast("keccak", data)


def abi_encode(signature, *args):
    return cast("abi-encode", signature, *args)


def tag(name):
    """A right-padded `bytes32` domain tag."""
    return cast("format-bytes32-string", name)


def word(value):
    """A 32-byte big-endian word."""
    return "0x" + format(value % WORD_MOD, "064x")


def concat(*hexes):
    return "0x" + "".join(h[2:] for h in hexes)


def dec(value):
    return str(value)


def decimals(value):
    """`value` with every integer, at any depth, as a decimal string (booleans stay booleans)."""
    if isinstance(value, dict):
        return {k: decimals(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decimals(v) for v in value]
    if isinstance(value, (bool, str)):
        return value
    return dec(value)


# --- secp256k1 -----------------------------------------------------------------------------------


def _add(a, b):
    """Affine point addition; `None` is the point at infinity."""
    if a is None:
        return b
    if b is None:
        return a
    (x1, y1), (x2, y2) = a, b
    if x1 == x2 and (y1 + y2) % SECP_P == 0:
        return None
    if a == b:
        slope = 3 * x1 * x1 * pow(2 * y1, -1, SECP_P) % SECP_P
    else:
        slope = (y2 - y1) * pow(x2 - x1, -1, SECP_P) % SECP_P
    x3 = (slope * slope - x1 - x2) % SECP_P
    return x3, (slope * (x1 - x3) - y1) % SECP_P


def _mul(addend, k):
    """`k·addend` by double-and-add; `k = 0` gives the point at infinity."""
    result = None
    while k:
        if k & 1:
            result = _add(result, addend)
        addend = _add(addend, addend)
        k >>= 1
    return result


def point(k):
    """`k·G`."""
    assert 1 <= k < SECP_N
    return _mul(SECP_G, k)


def compress(x, y):
    """SEC1 compressed encoding: `0x02 | (y & 1)` followed by the 32-byte big-endian X."""
    return bytes([2 + (y & 1)]) + x.to_bytes(32, "big")


def on_curve(x, y):
    return 0 <= x < SECP_P and 0 <= y < SECP_P and (y * y - x**3 - 7) % SECP_P == 0


def decompress(public_key):
    """Appendix A: `(ckX, ckY)` of a 33-byte `ckPrefix || ckX`, or `None` when it is rejected.

    X is never reduced mod p; `y0 = (x^3 + 7)^((p + 1) / 4)` must square back to `x^3 + 7`, and the
    root with the prefix's parity is taken.
    """
    if len(public_key) != 33 or public_key[0] not in (2, 3):
        return None
    x = int.from_bytes(public_key[1:], "big")
    if x >= SECP_P:
        return None
    a = (x**3 + 7) % SECP_P
    y0 = pow(a, (SECP_P + 1) // 4, SECP_P)
    if y0 * y0 % SECP_P != a:
        return None
    y = y0 if y0 % 2 == public_key[0] - 2 else SECP_P - y0
    assert on_curve(x, y) and y & 1 == public_key[0] - 2
    assert compress(x, y) == public_key
    return x, y


def address_of(x, y):
    """`keccak256(uint256_be(x) || uint256_be(y))[12:]`."""
    return "0x" + keccak(concat(word(x), word(y)))[-40:]


def ecrecover(digest, r, s, v):
    """`ecrecover(digest, v + 27, r, s)` for V in {0, 1}: the signer address, or `None` (zero)."""
    if not (0 < r < SECP_N and 0 < s < SECP_N and v in (0, 1)):
        return None
    big_r = decompress(bytes([2 + v]) + r.to_bytes(32, "big"))
    if big_r is None:
        return None
    r_inv = pow(r, -1, SECP_N)
    z = int(digest, 16)
    q = _add(_mul(big_r, s * r_inv % SECP_N), _mul(SECP_G, -z * r_inv % SECP_N))
    return None if q is None else address_of(*q)


# --- deployment and keys -------------------------------------------------------------------------


def deployment():
    return decimals(DEPLOYMENT)


def leading_zero_x_scalar():
    """The first scalar k >= 1 whose public key X has a zero top byte."""
    k, current = 1, SECP_G
    while current[0] >> 248:
        k += 1
        current = _add(current, SECP_G)
    assert point(k) == current
    return k


def keys():
    """Consensus keys 0xA1..0xA5 plus the first key whose X starts with a zero byte."""
    scalars = [(f"a{i}", 0xA0 + i) for i in range(1, 6)]
    scalars.append(("leading_zero_x", leading_zero_x_scalar()))
    out = []
    for name, k in scalars:
        x, y = point(k)
        private_key = word(k)
        ck_x, ck_y = word(x), word(y)
        ck_prefix = 2 + (y & 1)
        ck_addr = "0x" + keccak(concat(ck_x, ck_y))[-40:]
        assert ck_addr == cast("wallet", "address", "--private-key", private_key).lower(), name
        out.append(
            {
                "name": name,
                "private_key": private_key,
                "public_key": "0x" + compress(x, y).hex(),
                "ck_prefix": ck_prefix,
                "ck_x": ck_x,
                "ck_y": ck_y,
                "ck_addr": ck_addr,
                "entry_key": keccak(abi_encode("f(uint256,bytes32)", ck_prefix, ck_x)),
            }
        )
    return decimals(out)


# --- key decompression and registration PoPs -----------------------------------------------------


def smallest_off_curve_x():
    """The smallest X >= 1 that is not the X of any curve point."""
    x = 1
    while decompress(bytes([2]) + x.to_bytes(32, "big")) is not None:
        x += 1
    return x


def key_decompression(key_list):
    """Each key decoded from its own prefix and from the other one (the negated point), and the
    inputs registration rejects. The malformed encodings reuse key a1's coordinates."""
    cases = []
    for key in key_list:
        x, y = int(key["ck_x"], 16), int(key["ck_y"], 16)
        own = compress(x, y)
        flipped = bytes([own[0] ^ 1]) + own[1:]
        for name, public_key, expected_y in (
            (key["name"], own, y),
            ("parity_flip_" + key["name"], flipped, SECP_P - y),
        ):
            decoded = decompress(public_key)
            assert decoded == (x, expected_y), name
            ck_addr = address_of(x, expected_y)
            assert (ck_addr == key["ck_addr"]) == (public_key == own), name
            cases.append(
                {
                    "name": name,
                    "public_key": "0x" + public_key.hex(),
                    "valid": True,
                    "ck_y": word(expected_y),
                    "ck_addr": ck_addr,
                }
            )

    base = key_list[0]
    x, y = int(base["ck_x"], 16), int(base["ck_y"], 16)
    x_bytes, xy = x.to_bytes(32, "big"), x.to_bytes(32, "big") + y.to_bytes(32, "big")
    off_curve_x = smallest_off_curve_x()
    # X is not reduced mod p: X = p would reduce to 0 (no point), X = 2^256 - 1 onto the curve.
    assert decompress(bytes([2]) + ((WORD_MOD - 1) % SECP_P).to_bytes(32, "big")) is not None
    rejected = (
        ("x_eq_p", bytes([2]) + SECP_P.to_bytes(32, "big"), "x_ge_p"),
        ("x_max", bytes([3]) + (WORD_MOD - 1).to_bytes(32, "big"), "x_ge_p"),
        ("not_on_curve", bytes([2]) + off_curve_x.to_bytes(32, "big"), "not_on_curve"),
        ("prefix_00", bytes([0]) + x_bytes, "bad_prefix"),
        ("prefix_01", bytes([1]) + x_bytes, "bad_prefix"),
        ("prefix_04", bytes([4]) + x_bytes, "bad_prefix"),
        ("uncompressed_65", bytes([4]) + xy, "uncompressed"),
        ("uncompressed_64", xy, "uncompressed"),
        ("hybrid_06", bytes([6]) + xy, "hybrid"),
        ("hybrid_07", bytes([7]) + xy, "hybrid"),
        ("trailing_byte", compress(x, y) + bytes(1), "trailing_bytes"),
        ("short_32", x_bytes, "short"),
        ("empty", b"", "empty"),
    )
    for name, public_key, reason in rejected:
        assert decompress(public_key) is None, name
        cases.append(
            {"name": name, "public_key": "0x" + public_key.hex(), "valid": False, "reason": reason}
        )
    return cases


@functools.cache
def keccak_text(text):
    """keccak256 of a UTF-8 string."""
    assert not text.startswith("0x"), text
    return cast("keccak", text)


@functools.cache
def register_digest(chain_id, registry, owner):
    """`(domainSeparator, structHash, digest)` of the EIP-712 `Register(address owner)` message."""
    domain_separator = keccak(
        abi_encode(
            "f(bytes32,bytes32,bytes32,uint256,address)",
            keccak_text(EIP712_DOMAIN_TYPE),
            keccak_text(EIP712_NAME),
            keccak_text(EIP712_VERSION),
            chain_id,
            registry,
        )
    )
    struct_hash = keccak(abi_encode("f(bytes32,address)", keccak_text(REGISTER_TYPE), owner))
    return domain_separator, struct_hash, keccak(concat("0x1901", domain_separator, struct_hash))


def typed_data(chain_id, registry, owner):
    """The same message as EIP-712 typed data, for cast's own hashing."""
    return json.dumps(
        {
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"},
                ],
                "Register": [{"name": "owner", "type": "address"}],
            },
            "primaryType": "Register",
            "domain": {
                "name": EIP712_NAME,
                "version": EIP712_VERSION,
                "chainId": chain_id,
                "verifyingContract": registry,
            },
            "message": {"owner": owner},
        }
    )


def split_sig(sig):
    raw = bytes.fromhex(sig[2:])
    assert len(raw) == 65, sig
    return int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:64], "big"), raw[64]


def join_sig(r, s, v):
    """65-byte `R || S || V`."""
    return "0x" + r.to_bytes(32, "big").hex() + s.to_bytes(32, "big").hex() + bytes([v]).hex()


def sign_registration(key, chain_id, registry, owner):
    """A PoP by `key` for `register_digest(chain_id, registry, owner)`, checked three ways.

    `cast wallet sign --no-hash` signs the digest (RFC 6979, low s); V is rewritten from 27/28 to
    0/1. The signature must equal cast's EIP-712 signature of the same typed data (so the digest is
    cast's EIP-712 hash), pass `cast wallet verify`, and recover to `ck_addr` in pure Python.
    """
    domain_separator, struct_hash, digest = register_digest(chain_id, registry, owner)
    private_key = key["private_key"]
    signed = cast("wallet", "sign", "--no-hash", "--private-key", private_key, digest)
    typed = typed_data(chain_id, registry, owner)
    assert signed == cast("wallet", "sign", "--data", typed, "--private-key", private_key)
    subprocess.run(
        ["cast", "wallet", "verify", "--no-hash", "--address", key["ck_addr"], digest, signed],
        check=True,
        capture_output=True,
    )
    r, s, v = split_sig(signed)
    assert v in (27, 28) and 0 < r < SECP_N and 0 < s <= SECP_N // 2
    assert ecrecover(digest, r, s, v - 27) == key["ck_addr"]
    return {
        "domain_separator": domain_separator,
        "struct_hash": struct_hash,
        "digest": digest,
        "pop_sig": join_sig(r, s, v - 27),
    }


def register_digests(key_list):
    """Every key's PoP for both owners at the deployment registry on the deployment L1 chain."""
    chain_id, registry = DEPLOYMENT["l1_chain_id"], DEPLOYMENT["registry"]
    out = []
    for key in key_list:
        for owner in OWNERS:
            signed = sign_registration(key, chain_id, registry, owner)
            out.append(
                {
                    "name": f"{key['name']}_owner_{owner[-2:]}",
                    "l1_chain_id": chain_id,
                    "registry": registry,
                    "owner": owner,
                    "key": key["public_key"],
                    **signed,
                }
            )
    return decimals(out)


def pop_accepted(public_key, owner, pop_sig):
    """Spec 4.1 at the deployment registry: does a registration by `owner` accept this PoP?"""
    decoded = decompress(bytes.fromhex(public_key[2:]))
    raw = bytes.fromhex(pop_sig[2:])
    if decoded is None or len(raw) != 65:
        return False
    r, s, v = split_sig(pop_sig)
    if v not in (0, 1) or not 0 < r < SECP_N or not 0 < s <= SECP_N // 2:
        return False
    _, _, digest = register_digest(DEPLOYMENT["l1_chain_id"], DEPLOYMENT["registry"], owner)
    signer = ecrecover(digest, r, s, v)
    return signer is not None and signer == address_of(*decoded)


def pop_rejections(key_list, digests):
    """PoPs that a registration by `owner` at the deployment registry rejects; every key decodes.

    The malformed signatures derive from one valid PoP whose V is 0 (so `v_27` is that signature in
    the 27/28 form and `length_64` is also its EIP-2098 compact form). The binding cases are
    well-formed signatures for another owner, key, chain id (the L2 chain id) or verifying contract
    (the Inbox), or for the point with the same X and the other parity.
    """
    base = next(c for c in digests if c["owner"] == OWNERS[0] and c["pop_sig"].endswith("00"))
    (key,) = [k for k in key_list if k["public_key"] == base["key"]]
    other_key = next(k for k in key_list if k["public_key"] != base["key"])
    owner, other_owner = OWNERS
    public_key, sig = base["key"], base["pop_sig"]
    r, s, v = split_sig(sig)
    digest = base["digest"]
    flipped = "0x" + bytes([bytes.fromhex(public_key[2:4])[0] ^ 1]).hex() + public_key[4:]
    unrecoverable_r = smallest_off_curve_x()
    wrong_chain = sign_registration(key, DEPLOYMENT["l2_chain_id"], DEPLOYMENT["registry"], owner)
    wrong_registry = sign_registration(key, DEPLOYMENT["l1_chain_id"], DEPLOYMENT["inbox"], owner)
    assert digest not in (wrong_chain["digest"], wrong_registry["digest"])
    # The malleated twin is a valid ECDSA signature of the same key; only the low-s rule rejects it.
    assert ecrecover(digest, r, SECP_N - s, 1 - v) == key["ck_addr"]
    assert ecrecover(digest, unrecoverable_r, s, v) is None
    cases = (
        ("v_27", public_key, owner, join_sig(r, s, 27)),
        ("v_2", public_key, owner, join_sig(r, s, 2)),
        ("high_s", public_key, owner, join_sig(r, SECP_N - s, 1 - v)),
        ("r_zero", public_key, owner, join_sig(0, s, v)),
        ("s_zero", public_key, owner, join_sig(r, 0, v)),
        ("r_eq_n", public_key, owner, join_sig(SECP_N, s, v)),
        ("unrecoverable_r", public_key, owner, join_sig(unrecoverable_r, s, v)),
        ("length_64", public_key, owner, sig[:-2]),
        ("length_66", public_key, owner, sig + "00"),
        ("wrong_owner", public_key, other_owner, sig),
        ("wrong_key", other_key["public_key"], owner, sig),
        ("wrong_chain", public_key, owner, wrong_chain["pop_sig"]),
        ("wrong_registry", public_key, owner, wrong_registry["pop_sig"]),
        ("parity_flip", flipped, owner, sig),
    )
    out = []
    for name, case_key, case_owner, pop_sig in cases:
        assert decompress(bytes.fromhex(case_key[2:])) is not None, name
        assert not pop_accepted(case_key, case_owner, pop_sig), name
        out.append(
            {
                "name": name,
                "public_key": case_key,
                "owner": case_owner,
                "pop_sig": pop_sig,
                "reason": name,
            }
        )
    assert v == 0 and pop_accepted(public_key, owner, sig)
    return out


# --- committee configuration, registry entries, committee sets -----------------------------------


def committee_config():
    """`committeeConfigHash`: seven static words (224 bytes)."""
    inputs = {
        "tag": "ETNA_PARENT_ANCHOR_V1",
        "l2_chain_id": DEPLOYMENT["l2_chain_id"],
        "registry": DEPLOYMENT["registry"],
        "vp_unit": 10**9,
        "s_min": 10**18,
        "n_max": 128,
        "unsettled_limit": 3600,
    }
    preimage = abi_encode(
        "f(bytes32,uint256,address,uint256,uint256,uint256,uint256)",
        tag(inputs["tag"]),
        inputs["l2_chain_id"],
        inputs["registry"],
        inputs["vp_unit"],
        inputs["s_min"],
        inputs["n_max"],
        inputs["unsettled_limit"],
    )
    return {"inputs": decimals(inputs), "preimage": preimage, "hash": keccak(preimage)}


def reg_leaf(index, entry):
    return keccak(
        abi_encode(
            "f(bytes32,uint256,uint256,bytes32,uint256,uint256,uint256)",
            tag("ETNA_REG_ENTRY_V1"),
            index,
            entry["ck_prefix"],
            entry["ck_x"],
            entry["eff_stake"],
            entry["active_from_l1"],
            entry["exit_effective_l1"],
        )
    )


def entries_root(leaves):
    """Leaves zero-padded to a power of two, inner nodes keccak256(left || right); none gives 0."""
    if not leaves:
        return word(0)
    width = 1
    while width < len(leaves):
        width *= 2
    level = leaves + [word(0)] * (width - len(leaves))
    while len(level) > 1:
        level = [keccak(concat(level[j], level[j + 1])) for j in range(0, len(level), 2)]
    return level[0]


def registry_entries(key_list):
    """Entries 0..4 from keys a1..a5, their leaves, a released slot 5 and every prefix root.

    Entry `i`: `i + 1` TAIKO, active from `10 + i`, exit at `1000 + i` for odd `i` (no exit,
    `2^48 - 1`, for even `i`). Slot 5 is released: its entry has all-zero fields.
    """
    entries = []
    for i, key in enumerate(key_list[:5]):
        entries.append(
            {
                "ck_prefix": int(key["ck_prefix"]),
                "ck_x": key["ck_x"],
                "eff_stake": (i + 1) * 10**18,
                "active_from_l1": 10 + i,
                "exit_effective_l1": 1000 + i if i % 2 == 1 else NO_EXIT,
            }
        )
    leaves = [reg_leaf(i, entry) for i, entry in enumerate(entries)]
    zero_entry = {
        "ck_prefix": 0,
        "ck_x": word(0),
        "eff_stake": 0,
        "active_from_l1": 0,
        "exit_effective_l1": 0,
    }
    released = {"index": 5, "leaf": reg_leaf(5, zero_entry)}
    all_leaves = leaves + [released["leaf"]]
    return decimals(
        {
            "entries": entries,
            "leaves": leaves,
            "released": released,
            "roots": [
                {"count": n, "entries_root": entries_root(all_leaves[:n])} for n in range(7)
            ],
        }
    )


def committee_sets(entries, config):
    """Committee sets of 0, 1, 3 and 5 members (the first registry entries), per appendix A.

    Members are in ascending set-key order; leaves and nodes use `k = targetEpoch + 1`; an odd last
    node is promoted unchanged. Spec 4.3 rejects an empty committee, so the 0-member case carries
    no root or record.
    """
    chain_id = DEPLOYMENT["l2_chain_id"]
    vp_unit = int(config["inputs"]["vp_unit"])
    target_epoch, cutoff, checkpoint = 7, 100, 3
    k = target_epoch + 1
    cases = []
    for count in (0, 1, 3, 5):
        if count == 0:
            cases.append({"members": [], "valid": False, "reason": "empty_committee"})
            continue
        members = []
        for entry in entries[:count]:
            stake = int(entry["eff_stake"])
            members.append(
                {
                    "ck_prefix": int(entry["ck_prefix"]),
                    "ck_x": entry["ck_x"],
                    "eff_stake": stake,
                    "power": stake // vp_unit,
                    "set_key": keccak(
                        abi_encode(
                            "f(bytes32,uint256,uint256,bytes32)",
                            tag("ETNA_SET_KEY_V1"),
                            chain_id,
                            entry["ck_prefix"],
                            entry["ck_x"],
                        )
                    ),
                }
            )
        members.sort(key=lambda member: int(member["set_key"], 16))
        preimages = [
            abi_encode(
                "f(bytes32,uint256,uint256,uint256,uint256,bytes32,uint256,uint256)",
                tag("ETNA_SET_LEAF_V1"),
                chain_id,
                k,
                index,
                member["ck_prefix"],
                member["ck_x"],
                member["eff_stake"],
                member["power"],
            )
            for index, member in enumerate(members)
        ]
        leaves = [keccak(preimage) for preimage in preimages]
        level = leaves[:]
        while len(level) > 1:
            level = [
                keccak(
                    abi_encode(
                        "f(bytes32,uint256,uint256,bytes32,bytes32)",
                        tag("ETNA_SET_NODE"),
                        chain_id,
                        k,
                        level[i],
                        level[i + 1],
                    )
                )
                if i + 1 < len(level)
                else level[i]
                for i in range(0, len(level), 2)
            ]
        root = level[0]
        total_power = sum(member["power"] for member in members)
        record_preimage = abi_encode(
            "f(bytes32,uint256,uint256,uint256,uint256,bytes32,uint256)",
            tag("ETNA_COMMITTEE_V1"),
            chain_id,
            target_epoch,
            cutoff,
            checkpoint,
            root,
            total_power,
        )
        cases.append(
            {
                "valid": True,
                "l2_chain_id": chain_id,
                "target_epoch": target_epoch,
                "set_version": k,
                "cutoff_l1_block": cutoff,
                "checkpoint_index": checkpoint,
                "members": members,
                "set_leaf_preimages": preimages,
                "set_leaves": leaves,
                "set_root": root,
                "total_power": total_power,
                "record_preimage": record_preimage,
                "record_hash": keccak(record_preimage),
            }
        )
    return decimals(cases)


# --- cuts, statements, land ABI ------------------------------------------------------------------


def cut_at(x):
    """The Lean model's `Examples.cutAt`: EL hash 100 + x, Comet hash 200 + x (0 at x = 0), FI
    cursor x / 6."""
    return {
        "height": x,
        "block_hash": word(100 + x),
        "comet_hash": word(0 if x == 0 else 200 + x),
        "forced_head": x // K,
    }


_LEAVES = {}


def cut_leaf(x):
    """`(preimage, leaf)` of cutLeaf(x): four words (x, blockHash, cometHash, forcedHead)."""
    if x not in _LEAVES:
        cut = cut_at(x)
        preimage = abi_encode(
            "f(uint256,bytes32,bytes32,uint256)",
            x,
            cut["block_hash"],
            cut["comet_hash"],
            cut["forced_head"],
        )
        _LEAVES[x] = (preimage, keccak(preimage))
    return _LEAVES[x]


CUT_CASES = (
    ("g0_p0_h6", 0, 0, 6),
    ("g0_p0_h12", 0, 0, 12),
    ("g0_p0_h18", 0, 0, 18),
    ("g1_p6_h18", 1, 6, 18),
    ("g0_p0_h300", 0, 0, 300),
)


def cuts():
    table = []
    for x in range(19):
        preimage, leaf = cut_leaf(x)
        table.append({**cut_at(x), "preimage": preimage, "leaf": leaf})
    cut_hashes = []
    for name, generation, p, h in CUT_CASES:
        leaves = [cut_leaf(x)[1] for x in range(p + K, h, K)]
        assert len(leaves) == (h - p) // K - 1
        leaves_hash = keccak(concat(*leaves))
        preimage = abi_encode(
            "f(bytes32,uint256,uint256,uint256,bytes32)",
            tag("ETNA_LAND_CUTS_V1"),
            generation,
            p,
            h,
            leaves_hash,
        )
        cut_hashes.append(
            {
                "name": name,
                "generation": generation,
                "parent_height": p,
                "last_height": h,
                "leaves": leaves,
                "leaves_hash": leaves_hash,
                "preimage": preimage,
                "cut_hash": keccak(preimage),
            }
        )
    return decimals({"table": table, "cut_hashes": cut_hashes})


def cut_hash_for(cut_vectors, generation, p, h):
    (case,) = [
        c
        for c in cut_vectors["cut_hashes"]
        if (int(c["generation"]), int(c["parent_height"]), int(c["last_height"]))
        == (generation, p, h)
    ]
    return case["cut_hash"]


STATEMENT_SIGNATURE = (
    "f(bytes32,uint256,uint256,address,address,uint256,uint256,bytes32,bytes32,bytes32,uint256,"
    "bytes32,bytes32,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256,bytes32)"
)
STATEMENT_CASES = (
    # name, generation, p, h, FI head before (at p), FI head after (at h)
    ("genesis", 0, 0, 18, 0, 3),
    ("nonzero", 1, 6, 18, 1, 3),
)


def land_statements(config, cut_vectors):
    """Twenty-one static words (672 bytes); origin and terminal values follow `cut_at`."""
    out = []
    for name, generation, p, h, head_before, head_after in STATEMENT_CASES:
        origin, last = cut_at(p), cut_at(h)
        assert (origin["forced_head"], last["forced_head"]) == (head_before, head_after)
        inputs = {
            "tag": "TAIKO_ETNA_LAND_V1",
            "l1_chain_id": DEPLOYMENT["l1_chain_id"],
            "l2_chain_id": DEPLOYMENT["l2_chain_id"],
            "inbox": DEPLOYMENT["inbox"],
            "registry": DEPLOYMENT["registry"],
            "generation": generation,
            "parent_height": p,
            "parent_hash": origin["block_hash"],
            "parent_comet_hash": origin["comet_hash"],
            "committee_config_hash": config["hash"],
            "last_height": h,
            "last_block_hash": last["block_hash"],
            "last_comet_hash": last["comet_hash"],
            "last_state_root": word(300 + h),
            "l1_reference_block_number": 19_000_000,
            "l1_reference_block_hash": word(0x44),
            "blob_hashes": ["0x01" + "aa" * 31, "0x01" + "bb" * 31],
            "forced_inclusion_head_before": head_before,
            "forced_inclusion_head_after": head_after,
            "active_committee_snapshot": 18_999_000,
            "cut_hash": cut_hash_for(cut_vectors, generation, p, h),
        }
        blob_hashes_hash = keccak(concat(*inputs["blob_hashes"]))
        preimage = abi_encode(
            STATEMENT_SIGNATURE,
            tag(inputs["tag"]),
            inputs["l1_chain_id"],
            inputs["l2_chain_id"],
            inputs["inbox"],
            inputs["registry"],
            inputs["generation"],
            inputs["parent_height"],
            inputs["parent_hash"],
            inputs["parent_comet_hash"],
            inputs["committee_config_hash"],
            inputs["last_height"],
            inputs["last_block_hash"],
            inputs["last_comet_hash"],
            inputs["last_state_root"],
            inputs["l1_reference_block_number"],
            inputs["l1_reference_block_hash"],
            blob_hashes_hash,
            inputs["forced_inclusion_head_before"],
            inputs["forced_inclusion_head_after"],
            inputs["active_committee_snapshot"],
            inputs["cut_hash"],
        )
        out.append(
            {
                "name": name,
                "inputs": decimals(inputs),
                "blob_hashes_hash": blob_hashes_hash,
                "preimage": preimage,
                "hash": keccak(preimage),
            }
        )
    return out


LAND_SIGNATURE = (
    "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256),bytes32[],bytes)"
)


def land_abi(statements):
    """Calldata of `land(input, leaves, proof)` for the `nonzero` statement (p 6, h 18)."""
    (statement,) = [s for s in statements if s["name"] == "nonzero"]
    inputs = statement["inputs"]
    p, h = int(inputs["parent_height"]), int(inputs["last_height"])
    leaves = [cut_leaf(x)[1] for x in range(p + K, h, K)]
    proof = "0x00"
    land_input = "(" + ",".join(
        [
            inputs["parent_height"],
            inputs["last_height"],
            inputs["last_block_hash"],
            inputs["last_comet_hash"],
            inputs["last_state_root"],
            inputs["l1_reference_block_number"],
            inputs["forced_inclusion_head_after"],
            inputs["active_committee_snapshot"],
        ]
    ) + ")"
    return {
        "signature": LAND_SIGNATURE,
        "selector": cast("sig", LAND_SIGNATURE),
        "statement": "nonzero",
        "leaves": leaves,
        "proof": proof,
        "calldata": cast(
            "calldata", LAND_SIGNATURE, land_input, "[" + ",".join(leaves) + "]", proof
        ),
    }


# --- chain identity and block header -------------------------------------------------------------


def chain_domains():
    """chainDomain and the 48-byte CometBFT chain_id = "etna-" + base64url_no_padding(digest)."""
    l1, l2, inbox = DEPLOYMENT["l1_chain_id"], DEPLOYMENT["l2_chain_id"], DEPLOYMENT["inbox"]
    cases = [(inbox, g) for g in (0, 1, 2, U48_MAX)] + [(OTHER_INBOX, 0)]
    out = []
    for case_inbox, generation in cases:
        preimage = abi_encode(
            "f(bytes32,uint256,uint256,address,uint256)",
            tag("ETNA_COMET_DOMAIN_V1"),
            l1,
            l2,
            case_inbox,
            generation,
        )
        digest = keccak(preimage)
        encoded = base64.urlsafe_b64encode(bytes.fromhex(digest[2:])).decode()
        chain_id = "etna-" + encoded.rstrip("=")
        assert len(chain_id) == 48
        out.append(
            {
                "l1_chain_id": l1,
                "l2_chain_id": l2,
                "inbox": case_inbox,
                "generation": generation,
                "preimage": preimage,
                "chain_domain": digest,
                "chain_id": chain_id,
            }
        )
    return decimals(out)


def extra_data():
    """extraData = 0x64 || uint48_be(generation) || uint48_be(anchorNumber): 13 bytes."""
    out = []
    for generation, anchor_number in ((0, 0), (5, 7), (U48_MAX, U48_MAX)):
        out.append(
            {
                "generation": generation,
                "anchor_number": anchor_number,
                "extra_data": "0x64" + format(generation, "012x") + format(anchor_number, "012x"),
            }
        )
    return decimals(out)


# --- votes: CometBFT v0.40.0 sign bytes and secp256k1eth signatures ------------------------------

VOTEGEN = HERE / "votegen"
PREVOTE, PRECOMMIT = 1, 2
VOTE_HEIGHT = 1000
VOTE_TIME = (1_700_000_000, 123)
# The last second (9999-12-31T23:59:59Z) that protobuf's Timestamp, and so CometBFT's
# VoteSignBytes, can encode; CometBFT panics on later times.
MAX_VOTE_SECONDS = 253_402_300_799
# Block ids as (hash, part set total, part set hash); a zero hash is absent, as in appendix A.
BLOCK_A = ("0x" + "aa" * 32, 1, "0x" + "ab" * 32)
BLOCK_B = ("0x" + "bb" * 32, 2, "0x" + "bc" * 32)
BLOCK_NIL = (word(0), 0, word(0))
BLOCK_PARTIAL = (word(0), 1, "0x" + "ab" * 32)
BLOCK_MAX = (BLOCK_A[0], 2**32 - 1, BLOCK_A[2])

# name, type, round, block id, generation, Inbox; height VOTE_HEIGHT and time VOTE_TIME unless
# VOTE_OVERRIDES says otherwise.
VOTE_CASES = (
    ("precommit_a", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("precommit_nil", PRECOMMIT, 0, BLOCK_NIL, 0, DEPLOYMENT["inbox"]),
    ("precommit_b", PRECOMMIT, 0, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("precommit_a_late", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("prevote_a_r1", PREVOTE, 1, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("prevote_b_r1", PREVOTE, 1, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("prevote_b_r2", PREVOTE, 2, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("precommit_b_r1", PRECOMMIT, 1, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("gen1_precommit_a", PRECOMMIT, 0, BLOCK_A, 1, DEPLOYMENT["inbox"]),
    ("gen1_precommit_b", PRECOMMIT, 0, BLOCK_B, 1, DEPLOYMENT["inbox"]),
    ("gen2_precommit_a", PRECOMMIT, 0, BLOCK_A, 2, DEPLOYMENT["inbox"]),
    ("gen2_precommit_b", PRECOMMIT, 0, BLOCK_B, 2, DEPLOYMENT["inbox"]),
    ("other_inbox_precommit_b", PRECOMMIT, 0, BLOCK_B, 0, OTHER_INBOX),
    ("partial_block_id", PRECOMMIT, 0, BLOCK_PARTIAL, 0, DEPLOYMENT["inbox"]),
    ("max_values", PRECOMMIT, 2**31 - 1, BLOCK_MAX, 0, DEPLOYMENT["inbox"]),
)
VOTE_OVERRIDES = {
    "precommit_a_late": {"time": (1_700_000_001, 0)},
    "max_values": {"height": 2**63 - 1, "time": (MAX_VOTE_SECONDS, 999_999_999)},
}
# name, vote a, vote b, the Inbox's current generation, reason ("double_sign" when slashable).
VOTE_PAIRS = (
    ("precommit_conflict", "precommit_a", "precommit_b", 0, "double_sign"),
    ("precommit_vs_nil", "precommit_a", "precommit_nil", 0, "double_sign"),
    ("prevote_conflict_round_1", "prevote_a_r1", "prevote_b_r1", 0, "double_sign"),
    ("same_block_later_time", "precommit_a", "precommit_a_late", 0, "same_block_id"),
    ("different_round", "prevote_b_r1", "prevote_b_r2", 0, "different_round"),
    ("different_type", "prevote_a_r1", "precommit_b_r1", 0, "different_type"),
    ("generation_1_conflict", "gen1_precommit_a", "gen1_precommit_b", 1, "double_sign"),
    ("historical_generation_conflict", "precommit_a", "precommit_b", 1, "double_sign"),
    ("future_generation", "gen2_precommit_a", "gen2_precommit_b", 1, "future_generation"),
    ("other_deployment", "precommit_a", "other_inbox_precommit_b", 0, "other_deployment"),
)


def uvarint(value):
    """Protobuf base-128 varint of a non-negative integer."""
    assert value >= 0, value
    out = bytearray()
    while value >= 0x80:
        out.append(value & 0x7F | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def length_delimited(tag_byte, payload):
    """`tag || uvarint(len(payload)) || payload`."""
    return bytes([tag_byte]) + uvarint(len(payload)) + payload


def vote_sign_bytes(vote, chain_id):
    """Appendix A `voteSignBytes`, written from the spec text alone (not from CometBFT).

    Bracketed fields are omitted when zero or empty; an all-zero 32-byte hash counts as empty, and
    a nil vote (hash, total and parts hash all zero) omits the whole block id.
    """
    vote_type, height, round_ = (int(vote[k]) for k in ("voteType", "height", "round"))
    total, seconds, nanos = (
        int(vote[k]) for k in ("partsTotal", "timestampSeconds", "timestampNanos")
    )
    block_hash, parts_hash = (bytes.fromhex(vote[k][2:]) for k in ("blockHash", "partsHash"))
    assert vote_type in (PREVOTE, PRECOMMIT) and 0 <= height < 2**63 and 0 <= round_ < 2**31
    assert 0 <= total < 2**32 and 0 <= seconds < 2**63 and 0 <= nanos < 10**9
    assert len(block_hash) == len(parts_hash) == 32 and len(chain_id) == 48
    zero = bytes(32)

    psh = (b"\x08" + uvarint(total) if total else b"") + (
        length_delimited(0x12, parts_hash) if parts_hash != zero else b""
    )
    block_id = (length_delimited(0x0A, block_hash) if block_hash != zero else b"") + (
        length_delimited(0x12, psh)
    )
    is_nil = block_hash == zero and total == 0 and parts_hash == zero
    timestamp = (b"\x08" + uvarint(seconds) if seconds else b"") + (
        b"\x10" + uvarint(nanos) if nanos else b""
    )
    cv = (
        (b"\x08" + uvarint(vote_type) if vote_type else b"")
        + (b"\x11" + height.to_bytes(8, "little", signed=True) if height else b"")
        + (b"\x19" + round_.to_bytes(8, "little", signed=True) if round_ else b"")
        + (b"" if is_nil else length_delimited(0x22, block_id))
        + length_delimited(0x2A, timestamp)
        + length_delimited(0x32, chain_id.encode("ascii"))
    )
    return uvarint(len(cv)) + cv


def vote_inputs(chain_ids):
    """Every vote case as `{name, vote, chain_id}`, with integers as decimal strings."""
    cases = []
    for name, vote_type, round_, block_id, generation, inbox in VOTE_CASES:
        overrides = VOTE_OVERRIDES.get(name, {})
        seconds, nanos = overrides.get("time", VOTE_TIME)
        block_hash, total, parts_hash = block_id
        vote = {
            "voteType": vote_type,
            "height": overrides.get("height", VOTE_HEIGHT),
            "round": round_,
            "blockHash": block_hash,
            "partsTotal": total,
            "partsHash": parts_hash,
            "timestampSeconds": seconds,
            "timestampNanos": nanos,
            "generation": generation,
        }
        cases.append(
            {"name": name, "vote": decimals(vote), "chain_id": chain_ids[(inbox, generation)]}
        )
    return cases


def run_votegen(private_key, cases):
    """CometBFT v0.40.0's `VoteSignBytes` and secp256k1eth signature of every case."""
    request = {
        "key": private_key,
        "votes": [{k: case[k] for k in ("name", "chain_id", "vote")} for case in cases],
    }
    result = subprocess.run(
        ["go", "run", "."],
        cwd=VOTEGEN,
        input=json.dumps(request),
        capture_output=True,
        text=True,
        env={**os.environ, "GOFLAGS": "-mod=readonly", "GOWORK": "off"},
    )
    if result.returncode != 0:
        raise SystemExit(f"votegen failed:\n{result.stderr}")
    return json.loads(result.stdout)


def check_vote_signature(key, sign_bytes, signature):
    """65 bytes, V in {0, 1}, low s; recovers to the key's address over keccak256(sign_bytes), as
    `slashDoubleSign` checks with ecrecover, and equals cast's RFC 6979 signature of that digest."""
    digest = keccak(sign_bytes)
    r, s, v = split_sig(signature)
    assert v in (0, 1) and 0 < r < SECP_N and 0 < s <= SECP_N // 2, signature
    assert ecrecover(digest, r, s, v) == key["ck_addr"], signature
    signed = cast("wallet", "sign", "--no-hash", "--private-key", key["private_key"], digest)
    assert signed == join_sig(r, s, v + 27), (signed, signature)


def block_id_of(vote):
    return vote["blockHash"], vote["partsTotal"], vote["partsHash"]


def double_sign_failure(key, chain_ids, a, b, current_generation):
    """Spec 4.1 `slashDoubleSign` checks at this deployment: the first one the pair fails, or None.

    Sign bytes are rebuilt from the deployment's own Inbox and the votes' shared generation, so a
    vote signed for another deployment fails the signature check.
    """
    va, vb = a["vote"], b["vote"]
    for rule, field in (
        ("different_type", "voteType"),
        ("different_height", "height"),
        ("different_round", "round"),
        ("different_generation", "generation"),
    ):
        if va[field] != vb[field]:
            return rule
    if block_id_of(va) == block_id_of(vb):
        return "same_block_id"
    generation = int(va["generation"])
    if generation > current_generation:
        return "future_generation"
    chain_id = chain_ids[(DEPLOYMENT["inbox"], generation)]
    for case in (a, b):
        sign_bytes = "0x" + vote_sign_bytes(case["vote"], chain_id).hex()
        r, s, v = split_sig(case["signature"])
        if ecrecover(keccak(sign_bytes), r, s, v) != key["ck_addr"]:
            return "signature"
    return None


def votes(key_list, domains):
    """Vote sign bytes and signatures by key a1, and the double-sign pairs built from them.

    CometBFT v0.40.0 produces the sign bytes and signatures; generation stops if any sign-byte
    string differs from the appendix A encoder (neither side is adjusted to match the other).
    """
    key = key_list[0]
    assert key["name"] == "a1" and int(key["private_key"], 16) == 0xA1
    chain_ids = {(d["inbox"], int(d["generation"])): d["chain_id"] for d in domains}
    used = [(DEPLOYMENT["inbox"], g) for g in (0, 1, 2)] + [(OTHER_INBOX, 0)]
    cases = vote_inputs(chain_ids)
    assert {c["chain_id"] for c in cases} == {chain_ids[u] for u in used}

    out = run_votegen(key["private_key"], cases)
    assert out["public_key"] == key["public_key"], out["public_key"]
    assert out["signer"] == key["ck_addr"], out["signer"]
    assert [c["name"] for c in out["cases"]] == [c["name"] for c in cases]
    for case, signed in zip(cases, out["cases"]):
        cometbft = signed["sign_bytes"]
        appendix_a = "0x" + vote_sign_bytes(case["vote"], case["chain_id"]).hex()
        if cometbft != appendix_a:
            raise SystemExit(
                f"{case['name']}: CometBFT v0.40.0 and appendix A sign bytes differ\n"
                f"  CometBFT:   {cometbft}\n  appendix A: {appendix_a}"
            )
        check_vote_signature(key, cometbft, signed["signature"])
        case["sign_bytes"] = cometbft
        case["signature"] = signed["signature"]

    by_name = {case["name"]: case for case in cases}
    pairs = []
    for name, a, b, current_generation, reason in VOTE_PAIRS:
        failure = double_sign_failure(key, chain_ids, by_name[a], by_name[b], current_generation)
        expected = {"double_sign": None, "other_deployment": "signature"}.get(reason, reason)
        assert failure == expected, (name, failure, reason)
        pairs.append(
            {
                "name": name,
                "a": a,
                "b": b,
                "double_sign": reason == "double_sign",
                "reason": reason,
                "current_generation": current_generation,
            }
        )
    return decimals(
        {
            "key": {
                "private_key": key["private_key"],
                "public_key": key["public_key"],
                "signer": key["ck_addr"],
            },
            "chain_ids": [
                {"inbox": inbox, "generation": g, "chain_id": chain_ids[(inbox, g)]}
                for inbox, g in used
            ],
            "cases": cases,
            "pairs": pairs,
        }
    )


# --- forced-inclusion eligibility (spec 7.2) -----------------------------------------------------

FICHECK = HERE / "ficheck"
FI_SENDER_KEY = 0xF1  # signs every transaction
FI_AUTHORITY_KEY = 0xF2  # signs the EIP-7702 authorization tuples
FI_TO = bytes.fromhex("55" * 20)
FI_DELEGATE = bytes.fromhex("66" * 20)
FI_ACCESS_ADDRESS = bytes.fromhex("77" * 20)
FI_STORAGE_KEY = (1).to_bytes(32, "big")
FI_BLOB_HASH = bytes.fromhex("01" + "aa" * 31)
GWEI = 10**9

_FI_FEE_1559 = ("chain_id", "nonce", "max_priority_fee", "max_fee", "gas", "to", "value", "data")
FI_LAYOUTS = {
    0: ("nonce", "gas_price", "gas", "to", "value", "data", "v", "r", "s"),
    1: (
        "chain_id",
        "nonce",
        "gas_price",
        "gas",
        "to",
        "value",
        "data",
        "access_list",
        "y_parity",
        "r",
        "s",
    ),
    2: (*_FI_FEE_1559, "access_list", "y_parity", "r", "s"),
    3: (
        *_FI_FEE_1559,
        "access_list",
        "max_fee_per_blob_gas",
        "blob_hashes",
        "y_parity",
        "r",
        "s",
    ),
    4: (*_FI_FEE_1559, "access_list", "authorization_list", "y_parity", "r", "s"),
}
# Spec 7.2 widths: nonce and gas below 2^64, each fee field below 2^128, value below 2^256.
FI_WIDTHS = {
    "nonce": 64,
    "gas": 64,
    "gas_price": 128,
    "max_priority_fee": 128,
    "max_fee": 128,
    "max_fee_per_blob_gas": 128,
    "value": 256,
}


class Encoded(bytes):
    """An item that is already RLP-encoded; `rlp` splices it in unchanged."""


def be_bytes(value):
    """Minimal big-endian bytes of a non-negative integer (empty for zero)."""
    assert value >= 0, value
    return value.to_bytes((value.bit_length() + 7) // 8, "big")


def rlp_header(length, offset, pad=False):
    """The RLP length prefix; `pad` adds a leading zero to the length bytes (non-canonical)."""
    if length < 56 and not pad:
        return bytes([offset + length])
    length_bytes = (b"\x00" if pad else b"") + be_bytes(length)
    return bytes([offset + 55 + len(length_bytes)]) + length_bytes


def rlp(item):
    """Canonical RLP of an int (minimal big-endian), bytes, `Encoded` bytes or a list of items."""
    if isinstance(item, Encoded):
        return bytes(item)
    if isinstance(item, int):
        item = be_bytes(item)
    if isinstance(item, bytes):
        if len(item) == 1 and item[0] < 0x80:
            return item
        return rlp_header(len(item), 0x80) + item
    payload = b"".join(rlp(x) for x in item)
    return rlp_header(len(payload), 0xC0) + payload


def fi_layout(tx_type):
    """The fields of `tx_type`; an unknown type's body is built (and read) with type 2's fields."""
    return FI_LAYOUTS.get(tx_type, FI_LAYOUTS[2])


def fi_encode(tx_type, fields):
    """`rlp(fields)` for a legacy transaction, `type || rlp(fields)` for a typed one."""
    body = rlp([fields[name] for name in fi_layout(tx_type)])
    return body if tx_type == 0 else bytes([tx_type]) + body


def fi_signing_hash(tx_type, fields, legacy_chain_id=None):
    """keccak256 of the signing payload: a legacy transaction's six fields, plus
    `[chain_id, 0, 0]` under EIP-155; `type || rlp(fields without the signature)` when typed."""
    unsigned = [fields[name] for name in fi_layout(tx_type)[:-3]]
    if tx_type == 0:
        extra = [] if legacy_chain_id is None else [legacy_chain_id, 0, 0]
        return keccak("0x" + rlp(unsigned + extra).hex())
    return keccak("0x" + (bytes([tx_type]) + rlp(unsigned)).hex())


def sign_digest(private_key, digest):
    """`(r, s, recovery id)` from `cast wallet sign --no-hash` (RFC 6979, low s)."""
    signed = cast("wallet", "sign", "--no-hash", "--private-key", word(private_key), digest)
    r, s, v = split_sig(signed)
    assert v in (27, 28) and 0 < r < SECP_N and 0 < s <= SECP_N // 2, signed
    return r, s, v - 27


@functools.cache
def key_address(private_key):
    address = address_of(*point(private_key))
    assert address == cast("wallet", "address", "--private-key", word(private_key)).lower()
    return address


def fi_sign(tx_type, fields, legacy_chain_id=None):
    """`fields` signed by the FI sender: a typed y_parity, or a legacy v of 27/28 (no chain id)
    or 2·chainId + 35/36 (EIP-155)."""
    digest = fi_signing_hash(tx_type, fields, legacy_chain_id)
    r, s, parity = sign_digest(FI_SENDER_KEY, digest)
    assert ecrecover(digest, r, s, parity) == key_address(FI_SENDER_KEY)
    if tx_type != 0:
        return {**fields, "y_parity": parity, "r": r, "s": s}
    base = 27 if legacy_chain_id is None else 2 * legacy_chain_id + 35
    return {**fields, "v": base + parity, "r": r, "s": s}


def fi_parity(tx_type, fields):
    if tx_type != 0:
        return fields["y_parity"]
    v = fields["v"]
    return v - 27 if v in (27, 28) else (v - 35) % 2


def fi_with_parity(tx_type, build, parity, legacy_chain_id=None):
    """`build(nonce)` signed at the first nonce from 0 whose signature has this recovery id."""
    nonce = 0
    while True:
        signed = fi_sign(tx_type, build(nonce), legacy_chain_id)
        if fi_parity(tx_type, signed) == parity:
            return signed
        nonce += 1


def fi_authorization_digest(chain_id, address, nonce):
    return keccak("0x05" + rlp([chain_id, address, nonce]).hex())


def fi_authorization(chain_id, nonce=0, address=FI_DELEGATE):
    """An EIP-7702 tuple `[chain_id, address, nonce, y_parity, r, s]` signed by the authority over
    keccak256(0x05 || rlp([chain_id, address, nonce])). Within EIP-7702 widths it must equal
    `cast wallet sign-auth`; an over-wide nonce or a short address is signed as encoded."""
    digest = fi_authorization_digest(chain_id, address, nonce)
    r, s, parity = sign_digest(FI_AUTHORITY_KEY, digest)
    assert ecrecover(digest, r, s, parity) == key_address(FI_AUTHORITY_KEY)
    auth = [chain_id, address, nonce, parity, r, s]
    if nonce >= 2**64 or len(address) != 20:
        return auth
    by_cast = cast(
        "wallet",
        "sign-auth",
        "--private-key",
        word(FI_AUTHORITY_KEY),
        "--nonce",
        nonce,
        "--chain",
        chain_id,
        "--rpc-url",
        "http://127.0.0.1:1",  # never contacted: nonce and chain are given
        "0x" + address.hex(),
    )
    assert by_cast == "0x" + rlp(auth).hex(), by_cast
    return auth


def fi_authorization_with_parity(chain_id, parity):
    """The authority's tuple at the first nonce from 0 whose signature has this recovery id."""
    nonce = 0
    while (auth := fi_authorization(chain_id, nonce))[3] != parity:
        nonce += 1
    return auth


def fi_legacy(**overrides):
    return {
        "nonce": 0,
        "gas_price": 2 * GWEI,
        "gas": 21_000,
        "to": FI_TO,
        "value": 1,
        "data": b"",
        **overrides,
    }


def fi_eip2930(**overrides):
    return {
        "chain_id": DEPLOYMENT["l2_chain_id"],
        "nonce": 0,
        "gas_price": 2 * GWEI,
        "gas": 30_000,
        "to": FI_TO,
        "value": 1,
        "data": b"",
        "access_list": [[FI_ACCESS_ADDRESS, [FI_STORAGE_KEY]]],
        **overrides,
    }


def fi_eip1559(**overrides):
    return {
        "chain_id": DEPLOYMENT["l2_chain_id"],
        "nonce": 0,
        "max_priority_fee": GWEI,
        "max_fee": 2 * GWEI,
        "gas": 21_000,
        "to": FI_TO,
        "value": 1,
        "data": b"",
        "access_list": [],
        **overrides,
    }


def fi_blob(**overrides):
    return fi_eip1559(max_fee_per_blob_gas=1, blob_hashes=[FI_BLOB_HASH], **overrides)


def fi_eip7702(authorizations, **overrides):
    return fi_eip1559(gas=100_000, authorization_list=authorizations, **overrides)


def rlp_lenient(data, i=0):
    """`(item, end)` of the RLP item at `data[i]`, accepting non-minimal length prefixes; a string
    is bytes and a list a list of items."""
    if i >= len(data):
        raise ValueError("truncated")
    first = data[i]
    if first < 0x80:
        return data[i : i + 1], i + 1
    is_list = first >= 0xC0
    short = first - (0xC0 if is_list else 0x80)
    if short < 56:
        length, start = short, i + 1
    else:
        size = short - 55
        length, start = int.from_bytes(data[i + 1 : i + 1 + size], "big"), i + 1 + size
    end = start + length
    if end > len(data):
        raise ValueError("truncated")
    if not is_list:
        return data[start:end], end
    items, j = [], start
    while j < end:
        item, j = rlp_lenient(data[:end], j)
        items.append(item)
    return items, end


def fi_violations(raw):
    """`(violated rules, recovered sender)` of `raw` under spec 7.2, from the bytes alone.

    A lenient decode (non-minimal lengths, leading-zero integers, trailing bytes, extra fields and
    an empty type-4 destination are read through and reported as `noncanonical`) lets every other
    rule be checked too, so a case can be shown to break only the rule it is labelled with. The
    signature is recovered over the signing payload re-encoded from the decoded fields.
    """
    l2_chain_id, gas_limit = DEPLOYMENT["l2_chain_id"], DEPLOYMENT["l2_block_gas_limit"]
    if not raw or 0x80 <= raw[0] < 0xC0:
        return {"noncanonical"}, None
    violations = set()
    tx_type = 0 if raw[0] >= 0xC0 else raw[0]
    if tx_type not in (0, 1, 2, 4):
        violations.add("type")
    body = raw if tx_type == 0 else raw[1:]
    try:
        items, end = rlp_lenient(body)
    except ValueError:
        return violations | {"noncanonical"}, None
    names = fi_layout(tx_type)
    if end != len(body) or not isinstance(items, list) or len(items) != len(names):
        violations.add("noncanonical")
        if not isinstance(items, list) or len(items) < len(names):
            return violations, None
    fields = {}
    for name, item in zip(names, items):
        if name in ("to", "data", "access_list", "blob_hashes"):
            fields[name] = item
        elif name == "authorization_list":
            fields[name] = [
                [int.from_bytes(f, "big") if i != 1 else f for i, f in enumerate(auth)]
                for auth in item
            ]
        else:
            fields[name] = int.from_bytes(item, "big")
    if fi_encode(tx_type, fields) != raw:
        violations.add("noncanonical")
    # Fixed-width fields that RLP does not constrain: a destination is empty or 20 bytes (always
    # 20 for types 3 and 4), an access-list entry is [20-byte address, [32-byte keys]] and an
    # authorization tuple has six fields.
    if len(fields["to"]) != 20 and (fields["to"] or tx_type in (3, 4)):
        violations.add("noncanonical")
    for entry in fields.get("access_list", []):
        address, keys = entry if isinstance(entry, list) and len(entry) == 2 else (b"", [])
        if len(address) != 20 or not isinstance(keys, list) or any(len(k) != 32 for k in keys):
            violations.add("noncanonical")
    tuples = fields.get("authorization_list", [])
    if any(len(auth) != 6 for auth in tuples):
        violations.add("noncanonical")

    if any(fields[name] >= 2**bits for name, bits in FI_WIDTHS.items() if name in fields):
        violations.add("width")
    # EIP-7702 tuple widths: chain_id uint256, address 20 bytes, nonce uint64, y_parity uint8,
    # r and s uint256. Nothing else about a tuple affects eligibility.
    for chain_id, address, nonce, y_parity, r, s in (auth[:6] for auth in tuples if len(auth) >= 6):
        if len(address) != 20 or nonce >= 2**64 or y_parity >= 2**8:
            violations.add("width")
        if max(chain_id, r, s) >= 2**256:
            violations.add("width")
    if fields["gas"] > gas_limit:
        violations.add("gas_limit")

    legacy_chain_id, parity = None, None
    if tx_type == 0:
        v = fields["v"]
        if v in (27, 28):
            parity = v - 27
        elif v >= 35:
            legacy_chain_id, parity = (v - 35) // 2, (v - 35) % 2
            if legacy_chain_id != l2_chain_id:
                violations.add("chain_id")
    else:
        parity = fields["y_parity"]
        if fields["chain_id"] != l2_chain_id:
            violations.add("chain_id")
    r, s = fields["r"], fields["s"]
    sender = None
    if parity in (0, 1) and 0 < r < SECP_N and 0 < s <= SECP_N // 2:
        sender = ecrecover(fi_signing_hash(tx_type, fields, legacy_chain_id), r, s, parity)
    if sender is None:
        violations.add("signature")
    return violations, sender


def fi_cases():
    """`(cases, other senders)`: `(name, rule, raw)` of every case, in the order the vectors list
    them, and the sender of each readable non-signature case not signed by the FI sender.

    Each ineligible case breaks only the rule it is labelled with (gas 2^64 is also above the
    block gas limit) and is otherwise well-formed and signed by the FI sender, so an
    implementation that skips that one rule accepts it. Framing cases wrap canonical
    transactions; the signature of a re-encoded case covers its canonical signing payload.
    """
    l2_chain_id, gas_limit = DEPLOYMENT["l2_chain_id"], DEPLOYMENT["l2_block_gas_limit"]

    def legacy(parity, chain_id):
        return fi_with_parity(0, lambda n: fi_legacy(nonce=n), parity, chain_id)

    def eip1559(**overrides):
        return fi_sign(2, fi_eip1559(**overrides))

    def eip7702(authorizations, **overrides):
        return fi_encode(4, fi_sign(4, fi_eip7702(authorizations, **overrides)))

    base = eip1559()
    auth = fi_authorization(l2_chain_id)
    auth_r_zero = [*auth[:4], 0, auth[5]]
    auth_y_255 = [*auth[:3], 255, *auth[4:]]
    # Over-wide tuples whose low bits are a valid tuple, so a decoder that truncates y_parity to
    # 8 bits or r to 256 bits reads a validly signed tuple back.
    even_auth = fi_authorization_with_parity(l2_chain_id, 0)
    auth_y_256 = [*even_auth[:3], 256, *even_auth[4:]]
    auth_r_33 = [*auth[:4], 2**256 + auth[4], auth[5]]
    assert auth_y_256[3] % 2**8 == even_auth[3] and auth_r_33[4] % 2**256 == auth[4]
    # A high-s tuple signature is the twin of a valid one; the EL skips that tuple.
    auth_high_s = [*auth[:3], 1 - auth[3], auth[4], SECP_N - auth[5]]
    auth_digest = fi_authorization_digest(*auth[:3])
    assert ecrecover(auth_digest, auth[4], auth[5], auth[3]) == key_address(FI_AUTHORITY_KEY)
    assert auth_high_s[5] > SECP_N // 2
    short_address_access_list = [[FI_ACCESS_ADDRESS[:19], [FI_STORAGE_KEY]]]
    even = fi_with_parity(2, lambda n: fi_eip1559(nonce=n), 0)
    low_s = base["s"]
    unrecoverable_r = smallest_off_curve_x()

    # The low-s twin of `high_s` and the parity-masked twin of `y_parity_2` recover the sender.
    base_digest, even_digest = fi_signing_hash(2, base), fi_signing_hash(2, even)
    flipped = 1 - base["y_parity"]
    assert ecrecover(base_digest, base["r"], SECP_N - low_s, flipped) == key_address(FI_SENDER_KEY)
    assert ecrecover(even_digest, even["r"], even["s"], 2 & 1) == key_address(FI_SENDER_KEY)
    assert ecrecover(base_digest, unrecoverable_r, low_s, 0) is None
    assert ecrecover(base_digest, unrecoverable_r, low_s, 1) is None

    # s = floor(n/2) is the largest low s, and no FI-sender signature has it: the boundary pair
    # signs `base`'s payload with `base`'s r, so (r, n/2, 0) recovers some other key Q, and
    # (r, n/2 + 1, 1) is its high-s twin.
    half_n = SECP_N // 2
    boundary_sender = ecrecover(base_digest, base["r"], half_n, 0)
    assert boundary_sender not in (None, key_address(FI_SENDER_KEY))
    assert SECP_N - (half_n + 1) == half_n

    base_items = [base[name] for name in fi_layout(2)]
    payload = rlp(base_items)[2:]  # a signed transaction is above 55 bytes: 0xf8 <length>
    assert rlp(base_items)[0] == 0xF8 and len(payload) < 256
    nonce_one = eip1559(nonce=1)

    cases = [
        ("legacy_eip155_35", "eligible", fi_encode(0, legacy(0, l2_chain_id))),
        ("legacy_eip155_36", "eligible", fi_encode(0, legacy(1, l2_chain_id))),
        ("legacy_pre155_27", "eligible", fi_encode(0, legacy(0, None))),
        ("legacy_pre155_28", "eligible", fi_encode(0, legacy(1, None))),
        ("eip2930", "eligible", fi_encode(1, fi_sign(1, fi_eip2930()))),
        ("eip1559", "eligible", fi_encode(2, base)),
        ("eip1559_zero_fee", "eligible", fi_encode(2, eip1559(max_priority_fee=0, max_fee=0))),
        ("eip7702", "eligible", eip7702([auth])),
        ("eip7702_invalid_auth_signature", "eligible", eip7702([auth_r_zero])),
        ("eip7702_empty_auth_list", "eligible", eip7702([])),
        ("gas_at_limit", "eligible", fi_encode(2, eip1559(gas=gas_limit))),
        ("nonce_max", "eligible", fi_encode(2, eip1559(nonce=2**64 - 1))),
        (
            "fee_max",
            "eligible",
            fi_encode(2, eip1559(max_priority_fee=2**128 - 1, max_fee=2**128 - 1)),
        ),
        ("value_max", "eligible", fi_encode(2, eip1559(value=2**256 - 1))),
        # The EL skips a tuple for another chain or with y_parity above 1; chain id 0 is any chain.
        ("eip7702_foreign_tuple_chain_id", "eligible", eip7702([fi_authorization(1)])),
        ("eip7702_tuple_y_parity_255", "eligible", eip7702([auth_y_255])),
        ("eip7702_tuple_chain_id_zero", "eligible", eip7702([fi_authorization(0)])),
        (
            "legacy_contract_creation",
            "eligible",
            fi_encode(0, fi_sign(0, fi_legacy(to=b"", gas=60_000), l2_chain_id)),
        ),
        ("eip1559_contract_creation", "eligible", fi_encode(2, eip1559(to=b"", gas=60_000))),
        ("s_half_n", "eligible", fi_encode(2, {**base, "s": half_n, "y_parity": 0})),
        (
            "eip7702_tuple_nonce_max",
            "eligible",
            eip7702([fi_authorization(l2_chain_id, nonce=2**64 - 1)]),
        ),
        ("eip7702_tuple_high_s", "eligible", eip7702([auth_high_s])),
        ("empty", "noncanonical", b""),
        ("trailing_byte", "noncanonical", fi_encode(2, base) + b"\x00"),
        ("two_transactions", "noncanonical", fi_encode(2, base) + fi_encode(2, nonce_one)),
        (
            "leading_zero_nonce",
            "noncanonical",
            fi_encode(2, {**nonce_one, "nonce": Encoded(b"\x82\x00\x01")}),
        ),
        (
            "non_minimal_length_prefix",
            "noncanonical",
            b"\x02" + rlp_header(len(payload), 0xC0, pad=True) + payload,
        ),
        (
            "typed_missing_field",
            "noncanonical",
            b"\x02" + rlp([base[name] for name in fi_layout(2) if name != "access_list"]),
        ),
        ("typed_extra_field", "noncanonical", b"\x02" + rlp([*base_items, b""])),
        ("eip7702_empty_to", "noncanonical", eip7702([auth], to=b"")),
        (
            "legacy_to_19_bytes",
            "noncanonical",
            fi_encode(0, fi_sign(0, fi_legacy(to=FI_TO[:19]), l2_chain_id)),
        ),
        ("eip1559_to_19_bytes", "noncanonical", fi_encode(2, eip1559(to=FI_TO[:19]))),
        (
            "eip2930_access_list_address_19_bytes",
            "noncanonical",
            fi_encode(1, fi_sign(1, fi_eip2930(access_list=short_address_access_list))),
        ),
        (
            "eip1559_storage_key_31_bytes",
            "noncanonical",
            fi_encode(
                2, eip1559(gas=30_000, access_list=[[FI_ACCESS_ADDRESS, [FI_STORAGE_KEY[1:]]]])
            ),
        ),
        ("eip7702_tuple_5_fields", "noncanonical", eip7702([auth[:5]])),
        ("eip7702_tuple_7_fields", "noncanonical", eip7702([[*auth, 0]])),
        ("type3_blob", "type", fi_encode(3, fi_sign(3, fi_blob()))),
        ("unknown_type_05", "type", fi_encode(0x05, fi_sign(0x05, fi_eip1559()))),
        ("unknown_type_7f", "type", fi_encode(0x7F, fi_sign(0x7F, fi_eip1559()))),
        ("legacy_v_37", "chain_id", fi_encode(0, legacy(0, 1))),
        ("typed_wrong_chain_id", "chain_id", fi_encode(2, eip1559(chain_id=l2_chain_id + 1))),
        ("y_parity_2", "signature", fi_encode(2, {**even, "y_parity": 2})),
        ("r_zero", "signature", fi_encode(2, {**base, "r": 0})),
        ("s_zero", "signature", fi_encode(2, {**base, "s": 0})),
        ("r_eq_n", "signature", fi_encode(2, {**base, "r": SECP_N})),
        (
            "high_s",
            "signature",
            fi_encode(2, {**base, "s": SECP_N - low_s, "y_parity": flipped}),
        ),
        ("unrecoverable_r", "signature", fi_encode(2, {**base, "r": unrecoverable_r})),
        ("s_half_n_plus_1", "signature", fi_encode(2, {**base, "s": half_n + 1, "y_parity": 1})),
        ("nonce_2_64", "width", fi_encode(2, eip1559(nonce=2**64))),
        ("gas_2_64", "width", fi_encode(2, eip1559(gas=2**64))),
        ("fee_2_128", "width", fi_encode(2, eip1559(max_fee=2**128))),
        ("tip_2_128", "width", fi_encode(2, eip1559(max_priority_fee=2**128))),
        (
            "legacy_gas_price_2_128",
            "width",
            fi_encode(0, fi_sign(0, fi_legacy(gas_price=2**128), l2_chain_id)),
        ),
        (
            "eip2930_gas_price_2_128",
            "width",
            fi_encode(1, fi_sign(1, fi_eip2930(gas_price=2**128))),
        ),
        ("eip7702_fee_2_128", "width", eip7702([auth], max_fee=2**128)),
        ("value_33_bytes", "width", fi_encode(2, eip1559(value=2**256))),
        (
            "eip7702_tuple_nonce_2_64",
            "width",
            eip7702([fi_authorization(l2_chain_id, nonce=2**64)]),
        ),
        ("eip7702_tuple_y_parity_256", "width", eip7702([auth_y_256])),
        (
            "eip7702_tuple_address_19_bytes",
            "width",
            eip7702([fi_authorization(l2_chain_id, address=FI_DELEGATE[:19])]),
        ),
        ("eip7702_tuple_r_33_bytes", "width", eip7702([auth_r_33])),
        ("gas_above_limit", "gas_limit", fi_encode(2, eip1559(gas=gas_limit + 1))),
    ]
    return cases, {"s_half_n": boundary_sender}


# Noncanonical cases with no transaction to read through: nothing else can be checked.
FI_UNREADABLE = ("empty", "typed_missing_field")


def fi_eligibility():
    """Spec 7.2 forced-inclusion eligibility of raw transaction bytes at the deployment's L2 chain
    id and block gas limit. Every case is classified again from its bytes by `fi_violations`;
    `ficheck/` then checks the written file against go-ethereum v1.15.5."""
    cases, other_senders = fi_cases()
    out = []
    for name, rule, raw in cases:
        violations, recovered = fi_violations(raw)
        expected = set() if rule == "eligible" else {rule}
        if name == "gas_2_64":
            expected.add("gas_limit")
        assert violations == expected, (name, violations)
        if rule != "signature" and name not in FI_UNREADABLE:
            sender = other_senders.get(name, key_address(FI_SENDER_KEY))
            assert recovered == sender, (name, recovered)
        out.append(
            {"name": name, "raw": "0x" + raw.hex(), "eligible": rule == "eligible", "rule": rule}
        )
    assert len({case["raw"] for case in out}) == len(out)
    return {
        "l2_chain_id": dec(DEPLOYMENT["l2_chain_id"]),
        "l2_block_gas_limit": dec(DEPLOYMENT["l2_block_gas_limit"]),
        "cases": out,
    }


def run_ficheck():
    """Checks the written vectors against go-ethereum v1.15.5 (`ficheck/`, run with `go run`)."""
    result = subprocess.run(
        ["go", "run", ".", "../vectors.json"],
        cwd=FICHECK,
        capture_output=True,
        text=True,
        env={**os.environ, "GOFLAGS": "-mod=readonly", "GOWORK": "off"},
    )
    if result.returncode != 0:
        raise SystemExit(f"ficheck failed:\n{result.stdout}{result.stderr}")


# --- storage layout ------------------------------------------------------------------------------

# Packed words (appendix B): fields in the listed order from the least-significant bit; ckPrefix
# takes 8 bits and every other field 48; unused high bits are zero.
# Each entry: vector key -> (layout table, packing name, fields, ordinary values); every kind also
# gets an all-max item (2^48 - 1, ckPrefix 3).
PACKED = {
    "inbox_272": (
        "inbox",
        "genesis_packed",
        ("genesis_height", "l1_block", "epoch_len_l2"),
        (6, 19_000_000, 3_600),
    ),
    "inbox_280_word2": (
        "inbox",
        "forced_inclusion_entry_word2",
        ("timestamp", "l1_block"),
        (1_700_000_000, 19_000_123),
    ),
    "inbox_281": ("inbox", "forced_inclusion_head_tail", ("head", "tail"), (1, 3)),
    "inbox_282": (
        "inbox",
        "forced_inclusion_config",
        ("forced_inclusion_delay", "max_anchor_age"),
        (384, 1_152),
    ),
    "inbox_285_word1": (
        "inbox",
        "landing_word1",
        ("parent_height", "generation", "head"),
        (12, 1, 3),
    ),
    "registry_checkpoint_word1": (
        "registry",
        "checkpoint_word1",
        ("l1_block", "count"),
        (19_000_000, 5),
    ),
    "registry_entry_word3": (
        "registry",
        "entry_word3",
        ("ck_prefix", "active_from_l1", "exit_effective_l1"),
        (2, 10, 1_001),
    ),
}


def bits_of(field_name):
    return 8 if field_name == "ck_prefix" else 48


def packing(table):
    out = {}
    for _, (layout_table, name, fields, _) in PACKED.items():
        if layout_table != table:
            continue
        offset, lanes = 0, {}
        for field_name in fields:
            lanes[field_name] = {"offset": offset, "bits": bits_of(field_name)}
            offset += bits_of(field_name)
        out[name] = lanes
    return out


def pack(fields, values):
    packed, offset = 0, 0
    for field_name, value in zip(fields, values):
        bits = bits_of(field_name)
        assert 0 <= value < 2**bits, (field_name, value)
        packed |= value << offset
        offset += bits
    return word(packed)


def packed_words():
    out = {}
    for key, (_, _, fields, ordinary) in PACKED.items():
        maximum = tuple(3 if f == "ck_prefix" else U48_MAX for f in fields)
        out[key] = [
            {**dict(zip(fields, values)), "word": pack(fields, values)}
            for values in (ordinary, maximum)
        ]
    return decimals(out)


def origin_words():
    """Slot 290 origins: (startHeight, l1BlockNumber, l1Timestamp), one full word each."""
    fields = ("start_height", "l1_block_number", "l1_timestamp")
    cases = ((0, (0, 19_000_000, 1_700_000_000)), (1, (U48_MAX, U48_MAX, U48_MAX)))
    return decimals(
        [{"generation": generation, **dict(zip(fields, values))} for generation, values in cases]
    )


INBOX_SLOTS = {
    "initialization_status": 258,
    "recovery_generation": 268,
    "committee_config_hash": 269,
    "last_checkpoint_height": 270,
    "last_checkpoint_hash": 271,
    "genesis_packed": 272,
    "genesis_block_hash": 273,
    "genesis_state_root": 274,
    "genesis_committee_record_hash": 278,
    "genesis_cutoff": 279,
    "forced_inclusion_queue": 280,
    "forced_inclusion_head_tail": 281,
    "forced_inclusion_config": 282,
    "active_committee_snapshot": 284,
    "landings": 285,
    "origins": 290,
}
RESERVED_SLOTS = (283, 286, 287, 288, 289, 291)
ANCHOR_SLOTS = (268, 270, 271, 281)


def mapping_slots(key, slot, count):
    first = int(cast("index", "uint256", key, slot), 16)
    return [word(first + w) for w in range(count)]


def layout():
    """The node-facing storage layout of the Inbox and the staking registry (appendix B)."""
    base = cast("index-erc7201", "taiko.etna.registry")
    base_int = int(base, 16)
    checkpoint_data = int(keccak(base), 16)
    entries_slot = word(base_int + 1)
    entry_data = int(keccak(entries_slot), 16)

    def cp(i):
        return checkpoint_data + 2 * i

    def namespace(name):
        ns_base = cast("index-erc7201", name)
        return {
            "namespace": name,
            "base": ns_base,
            "slots": [
                {"bond_id": bond_id, "slot": cast("index", "uint256", bond_id, ns_base)}
                for bond_id in (0, 4095)
            ],
        }

    inbox = {
        "slots": INBOX_SLOTS,
        "reserved_slots": list(RESERVED_SLOTS),
        "packing": packing("inbox"),
        "initialized_status": 3,
        "anchor_slots": list(ANCHOR_SLOTS),
        "forced_inclusion_entry_slots": [
            {"index": i, "slots": mapping_slots(i, INBOX_SLOTS["forced_inclusion_queue"], 2)}
            for i in (0, 7)
        ],
        "landing_slots": [
            {"height": h, "slots": mapping_slots(h, INBOX_SLOTS["landings"], 3)}
            for h in (0, 6, 18)
        ],
        "origin_slots": [
            {"generation": g, "slots": mapping_slots(g, INBOX_SLOTS["origins"], 3)}
            for g in (0, 1)
        ],
    }
    registry = {
        "namespace": "taiko.etna.registry",
        "base": base,
        "checkpoints_slot": base,
        "entries_slot": entries_slot,
        "no_exit": NO_EXIT,
        "packing": packing("registry"),
        "checkpoint_slots": [
            {"index": i, "slots": [word(cp(i) + w) for w in range(2)]} for i in (0, 1, 5)
        ],
        "entry_slots": [
            {"index": j, "slots": [word(entry_data + 3 * j + w) for w in range(3)]}
            for j in (0, 1, 4095)
        ],
        "snapshot_slots": [
            {
                "index": i,
                "has_next": has_next,
                "slots": [base, word(cp(i)), word(cp(i) + 1)]
                + ([word(cp(i + 1))] if has_next else []),
            }
            for i, has_next in ((0, False), (0, True), (3, True))
        ],
        "owners": namespace("taiko.etna.registry.owners"),
        "exit_confirmations": namespace("taiko.etna.registry.exit-confirmations"),
    }
    return decimals({"inbox": inbox, "registry": registry})


def main():
    key_list = keys()
    digests = register_digests(key_list)
    config = committee_config()
    entries = registry_entries(key_list)
    cut_vectors = cuts()
    statements = land_statements(config, cut_vectors)
    domains = chain_domains()
    vectors = {
        "schema_version": "4",
        "deployment": deployment(),
        "keys": key_list,
        "key_decompression": key_decompression(key_list),
        "register_digests": digests,
        "pop_rejections": pop_rejections(key_list, digests),
        "committee_config": config,
        "registry_entries": entries,
        "committee_sets": committee_sets(entries["entries"], config),
        "cuts": cut_vectors,
        "land_statements": statements,
        "land_abi": land_abi(statements),
        "chain_domains": domains,
        "votes": votes(key_list, domains),
        "fi_eligibility": fi_eligibility(),
        "extra_data": extra_data(),
        "packed_words": packed_words(),
        "origin_words": origin_words(),
        "layout": layout(),
    }
    OUTPUT.write_text(json.dumps(vectors, indent=2) + "\n")
    subprocess.run(["pnpm", "exec", "prettier", "--write", str(OUTPUT)], cwd=ROOT, check=True)
    run_ficheck()


if __name__ == "__main__":
    main()
