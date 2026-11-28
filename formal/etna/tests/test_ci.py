"""Behavioral controls for the complete, fresh, exact-outcome CI gate."""

import contextlib
import hashlib
import io
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("etna_ci", ROOT / "ci.py")
CI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CI)


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "repo" / "formal" / "etna"
        (self.root / "configs").mkdir(parents=True)
        (self.root / "EtnaSettlement.tla").write_text("---- MODULE EtnaSettlement ----\n====\n")
        self.add_config("positive", "PASS")
        self.add_config("negative", "INVARIANT DeliberateViolation")
        shutil.copyfile(ROOT / "check.py", self.root / "check.py")
        for suite in ("tests", "conformance/tests", "sensitivity/tests"):
            directory = self.root / suite
            directory.mkdir(parents=True)
            (directory / "test_sample.py").write_text(
                "import unittest\nclass Sample(unittest.TestCase):\n"
                " def test_sample(self): self.assertTrue(True)\n"
            )
        rules = self.root.parents[1] / "packages/protocol/docs/etna/rules/tools"
        rules.mkdir(parents=True)
        (rules / "check.py").write_text("print('rules checked')\n")
        self.jar = self.base / "tla2tools.jar"
        self.jar.write_bytes(b"disposable fake tool")
        self.java = self.base / "java"
        self.java.write_text(
            "#!" + sys.executable + "\n"
            "import pathlib,re,sys\n"
            "config=pathlib.Path(sys.argv[sys.argv.index('-config')+1])\n"
            "text=config.read_text()\n"
            "assert '-workers' in sys.argv and '-metadir' in sys.argv\n"
            "pathlib.Path(__file__).with_suffix('.called').write_text('called')\n"
            "if 'EXPECT: PASS' in text:\n"
            " print('Model checking completed. No error has been found.')\n"
            " code=0\n"
            "else:\n"
            " name=re.search(r'EXPECT: INVARIANT (\\w+)',text)[1]\n"
            " print('Error: Invariant '+name+' is violated.')\n"
            " code=12\n"
            "print('3 states generated, 2 distinct states found, 0 states left on queue.')\n"
            "sys.exit(code)\n"
        )
        self.java.chmod(0o755)
        self.output = self.base / "output"

    def add_config(self, name, expected):
        (self.root / "configs" / (name + ".cfg")).write_text("\\* EXPECT: " + expected + "\n")

    def run_gate(self, pin_fake=True):
        digest = hashlib.sha256(self.jar.read_bytes()).hexdigest() if pin_fake else CI.TLC_SHA256
        with mock.patch.object(CI, "TLC_SHA256", digest), contextlib.redirect_stdout(io.StringIO()):
            code = CI.run_gate(self.root, str(self.java), self.jar, self.output)
        return code, json.loads((self.output / "summary.json").read_text())

    def corrupt_checker(self, statement):
        path = self.root / "check.py"
        text = path.read_text().replace(
            "sys.exit(main())",
            "code = main()\n    "
            "result_path = next(args_path.glob('etna-tlc-*/results.json'))\n    "
            "rows = json.loads(result_path.read_text())\n    " + statement + "\n    "
            "result_path.write_text(json.dumps(rows))\n    sys.exit(code)",
        )
        text = text.replace("code = main()", "args_path = Path(sys.argv[sys.argv.index('--output-dir') + 1])\n    code = main()")
        path.write_text(text)

    def test_all_discovered_configs_and_all_child_statuses_are_required(self):
        self.add_config("additional", "PASS")
        code, summary = self.run_gate()
        self.assertEqual(code, 0, summary)
        self.assertTrue(summary["ok"])
        self.assertEqual(summary["cases"], ["additional", "negative", "positive"])
        self.assertEqual(len(summary["children"]), 5)
        for child in summary["children"][1:4]:
            self.assertEqual(child.get("tests"), {"discovered": 1, "run": 1, "skipped": 0,
                                            "errors": 0, "failures": 0, "successful": True})
        self.assertTrue(all(child["returncode"] == 0 for child in summary["children"]))
        self.assertTrue(all((self.output / child["log"]).is_file() for child in summary["children"]))

    def test_prefix_related_config_names_cover_every_identity(self):
        self.add_config("positive-extended", "PASS")
        code, summary = self.run_gate()
        self.assertEqual(code, 0, summary)
        self.assertEqual(set(summary["cases"]), {"negative", "positive", "positive-extended"})

    def test_wrong_tool_hash_refuses_execution(self):
        code, summary = self.run_gate(pin_fake=False)
        self.assertNotEqual(code, 0)
        self.assertFalse(summary["ok"])
        self.assertFalse(self.java.with_suffix(".called").exists())
        self.assertIn("SHA256", " ".join(summary["errors"]))

    def test_failed_python_child_refuses_gate(self):
        (self.root / "tests/test_sample.py").write_text("raise RuntimeError('intentional child failure')\n")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertFalse(summary["ok"])
        self.assertTrue(any(child["returncode"] != 0 for child in summary["children"]))

    def test_empty_python_suite_is_not_success(self):
        (self.root / "tests/test_sample.py").unlink()
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("required child failed: python", summary["errors"])

    def test_all_skipped_python_suite_is_not_success(self):
        (self.root / "tests/test_sample.py").write_text(
            "import unittest\n@unittest.skip('intentional skipped-only control')\n"
            "class Sample(unittest.TestCase):\n def test_sample(self): pass\n"
        )
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("required child failed: python", summary["errors"])

    def test_mixed_skipped_python_suite_is_not_success(self):
        path = self.root / "tests/test_sample.py"
        path.write_text(path.read_text() +
                        "@unittest.skip('intentional mixed-skip control')\n"
                        "class Skipped(unittest.TestCase):\n def test_skipped(self): pass\n")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("required child failed: python", summary["errors"])

    def test_early_success_exit_without_test_counts_is_not_success(self):
        (self.root / "tests/test_sample.py").write_text("import os; os._exit(0)\n")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertEqual(summary["children"][1]["returncode"], 0)
        self.assertIn("invalid Python test counts", " ".join(summary["errors"]))

    def test_empty_default_set_is_not_success(self):
        for path in (self.root / "configs").glob("*.cfg"):
            path.unlink()
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertFalse(summary["ok"])
        self.assertFalse(self.java.with_suffix(".called").exists())

    def test_omitted_result_is_not_success(self):
        self.corrupt_checker("rows.pop()")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("coverage", " ".join(summary["errors"]))

    def test_duplicate_result_cannot_replace_missing_identity(self):
        self.corrupt_checker("rows[-1] = rows[0]")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("coverage", " ".join(summary["errors"]))

    def test_missing_results_file_is_not_success(self):
        path = self.root / "check.py"
        path.write_text("print('no results')\n")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("results.json", " ".join(summary["errors"]))

    def test_missing_log_is_not_success(self):
        self.corrupt_checker("(result_path.parent / rows[0]['log']).unlink()")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertFalse(summary["ok"])

    def test_claimed_ok_cannot_bypass_actual_outcome(self):
        self.corrupt_checker("rows[0]['returncode'] = 0")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("outcome", " ".join(summary["errors"]))

    def test_config_hash_must_match_executed_input(self):
        self.corrupt_checker("rows[0]['config_sha256'] = '0' * 64")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertFalse(summary["ok"])

    def test_nonzero_checker_status_cannot_be_hidden_by_valid_results(self):
        self.corrupt_checker("code = 17")
        code, summary = self.run_gate()
        self.assertNotEqual(code, 0)
        self.assertIn("required child failed: tlc", summary["errors"])
        self.assertEqual(summary["children"][0]["returncode"], 17)

    def test_child_timeout_records_failure_and_log(self):
        self.output.mkdir()
        child = CI.run_child("slow", [sys.executable, "-c", "import time; time.sleep(20)"],
                             self.root, self.output, 0.1)
        self.assertIsNone(child["returncode"])
        self.assertIn("CI CHILD TIMEOUT", (self.output / child["log"]).read_text())

    def test_stale_output_is_refused_and_preserved(self):
        code, _ = self.run_gate()
        self.assertEqual(code, 0)
        original = (self.output / "summary.json").read_bytes()
        with self.assertRaises(FileExistsError):
            self.run_gate()
        self.assertEqual((self.output / "summary.json").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
