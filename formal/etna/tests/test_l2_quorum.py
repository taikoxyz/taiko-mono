"""Source-derived power and lifecycle tests for the symbolic quorum projection."""

from dataclasses import FrozenInstanceError, replace
from importlib import import_module
from itertools import product
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]


class L2QuorumTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        self.m = import_module("formal.etna.draft_rules.l2_staking")
        self.q = import_module("formal.etna.draft_rules.quorum")

    def initial(self, *, bonds=(), config=None, keys=("A", "B", "C", "D")):
        if config is None:
            config = self.m.Config(1, 10, 4, 2, 1000)
        return self.m.initial_state(
            config, origin=10, generation=1, origin_fallback=keys, bonds=bonds
        )

    def selection(self, *key_powers):
        return self.m.Selection(
            tuple(self.m.Member(key, power) for key, power in key_powers), "candidate"
        )

    def commit(self, height, commits, *, nil=(), absent=()):
        return self.q.LastCommit(1, height, tuple(
            self.q.FlagVote(key, flag)
            for flag, keys in (("absent", absent), ("nil", nil), ("commit", commits))
            for key in keys
        ))

    def availability(self, height, keys):
        return self.q.Availability(1, height, tuple(keys))

    def powers(self, selection):
        return tuple(sorted((member.key, member.power) for member in selection.members))

    def test_weighted_strict_threshold_uses_only_commit_flags(self):
        selection = self.selection(("A", 3), ("B", 2), ("C", 1))
        commit = self.commit(11, "AB", nil="C")
        self.assertEqual(self.q.committed_power(selection, commit, generation=1, height=11), 5)
        commit = self.commit(11, "AC", nil="B")
        with self.assertRaises(ValueError):
            self.q.committed_power(selection, commit, generation=1, height=11)

        self.assertEqual(
            self.q.available_power(selection, self.availability(11, "BA"), generation=1, height=11),
            5,
        )
        with self.assertRaises(ValueError):
            self.q.available_power(
                selection, self.availability(11, "AC"), generation=1, height=11
            )

    def test_finite_commit_bank_checks_acceptance_and_refusal(self):
        exact_boundary_cases = 0
        for size in range(1, 5):
            keys = "ABCD"[:size]
            for powers in product((1, 2, 3), repeat=size):
                selection = self.selection(*zip(keys, powers))
                threshold, remainder = divmod(2 * sum(powers), 3)
                for flags in product(("commit", "nil", "absent"), repeat=size):
                    votes = tuple(self.q.FlagVote(key, flag) for key, flag in zip(keys, flags))
                    commit = self.q.LastCommit(1, 11, votes)
                    contributing = sum(power for power, flag in zip(powers, flags)
                                       if flag == "commit")
                    with self.subTest(powers=powers, flags=flags):
                        if contributing >= threshold + 1:
                            self.assertEqual(
                                self.q.committed_power(selection, commit, generation=1, height=11),
                                contributing,
                            )
                        else:
                            with self.assertRaises(ValueError):
                                self.q.committed_power(selection, commit, generation=1, height=11)
                            if remainder == 0 and contributing == threshold:
                                exact_boundary_cases += 1
        self.assertGreater(exact_boundary_cases, 0)

    def test_power_gate_accepts_exact_total_power_cap(self):
        cap = self.m.MAX_POWER
        selection = self.selection(("A", cap - 1), ("B", 1))
        commit = self.commit(11, "A", absent="B")
        available = self.availability(11, "A")
        self.assertEqual(
            self.q.committed_power(selection, commit, generation=1, height=11), cap - 1
        )
        self.assertEqual(
            self.q.available_power(selection, available, generation=1, height=11), cap - 1
        )

    def test_malformed_vote_rows_refuse_even_if_known_commit_power_is_enough(self):
        selection = self.selection(("A", 4), ("B", 1))
        good = self.q.FlagVote("A", "commit")
        invalid_rows = (
            (), (good,), (good, good), (good, self.q.FlagVote("C", "absent")),
            (good, self.q.FlagVote("B", "COMMIT")), (good, self.q.FlagVote("B", None)),
            (good, self.q.FlagVote([], "absent")), (good, ("B", "absent")),
            [good, self.q.FlagVote("B", "absent")],
        )
        for rows in invalid_rows:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                self.q.committed_power(
                    selection, self.q.LastCommit(1, 11, rows), generation=1, height=11
                )

    def test_malformed_availability_refuses_even_if_known_power_is_enough(self):
        selection = self.selection(("A", 4), ("B", 1))
        for keys in ((), ("A", "A"), ("A", "C"), ("A", ""), ("A", []), ["A"], "A"):
            with self.subTest(keys=keys), self.assertRaises(ValueError):
                self.q.available_power(
                    selection, self.q.Availability(1, 11, keys), generation=1, height=11
                )

    def test_helpers_refuse_invalid_signing_sets(self):
        member = self.m.Member
        malformed = (
            None, self.m.Selection((member("A", 1),), "unknown"),
            self.m.Selection((), "candidate"), self.selection(("A", 0)),
            self.selection(("A", True)), self.selection(("A", 1), ("A", 1)),
            self.selection(("A", self.m.MAX_POWER), ("B", 1)),
            self.m.Selection([member("A", 1)], "candidate"),
            self.m.Selection((member("A", 1, valid_key=False),), "candidate"),
            self.m.Selection((member("A", 1, reserved_bits=1),), "candidate"),
            self.m.Selection(tuple(member(f"K{index}", 1) for index in range(129)), "candidate"),
        )
        for selection in malformed:
            with self.subTest(selection=selection):
                with self.assertRaises(ValueError):
                    self.q.committed_power(
                        selection, self.commit(11, "A"), generation=1, height=11
                    )
                with self.assertRaises(ValueError):
                    self.q.available_power(
                        selection, self.availability(11, "A"), generation=1, height=11
                    )

    def test_non_candidate_power_helpers_require_unit_weights(self):
        weighted = self.selection(("A", 3), ("B", 1))
        for validate, premise in (
            (self.q.committed_power, self.commit(11, "A", absent="B")),
            (self.q.available_power, self.availability(11, "A")),
        ):
            self.assertEqual(validate(weighted, premise, generation=1, height=11), 3)
            for source in ("origin", "fallback"):
                with self.subTest(validate=validate.__name__, source=source):
                    with self.assertRaises(ValueError):
                        validate(replace(weighted, source=source), premise,
                                 generation=1, height=11)

    def test_helpers_check_exact_bounded_domain_fields(self):
        selection = self.selection(("A", 1))
        cases = {
            "generation": (True, 1.0, -1, 2, 2**48),
            "height": (False, 11.0, -1, 12, 2**48),
        }
        for validate, premise in (
            (self.q.committed_power, self.commit(11, "A")),
            (self.q.available_power, self.availability(11, "A")),
        ):
            for field, values in cases.items():
                for value in values:
                    with self.subTest(validate=validate.__name__, field=field, value=value):
                        with self.assertRaises(ValueError):
                            validate(selection, replace(premise, **{field: value}),
                                     generation=1, height=11)
                        expected = {"generation": 1, "height": 11}
                        expected[field] = value
                        with self.assertRaises(ValueError):
                            validate(selection, premise, **expected)
            with self.assertRaises(ValueError):
                validate(selection, None, generation=1, height=11)

    def test_origin_requires_no_parent_and_current_origin_availability(self):
        origin = self.initial()
        anchor = self.m.Anchor(0, ("F",))
        available = self.availability(11, "ABC")
        for parent in (self.commit(10, "ABCD"), self.q.LastCommit(1, 10, ())):
            with self.subTest(parent=parent), self.assertRaises(ValueError):
                self.q.advance_with_quorum(origin, anchor, parent=parent, available=available)
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                origin, anchor, parent=None, available=available,
                previous_available=self.availability(10, "ABCD"),
            )
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                origin, anchor, parent=None, available=self.availability(11, "F")
            )
        first = self.q.advance_with_quorum(origin, anchor, parent=None, available=available)
        self.assertEqual(first.miss_bitmap, 0)
        self.assertEqual(first.state.height, 11)
        self.assertEqual(self.powers(first.state.current_signers),
                         (("A", 1), ("B", 1), ("C", 1), ("D", 1)))
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                first.state, anchor, parent=None, available=self.availability(12, "ABCD")
            )

    def test_previous_availability_refuses_offline_nil_and_commit(self):
        anchor = self.m.Anchor(0, ("F",))
        previous = self.availability(11, "ABC")
        first = self.q.advance_with_quorum(
            self.initial(), anchor, parent=None, available=previous
        )
        available = self.availability(12, "ABCD")
        absent = self.commit(11, "ABC", absent="D")
        offline_votes = (self.commit(11, "ABC", nil="D"), self.commit(11, "ABCD"))
        for parent in offline_votes:
            with self.subTest(parent=parent), self.assertRaises(ValueError):
                self.q.advance_with_quorum(
                    first.state, anchor, parent=parent, available=available, previous_available=previous
                )
        for malformed in (replace(previous, height=12), replace(previous, generation=0),
                          self.availability(11, "AB"), self.availability(11, "ABCDF")):
            with self.subTest(previous=malformed), self.assertRaises(ValueError):
                self.q.advance_with_quorum(
                    first.state, anchor, parent=absent, available=available,
                    previous_available=malformed,
                )
        self.assertEqual(self.q.advance_with_quorum(
            first.state, anchor, parent=absent, available=available, previous_available=previous
        ).state.height, 12)
        self.assertEqual(self.q.advance_with_quorum(
            first.state, anchor, parent=offline_votes[0], available=available
        ).state.height, 12)

    def test_seven_height_trace_slashes_and_delays_fallback_then_retries(self):
        unit = 10**27 // 4
        config = self.m.Config(unit, unit, 4, 2, 1000)
        origin = self.initial(
            config=config,
            bonds=tuple(self.m.Bond(index, key, unit, index) for index, key in enumerate("ABCD")),
        )
        anchor = self.m.Anchor(4 * unit, ("B", "C", "D", "F"))
        # The H13 penalty drops the H13 snapshot below the threshold. The
        # fallback signs from H15 and can omit one, but cannot lose two.
        rows = (
            (11, "ABCD", None, "ABCD", "candidate", 0, 0, 4),
            (12, "ABCD", self.commit(11, "BCD", nil="A"), "ABCD", "candidate", 1, 1, 4),
            (13, "ABCD", self.commit(12, "BCD", absent="A"), "ABCD", "fallback", 1, 0, 3),
            (14, "ABCD", self.commit(13, "BCD", absent="A"), "ABCD", "fallback", 0, 0, 3),
            (15, "BCD", self.commit(14, "ABCD"), "BCDF", "fallback", 0, 0, 3),
            (16, "BCDF", self.commit(15, "BCD", absent="F"), "BCDF", "fallback", 0, 0, 3),
            (17, "BCDF", self.commit(16, "BCDF"), "BCDF", "fallback", 0, 0, 3),
        )
        state, previous = origin, None
        for height, online, parent, signers, source, bitmap, count, total_units in rows:
            with self.subTest(height=height):
                if height == 15:
                    stalled = self.availability(15, "BC")
                    unchanged = state
                    with self.assertRaises(ValueError):
                        self.q.advance_with_quorum(
                            state, anchor, parent=parent, available=stalled,
                            previous_available=previous, actions=(self.m.Action("exit", 1),),
                            block_start_ok=False,
                        )
                    self.assertEqual(state, unchanged)
                    self.assertEqual(state.height, 14)
                    self.assertEqual(state.bonds[1], self.m.Bond(1, "B", unit, 1))
                    self.assertEqual(previous, self.availability(14, "ABCD"))

                available = self.availability(height, online)
                result = self.q.advance_with_quorum(
                    state, anchor, parent=parent, available=available, previous_available=previous
                )
                state, previous = result.state, available
                self.assertEqual(state.height, height)
                self.assertEqual(self.powers(state.current_signers), tuple((key, 1) for key in signers))
                self.assertEqual(state.pending_signers.source, source)
                self.assertEqual(state.snapshot.total_stake, total_units * unit)
                self.assertEqual(result.miss_bitmap, bitmap)
                self.assertEqual(state.misses, (count, 0, 0, 0))
                if height == 13:
                    self.assertEqual(result.penalties, ((0, unit // 10),))
                    self.assertEqual(state.bonds[0], self.m.Bond(0, "A", 9 * unit // 10))
                    self.assertEqual(result.updates, (self.m.Member("A", 0), self.m.Member("F", 1)))
                else:
                    self.assertEqual(result.penalties, ())

    def test_same_key_power_change_uses_parent_and_current_weights_separately(self):
        state = self.initial(
            config=self.m.Config(1, 1, 3, 2, 1000), keys=("A", "B", "C"),
            bonds=tuple(self.m.Bond(index, key, stake, index)
                        for index, (key, stake) in enumerate((("A", 7), ("B", 1), ("C", 1)))),
        )
        candidate = self.m.Anchor(0, ("A", "B", "C"))
        fallback = self.m.Anchor(self.m.UINT256_MAX, ("A", "B", "C"))
        a11 = self.availability(11, "ABC")
        a12 = self.availability(12, "ABC")
        a13 = self.availability(13, "A")
        a14 = self.availability(14, "ABC")
        h11 = self.q.advance_with_quorum(state, candidate, parent=None, available=a11).state
        h12 = self.q.advance_with_quorum(
            h11, fallback, parent=self.commit(11, "ABC"), available=a12, previous_available=a11
        ).state
        h13 = self.q.advance_with_quorum(
            h12, candidate, parent=self.commit(12, "ABC"), available=a13, previous_available=a12
        ).state
        p13 = self.commit(13, "A", absent="BC")
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                h13, candidate, parent=p13, available=self.availability(14, "AB"),
                previous_available=a13,
            )
        result = self.q.advance_with_quorum(
            h13, candidate, parent=p13, available=a14, previous_available=a13
        )
        self.assertEqual(self.powers(h13.current_signers), (("A", 7), ("B", 1), ("C", 1)))
        self.assertEqual(self.powers(result.state.current_signers), (("A", 1), ("B", 1), ("C", 1)))
        self.assertEqual(result.miss_bitmap, 6)
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                result.state, candidate, parent=self.commit(14, "AB", absent="C"),
                available=self.availability(15, "A"), previous_available=a14,
            )

    def test_missing_reseated_parent_key_charges_its_new_live_seat(self):
        config = self.m.Config(2, 20, 4, 1, 1000)
        state = self.initial(config=config, bonds=(
            self.m.Bond(0, "A", 21, 1), self.m.Bond(1, "B", 22, 0),
            self.m.Bond(2, "C", 20, 2), self.m.Bond(3, "D", 20, 3),
        ))
        anchor = self.m.Anchor(0, ("F",))
        a11 = self.availability(11, "ABCD")
        a12 = self.availability(12, "ABCD")
        h11 = self.q.advance_with_quorum(
            state, anchor, parent=None, available=a11, actions=(self.m.Action("exit", 1),)
        ).state
        result = self.q.advance_with_quorum(
            h11, anchor, parent=self.commit(11, "BCD", absent="A"), available=a12,
            previous_available=a11, actions=(self.m.Action("top_up", 0, amount=2),),
        )
        self.assertEqual(result.miss_bitmap, 2)
        self.assertEqual(result.penalties, ((0, 3),))
        self.assertEqual(result.state.bonds[0], self.m.Bond(0, "A", 20, 0))
        self.assertEqual(self.powers(self.m.Selection(result.state.snapshot.members, "candidate")),
                         (("C", 10), ("D", 10)))
        next_result = self.q.advance_with_quorum(
            result.state, anchor, parent=self.commit(12, "BCD", nil="A"),
            available=self.availability(13, "ABCD"), previous_available=a12,
        )
        self.assertEqual(next_result.miss_bitmap, 1)
        self.assertEqual(next_result.penalties, ((0, 2),))
        self.assertEqual(next_result.state.bonds[0], self.m.Bond(0, "A", 18))

    def test_admitted_failed_call_keeps_counter_until_empty_seat_is_reused(self):
        state = self.initial(bonds=(self.m.Bond(0, "A", 11, 0),))
        anchor = self.m.Anchor(0, ("F",))
        a11 = self.availability(11, "ABCD")
        a12 = self.availability(12, "ABCD")
        a13 = self.availability(13, "A")
        h11 = self.q.advance_with_quorum(state, anchor, parent=None, available=a11).state
        h12 = self.q.advance_with_quorum(
            h11, anchor, parent=self.commit(11, "BCD", absent="A"),
            available=a12, previous_available=a11,
        ).state
        result = self.q.advance_with_quorum(
            h12, anchor, parent=self.commit(12, "BCD", nil="A"), available=a13,
            previous_available=a12, block_start_ok=False, actions=(self.m.Action("exit", 0),),
        )
        self.assertFalse(result.call_succeeded)
        self.assertEqual(result.miss_bitmap, 1)
        self.assertEqual(result.penalties, ())
        self.assertEqual(result.state.bonds[0], self.m.Bond(0, "A", 11, exit_height=13))
        self.assertEqual(result.state.misses, (1, 0, 0, 0))
        self.assertEqual(result.state.snapshot, h12.snapshot)
        self.assertEqual(result.state.stored_generation, h12.stored_generation)
        self.assertEqual(result.state.pending_signers.source, "fallback")
        resumed = self.q.advance_with_quorum(
            result.state, anchor, parent=self.commit(13, "A"),
            available=self.availability(14, "A"), previous_available=a13,
            actions=(self.m.Action("register", 1, "B", 10),),
        )
        self.assertEqual(resumed.state.bonds[1], self.m.Bond(1, "B", 10, 0))
        self.assertEqual(resumed.state.misses, (0, 0, 0, 0))
        self.assertEqual(resumed.state.snapshot, self.m.Snapshot(14, 0, ()))

    def test_both_quorum_gates_precede_lifecycle_actions(self):
        anchor = self.m.Anchor(0, ("F",))
        a11 = self.availability(11, "ABCD")
        a12 = self.availability(12, "ABCD")
        h11 = self.q.advance_with_quorum(self.initial(), anchor, parent=None, available=a11).state
        invalid_action = (self.m.Action("exit", 0),)
        for parent, available in (
            (self.commit(11, "AB", absent="CD"), a12),
            (self.commit(11, "ABCD"), self.availability(12, "AB")),
        ):
            with self.subTest(parent=parent, available=available):
                with self.assertRaisesRegex(ValueError, "quorum"):
                    self.q.advance_with_quorum(
                        h11, anchor, parent=parent, available=available,
                        previous_available=a11, actions=invalid_action,
                    )
        with self.assertRaises(ValueError):
            self.q.advance_with_quorum(
                h11, anchor, parent=self.commit(11, "ABCD"), available=a12,
                previous_available=a11, actions=invalid_action,
            )
        self.assertEqual(h11.height, 11)
        self.assertEqual(h11.bonds, ())

    def test_wrapper_preserves_state_anchor_and_block_start_validation(self):
        state = self.initial()
        anchor = self.m.Anchor(0, ("F",))
        available = self.availability(11, "ABCD")
        cases = (
            (replace(state, height=True), anchor, True),
            (replace(state, pending_signers=self.m.Selection((), "fallback")), anchor, True),
            (replace(state, current_signers=self.selection(("A", 1))), anchor, True),
            (state, self.m.Anchor(-1, ("F",)), True),
            (state, anchor, 1),
        )
        for predecessor, block_anchor, call_ok in cases:
            with self.subTest(state=predecessor, anchor=block_anchor, call_ok=call_ok):
                with self.assertRaises(ValueError):
                    self.q.advance_with_quorum(
                        predecessor, block_anchor, parent=None, available=available,
                        block_start_ok=call_ok,
                    )

    def test_wrapper_rejects_non_unit_origin_and_fallback_pipeline_sets(self):
        anchor = self.m.Anchor(0, ("A", "B", "C", "D"))
        a11 = self.availability(11, "ABCD")
        a12 = self.availability(12, "ABCD")
        parent = self.commit(11, "ABCD")
        first = self.q.advance_with_quorum(self.initial(), anchor, parent=None, available=a11)
        self.assertEqual(self.q.advance_with_quorum(
            first.state, anchor, parent=parent, available=a12, previous_available=a11
        ).state.height, 12)
        weighted = self.selection(("A", 3), ("B", 1), ("C", 1), ("D", 1))
        for field in ("current_signers", "next_signers", "pending_signers"):
            for source in ("origin", "fallback"):
                malformed = replace(first.state, **{field: replace(weighted, source=source)})
                with self.subTest(field=field, source=source), self.assertRaises(ValueError):
                    self.q.advance_with_quorum(
                        malformed, anchor, parent=parent, available=a12, previous_available=a11
                    )

    def test_symbolic_premises_are_frozen(self):
        vote = self.q.FlagVote("A", "commit")
        for premise, field in (
            (vote, "flag"), (self.q.LastCommit(1, 11, (vote,)), "votes"),
            (self.availability(11, "A"), "keys"),
        ):
            with self.subTest(premise=premise), self.assertRaises(FrozenInstanceError):
                setattr(premise, field, None)


if __name__ == "__main__":
    unittest.main()
