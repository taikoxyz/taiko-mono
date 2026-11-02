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

    def test_literal_backlink_does_not_supply_an_owning_rule_link(self):
        self.spec = self.spec.replace("[One](UPGRADES.md#1-one)", "`[One](UPGRADES.md#1-one)`")
        self.assertTrue(any("owning-rule backlink" in m for m in self.errors()))

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
        self.table = self.table.replace(self.row, self.row + self.row)
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
        self.assets = {"10.1": ("## START-10.1-1\n\n| Vector | Setup | Expected |\n| --- | --- | --- |\n| 1.a accept | A | Yes |\n| 1.b reject | B | No |\n", "## Q10.1-1\nQuestion.\n")}
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
            + " |\n\n## Index\n\n| ID | Type | Title | Section | Vectors |\n| --- | --- | --- | --- | --- |\n| TEST-1-1 | rule | Rule | 1 | Vectors |\n"
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
        current = "## Index\n\n| ID | Type | Title | Section | Vectors |\n| --- | --- | --- | --- | --- |\n| TEST-1-1 | limitation | Rule | 1 | Vectors |\n"
        before = current.replace("limitation", "rule")
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
        current = self.append_snapshot(current)
        index = {self.rid: {"type": "retired", "section": "1"}}
        self.assertEqual(self.errors(spec="", table=current, index=index), [])

    def test_retirement_digest_is_checked(self):
        index = {self.rid: {"type": "retired", "section": "1"}}
        self.assertIn("amendments: stale content digest TEST-1-1",
                      self.errors(spec="", index=index))

    def append_snapshot(self, current):
        row = next(line for line in self.table.splitlines() if line.startswith("| TEST-1-1 | Original"))
        return current.replace("## Index", "## Amendment history\n\n"
                               "| ID | Prior meaning | Current amendment | Content digest |\n"
                               "| --- | --- | --- | --- |\n" + row + "\n\n## Index")

    def test_second_amendment_requires_prior_current_declaration_snapshot(self):
        current = self.table.replace("Current meaning.", "Second amendment.")
        self.assertIn("amendments: missing declaration snapshot TEST-1-1", self.errors(table=current))

    def test_digest_refresh_requires_prior_declaration_snapshot(self):
        current = self.table.replace(hashlib.blake2s(b"type: rule\nCurrent requirement.").hexdigest(),
                                  hashlib.blake2s(b"type: rule\nSecond requirement.").hexdigest())
        self.assertIn("amendments: missing declaration snapshot TEST-1-1",
                      self.errors(spec="**[TEST-1-1]** Second requirement.\n", table=current))

    def test_second_amendment_with_exact_prior_snapshot_is_valid(self):
        current = self.append_snapshot(self.table.replace("Current meaning.", "Second amendment."))
        self.assertEqual(self.errors(table=current), [])

    def test_existing_declaration_snapshot_cannot_be_removed(self):
        baseline = self.append_snapshot(self.table)
        self.assertIn("amendments: historical snapshots are not append-only",
                      self.errors(baseline_table=baseline))

    def test_existing_declaration_snapshot_cannot_be_rewritten(self):
        baseline = self.append_snapshot(self.table)
        start = baseline.index("## Amendment history")
        current = baseline[:start] + baseline[start:].replace("Current meaning.", "Rewritten meaning.")
        self.assertIn("amendments: historical snapshots are not append-only",
                      self.errors(table=current, baseline_table=baseline))

    def recurring_declaration(self):
        row = next(line for line in self.table.splitlines() if line.startswith("| TEST-1-1 | Original"))
        intermediate = row.replace("Current meaning.", "Intermediate meaning.").replace(
            hashlib.blake2s(b"type: rule\nCurrent requirement.").hexdigest(),
            hashlib.blake2s(b"type: rule\nIntermediate requirement.").hexdigest())
        baseline = self.append_snapshot(self.table).replace(row + "\n\n## Index", row + "\n" + intermediate + "\n\n## Index")
        current = baseline.replace("Current meaning.", "Third meaning.", 1).replace(
            hashlib.blake2s(b"type: rule\nCurrent requirement.").hexdigest(),
            hashlib.blake2s(b"type: rule\nThird requirement.").hexdigest(), 1)
        return baseline, current, row

    def test_repeated_declaration_requires_a_new_snapshot_after_returning_to_prior_meaning(self):
        # The baseline is A -> B -> A; moving to C must append a second A snapshot.
        baseline, current, _row = self.recurring_declaration()
        self.assertIn("amendments: missing declaration snapshot TEST-1-1",
                      self.errors(spec="**[TEST-1-1]** Third requirement.\n", table=current,
                                  baseline_table=baseline))

    def test_repeated_declaration_with_a_fresh_duplicate_snapshot_is_valid(self):
        baseline, current, row = self.recurring_declaration()
        current = current.replace("\n\n## Index", "\n" + row + "\n\n## Index")
        self.assertEqual(self.errors(spec="**[TEST-1-1]** Third requirement.\n", table=current,
                                     baseline_table=baseline), [])


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

    def test_code_before_marker_cannot_be_hidden_in_html_within_definition(self):
        for opening, closing in (("<!--", "-->"), ("<pre>", "</pre>")):
            with self.subTest(opening=opening):
                spec = ("## Appendix A. Encodings\n\n" + opening
                        + "\n```txt\n// [ENC-A-1]\nvalue = 1\n```\n" + closing + "\n")
                self.assertIn("placement: code-before marker inside hidden HTML ENC-A-1",
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

    def test_commented_index_rows_do_not_supply_live_identity(self):
        self.edit("rules/INDEX.md", "| TEST-1-2 | rule | Requirement | 1 | Vectors |",
                  "<!--\n| TEST-1-2 | rule | Requirement | 1 | Vectors |\n-->")
        self.run_check("FAIL markers: 1 ID(s) with no INDEX row")

    def test_commented_vector_heading_does_not_supply_coverage(self):
        self.edit("rules/vectors/1.md", "## TEST-1-2", "<!--\n## TEST-1-2\n-->")
        self.run_check("FAIL assets: no vector heading for TEST-1-2")

    def test_commented_vector_and_question_do_not_inflate_counts(self):
        self.write("rules/vectors/1.md", "## TEST-1-1\n\n## TEST-1-2\n\n<!--\n| 2.a accept | A | Yes |\n-->\n")
        self.write("rules/review/1.md", "# Review\n\n<!--\n## Q1-1\nHidden question.\n-->\n")
        self.run_check()

    def test_commented_coverage_row_does_not_supply_counts(self):
        self.edit("rules/INDEX.md", "| 1 | 2 | 0 | 0 |", "<!--\n| 1 | 2 | 0 | 0 |\n-->")
        self.run_check("FAIL coverage: missing 1")

    def test_commented_amendment_does_not_declare_changed_rule(self):
        self.edit("SPEC.md", "Unchanged requirement.", "Changed requirement.")
        row = ("<!--\n| TEST-1-2 | Original | Changed | "
               "d4ffb28f42cc5c9c0261c7ee3a9b35a7c2227d88870996b8e0cac8d2d1693fb8 |\n-->\n")
        self.edit("rules/INDEX.md", "\n## Coverage", row + "\n## Coverage")
        self.run_check("FAIL amendments: undeclared amendment TEST-1-2")

    def append_history(self, row):
        self.edit("rules/INDEX.md", "\n## Coverage", "\n## Amendment history\n\n"
                  "| ID | Prior meaning | Current amendment | Content digest |\n"
                  "| --- | --- | --- | --- |\n" + row + "\n\n## Coverage")

    def test_unknown_history_identity_fails_without_base_comparison(self):
        self.append_history("| TEST-1-999 | Old | Fake | " + "a" * 64 + " |")
        result = subprocess.run([sys.executable, str(self.docs / "rules/tools/check.py")],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FAIL amendments: unknown historical amendment TEST-1-999", result.stdout)

    def test_fabricated_history_for_known_identity_is_not_a_base_snapshot(self):
        self.append_history("| TEST-1-2 | Invented past | Invented claim | " + "a" * 64 + " |")
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_malformed_historical_digest_is_rejected(self):
        self.append_history("| TEST-1-2 | Old | Current | not-a-digest |")
        self.run_check("FAIL amendments: malformed historical amendment TEST-1-2")

    def test_malformed_historical_identity_cannot_be_silently_ignored(self):
        self.append_history("| invented | Old | Current | " + "a" * 64 + " |")
        self.run_check("FAIL amendments: unknown historical amendment invented")

    def test_commented_history_cannot_preserve_changed_declaration(self):
        self.add_historical_declaration()
        self.edit("rules/INDEX.md", "Current meaning.", "Next meaning.")
        self.append_history("<!--\n" + self.history_row + "-->")
        self.run_check("FAIL amendments: missing declaration snapshot TEST-1-2")

    def test_commented_question_is_not_a_resolvable_review_fragment(self):
        self.write("rules/review/1.md", "# Review\n\n<!--\n## Q1-1\nHidden question.\n-->\n")
        self.write("rules/vectors/1.md", "## TEST-1-1\n\n## TEST-1-2\n\n"
                   "See [question](../review/1.md#q1-1).\n")
        self.run_check("FAIL links: 1.md -> ../review/1.md#q1-1 (dead fragment)")

    def test_missing_relative_image_is_a_broken_reference(self):
        self.write("rules/review/1.md", "# Review\n\n![Diagram](MISSING.png)\n")
        self.run_check("FAIL links: 1.md -> MISSING.png")

    def test_commented_link_is_not_a_live_broken_reference(self):
        self.write("rules/review/1.md", "# Review\n\n<!--\n[old link](MISSING.md)\n-->\n")
        self.run_check()

    def test_orphan_pipe_rows_cannot_pass_as_vector_coverage(self):
        self.write("rules/vectors/1.md", "## TEST-1-1\n\n## TEST-1-2\n\nA prose note.\n\n"
                   "| 2.a accept | Setup | Conforms |\n| 2.b reject | Setup | Violates |\n")
        self.edit("rules/INDEX.md", "| 1 | 2 | 0 | 0 |", "| 1 | 2 | 2 | 0 |")
        self.run_check("FAIL tables: 1.md needs a header and separator before table rows")

    def test_valid_header_separator_table_supplies_vector_coverage(self):
        self.write("rules/vectors/1.md", "## TEST-1-1\n\n## TEST-1-2\n\n"
                   "| Vector | Setup | Expected |\n| :--- | ---: | :---: |\n"
                   "| 2.a accept | A `x\\|y` value | Conforms |\n"
                   "| 2.b reject | A \\| value | Violates |\n")
        self.edit("rules/INDEX.md", "| 1 | 2 | 0 | 0 |", "| 1 | 2 | 2 | 0 |")
        self.run_check()

    def test_orphan_pipe_examples_in_fences_and_comments_remain_literal(self):
        self.write("rules/review/1.md", "# Review\n\n```txt\n| Example | Only |\n```\n\n"
                   "<!--\n| Old example | Only |\n-->\n")
        self.run_check()

    def supersede_declaration(self, commit=True):
        self.edit("SPEC.md", "Unchanged requirement.", "Updated requirement.")
        digest = hashlib.blake2s(b"type: rule\nUpdated requirement.").hexdigest()
        replacement = self.history_row.replace("Current meaning.", "Updated meaning.")
        replacement = replacement.replace(self.history_row.split(" | ")[-1].strip(" |\n"), digest)
        self.edit("rules/INDEX.md", self.history_row, replacement)
        if commit:
            self.git("add", "etna/SPEC.md", "etna/rules/INDEX.md")
            self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                     "commit", "-qm", "supersede declaration before history backfill")

    def backfill_from_git(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        self.supersede_declaration()
        self.append_history(self.history_row)

    def test_draft_commit_backfill_is_not_a_base_snapshot(self):
        self.backfill_from_git()
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_backfill_cannot_invent_a_different_prior_declaration(self):
        self.backfill_from_git()
        self.edit("rules/INDEX.md", self.history_row,
                  self.history_row.replace("Current meaning.", "Invented meaning."))
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_backfill_cannot_reuse_one_git_supersession_twice(self):
        self.backfill_from_git()
        self.edit("rules/INDEX.md", self.history_row, self.history_row + self.history_row)
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_required_base_snapshot_also_consumes_its_git_supersession(self):
        self.add_historical_declaration()
        self.supersede_declaration()
        self.append_history(self.history_row + self.history_row)
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_working_draft_supersession_needs_no_history(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        self.supersede_declaration(commit=False)
        self.run_check()

    def test_committed_draft_supersession_needs_no_history(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        self.supersede_declaration()
        self.run_check()

    def test_unmerged_draft_declaration_can_be_removed(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        self.edit("rules/INDEX.md", self.history_row, "")
        self.run_check()

    def test_unchanged_head_declaration_does_not_authorize_fake_working_history(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        self.append_history(self.history_row)
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

    def test_superseded_git_row_with_wrong_typed_digest_does_not_prove_backfill(self):
        original_base = self.base
        self.add_historical_declaration()
        self.base = original_base
        bad_row = self.history_row.replace(
            hashlib.blake2s(b"type: rule\nUnchanged requirement.").hexdigest(), "a" * 64)
        self.edit("rules/INDEX.md", self.history_row, bad_row)
        self.git("add", "etna/rules/INDEX.md")
        self.git("-c", "user.name=Checker Test", "-c", "user.email=checker@example.invalid",
                 "commit", "-qm", "invalid historical digest")
        self.history_row = bad_row
        self.supersede_declaration()
        self.append_history(bad_row)
        self.run_check("FAIL amendments: unsupported declaration snapshot TEST-1-2")

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

    def test_explicit_empty_base_is_an_argument_error(self):
        result = subprocess.run([sys.executable, str(self.docs / "rules/tools/check.py"),
                                 "--amendments-base", ""], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--amendments-base must not be empty", result.stderr)

    def test_symlink_invocation_uses_real_checker_repository_and_base(self):
        self.edit("SPEC.md", "Unchanged requirement.", "Changed requirement.")
        launcher = self.repo / "launcher/check.py"
        launcher.parent.mkdir()
        launcher.symlink_to(self.docs / "rules/tools/check.py")
        result = subprocess.run([sys.executable, str(launcher), "--amendments-base", self.base],
                                cwd=launcher.parent, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FAIL amendments: undeclared amendment TEST-1-2", result.stdout)
        self.assertNotIn("Traceback", result.stderr)

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


class MarkdownParserRegressions(unittest.TestCase):
    def test_indented_fake_fence_cannot_hide_appendix_definition_in_comment(self):
        spec = ("    ~~~\n\n<!--\n## Appendix A. Encodings\n\n```txt\n"
                "// [ENC-A-1]\nvalue = 1\n```\n-->\n")
        self.assertTrue(check.check_marker_placement(spec))
        self.assertTrue(check.check_markdown_structure("SPEC.md", spec))

    def test_indented_fake_fence_cannot_hide_landing_reference(self):
        spec = ("## 6.1. Landing\n\n**[LAND-6.1-10]** Reference.\n\n"
                "    ~~~\n\n<!--\n```solidity\nfunction land() {}\n```\n-->\n")
        with self.assertRaises(ValueError):
            check.governed_bodies(spec)

    def test_hidden_first_amendment_section_cannot_override_visible_section(self):
        digest = check.content_digest("Current.", "rule")
        table = ("## Material amendments\n\n| ID | Prior meaning | Current amendment | Content digest |\n"
                 "| --- | --- | --- | --- |\n| TEST-1-1 | Prior | Current | " + digest + " |\n")
        text = "    ~~~\n\n<!--\n" + table + "-->\n\n" + table.replace(digest, "a" * 64)
        errors = check.check_amendments("**[TEST-1-1]** Current.\n", text,
                                       {"TEST-1-1": {"type": "rule"}})
        self.assertIn("amendments: stale content digest TEST-1-1", errors)

    def test_visible_duplicate_amendment_sections_are_rejected(self):
        table = "## Material amendments\n\n| ID | Prior meaning | Current amendment | Content digest |\n| --- | --- | --- | --- |\n"
        self.assertTrue(check.check_amendments("", table + "\n" + table, {}))

    def test_leading_space_history_row_is_not_skipped(self):
        text = ("## Amendment history\n\n | ID | Prior meaning | Current amendment | Content digest |\n"
                " | --- | --- | --- | --- |\n | invented | Prior | Current | " + "a" * 64 + " |\n")
        self.assertIn("amendments: unknown historical amendment invented",
                      check.check_amendments("", text, {}))

    def test_leading_space_index_row_is_live(self):
        text = " | ID | Type | Title | Section | Vectors |\n | --- | --- | --- | --- | --- |\n | TEST-1-1 | rule | Title | 1 | Vectors |\n"
        self.assertIn("TEST-1-1", check.parse_index(text)[0])

    def test_reference_definitions_cannot_hide_normative_rules(self):
        for name in ("SPEC.md", "UPGRADES.md"):
            with self.subTest(name=name):
                self.assertTrue(check.check_markdown_structure(name,
                    '[hidden]: /url "**[TEST-1-1]** Hidden requirement."\n'))

    def test_even_backslashes_do_not_escape_html(self):
        self.assertTrue(check.check_markdown_structure("SPEC.md", "\\\\<script>\n"))

    def test_autolink_backtick_cannot_open_a_code_span(self):
        self.assertTrue(check.check_markdown_structure("SPEC.md", '<https://example.invalid/`> <script>hidden</script> `\n'))

    def test_html_attribute_backtick_cannot_open_a_code_span(self):
        self.assertTrue(check.check_markdown_structure("SPEC.md", '<br title="`"> <script>hidden</script> `\n'))

    def test_noncanonical_rendered_marker_lookalikes_are_rejected(self):
        for marker in (r"\**[TEST-1-1]**", "__[TEST-1-1]__", "**&#91;TEST-1-1&#93;**",
                       r"**\[TEST-1-1\]**", "&#42;&#42;[TEST-1-1]&#42;&#42;"):
            with self.subTest(marker=marker):
                self.assertTrue(check.check_marker_placement(marker + " Hidden requirement.\n"))

    def test_lazy_list_continuation_is_a_paragraph_continuation(self):
        self.assertTrue(check.check_marker_placement("- **[TEST-1-1]** First requirement.\n  --- still same paragraph\n"))

    def test_five_spaces_after_list_marker_are_code(self):
        self.assertIn("placement: inline rule inside indented code TEST-1-1",
                      check.check_marker_placement("-     **[TEST-1-1]** Hidden requirement.\n"))

    def test_ordinary_comparison_text_is_not_html(self):
        for text in ("a<b\n", "If x <y\n", "**[TEST-1-1]** If x <y, compare a<b.\n"):
            with self.subTest(text=text):
                self.assertEqual(check.check_markdown_structure("SPEC.md", text), [])

    def test_thematic_break_after_table_or_list_is_not_setext(self):
        for text in ("| A | B |\n| --- | --- |\n| X | Y |\n---\n", "- An item\n---\n"):
            with self.subTest(text=text):
                self.assertEqual(check.check_markdown_structure("SPEC.md", text), [])

    def test_empty_amendment_or_history_row_reports_a_failure(self):
        for heading in ("Material amendments", "Amendment history"):
            with self.subTest(heading=heading):
                text = ("## " + heading + "\n\n| ID | Prior meaning | Current amendment | Content digest |\n"
                        "| --- | --- | --- | --- |\n|\n")
                self.assertTrue(check.check_amendments("", text, {}, baseline_index_text=""))

    def test_wrong_declaration_table_header_is_rejected(self):
        for heading in ("Material amendments", "Amendment history"):
            with self.subTest(heading=heading):
                text = ("## " + heading + "\n\n| invented | Fake prior | Fake current | " + "a" * 64
                        + " |\n| --- | --- | --- | --- |\n")
                self.assertTrue(check.check_amendments("", text, {}))

    def test_missing_dependencies_report_the_install_command(self):
        result = subprocess.run([sys.executable, "-S", check.__file__], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pip install -r", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_gfm_code_span_pipe_still_splits_cells(self):
        self.assertEqual(check.split_cells("| A | `x|y` |"), ["A", "`x", "y`"])


if __name__ == "__main__":
    unittest.main()
