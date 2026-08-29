#!/usr/bin/env python3
"""Adversarial tests for canonical seat duties and composed Market calls."""

from __future__ import annotations

import importlib.util
import copy
from dataclasses import dataclass, replace
import inspect
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parent
SETTLEMENT_PATH = ROOT / "settlement-window-model.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {path.name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


settlement = load_module("settlement_window_model_task4", SETTLEMENT_PATH)
market = load_module("seat_market_model_task4", ROOT / "seat-market-model.py")


def addr(label: str) -> str:
    raw = label.encode("ascii")
    if not raw or len(raw) > 20:
        raise ValueError("address label must contain 1..20 ASCII bytes")
    return "0x" + raw.ljust(20, b"\x00").hex()


def authorization():
    return market.TargetAuthorization(
        target=addr("settlement"),
        settlement_chain_id=1,
        protocol_version=25,
        runtime_hash=b"r" * 32,
        configuration_hash=b"c" * 32,
        expected_magic=b"SEAT",
    )


def make_pair(
    *,
    tip_slot=1_000,
    runway=settlement.SEAT_RUNWAY_SECONDS,
    market_label="market",
):
    seat_market = market.SeatMarket(
        market_chain_id=1,
        market_address=addr(market_label),
        sla_bond=1_000,
        immutable_maximum_ask=100,
        quote_maturity_seconds=10,
        quote_maturity_blocks=3,
        exit_delay_seconds=settlement.EXIT_DELAY_SECONDS,
        penalty_sink=addr("penalty"),
        authorization=authorization(),
        insertion_enabled=True,
        cached_generation=7,
        seat_runway_seconds=runway,
        handover_delay_seconds=settlement.HANDOVER_DELAY_SECONDS,
        stage_grace_seconds=settlement.STAGE_GRACE_SECONDS,
        maximum_inclusion_seconds=settlement.T_INCLUDE_MAX_SECONDS,
        premium_claim_delay_seconds=10,
        release_challenge_seconds=20,
        reorg_stability_seconds=30,
        evidence_delay_seconds=40,
    )
    protocol = settlement.protocol(
        tip_slot=tip_slot,
        seat=False,
        settlement_address=authorization().target,
    )
    protocol.seat_runway_seconds = runway
    protocol.bind_seat_market_for_test(seat_market)
    return protocol, seat_market


def insert_offer(seat_market, operator, ask, timestamp, block_number):
    return seat_market.insert_offer(
        caller=addr(operator),
        payout=addr(f"pay-{operator}"),
        ask_wei_per_second=ask,
        target=authorization().target,
        generation=7,
        clock=market.Clock(timestamp, block_number),
        value=seat_market.sla_bond,
    )


def install_offer(
    protocol,
    seat_market,
    operator,
    ask,
    *,
    quoted_at,
    quoted_block,
):
    seat_market.sponsor_premium(ask * seat_market.seat_runway_seconds)
    row = insert_offer(
        seat_market, operator, ask, quoted_at, quoted_block
    )
    staged = protocol.stage_best(
        seat_market,
        settlement.Clock(
            quoted_block + seat_market.quote_maturity_blocks,
            quoted_at + seat_market.quote_maturity_seconds,
        ),
    )
    if staged == "SYNCED" or staged.code is not market.ResultCode.STAGED:
        raise AssertionError("fixture did not stage")
    installed = protocol.apply_stage(
        seat_market,
        settlement.Clock(
            quoted_block + seat_market.quote_maturity_blocks + 1,
            staged.stage.handover_at,
        ),
    )
    term_id = installed.tranche.installed_term_id
    return row, term_id


def synthetic_term(index: int, installed_at: int, ask: int = 1):
    byte = index.to_bytes(1, "big")
    return settlement.SeatTerm(
        byte * 32,
        (index + 32).to_bytes(1, "big") * 32,
        (index + 64).to_bytes(1, "big") * 32,
        f"operator-{index}",
        f"payout-{index}",
        ask,
        installed_at,
    )


def canonical_cure(protocol, duty, *, at=None, tip=None):
    timestamp = duty.slash_at if at is None else at
    target_tip = duty.target_tip if tip is None else tip
    clock = settlement.Clock(
        protocol.canonical.canonicalized_at_block + 1,
        timestamp,
    )
    candidate = settlement.candidate(
        protocol,
        clock,
        f"cure-{duty.sequence}",
        slot=target_tip,
    )
    protocol._commit(candidate, clock)
    return clock


def activate_current_duty(protocol, *, open_recovery=True):
    term_id = protocol.active_primary_term_id
    if term_id is None:
        raise AssertionError("fixture has no active primary")
    service = protocol.seat_services[term_id]
    if service.prospective_recovery_at is None:
        raise AssertionError("fixture has no prospective recovery boundary")
    clock = settlement.Clock(
        protocol.canonical.canonicalized_at_block + 1,
        service.prospective_recovery_at + 1,
    )
    changed = (
        protocol.sync(clock)
        if open_recovery
        else protocol._sync_seat_deadlines(clock)
    )
    if not changed or term_id not in protocol.term_duty:
        raise AssertionError("fixture did not activate the due duty")
    return protocol.seat_duties[protocol.term_duty[term_id]]


def accept_qualifying_normal_best(protocol, term_id, *, block_number=300):
    service = protocol.seat_services[term_id]
    arm_at = max(
        service.responsibility_start,
        settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
    ) + 1
    protocol.normal_arm_block_number = None
    if protocol.arm_normal_context(
        settlement.Clock(block_number, arm_at)
    ) != "ARMED":
        raise AssertionError("fixture did not arm normal context")
    if protocol.activate_normal_context(
        settlement.Clock(block_number + 1, arm_at)
    ) != "ACTIVATED":
        raise AssertionError("fixture did not activate normal context")
    submit_clock = settlement.Clock(
        block_number + 2,
        service.prospective_recovery_at,
    )
    candidate = settlement.candidate(
        protocol,
        submit_clock,
        f"mature-seat-best-{block_number}",
        slot=service.prospective_target_tip,
    )
    if protocol.submit(candidate, submit_clock) != "ACCEPTED":
        raise AssertionError("fixture did not accept qualifying normal best")
    return candidate


@dataclass
class RejectingCanonicalHistory:
    forced_queue: object
    inbox_apply_router: object
    migration_gate: object
    live_protocol: object
    attempts: int = 0

    def record_canonical(self, _core, *, l1_block):
        self.attempts += 1
        return None


def canonical_graph_state(protocol, history):
    """Deep state snapshot with shared authority identities made explicit."""

    protocol_local = {
        key: value
        for key, value in protocol.__dict__.items()
        if key
        not in {
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "versioned_history",
        }
    }
    history_local = {
        key: value
        for key, value in history.__dict__.items()
        if key
        not in {
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "live_protocol",
        }
    }
    return copy.deepcopy(
        (
            protocol_local,
            history_local,
            protocol.forced_queue.__dict__,
            protocol.inbox_apply_router.__dict__,
            protocol.migration_gate.__dict__,
            history.forced_queue.__dict__,
            history.inbox_apply_router.__dict__,
            history.migration_gate.__dict__,
            protocol.versioned_history is history,
            history.forced_queue is protocol.forced_queue,
            history.inbox_apply_router is protocol.inbox_apply_router,
            history.migration_gate is protocol.migration_gate,
            history.live_protocol is protocol,
        )
    )


class SourceFreezeTests(unittest.TestCase):
    def test_immediate_burn_authority_is_deleted_but_core_gap_bound_remains(self):
        source = SETTLEMENT_PATH.read_text()
        self.assertNotIn("burned_local", source)
        self.assertNotIn("terminated: bool", source)
        self.assertNotIn("self.active_seat.terminated = True", source)
        self.assertIn("G_MAX = DELTA_FINAL_LAG", source)

    def test_canonical_seat_records_exist(self):
        for name in (
            "SeatTerm",
            "SeatService",
            "Duty",
            "DutyStatus",
            "SeatDutyCell",
            "SelectionRecord",
            "SelectionSource",
            "SettlementSeatStage",
        ):
            self.assertTrue(hasattr(settlement, name), name)

    def test_production_facade_accepts_ids_not_caller_supplied_views(self):
        expected = {
            "stage_best",
            "apply_stage",
            "expire_stage",
            "reconcile_stage_invalidation",
            "accrue_seat_premium",
            "reconcile_seat_reserve",
            "request_bond_release",
            "finalize_bond_release",
            "enforce_seat_breach",
        }
        for name in expected:
            parameters = inspect.signature(
                getattr(settlement.Protocol, name)
            ).parameters
            self.assertNotIn("view", parameters)
            self.assertNotIn("cap", parameters)
            self.assertNotIn("payout", parameters)
        self.assertIn(
            "accrue_premium", settlement.NON_PROTOCOL_MARKET_UNIT_PRIMITIVES
        )
        self.assertIn(
            "finalize_release", settlement.NON_PROTOCOL_MARKET_UNIT_PRIMITIVES
        )


