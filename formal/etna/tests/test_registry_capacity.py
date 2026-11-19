"""Boundary tests for the independent current Registry capacity observer."""
from copy import deepcopy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "conformance"))

from registry_capacity import Profile, expected_transition, initial_state, minimum_stake


class MinimumStakeTests(unittest.TestCase):
    def test_strict_4096_slot_bound(self):
        supply = 10**27
        slots = 4096
        equality = 244_140_625_000_000_000_000_000
        minimum = minimum_stake(supply, slots)
        self.assertEqual(minimum, 244_140_625_000_000_000_000_001)
        for stake, amount, expected in (
            (equality - 1, supply - slots, False),
            (equality, supply, False),
            (equality + 1, supply + slots, True),
        ):
            with self.subTest(stake=stake):
                self.assertEqual(stake * slots, amount)
                self.assertEqual(stake >= minimum, expected)
                self.assertEqual(stake * slots > supply, expected)

    def test_irregular_and_large_amounts_preserve_exact_predecessor(self):
        for supply, slots, expected in (
            (0, 4096, 1), (7, 2, 4), (7, 1, 8), (10**120 + 4, 10, 10**119 + 1),
        ):
            with self.subTest(supply=supply, slots=slots):
                stake = minimum_stake(supply, slots)
                self.assertEqual(stake, expected)
                self.assertGreater(stake * slots, supply)
                self.assertLessEqual((stake - 1) * slots, supply)

    def test_rejects_invalid_integer_domain(self):
        for supply, slots in ((False, 3), (7, True), (7.0, 2), (7, 2.0), ("7", 2)):
            with self.subTest(supply=supply, slots=slots), self.assertRaises(TypeError):
                minimum_stake(supply, slots)
        for supply, slots in ((-1, 3), (7, 0), (7, -1)):
            with self.subTest(supply=supply, slots=slots), self.assertRaises(ValueError):
                minimum_stake(supply, slots)


