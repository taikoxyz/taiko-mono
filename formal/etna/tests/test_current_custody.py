"""Current custody uses actual accepted calls; model-only mutants must compile first."""
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


def read_layer(path):
    lines = (ROOT / path).read_text().splitlines()
    imports = []
    while lines and lines[0].startswith('import '):
        imports.append(lines.pop(0))
    return imports, '\n'.join(lines)


def layers():
    model_names = ('CurrentProtocol', 'CurrentCustody', 'CurrentJournal',
                   'CurrentProtocolFinality', 'CurrentEconomics', 'CurrentMetadata')
    proof_names = ('CurrentReference', 'CurrentHistory', 'CurrentProtocolFinality',
                   'CurrentEconomics', 'CurrentMetadata', 'CurrentFootprintHistory',
                   'CurrentCertificate', 'CurrentSettlement', 'CurrentJournal', 'CurrentCustody')
    cloned = {f'EtnaModel.{name}' for name in model_names}
    cloned.update(f'EtnaProofs.{name}' for name in proof_names)
    imports, models, proofs = [], [], []
    for library, names, bodies in (('EtnaModel', model_names, models), ('EtnaProofs', proof_names, proofs)):
        for name in names:
            im, body = read_layer(f'{library}/{name}.lean')
            imports.extend(line for line in im if line.removeprefix('import ') not in cloned)
            if name == 'CurrentCustody' and library == 'EtnaProofs':
                body = body.split('/-- Exhaustive successful-call induction.', 1)[0]
                body += '\nend Etna.Design.Current.Protocol.Custody\n'
            for namespace in ('Protocol', 'Journal', 'ProtocolFinality', 'Economics'):
                body = re.sub(r'\b' + namespace + r'\b', 'CustodyMutation' + namespace, body)
            bodies.append(body)
    header = '\n'.join(dict.fromkeys(imports)) + '\nset_option linter.unusedVariables false\n'
    return header, '\n'.join(models), '\n'.join(proofs)


class CurrentCustodyTests(unittest.TestCase):
    def compile(self, source):
        (ROOT / '.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_nonempty_overlap_and_corrected_start_paths(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentCustody.lean'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_unchanged_mutation_layers_compile(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        header, model, proof = layers()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new, 1)
        result = self.compile(header + changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        result = self.compile(header + changed + '\n' + proof)
        self.assertNotEqual(result.returncode, 0, 'unchanged custody proofs accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])

    def test_landing_cannot_bypass_checks(self):
        self.reject('if LandingChecks env w a then some (landed w a) else none',
                    'if True then some (landed w a) else none')

    def test_origin_cursor_is_bound(self):
        self.reject('origin.elHash,origin.cometHash,origin.cursor,',
                    'origin.elHash,origin.cometHash,0,')

    def test_parent_hash_binding_required(self):
        self.reject('HashBound env p ∧ (∀ b ∈ bs, HashBound env b.header)',
                    'True ∧ (∀ b ∈ bs, HashBound env b.header)')

    def test_genesis_root_is_new_network_only(self):
        self.reject('(newNetwork : env.core.unzenInbox = 0) : Path env initial env.genesisHeader',
                    '(newNetwork : True) : Path env initial env.genesisHeader')

    def test_switching_root_requires_its_actual_source_trace(self):
        self.reject('∃ w t a legacy, Trace env initial w ∧ land env w a = some t ∧ FirstFence env w h ∧',
                    '∃ w t a legacy, land env w a = some t ∧ FirstFence env w h ∧')

    def test_each_edge_needs_its_parent_custody(self):
        self.reject('(segment : Suffix env w a) (parent : Path env initial segment.parent)',
                    '(segment : Suffix env w a) (parent : True)')

    def test_emitted_state_root_is_certificate_root(self):
        self.reject('signals := w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩]',
                    'signals := w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,0⟩]')


if __name__ == '__main__':
    unittest.main()
