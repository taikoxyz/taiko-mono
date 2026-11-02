"""Regression tests for replacement IDs retaining a retired rule's position."""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class ReplacementOrderTests(unittest.TestCase):
    def check_fixture(self, tail, replacements):
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
                rows.append(f"| {rid} | retired | {title} | 12 | |")
            (rules / "INDEX.md").write_text("\n".join(rows) + "\n")
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


if __name__ == "__main__":
    unittest.main()
