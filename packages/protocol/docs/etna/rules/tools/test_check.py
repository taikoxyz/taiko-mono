"""CLI regression tests for structured retirements and replacement ordering."""

from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest


class ReplacementOrderTests(unittest.TestCase):
    def check_fixture(self, tail, replacements, *, metadata=None, titles=None, raw_metadata=None):
        with tempfile.TemporaryDirectory() as directory:
            docs = Path(directory)
            rules = docs / "rules"
            for name in ("tools", "vectors", "review"):
                (rules / name).mkdir(parents=True)
            checker = rules / "tools" / "check.py"
            shutil.copyfile(Path(__file__).with_name("check.py"), checker)
            ids = [f"LIMIT-12-{n}" for n in range(1, 10)] + tail
            (docs / "SPEC.md").write_text(
                "## 12. Limitations\n\n"
                + "\n".join(f"**[{rid}]** A limitation." for rid in ids)
                + "\n"
            )
            rows = [f"| {rid} | limitation | A limitation | 12 | |" for rid in ids]
            for rid, replacement in replacements.items():
                title = "Retired" if replacement is None else f"Retired: replaced by {replacement}"
                title = (titles or {}).get(rid, title)
                rows.append(f"| {rid} | retired | {title} | 12 | |")
            (rules / "INDEX.md").write_text("\n".join(rows) + "\n")
            (rules / "retirements.json").write_text(
                raw_metadata if raw_metadata is not None
                else json.dumps(replacements if metadata is None else metadata) + "\n"
            )
            (rules / "vectors" / "12.md").write_text("# Vectors\n")
            (rules / "review" / "12.md").write_text("# Review\n")
            return subprocess.run(
                [sys.executable, str(checker)], capture_output=True, text=True
            )

    def test_replacement_precedes_existing_suffix_sibling(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_replacement_chain_retains_original_position(self):
        result = self.check_fixture(
            ["LIMIT-12-10c", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b", "LIMIT-12-10b": "LIMIT-12-10c"},
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unannounced_suffix_inversion_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": None},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not in document order", result.stdout)

    def test_replacement_after_its_original_sibling_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-10b", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not in document order", result.stdout)

    def test_missing_replacement_target_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("replacement", result.stdout)

    def test_replacement_cannot_change_numeric_family(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-11", "LIMIT-12-11a"],
            {"LIMIT-12-10": "LIMIT-12-11a"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("replacement", result.stdout)

    def test_title_wording_does_not_control_replacement(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
            titles={"LIMIT-12-10": "Superseded by the revised timestamp limitation"},
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_retirement_metadata_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
            metadata={},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retirement", result.stdout)

    def test_replacement_chain_cannot_end_at_deleted_rule(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b", "LIMIT-12-10b": None},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("replacement", result.stdout)

    def test_non_object_retirement_metadata_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
            metadata=[],
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retirement", result.stdout)

    def test_metadata_for_a_live_rule_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": None},
            metadata={"LIMIT-12-10": None, "LIMIT-12-11": None},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retirement", result.stdout)

    def test_duplicate_retirement_keys_are_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
            raw_metadata='{"LIMIT-12-10": null, "LIMIT-12-10": "LIMIT-12-10b"}',
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retirement", result.stdout)

    def test_invalid_metadata_json_is_rejected(self):
        result = self.check_fixture(
            ["LIMIT-12-10b", "LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": "LIMIT-12-10b"},
            raw_metadata="{",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("retirement", result.stdout)

    def test_standalone_deleted_rule_needs_no_live_successor(self):
        result = self.check_fixture(
            ["LIMIT-12-10a", "LIMIT-12-11"],
            {"LIMIT-12-10": None},
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
