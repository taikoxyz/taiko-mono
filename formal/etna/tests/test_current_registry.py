"""Permanent current-registry evidence must reject compilable semantic mutations."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    model = (ROOT / 'EtnaModel/CurrentRegistry.lean').read_text()
    proofs = (ROOT / 'EtnaProofs/CurrentRegistry.lean').read_text()
    fixture = (ROOT / 'tests/CurrentRegistry.lean').read_text()
    model = model.replace('RegistryMachine', 'RegistryMachineMutation')
    extra_imports = '\n'.join(line for line in proofs.splitlines()
                              if line.startswith('import ') and line != 'import EtnaModel.CurrentRegistry')
    proofs = '\n'.join(line for line in proofs.splitlines() if not line.startswith('import '))
    model = extra_imports + '\n' + model
    proofs = proofs.replace('RegistryMachine', 'RegistryMachineMutation')
    fixture = fixture.replace('import EtnaProofs.CurrentRegistry', '').replace('RegistryMachine', 'RegistryMachineMutation')
    return model, proofs, fixture


class CurrentRegistryTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=180)

    def test_kernel_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentRegistry.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        model, proofs, fixture = layers()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        result = self.compile(changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        result = self.compile(changed + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])


MUTATIONS = [
    ('identity', 'value with key := old.value.key', 'value with key := 0'),
    ('historical_generation', 'Staking.doubleSign v.domain v.generation a b = true',
     'Staking.doubleSign v.domain v.generation a b = true ∧ a.generation = v.generation'),
    ('signature', 's.verify key a sigA = true', 's.verify key a sigA = s.verify key a sigA'),
    ('issued_exclusion', 'decide (id < s.ledger.nextId) &&', 'true &&'),
    ('forfeit_rate', 'let penalty := Staking.forfeitPenalty b.balance s.config.forfeitBps',
     'let penalty := Staking.forfeitPenalty b.balance 10000'),
    ('rollback_recheck', 'Staking.rollbackBySnapshot snapshot b.value', 'Staking.rollbackBySnapshot (snapshot+b.value.exitAt) b.value'),
]


def mutation_test(old, new):
    def test(self):
        self.reject(old, new)
    return test


for name, old, new in MUTATIONS:
    setattr(CurrentRegistryTests, 'test_mutation_' + name, mutation_test(old, new))
