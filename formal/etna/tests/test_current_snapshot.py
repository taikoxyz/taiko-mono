"""Canonical f556 Registry witnesses and config-bound direct selection."""

from dataclasses import replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]
EMPTY = (0, 0, 0, 0, 0)
ZERO_ROOT = bytes(32)
NO_EXIT = 2**48 - 1

# Small occupancy horizon. These typed rows stand for occupied slots, including
# one with zero effective stake. They are never used as an admission committee.
ROW_0 = (2, 1, 9, 1, 5)
ROW_1 = (3, 2, 7, 2, 6)
ROW_2 = (2, 3, 0, 3, 4)
REPLACEMENT = (3, 4, 8, 7, NO_EXIT)

# Direct byte vectors use public compressed keys and deployment-compatible units.
KEY_A = (2, 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798)
KEY_B = (2, 0xC6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5)
KEY_C = (2, 0xF9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9)
Q = 10**23
CHAIN_ID = 167001
REGISTRY = 0x1234567890ABCDEF1234567890ABCDEF12345678
CONFIG_HASH = bytes.fromhex("17082c8ce3618dd5df8dbf182fbfb58696cf2d370f1be25a49bb2e16f6759891")
CONFIG_PREIMAGE = bytes.fromhex(
    "45544e415f504152454e545f414e43484f525f56310000000000000000000000"
    "0000000000000000000000000000000000000000000000000000000000028c59"
    "0000000000000000000000001234567890abcdef1234567890abcdef12345678"
    "000000000000000000000000000000000000000000002a5a058fc295ed000000"
    "0000000000000000000000000000000000000000000054b40b1f852bda000000"
    "0000000000000000000000000000000000000000000000000000000000000002"
    "0000000000000000000000000000000000000000000000000000000000000e10"
)
PUBLIC_ROOT = bytes.fromhex("3e6a2ebd4dfba7d0249ce4f92d31ae5ed92525cf05abee6b37a2bf7272ea9913")


def entry(key, stake=4 * Q, active=7, exit_at=NO_EXIT):
    return (*key, stake, active, exit_at)


def abi(tag, *values):
    return tag + bytes(32 - len(tag)) + b"".join(bytes.fromhex(f"{value:064x}") for value in values)


class CurrentSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/snapshot.py").is_file(),
            "Z04 snapshot model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        before_import = sys.path.copy()
        self.model = import_module("formal.etna.current_rules.snapshot")
        self.assertEqual(sys.path, before_import)
        self.keccak = import_module("formal.etna.conformance.run_comet_apphash").keccak256
        self.config = self.model.Config(CHAIN_ID, REGISTRY, 2 * Q, 4 * Q, 2, 3600)

    def leaf(self, position, row):
        return self.keccak(abi(b"ETNA_REG_ENTRY_V1", position, *row))

    def witness_root(self, rows):
        if not rows:
            return ZERO_ROOT
        width = 1 << (len(rows) - 1).bit_length()
        leaves = tuple(self.leaf(i, row) for i, row in enumerate(rows))

        def fold(nodes):
            if len(nodes) == 1:
                return nodes[0]
            halfway = len(nodes) // 2
            return self.keccak(fold(nodes[:halfway]) + fold(nodes[halfway:]))

        return fold(leaves + (ZERO_ROOT,) * (width - len(rows)))

    def expected_config_hash(self, config):
        return self.keccak(abi(
            b"ETNA_PARENT_ANCHOR_V1", config.l2_chain_id, config.registry, config.vp_unit,
            config.min_stake, config.n_max, config.u,
        ))

    def select(self, rows, at=7, *, config=None):
        config = self.config if config is None else config
        return self.model.select(rows, at, config, self.expected_config_hash(config))

    def test_all_three_slot_occupancies_have_minimal_positional_counts(self):
        expected_by_mask = (
            (), (ROW_0,), (EMPTY, ROW_1), (ROW_0, ROW_1),
            (EMPTY, EMPTY, ROW_2), (ROW_0, EMPTY, ROW_2),
            (EMPTY, ROW_1, ROW_2), (ROW_0, ROW_1, ROW_2),
        )
        for mask, expected in enumerate(expected_by_mask):
            with self.subTest(mask=f"{mask:03b}"):
                slots = tuple(row if mask & (1 << i) else EMPTY for i, row in enumerate((ROW_0, ROW_1, ROW_2)))
                entries = self.model.canonical_entries(slots)
                self.assertEqual(entries, expected)
                self.model.validate_snapshot(entries, len(expected), self.witness_root(expected))

    def test_no_slots_and_zero_count_have_zero_root(self):
        self.assertEqual(self.model.canonical_entries(()), ())
        self.model.validate_snapshot((), 0, ZERO_ROOT)
        with self.assertRaisesRegex(ValueError, "root mismatch"):
            self.model.validate_snapshot((), 0, self.keccak(b""))

    def test_public_witness_hashes_the_interior_vacancy_but_not_tree_padding(self):
        first, last = entry(KEY_A), entry(KEY_C, stake=0)
        rows = (first, EMPTY, last)
        left, vacancy, right = self.leaf(0, first), self.leaf(1, EMPTY), self.leaf(2, last)
        self.assertEqual(vacancy.hex(), "21d961646cf730220ee47cda213ec296eba41d18fc39f8f6cb1e1350f77c907d")
        self.assertEqual(self.witness_root(rows), PUBLIC_ROOT)
        self.assertEqual(self.model.canonical_entries(rows), rows)
        self.model.validate_snapshot(rows, 3, PUBLIC_ROOT)
        alternatives = (
            self.keccak(self.keccak(left + ZERO_ROOT) + self.keccak(right + ZERO_ROOT)),
            self.keccak(self.keccak(left + vacancy) + self.keccak(right + self.leaf(3, EMPTY))),
            self.witness_root((last, EMPTY, first)),
            self.witness_root((first, last)),
        )
        for root in alternatives:
            with self.subTest(root=root.hex()), self.assertRaisesRegex(ValueError, "root mismatch"):
                self.model.validate_snapshot(rows, 3, root)

    def test_matching_roots_do_not_admit_trailing_or_all_empty_entries(self):
        for rows in ((ROW_0, EMPTY), (EMPTY,), (EMPTY, EMPTY, EMPTY)):
            with self.subTest(count=len(rows), first=rows[0]):
                root = self.witness_root(rows)
                self.assertNotEqual(root, ZERO_ROOT)
                with self.assertRaisesRegex(ValueError, "trailing empty"):
                    self.model.validate_snapshot(rows, len(rows), root)

    def test_withdrawal_shrinks_count_and_slot_reuse_preserves_old_witnesses(self):
        slots = (ROW_0, EMPTY, ROW_2)
        before = self.model.canonical_entries(slots)
        before_root = self.witness_root((ROW_0, EMPTY, ROW_2))
        slots = (ROW_0, EMPTY, EMPTY)
        shrunk = self.model.canonical_entries(slots)
        slots = (EMPTY, EMPTY, EMPTY)
        self.assertEqual(self.model.canonical_entries(slots), ())
        slots = (REPLACEMENT, EMPTY, EMPTY)
        reused = self.model.canonical_entries(slots)
        self.assertEqual(shrunk, (ROW_0,))
        self.assertEqual(reused, (REPLACEMENT,))
        self.assertEqual(before, (ROW_0, EMPTY, ROW_2))
        self.model.validate_snapshot(reused, 1, self.leaf(0, REPLACEMENT))
        self.model.validate_snapshot(shrunk, 1, self.leaf(0, ROW_0))
        self.model.validate_snapshot(before, 3, before_root)
        with self.assertRaisesRegex(ValueError, "root mismatch"):
            self.model.validate_snapshot(reused, 1, self.leaf(0, ROW_0))

    def test_count_is_exact_integer_and_cannot_exceed_capacity(self):
        full_span = (EMPTY,) * 4095 + (ROW_2,)
        self.assertEqual(self.model.canonical_entries(full_span), full_span)
        with self.assertRaises(ValueError):
            self.model.canonical_entries(full_span + (EMPTY,))
        for count in (False, True, -1, 0, 2, 4097, 2**48):
            with self.subTest(count=count), self.assertRaises(ValueError):
                self.model.validate_snapshot((ROW_0,), count, self.leaf(0, ROW_0))
        oversized = (EMPTY,) * 4096 + (ROW_2,)
        with self.assertRaises(ValueError):
            self.model.validate_snapshot(oversized, 4097, ZERO_ROOT)

    def test_checkpoints_require_closed_typed_rows_and_exact_root_bytes(self):
        for rows in ([ROW_0], ((2, 1, 9, 1),), ((0, 0, 1, 0, 0),),
                     ((4, 1, 9, 1, 5),), ((False, 0, 0, 0, 0),)):
            with self.subTest(rows=rows):
                with self.assertRaises(ValueError):
                    self.model.canonical_entries(rows)
                with self.assertRaises(ValueError):
                    self.model.validate_snapshot(rows, len(rows), ZERO_ROOT)
        for index, value in ((0, 256), (1, 2**256), (2, -1), (2, 2**256), (3, 2**48), (4, True)):
            row = ROW_0[:index] + (value,) + ROW_0[index + 1:]
            with self.subTest(index=index, value=value), self.assertRaises(ValueError):
                self.model.validate_snapshot((row,), 1, ZERO_ROOT)
        for root in (bytes(31), bytes(33), bytearray(ZERO_ROOT), ZERO_ROOT.hex()):
            with self.subTest(root=root), self.assertRaises(ValueError):
                self.model.validate_snapshot((), 0, root)

    def test_committee_config_is_all_seven_abi_words_with_min_stake_fifth(self):
        self.assertEqual(len(CONFIG_PREIMAGE), 224)
        self.assertEqual(int.from_bytes(CONFIG_PREIMAGE[128:160], "big"), 4 * Q)
        self.assertEqual(self.keccak(CONFIG_PREIMAGE), CONFIG_HASH)
        self.assertEqual(self.model.config_preimage(self.config), CONFIG_PREIMAGE)
        self.assertEqual(self.model.config_hash(self.config), CONFIG_HASH)

    def test_changing_any_word_cannot_reuse_the_authenticated_config_hash(self):
        rows = (entry(KEY_A), entry(KEY_B, 5 * Q))
        changed_min = replace(self.config, min_stake=4 * Q + 1)
        self.assertEqual(self.select(rows, config=changed_min), ((*KEY_B, 5 * Q, 2),))
        self.assertEqual(self.model.select(rows, 7, self.config, CONFIG_HASH),
                         ((*KEY_B, 5 * Q, 2), (*KEY_A, 4 * Q, 2)))
        for field, value in (("l2_chain_id", CHAIN_ID + 1), ("registry", REGISTRY + 1),
                             ("vp_unit", 2 * Q + 1), ("min_stake", 4 * Q + 1),
                             ("n_max", 1), ("u", 3601)):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "config hash mismatch"):
                self.model.select(rows, 7, replace(self.config, **{field: value}), CONFIG_HASH)
        for digest in (ZERO_ROOT, bytearray(CONFIG_HASH), CONFIG_HASH[:-1], CONFIG_HASH.hex()):
            with self.subTest(digest=digest), self.assertRaises(ValueError):
                self.model.select(rows, 7, self.config, digest)

    def test_authenticated_configuration_still_requires_numeric_source_bounds(self):
        at_supply_limit = 10**27 // 4096
        with self.assertRaisesRegex(ValueError, "min_stake must be at least vp_unit"):
            self.select((entry(KEY_A),), config=replace(self.config, vp_unit=5 * Q))
        for field, value in (("vp_unit", 867_361_737), ("min_stake", at_supply_limit),
                             ("n_max", 0), ("n_max", 4097), ("u", 0), ("u", 65537)):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.select((entry(KEY_A),), config=replace(self.config, **{field: value}))
        boundary = replace(self.config, vp_unit=867_361_738, min_stake=at_supply_limit + 1,
                           n_max=4096, u=65536)
        self.assertEqual(self.select((entry(KEY_A, at_supply_limit + 1),), config=boundary),
                         ((*KEY_A, 244_140_625_000_000_000_000_001, 281_474_976_706_892),))
        self.assertEqual(self.select((entry(KEY_A),), config=replace(self.config, n_max=1, u=1)),
                         ((*KEY_A, 4 * Q, 2),))

    def test_config_values_cannot_alias_bool_or_overflow_their_typed_words(self):
        for field, value in (("l2_chain_id", 2**256), ("registry", 2**160), ("vp_unit", -1),
                             ("min_stake", 2**256), ("n_max", True), ("u", False)):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.model.config_preimage(replace(self.config, **{field: value}))

    def test_selection_includes_exact_threshold_and_floors_fractional_power(self):
        rows = (entry(KEY_A, 4 * Q - 1), entry(KEY_B), entry(KEY_C, 6 * Q - 1))
        self.assertEqual(self.select(rows), ((*KEY_B, 4 * Q, 2), (*KEY_C, 6 * Q - 1, 2)))

    def test_eligibility_uses_inclusive_activation_and_exclusive_exit(self):
        rows = (entry(KEY_A, active=7, exit_at=9), EMPTY, entry(KEY_B, active=8, exit_at=10))
        for at, expected in ((7, ((*KEY_A, 4 * Q, 2),)),
                             (8, ((*KEY_B, 4 * Q, 2), (*KEY_A, 4 * Q, 2))),
                             (9, ((*KEY_B, 4 * Q, 2),))):
            with self.subTest(at=at):
                self.assertEqual(self.select(rows, at), expected)
        for at in (6, 10):
            with self.subTest(at=at), self.assertRaisesRegex(ValueError, "empty selected set"):
                self.select(rows, at)

    def test_snapshot_block_requires_uint48(self):
        rows = (entry(KEY_A),)
        for at in (-1, 2**48, True):
            with self.subTest(at=at), self.assertRaises(ValueError):
                self.select(rows, at)
        self.assertEqual(self.select(rows, NO_EXIT - 1), ((*KEY_A, 4 * Q, 2),))
        with self.assertRaisesRegex(ValueError, "empty selected set"):
            self.select(rows, NO_EXIT)

    def test_rank_uses_stake_then_set_key_before_ordering_the_selected_members(self):
        rows = (entry(KEY_A, 7 * Q), entry(KEY_C, 4 * Q), entry(KEY_B, 4 * Q))
        for placement in (rows, tuple(reversed(rows)), (EMPTY, *rows)):
            with self.subTest(placement=placement):
                self.assertEqual(self.select(placement), ((*KEY_B, 4 * Q, 2), (*KEY_A, 7 * Q, 3)))
        one_member = replace(self.config, n_max=1)
        self.assertEqual(self.select(tuple(entry(key) for key in (KEY_A, KEY_C, KEY_B)), config=one_member),
                         ((*KEY_B, 4 * Q, 2),))

    def test_eligible_duplicate_key_is_rejected_before_cutoff(self):
        config = replace(self.config, n_max=1)
        with self.assertRaisesRegex(ValueError, "duplicate eligible"):
            self.select((entry(KEY_A), entry(KEY_A, 5 * Q)), config=config)
        self.assertEqual(self.select((entry(KEY_A), entry(KEY_A, 5 * Q, active=8)), config=config),
                         ((*KEY_A, 4 * Q, 2),))

    def test_zero_stake_or_empty_registry_cannot_select_a_committee(self):
        for rows in ((), (EMPTY, entry(KEY_A, 0))):
            with self.subTest(rows=rows), self.assertRaisesRegex(ValueError, "empty selected set"):
                self.select(rows)
        with self.assertRaisesRegex(ValueError, "trailing empty"):
            self.select((entry(KEY_A), EMPTY))

    def test_selected_power_must_fit_uint64_and_the_total_backstop(self):
        max_power = 1_152_921_504_606_846_975
        unit = 2 * Q
        limit_stake = max_power * unit
        self.assertEqual(self.select((entry(KEY_A, limit_stake),)), ((*KEY_A, limit_stake, max_power),))
        with self.assertRaisesRegex(ValueError, "total power"):
            self.select((entry(KEY_A, limit_stake), entry(KEY_B)))
        with self.assertRaisesRegex(ValueError, "uint64 power"):
            self.select((entry(KEY_A, 2**64 * unit),))


if __name__ == "__main__":
    unittest.main()
