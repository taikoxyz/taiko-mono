"""Checker regression tests with independent fixtures for each validation branch."""
import hashlib
import pathlib
import subprocess
import sys
import unittest

import check


class IncorporationTests(unittest.TestCase):
    def setUp(self):
        self.index = {"START-10.1-1": {"type": "rule"}, "START-10.1-4": {"type": "rule"}}
        self.spec = (
            "**[START-10.1-1]** [One](UPGRADES.md#1-one)\n"
            "**[START-10.1-4]** [Two](UPGRADES.md#2-two)\n"
        )
        self.helper = (
            "# Definitions\n\n## 1. One\n\n<!-- governed-by: START-10.1-1 -->\n\nFirst.\n"
            "\n## 2. Two\n\n<!-- governed-by: START-10.1-4 -->\n\nSecond.\n"
        )

    def errors(self):
        return check.check_incorporation(self.spec, self.helper, self.index)

    def test_valid_fixture(self):
        self.assertEqual(self.errors(), [])

    def test_missing_mapping(self):
        self.helper = self.helper.replace("<!-- governed-by: START-10.1-1 -->", "")
        self.assertTrue(any("exactly one" in m for m in self.errors()))

    def test_unknown_id_only(self):
        # The backlink is valid; only the INDEX ownership lookup is missing.
        del self.index["START-10.1-1"]
        self.assertEqual(self.errors(), ["incorporation: START-10.1-1 is not a live rule"])

    def test_non_rule_type_only(self):
        # Keep the known ID, matching marker and backlink intact.
        self.index["START-10.1-1"]["type"] = "limitation"
        self.assertEqual(self.errors(), ["incorporation: START-10.1-1 is not a live rule"])

    def test_mapping_outside_section_only(self):
        self.helper = "<!-- governed-by: START-10.1-1 -->\n" + self.helper
        self.assertEqual(self.errors(), ["incorporation: governing ID outside a section"])

    def test_duplicate_anchor_only(self):
        self.helper = self.helper.replace("## 2. Two", "## 1. One")
        self.spec = self.spec.replace("#2-two", "#1-one")
        self.assertEqual(self.errors(), ["incorporation: duplicate section anchor 1-one"])

    def test_missing_backlink_only(self):
        self.spec = self.spec.replace("UPGRADES.md#1-one", "UPGRADES.md")
        self.assertTrue(any("owning-rule backlink" in m for m in self.errors()))

    def test_duplicate_mapping(self):
        self.helper = self.helper.replace("First.", "<!-- governed-by: START-10.1-1 -->\n\nFirst.")
        self.assertTrue(any("exactly one" in m for m in self.errors()))

    def test_example_cannot_supply_mapping(self):
        self.helper = self.helper.replace(
            "<!-- governed-by: START-10.1-1 -->", "```txt\n<!-- governed-by: START-10.1-1 -->\n```"
        )
        self.assertTrue(any("exactly one" in m for m in self.errors()))

    def test_mismatched_fence_cannot_hide_real_unmapped_section(self):
        self.helper += "\n```txt\n~~~\n```\n\n## 3. Unmapped\n\nA real requirement.\n"
        self.assertTrue(any("3. Unmapped needs exactly one" in m for m in self.errors()))

    def test_shorter_fence_does_not_close_example(self):
        self.helper += "\n````txt\n```\n## Example heading\n````\n"
        self.assertEqual(self.errors(), [])

    def test_unclosed_fence_is_an_error(self):
        self.helper += "\n```txt\nAn unclosed example.\n"
        self.assertTrue(any("unclosed fence" in m for m in self.errors()))


class AmendmentTests(unittest.TestCase):
    def setUp(self):
        self.before = "**[START-10.1-1]** Old requirement.\n"
        self.after = "**[START-10.1-1]** New requirement.\n"
        self.index = {"START-10.1-1": {"type": "rule"}}
        self.table = (
            "## Material amendments\n\n| ID | Prior meaning | Current amendment | Content digest |\n"
            "| --- | --- | --- | --- |\n"
            "| START-10.1-1 | Old | New | " + hashlib.blake2s(b"New requirement.").hexdigest() + " |\n\n## Index\n"
        )
        self.row = next(line for line in self.table.splitlines() if line.startswith("| START-10.1-1")) + "\n"

    def errors(self):
        return check.check_amendments(self.after, self.table, self.index, self.before)

    def test_all_changed_ids_are_declared(self):
        self.assertEqual(self.errors(), [])

    def test_missing_changed_id(self):
        self.table = self.table.replace(self.row, "")
        self.assertTrue(any("undeclared amendment START-10.1-1" in m for m in self.errors()))

    def test_duplicate_amendment_id(self):
        self.table = self.table.replace("## Index", self.row + "\n## Index")
        self.assertTrue(any("duplicate amendment" in m for m in self.errors()))

    def test_unknown_amendment_id(self):
        self.table = self.table.replace("START-10.1-1 |", "START-10.1-999 |")
        self.assertTrue(any("unknown amendment" in m for m in self.errors()))

    def test_formatting_does_not_require_amendment(self):
        self.after = "**[START-10.1-1]** Old   requirement.\n"
        self.table = self.table.replace(self.row, "")
        self.assertEqual(self.errors(), [])

    def test_definition_block_change_requires_amendment(self):
        self.before = "```txt\n// [START-10.1-1]\nfield = old\n```\n"
        self.after = self.before.replace("field = old", "field = new")
        self.table = self.table.replace(self.row, "")
        self.assertTrue(any("undeclared amendment" in m for m in self.errors()))


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.index = {"START-10.1-1": {"section": "10.1", "type": "rule"},
                      "START-10.1-4": {"section": "10.1", "type": "rule"}}
        self.assets = {"10.1": ("## START-10.1-1\n| 1.a accept | A | Yes |\n| 1.b reject | B | No |\n", "## Q10.1-1\nQuestion.\n")}
        self.table = "## Coverage\n\n| Section | IDs | Vectors | Review questions |\n| --- | --- | --- | --- |\n| 10.1 | 2 | 2 | 1 |\n"

    def errors(self):
        return check.check_coverage(self.table, self.index, self.assets)

    def test_valid_counts(self):
        self.assertEqual(self.errors(), [])

    def test_each_count_is_checked_independently(self):
        for row in ["1 | 2 | 1", "2 | 1 | 1", "2 | 2 | 0"]:
            with self.subTest(row=row):
                original = self.table
                self.table = original.replace("2 | 2 | 1", row)
                self.assertTrue(any("coverage: 10.1" in m for m in self.errors()))
                self.table = original

    def test_missing_section(self):
        self.table = self.table.replace("| 10.1 | 2 | 2 | 1 |\n", "")
        self.assertTrue(any("coverage: missing 10.1" in m for m in self.errors()))

    def test_duplicate_case_label(self):
        vectors, review = self.assets["10.1"]
        self.assets["10.1"] = (vectors.replace("1.b", "1.a"), review)
        self.assertTrue(any("duplicate vector" in m for m in self.errors()))


class RepositoryIntegrationTests(unittest.TestCase):
    def test_repository_checker(self):
        docs = pathlib.Path(__file__).resolve().parents[2]
        result = subprocess.run([sys.executable, str(docs / "rules/tools/check.py")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
