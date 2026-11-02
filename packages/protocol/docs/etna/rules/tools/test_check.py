"""Checker regression tests with independent fixtures for each validation branch."""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
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
            "| START-10.1-1 | Old | New | " + hashlib.blake2s(b"type: rule\nNew requirement.").hexdigest() + " |\n\n## Index\n"
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


class AmendmentHistoryTests(unittest.TestCase):
    """Historical identity and prior meaning cannot be erased by editing current files."""

    def setUp(self):
        self.rid = "TEST-1-1"
        self.spec = "**[TEST-1-1]** Current requirement.\n"
        self.index = {self.rid: {"type": "rule", "section": "1"}}
        self.table = (
            "## Material amendments\n\n| ID | Prior meaning | Current amendment | Content digest |\n"
            "| --- | --- | --- | --- |\n"
            "| TEST-1-1 | Original meaning. | Current meaning. | "
            + hashlib.blake2s(b"type: rule\nCurrent requirement.").hexdigest()
            + " |\n\n## Index\n\n| TEST-1-1 | rule | Rule | 1 | Vectors |\n"
        )

    def errors(self, spec=None, table=None, index=None, baseline_table=None):
        return check.check_amendments(
            self.spec if spec is None else spec, self.table if table is None else table,
            self.index if index is None else index, self.spec,
            baseline_index_text=self.table if baseline_table is None else baseline_table)

    def test_deletion_requires_retired_tombstone_even_for_last_id(self):
        self.assertIn("amendments: missing retired tombstone TEST-1-1",
                      self.errors(spec="", index={}))

    def test_unchanged_registry_is_valid(self):
        self.assertEqual(self.errors(), [])

    def test_retired_identity_cannot_be_reactivated(self):
        before = self.table.replace("| rule | Rule |", "| retired | Rule |")
        self.assertIn("amendments: retired ID reused TEST-1-1", self.errors(baseline_table=before))

    def test_deleted_registry_row_is_rejected(self):
        current = "\n".join(line for line in self.table.splitlines()
                            if not line.startswith("| TEST-1-1 | Original"))
        self.assertIn("amendments: removed history TEST-1-1", self.errors(table=current))

    def test_prior_meaning_cannot_be_rewritten(self):
        current = self.table.replace("Original meaning.", "Rewritten history.")
        self.assertIn("amendments: rewritten prior meaning TEST-1-1", self.errors(table=current))

    def test_type_change_requires_declaration(self):
        current = "## Index\n| TEST-1-1 | limitation | Rule | 1 | Vectors |\n"
        before = "## Index\n| TEST-1-1 | rule | Rule | 1 | Vectors |\n"
        index = {self.rid: {"type": "limitation", "section": "1"}}
        self.assertIn("amendments: undeclared amendment TEST-1-1",
                      self.errors(table=current, index=index, baseline_table=before))

    def test_type_change_invalidates_old_declaration_digest(self):
        self.assertEqual(self.errors(), [])
        index = {self.rid: {"type": "limitation", "section": "1"}}
        self.assertIn("amendments: stale content digest TEST-1-1", self.errors(index=index))

    def test_retirement_with_retained_history_and_fresh_digest_is_valid(self):
        current = self.table.replace("| rule | Rule |", "| retired | Rule |")
        current = current.replace(hashlib.blake2s(b"type: rule\nCurrent requirement.").hexdigest(),
                                  hashlib.blake2s(b"type: retired\n").hexdigest())
        index = {self.rid: {"type": "retired", "section": "1"}}
        self.assertEqual(self.errors(spec="", table=current, index=index), [])

    def test_retirement_digest_is_checked(self):
        index = {self.rid: {"type": "retired", "section": "1"}}
        self.assertIn("amendments: stale content digest TEST-1-1",
                      self.errors(spec="", index=index))


