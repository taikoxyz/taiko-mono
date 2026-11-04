"""Current displacement cases do not silently inherit historical full-registry rejection."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('current_vectors', ROOT/'scripts/check_current_vectors.py')
vectors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vectors)


class CurrentVectorTests(unittest.TestCase):
    def test_opening_invariants(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentVectors.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=180)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_current_vectors_are_fresh(self):
        self.assertEqual(vectors.check(), 1)

    def test_current_displacement_observables(self):
        data = json.loads((vectors.DIRECTORY/'registry_admission.json').read_text())
        self.assertEqual(data['schema'], 'etna-current-registry-admission-1')
        self.assertEqual(len(data['vectors']), 8)
        rows = {v['id']:v['expect'] for v in data['vectors']}
        last = rows['last-slot-minimum-displacement']
        self.assertFalse(last['revert'])
        self.assertEqual((last['selectedSlot'],last['bondId'],last['slot4096']), (4095,4096,None))
        self.assertEqual((last['oldBond']['slot'],last['oldBond']['balance'],last['oldBond']['exitAt']),
                         (None,10,10))
        self.assertTrue(rows['strict-equal-minimum-rejected']['revert'])
        self.assertTrue(rows['below-minimum-rejected']['revert'])
        self.assertEqual(rows['nonzero-tied-minimum-lowest-index']['selectedSlot'],17)
        self.assertEqual(rows['pending-principal-changes-minimum']['selectedSlot'],4095)
        self.assertEqual(rows['all-positive-tie-slot-zero']['selectedSlot'],0)
        self.assertIsNone(rows['empty-last-slot']['oldBondId'])
        vacant = next(v['setup'] for v in data['vectors'] if v['id'] == 'empty-last-slot')
        self.assertEqual(vacant['landedSnapshot'], 2)
        lifecycle = vacant['vacancyLifecycle']
        self.assertEqual((lifecycle['requestBlock'], lifecycle['exitAt'], lifecycle['confirmBlock'],
                          lifecycle['withdrawBlock'], lifecycle['recipient']), (1,2,2,5,7))
        self.assertEqual(lifecycle['withdrawnBond'], {
            'key':4096, 'owner':0, 'stake':0, 'pending':0, 'balance':0, 'activeFrom':1,
            'exitAt':2, 'released':True, 'confirmedAt':None, 'readyAt':0, 'slot':None})
        pending = rows['displaced-pending-principal-retained']['oldBond']
        self.assertEqual((pending['stake'],pending['pending'],pending['balance'],pending['readyAt']), (7,3,10,2))


if __name__ == '__main__':
    unittest.main()
