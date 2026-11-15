"""Actual landing metadata, rather than a matching header, decides rollback trust."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layer(path):
    lines = (ROOT/path).read_text().splitlines()
    imports = []
    while lines and lines[0].startswith('import '):
        imports.append(lines.pop(0))
    return imports, '\n'.join(lines)


def layers():
    imports, bodies = [], []
    cloned = {'EtnaModel.CurrentGovernance', 'EtnaProofs.CurrentGovernance'}
    for path in ('EtnaModel/CurrentGovernance.lean', 'EtnaProofs/CurrentGovernance.lean',
                 'tests/CurrentRollbackOutputs.lean'):
        dependencies, body = layer(path)
        imports.extend(line for line in dependencies if line.removeprefix('import ') not in cloned)
        bodies.append(re.sub(r'\bGovernance\b', 'RollbackOutputsMutation', body))
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies


class CurrentRollbackOutputTests(unittest.TestCase):
    def compile(self, source):
        (ROOT/'.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_actual_landing_outputs_decide_the_first_bad_landing(self):
        imports, model, proofs, fixture = layers()
        result = self.compile('\n'.join((imports, model, proofs, fixture)))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    @unittest.skipUnless(os.environ.get('ETNA_FULL_TESTS') == '1',
                         'mutation suite: set ETNA_FULL_TESTS=1')
    def test_header_only_trust_is_rejected(self):
        imports, model, proofs, fixture = layers()
        old = 'event.Certified env initial'
        self.assertEqual(model.count(old), 2)
        changed = model.replace(old, 'True')
        result = self.compile(imports+changed)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')
        result = self.compile('\n'.join((imports, changed, proofs, fixture)))
        self.assertNotEqual(result.returncode, 0, 'metadata-blind rollback trust accepted')
        errors = [line for line in (result.stdout+result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout+result.stderr)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token',
                           'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])


if __name__ == '__main__':
    unittest.main()
