"""Current displacement cases do not silently inherit historical full-registry rejection, and the
validator-state cases follow stock CometBFT v0.40.0 arithmetic."""
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
        self.assertEqual(vectors.check(), 2)

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

    def test_current_validator_state_observables(self):
        data = json.loads((vectors.DIRECTORY/'validator_state.json').read_text())
        self.assertEqual(data['schema'], 'etna-current-validator-state-1')
        rows = {v['id']:v['expect'] for v in data['vectors']}
        self.assertEqual(len(rows), 10)
        # CometBFT by hand: NewValidatorSet increments once (priorities += power, the highest
        # proposes and pays the total 60); NextValidators increments once more.
        genesis = rows['genesis-unequal-rotation']['states'][0]
        self.assertEqual(genesis['current'], {'members': [[3,30,-30],[2,20,20],[1,10,10]], 'proposer': 3})
        self.assertEqual(genesis['next'], {'members': [[3,30,0],[2,20,-20],[1,10,20]], 'proposer': 2})
        # Equal powers order and tie-break by address: 2, 4, 9.
        tied = rows['equal-power-address-order']['states'][0]['current']
        self.assertEqual(([m[0] for m in tied['members']], tied['proposer']), ([2,4,9], 2))
        # H's updates join NextValidators at H+1 and sign from H+2.
        added = rows['addition-signs-at-h-plus-2']['states']
        self.assertEqual([[m[0] for m in s['current']['members']] for s in added], [[1,2],[1,2],[1,2,3],[1,2,3]])
        self.assertEqual([s['height'] for s in added], [5,6,7,8])
        self.assertEqual([m[0] for m in added[1]['next']['members']], [1,2,3])
        removed = rows['removal-and-power-change']['states'][2]['current']['members']
        self.assertEqual([m[:2] for m in removed], [[3,30],[2,25]])
        for name, index in [('duplicate-update-rejected',2),('unknown-removal-rejected',1),
                            ('empty-set-rejected',1),('genesis-zero-power-rejected',0),
                            ('total-power-overflow-rejected',1)]:
            self.assertEqual(rows[name]['rejectedAt'], index, name)
            self.assertEqual(len(rows[name]['states']), index, name)
        for name in ['genesis-unequal-rotation','equal-power-address-order','addition-signs-at-h-plus-2',
                     'removal-and-power-change','same-power-update']:
            self.assertIsNone(rows[name]['rejectedAt'], name)


if __name__ == '__main__':
    unittest.main()
