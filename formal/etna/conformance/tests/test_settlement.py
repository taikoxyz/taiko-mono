"""Checks the exported TLC receipt parser and frozen expectation integrity."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock
import tempfile
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_settlement", ROOT / "export_settlement.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


class SettlementExportTests(unittest.TestCase):
    def test_requires_successful_exhaustion(self):
        with self.assertRaises(ValueError):
            export.parse_receipts('<< "ETNA_SETTLEMENT", 1, 0 >>')

    def test_fixture_is_integrity_checked(self):
        data = json.loads((ROOT / "settlement_cases.json").read_text())
        export.validate(data)
        broken = copy.deepcopy(data)
        broken["cases"][0]["steps"][1]["accepted"] = False
        with self.assertRaises(ValueError):
            export.validate(broken)

    def test_missing_step_rejected_even_with_new_digest(self):
        data = json.loads((ROOT / "settlement_cases.json").read_text())
        data["cases"][0]["steps"].pop()
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.validate(data)

    def test_wrong_provenance_rejected(self):
        data = json.loads((ROOT / "settlement_cases.json").read_text())
        data["provenance"]["base_sha256"] = "0" * 64
        data["content_sha256"] = export.content_digest(data)
        with self.assertRaises(ValueError):
            export.validate(data)

    def test_changed_outcome_rejected_after_digest_recalculation(self):
        original = json.loads((ROOT / "settlement_cases.json").read_text())
        changed = copy.deepcopy(original)
        changed["cases"][0]["steps"][1]["accepted"] = False
        changed["content_sha256"] = export.content_digest(changed)
        with self.assertRaises(ValueError):
            export.compare_fixture(original, changed)

    def test_concurrent_model_edit_cannot_be_stamped_as_tested(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "EtnaSettlement.tla"
            model = Path(directory) / "EtnaSettlementReplay.tla"
            base.write_text("original base")
            model.write_text("original replay")
            def changed_input(*args, **kwargs):
                model.write_text("changed replay")
                return SimpleNamespace(returncode=0, stdout="", stderr="")
            with mock.patch.object(export, "BASE", base), mock.patch.object(export, "MODEL", model), \
                    mock.patch.object(export, "sha", return_value=export.TLC_SHA256), \
                    mock.patch.object(export.subprocess, "run", side_effect=changed_input):
                with self.assertRaisesRegex(ValueError, "inputs changed"):
                    export.generate("/usr/bin/java", Path(directory) / "tools.jar")

    def test_duplicate_receipt_rejected(self):
        text = 'Model checking completed. No error has been found.\n0 states left on queue.\n'
        row = '<< "ETNA_SETTLEMENT",1,0,0,0,TRUE,0,0,0,0,0,<<FALSE,0,0,0,0>>,<<FALSE,0,0,0>>,<< >> >>\n'
        with self.assertRaises(ValueError):
            export.parse_receipts(text + row + row)


if __name__ == "__main__":
    unittest.main()
