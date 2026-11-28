"""Current admission cases take the lowest empty slot and reject a full registry without
displacement, and the validator-state cases follow stock CometBFT v0.40.0 arithmetic."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
# One test token unit: 25,000 TAIKO in base units. Every vector amount is a multiple of it,
# except the below-minimum amount minStake - 1.
UNIT = 25_000 * 10**18
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

    def test_current_admission_observables(self):
        data = json.loads((vectors.DIRECTORY/'registry_admission.json').read_text())
        self.assertEqual(data['schema'], 'etna-current-registry-admission-1')
        self.assertEqual(data['authorityCommit'], '994960561490b882558da7847a21a41a271350c5')
        self.assertEqual([v['id'] for v in data['vectors']], [
            'empty-last-slot', 'lowest-empty-slot', 'full-registry-rejected',
            'zero-balance-bond-not-replaced', 'withdrawn-slot-reused', 'pending-topup-irrelevant',
            'below-minimum-rejected'])
        rows = {v['id']:v['expect'] for v in data['vectors']}
        setups = {v['id']:v['setup'] for v in data['vectors']}
        amounts = {v['id']:v['call']['amount'] for v in data['vectors']}
        minimum = 10*UNIT
        for name, setup in setups.items():
            # STAKE-4.1-14a, PARAM-11-11: a deployable registry needs 4096 x minStake > 10^27.
            self.assertGreater(4096*setup['minStake'], 10**27, name)
            self.assertEqual((setup['minStake'],setup['defaultStake'],setup['lowStake']),
                             (minimum,20*UNIT,minimum), name)
        self.assertEqual(amounts, {
            'empty-last-slot':minimum, 'lowest-empty-slot':minimum, 'full-registry-rejected':21*UNIT,
            'zero-balance-bond-not-replaced':21*UNIT, 'withdrawn-slot-reused':minimum,
            'pending-topup-irrelevant':minimum, 'below-minimum-rejected':minimum-1})
        for name, slot, bond, reserve in [('empty-last-slot',4095,4096,81910), ('lowest-empty-slot',1,4,70),
                                          ('withdrawn-slot-reused',17,4096,81910),
                                          ('pending-topup-irrelevant',4,4,83)]:
            row = rows[name]
            self.assertFalse(row['revert'], name)
            self.assertEqual((row['selectedSlot'],row['bondId'],row['nextId']), (slot,bond,bond+1), name)
            self.assertIsNone(row['oldBondId'], name)
            self.assertIsNone(row['oldBond'], name)
            self.assertEqual((row['newBond']['slot'],row['newBond']['stake']), (slot,minimum), name)
            self.assertIsNone(row['slot4096'], name)
            self.assertEqual((row['callerBalance'],row['registryBalance']), (90*UNIT,reserve*UNIT), name)
        for name in ['full-registry-rejected', 'zero-balance-bond-not-replaced', 'below-minimum-rejected']:
            self.assertEqual(rows[name], {'revert':True, 'stateUnchanged':True}, name)
        # A held slot with zero balance after a slash is not empty.
        slash = setups['zero-balance-bond-not-replaced']['slashLifecycle']
        self.assertEqual((slash['slashedBond']['slot'],slash['slashedBond']['balance'],
                          slash['slashedBond']['released']), (17,0,False))
        self.assertEqual(setups['full-registry-rejected']['openingBonds'], 4096)
        self.assertEqual(setups['below-minimum-rejected']['openingBonds'], 4)
        self.assertEqual(setups['pending-topup-irrelevant']['lowPending'], 3*UNIT)
        vacant = setups['empty-last-slot']
        self.assertEqual(vacant['landedSnapshot'], 2)
        lifecycle = vacant['vacancyLifecycle']
        self.assertEqual((lifecycle['requestBlock'], lifecycle['exitAt'], lifecycle['confirmBlock'],
                          lifecycle['withdrawBlock'], lifecycle['recipient']), (1,2,2,5,7))
        self.assertEqual(lifecycle['withdrawnBond'], {
            'key':4096, 'owner':0, 'stake':0, 'pending':0, 'balance':0, 'activeFrom':1,
            'exitAt':2, 'released':True, 'confirmedAt':None, 'readyAt':0, 'slot':None})

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
