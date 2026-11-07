"""Actual Protocol calls must refine closed principal traces and atomic paid H2."""
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


def renamed(source):
    source = re.sub(r'\bEtna\.Design\.Current\.Protocol\b', 'Etna.Design.Current.ProtocolMutation', source)
    source = source.replace('Etna.Design.Current.ProtocolFinality', 'Etna.Design.Current.ProtocolFinalityMutation')
    source = re.sub(r'\bProtocol\.', 'ProtocolMutation.', source)
    source = re.sub(r'\bopen Protocol\b', 'open ProtocolMutation', source)
    source = source.replace('Current Protocol ProtocolFinality', 'Current ProtocolMutation ProtocolFinalityMutation')
    source = re.sub(r'\bopen Etna\.Design\.Current\.ProtocolFinality\b', 'open Etna.Design.Current.ProtocolFinalityMutation', source)
    return source


def sources():
    imports, bodies = [], []
    for library, name in [('EtnaModel', 'CurrentProtocol'), ('EtnaModel', 'CurrentProtocolFinality'),
                          ('EtnaProofs', 'CurrentProtocolFinality')]:
        lines = (ROOT / library / (name + '.lean')).read_text().splitlines()
        while lines and lines[0].startswith('import '):
            line = lines.pop(0)
            if line not in ('import EtnaModel.CurrentProtocol', 'import EtnaModel.CurrentProtocolFinality'):
                imports.append(line)
        bodies.append(renamed('\n'.join(lines)))
    fixture = (ROOT / 'tests/CurrentProtocolFinality.lean').read_text().replace('import EtnaProofs.CurrentProtocolFinality', '')
    return '\n'.join(dict.fromkeys(imports)) + '\n', *bodies, renamed(fixture)


class CurrentProtocolFinalityTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def test_actual_protocol_examples(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentProtocolFinality.lean'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_renamed_baseline(self):
        parts = sources()
        result = self.compile('\n'.join(parts))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, protocol, model, proofs, fixture = sources()
        self.assertEqual(protocol.count(old), 1, old)
        changed = protocol.replace(old, new)
        result = self.compile(imports + changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + changed + '\n' + model + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_initialize_cannot_reset_a_later_generation(self):
        self.reject('w.initialized = false ∧ w.inbox.generation = 0 ∧', 'w.initialized = false ∧')

    def test_start_cannot_reset_a_later_generation(self):
        self.reject('w.start = none ∧ w.inbox.generation = 0 ∧ caller', 'w.start = none ∧ caller')

    def test_actual_advance_rejects_backwards_clock(self):
        self.reject('number < limit48 ∧ env.time w.number ≤ env.time number then', 'number < limit48 then')

    def test_recovery_advances_generation(self):
        self.reject('inbox with generation := w.inbox.generation+1,', 'inbox with generation := 0,')

    def test_node_restart_cannot_uninitialize_inbox(self):
        self.reject('| .restart => some (nodeRestart w)',
                    '| .restart => some { (nodeRestart w) with initialized := false }')

    def test_registry_call_cannot_bypass_token_transfers(self):
        self.reject('(RegistryPayments.executeTransaction env.token w.registry (registryView env w) w.number caller a).map',
                    '(Option.map (fun registry => (⟨registry,w.registry.token⟩,([] : List RegistryPayments.Payment))) (RegistryMachine.execute w.registry.registry (registryView env w) w.number a)).map')


if __name__ == '__main__':
    unittest.main()
