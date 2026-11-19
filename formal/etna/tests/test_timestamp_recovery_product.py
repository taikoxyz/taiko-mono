"""Current timestamp schedule and recovery boundaries, independent of TLC."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "conformance"))
from timestamp_recovery import (
    U48, U256, Schedule, Origin, State, Authorization, Decision, Block,
    pack, schedule_rules, schedule_stop, select_rule, candidate, verify_blocks,
    recover, invalidate, require_progress,
)


class TimestampRecovery(unittest.TestCase):
    def setUp(self):
        self.schedule = Schedule(0, 1, 8, 10)
        self.state = State(self.schedule, 0, 7, 4, 9, 3, 11,
                           (Origin(0, 0, 1, 2),), True, True)
        self.auth = Authorization(0, 7, 4, 20, 2)

    def rules(self, s=None, **overrides):
        args = dict(rules=1, time=9, now=3, max_age=2, owner=True, initialized=True)
        args.update(overrides)
        return schedule_rules(self.schedule if s is None else s, **args)

    def stop(self, s=None, **overrides):
        args = dict(time=11, now=3, max_age=2, owner=True, initialized=True)
        args.update(overrides)
        return schedule_stop(self.schedule if s is None else s, **args)

    def recover(self, state=None, auth=None, **overrides):
        args = dict(owner=True, now=17, number=29)
        args.update(overrides)
        return recover(self.state if state is None else state,
                       self.auth if auth is None else auth, **args)

    def test_slot293_uses_four_low_first_48_bit_fields(self):
        s = Schedule(3, 4, 5, 6)
        self.assertEqual(pack(s), 3 + (4 << 48) + (5 << 96) + (6 << 144))

    def test_same_rule_reschedule_and_exact_new_lead_time(self):
        s, event = self.rules(time=5)
        self.assertEqual(s, Schedule(0, 1, 5, 10))
        self.assertEqual(event, 1 << 48 | 5 << 96 | 10 << 144)

    def test_pending_deadline_is_strict_for_both_calls(self):
        for now in (6, 7):
            with self.subTest(now=now), self.assertRaises(ValueError):
                self.rules(now=now, time=20)
        for now in (8, 9):
            with self.subTest(now=now), self.assertRaises(ValueError):
                self.stop(now=now, time=20)

    def test_promotion_and_failed_promotion_are_atomic(self):
        self.assertEqual(self.rules(now=8, rules=2, time=10)[0], Schedule(1, 2, 10, 10))
        original = self.schedule
        with self.assertRaises(ValueError):
            self.rules(now=8, rules=3, time=10)
        self.assertEqual(self.schedule, original)

    def test_rules_and_stop_cancellation_values(self):
        self.assertEqual(self.rules(time=U48)[0], Schedule(0, 1, U48, 10))
        self.assertEqual(self.stop(time=0)[0], Schedule(0, 1, 8, 0))

    def test_schedule_owner_initialization_and_rule_number(self):
        for function in (self.rules, self.stop):
            for change in (dict(owner=False), dict(initialized=False)):
                with self.subTest(function=function.__name__, change=change), self.assertRaises(ValueError):
                    function(**change)
        for rules in (0, 3):
            with self.subTest(rules=rules), self.assertRaises(ValueError):
                self.rules(rules=rules)

    def test_exact_field_widths_boolean_aliases_and_sum_overflow(self):
        for change in (dict(rules=U48+1), dict(time=U48+1), dict(rules=True),
                       dict(time=True), dict(max_age=-1), dict(owner=1)):
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.rules(**change)
        for function in (self.rules, self.stop):
            with self.subTest(function=function.__name__), self.assertRaises(ValueError):
                function(Schedule(0, 0, 0, 0), now=U256, max_age=1, time=0)

    def test_activation_is_inclusive(self):
        self.assertEqual(select_rule(self.schedule, 7), 0)
        self.assertEqual(select_rule(self.schedule, 8), 1)
        self.assertEqual(select_rule(self.schedule, 9), 1)

    def test_stop_compares_parent_and_allows_first_crossing(self):
        s = Schedule(0, 0, 0, 2)
        args = dict(parent_time=1, bft_time=4, anchor_time=2, max_age=2,
                    supported=frozenset({0}), first=False, origin_time=0,
                    anchor_number=31, origin_number=29, parent_anchor_number=30)
        self.assertEqual(candidate(s, **args), Decision(0, "ACCEPT", 4, 4))
        args.update(parent_time=4, bft_time=5, anchor_time=3)
        self.assertEqual(candidate(s, **args).outcome, "STOP")

    def test_first_bft_and_el_clock_are_distinct(self):
        args = dict(parent_time=4, bft_time=3, anchor_time=3, max_age=2,
                    supported=frozenset({2}), first=True, origin_time=3,
                    anchor_number=31, origin_number=31, parent_anchor_number=40)
        self.assertEqual(candidate(Schedule(2, 2, 0, 0), **args), Decision(2, "ACCEPT", 3, 5))
        with self.assertRaises(ValueError):
            candidate(Schedule(2, 2, 0, 0), **dict(args, bft_time=5))
        with self.assertRaises(ValueError):
            candidate(Schedule(2, 2, 0, 0), **dict(args, anchor_number=30))

    def test_non_grid_execution_block_and_timestamp_do_not_alias(self):
        result, _ = self.recover(auth=self.auth._replace(valid_until=1401), now=1401, number=31)
        self.assertEqual(result.origins[-1], Origin(1, 7, 31, 1401))
        args = dict(parent_time=1403, bft_time=1401, anchor_number=32, anchor_time=1402,
                    parent_anchor_number=99, origin_number=31, max_age=2,
                    supported=frozenset({2}), first=True, origin_time=1401)
        self.assertEqual(candidate(Schedule(2, 2, 0, 0), **args), Decision(2, "ACCEPT", 1401, 1404))
        with self.assertRaises(ValueError):
            candidate(Schedule(2, 2, 0, 0), **dict(args, bft_time=31))
        with self.assertRaises(ValueError):
            candidate(Schedule(2, 2, 0, 0), **dict(args, anchor_number=30))

    def test_unknown_rule_waits_and_cannot_be_proven(self):
        args = dict(parent_time=7, bft_time=8, anchor_time=7, max_age=2,
                    supported=frozenset({0}), first=False, origin_time=0,
                    anchor_number=31, origin_number=29, parent_anchor_number=30)
        self.assertEqual(candidate(self.schedule, **args).outcome, "WAIT")
        block = Block(7, 8, 31, 7, 30, 29, self.schedule, 1, 8, False, 0)
        with self.assertRaises(ValueError):
            verify_blocks((block,), frozenset({0}), max_age=2)

    def test_history_uses_each_blocks_own_anchor_schedule(self):
        old = Schedule(0, 1, 4, 0)
        newer = Schedule(1, 2, 8, 0)
        blocks = (Block(1, 2, 31, 1, 30, 29, old, 0, 2, False, 0),
                  Block(3, 4, 33, 3, 31, 29, old, 1, 4, False, 0),
                  Block(7, 8, 37, 7, 33, 29, newer, 2, 8, False, 0))
        self.assertEqual(verify_blocks(blocks, frozenset({0, 1, 2}), max_age=2), (0, 1, 2))
        with self.assertRaises(ValueError):
            verify_blocks((blocks[0]._replace(schedule=newer),), frozenset({0, 1, 2}), max_age=2)

    def test_unknown_rule_waits_even_when_stop_is_reached(self):
        result = candidate(Schedule(0, 1, 8, 10), parent_time=10, bft_time=11,
                           anchor_number=31, anchor_time=10, parent_anchor_number=30,
                           origin_number=29, max_age=2, supported=frozenset({0}),
                           first=False, origin_time=0)
        self.assertEqual(result, Decision(1, "WAIT", 11, 11))

    def test_nonzero_recovery_full_frame_and_actual_execution_origin(self):
        result, event = self.recover()
        expected = self.state._replace(schedule=Schedule(2, 2, 0, 0), generation=1,
                                       nonce=5, head=7,
                                       origins=self.state.origins + (Origin(1, 7, 29, 17),))
        self.assertEqual(result, expected)
        self.assertEqual(event, 2 | 2 << 48)
        self.assertEqual((result.checkpoint, result.fi_head, result.active_snapshot), (7, 3, 11))

    def test_rules_zero_carries_pending_schedule_but_clears_stop(self):
        result, _ = self.recover(auth=self.auth._replace(rules=0))
        self.assertEqual(result.schedule, Schedule(0, 1, 8, 0))
        self.assertEqual(result.generation, 1)

    def test_recovery_authorization_guards_and_safe_refusal(self):
        for change in (dict(generation=1), dict(checkpoint=6), dict(nonce=3), dict(valid_until=16)):
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.recover(auth=self.auth._replace(**change))
        for state in (self.state._replace(initialized=False), self.state._replace(start_written=False)):
            with self.subTest(state=state), self.assertRaises(ValueError):
                self.recover(state=state)
        with self.assertRaises(ValueError):
            self.recover(owner=False)

    def test_valid_until_equality_and_general_no_stop_recovery(self):
        state = self.state._replace(schedule=Schedule(0, 0, 0, 0))
        auth = self.auth._replace(valid_until=17, rules=1)
        result, _ = self.recover(state, auth)
        self.assertEqual((result.generation, result.schedule), (1, Schedule(1, 1, 0, 0)))

    def test_nonce_invalidation_does_not_touch_other_state(self):
        self.assertEqual(invalidate(self.state, 4, owner=True), self.state._replace(nonce=5))
        for expected, owner in ((3, True), (4, False)):
            with self.subTest(expected=expected, owner=owner), self.assertRaises(ValueError):
                invalidate(self.state, expected, owner=owner)

    def test_recovery_counters_and_rules_cannot_wrap(self):
        maximum_generation = self.state._replace(generation=U48,
            origins=(Origin(U48, 0, 1, 2),))
        for state, auth in ((maximum_generation, self.auth._replace(generation=U48)),
                            (self.state._replace(nonce=U256), self.auth._replace(nonce=U256)),
                            (self.state, self.auth._replace(rules=3))):
            with self.subTest(state=state, auth=auth), self.assertRaises(ValueError):
                self.recover(state, auth)

    def test_forged_boolean_and_mutable_state_are_rejected(self):
        for state in (self.state._replace(generation=False), self.state._replace(nonce=True),
                      self.state._replace(origins=list(self.state.origins)),
                      self.state._replace(schedule=(0, 1, 8, 10))):
            with self.subTest(state=state), self.assertRaises(ValueError):
                self.recover(state)

    def test_static_or_empty_claim_does_not_establish_product_progress(self):
        for receipts in ([], [{"generation": 1, "checkpoint": 8}]):
            with self.subTest(receipts=receipts), self.assertRaises(ValueError):
                require_progress(receipts)

    def test_lookalike_progress_and_boolean_metadata_are_not_evidence(self):
        from timestamp_recovery import same, check_transition, initial, LIMITS
        self.assertFalse(same(frozenset({True}), frozenset({1})))
        forged = [dict(operation=k, input=(), before={}, after={}, accepted=True)
                  for k in (2, 10, 14, 5, 8, 10, 11, 12, 14, 7)]
        with self.assertRaises(ValueError):
            require_progress(forged)
        pre = initial(LIMITS["smoke"])
        with self.assertRaises(ValueError):
            check_transition(pre, pre, 9, (frozenset({True}),), True, LIMITS["smoke"])

    def test_native_cancel_sentinel_maps_only_typed_rules_time(self):
        from timestamp_recovery import raw_schedule, schedule_raw, event, initial, LIMITS, after
        raw = dict(active=999, next=1, time=999, stop=999)
        decoded = raw_schedule(raw)
        self.assertEqual(decoded, Schedule(999, 1, U48, 999))
        self.assertEqual(schedule_raw(decoded), raw)
        self.assertEqual((pack(decoded) >> 96) & U48, U48)
        self.assertEqual(pack(decoded) & U48, 999)
        self.assertEqual((pack(decoded) >> 144) & U48, 999)
        for value in (999.0, True, "999"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                raw_schedule(dict(raw, time=value))
        pre = initial(LIMITS["schedule-safety"])
        args = (1, 999, True)
        self.assertEqual(event(pre, 1, args, True), (0, 1, 999, 0))
        self.assertEqual(raw_schedule(after(pre, 1, args)["schedule"]).time, U48)

    def test_initialized_startless_nonce_invalidation_needs_no_origin(self):
        state = self.state._replace(schedule=Schedule(0, 0, 0, 0), checkpoint=0, head=0,
                                    fi_head=0, origins=(), start_written=False)
        try:
            result = invalidate(state, 4, owner=True)
        except ValueError:
            result = None
        self.assertEqual(result, state._replace(nonce=5))
        with self.assertRaises(ValueError):
            self.recover(state, Authorization(0, 0, 4, 20, 1))
        with self.assertRaises(ValueError):
            invalidate(state._replace(initialized=False), 4, owner=True)
