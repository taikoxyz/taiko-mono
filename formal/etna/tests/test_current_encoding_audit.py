"""Exact kernel-type audit retains genuine polymorphic encoding contracts."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('encoding_audit', ROOT/'scripts/audit_proofs.py')
AUDIT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(AUDIT)


class EncodingAuditTests(unittest.TestCase):
    def setUp(self):
        self.entry = next(copy.deepcopy(e) for e in json.loads((ROOT/'manifests/design.json').read_text())['theorems']
                          if e['declaration'] == 'Etna.Design.Current.Encoding.relabel_injective')

    def check(self):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(AUDIT.render_audit([self.entry], complete=False))
            file.flush()
            return AUDIT.check_kernel_file(file.name)

    def test_polymorphic_contract_keeps_actual_level_parameters(self):
        output = self.check()
        self.assertIn('derivation chain: '+self.entry['declaration'], output)

    def test_monomorphic_replacement_is_not_the_full_contract(self):
        self.assertIn('Type u_1', self.entry['type'])
        self.entry['type'] = self.entry['type'].replace('Type u_1', 'Type')
        with self.assertRaisesRegex(ValueError, 'full theorem type mismatch'):
            self.check()

    def test_undeclared_level_is_not_silently_bound(self):
        self.entry['type'] = self.entry['type'].replace('u_1', 'unreviewed_level')
        with self.assertRaisesRegex(ValueError, 'unknown universe level'):
            self.check()


if __name__ == '__main__':
    unittest.main()
