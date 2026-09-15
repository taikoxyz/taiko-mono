#!/usr/bin/env python3
"""Composed adversarial premium traces; synthetic amounts are not calibration.

Only reusable fixtures are imported from the Settlement test module.  No suite
is loaded or run transitively.  Offers cross stage/apply and canonical progress
uses Protocol.submit, with no direct duty mutation or private commit shortcut.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parent


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


fixtures = load_module("seat_promotion_fixtures", "test-settlement-window.py")
settlement = fixtures.settlement
market = fixtures.market
economics = load_module("seat_promotion_economics", "economic-profile-model.py")


def funded_pair(bond, runway=8_000):
    """Use the composed authority fixture with a constructor-set bond amount."""
    protocol, base = fixtures.make_pair(runway=runway)
    seat_market = market.SeatMarket(
        market_chain_id=base.market_chain_id,
        market_address=base.market_address,
        sla_bond=bond,
        immutable_maximum_ask=base.immutable_maximum_ask,
        quote_maturity_seconds=base.quote_maturity_seconds,
        quote_maturity_blocks=base.quote_maturity_blocks,
        exit_delay_seconds=base.exit_delay_seconds,
        penalty_sink=base.penalty_sink,
        authorization=base.authorization,
        insertion_enabled=True,
        cached_generation=protocol.seat_generation,
        release_manager=base.release_manager,
        target_runtime=next(iter(base.target_runtimes.values())),
        seat_runway_seconds=runway,
        handover_delay_seconds=base.handover_delay_seconds,
        stage_grace_seconds=base.stage_grace_seconds,
        maximum_inclusion_seconds=base.maximum_inclusion_seconds,
        maximum_standby_lease_seconds=base.maximum_standby_lease_seconds,
        minimum_standby_tenure_seconds=base.minimum_standby_tenure_seconds,
        minimum_ask_improvement_wei_per_second=settlement.MIN_ASK_IMPROVEMENT_WEI_PER_SECOND,
        minimum_ask_improvement_bps=settlement.MIN_ASK_IMPROVEMENT_BPS,
        premium_claim_delay_seconds=base.premium_claim_delay_seconds,
        release_challenge_seconds=base.release_challenge_seconds,
        reorg_stability_seconds=base.reorg_stability_seconds,
        evidence_delay_seconds=base.evidence_delay_seconds,
    )
    protocol.bind_seat_market_for_test(seat_market)
    return protocol, seat_market


def install_offer(protocol, seat_market, operator, ask, quoted_at, quoted_block):
    """Install even a zero-ask offer through the public composed operations."""
    if ask:
        seat_market.sponsor_premium(ask * seat_market.seat_runway_seconds)
    row = fixtures.insert_offer(seat_market, operator, ask, quoted_at, quoted_block)
    staged = protocol.stage_best(seat_market, settlement.Clock(
        quoted_block + seat_market.quote_maturity_blocks,
        quoted_at + seat_market.quote_maturity_seconds,
    ))
    if staged == "SYNCED" or staged.code is not market.ResultCode.STAGED:
        raise AssertionError("offer did not stage")
    installed = protocol.apply_stage(seat_market, settlement.Clock(
        quoted_block + seat_market.quote_maturity_blocks + 1,
        staged.stage.handover_at,
    ))
    return row, installed.tranche.installed_term_id


class SeatPromotionEconomicsTests(unittest.TestCase):
    def lineup(self, bond=100_000_000, runway=8_000):
        protocol, seat_market = funded_pair(bond, runway)
        primary_row, primary = install_offer(
            protocol, seat_market, "low", 0, settlement.GENESIS_TIMESTAMP + 1_000, 100,
        )
        _, successor = install_offer(
            protocol, seat_market, "high", 100, settlement.GENESIS_TIMESTAMP + 1_020, 110,
        )
        self.assertEqual(protocol.seat_lineup, [primary, successor])
        self.assertEqual(seat_market.accounting.free_premium, 0)
        self.assertEqual(seat_market.accounting.reserved_premium, 100 * runway)
        return protocol, seat_market, primary_row, primary, successor

    def promoted(self, boundary, bond=100_000_000, runway=8_000):
        protocol, seat_market, primary_row, primary, successor = self.lineup(bond, runway)
        original = protocol.seat_services[primary]
        baseline_end = original.service_eligible_until
        # No independent lander/sync is assumed.  A permissionless sync opens
        # recovery just before failover, without extending any round deadline.
        self.assertTrue(protocol.sync(settlement.Clock(
            1_000, original.prospective_failover_at - 2,
        )))
        duty = protocol.seat_duties[protocol.term_duty[primary]]
        at = {
            "before-failover": duty.failover_at - 1,
            "failover-equality": duty.failover_at,
            "after-failover": duty.failover_at + 1,
            "before-slash": duty.slash_at - 1,
            "slash-equality": duty.slash_at,
            "after-slash": duty.slash_at + 1,
        }[boundary]
        commit_clock = settlement.Clock(
            protocol.recovery.anchor_number + settlement.F_L1, at,
        )
        candidate = settlement.candidate(
            protocol, commit_clock, f"promotion-{boundary}",
            tier=settlement.Tier.RECOVERY_SIGNED, slot=commit_clock.l2_slot,
            recovery_fields_zero=False,
        )
        old_block = protocol.core.l2_block_number
        self.assertEqual(protocol.submit(candidate, commit_clock), "COMMITTED")
        self.assertEqual(protocol.core.l2_block_number, old_block + 1)
        if boundary != "after-slash":
            self.assertEqual(protocol.active_primary_term_id, successor)
            self.assertEqual(protocol.seat_services[successor].responsibility_start, at)
            self.assertEqual(
                protocol.seat_services[successor].minimum_tenure_until - at, 1_000,
            )
        return protocol, seat_market, primary_row, primary, successor, duty, baseline_end

    def credit_primary_bond(self, protocol, seat_market, row, primary, duty):
        clock = settlement.Clock(
            1_101, duty.satisfied_at + 1_000 + seat_market.premium_claim_delay_seconds,
        )
        requested = protocol.request_bond_release(
            seat_market, row.tranche.tranche_id, primary, clock,
        )
        self.assertNotEqual(requested, "SYNCED")
        owner_at = max(
            clock.timestamp + seat_market.release_challenge_seconds,
            duty.satisfied_at + seat_market.reorg_stability_seconds,
            max(duty.slash_at, protocol.seat_services[primary].term_removed_at)
            + seat_market.evidence_delay_seconds + seat_market.reorg_stability_seconds,
        )
        protocol.sync(settlement.Clock(clock.block_number + 1, owner_at))
        result = protocol.finalize_bond_release(
            seat_market, row.tranche.tranche_id, primary,
            settlement.Clock(clock.block_number + 1, owner_at),
        )
        self.assertIs(
            seat_market.tranches[row.tranche.tranche_id].disposition,
            market.BondDisposition.OWNER_CREDITED,
        )
        self.assertEqual(result.amount, seat_market.sla_bond)
        self.assertEqual(seat_market.credits[result.credit_id].amount,
                         seat_market.sla_bond)
        return result.amount

    def test_late_cure_credits_100000_premium_and_returns_large_bond(self):
        p, m, row, primary, successor, duty, baseline_end = self.promoted("after-failover")
        self.assertIs(duty.status, settlement.DutyStatus.SATISFIED)
        self.assertIsNone(duty.breach_recorded_at)
        start = p.seat_services[successor].responsibility_start
        self.assertEqual((start, baseline_end), (1_004_616, 1_005_051))
        credited = p.accrue_seat_premium(m, successor, settlement.Clock(
            1_100, start + 1_000 + m.premium_claim_delay_seconds,
        ))
        self.assertEqual(credited.amount, 100_000)
        self.assertEqual(m.premium_credits[credited.premium_credit_id].amount,
                         100_000)
        self.assertEqual(m.accounting.reserved_premium, 700_000)
        exposure = economics.funded_promotion_exposure(
            successor_ask=p.seat_terms[successor].ask,
            predecessor_ask=p.seat_terms[primary].ask,
            funded_reserve=100 * m.seat_runway_seconds,
            funded_service_horizon=m.seat_runway_seconds,
            eligible_baseline_overlap=baseline_end - start,
        )
        self.assertEqual(exposure["maximumPremiumWei"], 800_000)
        self.assertEqual(exposure["maximumIncrementalOverlapWei"], 43_500)
        self.assertLess(exposure["maximumIncrementalOverlapWei"], credited.amount)
        self.assertEqual(self.credit_primary_bond(p, m, row, primary, duty), 100_000_000)

    def test_cure_boundaries_preserve_full_bond_and_fresh_paid_tenure(self):
        for boundary, overlap in (
            ("before-failover", 437),
            ("failover-equality", 436),
            ("after-failover", 435),
            ("before-slash", 0),
            ("slash-equality", 0),
        ):
            with self.subTest(boundary=boundary):
                p, m, row, primary, successor, duty, baseline_end = self.promoted(boundary)
                self.assertIs(duty.status, settlement.DutyStatus.SATISFIED)
                self.assertIsNone(duty.breach_recorded_at)
                start = p.seat_services[successor].responsibility_start
                self.assertEqual(max(0, baseline_end - start), overlap)
                credit = p.accrue_seat_premium(m, successor, settlement.Clock(
                    1_100, start + 1_000 + m.premium_claim_delay_seconds,
                ))
                self.assertEqual(credit.amount, 100_000)
                self.assertEqual(self.credit_primary_bond(p, m, row, primary, duty),
                                 100_000_000)
                self.assertEqual(m.accounting.outstanding_penalty_credits, 0)

    def test_increasing_refundable_bond_does_not_remove_overlap_spending(self):
        for bond in (100_000_000, 10**18):
            with self.subTest(bond=bond):
                p, m, row, primary, successor, duty, baseline_end = self.promoted(
                    "after-failover", bond=bond,
                )
                start = p.seat_services[successor].responsibility_start
                credited = p.accrue_seat_premium(m, successor, settlement.Clock(
                    1_100, baseline_end + m.premium_claim_delay_seconds,
                ))
                self.assertEqual(credited.amount, 43_500)
                self.assertEqual(credited.amount, 100 * (baseline_end - start))
                self.assertEqual(self.credit_primary_bond(p, m, row, primary, duty), bond)
                self.assertEqual(m.accounting.outstanding_penalty_credits, 0)

    def test_after_slash_progress_preserves_breach_and_penalty(self):
        p, m, row, primary, successor, duty, _ = self.promoted("after-slash")
        self.assertIs(duty.status, settlement.DutyStatus.BREACHED)
        self.assertIsNone(duty.satisfied_at)
        self.assertEqual(duty.breach_recorded_at, duty.slash_at + 1)
        # This commit keeps the selected successor unstarted; no premium is
        # earned just by holding its funded reserve or being selected.
        self.assertIsNone(p.active_primary_term_id)
        self.assertEqual(p.selected_successor_term_id, successor)
        self.assertIsNone(p.seat_services[successor].responsibility_start)
        self.assertEqual(m.accounting.outstanding_premium_claims, 0)
        with self.assertRaises(market.TransitionRejected):
            p.request_bond_release(m, row.tranche.tranche_id, primary,
                                  settlement.Clock(1_100, duty.slash_at + 2))
        penalty = p.enforce_seat_breach(m, row.tranche.tranche_id, primary,
            settlement.Clock(1_101, duty.breach_recorded_at + m.reorg_stability_seconds))
        self.assertEqual(penalty.amount, 100_000_000)
        self.assertIs(m.tranches[row.tranche.tranche_id].disposition,
                      market.BondDisposition.PENALTY_CREDITED)
        self.assertEqual(m.accounting.outstanding_penalty_credits, 100_000_000)
        self.assertEqual(m.accounting.outstanding_owner_credits, 0)

    def test_healthy_primary_serves_at_zero_ask_through_comparison_overlap(self):
        p, m, _, primary, successor = self.lineup()
        baseline_end = p.seat_services[primary].service_eligible_until
        # Three normal windows keep the incumbent current without attaching an
        # SLA duty.  The third proof is accepted immediately before the attack
        # start time; its normal window commits while the incumbent serves.
        for index in range(3):
            target = p.seat_services[primary].prospective_target_tip
            opened_at = settlement.GENESIS_TIMESTAMP + 1_040 + index * 1_201
            block = 1_000 + index * 100
            self.assertEqual(p.arm_normal_context(
                settlement.Clock(block, opened_at - 1)), "ARMED")
            self.assertEqual(p.activate_normal_context(
                settlement.Clock(block + 1, opened_at)), "ACTIVATED")
            clock = settlement.Clock(block + settlement.F_L1 + 1,
                                     settlement.GENESIS_TIMESTAMP + target)
            candidate = settlement.candidate(p, clock, f"healthy-{index}", slot=target)
            self.assertEqual(p.submit(candidate, clock), "ACCEPTED")
            self.assertTrue(p.sync(settlement.Clock(block + settlement.F_L1 + 2,
                                                    p.normal_deadline)))
            self.assertNotIn(primary, p.term_duty)
        self.assertEqual(p.active_primary_term_id, primary)
        self.assertEqual(p.core.tip_slot, 4_615)
        self.assertFalse(p.sync(settlement.Clock(1_400, baseline_end - 1)))
        self.assertEqual(p.active_primary_term_id, primary)
        premium = p.accrue_seat_premium(m, primary, settlement.Clock(
            1_401, baseline_end - 1,
        ))
        self.assertEqual(premium.amount, 0)
        self.assertEqual(m.accounting.outstanding_premium_claims, 0)
        self.assertTrue(p.sync(settlement.Clock(1_402, baseline_end)))
        self.assertEqual(p.seat_services[primary].closed_at, baseline_end)
        self.assertEqual(p.selected_successor_term_id, successor)
        self.assertEqual(m.accounting.outstanding_penalty_credits, 0)

    def test_premium_continues_past_minimum_tenure_within_actual_reserve(self):
        p, m, _, _, successor, _, _ = self.promoted("after-failover")
        service = p.seat_services[successor]
        start = service.responsibility_start
        self.assertEqual(p.arm_normal_context(
            settlement.Clock(1_070, start)), "ARMED")
        self.assertEqual(p.activate_normal_context(
            settlement.Clock(1_071, start + 1)), "ACTIVATED")
        clock = settlement.Clock(1_140, service.prospective_recovery_at)
        candidate = settlement.candidate(p, clock, "successor-healthy",
                                         slot=service.prospective_target_tip)
        self.assertEqual(p.submit(candidate, clock), "ACCEPTED")
        self.assertTrue(p.sync(settlement.Clock(1_141, p.normal_deadline)))
        self.assertNotIn(successor, p.term_duty)
        credited = p.accrue_seat_premium(m, successor, settlement.Clock(
            1_200, start + 2_000 + m.premium_claim_delay_seconds,
        ))
        self.assertEqual(credited.amount, 200_000)
        self.assertGreater(credited.amount,
                           p.seat_terms[successor].ask * p.minimum_primary_tenure_seconds)
        self.assertEqual(m.accounting.reserved_premium, 600_000)
        self.assertEqual(m.accounting.outstanding_premium_claims
                         + m.accounting.reserved_premium, 800_000)

    def test_term_exposure_scales_with_funding_and_runway(self):
        for runway in (8_000, 16_000):
            with self.subTest(runway=runway):
                p, m, _, primary, successor, _, baseline_end = self.promoted(
                    "after-failover", runway=runway,
                )
                service = p.seat_services[successor]
                reserve = m.accounting.live_reserves[successor]
                exposure = economics.funded_promotion_exposure(
                    successor_ask=p.seat_terms[successor].ask,
                    predecessor_ask=p.seat_terms[primary].ask,
                    funded_reserve=reserve.reserved_wei,
                    funded_service_horizon=service.premium_funded_until
                        - service.responsibility_start,
                    eligible_baseline_overlap=baseline_end - service.responsibility_start,
                )
                self.assertEqual(exposure["maximumPremiumWei"], 100 * runway)
                self.assertEqual(reserve.reserved_wei, 100 * runway)
                self.assertEqual(m.accounting.free_premium, 0)
                self.assertEqual(exposure["maximumIncrementalOverlapWei"],
                                 100 * (baseline_end - service.responsibility_start))


if __name__ == "__main__":
    unittest.main(verbosity=2)