class ProsePlacementTests(unittest.TestCase):
    def test_inline_marker_cannot_be_hidden_in_html_comment(self):
        spec = "<!--\n**[TEST-1-1]** Hidden requirement.\n-->\n"
        self.assertIn("placement: inline rule inside HTML comment TEST-1-1",
                      check.check_marker_placement(spec))

    def test_inline_marker_cannot_be_indented_code(self):
        spec = "## 1. Rules\n\n    **[TEST-1-1]** Hidden requirement.\n"
        self.assertIn("placement: inline rule inside indented code TEST-1-1",
                      check.check_marker_placement(spec))

    def test_inline_marker_cannot_be_raw_html_code(self):
        for tag in ("pre", "script", "style", "textarea", "PRE"):
            with self.subTest(tag=tag):
                spec = "<" + tag + ">\n\n**[TEST-1-1]** Hidden requirement.\n\n</" + tag + ">\n"
                self.assertIn("placement: inline rule inside raw HTML code TEST-1-1",
                              check.check_marker_placement(spec))

    def test_nested_list_fence_cannot_supply_inline_rule(self):
        spec = "- Wrapper\n\n    ```txt\n    **[TEST-1-1]** Hidden requirement.\n\n    ```\n"
        self.assertIn("placement: inline rule inside fenced code TEST-1-1",
                      check.check_marker_placement(spec))

    def test_inline_code_span_cannot_supply_rule(self):
        for spec in ("`**[TEST-1-1]** Hidden requirement.`\n",
                     "``**[TEST-1-1]** Hidden `nested` requirement.``\n"):
            with self.subTest(spec=spec):
                self.assertIn("placement: inline rule inside inline code TEST-1-1",
                              check.check_marker_placement(spec))

    def test_details_summary_keeps_visible_rule(self):
        spec = "<details>\n<summary>Details</summary>\n\n**[TEST-1-1]** Visible requirement.\n\n</details>\n"
        self.assertEqual(check.check_marker_placement(spec), [])

    def test_raw_html_tag_in_inline_code_does_not_hide_next_rule(self):
        spec = "Use `<pre>` for examples.\n\n**[TEST-1-1]** Visible `field` requirement.\n"
        self.assertEqual(check.check_marker_placement(spec), [])

    def test_unmarked_paragraph_continuation_is_rejected(self):
        spec = "**[TEST-1-1]** First requirement.\nAdditional requirement.\n"
        self.assertIn("placement: unmarked paragraph continuation after TEST-1-1",
                      check.check_marker_placement(spec))

    def test_nested_list_rule_remains_visible(self):
        spec = "- Parent.\n  - Child.\n     - **[TEST-1-1]** Visible requirement.\n"
        self.assertEqual(check.check_marker_placement(spec), [])

    def test_separate_paragraph_remains_unmarked_guidance(self):
        spec = "**[TEST-1-1]** First requirement.\n\nUnmarked guidance.\n"
        self.assertEqual(check.check_marker_placement(spec), [])

    def test_appendix_code_before_marker_remains_valid(self):
        spec = "## Appendix A. Encodings\n\n```txt\n// [ENC-A-1]\nvalue = 1\n```\n"
        self.assertEqual(check.check_marker_placement(spec), [])

    def test_indented_pseudo_fence_cannot_authorize_code_before_marker(self):
        spec = "## Appendix A. Encodings\n\n    ```txt\n// [ENC-A-1]\nvalue = 1\n```\n"
        self.assertIn("placement: code-before marker outside Appendix A definition ENC-A-1",
                      check.check_marker_placement(spec))


