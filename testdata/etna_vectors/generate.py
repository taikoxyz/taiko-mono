#!/usr/bin/env python3
"""Regenerates testdata/etna_vectors/vectors.json (schema "9").

Run from the repository root with Foundry's `cast` and Go on PATH and the workspace's pnpm
dependencies installed (the output is formatted with the repository's prettier):

    python3 -I testdata/etna_vectors/generate.py

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
address over keccak256 of the sign bytes and equal cast's signature of that digest. Validator states
come from stock CometBFT v0.40.0 committing blocks (`valgen/`, run with `go run`); every state must
equal `valset_model.py`, a separate Python reading of CometBFT's validator-set arithmetic, and every
preimage and hash must equal `cast abi-encode` and `cast keccak` of its entries. Forced-inclusion
eligibility cases (spec 7.2) are RLP-encoded in Python and signed with `cast wallet sign --no-hash`
over `cast keccak` signing hashes (EIP-7702 tuples must equal `cast wallet sign-auth`); each case is
classified again from its bytes, an ineligible case must break only the rule it is labelled with,
and the written file is checked against go-ethereum v1.15.5 (`ficheck/`, run with `go run`).
Every literal hash and byte string that the spec's appendix A vectors list is recomputed
(`appendix_a_examples`), and generation stops if one differs. Only the inputs, the packing table
and the storage slot numbers are written by hand, following the Etna spec's appendix A (encodings)
and appendix B (storage layout). All integers are decimal strings so that every value survives
JSON parsing exactly.
"""

import base64
import concurrent.futures
import functools
import json
import os
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
# `python3 -I` leaves the script's own directory off sys.path.
sys.path.insert(0, str(HERE))

import valset_model  # noqa: E402

ROOT = HERE.parents[1]
OUTPUT = HERE / "vectors.json"

WORD_MOD = 2**256
U48_MAX = 2**48 - 1
NO_EXIT = U48_MAX  # exitEffectiveL1 = 2^48 - 1 means no exit is set
FI_STEP = 6  # the cut model's FI cursor advances once every FI_STEP heights

# secp256k1 curve parameters (SEC 2).
SECP_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
SECP_G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)

TAIKO = 10**18  # base units per TAIKO
TAIKO_SUPPLY = 10**9 * TAIKO  # TAIKO's fixed total supply, 10^27 base units (4.3)
MAX_TOTAL_VOTING_POWER = (2**63 - 1) // 8  # CometBFT's MaxTotalVotingPower, appendix A's MAX
MAX_COMMITTEE_SIZE = 4096  # n_max's upper bound and the number of registry slots (START-10-11)

