"""Focused recovery receipt completeness/provenance regression tests."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock
from types import SimpleNamespace
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_recovery", ROOT / "export_recovery.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)

class RecoveryExportTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "recovery_cases.json").read_text())

    def test_valid_fixture(self):
        export.validate(self.fixture())

    def test_missing_case_rejected_after_rehash(self):
        data = self.fixture()
        data["cases"].pop()
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.validate(data)

    def test_wrong_model_pin_rejected(self):
        data = self.fixture()
        data["provenance"]["model_sha256"] = "0"*64
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.validate(data)

    def test_changed_real_expected_effect_rejected(self):
        original = self.fixture()
        data = copy.deepcopy(original)
        data["cases"][0]["attempt"]["after"]["nonce"] += 1
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.compare_fixture(original, data)

    def test_callback_not_silently_passed(self):
        data = self.fixture()
        data["cases"][0]["attempt"]["injection"]["callback"] = "Registry"
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.validate(data)

    def test_source_edit_during_execution_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)/"EtnaSettlement.tla"
            model = Path(directory)/"EtnaRecoveryTransaction.tla"
            config = Path(directory)/"held.cfg"
            jar = Path(directory)/"tools.jar"
            for item in [base,model,config,jar]:
                item.write_bytes(b"original")
            def drift(*args,**kwargs):
                model.write_text("changed")
                return SimpleNamespace(returncode=0,stdout="",stderr="")
            with mock.patch.object(export,"BASE",base),mock.patch.object(export,"MODEL",model), \
                 mock.patch.object(export,"CONFIG",config), \
                 mock.patch.object(export,"TLC_SHA",export.digest(jar.read_bytes())), \
                 mock.patch.object(export.subprocess,"run",side_effect=drift):
                with self.assertRaisesRegex(ValueError,"inputs changed"):
                    export.generate("/usr/bin/java",jar)

    def test_parser_never_evaluates_code(self):
        with self.assertRaises(ValueError):
            export.ValueParser('__import__("os")').value()

if __name__ == "__main__":
    unittest.main()
