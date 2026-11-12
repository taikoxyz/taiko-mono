"""Mutation tests for check.py: each test copies the corpus to a temp dir and breaks one rule."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / "check.py"
spec = importlib.util.spec_from_file_location("check", SCRIPT)
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)
ROOT = SCRIPT.parent

BLOCK = "cases/smoke.block.transfer.json"
HARNESS = "cases/smoke.harness.add.json"
ANCHOR = ("input", "txs", 0)
TRANSFER = ("input", "txs", 1)

# Synthetic expectations for the two smoke inputs; they only need to be well formed.
BLOCK_EXPECTED = {
    "raw_txs": ["0x02c0", "0x02c0"],
    "included": [0, 1],
    "truncated_at": None,
    "cumulative_zk_gas": ["0x100", "0x200"],
    "block_zk_gas": "0x200",
    "state_root": "0x" + "11" * 32,
    "import_built": "accept",
    "import_extended": None,
    "import_wrong_difficulty": "reject",
}
HARNESS_EXPECTED = {"frame_zk_gas": "0x1", "status": "success"}


def set_at(*path_and_value):
    """Returns a mutation that sets data[path...] = value."""
    *path, value = path_and_value

    def mutate(data):
        for key in path[:-1]:
            data = data[key]
        data[path[-1]] = copy.deepcopy(value)

    return mutate


def delete_at(*path):
    def mutate(data):
        for key in path[:-1]:
            data = data[key]
        del data[path[-1]]

    return mutate


def chain(*mutations):
    def mutate(data):
        for mutation in mutations:
            mutation(data)

    return mutate


def add_sentinel(data):
    """Appends a second transfer from signer 1 so the block has three txs."""
    sentinel = copy.deepcopy(data["input"]["txs"][1])
    sentinel["nonce"] = "0x1"
    data["input"]["txs"].append(sentinel)


TRUNCATED = chain(
    add_sentinel,
    set_at(
        "expected",
        dict(
            BLOCK_EXPECTED,
            raw_txs=["0x02c0"] * 3,
            included=[0],
            truncated_at=1,
            cumulative_zk_gas=["0x100"],
            block_zk_gas="0x100",
            import_extended="reject",
        ),
    ),
)


def cell(cell_id, mutation):
    """Applies mutation to one coverage.json cell."""

    def mutate(data):
        mutation(next(c for c in data["cells"] if c["id"] == cell_id))

    return mutate


class CheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "zk_gas_vectors"
        shutil.copytree(ROOT, self.root, ignore=shutil.ignore_patterns("__pycache__"))

    def read(self, rel):
        return json.loads((self.root / rel).read_text())

    def write(self, rel, data):
        (self.root / rel).write_text(json.dumps(data, indent=2))

    def errors_after(self, rel, mutate, require_expected=False):
        """Checks the corpus with one file mutated, then restores the file."""
        original = (self.root / rel).read_text()
        data = json.loads(original)
        mutate(data)
        self.write(rel, data)
        try:
            return check.check(self.root, require_expected)
        finally:
            (self.root / rel).write_text(original)

    def assertRejected(self, rel, mutate, needle, require_expected=False):
        errors = self.errors_after(rel, mutate, require_expected)
        self.assertTrue(
            any(needle in error for error in errors),
            f"expected an error containing {needle!r}, got {errors}",
        )

    def assertAccepted(self, rel, mutate, require_expected=False):
        self.assertEqual(self.errors_after(rel, mutate, require_expected), [])

    def test_current_corpus_passes(self):
        self.assertEqual(check.check(self.root, False), [])

    def test_unknown_cell_rejected(self):
        self.assertRejected(BLOCK, set_at("cells", ["no.such.cell"]), "unknown cell 'no.such.cell'")

    def test_empty_cell_rejected(self):
        unused = {"id": "static.arith.unused", "layers": ["harness"], "source": "s", "description": "d"}
        self.assertRejected(
            "coverage.json",
            lambda data: data["cells"].append(unused),
            "cell 'static.arith.unused' has no vector",
        )

    def test_layer_not_allowed_rejected(self):
        self.assertRejected(
            "coverage.json",
            cell("static.arith.success", set_at("layers", ["block"])),
            "layer 'harness' is not allowed for cell 'static.arith.success'",
        )
        self.assertRejected(
            "coverage.json",
            cell("static.arith.success", set_at("layers", ["block", "trace"])),
            "layers",
        )

    def test_id_must_match_filename(self):
        self.assertRejected(BLOCK, set_at("id", "smoke.block.other"), "does not match the file name")
        (self.root / BLOCK).rename(self.root / "cases/smoke.block.renamed.json")
        errors = check.check(self.root, False)
        self.assertTrue(any("does not match the file name" in e for e in errors), errors)

    def test_noncanonical_hex_rejected(self):
        for bad in ["0x00", "0X1", "0x0A", "0x", "1", 1, None]:
            with self.subTest(value=bad):
                self.assertRejected(BLOCK, set_at(*TRANSFER, "value", bad), "input.txs[1].value")
        for good in ["0x0", "0xa"]:
            with self.subTest(value=good):
                self.assertAccepted(BLOCK, set_at(*TRANSFER, "value", good))
        storage = ("input", "alloc", "0x000000000000000000000000000000000000c0de", "storage")
        self.assertRejected(HARNESS, set_at(*storage, {"0x01": "0x1"}), "storage key")
        self.assertRejected(HARNESS, set_at(*storage, {"0x1": "0x01"}), "storage.0x1")
        self.assertAccepted(HARNESS, set_at(*storage, {"0x1": "0xff"}))
        # Byte-valued fields keep their leading zeros.
        self.assertAccepted(BLOCK, set_at(*TRANSFER, "data", "0x0001"))

    def test_byte_fields_validated(self):
        for field, bad in [
            ("data", "0x1"),
            ("data", "0X00"),
            ("data", "00"),
            ("to", "0x" + "00" * 19),
            ("to", "0x" + "zz" * 20),
        ]:
            with self.subTest(field=field, value=bad):
                self.assertRejected(BLOCK, set_at(*TRANSFER, field, bad), f"input.txs[1].{field}")
        self.assertAccepted(BLOCK, set_at(*TRANSFER, "to", "0x000000000000000000000000000000000000BEEF"))
        self.assertAccepted(BLOCK, set_at(*TRANSFER, "to", None))

    def test_unknown_and_missing_fields_rejected(self):
        self.assertRejected(BLOCK, set_at("comment", "x"), "unknown field 'comment'")
        self.assertRejected(BLOCK, delete_at("description"), "missing field 'description'")
        self.assertRejected(BLOCK, delete_at(*TRANSFER, "max_fee"), "missing field 'max_fee'")
        self.assertRejected(HARNESS, set_at("input", "calldata", "0x"), "unknown field 'calldata'")
        self.assertRejected(HARNESS, delete_at("input", "caller"), "missing field 'caller'")

    def test_duplicate_json_key_rejected(self):
        path = self.root / BLOCK
        text = json.dumps(json.loads(path.read_text()))
        path.write_text(text.replace('"id": ', '"id": "smoke.block.transfer", "id": ', 1))
        errors = check.check(self.root, False)
        self.assertTrue(any("duplicate key 'id'" in e for e in errors), errors)

    def test_alloc_rules(self):
        alloc = ("input", "alloc")
        upper = "0x0000000000000000000000000000000000C0FFEE"
        self.assertRejected(BLOCK, set_at(*alloc, upper, {"balance": "0x1"}), "duplicate address")
        self.assertRejected(BLOCK, set_at(*alloc, "0x" + "00" * 19, {"balance": "0x1"}), "must be 20 bytes")
        self.assertRejected(BLOCK, set_at(*alloc, "0x" + "ab" * 20, {"nonce": "0x0"}), "missing field 'balance'")
        unknown = {"balance": "0x1", "code_hash": "0x"}
        self.assertRejected(BLOCK, set_at(*alloc, "0x" + "ab" * 20, unknown), "unknown field 'code_hash'")

    def test_block_fixed_environment(self):
        env = ("input", "env")
        for field, bad in [
            ("chain_id", "0x28c5a"),
            ("number", "0x2"),
            ("base_fee", "0x17d7841"),
            ("timestamp", "0x0"),
            ("extra_data", "0x4b0000000001"),
            ("prev_randao", "0x" + "00" * 31),
            ("coinbase", "0x" + "00" * 21),
        ]:
            with self.subTest(field=field):
                self.assertRejected(BLOCK, set_at(*env, field, bad), f"input.env.{field}")

    def test_anchor_stub_required(self):
        stub = ("input", "alloc", "0x1670010000000000000000000000000000010001")
        self.assertRejected(BLOCK, delete_at(*stub), "STOP stub")
        self.assertRejected(BLOCK, set_at(*stub, "code", "0x6000"), "STOP stub")

    def test_block_first_tx_must_be_anchor(self):
        for field, bad in [
            ("signer", 1),
            ("to", "0x1670010000000000000000000000000000010002"),
            ("data", "0x523e6855"),
            ("data", "0x523e685400"),
            ("gas", "0xf4241"),
            ("max_priority_fee", "0x1"),
            ("max_fee", "0x17d7841"),
            ("nonce", "0x1"),
            ("value", "0x1"),
        ]:
            with self.subTest(field=field, value=bad):
                self.assertRejected(BLOCK, set_at(*ANCHOR, field, bad), "anchor")
        self.assertRejected(BLOCK, set_at("input", "txs", []), "anchor")

    def test_golden_touch_only_at_index_zero(self):
        self.assertRejected(BLOCK, set_at(*TRANSFER, "signer", "golden_touch"), "golden_touch")

    def test_signer_range(self):
        for bad in [0, 2**32, -1, True, "1", 1.0, None]:
            with self.subTest(signer=bad):
                self.assertRejected(BLOCK, set_at(*TRANSFER, "signer", bad), "input.txs[1].signer")
        self.assertAccepted(BLOCK, set_at(*TRANSFER, "signer", 2**32 - 1))

    def test_blob_or_access_list_rejected(self):
        for field, value in [("type", 2), ("access_list", []), ("blob_versioned_hashes", [])]:
            with self.subTest(field=field):
                self.assertRejected(BLOCK, set_at(*TRANSFER, field, value), f"field '{field}' is not allowed")

    def test_harness_input_rules(self):
        self.assertRejected(HARNESS, set_at("input", "frame_gas", hex(2**64 - 1)), "input.frame_gas")
        self.assertAccepted(HARNESS, set_at("input", "frame_gas", hex(2**64 - 1 - 21_000)))
        self.assertRejected(HARNESS, set_at("input", "zk_block_limit", hex(2**64)), "input.zk_block_limit")
        self.assertRejected(HARNESS, set_at("input", "caller", "0x1234"), "input.caller")

    def test_require_expected_missing_rejected(self):
        for rel in (BLOCK, HARNESS):
            data = self.read(rel)
            data.pop("expected", None)
            self.write(rel, data)
        self.assertEqual(check.check(self.root, False), [])
        errors = check.check(self.root, True)
        for rel in (BLOCK, HARNESS):
            self.assertTrue(any(e.startswith(rel) and "missing expected" in e for e in errors), errors)
        for rel, expected in ((BLOCK, BLOCK_EXPECTED), (HARNESS, HARNESS_EXPECTED)):
            self.write(rel, dict(self.read(rel), expected=expected))
        self.assertEqual(check.check(self.root, True), [])
        # Expected fields must match the layer.
        self.assertRejected(BLOCK, set_at("expected", HARNESS_EXPECTED), "missing field 'included'", True)
        self.assertRejected(HARNESS, set_at("expected", BLOCK_EXPECTED), "missing field 'status'", True)

    def test_truncation_needs_sentinel(self):
        self.assertAccepted(BLOCK, TRUNCATED)
        self.assertRejected(BLOCK, chain(TRUNCATED, set_at("expected", "truncated_at", 2)), "sentinel")
        # The two-tx smoke block has no tx after index 1.
        no_sentinel = dict(
            BLOCK_EXPECTED,
            included=[0],
            truncated_at=1,
            cumulative_zk_gas=["0x100"],
            block_zk_gas="0x100",
            import_extended="reject",
        )
        self.assertRejected(BLOCK, set_at("expected", no_sentinel), "sentinel")

    def test_expected_consistency(self):
        self.assertAccepted(BLOCK, set_at("expected", BLOCK_EXPECTED))
        for name, mutation, needle in [
            ("block total", set_at("expected", "block_zk_gas", "0x201"), "last cumulative_zk_gas"),
            ("included start", set_at("expected", "included", [1]), "start with 0"),
            ("included order", set_at("expected", "included", [0, 0]), "included: must be strictly increasing"),
            ("included range", set_at("expected", "included", [0, 2]), "out of range"),
            ("included type", set_at("expected", "included", [0, True]), "JSON integers"),
            ("cumulative length", set_at("expected", "cumulative_zk_gas", ["0x200"]), "one entry per included"),
            (
                "cumulative order",
                set_at("expected", "cumulative_zk_gas", ["0x200", "0x200"]),
                "cumulative_zk_gas: must be strictly increasing",
            ),
            (
                "cumulative limit",
                chain(
                    set_at("expected", "cumulative_zk_gas", ["0x100", "0x5f5e101"]),
                    set_at("expected", "block_zk_gas", "0x5f5e101"),
                ),
                "block zk gas limit",
            ),
            ("raw_txs length", set_at("expected", "raw_txs", ["0x02c0"]), "one per input tx"),
            ("raw_txs type", set_at("expected", "raw_txs", ["0x02c0", "0x01c0"]), "type-2"),
            ("state root", set_at("expected", "state_root", "0x11"), "state_root: must be 32 bytes"),
            ("import_built", set_at("expected", "import_built", "reject"), "import_built"),
            (
                "import_wrong_difficulty",
                set_at("expected", "import_wrong_difficulty", "accept"),
                "import_wrong_difficulty",
            ),
            ("extended without truncation", set_at("expected", "import_extended", "reject"), "import_extended"),
            (
                "truncated before included",
                chain(
                    TRUNCATED,
                    set_at("expected", "included", [0, 2]),
                    set_at("expected", "cumulative_zk_gas", ["0x100", "0x200"]),
                    set_at("expected", "block_zk_gas", "0x200"),
                ),
                "greater than every included",
            ),
            (
                "truncation without extended",
                chain(TRUNCATED, set_at("expected", "import_extended", None)),
                "import_extended",
            ),
        ]:
            with self.subTest(name=name):
                self.assertRejected(BLOCK, chain(set_at("expected", BLOCK_EXPECTED), mutation), needle)

    def test_zk_limit_requires_null_frame_zk_gas(self):
        self.assertAccepted(HARNESS, set_at("expected", {"frame_zk_gas": None, "status": "zk_limit"}))
        zk_limit_with_gas = {"frame_zk_gas": "0x1", "status": "zk_limit"}
        self.assertRejected(HARNESS, set_at("expected", zk_limit_with_gas), "must be null when status is zk_limit")
        success_without_gas = {"frame_zk_gas": None, "status": "success"}
        self.assertRejected(HARNESS, set_at("expected", success_without_gas), "null only when status is zk_limit")
        noncanonical = {"frame_zk_gas": "0x01", "status": "revert"}
        self.assertRejected(HARNESS, set_at("expected", noncanonical), "expected.frame_zk_gas")
        for status in ["success", "revert", "halt"]:
            with self.subTest(status=status):
                self.assertAccepted(HARNESS, set_at("expected", {"frame_zk_gas": "0x0", "status": status}))
        misspelled = {"frame_zk_gas": "0x1", "status": "zklimit"}
        self.assertRejected(HARNESS, set_at("expected", misspelled), "expected.status")

    def test_reference_commits_are_full_sha(self):
        self.assertRejected("reference.json", set_at("alethia_reth", "commit", "6e86a39"), "alethia_reth.commit")
        self.assertRejected("reference.json", set_at("taiko_geth_checked", "6cfe6e010"), "taiko_geth_checked")
        upper = "6CFE6E01062A1DFC00650BC6FE51FF3A0E30F6E4"
        self.assertRejected("reference.json", set_at("taiko_geth_checked", upper), "taiko_geth_checked")

    def test_coverage_reference_matches_reference_json(self):
        bumped = set_at("alethia_reth", "revm_interpreter", "43.0.2")
        self.assertRejected("reference.json", bumped, "must be 'revm-interpreter 43.0.2' to match reference.json")
        self.assertRejected("reference.json", set_at("alethia_reth", "revm", "latest"), "alethia_reth.revm")

    def test_stray_case_file_rejected(self):
        (self.root / "cases/notes.txt").write_text("x")
        errors = check.check(self.root, False)
        self.assertTrue(any("cases/notes.txt" in e for e in errors), errors)
        (self.root / "cases/notes.txt").unlink()
        (self.root / "cases/.DS_Store").write_text("x")
        self.assertEqual(check.check(self.root, False), [])

    def test_no_vectors_rejected(self):
        shutil.rmtree(self.root / "cases")
        errors = check.check(self.root, False)
        self.assertTrue(any("no vectors" in e for e in errors), errors)

    def test_cli_exit_codes(self):
        command = [sys.executable, str(self.root / "check.py")]
        ok = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(ok.returncode, 0, ok.stderr)
        (self.root / "reference.json").write_text("{}")
        bad = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(bad.returncode, 1)
        self.assertIn("reference.json", bad.stderr)


if __name__ == "__main__":
    unittest.main()
