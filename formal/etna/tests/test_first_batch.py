"""Kernel-checked positive and rejection traces for the composed design model."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FirstBatchTests(unittest.TestCase):
    def test_design_traces(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/FirstBatch.lean'],
                                cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
