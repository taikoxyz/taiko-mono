#!/usr/bin/env python3
"""Structural checks of vectors.json against the Etna spec's appendix A (encodings) and B (storage).

Run from the repository root (standard library only; no `cast`, `go` or network):

    python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v

`generate.py` computes every hash and slot with `cast`. These tests decode the generated preimages
and words and check what can be checked without keccak: word order and count, field widths and
packing offsets, the 48-byte chain id, key compression and decompression, signature recovery to the
registered point, and the shape of each case.
"""

import base64
import json
import pathlib
import unittest

V = json.loads((pathlib.Path(__file__).resolve().parent / "vectors.json").read_text())

K = 6
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


def classify(public_key):
    """The reason a public key input is rejected, from its shape alone (None if it decodes)."""
    if not public_key:
        return "empty"
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
]
VOTE_FIELDS = [
    "voteType",
    "height",
    "round",
    "blockHash",
    "partsTotal",
    "partsHash",
    "timestampSeconds",
    "timestampNanos",
    "generation",
]
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
    # A present block id is never all zero; a nil vote omits it.
    assert 4 not in cv or block_id.get(1) or psh, cv[4]
    vote = {
        "voteType": cv.get(1, 0),
        "height": cv.get(2, 0),
        "round": cv.get(3, 0),
        "blockHash": "0x" + block_id.get(1, bytes(32)).hex(),
        "partsTotal": psh.get(1, 0),
        "partsHash": "0x" + psh.get(2, bytes(32)).hex(),
        "timestampSeconds": timestamp.get(1, 0),
        "timestampNanos": timestamp.get(2, 0),
    }
    return {k: v if isinstance(v, str) else str(v) for k, v in vote.items()}, cv[6].decode("ascii")


def block_id_of(vote):
    return vote["blockHash"], vote["partsTotal"], vote["partsHash"]


