#!/usr/bin/env python3
"""Adversarial tests for canonical seat duties and composed Market calls."""

from __future__ import annotations

import importlib.util
import copy
import hashlib
from dataclasses import dataclass, replace
import inspect
from pathlib import Path
import sys
from types import SimpleNamespace
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


class StandaloneSettlementAuthority:
    """Explicit unit target for non-migration composed Market tests."""

    def __init__(self, auth, generation):
        self.authorization = auth
        self.generation = generation

    def exact_market_target_state(self):
        auth = self.authorization
        return (
            auth.target,
            auth.settlement_chain_id,
            auth.protocol_version,
            auth.runtime_hash,
            auth.configuration_hash,
            auth.expected_magic,
            "ACTIVE",
            self.generation,
        )


def make_pair(
    *,
    tip_slot=1_000,
    runway=settlement.SEAT_RUNWAY_SECONDS,
    market_label="market",
):
    auth = authorization()
    authority = StandaloneSettlementAuthority(auth, 7)
    runtime = market.TargetRuntime(auth, authority)
    release_manager = market.ReleaseManager(
        addr("release-manager"),
        activation_authority=SimpleNamespace(
            version_manager=addr("version-manager"),
            activation_receipts={},
        ),
    )
    release_manager.register_router_target(
        release_manager.activation_authority.version_manager,
        1,
        addr(market_label),
        auth,
        runtime,
    )
    seat_market = market.SeatMarket(
        market_chain_id=1,
        market_address=addr(market_label),
        sla_bond=1_000,
        immutable_maximum_ask=100,
        quote_maturity_seconds=10,
        quote_maturity_blocks=3,
        exit_delay_seconds=settlement.EXIT_DELAY_SECONDS,
        penalty_sink=addr("penalty"),
        authorization=auth,
        insertion_enabled=True,
        cached_generation=7,
        release_manager=release_manager,
        target_runtime=runtime,
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


def install_current_offer(
    protocol,
    seat_market,
    operator,
    ask,
    *,
    quoted_at,
    quoted_block,
):
    seat_market.sponsor_premium(ask * seat_market.seat_runway_seconds)
    row = seat_market.insert_offer(
        caller=addr(operator),
        payout=addr(f"pay-{operator}"),
        ask_wei_per_second=ask,
        target=protocol.settlement_address,
        generation=protocol.seat_generation,
        clock=market.Clock(quoted_at, quoted_block),
        value=seat_market.sla_bond,
    )
    staged = protocol.stage_best(
        seat_market,
        settlement.Clock(
            quoted_block + seat_market.quote_maturity_blocks,
            quoted_at + seat_market.quote_maturity_seconds,
        ),
    )
    if staged == "SYNCED" or staged.code is not market.ResultCode.STAGED:
        raise AssertionError("fixture did not stage current target")
    installed = protocol.apply_stage(
        seat_market,
        settlement.Clock(
            quoted_block + seat_market.quote_maturity_blocks + 1,
            staged.stage.handover_at,
        ),
    )
    return row, installed.tranche.installed_term_id


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
    if term_id in protocol.term_duty:
        return protocol.seat_duties[protocol.term_duty[term_id]]
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
    inbox_apply_descriptor: object
    migration_gate: object
    live_protocol: object
    header_oracle: object | None = None
    _router_authority: object | None = None
    attempts: int = 0

    def _record_canonical_from_protocol(self, *, protocol, clock):
        self.attempts += 1
        return None


def canonical_graph_state(protocol, history):
    """Deep state snapshot with shared authority identities made explicit."""

    normal_best = protocol.normal_best
    protocol_local = {
        key: value
        for key, value in protocol.__dict__.items()
        if key
        not in {
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "versioned_history",
            "_inbox_execution_authority",
            "_canonical_commit_frame",
            "normal_best",
        }
    }
    history_local = {
        key: value
        for key, value in history.__dict__.items()
        if key
        not in {
            "forced_queue",
            "inbox_apply_descriptor",
            "migration_gate",
            "live_protocol",
            "_router_authority",
        }
    }
    protocol_queue_local = {
        key: value
        for key, value in protocol.forced_queue.__dict__.items()
        if key != "_router_authority"
    }
    history_queue_local = {
        key: value
        for key, value in history.forced_queue.__dict__.items()
        if key != "_router_authority"
    }
    inbox_local = {
        key: value
        for key, value in protocol.inbox_apply_router.__dict__.items()
        if key != "_terminal_registrar_authority"
    }
    return (
        copy.deepcopy((
            protocol_local,
            history_local,
            protocol_queue_local,
            inbox_local,
            protocol.migration_gate.__dict__,
            history_queue_local,
            history.inbox_apply_descriptor,
            history.migration_gate.__dict__,
        )),
        (
            None if normal_best is None
            else settlement.candidate_inbox_execution_digest(normal_best)
        ),
        protocol._inbox_execution_authority.protocol is protocol,
        protocol.versioned_history is history,
        history.forced_queue is protocol.forced_queue,
        history.inbox_apply_descriptor == protocol.inbox_apply_descriptor,
        history.migration_gate is protocol.migration_gate,
        history.live_protocol is protocol,
    )


def bind_router_active_history(protocol, *, runtime_hash, execution_profile_hash):
    """Attach one exact bootstrapped History for rollback-focused fixtures."""

    profile = settlement.execution_profile_for_test(
        authorization().protocol_version, execution_profile_hash
    )
    history = settlement.VersionedSettlementHistory(
        protocol.settlement_address,
        runtime_hash,
        authorization().protocol_version,
        profile.execution_profile_hash,
        copy.deepcopy(protocol.core),
        protocol.canonical.canonicalized_at_block,
        protocol.forced_queue,
        migration_gate=protocol.migration_gate,
        live_protocol=protocol,
        inbox_apply_descriptor=protocol.inbox_apply_descriptor,
        header_oracle=protocol.header_oracle,
        execution_profile=profile,
    )
    protocol.versioned_history = history
    router = settlement.deploy_active_settlement_router(
        history,
        addr("version-manager"),
        protocol.forced_queue,
        protocol.inbox_apply_router,
        protocol.migration_gate,
        protocol.header_oracle,
    )
    if not router.bootstrap(
        history,
        sequence=0,
        clock=settlement.Clock(
            protocol.canonical.canonicalized_at_block,
            settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
        ),
        caller=router.version_manager,
    ):
        raise AssertionError("fixture failed to bootstrap exact History graph")
    return history, router


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
        enqueue_clock = settlement.Clock(
            1_099,
            service.prospective_recovery_at - 10 - settlement.FORCE_DELAY,
        )
        router = settlement.routed_ingress_for_test(protocol)
        adapter = settlement.activate_ingress_adapter_for_test(
            router,
            kind=settlement.ForceKind.USER_TX,
            clock=enqueue_clock,
        )
        descriptor = settlement.message(enqueue_clock.l2_slot, "force")
        self.assertEqual(
            adapter.enqueue(
                enqueue_clock,
                descriptor,
                caller=descriptor.sender,
                deposit=descriptor.prepaid,
            ),
            "QUEUED:0",
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
            rejected.inbox_apply_descriptor,
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
        profile = settlement.execution_profile_for_test(
            1, "profile:atomic-success"
        )
        history = settlement.VersionedSettlementHistory(
            "model-settlement",
            "runtime:atomic-success",
            1,
            profile.execution_profile_hash,
            copy.deepcopy(protocol.core),
            99,
            protocol.forced_queue,
            migration_gate=protocol.migration_gate,
            live_protocol=protocol,
            inbox_apply_descriptor=protocol.inbox_apply_descriptor,
            header_oracle=protocol.header_oracle,
            execution_profile=profile,
        )
        protocol.versioned_history = history
        active_router = settlement.deploy_active_settlement_router(
            history,
            addr("version-manager"),
            protocol.forced_queue,
            protocol.inbox_apply_router,
            protocol.migration_gate,
            protocol.header_oracle,
        )
        self.assertTrue(active_router.bootstrap(
            history,
            sequence=0,
            clock=settlement.Clock(100, settlement.GENESIS_TIMESTAMP + 999),
            caller=active_router.version_manager,
        ))
        queue = protocol.forced_queue
        router = protocol.inbox_apply_router
        gate = protocol.migration_gate
        arm_clock = settlement.Clock(
            101, settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot + 1
        )
        self.assertEqual(protocol.arm_normal_context(arm_clock), "ARMED")
        self.assertEqual(
            protocol.activate_normal_context(
                settlement.Clock(102, arm_clock.timestamp)
            ),
            "ACTIVATED",
        )
        commit_clock = settlement.Clock(103, arm_clock.timestamp)
        candidate = settlement.candidate(
            protocol, commit_clock, "history-success-then-seat-fault"
        )
        self.assertIsNotNone(candidate.inbox_execution_receipt)
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
        self.assertEqual(
            history.inbox_apply_descriptor,
            protocol.inbox_apply_descriptor,
        )
        self.assertIs(history.migration_gate, gate)

    def test_wrong_canonical_history_authority_graph_rejects_before_attempt(self):
        for wrong_field in (
            "forced_queue",
            "inbox_apply_descriptor",
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
                protocol.inbox_apply_descriptor,
                protocol.migration_gate,
                protocol,
            )
            if wrong_field == "live_protocol":
                history.live_protocol = None
            elif wrong_field == "inbox_apply_descriptor":
                history.inbox_apply_descriptor = replace(
                    history.inbox_apply_descriptor,
                    address="other-inbox",
                )
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
                history.inbox_apply_descriptor,
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
                    history.inbox_apply_descriptor,
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
        history, _active_router = bind_router_active_history(
            protocol,
            runtime_hash="runtime:composed-fault",
            execution_profile_hash="profile:composed-fault",
        )
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
        self.assertEqual(
            history.inbox_apply_descriptor,
            protocol.inbox_apply_descriptor,
        )
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
            history, _active_router = bind_router_active_history(
                protocol,
                runtime_hash=f"runtime:sync-fault:{activate_before_sync}",
                execution_profile_hash=(
                    f"profile:sync-fault:{activate_before_sync}"
                ),
            )
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
        protocol.minimum_primary_tenure_seconds = 10_000
        protocol.seat_runway_seconds = 20_000
        primary = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        standby = synthetic_term(2, primary.installed_at)
        protocol.install_seat_term_for_test(primary, rank=0, start_primary=True)
        protocol.install_seat_term_for_test(standby, rank=1, start_primary=False)
        duty = activate_current_duty(protocol)
        close_at = duty.recovery_at + 1
        self.assertLess(
            close_at,
            protocol.seat_services[primary.term_id].minimum_tenure_until,
        )
        before_visits = protocol.seat_scan_visits_total
        protocol._scan_seat_duties(
            settlement.Clock(901, close_at),
            allow_cure=False,
            excuse_for_migration=True,
        )
        protocol._close_seats_for_migration(close_at)
        self.assertEqual(
            protocol.seat_duties[duty.duty_id].status,
            settlement.DutyStatus.EXCUSED_MIGRATION,
        )
        self.assertEqual(protocol.seat_lineup, [])
        self.assertEqual(protocol.seat_scan_count, 4)
        self.assertEqual(protocol.seat_scan_visits_total - before_visits, 4)

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
        protocol._scan_seat_duties(
            settlement.Clock(901, duty.failover_at + 2),
            allow_cure=False,
            excuse_for_migration=True,
        )
        protocol._close_seats_for_migration(duty.failover_at + 2)
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


def migration_manager_fixture(*, seat=True):
    protocol = settlement.protocol(
        tip_slot=1_000,
        seat=seat,
        settlement_address=addr("settlement"),
    )
    profile = settlement.execution_profile_for_test(25, "profile:seat-v1")
    history = settlement.VersionedSettlementHistory(
        protocol.settlement_address,
        "runtime:seat-v1",
        25,
        profile.execution_profile_hash,
        copy.deepcopy(protocol.core),
        protocol.canonical.canonicalized_at_block,
        protocol.forced_queue,
        migration_gate=protocol.migration_gate,
        live_protocol=protocol,
        inbox_apply_descriptor=protocol.inbox_apply_descriptor,
        header_oracle=protocol.header_oracle,
        execution_profile=profile,
    )
    protocol.versioned_history = history
    router = settlement.deploy_active_settlement_router(
        history,
        addr("version-manager"),
        protocol.forced_queue,
        protocol.inbox_apply_router,
        protocol.migration_gate,
        protocol.header_oracle,
    )
    if not router.bootstrap(
        history,
        sequence=0,
        clock=settlement.Clock(
            protocol.canonical.canonicalized_at_block,
            settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
        ),
        caller=router.version_manager,
    ):
        raise AssertionError("fixture did not bootstrap active router")
    manager = settlement.ProtocolVersionManager(
        address=addr("version-manager"),
        router=router,
    )
    return protocol, manager


def migration_graph_projection(protocol, manager):
    history = protocol.versioned_history
    normal_best = protocol.normal_best
    protocol_state = {
        key: copy.deepcopy(value)
        for key, value in protocol.__dict__.items()
        if key not in {
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "versioned_history",
            "_inbox_execution_authority",
            "_canonical_commit_frame",
            "normal_best",
        }
    }
    history_state = {
        key: copy.deepcopy(value)
        for key, value in history.__dict__.items()
        if key not in {
            "forced_queue",
            "inbox_apply_router",
            "migration_gate",
            "live_protocol",
            "_router_authority",
        }
    }
    return (
        protocol_state,
        history_state,
        copy.deepcopy(protocol.forced_queue),
        copy.deepcopy({
            key: value
            for key, value in protocol.inbox_apply_router.__dict__.items()
            if key != "_terminal_registrar_authority"
        }),
        copy.deepcopy(protocol.migration_gate),
        copy.deepcopy(manager.arm_responses),
        copy.deepcopy(manager.abort_responses),
        copy.deepcopy(manager.arm_manifests),
        copy.deepcopy(manager.cancel_manifests),
        manager.router.active_version,
        tuple(manager.router.registrations),
        copy.deepcopy(manager.router.activation_receipts),
        copy.deepcopy(manager.router.activation_receipt_keys_by_generation),
        copy.deepcopy(
            manager.router.successor_receipt_key_by_old_authorization_id
        ),
        set(manager.router.used_target_addresses),
        (
            None if normal_best is None
            else settlement.candidate_inbox_execution_digest(normal_best)
        ),
        protocol._inbox_execution_authority.protocol is protocol,
    )


def execute_manager_arm(manager, clock, *, executable_at=None):
    manifest = settlement.ScheduledSeatMigration(
        1,
        25,
        26,
        b"m" * 32,
        clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        clock.timestamp if executable_at is None else executable_at,
    )
    if manifest.key not in manager.arm_manifests:
        manager.schedule_seat_migration(
            manifest,
            caller=manager.governance,
            clock=settlement.Clock(
                max(0, clock.block_number - 1), manifest.scheduled_at
            ),
        )
    return manager.arm_seat_migration(
        manifest_key=manifest.key,
        executor=addr("executor"),
        clock=clock,
    )


def execute_manager_abort(manager, clock, *, executable_at=None):
    manifest = settlement.ScheduledSeatMigration(
        1,
        25,
        26,
        b"m" * 32,
        clock.timestamp - settlement.SEAT_MIGRATION_CANCEL_DELAY,
        clock.timestamp if executable_at is None else executable_at,
    )
    if manifest.key not in manager.cancel_manifests:
        manager.schedule_seat_migration(
            manifest,
            caller=manager.governance,
            clock=settlement.Clock(
                max(0, clock.block_number - 1), manifest.scheduled_at
            ),
            cancel=True,
        )
    return manager.abort_seat_migration(
        manifest_key=manifest.key,
        executor=addr("executor"),
        clock=clock,
    )


def production_migration_fixture(
    *, target_header_variant: str = "exact",
    source_bridge_descriptor=None,
):
    old_auth = authorization()
    old_protocol = settlement.protocol(
        tip_slot=1_000, seat=False, settlement_address=old_auth.target
    )
    old_protocol.first_v2_block_number = 1
    old_profile = settlement.execution_profile_for_test(
        old_auth.protocol_version, "profile:seat-v1"
    )
    old_history = settlement.VersionedSettlementHistory(
        old_auth.target,
        "runtime:seat-v1",
        old_auth.protocol_version,
        old_profile.execution_profile_hash,
        copy.deepcopy(old_protocol.core),
        old_protocol.canonical.canonicalized_at_block,
        old_protocol.forced_queue,
        migration_gate=old_protocol.migration_gate,
        live_protocol=old_protocol,
        inbox_apply_descriptor=old_protocol.inbox_apply_descriptor,
        header_oracle=old_protocol.header_oracle,
        market_runtime_hash=old_auth.runtime_hash,
        market_configuration_hash=old_auth.configuration_hash,
        market_magic=old_auth.expected_magic,
        execution_profile=old_profile,
    )
    old_protocol.versioned_history = old_history
    router = settlement.deploy_active_settlement_router(
        old_history,
        addr("version-manager"),
        old_protocol.forced_queue,
        old_protocol.inbox_apply_router,
        old_protocol.migration_gate,
        old_protocol.header_oracle,
    )
    assert router.bootstrap(
        old_history,
        sequence=0,
        clock=settlement.Clock(
            old_protocol.canonical.canonicalized_at_block,
            settlement.GENESIS_TIMESTAMP + old_protocol.core.tip_slot,
        ),
        caller=router.version_manager,
    )
    release_manager = market.ReleaseManager(
        addr("release-manager"), activation_authority=router
    )
    manager = settlement.ProtocolVersionManager(
        addr("version-manager"),
        router,
        release_manager=release_manager,
        market_chain_id=1,
        market_address=addr("market"),
    )
    old_runtime = market.TargetRuntime(old_auth, old_history)
    old_id = release_manager.register_router_target(
        manager.address, 1, addr("market"), old_auth, old_runtime
    )
    seat_market = market.SeatMarket(
        market_chain_id=1,
        market_address=addr("market"),
        sla_bond=1_000,
        immutable_maximum_ask=100,
        quote_maturity_seconds=10,
        quote_maturity_blocks=3,
        exit_delay_seconds=settlement.EXIT_DELAY_SECONDS,
        penalty_sink=addr("penalty"),
        authorization=old_auth,
        insertion_enabled=True,
        cached_generation=old_protocol.seat_generation,
        release_manager=release_manager,
        target_runtime=old_runtime,
        seat_runway_seconds=old_protocol.seat_runway_seconds,
        handover_delay_seconds=settlement.HANDOVER_DELAY_SECONDS,
        stage_grace_seconds=settlement.STAGE_GRACE_SECONDS,
        maximum_inclusion_seconds=settlement.T_INCLUDE_MAX_SECONDS,
    )
    old_protocol.bind_seat_market_for_test(seat_market)

    new_auth = replace(
        old_auth,
        target=addr("settlement-v2"),
        protocol_version=old_auth.protocol_version + 1,
        runtime_hash=b"2" * 32,
        configuration_hash=b"d" * 32,
    )
    if target_header_variant == "exact":
        target_header_oracle = old_protocol.header_oracle
    elif target_header_variant == "copy-equal":
        target_header_oracle = old_protocol.header_oracle.fork_for_test({})
    elif target_header_variant == "forged-header":
        original = old_protocol.header_oracle.header(1)
        target_header_oracle = old_protocol.header_oracle.fork_for_test({
            1: replace(original, block_hash="f" * 64)
        })
    elif target_header_variant == "substituted-runtime":
        target_header_oracle = settlement.L1HeaderOracle(
            settlement.L1_HEADER_ORACLE_ADDRESS,
            "other-runtime",
            settlement.L1_HEADER_ORACLE_CONFIGURATION_HASH,
            dict(old_protocol.header_oracle._headers),
        )
    else:
        raise ValueError("unknown target header variant")
    new_protocol = settlement.protocol(
        tip_slot=old_protocol.core.tip_slot,
        cursor=old_protocol.core.message_cursor,
        seat=False,
        mode=settlement.Mode.PREACTIVE,
        forced_queue=old_protocol.forced_queue,
        inbox_apply_router=old_protocol.inbox_apply_router,
        header_oracle=target_header_oracle,
        migration_gate=old_protocol.migration_gate,
        settlement_address=new_auth.target,
    )
    new_protocol.seat_generation = 0
    new_protocol.canonical = copy.deepcopy(old_protocol.canonical)
    new_profile = settlement.execution_profile_for_test(
        new_auth.protocol_version, "profile:seat-v2"
    )
    new_history = settlement.VersionedSettlementHistory(
        new_auth.target,
        "runtime:seat-v2",
        new_auth.protocol_version,
        new_profile.execution_profile_hash,
        copy.deepcopy(old_protocol.core),
        old_protocol.canonical.canonicalized_at_block,
        old_protocol.forced_queue,
        migration_gate=old_protocol.migration_gate,
        live_protocol=new_protocol,
        inbox_apply_descriptor=old_protocol.inbox_apply_descriptor,
        header_oracle=target_header_oracle,
        market_runtime_hash=new_auth.runtime_hash,
        market_configuration_hash=new_auth.configuration_hash,
        market_magic=new_auth.expected_magic,
        execution_profile=new_profile,
        source_bridge_descriptor=source_bridge_descriptor,
        release_profile_ingress_specs=(
            (settlement.ForceKind.USER_TX, "kind0-adapter", ""),
            (
                settlement.ForceKind.BRIDGE_CREDIT,
                "bridge-inbox-adapter:v2",
                "bridge:v2",
            ),
        ),
    )
    new_protocol.versioned_history = new_history
    new_runtime = market.TargetRuntime(new_auth, new_history)
    new_id = release_manager.register_router_target(
        manager.address, 1, addr("market"), new_auth, new_runtime
    )
    new_protocol.seat_authorization_id = new_id
    new_protocol.seat_market_address = addr("market")
    return (
        old_protocol, old_history, new_history, seat_market, manager,
        release_manager, old_id, new_id,
    )


def prepare_production_activation(rows, *, clock=None):
    (
        old_protocol, old_history, new_history, seat_market, manager,
        release_manager, old_id, new_id,
    ) = rows
    arm_clock = clock or settlement.Clock(
        1_000, settlement.GENESIS_TIMESTAMP + 1_000
    )
    activation_clock = settlement.Clock(
        max(old_history.last_canonical_l1_block + 1,
            arm_clock.block_number + 1),
        max(
            arm_clock.timestamp + 1,
            settlement.GENESIS_TIMESTAMP + old_history.core.tip_slot + 1,
        ),
    )
    target_manifest_hash = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=activation_clock.block_number,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    ).release_manifest_hash
    manifest = settlement.ScheduledSeatMigration(
        1, 25, 26, target_manifest_hash,
        arm_clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        arm_clock.timestamp,
        old_id,
        new_id,
    )
    manager.schedule_seat_migration(
        manifest,
        caller=manager.governance,
        clock=settlement.Clock(
            max(0, arm_clock.block_number - 1), manifest.scheduled_at
        ),
    )
    manager.arm_seat_migration(
        manifest_key=manifest.key, executor=addr("executor"), clock=arm_clock
    )
    manager.router.registrations[25].settlement.live_protocol.sync(arm_clock)
    assert old_history.enter_migration_ready()
    candidate, inbox_rows = settlement.migration_activation_candidate(
        manager.router,
        new_history,
        activation_clock,
        target_manifest_hash,
        "production-activation",
        addr("beneficiary"),
    )
    authority = new_history.live_protocol._inbox_execution_authority
    attestation = settlement.issue_verified_migration_evm_trace_for_test(
        authority,
        router=manager.router,
        settlement=new_history,
        clock=activation_clock,
        target_manifest_hash=target_manifest_hash,
        candidate=candidate,
        rows=inbox_rows,
    )
    proof = authority.verify_migration_execution_output(
        router=manager.router,
        settlement=new_history,
        clock=activation_clock,
        target_manifest_hash=target_manifest_hash,
        candidate=candidate,
        evm_validity=attestation,
        rows=inbox_rows,
    )
    return manifest, proof


def migration_proof_clock(proof):
    return settlement.Clock(
        proof.candidate.blocks[0].anchor_number + settlement.F_L1,
        proof.candidate.blocks[0].evm_timestamp,
    )


def activate_production_fixture(rows, *, clock=None):
    manifest, proof = prepare_production_activation(
        rows, clock=clock
    )
    manager = rows[4]
    activation_clock = migration_proof_clock(proof)
    poststate = settlement.replay_verified_migration_output_on_l2_for_test(
        rows[2].live_protocol, proof, manager.router
    )
    assert poststate is not None
    receipt = manager.activate_seat_migration(
        manifest_key=manifest.key,
        activation_proof=proof,
        executor=addr("executor"),
        clock=activation_clock,
    )
    assert settlement.select_canonical_l2_poststate_for_test(poststate)
    return receipt


def register_production_successor(rows, *, label: str, protocol_version: int):
    manager, release_manager = rows[4], rows[5]
    old_history = manager.router.registrations[manager.router.active_version].settlement
    old_protocol = old_history.live_protocol
    old_auth = release_manager.authorizations[old_protocol.seat_authorization_id]
    new_auth = replace(
        old_auth,
        target=addr(f"settlement-{label}"),
        protocol_version=protocol_version,
        runtime_hash=label.encode().ljust(32, b"r")[:32],
        configuration_hash=label.encode().ljust(32, b"c")[:32],
    )
    new_protocol = settlement.protocol(
        tip_slot=old_protocol.core.tip_slot,
        cursor=old_protocol.core.message_cursor,
        seat=False,
        mode=settlement.Mode.PREACTIVE,
        forced_queue=old_protocol.forced_queue,
        inbox_apply_router=old_protocol.inbox_apply_router,
        header_oracle=manager.router.header_oracle,
        migration_gate=manager.router.migration_gate,
        settlement_address=new_auth.target,
    )
    new_protocol.seat_generation = 0
    new_protocol.canonical = copy.deepcopy(old_protocol.canonical)
    new_profile = settlement.execution_profile_for_test(
        protocol_version, f"profile:{label}"
    )
    new_history = settlement.VersionedSettlementHistory(
        new_auth.target,
        f"runtime:{label}",
        protocol_version,
        new_profile.execution_profile_hash,
        copy.deepcopy(old_history.core),
        old_history.canonicalized_at_block,
        old_protocol.forced_queue,
        migration_gate=old_protocol.migration_gate,
        live_protocol=new_protocol,
        inbox_apply_descriptor=old_protocol.inbox_apply_descriptor,
        header_oracle=manager.router.header_oracle,
        market_runtime_hash=new_auth.runtime_hash,
        market_configuration_hash=new_auth.configuration_hash,
        market_magic=new_auth.expected_magic,
        execution_profile=new_profile,
        release_profile_ingress_specs=(
            (settlement.ForceKind.USER_TX, "kind0-adapter", ""),
            (
                settlement.ForceKind.BRIDGE_CREDIT,
                f"bridge-inbox-adapter:{label}",
                f"bridge:{label}",
            ),
        ),
    )
    new_protocol.versioned_history = new_history
    runtime = market.TargetRuntime(new_auth, new_history)
    authorization_id = release_manager.register_router_target(
        manager.address,
        manager.market_chain_id,
        manager.market_address,
        new_auth,
        runtime,
    )
    new_protocol.seat_authorization_id = authorization_id
    new_protocol.seat_market_address = manager.market_address
    return new_history, authorization_id


def activate_registered_successor(
    rows,
    new_history,
    old_authorization_id,
    new_authorization_id,
    *,
    manifest_byte: bytes,
    clock: settlement.Clock | None = None,
):
    manager = rows[4]
    old_history = manager.router.registrations[manager.router.active_version].settlement
    old_protocol = old_history.live_protocol
    generation = old_protocol.migration_gate.generation + 1
    timestamp = settlement.GENESIS_TIMESTAMP + 1_000 + generation * 100
    clock = clock or settlement.Clock(
        max(old_history.last_canonical_l1_block + 10, 1_000 + generation * 10),
        timestamp,
    )
    timestamp = clock.timestamp
    manifest_hash = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=clock.block_number,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    ).release_manifest_hash
    manifest = settlement.ScheduledSeatMigration(
        generation,
        old_history.protocol_version,
        new_history.protocol_version,
        manifest_hash,
        timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        timestamp,
        old_authorization_id,
        new_authorization_id,
    )
    manager.schedule_seat_migration(
        manifest,
        caller=manager.governance,
        clock=settlement.Clock(
            max(0, clock.block_number - 1), manifest.scheduled_at
        ),
    )
    manager.arm_seat_migration(
        manifest_key=manifest.key, executor=addr("executor"), clock=clock
    )
    old_protocol.sync(clock)
    activation_clock = settlement.Clock(
        max(old_history.last_canonical_l1_block + 1, clock.block_number + 1),
        max(
            clock.timestamp + 1,
            settlement.GENESIS_TIMESTAMP + old_history.core.tip_slot + 1,
        ),
    )
    candidate, inbox_rows = settlement.migration_activation_candidate(
        manager.router,
        new_history,
        activation_clock,
        manifest_hash,
        manifest_byte.hex(),
        addr("beneficiary"),
    )
    authority = new_history.live_protocol._inbox_execution_authority
    attestation = settlement.issue_verified_migration_evm_trace_for_test(
        authority,
        router=manager.router,
        settlement=new_history,
        clock=activation_clock,
        target_manifest_hash=manifest_hash,
        candidate=candidate,
        rows=inbox_rows,
    )
    proof = authority.verify_migration_execution_output(
        router=manager.router,
        settlement=new_history,
        clock=activation_clock,
        target_manifest_hash=manifest_hash,
        candidate=candidate,
        evm_validity=attestation,
        rows=inbox_rows,
    )
    poststate = settlement.replay_verified_migration_output_on_l2_for_test(
        new_history.live_protocol, proof, manager.router
    )
    assert poststate is not None
    receipt = manager.activate_seat_migration(
        manifest_key=manifest.key,
        activation_proof=proof,
        executor=addr("executor"),
        clock=activation_clock,
    )
    assert settlement.select_canonical_l2_poststate_for_test(poststate)
    return receipt


def abort_current_migration_generation(rows, *, target_version: int, manifest_byte: bytes):
    manager = rows[4]
    history = manager.router.registrations[manager.router.active_version].settlement
    protocol = history.live_protocol
    generation = protocol.migration_gate.generation + 1
    timestamp = settlement.GENESIS_TIMESTAMP + 1_000 + generation * 100
    clock = settlement.Clock(
        max(history.last_canonical_l1_block + 10, 1_000 + generation * 10),
        timestamp,
    )
    manifest_hash = manifest_byte * 32
    arm = settlement.ScheduledSeatMigration(
        generation,
        history.protocol_version,
        target_version,
        manifest_hash,
        timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        timestamp,
    )
    manager.schedule_seat_migration(
        arm,
        caller=manager.governance,
        clock=settlement.Clock(
            max(0, clock.block_number - 1), arm.scheduled_at
        ),
    )
    manager.arm_seat_migration(
        manifest_key=arm.key, executor=addr("executor"), clock=clock
    )
    cancel_timestamp = timestamp + settlement.SEAT_MIGRATION_CANCEL_DELAY
    cancel = replace(
        arm,
        scheduled_at=timestamp,
        executable_at=cancel_timestamp,
    )
    manager.schedule_seat_migration(
        cancel,
        caller=manager.governance,
        clock=settlement.Clock(clock.block_number, cancel.scheduled_at),
        cancel=True,
    )
    manager.abort_seat_migration(
        manifest_key=cancel.key,
        executor=addr("executor"),
        clock=settlement.Clock(clock.block_number + 1, cancel_timestamp),
    )