class CanonicalDutyTests(unittest.TestCase):
    def primary(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        duty = activate_current_duty(protocol)
        return protocol, term, duty

    def test_thresholds_and_target_are_frozen_from_old_tip(self):
        protocol, term, duty = self.primary()
        tip_time = settlement.GENESIS_TIMESTAMP + 1_000
        self.assertEqual(duty.term_id, term.term_id)
        self.assertEqual(duty.tranche_id, term.tranche_id)
        self.assertEqual(duty.operator, term.operator)
        self.assertEqual(duty.base_sequence, 900)
        self.assertEqual(duty.target_tip, 1_000 + settlement.DELTA_RECOVERY_LAG)
        self.assertEqual(
            duty.recovery_at, tip_time + settlement.DELTA_RECOVERY_LAG
        )
        self.assertEqual(duty.failover_at, tip_time + settlement.G_MAX)
        self.assertEqual(duty.slash_at, tip_time + settlement.DELTA_SLASH_LAG)
        self.assertEqual(settlement.G_MAX, settlement.DELTA_FINAL_LAG)

    def test_recovery_miss_is_strict_before_equal_after(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        recovery_at = protocol.seat_services[term.term_id].prospective_recovery_at
        for timestamp, changed in (
            (recovery_at - 1, False),
            (recovery_at, False),
            (recovery_at + 1, True),
        ):
            clone = copy.deepcopy(protocol)
            self.assertEqual(
                clone.sync(settlement.Clock(1_100, timestamp)), changed
            )
            self.assertEqual(term.term_id in clone.term_duty, changed)
            self.assertEqual(
                clone.mode,
                settlement.Mode.RECOVERY if changed else settlement.Mode.NORMAL,
            )

    def test_failover_and_slash_are_strict_and_do_not_burn_locally(self):
        protocol, term, duty = self.primary()
        equal = copy.deepcopy(protocol)
        equal.sync(settlement.Clock(1_100, duty.failover_at))
        equal_duty = equal.seat_duties[duty.duty_id]
        self.assertEqual(equal_duty.status, settlement.DutyStatus.OPEN)
        self.assertIn(term.term_id, equal.seat_lineup)

        late = copy.deepcopy(protocol)
        late.sync(settlement.Clock(1_100, duty.failover_at + 1))
        late_duty = late.seat_duties[duty.duty_id]
        self.assertEqual(late_duty.status, settlement.DutyStatus.FAILED_OVER)
        self.assertNotIn(term.term_id, late.seat_lineup)
        late.sync(settlement.Clock(1_101, duty.slash_at))
        self.assertEqual(late_duty.status, settlement.DutyStatus.FAILED_OVER)
        late.sync(settlement.Clock(1_102, duty.slash_at + 1))
        self.assertEqual(late_duty.status, settlement.DutyStatus.BREACHED)
        self.assertEqual(late_duty.breach_recorded_at, duty.slash_at + 1)

    def test_cure_requires_both_sequence_and_target_tip(self):
        protocol, _, duty = self.primary()
        sequence_only = copy.deepcopy(protocol)
        sequence_only.core.l2_block_number += 1
        self.assertEqual(
            sequence_only._latch_canonical_cures(
                settlement.Clock(1_100, duty.recovery_at)
            ),
            0,
        )
        tip_only = copy.deepcopy(protocol)
        tip_only.core.tip_slot = duty.target_tip
        self.assertEqual(
            tip_only._latch_canonical_cures(
                settlement.Clock(1_100, duty.recovery_at)
            ),
            0,
        )
        both = copy.deepcopy(protocol)
        canonical_cure(both, both.seat_duties[duty.duty_id], at=duty.slash_at)
        cured = both.seat_duties[duty.duty_id]
        self.assertEqual(cured.status, settlement.DutyStatus.SATISFIED)
        first = cured.satisfied_at
        both._latch_canonical_cures(
            settlement.Clock(1_200, duty.slash_at + 1)
        )
        self.assertEqual(cured.satisfied_at, first)

    def test_after_slash_catchup_advances_core_but_never_cures(self):
        protocol, _, duty = self.primary()
        protocol.sync(settlement.Clock(1_100, duty.slash_at + 1))
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.BREACHED,
        )
        old_sequence = protocol.core.l2_block_number
        canonical_cure(
            protocol,
            protocol.seat_duties[duty.duty_id],
            at=duty.slash_at + 2,
            tip=duty.target_tip + 1,
        )
        self.assertEqual(protocol.core.l2_block_number, old_sequence + 1)
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.BREACHED,
        )

    def test_same_commit_orders_failover_before_cure_and_breach_before_rejection(self):
        protocol, _, duty = self.primary()
        standby = synthetic_term(2, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        failover_commit = settlement.Clock(1_300, duty.failover_at + 1)
        protocol._commit(
            settlement.candidate(
                protocol,
                failover_commit,
                "same-commit-failover-cure",
                slot=duty.target_tip,
            ),
            failover_commit,
        )
        self.assertEqual(duty.status, settlement.DutyStatus.SATISFIED)
        self.assertEqual(
            protocol.seat_services[duty.term_id].closed_at,
            duty.failover_at,
        )
        self.assertEqual(protocol.active_primary_term_id, standby.term_id)
        self.assertEqual(protocol.seat_scan_count, settlement.DUTY_RING_CAPACITY)

        breached, _, breached_duty = self.primary()
        late_commit = settlement.Clock(1_301, breached_duty.slash_at + 1)
        breached._commit(
            settlement.candidate(
                breached,
                late_commit,
                "same-commit-post-slash",
                slot=breached_duty.target_tip,
            ),
            late_commit,
        )
        self.assertEqual(
            breached_duty.status, settlement.DutyStatus.BREACHED
        )
        self.assertIsNone(breached_duty.satisfied_at)
        self.assertEqual(
            breached.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )
    def test_failover_selects_but_cure_later_starts_same_standby_identity(self):
        protocol, primary, duty = self.primary()
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(
            standby, rank=1, start_primary=False
        )
        protocol.sync(settlement.Clock(1_100, duty.failover_at + 1))
        selected_service = protocol.seat_services[standby.term_id]
        self.assertEqual(protocol.selected_successor_term_id, standby.term_id)
        self.assertIsNone(selected_service.responsibility_start)
        canonical_cure(
            protocol,
            protocol.seat_duties[duty.duty_id],
            at=duty.failover_at + 2,
            tip=duty.target_tip + 1,
        )
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertEqual(
            protocol.active_primary_term_id, standby.term_id
        )
        self.assertEqual(
            protocol.seat_services[standby.term_id].responsibility_start,
            duty.failover_at + 2,
        )
        self.assertEqual(protocol.preview_premium_cap(primary.term_id), duty.failover_at)

    def test_force_only_recovery_does_not_reset_attached_duty(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        service = protocol.seat_services[term.term_id]
        protocol.forced_queue.append(
            settlement.message(0, "force"),
            deposit=1,
            due_at=service.prospective_recovery_at - 10,
            caller=protocol.forced_queue.router_address,
        )
        self.assertTrue(
            protocol.sync(
                settlement.Clock(1_100, service.prospective_recovery_at - 9)
            )
        )
        self.assertEqual(protocol.recovery.causes, settlement.Cause.FORCE_DUE)
        self.assertNotIn(term.term_id, protocol.term_duty)
        base = (service.duty_base_tip_slot, service.duty_base_sequence)
        self.assertTrue(
            protocol.sync(
                settlement.Clock(1_101, service.prospective_recovery_at + 1)
            )
        )
        duty = protocol.seat_duties[protocol.term_duty[term.term_id]]
        self.assertEqual((duty.base_tip_slot, duty.base_sequence), base)
        self.assertEqual(protocol.duty_sequence, 1)

    def test_commit_scan_is_bounded_to_four_and_satisfied_at_is_immutable(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        for index in range(1, 5):
            term = synthetic_term(index, settlement.GENESIS_TIMESTAMP + 1_000)
            protocol.install_seat_term_for_test(
                term, rank=len(protocol.seat_lineup), start_primary=index == 1
            )
            if index > 1:
                protocol._start_seat_service(
                    term.term_id,
                    term.installed_at,
                    base_tip_slot=protocol.core.tip_slot,
                    base_sequence=protocol.core.l2_block_number,
                )
            protocol._attach_duty(term.term_id)
        protocol.core.l2_block_number += 1
        protocol.core.tip_slot += settlement.DELTA_RECOVERY_LAG
        protocol._latch_canonical_cures(
            settlement.Clock(1_100, settlement.GENESIS_TIMESTAMP + 2_200)
        )
        self.assertEqual(protocol.seat_scan_count, settlement.SEAT_COUNT)
        self.assertLessEqual(protocol.seat_scan_count, 4)

    def test_recovery_submit_has_one_total_four_cell_pass(self):
        no_change = settlement.protocol(tip_slot=1_000, seat=False)
        settlement.open_recovery(no_change)
        no_change_clock = settlement.recovery_submit_clock(no_change)
        no_change_candidate = settlement.escape_candidate(
            no_change, no_change_clock, "single-pass-no-change"
        )
        visits_before = no_change.seat_scan_visits_total
        self.assertEqual(
            no_change.submit(no_change_candidate, no_change_clock),
            "COMMITTED",
        )
        self.assertEqual(
            no_change.seat_scan_visits_total - visits_before,
            settlement.DUTY_RING_CAPACITY,
        )

        def duty_recovery_fixture():
            protocol = settlement.protocol(tip_slot=1_000, seat=False)
            installed_at = settlement.GENESIS_TIMESTAMP + 1_000
            primary = synthetic_term(1, installed_at)
            standby = synthetic_term(2, installed_at)
            protocol.install_seat_term_for_test(
                primary, rank=0, start_primary=True
            )
            protocol.install_seat_term_for_test(
                standby, rank=1, start_primary=False
            )
            duty = activate_current_duty(protocol, open_recovery=True)
            protocol.recovery.expires_at = duty.slash_at
            commit_clock = settlement.Clock(
                protocol.recovery.anchor_number + settlement.F_L1,
                duty.failover_at + 1,
            )
            candidate = settlement.candidate(
                protocol,
                commit_clock,
                "single-pass-failover-cure",
                tier=settlement.Tier.RECOVERY_SIGNED,
                slot=commit_clock.l2_slot,
                recovery_fields_zero=False,
            )
            return protocol, primary, standby, duty, commit_clock, candidate

        protocol, primary, standby, duty, commit_clock, candidate = (
            duty_recovery_fixture()
        )
        visits_before = protocol.seat_scan_visits_total
        self.assertEqual(protocol.submit(candidate, commit_clock), "COMMITTED")
        self.assertEqual(
            protocol.seat_scan_visits_total - visits_before,
            settlement.DUTY_RING_CAPACITY,
        )
        self.assertIs(duty.status, settlement.DutyStatus.SATISFIED)
        self.assertEqual(
            protocol.seat_services[primary.term_id].closed_at,
            duty.failover_at,
        )
        self.assertEqual(protocol.active_primary_term_id, standby.term_id)

        protocol, _, _, duty, commit_clock, candidate = duty_recovery_fixture()
        candidate = replace(candidate, proof_ok=False)
        visits_before = protocol.seat_scan_visits_total
        self.assertEqual(protocol.submit(candidate, commit_clock), "SYNCED")
        self.assertEqual(
            protocol.seat_scan_visits_total - visits_before,
            settlement.DUTY_RING_CAPACITY,
        )
        retained = protocol.seat_duties[duty.duty_id]
        self.assertIs(retained.status, settlement.DutyStatus.FAILED_OVER)

    def test_historical_duty_cure_cannot_promote_unrelated_selection(self):
        for unrelated_source in (
            settlement.SelectionSource.DUTY_FAILOVER,
            settlement.SelectionSource.HEALTHY_EXPIRY,
        ):
            protocol = settlement.protocol(tip_slot=1_000, seat=False)
            installed_at = settlement.GENESIS_TIMESTAMP + 1_000
            first = synthetic_term(1, installed_at)
            second = synthetic_term(2, installed_at)
            third = synthetic_term(3, installed_at)
            for rank, term in enumerate((first, second, third)):
                protocol.install_seat_term_for_test(
                    term, rank=rank, start_primary=rank == 0
                )
            if unrelated_source is settlement.SelectionSource.DUTY_FAILOVER:
                first_attachment = protocol._attach_duty(first.term_id)
                first_duty = first_attachment.duty
                if first_duty is None:
                    raise AssertionError("first duty fixture failed")
                protocol._start_seat_service(
                    second.term_id,
                    installed_at,
                    base_tip_slot=1_100,
                    base_sequence=protocol.core.l2_block_number,
                )
                second_attachment = protocol._attach_duty(second.term_id)
                second_duty = second_attachment.duty
                if second_duty is None:
                    raise AssertionError("second duty fixture failed")
                protocol._sync_seat_deadlines(
                    settlement.Clock(1_102, second_duty.failover_at + 1)
                )
                self.assertLess(
                    second_duty.failover_at, first_duty.slash_at
                )
                self.assertEqual(
                    protocol.seat_selection.predecessor_duty_id,
                    second_duty.duty_id,
                )
                cure_at = second_duty.failover_at + 1
            else:
                first_duty = activate_current_duty(
                    protocol, open_recovery=False
                )
                protocol._sync_seat_deadlines(
                    settlement.Clock(1_101, first_duty.failover_at + 1)
                )
                protocol._promote_selected(first_duty.failover_at + 2)
                remove_at = first_duty.failover_at + 3
                protocol._close_service(
                    second.term_id, remove_at, "FUNDING_EXPIRED"
                )
                protocol._remove_lineup_term(second.term_id, remove_at)
                protocol._advance_lineup_revision()
                protocol._select_successor(
                    selected_at=remove_at,
                    source=settlement.SelectionSource.HEALTHY_EXPIRY,
                    target_tip=first_duty.target_tip + 1,
                )
                self.assertIsNone(
                    protocol.seat_selection.predecessor_duty_id
                )
                cure_at = first_duty.failover_at + 4
            selection = copy.deepcopy(protocol.seat_selection)
            third_service = protocol.seat_services[third.term_id]
            cure_clock = settlement.Clock(
                1_103,
                cure_at,
            )
            cure = settlement.candidate(
                protocol,
                cure_clock,
                f"historical-isolation-{unrelated_source.name}",
                slot=first_duty.target_tip,
            )
            protocol._commit(cure, cure_clock)
            self.assertIs(
                protocol.seat_duties[first_duty.duty_id].status,
                settlement.DutyStatus.SATISFIED,
            )
            self.assertEqual(protocol.seat_selection, selection)
            self.assertIsNone(third_service.responsibility_start)


class BombMarket:
    calls = 0

    def __deepcopy__(self, memo):
        return self

    def __eq__(self, other):
        return self is other

    def __getattr__(self, name):
        type(self).calls += 1
        raise AssertionError(f"canonical path called Market.{name}")


class CanonicalNoMarketTests(unittest.TestCase):
    def test_canonical_surfaces_have_no_market_parameter(self):
        for name in ("sync", "_commit", "preview_premium_cap"):
            self.assertNotIn(
                "market", inspect.signature(getattr(settlement.Protocol, name)).parameters
            )

    def test_leading_sync_returns_synced_without_touching_bomb_market(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        recovery_at = protocol.seat_services[term.term_id].prospective_recovery_at
        BombMarket.calls = 0
        result = protocol.stage_best(
            BombMarket(), settlement.Clock(1_100, recovery_at + 1)
        )
        self.assertEqual(result, "SYNCED")
        self.assertEqual(BombMarket.calls, 0)
        self.assertIn(term.term_id, protocol.term_duty)


class ComposedTransactionTests(unittest.TestCase):
    def test_ordinary_progress_refreshes_prospective_duty_without_allocating_ring(self):
        protocol, seat_market = make_pair(runway=8_000)
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, term_id = install_offer(
            protocol,
            seat_market,
            "alice",
            10,
            quoted_at=tip_time,
            quoted_block=100,
        )
        service = protocol.seat_services[term_id]
        original_recovery_at = tip_time + settlement.DELTA_RECOVERY_LAG
        self.assertNotIn(term_id, protocol.term_duty)
        self.assertEqual(protocol.duty_sequence, 0)
        self.assertTrue(all(cell.reusable for cell in protocol.duty_ring))
        self.assertEqual(service.duty_base_tip_slot, 1_000)
        self.assertEqual(service.duty_base_sequence, 900)
        self.assertEqual(service.prospective_recovery_at, original_recovery_at)

        for round_index, target_tip in enumerate((2_200, 3_400)):
            service = protocol.seat_services[term_id]
            arm_at = max(service.responsibility_start, protocol.core.tip_slot
                         + settlement.GENESIS_TIMESTAMP) + round_index + 1
            arm_block = 105 + round_index * 4
            self.assertEqual(
                protocol.arm_normal_context(
                    settlement.Clock(arm_block, arm_at)
                ),
                "ARMED",
            )
            self.assertEqual(
                protocol.activate_normal_context(
                    settlement.Clock(arm_block + 1, arm_at)
                ),
                "ACTIVATED",
            )
            recovery_at = service.prospective_recovery_at
            submit_clock = settlement.Clock(arm_block + 2, recovery_at)
            qualifying = settlement.candidate(
                protocol,
                submit_clock,
                f"ordinary-seat-progress-{round_index}",
                slot=target_tip,
            )
            self.assertEqual(protocol.submit(qualifying, submit_clock), "ACCEPTED")
            self.assertTrue(
                protocol.sync(
                    settlement.Clock(
                        arm_block + 3,
                        protocol.normal_deadline,
                    )
                )
            )
            service = protocol.seat_services[term_id]
            self.assertEqual(protocol.active_primary_term_id, term_id)
            self.assertIsNone(service.closed_at)
            self.assertNotIn(term_id, protocol.term_duty)
            self.assertEqual(protocol.duty_sequence, 0)
            self.assertTrue(all(cell.reusable for cell in protocol.duty_ring))
            self.assertEqual(service.duty_base_tip_slot, target_tip)
            self.assertEqual(service.duty_base_sequence, 901 + round_index)
            self.assertEqual(
                service.prospective_recovery_at,
                settlement.GENESIS_TIMESTAMP
                    + target_tip
                    + settlement.DELTA_RECOVERY_LAG,
            )

    def test_direct_install_uses_common_runway_and_prospective_duty(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        row, term_id = install_offer(
            protocol,
            seat_market,
            "alice",
            10,
            quoted_at=tip_time,
            quoted_block=100,
        )
        term = protocol.seat_terms[term_id]
        service = protocol.seat_services[term_id]
        self.assertEqual(term.tranche_id, row.tranche.tranche_id)
        self.assertEqual(service.responsibility_start, term.installed_at)
        self.assertEqual(
            service.minimum_tenure_until,
            term.installed_at + settlement.MIN_PRIMARY_TENURE_SECONDS,
        )
        self.assertEqual(
            service.premium_funded_until,
            term.installed_at + settlement.SEAT_RUNWAY_SECONDS,
        )
        self.assertEqual(
            service.service_eligible_until,
            service.premium_funded_until - settlement.SLA_TAIL_SECONDS,
        )
        self.assertNotIn(term_id, protocol.term_duty)
        self.assertEqual(service.duty_base_tip_slot, 1_000)
        self.assertEqual(service.duty_base_sequence, 900)
        self.assertEqual(service.prospective_target_tip, 2_200)
        self.assertTrue(all(cell.reusable for cell in protocol.duty_ring))
        self.assertEqual(protocol.active_primary_term_id, term_id)
        seat_market.assert_valid()

    def test_recovery_crossing_tombstones_stage_and_retry_cannot_apply(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol,
            seat_market,
            "alice",
            10,
            quoted_at=tip_time,
            quoted_block=100,
        )
        recovery_at = protocol.seat_services[primary].prospective_recovery_at
        seat_market.sponsor_premium(5 * seat_market.seat_runway_seconds)
        insert_offer(
            seat_market,
            "bob",
            5,
            recovery_at - 11,
            200,
        )
        staged = protocol.stage_best(
            seat_market,
            settlement.Clock(203, recovery_at - 1),
        )
        self.assertEqual(staged.code, market.ResultCode.STAGED)
        stage = copy.deepcopy(protocol.settlement_seat_stage)
        self.assertGreater(stage.handover_at, recovery_at)
        market_staged = copy.deepcopy(seat_market)

        self.assertEqual(
            protocol.apply_stage(
                seat_market,
                settlement.Clock(204, stage.handover_at),
            ),
            "SYNCED",
        )
        self.assertEqual(seat_market, market_staged)
        self.assertIs(protocol.mode, settlement.Mode.RECOVERY)
        self.assertIsNone(protocol.settlement_seat_stage)
        self.assertIn(stage.stage_id, protocol.stage_tombstones)
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.apply_stage(
                seat_market,
                settlement.Clock(205, stage.handover_at + 1),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])

    def test_mature_best_replays_before_old_failover_and_slash_boundaries(self):
        for offset, expected_status in (
            (settlement.DELTA_FINAL_LAG + 1, settlement.DutyStatus.OPEN),
            (settlement.DELTA_SLASH_LAG + 1, settlement.DutyStatus.FAILED_OVER),
        ):
            with self.subTest(offset=offset):
                protocol, seat_market = make_pair(runway=8_000)
                tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
                _, primary = install_offer(
                    protocol,
                    seat_market,
                    "alice",
                    10,
                    quoted_at=tip_time,
                    quoted_block=100,
                )
                if expected_status is settlement.DutyStatus.FAILED_OVER:
                    install_offer(
                        protocol,
                        seat_market,
                        "bob",
                        20,
                        quoted_at=tip_time + 20,
                        quoted_block=110,
                    )
                old_base_tip = protocol.seat_services[primary].duty_base_tip_slot
                accept_qualifying_normal_best(protocol, primary)
                sync_at = (
                    settlement.GENESIS_TIMESTAMP + old_base_tip + offset
                )
                self.assertTrue(
                    protocol.sync(settlement.Clock(400 + offset, sync_at))
                )
                duty = protocol.seat_duties[protocol.term_duty[primary]]
                self.assertEqual(duty.base_tip_slot, 2_200)
                self.assertEqual(duty.base_sequence, 901)
                self.assertEqual(duty.recovery_at, 1_003_400)
                self.assertEqual(duty.failover_at, 1_005_800)
                self.assertEqual(duty.slash_at, 1_007_364)
                self.assertIs(duty.status, expected_status)
                self.assertEqual(
                    protocol.seat_scan_count,
                    settlement.DUTY_RING_CAPACITY,
                )
                if expected_status is settlement.DutyStatus.OPEN:
                    self.assertEqual(protocol.active_primary_term_id, primary)
                else:
                    self.assertEqual(
                        protocol.seat_services[primary].closed_at,
                        duty.failover_at,
                    )

    def test_single_ring_scan_and_history_rejection_rolls_back_every_protocol_byte(self):
        protocol, seat_market = make_pair(runway=8_000)
        RingAndReclamationTests.fill_history_ring(protocol)
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol,
            seat_market,
            "alice",
            10,
            quoted_at=tip_time,
            quoted_block=100,
        )
        accept_qualifying_normal_best(protocol, primary, block_number=500)
        self.assertTrue(
            protocol.sync(
                settlement.Clock(503, protocol.normal_deadline)
            )
        )
        self.assertEqual(
            protocol.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )

        no_commit = settlement.protocol(tip_slot=1_000, seat=False)
        RingAndReclamationTests.fill_history_ring(no_commit)
        self.assertFalse(
            no_commit.sync(
                settlement.Clock(600, settlement.GENESIS_TIMESTAMP + 1_001)
            )
        )
        self.assertEqual(
            no_commit.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )

        cached = settlement.protocol(tip_slot=1_000, seat=False)
        RingAndReclamationTests.fill_history_ring(cached)
        cached.duty_ring[0].reusable = True
        active = synthetic_term(9, settlement.GENESIS_TIMESTAMP + 1_000)
        cached.install_seat_term_for_test(active, rank=0, start_primary=True)
        recovery_at = cached.seat_services[active.term_id].prospective_recovery_at
        self.assertTrue(
            cached.sync(settlement.Clock(601, recovery_at + 1))
        )
        self.assertIn(active.term_id, cached.term_duty)
        self.assertEqual(
            cached.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )

        rejected, rejected_market = make_pair(runway=8_000)
        rejected_tip_time = (
            settlement.GENESIS_TIMESTAMP + rejected.core.tip_slot
        )
        _, rejected_primary = install_offer(
            rejected,
            rejected_market,
            "alice",
            10,
            quoted_at=rejected_tip_time,
            quoted_block=100,
        )
        accept_qualifying_normal_best(
            rejected, rejected_primary, block_number=700
        )
        service = rejected.seat_services[rejected_primary]
        rejected.versioned_history = RejectingCanonicalHistory(
            rejected.forced_queue,
            rejected.inbox_apply_router,
            rejected.migration_gate,
            rejected,
        )
        before = canonical_graph_state(rejected, rejected.versioned_history)
        with self.assertRaises(AssertionError):
            rejected.sync(
                settlement.Clock(703, service.prospective_failover_at + 1)
            )
        self.assertEqual(
            canonical_graph_state(rejected, rejected.versioned_history),
            before,
        )

    def test_successful_history_write_then_seat_fault_restores_shared_aliases(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        history = settlement.VersionedSettlementHistory(
            "model-settlement",
            "runtime:atomic-success",
            1,
            "profile:atomic-success",
            copy.deepcopy(protocol.core),
            99,
            protocol.forced_queue,
            mode="ACTIVE",
            current_sequence=0,
            last_canonical_l1_block=100,
            migration_gate=protocol.migration_gate,
            live_protocol=protocol,
            inbox_apply_router=protocol.inbox_apply_router,
        )
        protocol.versioned_history = history
        queue = protocol.forced_queue
        router = protocol.inbox_apply_router
        gate = protocol.migration_gate
        commit_clock = settlement.Clock(
            101, settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        )
        candidate = settlement.candidate(
            protocol, commit_clock, "history-success-then-seat-fault"
        )
        protocol.seat_fault_point = "after_history_record"
        before = canonical_graph_state(protocol, history)
        with self.assertRaises(RuntimeError):
            protocol._commit(candidate, commit_clock)
        self.assertEqual(canonical_graph_state(protocol, history), before)
        self.assertIs(protocol.versioned_history, history)
        self.assertIs(protocol.forced_queue, queue)
        self.assertIs(protocol.inbox_apply_router, router)
        self.assertIs(protocol.migration_gate, gate)
        self.assertIs(history.forced_queue, queue)
        self.assertIs(history.inbox_apply_router, router)
        self.assertIs(history.migration_gate, gate)

    def test_wrong_canonical_history_authority_graph_rejects_before_attempt(self):
        for wrong_field in (
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "live_protocol",
        ):
            protocol, seat_market = make_pair(runway=8_000)
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            _, primary = install_offer(
                protocol,
                seat_market,
                f"primary-{wrong_field[:4]}",
                10,
                quoted_at=tip_time,
                quoted_block=100,
            )
            accept_qualifying_normal_best(protocol, primary, block_number=500)
            history = RejectingCanonicalHistory(
                protocol.forced_queue,
                protocol.inbox_apply_router,
                protocol.migration_gate,
                protocol,
            )
            if wrong_field == "live_protocol":
                history.live_protocol = None
            else:
                setattr(history, wrong_field, copy.deepcopy(getattr(history, wrong_field)))
            protocol.versioned_history = history
            commit_clock = settlement.Clock(503, protocol.normal_deadline)
            before = canonical_graph_state(protocol, history)
            exact_objects = (
                protocol.forced_queue,
                protocol.inbox_apply_router,
                protocol.migration_gate,
                history.forced_queue,
                history.inbox_apply_router,
                history.migration_gate,
                history.live_protocol,
            )
            with self.assertRaisesRegex(
                AssertionError, "invalid canonical history authority graph"
            ):
                protocol.sync(commit_clock)
            self.assertEqual(canonical_graph_state(protocol, history), before)
            self.assertEqual(history.attempts, 0)
            self.assertEqual(
                exact_objects,
                (
                    protocol.forced_queue,
                    protocol.inbox_apply_router,
                    protocol.migration_gate,
                    history.forced_queue,
                    history.inbox_apply_router,
                    history.migration_gate,
                    history.live_protocol,
                ),
            )

    def test_composed_fault_restores_bound_history_and_shared_aliases(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "alice", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = copy.deepcopy(protocol.settlement_seat_stage)
        history = settlement.VersionedSettlementHistory(
            protocol.settlement_address,
            "runtime:composed-fault",
            1,
            "profile:composed-fault",
            copy.deepcopy(protocol.core),
            99,
            protocol.forced_queue,
            mode="ACTIVE",
            current_sequence=0,
            last_canonical_l1_block=100,
            migration_gate=protocol.migration_gate,
            live_protocol=protocol,
            inbox_apply_router=protocol.inbox_apply_router,
        )
        protocol.versioned_history = history
        queue = protocol.forced_queue
        router = protocol.inbox_apply_router
        gate = protocol.migration_gate
        protocol.seat_fault_point = "after_market_install"
        before = canonical_graph_state(protocol, history)
        market_before = copy.deepcopy(seat_market)
        with self.assertRaises(RuntimeError):
            protocol.apply_stage(
                seat_market,
                settlement.Clock(104, stage.handover_at),
            )
        self.assertEqual(canonical_graph_state(protocol, history), before)
        self.assertEqual(seat_market, market_before)
        self.assertIs(protocol.versioned_history, history)
        self.assertIs(protocol.forced_queue, queue)
        self.assertIs(protocol.inbox_apply_router, router)
        self.assertIs(protocol.migration_gate, gate)
        self.assertIs(history.forced_queue, queue)
        self.assertIs(history.inbox_apply_router, router)
        self.assertIs(history.migration_gate, gate)
        self.assertIs(history.live_protocol, protocol)

    def test_public_sync_fault_rolls_back_activated_and_prospective_duties(self):
        for activate_before_sync in (False, True):
            protocol, seat_market = make_pair(runway=8_000)
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            _, primary = install_offer(
                protocol,
                seat_market,
                f"alice-{int(activate_before_sync)}",
                10,
                quoted_at=tip_time,
                quoted_block=100,
            )
            service = protocol.seat_services[primary]
            recovery_at = service.prospective_recovery_at
            seat_market.sponsor_premium(5 * seat_market.seat_runway_seconds)
            insert_offer(
                seat_market,
                f"bob-{int(activate_before_sync)}",
                5,
                recovery_at - 11,
                200,
            )
            protocol.stage_best(
                seat_market,
                settlement.Clock(203, recovery_at - 1),
            )
            stage = copy.deepcopy(protocol.settlement_seat_stage)
            if activate_before_sync:
                attachment = protocol._attach_duty(primary)
                if attachment.duty is None:
                    raise AssertionError("fixture failed to attach duty")
                sync_at = attachment.duty.failover_at + 1
            else:
                sync_at = recovery_at + 1
            history = settlement.VersionedSettlementHistory(
                protocol.settlement_address,
                f"runtime:sync-fault:{activate_before_sync}",
                1,
                f"profile:sync-fault:{activate_before_sync}",
                copy.deepcopy(protocol.core),
                99,
                protocol.forced_queue,
                mode="ACTIVE",
                current_sequence=0,
                last_canonical_l1_block=100,
                migration_gate=protocol.migration_gate,
                live_protocol=protocol,
                inbox_apply_router=protocol.inbox_apply_router,
            )
            protocol.versioned_history = history
            protocol.seat_fault_point = "after_stage_tombstone"
            before = canonical_graph_state(protocol, history)
            with self.assertRaises(RuntimeError):
                protocol.sync(settlement.Clock(700, sync_at))
            self.assertEqual(canonical_graph_state(protocol, history), before)
            self.assertEqual(protocol.settlement_seat_stage, stage)
            self.assertNotIn(stage.stage_id, protocol.stage_tombstones)
            if activate_before_sync:
                duty = protocol.seat_duties[protocol.term_duty[primary]]
                self.assertIs(duty.status, settlement.DutyStatus.OPEN)
            else:
                self.assertNotIn(primary, protocol.term_duty)

    def test_four_term_lineup_and_standby_order_are_deterministic(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        installed = []
        for index, ask in enumerate((10, 20, 30, 40)):
            _, term_id = install_offer(
                protocol,
                seat_market,
                chr(ord("a") + index),
                ask,
                quoted_at=tip_time + index * 20,
                quoted_block=100 + index * 10,
            )
            installed.append(term_id)
        self.assertEqual(protocol.seat_lineup, installed)
        self.assertEqual(len(protocol.seat_lineup), settlement.SEAT_COUNT)
        self.assertEqual(protocol.active_primary_term_id, installed[0])
        for term_id in installed[1:]:
            self.assertIsNone(
                protocol.seat_services[term_id].responsibility_start
            )

    def test_replacement_preserves_every_standby_id_and_order(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol, seat_market, "a", 30,
            quoted_at=tip_time, quoted_block=100,
        )
        standbys = []
        for index, ask in enumerate((40, 50, 60), 1):
            _, term_id = install_offer(
                protocol, seat_market, chr(ord("a") + index), ask,
                quoted_at=tip_time + index * 20,
                quoted_block=100 + index * 10,
            )
            standbys.append(term_id)
        seat_market.sponsor_premium(20 * seat_market.seat_runway_seconds)
        insert_offer(seat_market, "z", 20, tip_time + 100, 200)
        staged = protocol.stage_best(
            seat_market,
            settlement.Clock(203, tip_time + 110),
        )
        self.assertEqual(staged.stage.selected_rank, 0)
        stage = protocol.settlement_seat_stage
        self.assertEqual(stage.outgoing_primary_term_id, primary)
        revision_before = protocol.seat_lineup_revision
        installed = protocol.apply_stage(
            seat_market,
            settlement.Clock(204, stage.handover_at),
        )
        new_term = installed.tranche.installed_term_id
        self.assertEqual(protocol.seat_lineup, [new_term, *standbys])
        self.assertEqual(protocol.seat_lineup_revision, revision_before + 1)
        self.assertEqual(
            protocol.seat_services[primary].close_reason,
            "HEALTHY_HANDOVER",
        )

    def test_healthy_progress_preserves_live_stage_lineup_commitment(self):
        protocol, seat_market = make_pair(runway=8_000)
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol,
            seat_market,
            "alice",
            30,
            quoted_at=tip_time,
            quoted_block=100,
        )
        service = protocol.seat_services[primary]
        recovery_at = service.prospective_recovery_at
        seat_market.sponsor_premium(20 * seat_market.seat_runway_seconds)
        insert_offer(
            seat_market,
            "bob",
            20,
            recovery_at - seat_market.quote_maturity_seconds - 1,
            400,
        )
        staged = protocol.stage_best(
            seat_market,
            settlement.Clock(403, recovery_at - 1),
        )
        self.assertEqual(staged.code, market.ResultCode.STAGED)
        stage = copy.deepcopy(protocol.settlement_seat_stage)
        commitment = protocol.seat_lineup_commitment()
        revision = protocol.seat_lineup_revision
        progress_clock = settlement.Clock(500, recovery_at)
        progress = settlement.candidate(
            protocol,
            progress_clock,
            "healthy-progress-during-stage",
            slot=service.prospective_target_tip,
        )
        protocol._commit(progress, progress_clock)
        self.assertEqual(protocol.seat_lineup_revision, revision)
        self.assertEqual(protocol.seat_lineup_commitment(), commitment)
        self.assertEqual(
            protocol.settlement_seat_stage.lineup_commitment,
            stage.lineup_commitment,
        )
        installed = protocol.apply_stage(
            seat_market,
            settlement.Clock(504, stage.handover_at),
        )
        self.assertEqual(protocol.seat_lineup_revision, revision + 1)
        self.assertNotEqual(protocol.seat_lineup_commitment(), commitment)
        self.assertEqual(
            protocol.active_primary_term_id,
            installed.tranche.installed_term_id,
        )

    def test_apply_accepts_handover_and_expiry_equalities_only(self):
        for offset, succeeds in ((-1, False), (0, True)):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.stage_best(
                seat_market, settlement.Clock(103, tip_time + 10)
            )
            stage = protocol.settlement_seat_stage
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            call_clock = settlement.Clock(104, stage.handover_at + offset)
            if succeeds:
                protocol.apply_stage(seat_market, call_clock)
                self.assertIsNone(protocol.settlement_seat_stage)
            else:
                with self.assertRaises(ValueError):
                    protocol.apply_stage(seat_market, call_clock)
                self.assertEqual(protocol, before[0])
                self.assertEqual(seat_market, before[1])

        for offset, succeeds in ((0, True), (1, False)):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.stage_best(
                seat_market, settlement.Clock(103, tip_time + 10)
            )
            stage = protocol.settlement_seat_stage
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            call_clock = settlement.Clock(104, stage.expires_at + offset)
            if succeeds:
                protocol.apply_stage(seat_market, call_clock)
            else:
                with self.assertRaises(ValueError):
                    protocol.apply_stage(seat_market, call_clock)
                self.assertEqual(protocol, before[0])
                self.assertEqual(seat_market, before[1])

    def test_final_term_id_binds_actual_apply_time_and_install_revision(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "alice", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = copy.deepcopy(protocol.settlement_seat_stage)
        base_revision = protocol.seat_lineup_revision
        early_protocol, late_protocol = copy.deepcopy(protocol), copy.deepcopy(protocol)
        early_market, late_market = copy.deepcopy(seat_market), copy.deepcopy(seat_market)
        early = early_protocol.apply_stage(
            early_market,
            settlement.Clock(104, stage.handover_at),
        )
        late = late_protocol.apply_stage(
            late_market,
            settlement.Clock(105, stage.expires_at),
        )
        early_term = early.tranche.installed_term_id
        late_term = late.tranche.installed_term_id
        self.assertNotEqual(early_term, late_term)
        self.assertEqual(
            early_protocol.seat_terms[early_term].installed_at,
            stage.handover_at,
        )
        self.assertEqual(
            late_protocol.seat_terms[late_term].installed_at,
            stage.expires_at,
        )
        self.assertEqual(
            late_protocol.seat_services[late_term].premium_funded_until
            - early_protocol.seat_services[early_term].premium_funded_until,
            stage.expires_at - stage.handover_at,
        )
        self.assertEqual(early_protocol.seat_lineup_revision, base_revision + 1)
        self.assertEqual(late_protocol.seat_lineup_revision, base_revision + 1)
        self.assertIn(early_term, early_market.accounting.live_reserves)
        self.assertIn(late_term, late_market.accounting.live_reserves)

        exact_inputs = (
            stage.authorization_id,
            stage.generation,
            stage.offer_id,
            stage.tranche_id,
            stage.handover_at,
            base_revision + 1,
        )
        self.assertEqual(
            early_term,
            early_protocol._seat_term_id(*exact_inputs),
        )
        substitutions = (
            (b"x" * 32, *exact_inputs[1:]),
            (exact_inputs[0], exact_inputs[1] + 1, *exact_inputs[2:]),
            (*exact_inputs[:2], b"y" * 32, *exact_inputs[3:]),
            (*exact_inputs[:3], b"z" * 32, *exact_inputs[4:]),
            (*exact_inputs[:4], exact_inputs[4] + 1, exact_inputs[5]),
            (*exact_inputs[:5], exact_inputs[5] + 1),
        )
        for substituted in substitutions:
            self.assertNotEqual(
                early_protocol._seat_term_id(*substituted), early_term
            )

    def test_ordinary_expiry_is_atomic_before_and_at_equality(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        row = insert_offer(seat_market, "a", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = protocol.settlement_seat_stage
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.expire_stage(
                seat_market,
                settlement.Clock(104, stage.expires_at - 1),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])
        protocol.expire_stage(
            seat_market, settlement.Clock(104, stage.expires_at)
        )
        self.assertIsNone(protocol.settlement_seat_stage)
        self.assertEqual(
            seat_market.offers[row.offer.offer_id].location,
            market.OfferLocation.PENDING,
        )
        self.assertEqual(seat_market.accounting.reserved_premium, 0)

    def test_canonical_tombstone_then_authenticated_async_restore(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        row = insert_offer(seat_market, "a", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = copy.deepcopy(protocol.settlement_seat_stage)
        market_staged = copy.deepcopy(seat_market)
        protocol._invalidate_local_stage("CANONICAL_TEST")
        self.assertIsNone(protocol.settlement_seat_stage)
        self.assertEqual(seat_market, market_staged)
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.reconcile_stage_invalidation(
                seat_market,
                stage.stage_id,
                b"x" * 32,
                settlement.Clock(104, tip_time + 11),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])
        protocol.reconcile_stage_invalidation(
            seat_market,
            stage.stage_id,
            stage.lineup_commitment,
            settlement.Clock(104, tip_time + 11),
        )
        self.assertTrue(protocol.stage_tombstones[stage.stage_id].reconciled)
        self.assertEqual(
            seat_market.offers[row.offer.offer_id].location,
            market.OfferLocation.PENDING,
        )

    def test_stage_and_apply_faults_restore_both_components_byte_exactly(self):
        for fault in (
            "after_candidate_selection",
            "after_reserve_debit",
            "after_offer_location_change",
            "after_tranche_usage_change",
        ):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            seat_market.fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                protocol.stage_best(
                    seat_market, settlement.Clock(103, tip_time + 10)
                )
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)
        for fault in ("after_market_stage", "after_stage_recording"):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.seat_fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                protocol.stage_best(
                    seat_market, settlement.Clock(103, tip_time + 10)
                )
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)

    def test_install_faults_restore_reserve_stage_and_lineup(self):
        for component, fault in (
            ("market", "after_reserve_rekey"),
            ("market", "after_stage_clear"),
            ("settlement", "after_market_install"),
            ("settlement", "after_term_install"),
            ("settlement", "after_settlement_stage_clear"),
        ):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.stage_best(
                seat_market, settlement.Clock(103, tip_time + 10)
            )
            stage = copy.deepcopy(protocol.settlement_seat_stage)
            if component == "market":
                seat_market.fault_point = fault
            else:
                protocol.seat_fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                protocol.apply_stage(
                    seat_market,
                    settlement.Clock(104, stage.handover_at),
                )
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)

    def test_expiry_and_invalidation_faults_restore_both_components(self):
        for component, fault in (
            ("market", "after_stage_clear"),
            ("settlement", "after_market_expiry"),
            ("settlement", "after_settlement_stage_clear"),
        ):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.stage_best(
                seat_market, settlement.Clock(103, tip_time + 10)
            )
            stage = copy.deepcopy(protocol.settlement_seat_stage)
            if component == "market":
                seat_market.fault_point = fault
            else:
                protocol.seat_fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                protocol.expire_stage(
                    seat_market,
                    settlement.Clock(104, stage.expires_at),
                )
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)

        for component, fault in (
            ("market", "after_stage_clear"),
            ("settlement", "after_market_invalidation"),
            ("settlement", "after_tombstone_reconciliation"),
        ):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            seat_market.sponsor_premium(seat_market.seat_runway_seconds)
            insert_offer(seat_market, "a", 1, tip_time, 100)
            protocol.stage_best(
                seat_market, settlement.Clock(103, tip_time + 10)
            )
            stage = copy.deepcopy(protocol.settlement_seat_stage)
            protocol._invalidate_local_stage("FAULT_TEST")
            if component == "market":
                seat_market.fault_point = fault
            else:
                protocol.seat_fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                protocol.reconcile_stage_invalidation(
                    seat_market,
                    stage.stage_id,
                    stage.lineup_commitment,
                    settlement.Clock(104, tip_time + 11),
                )
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)

    def test_stale_generation_lineup_and_stage_identity_roll_back_both(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "a", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = protocol.settlement_seat_stage
        for mutation in ("generation", "lineup", "identity"):
            bad_protocol = copy.deepcopy(protocol)
            bad_market = copy.deepcopy(seat_market)
            if mutation == "generation":
                bad_protocol.seat_generation += 1
            elif mutation == "lineup":
                bad_protocol.seat_services = copy.deepcopy(
                    bad_protocol.seat_services
                )
                # Empty lineup commitment still changes when generation moves;
                # add a retained synthetic standby for this stale snapshot.
                term = synthetic_term(9, tip_time)
                bad_protocol.seat_terms[term.term_id] = term
                bad_protocol.seat_services[term.term_id] = settlement.SeatService(
                    None, tip_time + 600, None, None
                )
                bad_protocol.seat_lineup.append(term.term_id)
            else:
                bad_protocol.settlement_seat_stage = replace(
                    bad_protocol.settlement_seat_stage,
                    stage_id=b"x" * 32,
                )
            before = (copy.deepcopy(bad_protocol), copy.deepcopy(bad_market))
            with self.assertRaises((ValueError, market.TransitionRejected)):
                bad_protocol.apply_stage(
                    bad_market,
                    settlement.Clock(104, stage.handover_at),
                )
            self.assertEqual(bad_protocol, before[0], mutation)
            self.assertEqual(bad_market, before[1], mutation)

    def test_outgoing_close_and_exit_faults_roll_back_both_components(self):
        for fault in (
            "after_outgoing_close",
            "after_exit_roster_removal",
            "after_exit_reserve_reconciliation",
        ):
            protocol, seat_market = make_pair()
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            row, primary = install_offer(
                protocol, seat_market, "a", 30,
                quoted_at=tip_time, quoted_block=100,
            )
            if fault == "after_outgoing_close":
                seat_market.sponsor_premium(
                    20 * seat_market.seat_runway_seconds
                )
                insert_offer(seat_market, "b", 20, tip_time + 20, 110)
                protocol.stage_best(
                    seat_market, settlement.Clock(113, tip_time + 30)
                )
                stage = protocol.settlement_seat_stage
                call = lambda: protocol.apply_stage(
                    seat_market,
                    settlement.Clock(114, stage.handover_at),
                )
            else:
                request_clock = settlement.Clock(110, tip_time + 20)
                protocol.request_installed_exit(
                    row.tranche.operator, primary, request_clock
                )
                deadline = protocol.installed_exit_at(primary)
                call = lambda: protocol.finalize_installed_exit(
                    seat_market,
                    primary,
                    settlement.Clock(111, deadline),
                )
            protocol.seat_fault_point = fault
            before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
            with self.assertRaises(RuntimeError):
                call()
            self.assertEqual(protocol, before[0], fault)
            self.assertEqual(seat_market, before[1], fault)


class ExitAndPremiumTests(unittest.TestCase):
    def primary_and_standby(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        primary_row, primary = install_offer(
            protocol, seat_market, "a", 10,
            quoted_at=tip_time, quoted_block=100,
        )
        standby_row, standby = install_offer(
            protocol, seat_market, "b", 20,
            quoted_at=tip_time + 20, quoted_block=110,
        )
        return (
            protocol, seat_market, primary_row, primary,
            standby_row, standby,
        )

    def no_duty_expiry_lineup(self, standby_count=1, runway=None):
        if runway is None:
            runway = (
                settlement.MIN_PRIMARY_TENURE_SECONDS
                + settlement.HANDOVER_EXECUTION_BUFFER_SECONDS
                + settlement.SLA_TAIL_SECONDS
            )
        protocol, seat_market = make_pair(runway=runway)
        # A full retained-history ring leaves the primary's prospective duty
        # unallocated.  At the minimum valid runway, service eligibility
        # arrives before the strict recovery boundary.
        RingAndReclamationTests.fill_history_ring(protocol)
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        rows = []
        terms = []
        for offset, operator in enumerate(("a", "b", "c", "d")[:standby_count + 1]):
            row, term_id = install_offer(
                protocol,
                seat_market,
                operator,
                2 + offset,
                quoted_at=tip_time + 20 * offset,
                quoted_block=100 + 10 * offset,
            )
            rows.append(row)
            terms.append(term_id)
        primary_service = protocol.seat_services[terms[0]]
        self.assertNotIn(terms[0], protocol.term_duty)
        self.assertIsNotNone(primary_service.prospective_recovery_at)
        self.assertIsNone(primary_service.ring_full_recovery_at)
        return protocol, seat_market, rows, terms

    def test_operator_only_one_shot_exit_and_primary_boundaries(self):
        protocol, seat_market, row, primary, _, standby = self.primary_and_standby()
        service = protocol.seat_services[primary]
        before = copy.deepcopy(protocol)
        with self.assertRaises(ValueError):
            protocol.request_installed_exit(
                addr("attacker"),
                primary,
                settlement.Clock(120, service.responsibility_start + 20),
            )
        self.assertEqual(protocol, before)
        requested = service.responsibility_start + 20
        deadline = protocol.request_installed_exit(
            row.tranche.operator,
            primary,
            settlement.Clock(120, requested),
        )
        first = protocol.seat_services[primary].exit_requested_at
        self.assertEqual(
            deadline,
            max(
                requested + settlement.EXIT_DELAY_SECONDS,
                service.minimum_tenure_until,
            ),
        )
        protocol.request_installed_exit(
            row.tranche.operator,
            primary,
            settlement.Clock(121, requested + 100),
        )
        self.assertEqual(protocol.seat_services[primary].exit_requested_at, first)
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.finalize_installed_exit(
                seat_market,
                primary,
                settlement.Clock(122, deadline - 1),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])
        protocol.finalize_installed_exit(
            seat_market, primary, settlement.Clock(123, deadline)
        )
        self.assertNotIn(primary, protocol.seat_lineup)
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertEqual(protocol.active_primary_term_id, standby)
        self.assertEqual(
            protocol.seat_services[standby].responsibility_start,
            deadline,
        )
        self.assertNotIn(primary, protocol.term_duty)
        self.assertEqual(
            protocol.seat_services[primary].term_removed_at,
            deadline,
        )
        self.assertEqual(
            seat_market.tranches[row.tranche.tranche_id].disposition,
            market.BondDisposition.NONE,
        )

    def test_delayed_healthy_expiry_retains_removal_time_for_release_horizon(self):
        protocol, seat_market = make_pair(runway=5_149)
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        row, primary = install_offer(
            protocol,
            seat_market,
            "a",
            2,
            quoted_at=tip_time,
            quoted_block=100,
        )
        service = protocol.seat_services[primary]
        expiry = service.service_eligible_until
        self.assertEqual(service.prospective_recovery_at, expiry)
        removed_at = expiry + 570
        self.assertTrue(
            protocol.sync(settlement.Clock(200, removed_at))
        )
        self.assertEqual(service.closed_at, expiry)
        self.assertEqual(service.term_removed_at, removed_at)
        view = protocol._market_service_view(seat_market, primary)
        self.assertEqual(view.last_liability_at, removed_at)

        protocol.reconcile_seat_reserve(
            seat_market,
            primary,
            settlement.Clock(201, removed_at),
        )
        protocol.request_bond_release(
            seat_market,
            row.tranche.tranche_id,
            primary,
            settlement.Clock(202, removed_at),
        )
        owner_at = (
            removed_at
            + seat_market.evidence_delay_seconds
            + seat_market.reorg_stability_seconds
        )
        before = copy.deepcopy(seat_market)
        with self.assertRaises(market.TransitionRejected):
            protocol.finalize_bond_release(
                seat_market,
                row.tranche.tranche_id,
                primary,
                settlement.Clock(203, owner_at - 1),
            )
        self.assertEqual(seat_market, before)
        protocol.finalize_bond_release(
            seat_market,
            row.tranche.tranche_id,
            primary,
            settlement.Clock(204, owner_at),
        )
        self.assertIs(
            seat_market.tranches[row.tranche.tranche_id].disposition,
            market.BondDisposition.OWNER_CREDITED,
        )

    def test_selected_successor_cannot_exit_or_accrue_until_cure(self):
        protocol, seat_market, row, primary, standby_row, standby = (
            self.primary_and_standby()
        )
        duty = activate_current_duty(protocol)
        protocol.sync(
            settlement.Clock(121, duty.failover_at + 1)
        )
        self.assertEqual(protocol.selected_successor_term_id, standby)
        market_before = copy.deepcopy(seat_market)
        with self.assertRaises(ValueError):
            protocol.request_installed_exit(
                standby_row.tranche.operator,
                standby,
                settlement.Clock(122, duty.failover_at + 2),
            )
        with self.assertRaises(ValueError):
            protocol.accrue_seat_premium(
                seat_market,
                standby,
                settlement.Clock(122, duty.failover_at + 2),
            )
        self.assertEqual(seat_market, market_before)
        canonical_cure(
            protocol, duty, at=duty.failover_at + 2, tip=duty.target_tip
        )
        self.assertEqual(protocol.active_primary_term_id, standby)
        self.assertIsNotNone(
            protocol.seat_services[standby].responsibility_start
        )

    def test_standby_exit_matures_independently_before_primary_failover(self):
        protocol, seat_market, _, primary, standby_row, standby = (
            self.primary_and_standby()
        )
        service = protocol.seat_services[standby]
        requested = service.minimum_tenure_until - 100
        deadline = protocol.request_installed_exit(
            standby_row.tranche.operator,
            standby,
            settlement.Clock(120, requested),
        )
        self.assertEqual(deadline, service.minimum_tenure_until)
        protocol.finalize_installed_exit(
            seat_market, standby, settlement.Clock(121, deadline)
        )
        self.assertEqual(protocol.seat_lineup, [primary])
        self.assertEqual(protocol.active_primary_term_id, primary)
        self.assertNotIn(standby, seat_market.accounting.live_reserves)

    def test_pre_requested_standby_recomputes_primary_tenure_after_promotion(self):
        protocol, _, _, primary, standby_row, standby = self.primary_and_standby()
        standby_service = protocol.seat_services[standby]
        request_at = standby_service.minimum_tenure_until - 200
        original_deadline = protocol.request_installed_exit(
            standby_row.tranche.operator,
            standby,
            settlement.Clock(120, request_at),
        )
        duty = activate_current_duty(protocol)
        canonical_cure(
            protocol, duty, at=duty.recovery_at + 2, tip=duty.target_tip
        )
        promoted = protocol.seat_services[standby]
        self.assertEqual(promoted.exit_requested_at, request_at)
        self.assertGreater(
            protocol.installed_exit_at(standby), original_deadline
        )
        self.assertEqual(
            protocol.installed_exit_at(standby),
            promoted.minimum_tenure_until,
        )

    def test_due_exit_finalization_returns_synced_before_any_market_write(self):
        protocol, seat_market, row, primary, _, _ = self.primary_and_standby()
        service = protocol.seat_services[primary]
        protocol.request_installed_exit(
            row.tranche.operator,
            primary,
            settlement.Clock(120, service.responsibility_start + 20),
        )
        recovery_at = service.prospective_recovery_at
        clock = settlement.Clock(200, recovery_at + 1)
        market_before = copy.deepcopy(seat_market)
        self.assertEqual(
            protocol.finalize_installed_exit(seat_market, primary, clock),
            "SYNCED",
        )
        self.assertEqual(seat_market, market_before)
        self.assertIn(primary, protocol.seat_lineup)
        self.assertIn(primary, protocol.term_duty)

    def test_removed_primary_duty_can_fail_and_slash_without_reclosing_service(self):
        protocol, seat_market, row, primary, _, standby = self.primary_and_standby()
        service = protocol.seat_services[primary]
        duty = activate_current_duty(protocol)
        protocol.request_installed_exit(
            row.tranche.operator,
            primary,
            settlement.Clock(130, duty.recovery_at + 2),
        )
        exit_at = protocol.installed_exit_at(primary)
        protocol.finalize_installed_exit(
            seat_market, primary, settlement.Clock(131, exit_at)
        )
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertEqual(protocol.active_primary_term_id, standby)
        self.assertEqual(protocol.seat_services[primary].closed_at, exit_at)
        self.assertTrue(
            protocol.sync(settlement.Clock(132, duty.failover_at + 1))
        )
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.FAILED_OVER,
        )
        self.assertEqual(protocol.seat_services[primary].closed_at, exit_at)
        self.assertEqual(
            protocol.seat_services[primary].close_reason, "VOLUNTARY_EXIT"
        )
        self.assertTrue(
            protocol.sync(settlement.Clock(133, duty.slash_at + 1))
        )
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.BREACHED,
        )
        self.assertEqual(protocol.seat_services[primary].closed_at, exit_at)

    def test_omitted_sync_preview_and_accrual_cannot_raise_cap(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol, seat_market, "a", 2,
            quoted_at=tip_time, quoted_block=100,
        )
        service = protocol.seat_services[primary]
        failover_at = service.prospective_failover_at
        self.assertNotIn(primary, protocol.term_duty)
        self.assertEqual(protocol.preview_premium_cap(primary), failover_at)
        self.assertGreater(
            failover_at,
            protocol.seat_services[primary].service_eligible_until,
        )
        omitted = copy.deepcopy(protocol)
        omitted_market = copy.deepcopy(seat_market)
        synced = copy.deepcopy(protocol)
        synced_market = copy.deepcopy(seat_market)
        clock = settlement.Clock(200, failover_at + 1)
        self.assertEqual(
            omitted.accrue_seat_premium(omitted_market, primary, clock),
            "SYNCED",
        )
        self.assertEqual(omitted_market, seat_market)
        self.assertTrue(synced.sync(clock))
        self.assertEqual(
            omitted.preview_premium_cap(primary),
            synced.preview_premium_cap(primary),
        )
        self.assertEqual(
            omitted.preview_premium_cap(primary), failover_at
        )

    def test_no_duty_funding_expiry_selects_then_commit_promotes_without_backpay(self):
        protocol, seat_market, _, terms = self.no_duty_expiry_lineup(3)
        protocol.duty_ring[0].reusable = True
        primary, successor, *tail = terms
        service = protocol.seat_services[primary]
        expiry = service.service_eligible_until
        self.assertEqual(protocol.preview_premium_cap(primary), expiry)

        before = copy.deepcopy(protocol)
        self.assertFalse(
            before.sync(settlement.Clock(200, expiry - 1))
        )
        self.assertEqual(before.seat_lineup, terms)

        omitted = copy.deepcopy(protocol)
        omitted_market = copy.deepcopy(seat_market)
        synced = copy.deepcopy(protocol)
        synced_market = copy.deepcopy(seat_market)
        expiry_clock = settlement.Clock(201, expiry)
        self.assertEqual(
            omitted.accrue_seat_premium(
                omitted_market, primary, expiry_clock
            ),
            "SYNCED",
        )
        self.assertEqual(omitted_market, seat_market)
        self.assertTrue(synced.sync(expiry_clock))
        self.assertEqual(omitted, synced)
        self.assertEqual(synced_market, seat_market)

        self.assertEqual(
            synced.seat_services[primary].closed_at, expiry
        )
        self.assertIsNone(synced.active_primary_term_id)
        self.assertEqual(synced.selected_successor_term_id, successor)
        self.assertEqual(synced.seat_lineup, [successor, *tail])
        promoted = synced.seat_services[successor]
        self.assertIsNone(promoted.responsibility_start)
        reserve = synced_market.accounting.live_reserves[successor]
        self.assertIs(reserve.lifecycle, market.ReserveLifecycle.UNSTARTED)

        target_tip = synced.seat_selection.target_tip
        promote_clock = settlement.Clock(
            202,
            max(expiry + 1, settlement.GENESIS_TIMESTAMP + target_tip),
        )
        qualifying = settlement.candidate(
            synced, promote_clock, "healthy-expiry-cure", slot=target_tip
        )
        synced._commit(qualifying, promote_clock)
        promoted = synced.seat_services[successor]
        self.assertEqual(promoted.responsibility_start, promote_clock.timestamp)
        self.assertEqual(
            promoted.premium_funded_until,
            promote_clock.timestamp + synced.seat_runway_seconds,
        )
        self.assertNotIn(successor, synced.term_duty)
        self.assertGreater(
            promoted.prospective_recovery_at, promote_clock.timestamp
        )

        accrue_clock = settlement.Clock(
            203,
            promote_clock.timestamp
                + seat_market.premium_claim_delay_seconds
                + 5,
        )
        accrued = synced.accrue_seat_premium(
            synced_market, successor, accrue_clock
        )
        self.assertEqual(
            accrued.amount,
            synced.seat_terms[successor].ask * 5,
        )
        self.assertIs(
            synced_market.accounting.live_reserves[successor].lifecycle,
            market.ReserveLifecycle.OPEN,
        )

        late = copy.deepcopy(protocol)
        late_clock = settlement.Clock(204, expiry + 17)
        self.assertTrue(late.sync(late_clock))
        self.assertIsNone(late.seat_services[successor].responsibility_start)
        self.assertEqual(late.selected_successor_term_id, successor)
        self.assertEqual(late.seat_services[primary].closed_at, expiry)

    def test_healthy_expiry_ordering_never_frames_selected_successor(self):
        protocol, _, _, terms = self.no_duty_expiry_lineup(1)
        primary, successor = terms
        service = protocol.seat_services[primary]
        expiry = service.service_eligible_until
        recovery = service.prospective_recovery_at
        slash = recovery + (
            settlement.DELTA_SLASH_LAG
            - settlement.DELTA_RECOVERY_LAG
        )
        self.assertLess(expiry, recovery)
        for index, timestamp in enumerate(
            (expiry, recovery, recovery + 1, slash + 1), 300
        ):
            clone = copy.deepcopy(protocol)
            self.assertTrue(clone.sync(settlement.Clock(index, timestamp)))
            self.assertEqual(clone.seat_services[primary].closed_at, expiry)
            self.assertEqual(clone.selected_successor_term_id, successor)
            self.assertIsNone(
                clone.seat_services[successor].responsibility_start
            )
            self.assertNotIn(successor, clone.term_duty)

        gmax_equal = copy.deepcopy(protocol)
        gmax_at = (
            settlement.GENESIS_TIMESTAMP
            + protocol.core.tip_slot
            + settlement.G_MAX
        )
        self.assertTrue(gmax_equal.sync(settlement.Clock(400, gmax_at)))
        self.assertIs(gmax_equal.mode, settlement.Mode.NORMAL)
        self.assertEqual(gmax_equal.selected_successor_term_id, successor)
        self.assertTrue(
            gmax_equal.sync(settlement.Clock(401, gmax_at + 1))
        )
        self.assertIs(gmax_equal.mode, settlement.Mode.RECOVERY)
        self.assertIsNone(
            gmax_equal.seat_services[successor].responsibility_start
        )

    def test_objective_duty_strictly_precedes_cutoff_but_equality_is_healthy(self):
        # Direct installation starts 15 seconds after the immutable old tip in
        # this fixture, so these runways place recovery at E-1, E, and E+1.
        for runway, relation in ((5_150, "DUTY"), (5_149, "EQUAL"), (5_148, "HEALTHY")):
            protocol, seat_market, _, terms = self.no_duty_expiry_lineup(
                1, runway=runway
            )
            primary, successor = terms
            service = protocol.seat_services[primary]
            recovery = service.prospective_recovery_at
            expiry = service.service_eligible_until
            protocol.duty_ring[0].reusable = True
            market_before = copy.deepcopy(seat_market)
            before_cap = protocol.preview_premium_cap(primary)
            clock = settlement.Clock(500 + runway, max(recovery, expiry) + 1)
            self.assertTrue(protocol.sync(clock))
            self.assertEqual(seat_market, market_before)
            if relation == "DUTY":
                self.assertEqual(recovery, expiry - 1)
                duty = protocol.seat_duties[protocol.term_duty[primary]]
                self.assertEqual(before_cap, duty.failover_at)
                self.assertEqual(protocol.preview_premium_cap(primary), duty.failover_at)
                self.assertEqual(protocol.active_primary_term_id, primary)
                self.assertIsNone(protocol.selected_successor_term_id)
            else:
                self.assertEqual(
                    recovery,
                    expiry if relation == "EQUAL" else expiry + 1,
                )
                self.assertEqual(before_cap, expiry)
                self.assertEqual(protocol.preview_premium_cap(primary), expiry)
                self.assertEqual(protocol.seat_services[primary].closed_at, expiry)
                self.assertEqual(protocol.selected_successor_term_id, successor)
                self.assertIs(
                    protocol.seat_selection.source,
                    settlement.SelectionSource.HEALTHY_EXPIRY,
                )
                self.assertIsNone(protocol.seat_selection.predecessor_duty_id)
                self.assertNotIn(primary, protocol.term_duty)

    def test_omitted_healthy_expiry_and_market_reconciliation_are_identical(self):
        protocol, seat_market, _, terms = self.no_duty_expiry_lineup(
            1, runway=5_149
        )
        primary = terms[0]
        expiry = protocol.seat_services[primary].service_eligible_until
        omitted = copy.deepcopy(protocol)
        omitted_market = copy.deepcopy(seat_market)
        synced = copy.deepcopy(protocol)
        synced_market = copy.deepcopy(seat_market)
        sync_clock = settlement.Clock(600, expiry)
        self.assertEqual(
            omitted.reconcile_seat_reserve(
                omitted_market, primary, sync_clock
            ),
            "SYNCED",
        )
        self.assertEqual(omitted_market, seat_market)
        self.assertTrue(synced.sync(sync_clock))
        self.assertEqual(omitted, synced)
        reconcile_clock = settlement.Clock(
            601, expiry + seat_market.premium_claim_delay_seconds
        )
        omitted_result = omitted.reconcile_seat_reserve(
            omitted_market, primary, reconcile_clock
        )
        synced_result = synced.reconcile_seat_reserve(
            synced_market, primary, reconcile_clock
        )
        self.assertEqual(omitted_result, synced_result)
        self.assertEqual(omitted, synced)
        self.assertEqual(omitted_market, synced_market)

    def test_selected_commit_or_revision_starts_once_and_unusable_vacates(self):
        protocol, _, _, terms = self.no_duty_expiry_lineup(1)
        primary, successor = terms
        expiry = protocol.seat_services[primary].service_eligible_until
        self.assertTrue(protocol.sync(settlement.Clock(700, expiry)))
        selection = protocol.seat_selection
        protocol.duty_ring[0].reusable = True
        promote_clock = settlement.Clock(
            701,
            max(expiry + 1, settlement.GENESIS_TIMESTAMP + selection.target_tip),
        )
        protocol._commit(
            settlement.candidate(
                protocol,
                promote_clock,
                "selection-race",
                slot=selection.target_tip,
            ),
            promote_clock,
        )
        duty_sequence = protocol.duty_sequence
        self.assertEqual(protocol.active_primary_term_id, successor)
        self.assertIsNone(protocol.seat_selection)
        self.assertFalse(protocol._promote_selected(promote_clock.timestamp + 1))
        self.assertEqual(protocol.duty_sequence, duty_sequence)

        late, _, _, late_terms = self.no_duty_expiry_lineup(1)
        late_primary, late_successor = late_terms
        late_expiry = late.seat_services[late_primary].service_eligible_until
        self.assertTrue(late.sync(settlement.Clock(710, late_expiry)))
        gmax = settlement.GENESIS_TIMESTAMP + late.core.tip_slot + settlement.G_MAX
        self.assertTrue(late.sync(settlement.Clock(711, gmax + 1)))
        self.assertIs(late.mode, settlement.Mode.RECOVERY)
        late.seat_runway_seconds -= 1
        self.assertTrue(
            late.sync(settlement.Clock(712, late.recovery.expires_at + 1))
        )
        self.assertEqual(late.seat_lineup, [])
        self.assertIsNone(late.seat_selection)
        self.assertEqual(
            late.seat_services[late_successor].close_reason,
            "PROMOTION_REVISION_UNUSABLE",
        )

    def test_unusable_recovery_revision_never_starts_selected_successor(self):
        mutations = (
            ("canonical_state_witness_available", False),
            ("canonical_code_preimages_available", False),
            ("seat_profile_ready", False),
            ("seat_configuration_ready", False),
            (
                "seat_runway_seconds",
                settlement.MIN_PRIMARY_TENURE_SECONDS
                    + settlement.HANDOVER_EXECUTION_BUFFER_SECONDS
                    + settlement.SLA_TAIL_SECONDS
                    - 1,
            ),
            ("seat_runway_seconds", settlement.SEAT_UINT256_MAX),
        )
        for index, (attribute, value) in enumerate(mutations):
            with self.subTest(attribute=attribute, value=value):
                protocol, _, _, terms = self.no_duty_expiry_lineup(1)
                primary, successor = terms
                expiry = protocol.seat_services[primary].service_eligible_until
                self.assertTrue(
                    protocol.sync(settlement.Clock(800 + index * 3, expiry))
                )
                gmax = (
                    settlement.GENESIS_TIMESTAMP
                    + protocol.core.tip_slot
                    + settlement.G_MAX
                )
                self.assertTrue(
                    protocol.sync(
                        settlement.Clock(801 + index * 3, gmax + 1)
                    )
                )
                self.assertIs(protocol.mode, settlement.Mode.RECOVERY)
                setattr(protocol, attribute, value)
                self.assertTrue(
                    protocol.sync(
                        settlement.Clock(
                            802 + index * 3,
                            protocol.recovery.expires_at + 1,
                        )
                    )
                )
                self.assertEqual(protocol.seat_lineup, [])
                self.assertIsNone(protocol.selected_successor_term_id)
                self.assertIsNone(
                    protocol.seat_services[successor].responsibility_start
                )
                self.assertEqual(
                    protocol.seat_services[successor].close_reason,
                    "PROMOTION_REVISION_UNUSABLE",
                )

    def test_unusable_qualifying_commit_vacates_instead_of_starting_successor(self):
        protocol, _, _, terms = self.no_duty_expiry_lineup(1)
        primary, successor = terms
        expiry = protocol.seat_services[primary].service_eligible_until
        self.assertTrue(protocol.sync(settlement.Clock(900, expiry)))
        selection = protocol.seat_selection
        protocol.canonical_state_witness_available = False
        commit_clock = settlement.Clock(
            901,
            max(expiry + 1, settlement.GENESIS_TIMESTAMP + selection.target_tip),
        )
        protocol._commit(
            settlement.candidate(
                protocol,
                commit_clock,
                "unusable-selected-commit",
                slot=selection.target_tip,
            ),
            commit_clock,
        )
        self.assertEqual(protocol.seat_lineup, [])
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertIsNone(protocol.seat_services[successor].responsibility_start)
        self.assertEqual(
            protocol.seat_services[successor].close_reason,
            "PROMOTION_REVISION_UNUSABLE",
        )

    def test_no_duty_funding_expiry_without_standby_leaves_vacancy(self):
        protocol, seat_market, _, terms = self.no_duty_expiry_lineup(0)
        primary = terms[0]
        expiry = protocol.seat_services[primary].service_eligible_until
        market_before = copy.deepcopy(seat_market)
        self.assertTrue(protocol.sync(settlement.Clock(200, expiry)))
        self.assertEqual(protocol.seat_lineup, [])
        self.assertIsNone(protocol.active_primary_term_id)
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertEqual(protocol.preview_premium_cap(primary), expiry)
        self.assertEqual(seat_market, market_before)

    def test_satisfaction_is_the_earlier_permanent_cap(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, primary = install_offer(
            protocol, seat_market, "a", 2,
            quoted_at=tip_time, quoted_block=100,
        )
        duty = activate_current_duty(protocol)
        canonical_cure(
            protocol, duty, at=duty.recovery_at + 2, tip=duty.target_tip
        )
        self.assertEqual(
            protocol.preview_premium_cap(primary), duty.recovery_at + 2
        )


class RingAndReclamationTests(unittest.TestCase):
    @staticmethod
    def fill_history_ring(protocol):
        duties = []
        installed_at = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        for index in range(1, 5):
            term = synthetic_term(index, installed_at)
            protocol.seat_terms[term.term_id] = term
            protocol.seat_services[term.term_id] = settlement.SeatService(
                installed_at,
                installed_at + settlement.MIN_PRIMARY_TENURE_SECONDS,
                installed_at + settlement.SEAT_RUNWAY_SECONDS,
                installed_at + settlement.SEAT_RUNWAY_SECONDS
                    - settlement.SLA_TAIL_SECONDS,
                closed_at=installed_at + index,
                close_reason="SATISFIED",
                term_removed_at=installed_at + index,
            )
            protocol._set_prospective_duty(
                term.term_id,
                protocol.core.tip_slot,
                protocol.core.l2_block_number,
            )
            attachment = protocol._attach_duty(
                term.term_id,
                protocol.core.tip_slot,
                protocol.core.l2_block_number,
            )
            if attachment.duty is None:
                raise AssertionError("history fixture failed to attach duty")
            duty = attachment.duty
            duty.status = settlement.DutyStatus.SATISFIED
            duty.satisfied_at = installed_at + index
            duty.disposition_at = installed_at + index
            duties.append(duty)
        protocol._assert_seat_valid()
        return duties

    def test_ring_full_caps_at_recovery_and_vacates_entire_lineup_fail_open(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        self.fill_history_ring(protocol)
        installed_at = settlement.GENESIS_TIMESTAMP + 1_010
        primary = synthetic_term(9, installed_at)
        protocol.install_seat_term_for_test(
            primary, rank=0, start_primary=True
        )
        standbys = []
        for index in (10, 11, 12):
            term = synthetic_term(index, installed_at)
            protocol.install_seat_term_for_test(
                term, rank=len(protocol.seat_lineup), start_primary=False
            )
            standbys.append(term)
        service = protocol.seat_services[primary.term_id]
        self.assertNotIn(primary.term_id, protocol.term_duty)
        self.assertEqual(
            protocol.preview_premium_cap(primary.term_id),
            service.prospective_recovery_at,
        )
        self.assertFalse(
            protocol.sync(
                settlement.Clock(1_100, service.prospective_recovery_at)
            )
        )
        self.assertEqual(
            protocol.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )
        self.assertTrue(
            protocol.sync(
                settlement.Clock(1_101, service.prospective_recovery_at + 1)
            )
        )
        self.assertEqual(protocol.seat_lineup, [])
        for term_id in (primary.term_id, *(term.term_id for term in standbys)):
            self.assertEqual(
                protocol.seat_services[term_id].closed_at,
                service.prospective_recovery_at,
            )
        self.assertIs(protocol.mode, settlement.Mode.RECOVERY)
        self.assertEqual(protocol.recovery.causes, settlement.Cause.SLA)

    def test_duty_sequence_saturation_is_fail_open_at_objective_recovery(self):
        allocating = settlement.protocol(tip_slot=1_000, seat=False)
        first = synthetic_term(9, settlement.GENESIS_TIMESTAMP + 1_000)
        allocating.install_seat_term_for_test(
            first, rank=0, start_primary=True
        )
        allocating.duty_sequence = settlement.UINT64_MAX - 1
        first_service = allocating.seat_services[first.term_id]
        self.assertTrue(
            allocating.sync(
                settlement.Clock(1_100, first_service.prospective_recovery_at + 1)
            )
        )
        first_duty = allocating.seat_duties[
            allocating.term_duty[first.term_id]
        ]
        self.assertEqual(first_duty.sequence, settlement.UINT64_MAX)

        exhausted = settlement.protocol(tip_slot=1_000, seat=False)
        second = synthetic_term(10, settlement.GENESIS_TIMESTAMP + 1_000)
        exhausted.install_seat_term_for_test(
            second, rank=0, start_primary=True
        )
        exhausted.duty_sequence = settlement.UINT64_MAX
        second_service = exhausted.seat_services[second.term_id]
        recovery_at = second_service.prospective_recovery_at
        sync_at = recovery_at + 1
        self.assertEqual(
            exhausted.preview_premium_cap(second.term_id), recovery_at
        )
        self.assertTrue(
            exhausted.sync(settlement.Clock(1_101, sync_at))
        )
        self.assertEqual(
            exhausted.seat_scan_count, settlement.DUTY_RING_CAPACITY
        )
        self.assertNotIn(second.term_id, exhausted.term_duty)
        self.assertEqual(exhausted.seat_lineup, [])
        self.assertEqual(second_service.closed_at, recovery_at)
        self.assertEqual(second_service.term_removed_at, sync_at)
        self.assertIs(exhausted.mode, settlement.Mode.RECOVERY)
        self.assertEqual(exhausted.recovery.causes, settlement.Cause.SLA)

    def test_late_reclaim_cannot_retroactively_avert_ring_full_vacancy(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        duties = self.fill_history_ring(protocol)
        primary = synthetic_term(9, settlement.GENESIS_TIMESTAMP + 1_010)
        protocol.install_seat_term_for_test(
            primary, rank=0, start_primary=True
        )
        cap_before = protocol.preview_premium_cap(primary.term_id)
        BombMarket.calls = 0
        result = protocol.reclaim_duty_cell(
            BombMarket(),
            duties[0].duty_id,
            duties[0].term_id,
            duties[0].tranche_id,
            settlement.Clock(1_100, cap_before + 1),
        )
        self.assertEqual(result, "SYNCED")
        self.assertEqual(BombMarket.calls, 0)
        self.assertEqual(protocol.preview_premium_cap(primary.term_id), cap_before)
        self.assertNotIn(primary.term_id, protocol.seat_lineup)
        self.assertFalse(protocol.duty_ring[duties[0].ring_index].reusable)

    def test_infeasible_failover_successor_vacates_full_lineup(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        protocol.sync(settlement.Clock(1_100, duty.failover_at + 1))
        protocol.seat_runway_seconds = (
            protocol.minimum_primary_tenure_seconds
            + settlement.HANDOVER_EXECUTION_BUFFER_SECONDS
            + settlement.SLA_TAIL_SECONDS
            - 1
        )
        canonical_cure(
            protocol,
            protocol.seat_duties[duty.duty_id],
            at=duty.failover_at + 2,
            tip=duty.target_tip + 1,
        )
        self.assertEqual(protocol.seat_lineup, [])
        self.assertIsNone(protocol.selected_successor_term_id)
        self.assertEqual(
            protocol.seat_services[standby.term_id].close_reason,
            "PROMOTION_REVISION_UNUSABLE",
        )

    def test_next_usable_recovery_revision_can_start_selected_successor(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        protocol.sync(settlement.Clock(1_100, duty.failover_at + 1))
        self.assertEqual(protocol.selected_successor_term_id, standby.term_id)
        expiry = protocol.recovery.expires_at
        self.assertTrue(protocol.sync(settlement.Clock(1_101, expiry + 1)))
        self.assertEqual(protocol.active_primary_term_id, standby.term_id)
        self.assertIsNone(protocol.selected_successor_term_id)

    def test_four_uncooperative_operators_cannot_pin_release_or_ring_reuse(self):
        protocol, seat_market = make_pair()
        rows = []
        duties = []
        for index in range(4):
            tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
            row, term_id = install_offer(
                protocol,
                seat_market,
                chr(ord("a") + index),
                index + 1,
                quoted_at=tip_time,
                quoted_block=100 + index * 20,
            )
            duty = activate_current_duty(protocol, open_recovery=False)
            canonical_cure(
                protocol,
                duty,
                at=duty.recovery_at + 2,
                tip=duty.target_tip,
            )
            rows.append((row, term_id))
            duties.append(duty)
        self.assertTrue(all(not cell.reusable for cell in protocol.duty_ring))
        self.assertEqual(protocol.seat_lineup, [])

        request_at = max(duty.slash_at for duty in duties) + 100
        request_clock = settlement.Clock(1_000, request_at)
        first = protocol.request_bond_release(
            seat_market,
            rows[0][0].tranche.tranche_id,
            rows[0][1],
            request_clock,
        )
        self.assertEqual(first, "SYNCED")
        for row, term_id in rows:
            result = protocol.request_bond_release(
                seat_market,
                row.tranche.tranche_id,
                term_id,
                request_clock,
            )
            self.assertNotEqual(result, "SYNCED")

        premature = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.reclaim_duty_cell(
                seat_market,
                duties[0].duty_id,
                duties[0].term_id,
                duties[0].tranche_id,
                request_clock,
            )
        self.assertEqual(protocol, premature[0])
        self.assertEqual(seat_market, premature[1])

        finalize_clock = settlement.Clock(1_001, request_at + 100)
        credit_ids = []
        for row, term_id in rows:
            result = protocol.finalize_bond_release(
                seat_market,
                row.tranche.tranche_id,
                term_id,
                finalize_clock,
            )
            credit_ids.append(result.credit_id)
        self.assertTrue(
            all(not seat_market.credits[credit_id].claimed
                for credit_id in credit_ids)
        )

        before_wrong = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises(ValueError):
            protocol.reclaim_duty_cell(
                seat_market,
                duties[0].duty_id,
                duties[0].term_id,
                duties[1].tranche_id,
                finalize_clock,
            )
        self.assertEqual(protocol, before_wrong[0])
        self.assertEqual(seat_market, before_wrong[1])

        for duty in duties:
            self.assertTrue(
                protocol.reclaim_duty_cell(
                    seat_market,
                    duty.duty_id,
                    duty.term_id,
                    duty.tranche_id,
                    finalize_clock,
                )
            )
        self.assertTrue(all(cell.reusable for cell in protocol.duty_ring))
        self.assertTrue(
            all(not seat_market.credits[credit_id].claimed
                for credit_id in credit_ids)
        )
        with self.assertRaises(ValueError):
            protocol.reclaim_duty_cell(
                seat_market,
                duties[0].duty_id,
                duties[0].term_id,
                duties[0].tranche_id,
                finalize_clock,
            )

        # Model the unrelated canonical progress that returned the core from
        # recovery before the next optional seat admission.
        protocol.core.tip_slot = (
            finalize_clock.timestamp - settlement.GENESIS_TIMESTAMP
        )
        protocol.core.l2_block_number += 1
        protocol.mode = settlement.Mode.NORMAL
        protocol.recovery = None
        fifth = synthetic_term(9, finalize_clock.timestamp + 1)
        protocol.install_seat_term_for_test(fifth, rank=0, start_primary=True)
        fifth_duty = activate_current_duty(protocol, open_recovery=False)
        self.assertEqual(fifth_duty.ring_index, duties[0].ring_index)
        self.assertGreater(fifth_duty.sequence, duties[0].sequence)
        with self.assertRaises(ValueError):
            protocol.reclaim_duty_cell(
                seat_market,
                duties[0].duty_id,
                duties[0].term_id,
                duties[0].tranche_id,
                settlement.Clock(1_002, fifth.installed_at),
            )

    def test_release_and_reclaim_are_caller_independent(self):
        for name in (
            "request_bond_release",
            "finalize_bond_release",
            "reclaim_duty_cell",
        ):
            self.assertNotIn(
                "caller", inspect.signature(getattr(settlement.Protocol, name)).parameters
            )


class BoundaryAndAuthorityTests(unittest.TestCase):
    def test_no_duty_and_closed_caps_choose_the_earliest_local_bound(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.seat_terms[term.term_id] = term
        protocol.seat_services[term.term_id] = settlement.SeatService(
            responsibility_start=term.installed_at,
            minimum_tenure_until=term.installed_at + 1_000,
            premium_funded_until=term.installed_at + 6_000,
            service_eligible_until=term.installed_at + 2_036,
        )
        self.assertEqual(
            protocol.preview_premium_cap(term.term_id),
            term.installed_at + 2_036,
        )
        protocol.seat_services[term.term_id].closed_at = term.installed_at + 100
        protocol.seat_services[term.term_id].close_reason = "MIGRATION"
        self.assertEqual(
            protocol.preview_premium_cap(term.term_id),
            term.installed_at + 100,
        )

    def test_migration_excuses_unresolved_duties_and_ignores_tenure(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        close_at = primary.installed_at + 1
        self.assertLess(
            close_at,
            protocol.seat_services[primary.term_id].minimum_tenure_until,
        )
        protocol.close_seats_for_migration(close_at)
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.EXCUSED_MIGRATION,
        )
        self.assertEqual(protocol.seat_lineup, [])
        self.assertEqual(protocol.seat_scan_count, 4)

    def test_migration_excuses_failover_selection_and_clears_record(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        protocol.sync(settlement.Clock(900, duty.failover_at + 1))
        self.assertIs(
            protocol.seat_selection.source,
            settlement.SelectionSource.DUTY_FAILOVER,
        )
        self.assertEqual(
            protocol.seat_selection.predecessor_duty_id, duty.duty_id
        )
        protocol.close_seats_for_migration(duty.failover_at + 2)
        self.assertIsNone(protocol.seat_selection)
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.EXCUSED_MIGRATION,
        )

    def test_selection_record_commitment_and_term_replay_are_fail_closed(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        protocol.sync(settlement.Clock(910, duty.failover_at + 1))
        selection = protocol.seat_selection
        self.assertEqual(
            protocol.seat_selections[selection.selection_id], selection
        )
        self.assertEqual(
            protocol.term_selection[standby.term_id], selection.selection_id
        )
        substitutions = (
            replace(selection, term_id=primary.term_id),
            replace(selection, tranche_id=b"x" * 32),
            replace(selection, offer_id=b"y" * 32),
            replace(
                selection,
                selected_canonical_sequence=
                    selection.selected_canonical_sequence + 1,
            ),
            replace(selection, selected_at=selection.selected_at + 1),
            replace(selection, target_tip=selection.target_tip + 1),
            replace(
                selection, source=settlement.SelectionSource.HEALTHY_EXPIRY
            ),
            replace(selection, predecessor_duty_id=None),
        )
        for forged in substitutions:
            clone = copy.deepcopy(protocol)
            clone.seat_selection = forged
            clone.seat_selections[selection.selection_id] = forged
            with self.assertRaises(AssertionError):
                clone._assert_seat_valid()

        replay = copy.deepcopy(protocol)
        replay._clear_selected_successor()
        replay._select_successor(
            selected_at=selection.selected_at + 1,
            source=settlement.SelectionSource.DUTY_FAILOVER,
            trigger_duty_id=duty.duty_id,
            target_tip=duty.target_tip,
        )
        self.assertEqual(replay.seat_lineup, [])
        self.assertIsNone(replay.seat_selection)
        self.assertEqual(replay.seat_selections, protocol.seat_selections)
        self.assertEqual(replay.term_selection, protocol.term_selection)
        self.assertEqual(
            replay.seat_services[standby.term_id].close_reason,
            "SELECTION_REPLAY",
        )
        replay._assert_seat_valid()

    def test_duplicate_term_tranche_and_second_duty_are_rejected(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        with self.assertRaises(ValueError):
            protocol.install_seat_term_for_test(
                replace(term, term_id=b"x" * 32),
                rank=1,
                start_primary=False,
            )
        protocol._attach_duty(term.term_id)
        with self.assertRaises(AssertionError):
            protocol._attach_duty(
                term.term_id,
                protocol.core.tip_slot,
                protocol.core.l2_block_number,
            )

    def test_checked_exit_overflow_rejects_without_recording_request(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=False)
        protocol.exit_delay_seconds = settlement.SEAT_UINT256_MAX
        before = copy.deepcopy(protocol)
        with self.assertRaises(ValueError):
            protocol.request_installed_exit(
                term.operator,
                term.term_id,
                settlement.Clock(1_100, settlement.GENESIS_TIMESTAMP + 1_000),
            )
        self.assertEqual(protocol, before)

    def test_checked_service_start_overflow_rolls_back_composed_install(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "a", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = protocol.settlement_seat_stage
        # Keep the mandatory leading sync quiescent while forcing checked
        # service-start arithmetic past uint256.  These fields are immutable
        # production parameters; mutation is a focused model fault fixture.
        protocol.minimum_primary_tenure_seconds = (
            settlement.SEAT_UINT256_MAX - 5_000
        )
        protocol.seat_runway_seconds = settlement.SEAT_UINT256_MAX
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        with self.assertRaises((ValueError, market.ArithmeticFault)):
            protocol.apply_stage(
                seat_market,
                settlement.Clock(104, stage.handover_at),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])

    def test_forged_dynamic_view_cannot_enter_the_composed_facade(self):
        protocol, seat_market = make_pair()
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        forged = object()
        with self.assertRaises(TypeError):
            protocol.accrue_seat_premium(
                seat_market,
                b"x" * 32,
                forged,
                settlement.Clock(100, settlement.GENESIS_TIMESTAMP + 1_000),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(seat_market, before[1])

    def test_market_binding_rejects_runway_and_target_substitution(self):
        protocol, seat_market = make_pair()
        bad_runway = copy.deepcopy(seat_market)
        object.__setattr__(
            bad_runway,
            "_seat_runway_seconds",
            seat_market.seat_runway_seconds + 1,
        )
        with self.assertRaises(ValueError):
            protocol.bind_seat_market_for_test(bad_runway)
        _, bad_market_target = make_pair(market_label="different-market")
        with self.assertRaises(ValueError):
            protocol.bind_seat_market_for_test(bad_market_target)
        before = (copy.deepcopy(protocol), copy.deepcopy(bad_market_target))
        with self.assertRaises(ValueError):
            protocol.stage_best(
                bad_market_target,
                settlement.Clock(
                    100, settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
                ),
            )
        self.assertEqual(protocol, before[0])
        self.assertEqual(bad_market_target, before[1])
        wrong_protocol = settlement.protocol(
            tip_slot=1_000,
            seat=False,
            settlement_address=addr("other"),
        )
        with self.assertRaises(ValueError):
            wrong_protocol.bind_seat_market_for_test(seat_market)


if __name__ == "__main__":
    unittest.main(verbosity=2)
