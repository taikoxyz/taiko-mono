"""Current authority pins, current-only evidence and kernel-checked semantic examples."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('coverage_current', ROOT/'scripts/check_spec_coverage.py')
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)


class CurrentAuthorityTests(unittest.TestCase):
    def test_inventory_is_current_only(self):
        current = coverage.inventory()
        self.assertEqual(len(current), 566)
        self.assertTrue(all('historical' not in r for r in current))
        self.assertEqual({r['language'] for r in current},
                         {'live_en', 'live_acceptance', 'live_anchorless', 'live_switch'})
        self.assertTrue(all(r['source_commit'] == 'e84a9aaac526c15597d97ee93f8803f92b02c279' for r in current))
        self.assertFalse(any(r['status'] == 'design-pending' for r in current))
        self.assertTrue(all(n.startswith('Etna.Design.Current.') for r in current for n in r['theorems']))
        self.assertTrue(any(r['status'] == 'partial' for r in current))

    def test_current_kernel_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentDesign.lean'], cwd=ROOT,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

class CurrentEvidenceIsolationTests(unittest.TestCase):
    def test_non_current_theorem_cannot_count_as_current_evidence(self):
        # A theorem outside Etna.Design.Current (and outside the reviewed shared plumbing)
        # citing a current clause is an authority mismatch.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'manifests').mkdir()
            manifest = json.loads((ROOT/'manifests/design.json').read_text())
            spec = json.loads((ROOT/'spec-coverage.json').read_text())
            current_source = next(iter(spec['claims'][-1]['evidence']))
            entry = next(e for e in manifest['theorems'] if e['sources'])
            manifest['theorems'].append({**entry, 'declaration': 'Etna.Design.Staking.not_current',
                                         'sources': [current_source]})
            (root/'manifests/design.json').write_text(json.dumps(manifest))
            (root/'spec-coverage.json').write_text(json.dumps(spec))
            with self.assertRaisesRegex(ValueError, 'theorem authority mismatch: Etna.Design.Staking.not_current cites '
                                        + current_source):
                coverage.inventory(root, coverage.REPO)

    def test_switch_authority_pin_is_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            spec = json.loads((ROOT/'spec-coverage.json').read_text())
            spec.pop('switch_source')
            (root/'spec-coverage.json').write_text(json.dumps(spec))
            with self.assertRaisesRegex(ValueError, 'switch reviewed source pin required'):
                coverage.source_rows(root, coverage.REPO)

class AuthorityByteTests(unittest.TestCase):
    def test_each_independent_authority_rejects_edited_bytes(self):
        import shutil
        for key, label, path, _ in coverage.SOURCE_INPUTS:
            with self.subTest(authority=label), tempfile.TemporaryDirectory() as tmp:
                repo = Path(tmp)
                root = repo/'formal/etna'
                root.mkdir(parents=True)
                shutil.copyfile(ROOT/'spec-coverage.json', root/'spec-coverage.json')
                for _, _, source, _ in coverage.SOURCE_INPUTS:
                    target = repo/source
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(coverage.REPO/source, target)
                target = repo/path
                target.write_text(target.read_text()+'\nChanged normative text.\n')
                with self.assertRaisesRegex(ValueError, label+' digest mismatch'):
                    coverage.source_rows(root, repo)
