"""Kernel-recheck deployment substitution and stored-occupant signature regressions."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('audit', ROOT/'scripts/audit_proofs.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class ReviewFixTests(unittest.TestCase):
    def test_deployment_and_evidence_traces(self):
        audit.check_kernel_file(ROOT/'tests/ReviewFixes.lean')
