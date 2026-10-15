"""Run real Lean, including poisoned declarations, to exercise the proof trust gate."""
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'scripts' / 'audit_proofs.py'


class ProofAuditTests(unittest.TestCase):
    def audit(self, source, theorem='Fixture.sound', type_='∀ (n : Nat), n = n', imports=True):
        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
            path = pathlib.Path(tmp)
            module = path.name + '.Fixture'
            (path / 'Fixture.lean').write_text(source)
            manifest = {'schema_version': 1, 'theorems': [{
                'id': 'TEST-01', 'module': module if imports else '',
                'declaration': theorem, 'type': type_, 'assumptions': [],
                'bridge_level': 'spec-proved', 'production': [], 'tests': []}]}
            (path / 'manifest.json').write_text(json.dumps(manifest))
            return subprocess.run(['python3', str(AUDIT), '--manifest', str(path / 'manifest.json'),
                                   '--output', str(path / 'Audit.lean')], cwd=ROOT,
                                  text=True, capture_output=True)

    def test_accepts_kernel_checked_theorem(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_deleted_theorem(self):
        result = self.audit('namespace Fixture\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unknown constant `Fixture.sound`', result.stderr)

    def test_rejects_sorry(self):
        result = self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := by sorry\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('sorryAx', result.stderr)

    def test_rejects_transitive_custom_axiom(self):
        result = self.audit('namespace Fixture\naxiom injected : ∀ (n : Nat), n = n\ntheorem sound (n : Nat) : n = n := injected n\nend Fixture\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Fixture.injected', result.stderr)

    def test_rejects_missing_import(self):
        self.assertNotEqual(self.audit('namespace Fixture\ntheorem sound (n : Nat) : n = n := rfl\nend Fixture\n', imports=False).returncode, 0)

    def test_rejects_hidden_default_premise(self):
        result = self.audit('namespace Fixture\ntheorem sound (h : True := by trivial) : True := h\nend Fixture\n', type_='True')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('full type mismatch', result.stderr)

    def test_rejects_hidden_implicit_premise(self):
        result = self.audit('namespace Fixture\ntheorem sound {h : True} : True := h\nend Fixture\n', type_='True')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_changed_full_type(self):
        self.assertNotEqual(self.audit('namespace Fixture\ntheorem sound (n : Nat) (h : n = n) : n = n := h\nend Fixture\n').returncode, 0)


if __name__ == '__main__':
    unittest.main()
