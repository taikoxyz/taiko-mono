"""Field-level and frozen-literal checks for ENC-A-43 through ENC-A-45."""

from dataclasses import FrozenInstanceError, replace
from importlib import import_module
import json
from pathlib import Path
import sys
import unittest


ETNA = Path(__file__).resolve().parents[1]


class VoteWireTests(unittest.TestCase):
    def setUp(self):
        root = str(ETNA.parents[1])
        sys.path.insert(0, root)
        self.addCleanup(sys.path.remove, root)
        self.wire = import_module("formal.etna.draft_rules.vote_wire")
        self.corpus = json.loads((ETNA / "draft_rules/vote_wire_vectors.json").read_bytes())
        self.chain = self.corpus["chainId"]
        self.epoch = self.wire.VoteFields(2, 1, 0, b"", 0, b"", 0, 0)

    def encode(self, fields):
        return self.wire.vote_sign_bytes(fields, self.chain)

    def test_nil_epoch_literal(self):
        # Body length 63, precommit, sfixed64 height 1, empty timestamp, 48-byte domain.
        expected = bytes.fromhex("3f08021101000000000000002a003230") + self.chain.encode("ascii")
        self.assertEqual(self.encode(self.epoch), expected)

    def test_all_frozen_literals_and_lengths(self):
        vectors = self.corpus["vectors"]
        self.assertEqual(len({row["id"] for row in vectors}), 29)
        self.assertEqual(len(vectors), 29)
        for row in vectors:
            with self.subTest(vector=row["id"]):
                data = row["input"]
                fields = self.wire.VoteFields(
                    data["type"], int(data["height"]), data["round"], bytes.fromhex(data["hashHex"]),
                    data["total"], bytes.fromhex(data["partsHashHex"]), int(data["seconds"]), data["nanos"],
                )
                actual = self.encode(fields)
                self.assertIs(type(actual), bytes)
                self.assertEqual(actual, bytes.fromhex(row["wireHex"]))
                self.assertEqual(len(actual), row["wireBytes"])
                prefix_width = 1 if row["bodyBytes"] < 128 else 2
                self.assertEqual(len(actual) - prefix_width, row["bodyBytes"])

    def test_signed_enum_and_round(self):
        fields = replace(self.epoch, vote_type=-1, height=0, round=-2)
        expected_body = (b"\x08" + b"\xff" * 9 + b"\x01"
                         + b"\x19\xfe" + b"\xff" * 7
                         + b"\x2a\x00\x32\x30" + self.chain.encode("ascii"))
        self.assertEqual(self.encode(fields), bytes([len(expected_body)]) + expected_body)

    def test_integer_widths_and_exact_types(self):
        ranges = {"vote_type": (32, True), "height": (64, True), "round": (32, True),
                  "parts_total": (32, False), "seconds": (64, True), "nanos": (32, True)}
        for field, (width, signed) in ranges.items():
            minimum = -(1 << (width - 1)) if signed else 0
            maximum = (1 << (width - int(signed))) - 1
            for invalid in (minimum - 1, maximum + 1, True, 1.0, "0", None):
                with self.subTest(field=field, value=invalid), self.assertRaises(ValueError):
                    self.encode(replace(self.epoch, **{field: invalid}))

    def test_hash_shape_and_mutability(self):
        for field in ("block_hash", "parts_hash"):
            for invalid in (bytes(1), bytes(31), bytes(33), bytearray(32), memoryview(bytes(32)), "", None):
                with self.subTest(field=field, value=invalid), self.assertRaises(ValueError):
                    self.encode(replace(self.epoch, **{field: invalid}))
        with self.assertRaises(FrozenInstanceError):
            self.epoch.seconds = 1

    def test_domain_shape_and_field_container(self):
        for chain in ("", self.chain[:-1], self.chain + "A", "xxxx-" + self.chain[5:],
                      self.chain[:-1] + "=", self.chain[:-1] + "é", self.chain.encode(), None):
            with self.subTest(chain=chain), self.assertRaises(ValueError):
                self.wire.vote_sign_bytes(self.epoch, chain)
        for fields in (None, {}, tuple(vars(self.epoch).values())):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                self.encode(fields)
