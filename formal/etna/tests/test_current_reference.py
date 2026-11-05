"""Check general closed-prefix certificate transport and the concrete live bridge."""
from pathlib import Path
import subprocess
import re
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]


class CurrentReferenceTests(unittest.TestCase):
    def sources(self):
        models = ('CurrentProtocol', 'CurrentJournal', 'CurrentProtocolFinality',
                  'CurrentEconomics', 'CurrentMetadata')
        proofs = ('CurrentReference', 'CurrentHistory', 'CurrentProtocolFinality',
                  'CurrentEconomics', 'CurrentMetadata', 'CurrentFootprintHistory',
                  'CurrentCertificate')
        cloned = {f'EtnaModel.{name}' for name in models}
        cloned.update(f'EtnaProofs.{name}' for name in proofs)
        imports, bodies = [], []
        for library, names in (('EtnaModel', models), ('EtnaProofs', proofs)):
            for name in names:
                body = []
                for line in (ROOT / library / (name + '.lean')).read_text().splitlines():
                    if line.startswith('import '):
                        if line.removeprefix('import ') not in cloned:
                            imports.append(line)
                    else:
                        body.append(line)
                renamed = '\n'.join(body)
                for namespace in ('Protocol', 'Journal', 'ProtocolFinality', 'Economics'):
                    renamed = re.sub(r'\b' + namespace + r'\b', 'ReferenceMutation' + namespace, renamed)
                bodies.append(renamed)
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

    def test_statement_generation_binds_reference_to_live_generation(self):
        self.reject('⟨w.inbox.domain,w.inbox.generation,w.inbox.committeeConfig,origin.elHash,origin.cometHash,origin.cursor,',
                    '⟨w.inbox.domain,0,w.inbox.committeeConfig,origin.elHash,origin.cometHash,origin.cursor,')

    def test_image_certificate_has_no_live_storage_premise(self):
        model = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text()
        image = model.split('def ImageCertifies ', 1)[1].split('/-- Semantic', 1)[0]
        self.assertNotIn('CertificateFootprint', image)
        environment = model.split('structure Environment where', 1)[1].split('structure World where', 1)[0]
        self.assertNotIn('archiveAuthenticated', environment)

    def test_general_transport_and_operational_bound(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentReference.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_reachable_recovery_stale_reference_rejected_by_bound_certificate(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentCertificateFootprint.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')


if __name__ == '__main__':
    unittest.main()