class ForcedIngressRouterTests(unittest.TestCase):
    def setUp(self):
        self.protocol, self.manager = migration_manager_fixture(seat=False)
        self.router = self.manager.router
        self.clock = settlement.Clock(
            self.protocol.canonical.canonicalized_at_block + 1,
            settlement.GENESIS_TIMESTAMP + self.protocol.core.tip_slot,
        )
        self.kind0_adapter = settlement.activate_ingress_adapter_for_test(
            self.router,
            kind=settlement.ForceKind.USER_TX,
            clock=self.clock,
        )
        self.source_bridge = settlement.source_bridge_for_test(
            self.router
        )
        self.credit_registry = self.source_bridge.credit_registry
        self.bridge_adapter = settlement.activate_ingress_adapter_for_test(
            self.router,
            kind=settlement.ForceKind.BRIDGE_CREDIT,
            clock=self.clock,
            source_bridge=self.source_bridge,
        )
        self.destination_store = settlement.InboxCreditStoreV2(
            "inbox-apply", self.source_bridge.address, ""
        )
        self.destination_manifest = settlement.release_manifest_fixture(
            77,
            "",
            self.source_bridge.address,
            self.destination_store,
            router=self.router,
        )
        self.destination_accumulator = settlement.TerminalAccumulatorV2({
            self.destination_manifest.destination_domain_id:
                self.destination_manifest.destination_bridge,
        })
        self.destination_receiver = settlement.BridgeCallReceiverV2(
            "bridge-recipient"
        )
        self.destination_bridge = settlement.destination_bridge_for_test(
            self.destination_manifest,
            self.destination_store,
            self.destination_accumulator,
            applications=(self.destination_receiver,),
            balance=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            quota=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            timestamp=self.clock.timestamp,
        )
        self.destination_environment = (
            self.destination_bridge.execution_environment
        )
        self._destination_queue_index = 0

    def activate_adapter(self, adapter, kind):
        if kind is settlement.ForceKind.USER_TX:
            self.assertIsNotNone(self.router._ingress_binding(adapter))
            return
        if type(adapter) is settlement.BridgeAdapter:
            registration = self.router.registrations[
                self.router.active_version
            ]
            domain = settlement.derive_ingress_destination_domain(
                adapter, registration
            )
            authorization = registration.ingress_authorizations_by_address[
                adapter.address
            ]
            self.assertIs(
                adapter.credit_registry.domain_registry
                    ._destinations_by_domain.get(domain),
                registration.release_manifests_by_adapter[adapter.address],
            )
            self.assertEqual(
                authorization.destination_bridge,
                registration.release_manifests_by_adapter[
                    adapter.address
                ].destination_bridge,
            )
        activation_clock = (
            adapter.source_bridge.support_final_clock(self.clock.timestamp)
            if type(adapter) is settlement.BridgeAdapter
            else self.clock
        )
        self.assertTrue(self.router.activate_profile_bridge_adapter(
            adapter,
            protocol_version=self.router.active_version,
            executor=addr("executor"),
            clock=activation_clock,
        ))

    def bridge_descriptor(self, label="bridge"):
        return settlement.bridge_message(self.clock.l2_slot, label)

    def destination_delivery(
        self,
        label,
        *,
        to=None,
        value=1,
        fee=1,
        gas_limit=settlement.MAX_FORCE_MESSAGE_GAS,
        data=None,
        install_pin=True,
        liquidity_fee=1,
        fund_liquidity=True,
    ):
        self._destination_queue_index += 1
        message = settlement.IBridgeMessageV1(
            self._destination_queue_index,
            fee,
            gas_limit,
            addr(hashlib.sha256(f"sender:{label}".encode()).hexdigest()[:20]),
            1,
            addr(hashlib.sha256(f"owner:{label}".encode()).hexdigest()[:20]),
            self.destination_bridge.destination_chain_id,
            addr("destination-owner"),
            self.destination_receiver.address if to is None else to,
            value,
            (settlement.ON_MESSAGE_INVOCATION_SELECTOR + label.encode())
            if data is None else data,
        )
        source, route = settlement.destination_delivery_context_for_test(
            self.destination_bridge,
            message,
            queue_index=self._destination_queue_index,
            liquidity_fee=liquidity_fee,
        )
        if install_pin:
            self.assertTrue(settlement.install_destination_pin_for_test(
                self.destination_bridge,
                message,
                source,
                route,
                now=self.clock.timestamp,
                liquidity_fee=liquidity_fee,
            ))
            if fund_liquidity and value + fee > 0:
                ticket_id = (
                    settlement.reserve_destination_liquidity_for_test(
                        self.destination_bridge,
                        message,
                        source,
                        route,
                        now=self.clock.timestamp,
                        owner=addr("lp"),
                        l1_recipient=addr("lp-l1"),
                    )
                )
                self.assertTrue(ticket_id)
        return message, source, route

    def test_protocol_exposes_no_forced_ingress_append_bypass(self):
        for name in (
            "admit_message",
            "admit_bridge_direct",
            "sync_ingress",
            "append_from_adapter",
        ):
            self.assertFalse(hasattr(self.protocol, name), name)
        self.assertFalse(hasattr(self.router.forced_queue, "append"))

    def test_queue_cursor_and_escrow_require_exact_commit_frames(self):
        queue = self.router.forced_queue
        self.assertFalse(hasattr(queue, "advance_cursor"))
        forged = settlement.candidate(
            self.protocol,
            self.clock,
            "forged-direct-queue-advance",
            beneficiary=addr("attacker"),
        )
        queue_before = queue._transaction_snapshot()
        self.assertFalse(queue._advance_from_active_settlement(
            settlement=self.protocol.versioned_history,
            candidate=forged,
        ))
        self.assertEqual(queue._transaction_snapshot(), queue_before)

        rows = production_migration_fixture()
        manifest, proof = prepare_production_activation(rows)
        migration_queue = rows[4].router.forced_queue
        migration_before = migration_queue._transaction_snapshot()
        self.assertFalse(
            migration_queue._activate_and_advance_from_router(
                expected_old=rows[1].address,
                settlement=rows[2],
                proof=proof,
                router=rows[4].router,
            )
        )
        self.assertFalse(
            migration_queue._activate_and_advance_from_router(
                expected_old=rows[1].address,
                settlement=rows[2],
                proof=replace(proof, beneficiary=addr("attacker")),
                router=rows[4].router,
            )
        )
        self.assertEqual(
            migration_queue._transaction_snapshot(), migration_before
        )
        receipt = rows[4].activate_seat_migration(
            manifest_key=manifest.key,
            activation_proof=proof,
            executor=addr("executor"),
            clock=migration_proof_clock(proof),
        )
        self.assertIsNotNone(receipt)
        self.assertEqual(
            migration_queue.active_settlement_address, rows[2].address
        )

    def test_router_owns_stamped_two_phase_append(self):
        status, stamp = self.router.sync_ingress(
            clock=self.clock,
            caller_adapter=self.kind0_adapter,
        )
        self.assertEqual(status, "ACTIVE")
        self.assertEqual(
            stamp,
            (
                self.router.active_version,
                self.router.migration_gate.generation,
            ),
        )
        before = self.router.forced_queue.count
        descriptor = settlement.message(self.clock.l2_slot, "kind0-direct")
        self.assertEqual(
            self.router.append_from_adapter(
                descriptor,
                clock=self.clock,
                stamp=stamp,
                deposit=descriptor.prepaid,
                caller_adapter=self.kind0_adapter,
            ),
            f"QUEUED:{before}",
        )
        stored = self.router.forced_queue.descriptors[before]
        self.assertEqual(stored.enqueued_at, self.clock.timestamp)
        self.assertEqual(stored.due_at, self.clock.timestamp + settlement.FORCE_DELAY)
        self.assertEqual(stored.prepaid, descriptor.prepaid)

    def test_exact_adapter_identity_and_kind_role_are_not_forgeable(self):
        with self.assertRaises(ValueError):
            self.router.append_from_adapter(
                replace(self.bridge_descriptor(), prepaid=3),
                clock=self.clock,
                stamp=(self.router.active_version, 0),
                deposit=3,
                caller_adapter="bridge-inbox-adapter",
            )
        status, stamp = self.router.sync_ingress(
            clock=self.clock, caller_adapter=self.kind0_adapter
        )
        self.assertEqual(status, "ACTIVE")
        with self.assertRaises(ValueError):
            self.router.append_from_adapter(
                replace(self.bridge_descriptor(), prepaid=3),
                clock=self.clock,
                stamp=stamp,
                deposit=3,
                caller_adapter=self.kind0_adapter,
            )

    def test_profile_native_registry_is_typed_append_only(self):
        original_bindings = self.router.authorized_ingress
        for legacy_surface in (
            "ingress_manifests",
            "pending_ingress_by_address",
            "activated_ingress_manifests",
            "schedule_ingress_adapter",
            "activate_ingress_adapter",
        ):
            self.assertFalse(hasattr(self.manager, legacy_surface))
        self.assertFalse(
            hasattr(self.router, "_register_ingress_from_manager")
        )
        self.assertFalse(
            hasattr(self.bridge_adapter, "_seal_destination_from_manager")
        )
        with self.assertRaises(ValueError):
            settlement.ProtocolVersionManager(self.manager.address, self.router)
        evil = settlement.BridgeAdapter(
            self.router,
            self.credit_registry,
            self.source_bridge,
            address="bridge-inbox-adapter:not-in-release",
        )
        self.assertFalse(self.router.activate_profile_bridge_adapter(
            evil,
            protocol_version=self.router.active_version,
            executor=addr("executor"),
            clock=self.source_bridge.support_final_clock(self.clock.timestamp),
        ))
        self.assertEqual(self.router.authorized_ingress, original_bindings)
        old_status, old_stamp = self.router.sync_ingress(
            clock=self.clock, caller_adapter=self.bridge_adapter
        )
        self.assertEqual(old_status, "ACTIVE")
        self.assertIsNotNone(old_stamp)

    def test_ingress_registry_conflicts_and_metadata_mismatches_roll_back(self):
        bindings_before = self.router.authorized_ingress
        clone = settlement.BridgeAdapter(
            self.router,
            self.credit_registry,
            self.source_bridge,
            address=self.bridge_adapter.address,
        )
        self.assertFalse(self.router.activate_profile_bridge_adapter(
            clone,
            protocol_version=self.router.active_version,
            executor=addr("executor"),
            clock=self.source_bridge.support_final_clock(self.clock.timestamp),
        ))
        wrong_runtime = settlement.BridgeAdapter(
            self.router,
            self.credit_registry,
            self.source_bridge,
            runtime_hash="code:bridge-inbox-adapter:clone",
        )
        self.assertFalse(self.router.activate_profile_bridge_adapter(
            wrong_runtime,
            protocol_version=self.router.active_version,
            executor=addr("executor"),
            clock=self.source_bridge.support_final_clock(self.clock.timestamp),
        ))
        self.assertEqual(self.router.authorized_ingress, bindings_before)

    def test_due_at_uses_each_dominant_term_and_checked_uint64(self):
        for dominant in ("delay", "queue", "recovery"):
            with self.subTest(dominant=dominant):
                protocol, manager = migration_manager_fixture(seat=False)
                router = manager.router
                clock = settlement.Clock(
                    protocol.canonical.canonicalized_at_block + 1,
                    settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
                )
                adapter = settlement.activate_ingress_adapter_for_test(
                    router,
                    kind=settlement.ForceKind.USER_TX,
                    clock=clock,
                )
                expected = clock.timestamp + settlement.FORCE_DELAY
                if dominant == "queue":
                    expected += 7
                    router.forced_queue.last_due_at = expected
                elif dominant == "recovery":
                    protocol._activate(clock, settlement.Cause.FORCE_DUE)
                    expected = protocol.recovery.expires_at + 1
                status, stamp = router.sync_ingress(
                    clock=clock, caller_adapter=adapter
                )
                self.assertEqual(status, "ACTIVE")
                descriptor = settlement.message(
                    clock.l2_slot, f"due-{dominant}")
                self.assertEqual(
                    router.append_from_adapter(
                        descriptor,
                        clock=clock,
                        stamp=stamp,
                        deposit=descriptor.prepaid,
                        caller_adapter=adapter,
                    ),
                    "QUEUED:0",
                )
                self.assertEqual(
                    router.forced_queue.descriptors[0].due_at, expected
                )

        for overflow in ("delay", "queue", "recovery"):
            with self.subTest(overflow=overflow):
                protocol, manager = migration_manager_fixture(seat=False)
                router = manager.router
                clock = settlement.Clock(
                    protocol.canonical.canonicalized_at_block + 1,
                    settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
                )
                adapter = settlement.activate_ingress_adapter_for_test(
                    router,
                    kind=settlement.ForceKind.USER_TX,
                    clock=clock,
                )
                status, stamp = router.sync_ingress(
                    clock=clock, caller_adapter=adapter
                )
                self.assertEqual(status, "ACTIVE")
                append_clock = clock
                if overflow == "delay":
                    append_clock = settlement.Clock(
                        clock.block_number,
                        settlement.UINT64_MAX - settlement.FORCE_DELAY + 1,
                    )
                elif overflow == "queue":
                    router.forced_queue.last_due_at = settlement.UINT64_MAX + 1
                else:
                    protocol._activate(clock, settlement.Cause.FORCE_DUE)
                    protocol.recovery = replace(
                        protocol.recovery, expires_at=settlement.UINT64_MAX
                    )
                descriptor = replace(
                    settlement.message(
                        clock.l2_slot, f"overflow-{overflow}"),
                    prepaid=3,
                )
                queue_before = copy.deepcopy(router.forced_queue)
                with self.assertRaises(ValueError):
                    router.append_from_adapter(
                        descriptor,
                        clock=append_clock,
                        stamp=stamp,
                        deposit=3,
                        caller_adapter=adapter,
                    )
                self.assertEqual(router.forced_queue, queue_before)

    def test_invalid_kind0_is_rejected_before_sync_and_valid_sync_is_refundable(self):
        far_clock = settlement.Clock(
            self.clock.block_number + 1,
            settlement.GENESIS_TIMESTAMP
            + self.protocol.core.tip_slot
            + settlement.DELTA_FINAL_LAG
            + 1,
        )
        invalid = replace(
            settlement.message(far_clock.l2_slot, "bad-signature"),
            signature_ok=False,
        )
        queue_before = copy.deepcopy(self.router.forced_queue)
        with self.assertRaises(ValueError):
            self.kind0_adapter.enqueue(
                far_clock,
                invalid,
                caller=invalid.sender,
                deposit=invalid.prepaid,
            )
        self.assertIs(self.protocol.mode, settlement.Mode.NORMAL)
        self.assertEqual(self.router.forced_queue, queue_before)
        valid = settlement.message(far_clock.l2_slot, "valid")
        self.assertEqual(
            self.kind0_adapter.enqueue(
                far_clock,
                valid,
                caller=valid.sender,
                deposit=valid.prepaid,
            ),
            "SYNCED_REFUNDED",
        )
        self.assertIs(self.protocol.mode, settlement.Mode.RECOVERY)
        self.assertEqual(
            self.kind0_adapter.refunds[valid.sender], valid.prepaid
        )

    def test_bridge_post_append_faults_restore_queue_source_and_adapter(self):
        for fault_point in ("after_source_mark", "after_adapter_record"):
            with self.subTest(fault_point=fault_point):
                protocol, manager = migration_manager_fixture(seat=False)
                clock = settlement.Clock(
                    protocol.canonical.canonicalized_at_block + 1,
                    settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
                )
                source = settlement.source_bridge_for_test(manager.router)
                adapter = settlement.activate_ingress_adapter_for_test(
                    manager.router,
                    kind=settlement.ForceKind.BRIDGE_CREDIT,
                    clock=clock,
                    source_bridge=source,
                )
                enqueue_by = (
                    clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                )
                source_clock = source.support_final_clock(clock.timestamp)
                descriptor = settlement.bridge_message(
                    clock.l2_slot,
                    fault_point,
                    value=3,
                    fee=1,
                )
                credit_id = source.send_message(
                    descriptor,
                    clock=source_clock,
                    enqueue_by=enqueue_by,
                    caller=descriptor.sender,
                    msg_value=(descriptor.bridge_value + descriptor.bridge_fee
                               + descriptor.bridge_liquidity_fee),
                ).credit_id
                queue_before = copy.deepcopy(manager.router.forced_queue)
                source_before = copy.deepcopy(source)
                records_before = copy.deepcopy(adapter.records)
                adapter.fault_point = fault_point
                with self.assertRaises(RuntimeError):
                    adapter.enqueue(
                        source_clock,
                        envelope=descriptor,
                        caller=addr("relayer"),
                        deposit=descriptor.prepaid,
                    )
                self.assertEqual(manager.router.forced_queue, queue_before)
                self.assertEqual(source, source_before)
                self.assertEqual(adapter.records, records_before)
                self.assertFalse(adapter.entered)
                self.assertIs(adapter.router, manager.router)
                self.assertIs(
                    manager.router.registrations[
                        manager.router.active_version
                    ].settlement.live_protocol,
                    protocol,
                )

    def test_source_identity_and_emission_block_are_fixed_width(self):
        label = "fixed-source-identity"
        enqueue_by = self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        envelope = settlement.bridge_message(
            self.clock.l2_slot, label, value=0, fee=1
        )
        source_clock = self.source_bridge.support_final_clock(
            self.clock.timestamp
        )
        credit_id = self.source_bridge.credit_id_for(envelope, source_clock)
        source_before = self.source_bridge._transaction_snapshot()
        registry_before = dict(self.credit_registry.authorizations)
        for source_chain_id in (
            0,
            self.source_bridge.source_chain_id + 1,
            settlement.UINT64_MAX,
        ):
            with self.subTest(source_chain_id=source_chain_id):
                raw = replace(
                    envelope,
                    message=replace(
                        envelope.message, source_chain_id=source_chain_id
                    ),
                )
                self.assertEqual(
                    self.source_bridge.credit_id_for(raw, source_clock),
                    credit_id,
                )
        for block_number in (0, settlement.UINT64_MAX + 1):
            with self.subTest(block_number=block_number):
                with self.assertRaises(ValueError):
                    self.source_bridge.send_message(
                        envelope,
                        clock=settlement.Clock(
                            block_number, self.clock.timestamp
                        ),
                        enqueue_by=enqueue_by,
                        caller=envelope.sender,
                        msg_value=(envelope.bridge_value + envelope.bridge_fee
                                   + envelope.bridge_liquidity_fee),
                    )
                self.assertEqual(
                    self.source_bridge._transaction_snapshot(), source_before
                )
                self.assertEqual(
                    self.credit_registry.authorizations, registry_before
                )

        self.assertEqual(self.source_bridge.send_message(
            envelope,
            clock=source_clock,
            enqueue_by=enqueue_by,
            caller=envelope.sender,
            msg_value=(envelope.bridge_value + envelope.bridge_fee
                       + envelope.bridge_liquidity_fee),
        ).credit_id, credit_id)
        for emitted_at_block in (0, settlement.UINT64_MAX + 1):
            with self.subTest(emitted_at_block=emitted_at_block):
                valid = self.credit_registry.authorizations[credit_id]
                self.credit_registry._authorizations[credit_id] = replace(
                    valid, emitted_at_block=emitted_at_block
                )
                before = (
                    copy.deepcopy(self.router.forced_queue),
                    copy.deepcopy(dict(self.source_bridge.credits)),
                    copy.deepcopy(self.bridge_adapter.records),
                )
                with self.assertRaises(ValueError):
                    self.bridge_adapter.enqueue(
                        source_clock,
                        envelope=envelope,
                        caller=addr("enqueuer"),
                        deposit=envelope.prepaid,
                    )
                self.assertEqual(self.router.forced_queue, before[0])
                self.assertEqual(self.source_bridge.credits, before[1])
                self.assertEqual(self.bridge_adapter.records, before[2])
                self.credit_registry._authorizations[credit_id] = valid

    def test_raw_bridge_message_derives_every_dynamic_commitment(self):
        for size in (0, 31, 32, 33, settlement.MAX_FORCE_MESSAGE_BYTES):
            with self.subTest(size=size):
                raw = bytes((index % 251 for index in range(size)))
                envelope = settlement.bridge_message(
                    self.clock.l2_slot,
                    f"raw-{size}",
                    data=raw,
                )
                self.assertIsInstance(
                    envelope, settlement.BridgeAdmissionEnvelope
                )
                self.assertIsInstance(
                    envelope.message, settlement.IBridgeMessageV1
                )
                self.assertEqual(envelope.message.data, raw)
                self.assertEqual(envelope.byte_length, len(raw))
                self.assertEqual(
                    envelope.bridge_data_hash,
                    settlement.bridge_message_data_hash(raw),
                )
                self.assertEqual(
                    envelope.payload_hash,
                    settlement.bridge_message_hash(envelope.message),
                )
                if size:
                    changed = raw[:-1] + bytes([raw[-1] ^ 1])
                    forged = replace(
                        envelope,
                        message=replace(envelope.message, data=changed),
                    )
                    self.assertNotEqual(
                        forged.payload_hash, envelope.payload_hash
                    )
                    self.assertNotEqual(
                        forged.bridge_data_hash, envelope.bridge_data_hash
                    )
        with self.assertRaises(ValueError):
            settlement.bridge_message(
                self.clock.l2_slot,
                "oversize-raw",
                data=b"x" * (settlement.MAX_FORCE_MESSAGE_BYTES + 1),
            )
        self.assertNotIn(
            "data_hash", settlement.IBridgeMessageV1.__dataclass_fields__
        )
        self.assertNotIn(
            "data_length", settlement.IBridgeMessageV1.__dataclass_fields__
        )
        for legacy_field in (
            "bridge_data_hash",
            "bridge_data_length",
            "bridge_value",
            "bridge_fee",
        ):
            self.assertNotIn(
                legacy_field, settlement.Message.__dataclass_fields__
            )

    def test_source_bridge_send_splits_authorization_from_funded_liability(self):
        bridge = settlement.source_bridge_for_test(self.router)
        registry = bridge.credit_registry
        clock = bridge.support_final_clock(self.clock.timestamp)
        enqueue_by = self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "funded-source-send",
            value=10,
            fee=2,
        )
        self.assertFalse(hasattr(registry, "open"))
        self.assertFalse(hasattr(bridge, "open"))
        for funding in (0, 11, 12):
            with self.subTest(funding=funding):
                registry_before = dict(registry.authorizations)
                bridge_before = bridge._transaction_snapshot()
                with self.assertRaises(ValueError):
                    bridge.send_message(
                        envelope,
                        caller=envelope.sender,
                        msg_value=funding,
                        clock=clock,
                        enqueue_by=enqueue_by,
                    )
                self.assertEqual(registry.authorizations, registry_before)
                self.assertEqual(bridge._transaction_snapshot(), bridge_before)
        credit_id = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=13,
            clock=clock,
            enqueue_by=enqueue_by,
        ).credit_id
        self.assertIn(credit_id, registry.authorizations)
        self.assertIn(credit_id, bridge.credits)
        self.assertEqual(bridge.balance, 13)
        self.assertEqual(bridge.total_live_liability, 13)
        self.assertFalse(hasattr(registry, "balance"))
        self.assertFalse(hasattr(registry, "credits"))
        self.assertIs(registry.source_bridge, bridge)
        second = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=13,
            clock=clock,
            enqueue_by=enqueue_by,
        )
        self.assertNotEqual(second.credit_id, credit_id)
        self.assertEqual(second.envelope.message.message_id, 1)
        self.assertEqual(len(registry.authorizations), 2)
        self.assertEqual(bridge.balance, 26)
        self.assertEqual(bridge.total_live_liability, 26)
        with self.assertRaises(ValueError):
            settlement.SourceBridgeV2(
                registry,
                source_descriptor=bridge.source_descriptor,
                address=bridge.address,
            )

    def test_source_read_abis_are_exact_and_fail_before_enqueue(self):
        bridge = self.source_bridge
        registry = bridge.credit_registry
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "exact-source-reads",
            value=4,
            fee=2,
            liquidity_fee=3,
        )
        receipt = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=9,
            clock=clock,
            enqueue_by=(
                self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
            ),
        )
        credit_word = settlement._model_fixed_bytes32(receipt.credit_id)
        authorization_call = (
            settlement.CREDIT_AUTHORIZATION_SELECTOR + credit_word
        )
        liability_call = settlement.CREDIT_LIABILITY_SELECTOR + credit_word
        authorization_return = registry.credit_authorization_v2(
            authorization_call, gas=settlement.SOURCE_READ_GAS
        )
        liability_return = bridge.credit_liability_v2(
            liability_call, gas=settlement.SOURCE_READ_GAS
        )
        self.assertEqual(
            (
                settlement.CREDIT_AUTHORIZATION_SELECTOR.hex(),
                settlement.CREDIT_LIABILITY_SELECTOR.hex(),
                len(authorization_call),
                len(liability_call),
                len(authorization_return),
                len(liability_return),
            ),
            ("05ecb6c2", "c978978a", 36, 36, 576, 288),
        )
        self.assertIsNone(registry.credit_authorization_v2(
            b"\x00" * 36, gas=settlement.SOURCE_READ_GAS
        ))
        self.assertIsNone(bridge.credit_liability_v2(
            liability_call + b"\x00", gas=settlement.SOURCE_READ_GAS
        ))

        def assert_rejected_before_mutation():
            before = (
                copy.deepcopy(self.router.forced_queue),
                copy.deepcopy(dict(bridge.credits)),
                copy.deepcopy(self.bridge_adapter.records),
            )
            with self.assertRaises(ValueError):
                self.bridge_adapter.enqueue(
                    clock,
                    envelope=receipt.envelope,
                    caller=addr("source-read-relayer"),
                    deposit=receipt.envelope.prepaid,
                )
            self.assertEqual(self.router.forced_queue, before[0])
            self.assertEqual(bridge.credits, before[1])
            self.assertEqual(self.bridge_adapter.records, before[2])

        for target, attribute, malformed in (
            (registry, "credit_authorization_return_override",
             authorization_return[:-1]),
            (registry, "credit_authorization_return_override",
             authorization_return + b"\x00"),
            (registry, "credit_authorization_return_override",
             bytes([authorization_return[0] ^ 1])
             + authorization_return[1:]),
            (bridge, "credit_liability_return_override",
             liability_return[:-1]),
            (bridge, "credit_liability_return_override",
             liability_return + b"\x00"),
            (bridge, "credit_liability_return_override",
             liability_return[:96] + b"\x01"
             + liability_return[97:]),
            (registry, "component_config_return_override", b"x" * 31),
            (bridge, "component_config_return_override", b"x" * 33),
        ):
            with self.subTest(target=type(target).__name__, size=len(malformed)):
                setattr(target, attribute, malformed)
                assert_rejected_before_mutation()
                setattr(target, attribute, None)

        balance = bridge.balance
        bridge.balance = bridge.total_live_liability - 1
        assert_rejected_before_mutation()
        bridge.balance = balance
        liability = bridge._total_live_liability
        bridge._total_live_liability = 1
        assert_rejected_before_mutation()
        bridge._total_live_liability = liability
        self.assertEqual(self.bridge_adapter.enqueue(
            clock,
            envelope=receipt.envelope,
            caller=addr("source-read-relayer"),
            deposit=receipt.envelope.prepaid,
        ), "QUEUED:0")

    def test_message_gas_reserve_and_zero_settlement_boundaries(self):
        with self.assertRaises(ValueError):
            settlement.bridge_message(
                self.clock.l2_slot,
                "at-reserve",
                value=1,
                fee=1,
                gas_limit=settlement.V2_POST_CALL_GAS_RESERVE,
            )
        above = settlement.bridge_message(
            self.clock.l2_slot,
            "above-reserve",
            value=1,
            fee=1,
            gas_limit=settlement.V2_POST_CALL_GAS_RESERVE + 1,
        )
        self.assertEqual(
            above.bridge_gas_limit,
            settlement.V2_POST_CALL_GAS_RESERVE + 1,
        )
        with self.assertRaises(ValueError):
            settlement.bridge_message(
                self.clock.l2_slot,
                "zero-gas-with-fee",
                value=1,
                fee=1,
                gas_limit=0,
            )
        self.assertEqual(settlement.bridge_message(
            self.clock.l2_slot,
            "zero-gas-value",
            value=1,
            fee=0,
            gas_limit=0,
        ).bridge_value, 1)
        with self.assertRaises(ValueError):
            settlement.bridge_message(
                self.clock.l2_slot,
                "zero-settlement",
                value=0,
                fee=0,
                gas_limit=0,
            )

    def test_registration_commitment_and_mpt_abi_are_exact(self):
        manifest = self.destination_manifest
        registration_preimage = b"".join((
            manifest.protocol_version.to_bytes(8, "big"),
            manifest.commitment,
            manifest.destination_chain_id.to_bytes(32, "big"),
            settlement._model_fixed_bytes32(
                manifest.destination_namespace
            ),
            settlement._model_fixed_bytes32(
                manifest.destination_domain_id
            ),
            settlement._model_address20(manifest.destination_bridge),
            settlement._model_fixed_bytes32(
                manifest.destination_infrastructure_hash
            ),
            settlement._model_fixed_bytes32(
                manifest.execution_profile_hash
            ),
        ))
        self.assertEqual(len(registration_preimage), 220)
        self.assertEqual(
            manifest.registration_commitment,
            settlement.keccak256(
                settlement.D_DESTINATION_REGISTRATION
                + registration_preimage
            ),
        )
        for index in range(8):
            words = list((
                manifest.protocol_version,
                manifest.commitment,
                manifest.destination_chain_id,
                manifest.destination_namespace,
                manifest.destination_domain_id,
                manifest.destination_bridge,
                manifest.destination_infrastructure_hash,
                manifest.execution_profile_hash,
            ))
            words[index] = (
                words[index] + 1 if type(words[index]) is int
                else b"x" * 32 if type(words[index]) is bytes
                else str(words[index]) + ":substituted"
            )
            encoded = b"".join((
                int(words[0]).to_bytes(8, "big"),
                settlement._model_fixed_bytes32(words[1]),
                int(words[2]).to_bytes(32, "big"),
                settlement._model_fixed_bytes32(words[3]),
                settlement._model_fixed_bytes32(words[4]),
                settlement._model_address20(words[5]),
                settlement._model_fixed_bytes32(words[6]),
                settlement._model_fixed_bytes32(words[7]),
            ))
            self.assertNotEqual(
                settlement.keccak256(
                    settlement.D_DESTINATION_REGISTRATION + encoded
                ),
                manifest.registration_commitment,
            )

        statement = settlement.RegistrationStorageStatement(
            1,
            self.router.address,
            self.credit_registry.domain_registry.address,
            settlement.registration_route_key(
                self.source_bridge.source_domain_id,
                self.source_bridge.frozen_bridge_execution_hash,
                manifest.destination_domain_id,
            ),
            manifest.destination_chain_id,
            manifest.protocol_version,
            0,
            "state-root:test",
            "terminal-domain-registrar",
            "code:registrar",
            settlement.terminal_registration_storage_trie_key(
                manifest.protocol_version
            ),
            manifest.registration_commitment,
        )
        verifier = (
            self.credit_registry.domain_registry.registration_mpt_verifier
        )
        proof = settlement.issue_registration_mpt_proof_for_test(
            verifier,
            statement,
            account_nodes=(b"a" * 600,),
            storage_nodes=(b"b" * 600,),
        )
        calldata = settlement.registration_verifier_calldata(
            statement, proof
        )
        self.assertEqual(calldata[:4], bytes.fromhex("33639818"))
        self.assertEqual(int.from_bytes(
            calldata[4 + 12 * 32:4 + 13 * 32], "big"
        ), 0x1A0)
        self.assertEqual(
            len(verifier.verify_membership(statement, proof).returndata), 32
        )
        with self.assertRaises(ValueError):
            settlement.issue_registration_mpt_proof_for_test(
                verifier,
                statement,
                account_nodes=(b"a" * 601,),
                storage_nodes=(b"b",),
            )
        verifier.verification_gas_limit = 8_000_001
        with self.assertRaises(ValueError):
            verifier.verify_membership(statement, proof)
        verifier.verification_gas_limit = 8_000_000
        verifier.calldata_override = bytes(4) + calldata[4:]
        with self.assertRaises(ValueError):
            verifier.verify_membership(statement, proof)
        verifier.calldata_override = None

    def test_liquidity_fee_is_outside_legacy_message_hash_but_inside_credit(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "fee-separation",
            value=4,
            fee=2,
            liquidity_fee=3,
        )
        higher_fee = replace(envelope, liquidity_fee=4)
        self.assertEqual(
            settlement.bridge_message_hash(envelope),
            settlement.bridge_message_hash(higher_fee),
        )
        self.assertNotEqual(
            bridge.credit_id_for(envelope, clock),
            bridge.credit_id_for(higher_fee, clock),
        )
        receipt = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=9,
            clock=clock,
            enqueue_by=self.clock.timestamp
            + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        )
        self.assertEqual(
            bridge.credit_registry.authorizations[
                receipt.credit_id
            ].liquidity_fee,
            3,
        )
        self.assertEqual(self.bridge_adapter.enqueue(
            clock,
            envelope=receipt.envelope,
            caller=addr("relayer"),
            deposit=receipt.envelope.prepaid,
        ), "QUEUED:0")
        descriptor = self.router.forced_queue.descriptors[0]
        self.assertIsInstance(descriptor, settlement.BridgeQueueDescriptorV11)
        self.assertEqual(descriptor.bridge_liquidity_fee, 3)

    def test_source_send_late_registry_and_bridge_faults_are_atomic(self):
        for fault_owner, fault_point in (
            ("registry", "after_authorization_write"),
            ("bridge", "after_registry_write"),
            ("bridge", "after_liability_write"),
        ):
            with self.subTest(fault_owner=fault_owner, fault_point=fault_point):
                protocol, manager = migration_manager_fixture(seat=False)
                bridge = settlement.source_bridge_for_test(manager.router)
                registry = bridge.credit_registry
                clock = bridge.support_final_clock(
                    settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
                )
                envelope = settlement.bridge_message(
                    protocol.core.tip_slot,
                    f"atomic-{fault_point}",
                    value=3,
                    fee=1,
                )
                enqueue_by = (
                    settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
                    + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                )
                registry_before = dict(registry.authorizations)
                bridge_before = bridge._transaction_snapshot()
                if fault_owner == "registry":
                    registry.fault_point = fault_point
                else:
                    bridge.fault_point = fault_point
                with self.assertRaises(RuntimeError):
                    bridge.send_message(
                        envelope,
                        caller=envelope.sender,
                        msg_value=5,
                        clock=clock,
                        enqueue_by=enqueue_by,
                    )
                self.assertEqual(registry.authorizations, registry_before)
                self.assertEqual(bridge._transaction_snapshot(), bridge_before)
                registry.fault_point = None
                bridge.fault_point = None
                credit_id = bridge.send_message(
                    envelope,
                    caller=envelope.sender,
                    msg_value=5,
                    clock=clock,
                    enqueue_by=enqueue_by,
                ).credit_id
                self.assertIn(credit_id, registry.authorizations)
                self.assertEqual(bridge.credits[credit_id].status, "NEW")

    def test_same_address_source_bridge_clone_cannot_mint_authorization(self):
        bridge = self.source_bridge
        registry = self.credit_registry
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "exact-source-capability",
            value=1,
            fee=1,
        )
        credit_id = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=3,
            clock=clock,
            enqueue_by=self.clock.timestamp
            + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        ).credit_id
        authorization = registry.authorizations[credit_id]
        forged_bridge = copy.copy(bridge)
        self.assertEqual(forged_bridge.address, bridge.address)
        self.assertIsNot(forged_bridge, bridge)
        before = dict(registry.authorizations)
        self.assertFalse(
            registry._authorize_from_source_bridge(
                credit_id + ":forged",
                authorization,
                source_bridge=forged_bridge,
            )
        )
        self.assertEqual(registry.authorizations, before)
        with self.assertRaises(TypeError):
            registry.authorizations[credit_id + ":public-write"] = authorization

    def test_source_send_normalizes_fields_with_fresh_v2_counter(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        enqueue_by = self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        raw = settlement.bridge_message(
            self.clock.l2_slot,
            "normalize-eoa",
            bridge_from=addr("ignored-from"),
            message_id=settlement.UINT64_MAX,
            source_chain_id=77,
            value=3,
            fee=1,
        )
        external_caller = addr("eoa-user")
        receipt = bridge.send_message(
            raw,
            caller=external_caller,
            msg_value=5,
            clock=clock,
            enqueue_by=enqueue_by,
        )
        self.assertIsInstance(receipt, settlement.SourceSendReceipt)
        normalized = receipt.envelope.message
        self.assertEqual(normalized.message_id, 0)
        self.assertEqual(normalized.sender, external_caller)
        self.assertEqual(normalized.source_chain_id, bridge.source_chain_id)
        self.assertNotEqual(normalized.sender, bridge.address)
        self.assertEqual(
            receipt.msg_hash,
            settlement.bridge_message_hash(receipt.envelope),
        )

        followup = bridge.send_message(
            raw,
            caller=addr("second-v2-user"),
            msg_value=5,
            clock=clock,
            enqueue_by=enqueue_by,
        )
        self.assertEqual(followup.envelope.message.message_id, 1)
        self.assertEqual(bridge.next_message_id, 2)
        before = bridge._transaction_snapshot()
        with self.assertRaises(ValueError):
            bridge.send_message(
                raw,
                caller=settlement.V1_OFFICIAL_VAULT_ADDRESSES[0],
                msg_value=5,
                clock=clock,
                enqueue_by=enqueue_by,
            )
        self.assertEqual(bridge._transaction_snapshot(), before)

    def test_v2_direct_launch_has_no_asset_or_capsule_surface(self):
        for name in (
            "BridgeVaultOutflowAuthorizationV2",
            "VaultAssetIntentV2",
            "RefundVaultLedger",
            "RefundRestorableToken",
            "vault_destination_calldata",
            "refund_capsule_hash",
        ):
            self.assertFalse(hasattr(settlement, name), name)
        for name in (
            "send_message_from_vault",
            "finalize_capsule_from_vault",
            "execute_vault_outflow",
        ):
            self.assertFalse(hasattr(self.source_bridge, name), name)
        self.assertEqual(
            settlement.source_send_mode("sendMessageFromVaultV2(Message)"),
            "REJECTED",
        )

    def test_source_rejects_every_manifest_privileged_target_atomically(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        support = bridge.domain_registry.latest_final_entry(
            self.destination_manifest.destination_chain_id, clock
        )
        self.assertIsNotNone(support)
        denyset = (
            support.manifest.destination_bridge_descriptor
                .privileged_target_denyset
        )
        self.assertIn("signal-service", denyset)
        self.assertIn("delegate-controller", denyset)
        self.assertIn(
            support.manifest.destination_bridge_descriptor
                .native_quota_manager,
            denyset,
        )
        self.assertIn(
            support.manifest.destination_bridge_descriptor
                .deployment_descriptor.pauser,
            denyset,
        )
        for index, target in enumerate(denyset):
            with self.subTest(target=target):
                envelope = settlement.bridge_message(
                    self.clock.l2_slot,
                    f"deny:{index}",
                    to=target,
                    fee=0,
                    gas_limit=0,
                    value=1,
                    data=b"forged-privileged-call",
                )
                bridge_before = bridge._transaction_snapshot()
                registry_before = dict(
                    bridge.credit_registry.authorizations
                )
                with self.assertRaises(ValueError):
                    bridge.send_message(
                        envelope,
                        caller=addr("ordinary-user"),
                        msg_value=2,
                        clock=clock,
                        enqueue_by=(
                            self.clock.timestamp
                            + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                        ),
                    )
                self.assertEqual(bridge._transaction_snapshot(), bridge_before)
                self.assertEqual(
                    bridge.credit_registry.authorizations,
                    registry_before,
                )

    def test_destination_privileged_defense_fails_without_payout_or_quota(self):
        descriptor = self.destination_manifest.destination_bridge_descriptor
        privileged_receivers = {
            target: settlement.BridgeCallReceiverV2(target)
            for target in (
                "signal-service",
                descriptor.native_quota_manager,
                "delegate-controller",
                descriptor.deployment_descriptor.pauser,
            )
        }
        for receiver in privileged_receivers.values():
            self.assertTrue(
                self.destination_environment.deploy_application(receiver)
            )
        for index, target in enumerate(descriptor.privileged_target_denyset):
            with self.subTest(target=target):
                delivery = self.destination_delivery(
                    f"hard-deny-{index}",
                    to=target,
                    value=3,
                    fee=2,
                    data=settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"x",
                )
                credit_id = settlement.destination_credit_id_v2(*delivery)
                pool = self.destination_bridge.liquidity_pool
                reservation = pool.reservations[credit_id]
                ticket_id = reservation.ticket_id
                reserved_before = pool.reserved_count(
                    self.destination_bridge.local_domain_id
                )
                pool_balance_before = pool.balance
                before = (
                    self.destination_bridge.balance,
                    self.destination_bridge.ether_quota,
                    dict(self.destination_bridge.pull_credits),
                )
                receiver = privileged_receivers.get(target)
                receiver_before = (
                    None if receiver is None
                    else receiver._transaction_snapshot()
                )
                self.destination_environment.block_timestamp = (
                    self.clock.timestamp + 1
                )
                self.assertEqual(self.destination_bridge.process(
                    *delivery, caller=addr("relayer")
                ), "FAILED")
                self.assertNotIn(credit_id, pool.reservations)
                self.assertEqual(pool.tickets[ticket_id].state, "AVAILABLE")
                self.assertEqual(
                    pool.reserved_count(self.destination_bridge.local_domain_id),
                    reserved_before - 1,
                )
                self.assertEqual(pool.balance, pool_balance_before)
                self.assertEqual(
                    (
                        self.destination_bridge.balance,
                        self.destination_bridge.ether_quota,
                        self.destination_bridge.pull_credits,
                    ),
                    before,
                )
                if receiver is not None:
                    self.assertEqual(
                        receiver._transaction_snapshot(), receiver_before
                    )

    def test_non_invocable_selector_is_done_and_value_becomes_owner_pull(self):
        delivery = self.destination_delivery(
            "wrong-selector",
            value=9,
            fee=0,
            gas_limit=0,
            data=b"\xde\xad\xbe\xefpayload",
        )
        received_before = list(self.destination_receiver.received)
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(self.destination_receiver.received, received_before)
        self.assertEqual(
            sum(self.destination_bridge.pull_credits.values()), 9
        )
        self.assertEqual(
            self.destination_bridge.pull_credits[
                delivery[0].destination_owner
            ],
            9,
        )
        self.assertEqual(
            self.destination_bridge.balance,
            2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR + 9,
        )
        retry_delivery = self.destination_delivery(
            "wrong-selector-retry-last",
            value=1,
            fee=0,
            gas_limit=0,
            data=b"\xca\xfe\xba\xbepayload",
        )
        retry_credit = settlement.destination_credit_id_v2(*retry_delivery)
        settlement.set_destination_v2_accounting_for_test(
            self.destination_bridge,
            status={
                **dict(self.destination_bridge.status),
                retry_credit: "RETRIABLE",
            },
        )
        self.assertEqual(self.destination_bridge.retry(
            *retry_delivery,
            caller=addr("public-finalizer"),
            is_last_attempt=True,
        ), "DONE")

    def test_unknown_eoa_and_short_fallback_are_permissionless(self):
        target = addr("new-eoa")
        delivery = self.destination_delivery(
            "eoa-short",
            to=target,
            value=4,
            fee=0,
            data=b"\x01\x02\x03",
        )
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(self.destination_environment.eoa_balances[target], 4)
        self.assertNotIn(
            target, self.destination_environment._applications_by_address
        )

    def test_empty_message_call_boundaries_match_bridge_semantics(self):
        receiver = self.destination_receiver
        received_before = list(receiver.received)
        zero_empty = self.destination_delivery(
            "zero-empty", to=receiver.address, value=0, fee=1, data=b""
        )
        self.assertEqual(self.destination_bridge.process(
            *zero_empty, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(receiver.received, received_before)

        value_empty = self.destination_delivery(
            "value-empty", to=receiver.address, value=1, fee=0, data=b""
        )
        self.assertEqual(self.destination_bridge.process(
            *value_empty, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(len(receiver.received), len(received_before) + 1)
        for length in (1, 2, 3):
            delivery = self.destination_delivery(
                f"short-{length}",
                to=receiver.address,
                value=0,
                fee=1,
                data=b"x" * length,
            )
            self.assertEqual(self.destination_bridge.process(
                *delivery, caller=addr("relayer")
            ), "DONE")
        self.assertEqual(len(receiver.received), len(received_before) + 4)

    def test_insolvent_destination_never_calls_target(self):
        delivery = self.destination_delivery(
            "pre-call-solvency", value=8, fee=3,
            fund_liquidity=False,
        )
        receiver_before = self.destination_receiver._transaction_snapshot()
        bridge_before = self.destination_bridge._transaction_snapshot()
        self.destination_bridge.balance = 10
        settlement.set_bridge_eth_quota_available_for_test(
            self.destination_bridge, 11
        )
        settlement.set_destination_v2_accounting_for_test(
            self.destination_bridge,
            pull_credits={addr("prior-owner"): 1},
            total_liability=1,
        )
        capacity_before = self.destination_bridge._transaction_snapshot()
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "UNFUNDED")
        self.assertEqual(
            self.destination_receiver._transaction_snapshot(), receiver_before
        )
        self.assertEqual(
            self.destination_bridge._transaction_snapshot(), capacity_before
        )
        settlement.restore_destination_bridge_snapshot_for_test(
            self.destination_bridge, bridge_before
        )

    def test_exact_liability_plus_value_fee_calls_once_without_double_debit(self):
        delivery = self.destination_delivery(
            "exact-v-plus-f", value=8, fee=3
        )
        prior_owner = addr("prior-owner")
        settlement.set_destination_v2_accounting_for_test(
            self.destination_bridge,
            pull_credits={prior_owner: 5},
            total_liability=5,
        )
        self.destination_bridge.balance = 5 + 8 + 3
        settlement.set_bridge_eth_quota_available_for_test(
            self.destination_bridge, 11
        )
        observed_during_call = []
        self.destination_receiver.callback = lambda bridge: (
            observed_during_call.append(bridge.balance)
        )
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(observed_during_call, [19])
        self.assertEqual(self.destination_bridge.balance, 19)
        self.assertEqual(self.destination_bridge.total_pull_liability, 5 + 3)
        self.assertEqual(self.destination_bridge.ether_quota, 0)

        one_short = self.destination_delivery(
            "one-short-v-plus-f", value=8, fee=3,
            fund_liquidity=False,
        )
        receiver_before = self.destination_receiver._transaction_snapshot()
        self.destination_bridge.balance = (
            self.destination_bridge.total_pull_liability + 10
        )
        settlement.set_bridge_eth_quota_available_for_test(
            self.destination_bridge, 11
        )
        bridge_before = self.destination_bridge._transaction_snapshot()
        self.assertEqual(self.destination_bridge.process(
            *one_short, caller=addr("relayer")
        ), "UNFUNDED")
        self.assertEqual(
            self.destination_receiver._transaction_snapshot(), receiver_before
        )
        self.assertEqual(
            self.destination_bridge._transaction_snapshot(), bridge_before
        )

    def test_dynamic_app_contexts_are_exact_and_clear_on_every_exit(self):
        app = settlement.BridgeCallReceiverV2(addr("created-app"))
        self.assertTrue(self.destination_environment.deploy_application(app))
        delivery = self.destination_delivery("context-ok", to=app.address)
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(len(app.observed_legacy_contexts), 1)
        self.assertEqual(len(app.observed_v2_contexts), 1)
        observed_v2 = app.observed_v2_contexts[0]
        self.assertEqual(
            observed_v2,
            settlement.BridgeInvocationContextV2(
                self.destination_manifest.protocol_version,
                "V2_DIRECT",
                settlement.destination_credit_id_v2(*delivery),
                settlement.bridge_message_hash(delivery[0]),
                delivery[1].source_domain_id,
                delivery[1].source_registration_epoch,
                delivery[1].source_bridge,
                delivery[1].bridge_execution_hash,
                delivery[1].emitted_at_block,
                delivery[2].queue_index,
                delivery[2].destination_domain_id,
                delivery[2].destination_bridge,
                self.destination_manifest.commitment,
                self.destination_manifest.execution_profile_hash,
            ),
        )
        with self.assertRaises(ValueError):
            self.destination_environment.read_bridge_context_v2()
        self.assertIsNone(self.destination_environment.legacy_bridge_context)
        self.assertIsNone(self.destination_environment.bridge_context_v2)

        failing = self.destination_delivery("context-revert", to=app.address)
        snapshot = app._transaction_snapshot()
        app.fault_point = "revert"
        self.assertEqual(self.destination_bridge.process(
            *failing, caller=addr("relayer")
        ), "NEW")
        self.assertEqual(app._transaction_snapshot(), snapshot)
        self.assertIsNone(self.destination_environment.legacy_bridge_context)
        self.assertIsNone(self.destination_environment.bridge_context_v2)

    def test_future_bridge_trusting_endpoint_rejects_historical_context(self):
        future_address = addr("future-app")
        old_delivery = self.destination_delivery(
            "predeploy-future-credit", to=future_address, value=0, fee=1
        )
        future_policy = settlement.BridgeInvocationPolicyV2(
            self.destination_manifest.protocol_version + 1,
            "V2_DIRECT",
            old_delivery[1].source_domain_id,
            old_delivery[1].source_registration_epoch + 1,
            old_delivery[1].source_bridge,
            old_delivery[1].bridge_execution_hash,
            old_delivery[1].emitted_at_block + 1,
            "domain:future",
            "bridge:future",
            b"\x11" * 32,
            "profile:future",
        )
        newly_deployed = settlement.BridgeCallReceiverV2(
            future_address, required_v2_policy=future_policy
        )
        self.assertTrue(self.destination_environment.deploy_application(
            newly_deployed
        ))
        self.assertEqual(self.destination_bridge.process(
            *old_delivery, caller=addr("relayer")
        ), "NEW")
        self.assertEqual(newly_deployed.received, [])

        new_store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:future", ""
        )
        new_manifest = settlement.release_manifest_fixture(
            93, "", "bridge:future", new_store, router=self.router
        )
        new_accumulator = settlement.TerminalAccumulatorV2({
            new_manifest.destination_domain_id:
                new_manifest.destination_bridge,
        })
        new_message = replace(
            old_delivery[0],
            message_id=9_301,
            destination_chain_id=new_manifest.destination_chain_id,
            to=future_address,
        )
        new_route = settlement.DestinationContextV2(
            new_manifest.destination_chain_id,
            new_manifest.destination_domain_id,
            new_manifest.destination_bridge,
            new_manifest.commitment,
            new_manifest.execution_profile_hash,
            9_301,
        )
        new_source_template = settlement.SourceContextV2(
            new_manifest.protocol_version,
            settlement.ForceKind.BRIDGE_CREDIT.value,
            "",
            settlement.bridge_message_hash(new_message),
            old_delivery[1].source_domain_id,
            old_delivery[1].source_registration_epoch + 1,
            old_delivery[1].source_bridge,
            old_delivery[1].bridge_execution_hash,
            old_delivery[1].emitted_at_block + 1,
            new_route.queue_index,
            old_delivery[1].enqueue_by,
            "DIRECT",
            "",
            "",
            "",
        )
        new_policy = settlement.BridgeInvocationPolicyV2(
            new_manifest.protocol_version,
            "V2_DIRECT",
            new_source_template.source_domain_id,
            new_source_template.source_registration_epoch,
            new_source_template.source_bridge,
            new_source_template.bridge_execution_hash,
            new_source_template.emitted_at_block,
            new_manifest.destination_domain_id,
            new_manifest.destination_bridge,
            new_manifest.commitment,
            new_manifest.execution_profile_hash,
        )
        new_receiver = settlement.BridgeCallReceiverV2(
            future_address, required_v2_policy=new_policy
        )
        new_bridge = settlement.destination_bridge_for_test(
            new_manifest,
            new_store,
            new_accumulator,
            applications=(new_receiver,),
            balance=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            quota=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            timestamp=self.clock.timestamp + 1,
        )
        new_credit = settlement.destination_credit_id_v2(
            new_message, replace(new_source_template, credit_id=""), new_route,
            liquidity_fee=1,
        )
        new_source = replace(
            new_source_template,
            escrow_id=settlement.bridge_escrow_id(new_credit),
            credit_id=new_credit,
        )
        self.assertTrue(settlement.install_destination_pin_for_test(
            new_bridge,
            new_message,
            new_source,
            new_route,
            now=self.clock.timestamp,
        ))
        self.assertTrue(settlement.reserve_destination_liquidity_for_test(
            new_bridge,
            new_message,
            new_source,
            new_route,
            now=self.clock.timestamp,
        ))
        self.assertEqual(new_bridge.process(
            new_message,
            new_source,
            new_route,
            caller=addr("relayer"),
        ), "DONE")
        self.assertEqual(len(new_receiver.observed_v2_contexts), 1)

    def test_fresh_v2_accounts_cannot_alias_legacy_v1_state(self):
        legacy_v1 = {
            "source_address": settlement.LEGACY_V1_SOURCE_BRIDGE,
            "destination_address": "legacy-bridge:destination:A",
            "balance": 41,
            "next_message_id": 73,
            "quota": (9, 20, 7),
            "status": {"legacy-credit": "RETRIABLE"},
            "entered": False,
        }
        before = copy.deepcopy(legacy_v1)
        self.assertNotEqual(
            self.source_bridge.address, legacy_v1["source_address"]
        )
        self.assertEqual(
            self.source_bridge.source_descriptor.legacy_v1_bridge,
            legacy_v1["source_address"],
        )
        self.assertNotEqual(
            self.destination_bridge.address,
            legacy_v1["destination_address"],
        )
        delivery = self.destination_delivery("fresh-v2-isolation")
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(legacy_v1, before)

    def test_eip150_threshold_and_callee_oog_are_distinct(self):
        delivery = self.destination_delivery("gas-threshold")
        message = delivery[0]
        requested = self.destination_bridge._invocation_gas_limit(message)
        threshold = self.destination_bridge._required_available_gas(
            message, requested
        )
        self.destination_environment.available_gas = threshold - 1
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "REJECTED")
        self.assertNotIn(
            settlement.destination_credit_id_v2(*delivery),
            self.destination_bridge.status,
        )
        self.destination_environment.available_gas = threshold
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")

        oog = self.destination_delivery("callee-oog")
        self.destination_receiver.exhausts_forwarded_gas = True
        self.destination_environment.available_gas = 10_000_000
        self.assertEqual(self.destination_bridge.process(
            *oog, caller=addr("relayer")
        ), "NEW")
        self.assertNotIn(
            settlement.destination_credit_id_v2(*oog),
            self.destination_bridge.status,
        )

    def test_v2_fee_is_success_only_and_retry_earns_the_bounty(self):
        delivery = self.destination_delivery(
            "success-bounty", value=5, fee=9
        )
        balance = self.destination_bridge.balance
        quota = self.destination_bridge.ether_quota
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "NEW")
        self.assertEqual(self.destination_bridge.total_pull_liability, 0)
        self.assertEqual(
            (self.destination_bridge.balance,
             self.destination_bridge.ether_quota),
            (balance, quota),
        )
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=delivery[0].destination_owner
        ), "RETRIABLE")
        self.assertEqual(self.destination_bridge.total_pull_liability, 0)
        self.destination_receiver.fault_point = None
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=addr("retry-relayer"), is_last_attempt=False
        ), "DONE")
        self.assertEqual(self.destination_bridge.total_pull_liability, 9)
        self.assertEqual(
            self.destination_bridge.pull_credits[addr("retry-relayer")], 9
        )
        self.assertNotIn(
            delivery[0].destination_owner,
            self.destination_bridge.pull_credits,
        )
        self.assertEqual(self.destination_bridge.balance, balance + 9)
        self.assertEqual(self.destination_bridge.ether_quota, quota - 14)

        owner_delivery = self.destination_delivery(
            "owner-success-bounty", value=0, fee=4, data=b""
        )
        owner = owner_delivery[0].destination_owner
        self.assertEqual(self.destination_bridge.process(
            *owner_delivery, caller=owner
        ), "DONE")
        self.assertEqual(self.destination_bridge.pull_credits[owner], 4)
        self.assertEqual(self.destination_bridge.process(
            *owner_delivery, caller=addr("racing-relayer")
        ), "REJECTED")
        self.assertNotIn(
            addr("racing-relayer"), self.destination_bridge.pull_credits
        )

    def test_pull_withdrawal_has_recipient_retry_and_reentrancy_guard(self):
        delivery = self.destination_delivery(
            "pull-credit", value=7, fee=1,
            data=b"\xaa\xbb\xcc\xdd",
        )
        owner = delivery[0].destination_owner
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        claim = self.destination_bridge.pull_credits[owner]
        recipient = settlement.BridgeCallReceiverV2(addr("pull-recipient"))
        self.assertTrue(self.destination_environment.deploy_application(
            recipient
        ))
        recipient.fault_point = "receive_revert"
        self.assertEqual(self.destination_bridge.withdraw_pull_credit(
            owner, recipient.address
        ), 0)
        self.assertEqual(self.destination_bridge.pull_credits[owner], claim)
        recipient.fault_point = None
        nested = []
        recipient.callback = lambda bridge: nested.append(
            bridge.withdraw_pull_credit(owner, addr("nested"))
        )
        self.assertEqual(self.destination_bridge.withdraw_pull_credit(
            owner, recipient.address
        ), claim)
        self.assertEqual(nested, [0])
        self.assertNotIn(owner, self.destination_bridge.pull_credits)
        self.assertEqual(recipient.native_balance, claim)

    def test_queued_source_liability_keeps_value_and_fee_reserved(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot, "queued-full-liability", value=10, fee=2
        )
        receipt = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=13,
            clock=clock,
            enqueue_by=self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        )
        self.assertEqual(bridge.total_live_liability, 13)
        self.assertEqual(self.bridge_adapter.enqueue(
            clock,
            envelope=receipt.envelope,
            caller=addr("relayer"),
            deposit=receipt.envelope.prepaid,
        ), "QUEUED:0")
        self.assertEqual(bridge.total_live_liability, 13)
        self.assertFalse(hasattr(bridge, "ordinary_payout"))

    def test_source_refund_recipient_failure_retries_unpaused_and_cei(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "source-refund-recipient",
            src_owner=addr("refund-owner"),
            value=7,
            fee=3,
        )
        receipt = bridge.send_message(
            envelope,
            caller=addr("refund-owner"),
            msg_value=11,
            clock=clock,
            enqueue_by=self.clock.timestamp
            + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        )
        authorization = bridge.credit_registry.authorizations[
            receipt.credit_id
        ]
        self.assertTrue(bridge.cancel(
            receipt.credit_id, now=authorization.enqueue_by + 1
        ))
        receiver = settlement.SourceNativeReceiverV2(
            addr("rejecting-refund"), rejects_native=True
        )
        self.assertTrue(bridge.native_environment.deploy_receiver(receiver))
        self.assertTrue(bridge.set_paused(
            True,
            caller=bridge.source_descriptor.deployment_descriptor.pauser,
            chain_id=bridge.source_chain_id,
        ))
        before = bridge._transaction_snapshot()
        self.assertEqual(bridge.withdraw_refund(
            addr("attacker"), addr("attacker")
        ), 0)
        self.assertEqual(bridge._transaction_snapshot(), before)
        self.assertEqual(bridge.withdraw_refund(
            addr("refund-owner"), receiver.address
        ), 0)
        self.assertEqual(bridge._transaction_snapshot(), before)
        nested = []
        receiver.rejects_native = False
        receiver.callback = lambda exact_bridge: nested.append(
            exact_bridge.withdraw_refund(
                addr("refund-owner"), addr("nested-recipient")
            )
        )
        self.assertEqual(bridge.withdraw_refund(
            addr("refund-owner"), receiver.address
        ), 11)
        self.assertEqual(nested, [0])
        self.assertEqual(receiver.balance, 11)
        self.assertEqual(bridge.total_live_liability, 0)
        self.assertEqual(bridge.balance, 0)

    def test_fresh_source_and_destination_have_independent_state_and_locks(self):
        source = self.source_bridge
        destination = self.destination_bridge
        source_before = (
            source.next_message_id, source.balance, source.total_live_liability
        )
        destination_before = (
            destination.balance, destination.total_pull_liability
        )

        # A frame in one fresh Bridge cannot lock or mutate the other Bridge.
        source.entered = True
        try:
            delivery = self.destination_delivery("independent-destination")
            self.assertEqual(destination.process(
                *delivery, caller=addr("relayer")
            ), "DONE")
        finally:
            source.entered = False
        self.assertEqual(
            (source.next_message_id, source.balance,
             source.total_live_liability),
            source_before,
        )

        destination.entered = True
        try:
            clock = source.support_final_clock(self.clock.timestamp)
            envelope = settlement.bridge_message(
                self.clock.l2_slot,
                "independent-source",
                value=1,
                fee=1,
            )
            receipt = source.send_message(
                envelope,
                caller=envelope.sender,
                msg_value=3,
                clock=clock,
                enqueue_by=self.clock.timestamp
                + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
            )
        finally:
            destination.entered = False
        self.assertEqual(receipt.envelope.message.message_id, source_before[0])
        self.assertEqual(
            (destination.balance, destination.total_pull_liability),
            (
                destination_before[0] + delivery[0].fee,
                destination_before[1] + delivery[0].fee,
            ),
        )


    def test_native_quota_manager_refills_and_unlimited_launch_rejects(self):
        bridge = self.destination_bridge
        manager = bridge.quota_manager
        now = self.destination_environment.block_timestamp
        settlement.set_bridge_eth_quota_available_for_test(
            bridge, 0, updated_at=now
        )
        self.destination_environment.block_timestamp = (
            now + manager.quota_period // 2
        )
        self.assertEqual(
            bridge.ether_quota,
            manager.eth_quota_cap // 2,
        )
        self.destination_environment.block_timestamp = now + manager.quota_period
        self.assertEqual(
            bridge.ether_quota,
            manager.eth_quota_cap,
        )
        self.assertFalse(manager.transfer_ownership(addr("attacker")))
        self.assertFalse(manager.accept_ownership(addr("attacker")))
        self.assertFalse(manager.update_quota(1, caller=addr("attacker")))
        self.assertFalse(manager._consume_from_bridge(
            1,
            bridge=bridge,
            frame=None,
            capability=object(),
        ))
        unlimited = settlement.FrozenNativeQuotaManagerV2(
            "quota:unlimited",
            "bridge:unlimited",
            settlement.NATIVE_QUOTA_PERIOD_SECONDS,
            0,
        )
        self.assertEqual(
            unlimited.available_quota(now), settlement.UNLIMITED_QUOTA
        )
        descriptor = self.destination_manifest.destination_bridge_descriptor
        self.assertFalse(replace(
            self.destination_manifest,
            destination_bridge_descriptor=replace(
                descriptor, native_eth_quota=0
            ),
        ).structurally_valid())

    def test_source_create2_deployment_is_permissionless_and_idempotent(self):
        bridge = self.source_bridge
        factory = bridge.deployment_factory
        descriptor = bridge.source_descriptor
        first = bridge.deployment_receipt
        self.assertTrue(first.created_now)
        self.assertEqual(len(descriptor.canonical_bytes), 752)
        self.assertEqual(
            descriptor.bridge_execution_hash,
            settlement.keccak256(
                b"slot-chain-source-bridge-execution-v4"
                + (752).to_bytes(4, "big")
                + descriptor.canonical_bytes
            ).hex(),
        )
        self.assertEqual(
            len({
                descriptor.deployment_factory,
                descriptor.bundle_deployer,
                descriptor.legacy_v1_bridge,
                descriptor.source_bridge,
                descriptor.bridge_credit_registry,
                descriptor.native_quota_manager,
            }),
            6,
        )
        self.assertTrue(factory.valid_source_receipt(
            first, descriptor, self.credit_registry, bridge.quota_manager,
            bridge.terminal_verifier,
        ))
        self.assertEqual(
            descriptor.bundle_deployer,
            settlement.source_bridge_create2_address(
                descriptor.deployment_factory,
                descriptor.deployment_salt,
                descriptor.deployment_initcode_hash,
            ),
        )
        self.assertEqual(
            first.bridge,
            settlement.source_bundle_child_address(
                descriptor.bundle_deployer, 1
            ),
        )
        self.assertNotEqual(first.bridge, descriptor.legacy_v1_bridge)
        self.assertTrue(factory.immutable_nonproxy)
        self.assertTrue(factory.selfdestruct_disabled)
        self.assertEqual(
            first.configuration_hash,
            descriptor.deployment_descriptor.account_configuration_hash,
        )
        self.assertEqual(first.configuration_hash, bridge.configuration_hash)
        self.assertTrue(factory.source_bundle_exact(
            descriptor,
            self.credit_registry,
            bridge.quota_manager,
            bridge.terminal_verifier,
            bridge,
            require_live_bundle=True,
        ))
        # Receipt bytes are only a test observation.  Current-code/config
        # checks neither consume nor trust their seal.
        self.assertFalse(factory.valid_source_receipt(
            replace(first, seal="forged"),
            descriptor,
            self.credit_registry,
            bridge.quota_manager,
            bridge.terminal_verifier,
        ))
        self.assertTrue(factory.source_bundle_exact(
            descriptor,
            self.credit_registry,
            bridge.quota_manager,
            bridge.terminal_verifier,
            bridge,
            require_live_bundle=True,
        ))
        for component in (
            factory,
            bridge,
            self.credit_registry,
            bridge.quota_manager,
            self.credit_registry.domain_registry,
            bridge.terminal_verifier,
        ):
            # Test-only STATICCALL returndata fault injection must also cover
            # frozen immutable components such as TerminalSignalVerifier.
            object.__setattr__(
                component, "component_config_return_override", b"x" * 31
            )
            self.assertFalse(factory.source_bundle_exact(
                descriptor,
                self.credit_registry,
                bridge.quota_manager,
                bridge.terminal_verifier,
                bridge,
                require_live_bundle=True,
            ))
            object.__setattr__(
                component, "component_config_return_override", None
            )

        poisoned_descriptor = replace(
            descriptor,
            native_eth_quota=descriptor.native_eth_quota - 1,
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_initcode_hash="",
            bundle_deployer="",
            deployment_descriptor=None,
        )
        self.assertNotEqual(
            poisoned_descriptor.deployment_initcode_hash,
            descriptor.deployment_initcode_hash,
        )
        self.assertNotEqual(
            poisoned_descriptor.source_bridge, descriptor.source_bridge
        )
        poisoned_bridge, _, _ = factory.deploy_source_bundle(
            poisoned_descriptor,
            self.credit_registry.domain_registry,
            caller=addr("config-grinder"),
        )
        self.assertEqual(
            poisoned_bridge.address, poisoned_descriptor.source_bridge
        )
        self.assertIs(factory._bundles[descriptor.source_bridge][0], bridge)

        front_bridge, front_registry, front_run = factory.deploy_source_bundle(
            descriptor,
            self.credit_registry.domain_registry,
            caller=addr("front-runner"),
        )
        self.assertIs(front_bridge, bridge)
        self.assertIs(front_registry, self.credit_registry)
        self.assertFalse(front_run.created_now)
        self.assertTrue(factory.valid_source_receipt(
            front_run, descriptor, self.credit_registry, bridge.quota_manager,
            bridge.terminal_verifier,
        ))
        self.assertEqual(
            (
                front_run.bridge,
                front_run.salt,
                front_run.initcode_hash,
                front_run.runtime_hash,
                front_run.configuration_hash,
            ),
            (
                first.bridge,
                first.salt,
                first.initcode_hash,
                first.runtime_hash,
                first.configuration_hash,
            ),
        )

        wrong = settlement.ImmutableV2BridgeFactory(
            descriptor.deployment_factory,
            descriptor.deployment_factory_runtime_hash,
            descriptor.deployment_factory_configuration_hash,
        )
        wrong.preseed_wrong_code_for_test(
            descriptor.source_bridge,
            runtime_hash="code:attacker",
        )
        with self.assertRaises(ValueError):
            wrong.deploy_source_bundle(
                descriptor,
                self.credit_registry.domain_registry,
                caller=addr("attacker"),
            )
        self.assertFalse(factory.valid_source_receipt(
            replace(first, runtime_hash="code:attacker"),
            descriptor, self.credit_registry, bridge.quota_manager,
            bridge.terminal_verifier,
        ))
        self.assertFalse(factory.valid_source_receipt(
            replace(first, bridge=descriptor.legacy_v1_bridge),
            descriptor, self.credit_registry, bridge.quota_manager,
            bridge.terminal_verifier,
        ))
        for substituted in (
            replace(
                descriptor,
                source_bridge="bridge:attacker-selected",
                deployment_descriptor=None,
            ),
            replace(
                descriptor,
                deployment_salt="salt:attacker",
                deployment_descriptor=None,
            ),
            replace(
                descriptor,
                legacy_v1_bridge=descriptor.source_bridge,
                deployment_descriptor=None,
            ),
        ):
            with self.assertRaises(ValueError):
                substituted.descriptor_id
            with self.assertRaises(ValueError):
                factory.deploy_source_bundle(
                    substituted,
                    self.credit_registry.domain_registry,
                    caller=addr("attacker"),
                )
        for mutable_factory in (
            settlement.ImmutableV2BridgeFactory(
                descriptor.deployment_factory,
                descriptor.deployment_factory_runtime_hash,
                descriptor.deployment_factory_configuration_hash,
                immutable_nonproxy=False,
            ),
            settlement.ImmutableV2BridgeFactory(
                descriptor.deployment_factory,
                descriptor.deployment_factory_runtime_hash,
                descriptor.deployment_factory_configuration_hash,
                selfdestruct_disabled=False,
            ),
        ):
            with self.assertRaises(ValueError):
                mutable_factory.deploy_source_bundle(
                    descriptor,
                    self.credit_registry.domain_registry,
                    caller=addr("permissionless-deployer"),
                )
        with self.assertRaises(ValueError):
            replace(
                descriptor,
                deployment_descriptor=replace(
                    descriptor.deployment_descriptor,
                    account_configuration_hash="config:attacker",
                ),
            ).descriptor_id

    def test_v2_accounting_views_and_mutation_authority_are_private(self):
        source = self.source_bridge
        destination = self.destination_bridge
        with self.assertRaises(TypeError):
            source.credits["attacker"] = object()
        with self.assertRaises(TypeError):
            source.refunds["attacker"] = 1
        with self.assertRaises(TypeError):
            destination.pull_credits["attacker"] = 1
        with self.assertRaises(TypeError):
            destination.status["attacker"] = "DONE"
        self.assertFalse(hasattr(source, "accounting_ledger"))
        self.assertFalse(hasattr(destination, "accounting_ledger"))
        self.assertFalse(hasattr(source, "set_credit_status"))
        self.assertFalse(hasattr(destination, "set_pull_credit"))

    def test_release_successor_must_use_fresh_domain_and_bridge(self):
        release = self.destination_manifest
        fresh = settlement.bridge_deployment_state_for_test(release)
        self.assertTrue(fresh.authenticates(release, require_fresh=True))
        activated = replace(fresh, v2_active=True)
        self.assertFalse(activated.authenticates(
            release,
            known_identity=fresh.static_identity(release),
            require_fresh=True,
        ))
        self.assertTrue(activated.authenticates(
            release,
            known_identity=fresh.static_identity(release),
            require_fresh=False,
        ))
        successor_store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:fresh-successor", "domain:placeholder"
        )
        successor = settlement.release_manifest_fixture(
            release.protocol_version + 1,
            "domain:placeholder",
            "bridge:fresh-successor",
            successor_store,
            router=self.router,
        )
        self.assertNotEqual(
            release.destination_bridge_descriptor.native_quota_manager,
            successor.destination_bridge_descriptor.native_quota_manager,
        )
        self.assertNotEqual(
            release.destination_domain_id, successor.destination_domain_id
        )
        same_bridge = settlement.release_manifest_fixture(
            release.protocol_version + 2,
            release.destination_domain_id,
            release.destination_bridge,
            settlement.InboxCreditStoreV2(
                "inbox-apply",
                release.destination_bridge,
                release.destination_domain_id,
            ),
            router=self.router,
        )
        self.assertFalse(
            settlement.historical_v2_privileged_policy_compatible(
                release, same_bridge,
            )
        )

    def test_destination_lifetime_authority_graph_cannot_split(self):
        successor_store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:replacement", ""
        )
        successor = settlement.release_manifest_fixture(
            78,
            "",
            "bridge:replacement",
            successor_store,
            router=self.router,
        )
        self.assertTrue(
            settlement.historical_v2_privileged_policy_compatible(
                self.destination_manifest, successor
            )
        )
        for index in (3, 5, 6, 7):
            with self.subTest(component=index):
                components = list(successor.components)
                components[index] = replace(
                    components[index],
                    runtime_hash=components[index].runtime_hash + ":split",
                )
                components = tuple(components)
                split = replace(
                    successor,
                    components=components,
                    destination_infrastructure_hash=(
                        settlement.destination_infrastructure_hash(components)
                    ),
                )
                split = replace(
                    split,
                    destination_domain_id=(
                        split.canonical_destination_descriptor
                            .destination_domain_id
                    ),
                )
                self.assertTrue(split.structurally_valid())
                self.assertFalse(
                    settlement.historical_v2_privileged_policy_compatible(
                        self.destination_manifest, split
                    )
                )

        protocol, manager = migration_manager_fixture(seat=False)
        registrar = protocol.inbox_apply_router._terminal_registrar_authority
        authority = registrar.authority
        store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:replacement", ""
        )
        exact = settlement.release_manifest_fixture(
            79, "", "bridge:replacement", store, router=manager.router
        )
        components = list(exact.components)
        components[5] = replace(
            components[5], config_hash="cfg:split-authority"
        )
        components = tuple(components)
        split = replace(
            exact,
            components=components,
            destination_infrastructure_hash=(
                settlement.destination_infrastructure_hash(components)
            ),
        )
        split = replace(
            split,
            destination_domain_id=(
                split.canonical_destination_descriptor.destination_domain_id
            ),
        )
        object.__setattr__(
            store, "destination_domain_id", split.destination_domain_id
        )
        self.assertTrue(split.structurally_valid())
        self.assertFalse(settlement.execute_release_activation_for_test(
            protocol._inbox_execution_authority,
            authority,
            registrar,
            manifest=split,
            anchor=settlement.AnchorV4Model(
                split.anchor,
                split.anchor_runtime_hash,
                split.commitment,
            ),
            store=store,
            bridge_deployment=settlement.bridge_deployment_state_for_test(
                split
            ),
        ))

    def test_native_liquidity_pool_rejects_prelaunch_deposit_and_does_not_fund_tx0(self):
        protocol, manager = migration_manager_fixture(seat=False)
        registrar = protocol.inbox_apply_router._terminal_registrar_authority
        authority = registrar.authority
        pool = registrar.liquidity_pool
        self.assertIsNone(pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=7
        ))
        self.assertEqual((pool.balance, pool.ticket_liability), (0, 0))
        # Forced ETH is unowned surplus and cannot manufacture an LP ticket.
        pool.balance = 17
        store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:underfunded", ""
        )
        manifest = settlement.release_manifest_fixture(
            80, "", "bridge:underfunded", store, router=manager.router
        )
        deployment = settlement.bridge_deployment_state_for_test(manifest)
        endpoint = settlement.EndpointActivationStateV2()
        anchor = settlement.AnchorV4Model(
            manifest.anchor, manifest.anchor_runtime_hash, manifest.commitment
        )
        self.assertTrue(settlement.execute_release_activation_for_test(
            protocol._inbox_execution_authority,
            authority,
            registrar,
            manifest=manifest,
            anchor=anchor,
            store=store,
            endpoint_state=endpoint,
            bridge_deployment=deployment,
            retirement_queue_watermark=0,
        ))
        receipt = registrar.bridge_activation_receipts[manifest.destination_bridge]
        self.assertTrue(pool.active)
        self.assertEqual((pool.balance, pool.ticket_liability), (17, 0))
        self.assertEqual((deployment.balance, receipt.bridge_postbalance), (0, 0))
        ticket_id = pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=7
        )
        self.assertIsNotNone(ticket_id)
        self.assertEqual((pool.balance, pool.ticket_liability), (24, 7))

    def test_destination_forced_prefunding_is_surplus_not_activation_dos(self):
        amount = settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR
        for surplus in (1, amount - 1, amount, 9 * amount):
            with self.subTest(surplus=surplus):
                protocol, manager = migration_manager_fixture(seat=False)
                registrar = (
                    protocol.inbox_apply_router._terminal_registrar_authority
                )
                pool = registrar.liquidity_pool
                pre_pool = pool.balance
                store = settlement.InboxCreditStoreV2(
                    "inbox-apply", f"bridge:dust:{surplus}", ""
                )
                manifest = settlement.release_manifest_fixture(
                    80,
                    "",
                    f"bridge:dust:{surplus}",
                    store,
                    router=manager.router,
                )
                deployment = settlement.bridge_deployment_state_for_test(
                    manifest, balance=surplus
                )
                self.assertTrue(settlement.execute_release_activation_for_test(
                    protocol._inbox_execution_authority,
                    registrar.authority,
                    registrar,
                    manifest=manifest,
                    anchor=settlement.AnchorV4Model(
                        manifest.anchor,
                        manifest.anchor_runtime_hash,
                        manifest.commitment,
                    ),
                    store=store,
                    bridge_deployment=deployment,
                ))
                receipt = registrar.bridge_activation_receipts[
                    manifest.destination_bridge
                ]
                self.assertEqual(deployment.balance, surplus)
                self.assertEqual(deployment.activation_surplus, surplus)
                self.assertEqual(pool.balance, pre_pool)
                self.assertEqual(
                    (
                        receipt.activation_surplus,
                        receipt.bridge_postbalance,
                    ),
                    (
                        surplus,
                        surplus,
                    ),
                )
                self.assertTrue(receipt.valid_for(manifest, deployment))
                self.assertFalse(replace(
                    receipt, activation_surplus=surplus + 1
                ).valid_for(manifest, deployment))

    def test_release_tx0_watermark_is_exact_queue_count_calldata(self):
        protocol, manager = migration_manager_fixture(seat=False)
        registrar = protocol.inbox_apply_router._terminal_registrar_authority
        protocol.forced_queue.count = 9
        registrar.inbox_router.next_queue_index = 3
        store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:watermark", ""
        )
        manifest = settlement.release_manifest_fixture(
            80, "", "bridge:watermark", store, router=manager.router
        )
        self.assertNotEqual(
            settlement.release_system_calldata_hash(manifest, 9),
            settlement.release_system_calldata_hash(manifest, 8),
        )
        for substituted in (0, 8, 10, settlement.UINT64_MAX + 1):
            deployment = settlement.bridge_deployment_state_for_test(manifest)
            self.assertFalse(settlement.execute_release_activation_for_test(
                protocol._inbox_execution_authority,
                registrar.authority,
                registrar,
                manifest=manifest,
                anchor=settlement.AnchorV4Model(
                    manifest.anchor,
                    manifest.anchor_runtime_hash,
                    manifest.commitment,
                ),
                store=store,
                bridge_deployment=deployment,
                retirement_queue_watermark=substituted,
            ))
            self.assertFalse(deployment.v2_active)
            self.assertNotIn(80, registrar.registrations)
        exact_deployment = settlement.bridge_deployment_state_for_test(manifest)
        self.assertTrue(settlement.execute_release_activation_for_test(
            protocol._inbox_execution_authority,
            registrar.authority,
            registrar,
            manifest=manifest,
            anchor=settlement.AnchorV4Model(
                manifest.anchor,
                manifest.anchor_runtime_hash,
                manifest.commitment,
            ),
            store=store,
            bridge_deployment=exact_deployment,
            retirement_queue_watermark=9,
        ))
        receipt = registrar.bridge_activation_receipts[
            manifest.destination_bridge
        ]
        self.assertEqual(receipt.retirement_queue_count, 9)

    def test_old_domain_reservations_block_reclaim_until_terminal_release(self):
        protocol, manager = migration_manager_fixture(seat=False)
        registrar = protocol.inbox_apply_router._terminal_registrar_authority
        authority = registrar.authority
        pool = registrar.liquidity_pool
        forced_surplus = 13

        first_store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:funding-a", ""
        )
        first = settlement.release_manifest_fixture(
            80, "", "bridge:funding-a", first_store,
            router=manager.router,
        )
        first_deployment = settlement.bridge_deployment_state_for_test(first)
        self.assertEqual(first_deployment.balance, 0)
        self.assertTrue(settlement.execute_release_activation_for_test(
            protocol._inbox_execution_authority,
            authority,
            registrar,
            manifest=first,
            anchor=settlement.AnchorV4Model(
                first.anchor, first.anchor_runtime_hash, first.commitment
            ),
            store=first_store,
            bridge_deployment=first_deployment,
            retirement_queue_watermark=0,
        ))
        self.assertEqual((pool.balance, first_deployment.balance), (0, 0))
        first_bridge = settlement.destination_bridge_for_test(
            first,
            first_store,
            registrar.accumulator,
            balance=forced_surplus,
        )
        self.assertEqual(first_bridge.reclaim_surplus(
            registrar, caller=addr("observer")
        ), (settlement.ReclaimResult.REJECTED, 0))

        registrar.inbox_router.next_queue_index = 5
        protocol.forced_queue.count = 7
        second_store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:funding-b", ""
        )
        second = settlement.release_manifest_fixture(
            81, "", "bridge:funding-b", second_store,
            router=manager.router,
        )
        second_deployment = settlement.bridge_deployment_state_for_test(second)
        self.assertTrue(settlement.execute_release_activation_for_test(
            protocol._inbox_execution_authority,
            authority,
            registrar,
            manifest=second,
            anchor=settlement.AnchorV4Model(
                second.anchor, second.anchor_runtime_hash, second.commitment
            ),
            store=second_store,
            bridge_deployment=second_deployment,
            retirement_queue_watermark=7,
        ))
        self.assertEqual(
            registrar.retirement_queue_watermarks[first.destination_bridge],
            7,
        )
        self.assertEqual((pool.balance, second_deployment.balance), (0, 0))
        self.assertEqual(first_bridge.reclaim_surplus(
            registrar, caller=addr("observer")
        ), (settlement.ReclaimResult.REJECTED, 0))

        message = settlement.IBridgeMessageV1(
            1, 2, settlement.MAX_FORCE_MESSAGE_GAS,
            addr("remote-lp"), 1, addr("source-owner"),
            first_bridge.destination_chain_id, addr("dest-owner"),
            addr("recipient"), 5,
            settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"old-domain",
        )
        source, route = settlement.destination_delivery_context_for_test(
            first_bridge, message, queue_index=0
        )
        self.assertTrue(settlement.install_destination_pin_for_test(
            first_bridge, message, source, route, now=self.clock.timestamp
        ))
        ticket_id = settlement.reserve_destination_liquidity_for_test(
            first_bridge, message, source, route, now=self.clock.timestamp
        )
        self.assertTrue(ticket_id)
        credit_id = settlement.destination_credit_id_v2(message, source, route)
        self.assertEqual(pool.reserved_count(first.destination_domain_id), 1)
        registrar.inbox_router.next_queue_index = 7
        self.assertEqual(first_bridge.reclaim_surplus(
            registrar, caller=addr("observer")
        ), (settlement.ReclaimResult.REJECTED, 0))
        process_by = first_store.pins[credit_id].process_by
        first_bridge.execution_environment.block_timestamp = process_by + 1
        self.assertTrue(first_bridge.expire_v2(credit_id))
        self.assertEqual(pool.reserved_count(first.destination_domain_id), 0)
        self.assertEqual(pool.tickets[ticket_id].state, "AVAILABLE")
        self.assertEqual(first_bridge.reclaim_surplus(
            registrar, caller=addr("public-reclaimer")
        ), (settlement.ReclaimResult.RECLAIMED_VALUE, forced_surplus))
        self.assertTrue(first_bridge.retired)
        self.assertEqual((pool.balance, pool.ticket_liability), (7, 7))
        self.assertEqual(
            first.execution_profile.bridge_surplus_sink.balance,
            forced_surplus,
        )
        self.assertEqual(pool.withdraw_ticket(
            ticket_id, caller="test-liquidity-provider", recipient=addr("lp")
        ), 7)
        self.assertEqual((pool.balance, pool.ticket_liability), (0, 0))
        self.assertEqual(pool.balance + pool.withdrawn_total, 7)
        self.assertEqual(first_bridge.reclaim_surplus(
            registrar, caller=addr("observer")
        ), (settlement.ReclaimResult.REJECTED, 0))


    def test_v2_last_retry_success_tail_fault_restores_retriable(self):
        delivery = self.destination_delivery(
            "v2-last-tail", value=5, fee=1
        )
        owner = delivery[0].destination_owner
        credit_id = settlement.destination_credit_id_v2(*delivery)
        pool = self.destination_bridge.liquidity_pool
        reserved_before = pool.reserved_count(
            self.destination_bridge.local_domain_id
        )
        pool_before = pool._snapshot()
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(
            self.destination_bridge.process(*delivery, caller=owner),
            "RETRIABLE",
        )
        self.assertEqual(pool._snapshot(), pool_before)
        self.assertEqual(
            pool.reserved_count(self.destination_bridge.local_domain_id),
            reserved_before,
        )

        reservation = pool.reservations[credit_id]
        ticket_id = reservation.ticket_id
        pool_balance = pool.balance
        # A reverted invocation keeps the exact reservation live; the retry
        # consumes it only in the same journal as DONE.
        self.destination_receiver.fault_point = ""
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=owner, is_last_attempt=True
        ), "DONE")
        self.assertNotIn(
            credit_id, pool.reservations
        )
        self.assertEqual(
            pool.tickets[ticket_id].state,
            "CONSUMED",
        )
        self.assertEqual(
            pool.balance,
            pool_balance - 6,
        )
        self.assertEqual(
            pool.reserved_count(self.destination_bridge.local_domain_id),
            reserved_before - 1,
        )
        self.assertEqual(self.destination_bridge.status[credit_id], "DONE")

    def test_native_liquidity_reservation_is_exact_and_terminal_ordered(self):
        delivery = self.destination_delivery(
            "exact-ticket", value=4, fee=2, liquidity_fee=7,
            fund_liquidity=False,
        )
        message, source, route = delivery
        credit_id = settlement.destination_credit_id_v2(*delivery)
        pool = self.destination_bridge.liquidity_pool
        domain_id = self.destination_bridge.local_domain_id
        self.assertEqual(
            self.destination_store.pins[credit_id].liquidity_fee, 7
        )
        wrong_ticket = pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=5
        )
        self.assertTrue(wrong_ticket)
        self.assertFalse(pool.reserve(
            wrong_ticket,
            self.destination_bridge,
            message,
            source,
            route,
            caller=addr("lp"),
            now=self.clock.timestamp,
        ))
        self.assertEqual(pool.withdraw_ticket(
            wrong_ticket, caller=addr("lp"), recipient=addr("lp")
        ), 5)
        ticket_id = pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=6
        )
        self.assertTrue(ticket_id)
        self.assertFalse(pool.reserve(
            ticket_id,
            self.destination_bridge,
            message,
            source,
            route,
            caller=addr("attacker"),
            now=self.clock.timestamp,
        ))
        reserved_before = pool.reserved_count(domain_id)
        self.assertTrue(pool.reserve(
            ticket_id,
            self.destination_bridge,
            message,
            source,
            route,
            caller=addr("lp"),
            now=self.clock.timestamp,
        ))
        self.assertEqual(pool.reserved_count(domain_id), reserved_before + 1)
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(pool.tickets[ticket_id].state, "CONSUMED")
        self.assertEqual(pool.reserved_count(domain_id), reserved_before)

        late_ticket = pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=6
        )
        self.assertTrue(late_ticket)
        self.assertFalse(pool.reserve(
            late_ticket,
            self.destination_bridge,
            message,
            source,
            route,
            caller=addr("lp"),
            now=self.clock.timestamp,
        ))
        self.assertEqual(pool.withdraw_ticket(
            late_ticket, caller=addr("lp"), recipient=addr("lp")
        ), 6)

    def test_unfunded_credit_expires_and_cannot_be_reserved_after_terminal(self):
        delivery = self.destination_delivery(
            "unfunded-expiry", value=8, fee=3,
            fund_liquidity=False,
        )
        message, source, route = delivery
        credit_id = settlement.destination_credit_id_v2(*delivery)
        pool = self.destination_bridge.liquidity_pool
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("relayer")
        ), "UNFUNDED")
        self.assertNotIn(credit_id, self.destination_bridge.status)
        process_by = self.destination_store.pins[credit_id].process_by
        self.destination_environment.block_timestamp = process_by + 1
        self.assertTrue(self.destination_bridge.expire_v2(credit_id))
        self.assertEqual(self.destination_bridge.status[credit_id], "FAILED")
        ticket_id = pool.deposit(
            owner=addr("lp"), l1_recipient=addr("lp-l1"), amount=11
        )
        self.assertTrue(ticket_id)
        self.assertFalse(pool.reserve(
            ticket_id,
            self.destination_bridge,
            message,
            source,
            route,
            caller=addr("lp"),
            now=process_by,
        ))
        self.assertEqual(pool.withdraw_ticket(
            ticket_id, caller=addr("lp"), recipient=addr("lp")
        ), 11)

    def test_v2_roles_are_immutable_and_strictly_one_way(self):
        source = self.source_bridge
        destination = self.destination_bridge
        self.assertEqual(
            source.source_descriptor.role,
            settlement.BRIDGE_ROLE_SOURCE_ONLY,
        )
        self.assertEqual(
            self.destination_manifest.destination_bridge_descriptor.role,
            settlement.BRIDGE_ROLE_DESTINATION_ONLY,
        )
        self.assertFalse(hasattr(source, "process"))
        self.assertFalse(hasattr(destination, "send_message"))
        with self.assertRaises(TypeError):
            source.finalize_done(
                "credit:forged-verifier",
                proof=None,
                verifier=object(),
            )
        with self.assertRaises(ValueError):
            replace(
                source.source_descriptor,
                role=settlement.BRIDGE_ROLE_DESTINATION_ONLY,
            ).descriptor_id
        descriptor = self.destination_manifest.destination_bridge_descriptor
        self.assertFalse(replace(
            self.destination_manifest,
            destination_bridge_descriptor=replace(
                descriptor, role=settlement.BRIDGE_ROLE_SOURCE_ONLY
            ),
        ).structurally_valid())

    def test_fresh_v2_message_id_late_revert_and_overflow_are_atomic(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot, "shared-id", value=1, fee=0
        )
        receipt = bridge.send_message(
            envelope,
            caller=addr("v2"),
            msg_value=2,
            clock=clock,
            enqueue_by=self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        )
        self.assertEqual(receipt.envelope.message.message_id, 0)
        self.assertEqual(bridge.next_message_id, 1)
        bridge.fault_point = "after_liability_write"
        with self.assertRaises(RuntimeError):
            bridge.send_message(
                envelope,
                caller=addr("late-fault"),
                msg_value=2,
                clock=clock,
                enqueue_by=(
                    self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                ),
            )
        self.assertEqual(bridge.next_message_id, 1)
        bridge.fault_point = None
        bridge.next_message_id = settlement.UINT64_MAX
        before = bridge._transaction_snapshot()
        with self.assertRaises(ValueError):
            bridge.send_message(
                envelope,
                caller=addr("overflow"),
                msg_value=2,
                clock=clock,
                enqueue_by=(
                    self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                ),
            )
        self.assertEqual(bridge._transaction_snapshot(), before)

    def test_same_address_cross_chain_graphs_are_storage_and_balance_separate(self):
        self.assertEqual(
            self.source_bridge.address, self.destination_bridge.address
        )
        self.assertNotEqual(
            self.source_bridge.source_chain_id,
            self.destination_bridge.destination_chain_id,
        )
        self.assertIsNot(self.source_bridge, self.destination_bridge)
        self.assertNotIn(
            self.source_bridge,
            self.destination_bridge.__dict__.values(),
        )
        source_balance = self.source_bridge.balance
        self.destination_bridge.balance += 1
        self.assertEqual(self.source_bridge.balance, source_balance)
        with self.assertRaises(ValueError):
            settlement.destination_bridge_for_test(
                self.destination_manifest,
                self.destination_store,
                self.destination_accumulator,
                balance=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
                quota=2 * settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            )

    def test_manifest_pins_denyset_and_v2_post_call_reserve(self):
        descriptor = self.destination_manifest.destination_bridge_descriptor
        self.assertEqual(
            descriptor.post_call_gas_reserve,
            settlement.V2_POST_CALL_GAS_RESERVE,
        )
        self.assertFalse(replace(
            self.destination_manifest,
            destination_bridge_descriptor=replace(
                descriptor,
                privileged_target_denyset=("attacker",),
            ),
        ).structurally_valid())
        same_authority = settlement.release_manifest_fixture(
            79,
            self.destination_manifest.destination_domain_id,
            self.destination_manifest.destination_bridge,
            settlement.InboxCreditStoreV2(
                "inbox-apply",
                self.destination_manifest.destination_bridge,
                self.destination_manifest.destination_domain_id,
            ),
            router=self.router,
        )
        self.assertFalse(
            settlement.historical_v2_privileged_policy_compatible(
                self.destination_manifest, same_authority
            )
        )
        added_future_privilege = replace(
            same_authority,
            destination_bridge_descriptor=replace(
                same_authority.destination_bridge_descriptor,
                privileged_target_denyset=(
                    *same_authority.destination_bridge_descriptor
                        .privileged_target_denyset,
                    addr("future-endpoint"),
                ),
            ),
        )
        self.assertFalse(
            settlement.historical_v2_privileged_policy_compatible(
                self.destination_manifest, added_future_privilege
            )
        )
        self.assertFalse(replace(
            self.destination_manifest,
            destination_bridge_descriptor=replace(
                descriptor,
                post_call_gas_reserve=(
                    settlement.V2_POST_CALL_GAS_RESERVE - 1
                ),
            ),
        ).structurally_valid())

    def test_last_retry_failure_terminalizes_only_for_destination_owner(self):
        delivery = self.destination_delivery("last-attempt")
        owner = delivery[0].destination_owner
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=owner
        ), "RETRIABLE")
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=addr("observer"), is_last_attempt=False
        ), "RETRIABLE")
        self.assertEqual(self.destination_bridge.status[credit_id], "RETRIABLE")
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=owner, is_last_attempt=True
        ), "FAILED")
        self.assertEqual(self.destination_bridge.status[credit_id], "FAILED")

    def test_credit_registry_authorization_is_fixed_size(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        raw = settlement.bridge_message(
            self.clock.l2_slot,
            "fixed-registry",
            bridge_from=addr("ignored"),
            message_id=123,
            source_chain_id=456,
            data=b"fixed-registry-data",
            value=1,
            fee=1,
        )
        receipt = bridge.send_message(
            raw,
            caller=addr("registry-user"),
            msg_value=3,
            clock=clock,
            enqueue_by=self.clock.timestamp
            + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        )
        authorization = self.credit_registry.authorizations[
            receipt.credit_id
        ]
        self.assertNotIn(
            "message_preimage",
            settlement.CreditAuthorization.__dataclass_fields__,
        )
        self.assertNotIn("data", authorization.__dict__)
        self.assertEqual(
            authorization.calldata_hash,
            receipt.envelope.message.data_hash,
        )
        self.assertEqual(
            authorization.calldata_length,
            len(receipt.envelope.message.data),
        )

    def test_destination_bridge_executes_exact_message_without_auth_booleans(self):
        owner = addr("destination-owner")
        message = settlement.IBridgeMessageV1(
            1, 7, 3_000_000, addr("remote-sender"), 1,
            addr("source-owner"),
            self.destination_bridge.destination_chain_id,
            owner,
            self.destination_receiver.address,
            11,
            settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"exact",
        )
        source, route = settlement.destination_delivery_context_for_test(
            self.destination_bridge, message, queue_index=1
        )
        self.assertTrue(settlement.install_destination_pin_for_test(
            self.destination_bridge, message, source, route,
            now=self.clock.timestamp,
        ))
        self.assertTrue(settlement.reserve_destination_liquidity_for_test(
            self.destination_bridge, message, source, route,
            now=self.clock.timestamp,
        ))
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            message, source, route, caller=addr("relayer")
        ), "DONE")
        credit_id = settlement.destination_credit_id_v2(
            message, source, route
        )
        self.assertEqual(self.destination_bridge.status[credit_id], "DONE")
        self.assertEqual(self.destination_receiver.native_balance, 11)
        self.assertEqual(
            sum(self.destination_bridge.pull_credits.values()), message.fee
        )
        self.assertEqual(self.destination_bridge.process(
            message, source, route, caller=addr("relayer")
        ), "REJECTED")
        for substituted in (
            (replace(message, data=message.data + b"\x00"), source, route),
            (message, replace(source, source_domain_id="domain:wrong"), route),
            (message, source, replace(route, queue_index=route.queue_index + 1)),
        ):
            self.assertEqual(self.destination_bridge.process(
                *substituted, caller=addr("relayer")
            ), "REJECTED")

        dynamically_deployed = settlement.BridgeCallReceiverV2(
            addr("dynamic-app")
        )
        self.assertTrue(self.destination_environment.deploy_application(
            dynamically_deployed
        ))
        dynamic_message = replace(
            message,
            message_id=2,
            to=dynamically_deployed.address,
            value=3,
            fee=1,
            data=settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"dynamic",
        )
        dynamic_source, dynamic_route = (
            settlement.destination_delivery_context_for_test(
                self.destination_bridge, dynamic_message, queue_index=2
            )
        )
        self.assertTrue(settlement.install_destination_pin_for_test(
            self.destination_bridge,
            dynamic_message,
            dynamic_source,
            dynamic_route,
            now=self.clock.timestamp,
        ))
        self.assertTrue(settlement.reserve_destination_liquidity_for_test(
            self.destination_bridge,
            dynamic_message,
            dynamic_source,
            dynamic_route,
            now=self.clock.timestamp,
        ))
        self.assertEqual(self.destination_bridge.process(
            dynamic_message, dynamic_source, dynamic_route,
            caller=addr("relayer"),
        ), "DONE")
        self.assertEqual(dynamically_deployed.native_balance, 3)
        parameters = inspect.signature(
            settlement.DestinationBridgeLedger.process
        ).parameters
        for stale_bool in (
            "message_available", "result_hash_matches", "callback_ok"
        ):
            self.assertNotIn(stale_bool, parameters)
        self.assertNotIn("available_gas", parameters)
        self.assertNotIn("base_fee", parameters)

    def test_destination_retry_manual_owner_and_expiry_are_exact(self):
        owner = addr("manual-dest-owner")
        message = settlement.IBridgeMessageV1(
            40, 2, 3_000_000, addr("remote-manual"), 1,
            addr("source-owner"),
            self.destination_bridge.destination_chain_id,
            owner,
            self.destination_receiver.address,
            5,
            settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"manual",
        )
        source, route = settlement.destination_delivery_context_for_test(
            self.destination_bridge, message, queue_index=40
        )
        self.assertTrue(settlement.install_destination_pin_for_test(
            self.destination_bridge, message, source, route,
            now=self.clock.timestamp,
        ))
        self.assertTrue(settlement.reserve_destination_liquidity_for_test(
            self.destination_bridge, message, source, route,
            now=self.clock.timestamp,
        ))
        delivery = (message, source, route)
        self.destination_receiver.fault_point = "revert"
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=addr("observer")
        ), "NEW")
        self.assertNotIn(
            settlement.destination_credit_id_v2(*delivery),
            self.destination_bridge.status,
        )
        self.assertEqual(self.destination_bridge.process(
            *delivery, caller=owner
        ), "RETRIABLE")
        self.assertFalse(self.destination_bridge.manual_fail(
            *delivery, caller=addr("observer")
        ))
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=addr("observer"), is_last_attempt=True,
        ), "REJECTED")
        self.assertEqual(self.destination_bridge.retry(
            *delivery, caller=addr("observer"), is_last_attempt=False,
        ), "RETRIABLE")
        descriptor = self.destination_manifest.destination_bridge_descriptor
        self.assertFalse(self.destination_bridge.set_paused(
            True, caller=addr("attacker"),
            chain_id=self.destination_bridge.destination_chain_id,
        ))
        self.assertFalse(self.destination_bridge.set_paused(
            True, caller=descriptor.pauser,
            chain_id=self.destination_bridge.destination_chain_id + 1,
        ))
        self.assertTrue(self.destination_bridge.set_paused(
            True, caller=descriptor.pauser,
            chain_id=self.destination_bridge.destination_chain_id,
        ))
        self.assertFalse(self.destination_bridge.manual_fail(
            *delivery, caller=owner
        ))
        process_by = self.destination_store.pins[
            settlement.destination_credit_id_v2(*delivery)
        ].process_by
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.destination_environment.block_timestamp = process_by
        self.assertFalse(self.destination_bridge.expire_v2(credit_id))
        self.destination_environment.block_timestamp = process_by + 1
        self.assertTrue(self.destination_bridge.expire_v2(credit_id))
        self.assertTrue(self.destination_bridge.set_paused(
            False, caller=descriptor.pauser,
            chain_id=self.destination_bridge.destination_chain_id,
        ))

    def test_destination_native_value_is_exact_and_atomic(self):
        store = settlement.InboxCreditStoreV2(
            "inbox-apply", "bridge:l2-native", ""
        )
        manifest = settlement.release_manifest_fixture(
            88, "", "bridge:l2-native", store, router=self.router
        )
        accumulator = settlement.TerminalAccumulatorV2({
            manifest.destination_domain_id: manifest.destination_bridge,
        })
        receiver = settlement.BridgeCallReceiverV2("recipient:l2-native")
        bridge = settlement.destination_bridge_for_test(
            manifest,
            store,
            accumulator,
            applications=(receiver,),
            balance=0,
            quota=settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR,
            timestamp=self.clock.timestamp + 1,
        )
        environment = bridge.execution_environment
        next_index = 0

        def delivery(label, value, fee=0):
            nonlocal next_index
            next_index += 1
            message = settlement.IBridgeMessageV1(
                next_index,
                fee,
                3_000_000,
                addr(f"ns-{label}"),
                1,
                addr(f"no-{label}"),
                bridge.destination_chain_id,
                addr(f"nd-{label}"),
                receiver.address,
                value,
                settlement.ON_MESSAGE_INVOCATION_SELECTOR + label.encode(),
            )
            source, route = settlement.destination_delivery_context_for_test(
                bridge,
                message,
                queue_index=next_index,
                source_domain_id=f"domain:source:{label}",
                source_bridge=addr(f"sb-{label}"),
                bridge_execution_hash=f"execution:source:{label}",
            )
            self.assertTrue(settlement.install_destination_pin_for_test(
                bridge, message, source, route, now=self.clock.timestamp
            ))
            if value + fee:
                self.assertTrue(
                    settlement.reserve_destination_liquidity_for_test(
                        bridge,
                        message,
                        source,
                        route,
                        now=self.clock.timestamp,
                    )
                )
            return message, source, route

        positive = delivery("positive", 7)
        positive_credit = settlement.destination_credit_id_v2(*positive)
        bridge.balance = 0
        settlement.set_bridge_eth_quota_available_for_test(bridge, 0)
        self.assertEqual(bridge.process(
            *positive, caller=addr("observer")
        ), "REJECTED")
        self.assertNotIn(positive_credit, bridge.status)
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 0))
        self.assertEqual(receiver.native_balance, 0)

        settlement.set_bridge_eth_quota_available_for_test(bridge, 0)
        self.assertEqual(bridge.process(
            *positive, caller=addr("observer")
        ), "REJECTED")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 0))

        settlement.set_bridge_eth_quota_available_for_test(bridge, 7)
        receiver.fault_point = "revert"
        self.assertEqual(bridge.process(
            *positive, caller=addr("observer")
        ), "NEW")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 7))
        self.assertEqual(receiver.native_balance, 0)
        self.assertEqual(receiver.received, [])

        receiver.fault_point = None
        self.assertEqual(bridge.process(
            *positive, caller=addr("observer")
        ), "DONE")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 0))
        self.assertEqual(receiver.native_balance, 7)
        self.assertEqual(len(receiver.received), 1)
        self.assertEqual(bridge.process(
            *positive, caller=addr("observer")
        ), "REJECTED")
        self.assertEqual(receiver.native_balance, 7)

        settlement.set_bridge_eth_quota_available_for_test(bridge, 8)
        append_fault = delivery("append-fault", 5, fee=3)
        append_credit = settlement.destination_credit_id_v2(*append_fault)
        terminalized_before = dict(
            accumulator.terminalized_pinned_count
        )
        guard_before = set(accumulator._terminalized_credits)
        accumulator.append_return_length = 31
        self.assertEqual(bridge.process(
            *append_fault, caller=addr("observer")
        ), "REJECTED")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 8))
        self.assertEqual(receiver.native_balance, 7)
        self.assertNotIn(append_credit, bridge.status)
        self.assertNotIn(append_credit, bridge.terminal_index)
        self.assertEqual(
            accumulator.terminalized_pinned_count, terminalized_before
        )
        self.assertEqual(accumulator._terminalized_credits, guard_before)
        accumulator.append_return_length = 32
        self.assertEqual(bridge.process(
            *append_fault, caller=addr("observer")
        ), "DONE")
        self.assertEqual(receiver.native_balance, 12)
        self.assertEqual(bridge.total_pull_liability, 3)
        self.assertEqual(sum(bridge.pull_credits.values()), 3)
        self.assertIn(
            (bridge.local_domain_id, append_credit),
            accumulator._terminalized_credits,
        )
        self.assertEqual(
            accumulator.terminalized_pinned_count[bridge.local_domain_id],
            terminalized_before[bridge.local_domain_id] + 1,
        )

        zero_message = settlement.IBridgeMessageV1(
            next_index + 1,
            0,
            3_000_000,
            addr("ns-zero"),
            1,
            addr("no-zero"),
            bridge.destination_chain_id,
            addr("nd-zero"),
            receiver.address,
            0,
            settlement.ON_MESSAGE_INVOCATION_SELECTOR + b"zero",
        )
        zero_source, zero_route = (
            settlement.destination_delivery_context_for_test(
                bridge,
                zero_message,
                queue_index=next_index + 1,
                source_domain_id="domain:source:zero",
                source_bridge=addr("sb-zero"),
                bridge_execution_hash="execution:source:zero",
            )
        )
        self.assertFalse(settlement.install_destination_pin_for_test(
            bridge,
            zero_message,
            zero_source,
            zero_route,
            now=self.clock.timestamp,
        ))
        self.assertEqual(receiver.native_balance, 12)

        expiring = delivery("expire", 9)
        expiring_credit = settlement.destination_credit_id_v2(*expiring)
        process_by = store.pins[expiring_credit].process_by
        balance_before = bridge.balance
        quota_before = bridge.ether_quota
        target_before = receiver.native_balance
        del expiring
        environment.block_timestamp = process_by + 1
        self.assertTrue(bridge.expire_v2(expiring_credit))
        self.assertEqual(
            (bridge.balance, receiver.native_balance),
            (balance_before, target_before),
        )
        self.assertGreaterEqual(bridge.ether_quota, quota_before)
        self.assertEqual(
            bridge.ether_quota,
            bridge.quota_manager.eth_quota_cap,
        )
        self.assertFalse(bridge.expire_v2(expiring_credit))

    def test_real_inbox_pin_needs_no_bridge_status_seed(self):
        owner = addr("real-inbox-owner")
        inbox = settlement.InboxApplyRouterV2(next_queue_index=0)
        self.assertTrue(self.destination_store._bind_inbox_apply(inbox))
        inbox.routes[self.destination_bridge.local_domain_id] = (
            settlement.InboxRoute(
                self.destination_store,
                self.destination_bridge.address,
                self.destination_store.runtime_codehash,
                self.destination_store.route_config_hash,
            )
        )
        execution = settlement.protocol(
            cursor=0,
            seat=False,
            inbox_apply_router=inbox,
        )
        authority = execution._inbox_execution_authority

        def apply_real_pin(delivery):
            message, source, route = delivery
            descriptor = settlement.BridgeQueueDescriptorV11(
                self.clock.timestamp,
                settlement.MAX_FORCE_MESSAGE_GAS,
                message.data_length,
                settlement.bridge_message_hash(message),
                1,
                message.sender,
                message.fee,
                message.source_chain_id,
                message.source_owner,
                message.destination_chain_id,
                message.destination_owner,
                message.value,
                message.data_hash,
                source.source_domain_id,
                source.source_registration_epoch,
                source.source_bridge,
                source.bridge_execution_hash,
                source.emitted_at_block,
                route.destination_domain_id,
                source.enqueue_by,
                source.refund_mode,
                message.sender,
                source.refund_vault,
                source.refund_capsule_hash,
                source.escrow_id,
                bridge_liquidity_fee=1,
            )
            self.assertEqual(descriptor.credit_id,
                             settlement.destination_credit_id_v2(*delivery))
            self.assertEqual(
                settlement.inbox_kind1_result(route.queue_index, descriptor),
                settlement.destination_result_hash_v11(*delivery),
            )
            authority._execution_frame = (id(delivery), 0)
            try:
                self.assertTrue(inbox._apply_verified_rows(
                    ((
                        route.queue_index,
                        5,
                        settlement.UINT32_MAX,
                        settlement.inbox_kind1_result(
                            route.queue_index, descriptor
                        ),
                        descriptor,
                    ),),
                    force_start=route.queue_index,
                    l2_block_number=route.queue_index + 1,
                    evm_timestamp=self.clock.timestamp,
                    authority=authority,
                    capability=settlement._INBOX_APPLY_ROWS_CAPABILITY,
                ))
            finally:
                authority._execution_frame = None
            credit_id = descriptor.credit_id
            self.assertIn(credit_id, self.destination_store.pins)
            self.assertNotIn(credit_id, self.destination_bridge.status)
            self.assertTrue(
                settlement.reserve_destination_liquidity_for_test(
                    self.destination_bridge,
                    message,
                    source,
                    route,
                    now=self.clock.timestamp,
                )
            )
            return credit_id

        def direct_delivery(index, label):
            message = settlement.IBridgeMessageV1(
                index,
                1,
                settlement.MAX_FORCE_MESSAGE_GAS,
                addr(hashlib.sha256(
                    f"sender-{label}".encode()
                ).hexdigest()[:20]),
                1,
                addr(hashlib.sha256(
                    f"source-owner-{label}".encode()
                ).hexdigest()[:20]),
                self.destination_bridge.destination_chain_id,
                owner,
                self.destination_receiver.address,
                2,
                settlement.ON_MESSAGE_INVOCATION_SELECTOR + label.encode(),
            )
            source, route = settlement.destination_delivery_context_for_test(
                self.destination_bridge, message, queue_index=index
            )
            return message, source, route

        direct = direct_delivery(0, "real-inbox-done")
        direct_credit = apply_real_pin(direct)
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.process(
            *direct, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(self.destination_bridge.status[direct_credit], "DONE")

        retriable = direct_delivery(1, "real-inbox-retry")
        retry_credit = apply_real_pin(retriable)
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(self.destination_bridge.process(
            *retriable, caller=owner
        ), "RETRIABLE")
        self.assertEqual(
            self.destination_bridge.status[retry_credit], "RETRIABLE"
        )
        self.destination_receiver.fault_point = None
        self.assertEqual(self.destination_bridge.retry(
            *retriable, caller=addr("observer"), is_last_attempt=False,
        ), "DONE")

        expiring = direct_delivery(2, "real-inbox-expire")
        expire_credit = apply_real_pin(expiring)
        self.assertNotIn(expire_credit, self.destination_bridge.status)
        process_by = self.destination_store.pins[expire_credit].process_by
        terminal_count = self.destination_accumulator.count
        self.destination_environment.block_timestamp = process_by
        self.assertFalse(self.destination_bridge.expire_v2("credit:unknown"))
        self.assertFalse(self.destination_bridge.expire_v2(expire_credit))
        del expiring
        descriptor = self.destination_manifest.destination_bridge_descriptor
        self.assertTrue(self.destination_bridge.set_paused(
            True, caller=descriptor.pauser,
            chain_id=self.destination_bridge.destination_chain_id,
        ))
        self.destination_environment.block_timestamp = process_by + 1
        self.assertTrue(self.destination_bridge.expire_v2(expire_credit))
        self.assertTrue(self.destination_bridge.set_paused(
            False, caller=descriptor.pauser,
            chain_id=self.destination_bridge.destination_chain_id,
        ))
        self.assertEqual(
            self.destination_bridge.status[expire_credit], "FAILED"
        )
        self.assertEqual(
            self.destination_accumulator.count, terminal_count + 1
        )
        self.assertFalse(self.destination_bridge.expire_v2(expire_credit))
        self.assertFalse(self.destination_bridge.expire_v2(direct_credit))

    def test_source_pause_blocks_new_v2_sends_but_not_refunds(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        enqueue_by = self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        owner = addr("pause-owner")
        direct = settlement.bridge_message(
            self.clock.l2_slot,
            "paused-direct",
            src_owner=owner,
            value=1,
            fee=1,
        )
        self.assertFalse(bridge.set_paused(
            True, caller=addr("attacker"), chain_id=bridge.source_chain_id
        ))
        self.assertFalse(bridge.set_paused(
            True,
            caller=bridge.source_descriptor.deployment_descriptor.pauser,
            chain_id=bridge.source_chain_id + 1,
        ))
        self.assertTrue(bridge.set_paused(
            True,
            caller=bridge.source_descriptor.deployment_descriptor.pauser,
            chain_id=bridge.source_chain_id,
        ))
        registry_before = dict(bridge.credit_registry.authorizations)
        bridge_before = bridge._transaction_snapshot()
        with self.assertRaises(ValueError):
            bridge.send_message(
                direct,
                caller=owner,
                msg_value=3,
                clock=clock,
                enqueue_by=enqueue_by,
            )
        self.assertEqual(bridge.credit_registry.authorizations, registry_before)
        self.assertEqual(bridge._transaction_snapshot(), bridge_before)
        self.assertTrue(bridge.set_paused(
            False,
            caller=bridge.source_descriptor.deployment_descriptor.pauser,
            chain_id=bridge.source_chain_id,
        ))
        receipt = bridge.send_message(
            direct,
            caller=owner,
            msg_value=3,
            clock=clock,
            enqueue_by=enqueue_by,
        )
        self.assertTrue(bridge.set_paused(
            True,
            caller=bridge.source_descriptor.deployment_descriptor.pauser,
            chain_id=bridge.source_chain_id,
        ))
        self.assertTrue(bridge.cancel(receipt.credit_id, now=enqueue_by + 1))
        self.assertEqual(bridge.withdraw_refund(owner), 3)
        self.assertEqual(bridge.total_live_liability, 0)

    def test_bridge_message_field_substitution_cannot_reuse_authorization(self):
        bridge = self.source_bridge
        registry = self.credit_registry
        clock = bridge.support_final_clock(self.clock.timestamp)
        enqueue_by = self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "full-field-binding",
            value=9,
            fee=2,
            data=b"x" * 33,
        )
        credit_id = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=12,
            clock=clock,
            enqueue_by=enqueue_by,
        ).credit_id
        message = envelope.message
        substitutions = (
            replace(message, message_id=message.message_id + 1),
            replace(message, fee=message.fee + 1),
            replace(message, gas_limit=message.gas_limit + 1),
            replace(message, sender="other-sender"),
            replace(message, source_chain_id=message.source_chain_id + 1),
            replace(message, source_owner="other-source-owner"),
            replace(
                message,
                destination_chain_id=message.destination_chain_id + 1,
            ),
            replace(message, destination_owner="other-destination-owner"),
            replace(message, to="other-target"),
            replace(message, value=message.value + 1),
            replace(message, data=message.data[:-1] + b"y"),
        )
        for forged_message in substitutions:
            with self.subTest(field=forged_message):
                forged = replace(envelope, message=forged_message)
                queue_before = copy.deepcopy(self.router.forced_queue)
                bridge_before = bridge._transaction_snapshot()
                registry_before = dict(registry.authorizations)
                records_before = copy.deepcopy(self.bridge_adapter.records)
                with self.assertRaises(ValueError):
                    self.bridge_adapter.enqueue(
                        clock,
                        envelope=forged,
                        caller=addr("permissionless"),
                        deposit=forged.prepaid,
                    )
                self.assertEqual(self.router.forced_queue, queue_before)
                self.assertEqual(bridge._transaction_snapshot(), bridge_before)
                self.assertEqual(registry.authorizations, registry_before)
                self.assertEqual(self.bridge_adapter.records, records_before)
        self.assertEqual(bridge.credits[credit_id].status, "NEW")

    def test_bridge_queue_late_revert_restores_split_source_graph(self):
        bridge = self.source_bridge
        registry = self.credit_registry
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "queue-late-revert",
            value=4,
            fee=1,
        )
        credit_id = bridge.send_message(
            envelope,
            caller=envelope.sender,
            msg_value=6,
            clock=clock,
            enqueue_by=self.clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY,
        ).credit_id
        queue_before = self.router.forced_queue._transaction_snapshot()
        bridge_before = bridge._transaction_snapshot()
        registry_before = dict(registry.authorizations)
        records_before = copy.deepcopy(self.bridge_adapter.records)
        self.router.forced_queue.append_fault_point = "after_descriptor"
        with self.assertRaises(RuntimeError):
            self.bridge_adapter.enqueue(
                clock,
                envelope=envelope,
                caller=addr("permissionless"),
                deposit=envelope.prepaid,
            )
        self.router.forced_queue.append_fault_point = None
        self.assertEqual(
            self.router.forced_queue._transaction_snapshot(), queue_before
        )
        self.assertEqual(bridge._transaction_snapshot(), bridge_before)
        self.assertEqual(registry.authorizations, registry_before)
        self.assertEqual(self.bridge_adapter.records, records_before)
        self.assertEqual(bridge.credits[credit_id].status, "NEW")
        self.assertEqual(
            self.bridge_adapter.enqueue(
                clock,
                envelope=envelope,
                caller=addr("permissionless"),
                deposit=envelope.prepaid,
            ),
            "QUEUED:0",
        )

    def test_router_and_adapters_are_non_reentrant(self):
        descriptor = settlement.message(self.clock.l2_slot, "reentrant")
        queue_before = copy.deepcopy(self.router.forced_queue)
        self.kind0_adapter.entered = True
        with self.assertRaises(RuntimeError):
            self.kind0_adapter.enqueue(
                self.clock,
                descriptor,
                caller=descriptor.sender,
                deposit=descriptor.prepaid,
            )
        self.kind0_adapter.entered = False
        self.router.ingress_entered = True
        with self.assertRaises(RuntimeError):
            self.router.sync_ingress(
                clock=self.clock, caller_adapter=self.kind0_adapter
            )
        self.router.ingress_entered = False
        self.assertEqual(self.router.forced_queue, queue_before)

    def test_real_version_activation_invalidates_stamp_but_retains_old_adapter(self):
        rows = production_migration_fixture()
        old_protocol, old_history, _target, _market, manager = rows[:5]
        ingress_clock = settlement.Clock(
            old_history.last_canonical_l1_block + 1,
            settlement.GENESIS_TIMESTAMP + old_protocol.core.tip_slot,
        )
        adapter = settlement.activate_ingress_adapter_for_test(
            manager.router,
            kind=settlement.ForceKind.BRIDGE_CREDIT,
            clock=ingress_clock,
        )
        status, old_stamp = manager.router.sync_ingress(
            clock=ingress_clock, caller_adapter=adapter
        )
        self.assertEqual(status, "ACTIVE")
        self.assertIsNotNone(old_stamp)
        activate_production_fixture(
            rows,
            clock=settlement.Clock(
                ingress_clock.block_number + 10,
                ingress_clock.timestamp + 10,
            ),
        )
        queue_before = copy.deepcopy(manager.router.forced_queue)
        descriptor = settlement.message(
            ingress_clock.l2_slot + 12,
            "post-version-stale",
            kind=settlement.ForceKind.BRIDGE_CREDIT,
        )
        with self.assertRaises(ValueError):
            manager.router.append_from_adapter(
                descriptor,
                clock=settlement.Clock(
                    ingress_clock.block_number + 12,
                    ingress_clock.timestamp + 12,
                ),
                stamp=old_stamp,
                deposit=descriptor.prepaid,
                caller_adapter=adapter,
            )
        self.assertEqual(manager.router.forced_queue, queue_before)
        new_status, new_stamp = manager.router.sync_ingress(
            clock=settlement.Clock(
                ingress_clock.block_number + 13,
                ingress_clock.timestamp + 13,
            ),
            caller_adapter=adapter,
        )
        self.assertEqual(new_status, "ACTIVE")
        self.assertEqual(new_stamp[0], manager.router.active_version)

    def test_kind0_routes_active_tip_but_retired_bridge_cannot_mint(self):
        rows = production_migration_fixture()
        old_protocol, old_history, _second_history = rows[:3]
        manager, second_id = rows[4], rows[7]
        ingress_clock = settlement.Clock(
            old_history.last_canonical_l1_block + 1,
            settlement.GENESIS_TIMESTAMP + old_protocol.core.tip_slot,
        )
        kind0 = settlement.activate_ingress_adapter_for_test(
            manager.router,
            kind=settlement.ForceKind.USER_TX,
            clock=ingress_clock,
        )
        source = settlement.source_bridge_for_test(manager.router)
        bridge = settlement.activate_ingress_adapter_for_test(
            manager.router,
            kind=settlement.ForceKind.BRIDGE_CREDIT,
            clock=ingress_clock,
            source_bridge=source,
        )
        pre_cutover_clock = source.support_final_clock(ingress_clock.timestamp)
        pre_cutover_message = settlement.bridge_message(
            ingress_clock.l2_slot,
            "old-new-credit",
            value=2,
            fee=1,
        )
        pre_cutover_receipt = source.send_message(
            pre_cutover_message,
            clock=pre_cutover_clock,
            enqueue_by=(
                ingress_clock.timestamp
                + settlement.MAX_BRIDGE_ENQUEUE_DELAY
            ),
            caller=pre_cutover_message.sender,
            msg_value=4,
        )
        activate_production_fixture(rows)
        third_history, third_id = register_production_successor(
            rows, label="v3i", protocol_version=27
        )
        activate_registered_successor(
            rows,
            third_history,
            second_id,
            third_id,
            manifest_byte=b"i",
        )
        final_protocol = third_history.live_protocol
        final_clock = settlement.Clock(
            third_history.last_canonical_l1_block + 1,
            settlement.GENESIS_TIMESTAMP + final_protocol.core.tip_slot + 1,
        )
        kind0_descriptor = settlement.message(
            final_clock.l2_slot, "v1-kind0-at-v3"
        )
        self.assertEqual(
            kind0.enqueue(
                final_clock,
                kind0_descriptor,
                caller=kind0_descriptor.sender,
                deposit=kind0_descriptor.prepaid,
            ),
            "QUEUED:0",
        )
        enqueue_by = (
            final_clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        )
        source_clock = source.support_final_clock(final_clock.timestamp)
        with self.assertRaises(ValueError):
            bridge.enqueue(
                source_clock,
                envelope=pre_cutover_receipt.envelope,
                caller=addr("late-relayer"),
                deposit=pre_cutover_receipt.envelope.prepaid,
            )
        self.assertEqual(
            source.credits[pre_cutover_receipt.credit_id].status,
            "NEW",
        )
        bridge_descriptor = settlement.bridge_message(
            final_clock.l2_slot,
            "v1-bridge-at-v3",
                    value=3,
                    fee=1,
                )
        with self.assertRaises(ValueError):
            source.send_message(
                bridge_descriptor,
                clock=source_clock,
                enqueue_by=enqueue_by,
                caller=bridge_descriptor.sender,
                msg_value=(
                    bridge_descriptor.bridge_value
                    + bridge_descriptor.bridge_fee
                    + bridge_descriptor.bridge_liquidity_fee
                ),
            )
        self.assertEqual(manager.router.active_version, 27)
        self.assertIs(
            manager.router.registrations[27].settlement, third_history
        )
        self.assertIs(final_protocol.messages, manager.router.forced_queue.descriptors)
        self.assertEqual(
            final_protocol.messages[-1].payload_hash,
            "v1-kind0-at-v3",
        )
        self.assertIsNotNone(manager.router._ingress_binding(kind0))
        self.assertIsNotNone(manager.router._ingress_binding(bridge))

    def test_payable_stale_capacity_and_queue_faults_revert_completely(self):
        status, stamp = self.router.sync_ingress(
            clock=self.clock, caller_adapter=self.bridge_adapter
        )
        self.assertEqual(status, "ACTIVE")
        queue_before = copy.deepcopy(self.router.forced_queue)
        self.assertTrue(self.router.migration_gate._arm_from_manager(
            1,
            self.router.active_version,
            self.router.active_version + 1,
            b"m" * 32,
            caller=self.router.version_manager,
        ))
        with self.assertRaises(ValueError):
            self.router.append_from_adapter(
                replace(self.bridge_descriptor("stale"), prepaid=3),
                clock=self.clock,
                stamp=stamp,
                deposit=3,
                caller_adapter=self.bridge_adapter,
            )
        self.assertEqual(self.router.forced_queue, queue_before)
        self.assertTrue(self.router.migration_gate._abort_from_manager(
            1,
            self.router.active_version,
            self.router.active_version + 1,
            b"m" * 32,
            cancel_manifest_active=True,
            caller=self.router.version_manager,
        ))
        with self.assertRaises(ValueError):
            self.router.append_from_adapter(
                replace(self.bridge_descriptor("aborted"), prepaid=3),
                clock=self.clock,
                stamp=stamp,
                deposit=3,
                caller_adapter=self.bridge_adapter,
            )
        self.assertEqual(self.router.forced_queue, queue_before)

        protocol, manager = migration_manager_fixture(seat=False)
        router = manager.router
        adapter = settlement.activate_ingress_adapter_for_test(
            router,
            kind=settlement.ForceKind.USER_TX,
            clock=self.clock,
        )
        protocol.queue_capacity = 0
        _, live_stamp = router.sync_ingress(
            clock=self.clock, caller_adapter=adapter
        )
        queue_before = copy.deepcopy(router.forced_queue)
        with self.assertRaises(ValueError):
            router.append_from_adapter(
                settlement.message(self.clock.l2_slot, "capacity"),
                clock=self.clock,
                stamp=live_stamp,
                deposit=settlement.message(
                    self.clock.l2_slot, "capacity").prepaid,
                caller_adapter=adapter,
            )
        self.assertEqual(router.forced_queue, queue_before)
        protocol.queue_capacity = settlement.MAX_FORCE_QUEUE_ITEMS
        router.forced_queue.append_fault_point = "after_descriptor"
        with self.assertRaises(RuntimeError):
            router.append_from_adapter(
                settlement.message(self.clock.l2_slot, "fault"),
                clock=self.clock,
                stamp=live_stamp,
                deposit=settlement.message(
                    self.clock.l2_slot, "fault").prepaid,
                caller_adapter=adapter,
            )
        self.assertEqual(router.forced_queue, queue_before)

    def test_armed_sync_progresses_cleanup_and_refunds_without_append(self):
        execute_manager_arm(self.manager, self.clock)
        self.protocol.sessions["cleanup"] = settlement.DataSession(
            "cleanup", "alice", self.clock.timestamp - 1
        )
        self.router.migration_gate.live_data_sessions = 1
        queue_before = copy.deepcopy(self.router.forced_queue)
        descriptor = settlement.message(self.clock.l2_slot, "cleanup")
        self.assertEqual(
            self.kind0_adapter.enqueue(
                self.clock,
                descriptor,
                caller=descriptor.sender,
                deposit=descriptor.prepaid,
            ),
            "SYNCED_REFUNDED",
        )
        self.assertNotIn("cleanup", self.protocol.sessions)
        self.assertEqual(self.router.forced_queue, queue_before)
        self.assertEqual(
            self.kind0_adapter.refunds[descriptor.sender], descriptor.prepaid
        )

    def test_descriptor_value_mismatch_reverts_without_canonicalizing_it(self):
        status, stamp = self.router.sync_ingress(
            clock=self.clock, caller_adapter=self.bridge_adapter
        )
        self.assertEqual(status, "ACTIVE")
        queue_before = copy.deepcopy(self.router.forced_queue)
        with self.assertRaises(ValueError):
            self.router.append_from_adapter(
                self.bridge_descriptor("mismatch"),
                clock=self.clock,
                stamp=stamp,
                deposit=7,
                caller_adapter=self.bridge_adapter,
            )
        self.assertEqual(self.router.forced_queue, queue_before)


