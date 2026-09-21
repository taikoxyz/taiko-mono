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
from unittest.mock import patch


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
commitment = load_module(
    "commitment_model_bounded_frontier",
    ROOT / "commitment-model.py",
)


def addr(label: str) -> str:
    raw = label.encode("ascii")
    if not raw or len(raw) > 20:
        raise ValueError("address label must contain 1..20 ASCII bytes")
    return "0x" + raw.ljust(20, b"\x00").hex()


def schedule_fork_row(
    digest: bytes,
    first_parent_slot: int,
    last_parent_slot_exclusive: int,
    *,
    gas: int = 500_000,
    runtime_domain: bytes = b"schedule-fork-runtime:",
) -> settlement.RegisterForkVerifierPayloadV1:
    gindices = settlement.CURRENT_SCHEDULE_FORK_GINDICES
    schema = settlement.current_schedule_ssz_multiproof_schema_hash_v1()
    selector = bytes.fromhex("7e981e0b")
    config = settlement.schedule_fork_verifier_configuration_hash_v1(
        digest, gindices, schema, selector, gas
    )
    return settlement.RegisterForkVerifierPayloadV1(
        digest,
        first_parent_slot,
        last_parent_slot_exclusive,
        settlement.keccak256(b"schedule-fork-verifier:" + digest)[12:],
        settlement.keccak256(runtime_domain + digest),
        *gindices,
        schema,
        config,
        selector,
        gas,
    )


def schedule_fork_world(
    *rows: settlement.RegisterForkVerifierPayloadV1,
) -> settlement.ScheduleForkVerifierWorldV1:
    world = settlement.ScheduleForkVerifierWorldV1()
    for row in rows:
        world.publish(row)
    return world


def authorization():
    # The Settlement is the existing Inbox proxy; the Market authorization
    # binds its address, chain, version and code identity.
    return market.TargetAuthorization(
        target=addr("inbox-proxy"),
        settlement_chain_id=1,
        protocol_version=25,
        runtime_hash=b"r" * 32,
        configuration_hash=b"c" * 32,
        expected_magic=b"SEAT",
        target_manifest_hash=b"m" * 32,
        target_registration_hash=b"g" * 32,
    )


class StandaloneSettlementAuthority:
    """Explicit unit target for non-migration composed Market tests."""

    def __init__(self, auth, generation):
        self.authorization = auth
        self.generation = generation
        self.live_protocol = None

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

    def seat_install_record_v1(self, term_id):
        if self.live_protocol is None:
            raise ValueError("standalone authority is not protocol-bound")
        return self.live_protocol.seat_install_record_v1(term_id)

    def seat_market_record_v1(self, term_id):
        if self.live_protocol is None:
            raise ValueError("standalone authority is not protocol-bound")
        return self.live_protocol.seat_market_record_v1(term_id)

    def seat_duty_record_v1(self, duty_id):
        if self.live_protocol is None:
            raise ValueError("standalone authority is not protocol-bound")
        return self.live_protocol.seat_duty_record_v1(duty_id)


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
        maximum_standby_lease_seconds=settlement.MAX_STANDBY_LEASE_SECONDS,
        minimum_standby_tenure_seconds=(
            settlement.MIN_STANDBY_TENURE_SECONDS
        ),
        minimum_ask_improvement_wei_per_second=(
            settlement.MIN_ASK_IMPROVEMENT_WEI_PER_SECOND
        ),
        minimum_ask_improvement_bps=settlement.MIN_ASK_IMPROVEMENT_BPS,
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
    authority.live_protocol = protocol
    return protocol, seat_market


