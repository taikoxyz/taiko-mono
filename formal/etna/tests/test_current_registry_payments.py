"""Atomic payment wrapper: real token failures and compilable semantic mutations."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    model = (ROOT / 'EtnaModel/CurrentRegistryPayments.lean').read_text()
    proofs = (ROOT / 'EtnaProofs/CurrentRegistryPayments.lean').read_text()
    fixture = (ROOT / 'tests/CurrentRegistryPayments.lean').read_text()
    imports = '\n'.join(line for line in proofs.splitlines()
                        if line.startswith('import ') and 'CurrentRegistryPayments' not in line)
    proofs = '\n'.join(line for line in proofs.splitlines() if not line.startswith('import '))
    fixture = fixture.replace('import EtnaProofs.CurrentRegistryPayments', '')
    return tuple(text.replace('RegistryPayments', 'RegistryPaymentsMutation')
                 for text in (model, imports + '\n' + proofs, fixture))


class CurrentRegistryPaymentTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=60)

    def test_kernel_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentRegistryPayments.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        model, proofs, fixture = layers()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        # Imports must precede model declarations in the combined unchanged evidence.
        extra_imports = '\n'.join(line for line in proofs.splitlines() if line.startswith('import '))
        proof_body = '\n'.join(line for line in proofs.splitlines() if not line.startswith('import '))
        result = self.compile(changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        result = self.compile(extra_imports + '\n' + changed + '\n' + proof_body + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])


MUTATIONS = [
    ('atomic_transfer_failure', '(runTransfers env s.token payments).map fun token =>',
     '(some ((runTransfers env s.token payments).getD s.token)).map fun token =>'),
    ('withdraw_recipient', '[⟨env.registryAddress,recipient,b.value.balance,false⟩]',
     '[⟨env.registryAddress,caller+0*recipient,b.value.balance,false⟩]'),
    ('fixed_bounty', 'Staking.fraction b.value.balance s.config.slashBountyBps',
     'Staking.fraction b.value.balance (10000+0*s.config.slashBountyBps)'),
    ('slash_remainder', 'b.value.balance-bounty,false', 'b.value.balance,false'),
    ('caller_binding', 'caller == embedded', '(caller == embedded || true)'),
    ('deposit_approval', '[⟨caller,env.registryAddress,amount,true⟩]',
     '[⟨caller,env.registryAddress,amount,false⟩]'),
]


def mutation_test(old, new):
    def test(self):
        self.reject(old, new)
    return test


for name, old, new in MUTATIONS:
    setattr(CurrentRegistryPaymentTests, 'test_mutation_' + name, mutation_test(old, new))
