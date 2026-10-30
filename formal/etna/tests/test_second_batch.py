"""Kernel-check the audited historical-context and mixed-protocol regression traces."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SecondBatchTests(unittest.TestCase):
    def test_historical_state_traces(self):
        result = subprocess.run(['lake','env','lean','tests/SecondBatch.lean'], cwd=ROOT,
                                text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
