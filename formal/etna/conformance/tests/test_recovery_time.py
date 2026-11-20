"""Receipt identity, raw-premise preservation and fresh-output comparison checks."""
import copy
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("export_recovery_time", ROOT / "export_recovery_time.py")
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


class RecoveryTimeTests(unittest.TestCase):
    def fixture(self):
        return json.loads((ROOT / "recovery_time_cases.json").read_text())

    def rehash(self, data):
        data["content_sha256"] = export.content_digest(data)
        return data

    def test_valid_three_actual_observations(self):
        data = self.fixture()
        export.validate(data)
        self.assertEqual({c["id"]: (c["observation"]["header"]["bftTime"],
                                    c["observation"]["header"]["elTimestamp"])
                          for c in data["cases"]},
                         {"equal-times": (3, 3), "parent-dominates": (3, 4), "later-anchor": (3, 4)})

    def test_missing_duplicate_and_unexpected_cases_rejected(self):
        for change in (lambda c: c.pop(), lambda c: c.__setitem__(0, c[1]),
                       lambda c: c[0].__setitem__("id", "unexpected")):
            data = self.fixture()
            change(data["cases"])
            with self.assertRaisesRegex(ValueError, "missing/duplicate"):
                export.validate(self.rehash(data))

    def test_unhashed_change_rejected(self):
        data = self.fixture()
        data["cases"][0]["observation"]["header"]["elTimestamp"] += 1
        with self.assertRaisesRegex(ValueError, "changed observations"):
            export.validate(data)

    def test_rehashed_changes_to_each_clock_and_raw_premise_fail_fresh_comparison(self):
        actual = self.fixture()
        paths = [("header", "bftTime"), ("header", "elTimestamp"), ("header", "generation"),
                 ("raw", "generation"), ("raw", "parent", "height"),
                 ("raw", "parent", "elTimestamp"), ("raw", "origin", "height"),
                 ("raw", "origin", "l1Number"), ("raw", "origin", "l1Timestamp"),
                 ("raw", "anchor", "l1Number"), ("raw", "anchor", "l1Timestamp")]
        for case in range(3):
            for path in paths:
                with self.subTest(case=case, path=path):
                    data = copy.deepcopy(actual)
                    target = data["cases"][case]["observation"]
                    for part in path[:-1]:
                        target = target[part]
                    target[path[-1]] += 1
                    with self.assertRaisesRegex(ValueError, "differs from actual"):
                        export.compare_fixture(actual, self.rehash(data))

    def test_missing_raw_and_header_fields_rejected_after_rehash(self):
        for section, field in (("raw", "origin"), ("header", "bftTime"), ("header", "elTimestamp")):
            data = self.fixture()
            del data["cases"][0]["observation"][section][field]
            with self.assertRaisesRegex(ValueError, "observation fields"):
                export.validate(self.rehash(data))

    def test_every_provenance_component_is_checked(self):
        for key in self.fixture()["provenance"]:
            data = self.fixture()
            data["provenance"][key] = "substituted"
            with self.assertRaisesRegex(ValueError, "provenance"):
                export.validate(self.rehash(data))

    def test_raw_parser_requires_all_three_unique_receipts_and_exhaustion(self):
        log = 'Model checking completed. No error has been found.\n0 states left on queue.\n'
        rows = ['<<"ETNA_RECOVERY_TIME", "%s", [present |-> TRUE]>>\n' % name
                for name in sorted(export.REQUIRED)]
        self.assertEqual(len(export.parse_receipts(log + ''.join(rows))), 3)
        for bad in (log + ''.join(rows[:-1]), log + ''.join(rows) + rows[0],
                    ''.join(rows), log + ''.join(rows) + 'Error: unrelated\n'):
            with self.assertRaises(ValueError):
                export.parse_receipts(bad)

    def test_source_edit_during_execution_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            paths = {name: work / name for name in ("model", "config", "parser", "pins", "exporter")}
            for p in paths.values():
                p.write_text("original")
            jar = work / "tools.jar"
            jar.write_bytes(b"tool")
            def drift(*args, **kwargs):
                paths["model"].write_text("changed")
                return SimpleNamespace(returncode=0, stdout="", stderr="")
            with mock.patch.object(export, "INPUTS", tuple(paths.values())), \
                 mock.patch.object(export, "MODEL", paths["model"]), \
                 mock.patch.object(export, "CONFIG", paths["config"]), \
                 mock.patch.object(export, "TLC_SHA", export.digest(jar.read_bytes())), \
                 mock.patch.object(export.subprocess, "run", side_effect=drift):
                with self.assertRaisesRegex(ValueError, "inputs changed"):
                    export.generate("/usr/bin/java", jar)


if __name__ == "__main__":
    unittest.main()
