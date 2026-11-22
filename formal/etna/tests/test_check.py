"""Tests for accepting actual TLC outcomes, not merely finding an error string."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
from unittest import mock
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "etna_check", Path(__file__).resolve().parents[1] / "check.py"
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)

PASS = (
    "Model checking completed. No error has been found.\n"
    "123 states generated, 45 distinct states found, 0 states left on queue.\n"
)
VIOLATION = (
    "Error: Invariant NoStaleCheckpointRecovery is violated.\n"
    "Error: The behavior up to this point is:\n"
    "12 states generated, 9 distinct states found, 2 states left on queue.\n"
)


class OutcomeTests(unittest.TestCase):
    def test_completed_baseline_is_accepted(self):
        self.assertTrue(CHECK.classify_output(0, PASS, "PASS"))

    def test_nonzero_exit_never_passes_baseline(self):
        self.assertFalse(CHECK.classify_output(1, PASS, "PASS"))

    def test_partial_or_incomplete_search_does_not_pass(self):
        self.assertFalse(CHECK.classify_output(0, "No error has been found.", "PASS"))
        self.assertFalse(CHECK.classify_output(0, PASS.replace("0 states left", "3 states left"), "PASS"))

    def test_expected_invariant_violation_is_accepted(self):
        self.assertTrue(CHECK.classify_output(12, VIOLATION, "NoStaleCheckpointRecovery"))

    def test_another_invariant_does_not_satisfy_negative_control(self):
        self.assertFalse(CHECK.classify_output(12, VIOLATION, "NoExpiredRecovery"))

    def test_parser_failure_does_not_satisfy_negative_control(self):
        output = "Parsing or semantic analysis failed.\n" + VIOLATION
        self.assertFalse(CHECK.classify_output(150, output, "NoStaleCheckpointRecovery"))

    def test_runtime_exception_does_not_satisfy_negative_control(self):
        output = VIOLATION + "Error: TLC threw an unexpected exception.\n"
        self.assertFalse(CHECK.classify_output(12, output, "NoStaleCheckpointRecovery"))

    def test_error_is_not_accepted_as_baseline_success(self):
        self.assertFalse(CHECK.classify_output(0, PASS + VIOLATION, "PASS"))


class ConfigurationTests(unittest.TestCase):
    def test_pass_expectation(self):
        self.assertEqual(CHECK.parse_expectation("\\* EXPECT: PASS\nINIT Init\n"), "PASS")

    def test_invariant_expectation(self):
        self.assertEqual(
            CHECK.parse_expectation("\\* EXPECT: INVARIANT NoExpiredRecovery\n"),
            "NoExpiredRecovery",
        )

    def test_missing_or_duplicate_expectation_is_rejected(self):
        for text in ("INIT Init\n", "\\* EXPECT: PASS\n\\* EXPECT: PASS\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                CHECK.parse_expectation(text)

class ModuleSelectionTests(unittest.TestCase):
    def test_legacy_configuration_selects_original_module(self):
        self.assertEqual(CHECK.parse_module("\\* EXPECT: PASS\n"), "EtnaSettlement")

    def test_explicit_configuration_selects_composed_module(self):
        self.assertEqual(
            CHECK.parse_module("\\* MODULE: EtnaCheckpointIdentity\n"),
            "EtnaCheckpointIdentity",
        )

    def test_invalid_module_never_falls_back_to_original_model(self):
        for name in ("../EtnaSettlement", "/etc/passwd", "Model.tla", "", "A B"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                CHECK.parse_module("\\* MODULE: " + name + "\n")

    def test_duplicate_module_is_rejected(self):
        with self.assertRaises(ValueError):
            CHECK.parse_module("\\* MODULE: First\n\\* MODULE: Second\n")

    def test_missing_module_is_rejected_before_execution(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                CHECK.resolve_module("\\* MODULE: Missing\n", Path(directory))

    def test_selected_module_must_be_a_local_file(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module = root / "EtnaCheckpointIdentity.tla"
            module.write_text("---- MODULE EtnaCheckpointIdentity ----\n====\n")
            self.assertEqual(
                CHECK.resolve_module("\\* MODULE: EtnaCheckpointIdentity\n", root),
                module,
            )


class InputSnapshotTests(unittest.TestCase):
    def test_unchanged_inputs_keep_run_valid(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Model.tla"
            source.write_text("original model")
            self.assertTrue(CHECK.inputs_unchanged(CHECK.snapshot_inputs([source])))

    def test_edited_input_invalidates_run(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Model.tla"
            source.write_text("original model")
            snapshot = CHECK.snapshot_inputs([source])
            source.write_text("different model")
            self.assertFalse(CHECK.inputs_unchanged(snapshot))

    def test_removed_input_invalidates_run(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "Model.tla"
            source.write_text("original model")
            snapshot = CHECK.snapshot_inputs([source])
            source.unlink()
            self.assertFalse(CHECK.inputs_unchanged(snapshot))


class ConfigDirectoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.caller = Path(self.temporary.name)
        self.configs = self.caller / "selected"
        self.configs.mkdir()
        self.config = self.configs / "one.cfg"
        self.config.write_text("\\* EXPECT: PASS\n\\* MODULE: EtnaProvingProgress\n")
        self.jar = self.caller / "tools.jar"
        self.jar.write_bytes(b"test jar; never executed")
        self.output = self.caller / "results"
        self.arguments = ["--tlc-jar", str(self.jar), "--output-dir", str(self.output)]

    def run_checker(self, arguments, effect=None):
        previous = Path.cwd()
        os.chdir(self.caller)
        self.addCleanup(os.chdir, previous)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with mock.patch.object(CHECK.subprocess, "run", side_effect=effect) as run:
                result = CHECK.main(self.arguments + arguments)
        return result, run

    @staticmethod
    def passed(command, **kwargs):
        return CHECK.subprocess.CompletedProcess(command, 0, stdout=PASS.encode())

    def read_result(self):
        results, = self.output.glob("etna-tlc-*/results.json")
        result, = json.loads(results.read_text())
        return result

    def test_default_directory_stays_script_relative_from_other_cwd(self):
        result, run = self.run_checker(["--case", "baseline"], self.passed)
        self.assertEqual(result, 0)
        command = run.call_args.args[0]
        self.assertEqual(Path(command[command.index("-config") + 1]), CHECK.Path(CHECK.__file__).parent / "configs/baseline.cfg")
        self.assertEqual(len(list((Path(CHECK.__file__).parent / "configs").glob("*.cfg"))), 503)

    def test_relative_custom_directory_resolves_before_subprocess_cwd(self):
        # A config-adjacent module must never shadow the local model.
        (self.configs / "EtnaProvingProgress.tla").write_text("untrusted adjacent module")
        result, run = self.run_checker(["--config-dir", "selected", "--case", "one", "--case", "one"], self.passed)
        self.assertEqual(result, 0)
        self.assertEqual(run.call_count, 1)
        command = run.call_args.args[0]
        self.assertEqual(Path(command[command.index("-config") + 1]), self.config)
        self.assertEqual(Path(command[-1]), Path(CHECK.__file__).parent / "EtnaProvingProgress.tla")
        self.assertEqual(run.call_args.kwargs["cwd"], Path(CHECK.__file__).parent)
        result = self.read_result()
        self.assertEqual(result["module"], "EtnaProvingProgress")
        self.assertTrue(result["inputs_unchanged"])
        self.assertEqual(result["config_sha256"], CHECK.hashlib.sha256(self.config.read_bytes()).hexdigest())

    def test_relative_output_uses_caller_directory_and_cleans_actual_child_states(self):
        # Keep both possible destinations inside a disposable tree. The child
        # creates state relative to its actual cwd, just as TLC does.
        model_root = self.caller / "model"
        model_root.mkdir()
        module = model_root / "EtnaProvingProgress.tla"
        module.write_text("temporary local model; never executed")
        child_states = []

        def create_states_then_pass(command, *, cwd, **kwargs):
            requested = Path(command[command.index("-metadir") + 1])
            actual = (Path(cwd) / requested).resolve()
            actual.mkdir(parents=True)
            (actual / "state-file").write_bytes(b"temporary state database")
            child_states.append((requested, actual))
            return self.passed(command, **kwargs)

        with mock.patch.object(CHECK, "__file__", str(model_root / "check.py")):
            result, _ = self.run_checker(
                ["--config-dir", "selected", "--output-dir", "results"], create_states_then_pass)
        self.assertEqual(result, 0)
        requested, actual = child_states[0]
        self.assertTrue(requested.is_absolute())
        self.assertTrue(actual.is_relative_to(self.output))
        self.assertFalse(actual.exists())
        self.assertEqual(set(model_root.iterdir()), {module})
        report = self.read_result()
        self.assertTrue(report["ok"])
        log, = self.output.glob("etna-tlc-*/one/tlc.log")
        self.assertEqual(log.read_text(), PASS)

    def test_absolute_directory_is_selected(self):
        result, run = self.run_checker(["--config-dir", str(self.configs)], self.passed)
        self.assertEqual(result, 0)
        self.assertEqual(Path(run.call_args.args[0][-2]), self.config)

    def test_unknown_case_is_scoped_to_explicit_directory(self):
        with self.assertRaises(SystemExit) as error:
            self.run_checker(["--config-dir", "selected", "--case", "baseline"], self.passed)
        self.assertEqual(error.exception.code, 2)
        self.assertFalse(self.output.exists())

    def test_missing_empty_or_file_directory_does_not_fall_back(self):
        empty = self.caller / "empty"
        empty.mkdir()
        for directory in ("missing", "empty", str(self.config)):
            with self.subTest(directory=directory), self.assertRaises(SystemExit) as error:
                self.run_checker(["--config-dir", directory], self.passed)
            self.assertEqual(error.exception.code, 2)
        self.assertFalse(self.output.exists())

    def test_selected_config_edit_during_run_is_failure_with_original_identity(self):
        original = CHECK.hashlib.sha256(self.config.read_bytes()).hexdigest()
        def edit_then_pass(command, **kwargs):
            self.config.write_text(self.config.read_text() + "\\* actual change\n")
            return self.passed(command, **kwargs)
        result, _ = self.run_checker(["--config-dir", "selected"], edit_then_pass)
        self.assertEqual(result, 1)
        row = self.read_result()
        self.assertFalse(row["ok"])
        self.assertFalse(row["inputs_unchanged"])
        self.assertEqual(row["config_sha256"], original)
        log, = self.output.glob("etna-tlc-*/one/tlc.log")
        self.assertIn("CHECKER INPUT CHANGED", log.read_text())

    def test_explicit_bad_metadata_still_fails_before_execution(self):
        for text in ("\\* EXPECT: PASS\n\\* EXPECT: PASS\n",
                     "\\* EXPECT: PASS\n\\* MODULE: ../Outside\n",
                     "\\* EXPECT: PASS\n\\* MODULE: First\n\\* MODULE: Second\n"):
            self.config.write_text(text)
            with self.subTest(text=text), self.assertRaises(SystemExit):
                self.run_checker(["--config-dir", "selected"], self.passed)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
