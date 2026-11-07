"""Exercise the resource gate when the child finishes between polling observations."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
import checkpoint_import_resources as bench


class CompletedPhaseDeadline(unittest.TestCase):
    def run_reaped(self, elapsed):
        wait4 = os.wait4
        with tempfile.TemporaryDirectory() as directory:
            # Reap the real child on the first poll. Simulate the parent being descheduled
            # until the exact deadline or until just beyond it (both round to 600.000).
            with patch.object(bench.os, "wait4", lambda pid, _: wait4(pid, 0)), \
                 patch.object(bench.time, "monotonic", side_effect=[100.0, 100.0 + elapsed]):
                return bench.measure("verify", [sys.executable, "-c", "pass"],
                                     Path(directory), os.environ)

    def test_exact_deadline(self):
        self.assertEqual(self.run_reaped(600), "")

    def test_over_deadline_despite_rounding(self):
        with self.assertRaisesRegex(RuntimeError, "exceeded the predeclared 600 second limit"):
            self.run_reaped(600.0001)


if __name__ == "__main__":
    unittest.main()
