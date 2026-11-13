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


if __name__ == "__main__":
    unittest.main()