class ClosedSupplyTests(unittest.TestCase):
    def setUp(self):
        self.state = initial_state()
        self.profile = Profile()

    def step(self, kind, *, allowed=True, bond=0, actor=0, key=0, amount=0, snapshot=0):
        pre = deepcopy(self.state)
        call = dict(kind=kind, bond=bond, actor=actor, key=key, amount=amount, snapshot=snapshot)
        accepted, post = expected_transition(self.state, call, self.profile)
        self.assertEqual(self.state, pre, "observer changed its input")
        self.assertEqual(accepted, allowed, (kind, pre))
        if not allowed:
            self.assertEqual(post, pre)
        self.state = post
        cash = self.state["cash"]
        balances = [*cash.values()]
        for entry in self.state["bonds"].values():
            balances.extend((entry["eff"], entry["pending"]))
        self.assertTrue(all(x >= 0 for x in balances))
        self.assertEqual(sum(balances), 7)

    def register(self, key, *, allowed=True):
        self.step("Register", actor=1, key=key, amount=4, allowed=allowed)

    def start(self, *, topup=False):
        self.register(0)
        self.step("Tick")
        if topup:
            self.step("TopUp", actor=1, amount=1)
        self.step("Tick")
        self.step("Start", snapshot=2)
        self.assertEqual(self.state["coverage"], 2)

    def reporter_full(self):
        self.start()
        self.step("Slash", actor=2)
        self.assertEqual(self.state["cash"], dict(liquid=3, reporter=1, sink=3))
        self.assertEqual(self.state["bonds"][0]["eff"], 0)
        self.assertEqual(self.state["bonds"][0]["exit"], 3)
        self.assertTrue(self.state["slots"][0]["occupied"])
        self.register(1, allowed=False)
        self.step("RecycleReporter", amount=1)
        self.assertEqual(self.state["cash"], dict(liquid=4, reporter=0, sink=3))
        self.register(1)
        self.assertEqual(self.state["cash"], dict(liquid=0, reporter=0, sink=3))
        self.assertEqual(self.state["slots"], {
            0: dict(occupied=True, bond=0), 1: dict(occupied=True, bond=1),
        })
        self.assertEqual(self.state["bonds"][1]["eff"], 4)

    def recovery_gap(self):
        self.step("Tick")
        self.step("Recover", snapshot=4)
        self.assertEqual(self.state["recoveredAt"], 4)
        self.assertEqual(self.state["coverage"], 2)
        self.step("Tick")
        self.assertEqual(self.state["recovery"], dict(at=4, powers={0: 0, 1: 4, 2: 0}))

    def test_reporter_alone_funds_second_held_slot(self):
        self.reporter_full()
        self.register(2, allowed=False)

    def test_recovery_alone_cannot_confirm_or_release_zero_holder(self):
        self.profile = Profile(landing=False)
        self.reporter_full()
        self.recovery_gap()
        self.step("Tick")
        self.step("Tick")
        self.step("Confirm", actor=2, allowed=False)
        self.step("Withdraw", actor=2, allowed=False)
        self.register(2, allowed=False)
        self.assertEqual(self.state["coverage"], 2)
        self.assertEqual(self.state["bonds"][0]["confirmed"], 0)
        self.assertTrue(self.state["slots"][0]["occupied"])

    def test_real_landing_starts_delay_and_zero_withdrawal_does_not_fund_new_call(self):
        self.reporter_full()
        self.recovery_gap()
        self.step("Confirm", actor=2, allowed=False)
        self.step("Land", snapshot=4)
        self.assertEqual(self.state["coverage"], 4)
        self.step("Confirm", actor=2)
        self.assertEqual(self.state["bonds"][0]["confirmed"], 5)
        self.step("Withdraw", actor=2, allowed=False)
        self.step("Tick")
        self.step("Confirm", actor=2)
        self.assertEqual(self.state["bonds"][0]["confirmed"], 5)
        self.step("Withdraw", actor=2)
        self.assertEqual(self.state["slots"][0], dict(occupied=False, bond=0))
        self.assertEqual(self.state["cash"], dict(liquid=0, reporter=0, sink=3))
        self.assertTrue(self.state["bonds"][0]["issued"])
        self.assertTrue(self.state["bonds"][0]["withdrawn"])
        self.assertFalse(self.state["bonds"][0]["holds"])
        self.register(2, allowed=False)

    def test_forfeit_keeps_pending_and_positive_withdrawal_pays_only_owner(self):
        self.profile = Profile(reporter_recycle=False, sink_recycle=True)
        self.start(topup=True)
        self.step("Forfeit", actor=3)
        self.assertEqual(self.state["cash"], dict(liquid=2, reporter=0, sink=3))
        bond = self.state["bonds"][0]
        self.assertEqual((bond["eff"], bond["pending"], bond["ready"]), (1, 1, 3))
        self.step("RecycleSink", amount=3)
        self.register(1)
        self.recovery_gap()
        self.step("Land", snapshot=4)
        self.step("Confirm", actor=2)
        self.step("Tick")
        self.step("Withdraw", actor=2, allowed=False)
        self.step("Withdraw", actor=1)
        self.assertEqual(self.state["cash"], dict(liquid=3, reporter=0, sink=0))
        self.assertEqual(self.state["bonds"][0]["pending"], 0)
        self.assertEqual(self.state["bonds"][0]["eff"], 0)
        self.assertTrue(self.state["bonds"][0]["forfeited"])


    def test_land_refuses_when_survivor_is_slashed_before_recovery_block_closes(self):
        self.reporter_full()
        self.step("Tick")
        self.step("Recover", snapshot=4)
        self.step("Slash", bond=1, actor=2)
        self.step("Tick")
        self.assertEqual(self.state["recovery"], dict(at=4, powers={0: 0, 1: 0, 2: 0}))
        self.step("Land", snapshot=4, allowed=False)
        self.assertEqual(self.state["coverage"], 2)

    def test_land_uses_frozen_recovery_selection_after_live_stake_changes(self):
        self.reporter_full()
        self.step("Tick")
        self.step("Recover", snapshot=4)
        self.step("Tick")
        frozen = dict(at=4, powers={0: 0, 1: 4, 2: 0})
        self.assertEqual(self.state["recovery"], frozen)
        self.step("Slash", bond=1, actor=2)
        self.assertEqual(self.state["bonds"][1]["eff"], 0)
        self.step("Land", snapshot=4)
        self.assertEqual(self.state["recovery"], frozen)
        self.assertEqual(self.state["coverage"], 4)
        self.step("Confirm", bond=1, actor=2, allowed=False)

    def test_elapsed_topup_delay_moves_no_stake_without_activation(self):
        self.register(0)
        self.step("Tick")
        self.step("TopUp", actor=1, amount=1)
        self.step("Activate", actor=2, allowed=False)
        self.step("Tick")
        self.assertEqual(self.state["closed"], dict(at=2, powers={0: 4, 1: 0, 2: 0}))
        self.assertEqual((self.state["bonds"][0]["eff"], self.state["bonds"][0]["pending"]), (4, 1))
        self.step("Activate", actor=2)
        self.assertEqual((self.state["bonds"][0]["eff"], self.state["bonds"][0]["pending"]), (5, 0))
        self.assertEqual(self.state["closed"], dict(at=2, powers={0: 4, 1: 0, 2: 0}))
        self.assertEqual(self.state["cash"]["liquid"], 2)


    def test_confirmation_fault_cannot_hide_an_unrelated_field_type_change(self):
        from registry_capacity import _fault_shape

        self.reporter_full()
        self.step("Tick")
        self.step("Recover", snapshot=4)
        self.assertEqual(self.state["recovery"]["at"], 0)
        pre = self.state
        call = {"kind": "Confirm", "bond": 0, "actor": 2, "key": 0, "amount": 0, "snapshot": 0}
        accepted, expected = expected_transition(pre, call, self.profile)
        self.assertFalse(accepted)
        faulty = deepcopy(pre)
        faulty["bonds"][0]["confirmed"] = pre["now"]
        receipt = {"call": call, "accepted": True}
        _fault_shape("premature-confirm", pre, receipt, faulty, expected, accepted)
        faulty["bonds"][0]["eff"] = False
        with self.assertRaises(ValueError):
            _fault_shape("premature-confirm", pre, receipt, faulty, expected, accepted)


if __name__ == "__main__":
    unittest.main()
