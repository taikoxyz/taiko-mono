"""Lifecycle receipt completeness, drift and independent expectation regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_lifecycle", ROOT / "export_recovery_lifecycle.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


class LifecycleExportTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "recovery_lifecycle_cases.json").read_text())

    def rehash(self, data):
        data["content_sha256"] = export.content_digest(data)
        return data

    def test_valid_eight_actual_receipts(self):
        export.validate(self.fixture())

    def test_skipped_case_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"].pop()
        with self.assertRaisesRegex(ValueError, "missing/duplicate"):
            export.validate(self.rehash(data))

    def test_duplicate_case_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"][-1] = copy.deepcopy(data["cases"][0])
        with self.assertRaisesRegex(ValueError, "missing/duplicate"):
            export.validate(self.rehash(data))

    def test_profile_relabel_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"][0]["profile"] = "Withdrawn"
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            export.validate(self.rehash(data))

    def test_rehashed_confirmation_observer_mutation_fails_fresh_comparison(self):
        actual = self.fixture()
        data = copy.deepcopy(actual)
        data["cases"][0]["attempt"]["after"]["state"]["bonds"]["0"]["confirmed"] = 96
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(data))

    def test_rehashed_withdrawn_expected_effect_mutation_fails_fresh_comparison(self):
        actual = self.fixture()
        data = copy.deepcopy(actual)
        data["cases"][4]["attempt"]["after"]["state"]["bonds"]["0"]["withdrawn"] = False
        with self.assertRaisesRegex(ValueError, "differs from actual"):
            export.compare_fixture(actual, self.rehash(data))

    def test_wrong_frozen_source_pin_rejected(self):
        data = self.fixture()
        data["provenance"]["model_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "provenance"):
            export.validate(self.rehash(data))

    def test_callback_cannot_be_silently_claimed(self):
        data = self.fixture()
        data["cases"][0]["attempt"]["injection"]["callback"] = "Registry"
        with self.assertRaisesRegex(ValueError, "callback"):
            export.validate(self.rehash(data))

    def test_incomplete_tlc_execution_rejected(self):
        with self.assertRaisesRegex(ValueError, "did not exhaust"):
            export.parse_receipts("Model checking completed. No error has been found.", "Displaced")

    def test_parser_never_evaluates_code(self):
        with self.assertRaises(ValueError):
            export.ValueParser('__import__("os")').value()

    def test_source_or_config_drift_during_execution_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            base, model, jar = [work / name for name in ("EtnaSettlement.tla", "EtnaRecoveryTransaction.tla", "tools.jar")]
            configs = {profile: work / (profile + ".cfg") for profile in export.PROFILES}
            for path in [base, model, jar, *configs.values()]:
                path.write_bytes(b"original")
            for changed in [base, model, *configs.values(), jar]:
                def drift(*args, **kwargs):
                    changed.write_bytes(b"changed")
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                with self.subTest(changed=changed.name), \
                     mock.patch.object(export, "BASE", base), mock.patch.object(export, "MODEL", model), \
                     mock.patch.object(export, "CONFIGS", configs), \
                     mock.patch.object(export, "TLC_SHA", export.digest(jar.read_bytes())), \
                     mock.patch.object(export.subprocess, "run", side_effect=drift):
                    with self.assertRaisesRegex(ValueError, "inputs changed"):
                        export.generate("/usr/bin/java", jar)
                changed.write_bytes(b"original")


if __name__ == "__main__":
    unittest.main()
