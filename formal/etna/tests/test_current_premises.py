"""Kernel replay of the complete accepting deployment and reference counterexample."""
from pathlib import Path
import subprocess
import importlib.util
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentPremisesTests(unittest.TestCase):
    def test_accepting_witness_is_mandatory(self):
        spec = importlib.util.spec_from_file_location('accepting_audit', ROOT/'scripts/audit_proofs.py')
        audit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(audit)
        manifest = json.loads((ROOT/'manifests/design.json').read_text())
        manifest['theorems'] = [entry for entry in manifest['theorems']
                                if entry['declaration'] != audit.CURRENT_ACCEPTING_WITNESS]
        with self.assertRaisesRegex(ValueError, audit.CURRENT_ACCEPTING_WITNESS):
            audit.validate_contract(manifest)

    def test_global_acceptance_and_before_after_reference_semantics(self):
        result = subprocess.run(
            ['lake', 'env', 'lean', 'tests/CurrentPremises.lean'],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')


if __name__ == '__main__':
    unittest.main()
