"""Current raw-input committee, accountable liability and local locking regressions."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]


def sources():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT / library / 'CurrentFinality.lean').read_text().splitlines()
        while lines and lines[0].startswith('import '):
            line = lines.pop(0)
            if line != 'import EtnaModel.CurrentFinality':
                imports.append(line)
        bodies.append('\n'.join(lines).replace('Etna.Design.Current.Finality', 'Etna.Design.Current.FinalityMutation'))
    fixture = (ROOT / 'tests/CurrentFinality.lean').read_text().replace('import EtnaProofs.CurrentFinality', '')
    fixture = fixture.replace('Etna.Design.Current.Finality', 'Etna.Design.Current.FinalityMutation')
    return '\n'.join(dict.fromkeys(imports)) + '\n', *bodies, fixture


class CurrentFinalityTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def test_current_examples(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentFinality.lean'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, model, proofs, fixture = sources()
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        result = self.compile(imports + changed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + changed + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_origin_lookback_inclusive(self):
        self.reject('if h ≤ cfg.originHeight then cfg.originBlock',
                    'if h < cfg.originHeight then cfg.originBlock')

    def test_archive_index_starts_after_origin(self):
        self.reject('archive[h-cfg.originHeight-1]?', 'archive[h-cfg.originHeight]?')

    def test_registry_reads_historical_cutoff(self):
        self.reject('RegistryHistory.latestSnapshot registry.history cutoff',
                    'RegistryHistory.latestSnapshot registry.history (cutoff+1000)')

    def test_header_archive_complete(self):
        self.reject('requiredPrefix cfg h ≤ archive.length ∧', 'True ∧')

    def test_header_archive_heights(self):
        self.reject("archive.map BlockValidity.Header.height = List.range' (cfg.originHeight+1) archive.length ∧", 'True ∧')

    def test_authentication_required(self):
        self.reject('Ready cfg registry archive h ∧ Authentic adapters cfg registry archive then',
                    'Ready cfg registry archive h then')

    def test_overlap_requires_both_signatures(self):
        self.reject('(votesA.map Consensus.Vote.key).contains entry.key &&',
                    '(votesA.map Consensus.Vote.key).contains entry.key ||')

    def test_all_chain_certificates_are_attributed(self):
        self.reject('∀ pair ∈ Blocks.pairs p bs, Locking.CommitAttribution',
                    '∀ pair ∈ (Blocks.pairs p bs).take 1, Locking.CommitAttribution')

    def test_agreement_covers_every_overlapping_header(self):
        self.reject('| a :: as, b :: bs => a = b ∧ HeaderAgreement as bs',
                    '| a :: as, b :: bs => a = b ∧ True')

    def test_evidence_authentication_not_assumed(self):
        self.reject('registry.verify vote.key (Accountability.evidence vote) sig = true', '(sig : Hash) = sig')


if __name__ == '__main__':
    unittest.main()
