"""Tests for accepting actual TLC outcomes, not merely finding an error string."""

import importlib.util
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


if __name__ == "__main__":
    unittest.main()