class AmendmentBaseCLIIntegrationTests(unittest.TestCase):
    """Use a real externally supplied Git base, including its SPEC/INDEX/UPGRADES."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = pathlib.Path(self.temp.name).resolve()
        self.docs = self.repo / "etna"
        (self.docs / "rules/tools").mkdir(parents=True)
        shutil.copyfile(pathlib.Path(check.__file__), self.docs / "rules/tools/check.py")
        self.write("SPEC.md", "## 1. Rules\n\n**[TEST-1-1]** [Rules](UPGRADES.md#1-rules)\n\n"
                   "**[TEST-1-2]** Unchanged requirement.\n")
        self.write("UPGRADES.md", "## 1. Rules\n\n<!-- governed-by: TEST-1-1 -->\n\n"
                   "Original helper.\n\n```txt\nvalue = 1\n```\n")
        self.write("rules/INDEX.md", "## Material amendments\n\n"
                   "| ID | Prior meaning | Current amendment | Content digest |\n"
                   "| --- | --- | --- | --- |\n\n"
                   "## Coverage\n\n| Section | IDs | Vectors | Review questions |\n"
                   "| --- | --- | --- | --- |\n| 1 | 2 | 0 | 0 |\n\n"
                   "## Index\n\n| ID | Type | Title | Section | Vectors |\n"
                   "| --- | --- | --- | --- | --- |\n"
                   "| TEST-1-1 | rule | Helper | 1 | Vectors |\n"
                   "| TEST-1-2 | rule | Requirement | 1 | Vectors |\n")
        self.write("rules/vectors/1.md", "## TEST-1-1\n\n## TEST-1-2\n")
        self.write("rules/review/1.md", "# Review\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "external base")
        self.base = self.git("rev-parse", "HEAD").strip()

    def write(self, path, text):
        target = self.docs / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.repo), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def edit(self, path, old, new):
        target = self.docs / path
        self.assertIn(old, target.read_text())
        target.write_text(target.read_text().replace(old, new, 1))

    def run_check(self, expected=None):
        result = subprocess.run([sys.executable, str(self.docs / "rules/tools/check.py"),
                                 "--amendments-base", self.base], capture_output=True, text=True)
        if expected is None:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("ok   amendments (base delta checked)", result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(expected, result.stdout)

    def test_unchanged_external_base_passes(self):
        self.run_check()

    def test_spec_change_is_compared_to_external_base(self):
        self.edit("SPEC.md", "Unchanged requirement.", "Changed requirement.")
        self.run_check("FAIL amendments: undeclared amendment TEST-1-2")

    def test_helper_prose_change_is_compared_to_external_base(self):
        self.edit("UPGRADES.md", "Original helper.", "Changed helper.")
        self.run_check("FAIL amendments: undeclared amendment TEST-1-1")

    def test_helper_definition_change_is_compared_to_external_base(self):
        self.edit("UPGRADES.md", "value = 1", "value = 2")
        self.run_check("FAIL amendments: undeclared amendment TEST-1-1")

    def test_index_type_change_is_compared_to_external_base(self):
        self.edit("rules/INDEX.md", "| TEST-1-2 | rule |", "| TEST-1-2 | limitation |")
        self.run_check("FAIL amendments: undeclared amendment TEST-1-2")

    def test_deleting_last_identity_requires_tombstone(self):
        self.edit("SPEC.md", "**[TEST-1-2]** Unchanged requirement.\n", "")
        self.edit("rules/INDEX.md", "| TEST-1-2 | rule | Requirement | 1 | Vectors |\n", "")
        self.edit("rules/INDEX.md", "| 1 | 2 | 0 | 0 |", "| 1 | 1 | 0 | 0 |")
        self.edit("rules/vectors/1.md", "## TEST-1-2\n", "")
        self.run_check("FAIL amendments: missing retired tombstone TEST-1-2")

    def test_missing_base_index_fails_closed(self):
        self.git("rm", "etna/rules/INDEX.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "base missing index")
        missing_base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", self.base, "--", "etna/rules/INDEX.md")
        self.base = missing_base
        self.run_check("FAIL amendments: cannot read INDEX.md at supplied base")

    def test_missing_base_helper_fails_closed(self):
        self.git("rm", "etna/UPGRADES.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "base missing helper")
        missing_base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", self.base, "--", "etna/UPGRADES.md")
        self.base = missing_base
        self.run_check("FAIL amendments: cannot read UPGRADES.md at supplied base")

    def test_first_helper_introduction_allows_verified_absent_base_file(self):
        self.edit("SPEC.md", "[Rules](UPGRADES.md#1-rules)", "Original helper rule.")
        self.git("rm", "etna/UPGRADES.md")
        self.git("add", "etna/SPEC.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "base before helper introduction")
        original_base = self.base
        self.base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", original_base, "--", "etna/SPEC.md", "etna/UPGRADES.md")
        governed = ("type: rule\n[Rules](UPGRADES.md#1-rules)\n[UPGRADES.md#1-rules]\n"
                    "## 1. Rules\n\n<!-- governed-by: TEST-1-1 -->\n\nOriginal helper.\n\n"
                    "```txt\nvalue = 1\n```")
        digest = hashlib.blake2s(governed.encode()).hexdigest()
        row = "| TEST-1-1 | Original helper rule. | Incorporates helper. | " + digest + " |\n"
        self.edit("rules/INDEX.md", "\n## Coverage", row + "\n## Coverage")
        self.run_check()

    def test_unreadable_existing_base_helper_is_not_first_introduction(self):
        # A tree entry exists, but its blob is unavailable: a failed read is not absence.
        original_base = self.base
        self.edit("SPEC.md", "[Rules](UPGRADES.md#1-rules)", "Original helper rule.")
        self.git("add", "etna/SPEC.md")
        self.git("update-index", "--cacheinfo", "100644," + "a" * 40 + ",etna/UPGRADES.md")
        tree = self.git("write-tree", "--missing-ok").strip()
        self.base = self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                             "commit-tree", tree, "-p", self.base, "-m", "unavailable helper blob").strip()
        self.git("checkout", original_base, "--", "etna/SPEC.md")
        self.run_check("FAIL amendments: cannot read UPGRADES.md at supplied base")

    def test_missing_base_spec_fails_closed(self):
        self.git("rm", "etna/SPEC.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "base missing spec")
        missing_base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", self.base, "--", "etna/SPEC.md")
        self.base = missing_base
        self.run_check("FAIL amendments: cannot read SPEC.md at supplied base")

    def test_nonexistent_base_fails_closed(self):
        self.base = "0" * 40
        self.run_check("FAIL amendments: cannot read SPEC.md at supplied base")

    def add_historical_declaration(self):
        digest = hashlib.blake2s(b"type: rule\nUnchanged requirement.").hexdigest()
        self.history_row = "| TEST-1-2 | Original meaning. | Current meaning. | " + digest + " |\n"
        self.edit("rules/INDEX.md", "\n## Coverage", self.history_row + "\n## Coverage")
        self.git("add", "etna/rules/INDEX.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "historical amendment")
        self.base = self.git("rev-parse", "HEAD").strip()

    def test_historical_registry_row_cannot_be_deleted(self):
        self.add_historical_declaration()
        self.edit("rules/INDEX.md", self.history_row, "")
        self.run_check("FAIL amendments: removed history TEST-1-2")

    def test_historical_prior_meaning_cannot_be_rewritten(self):
        self.add_historical_declaration()
        self.edit("rules/INDEX.md", "Original meaning.", "Rewritten meaning.")
        self.run_check("FAIL amendments: rewritten prior meaning TEST-1-2")

    def test_retired_external_base_id_cannot_be_reused(self):
        self.edit("SPEC.md", "**[TEST-1-2]** Unchanged requirement.\n", "")
        self.edit("rules/INDEX.md", "| TEST-1-2 | rule |", "| TEST-1-2 | retired |")
        self.edit("rules/INDEX.md", "| 1 | 2 | 0 | 0 |", "| 1 | 1 | 0 | 0 |")
        self.git("add", "etna")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "retired identity")
        retired_base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", self.base, "--", "etna")
        self.base = retired_base
        self.run_check("FAIL amendments: retired ID reused TEST-1-2")


if __name__ == "__main__":
    unittest.main()
