"""All current premises and honest locking admit a real nonempty valid chain."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentAgreementTests(unittest.TestCase):
    def test_honest_profile_all_fourteen_premises_and_nonempty_agreement(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentAgreement.lean'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')


if __name__ == '__main__':
    unittest.main()
