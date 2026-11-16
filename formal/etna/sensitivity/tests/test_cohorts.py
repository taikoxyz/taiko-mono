"""The explicit runtime cohorts partition all assessed required fault obligations."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('cohort_campaign', ROOT / 'run.py')
campaign = importlib.util.module_from_spec(spec)
spec.loader.exec_module(campaign)


class CohortPartition(unittest.TestCase):
    def setUp(self):
        self.manifest = campaign.load_manifest(ROOT / 'mutations.json')
        self.descriptor = campaign.read_json(ROOT / 'cohorts.json')

    def check_partition(self, descriptor):
        self.assertEqual(descriptor['schema'], 'etna-fault-cohorts-1')
        self.assertEqual(descriptor['manifest'], 'mutations.json')
        required = {item['id']: item for item in self.manifest['obligations']
                    if item['required'] and not item.get('unassessed_reason')}
        cohort_ids, selected = [], []
        for cohort in descriptor['cohorts']:
            cohort_ids.append(cohort['id'])
            ids = cohort['required_ids']
            self.assertTrue(ids)
            self.assertTrue(set(ids).issubset(required), 'unknown or unassessed obligation')
            self.assertIn(cohort['engine'], ('tlc', 'forge'))
            tests = cohort['test_ids']
            self.assertEqual(len(tests), len(set(tests)))
            if cohort['engine'] == 'tlc':
                self.assertEqual(tests, [])
            else:
                self.assertTrue(tests)
            for identifier in ids:
                item = required[identifier]
                self.assertEqual(item['engine'], cohort['engine'])
                if cohort['engine'] == 'forge':
                    self.assertEqual(set(item['workloads']), set(tests),
                                     'Forge cohort must have one exact test set')
            selected.extend(ids)
        self.assertEqual(len(cohort_ids), len(set(cohort_ids)))
        self.assertEqual(len(selected), len(set(selected)), 'duplicate cohort obligation')
        self.assertEqual(set(selected), set(required), 'missing assessed required obligation')

    def test_current_cohorts_cover_every_required_obligation_exactly_once(self):
        self.check_partition(self.descriptor)

    def test_missing_or_duplicate_obligation_rejected(self):
        for duplicate in (False, True):
            changed = copy.deepcopy(self.descriptor)
            ids = changed['cohorts'][0]['required_ids']
            if duplicate:
                ids.append(ids[0])
            else:
                ids.pop()
            with self.subTest(duplicate=duplicate), self.assertRaises(AssertionError):
                self.check_partition(changed)

    def test_unknown_and_unassessed_obligations_rejected(self):
        unassessed = next(item['id'] for item in self.manifest['obligations']
                          if item.get('unassessed_reason'))
        for identifier in ('unknown-obligation', unassessed):
            changed = copy.deepcopy(self.descriptor)
            changed['cohorts'][0]['required_ids'].append(identifier)
            with self.subTest(identifier=identifier), self.assertRaises(AssertionError):
                self.check_partition(changed)

    def test_forge_union_or_substituted_test_set_rejected(self):
        forge = [cohort for cohort in self.descriptor['cohorts'] if cohort['engine'] == 'forge']
        self.assertGreaterEqual(len(forge), 2)
        for union in (False, True):
            changed = copy.deepcopy(self.descriptor)
            target = next(cohort for cohort in changed['cohorts'] if cohort['id'] == forge[0]['id'])
            target['test_ids'] = (target['test_ids'] if union else []) + forge[1]['test_ids']
            with self.subTest(union=union), self.assertRaises(AssertionError):
                self.check_partition(changed)

    def test_forge_obligation_cannot_move_to_incompatible_cohort(self):
        changed = copy.deepcopy(self.descriptor)
        forge = [cohort for cohort in changed['cohorts'] if cohort['engine'] == 'forge']
        forge[1]['required_ids'].append(forge[0]['required_ids'].pop())
        with self.assertRaisesRegex(AssertionError, 'exact test set'):
            self.check_partition(changed)


if __name__ == '__main__':
    unittest.main()
