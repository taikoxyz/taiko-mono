"""Source-derived observations for permanent bond forfeiture."""

from copy import deepcopy
from dataclasses import replace
from importlib import import_module
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]
PACKAGE = "formal.etna.current_rules"
INCIDENT = bytes.fromhex("40" * 32)
NO_EXIT = (1 << 48) - 1
MAX256 = (1 << 256) - 1
SEEDS = ((9, 4, 1), (4, 9, 1), (4, 0, 10))


class CurrentForfeitureTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            (ROOT / "formal/etna/current_rules/forfeiture.py").is_file(),
            "Z02 permanent bond forfeiture model is missing",
        )
        sys.path.insert(0, str(ROOT))
        self.addCleanup(sys.path.remove, str(ROOT))
        self.m = import_module(PACKAGE + ".forfeiture")
        self.explorer = import_module(PACKAGE + ".explorer")

    def take(self, state, action):
        result = self.m.step(state, action)
        self.m.check(state, action, result)
        return result

    def refuse(self, state, action, reason):
        before = deepcopy(state)
        with self.assertRaisesRegex(self.explorer.Refused, reason):
            self.m.step(state, action)
        self.assertEqual(state, before)

    def forfeit(self, bond_id=0, **kwargs):
        return self.m.Forfeit(bond_id, INCIDENT, 1048, **kwargs)

    def at(self, state, block, timestamp):
        return self.take(state, self.m.Advance(block, timestamp)).state

    def test_ceiling_floor_and_word_bounds(self):
        m = self.m
        self.assertEqual(m.penalty(13, 3333), 5)
        self.assertEqual(m.penalty(1, 3333), 1)
        self.assertEqual(m.bounty(13, 1000), 1)
        self.assertEqual(m.bounty(1, 1000), 0)
        self.assertEqual(m.bounty(13, 0), 0)
        self.assertEqual(m.penalty(MAX256, 10000), MAX256)
        self.assertEqual(
            m.bounty(MAX256, 1000),
            11579208923731619542357098500868790785326998466564056403945758400791312963993,
        )
        for calculate, balance, bps in (
            (m.penalty, -1, 3333), (m.penalty, MAX256 + 1, 3333),
            (m.bounty, -1, 1000), (m.bounty, MAX256 + 1, 1000),
            (m.penalty, 13, 0), (m.penalty, 13, 10001),
            (m.bounty, 13, -1), (m.bounty, 13, 10000),
        ):
            with self.subTest(calculate=calculate.__name__, balance=balance, bps=bps):
                with self.assertRaises(self.explorer.Refused):
                    calculate(balance, bps)

    def test_effective_first_then_pending_and_full_pending_clear(self):
        m = self.m
        for seed, eff, pending in ((SEEDS[0], 4, 4), (SEEDS[1], 0, 8)):
            with self.subTest(seed=seed):
                start = m.initial(seed)
                result = self.take(start, self.forfeit())
                self.assertEqual(result.state, replace(
                    start, bonds=(m.Bond(0, "key0", "address0", "owner", 0,
                                         eff, pending, 102, 99, 100, 0, False, True),),
                    sink=5, checkpoint_block=100,
                ))
                self.assertEqual(result.events, (("Forfeited", 0, INCIDENT, 13, 5),))
        start = replace(m.initial(SEEDS[1]), forfeit_bps=10000)
        result = self.take(start, self.forfeit())
        self.assertEqual((result.state.bonds[0].eff, result.state.bonds[0].pending,
                          result.state.bonds[0].ready_at, result.state.sink), (0, 0, 0, 13))

    def test_preauthorization_uses_funded_topup_then_execution_balance(self):
        m = self.m
        start = m.initial(SEEDS[2])
        authorization = self.forfeit()
        result = self.take(start, m.TopUp(0, 9))
        deposit = result.state
        self.assertEqual(result.events, (("TopUpDeposited", 0, 9, 102),))
        self.assertEqual((deposit.owner_reserve, deposit.checkpoint_block), (1, 99))
        self.refuse(deposit, m.ActivateTopUp(0), "maturity")
        self.refuse(deposit, m.TopUp(0, 1), "pending")
        pending = self.take(deposit, authorization)
        self.assertEqual(pending.events, (("Forfeited", 0, INCIDENT, 13, 5),))
        self.assertEqual(pending.state.bonds[0], m.Bond(
            0, "key0", "address0", "owner", 0, 0, 8, 102, 99, 100, 0, False, True,
        ))
        matured = self.at(deposit, 102, 1024)
        activated = self.take(matured, m.ActivateTopUp(0))
        self.assertEqual(activated.events, (("TopUpActivated", 0, 9),))
        final = self.take(activated.state, authorization)
        self.assertEqual(final.events, pending.events)
        self.assertEqual(final.state.bonds[0], m.Bond(
            0, "key0", "address0", "owner", 0, 8, 0, 0, 99, 102, 0, False, True,
        ))
        self.refuse(self.at(pending.state, 102, 1024), m.ActivateTopUp(0), "exit")

    def test_legal_denominations_round_up_one_base_unit_after_topup(self):
        m = self.m
        # Q = 10**23 base units. Deployment minStake = 3Q exceeds 10**27 / 4096.
        # The arithmetic edge uses the same step outside the closed-14 graph.
        start = m.initial(SEEDS[2])
        bond = replace(start.bonds[0], eff=300_000_000_000_000_000_000_000)
        start = replace(start, bonds=(bond,), owner_reserve=1_100_000_000_000_000_000_000_000)
        authorization = self.forfeit()
        funded = m.step(start, m.TopUp(0, 1_000_000_000_000_000_000_000_001))
        self.assertEqual(funded.state, replace(
            start,
            bonds=(replace(bond, pending=1_000_000_000_000_000_000_000_001, ready_at=102),),
            owner_reserve=99_999_999_999_999_999_999_999,
        ))
        self.assertEqual(funded.events, (("TopUpDeposited", 0, 1_000_000_000_000_000_000_000_001, 102),))
        result = m.step(funded.state, authorization)
        self.assertEqual(result.state, replace(
            funded.state,
            bonds=(replace(bond, eff=0, pending=866_710_000_000_000_000_000_000, ready_at=102,
                           exit_effective=100, forfeited=True),),
            sink=433_290_000_000_000_000_000_001, checkpoint_block=100,
        ))
        self.assertEqual(result.events, (("Forfeited", 0, INCIDENT, 1_300_000_000_000_000_000_000_001,
                                         433_290_000_000_000_000_000_001),))
        state = result.state
        self.assertEqual(state.bonds[0].balance + state.owner_reserve + state.reporter + state.sink,
                         1_400_000_000_000_000_000_000_000)

    def test_self_report_uses_integer_rounding_and_all_remaining_principal(self):
        m = self.m
        for bps, seed, first_penalty, report_first_cost, forfeit_first_cost in (
            (3333, SEEDS[1], 5, 12, 13),
            (9500, SEEDS[1], 13, 12, 13),
            (9500, (1, 0, 13), 1, 1, 1),
        ):
            with self.subTest(bps=bps, seed=seed):
                start = replace(m.initial(seed), forfeit_bps=bps)
                report = m.Slash(0, "key0", self_report=True)
                reported = self.take(start, report).state
                self.assertEqual(reported.sink, report_first_cost)
                self.assertEqual(reported.owner_reserve, 14 - report_first_cost)
                self.assertEqual((reported.reporter, reported.bonds[0].ready_at,
                                  reported.bonds[0].pending, reported.bonds[0].forfeited), (0, 0, 0, False))
                self.refuse(reported, self.forfeit(), "zero balance")
                forfeited = self.take(start, self.forfeit()).state
                self.assertEqual((forfeited.sink, forfeited.owner_reserve, forfeited.reporter),
                                 (first_penalty, start.owner_reserve, 0))
                if first_penalty < forfeit_first_cost:
                    forfeited = self.take(forfeited, report).state
                else:
                    self.refuse(forfeited, report, "zero balance")
                self.assertEqual((forfeited.sink, forfeited.bonds[0].balance,
                                  forfeited.bonds[0].forfeited), (forfeit_first_cost, 0, True))
        reported = self.take(m.initial(SEEDS[1]), m.Slash(0, "key0")).state
        self.assertEqual((reported.owner_reserve, reported.reporter, reported.sink), (1, 1, 12))

    def test_confirmation_and_withdrawal_preserve_old_id_on_slot_reuse(self):
        m = self.m
        start = m.initial(SEEDS[1])
        requested = self.take(start, m.RequestExit(0)).state
        self.refuse(requested, m.ConfirmExit(0), "snapshot")
        landed = self.take(self.at(requested, 102, 1024), m.Land(101)).state
        confirmed = self.take(landed, m.ConfirmExit(0)).state
        self.assertEqual(confirmed.bonds[0].confirmed_at, 102)
        authorization = self.forfeit()
        forfeited = self.take(confirmed, authorization).state
        self.assertEqual((forfeited.bonds[0].exit_effective, forfeited.bonds[0].confirmed_at),
                         (101, 102))
        too_early = self.at(forfeited, 103, 1036)
        self.assertEqual(self.take(too_early, m.ConfirmExit(0)).state, too_early)
        self.refuse(too_early, m.Withdraw(0), "delay")
        due = self.at(too_early, 104, 1048)
        self.refuse(due, m.Withdraw(0, owner=False), "owner")
        self.refuse(due, m.Withdraw(0, transfer_ok=False), "transfer")
        withdrawn = self.take(due, m.Withdraw(0)).state
        old = m.Bond(0, "key0", "address0", None, None, 0, 0, 0, 99, 101, 0, True, True)
        self.assertEqual((withdrawn.bonds, withdrawn.owner_reserve, withdrawn.sink), ((old,), 9, 5))
        self.assertEqual(m.slot_holder(withdrawn, 0), (False, 0))
        self.assertEqual(m.key_bond(withdrawn, "address0"), (True, 0))
        self.refuse(withdrawn, self.forfeit(), "withdrawn")
        self.refuse(withdrawn, m.Register("key0", "address0", 2), "registered")
        self.refuse(withdrawn, m.Register("key1", "address1", 2, transfer_ok=False), "transfer")
        reused = self.take(withdrawn, m.Register("key1", "address1", 2)).state
        new = m.Bond(1, "key1", "address1", "owner", 0, 2, 0, 0, 106, NO_EXIT, 0, False, False)
        self.assertEqual(reused.bonds, (old, new))
        self.assertEqual(m.slot_holder(reused, 0), (True, 1))
        self.assertEqual(m.key_bond(reused, "address1"), (True, 1))
        self.refuse(reused, self.forfeit(), "withdrawn")
        self.refuse(reused, self.forfeit(2), "unissued")
        penalized = self.take(reused, self.forfeit(1))
        self.assertEqual(penalized.events, (("Forfeited", 1, INCIDENT, 2, 1),))
        self.assertEqual(penalized.state.bonds, (old, replace(new, eff=1, exit_effective=104, forfeited=True)))
        self.assertEqual((penalized.state.owner_reserve, penalized.state.sink), (7, 6))
        redirected = self.take(due, m.Withdraw(0, to_owner=False)).state
        self.assertEqual((redirected.owner_reserve, redirected.reporter, redirected.sink), (1, 8, 5))

    def test_zero_balance_withdrawal_is_permissionless_without_a_transfer(self):
        m = self.m
        slashed = self.take(m.initial(), m.Slash(0, "key0")).state
        landed = self.take(self.at(slashed, 101, 1012), m.Land(100)).state
        confirmed = self.take(landed, m.ConfirmExit(0)).state
        due = self.at(confirmed, 103, 1036)
        result = self.take(due, m.Withdraw(0, owner=False, to_owner=False, transfer_ok=False))
        self.assertEqual(result.state.bonds[0], m.Bond(
            0, "key0", "address0", None, None, 0, 0, 0, 99, 100, 0, True, False,
        ))
        self.assertEqual((result.state.owner_reserve, result.state.reporter, result.state.sink),
                         (1, 1, 12))

    def test_transfer_authority_time_and_evidence_refusals_are_atomic(self):
        m = self.m
        start = m.initial(SEEDS[2])
        self.refuse(start, m.TopUp(0, 9, transfer_ok=False), "transfer")
        self.refuse(start, self.forfeit(transfer_ok=False), "transfer")
        self.refuse(start, self.forfeit(owner=False), "owner")
        self.refuse(replace(start, initialized=False), self.forfeit(), "initialization")
        self.refuse(start, m.Slash(0, "key1"), "evidence")
        self.refuse(start, m.Slash(0, "key0", valid_evidence=False), "evidence")
        self.refuse(start, m.Slash(0, "key0", evidence_generation=1), "evidence")
        self.refuse(start, m.Slash(0, "key0", transfer_ok=False), "transfer")
        self.refuse(start, m.Forfeit(0, INCIDENT, MAX256 + 1), "uint256")
        on_time = self.take(self.at(start, 104, 1048), self.forfeit())
        self.assertEqual(on_time.events, (("Forfeited", 0, INCIDENT, 4, 2),))
        self.refuse(on_time.state, self.forfeit(), "already forfeited")
        self.refuse(self.at(start, 105, 1049), self.forfeit(), "expired")

    def test_recovery_and_nonce_changes_do_not_consume_forfeiture_authorization(self):
        m = self.m
        start = m.initial()
        authorization = self.forfeit()
        recover = m.Recover(0, 0, 0, 1048)
        invalidated = self.take(start, m.InvalidateNonce(0)).state
        recovered = self.take(start, recover).state
        self.assertEqual((invalidated.generation, invalidated.nonce), (0, 1))
        self.assertEqual((recovered.generation, recovered.nonce), (1, 1))
        self.assertEqual(recovered.active_snapshot, 99)
        for before in (invalidated, recovered):
            result = self.take(before, authorization)
            self.assertEqual(result.events, (("Forfeited", 0, INCIDENT, 13, 5),))
            self.refuse(result.state, recover, "stale")
            self.assertEqual((result.state.bonds[0].forfeited, result.state.sink), (True, 5))
        forfeited = self.take(start, authorization).state
        after = self.take(forfeited, recover).state
        self.assertEqual(after, replace(forfeited, generation=1, nonce=1))
        reported = self.take(after, m.Slash(0, "key0")).state
        self.assertEqual(reported.sink, 13)
        landed = self.take(self.at(forfeited, 101, 1012), m.Land(100)).state
        confirmed = self.take(landed, m.ConfirmExit(0)).state
        self.refuse(confirmed, recover, "stale checkpoint")
        rolled_back = self.take(confirmed, m.Rollback(0, 99)).state
        self.assertEqual(rolled_back, replace(
            confirmed, c=0, nonce=1, active_snapshot=99,
            bonds=(replace(confirmed.bonds[0], confirmed_at=0),),
        ))

    def test_slot_lookup_distinguishes_vacancy_from_out_of_domain_index(self):
        m = self.m
        start = m.initial()
        self.assertEqual(m.slot_holder(start, 0), (True, 0))
        self.assertEqual(m.slot_holder(start, 4095), (False, 0))
        for invalid in (4096, -1, 0.0, True):
            with self.subTest(slot=invalid), self.assertRaisesRegex(self.explorer.Refused, "slot"):
                m.slot_holder(start, invalid)

    def test_exploration_bounds_do_not_refuse_valid_registration(self):
        m = self.m
        start = m.initial(SEEDS[2])
        second = m.Register("key1", "address1", 2)
        self.assertNotIn(second, tuple(m.actions(start)))
        registered = self.take(start, second).state
        self.assertEqual((m.slot_holder(registered, 0), m.slot_holder(registered, 1)),
                         ((True, 0), (True, 1)))
        third = m.Register("key2", "address2", 2)
        self.assertNotIn(third, tuple(m.actions(registered)))
        result = self.take(registered, third).state
        self.assertEqual(m.slot_holder(result, 2), (True, 2))
        self.assertEqual(result.owner_reserve, 6)
        self.assertEqual(result.bonds[0], start.bonds[0])

    def test_finite_graph_has_live_withdrawn_reused_and_deadline_witnesses(self):
        m = self.m
        for seed in SEEDS:
            with self.subTest(seed=seed):
                graph = self.explorer.explore(
                    m.initial(seed), m.actions, m.step, m.check, max_states=30_000,
                )
                live = next(edge for edge in graph.accepted if m.witness_live(edge))
                withdrawn = next(edge for edge in graph.refused if m.witness_withdrawn(edge))
                reused = next(edge for edge in graph.refused if m.witness_reused(edge))
                equal = next(edge for edge in graph.accepted if m.witness_at_deadline(edge))
                expired = next(edge for edge in graph.refused if m.witness_expired(edge))
                self.assertEqual(live.events, (("Forfeited", 0, INCIDENT, sum(seed[:2]),
                                                2 if seed == SEEDS[2] else 5),))
                self.assertTrue(withdrawn.pre.bonds[0].forfeited)
                self.assertEqual((withdrawn.reason, reused.reason), ("withdrawn bond", "withdrawn bond"))
                replacement_hit = next(edge for edge in graph.accepted if
                                       edge.action == self.forfeit(1) and edge.pre.bonds[0].forfeited)
                self.assertEqual(replacement_hit.events, (("Forfeited", 1, INCIDENT, 2, 1),))
                self.assertEqual(replacement_hit.pre.bonds[0], replacement_hit.post.bonds[0])
                for generation in (0, 1):
                    after_nonce_or_recover = next(edge for edge in graph.accepted if
                                                  m.witness_live(edge) and edge.pre.nonce == 1
                                                  and edge.pre.generation == generation)
                    self.assertEqual(after_nonce_or_recover.events, live.events)
                failed_recovery = next(edge for edge in graph.refused if
                                       edge.action == m.RECOVERY and edge.pre.bonds[0].forfeited
                                       and edge.reason == "stale recovery nonce")
                self.assertEqual(failed_recovery.pre.sink, 2 if seed == SEEDS[2] else 5)
                self.assertEqual(m.slot_holder(reused.pre, 0), (True, 1))
                self.assertFalse(reused.pre.bonds[1].forfeited)
                self.assertEqual(equal.pre.timestamp, 1048)
                self.assertEqual(expired.pre.timestamp, 1060)
                path = graph.path_to(reused.pre)
                self.assertIn(m.Register, tuple(type(edge.action) for edge in path))
                self.assertIn(m.Withdraw, tuple(type(edge.action) for edge in path))
                if seed == SEEDS[2]:
                    funded = next(edge for edge in graph.accepted if m.witness_funded_topup(edge))
                    self.assertEqual(funded.events, (("Forfeited", 0, INCIDENT, 13, 5),))
                    self.assertIn(m.TopUp, tuple(type(edge.action) for edge in graph.path_to(funded.pre)))