def insert_offer(seat_market, operator, ask, timestamp, block_number):
    return seat_market.submit_seat_offer_v1(
        caller=addr(operator),
        payout=addr(f"pay-{operator}"),
        ask_wei_per_second=ask,
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
    row = seat_market.submit_seat_offer_v1(
        caller=addr(operator),
        payout=addr(f"pay-{operator}"),
        ask_wei_per_second=ask,
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


class CanonicalDutyTests(unittest.TestCase):
    def test_duty_and_selection_identity_goldens_are_exact_legacy_keccak(self):
        term = bytes.fromhex("11" * 32)
        tranche = bytes.fromhex("22" * 32)
        offer = bytes.fromhex("33" * 32)
        predecessor = bytes.fromhex("44" * 32)
        self.assertEqual(
            settlement.seat_duty_id_v1(term, 7, 9, 11).hex(),
            "9d3748bde1efb24b0352360aa2e155bbdbcd5b3caee4626a3a8902f78a2c9aaf",
        )
        self.assertEqual(
            settlement.seat_selection_id_v1(
                term,
                tranche,
                offer,
                13,
                15,
                17,
                settlement.SelectionSource.DUTY_FAILOVER,
                predecessor,
            ).hex(),
            "5778f1e12c1095f38c12bf31f7493fa92d6c90285c6d3ae357fe6efa6f04bdde",
        )
        self.assertEqual(
            settlement.seat_selection_id_v1(
                term,
                tranche,
                offer,
                13,
                15,
                17,
                settlement.SelectionSource.HEALTHY_EXPIRY,
                None,
            ).hex(),
            "66e2f28dd0812f714a4e1e78ade0467d76ee8acc088e9c793f3ea73c6893f8c7",
        )
        self.assertNotEqual(
            settlement.seat_duty_id_v1(term, 7, 9, 12),
            settlement.seat_duty_id_v1(term, 7, 9, 11),
        )
        with self.assertRaises(ValueError):
            settlement.seat_duty_id_v1(term, 7, 1 << 64, 11)

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
        self.assertEqual(duty.base_sequence, 0)
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
        sequence_only.seat_canonical_sequence += 1
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
        canonical_cure(
            both, both.seat_duties[duty.duty_id], at=duty.failover_at
        )
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
        self.assertEqual(duty.satisfied_at, failover_commit.timestamp)
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

    def test_prior_failover_sync_cannot_preempt_cure_through_slash_equality(self):
        for timestamp_kind in ("failover+1", "slash-1", "slash"):
            protocol, _, duty = self.primary()
            standby = synthetic_term(2, settlement.GENESIS_TIMESTAMP + 1_000)
            protocol.install_seat_term_for_test(
                standby, rank=1, start_primary=False
            )
            self.assertTrue(
                protocol.sync(settlement.Clock(1_250, duty.failover_at + 1))
            )
            self.assertIs(
                protocol.seat_duties[duty.duty_id].status,
                settlement.DutyStatus.FAILED_OVER,
            )
            timestamp = {
                "failover+1": duty.failover_at + 1,
                "slash-1": duty.slash_at - 1,
                "slash": duty.slash_at,
            }[timestamp_kind]
            canonical_cure(protocol, duty, at=timestamp)
            retained = protocol.seat_duties[duty.duty_id]
            self.assertIs(retained.status, settlement.DutyStatus.SATISFIED)
            self.assertEqual(retained.satisfied_at, timestamp)
            self.assertEqual(protocol.active_primary_term_id, standby.term_id)

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
        self.assertEqual(
            protocol.preview_premium_cap(primary.term_id), duty.recovery_at
        )

    def test_force_only_recovery_does_not_reset_attached_duty(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        service = protocol.seat_services[term.term_id]
        enqueue_clock = settlement.Clock(
            1_099,
            service.prospective_recovery_at - 10 - settlement.FORCE_DELAY,
        )
        descriptor = settlement.message(enqueue_clock.l2_slot, "force")
        self.assertEqual(
            protocol.forced_queue.enqueue(
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
        self.assertEqual(duty.satisfied_at, commit_clock.timestamp)
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

    def test_future_tip_lag_comparison_is_ordered_before_subtraction(self):
        protocol = settlement.protocol(tip_slot=1_024, seat=False)
        before_tip = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        self.assertFalse(protocol.sync(before_tip))
        self.assertIs(protocol.mode, settlement.Mode.NORMAL)
        self.assertFalse(
            settlement.strict_slot_lag_exceeds(1_000, 1_024, settlement.G_MAX)
        )
        self.assertFalse(
            settlement.strict_slot_lag_exceeds(
                1_024 + settlement.G_MAX,
                1_024,
                settlement.G_MAX,
            )
        )
        self.assertTrue(
            settlement.strict_slot_lag_exceeds(
                1_024 + settlement.G_MAX + 1,
                1_024,
                settlement.G_MAX,
            )
        )
        with self.assertRaises(ValueError):
            settlement.strict_slot_lag_exceeds(0, 0, settlement.UINT64_MAX + 1)


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
        fresh_base_tip = max(
            protocol.core.tip_slot,
            service.responsibility_start - settlement.GENESIS_TIMESTAMP,
        )
        original_recovery_at = (
            settlement.GENESIS_TIMESTAMP
            + fresh_base_tip
            + settlement.DELTA_RECOVERY_LAG
        )
        self.assertNotIn(term_id, protocol.term_duty)
        self.assertEqual(protocol.duty_sequence, 0)
        self.assertTrue(all(cell.reusable for cell in protocol.duty_ring))
        self.assertEqual(service.duty_base_tip_slot, fresh_base_tip)
        self.assertEqual(service.duty_base_sequence, 0)
        self.assertEqual(service.prospective_recovery_at, original_recovery_at)

        for round_index, target_tip in enumerate((
            fresh_base_tip + settlement.DELTA_RECOVERY_LAG,
            fresh_base_tip + 2 * settlement.DELTA_RECOVERY_LAG,
        )):
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
            self.assertEqual(service.duty_base_sequence, 1 + round_index)
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
        fresh_base_tip = max(
            protocol.core.tip_slot,
            term.installed_at - settlement.GENESIS_TIMESTAMP,
        )
        self.assertEqual(service.duty_base_tip_slot, fresh_base_tip)
        self.assertEqual(service.duty_base_sequence, 0)
        self.assertEqual(
            service.prospective_target_tip,
            fresh_base_tip + settlement.DELTA_RECOVERY_LAG,
        )
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
                expected_base_tip = (
                    old_base_tip + settlement.DELTA_RECOVERY_LAG
                )
                self.assertEqual(duty.base_tip_slot, expected_base_tip)
                self.assertEqual(duty.base_sequence, 1)
                self.assertEqual(
                    duty.recovery_at,
                    settlement.GENESIS_TIMESTAMP + expected_base_tip
                    + settlement.DELTA_RECOVERY_LAG,
                )
                self.assertEqual(
                    duty.failover_at,
                    settlement.GENESIS_TIMESTAMP + expected_base_tip
                    + settlement.DELTA_FINAL_LAG,
                )
                self.assertEqual(
                    duty.slash_at,
                    settlement.GENESIS_TIMESTAMP + expected_base_tip
                    + settlement.DELTA_SLASH_LAG,
                )
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

    def test_first_primary_duty_starts_at_apply_not_stale_canonical_tip(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        apply_at = tip_time + settlement.G_MAX
        stage_at = apply_at - settlement.HANDOVER_DELAY_SECONDS
        quote_at = stage_at - seat_market.quote_maturity_seconds
        quote_block = 100
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "boundary-primary", 1, quote_at, quote_block)
        staged = protocol.stage_best(
            seat_market,
            settlement.Clock(
                quote_block + seat_market.quote_maturity_blocks,
                stage_at,
            ),
        )
        self.assertEqual(staged.code, market.ResultCode.STAGED)
        self.assertEqual(staged.stage.handover_at, apply_at)

        installed = protocol.apply_stage(
            seat_market,
            settlement.Clock(
                quote_block + seat_market.quote_maturity_blocks + 1,
                apply_at,
            ),
        )
        term_id = installed.tranche.installed_term_id
        service = protocol.seat_services[term_id]
        fresh_base = apply_at - settlement.GENESIS_TIMESTAMP
        self.assertEqual(service.responsibility_start, apply_at)
        self.assertEqual(service.duty_base_tip_slot, fresh_base)
        self.assertEqual(
            service.prospective_recovery_at,
            apply_at + settlement.DELTA_RECOVERY_LAG,
        )
        self.assertEqual(
            service.prospective_failover_at,
            apply_at + settlement.DELTA_FINAL_LAG,
        )
        self.assertGreaterEqual(
            protocol.preview_premium_cap(term_id), service.responsibility_start
        )
        self.assertFalse(protocol.sync(settlement.Clock(500, apply_at)))
        self.assertNotIn(term_id, protocol.term_duty)
        self.assertFalse(
            protocol.sync(
                settlement.Clock(501, service.prospective_recovery_at)
            )
        )
        self.assertTrue(
            protocol.sync(
                settlement.Clock(502, service.prospective_recovery_at + 1)
            )
        )
        self.assertIn(term_id, protocol.term_duty)

    def test_competitive_primary_replacement_gets_its_own_fresh_duty(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        first_apply_at = tip_time + settlement.G_MAX
        first_stage_at = first_apply_at - settlement.HANDOVER_DELAY_SECONDS
        first_quote_at = first_stage_at - seat_market.quote_maturity_seconds
        seat_market.sponsor_premium(10 * seat_market.seat_runway_seconds)
        insert_offer(seat_market, "old-primary", 10, first_quote_at, 100)
        first_stage = protocol.stage_best(
            seat_market,
            settlement.Clock(
                100 + seat_market.quote_maturity_blocks,
                first_stage_at,
            ),
        )
        first_install = protocol.apply_stage(
            seat_market,
            settlement.Clock(
                101 + seat_market.quote_maturity_blocks,
                first_apply_at,
            ),
        )
        old_term = first_install.tranche.installed_term_id
        old_service = protocol.seat_services[old_term]
        self.assertEqual(old_service.duty_base_tip_slot, settlement.G_MAX + 1_000)

        replacement_apply_at = old_service.minimum_tenure_until
        replacement_stage_at = (
            replacement_apply_at - settlement.HANDOVER_DELAY_SECONDS
        )
        replacement_quote_at = (
            replacement_stage_at - seat_market.quote_maturity_seconds
        )
        insert_offer(
            seat_market,
            "new-primary",
            0,
            replacement_quote_at,
            200,
        )
        replacement_stage = protocol.stage_best(
            seat_market,
            settlement.Clock(
                200 + seat_market.quote_maturity_blocks,
                replacement_stage_at,
            ),
        )
        self.assertEqual(replacement_stage.stage.selected_rank, 0)
        self.assertEqual(
            replacement_stage.stage.outgoing_primary_term_id, old_term
        )
        self.assertEqual(
            replacement_stage.stage.handover_at, replacement_apply_at
        )
        replacement = protocol.apply_stage(
            seat_market,
            settlement.Clock(
                201 + seat_market.quote_maturity_blocks,
                replacement_apply_at,
            ),
        )
        new_term = replacement.tranche.installed_term_id
        new_service = protocol.seat_services[new_term]
        self.assertEqual(
            new_service.duty_base_tip_slot,
            replacement_apply_at - settlement.GENESIS_TIMESTAMP,
        )
        self.assertEqual(
            new_service.prospective_recovery_at,
            replacement_apply_at + settlement.DELTA_RECOVERY_LAG,
        )
        self.assertGreaterEqual(
            protocol.preview_premium_cap(new_term),
            new_service.responsibility_start,
        )
        self.assertEqual(
            protocol.seat_services[old_term].closed_at, replacement_apply_at
        )
        self.assertFalse(
            protocol.sync(
                settlement.Clock(500, new_service.prospective_recovery_at)
            )
        )
        self.assertNotIn(new_term, protocol.term_duty)

    def test_rank_zero_apply_after_old_final_lag_is_preempted_by_recovery(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        apply_at = tip_time + settlement.G_MAX + 1
        stage_at = apply_at - settlement.HANDOVER_DELAY_SECONDS
        quote_at = stage_at - seat_market.quote_maturity_seconds
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        insert_offer(seat_market, "late-primary", 1, quote_at, 100)
        staged = protocol.stage_best(
            seat_market,
            settlement.Clock(
                100 + seat_market.quote_maturity_blocks,
                stage_at,
            ),
        )
        stage_id = staged.stage.stage_id
        result = protocol.apply_stage(
            seat_market,
            settlement.Clock(
                101 + seat_market.quote_maturity_blocks,
                apply_at,
            ),
        )
        self.assertEqual(result, "SYNCED")
        self.assertIs(protocol.mode, settlement.Mode.RECOVERY)
        self.assertEqual(protocol.seat_lineup, [])
        self.assertIsNone(protocol.settlement_seat_stage)
        self.assertIn(stage_id, protocol.stage_tombstones)

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

    def test_ordinary_expiry_is_strictly_after_apply_equality(self):
        protocol, seat_market = make_pair()
        tip_time = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        seat_market.sponsor_premium(seat_market.seat_runway_seconds)
        row = insert_offer(seat_market, "a", 1, tip_time, 100)
        protocol.stage_best(
            seat_market, settlement.Clock(103, tip_time + 10)
        )
        stage = protocol.settlement_seat_stage
        before = (copy.deepcopy(protocol), copy.deepcopy(seat_market))
        for timestamp in (stage.expires_at - 1, stage.expires_at):
            with self.assertRaises(ValueError):
                protocol.expire_stage(
                    seat_market,
                    settlement.Clock(104, timestamp),
                )
            self.assertEqual(protocol, before[0])
            self.assertEqual(seat_market, before[1])

        equality_protocol = copy.deepcopy(protocol)
        equality_market = copy.deepcopy(seat_market)
        installed = equality_protocol.apply_stage(
            equality_market,
            settlement.Clock(105, stage.expires_at),
        )
        self.assertEqual(
            equality_protocol.active_primary_term_id,
            installed.tranche.installed_term_id,
        )
        with self.assertRaises(ValueError):
            equality_protocol.expire_stage(
                equality_market,
                settlement.Clock(106, stage.expires_at),
            )

        protocol.expire_stage(
            seat_market, settlement.Clock(104, stage.expires_at + 1)
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
                    settlement.Clock(104, stage.expires_at + 1),
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
                bad_protocol._record_seat_term(term)
                bad_protocol.seat_services[term.term_id] = settlement.SeatService(
                    None,
                    tip_time + 600,
                    None,
                    None,
                    standby_lease_expires_at=(
                        tip_time + settlement.MAX_STANDBY_LEASE_SECONDS
                    ),
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
        market_before_finalization = copy.deepcopy(seat_market)
        protocol.finalize_installed_exit(
            seat_market, primary, settlement.Clock(123, deadline)
        )
        self.assertEqual(seat_market, market_before_finalization)
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
        self.assertEqual(
            service.prospective_recovery_at,
            service.responsibility_start + settlement.DELTA_RECOVERY_LAG,
        )
        self.assertLess(expiry, service.prospective_recovery_at)
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
        self.assertIn(standby, seat_market.accounting.live_reserves)
        protocol.reconcile_seat_reserve(
            seat_market, standby, settlement.Clock(122, deadline)
        )
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
        recovery_at = service.prospective_recovery_at
        failover_at = service.prospective_failover_at
        self.assertNotIn(primary, protocol.term_duty)
        self.assertEqual(protocol.preview_premium_cap(primary), recovery_at)
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
            omitted.preview_premium_cap(primary), recovery_at
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
        # Fresh primary liability starts at the actual APPLY time, so these
        # runways place recovery at E-1, E, and E+1 respectively.
        for runway, relation in ((5_165, "DUTY"), (5_164, "EQUAL"), (5_163, "HEALTHY")):
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
                self.assertEqual(before_cap, duty.recovery_at)
                self.assertEqual(protocol.preview_premium_cap(primary), duty.recovery_at)
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
            "STANDBY_LEASE_EXPIRED",
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
                # Exercise the revision gate before the immutable standby
                # lease becomes due.  A public sync after both boundaries is
                # required to expire the lease first and therefore records
                # STANDBY_LEASE_EXPIRED instead.
                promote_at = protocol.seat_services[
                    successor
                ].standby_lease_expires_at - 1
                self.assertFalse(protocol._promote_selected(promote_at))
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
            protocol.preview_premium_cap(primary), duty.recovery_at
        )


class RingAndReclamationTests(unittest.TestCase):
    @staticmethod
    def fill_history_ring(protocol):
        duties = []
        installed_at = settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        for index in range(1, 5):
            term = synthetic_term(index, installed_at)
            protocol._record_seat_term(term)
            protocol.seat_services[term.term_id] = settlement.SeatService(
                installed_at,
                installed_at + settlement.MIN_PRIMARY_TENURE_SECONDS,
                installed_at + settlement.SEAT_RUNWAY_SECONDS,
                installed_at + settlement.SEAT_RUNWAY_SECONDS
                    - settlement.SLA_TAIL_SECONDS,
                closed_at=installed_at + index,
                close_reason="SATISFIED",
                term_removed_at=installed_at + index,
                standby_lease_expires_at=(
                    installed_at + protocol.maximum_standby_lease_seconds
                ),
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
            protocol.unresolved_duty_count -= 1
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


class BoundedFrontierAndDataSessionTests(unittest.TestCase):
    def test_forced_frontier_carries_and_matches_independent_full_tree(self):
        domain = b"slot-chain-force-node-v2"
        empty = [bytes(32) for _ in range(settlement.FORCE_TREE_DEPTH)]
        leaf = hashlib.sha256(b"leaf").digest()
        at_zero = settlement._append_frontier_leaf(
            empty, 0, leaf, node_domain=domain
        )
        self.assertEqual(at_zero[0], leaf)
        first = hashlib.sha256(b"first").digest()
        one = list(empty)
        one[0] = first
        at_one = settlement._append_frontier_leaf(
            one, 1, leaf, node_domain=domain
        )
        self.assertEqual(
            at_one[1],
            settlement.keccak256(domain + b"\x00" + first + leaf),
        )

        synthetic = [hashlib.sha256(f"f{height}".encode()).digest()
                     for height in range(settlement.FORCE_TREE_DEPTH)]
        expected = leaf
        for height in range(63):
            expected = settlement.keccak256(
                domain + bytes((height,)) + synthetic[height] + expected
            )
        carry_63 = settlement._append_frontier_leaf(
            synthetic, (1 << 63) - 1, leaf, node_domain=domain
        )
        self.assertEqual(carry_63[63], expected)
        max_minus_one = settlement._append_frontier_leaf(
            synthetic,
            settlement.UINT64_MAX - 1,
            leaf,
            node_domain=domain,
        )
        self.assertEqual(max_minus_one[0], leaf)
        self.assertEqual(
            len(settlement.force_wrapped_root(
                max_minus_one, settlement.UINT64_MAX
            )),
            64,
        )
        count_five = list(synthetic)
        baseline = settlement.force_wrapped_root(count_five, 5)
        stale = list(count_five)
        stale[1] = hashlib.sha256(b"ignored-zero-bit").digest()
        self.assertEqual(settlement.force_wrapped_root(stale, 5), baseline)
        used = list(count_five)
        used[2] = hashlib.sha256(b"used-bit").digest()
        self.assertNotEqual(settlement.force_wrapped_root(used, 5), baseline)
        with self.assertRaises(ValueError):
            settlement._append_frontier_leaf(
                synthetic,
                settlement.UINT64_MAX,
                leaf,
                node_domain=domain,
            )

        descriptors = [
            settlement.message(index, f"frontier-{index}")
            for index in range(65)
        ]
        original = settlement.force_frontier_from_descriptors
        try:
            settlement.force_frontier_from_descriptors = lambda _rows: (
                (_ for _ in ()).throw(AssertionError("frontier oracle alias"))
            )
            full_roots = {
                count: settlement.model_force_root(descriptors[:count])
                for count in (0, 1, 2, 3, 7, 8, 63, 64, 65)
            }
        finally:
            settlement.force_frontier_from_descriptors = original
        for count, root in full_roots.items():
            frontier = original(descriptors[:count])
            self.assertEqual(
                settlement.force_wrapped_root(frontier, count), root
            )

    def test_data_mmr_boundaries_and_inclusion_proof_are_exact(self):
        exact_session = commitment.session_id(1, 0xABCD, 0xCAFE, 2)
        exact_body = commitment.body_root((
            bytes.fromhex("0102"), bytes.fromhex("030405")
        ))
        exact_leaf_0 = commitment.data_leaf(
            exact_session, 0, bytes.fromhex("33" * 32), exact_body,
            0, 0, 2, b"alpha", 0xCAFE, 9_999, 5, 6,
        )
        exact_leaf_1 = commitment.data_leaf(
            exact_session, 1, bytes.fromhex("55" * 32), exact_body,
            0, 1, 2, b"beta", 0xCAFE, 9_999, 7, 8,
        )
        exact_frontier = [bytes(32)
                          for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)]
        exact_frontier, exact_count, _ = settlement.append_data_mmr(
            exact_frontier, 0, exact_leaf_0
        )
        exact_frontier, exact_count, exact_root = settlement.append_data_mmr(
            exact_frontier, exact_count, exact_leaf_1
        )
        self.assertEqual(exact_count, 2)
        self.assertEqual(
            exact_root,
            "d20459aeb2fe916a18dd584d39b2ae25075c6b6c14104d9d64a8b1d7882eb4df",
        )
        self.assertEqual(
            exact_root, commitment.mmr_root(
                (exact_leaf_0, exact_leaf_1)
            ).hex()
        )

        canonical_leaves = [
            hashlib.sha256(f"appendix-leaf-{index}".encode()).digest()
            for index in range(2_100)
        ]
        frontier = [bytes(32)
                    for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)]
        root = settlement.data_mmr_root(frontier, 0)
        checkpoints = {0, 1, 2, 3, 4, 7, 8, 2_047, 2_048, 2_099, 2_100}
        self.assertEqual(
            root,
            settlement.model_data_mmr_root(canonical_leaves[:0]),
        )
        for index, canonical_leaf in enumerate(canonical_leaves):
            frontier, count, root = settlement.append_data_mmr(
                frontier, index, canonical_leaf
            )
            self.assertEqual(count, index + 1)
            if count in checkpoints:
                self.assertEqual(
                    root,
                    settlement.model_data_mmr_root(canonical_leaves[:count]),
                )
        with self.assertRaises(ValueError):
            settlement.append_data_mmr(
                frontier,
                settlement.MAX_DATA_RECORDS_PER_SESSION,
                hashlib.sha256(b"overflow").digest(),
            )

        proof_leaves = canonical_leaves[:7]
        leaf, proof = settlement.model_data_mmr_proof(
            proof_leaves, 4
        )
        proof_root = settlement.model_data_mmr_root(proof_leaves)
        self.assertTrue(
            settlement.verify_data_mmr_proof(leaf, proof, proof_root)
        )
        self.assertEqual(tuple(row[0] for row in proof.other_peaks), (0, 2))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf, replace(proof, index=proof.count), proof_root
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf,
            replace(proof, siblings=proof.siblings + proof.siblings[:1]),
            proof_root,
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf, replace(proof, siblings=()), proof_root
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf,
            replace(proof, siblings=("00" * 32,) + proof.siblings[1:]),
            proof_root,
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf, replace(proof, other_peaks=tuple(reversed(proof.other_peaks))),
            proof_root,
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf, replace(proof, other_peaks=proof.other_peaks[:-1]), proof_root
        ))
        self.assertFalse(settlement.verify_data_mmr_proof(
            leaf,
            replace(proof, other_peaks=proof.other_peaks + proof.other_peaks[:1]),
            proof_root,
        ))

    @staticmethod
    def _post_terms(*, length=1, blob_base_fee=0, payment=0, salt=b"blob"):
        post = settlement.data_post_for_test(
            chunk_byte_length=length, salt=salt
        )
        versioned_hash = settlement.kzg_commitment_to_versioned_hash(
            post.commitment
        )
        return dict(
            posts=(post,),
            tx_blob_hashes=(versioned_hash,),
            blob_base_fee=blob_base_fee,
            payment=payment,
        )

    def test_open_is_exact_cell_atomic_and_checked_sequence(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        p = settlement.protocol(seat=False)
        owner = addr("atomic-open")
        expected = p.next_data_session_id(owner)
        self.assertEqual(p.open_session(
            now, owner, 7, expiry, payment=10
        ), expected)
        self.assertEqual(p.session_cell_by_id[expected], 8)
        self.assertIs(
            p.session_cells[7].tag, settlement.DataSessionCellTag.LIVE
        )
        self.assertEqual(
            (p.session_live_count, p.session_refund_count,
             p.session_occupied_count,
             p.settlement_eth_balance, p.data_session_live_bond_liability),
            (1, 0, 1, 10, 10),
        )
        self.assertEqual(p.data_session_events, [
            settlement.SessionOpenedEvent(
                expected, owner, 7, 0, expiry, 10, 0
            )
        ])

        failures = (
            (addr("front-run"), 7, 10),
            (addr("underpay"), 8, 9),
            (addr("overpay"), 8, 11),
            (addr("bad-cell"), 1_024, 10),
        )
        for candidate_owner, cell, payment in failures:
            before = p.snapshot()
            with self.assertRaises(settlement.DataSessionRevert):
                p.open_session(
                    now, candidate_owner, cell, expiry, payment=payment
                )
            self.assertTrue(p.identical(before))

        capped = settlement.protocol(seat=False)
        first_id = capped.next_data_session_id(owner)
        self.assertEqual(capped.open_session(
            now, owner, 0, expiry, payment=10
        ), first_id)
        second_id = capped.next_data_session_id(owner)
        self.assertEqual(capped.open_session(
            now, owner, 1, expiry, payment=10
        ), second_id)
        before = capped.snapshot()
        with self.assertRaises(settlement.DataSessionRevert):
            capped.open_session(now, owner, 2, expiry, payment=10)
        self.assertTrue(capped.identical(before))

        last = settlement.protocol(seat=False)
        last.next_session_sequence = settlement.UINT64_MAX - 1
        last_id = last.next_data_session_id(owner)
        self.assertEqual(last.open_session(
            now, owner, 0, expiry, payment=10
        ), last_id)
        self.assertEqual(last.next_session_sequence, settlement.UINT64_MAX)
        self.assertEqual(last.sessions[last_id].sequence,
                         settlement.UINT64_MAX - 1)
        before = last.snapshot()
        with self.assertRaises(settlement.DataSessionRevert):
            last.open_session(
                now, addr("after-max"), 1, expiry, payment=10
            )
        self.assertTrue(last.identical(before))

    def test_post_fee_blob_geometry_and_atomic_failures(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        p = settlement.protocol(
            seat=False,
            data_session_required_bond=7,
            data_session_base_rent_wei=3,
            data_session_rent_per_published_byte_wei=2,
            data_session_blob_base_fee_multiplier_bps=7_500,
            data_session_max_blobs_per_post=2,
        )
        owner = addr("fee-owner")
        session_id = p.next_data_session_id(owner)
        self.assertEqual(p.open_session(
            now, owner, 0, expiry, payment=10
        ), session_id)
        self.assertEqual(p.settlement_eth_balance, 10)
        self.assertEqual(p.data_session_live_bond_liability, 7)
        lengths = (0, 126_972)
        expected_fee = 843_768
        self.assertEqual(
            p.data_session_post_fee(lengths, 2, 3), expected_fee
        )
        leaves = (
            hashlib.sha256(b"exact-post-leaf-0").digest(),
            hashlib.sha256(b"exact-post-leaf-1").digest(),
        )
        posts = tuple(
            settlement.data_post_for_test(
                chunk_byte_length=length,
                salt=f"fee-{index}".encode(),
            )
            for index, (leaf, length) in enumerate(zip(leaves, lengths))
        )
        hashes = tuple(
            settlement.kzg_commitment_to_versioned_hash(post.commitment)
            for post in posts
        )
        derived_leaves = tuple(
            p.derive_data_post(p.sessions[session_id], index, post, blob_hash)[0]
            for index, (post, blob_hash) in enumerate(zip(posts, hashes))
        )
        posted = p.post_data(
            now,
            session_id,
            owner,
            posts=posts,
            tx_blob_hashes=hashes,
            blob_base_fee=3,
            payment=expected_fee,
        )
        self.assertEqual(posted, (
            0, 2, settlement.model_data_mmr_root(derived_leaves)
        ))
        self.assertEqual(p.sessions[session_id].count, 2)
        self.assertEqual(
            tuple((event.index, event.canonical_leaf)
                  for event in p.data_record_events),
            ((0, derived_leaves[0]), (1, derived_leaves[1])),
        )
        self.assertEqual(
            p.data_session_events[1:],
            [
                settlement.DataRecord(
                    session_id, index, hashes[index], derived_leaves[index],
                    posts[index].chunk_byte_length,
                )
                for index in range(2)
            ],
        )
        self.assertEqual(p.settlement_eth_balance, 10 + expected_fee)
        self.assertEqual(p.data_session_accounted_liabilities, 7)

        rejected = [
            dict(posts=posts,
                 tx_blob_hashes=hashes
                    + (hashlib.sha256(b"extra").digest(),),
                 blob_base_fee=3, payment=expected_fee),
            dict(posts=posts, tx_blob_hashes=hashes,
                 blob_base_fee=3, payment=expected_fee - 1),
            dict(posts=posts, tx_blob_hashes=hashes,
                 blob_base_fee=3, payment=expected_fee + 1),
            dict(posts=(replace(posts[0], chunk_byte_length=126_973),
                        posts[1]),
                 tx_blob_hashes=hashes,
                 blob_base_fee=3, payment=expected_fee),
        ]
        for terms in rejected:
            before = p.snapshot()
            before_events = copy.deepcopy(p.data_session_events)
            with self.assertRaises(settlement.DataSessionRevert):
                p.post_data(now, session_id, owner, **terms)
            self.assertTrue(p.identical(before))
            self.assertEqual(p.data_session_events, before_events)

        overflow = settlement.protocol(
            seat=False,
            data_session_rent_per_published_byte_wei=(
                settlement.SEAT_UINT256_MAX
            ),
        )
        overflow_id = overflow.next_data_session_id(owner)
        self.assertEqual(overflow.open_session(
            now, owner, 0, expiry, payment=10
        ), overflow_id)
        for length, base_fee in ((2, 0), (0, settlement.SEAT_UINT256_MAX)):
            before = overflow.snapshot()
            with self.assertRaises(settlement.DataSessionRevert):
                overflow.post_data(
                    now,
                    overflow_id,
                    owner,
                    **self._post_terms(
                        length=length, blob_base_fee=base_fee, payment=0,
                    ),
                )
            self.assertTrue(overflow.identical(before))

        full_precision = settlement.protocol(
            seat=False,
            data_session_blob_base_fee_multiplier_bps=1,
        )
        large_base_fee = settlement.SEAT_UINT256_MAX // 20
        exact = full_precision.data_session_post_fee(
            (0,), 1, large_base_fee
        )
        self.assertLessEqual(exact, settlement.SEAT_UINT256_MAX)
        self.assertEqual(
            exact,
            (131_072 * large_base_fee + 9_999) // 10_000,
        )
        structural = settlement.data_post_for_test()
        self.assertFalse(replace(structural, chunk_count=0).structurally_valid())
        self.assertTrue(structural.structurally_valid())
        self.assertTrue(replace(
            structural, chunk_index=8, chunk_count=9
        ).structurally_valid())
        self.assertFalse(replace(
            structural, chunk_count=10
        ).structurally_valid())

    def test_ordinary_scan_wrap_and_direct_live_claim_deltas(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        p = settlement.protocol(seat=False, refund_claim_window_seconds=100)
        for cell in range(8):
            p._install_data_session_for_test(
                settlement.DataSession(
                    f"live-{cell}", f"owner-{cell}",
                    now.timestamp + 1_000, refundable_bond=1,
                ),
                cell,
            )
        p._install_data_session_for_test(
            settlement.DataSession(
                "later-expired", "later-owner", now.timestamp,
                refundable_bond=9,
            ),
            8,
        )
        self.assertEqual(
            p.gc_sessions(now),
            (settlement.SESSION_MAINTENANCE_SCANNED, 8, 0, 8),
        )
        self.assertEqual(p.gc_cursor, 8)
        self.assertEqual(
            p.gc_sessions(now),
            (settlement.SESSION_MAINTENANCE_SCANNED, 8, 1, 16),
        )
        self.assertEqual(p.gc_cursor, 16)
        self.assertIs(
            p.session_cells[8].tag, settlement.DataSessionCellTag.REFUND
        )
        self.assertEqual(p.session_cells[8].refund_claim_deadline,
                         now.timestamp + 100)
        self.assertEqual(p.data_session_events[-2:], [
            settlement.SessionLiveToRefundEvent(
                "later-expired", "later-owner", 8,
                now.timestamp + 100, 0,
            ),
            settlement.DataSessionsMaintainedEvent(1, 8, 16, 8, 1),
        ])
        refund_view = p.data_session_view("later-expired")
        self.assertEqual(
            (refund_view.tag, refund_view.session_id, refund_view.owner,
             refund_view.refundable_bond, refund_view.refund_claim_deadline),
            (2, "later-expired", "later-owner", 9, now.timestamp + 100),
        )
        self.assertEqual(
            (refund_view.sequence, refund_view.expiry, refund_view.count,
             refund_view.sealed, refund_view.root,
             refund_view.frontier),
            (0, 0, 0, False, "",
             tuple(bytes(32) for _ in range(
                 settlement.DATA_MMR_FRONTIER_DEPTH))),
        )

        wrapped = settlement.protocol(
            seat=False, refund_claim_window_seconds=100
        )
        wrapped.gc_cursor = 1_020
        for cell in (1_020, 1_021, 1_022, 1_023, 0, 1, 2, 3):
            wrapped._install_data_session_for_test(
                settlement.DataSession(
                    f"wrap-{cell}", f"wrap-owner-{cell}", now.timestamp,
                    refundable_bond=1,
                ),
                cell,
            )
        self.assertEqual(
            wrapped.gc_sessions(now),
            (settlement.SESSION_MAINTENANCE_SCANNED, 8, 8, 4),
        )
        self.assertEqual(wrapped.gc_cursor, 4)
        self.assertEqual(
            (wrapped.session_live_count, wrapped.session_refund_count,
             wrapped.session_occupied_count),
            (0, 8, 8),
        )

        direct = settlement.protocol(
            seat=False, refund_claim_window_seconds=100
        )
        owner = addr("direct-live-owner")
        session = direct._install_data_session_for_test(
            settlement.DataSession(
                "direct-live", owner, now.timestamp, refundable_bond=10
            ),
            5,
        )
        receiver = settlement.DataSessionBondReceiver(addr("recipient"))
        self.assertEqual(direct.claim_data_session_refund(
            settlement.Clock(now.block_number, now.timestamp + 100),
            session.session_id,
            owner,
            receiver,
        ), 10)
        self.assertEqual(receiver.balance, 10)
        self.assertEqual(direct.data_session_events, [
            settlement.SessionBondClaimedEvent(
                session.session_id, owner, receiver.address, 10
            )
        ])
        self.assertEqual(
            (direct.session_live_count, direct.session_refund_count,
             direct.session_occupied_count,
             direct.data_session_live_bond_liability,
             direct.data_session_refund_bond_liability,
             direct.settlement_eth_balance),
            (0, 0, 0, 0, 0, 0),
        )
        self.assertNotIn(session.session_id, direct.session_cell_by_id)
        self.assertNotIn(owner, direct.session_owner_live_count)

    def test_point_evaluation_adapter_and_derived_leaf_are_exact(self):
        self.assertEqual(
            tuple(tag.value for tag in settlement.DataSessionCellTag),
            (0, 1, 2),
        )
        self.assertEqual(
            tuple(mode.value for mode in settlement.DataSessionMaintenanceMode),
            (1, 2, 3),
        )
        owner = "0x" + "00" * 18 + "cafe"
        settlement_address = "0x" + "00" * 18 + "abcd"
        p = settlement.protocol(
            seat=False,
            settlement_address=settlement_address,
            data_session_protocol_version=1,
        )
        p.next_session_sequence = 2
        session_id = p.next_data_session_id(owner)
        self.assertEqual(
            session_id,
            commitment.session_id(1, 0xABCD, 0xCAFE, 2).hex(),
        )
        session = p._install_data_session_for_test(
            settlement.DataSession(
                session_id, owner, 9_999, refundable_bond=10, sequence=2
            ),
            0,
        )
        body = commitment.body_root((b"\x01\x02", b"\x03\x04\x05"))
        chunk = b"alpha"
        croot = commitment.chunk_root(body, 0, 0, 2, chunk)
        post = settlement.DataPost(
            body, 0, 0, 2, len(chunk), croot, 6,
            b"c" * 32, b"c" * 16, b"p" * 32, b"p" * 16,
        )
        versioned_hash = settlement.kzg_commitment_to_versioned_hash(
            post.commitment
        )
        leaf, z, point_input = p.derive_data_post(
            session, 0, post, versioned_hash
        )
        self.assertEqual(z, commitment.fs_challenge(
            1, 1, bytes.fromhex(session_id), versioned_hash, body,
            0, 0, 2, len(chunk), croot, 0xCAFE, 9_999,
        ))
        self.assertEqual(leaf, commitment.data_leaf(
            bytes.fromhex(session_id), 0, versioned_hash, body,
            0, 0, 2, chunk, 0xCAFE, 9_999, z, 6,
        ))
        self.assertEqual(len(point_input), 192)
        self.assertEqual(point_input[:32], versioned_hash)
        now = settlement.Clock(1_000, 9_000)
        self.assertEqual(p.post_data(
            now, session_id, owner,
            posts=(post,),
            tx_blob_hashes=(versioned_hash,),
            blob_base_fee=0,
            payment=0,
        ), (0, 1, commitment.mmr_root((leaf,)).hex()))
        self.assertEqual(p.sessions[session_id].root,
                         commitment.mmr_root((leaf,)).hex())

        faults = (
            settlement.PointEvaluationAdapter(success=False),
            settlement.PointEvaluationAdapter(return_data=b"s" * 63),
            settlement.PointEvaluationAdapter(return_data=b"l" * 65),
            settlement.PointEvaluationAdapter(return_data=b"w" * 64),
        )
        for index, adapter in enumerate(faults):
            broken = settlement.protocol(
                seat=False, point_evaluation_adapter=adapter
            )
            broken_owner = addr(f"point-fault-{index}")
            expiry = now.timestamp + settlement.DATA_TTL_SECONDS
            broken_id = broken.next_data_session_id(broken_owner)
            self.assertEqual(broken.open_session(
                now, broken_owner, 0, expiry, payment=10
            ), broken_id)
            before = broken.snapshot()
            with self.assertRaises(settlement.DataSessionRevert):
                broken.post_data(
                    now, broken_id, broken_owner,
                    **self._post_terms(),
                )
            self.assertTrue(broken.identical(before))

        for forged_post, forged_hash in (
            (post, bytes((versioned_hash[0] ^ 1,)) + versioned_hash[1:]),
            (replace(post, commitment_lo=b"d" * 16), versioned_hash),
        ):
            before = p.snapshot()
            before_events = copy.deepcopy(p.data_session_events)
            with self.assertRaises(settlement.DataSessionRevert):
                p.post_data(
                    now, session_id, owner,
                    posts=(forged_post,),
                    tx_blob_hashes=(forged_hash,),
                    blob_base_fee=0,
                    payment=0,
                )
            self.assertTrue(p.identical(before))
            self.assertEqual(p.data_session_events, before_events)

        bounded = settlement.protocol(seat=False)
        bounded_owner = addr("bounded-post")
        bounded_id = bounded.next_data_session_id(bounded_owner)
        frontier = [bytes(32)
                    for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)]
        root = settlement.data_mmr_root(frontier, 0)
        for index in range(2_099):
            frontier, count, root = settlement.append_data_mmr(
                frontier, index,
                hashlib.sha256(f"existing-{index}".encode()).digest(),
            )
        bounded._install_data_session_for_test(
            settlement.DataSession(
                bounded_id, bounded_owner,
                now.timestamp + settlement.DATA_TTL_SECONDS,
                refundable_bond=10,
                count=2_099,
                frontier=frontier,
                root=root,
            ),
            0,
        )
        first = settlement.data_post_for_test(salt=b"cap-0")
        second = settlement.data_post_for_test(salt=b"cap-1")
        before = bounded.snapshot()
        with self.assertRaises(settlement.DataSessionRevert):
            bounded.post_data(
                now, bounded_id, bounded_owner,
                posts=(first, second),
                tx_blob_hashes=(
                    settlement.kzg_commitment_to_versioned_hash(first.commitment),
                    settlement.kzg_commitment_to_versioned_hash(second.commitment),
                ),
                blob_base_fee=0,
                payment=0,
            )
        self.assertTrue(bounded.identical(before))

    def test_refund_claim_equality_forfeit_stale_id_and_reentry(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        owner = addr("refund-owner")
        p = settlement.protocol(seat=False)
        p._install_data_session_for_test(
            settlement.DataSession(
                "refund-at-equality", owner, now.timestamp,
                refundable_bond=10,
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp + 10,
        )
        nested_results = []
        receiver = settlement.DataSessionBondReceiver(addr("nested-recipient"))
        def catch_nested_claim(protocol, sid):
            try:
                protocol.claim_data_session_refund(
                    settlement.Clock(now.block_number, now.timestamp + 10),
                    sid, owner, receiver
                )
            except settlement.DataSessionRevert:
                nested_results.append("REVERT")
        receiver.callback = catch_nested_claim
        self.assertEqual(p.claim_data_session_refund(
            settlement.Clock(now.block_number, now.timestamp + 10),
            "refund-at-equality", owner, receiver
        ), 10)
        self.assertEqual(nested_results, ["REVERT"])
        self.assertEqual(receiver.balance, 10)

        stale = "refund-after-deadline"
        q = settlement.protocol(seat=False)
        q._install_data_session_for_test(
            settlement.DataSession(
                stale, owner, now.timestamp, refundable_bond=10
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp + 10,
        )
        after = settlement.Clock(now.block_number, now.timestamp + 11)
        with self.assertRaises(settlement.DataSessionRevert):
            q.claim_data_session_refund(
                after, stale, owner,
                settlement.DataSessionBondReceiver(addr("late")),
            )
        self.assertEqual(
            q.gc_sessions(after),
            (settlement.SESSION_MAINTENANCE_SCANNED, 8, 1, 8),
        )
        self.assertEqual(q.data_session_events[-2:], [
            settlement.SessionRefundForfeitedEvent(
                stale, owner, 0, 10
            ),
            settlement.DataSessionsMaintainedEvent(1, 0, 8, 8, 1),
        ])
        self.assertIs(q.session_cells[0].tag,
                      settlement.DataSessionCellTag.FREE)
        self.assertNotIn(stale, q.session_cell_by_id)
        stale_frontier, stale_count, stale_root = settlement.append_data_mmr(
            [bytes(32) for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)],
            0,
            hashlib.sha256(b"stale-physical-leaf").digest(),
        )
        q.session_cells[0] = settlement.DataSessionCell(
            settlement.DataSessionCellTag.FREE,
            settlement.DataSession(
                "stale-physical", owner, now.timestamp,
                cell_index=0,
                count=stale_count,
                frontier=stale_frontier,
                root=stale_root,
                sealed=True,
            ),
            0,
        )
        q._assert_data_session_state()
        next_id = q.next_data_session_id(owner)
        fresh = settlement.protocol(seat=False)
        fresh.next_session_sequence = q.next_session_sequence
        self.assertEqual(fresh.next_data_session_id(owner), next_id)
        self.assertEqual(q.open_session(
            after, owner, 0, after.timestamp + settlement.DATA_TTL_SECONDS,
            payment=10,
        ), next_id)
        self.assertEqual(fresh.open_session(
            after, owner, 0, after.timestamp + settlement.DATA_TTL_SECONDS,
            payment=10,
        ), next_id)
        reused = q.sessions[next_id]
        self.assertEqual(
            (reused.count, reused.sealed, reused.root, reused.frontier),
            (0, False,
             settlement.data_mmr_root(
                 [bytes(32)
                  for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)], 0
             ),
             [bytes(32)
              for _ in range(settlement.DATA_MMR_FRONTIER_DEPTH)]),
        )
        terms = self._post_terms(salt=b"reuse")
        self.assertEqual(
            q.post_data(after, next_id, owner, **terms),
            fresh.post_data(after, next_id, owner, **terms),
        )
        self.assertEqual(q.sessions[next_id].root,
                         fresh.sessions[next_id].root)
        self.assertNotEqual(next_id, stale)
        with self.assertRaises(settlement.DataSessionRevert):
            q.post_data(
                after, stale, owner,
                **self._post_terms(salt=b"stale"),
            )

        rollback = settlement.protocol(seat=False)
        rollback._install_data_session_for_test(
            settlement.DataSession(
                "refund-rollback", owner, now.timestamp,
                refundable_bond=10,
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp + 10,
        )
        rejecting = settlement.DataSessionBondReceiver(addr("rejecting"))
        def mutate_then_revert(protocol, _sid):
            rejecting.address = addr("mutated-receiver")
            rejecting.rejects = True
            protocol.force_data_session_eth(99)
            protocol.tombstone()
            raise RuntimeError("receiver revert")
        rejecting.callback = mutate_then_revert
        before = rollback.snapshot()
        before_events = copy.deepcopy(rollback.data_session_events)
        with self.assertRaises(settlement.DataSessionRevert):
            rollback.claim_data_session_refund(
                now, "refund-rollback", owner, rejecting
            )
        self.assertTrue(rollback.identical(before))
        self.assertEqual(rollback.data_session_events, before_events)
        self.assertEqual(rejecting.balance, 0)
        self.assertEqual(rejecting.address, addr("rejecting"))
        self.assertFalse(rejecting.rejects)

    def test_post_and_seal_expiry_boundary_is_strict(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        owner = addr("expiry-owner")
        for offset in (-1, 0, 1):
            p = settlement.protocol(seat=False)
            session_id = p.next_data_session_id(owner)
            self.assertEqual(p.open_session(
                now, owner, 0, expiry, payment=10
            ), session_id)
            boundary = settlement.Clock(
                now.block_number + 1, expiry + offset
            )
            if offset < 0:
                post_result = p.post_data(
                    boundary, session_id, owner, **self._post_terms()
                )
                self.assertEqual(post_result[:2], (0, 1))
            else:
                with self.assertRaises(settlement.DataSessionRevert):
                    p.post_data(
                        boundary, session_id, owner, **self._post_terms()
                    )
                # Give SEAL a nonempty live sidecar without changing expiry.
                session = p.sessions[session_id]
                leaf = hashlib.sha256(b"fixture-seal-leaf").digest()
                session.frontier, session.count, session.root = (
                    settlement.append_data_mmr(
                        session.frontier, session.count, leaf
                    )
                )
            if offset < 0:
                self.assertEqual(
                    p.seal_session(boundary, session_id, owner),
                    (1, post_result[2], expiry),
                )
            else:
                with self.assertRaises(settlement.DataSessionRevert):
                    p.seal_session(boundary, session_id, owner)

    def test_bounded_sybil_cycles_surplus_and_sink_rollback(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        p = settlement.protocol(
            seat=False, refund_claim_window_seconds=1
        )
        for cycle in range(2):
            expiry = now.timestamp + settlement.DATA_TTL_SECONDS
            for cell in range(settlement.MAX_LIVE_DATA_SESSIONS):
                owner = f"cycle-{cycle}-owner-{cell}"
                self.assertNotEqual(p.open_session(
                    now, owner, cell, expiry, payment=10
                ), "REJECTED")
            self.assertLessEqual(len(p.session_cell_by_id), 1_024)
            self.assertFalse(hasattr(p, "data_session_claimable"))
            conversion = settlement.Clock(
                now.block_number + 1, expiry
            )
            for _ in range(129):
                p.gc_sessions(conversion)
                if p.session_live_count == 0:
                    break
            self.assertFalse(p.session_owner_live_count)
            forfeiture = settlement.Clock(
                now.block_number + 2, expiry + 2
            )
            for _ in range(129):
                p.gc_sessions(forfeiture)
                if p.session_occupied_count == 0:
                    break
            self.assertEqual(p.session_occupied_count, 0)
            self.assertFalse(p.session_cell_by_id)
            self.assertEqual(p.data_session_accounted_liabilities, 0)
        self.assertEqual(p.settlement_eth_balance, 20_480)
        self.assertTrue(p.force_data_session_eth(5))

        nested = []
        def catch_nested_sweep(protocol):
            try:
                protocol.sweep_session_surplus()
            except settlement.DataSessionRevert:
                nested.append("REVERT")
        p.data_rent_sink.callback = catch_nested_sweep
        self.assertEqual(p.sweep_session_surplus(), 20_485)
        self.assertEqual(nested, ["REVERT"])
        self.assertEqual(p.data_rent_sink.balance, 20_485)
        self.assertEqual(
            p.data_session_events[-1],
            settlement.SessionSurplusSweptEvent(
                p.data_rent_sink.address, 20_485
            ),
        )

        failing_sink = settlement.DataRentSink("failing-sink")
        q = settlement.protocol(seat=False, data_rent_sink=failing_sink)
        q.force_data_session_eth(100)
        def mutate_sink_then_revert(protocol):
            failing_sink.address = "mutated-sink"
            failing_sink.rejects = True
            protocol.force_data_session_eth(7)
            protocol.tombstone()
            raise RuntimeError("sink revert")
        failing_sink.callback = mutate_sink_then_revert
        before = q.snapshot()
        before_events = copy.deepcopy(q.data_session_events)
        with self.assertRaises(settlement.DataSessionRevert):
            q.sweep_session_surplus()
        self.assertTrue(q.identical(before))
        self.assertEqual(q.data_session_events, before_events)
        self.assertEqual(failing_sink.balance, 0)
        self.assertEqual(failing_sink.address, "failing-sink")
        self.assertFalse(failing_sink.rejects)

        equal = settlement.protocol(seat=False)
        owner = addr("equal-solvency")
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        self.assertNotEqual(equal.open_session(
            now, owner, 0, expiry, payment=10
        ), "REJECTED")
        self.assertEqual(equal.sweep_session_surplus(), 0)
        equal.settlement_eth_balance -= 1
        with self.assertRaises(settlement.DataSessionRevert):
            equal.sweep_session_surplus()
        with self.assertRaises(settlement.DataSessionRevert):
            equal.claim_data_session_refund(
                now, "missing", owner,
                settlement.DataSessionBondReceiver(addr("insolvent")),
            )

    def test_exact_session_view_abis_mask_union_words(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        p = settlement.protocol(seat=False)
        free_raw = p.data_session_cell_v1(0)
        miss_raw = p.data_session_by_id_v1("00" * 32)
        self.assertEqual(len(free_raw), 704)
        self.assertEqual(len(miss_raw), 320)
        self.assertEqual(
            settlement.decode_data_session_cell_v1(free_raw),
            settlement.DataSessionCellAbiV1(),
        )
        self.assertEqual(
            settlement.decode_data_session_by_id_v1(miss_raw),
            settlement.DataSessionByIdAbiV1(),
        )

        owner = "0x" + "12" * 20
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        session_id = p.next_data_session_id(owner)
        self.assertEqual(
            p.open_session(now, owner, 0, expiry, payment=10), session_id
        )
        post_result = p.post_data(
            now, session_id, owner, **self._post_terms(salt=b"view-live")
        )
        live_cell = settlement.decode_data_session_cell_v1(
            p.data_session_cell_v1(0)
        )
        live_by_id = settlement.decode_data_session_by_id_v1(
            p.data_session_by_id_v1(session_id)
        )
        self.assertEqual(
            (live_cell.tag, live_cell.session_id, live_cell.owner,
             live_cell.count, live_cell.root, live_cell.claim_deadline),
            (1, bytes.fromhex(session_id), bytes.fromhex("12" * 20),
             1, bytes.fromhex(post_result[2]), 0),
        )
        self.assertEqual(
            (live_by_id.cell_plus_one, live_by_id.tag, live_by_id.count,
             live_by_id.root),
            (1, 1, 1, bytes.fromhex(post_result[2])),
        )

        p._live_to_refund(0, expiry + 100)
        refund_cell = settlement.decode_data_session_cell_v1(
            p.data_session_cell_v1(0)
        )
        refund_by_id = settlement.decode_data_session_by_id_v1(
            p.data_session_by_id_v1(session_id)
        )
        self.assertEqual(
            (refund_cell.tag, refund_cell.session_id, refund_cell.owner,
             refund_cell.sequence, refund_cell.expiry, refund_cell.count,
             refund_cell.sealed, refund_cell.root, refund_cell.peaks,
             refund_cell.bond_wei, refund_cell.claim_deadline),
            (2, bytes.fromhex(session_id), bytes.fromhex("12" * 20),
             0, 0, 0, False, bytes(32),
             tuple(bytes(32) for _ in range(12)), 10, expiry + 100),
        )
        self.assertEqual(
            (refund_by_id.cell_plus_one, refund_by_id.tag,
             refund_by_id.sequence, refund_by_id.expiry,
             refund_by_id.count, refund_by_id.sealed, refund_by_id.root,
             refund_by_id.bond_wei, refund_by_id.claim_deadline),
            (1, 2, 0, 0, 0, False, bytes(32), 10, expiry + 100),
        )
        accounting_raw = p.data_session_accounting_v1()
        accounting = settlement.decode_data_session_accounting_v1(
            accounting_raw
        )
        self.assertEqual(len(accounting_raw), 448)
        self.assertEqual(
            (accounting.live_count, accounting.refund_count,
             accounting.occupied_count, accounting.live_bond_liability,
             accounting.refund_bond_liability),
            (0, 1, 1, 0, 10),
        )
        self.assertEqual(
            accounting.data_session_config_hash,
            p.data_session_config_hash_v1(),
        )
        for raw, decoder, padding_offset in (
            (free_raw, settlement.decode_data_session_cell_v1, 0),
            (miss_raw, settlement.decode_data_session_by_id_v1, 0),
            (accounting_raw, settlement.decode_data_session_accounting_v1, 4),
        ):
            for malformed in (raw[:-1], raw + b"\x00"):
                with self.assertRaises(ValueError):
                    decoder(malformed)
            mutated = bytearray(raw)
            mutated[padding_offset] ^= 1
            with self.assertRaises(ValueError):
                decoder(bytes(mutated))

    def test_session_refs_are_strictly_sorted_and_unique(self):
        p = settlement.protocol(seat=False)
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        session_ids = []
        for owner in (addr("ref-a"), addr("ref-b")):
            session_id = p.next_data_session_id(owner)
            self.assertEqual(p.open_session(
                now, owner, len(session_ids), expiry, payment=10
            ), session_id)
            post_result = p.post_data(
                now,
                session_id,
                owner,
                **self._post_terms(salt=f"body-{owner}".encode()),
            )
            self.assertEqual(post_result[:2], (0, 1))
            self.assertEqual(
                p.seal_session(now, session_id, owner),
                (1, post_result[2], expiry),
            )
            session_ids.append(session_id)
        refs = tuple(sorted((
            settlement.SessionRef(
                session_id,
                p.sessions[session_id].count,
                p.sessions[session_id].root,
            ) for session_id in session_ids
        ), key=lambda row: row.session_id))
        candidate = settlement.candidate(p, now, "sorted-refs")
        self.assertTrue(p._sessions_ok(
            replace(candidate, session_refs=refs), now
        ))
        self.assertFalse(p._sessions_ok(
            replace(candidate, session_refs=tuple(reversed(refs))), now
        ))
        self.assertFalse(p._sessions_ok(
            replace(candidate, session_refs=(refs[0], refs[0])), now
        ))


def reward_rows(*, class_one=(10, 2, 3, 100)):
    return (
        settlement.RewardClassV1(1, *class_one),
        settlement.RewardClassV1(2, 20, 3, 4, 200),
        settlement.RewardClassV1(3, 30, 4, 5, 300),
    )


def reward_protocol(
    rows=None, *, claim_window_seconds=100, reorg_margin_seconds=10
):
    registry = settlement.RewardClassRegistryV1(
        reward_rows() if rows is None else rows
    )
    return settlement.protocol(
        seat=False,
        refund_claim_window_seconds=claim_window_seconds,
        reward_reorg_margin_seconds=reorg_margin_seconds,
        reward_class_registry=registry,
        reward_execution_profile_hash=b"e" * 32,
    )


def reward_candidate(
    protocol,
    clock,
    candidate_id,
    *,
    tier=settlement.Tier.NORMAL_SIGNED,
    execution_gas=7,
    data_records=(),
    beneficiary=None,
):
    return settlement.candidate(
        protocol,
        clock,
        candidate_id,
        tier=tier,
        beneficiary=(
            addr("reward-beneficiary")
            if beneficiary is None else beneficiary
        ),
        gas_used=execution_gas,
        data_records=tuple(data_records),
    )


class RewardReceiptV1Tests(unittest.TestCase):
    def setUp(self):
        self.rows = reward_rows()
        self.claim_window_seconds = 100
        self.reorg_margin_seconds = 10
        self.protocol = reward_protocol(
            self.rows,
            claim_window_seconds=self.claim_window_seconds,
            reorg_margin_seconds=self.reorg_margin_seconds,
        )
        self.committed_at = settlement.Clock(
            901, settlement.GENESIS_TIMESTAMP + 1_001
        )

    def _record(self, candidate_id, **candidate_kwargs):
        candidate = reward_candidate(
            self.protocol,
            self.committed_at,
            candidate_id,
            **candidate_kwargs,
        )
        event = self.protocol._record_reward_receipt_v1(
            candidate, self.committed_at
        )
        cell = self.protocol.reward_receipts[candidate.tier.value][
            settlement.reward_receipt_index_v1(candidate_id)
        ]
        return candidate, event, cell

    def _fund(self, receipt, amount=None):
        exact_amount = (
            self.protocol.reward_amount_v1(
                receipt,
                self.protocol.reward_class_registry.class_by_id(
                    receipt.reward_class
                ),
            )
            if amount is None else amount
        )
        event = self.protocol.fund_reward_class_v1(
            receipt.reward_class,
            exact_amount,
            funder=addr("reward-funder"),
        )
        self.assertEqual(event, settlement.RewardClassFundedV1(
            receipt.reward_class,
            addr("reward-funder"),
            exact_amount,
            exact_amount,
            exact_amount,
        ))
        return exact_amount

    def _view(self, candidate_id):
        return self.protocol.reward_receipt_v1(
            settlement.REWARD_RECEIPT_V1_SELECTOR
            + settlement._model_fixed_bytes32(candidate_id),
            caller=addr("reward-viewer"),
            gas=settlement.REWARD_RECEIPT_READ_GAS,
            value=0,
        )

    def test_tier_is_the_only_reward_class_and_metrics_are_proof_bound(self):
        self.assertNotIn(
            "reward_class", settlement.Candidate.__dataclass_fields__
        )
        owner = addr("reward-publisher")
        session_id = self.protocol.next_data_session_id(owner)
        self.protocol._install_data_session_for_test(
            settlement.DataSession(
                session_id,
                owner,
                self.committed_at.timestamp + 1_000,
                refundable_bond=10,
            ),
            0,
        )
        posts = tuple(
            settlement.DataPost(
                bytes((marker,)) * 32,
                0,
                offset,
                2,
                length,
                bytes((marker + 10,)) * 32,
                marker,
                bytes((marker + 20,)) * 32,
                bytes((marker + 20,)) * 16,
                bytes((marker + 30,)) * 32,
                bytes((marker + 30,)) * 16,
            )
            for offset, (length, marker) in enumerate(((5, 1), (9, 2)))
        )
        versioned_hashes = tuple(
            settlement.kzg_commitment_to_versioned_hash(post.commitment)
            for post in posts
        )
        self.protocol.post_data(
            self.committed_at,
            session_id,
            owner,
            posts=posts,
            tx_blob_hashes=versioned_hashes,
            blob_base_fee=0,
            payment=0,
        )
        self.assertEqual(
            tuple(row.chunk_byte_length
                  for row in self.protocol.data_record_events),
            (5, 9),
        )
        self.protocol.seal_session(self.committed_at, session_id, owner)
        candidate, event, cell = self._record(
            "11" * 32,
            tier=settlement.Tier.NORMAL_SIGNED,
            execution_gas=7,
            data_records=((session_id, 0), (session_id, 1)),
        )
        receipt = cell.receipt
        self.assertTrue(event.receipt_stored)
        self.assertIsNotNone(receipt)
        self.assertEqual(receipt.reward_class, 1)
        self.assertEqual(event.candidate_id, receipt.candidate_id)
        self.assertEqual(event.beneficiary, receipt.beneficiary)
        self.assertEqual(event.reward_class, receipt.reward_class)
        self.assertEqual(
            event.reward_execution_gas, receipt.reward_execution_gas
        )
        self.assertEqual(
            event.reward_published_bytes, receipt.reward_published_bytes
        )
        self.assertEqual(event.receipt_index, 0x11)
        self.assertEqual(event.receipt_commitment, receipt.commitment)
        self.assertEqual(
            (receipt.reward_execution_gas, receipt.reward_published_bytes),
            (7, 14),
        )
        self.assertEqual(
            settlement.reward_candidate_metrics_v1(self.protocol, candidate),
            (7, 14),
        )
        duplicate = replace(
            candidate,
            blocks=(replace(
                candidate.blocks[0],
                data_records=((session_id, 0), (session_id, 0)),
            ),),
            reward_published_bytes=10,
        )
        self.assertFalse(settlement.reward_candidate_metrics_valid_v1(
            duplicate, self.protocol
        ))
        wrong_total = replace(candidate, reward_published_bytes=15)
        before_events = self.protocol.reward_events.copy()
        with self.assertRaises(AssertionError):
            self.protocol._record_reward_receipt_v1(
                wrong_total, self.committed_at
            )
        self.assertEqual(self.protocol.reward_events, before_events)

        hit = self._view(receipt.candidate_id)
        self.assertEqual(len(hit), 384)
        hit_words = tuple(hit[offset:offset + 32]
                          for offset in range(0, len(hit), 32))
        self.assertEqual(hit_words[0], b"RRV1" + bytes(28))
        self.assertEqual(hit_words[1], bytes(31) + b"\x01")
        self.assertEqual(hit_words[4], receipt.reward_execution_gas.to_bytes(32, "big"))
        self.assertEqual(hit_words[5], receipt.reward_published_bytes.to_bytes(32, "big"))
        self.assertEqual(hit_words[11], receipt.commitment)
        miss = self._view("99" * 31 + "11")
        self.assertEqual(miss[:32], b"RRV1" + bytes(28))
        self.assertEqual(miss[32:], bytes(352))

        amount = self._fund(receipt)
        self.assertFalse(cell.claimed)
        self.assertEqual(
            tuple(inspect.signature(self.protocol.claim_reward_v1).parameters),
            ("candidate_id", "clock", "transfer"),
        )
        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                "99" * 31 + "11", self.committed_at
            )
        self.assertFalse(cell.claimed)
        self.assertFalse(hasattr(settlement, "RewardDistributorV1"))
        self.assertEqual(self.protocol.claim_reward_v1(
            receipt.candidate_id, self.committed_at
        ), amount)

    def test_receipt_uses_seconds_and_allows_claim_at_exact_deadline(self):
        candidate, _, cell = self._record("22" * 32)
        receipt = cell.receipt
        self.assertEqual(receipt.committed_at_block, self.committed_at.block_number)
        self.assertEqual(
            receipt.committed_at_timestamp, self.committed_at.timestamp
        )
        self.assertEqual(
            receipt.claim_until,
            self.committed_at.timestamp
            + self.claim_window_seconds,
        )
        self.assertNotEqual(
            receipt.claim_until,
            self.committed_at.block_number
            + self.claim_window_seconds,
        )
        amount = self._fund(receipt)
        deadline = settlement.Clock(
            self.committed_at.block_number + 50_000,
            receipt.claim_until,
        )
        self.assertEqual(
            self.protocol.claim_reward_v1(receipt.candidate_id, deadline),
            amount,
        )

    def test_claimed_collision_reuses_at_exact_reorg_margin(self):
        _, _, first_cell = self._record("01" * 32)
        first = first_cell.receipt
        amount = self._fund(first)
        self.assertEqual(self.protocol.claim_reward_v1(
            first.candidate_id, self.committed_at
        ), amount)

        replacement = reward_candidate(
            self.protocol,
            self.committed_at,
            "02" * 31 + "01",
        )
        before_margin = settlement.Clock(
            self.committed_at.block_number + 1,
            self.committed_at.timestamp
            + self.reorg_margin_seconds - 1,
        )
        self.assertFalse(
            self.protocol._record_reward_receipt_v1(
                replacement, before_margin
            ).receipt_stored
        )
        at_margin = replace(
            before_margin, timestamp=before_margin.timestamp + 1
        )
        self.assertTrue(
            self.protocol._record_reward_receipt_v1(
                replacement, at_margin
            ).receipt_stored
        )
        self.assertEqual(first_cell.receipt.candidate_id, bytes.fromhex(
            replacement.candidate_id
        ))
        self.assertFalse(first_cell.claimed)

    def test_expired_collision_still_waits_for_reorg_margin(self):
        claim_window_seconds = 5
        reorg_margin_seconds = 10
        protocol = reward_protocol(
            self.rows,
            claim_window_seconds=claim_window_seconds,
            reorg_margin_seconds=reorg_margin_seconds,
        )
        first = reward_candidate(protocol, self.committed_at, "31" * 32)
        self.assertTrue(protocol._record_reward_receipt_v1(
            first, self.committed_at
        ).receipt_stored)
        replacement = reward_candidate(
            protocol, self.committed_at, "32" * 31 + "31"
        )
        at_claim_until = settlement.Clock(
            self.committed_at.block_number + 1,
            self.committed_at.timestamp
            + claim_window_seconds,
        )
        self.assertFalse(protocol._record_reward_receipt_v1(
            replacement, at_claim_until
        ).receipt_stored)
        expired_before_margin = settlement.Clock(
            self.committed_at.block_number + 1,
            self.committed_at.timestamp
            + claim_window_seconds
            + reorg_margin_seconds - 1,
        )
        self.assertFalse(protocol._record_reward_receipt_v1(
            replacement, expired_before_margin
        ).receipt_stored)
        at_margin = replace(expired_before_margin, timestamp=(
            self.committed_at.timestamp
            + claim_window_seconds
            + reorg_margin_seconds
        ))
        self.assertTrue(protocol._record_reward_receipt_v1(
            replacement, at_margin
        ).receipt_stored)

    def test_funding_shortage_does_not_consume_receipt(self):
        _, _, cell = self._record("44" * 32)
        receipt = cell.receipt
        amount = self.protocol.reward_amount_v1(
            receipt,
            self.protocol.reward_class_registry.class_by_id(
                receipt.reward_class
            ),
        )
        self.assertTrue(self.protocol.force_reward_eth_v1(amount * 2))
        self.assertEqual(self.protocol.reward_funded_by_class, {1: 0, 2: 0, 3: 0})
        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                receipt.candidate_id, self.committed_at
            )
        self.assertFalse(self.protocol.reward_receipt_state_v1(
            receipt.candidate_id
        )[1])
        self.assertEqual(self.protocol.sweep_session_surplus(), amount * 2)
        first_funding = self.protocol.fund_reward_class_v1(
            receipt.reward_class,
            amount - 1,
            funder=addr("reward-funder"),
        )
        self.assertEqual(first_funding, settlement.RewardClassFundedV1(
            receipt.reward_class,
            addr("reward-funder"),
            amount - 1,
            amount - 1,
            amount - 1,
        ))
        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                receipt.candidate_id, self.committed_at
            )
        self.assertFalse(self.protocol.reward_receipt_state_v1(
            receipt.candidate_id
        )[1])
        self.assertEqual(
            self.protocol.reward_funded_by_class[receipt.reward_class], amount - 1
        )
        second_funding = self.protocol.fund_reward_class_v1(
            receipt.reward_class, 1, funder=addr("second-funder")
        )
        self.assertEqual(second_funding, settlement.RewardClassFundedV1(
            receipt.reward_class,
            addr("second-funder"),
            1,
            amount,
            amount,
        ))
        accounting = settlement.decode_data_session_accounting_v1(
            self.protocol.data_session_accounting_v1()
        )
        self.assertEqual(
            (accounting.reward_funding_class_1,
             accounting.reward_funding_class_2,
             accounting.reward_funding_class_3,
             accounting.total_reward_funding),
            (amount, 0, 0, amount),
        )
        self.assertEqual(self.protocol.claim_reward_v1(
            receipt.candidate_id, self.committed_at
        ), amount)
        self.assertEqual(self.protocol.settlement_eth_balance, 0)
        self.assertEqual(self.protocol.total_reward_funding, 0)
        self.assertFalse(hasattr(self.protocol, "data_session_balance"))
        self.assertFalse(hasattr(self.protocol, "withdraw_reward_v1"))

        invalid = reward_protocol(self.rows)
        invalid_before = (
            invalid.reward_funded_by_class.copy(),
            invalid.total_reward_funding,
            invalid.settlement_eth_balance,
            invalid.reward_accounting_events.copy(),
        )
        for class_id, funding in ((4, 1), (1, 0)):
            with self.assertRaises(settlement.RewardFundingRevert):
                invalid.fund_reward_class_v1(
                    class_id, funding, funder=addr("invalid-funder")
                )
            self.assertEqual((
                invalid.reward_funded_by_class,
                invalid.total_reward_funding,
                invalid.settlement_eth_balance,
                invalid.reward_accounting_events,
            ), invalid_before)

    def test_transfer_failure_rolls_back_and_reentry_cannot_double_claim(self):
        _, _, cell = self._record("55" * 32)
        receipt = cell.receipt
        amount = self._fund(receipt)
        nested_clock = settlement.Clock(
            self.committed_at.block_number + 1,
            self.committed_at.timestamp + 2_000,
        )
        nested_candidate = reward_candidate(
            self.protocol, nested_clock, "56" * 32
        )
        snapshot = self.protocol.snapshot()
        caught = []

        def mutate_then_fail(_beneficiary, _amount, exact_settlement):
            for mutation in (
                lambda: exact_settlement.claim_reward_v1(
                    receipt.candidate_id, self.committed_at
                ),
                lambda: exact_settlement.sync(nested_clock),
                lambda: exact_settlement.submit(
                    nested_candidate, nested_clock
                ),
                exact_settlement.tombstone,
            ):
                try:
                    mutation()
                except settlement.SharedSettlementReentrancy:
                    caught.append(True)
            try:
                exact_settlement.fund_reward_class_v1(
                    1, 1, funder=addr("nested-funder")
                )
            except settlement.SharedSettlementReentrancy:
                caught.append(True)
            return False

        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                receipt.candidate_id,
                self.committed_at,
                transfer=mutate_then_fail,
            )
        self.assertEqual(caught, [True, True, True, True, True])
        self.assertEqual(self.protocol, snapshot)
        self.assertFalse(self.protocol.reward_receipt_state_v1(
            receipt.candidate_id
        )[1])
        self.assertEqual(
            len(self.protocol.reward_accounting_events), 1
        )

        uncaught_snapshot = self.protocol.snapshot()

        def uncaught_nested_mutation(
            _beneficiary, _amount, exact_settlement
        ):
            exact_settlement.sync(nested_clock)

        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                receipt.candidate_id,
                self.committed_at,
                transfer=uncaught_nested_mutation,
            )
        self.assertEqual(self.protocol, uncaught_snapshot)

        reentries = []

        def reenter(_beneficiary, _amount, exact_settlement):
            try:
                exact_settlement.claim_reward_v1(
                    receipt.candidate_id, self.committed_at
                )
            except settlement.SharedSettlementReentrancy:
                reentries.append("claim")
            try:
                exact_settlement.submit(nested_candidate, nested_clock)
            except settlement.SharedSettlementReentrancy:
                reentries.append("submit")
            return True

        self.assertEqual(self.protocol.claim_reward_v1(
            receipt.candidate_id, self.committed_at, transfer=reenter
        ), amount)
        self.assertEqual(reentries, ["claim", "submit"])
        self.assertTrue(self.protocol.reward_receipt_state_v1(
            receipt.candidate_id
        )[1])
        with self.assertRaises(settlement.RewardClaimRevert):
            self.protocol.claim_reward_v1(
                receipt.candidate_id, self.committed_at
            )
        self.assertEqual(len(self.protocol.reward_payments), 1)
        self.assertEqual(
            tuple(type(row) for row in self.protocol.reward_accounting_events),
            (settlement.RewardClassFundedV1, settlement.RewardClaimedV1),
        )

    def test_builder_registry_code_config_and_class_faults_revert_exactly(self):
        _, _, cell = self._record("58" * 32)
        receipt = cell.receipt
        amount = self._fund(receipt)
        faults = (
            ("observed_runtime_hash_override", b"x" * 32),
            ("component_config_return_override", b"y" * 32),
            ("return_overrides", {
                1: settlement.encode_reward_class_return_v1(
                    self.rows[1],
                    self.protocol.reward_class_registry_configuration_hash,
                )
            }),
        )
        for attribute, value in faults:
            setattr(self.protocol.reward_class_registry, attribute, value)
            snapshot = self.protocol.snapshot()
            with self.assertRaises(settlement.RewardClaimRevert):
                self.protocol.claim_reward_v1(
                    receipt.candidate_id, self.committed_at
                )
            self.assertEqual(self.protocol, snapshot)
            setattr(
                self.protocol.reward_class_registry,
                attribute,
                {} if attribute == "return_overrides" else None,
            )
        self.assertEqual(self.protocol.claim_reward_v1(
            receipt.candidate_id, self.committed_at
        ), amount)

    def test_zero_reward_consumes_without_transfer_and_emits_claim(self):
        rows = reward_rows(class_one=(0, 0, 0, 0))
        protocol = reward_protocol(rows)
        candidate = reward_candidate(
            protocol, self.committed_at, "59" * 32
        )
        self.assertTrue(protocol._record_reward_receipt_v1(
            candidate, self.committed_at
        ).receipt_stored)
        called = []
        self.assertEqual(protocol.claim_reward_v1(
            bytes.fromhex(candidate.candidate_id),
            self.committed_at,
            transfer=lambda *_args: called.append(True) or True,
        ), 0)
        self.assertEqual(called, [])
        self.assertTrue(protocol.reward_receipt_state_v1(
            candidate.candidate_id
        )[1])
        self.assertEqual(protocol.reward_accounting_events, [
            settlement.RewardClaimedV1(
                bytes.fromhex(candidate.candidate_id),
                candidate.beneficiary,
                1,
                0,
            )
        ])

    def test_cap_aware_arithmetic_never_builds_a_uint256_overflow(self):
        rows = reward_rows(
            class_one=(
                settlement.SEAT_UINT256_MAX - 5,
                settlement.SEAT_UINT256_MAX,
                settlement.SEAT_UINT256_MAX,
                settlement.SEAT_UINT256_MAX,
            )
        )
        protocol = reward_protocol(rows)
        protocol.data_record_events.append(settlement.DataRecord(
            "reward-wide-record",
            0,
            b"v" * 32,
            b"l" * 32,
            settlement.UINT64_MAX,
        ))
        candidate = reward_candidate(
            protocol,
            self.committed_at,
            "66" * 32,
            execution_gas=settlement.SEAT_UINT256_MAX,
            data_records=(("reward-wide-record", 0),),
        )
        protocol._record_reward_receipt_v1(candidate, self.committed_at)
        receipt = protocol.reward_receipts[1][0x66].receipt
        self.assertEqual(
            protocol.reward_amount_v1(receipt, rows[0]),
            settlement.SEAT_UINT256_MAX,
        )

    def test_first_middle_and_last_block_tiers_are_candidate_bound(self):
        protocol = settlement.protocol(seat=False)
        now = settlement.Clock(
            901, settlement.GENESIS_TIMESTAMP + 1_001
        )
        settlement.activate_normal(protocol, now)
        base = settlement.candidate(
            protocol, now, "three-block-tier", gas_used=1
        )
        first = base.blocks[0]
        middle = replace(
            first,
            slot=first.slot + 1,
            evm_timestamp=first.evm_timestamp + 1,
            block_hash="2" * 64,
            parent_hash=first.block_hash,
            gas_used=2,
        )
        last = replace(
            middle,
            slot=middle.slot + 1,
            evm_timestamp=middle.evm_timestamp + 1,
            block_hash="3" * 64,
            parent_hash=middle.block_hash,
            gas_used=3,
        )
        exact = replace(
            base,
            blocks=(first, middle, last),
            end_l2_block_number=protocol.core.l2_block_number + 3,
            reward_execution_gas=6,
        )
        self.assertTrue(protocol._valid_normal(exact, now))
        for position in (0, 1, 2):
            mixed = list(exact.blocks)
            mixed[position] = replace(
                mixed[position], tier=settlement.Tier.RECOVERY_SIGNED
            )
            self.assertFalse(protocol._valid_normal(
                replace(exact, blocks=tuple(mixed)), now
            ))

    def test_explicit_allocation_outcomes_and_local_corruption_scope(self):
        conversion = replace(
            reward_candidate(
                self.protocol, self.committed_at, "conversion-skip"
            ),
            candidate_id=object(),
        )
        decision = self.protocol._reward_receipt_allocation_decision_v1(
            conversion, self.committed_at
        )
        self.assertIs(
            decision.outcome,
            settlement.RewardReceiptAllocationOutcomeV1.SKIP_ID_CONVERSION,
        )
        self.assertFalse(self.protocol._record_reward_receipt_v1(
            conversion, self.committed_at
        ).receipt_stored)

        selected = reward_protocol(self.rows)
        selected_candidate = reward_candidate(
            selected, self.committed_at, "aa" * 32
        )
        selected.reward_receipts[1][0xAA] = \
            settlement.RewardReceiptCellV1(None, True)
        selected_snapshot = selected.snapshot()
        with self.assertRaises(AssertionError):
            selected._commit(selected_candidate, self.committed_at)
        self.assertEqual(selected, selected_snapshot)

        unrelated = reward_protocol(self.rows)
        unrelated.reward_receipts[1][0xAB] = \
            settlement.RewardReceiptCellV1(None, True)
        self.assertFalse(unrelated._reward_receipt_state_valid_v1())
        unrelated_candidate = reward_candidate(
            unrelated, self.committed_at, "aa" * 32
        )
        prior_l2_block = unrelated.core.l2_block_number
        unrelated._commit(unrelated_candidate, self.committed_at)
        self.assertEqual(
            unrelated.core.l2_block_number, prior_l2_block + 1
        )
        self.assertTrue(unrelated.reward_events[-1].receipt_stored)

    def test_class_local_ring_capacity_and_deadline_skip_canonical_progress(self):
        # A full class-1 ring still retains the documented same-class
        # low-byte collision behavior, but cannot consume class-3 capacity.
        for index in range(settlement.MAX_REWARD_RECEIPTS):
            candidate_id = ((1 << 248) | index).to_bytes(32, "big").hex()
            candidate = reward_candidate(
                self.protocol, self.committed_at, candidate_id
            )
            self.assertTrue(self.protocol._record_reward_receipt_v1(
                candidate, self.committed_at
            ).receipt_stored)
        self.assertTrue(all(
            cell.receipt is not None
            for cell in self.protocol.reward_receipts[1]
        ))
        class_three = reward_candidate(
            self.protocol,
            self.committed_at,
            ((3 << 248) | 42).to_bytes(32, "big").hex(),
            tier=settlement.Tier.ESCAPE_UNSIGNED,
        )
        class_three_event = self.protocol._record_reward_receipt_v1(
            class_three, self.committed_at
        )
        self.assertTrue(class_three_event.receipt_stored)
        self.assertEqual(
            self.protocol.reward_receipts[3][42].receipt.candidate_id,
            bytes.fromhex(class_three.candidate_id),
        )
        self.assertEqual(
            self.protocol.reward_receipt_state_v1(class_three.candidate_id)[0],
            self.protocol.reward_receipts[3][42].receipt,
        )

        progress_clock = settlement.Clock(
            self.committed_at.block_number + 1,
            self.committed_at.timestamp + 1,
        )
        colliding = reward_candidate(
            self.protocol,
            progress_clock,
            ((2 << 248) | 42).to_bytes(32, "big").hex(),
        )
        prior_l2_block = self.protocol.core.l2_block_number
        self.protocol._commit(colliding, progress_clock)
        self.assertEqual(
            self.protocol.core.l2_block_number, prior_l2_block + 1
        )
        self.assertFalse(self.protocol.reward_events[-1].receipt_stored)

        overflow_protocol = reward_protocol(self.rows)
        overflow_clock = settlement.Clock(901, settlement.UINT64_MAX)
        overflow = reward_candidate(
            overflow_protocol, overflow_clock, "77" * 32
        )
        prior_l2_block = overflow_protocol.core.l2_block_number
        overflow_protocol._commit(overflow, overflow_clock)
        self.assertEqual(
            overflow_protocol.core.l2_block_number, prior_l2_block + 1
        )
        self.assertFalse(
            overflow_protocol.reward_events[-1].receipt_stored
        )
        self.assertIsNone(
            overflow_protocol.reward_receipts[1][0x77].receipt
        )


class RegistryLifecycleRound4Tests(unittest.TestCase):
    """Adversarial boundaries for the Round-4 BuilderRegistry closure."""

    @staticmethod
    def generation(index, *, bond=None, effective_window=8):
        return settlement.Generation(
            f"registry-builder-{index}",
            index + 1 if bond is None else bond,
            index,
            effective_window,
        )

    def test_penalty_sink_cannot_be_the_registry_and_exit_sequence_exhausts_safely(self):
        with self.assertRaisesRegex(ValueError, "malformed BuilderRegistry geometry"):
            settlement.RegistryLifecycle(
                [], registry_address="registry", penalty_sink="registry"
            )

        first = self.generation(0, bond=100, effective_window=0)
        last = self.generation(1, bond=101, effective_window=0)
        registry = settlement.RegistryLifecycle([first, last])
        registry.next_exit_sequence = settlement.UINT64_MAX - 1
        self.assertTrue(registry.request_exit(
            first.address, 0, caller=first.address
        ))
        self.assertEqual(first.registration_index, registry.exit_requests[
            settlement.UINT64_MAX - 1
        ].registration_index)
        self.assertEqual(registry.next_exit_sequence, settlement.UINT64_MAX)
        before = (
            registry.active[1], dict(registry.exit_requests),
            dict(registry.exit_by_registration), registry.next_exit_sequence,
        )
        self.assertFalse(registry.request_exit(
            last.address, 0, caller=last.address
        ))
        self.assertEqual((
            registry.active[1], dict(registry.exit_requests),
            dict(registry.exit_by_registration), registry.next_exit_sequence,
        ), before)

    def test_constructor_enforces_liability_ring_residence_capacity(self):
        largest_safe_delay = 248 * settlement.SCHEDULE_WINDOW_SLOTS
        safe = settlement.RegistryLifecycle(
            [], evidence_delay_seconds=largest_safe_delay,
            reorg_margin_seconds=0,
        )
        self.assertEqual(
            settlement.maximum_liability_residence_windows_v1(
                safe.evidence_delay_seconds, safe.reorg_margin_seconds
            ),
            settlement.MAX_LIVE_WINDOWS - 1,
        )
        with self.assertRaisesRegex(
            ValueError, "malformed BuilderRegistry geometry"
        ):
            settlement.RegistryLifecycle(
                [], evidence_delay_seconds=largest_safe_delay + 1,
                reorg_margin_seconds=0,
            )

    def test_self_consent_and_lowest_vacancy_cover_cell_zero_and_sixty_three(self):
        registry = settlement.RegistryLifecycle([])
        first = self.generation(0)
        self.assertFalse(registry.admit(first, 0, caller="attacker"))
        self.assertTrue(registry.admit(first, 0, caller=first.address))
        self.assertEqual(registry.active[0].address, first.address)
        self.assertEqual(registry.active[0].registration_index, 0)
        self.assertEqual(registry.active[0].effective_l2_slot, 8 * 384)
        for index in range(1, 64):
            generation = self.generation(index)
            self.assertTrue(registry.admit(
                generation, 0, caller=generation.address
            ))
        self.assertEqual(registry.active[63].registration_index, 63)
        self.assertEqual(registry.active_count, 64)

        removed = registry.active[17]
        self.assertIsNotNone(removed)
        registry.active[17] = None
        registry._clear_generation_index(
            removed, expected=("ACTIVE", 17)
        )
        hole = self.generation(64, bond=10_000)
        self.assertTrue(registry.admit(hole, 0, caller=hole.address))
        self.assertEqual(registry.active[17].address, hole.address)
        self.assertEqual(registry.active[17].registration_index, 64)

    def test_reverse_indexes_cover_uint64_max_move_and_final_release(self):
        maximum = self.generation(
            settlement.UINT64_MAX, bond=100, effective_window=0
        )
        registry = settlement.RegistryLifecycle([])
        registry.next_registration_index = settlement.UINT64_MAX
        self.assertTrue(registry.admit(
            maximum, 0, caller=maximum.address
        ))
        self.assertEqual(
            registry.live_registration_index_plus_one[maximum.address],
            settlement.UINT64_MAX + 1,
        )
        self.assertEqual(
            registry.generation_locations[settlement.UINT64_MAX],
            ("ACTIVE", 0),
        )
        self.assertEqual(
            registry.next_registration_index, settlement.UINT64_MAX + 1
        )
        exhausted_snapshot = (
            tuple(registry.active), tuple(registry.liability_ring),
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.base_bond_escrow, registry.token_balance,
        )
        self.assertFalse(registry.admit(
            settlement.Generation("exhausted", 101, 0, 0),
            0,
            caller="exhausted",
        ))
        self.assertEqual((
            tuple(registry.active), tuple(registry.liability_ring),
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.base_bond_escrow, registry.token_balance,
        ), exhausted_snapshot)

        cursor = settlement.ScheduleReleaseCursor(
            next_release_window=settlement.UINT64_MAX
        )
        self.assertTrue(registry.release_terminal_active(0, 1, cursor))
        self.assertNotIn(
            settlement.UINT64_MAX, registry.generation_locations
        )
        self.assertNotIn(
            maximum.address, registry.live_registration_index_plus_one
        )
        self.assertFalse(registry.admit(
            settlement.Generation(
                maximum.address, 101, settlement.UINT64_MAX, 0
            ),
            0,
            caller=maximum.address,
        ))
        registry.audit_lifecycle_invariants()

    def test_restart_preserves_released_registration_holes_and_exhaustion(self):
        # Released generations are deliberately absent from the live reverse
        # indexes.  A restarted model must retain the monotonic stored counter
        # instead of deriving it back down from only the surviving rows.
        restarted = settlement.RegistryLifecycle(
            [], next_registration_index=123
        )
        generation = settlement.Generation(
            "post-restart", 10_000, 123, 0
        )
        self.assertTrue(restarted.admit(
            generation, 0, caller=generation.address
        ))
        self.assertEqual(restarted.next_registration_index, 124)

        survivor = settlement.Generation("survivor", 50, 10, 0)
        with_hole = settlement.RegistryLifecycle(
            [survivor], next_registration_index=20
        )
        self.assertEqual(with_hole.next_registration_index, 20)
        with self.assertRaisesRegex(ValueError, "next registration"):
            settlement.RegistryLifecycle(
                [survivor], next_registration_index=10
            )

        exhausted = settlement.RegistryLifecycle(
            [], next_registration_index=settlement.UINT64_MAX + 1
        )
        self.assertFalse(exhausted.admit(
            settlement.Generation("never-reused", 50, 0, 0),
            0,
            caller="never-reused",
        ))
        self.assertEqual(
            exhausted.next_registration_index,
            settlement.UINT64_MAX + 1,
        )

    def test_brh1_exhausted_sentinel_is_width_safe_and_canonical(self):
        ordinary = commitment.builder_registry_header(
            63,
            0x0102030405060708,
            0x1112131415161718,
            0x2122232425262728,
        )
        self.assertEqual(
            ordinary.hex(),
            "42524831013f00000102030405060708"
            "11121314151617182122232425262728",
        )
        self.assertEqual(
            commitment.decode_builder_registry_header(ordinary),
            (63, 0x0102030405060708, 0x1112131415161718,
             0x2122232425262728),
        )
        last_ordinary = commitment.builder_registry_header(
            64, settlement.UINT64_MAX, settlement.UINT64_MAX,
            settlement.UINT64_MAX,
        )
        self.assertEqual(last_ordinary[6:8], b"\x00\x00")
        self.assertEqual(last_ordinary[24:], b"\xff" * 8)
        exhausted = commitment.builder_registry_header(
            64, settlement.UINT64_MAX, settlement.UINT64_MAX,
            settlement.UINT64_MAX + 1,
        )
        self.assertEqual(exhausted[6:8], b"\x01\x00")
        self.assertEqual(exhausted[24:], bytes(8))
        self.assertEqual(
            commitment.decode_builder_registry_header(exhausted)[3],
            settlement.UINT64_MAX + 1,
        )
        noncanonical = (
            exhausted[:6] + b"\x02" + exhausted[7:],
            exhausted[:7] + b"\x01" + exhausted[8:],
            exhausted[:24] + (1).to_bytes(8, "big"),
        )
        for raw_word in noncanonical:
            with self.subTest(raw_word=raw_word.hex()):
                with self.assertRaises(ValueError):
                    commitment.decode_builder_registry_header(raw_word)
        with self.assertRaises(AssertionError):
            commitment.builder_registry_header(
                0, 0, 0, settlement.UINT64_MAX + 2
            )

    def test_bitmap_counter_and_credit_hot_paths_do_not_iterate_history(self):
        class NoIterationDict(dict):
            def __iter__(self):
                raise AssertionError("hot path iterated a lifetime mapping")

            def items(self):
                raise AssertionError("hot path iterated a lifetime mapping")

            def values(self):
                raise AssertionError("hot path iterated a lifetime mapping")

        class NoIterationSet(set):
            def __iter__(self):
                raise AssertionError("hot path iterated a lifetime set")

        self.assertTrue(gate._bootstrap_from_router(1))
        builder = self.generation(0, bond=100, effective_window=0)
        registry = settlement.RegistryLifecycle(
            [builder], lease_per_window_atomic=10
        )
        for window in (0, 1, 2):
            self.assertTrue(registry.reserve(builder.address, window, 0))
        registry.tranches = NoIterationDict(registry.tranches)
        registry.open_reservations = NoIterationSet(
            registry.open_reservations
        )
        registry.liable_reservations = NoIterationSet(
            registry.liable_reservations
        )
        self.assertEqual(registry.normalize_reservations(0, 2), 2)
        self.assertEqual(registry.active[0].reservation_bitmap, 1)

        full = settlement.RegistryLifecycle([
            self.generation(index, bond=100 + index, effective_window=0)
            for index in range(64)
        ])
        newcomer = self.generation(64, bond=10_000, effective_window=0)
        self.assertTrue(full.admit(newcomer, 0, caller=newcomer.address))
        retained, release_window = full.liability_ring[0]
        full.tranches = NoIterationDict(full.tranches)
        full.credits = NoIterationDict(full.credits)
        self.assertTrue(full.release_liability(0, release_window))
        self.assertEqual(full.total_credit_liability, retained.bond)
        self.assertEqual(
            full.claim_credit(retained.address, "recipient",
                              caller=retained.address),
            retained.bond,
        )
        self.assertEqual(full.total_credit_liability, 0)

    def test_lifecycle_index_corruption_is_detected_without_fallback_scan(self):
        registry = settlement.RegistryLifecycle([
            self.generation(0, bond=100, effective_window=0)
        ])
        registry.generation_locations[0] = ("LIABILITY", 0)
        with self.assertRaisesRegex(AssertionError, "occupancy"):
            registry._generation_location(0)
        with self.assertRaisesRegex(AssertionError, "reverse index"):
            registry.audit_lifecycle_invariants()

        registry = settlement.RegistryLifecycle([
            self.generation(0, bond=100, effective_window=0)
        ])
        registry.total_credit_liability = 1
        with self.assertRaisesRegex(AssertionError, "pull-credit total"):
            registry.audit_lifecycle_invariants()

    def test_generation_move_and_clear_index_faults_roll_back(self):
        registry = settlement.RegistryLifecycle([
            self.generation(index, bond=100 + index, effective_window=0)
            for index in range(64)
        ])
        newcomer = self.generation(64, bond=10_000, effective_window=0)
        before_move = (
            tuple(registry.active), tuple(registry.liability_ring),
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.movement_sequence, dict(registry.replacements),
            registry.base_bond_escrow, registry.token_balance,
            dict(registry.credits), registry.total_credit_liability,
        )
        registry.lifecycle_fault_point = "after_generation_move_index"
        with self.assertRaisesRegex(RuntimeError, "move-index"):
            registry.admit(newcomer, 0, caller=newcomer.address)
        self.assertEqual((
            tuple(registry.active), tuple(registry.liability_ring),
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.movement_sequence, dict(registry.replacements),
            registry.base_bond_escrow, registry.token_balance,
            dict(registry.credits), registry.total_credit_liability,
        ), before_move)

        registry.lifecycle_fault_point = None
        self.assertTrue(registry.admit(
            newcomer, 0, caller=newcomer.address
        ))
        retained, release_window = registry.liability_ring[0]
        self.assertEqual(
            registry.live_registration_index_plus_one[retained.address],
            retained.registration_index + 1,
        )
        before_clear = (
            registry.liability_ring[0],
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.base_bond_escrow, registry.token_balance,
            dict(registry.credits), registry.total_credit_liability,
        )
        registry.lifecycle_fault_point = "after_generation_clear_index"
        with self.assertRaisesRegex(RuntimeError, "clear-index"):
            registry.release_liability(0, release_window)
        self.assertEqual((
            registry.liability_ring[0],
            dict(registry.generation_locations),
            dict(registry.live_registration_index_plus_one),
            registry.base_bond_escrow, registry.token_balance,
            dict(registry.credits), registry.total_credit_liability,
        ), before_clear)
        registry.lifecycle_fault_point = None
        self.assertTrue(registry.release_liability(0, release_window))
        self.assertNotIn(retained.address,
                         registry.live_registration_index_plus_one)
        registry.audit_lifecycle_invariants()

    def test_full_fresh_table_has_no_eight_window_sybil_fence(self):
        registry = settlement.RegistryLifecycle([
            self.generation(index, bond=10, effective_window=8)
            for index in range(64)
        ], lease_per_window_atomic=10)
        newcomer = self.generation(64, bond=11, effective_window=999)
        self.assertTrue(registry.admit(
            newcomer, 0, caller=newcomer.address, current_l2_slot=17
        ))
        self.assertEqual(registry.active[63].registration_index, 64)
        self.assertEqual(registry.active[63].effective_l2_slot, 17 + 8 * 384)
        self.assertEqual(registry.liability_ring[0][0].registration_index, 63)
        self.assertEqual(
            registry.liability_ring[0][0].tombstoned_at_l2_slot,
            settlement.UINT64_MAX,
        )

    def test_healthy_movement_preserves_sealed_key_but_liability_slash_tombstones(self):
        generations = [
            self.generation(
                index,
                bond=(10 if index == 0 else 100 + index),
                effective_window=0,
            )
            for index in range(64)
        ]
        registry = settlement.RegistryLifecycle(
            generations, lease_per_window_atomic=10
        )
        victim = generations[0]
        self.assertTrue(registry.reserve(victim.address, 8, 0))
        newcomer = self.generation(64, bond=1_000)
        self.assertTrue(registry.admit(
            newcomer, 0, caller=newcomer.address, current_l2_slot=7
        ))
        retained = registry.liability_ring[0][0]
        self.assertEqual(
            registry.liability_ring[0][1],
            8 + 1 + (
                settlement.EVIDENCE_DELAY_SECONDS
                + settlement.REORG_MARGIN_SECONDS
                + settlement.SCHEDULE_WINDOW_SLOTS - 1
            ) // settlement.SCHEDULE_WINDOW_SLOTS + 2,
        )
        self.assertEqual(retained.registration_index, 0)
        self.assertEqual(
            retained.tombstoned_at_l2_slot, settlement.UINT64_MAX
        )
        self.assertEqual(
            registry.tranche_state(0, 8), settlement.TrancheState.LIABLE
        )

        self.assertTrue(registry.slash_tranche(
            0,
            8,
            registry.tranche_deadline(8),
            reporter="reporter",
            reporter_cap_atomic=3,
            current_l2_slot=99,
        ))
        self.assertEqual(
            registry.liability_ring[0][0].tombstoned_at_l2_slot, 99
        )

    def test_tombstone_maintenance_precedes_healthy_replacement(self):
        registry = settlement.RegistryLifecycle([
            self.generation(index, bond=100 + index, effective_window=0)
            for index in range(64)
        ])
        victim = registry.active[63]
        self.assertIsNotNone(victim)
        registry.active[63] = replace(
            victim, tombstoned_at_l2_slot=123, reservations_closed=True
        )
        healthy_before = tuple(registry.active[:63])
        newcomer = self.generation(64, bond=100_000)
        self.assertFalse(registry.admit(
            newcomer, 0, caller=newcomer.address, current_l2_slot=123
        ))
        self.assertEqual(tuple(registry.active[:63]), healthy_before)
        self.assertEqual(registry.process_maintenance(
            0, current_l2_slot=123
        )[1], 1)
        self.assertTrue(registry.admit(
            newcomer, 0, caller=newcomer.address, current_l2_slot=123
        ))
        self.assertEqual(registry.active[63].registration_index, 64)

    def test_registration_index_and_bond_floor_are_derived(self):
        registry = settlement.RegistryLifecycle(
            [], lease_per_window_atomic=10, maximum_bond_atomic=20
        )
        wrong_index = self.generation(1, bond=10)
        self.assertFalse(registry.admit(
            wrong_index, 0, caller=wrong_index.address
        ))
        below_floor = self.generation(0, bond=9)
        self.assertFalse(registry.admit(
            below_floor, 0, caller=below_floor.address
        ))
        above_cap = self.generation(0, bond=21)
        self.assertFalse(registry.admit(
            above_cap, 0, caller=above_cap.address
        ))
        at_cap = self.generation(0, bond=20, effective_window=999)
        self.assertTrue(registry.admit(
            at_cap, 0, caller=at_cap.address, current_l2_slot=19
        ))
        self.assertEqual(registry.next_registration_index, 1)

        registry = settlement.RegistryLifecycle(
            [], lease_per_window_atomic=10, maximum_bond_atomic=20
        )
        first = self.generation(0, bond=10, effective_window=999)
        self.assertTrue(registry.admit(
            first, 0, caller=first.address, current_l2_slot=19
        ))
        self.assertEqual(registry.next_registration_index, 1)
        self.assertEqual(registry.active[0].effective_l2_slot, 19 + 8 * 384)

    def test_empty_free_reserved_custody_and_window_ring_wrap(self):
        self.assertTrue(gate._bootstrap_from_router(1))
        builder = self.generation(0, bond=100, effective_window=0)
        registry = settlement.RegistryLifecycle(
            [builder], lease_per_window_atomic=10
        )
        self.assertEqual(registry.accounted_builder_token, 100)
        self.assertFalse(registry.reserve(
            builder.address, 511, 511, caller="attacker"
        ))
        self.assertTrue(registry.reserve(
            builder.address, 511, 511, caller=builder.address
        ))
        self.assertEqual(registry.accounted_builder_token, 110)
        self.assertEqual(registry.tranche_ring_window(0, 511), 511)
        self.assertEqual(registry.active[0].reservation_bitmap, 1)

        self.assertEqual(registry.normalize_reservations(
            builder.registration_index, 512), 1)
        self.assertEqual(
            registry.tranche_state(builder.registration_index, 511),
            settlement.TrancheState.LIABLE,
        )
        cursor = settlement.ScheduleReleaseCursor(next_release_window=511)
        self.assertTrue(cursor.expire(511, releasable=True))
        deadline = registry.tranche_deadline(511)
        self.assertFalse(registry.release_tranche(
            builder.registration_index, 511, deadline, cursor
        ))
        self.assertTrue(registry.release_tranche(
            builder.registration_index, 511, deadline + 1, cursor
        ))
        self.assertTrue(registry.reserve(
            builder.address, 512, 512, caller=builder.address
        ))
        self.assertEqual(registry.tranche_ring_window(0, 512), 512)
        self.assertEqual(registry.active[0].reservation_bitmap, 1)
        registry.assert_custody_conservation()

    def test_evidence_accepts_deadline_equality_and_release_is_strict(self):
        builder = self.generation(0, bond=100, effective_window=0)
        registry = settlement.RegistryLifecycle(
            [builder], settlement_chain_id=167, lease_per_window_atomic=20
        )
        self.assertTrue(registry.reserve(builder.address, 9, 9))
        self.assertEqual(registry.normalize_reservations(
            builder.registration_index, 10), 1)
        deadline = registry.tranche_deadline(9)
        before = (
            registry.active[0], registry.tranches.copy(),
            registry.tranche_escrow, registry.credits.copy(),
        )
        self.assertFalse(registry.slash_tranche(
            builder.registration_index,
            9,
            deadline,
            reporter="reporter",
            reporter_cap_atomic=7,
            current_l2_slot=3_999,
            signed_settlement_chain_id=168,
        ))
        self.assertEqual((
            registry.active[0], registry.tranches.copy(),
            registry.tranche_escrow, registry.credits.copy(),
        ), before)
        self.assertTrue(registry.slash_tranche(
            builder.registration_index,
            9,
            deadline,
            reporter="reporter",
            reporter_cap_atomic=7,
            current_l2_slot=3_999,
            signed_settlement_chain_id=167,
        ))
        self.assertEqual(registry.active[0].tombstoned_at_l2_slot, 3_999)
        self.assertEqual(registry.credits["reporter"], 7)
        self.assertEqual(registry.credits[registry.penalty_sink], 13)
        self.assertFalse(registry.slash_tranche(
            builder.registration_index,
            9,
            deadline,
            reporter="reporter",
            reporter_cap_atomic=7,
            current_l2_slot=4_000,
        ))
        registry.assert_custody_conservation()

    def test_base_and_tranche_credits_claim_once_without_sweeping_surplus(self):
        builder = self.generation(0, bond=100, effective_window=0)
        registry = settlement.RegistryLifecycle(
            [builder], lease_per_window_atomic=10
        )
        self.assertTrue(registry.reserve(builder.address, 0, 0))
        self.assertEqual(registry.normalize_reservations(0, 1), 1)
        cursor = settlement.ScheduleReleaseCursor(next_release_window=0)
        self.assertTrue(cursor.expire(0, releasable=True))
        self.assertTrue(registry.release_tranche(
            0, 0, registry.tranche_deadline(0) + 1, cursor
        ))
        self.assertEqual(registry.credits[builder.address], 10)

        self.assertTrue(registry.request_exit(builder.address, 1))
        self.assertEqual(registry.process_maintenance(
            269, current_l2_slot=269 * 384
        )[1], 1)
        self.assertTrue(registry.release_liability(0, 269))
        self.assertEqual(registry.credits[builder.address], 110)

        registry.force_token_surplus(7)
        self.assertEqual(registry.token_balance, 117)
        self.assertEqual(registry.claim_credit(
            builder.address, "recipient", caller=builder.address
        ), 110)
        self.assertEqual(registry.token_balance, 7)
        self.assertEqual(registry.accounted_builder_token, 0)
        with self.assertRaises(ValueError):
            registry.claim_credit(
                builder.address, "recipient", caller=builder.address
            )
        registry.assert_custody_conservation()

    def test_fifo_maintenance_precedes_full_table_replacement_and_caps_moves(self):
        registry = settlement.RegistryLifecycle([
            self.generation(index, effective_window=0) for index in range(64)
        ])
        for index in range(5):
            builder = registry.active[index]
            self.assertIsNotNone(builder)
            self.assertTrue(registry.request_exit(
                builder.address, 0, caller=builder.address
            ))
        newcomer = self.generation(64, bond=100_000, effective_window=277)
        self.assertFalse(registry.admit(
            newcomer, 268, caller=newcomer.address
        ))

        inspected, moved = registry.process_maintenance(
            268, current_l2_slot=268 * 384
        )
        self.assertGreaterEqual(inspected, 4)
        self.assertEqual(moved, 4)
        self.assertEqual(
            [row.registration_index for row in registry.liabilities[:4]],
            [0, 1, 2, 3],
        )
        self.assertEqual(registry.moves_used(268), 4)
        self.assertEqual(registry.process_maintenance(
            268, current_l2_slot=268 * 384
        )[1], 0)
        self.assertEqual(registry.process_maintenance(
            269, current_l2_slot=269 * 384
        )[1], 1)
        self.assertTrue(registry.admit(
            newcomer, 269, caller=newcomer.address
        ))
        self.assertEqual(registry.active[0].address, newcomer.address)
        self.assertEqual(registry.active[0].registration_index, 64)
        self.assertEqual(
            registry.active[0].effective_l2_slot,
            269 * 384 + 8 * 384,
        )

    def test_liability_last_cell_wrap_and_pair_proof_order(self):
        registry = settlement.RegistryLifecycle([
            self.generation(index, effective_window=0) for index in range(64)
        ])
        registry.movement_sequence = 1_071
        first = self.generation(64, bond=100_000, effective_window=8)
        second = self.generation(65, bond=100_001, effective_window=8)
        self.assertTrue(registry.admit(first, 0, caller=first.address))
        self.assertEqual(registry.liability_ring[1_071][0].registration_index, 0)
        self.assertTrue(registry.admit(second, 0, caller=second.address))
        self.assertEqual(registry.liability_ring[0][0].registration_index, 1)

        pre_root = b"p" * 32
        intermediate, final = settlement.admission_move_proof_order(
            pre_root,
            liability_position=64 + 1_071,
            active_position=63,
            liability_proof_root=pre_root,
            active_proof_root=None,
        )
        self.assertEqual(len(intermediate), 32)
        self.assertEqual(len(final), 32)
        self.assertEqual(
            settlement.admission_move_proof_order(
                pre_root,
                liability_position=64 + 1_071,
                active_position=63,
                liability_proof_root=pre_root,
                active_proof_root=intermediate,
            ),
            (intermediate, final),
        )
        with self.assertRaises(ValueError):
            settlement.admission_move_proof_order(
                pre_root,
                liability_position=64 + 1_071,
                active_position=63,
                liability_proof_root=b"a" * 32,
                active_proof_root=pre_root,
            )

    def test_schedule_cursor_starts_at_launch_window_and_never_backfills_zero(self):
        cursor = settlement.ScheduleReleaseCursor(first_managed_window=1_000_000)
        self.assertEqual(cursor.next_release_window, 1_000_000)
        self.assertFalse(cursor.is_expired(999_999))
        self.assertEqual(
            cursor.release_state(999_999),
            (settlement.ScheduleReleaseState.UNSEALED, bytes(32)),
        )
        self.assertEqual(
            cursor.window_state(999_999),
            (settlement.ScheduleReleaseState.UNSEALED, bytes(32), bytes(32)),
        )
        cursor.sealed_entry_roots[1_000_000] = b"r" * 32
        cursor.sealed_seeds[1_000_000] = b"s" * 32
        self.assertEqual(
            cursor.window_state(1_000_000),
            (settlement.ScheduleReleaseState.SEALED, b"r" * 32, b"s" * 32),
        )
        swv = settlement.encode_schedule_window_return_v1(
            1_000_000, *cursor.window_state(1_000_000)
        )
        self.assertEqual(len(swv), 160)
        self.assertEqual(swv[:32], b"SWV1" + bytes(28))
        self.assertFalse(cursor.expire(0, releasable=True))
        self.assertTrue(cursor.expire(1_000_000, releasable=True))
        self.assertTrue(cursor.is_expired(1_000_000))
        self.assertFalse(cursor.is_expired(999_999))
        self.assertEqual(
            cursor.window_state(1_000_000),
            (settlement.ScheduleReleaseState.EXPIRED, bytes(32), bytes(32)),
        )
        vacant = settlement.ScheduleReleaseCursor(first_managed_window=5)
        vacant.objectively_vacant.add(5)
        self.assertEqual(
            vacant.window_state(5),
            (settlement.ScheduleReleaseState.VACANT,
             settlement.EMPTY_RANKED_ENTRY_ROOT, bytes(32)),
        )

    def test_registration_exit_head_skip_is_bounded_to_64_records(self):
        registry = settlement.RegistryLifecycle([])
        registry.next_exit_sequence = 65
        registry.exit_requests = {
            sequence: settlement.BuilderExitRequest(
                sequence, sequence, 0, 0, resolved=True
            )
            for sequence in range(65)
        }
        self.assertTrue(registry._mature_live_exit_pending(0))
        registry.exit_head_sequence = 1
        self.assertFalse(registry._mature_live_exit_pending(0))

    def test_schedule_expiry_commits_safe_prefix_and_auth_fault_rolls_back(self):
        root_10 = b"a" * 32
        root_11 = b"b" * 32
        cursor = settlement.ScheduleReleaseCursor(
            first_managed_window=10,
            sealed_entry_roots={10: root_10, 11: root_11},
            objectively_vacant={12},
        )
        self.assertEqual(
            cursor.release_state(10),
            (settlement.ScheduleReleaseState.SEALED, root_10),
        )
        self.assertEqual(
            cursor.release_state(12),
            (
                settlement.ScheduleReleaseState.VACANT,
                settlement.EMPTY_RANKED_ENTRY_ROOT,
            ),
        )
        self.assertEqual(
            cursor.expire_batch(8, lambda window: window < 12), 2
        )
        self.assertEqual(cursor.next_release_window, 12)
        self.assertEqual(
            cursor.release_state(10),
            (settlement.ScheduleReleaseState.EXPIRED, bytes(32)),
        )
        self.assertEqual(
            cursor.release_state(12),
            (
                settlement.ScheduleReleaseState.VACANT,
                settlement.EMPTY_RANKED_ENTRY_ROOT,
            ),
        )

        rollback = settlement.ScheduleReleaseCursor(
            first_managed_window=20,
            sealed_entry_roots={20: b"c" * 32, 21: b"d" * 32},
        )

        def authenticate(window):
            if window == 21:
                raise RuntimeError("malformed ASR1/SSR1")
            return True

        with self.assertRaises(RuntimeError):
            rollback.expire_batch(8, authenticate)
        self.assertEqual(rollback.next_release_window, 20)
        with self.assertRaises(ValueError):
            rollback.expire_batch(0, lambda _: True)

        with self.assertRaises(ValueError):
            settlement.ScheduleReleaseCursor(
                first_managed_window=settlement.UINT64_MAX
            )
        with self.assertRaises(ValueError):
            settlement.ScheduleReleaseCursor(
                first_managed_window=settlement.LAST_MANAGED_SCHEDULE_WINDOW + 1
            )
        terminal = settlement.ScheduleReleaseCursor(
            first_managed_window=settlement.LAST_MANAGED_SCHEDULE_WINDOW,
            objectively_vacant={settlement.LAST_MANAGED_SCHEDULE_WINDOW},
        )
        self.assertEqual(terminal.expire_batch(1, lambda _: True), 1)
        self.assertEqual(terminal.expire_batch(1, lambda _: True), 0)
        self.assertEqual(terminal.next_release_window, settlement.UINT64_MAX)
        self.assertTrue(
            terminal.is_expired(settlement.LAST_MANAGED_SCHEDULE_WINDOW)
        )
        self.assertFalse(
            terminal.is_expired(settlement.LAST_MANAGED_SCHEDULE_WINDOW + 1)
        )
        self.assertEqual(
            terminal.release_state(settlement.LAST_MANAGED_SCHEDULE_WINDOW + 1),
            (settlement.ScheduleReleaseState.UNSEALED, bytes(32)),
        )
        last_slot_end = (
            settlement.SCHEDULE_WINDOW_SLOTS
            * (settlement.LAST_MANAGED_SCHEDULE_WINDOW + 1) - 1
        )
        self.assertLessEqual(last_slot_end, settlement.UINT64_MAX)
        last_deadline = (
            settlement.GENESIS_TIMESTAMP + last_slot_end + 1
            + settlement.EVIDENCE_DELAY_SECONDS
            + settlement.REORG_MARGIN_SECONDS
        )
        self.assertLessEqual(last_deadline, settlement.UINT64_MAX - 1)
        self.assertGreater(
            settlement.GENESIS_TIMESTAMP
            + settlement.SCHEDULE_WINDOW_SLOTS
            * (settlement.LAST_MANAGED_SCHEDULE_WINDOW + 2)
            + settlement.EVIDENCE_DELAY_SECONDS
            + settlement.REORG_MARGIN_SECONDS,
            settlement.UINT64_MAX - 1,
        )
        self.assertTrue(settlement.tranche_releasable(
            settlement.LAST_MANAGED_SCHEDULE_WINDOW,
            settlement.UINT64_MAX,
            last_deadline + 1,
            last_deadline,
        ))
        self.assertFalse(settlement.tranche_releasable(
            settlement.LAST_MANAGED_SCHEDULE_WINDOW + 1,
            settlement.UINT64_MAX,
            last_deadline + 1,
            last_deadline,
        ))

        def terminal_state(cursor, window, *, actual=None, mask=0):
            return settlement.encode_settlement_schedule_terminal_state_v1(
                window,
                1,
                settlement.UINT64_MAX if actual is None else actual,
                mask,
                caller=cursor.schedule_oracle,
                pinned_schedule_oracle=cursor.schedule_oracle,
            )

        backlogged = settlement.ScheduleReleaseCursor()
        self.assertEqual(backlogged.next_release_window, 0)
        self.assertGreater(backlogged.last_managed_window, 1_000_000)
        self.assertTrue(backlogged.finalize_expiry(
            last_deadline + 1,
            1,
            lambda window: terminal_state(backlogged, window),
        ))
        self.assertEqual(
            backlogged.next_release_window, settlement.UINT64_MAX
        )
        self.assertEqual(
            settlement.keccak256(b"finalizeScheduleExpiryV1()")[:4],
            settlement.SCHEDULE_FINALIZE_EXPIRY_SELECTOR,
        )
        self.assertEqual(
            settlement.keccak256(
                b"settlementScheduleTerminalStateV1(uint64)"
            )[:4],
            settlement.SETTLEMENT_SCHEDULE_TERMINAL_SELECTOR,
        )
        swt = settlement.encode_schedule_finalize_expiry_return_v1(
            0, backlogged.last_managed_window,
            backlogged.next_release_window,
        )
        self.assertEqual(len(swt), 128)
        self.assertEqual(swt[:32], b"SWT1" + bytes(28))

        faulting = settlement.ScheduleReleaseCursor()

        def terminal_fault(_):
            raise RuntimeError("malformed terminal SSR1")

        with self.assertRaises(RuntimeError):
            faulting.finalize_expiry(
                last_deadline + 1, 1, terminal_fault
            )
        self.assertEqual(faulting.next_release_window, 0)

        very_late = settlement.ScheduleReleaseCursor()
        self.assertEqual(
            settlement.capped_schedule_terminal_global_min(
                settlement.UINT64_MAX + 10_000
            ),
            settlement.UINT64_MAX,
        )
        sts = settlement.encode_settlement_schedule_terminal_state_v1(
            very_late.last_managed_window,
            1,
            settlement.UINT64_MAX + 10_000,
            0,
            caller=very_late.schedule_oracle,
            pinned_schedule_oracle=very_late.schedule_oracle,
        )
        self.assertEqual(len(sts), 160)
        self.assertEqual(sts[:32], b"STS1" + bytes(28))
        self.assertEqual(
            int.from_bytes(sts[3 * 32:4 * 32], "big"),
            settlement.UINT64_MAX,
        )
        self.assertTrue(very_late.finalize_expiry(
            settlement.GENESIS_TIMESTAMP + settlement.UINT64_MAX + 1,
            1,
            lambda window: terminal_state(
                very_late, window,
                actual=settlement.UINT64_MAX + 10_000,
            ),
        ))
        self.assertEqual(
            very_late.next_release_window, settlement.UINT64_MAX
        )

    def test_terminal_active_release_is_deadline_safe_and_ring_independent(self):
        # Select deployment inputs whose last managed window is exactly eight,
        # and whose inclusive replay deadline is UINT64_MAX - 1.  This pins the
        # final admission, final tranche and strict-release boundaries.
        last_managed = 8
        genesis = (
            settlement.UINT64_MAX - 1
            - settlement.SCHEDULE_WINDOW_SLOTS * (last_managed + 1)
        )
        active = [
            self.generation(index, bond=100 + index, effective_window=0)
            for index in range(64)
        ]
        blocked_liability = self.generation(
            64, bond=1_000, effective_window=0
        )
        liability_ring = [None] * settlement.MAX_LIABILITY_GENERATIONS
        liability_ring[0] = (blocked_liability, settlement.UINT64_MAX)
        registry = settlement.RegistryLifecycle(
            active,
            genesis_timestamp=genesis,
            evidence_delay_seconds=0,
            reorg_margin_seconds=0,
            liability_ring=liability_ring,
            lease_per_window_atomic=10,
        )
        self.assertEqual(registry.last_managed_window, last_managed)
        self.assertEqual(
            registry.tranche_deadline(last_managed),
            settlement.UINT64_MAX - 1,
        )

        # Slot zero admits a generation exactly at the last window.  One slot
        # into the next source window would make it effective too late.
        empty_registry = settlement.RegistryLifecycle(
            [],
            genesis_timestamp=genesis,
            evidence_delay_seconds=0,
            reorg_margin_seconds=0,
            lease_per_window_atomic=10,
        )
        exact = self.generation(0, bond=10)
        self.assertTrue(empty_registry.admit(
            exact, 0, caller=exact.address,
            current_l2_slot=settlement.SCHEDULE_WINDOW_SLOTS - 1,
        ))
        late = self.generation(1, bond=11)
        self.assertFalse(empty_registry.admit(
            late, 1, caller=late.address,
            current_l2_slot=settlement.SCHEDULE_WINDOW_SLOTS,
        ))

        self.assertTrue(registry.reserve(
            active[0].address, last_managed, last_managed
        ))
        self.assertTrue(registry.reserve(
            active[63].address, last_managed, last_managed
        ))
        self.assertFalse(registry.reserve(
            active[1].address, last_managed + 1, last_managed
        ))
        cursor = settlement.ScheduleReleaseCursor(
            genesis_timestamp=genesis,
            evidence_delay_seconds=0,
            reorg_margin_seconds=0,
            first_managed_window=0,
            last_managed_window=last_managed,
            objectively_vacant={last_managed},
        )
        self.assertEqual(registry.process_maintenance(
            last_managed + 1,
            current_l2_slot=(last_managed + 1) * 384,
        ), (0, 0))

        # Equality evidence lands before terminal expiry.  The O(1) terminal
        # jump then discharges the entire 0..8 cursor backlog from only the
        # final window's monotonic release predicates.
        self.assertFalse(cursor.finalize_expiry(
            settlement.UINT64_MAX - 1,
            1,
            lambda window: settlement.encode_settlement_schedule_terminal_state_v1(
                window,
                1,
                settlement.UINT64_MAX,
                0,
                caller=cursor.schedule_oracle,
                pinned_schedule_oracle=cursor.schedule_oracle,
            ),
        ))
        self.assertTrue(registry.slash_tranche(
            0,
            last_managed,
            settlement.UINT64_MAX - 1,
            reporter="terminal-reporter",
            reporter_cap_atomic=3,
            current_l2_slot=settlement.UINT64_MAX,
        ))
        self.assertTrue(cursor.finalize_expiry(
            settlement.UINT64_MAX,
            1,
            lambda window: settlement.encode_settlement_schedule_terminal_state_v1(
                window,
                1,
                settlement.UINT64_MAX,
                0,
                caller=cursor.schedule_oracle,
                pinned_schedule_oracle=cursor.schedule_oracle,
            ),
        ))
        self.assertEqual(cursor.next_release_window, settlement.UINT64_MAX)
        substituted_cursor = settlement.ScheduleReleaseCursor(
            schedule_oracle="substituted-oracle",
            genesis_timestamp=genesis,
            evidence_delay_seconds=0,
            reorg_margin_seconds=0,
            first_managed_window=0,
            last_managed_window=last_managed,
            next_release_window=settlement.UINT64_MAX,
        )
        self.assertFalse(registry.release_terminal_active(
            1, settlement.UINT64_MAX + 1, substituted_cursor
        ))
        no_reservation = registry.active[1]
        self.assertEqual(registry.normalize_reservations(
            1,
            settlement.UINT64_MAX + 10_000,
            cursor,
        ), 0)
        self.assertEqual(registry.active[1], no_reservation)
        self.assertEqual(registry.normalize_reservations(
            63,
            settlement.UINT64_MAX + 10_000,
            cursor,
        ), 1)
        self.assertEqual(
            registry.active[63].reservation_base_window,
            last_managed,
        )
        self.assertEqual(registry.active[63].reservation_bitmap, 0)
        self.assertFalse(registry.active[63].reservations_closed)
        self.assertEqual(
            registry.liability_ring[0][0].registration_index, 64
        )
        self.assertFalse(registry.release_terminal_active(
            63, settlement.UINT64_MAX - 1, cursor
        ))
        self.assertTrue(registry.release_tranche(
            63, last_managed, settlement.UINT64_MAX, cursor
        ))
        self.assertTrue(registry.release_terminal_active(
            63, settlement.UINT64_MAX + 1, cursor
        ))
        self.assertTrue(registry.release_terminal_active(
            0, settlement.UINT64_MAX + 2, cursor
        ))
        for index in range(1, 63):
            self.assertTrue(registry.release_terminal_active(
                index, settlement.UINT64_MAX + 2 + index, cursor
            ))
        self.assertEqual(registry.active_count, 0)
        self.assertIsNotNone(registry.liability_ring[0])
        self.assertFalse(registry.release_liability(
            0, last_managed + 1
        ))
        self.assertTrue(registry.release_liability(
            0,
            last_managed + 1,
            now=settlement.UINT64_MAX + 66,
            schedule_cursor=cursor,
        ))
        registry.assert_custody_conservation()

    def test_terminal_bound_is_derived_and_cross_component_mismatch_rejects(self):
        derived = settlement.derive_last_managed_schedule_window(
            settlement.GENESIS_TIMESTAMP,
            settlement.EVIDENCE_DELAY_SECONDS,
            settlement.REORG_MARGIN_SECONDS,
        )
        self.assertEqual(derived, settlement.LAST_MANAGED_SCHEDULE_WINDOW)
        with self.assertRaises(ValueError):
            settlement.RegistryLifecycle(
                [], last_managed_window=derived - 1
            )
        bounded_initial = schedule_fork_row(
            bytes.fromhex("01020304"), 0, 500_000
        )
        with self.assertRaises(ValueError):
            settlement.ScheduleOracleV1(
                "schedule-oracle", "version-manager",
                bounded_initial,
                last_managed_window=derived - 1,
                fork_verifier_world=schedule_fork_world(bounded_initial),
            )
        bounded_oracle = settlement.ScheduleOracleV1(
            "schedule-oracle", "version-manager",
            bounded_initial,
            first_managed_window=5,
            fork_verifier_world=schedule_fork_world(bounded_initial),
        )
        late_initial = schedule_fork_row(
            bytes.fromhex("05060708"),
            0,
            bounded_oracle.target_slot(1_000),
        )
        with self.assertRaisesRegex(ValueError, "already unsafe"):
            settlement.ScheduleOracleV1(
                "late-schedule-oracle",
                "version-manager",
                late_initial,
                deployed_at_timestamp=(
                    settlement.GENESIS_TIMESTAMP
                    + 1_000 * settlement.SCHEDULE_WINDOW_SLOTS
                ),
                fork_verifier_world=schedule_fork_world(late_initial),
            )
        boundary_clock = settlement.Clock(1, settlement.GENESIS_TIMESTAMP)
        with self.assertRaises(ValueError):
            bounded_oracle.seal_window_v1(
                4, bytes.fromhex("01020304"), b"", b"",
                system=settlement.ScheduleCarrierSystemContextV1((), b""),
                clock=boundary_clock,
            )
        with self.assertRaises(ValueError):
            bounded_oracle.consume_window_v1(
                4,
                clock=boundary_clock,
            )
        first_managed_deadline = (
            settlement.GENESIS_TIMESTAMP
            + 5 * settlement.SCHEDULE_WINDOW_SLOTS
            - settlement.SCHEDULE_LOOKAHEAD_SECONDS
        )
        self.assertEqual(
            bounded_oracle.consume_window_v1(
                5,
                clock=settlement.Clock(1, first_managed_deadline),
            ),
            bytes(32),
        )
        with self.assertRaises(ValueError):
            settlement.derive_last_managed_schedule_window(
                settlement.UINT64_MAX,
                settlement.EVIDENCE_DELAY_SECONDS,
                settlement.REORG_MARGIN_SECONDS,
            )

        bounded = settlement.RegistryLifecycle(
            [self.generation(0, bond=100, effective_window=0)],
            first_managed_window=5,
            lease_per_window_atomic=10,
        )
        self.assertFalse(bounded.reserve(
            bounded.active[0].address, 4, 4
        ))
        self.assertEqual(bounded.tranches, {})
        self.assertTrue(bounded.reserve(
            bounded.active[0].address, 5, 5
        ))

        wrap_safe = settlement.RegistryLifecycle(
            [
                self.generation(index, bond=10 + index, effective_window=0)
                for index in range(64)
            ],
            first_managed_window=5,
            lease_per_window_atomic=10,
        )
        victim = wrap_safe.active[0]
        self.assertFalse(wrap_safe.reserve(victim.address, 4, 4))
        replacement = self.generation(64, bond=10_000)
        self.assertTrue(wrap_safe.admit(
            replacement, 0, caller=replacement.address
        ))
        self.assertEqual(
            wrap_safe.liability_ring[0][0].unreleased_tranche_count, 0
        )
        self.assertTrue(wrap_safe.release_liability(0, 1_000))

    def test_normalization_never_releases_or_credits(self):
        builder = self.generation(0, bond=100, effective_window=0)
        registry = settlement.RegistryLifecycle(
            [builder], lease_per_window_atomic=10
        )
        self.assertTrue(registry.reserve(builder.address, 0, 0))
        deadline = registry.tranche_deadline(0)
        before_balance = registry.token_balance
        self.assertEqual(registry.normalize_reservations(0, 10_000), 1)
        self.assertEqual(registry.tranche_escrow, 10)
        self.assertEqual(registry.credits, {})
        self.assertEqual(registry.token_balance, before_balance)
        cursor = settlement.ScheduleReleaseCursor(first_managed_window=0)
        self.assertTrue(cursor.expire(0, releasable=True))
        self.assertFalse(registry.release_tranche(0, 0, deadline, cursor))
        self.assertTrue(registry.release_tranche(0, 0, deadline + 1, cursor))


if __name__ == "__main__":
    unittest.main(verbosity=2)
