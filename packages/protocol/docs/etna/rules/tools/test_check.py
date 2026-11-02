"""Regression tests for normative upgrade-definition coverage.

Run: python3 -m unittest discover -s packages/protocol/docs/etna/rules/tools
Removing coverage/backlink enforcement must make the mutation tests fail.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


DOCS = pathlib.Path(__file__).resolve().parents[2]


class UpgradeCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.docs = pathlib.Path(self.temp.name) / "etna"
        shutil.copytree(DOCS, self.docs, ignore=shutil.ignore_patterns("__pycache__"))

    def change(self, name, old, new):
        path = self.docs / name
        text = path.read_text()
        self.assertEqual(text.count(old), 1)
        path.write_text(text.replace(old, new))

    def check(self):
        return subprocess.run(
            [sys.executable, str(self.docs / "rules/tools/check.py")],
            capture_output=True, text=True,
        )

    def assert_coverage_failure(self):
        result = self.check()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("FAIL incorporation:", result.stdout)

    def test_complete_current_document_passes(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_governing_id_fails(self):
        self.change("UPGRADES.md", "<!-- governed-by: START-10.1-8 -->", "")
        self.assert_coverage_failure()

    def test_unknown_governing_id_fails(self):
        self.change("UPGRADES.md", "governed-by: START-10.1-8", "governed-by: START-10.1-999")
        self.assert_coverage_failure()

    def test_limitation_cannot_govern_requirements(self):
        self.change("UPGRADES.md", "governed-by: START-10.1-8", "governed-by: LIMIT-12-10")
        self.assert_coverage_failure()

    def test_missing_owning_rule_backlink_fails(self):
        self.change("SPEC.md", "UPGRADES.md#5-structural-fence-and-atomic-activation", "UPGRADES.md")
        self.assert_coverage_failure()

    def test_additional_unmapped_section_fails(self):
        path = self.docs / "UPGRADES.md"
        path.write_text(path.read_text() + "\n## 7. Unmapped requirements\n\nRequire new behavior.\n")
        self.assert_coverage_failure()

    def test_duplicate_mapping_fails(self):
        marker = "<!-- governed-by: START-10.1-8 -->"
        self.change("UPGRADES.md", marker, marker + "\n" + marker)
        self.assert_coverage_failure()

    def test_example_mapping_does_not_supply_authority(self):
        marker = "<!-- governed-by: START-10.1-8 -->"
        self.change("UPGRADES.md", marker, "```txt\n" + marker + "\n```")
        self.assert_coverage_failure()


if __name__ == "__main__":
    unittest.main()
