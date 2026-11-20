"""Literal observations for recovery exclusion, FI blanking, and replay."""

from dataclasses import astuple, replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]
MAX48 = 281474976710655
MAX256 = 2**256 - 1
EMPTY_HASH = bytes.fromhex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")


class CurrentRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/recovery.py").is_file(),
            "Z03 recovery model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        self.model = import_module("formal.etna.current_rules.recovery")
        self.explorer = import_module("formal.etna.current_rules.explorer")
        self.start = self.model.initial()
        self.recover = self.model.Recover(0, 30, 0, 1000)

    def refused(self, state, action, reason):
        before = astuple(state)
        with self.assertRaisesRegex(self.explorer.Refused, reason):
            self.model.step(state, action)
        self.assertEqual(astuple(state), before)

    def test_fixture_retains_distinct_confirmation_and_rotation_snapshots(self):
        self.assertEqual(self.start.schedule, (0, 1, 2600, 2700))
        self.assertEqual(tuple(map(astuple, self.start.landings)), (
            (21, 20, 0, 7, "el-21", "comet-21", 70),
            (30, 21, 0, 7, "el-30", "comet-30", 80),
        ))
        self.assertEqual(self.start.bonds[0].registry_update_block, 64)
        bond = self.start.bonds[1]
        self.assertEqual(
            (bond.registry_update_block, bond.exit_effective, bond.exit_confirmed), (69, 70, 75),
        )
        edge = next(action for action in self.model.actions(self.start)
                    if isinstance(action, self.model.Land))
        self.assertEqual(astuple(edge.record), (31, 30, 0, 8, "el-31", "comet-31", 96))

    def test_withdrawn_issued_exclusion_does_not_target_replacement(self):
        result = self.model.step(self.start, replace(self.recover, exclusions=(0,)))
        self.assertEqual(result.state.slots, (2, 1))
        self.assertEqual(astuple(result.state.bonds[0]), (
            0, None, "key-0", None, 49, 0, 0, None, 60, None, True, True, 64,
        ))
        self.assertEqual(astuple(result.state.bonds[2]), (
            2, 0, "key-2", "owner-2", 68, 13, 4, 102, None, None, False, False, 65,
        ))
        self.assertEqual(result.state.bonds, self.start.bonds)
        self.assertEqual(result.events, (
            ("Recovered", 1, 30, 100, 1000, 1, (0,), ()),
            ("RulesScheduleUpdated", 0xA28_000000000001_000000000000),
        ))

    def test_combined_exclusions_and_fi_only_change_listed_fields(self):
        result = self.model.step(
            self.start, replace(self.recover, exclusions=(0, 1, 2), fi_to_clear=(7,)),
        )
        post = result.state
        self.assertEqual(post.bonds, (
            self.start.bonds[0],
            self.start.bonds[1],
            replace(self.start.bonds[2], exit_effective=100, registry_update_block=100),
        ))
        self.assertEqual(astuple(post.bonds[1]), (
            1, 1, "key-1", "owner-1", 55, 13, 4, 65, 70, 75, False, False, 69,
        ))
        self.assertEqual(tuple(map(astuple, post.fi)), (
            (7, EMPTY_HASH, 976, 98, 30_000_000_000),
            (8, bytes.fromhex("22" * 32), 988, 99, 45_000_000_000),
        ))
        self.assertEqual(post.landings, self.start.landings)
        self.assertEqual(astuple(post.landings[-1]), (30, 21, 0, 7, "el-30", "comet-30", 80))
        self.assertEqual((post.fi_head, post.fi_tail, post.inbox_balance), (7, 9, 75_000_000_000))
        self.assertEqual((post.active_snapshot, post.sink, post.schedule), (80, 0, (0, 1, 2600, 0)))
        self.assertEqual(tuple(map(astuple, post.origins)), ((0, 2, 50, 400), (1, 30, 100, 1000)))
        self.assertEqual(result.events, (
            ("Recovered", 1, 30, 100, 1000, 1, (0, 1, 2), (7,)),
            ("RulesScheduleUpdated", 0xA28_000000000001_000000000000),
        ))

    def test_live_exit_moves_only_earlier_and_keeps_confirmation(self):
        delayed_exit = replace(self.start.bonds[2], exit_effective=130)
        seed = replace(self.start, bonds=(*self.start.bonds[:2], delayed_exit))
        result = self.model.step(seed, replace(self.recover, exclusions=(1, 2)))
        self.assertEqual(astuple(result.state.bonds[2]), (
            2, 0, "key-2", "owner-2", 68, 13, 4, 102, 100, None, False, False, 100,
        ))
        self.assertEqual(result.state.bonds[1], self.start.bonds[1])

    def test_unissued_last_bond_leaves_earlier_exit_and_fi_unchanged(self):
        self.refused(
            self.start,
            replace(self.recover, exclusions=(2, 3), fi_to_clear=(7,)),
            "unissued",
        )

    def test_invalid_last_fi_index_leaves_earlier_fi_and_exit_unchanged(self):
        self.refused(self.start, replace(self.recover, exclusions=(2,), fi_to_clear=(7, 9)), "FI range")
        self.refused(self.start, replace(self.recover, fi_to_clear=(6,)), "FI range")
        landed = self.model.step(self.start, self.landing()).state
        call = replace(self.recover, expected_c=31, fi_to_clear=(7,))
        self.refused(landed, call, "FI range")
        accepted = self.model.step(landed, replace(call, fi_to_clear=(8,))).state
        self.assertEqual((accepted.fi_head, accepted.fi_tail, accepted.inbox_balance), (8, 9, 75_000_000_000))
        self.assertEqual(tuple(item.tx_hash for item in accepted.fi), (bytes.fromhex("11" * 32), EMPTY_HASH))

    def test_duplicate_and_descending_lists_refuse(self):
        for fields, reason in (
            ({"exclusions": (2, 1)}, "bond order"), ({"exclusions": (2, 2)}, "bond order"),
            ({"fi_to_clear": (8, 7)}, "FI order"), ({"fi_to_clear": (7, 7)}, "FI order"),
        ):
            with self.subTest(fields=fields):
                self.refused(self.start, replace(self.recover, **fields), reason)

    def test_recovery_caller_init_start_exact_guards_and_deadline(self):
        for state, fields, reason in (
            (self.start, {"caller": "operator"}, "Inbox owner"),
            (replace(self.start, initialized=False), {}, "initialization"),
            (replace(self.start, started=False), {}, "start missing"),
            (self.start, {"expected_generation": 1}, "stale generation"),
            (self.start, {"expected_c": 29}, "stale checkpoint"),
            (self.start, {"expected_nonce": 1}, "stale nonce"),
            (self.start, {"valid_until": 999}, "expired"),
            (self.start, {"valid_until": MAX256 + 1}, "uint256"),
            (self.start, {"expected_c": MAX48 + 1}, "uint48"),
        ):
            with self.subTest(reason=reason):
                self.refused(state, replace(self.recover, **fields), reason)
        self.assertEqual(self.model.step(self.start, self.recover).state.generation, 1)
        self.assertEqual(
            self.model.step(self.start, replace(self.recover, valid_until=MAX256)).state.nonce, 1,
        )

    def test_incompatible_structural_rules_refuse_before_list_effects(self):
        for rules in (1, 3):
            with self.subTest(rules=rules):
                self.refused(
                    self.start,
                    replace(self.recover, rules=rules, exclusions=(2,), fi_to_clear=(7,)),
                    "structural rules",
                )
        result = self.model.step(self.start, replace(self.recover, rules=2))
        self.assertEqual(result.state.schedule, (2, 2, 0, 0))
        self.assertEqual(result.events, (
            ("Recovered", 1, 30, 100, 1000, 1, (), ()),
            ("RulesScheduleUpdated", 0x2_000000000002),
        ))

    def test_repeated_recovery_keeps_previous_origins_and_allows_already_blank(self):
        m = self.model
        first = m.step(self.start, replace(self.recover, fi_to_clear=(7,))).state
        later = m.step(first, m.AdvanceBlock(101, 1012)).state
        repeat = m.Recover(1, 30, 1, 1012, fi_to_clear=(7,))
        self.assertNotIn(repeat, tuple(m.actions(later)))
        result = m.step(later, repeat)
        self.assertEqual(result.state.fi, first.fi)
        self.assertEqual(result.state.landings, self.start.landings)
        records = ((0, 2, 50, 400), (1, 30, 100, 1000), (2, 30, 101, 1012))
        self.assertEqual(tuple(map(astuple, result.state.origins)), records)
        self.assertEqual(astuple(m.origin_at(result.state, 1)), records[1])
        with self.assertRaisesRegex(self.explorer.Refused, "origin missing"):
            m.origin_at(result.state, 3)
        self.refused(later, replace(self.recover, valid_until=1012), "stale generation")

    def landing(self):
        return self.model.Land(self.model.Landing(31, 30, 0, 8, "el-31", "comet-31", 96))

    def test_landing_and_rollback_cannot_revive_fixed_authorization(self):
        m = self.model
        landed = m.step(self.start, self.landing()).state
        self.assertEqual((landed.generation, landed.c, landed.nonce), (0, 31, 0))
        self.refused(landed, self.recover, "stale checkpoint")
        rolled_back = m.step(landed, m.Rollback(30)).state
        self.assertEqual((rolled_back.generation, rolled_back.c, rolled_back.nonce), (0, 30, 1))
        self.assertEqual((rolled_back.fi_head, rolled_back.active_snapshot), (7, 80))
        self.assertEqual(rolled_back.landings, self.start.landings)
        self.assertEqual(rolled_back.origins, self.start.origins)
        self.assertEqual(rolled_back.bonds, self.start.bonds)
        self.refused(rolled_back, self.recover, "stale nonce")
        recovered = m.step(rolled_back, replace(self.recover, expected_nonce=1)).state
        self.assertEqual((recovered.generation, recovered.c, recovered.nonce), (1, 30, 2))
        self.refused(recovered, self.landing(), "stale landing generation")

    def test_rollback_keeps_newer_origin_and_clears_uncovered_confirmations(self):
        m = self.model
        old, exiting, replacement = self.start.bonds
        exiting = replace(exiting, exit_effective=94, exit_confirmed=None, registry_update_block=93)
        seed = replace(self.start, bonds=(old, exiting, replacement))
        landed = m.step(seed, self.landing()).state
        # Selected state after a separate confirmation in the landing block.
        confirmed = replace(exiting, exit_confirmed=100)
        landed = replace(landed, bonds=(old, confirmed, replacement))
        recovered = m.step(landed, replace(self.recover, expected_c=31)).state
        result = m.step(recovered, m.Rollback(30)).state
        self.assertEqual((result.generation, result.c, result.nonce), (1, 30, 2))
        self.assertEqual(tuple(map(astuple, result.origins)), ((0, 2, 50, 400), (1, 31, 100, 1000)))
        self.assertEqual(result.bonds, seed.bonds)
        self.assertTrue(result.bonds[0].forfeited)
        landing = m.Land(m.Landing(31, 30, 1, 8, "el-new", "comet-new", 96))
        self.refused(result, landing, "origin above checkpoint")
        restarted = m.step(result, m.Recover(1, 30, 2, 1000)).state
        later = m.step(restarted, m.AdvanceBlock(101, 1012)).state
        fresh_landing = m.Land(replace(landing.record, generation=2, active_snapshot=100))
        post = m.step(later, fresh_landing).state
        self.assertEqual((post.c, post.fi_head, post.active_snapshot), (31, 8, 100))

    def test_independent_forfeit_survives_later_atomic_recovery_refusal(self):
        m = self.model
        invalidated = m.step(self.start, m.InvalidateNonce(0)).state
        forfeited = m.step(invalidated, m.Forfeit(2, "incident", 1000))
        self.assertEqual(forfeited.events, (("Forfeited", 2, "incident", 17, 6),))
        post = forfeited.state
        self.assertEqual((post.generation, post.c, post.nonce, post.sink), (0, 30, 1, 6))
        self.assertEqual(astuple(post.bonds[2]), (
            2, 0, "key-2", "owner-2", 68, 7, 4, 102, 100, None, False, True, 100,
        ))
        self.refused(post, self.recover, "stale nonce")
        self.refused(post, replace(self.recover, expected_nonce=1, fi_to_clear=(7, 9)), "FI range")
        accepted = m.step(post, replace(self.recover, expected_nonce=1, exclusions=(2,))).state
        self.assertEqual((accepted.bonds, accepted.sink), (post.bonds, 6))

    def test_only_initialized_owner_can_invalidate_matching_nonce(self):
        m = self.model
        for seed, action, reason in (
            (replace(self.start, initialized=False), m.InvalidateNonce(0), "initialization"),
            (self.start, m.InvalidateNonce(0, caller="operator"), "Inbox owner"),
            (self.start, m.InvalidateNonce(1), "stale nonce"),
        ):
            with self.subTest(reason=reason):
                self.refused(seed, action, reason)
        prestart = replace(self.start, started=False, landings=(), origins=())
        result = m.step(prestart, m.InvalidateNonce(0))
        self.assertEqual(result.state, replace(prestart, nonce=1))
        self.assertEqual(result.events, (("RecoveryNonceInvalidated", 0, 1),))

    def test_uint48_generation_and_uint256_nonce_do_not_wrap(self):
        m = self.model
        near = replace(self.start, generation=MAX48 - 1, nonce=MAX256 - 1)
        action = m.Recover(MAX48 - 1, 30, MAX256 - 1, 1000)
        post = m.step(near, action).state
        self.assertEqual((post.generation, post.nonce), (MAX48, MAX256))
        self.assertEqual(astuple(m.origin_at(post, MAX48)), (MAX48, 30, 100, 1000))
        self.refused(replace(post, nonce=0), m.Recover(MAX48, 30, 0, 1000), "uint48")
        near_full = replace(self.start, nonce=MAX256 - 1)
        invalidated = m.step(near_full, m.InvalidateNonce(MAX256 - 1))
        self.assertEqual(invalidated.state, replace(near_full, nonce=MAX256))
        self.assertEqual(invalidated.events, (("RecoveryNonceInvalidated", MAX256 - 1, MAX256),))
        full = replace(self.start, nonce=MAX256)
        self.refused(full, replace(self.recover, expected_nonce=MAX256), "uint256")
        self.refused(full, m.InvalidateNonce(MAX256), "uint256")
        landed = m.step(full, self.landing()).state
        self.refused(landed, m.Rollback(30), "uint256")
        at_limit = replace(self.start, nonce=3)
        outside_bank = m.InvalidateNonce(3)
        self.assertNotIn(outside_bank, tuple(m.actions(at_limit)))
        invalidated = m.step(at_limit, outside_bank)
        self.assertEqual(invalidated.state, replace(at_limit, nonce=4))
        self.assertEqual(invalidated.events, (("RecoveryNonceInvalidated", 3, 4),))

    def test_declared_graph_contains_shortest_acceptance_and_refusal_histories(self):
        m = self.model
        graph = self.explorer.explore(self.start, m.actions, m.step, m.check, max_states=2000)
        accepted = {len(graph.path_to(edge.pre)) + 1 for edge in graph.accepted
                    if isinstance(edge.action, m.Recover) and edge.action.exclusions == (0,)}
        self.assertEqual(min(accepted), 1)

        first_landing = next(edge for edge in graph.accepted
                             if edge.pre == self.start and isinstance(edge.action, m.Land))
        rollback = next(edge for edge in graph.accepted
                        if edge.pre == first_landing.post and isinstance(edge.action, m.Rollback))
        invalidation = next(edge for edge in graph.accepted
                            if edge.pre == self.start and isinstance(edge.action, m.InvalidateNonce))
        self.assertEqual(invalidation.events, (("RecoveryNonceInvalidated", 0, 1),))
        self.assertEqual(graph.path_to(first_landing.post), (first_landing,))
        # Invalidation is a shorter route to the same state as rollback.
        self.assertEqual(len(graph.path_to(rollback.post)), 1)
        self.assertTrue(any(edge.action == self.recover and edge.pre == rollback.post
                            and edge.reason == "stale nonce" for edge in graph.refused))
        self.assertTrue(any(
            edge.action == replace(self.recover, exclusions=(2, 3), fi_to_clear=(7,))
            and edge.pre == self.start and edge.reason == "unissued bond"
            for edge in graph.refused
        ))

    def test_max_uint48_block_preserves_unset_exit_sentinel(self):
        m = self.model
        seed = replace(self.start, block=MAX48)
        exclusion = replace(self.recover, exclusions=(2,))
        result = m.step(seed, exclusion)
        self.assertEqual(result.state.bonds, seed.bonds)
        self.assertEqual(astuple(m.origin_at(result.state, 1)), (1, 30, MAX48, 1000))
        m.check(seed, exclusion, result)

        forfeit = m.Forfeit(2, "incident", 1000)
        forfeited = m.step(seed, forfeit)
        self.assertEqual(astuple(forfeited.state.bonds[2]), (
            2, 0, "key-2", "owner-2", 68, 7, 4, 102, None, None, False, True, MAX48,
        ))
        m.check(seed, forfeit, forfeited)
