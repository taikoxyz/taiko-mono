"""Kernel-check physical archive ancestry and reject compilable weakened contracts."""
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


def sources():
    model = 'import EtnaProofs.CurrentFinality\n' + (ROOT / 'EtnaModel/CurrentArchive.lean').read_text()
    proofs = (ROOT / 'EtnaProofs/CurrentArchive.lean').read_text().replace(
        'import EtnaModel.CurrentArchive\n', '').replace('import EtnaProofs.CurrentFinality\n', '')
    fixture = (ROOT / 'tests/CurrentArchive.lean').read_text().replace(
        'import EtnaProofs.CurrentArchive\n', '')
    return tuple(re.sub(r'\bArchive\b', 'ArchiveMutation', s) for s in (model, proofs, fixture))


class CurrentArchiveTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_archive_examples(self):
        result = self.compile('\n'.join(sources()))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        model, proofs, fixture = sources()
        self.assertEqual(model.count(old), 1, old)
        mutant = model.replace(old, new)
        result = self.compile(mutant)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(mutant + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted archive mutant')
        first = next(line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)

    def test_physical_parent_hash_required(self):
        self.reject('parentOf h.elHash = p.elHash', 'True')

    def test_physical_height_successor_required(self):
        self.reject('h.height = p.height+1', 'True')

    def test_actual_batch_headers_required(self):
        self.reject('archive = prior ++ bs.map Blocks.Block.header', 'True')

    def test_prefix_ends_at_actual_parent(self):
        self.reject('terminal root prior = p', 'True')

    def test_historical_headers_hash_bound(self):
        self.reject('(∀ h ∈ archive, hash h = h.elHash)', 'True')

    def test_actual_body_physical_parent_agrees(self):
        self.reject('(∀ b ∈ bs, parentOf b.header.elHash = b.body.parentHash)', 'True')

    def test_origin_height_bound(self):
        self.reject('root.height = cfg.originHeight', 'True')

    def test_origin_cut_bound(self):
        self.reject('root.cut = origin', 'True')

    def test_origin_header_hash_bound(self):
        self.reject('hash root = root.elHash', 'True')

    def test_generation_origin_before_reference(self):
        self.reject('cfg.originBlock ≤ reference', 'True')

    def test_all_archive_anchors_before_reference(self):
        self.reject('(∀ h ∈ archive, h.anchor.number ≤ reference)', 'True')


if __name__ == '__main__':
    unittest.main()
