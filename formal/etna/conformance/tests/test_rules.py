"""Actual-receipt completeness, source drift, fresh comparison and mapping regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_rules", ROOT / "export_rules.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


class RulesExportTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "rules_cases.json").read_text())

    def rehash(self, data):
        data["content_sha256"] = export.content_digest(data)
        return data

    def test_actual_38_calls_23_programs_validate(self):
        data = self.fixture()
        export.validate(data)
        self.assertEqual(len({x["attempt"]["program"] for x in data["cases"]}), 23)

    def test_missing_or_duplicate_case_rejected_after_rehash(self):
        for duplicate in (False, True):
            data = self.fixture()
            if duplicate:
                data["cases"][-1] = copy.deepcopy(data["cases"][0])
            else:
                data["cases"].pop()
            with self.subTest(duplicate=duplicate), self.assertRaisesRegex(ValueError, "missing/duplicate"):
                export.validate(self.rehash(data))

    def test_original_program_index_cannot_be_relabelled(self):
        data = self.fixture()
        data["cases"][0]["attempt"]["index"] = 8
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            export.validate(self.rehash(data))

    def test_five_field_schedule_cannot_be_truncated(self):
        data = self.fixture()
        del data["cases"][0]["attempt"]["after"]["schedule"]["stopGrid"]
        with self.assertRaisesRegex(ValueError, "five-field"):
            export.validate(self.rehash(data))

    def test_wrong_1200_scale_rejected(self):
        data = self.fixture()
        data["mapping"]["timestamp_scale"] = 1200
        with self.assertRaisesRegex(ValueError, "time mapping"):
            export.validate(self.rehash(data))

    def test_cancel_sentinel_cannot_be_mapped_as_unix_time(self):
        data = self.fixture()
        data["mapping"]["cancellation_uint48"] = 100000 + 1152 * 99
        with self.assertRaisesRegex(ValueError, "time mapping"):
            export.validate(self.rehash(data))

    def test_original_argument_mutation_detected_by_fresh_execution_comparison(self):
        actual = self.fixture()
        changed = copy.deepcopy(actual)
        changed["cases"][0]["attempt"]["args"]["grid"] += 6
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(changed))

    def test_rehashed_packed_event_mutation_detected_by_fresh_comparison(self):
        actual = self.fixture()
        changed = copy.deepcopy(actual)
        changed["cases"][0]["attempt"]["scheduleEvent"]["limbs"][1] += 1
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(changed))

    def test_changed_executed_prestate_breaks_program_continuity(self):
        data = self.fixture()
        row = next(x for x in data["cases"] if x["id"] == "Promote/2")
        row["attempt"]["before"]["schedule"]["activeRules"] = 99
        with self.assertRaisesRegex(ValueError, "continuity"):
            export.validate(self.rehash(data))

    def test_source_or_parser_provenance_cannot_drift(self):
        for field in ("model_sha256", "parser_sha256", "contracts_manifest_sha256", "source_config_sha256"):
            data = self.fixture()
            data["provenance"][field] = "0" * 64
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "provenance"):
                export.validate(self.rehash(data))

    def test_incomplete_or_erroring_tlc_log_rejected(self):
        for log in ("", "Model checking completed. No error has been found.",
                    "Model checking completed. No error has been found.\n0 states left on queue.\nError: drift"):
            with self.subTest(log=log), self.assertRaisesRegex(ValueError, "did not exhaust"):
                export.parse_receipts(log)

    def test_parser_never_evaluates_input(self):
        with self.assertRaises(ValueError):
            export.ValueParser('__import__("os")').value()

    def test_every_frozen_input_drift_during_execution_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            names = ("BASE", "MODEL", "CONFIG", "PARSER_SOURCE", "PINS", "CONTRACT_MANIFEST")
            files = {name: work / (name + ".txt") for name in names}
            jar = work / "tools.jar"
            for p in [*files.values(), jar]:
                p.write_bytes(b"original")
            for changed in [*files.values(), jar]:
                def drift(*args, **kwargs):
                    changed.write_bytes(b"changed")
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                with self.subTest(changed=changed.name), mock.patch.multiple(export, **files), \
                     mock.patch.object(export, "TLC_SHA", export.digest(jar.read_bytes())), \
                     mock.patch.object(export.subprocess, "run", side_effect=drift):
                    with self.assertRaisesRegex(ValueError, "inputs changed"):
                        export.generate("/usr/bin/java", jar)
                changed.write_bytes(b"original")


if __name__ == "__main__":
    unittest.main()
