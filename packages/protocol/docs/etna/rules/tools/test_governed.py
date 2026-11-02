"""Regression tests for complete governed-content tracking and CLI validation stages."""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

import check


def declaration(rid, body):
    digest = hashlib.blake2s(("type: rule\n" + body).encode()).hexdigest()
    return ("## Material amendments\n\n| ID | Prior meaning | Current amendment | Content digest |\n"
            "| --- | --- | --- | --- |\n| " + rid + " | Prior | Current | " + digest + " |\n\n## Index\n")


class GovernedContentTests(unittest.TestCase):
    def setUp(self):
        self.spec = "**[START-10.1-5]** [Rules](UPGRADES.md#1-rules)\n"
        self.helper = "## 1. Rules\n\n<!-- governed-by: START-10.1-5 -->\n\nT > checkpointTimestamp.\n\n```txt\nH >= c + U\n```\n"
        self.index = {"START-10.1-5": {"type": "rule"}}

    def test_helper_prose_change_requires_declaration(self):
        changed = self.helper.replace("T >", "T >=")
        errors = check.check_amendments(self.spec, "", self.index, self.spec,
                                        helper=changed, baseline_helper=self.helper)
        self.assertIn("amendments: undeclared amendment START-10.1-5", errors)

    def test_helper_fenced_definition_change_requires_declaration(self):
        changed = self.helper.replace("H >=", "H >")
        errors = check.check_amendments(self.spec, "", self.index, self.spec,
                                        helper=changed, baseline_helper=self.helper)
        self.assertIn("amendments: undeclared amendment START-10.1-5", errors)

    def test_existing_declaration_expires_after_edit(self):
        table = declaration("START-10.1-5", check.governed_bodies(self.spec, self.helper)["START-10.1-5"])
        changed = self.helper.replace("T >", "T >=")
        errors = check.check_amendments(self.spec, table, self.index, helper=changed)
        self.assertIn("amendments: stale content digest START-10.1-5", errors)

    def test_solidity_check_change_is_governed(self):
        before = ("### 6.1 land\n\n**[LAND-6.1-10]** Reference checks.\n\n"
                  "```solidity\nrequire(c < h);\n```\n\n### 6.2 Proofs\n")
        after = before.replace("c < h", "c <= h")
        errors = check.check_amendments(after, "", {"LAND-6.1-10": {"type": "rule"}}, before)
        self.assertIn("amendments: undeclared amendment LAND-6.1-10", errors)

    def test_code_string_whitespace_is_preserved(self):
        before = self.helper.replace("H >= c + U", 'domain = "A B"')
        after = before.replace('"A B"', '"A  B"')
        self.assertNotEqual(check.governed_bodies(self.spec, before), check.governed_bodies(self.spec, after))

    def test_missing_reference_block_fails(self):
        errors = check.check_amendments("### 6.1 land\n\n**[LAND-6.1-10]** Reference checks.\n", "",
                                        {"LAND-6.1-10": {"type": "rule"}})
        self.assertTrue(any("reference Solidity" in error for error in errors))


class MarkdownStructureTests(unittest.TestCase):
    def test_spec_unclosed_fence(self):
        self.assertTrue(any("unclosed fence" in e for e in check.check_markdown_structure("SPEC.md", "```txt\nvalue\n")))

    def test_setext_section_is_not_silently_unowned(self):
        self.assertTrue(any("setext" in e for e in check.check_markdown_structure("UPGRADES.md", "Hidden section\n--------------\n")))

    def test_setext_inside_example_is_ignored(self):
        self.assertEqual(check.check_markdown_structure("SPEC.md", "```txt\nExample\n-------\n```\n"), [])


class CheckerCLIStagesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.docs = pathlib.Path(self.temp.name) / "etna"
        source = pathlib.Path(__file__).resolve().parents[2]
        shutil.copytree(source, self.docs, ignore=shutil.ignore_patterns("__pycache__"))

    def edit(self, path, old, new):
        path = self.docs / path
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1))

    def run_check(self, expected):
        result = subprocess.run([sys.executable, str(self.docs / "rules/tools/check.py")], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(expected, result.stdout)

    def test_duplicate_marker(self):
        self.edit("SPEC.md", "**[CONS-3.1-9]**", "**[CONS-3.1-8]**")
        self.run_check("FAIL markers: duplicate ID")

    def test_unknown_index_type(self):
        path = self.docs / "rules/INDEX.md"
        rows = path.read_text().splitlines()
        row = next(r for r in rows if r.startswith("| LAND-6.1-13") and len(check.split_cells(r)) == 5)
        cells = check.split_cells(row)
        cells[1] = "unknown"
        self.edit("rules/INDEX.md", row, "| " + " | ".join(cells) + " |")
        self.run_check("FAIL index: unknown type")

    def test_missing_vector_heading(self):
        self.edit("rules/vectors/6.1.md", "## LAND-6.1-13", "## LAND-6.1-999")
        self.run_check("FAIL assets: no vector heading for LAND-6.1-13")

    def test_dead_relative_link(self):
        self.edit("rules/vectors/6.1.md", "(../../SPEC.md)", "(../../MISSING.md)")
        self.run_check("FAIL links:")

    def test_bad_table_columns(self):
        self.edit("rules/vectors/6.1.md", "| Vector", "| Extra | Vector")
        self.run_check("FAIL tables:")

    def test_helper_prose_invalidates_current_seal(self):
        self.edit("UPGRADES.md", "maxAnchorAge < T", "maxAnchorAge <= T")
        self.run_check("FAIL amendments: stale content digest START-10.1-5")

    def test_helper_definition_invalidates_current_seal(self):
        self.edit("UPGRADES.md", "uint64 triggerTimestamp,", "uint8 triggerTimestamp,")
        self.run_check("FAIL amendments: stale content digest START-10.1-4")

    def test_reference_solidity_invalidates_current_seal(self):
        self.edit("SPEC.md", "p <= c && c < h", "p <= c && c <= h")
        self.run_check("FAIL amendments: stale content digest LAND-6.1-10")

    def test_inline_rule_cannot_be_hidden_in_closed_example(self):
        path = self.docs / "SPEC.md"
        text = path.read_text()
        line = next(line for line in text.splitlines() if line.startswith("**[CONS-3.4-12]**"))
        path.write_text(text.replace(line, "```txt\n" + line + "\n```", 1))
        self.run_check("FAIL placement: inline rule inside fenced code CONS-3.4-12")

    def test_code_before_marker_requires_appendix_definition(self):
        path = self.docs / "SPEC.md"
        text = path.read_text().replace("// [ENC-A-6]\n", "", 1)
        path.write_text(text + "\n// [ENC-A-6]\nMisplaced definition.\n")
        self.run_check("FAIL placement: code-before marker outside Appendix A definition ENC-A-6")

    def test_unclosed_spec_fence(self):
        path = self.docs / "SPEC.md"
        path.write_text(path.read_text() + "\n```txt\nUnclosed\n")
        self.run_check("FAIL markdown: unclosed fence in SPEC.md")

    def test_unclosed_vector_fence(self):
        path = self.docs / "rules/vectors/6.1.md"
        path.write_text(path.read_text() + "\n```txt\nUnclosed vector example.\n")
        self.run_check("FAIL markdown: unclosed fence in rules/vectors/6.1.md")

    def test_appendix_definition_fence_cannot_be_hidden_in_html(self):
        for opening, closing in (("<!--", "-->"), ("<pre>", "</pre>")):
            with self.subTest(opening=opening):
                path = self.docs / "SPEC.md"
                original = path.read_text()
                start = original.index("```txt", original.index("## Appendix A"))
                end = original.index("```", start + 6) + 3
                path.write_text(original[:start] + opening + "\n" + original[start:end]
                                + "\n" + closing + original[end:])
                try:
                    self.run_check("FAIL placement: code-before marker inside hidden HTML ENC-A-1")
                finally:
                    path.write_text(original)
