"""Unit contracts for the current-registry frames and opt-in profiles."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "conformance"))


class RegistryVacancyTests(unittest.TestCase):
    def setUp(self):
        import registry_vacancy_observer as observer

        self.observe = observer.expected_transition
        self.state = observer.initial_state()
        self.transitions = []

    def step(self, name, **inputs):
        allowed, state = self.observe(self.state, {"name": name, **inputs})
        self.assertTrue(allowed, (name, inputs))
        self.transitions.append((self.state, {"accepted": allowed, "call": {"kind": name, **inputs}}, state))
        self.state = state

    def register(self, key, actor=1, amount=3):
        self.step("Register", key=key, actor=actor, amount=amount)

    def tick(self, capture=False):
        self.step("Tick", capture=capture)

    def slash(self, bond):
        self.step("Slash", bond=bond, actor=3)

    def withdraw_at_two(self, *bonds):
        self.tick()
        self.step("Land", snapshot=1)
        for bond in bonds:
            self.step("Confirm", bond=bond, actor=3)
        self.tick()
        for bond in bonds:
            self.step("Withdraw", bond=bond, actor=3)

    def test_zero_principal_lower_slot_is_occupied(self):
        self.register(0)
        self.slash(0)
        self.register(1, actor=2)
        self.assertEqual(self.state["slots"], {
            0: {"occupied": True, "bond": 0},
            1: {"occupied": True, "bond": 1},
        })
        self.assertTrue(self.state["bonds"][0]["holds"])
        self.assertEqual(self.state["bonds"][0]["eff"], 0)

    def test_two_vacancies_allocate_in_order_and_keep_lifetime_ids(self):
        from registry_vacancy_observer import _two_initial_slots_released

        self.register(0)
        self.register(1, actor=2)
        self.slash(0)
        self.slash(1)
        self.withdraw_at_two(1, 0)
        self.assertTrue(_two_initial_slots_released(self.transitions))
        self.assertEqual(self.state["slots"], {
            0: {"occupied": False, "bond": 0},
            1: {"occupied": False, "bond": 0},
        })
        self.register(2)
        self.register(3, actor=2)
        self.assertEqual([self.state["slots"][i]["bond"] for i in range(2)], [2, 3])
        self.assertEqual(self.state["reuse"], 2)
        for bond in (0, 1):
            self.assertEqual(self.state["keys"][bond], {"registered": True, "bond": bond})
            self.assertTrue(self.state["bonds"][bond]["withdrawn"])
            self.assertFalse(self.state["bonds"][bond]["holds"])

    def test_sequential_release_of_one_slot_is_not_two_slot_history(self):
        from registry_vacancy_observer import _two_initial_slots_released

        self.register(0)
        self.slash(0)
        self.withdraw_at_two(0)
        self.register(1)
        self.slash(1)
        self.tick()
        self.step("Land", snapshot=3)
        self.step("Confirm", bond=1, actor=3)
        self.tick()
        self.step("Withdraw", bond=1, actor=3)
        self.assertTrue(all(not occupant["occupied"] for occupant in self.state["slots"].values()))
        self.assertEqual(self.state["uses"], {0: 2, 1: 0})
        self.assertFalse(_two_initial_slots_released(self.transitions))

    def test_full_refusal_preserves_bonds_keys_sequence_and_cash(self):
        self.register(0)
        self.register(1, actor=2)
        self.slash(0)
        self.tick()
        self.step("TopUp", bond=1, actor=2)
        self.step("Exit", bond=1, actor=2)
        pre = copy.deepcopy(self.state)
        for amount in (3, 4):
            allowed, post = self.observe(self.state, {
                "name": "Register", "key": 2, "actor": 1, "amount": amount,
            })
            self.assertFalse(allowed)
            self.assertEqual(post, pre)
            self.assertEqual(self.state, pre)

    def test_withdrawn_lifetime_key_refuses_with_fresh_admission_in_same_prestate(self):
        self.register(0)
        self.slash(0)
        self.withdraw_at_two(0)
        pre = copy.deepcopy(self.state)
        accepted, post = self.observe(pre, {"name": "Register", "key": 0, "actor": 2, "amount": 4})
        self.assertFalse(accepted)
        self.assertEqual(post, pre)
        self.register(1, actor=2, amount=4)
        self.assertEqual(self.state["slots"][0], {"occupied": True, "bond": 1})
        self.assertEqual(self.state["keys"][0], {"registered": True, "bond": 0})

    def test_topup_and_issuance_scope_end_are_classified_as_profile_bounds(self):
        from registry_vacancy_observer import OutOfProfile

        self.register(0)
        self.tick()
        self.step("TopUp", bond=0, actor=1)
        self.tick()
        self.step("Activate", bond=0, actor=3)
        with self.assertRaises(OutOfProfile):
            self.observe(self.state, {"name": "TopUp", "bond": 0, "actor": 1})
        self.state["nextId"] = 4
        with self.assertRaises(OutOfProfile):
            self.observe(self.state, {"name": "Register", "key": 4, "actor": 1, "amount": 3})

    def test_raw_call_metadata_must_match_the_actual_offer(self):
        from registry_vacancy_observer import validate_raw_call

        self.register(0)
        self.tick()
        call = {"kind": "TopUp", "bond": 0, "actor": 1, "key": 0,
                "amount": 0, "snapshot": 0, "capture": False}
        observed = validate_raw_call(self.state, {"accepted": True, "call": call},
                                     capture_history=False)
        self.assertEqual(observed["name"], "TopUp")
        for changed in ({"amount": 500}, {"actor": 2}, {"snapshot": 2}, {"capture": True}):
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, "noncanonical"):
                validate_raw_call(self.state, {"accepted": True, "call": {**call, **changed}},
                                  capture_history=False)
        with self.assertRaisesRegex(ValueError, "only Register"):
            validate_raw_call(self.state, {"accepted": False, "call": call}, capture_history=False)

    def test_block_end_sample_uses_only_effective_stake_and_stays_frozen(self):
        self.register(0)
        self.tick()
        self.step("TopUp", bond=0, actor=1)
        self.tick(capture=True)
        saved = copy.deepcopy(self.state["sample"])
        self.assertEqual(saved["snapshot"], 2)
        self.assertEqual(saved["powers"], {0: 3, 1: 0, 2: 0, 3: 0})
        self.assertEqual(saved["checkpoint"]["at"], 1)
        self.step("Activate", bond=0, actor=3)
        self.assertEqual(self.state["bonds"][0]["eff"], 4)
        self.slash(0)
        self.tick()
        self.step("Land", snapshot=3)
        self.step("Confirm", bond=0, actor=3)
        self.tick()
        self.step("Withdraw", bond=0, actor=3)
        self.register(1)
        self.assertEqual(self.state["sample"], saved)
        self.assertEqual(self.state["slots"][0], {"occupied": True, "bond": 1})


class ProductProfilesTests(unittest.TestCase):
    def test_only_opt_in_profiles_use_the_new_model(self):
        source = ROOT / "EtnaRegistryVacancy.tla"
        self.assertTrue(source.is_file())
        profiles = ROOT / "products" / "registry-vacancy"
        self.assertTrue((profiles / "safety.cfg").is_file())
        self.assertTrue((profiles / "two-holes.cfg").is_file())
        for path in (ROOT / "configs").glob("*.cfg"):
            self.assertNotIn(source.stem, path.read_text())

class SimulationFooterTests(unittest.TestCase):
    BANNER = "Running Random Simulation with seed 1 with 1 worker on 8 cores\n"
    FOOTER = ("The number of states generated: 640\n"
              "Simulation using seed 1 and aril 0\n"
              "Progress: 643 states checked.\n"
              "Finished in 00s at (2026-01-01 00:00:00)\n")

    def test_simulation_summary_keeps_generated_count_and_sampling_identity(self):
        from registry_vacancy_observer import simulation_summary

        self.assertEqual(simulation_summary(self.BANNER + self.FOOTER, 1),
                         {"generated": 640, "seed": 1, "aril": 0})

    def test_simulation_summary_rejects_wrong_mode_seed_and_trailing_output(self):
        from registry_vacancy_observer import simulation_summary

        log = self.BANNER + self.FOOTER
        malformed = (
            log.replace("and aril 0", "and aril"),
            log.replace("Simulation using seed 1", "Simulation using seed 2"),
            log.replace("with 1 worker", "with 2 workers"),
            log + "640 states generated, 1 distinct states found, 0 states left on queue.\n",
            log + "unexpected footer data\n",
        )
        for raw in malformed:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                simulation_summary(raw, 1)