class L1L2ExecutionBoundaryTests(unittest.TestCase):
    def normal_forks(self, *idents):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        settlement.routed_ingress_for_test(protocol)
        arm_clock = settlement.Clock(
            901, settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot + 1
        )
        self.assertEqual(protocol.arm_normal_context(arm_clock), "ARMED")
        self.assertEqual(
            protocol.activate_normal_context(
                settlement.Clock(902, arm_clock.timestamp)
            ),
            "ACTIVATED",
        )
        commit_clock = settlement.Clock(903, arm_clock.timestamp)
        candidates = tuple(
            settlement.candidate(protocol, commit_clock, ident)
            for ident in idents
        )
        self.assertTrue(all(
            candidate.inbox_execution_receipt is not None
            for candidate in candidates
        ))
        poststates = tuple(
            settlement.replay_prepared_candidate_on_l2_for_test(
                protocol._inbox_execution_authority,
                candidate,
                ((),),
                commit_clock,
            )
            for candidate in candidates
        )
        self.assertTrue(all(poststate is not None for poststate in poststates))
        return protocol, commit_clock, candidates, poststates

    def test_loser_fork_never_pollutes_and_winner_enables_next_l2_block(self):
        protocol, commit_clock, candidates, poststates = self.normal_forks(
            "loser-fork", "winner-fork"
        )
        loser, winner = candidates
        loser_poststate, winner_poststate = poststates
        l2_before = settlement.l2_execution_state_commitment_for_test(protocol)
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        protocol._commit(winner, commit_clock)
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertFalse(
            settlement.select_canonical_l2_poststate_for_test(loser_poststate)
        )
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertTrue(
            settlement.select_canonical_l2_poststate_for_test(winner_poststate)
        )
        self.assertEqual(
            protocol.inbox_apply_router.last_applied_l2_block,
            winner.end_l2_block_number,
        )

        protocol._clear_normal()
        next_arm = settlement.Clock(904, commit_clock.timestamp + 1)
        self.assertEqual(protocol.arm_normal_context(next_arm), "ARMED")
        self.assertEqual(
            protocol.activate_normal_context(
                settlement.Clock(905, next_arm.timestamp)
            ),
            "ACTIVATED",
        )
        next_clock = settlement.Clock(906, next_arm.timestamp)
        next_candidate = settlement.candidate(
            protocol, next_clock, "post-selector-next-block"
        )
        next_poststate = settlement.replay_prepared_candidate_on_l2_for_test(
            protocol._inbox_execution_authority,
            next_candidate,
            ((),),
            next_clock,
        )
        self.assertIsNotNone(next_poststate)
        protocol._commit(next_candidate, next_clock)
        self.assertTrue(
            settlement.select_canonical_l2_poststate_for_test(next_poststate)
        )

    def test_commit_fault_discards_fork_and_same_sealed_poststate_retries(self):
        protocol, commit_clock, candidates, poststates = self.normal_forks(
            "fault-retry-fork",
        )
        candidate = candidates[0]
        poststate = poststates[0]
        l2_before = settlement.l2_execution_state_commitment_for_test(protocol)
        protocol.seat_fault_point = "after_history_record"
        with self.assertRaises(RuntimeError):
            protocol._commit(candidate, commit_clock)
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertFalse(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )
        protocol.seat_fault_point = None
        protocol._commit(candidate, commit_clock)
        self.assertTrue(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )
        self.assertFalse(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )

    def test_pre_cutover_migration_fork_is_inert_until_exact_l1_activation(self):
        rows = production_migration_fixture()
        _old, _history, target, _market, manager = rows[:5]
        manifest, output = prepare_production_activation(rows)
        protocol = target.live_protocol
        l2_before = settlement.l2_execution_state_commitment_for_test(protocol)
        poststate = settlement.replay_verified_migration_output_on_l2_for_test(
            protocol, output, manager.router
        )
        self.assertIsNotNone(poststate)
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertFalse(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertTrue(manager.activate_seat_migration(
            manifest_key=manifest.key,
            activation_proof=output,
            executor=addr("executor"),
            clock=migration_proof_clock(output),
        ))
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(protocol),
            l2_before,
        )
        self.assertTrue(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )
        self.assertFalse(any(
            isinstance(value, settlement.InboxApplyRouterV2)
            for value in manager.router.__dict__.values()
        ))
        self.assertEqual(
            target.inbox_apply_descriptor,
            manager.router.inbox_apply_descriptor,
        )

    def test_fresh_immutable_observation_binds_exact_initial_account_state(self):
        rows = production_migration_fixture()
        _old, _history, target, _market, manager = rows[:5]
        manifest, output = prepare_production_activation(rows)
        registration = settlement.settlement_registration(
            manager.router,
            target,
            activation_block=migration_proof_clock(output).block_number,
            predecessor_version=manager.router.active_version,
            release_manifest_hash=manifest.target_manifest_hash,
        )
        release = registration.release_manifest
        observed = target.live_protocol._inbox_execution_authority \
            ._observed_release_deployments[manifest.target_manifest_hash]
        deployment = observed.bridge_deployment
        descriptor = release.destination_bridge_descriptor
        immutable = descriptor.deployment_descriptor
        self.assertEqual(immutable.topology, "IMMUTABLE_NONPROXY")
        self.assertTrue(deployment.authenticates(release))
        self.assertFalse(deployment.upgrade_to_and_call(
            "impl:attacker",
            b"reinitialize",
        ))
        self.assertFalse(deployment.transfer_ownership(addr("attacker")))
        self.assertFalse(deployment.accept_ownership(addr("attacker")))
        self.assertFalse(deployment.reinitialize(3, b"attack"))
        for substitution in (
            replace(deployment, account_runtime_hash="wrong-runtime"),
            replace(deployment, account_configuration_hash="wrong-config"),
            replace(deployment, storage_layout_hash="wrong-layout"),
            replace(deployment, pauser="pauser:attacker"),
            replace(deployment, signal_service="signal:attacker"),
            replace(deployment, v2_endpoints=("endpoint:attacker",)),
            replace(deployment, quota_manager_state=replace(
                deployment.quota_manager_state,
                configuration_hash="config:attacker",
            )),
            replace(deployment, quota_manager_state=replace(
                deployment.quota_manager_state,
                quota=0,
                available=0,
            )),
            replace(deployment, quota_manager_state=replace(
                deployment.quota_manager_state, updated_at=1,
            )),
            replace(deployment, next_message_id=1),
            replace(deployment, status_entries=(("credit", "NEW"),)),
            replace(deployment, pull_credit_entries=(("owner", 1),)),
            replace(deployment, total_liability=1),
            replace(deployment, terminal_index_entries=(("credit", 0),)),
            replace(deployment, v2_active=True),
            replace(deployment, activation_surplus=0),
        ):
            self.assertFalse(substitution.authenticates(release))
        forced_surplus = replace(
            deployment, balance=settlement.DESTINATION_NATIVE_LIQUIDITY_FLOOR - 1
        )
        self.assertTrue(forced_surplus.authenticates(release))
        substituted_release = replace(
            release,
            destination_bridge_descriptor=replace(
                release.destination_bridge_descriptor,
                deployment_descriptor=replace(
                    immutable, pauser="pauser:attacker"
                ),
            ),
        )
        # The exact 248-byte public descriptor has no hidden Python-object
        # fields.  A substituted deployment witness is rejected by the live
        # account checks, even though it cannot create a second manifest hash.
        self.assertEqual(release.commitment, substituted_release.commitment)
        self.assertFalse(substituted_release.structurally_valid())