class VectorsTest(unittest.TestCase):
    def test_schema_version_is_4(self):
        self.assertEqual(V["schema_version"], "4")

    def test_deployment(self):
        self.assertEqual(
            V["deployment"],
            {
                "l1_chain_id": "1",
                "l2_chain_id": "167001",
                "inbox": "0x1111111111111111111111111111111111111111",
                "registry": "0x2222222222222222222222222222222222222222",
                "l2_block_gas_limit": "45000000",
            },
        )

    def test_config_is_seven_words(self):
        cfg = V["committee_config"]
        inputs = cfg["inputs"]
        self.assertEqual(len(hexbytes(cfg["preimage"])), 224)
        self.assertEqual(inputs["tag"], "ETNA_PARENT_ANCHOR_V1")
        self.assertEqual(inputs["unsettled_limit"], "3600")
        self.assertEqual(inputs["registry"], V["deployment"]["registry"])
        self.assertEqual(
            words(cfg["preimage"]),
            [
                tag("ETNA_PARENT_ANCHOR_V1"),
                uint(inputs["l2_chain_id"]),
                address(inputs["registry"]),
                uint(inputs["vp_unit"]),
                uint(inputs["s_min"]),
                uint(inputs["n_max"]),
                uint(inputs["unsettled_limit"]),
            ],
        )

    def test_statements_are_21_words(self):
        statements = V["land_statements"]
        self.assertEqual([s["name"] for s in statements], ["genesis", "nonzero"])
        for statement in statements:
            inputs = statement["inputs"]
            p, h = int(inputs["parent_height"]), int(inputs["last_height"])
            self.assertEqual(len(hexbytes(statement["preimage"])), 672)
            self.assertEqual(p % K, 0)
            self.assertEqual(h % K, 0)
            self.assertEqual(word(statement["preimage"], 0), tag("TAIKO_ETNA_LAND_V1"))
            self.assertEqual(word(statement["preimage"], 20), inputs["cut_hash"])
            self.assertEqual(inputs["committee_config_hash"], V["committee_config"]["hash"])
            cut = [
                c
                for c in V["cuts"]["cut_hashes"]
                if (int(c["generation"]), int(c["parent_height"]), int(c["last_height"]))
                == (int(inputs["generation"]), p, h)
            ]
            self.assertEqual(len(cut), 1)
            self.assertEqual(inputs["cut_hash"], cut[0]["cut_hash"])
            self.assertEqual(
                words(statement["preimage"]),
                [
                    tag(inputs["tag"]),
                    uint(inputs["l1_chain_id"]),
                    uint(inputs["l2_chain_id"]),
                    address(inputs["inbox"]),
                    address(inputs["registry"]),
                    uint(inputs["generation"]),
                    uint(p),
                    inputs["parent_hash"],
                    inputs["parent_comet_hash"],
                    inputs["committee_config_hash"],
                    uint(h),
                    inputs["last_block_hash"],
                    inputs["last_comet_hash"],
                    inputs["last_state_root"],
                    uint(inputs["l1_reference_block_number"]),
                    inputs["l1_reference_block_hash"],
                    statement["blob_hashes_hash"],
                    uint(inputs["forced_inclusion_head_before"]),
                    uint(inputs["forced_inclusion_head_after"]),
                    uint(inputs["active_committee_snapshot"]),
                    inputs["cut_hash"],
                ],
            )
            for blob in inputs["blob_hashes"]:
                self.assertEqual(len(hexbytes(blob)), 32)
                self.assertEqual(hexbytes(blob)[0], 0x01)

    def test_cut_leaves_are_four_words(self):
        table = V["cuts"]["table"]
        self.assertEqual([int(c["height"]) for c in table], list(range(19)))
        for cut in table:
            x = int(cut["height"])
            self.assertEqual(len(hexbytes(cut["preimage"])), 128)
            self.assertEqual(int(cut["forced_head"]), x // K)
            self.assertEqual(cut["block_hash"], uint(100 + x))
            self.assertEqual(cut["comet_hash"], uint(0 if x == 0 else 200 + x))
            self.assertEqual(
                words(cut["preimage"]),
                [uint(x), cut["block_hash"], cut["comet_hash"], uint(cut["forced_head"])],
            )

    def test_empty_cut_list_hashes_empty_string(self):
        empty = [
            c
            for c in V["cuts"]["cut_hashes"]
            if int(c["last_height"]) == int(c["parent_height"]) + K
        ]
        self.assertTrue(empty)
        for case in empty:
            self.assertEqual(case["leaves"], [])
            self.assertEqual(case["leaves_hash"], KECCAK_EMPTY)

    def test_cut_hash_leaf_count(self):
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        cases = V["cuts"]["cut_hashes"]
        self.assertEqual(
            [(int(c["generation"]), int(c["parent_height"]), int(c["last_height"])) for c in cases],
            [(0, 0, 6), (0, 0, 12), (0, 0, 18), (1, 6, 18), (0, 0, 300)],
        )
        for case in cases:
            p, h = int(case["parent_height"]), int(case["last_height"])
            self.assertEqual(len(case["leaves"]), (h - p) // K - 1)
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
            for index, leaf in enumerate(case["leaves"]):
                height = p + K * (index + 1)
                if height in table:
                    self.assertEqual(leaf, table[height])
        self.assertEqual(len(cases[-1]["leaves"]), 49)

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
        self.assertEqual(list(votes), ["key", "chain_ids", "cases", "pairs"])
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
        nil = (uint(0), "0", uint(0))
        # name: (type, round, block id, generation); height 1000, timestamp (1700000000, 123).
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
            "partial_block_id": ("2", "0", (uint(0), "1", "0x" + "ab" * 32), "0"),
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
            timestamp = ("1700000001", "0") if name == "precommit_a_late" else ("1700000000", "123")
            self.assertEqual(
                vote,
                dict(
                    zip(
                        VOTE_FIELDS,
                        (vote_type, "1000", round_, *block_id, *timestamp, generation),
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
                "future_generation",
                "other_deployment",
            },
            {p["reason"] for p in pairs},
        )
        self.assertEqual(len({p["name"] for p in pairs}), len(pairs))
        for pair in pairs:
            self.assertEqual(
                list(pair), ["name", "a", "b", "double_sign", "reason", "current_generation"]
            )
            a, b, reason = cases[pair["a"]], cases[pair["b"]], pair["reason"]
            self.assertIs(pair["double_sign"], reason == "double_sign", pair["name"])
            current = int(pair["current_generation"])
            same = {k for k in ("voteType", "height", "round", "generation") if a[k] == b[k]}
            if reason == "different_type":
                self.assertEqual(same, {"height", "round", "generation"}, pair["name"])
                continue
            if reason == "different_round":
                self.assertEqual(same, {"voteType", "height", "generation"}, pair["name"])
                continue
            self.assertEqual(same, {"voteType", "height", "round", "generation"}, pair["name"])
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
        historical = [
            p
            for p in pairs
            if p["double_sign"] and int(cases[p["a"]]["generation"]) < int(p["current_generation"])
        ]
        self.assertTrue(historical)

    def test_extra_data_is_13_bytes(self):
        cases = V["extra_data"]
        self.assertEqual(
            [(int(c["generation"]), int(c["anchor_number"])) for c in cases],
            [(0, 0), (5, 7), (U48_MAX, U48_MAX)],
        )
        for case in cases:
            data = hexbytes(case["extra_data"])
            self.assertEqual(len(data), 13)
            self.assertEqual(data[0], 0x64)
            self.assertEqual(int.from_bytes(data[1:7], "big"), int(case["generation"]))
            self.assertEqual(int.from_bytes(data[7:13], "big"), int(case["anchor_number"]))
        self.assertEqual(cases[1]["extra_data"], "0x64000000000005000000000007")

    def test_packed_words_decode_to_inputs(self):
        packing = {
            "inbox_272": V["layout"]["inbox"]["packing"]["genesis_packed"],
            "inbox_280_word2": V["layout"]["inbox"]["packing"]["forced_inclusion_entry_word2"],
            "inbox_281": V["layout"]["inbox"]["packing"]["forced_inclusion_head_tail"],
            "inbox_282": V["layout"]["inbox"]["packing"]["forced_inclusion_config"],
            "inbox_285_word1": V["layout"]["inbox"]["packing"]["landing_word1"],
            "registry_checkpoint_word1": V["layout"]["registry"]["packing"]["checkpoint_word1"],
            "registry_entry_word3": V["layout"]["registry"]["packing"]["entry_word3"],
        }
        self.assertEqual(set(V["packed_words"]), set(packing))
        for kind, items in V["packed_words"].items():
            fields = packing[kind]
            # Fields sit in the listed order from bit 0: ckPrefix 8 bits, everything else 48.
            offset = 0
            for name, lane in fields.items():
                self.assertEqual(int(lane["offset"]), offset, (kind, name))
                self.assertEqual(int(lane["bits"]), 8 if name == "ck_prefix" else 48, (kind, name))
                offset += int(lane["bits"])
            self.assertGreaterEqual(len(items), 2, kind)
            saw_max = False
            for item in items:
                self.assertEqual(list(item), [*fields, "word"], kind)
                value = int(item["word"], 16)
                self.assertEqual(len(hexbytes(item["word"])), 32)
                for name, lane in fields.items():
                    bits = int(lane["bits"])
                    lane_value = (value >> int(lane["offset"])) & ((1 << bits) - 1)
                    self.assertEqual(lane_value, int(item[name]), (kind, name))
                self.assertEqual(value >> offset, 0, kind)
                saw_max |= all(
                    int(item[name]) == (3 if name == "ck_prefix" else U48_MAX) for name in fields
                )
            self.assertTrue(saw_max, kind)

    def test_origin_words_are_three_full_words(self):
        origins = V["origin_words"]
        self.assertEqual([int(o["generation"]) for o in origins], [0, 1])
        for origin in origins:
            self.assertEqual(
                list(origin), ["generation", "start_height", "l1_block_number", "l1_timestamp"]
            )
            for name in ("start_height", "l1_block_number", "l1_timestamp"):
                self.assertLessEqual(int(origin[name]), U48_MAX)
        fields = ("start_height", "l1_block_number", "l1_timestamp")
        self.assertTrue(any(all(int(o[n]) == U48_MAX for n in fields) for o in origins))

    def test_layout_anchor_and_reserved_slots(self):
        inbox = V["layout"]["inbox"]
        self.assertEqual(inbox["anchor_slots"], ["268", "270", "271", "281"])
        self.assertEqual(inbox["reserved_slots"], ["283", "286", "287", "288", "289", "291"])
        self.assertEqual(inbox["initialized_status"], "3")
        self.assertEqual(
            inbox["slots"],
            {
                "initialization_status": "258",
                "recovery_generation": "268",
                "committee_config_hash": "269",
                "last_checkpoint_height": "270",
                "last_checkpoint_hash": "271",
                "genesis_packed": "272",
                "genesis_block_hash": "273",
                "genesis_state_root": "274",
                "genesis_committee_record_hash": "278",
                "genesis_cutoff": "279",
                "forced_inclusion_queue": "280",
                "forced_inclusion_head_tail": "281",
                "forced_inclusion_config": "282",
                "active_committee_snapshot": "284",
                "landings": "285",
                "origins": "290",
            },
        )
        used = set(inbox["slots"].values())
        self.assertFalse(used & set(inbox["reserved_slots"]))

    def test_layout_mapping_slots_are_consecutive(self):
        inbox = V["layout"]["inbox"]
        for key, field, count, ids in (
            ("forced_inclusion_entry_slots", "index", 2, ["0", "7"]),
            ("landing_slots", "height", 3, ["0", "6", "18"]),
            ("origin_slots", "generation", 3, ["0", "1"]),
        ):
            self.assertEqual([item[field] for item in inbox[key]], ids, key)
            for item in inbox[key]:
                slots = [int(s, 16) for s in item["slots"]]
                self.assertEqual(len(slots), count, key)
                self.assertEqual(slots, [slots[0] + w for w in range(count)], key)

    def test_registry_entries_have_three_words(self):
        registry = V["layout"]["registry"]
        base = int(registry["base"], 16)
        self.assertEqual(registry["namespace"], "taiko.etna.registry")
        self.assertEqual(registry["no_exit"], str(U48_MAX))
        self.assertEqual(int(registry["checkpoints_slot"], 16), base)
        self.assertEqual(int(registry["entries_slot"], 16), base + 1)
        self.assertEqual(base & 0xFF, 0)  # ERC-7201 clears the low byte

        entries = registry["entry_slots"]
        self.assertEqual([e["index"] for e in entries], ["0", "1", "4095"])
        entry_data = int(entries[0]["slots"][0], 16)
        for entry in entries:
            slots = [int(s, 16) for s in entry["slots"]]
            self.assertEqual(slots, [entry_data + 3 * int(entry["index"]) + w for w in range(3)])

        checkpoints = registry["checkpoint_slots"]
        self.assertEqual([c["index"] for c in checkpoints], ["0", "1", "5"])
        checkpoint_data = int(checkpoints[0]["slots"][0], 16)
        for checkpoint in checkpoints:
            slots = [int(s, 16) for s in checkpoint["slots"]]
            self.assertEqual(
                slots, [checkpoint_data + 2 * int(checkpoint["index"]) + w for w in range(2)]
            )

        snapshots = registry["snapshot_slots"]
        self.assertEqual(
            [(s["index"], s["has_next"]) for s in snapshots],
            [("0", False), ("0", True), ("3", True)],
        )
        for snapshot in snapshots:
            cp = checkpoint_data + 2 * int(snapshot["index"])
            expected = [base, cp, cp + 1] + ([cp + 2] if snapshot["has_next"] else [])
            self.assertEqual([int(s, 16) for s in snapshot["slots"]], expected)

        for key, namespace in (
            ("owners", "taiko.etna.registry.owners"),
            ("exit_confirmations", "taiko.etna.registry.exit-confirmations"),
        ):
            self.assertEqual(registry[key]["namespace"], namespace)
            self.assertEqual(int(registry[key]["base"], 16) & 0xFF, 0)
            self.assertEqual([s["bond_id"] for s in registry[key]["slots"]], ["0", "4095"])

    def test_registry_entries_match_keys(self):
        reg = V["registry_entries"]
        self.assertEqual(len(reg["entries"]), 5)
        self.assertEqual(len(reg["leaves"]), 5)
        for i, (entry, key) in enumerate(zip(reg["entries"], V["keys"])):
            self.assertEqual(entry["ck_prefix"], key["ck_prefix"])
            self.assertEqual(entry["ck_x"], key["ck_x"])
            self.assertEqual(int(entry["eff_stake"]), (i + 1) * 10**18)
            self.assertEqual(int(entry["active_from_l1"]), 10 + i)
            self.assertEqual(int(entry["exit_effective_l1"]), 1000 + i if i % 2 else U48_MAX)
        roots = reg["roots"]
        self.assertEqual([int(r["count"]) for r in roots], list(range(7)))
        self.assertEqual(roots[0]["entries_root"], uint(0))
        self.assertEqual(roots[1]["entries_root"], reg["leaves"][0])

    def test_released_leaf_uses_zero_fields(self):
        released = V["registry_entries"]["released"]
        self.assertEqual(released["index"], "5")
        self.assertEqual(len(hexbytes(released["leaf"])), 32)
        self.assertNotEqual(released["leaf"], uint(0))
        self.assertNotIn(released["leaf"], V["registry_entries"]["leaves"])

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
            self.assertEqual(len(hexbytes(key["entry_key"])), 32)
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
                    "l1_chain_id",
                    "registry",
                    "owner",
                    "key",
                    "domain_separator",
                    "struct_hash",
                    "digest",
                    "pop_sig",
                ],
            )
            self.assertEqual(case["l1_chain_id"], V["deployment"]["l1_chain_id"])
            self.assertEqual(case["registry"], V["deployment"]["registry"])
            for field in ("domain_separator", "struct_hash", "digest"):
                self.assertEqual(len(hexbytes(case[field])), 32)
            r, s, v = sig_parts(hexbytes(case["pop_sig"]))
            self.assertIn(v, (0, 1))
            self.assertTrue(0 < r < SECP_N)
            self.assertTrue(0 < s <= SECP_N // 2)
            self.assertEqual(recover(case["digest"], r, s, v), key_point(keys[case["key"]]))
            self.assertTrue(pop_accepted(case["key"], case["digest"], case["pop_sig"]))

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
            # Every case is rejected at the deployment registry when submitted by `owner`.
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
                # Well-formed signatures that are bound to another owner, key, chain or registry.
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

    def test_committee_sets_match_appendix_a(self):
        cases = V["committee_sets"]
        self.assertEqual([len(c["members"]) for c in cases], [0, 1, 3, 5])
        # Spec 4.3 step 4: an empty committee is rejected, so it has no root or record.
        self.assertEqual(cases[0], {"members": [], "valid": False, "reason": "empty_committee"})
        vp_unit = int(V["committee_config"]["inputs"]["vp_unit"])
        for case in cases[1:]:
            self.assertTrue(case["valid"])
            k = int(case["target_epoch"]) + 1
            self.assertEqual(int(case["set_version"]), k)
            members = case["members"]
            set_keys = [int(m["set_key"], 16) for m in members]
            self.assertEqual(set_keys, sorted(set_keys))
            for i, member in enumerate(members):
                self.assertEqual(int(member["power"]), int(member["eff_stake"]) // vp_unit)
                self.assertEqual(
                    words(case["set_leaf_preimages"][i]),
                    [
                        tag("ETNA_SET_LEAF_V1"),
                        uint(case["l2_chain_id"]),
                        uint(k),
                        uint(i),
                        uint(member["ck_prefix"]),
                        member["ck_x"],
                        uint(member["eff_stake"]),
                        uint(member["power"]),
                    ],
                )
            self.assertEqual(len(case["set_leaves"]), len(members))
            self.assertEqual(int(case["total_power"]), sum(int(m["power"]) for m in members))
            if len(members) == 1:
                self.assertEqual(case["set_root"], case["set_leaves"][0])
            self.assertEqual(
                words(case["record_preimage"]),
                [
                    tag("ETNA_COMMITTEE_V1"),
                    uint(case["l2_chain_id"]),
                    uint(case["target_epoch"]),
                    uint(case["cutoff_l1_block"]),
                    uint(case["checkpoint_index"]),
                    case["set_root"],
                    uint(case["total_power"]),
                ],
            )

    def test_land_abi_encodes_the_nonzero_statement(self):
        abi = V["land_abi"]
        self.assertEqual(
            abi["signature"],
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256),bytes32[],bytes)",
        )
        self.assertEqual(abi["statement"], "nonzero")
        inputs = by_name(V["land_statements"], "nonzero")["inputs"]
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        self.assertEqual(abi["leaves"], [table[12]])
        self.assertEqual(abi["proof"], "0x00")
        calldata = hexbytes(abi["calldata"])
        self.assertEqual(calldata[:4], hexbytes(abi["selector"]))
        self.assertEqual(
            ["0x" + calldata[4 + 32 * i : 36 + 32 * i].hex() for i in range(8)],
            [
                uint(inputs["parent_height"]),
                uint(inputs["last_height"]),
                inputs["last_block_hash"],
                inputs["last_comet_hash"],
                inputs["last_state_root"],
                uint(inputs["l1_reference_block_number"]),
                uint(inputs["forced_inclusion_head_after"]),
                uint(inputs["active_committee_snapshot"]),
            ],
        )


if __name__ == "__main__":
    unittest.main()
