#!/usr/bin/env python3
"""Structural checks of vectors.json against the Etna spec's appendix A (encodings) and B (storage).

Run from the repository root (standard library only; no `cast`, `go` or network):

    python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v

`generate.py` computes every hash and slot with `cast`. These tests decode the generated preimages
and words and check what can be checked without keccak: word order and count, field widths and
packing offsets, the 48-byte chain id, key compression and decompression, signature recovery to the
registered point, and the shape of each case. The validator-state chains are the exception: they
are replayed with `valset_model.py` and every hash is recomputed with a Keccak-256 written here
(hashlib's when the Python build has one). So are the staking sections: the fallback key hashes,
the staking contract's slots and the validator addresses use that Keccak-256, and every
missBitmap, candidate and block-start case is decided again by models written here, separately
from `generate.py`'s.
"""

import base64
import hashlib
import json
import pathlib
import unittest

import valset_model

V = json.loads((pathlib.Path(__file__).resolve().parent / "vectors.json").read_text())

FI_STEP = 6  # the cut model's FI cursor advances once every FI_STEP heights
U48_MAX = 2**48 - 1
SECP_P = 2**256 - 2**32 - 977
SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
SECP_G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)
OWNERS = ("0x" + "aa" * 20, "0x" + "bb" * 20)
KECCAK_EMPTY = "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
CHAIN_ID_ALPHABET = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")


def hexbytes(value):
    assert value.startswith("0x"), value
    return bytes.fromhex(value[2:])


def words(value):
    data = hexbytes(value)
    assert len(data) % 32 == 0, value
    return ["0x" + data[i : i + 32].hex() for i in range(0, len(data), 32)]


def word(value, index):
    return words(value)[index]


def tag(name):
    """A right-zero-padded `bytes32` ASCII domain tag."""
    return "0x" + name.encode().ljust(32, b"\0").hex()


def uint(value):
    return "0x" + format(int(value), "064x")


def address(value):
    return "0x" + hexbytes(value).rjust(32, b"\0").hex()


def by_name(cases, name):
    matches = [case for case in cases if case["name"] == name]
    assert len(matches) == 1, name
    return matches[0]


# --- secp256k1 (appendix A decompression and ecrecover, without keccak) ---------------------------


