"""Current custody uses actual accepted calls; model-only mutants must compile first."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read_layer(path):
    lines = (ROOT / path).read_text().splitlines()
    imports = []
    while lines and lines[0].startswith('import '):
        imports.append(lines.pop(0))
    return imports, '\n'.join(lines)


def layers():
    imports, models, proofs = [], [], []
    for name in ('CurrentProtocol', 'CurrentCustody'):
        im, body = read_layer(f'EtnaModel/{name}.lean')
        imports.extend(im)
        models.append(body)
    for name in ('CurrentSettlement', 'CurrentCustody'):
        im, body = read_layer(f'EtnaProofs/{name}.lean')
        imports.extend(im)
        if name == 'CurrentCustody':
            # Root journal proofs refer to the original protocol. The local custody
            # lemmas below already cover landing, roots and nonlanding preservation.
            body = body.split('/-- Exhaustive successful-call induction.', 1)[0]
            body += '\nend Etna.Design.Current.Protocol.Custody\n'
        proofs.append(body)
    imports = [line for line in imports if line not in {
        'import EtnaModel.CurrentProtocol', 'import EtnaModel.CurrentCustody',
        'import EtnaProofs.CurrentSettlement', 'import EtnaProofs.CurrentJournal'}]
    imports.append('import EtnaProofs.CurrentBlocks')
    header = '\n'.join(dict.fromkeys(imports)) + '\nset_option linter.unusedVariables false\n'
    return header, '\n'.join(models).replace('Protocol', 'CustodyMutationProtocol'), \
        '\n'.join(proofs).replace('Protocol', 'CustodyMutationProtocol')


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

    def test_each_edge_needs_its_parent_custody(self):
        self.reject('(segment : Suffix env w a) (parent : Path env initial segment.parent)',
                    '(segment : Suffix env w a) (parent : True)')

    def test_emitted_state_root_is_certificate_root(self):
        self.reject('signals := w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,a.input.lastStateRoot⟩]',
                    'signals := w.inbox.signals ++ [⟨a.input.lastHeight,a.input.lastBlockHash,0⟩]')


if __name__ == '__main__':
    unittest.main()
