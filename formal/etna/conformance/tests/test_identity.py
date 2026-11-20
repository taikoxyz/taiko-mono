"""Actual identity receipt completeness, provenance and observer regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_identity", ROOT / "export_identity.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


class IdentityExportTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "identity_cases.json").read_text())

    def rehash(self, data):
        data["content_sha256"] = export.content_digest(data)
        return data

    def test_valid_twenty_actual_scenarios(self):
        export.validate(self.fixture())

    def test_exported_corpus_reaches_required_witnesses(self):
        cases = {case["id"]: case for case in self.fixture()["cases"]}
        for field in export.FIELDS:
            self.assertFalse(cases[field + "/Frontier"]["steps"][-1]["accepted"])
            self.assertFalse(cases[field + "/Origin"]["steps"][-1]["accepted"])
            self.assertTrue(cases[field + "/Compatible"]["steps"][-1]["after"]["audit"]["goodOverlap"])
            self.assertTrue(cases[field + "/Divergent"]["steps"][-1]["after"]["audit"]["divergentSuffix"])
            recovered = cases[field + "/Recovery"]["steps"]
            self.assertFalse(recovered[-2]["accepted"])
            self.assertTrue(recovered[-1]["accepted"])
            self.assertTrue(recovered[-1]["after"]["audit"]["reusedOrigin"])

    def test_missing_supplied_cut_rejected_after_rehash(self):
        data = self.fixture()
        del data["cases"][0]["steps"][1]["cuts"]["1"]
        with self.assertRaisesRegex(ValueError, "supplied cuts"):
            export.validate(self.rehash(data))

    def test_missing_frontier_case_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"] = [c for c in data["cases"] if c["id"] != "FI/Frontier"]
        with self.assertRaisesRegex(ValueError, "missing/duplicate"):
            export.validate(self.rehash(data))

    def test_duplicate_recovery_case_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"][-1] = copy.deepcopy(data["cases"][0])
        with self.assertRaisesRegex(ValueError, "missing/duplicate"):
            export.validate(self.rehash(data))

    def test_skipped_intermediate_action_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"][0]["steps"].pop(1)
        with self.assertRaisesRegex(ValueError, "skipped"):
            export.validate(self.rehash(data))

    def test_field_relabel_rejected(self):
        data = self.fixture()
        data["cases"][0]["field"] = "Val"
        with self.assertRaisesRegex(ValueError, "identity"):
            export.validate(self.rehash(data))

    def test_rehashed_frontier_outcome_cannot_replace_actual_execution(self):
        actual = self.fixture()
        data = copy.deepcopy(actual)
        case = next(c for c in data["cases"] if c["id"] == "Comet/Frontier")
        case["steps"][-1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(data))

    def test_rehashed_retained_validator_identity_cannot_replace_actual_execution(self):
        actual = self.fixture()
        data = copy.deepcopy(actual)
        case = next(c for c in data["cases"] if c["id"] == "Val/Recovery")
        case["steps"][-1]["after"]["records"]["1"]["cut"]["val"][3] = "Other"
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(data))

    def test_wrong_model_provenance_rejected(self):
        data = self.fixture()
        data["provenance"]["model_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "provenance"):
            export.validate(self.rehash(data))

    def test_unexhausted_model_rejected(self):
        with self.assertRaisesRegex(ValueError, "did not exhaust"):
            export.parse_receipts("Model checking completed. No error has been found.", "EL", 1)

    def test_source_parser_or_jar_drift_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            base, model, parser, jar = [work / name for name in ("EtnaSettlement.tla", "EtnaCheckpointIdentity.tla", "parser.py", "tools.jar")]
            for path in [base, model, parser, jar]:
                path.write_bytes(b"original")
            for changed in [base, model, parser, jar]:
                def drift(*args, **kwargs):
                    changed.write_bytes(b"changed")
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                with self.subTest(changed=changed.name), \
                     mock.patch.object(export, "BASE", base), mock.patch.object(export, "MODEL", model), \
                     mock.patch.object(export, "PARSER_SOURCE", parser), \
                     mock.patch.object(export, "TLC_SHA", export.digest(jar.read_bytes())), \
                     mock.patch.object(export.subprocess, "run", side_effect=drift):
                    with self.assertRaisesRegex(ValueError, "inputs changed"):
                        export.generate("/usr/bin/java", jar)
                changed.write_bytes(b"original")


if __name__ == "__main__":
    unittest.main()
