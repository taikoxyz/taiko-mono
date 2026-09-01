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
commitment = load_module(
    "commitment_model_bounded_frontier",
    ROOT / "commitment-model.py",
)


def addr(label: str) -> str:
    raw = label.encode("ascii")
    if not raw or len(raw) > 20:
        raise ValueError("address label must contain 1..20 ASCII bytes")
    return "0x" + raw.ljust(20, b"\x00").hex()


def authorization():
    deployment = settlement.settlement_deployment_descriptor_for_test(
        "seat-market-authorized-settlement", b"r" * 32, b"c" * 32
    )
    return market.TargetAuthorization(
        target=deployment.target_settlement,
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

    evolved_seat_generation = protocol.seat_generation
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
        market_runtime_hash=settlement._model_fixed_bytes32(runtime_hash),
        execution_profile=profile,
    )
    protocol.versioned_history = history
    profile_words = settlement._execution_profile_abi_words_v2(
        profile.canonical_profile_bytes
    )
    profile_pvm = "0x" + profile_words[20][12:].hex()
    profile_router = "0x" + profile_words[23][12:].hex()
    profile_market = "0x" + profile_words[35][12:].hex()
    object.__setattr__(
        protocol.forced_queue, "router_address", profile_router
    )
    router = settlement.deploy_active_settlement_router(
        history,
        profile_pvm,
        protocol.forced_queue,
        protocol.inbox_apply_router,
        protocol.migration_gate,
        protocol.header_oracle,
        address=profile_router,
    )
    bootstrap_clock = settlement.Clock(
        max(400, protocol.canonical.canonicalized_at_block),
        settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
    )
    bootstrap_proof = settlement.prepare_genesis_activation_for_test(
        router, history, bootstrap_clock
    )
    protocol.seat_generation = 0
    if not router.bootstrap(
        history,
        sequence=0,
        clock=bootstrap_clock,
        caller=router.version_manager,
        proof=bootstrap_proof,
    ):
        raise AssertionError("fixture failed to bootstrap exact History graph")
    protocol.seat_generation = evolved_seat_generation
    return history, router


def unactivated_genesis_fixture(*, suffix="checkpoint", protocol_version=25):
    """Build the exact pre-checkpoint genesis graph without crossing delays."""

    protocol = settlement.protocol(seat=False)
    protocol.seat_generation = 0
    profile = settlement.execution_profile_for_test(
        protocol_version, f"profile:{suffix}"
    )
    history = settlement.VersionedSettlementHistory(
        protocol.settlement_address,
        f"runtime:{suffix}",
        protocol_version,
        profile.execution_profile_hash,
        copy.deepcopy(protocol.core),
        protocol.canonical.canonicalized_at_block,
        protocol.forced_queue,
        migration_gate=protocol.migration_gate,
        live_protocol=protocol,
        inbox_apply_descriptor=protocol.inbox_apply_descriptor,
        header_oracle=protocol.header_oracle,
        market_runtime_hash=settlement._model_fixed_bytes32(
            f"runtime:{suffix}"
        ),
        execution_profile=profile,
    )
    protocol.versioned_history = history
    profile_words = settlement._execution_profile_abi_words_v2(
        profile.canonical_profile_bytes
    )
    profile_router = "0x" + profile_words[23][12:].hex()
    object.__setattr__(
        protocol.forced_queue, "router_address", profile_router
    )
    router = settlement.deploy_active_settlement_router(
        history,
        "0x" + profile_words[20][12:].hex(),
        protocol.forced_queue,
        protocol.inbox_apply_router,
        protocol.migration_gate,
        protocol.header_oracle,
        address=profile_router,
    )
    clock = settlement.Clock(
        max(400, protocol.canonical.canonicalized_at_block + 3),
        settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot
        + 2 * settlement.SEAT_MIGRATION_MANIFEST_DELAY,
    )
    return protocol, history, router, clock


def publish_genesis_campaign_fixture(
    router, history, landing_clock, *, publish=True
):
    """Publish one exact staged campaign and return its immutable clocks."""

    force_cutoff = landing_clock.block_number - 260
    proposal_cutoff = landing_clock.block_number - 196
    quiesce = landing_clock.block_number - 4
    resume_block = landing_clock.block_number + 128
    resume_timestamp = landing_clock.timestamp + 1_800
    schedule_clock = settlement.Clock(
        landing_clock.block_number - 330,
        landing_clock.timestamp - 5_000,
    )
    publish_clock = settlement.Clock(
        landing_clock.block_number - 325,
        schedule_clock.timestamp + settlement.SEAT_MIGRATION_MANIFEST_DELAY,
    )
    preview = settlement.settlement_registration(
        router, history, activation_block=0, predecessor_version=0,
        release_manifest_hash=router.bootstrap_release_manifest_hash,
    )
    registration_hash = settlement.target_registration_hash_v2(preview)
    profile_hash = router.legacy_launch_hook.legacy_resume_profile_hash
    review = settlement.legacy_genesis_review_commitment_v1(
        router.legacy_launch_hook.deployment_hash, profile_hash,
        history.protocol_version, router.bootstrap_release_manifest_hash,
        registration_hash,
    )
    campaign_id = router._schedule_genesis_campaign_for_fixture_v1(
        history,
        review_commitment=review,
        review_finalized_by_block=landing_clock.block_number - 394,
        force_cutoff_block=force_cutoff,
        proposal_cutoff_block=proposal_cutoff,
        quiesce_block=quiesce,
        resume_by_block=resume_block,
        resume_by_timestamp=resume_timestamp,
        executable_at=publish_clock.timestamp,
        caller=router.version_manager,
        clock=schedule_clock,
    )
    if campaign_id is None:
        raise AssertionError("campaign fixture scheduling failed")
    if not publish:
        return router.scheduled_genesis_campaign.campaign, dict(
            schedule=schedule_clock,
            publish=publish_clock,
            force=settlement.Clock(
                force_cutoff, landing_clock.timestamp - 260 * 12
            ),
            proposal=settlement.Clock(
                proposal_cutoff, landing_clock.timestamp - 196 * 12
            ),
            quiesce=settlement.Clock(quiesce, landing_clock.timestamp),
            resume=settlement.Clock(resume_block, resume_timestamp),
            landing=landing_clock,
        )
    campaign = router._publish_genesis_campaign_for_fixture_v1(
        campaign_id, caller=addr("campaign-publisher"), clock=publish_clock
    )
    if campaign is None:
        raise AssertionError("campaign fixture publication failed")
    return campaign, dict(
        schedule=schedule_clock,
        publish=publish_clock,
        force=settlement.Clock(force_cutoff, landing_clock.timestamp - 260 * 12),
        proposal=settlement.Clock(
            proposal_cutoff, landing_clock.timestamp - 196 * 12
        ),
        quiesce=settlement.Clock(quiesce, landing_clock.timestamp),
        resume=settlement.Clock(resume_block, resume_timestamp),
        landing=landing_clock,
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
        self.assertEqual(duty.status, settlement.DutyStatus.FAILED_OVER)
        self.assertIsNone(duty.satisfied_at)
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
        self.assertIs(duty.status, settlement.DutyStatus.FAILED_OVER)
        self.assertIsNone(duty.satisfied_at)
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
                settlement.DutyStatus.FAILED_OVER,
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
        self.assertEqual(service.duty_base_sequence, 900)
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
        fresh_base_tip = max(
            protocol.core.tip_slot,
            term.installed_at - settlement.GENESIS_TIMESTAMP,
        )
        self.assertEqual(service.duty_base_tip_slot, fresh_base_tip)
        self.assertEqual(service.duty_base_sequence, 900)
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
                self.assertEqual(duty.base_sequence, 901)
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
            market_runtime_hash=settlement._model_fixed_bytes32(
                "runtime:atomic-success"
            ),
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
        bootstrap_clock = settlement.Clock(
            400, settlement.GENESIS_TIMESTAMP + 999
        )
        bootstrap_proof = settlement.prepare_genesis_activation_for_test(
            active_router, history, bootstrap_clock
        )
        evolved_generation = protocol.seat_generation
        protocol.seat_generation = 0
        self.assertTrue(active_router.bootstrap(
            history,
            sequence=0,
            clock=bootstrap_clock,
            caller=active_router.version_manager,
            proof=bootstrap_proof,
        ))
        protocol.seat_generation = evolved_generation
        queue = protocol.forced_queue
        router = protocol.inbox_apply_router
        gate = protocol.migration_gate
        arm_clock = settlement.Clock(
            401, settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot + 1
        )
        self.assertEqual(protocol.arm_normal_context(arm_clock), "ARMED")
        self.assertEqual(
            protocol.activate_normal_context(
                settlement.Clock(402, arm_clock.timestamp)
            ),
            "ACTIVATED",
        )
        commit_clock = settlement.Clock(403, arm_clock.timestamp)
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


class BoundaryAndAuthorityTests(unittest.TestCase):
    def test_absent_due_sentinel_never_becomes_a_real_boundary(self):
        terminal = settlement.Clock(1, settlement.UINT64_MAX)
        empty = settlement.protocol(seat=False)
        self.assertFalse(empty.force_due(terminal))
        self.assertEqual(empty.boundary_queries, 0)

        last = replace(
            settlement.message(0, "last-deadline"),
            due_at=settlement.UINT64_MAX,
        )
        present = settlement.protocol(seat=False, messages=[last])
        self.assertFalse(present.force_due(replace(
            terminal, timestamp=settlement.UINT64_MAX - 1
        )))
        self.assertTrue(present.force_due(terminal))

        present.core.message_cursor = present.forced_queue.count
        present.forced_queue.cursor = present.forced_queue.count
        self.assertFalse(present.force_due(terminal))

    def test_recovery_root_freeze_never_reads_descriptor_history(self):
        class IterationForbiddenList(list):
            def __iter__(self):
                raise AssertionError("descriptor history was iterated")

            def __getitem__(self, key):
                raise AssertionError("descriptor history was indexed")

        protocol = settlement.protocol(
            seat=False, messages=[settlement.message(0, "root")]
        )
        protocol.forced_queue.descriptors = IterationForbiddenList(
            protocol.forced_queue.descriptors
        )
        self.assertEqual(
            protocol.force_root(protocol.forced_queue.count),
            protocol.forced_queue.root,
        )
        with self.assertRaises(ValueError):
            protocol.force_root(0)

    def test_normal_close_distinguishes_absent_and_live_due_boundaries(self):
        deadline = settlement.GENESIS_TIMESTAMP + 5_000

        def close_with(messages):
            protocol = settlement.protocol(seat=False, messages=messages)
            submit_clock = settlement.Clock(500, deadline - 1)
            protocol.normal_best = settlement.candidate(
                protocol, submit_clock, "boundary-best", message_end=0
            )
            protocol.normal_best_min_data_expiry = (
                deadline + settlement.REORG_MARGIN_SECONDS
            )
            protocol.normal_deadline = deadline
            closed, outcome = protocol._close_mature_normal(
                settlement.Clock(501, deadline)
            )
            return protocol, closed, outcome

        absent, closed, outcome = close_with([])
        self.assertTrue(closed)
        self.assertIsNotNone(outcome)
        self.assertIn("NORMAL_COMMITTED", absent.events)

        for offset in (-1, 0, 1):
            with self.subTest(offset=offset):
                row = replace(
                    settlement.message(0, f"boundary-{offset}"),
                    due_at=deadline + offset,
                )
                protocol, closed, outcome = close_with([row])
                self.assertTrue(closed)
                if offset <= 0:
                    self.assertIsNone(outcome)
                    self.assertIn(
                        "NORMAL_CANCELED_FORCE_OMISSION", protocol.events
                    )
                else:
                    self.assertIsNotNone(outcome)
                    self.assertIn("NORMAL_COMMITTED", protocol.events)

    def test_recovery_expiry_and_append_roll_are_strict_and_bounded(self):
        protocol, manager = migration_manager_fixture(seat=False)
        open_clock = settlement.Clock(
            1_100,
            settlement.GENESIS_TIMESTAMP
            + protocol.core.tip_slot
            + settlement.DELTA_FINAL_LAG
            + 1,
        )
        protocol._activate(open_clock, settlement.Cause.SLA)
        old = protocol.recovery
        old_candidate = settlement.escape_candidate(
            protocol, settlement.recovery_submit_clock(protocol), "old-round"
        )
        for offset in (-1, 0):
            check_clock = settlement.Clock(
                old.anchor_number + settlement.F_L1,
                old.expires_at + offset,
            )
            self.assertFalse(protocol._roll_recovery(check_clock))
            self.assertTrue(protocol._valid_recovery(
                old_candidate, check_clock
            ))

        adapter_clock = settlement.Clock(
            old.anchor_number + 1, old.expires_at - settlement.FORCE_DELAY
        )
        adapter = settlement.activate_ingress_adapter_for_test(
            manager.router,
            kind=settlement.ForceKind.USER_TX,
            clock=adapter_clock,
        )
        descriptor = settlement.message(adapter_clock.l2_slot, "during-round")
        self.assertEqual(
            adapter.enqueue(
                adapter_clock,
                descriptor,
                caller=descriptor.sender,
                deposit=descriptor.prepaid,
            ),
            "QUEUED:0",
        )
        self.assertEqual(
            protocol.forced_queue.descriptors[0].due_at, old.expires_at + 1
        )

        class IterationForbiddenList(list):
            def __iter__(self):
                raise AssertionError("recovery roll iterated descriptors")

            def __getitem__(self, key):
                raise AssertionError("recovery roll indexed descriptors")

        protocol.forced_queue.descriptors = IterationForbiddenList(
            protocol.forced_queue.descriptors
        )
        self.assertTrue(protocol._roll_recovery(settlement.Clock(
            old.anchor_number + settlement.F_L1 + 1,
            old.expires_at + 1,
        )))
        self.assertEqual(protocol.recovery.revision, old.revision + 1)
        self.assertEqual(
            (protocol.recovery.force_cutoff, protocol.recovery.force_root),
            (protocol.forced_queue.count, protocol.forced_queue.root),
        )
        self.assertFalse(protocol._valid_recovery(
            old_candidate,
            settlement.Clock(
                protocol.recovery.anchor_number + settlement.F_L1,
                protocol.recovery.expires_at,
            ),
        ))

    def test_no_duty_and_closed_caps_choose_the_earliest_local_bound(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol._record_seat_term(term)
        protocol.seat_services[term.term_id] = settlement.SeatService(
            responsibility_start=term.installed_at,
            minimum_tenure_until=term.installed_at + 1_000,
            premium_funded_until=term.installed_at + 6_000,
            service_eligible_until=term.installed_at + 2_036,
            standby_lease_expires_at=(
                term.installed_at + protocol.maximum_standby_lease_seconds
            ),
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

    def test_migration_preserves_failed_over_duty_and_clears_selection(self):
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
            settlement.DutyStatus.FAILED_OVER,
        )
        self.assertEqual(protocol.unresolved_duty_count, 1)

    def test_unresolved_duty_counter_tracks_every_terminal_transition(self):
        def fixture():
            protocol = settlement.protocol(tip_slot=1_000, seat=False)
            term = synthetic_term(
                1, settlement.GENESIS_TIMESTAMP + 1_000
            )
            protocol.install_seat_term_for_test(
                term, rank=0, start_primary=True
            )
            return protocol, activate_current_duty(protocol)

        satisfied, satisfied_duty = fixture()
        canonical_cure(
            satisfied,
            satisfied_duty,
            at=satisfied_duty.recovery_at,
            tip=satisfied_duty.target_tip,
        )
        self.assertEqual(satisfied.unresolved_duty_count, 0)

        breached, breached_duty = fixture()
        breached.sync(settlement.Clock(901, breached_duty.failover_at + 1))
        self.assertEqual(breached.unresolved_duty_count, 1)
        breached.sync(settlement.Clock(902, breached_duty.slash_at + 1))
        self.assertEqual(breached.unresolved_duty_count, 0)

        excused, excused_duty = fixture()
        excused._scan_seat_duties(
            settlement.Clock(903, excused_duty.recovery_at),
            allow_cure=False,
            excuse_for_migration=True,
        )
        self.assertEqual(excused.unresolved_duty_count, 0)

    def test_migration_readiness_does_not_scan_retained_duty_history(self):
        class IterationForbiddenDict(dict):
            def __iter__(self):
                raise AssertionError("retained duty history was iterated")

            def values(self):
                raise AssertionError("retained duty history was scanned")

        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 2_000
        )
        old_protocol, manager = production_migration_fixture()[0::4]
        execute_manager_arm(manager, arm_clock)
        old_protocol.seat_duties = IterationForbiddenDict(
            old_protocol.seat_duties
        )
        self.assertTrue(old_protocol._local_migration_arm_complete(False))

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
        self.assertEqual(
            protocol.seat_term_by_tranche[term.tranche_id], term.term_id
        )
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

    def test_term_tranche_adoption_is_constant_work_with_large_history(self):
        class IterationForbiddenDict(dict):
            def __iter__(self):
                raise AssertionError("term adoption iterated append-only history")

            def items(self):
                raise AssertionError("term adoption iterated append-only history")

            def values(self):
                raise AssertionError("term adoption iterated append-only history")

        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        history_size = 100_000
        protocol.seat_terms = IterationForbiddenDict(
            ((index + 1).to_bytes(32, "big"), None)
            for index in range(history_size)
        )
        protocol.seat_term_by_tranche = IterationForbiddenDict(
            ((index + history_size + 1).to_bytes(32, "big"),
             (index + 1).to_bytes(32, "big"))
            for index in range(history_size)
        )
        fresh = settlement.SeatTerm(
            (3 * history_size + 1).to_bytes(32, "big"),
            (3 * history_size + 2).to_bytes(32, "big"),
            (3 * history_size + 3).to_bytes(32, "big"),
            "operator-large-history",
            "payout-large-history",
            1,
            settlement.GENESIS_TIMESTAMP + 1_000,
        )
        protocol._record_seat_term(fresh)
        self.assertIs(protocol.seat_terms[fresh.term_id], fresh)
        self.assertEqual(
            protocol.seat_term_by_tranche[fresh.tranche_id], fresh.term_id
        )

        duplicate = replace(fresh, term_id=b"z" * 32)
        with self.assertRaises(ValueError):
            protocol._record_seat_term(duplicate)

    def test_term_tranche_reverse_index_is_fail_closed(self):
        protocol = settlement.protocol(tip_slot=1_000, seat=False)
        term = synthetic_term(1, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol.install_seat_term_for_test(term, rank=0, start_primary=True)
        protocol.seat_term_by_tranche[term.tranche_id] = b"z" * 32
        with self.assertRaises(AssertionError):
            protocol._assert_seat_valid()

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
    settlement_target = settlement.settlement_deployment_descriptor_for_test(
        "migration-manager-settlement", b"r" * 32, b"c" * 32
    ).target_settlement
    protocol = settlement.protocol(
        tip_slot=1_000,
        seat=seat,
        settlement_address=settlement_target,
    )
    evolved_seat_generation = protocol.seat_generation
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
        market_runtime_hash=settlement._model_fixed_bytes32(
            "runtime:seat-v1"
        ),
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
    bootstrap_clock = settlement.Clock(
        max(400, protocol.canonical.canonicalized_at_block),
        settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
    )
    bootstrap_proof = settlement.prepare_genesis_activation_for_test(
        router, history, bootstrap_clock
    )
    protocol.seat_generation = 0
    if not router.bootstrap(
        history,
        sequence=0,
        clock=bootstrap_clock,
        caller=router.version_manager,
        proof=bootstrap_proof,
    ):
        raise AssertionError("fixture did not bootstrap active router")
    protocol.seat_generation = evolved_seat_generation
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
    target_manifest_hash = b"m" * 32
    target_registration_hash = b"r" * 32
    old_authorization_id = b""
    new_authorization_id = b""
    if manager.release_manager is not None:
        old_history = manager.router.registrations[manager.router.active_version] \
            .settlement
        rows = tuple(
            (authorization_id, runtime.authority)
            for authorization_id, runtime
            in manager.release_manager.target_runtimes.items()
            if runtime.authority.protocol_version in {25, 26}
        )
        old_authorization_id = next(
            authorization_id for authorization_id, history in rows
            if history is old_history
        )
        new_authorization_id, target = next(
            row for row in rows if row[1].protocol_version == 26
        )
        registration = settlement.settlement_registration(
            manager.router,
            target,
            activation_block=0,
            predecessor_version=old_history.protocol_version,
            release_manifest_hash=None,
        )
        target_manifest_hash = registration.release_manifest_hash
        target_registration_hash = settlement.target_registration_hash_v2(
            registration
        )
    manifest = settlement.ScheduledSeatMigration(
        1,
        25,
        26,
        target_manifest_hash,
        clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        clock.timestamp if executable_at is None else executable_at,
        old_authorization_id,
        new_authorization_id,
        target_registration_hash,
    )
    if manifest.key not in manager.arm_manifests:
        manager.schedule_seat_migration(
            manifest,
            caller=manager.governance,
            clock=settlement.Clock(
                max(
                    0,
                    clock.block_number
                    - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                ),
                manifest.scheduled_at,
            ),
        )
    return manager.arm_seat_migration(
        manifest_key=manifest.key,
        executor=addr("executor"),
        clock=clock,
    )


def execute_manager_abort(manager, clock, *, executable_at=None):
    armed = manager.arm_manifests[next(
        key for key in manager.arm_manifests if key[0] == 1
    )]
    manifest = replace(
        armed,
        scheduled_at=clock.timestamp - settlement.SEAT_MIGRATION_CANCEL_DELAY,
        executable_at=(
            clock.timestamp if executable_at is None else executable_at
        ),
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
    evolve_after_genesis: bool = True,
    preinstall_successor: bool = True,
    register_successor_in_release_manager: bool = True,
):
    old_auth = authorization()
    old_protocol = settlement.protocol(
        tip_slot=1_000, seat=False, settlement_address=old_auth.target
    )
    # Genesis activation must observe the fresh V2 seat namespace at its real
    # constructor value.  Most migration tests then model later ordinary seat
    # evolution by restoring the historical fixture generation.
    evolved_generation = old_protocol.seat_generation
    old_protocol.seat_generation = 0
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
        market_runtime_hash=settlement._model_fixed_bytes32(
            "runtime:seat-v1"
        ),
        market_configuration_hash=old_auth.configuration_hash,
        market_magic=old_auth.expected_magic,
        execution_profile=old_profile,
    )
    old_protocol.versioned_history = old_history
    profile_words = settlement._execution_profile_abi_words_v2(
        old_profile.canonical_profile_bytes
    )
    profile_router = "0x" + profile_words[23][12:].hex()
    profile_market = "0x" + profile_words[35][12:].hex()
    object.__setattr__(
        old_protocol.forced_queue, "router_address", profile_router
    )
    router = settlement.deploy_active_settlement_router(
        old_history,
        "0x" + profile_words[20][12:].hex(),
        old_protocol.forced_queue,
        old_protocol.inbox_apply_router,
        old_protocol.migration_gate,
        old_protocol.header_oracle,
        address=profile_router,
    )
    bootstrap_clock = settlement.Clock(
        max(400, old_protocol.canonical.canonicalized_at_block),
        settlement.GENESIS_TIMESTAMP + old_protocol.core.tip_slot,
    )
    bootstrap_proof = settlement.prepare_genesis_activation_for_test(
        router, old_history, bootstrap_clock
    )
    assert router.bootstrap(
        old_history,
        sequence=0,
        clock=bootstrap_clock,
        caller=router.version_manager,
        proof=bootstrap_proof,
    )
    if evolve_after_genesis:
        old_protocol.seat_generation = evolved_generation
    old_registration = router.registrations[router.active_version]
    old_auth = replace(
        old_auth,
        runtime_hash=settlement._model_fixed_bytes32(
            old_registration.runtime_hash
        ),
        target_manifest_hash=settlement._model_fixed_bytes32(
            old_registration.release_manifest_hash
        ),
        target_registration_hash=settlement.target_registration_hash_v2(
            old_registration
        ),
    )
    object.__setattr__(
        old_history, "market_runtime_hash", old_auth.runtime_hash
    )
    release_manager = market.ReleaseManager(
        addr("release-manager"), activation_authority=router
    )
    manager = settlement.ProtocolVersionManager(
        router.version_manager,
        router,
        release_manager=release_manager,
        market_chain_id=1,
        market_address=profile_market,
    )
    old_runtime = market.TargetRuntime(old_auth, old_history)
    old_id = release_manager.register_router_target(
        manager.address, 1, profile_market, old_auth, old_runtime
    )
    seat_market = market.SeatMarket(
        market_chain_id=1,
        market_address=profile_market,
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
        protocol_version_manager_address=router.version_manager,
        activation_router_address=router.address,
        activation_router_runtime_hash=market._model_component_hash(
            router.runtime_hash, "Router runtime"
        ),
        activation_router_configuration_hash=market._model_component_hash(
            router.configuration_hash, "Router configuration"
        ),
        seat_runway_seconds=old_protocol.seat_runway_seconds,
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
    )
    old_protocol.bind_seat_market_for_test(seat_market)

    new_auth = replace(
        old_auth,
        target=settlement.settlement_deployment_descriptor_for_test(
            "seat-market-authorized-settlement-v2", b"2" * 32, b"d" * 32
        ).target_settlement,
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
    elif target_header_variant == "replaceable-wrapper":
        # Production has no replaceable oracle object: an attempted wrapper is
        # simply outside the fixed EIP-2935 system-read graph.
        target_header_oracle = object()
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
    # Every release registered by this immutable PVM shares its protocol-root
    # manifest namespace; a successor cannot mint a parallel release domain.
    new_profile = settlement.execution_profile_for_test(
        new_auth.protocol_version, old_profile.namespace
    )
    new_profile = settlement.bind_execution_profile_to_router_graph_v2(
        new_profile, router
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
    new_registration = settlement.settlement_registration(
        router,
        new_history,
        activation_block=0,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    )
    new_auth = replace(
        new_auth,
        runtime_hash=settlement._model_fixed_bytes32(
            new_registration.runtime_hash
        ),
        target_manifest_hash=settlement._model_fixed_bytes32(
            new_registration.release_manifest_hash
        ),
        target_registration_hash=settlement.target_registration_hash_v2(
            new_registration
        ),
    )
    object.__setattr__(
        new_history, "market_runtime_hash", new_auth.runtime_hash
    )
    new_runtime = market.TargetRuntime(new_auth, new_history)
    new_id = market.authorization_identity(
        1, profile_market, new_auth
    )
    if register_successor_in_release_manager:
        self_registered_id = release_manager.register_router_target(
            manager.address, 1, profile_market, new_auth, new_runtime
        )
        assert self_registered_id == new_id
    if preinstall_successor:
        if not register_successor_in_release_manager:
            raise ValueError("legacy preinstall requires ReleaseManager registration")
        seat_market._pvm_preinstall_authorization(release_manager, new_id)
    new_protocol.seat_authorization_id = new_id
    new_protocol.seat_market_address = profile_market
    old_protocol.seat_authorization_id = old_id
    old_protocol.seat_market_address = profile_market
    assert router._seat_authorization_id_v1(old_registration) == old_id
    assert router._seat_authorization_id_v1(new_registration) == new_id
    return (
        old_protocol, old_history, new_history, seat_market, manager,
        release_manager, old_id, new_id,
    )


def protocol_authority_fixture():
    """Exact delayed PVM/Router/Market/Schedule journal fixture."""

    rows = production_migration_fixture(
        preinstall_successor=False,
        register_successor_in_release_manager=False,
    )
    router = rows[4].router
    witness = settlement.settlement_registration(
        router,
        rows[2],
        activation_block=0,
        predecessor_version=router.active_version,
        release_manifest_hash=None,
    )
    payload = settlement.encode_register_release_payload_for_registration_v1(
        witness
    )
    decoded = settlement.decode_register_release_payload_v1(payload)
    derived = settlement.derive_register_release_authority_v2(
        decoded.profile_bytes, decoded.expected_predecessor_protocol_version
    )
    deployment_world = settlement.live_deployment_world_for_release_v2(derived)
    # The behavioral target object represents the exact CREATE2 deployment
    # committed by the strict profile, not the older mutable witness tuple.
    object.__setattr__(
        witness.settlement, "address", "0x" + decoded.target_address.hex()
    )
    object.__setattr__(
        witness.settlement, "runtime_hash", decoded.target_runtime_hash
    )
    object.__setattr__(
        witness.settlement, "market_configuration_hash",
        decoded.target_configuration_hash,
    )
    object.__setattr__(
        witness.settlement,
        "settlement_deployment_descriptor",
        settlement.settlement_deployment_descriptor_from_profile_v2(
            witness.execution_profile
        ),
    )
    if witness.settlement.live_protocol is not None:
        object.__setattr__(
            witness.settlement.live_protocol, "settlement_address",
            witness.settlement.address,
        )
    # Retain the exact live deployment witness, rather than the pre-CREATE2
    # object snapshot used only to derive the payload bytes.
    witness = settlement.settlement_registration(
        router,
        witness.settlement,
        activation_block=0,
        predecessor_version=router.active_version,
        release_manifest_hash=decoded.release_manifest_hash,
    )
    assert settlement.encode_register_release_payload_for_registration_v1(
        witness
    ) == payload
    pvm_address = router.version_manager
    profile_words = settlement._execution_profile_abi_words_v2(
        decoded.profile_bytes
    )
    root_factory_address = "0x" + profile_words[202][12:].hex()
    router._source_bridge_factories_by_address[root_factory_address] = (
        settlement.ImmutableV2BridgeFactory(
            root_factory_address,
            "0x" + profile_words[203].hex(),
            "0x" + profile_words[204].hex(),
        )
    )
    pvm_authorization = market.TargetAuthorization(
        witness.settlement.address,
        int.from_bytes(profile_words[2], "big"),
        witness.settlement.protocol_version,
        decoded.target_runtime_hash,
        decoded.target_configuration_hash,
        b"SEAT",
        decoded.release_manifest_hash,
        decoded.target_registration_hash,
    )
    pvm_authorization_id = market.authorization_identity(
        int.from_bytes(profile_words[2], "big"),
        "0x" + profile_words[35][12:].hex(),
        pvm_authorization,
    )
    witness.settlement.live_protocol.seat_authorization_id = (
        pvm_authorization_id
    )
    witness.settlement.live_protocol.seat_market_address = (
        "0x" + profile_words[35][12:].hex()
    )
    witness = settlement.settlement_registration(
        router,
        witness.settlement,
        activation_block=0,
        predecessor_version=router.active_version,
        release_manifest_hash=decoded.release_manifest_hash,
    )
    assert settlement.encode_register_release_payload_for_registration_v1(
        witness
    ) == payload
    market_authority = settlement.PvmDerivedMarketAuthorizationV1(
        int.from_bytes(profile_words[2], "big"),
        "0x" + profile_words[35][12:].hex(), pvm_address,
        int.from_bytes(profile_words[2], "big"), router.address,
        profile_words[36], profile_words[37],
        storage_backend=rows[3],
    )
    schedule_oracle = settlement.ScheduleOracleV1(
        "0x" + profile_words[32][12:].hex(), pvm_address,
        current_window=100,
    )
    # The production authority graph has exactly one PVM.  The nested fixture
    # used an older manager only to construct the already-active predecessor;
    # retire that test scaffold before binding the delayed PVMv1.
    object.__setattr__(router, "_version_manager_authority", None)
    manager = settlement.ProtocolVersionManagerV1(
        pvm_address,
        int.from_bytes(profile_words[2], "big"),
        "0x" + profile_words[16][12:].hex(),
        router.address,
        "0x" + profile_words[26][12:].hex(),
        "0x" + profile_words[29][12:].hex(),
        schedule_oracle.address,
        market_authority, deployment_world,
        "0x" + profile_words[38][12:].hex(),
        "0x" + profile_words[41][12:].hex(),
        profile_words[18],
        profile_words[9],
        profile_words[36],
        profile_words[37],
        profile_words[21],
        tuple(profile_words[index] for index in (
            24, 25, 27, 28, 30, 31, 33, 34, 39, 40, 42, 43,
        )),
        active_protocol_version=router.active_version,
        router=router,
        release_witnesses={witness.settlement.protocol_version: witness},
        schedule_oracle=schedule_oracle,
    )
    support_registry = router._bridge_domain_registry_authority
    if type(support_registry) is settlement.BridgeDomainRegistry:
        object.__setattr__(support_registry, "manager", manager)
    timelock = settlement.ProtocolChangeTimelockV1(
        manager.timelock_address, manager.settlement_chain_id,
        "0x" + profile_words[19][12:].hex(), manager, profile_words[17],
    )
    return (
        rows, router, witness, payload, manager, timelock,
        market_authority, schedule_oracle,
        settlement.Clock(1_000, 1_000_000),
    )


def genesis_protocol_authority_fixture():
    """Delayed authority fixture whose Router is still on legacy genesis."""

    protocol, history, router, _ = unactivated_genesis_fixture(
        suffix="pvm-genesis-publication"
    )
    witness = settlement.settlement_registration(
        router, history, activation_block=0, predecessor_version=0,
        release_manifest_hash=None,
    )
    payload = settlement.encode_register_release_payload_for_registration_v1(
        witness
    )
    decoded = settlement.decode_register_release_payload_v1(payload)
    derived = settlement.derive_register_release_authority_v2(
        decoded.profile_bytes, decoded.expected_predecessor_protocol_version
    )
    deployment_world = settlement.live_deployment_world_for_release_v2(derived)
    object.__setattr__(
        witness.settlement, "address", "0x" + decoded.target_address.hex()
    )
    object.__setattr__(
        witness.settlement, "runtime_hash", decoded.target_runtime_hash
    )
    object.__setattr__(
        witness.settlement, "market_configuration_hash",
        decoded.target_configuration_hash,
    )
    object.__setattr__(
        witness.settlement,
        "settlement_deployment_descriptor",
        settlement.settlement_deployment_descriptor_from_profile_v2(
            witness.execution_profile
        ),
    )
    if witness.settlement.live_protocol is not None:
        object.__setattr__(
            witness.settlement.live_protocol, "settlement_address",
            witness.settlement.address,
        )
    witness = settlement.settlement_registration(
        router,
        witness.settlement,
        activation_block=0,
        predecessor_version=0,
        release_manifest_hash=decoded.release_manifest_hash,
    )
    assert settlement.encode_register_release_payload_for_registration_v1(
        witness
    ) == payload
    pvm_address = router.version_manager
    profile_words = settlement._execution_profile_abi_words_v2(
        decoded.profile_bytes
    )
    root_factory_address = "0x" + profile_words[202][12:].hex()
    router._source_bridge_factories_by_address[root_factory_address] = (
        settlement.ImmutableV2BridgeFactory(
            root_factory_address,
            "0x" + profile_words[203].hex(),
            "0x" + profile_words[204].hex(),
        )
    )
    market_authority = settlement.PvmDerivedMarketAuthorizationV1(
        int.from_bytes(profile_words[2], "big"),
        "0x" + profile_words[35][12:].hex(), pvm_address,
        int.from_bytes(profile_words[2], "big"), router.address,
        profile_words[36], profile_words[37],
    )
    schedule_oracle = settlement.ScheduleOracleV1(
        "0x" + profile_words[32][12:].hex(), pvm_address,
        current_window=100,
    )
    object.__setattr__(router, "_version_manager_authority", None)
    manager = settlement.ProtocolVersionManagerV1(
        pvm_address, int.from_bytes(profile_words[2], "big"),
        "0x" + profile_words[16][12:].hex(), router.address,
        "0x" + profile_words[26][12:].hex(),
        "0x" + profile_words[29][12:].hex(),
        schedule_oracle.address, market_authority, deployment_world,
        "0x" + profile_words[38][12:].hex(),
        "0x" + profile_words[41][12:].hex(),
        profile_words[18], profile_words[9],
        profile_words[36], profile_words[37],
        profile_words[21],
        tuple(profile_words[index] for index in (
            24, 25, 27, 28, 30, 31, 33, 34, 39, 40, 42, 43,
        )),
        active_protocol_version=0, router=router,
        release_witnesses={history.protocol_version: witness},
        schedule_oracle=schedule_oracle,
    )
    bridge_authorizations = tuple(
        authorization
        for authorization in witness.ingress_authorizations_by_address.values()
        if authorization.kind is settlement.ForceKind.BRIDGE_CREDIT
    )
    assert len(bridge_authorizations) == 1
    source_descriptor = bridge_authorizations[0].source_descriptor
    assert type(source_descriptor) is settlement.SourceBridgeDescriptor
    support_registry = settlement.BridgeDomainRegistry(
        router,
        manager,
        settlement.release_authority_descriptor_from_manifest(
            witness.release_manifest
        ),
        settlement.TestRegistrationMptVerifier(
            settlement.canonical_registration_mpt_verifier_descriptor()
        ),
        address=source_descriptor.support_registry_address,
        runtime_hash=source_descriptor.support_registry_runtime_hash,
        configuration_hash=(
            source_descriptor.support_registry_configuration_hash
        ),
    )
    object.__setattr__(
        router, "_bridge_domain_registry_authority", support_registry
    )
    timelock = settlement.ProtocolChangeTimelockV1(
        manager.timelock_address, manager.settlement_chain_id,
        "0x" + profile_words[19][12:].hex(), manager, profile_words[17],
    )
    return (
        (protocol, history), router, witness, payload, manager, timelock,
        market_authority, schedule_oracle,
        settlement.Clock(100, 1_000_000),
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
    target_registration = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=activation_clock.block_number,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    )
    target_manifest_hash = target_registration.release_manifest_hash
    target_registration_hash = settlement.target_registration_hash_v2(
        target_registration
    )
    manifest = settlement.ScheduledSeatMigration(
        1, 25, 26, target_manifest_hash,
        arm_clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        arm_clock.timestamp,
        old_id,
        new_id,
        target_registration_hash,
    )
    manager.schedule_seat_migration(
        manifest,
        caller=manager.governance,
        clock=settlement.Clock(
            max(
                0,
                arm_clock.block_number
                - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            ),
            manifest.scheduled_at,
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


def schedule_production_bridge_package(rows, *, arm_clock, staged_block):
    """Stage the exact successor package without arming migration."""

    (
        _old_protocol, old_history, new_history, _seat_market, manager,
        _release_manager, old_id, new_id,
    ) = rows
    target_registration = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=arm_clock.block_number + 1,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    )
    manifest = settlement.ScheduledSeatMigration(
        1,
        old_history.protocol_version,
        new_history.protocol_version,
        target_registration.release_manifest_hash,
        arm_clock.timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        arm_clock.timestamp,
        old_id,
        new_id,
        settlement.target_registration_hash_v2(target_registration),
    )
    manager.schedule_seat_migration(
        manifest,
        caller=manager.governance,
        clock=settlement.Clock(staged_block, manifest.scheduled_at),
    )
    return manifest, target_registration


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
    next_runtime = label.encode().ljust(32, b"r")[:32]
    next_configuration = label.encode().ljust(32, b"c")[:32]
    next_target = settlement.settlement_deployment_descriptor_for_test(
        f"production-successor:{label}", next_runtime, next_configuration
    ).target_settlement
    new_auth = replace(
        old_auth,
        target=next_target,
        protocol_version=protocol_version,
        runtime_hash=next_runtime,
        configuration_hash=next_configuration,
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
    # Successors remain inside the protocol-root manifest namespace.  The
    # immutable PVM rejects an alternate namespace before registration.
    new_profile = settlement.execution_profile_for_test(
        protocol_version, old_history.execution_profile.namespace
    )
    new_profile = settlement.bind_execution_profile_to_router_graph_v2(
        new_profile, manager.router
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
    preview = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=0,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    )
    new_auth = replace(
        new_auth,
        runtime_hash=settlement._model_fixed_bytes32(preview.runtime_hash),
        target_manifest_hash=settlement._model_fixed_bytes32(
            preview.release_manifest_hash
        ),
        target_registration_hash=settlement.target_registration_hash_v2(
            preview
        ),
    )
    object.__setattr__(
        new_history, "market_runtime_hash", new_auth.runtime_hash
    )
    runtime = market.TargetRuntime(new_auth, new_history)
    authorization_id = release_manager.register_router_target(
        manager.address,
        manager.market_chain_id,
        manager.market_address,
        new_auth,
        runtime,
    )
    rows[3]._pvm_preinstall_authorization(release_manager, authorization_id)
    new_protocol.seat_authorization_id = authorization_id
    new_protocol.seat_market_address = manager.market_address
    assert manager.router._seat_authorization_id_v1(preview) == authorization_id
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
    target_registration = settlement.settlement_registration(
        manager.router,
        new_history,
        activation_block=clock.block_number,
        predecessor_version=old_history.protocol_version,
        release_manifest_hash=None,
    )
    manifest_hash = target_registration.release_manifest_hash
    target_registration_hash = settlement.target_registration_hash_v2(
        target_registration
    )
    manifest = settlement.ScheduledSeatMigration(
        generation,
        old_history.protocol_version,
        new_history.protocol_version,
        manifest_hash,
        timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        timestamp,
        old_authorization_id,
        new_authorization_id,
        target_registration_hash,
    )
    manager.schedule_seat_migration(
        manifest,
        caller=manager.governance,
        clock=settlement.Clock(
            max(
                0,
                clock.block_number
                    - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            ),
            manifest.scheduled_at,
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
    _ = manifest_byte
    target_authorization_id, target_history = next(
        (authorization_id, runtime.authority)
        for authorization_id, runtime
        in manager.release_manager.target_runtimes.items()
        if runtime.authority.protocol_version == target_version
    )
    target_registration = settlement.settlement_registration(
        manager.router,
        target_history,
        activation_block=0,
        predecessor_version=history.protocol_version,
        release_manifest_hash=None,
    )
    manifest_hash = target_registration.release_manifest_hash
    arm = settlement.ScheduledSeatMigration(
        generation,
        history.protocol_version,
        target_version,
        manifest_hash,
        timestamp - settlement.SEAT_MIGRATION_MANIFEST_DELAY,
        timestamp,
        protocol.seat_authorization_id,
        target_authorization_id,
        settlement.target_registration_hash_v2(target_registration),
    )
    manager.schedule_seat_migration(
        arm,
        caller=manager.governance,
        clock=settlement.Clock(
            max(
                0,
                clock.block_number
                    - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            ),
            arm.scheduled_at,
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
        self._atomic_liquidity_credits = set()
        self._atomic_liquidity_tickets = {}

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
                self._atomic_liquidity_credits.add(
                    settlement.destination_credit_id_v2(
                        message, source, route
                    )
                )
        return message, source, route

    def liquidity_ticket(self, delivery, *, depositor, amount=None):
        message, source, route = delivery
        credit_id = settlement.destination_credit_id_v2(*delivery)
        key = (credit_id, depositor)
        ticket_id = self._atomic_liquidity_tickets.get(key)
        if ticket_id is not None and ticket_id in (
                self.destination_bridge.liquidity_pool.tickets):
            return ticket_id
        exact_amount = message.value + message.fee if amount is None else amount
        ticket_id = self.destination_bridge.liquidity_pool.deposit(
            caller=depositor,
            l1_recipient=addr(f"l1-{len(self._atomic_liquidity_tickets)}"),
            salt=hashlib.sha256(
                f"{credit_id}:{depositor}:{len(self._atomic_liquidity_tickets)}"
                .encode()
            ).digest(),
            amount=exact_amount,
        )
        self.assertTrue(ticket_id)
        self._atomic_liquidity_tickets[key] = ticket_id
        return ticket_id

    def process_destination(self, delivery, *, caller):
        credit_id = settlement.destination_credit_id_v2(*delivery)
        if credit_id not in self._atomic_liquidity_credits:
            return self.destination_bridge.process(*delivery, caller=caller)
        ticket_id = self.liquidity_ticket(delivery, depositor=caller)
        return self.destination_bridge.liquidity_pool.process_with_liquidity(
            ticket_id, self.destination_bridge, *delivery, caller=caller,
        )

    def retry_destination(self, delivery, *, caller, is_last_attempt):
        credit_id = settlement.destination_credit_id_v2(*delivery)
        if credit_id not in self._atomic_liquidity_credits:
            return self.destination_bridge.retry(
                *delivery, caller=caller, is_last_attempt=is_last_attempt,
            )
        ticket_id = self.liquidity_ticket(delivery, depositor=caller)
        return self.destination_bridge.liquidity_pool.retry_with_liquidity(
            ticket_id, self.destination_bridge, *delivery, caller=caller,
            is_last_attempt=is_last_attempt,
        )

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
            migration_queue._migrate_from_router(
                bytes(),
                router=rows[4].router,
            )
        )
        self.assertFalse(
            migration_queue._migrate_from_router(
                b"forged-qmig-calldata",
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

    def test_bridge_adapter_config_is_exact_five_address_grammar(self):
        fields = {
            "source_registry_address": self.credit_registry.address,
            "source_bridge_address": self.source_bridge.address,
            "router_address": self.router.address,
            "queue_address": self.router.forced_queue.address,
            "seal_authority": self.router.version_manager,
        }
        exact_preimage = b"".join(
            settlement._model_address20(fields[name])
            for name in (
                "source_registry_address",
                "source_bridge_address",
                "router_address",
                "queue_address",
                "seal_authority",
            )
        )
        self.assertEqual(len(exact_preimage), 100)
        expected = "0x" + settlement.keccak256(
            settlement.D_COMPONENT_CONFIG
            + bytes((1,))
            + len(exact_preimage).to_bytes(2, "big")
            + exact_preimage
        ).hex()
        common = {
            "router_runtime_hash": self.router.runtime_hash,
            "router_configuration_hash": self.router.configuration_hash,
            "queue_runtime_hash": self.router.forced_queue.runtime_hash,
            "queue_configuration_hash": self.router.forced_queue.config_hash,
            "source_registry_runtime_hash": self.credit_registry.runtime_hash,
            "source_registry_configuration_hash": (
                self.credit_registry.configuration_hash
            ),
            "source_bridge_runtime_hash": self.source_bridge.runtime_hash,
            "source_bridge_configuration_hash_": (
                self.source_bridge.configuration_hash
            ),
        }
        self.assertEqual(
            settlement.bridge_ingress_component_configuration_hash(
                **fields, **common
            ),
            expected,
        )
        self.assertEqual(self.bridge_adapter.configuration_hash, expected)

        for name in fields:
            with self.subTest(mutated_field=name):
                mutated = dict(fields)
                mutated[name] = addr(f"other-{len(name)}")
                self.assertNotEqual(
                    settlement.bridge_ingress_component_configuration_hash(
                        **mutated, **common
                    ),
                    expected,
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
            ("05ecb6c2", "c978978a", 36, 36, 704, 288),
        )
        self.assertIsNone(registry.credit_authorization_v2(
            b"\x00" * 36, gas=settlement.SOURCE_READ_GAS
        ))
        self.assertIsNone(bridge.credit_liability_v2(
            liability_call + b"\x00", gas=settlement.SOURCE_READ_GAS
        ))
        decoded_authorization = registry.decode_credit_authorization_v2(
            receipt.credit_id, authorization_return
        )
        decoded_liability = bridge.decode_credit_liability_v2(
            receipt.credit_id, liability_return
        )
        self.assertEqual(
            settlement.encode_credit_authorization_v2(decoded_authorization),
            settlement.encode_credit_authorization_v2(
                registry.authorizations[receipt.credit_id]
            ),
        )
        self.assertIsNot(
            decoded_authorization,
            registry.authorizations[receipt.credit_id],
        )
        self.assertIsNotNone(decoded_liability)
        self.assertIsNot(
            decoded_liability[0], bridge._credits[receipt.credit_id]
        )
        wrong_credit_id = (b"\xff" * 32).hex()
        self.assertIsNone(registry.decode_credit_authorization_v2(
            wrong_credit_id, authorization_return
        ))

        class NoHistoryScanDict(dict):
            def items(self):
                raise AssertionError("fixed-gas source read scanned history")

            def values(self):
                raise AssertionError("fixed-gas source read scanned history")

        original_authorizations = registry._authorizations
        original_credits = bridge._credits
        indexed_authorizations = NoHistoryScanDict(original_authorizations)
        indexed_credits = NoHistoryScanDict(original_credits)
        for index in range(10_000):
            key = f"{index:064x}"
            if key != receipt.credit_id:
                dict.__setitem__(
                    indexed_authorizations, key, decoded_authorization
                )
                dict.__setitem__(
                    indexed_credits, key, decoded_liability[0]
                )
        registry._authorizations = indexed_authorizations
        bridge._credits = indexed_credits
        try:
            self.assertEqual(
                registry.credit_authorization_v2(
                    authorization_call, gas=settlement.SOURCE_READ_GAS
                ),
                authorization_return,
            )
            self.assertEqual(
                bridge.credit_liability_v2(
                    liability_call, gas=settlement.SOURCE_READ_GAS
                ),
                liability_return,
            )
        finally:
            registry._authorizations = original_authorizations
            bridge._credits = original_credits

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
            bridge.source_domain_id,
            bridge.frozen_bridge_execution_hash,
            self.destination_manifest.destination_chain_id,
            clock,
            source_bridge=bridge.address,
            caller=bridge.address,
            target="ordinary-target",
        )
        self.assertIsNotNone(support)
        # A source send is authorized by the currently active release's BIP1,
        # not by a separately constructed future destination release.  Fresh
        # successor domains cannot receive an old route's credit.
        active_manifest = self.router.registrations[
            self.router.active_version
        ].release_manifest
        denyset = active_manifest.destination_bridge_descriptor \
            .privileged_target_denyset
        self.assertIn("signal-service", denyset)
        self.assertIn("delegate-controller", denyset)
        self.assertIn(
            active_manifest.destination_bridge_descriptor.native_quota_manager,
            denyset,
        )
        self.assertIn(
            active_manifest.destination_bridge_descriptor
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

    def test_legacy_active_route_accepts_final_or_consumed_row(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        entry = bridge.domain_registry.latest_final_entry(
            bridge.source_domain_id,
            bridge.frozen_bridge_execution_hash,
            self.destination_manifest.destination_chain_id,
            clock,
            source_bridge=bridge.address,
            caller=bridge.address,
            target="ordinary-target",
        )
        self.assertIsNotNone(entry)
        self.assertEqual(entry.route_kind, "LEGACY")
        self.assertFalse(entry.arm_ready_consumed)
        message = settlement.bridge_message(
            clock.timestamp, "legacy-route-two-states", to="ordinary-target",
            value=1, fee=0,
        )
        self.assertTrue(bridge.credit_id_for(message, clock))

        # Once a legacy row was atomically consumed it no longer needs the
        # older confirmation-finality fallback, but remains the same route.
        entry.arm_ready_consumed = True
        entry.confirmed_at_block = None
        self.assertTrue(bridge.credit_id_for(message, clock))

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
                ticket_id = self.liquidity_ticket(
                    delivery, depositor=addr("relayer")
                )
                pool_before = pool._snapshot()
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
                self.assertEqual(self.process_destination(
                    delivery, caller=addr("relayer")
                ), "FAILED")
                self.assertEqual(
                    pool.tickets[ticket_id].available_amount, 5
                )
                self.assertEqual(pool._snapshot(), pool_before)
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.retry_destination(
            retry_delivery,
            caller=retry_delivery[0].destination_owner,
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            zero_empty, caller=addr("relayer")
        ), "DONE")
        self.assertEqual(receiver.received, received_before)

        value_empty = self.destination_delivery(
            "value-empty", to=receiver.address, value=1, fee=0, data=b""
        )
        self.assertEqual(self.process_destination(
            value_empty, caller=addr("relayer")
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
            self.assertEqual(self.process_destination(
                delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            failing, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            old_delivery, caller=addr("relayer")
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
        new_ticket = settlement.deposit_destination_liquidity_for_test(
            new_bridge, new_message, depositor=addr("relayer"),
            salt="future-ticket",
        )
        self.assertTrue(new_ticket)
        self.assertEqual(new_bridge.liquidity_pool.process_with_liquidity(
            new_ticket, new_bridge, new_message, new_source, new_route,
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
            settlement._model_address20(
                self.source_bridge.source_descriptor.legacy_v1_bridge
            ),
            settlement._model_address20(legacy_v1["source_address"]),
        )
        self.assertNotEqual(
            self.destination_bridge.address,
            legacy_v1["destination_address"],
        )
        delivery = self.destination_delivery("fresh-v2-isolation")
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
        ), "REJECTED")
        self.assertNotIn(
            settlement.destination_credit_id_v2(*delivery),
            self.destination_bridge.status,
        )
        self.destination_environment.available_gas = threshold
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
        ), "DONE")

        oog = self.destination_delivery("callee-oog")
        self.destination_receiver.exhausts_forwarded_gas = True
        self.destination_environment.available_gas = 10_000_000
        self.assertEqual(self.process_destination(
            oog, caller=addr("relayer")
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
        ), "NEW")
        self.assertEqual(self.destination_bridge.total_pull_liability, 0)
        self.assertEqual(
            (self.destination_bridge.balance,
             self.destination_bridge.ether_quota),
            (balance, quota),
        )
        self.assertEqual(self.process_destination(
            delivery, caller=delivery[0].destination_owner
        ), "RETRIABLE")
        self.assertEqual(self.destination_bridge.total_pull_liability, 0)
        self.destination_receiver.fault_point = None
        self.assertEqual(self.retry_destination(
            delivery, caller=addr("retry-relayer"), is_last_attempt=False
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
        self.assertEqual(self.process_destination(
            owner_delivery, caller=owner
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
        self.assertEqual(self.process_destination(
            delivery, caller=addr("relayer")
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

    def test_source_pull_reclassification_overflow_is_atomic(self):
        bridge = self.source_bridge
        clock = bridge.support_final_clock(self.clock.timestamp)
        envelope = settlement.bridge_message(
            self.clock.l2_slot,
            "source-overflow-atomic",
            value=2,
            fee=1,
            liquidity_fee=1,
        )
        enqueue_by = (
            clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        )
        receipt = bridge.send_message(
            envelope,
            caller=addr("overflow-owner"),
            msg_value=4,
            clock=clock,
            enqueue_by=enqueue_by,
        )
        credit_before = copy.deepcopy(bridge.credits[receipt.credit_id])
        refund_owner = bridge.credit_registry.authorizations[
            receipt.credit_id
        ].owner
        settlement.set_source_v2_accounting_for_test(
            bridge,
            refunds={refund_owner: settlement.SEAT_UINT256_MAX},
        )
        refunds_before = dict(bridge.refunds)
        self.assertFalse(bridge.cancel(
            receipt.credit_id, now=enqueue_by + 1,
        ))
        self.assertEqual(bridge.credits[receipt.credit_id], credit_before)
        self.assertEqual(bridge.refunds, refunds_before)

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

    def test_source_lp_pull_failure_retries_and_is_reentrant_safe(self):
        bridge = self.source_bridge
        lp_recipient = addr("lp-pull-owner")
        settlement.set_source_v2_accounting_for_test(
            bridge,
            liquidity_claims={lp_recipient: 9},
            total_liability=9,
        )
        bridge.balance = 9
        receiver = settlement.SourceNativeReceiverV2(
            addr("lp-pull-receiver"), rejects_native=True
        )
        self.assertTrue(bridge.native_environment.deploy_receiver(receiver))
        before = bridge._transaction_snapshot()
        self.assertEqual(bridge.withdraw_liquidity_claim(
            lp_recipient, receiver.address
        ), 0)
        self.assertEqual(bridge._transaction_snapshot(), before)
        nested = []
        receiver.rejects_native = False
        receiver.callback = lambda exact_bridge: nested.append(
            exact_bridge.withdraw_liquidity_claim(
                lp_recipient, addr("nested-lp-pull")
            )
        )
        self.assertEqual(bridge.withdraw_liquidity_claim(
            lp_recipient, receiver.address
        ), 9)
        self.assertEqual(nested, [0])
        self.assertNotIn(lp_recipient, bridge.liquidity_claims)
        self.assertEqual(
            (bridge.balance, bridge.total_live_liability),
            (0, 0),
        )
        self.assertEqual(receiver.balance, 9)

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
            self.assertEqual(self.process_destination(
                delivery, caller=addr("relayer")
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
        self.assertNotEqual(release.components[2], successor.components[2])
        self.assertNotEqual(
            release.execution_profile.canonical_profile_bytes,
            successor.execution_profile.canonical_profile_bytes,
        )
        second_successor = settlement.release_manifest_fixture(
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
        self.assertNotEqual(
            release.destination_bridge, second_successor.destination_bridge
        )
        self.assertNotEqual(
            release.destination_domain_id,
            second_successor.destination_domain_id,
        )
        self.assertTrue(
            settlement.historical_v2_privileged_policy_compatible(
                release, second_successor,
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
            caller=addr("lp"), l1_recipient=addr("lp-l1"),
            salt="prelaunch", amount=7,
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
            caller=addr("lp"), l1_recipient=addr("lp-l1"),
            salt="postlaunch", amount=7,
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
        registrar.authority.release_activation_return_override = b"RAV2"
        malformed_deployment = settlement.bridge_deployment_state_for_test(
            manifest
        )
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
            bridge_deployment=malformed_deployment,
            retirement_queue_watermark=9,
        ))
        self.assertNotIn(80, registrar.authority.releases)
        self.assertNotIn(
            80, registrar.authority.release_retirement_queue_counts
        )
        self.assertFalse(registrar.liquidity_pool.bridge_by_domain)
        self.assertFalse(registrar.liquidity_pool.domain_by_bridge)
        registrar.authority.release_activation_return_override = None
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
        self.assertEqual(
            registrar.authority.release_activation_v2(80),
            b"RAV2" + bytes(28) + manifest.commitment
            + settlement._model_uint(9, 32, "test RAV2 Queue count"),
        )
        replay_anchor = settlement.AnchorV4Model(
            manifest.anchor,
            manifest.anchor_runtime_hash,
            manifest.commitment,
        )
        self.assertTrue(replay_anchor.authenticate(manifest))
        self.assertFalse(registrar.authority.activate(
            manifest,
            8,
            caller=replay_anchor,
            tx_origin=registrar.authority.system_sender,
        ))

    def test_destination_successor_receipts_gate_bounded_reclaim(self):
        protocol, manager = migration_manager_fixture(seat=False)
        registrar = protocol.inbox_apply_router._terminal_registrar_authority
        authority = protocol._inbox_execution_authority
        protocol.forced_queue.count = 9
        registrar.inbox_router.next_queue_index = 3

        def activate(version, label, block_number, *, expected=True):
            store = settlement.InboxCreditStoreV2(
                "inbox-apply", f"bridge:{label}", ""
            )
            manifest = settlement.release_manifest_fixture(
                version, "", f"bridge:{label}", store,
                router=manager.router,
            )
            deployment = settlement.bridge_deployment_state_for_test(manifest)
            activated = settlement.execute_release_activation_for_test(
                authority,
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
                retirement_queue_watermark=9,
                activated_at_block=block_number,
            )
            self.assertEqual(activated, expected)
            return manifest, store

        first, first_store = activate(80, "receipt-first", 1_000)
        self.assertEqual(registrar.destination_successor_index, 1)
        self.assertEqual(
            registrar.liquidity_pool.bridge_by_domain[
                first.destination_domain_id
            ],
            first.destination_bridge,
        )
        self.assertEqual(
            registrar.liquidity_pool.domain_by_bridge[
                first.destination_bridge
            ],
            first.destination_domain_id,
        )
        first_raw = next(iter(
            registrar.destination_activation_receipt_rows.values()
        ))
        first_receipt = settlement.decode_destination_activation_receipt_v2(
            first_raw
        )
        self.assertEqual(
            (
                first_receipt.old_protocol_version,
                first_receipt.old_manifest_hash,
                first_receipt.old_domain_id,
                first_receipt.old_bridge,
            ),
            (0, bytes(32), bytes(32), bytes(20)),
        )
        self.assertFalse(registrar.destination_successor_receipt_rows)
        self.assertFalse(registrar.liquidity_pool._bridge_authorities)

        old_bridge = settlement.destination_bridge_for_test(
            first,
            first_store,
            registrar.accumulator,
            balance=17,
        )
        second, second_store = activate(81, "receipt-second", 1_001)
        old_key = (
            settlement._model_fixed_bytes32(first.destination_domain_id),
            settlement._model_address20(first.destination_bridge),
        )
        successor_raw = registrar.destination_successor_receipt_rows[old_key]
        receipt_id = successor_raw[:32]
        second_receipt = settlement.decode_destination_activation_receipt_v2(
            registrar.destination_activation_receipt_rows[receipt_id]
        )
        self.assertEqual(
            (
                second_receipt.successor_index,
                second_receipt.old_protocol_version,
                second_receipt.new_protocol_version,
                second_receipt.old_manifest_hash,
                second_receipt.new_manifest_hash,
                second_receipt.retirement_queue_count,
                second_receipt.activated_at_block,
            ),
            (2, 80, 81, first.commitment, second.commitment, 9, 1_001),
        )

        second_bridge = settlement.destination_bridge_for_test(
            second,
            second_store,
            registrar.accumulator,
            balance=23,
        )
        third, _ = activate(82, "receipt-third", 1_002)
        self.assertEqual(
            registrar.active_destination_manifest_hash, third.commitment
        )
        self.assertNotEqual(
            second_receipt.new_manifest_hash,
            registrar.active_destination_manifest_hash,
        )

        self.assertEqual(
            old_bridge.reclaim_surplus(caller=addr("early-reclaimer")),
            (settlement.ReclaimResult.REJECTED, 0),
        )
        registrar.inbox_router.next_queue_index = 9
        registrar.destination_successor_return_override = b"DSV2"
        self.assertEqual(
            old_bridge.reclaim_surplus(caller=addr("bad-abi")),
            (settlement.ReclaimResult.REJECTED, 0),
        )
        registrar.destination_successor_return_override = None
        registrar.destination_receipt_fault_point = "revert"
        self.assertEqual(
            old_bridge.reclaim_surplus(caller=addr("revert-abi")),
            (settlement.ReclaimResult.REJECTED, 0),
        )
        registrar.destination_receipt_fault_point = None
        old_route = registrar.inbox_router.routes.get(
            old_bridge.local_domain_id
        )
        old_manifest = old_bridge.release_manifest
        self.assertTrue(old_manifest.structurally_valid())
        self.assertFalse(old_bridge.retired)
        self.assertTrue(old_bridge.v2_active)
        self.assertFalse(old_bridge.entered)
        self.assertEqual(
            registrar.retirement_queue_watermarks.get(old_bridge.address), 9
        )
        self.assertGreater(second_receipt.new_protocol_version, 80)
        self.assertNotEqual(second_receipt.new_bridge, bytes(20))
        self.assertNotEqual(
            second_receipt.new_bridge,
            settlement._model_address20(old_bridge.address),
        )
        self.assertGreater(second_receipt.activated_at_block, 0)
        self.assertGreaterEqual(registrar.inbox_router.next_queue_index, 9)
        self.assertTrue(all(
            settlement._model_address20(expected.address)
                == settlement._model_address20(actual.address)
            and settlement._model_fixed_bytes32(expected.runtime_hash)
                == settlement._model_fixed_bytes32(actual.runtime_hash)
            and settlement._model_fixed_bytes32(expected.config_hash)
                == settlement._model_fixed_bytes32(actual.config_hash)
            for expected, actual in zip(
                (old_manifest.components[index]
                 for index in (3, 5, 6, 7, 8)),
                (
                    settlement.ReleaseComponentV2(
                        registrar.inbox_router.address,
                        registrar.inbox_router.runtime_hash,
                        registrar.inbox_router.configuration_hash,
                    ),
                    settlement.ReleaseComponentV2(
                        registrar.authority.address,
                        registrar.authority.runtime_hash,
                        registrar.authority.configuration_hash,
                    ),
                    settlement.ReleaseComponentV2(
                        registrar.address,
                        registrar.runtime_hash,
                        registrar.configuration_hash,
                    ),
                    settlement.ReleaseComponentV2(
                        registrar.accumulator.address,
                        registrar.accumulator.runtime_hash,
                        registrar.accumulator.configuration_hash,
                    ),
                    settlement.ReleaseComponentV2(
                        registrar.liquidity_pool.address,
                        registrar.liquidity_pool.runtime_hash,
                        registrar.liquidity_pool.configuration_hash,
                    ),
                ),
            )
        ))
        self.assertEqual(
            (
                second_receipt.receipt_id,
                second_receipt.old_protocol_version,
                second_receipt.old_manifest_hash,
                second_receipt.old_domain_id,
                second_receipt.old_bridge,
                second_receipt.retirement_queue_count,
                second_receipt.sealed,
            ),
            (
                receipt_id,
                old_manifest.protocol_version,
                old_manifest.commitment,
                settlement._model_fixed_bytes32(
                    old_bridge.local_domain_id
                ),
                settlement._model_address20(old_bridge.address),
                9,
                1,
            ),
        )
        self.assertIs(old_route.store, old_bridge.inbox_store)
        self.assertEqual(old_route.destination_bridge, old_bridge.address)
        self.assertIs(
            registrar.accumulator, old_bridge.terminal_accumulator
        )
        self.assertEqual(
            registrar.accumulator.domains.get(old_bridge.local_domain_id),
            old_bridge.address,
        )
        self.assertEqual(
            registrar.accumulator.terminalized_pinned_count.get(
                old_bridge.local_domain_id
            ),
            old_bridge.inbox_store.pinned_count,
        )
        self.assertEqual(old_bridge.total_pull_liability, 0)
        self.assertEqual(
            registrar.authority.releases.get(old_manifest.protocol_version),
            old_manifest.commitment,
        )
        self.assertEqual(
            registrar.registrations.get(old_manifest.protocol_version),
            old_manifest.registration_commitment,
        )
        self.assertIs(
            old_bridge.bridge_surplus_sink,
            old_manifest.execution_profile.bridge_surplus_sink,
        )
        self.assertIsInstance(
            old_manifest.execution_profile, settlement.ExecutionProfile
        )
        self.assertEqual(
            old_manifest.execution_profile.execution_profile_hash,
            old_manifest.execution_profile_hash,
        )
        self.assertEqual(old_bridge.bridge_surplus_sink.asset_id, "NATIVE_ETH")
        self.assertTrue(old_bridge.bridge_surplus_sink.address)
        self.assertEqual(
            old_bridge.reclaim_surplus(caller=addr("reclaimer")),
            (settlement.ReclaimResult.RECLAIMED_VALUE, 17),
        )
        self.assertTrue(old_bridge.retired)
        self.assertEqual(
            old_bridge.reclaim_surplus(caller=addr("double")),
            (settlement.ReclaimResult.REJECTED, 0),
        )
        self.assertEqual(
            second_bridge.reclaim_surplus(caller=addr("middle-reclaimer")),
            (settlement.ReclaimResult.RECLAIMED_VALUE, 23),
        )
        self.assertTrue(second_bridge.retired)

        registrar.destination_successor_index = settlement.UINT64_MAX - 1
        fourth, _ = activate(83, "receipt-index-maximum", 1_003)
        self.assertEqual(
            registrar.destination_successor_index, settlement.UINT64_MAX
        )
        activation_rows = dict(
            registrar.destination_activation_receipt_rows
        )
        activate(
            84, "receipt-index-overflow", 1_004, expected=False
        )
        self.assertEqual(
            registrar.destination_successor_index, settlement.UINT64_MAX
        )
        self.assertEqual(
            registrar.destination_activation_receipt_rows, activation_rows
        )
        self.assertEqual(
            registrar.active_destination_manifest_hash, fourth.commitment
        )
        self.assertNotIn(84, registrar.authority.releases)

    def test_atomic_ticket_salt_topup_partial_withdraw_delete_and_recreate(self):
        pool = self.destination_bridge.liquidity_pool
        depositor = addr("salt-lp")
        recipient = addr("salt-l1")
        salt = bytes.fromhex("42" * 32)
        expected = settlement.keccak256(b"".join((
            b"slot-chain-liquidity-ticket-v2",
            settlement._model_uint(
                pool.destination_chain_id, 32, "ticket chain"
            ),
            settlement._model_address20(pool.address),
            settlement._model_address20(depositor),
            settlement._model_address20(recipient),
            salt,
        ))).hex()
        ticket_id = pool.deposit(
            caller=depositor, l1_recipient=recipient,
            salt=salt, amount=10,
        )
        self.assertEqual(ticket_id, expected)
        self.assertEqual(pool.deposit(
            caller=depositor, l1_recipient=recipient,
            salt=salt, amount=5,
        ), ticket_id)
        other = pool.deposit(
            caller=depositor, l1_recipient=addr("other-l1"),
            salt=salt, amount=2,
        )
        self.assertTrue(other)
        self.assertNotEqual(other, ticket_id)
        self.assertIsNone(pool.withdraw_available(
            ticket_id, caller=addr("attacker"), recipient=depositor,
            amount=1,
        ))
        self.assertEqual(pool.withdraw_available(
            ticket_id, caller=depositor, recipient=depositor, amount=6,
        ), 9)
        self.assertEqual(pool.withdraw_available(
            ticket_id, caller=depositor, recipient=depositor, amount=9,
        ), 0)
        self.assertNotIn(ticket_id, pool.tickets)
        self.assertEqual(pool.deposit(
            caller=depositor, l1_recipient=recipient,
            salt=salt, amount=3,
        ), ticket_id)
        self.assertEqual(pool.tickets[ticket_id].available_amount, 3)
        self.assertEqual(pool.withdraw_available(
            ticket_id, caller=depositor, recipient=depositor, amount=3,
        ), 0)
        self.assertEqual(pool.withdraw_available(
            other, caller=depositor, recipient=depositor, amount=2,
        ), 0)
        maximum = pool.deposit(
            caller=depositor, l1_recipient=recipient,
            salt="maximum", amount=settlement.SEAT_UINT256_MAX,
        )
        self.assertTrue(maximum)
        before = pool._snapshot()
        self.assertIsNone(pool.deposit(
            caller=depositor, l1_recipient=recipient,
            salt="maximum", amount=1,
        ))
        self.assertEqual(pool._snapshot(), before)
        self.assertEqual(pool.withdraw_available(
            maximum, caller=depositor, recipient=depositor,
            amount=settlement.SEAT_UINT256_MAX,
        ), 0)
        self.assertEqual((pool.balance, pool.total_available), (0, 0))

    def test_atomic_first_success_wins_without_touching_losing_ticket(self):
        delivery = self.destination_delivery(
            "atomic-race", value=4, fee=2, fund_liquidity=False,
        )
        pool = self.destination_bridge.liquidity_pool
        first = addr("first-lp")
        second = addr("second-lp")
        first_ticket = pool.deposit(
            caller=first, l1_recipient=addr("first-l1"),
            salt="race-a", amount=10,
        )
        second_ticket = pool.deposit(
            caller=second, l1_recipient=addr("second-l1"),
            salt="race-b", amount=6,
        )
        second_before = pool.tickets[second_ticket].available_amount
        self.assertEqual(pool.process_with_liquidity(
            first_ticket, self.destination_bridge, *delivery, caller=first,
        ), "DONE")
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.assertEqual(pool.tickets[first_ticket].available_amount, 4)
        self.assertEqual(
            self.destination_bridge._terminal_settlements[credit_id],
            settlement.NativeLiquiditySettlementV2(
                first_ticket, addr("first-l1"), 6
            ),
        )
        losing_before = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            second_ticket, self.destination_bridge, *delivery, caller=second,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), losing_before)
        self.assertEqual(
            pool.tickets[second_ticket].available_amount, second_before
        )

    def test_atomic_process_deadline_equality_and_late_failure(self):
        equality = self.destination_delivery(
            "atomic-equality", value=2, fee=1, fund_liquidity=False,
        )
        pool = self.destination_bridge.liquidity_pool
        owner = addr("deadline-lp")
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("deadline-l1"),
            salt="deadline-eq", amount=3,
        )
        credit = settlement.destination_credit_id_v2(*equality)
        self.destination_environment.block_timestamp = (
            self.destination_store.pins[credit].process_by
        )
        self.assertEqual(pool.process_with_liquidity(
            ticket, self.destination_bridge, *equality, caller=owner,
        ), "DONE")

        late = self.destination_delivery(
            "atomic-late", value=2, fee=1, fund_liquidity=False,
        )
        late_ticket = pool.deposit(
            caller=owner, l1_recipient=addr("deadline-l1"),
            salt="deadline-late", amount=3,
        )
        late_credit = settlement.destination_credit_id_v2(*late)
        self.destination_environment.block_timestamp = (
            self.destination_store.pins[late_credit].process_by + 1
        )
        before = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            late_ticket, self.destination_bridge, *late, caller=owner,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), before)
        self.assertTrue(self.destination_bridge.expire_v2(late_credit))
        self.assertEqual(pool._snapshot(), before)

    def test_atomic_target_failure_and_owner_last_failure_preserve_ticket(self):
        typed_failure = settlement.TargetCallFailedV2(bytes.fromhex("11" * 32))
        self.assertEqual(
            typed_failure.return_data,
            settlement.TARGET_CALL_FAILED_V2_SELECTOR + bytes.fromhex("11" * 32),
        )
        self.assertEqual(len(typed_failure.return_data), 36)
        delivery = self.destination_delivery(
            "atomic-last", value=5, fee=2, fund_liquidity=False,
        )
        pool = self.destination_bridge.liquidity_pool
        owner = delivery[0].destination_owner
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("last-l1"),
            salt="owner-last", amount=7,
        )
        before = pool._snapshot()
        target_before = self.destination_receiver._transaction_snapshot()
        quota_before = self.destination_bridge.ether_quota
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(pool.process_with_liquidity(
            ticket, self.destination_bridge, *delivery, caller=owner,
        ), "RETRIABLE")
        self.assertEqual(pool._snapshot(), before)
        self.assertEqual(
            self.destination_receiver._transaction_snapshot(), target_before
        )
        self.assertEqual(self.destination_bridge.ether_quota, quota_before)
        nonowner_delivery = self.destination_delivery(
            "atomic-nonowner-failure", value=5, fee=2,
            fund_liquidity=False,
        )
        nonowner = addr("nonowner-failure")
        nonowner_ticket = pool.deposit(
            caller=nonowner, l1_recipient=addr("nonowner-failure-l1"),
            salt="nonowner-failure", amount=7,
        )
        nonowner_before = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            nonowner_ticket, self.destination_bridge, *nonowner_delivery,
            caller=nonowner,
        ), "NEW")
        self.assertEqual(pool._snapshot(), nonowner_before)
        self.assertNotIn(
            settlement.destination_credit_id_v2(*nonowner_delivery),
            self.destination_bridge.status,
        )
        observer = addr("last-observer")
        observer_ticket = pool.deposit(
            caller=observer, l1_recipient=addr("observer-l1"),
            salt="observer-last", amount=7,
        )
        observer_before = pool._snapshot()
        self.assertEqual(pool.retry_with_liquidity(
            observer_ticket, self.destination_bridge, *delivery,
            caller=observer, is_last_attempt=True,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), observer_before)
        self.assertEqual(pool.retry_with_liquidity(
            ticket, self.destination_bridge, *delivery,
            caller=owner, is_last_attempt=True,
        ), "FAILED")
        self.assertEqual(pool._snapshot(), observer_before)
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.assertEqual(self.destination_bridge.status[credit_id], "FAILED")
        self.assertNotIn(
            credit_id, self.destination_bridge._terminal_settlements
        )

    def test_atomic_value_callback_and_all_faults_restore_every_journal(self):
        bridge = self.destination_bridge
        pool = bridge.liquidity_pool
        self.assertEqual(
            settlement.ACCEPT_LIQUIDITY_VALUE_V2_SELECTOR.hex(), "a34908bb"
        )
        self.assertEqual(
            settlement.ACCEPT_LIQUIDITY_VALUE_V2_RETURN,
            b"NLV2" + bytes(28),
        )
        self.assertFalse(bridge.receive_native(caller=pool, value=1))
        self.assertEqual(bridge.accept_liquidity_value_v2(
            "00" * 32, "11" * 32, 1, caller=pool, value=1,
        ), b"")
        cases = (
            ("bridge", "revert"),
            ("bridge", "oog"),
            ("bridge", "bad_magic"),
            ("bridge", "short_magic"),
            ("bridge", "long_magic"),
            ("pool", "callback_credit_substitution"),
            ("pool", "callback_ticket_substitution"),
            ("pool", "callback_amount_substitution"),
            ("pool", "callback_plain_receive"),
            ("pool", "callback_duplicate"),
        )
        for index, (target, fault) in enumerate(cases):
            with self.subTest(target=target, fault=fault):
                delivery = self.destination_delivery(
                    f"atomic-callback-{index}", value=3, fee=2,
                    fund_liquidity=False,
                )
                owner = addr(f"cb-lp-{index}")
                ticket = pool.deposit(
                    caller=owner, l1_recipient=addr(f"cb-l1-{index}"),
                    salt=f"callback-{index}", amount=5,
                )
                pool_before = pool._snapshot()
                bridge_before = bridge._transaction_snapshot()
                target_before = self.destination_receiver._transaction_snapshot()
                if target == "bridge":
                    bridge.liquidity_value_fault_point = fault
                else:
                    pool.fault_point = fault
                self.assertEqual(pool.process_with_liquidity(
                    ticket, bridge, *delivery, caller=owner,
                ), "UNFUNDED")
                self.assertEqual(pool._snapshot(), pool_before)
                self.assertEqual(bridge._transaction_snapshot(), bridge_before)
                self.assertEqual(
                    self.destination_receiver._transaction_snapshot(),
                    target_before,
                )
                self.assertIsNone(pool._active_liquidity_authorization)
                self.assertEqual(pool._liquidity_consumption_receipt, "")
                self.assertIsNone(bridge._liquidity_value_expectation)
                self.assertEqual(bridge._liquidity_value_receipt, "")
                bridge.liquidity_value_fault_point = None
                pool.fault_point = None

    def test_atomic_quote_and_bridge_state_decode_fail_closed(self):
        delivery = self.destination_delivery(
            "atomic-views", value=3, fee=2, fund_liquidity=False,
        )
        bridge = self.destination_bridge
        pool = bridge.liquidity_pool
        owner = addr("view-lp")
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("view-l1"),
            salt="views", amount=5,
        )
        credit_id = settlement.destination_credit_id_v2(*delivery)
        quote_method = bridge.inbox_store.liquidity_quote_v2
        state_method = bridge.liquidity_state_v2
        quote = quote_method(credit_id)
        state = state_method(credit_id)
        self.assertEqual(len(quote), 160)
        self.assertEqual(len(state), 160)

        def with_word(raw, index, word):
            return raw[:index * 32] + word + raw[(index + 1) * 32:]

        quote_cases = (
            quote[:-1], quote + b"\x00", bytes(32) + quote[32:],
            with_word(quote, 1, (delivery[0].value + 1).to_bytes(32, "big")),
            with_word(quote, 2, bytes((1,)) + bytes(31)),
            with_word(quote, 2, (delivery[0].fee + 1).to_bytes(32, "big")),
            with_word(quote, 3, bytes(32)),
            with_word(quote, 4, bytes((1,)) + bytes(31)),
        )
        for index, malformed in enumerate(quote_cases):
            with self.subTest(view="quote", index=index):
                before = pool._snapshot()
                bridge.inbox_store.liquidity_quote_v2 = lambda _credit: malformed
                self.assertEqual(pool.process_with_liquidity(
                    ticket, bridge, *delivery, caller=owner,
                ), "REJECTED")
                self.assertEqual(pool._snapshot(), before)
        bridge.inbox_store.liquidity_quote_v2 = quote_method

        state_cases = (
            state[:-1], state + b"\x00",
            with_word(state, 0, settlement._model_fixed_bytes32("wrong")),
            with_word(state, 1, b"\x01" + state[33:64]),
            with_word(state, 1, bytes(12) + addr("other").encode()[:20]),
            with_word(state, 2, b"\x01" + state[65:96]),
            with_word(state, 2, bytes(12) + settlement._model_address20("bad")),
            with_word(state, 3, (2).to_bytes(32, "big")),
            with_word(state, 4, (1).to_bytes(32, "big")),
        )
        for index, malformed in enumerate(state_cases):
            with self.subTest(view="bridge", index=index):
                before = pool._snapshot()
                bridge.liquidity_state_v2 = lambda _credit: malformed
                self.assertEqual(pool.process_with_liquidity(
                    ticket, bridge, *delivery, caller=owner,
                ), "REJECTED")
                self.assertEqual(pool._snapshot(), before)
        bridge.liquidity_state_v2 = state_method
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "DONE")

    def test_atomic_direct_consume_buggy_wrapper_and_target_reentry_fail_closed(self):
        delivery = self.destination_delivery(
            "atomic-authority", value=4, fee=2, fund_liquidity=False,
        )
        bridge = self.destination_bridge
        pool = bridge.liquidity_pool
        owner = addr("auth-lp")
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("auth-l1"),
            salt="authority", amount=12,
        )
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.assertIsNone(pool._consume_authorized(
            ticket, credit_id, 6, bridge=bridge, capability=object(),
        ))
        before = pool._snapshot()
        original = bridge._process_with_liquidity_from_pool
        bridge._process_with_liquidity_from_pool = lambda *args, **kwargs: "DONE"
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), before)
        bridge._process_with_liquidity_from_pool = original

        nested = []
        self.destination_receiver.callback = lambda _bridge: nested.extend((
            pool.withdraw_available(
                ticket, caller=owner, recipient=owner, amount=1
            ),
            pool.process_with_liquidity(
                ticket, bridge, *delivery, caller=owner
            ),
        ))
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "DONE")
        self.assertEqual(nested, [None, "REJECTED"])
        self.assertEqual(pool.tickets[ticket].available_amount, 6)
        self.destination_receiver.callback = None

    def test_atomic_authorization_binds_processor_store_result_and_frame(self):
        delivery = self.destination_delivery(
            "atomic-binding", value=3, fee=2, fund_liquidity=False,
        )
        bridge = self.destination_bridge
        pool = bridge.liquidity_pool
        owner = addr("binding-lp")
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("binding-l1"),
            salt="binding", amount=5,
        )
        before = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=addr("attacker"),
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), before)
        self.assertEqual(bridge.accept_liquidity_value_v2(
            "00" * 32, "11" * 32, 1,
            caller=addr("attacker"), value=1,
        ), b"")

        captured = []
        original = bridge._process_with_liquidity_from_pool

        def capture(*args, **kwargs):
            captured.append(pool._active_liquidity_authorization)
            return "UNFUNDED"

        bridge._process_with_liquidity_from_pool = capture
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "UNFUNDED")
        bridge._process_with_liquidity_from_pool = original
        authorization = captured[0]
        self.assertEqual(
            (
                authorization.depositor,
                authorization.processor,
                authorization.inbox_credit_store,
                authorization.result_hash,
                authorization.frame.caller,
                authorization.frame.operation,
            ),
            (
                owner,
                owner,
                bridge.inbox_store.address,
                bridge.inbox_store.pins[
                    authorization.credit_id
                ].result_hash,
                owner,
                "POOL_PROCESS",
            ),
        )
        exact = authorization.commitment

        def commitment(**changes):
            values = {
                "destination_chain_id": pool.destination_chain_id,
                "destination_domain_id": authorization.destination_domain_id,
                "destination_bridge": authorization.destination_bridge,
                "liquidity_pool": pool.address,
                "inbox_credit_store": authorization.inbox_credit_store,
                "result_hash": authorization.result_hash,
                "credit_id": authorization.credit_id,
                "ticket_id": authorization.ticket_id,
                "depositor": authorization.depositor,
                "processor": authorization.processor,
                "amount": authorization.amount,
                "message_hash": authorization.message_hash,
                "source_context_hash": authorization.source_context_hash,
                "destination_context_hash": (
                    authorization.destination_context_hash
                ),
                "frame_nonce": authorization.frame.nonce,
                "operation": authorization.operation,
                "is_last_attempt": authorization.is_last_attempt,
            }
            values.update(changes)
            return settlement.liquidity_acceptance_commitment_v2(**values)

        self.assertEqual(commitment(), exact)
        substitutions = (
            {"depositor": addr("other-dep")},
            {"processor": addr("other-proc")},
            {"inbox_credit_store": addr("other-store")},
            {"result_hash": "11" * 32},
            {"frame_nonce": authorization.frame.nonce + 1},
            {"operation": "POOL_RETRY"},
            {"is_last_attempt": True},
        )
        for change in substitutions:
            with self.subTest(change=change):
                self.assertNotEqual(commitment(**change), exact)

        def substitute_frame(*args, **kwargs):
            current = pool._active_liquidity_authorization
            pool._active_liquidity_authorization = replace(
                current, frame=object()
            )
            return original(*args, **kwargs)

        bridge._process_with_liquidity_from_pool = substitute_frame
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "REJECTED")
        bridge._process_with_liquidity_from_pool = original
        self.assertEqual(pool._snapshot(), before)
        self.assertIsNone(pool._active_liquidity_authorization)

    def test_atomic_withdraw_consume_ordering_and_terminal_faults(self):
        delivery = self.destination_delivery(
            "atomic-order", value=5, fee=2, fund_liquidity=False,
        )
        bridge = self.destination_bridge
        pool = bridge.liquidity_pool
        owner = addr("order-lp")
        ticket = pool.deposit(
            caller=owner, l1_recipient=addr("order-l1"),
            salt="ordering", amount=10,
        )
        self.assertEqual(pool.withdraw_available(
            ticket, caller=owner, recipient=owner, amount=4,
        ), 6)
        before = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), before)
        self.assertEqual(pool.deposit(
            caller=owner, l1_recipient=addr("order-l1"),
            salt="ordering", amount=1,
        ), ticket)

        bridge.terminal_accumulator.append_return_length = 31
        rollback = pool._snapshot()
        target_before = self.destination_receiver._transaction_snapshot()
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), rollback)
        self.assertEqual(
            self.destination_receiver._transaction_snapshot(), target_before
        )
        bridge.terminal_accumulator.append_return_length = 32
        settlement.set_bridge_eth_quota_available_for_test(bridge, 0)
        quota_rollback = pool._snapshot()
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "REJECTED")
        self.assertEqual(pool._snapshot(), quota_rollback)
        settlement.set_bridge_eth_quota_available_for_test(bridge, 7)
        self.assertEqual(pool.process_with_liquidity(
            ticket, bridge, *delivery, caller=owner,
        ), "DONE")
        self.assertNotIn(ticket, pool.tickets)

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

    def test_cross_chain_graphs_are_storage_and_balance_separate(self):
        self.assertNotEqual(
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
        fresh_successor = settlement.release_manifest_fixture(
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
        self.assertTrue(
            settlement.historical_v2_privileged_policy_compatible(
                self.destination_manifest, fresh_successor
            )
        )
        added_future_privilege = replace(
            fresh_successor,
            destination_bridge_descriptor=replace(
                fresh_successor.destination_bridge_descriptor,
                privileged_target_denyset=(
                    *fresh_successor.destination_bridge_descriptor
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
        self.assertEqual(self.process_destination(
            delivery, caller=owner
        ), "RETRIABLE")
        credit_id = settlement.destination_credit_id_v2(*delivery)
        self.assertEqual(self.retry_destination(
            delivery, caller=addr("observer"), is_last_attempt=False
        ), "RETRIABLE")
        self.assertEqual(self.destination_bridge.status[credit_id], "RETRIABLE")
        self.assertEqual(self.retry_destination(
            delivery, caller=owner, is_last_attempt=True
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
        ticket_id = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, message, depositor=addr("relayer"),
            salt="exact-message",
        )
        self.assertTrue(ticket_id)

        class IterationForbiddenLeafEvents(list):
            def __iter__(self):
                raise AssertionError("terminal hot path iterated leaf history")

        class IterationForbiddenTerminalCounters(dict):
            def items(self):
                raise AssertionError("terminal hot path iterated domain history")

            def values(self):
                raise AssertionError("terminal hot path iterated domain history")

            def __iter__(self):
                raise AssertionError("terminal hot path iterated domain history")

        self.destination_accumulator.leaf_events = (
            IterationForbiddenLeafEvents(
                self.destination_accumulator.leaf_events
            )
        )
        self.destination_accumulator.terminalized_pinned_count = (
            IterationForbiddenTerminalCounters(
                self.destination_accumulator.terminalized_pinned_count
            )
        )
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(
            self.destination_bridge.liquidity_pool.process_with_liquidity(
                ticket_id, self.destination_bridge, message, source, route,
                caller=addr("relayer"),
            ),
            "DONE",
        )
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
        dynamic_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, dynamic_message,
            depositor=addr("relayer"), salt="dynamic-message",
        )
        self.assertTrue(dynamic_ticket)
        self.assertEqual(
            self.destination_bridge.liquidity_pool.process_with_liquidity(
                dynamic_ticket, self.destination_bridge, dynamic_message,
                dynamic_source, dynamic_route, caller=addr("relayer"),
            ),
            "DONE",
        )
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

    def test_destination_bridge_uses_indexed_strict_store_verifier(self):
        delivery = self.destination_delivery(
            "strict-icv2", value=1, fee=1, fund_liquidity=False
        )
        credit_id = settlement.destination_credit_id_v2(*delivery)
        store = self.destination_bridge.inbox_store
        raw = store.staticcall_verify_inbox_credit_v2(
            settlement.VERIFY_INBOX_CREDIT_V2_SELECTOR
            + settlement._model_fixed_bytes32(credit_id),
            caller=self.destination_bridge.address,
            value=0,
            gas=settlement.VERIFY_INBOX_CREDIT_V2_GAS,
        )
        returned_pin = settlement.decode_verified_inbox_credit_v2(raw)
        stored_pin = store.pins[credit_id]
        self.assertEqual(returned_pin.credit_id, credit_id)
        self.assertEqual(
            (
                returned_pin.result_hash,
                returned_pin.process_by,
                returned_pin.value,
                returned_pin.execution_fee,
                returned_pin.liquidity_fee,
                returned_pin.source_context_hash,
            ),
            (
                stored_pin.result_hash,
                stored_pin.process_by,
                stored_pin.value,
                stored_pin.execution_fee,
                stored_pin.liquidity_fee,
                stored_pin.source_context_hash,
            ),
        )

        class IterationForbiddenPins(dict):
            def values(self):
                raise AssertionError("ICV2 lookup iterated pin history")

            def items(self):
                raise AssertionError("ICV2 lookup iterated pin history")

            def __iter__(self):
                raise AssertionError("ICV2 lookup iterated pin history")

        store.pins = IterationForbiddenPins(store.pins)
        self.assertEqual(
            self.destination_bridge._pin(
                credit_id, self.destination_bridge.local_domain_id
            ),
            returned_pin,
        )
        for malformed in (
            raw[:-1], raw + b"\x00", b"FAIL" + raw[4:],
            raw[:3 * 32] + (1 << 64).to_bytes(32, "big")
                + raw[4 * 32:],
        ):
            store.verify_return_override = malformed
            self.assertIsNone(self.destination_bridge._pin(
                credit_id, self.destination_bridge.local_domain_id
            ))
        store.verify_return_override = None
        store.verify_fault_point = "revert"
        self.assertIsNone(self.destination_bridge._pin(
            credit_id, self.destination_bridge.local_domain_id
        ))
        store.verify_fault_point = None
        with self.assertRaises(ValueError):
            store.staticcall_verify_inbox_credit_v2(
                settlement.VERIFY_INBOX_CREDIT_V2_SELECTOR
                + settlement._model_fixed_bytes32(credit_id),
                caller=self.destination_bridge.address,
                value=0,
                gas=settlement.VERIFY_INBOX_CREDIT_V2_GAS - 1,
            )

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
        observer = addr("observer")
        observer_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, message, depositor=observer,
            salt="manual-observer",
        )
        owner_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, message, depositor=owner,
            salt="manual-owner",
        )
        self.assertTrue(observer_ticket)
        self.assertTrue(owner_ticket)
        delivery = (message, source, route)
        self.destination_receiver.fault_point = "revert"
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(
            self.destination_bridge.liquidity_pool.process_with_liquidity(
                observer_ticket, self.destination_bridge, *delivery,
                caller=observer,
            ),
            "NEW",
        )
        self.assertNotIn(
            settlement.destination_credit_id_v2(*delivery),
            self.destination_bridge.status,
        )
        self.assertEqual(
            self.destination_bridge.liquidity_pool.process_with_liquidity(
                owner_ticket, self.destination_bridge, *delivery,
                caller=owner,
            ),
            "RETRIABLE",
        )
        self.assertFalse(self.destination_bridge.manual_fail(
            *delivery, caller=addr("observer")
        ))
        self.assertEqual(
            self.destination_bridge.liquidity_pool.retry_with_liquidity(
                observer_ticket, self.destination_bridge, *delivery,
                caller=observer, is_last_attempt=True,
            ),
            "REJECTED",
        )
        self.assertEqual(
            self.destination_bridge.liquidity_pool.retry_with_liquidity(
                observer_ticket, self.destination_bridge, *delivery,
                caller=observer, is_last_attempt=False,
            ),
            "RETRIABLE",
        )
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
        tickets = {}

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
                tickets[settlement.destination_credit_id_v2(
                    message, source, route
                )] = settlement.deposit_destination_liquidity_for_test(
                    bridge, message, depositor=addr("observer"),
                    salt=f"native-{label}",
                )
                self.assertTrue(tickets[
                    settlement.destination_credit_id_v2(
                        message, source, route
                    )
                ])
            return message, source, route

        def funded_process(exact_delivery):
            credit_id = settlement.destination_credit_id_v2(*exact_delivery)
            return bridge.liquidity_pool.process_with_liquidity(
                tickets[credit_id], bridge, *exact_delivery,
                caller=addr("observer"),
            )

        positive = delivery("positive", 7)
        positive_credit = settlement.destination_credit_id_v2(*positive)
        bridge.balance = 0
        settlement.set_bridge_eth_quota_available_for_test(bridge, 0)
        self.assertEqual(funded_process(positive), "REJECTED")
        self.assertNotIn(positive_credit, bridge.status)
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 0))
        self.assertEqual(receiver.native_balance, 0)

        settlement.set_bridge_eth_quota_available_for_test(bridge, 0)
        self.assertEqual(funded_process(positive), "REJECTED")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 0))

        settlement.set_bridge_eth_quota_available_for_test(bridge, 7)
        receiver.fault_point = "revert"
        self.assertEqual(funded_process(positive), "NEW")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 7))
        self.assertEqual(receiver.native_balance, 0)
        self.assertEqual(receiver.received, [])

        receiver.fault_point = None
        self.assertEqual(funded_process(positive), "DONE")
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
        accumulator_before = accumulator._transaction_snapshot()
        accumulator.append_return_length = 31
        self.assertEqual(funded_process(append_fault), "REJECTED")
        self.assertEqual((bridge.balance, bridge.ether_quota), (0, 8))
        self.assertEqual(receiver.native_balance, 7)
        self.assertNotIn(append_credit, bridge.status)
        self.assertNotIn(append_credit, bridge.terminal_index)
        self.assertEqual(
            accumulator.terminalized_pinned_count, terminalized_before
        )
        self.assertEqual(
            accumulator._transaction_snapshot(), accumulator_before
        )
        accumulator.append_return_length = 32
        self.assertEqual(funded_process(append_fault), "DONE")
        self.assertEqual(receiver.native_balance, 12)
        self.assertEqual(bridge.total_pull_liability, 3)
        self.assertEqual(sum(bridge.pull_credits.values()), 3)
        self.assertFalse(hasattr(accumulator, "_terminalized_credits"))
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
        direct_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, direct[0], depositor=addr("relayer"),
            salt="real-inbox-done",
        )
        self.assertTrue(direct_ticket)
        self.destination_environment.block_timestamp = self.clock.timestamp + 1
        self.assertEqual(self.destination_bridge.liquidity_pool.process_with_liquidity(
            direct_ticket, self.destination_bridge, *direct,
            caller=addr("relayer")
        ), "DONE")
        self.assertEqual(self.destination_bridge.status[direct_credit], "DONE")

        retriable = direct_delivery(1, "real-inbox-retry")
        retry_credit = apply_real_pin(retriable)
        owner_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, retriable[0], depositor=owner,
            salt="real-inbox-owner-retry",
        )
        observer_ticket = settlement.deposit_destination_liquidity_for_test(
            self.destination_bridge, retriable[0], depositor=addr("observer"),
            salt="real-inbox-observer-retry",
        )
        self.assertTrue(owner_ticket)
        self.assertTrue(observer_ticket)
        self.destination_receiver.fault_point = "revert"
        self.assertEqual(self.destination_bridge.liquidity_pool.process_with_liquidity(
            owner_ticket, self.destination_bridge, *retriable, caller=owner
        ), "RETRIABLE")
        self.assertEqual(
            self.destination_bridge.status[retry_credit], "RETRIABLE"
        )
        self.destination_receiver.fault_point = None
        self.assertEqual(self.destination_bridge.liquidity_pool.retry_with_liquidity(
            observer_ticket, self.destination_bridge, *retriable,
            caller=addr("observer"), is_last_attempt=False,
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
            b"r" * 32,
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
            b"r" * 32,
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
        self.protocol._install_data_session_for_test(
            settlement.DataSession(
                "cleanup", "alice", self.clock.timestamp - 1,
                refundable_bond=1,
            ),
            0,
        )
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
    def test_market_genesis_bootstraps_from_zero_key_router_receipt_atomically(self):
        rows = production_migration_fixture(evolve_after_genesis=False)
        old_protocol, _old_history, _new_history, live_market, manager = rows[:5]
        release_manager, old_id = rows[5], rows[6]
        router = manager.router

        def pending_market(*, forced_surplus: int = 0):
            result = market.SeatMarket(
                market_chain_id=live_market.market_chain_id,
                market_address=live_market.market_address,
                sla_bond=live_market.sla_bond,
                immutable_maximum_ask=live_market.immutable_maximum_ask,
                quote_maturity_seconds=live_market.quote_maturity_seconds,
                quote_maturity_blocks=live_market.quote_maturity_blocks,
                exit_delay_seconds=live_market.exit_delay_seconds,
                penalty_sink=addr("penalty"),
                authorization=None,
                insertion_enabled=False,
                cached_generation=None,
                release_manager=release_manager,
                target_runtime=None,
                genesis_pending=True,
                activation_router_address=router.address,
                activation_router_runtime_hash=market._model_component_hash(
                    router.runtime_hash, "Router runtime"
                ),
                activation_router_configuration_hash=(
                    market._model_component_hash(
                        router.configuration_hash, "Router configuration"
                    )
                ),
                seat_runway_seconds=old_protocol.seat_runway_seconds,
                handover_delay_seconds=settlement.HANDOVER_DELAY_SECONDS,
                stage_grace_seconds=settlement.STAGE_GRACE_SECONDS,
                maximum_inclusion_seconds=settlement.T_INCLUDE_MAX_SECONDS,
                maximum_standby_lease_seconds=(
                    settlement.MAX_STANDBY_LEASE_SECONDS
                ),
                minimum_standby_tenure_seconds=(
                    settlement.MIN_STANDBY_TENURE_SECONDS
                ),
                minimum_ask_improvement_wei_per_second=(
                    settlement.MIN_ASK_IMPROVEMENT_WEI_PER_SECOND
                ),
                minimum_ask_improvement_bps=(
                    settlement.MIN_ASK_IMPROVEMENT_BPS
                ),
            )
            # Model an involuntary SELFDESTRUCT transfer: no Market entrypoint
            # executes, so only the account balance changes.
            result.actual_balance += forced_surplus
            result.assert_valid()
            result._pvm_preinstall_authorization(release_manager, old_id)
            return result

        bootstrapped = pending_market(forced_surplus=777)
        receipt = market.decode_market_rotation_receipt_v1(
            bootstrapped.rotate_settlement_authorization_v1(
                market.Clock(2_000, settlement.GENESIS_TIMESTAMP + 2_000)
            )
        )
        self.assertIs(receipt.result, market.MarketRotationResult.BOOTSTRAPPED)
        self.assertEqual(receipt.old_authorization_id, market.ZERO_BYTES32)
        self.assertEqual(receipt.new_authorization_id, old_id)
        self.assertEqual(bootstrapped.current_authorization_id, old_id)
        self.assertTrue(bootstrapped.authorization_enabled[old_id])
        self.assertTrue(bootstrapped.bootstrap_complete)
        self.assertEqual(bootstrapped.actual_balance, 777)
        self.assertEqual(bootstrapped.accounting.accounted_balance, 0)
        bootstrapped.sync_seat_generation()
        with self.assertRaises(market.TransitionRejected):
            bootstrapped.rotate_settlement_authorization_v1(
                market.Clock(2_001, settlement.GENESIS_TIMESTAMP + 2_001)
            )

        for fault in (
            "after_new_target_enablement", "after_generation_cache_reset",
            "after_current_target_update", "after_activation_receipt_consumption",
        ):
            candidate = pending_market()
            before = copy.deepcopy(candidate)
            candidate.fault_point = fault
            with self.assertRaises(RuntimeError, msg=fault):
                candidate.rotate_settlement_authorization_v1(
                    market.Clock(2_000, settlement.GENESIS_TIMESTAMP + 2_000)
                )
            candidate.fault_point = None
            before.fault_point = None
            self.assertEqual(candidate, before)

    def test_genesis_nonzero_seat_namespace_reverts_the_complete_graph(self):
        protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="nonzero-seat-namespace"
        )
        proof = settlement.prepare_genesis_activation_for_test(
            router, history, landing
        )
        protocol.seat_generation = 7

        def projection():
            return (
                copy.deepcopy(protocol),
                copy.deepcopy({
                    key: value for key, value in history.__dict__.items()
                    if key not in {
                        "forced_queue", "inbox_apply_descriptor",
                        "migration_gate", "live_protocol", "_router_authority",
                    }
                }),
                router.forced_queue._transaction_snapshot(),
                copy.deepcopy(router.legacy_launch_hook.legacy_launch_state_v1()),
                router.active_version,
                tuple(router.registrations),
                router.activation_successor_index_v1,
                copy.deepcopy(router.activation_receipt_rows_v1),
                copy.deepcopy(router.seat_successor_rows_v1),
                router.genesis_activation_receipt,
                tuple(router.genesis_activation_trace),
                router.migration_lifecycle,
            )

        before = projection()
        self.assertFalse(router.bootstrap(
            history, sequence=0, clock=landing,
            caller=router.version_manager, proof=proof,
        ))
        self.assertEqual(projection(), before)
        self.assertNotIn(bytes(32), router.seat_successor_rows_v1)
        self.assertEqual(router.activation_receipt_rows_v1, {})

    def test_router_configuration_hash_binds_complete_acyclic_deployment_graph(self):
        rows = production_migration_fixture()
        router = rows[4].router
        descriptor = router.inbox_apply_descriptor
        legacy = router.legacy_launch_hook.resume_descriptor_fixture
        self.assertIsNotNone(legacy)
        inbox_hash = settlement.inbox_apply_deployment_descriptor_hash_v1(
            address=descriptor.address,
            registrar_address=descriptor.registrar_address,
            runtime_hash=descriptor.runtime_hash,
            configuration_hash=descriptor.configuration_hash,
        )
        legacy_hash = settlement.legacy_bootstrap_descriptor_hash_v1(
            proxy_address=legacy.inbox_proxy,
            proxy_runtime_hash=legacy.inbox_proxy_runtime_hash,
            implementation_address=legacy.inbox_implementation,
            implementation_runtime_hash=legacy.inbox_implementation_runtime_hash,
            inbox_configuration_hash=settlement.legacy_inbox_configuration_hash_v1(
                legacy.inbox_config
            ),
        )
        first_supported = router.header_oracle.first_supported_block
        arguments = dict(
            settlement_chain_context_id=router.settlement_chain_context_id,
            version_manager=router.version_manager,
            version_manager_runtime_hash=router.version_manager_runtime_hash,
            forced_queue_address=router.forced_queue.address,
            forced_queue_runtime_hash=router.forced_queue.runtime_hash,
            forced_queue_configuration_hash=router.forced_queue.config_hash,
            builder_registry_address=router.builder_registry_id,
            schedule_oracle_address=router.schedule_oracle_id,
            router_namespace=router.router_namespace,
            inbox_apply_descriptor_hash=inbox_hash,
            l1_history_first_supported_block=first_supported,
            l1_history_read_configuration_hash=(
                settlement.eip2935_read_configuration_hash_v1(first_supported)
            ),
            legacy_bootstrap_descriptor_hash=legacy_hash,
        )
        expected = settlement.active_settlement_router_configuration_hash_v2(
            **arguments
        )
        self.assertEqual(
            settlement._model_fixed_bytes32(router.configuration_hash), expected
        )
        active_registration = router.registrations[router.active_version]
        active_profile = active_registration.execution_profile
        profile_words = settlement._execution_profile_abi_words_v2(
            active_profile.canonical_profile_bytes
        )
        self.assertEqual(profile_words[20], settlement._abi_address_word(
            router.version_manager
        ))
        self.assertEqual(profile_words[23], settlement._abi_address_word(
            router.address
        ))
        self.assertEqual(profile_words[25], expected)
        self.assertEqual(profile_words[26], settlement._abi_address_word(
            router.forced_queue.address
        ))

        stale_profile = settlement.execution_profile_for_test(
            active_profile.protocol_version, "profile:stale-router-binding"
        )
        history = active_registration.settlement
        try:
            object.__setattr__(history, "execution_profile", stale_profile)
            object.__setattr__(
                history, "execution_profile_hash",
                stale_profile.execution_profile_hash,
            )
            with self.assertRaisesRegex(ValueError, "live Router graph"):
                settlement.settlement_registration(
                    router,
                    history,
                    activation_block=history.last_canonical_l1_block,
                    predecessor_version=0,
                    release_manifest_hash=active_registration.release_manifest_hash,
                )
        finally:
            object.__setattr__(history, "execution_profile", active_profile)
            object.__setattr__(
                history, "execution_profile_hash",
                active_profile.execution_profile_hash,
            )

        for field_name, value in arguments.items():
            mutated = dict(arguments)
            if type(value) is int:
                replacement = value + 1
            elif type(value) is bytes:
                replacement = bytes([value[0] ^ 1]) + value[1:]
            elif "address" in field_name or field_name == "version_manager":
                replacement = addr(f"mut-{len(field_name)}")
            else:
                replacement = value + ":mutated"
            mutated[field_name] = replacement
            with self.subTest(outer=field_name):
                self.assertNotEqual(
                    settlement.active_settlement_router_configuration_hash_v2(
                        **mutated
                    ),
                    expected,
                )

        inbox_leaves = dict(
            address=descriptor.address,
            registrar_address=descriptor.registrar_address,
            runtime_hash=descriptor.runtime_hash,
            configuration_hash=descriptor.configuration_hash,
        )
        for field_name, value in inbox_leaves.items():
            mutated = dict(inbox_leaves)
            mutated[field_name] = (
                addr(f"inbox-mut-{len(field_name)}")
                if "address" in field_name else value + ":mutated"
            )
            with self.subTest(inbox=field_name):
                self.assertNotEqual(
                    settlement.inbox_apply_deployment_descriptor_hash_v1(
                        **mutated
                    ),
                    inbox_hash,
                )

        legacy_leaves = dict(
            proxy_address=legacy.inbox_proxy,
            proxy_runtime_hash=legacy.inbox_proxy_runtime_hash,
            implementation_address=legacy.inbox_implementation,
            implementation_runtime_hash=legacy.inbox_implementation_runtime_hash,
            inbox_configuration_hash=settlement.legacy_inbox_configuration_hash_v1(
                legacy.inbox_config
            ),
        )
        for field_name, value in legacy_leaves.items():
            mutated = dict(legacy_leaves)
            mutated[field_name] = (
                addr(f"legacy-mut-{len(field_name)}")
                if "address" in field_name
                else (
                    bytes([value[0] ^ 1]) + value[1:]
                    if type(value) is bytes else value + ":mutated"
                )
            )
            with self.subTest(legacy=field_name):
                self.assertNotEqual(
                    settlement.legacy_bootstrap_descriptor_hash_v1(**mutated),
                    legacy_hash,
                )

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
            gate.target_registration_hash,
            cancel_manifest_active=True,
            caller=gate.coordinator,
        ))
        self.assertTrue(gate._publish_abort_active(
            generation, caller=gate.coordinator
        ))
        self.assertTrue(gate._arm_from_manager(
            generation + 1,
            router.active_version,
            target.protocol_version,
            manifest.target_manifest_hash,
            manifest.target_registration_hash,
            caller=gate.coordinator,
        ))
        self.assertEqual(gate.mode, "ARMED")
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
        replacement_router_address = addr("replacement-router")
        replacement_queue = replace(
            manager.router.forced_queue,
            router_address=replacement_router_address,
        )
        replacement_router = settlement.ActiveSettlementRouter(
            addr("replacement-manager"), replacement_queue,
            manager.router.inbox_apply_descriptor,
            manager.router.migration_gate,
            manager.router.header_oracle,
            settlement.LegacyLaunchHookV1(addr("replacement-manager")),
            address=replacement_router_address,
        )
        immutable_replacements = (
            (manager, "address", addr("replacement-manager")),
            (manager, "router", replacement_router),
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

    def test_genesis_campaign_public_gate_cutoffs_cancel_and_upgrade_freeze(self):
        _protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="campaign-gate"
        )
        hook = router.legacy_launch_hook
        self.assertTrue(hook.authorize_upgrade_v1(
            caller=hook.owner,
            clock=settlement.Clock(1, 1),
        ))
        campaign, clocks = publish_genesis_campaign_fixture(
            router, history, landing
        )
        state = settlement.decode_genesis_campaign_v1(
            router.genesis_campaign_state_return_v1()
        )
        self.assertEqual(len(router.genesis_campaign_state_return_v1()), 512)
        self.assertEqual((state.status, state.campaign_id), (1, campaign.campaign_id))
        public = settlement.decode_active_settlement_state_v1(
            router.active_settlement_state_v1()
        )
        self.assertEqual(len(router.active_settlement_state_v1()), 256)
        self.assertEqual(
            (public.phase, public.active_protocol_version,
             public.target_protocol_version, public.target_manifest_hash,
             public.target_registration_hash),
            (settlement.RouterPhase.ACTIVE, 0, 0, bytes(32), bytes(32)),
        )
        self.assertFalse(hook.authorize_upgrade_v1(
            caller=hook.owner, clock=clocks["publish"]
        ))
        self.assertFalse(hook.authorize_upgrade_v1(
            caller=hook.owner, clock=clocks["force"]
        ))
        getter = router.genesis_campaign_return_override
        router.genesis_campaign_return_override = b"bad"
        self.assertFalse(hook.authorize_upgrade_v1(
            caller=hook.owner, clock=clocks["publish"]
        ))
        forced_before = (hook.forced_tail, hook.retained_forced_value)
        self.assertFalse(hook.append_forced_ingress(
            amount=19, caller=addr("forcer"),
            block_number=clocks["force"].block_number,
            timestamp=clocks["force"].timestamp,
        ))
        self.assertEqual(
            (hook.forced_tail, hook.retained_forced_value), forced_before
        )
        router.genesis_campaign_return_override = getter
        self.assertTrue(hook.append_forced_ingress(
            amount=7, caller=addr("forcer"),
            block_number=clocks["force"].block_number - 1,
            timestamp=clocks["force"].timestamp - 1,
        ))
        proposal_before = (hook.next_proposal_id, hook.retained_proposal_value)
        self.assertFalse(hook.submit_proposal(
            caller=addr("proposer"),
            block_number=clocks["proposal"].block_number,
            timestamp=clocks["proposal"].timestamp,
            value=23,
        ))
        self.assertEqual(
            (hook.next_proposal_id, hook.retained_proposal_value),
            proposal_before,
        )
        self.assertTrue(hook.submit_proposal(
            caller=addr("proposer"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
            value=3,
        ))

        _p2, h2, r2, l2 = unactivated_genesis_fixture(
            suffix="campaign-cancel"
        )
        c2, k2 = publish_genesis_campaign_fixture(r2, h2, l2)
        cancel_clock = settlement.Clock(
            k2["publish"].block_number + 1,
            k2["publish"].timestamp + 1,
        )
        cancel_args = dict(
            campaign_id=c2.campaign_id,
            target_address=c2.target_address,
            target_registration_hash=c2.target_registration_hash,
            cancellation_commitment=settlement.keccak256(b"cancel-artifact"),
            cancellation_finalized_by_block=c2.review_finalized_by_block,
            caller=r2.version_manager,
            clock=cancel_clock,
        )
        self.assertFalse(r2.withdraw_genesis_campaign_v1(
            **{**cancel_args, "target_address": addr("substitute")}
        ))
        self.assertFalse(r2.withdraw_genesis_campaign_v1(**cancel_args))
        self.assertIs(r2.genesis_campaign, c2)
        self.assertIs(
            r2.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        # A published campaign is noncancelable; only its queued timelock
        # operation could have been canceled before publication.
        self.assertFalse(r2.withdraw_genesis_campaign_v1(**cancel_args))
        retained = settlement.decode_genesis_campaign_v1(
            r2.genesis_campaign_state_return_v1()
        )
        self.assertEqual((retained.status, retained.campaign_id),
                         (1, c2.campaign_id))
        self.assertFalse(r2.legacy_launch_hook.authorize_upgrade_v1(
            caller=r2.legacy_launch_hook.owner, clock=cancel_clock
        ))

    def test_genesis_bounded_scans_quiescence_and_atomic_dirty_activation(self):
        _protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="bounded-scan"
        )
        campaign, clocks = publish_genesis_campaign_fixture(
            router, history, landing
        )
        hook = router.legacy_launch_hook
        self.assertEqual(
            settlement.LEGACY_PROPOSAL_BATCH_RAW_BYTES_MAX, 60_928
        )
        self.assertEqual(
            settlement.LEGACY_PROPOSAL_BATCH_CALLDATA_BYTES_MAX, 62_084
        )
        self.assertEqual(
            settlement.LEGACY_SCAN_ROW_COUNT_MAX
                * (settlement.LEGACY_PROPOSAL_ROW_BYTES_MAX
                   + settlement.LEGACY_FORCED_ROW_BYTES_MAX),
            4_161_536,
        )
        self.assertFalse(hook.submit_proposal(
            caller=addr("oversized-proposal"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
            preimage=b"p" * (settlement.LEGACY_PROPOSAL_ROW_BYTES_MAX + 1),
        ))
        self.assertFalse(hook.append_forced_ingress(
            amount=1, caller=addr("oversized-forced"),
            block_number=clocks["force"].block_number - 1,
            timestamp=clocks["force"].timestamp - 1,
            preimage=b"f" * (settlement.LEGACY_FORCED_ROW_BYTES_MAX + 1),
        ))
        for index in range(17):
            self.assertTrue(hook.append_forced_ingress(
                amount=index + 1, caller=addr("forcer"),
                block_number=clocks["force"].block_number - 1,
                timestamp=clocks["force"].timestamp - 1,
                preimage=f"forced-{index}".encode(),
                blob_timestamp=landing.timestamp,
            ))
            self.assertTrue(hook.submit_proposal(
                caller=addr("proposer"),
                block_number=clocks["proposal"].block_number - 1,
                timestamp=clocks["proposal"].timestamp - 1,
                preimage=f"proposal-{index}".encode(),
                blob_timestamp=landing.timestamp,
            ))
        self.assertFalse(hook.submit_proposal(
            caller=addr("zero-blob"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
            blob_timestamp=0,
        ))
        begin = hook.begin_legacy_genesis_scan_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("scanner"), clock=clocks["proposal"],
        )
        self.assertEqual(len(begin), 160)
        proposal_rows = tuple(
            hook.proposal_records[index].preimage
            for index in range(hook.proposal_scan_start,
                               hook.frozen_next_proposal_id)
        )
        before_short = copy.deepcopy(hook.__dict__)
        self.assertEqual(hook.scan_legacy_genesis_proposals_v1(
            campaign.generation, campaign.campaign_id, proposal_rows[:15],
            caller=addr("front-runner"), clock=clocks["proposal"],
        ), b"")
        self.assertEqual(hook.__dict__, before_short)
        wrong = (b"substitute",) + proposal_rows[1:16]
        self.assertEqual(hook.scan_legacy_genesis_proposals_v1(
            campaign.generation, campaign.campaign_id, wrong,
            caller=addr("scanner"), clock=clocks["proposal"],
        ), b"")
        self.assertEqual(len(hook.scan_legacy_genesis_proposals_v1(
            campaign.generation, campaign.campaign_id, proposal_rows[:16],
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 160)
        self.assertEqual(len(hook.scan_legacy_genesis_proposals_v1(
            campaign.generation, campaign.campaign_id, proposal_rows[16:],
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 160)
        self.assertEqual(hook.scan_legacy_genesis_forced_v1(
            campaign.generation, campaign.campaign_id, 15,
            caller=addr("scanner"), clock=clocks["proposal"],
        ), b"")
        self.assertEqual(len(hook.scan_legacy_genesis_forced_v1(
            campaign.generation, campaign.campaign_id, 16,
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 192)
        self.assertEqual(len(hook.scan_legacy_genesis_forced_v1(
            campaign.generation, campaign.campaign_id, 1,
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 192)
        scan_state = hook.legacy_genesis_scan_state_v1()
        self.assertEqual((len(scan_state), int.from_bytes(scan_state[-32:], "big")),
                         (608, 2))
        self.assertEqual(hook.scan_call_count, 4)
        self.assertLessEqual(hook.scan_call_count,
                             settlement.LEGACY_SCAN_CALL_MAX)
        auxiliary_before_donation = hook.scan_commitment_v1()
        hook.raw_proxy_surplus += 32 * 10**18
        self.assertEqual(hook.scan_commitment_v1(), auxiliary_before_donation)
        self.assertTrue(hook.finalize_next_proposal(
            caller=addr("prover"),
            block_number=clocks["quiesce"].block_number - 1,
        ))
        exact_scan_state = hook.legacy_genesis_scan_state_v1()
        hook.scan_state_return_override = exact_scan_state[:-1] + b"\x01"
        self.assertEqual(hook.enter_legacy_genesis_quiescence_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("keeper"), clock=clocks["quiesce"],
        ), b"")
        hook.scan_state_return_override = None
        hook.prover_whitelist_member_count = 1
        self.assertEqual(hook.enter_legacy_genesis_quiescence_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("keeper"), clock=clocks["quiesce"],
        ), b"")
        hook.prover_whitelist_member_count = 0
        hook.fault_point = "after_quiescence"
        self.assertEqual(hook.enter_legacy_genesis_quiescence_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("keeper"), clock=clocks["quiesce"],
        ), b"")
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.ACTIVE)
        hook.fault_point = None
        self.assertEqual(len(hook.enter_legacy_genesis_quiescence_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("keeper"), clock=clocks["quiesce"],
        )), 96)
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.QUIESCENT)
        self.assertFalse(hook.submit_proposal(
            caller=addr("late"), block_number=clocks["quiesce"].block_number,
            timestamp=clocks["quiesce"].timestamp,
        ))
        proof = router.genesis_activation_proof_stub_v1(history)
        exact_lgs = hook.legacy_launch_state_return_v1()
        hook.state_return_override = exact_lgs[:-1] + b"\x01"
        self.assertFalse(router.bootstrap(
            history, sequence=0, clock=landing, caller=addr("lander"),
            proof=proof,
        ))
        hook.state_return_override = None
        exact_scan_state = hook.legacy_genesis_scan_state_v1()
        hook.scan_state_return_override = exact_scan_state[:-1] + b"\x01"
        self.assertFalse(router.bootstrap(
            history, sequence=0, clock=landing, caller=addr("lander"),
            proof=proof,
        ))
        hook.scan_state_return_override = None
        self.assertFalse(router.bootstrap(
            history, sequence=0, clock=landing, caller=addr("lander"),
            proof=replace(proof, campaign_id=bytes.fromhex("ff" * 32)),
        ))

        def projection():
            return (
                copy.deepcopy(history.core), history.mode,
                history.current_sequence, copy.deepcopy(history.history),
                copy.deepcopy(history.migration_gate.__dict__),
                router.forced_queue._transaction_snapshot(),
                router.active_version, tuple(router.registrations),
                copy.deepcopy(hook.legacy_launch_state_v1()),
                router.migration_lifecycle,
                router._migration_callback_frame,
                router.genesis_campaign,
                router.genesis_activation_receipt,
                tuple(router.genesis_activation_trace),
            )

        faults = (
            (hook, "fault_point", "after_arm"),
            (hook, "fault_point", "after_finalize"),
            (hook, "fault_point", "maps_bad_return"),
            (router, "migration_fault_point", "after_genesis_activating"),
            (router, "migration_fault_point", "after_genesis_proof"),
            (router, "migration_fault_point", "after_genesis_arm"),
            (router, "migration_fault_point", "after_genesis_ready"),
            (router, "migration_fault_point", "after_source_freeze"),
            (router, "migration_fault_point", "after_target_adopt"),
            (router, "migration_fault_point", "before_queue_migrate"),
            (router, "migration_fault_point", "after_registration"),
            (router, "migration_fault_point", "before_publication"),
            (history, "migration_callback_fault_point", "adopt_after_core"),
            (history, "migration_callback_fault_point", "adopt_bad_return"),
            (router.forced_queue, "migration_fault_point", "after_credit"),
            (router.forced_queue, "migration_fault_point", "after_swap"),
            (router.forced_queue, "migration_fault_point", "bad_return"),
        )
        for target, field_name, fault in faults:
            with self.subTest(fault=fault):
                setattr(target, field_name, fault)
                stable = projection()
                self.assertFalse(router.bootstrap(
                    history, sequence=0, clock=landing,
                    caller=addr("lander"), proof=proof,
                ))
                self.assertEqual(projection(), stable)
                self.assertIs(
                    hook.phase, settlement.LegacyLaunchPhase.QUIESCENT
                )
                setattr(target, field_name, None)
        self.assertTrue(router.bootstrap(
            history, sequence=0, clock=landing,
            caller=addr("lander"), proof=proof,
        ))
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.FROZEN)
        self.assertEqual(router.genesis_activation_trace, [
            "ACTIVATING", "LGS_QUIESCENT", "VERIFIED", "LGAR",
            "LGS_READY", "LGFN", "MCAN", "QMIG", "MAPS",
            "REGISTERED", "PUBLISHED", "IDLE",
        ])
        receipt = router.genesis_activation_receipt
        self.assertIsNotNone(receipt)
        self.assertEqual(
            receipt.transition_auxiliary_hash,
            settlement.legacy_genesis_abandonment_auxiliary_hash_v1(hook),
        )
        self.assertNotEqual(receipt.transition_auxiliary_hash, bytes(32))
        self.assertFalse(hook.authorize_upgrade_v1(
            caller=hook.owner, clock=landing
        ))

    def test_genesis_expiry_resume_commutes_and_old_scans_cannot_be_orphaned(self):
        def partial_fixture(suffix):
            _p, history, router, landing = unactivated_genesis_fixture(
                suffix=suffix
            )
            campaign, clocks = publish_genesis_campaign_fixture(
                router, history, landing
            )
            hook = router.legacy_launch_hook
            for index in range(17):
                self.assertTrue(hook.submit_proposal(
                    caller=addr("proposer"),
                    block_number=clocks["proposal"].block_number - 1,
                    timestamp=clocks["proposal"].timestamp - 1,
                    preimage=f"resume-{index}".encode(),
                ))
            self.assertEqual(len(hook.begin_legacy_genesis_scan_v1(
                campaign.generation, campaign.campaign_id,
                caller=addr("scanner"), clock=clocks["proposal"],
            )), 160)
            rows = tuple(
                hook.proposal_records[index].preimage
                for index in range(hook.proposal_scan_start,
                                   hook.frozen_next_proposal_id)
            )
            self.assertEqual(len(hook.scan_legacy_genesis_proposals_v1(
                campaign.generation, campaign.campaign_id, rows[:16],
                caller=addr("scanner"), clock=clocks["proposal"],
            )), 160)
            return history, router, hook, campaign, clocks, rows

        def replacement_args(history, router, hook, campaign, resume_clock):
            preview = settlement.settlement_registration(
                router, history, activation_block=0, predecessor_version=0,
                release_manifest_hash=router.bootstrap_release_manifest_hash,
            )
            review = settlement.legacy_genesis_review_commitment_v1(
                hook.deployment_hash, hook.legacy_resume_profile_hash,
                history.protocol_version,
                router.bootstrap_release_manifest_hash,
                settlement.target_registration_hash_v2(preview),
            )
            return dict(
                settlement=history, review_commitment=review,
                review_finalized_by_block=campaign.review_finalized_by_block,
                force_cutoff_block=campaign.force_cutoff_block + 1_000,
                proposal_cutoff_block=campaign.proposal_cutoff_block + 1_000,
                quiesce_block=campaign.quiesce_block + 1_000,
                resume_by_block=campaign.resume_by_block + 1_000,
                resume_by_timestamp=campaign.resume_by_timestamp + 7_000,
                executable_at=resume_clock.timestamp
                    + settlement.SEAT_MIGRATION_MANIFEST_DELAY,
                caller=router.version_manager, clock=resume_clock,
            )

        # Local resume then Router expiry is one valid commuting order.
        _h0, r0, hook0, c0, k0, _rows0 = partial_fixture(
            "resume-local-first"
        )
        self.assertEqual(len(hook0.resume_legacy_genesis_v1(
            c0.generation, c0.campaign_id,
            caller=addr("resumer"), clock=k0["resume"],
        )), 96)
        self.assertEqual(len(r0.expire_legacy_genesis_campaign_v1(
            c0.generation, c0.campaign_id,
            caller=addr("expirer"), clock=k0["resume"],
        )), 32)

        # A Router-expired campaign cannot be replaced while its partial
        # local scan remains; explicit resume clears it, then nonce advances.
        history, router, hook, campaign, clocks, _rows = partial_fixture(
            "resume-orphan-guard"
        )
        self.assertEqual(len(router.expire_legacy_genesis_campaign_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("expirer"), clock=clocks["resume"],
        )), 32)
        new_args = replacement_args(
            history, router, hook, campaign, clocks["resume"]
        )
        self.assertIsNone(
            router._schedule_genesis_campaign_for_fixture_v1(**new_args)
        )
        self.assertEqual(len(hook.resume_legacy_genesis_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("resumer"), clock=clocks["resume"],
        )), 96)
        self.assertTrue(hook.campaign_surfaces_clean_v1())
        self.assertTrue(hook.authorize_upgrade_v1(
            caller=hook.owner, clock=clocks["resume"]
        ))
        replacement_id = router._schedule_genesis_campaign_for_fixture_v1(
            **new_args
        )
        self.assertIsNotNone(replacement_id)
        self.assertEqual(router.genesis_campaign_nonce, campaign.nonce + 1)

        _h2, r2, hook2, c2, k2, rows2 = partial_fixture(
            "resume-router-first"
        )
        r2.migration_fault_point = "after_genesis_campaign_expiry"
        self.assertEqual(r2.expire_legacy_genesis_campaign_v1(
            c2.generation, c2.campaign_id, caller=addr("expirer"),
            clock=k2["resume"],
        ), b"")
        self.assertIs(r2.genesis_campaign, c2)
        self.assertIs(
            r2.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        r2.migration_fault_point = None
        self.assertEqual(len(r2.expire_legacy_genesis_campaign_v1(
            c2.generation, c2.campaign_id, caller=addr("expirer"),
            clock=k2["resume"],
        )), 32)
        self.assertFalse(hook2.campaign_surfaces_clean_v1())
        self.assertEqual(len(hook2.resume_legacy_genesis_v1(
            c2.generation, c2.campaign_id, caller=addr("resumer"),
            clock=k2["resume"],
        )), 96)
        self.assertTrue(hook2.campaign_surfaces_clean_v1())

        _h3, r3, hook3, c3, k3, rows3 = partial_fixture("resume-complete")
        self.assertEqual(len(hook3.scan_legacy_genesis_proposals_v1(
            c3.generation, c3.campaign_id, rows3[16:],
            caller=addr("scanner"), clock=k3["proposal"],
        )), 160)
        self.assertEqual(len(r3.expire_legacy_genesis_campaign_v1(
            c3.generation, c3.campaign_id, caller=addr("expirer"),
            clock=k3["resume"],
        )), 32)
        complete_args = replacement_args(_h3, r3, hook3, c3, k3["resume"])
        self.assertIsNone(
            r3._schedule_genesis_campaign_for_fixture_v1(**complete_args)
        )
        self.assertEqual(len(hook3.resume_legacy_genesis_v1(
            c3.generation, c3.campaign_id, caller=addr("resumer"),
            clock=k3["resume"],
        )), 96)
        self.assertTrue(hook3.campaign_surfaces_clean_v1())
        self.assertIsNotNone(
            r3._schedule_genesis_campaign_for_fixture_v1(**complete_args)
        )

        # QUIESCENT uses the same local-only escape and cannot authorize an
        # implementation change before the clear.
        _p4, h4, r4, l4 = unactivated_genesis_fixture(suffix="resume-quiescent")
        settlement.prepare_genesis_activation_for_test(r4, h4, l4)
        c4 = r4.genesis_campaign
        hook4 = r4.legacy_launch_hook
        resume4 = settlement.Clock(c4.resume_by_block, c4.resume_by_timestamp)
        self.assertIs(hook4.phase, settlement.LegacyLaunchPhase.QUIESCENT)
        self.assertFalse(hook4.authorize_upgrade_v1(
            caller=hook4.owner, clock=settlement.Clock(
                resume4.block_number - 1, resume4.timestamp - 1
            )
        ))
        self.assertEqual(len(r4.expire_legacy_genesis_campaign_v1(
            c4.generation, c4.campaign_id, caller=addr("expirer"),
            clock=resume4,
        )), 32)
        quiescent_args = replacement_args(h4, r4, hook4, c4, resume4)
        self.assertIsNone(
            r4._schedule_genesis_campaign_for_fixture_v1(**quiescent_args)
        )
        hook4.prover_whitelist_member_count = 1
        self.assertEqual(hook4.resume_legacy_genesis_v1(
            c4.generation, c4.campaign_id,
            caller=addr("resumer"), clock=resume4,
        ), b"")
        hook4.prover_whitelist_member_count = 0
        self.assertEqual(len(hook4.resume_legacy_genesis_v1(
            c4.generation, c4.campaign_id,
            caller=addr("resumer"), clock=resume4,
        )), 96)
        self.assertTrue(hook4.authorize_upgrade_v1(
            caller=hook4.owner, clock=resume4
        ))

    def test_genesis_expiry_horizon_profile_codec_and_stale_rows(self):
        _protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="expiry-profile"
        )
        landing = replace(landing, timestamp=2_000_000)
        campaign, clocks = publish_genesis_campaign_fixture(
            router, history, landing
        )
        hook = router.legacy_launch_hook
        self.assertEqual(
            settlement.LEGACY_RESUME_PROFILE_DOMAIN,
            b"slot-chain-legacy-genesis-resume-profile-v2",
        )
        self.assertEqual(
            settlement.LEGACY_REVIEW_COMMITMENT_DOMAIN,
            b"slot-chain-legacy-genesis-review-v1",
        )
        self.assertEqual(
            settlement.GENESIS_RESUME_INCLUSION_MARGIN_SECONDS,
            settlement.LEGACY_RESUME_PROOF_GENERATION_MAX_SECONDS
                + settlement.REORG_MARGIN_SECONDS
                + settlement.T_INCLUDE_MAX_SECONDS,
        )
        self.assertEqual(
            settlement.legacy_resume_profile_hash_v1(
                bytes.fromhex("11" * 32)
            ).hex(),
            "881fc1d602765b557645b7ca9ea0c66fd0e3e6925a7352cb7a43171c3965ab39",
        )
        self.assertEqual(
            settlement.legacy_resume_verifier_route_hash_v1(
                bytes.fromhex("11" * 32)
            ).hex(),
            "d401fa7d8531d19575ed6c00a1220f10f69915dc245e40ae1400163d1439220b",
        )
        self.assertEqual(
            settlement.signal_service_checkpoint_descriptor_hash_v1(
                bytes.fromhex("11" * 32)
            ).hex(),
            "1abbb6adee547ad039bcb3b89515a2fe4e332706c0584764ccd99493be389fa9",
        )
        self.assertEqual(
            (settlement.LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL,
             settlement.LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL),
            (10, 21),
        )
        self.assertEqual(
            settlement.legacy_resume_profile_hash_v1(
                bytes.fromhex("11" * 32),
                prover_whitelist_address_zero=False,
                prover_whitelist_member_count=0,
                prover_whitelist_mutation_fenced=True,
            ),
            bytes(32),
        )
        self.assertEqual(
            settlement.legacy_resume_profile_hash_v1(
                bytes.fromhex("11" * 32),
                prover_whitelist_address_zero=False,
                prover_whitelist_member_count=0,
                prover_whitelist_mutation_fenced=False,
            ),
            bytes(32),
        )
        self.assertFalse(hook.submit_proposal(
            caller=addr("zero-blob"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
            blob_timestamp=0,
        ))
        stale_timestamp = (
            campaign.resume_by_timestamp
            + settlement.GENESIS_RESUME_INCLUSION_MARGIN_SECONDS
            - settlement.LEGACY_BLOB_RETENTION_SECONDS - 1
        )
        self.assertTrue(hook.submit_proposal(
            caller=addr("stale"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
            preimage=b"stale-row", blob_timestamp=stale_timestamp,
        ))
        self.assertEqual(len(hook.begin_legacy_genesis_scan_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 160)
        self.assertEqual(len(hook.scan_legacy_genesis_proposals_v1(
            campaign.generation, campaign.campaign_id, (b"stale-row",),
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 160)
        self.assertEqual(hook.enter_legacy_genesis_quiescence_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("keeper"), clock=clocks["quiesce"],
        ), b"")

        _p2, h2, r2, l2 = unactivated_genesis_fixture(
            suffix="expiry-boundary"
        )
        l2 = replace(l2, timestamp=2_000_000)
        c2, k2 = publish_genesis_campaign_fixture(r2, h2, l2)
        hook2 = r2.legacy_launch_hook
        exact_timestamp = (
            c2.resume_by_timestamp
            + settlement.GENESIS_RESUME_INCLUSION_MARGIN_SECONDS
            - settlement.LEGACY_BLOB_RETENTION_SECONDS
        )
        self.assertTrue(hook2.submit_proposal(
            caller=addr("boundary"),
            block_number=k2["proposal"].block_number - 1,
            timestamp=k2["proposal"].timestamp - 1,
            preimage=b"boundary-row", blob_timestamp=exact_timestamp,
        ))
        self.assertEqual(len(hook2.begin_legacy_genesis_scan_v1(
            c2.generation, c2.campaign_id,
            caller=addr("scanner"), clock=k2["proposal"],
        )), 160)
        self.assertEqual(len(hook2.scan_legacy_genesis_proposals_v1(
            c2.generation, c2.campaign_id, (b"boundary-row",),
            caller=addr("scanner"), clock=k2["proposal"],
        )), 160)
        self.assertEqual(len(hook2.enter_legacy_genesis_quiescence_v1(
            c2.generation, c2.campaign_id,
            caller=addr("keeper"), clock=k2["quiesce"],
        )), 96)
        hook2.prover_whitelist_member_count = 1
        proof = r2.genesis_activation_proof_stub_v1(h2)
        self.assertFalse(r2.bootstrap(
            h2, sequence=0, clock=l2, caller=addr("lander"), proof=proof,
        ))
        self.assertFalse(hook2.authorize_upgrade_v1(
            caller=hook2.owner, clock=l2
        ))

    def test_genesis_resume_route_and_signal_graph_fail_closed_at_publication(self):
        invalid_mutations = (
            ("resume_route_members", (1,)),
            ("resume_route_sgx_required", True),
            ("resume_route_members", (6, 5)),
            ("resume_route_members", (5, 7)),
            ("resume_route_age_independent", False),
            ("resume_route_descriptor_hashes",
             (bytes.fromhex("ab" * 32), bytes.fromhex("cd" * 32))),
            ("resume_route_key_policy_hashes",
             (bytes.fromhex("12" * 32), bytes.fromhex("34" * 32))),
            ("resume_route_fixed_key_adapters", False),
            ("resume_route_mutable_trust_map", True),
            ("signal_service_upgrade_fenced", False),
            ("signal_service_fence_descriptor_hash", bytes.fromhex("ee" * 32)),
            ("signal_service_direct_final_implementation", False),
            ("signal_service_fork_router", True),
            ("signal_service_delegate_target_reachable", True),
            ("prover_whitelist_member_count", 1),
            ("state_return_override", b"malformed-LGS1"),
            ("scan_state_return_override", b"malformed-LGSS"),
        )
        for index, (field_name, bad_value) in enumerate(invalid_mutations):
            with self.subTest(field=field_name, case=index):
                _protocol, history, router, landing = \
                    unactivated_genesis_fixture(suffix=f"bad-route-{index}")
                hook = router.legacy_launch_hook
                setattr(hook, field_name, bad_value)
                with self.assertRaises(AssertionError):
                    publish_genesis_campaign_fixture(router, history, landing)
                self.assertIsNone(router.genesis_campaign)
                self.assertEqual(router.active_version, 0)
                self.assertIs(
                    router.migration_lifecycle,
                    settlement.RouterMigrationLifecycle.IDLE,
                )

        _p0, h0, r0, l0 = unactivated_genesis_fixture(
            suffix="unfenced-nonzero-whitelist"
        )
        r0.legacy_launch_hook.prover_whitelist_address_zero = False
        r0.legacy_launch_hook.prover_whitelist_mutation_fenced = False
        with self.assertRaises(AssertionError):
            publish_genesis_campaign_fixture(r0, h0, l0)

        _p1, h1, r1, l1 = unactivated_genesis_fixture(
            suffix="profile-changes-after-schedule"
        )
        scheduled, scheduled_clocks = publish_genesis_campaign_fixture(
            r1, h1, l1, publish=False
        )
        r1.migration_fault_point = "after_genesis_campaign_publish"
        self.assertIsNone(r1._publish_genesis_campaign_for_fixture_v1(
            scheduled.campaign_id, caller=addr("publisher"),
            clock=scheduled_clocks["publish"],
        ))
        self.assertIsNotNone(r1.scheduled_genesis_campaign)
        self.assertIsNone(r1.genesis_campaign)
        self.assertIs(
            r1.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        r1.migration_fault_point = None
        r1.legacy_launch_hook.prover_whitelist_member_count = 1
        self.assertIsNone(r1._publish_genesis_campaign_for_fixture_v1(
            scheduled.campaign_id, caller=addr("publisher"),
            clock=scheduled_clocks["publish"],
        ))
        self.assertIsNotNone(r1.scheduled_genesis_campaign)
        self.assertIsNone(r1.genesis_campaign)
        r1.legacy_launch_hook.prover_whitelist_member_count = 0
        self.assertIsNotNone(r1._publish_genesis_campaign_for_fixture_v1(
            scheduled.campaign_id, caller=addr("publisher"),
            clock=scheduled_clocks["publish"],
        ))

        _protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="good-risc0-sp1-route"
        )
        hook = router.legacy_launch_hook
        self.assertEqual(hook.resume_route_members, (5, 6))
        self.assertTrue(hook.resume_route_age_independent)
        self.assertFalse(hook.resume_route_sgx_required)
        self.assertTrue(hook.signal_service_upgrade_fenced)
        campaign, _clocks = publish_genesis_campaign_fixture(
            router, history, landing
        )
        self.assertIs(router.genesis_campaign, campaign)

    def test_genesis_full_caps_complete_in_exactly_128_maximal_batches(self):
        _protocol, history, router, landing = unactivated_genesis_fixture(
            suffix="full-scan-caps"
        )
        campaign, clocks = publish_genesis_campaign_fixture(
            router, history, landing
        )
        hook = router.legacy_launch_hook
        for index in range(settlement.LEGACY_SCAN_ROW_COUNT_MAX):
            self.assertTrue(hook.submit_proposal(
                caller=addr("proposer"),
                block_number=clocks["proposal"].block_number - 1,
                timestamp=clocks["proposal"].timestamp - 1,
                preimage=b"p" + index.to_bytes(2, "big"),
            ))
            self.assertTrue(hook.append_forced_ingress(
                amount=1, caller=addr("forcer"),
                block_number=clocks["force"].block_number - 1,
                timestamp=clocks["force"].timestamp - 1,
                preimage=b"f" + index.to_bytes(2, "big"),
            ))
        self.assertFalse(hook.submit_proposal(
            caller=addr("overflow"),
            block_number=clocks["proposal"].block_number - 1,
            timestamp=clocks["proposal"].timestamp - 1,
        ))
        self.assertFalse(hook.append_forced_ingress(
            amount=1, caller=addr("overflow"),
            block_number=clocks["force"].block_number - 1,
            timestamp=clocks["force"].timestamp - 1,
        ))
        prep = hook.legacy_genesis_preparation_v1()
        self.assertEqual(len(prep), 288)
        self.assertEqual(
            int.from_bytes(prep[7 * 32:8 * 32], "big"),
            4_161_536,
        )
        self.assertEqual(len(hook.begin_legacy_genesis_scan_v1(
            campaign.generation, campaign.campaign_id,
            caller=addr("scanner"), clock=clocks["proposal"],
        )), 160)
        while hook.proposal_scan_cursor != hook.frozen_next_proposal_id:
            cursor = hook.proposal_scan_cursor
            rows = tuple(
                hook.proposal_records[index].preimage
                for index in range(cursor, cursor + 16)
            )
            self.assertEqual(len(hook.scan_legacy_genesis_proposals_v1(
                campaign.generation, campaign.campaign_id, rows,
                caller=addr("scanner"), clock=clocks["proposal"],
            )), 160)
        while hook.forced_scan_cursor != hook.frozen_forced_tail:
            self.assertEqual(len(hook.scan_legacy_genesis_forced_v1(
                campaign.generation, campaign.campaign_id, 16,
                caller=addr("scanner"), clock=clocks["proposal"],
            )), 192)
        self.assertEqual(hook.scan_call_count, 128)
        self.assertEqual(
            (hook.proposal_scan_count, hook.forced_scan_count),
            (1_024, 1_024),
        )
        self.assertEqual(
            int.from_bytes(hook.legacy_genesis_scan_state_v1()[-32:], "big"),
            2,
        )

    def _obsolete_irreversible_genesis_checkpoint_is_delayed_and_target_independent(self):
        _protocol, history, router, landing_clock = \
            unactivated_genesis_fixture(suffix="checkpoint")
        hook = router.legacy_launch_hook
        delay = settlement.SEAT_MIGRATION_MANIFEST_DELAY
        checkpoint_at = landing_clock.timestamp - delay
        authorization_clock = settlement.Clock(
            landing_clock.block_number - 2, checkpoint_at - delay
        )
        checkpoint_clock = settlement.Clock(
            landing_clock.block_number - 1, checkpoint_at
        )
        self.assertFalse(router.authorize_legacy_genesis_checkpoint_v1(
            executable_at=checkpoint_at,
            caller=addr("not-governance"),
            clock=authorization_clock,
        ))
        self.assertFalse(router.authorize_legacy_genesis_checkpoint_v1(
            executable_at=True,
            caller=router.version_manager,
            clock=authorization_clock,
        ))
        self.assertFalse(router.authorize_legacy_genesis_checkpoint_v1(
            executable_at=checkpoint_at - 1,
            caller=router.version_manager,
            clock=authorization_clock,
        ))
        self.assertTrue(router.authorize_legacy_genesis_checkpoint_v1(
            executable_at=checkpoint_at,
            caller=router.version_manager,
            clock=authorization_clock,
        ))
        self.assertFalse(router.schedule_genesis_target_v1(
            history,
            executable_at=landing_clock.timestamp,
            caller=router.version_manager,
            clock=checkpoint_clock,
        ))
        # Authorization never fixes a boundary, so ordinary legacy mutations
        # before the landing instant cannot invalidate or starve checkpointing.
        self.assertTrue(hook.submit_proposal(caller=addr("legacy-proposer")))
        self.assertTrue(hook.append_forced_ingress(
            amount=7, caller=addr("legacy-forcer")
        ))
        self.assertIsNone(router.checkpoint_legacy_genesis_v1(
            caller=addr("early-keeper"),
            clock=replace(checkpoint_clock, timestamp=checkpoint_at - 1),
        ))
        hook.fault_point = "after_checkpoint"
        self.assertIsNone(router.checkpoint_legacy_genesis_v1(
            caller=addr("keeper"), clock=checkpoint_clock
        ))
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.ACTIVE)
        self.assertEqual(hook.generation, 0)
        self.assertEqual(hook.checkpoint_id, b"")
        hook.fault_point = None
        router.migration_fault_point = \
            "after_genesis_checkpoint_publication"
        self.assertIsNone(router.checkpoint_legacy_genesis_v1(
            caller=addr("keeper"), clock=checkpoint_clock
        ))
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.ACTIVE)
        self.assertEqual(hook.generation, 0)
        self.assertEqual(hook.checkpoint_id, b"")
        self.assertEqual(router.retired_target_checkpoint_state, "LEGACY_ACTIVE")
        self.assertIs(
            router.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        router.migration_fault_point = None
        checkpoint = router.checkpoint_legacy_genesis_v1(
            caller=addr("keeper"), clock=checkpoint_clock
        )
        self.assertIsNotNone(checkpoint)
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.READY)
        self.assertEqual(checkpoint.generation, 1)
        self.assertEqual(
            (checkpoint.live_proposals, checkpoint.native_live_queue,
             checkpoint.native_escrow),
            (1, 1, 7),
        )
        self.assertEqual(checkpoint.checkpoint_id, hook.checkpoint_id)
        self.assertEqual(checkpoint.boundary_hash, hook.boundary_hash)
        self.assertNotEqual(checkpoint.checkpoint_id, bytes(32))
        self.assertEqual(hook.target_protocol_version, 0)
        self.assertEqual(hook.target_registration_hash, b"")
        self.assertFalse(hook.submit_proposal(caller=addr("late-proposer")))
        self.assertFalse(hook.append_forced_ingress(
            amount=9, caller=addr("late-forcer")
        ))
        self.assertIsNone(router.checkpoint_legacy_genesis_v1(
            caller=addr("duplicate"), clock=landing_clock
        ))
        for forbidden in (
            "abort_legacy_launch_v1", "resume_legacy_launch_v1",
            "arm_legacy_genesis_v1",
        ):
            self.assertFalse(hasattr(router, forbidden))
            self.assertFalse(hasattr(hook, forbidden))
        self.assertFalse(hook.quiesce(caller=hook.owner))

    def _obsolete_genesis_proof_is_verified_before_activation_and_faults_restore_ready(self):
        _protocol, history, router, landing_clock = \
            unactivated_genesis_fixture(suffix="activation")
        proof = settlement.prepare_genesis_activation_for_test(
            router, history, landing_clock
        )
        hook = router.legacy_launch_hook
        queue = router.forced_queue

        def projection():
            return (
                copy.deepcopy(history.core), history.mode,
                history.current_sequence, copy.deepcopy(history.history),
                copy.deepcopy(history.migration_gate.__dict__),
                queue._transaction_snapshot(), router.active_version,
                tuple(router.registrations),
                copy.deepcopy(hook.legacy_launch_state_v1()),
                router.migration_lifecycle,
                router._migration_callback_frame,
                router.armed_genesis_target,
                router.scheduled_genesis_target_cancel,
                frozenset(router.canceled_genesis_target_tuples),
                router.retired_target_checkpoint_state,
                router.genesis_activation_receipt,
                tuple(router.genesis_activation_trace),
            )

        stable_ready = projection()
        invalid_proofs = (
            None,
            replace(proof, valid=False),
            replace(proof, valid=1),
            replace(proof, checkpoint_id=b"x" * 32),
            replace(proof, boundary_hash=b"x" * 32),
            replace(proof, target_registration_hash=b"x" * 32),
            replace(proof, output_core_hash=b"x" * 32),
            replace(proof, statement_digest=b"x" * 32),
        )
        for invalid in invalid_proofs:
            self.assertFalse(router.bootstrap(
                history, sequence=0, clock=landing_clock,
                caller=addr("lander"), proof=invalid,
            ))
            self.assertEqual(projection(), stable_ready)
            self.assertIs(hook.phase, settlement.LegacyLaunchPhase.READY)
            self.assertEqual(queue.active_settlement_address, hook.proxy_address)
        self.assertFalse(router.bootstrap(
            history, sequence=-1, clock=landing_clock,
            caller=addr("lander"), proof=proof,
        ))
        self.assertFalse(router.bootstrap(
            history, sequence=0, clock=landing_clock,
            caller="", proof=proof,
        ))
        self.assertEqual(projection(), stable_ready)

        faults = (
            (hook, "fault_point", "after_finalize"),
            (hook, "fault_point", "maps_bad_return"),
            (router, "migration_fault_point", "after_source_freeze"),
            (router, "migration_fault_point", "after_target_adopt"),
            (router, "migration_fault_point", "before_queue_migrate"),
            (router, "migration_fault_point", "after_registration"),
            (router, "migration_fault_point", "before_publication"),
            (history, "migration_callback_fault_point", "adopt_after_core"),
            (history, "migration_callback_fault_point", "adopt_after_history"),
            (history, "migration_callback_fault_point", "adopt_bad_return"),
            (history, "migration_callback_fault_point", "target_maps_bad_return"),
            (queue, "migration_fault_point", "after_credit"),
            (queue, "migration_fault_point", "after_swap"),
            (queue, "migration_fault_point", "bad_return"),
            (queue, "migration_fault_point", "maps_bad_return"),
        )
        for target, field_name, fault in faults:
            setattr(target, field_name, fault)
            before_fault = projection()
            self.assertFalse(router.bootstrap(
                history, sequence=0, clock=landing_clock,
                caller=addr("lander"), proof=proof,
            ), fault)
            self.assertEqual(projection(), before_fault, fault)
            self.assertIs(hook.phase, settlement.LegacyLaunchPhase.READY)
            self.assertEqual(queue.active_settlement_address, hook.proxy_address)
            setattr(target, field_name, None)

        self.assertTrue(router.bootstrap(
            history, sequence=0, clock=landing_clock,
            caller=addr("lander"), proof=proof,
        ))
        self.assertIs(hook.phase, settlement.LegacyLaunchPhase.FROZEN)
        self.assertEqual(queue.active_settlement_address, history.address)
        self.assertEqual(history.current_sequence, 0)
        self.assertEqual(router.active_version, history.protocol_version)
        self.assertIsNotNone(router.genesis_activation_receipt)
        self.assertEqual(
            router.genesis_activation_receipt.target_registration_hash,
            proof.target_registration_hash,
        )
        self.assertEqual(router.genesis_activation_trace, [
            "VERIFIED", "ACTIVATING", "LGFN", "MCAN", "QMIG",
            "MAPS", "REGISTERED", "PUBLISHED", "IDLE",
        ])
        self.assertIs(
            router.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        self.assertFalse(hook.submit_proposal(caller=addr("late-proposer")))
        self.assertFalse(hook.append_forced_ingress(
            amount=1, caller=addr("late-forcer")
        ))

    def _obsolete_checkpoint_survives_target_cancel_and_delayed_replacement(self):
        protocol, original, router, landing_clock = \
            unactivated_genesis_fixture(suffix="replace-original")
        delay = settlement.SEAT_MIGRATION_MANIFEST_DELAY
        checkpoint_at = landing_clock.timestamp - 2 * delay
        authorization_clock = replace(
            landing_clock, timestamp=checkpoint_at - delay
        )
        checkpoint_clock = replace(landing_clock, timestamp=checkpoint_at)
        self.assertTrue(router.authorize_legacy_genesis_checkpoint_v1(
            executable_at=checkpoint_at,
            caller=router.version_manager,
            clock=authorization_clock,
        ))
        checkpoint = router.checkpoint_legacy_genesis_v1(
            caller=addr("checkpoint-keeper"), clock=checkpoint_clock
        )
        self.assertIsNotNone(checkpoint)
        first_ready_at = checkpoint_at + delay
        first_ready_clock = replace(landing_clock, timestamp=first_ready_at)
        self.assertFalse(router.schedule_genesis_target_v1(
            original,
            executable_at=True,
            caller=router.version_manager,
            clock=checkpoint_clock,
        ))
        self.assertTrue(router.schedule_genesis_target_v1(
            original,
            executable_at=first_ready_at,
            caller=router.version_manager,
            clock=checkpoint_clock,
        ))
        self.assertEqual(
            router.retired_target_checkpoint_state, "RETIRED_TARGET_CLEARED"
        )
        scheduled_tuple = router._genesis_target_tuple_v1(
            router.scheduled_genesis_target
        )
        self.assertIsNotNone(scheduled_tuple)
        self.assertFalse(router.schedule_genesis_target_cancel_v1(
            checkpoint_id=scheduled_tuple[0],
            target_address=scheduled_tuple[1],
            target_protocol_version=scheduled_tuple[2],
            target_manifest_hash=scheduled_tuple[3],
            target_registration_hash=scheduled_tuple[4],
            executable_at=first_ready_at + delay,
            caller=router.version_manager,
            clock=checkpoint_clock,
        ))
        self.assertIsNone(router.arm_genesis_target_v1(
            caller=addr("early-armer"),
            clock=replace(first_ready_clock, timestamp=first_ready_at - 1),
        ))
        scheduled_before_fault = router.scheduled_genesis_target
        router.migration_fault_point = "after_genesis_target_ready"
        self.assertIsNone(router.arm_genesis_target_v1(
            caller=addr("faulting-armer"), clock=first_ready_clock
        ))
        self.assertIs(router.scheduled_genesis_target, scheduled_before_fault)
        self.assertIsNone(router.armed_genesis_target)
        self.assertEqual(
            router.retired_target_checkpoint_state, "RETIRED_TARGET_CLEARED"
        )
        self.assertIs(
            router.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        router.migration_fault_point = None
        self.assertIsNotNone(router.arm_genesis_target_v1(
            caller=addr("first-armer"), clock=first_ready_clock
        ))
        self.assertEqual(router.retired_target_checkpoint_state, "READY")
        stale_proof = router.genesis_activation_proof_stub_v1(original)
        original_tuple = router._genesis_target_tuple_v1(
            router.armed_genesis_target
        )
        self.assertIsNotNone(original_tuple)
        cancel_args = dict(
            checkpoint_id=original_tuple[0],
            target_address=original_tuple[1],
            target_protocol_version=original_tuple[2],
            target_manifest_hash=original_tuple[3],
            target_registration_hash=original_tuple[4],
        )
        cancel_ready_at = first_ready_at + delay
        self.assertFalse(router.schedule_genesis_target_cancel_v1(
            **cancel_args,
            executable_at=cancel_ready_at,
            caller=addr("not-governance"),
            clock=first_ready_clock,
        ))
        self.assertTrue(router.schedule_genesis_target_cancel_v1(
            **cancel_args,
            executable_at=cancel_ready_at,
            caller=router.version_manager,
            clock=first_ready_clock,
        ))
        self.assertIsNone(router.cancel_genesis_target_v1(
            **cancel_args,
            caller=addr("early-canceler"),
            clock=replace(first_ready_clock, timestamp=cancel_ready_at - 1),
        ))
        self.assertIsNone(router.cancel_genesis_target_v1(
            **{**cancel_args, "target_address": addr("substitute")},
            caller=addr("cancel-keeper"),
            clock=replace(first_ready_clock, timestamp=cancel_ready_at),
        ))
        cancel_clock = replace(first_ready_clock, timestamp=cancel_ready_at)
        cancel_projection = (
            router.armed_genesis_target,
            router.scheduled_genesis_target_cancel,
            frozenset(router.canceled_genesis_target_tuples),
            router.retired_target_checkpoint_state,
            router.legacy_launch_hook.legacy_launch_state_v1(),
            router.forced_queue.active_settlement_address,
        )
        router.migration_fault_point = "after_genesis_target_cancel"
        self.assertIsNone(router.cancel_genesis_target_v1(
            **cancel_args,
            caller=addr("cancel-keeper"),
            clock=cancel_clock,
        ))
        self.assertEqual(cancel_projection, (
            router.armed_genesis_target,
            router.scheduled_genesis_target_cancel,
            frozenset(router.canceled_genesis_target_tuples),
            router.retired_target_checkpoint_state,
            router.legacy_launch_hook.legacy_launch_state_v1(),
            router.forced_queue.active_settlement_address,
        ))
        self.assertIs(
            router.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        router.migration_fault_point = None
        self.assertEqual(router.cancel_genesis_target_v1(
            **cancel_args,
            caller=addr("cancel-keeper"),
            clock=cancel_clock,
        ), ("READY", "RETIRED_TARGET_CLEARED"))
        self.assertIs(
            router.migration_lifecycle,
            settlement.RouterMigrationLifecycle.IDLE,
        )
        self.assertEqual(
            router.retired_target_checkpoint_state, "RETIRED_TARGET_CLEARED"
        )
        self.assertIsNone(router.cancel_genesis_target_v1(
            **cancel_args,
            caller=addr("stale-canceler"),
            clock=cancel_clock,
        ))
        self.assertIs(
            router.legacy_launch_hook.phase,
            settlement.LegacyLaunchPhase.READY,
        )
        self.assertEqual(router.legacy_launch_hook.checkpoint_id,
                         checkpoint.checkpoint_id)
        self.assertEqual(
            router.forced_queue.active_settlement_address,
            router.legacy_launch_hook.proxy_address,
        )
        self.assertIn(original_tuple, router.canceled_genesis_target_tuples)
        self.assertFalse(router.schedule_genesis_target_v1(
            original,
            executable_at=cancel_ready_at + delay,
            caller=router.version_manager,
            clock=cancel_clock,
        ))

        replacement_profile = original.execution_profile
        replacement = settlement.VersionedSettlementHistory(
            addr("replacement-target"),
            "runtime:replace-target",
            original.protocol_version,
            replacement_profile.execution_profile_hash,
            copy.deepcopy(original.core),
            original.canonicalized_at_block,
            protocol.forced_queue,
            migration_gate=protocol.migration_gate,
            inbox_apply_descriptor=protocol.inbox_apply_descriptor,
            header_oracle=protocol.header_oracle,
            market_runtime_hash=settlement._model_fixed_bytes32(
                "runtime:replace-target"
            ),
            execution_profile=replacement_profile,
            release_profile_ingress_specs=
                original.release_profile_ingress_specs,
        )
        second_ready_at = cancel_ready_at + delay
        self.assertTrue(router.schedule_genesis_target_v1(
            replacement,
            executable_at=second_ready_at,
            caller=router.version_manager,
            clock=cancel_clock,
        ))
        second_ready_clock = replace(
            landing_clock, timestamp=second_ready_at
        )
        self.assertIsNotNone(router.arm_genesis_target_v1(
            caller=addr("replacement-armer"), clock=second_ready_clock
        ))
        ready_projection = (
            router.legacy_launch_hook.legacy_launch_state_v1(),
            router.forced_queue._transaction_snapshot(),
            router.armed_genesis_target,
            replacement.mode,
            replacement.current_sequence,
        )
        self.assertFalse(router.bootstrap(
            replacement, sequence=0, clock=second_ready_clock,
            caller=addr("replacement-lander"), proof=stale_proof,
        ))
        self.assertEqual(ready_projection, (
            router.legacy_launch_hook.legacy_launch_state_v1(),
            router.forced_queue._transaction_snapshot(),
            router.armed_genesis_target,
            replacement.mode,
            replacement.current_sequence,
        ))
        replacement_proof = router.genesis_activation_proof_stub_v1(
            replacement
        )
        self.assertTrue(router.bootstrap(
            replacement, sequence=0, clock=second_ready_clock,
            caller=addr("replacement-lander"), proof=replacement_proof,
        ))
        self.assertEqual(router.active_version, original.protocol_version)
        self.assertEqual(
            router.forced_queue.active_settlement_address,
            replacement.address,
        )
        self.assertNotEqual(
            replacement.address, router.bootstrap_target_address
        )

    def test_genesis_context_and_queue_authority_substitutions_fail_closed(self):
        active_target = settlement.protocol(seat=False).settlement_address
        for authority in (
            "", active_target, "active-settlement-router",
            addr("foreign-authority"),
        ):
            protocol = settlement.protocol(seat=False)
            protocol.forced_queue.active_settlement_address = authority
            profile = settlement.execution_profile_for_test(
                25, f"profile:queue-substitution:{authority}"
            )
            history = settlement.VersionedSettlementHistory(
                protocol.settlement_address,
                "runtime:queue-substitution",
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
            with self.assertRaises(ValueError, msg=authority):
                settlement.deploy_active_settlement_router(
                    history,
                    addr("version-manager"),
                    protocol.forced_queue,
                    protocol.inbox_apply_router,
                    protocol.migration_gate,
                    protocol.header_oracle,
                )

        core = settlement.CanonicalCore(
            1, "b" * 64, 1, "s" * 64, 0
        )
        base = dict(
            transition_kind="GENESIS_IMPORT",
            router_generation=1,
            seat_generation=0,
            source_protocol_version=0,
            target_protocol_version=1,
            target_manifest_hash=b"m" * 32,
            target_registration_hash=b"r" * 32,
            source_checkpoint_id=b"c" * 32,
            source_boundary_hash=b"d" * 32,
            source_settlement=addr("legacy-proxy"),
            target_settlement=addr("target"),
            target_canonical_sequence=0,
            candidate_digest="candidate",
            output_core=core,
            output_core_hash=settlement.canonical_core_hash_v2(core),
            canonicalized_at_block=1,
            queue_start=0,
            queue_end=0,
            queue_address=addr("queue"),
            queue_root="queue-root",
            queue_count=0,
            queue_credited_wei=0,
            queue_post_accounted_liability_wei=0,
            queue_post_total_claimable_wei=0,
            beneficiary=addr("beneficiary"),
            settlement_chain_id=1,
            router_address=addr("router"),
            source_manifest_hash=b"l" * 32,
            base_canonical_hash=b"h" * 32,
            statement_hash=b"t" * 32,
            source_poststate_commitment=b"p" * 32,
        )
        exact = settlement.MigrationCanonicalContextV2(
            source_canonical_sequence=0, **base
        )
        self.assertEqual(exact.source_canonical_sequence, 0)
        self.assertEqual(
            len(exact.source_return),
            settlement.MIGRATION_SOURCE_FREEZE_RETURN_LENGTH,
        )
        self.assertEqual(len(exact.source_return), 96)
        self.assertEqual(len(exact.target_return), 96)
        self.assertEqual(len(exact.queue_return), 128)
        self.assertEqual(len(exact.maps_return), 128)
        self.assertEqual(len(exact.adopt_calldata), 580)
        self.assertEqual(len(exact.freeze_calldata), 36)
        self.assertEqual(len(exact.queue_calldata), 260)
        self.assertEqual(len(exact.maps_calldata), 36)
        exact_core = commitment.CanonicalCoreV2(
            core.l2_block_number,
            settlement._model_fixed_bytes32(core.tip_hash),
            core.tip_slot,
            settlement._model_fixed_bytes32(core.state_root),
            core.message_cursor,
            settlement._model_fixed_bytes32(core.winning_data_commitment),
            core.next_base_fee,
            core.next_excess_blob_gas,
            settlement._model_fixed_bytes32(core.terminal_root),
            core.terminal_count,
        )
        expected_context_hash = commitment.migration_activation_context_hash(
            exact.settlement_chain_id,
            int(exact.router_address, 16),
            1,
            exact.router_generation,
            exact.seat_generation,
            exact.source_protocol_version,
            exact.target_protocol_version,
            exact.source_manifest_hash,
            exact.target_manifest_hash,
            exact.target_registration_hash,
            int(exact.source_settlement, 16),
            int(exact.target_settlement, 16),
            exact.source_canonical_sequence,
            exact.base_canonical_hash,
            exact.statement_hash,
            settlement._model_fixed_bytes32(exact.candidate_digest),
            exact_core,
            int(exact.queue_address, 16),
            settlement._model_fixed_bytes32(exact.queue_root),
            exact.queue_count,
            exact.queue_start,
            exact.queue_end,
            int(exact.beneficiary, 16),
            exact.canonicalized_at_block,
        )
        self.assertEqual(exact.commitment, expected_context_hash)
        self.assertEqual(
            exact.adopt_calldata,
            commitment.encode_adopt_migration_canonical_calldata(
                1, exact.router_generation, exact.seat_generation,
                exact.source_protocol_version, exact.target_protocol_version,
                exact.source_canonical_sequence, exact.target_manifest_hash,
                settlement._model_fixed_bytes32(exact.candidate_digest),
                exact_core,
            ),
        )
        self.assertEqual(
            exact.queue_calldata,
            commitment.encode_queue_migration_calldata(
                exact.commitment, int(exact.source_settlement, 16),
                int(exact.target_settlement, 16),
                settlement._model_fixed_bytes32(exact.queue_root),
                exact.queue_count, exact.queue_start, exact.queue_end,
                int(exact.beneficiary, 16),
            ),
        )
        self.assertNotEqual(
            replace(exact, router_generation=2).commitment,
            exact.commitment,
        )
        for invalid_source_sequence in (-1, 1):
            with self.assertRaises(ValueError):
                settlement.MigrationCanonicalContextV2(
                    source_canonical_sequence=invalid_source_sequence,
                    **base,
                )
        with self.assertRaises(ValueError):
            settlement.MigrationCanonicalContextV2(
                source_canonical_sequence=0,
                **{**base, "seat_generation": 1},
            )
        migration = {
            **base,
            "transition_kind": "VERSION_MIGRATION",
            "source_checkpoint_id": bytes(32),
            "source_boundary_hash": bytes(32),
            "source_canonical_sequence": 1,
            "target_canonical_sequence": 2,
            "source_poststate_commitment": bytes(32),
        }
        with self.assertRaises(ValueError):
            settlement.MigrationCanonicalContextV2(**migration)
        self.assertEqual(
            settlement.MigrationCanonicalContextV2(
                **{**migration, "seat_generation": 2}
            ).seat_generation,
            2,
        )

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

    def test_rotation_requires_separate_frozen_tombstone_reconciliation(self):
        rows = production_migration_fixture()
        stage_id, lineup = self._stage_old_target(rows)
        old_protocol, old_history, _new_history, seat_market = rows[:4]
        receipt = activate_production_fixture(rows)
        seat_manager = rows[4]
        manager = rows[5]
        tombstone = old_protocol.stage_tombstones[stage_id]
        self.assertTrue(tombstone.migration_terminal)
        self.assertFalse(tombstone.reconciled)
        self.assertIsNotNone(seat_market.stage)

        # Rotation cannot silently absorb a Settlement-to-Market cancellation.
        # Its failed attempt is byte-identical in both components.
        market_before = copy.deepcopy(seat_market)
        graph_before = migration_graph_projection(old_protocol, seat_manager)
        blocked = market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(2_001, settlement.GENESIS_TIMESTAMP + 2_001),
            )
        )
        self.assertIs(
            blocked.result, market.MarketRotationResult.RECONCILIATION_REQUIRED
        )
        self.assertEqual(blocked.blocking_stage_id, stage_id)
        self.assertEqual(seat_market, market_before)
        self.assertEqual(
            migration_graph_projection(old_protocol, seat_manager), graph_before
        )

        result = old_protocol.reconcile_stage_invalidation(
            seat_market,
            stage_id,
            lineup,
            settlement.Clock(2_002, settlement.GENESIS_TIMESTAMP + 2_002),
        )
        self.assertIsNotNone(result.credit_id)
        self.assertTrue(tombstone.reconciled)
        self.assertIsNone(old_protocol.outstanding_stage_tombstone_id)
        self.assertIsNone(seat_market.stage)

        runtime = seat_market.target_runtimes[receipt.old_authorization_id]
        market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(2_003, settlement.GENESIS_TIMESTAMP + 2_003)
            )
        )
        self.assertIs(seat_market.release_manager, manager)
        self.assertIs(runtime.authority, old_history)
        self.assertEqual(
            seat_market.current_authorization_id,
            receipt.new_authorization_id,
        )

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
        with self.assertRaises(settlement.DataSessionRevert):
            old_protocol.open_session(
                settlement.Clock(2_000, settlement.GENESIS_TIMESTAMP + 2_000),
                addr("attacker"),
                0,
                settlement.GENESIS_TIMESTAMP + 9_000,
            )
        result = market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(2_001, settlement.GENESIS_TIMESTAMP + 2_001)
            )
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

    def test_staged_source_package_does_not_disable_active_route(self):
        successor_descriptor = replace(
            settlement.canonical_source_bridge_descriptor(),
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_salt="salt:source-successor:staged-only:v2",
            deployment_descriptor=None,
        )
        rows = production_migration_fixture(
            source_bridge_descriptor=successor_descriptor
        )
        manager = rows[4]
        router = manager.router
        old_source = settlement.source_bridge_for_test(router)
        old_registry_alias = router._bridge_credit_registry_authority
        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 1_000
        )
        _manifest, target_registration = schedule_production_bridge_package(
            rows,
            arm_clock=arm_clock,
            staged_block=(
                arm_clock.block_number
                - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS
            ),
        )
        target_descriptor_id = router._source_descriptor_id_by_version[
            target_registration.settlement.protocol_version
        ]
        target_source = router._source_bundles_by_descriptor_id[
            target_descriptor_id
        ][0]

        self.assertIs(router._source_bridge_authority, old_source)
        self.assertIs(
            router._bridge_credit_registry_authority, old_registry_alias
        )
        self.assertFalse(target_source.v2_active)
        self.assertTrue(router.bridge_package_arm_ready_v1(
            target_registration, clock=arm_clock
        ))
        package_view = router._bridge_domain_registry_authority \
            .bridge_route_package_v1(
                settlement.BRIDGE_ROUTE_PACKAGE_SELECTOR
                + settlement._model_uint(
                    target_registration.release_manifest.destination_chain_id,
                    32, "test BRP1 destination chain",
                )
                + settlement._model_uint(
                    target_registration.settlement.protocol_version,
                    32, "test BRP1 version",
                ),
                caller=router.address, value=0,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                clock=arm_clock,
            )
        self.assertEqual(len(package_view), 480)
        self.assertEqual(package_view[:32], b"BRP1" + bytes(28))
        self.assertEqual(int.from_bytes(package_view[32:64], "big"), 2)

        old_clock = old_source.support_final_clock(arm_clock.timestamp)
        old_message = settlement.bridge_message(
            old_clock.timestamp,
            "staged-target-does-not-stop-old",
            value=3,
            fee=1,
            liquidity_fee=1,
        )
        self.assertTrue(old_source.send_message(
            old_message,
            caller=old_message.sender,
            msg_value=5,
            clock=old_clock,
            enqueue_by=(
                old_clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
            ),
        ))
        with self.assertRaises(ValueError):
            target_source.credit_id_for(old_message, arm_clock)
        old_state = old_source._transaction_snapshot()
        router.active_settlement_state_return_override = b"ASR1"
        with self.assertRaises(ValueError):
            old_source.credit_id_for(old_message, old_clock)
        self.assertEqual(old_source._transaction_snapshot(), old_state)
        router.active_settlement_state_return_override = None

    def test_active_route_requires_exact_idle_mact_before_asr1(self):
        rows = production_migration_fixture()
        router = rows[4].router
        source = settlement.source_bridge_for_test(router)
        now = source.support_final_clock(
            settlement.GENESIS_TIMESTAMP + 2_000
        )
        message = settlement.bridge_message(
            now.timestamp, "exact-idle-mact-route", value=3, fee=1,
            liquidity_fee=1,
        )
        valid = router.migration_activation_context_v1()
        decoded = settlement.decode_migration_activation_context_v1(valid)
        self.assertEqual(
            settlement.MIGRATION_ACTIVATION_CONTEXT_SELECTOR.hex(),
            "7cf70319",
        )
        self.assertEqual(len(valid), 320)
        self.assertIs(
            decoded.lifecycle, settlement.RouterMigrationLifecycle.IDLE
        )
        self.assertEqual(valid[64:], bytes(256))
        self.assertEqual(
            router.staticcall_migration_activation_context_v1(
                settlement.MIGRATION_ACTIVATION_CONTEXT_SELECTOR,
                caller=source.domain_registry.address, value=0,
                gas=settlement.MIGRATION_ACTIVATION_CONTEXT_GAS,
            ),
            valid,
        )
        asr = router.active_settlement_state_v1()
        self.assertEqual(
            router.staticcall_active_settlement_state_v1(
                settlement.ACTIVE_SETTLEMENT_STATE_SELECTOR,
                caller=source.domain_registry.address, value=0,
                gas=settlement.ACTIVE_SETTLEMENT_STATE_GAS,
            ),
            asr,
        )
        for invoke in (
            lambda: router.staticcall_migration_activation_context_v1(
                b"bad!", caller=source.domain_registry.address, value=0,
                gas=settlement.MIGRATION_ACTIVATION_CONTEXT_GAS,
            ),
            lambda: router.staticcall_migration_activation_context_v1(
                settlement.MIGRATION_ACTIVATION_CONTEXT_SELECTOR + b"\x00",
                caller=source.domain_registry.address, value=0,
                gas=settlement.MIGRATION_ACTIVATION_CONTEXT_GAS,
            ),
            lambda: router.staticcall_migration_activation_context_v1(
                settlement.MIGRATION_ACTIVATION_CONTEXT_SELECTOR,
                caller=source.domain_registry.address, value=1,
                gas=settlement.MIGRATION_ACTIVATION_CONTEXT_GAS,
            ),
            lambda: router.staticcall_migration_activation_context_v1(
                settlement.MIGRATION_ACTIVATION_CONTEXT_SELECTOR,
                caller=source.domain_registry.address, value=0,
                gas=settlement.MIGRATION_ACTIVATION_CONTEXT_GAS - 1,
            ),
            lambda: router.staticcall_active_settlement_state_v1(
                b"bad!", caller=source.domain_registry.address, value=0,
                gas=settlement.ACTIVE_SETTLEMENT_STATE_GAS,
            ),
            lambda: router.staticcall_active_settlement_state_v1(
                settlement.ACTIVE_SETTLEMENT_STATE_SELECTOR + b"\x00",
                caller=source.domain_registry.address, value=0,
                gas=settlement.ACTIVE_SETTLEMENT_STATE_GAS,
            ),
            lambda: router.staticcall_active_settlement_state_v1(
                settlement.ACTIVE_SETTLEMENT_STATE_SELECTOR,
                caller=source.domain_registry.address, value=1,
                gas=settlement.ACTIVE_SETTLEMENT_STATE_GAS,
            ),
            lambda: router.staticcall_active_settlement_state_v1(
                settlement.ACTIVE_SETTLEMENT_STATE_SELECTOR,
                caller=source.domain_registry.address, value=0,
                gas=settlement.ACTIVE_SETTLEMENT_STATE_GAS - 1,
            ),
        ):
            with self.assertRaises(ValueError):
                invoke()
        self.assertTrue(source.credit_id_for(message, now))
        registry = source.domain_registry
        abr_call = b"".join((
            settlement.ACTIVE_BRIDGE_ROUTE_SELECTOR,
            settlement._model_uint(
                message.message.destination_chain_id,
                32, "test ABR2 destination chain",
            ),
            bytes(12) + settlement._model_address20(source.address),
            settlement._model_fixed_bytes32(source.source_domain_id),
            settlement._model_fixed_bytes32(
                source.frozen_bridge_execution_hash
            ),
            bytes(12) + settlement._model_address20(message.message.to),
        ))
        abr = registry.active_bridge_route_v2(
            abr_call, caller=source.address, value=0,
            gas=settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS, clock=now,
        )
        self.assertEqual((len(abr), abr[:32]), (384, b"ABR2" + bytes(28)))
        self.assertEqual(
            settlement.encode_active_bridge_route_v2(
                settlement.decode_active_bridge_route_v2(abr)
            ),
            abr,
        )
        dirty_address = bytearray(abr_call)
        dirty_address[36] = 1
        for candidate, caller, value, gas in (
            (abr_call[:-1], source.address, 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (abr_call + b"\x00", source.address, 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (b"bad!" + abr_call[4:], source.address, 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (bytes(dirty_address), source.address, 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (abr_call, addr("wrong-abr-caller"), 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (abr_call, source.address, 1,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS),
            (abr_call, source.address, 0,
             settlement.ACTIVE_BRIDGE_ROUTE_READ_GAS - 1),
        ):
            with self.assertRaises(ValueError):
                registry.active_bridge_route_v2(
                    candidate, caller=caller, value=value, gas=gas, clock=now
                )

        bad_magic = bytearray(valid)
        bad_magic[0] ^= 1
        bad_padding = bytearray(valid)
        bad_padding[32] = 1
        nonzero_context = bytearray(valid)
        nonzero_context[95] = 1
        non_idle = settlement.encode_migration_activation_context_v1(
            settlement.MigrationActivationContextStateV1(
                settlement.RouterMigrationLifecycle.ARMING,
                bytes(32), bytes(20), bytes(20), 0, 0, 0,
                bytes(32), bytes(32),
            )
        )
        for malformed in (
            valid[:-1], valid + b"\x00", bytes(bad_magic),
            bytes(bad_padding), bytes(nonzero_context), non_idle,
        ):
            before = source._transaction_snapshot()
            router.migration_activation_context_return_override = malformed
            with self.assertRaises(ValueError):
                source.credit_id_for(message, now)
            self.assertEqual(source._transaction_snapshot(), before)
        router.migration_activation_context_return_override = None

        for fault in ("revert", "oog"):
            before = source._transaction_snapshot()
            router.migration_activation_context_fault_point = fault
            with self.assertRaises(ValueError):
                source.credit_id_for(message, now)
            self.assertEqual(source._transaction_snapshot(), before)
        router.migration_activation_context_fault_point = None

        bad_asr_magic = bytearray(asr)
        bad_asr_magic[0] ^= 1
        bad_asr_padding = bytearray(asr)
        bad_asr_padding[32] = 1
        bad_asr_phase = bytearray(asr)
        bad_asr_phase[-1] = settlement.RouterPhase.ARMED.value
        for malformed in (
            asr[:-1], asr + b"\x00", bytes(bad_asr_magic),
            bytes(bad_asr_padding), bytes(bad_asr_phase),
        ):
            before = source._transaction_snapshot()
            router.active_settlement_state_return_override = malformed
            with self.assertRaises(ValueError):
                source.credit_id_for(message, now)
            self.assertEqual(source._transaction_snapshot(), before)
        router.active_settlement_state_return_override = None
        for fault in ("revert", "oog"):
            before = source._transaction_snapshot()
            router.active_settlement_state_fault_point = fault
            with self.assertRaises(ValueError):
                source.credit_id_for(message, now)
            self.assertEqual(source._transaction_snapshot(), before)
        router.active_settlement_state_fault_point = None
        registry.active_bridge_route_return_override = b"ABR2"
        with self.assertRaises(ValueError):
            source.credit_id_for(message, now)
        registry.active_bridge_route_return_override = None
        for fault in ("revert", "oog"):
            registry.active_bridge_route_fault_point = fault
            with self.assertRaises(ValueError):
                source.credit_id_for(message, now)
        registry.active_bridge_route_fault_point = None
        self.assertTrue(source.credit_id_for(message, now))

    def test_arm_rejects_unmatured_or_directly_consumed_package(self):
        successor_descriptor = replace(
            settlement.canonical_source_bridge_descriptor(),
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_salt="salt:source-successor:arm-delay:v2",
            deployment_descriptor=None,
        )
        rows = production_migration_fixture(
            source_bridge_descriptor=successor_descriptor
        )
        manager = rows[4]
        router = manager.router
        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 1_000
        )
        manifest, target_registration = schedule_production_bridge_package(
            rows, arm_clock=arm_clock, staged_block=arm_clock.block_number - 1
        )
        registry = router._bridge_domain_registry_authority
        entry = next(
            row for row in registry.entries.values()
            if row.protocol_version == target_registration.settlement.protocol_version
        )
        snapshot = registry._transaction_snapshot()
        package_view = registry.bridge_route_package_v1(
            settlement.BRIDGE_ROUTE_PACKAGE_SELECTOR
            + settlement._model_uint(
                target_registration.release_manifest.destination_chain_id,
                32, "test BRP1 destination chain",
            )
            + settlement._model_uint(
                target_registration.settlement.protocol_version,
                32, "test BRP1 version",
            ),
            caller=router.address, value=0,
            gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
            clock=arm_clock,
        )
        self.assertEqual(int.from_bytes(package_view[32:64], "big"), 1)

        self.assertIsNone(registry.arm_ready_entry(
            target_registration,
            target_registration.release_manifest.destination_chain_id,
            arm_clock,
        ))
        self.assertFalse(registry.consume_arm_ready(
            target_registration,
            settlement.Clock(
                arm_clock.block_number
                    + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                arm_clock.timestamp,
            ),
            router=router,
            capability=object(),
        ))
        self.assertFalse(registry.consume_arm_ready(
            target_registration,
            arm_clock,
            router=router,
            capability=settlement._BRIDGE_ROUTE_ACTIVATION_CAPABILITY,
        ))
        self.assertFalse(registry.consume_arm_ready(
            router.registrations[router.active_version],
            settlement.Clock(
                arm_clock.block_number
                    + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                arm_clock.timestamp,
            ),
            router=router,
            capability=settlement._BRIDGE_ROUTE_ACTIVATION_CAPABILITY,
        ))
        self.assertEqual(registry._transaction_snapshot(), snapshot)
        self.assertFalse(entry.arm_ready_consumed)
        with self.assertRaises(ValueError):
            manager.arm_seat_migration(
                manifest_key=manifest.key,
                executor=addr("executor"),
                clock=arm_clock,
            )
        self.assertEqual(router.migration_gate.mode, "ACTIVE")
        self.assertFalse(entry.arm_ready_consumed)

    def test_abort_keeps_old_source_active_and_target_unconsumed(self):
        successor_descriptor = replace(
            settlement.canonical_source_bridge_descriptor(),
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_salt="salt:source-successor:abort:v2",
            deployment_descriptor=None,
        )
        rows = production_migration_fixture(
            source_bridge_descriptor=successor_descriptor
        )
        manager = rows[4]
        router = manager.router
        old_source = settlement.source_bridge_for_test(router)
        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 1_000
        )
        manifest, _target_registration = schedule_production_bridge_package(
            rows,
            arm_clock=arm_clock,
            staged_block=(
                arm_clock.block_number
                - settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS
            ),
        )
        manager.arm_seat_migration(
            manifest_key=manifest.key,
            executor=addr("executor"),
            clock=arm_clock,
        )
        blocked = settlement.bridge_message(
            arm_clock.timestamp,
            "armed-route-rejects",
            value=2,
            fee=1,
            liquidity_fee=1,
        )
        self.assertEqual(router.migration_gate.mode, "ARMED")
        with self.assertRaises(ValueError):
            old_source.credit_id_for(blocked, arm_clock)
        ready_clock = settlement.Clock(
            arm_clock.block_number + 1, arm_clock.timestamp + 1
        )
        self.assertTrue(rows[0].sync(ready_clock))
        self.assertTrue(rows[1].enter_migration_ready())
        self.assertEqual(router.migration_gate.mode, "READY")
        with self.assertRaises(ValueError):
            old_source.credit_id_for(blocked, ready_clock)
        abort_clock = settlement.Clock(
            ready_clock.block_number + 1,
            settlement.GENESIS_TIMESTAMP + 1_000
            + settlement.SEAT_MIGRATION_CANCEL_DELAY,
        )
        self.assertTrue(execute_manager_abort(manager, abort_clock))
        target_entry = next(
            row for row in router._bridge_domain_registry_authority.entries.values()
            if row.protocol_version == rows[2].protocol_version
        )
        self.assertEqual(router.migration_gate.mode, "ACTIVE")
        self.assertIs(settlement.source_bridge_for_test(router), old_source)
        self.assertFalse(target_entry.arm_ready_consumed)

        old_clock = old_source.support_final_clock(abort_clock.timestamp)
        message = settlement.bridge_message(
            old_clock.timestamp,
            "aborted-target-old-route",
            value=2,
            fee=1,
            liquidity_fee=1,
        )
        self.assertTrue(old_source.send_message(
            message,
            caller=message.sender,
            msg_value=4,
            clock=old_clock,
            enqueue_by=(
                old_clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
            ),
        ))

    def test_activation_faults_roll_back_arm_ready_consumption(self):
        fault_points = (
            ("router", "after_source_freeze"),
            ("router", "after_target_adopt"),
            ("manager", "after_target_import"),
            ("manager", "after_activation_receipt_write"),
            ("router", "before_queue_migrate"),
        )
        for owner, fault in fault_points:
            with self.subTest(owner=owner, fault=fault):
                successor_descriptor = replace(
                    settlement.canonical_source_bridge_descriptor(),
                    source_bridge="",
                    bridge_credit_registry="",
                    native_quota_manager="",
                    deployment_salt=f"salt:source-fault:{fault}:v2",
                    deployment_descriptor=None,
                )
                rows = production_migration_fixture(
                    source_bridge_descriptor=successor_descriptor
                )
                manager = rows[4]
                router = manager.router
                old_version = router.active_version
                old_source = settlement.source_bridge_for_test(router)
                manifest, proof = prepare_production_activation(rows)
                entry = next(
                    row for row in router._bridge_domain_registry_authority
                        .entries.values()
                    if row.protocol_version == rows[2].protocol_version
                )
                self.assertFalse(entry.arm_ready_consumed)
                if owner == "router":
                    router.migration_fault_point = fault
                else:
                    manager.fault_point = fault
                with self.assertRaises(RuntimeError):
                    manager.activate_seat_migration(
                        manifest_key=manifest.key,
                        activation_proof=proof,
                        executor=addr("fault-executor"),
                        clock=migration_proof_clock(proof),
                    )
                restored = next(
                    row for row in router._bridge_domain_registry_authority
                        .entries.values()
                    if row.protocol_version == rows[2].protocol_version
                )
                self.assertFalse(restored.arm_ready_consumed)
                self.assertEqual(router.active_version, old_version)
                self.assertIs(settlement.source_bridge_for_test(router), old_source)
                self.assertEqual(router.migration_gate.mode, "READY")

    def test_historical_reward_lifecycle_survives_cutover_and_late_fault(self):
        rows = production_migration_fixture()
        old_protocol, old_history, new_history = rows[:3]
        manager = rows[4]

        recovery_trigger = settlement.Clock(
            1_000,
            settlement.GENESIS_TIMESTAMP
            + old_protocol.core.tip_slot
            + settlement.DELTA_FINAL_LAG
            + 1,
        )
        self.assertTrue(old_protocol.sync(recovery_trigger))
        reward_clock = settlement.recovery_submit_clock(old_protocol)
        reward_candidate = settlement.candidate(
            old_protocol,
            reward_clock,
            "historical-reward-lifecycle",
            tier=settlement.Tier.ESCAPE_UNSIGNED,
            signed=False,
            slot=old_protocol.recovery.escape_slot,
            discretionary=False,
            recovery_fields_zero=False,
            beneficiary=addr("hist-beneficiary"),
            gas_used=7,
        )
        self.assertEqual(
            old_protocol.submit(reward_candidate, reward_clock), "COMMITTED"
        )
        committed = old_protocol.reward_events[-1]
        receipt, claimed = old_protocol.reward_receipt_state_v1(
            committed.candidate_id
        )
        self.assertIsNotNone(receipt)
        self.assertFalse(claimed)
        self.assertEqual(receipt.reward_class, 3)
        reward_class = old_protocol.reward_class_registry.class_by_id(
            receipt.reward_class
        )
        reward_amount = old_protocol.reward_amount_v1(receipt, reward_class)
        old_protocol.fund_reward_class_v1(
            receipt.reward_class,
            reward_amount,
            funder=addr("hist-funder"),
        )

        # The production fixture constructs the successor before this source
        # commit. Model a real deployment after the reward-bearing canonical
        # state by refreshing only its constructor-copied canonical snapshot.
        new_history.core = copy.deepcopy(old_protocol.core)
        new_history.canonicalized_at_block = (
            old_protocol.canonical.canonicalized_at_block
        )
        new_history.live_protocol.canonical = copy.deepcopy(
            old_protocol.canonical
        )

        def reward_projection(protocol):
            return copy.deepcopy((
                protocol.reward_receipts,
                protocol.reward_funded_by_class,
                protocol.total_reward_funding,
                protocol.settlement_eth_balance,
                protocol.reward_events,
                protocol.reward_accounting_events,
                protocol.reward_payments,
                protocol.reward_execution_profile_hash,
                protocol.reward_class_registry_address,
                protocol.reward_class_registry_runtime_hash,
                protocol.reward_class_registry_configuration_hash,
                protocol.reward_class_registry,
            ))

        source_reward_state = reward_projection(old_protocol)
        arm_clock = settlement.Clock(
            max(1_100, reward_clock.block_number + 10),
            reward_clock.timestamp + 10,
        )
        manifest, proof = prepare_production_activation(
            rows, clock=arm_clock
        )
        activation_clock = migration_proof_clock(proof)

        manager.fault_point = "after_activation_receipt_write"
        with self.assertRaises(RuntimeError):
            manager.activate_seat_migration(
                manifest_key=manifest.key,
                activation_proof=proof,
                executor=addr("fault-executor"),
                clock=activation_clock,
            )
        self.assertEqual(reward_projection(old_protocol), source_reward_state)
        self.assertEqual(old_history.mode, "MIGRATION_READY")
        self.assertEqual(manager.router.active_version, 25)

        manager.fault_point = None
        manager.activate_seat_migration(
            manifest_key=manifest.key,
            activation_proof=proof,
            executor=addr("executor"),
            clock=activation_clock,
        )
        new_protocol = new_history.live_protocol
        self.assertEqual(old_history.mode, "FROZEN")
        self.assertEqual(new_history.mode, "ACTIVE")
        self.assertEqual(reward_projection(old_protocol), source_reward_state)
        self.assertEqual(set(new_protocol.reward_receipts), {1, 2, 3})
        self.assertTrue(all(
            cell == settlement.RewardReceiptCellV1()
            for ring in new_protocol.reward_receipts.values()
            for cell in ring
        ))
        self.assertEqual(
            new_protocol.reward_funded_by_class, {1: 0, 2: 0, 3: 0}
        )
        self.assertEqual(new_protocol.total_reward_funding, 0)
        self.assertEqual(new_protocol.settlement_eth_balance, 0)
        self.assertEqual(
            old_protocol.reward_receipt_state_v1(committed.candidate_id),
            (receipt, False),
        )
        self.assertEqual(
            old_protocol.reward_funded_by_class,
            {1: 0, 2: 0, 3: reward_amount},
        )
        self.assertEqual(old_protocol.total_reward_funding, reward_amount)
        self.assertEqual(old_protocol.settlement_eth_balance, reward_amount)

        transfers = []
        self.assertEqual(
            old_protocol.claim_reward_v1(
                committed.candidate_id,
                activation_clock,
                transfer=lambda beneficiary, amount, exact_settlement: (
                    transfers.append((
                        beneficiary, amount, exact_settlement is old_protocol
                    )) or True
                ),
            ),
            reward_amount,
        )
        self.assertEqual(transfers, [(
            receipt.beneficiary, reward_amount, True
        )])
        accounting_events = len(old_protocol.reward_accounting_events)
        with self.assertRaises(settlement.RewardClaimRevert):
            old_protocol.claim_reward_v1(
                committed.candidate_id,
                activation_clock,
                transfer=lambda *_args: transfers.append("duplicate") or True,
            )
        self.assertEqual(len(old_protocol.reward_accounting_events), accounting_events)
        self.assertEqual(len(transfers), 1)
        self.assertEqual(
            old_protocol.reward_receipt_state_v1(committed.candidate_id),
            (receipt, True),
        )
        self.assertEqual(old_protocol.total_reward_funding, 0)
        self.assertEqual(old_protocol.settlement_eth_balance, 0)

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

        # REGISTER/schedule preparation has already won the CREATE2 race with
        # the exact inactive package.  An arbitrary caller can only retrieve
        # that same bundle; it cannot create or replace a current alias.
        predeployed, predeployed_registry, receipt = (
            factory.deploy_source_bundle(
                bound_successor_descriptor,
                support_registry,
                caller=addr("attacker"),
            )
        )
        self.assertFalse(receipt.created_now)
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

    def test_source_successor_exclusively_mints_while_history_refunds(self):
        successor_descriptor = replace(
            settlement.canonical_source_bridge_descriptor(),
            source_bridge="",
            bridge_credit_registry="",
            native_quota_manager="",
            deployment_salt="salt:source-successor:exclusive-mint:v2",
            deployment_descriptor=None,
        )
        rows = production_migration_fixture(
            source_bridge_descriptor=successor_descriptor
        )
        manager = rows[4]
        router = manager.router

        old_source = settlement.source_bridge_for_test(router)
        old_clock = old_source.support_final_clock(
            settlement.GENESIS_TIMESTAMP + 1_000
        )
        historical = settlement.bridge_message(
            old_clock.timestamp,
            "historical-source-refund",
            value=10,
            fee=2,
            liquidity_fee=1,
        )
        historical_enqueue_by = (
            old_clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        )
        historical_receipt = old_source.send_message(
            historical,
            caller=historical.sender,
            msg_value=13,
            clock=old_clock,
            enqueue_by=historical_enqueue_by,
        )

        activate_production_fixture(rows)
        new_source = settlement.source_bridge_for_test(router)
        self.assertIsNot(new_source, old_source)
        new_clock = new_source.support_final_clock(old_clock.timestamp + 1)
        blocked = settlement.bridge_message(
            new_clock.timestamp,
            "historical-source-new-credit",
            value=3,
            fee=1,
            liquidity_fee=1,
        )
        blocked_enqueue_by = (
            new_clock.timestamp + settlement.MAX_BRIDGE_ENQUEUE_DELAY
        )

        with self.assertRaises(ValueError):
            old_source.credit_id_for(blocked, new_clock)
        old_before = old_source._transaction_snapshot()
        old_registry_before = (
            old_source.credit_registry._authorization_snapshot()
        )
        with self.assertRaises(ValueError):
            old_source.send_message(
                blocked,
                caller=blocked.sender,
                msg_value=5,
                clock=new_clock,
                enqueue_by=blocked_enqueue_by,
            )
        self.assertEqual(old_source._transaction_snapshot(), old_before)
        self.assertEqual(
            old_source.credit_registry._authorization_snapshot(),
            old_registry_before,
        )

        live_receipt = new_source.send_message(
            blocked,
            caller=blocked.sender,
            msg_value=5,
            clock=new_clock,
            enqueue_by=blocked_enqueue_by,
        )
        self.assertEqual(
            new_source.credits[live_receipt.credit_id].status, "NEW"
        )
        active_registration = router.registrations[router.active_version]
        bridge_authorization = next(
            row for row in active_registration.ingress_authorizations
            if row.kind is settlement.ForceKind.BRIDGE_CREDIT
        )
        active_adapter = router._profile_deployments_by_version[
            router.active_version
        ][bridge_authorization.authorization_id]
        deposit = router.required_ingress_deposit(
            live_receipt.envelope, active_adapter
        )
        queued = active_adapter.enqueue(
            new_clock,
            envelope=live_receipt.envelope,
            caller=addr("cutover-enqueuer"),
            deposit=deposit,
        )
        self.assertTrue(queued.startswith("QUEUED:"))
        self.assertEqual(
            new_source.credits[live_receipt.credit_id].status, "QUEUED"
        )

        self.assertTrue(old_source.cancel(
            historical_receipt.credit_id,
            now=historical_enqueue_by + 1,
        ))
        self.assertEqual(old_source.withdraw_refund(historical.sender), 13)
        self.assertEqual(
            old_source.credits[historical_receipt.credit_id].status,
            "CANCELLED",
        )

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
            ("session_cell_by_id", {"dirty": 1}),
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

    def test_callback_and_queue_fault_matrix_restores_ready_cutover(self):
        faults = (
            ("source", "freeze_after_write"),
            ("source", "freeze_bad_return"),
            ("source", "source_maps_bad_return"),
            ("target", "adopt_after_core"),
            ("target", "adopt_after_history"),
            ("target", "adopt_bad_return"),
            ("target", "target_maps_bad_return"),
            ("queue", "after_credit"),
            ("queue", "after_swap"),
            ("queue", "bad_return"),
            ("queue", "maps_bad_return"),
            ("router", "after_source_freeze"),
            ("router", "after_target_adopt"),
            ("router", "before_queue_migrate"),
        )
        for component, fault in faults:
            rows = production_migration_fixture()
            old_protocol, old_history, target, _market, manager = rows[:5]
            manifest, proof = prepare_production_activation(rows)
            queue = manager.router.forced_queue
            if component == "source":
                old_history.migration_callback_fault_point = fault
            elif component == "target":
                target.migration_callback_fault_point = fault
            elif component == "queue":
                queue.migration_fault_point = fault
            else:
                manager.router.migration_fault_point = fault
            before = migration_graph_projection(old_protocol, manager)
            target_before = copy.deepcopy({
                key: value for key, value in target.__dict__.items()
                if key not in {
                    "forced_queue", "migration_gate", "live_protocol",
                    "inbox_apply_descriptor", "header_oracle",
                }
            })
            with self.assertRaises(
                (RuntimeError, ValueError, AssertionError), msg=f"{component}:{fault}"
            ):
                manager.activate_seat_migration(
                    manifest_key=manifest.key,
                    activation_proof=proof,
                    executor=addr("executor"),
                    clock=migration_proof_clock(proof),
                )
            self.assertEqual(
                migration_graph_projection(old_protocol, manager), before,
                f"{component}:{fault}",
            )
            self.assertEqual(
                {
                    key: value for key, value in target.__dict__.items()
                    if key not in {
                        "forced_queue", "migration_gate", "live_protocol",
                        "inbox_apply_descriptor", "header_oracle",
                    }
                },
                target_before,
                f"{component}:{fault}",
            )
            self.assertEqual(old_history.mode, "MIGRATION_READY")
            self.assertEqual(old_protocol.migration_gate.mode, "READY")
            self.assertEqual(target.mode, "PREACTIVE")
            self.assertEqual(queue.active_settlement_address, old_history.address)
            self.assertIs(
                manager.router.migration_lifecycle,
                settlement.RouterMigrationLifecycle.IDLE,
            )
            old_history.migration_callback_fault_point = None
            target.migration_callback_fault_point = None
            queue.migration_fault_point = None
            manager.router.migration_fault_point = None
            self.assertTrue(manager.activate_seat_migration(
                manifest_key=manifest.key,
                activation_proof=proof,
                executor=addr("executor"),
                clock=migration_proof_clock(proof),
            ))

    def test_migration_selectors_and_response_widths_are_frozen(self):
        self.assertEqual(
            settlement.SEAT_MIGRATION_ARM_SELECTOR.hex(), "91d657cf"
        )
        self.assertEqual(
            settlement.SEAT_MIGRATION_ABORT_SELECTOR.hex(), "c69d5579"
        )
        self.assertEqual(
            settlement.MIGRATION_CANONICAL_ADOPT_SELECTOR.hex(), "3286443c"
        )
        protocol, manager = migration_manager_fixture(seat=False)
        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 1_000
        )
        arm_raw = execute_manager_arm(manager, arm_clock)
        self.assertEqual(len(arm_raw), 192)
        self.assertEqual(
            settlement.decode_seat_migration_response(
                arm_raw
            ).target_registration_hash,
            b"r" * 32,
        )
        abort_raw = execute_manager_abort(
            manager,
            settlement.Clock(1_001, arm_clock.timestamp + 1),
        )
        self.assertEqual(len(abort_raw), 192)
        self.assertEqual(
            settlement.decode_seat_migration_response(
                abort_raw
            ).target_registration_hash,
            b"r" * 32,
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

        with self.assertRaises(ValueError):
            production_migration_fixture(
                target_header_variant="replaceable-wrapper"
            )

        for variant in ("copy-equal", "forged-header"):
            rows = production_migration_fixture()
            old_protocol, _old_history, target_history, seat_market, manager = rows[:5]
            substitutions = {}
            if variant == "forged-header":
                original = target_history.header_oracle.header(1)
                substitutions[1] = replace(original, block_hash="f" * 64)
            substituted_header = target_history.header_oracle.fork_for_test(
                substitutions
            )
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

        third_history, third_id = register_production_successor(
            rows, label="v3", protocol_version=27
        )
        # An aborted arm consumes a router generation but creates no receipt.
        abort_current_migration_generation(
            rows, target_version=27, manifest_byte=b"a"
        )
        third_receipt = activate_registered_successor(
            rows,
            third_history,
            second_id,
            third_id,
            manifest_byte=b"n",
        )
        first_activation_id = market.decode_successor_receipt_v1(
            manager.router.seat_successor_receipt_v1(first_id)
        ).receipt_id
        third_activation_id = market.decode_successor_receipt_v1(
            manager.router.seat_successor_receipt_v1(second_id)
        ).receipt_id
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

        first = market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(3_000, settlement.GENESIS_TIMESTAMP + 3_000)
            )
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

        second = market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(3_002, settlement.GENESIS_TIMESTAMP + 3_002)
            )
        )
        self.assertEqual(second.purged_count, 0)
        self.assertEqual(seat_market.current_authorization_id, third_id)
        self.assertTrue(seat_market.authorization_enabled[third_id])
        self.assertFalse(seat_market.authorization_enabled[first_id])
        self.assertFalse(seat_market.authorization_enabled[second_id])
        self.assertEqual(
            seat_market.consumed_activation_receipt_ids,
            {first_activation_id, third_activation_id},
        )
        seat_market.sync_seat_generation()
        with self.assertRaises(market.TransitionRejected):
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(3_003, settlement.GENESIS_TIMESTAMP + 3_003)
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
        market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(
                    first_activation_clock.timestamp + 2,
                    first_activation_clock.block_number + 2,
                )
            )
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
        market.decode_market_rotation_receipt_v1(
            seat_market.rotate_settlement_authorization_v1(
                market.Clock(
                    second_activation_clock.timestamp + 2,
                    second_activation_clock.block_number + 2,
                )
            )
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
            (-1, settlement.DutyStatus.FAILED_OVER),
            (0, settlement.DutyStatus.FAILED_OVER),
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
            market_runtime_hash=settlement._model_fixed_bytes32(
                "runtime:seat-v1"
            ),
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
        bootstrap_clock = settlement.Clock(
            max(400, protocol.canonical.canonicalized_at_block),
            settlement.GENESIS_TIMESTAMP + protocol.core.tip_slot,
        )
        bootstrap_proof = settlement.prepare_genesis_activation_for_test(
            router, history, bootstrap_clock
        )
        evolved_generation = protocol.seat_generation
        protocol.seat_generation = 0
        self.assertTrue(router.bootstrap(
            history,
            sequence=0,
            clock=bootstrap_clock,
            caller=router.version_manager,
            proof=bootstrap_proof,
        ))
        protocol.seat_generation = evolved_generation
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
            "arm_response_wrong_target_registration",
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
                target_registration_hash=b"r" * 32,
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
            lambda word: replace(word, target_registration_hash=b"x" * 32),
            lambda word: replace(word, phase=settlement.RouterPhase.READY),
        )
        for substitute in substitutions:
            protocol, manager = migration_manager_fixture(seat=False)
            gate = protocol.migration_gate
            self.assertTrue(gate._arm_from_manager(
                1, 25, 26, b"m" * 32, b"r" * 32,
                caller=manager.address
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
            1, 25, 26, b"m" * 32, b"r" * 32,
            caller=manager.address
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
                canceled.target_registration_hash,
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
            target_registration_hash=b"r" * 32,
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
            "abort_response_wrong_target_registration",
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
                target_registration_hash=b"r" * 32,
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
        # Abort performs cleanup only; it never runs a same-transaction sync.
        self.assertIs(protocol.mode, settlement.Mode.NORMAL)
        self.assertEqual(
            protocol.seat_migration_abort.canceled_arm,
            protocol.seat_migration_arm.router_word,
        )

class ImmutableProtocolAuthorityV1Tests(unittest.TestCase):
    def test_seat_wire_cross_model_fixture_is_byte_exact(self):
        rows = settlement.canonical_seat_wire_cross_model_fixture_v1()
        decoders = {
            "MWV1": market.decode_market_wire_state_v1,
            "SMI1": market.decode_seat_mutation_intent_v1,
            "SLV1": market.decode_seat_lineup_wire_v1,
            "SIR1": market.decode_seat_install_record_v1,
            "SMR1": market.decode_seat_mutation_receipt_v1,
            "MEC1": market.decode_market_economic_receipt_v1,
            "MHS1": market.decode_market_history_safety_v1,
            "MRO1": market.decode_market_rotation_receipt_v1,
        }
        encoders = {
            "MWV1": market.encode_market_wire_state_v1,
            "SMI1": market.encode_seat_mutation_intent_v1,
            "SLV1": market.encode_seat_lineup_wire_v1,
            "SIR1": market.encode_seat_install_record_v1,
            "SMR1": market.encode_seat_mutation_receipt_v1,
            "MEC1": market.encode_market_economic_receipt_v1,
            "MHS1": market.encode_market_history_safety_v1,
            "MRO1": market.encode_market_rotation_receipt_v1,
        }
        for name, raw in rows.items():
            self.assertEqual(encoders[name](decoders[name](raw)), raw)

    def test_execution_profile_v2_strict_abi_rejection_corpus(self):
        profile = settlement.canonical_execution_profile_cross_model_fixture_v2()
        self.assertEqual(len(profile), 8_672)
        self.assertEqual(profile[:32], (32).to_bytes(32, "big"))
        self.assertEqual(
            profile[(1 + settlement.EXECUTION_PROFILE_VALUE_WORDS) * 32:
                    (2 + settlement.EXECUTION_PROFILE_VALUE_WORDS) * 32],
            settlement.EXECUTION_PROFILE_STATIC_BYTES.to_bytes(32, "big"),
        )
        self.assertEqual(
            settlement._execution_profile_abi_words_v2(profile)[0],
            (2).to_bytes(32, "big"),
        )
        words = settlement._execution_profile_abi_words_v2(profile)
        history_address = bytes(12) + bytes.fromhex(
            settlement.L1_EIP2935_HISTORY_STORAGE_ADDRESS[2:]
        )
        self.assertEqual(words[57], history_address)
        self.assertEqual(
            int.from_bytes(words[244], "big"),
            settlement.L1_EIP2935_FIRST_SUPPORTED_BLOCK,
        )
        self.assertEqual(
            words[46], settlement.settlement_factory_configuration_hash_v2()
        )
        self.assertEqual(
            words[44], bytes(12) + bytes.fromhex(
                settlement.SETTLEMENT_FACTORY_ADDRESS_V2[2:]
            )
        )
        self.assertEqual(
            words[45], settlement.SETTLEMENT_FACTORY_RUNTIME_HASH_V2
        )
        self.assertEqual(
            words[37],
            settlement.aggregator_seat_market_configuration_hash_v2(words),
        )
        self.assertEqual(
            words[205],
            settlement.source_bundle_salt_v1(
                words[9], int.from_bytes(words[1], "big")
            ),
        )
        self.assertEqual(
            words[209],
            bytes(12) + settlement._model_address20(
                settlement.LEGACY_V1_SOURCE_BRIDGE
            ),
        )
        self.assertEqual(
            words[58], settlement.L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
        )
        self.assertEqual(
            words[245], settlement.L2_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
        )
        self.assertEqual(
            words[59], settlement.eip2935_read_configuration_hash_v1(
                settlement.L1_EIP2935_FIRST_SUPPORTED_BLOCK
            )
        )
        self.assertEqual(
            int.from_bytes(words[246], "big"),
            settlement.L2_EIP2935_HISTORY_STORAGE_ACTIVATION_BLOCK,
        )
        for legacy in (
            bytes.fromhex("a1617601"),
            bytes.fromhex("a4000101400241000380"),
        ):
            with self.assertRaises(ValueError):
                settlement._execution_profile_abi_words_v2(legacy)

        mutations = []
        def changed(offset, value):
            candidate = bytearray(profile)
            candidate[offset] ^= value
            mutations.append(bytes(candidate))
        changed(31, 1)  # outer root
        changed((1 + settlement.EXECUTION_PROFILE_VALUE_WORDS) * 32 + 31, 1)
        changed(32, 1)  # uint64 dirty high padding
        changed((1 + 16) * 32, 1)  # address dirty high padding
        changed((1 + 6) * 32 + 31, 1)  # bytes4 dirty low padding
        zero_hash = bytearray(profile)
        zero_hash[(1 + 4) * 32:(2 + 4) * 32] = bytes(32)
        mutations.append(bytes(zero_hash))
        changed((1 + 55) * 32 + 31, 1)  # immutable refs
        changed((1 + 44) * 32 + 31, 1)  # fixed factory address
        changed((1 + 45) * 32 + 31, 1)  # fixed factory runtime
        changed((1 + 46) * 32 + 31, 1)  # fixed factory configuration
        changed((1 + 37) * 32 + 31, 1)  # immutable Market Router binding
        changed((1 + 205) * 32 + 31, 1)  # version-derived source bundle salt
        changed((1 + 209) * 32 + 31, 1)  # migration-root V1 Bridge
        for eip2935_word in (57, 58, 59, 244, 245, 246):
            changed((1 + eip2935_word) * 32 + 31, 1)
        dirty_first_supported = bytearray(profile)
        dirty_first_supported[(1 + 244) * 32] = 1
        mutations.append(bytes(dirty_first_supported))
        changed((1 + 111) * 32 + 31, 1)  # fixed component getter gas
        changed((1 + 114) * 32 + 31, 1)  # duplicated gas authority
        changed((1 + 118) * 32 + 31, 1)  # fixed geometry/hash
        changed(len(profile) - 1, 1)  # dynamic tail padding
        for candidate in mutations:
            with self.subTest(offset=next(
                    i for i, (left, right) in enumerate(zip(profile, candidate))
                    if left != right)):
                with self.assertRaises(ValueError):
                    settlement._execution_profile_abi_words_v2(candidate)

        # L1 first-supported and L2 activation are independent uint64 fields.
        first_supported_two = bytearray(profile)
        first_supported_two[(1 + 244) * 32:(2 + 244) * 32] = \
            (2).to_bytes(32, "big")
        with self.assertRaises(ValueError):
            settlement._execution_profile_abi_words_v2(
                bytes(first_supported_two)
            )
        first_supported_two[(1 + 59) * 32:(2 + 59) * 32] = \
            settlement.eip2935_read_configuration_hash_v1(2)
        self.assertEqual(
            int.from_bytes(
                settlement._execution_profile_abi_words_v2(
                    bytes(first_supported_two)
                )[244], "big"
            ), 2,
        )
        l2_activation_two = bytearray(profile)
        l2_activation_two[(1 + 7) * 32:(2 + 7) * 32] = \
            (2).to_bytes(32, "big")
        l2_activation_two[(1 + 246) * 32:(2 + 246) * 32] = \
            (2).to_bytes(32, "big")
        self.assertEqual(
            int.from_bytes(
                settlement._execution_profile_abi_words_v2(
                    bytes(l2_activation_two)
                )[246], "big"
            ), 2,
        )
        invalid_l2_activation = bytearray(profile)
        invalid_l2_activation[(1 + 246) * 32:(2 + 246) * 32] = \
            (2).to_bytes(32, "big")
        with self.assertRaises(ValueError):
            settlement._execution_profile_abi_words_v2(
                bytes(invalid_l2_activation)
            )

    def test_l1_history_boundary_is_bound_to_the_runtime_consumer(self):
        profile = replace(
            settlement.execution_profile_for_test(
                1, "profile:history-boundary:2"
            ),
            l1_history_first_supported_block=2,
        )
        words = settlement._execution_profile_abi_words_v2(
            profile.canonical_profile_bytes
        )
        self.assertEqual(int.from_bytes(words[244], "big"), 2)
        self.assertEqual(
            words[59], settlement.eip2935_read_configuration_hash_v1(2)
        )

        def target(oracle):
            protocol = settlement.protocol(
                seat=False, header_oracle=oracle,
                settlement_address="history-boundary-target",
            )
            return settlement.VersionedSettlementHistory(
                protocol.settlement_address,
                "runtime:history-boundary",
                1,
                profile.execution_profile_hash,
                copy.deepcopy(protocol.core),
                protocol.canonical.canonicalized_at_block,
                protocol.forced_queue,
                execution_profile=profile,
                migration_gate=protocol.migration_gate,
                live_protocol=protocol,
                inbox_apply_descriptor=protocol.inbox_apply_descriptor,
                header_oracle=oracle,
            )

        with self.assertRaises(ValueError):
            target(settlement.make_header_oracle(first_supported_block=1))
        exact_oracle = settlement.make_header_oracle(first_supported_block=2)
        history = target(exact_oracle)
        self.assertIs(history.header_oracle, exact_oracle)
        self.assertEqual(
            history.execution_profile.l1_history_first_supported_block, 2
        )

    def _execute_release(self, fixture, *, fault=None):
        (_rows, _router, _witness, payload, manager, timelock,
         _market, _oracle, clock) = fixture
        manager.fault_point = fault
        operation_id = timelock.queue_protocol_change_v1(
            settlement.REGISTER_RELEASE, payload,
            caller=timelock.dao_proposer, clock=clock,
        )
        self.assertIsNotNone(operation_id)
        mature = settlement.Clock(
            clock.block_number + 1,
            clock.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        return operation_id, mature, timelock.execute_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=addr("permissionless"), clock=mature,
        )

    def _queue_genesis_publication(self, fixture):
        release_operation, mature, released = self._execute_release(fixture)
        self.assertTrue(released)
        self.assertEqual(fixture[5].operations[release_operation].state, 4)
        witness, timelock = fixture[2], fixture[5]
        decoded = settlement.decode_register_release_payload_v1(fixture[3])
        publication_clock = settlement.Clock(
            1_000,
            mature.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        values = dict(
            force_cutoff_block=1_064,
            proposal_cutoff_block=1_128,
            quiesce_not_before_block=1_320,
            resume_by_block=1_450,
            resume_by_timestamp=publication_clock.timestamp + 7_200,
            review_finalized_by_block=1_000,
            target_settlement="0x" + decoded.target_address.hex(),
            target_protocol_version=decoded.protocol_version,
            target_manifest_hash=decoded.release_manifest_hash,
            target_registration_hash=decoded.target_registration_hash,
        )
        payload = settlement.encode_publish_genesis_campaign_payload_v1(
            **values
        )
        operation_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_GENESIS_CAMPAIGN, payload,
            caller=timelock.dao_proposer, clock=mature,
        )
        self.assertIsNotNone(operation_id)
        return payload, operation_id, publication_clock, values

    def test_pvm_genesis_publication_exact_lgp1_lgc1_and_reentry_guards(self):
        fixture = genesis_protocol_authority_fixture()
        router, manager, timelock = fixture[1], fixture[4], fixture[5]
        payload, operation_id, publication_clock, values = \
            self._queue_genesis_publication(fixture)
        observations = []

        def adversarial_callback(callback_router, callback_manager):
            observations.append((
                callback_router.migration_lifecycle,
                callback_manager.lifecycle,
                timelock.execute_protocol_change_v1(
                    2, settlement.PUBLISH_GENESIS_CAMPAIGN, payload,
                    caller=addr("reentrant-executor"),
                    clock=publication_clock,
                ),
                timelock.cancel_protocol_change_v1(
                    2, settlement.PUBLISH_GENESIS_CAMPAIGN, payload,
                    caller=timelock.dao_proposer,
                ),
            ))

        router.genesis_publication_callback = adversarial_callback
        self.assertTrue(timelock.execute_protocol_change_v1(
            2, settlement.PUBLISH_GENESIS_CAMPAIGN, payload,
            caller=addr("gen-publisher"), clock=publication_clock,
        ))
        self.assertEqual(
            settlement.PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR.hex(),
            "5f0ed7f5",
        )
        self.assertEqual(observations, [(
            settlement.RouterMigrationLifecycle.PUBLISHING,
            "APPLYING", False, False,
        )])
        state_raw = router.genesis_campaign_state_return_v1()
        self.assertEqual(len(state_raw), 512)
        state = settlement.decode_genesis_campaign_v1(state_raw)
        campaign = router.genesis_campaign
        self.assertEqual(state, settlement.genesis_campaign_state_v1(campaign))
        expected_review = settlement.legacy_genesis_review_commitment_v1(
            router.legacy_launch_hook.deployment_hash,
            router.legacy_launch_hook.legacy_resume_profile_hash,
            values["target_protocol_version"],
            values["target_manifest_hash"],
            values["target_registration_hash"],
        )
        self.assertEqual(state.review_commitment, expected_review)
        self.assertEqual(state.nonce, 1)
        self.assertEqual(state.generation, 1)
        self.assertEqual(
            state.campaign_id,
            settlement.legacy_genesis_campaign_id_v1(
                router.legacy_launch_hook.deployment_hash,
                state.nonce, state.generation,
                values["review_finalized_by_block"],
                values["force_cutoff_block"],
                values["proposal_cutoff_block"],
                values["quiesce_not_before_block"],
                values["resume_by_block"],
                values["resume_by_timestamp"],
                values["target_settlement"],
                values["target_protocol_version"],
                values["target_manifest_hash"],
                values["target_registration_hash"], expected_review,
            ),
        )
        self.assertEqual(timelock.operations[operation_id].state, 4)
        self.assertEqual(manager.generation, 1)
        self.assertEqual(manager.lifecycle, "IDLE")
        self.assertIs(router.migration_lifecycle,
                      settlement.RouterMigrationLifecycle.IDLE)

        before = router.genesis_campaign_state_return_v1()
        self.assertFalse(router.withdraw_genesis_campaign_v1(
            state.campaign_id,
            target_address=state.target_address,
            target_registration_hash=state.target_registration_hash,
            cancellation_commitment=b"c" * 32,
            cancellation_finalized_by_block=state.review_finalized_by_block,
            caller=router.version_manager, clock=publication_clock,
        ))
        self.assertEqual(router.genesis_campaign_state_return_v1(), before)

    def test_pvm_genesis_publication_faults_substitution_and_gas_roll_back(self):
        scenarios = (
            ("router_fault", "genesis_after_lifecycle"),
            ("router_fault", "genesis_after_campaign"),
            ("router_fault", "genesis_before_idle"),
            ("router_fault", "genesis_after_idle"),
            ("pvm_fault", "after_genesis_router"),
            ("pvm_fault", "before_idle"),
            ("return", b""),
            ("postread", b""),
            ("callback_fault", None),
            ("gas", 7_999_999),
        )
        for kind, value in scenarios:
            with self.subTest(kind=kind, value=value):
                fixture = genesis_protocol_authority_fixture()
                router, manager, timelock = fixture[1], fixture[4], fixture[5]
                payload, operation_id, publication_clock, _ = \
                    self._queue_genesis_publication(fixture)
                if kind == "router_fault":
                    router.release_registration_fault_point = value
                elif kind == "pvm_fault":
                    manager.fault_point = value
                elif kind == "return":
                    router.genesis_publication_return_override = value
                elif kind == "postread":
                    manager.genesis_postread_override = value
                elif kind == "callback_fault":
                    router.genesis_publication_callback = lambda *_: (
                        (_ for _ in ()).throw(RuntimeError("callback fault"))
                    )
                else:
                    manager.genesis_router_call_gas_limit = value
                self.assertFalse(timelock.execute_protocol_change_v1(
                    2, settlement.PUBLISH_GENESIS_CAMPAIGN, payload,
                    caller=addr("gen-publisher"),
                    clock=publication_clock,
                ))
                self.assertEqual(timelock.operations[operation_id].state, 1)
                self.assertIsNone(router.genesis_campaign)
                self.assertEqual(router.genesis_campaign_nonce, 0)
                self.assertIsNone(manager.published_genesis_campaign)
                self.assertEqual(manager.generation, 0)
                self.assertEqual(manager.lifecycle, "IDLE")
                self.assertIs(
                    router.migration_lifecycle,
                    settlement.RouterMigrationLifecycle.IDLE,
                )
                self.assertIs(
                    router.legacy_launch_hook.phase,
                    settlement.LegacyLaunchPhase.ACTIVE,
                )

        substituted = genesis_protocol_authority_fixture()
        payload, operation_id, publication_clock, _ = \
            self._queue_genesis_publication(substituted)
        changed = bytearray(payload)
        changed[-1] ^= 1
        changed = bytes(changed)
        substituted_operation = substituted[5].queue_protocol_change_v1(
            settlement.PUBLISH_GENESIS_CAMPAIGN, changed,
            caller=substituted[5].dao_proposer,
            clock=settlement.Clock(
                publication_clock.block_number - 1,
                publication_clock.timestamp
                    - settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
            ),
        )
        self.assertIsNotNone(substituted_operation)
        self.assertFalse(substituted[5].execute_protocol_change_v1(
            3, settlement.PUBLISH_GENESIS_CAMPAIGN, changed,
            caller=addr("substituter"), clock=publication_clock,
        ))
        self.assertEqual(substituted[5].operations[substituted_operation].state,
                         1)
        self.assertIsNone(substituted[1].genesis_campaign)

    def test_register_release_exact_geometry_and_atomic_postreads(self):
        fixture = protocol_authority_fixture()
        (rows, router, witness, payload, manager, timelock,
         market_authority, _oracle, clock) = fixture
        decoded = settlement.decode_register_release_payload_v1(payload)
        derived = settlement.derive_register_release_authority_v2(
            decoded.profile_bytes,
            decoded.expected_predecessor_protocol_version,
        )
        self.assertEqual(payload[67 * 32:68 * 32], (0x880).to_bytes(32, "big"))
        self.assertEqual(
            len(payload),
            2_208 + ((len(decoded.profile_bytes) + 31) // 32) * 32,
        )
        self.assertEqual(
            decoded.target_registration_hash,
            derived.target_registration_hash,
        )
        self.assertEqual(
            decoded.migration_activation_profile_record_hash,
            derived.migration_activation_profile
                .activation_profile_record_hash,
        )
        operation_id = timelock.queue_protocol_change_v1(
            settlement.REGISTER_RELEASE, payload,
            caller=timelock.dao_proposer, clock=clock,
        )
        self.assertIsNotNone(operation_id)
        self.assertFalse(timelock.execute_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=addr("early"), clock=clock,
        ))
        mature = settlement.Clock(
            clock.block_number + 1,
            clock.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=addr("permissionless"), clock=mature,
        ))
        version = witness.settlement.protocol_version
        self.assertEqual(len(router.target_release_registration_v2(version)), 416)
        self.assertEqual(len(router.migration_activation_profile_v2(version)), 768)
        self.assertEqual(len(manager.profile_ingress_root_v2(version)), 128)
        root, ids = manager.profile_ingress_roots[version]
        self.assertEqual(root, derived.ingress_authorization_root)
        self.assertEqual(len(ids), 2)
        self.assertEqual(tuple(ids), tuple(sorted(ids)))
        self.assertTrue(all(
            len(manager.profile_ingress_authorization_v2(item)) == 800
            for item in ids
        ))
        seat_market = rows[3]
        self.assertFalse(market_authority.authorizations)
        self.assertEqual(len(seat_market.authorizations), 2)
        self.assertEqual(len(rows[5].authorizations), 1)
        self.assertEqual(
            market_authority.authority_configuration_hash,
            settlement.aggregator_seat_market_configuration_hash_v2(
                derived.profile_words
            ),
        )
        with self.assertRaises(AttributeError):
            market_authority.active_settlement_router = addr("replacement-router")
        authorization_id = next(
            item for item in seat_market.authorizations if item != rows[6]
        )
        self.assertEqual(
            len(market_authority.settlement_authorization_v1(
                authorization_id
            )), 256,
        )
        self.assertEqual(timelock.operations[operation_id].state, 4)
        self.assertEqual(manager.lifecycle, "IDLE")
        self.assertIs(router.migration_lifecycle,
                      settlement.RouterMigrationLifecycle.IDLE)

        registry = router._bridge_domain_registry_authority
        self.assertIsInstance(registry, settlement.BridgeDomainRegistry)
        version_word = settlement._model_uint(
            version, 32, "test route protocol version"
        )
        retry_clock = settlement.Clock(
            mature.block_number + 10, mature.timestamp + 10
        )
        package_before = registry._transaction_snapshot()
        brd = router.prepare_bridge_route_package_v1(
            settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
            caller=addr("package-preparer"), value=0,
            gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
            clock=retry_clock,
        )
        self.assertEqual((len(brd), brd[:32]), (128, b"BRD1" + bytes(28)))
        self.assertEqual(registry._transaction_snapshot(), package_before)
        entry = next(
            row for row in registry.entries.values()
            if row.protocol_version == version
        )
        self.assertEqual(brd[64:96], entry.package_root)
        self.assertEqual(
            int.from_bytes(brd[96:128], "big"),
            entry.staged_at_block
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
        )
        with self.assertRaises(ValueError):
            registry.stage_bridge_route_package_v1(
                settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=router.address, value=0,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            )
        brp_call = (
            settlement.BRIDGE_ROUTE_PACKAGE_SELECTOR
            + settlement._model_uint(
                witness.release_manifest.destination_chain_id,
                32, "test BRP1 destination chain",
            )
            + version_word
        )
        brp = registry.bridge_route_package_v1(
            brp_call, caller=addr("observer"), value=0,
            gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
            clock=retry_clock,
        )
        self.assertEqual((len(brp), brp[:32]), (480, b"BRP1" + bytes(28)))
        self.assertEqual(brp[160:192], brd[96:128])

        rtr_call = (
            settlement.TARGET_RELEASE_REGISTRATION_SELECTOR + version_word
        )
        rtr = router.staticcall_target_release_registration_v2(
            rtr_call, caller=registry.address, value=0,
            gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS,
        )
        self.assertEqual((len(rtr), rtr[:32]), (416, b"RTR2" + bytes(28)))
        self.assertEqual(
            settlement.decode_target_release_registration_return_v2(rtr),
            router.target_release_registrations_v2[version],
        )
        for invoke in (
            lambda: router.staticcall_target_release_registration_v2(
                b"bad!" + version_word, caller=registry.address, value=0,
                gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS,
            ),
            lambda: router.staticcall_target_release_registration_v2(
                rtr_call + b"\x00", caller=registry.address, value=0,
                gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS,
            ),
            lambda: router.staticcall_target_release_registration_v2(
                settlement.TARGET_RELEASE_REGISTRATION_SELECTOR
                    + bytes([1]) + version_word[1:],
                caller=registry.address, value=0,
                gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS,
            ),
            lambda: router.staticcall_target_release_registration_v2(
                rtr_call, caller=registry.address, value=1,
                gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS,
            ),
            lambda: router.staticcall_target_release_registration_v2(
                rtr_call, caller=registry.address, value=0,
                gas=settlement.TARGET_RELEASE_REGISTRATION_READ_GAS - 1,
            ),
        ):
            with self.assertRaises(ValueError):
                invoke()

        bad_rtr_magic = bytearray(rtr)
        bad_rtr_magic[0] ^= 1
        bad_rtr_integer_padding = bytearray(rtr)
        bad_rtr_integer_padding[32] = 1
        bad_rtr_address_padding = bytearray(rtr)
        bad_rtr_address_padding[96] = 1
        for malformed in (
            rtr[:-1], rtr + b"\x00", bytes(bad_rtr_magic),
            bytes(bad_rtr_integer_padding), bytes(bad_rtr_address_padding),
        ):
            before = registry._transaction_snapshot()
            router.release_registration_getter_override = malformed
            with self.assertRaises(ValueError):
                router.prepare_bridge_route_package_v1(
                    settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR
                        + version_word,
                    caller=addr("preparer"), value=0,
                    gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                    clock=retry_clock,
                )
            self.assertEqual(registry._transaction_snapshot(), before)
        router.release_registration_getter_override = None
        for fault in ("revert", "oog"):
            before = registry._transaction_snapshot()
            router.release_registration_getter_fault_point = fault
            with self.assertRaises(RuntimeError):
                router.prepare_bridge_route_package_v1(
                    settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR
                        + version_word,
                    caller=addr("preparer"), value=0,
                    gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                    clock=retry_clock,
                )
            self.assertEqual(registry._transaction_snapshot(), before)
        router.release_registration_getter_fault_point = None

        brc_call = (
            settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_SELECTOR
            + version_word + settlement.target_registration_hash_v2(witness)
        )
        for invoke in (
            lambda: router.prepare_bridge_route_package_v1(
                settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller="", value=0,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: registry.stage_bridge_route_package_v1(
                settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=addr("not-router"), value=0,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: registry.bridge_route_package_v1(
                brp_call + b"\x00", caller=addr("observer"), value=0,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                brc_call, caller=router.address, value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=retry_clock,
            ),
        ):
            before = registry._transaction_snapshot()
            with self.assertRaises(ValueError):
                invoke()
            self.assertEqual(registry._transaction_snapshot(), before)

        # Every executable envelope rejects wrong selector/length/padding,
        # caller, value or gas before a package write.
        dirty_version = bytes([1]) + version_word[1:]
        bad_envelopes = (
            lambda: router.prepare_bridge_route_package_v1(
                b"bad!" + version_word, caller=addr("preparer"), value=0,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: router.prepare_bridge_route_package_v1(
                settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR
                    + dirty_version,
                caller=addr("preparer"), value=0,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: router.prepare_bridge_route_package_v1(
                settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=addr("preparer"), value=1,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: router.prepare_bridge_route_package_v1(
                settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=addr("preparer"), value=0,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS - 1,
                clock=retry_clock,
            ),
            lambda: registry.stage_bridge_route_package_v1(
                b"bad!" + version_word, caller=router.address, value=0,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: registry.stage_bridge_route_package_v1(
                settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + dirty_version,
                caller=router.address, value=0,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: registry.stage_bridge_route_package_v1(
                settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=router.address, value=1,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            ),
            lambda: registry.stage_bridge_route_package_v1(
                settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=router.address, value=0,
                gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS - 1,
                clock=retry_clock,
            ),
            lambda: registry.bridge_route_package_v1(
                b"bad!" + brp_call[4:], caller=addr("observer"), value=0,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                clock=retry_clock,
            ),
            lambda: registry.bridge_route_package_v1(
                brp_call[:-32] + dirty_version,
                caller=addr("observer"), value=0,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                clock=retry_clock,
            ),
            lambda: registry.bridge_route_package_v1(
                brp_call, caller=addr("observer"), value=1,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                clock=retry_clock,
            ),
            lambda: registry.bridge_route_package_v1(
                brp_call, caller=addr("observer"), value=0,
                gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS - 1,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                b"bad!" + brc_call[4:], caller=router.address, value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_SELECTOR
                    + dirty_version + brc_call[36:],
                caller=router.address, value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                brc_call, caller=addr("not-router"), value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                brc_call, caller=router.address, value=1,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=retry_clock,
            ),
            lambda: registry.consume_bridge_route_arm_ready_v1(
                brc_call, caller=router.address, value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS - 1,
                clock=retry_clock,
            ),
        )
        for index, invoke in enumerate(bad_envelopes):
            with self.subTest(bad_bridge_envelope=index):
                before = registry._transaction_snapshot()
                with self.assertRaises(ValueError):
                    invoke()
                self.assertEqual(registry._transaction_snapshot(), before)

        router_package_before = router._bridge_package_snapshot_v1()
        router.prepare_bridge_route_fault_point = "after_stage"
        with self.assertRaises(RuntimeError):
            router.prepare_bridge_route_package_v1(
                settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                caller=addr("preparer"), value=0,
                gas=settlement.PREPARE_BRIDGE_ROUTE_PACKAGE_GAS,
                clock=retry_clock,
            )
        router.prepare_bridge_route_fault_point = None
        self.assertEqual(
            router._bridge_package_snapshot_v1(), router_package_before
        )
        for attribute, call in (
            ("stage_bridge_route_fault_point", lambda: (
                registry.stage_bridge_route_package_v1(
                    settlement.STAGE_BRIDGE_ROUTE_PACKAGE_SELECTOR + version_word,
                    caller=router.address, value=0,
                    gas=settlement.STAGE_BRIDGE_ROUTE_PACKAGE_GAS,
                    clock=retry_clock,
                )
            )),
            ("bridge_route_package_fault_point", lambda: (
                registry.bridge_route_package_v1(
                    brp_call, caller=addr("observer"), value=0,
                    gas=settlement.BRIDGE_ROUTE_PACKAGE_READ_GAS,
                    clock=retry_clock,
                )
            )),
            ("consume_bridge_route_fault_point", lambda: (
                registry.consume_bridge_route_arm_ready_v1(
                    brc_call, caller=router.address, value=0,
                    gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                    clock=retry_clock,
                )
            )),
        ):
            before = registry._transaction_snapshot()
            setattr(registry, attribute, "revert")
            with self.assertRaises(RuntimeError):
                call()
            setattr(registry, attribute, None)
            self.assertEqual(registry._transaction_snapshot(), before)

        # BRC1 authorization is the ordered public MACT+ASR1+RTR2 join, not a
        # Python-only capability.  Model the activation transaction's
        # already-written target registration and exact Router returndata,
        # then consume once.  The nonzero context hash is an opaque
        # Router-issued full-frame correlation value; the independently
        # checkable source/generation/target authorization is the ASR1 join.
        source_registration = router.registrations[router.active_version]
        activation_view = settlement.encode_migration_activation_context_v1(
            settlement.MigrationActivationContextStateV1(
                settlement.RouterMigrationLifecycle.ACTIVATING,
                b"a" * 32,
                settlement._model_address20(
                    source_registration.settlement.address
                ),
                settlement._model_address20(witness.settlement.address),
                1,
                router.active_version,
                version,
                witness.release_manifest_hash,
                settlement.target_registration_hash_v2(witness),
            )
        )
        activation_state = settlement.encode_active_settlement_state_v1(
            settlement.ActiveSettlementStateV1(
                settlement._model_address20(
                    source_registration.settlement.address
                ),
                1,
                router.active_version,
                version,
                witness.release_manifest_hash,
                settlement.target_registration_hash_v2(witness),
                settlement.RouterPhase.READY,
            )
        )
        prior_target = router.registrations.get(version)
        consumed_before = registry._transaction_snapshot()
        router.registrations[version] = witness
        router.migration_activation_context_return_override = activation_view
        router.active_settlement_state_return_override = activation_state
        consume_clock = settlement.Clock(
            mature.block_number + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            mature.timestamp + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
        )
        try:
            for attribute in (
                "migration_activation_context_fault_point",
                "active_settlement_state_fault_point",
                "release_registration_getter_fault_point",
            ):
                before = registry._transaction_snapshot()
                setattr(router, attribute, "oog")
                with self.assertRaises(RuntimeError):
                    registry.consume_bridge_route_arm_ready_v1(
                        brc_call, caller=router.address, value=0,
                        gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                        clock=consume_clock,
                    )
                setattr(router, attribute, None)
                self.assertEqual(registry._transaction_snapshot(), before)

            for malformed in (rtr[:-1], rtr + b"\x00",
                              bytes(bad_rtr_magic),
                              bytes(bad_rtr_integer_padding),
                              bytes(bad_rtr_address_padding)):
                before = registry._transaction_snapshot()
                router.release_registration_getter_override = malformed
                with self.assertRaises(ValueError):
                    registry.consume_bridge_route_arm_ready_v1(
                        brc_call, caller=router.address, value=0,
                        gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                        clock=consume_clock,
                    )
                self.assertEqual(registry._transaction_snapshot(), before)
            router.release_registration_getter_override = None

            for mismatched_state in (
                settlement.encode_migration_activation_context_v1(
                    settlement.MigrationActivationContextStateV1(
                        settlement.RouterMigrationLifecycle.ACTIVATING,
                        b"a" * 32,
                        settlement._model_address20(addr("wrong-source")),
                        settlement._model_address20(witness.settlement.address),
                        1, router.active_version, version,
                        witness.release_manifest_hash,
                        settlement.target_registration_hash_v2(witness),
                    )
                ),
                settlement.encode_migration_activation_context_v1(
                    settlement.MigrationActivationContextStateV1(
                        settlement.RouterMigrationLifecycle.ACTIVATING,
                        b"a" * 32,
                        settlement._model_address20(
                            source_registration.settlement.address
                        ),
                        settlement._model_address20(witness.settlement.address),
                        2, router.active_version, version,
                        witness.release_manifest_hash,
                        settlement.target_registration_hash_v2(witness),
                    )
                ),
            ):
                before = registry._transaction_snapshot()
                router.migration_activation_context_return_override = \
                    mismatched_state
                with self.assertRaises(ValueError):
                    registry.consume_bridge_route_arm_ready_v1(
                        brc_call, caller=router.address, value=0,
                        gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                        clock=consume_clock,
                    )
                self.assertEqual(registry._transaction_snapshot(), before)
            router.migration_activation_context_return_override = \
                activation_view

            brc = registry.consume_bridge_route_arm_ready_v1(
                brc_call, caller=router.address, value=0,
                gas=settlement.CONSUME_BRIDGE_ROUTE_ARM_READY_GAS,
                clock=consume_clock,
            )
            self.assertEqual(
                (len(brc), brc[:32]), (128, b"BRC1" + bytes(28))
            )
        finally:
            router.migration_activation_context_return_override = None
            router.active_settlement_state_return_override = None
            router.release_registration_getter_override = None
            router.migration_activation_context_fault_point = None
            router.active_settlement_state_fault_point = None
            router.release_registration_getter_fault_point = None
            if prior_target is None:
                router.registrations.pop(version, None)
            else:
                router.registrations[version] = prior_target
            registry._restore_transaction_snapshot(consumed_before)

    def test_register_release_malformed_payloads_and_late_faults_roll_back(self):
        fixture = protocol_authority_fixture()
        payload = fixture[3]
        malformed = []
        for candidate in (payload[:-1], payload + bytes(32)):
            malformed.append(candidate)
        wrong_offset = bytearray(payload)
        wrong_offset[67 * 32 + 31] ^= 1
        malformed.append(bytes(wrong_offset))
        wrong_padding = bytearray(payload)
        wrong_padding[-1] ^= 1
        malformed.append(bytes(wrong_padding))
        wrong_create2 = bytearray(payload)
        wrong_create2[64 * 32 + 31] ^= 1
        malformed.append(bytes(wrong_create2))
        for candidate in malformed:
            with self.subTest(length=len(candidate)):
                with self.assertRaises(ValueError):
                    settlement.decode_register_release_payload_v1(candidate)

        for fault in (
            "after_router_registration", "before_idle",
        ):
            with self.subTest(fault=fault):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                package_before = current[1]._bridge_package_snapshot_v1()
                operation_id, mature, success = self._execute_release(
                    current, fault=fault
                )
                self.assertFalse(success)
                router, manager, timelock, market = (
                    current[1], current[4], current[5], current[6]
                )
                self.assertEqual(
                    router.target_release_registrations_v2,
                    registrations_before,
                )
                self.assertFalse(router.migration_activation_profiles_v2)
                self.assertFalse(manager.profile_ingress_roots)
                self.assertFalse(manager.profile_ingress_rows)
                self.assertFalse(market.authorizations)
                target_version = current[2].settlement.protocol_version
                self.assertNotIn(
                    target_version, router._profile_deployments_by_version
                )
                self.assertNotIn(
                    target_version, router._source_descriptor_id_by_version
                )
                support = router._bridge_domain_registry_authority
                self.assertFalse(any(
                    entry.protocol_version == target_version
                    for entry in support.entries.values()
                ))
                self.assertEqual(
                    router._bridge_package_snapshot_v1(), package_before
                )
                self.assertEqual(timelock.operations[operation_id].state, 1)
                self.assertEqual(manager.lifecycle, "IDLE")
                if fault == "before_idle":
                    manager.fault_point = None
                    retry = settlement.Clock(
                        mature.block_number + 10, mature.timestamp + 1
                    )
                    self.assertTrue(timelock.execute_protocol_change_v1(
                        1,
                        settlement.REGISTER_RELEASE,
                        current[3],
                        caller=addr("release-retry"),
                        clock=retry,
                    ))
                    target_entry = next(
                        entry for entry in support.entries.values()
                        if entry.protocol_version == target_version
                    )
                    self.assertEqual(
                        target_entry.staged_at_block, retry.block_number
                    )

        for component, fault in (("router", "after_write"),
                                 ("market", "after_install")):
            with self.subTest(component=component):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                if component == "router":
                    current[1].release_registration_fault_point = fault
                else:
                    current[6].fault_point = fault
                operation_id, _mature, success = self._execute_release(current)
                self.assertFalse(success)
                self.assertEqual(
                    current[1].target_release_registrations_v2,
                    registrations_before,
                )
                self.assertFalse(current[6].authorizations)
        self._assert_register_release_live_deployment_world_is_exact_and_atomic()

    def _assert_register_release_live_deployment_world_is_exact_and_atomic(self):
        positive = protocol_authority_fixture()
        decoded_positive = settlement.decode_register_release_payload_v1(
            positive[3]
        )
        settlement_derived = settlement.derive_register_release_authority_v2(
            decoded_positive.profile_bytes,
            decoded_positive.expected_predecessor_protocol_version,
        )
        commitment_derived = commitment.derive_register_release_authority_v2(
            decoded_positive.profile_bytes,
            decoded_positive.expected_predecessor_protocol_version,
        )
        self.assertEqual(
            settlement_derived.bridge_route_expansion,
            commitment_derived.bridge_route_expansion,
        )
        self.assertEqual(
            settlement_derived.bridge_invocation_policy,
            commitment_derived.bridge_invocation_policy,
        )
        self.assertEqual(
            settlement_derived.bridge_route_expansion_hash,
            commitment_derived.bridge_route_expansion_hash,
        )
        self.assertEqual(
            settlement_derived.target_registration_hash,
            commitment_derived.target_registration_hash,
        )
        commitment_inventory = commitment.target_constructor_inventory_v2(
            decoded_positive.profile_bytes, commitment_derived
        )
        settlement_inventory = settlement.target_constructor_inventory_v2(
            decoded_positive.profile_bytes,
            settlement_derived.execution_profile_hash,
            settlement_derived.migration_activation_profile
                .activation_profile_record_hash,
            settlement_derived.data_session_configuration_hash,
            settlement_derived.target_configuration_hash,
        )
        self.assertEqual(commitment_inventory, settlement_inventory)
        settlement_constructor = \
            settlement.encode_target_constructor_state_return_v2(
                settlement.target_constructor_poststate_commitment_v2(
                    settlement_inventory
                ),
                settlement_derived.target_configuration_hash,
            )
        commitment_constructor = \
            commitment.encode_target_constructor_state_return_v2(
                commitment.target_constructor_poststate_commitment_v2(
                    commitment_inventory
                ),
                commitment_derived.settlement_deployment_descriptor
                    .target_configuration_hash,
            )
        self.assertEqual(settlement_constructor, commitment_constructor)
        settlement_accounting = settlement.encode_data_session_accounting_v1(
            settlement.DataSessionAccountingV1(
                0, 0, 0, 0, 0, 0, 0, 0, 0, False,
                settlement_derived.data_session_configuration_hash,
            )
        )
        commitment_accounting = \
            commitment.encode_empty_data_session_accounting_v1(
                commitment_derived.data_session_configuration_hash
            )
        self.assertEqual(settlement_accounting, commitment_accounting)
        self.assertEqual(
            settlement.SETTLEMENT_FACTORY_DEPLOY_SELECTOR,
            commitment.SETTLEMENT_FACTORY_DEPLOY_SELECTOR,
        )
        self.assertEqual(
            settlement.validate_live_register_release_deployment_v2(
                settlement.live_deployment_world_for_release_v2(
                    settlement_derived
                ), settlement_derived,
                decoded_positive.profile_bytes, caller=positive[4].address,
            ),
            commitment.live_registration_validation_commitment_v2(
                commitment_derived, commitment_accounting,
                commitment_constructor,
            ),
        )
        self.assertTrue(self._execute_release(positive)[2])
        manager, router = positive[4], positive[1]
        self.assertEqual(
            positive[6].authorization_id_by_target,
            {
                row.target: authorization_id
                for authorization_id, row in positive[6].authorizations.items()
            },
        )
        self.assertNotIn(
            "expected_router_registration",
            inspect.signature(
                positive[6].install_settlement_authorization_v1
            ).parameters,
        )
        self.assertEqual(positive[6].active_settlement_router, router.address)
        trace = manager.deployment_world.trace
        callers = tuple(row[0] for row in trace)
        self.assertEqual(callers[:25], (manager.address,) * 25)
        self.assertEqual(callers[25:50], (router.address,) * 25)
        self.assertEqual(callers[50:], (manager.address,) * 5)
        control_trace = tuple(
            f"control:{label}:{surface}"
            for label in (
                "Router", "ForcedQueue", "BuilderRegistry",
                "ScheduleOracle", "BridgeDomainRegistry",
                "BridgeCreditRegistry",
            )
            for surface in ("account", "extcodehash", "config")
        )
        deployment_trace = (
            "factory:account", "factory:extcodehash",
            "target:account", "target:extcodehash", "target:config",
            "target:data-session-accounting", "target:constructor-state",
        )
        self.assertEqual(
            tuple(row[1] for row in trace),
            control_trace + deployment_trace + control_trace
            + deployment_trace + (
                "target-postread:account", "target-postread:extcodehash",
                "target-postread:config",
                "target-postread:data-session-accounting",
                "target-postread:constructor-state",
            ),
        )

        def assert_rejected(mutate):
            current = protocol_authority_fixture()
            registrations_before = copy.deepcopy(
                current[1].target_release_registrations_v2
            )
            decoded = settlement.decode_register_release_payload_v1(current[3])
            derived = settlement.derive_register_release_authority_v2(
                decoded.profile_bytes,
                decoded.expected_predecessor_protocol_version,
            )
            mutate(current, derived)
            operation_id, _mature, success = self._execute_release(current)
            self.assertFalse(success)
            self.assertEqual(
                current[1].target_release_registrations_v2,
                registrations_before,
            )
            self.assertFalse(current[1].migration_activation_profiles_v2)
            self.assertFalse(current[4].profile_ingress_rows)
            self.assertFalse(current[6].authorizations)
            self.assertFalse(current[6].authorization_id_by_target)
            self.assertEqual(current[5].operations[operation_id].state, 1)
            self.assertEqual(current[4].lifecycle, "IDLE")

        def account(current, derived, address):
            return current[4].deployment_world.accounts[address]

        mutations = (
            lambda current, derived: current[4].deployment_world.accounts.pop(
                derived.profile_words[44][12:]
            ),
            lambda current, derived: setattr(
                account(current, derived, derived.profile_words[44][12:]),
                "runtime_hash", b"x" * 32,
            ),
            lambda current, derived: setattr(
                account(current, derived, derived.target_address),
                "runtime_hash", b"x" * 32,
            ),
            lambda current, derived: setattr(
                account(current, derived, derived.target_address),
                "configuration_hash", b"c" * 32,
            ),
            lambda current, derived: setattr(
                account(current, derived, derived.target_address),
                "accounting",
                replace(
                    account(current, derived, derived.target_address).accounting,
                    live_count=1,
                ),
            ),
            lambda current, derived: setattr(
                account(current, derived, derived.target_address),
                "constructor_inventory",
                (b"\x01" * 32,)
                + account(current, derived, derived.target_address)
                    .constructor_inventory[1:],
            ),
            lambda current, derived: account(
                current, derived, derived.target_address
            ).overrides.__setitem__(
                (current[4].address, "data_session_accounting"), b"x" * 383
            ),
            lambda current, derived: account(
                current, derived, derived.target_address
            ).overrides.__setitem__(
                (current[4].address, "target_constructor_state"), b"x" * 95
            ),
            lambda current, derived: account(
                current, derived, derived.target_address
            ).overrides.__setitem__(
                (current[1].address, "target_constructor_state"), b"x" * 97
            ),
            lambda current, derived: account(
                current, derived, derived.target_address
            ).faults.add((current[4].address, "extcodehash")),
            lambda current, derived: current[4].deployment_world.accounts.pop(
                derived.profile_words[23][12:]
            ),
            lambda current, derived: account(
                current, derived, derived.profile_words[26][12:]
            ).overrides.__setitem__(
                (current[4].address, "extcodehash"), b"q" * 32
            ),
            lambda current, derived: account(
                current, derived, derived.profile_words[41][12:]
            ).overrides.__setitem__(
                (current[1].address, "component_config"), b"c" * 31
            ),
            lambda current, derived: object.__setattr__(
                current[1], "header_oracle",
                settlement.make_header_oracle(first_supported_block=2),
            ),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(live_world_mutation=index):
                assert_rejected(mutate)

        for caller_role, trailing in (("manager", False), ("router", True)):
            with self.subTest(pvm1_caller=caller_role, trailing=trailing):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                manager, router = current[4], current[1]
                caller = manager.address if caller_role == "manager" \
                    else router.address
                canonical = manager.config_return_v1()
                manager.config_return_overrides[caller] = (
                    canonical + bytes(32) if trailing else canonical[:-1]
                )
                operation_id, _mature, success = self._execute_release(current)
                self.assertFalse(success)
                self.assertEqual(
                    router.target_release_registrations_v2,
                    registrations_before,
                )
                self.assertFalse(manager.profile_ingress_rows)
                self.assertFalse(current[6].authorizations)
                self.assertEqual(current[5].operations[operation_id].state, 1)

        # ERC-2470 has no protocol-specific configuration getter.  Its root
        # identity is the exact address/runtime/artifact/deployer/tx tuple;
        # the target's component getter never accepts the deploy selector.
        selector_fixture = protocol_authority_fixture()
        selector_derived = settlement.derive_register_release_authority_v2(
            settlement.decode_register_release_payload_v1(
                selector_fixture[3]
            ).profile_bytes,
            0,
        )
        target_account = account(
            selector_fixture, selector_derived,
            selector_derived.target_address,
        )
        self.assertEqual(
            selector_derived.profile_words[44][12:].hex(),
            settlement.SETTLEMENT_FACTORY_ADDRESS_V2[2:].lower(),
        )
        self.assertEqual(
            selector_derived.profile_words[45],
            settlement.SETTLEMENT_FACTORY_RUNTIME_HASH_V2,
        )
        with self.assertRaises(ValueError):
            target_account.component_config_hash_v2(
                selector_fixture[4].address,
                settlement.SETTLEMENT_FACTORY_DEPLOY_SELECTOR, 50_000, 0,
            )

        # A lookalike Market deployment bound to a different Router cannot
        # consume an authentic row from the manager's Router.
        substituted_router = protocol_authority_fixture()
        registrations_before = copy.deepcopy(
            substituted_router[1].target_release_registrations_v2
        )
        original_market = substituted_router[6]
        wrong_market = settlement.PvmDerivedMarketAuthorizationV1(
            original_market.market_chain_id, original_market.address,
            original_market.protocol_version_manager,
            original_market.settlement_chain_id, addr("wrong-router"),
            original_market.runtime_hash,
            original_market.profile_configuration_hash,
        )
        substituted_router[4].market = wrong_market
        operation_id, _mature, success = self._execute_release(
            substituted_router
        )
        self.assertFalse(success)
        self.assertEqual(
            substituted_router[1].target_release_registrations_v2,
            registrations_before,
        )
        self.assertFalse(wrong_market.authorizations)
        self.assertEqual(
            substituted_router[5].operations[operation_id].state, 1
        )

        # Internal profile self-consistency is insufficient: even after every
        # downstream DAG hash is recomputed, a lookalike Market tuple must fail
        # the live PVM/Router/Market root join before any protocol write.
        profile_substitution = list(protocol_authority_fixture())
        registrations_before = copy.deepcopy(
            profile_substitution[1].target_release_registrations_v2
        )
        original = settlement.decode_register_release_payload_v1(
            profile_substitution[3]
        )
        candidate = bytearray(original.profile_bytes)
        alternate_market = addr("profile-lookalike")
        alternate_runtime = settlement.keccak256(b"lookalike-market-runtime")
        candidate[(1 + 35) * 32:(2 + 35) * 32] = (
            bytes(12) + bytes.fromhex(alternate_market[2:])
        )
        candidate[(1 + 36) * 32:(2 + 36) * 32] = alternate_runtime
        candidate[(1 + 37) * 32:(2 + 37) * 32] = \
            settlement.pvm_derived_market_authority_configuration_hash_v1(
                1, alternate_market, 1,
                profile_substitution[4].address,
                profile_substitution[1].address,
            )
        alternate_profile = \
            settlement.canonicalize_execution_profile_authority_graph_v2(
                bytes(candidate)
            )
        alternate = settlement.derive_register_release_authority_v2(
            alternate_profile,
            original.expected_predecessor_protocol_version,
        )
        padded = (len(alternate_profile) + 31) // 32 * 32
        profile_substitution[3] = b"".join((
            original.expected_predecessor_protocol_version.to_bytes(32, "big"),
            alternate.manifest_abi, alternate.deployment_abi,
            (0x880).to_bytes(32, "big"),
            len(alternate_profile).to_bytes(32, "big"), alternate_profile,
            bytes(padded - len(alternate_profile)),
        ))
        operation_id, _mature, success = self._execute_release(
            profile_substitution
        )
        self.assertFalse(success)
        self.assertEqual(
            profile_substitution[1].target_release_registrations_v2,
            registrations_before,
        )
        self.assertFalse(profile_substitution[6].authorizations)
        self.assertEqual(
            profile_substitution[5].operations[operation_id].state, 1
        )

        # A mutation introduced only after Router returns is detected by the
        # PVM target postread and is reverted with the outer transaction.
        toctou = protocol_authority_fixture()
        registrations_before = copy.deepcopy(
            toctou[1].target_release_registrations_v2
        )
        decoded = settlement.decode_register_release_payload_v1(toctou[3])
        target = decoded.target_address

        def mutate_after_router(world, manager_, _router):
            world.accounts[target].overrides[
                (manager_.address, "component_config")
            ] = b"z" * 32

        toctou[4].deployment_world.between_router_and_pvm_hook = \
            mutate_after_router
        operation_id, _mature, success = self._execute_release(toctou)
        self.assertFalse(success)
        self.assertEqual(
            toctou[1].target_release_registrations_v2,
            registrations_before,
        )
        self.assertFalse(toctou[6].authorizations)
        self.assertEqual(toctou[5].operations[operation_id].state, 1)
        self.assertNotIn(
            (toctou[4].address, "component_config"),
            toctou[4].deployment_world.accounts[target].overrides,
        )

        for point in ("router_direct_read", "pvm_postread"):
            with self.subTest(point=point):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                if point == "router_direct_read":
                    current[1].release_registration_getter_override = b""
                else:
                    current[4].postread_override = b""
                operation_id, _mature, success = self._execute_release(current)
                self.assertFalse(success)
                self.assertEqual(
                    current[1].target_release_registrations_v2,
                    registrations_before,
                )
                self.assertFalse(current[4].profile_ingress_rows)
                self.assertFalse(current[6].authorizations)
                self.assertEqual(current[5].operations[operation_id].state, 1)

        # Every one of the eight deployment words is either rejected by the
        # CREATE2 decoder or reaches the witness join and reverts atomically.
        for deployment_word in range(59, 67):
            with self.subTest(deployment_word=deployment_word):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                changed = bytearray(current[3])
                changed[deployment_word * 32 + 31] ^= 1
                changed = bytes(changed)
                try:
                    settlement.decode_register_release_payload_v1(changed)
                except ValueError:
                    continue
                operation_id = current[5].queue_protocol_change_v1(
                    settlement.REGISTER_RELEASE, changed,
                    caller=current[5].dao_proposer, clock=current[8],
                )
                self.assertIsNotNone(operation_id)
                self.assertFalse(current[5].execute_protocol_change_v1(
                    1, settlement.REGISTER_RELEASE, changed,
                    caller=addr("permissionless"),
                    clock=settlement.Clock(
                        current[8].block_number + 1,
                        current[8].timestamp
                            + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
                    ),
                ))
                self.assertEqual(
                    current[1].target_release_registrations_v2,
                    registrations_before,
                )
                self.assertFalse(current[6].authorizations)

    def test_register_release_rejects_alternate_manifest_namespace_before_writes(self):
        current = list(protocol_authority_fixture())
        registrations_before = copy.deepcopy(
            current[1].target_release_registrations_v2
        )
        original = settlement.decode_register_release_payload_v1(current[3])
        original_words = settlement._execution_profile_abi_words_v2(
            original.profile_bytes
        )
        self.assertEqual(
            original_words[9], current[4].manifest_namespace
        )

        alternate_namespace = settlement.keccak256(
            b"alternate-protocol-root-manifest-namespace"
        )
        candidate = bytearray(original.profile_bytes)
        candidate[(1 + 9) * 32:(2 + 9) * 32] = alternate_namespace
        candidate[(1 + 205) * 32:(2 + 205) * 32] = \
            settlement.source_bundle_salt_v1(
                alternate_namespace,
                int.from_bytes(original_words[1], "big"),
            )
        alternate_profile = \
            settlement.canonicalize_execution_profile_authority_graph_v2(
                bytes(candidate)
            )
        alternate_words = settlement._execution_profile_abi_words_v2(
            alternate_profile
        )
        self.assertEqual(alternate_words[9], alternate_namespace)
        self.assertNotEqual(
            alternate_words[9], current[4].manifest_namespace
        )
        alternate = settlement.derive_register_release_authority_v2(
            alternate_profile,
            original.expected_predecessor_protocol_version,
        )
        padded = (len(alternate_profile) + 31) // 32 * 32
        current[3] = b"".join((
            original.expected_predecessor_protocol_version.to_bytes(32, "big"),
            alternate.manifest_abi,
            alternate.deployment_abi,
            (0x880).to_bytes(32, "big"),
            len(alternate_profile).to_bytes(32, "big"),
            alternate_profile,
            bytes(padded - len(alternate_profile)),
        ))

        operation_id, _mature, success = self._execute_release(current)
        self.assertFalse(success)
        self.assertEqual(current[4].lifecycle, "IDLE")
        self.assertFalse(current[4].consumed_operation_ids)
        self.assertFalse(current[4].profile_ingress_rows)
        self.assertEqual(
            current[1].target_release_registrations_v2,
            registrations_before,
        )
        self.assertFalse(current[6].authorizations)
        self.assertEqual(current[5].operations[operation_id].state, 1)

    def test_protocol_timelock_cancel_replay_and_exact_views(self):
        fixture = protocol_authority_fixture()
        payload, manager, timelock, clock = (
            fixture[3], fixture[4], fixture[5], fixture[8]
        )
        self.assertEqual(len(timelock.config_return_v1()), 160)
        manager_config = manager.config_return_v1()
        self.assertEqual(len(manager_config), 1_088)
        self.assertEqual(manager_config[8 * 32:9 * 32], manager.market_runtime_hash)
        self.assertEqual(
            manager_config[9 * 32:10 * 32],
            manager.market_configuration_hash,
        )
        self.assertEqual(
            tuple(manager_config[index * 32:(index + 1) * 32]
                  for index in range(22, 34)),
            manager.control_component_hashes,
        )
        self.assertEqual(
            settlement.protocol_version_manager_configuration_hash_v1(
                settlement.decode_protocol_version_manager_config_return_v1(
                    manager_config
                )
            ),
            manager.configuration_hash,
        )
        manager_view = \
            settlement.decode_protocol_version_manager_config_return_v1(
                manager_config
            )
        as_int = lambda value: int.from_bytes(value, "big")
        independent_config = commitment.ProtocolVersionManagerConfigurationV1(
            manager_view.settlement_chain_id,
            as_int(manager_view.protocol_change_timelock),
            manager_view.timelock_descriptor_hash,
            as_int(manager_view.active_settlement_router),
            as_int(manager_view.forced_queue),
            as_int(manager_view.builder_registry),
            as_int(manager_view.schedule_oracle),
            as_int(manager_view.aggregator_seat_market),
            manager_view.aggregator_seat_market_runtime_hash,
            manager_view.aggregator_seat_market_configuration_hash,
            *manager.control_component_hashes,
            as_int(manager_view.bridge_domain_registry),
            as_int(manager_view.bridge_credit_registry),
            manager_view.manifest_namespace,
            manager_view.release_router_registration_gas,
            manager_view.release_market_installation_gas,
            manager_view.release_postread_gas,
            manager_view.release_post_callback_reserve_gas,
        )
        self.assertEqual(
            commitment.encode_protocol_version_manager_config_return(
                independent_config
            ),
            manager_config,
        )
        self.assertEqual(
            commitment.protocol_version_manager_configuration_hash(
                independent_config
            ),
            manager.configuration_hash,
        )
        self.assertEqual(
            manager_view.migration_arm_execution_window_seconds,
            settlement.MIGRATION_ARM_EXECUTION_WINDOW_SECONDS,
        )
        self.assertEqual(
            settlement.MIGRATION_ARM_FRESH_AFTER_SELECTOR,
            settlement.keccak256(b"migrationArmFreshAfterV1()")[:4],
        )
        self.assertEqual(
            manager.migration_arm_fresh_after_v1(),
            commitment.encode_migration_arm_fresh_after_return(0),
        )
        for trailing in (False, True):
            with self.subTest(pct1_trailing=trailing):
                current = protocol_authority_fixture()
                registrations_before = copy.deepcopy(
                    current[1].target_release_registrations_v2
                )
                raw = current[5].config_return_v1()
                current[5].config_return_overrides[current[4].address] = (
                    raw + bytes(32) if trailing else raw[:-1]
                )
                operation_id, _mature, success = self._execute_release(current)
                self.assertFalse(success)
                self.assertEqual(
                    current[1].target_release_registrations_v2,
                    registrations_before,
                )
                self.assertEqual(current[5].operations[operation_id].state, 1)

        malicious = protocol_authority_fixture()
        registrations_before = copy.deepcopy(
            malicious[1].target_release_registrations_v2
        )
        attacker = addr("malicious-dao")
        malicious[5].dao_proposer = attacker
        malicious_operation = malicious[5].queue_protocol_change_v1(
            settlement.REGISTER_RELEASE, malicious[3], caller=attacker,
            clock=malicious[8],
        )
        self.assertIsNotNone(malicious_operation)
        self.assertFalse(malicious[5].execute_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, malicious[3],
            caller=addr("permissionless"),
            clock=settlement.Clock(
                malicious[8].block_number + 1,
                malicious[8].timestamp
                    + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
            ),
        ))
        self.assertEqual(
            malicious[1].target_release_registrations_v2,
            registrations_before,
        )
        self.assertEqual(
            malicious[5].operations[malicious_operation].state, 1
        )
        self.assertEqual(
            settlement.INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR.hex(),
            "b1a3fef9",
        )
        self.assertEqual(
            settlement.SETTLEMENT_AUTHORIZATION_SELECTOR.hex(), "1693ae01"
        )
        for unknown in (0, 5, 255):
            self.assertIsNone(timelock.queue_protocol_change_v1(
                unknown, payload, caller=timelock.dao_proposer, clock=clock
            ))
        operation_id = timelock.queue_protocol_change_v1(
            settlement.REGISTER_RELEASE, payload,
            caller=timelock.dao_proposer, clock=clock,
        )
        self.assertEqual(len(timelock.operation_return_v1(operation_id)), 256)
        self.assertFalse(timelock.cancel_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload, caller=addr("foreign")
        ))
        self.assertTrue(timelock.cancel_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=timelock.dao_proposer,
        ))
        self.assertFalse(timelock.cancel_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=timelock.dao_proposer,
        ))
        self.assertFalse(timelock.execute_protocol_change_v1(
            1, settlement.REGISTER_RELEASE, payload,
            caller=addr("executor"),
            clock=settlement.Clock(
                clock.block_number + 1,
                clock.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
            ),
        ))
        self.assertEqual(timelock.operations[operation_id].state, 3)

    def test_eip2935_is_a_fixed_selector_free_system_read_not_authority(self):
        adapter = settlement.make_header_oracle()
        self.assertIs(
            type(adapter), settlement.EIP2935SystemReadTestAdapter
        )
        self.assertFalse(hasattr(adapter, "address"))
        self.assertFalse(hasattr(adapter, "runtime_hash"))
        requested = 100
        calldata = requested.to_bytes(32, "big")
        self.assertEqual(
            adapter.read_hash(requested, 101, calldata),
            bytes.fromhex(adapter.header(requested).block_hash),
        )
        self.assertEqual(
            settlement.L1_EIP2935_HISTORY_STORAGE_ADDRESS.lower(),
            "0x0000f90827f1c53a10cb7a02335b175320002935",
        )
        self.assertEqual(
            settlement.L2_EIP2935_HISTORY_STORAGE_ADDRESS.lower(),
            "0x0000f90827f1c53a10cb7a02335b175320002935",
        )
        for current, call_data, gas, value in (
            (requested, calldata, settlement.EIP2935_HISTORY_READ_GAS, 0),
            (requested + settlement.EIP2935_HISTORY_SERVE_WINDOW + 1,
             calldata, settlement.EIP2935_HISTORY_READ_GAS, 0),
            (101, (requested + 1).to_bytes(32, "big"),
             settlement.EIP2935_HISTORY_READ_GAS, 0),
            (101, calldata, settlement.EIP2935_HISTORY_READ_GAS - 1, 0),
            (101, calldata, settlement.EIP2935_HISTORY_READ_GAS, 1),
        ):
            with self.assertRaises(ValueError):
                adapter.read_hash(
                    requested, current, call_data,
                    gas_limit=gas, value=value,
                )

        bounded = settlement.make_header_oracle(first_supported_block=100)
        self.assertEqual(
            bounded.read_hash(100, 101, (100).to_bytes(32, "big")),
            bytes.fromhex(bounded.header(100).block_hash),
        )
        with self.assertRaises(ValueError):
            bounded.read_hash(99, 101, (99).to_bytes(32, "big"))
        substituted = settlement.make_header_oracle(first_supported_block=101)
        with self.assertRaises(ValueError):
            substituted.read_hash(100, 101, (100).to_bytes(32, "big"))
        self.assertNotEqual(
            settlement.eip2935_read_configuration_hash_v1(100),
            settlement.eip2935_read_configuration_hash_v1(101),
        )

    def test_schedule_registry_successors_bounds_and_vacant_is_not_stored(self):
        fixture = protocol_authority_fixture()
        manager, timelock, oracle, clock = (
            fixture[4], fixture[5], fixture[7], fixture[8]
        )

        def fork_row(digest, first_window, gas=500_000):
            gindices = (8, 201, 6_434, 6_437, 6_441, 6_444)
            witness_schema = settlement.keccak256(
                b"schedule-witness:" + digest
            )
            selector = bytes.fromhex("7e981e0b")
            config = settlement.schedule_fork_verifier_configuration_hash_v1(
                digest, gindices, witness_schema, selector, gas
            )
            return settlement.RegisterForkVerifierPayloadV1(
                digest, first_window, bytes.fromhex("11" * 20),
                settlement.keccak256(b"fork-runtime:" + digest),
                *gindices, witness_schema, config, selector, gas,
            )

        first = fork_row(bytes.fromhex("01020304"), 109)
        first_payload = settlement.encode_register_fork_verifier_payload_v1(
            first
        )
        self.assertEqual(len(first_payload), 14 * 32)
        operation = timelock.queue_protocol_change_v1(
            settlement.REGISTER_FORK_VERIFIER, first_payload,
            caller=timelock.dao_proposer, clock=clock,
        )
        mature = settlement.Clock(
            clock.block_number + 1,
            clock.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            1, settlement.REGISTER_FORK_VERIFIER, first_payload,
            caller=addr("fork-installer"), clock=mature,
        ))
        self.assertEqual(timelock.operations[operation].state, 4)
        second = fork_row(bytes.fromhex("05060708"), 120, 5_000_000)
        second_payload = settlement.encode_register_fork_verifier_payload_v1(
            second
        )
        queued = timelock.queue_protocol_change_v1(
            settlement.REGISTER_FORK_VERIFIER, second_payload,
            caller=timelock.dao_proposer, clock=mature,
        )
        second_mature = settlement.Clock(
            mature.block_number + 1,
            mature.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            2, settlement.REGISTER_FORK_VERIFIER, second_payload,
            caller=addr("fork-installer"), clock=second_mature,
        ))
        self.assertEqual(timelock.operations[queued].state, 4)
        first_view = oracle.fork_verifier_registration_v1(first.fork_digest)
        self.assertEqual(first_view[3 * 32:3 * 32 + 4], second.fork_digest)
        self.assertIsNotNone(oracle._eligible_row(119, first.fork_digest))
        self.assertIsNone(oracle._eligible_row(120, first.fork_digest))
        self.assertIsNotNone(oracle._eligible_row(120, second.fork_digest))

        deadline = second_mature.timestamp + 100
        before = dict(oracle.sealed_windows)
        for bad_return in (b"", b"SFC1" + bytes(251), bytes(256)):
            with self.assertRaises(ValueError):
                oracle.seal_window_v1(
                    120, second.fork_digest, b"retryable-witness", bad_return,
                    seal_deadline=deadline, clock=second_mature,
                )
        self.assertEqual(oracle.sealed_windows, before)
        carrier = b"SFC1" + bytes(28) + b"s" * 32 + bytes(192)
        seal = oracle.seal_window_v1(
            120, second.fork_digest, b"valid-witness", carrier,
            seal_deadline=deadline, clock=second_mature,
        )
        self.assertEqual(oracle.consume_window_v1(
            120, seal_deadline=deadline, clock=second_mature
        ), seal)
        with self.assertRaises(ValueError):
            oracle.consume_window_v1(
                121, seal_deadline=deadline, clock=second_mature
            )
        after_deadline = settlement.Clock(
            second_mature.block_number + 1, deadline
        )
        self.assertEqual(oracle.consume_window_v1(
            121, seal_deadline=deadline, clock=after_deadline
        ), bytes(32))
        self.assertNotIn(121, oracle.sealed_windows)

    def test_nonextendable_version_lease_arm_abort_and_rollback(self):
        fixture = protocol_authority_fixture()
        _operation, mature, release_success = self._execute_release(fixture)
        self.assertTrue(release_success)
        router, witness, manager, timelock = (
            fixture[1], fixture[2], fixture[4], fixture[5]
        )
        version = witness.settlement.protocol_version
        decoded = settlement.decode_register_release_payload_v1(fixture[3])
        registration_hash = decoded.target_registration_hash
        arm_payload = b"".join((
            manager.active_protocol_version.to_bytes(32, "big"),
            version.to_bytes(32, "big"), decoded.release_manifest_hash,
            registration_hash,
        ))
        arm_operation = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, arm_payload,
            caller=timelock.dao_proposer, clock=mature,
        )
        arm_clock = settlement.Clock(
            mature.block_number
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            mature.timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            2, settlement.PUBLISH_MIGRATION_ARM, arm_payload,
            caller=addr("armer"), clock=arm_clock,
        ))
        lease = manager.migration_lease
        self.assertEqual(router.migration_gate.mode, "ARMED")
        source_protocol = fixture[0][0]
        source_history = fixture[0][1]
        self.assertIsNotNone(source_protocol.seat_migration_arm)
        self.assertEqual(source_history.mode, "MIGRATION_ARMED")
        self.assertTrue(source_protocol.sync(settlement.Clock(
            arm_clock.block_number + 1, arm_clock.timestamp + 1
        )))
        self.assertEqual(router.migration_gate.mode, "READY")
        self.assertEqual(source_history.mode, "MIGRATION_READY")
        self.assertEqual(
            lease.abort_after_timestamp,
            arm_clock.timestamp
                + settlement.MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS,
        )
        self.assertFalse(manager.permissionless_abort_expired_migration_v1(
            caller=addr("keeper"),
            clock=settlement.Clock(
                arm_clock.block_number + 1,
                lease.abort_after_timestamp - 1,
            ),
        ))
        self.assertTrue(manager.permissionless_abort_expired_migration_v1(
            caller=addr("keeper"),
            clock=settlement.Clock(
                arm_clock.block_number + 2, lease.abort_after_timestamp
            ),
        ))
        self.assertEqual(manager.migration_lease,
                         settlement.VersionMigrationLeaseV1())
        self.assertEqual(router.migration_gate.mode, "ACTIVE")
        self.assertEqual(timelock.operations[arm_operation].state, 4)
        self.assertEqual(manager.arm_fresh_after, lease.abort_after_timestamp)
        self.assertEqual(
            commitment.decode_migration_arm_fresh_after_return(
                manager.migration_arm_fresh_after_v1()
            ),
            lease.abort_after_timestamp,
        )

        rollback = protocol_authority_fixture()
        self.assertTrue(self._execute_release(rollback)[2])
        router2, witness2, manager2, timelock2 = (
            rollback[1], rollback[2], rollback[4], rollback[5]
        )
        decoded2 = settlement.decode_register_release_payload_v1(rollback[3])
        reg2 = decoded2.target_registration_hash
        arm2 = b"".join((
            manager2.active_protocol_version.to_bytes(32, "big"),
            witness2.settlement.protocol_version.to_bytes(32, "big"),
            decoded2.release_manifest_hash, reg2,
        ))
        first_mature = settlement.Clock(
            rollback[8].block_number + 1,
            rollback[8].timestamp + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
        )
        self.assertIsNotNone(timelock2.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, arm2,
            caller=timelock2.dao_proposer, clock=first_mature,
        ))
        router2.release_registration_fault_point = "arm_after_gate"
        self.assertFalse(timelock2.execute_protocol_change_v1(
            2, settlement.PUBLISH_MIGRATION_ARM, arm2,
            caller=addr("armer"),
            clock=settlement.Clock(
                first_mature.block_number
                    + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                first_mature.timestamp
                    + settlement.PROTOCOL_CHANGE_DELAY_SECONDS,
            ),
        ))
        self.assertEqual(router2.migration_gate.mode, "ACTIVE")
        self.assertEqual(manager2.migration_lease,
                         settlement.VersionMigrationLeaseV1())

    def test_migration_arm_execution_window_is_inclusive_and_double_enforced(self):
        def prepared():
            fixture = protocol_authority_fixture()
            _release, mature, released = self._execute_release(fixture)
            self.assertTrue(released)
            manager, timelock = fixture[4], fixture[5]
            decoded = settlement.decode_register_release_payload_v1(
                fixture[3]
            )
            payload = b"".join((
                fixture[1].active_version.to_bytes(32, "big"),
                decoded.protocol_version.to_bytes(32, "big"),
                decoded.release_manifest_hash,
                decoded.target_registration_hash,
            ))
            operation_id = timelock.queue_protocol_change_v1(
                settlement.PUBLISH_MIGRATION_ARM, payload,
                caller=timelock.dao_proposer, clock=mature,
            )
            self.assertIsNotNone(operation_id)
            row = timelock.operations[operation_id]
            return fixture, payload, operation_id, row

        fixture, payload, operation_id, row = prepared()
        timelock = fixture[5]
        before = settlement.Clock(
            fixture[8].block_number + 1
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            row.execute_after - 1,
        )
        self.assertFalse(timelock.execute_protocol_change_v1(
            row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("before-arm-maturity"), clock=before,
        ))
        self.assertEqual(timelock.operations[operation_id].state, 1)

        at_maturity = settlement.Clock(
            before.block_number + 1, row.execute_after
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("at-arm-maturity"), clock=at_maturity,
        ))

        fixture, payload, operation_id, row = prepared()
        execute_by = (
            row.execute_after
            + settlement.MIGRATION_ARM_EXECUTION_WINDOW_SECONDS
        )
        self.assertTrue(fixture[5].execute_protocol_change_v1(
            row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("at-arm-deadline"),
            clock=settlement.Clock(
                fixture[8].block_number + 1
                    + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                execute_by,
            ),
        ))

        fixture, payload, operation_id, row = prepared()
        expired = settlement.Clock(
            fixture[8].block_number + 1
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            row.execute_after
                + settlement.MIGRATION_ARM_EXECUTION_WINDOW_SECONDS + 1,
        )
        self.assertFalse(fixture[5].execute_protocol_change_v1(
            row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("after-arm-deadline"), clock=expired,
        ))
        self.assertEqual(fixture[5].operations[operation_id].state, 1)

        # Bypass the Timelock's deadline predicate in the fixture and prove
        # that PVM independently rejects the same expired authority.
        manager, timelock = fixture[4], fixture[5]
        consumed_before = set(manager.consumed_operation_ids)
        executing = replace(row, state=2)
        timelock.operations[operation_id] = executing
        timelock._executing_operation_id = operation_id
        with self.assertRaisesRegex(ValueError, "stale or expired"):
            manager.apply_protocol_change_v1(
                operation_id, executing, payload,
                timelock=timelock, clock=expired,
            )
        self.assertEqual(manager.lifecycle, "IDLE")
        self.assertEqual(manager.consumed_operation_ids, consumed_before)
        self.assertNotIn(operation_id, manager.consumed_operation_ids)

    def test_abort_freshness_invalidates_all_preabort_arms_and_requires_new_delay(self):
        fixture = protocol_authority_fixture()
        _release, mature, released = self._execute_release(fixture)
        self.assertTrue(released)
        router, manager, timelock = fixture[1], fixture[4], fixture[5]
        decoded = settlement.decode_register_release_payload_v1(fixture[3])
        payload = b"".join((
            router.active_version.to_bytes(32, "big"),
            decoded.protocol_version.to_bytes(32, "big"),
            decoded.release_manifest_hash,
            decoded.target_registration_hash,
        ))
        first_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=timelock.dao_proposer, clock=mature,
        )
        sibling_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=timelock.dao_proposer,
            clock=settlement.Clock(mature.block_number, mature.timestamp + 1),
        )
        self.assertIsNotNone(first_id)
        self.assertIsNotNone(sibling_id)
        first_row = timelock.operations[first_id]
        arm_clock = settlement.Clock(
            mature.block_number
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            first_row.execute_after,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            first_row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("first-arm"), clock=arm_clock,
        ))
        lease = manager.migration_lease
        abort_clock = settlement.Clock(
            arm_clock.block_number + 2, lease.abort_after_timestamp
        )

        manager.fault_point = "abort_before_idle"
        self.assertFalse(manager.permissionless_abort_expired_migration_v1(
            caller=addr("faulting-aborter"), clock=abort_clock,
        ))
        self.assertEqual(manager.arm_fresh_after, 0)
        self.assertEqual(router.migration_gate.mode, "ARMED")
        manager.fault_point = None
        self.assertTrue(manager.permissionless_abort_expired_migration_v1(
            caller=addr("successful-aborter"), clock=abort_clock,
        ))
        self.assertEqual(manager.arm_fresh_after, abort_clock.timestamp)

        # The sibling was already mature at abort, but the strict queued-at
        # watermark invalidates it together with every other pre-abort row.
        sibling_row = timelock.operations[sibling_id]
        self.assertLessEqual(sibling_row.execute_after, abort_clock.timestamp)
        self.assertFalse(timelock.execute_protocol_change_v1(
            sibling_row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("stale-sibling"), clock=abort_clock,
        ))
        self.assertEqual(timelock.operations[sibling_id].state, 1)

        equality_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=timelock.dao_proposer, clock=abort_clock,
        )
        equality_row = timelock.operations[equality_id]
        self.assertEqual(equality_row.queued_at, manager.arm_fresh_after)
        self.assertFalse(timelock.execute_protocol_change_v1(
            equality_row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("equal-watermark"),
            clock=settlement.Clock(
                abort_clock.block_number + 1, equality_row.execute_after
            ),
        ))

        post_abort_queue_clock = settlement.Clock(
            abort_clock.block_number + 1, abort_clock.timestamp + 1
        )
        fresh_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=timelock.dao_proposer, clock=post_abort_queue_clock,
        )
        fresh_row = timelock.operations[fresh_id]
        self.assertGreater(fresh_row.queued_at, manager.arm_fresh_after)
        self.assertFalse(timelock.execute_protocol_change_v1(
            fresh_row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("fresh-but-early"),
            clock=settlement.Clock(
                post_abort_queue_clock.block_number + 1,
                fresh_row.execute_after - 1,
            ),
        ))
        self.assertTrue(timelock.execute_protocol_change_v1(
            fresh_row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("fresh-after-delay"),
            clock=settlement.Clock(
                post_abort_queue_clock.block_number + 2,
                fresh_row.execute_after,
            ),
        ))

    def test_successful_activation_does_not_advance_abort_freshness(self):
        fixture = protocol_authority_fixture()
        _release, mature, released = self._execute_release(fixture)
        self.assertTrue(released)
        old_protocol, old_history = fixture[0][0], fixture[0][1]
        router, witness, manager, timelock = (
            fixture[1], fixture[2], fixture[4], fixture[5]
        )
        decoded = settlement.decode_register_release_payload_v1(fixture[3])
        payload = b"".join((
            router.active_version.to_bytes(32, "big"),
            decoded.protocol_version.to_bytes(32, "big"),
            decoded.release_manifest_hash,
            decoded.target_registration_hash,
        ))
        operation_id = timelock.queue_protocol_change_v1(
            settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=timelock.dao_proposer, clock=mature,
        )
        row = timelock.operations[operation_id]
        arm_clock = settlement.Clock(
            mature.block_number
                + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
            row.execute_after,
        )
        self.assertTrue(timelock.execute_protocol_change_v1(
            row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
            caller=addr("success-arm"), clock=arm_clock,
        ))
        activation_clock = settlement.Clock(
            max(old_history.last_canonical_l1_block + 1,
                arm_clock.block_number + 1),
            max(arm_clock.timestamp + 1,
                settlement.GENESIS_TIMESTAMP + old_history.core.tip_slot + 1),
        )
        self.assertTrue(old_protocol.sync(activation_clock))
        self.assertEqual(router.migration_gate.mode, "READY")
        armed_lease = manager.migration_lease
        self.assertEqual(
            manager.migration_arm_id_by_generation[armed_lease.generation],
            armed_lease.arm_id,
        )

        class IterationForbiddenArmHistory(dict):
            def values(self):
                raise AssertionError("live lease lookup iterated arm history")

            def items(self):
                raise AssertionError("live lease lookup iterated arm history")

            def __iter__(self):
                raise AssertionError("live lease lookup iterated arm history")

        manager.migration_arms = IterationForbiddenArmHistory(
            manager.migration_arms
        )
        self.assertEqual(
            manager.live_version_migration_lease_v1(),
            settlement.encode_live_version_migration_lease_return_v1(
                armed_lease
            ),
        )
        canonical_consume_probe = b"".join((
            settlement.VERSION_MIGRATION_CONSUME_SELECTOR,
            armed_lease.arm_id,
            bytes.fromhex("11" * 32),
            bytes.fromhex("22" * 32),
        ))
        malformed_envelopes = (
            (canonical_consume_probe[:-1], router, 0,
             settlement.VERSION_MIGRATION_CONSUME_GAS),
            (b"FAIL" + canonical_consume_probe[4:], router, 0,
             settlement.VERSION_MIGRATION_CONSUME_GAS),
            (canonical_consume_probe, object(), 0,
             settlement.VERSION_MIGRATION_CONSUME_GAS),
            (canonical_consume_probe, router, 1,
             settlement.VERSION_MIGRATION_CONSUME_GAS),
            (canonical_consume_probe, router, 0,
             settlement.VERSION_MIGRATION_CONSUME_GAS - 1),
        )
        for calldata, caller, value, gas in malformed_envelopes:
            with self.assertRaises(ValueError):
                manager.consume_version_migration_lease_v1(
                    calldata, caller=caller, value=value, gas=gas
                )
        self.assertEqual(manager.migration_lease, armed_lease)
        consume_calls = []
        original_consume = manager.consume_version_migration_lease_v1

        def recording_consume(calldata, *, caller, value, gas):
            consume_calls.append((calldata, caller, value, gas))
            return original_consume(
                calldata, caller=caller, value=value, gas=gas
            )

        manager.consume_version_migration_lease_v1 = recording_consume
        target = witness.settlement
        candidate, inbox_rows = settlement.migration_activation_candidate(
            router, target, activation_clock,
            decoded.release_manifest_hash,
            "pvm-success-freshness", addr("success-beneficiary"),
        )
        authority = target.live_protocol._inbox_execution_authority
        attestation = settlement.issue_verified_migration_evm_trace_for_test(
            authority, router=router, settlement=target,
            clock=activation_clock,
            target_manifest_hash=decoded.release_manifest_hash,
            candidate=candidate, rows=inbox_rows,
        )
        proof = authority.verify_migration_execution_output(
            router=router, settlement=target, clock=activation_clock,
            target_manifest_hash=decoded.release_manifest_hash,
            candidate=candidate, evm_validity=attestation, rows=inbox_rows,
        )
        poststate = settlement.replay_verified_migration_output_on_l2_for_test(
            target.live_protocol, proof, router
        )
        self.assertIsNotNone(poststate)
        self.assertIsNotNone(router.activate_version_with_migration_v1(
            proof, caller=addr("success-activator"), clock=activation_clock,
        ))
        self.assertTrue(
            settlement.select_canonical_l2_poststate_for_test(poststate)
        )
        self.assertEqual(router.active_version, decoded.protocol_version)
        self.assertEqual(router.migration_gate.mode, "ACTIVE")
        self.assertEqual(
            manager.migration_lease, settlement.VersionMigrationLeaseV1()
        )
        self.assertEqual(len(consume_calls), 1)
        consume_calldata, consume_caller, consume_value, consume_gas = (
            consume_calls[0]
        )
        self.assertEqual(len(consume_calldata), 100)
        self.assertEqual(
            consume_calldata[:4],
            settlement.VERSION_MIGRATION_CONSUME_SELECTOR,
        )
        self.assertEqual(consume_calldata[4:36], armed_lease.arm_id)
        self.assertEqual(consume_caller, router)
        self.assertEqual(consume_value, 0)
        self.assertEqual(
            consume_gas, settlement.VERSION_MIGRATION_CONSUME_GAS
        )
        self.assertEqual(manager.migration_arms[armed_lease.arm_id], armed_lease)
        self.assertEqual(router.version_migration_activation_trace, [
            "VERIFIED", "ACTIVATING", "MFRZ", "MCAN", "K0ING", "SACT",
            "BRC1", "BSEAL", "BIND", "QMIG", "MAPS", "REGISTERED",
            "PUBLISHED", "IDLE", "VMC1",
        ])
        self.assertEqual(
            manager.live_version_migration_lease_v1(),
            settlement.encode_live_version_migration_lease_return_v1(
                settlement.VersionMigrationLeaseV1()
            ),
        )
        self.assertFalse(manager.permissionless_abort_expired_migration_v1(
            caller=addr("stale-abort"),
            clock=settlement.Clock(
                activation_clock.block_number + 1,
                armed_lease.abort_after_timestamp,
            ),
        ))
        self.assertEqual(manager.arm_fresh_after, 0)
        self.assertEqual(
            manager.migration_arm_fresh_after_v1(),
            commitment.encode_migration_arm_fresh_after_return(0),
        )

        active_registration = router.registrations[router.active_version]
        bridge_authorization = next(
            authorization
            for authorization in active_registration.ingress_authorizations
            if authorization.kind is settlement.ForceKind.BRIDGE_CREDIT
        )
        source_descriptor_id = router._source_descriptor_id_by_version[
            router.active_version
        ]
        source, _credit_registry, _quota = (
            router._source_bundles_by_descriptor_id[source_descriptor_id]
        )
        adapter = router._profile_deployments_by_version[
            router.active_version
        ][bridge_authorization.authorization_id]
        self.assertTrue(source.v2_active)
        self.assertTrue(adapter.destination_sealed)
        support_entry = router._bridge_domain_registry_authority \
            .latest_final_entry(
                source.source_domain_id,
                source.frozen_bridge_execution_hash,
                active_registration.release_manifest.destination_chain_id,
                settlement.Clock(
                    activation_clock.block_number,
                    activation_clock.timestamp + 1,
                ),
                source_bridge=source.address,
                caller=source.address,
                target=addr("c3-recipient"),
            )
        self.assertIsNotNone(support_entry)
        self.assertEqual(support_entry.route_kind, "PRIMITIVE")
        self.assertTrue(support_entry.arm_ready_consumed)

        post_cutover_clock = source.support_final_clock(
            activation_clock.timestamp + 1
        )
        denied_target = active_registration.release_manifest \
            .destination_bridge_descriptor.privileged_target_denyset[0]
        denied = settlement.bridge_message(
            post_cutover_clock.timestamp,
            "strict-c3-denied-target",
            to=denied_target,
            value=3,
            fee=1,
            liquidity_fee=1,
        )
        source_before_denied = source._transaction_snapshot()
        with self.assertRaises(ValueError):
            source.send_message(
                denied,
                caller=denied.sender,
                msg_value=5,
                clock=post_cutover_clock,
                enqueue_by=(
                    post_cutover_clock.timestamp
                    + settlement.MAX_BRIDGE_ENQUEUE_DELAY
                ),
            )
        self.assertEqual(source._transaction_snapshot(), source_before_denied)

        message = settlement.bridge_message(
            post_cutover_clock.timestamp,
            "strict-c3-post-cutover",
            to=addr("c3-recipient"),
            value=3,
            fee=1,
            liquidity_fee=1,
        )
        receipt = source.send_message(
            message,
            caller=message.sender,
            msg_value=5,
            clock=post_cutover_clock,
            enqueue_by=(
                post_cutover_clock.timestamp
                + settlement.MAX_BRIDGE_ENQUEUE_DELAY
            ),
        )
        self.assertEqual(source.credits[receipt.credit_id].status, "NEW")
        deposit = router.required_ingress_deposit(receipt.envelope, adapter)
        relayer = addr("strict-c3-relayer")
        self.assertEqual(
            adapter.enqueue(
                post_cutover_clock,
                envelope=receipt.envelope,
                caller=relayer,
                deposit=deposit,
            ),
            "SYNCED_REFUNDED",
        )
        self.assertEqual(adapter.withdraw_refund(relayer), deposit)
        queued = adapter.enqueue(
            post_cutover_clock,
            envelope=receipt.envelope,
            caller=relayer,
            deposit=deposit,
        )
        self.assertTrue(queued.startswith("QUEUED:"))
        self.assertEqual(source.credits[receipt.credit_id].status, "QUEUED")

    def test_strict_brc_faults_restore_arm_ready_consumption(self):
        scenarios = (
            ("registry_fault", "revert"),
            ("registry_return", b"BRC1"),
            ("mact_return", b"MACT"),
            ("asr_return", b"ASR1"),
            ("rtr_return", b"RTR2"),
            ("after_consume", "after_activation_receipt_write"),
            ("lease_consume_revert", "migration_consume_revert"),
            ("lease_consume_bad_return", "migration_consume_wrong_magic"),
        )
        for kind, fault in scenarios:
            with self.subTest(kind=kind):
                fixture = protocol_authority_fixture()
                _release, mature, released = self._execute_release(fixture)
                self.assertTrue(released)
                old_protocol, old_history = fixture[0][0], fixture[0][1]
                router, witness, manager, timelock = (
                    fixture[1], fixture[2], fixture[4], fixture[5]
                )
                decoded = settlement.decode_register_release_payload_v1(
                    fixture[3]
                )
                payload = b"".join((
                    router.active_version.to_bytes(32, "big"),
                    decoded.protocol_version.to_bytes(32, "big"),
                    decoded.release_manifest_hash,
                    decoded.target_registration_hash,
                ))
                operation_id = timelock.queue_protocol_change_v1(
                    settlement.PUBLISH_MIGRATION_ARM, payload,
                    caller=timelock.dao_proposer, clock=mature,
                )
                row = timelock.operations[operation_id]
                arm_clock = settlement.Clock(
                    mature.block_number
                        + settlement.BRIDGE_ROUTE_ARM_REVIEW_BLOCKS,
                    row.execute_after,
                )
                self.assertTrue(timelock.execute_protocol_change_v1(
                    row.nonce, settlement.PUBLISH_MIGRATION_ARM, payload,
                    caller=addr("fault-arm"), clock=arm_clock,
                ))
                activation_clock = settlement.Clock(
                    max(old_history.last_canonical_l1_block + 1,
                        arm_clock.block_number + 1),
                    max(arm_clock.timestamp + 1,
                        settlement.GENESIS_TIMESTAMP
                            + old_history.core.tip_slot + 1),
                )
                self.assertTrue(old_protocol.sync(activation_clock))
                target = witness.settlement
                candidate, inbox_rows = settlement.migration_activation_candidate(
                    router, target, activation_clock,
                    decoded.release_manifest_hash,
                    f"strict-brc-fault:{kind}", addr("fault-beneficiary"),
                )
                authority = target.live_protocol._inbox_execution_authority
                attestation = settlement.issue_verified_migration_evm_trace_for_test(
                    authority, router=router, settlement=target,
                    clock=activation_clock,
                    target_manifest_hash=decoded.release_manifest_hash,
                    candidate=candidate, rows=inbox_rows,
                )
                proof = authority.verify_migration_execution_output(
                    router=router, settlement=target,
                    clock=activation_clock,
                    target_manifest_hash=decoded.release_manifest_hash,
                    candidate=candidate, evm_validity=attestation,
                    rows=inbox_rows,
                )
                self.assertIsNotNone(
                    settlement.replay_verified_migration_output_on_l2_for_test(
                        target.live_protocol, proof, router
                    )
                )
                registry = router._bridge_domain_registry_authority
                entry = next(
                    item for item in registry.entries.values()
                    if item.protocol_version == decoded.protocol_version
                )
                self.assertFalse(entry.arm_ready_consumed)
                target_deployments = (
                    router._profile_deployments_by_version[
                        decoded.protocol_version
                    ]
                )
                target_adapter = next(
                    item for item in target_deployments.values()
                    if type(item) is settlement.BridgeAdapter
                )
                target_source = target_adapter.source_bridge
                old_version = router.active_version
                trace_before = list(
                    router.version_migration_activation_trace
                )
                lease_before = manager.migration_lease
                queue_before = router.forced_queue._transaction_snapshot()
                receipt_rows_before = (
                    dict(router.activation_receipts),
                    dict(router.activation_receipt_rows_v1),
                    dict(router.seat_successor_rows_v1),
                )
                target_before = (
                    target.mode, target.current_sequence, target.core,
                )
                adapter_seal_before = target_adapter.destination_domain_id
                source_before = target_source._transaction_snapshot()
                profile_before = dict(target_deployments)
                ingress_before = (
                    router._authorized_ingress,
                    router._authorized_ingress_by_address,
                    router._authorized_ingress_adapter_ids,
                )
                if kind == "registry_fault":
                    registry.consume_bridge_route_fault_point = fault
                elif kind == "registry_return":
                    registry.consume_bridge_route_return_override = fault
                elif kind == "mact_return":
                    router.migration_activation_context_return_override = fault
                elif kind == "asr_return":
                    router.active_settlement_state_return_override = fault
                elif kind == "rtr_return":
                    router.release_registration_getter_override = fault
                else:
                    manager.fault_point = fault
                with self.assertRaises((ValueError, RuntimeError)):
                    router.activate_version_with_migration_v1(
                        proof, caller=addr("fault-activator"),
                        clock=activation_clock,
                    )
                restored = next(
                    item for item in registry.entries.values()
                    if item.protocol_version == decoded.protocol_version
                )
                self.assertFalse(restored.arm_ready_consumed)
                self.assertEqual(router.active_version, old_version)
                self.assertEqual(router.migration_gate.mode, "READY")
                self.assertEqual(
                    router.version_migration_activation_trace, trace_before
                )
                self.assertEqual(manager.migration_lease, lease_before)
                self.assertEqual(
                    router.forced_queue._transaction_snapshot(), queue_before
                )
                self.assertEqual((
                    router.activation_receipts,
                    router.activation_receipt_rows_v1,
                    router.seat_successor_rows_v1,
                ), receipt_rows_before)
                self.assertEqual(
                    (target.mode, target.current_sequence, target.core),
                    target_before,
                )
                self.assertEqual(
                    target_adapter.destination_domain_id, adapter_seal_before
                )
                self.assertEqual(
                    target_source._transaction_snapshot(), source_before
                )
                self.assertEqual(
                    dict(router._profile_deployments_by_version[
                        decoded.protocol_version
                    ]),
                    profile_before,
                )
                self.assertEqual((
                    router._authorized_ingress,
                    router._authorized_ingress_by_address,
                    router._authorized_ingress_adapter_ids,
                ), ingress_before)
                registry.consume_bridge_route_fault_point = None
                registry.consume_bridge_route_return_override = None
                router.migration_activation_context_return_override = None
                router.active_settlement_state_return_override = None
                router.release_registration_getter_override = None
                manager.fault_point = None


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

    def test_terminal_frontier_is_bounded_wrapped_and_event_oracle_only(self):
        leaves = [hashlib.sha256(f"terminal-{index}".encode()).hexdigest()
                  for index in range(65)]
        for count in (0, 1, 2, 3, 7, 8, 63, 64, 65):
            frontier = settlement.terminal_frontier_from_leaves(
                leaves[:count]
            )
            tree = settlement.terminal_merkle_root(leaves[:count])
            self.assertEqual(
                settlement.terminal_frontier_root(frontier, count),
                settlement.terminal_wrapped_root(count, tree),
            )
        accumulator = settlement.TerminalAccumulatorV2({"domain": "bridge"})
        self.assertEqual(len(accumulator.frontier), 64)
        self.assertFalse(hasattr(accumulator, "leaves"))
        self.assertFalse(hasattr(accumulator, "_terminalized_credits"))
        self.assertEqual(accumulator.leaf_events, [])
        synthetic = [hashlib.sha256(f"t{height}".encode()).digest()
                     for height in range(settlement.TERMINAL_TREE_DEPTH)]
        leaf = hashlib.sha256(b"terminal-max").digest()
        max_minus_one = settlement._append_frontier_leaf(
            synthetic,
            settlement.UINT64_MAX - 1,
            leaf,
            node_domain=b"slot-chain-terminal-node-v2",
        )
        self.assertEqual(max_minus_one[0], leaf)
        self.assertEqual(len(settlement.terminal_frontier_root(
            max_minus_one, settlement.UINT64_MAX
        )), 64)
        baseline = settlement.terminal_frontier_root(synthetic, 5)
        stale = list(synthetic)
        stale[1] = hashlib.sha256(b"ignored-terminal-zero-bit").digest()
        self.assertEqual(
            settlement.terminal_frontier_root(stale, 5), baseline
        )
        used = list(synthetic)
        used[2] = hashlib.sha256(b"used-terminal-bit").digest()
        self.assertNotEqual(
            settlement.terminal_frontier_root(used, 5), baseline
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

        armed = settlement.protocol(seat=False)
        armed.migration_gate.mode = "ARMED"
        before = armed.snapshot()
        with self.assertRaises(settlement.DataSessionRevert):
            armed.open_session(now, owner, 0, expiry, payment=10)
        self.assertTrue(armed.identical(before))

    def test_active_settlement_state_abi_is_exact(self):
        self.assertEqual(
            tuple(phase.value for phase in settlement.RouterPhase),
            (0, 1, 2),
        )
        state = settlement.ActiveSettlementStateV1(
            settlement._model_address20("model-settlement"),
            7,
            25,
            0,
            bytes(32),
            bytes(32),
            settlement.RouterPhase.ACTIVE,
        )
        raw = settlement.encode_active_settlement_state_v1(state)
        self.assertEqual(len(raw), 256)
        self.assertEqual(
            settlement.decode_active_settlement_state_v1(raw), state
        )
        self.assertTrue(settlement.verify_active_settlement_state_v1(
            raw,
            gas=50_000,
            expected_settlement="model-settlement",
            expected_protocol_version=25,
        ))
        bad_rows = []
        for offset in (4, 32, 64, 96, 128, 160, 224):
            mutated = bytearray(raw)
            mutated[offset] ^= 1
            bad_rows.append(bytes(mutated))
        wrong_phase = bytearray(raw)
        wrong_phase[-1] = 3
        bad_rows.extend((bytes(wrong_phase), raw[:-1], raw + b"\x00"))
        for bad in bad_rows:
            self.assertFalse(settlement.verify_active_settlement_state_v1(
                bad,
                gas=50_000,
                expected_settlement="model-settlement",
                expected_protocol_version=25,
            ))
        self.assertFalse(settlement.verify_active_settlement_state_v1(
            raw,
            gas=49_999,
            expected_settlement="model-settlement",
            expected_protocol_version=25,
        ))
        self.assertFalse(settlement.verify_active_settlement_state_v1(
            raw,
            gas=50_000,
            expected_settlement="other-settlement",
            expected_protocol_version=25,
        ))
        self.assertFalse(settlement.verify_active_settlement_state_v1(
            raw,
            gas=50_000,
            expected_settlement="model-settlement",
            expected_protocol_version=26,
        ))
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        protocol = settlement.protocol(seat=False)
        owner = addr("active-state-sidecar")
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        session_id = protocol.next_data_session_id(owner)
        self.assertEqual(protocol.open_session(
            now, owner, 0, expiry, payment=10
        ), session_id)
        protocol.post_data(
            now, session_id, owner, **self._post_terms(salt=b"active-sidecar")
        )
        protocol.active_settlement_state_return_override = (
            protocol.active_settlement_state_v1()[:-1]
        )
        before = protocol.snapshot()
        before_events = copy.deepcopy(protocol.data_session_events)
        for call in (
            lambda: protocol.open_session(
                now, addr("second-owner"), 1, expiry, payment=10
            ),
            lambda: protocol.post_data(
                now, session_id, owner,
                **self._post_terms(salt=b"blocked-post"),
            ),
            lambda: protocol.seal_session(now, session_id, owner),
        ):
            with self.assertRaises(settlement.DataSessionRevert):
                call()
            self.assertTrue(protocol.identical(before))
            self.assertEqual(protocol.data_session_events, before_events)

    def test_readiness_and_accounting_abis_gate_ready_exactly(self):
        config_hash = hashlib.sha256(b"registered-session-config").digest()
        gate = settlement.MigrationGate(coordinator="version-manager")
        self.assertTrue(gate._bootstrap_from_router(
            25,
            "version-manager",
            active_settlement_address="source-settlement",
            active_data_session_config_hash=config_hash,
        ))
        self.assertTrue(gate._arm_from_manager(
            1, 25, 26, b"m" * 32, b"r" * 32,
            caller="version-manager"
        ))
        readiness = settlement.MigrationReadinessV1(
            1, 25, 26, b"m" * 32,
            b"r" * 32,
            settlement.MigrationBoundaryState.NONE, True,
        )
        accounting = settlement.DataSessionAccountingV1(
            0, 3, 3, 511, 99, 0, 30, 1, 999, False, config_hash
        )
        readiness_raw = settlement.encode_migration_readiness_v1(readiness)
        accounting_raw = settlement.encode_data_session_accounting_v1(accounting)
        self.assertEqual(len(readiness_raw), 256)
        self.assertEqual(len(accounting_raw), 512)
        self.assertEqual(
            settlement.decode_migration_readiness_v1(readiness_raw), readiness
        )
        self.assertEqual(
            settlement.decode_data_session_accounting_v1(accounting_raw),
            accounting,
        )

        class ReadyCaller:
            settlement_address = "source-settlement"
            migration_gate = gate
            settlement_eth_balance = 30

            def __init__(self, ready, accounted):
                self.ready = ready
                self.accounted = accounted

            @staticmethod
            def _is_current_settlement_target():
                return True

            def migration_readiness_v1(self):
                return self.ready

            def data_session_accounting_v1(self):
                return self.accounted

        bad_readiness = []
        for offset in (4, 32, 64, 96, 160, 192):
            mutated = bytearray(readiness_raw)
            mutated[offset] ^= 1
            bad_readiness.append(bytes(mutated))
        bad_readiness.extend((readiness_raw[:-1], readiness_raw + b"\x00"))
        for raw in bad_readiness:
            with self.assertRaises(ValueError):
                gate._mark_ready_from_protocol(
                    protocol=ReadyCaller(raw, accounting_raw),
                    caller="source-settlement", generation=1,
                )
            self.assertEqual(gate.mode, "ARMED")
        bad_accounting = []
        for offset in (4, 32, 64, 96, 128, 160, 320):
            mutated = bytearray(accounting_raw)
            mutated[offset] ^= 1
            bad_accounting.append(bytes(mutated))
        bad_accounting.extend((accounting_raw[:-1], accounting_raw + b"\x00"))
        for raw in bad_accounting:
            with self.assertRaises(ValueError):
                gate._mark_ready_from_protocol(
                    protocol=ReadyCaller(readiness_raw, raw),
                    caller="source-settlement", generation=1,
                )
            self.assertEqual(gate.mode, "ARMED")
        wrong_ready_rows = (
            replace(readiness, generation=2),
            replace(readiness, target_manifest_hash=b"x" * 32),
            replace(
                readiness,
                boundary_state=settlement.MigrationBoundaryState.NORMAL,
            ),
            replace(readiness, local_arm_complete=False),
        )
        for row in wrong_ready_rows:
            with self.assertRaises(ValueError):
                gate._mark_ready_from_protocol(
                    protocol=ReadyCaller(
                        settlement.encode_migration_readiness_v1(row),
                        accounting_raw,
                    ),
                    caller="source-settlement", generation=1,
                )
            self.assertEqual(gate.mode, "ARMED")
        wrong_accounting_rows = (
            replace(accounting, live_count=1, occupied_count=4),
            replace(accounting, occupied_count=2),
            replace(accounting, guard_entered=True),
            replace(accounting, data_session_config_hash=b"x" * 32),
            replace(
                accounting,
                live_bond_liability=settlement.SEAT_UINT256_MAX,
                refund_bond_liability=1,
            ),
        )
        for row in wrong_accounting_rows:
            with self.assertRaises(ValueError):
                gate._mark_ready_from_protocol(
                    protocol=ReadyCaller(
                        readiness_raw,
                        settlement.encode_data_session_accounting_v1(row),
                    ),
                    caller="source-settlement", generation=1,
                )
            self.assertEqual(gate.mode, "ARMED")
        with self.assertRaises(ValueError):
            gate._mark_ready_from_protocol(
                protocol=ReadyCaller(readiness_raw, accounting_raw),
                caller="attacker", generation=1,
            )
        insolvent = ReadyCaller(readiness_raw, accounting_raw)
        insolvent.settlement_eth_balance = 29
        with self.assertRaises(ValueError):
            gate._mark_ready_from_protocol(
                protocol=insolvent,
                caller="source-settlement", generation=1,
            )
        self.assertEqual(gate._mark_ready_from_protocol(
            protocol=ReadyCaller(readiness_raw, accounting_raw),
            caller="source-settlement", generation=1,
        ), settlement.MARK_MIGRATION_READY_RETURN)
        self.assertEqual(gate.mode, "READY")

        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        integrated = settlement.protocol(seat=False)
        integrated_router = settlement.routed_ingress_for_test(integrated)
        settlement.ProtocolVersionManager(
            integrated_router.version_manager, integrated_router
        )
        self.assertTrue(integrated.migration_gate._arm_from_manager(
            1, 1, 2, b"i" * 32, b"r" * 32,
            caller="version-manager"
        ))
        integrated.versioned_history.mode = "MIGRATION_ARMED"
        self.assertTrue(integrated._arm_migration_for_test(1, now))
        self.assertEqual(integrated.migration_gate.mode, "ARMED")
        before_mark = settlement.decode_migration_readiness_v1(
            integrated.migration_readiness_v1()
        )
        self.assertTrue(before_mark.local_arm_complete)
        integrated.migration_gate.mark_ready_return_override = (
            b"FAIL" + bytes(28)
        )
        before = integrated.snapshot()
        before_events = copy.deepcopy(integrated.events)
        with self.assertRaises(ValueError):
            integrated.sync(now)
        self.assertTrue(integrated.identical(before))
        self.assertEqual(integrated.events, before_events)
        self.assertEqual(integrated.migration_gate.mode, "ARMED")
        integrated.migration_gate.mark_ready_return_override = None
        self.assertTrue(integrated.sync(now))
        self.assertEqual(integrated.migration_gate.mode, "READY")
        after_mark = settlement.decode_migration_readiness_v1(
            integrated.migration_readiness_v1()
        )
        self.assertTrue(after_mark.local_arm_complete)
        self.assertTrue(
            integrated.migration_gate._ready_views_valid_for_activation(
                integrated
            )
        )
        integrated._install_data_session_for_test(
            settlement.DataSession(
                "activation-refund", "activation-owner", now.timestamp,
                refundable_bond=1,
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp + 1,
        )
        self.assertTrue(
            integrated.migration_gate._ready_views_valid_for_activation(
                integrated
            )
        )
        integrated.settlement_eth_balance -= 1
        self.assertFalse(
            integrated.migration_gate._ready_views_valid_for_activation(
                integrated
            )
        )

    def test_boundary_state_derivation_rejects_orphan_and_conflicts(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)

        def armed_protocol():
            protocol = settlement.protocol(
                seat=False,
                migration_gate=settlement.MigrationGate(
                    coordinator="version-manager"
                ),
            )
            self.assertTrue(protocol.migration_gate._bootstrap_from_router(1))
            self.assertTrue(protocol.migration_gate._arm_from_manager(
                1, 1, 2, b"b" * 32, b"r" * 32,
                caller="version-manager"
            ))
            self.assertTrue(protocol._arm_migration_for_test(1, now))
            return protocol

        self.assertIs(
            settlement.decode_migration_readiness_v1(
                armed_protocol().migration_readiness_v1()
            ).boundary_state,
            settlement.MigrationBoundaryState.NONE,
        )
        marker_protocols = []
        arm_marker = armed_protocol()
        arm_marker.normal_arm_block_number = now.block_number
        marker_protocols.append(arm_marker)
        deadline_marker = armed_protocol()
        deadline_marker.normal_deadline = now.timestamp + 1
        marker_protocols.append(deadline_marker)
        best_marker = armed_protocol()
        best_marker.normal_best = settlement.candidate(
            best_marker, now, "readiness-best"
        )
        marker_protocols.append(best_marker)
        for protocol in marker_protocols:
            row = settlement.decode_migration_readiness_v1(
                protocol.migration_readiness_v1()
            )
            self.assertIs(
                row.boundary_state, settlement.MigrationBoundaryState.NORMAL
            )
            self.assertFalse(row.local_arm_complete)
        orphan = armed_protocol()
        orphan.normal_context_id = "orphan"
        with self.assertRaises(ValueError):
            orphan.migration_readiness_v1()
        # Construct the exact current recovery before arming the component.
        recovering = settlement.protocol(
            seat=False,
            migration_gate=settlement.MigrationGate(
                coordinator="version-manager"
            ),
        )
        recovering.sync(settlement.Clock(
            now.block_number + 1,
            settlement.GENESIS_TIMESTAMP + recovering.core.tip_slot
            + settlement.DELTA_FINAL_LAG + 1,
        ))
        self.assertIs(recovering.mode, settlement.Mode.RECOVERY)
        self.assertTrue(recovering.migration_gate._bootstrap_from_router(1))
        self.assertTrue(recovering.migration_gate._arm_from_manager(
            1, 1, 2, b"r" * 32, b"q" * 32,
            caller="version-manager"
        ))
        self.assertTrue(recovering._arm_migration_for_test(1, now))
        row = settlement.decode_migration_readiness_v1(
            recovering.migration_readiness_v1()
        )
        self.assertIs(
            row.boundary_state, settlement.MigrationBoundaryState.RECOVERY
        )
        recovering.normal_deadline = now.timestamp + 1
        with self.assertRaises(ValueError):
            recovering.migration_readiness_v1()

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

    def test_maintenance_status_and_seal_have_exact_sync_boundary(self):
        lagged = settlement.protocol(seat=False)
        lagged_clock = settlement.Clock(
            1_001,
            settlement.GENESIS_TIMESTAMP + lagged.core.tip_slot
            + settlement.DELTA_FINAL_LAG + 1,
        )
        cursor = lagged.gc_cursor
        self.assertEqual(
            lagged.maintain_data_sessions(lagged_clock),
            (settlement.SESSION_MAINTENANCE_SYNCED, 0, 0, cursor),
        )
        self.assertEqual(lagged.gc_cursor, cursor)
        self.assertIs(lagged.mode, settlement.Mode.RECOVERY)

        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        armed = settlement.protocol(seat=False)
        armed._install_data_session_for_test(
            settlement.DataSession(
                "armed-live", "armed-owner", now.timestamp + 1_000,
                refundable_bond=1,
            ),
            0,
        )
        armed_router = settlement.routed_ingress_for_test(armed)
        settlement.ProtocolVersionManager(
            armed_router.version_manager, armed_router
        )
        self.assertTrue(armed.migration_gate._arm_from_manager(
            1, 1, 2, b"a" * 32, b"r" * 32,
            caller="version-manager"
        ))
        armed.versioned_history.mode = "MIGRATION_ARMED"
        self.assertTrue(armed._arm_migration_for_test(1, now))
        self.assertEqual(
            armed.maintain_data_sessions(now),
            (settlement.SESSION_MAINTENANCE_SYNCED, 0, 0, 8),
        )
        self.assertEqual(armed.gc_cursor, 8)
        self.assertIs(armed.session_cells[0].tag,
                      settlement.DataSessionCellTag.REFUND)

        sealed = settlement.protocol(seat=False)
        owner = addr("seal-owner")
        expiry = now.timestamp + settlement.DATA_TTL_SECONDS
        session_id = sealed.next_data_session_id(owner)
        self.assertEqual(sealed.open_session(
            now, owner, 0, expiry, payment=10
        ), session_id)
        post_result = sealed.post_data(
            now, session_id, owner, **self._post_terms()
        )
        self.assertEqual(post_result[:2], (0, 1))
        cursor = sealed.gc_cursor
        self.assertEqual(
            sealed.seal_session(lagged_clock, session_id, owner),
            (1, post_result[2], expiry),
        )
        self.assertIsInstance(
            sealed.data_session_events[-1], settlement.SessionSealedEvent
        )
        self.assertEqual(sealed.gc_cursor, cursor)
        self.assertIs(sealed.mode, settlement.Mode.NORMAL)

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

    def test_migration_1024_live_to_refund_in_exactly_128_calls(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        p = settlement.protocol(
            seat=False, refund_claim_window_seconds=100,
            migration_gate=settlement.MigrationGate(
                coordinator="version-manager"
            ),
        )
        p.gc_cursor = 73
        for cell in range(settlement.MAX_LIVE_DATA_SESSIONS):
            p._install_data_session_for_test(
                settlement.DataSession(
                    f"migration-{cell}", f"sybil-{cell}",
                    now.timestamp + 10_000, refundable_bond=1,
                ),
                cell,
            )
        self.assertEqual(p.session_live_count, 1_024)
        self.assertEqual(p.session_occupied_count, 1_024)
        p_router = settlement.routed_ingress_for_test(p)
        settlement.ProtocolVersionManager(p_router.version_manager, p_router)
        self.assertTrue(p.migration_gate._arm_from_manager(
            1, 1, 2, b"m" * 32, b"r" * 32,
            caller="version-manager"
        ))
        p.versioned_history.mode = "MIGRATION_ARMED"
        self.assertTrue(p._arm_migration_for_test(1, now))
        deadline = p.migration_refund_claim_deadline
        for call in range(128):
            self.assertNotEqual(p.migration_gate.mode, "READY")
            self.assertTrue(p._sync_migration(settlement.Clock(
                now.block_number + call, now.timestamp
            )))
        self.assertEqual(p.migration_gate.mode, "READY")
        self.assertEqual(p.gc_cursor, 73)
        self.assertEqual(
            (p.session_live_count, p.session_refund_count,
             p.session_occupied_count,
             p.data_session_live_bond_liability,
             p.data_session_refund_bond_liability),
            (0, 1_024, 1_024, 0, 1_024),
        )
        migration_events = [
            event for event in p.data_session_events
            if isinstance(event, settlement.SessionLiveToRefundEvent)
        ]
        maintenance_events = [
            event for event in p.data_session_events
            if isinstance(event, settlement.DataSessionsMaintainedEvent)
        ]
        self.assertEqual(len(migration_events), 1_024)
        self.assertEqual(len(maintenance_events), 128)
        self.assertTrue(all(
            event.migration_generation == 1
            for event in migration_events
        ))
        self.assertTrue(all(
            event.mode == settlement.DataSessionMaintenanceMode.MIGRATION.value
            and event.inspected == 8
            for event in maintenance_events
        ))
        self.assertEqual(len(p.session_cell_by_id), 1_024)
        self.assertFalse(p.session_owner_live_count)
        self.assertTrue(all(
            cell.tag is settlement.DataSessionCellTag.REFUND
            and cell.refund_claim_deadline == deadline
            for cell in p.session_cells
        ))
        self.assertEqual(p.gc_sessions(settlement.Clock(
            now.block_number + 200, deadline + 1
        )), (settlement.SESSION_MAINTENANCE_SCANNED, 8, 8, 81))
        self.assertEqual(p.session_refund_count, 1_016)

    def test_production_arm_freezes_deadline_before_live_cleanup_and_rolls_back(self):
        arm_clock = settlement.Clock(
            1_000, settlement.GENESIS_TIMESTAMP + 2_000
        )
        rows = production_migration_fixture()
        old_protocol, manager = rows[0], rows[4]
        old_protocol._install_data_session_for_test(
            settlement.DataSession(
                "arm-live", "arm-owner", arm_clock.timestamp + 1_000,
                refundable_bond=1,
            ),
            0,
        )
        execute_manager_arm(manager, arm_clock)
        self.assertEqual(old_protocol.migration_refund_generation, 1)
        self.assertGreater(old_protocol.migration_refund_claim_deadline,
                           arm_clock.timestamp)
        self.assertIs(old_protocol.session_cells[0].tag,
                      settlement.DataSessionCellTag.REFUND)
        self.assertEqual(old_protocol.migration_gate.mode, "ARMED")
        self.assertTrue(old_protocol._local_migration_arm_complete(False))
        self.assertTrue(old_protocol.sync(arm_clock))
        self.assertEqual(old_protocol.migration_gate.mode, "READY")
        self.assertTrue(
            old_protocol.migration_gate._ready_views_valid_for_activation(
                old_protocol
            )
        )

        failed_rows = production_migration_fixture()
        failed, failed_manager = failed_rows[0], failed_rows[4]
        failed._install_data_session_for_test(
            settlement.DataSession(
                "fault-live", "fault-owner", arm_clock.timestamp + 1_000,
                refundable_bond=1,
            ),
            0,
        )
        failed.seat_fault_point = "after_local_migration_arm"
        before = failed.snapshot()
        with self.assertRaises(RuntimeError):
            execute_manager_arm(failed_manager, arm_clock)
        self.assertTrue(failed.identical(before))
        self.assertEqual(failed.migration_refund_generation, 0)
        self.assertEqual(failed.migration_refund_claim_deadline, 0)
        self.assertIs(failed.session_cells[0].tag,
                      settlement.DataSessionCellTag.LIVE)

    def test_migration_deadline_boundary_abort_and_live_claim(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        p = settlement.protocol(
            seat=False, refund_claim_window_seconds=100,
            migration_gate=settlement.MigrationGate(
                coordinator="version-manager"
            ),
        )
        owner = addr("boundary-owner")
        p._install_data_session_for_test(
            settlement.DataSession(
                "boundary-live", owner, now.timestamp - 1,
                refundable_bond=10,
            ),
            0,
        )
        p.normal_deadline = now.timestamp + 500
        p.normal_arm_block_number = now.block_number
        self.assertTrue(p.migration_gate._bootstrap_from_router(1))
        self.assertTrue(p.migration_gate._arm_from_manager(
            1, 1, 2, b"m" * 32, b"r" * 32,
            caller="version-manager"
        ))
        self.assertTrue(p._arm_migration_for_test(1, now))
        self.assertEqual(
            p.migration_refund_claim_deadline, now.timestamp + 600
        )
        receiver = settlement.DataSessionBondReceiver(addr("boundary-recipient"))
        with self.assertRaises(settlement.DataSessionRevert):
            p.claim_data_session_refund(
                now, "boundary-live", owner, receiver
            )
        self.assertEqual(p.session_live_count, 1)
        p._clear_normal()
        equality = settlement.Clock(
            now.block_number + 1, p.migration_refund_claim_deadline
        )
        self.assertEqual(p.claim_data_session_refund(
            equality, "boundary-live", owner, receiver
        ), 10)
        self.assertEqual(p.session_live_count, 0)
        self.assertEqual(p.session_refund_count, 0)

        saturated = settlement.protocol(
            seat=False,
            migration_gate=settlement.MigrationGate(
                coordinator="version-manager"
            ),
        )
        saturated.normal_deadline = settlement.UINT64_MAX
        saturated.normal_arm_block_number = now.block_number
        self.assertTrue(saturated.migration_gate._bootstrap_from_router(1))
        self.assertTrue(saturated.migration_gate._arm_from_manager(
            1, 1, 2, b"s" * 32, b"r" * 32,
            caller="version-manager"
        ))
        self.assertTrue(saturated._arm_migration_for_test(1, now))
        self.assertEqual(
            saturated.migration_refund_claim_deadline,
            settlement.UINT64_MAX,
        )

        partial = settlement.protocol(
            seat=False,
            migration_gate=settlement.MigrationGate(
                coordinator="version-manager"
            ),
        )
        partial.gc_cursor = 100
        for cell in range(100, 116):
            partial._install_data_session_for_test(
                settlement.DataSession(
                    f"partial-{cell}", f"partial-owner-{cell}",
                    now.timestamp + 1_000, refundable_bond=1,
                ),
                cell,
            )
        self.assertTrue(partial.migration_gate._bootstrap_from_router(1))
        self.assertTrue(partial.migration_gate._arm_from_manager(
            1, 1, 2, b"p" * 32, b"r" * 32,
            caller="version-manager"
        ))
        self.assertTrue(partial._arm_migration_for_test(1, now))
        self.assertTrue(partial._sync_migration(now))
        retained_deadline = partial.migration_refund_claim_deadline
        self.assertEqual(
            (partial.session_live_count, partial.session_refund_count),
            (8, 8),
        )
        self.assertTrue(partial.migration_gate._abort_from_manager(
            1, 1, 2, b"p" * 32,
            b"r" * 32,
            cancel_manifest_active=True,
            caller="version-manager",
        ))
        self.assertEqual(
            (partial.session_live_count, partial.session_refund_count),
            (8, 8),
        )
        self.assertTrue(all(
            partial.session_cells[cell].refund_claim_deadline
                == retained_deadline
            for cell in range(100, 108)
        ))
        self.assertTrue(all(
            partial.session_cells[cell].tag
                is settlement.DataSessionCellTag.LIVE
            for cell in range(108, 116)
        ))

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

    def test_preactive_target_is_exactly_empty_and_public_mutators_do_nothing(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        shared = settlement.MigrationGate()
        base = settlement.protocol(seat=False)
        target = settlement.Protocol(
            base.canonical,
            base.header_oracle,
            base.forced_queue,
            base.inbox_apply_router,
            settlement_address="preactive-target",
            mode=settlement.Mode.PREACTIVE,
            migration_gate=shared,
            settlement_eth_balance=77,
        )
        before = target.snapshot()
        with self.assertRaises(settlement.DataSessionRevert):
            target.open_session(
                now, addr("preactive"), 0,
                now.timestamp + settlement.DATA_TTL_SECONDS,
                payment=10,
            )
        with self.assertRaises(settlement.DataSessionRevert):
            target.post_data(
                now, "00" * 32, addr("preactive"),
                **self._post_terms(salt=b"preactive"),
            )
        with self.assertRaises(settlement.DataSessionRevert):
            target.seal_session(now, "00" * 32, addr("preactive"))
        self.assertEqual(target.gc_sessions(now), (0, 0, 0, 0))
        with self.assertRaises(settlement.DataSessionRevert):
            target.claim_data_session_refund(
                now, "00" * 32, addr("preactive"),
                settlement.DataSessionBondReceiver(addr("recipient")),
            )
        with self.assertRaises(settlement.DataSessionRevert):
            target.sweep_session_surplus()
        self.assertEqual(target.data_rent_sink.balance, 0)
        self.assertTrue(target.identical(before))
        self.assertEqual(target.settlement_eth_balance, 77)

        dirty = settlement.protocol(seat=False)
        dirty.session_cells[0] = settlement.DataSessionCell(
            settlement.DataSessionCellTag.LIVE,
            settlement.DataSession(
                "dirty", "dirty-owner", now.timestamp,
                cell_index=0,
            ),
        )
        with self.assertRaises(ValueError):
            dirty.__post_init__()

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
        self.assertEqual(len(accounting_raw), 512)
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

    def test_historical_and_ready_refund_only_maintenance(self):
        now = settlement.Clock(1_000, settlement.GENESIS_TIMESTAMP + 1_000)
        ready = settlement.protocol(seat=False)
        ready.migration_gate.mode = "READY"
        ready._install_data_session_for_test(
            settlement.DataSession(
                "ready-refund", "ready-owner", now.timestamp,
                refundable_bond=1,
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp,
        )
        self.assertEqual(ready.gc_sessions(settlement.Clock(
            now.block_number + 1, now.timestamp + 1
        )), (settlement.SESSION_MAINTENANCE_SCANNED, 8, 1, 8))

        rows = production_migration_fixture()
        old_protocol = rows[0]
        activate_production_fixture(rows)
        self.assertEqual(rows[1].mode, "FROZEN")
        old_protocol._install_data_session_for_test(
            settlement.DataSession(
                "historical-refund", "historical-owner", now.timestamp,
                refundable_bond=1,
            ),
            0,
            tag=settlement.DataSessionCellTag.REFUND,
            refund_claim_deadline=now.timestamp,
        )
        self.assertEqual(old_protocol.gc_sessions(settlement.Clock(
            now.block_number + 1, now.timestamp + 1
        )), (settlement.SESSION_MAINTENANCE_SCANNED, 8, 1, 8))
        self.assertEqual(old_protocol.session_occupied_count, 0)

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
        exact_digest = settlement.candidate_inbox_execution_digest(candidate)
        for substituted in (
            replace(candidate, tier=settlement.Tier.RECOVERY_SIGNED),
            replace(candidate, reward_execution_gas=8),
            replace(candidate, reward_published_bytes=12),
        ):
            self.assertNotEqual(
                settlement.candidate_inbox_execution_digest(substituted),
                exact_digest,
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

        preactive = reward_protocol(self.rows)
        preactive.mode = settlement.Mode.PREACTIVE
        with self.assertRaises(settlement.RewardFundingRevert):
            preactive.fund_reward_class_v1(
                1, 1, funder=addr("preactive-funder")
            )
        self.assertEqual(preactive.reward_accounting_events, [])
        self.assertEqual(preactive.reward_funded_by_class, {1: 0, 2: 0, 3: 0})
        self.assertEqual(preactive.total_reward_funding, 0)
        self.assertEqual(preactive.settlement_eth_balance, 0)
        historical = reward_protocol(self.rows)
        historical.versioned_history = object()
        historical_event = historical.fund_reward_class_v1(
            1, 1, funder=addr("historical-funder")
        )
        self.assertEqual(historical_event, settlement.RewardClassFundedV1(
            1, addr("historical-funder"), 1, 1, 1
        ))

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

    def test_profile_timings_and_registry_rows_have_one_authority_each(self):
        self.assertNotIn(
            "reward_configuration", settlement.Protocol.__dataclass_fields__
        )
        self.assertFalse(hasattr(settlement, "RewardConfigurationV1"))
        standalone = settlement.protocol(seat=False)
        self.assertEqual((
            standalone.refund_claim_window_seconds,
            standalone.reward_reorg_margin_seconds,
        ), (
            settlement.REWARD_CLAIM_WINDOW_SECONDS,
            settlement.REORG_MARGIN_SECONDS,
        ))
        settlement.routed_ingress_for_test(standalone)
        words = settlement._execution_profile_abi_words_v2(
            standalone.versioned_history.execution_profile
                .canonical_profile_bytes
        )
        self.assertEqual(
            int.from_bytes(words[106], "big"),
            standalone.refund_claim_window_seconds,
        )
        self.assertEqual(
            int.from_bytes(words[85], "big"),
            standalone.reward_reorg_margin_seconds,
        )
        self.assertTrue(standalone._reward_profile_bindings_valid_v1())

        mismatched = reward_protocol(
            self.rows, claim_window_seconds=5, reorg_margin_seconds=10
        )
        candidate = reward_candidate(
            mismatched, self.committed_at, "profile-timing-mismatch"
        )
        settlement.routed_ingress_for_test(mismatched)
        self.assertFalse(mismatched._reward_profile_bindings_valid_v1())
        with self.assertRaises(AssertionError):
            mismatched._record_reward_receipt_v1(
                candidate, self.committed_at
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