class GlobalSeatMigrationHandshakeTests(unittest.TestCase):
    def test_migration_output_is_verifier_issued_and_observed_prestate_bound(self):
        rows = production_migration_fixture()
        _old, _history, target, _market, manager = rows[:5]
        manifest, output = prepare_production_activation(rows)
        authority = target.live_protocol._inbox_execution_authority
        router = manager.router
        self.assertFalse(hasattr(router, "prepare_migration_activation_proof"))
        for forbidden in ("verifier", "router", "evm_validity", "seal"):
            self.assertFalse(hasattr(output, forbidden))
        self.assertTrue(
            output.transition_proof.public_inputs
                .release_system_calldata_hash
        )
        self.assertTrue(
            output.transition_proof.public_inputs.inbox_system_calldata_hash
        )
        verifier = authority.migration_transition_verifier
        descriptor = authority.migration_transition_verifier_descriptor
        self.assertIsInstance(
            verifier, settlement.IMigrationTransitionVerifier
        )
        verifier_result = verifier.verify_transition(output.transition_proof)
        self.assertIs(verifier_result.verifier, verifier)
        self.assertEqual(verifier_result.descriptor, descriptor)
        self.assertTrue(descriptor.structurally_valid())
        source = router._source_bridge_authority
        registry = router._bridge_credit_registry_authority
        self.assertIsInstance(source, settlement.SourceBridgeV2)
        self.assertIsInstance(registry, settlement.BridgeCreditRegistryV2)
        self.assertIs(source.credit_registry, registry)
        self.assertIs(registry.source_bridge, source)
        self.assertIsInstance(
            source.domain_registry.release_authority_descriptor,
            settlement.DestinationReleaseAuthorityDescriptor,
        )
        self.assertNotIn("_release_authority", router.__dict__)
        self.assertFalse(any(
            isinstance(value, settlement.ProtocolReleaseAuthorityV2)
            for value in source.domain_registry.__dict__.values()
        ))

        observed = authority._observed_release_deployments[
            manifest.target_manifest_hash
        ]
        self.assertIs(observed.transition_verifier, verifier)
        self.assertEqual(
            observed.transition_result_digest,
            verifier_result.digest,
        )
        authority._observed_release_deployments.pop(
            manifest.target_manifest_hash
        )
        l2_before = settlement.l2_execution_state_commitment_for_test(
            target.live_protocol
        )
        reissued_trace = settlement.issue_verified_migration_evm_trace_for_test(
            authority,
            router=router,
            settlement=target,
            clock=migration_proof_clock(output),
            target_manifest_hash=manifest.target_manifest_hash,
            candidate=output.candidate,
            rows=output.rows,
        )
        reissued = authority.verify_migration_execution_output(
            router=router,
            settlement=target,
            clock=migration_proof_clock(output),
            target_manifest_hash=manifest.target_manifest_hash,
            candidate=output.candidate,
            evm_validity=reissued_trace,
            rows=output.rows,
        )
        self.assertEqual(reissued.digest, output.digest)
        authority._observed_release_deployments.pop(
            manifest.target_manifest_hash
        )
        self.assertEqual(
            settlement.l2_execution_state_commitment_for_test(
                target.live_protocol
            ),
            l2_before,
        )
        authority._observed_release_deployments[
            manifest.target_manifest_hash
        ] = observed

        verification_clock = migration_proof_clock(output)
        registration = settlement.settlement_registration(
            router,
            target,
            activation_block=verification_clock.block_number,
            predecessor_version=router.active_version,
            release_manifest_hash=manifest.target_manifest_hash,
        )
        witness = settlement.release_deployment_witness_for_test(
            authority, registration.release_manifest
        )
        public_inputs = authority._migration_transition_public_inputs(
            router=router,
            settlement=target,
            clock=verification_clock,
            target_manifest_hash=manifest.target_manifest_hash,
            candidate=output.candidate,
            rows=output.rows,
            witness=witness,
        )
        self.assertEqual(
            public_inputs.deployment_commitment,
            settlement.release_deployment_commitment(
                registration.release_manifest,
                transition_kind=public_inputs.transition_kind,
                retirement_queue_count=public_inputs.queue_count,
            ),
        )
        self.assertEqual(
            public_inputs.digest,
            settlement.MigrationTransitionPublicInputs(
                *tuple(
                    getattr(public_inputs, name)
                    for name in public_inputs.__dataclass_fields__
                )
            ).digest,
        )
        self.assertIsInstance(
            verifier, settlement.TestMigrationTransitionVerifier
        )
        valid_test_proof = settlement.issue_migration_transition_proof_for_test(
            verifier,
            public_inputs, b"valid-independent-proof"
        )
        verifier_result = verifier.verify_transition(valid_test_proof)
        self.assertEqual(len(verifier_result.returndata), 32)
        self.assertEqual(
            verifier_result.returndata, bytes.fromhex(public_inputs.digest)
        )
        for malformed_return in (b"x" * 31, b"x" * 33):
            verifier.returndata_override = malformed_return
            self.assertFalse(router._valid_migration_activation_proof(
                output,
                settlement=target,
                target_manifest_hash=manifest.target_manifest_hash,
                clock=verification_clock,
            ))
        verifier.returndata_override = None
        verifier.raise_on_verify = True
        self.assertFalse(router._valid_migration_activation_proof(
            output,
            settlement=target,
            target_manifest_hash=manifest.target_manifest_hash,
            clock=verification_clock,
        ))
        verifier.raise_on_verify = False
        with self.assertRaises(ValueError):
            verifier.verify_transition(replace(
                valid_test_proof, proof_bytes=b"substituted-proof"
            ))
        oversized = settlement.issue_migration_transition_proof_for_test(
            verifier,
            public_inputs,
            b"x" * (descriptor.maximum_proof_bytes + 1),
        )
        with self.assertRaises(ValueError):
            verifier.verify_transition(oversized)
        self.assertNotEqual(
            replace(descriptor, runtime_hash="wrong-codehash").commitment,
            descriptor.commitment,
        )
        for invalid_descriptor in (
            replace(descriptor, configuration_hash="wrong-config"),
            replace(descriptor, selector="verify(bytes)"),
            replace(descriptor, public_input_schema_hash="wrong-schema"),
            replace(descriptor, nonproxy=False),
        ):
            self.assertFalse(invalid_descriptor.structurally_valid())

        same_descriptor_clone = settlement.TestMigrationTransitionVerifier(
            descriptor
        )
        clone_proof = settlement.issue_migration_transition_proof_for_test(
            same_descriptor_clone,
            public_inputs, b"clone-proof"
        )
        with self.assertRaises(ValueError):
            authority.verify_migration_transition(
                router=router,
                settlement=target,
                clock=verification_clock,
                target_manifest_hash=manifest.target_manifest_hash,
                candidate=output.candidate,
                rows=output.rows,
                witness=witness,
                proof=clone_proof,
            )
        wrong_key = "vk:migration-transition:wrong"
        wrong_descriptor = replace(
            descriptor,
            verifying_key_hash=wrong_key,
            configuration_hash=(
                settlement.migration_transition_verifier_configuration_hash(
                    wrong_key,
                    descriptor.proof_system_id,
                    descriptor.public_input_schema_hash,
                    descriptor.maximum_proof_bytes,
                    descriptor.verification_gas_limit,
                    descriptor.selector,
                )
            ),
        )
        wrong_key_verifier = settlement.TestMigrationTransitionVerifier(
            wrong_descriptor
        )
        wrong_key_proof = settlement.issue_migration_transition_proof_for_test(
            wrong_key_verifier,
            public_inputs, b"wrong-key-proof"
        )
        with self.assertRaises(ValueError):
            authority.verify_migration_transition(
                router=router,
                settlement=target,
                clock=verification_clock,
                target_manifest_hash=manifest.target_manifest_hash,
                candidate=output.candidate,
                rows=output.rows,
                witness=witness,
                proof=wrong_key_proof,
            )

        substitutions = (
            replace(
                public_inputs,
                output_core=replace(
                    public_inputs.output_core,
                    state_root="state:substituted-end-root",
                ),
            ),
            replace(
                public_inputs,
                release_system_calldata_hash=(
                    public_inputs.inbox_system_calldata_hash
                ),
                inbox_system_calldata_hash=(
                    public_inputs.release_system_calldata_hash
                ),
            ),
            replace(
                public_inputs,
                base_core=replace(
                    public_inputs.base_core,
                    state_root="state:substituted-prestate",
                ),
            ),
            replace(
                public_inputs,
                deployment_commitment="deployment:substituted",
            ),
            replace(
                public_inputs,
                transition_kind=1,
            ),
            replace(public_inputs, queue_count=public_inputs.queue_count + 1),
        )
        for index, substituted_inputs in enumerate(substitutions):
            with self.subTest(public_input_substitution=index):
                substituted_proof = (
                    settlement.issue_migration_transition_proof_for_test(
                        verifier,
                        substituted_inputs,
                        f"substitution-proof:{index}".encode(),
                    )
                )
                with self.assertRaises(ValueError):
                    authority.verify_migration_transition(
                        router=router,
                        settlement=target,
                        clock=verification_clock,
                        target_manifest_hash=manifest.target_manifest_hash,
                        candidate=output.candidate,
                        rows=output.rows,
                        witness=witness,
                        proof=substituted_proof,
                    )

        for index, bad_witness in enumerate((
            replace(
                witness,
                endpoint_state=replace(
                    witness.endpoint_state, bridge_account_absent=False,
                ),
            ),
            replace(
                witness,
                bridge_deployment=replace(
                    witness.bridge_deployment, next_message_id=1,
                ),
            ),
            replace(
                witness,
                bridge_deployment=replace(
                    witness.bridge_deployment,
                    account_runtime_hash="code:substituted",
                ),
            ),
            replace(
                witness,
                bridge_deployment=replace(
                    witness.bridge_deployment,
                    account_configuration_hash="config:substituted",
                ),
            ),
            replace(
                witness,
                pool_observation=(
                    witness.pool_observation[0],
                    witness.pool_observation[1],
                    witness.pool_observation[2],
                    witness.pool_observation[3] + 1,
                ),
            ),
        )):
            with self.subTest(fresh_deployment_substitution=index):
                with self.assertRaises(ValueError):
                    authority._migration_transition_public_inputs(
                        router=router,
                        settlement=target,
                        clock=verification_clock,
                        target_manifest_hash=manifest.target_manifest_hash,
                        candidate=output.candidate,
                        rows=output.rows,
                        witness=bad_witness,
                    )

        private_components = list(witness.observed_components)
        private_components[0] = replace(
            private_components[0], runtime_hash="wrong-private-codehash"
        )
        with self.assertRaises(ValueError):
            authority.verify_migration_transition(
                router=router,
                settlement=target,
                clock=verification_clock,
                target_manifest_hash=manifest.target_manifest_hash,
                candidate=output.candidate,
                rows=output.rows,
                witness=replace(
                    witness, observed_components=tuple(private_components)
                ),
                proof=valid_test_proof,
            )

        components = list(observed.observed_components)
        components[0] = replace(
            components[0], runtime_hash="missing-or-substituted-code"
        )
        forged_observation = replace(
            observed, observed_components=tuple(components)
        )
        self.assertNotEqual(forged_observation.digest, observed.digest)
        forged_inputs = replace(
            output.transition_proof.public_inputs,
            deployment_commitment=forged_observation.digest,
        )
        forged_transition_proof = (
            settlement.issue_migration_transition_proof_for_test(
                verifier, forged_inputs, b"forged-observation-proof"
            )
        )
        forged_output = replace(
            output,
            transition_proof=forged_transition_proof,
            transition_statement_digest=forged_inputs.digest,
        )
        self.assertFalse(router._valid_migration_activation_proof(
            forged_output,
            settlement=target,
            target_manifest_hash=manifest.target_manifest_hash,
            clock=migration_proof_clock(output),
        ))
        with self.assertRaises(ValueError):
            manager.activate_seat_migration(
                manifest_key=manifest.key,
                activation_proof=forged_output,
                executor=addr("executor"),
                clock=migration_proof_clock(output),
            )
        self.assertEqual(router.active_version, 25)
        self.assertFalse(hasattr(
            router, "_trace_migration_execution_for_verifier"
        ))
        minimum_landing = migration_proof_clock(output)
        later_landing = settlement.Clock(
            minimum_landing.block_number + 7,
            minimum_landing.timestamp + 7,
        )
        self.assertTrue(manager.activate_seat_migration(
            manifest_key=manifest.key,
            activation_proof=output,
            executor=addr("executor"),
            clock=later_landing,
        ))

    def test_canceled_generation_and_source_sequence_cannot_replay_trace(self):
        rows = production_migration_fixture()
        _old, old_history, target, _market, manager = rows[:5]
        manifest, output = prepare_production_activation(rows)
        router = manager.router
        minimum_landing = migration_proof_clock(output)
        later_landing = settlement.Clock(
            minimum_landing.block_number + 11,
            minimum_landing.timestamp + 11,
        )
        self.assertTrue(router._valid_migration_activation_proof(
            output,
            settlement=target,
            target_manifest_hash=manifest.target_manifest_hash,
            clock=later_landing,
        ))
        self.assertEqual(
            output.transition_statement_digest,
            output.transition_proof.public_inputs.digest,
        )
        self.assertEqual(
            (output.router_generation, output.source_canonical_sequence),
            (
                router.migration_gate.generation,
                old_history.current_sequence,
            ),
        )

        # A later canonical history write changes the exact source sequence,
        # even if all candidate/Queue fields are otherwise copied verbatim.
        old_sequence = old_history.current_sequence
        old_history.current_sequence = old_sequence + 1
        self.assertFalse(router._valid_migration_activation_proof(
            output,
            settlement=target,
            target_manifest_hash=manifest.target_manifest_hash,
            clock=later_landing,
        ))
        old_history.current_sequence = old_sequence

        gate = router.migration_gate
        generation = gate.generation
        self.assertTrue(gate._abort_from_manager(
            generation,
            gate.active_protocol_version,
            gate.target_protocol_version,
            gate.target_manifest_hash,
            cancel_manifest_active=True,
            caller=gate.coordinator,
        ))
        self.assertTrue(gate._arm_from_manager(
            generation + 1,
            router.active_version,
            target.protocol_version,
            manifest.target_manifest_hash,
            caller=gate.coordinator,
        ))
        self.assertTrue(gate._try_ready_from_protocol(
            normal_open=False,
            recovery_active=False,
        ))
        self.assertFalse(router._valid_migration_activation_proof(
            output,
            settlement=target,
            target_manifest_hash=manifest.target_manifest_hash,
            clock=later_landing,
        ))

    def test_execution_profile_hash_commits_rotatable_exact_verifier(self):
        profile_v2 = settlement.execution_profile_for_test(
            26, "profile:seat-v2", verifier_revision="release-26"
        )
        profile_v3 = settlement.execution_profile_for_test(
            27, "profile:seat-v3", verifier_revision="release-27"
        )
        self.assertTrue(profile_v2.structurally_valid())
        self.assertTrue(profile_v3.structurally_valid())
        self.assertNotEqual(
            profile_v2.execution_profile_hash,
            profile_v3.execution_profile_hash,
        )
        self.assertIsNot(
            profile_v2.migration_transition_verifier,
            profile_v3.migration_transition_verifier,
        )
        self.assertNotEqual(
            profile_v2.migration_transition_verifier_descriptor,
            profile_v3.migration_transition_verifier_descriptor,
        )
        changed_key = replace(
            profile_v2.migration_transition_verifier_descriptor,
            verifying_key_hash="vk:substituted",
        )
        self.assertNotEqual(
            settlement.migration_transition_encode((
                profile_v2.protocol_version,
                profile_v2.namespace,
                changed_key,
            )),
            settlement.migration_transition_encode((
                profile_v2.protocol_version,
                profile_v2.namespace,
                profile_v2.migration_transition_verifier_descriptor,
            )),
        )

    def test_canonical_writer_and_stamped_ingress_require_exact_router_graph(self):
        rows = production_migration_fixture()
        protocol, history, _target, _seat_market, manager = rows[:5]
        self.assertFalse(hasattr(history, "record_canonical"))
        self.assertFalse(hasattr(history, "install_imported"))

        history_before = (
            copy.deepcopy(history.core),
            history.canonicalized_at_block,
            history.current_sequence,
            history.last_canonical_l1_block,
            copy.deepcopy(history.history),
        )
        forged_protocol = settlement.protocol(
            tip_slot=protocol.core.tip_slot,
            cursor=protocol.core.message_cursor,
            seat=False,
            settlement_address=protocol.settlement_address,
        )
        self.assertIsNone(history._record_canonical_from_protocol(
            protocol=forged_protocol,
            clock=settlement.Clock(
                history.last_canonical_l1_block + 1,
                settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot + 1,
            ),
        ))
        self.assertEqual(
            (
                history.core,
                history.canonicalized_at_block,
                history.current_sequence,
                history.last_canonical_l1_block,
                history.history,
            ),
            history_before,
        )

        ingress_clock = settlement.Clock(
            history.last_canonical_l1_block + 1,
            settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
        )
        adapter = settlement.activate_ingress_adapter_for_test(
            manager.router,
            kind=settlement.ForceKind.BRIDGE_CREDIT,
            clock=ingress_clock,
        )
        status, stamp = manager.router.sync_ingress(
            clock=ingress_clock, caller_adapter=adapter
        )
        self.assertEqual(status, "ACTIVE")
        self.assertIsNotNone(stamp)
        queue_before = copy.deepcopy(manager.router.forced_queue)
        exact_gate = protocol.migration_gate
        split_gate = copy.deepcopy(exact_gate)
        object.__setattr__(protocol, "migration_gate", split_gate)
        descriptor = settlement.message(
            ingress_clock.block_number,
            "split-router-root",
            kind=settlement.ForceKind.BRIDGE_CREDIT,
        )
        with self.assertRaises(ValueError):
            manager.router.append_from_adapter(
                descriptor,
                clock=ingress_clock,
                stamp=stamp,
                deposit=descriptor.prepaid,
                caller_adapter=adapter,
            )
        self.assertIsNone(history._record_canonical_from_protocol(
            protocol=protocol,
            clock=settlement.Clock(
                history.last_canonical_l1_block + 1,
                ingress_clock.timestamp + 1,
            ),
        ))
        self.assertEqual(manager.router.forced_queue, queue_before)
        self.assertEqual(
            (
                history.core,
                history.canonicalized_at_block,
                history.current_sequence,
                history.last_canonical_l1_block,
                history.history,
            ),
            history_before,
        )
        object.__setattr__(protocol, "migration_gate", exact_gate)

    def test_production_authority_surfaces_reject_lookalikes_and_raw_bypasses(self):
        rows = production_migration_fixture()
        old_protocol, old_history, new_history, _seat_market, manager, release_manager = rows[:6]

        class Lookalike:
            router = manager.router
            address = manager.address

        auth = replace(
            authorization(),
            target=addr("lookalike-target"),
            protocol_version=99,
        )
        runtime = market.TargetRuntime(auth, new_history)
        before = (
            dict(release_manager.authorizations),
            dict(release_manager.target_runtimes),
            dict(release_manager.target_bindings),
            set(release_manager.used_target_addresses),
        )
        with self.assertRaises(market.TransitionRejected):
            release_manager.register_router_target(
                Lookalike(), 1, addr("market"), auth, runtime
            )
        self.assertEqual(
            (
                release_manager.authorizations,
                release_manager.target_runtimes,
                release_manager.target_bindings,
                release_manager.used_target_addresses,
            ),
            before,
        )
        old_runtime = release_manager.target_runtimes[rows[6]]
        detached_gate = settlement.MigrationGate()
        immutable_replacements = (
            (manager, "address", addr("replacement-manager")),
            (manager, "router", settlement.ActiveSettlementRouter(
                addr("replacement-manager"),
                replace(manager.router.forced_queue),
                manager.router.inbox_apply_descriptor,
                manager.router.migration_gate,
                manager.router.header_oracle,
            )),
            (manager, "release_manager", market.ReleaseManager(
                addr("other-release"), activation_authority=manager.router
            )),
            (manager, "market_chain_id", 2),
            (manager, "market_address", addr("other-market")),
            (manager, "governance", addr("repl-governance")),
            (manager, "manifest_delay_seconds", 0),
            (manager, "cancel_delay_seconds", 0),
            (release_manager, "address", addr("replacement-release")),
            (release_manager, "activation_authority", object()),
            (old_runtime, "authorization", auth),
            (old_runtime, "authority", new_history),
            (manager.router, "version_manager", addr("other-manager")),
            (manager.router, "forced_queue", copy.deepcopy(
                manager.router.forced_queue
            )),
            (manager.router, "inbox_apply_descriptor", replace(
                manager.router.inbox_apply_descriptor,
                address="other-inbox",
            )),
            (manager.router, "migration_gate", settlement.MigrationGate()),
            (manager.router, "header_oracle", settlement.make_header_oracle()),
            (manager.router, "address", addr("other-router")),
            (manager.router, "forced_queue_runtime_hash", "other-runtime"),
            (manager.router, "forced_queue_config_hash", "other-config"),
            (manager.router, "builder_registry_id", "other-builders"),
            (manager.router, "schedule_oracle_id", "other-oracle"),
            (manager.router, "authorized_ingress", frozenset({"attacker"})),
            (manager.router.forced_queue, "address", "other-queue"),
            (manager.router.forced_queue, "router_address", "attacker"),
            (manager.router.forced_queue, "runtime_hash", "other-runtime"),
            (manager.router.forced_queue, "config_hash", "other-config"),
            (manager.router.forced_queue, "nonproxy", False),
            (manager.router.forced_queue, "selfdestruct_disabled", False),
            (manager.router.forced_queue, "delegate_target_reachable", True),
            (manager.router.inbox_apply_descriptor, "address", "other-inbox"),
            (
                manager.router.inbox_apply_descriptor,
                "registrar_address",
                "other-registrar",
            ),
            (manager.router.migration_gate, "coordinator", addr("attacker")),
            (detached_gate, "coordinator", addr("attacker")),
            (old_history, "address", addr("other-settlement")),
            (old_history, "runtime_hash", "other-runtime"),
            (old_history, "protocol_version", 99),
            (old_history, "execution_profile_hash", "other-profile"),
            (old_history, "forced_queue", copy.deepcopy(old_history.forced_queue)),
            (old_history, "migration_gate", settlement.MigrationGate()),
            (old_history, "inbox_apply_descriptor", replace(
                old_history.inbox_apply_descriptor,
                address="other-inbox",
            )),
            (old_history, "builder_registry_id", "other-builders"),
            (old_history, "schedule_oracle_id", "other-schedule"),
            (old_history, "market_settlement_chain_id", 2),
            (old_history, "market_runtime_hash", b"x" * 32),
            (old_history, "market_configuration_hash", b"x" * 32),
            (old_history, "market_magic", b"FAIL"),
            (old_history, "header_oracle", settlement.make_header_oracle()),
            (old_history, "_router_authority", object()),
            (old_protocol, "forced_queue", copy.deepcopy(old_protocol.forced_queue)),
            (old_protocol, "inbox_apply_router", copy.deepcopy(
                old_protocol.inbox_apply_router
            )),
            (old_protocol, "migration_gate", settlement.MigrationGate()),
            (old_protocol, "header_oracle", settlement.make_header_oracle()),
        )
        for target, field_name, value in immutable_replacements:
            original = getattr(target, field_name)
            with self.assertRaises(AttributeError):
                setattr(target, field_name, value)
            self.assertIs(getattr(target, field_name), original)
        for delay_field in ("manifest_delay_seconds", "cancel_delay_seconds"):
            kwargs = {delay_field: 0}
            with self.assertRaises(ValueError):
                settlement.ProtocolVersionManager(
                    manager.address,
                    manager.router,
                    release_manager=release_manager,
                    market_chain_id=manager.market_chain_id,
                    market_address=manager.market_address,
                    **kwargs,
                )
        self.assertFalse(hasattr(release_manager, "activation_receipts"))
        self.assertFalse(hasattr(release_manager, "_record_activation_for_test"))
        self.assertFalse(hasattr(release_manager, "_register_target_for_test"))
        self.assertNotIn(
            "activation_block",
            inspect.signature(manager.router.bootstrap).parameters,
        )
        self.assertNotIn(
            "l1_block",
            inspect.signature(manager.activate_seat_migration).parameters,
        )
        queue_before = copy.deepcopy(manager.router.forced_queue)
        descriptor = settlement.message(0, "immutability-bypass")
        self.assertFalse(hasattr(manager.router.forced_queue, "append"))
        self.assertIsNone(manager.router.forced_queue._append_from_router(
            descriptor,
            deposit=descriptor.prepaid,
            due_at=descriptor.due_at,
            router=object(),
        ))
        self.assertEqual(manager.router.forced_queue, queue_before)
        clock_rows = production_migration_fixture()
        manifest, proof = prepare_production_activation(clock_rows)
        clock_before = migration_graph_projection(clock_rows[0], clock_rows[4])
        with self.assertRaises(TypeError):
            clock_rows[4].activate_seat_migration(
                manifest_key=manifest.key,
                activation_proof=proof,
                executor=addr("executor"),
                l1_block=settlement.UINT64_MAX,
            )
        self.assertEqual(
            migration_graph_projection(clock_rows[0], clock_rows[4]),
            clock_before,
        )
        for forbidden in (
            "bootstrap",
            "arm",
            "try_ready",
            "activate_target",
            "abort",
        ):
            self.assertFalse(hasattr(settlement.MigrationGate, forbidden))
        self.assertFalse(
            hasattr(settlement.Protocol, "close_seats_for_migration")
        )
        self.assertFalse(
            hasattr(settlement.ActiveSettlementRouter, "abort_migration")
        )
        self.assertFalse(
            hasattr(settlement.VersionedSettlementHistory, "arm_migration")
        )

    def test_router_bootstrap_is_authenticated_atomic_and_retryable(self):
        protocol = settlement.protocol(seat=False)
        profile = settlement.execution_profile_for_test(
            25, "profile:bootstrap"
        )
        history = settlement.VersionedSettlementHistory(
            protocol.settlement_address,
            "runtime:bootstrap",
            25,
            profile.execution_profile_hash,
            copy.deepcopy(protocol.core),
            protocol.canonical.canonicalized_at_block,
            protocol.forced_queue,
            migration_gate=protocol.migration_gate,
            live_protocol=protocol,
            inbox_apply_descriptor=protocol.inbox_apply_descriptor,
            header_oracle=protocol.header_oracle,
            execution_profile=profile,
        )
        protocol.versioned_history = history
        router = settlement.deploy_active_settlement_router(
            history,
            addr("version-manager"), protocol.forced_queue,
            protocol.inbox_apply_router,
            protocol.migration_gate,
            protocol.header_oracle,
        )
        gate = protocol.migration_gate
        queue = protocol.forced_queue
        inbox = protocol.inbox_apply_router
        projection = lambda: (
            copy.deepcopy(history.core), history.mode, history.current_sequence,
            copy.deepcopy(history.history), copy.deepcopy(gate.__dict__),
            copy.deepcopy(queue.__dict__), router.active_version,
            tuple(router.registrations),
        )
        before = projection()
        bootstrap_clock = settlement.Clock(
            protocol.canonical.canonicalized_at_block,
            settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
        )
        self.assertFalse(router.bootstrap(
            history, sequence=0,
            clock=bootstrap_clock,
            caller=addr("attacker"),
        ))
        self.assertEqual(projection(), before)
        self.assertFalse(router.bootstrap(
            history, sequence=-1,
            clock=bootstrap_clock,
            caller=router.version_manager,
        ))
        self.assertEqual(projection(), before)
        self.assertIs(history.live_protocol, protocol)
        self.assertIs(history.migration_gate, gate)
        self.assertIs(history.forced_queue, queue)
        self.assertEqual(
            history.inbox_apply_descriptor,
            protocol.inbox_apply_descriptor,
        )
        self.assertIs(protocol.versioned_history, history)
        self.assertTrue(router.bootstrap(
            history, sequence=0,
            clock=bootstrap_clock,
            caller=router.version_manager,
        ))
        activated = projection()
        with self.assertRaises(TypeError):
            router.bootstrap(
                history, sequence=1,
                activation_block=settlement.UINT64_MAX,
                caller=router.version_manager,
            )
        self.assertEqual(projection(), activated)

    @staticmethod
    def _stage_old_target(rows):
        old_protocol, _old_history, _new_history, seat_market = rows[:4]
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        seat_market.insert_offer(
            caller=addr("stage-old"),
            payout=addr("stage-old-pay"),
            ask_wei_per_second=1,
            target=old_protocol.settlement_address,
            generation=old_protocol.seat_generation,
            clock=market.Clock(100, 100),
            value=seat_market.sla_bond,
        )
        staged = old_protocol.stage_best(
            seat_market, settlement.Clock(103, 110)
        )
        return staged.stage.stage_id, staged.stage.lineup_commitment

    def test_rotation_authenticates_and_atomically_acks_old_tombstone(self):
        for fault in (
            "after_migration_stage_cancellation",
            "after_migration_tombstone_ack",
        ):
            rows = production_migration_fixture()
            stage_id, lineup = self._stage_old_target(rows)
            old_protocol, old_history, _new_history, seat_market = rows[:4]
            receipt = activate_production_fixture(rows)
            tombstone = old_protocol.stage_tombstones[stage_id]
            self.assertTrue(tombstone.migration_terminal)
            self.assertFalse(tombstone.reconciled)
            self.assertIsNotNone(seat_market.stage)
            with self.assertRaises(ValueError):
                old_protocol.reconcile_stage_invalidation(
                    seat_market,
                    stage_id,
                    lineup,
                    settlement.Clock(1_001, settlement.GENESIS_TIMESTAMP + 1_001),
                )
            manager = rows[5]
            runtime = seat_market.target_runtimes[receipt.old_authorization_id]
            seat_market.fault_point = fault
            market_before = copy.deepcopy(seat_market)
            with self.assertRaises(RuntimeError):
                manager.execute_rotation(
                    seat_market,
                    receipt.key,
                    market.Clock(2_001, settlement.GENESIS_TIMESTAMP + 2_001),
                )
            self.assertEqual(seat_market, market_before)
            self.assertFalse(old_protocol.stage_tombstones[stage_id].reconciled)
            self.assertEqual(old_protocol.outstanding_stage_tombstone_id, stage_id)
            self.assertIs(seat_market.release_manager, manager)
            self.assertIs(runtime.authority, old_history)
            seat_market.fault_point = None
            manager.execute_rotation(
                seat_market,
                receipt.key,
                market.Clock(2_002, settlement.GENESIS_TIMESTAMP + 2_002),
            )
            self.assertTrue(old_protocol.stage_tombstones[stage_id].reconciled)
            self.assertIsNone(old_protocol.outstanding_stage_tombstone_id)
            self.assertIsNone(seat_market.stage)

    def test_post_abort_stage_cancel_is_permissionless_atomic_and_does_not_poison_future_stages(self):
        for market_fault, seat_fault in (
            ("after_tranche_usage_change", None),
            ("after_credit_creation", None),
            (None, "after_market_invalidation"),
            (None, "after_tombstone_reconciliation"),
        ):
            rows = production_migration_fixture()
            stage_id, lineup = self._stage_old_target(rows)
            old_protocol, _old_history, _new_history, seat_market, manager = rows[:5]
            execute_manager_arm(
                manager,
                settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000),
            )
            execute_manager_abort(
                manager,
                settlement.Clock(1_001, settlement.GENESIS_TIMESTAMP + 1_001),
            )
            tombstone = old_protocol.stage_tombstones[stage_id]
            self.assertTrue(tombstone.migration_terminal)
            self.assertFalse(tombstone.reconciled)
            self.assertIsNotNone(seat_market.stage)
            manager_ref = seat_market.release_manager
            runtime_ref = seat_market.target_runtimes[
                seat_market.current_authorization_id
            ]
            seat_market.fault_point = market_fault
            old_protocol.seat_fault_point = seat_fault
            market_before = copy.deepcopy(seat_market)
            graph_before = migration_graph_projection(old_protocol, manager)
            with self.assertRaises(RuntimeError):
                old_protocol.reconcile_stage_invalidation(
                    seat_market,
                    stage_id,
                    lineup,
                    settlement.Clock(
                        1_002, settlement.GENESIS_TIMESTAMP + 1_002
                    ),
                )
            self.assertEqual(seat_market, market_before)
            self.assertEqual(
                migration_graph_projection(old_protocol, manager), graph_before
            )
            self.assertIs(seat_market.release_manager, manager_ref)
            self.assertIs(
                seat_market.target_runtimes[
                    seat_market.current_authorization_id
                ],
                runtime_ref,
            )
            seat_market.fault_point = None
            old_protocol.seat_fault_point = None
            result = old_protocol.reconcile_stage_invalidation(
                seat_market,
                stage_id,
                lineup,
                settlement.Clock(
                    1_003, settlement.GENESIS_TIMESTAMP + 1_003
                ),
            )
            self.assertIsNotNone(result.credit_id)
            self.assertTrue(old_protocol.stage_tombstones[stage_id].reconciled)
            self.assertIsNone(seat_market.stage)
            with self.assertRaises(ValueError):
                old_protocol.reconcile_stage_invalidation(
                    seat_market,
                    stage_id,
                    lineup,
                    settlement.Clock(
                        1_004, settlement.GENESIS_TIMESTAMP + 1_004
                    ),
                )

        rows = production_migration_fixture()
        stage_id, lineup = self._stage_old_target(rows)
        old_protocol, _old_history, _new_history, seat_market, manager = rows[:5]
        execute_manager_arm(
            manager,
            settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000),
        )
        old_protocol.sync(
            settlement.Clock(1_001, settlement.GENESIS_TIMESTAMP + 1_001)
        )
        self.assertEqual(old_protocol.migration_gate.mode, "READY")
        execute_manager_abort(
            manager,
            settlement.Clock(1_002, settlement.GENESIS_TIMESTAMP + 1_002),
        )
        result = old_protocol.reconcile_stage_invalidation(
            seat_market,
            stage_id,
            lineup,
            settlement.Clock(1_003, settlement.GENESIS_TIMESTAMP + 1_003),
        )
        self.assertIsNotNone(result.credit_id)
        self.assertTrue(old_protocol.stage_tombstones[stage_id].reconciled)
        self.assertIsNone(old_protocol.outstanding_stage_tombstone_id)
        with self.assertRaises(ValueError):
            old_protocol.reconcile_stage_invalidation(
                seat_market,
                stage_id,
                lineup,
                settlement.Clock(1_004, settlement.GENESIS_TIMESTAMP + 1_004),
            )

        self.assertEqual(
            seat_market.sync_seat_generation().purged_count, 0
        )
        inserted = seat_market.insert_offer(
            caller=addr("after-abort"),
            payout=addr("after-abort-pay"),
            ask_wei_per_second=1,
            target=old_protocol.settlement_address,
            generation=old_protocol.seat_generation,
            clock=market.Clock(1_010, 1_010),
            value=seat_market.sla_bond,
        )
        ordinary = old_protocol.stage_best(
            seat_market,
            settlement.Clock(1_020, settlement.GENESIS_TIMESTAMP + 1_020),
        )
        self.assertEqual(ordinary.stage.offer_id, inserted.offer.offer_id)
        old_protocol._invalidate_local_stage("ORDINARY_TEST")
        ordinary_tombstone = old_protocol.stage_tombstones[ordinary.stage.stage_id]
        self.assertFalse(ordinary_tombstone.migration_terminal)
        old_protocol.reconcile_stage_invalidation(
            seat_market,
            ordinary.stage.stage_id,
            ordinary.stage.lineup_commitment,
            settlement.Clock(1_021, settlement.GENESIS_TIMESTAMP + 1_021),
        )
        self.assertTrue(ordinary_tombstone.reconciled)
        self.assertEqual(
            seat_market.offers[inserted.offer.offer_id].location,
            market.OfferLocation.PENDING,
        )

    def test_real_activation_uses_distinct_state_and_composed_rotation(self):
        rows = production_migration_fixture()
        (
            old_protocol, old_history, new_history, seat_market, manager,
            release_manager, old_id, new_id,
        ) = rows
        for index in range(4):
            seat_market.insert_offer(
                caller=addr(f"pending-{index}"),
                payout=addr(f"pay-{index}"),
                ask_wei_per_second=index + 1,
                target=old_history.address,
                generation=old_protocol.seat_generation,
                clock=market.Clock(100 + index, 100 + index),
                value=seat_market.sla_bond,
            )
        receipt = activate_production_fixture(rows)
        new_protocol = new_history.live_protocol
        self.assertIsNot(new_protocol, old_protocol)
        self.assertIs(old_history.live_protocol, old_protocol)
        self.assertIs(new_history.live_protocol, new_protocol)
        self.assertIs(old_protocol.migration_gate, new_protocol.migration_gate)
        self.assertEqual(old_history.mode, "FROZEN")
        self.assertEqual(new_history.mode, "ACTIVE")
        self.assertEqual(old_protocol.seat_lineup, [])
        self.assertEqual(new_protocol.seat_lineup, [])
        self.assertTrue(all(cell.reusable for cell in new_protocol.duty_ring))
        gate_sessions = new_protocol.migration_gate.live_data_sessions
        self.assertEqual(
            old_protocol.open_session(
                settlement.Clock(2_000, settlement.GENESIS_TIMESTAMP + 2_000),
                "frozen-grief",
                addr("attacker"),
                settlement.GENESIS_TIMESTAMP + 9_000,
            ),
            "REJECTED_HISTORICAL",
        )
        self.assertEqual(new_protocol.migration_gate.live_data_sessions, gate_sessions)
        result = release_manager.execute_rotation(
            seat_market,
            receipt.key,
            market.Clock(2_001, settlement.GENESIS_TIMESTAMP + 2_001),
        )
        self.assertEqual(result.purged_count, 4)
        self.assertEqual(seat_market.current_authorization_id, new_id)
        self.assertIn(old_id, seat_market.authorizations)
        self.assertFalse(seat_market.authorization_enabled[old_id])
        self.assertTrue(seat_market.authorization_enabled[new_id])
        self.assertIs(seat_market.target_runtimes[old_id].authority, old_history)
        self.assertIs(seat_market.target_runtimes[new_id].authority, new_history)
        sync = seat_market.sync_seat_generation()
        self.assertEqual(sync.purged_count, 0)
        self.assertEqual(seat_market.cached_generation, new_protocol.seat_generation)
        inserted = seat_market.insert_offer(
            caller=addr("new-operator"),
            payout=addr("new-payout"),
            ask_wei_per_second=1,
            target=new_history.address,
            generation=new_protocol.seat_generation,
            clock=market.Clock(2_010, 2_010),
            value=seat_market.sla_bond,
        )
        self.assertEqual(inserted.offer.authorization_id, new_id)

    def test_source_successor_reuses_front_run_bundle_and_retains_history(self):
        successor_descriptor = replace(
            settlement.canonical_source_bridge_descriptor(),
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_salt="salt:source-successor:v2",
            deployment_descriptor=None,
        )
        rows = production_migration_fixture(
            source_bridge_descriptor=successor_descriptor
        )
        manager = rows[4]
        router = manager.router
        old_version = router.active_version
        old_descriptor_id = router._source_descriptor_id_by_version[old_version]
        old_source, old_registry, old_quota = (
            router._source_bundles_by_descriptor_id[old_descriptor_id]
        )
        migration_manifest, activation_proof = prepare_production_activation(
            rows
        )
        preview = settlement.settlement_registration(
            router,
            rows[2],
            activation_block=migration_proof_clock(
                activation_proof
            ).block_number,
            predecessor_version=old_version,
            release_manifest_hash=migration_manifest.target_manifest_hash,
        )
        bound_successor_descriptor = next(
            row.source_descriptor
            for row in preview.ingress_authorizations
            if row.kind is settlement.ForceKind.BRIDGE_CREDIT
        )
        support_registry = router._bridge_domain_registry_authority
        factory = router._source_bridge_factories_by_address[
            bound_successor_descriptor.deployment_factory
        ]

        # An arbitrary account wins the CREATE2 race before activation.  The
        # Router must consume the exact inactive bundle, never deploy a clone.
        predeployed, predeployed_registry, receipt = (
            factory.deploy_source_bundle(
                bound_successor_descriptor,
                support_registry,
                caller=addr("attacker"),
            )
        )
        self.assertTrue(receipt.created_now)
        self.assertFalse(predeployed.v2_active)
        predeployed.balance = 1

        manager.fault_point = "after_target_import"
        with self.assertRaises(RuntimeError):
            manager.activate_seat_migration(
                manifest_key=migration_manifest.key,
                activation_proof=activation_proof,
                executor=addr("executor"),
                clock=migration_proof_clock(activation_proof),
            )
        self.assertFalse(predeployed.v2_active)
        self.assertIsNone(predeployed.activation_surplus)
        self.assertEqual(predeployed.balance, 1)
        self.assertIs(
            factory._bundles[predeployed.address][0], predeployed
        )
        manager.fault_point = None
        self.assertTrue(manager.activate_seat_migration(
            manifest_key=migration_manifest.key,
            activation_proof=activation_proof,
            executor=addr("executor"),
            clock=migration_proof_clock(activation_proof),
        ))
        new_version = router.active_version
        new_descriptor_id = router._source_descriptor_id_by_version[new_version]
        new_source, new_registry, new_quota = (
            router._source_bundles_by_descriptor_id[new_descriptor_id]
        )
        self.assertIs(new_source, predeployed)
        self.assertIs(new_registry, predeployed_registry)
        self.assertTrue(new_source.v2_active)
        self.assertEqual(new_source.activation_surplus, 1)
        self.assertEqual(new_source.balance, 1)
        self.assertIs(new_source.domain_registry, support_registry)
        self.assertEqual(len(router._source_bundles_by_descriptor_id), 2)
        self.assertEqual(
            len({
                old_source.address, old_registry.address, old_quota.address,
                new_source.address, new_registry.address, new_quota.address,
            }),
            6,
        )
        self.assertIs(
            router._source_bundles_by_descriptor_id[old_descriptor_id][0],
            old_source,
        )
        self.assertTrue(old_source.v2_active)

    def test_target_l2_objects_cannot_influence_l1_proof_acceptance(self):
        dirty_rows = (
            ("release_activation_pending", True),
            ("pending_release_protocol_version", 1),
            ("pending_release_manifest_hash", "dirty"),
            ("first_v2_block_number", 1),
            ("episode", 1),
            ("recovery", "dirty"),
            ("normal_best", "dirty"),
            ("normal_best_min_data_expiry", 0),
            ("normal_deadline", 0),
            ("normal_required_through", 0),
            ("normal_min_admissible", 0),
            ("normal_admission_version", 0),
            ("normal_admission_root", "dirty"),
            ("normal_anchor_number", 0),
            ("normal_anchor_hash", "dirty"),
            ("normal_context_id", "dirty"),
            ("normal_arm_block_number", 0),
            ("admission_version", 1),
            ("admission_root", "dirty"),
            ("canonical", settlement.Canonical(
                settlement.CanonicalCore(
                    1, "dirty", 1, "dirty", 0
                ),
                1,
            )),
            ("seat_terms", {b"t" * 32: "dirty"}),
            ("seat_services", {b"t" * 32: "dirty"}),
            ("seat_lineup", [b"t" * 32]),
            ("seat_duties", {b"d" * 32: "dirty"}),
            ("term_duty", {b"t" * 32: b"d" * 32}),
            ("seat_selections", {b"s" * 32: "dirty"}),
            ("term_selection", {b"t" * 32: b"s" * 32}),
            ("seat_selection", "dirty"),
            ("settlement_seat_stage", "dirty"),
            ("stage_tombstones", {b"s" * 32: "dirty"}),
            ("seat_lineup_revision", (1 << 256) - 1),
            ("duty_sequence", settlement.UINT64_MAX),
            ("outstanding_stage_tombstone_id", b"x" * 32),
            ("seat_generation", 1),
            ("seat_migration_local_generation", 1),
            ("seat_migration_arm", "dirty"),
            ("seat_migration_abort", "dirty"),
            ("seat_sla_trigger_pending", True),
            ("seat_scan_count", 1),
            ("seat_scan_visits_total", 1),
            ("events", ["DIRTY"]),
            ("duty_ring", []),
            (
                "duty_ring",
                [settlement.SeatDutyCell() for _ in range(5)],
            ),
            (
                "duty_ring",
                [settlement.SeatDutyCell(sequence=1)]
                + [settlement.SeatDutyCell() for _ in range(3)],
            ),
            ("seat_runway_seconds", settlement.SEAT_RUNWAY_SECONDS + 1),
            (
                "minimum_primary_tenure_seconds",
                settlement.MIN_PRIMARY_TENURE_SECONDS + 1,
            ),
            (
                "minimum_standby_tenure_seconds",
                settlement.MIN_STANDBY_TENURE_SECONDS + 1,
            ),
            ("exit_delay_seconds", settlement.EXIT_DELAY_SECONDS + 1),
            ("seat_profile_ready", False),
            ("seat_configuration_ready", False),
            ("gc_cursor", 1),
            ("boundary_queries", 1),
            ("seat_fault_point", "dirty"),
            ("canonical_state_witness_available", False),
            ("canonical_code_preimages_available", False),
            ("sessions", {"dirty": "dirty"}),
        )
        for field_name, value in dirty_rows:
            rows = production_migration_fixture()
            _old_protocol, _old_history, new_history, _seat_market, manager = rows[:5]
            target = new_history.live_protocol
            manifest, proof = prepare_production_activation(rows)
            setattr(target, field_name, value)
            self.assertTrue(
                manager.router._valid_migration_activation_proof(
                    proof,
                    settlement=new_history,
                    target_manifest_hash=manifest.target_manifest_hash,
                    clock=migration_proof_clock(proof),
                ),
                field_name,
            )

    def test_late_activation_fault_restores_old_new_and_router_graphs(self):
        for fault in ("after_target_import", "after_activation_receipt_write"):
            rows = production_migration_fixture()
            old_protocol, _old_history, new_history, seat_market, manager = rows[:5]
            manifest, proof = prepare_production_activation(rows)
            target = new_history.live_protocol
            l2_before = settlement.l2_execution_state_commitment_for_test(
                target
            )
            poststate = (
                settlement.replay_verified_migration_output_on_l2_for_test(
                    target, proof, manager.router
                )
            )
            self.assertIsNotNone(poststate)
            manager.fault_point = fault
            graph_before = migration_graph_projection(old_protocol, manager)
            market_before = copy.deepcopy(seat_market)
            history_before = copy.deepcopy({
                key: row for key, row in new_history.__dict__.items()
                if key not in {
                    "forced_queue", "inbox_apply_descriptor", "migration_gate",
                    "live_protocol",
                }
            })
            target_before = copy.deepcopy({
                key: row for key, row in target.__dict__.items()
                if key not in {
                    "forced_queue", "inbox_apply_router", "migration_gate",
                    "versioned_history", "_inbox_execution_authority",
                    "_canonical_commit_frame", "normal_best",
                }
            })
            refs = (
                new_history.forced_queue,
                new_history.inbox_apply_descriptor,
                new_history.migration_gate,
                new_history.live_protocol,
            )
            with self.assertRaises(RuntimeError):
                manager.activate_seat_migration(
                    manifest_key=manifest.key,
                    activation_proof=proof,
                    executor=addr("executor"),
                    clock=migration_proof_clock(proof),
                )
            self.assertEqual(
                migration_graph_projection(old_protocol, manager), graph_before
            )
            self.assertEqual(seat_market, market_before)
            self.assertEqual(
                {
                    key: row for key, row in new_history.__dict__.items()
                    if key not in {
                        "forced_queue", "inbox_apply_descriptor", "migration_gate",
                        "live_protocol",
                    }
                },
                history_before,
            )
            self.assertEqual(
                {
                    key: row for key, row in target.__dict__.items()
                    if key not in {
                        "forced_queue", "inbox_apply_router", "migration_gate",
                        "versioned_history", "_inbox_execution_authority",
                        "_canonical_commit_frame", "normal_best",
                    }
                },
                target_before,
            )
            self.assertEqual(
                (
                    new_history.forced_queue,
                    new_history.inbox_apply_descriptor,
                    new_history.migration_gate,
                    new_history.live_protocol,
                ),
                refs,
            )
            self.assertEqual(
                settlement.l2_execution_state_commitment_for_test(target),
                l2_before,
            )
            self.assertFalse(
                settlement.select_canonical_l2_poststate_for_test(poststate)
            )
            manager.fault_point = None
            self.assertTrue(manager.activate_seat_migration(
                manifest_key=manifest.key,
                activation_proof=proof,
                executor=addr("executor"),
                clock=migration_proof_clock(proof),
            ))
            self.assertTrue(
                settlement.select_canonical_l2_poststate_for_test(poststate)
            )

    def test_preactive_history_and_header_source_must_be_exact_and_fresh(self):
        for field_name, value in (
            ("mode", "ACTIVE"),
            ("history", {0: "dirty"}),
            ("current_sequence", 0),
            ("last_canonical_l1_block", 1),
            ("_router_authority", object()),
        ):
            rows = production_migration_fixture()
            old_protocol, _old_history, target_history, seat_market, manager = rows[:5]
            manifest, proof = prepare_production_activation(rows)
            if field_name == "_router_authority":
                object.__setattr__(target_history, field_name, value)
            else:
                setattr(target_history, field_name, value)
            before = migration_graph_projection(old_protocol, manager)
            market_before = copy.deepcopy(seat_market)
            with self.assertRaises(ValueError, msg=field_name):
                manager.activate_seat_migration(
                    manifest_key=manifest.key,
                    activation_proof=proof,
                    executor=addr("executor"),
                    clock=migration_proof_clock(proof),
                )
            self.assertEqual(migration_graph_projection(old_protocol, manager), before)
            self.assertEqual(seat_market, market_before)

        for variant in (
            "copy-equal", "forged-header", "substituted-runtime"
        ):
            variant_rows = production_migration_fixture(
                target_header_variant=variant)
            substituted_header = variant_rows[2].header_oracle
            rows = production_migration_fixture()
            old_protocol, _old_history, target_history, seat_market, manager = rows[:5]
            manifest, proof = prepare_production_activation(rows)
            object.__setattr__(
                target_history, "header_oracle", substituted_header
            )
            object.__setattr__(
                target_history.live_protocol,
                "header_oracle",
                substituted_header,
            )
            self.assertIsNot(
                target_history.header_oracle, manager.router.header_oracle
            )
            graph_before = migration_graph_projection(old_protocol, manager)
            market_before = copy.deepcopy(seat_market)
            with self.assertRaises(ValueError, msg=variant):
                manager.activate_seat_migration(
                    manifest_key=manifest.key,
                    activation_proof=proof,
                    executor=addr("executor"),
                    clock=migration_proof_clock(proof),
                )
            self.assertEqual(
                migration_graph_projection(old_protocol, manager), graph_before
            )
            self.assertEqual(seat_market, market_before)

    def test_skipped_rotation_catches_up_one_receipt_per_call_across_abort_gap(self):
        rows = production_migration_fixture()
        (
            old_protocol, old_history, second_history, seat_market, manager,
            release_manager, first_id, second_id,
        ) = rows
        first_receipt = activate_production_fixture(rows)
        second_protocol = second_history.live_protocol
        self.assertEqual(seat_market.current_authorization_id, first_id)

        # An aborted arm consumes a router generation but creates no receipt.
        abort_current_migration_generation(
            rows, target_version=27, manifest_byte=b"a"
        )
        third_history, third_id = register_production_successor(
            rows, label="v3", protocol_version=27
        )
        third_receipt = activate_registered_successor(
            rows,
            third_history,
            second_id,
            third_id,
            manifest_byte=b"n",
        )
        self.assertGreater(
            third_receipt.router_generation,
            first_receipt.router_generation + 1,
        )
        self.assertEqual(old_history.mode, "FROZEN")
        self.assertEqual(second_history.mode, "FROZEN")
        self.assertEqual(third_history.mode, "ACTIVE")
        self.assertIs(old_protocol.migration_gate, second_protocol.migration_gate)
        self.assertIs(
            second_protocol.migration_gate,
            third_history.live_protocol.migration_gate,
        )

        first = release_manager.execute_rotation(
            seat_market,
            first_receipt.key,
            market.Clock(3_000, settlement.GENESIS_TIMESTAMP + 3_000),
        )
        self.assertEqual(first.purged_count, 0)
        self.assertEqual(seat_market.current_authorization_id, second_id)
        self.assertFalse(seat_market.authorization_enabled[second_id])
        self.assertIsNone(seat_market.cached_generation)
        with self.assertRaises(market.TransitionRejected):
            seat_market.sync_seat_generation()
        with self.assertRaises(market.TransitionRejected):
            seat_market.insert_offer(
                caller=addr("frozen-hop"), payout=addr("frozen-hop-pay"),
                ask_wei_per_second=1,
                target=second_history.address,
                generation=second_protocol.seat_generation,
                clock=market.Clock(3_001, 3_001),
                value=seat_market.sla_bond,
            )

        second = release_manager.execute_rotation(
            seat_market,
            third_receipt.key,
            market.Clock(3_002, settlement.GENESIS_TIMESTAMP + 3_002),
        )
        self.assertEqual(second.purged_count, 0)
        self.assertEqual(seat_market.current_authorization_id, third_id)
        self.assertTrue(seat_market.authorization_enabled[third_id])
        self.assertFalse(seat_market.authorization_enabled[first_id])
        self.assertFalse(seat_market.authorization_enabled[second_id])
        self.assertEqual(
            seat_market.consumed_activation_receipts,
            {first_receipt.key, third_receipt.key},
        )
        seat_market.sync_seat_generation()
        with self.assertRaises(market.TransitionRejected):
            release_manager.execute_rotation(
                seat_market,
                first_receipt.key,
                market.Clock(3_003, settlement.GENESIS_TIMESTAMP + 3_003),
            )
        self.assertEqual(old_history.mode, "FROZEN")
        self.assertEqual(second_history.mode, "FROZEN")
        self.assertEqual(third_history.mode, "ACTIVE")

    def test_three_version_rotation_retains_real_historical_economic_lifecycles(self):
        rows = production_migration_fixture()
        (
            first_protocol, first_history, second_history, seat_market, manager,
            release_manager, first_id, second_id,
        ) = rows

        def install_live(protocol, label, ask, timestamp, block_number):
            seat_market.sponsor_premium(
                ask * seat_market.seat_runway_seconds
            )
            inserted = seat_market.insert_offer(
                caller=addr(label),
                payout=addr(f"pay-{label}"),
                ask_wei_per_second=ask,
                target=protocol.settlement_address,
                generation=protocol.seat_generation,
                clock=market.Clock(timestamp, block_number),
                value=seat_market.sla_bond,
            )
            staged = protocol.stage_best(
                seat_market,
                settlement.Clock(
                    block_number + seat_market.quote_maturity_blocks,
                    timestamp + seat_market.quote_maturity_seconds,
                ),
            )
            if staged == "SYNCED":
                staged = protocol.stage_best(
                    seat_market,
                    settlement.Clock(
                        block_number + seat_market.quote_maturity_blocks + 1,
                        timestamp + seat_market.quote_maturity_seconds + 1,
                    ),
                )
            self.assertIs(staged.code, market.ResultCode.STAGED)
            installed = protocol.apply_stage(
                seat_market,
                settlement.Clock(
                    block_number + seat_market.quote_maturity_blocks + 1,
                    staged.stage.handover_at,
                ),
            )
            return inserted, installed.tranche.installed_term_id

        def claim_premium(result):
            if result.premium_credit_id is not None and result.amount > 0:
                seat_market.claim_premium_credit(
                    result.premium_credit_id,
                    lambda _beneficiary, _amount, _market: None,
                )

        first_row, first_term = install_live(
            first_protocol,
            "v1-owner",
            2,
            settlement.GENESIS_TIMESTAMP + first_protocol.core.tip_slot,
            100,
        )
        first_release_row, first_release_term = install_live(
            first_protocol,
            "v1-release",
            3,
            settlement.GENESIS_TIMESTAMP + first_protocol.core.tip_slot + 20,
            120,
        )
        first_duty = activate_current_duty(
            first_protocol, open_recovery=False
        )
        first_activation_clock = settlement.Clock(
            max(first_history.last_canonical_l1_block + 10, 1_000),
            first_duty.slash_at + 1,
        )
        first_receipt = activate_production_fixture(
            rows, clock=first_activation_clock
        )
        self.assertIs(
            first_protocol.seat_duties[first_duty.duty_id].status,
            settlement.DutyStatus.BREACHED,
        )
        release_manager.execute_rotation(
            seat_market,
            first_receipt.key,
            market.Clock(
                first_activation_clock.timestamp + 2,
                first_activation_clock.block_number + 2,
            ),
        )
        seat_market.sync_seat_generation()
        second_protocol = second_history.live_protocol
        second_catchup_clock = settlement.Clock(
            second_history.last_canonical_l1_block + 4,
            first_activation_clock.timestamp + 3,
        )
        second_protocol.sync(second_catchup_clock)
        self.assertIs(second_protocol.mode, settlement.Mode.RECOVERY)
        second_recovery_clock = settlement.recovery_submit_clock(
            second_protocol
        )
        self.assertEqual(
            second_protocol.submit(
                settlement.escape_candidate(
                    second_protocol,
                    second_recovery_clock,
                    "v2-post-activation-catchup",
                ),
                second_recovery_clock,
            ),
            "COMMITTED",
        )
        self.assertEqual(seat_market.current_authorization_id, second_id)

        second_install_at = max(
            first_activation_clock.timestamp + 20,
            settlement.GENESIS_TIMESTAMP + second_protocol.core.tip_slot + 20,
        )
        second_row, second_term = install_live(
            second_protocol,
            "v2-owner",
            3,
            second_install_at,
            first_activation_clock.block_number + 20,
        )
        second_release_row, second_release_term = install_live(
            second_protocol,
            "v2-release",
            4,
            second_install_at + 20,
            first_activation_clock.block_number + 40,
        )
        second_duty = activate_current_duty(
            second_protocol, open_recovery=False
        )
        third_history, third_id = register_production_successor(
            rows, label="v3-ledger", protocol_version=27
        )
        second_activation_clock = settlement.Clock(
            max(second_history.last_canonical_l1_block + 10, 2_000),
            second_duty.slash_at + 1,
        )
        second_receipt = activate_registered_successor(
            rows,
            third_history,
            second_id,
            third_id,
            manifest_byte=b"v",
            clock=second_activation_clock,
        )
        self.assertIs(
            second_protocol.seat_duties[second_duty.duty_id].status,
            settlement.DutyStatus.BREACHED,
        )
        release_manager.execute_rotation(
            seat_market,
            second_receipt.key,
            market.Clock(
                second_activation_clock.timestamp + 2,
                second_activation_clock.block_number + 2,
            ),
        )
        seat_market.sync_seat_generation()
        third_protocol = third_history.live_protocol
        self.assertEqual(seat_market.current_authorization_id, third_id)
        self.assertEqual(
            (first_history.mode, second_history.mode, third_history.mode),
            ("FROZEN", "FROZEN", "ACTIVE"),
        )
        historical_profiles = tuple(
            manager.router.registrations[version].execution_profile
            for version in (25, 26, 27)
        )
        self.assertEqual(
            historical_profiles,
            (
                first_history.execution_profile,
                second_history.execution_profile,
                third_history.execution_profile,
            ),
        )
        self.assertEqual(len({
            profile.execution_profile_hash
            for profile in historical_profiles
        }), 3)
        self.assertEqual(len({
            id(profile.migration_transition_verifier)
            for profile in historical_profiles
        }), 3)
        for version, profile in zip((25, 26, 27), historical_profiles):
            self.assertEqual(
                manager.router.registrations[version]
                    .release_manifest.migration_transition_verifier,
                profile.migration_transition_verifier_descriptor,
            )

        economic_at = max(first_duty.slash_at, second_duty.slash_at) + 200

        def settle_historical_breach(protocol, row, term_id, duty, block, at):
            claim_premium(protocol.accrue_seat_premium(
                seat_market, term_id, settlement.Clock(block, at)
            ))
            claim_premium(protocol.reconcile_seat_reserve(
                seat_market, term_id, settlement.Clock(block + 1, at + 1)
            ))
            penalty = protocol.enforce_seat_breach(
                seat_market,
                row.tranche.tranche_id,
                term_id,
                settlement.Clock(block + 2, at + 2),
            )
            seat_market.claim_credit(
                penalty.credit_id,
                lambda _beneficiary, _amount, _market: None,
            )
            self.assertTrue(protocol.reclaim_duty_cell(
                seat_market,
                duty.duty_id,
                term_id,
                row.tranche.tranche_id,
                settlement.Clock(block + 3, at + 3),
            ))
            self.assertIs(
                seat_market.tranches[row.tranche.tranche_id].disposition,
                market.BondDisposition.PENALTY_CREDITED,
            )

        def settle_historical_release(protocol, row, term_id, block, at):
            claim_premium(protocol.accrue_seat_premium(
                seat_market, term_id, settlement.Clock(block, at)
            ))
            claim_premium(protocol.reconcile_seat_reserve(
                seat_market, term_id, settlement.Clock(block + 1, at + 1)
            ))
            protocol.request_bond_release(
                seat_market,
                row.tranche.tranche_id,
                term_id,
                settlement.Clock(block + 2, at + 2),
            )
            owner_release = protocol.finalize_bond_release(
                seat_market,
                row.tranche.tranche_id,
                term_id,
                settlement.Clock(block + 3, at + 200),
            )
            seat_market.claim_credit(
                owner_release.credit_id,
                lambda _beneficiary, _amount, _market: None,
            )
            self.assertIs(
                seat_market.tranches[row.tranche.tranche_id].disposition,
                market.BondDisposition.OWNER_CREDITED,
            )

        settle_historical_breach(
            first_protocol, first_row, first_term, first_duty,
            3_000, economic_at,
        )
        settle_historical_release(
            first_protocol, first_release_row, first_release_term,
            3_100, economic_at + 300,
        )
        settle_historical_breach(
            second_protocol, second_row, second_term, second_duty,
            3_200, economic_at + 600,
        )
        settle_historical_release(
            second_protocol, second_release_row, second_release_term,
            3_300, economic_at + 900,
        )

        for old_protocol, old_row, old_term in (
            (first_protocol, first_row, first_term),
            (second_protocol, second_row, second_term),
        ):
            with self.assertRaises(market.TransitionRejected):
                seat_market.insert_offer(
                    caller=addr("old-insert"),
                    payout=addr("old-insert-pay"),
                    ask_wei_per_second=1,
                    target=old_protocol.settlement_address,
                    generation=old_protocol.seat_generation,
                    clock=market.Clock(economic_at + 1_200, 3_400),
                    value=seat_market.sla_bond,
                )
            with self.assertRaises(market.TransitionRejected):
                seat_market.requote(
                    caller=old_row.offer.operator,
                    offer_id=old_row.offer.offer_id,
                    payout=old_row.offer.payout,
                    ask_wei_per_second=old_row.offer.ask_wei_per_second,
                    target=old_protocol.settlement_address,
                    generation=old_protocol.seat_generation,
                    clock=market.Clock(economic_at + 1_200, 3_400),
                )
            with self.assertRaises(ValueError):
                old_protocol.stage_best(
                    seat_market,
                    settlement.Clock(3_400, economic_at + 1_200),
                )
            with self.assertRaises(ValueError):
                old_protocol.apply_stage(
                    seat_market,
                    settlement.Clock(3_400, economic_at + 1_200),
                )

        third_catchup_clock = settlement.Clock(
            max(third_history.last_canonical_l1_block + 4, 3_400),
            economic_at + 1_200,
        )
        third_protocol.sync(third_catchup_clock)
        self.assertIs(third_protocol.mode, settlement.Mode.RECOVERY)
        third_recovery_clock = settlement.recovery_submit_clock(
            third_protocol
        )
        self.assertEqual(
            third_protocol.submit(
                settlement.escape_candidate(
                    third_protocol,
                    third_recovery_clock,
                    "v3-historical-settlement-catchup",
                ),
                third_recovery_clock,
            ),
            "COMMITTED",
        )
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        third_insert = seat_market.insert_offer(
            caller=addr("v3-owner"),
            payout=addr("pay-v3-owner"),
            ask_wei_per_second=1,
            target=third_protocol.settlement_address,
            generation=third_protocol.seat_generation,
            clock=market.Clock(economic_at + 1_201, 3_401),
            value=seat_market.sla_bond,
        )
        third_stage = third_protocol.stage_best(
            seat_market,
            settlement.Clock(
                3_401 + seat_market.quote_maturity_blocks,
                economic_at + 1_201 + seat_market.quote_maturity_seconds,
            ),
        )
        self.assertIs(third_stage.code, market.ResultCode.STAGED)
        self.assertEqual(third_stage.offer.offer_id, third_insert.offer.offer_id)

    def test_manager_arm_is_raw_exact_and_strict_slash_precedes_excuse(self):
        for delta, expected in (
            (-1, settlement.DutyStatus.EXCUSED_MIGRATION),
            (0, settlement.DutyStatus.EXCUSED_MIGRATION),
            (1, settlement.DutyStatus.BREACHED),
        ):
            protocol, manager = migration_manager_fixture()
            duty = activate_current_duty(protocol, open_recovery=False)
            before_generation = protocol.seat_generation
            visits_before = protocol.seat_scan_visits_total
            response = execute_manager_arm(
                manager,
                settlement.Clock(1_100, duty.slash_at + delta),
            )
            decoded = settlement.decode_seat_migration_response(response)
            self.assertEqual(len(response), settlement.SEAT_MIGRATION_RESPONSE_LENGTH)
            self.assertEqual(decoded.magic, settlement.SEAT_ARMED_MAGIC)
            self.assertEqual(
                (
                    decoded.router_generation,
                    decoded.active_protocol_version,
                    decoded.target_protocol_version,
                    decoded.target_manifest_hash,
                    decoded.seat_generation,
                ),
                (1, 25, 26, b"m" * 32, before_generation + 1),
            )
            self.assertEqual(protocol.migration_gate.mode, "ARMED")
            self.assertEqual(protocol.seat_generation, before_generation + 1)
            self.assertEqual(
                protocol.seat_scan_visits_total - visits_before, 4
            )
            self.assertEqual(protocol.seat_lineup, [])
            self.assertIs(protocol.seat_duties[duty.duty_id].status, expected)
            if expected is settlement.DutyStatus.BREACHED:
                self.assertGreater(
                    protocol.seat_duties[duty.duty_id].breach_recorded_at,
                    duty.slash_at,
                )

    def test_arm_commits_mature_best_without_ready_race_and_market_call(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        _, term_id = install_offer(
            protocol,
            seat_market,
            "mig",
            1,
            quoted_at=tip_time,
            quoted_block=100,
        )
        profile = settlement.execution_profile_for_test(
            25, "profile:seat-v1"
        )
        history = settlement.VersionedSettlementHistory(
            protocol.settlement_address,
            "runtime:seat-v1",
            25,
            profile.execution_profile_hash,
            copy.deepcopy(protocol.core),
            protocol.canonical.canonicalized_at_block,
            protocol.forced_queue,
            migration_gate=protocol.migration_gate,
            live_protocol=protocol,
            inbox_apply_descriptor=protocol.inbox_apply_descriptor,
            header_oracle=protocol.header_oracle,
            execution_profile=profile,
        )
        protocol.versioned_history = history
        router = settlement.deploy_active_settlement_router(
            history,
            addr("version-manager"),
            protocol.forced_queue,
            protocol.inbox_apply_router,
            protocol.migration_gate,
            protocol.header_oracle,
        )
        self.assertTrue(router.bootstrap(
            history,
            sequence=0,
            clock=settlement.Clock(
                protocol.canonical.canonicalized_at_block,
                settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
            ),
            caller=router.version_manager,
        ))
        gate = protocol.migration_gate
        manager = settlement.ProtocolVersionManager(
            addr("version-manager"), router
        )
        accepted = accept_qualifying_normal_best(
            protocol, term_id, block_number=1_000
        )
        canonical_before = protocol.core.l2_block_number
        visits_before = protocol.seat_scan_visits_total
        market_before = copy.deepcopy(seat_market)
        execute_manager_arm(
            manager,
            settlement.Clock(
                accepted.blocks[0].anchor_number + settlement.F_L1 + 2,
                protocol.normal_deadline,
            ),
        )
        self.assertGreater(protocol.core.l2_block_number, canonical_before)
        self.assertEqual(gate.mode, "ARMED")
        self.assertIsNotNone(protocol.seat_migration_arm)
        self.assertEqual(seat_market, market_before)
        self.assertEqual(protocol.seat_scan_visits_total - visits_before, 4)

    def test_arm_response_and_tuple_faults_restore_exact_router_protocol_graph(self):
        for fault in (
            "arm_response_empty",
            "arm_response_short",
            "arm_response_long",
            "arm_response_trailing",
            "arm_response_wrong_magic",
            "arm_response_wrong_generation",
            "arm_response_wrong_active_version",
            "arm_response_wrong_target_version",
            "arm_response_wrong_manifest",
            "arm_response_wrong_seat_generation",
            "after_local_migration_arm",
        ):
            protocol, manager = migration_manager_fixture()
            protocol.seat_fault_point = fault
            gate = protocol.migration_gate
            clock = settlement.Clock(
                1_100, settlement.GENESIS_TIMESTAMP + 1_001
            )
            manifest = settlement.ScheduledSeatMigration(
                1,
                25,
                26,
                b"m" * 32,
                clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
                clock.timestamp,
            )
            manager.schedule_seat_migration(
                manifest,
                caller=manager.governance,
                clock=settlement.Clock(
                    clock.block_number - 1, manifest.scheduled_at
                ),
            )
            before = migration_graph_projection(protocol, manager)
            with self.assertRaises((RuntimeError, ValueError, AssertionError)):
                manager.arm_seat_migration(
                    manifest_key=manifest.key,
                    executor=addr("executor"),
                    clock=clock,
                )
            self.assertEqual(
                migration_graph_projection(protocol, manager), before, fault
            )
            self.assertIs(protocol.migration_gate, gate)
            self.assertIs(
                manager.router.registrations[25].settlement.migration_gate,
                gate,
            )

    def test_direct_arm_and_abort_callbacks_bind_every_router_tuple_field(self):
        substitutions = (
            lambda word: replace(word, generation=word.generation + 1),
            lambda word: replace(word, active_version=word.active_version + 1),
            lambda word: replace(word, target_version=word.target_version + 1),
            lambda word: replace(word, target_manifest_hash=b"x" * 32),
            lambda word: replace(word, phase=settlement.RouterPhase.READY),
        )
        for substitute in substitutions:
            protocol, manager = migration_manager_fixture(seat=False)
            gate = protocol.migration_gate
            self.assertTrue(gate._arm_from_manager(
                1, 25, 26, b"m" * 32, caller=manager.address
            ))
            protocol.versioned_history.mode = "MIGRATION_ARMED"
            before = migration_graph_projection(protocol, manager)
            with self.assertRaises(ValueError):
                protocol.complete_seat_migration_arm(
                    caller=manager.address,
                    router_word=substitute(gate.router_word),
                    clock=settlement.Clock(
                        1_000, settlement.GENESIS_TIMESTAMP + 1_000
                    ),
                )
            self.assertEqual(migration_graph_projection(protocol, manager), before)

        protocol, manager = migration_manager_fixture(seat=False)
        gate = protocol.migration_gate
        self.assertTrue(gate._arm_from_manager(
            1, 25, 26, b"m" * 32, caller=manager.address
        ))
        protocol.versioned_history.mode = "MIGRATION_ARMED"
        before = migration_graph_projection(protocol, manager)
        with self.assertRaises(ValueError):
            protocol.complete_seat_migration_arm(
                caller=addr("attacker"), router_word=gate.router_word,
                clock=settlement.Clock(
                    1_000, settlement.GENESIS_TIMESTAMP + 1_000
                ),
            )
        self.assertEqual(migration_graph_projection(protocol, manager), before)

        for substitute in substitutions:
            protocol, manager = migration_manager_fixture(seat=False)
            execute_manager_arm(
                manager,
                settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000),
            )
            gate = protocol.migration_gate
            canceled = protocol.seat_migration_arm.router_word
            self.assertTrue(gate._abort_from_manager(
                canceled.generation,
                canceled.active_version,
                canceled.target_version,
                canceled.target_manifest_hash,
                cancel_manifest_active=True,
                caller=manager.address,
            ))
            protocol.versioned_history.mode = "ACTIVE"
            before = migration_graph_projection(protocol, manager)
            with self.assertRaises(ValueError):
                protocol.complete_seat_migration_abort(
                    caller=manager.address,
                    canceled_arm=substitute(canceled),
                    clock=settlement.Clock(
                        1_001, settlement.GENESIS_TIMESTAMP + 1_001
                    ),
                )
            self.assertEqual(migration_graph_projection(protocol, manager), before)

    def test_delayed_manifest_authority_boundaries_and_replay_are_exact(self):
        protocol, manager = migration_manager_fixture(seat=False)
        now = settlement.GENESIS_TIMESTAMP + 1_000
        too_early = settlement.ScheduledSeatMigration(
            1, 25, 26, b"e" * 32, now,
            now + settlement.SEAT_MIGRATION_MANIFEST_DELAY - 1,
        )
        before = migration_graph_projection(protocol, manager)
        with self.assertRaises(ValueError):
            manager.schedule_seat_migration(
                too_early,
                caller=manager.governance,
                clock=settlement.Clock(999, now),
            )
        self.assertEqual(migration_graph_projection(protocol, manager), before)
        exact = replace(
            too_early,
            target_manifest_hash=b"m" * 32,
            executable_at=now + settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        )
        with self.assertRaises(ValueError):
            manager.schedule_seat_migration(
                exact,
                caller=addr("attacker"),
                clock=settlement.Clock(999, now),
            )
        with self.assertRaises(ValueError):
            manager.schedule_seat_migration(
                replace(
                    exact,
                    scheduled_at=now - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
                ),
                caller=manager.governance,
                clock=settlement.Clock(999, now),
            )
        manager.schedule_seat_migration(
            exact,
            caller=manager.governance,
            clock=settlement.Clock(999, now),
        )
        with self.assertRaises(ValueError):
            manager.arm_seat_migration(
                manifest_key=exact.key,
                executor=addr("executor"),
                clock=settlement.Clock(1_000, exact.executable_at - 1),
            )
        manager.arm_seat_migration(
            manifest_key=exact.key,
            executor=addr("executor"),
            clock=settlement.Clock(1_001, exact.executable_at),
        )
        with self.assertRaises(ValueError):
            manager.arm_seat_migration(
                manifest_key=exact.key,
                executor=addr("executor"),
                clock=settlement.Clock(1_002, exact.executable_at + 1),
            )
    def test_abort_response_fault_matrix_restores_global_and_local_graph(self):
        for fault in (
            "abort_response_empty",
            "abort_response_short",
            "abort_response_long",
            "abort_response_trailing",
            "abort_response_wrong_magic",
            "abort_response_wrong_generation",
            "abort_response_wrong_active_version",
            "abort_response_wrong_target_version",
            "abort_response_wrong_manifest",
            "abort_response_wrong_seat_generation",
            "after_local_migration_abort",
        ):
            protocol, manager = migration_manager_fixture(seat=False)
            execute_manager_arm(
                manager,
                settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000),
            )
            protocol.seat_fault_point = fault
            clock = settlement.Clock(
                1_001, settlement.GENESIS_TIMESTAMP + 1_001
            )
            manifest = settlement.ScheduledSeatMigration(
                1, 25, 26, b"m" * 32,
                clock.timestamp - settlement.SEAT_MIGRATION_CANCEL_DELAY,
                clock.timestamp,
            )
            manager.schedule_seat_migration(
                manifest,
                caller=manager.governance,
                clock=settlement.Clock(
                    clock.block_number - 1, manifest.scheduled_at
                ),
                cancel=True,
            )
            before = migration_graph_projection(protocol, manager)
            with self.assertRaises((RuntimeError, ValueError, AssertionError)):
                manager.abort_seat_migration(
                    manifest_key=manifest.key,
                    executor=addr("executor"),
                    clock=clock,
                )
            self.assertEqual(migration_graph_projection(protocol, manager), before)
            protocol.seat_fault_point = None
            response = manager.abort_seat_migration(
                manifest_key=manifest.key,
                executor=addr("executor"),
                clock=clock,
            )
            self.assertEqual(
                settlement.decode_seat_migration_response(response).magic,
                settlement.SEAT_ABORTED_MAGIC,
            )
            self.assertEqual(protocol.migration_gate.mode, "ACTIVE")
            with self.assertRaises(ValueError):
                manager.abort_seat_migration(
                    manifest_key=manifest.key,
                    executor=addr("executor"),
                    clock=clock,
                )

    def test_abort_validates_retained_canceled_tuple_and_never_lowers_generation(self):
        protocol, manager = migration_manager_fixture(seat=False)
        execute_manager_arm(
            manager,
            settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000),
        )
        retained_generation = protocol.seat_generation
        clock = settlement.Clock(
            1_001,
            settlement.GENESIS_TIMESTAMP
            + protocol.core.tip_slot
            + settlement.DELTA_FINAL_LAG
            + 1,
        )
        response = execute_manager_abort(manager, clock)
        decoded = settlement.decode_seat_migration_response(response)
        self.assertEqual(decoded.magic, settlement.SEAT_ABORTED_MAGIC)
        self.assertEqual(decoded.target_manifest_hash, b"m" * 32)
        self.assertEqual(protocol.seat_generation, retained_generation)
        self.assertEqual(protocol.migration_gate.mode, "ACTIVE")
        self.assertIs(protocol.mode, settlement.Mode.RECOVERY)
        self.assertEqual(
            protocol.seat_migration_abort.canceled_arm,
            protocol.seat_migration_arm.router_word,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
