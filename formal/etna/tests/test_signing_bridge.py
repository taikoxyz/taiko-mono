"""Kernel mutations of signer/prefix binding, with real proofs and no mock checks.

The copied declarations live in a distinct namespace so imported deployment proofs
can retain the original Model root. Each mutation keeps valid Lean syntax and must
break an independent binding contract or the actual composed proof.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined_bridge():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'SigningBridge.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.SigningBridge',
                                                     'Etna.Design.SigningBridgeMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)


class SigningBridgeKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, old, new):
        source = combined_bridge()
        self.assertIn(old, source)
        result = self.compile(source.replace(old, new, 1))
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'a missing real binding must break its proof')
        self.assertIn('error:', output)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token'):
            self.assertNotIn(accidental, output)

    def test_complete_bridge_compiles_silently(self):
        result = self.compile(combined_bridge())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_checkpoint_el_hash_cannot_be_omitted(self):
        self.rejected('h.elHash = cp.elHash', 'True')

    def test_checkpoint_comet_hash_cannot_be_omitted(self):
        self.rejected('h.cometHash = cp.cometHash', 'True')

    def test_request_membership_cannot_be_omitted(self):
        self.rejected('e.key = key', 'True')

    def test_request_height_cannot_be_disconnected_from_tip(self):
        self.rejected('m.height = p.tip.height+1', 'True')

    def test_actual_request_height_cannot_be_shifted(self):
        self.rejected('⟨m.height,m.round,phaseStep m.phase⟩', '⟨m.height+1,m.round,phaseStep m.phase⟩')

    def test_actual_sign_bytes_cannot_be_replaced(self):
        self.rejected('phaseStep m.phase⟩,encode m⟩', 'phaseStep m.phase⟩,0⟩')

    def test_settlement_and_signing_archive_cannot_be_unbound(self):
        self.rejected('a.anchorAt = b.anchorAt', 'True')