DEPLOYMENT = {
    "l1_chain_id": 1,
    "l2_chain_id": 167001,
    "inbox": "0x1111111111111111111111111111111111111111",
    "registry": "0x2222222222222222222222222222222222222222",
    "l2_block_gas_limit": 45_000_000,
    # The registry's immutable minStake: the registration minimum, the committee eligibility
    # minimum (COMM-4.3-3) and the fifth word of the committee config hash (ENC-A-36, START-10-14).
    "min_stake": 250_000 * TAIKO,
    # A new network: the Etna start S is block 0 and the switch immutables are zero (spec 10, 11).
    "etna_start": 0,
    "unzen_inbox": "0x" + "00" * 20,
    "etna_fork_time": 0,
}
# Committee config hash inputs other than minStake (ENC-A-36, PARAM-11-7, PARAM-11-8).
VP_UNIT = 10**9
N_MAX = 128
UNSETTLED_LIMIT = 3_600
# START-10-10..12: vp_unit >= ceil(10^27 / MAX), minStake >= vp_unit and 4096 * minStake > 10^27,
# 1 <= n_max <= 4096 and 1 <= U <= 65,536.
assert VP_UNIT >= -(-TAIKO_SUPPLY // MAX_TOTAL_VOTING_POWER) == 867_361_738
assert DEPLOYMENT["min_stake"] >= VP_UNIT
assert MAX_COMMITTEE_SIZE * DEPLOYMENT["min_stake"] > TAIKO_SUPPLY
assert 1 <= N_MAX <= MAX_COMMITTEE_SIZE and 1 <= UNSETTLED_LIMIT <= 65_536
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


@functools.cache
def tag(name):
    """A domain tag as one static `bytes32` word: its ASCII bytes right-padded with zeros (ENC-A-5).
    Every tagged hash below passes this word as its first `bytes32` argument, never a string."""
    word32 = cast("format-bytes32-string", name)
    assert word32 == "0x" + name.encode("ascii").ljust(32, b"\0").hex(), name
    return word32


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


def consensus_key(name, k):
    """The key with private scalar k: its compressed encoding, ckPrefix, ckX, ckY and ckAddr, the
    address checked against `cast wallet address`."""
    x, y = point(k)
    private_key = word(k)
    ck_x, ck_y = word(x), word(y)
    ck_addr = "0x" + keccak(concat(ck_x, ck_y))[-40:]
    assert ck_addr == cast("wallet", "address", "--private-key", private_key).lower(), name
    return {
        "name": name,
        "private_key": private_key,
        "public_key": "0x" + compress(x, y).hex(),
        "ck_prefix": 2 + (y & 1),
        "ck_x": ck_x,
        "ck_y": ck_y,
        "ck_addr": ck_addr,
    }


def keys():
    """Consensus keys 0xA1..0xA5 plus the first key whose X starts with a zero byte."""
    scalars = [(f"a{i}", 0xA0 + i) for i in range(1, 6)]
    scalars.append(("leading_zero_x", leading_zero_x_scalar()))
    return decimals([consensus_key(name, k) for name, k in scalars])


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
    # The 66 ASCII characters of the key's hex form: textual encodings are rejected, not parsed.
    textual = base["public_key"][2:].encode("ascii")
    assert len(textual) == 66 and bytes.fromhex(textual.decode()) == compress(x, y)
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
        ("textual_hex", textual, "textual"),
        # SEC1's single-byte encoding of the point at infinity.
        ("identity_00", bytes(1), "identity"),
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
    """`committeeConfigHash`: seven static words (224 bytes); the fifth is the registry's
    minStake."""
    inputs = {
        "tag": "ETNA_PARENT_ANCHOR_V1",
        "l2_chain_id": DEPLOYMENT["l2_chain_id"],
        "registry": DEPLOYMENT["registry"],
        "vp_unit": VP_UNIT,
        "min_stake": DEPLOYMENT["min_stake"],
        "n_max": N_MAX,
        "unsettled_limit": UNSETTLED_LIMIT,
    }
    preimage = abi_encode(
        "f(bytes32,uint256,address,uint256,uint256,uint256,uint256)",
        tag(inputs["tag"]),
        inputs["l2_chain_id"],
        inputs["registry"],
        inputs["vp_unit"],
        inputs["min_stake"],
        inputs["n_max"],
        inputs["unsettled_limit"],
    )
    assert len(preimage) == 2 + 2 * 224
    return {"inputs": decimals(inputs), "preimage": preimage, "hash": keccak(preimage)}


ENTRY_FIELDS = ("ck_prefix", "ck_x", "eff_stake", "active_from_l1", "exit_effective_l1")
# An empty slot's entry: all-zero fields (ENC-A-20), which still give a nonzero leaf.
ZERO_ENTRY = {"ck_prefix": 0, "ck_x": word(0), "eff_stake": 0, "active_from_l1": 0,
              "exit_effective_l1": 0}
REG_LEAF_SIGNATURE = "f(bytes32,uint256,uint256,bytes32,uint256,uint256,uint256)"


@functools.cache
def _reg_leaf(index, ck_prefix, ck_x, eff_stake, active_from_l1, exit_effective_l1):
    preimage = abi_encode(
        REG_LEAF_SIGNATURE,
        tag("ETNA_REG_ENTRY_V1"),
        index,
        ck_prefix,
        ck_x,
        eff_stake,
        active_from_l1,
        exit_effective_l1,
    )
    assert len(preimage) == 2 + 2 * 224
    return preimage, keccak(preimage)


def reg_leaf_preimage(index, entry):
    """`regLeaf(j)`'s 224-byte preimage: seven words (ENC-A-37)."""
    return _reg_leaf(index, *(entry[f] for f in ENTRY_FIELDS))[0]


def reg_leaf(index, entry):
    """`regLeaf(j)`, indexed by the slot number j (ENC-A-37)."""
    return _reg_leaf(index, *(entry[f] for f in ENTRY_FIELDS))[1]


def node(left, right):
    """An entriesRoot inner node: keccak256(left || right), plain concatenation (ENC-A-5)."""
    return keccak(concat(left, right))


def entries_root(leaves):
    """ENC-A-38: leaves right-padded with bytes32(0) to the smallest power of two >= count, inner
    nodes keccak256(left || right); one leaf is its own root and none gives 0."""
    if not leaves:
        return word(0)
    width = 1
    while width < len(leaves):
        width *= 2
    level = leaves + [word(0)] * (width - len(leaves))
    while len(level) > 1:
        level = [node(level[j], level[j + 1]) for j in range(0, len(level), 2)]
    return level[0]


def registry_state(slots):
    """The registry's checkpoint view of `slots`, slot j holding entry `slots[j]` (None: empty).

    count is 0 when every slot is empty and otherwise 1 + the highest occupied slot, occupied slots
    with zero balance included (STAKE-4.1-36), so a nonempty list ends in an occupied slot
    (COMM-4.3-2). Each slot below count is listed, an empty one with all-zero fields, and has the
    slot-indexed leaf that entriesRoot hashes (ENC-A-38).
    """
    occupied = [j for j, entry in enumerate(slots) if entry is not None]
    count = occupied[-1] + 1 if occupied else 0
    assert count == len(slots) <= MAX_COMMITTEE_SIZE, "a nonempty list ends in an occupied slot"
    items, leaves = [], []
    for j, entry in enumerate(slots):
        fields = ZERO_ENTRY if entry is None else entry
        assert entry is None or (entry["ck_prefix"] in (2, 3) and entry != ZERO_ENTRY), j
        items.append({"slot": j, "occupied": entry is not None,
                      **{f: fields[f] for f in ENTRY_FIELDS}})
        leaves.append(reg_leaf(j, fields))
    return {"count": count, "slots": items, "leaves": leaves, "entries_root": entries_root(leaves)}


def registry_entry(i, key):
    """Entry i: (i + 1)·minStake, active from L1 block 10 + i, and an exit at 1000 + i for odd i
    (none, 2^48 - 1, for even i). Every entry is eligible at snapshot 100 (COMM-4.3-3)."""
    return {
        "ck_prefix": int(key["ck_prefix"]),
        "ck_x": key["ck_x"],
        "eff_stake": (i + 1) * DEPLOYMENT["min_stake"],
        "active_from_l1": 10 + i,
        "exit_effective_l1": 1000 + i if i % 2 == 1 else NO_EXIT,
    }


# The checkpoint history of a three-slot registry: name, L1 block, vectors, the change that block
# makes, and the slot contents after it (indexes into the entries, "slashed" for entry 2 after a
# double-sign slash empties it, None for an empty slot). Entry i registered at block i with an
# activation delay of 10; entry 1's exit is at 1001. Bond 0's later exit request, which also
# writes a checkpoint, is not listed.
SLASH_BLOCK = 3_000
CHECKPOINT_HISTORY = (
    (
        "three_bonds",
        2,
        [],
        "bond 2 registers into slot 2 beside bonds 0 and 1 in slots 0 and 1",
        (0, 1, 2),
    ),
    (
        "slot_1_withdrawn",
        2_000,
        ["ENC-A-38 38.h", "COMM-4.3-2 2.d"],
        "bond 1 withdraws from slot 1; slot 2 is still occupied, so count stays 3 and slot 1 is an "
        "all-zero entry",
        (0, None, 2),
    ),
    (
        "slot_2_zero_balance",
        SLASH_BLOCK,
        ["STAKE-4.1-36 36.f"],
        "double-sign slashing empties bond 2 in slot 2 (effStake 0, exitEffectiveL1 3000); the "
        "occupied zero-balance slot still counts",
        (0, None, "slashed"),
    ),
    (
        "slot_2_withdrawn",
        4_000,
        ["STAKE-4.1-36 36.g"],
        "bond 2 withdraws from slot 2: count shrinks to 1",
        (0,),
    ),
    (
        "slot_0_withdrawn",
        5_000,
        ["STAKE-4.1-36 36.g"],
        "bond 0 withdraws from slot 0 in a later block: every slot is empty, count and root are 0",
        (),
    ),
)


def checkpoint_history(entries):
    """Registry checkpoints (l1Block, count, entriesRoot) after each change of CHECKPOINT_HISTORY.
    Earlier checkpoints keep their own count and root (STAKE-4.1-36). The 38.h state also lists
    the wrong roots of ENC-A-38 38.i and COMM-4.3-2 2.e."""
    slashed = {**entries[2], "eff_stake": 0,
               "exit_effective_l1": min(entries[2]["exit_effective_l1"], SLASH_BLOCK)}
    assert all(e["active_from_l1"] == i + 10 for i, e in enumerate(entries))
    out = []
    for name, l1_block, vectors, change, contents in CHECKPOINT_HISTORY:
        slots = [None if c is None else slashed if c == "slashed" else entries[c] for c in contents]
        state = registry_state(slots)
        item = {
            "name": name,
            "vectors": vectors,
            "l1_block": l1_block,
            "change": change,
            **state,
            "checkpoint_word1": pack(PACKED["registry_checkpoint_word1"][2],
                                     (l1_block, state["count"])),
        }
        if name == "slot_1_withdrawn":
            l0, z1, l2 = state["leaves"]
            p = word(0)
            assert z1 == reg_leaf(1, ZERO_ENTRY) != p
            assert state["entries_root"] == node(node(l0, z1), node(l2, p))
            wrong = {
                # 38.i: a zero word instead of Z1, or the zero-field leaf of slot 3 instead of P.
                "zero_word_for_empty_slot": node(node(l0, p), node(l2, p)),
                "zero_entry_padding": node(node(l0, z1), node(l2, reg_leaf(3, ZERO_ENTRY))),
                # 38.i: slot 2 compacted to slot 1; 2.e: slot 1 omitted (slot 2 keeps its leaf).
                "compacted": entries_root([l0, reg_leaf(1, entries[2])]),
                "omitted_empty_slot": entries_root([l0, l2]),
            }
            assert len(set(wrong.values()) | {state["entries_root"]}) == len(wrong) + 1
            item["wrong_roots"] = wrong
        out.append(item)
    assert [c["count"] for c in out] == [3, 3, 3, 1, 0]
    assert out[3]["entries_root"] == out[0]["leaves"][0] and out[4]["entries_root"] == word(0)
    return out


def registry_entries(key_list):
    """Entries in slots 0..4 from keys a1..a5, their leaves, the leaf of an empty slot, the root of
    every fully occupied prefix, a checkpoint history with an interior empty slot, and leaves of
    bonds whose id differs from their slot.

    `regLeaf` is indexed by the slot, never the bond id (appendix A): `bond_slots` pins bond 4096
    taking slot 7 (ENC-A-37 37.e) and bond 2 taking slot 0 (37.g), each the lowest empty slot
    after its holder's withdrawal, with the leaf a bond-id index would give as `bond_id_leaf`.
    """
    entries = [registry_entry(i, key) for i, key in enumerate(key_list[:5])]
    leaves = [reg_leaf(i, entry) for i, entry in enumerate(entries)]
    roots = [
        {"count": n, "entries_root": registry_state(entries[:n])["entries_root"]}
        for n in range(len(entries) + 1)
    ]
    assert roots[1]["entries_root"] == leaves[0]

    key = key_list[5]
    bond_entry = {
        "ck_prefix": int(key["ck_prefix"]),
        "ck_x": key["ck_x"],
        "eff_stake": DEPLOYMENT["min_stake"],
        "active_from_l1": 15,
        "exit_effective_l1": NO_EXIT,
    }
    # Slots 5 and 6 of the 37.e registry hold entries 5 and 6 from keys 0xA6 and 0xA7.
    extra = [registry_entry(i, consensus_key(f"a{i + 1}", 0xA1 + i)) for i in (5, 6)]
    bond_slots = []
    for name, bond_id, slot, vector, description, slots in (
        (
            "full_registry_reuse",
            4096,
            7,
            "ENC-A-37 37.e",
            "bonds 0 to 4095 have been issued; slots 0 to 6 are held, every slot above 7 is empty "
            "and slot 7's bond has withdrawn; the next registration creates bond 4096 in slot 7",
            entries + extra + [bond_entry],
        ),
        (
            "withdrawal_reuse",
            2,
            0,
            "ENC-A-37 37.g",
            "bonds 0 and 1 held slots 0 and 1; bond 0 has withdrawn; the next registration "
            "creates bond 2 in slot 0",
            [bond_entry, entries[1]],
        ),
    ):
        leaf, bond_id_leaf = reg_leaf(slot, bond_entry), reg_leaf(bond_id, bond_entry)
        assert leaf != bond_id_leaf
        state = registry_state(slots)
        assert state["leaves"][slot] == leaf and state["count"] == len(slots)
        bond_slots.append(
            {
                "name": name,
                "vector": vector,
                "description": description,
                "bond_id": bond_id,
                "slot": slot,
                "entry": bond_entry,
                "leaf": leaf,
                "bond_id_leaf": bond_id_leaf,
                **state,
            }
        )
    return decimals(
        {
            "entries": entries,
            "leaves": leaves,
            "empty_slot": {"slot": 1, "leaf": reg_leaf(1, ZERO_ENTRY)},
            "roots": roots,
            "checkpoints": checkpoint_history(entries),
            "bond_slots": bond_slots,
        }
    )


SET_HASH_SIGNATURE = "f(bytes32,uint256,uint256,(uint8,bytes32,uint256,uint64)[])"
RECORD_SIGNATURE = "f(bytes32,uint256,uint256,uint256,uint256,bytes32,uint256)"


@functools.cache
def set_key(chain_id, ck_prefix, ck_x):
    """`setKey(ck)`: four words (ENC-A-39)."""
    return keccak(abi_encode("f(bytes32,uint256,uint256,bytes32)", tag("ETNA_SET_KEY_V1"),
                             chain_id, ck_prefix, ck_x))


def set_hash_preimage(chain_id, k, members):
    """`setHash`'s preimage (ENC-A-39a): four head words (tag, l2ChainId, k, offset 128), then the
    array length and four words per `SetMember(ckPrefix, ckX, effStake, assignedPower)`."""
    array = "[" + ",".join(
        f"({m['ck_prefix']},{m['ck_x']},{m['eff_stake']},{m['power']})" for m in members
    ) + "]"
    preimage = abi_encode(SET_HASH_SIGNATURE, tag("ETNA_SET_V1"), chain_id, k, array)
    assert len(preimage) == 2 + 2 * 32 * (5 + 4 * len(members))
    return preimage


def record_preimage(chain_id, target_epoch, cutoff, checkpoint, set_hash, total_power):
    """`CommitteeRecord`'s preimage: seven words (ENC-A-42)."""
    preimage = abi_encode(RECORD_SIGNATURE, tag("ETNA_COMMITTEE_V1"), chain_id, target_epoch,
                          cutoff, checkpoint, set_hash, total_power)
    assert len(preimage) == 2 + 2 * 224
    return preimage


def select_committee(entries, snapshot, chain_id):
    """Spec 4.3 steps 2-4 over a registry snapshot: eligible entries (activeFromL1 <= snapshot <
    exitEffectiveL1, effStake >= minStake), the first n_max by descending effStake then ascending
    set key, encoded in ascending set-key order with assignedPower = floor(effStake / vp_unit)."""
    eligible = [
        e for e in entries
        if e is not None and e["active_from_l1"] <= snapshot < e["exit_effective_l1"]
        and e["eff_stake"] >= DEPLOYMENT["min_stake"]
    ]
    keyed = [(e, int(set_key(chain_id, e["ck_prefix"], e["ck_x"]), 16)) for e in eligible]
    assert len({k for _, k in keyed}) == len(keyed)  # lifetime-unique keys (COMM-4.3-4)
    chosen = sorted(keyed, key=lambda item: (-item[0]["eff_stake"], item[1]))[:N_MAX]
    members = []
    for entry, key in sorted(chosen, key=lambda item: item[1]):
        power = entry["eff_stake"] // VP_UNIT
        assert 0 < power < 2**64
        members.append({
            "ck_prefix": entry["ck_prefix"],
            "ck_x": entry["ck_x"],
            "eff_stake": entry["eff_stake"],
            "power": power,
            "set_key": word(key),
        })
    assert sum(m["power"] for m in members) <= MAX_TOTAL_VOTING_POWER
    return members


def committee_sets(entries):
    """Committees selected from registries holding the first 0, 1, 3 and 5 entries, at snapshot
    100 (spec 4.3), per appendix A.

    Members are in ascending set-key order; one setHash with `k = targetEpoch + 1` commits the
    whole set. Spec 4.3 rejects an empty committee, so the 0-member case carries no hash or record.
    """
    chain_id = DEPLOYMENT["l2_chain_id"]
    entries = [{f: e[f] if f == "ck_x" else int(e[f]) for f in ENTRY_FIELDS} for e in entries]
    target_epoch, cutoff, checkpoint = 7, 100, 3
    k = target_epoch + 1
    # Selection applies the registry minimum: one base unit below it is ineligible (COMM-4.3-3).
    below = {**entries[0], "eff_stake": DEPLOYMENT["min_stake"] - 1}
    assert select_committee([below], cutoff, chain_id) == []
    cases = []
    for count in (0, 1, 3, 5):
        members = select_committee(entries[:count], cutoff, chain_id)
        assert sorted(m["ck_x"] for m in members) == sorted(e["ck_x"] for e in entries[:count])
        if count == 0:
            assert members == []
            cases.append({"members": [], "valid": False, "reason": "empty_committee"})
            continue
        set_preimage = set_hash_preimage(chain_id, k, members)
        set_hash = keccak(set_preimage)
        total_power = sum(member["power"] for member in members)
        record = record_preimage(chain_id, target_epoch, cutoff, checkpoint, set_hash, total_power)
        cases.append(
            {
                "valid": True,
                "l2_chain_id": chain_id,
                "target_epoch": target_epoch,
                "set_version": k,
                "cutoff_l1_block": cutoff,
                "checkpoint_index": checkpoint,
                "members": members,
                "set_hash_preimage": set_preimage,
                "set_hash": set_hash,
                "total_power": total_power,
                "record_preimage": record,
                "record_hash": keccak(record),
            }
        )
    return decimals(cases)


# --- cuts, statements, land ABI ------------------------------------------------------------------


def validator_states():
    """ENC-A-29a.l encoding-only example; synthetic keys do not assert canonical set order."""
    signature = (
        "f(bytes32,uint256,(uint8,bytes32,uint64,int64)[],uint256,"
        "(uint8,bytes32,uint64,int64)[],uint256)"
    )
    current = f"[(2,{word(1)},10,-5),(3,{word(2)},10,5)]"
    next_set = f"[(2,{word(1)},10,5),(3,{word(2)},10,-5)]"

    def encode(current_proposer, next_proposer):
        return abi_encode(
            signature, tag("ETNA_VAL_STATE_V1"), 6,
            current, current_proposer, next_set, next_proposer,
        )

    def entry(prefix, x, priority):
        return {
            "ck_prefix": str(prefix), "ck_x": word(x),
            "voting_power": "10", "proposer_priority": str(priority),
        }

    preimage = encode(1, 0)
    digest = keccak(preimage)
    assert digest == "0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b"
    return [{
        "name": "ENC-A-29a.l",
        "height": "6",
        "current_proposer": "1",
        "next_proposer": "0",
        "current": [entry(2, 1, -5), entry(3, 2, 5)],
        "next": [entry(2, 1, 5), entry(3, 2, -5)],
        "preimage": preimage,
        "hash": digest,
        "changed_current_proposer_hash": keccak(encode(0, 0)),
        "changed_next_proposer_hash": keccak(encode(1, 1)),
    }]


def app_hashes(states):
    """ENC-A-29b.g: appHash(6) of EL hash 0x11..11 and 29a.l's validator-state hash, three words
    (96 bytes). No L1 record, cut leaf or statement holds either hash."""
    (state,) = states
    block_hash = "0x" + "11" * 32
    preimage = abi_encode(
        "f(bytes32,bytes32,bytes32)", tag("ETNA_APP_HASH_V1"), block_hash, state["hash"]
    )
    digest = keccak(preimage)
    assert digest == "0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451"
    return [{
        "name": "ENC-A-29b.g",
        "height": state["height"],
        "block_hash": block_hash,
        "val_state_hash": state["hash"],
        "preimage": preimage,
        "hash": digest,
    }]


def cut_at(x):
    """The cut at height x: EL hash 100 + x, Comet hash 200 + x (0 at x = 0) and FI cursor
    x / FI_STEP, which advances by 0 or 1 per block."""
    return {
        "height": x,
        "block_hash": word(100 + x),
        "comet_hash": word(0 if x == 0 else 200 + x),
        "forced_head": x // FI_STEP,
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


def cut_leaves(p, h):
    """The leaves `land` carries for (p, h]: cutLeaf(p+1) .. cutLeaf(h-1), one per height."""
    return [cut_leaf(x)[1] for x in range(p + 1, h)]


# name, Etna start S, generation, p, h. The list has the h - p - 1 leaves of the heights strictly
# between p and h, so h = p + 1 gives the empty list (ENC-A-32) and h = p + 2 one leaf (31.e); S
# does not enter the hash, and the S = 1000 case is 33.f's landing with leaves at 1001 and 1002.
CUT_CASES = (
    ("g0_p0_h1", 0, 0, 0, 1),
    ("g0_p0_h2", 0, 0, 0, 2),
    ("g0_p0_h6", 0, 0, 0, 6),
    ("g0_p0_h18", 0, 0, 0, 18),
    ("g1_p6_h18", 0, 1, 6, 18),
    ("g2_p17_h18", 0, 2, 17, 18),
    ("s1000_g0_p1000_h1003", 1000, 0, 1000, 1003),
)


def cuts():
    table = []
    for x in range(19):
        preimage, leaf = cut_leaf(x)
        table.append({**cut_at(x), "preimage": preimage, "leaf": leaf})
    cut_hashes = []
    for name, start, generation, p, h in CUT_CASES:
        assert start <= p < h
        leaves = cut_leaves(p, h)
        assert len(leaves) == h - p - 1
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
                "etna_start": start,
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
        assert len(preimage) == 2 + 2 * 672
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
    leaves = cut_leaves(p, h)
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


def go_env():
    """The environment for `go run`: the caller's GOFLAGS (e.g. `-p=2`) plus `-mod=readonly`, and no
    workspace, so each module builds from its own go.mod and go.sum."""
    flags = " ".join(filter(None, [os.environ.get("GOFLAGS", ""), "-mod=readonly"]))
    return {**os.environ, "GOFLAGS": flags, "GOWORK": "off"}


# --- votes: CometBFT v0.40.0 sign bytes and secp256k1eth signatures ------------------------------

VOTEGEN = HERE / "votegen"
PREVOTE, PRECOMMIT = 1, 2
VOTE_HEIGHT = 1000
VOTE_TIME = (1_700_000_000, 123)
# The first (0001-01-01T00:00:00Z) and last (9999-12-31T23:59:59Z) seconds that protobuf's
# Timestamp, and so CometBFT's VoteSignBytes, can encode; CometBFT panics outside them. It signs
# and accepts negative (pre-1970) timestamps, and each vote carries its own, so a validator can
# backdate both votes of a double sign.
MIN_VOTE_SECONDS = -62_135_596_800
MAX_VOTE_SECONDS = 253_402_300_799
# Block ids as (hash, part set total, part set hash). Only "0x" is absent; zero32 is present.
BLOCK_A = ("0x" + "aa" * 32, 1, "0x" + "ab" * 32)
BLOCK_B = ("0x" + "bb" * 32, 2, "0x" + "bc" * 32)
BLOCK_NIL = ("0x", 0, "0x")
BLOCK_PARTIAL = ("0x", 1, "0x" + "ab" * 32)
# A hash with an all-zero part set header: CometBFT writes the empty header as `12 00`.
BLOCK_HASH_ONLY = (BLOCK_A[0], 0, "0x")
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
    ("precommit_b_h1001", PRECOMMIT, 0, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("hash_only_block_id", PRECOMMIT, 0, BLOCK_HASH_ONLY, 0, DEPLOYMENT["inbox"]),
    ("zero_timestamp", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("negative_timestamp", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("min_timestamp", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("max_timestamp_seconds", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("precommit_a_backdated", PRECOMMIT, 0, BLOCK_A, 0, DEPLOYMENT["inbox"]),
    ("precommit_b_backdated", PRECOMMIT, 0, BLOCK_B, 0, DEPLOYMENT["inbox"]),
    ("precommit_zero_block_hash", PRECOMMIT, 0, (word(0), 1, BLOCK_A[2]), 0, DEPLOYMENT["inbox"]),
    ("precommit_zero_parts_hash", PRECOMMIT, 0, (BLOCK_A[0], 1, word(0)), 0, DEPLOYMENT["inbox"]),
    ("precommit_zero_both_hashes", PRECOMMIT, 0, (word(0), 1, word(0)), 0, DEPLOYMENT["inbox"]),
    ("zero_hashes_zero_total", PRECOMMIT, 0, (word(0), 0, word(0)), 0, DEPLOYMENT["inbox"]),
    ("zero_block_hash_only", PRECOMMIT, 0, (word(0), 0, "0x"), 0, DEPLOYMENT["inbox"]),
    ("zero_parts_hash_only", PRECOMMIT, 0, ("0x", 0, word(0)), 0, DEPLOYMENT["inbox"]),
)
VOTE_OVERRIDES = {
    "precommit_a_late": {"time": (1_700_000_001, 0)},
    "max_values": {"height": 2**63 - 1, "time": (MAX_VOTE_SECONDS, 999_999_999)},
    "precommit_b_h1001": {"height": VOTE_HEIGHT + 1},
    # The Unix epoch: both timestamp fields are zero, so CometBFT writes the timestamp as `2a 00`.
    "zero_timestamp": {"time": (0, 0)},
    # Negative seconds are written as protobuf's int64 varint, the ten-byte uvarint of their
    # 64-bit two's-complement pattern.
    "negative_timestamp": {"time": (-1, 123)},
    "min_timestamp": {"time": (MIN_VOTE_SECONDS, 0)},
    "max_timestamp_seconds": {"time": (MAX_VOTE_SECONDS, 0)},
    "precommit_a_backdated": {"time": (-1, 0)},
    "precommit_b_backdated": {"time": (-1, 0)},
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
    # Each of the next three conflicts on the block id and differs in exactly one other field.
    (
        "different_round_conflicting_blocks",
        "prevote_a_r1",
        "prevote_b_r2",
        0,
        "different_round",
    ),
    # Spec 4.1 needs the same generation: votes for one height in two generations are not a
    # double sign, even though both generations are at or below the current one.
    ("different_generation", "precommit_a", "gen1_precommit_b", 1, "different_generation"),
    ("different_height", "precommit_a", "precommit_b_h1001", 0, "different_height"),
    # Backdated votes still count in CometBFT commits, so they are slashable evidence.
    ("backdated_conflict", "precommit_a_backdated", "precommit_b_backdated", 0, "double_sign"),
    ("zero_block_hash_conflict", "precommit_a", "precommit_zero_block_hash", 0, "double_sign"),
    ("zero_parts_hash_conflict", "precommit_a", "precommit_zero_parts_hash", 0, "double_sign"),
    ("zero_both_hashes_conflict", "precommit_nil", "precommit_zero_both_hashes", 0, "double_sign"),
    ("zero_hashes_zero_total_conflict", "precommit_nil", "zero_hashes_zero_total", 0, "double_sign"),
    ("zero_block_hash_only_conflict", "precommit_nil", "zero_block_hash_only", 0, "double_sign"),
    ("zero_parts_hash_only_conflict", "precommit_nil", "zero_parts_hash_only", 0, "double_sign"),
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


def varint_int64(value):
    """Protobuf varint of an int64: the uvarint of its 64-bit two's-complement pattern."""
    assert -(2**63) <= value < 2**63, value
    return uvarint(value % 2**64)


def length_delimited(tag_byte, payload):
    """`tag || uvarint(len(payload)) || payload`."""
    return bytes([tag_byte]) + uvarint(len(payload)) + payload


def vote_sign_bytes(vote, chain_id):
    """Appendix A `voteSignBytes`, written from the spec text alone (not from CometBFT).

    Numeric fields are omitted when zero; hash fields only when empty. A nil vote (both hashes
    empty and total zero) omits the whole block id. Timestamp seconds
    are a signed int64 (`timestampSecondsU64` is their two's-complement pattern).
    """
    vote_type, height, round_ = (int(vote[k]) for k in ("voteType", "height", "round"))
    total, seconds, nanos = (
        int(vote[k]) for k in ("partsTotal", "timestampSeconds", "timestampNanos")
    )
    block_hash, parts_hash = (bytes.fromhex(vote[k][2:]) for k in ("blockHash", "partsHash"))
    assert vote_type in (PREVOTE, PRECOMMIT) and 0 <= height < 2**63 and 0 <= round_ < 2**31
    assert 0 <= total < 2**32 and MIN_VOTE_SECONDS <= seconds <= MAX_VOTE_SECONDS
    assert int(vote["timestampSecondsU64"]) == seconds % 2**64 and 0 <= nanos < 10**9
    assert len(block_hash) in (0, 32) and len(parts_hash) in (0, 32) and len(chain_id) == 48

    psh = (b"\x08" + uvarint(total) if total else b"") + (
        length_delimited(0x12, parts_hash) if parts_hash else b""
    )
    block_id = (length_delimited(0x0A, block_hash) if block_hash else b"") + (
        length_delimited(0x12, psh)
    )
    is_nil = not block_hash and total == 0 and not parts_hash
    timestamp = (b"\x08" + varint_int64(seconds) if seconds else b"") + (
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
            "timestampSecondsU64": seconds % 2**64,
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
        env=go_env(),
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
            "slash_abi": slash_vote_abi(by_name),
        }
    )


def slash_vote_abi(cases):
    """Pin the registry ABI, including present zero32 and empty dynamic hash fields."""
    vote_type = "(uint8,uint64,uint32,bytes,uint32,bytes,uint64,uint32,uint48,bytes)"
    signature = "slashDoubleSign(uint256," + vote_type + "," + vote_type + ")"
    a, b = "precommit_a", "precommit_zero_parts_hash"

    def argument(case):
        vote = case["vote"]
        fields = ("voteType", "height", "round", "blockHash", "partsTotal", "partsHash",
                  "timestampSecondsU64", "timestampNanos", "generation")
        return "(" + ",".join(vote[field] for field in fields) + "," + case["signature"] + ")"

    return {"signature": signature, "selector": cast("sig", signature), "bond_id": "0",
            "a": a, "b": b,
            "calldata": cast("calldata", signature, 0, argument(cases[a]), argument(cases[b]))}


# --- validator-state chains: CometBFT v0.40.0 (ENC-A-29a, SYNC-9-5c) ----------------------------

VALGEN = HERE / "valgen"
VAL_STATE_SIGNATURE = (
    "f(bytes32,uint256,(uint8,bytes32,uint64,int64)[],uint256,"
    "(uint8,bytes32,uint64,int64)[],uint256)"
)
VAL_KEYS = tuple((f"c{i}", 0xC0 + i) for i in range(1, 13))  # validator keys c1..c12
VAL_GENESIS_TIME = 1_700_000_000
MAX_COMMITTEE_KEY = 0x10000  # member i of the maximum committee has private key 0x10000 + i
# Rows shown from each end of a maximum-committee set; the full sets follow from the rules.
MAX_COMMITTEE_SAMPLE = 3

# Each chain is one CometBFT chain from a genesis at start height o. FinalizeBlock returns validator
# updates only at S(t) = H(t) - 2 = t·L - 1 (4.2, 4.3; H(t) = 1 + t·L counts from block 0 for any
# S), each the change from the pending committee to epoch t's: new members at their power, leaving
# members at 0 and re-weighted members at their new power. `expect` names events the chain exists
# to show: (height, step, kind, fields) that the model must log.
VAL_CHAINS = (
    {
        "name": "gen0",
        "description": (
            "Generation 0 from the Etna start S = 0 with L = 7: genesis at 0, every single-height "
            "increment through 48, and switches at S(1)..S(7) that add (6), remove (13), re-weight "
            "(20), add, remove and re-weight at once (27), add (34), replace the largest member "
            "(41) and re-weight (48). Equal powers order by address; ties go to the lower address."
        ),
        "generation": 0,
        "start": 0,
        "end": 48,
        "epoch_length": 7,
        "genesis": (("c1", 30), ("c2", 30), ("c3", 20), ("c4", 10)),
        "switches": {
            6: (("c5", 25),),
            13: (("c4", 0),),
            20: (("c3", 45),),
            27: (("c6", 15), ("c2", 0), ("c1", 20)),
            34: (("c8", 20),),
            41: (("c3", 0), ("c9", 1)),
            48: (("c5", 50),),
        },
        "expect": (
            (0, "genesis", "tie", {"tied": ["c1", "c2"], "proposer": "c1"}),
            (6, "update", "center", {}),
            (27, "update", "rescale", {"fires": True}),
            (41, "update", "rescale", {"fires": True}),
        ),
    },
    {
        "name": "gen1",
        "description": (
            "Generation 1 from governance recovery at c = 48 (8.4): a new genesis at 48 with a "
            "different committee and initial height 49. Generation 0's update returned at "
            "S(7) = 48 is discarded with the rest of its state; the next switch is S(8) = 55 "
            "(add one member, remove another), active from H(8) = 57."
        ),
        "generation": 1,
        "start": 48,
        "end": 60,
        "epoch_length": 7,
        "genesis": (("c3", 40), ("c6", 15), ("c10", 25), ("c11", 25)),
        "switches": {55: (("c12", 10), ("c6", 0))},
        "expect": ((48, "genesis_next", "tie", {"tied": ["c10", "c11"], "proposer": "c10"}),),
    },
    {
        "name": "bounds_a",
        "description": (
            "L = 3. At S(1) = 2 the update leaves a priority spread of exactly 2·total, so "
            "neither UpdateWithChangeSet nor IncrementProposerPriority rescales; the increment "
            "raises it to 2·total + 1, so height 3 rescales by 2 and then centers a sum of -1 by "
            "floor(-1 / 4) = -1, leaving the largest residual sum, n - 1."
        ),
        "generation": 0,
        "start": 0,
        "end": 4,
        "epoch_length": 3,
        "genesis": (("c2", 2), ("c9", 2), ("c1", 12), ("c4", 8)),
        "switches": {2: (("c12", 1), ("c4", 0))},
        "expect": (
            (2, "update", "rescale", {"fires": False}),
            (2, "increment", "rescale", {"fires": False}),
            (3, "increment", "rescale", {"fires": True, "ratio": 2}),
            (3, "increment", "center", {"sum": -1, "shift": -1}),
        ),
    },
    {
        "name": "bounds_b",
        "description": (
            "L = 3. Height 3 rescales a spread of 2·total + 1 left by the switch at S(1) = 2; the "
            "switch at S(2) = 5 leaves a spread of 2·total + 1 inside UpdateWithChangeSet, whose "
            "rescale truncates negative priorities toward zero."
        ),
        "generation": 0,
        "start": 0,
        "end": 6,
        "epoch_length": 3,
        "genesis": (("c3", 6), ("c6", 4), ("c12", 11), ("c10", 5)),
        "switches": {2: (("c10", 0), ("c9", 1)), 5: (("c12", 0),)},
        "expect": (
            (2, "update", "center", {}),
            (3, "increment", "rescale", {"fires": True, "ratio": 2}),
            (5, "update", "rescale", {"fires": True, "ratio": 2, "truncated": ["c6", "c9"]}),
        ),
    },
    {
        "name": "bounds_c",
        "description": (
            "L = 3. Three members of equal power: genesis and later increments break priority ties "
            "by address. Height 3 has no update and increments a set whose spread is exactly "
            "2·total, which is not rescaled."
        ),
        "generation": 0,
        "start": 0,
        "end": 4,
        "epoch_length": 3,
        "genesis": (("c4", 1), ("c3", 1), ("c8", 1), ("c9", 3)),
        "switches": {2: (("c9", 0),)},
        "expect": (
            (0, "genesis_next", "tie", {"tied": ["c8", "c3", "c4"], "proposer": "c8"}),
            (3, "increment", "rescale", {"fires": False}),
        ),
    },
)

def max_committee_power(index):
    """2^48 + (i mod 64) - 32 for i < 4095, and the rest of MaxTotalVotingPower for i = 4095."""
    if index < MAX_COMMITTEE_SIZE - 1:
        return 2**48 + index % 64 - 32
    return MAX_TOTAL_VOTING_POWER - sum(map(max_committee_power, range(MAX_COMMITTEE_SIZE - 1)))


def run_valgen(request):
    """CometBFT v0.40.0's states of every chain (`valgen/`, run with `go run`)."""
    result = subprocess.run(
        ["go", "run", "."],
        cwd=VALGEN,
        input=json.dumps(request),
        capture_output=True,
        text=True,
        env=go_env(),
    )
    if result.returncode != 0:
        raise SystemExit(f"valgen failed:\n{result.stderr}")
    return json.loads(result.stdout)


def keccak_stdin(data):
    """`cast keccak` with the data on stdin, for inputs too large for one argument."""
    return subprocess.run(
        ["cast", "keccak"], input=data, capture_output=True, text=True, check=True
    ).stdout.strip()


def epoch_roles(epoch_length, height):
    """`S(t)`, `S(t)+1` or `H(t)` when `height` is one of them (S(t) = t·L - 1, H(t) = t·L + 1)."""
    roles = []
    for name, offset in (("S", -1), ("S+1", 0), ("H", 1)):
        t, rest = divmod(height - offset, epoch_length)
        if rest == 0 and t >= 1:
            roles.append(f"{name[0]}({t}){name[1:]}")
    return roles


# Rows per `cast abi-encode` argument: Linux limits one argument to 128 KiB (MAX_ARG_STRLEN), and a
# maximum-committee set written as one argument is about 400 KB.
VAL_STATE_ROWS_PER_ARG = 512


def val_state_preimage(height, sets, key_info):
    """Appendix A's preimage of valStateHash, encoded by `cast abi-encode`.

    A set too large for one argument is encoded in pieces: the head's six words as plain words
    (tag, x, the first array's offset 192, its proposer, the second array's offset and its
    proposer), then each array as its length and the rows of `cast abi-encode` of consecutive
    slices, which is the same standard ABI encoding.
    """

    def rows(entries):
        out = []
        for key, power, priority in entries:
            info = key_info[key]
            out.append(f"({info['ck_prefix']},{info['ck_x']},{power},{priority})")
        return out

    def array(entries):
        return "[" + ",".join(rows(entries)) + "]"

    (current, current_proposer), (following, next_proposer) = sets
    if max(len(current), len(following)) <= VAL_STATE_ROWS_PER_ARG:
        return abi_encode(
            VAL_STATE_SIGNATURE,
            tag("ETNA_VAL_STATE_V1"),
            height,
            array(current),
            current_proposer,
            array(following),
            next_proposer,
        )

    def array_words(entries):
        out = word(len(entries))[2:]
        for i in range(0, len(entries), VAL_STATE_ROWS_PER_ARG):
            part = abi_encode(
                "f((uint8,bytes32,uint64,int64)[])", array(entries[i : i + VAL_STATE_ROWS_PER_ARG])
            )
            # Drop the offset and length words; what is left is the slice's rows.
            out += part[2 + 128 :]
        assert len(out) == 64 * (1 + 4 * len(entries))
        return out

    head = abi_encode(
        "f(bytes32,uint256,uint256,uint256,uint256,uint256)",
        tag("ETNA_VAL_STATE_V1"),
        height,
        192,
        current_proposer,
        192 + 32 * (1 + 4 * len(current)),
        next_proposer,
    )
    return head + array_words(current) + array_words(following)


def check_val_states(chain, generated, key_info, address):
    """Each CometBFT state must match the model, be in set order, and have the preimage and hash
    that `cast` computes. Returns the states as `(height, current, cp, next, np, preimage, hash)`
    and the model's events."""
    updates = {h: tuple(c) for h, c in chain["switches"].items()}
    model_states, events = valset_model.replay(
        address, chain["start"], chain["end"], chain["genesis"], updates
    )
    assert len(generated) == len(model_states), chain["name"]
    out = []
    for state, (height, model_current, model_next) in zip(generated, model_states):
        assert int(state["height"]) == height, (chain["name"], height)
        sets = []
        for side, model_set in (("current", model_current), ("next", model_next)):
            entries = [
                (e["key"], int(e["voting_power"]), int(e["proposer_priority"]))
                for e in state[side]
            ]
            for e in state[side]:
                info = key_info[e["key"]]
                assert (int(e["ck_prefix"]), e["ck_x"]) == (info["ck_prefix"], info["ck_x"])
            proposer = int(state[side + "_proposer"])
            assert 0 <= proposer < len(entries)
            # CometBFT's set order: voting power descending, then address ascending.
            order = [(-power, address[key]) for key, power, _ in entries]
            assert order == sorted(order) and len(set(order)) == len(order), (chain["name"], height)
            if [list(e) for e in entries] != model_set.entries() or (
                proposer != model_set.proposer_index()
            ):
                raise SystemExit(
                    f"{chain['name']} height {height} {side}: CometBFT v0.40.0 and the model "
                    f"differ\n  CometBFT: {entries} proposer {proposer}\n"
                    f"  model:    {model_set.entries()} proposer {model_set.proposer_index()}"
                )
            sets.append((entries, proposer))
        preimage = val_state_preimage(height, sets, key_info)
        # A maximum-committee preimage (about 1 MiB) is too large for one command-line argument.
        digest = keccak_stdin(preimage) if len(preimage) > 100_000 else keccak(preimage)
        assert preimage == state["preimage"], (chain["name"], height)
        assert digest == state["hash"], (chain["name"], height)
        out.append((height, *sets[0], *sets[1], preimage, digest))
    for height, step, kind, fields in chain.get("expect", ()):
        matches = [
            e
            for e in events
            if (e["height"], e["step"], e["kind"]) == (height, step, kind)
            and all(e.get(k) == v for k, v in fields.items())
        ]
        assert len(matches) == 1, (chain["name"], height, step, kind, fields, events)
    return out, events


def val_state_keys():
    """Keys c1..c12 with the fields a ValEntry needs and the address that orders a set."""
    out = []
    for name, k in VAL_KEYS:
        x, y = point(k)
        private_key = word(k)
        ck_addr = address_of(x, y)
        assert ck_addr == cast("wallet", "address", "--private-key", private_key).lower(), name
        out.append(
            {
                "name": name,
                "private_key": private_key,
                "public_key": "0x" + compress(x, y).hex(),
                "ck_prefix": 2 + (y & 1),
                "ck_x": word(x),
                "ck_y": word(y),
                "ck_addr": ck_addr,
            }
        )
    return out


def max_committee_keys():
    """The maximum committee's keys (`m0`..`m4095`, private key 0x10000 + i) by consecutive point
    additions; every address is checked with `cast keccak`."""
    out, current = [], point(MAX_COMMITTEE_KEY)
    for i in range(MAX_COMMITTEE_SIZE):
        if i:
            current = _add(current, SECP_G)
        x, y = current
        out.append(
            {
                "name": f"m{i}",
                "private_key": word(MAX_COMMITTEE_KEY + i),
                "public_key": "0x" + compress(x, y).hex(),
                "ck_prefix": 2 + (y & 1),
                "ck_x": word(x),
                "xy": (x, y),
            }
        )
    assert current == point(MAX_COMMITTEE_KEY + MAX_COMMITTEE_SIZE - 1)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        addresses = list(pool.map(lambda key: address_of(*key["xy"]), out))
    for key, ck_addr in zip(out, addresses):
        key["ck_addr"] = ck_addr
        del key["xy"]
    return out


def val_state_chains(domains):
    """Validator-state hashes that stock CometBFT v0.40.0 computes (`valgen/`), checked against
    `valset_model.py` and appendix A's encoding."""
    chain_ids = {
        int(d["generation"]): d["chain_id"] for d in domains if d["inbox"] == DEPLOYMENT["inbox"]
    }
    keys_small = val_state_keys()
    keys_max = max_committee_keys()
    key_info = {k["name"]: k for k in keys_small + keys_max}
    address = {name: info["ck_addr"][2:] for name, info in key_info.items()}

    max_chain = {
        "name": "max_committee",
        "generation": 0,
        "start": 0,
        "end": 1,
        "epoch_length": None,
        "genesis": tuple((f"m{i}", max_committee_power(i)) for i in range(MAX_COMMITTEE_SIZE)),
        "switches": {},
    }
    assert sum(p for _, p in max_chain["genesis"]) == MAX_TOTAL_VOTING_POWER
    chains = VAL_CHAINS + (max_chain,)
    for chain in VAL_CHAINS:
        for height in chain["switches"]:
            assert epoch_roles(chain["epoch_length"], height)[:1] == [
                f"S({(height + 1) // chain['epoch_length']})"
            ], (chain["name"], height)
    request = {
        "keys": [{"name": k["name"], "private_key": k["private_key"]} for k in key_info.values()],
        "chains": [
            {
                "name": chain["name"],
                "chain_id": chain_ids[chain["generation"]],
                "start_height": str(chain["start"]),
                "end_height": str(chain["end"]),
                "genesis_time": str(VAL_GENESIS_TIME + chain["start"]),
                "genesis": [{"key": k, "power": str(p)} for k, p in chain["genesis"]],
                "updates": [
                    {"height": str(h), "changes": [{"key": k, "power": str(p)} for k, p in c]}
                    for h, c in sorted(chain["switches"].items())
                ],
            }
            for chain in chains
        ],
    }
    result = run_valgen(request)
    for generated in result["keys"]:
        info = key_info[generated["name"]]
        assert generated["public_key"] == info["public_key"], generated["name"]
        assert generated["address"] == info["ck_addr"], generated["name"]
    generated = {c["name"]: c["states"] for c in result["chains"]}

    chain_out = []
    for chain in VAL_CHAINS:
        states, events = check_val_states(chain, generated[chain["name"]], key_info, address)
        chain_out.append(
            {
                "name": chain["name"],
                "description": chain["description"],
                "generation": chain["generation"],
                "start_height": chain["start"],
                "end_height": chain["end"],
                "epoch_length": chain["epoch_length"],
                "genesis": [list(m) for m in chain["genesis"]],
                "switches": [
                    {
                        "epoch": (height + 1) // chain["epoch_length"],
                        "height": height,
                        "activation_height": height + 2,
                        "changes": [list(c) for c in changes],
                    }
                    for height, changes in sorted(chain["switches"].items())
                ],
                "start_preimage": states[0][5],
                "states": [
                    {
                        "height": height,
                        "current": [list(e) for e in current],
                        "current_proposer": cp,
                        "next": [list(e) for e in following],
                        "next_proposer": np_,
                        "hash": digest,
                    }
                    for height, current, cp, following, np_, _, digest in states
                ],
                "events": events,
            }
        )

    max_states, max_events = check_val_states(
        max_chain, generated["max_committee"], key_info, address
    )

    def sample(entries):
        return [list(e) for e in entries[:MAX_COMMITTEE_SAMPLE]], [
            list(e) for e in entries[-MAX_COMMITTEE_SAMPLE:]
        ]

    max_out = []
    for height, current, cp, following, np_, preimage, digest in max_states:
        current_head, current_tail = sample(current)
        next_head, next_tail = sample(following)
        max_out.append(
            {
                "height": height,
                "current_head": current_head,
                "current_tail": current_tail,
                "current_proposer": cp,
                "next_head": next_head,
                "next_tail": next_tail,
                "next_proposer": np_,
                "preimage_bytes": len(preimage) // 2 - 1,
                "hash": digest,
            }
        )
    return decimals(
        {
            "cometbft": "v0.40.0",
            "keys": keys_small,
            "chains": chain_out,
            "max_committee": {
                "description": (
                    "4096 members (n_max's bound) at CometBFT's MaxTotalVotingPower: genesis at "
                    "0 and one increment. Member i (0 <= i < 4096) is key mi with private key "
                    "0x10000 + i; its power is 2^48 + (i mod 64) - 32 for i < 4095, and member "
                    "4095 takes the rest of the total, 2^48 + 2078. Only the hash and the first "
                    "and last rows of each set are listed."
                ),
                "size": MAX_COMMITTEE_SIZE,
                "first_private_key": word(MAX_COMMITTEE_KEY),
                "total_power": MAX_TOTAL_VOTING_POWER,
                "last_member_power": max_committee_power(MAX_COMMITTEE_SIZE - 1),
                "start_height": max_chain["start"],
                "states": max_out,
                "events": max_events,
            },
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
        # Spec 7.2: eligibility ignores fees, even a tip above the fee cap.
        (
            "eip1559_tip_above_max_fee",
            "eligible",
            fi_encode(2, eip1559(max_priority_fee=3 * GWEI, max_fee=2 * GWEI)),
        ),
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
        env=go_env(),
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
    "inbox_293": (
        "inbox",
        "rules_schedule",
        ("active_rules", "next_rules", "rules_time", "stop_time"),
        (1, 2, 1_700_003_600, 1_700_007_200),
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
    # STOR-B-24: slot 293 packs four 48-bit fields, so bits 192 and up stay zero.
    assert all(int(item["word"], 16) >> 192 == 0 for item in out["inbox_293"])
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
    "recovery_nonce": 292,
    "rules_schedule": 293,
}
RESERVED_SLOTS = (283, 286, 287, 288, 289, 291)
ANCHOR_SLOTS = (268, 270, 271, 281, 293)


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
                for bond_id in (0, 4096)
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
        "top_ups": namespace("taiko.etna.registry.top-ups"),
        # STOR-B-32: the lifetime forfeiture flag, a mapping from uint256 bondId to bool.
        "forfeitures": namespace("taiko.etna.registry.forfeitures"),
    }
    for entry in registry["top_ups"]["slots"]:
        entry["ready_slot"] = word(int(entry["slot"], 16) + 1)
    return decimals({"inbox": inbox, "registry": registry})


# The Etna start used by the start ABI and event vectors: S = 1000 with the hash and stateRoot that
# setOrigin(S) copies from the Unzen Inbox's final proof and the SignalService checkpoint at S.
START = (1000, word(0x51), word(0x52))
# The forced inclusion bytes and fee of the FI ABI and event vectors; encoding is not checked at
# submission (spec 7.1), so one byte suffices.
FI_TX = "0xc0"
FI_FEE_WEI = 1_000_000_000
# The recovery and governance call arguments shared by the ABI and event vectors: the generation
# the schedule calls expect, recover's exclusions (strictly increasing bond ids, ENC-A-51 51.a) and
# the forced inclusion indexes it clears, and the incident id of a forfeiture.
EXPECTED_GENERATION = 1
EXCLUSIONS = (1, 5, 9)
FI_TO_CLEAR = (3, 5)
INCIDENT_ID = word(42)
VALID_UNTIL = 1_700_000_123
# The Unzen Inbox's proposeCutoff() on a switching network: ETNA_FORK_TIME - PROPOSE_MARGIN, here
# a fork time of 1,700,000,000 and the 12 s margin (START-10-5a, PARAM-11-12b).
PROPOSE_CUTOFF = 1_700_000_000 - 12


def uint_list(values):
    return "[" + ",".join(map(str, values)) + "]"


def governance_abi():
    """Executable appendix A governance calldata, independently checked by contract consumers."""
    calls = {
        "top_up": ("topUp(uint256,uint256)", [0, 100]),
        "activate_top_up": ("activateTopUp(uint256)", [0]),
        "forfeit": ("forfeit(uint256,bytes32,uint256)", [0, INCIDENT_ID, VALID_UNTIL]),
        "recover": (
            "recover(uint48,uint256,uint256,uint256,uint256[],uint256[],uint48)",
            [2, 12, 7, VALID_UNTIL, uint_list(EXCLUSIONS), uint_list(FI_TO_CLEAR), 4],
        ),
        "invalidate_recovery_nonce": ("invalidateRecoveryNonce(uint256)", [7]),
        "schedule_rules": (
            "scheduleRules(uint48,uint48,uint48)",
            [EXPECTED_GENERATION, 2, 1_700_003_600],
        ),
        "schedule_stop": ("scheduleStop(uint48,uint48)", [EXPECTED_GENERATION, 1_700_007_200]),
        "set_origin": ("setOrigin(uint48)", [START[0]]),
        "save_forced_inclusion": ("saveForcedInclusion(bytes)", [FI_TX]),
        "sweep_protocol_fees": ("sweepProtocolFees()", []),
    }
    assert list(EXCLUSIONS) == sorted(set(EXCLUSIONS))
    return {
        name: {
            "signature": signature,
            "selector": cast("sig", signature),
            "calldata": cast("calldata", signature, *args),
        }
        for name, (signature, args) in calls.items()
    }


def forfeitures():
    """Principal deductions, including pending-only and overflowing intermediate products."""
    out = []
    for effective, pending, rate in (
        (100, 0, 1000),
        (2, 98, 1000),
        (1, 0, 1),
        (0, 3, 10000),
        (WORD_MOD - 1, 0, 10000),
    ):
        balance = effective + pending
        penalty = (balance * rate + 9999) // 10000
        from_effective = min(effective, penalty)
        out.append(
            {
                "eff_stake": effective,
                "pending_top_up": pending,
                "forfeit_bps": rate,
                "penalty": penalty,
                "eff_stake_after": effective - from_effective,
                "pending_top_up_after": pending - (penalty - from_effective),
            }
        )
    return decimals(out)


def view_abi(key_list):
    """Calldata and return data of the appendix A registry lookups, the registry's lifetime
    forfeiture flag and minStake, the Inbox start view and the Unzen Inbox's proposal cutoff.

    `(true, 0)` names bond 0 or slot 0 and `(false, 0)` is absence, so the flag, not a zero id,
    tells them apart. `etnaStart()` returns (0, 0) before the start write. `proposeCutoff()`
    returns 0 while no cutoff is installed, and setOrigin requires a nonzero, reached cutoff.
    """
    found = "(bool,uint256)"
    views = {
        "bond_for_key": (
            "bondForKey(address)",
            [key_list[0]["ck_addr"]],
            found,
            (("bond_0", (True, 0)), ("unused_key", (False, 0))),
        ),
        "bond_in_slot": (
            "bondInSlot(uint256)",
            [7],
            found,
            (("bond_4096", (True, 4096)), ("empty_slot", (False, 0))),
        ),
        "slot_of_bond": (
            "slotOfBond(uint256)",
            [0],
            found,
            (("slot_0", (True, 0)), ("no_slot", (False, 0))),
        ),
        "forfeited": (
            "forfeited(uint256)",
            [0],
            "(bool)",
            (("forfeited", (True,)), ("not_forfeited", (False,))),
        ),
        "min_stake": (
            "minStake()",
            [],
            "(uint256)",
            (("deployment", (DEPLOYMENT["min_stake"],)),),
        ),
        "etna_start": (
            "etnaStart()",
            [],
            "(uint48,bytes32)",
            (("written", START[:2]), ("not_written", (0, word(0)))),
        ),
        "propose_cutoff": (
            "proposeCutoff()",
            [],
            "(uint48)",
            (("installed", (PROPOSE_CUTOFF,)), ("not_installed", (0,))),
        ),
    }

    def arg(value):
        return str(value).lower() if isinstance(value, bool) else value

    return {
        name: {
            "signature": signature,
            "selector": cast("sig", signature),
            "calldata": cast("calldata", signature, *args),
            "returns": returns,
            "results": [
                {
                    "name": result,
                    "values": decimals(list(values)),
                    "data": abi_encode("f" + returns, *map(arg, values)),
                }
                for result, values in results
            ],
        }
        for name, (signature, args, returns, results) in views.items()
    }


def governance_events():
    """Event topics and non-indexed ABI data: the governance events, explicit nonce invalidation,
    and the Inbox's initialization, landing, forced inclusion, sweep and recovery events."""
    rules_schedule = int(pack(*PACKED["inbox_293"][2:]), 16)
    exclusions, fi_to_clear = uint_list(EXCLUSIONS), uint_list(FI_TO_CLEAR)
    definitions = {
        "top_up_deposited": (
            "TopUpDeposited(uint256,uint256,uint48)",
            [word(0)],
            "f(uint256,uint48)",
            [100, 42],
        ),
        "top_up_activated": ("TopUpActivated(uint256,uint256)", [word(0)], "f(uint256)", [100]),
        "forfeited": (
            "Forfeited(uint256,bytes32,uint256,uint256)",
            [word(0)],
            "f(bytes32,uint256,uint256)",
            [INCIDENT_ID, 100, 10],
        ),
        "recovery_nonce_invalidated": (
            "RecoveryNonceInvalidated(uint256,uint256)",
            [],
            "f(uint256,uint256)",
            [7, 8],
        ),
        "rules_schedule_updated": (
            "RulesScheduleUpdated(uint256)",
            [],
            "f(uint256)",
            [rules_schedule],
        ),
        "start_written": (
            "StartWritten(uint256,bytes32,bytes32)",
            [],
            "f(uint256,bytes32,bytes32)",
            list(START),
        ),
        "etna_initialized": (
            "EtnaInitialized(uint256,uint256,bytes32,bytes32)",
            [],
            "f(uint256,uint256,bytes32,bytes32)",
            [10, 40, word(0x53), word(0x54)],
        ),
        "landed": (
            "Landed(uint256,uint256,uint256,bytes32,uint256,uint8)",
            [word(0), word(6), word(12)],
            "f(bytes32,uint256,uint8)",
            [word(0x77), 50, 1],
        ),
        "forced_inclusion_saved": (
            "ForcedInclusionSaved(uint48,bytes,uint256)",
            [word(3)],
            "f(bytes,uint256)",
            [FI_TX, FI_FEE_WEI],
        ),
        "protocol_fees_swept": ("ProtocolFeesSwept(uint256)", [], "f(uint256)", [FI_FEE_WEI]),
        "recovered": (
            "Recovered(uint48,uint256,uint256,uint256,uint256[],uint256[])",
            [word(2)],
            "f(uint256,uint256,uint256,uint256[],uint256[])",
            [12, 50, VALID_UNTIL, exclusions, fi_to_clear],
        ),
    }
    return {
        name: {
            "signature": signature,
            "topic0": keccak(signature),
            "indexed_topics": topics,
            "data": abi_encode(encoding, *args),
        }
        for name, (signature, topics, encoding, args) in definitions.items()
    }


# --- appendix A literal examples -----------------------------------------------------------------

# The secp256k1 generator G as a registered key: private key 1, ckPrefix 2 (G's Y is even) and
# ckX = G's X, the key of ENC-A-37 37.i, 39.a and 39a.a.
G_PREFIX, G_X = 2 + (SECP_G[1] & 1), word(SECP_G[0])
APPENDIX_MAINNET_CHAIN_ID = 167000  # the l2ChainId of ENC-A-39 39.a, 39a.a and 42.a
APPENDIX_STAKE = 250_000 * TAIKO  # effStake of 37.i and 39a.a; assignedPower is stake / 10^9

# The literal values the spec's vectors/A.md lists; generation stops if one does not reproduce.
APPENDIX_LITERALS = {
    "enc_a_10b_a": "0x05a173eee05e0e03682acaef0ca4dea2f32b47cd3e10eed85233465b524d4507",
    "enc_a_37_a": "0x21d961646cf730220ee47cda213ec296eba41d18fc39f8f6cb1e1350f77c907d",
    "enc_a_37_i": "0xe7283e6153912ee69d614724bff4c2c09b9d20287fa4e0840db13c883df21387",
    "enc_a_37_j": "0x6be6938b2da71c3451f504f138ac0f40a3402012cec0d51f5eb7d37d1fd574e7",
    "enc_a_39_a": "0x7529ec50109faf073e202f03d7b4804a32a3571765e9749536cc42cc37acb437",
    "enc_a_39a_a": "0x0c09cd574e795c943cf299b730422425455959f85c169641a97030f4d287566d",
    "enc_a_42_a": "0x6fa2491c7f7f68e27ae6e55fa1a5cbcc0dfb095bef60d4a69ed7498417368634",
    # Blob bytes from byte 0 up to the last nonzero one; every later byte is zero.
    "enc_a_23b_a": "0x3f0000001c" + "ff" * 27 + "30",
    "enc_a_23c_a": "0x00000000" + "01ff",
    "enc_a_45_g": "0x2a0b08" + "ff" * 9 + "01",
}

BLOB_FIELD_ELEMENTS = 4096
BLOB_STREAM_BYTES = 130_048  # 1,024 rounds of 127 bytes (ENC-A-23b)
BLOB_MAX_DATA = BLOB_STREAM_BYTES - 4  # n <= 130,044 (ENC-A-23c)


def blob_encode(data):
    """ENC-A-23a-c: the 131,072-byte blob carrying `data`."""
    assert len(data) <= BLOB_MAX_DATA
    stream = b"\x00" + len(data).to_bytes(3, "big") + data
    stream += bytes(BLOB_STREAM_BYTES - len(stream))
    out = bytearray()
    for r in range(BLOB_STREAM_BYTES // 127):
        chunk = stream[127 * r : 127 * (r + 1)]
        bodies = (chunk[0:31], chunk[32:63], chunk[64:95], chunk[96:127])
        x, y, z = chunk[31], chunk[63], chunk[95]
        headers = (
            x & 0x3F,
            (y & 0x0F) | ((x & 0xC0) >> 2),
            z & 0x3F,
            ((z & 0xC0) >> 2) | ((y & 0xF0) >> 4),
        )
        for header, body in zip(headers, bodies):
            out += bytes([header]) + body
    assert len(out) == 32 * BLOB_FIELD_ELEMENTS
    return bytes(out)


def blob_example(data, description):
    """A blob as its bytes up to the last nonzero one (every later byte is zero) and the keccak256
    of all 131,072 bytes."""
    blob = blob_encode(data)
    return {
        "description": description,
        "data": "0x" + data.hex(),
        "blob_prefix": "0x" + blob.rstrip(b"\0").hex(),
        "blob_hash": keccak_stdin("0x" + blob.hex()),
    }


def dynamic_tag_rejects(sources):
    """ENC-A-5 5.j: each domain-tagged hash's preimage with its tag encoded as a dynamic string
    instead of one static `bytes32` word, and the different hash that gives. A static-only
    preimage's other words are re-encoded unchanged (each is one ABI word); the two preimages with
    a dynamic array are encoded again from their arguments."""
    out = []
    for name, tag_name, path, preimage, accepted, encode_args in sources:
        assert preimage[2:66] == tag(tag_name)[2:], name
        if encode_args is None:
            words = [preimage[i : i + 64] for i in range(2, len(preimage), 64)]
            signature = "f(string" + ",bytes32" * (len(words) - 1) + ")"
            dynamic = abi_encode(signature, tag_name, *("0x" + w for w in words[1:]))
        else:
            signature, args = encode_args
            dynamic = abi_encode(signature.replace("f(bytes32,", "f(string,", 1), tag_name, *args)
        digest = keccak(dynamic)
        assert digest != accepted and keccak(preimage) == accepted, name
        out.append(
            {
                "name": name,
                "tag": tag_name,
                "accepted": path,
                "accepted_hash": accepted,
                "preimage": dynamic,
                "hash": digest,
            }
        )
    return out


def appendix_a_examples(config, entries, sets, states, apps, cut_vectors, statements, domains,
                        vote_vectors):
    """Every literal hash and byte string of the spec's vectors/A.md, recomputed; 29a.l and 29b.g
    are `validator_states` and `app_hashes`. 36.a is `committee_config`'s shape, and 38.h the
    interior-empty-slot checkpoint of `registry_entries.checkpoints`."""
    out = {}
    mix_preimage = abi_encode("f(bytes32,uint256)", word(1_000_000), 12_345)
    out["enc_a_10b_a"] = {
        "vector": "ENC-A-10b 10b.a",
        "parent_difficulty": 1_000_000,
        "number": 12_345,
        "preimage": mix_preimage,
        "hash": keccak(mix_preimage),
    }
    out["enc_a_23b_a"] = {
        "vector": "ENC-A-23b 23b.a",
        **blob_example(b"\xff" * 28, "data is 28 bytes of 0xff, so its last byte is round 0's x"),
    }
    out["enc_a_23c_a"] = {
        "vector": "ENC-A-23c 23c.a",
        **blob_example(b"\xff", "data is the single byte 0xff"),
    }
    # 23c.b's data is too long to list: 130,044 bytes of 0xff, so the stream has no fill. The blob
    # is listed by its first five bytes (header 0x3f, version 0x00, length 01 fb fc) and its hash.
    full = blob_encode(b"\xff" * BLOB_MAX_DATA)
    assert full[:5] == bytes.fromhex("3f0001fbfc")
    out["enc_a_23c_b"] = {
        "vector": "ENC-A-23c 23c.b",
        "description": "data is 130,044 bytes of 0xff: the length bytes are 01 fb fc, no fill",
        "data_byte": "0xff",
        "data_length": BLOB_MAX_DATA,
        "length_bytes": "0x" + BLOB_MAX_DATA.to_bytes(3, "big").hex(),
        "blob_head": "0x" + full[:5].hex(),
        "blob_hash": keccak_stdin("0x" + full.hex()),
    }
    assert out["enc_a_23c_b"]["length_bytes"] == "0x01fbfc"
    flipped = "0x40" + out["enc_a_23c_a"]["blob_prefix"][4:]
    out["enc_a_23d_f"] = {
        "vector": "ENC-A-23d 23d.f",
        "description": (
            "the blob of 23c.a with byte 0 changed from 0x00 to 0x40: it does not decode"
        ),
        "blob_prefix": flipped,
        "decodes": False,
    }
    out["enc_a_36_a"] = {
        "vector": "ENC-A-36 36.a",
        "preimage_bytes": len(config["preimage"]) // 2 - 1,
        "min_stake": DEPLOYMENT["min_stake"],
        "hash": config["hash"],
    }
    zero_preimage = reg_leaf_preimage(1, ZERO_ENTRY)
    out["enc_a_37_a"] = {
        "vector": "ENC-A-37 37.a",
        "slot": 1,
        "entry": ZERO_ENTRY,
        "preimage": zero_preimage,
        "hash": reg_leaf(1, ZERO_ENTRY),
    }
    g_entry = {"ck_prefix": G_PREFIX, "ck_x": G_X, "eff_stake": APPENDIX_STAKE,
               "active_from_l1": 100, "exit_effective_l1": NO_EXIT}
    out["enc_a_37_i"] = {
        "vector": "ENC-A-37 37.i",
        "slot": 0,
        "entry": g_entry,
        "preimage": reg_leaf_preimage(0, g_entry),
        "hash": reg_leaf(0, g_entry),
    }
    dynamic = abi_encode(REG_LEAF_SIGNATURE.replace("bytes32", "string", 1), "ETNA_REG_ENTRY_V1",
                         1, *(ZERO_ENTRY[f] for f in ENTRY_FIELDS))
    assert len(dynamic) == 2 + 2 * 288
    out["enc_a_37_j"] = {
        "vector": "ENC-A-37 37.j",
        "reject": True,
        "slot": 1,
        "entry": ZERO_ENTRY,
        "preimage": dynamic,
        "hash": keccak(dynamic),
    }
    (h_state,) = [c for c in entries["checkpoints"] if c["name"] == "slot_1_withdrawn"]
    l0, z1, l2 = h_state["leaves"]
    out["enc_a_38_h"] = {
        "vector": "ENC-A-38 38.h",
        "checkpoint": "slot_1_withdrawn",
        "count": 3,
        "l0": l0,
        "z1": z1,
        "l2": l2,
        "p": word(0),
        "left": node(l0, z1),
        "right": node(l2, word(0)),
        "root": node(node(l0, z1), node(l2, word(0))),
    }
    assert out["enc_a_38_h"]["root"] == h_state["entries_root"]
    assert z1 == out["enc_a_37_a"]["hash"]
    set_key_preimage = abi_encode("f(bytes32,uint256,uint256,bytes32)", tag("ETNA_SET_KEY_V1"),
                                  APPENDIX_MAINNET_CHAIN_ID, G_PREFIX, G_X)
    out["enc_a_39_a"] = {
        "vector": "ENC-A-39 39.a",
        "l2_chain_id": APPENDIX_MAINNET_CHAIN_ID,
        "ck_prefix": G_PREFIX,
        "ck_x": G_X,
        "preimage": set_key_preimage,
        "hash": keccak(set_key_preimage),
    }
    member = {"ck_prefix": G_PREFIX, "ck_x": G_X, "eff_stake": APPENDIX_STAKE,
              "power": APPENDIX_STAKE // VP_UNIT}
    set_preimage = set_hash_preimage(APPENDIX_MAINNET_CHAIN_ID, 1, [member])
    assert len(set_preimage) == 2 + 2 * 288
    set_hash = keccak(set_preimage)
    out["enc_a_39a_a"] = {
        "vector": "ENC-A-39a 39a.a",
        "l2_chain_id": APPENDIX_MAINNET_CHAIN_ID,
        "k": 1,
        "members": [member],
        "preimage": set_preimage,
        "hash": set_hash,
    }
    record = record_preimage(APPENDIX_MAINNET_CHAIN_ID, 0, 100, 0, set_hash, member["power"])
    out["enc_a_42_a"] = {
        "vector": "ENC-A-42 42.a",
        "l2_chain_id": APPENDIX_MAINNET_CHAIN_ID,
        "target_epoch": 0,
        "cutoff_l1_block": 100,
        "checkpoint_index": 0,
        "set_hash": set_hash,
        "total_power": member["power"],
        "preimage": record,
        "hash": keccak(record),
    }
    seconds_field = b"\x08" + varint_int64(-1)
    timestamp_field = length_delimited(0x2A, seconds_field)
    (backdated,) = [c for c in vote_vectors["cases"] if c["name"] == "precommit_a_backdated"]
    seconds, nanos = backdated["vote"]["timestampSeconds"], backdated["vote"]["timestampNanos"]
    assert (seconds, nanos) == ("-1", "0")
    assert timestamp_field.hex() in backdated["sign_bytes"]
    out["enc_a_45_g"] = {
        "vector": "ENC-A-45 45.g",
        "seconds": -1,
        "nanos": 0,
        "seconds_field": "0x" + seconds_field.hex(),
        "timestamp_field": "0x" + timestamp_field.hex(),
        "vote": "precommit_a_backdated",
    }
    for name, literal in APPENDIX_LITERALS.items():
        example = out[name]
        value = example.get("hash") or example.get("blob_prefix") or example["timestamp_field"]
        if value != literal:
            raise SystemExit(f"{name}: appendix A literal does not reproduce\n"
                             f"  computed: {value}\n  A.md:     {literal}")

    first_set = sets[1]
    domain, statement, cut = domains[0], statements[0], cut_vectors["cut_hashes"][0]
    (validator_state,), (app,) = states, apps
    member_rows = uint_list(
        f"({m['ck_prefix']},{m['ck_x']},{m['eff_stake']},{m['power']})"
        for m in first_set["members"]
    )
    val_rows = (
        f"[(2,{word(1)},10,-5),(3,{word(2)},10,5)]",
        f"[(2,{word(1)},10,5),(3,{word(2)},10,-5)]",
    )
    set_member = first_set["members"][0]
    out["dynamic_tag_rejects"] = dynamic_tag_rejects(
        (
            ("chain_domain", "ETNA_COMET_DOMAIN_V1", "chain_domains[0].chain_domain",
             domain["preimage"], domain["chain_domain"], None),
            ("committee_config", "ETNA_PARENT_ANCHOR_V1", "committee_config.hash",
             config["preimage"], config["hash"], None),
            ("reg_leaf", "ETNA_REG_ENTRY_V1", "appendix_a_examples.enc_a_37_a.hash",
             zero_preimage, out["enc_a_37_a"]["hash"], None),
            ("set_key", "ETNA_SET_KEY_V1", "committee_sets[1].members[0].set_key",
             abi_encode("f(bytes32,uint256,uint256,bytes32)", tag("ETNA_SET_KEY_V1"),
                        first_set["l2_chain_id"], set_member["ck_prefix"], set_member["ck_x"]),
             set_member["set_key"], None),
            ("set_hash", "ETNA_SET_V1", "committee_sets[1].set_hash",
             first_set["set_hash_preimage"], first_set["set_hash"],
             (SET_HASH_SIGNATURE, (first_set["l2_chain_id"], first_set["set_version"],
                                   member_rows))),
            ("committee_record", "ETNA_COMMITTEE_V1", "committee_sets[1].record_hash",
             first_set["record_preimage"], first_set["record_hash"], None),
            ("val_state", "ETNA_VAL_STATE_V1", "validator_states[0].hash",
             validator_state["preimage"], validator_state["hash"],
             (VAL_STATE_SIGNATURE, (validator_state["height"], val_rows[0],
                                    validator_state["current_proposer"], val_rows[1],
                                    validator_state["next_proposer"]))),
            ("app_hash", "ETNA_APP_HASH_V1", "app_hashes[0].hash", app["preimage"], app["hash"],
             None),
            ("cut_hash", "ETNA_LAND_CUTS_V1", "cuts.cut_hashes[0].cut_hash", cut["preimage"],
             cut["cut_hash"], None),
            ("statement", "TAIKO_ETNA_LAND_V1", "land_statements[0].hash", statement["preimage"],
             statement["hash"], None),
        )
    )
    reg = out["dynamic_tag_rejects"][2]
    assert reg["preimage"] == out["enc_a_37_j"]["preimage"] and reg["hash"] == APPENDIX_LITERALS[
        "enc_a_37_j"]
    return decimals(out)


def main():
    key_list = keys()
    digests = register_digests(key_list)
    config = committee_config()
    entries = registry_entries(key_list)
    sets = committee_sets(entries["entries"])
    cut_vectors = cuts()
    statements = land_statements(config, cut_vectors)
    domains = chain_domains()
    states = validator_states()
    apps = app_hashes(states)
    vote_vectors = votes(key_list, domains)
    vectors = {
        "schema_version": "9",
        "deployment": deployment(),
        "keys": key_list,
        "key_decompression": key_decompression(key_list),
        "register_digests": digests,
        "pop_rejections": pop_rejections(key_list, digests),
        "committee_config": config,
        "registry_entries": entries,
        "committee_sets": sets,
        "validator_states": states,
        "app_hashes": apps,
        "val_state_chains": val_state_chains(domains),
        "cuts": cut_vectors,
        "land_statements": statements,
        "land_abi": land_abi(statements),
        "chain_domains": domains,
        "votes": vote_vectors,
        "fi_eligibility": fi_eligibility(),
        "extra_data": extra_data(),
        "packed_words": packed_words(),
        "origin_words": origin_words(),
        "layout": layout(),
        "governance_abi": governance_abi(),
        "forfeitures": forfeitures(),
        "governance_events": governance_events(),
        "view_abi": view_abi(key_list),
        "appendix_a_examples": appendix_a_examples(
            config, entries, sets, states, apps, cut_vectors, statements, domains, vote_vectors
        ),
    }
    OUTPUT.write_text(json.dumps(vectors, indent=2) + "\n")
    subprocess.run(["pnpm", "exec", "prettier", "--write", str(OUTPUT)], cwd=ROOT, check=True)
    run_ficheck()


if __name__ == "__main__":
    main()
