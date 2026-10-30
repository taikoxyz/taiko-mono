"""Independent arithmetic/ordering expectations for the current registry/recovery vectors.

The separate generator tests require these committed artifacts to equal fresh model runs.
These checks pin externally observable results rather than restating the Lean implementation.
"""
import json
from pathlib import Path
import unittest

DATA = Path(__file__).resolve().parents[3] / 'testdata/etna_conformance'


class AlignmentVectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = {v['id']: v['expect'] for v in json.loads((DATA/'registry.json').read_text())['vectors']}
        cls.recovery = {v['id']: v['expect'] for v in json.loads((DATA/'recover.json').read_text())['vectors']}

    def registry_case(self, label):
        return self.registry['registry.hw.'+label]

    def test_pending_deposit_is_not_effective_or_historical_stake(self):
        deposited = self.registry_case('top-up-owner')['observable']['registry']
        bond = deposited['bonds'][0]
        self.assertEqual((bond['stake'], bond['pendingTopUp'], bond['topUpReadyAtL1']), (10, 7, 30))
        self.assertEqual(deposited['checkpointCount'], 1)
        activated = self.registry_case('top-up-activate-at-ready')['observable']['registry']
        bond = activated['bonds'][0]
        self.assertEqual((bond['stake'], bond['pendingTopUp'], bond['topUpReadyAtL1']), (17, 0, 0))
        self.assertEqual(activated['checkpointCount'], 2)
        self.assertEqual(activated['checkpoints'][1]['entries'][0]['stake'], 10)

    def test_capacity_does_not_prevent_top_up(self):
        case = self.registry_case('top-up-full-registry')
        self.assertFalse(case['revert'])
        registry = case['observable']['registry']
        self.assertEqual(registry['entryCount'], 4096)
        self.assertEqual(registry['stakeHeld'], 4096*10+7)

    def test_pending_principal_is_paid_and_fully_slashable(self):
        self.assertEqual(self.registry_case('withdraw-pays-pending-principal')['result'], {'paid': 17})
        self.assertEqual(self.registry_case('slash-pending-principal')['result'], {'bounty': 1, 'toSink': 16})
        self.assertEqual(self.registry_case('pending-only-withdraw-owner')['result'], {'paid': 90})
        self.assertTrue(self.registry_case('pending-only-withdraw-stranger')['revert'])
        self.assertEqual(self.registry_case('pending-only-slash')['result'], {'bounty': 9, 'toSink': 81})

    def test_forfeiture_rounding_spill_and_atomic_failure(self):
        self.assertEqual(self.registry_case('forfeit-exact-penalty')['result'], {'toSink': 1})
        self.assertEqual(self.registry_case('forfeit-ceiling-penalty')['result'], {'toSink': 2})
        spill = self.registry_case('forfeit-consumes-pending-after-effective')
        self.assertEqual(spill['result'], {'toSink': 11})
        bond = spill['observable']['registry']['bonds'][0]
        self.assertEqual((bond['stake'], bond['pendingTopUp']), (0, 90))
        failed = self.registry_case('forfeit-transfer-failure-atomic')
        self.assertTrue(failed['revert'])
        self.assertEqual(failed['observable']['registry']['forfeitedKeys'], [])
        self.assertEqual(failed['observable']['registry']['bonds'][0]['pendingTopUp'], 7)

    def test_lifetime_flags_survive_release_reuse_and_rollback(self):
        for label in ('forfeit-flag-survives-release-and-reuse', 'forfeit-flag-survives-rollback'):
            self.assertEqual(self.registry_case(label)['observable']['registry']['forfeitedKeys'], [1])
        self.assertEqual(self.registry_case('new-entry-can-forfeit-after-reuse')['observable']['registry']['forfeitedKeys'], [2, 1])
        for label in ('forfeit-repeat-same-entry', 'forfeit-repeat-rejected-after-rollback', 'forfeit-after-slash', 'forfeit-after-withdrawal'):
            self.assertTrue(self.registry_case(label)['revert'], label)

    def test_nonce_expiry_replay_and_uint256_boundaries(self):
        rejected = ('deadline-expired', 'nonce-invalidated-old-authorization', 'rollback-cannot-revive-authorization',
                    'executed-authorization-replay', 'invalidation-nonowner', 'invalidation-wrong-nonce',
                    'invalidation-replay', 'recover-before-initialization', 'invalidation-before-initialization',
                    'nonce-recovery-overflow', 'nonce-invalidation-overflow', 'nonce-rollback-overflow',
                    'nonce-invalidated-at-last-value', 'deadline-uint256-overflow')
        accepted = ('deadline-equal', 'deadline-future', 'nonce-invalidated-fresh-authorization',
                    'rollback-fresh-authorization', 'invalidation-owner', 'nonce-last-successful-recovery',
                    'nonce-last-successful-invalidation', 'landing-preserves-recovery-nonce')
        for label in rejected:
            self.assertTrue(self.recovery['recover.hw.'+label]['revert'], label)
        for label in accepted:
            self.assertFalse(self.recovery['recover.hw.'+label]['revert'], label)
        self.assertEqual(self.recovery['recover.hw.rollback-cannot-revive-authorization']['observable']['inbox']['recoveryNonce'], 1)
        self.assertEqual(self.recovery['recover.hw.nonce-last-successful-recovery']['observable']['inbox']['recoveryNonce'], str(2**256-1))
