"""The two Etna revisions have disjoint source and rule evidence."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rule_coverage', ROOT/'scripts/rule_coverage.py')
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)
coverage = rules.coverage


class AuthorityRevisionTests(unittest.TestCase):
    def test_report_validates_both_revisions(self):
        historical = coverage.inventory()
        current = coverage.current_inventory()
        self.assertEqual(len(historical), 579)
        self.assertTrue(current, 'the #22425 clause inventory must be checked independently')
        self.assertEqual({row['profile'] for row in historical}, {'historical'})
        self.assertEqual({row['profile'] for row in current}, {'current'})
        self.assertTrue({row['id'] for row in historical}.isdisjoint(row['id'] for row in current))
        self.assertEqual({row['source_commit'] for row in current},
                         {'2be1f5ec1635cd5d9fa6fc62e8b68f4b163d0de0'})

    def test_old_coverage_does_not_transfer_through_reused_rule_ids(self):
        historical = {row['rule']: row for row in rules.rule_rows()}
        current = {row['rule']: row for row in rules.current_rule_rows()}
        key = 'LAND-6.1-3'
        self.assertTrue(historical[key]['theorems'])
        self.assertEqual(current[key]['theorems'], [])
        self.assertEqual(current[key]['status'], 'deferred')
        self.assertNotEqual(historical[key]['clause'], current[key]['clause'])

    def test_every_current_index_id_is_recorded_once(self):
        current = rules.current_rule_rows()
        index = rules.index_rows((coverage.REPO/rules.INDEX_PATH).read_text())
        self.assertEqual(len(current), len(index))
        self.assertEqual({row['rule']: row['type'] for row in current},
                         {rule: row['type'] for rule, row in index.items()})
        retired = [row for row in current if row['type'] == 'retired']
        self.assertTrue(retired)
        self.assertTrue(all(row['status'] == 'retired' and row['clause'] is None and not row['theorems']
                            for row in retired))

    def test_new_clause_cannot_borrow_a_historical_theorem(self):
        current = coverage.current_inventory()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'manifests').mkdir()
            manifest = json.loads((ROOT/'manifests/design.json').read_text())
            old_theorem = next(entry for entry in manifest['theorems'] if entry['sources'])
            old_theorem['sources'].append(current[0]['id'])
            (root/'manifests/design.json').write_text(json.dumps(manifest))
            shutil.copyfile(ROOT/coverage.CURRENT_CONFIG, root/coverage.CURRENT_CONFIG)
            with self.assertRaisesRegex(ValueError, 'theorem authority mismatch'):
                coverage.current_inventory(root)

    def test_current_digest_pins_include_marker_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            shutil.copytree(coverage.REPO/coverage.SPEC_DIR, repo/coverage.SPEC_DIR)
            spec = repo/coverage.SPEC_PATH
            text = spec.read_text()
            spec.write_text(text.replace('**[MODEL-1-1]** ', '', 1))
            with self.assertRaisesRegex(ValueError, 'current spec digest mismatch'):
                coverage.current_inventory(repo=repo)

    def test_missing_current_index_fails_source_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            shutil.copytree(coverage.REPO/coverage.SPEC_DIR, repo/coverage.SPEC_DIR)
            (repo/rules.INDEX_PATH).unlink()
            with self.assertRaisesRegex(OSError, 'INDEX.md'):
                coverage.current_inventory(repo=repo)

    def test_every_current_source_rejects_edited_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            shutil.copytree(coverage.REPO/coverage.SPEC_DIR, repo/coverage.SPEC_DIR)
            config = json.loads((ROOT/coverage.CURRENT_CONFIG).read_text())
            for key in [key for key, _, _, _ in coverage.SOURCE_INPUTS] + ['index_source']:
                source = repo/config[key]['path']
                original = source.read_bytes()
                with self.subTest(source=source):
                    source.write_bytes(original+b'\n')
                    with self.assertRaisesRegex(ValueError, r'current .* digest mismatch'):
                        coverage.current_inventory(repo=repo)
                    source.write_bytes(original)
