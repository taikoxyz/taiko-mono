"""Hand-derived boundaries for the unmerged PR22425 symbolic draft model.

These checks provide no runtime, cryptographic or production-unit evidence.
Arbitrary missing sets in isolated probes need not describe quorum-feasible
commits; the helpers do not verify consensus reachability or signatures.
"""

from dataclasses import FrozenInstanceError, replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]


class L2StakingModelTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        self.m = import_module("formal.etna.draft_rules.l2_staking")
        self.config = self.m.Config(2, 2, 2, 2, 1000)
        self.anchor = self.m.Anchor(0, ("F",))

    def initial(self, bonds=(), **kwargs):
        return self.m.initial_state(
            self.config, origin_fallback=("F",), bonds=bonds, **kwargs
        )

    def members(self, selection):
        return tuple(sorted((member.key, member.power) for member in selection.members))

    def snapshot(self, height=7, total=10, members=None):
        if members is None:
            members = (self.m.Member("A", 5),)
        return self.m.Snapshot(height, total, members)

    def test_transactions_reach_next_snapshot_and_third_successor_signers(self):
        state = self.initial((self.m.Bond(0, "A", 10, 0),))
        trace = []
        for height in range(1, 5):
            actions = (self.m.Action("top_up", 0, amount=2),) if height == 1 else ()
            result = self.m.advance(state, self.anchor, actions=actions)
            state = result.state
            trace.append(self.members(state.current_signers))
            if height == 1:
                self.assertEqual(state.snapshot.total_stake, 10)
                self.assertEqual(state.snapshot.members, (self.m.Member("A", 5),))
                self.assertEqual(state.bonds[0].stake, 12)
            if height == 2:
                self.assertEqual(state.snapshot.members, (self.m.Member("A", 6),))
        self.assertEqual(trace, [(("F", 1),), (("F", 1),), (("A", 5),), (("A", 6),)])

    def test_penalty_is_rounded_up_before_snapshot_and_affects_h_plus_two(self):
        config = self.m.Config(2, 20, 2, 1, 1000)
        state = self.m.initial_state(config, origin_fallback=("A",),
                                    bonds=(self.m.Bond(0, "A", 21, 0),))
        state = self.m.advance(state, self.anchor).state
        result = self.m.advance(state, self.anchor, missing_keys=("A",))
        state = result.state
        self.assertEqual(result.penalties, ((0, 3),))
        self.assertEqual(state.bonds[0], self.m.Bond(0, "A", 18))
        self.assertEqual(state.misses, (0, 0))
        self.assertEqual(state.snapshot, self.snapshot(2, 0, ()))
        self.assertEqual(self.members(state.current_signers), (("A", 1),))
        self.assertEqual(self.members(state.next_signers), (("A", 10),))
        self.assertEqual(self.members(state.pending_signers), (("F", 1),))

    def test_parent_live_mapping_does_not_charge_old_key_to_reused_seat(self):
        state = self.m.initial_state(self.config, origin_fallback=("A",),
                                    bonds=(self.m.Bond(0, "A", 10, 0),))
        state = self.m.advance(state, self.anchor, actions=(
            self.m.Action("exit", 0), self.m.Action("register", 1, "B", 10),
        )).state
        result = self.m.advance(state, self.anchor, missing_keys=("A",))
        self.assertEqual(result.miss_bitmap, 0)
        self.assertEqual(result.state.bonds[1], self.m.Bond(1, "B", 10, 0))
        self.assertEqual(result.state.misses, (0, 0))

    def test_top_up_after_penalty_reseats_without_rewriting_snapshot(self):
        config = self.m.Config(2, 20, 2, 1, 1000)
        state = self.m.initial_state(config, origin_fallback=("A",),
                                    bonds=(self.m.Bond(0, "A", 21, 0),))
        state = self.m.advance(state, self.anchor).state
        state = self.m.advance(state, self.anchor, missing_keys=("A",),
                               actions=(self.m.Action("top_up", 0, amount=2),)).state
        self.assertEqual(state.snapshot.members, ())
        self.assertEqual(state.bonds[0], self.m.Bond(0, "A", 20, 0))
        self.assertEqual(state.misses, (0, 0))
        state = self.m.advance(state, self.anchor).state
        self.assertEqual(state.snapshot.members, (self.m.Member("A", 10),))

    def test_fallback_key_with_live_bond_counts_misses(self):
        state = self.initial((self.m.Bond(0, "F", 10, 0),))
        state = self.m.advance(state, self.anchor).state
        result = self.m.advance(state, self.anchor, missing_keys=("F",))
        self.assertEqual(result.miss_bitmap, 1)
        self.assertEqual(result.state.misses, (1, 0))
        result = self.m.advance(result.state, self.anchor, missing_keys=("F",))
        self.assertEqual(result.penalties, ((0, 1),))
        self.assertEqual(result.state.bonds[0].stake, 9)

    def test_nonmissing_block_resets_consecutive_count(self):
        state = self.initial((self.m.Bond(0, "F", 10, 0),))
        state = self.m.advance(state, self.anchor).state
        state = self.m.advance(state, self.anchor, missing_keys=("F",)).state
        state = self.m.advance(state, self.anchor).state
        self.assertEqual(state.misses, (0, 0))
        result = self.m.advance(state, self.anchor, missing_keys=("F",))
        self.assertEqual(result.penalties, ())
        self.assertEqual(result.state.misses, (1, 0))

    def test_failed_block_start_preserves_call_state_but_actions_continue(self):
        state = self.initial((self.m.Bond(0, "F", 10, 0),), generation=3)
        state = self.m.advance(state, self.anchor).state
        state = self.m.advance(state, self.anchor, missing_keys=("F",)).state
        before = state
        result = self.m.advance(state, self.anchor, block_start_ok=False,
                                missing_keys=("F",), actions=(self.m.Action("top_up", 0, amount=2),))
        self.assertFalse(result.call_succeeded)
        self.assertEqual(result.miss_bitmap, 1)
        self.assertEqual(result.penalties, ())
        self.assertEqual(result.state.misses, before.misses)
        self.assertEqual(result.state.snapshot, before.snapshot)
        self.assertEqual(result.state.stored_generation, before.stored_generation)
        self.assertEqual(result.state.bonds[0].stake, 12)
        self.assertEqual(result.state.pending_signers.source, "fallback")
        self.assertEqual(before.bonds[0].stake, 10)

    def test_first_two_sets_use_origin_not_current_anchor_fallback(self):
        state = self.initial()
        anchor = self.m.Anchor(self.m.UINT256_MAX, ("G",))
        observed = []
        for unused in range(3):
            state = self.m.advance(state, anchor).state
            observed.append(self.members(state.current_signers))
        self.assertEqual(observed, [(("F", 1),), (("F", 1),), (("G", 1),)])

    def test_threshold_is_inclusive_and_total_stake_keeps_remainders(self):
        snapshot = self.snapshot(total=11, members=(self.m.Member("A", 5),))
        self.assertEqual(self.m.derive_set(7, snapshot, self.m.Anchor(11, ("F",))).source, "candidate")
        self.assertEqual(self.m.derive_set(7, snapshot, self.m.Anchor(12, ("F",))).source, "fallback")

    def test_maximum_uint256_threshold_disables_equal_maximum_total(self):
        snapshot = self.snapshot(total=self.m.UINT256_MAX)
        selected = self.m.derive_set(7, snapshot, self.m.Anchor(self.m.UINT256_MAX, ("F",)))
        self.assertEqual(self.members(selected), (("F", 1),))
        self.assertEqual(selected.source, "fallback")

    def test_snapshot_height_compares_all_256_bits(self):
        for stored_height in (6, 8, 7 + 2**48, 7 + 2**255):
            with self.subTest(stored_height=stored_height):
                selected = self.m.derive_set(7, self.snapshot(height=stored_height), self.anchor)
                self.assertEqual(selected.source, "fallback")

    def test_invalid_candidate_shapes_fall_back_without_repair(self):
        member = self.m.Member
        invalid = (
            (), (member("A", 0),), (member("A", -1),),
            (member("A", 1), member("A", 2)),
            (member("A", 1, valid_key=False),),
            (member("A", 1, reserved_bits=1),),
            (member("A", self.m.MAX_POWER + 1),),
            (member("A", self.m.MAX_POWER), member("B", 1)),
            (member("A", 2**64 - 1), member("B", 2)),
            tuple(member(f"K{index:03}", 1) for index in range(129)),
        )
        for members in invalid:
            with self.subTest(members=members):
                selected = self.m.derive_set(7, self.snapshot(members=members), self.anchor)
                self.assertEqual(self.members(selected), (("F", 1),))

    def test_exact_power_limit_and_128_members_are_accepted(self):
        selected = self.m.derive_set(7, self.snapshot(members=(self.m.Member("A", self.m.MAX_POWER),)), self.anchor)
        self.assertEqual(selected.source, "candidate")
        members = tuple(self.m.Member(f"K{index:03}", 1) for index in range(128))
        self.assertEqual(self.m.derive_set(7, self.snapshot(members=members), self.anchor).members, members)

    def test_switches_emit_full_key_and_power_difference(self):
        state = self.initial((self.m.Bond(0, "A", 10, 0), self.m.Bond(1, "B", 4, 1)))
        first = self.m.advance(state, self.anchor)
        self.assertEqual(self.members(self.m.Selection(first.updates, "candidate")), (("A", 5), ("B", 2), ("F", 0)))
        second = self.m.advance(first.state, self.m.Anchor(self.m.UINT256_MAX, ("G",)))
        self.assertEqual(self.members(self.m.Selection(second.updates, "fallback")), (("A", 0), ("B", 0), ("G", 1)))
        third = self.m.advance(second.state, self.anchor)
        self.assertEqual(self.members(self.m.Selection(third.updates, "candidate")), (("A", 5), ("B", 2), ("G", 0)))

    def test_same_keys_and_powers_emit_no_update_despite_source_label(self):
        state = self.initial((self.m.Bond(0, "F", 2, 0),))
        result = self.m.advance(state, self.anchor)
        self.assertEqual(result.state.pending_signers.source, "candidate")
        self.assertEqual(result.updates, ())

    def test_recovery_initialization_does_not_retain_old_pending_sets(self):
        old = self.m.advance(self.initial((self.m.Bond(0, "A", 10, 0),)), self.anchor).state
        recovered = self.m.initial_state(self.config, origin=1, generation=1,
                                        origin_fallback=("G",), bonds=old.bonds,
                                        snapshot=old.snapshot)
        self.assertEqual(self.members(old.pending_signers), (("A", 5),))
        self.assertEqual(self.members(recovered.next_signers), (("G", 1),))
        self.assertEqual(self.members(recovered.pending_signers), (("G", 1),))
        failed = self.m.advance(recovered, self.anchor, block_start_ok=False).state
        self.assertEqual(failed.stored_generation, 0)
        self.assertEqual(self.members(failed.current_signers), (("G", 1),))

    def test_recovery_preserves_explicit_checkpoint_miss_counters(self):
        state = self.m.initial_state(self.config, origin=10, generation=1,
                                    origin_fallback=("F",),
                                    bonds=(self.m.Bond(0, "F", 10, 0),),
                                    misses=(1, 0), stored_generation=0)
        failed = self.m.advance(state, self.anchor, block_start_ok=False).state
        self.assertEqual(failed.misses, (1, 0))
        self.assertEqual(failed.stored_generation, 0)
        self.assertEqual(self.m.advance(state, self.anchor).state.misses, (0, 0))

    def test_empty_checkpoint_counter_survives_until_seat_is_taken(self):
        state = self.m.initial_state(self.config, origin=10, generation=1,
                                    origin_fallback=("A",),
                                    bonds=(self.m.Bond(0, "A", 10, None, 9),),
                                    misses=(1, 0))
        state = self.m.advance(state, self.anchor, block_start_ok=False).state
        self.assertEqual(state.misses, (1, 0))
        state = self.m.advance(state, self.anchor, actions=(
            self.m.Action("register", 1, "B", 10),
        )).state
        self.assertEqual(state.bonds[1].seat, 0)
        self.assertEqual(state.misses, (0, 0))
        result = self.m.advance(state, self.anchor, missing_keys=("A",))
        self.assertEqual(result.miss_bitmap, 0)
        self.assertEqual(result.state.misses, (0, 0))

    def test_exit_retains_counter_and_empty_seat_processing_does_not_change_it(self):
        state = self.m.initial_state(self.config, origin=10, generation=1,
                                    origin_fallback=("F",),
                                    bonds=(self.m.Bond(0, "F", 10, 0),), misses=(1, 0))
        state = self.m.advance(state, self.anchor, block_start_ok=False,
                               actions=(self.m.Action("exit", 0),)).state
        self.assertEqual(state.bonds[0].seat, None)
        self.assertEqual(state.misses, (1, 0))
        state = self.m.advance(state, self.anchor).state
        self.assertEqual(state.misses, (1, 0))

    def test_commit_boundaries_include_power_changes_but_ignore_labels_and_order(self):
        member, selection = self.m.Member, self.m.Selection
        sets = {
            2: selection((member("A", 1), member("B", 2)), "candidate"),
            3: selection((member("B", 2), member("A", 1)), "fallback"),
            4: selection((member("A", 2), member("B", 2)), "candidate"),
            5: selection((member("C", 1),), "fallback"),
        }
        self.assertEqual(self.m.required_commits(1, 5, sets), (3, 4, 5))
        self.assertEqual(self.m.required_commits(4, 5, {5: sets[5]}), (5,))
        self.assertEqual(self.m.required_commits(1, 2, {2: sets[2]}), (2,))

    def test_commit_ranges_refuse_missing_or_invalid_sets(self):
        selected = self.m.Selection((self.m.Member("A", 1),), "candidate")
        for parent, last, sets in ((1, 1, {}), (2, 1, {}), (-1, 1, {}),
                                   (0, 2, {2: selected}),
                                   (0, 1, {1: self.m.Selection((), "candidate")})):
            with self.subTest(parent=parent, last=last, sets=sets):
                with self.assertRaises(ValueError):
                    self.m.required_commits(parent, last, sets)

    def test_invalid_actions_refuse_without_mutating_input(self):
        state = self.initial((self.m.Bond(0, "A", 10, 0),))
        for action in (self.m.Action("top_up", 99, amount=1),
                       self.m.Action("top_up", 0, amount=0),
                       self.m.Action("top_up", 0, amount=-1),
                       self.m.Action("register", 1, "A", 2),
                       self.m.Action("register", 0, "B", 2),
                       self.m.Action("unsupported", 0)):
            with self.subTest(action=action):
                with self.assertRaises(ValueError):
                    self.m.advance(state, self.anchor, actions=(action,))
                self.assertEqual(state.height, 0)
                self.assertEqual(state.bonds, (self.m.Bond(0, "A", 10, 0),))

    def test_full_seat_backstop_and_released_lowest_seat(self):
        state = self.initial((self.m.Bond(0, "A", 10, 0), self.m.Bond(1, "B", 4, 1)))
        with self.assertRaises(ValueError):
            self.m.advance(state, self.anchor, actions=(self.m.Action("register", 2, "C", 2),))
        state = self.m.advance(state, self.anchor, actions=(
            self.m.Action("exit", 0), self.m.Action("register", 2, "C", 2),
        )).state
        self.assertEqual(state.bonds[2].seat, 0)
        with self.assertRaises(ValueError):
            self.m.advance(state, self.anchor, actions=(self.m.Action("top_up", 0, amount=2),))

    def test_invalid_numeric_configuration_and_unknown_misses_refuse(self):
        for config in (replace(self.config, vp_unit=0), replace(self.config, n_max=129),
                       replace(self.config, min_stake=1), replace(self.config, miss_limit=0),
                       replace(self.config, miss_slash_bps=10001), replace(self.config, vp_unit=True)):
            with self.subTest(config=config):
                with self.assertRaises(ValueError):
                    self.m.initial_state(config, origin_fallback=("F",))
        state = self.m.advance(self.initial(), self.anchor).state
        with self.assertRaises(ValueError):
            self.m.advance(state, self.anchor, missing_keys=("unknown",))
        with self.assertRaises(ValueError):
            self.m.advance(state, self.m.Anchor(-1, ("F",)))

    def test_state_is_immutable(self):
        state = self.initial((self.m.Bond(0, "A", 10, 0),))
        with self.assertRaises(FrozenInstanceError):
            state.height = 1
        with self.assertRaises(FrozenInstanceError):
            state.bonds[0].stake = 0

    def test_four_member_numerical_penalty_trace_has_feasible_parent_quorums(self):
        # Symbolic already-authenticated inputs; this is no signature check.
        unit = 10**27 // 4
        keys = ("A", "B", "C", "D")
        config = self.m.Config(unit, unit, 4, 2, 1000)
        self.assertEqual(config.min_stake * config.n_max, 10**27)
        self.assertGreaterEqual(config.vp_unit, 867361738)
        members = tuple(self.m.Member(key, 1) for key in keys)
        bonds = tuple(self.m.Bond(index, key, unit, index)
                      for index, key in enumerate(keys))
        state = self.m.initial_state(
            config, origin=10, generation=1, origin_fallback=keys, bonds=bonds,
            snapshot=self.m.Snapshot(10, 10**27, members),
        )
        anchor = self.m.Anchor(0, keys)
        first = self.m.advance(state, anchor)
        self.assertEqual(first.miss_bitmap, 0)  # H11 has no LastCommit.
        state = first.state
        for height in (12, 13):
            parent_total = sum(member.power for member in state.current_signers.members)
            committing_power = sum(member.power for member in state.current_signers.members
                                   if member.key != "A")
            self.assertEqual(parent_total, 4)
            self.assertEqual(committing_power, 3)
            self.assertGreater(3 * committing_power, 2 * parent_total)
            result = self.m.advance(state, anchor, missing_keys=("A",))
            state = result.state
            self.assertEqual(state.height, height)
            self.assertEqual(result.miss_bitmap, 1)
            if height == 12:
                self.assertEqual(result.penalties, ())
                self.assertEqual(state.misses, (1, 0, 0, 0))
        self.assertEqual(result.penalties, ((0, unit // 10),))
        self.assertEqual(state.bonds[0].stake, 9 * unit // 10)
        self.assertLess(state.bonds[0].stake, config.min_stake)
        self.assertIsNone(state.bonds[0].seat)
        self.assertEqual(result.updates, (self.m.Member("A", 0),))
        remaining = tuple(self.m.Member(key, 1) for key in ("B", "C", "D"))
        self.assertEqual(state.snapshot, self.m.Snapshot(13, 3 * unit, remaining))
        self.assertEqual(state.next_signers.members, members)  # H14 keeps A.
        self.assertEqual(state.pending_signers.members, remaining)  # H15 drops A.
        state = self.m.advance(state, anchor).state
        self.assertEqual(state.height, 14)
        self.assertEqual(state.current_signers.members, members)
        state = self.m.advance(state, anchor).state
        self.assertEqual(state.height, 15)
        self.assertEqual(state.current_signers.members, remaining)


if __name__ == "__main__":
    unittest.main()
