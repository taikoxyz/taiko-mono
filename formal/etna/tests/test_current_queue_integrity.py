"""Current queue contracts reject early skips and unpaid admission, using real transitions."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]


class CurrentQueueIntegrityTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def assert_silent_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject_mutation(self, model, evidence, old, new):
        self.assertEqual(model.count(old), 1)
        self.assert_silent_success(self.compile(model + evidence))
        changed = model.replace(old, new)
        self.assert_silent_success(self.compile(changed))
        result = self.compile(changed + evidence)
        self.assertNotEqual(result.returncode, 0, 'unchanged semantic contract accepted mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])

    def forced_function(self, name, end):
        source = (ROOT / 'EtnaModel/Forced.lean').read_text()
        body = source[source.index('def ' + name + ' '):source.index(end)]
        return ('import EtnaModel.CurrentProtocol\nnamespace Etna.QueueMutation\n'
                'open Etna.Design Etna.Design.Current Etna.Design.Forced\n' + body +
                '\nend Etna.QueueMutation\n')

    def test_nondue_skip_mutant(self):
        model = self.forced_function('step', '/-- Admission formula')
        evidence = '''
open Etna.Design Etna.QueueMutation
def early : Forced.Witness := ⟨0,⟨7,20,1⟩,true,7,1,false,none,false,0⟩
example : Etna.QueueMutation.step 0 1 10 1 (some early) .completedEmpty = .accepted 0 := by decide
'''
        self.reject_mutation(model, evidence,
                             'anchor < w.stored.timestamp+delay',
                             'anchor < w.stored.timestamp+delay ∧ False')

    def admission_model(self):
        return self.forced_function('enqueue', '/-- `sweepProtocolFees()')

    def admission_evidence(self, paid, refund):
        return '''
open Etna.Design Etna.Design.Current
def inbox : State := { Protocol.bareInbox ⟨⟨1,2,3,4⟩,7,8,0,0,9⟩ with
  forcedFee := 1,forcedThreshold := 1 }
example : Etna.QueueMutation.enqueue inbox 1 ''' + str(paid) + ' ' + str(refund).lower() + ''' = none := by decide
'''

    def test_underpayment_guard_mutant(self):
        self.reject_mutation(self.admission_model(), self.admission_evidence(999999999, True),
                             'fee ≤ paid', 'True')

    def test_refund_failure_guard_mutant(self):
        self.reject_mutation(self.admission_model(), self.admission_evidence(1000000001, False),
                             '(paid = fee ∨ refundOK = true)', '(refundOK = refundOK)')

    def import_contract(self):
        model = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text()
        model = re.sub(r'\bProtocol\b', 'QueueProtocolMutation', model)
        proof = (ROOT / 'EtnaProofs/CurrentQueueIntegrity.lean').read_text()
        proof = proof[proof.index('theorem node_import_closed'):proof.rindex('end Etna.Design.Current.QueueIntegrity')]
        evidence = ('\nnamespace Etna.QueueMutation\nopen Etna.Design Etna.Design.Current\n'
                    'open QueueProtocolMutation\n' + proof + '\nend Etna.QueueMutation\n')
        # The full range proof uses the already checked decoded importer contract.
        model = 'import EtnaProofs.CurrentQueueIntegrity\n' + model
        evidence = evidence.replace('import_complete_range', 'QueueIntegrity.import_complete_range')
        return model, evidence

    def test_ready_import_mutant(self):
        self.reject_mutation(*self.import_contract(),
                             'signer := { installed.signer with ready := false }',
                             'signer := installed.signer')

    def test_import_cannot_omit_original_generation_prefix(self):
        self.reject_mutation(*self.import_contract(),
                             'candidate.origin = w.inbox.origin.height',
                             'candidate.origin = candidate.origin')

    def test_deployment_rejects_free_admission(self):
        result = self.compile('''import EtnaModel.CurrentProtocol
open Etna.Design Etna.Design.Current.Protocol
example : Parameters.valid
    ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,2,1152,10,0,1,9⟩ = false := by decide
''')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_queue_integrity_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentQueueIntegrity.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')


if __name__ == '__main__':
    unittest.main()
