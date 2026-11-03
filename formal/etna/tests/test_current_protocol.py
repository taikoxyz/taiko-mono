"""Current app trust and funded initial state reject compilable weakened models."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from test_current_protocol_finality import sources as finality_sources

ROOT = Path(__file__).resolve().parents[1]


def node_sources():
    model = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text()
    fixture = (ROOT / 'tests/CurrentProtocol.lean').read_text().replace(
        'import EtnaModel.CurrentProtocol', '')
    return tuple(re.sub(r'\bProtocol\b', 'ProtocolMutation', source)
                 for source in (model, fixture))


class CurrentProtocolTests(unittest.TestCase):
    def compile(self, source):
        # No shared olean writes: these tests can run alongside the repository audit.
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def assert_compiles(self, source):
        result = self.compile(source)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def assert_evidence_rejects(self, model, evidence, old, new):
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        self.assert_compiles(changed)
        result = self.compile(changed + '\n' + evidence)
        self.assertNotEqual(result.returncode, 0, 'unchanged fixture accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix',
                           'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])

    def test_renamed_node_fixture(self):
        self.assert_compiles('\n'.join(node_sources()))

    def test_trust_requires_initialized_inbox(self):
        self.assert_evidence_rejects(*node_sources(),
            'w.initialized = true ∧ ∃ start, w.start = some start ∧',
            'w.initialized = w.initialized ∧ ∃ start, w.start = some start ∧')

    def test_trust_requires_authenticated_origin_hash(self):
        self.assert_evidence_rejects(*node_sources(),
            'env.headerHash p = p.elHash ∧',
            'env.headerHash p = env.headerHash p ∧')

    def test_switching_trust_requires_unzen_origin(self):
        self.assert_evidence_rejects(*node_sources(),
            'env.unzenRoot p ∧ env.startImplementation p.stateRoot = true',
            'True ∧ env.startImplementation p.stateRoot = true')

    def test_initial_token_funding_is_reachable(self):
        imports, protocol, model, proofs, fixture = finality_sources()
        evidence = '\n'.join((model, proofs, fixture))
        self.assert_compiles(imports + protocol + '\n' + evidence)
        self.assert_evidence_rejects(imports + protocol, evidence,
            '⟨registry,env.initialToken⟩',
            '⟨registry,⟨fun _ => 0,fun _ _ => 0⟩⟩')


if __name__ == '__main__':
    unittest.main()
