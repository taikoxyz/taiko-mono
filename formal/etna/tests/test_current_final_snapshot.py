"""Final-R witnesses over a symbolic registry and explicitly admitted inputs."""

from dataclasses import replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]


class FinalSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/final_snapshot.py").is_file(),
            "Z05 final-R model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        import_path = sys.path.copy()
        self.model = import_module("formal.etna.current_rules.final_snapshot")
        self.assertEqual(sys.path, import_path)

    def apply(self, state, *actions):
        for action in actions:
            state = self.model.step(state, action).state
        return state

    def recover(self, *exclusions):
        return self.model.Recover(0, 11, 0, 1000, exclusions)

    def authenticate(self, closed, **updates):
        supplied = self.model.Authenticate(closed.origins[-1], closed.checkpoints[-1])
        return replace(supplied, **updates)

    def observe(self, closed, *actions):
        return self.apply(closed, self.model.Advance(110, 2236), *actions)

    def test_recover_order_does_not_change_selection_from_final_r(self):
        m = self.model
        start = m.initial()
        recovered = self.apply(start, self.recover(0))
        activated = self.apply(start, m.ActivateTopUp(1))
        self.assertEqual(recovered.bonds[1].effective, 5)
        self.assertEqual(activated.bonds[1].effective, 6)
        self.assertEqual(recovered.last_landed, start.last_landed)
        self.assertEqual(recovered.origins[-1], m.Origin(1, 11, 7, 1000))
        with self.assertRaisesRegex(m.Refused, "snapshot block still open"):
            m.step(recovered, self.authenticate(recovered))
        with self.assertRaisesRegex(m.Refused, "authenticated final snapshot"):
            m.step(recovered, m.Select())
        left = self.apply(recovered, m.ActivateTopUp(1), m.Close())
        right = self.apply(activated, self.recover(0), m.Close())
        expected = m.RegistryCheckpoint(7, (m.Entry("A", 6, 2, 5), m.Entry("B", 6, 3, None)))
        self.assertEqual(left.checkpoints[-1], expected)
        self.assertEqual(right.checkpoints[-1], expected)
        for closed in (left, right):
            later = self.observe(closed)
            with self.assertRaisesRegex(m.Refused, "finality authentication"):
                m.step(later, self.authenticate(closed, verified=False))
            with self.assertRaisesRegex(m.Refused, "final checkpoint mismatch"):
                m.step(later, self.authenticate(closed, checkpoint=start.checkpoints[-1]))
            selected = self.apply(later, self.authenticate(closed), m.Select())
            self.assertEqual(selected.committee, m.Committee(1, 2, 7, (("B", 3),)))
            self.assertEqual(selected.last_landed, start.last_landed)
            self.assertTrue(selected.can_sign)

    def test_exclusion_blocks_matured_activation_but_does_not_veto_recover(self):
        m = self.model
        start = m.initial()
        recovered = self.apply(start, self.recover(1))
        self.assertEqual(recovered.bonds[1].pending, 1)
        with self.assertRaisesRegex(m.Refused, "exit already set"):
            m.step(recovered, m.ActivateTopUp(1))
        closed = self.apply(recovered, m.Close())
        self.assertEqual(closed.checkpoints[-1].count, 2)
        authenticated = self.observe(closed, self.authenticate(closed))
        with self.assertRaisesRegex(m.Refused, "empty eligible set"):
            m.step(authenticated, m.Select())
        self.assertFalse(authenticated.can_sign)
        self.assertEqual(authenticated.last_landed, start.last_landed)

    def test_independent_standby_forfeit_before_or_after_recover(self):
        m = self.model
        start = m.initial(withdrawable=False)
        recover = self.recover(0)
        forfeit = m.Forfeit(1, 1000)
        left = self.apply(start, recover, forfeit, m.Close())
        right = self.apply(start, forfeit, recover, m.Close())
        self.assertEqual(left, right)
        self.assertEqual(left.checkpoints[-1].entries, (
            m.Entry("A", 6, 2, 7), m.Entry("B", 2, 3, 7),
        ))
        self.assertEqual(left.bonds[1].pending, 1)
        self.assertTrue(left.bonds[1].forfeited)
        selected = self.observe(left, self.authenticate(left))
        with self.assertRaisesRegex(m.Refused, "empty eligible set"):
            m.step(selected, m.Select())

    def test_lowest_vacancy_reuse_clears_slot_metadata_and_preserves_old_id(self):
        m = self.model
        start = m.initial()
        register = m.Register("C", "owner-C", 4)
        recover = self.recover(0)
        left = self.apply(start, recover, m.Withdraw(0, "owner-A"), register, m.Close())
        right = self.apply(start, m.Withdraw(0, "owner-A"), register, recover, m.Close())
        self.assertEqual(left, right)
        self.assertEqual(left.checkpoints[:-1], start.checkpoints)
        self.assertEqual(left.checkpoints[-1].entries, (
            m.Entry("C", 4, 8, None), m.Entry("B", 5, 3, None),
        ))
        self.assertEqual(left.bonds[0], m.Bond("A", None, None, 2, 0, 5))
        self.assertEqual(left.bonds[2], m.Bond("C", "owner-C", 0, 8, 4))
        next_block = self.apply(left, m.Advance(8, 1012))
        with self.assertRaisesRegex(m.Refused, "no exit to confirm"):
            m.step(next_block, m.ConfirmExit(2))
        with self.assertRaisesRegex(m.Refused, "exit unconfirmed"):
            m.step(next_block, m.Withdraw(2, "owner-C"))
        selected = self.observe(self.apply(next_block, m.Close()), self.authenticate(left), m.Select())
        self.assertEqual(selected.committee.members, (("B", 2),))

    def test_r_plus_one_mutation_leaves_fixed_r_and_landing_uses_selected_cutoff(self):
        m = self.model
        start = m.initial()
        closed = self.apply(start, self.recover(0), m.Close())
        next_block = self.apply(closed, m.Advance(8, 1012),
                                m.ActivateTopUp(1), m.Close())
        self.assertEqual(next_block.checkpoints[-1].entries[1].effective, 6)
        self.assertEqual(next_block.checkpoints[-2], closed.checkpoints[-1])
        view = self.authenticate(closed)
        later = self.observe(next_block)
        with self.assertRaisesRegex(m.Refused, "final checkpoint mismatch"):
            m.step(later, self.authenticate(next_block))
        selected = self.apply(later, view, m.Select())
        self.assertEqual(selected.committee.members, (("B", 2),))
        self.assertEqual(selected.last_landed, start.last_landed)
        with self.assertRaisesRegex(m.Refused, "landing proof or signature"):
            m.step(selected, m.Land(1, 12, 7, verified=False))
        with self.assertRaisesRegex(m.Refused, "landing signing snapshot"):
            m.step(selected, m.Land(1, 12, 8))
        landed = self.apply(selected, m.Land(1, 12, 7))
        self.assertEqual(landed.last_landed, m.Landing(12, 1, 7))
        self.assertEqual(landed.origins, selected.origins)

    def test_non_entry_writes_use_latest_checkpoint_without_creating_one(self):
        m = self.model
        start = m.initial()
        closed = self.apply(start, self.recover(), m.ConfirmExit(0), m.Close())
        self.assertEqual(closed.checkpoints, start.checkpoints)
        self.assertEqual(closed.bonds[0].confirmed_at, 6)
        result = self.observe(closed, self.authenticate(closed), m.Select())
        self.assertEqual(result.committee, m.Committee(1, 2, 7, (("B", 2),)))

    def test_finite_banks_exhaust_with_positive_and_refusal_witnesses(self):
        audit = self.model.assess()
        self.assertEqual(len(audit), 2)
        excludes_new_id = self.recover(2)
        for graph, witnesses in audit:
            self.assertFalse(any(edge.action == excludes_new_id for edge in graph.accepted))
            self.assertTrue(graph.accepted)
            self.assertTrue(graph.refused)
            self.assertGreaterEqual(len(witnesses), 7)
            for witness in witnesses:
                self.assertIn(witness.last.pre, graph.states)
                self.assertEqual(witness.prefix, graph.path_to(witness.last.pre))
        with self.assertRaisesRegex(RuntimeError, "INCONCLUSIVE.*state cap"):
            self.model.assess(max_states=1)

    def test_even_future_exit_blocks_matured_activation(self):
        m = self.model
        requested = self.apply(m.initial(), m.RequestExit(1, "owner-B"))
        self.assertEqual(requested.bonds[1].exit_at, 8)
        with self.assertRaisesRegex(m.Refused, "exit already set"):
            m.step(requested, m.ActivateTopUp(1))
        closed = self.apply(requested, self.recover(0), m.Close())
        selected = self.observe(closed, self.authenticate(closed), m.Select())
        self.assertEqual(selected.committee.members, (("B", 2),))

    def test_new_deposit_changes_transaction_record_without_writing_checkpoint(self):
        m = self.model
        closed = self.apply(m.initial(), m.ActivateTopUp(1), m.Close(), m.Advance(8, 1012))
        deposited = self.apply(closed, m.TopUp(1, "owner-B", 1))
        self.assertEqual((deposited.bonds[1].effective, deposited.bonds[1].pending,
                          deposited.bonds[1].ready_at), (6, 1, 9))
        with self.assertRaisesRegex(m.Refused, "no matured top-up"):
            m.step(deposited, m.ActivateTopUp(1))
        self.assertEqual(self.apply(deposited, m.Close()).checkpoints, closed.checkpoints)

    def test_signer_gate_is_distinct_from_authenticated_committee_derivation(self):
        m = self.model
        closed = self.apply(m.initial(), self.recover(0), m.Close())
        later = self.observe(closed)
        authenticated = self.authenticate(closed, signer_verified=False)
        selected = self.apply(later, authenticated, m.Select())
        self.assertEqual(selected.committee.members, (("B", 2),))
        self.assertFalse(selected.can_sign)
        ready = self.apply(selected, replace(authenticated, signer_verified=True))
        self.assertTrue(ready.can_sign)
        self.assertEqual(ready.last_landed, selected.last_landed)
        for local_state in (later, selected, ready):
            with self.subTest(local_state=local_state):
                landing = m.Landing(12, 1, 7)
                result = m.step(local_state, m.Land(1, 12, 7))
                self.assertEqual(result.state, replace(local_state, last_landed=landing))
                self.assertEqual(result.events, (("Landed", landing),))

    def test_later_legal_recovery_writes_new_origin_without_overwriting_r(self):
        m = self.model
        start = m.initial()
        first = self.apply(start, self.recover(0), m.Close(), m.Advance(8, 1012))
        second = self.apply(first, m.Recover(1, 11, 1, 1012), m.Close())
        self.assertEqual(second.origins[:-1], first.origins)
        self.assertEqual(second.origins[-1], m.Origin(2, 11, 8, 1012))
        self.assertEqual(second.checkpoints, first.checkpoints)
        self.assertEqual(second.last_landed, first.last_landed)
        later = self.apply(second, m.Advance(111, 2248))
        selected = self.apply(later, self.authenticate(second), m.Select())
        self.assertEqual(selected.committee, m.Committee(2, 2, 8, (("B", 2),)))

    def test_symbolic_selection_checks_shape_duplicate_key_and_power(self):
        m = self.model
        origin = m.Origin(1, 11, 7, 1000)
        a = m.Entry("A", 4, 2, None)
        b = m.Entry("B", 5, 3, None)
        c = m.Entry("C", 4, 3, None)
        cases = (
            ((a, b), (("B", 2),)),
            ((a, c), (("C", 2),)),
            ((None, c), (("C", 2),)),
            ((a, None), "invalid checkpoint shape"),
            ((a, a), "duplicate eligible key"),
            ((replace(a, effective=0),), "empty eligible set"),
            ((replace(a, effective=2 * (m.MAX_POWER + 1)),), "invalid committee power"),
        )
        for rows, expected in cases:
            with self.subTest(rows=rows):
                view = m.FinalizedView(origin, m.RegistryCheckpoint(7, rows), True)
                if isinstance(expected, str):
                    with self.assertRaisesRegex(m.Refused, expected):
                        m.derive(view)
                else:
                    self.assertEqual(m.derive(view).members, expected)

    def test_landed_exit_needs_full_delay_and_highest_slot_withdrawal_shrinks_count(self):
        m = self.model
        closed = self.apply(m.initial(withdrawable=False), self.recover(1), m.Close())
        later = self.apply(closed, m.Advance(110, 2236))
        with self.assertRaisesRegex(m.Refused, "landed snapshot precedes exit"):
            m.step(later, m.ConfirmExit(1))
        confirmed = self.apply(later, m.Land(1, 12, 7), m.ConfirmExit(1))
        self.assertEqual(confirmed.bonds[1].confirmed_at, 110)
        with self.assertRaisesRegex(m.Refused, "withdrawal delay not elapsed"):
            m.step(confirmed, m.Withdraw(1, "owner-B"))
        removed = self.apply(confirmed, m.Close(), m.Advance(111, 2248),
                             m.Withdraw(1, "owner-B"), m.Close())
        self.assertEqual(removed.checkpoints[:-1], closed.checkpoints)
        self.assertEqual(removed.checkpoints[-1],
                         m.RegistryCheckpoint(111, (m.Entry("A", 6, 2, None),)))
        self.assertEqual(removed.last_landed, m.Landing(12, 1, 7))

    def test_fixed_origin_preserves_full_timestamp_word(self):
        m = self.model
        start_closed = self.apply(m.initial(), m.Close())
        timestamp = 2**48
        try:
            next_block = self.apply(start_closed, m.Advance(8, timestamp))
        except m.Refused as error:
            self.fail(f"valid uint256 timestamp {timestamp} refused: {error}")
        first = self.apply(next_block, m.Recover(0, 11, 0, timestamp), m.Close())
        self.assertEqual(first.origins[-1], m.Origin(1, 11, 8, timestamp))
        maximum = 2**256 - 1
        second = self.apply(first, m.Advance(110, maximum), m.Recover(1, 11, 1, maximum), m.Close())
        self.assertEqual(second.origins[-1], m.Origin(2, 11, 110, maximum))
        self.assertEqual(second.origins[:-1], first.origins)
        with self.assertRaisesRegex(m.Refused, "clock must advance within range"):
            m.step(second, m.Advance(111, 2**256))

    def test_recovery_bank_requires_prior_finalized_issuance_for_exclusion(self):
        m = self.model
        start = m.initial()
        excludes_new_id = self.recover(2)
        self.assertIn(excludes_new_id, tuple(m.actions(start)))
        with self.assertRaisesRegex(m.Refused, "unissued bond"):
            m.step(start, excludes_new_id)
        issued = self.apply(start, m.Withdraw(0, "owner-A"), m.Register("C", "owner-C", 4))
        self.assertEqual(issued.bonds[2].key, "C")
        # Contract execution sees the issued ID. The compliant authorization
        # bank cannot have verified this same-block issuance before authorizing.
        raw_call = self.apply(issued, excludes_new_id)
        self.assertEqual(raw_call.bonds[2].exit_at, 7)
        self.assertNotIn(excludes_new_id, tuple(m.actions(issued)))

    def test_exit_sentinel_at_maximum_block_preserves_full_projected_frame(self):
        m = self.model
        block = 2**48 - 1
        start = self.apply(m.initial(withdrawable=False), m.Close(), m.Advance(block, 1012))
        origin = m.Origin(1, 11, block, 1012)
        recovered = replace(start, origins=start.origins + (origin,), nonce=1, pending_update=())
        forfeited_bond = replace(start.bonds[1], effective=2, forfeited=True)
        forfeited = replace(start, bonds=(start.bonds[0], forfeited_bond), sink=3, entry_changed=True)
        checkpoint = m.RegistryCheckpoint(block, (m.Entry("A", 6, 2, None), m.Entry("B", 2, 3, None)))
        cases = (
            (m.Recover(0, 11, 0, 1012, (1,)), recovered,
             (("Recovered", origin, 1, (1,)),), start.checkpoints, ()),
            (m.Forfeit(1, 1012), forfeited, (("Forfeited", 1, "incident", 6, 3),),
             start.checkpoints + (checkpoint,), (("Checkpoint", checkpoint),)),
        )
        for action, state, events, checkpoints, close_events in cases:
            with self.subTest(action=action):
                result = m.step(start, action)
                self.assertEqual((result.state, result.events), (state, events))
                self.assertIsNone(result.state.bonds[1].exit_at)
                final = m.step(result.state, m.Close())
                self.assertEqual(final.state, replace(state, closed=True, entry_changed=False, checkpoints=checkpoints))
                self.assertEqual(final.events, close_events)
                m.check(start, action, result)
                m.check(result.state, m.Close(), final)