def has_point(x):
    """Whether x^3 + 7 is a square mod p (Euler's criterion)."""
    return pow((x**3 + 7) % SECP_P, (SECP_P - 1) // 2, SECP_P) in (0, 1)


def ec_add(a, b):
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


def ec_mul(point, k):
    result = None
    while k:
        if k & 1:
            result = ec_add(result, point)
        point = ec_add(point, point)
        k >>= 1
    return result


def decompress(public_key):
    """Appendix A: the point of a 33-byte `ckPrefix || ckX`, or None when it is rejected."""
    if len(public_key) != 33 or public_key[0] not in (2, 3):
        return None
    x = int.from_bytes(public_key[1:], "big")
    if x >= SECP_P:
        return None
    a = (x**3 + 7) % SECP_P
    y = pow(a, (SECP_P + 1) // 4, SECP_P)
    if y * y % SECP_P != a:
        return None
    return x, y if y % 2 == public_key[0] - 2 else SECP_P - y


def is_hex_text(data):
    """Whether `data` is ASCII hex text (an even number of hex digits)."""
    return len(data) % 2 == 0 and all(c in b"0123456789abcdefABCDEF" for c in data)


def classify(public_key):
    """The reason a public key input is rejected, from its shape alone (None if it decodes)."""
    if not public_key:
        return "empty"
    if public_key == b"\x00":
        return "identity"
    if len(public_key) == 66 and is_hex_text(public_key):
        return "textual"
    if len(public_key) == 65 and public_key[0] == 4:
        return "uncompressed"
    if len(public_key) == 65 and public_key[0] in (6, 7):
        return "hybrid"
    if len(public_key) == 64:
        return "uncompressed"
    if len(public_key) > 33:
        return "trailing_bytes"
    if len(public_key) < 33:
        return "short"
    if public_key[0] not in (2, 3):
        return "bad_prefix"
    if int.from_bytes(public_key[1:], "big") >= SECP_P:
        return "x_ge_p"
    if decompress(public_key) is None:
        return "not_on_curve"
    return None


def sig_parts(sig):
    """(r, s, V) of a 65-byte `R || S || V` signature."""
    assert len(sig) == 65, len(sig)
    return int.from_bytes(sig[:32], "big"), int.from_bytes(sig[32:64], "big"), sig[64]


def recover(digest, r, s, v):
    """ecrecover(digest, v + 27, r, s) as a point (no keccak), or None where ecrecover returns 0."""
    if not (0 < r < SECP_N and 0 < s < SECP_N and v in (0, 1)):
        return None
    big_r = decompress(bytes([2 + v]) + r.to_bytes(32, "big"))
    if big_r is None:
        return None
    r_inv = pow(r, -1, SECP_N)
    z = int(digest, 16)
    return ec_add(ec_mul(big_r, s * r_inv % SECP_N), ec_mul(SECP_G, -z * r_inv % SECP_N))


def pop_accepted(public_key, digest, pop_sig):
    """Spec 4.1 PoP rule: 65 bytes, V in {0,1}, 0 < r < n, 0 < s <= n/2, recovers the key point."""
    point = decompress(hexbytes(public_key))
    sig = hexbytes(pop_sig)
    if point is None or len(sig) != 65:
        return False
    r, s, v = sig_parts(sig)
    if v not in (0, 1) or not 0 < r < SECP_N or not 0 < s <= SECP_N // 2:
        return False
    return recover(digest, r, s, v) == point


def key_point(key):
    return int(key["ck_x"], 16), int(key["ck_y"], 16)


# --- vote sign bytes (appendix A voteSignBytes, decoded without keccak) ---------------------------

VOTE_CASES = [
    "precommit_a",
    "precommit_nil",
    "precommit_b",
    "precommit_a_late",
    "prevote_a_r1",
    "prevote_b_r1",
    "prevote_b_r2",
    "precommit_b_r1",
    "gen1_precommit_a",
    "gen1_precommit_b",
    "gen2_precommit_a",
    "gen2_precommit_b",
    "other_inbox_precommit_b",
    "partial_block_id",
    "max_values",
    "precommit_b_h1001",
    "hash_only_block_id",
    "zero_timestamp",
    "negative_timestamp",
    "min_timestamp",
    "max_timestamp_seconds",
    "precommit_a_backdated",
    "precommit_b_backdated",
    "precommit_zero_block_hash",
    "precommit_zero_parts_hash",
    "precommit_zero_both_hashes",
    "zero_hashes_zero_total",
    "zero_block_hash_only",
    "zero_parts_hash_only",
]
VOTE_FIELDS = [
    "voteType",
    "height",
    "round",
    "blockHash",
    "partsTotal",
    "partsHash",
    "timestampSeconds",
    "timestampSecondsU64",
    "timestampNanos",
    "generation",
]
# CometBFT's (protobuf's) Timestamp range: 0001-01-01T00:00:00Z to 9999-12-31T23:59:59Z.
MIN_VOTE_SECONDS = -62_135_596_800
MAX_VOTE_SECONDS = 253_402_300_799
OTHER_INBOX = "0x" + "33" * 20


def read_uvarint(data, i):
    """`(value, next index)` of the unsigned varint at `data[i]`."""
    value = shift = 0
    while True:
        byte = data[i]
        i += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            return value, i


def read_message(data):
    """`{field number: value}` of a protobuf message whose fields appear once, in ascending order.

    Varints decode to ints, fixed64 to signed little-endian ints and length-delimited fields to
    bytes. Proto3 omits zero and empty scalars, so a present scalar must be nonzero.
    """
    fields, i = {}, 0
    while i < len(data):
        key, i = read_uvarint(data, i)
        number, wire = key >> 3, key & 7
        assert not fields or number > max(fields), (number, list(fields))
        if wire == 0:
            value, i = read_uvarint(data, i)
        elif wire == 1:
            value = int.from_bytes(data[i : i + 8], "little", signed=True)
            i += 8
        elif wire == 2:
            length, i = read_uvarint(data, i)
            value = data[i : i + length]
            i += length
        else:
            raise AssertionError(f"wire type {wire}")
        fields[number] = value
    assert i == len(data), (i, len(data))
    return fields


def decode_vote_sign_bytes(sign_bytes):
    """`(vote fields without generation, chain_id)` of `uvarint(len(cv)) || cv`."""
    length, start = read_uvarint(sign_bytes, 0)
    assert length == len(sign_bytes) - start, (length, len(sign_bytes), start)
    cv = read_message(sign_bytes[start:])
    assert set(cv) <= {1, 2, 3, 4, 5, 6} and {5, 6} <= set(cv), list(cv)
    for number in (1, 2, 3):
        assert cv.get(number, 1) != 0, number
    block_id = read_message(cv[4]) if 4 in cv else {}
    assert set(block_id) <= {1, 2} and (not block_id or 2 in block_id), list(block_id)
    psh = read_message(block_id[2]) if 2 in block_id else {}
    timestamp = read_message(cv[5])
    for message, allowed in ((psh, {1, 2}), (timestamp, {1, 2})):
        assert set(message) <= allowed and all(message.values()), message
    for hash_bytes in (block_id.get(1), psh.get(2)):
        assert hash_bytes is None or len(hash_bytes) == 32
    # A present block id has at least one nonempty hash or nonzero total, even when its bytes are zero.
    assert 4 not in cv or block_id.get(1) or psh, cv[4]
    # Seconds are an int64 varint: the uvarint of the 64-bit two's-complement pattern.
    pattern = timestamp.get(1, 0)
    assert pattern < 2**64, pattern
    vote = {
        "voteType": cv.get(1, 0),
        "height": cv.get(2, 0),
        "round": cv.get(3, 0),
        "blockHash": "0x" + block_id.get(1, b"").hex(),
        "partsTotal": psh.get(1, 0),
        "partsHash": "0x" + psh.get(2, b"").hex(),
        "timestampSeconds": pattern - 2**64 if pattern >= 2**63 else pattern,
        "timestampSecondsU64": pattern,
        "timestampNanos": timestamp.get(2, 0),
    }
    return {k: v if isinstance(v, str) else str(v) for k, v in vote.items()}, cv[6].decode("ascii")


def block_id_of(vote):
    return vote["blockHash"], vote["partsTotal"], vote["partsHash"]


# --- forced-inclusion eligibility (spec 7.2 static rules, decoded without keccak) -----------------

FI_RULES = {"eligible", "noncanonical", "type", "chain_id", "signature", "width", "gas_limit"}
FI_CASES = [
    ("legacy_eip155_35", "eligible"),
    ("legacy_eip155_36", "eligible"),
    ("legacy_pre155_27", "eligible"),
    ("legacy_pre155_28", "eligible"),
    ("eip2930", "eligible"),
    ("eip1559", "eligible"),
    ("eip1559_zero_fee", "eligible"),
    ("eip7702", "eligible"),
    ("eip7702_invalid_auth_signature", "eligible"),
    ("eip7702_empty_auth_list", "eligible"),
    ("gas_at_limit", "eligible"),
    ("nonce_max", "eligible"),
    ("fee_max", "eligible"),
    ("value_max", "eligible"),
    ("eip7702_foreign_tuple_chain_id", "eligible"),
    ("eip7702_tuple_y_parity_255", "eligible"),
    ("eip7702_tuple_chain_id_zero", "eligible"),
    ("legacy_contract_creation", "eligible"),
    ("eip1559_contract_creation", "eligible"),
    ("s_half_n", "eligible"),
    ("eip7702_tuple_nonce_max", "eligible"),
    ("eip7702_tuple_high_s", "eligible"),
    ("eip1559_tip_above_max_fee", "eligible"),
    ("empty", "noncanonical"),
    ("trailing_byte", "noncanonical"),
    ("two_transactions", "noncanonical"),
    ("leading_zero_nonce", "noncanonical"),
    ("non_minimal_length_prefix", "noncanonical"),
    ("typed_missing_field", "noncanonical"),
    ("typed_extra_field", "noncanonical"),
    ("eip7702_empty_to", "noncanonical"),
    ("legacy_to_19_bytes", "noncanonical"),
    ("eip1559_to_19_bytes", "noncanonical"),
    ("eip2930_access_list_address_19_bytes", "noncanonical"),
    ("eip1559_storage_key_31_bytes", "noncanonical"),
    ("eip7702_tuple_5_fields", "noncanonical"),
    ("eip7702_tuple_7_fields", "noncanonical"),
    ("type3_blob", "type"),
    ("unknown_type_05", "type"),
    ("unknown_type_7f", "type"),
    ("legacy_v_37", "chain_id"),
    ("typed_wrong_chain_id", "chain_id"),
    ("y_parity_2", "signature"),
    ("r_zero", "signature"),
    ("s_zero", "signature"),
    ("r_eq_n", "signature"),
    ("high_s", "signature"),
    ("unrecoverable_r", "signature"),
    ("s_half_n_plus_1", "signature"),
    ("nonce_2_64", "width"),
    ("gas_2_64", "width"),
    ("fee_2_128", "width"),
    ("tip_2_128", "width"),
    ("legacy_gas_price_2_128", "width"),
    ("eip2930_gas_price_2_128", "width"),
    ("eip7702_fee_2_128", "width"),
    ("value_33_bytes", "width"),
    ("eip7702_tuple_nonce_2_64", "width"),
    ("eip7702_tuple_y_parity_256", "width"),
    ("eip7702_tuple_address_19_bytes", "width"),
    ("eip7702_tuple_r_33_bytes", "width"),
    ("gas_above_limit", "gas_limit"),
]
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


def rlp_item(data, i):
    """`(item, end)` of the canonical RLP item at `data[i]`; bytes or a list of items."""
    assert i < len(data), "truncated"
    first = data[i]
    if first < 0x80:
        return data[i : i + 1], i + 1
    is_list = first >= 0xC0
    short = first - (0xC0 if is_list else 0x80)
    if short < 56:
        length, start = short, i + 1
    else:
        size = short - 55
        length_bytes = data[i + 1 : i + 1 + size]
        assert len(length_bytes) == size and length_bytes[0] != 0, "non-minimal length"
        length, start = int.from_bytes(length_bytes, "big"), i + 1 + size
        assert length >= 56, "long form for a short item"
    end = start + length
    assert end <= len(data), "truncated"
    if not is_list:
        assert not (length == 1 and data[start] < 0x80), "single byte not encoded as itself"
        return data[start:end], end
    items, j = [], start
    while j < end:
        item, j = rlp_item(data, j)
        items.append(item)
    assert j == end, "list overrun"
    return items, end


def rlp_uint(item):
    assert isinstance(item, bytes) and (not item or item[0] != 0), "non-canonical integer"
    return int.from_bytes(item, "big")


def decode_fi(raw):
    """`(type, fields)` of exactly one canonical EIP-2718 transaction; AssertionError otherwise.

    The body of an unknown type is read with type 2's fields (the vectors build it that way).
    """
    assert raw, "empty"
    tx_type = 0 if raw[0] >= 0xC0 else raw[0]
    assert tx_type < 0x80, "not a transaction"
    body = raw if tx_type == 0 else raw[1:]
    items, end = rlp_item(body, 0)
    assert end == len(body), "trailing bytes"
    names = FI_LAYOUTS.get(tx_type, FI_LAYOUTS[2])
    assert isinstance(items, list) and len(items) == len(names), "field count"
    fields = {}
    for name, item in zip(names, items):
        if name in ("to", "data"):
            assert isinstance(item, bytes), name
            fields[name] = item
        elif name == "access_list":
            for entry in item:
                assert isinstance(entry, list) and len(entry) == 2, name
                address, keys = entry
                assert len(address) == 20 and isinstance(keys, list), name
                assert all(isinstance(k, bytes) and len(k) == 32 for k in keys), name
            fields[name] = item
        elif name == "blob_hashes":
            assert all(len(h) == 32 for h in item), name
            fields[name] = item
        elif name == "authorization_list":
            fields[name] = []
            # A tuple has six fields; an address of the wrong length breaks a tuple width, not
            # canonical decoding.
            for auth in item:
                assert isinstance(auth, list) and len(auth) == 6, name
                chain_id, address, nonce, y_parity, r, s = auth
                assert isinstance(address, bytes), name
                fields[name].append(
                    {
                        "chain_id": rlp_uint(chain_id),
                        "address": address,
                        "nonce": rlp_uint(nonce),
                        "y_parity": rlp_uint(y_parity),
                        "r": rlp_uint(r),
                        "s": rlp_uint(s),
                    }
                )
        else:
            fields[name] = rlp_uint(item)
    # A type-3 or type-4 destination is always a 20-byte address; otherwise it may be empty.
    assert len(fields["to"]) == 20 or (not fields["to"] and tx_type not in (3, 4)), "to"
    return tx_type, fields


def fi_static_failures(tx_type, fields, chain_id, gas_limit):
    """Spec 7.2 rules a decoded transaction breaks, except sender recovery (which needs keccak):
    an r with no curve point stands in for an unrecoverable signature."""
    failures = set()
    if tx_type not in (0, 1, 2, 4):
        failures.add("type")
    if tx_type == 0:
        v = fields["v"]
        parity = v - 27 if v in (27, 28) else (v - 35) % 2 if v >= 35 else None
        if v >= 35 and (v - 35) // 2 != chain_id:
            failures.add("chain_id")
    else:
        parity = fields["y_parity"]
        if fields["chain_id"] != chain_id:
            failures.add("chain_id")
    r, s = fields["r"], fields["s"]
    if parity not in (0, 1) or not 0 < r < SECP_N or not 0 < s <= SECP_N // 2 or not has_point(r):
        failures.add("signature")
    if any(fields[name] >= 2**bits for name, bits in FI_WIDTHS.items() if name in fields):
        failures.add("width")
    # EIP-7702 tuple widths: chain_id uint256, address 20 bytes, nonce uint64, y_parity uint8,
    # r and s uint256.
    for auth in fields.get("authorization_list", []):
        if len(auth["address"]) != 20 or auth["nonce"] >= 2**64 or auth["y_parity"] >= 2**8:
            failures.add("width")
        if max(auth["chain_id"], auth["r"], auth["s"]) >= 2**256:
            failures.add("width")
    if fields["gas"] > gas_limit:
        failures.add("gas_limit")
    return failures


# --- validator-state chains (appendix A ENC-A-29a, SYNC-9-5c) -------------------------------------

# Keccak-256 (the pre-NIST padding Ethereum uses). hashlib has it only when built against OpenSSL
# 3.2 or later, so the pure-Python permutation below is the fallback; both are checked against the
# known digests in `test_keccak256`.
_KECCAK_RC = (
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
)  # fmt: skip
# Lane i = x + 5y: rho rotation and pi destination (B[y, 2x + 3y] = rot(A[x, y])).
_KECCAK_ROT = (
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
)  # fmt: skip
_KECCAK_STEPS = tuple(
    (i, i // 5 + 5 * ((2 * (i % 5) + 3 * (i // 5)) % 5), _KECCAK_ROT[i]) for i in range(25)
)
_MASK64 = (1 << 64) - 1


def _keccak_f(a):
    b = [0] * 25
    for rc in _KECCAK_RC:
        c = [a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20] for x in range(5)]
        d = [
            c[(x - 1) % 5] ^ (((c[(x + 1) % 5] << 1) | (c[(x + 1) % 5] >> 63)) & _MASK64)
            for x in range(5)
        ]
        for i, j, r in _KECCAK_STEPS:
            v = a[i] ^ d[i % 5]
            b[j] = ((v << r) | (v >> (64 - r))) & _MASK64 if r else v
        for y in (0, 5, 10, 15, 20):
            b0, b1, b2, b3, b4 = b[y : y + 5]
            a[y : y + 5] = (
                b0 ^ (~b1 & b2),
                b1 ^ (~b2 & b3),
                b2 ^ (~b3 & b4),
                b3 ^ (~b4 & b0),
                b4 ^ (~b0 & b1),
            )
        a[0] ^= rc


def keccak256_python(data):
    data = bytes(data) + b"\x01" + bytes(-(len(data) + 1) % 136)
    data = data[:-1] + bytes([data[-1] | 0x80])
    a = [0] * 25
    for offset in range(0, len(data), 136):
        for i in range(17):
            a[i] ^= int.from_bytes(data[offset + 8 * i : offset + 8 * i + 8], "little")
        _keccak_f(a)
    return b"".join(a[i].to_bytes(8, "little") for i in range(4))


def keccak256(data):
    try:
        return hashlib.new("keccak-256", bytes(data)).digest()
    except ValueError:
        return keccak256_python(data)


def eth_address(point):
    """The secp256k1eth validator address: keccak256(X || Y)[12:] (CONS-3.1-3), lowercase hex."""
    x, y = point
    return keccak256(x.to_bytes(32, "big") + y.to_bytes(32, "big"))[12:].hex()


def val_state_preimage(height, current, current_proposer, following, next_proposer, keys):
    """Appendix A's valStateHash preimage: six head words (tag, x, offset, index, offset, index),
    then each set as its length and four words per entry, the priority sign-extended."""

    def w(value):
        return (value % 2**256).to_bytes(32, "big")

    def array(entries):
        out = [w(len(entries))]
        for key, power, priority in entries:
            out += [w(int(keys[key]["ck_prefix"])), hexbytes(keys[key]["ck_x"])]
            out += [w(int(power)), w(int(priority))]
        return b"".join(out)

    head = hexbytes(tag("ETNA_VAL_STATE_V1")) + w(height) + w(192) + w(current_proposer)
    head += w(192 + 32 + 128 * len(current)) + w(next_proposer)
    return head + array(current) + array(following)


def as_entries(rows):
    return [[key, int(power), int(priority)] for key, power, priority in rows]


def model_events(events):
    """The model's events as vectors.json writes them (integers as decimal strings)."""

    def text(value):
        if isinstance(value, bool) or isinstance(value, str):
            return value
        if isinstance(value, list):
            return [text(v) for v in value]
        return str(value)

    return [{k: text(v) for k, v in event.items()} for event in events]


def committee(entries):
    return {key: int(power) for key, power, _ in entries}


def h256(data):
    """keccak256 of `data` as 0x-prefixed hex."""
    return "0x" + keccak256(data).hex()


def join_words(*values):
    """The concatenation of 0x-prefixed 32-byte words."""
    out = b"".join(hexbytes(v) for v in values)
    assert len(out) == 32 * len(values)
    return out


def fallback_keys_preimage(keys):
    """fallbackKeysHash's preimage, written from appendix A: the tag and the array offset, then
    the length and two words per key (ckPrefix, then ckX)."""
    out = [tag("ETNA_FALLBACK_KEYS_V1"), uint(64), uint(len(keys))]
    for key in keys:
        out += [uint(key["ck_prefix"]), key["ck_x"]]
    return join_words(*out)


# The compressed public keys of the private keys 1 and 2, as the spec's fallback key examples
# list them: both prefixes are 0x02, so the list [K1, K2] is ascending by X.
K1 = {"ck_prefix": "2", "ck_x": "0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"}
K2 = {"ck_prefix": "2", "ck_x": "0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5"}


def blob_encode(data):
    """ENC-A-23a-c, written from appendix A: the 131,072-byte blob carrying `data`."""
    assert len(data) <= 130_044
    stream = b"\x00" + len(data).to_bytes(3, "big") + data
    stream += bytes(130_048 - len(stream))
    out = bytearray()
    for r in range(1024):
        c = stream[127 * r : 127 * (r + 1)]
        x, y, z = c[31], c[63], c[95]
        hdr = (
            x & 0x3F,
            (y & 0x0F) | ((x & 0xC0) >> 2),
            z & 0x3F,
            ((z & 0xC0) >> 2) | ((y & 0xF0) >> 4),
        )
        for h, body in zip(hdr, (c[0:31], c[32:63], c[64:95], c[96:127])):
            out += bytes([h]) + body
    return bytes(out)


def blob_decode(blob):
    """ENC-A-23d strict decoding: the data, or None when the blob does not decode."""
    if len(blob) != 131_072 or any(blob[32 * i] & 0xC0 for i in range(4096)):
        return None
    stream = bytearray()
    for r in range(1024):
        fe = [blob[32 * (4 * r + j) : 32 * (4 * r + j + 1)] for j in range(4)]
        h = [f[0] for f in fe]
        x = h[0] | ((h[1] & 0x30) << 2)
        y = (h[1] & 0x0F) | ((h[3] & 0x0F) << 4)
        z = h[2] | ((h[3] & 0x30) << 2)
        stream += fe[0][1:] + bytes([x]) + fe[1][1:] + bytes([y]) + fe[2][1:] + bytes([z])
        stream += fe[3][1:]
    n = int.from_bytes(stream[1:4], "big")
    if stream[0] != 0 or n > 130_044 or any(stream[4 + n :]):
        return None
    return bytes(stream[4 : 4 + n])


# Literal hashes copied from the Etna spec's appendix A vector catalogue: the mixHash example, the
# config hash example and its dynamic-string twin, and the one- and two-key fallback key hashes.
APPENDIX_A_LITERALS = {
    "enc_a_10b_a": "0x05a173eee05e0e03682acaef0ca4dea2f32b47cd3e10eed85233465b524d4507",
    "enc_a_36_a": "0x78f4b267763e0c4b58a0606e29530287b1761bf4155630c82e79d3e1215fe3b6",
    "enc_a_36_f": "0x4a305a25878a5ab6f2d7bd36fcdd3d7a5549d0b55471d812df821723caa6383c",
    "enc_a_36a_a": "0x9dd1f7298a08cbe8d9579af09f0c713fc35137e6c534a74f8c439b63252f046f",
    "enc_a_36a_b": "0x2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea",
}
# The topic0 values the spec lists for the Inbox's fallback key and minTotalStake events and the
# staking contract's top-up and forfeiture events.
SPEC_TOPICS = {
    "fallback_keys_updated": "0xad67b35e197f2041d061711ea23ef099f669424769b341298aaa52161dd9f88c",
    "min_total_stake_updated": "0xfd570c3cd5a2dd2e25a4647876d87fd36c533b77efb87ca66499f6cec64a25a1",
    "top_up_deposited": "0x06a2187e7ae93aae0a9ff5c976b126441fdcc2c16afd1274e9ba793336f179ab",
    "forfeited": "0xfa0800b34e880af94586f918c482b017b7cb8d550255ba57a432bc218dbdfc6b",
}
ON_BLOCK_START_SELECTOR = "0xea987592"


# --- L2 staking: fallback keys, storage words, miss bitmap, candidate, block-start call -----------

# The compressed public keys of the private keys 3 and 9: K3's prefix is 0x02 and K9's 0x03, and
# K9's X is the smaller, so [K3, K9] is ascending as 33-byte values but not by X alone.
K3 = {"ck_prefix": "2", "ck_x": "0xf9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"}
K9 = {"ck_prefix": "3", "ck_x": "0xacd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbe"}
# The staking contract's ERC-7201 base slot T, the word T + 257 (word 1 of snapshot seat record
# 127), the key-to-seat element of K1's address, and the EIP-1967 implementation slot.
STAKING_BASE = 0x5CFA9AE4FA3CCB6DB5189DBAFF84335BB566EBD2F7442638272A1D81CCB19E00
STAKING_RECORD_127_WORD1 = "0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19f01"
K1_ADDR = "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"
K1_KEY_SEAT_SLOT = "0x5aed0c9b66e2d0fa057ebed89e910688ada65f4c543b321333450c21264ccf27"
IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
PREFIX_THEN_X_HASH = "0x5890fcdf8ee020d53fbf91c780a078701c0cecd248bbf4322f5feccf57bc333b"
MAX_POWER_SUM = (2**63 - 1) // 8  # CometBFT's MaxTotalVotingPower
U64_MAX = 2**64 - 1
U256_MAX = 2**256 - 1
BLOCK_ID_FLAG_COMMIT = "2"


def key_bytes(key):
    """The 33-byte value ckPrefix || ckX of a {ck_prefix, ck_x} key."""
    return bytes([int(key["ck_prefix"])]) + hexbytes(key["ck_x"])


def scalar_key(k):
    """The compressed public key of private key k, as {ck_prefix, ck_x}."""
    x, y = ec_mul(SECP_G, k)
    return {"ck_prefix": str(2 + y % 2), "ck_x": uint(x)}


def ascending_scalar_keys(n):
    """The keys of private keys 1..n in ascending order of their 33-byte values."""
    return sorted((scalar_key(k) for k in range(1, n + 1)), key=key_bytes)


def fallback_list_failures(keys):
    """The setFallbackKeys conditions a list breaks: 1 to 128 entries, strictly ascending as
    33-byte values (so no repeats), every key a valid compressed public key."""
    raw = [key_bytes(key) for key in keys]
    failures = []
    if len(raw) < 1 or len(raw) > 128:
        failures.append("count")
    if raw != sorted(set(raw)):
        failures.append("order")
    if any(decompress(r) is None for r in raw):
        failures.append("key")
    return failures


def seat_from_word(value):
    """The seat a key-to-seat value gives: holdsSeat (bits 0-7) must be 1, seat (bits 8-15) below
    128 and every higher bit zero; anything else is no seat."""
    if value >> 16 != 0 or value & 0xFF != 1 or value >> 8 >= 128:
        return None
    return value >> 8


def record_member(record):
    """(33-byte key, power, stray high bits) of a snapshot seat record."""
    word1, word2 = int(record["word1"], 16), int(record["word2"], 16)
    return bytes([word2 & 0xFF]) + word1.to_bytes(32, "big"), word2 >> 8 & U64_MAX, word2 >> 72


def candidate_failures(case):
    """Which of the candidate conditions the case breaks, in a fixed order: the threshold is not
    the largest uint256, the whole word at T equals H, the set has members, no record word 2 has
    bits above `power`, every key is valid and distinct, every power is at least 1, their exact
    sum is at most MAX, and the snapshot total reaches the threshold."""
    members = [record_member(r) for r in case["records"]]
    keys = [key for key, _, _ in members]
    powers = [power for _, power, _ in members]
    threshold = int(case["min_total_stake"])
    checks = (
        ("min_total_stake_max", threshold == U256_MAX),
        ("snapshot_height", int(case["snapshot_height_word"], 16) != int(case["height"])),
        ("no_members", not members),
        ("stray_bits", any(stray for _, _, stray in members)),
        ("invalid_key", any(decompress(key) is None for key in keys)),
        ("duplicate_key", len(set(keys)) < len(keys)),
        ("zero_power", any(power == 0 for power in powers)),
        ("power_sum", sum(powers) > MAX_POWER_SUM),
        ("below_min_total_stake", int(case["snapshot_total_stake"]) < threshold),
    )
    return [name for name, failed in checks if failed]


def signer(key, power):
    """A signer entry: the key, its secp256k1eth address and its power."""
    return {
        "ck_prefix": str(key[0]),
        "ck_x": "0x" + key[1:].hex(),
        "ck_addr": "0x" + eth_address(decompress(key)),
        "power": str(power),
    }


def replay_block_start(params, case):
    """The staking contract from a fresh deployment through the case's registrations, prior calls
    and call (spec 4.1 and 4.2), in plain lists: a registration takes the lowest empty seat; each
    call counts a miss for an occupied seat whose bit is 1 and resets the count otherwise, then
    takes ceil(effStake * missSlashBps / 10000) from every seat that reached missLimit, resets its
    count and releases a bond left below minStake, then writes the 128 records, the total and the
    height. Returns the registration seats, the seats held when the call starts and the call's
    effects."""
    n_max, min_stake = params["n_max"], params["min_stake"]
    stake, holder, misses = [], [None] * 128, [0] * 128
    seats = []
    for reg in case["setup"]["registrations"]:
        assert int(reg["amount"]) >= min_stake
        free = [s for s in range(n_max) if holder[s] is None][0]
        holder[free], misses[free] = len(stake), 0
        stake.append(int(reg["amount"]))
        seats.append(free)

    def block_start(bitmap):
        for s in range(n_max):
            if holder[s] is not None:
                misses[s] = misses[s] + 1 if bitmap >> s & 1 else 0
        taken, released = 0, []
        for s in range(n_max):
            bond = holder[s]
            if bond is None or misses[s] < params["miss_limit"]:
                continue
            cut = (stake[bond] * params["miss_slash_bps"] + 9_999) // 10_000
            stake[bond] -= cut
            taken += cut
            misses[s] = 0
            if stake[bond] < min_stake:
                holder[s] = None
                released.append(bond)
        return taken, released

    for prior in case["setup"]["prior_calls"]:
        assert block_start(int(prior["miss_bitmap"])) == (0, []), case["name"]
    held = [s for s in range(128) if holder[s] is not None]
    taken, released = block_start(int(case["call"]["miss_bitmap"]))
    keys = [scalar_key(int(reg["private_key"], 16)) for reg in case["setup"]["registrations"]]
    records = []
    for s in range(128):
        bond = holder[s]
        if bond is not None:
            power = stake[bond] // params["vp_unit"]
            assert power <= U64_MAX, case["name"]
            word2 = int(keys[bond]["ck_prefix"]) | power << 8
            records.append({"seat": str(s), "word1": keys[bond]["ck_x"], "word2": uint(word2)})
    expect = {
        "miss_counts": [{"seat": str(s), "count": str(misses[s])} for s in held],
        "eff_stakes": [{"bond_id": str(b), "eff_stake": str(v)} for b, v in enumerate(stake)],
        "released": [str(b) for b in released],
        "penalty_total": str(taken),
        "records": records,
        "snapshot_total_stake": str(sum(stake[b] for b in holder if b is not None)),
        "snapshot_height": case["call"]["block_number"],
        "last_generation": case["call"]["generation"],
    }
    return seats, expect


class VectorsTest(unittest.TestCase):
    def test_governance_authorization_and_principal_vectors(self):
        calls = V["governance_abi"]
        contracts = {
            "recover": "inbox",
            "invalidate_recovery_nonce": "inbox",
            "schedule_rules": "inbox",
            "schedule_stop": "inbox",
            "set_origin": "inbox",
            "save_forced_inclusion": "inbox",
            "sweep_protocol_fees": "inbox",
            "set_fallback_keys": "inbox",
            "set_min_total_stake": "inbox",
            "register": "staking",
            "top_up": "staking",
            "request_exit": "staking",
            "withdraw": "staking",
            "forfeit": "staking",
            "on_block_start": "staking",
            "slash_double_sign": "staking",
        }
        self.assertEqual({name: call["contract"] for name, call in calls.items()}, contracts)
        for name, call in calls.items():
            self.assertEqual(list(call), ["contract", "signature", "selector", "calldata"], name)
            self.assertEqual(call["selector"], h256(call["signature"].encode())[:10], name)
            self.assertEqual(call["calldata"][:10], call["selector"], name)

        def args(name):
            return [int(w, 16) for w in words("0x" + calls[name]["calldata"][10:])]

        # recover(expectedGeneration, expectedC, expectedRecoveryNonce, validUntil, fiToClear,
        # rules): six head words, the one list's offset fifth and `rules` last, then the cleared
        # forced inclusion indexes.
        self.assertEqual(
            calls["recover"]["signature"],
            "recover(uint48,uint256,uint256,uint256,uint256[],uint48)",
        )
        self.assertEqual(calls["recover"]["selector"], "0x95e4b1e5")
        self.assertEqual(args("recover"), [2, 12, 7, 1_700_000_123, 192, 4, 2, 3, 5])
        self.assertEqual(
            calls["invalidate_recovery_nonce"]["signature"], "invalidateRecoveryNonce(uint256)"
        )
        self.assertEqual(args("invalidate_recovery_nonce"), [7])
        # Both schedule calls take the expected generation first.
        self.assertEqual(
            calls["schedule_rules"]["signature"], "scheduleRules(uint48,uint48,uint48)"
        )
        self.assertEqual(args("schedule_rules"), [1, 2, 1_700_003_600])
        self.assertEqual(calls["schedule_stop"]["signature"], "scheduleStop(uint48,uint48)")
        self.assertEqual(args("schedule_stop"), [1, 1_700_007_200])
        # setOrigin(S): the caller supplies only the height.
        self.assertEqual(calls["set_origin"]["signature"], "setOrigin(uint48)")
        self.assertEqual(args("set_origin"), [1000])
        # saveForcedInclusion(bytes) takes the raw transaction; sweepProtocolFees() no argument.
        self.assertEqual(calls["save_forced_inclusion"]["signature"], "saveForcedInclusion(bytes)")
        fi = words("0x" + calls["save_forced_inclusion"]["calldata"][10:])
        self.assertEqual([int(w, 16) for w in fi[:2]], [32, 1])
        self.assertEqual(fi[2], "0xc0" + "00" * 31)
        self.assertEqual(calls["sweep_protocol_fees"]["signature"], "sweepProtocolFees()")
        self.assertEqual(
            calls["sweep_protocol_fees"]["calldata"], calls["sweep_protocol_fees"]["selector"]
        )
        # setFallbackKeys takes the list as (ckPrefix, ckX) pairs, here [K1, K2]; setMinTotalStake
        # one word, here the value that hands every block to the fallback keys.
        self.assertEqual(
            calls["set_fallback_keys"]["signature"], "setFallbackKeys((uint8,bytes32)[])"
        )
        self.assertEqual(
            words("0x" + calls["set_fallback_keys"]["calldata"][10:]),
            [uint(32), uint(2), uint(2), K1["ck_x"], uint(2), K2["ck_x"]],
        )
        self.assertEqual(calls["set_min_total_stake"]["signature"], "setMinTotalStake(uint256)")
        self.assertEqual(args("set_min_total_stake"), [2**256 - 1])

        # The staking entry points carry the selectors of the spec's staking interface.
        self.assertEqual(
            {name: calls[name]["selector"] for name, c in contracts.items() if c == "staking"},
            {
                "register": "0x864274b0",
                "top_up": "0xde643a71",
                "request_exit": "0x721c6513",
                "withdraw": "0x00f714ce",
                "forfeit": "0x7b41461f",
                "on_block_start": ON_BLOCK_START_SELECTOR,
                "slash_double_sign": "0xd61617a4",
            },
        )
        # register(publicKey, amount, popSig): key a1's 33 bytes, minStake and its 65-byte proof
        # of possession for owner 0xaa..aa, each byte string padded to whole words.
        self.assertEqual(calls["register"]["signature"], "register(bytes,uint256,bytes)")
        (pop,) = [d for d in V["register_digests"] if d["name"] == "a1_owner_aa"]
        register = hexbytes("0x" + calls["register"]["calldata"][10:])
        self.assertEqual(len(register), 320)
        self.assertEqual(
            [int(w, 16) for w in words("0x" + register[:96].hex())],
            [96, int(V["deployment"]["min_stake"]), 192],
        )
        self.assertEqual(int.from_bytes(register[96:128], "big"), 33)
        self.assertEqual(register[128:192], hexbytes(pop["key"]).ljust(64, b"\0"))
        self.assertEqual(int.from_bytes(register[192:224], "big"), 65)
        self.assertEqual(register[224:], hexbytes(pop["pop_sig"]).ljust(96, b"\0"))
        self.assertEqual(calls["top_up"]["signature"], "topUp(uint256,uint256)")
        self.assertEqual(args("top_up"), [0, 100])
        self.assertEqual(calls["request_exit"]["signature"], "requestExit(uint256)")
        self.assertEqual(args("request_exit"), [0])
        self.assertEqual(calls["withdraw"]["signature"], "withdraw(uint256,address)")
        self.assertEqual(
            words("0x" + calls["withdraw"]["calldata"][10:]), [uint(0), address(OWNERS[0])]
        )
        # forfeit(bondId, incidentId, validUntil): exactly three arguments.
        self.assertEqual(calls["forfeit"]["signature"], "forfeit(uint256,bytes32,uint256)")
        self.assertEqual(args("forfeit"), [0, 42, 1_700_000_123])
        # The block-start call: generation 1 and missBitmap 5, one word each.
        self.assertEqual(calls["on_block_start"]["signature"], "onBlockStart(uint48,uint128)")
        self.assertEqual(args("on_block_start"), [1, 5])
        # The slash call is the votes section's zero-parts-hash conflict.
        slash = V["votes"]["slash_abi"]
        for field in ("signature", "selector", "calldata"):
            self.assertEqual(calls["slash_double_sign"][field], slash[field], field)

        # A forfeiture takes ceil(balance * forfeitBps / 10,000) of the bond's whole principal
        # from effStake, also where the product exceeds 256 bits; nothing else is deducted.
        cases = V["forfeitures"]
        fields = ("eff_stake", "forfeit_bps", "penalty", "eff_stake_after")
        min_stake, top = int(V["deployment"]["min_stake"]), 2**256 - 1
        self.assertEqual(
            [tuple(int(c[k]) for k in fields) for c in cases],
            [
                (100, 1000, 10, 90),
                (99, 1000, 10, 89),
                (1, 1, 1, 0),
                (3, 10000, 3, 0),
                (min_stake, 1000, min_stake // 10, min_stake - min_stake // 10),
                (top, 10000, top, 0),
                (top, 1, top // 10000 + 1, top - top // 10000 - 1),
            ],
        )
        for case in cases:
            self.assertEqual(list(case), list(fields))
            balance, rate = int(case["eff_stake"]), int(case["forfeit_bps"])
            self.assertGreater(balance, 0)
            self.assertTrue(0 < rate <= 10_000)
            self.assertEqual(int(case["penalty"]), -(-balance * rate // 10_000))

    def test_top_up_and_lifetime_forfeiture_live_on_the_staking_contract(self):
        calls, events, views = V["governance_abi"], V["governance_events"], V["view_abi"]
        # A top-up is one staking call that adds to the bond at once: there is no activation
        # call, and its event carries only the bond id and the amount.
        self.assertNotIn("activate_top_up", calls)
        self.assertNotIn("top_up_activated", events)
        self.assertEqual(calls["top_up"]["contract"], "staking")
        self.assertEqual(
            (events["top_up_deposited"]["contract"], events["top_up_deposited"]["signature"]),
            ("staking", "TopUpDeposited(uint256,uint256)"),
        )
        # The lifetime forfeiture flag is a staking view keyed by bond id.
        forfeited = views["forfeited"]
        self.assertEqual(
            (forfeited["contract"], forfeited["signature"]), ("staking", "forfeited(uint256)")
        )
        self.assertEqual(words("0x" + forfeited["calldata"][10:]), [uint(0)])
        self.assertEqual([r["values"] for r in forfeited["results"]], [[True], [False]])
        self.assertEqual(events["forfeited"]["contract"], "staking")
        # Recovery authorization stays on the Inbox, in slot 292.
        self.assertEqual(calls["invalidate_recovery_nonce"]["contract"], "inbox")
        self.assertEqual(V["layout"]["inbox"]["slots"]["recovery_nonce"], "292")

    def test_entry_keys_are_removed(self):
        # The lifetime forfeiture flag and recovery exclusions use bond ids, so no key hash remains.
        self.assertTrue(all("entry_key" not in key for key in V["keys"]))
        self.assertNotIn("entry_key", json.dumps(V))
        self.assertNotIn("origin_writer", json.dumps(V))

    def test_no_registry_families(self):
        for family in ("committee_config", "registry_entries", "committee_sets"):
            self.assertNotIn(family, V)
        self.assertEqual(set(V["layout"]), {"inbox"})

        def keys_of(value):
            if isinstance(value, dict):
                return set(value) | set().union(*map(keys_of, value.values()))
            if isinstance(value, list):
                return set().union(*map(keys_of, value))
            return set()

        self.assertEqual({k for k in keys_of(V) if "registry" in k}, set())
        # No preimage carries a tag of the registry, committee set or committee record encodings,
        # and the registry's address appears nowhere.
        text = json.dumps(V)
        for retired in (
            "ETNA_PARENT_ANCHOR_V1",
            "ETNA_REG_ENTRY_V1",
            "ETNA_SET_KEY_V1",
            "ETNA_SET_V1",
            "ETNA_COMMITTEE_V1",
        ):
            self.assertNotIn(retired, text)
            self.assertNotIn(tag(retired)[2:], text)
        self.assertNotIn("22" * 20, text)

    def test_governance_event_payloads(self):
        events = V["governance_events"]
        rules = int(V["packed_words"]["inbox_293"][0]["word"], 16)
        one_key = h256(fallback_keys_preimage([K1]))
        two_keys = h256(fallback_keys_preimage([K1, K2]))
        expected = {
            "fallback_keys_updated": (
                "FallbackKeysUpdated(bytes32,(uint8,bytes32)[])",
                [32, 1, 2, int(K1["ck_x"], 16)],
            ),
            "min_total_stake_updated": ("MinTotalStakeUpdated(uint256)", [2**256 - 1]),
            "recovery_nonce_invalidated": ("RecoveryNonceInvalidated(uint256,uint256)", [7, 8]),
            "rules_schedule_updated": ("RulesScheduleUpdated(uint256)", [rules]),
            "start_written": ("StartWritten(uint256,bytes32,bytes32)", [1000, 0x51, 0x52]),
            "etna_initialized": (
                "EtnaInitialized(bytes32,address,uint256)",
                [int(V["config"]["hash"], 16), int(V["deployment"]["staking"], 16), 151_200],
            ),
            "landed": ("Landed(uint256,uint256,uint256,bytes32,uint8)", [0x77, 1]),
            # The offset of the bytes, the fee, the length, then the one-byte transaction
            # left-aligned.
            "forced_inclusion_saved": (
                "ForcedInclusionSaved(uint48,bytes,uint256)",
                [64, 1_000_000_000, 1, 0xC0 << 248],
            ),
            "protocol_fees_swept": ("ProtocolFeesSwept(uint256)", [1_000_000_000]),
            # Five head words, the list's offset last, then the cleared forced inclusion
            # indexes; the fourth word is the fallback key hash of the new origin record.
            "recovered": (
                "Recovered(uint48,uint256,uint256,uint256,bytes32,uint256[])",
                [12, 50, 1_700_000_123, int(two_keys, 16), 160, 2, 3, 5],
            ),
            "top_up_deposited": ("TopUpDeposited(uint256,uint256)", [100]),
            "forfeited": ("Forfeited(uint256,bytes32,uint256,uint256)", [42, 100, 10]),
        }
        self.assertEqual(set(events), set(expected))
        for name, (signature, values) in expected.items():
            event = events[name]
            self.assertEqual(
                list(event), ["contract", "signature", "topic0", "indexed_topics", "data"], name
            )
            self.assertEqual(event["signature"], signature, name)
            self.assertEqual([int(w, 16) for w in words(event["data"])], values, name)
        # FallbackKeysUpdated indexes the list's hash and carries the stored list: the hash's
        # preimage after the tag, with the list's offset counted from the data.
        keys_event = events["fallback_keys_updated"]
        self.assertEqual(keys_event["indexed_topics"], [one_key])
        self.assertEqual(
            hexbytes(keys_event["data"]), hexbytes(uint(32)) + fallback_keys_preimage([K1])[64:]
        )
        self.assertEqual((one_key, two_keys), (APPENDIX_A_LITERALS["enc_a_36a_a"],
                                               APPENDIX_A_LITERALS["enc_a_36a_b"]))
        # Landed indexes its three heights; ForcedInclusionSaved its queue index; Recovered the
        # new generation; the staking events the bond id. The other events index nothing.
        self.assertEqual(events["landed"]["indexed_topics"], [uint(0), uint(6), uint(12)])
        self.assertEqual(events["forced_inclusion_saved"]["indexed_topics"], [uint(3)])
        self.assertEqual(events["recovered"]["indexed_topics"], [uint(2)])
        self.assertEqual(events["top_up_deposited"]["indexed_topics"], [uint(0)])
        self.assertEqual(events["forfeited"]["indexed_topics"], [uint(0)])
        for name in (
            "min_total_stake_updated",
            "rules_schedule_updated",
            "start_written",
            "recovery_nonce_invalidated",
            "etna_initialized",
            "protocol_fees_swept",
        ):
            self.assertEqual(events[name]["indexed_topics"], [], name)

    def test_event_topics(self):
        events = V["governance_events"]
        staking = {name for name, event in events.items() if event["contract"] == "staking"}
        self.assertEqual(staking, {"top_up_deposited", "forfeited"})
        self.assertEqual({event["contract"] for event in events.values()}, {"inbox", "staking"})
        # topic0 is keccak256 of the event signature, recomputed with both Keccak-256s here.
        for name, event in events.items():
            for impl in (keccak256_python, keccak256):
                self.assertEqual(
                    "0x" + impl(event["signature"].encode()).hex(), event["topic0"], name
                )
        for name, topic in SPEC_TOPICS.items():
            self.assertEqual(events[name]["topic0"], topic, name)

    def test_view_return_data(self):
        views = V["view_abi"]
        self.assertEqual(
            {name: (v["contract"], v["signature"], v["returns"]) for name, v in views.items()},
            {
                "config_hash": ("inbox", "configHash()", "(bytes32)"),
                "etna_staking": ("inbox", "etnaStaking()", "(address)"),
                "unsettled_limit": ("inbox", "unsettledLimit()", "(uint64)"),
                "get_fallback_keys": ("inbox", "getFallbackKeys()", "((uint8,bytes32)[])"),
                "fallback_keys_hash": ("inbox", "fallbackKeysHash()", "(bytes32)"),
                "min_total_stake": ("inbox", "minTotalStake()", "(uint256)"),
                "etna_start": ("inbox", "etnaStart()", "(uint48,bytes32)"),
                "propose_cutoff": ("unzen_inbox", "proposeCutoff()", "(uint48)"),
                "bond_for_key": ("staking", "bondForKey(address)", "(bool,uint256)"),
                "seat_of_bond": ("staking", "seatOfBond(uint256)", "(bool,uint8)"),
                "bond_in_seat": ("staking", "bondInSeat(uint8)", "(bool,uint256)"),
                "snapshot": (
                    "staking",
                    "snapshot()",
                    "(uint256,uint256,(uint8,uint8,bytes32,uint64)[])",
                ),
                "register_digest": ("staking", "registerDigest(address)", "(bytes32)"),
                "forfeited": ("staking", "forfeited(uint256)", "(bool)"),
                "min_stake": ("staking", "minStake()", "(uint256)"),
            },
        )
        for name, view in views.items():
            self.assertEqual(
                list(view), ["contract", "signature", "selector", "calldata", "returns", "results"]
            )
            self.assertEqual(view["selector"], h256(view["signature"].encode())[:10], name)
            self.assertEqual(view["calldata"][:10], view["selector"], name)
            if "[]" in view["returns"]:
                continue  # the two list views are checked word by word below
            types = view["returns"][1:-1].split(",")
            for result in view["results"]:
                encoded = []
                for kind, value in zip(types, result["values"], strict=True):
                    if kind == "bool":
                        encoded.append(uint(1 if value else 0))
                    elif kind == "bytes32":
                        encoded.append(value)
                    elif kind == "address":
                        encoded.append(address(value))
                    else:
                        encoded.append(uint(value))
                self.assertEqual(words(result["data"]), encoded, (name, result["name"]))
        self.assertEqual(
            {name: views[name]["selector"] for name in
             ("bond_for_key", "seat_of_bond", "bond_in_seat", "snapshot", "register_digest")},
            {
                "bond_for_key": "0x830dc3a1",
                "seat_of_bond": "0x7b81a4dc",
                "bond_in_seat": "0xd0b5360d",
                "snapshot": "0x9711715a",
                "register_digest": "0x049785d3",
            },
        )
        # A present bond, seat or seat holder and an absent one differ only in the flag word:
        # (true, 0) names bond 0 or seat 0 and (false, 0) is absence.
        for name in ("bond_for_key", "seat_of_bond", "bond_in_seat"):
            present, absent = views[name]["results"]
            self.assertEqual(present["values"], [True, "0"], name)
            self.assertEqual(absent["values"], [False, "0"], name)
        self.assertEqual(
            words("0x" + views["bond_for_key"]["calldata"][10:]),
            [address(V["keys"][0]["ck_addr"])],
        )
        for name in ("seat_of_bond", "bond_in_seat"):
            self.assertEqual(words("0x" + views[name]["calldata"][10:]), [uint(0)], name)
        # snapshot(): the height word, the total stake, then the occupied seats in ascending
        # seat order as (seat, ckPrefix, ckX, power): seat 0 holds K1 at power 100,000 and seat
        # 2 K2 at 250,000; an empty snapshot is all zero with no member.
        two_seats, empty = views["snapshot"]["results"]
        self.assertEqual(
            two_seats["values"],
            ["10", str(350_000 * 10**9),
             [["0", "2", K1["ck_x"], "100000"], ["2", "2", K2["ck_x"], "250000"]]],
        )
        self.assertEqual(
            words(two_seats["data"]),
            [uint(10), uint(350_000 * 10**9), uint(96), uint(2),
             uint(0), uint(2), K1["ck_x"], uint(100_000),
             uint(2), uint(2), K2["ck_x"], uint(250_000)],
        )
        self.assertEqual(empty["values"], ["0", "0", []])
        self.assertEqual(words(empty["data"]), [uint(0), uint(0), uint(96), uint(0)])
        # registerDigest(owner) is the owner's EIP-712 registration digest.
        (digest,) = views["register_digest"]["results"]
        self.assertEqual(words("0x" + views["register_digest"]["calldata"][10:]),
                         [address(OWNERS[0])])
        (pop,) = [d for d in V["register_digests"] if d["name"] == "a1_owner_aa"]
        self.assertEqual(digest["values"], [pop["digest"]])
        (min_stake,) = views["min_stake"]["results"]
        self.assertEqual(min_stake["values"], [V["deployment"]["min_stake"]])
        # The Inbox's configuration views: the config hash, its staking address and U.
        for name, value in (
            ("config_hash", V["config"]["hash"]),
            ("etna_staking", V["deployment"]["staking"]),
            ("unsettled_limit", V["deployment"]["unsettled_limit"]),
        ):
            (result,) = views[name]["results"]
            self.assertEqual(result["values"], [value], name)
            self.assertEqual(views[name]["calldata"], views[name]["selector"], name)
        # getFallbackKeys() returns the stored list [K1, K2], fallbackKeysHash() its hash.
        (keys,) = views["get_fallback_keys"]["results"]
        self.assertEqual(keys["values"], [[["2", K1["ck_x"]], ["2", K2["ck_x"]]]])
        self.assertEqual(
            words(keys["data"]), [uint(32), uint(2), uint(2), K1["ck_x"], uint(2), K2["ck_x"]]
        )
        (keys_hash,) = views["fallback_keys_hash"]["results"]
        self.assertEqual(keys_hash["values"], [APPENDIX_A_LITERALS["enc_a_36a_b"]])
        self.assertEqual(
            [r["values"] for r in views["min_total_stake"]["results"]],
            [[str(2**256 - 1)], ["0"]],
        )
        self.assertEqual(views["etna_start"]["calldata"], views["etna_start"]["selector"])
        written, not_written = views["etna_start"]["results"]
        self.assertEqual(not_written["data"], "0x" + "00" * 64)
        # The start that `setOrigin(S)` writes: S and the hash it copies, as StartWritten reports.
        origin = words("0x" + V["governance_abi"]["set_origin"]["calldata"][10:])
        start = words(V["governance_events"]["start_written"]["data"])
        self.assertEqual(words(written["data"]), [origin[0], start[1]])
        self.assertEqual(start[0], origin[0])
        installed, not_installed = views["propose_cutoff"]["results"]
        self.assertGreater(int(installed["values"][0]), 0)
        self.assertLess(int(installed["values"][0]), 2**48)
        self.assertEqual(not_installed["data"], uint(0))

    def test_schema_is_ten(self):
        self.assertEqual(V["schema_version"], "10")

    def test_deployment(self):
        self.assertEqual(
            V["deployment"],
            {
                "l1_chain_id": "1",
                "l2_chain_id": "167001",
                "inbox": "0x1111111111111111111111111111111111111111",
                "staking": "0x1670010000000000000000000000000000010003",
                "token": "0x1670010000000000000000000000000000000007",
                "l2_block_gas_limit": "45000000",
                "min_stake": str(7_812_500 * 10**18),
                "vp_unit": str(10**9),
                "n_max": "128",
                "miss_limit": "3600",
                "miss_slash_bps": "1000",
                "slash_bounty_bps": "1000",
                "forfeit_bps": "1000",
                "withdrawal_delay": "302402",
                "unsettled_limit": "151200",
                "evidence_window_blocks": "151200",
                "etna_start": "0",
                "unzen_inbox": "0x0000000000000000000000000000000000000000",
                "etna_fork_time": "0",
            },
        )
        d = {k: int(v) for k, v in V["deployment"].items() if not v.startswith("0x")}
        # The staking proxy and the bridged token are chain 167001's genesis predeploys: the
        # chain id's digits, zeros, then the suffix 10003 or 7, forty hex digits in all.
        for name, suffix in (("staking", "10003"), ("token", "7")):
            self.assertEqual(V["deployment"][name], "0x167001" + suffix.rjust(34, "0"), name)
        # The staking contract's bounds: vp_unit at least ceil(10^27 / MaxTotalVotingPower),
        # minStake at least vp_unit and n_max seats at minStake at least 10^27 base units,
        # 1 <= n_max <= 128, 1 <= missLimit <= 65,535, both penalty rates in (0, 10,000], the
        # bounty below 10,000, 1 <= U <= 262,144, and withdrawalDelay at least U + 2 + the
        # evidence window and below 2^48.
        self.assertEqual(-(-(10**27) // ((2**63 - 1) // 8)), 867_361_738)
        self.assertGreaterEqual(d["vp_unit"], 867_361_738)
        self.assertGreaterEqual(d["min_stake"], d["vp_unit"])
        self.assertGreaterEqual(d["min_stake"] * d["n_max"], 10**27)
        self.assertTrue(1 <= d["n_max"] <= 128)
        self.assertTrue(1 <= d["miss_limit"] <= 65_535)
        self.assertTrue(0 < d["miss_slash_bps"] <= 10_000)
        self.assertTrue(0 < d["forfeit_bps"] <= 10_000)
        self.assertLess(d["slash_bounty_bps"], 10_000)
        self.assertTrue(1 <= d["unsettled_limit"] <= 262_144)
        self.assertGreaterEqual(
            d["withdrawal_delay"], d["unsettled_limit"] + 2 + d["evidence_window_blocks"]
        )
        self.assertLess(d["withdrawal_delay"], 2**48)

    def test_config_is_four_words_and_matches_the_spec_literal(self):
        cfg, deployment = V["config"], V["deployment"]
        self.assertEqual(list(cfg), ["inputs", "preimage", "hash"])
        self.assertEqual(
            cfg["inputs"],
            {
                "tag": "ETNA_CONFIG_V1",
                "l2_chain_id": deployment["l2_chain_id"],
                "staking": deployment["staking"],
                "unsettled_limit": deployment["unsettled_limit"],
            },
        )
        self.assertEqual(list(cfg["inputs"]), ["tag", "l2_chain_id", "staking", "unsettled_limit"])
        self.assertEqual(
            hexbytes(cfg["preimage"]),
            join_words(
                tag("ETNA_CONFIG_V1"),
                uint(deployment["l2_chain_id"]),
                address(deployment["staking"]),
                uint(deployment["unsettled_limit"]),
            ),
        )
        self.assertEqual(len(hexbytes(cfg["preimage"])), 128)
        self.assertEqual(h256(hexbytes(cfg["preimage"])), cfg["hash"])
        # The spec's own example, encoded and hashed here: L2 chain id 167000, staking
        # 0x1111..11 and U = 151,200.
        example = join_words(
            tag("ETNA_CONFIG_V1"), uint(167_000), address("0x" + "11" * 20), uint(151_200)
        )
        for impl in (keccak256_python, keccak256):
            self.assertEqual("0x" + impl(example).hex(), APPENDIX_A_LITERALS["enc_a_36_a"])
        spec = V["appendix_a_examples"]["enc_a_36_a"]
        self.assertEqual(hexbytes(spec["preimage"]), example)
        self.assertEqual(spec["hash"], APPENDIX_A_LITERALS["enc_a_36_a"])

    def test_validator_state_published_encoding(self):
        case = V["validator_states"][0]
        self.assertEqual(
            case["hash"],
            "0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b",
        )
        self.assertEqual(len(hexbytes(case["preimage"])), 768)
        w = words(case["preimage"])
        self.assertEqual(
            w[:6],
            [tag("ETNA_VAL_STATE_V1"), uint(6), uint(192), uint(1), uint(480), uint(0)],
        )
        self.assertEqual(w[6], uint(2))
        self.assertEqual(w[15], uint(2))
        self.assertEqual(w[10], uint(2**256 - 5))
        self.assertEqual(w[23], uint(2**256 - 5))
        self.assertEqual(w[14], uint(5))
        self.assertEqual(w[19], uint(5))
        self.assertNotEqual(case["hash"], case["changed_current_proposer_hash"])
        self.assertNotEqual(case["hash"], case["changed_next_proposer_hash"])

    def test_keccak256(self):
        published = V["validator_states"][0]
        config = V["config"]
        key = V["keys"][0]
        for impl in (keccak256_python, keccak256):
            self.assertEqual("0x" + impl(b"").hex(), KECCAK_EMPTY)
            self.assertEqual("0x" + impl(hexbytes(published["preimage"])).hex(), published["hash"])
            self.assertEqual("0x" + impl(hexbytes(config["preimage"])).hex(), config["hash"])
            self.assertEqual(
                "0x" + impl(hexbytes(key["ck_x"]) + hexbytes(key["ck_y"]))[12:].hex(),
                key["ck_addr"],
            )

    def test_validator_state_chain_keys(self):
        section = V["val_state_chains"]
        self.assertEqual(section["cometbft"], "v0.40.0")
        self.assertEqual([k["name"] for k in section["keys"]], [f"c{i}" for i in range(1, 13)])
        for i, key in enumerate(section["keys"], start=1):
            self.assertEqual(int(key["private_key"], 16), 0xC0 + i)
            point = ec_mul(SECP_G, 0xC0 + i)
            self.assertEqual(decompress(hexbytes(key["public_key"])), point)
            self.assertEqual(int(key["ck_prefix"]), 2 + (point[1] & 1))
            self.assertEqual((int(key["ck_x"], 16), int(key["ck_y"], 16)), point)
            self.assertEqual(key["ck_addr"], "0x" + eth_address(point))

    def test_validator_state_chain_replay(self):
        """Every state is what valset_model's reading of CometBFT v0.40.0 gives, events included."""
        section = V["val_state_chains"]
        address = {k["name"]: k["ck_addr"][2:] for k in section["keys"]}
        self.assertEqual(
            [c["name"] for c in section["chains"]],
            ["gen0", "gen1", "bounds_a", "bounds_b", "bounds_c"],
        )
        for chain in section["chains"]:
            start, end = int(chain["start_height"]), int(chain["end_height"])
            epoch_length = int(chain["epoch_length"])
            self.assertGreaterEqual(epoch_length, 3)  # START-10-7
            updates = {}
            for switch in chain["switches"]:
                height, t = int(switch["height"]), int(switch["epoch"])
                # FinalizeBlock at S(t) = H(t) - 2 returns the update; it first signs H(t).
                self.assertEqual(height, t * epoch_length - 1)
                self.assertEqual(int(switch["activation_height"]), t * epoch_length + 1)
                self.assertTrue(start < height <= end)
                updates[height] = [(k, int(p)) for k, p in switch["changes"]]
            genesis = [(k, int(p)) for k, p in chain["genesis"]]
            states, events = valset_model.replay(address, start, end, genesis, updates)
            self.assertEqual(
                [int(s["height"]) for s in chain["states"]], list(range(start, end + 1))
            )
            for state, (height, current, following) in zip(chain["states"], states, strict=True):
                with self.subTest(chain=chain["name"], height=height):
                    self.assertEqual(as_entries(state["current"]), current.entries())
                    self.assertEqual(int(state["current_proposer"]), current.proposer_index())
                    self.assertEqual(as_entries(state["next"]), following.entries())
                    self.assertEqual(int(state["next_proposer"]), following.proposer_index())
            self.assertEqual(chain["events"], model_events(events))

    def test_validator_state_chain_hashes(self):
        section = V["val_state_chains"]
        keys = {k["name"]: k for k in section["keys"]}
        for chain in section["chains"]:
            hashes = set()
            for i, state in enumerate(chain["states"]):
                preimage = val_state_preimage(
                    int(state["height"]),
                    as_entries(state["current"]),
                    int(state["current_proposer"]),
                    as_entries(state["next"]),
                    int(state["next_proposer"]),
                    keys,
                )
                self.assertEqual("0x" + keccak256(preimage).hex(), state["hash"], state["height"])
                hashes.add(state["hash"])
                if i == 0:
                    self.assertEqual(preimage, hexbytes(chain["start_preimage"]))
                    w = words(chain["start_preimage"])
                    n = len(state["current"])
                    self.assertEqual(w[0], tag("ETNA_VAL_STATE_V1"))
                    self.assertEqual(
                        w[1:6],
                        [
                            uint(state["height"]),
                            uint(192),
                            uint(state["current_proposer"]),
                            uint(192 + 32 + 128 * n),
                            uint(state["next_proposer"]),
                        ],
                    )
                    self.assertEqual(len(w), 6 + 2 + 4 * (n + len(state["next"])))
            self.assertEqual(len(hashes), len(chain["states"]))

    def test_validator_state_chain_invariants(self):
        section = V["val_state_chains"]
        keys = {k["name"]: k for k in section["keys"]}
        stored_not_highest = 0
        for chain in section["chains"]:
            states = chain["states"]
            switches = {int(s["height"]): s for s in chain["switches"]}
            genesis = {k: int(p) for k, p in chain["genesis"]}
            self.assertEqual(committee(states[0]["current"]), genesis)
            self.assertEqual(committee(states[0]["next"]), genesis)
            for i, state in enumerate(states):
                height = int(state["height"])
                for side in ("current", "next"):
                    entries = as_entries(state[side])
                    proposer = int(state[side + "_proposer"])
                    # Set order: voting power descending, then secp256k1eth address ascending.
                    order = [(-power, keys[key]["ck_addr"]) for key, power, _ in entries]
                    self.assertEqual(order, sorted(set(order)))
                    self.assertTrue(0 <= proposer < len(entries))
                    # Centering subtracts floor(sum / n), leaving a sum in [0, n - 1], and the
                    # increment adds and removes the same total.
                    self.assertTrue(0 <= sum(e[2] for e in entries) <= len(entries) - 1)
                    # The stored proposer was decremented by the total: it is not recomputed.
                    if entries[proposer][2] != max(e[2] for e in entries):
                        stored_not_highest += 1
                if i == 0:
                    continue
                previous = states[i - 1]
                # Validators at x is NextValidators at x - 1, with its stored proposer.
                self.assertEqual(state["current"], previous["next"])
                self.assertEqual(state["current_proposer"], previous["next_proposer"])
                expected = committee(previous["next"])
                for key, power in switches.get(height, {"changes": []})["changes"]:
                    if int(power):
                        expected[key] = int(power)
                    else:
                        del expected[key]
                self.assertEqual(committee(state["next"]), expected)
            # H + 2: a switch returned at S(t) signs neither S(t) + 1 (current at S(t)) nor
            # S(t) + 2 = H(t) until current at S(t) + 1.
            by_height = {int(s["height"]): s for s in states}
            for height, switch in switches.items():
                new = committee(by_height[height]["next"])
                self.assertNotEqual(committee(by_height[height]["current"]), new)
                if height + 1 in by_height:
                    self.assertEqual(committee(by_height[height + 1]["current"]), new)
        self.assertGreater(stored_not_highest, 0)

    def test_validator_state_events_cover_bounds(self):
        """Rescaling at 2·total (none) and 2·total + 1 (ratio 2) in both UpdateWithChangeSet and
        IncrementProposerPriority, floor centering at its n - 1 residual, truncation toward zero
        and proposer ties broken by address."""
        section = V["val_state_chains"]
        address = {k["name"]: k["ck_addr"] for k in section["keys"]}
        seen = set()
        for chain in section["chains"]:
            for event in chain["events"]:
                if event["kind"] == "rescale":
                    diff, diff_max = int(event["diff"]), int(event["diff_max"])
                    self.assertGreaterEqual(diff, diff_max)
                    self.assertEqual(event["fires"], diff > diff_max)
                    if event["fires"]:
                        self.assertEqual(int(event["ratio"]), -(-diff // diff_max))
                        if event["truncated"]:
                            seen.add("truncated")
                    seen.add((event["step"], "rescale", diff - diff_max))
                elif event["kind"] == "center":
                    total, count = int(event["sum"]), int(event["count"])
                    self.assertTrue(total < 0 and total % count)
                    self.assertEqual(int(event["shift"]), total // count)
                    if total - count * (total // count) == count - 1:
                        seen.add("center_residual_n_minus_1")
                else:
                    self.assertEqual(event["kind"], "tie")
                    self.assertGreater(len(event["tied"]), 1)
                    self.assertEqual(event["proposer"], event["tied"][0])
                    self.assertEqual(event["tied"], sorted(event["tied"], key=address.get))
                    seen.add("tie")
        for step in ("update", "increment"):
            self.assertIn((step, "rescale", 0), seen)
            self.assertIn((step, "rescale", 1), seen)
        self.assertTrue({"truncated", "center_residual_n_minus_1", "tie"} <= seen)

    def test_no_landing_carries_validator_state(self):
        # ENC-A-29a.m: no cut leaf, slot 285 record or statement carries valStateHash; only appHash
        # commits it (ENC-A-29b), so the chains have no landing section.
        self.assertEqual(
            set(V["val_state_chains"]), {"cometbft", "keys", "chains", "max_committee"}
        )
        for cut in V["cuts"]["table"]:
            self.assertNotIn("val_state_hash", cut)
        for statement in V["land_statements"]:
            self.assertFalse([k for k in statement["inputs"] if "val_state" in k])

    def test_app_hash_is_three_words(self):
        (case,) = V["app_hashes"]
        self.assertEqual(case["name"], "ENC-A-29b.g")
        self.assertEqual(case["height"], "6")
        self.assertEqual(case["block_hash"], "0x" + "11" * 32)
        self.assertEqual(case["val_state_hash"], V["validator_states"][0]["hash"])
        self.assertEqual(
            words(case["preimage"]),
            [tag("ETNA_APP_HASH_V1"), case["block_hash"], case["val_state_hash"]],
        )
        self.assertEqual("0x" + keccak256(hexbytes(case["preimage"])).hex(), case["hash"])
        self.assertEqual(
            case["hash"], "0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451"
        )

    def test_validator_state_max_committee(self):
        """Rebuilds the 4096-member committee at MaxTotalVotingPower from its rules."""
        mc = V["val_state_chains"]["max_committee"]
        size, total = int(mc["size"]), int(mc["total_power"])
        self.assertEqual((size, total), (4096, (2**63 - 1) // 8))
        keys, address, genesis = {}, {}, []
        point = ec_mul(SECP_G, int(mc["first_private_key"], 16))
        for i in range(size):
            if i:
                point = ec_add(point, SECP_G)
            name = f"m{i}"
            keys[name] = {"ck_prefix": 2 + (point[1] & 1), "ck_x": "0x%064x" % point[0]}
            address[name] = eth_address(point)
            genesis.append((name, 2**48 + i % 64 - 32))
        genesis[-1] = (genesis[-1][0], total - sum(p for _, p in genesis[:-1]))
        self.assertEqual(int(mc["last_member_power"]), genesis[-1][1])
        start = int(mc["start_height"])
        states, events = valset_model.replay(
            address, start, start + len(mc["states"]) - 1, genesis, {}
        )
        for state, (height, current, following) in zip(mc["states"], states, strict=True):
            self.assertEqual(int(state["height"]), height)
            for side, valset in (("current", current), ("next", following)):
                entries = valset.entries()
                head, tail = as_entries(state[side + "_head"]), as_entries(state[side + "_tail"])
                self.assertEqual(head, entries[: len(head)])
                self.assertEqual(tail, entries[-len(tail) :])
                self.assertEqual(int(state[side + "_proposer"]), valset.proposer_index())
                self.assertEqual(valset.total(), total)
                self.assertEqual(len(entries), size)
            preimage = val_state_preimage(
                height,
                current.entries(),
                current.proposer_index(),
                following.entries(),
                following.proposer_index(),
                keys,
            )
            self.assertEqual(len(preimage), int(state["preimage_bytes"]))
            self.assertEqual("0x" + keccak256(preimage).hex(), state["hash"])
        self.assertEqual(mc["events"], model_events(events))

    def test_statements_have_nineteen_words(self):
        statements = V["land_statements"]
        self.assertEqual([s["name"] for s in statements], ["genesis", "nonzero"])
        table = {int(c["height"]): c for c in V["cuts"]["table"]}
        deployment = V["deployment"]
        for statement in statements:
            inputs = statement["inputs"]
            self.assertEqual(
                list(inputs),
                [
                    "tag",
                    "l1_chain_id",
                    "l2_chain_id",
                    "inbox",
                    "generation",
                    "parent_height",
                    "parent_hash",
                    "parent_comet_hash",
                    "config_hash",
                    "last_height",
                    "last_block_hash",
                    "last_comet_hash",
                    "last_state_root",
                    "l1_reference_block_number",
                    "l1_reference_block_hash",
                    "blob_hashes",
                    "forced_inclusion_head_before",
                    "forced_inclusion_head_after",
                    "cut_hash",
                ],
            )
            p, h = int(inputs["parent_height"]), int(inputs["last_height"])
            self.assertEqual(len(hexbytes(statement["preimage"])), 608)
            self.assertEqual(inputs["tag"], "TAIKO_ETNA_LAND_V1")
            for name in ("l1_chain_id", "l2_chain_id", "inbox"):
                self.assertEqual(inputs[name], deployment[name], name)
            self.assertEqual(inputs["config_hash"], V["config"]["hash"])
            # Origin and terminal values follow the cut table.
            self.assertEqual(inputs["parent_hash"], table[p]["block_hash"])
            self.assertEqual(inputs["parent_comet_hash"], table[p]["comet_hash"])
            self.assertEqual(
                int(inputs["forced_inclusion_head_before"]), int(table[p]["forced_head"])
            )
            self.assertEqual(inputs["last_block_hash"], table[h]["block_hash"])
            self.assertEqual(inputs["last_comet_hash"], table[h]["comet_hash"])
            self.assertEqual(
                int(inputs["forced_inclusion_head_after"]), int(table[h]["forced_head"])
            )
            cut = [
                c
                for c in V["cuts"]["cut_hashes"]
                if (int(c["generation"]), int(c["parent_height"]), int(c["last_height"]))
                == (int(inputs["generation"]), p, h)
            ]
            self.assertEqual(len(cut), 1)
            self.assertEqual(inputs["cut_hash"], cut[0]["cut_hash"])
            blobs = b"".join(hexbytes(blob) for blob in inputs["blob_hashes"])
            self.assertEqual("0x" + keccak256(blobs).hex(), statement["blob_hashes_hash"])
            for blob in inputs["blob_hashes"]:
                self.assertEqual(len(hexbytes(blob)), 32)
                self.assertEqual(hexbytes(blob)[0], 0x01)
            # The tag, the deployment, the proof origin, configHash, the terminal values, the L1
            # reference, the blobs, both FI heads and the cut hash: no staking address and no
            # committee snapshot.
            self.assertEqual(
                words(statement["preimage"]),
                [
                    tag(inputs["tag"]),
                    uint(inputs["l1_chain_id"]),
                    uint(inputs["l2_chain_id"]),
                    address(inputs["inbox"]),
                    uint(inputs["generation"]),
                    uint(p),
                    inputs["parent_hash"],
                    inputs["parent_comet_hash"],
                    inputs["config_hash"],
                    uint(h),
                    inputs["last_block_hash"],
                    inputs["last_comet_hash"],
                    inputs["last_state_root"],
                    uint(inputs["l1_reference_block_number"]),
                    inputs["l1_reference_block_hash"],
                    statement["blob_hashes_hash"],
                    uint(inputs["forced_inclusion_head_before"]),
                    uint(inputs["forced_inclusion_head_after"]),
                    inputs["cut_hash"],
                ],
            )
            self.assertNotIn(address(deployment["staking"]), words(statement["preimage"]))
            self.assertEqual(
                "0x" + keccak256(hexbytes(statement["preimage"])).hex(), statement["hash"]
            )

    def test_cut_leaves_are_four_words(self):
        self.assertEqual(set(V["cuts"]), {"table", "cut_hashes"})
        table = V["cuts"]["table"]
        self.assertEqual([int(c["height"]) for c in table], list(range(19)))
        for cut in table:
            x = int(cut["height"])
            self.assertEqual(
                set(cut), {"height", "block_hash", "comet_hash", "forced_head", "preimage", "leaf"}
            )
            self.assertEqual(len(hexbytes(cut["preimage"])), 128)
            self.assertEqual(int(cut["forced_head"]), x // FI_STEP)
            self.assertEqual(cut["block_hash"], uint(100 + x))
            self.assertEqual(cut["comet_hash"], uint(0 if x == 0 else 200 + x))
            self.assertEqual(
                words(cut["preimage"]),
                [uint(x), cut["block_hash"], cut["comet_hash"], uint(cut["forced_head"])],
            )
            self.assertEqual("0x" + keccak256(hexbytes(cut["preimage"])).hex(), cut["leaf"])

    def test_empty_cut_list_hashes_empty_string(self):
        empty = [
            c
            for c in V["cuts"]["cut_hashes"]
            if int(c["last_height"]) == int(c["parent_height"]) + 1
        ]
        self.assertEqual(len(empty), 2)
        for case in empty:
            self.assertEqual(case["leaves"], [])
            self.assertEqual(case["leaves_hash"], KECCAK_EMPTY)

    def test_cut_hash_has_one_leaf_per_height(self):
        cases = V["cuts"]["cut_hashes"]
        fields = ("etna_start", "generation", "parent_height", "last_height")
        self.assertEqual(
            [tuple(int(c[k]) for k in fields) for c in cases],
            [
                (0, 0, 0, 1),
                (0, 0, 0, 2),
                (0, 0, 0, 6),
                (0, 0, 0, 18),
                (0, 1, 6, 18),
                (0, 2, 17, 18),
                (1000, 0, 1000, 1003),
            ],
        )

        def leaf(x):
            # cutLeaf(x) of the cut model, encoded and hashed here, independently of `cast`.
            cut = [x, 100 + x, 0 if x == 0 else 200 + x, x // FI_STEP]
            return "0x" + keccak256(b"".join(hexbytes(uint(v)) for v in cut)).hex()

        for case in cases:
            p, h = int(case["parent_height"]), int(case["last_height"])
            # The leaves of the heights strictly between p and h, in height order (ENC-A-31).
            self.assertEqual(case["leaves"], [leaf(x) for x in range(p + 1, h)])
            self.assertEqual(len(case["leaves"]), h - p - 1)
            packed = b"".join(hexbytes(x) for x in case["leaves"])
            self.assertEqual("0x" + keccak256(packed).hex(), case["leaves_hash"])
            self.assertEqual(len(hexbytes(case["preimage"])), 160)
            self.assertEqual(
                words(case["preimage"]),
                [
                    tag("ETNA_LAND_CUTS_V1"),
                    uint(case["generation"]),
                    uint(p),
                    uint(h),
                    case["leaves_hash"],
                ],
            )
            self.assertEqual("0x" + keccak256(hexbytes(case["preimage"])).hex(), case["cut_hash"])
        # h = p + 2 carries exactly cutLeaf(p + 1) (ENC-A-31.e), and S = 1000 with (1000, 1003]
        # carries the two leaves at 1001 and 1002 (ENC-A-33.f).
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        self.assertEqual(by_name(cases, "g0_p0_h2")["leaves"], [table[1]])
        self.assertEqual(len(by_name(cases, "s1000_g0_p1000_h1003")["leaves"]), 2)

    def test_chain_ids_are_48_ascii_bytes(self):
        domains = V["chain_domains"]
        inbox = V["deployment"]["inbox"]
        self.assertEqual(
            [(d["inbox"], int(d["generation"])) for d in domains],
            [(inbox, 0), (inbox, 1), (inbox, 2), (inbox, U48_MAX), ("0x" + "33" * 20, 0)],
        )
        chain_ids = set()
        for domain in domains:
            chain_id = domain["chain_id"]
            self.assertTrue(chain_id.startswith("etna-"))
            self.assertEqual(len(chain_id.encode("ascii")), 48)
            rest = chain_id[len("etna-") :]
            self.assertTrue(set(rest) <= CHAIN_ID_ALPHABET)
            self.assertEqual(base64.urlsafe_b64decode(rest + "="), hexbytes(domain["chain_domain"]))
            self.assertEqual(
                words(domain["preimage"]),
                [
                    tag("ETNA_COMET_DOMAIN_V1"),
                    uint(domain["l1_chain_id"]),
                    uint(domain["l2_chain_id"]),
                    address(domain["inbox"]),
                    uint(domain["generation"]),
                ],
            )
            chain_ids.add(chain_id)
        self.assertEqual(len(chain_ids), len(domains))

    def test_vote_cases_present(self):
        votes = V["votes"]
        self.assertEqual(list(votes), ["key", "chain_ids", "cases", "pairs", "slash_abi"])
        key = V["keys"][0]
        self.assertEqual(key["name"], "a1")
        self.assertEqual(
            votes["key"],
            {
                "private_key": key["private_key"],
                "public_key": key["public_key"],
                "signer": key["ck_addr"],
            },
        )
        inbox = V["deployment"]["inbox"]
        domains = {(d["inbox"], d["generation"]): d["chain_id"] for d in V["chain_domains"]}
        self.assertEqual(
            [(c["inbox"], c["generation"]) for c in votes["chain_ids"]],
            [(inbox, "0"), (inbox, "1"), (inbox, "2"), (OTHER_INBOX, "0")],
        )
        for entry in votes["chain_ids"]:
            self.assertEqual(list(entry), ["inbox", "generation", "chain_id"])
            self.assertEqual(entry["chain_id"], domains[(entry["inbox"], entry["generation"])])
        chain_ids = {(c["inbox"], c["generation"]): c["chain_id"] for c in votes["chain_ids"]}

        cases = votes["cases"]
        self.assertEqual([c["name"] for c in cases], VOTE_CASES)
        a = ("0x" + "aa" * 32, "1", "0x" + "ab" * 32)
        b = ("0x" + "bb" * 32, "2", "0x" + "bc" * 32)
        nil = ("0x", "0", "0x")
        # name: (type, round, block id, generation); height 1000 and timestamp (1700000000, 123)
        # unless `heights` or `timestamps` says otherwise.
        heights = {"precommit_b_h1001": "1001"}
        timestamps = {
            "precommit_a_late": ("1700000001", "0"),
            "zero_timestamp": ("0", "0"),
            "negative_timestamp": ("-1", "123"),
            "min_timestamp": (str(MIN_VOTE_SECONDS), "0"),
            "max_timestamp_seconds": (str(MAX_VOTE_SECONDS), "0"),
            "precommit_a_backdated": ("-1", "0"),
            "precommit_b_backdated": ("-1", "0"),
        }
        expected = {
            "precommit_a": ("2", "0", a, "0"),
            "precommit_nil": ("2", "0", nil, "0"),
            "precommit_b": ("2", "0", b, "0"),
            "precommit_a_late": ("2", "0", a, "0"),
            "prevote_a_r1": ("1", "1", a, "0"),
            "prevote_b_r1": ("1", "1", b, "0"),
            "prevote_b_r2": ("1", "2", b, "0"),
            "precommit_b_r1": ("2", "1", b, "0"),
            "gen1_precommit_a": ("2", "0", a, "1"),
            "gen1_precommit_b": ("2", "0", b, "1"),
            "gen2_precommit_a": ("2", "0", a, "2"),
            "gen2_precommit_b": ("2", "0", b, "2"),
            "other_inbox_precommit_b": ("2", "0", b, "0"),
            "partial_block_id": ("2", "0", ("0x", "1", "0x" + "ab" * 32), "0"),
            "precommit_b_h1001": ("2", "0", b, "0"),
            "hash_only_block_id": ("2", "0", ("0x" + "aa" * 32, "0", "0x"), "0"),
            "zero_timestamp": ("2", "0", a, "0"),
            "negative_timestamp": ("2", "0", a, "0"),
            "min_timestamp": ("2", "0", a, "0"),
            "max_timestamp_seconds": ("2", "0", a, "0"),
            "precommit_a_backdated": ("2", "0", a, "0"),
            "precommit_b_backdated": ("2", "0", b, "0"),
            "precommit_zero_block_hash": ("2", "0", (uint(0), "1", a[2]), "0"),
            "precommit_zero_parts_hash": ("2", "0", (a[0], "1", uint(0)), "0"),
            "precommit_zero_both_hashes": ("2", "0", (uint(0), "1", uint(0)), "0"),
            "zero_hashes_zero_total": ("2", "0", (uint(0), "0", uint(0)), "0"),
            "zero_block_hash_only": ("2", "0", (uint(0), "0", "0x"), "0"),
            "zero_parts_hash_only": ("2", "0", ("0x", "0", uint(0)), "0"),
        }
        for case in cases:
            name, vote = case["name"], case["vote"]
            self.assertEqual(list(case), ["name", "vote", "chain_id", "sign_bytes", "signature"])
            self.assertEqual(list(vote), VOTE_FIELDS, name)
            case_inbox = OTHER_INBOX if name.startswith("other_inbox") else inbox
            self.assertEqual(case["chain_id"], chain_ids[(case_inbox, vote["generation"])], name)
            if name == "max_values":
                continue
            vote_type, round_, block_id, generation = expected[name]
            height = heights.get(name, "1000")
            seconds, nanos = timestamps.get(name, ("1700000000", "123"))
            timestamp = (seconds, str(int(seconds) % 2**64), nanos)
            self.assertEqual(
                vote,
                dict(
                    zip(
                        VOTE_FIELDS,
                        (vote_type, height, round_, *block_id, *timestamp, generation),
                    )
                ),
                name,
            )
        # Each field at its largest value that CometBFT v0.40.0 can sign: int64 height, int32
        # round, uint32 part count, and the last second protobuf's Timestamp can represent.
        self.assertEqual(
            by_name(cases, "max_values")["vote"],
            dict(
                zip(
                    VOTE_FIELDS,
                    (
                        "2",
                        str(2**63 - 1),
                        str(2**31 - 1),
                        "0x" + "aa" * 32,
                        str(2**32 - 1),
                        "0x" + "ab" * 32,
                        "253402300799",
                        "253402300799",
                        "999999999",
                        "0",
                    ),
                )
            ),
        )

    def test_vote_sign_bytes_end_with_48_byte_chain_id(self):
        prefix_lengths = set()
        for case in V["votes"]["cases"]:
            sign_bytes = hexbytes(case["sign_bytes"])
            chain_id = case["chain_id"].encode("ascii")
            self.assertEqual(len(chain_id), 48)
            self.assertTrue(sign_bytes.endswith(b"\x32\x30" + chain_id), case["name"])
            length, start = read_uvarint(sign_bytes, 0)
            self.assertEqual(length, len(sign_bytes) - start, case["name"])
            prefix_lengths.add(start)
        # Both one-byte (nil vote) and two-byte (body above 127 bytes) length prefixes occur.
        self.assertEqual(prefix_lengths, {1, 2})

    def test_vote_sign_bytes_decode_to_vote(self):
        for case in V["votes"]["cases"]:
            vote, chain_id = decode_vote_sign_bytes(hexbytes(case["sign_bytes"]))
            expected = {k: v for k, v in case["vote"].items() if k != "generation"}
            self.assertEqual(vote, expected, case["name"])
            self.assertEqual(chain_id, case["chain_id"], case["name"])
        cases = V["votes"]["cases"]
        self.assertEqual(len({c["sign_bytes"] for c in cases}), len(cases))
        # A partial block id omits only the zero hash; a nil vote omits the whole block id.
        def body(name):
            sign_bytes = hexbytes(by_name(cases, name)["sign_bytes"])
            return read_message(sign_bytes[read_uvarint(sign_bytes, 0)[1] :])

        self.assertEqual(list(read_message(body("partial_block_id")[4])), [2])
        self.assertEqual(list(body("precommit_nil")), [1, 2, 5, 6])
        self.assertEqual(list(body("max_values")), [1, 2, 3, 4, 5, 6])
        # An all-zero part set header is still written, as `12 00`, after a present hash; a zero
        # timestamp is still written, as `2a 00`.
        self.assertEqual(
            body("hash_only_block_id")[4], b"\x0a\x20" + b"\xaa" * 32 + b"\x12\x00"
        )
        self.assertEqual(body("zero_timestamp")[5], b"")
        zero_timestamp = hexbytes(by_name(cases, "zero_timestamp")["sign_bytes"])
        self.assertIn(b"\x2a\x00\x32\x30", zero_timestamp)

    def test_vote_encoder_preserves_present_zero_hashes(self):
        import generate

        original = by_name(V["votes"]["cases"], "precommit_a")
        for block_hash in (uint(0), "0x", "0x" + "aa" * 32):
            for parts_hash in (uint(0), "0x", "0x" + "ab" * 32):
                for total in ("1", "0"):
                    with self.subTest(block_hash=block_hash, parts_hash=parts_hash, total=total):
                        vote = {**original["vote"], "blockHash": block_hash,
                                "partsHash": parts_hash, "partsTotal": total}
                        encoded = generate.vote_sign_bytes(vote, original["chain_id"])
                        body = read_message(encoded[read_uvarint(encoded, 0)[1]:])
                        if block_hash == parts_hash == "0x" and total == "0":
                            self.assertNotIn(4, body)
                            continue
                        block_id = read_message(body[4])
                        psh = read_message(block_id[2])
                        self.assertEqual(block_id.get(1, b""), hexbytes(block_hash))
                        self.assertEqual(psh.get(2, b""), hexbytes(parts_hash))
                        self.assertEqual(psh.get(1, 0), int(total))

    def test_vote_timestamps_are_int64_in_cometbft_range(self):
        cases = V["votes"]["cases"]
        for case in cases:
            vote = case["vote"]
            seconds = int(vote["timestampSeconds"])
            self.assertTrue(MIN_VOTE_SECONDS <= seconds <= MAX_VOTE_SECONDS, case["name"])
            self.assertEqual(int(vote["timestampSecondsU64"]), seconds % 2**64, case["name"])
            self.assertTrue(0 <= int(vote["timestampNanos"]) < 10**9, case["name"])
        # Both ends of the range and a negative second occur; a negative second is a ten-byte
        # varint (protobuf int64), e.g. -1 is `ff ff ff ff ff ff ff ff ff 01`.
        self.assertLessEqual(
            {MIN_VOTE_SECONDS, -1, 0, MAX_VOTE_SECONDS},
            {int(c["vote"]["timestampSeconds"]) for c in cases},
        )

        def timestamp(name):
            sign_bytes = hexbytes(by_name(cases, name)["sign_bytes"])
            return read_message(sign_bytes[read_uvarint(sign_bytes, 0)[1] :])[5]

        expected = {
            "negative_timestamp": "08ffffffffffffffffff01107b",
            "min_timestamp": "088092b8c398feffffff01",
            "max_timestamp_seconds": "08ff82d1ffaf07",
            "precommit_a_backdated": "08ffffffffffffffffff01",
            "precommit_b_backdated": "08ffffffffffffffffff01",
        }
        for name, field in expected.items():
            self.assertEqual(timestamp(name), bytes.fromhex(field), name)
        # A backdated double sign is slashable evidence.
        backdated = by_name(V["votes"]["pairs"], "backdated_conflict")
        self.assertEqual(
            (backdated["a"], backdated["b"], backdated["double_sign"]),
            ("precommit_a_backdated", "precommit_b_backdated", True),
        )

    def test_vote_signatures_low_s_v01(self):
        cases = V["votes"]["cases"]
        for case in cases:
            sig = hexbytes(case["signature"])
            self.assertEqual(len(sig), 65, case["name"])
            r, s, v = sig_parts(sig)
            self.assertIn(v, (0, 1), case["name"])
            self.assertTrue(0 < r < SECP_N, case["name"])
            self.assertTrue(0 < s <= SECP_N // 2, case["name"])
        self.assertEqual(len({c["signature"] for c in cases}), len(cases))
        self.assertEqual({hexbytes(c["signature"])[64] for c in cases}, {0, 1})

    def test_slash_vote_abi_preserves_dynamic_hash_fields(self):
        abi = V["votes"]["slash_abi"]
        vote_type = "(uint8,uint64,uint32,bytes,uint32,bytes,uint64,uint32,uint48,bytes)"
        signature = "slashDoubleSign(uint256," + vote_type + "," + vote_type + ")"
        self.assertEqual(abi["signature"], signature)
        self.assertEqual(abi["selector"], "0x" + keccak256(signature.encode())[:4].hex())
        calldata = hexbytes(abi["calldata"])
        self.assertEqual(calldata[:4], hexbytes(abi["selector"]))
        arguments = calldata[4:]

        def integer(data, offset):
            return int.from_bytes(data[offset:offset + 32], "big")

        self.assertEqual(integer(arguments, 0), int(abi["bond_id"]))
        cursor = 96
        fields = ("voteType", "height", "round", "blockHash", "partsTotal", "partsHash",
                  "timestampSecondsU64", "timestampNanos", "generation", "signature")
        for index, label in enumerate(("a", "b"), start=1):
            self.assertEqual(integer(arguments, index * 32), cursor)
            case = by_name(V["votes"]["cases"], abi[label])
            values = {**case["vote"], "signature": case["signature"]}
            data, end = arguments[cursor:], 320
            for number, field in enumerate(fields):
                value = integer(data, number * 32)
                if field in ("blockHash", "partsHash", "signature"):
                    self.assertEqual(value, end)
                    length = integer(data, value)
                    actual = data[value + 32:value + 32 + length]
                    self.assertEqual(actual, hexbytes(values[field]))
                    padded = (length + 31) // 32 * 32
                    self.assertEqual(data[value + 32 + length:value + 32 + padded], bytes(padded - length))
                    end += 32 + padded
                else:
                    self.assertEqual(value, int(values[field]))
            cursor += end
        self.assertEqual(cursor, len(arguments))

    def test_pairs_cover_reasons(self):
        votes = V["votes"]
        cases = {c["name"]: c["vote"] for c in votes["cases"]}
        pairs = votes["pairs"]
        self.assertLessEqual(
            {
                "double_sign",
                "same_block_id",
                "different_round",
                "different_type",
                "different_height",
                "different_generation",
                "future_generation",
                "other_deployment",
            },
            {p["reason"] for p in pairs},
        )
        fields = {"voteType", "height", "round", "generation"}
        # The vote field each `different_*` reason isolates.
        differing = {
            "different_type": "voteType",
            "different_height": "height",
            "different_round": "round",
            "different_generation": "generation",
        }
        self.assertEqual(len({p["name"] for p in pairs}), len(pairs))
        for pair in pairs:
            self.assertEqual(
                list(pair), ["name", "a", "b", "double_sign", "reason", "current_generation"]
            )
            a, b, reason = cases[pair["a"]], cases[pair["b"]], pair["reason"]
            self.assertIs(pair["double_sign"], reason == "double_sign", pair["name"])
            current = int(pair["current_generation"])
            same = {k for k in fields if a[k] == b[k]}
            if reason in differing:
                self.assertEqual(same, fields - {differing[reason]}, pair["name"])
                # Neither vote's generation is in the future, so only the differing field fails.
                self.assertLessEqual(int(a["generation"]), current, pair["name"])
                self.assertLessEqual(int(b["generation"]), current, pair["name"])
                continue
            self.assertEqual(same, fields, pair["name"])
            self.assertIn(a["voteType"], ("1", "2"))
            if reason == "same_block_id":
                self.assertEqual(block_id_of(a), block_id_of(b), pair["name"])
                self.assertNotEqual(a, b, pair["name"])
                continue
            self.assertNotEqual(block_id_of(a), block_id_of(b), pair["name"])
            if reason == "future_generation":
                self.assertGreater(int(a["generation"]), current, pair["name"])
                continue
            self.assertLessEqual(int(a["generation"]), current, pair["name"])
            other = [n for n in (pair["a"], pair["b"]) if n.startswith("other_inbox")]
            self.assertEqual(len(other), 1 if reason == "other_deployment" else 0, pair["name"])
        # Each `different_*` reason other than type also occurs with conflicting block ids, so the
        # field check alone rejects it.
        for reason in ("different_height", "different_round", "different_generation"):
            self.assertTrue(
                any(
                    p["reason"] == reason
                    and block_id_of(cases[p["a"]]) != block_id_of(cases[p["b"]])
                    for p in pairs
                ),
                reason,
            )
        historical = [
            p
            for p in pairs
            if p["double_sign"] and int(cases[p["a"]]["generation"]) < int(p["current_generation"])
        ]
        self.assertTrue(historical)

    def test_extra_data_is_29_bytes_seat_0_is_the_low_bit_of_byte_28(self):
        cases = V["extra_data"]
        self.assertEqual(
            [tuple(int(c[k]) for k in ("generation", "anchor_number", "miss_bitmap"))
             for c in cases],
            [(0, 0, 0), (1, 258, 2**127 + 1), (U48_MAX, U48_MAX, 2**128 - 1), (5, 7, 1),
             (5, 7, 2**127)],
        )
        for case in cases:
            self.assertEqual(
                list(case),
                ["generation", "anchor_number", "miss_bitmap", "extra_data",
                 "on_block_start_calldata"],
            )
            data, bitmap = hexbytes(case["extra_data"]), int(case["miss_bitmap"])
            self.assertEqual(len(data), 29)
            self.assertEqual(data[0], 0x64)
            self.assertEqual(int.from_bytes(data[1:7], "big"), int(case["generation"]))
            self.assertEqual(int.from_bytes(data[7:13], "big"), int(case["anchor_number"]))
            self.assertEqual(int.from_bytes(data[13:29], "big"), bitmap)
            # Seat s is bit s of missBitmap: byte 28, the last, holds seats 0-7 with seat 0 its
            # low bit, and byte 13 seats 120-127 with seat 127 its high bit.
            for seat in range(128):
                self.assertEqual(
                    data[28 - seat // 8] >> (seat % 8) & 1, bitmap >> seat & 1, (bitmap, seat)
                )
        by_bitmap = {int(c["miss_bitmap"]): hexbytes(c["extra_data"]) for c in cases}
        self.assertEqual(by_bitmap[1][13:], bytes(15) + b"\x01")
        self.assertEqual(by_bitmap[2**127][13:], b"\x80" + bytes(15))
        self.assertEqual(cases[0]["extra_data"], "0x64" + "00" * 28)
        self.assertEqual(
            cases[1]["extra_data"],
            "0x64" + "000000000001" + "000000000102" + "80000000000000000000000000000001",
        )

    def test_on_block_start_calldata_is_68_bytes(self):
        signature = b"onBlockStart(uint48,uint128)"
        for impl in (keccak256_python, keccak256):
            self.assertEqual("0x" + impl(signature)[:4].hex(), ON_BLOCK_START_SELECTOR)
        for case in V["extra_data"]:
            # The selector, then the block's own generation and missBitmap as one standard ABI
            # word each; nothing follows.
            calldata = hexbytes(case["on_block_start_calldata"])
            self.assertEqual(len(calldata), 68)
            self.assertEqual(
                calldata,
                hexbytes(ON_BLOCK_START_SELECTOR)
                + hexbytes(uint(case["generation"]))
                + hexbytes(uint(case["miss_bitmap"])),
            )
        example = V["appendix_a_examples"]["enc_a_10d_a"]
        self.assertEqual(
            example["calldata"], ON_BLOCK_START_SELECTOR + "00" * 31 + "01" + "00" * 31 + "05"
        )
        self.assertEqual(V["governance_abi"]["on_block_start"]["calldata"], example["calldata"])

    def test_packed_words_decode_to_inputs(self):
        packing = V["layout"]["inbox"]["packing"]
        tables = {
            "inbox_272": packing["genesis_packed"],
            "inbox_280_word2": packing["forced_inclusion_entry_word2"],
            "inbox_281": packing["forced_inclusion_head_tail"],
            "inbox_282": packing["forced_inclusion_config"],
            "inbox_285_word1": packing["landing_word1"],
            "inbox_293": packing["rules_schedule"],
        }
        # Every packed Inbox field takes 48 bits, in the listed order from bit 0.
        lanes = {}
        for kind, fields in tables.items():
            lanes[kind] = [(name, int(lane["offset"]), int(lane["bits"]))
                           for name, lane in fields.items()]
            self.assertEqual(
                [(offset, bits) for _, offset, bits in lanes[kind]],
                [(48 * i, 48) for i in range(len(fields))],
                kind,
            )
        # The staking contract's key-to-seat value packs holdsSeat and seat, and a snapshot seat
        # record's second word ckPrefix and power, from bit 0: 8, 8, 8 and 64 bits.
        lanes["staking_key_seat"] = [("holds_seat", 0, 8), ("seat", 8, 8)]
        lanes["staking_record_word2"] = [("ck_prefix", 0, 8), ("power", 8, 64)]
        self.assertEqual(set(V["packed_words"]), set(lanes))
        # The all-max item holds each field's largest value: ckPrefix 3, holdsSeat 1, seat 127,
        # every other field all ones of its width.
        maxima = {"ck_prefix": 3, "holds_seat": 1, "seat": 127}
        for kind, items in V["packed_words"].items():
            width = sum(bits for _, _, bits in lanes[kind])
            self.assertGreaterEqual(len(items), 2, kind)
            saw_max = False
            for item in items:
                self.assertEqual(list(item), [name for name, _, _ in lanes[kind]] + ["word"], kind)
                value = int(item["word"], 16)
                self.assertEqual(len(hexbytes(item["word"])), 32)
                for name, offset, bits in lanes[kind]:
                    self.assertEqual(
                        value >> offset & ((1 << bits) - 1), int(item[name]), (kind, name)
                    )
                self.assertEqual(value >> width, 0, kind)
                saw_max |= all(
                    int(item[name]) == maxima.get(name, 2**bits - 1)
                    for name, _, bits in lanes[kind]
                )
            self.assertTrue(saw_max, kind)
        # Slot 272 packs genesisHeight and L1_0 only; slot 293 its four fields, so every bit from
        # 192 up is zero.
        self.assertEqual(list(tables["inbox_272"]), ["genesis_height", "l1_block"])
        self.assertEqual(
            list(tables["inbox_293"]), ["active_rules", "next_rules", "rules_time", "stop_time"]
        )
        for item in V["packed_words"]["inbox_293"]:
            self.assertEqual(int(item["word"], 16) >> 192, 0)
        # Seat 5 held, and the record word of prefix 0x02 at power 250,000.
        self.assertEqual(V["packed_words"]["staking_key_seat"][0]["word"], uint(0x0501))
        self.assertEqual(V["packed_words"]["staking_record_word2"][0]["word"], uint(0x3D09002))

    def test_origin_words_have_four_fields(self):
        origins = V["origin_words"]
        self.assertEqual([int(o["generation"]) for o in origins], [0, 1])
        fields = ("start_height", "l1_block_number", "l1_timestamp")
        for origin in origins:
            self.assertEqual(list(origin), ["generation", *fields, "fallback_keys_hash"])
            for name in fields:
                self.assertLessEqual(int(origin[name]), U48_MAX)
            self.assertEqual(len(hexbytes(origin["fallback_keys_hash"])), 32)
        self.assertTrue(any(all(int(o[n]) == U48_MAX for n in fields) for o in origins))
        # The fourth word is the fallback key hash slot 278 held when the record was written.
        self.assertEqual(
            [o["fallback_keys_hash"] for o in origins],
            [h256(fallback_keys_preimage([K1])), h256(fallback_keys_preimage([K1, K2]))],
        )
        # Each record is four consecutive words from its generation's mapping element.
        for item in V["layout"]["inbox"]["origin_slots"]:
            self.assertEqual(len(item["slots"]), 4)

    def test_inbox_layout_slots_and_anchor_order(self):
        inbox = V["layout"]["inbox"]
        self.assertEqual(inbox["initialized_status"], "3")
        slots = inbox["slots"]
        self.assertEqual(
            slots,
            {
                "initialization_status": "258",
                "recovery_generation": "268",
                "config_hash": "269",
                "last_checkpoint_height": "270",
                "last_checkpoint_hash": "271",
                "genesis_packed": "272",
                "genesis_block_hash": "273",
                "genesis_state_root": "274",
                "fallback_keys_hash": "278",
                "min_total_stake": "279",
                "forced_inclusion_queue": "280",
                "forced_inclusion_head_tail": "281",
                "forced_inclusion_config": "282",
                "landings": "285",
                "origins": "290",
                "recovery_nonce": "292",
                "rules_schedule": "293",
            },
        )
        self.assertEqual(
            inbox["reserved_slots"], ["283", "284", "286", "287", "288", "289", "291"]
        )
        # The anchor witness proves, in this order, the recovery generation, the checkpoint
        # height and hash, the fallback key hash, minTotalStake, the forced inclusion head and
        # tail, and the rules schedule; never the config hash or the recovery nonce.
        self.assertEqual(
            inbox["anchor_slots"], ["268", "270", "271", "278", "279", "281", "293"]
        )
        self.assertEqual(
            inbox["anchor_slots"],
            [
                slots[name]
                for name in (
                    "recovery_generation",
                    "last_checkpoint_height",
                    "last_checkpoint_hash",
                    "fallback_keys_hash",
                    "min_total_stake",
                    "forced_inclusion_head_tail",
                    "rules_schedule",
                )
            ],
        )
        self.assertNotIn(slots["config_hash"], inbox["anchor_slots"])
        self.assertNotIn(slots["recovery_nonce"], inbox["anchor_slots"])
        self.assertFalse(set(slots.values()) & set(inbox["reserved_slots"]))

    def test_layout_mapping_slots_are_consecutive(self):
        inbox = V["layout"]["inbox"]
        for key, field, count, ids in (
            ("forced_inclusion_entry_slots", "index", 2, ["0", "7"]),
            ("landing_slots", "height", 3, ["0", "6", "18"]),
            ("origin_slots", "generation", 4, ["0", "1"]),
        ):
            self.assertEqual([item[field] for item in inbox[key]], ids, key)
            for item in inbox[key]:
                slots = [int(s, 16) for s in item["slots"]]
                self.assertEqual(len(slots), count, key)
                self.assertEqual(slots, [slots[0] + w for w in range(count)], key)

    def test_fallback_keys_accept_reject_and_hash(self):
        family = V["fallback_keys"]
        self.assertEqual(list(family), ["tag", "accepted", "rejected"])
        self.assertEqual(family["tag"], "ETNA_FALLBACK_KEYS_V1")
        # K1, K2, K3 and K9 are the keys of private keys 1, 2, 3 and 9; by X alone K9 would
        # precede K3, as 33-byte values it follows it.
        self.assertEqual([scalar_key(k) for k in (1, 2, 3, 9)], [K1, K2, K3, K9])
        self.assertLess(int(K9["ck_x"], 16), int(K3["ck_x"], 16))
        self.assertLess(key_bytes(K3), key_bytes(K9))
        accepted = family["accepted"]
        self.assertEqual(
            [(c["name"], c["keys"]) for c in accepted],
            [
                ("one_key", [K1]),
                ("two_keys", [K1, K2]),
                ("prefix_then_x", [K3, K9]),
                ("max_keys", ascending_scalar_keys(128)),
            ],
        )
        topic0 = h256(b"FallbackKeysUpdated(bytes32,(uint8,bytes32)[])")
        self.assertEqual(topic0, SPEC_TOPICS["fallback_keys_updated"])
        for case in accepted:
            name, keys = case["name"], case["keys"]
            self.assertEqual(
                list(case), ["name", "keys", "preimage", "hash", "event", "validators"], name
            )
            self.assertEqual(fallback_list_failures(keys), [], name)
            # The tag and the offset, then the length and (ckPrefix, ckX) per key: 3 + 2n words.
            preimage = fallback_keys_preimage(keys)
            self.assertEqual(hexbytes(case["preimage"]), preimage, name)
            self.assertEqual(len(preimage), 32 * (3 + 2 * len(keys)), name)
            self.assertEqual(case["hash"], h256(preimage), name)
            # FallbackKeysUpdated: the hash is topic 1 and the data is the list alone (its offset,
            # its length and two words per key).
            event = case["event"]
            self.assertEqual(list(event), ["topic0", "topic1", "data"], name)
            self.assertEqual((event["topic0"], event["topic1"]), (topic0, case["hash"]), name)
            self.assertEqual(hexbytes(event["data"]), hexbytes(uint(32)) + preimage[64:], name)
            # The list signs as one validator per key, each at its secp256k1eth address with
            # power 1.
            self.assertEqual(
                case["validators"],
                [
                    {"ck_addr": "0x" + eth_address(decompress(key_bytes(key))), "power": "1"}
                    for key in keys
                ],
                name,
            )
        hashes = {c["name"]: c["hash"] for c in accepted}
        self.assertEqual(hashes["one_key"], APPENDIX_A_LITERALS["enc_a_36a_a"])
        self.assertEqual(hashes["two_keys"], APPENDIX_A_LITERALS["enc_a_36a_b"])
        self.assertEqual(hashes["prefix_then_x"], PREFIX_THEN_X_HASH)
        self.assertEqual(by_name(accepted, "one_key")["validators"][0]["ck_addr"], K1_ADDR)
        largest = by_name(accepted, "max_keys")
        self.assertEqual(len(hexbytes(largest["preimage"])), 8_288)
        self.assertEqual(len(words(largest["event"]["data"])), 258)

        # Each rejected list breaks exactly the condition it is labelled with: 1 to 128 entries,
        # strict ascending order of ckPrefix || ckX (a repeat is out of order), or a valid key.
        self.assertEqual(min(x for x in range(1, 10) if not has_point(x)), 5)
        expected = [
            ("empty", [], "count"),
            ("too_many", ascending_scalar_keys(129), "count"),
            ("descending", [K2, K1], "order"),
            ("duplicate", [K1, K1], "order"),
            ("x_alone", [K9, K3], "order"),
            ("prefix_04", [{"ck_prefix": "4", "ck_x": K1["ck_x"]}], "key"),
            ("x_not_below_p", [{"ck_prefix": "2", "ck_x": uint(SECP_P)}], "key"),
            ("off_curve", [{"ck_prefix": "2", "ck_x": uint(5)}], "key"),
        ]
        rejected = family["rejected"]
        self.assertEqual([(c["name"], c["keys"], c["reason"]) for c in rejected], expected)
        for case in rejected:
            self.assertEqual(list(case), ["name", "keys", "reason"], case["name"])
            self.assertEqual(fallback_list_failures(case["keys"]), [case["reason"]], case["name"])

    def test_staking_layout_slots_and_words(self):
        layout = V["staking_layout"]
        self.assertEqual(
            list(layout),
            [
                "namespace",
                "base",
                "snapshot_height_slot",
                "snapshot_total_stake_slot",
                "key_seat_slot",
                "record_slots",
                "key_seat_slots",
                "key_seat_words",
                "record_word2",
                "implementation_slot",
                "no_exit",
            ],
        )
        # T = keccak256(abi.encode(uint256(keccak256("taiko.etna.staking")) - 1)) & ~0xff.
        self.assertEqual(layout["namespace"], "taiko.etna.staking")
        for impl in (keccak256_python, keccak256):
            inner = int.from_bytes(impl(layout["namespace"].encode()), "big") - 1
            base = int.from_bytes(impl(inner.to_bytes(32, "big")), "big") & ~0xFF
            self.assertEqual(base, STAKING_BASE)
        base = STAKING_BASE
        # snapshotHeight at T, snapshotTotalStake at T + 1, the key-to-seat mapping at T + 2.
        self.assertEqual(
            [layout[k] for k in ("base", "snapshot_height_slot", "snapshot_total_stake_slot",
                                 "key_seat_slot")],
            [uint(base), uint(base), uint(base + 1), uint(base + 2)],
        )
        # Snapshot seat record s: ckX at T + 3 + 2s, the packed ckPrefix and power at T + 4 + 2s.
        records = layout["record_slots"]
        self.assertEqual([r["seat"] for r in records], ["0", "5", "127"])
        for record in records:
            seat = int(record["seat"])
            self.assertEqual(list(record), ["seat", "word1", "word2"])
            self.assertEqual(
                (record["word1"], record["word2"]),
                (uint(base + 3 + 2 * seat), uint(base + 4 + 2 * seat)),
            )
        self.assertEqual(records[-1]["word1"], STAKING_RECORD_127_WORD1)
        # A key's element is at keccak256(abi.encode(ckAddr, T + 2)): K1's, K2's and those of
        # keys a1-a4.
        slots = layout["key_seat_slots"]
        k2_addr = "0x" + eth_address(decompress(key_bytes(K2)))
        self.assertEqual(
            [item["ck_addr"] for item in slots],
            [K1_ADDR, k2_addr] + [key["ck_addr"] for key in V["keys"][:4]],
        )
        self.assertEqual(slots[0]["slot"], K1_KEY_SEAT_SLOT)
        for item in slots:
            self.assertEqual(list(item), ["ck_addr", "slot"])
            self.assertEqual(
                item["slot"], h256(hexbytes(address(item["ck_addr"])) + hexbytes(uint(base + 2)))
            )
        # A key-to-seat value gives seat s only for holdsSeat 1, seat s below 128 and nothing
        # from bit 16 up; 0x0500 is the value a released key must not keep.
        self.assertEqual(
            [(int(item["word"], 16), item["seat"]) for item in layout["key_seat_words"]],
            [
                (0x0501, "5"),
                (0x0001, "0"),
                (0x7F01, "127"),
                (0x0000, None),
                (0x0500, None),
                (0x0502, None),
                (0x8001, None),
                (0x10501, None),
            ],
        )
        for item in layout["key_seat_words"]:
            self.assertEqual(list(item), ["word", "seat"])
            self.assertEqual(len(hexbytes(item["word"])), 32)
            seat = seat_from_word(int(item["word"], 16))
            self.assertEqual(item["seat"], None if seat is None else str(seat))
        # Record word 2 packs ckPrefix in bits 0-7 and power in bits 8-71.
        self.assertEqual(
            [(item["ck_prefix"], item["power"], int(item["word"], 16))
             for item in layout["record_word2"]],
            [("2", "250000", 0x3D09002), ("3", str(U64_MAX), 0xFFFFFFFFFFFFFFFF03)],
        )
        for item in layout["record_word2"]:
            self.assertEqual(list(item), ["ck_prefix", "power", "word"])
            self.assertEqual(
                item["word"], uint(int(item["ck_prefix"]) | int(item["power"]) << 8)
            )
            self.assertEqual(int(item["word"], 16) >> 72, 0)
        # The proxy's EIP-1967 implementation slot, keccak256("eip1967.proxy.implementation") - 1,
        # and exitHeight's no-exit value.
        for impl in (keccak256_python, keccak256):
            digest = int.from_bytes(impl(b"eip1967.proxy.implementation"), "big")
            self.assertEqual(uint(digest - 1), IMPLEMENTATION_SLOT)
        self.assertEqual(layout["implementation_slot"], IMPLEMENTATION_SLOT)
        self.assertEqual(layout["no_exit"], str(U48_MAX))

    def test_miss_bitmap_cases(self):
        family = V["miss_bitmap"]
        self.assertEqual(list(family), ["cases"])
        expected = {
            "all_commit": 0,
            "absent_seat_5": 1 << 5,
            "nil_seat_0": 1 << 0,
            "seat_127": 1 << 127,
            "fallback_key_without_bond": 0,
            "fallback_key_with_seated_bond": 1 << 7,
            "vacated_in_parent": 0,
            "malformed_words": 0,
            "two_addresses_one_seat": 1 << 3,
            "seat_100": 1 << 100,
            "first_block": 0,
        }
        cases = family["cases"]
        self.assertEqual([c["name"] for c in cases], list(expected))
        for case in cases:
            name = case["name"]
            self.assertEqual(
                list(case), ["name", "first_block_of_generation", "validators", "miss_bitmap"]
            )
            self.assertEqual(case["first_block_of_generation"], name == "first_block", name)
            self.assertTrue(case["validators"], name)
            missing_seats = set()
            for validator in case["validators"]:
                self.assertEqual(list(validator), ["ck_addr", "block_id_flag", "key_seat_word"])
                self.assertEqual(len(hexbytes(validator["ck_addr"])), 20, name)
                self.assertEqual(len(hexbytes(validator["key_seat_word"])), 32, name)
                self.assertIn(validator["block_id_flag"], ("1", "2", "3"), name)
                # Missing is any flag other than commit: absent (1) or nil (3).
                if validator["block_id_flag"] != BLOCK_ID_FLAG_COMMIT:
                    missing_seats.add(seat_from_word(int(validator["key_seat_word"], 16)))
            missing_seats.discard(None)
            # The first block of a generation has no LastCommit: its bitmap is 0.
            bitmap = 0
            if not case["first_block_of_generation"]:
                bitmap = sum(1 << seat for seat in missing_seats)
            self.assertEqual(int(case["miss_bitmap"]), bitmap, name)
            self.assertEqual(bitmap, expected[name], name)

        def missing(name):
            return [
                (v["block_id_flag"], int(v["key_seat_word"], 16))
                for v in by_name(cases, name)["validators"]
                if v["block_id_flag"] != BLOCK_ID_FLAG_COMMIT
            ]

        self.assertEqual(missing("all_commit"), [])
        self.assertEqual(missing("absent_seat_5"), [("1", 0x0501)])
        self.assertEqual(missing("nil_seat_0"), [("3", 0x0001)])
        self.assertEqual(missing("seat_127"), [("1", 0x7F01)])
        self.assertEqual(missing("vacated_in_parent"), [("1", 0)])
        self.assertEqual(
            sorted(word for _, word in missing("malformed_words")), [0x0502, 0x8001, 0x10501]
        )
        self.assertEqual(missing("seat_100"), [("1", 0x6401)])
        # A seat two addresses map to is set when either is missing.
        pair = by_name(cases, "two_addresses_one_seat")["validators"]
        self.assertEqual(sorted(v["block_id_flag"] for v in pair), ["1", "2"])
        self.assertEqual({int(v["key_seat_word"], 16) for v in pair}, {0x0301})
        # While the fallback key set signs the parent, its keys are the validators: K1 and K2.
        fallback_addrs = [K1_ADDR, "0x" + eth_address(decompress(key_bytes(K2)))]
        for name, word_value in (("fallback_key_without_bond", 0),
                                 ("fallback_key_with_seated_bond", 0x0701)):
            case = by_name(cases, name)
            self.assertEqual([v["ck_addr"] for v in case["validators"]], fallback_addrs, name)
            self.assertEqual(missing(name), [("1", word_value)], name)
        # The first block's commit flags and seats would set a bit in any other block.
        self.assertTrue(any(seat_from_word(word) is not None for _, word in missing("first_block")))

    def test_candidate_cases(self):
        family = V["candidate"]
        self.assertEqual(list(family), ["cases"])
        expected = {
            "usable_three": None,
            "equal_threshold": None,
            "below_threshold": "below_min_total_stake",
            "threshold_max": "min_total_stake_max",
            "stale_height": "snapshot_height",
            "height_high_bits": "snapshot_height",
            "stray_bits": "stray_bits",
            "zero_prefix": "invalid_key",
            "zero_power": "zero_power",
            "off_curve_key": "invalid_key",
            "duplicate_key": "duplicate_key",
            "power_sum": "power_sum",
            "record_at_seat_100": None,
            "empty": "no_members",
        }
        cases = family["cases"]
        self.assertEqual([c["name"] for c in cases], list(expected))
        for case in cases:
            name = case["name"]
            self.assertEqual(
                list(case),
                ["name", "height", "snapshot_height_word", "snapshot_total_stake", "records",
                 "min_total_stake", "fallback_keys", "usable", "reason", "signers"],
                name,
            )
            self.assertEqual(len(hexbytes(case["snapshot_height_word"])), 32, name)
            # Only nonzero records are listed, in ascending seat order below 128.
            seats = [int(r["seat"]) for r in case["records"]]
            self.assertEqual(seats, sorted(set(seats)), name)
            self.assertTrue(all(seat < 128 for seat in seats), name)
            for record in case["records"]:
                self.assertEqual(list(record), ["seat", "word1", "word2"], name)
                self.assertEqual(len(hexbytes(record["word1"])), 32, name)
                self.assertEqual(len(hexbytes(record["word2"])), 32, name)
                self.assertTrue(int(record["word1"], 16) or int(record["word2"], 16), name)
            self.assertEqual(fallback_list_failures(case["fallback_keys"]), [], name)
            failures = candidate_failures(case)
            self.assertEqual(case["usable"], not failures, name)
            self.assertEqual(case["reason"], failures[0] if failures else None, name)
            self.assertEqual(case["reason"], expected[name], name)
            # Each unusable case breaks one condition only, except that a zero word 2 is both
            # ckPrefix 0 and power 0.
            self.assertEqual(len(failures), 2 if name == "zero_prefix" else int(bool(failures)))
            # A usable candidate signs with its members in seat order at their stored powers,
            # otherwise the fallback keys sign, each with power 1.
            if failures:
                signers = [signer(key_bytes(key), 1) for key in case["fallback_keys"]]
            else:
                signers = [signer(key, power) for key, power, _ in map(record_member,
                                                                       case["records"])]
            self.assertEqual(case["signers"], signers, name)

        c = {case["name"]: case for case in cases}
        height = int(c["usable_three"]["height"])
        self.assertTrue(all(int(case["height"]) == height for case in cases))

        def total_and_threshold(name):
            return int(c[name]["snapshot_total_stake"]), int(c[name]["min_total_stake"])

        total, threshold = total_and_threshold("equal_threshold")
        self.assertEqual(total, threshold)
        total, threshold = total_and_threshold("below_threshold")
        self.assertEqual(total, threshold - 1)
        self.assertEqual(total_and_threshold("threshold_max"), (U256_MAX, U256_MAX))
        self.assertEqual(int(c["stale_height"]["snapshot_height_word"], 16), height - 1)
        # The word at T with bit 48 set and its low 48 bits equal to H is not H.
        self.assertEqual(int(c["height_high_bits"]["snapshot_height_word"], 16), height | 1 << 48)

        def words2(name):
            return [int(r["word2"], 16) for r in c[name]["records"]]

        self.assertTrue(any(w >> 72 == 1 for w in words2("stray_bits")))
        self.assertIn(0, words2("zero_prefix"))
        self.assertIn(0x02, words2("zero_power"))
        self.assertIn(uint(5), [r["word1"] for r in c["off_curve_key"]["records"]])
        self.assertEqual(
            sum(power for _, power, _ in map(record_member, c["power_sum"]["records"])),
            MAX_POWER_SUM + 1,
        )
        self.assertIn("100", [r["seat"] for r in c["record_at_seat_100"]["records"]])
        self.assertEqual(c["empty"]["records"], [])

    def test_on_block_start_cases(self):
        family = V["on_block_start"]
        self.assertEqual(list(family), ["deployment", "cases"])
        fields = ("n_max", "min_stake", "vp_unit", "miss_limit", "miss_slash_bps")
        self.assertEqual(family["deployment"], {k: V["deployment"][k] for k in fields})
        base = {k: int(v) for k, v in family["deployment"].items()}
        m = base["min_stake"]
        # Per case: the miss counts of the seats held when the call starts (in seat order), the
        # seats of the records the call writes, the bonds it releases and the penalty it takes.
        pins = {
            "count_up": ([0, 0, 0, 3], [0, 1, 2, 3], [], 0),
            "count_reset": ([0, 0, 0, 0], [0, 1, 2, 3], [], 0),
            "empty_seat_bit": ([2], [0], [], 0),
            "zero_bitmap": ([0, 0, 0], [0, 1, 2], [], 0),
            "bitmap_4": ([0, 0, 1], [0, 1, 2], [], 0),
            "n_max_64_bit_100": ([1], [0], [], 0),
            "ceil_exact": ([0], [0], [], m),
            "ceil_round_up": ([0], [0], [], m + 1),
            "below_limit": ([9], [0], [], 0),
            "release_below_min": ([0, 0], [1], [0], m // 10),
            "miss_limit_1": ([0], [0], [], 2 * m // 10),
            "full_bps": ([0, 0], [1], [0], 3 * m),
            "three_seats": ([0] * 6, [0, 2, 5], [1, 3, 4], 3 * m // 10),
            "no_seats": ([], [], [], 0),
            "power_floor": ([0, 0, 0], [0, 1, 2], [], 0),
            "n_max_64_records": ([0] * 64, list(range(64)), [], 0),
        }
        cases = family["cases"]
        self.assertEqual([c["name"] for c in cases], list(pins))
        for case in cases:
            name = case["name"]
            self.assertEqual(list(case), ["name", "overrides", "setup", "call", "expect"], name)
            self.assertLessEqual(set(case["overrides"]), set(fields), name)
            params = {**base, **{k: int(v) for k, v in case["overrides"].items()}}
            # Every case deploys within the staking contract's bounds.
            self.assertTrue(1 <= params["n_max"] <= 128, name)
            self.assertGreaterEqual(params["vp_unit"], 867_361_738, name)
            self.assertGreaterEqual(params["min_stake"], params["vp_unit"], name)
            self.assertGreaterEqual(params["min_stake"] * params["n_max"], 10**27, name)
            self.assertTrue(1 <= params["miss_limit"] <= 65_535, name)
            self.assertTrue(0 < params["miss_slash_bps"] <= 10_000, name)
            setup, call = case["setup"], case["call"]
            self.assertEqual(list(setup), ["registrations", "prior_calls"], name)
            regs = setup["registrations"]
            self.assertEqual([r["bond_id"] for r in regs], [str(i) for i in range(len(regs))])
            for reg in regs:
                self.assertEqual(list(reg), ["bond_id", "private_key", "amount", "seat"], name)
                self.assertEqual(len(hexbytes(reg["private_key"])), 32, name)
            self.assertEqual(len({r["private_key"] for r in regs}), len(regs), name)
            for prior in setup["prior_calls"]:
                self.assertEqual(list(prior), ["generation", "miss_bitmap"], name)
            # The call's calldata is the selector and one word each for generation and missBitmap.
            self.assertEqual(
                list(call), ["block_number", "generation", "miss_bitmap", "calldata"], name
            )
            self.assertEqual(
                hexbytes(call["calldata"]),
                hexbytes(ON_BLOCK_START_SELECTOR) + hexbytes(uint(call["generation"]))
                + hexbytes(uint(call["miss_bitmap"])),
                name,
            )
            self.assertEqual(len(hexbytes(call["calldata"])), 68, name)
            seats, expect = replay_block_start(params, case)
            self.assertEqual([r["seat"] for r in regs], [str(s) for s in seats], name)
            self.assertEqual(list(case["expect"]), list(expect), name)
            self.assertEqual(case["expect"], expect, name)
            counts, record_seats, released, penalty = pins[name]
            got = case["expect"]
            self.assertEqual([int(c["count"]) for c in got["miss_counts"]], counts, name)
            self.assertEqual([int(r["seat"]) for r in got["records"]], record_seats, name)
            self.assertEqual([int(b) for b in got["released"]], released, name)
            self.assertEqual(int(got["penalty_total"]), penalty, name)

        c = {case["name"]: case for case in cases}

        def eff_stakes(name):
            return [int(e["eff_stake"]) for e in c[name]["expect"]["eff_stakes"]]

        # ceil(10m / 10) = m and ceil((10m + 1) / 10) = m + 1 both leave 9m.
        self.assertEqual(eff_stakes("ceil_exact"), [9 * m])
        self.assertEqual(eff_stakes("ceil_round_up"), [9 * m])
        self.assertEqual(c["ceil_round_up"]["setup"]["registrations"][0]["amount"], str(10 * m + 1))
        # A full-rate penalty takes the whole effStake.
        self.assertEqual(eff_stakes("full_bps")[0], 0)
        # With vp_unit = m, effStake 2.5m gives power 2.
        self.assertEqual(c["power_floor"]["overrides"], {"vp_unit": str(m)})
        self.assertEqual(
            [int(r["word2"], 16) >> 8 for r in c["power_floor"]["expect"]["records"]], [2, 1, 1]
        )
        self.assertEqual(eff_stakes("power_floor")[0], 5 * m // 2)
        # n_max 64 needs minStake of at least ceil(10^27 / 64) = 2m.
        for name in ("n_max_64_bit_100", "n_max_64_records"):
            self.assertEqual(c[name]["overrides"], {"n_max": "64", "min_stake": str(2 * m)}, name)
        self.assertEqual(int(c["n_max_64_bit_100"]["call"]["miss_bitmap"]) >> 100 & 1, 1)
        self.assertEqual(int(c["no_seats"]["call"]["miss_bitmap"]), 2**128 - 1)

    def test_keys_compress_to_33_bytes(self):
        keys = V["keys"]
        self.assertEqual(
            [k["name"] for k in keys], ["a1", "a2", "a3", "a4", "a5", "leading_zero_x"]
        )
        for i, key in enumerate(keys[:5]):
            self.assertEqual(int(key["private_key"], 16), 0xA1 + i)
        for key in keys:
            x, y = int(key["ck_x"], 16), int(key["ck_y"], 16)
            prefix = 2 + (y & 1)
            public_key = hexbytes(key["public_key"])
            self.assertEqual(int(key["ck_prefix"]), prefix)
            self.assertEqual(len(public_key), 33)
            self.assertEqual(public_key, bytes([prefix]) + hexbytes(key["ck_x"]))
            self.assertEqual(len(hexbytes(key["ck_x"])), 32)
            self.assertEqual(len(hexbytes(key["ck_y"])), 32)
            self.assertEqual(len(hexbytes(key["ck_addr"])), 20)
            self.assertNotIn("entry_key", key)
            self.assertEqual((y * y - x * x * x - 7) % SECP_P, 0)
        lead = keys[-1]
        self.assertEqual(hexbytes(lead["ck_x"])[0], 0)
        self.assertEqual(hexbytes(lead["public_key"])[1], 0)

    def test_decompression_accepts_both_prefixes_and_leading_zero_x(self):
        cases = V["key_decompression"]
        self.assertEqual(len({c["name"] for c in cases}), len(cases))
        valid = [c for c in cases if c["valid"]]
        self.assertEqual(len(valid), 2 * len(V["keys"]))
        for key in V["keys"]:
            x, y = key_point(key)
            own = by_name(cases, key["name"])
            self.assertTrue(own["valid"])
            self.assertEqual(own["public_key"], key["public_key"])
            self.assertEqual(own["ck_y"], key["ck_y"])
            self.assertEqual(own["ck_addr"], key["ck_addr"])
            # The other prefix with the same X decodes to the negated point, a different identity.
            flip = by_name(cases, "parity_flip_" + key["name"])
            self.assertTrue(flip["valid"])
            self.assertEqual(
                hexbytes(flip["public_key"]), bytes([(2 + (y & 1)) ^ 1]) + hexbytes(key["ck_x"])
            )
            self.assertEqual(flip["ck_y"], uint(SECP_P - y))
            self.assertNotEqual(flip["ck_addr"], key["ck_addr"])
        for case in valid:
            self.assertEqual(list(case), ["name", "public_key", "valid", "ck_y", "ck_addr"])
            public_key = hexbytes(case["public_key"])
            point = decompress(public_key)
            self.assertIsNotNone(point, case["name"])
            x, y = point
            self.assertEqual(case["ck_y"], uint(y), case["name"])
            self.assertEqual((y * y - x**3 - 7) % SECP_P, 0)
            self.assertEqual(y & 1, public_key[0] - 2)
            self.assertEqual(len(hexbytes(case["ck_y"])), 32)
            self.assertEqual(len(hexbytes(case["ck_addr"])), 20)
        self.assertEqual({hexbytes(c["public_key"])[0] for c in valid}, {2, 3})
        for name in ("leading_zero_x", "parity_flip_leading_zero_x"):
            public_key = hexbytes(by_name(cases, name)["public_key"])
            self.assertEqual(len(public_key), 33)
            self.assertEqual(public_key[1], 0)

    def test_decompression_reject_reasons_cover_spec(self):
        rejected = [c for c in V["key_decompression"] if not c["valid"]]
        reasons = {c["reason"] for c in rejected}
        self.assertLessEqual(
            {
                "x_ge_p",
                "not_on_curve",
                "bad_prefix",
                "uncompressed",
                "hybrid",
                "trailing_bytes",
                "short",
                "empty",
                "textual",
                "identity",
            },
            reasons,
        )
        by_reason = {reason: [] for reason in reasons}
        for case in rejected:
            self.assertEqual(list(case), ["name", "public_key", "valid", "reason"])
            public_key = hexbytes(case["public_key"])
            self.assertIsNone(decompress(public_key), case["name"])
            self.assertEqual(classify(public_key), case["reason"], case["name"])
            by_reason[case["reason"]].append(public_key)

        def x_of(public_key):
            return int.from_bytes(public_key[1:33], "big")

        # X is never reduced mod p: X = p, and 2^256 - 1 (which reduces onto the curve).
        self.assertEqual({x_of(k) for k in by_reason["x_ge_p"]}, {SECP_P, 2**256 - 1})
        self.assertTrue(has_point((2**256 - 1) % SECP_P))
        (off_curve,) = by_reason["not_on_curve"]
        self.assertFalse(has_point(x_of(off_curve)))
        self.assertTrue(all(has_point(x) for x in range(1, x_of(off_curve))))
        self.assertEqual(
            {(len(k), k[0]) for k in by_reason["bad_prefix"]}, {(33, 0), (33, 1), (33, 4)}
        )
        self.assertEqual({len(k) for k in by_reason["uncompressed"]}, {64, 65})
        self.assertEqual({(len(k), k[0]) for k in by_reason["hybrid"]}, {(65, 6), (65, 7)})
        for public_key in by_reason["uncompressed"] + by_reason["hybrid"]:
            xy = public_key[-64:]
            x, y = int.from_bytes(xy[:32], "big"), int.from_bytes(xy[32:], "big")
            self.assertEqual((y * y - x**3 - 7) % SECP_P, 0)
        self.assertEqual({len(k) for k in by_reason["trailing_bytes"]}, {34})
        self.assertEqual({len(k) for k in by_reason["short"]}, {32})
        self.assertEqual(by_reason["empty"], [b""])
        # The hex text of a registered key is rejected as text, never parsed into the key.
        keys = {hexbytes(k["public_key"]) for k in V["keys"]}
        (textual,) = by_reason["textual"]
        self.assertEqual(len(textual), 66)
        self.assertIn(bytes.fromhex(textual.decode("ascii")), keys)
        self.assertEqual(by_reason["identity"], [b"\x00"])

    def test_pop_signatures_are_65_bytes_low_s(self):
        cases = V["register_digests"]
        keys = {key["public_key"]: key for key in V["keys"]}
        self.assertEqual(
            sorted((c["key"], c["owner"]) for c in cases),
            sorted((k, owner) for k in keys for owner in OWNERS),
        )
        self.assertEqual(len({c["name"] for c in cases}), len(cases))
        self.assertEqual(len({c["domain_separator"] for c in cases}), 1)
        for owner in OWNERS:
            same_owner = [c for c in cases if c["owner"] == owner]
            self.assertEqual(len({(c["struct_hash"], c["digest"]) for c in same_owner}), 1)
        self.assertEqual(len({c["digest"] for c in cases}), len(OWNERS))
        for case in cases:
            self.assertEqual(
                list(case),
                [
                    "name",
                    "l2_chain_id",
                    "staking",
                    "owner",
                    "key",
                    "domain_separator",
                    "struct_hash",
                    "digest",
                    "pop_sig",
                ],
            )
            self.assertEqual(case["l2_chain_id"], V["deployment"]["l2_chain_id"])
            self.assertEqual(case["staking"], V["deployment"]["staking"])
            for field in ("domain_separator", "struct_hash", "digest"):
                self.assertEqual(len(hexbytes(case[field])), 32)
            r, s, v = sig_parts(hexbytes(case["pop_sig"]))
            self.assertIn(v, (0, 1))
            self.assertTrue(0 < r < SECP_N)
            self.assertTrue(0 < s <= SECP_N // 2)
            self.assertEqual(recover(case["digest"], r, s, v), key_point(keys[case["key"]]))
            self.assertTrue(pop_accepted(case["key"], case["digest"], case["pop_sig"]))

    def test_register_digests_use_the_l2_staking_domain(self):
        d = V["deployment"]
        domain_type = h256(
            b"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        )
        register_type = h256(b"Register(address owner)")

        def separator(chain_id, contract):
            return h256(
                join_words(
                    domain_type, h256(b"EtnaStaking"), h256(b"1"), uint(chain_id), address(contract)
                )
            )

        def digest(chain_id, contract, owner):
            struct_hash = h256(join_words(register_type, address(owner)))
            return h256(b"\x19\x01" + hexbytes(separator(chain_id, contract)) + hexbytes(struct_hash))

        # The EIP-712 domain is named "EtnaStaking", version "1", on the L2 chain id with the
        # staking proxy as verifying contract, recomputed here.
        for case in V["register_digests"]:
            self.assertEqual(case["domain_separator"], separator(d["l2_chain_id"], d["staking"]))
            self.assertEqual(
                case["struct_hash"], h256(join_words(register_type, address(case["owner"])))
            )
            self.assertEqual(case["digest"], digest(d["l2_chain_id"], d["staking"], case["owner"]))
        # The chain-bound rejection is the key's PoP for the L1 chain id, and the contract-bound
        # one for the Inbox as verifying contract: each recovers the key under its own domain.
        rejections = {c["name"]: c for c in V["pop_rejections"]}
        keys = {key["public_key"]: key for key in V["keys"]}
        for name, chain_id, contract in (
            ("wrong_chain", d["l1_chain_id"], d["staking"]),
            ("wrong_registry", d["l2_chain_id"], d["inbox"]),
        ):
            case = rejections[name]
            r, s, v = sig_parts(hexbytes(case["pop_sig"]))
            self.assertEqual(
                recover(digest(chain_id, contract, case["owner"]), r, s, v),
                key_point(keys[case["public_key"]]),
                name,
            )

    def test_pop_rejection_reasons(self):
        cases = V["pop_rejections"]
        self.assertLessEqual(
            {
                "v_27",
                "v_2",
                "high_s",
                "r_zero",
                "s_zero",
                "r_eq_n",
                "length_64",
                "length_66",
                "wrong_owner",
                "wrong_key",
                "wrong_chain",
                "wrong_registry",
            },
            {c["reason"] for c in cases},
        )
        self.assertEqual(len({c["name"] for c in cases}), len(cases))
        digests = {c["owner"]: c["digest"] for c in V["register_digests"]}
        valid = {(c["key"], c["owner"]): c["pop_sig"] for c in V["register_digests"]}
        keys = {key["public_key"]: key for key in V["keys"]}
        for case in cases:
            self.assertEqual(list(case), ["name", "public_key", "owner", "pop_sig", "reason"])
            self.assertIn(case["owner"], OWNERS)
            public_key, owner, reason = case["public_key"], case["owner"], case["reason"]
            digest = digests[owner]
            sig = hexbytes(case["pop_sig"])
            # Every case is rejected at the deployment's staking contract when submitted by
            # `owner`.
            self.assertFalse(pop_accepted(public_key, digest, case["pop_sig"]), case["name"])
            self.assertIsNotNone(decompress(hexbytes(public_key)), case["name"])
            if reason in ("length_64", "length_66"):
                full = hexbytes(valid[(public_key, owner)])
                self.assertEqual(len(sig), 64 if reason == "length_64" else 66)
                self.assertEqual(sig[:65], full[: len(sig)])
                continue
            r, s, v = sig_parts(sig)
            point = key_point(keys[public_key]) if public_key in keys else None
            if reason == "v_27":
                self.assertEqual(v, 27)
                self.assertEqual(recover(digest, r, s, v - 27), point)
            elif reason == "v_2":
                self.assertEqual(v, 2)
            elif reason == "high_s":
                # The malleated twin (n - s, V flipped) recovers the key; only low-s rejects it.
                self.assertTrue(SECP_N // 2 < s < SECP_N)
                self.assertEqual(recover(digest, r, s, v), point)
            elif reason == "r_zero":
                self.assertEqual(r, 0)
            elif reason == "s_zero":
                self.assertEqual(s, 0)
            elif reason == "r_eq_n":
                self.assertEqual(r, SECP_N)
            elif reason == "unrecoverable_r":
                self.assertTrue(0 < r < SECP_N and 0 < s <= SECP_N // 2 and v in (0, 1))
                self.assertIsNone(decompress(bytes([2 + v]) + r.to_bytes(32, "big")))
            else:
                # Well-formed signatures that are bound to another owner, key, chain or
                # verifying contract.
                self.assertTrue(0 < r < SECP_N and 0 < s <= SECP_N // 2 and v in (0, 1), reason)
                if reason == "wrong_owner":
                    (other,) = [o for o in OWNERS if o != owner]
                    self.assertEqual(case["pop_sig"], valid[(public_key, other)])
                elif reason == "wrong_key":
                    signers = [k for (k, o), sig_hex in valid.items() if sig_hex == case["pop_sig"]]
                    self.assertEqual(len(signers), 1)
                    self.assertNotEqual(signers[0], public_key)
                elif reason == "parity_flip":
                    original = "0x" + bytes([hexbytes(public_key)[0] ^ 1]).hex() + public_key[4:]
                    self.assertNotIn(public_key, keys)
                    self.assertEqual(case["pop_sig"], valid[(original, owner)])
                else:
                    self.assertIn(reason, ("wrong_chain", "wrong_registry"))
                    self.assertNotIn(case["pop_sig"], valid.values())
                    self.assertIn(public_key, keys)

    def test_appendix_a_literals(self):
        examples = V["appendix_a_examples"]
        for name, literal in APPENDIX_A_LITERALS.items():
            self.assertEqual(examples[name]["hash"], literal, name)
            self.assertEqual(h256(hexbytes(examples[name]["preimage"])), literal, name)
        # mixHash = keccak256(abi.encode(bytes32(p.difficulty), uint256(b.number))).
        mix = examples["enc_a_10b_a"]
        self.assertEqual(hexbytes(mix["preimage"]), join_words(uint(1_000_000), uint(12_345)))
        # extraData: all zero after the 0x64 byte, and generation 1, anchor number 258 and
        # missBitmap 2^127 + 1; both are rows of `extra_data`.
        rows = {
            tuple(int(c[k]) for k in ("generation", "anchor_number", "miss_bitmap")): c
            for c in V["extra_data"]
        }
        for name, inputs, extra_data in (
            ("enc_a_10_f", (0, 0, 0), "0x64" + "00" * 28),
            (
                "enc_a_10_h",
                (1, 258, 2**127 + 1),
                "0x64" + "000000000001" + "000000000102" + "80000000000000000000000000000001",
            ),
        ):
            example = examples[name]
            self.assertEqual(
                tuple(int(example[k]) for k in ("generation", "anchor_number", "miss_bitmap")),
                inputs,
                name,
            )
            self.assertEqual(example["extra_data"], extra_data, name)
            self.assertEqual(rows[inputs]["extra_data"], extra_data, name)
        # The missBitmap bit order: 5 sets seats 0 and 2 in the last byte; 2^127 sets seat 127,
        # the high bit of byte 13.
        five, top = examples["enc_a_10c_a"], examples["enc_a_10c_b"]
        self.assertEqual(
            (five["miss_bitmap"], five["seats"], five["extra_data_byte_28"]), ("5", ["0", "2"], "0x05")
        )
        self.assertEqual(hexbytes(five["extra_data"])[28], 0x05)
        self.assertEqual(
            (top["miss_bitmap"], top["seats"], top["extra_data_byte_13"]),
            (str(2**127), ["127"], "0x80"),
        )
        self.assertEqual(hexbytes(top["extra_data"])[13], 0x80)
        self.assertEqual(top["extra_data"], rows[(5, 7, 2**127)]["extra_data"])
        # The block-start call for generation 1 and missBitmap 5, and its selector.
        self.assertEqual(
            examples["enc_a_10d_a"]["calldata"],
            ON_BLOCK_START_SELECTOR + uint(1)[2:] + uint(5)[2:],
        )
        self.assertEqual(
            (examples["enc_a_10d_b"]["signature"], examples["enc_a_10d_b"]["selector"]),
            ("onBlockStart(uint48,uint128)", ON_BLOCK_START_SELECTOR),
        )
        # The config hash example is four words, 128 bytes; with the tag as a dynamic string it
        # is six words, 192 bytes, and a different hash.
        spec = examples["enc_a_36_a"]
        staking = "0x" + "11" * 20
        self.assertEqual(
            spec["inputs"],
            {"tag": "ETNA_CONFIG_V1", "l2_chain_id": "167000", "staking": staking,
             "unsettled_limit": "151200"},
        )
        self.assertEqual(spec["preimage_bytes"], "128")
        dynamic = examples["enc_a_36_f"]
        self.assertTrue(dynamic["reject"])
        self.assertEqual(dynamic["preimage_bytes"], "192")
        self.assertEqual(
            hexbytes(dynamic["preimage"]),
            join_words(uint(128), uint(167_000), address(staking), uint(151_200), uint(14),
                       tag("ETNA_CONFIG_V1")),
        )
        # The fallback key hashes of [K1] (160 bytes) and [K1, K2] (224 bytes), encoded here;
        # [K1] with the tag as a dynamic string is 224 bytes and rejected.
        one, two = examples["enc_a_36a_a"], examples["enc_a_36a_b"]
        for example, keys, size in ((one, [K1], 160), (two, [K1, K2], 224)):
            self.assertEqual(example["keys"], keys)
            self.assertEqual(hexbytes(example["preimage"]), fallback_keys_preimage(keys))
            self.assertEqual(example["preimage_bytes"], str(size))
            self.assertEqual(len(fallback_keys_preimage(keys)), size)
        dynamic_keys = examples["enc_a_36a_g"]
        self.assertTrue(dynamic_keys["reject"])
        self.assertEqual(dynamic_keys["keys"], [K1])
        self.assertEqual(dynamic_keys["preimage_bytes"], "224")
        self.assertEqual(
            hexbytes(dynamic_keys["preimage"]),
            join_words(uint(64), uint(128), uint(21), tag("ETNA_FALLBACK_KEYS_V1"), uint(1),
                       uint(2), K1["ck_x"]),
        )
        self.assertEqual(h256(hexbytes(dynamic_keys["preimage"])), dynamic_keys["hash"])
        self.assertNotEqual(dynamic_keys["hash"], one["hash"])
        # 45.g: seconds = -1 is ten varint bytes; the timestamp field is 2a 0b and those bytes.
        ts = examples["enc_a_45_g"]
        self.assertEqual(ts["seconds_field"], "0x08" + "ff" * 9 + "01")
        self.assertEqual(ts["timestamp_field"], "0x2a0b08" + "ff" * 9 + "01")
        (vote,) = [c for c in V["votes"]["cases"] if c["name"] == ts["vote"]]
        self.assertEqual((vote["vote"]["timestampSeconds"], vote["vote"]["timestampNanos"]),
                         ("-1", "0"))
        self.assertIn(ts["timestamp_field"][2:], vote["sign_bytes"])

    def test_appendix_a_validator_set_arithmetic(self):
        examples = V["appendix_a_examples"]
        address = {k["name"]: k["ck_addr"][2:] for k in V["val_state_chains"]["keys"]}

        def priorities(rows):
            return [int(row[2]) for row in rows]

        # 29a.n, from A.md: equal power 1 for addresses A < B, priorities (-3, 2), one increment:
        # spread 5 exceeds 4, rescale toward zero to (-1, 1), centre to (-1, 1); B wins and the
        # final priorities are (0, 0).
        n = examples["enc_a_29a_n"]
        a, b = (row[0] for row in n["members"])
        self.assertLess(address[a], address[b])
        self.assertEqual([(int(r[1]), int(r[2])) for r in n["members"]], [(1, -3), (1, 2)])
        self.assertEqual((int(n["spread"]), int(n["diff_max"])), (5, 4))
        self.assertEqual([int(p) for p in n["rescaled"]], [-1, 1])
        self.assertEqual([int(p) for p in n["centred"]], [-1, 1])
        self.assertEqual(n["final"][int(n["proposer"])][0], b)
        self.assertEqual(priorities(n["final"]), [0, 0])
        # 29a.o: the same members with priorities (-1, 0), no update, below the rescale
        # threshold: the average floors to -1, centred (0, 1), B wins and the final priorities
        # are (1, 0).
        o = examples["enc_a_29a_o"]
        self.assertEqual([row[0] for row in o["members"]], [a, b])
        self.assertEqual([(int(r[1]), int(r[2])) for r in o["members"]], [(1, -1), (1, 0)])
        self.assertNotIn("changes", o)
        self.assertLess(int(o["spread"]), int(o["diff_max"]))
        self.assertEqual([int(p) for p in o["rescaled"]], [-1, 0])
        self.assertEqual(int(o["centre_shift"]), -1)
        self.assertEqual([int(p) for p in o["centred"]], [0, 1])
        self.assertEqual(o["final"][int(o["proposer"])][0], b)
        self.assertEqual(priorities(o["final"]), [1, 0])
        # 29a.p: an update adds a member and removes another; the power after additions and
        # reweights but before removals is 17, so the new member starts at -19 before rescaling
        # and centring.
        p = examples["enc_a_29a_p"]
        old = {row[0]: (int(row[1]), int(row[2])) for row in p["members"]}
        changes = {key: int(power) for key, power in p["changes"]}
        (joining,) = [k for k, power in changes.items() if power > 0 and k not in old]
        (leaving,) = [k for k, power in changes.items() if power == 0]
        total = sum(w for w, _ in old.values()) + sum(
            power - old.get(k, (0, 0))[0] for k, power in changes.items() if power > 0
        )
        self.assertEqual((total, int(p["total_before_removals"])), (17, 17))
        self.assertEqual(-(total + (total >> 3)), -19)
        self.assertEqual(int(p["new_member_priority"]), -19)
        updated = {row[0]: int(row[2]) for row in p["updated"]}
        self.assertIn(joining, updated)
        self.assertNotIn(leaving, updated)
        # Kept members keep their priorities; the spread stays within 2 * total, so only the
        # centring by floor(sum / n) moves them.
        before = {k: old[k][1] for k in updated if k in old} | {joining: -19}
        new_total = sum(int(row[1]) for row in p["updated"])
        self.assertLessEqual(max(before.values()) - min(before.values()), 2 * new_total)
        shift = sum(before.values()) // len(before)
        self.assertEqual(updated, {k: v - shift for k, v in before.items()})
        # Every case replays with valset_model.py.
        for name in ("enc_a_29a_n", "enc_a_29a_o", "enc_a_29a_p"):
            case = examples[name]
            model = valset_model.Model(address)
            valset = valset_model.ValSet(
                [valset_model.Member(k, int(w), int(pr)) for k, w, pr in case["members"]], None
            )
            if "changes" in case:
                model._update(valset, [(k, int(w)) for k, w in case["changes"]])
                self.assertEqual(valset.entries(), as_entries(case["updated"]), name)
            self.assertEqual(valset.total(), int(case["total_power"]), name)
            model._increment(valset)
            self.assertEqual(valset.entries(), as_entries(case["final"]), name)
            self.assertEqual(valset.proposer_index(), int(case["proposer"]), name)

    def test_appendix_a_blobs(self):
        examples = V["appendix_a_examples"]
        # 23b.a and 23c.a, copied from A.md: blob bytes up to the last nonzero one.
        literals = {
            "enc_a_23b_a": "0x3f0000001c" + "ff" * 27 + "30",
            "enc_a_23c_a": "0x0000000001ff",
        }
        for name, prefix in literals.items():
            example = examples[name]
            data = hexbytes(example["data"])
            blob = blob_encode(data)
            self.assertEqual(example["blob_prefix"], prefix, name)
            self.assertEqual(blob, hexbytes(prefix).ljust(131_072, b"\0"), name)
            self.assertEqual(h256(blob), example["blob_hash"], name)
            self.assertEqual(blob_decode(blob), data, name)
        self.assertEqual(hexbytes(examples["enc_a_23b_a"]["data"]), b"\xff" * 28)
        # 23c.b: 130,044 bytes of 0xff fill the stream; the length bytes are 01 fb fc.
        full = examples["enc_a_23c_b"]
        self.assertEqual((full["length_bytes"], full["data_length"]), ("0x01fbfc", "130044"))
        data = hexbytes(full["data_byte"]) * int(full["data_length"])
        blob = blob_encode(data)
        self.assertEqual(blob[:5], hexbytes(full["blob_head"]))
        self.assertEqual(blob[1:5], b"\x00\x01\xfb\xfc")
        self.assertEqual(h256(blob), full["blob_hash"])
        self.assertEqual(blob_decode(blob), data)
        # 23d.f: a set top bit in the first header byte does not decode.
        flipped = examples["enc_a_23d_f"]
        self.assertFalse(flipped["decodes"])
        self.assertEqual(flipped["blob_prefix"], "0x4000000001ff")
        self.assertIsNone(blob_decode(hexbytes(flipped["blob_prefix"]).ljust(131_072, b"\0")))

    def test_dynamic_tag_rejects(self):
        cases = V["appendix_a_examples"]["dynamic_tag_rejects"]
        self.assertEqual(
            [c["tag"] for c in cases],
            [
                "ETNA_COMET_DOMAIN_V1",
                "ETNA_CONFIG_V1",
                "ETNA_FALLBACK_KEYS_V1",
                "ETNA_VAL_STATE_V1",
                "ETNA_APP_HASH_V1",
                "ETNA_LAND_CUTS_V1",
                "TAIKO_ETNA_LAND_V1",
            ],
        )
        for case in cases:
            dynamic = hexbytes(case["preimage"])
            self.assertEqual(h256(dynamic), case["hash"], case["name"])
            self.assertNotEqual(case["hash"], case["accepted_hash"], case["name"])
            # The first word is the string's offset; the string is its length and padded ASCII.
            offset = int.from_bytes(dynamic[:32], "big")
            self.assertEqual(
                dynamic[offset : offset + 64],
                join_words(uint(len(case["tag"])), tag(case["tag"])),
                case["name"],
            )
        by_tag = {c["tag"]: c for c in cases}
        self.assertEqual(by_tag["ETNA_CONFIG_V1"]["accepted_hash"], V["config"]["hash"])
        keys, example = by_tag["ETNA_FALLBACK_KEYS_V1"], V["appendix_a_examples"]["enc_a_36a_g"]
        self.assertEqual(keys["accepted_hash"], APPENDIX_A_LITERALS["enc_a_36a_a"])
        self.assertEqual((keys["preimage"], keys["hash"]), (example["preimage"], example["hash"]))

    def test_land_abi_has_seven_fields(self):
        abi = V["land_abi"]
        signature = (
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256),bytes32[],bytes)"
        )
        self.assertEqual(abi["signature"], signature)
        self.assertEqual(abi["selector"], "0x5185fd7a")
        self.assertEqual(abi["selector"], h256(signature.encode())[:10])
        self.assertEqual(abi["statement"], "nonzero")
        inputs = by_name(V["land_statements"], "nonzero")["inputs"]
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        # One leaf per height strictly between p = 6 and h = 18.
        leaves = abi["leaves"]
        self.assertEqual(leaves, [table[x] for x in range(7, 18)])
        self.assertEqual(abi["proof"], "0x00")
        calldata = hexbytes(abi["calldata"])
        self.assertEqual(calldata[:4], hexbytes(abi["selector"]))
        # The seven LandInput fields inline, the offsets of the leaves and the proof, then the
        # leaves and the one-byte proof, padded.
        self.assertEqual(
            words("0x" + calldata[4:].hex()),
            [
                uint(inputs["parent_height"]),
                uint(inputs["last_height"]),
                inputs["last_block_hash"],
                inputs["last_comet_hash"],
                inputs["last_state_root"],
                uint(inputs["l1_reference_block_number"]),
                uint(inputs["forced_inclusion_head_after"]),
                uint(9 * 32),
                uint(9 * 32 + 32 * (1 + len(leaves))),
                uint(len(leaves)),
                *leaves,
                uint(1),
                uint(0),
            ],
        )

    def test_fi_named_cases(self):
        fi = V["fi_eligibility"]
        self.assertEqual(list(fi), ["l2_chain_id", "l2_block_gas_limit", "cases"])
        self.assertEqual(fi["l2_chain_id"], V["deployment"]["l2_chain_id"])
        self.assertEqual(fi["l2_block_gas_limit"], V["deployment"]["l2_block_gas_limit"])
        self.assertEqual((fi["l2_chain_id"], fi["l2_block_gas_limit"]), ("167001", "45000000"))
        cases = fi["cases"]
        self.assertEqual([(c["name"], c["rule"]) for c in cases], FI_CASES)
        for case in cases:
            self.assertEqual(list(case), ["name", "raw", "eligible", "rule"], case["name"])
            self.assertIs(case["eligible"], case["rule"] == "eligible", case["name"])
            hexbytes(case["raw"])
        self.assertEqual(len({c["raw"] for c in cases}), len(cases))

    def test_fi_cases_cover_every_static_rule(self):
        self.assertEqual({c["rule"] for c in V["fi_eligibility"]["cases"]}, FI_RULES)

    def test_fi_eligible_types(self):
        types = set()
        for case in V["fi_eligibility"]["cases"]:
            if case["eligible"]:
                first = hexbytes(case["raw"])[0]
                self.assertTrue(first >= 0xC0 or first in (0x01, 0x02, 0x04), case["name"])
                types.add("legacy" if first >= 0xC0 else first)
        self.assertEqual(types, {"legacy", 0x01, 0x02, 0x04})

    def test_fi_cases_break_only_their_rule(self):
        fi = V["fi_eligibility"]
        chain_id, gas_limit = int(fi["l2_chain_id"]), int(fi["l2_block_gas_limit"])
        cases = {c["name"]: c for c in fi["cases"]}
        decoded = {}
        for name, case in cases.items():
            raw = hexbytes(case["raw"])
            if case["rule"] == "noncanonical":
                with self.assertRaises(AssertionError, msg=name):
                    decode_fi(raw)
                continue
            tx_type, fields = decode_fi(raw)
            decoded[name] = (tx_type, fields)
            expected = set() if case["rule"] == "eligible" else {case["rule"]}
            # Any gas of 2^64 or more is also above the block gas limit.
            if name == "gas_2_64":
                expected.add("gas_limit")
            failures = fi_static_failures(tx_type, fields, chain_id, gas_limit)
            self.assertEqual(failures, expected, name)

        # name: (type, field, value) pinned by the case; None skips that check.
        pinned = {
            "legacy_eip155_35": (0, "v", 2 * chain_id + 35),
            "legacy_eip155_36": (0, "v", 2 * chain_id + 36),
            "legacy_pre155_27": (0, "v", 27),
            "legacy_pre155_28": (0, "v", 28),
            "eip2930": (1, None, None),
            "eip1559": (2, None, None),
            "eip1559_zero_fee": (2, "max_fee", 0),
            "eip7702": (4, None, None),
            "eip7702_invalid_auth_signature": (4, None, None),
            "eip7702_empty_auth_list": (4, "authorization_list", []),
            "gas_at_limit": (None, "gas", gas_limit),
            "nonce_max": (None, "nonce", 2**64 - 1),
            "fee_max": (None, "max_fee", 2**128 - 1),
            "value_max": (None, "value", 2**256 - 1),
            "eip7702_foreign_tuple_chain_id": (4, None, None),
            "eip7702_tuple_y_parity_255": (4, None, None),
            "eip7702_tuple_chain_id_zero": (4, None, None),
            "legacy_contract_creation": (0, "to", b""),
            "eip1559_contract_creation": (2, "to", b""),
            "s_half_n": (2, "s", SECP_N // 2),
            "eip7702_tuple_nonce_max": (4, None, None),
            "eip7702_tuple_high_s": (4, None, None),
            "eip1559_tip_above_max_fee": (2, "max_priority_fee", 3 * 10**9),
            "type3_blob": (3, None, None),
            "unknown_type_05": (0x05, None, None),
            "unknown_type_7f": (0x7F, None, None),
            "legacy_v_37": (0, "v", 37),
            "typed_wrong_chain_id": (None, None, None),
            "y_parity_2": (None, "y_parity", 2),
            "r_zero": (None, "r", 0),
            "s_zero": (None, "s", 0),
            "r_eq_n": (None, "r", SECP_N),
            "high_s": (None, None, None),
            "unrecoverable_r": (None, None, None),
            "s_half_n_plus_1": (2, "s", SECP_N // 2 + 1),
            "nonce_2_64": (None, "nonce", 2**64),
            "gas_2_64": (None, "gas", 2**64),
            "fee_2_128": (None, "max_fee", 2**128),
            "tip_2_128": (2, "max_priority_fee", 2**128),
            "legacy_gas_price_2_128": (0, "gas_price", 2**128),
            "eip2930_gas_price_2_128": (1, "gas_price", 2**128),
            "eip7702_fee_2_128": (4, "max_fee", 2**128),
            "value_33_bytes": (None, "value", 2**256),
            "eip7702_tuple_nonce_2_64": (4, None, None),
            "eip7702_tuple_y_parity_256": (4, None, None),
            "eip7702_tuple_address_19_bytes": (4, None, None),
            "eip7702_tuple_r_33_bytes": (4, None, None),
            "gas_above_limit": (None, "gas", gas_limit + 1),
        }
        self.assertEqual(set(pinned), set(decoded))
        for name, (tx_type, field, value) in pinned.items():
            if tx_type is not None:
                self.assertEqual(decoded[name][0], tx_type, name)
            if field is not None:
                self.assertEqual(decoded[name][1][field], value, name)
        self.assertNotEqual(decoded["typed_wrong_chain_id"][1]["chain_id"], chain_id)
        # Eligibility ignores fees: a tip above the fee cap (both within width) is eligible.
        tip_above = decoded["eip1559_tip_above_max_fee"][1]
        self.assertGreater(tip_above["max_priority_fee"], tip_above["max_fee"])
        self.assertLess(tip_above["max_priority_fee"], 2**128)
        self.assertTrue(SECP_N // 2 < decoded["high_s"][1]["s"] < SECP_N)
        self.assertFalse(has_point(decoded["unrecoverable_r"][1]["r"]))
        self.assertTrue(decoded["eip2930"][1]["access_list"])
        # Authorization tuples need only EIP-7702 field widths: a zero tuple r stays eligible.
        (valid,) = decoded["eip7702"][1]["authorization_list"]
        self.assertEqual(valid["chain_id"], chain_id)
        self.assertTrue(0 < valid["r"] < SECP_N and 0 < valid["s"] <= SECP_N // 2)
        (invalid,) = decoded["eip7702_invalid_auth_signature"][1]["authorization_list"]
        self.assertEqual(invalid["r"], 0)
        # Each tuple case changes one tuple field of an otherwise ordinary type-4 transaction.
        tuple_fields = {
            "eip7702_foreign_tuple_chain_id": ("chain_id", 1),
            "eip7702_tuple_y_parity_255": ("y_parity", 255),
            "eip7702_tuple_chain_id_zero": ("chain_id", 0),
            "eip7702_tuple_nonce_2_64": ("nonce", 2**64),
            "eip7702_tuple_y_parity_256": ("y_parity", 256),
            "eip7702_tuple_nonce_max": ("nonce", 2**64 - 1),
        }
        for name, (field, value) in tuple_fields.items():
            (auth,) = decoded[name][1]["authorization_list"]
            self.assertEqual(auth[field], value, name)
        (short,) = decoded["eip7702_tuple_address_19_bytes"][1]["authorization_list"]
        self.assertEqual(len(short["address"]), 19)
        (high_s,) = decoded["eip7702_tuple_high_s"][1]["authorization_list"]
        self.assertTrue(SECP_N // 2 < high_s["s"] < SECP_N)
        (wide_r,) = decoded["eip7702_tuple_r_33_bytes"][1]["authorization_list"]
        self.assertEqual(len(wide_r["r"].to_bytes(33, "big").lstrip(b"\0")), 33)
        # Contract creations carry an EIP-155 v for the L2 chain (legacy) or the L2 chain id.
        creation_v = decoded["legacy_contract_creation"][1]["v"]
        self.assertIn(creation_v, (2 * chain_id + 35, 2 * chain_id + 36))
        # The s = n/2 boundary pair: one transaction with (r, n/2, 0) and its high-s twin.
        low, high = decoded["s_half_n"][1], decoded["s_half_n_plus_1"][1]
        self.assertEqual((low["y_parity"], high["y_parity"]), (0, 1))
        self.assertEqual(SECP_N - high["s"], low["s"])
        self.assertEqual(
            {k: v for k, v in low.items() if k not in ("s", "y_parity")},
            {k: v for k, v in high.items() if k not in ("s", "y_parity")},
        )

        # Fixed-width fields that RLP round-trips but a typed decoder rejects.
        def body(name):
            raw = hexbytes(cases[name]["raw"])
            return rlp_item(raw, 0 if raw[0] >= 0xC0 else 1)[0]

        self.assertEqual(len(body("legacy_to_19_bytes")[3]), 19)
        self.assertEqual(len(body("eip1559_to_19_bytes")[5]), 19)
        self.assertEqual(len(body("eip2930_access_list_address_19_bytes")[7][0][0]), 19)
        self.assertEqual(len(body("eip1559_storage_key_31_bytes")[8][0][1][0]), 31)
        self.assertEqual(len(body("eip7702_tuple_5_fields")[9][0]), 5)
        self.assertEqual(len(body("eip7702_tuple_7_fields")[9][0]), 7)

        # The framing cases wrap otherwise canonical transactions.
        trailing = hexbytes(cases["trailing_byte"]["raw"])
        self.assertEqual(trailing[-1:], b"\x00")
        decode_fi(trailing[:-1])
        both = hexbytes(cases["two_transactions"]["raw"])
        _, end = rlp_item(both, 1)
        decode_fi(both[:end])
        decode_fi(both[end:])
        empty_to = hexbytes(cases["eip7702_empty_to"]["raw"])
        self.assertEqual(empty_to[0], 0x04)
        self.assertEqual(rlp_item(empty_to, 1)[0][5], b"")
        self.assertEqual(hexbytes(cases["empty"]["raw"]), b"")


if __name__ == "__main__":
    unittest.main()
