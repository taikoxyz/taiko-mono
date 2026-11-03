"""Check general closed-prefix certificate transport and the concrete live bridge."""
from pathlib import Path
import subprocess
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentReferenceTests(unittest.TestCase):
    def sources(self):
        imports, bodies = [], []
        for library, name in [('EtnaModel', 'CurrentProtocol'), ('EtnaProofs', 'CurrentReference'),
                              ('EtnaProofs', 'CurrentCertificate')]:
            body = []
            for line in (ROOT / library / (name + '.lean')).read_text().splitlines():
                if line.startswith('import '):
                    if line not in ('import EtnaModel.CurrentProtocol', 'import EtnaProofs.CurrentReference'):
                        imports.append(line)
                else:
                    body.append(line)
            bodies.append(re.sub(r'\bProtocol\b', 'ReferenceMutationProtocol', '\n'.join(body)))
        return '\n'.join(dict.fromkeys(imports)) + '\n', bodies[0], '\n'.join(bodies[1:])

    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_unchanged_mutation_layers_compile(self):
        result = self.compile('\n'.join(self.sources()))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, model, proofs = self.sources()
        self.assertEqual(model.count(old), 1, old)
        mutant = model.replace(old, new)
        result = self.compile(imports + mutant)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + mutant + '\n' + proofs)
        self.assertNotEqual(result.returncode, 0, 'reference contract accepted semantic mutant')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_certificate_uses_only_closed_world(self):
        self.reject('LiveBatchCertificate env closed d archive p bs ∧',
                    'LiveBatchCertificate env w d archive p bs ∧')

    def test_concrete_archive_authentication_required(self):
        old = '''Archive.Authenticated env.headerHash env.headerParent (config w)
      (certificateOriginCut (certificateWorld env w d.input.l1ReferenceBlockNumber))
      d.input.l1ReferenceBlockNumber archive p bs'''
        self.reject(old, 'True')

    def test_missing_origin_cannot_use_mapping_default(self):
        self.reject('(certificateOrigin closed).isSome = true', 'True')

    def test_complete_numbered_reference_prefix_required(self):
        self.reject('''(referencePrefix w d.input.l1ReferenceBlockNumber).map Snapshot.number =
      List.range (d.input.l1ReferenceBlockNumber+1)''', 'True')

    def test_general_transport_and_operational_bound(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentReference.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')


if __name__ == '__main__':
    unittest.main()
