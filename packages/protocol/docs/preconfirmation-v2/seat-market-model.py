#!/usr/bin/env python3
"""Executable model for the bounded perpetual seat reverse auction.

The model owns waiting offers, SLA bonds, premium reserves, exact pull credits,
installed-bond release and breach enforcement.  Canonical lineup/duty authority
is deliberately represented only by immutable exact-view inputs: Task 4 composes
these Market primitives with the Settlement model in one simulated revert domain.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field
from enum import Enum
from functools import lru_cache
from pathlib import Path
import re
import runpy
from types import MappingProxyType
from typing import Callable


UINT256_MAX = (1 << 256) - 1
UINT64_MAX = (1 << 64) - 1
PENDING_COUNT = 4
MAX_STAGE = 1
PROTOCOL_VERSION_BITS = 64
SEAT_GENERATION_BITS = 64
LOOKAHEAD = runpy.run_path(str(Path(__file__).with_name("lookahead-model.py")))
keccak256 = LOOKAHEAD["keccak256"]

_CANONICAL_ADDRESS = re.compile(r"0x[0-9a-f]{40}\Z")
D_AUTHORIZATION = b"TAIKO_SEAT_TARGET_AUTHORIZATION_V1"
D_TRANCHE = b"TAIKO_SEAT_TRANCHE_V1"
D_OFFER = b"TAIKO_SEAT_OFFER_V1"
D_CREDIT = b"TAIKO_SEAT_BOND_CREDIT_V1"
D_PREMIUM_CREDIT = b"TAIKO_SEAT_PREMIUM_CREDIT_V1"
D_STAGE = b"TAIKO_SEAT_STAGE_V1"
TARGET_VIEW_RESPONSE_LENGTH = 20 + 32 + 8 + 32 + 32 + 4 + 1 + 8


class TransitionRejected(Exception):
    """A state transition did not satisfy its exact preconditions."""


class ArithmeticFault(TransitionRejected):
    """Checked uint256 arithmetic failed."""


def _uint(value: int, name: str = "value") -> int:
    if type(value) is not int:
        raise ArithmeticFault(f"{name} is not a uint256")
    if value < 0 or value > UINT256_MAX:
        raise ArithmeticFault(f"{name} is outside uint256")
    return value


def checked_add(left: int, right: int) -> int:
    left = _uint(left, "left operand")
    right = _uint(right, "right operand")
    result = left + right
    if result > UINT256_MAX:
        raise ArithmeticFault("uint256 addition overflow")
    return result


def checked_sub(left: int, right: int) -> int:
    left = _uint(left, "left operand")
    right = _uint(right, "right operand")
    if right > left:
        raise ArithmeticFault("uint256 subtraction underflow")
    return left - right


def checked_mul(left: int, right: int) -> int:
    left = _uint(left, "left operand")
    right = _uint(right, "right operand")
    result = left * right
    if result > UINT256_MAX:
        raise ArithmeticFault("uint256 multiplication overflow")
    return result


def u8(value: int) -> bytes:
    value = _uint(value)
    if value >= 1 << 8:
        raise ArithmeticFault("value is outside uint8")
    return value.to_bytes(1, "big")


def u64(value: int) -> bytes:
    value = _uint(value)
    if value > UINT64_MAX:
        raise ArithmeticFault("value is outside uint64")
    return value.to_bytes(8, "big")


def u256(value: int) -> bytes:
    return _uint(value).to_bytes(32, "big")


def _bytes32(value: bytes, name: str) -> bytes:
    if type(value) is not bytes or len(value) != 32:
        raise TransitionRejected(f"{name} must be exact bytes32")
    return value


def _bytes4(value: bytes, name: str) -> bytes:
    if type(value) is not bytes or len(value) != 4:
        raise TransitionRejected(f"{name} must be exact bytes4")
    return value


def _canonical_address(value: str, name: str) -> str:
    if type(value) is not str or _CANONICAL_ADDRESS.fullmatch(value) is None:
        raise TransitionRejected(f"{name} is not a canonical address")
    if value == "0x" + "00" * 20:
        raise TransitionRejected(f"{name} must be nonzero")
    return value


def address20(value: str, name: str = "address") -> bytes:
    return bytes.fromhex(_canonical_address(value, name)[2:])


@lru_cache(maxsize=None)
def hash_fixed(domain: bytes, *fields: bytes) -> bytes:
    """Legacy Keccak over one ASCII domain and already-fixed-width fields."""

    if (
        type(domain) is not bytes
        or len(domain) == 0
        or any(byte < 0x20 or byte > 0x7E for byte in domain)
    ):
        raise TransitionRejected("hash domain must be nonempty ASCII bytes")
    for field_value in fields:
        if type(field_value) is not bytes:
            raise TransitionRejected("codec field must be exact bytes")
    return keccak256(domain + b"".join(fields))


class OfferLocation(Enum):
    NONE = 0
    PENDING = 1
    STAGED = 2


class TrancheUsage(Enum):
    OFFER = 1
    STAGED = 2
    INSTALLED = 3
    CLOSED_UNINSTALLED = 4


class BondDisposition(Enum):
    NONE = 0
    OWNER_CREDITED = 1
    PENALTY_CREDITED = 2


class ReserveLifecycle(Enum):
    ABSENT = 0
    UNSTARTED = 1
    OPEN = 2
    CLOSED_TAIL = 3


class ResultCode(Enum):
    STAGED = 1
    NO_FEASIBLE_OFFER = 2
    UNDERFUNDED = 3


# Exact Section 4.4 lifecycle freeze for the Market transitions introduced in
# Task 3.  Tests pair this normative table with reachable-state fixtures and
# introspection over the complete public mutation surface.
TASK3_EVENT_FREEZE = MappingProxyType({
    "stage_best": (
        (OfferLocation.PENDING, TrancheUsage.OFFER, BondDisposition.NONE),
        (OfferLocation.STAGED, TrancheUsage.STAGED, BondDisposition.NONE),
    ),
    "expire_stage": (
        (OfferLocation.STAGED, TrancheUsage.STAGED, BondDisposition.NONE),
        (OfferLocation.PENDING, TrancheUsage.OFFER, BondDisposition.NONE),
    ),
    "invalidate_stage": (
        (OfferLocation.STAGED, TrancheUsage.STAGED, BondDisposition.NONE),
        (OfferLocation.PENDING, TrancheUsage.OFFER, BondDisposition.NONE),
    ),
    "cancel_stage_for_migration": (
        (OfferLocation.STAGED, TrancheUsage.STAGED, BondDisposition.NONE),
        (
            OfferLocation.NONE,
            TrancheUsage.CLOSED_UNINSTALLED,
            BondDisposition.OWNER_CREDITED,
        ),
    ),
    "install_stage": (
        (OfferLocation.STAGED, TrancheUsage.STAGED, BondDisposition.NONE),
        (OfferLocation.NONE, TrancheUsage.INSTALLED, BondDisposition.NONE),
    ),
    "request_release": (
        (OfferLocation.NONE, TrancheUsage.INSTALLED, BondDisposition.NONE),
        (OfferLocation.NONE, TrancheUsage.INSTALLED, BondDisposition.NONE),
    ),
    "finalize_release": (
        (OfferLocation.NONE, TrancheUsage.INSTALLED, BondDisposition.NONE),
        (
            OfferLocation.NONE,
            TrancheUsage.INSTALLED,
            BondDisposition.OWNER_CREDITED,
        ),
    ),
    "enforce_breach": (
        (OfferLocation.NONE, TrancheUsage.INSTALLED, BondDisposition.NONE),
        (
            OfferLocation.NONE,
            TrancheUsage.INSTALLED,
            BondDisposition.PENALTY_CREDITED,
        ),
    ),
})


@dataclass(frozen=True)
class Clock:
    timestamp: int
    block_number: int


@dataclass
class BondTranche:
    tranche_id: bytes
    operator: str
    bond_amount: int
    creation_sequence: int
    authorization_id: bytes
    generation: int
    usage: TrancheUsage
    disposition: BondDisposition = BondDisposition.NONE
    current_offer_id: bytes | None = None
    installed_term_id: bytes | None = None
    pending_refund_at: int | None = None
    release_requested_at: int | None = None
    terminalized_at: int | None = None
    terminal_horizon_at: int | None = None


@dataclass
class Offer:
    offer_id: bytes
    tranche_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    eligible_at_timestamp: int
    eligible_at_block: int
    quote_sequence: int
    target: str
    authorization_id: bytes
    generation: int
    location: OfferLocation = OfferLocation.PENDING

    @property
    def order_key(self) -> tuple[int, int, int, int, str]:
        return (
            self.ask_wei_per_second,
            self.eligible_at_timestamp,
            self.eligible_at_block,
            self.quote_sequence,
            self.operator,
        )


@dataclass
class Stage:
    stage_id: bytes
    offer_id: bytes
    selected_rank: int = 0
    outgoing_primary_term_id: bytes | None = None
    lineup_commitment: bytes = b"\x00" * 32
    handover_at: int = 0
    expires_at: int = 0
    reserve_id: bytes | None = None


@dataclass
class ExactCredit:
    credit_id: bytes
    tranche_id: bytes
    beneficiary: str
    amount: int
    disposition: BondDisposition
    claimed: bool = False


@dataclass
class PremiumCredit:
    credit_id: bytes
    reserve_id: bytes
    beneficiary: str
    amount: int
    sequence: int
    claimed: bool = False


@dataclass
class PremiumReserve:
    reserve_id: bytes
    reserved_wei: int
    lifecycle: ReserveLifecycle = ReserveLifecycle.UNSTARTED
    tranche_id: bytes | None = None
    owner_id: bytes | None = None
    term_id: bytes | None = None
    payout: str | None = None
    ask_wei_per_second: int = 0
    premium_funded_until: int | None = None
    last_accrued_at: int | None = None
    settlement_cap: int | None = None
    reserve_mature_at: int | None = None


@dataclass(frozen=True)
class LineupTerm:
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    minimum_tenure_until: int
    service_eligible_until: int
    healthy: bool = True


@dataclass(frozen=True)
class LineupSnapshot:
    target: str
    authorization_id: bytes
    generation: int
    commitment: bytes
    terms: tuple[LineupTerm, ...] = ()


@dataclass(frozen=True)
class InstallationView:
    target: str
    authorization_id: bytes
    generation: int
    stage_id: bytes
    term_id: bytes
    offer_id: bytes
    lineup_commitment: bytes
    applied_at: int


@dataclass(frozen=True)
class ServiceView:
    """Permanent, exact Settlement record used by a Market economic call."""

    target: str
    authorization_id: bytes
    settlement_chain_id: int
    protocol_version: int
    runtime_hash: bytes
    configuration_hash: bytes
    magic: bytes
    generation: int
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    responsibility_start: int | None
    premium_funded_until: int | None
    settlement_cap: int | None
    closed: bool
    refundable: bool = False
    disposition_at: int | None = None
    last_liability_at: int | None = None
    duty_id: bytes | None = None
    duty_disposition: str | None = None
    breached: bool = False
    breach_recorded_at: int | None = None
    roster_occupied: bool = False
    history_retained: bool = True


@dataclass
class MarketAccounting:
    bond_escrow: int = 0
    outstanding_owner_credits: int = 0
    outstanding_penalty_credits: int = 0
    free_premium: int = 0
    reserved_premium: int = 0
    outstanding_premium_claims: int = 0
    live_reserves: dict[bytes, PremiumReserve] = field(default_factory=dict)

    @property
    def accounted_balance(self) -> int:
        total = 0
        for amount in (
            self.bond_escrow,
            self.outstanding_owner_credits,
            self.outstanding_penalty_credits,
            self.free_premium,
            self.reserved_premium,
            self.outstanding_premium_claims,
        ):
            total = checked_add(total, amount)
        return total

    def assert_valid(self, actual_balance: int) -> None:
        actual_balance = _uint(actual_balance, "actual balance")
        for name in (
            "bond_escrow",
            "outstanding_owner_credits",
            "outstanding_penalty_credits",
            "free_premium",
            "reserved_premium",
            "outstanding_premium_claims",
        ):
            _uint(getattr(self, name), name)
        reserve_sum = 0
        for reserve_id, reserve in self.live_reserves.items():
            if not isinstance(reserve_id, bytes) or len(reserve_id) == 0:
                raise AssertionError("invalid reserve key")
            if reserve.reserve_id != reserve_id:
                raise AssertionError("reserve key mismatch")
            reserve_sum = checked_add(reserve_sum, reserve.reserved_wei)
        if self.reserved_premium != reserve_sum:
            raise AssertionError("reserved premium summary mismatch")
        if actual_balance < self.accounted_balance:
            raise AssertionError("actual balance is below accounted balance")


@dataclass(frozen=True)
class TargetAuthorization:
    target: str
    settlement_chain_id: int
    protocol_version: int
    runtime_hash: bytes
    configuration_hash: bytes
    expected_magic: bytes


@dataclass(frozen=True)
class ExactTargetView:
    target: str
    settlement_chain_id: int
    protocol_version: int
    runtime_hash: bytes
    configuration_hash: bytes
    magic: bytes
    phase: str
    generation: int


@dataclass
class TargetRuntime:
    """Read facade bound to one exact Settlement authority object.

    Phase and generation are never stored here. A production read derives both
    from the registered target-local Settlement history/Protocol graph. The
    response/fault fields are deterministic unit-test instrumentation only.
    """

    authorization: TargetAuthorization
    authority: object = field(compare=False)
    fault: str | None = None
    response_override: bytes | None = None
    read_count: int = field(default=0, compare=False)

    def __setattr__(self, name: str, value: object) -> None:
        if name in {"authorization", "authority"} and name in self.__dict__:
            raise AttributeError(f"target runtime {name} is immutable")
        object.__setattr__(self, name, value)

    def read_exact_target(self, target: str) -> bytes:
        self.read_count += 1
        if target != self.authorization.target:
            raise TransitionRejected("runtime read used the wrong target")
        if self.fault == "revert":
            raise RuntimeError("target read reverted")
        if self.fault == "oog":
            raise MemoryError("target read exhausted its bound")
        if self.response_override is not None:
            return self.response_override
        reader = getattr(self.authority, "exact_market_target_state", None)
        if not callable(reader):
            raise TransitionRejected("target authority has no exact read surface")
        row = reader()
        if type(row) is not tuple or len(row) != 8:
            raise TransitionRejected("target authority returned malformed state")
        raw = encode_exact_target_view(ExactTargetView(*row))
        if self.fault == "short":
            return raw[:-1]
        if self.fault == "long":
            return raw + b"\x00"
        if self.fault == "wrong_magic":
            return raw[:124] + b"FAIL" + raw[128:]
        return raw


@dataclass(frozen=True)
class ActivationReceiptView:
    router_generation: int
    old_protocol_version: int
    new_protocol_version: int
    old_target: str
    new_target: str
    target_manifest_hash: bytes
    seat_generation: int
    old_authorization_id: bytes
    new_authorization_id: bytes
    activation_block: int
    migration_stage_id: bytes | None = None
    migration_lineup_commitment: bytes | None = None

    @property
    def key(self) -> tuple[int, bytes]:
        return self.router_generation, self.target_manifest_hash


@dataclass
class ReleaseManager:
    address: str
    activation_authority: object | None = field(default=None, compare=False)
    authorizations: dict[bytes, TargetAuthorization] = field(default_factory=dict)
    target_runtimes: dict[bytes, TargetRuntime] = field(default_factory=dict)
    target_bindings: dict[bytes, tuple[int, str]] = field(default_factory=dict)
    used_target_addresses: set[str] = field(default_factory=set)

    @staticmethod
    def exact_authorization_id(
        market_chain_id: int,
        market_address: str,
        authorization: TargetAuthorization,
    ) -> bytes:
        return authorization_identity(
            market_chain_id, market_address, authorization
        )

    def __setattr__(self, name: str, value: object) -> None:
        if name in {"address", "activation_authority"} and name in self.__dict__:
            raise AttributeError(f"release-manager {name} is immutable")
        object.__setattr__(self, name, value)

    def _is_activation_manager(self, caller: object) -> bool:
        router = self.activation_authority
        return (
            router is not None
            and type(caller) is str
            and caller == getattr(router, "version_manager", None)
        )

    def activation_receipt(
        self, receipt_key: tuple[int, bytes]
    ) -> ActivationReceiptView | None:
        router = self.activation_authority
        receipt = getattr(router, "activation_receipts", {}).get(receipt_key)
        if receipt is None:
            return None
        try:
            return ActivationReceiptView(
                receipt.router_generation,
                receipt.old_protocol_version,
                receipt.new_protocol_version,
                receipt.old_target,
                receipt.new_target,
                receipt.target_manifest_hash,
                receipt.seat_generation,
                receipt.old_authorization_id,
                receipt.new_authorization_id,
                receipt.activation_block,
                receipt.migration_stage_id,
                receipt.migration_lineup_commitment,
            )
        except (AttributeError, TypeError, ValueError):
            return None

    def _register_target(
        self,
        market_chain_id: int,
        market_address: str,
        authorization: TargetAuthorization,
        runtime: TargetRuntime,
    ) -> bytes:
        if runtime.authorization != authorization:
            raise TransitionRejected("target runtime authorization differs")
        authorization_id = authorization_identity(
            market_chain_id, market_address, authorization
        )
        exact_binding = (
            _uint(market_chain_id, "market chain id"),
            _canonical_address(market_address, "market address"),
        )
        if authorization_id in self.authorizations:
            raise TransitionRejected("release-manager target is append-only")
        if authorization.target in self.used_target_addresses:
            raise TransitionRejected("Settlement target address was already registered")
        self.authorizations[authorization_id] = authorization
        self.target_runtimes[authorization_id] = runtime
        self.target_bindings[authorization_id] = exact_binding
        self.used_target_addresses.add(authorization.target)
        return authorization_id

    def register_router_target(
        self,
        caller: str,
        market_chain_id: int,
        market_address: str,
        authorization: TargetAuthorization,
        runtime: TargetRuntime,
    ) -> bytes:
        if not self._is_activation_manager(caller):
            raise TransitionRejected("target registration caller is unauthorized")
        return self._register_target(
            market_chain_id, market_address, authorization, runtime
        )

    def execute_rotation(
        self, market: object, receipt_key: tuple[int, bytes], clock: Clock
    ) -> TransitionResult:
        """Route rotation through the exact old frozen Settlement authority."""

        if getattr(market, "release_manager", None) is not self:
            raise TransitionRejected("rotation Market is not manager-bound")
        receipt = self.activation_receipt(receipt_key)
        if type(receipt) is not ActivationReceiptView:
            raise TransitionRejected("exact activation receipt is absent")
        runtime = self.target_runtimes.get(receipt.old_authorization_id)
        authority = None if runtime is None else runtime.authority
        protocol = None if authority is None else getattr(authority, "live_protocol", None)
        executor = getattr(protocol, "execute_market_target_rotation", None)
        if not callable(executor):
            raise TransitionRejected("rotation lacks old Settlement authority")
        return executor(market, self, receipt_key, clock)


def encode_exact_target_view(view: ExactTargetView) -> bytes:
    if type(view) is not ExactTargetView:
        raise TransitionRejected("malformed target view")
    _canonical_address(view.target, "view target")
    _uint(view.settlement_chain_id, "view settlement chain id")
    protocol_version = u64(view.protocol_version)
    runtime_hash = _bytes32(view.runtime_hash, "view runtime hash")
    config_hash = _bytes32(view.configuration_hash, "view configuration hash")
    magic = _bytes4(view.magic, "view magic")
    phases = {"ACTIVE": 1, "ARMED": 2, "READY": 3, "FROZEN": 4}
    if type(view.phase) is not str or view.phase not in phases:
        raise TransitionRejected("view phase is invalid")
    return b"".join((
        address20(view.target, "view target"),
        u256(view.settlement_chain_id),
        protocol_version,
        runtime_hash,
        config_hash,
        magic,
        bytes((phases[view.phase],)),
        u64(view.generation),
    ))


def decode_exact_target_view(raw: bytes) -> ExactTargetView:
    if type(raw) is not bytes or len(raw) != TARGET_VIEW_RESPONSE_LENGTH:
        raise TransitionRejected("target view has noncanonical length")
    phases = {1: "ACTIVE", 2: "ARMED", 3: "READY", 4: "FROZEN"}
    phase = phases.get(raw[128])
    if phase is None:
        raise TransitionRejected("target view phase is invalid")
    return ExactTargetView(
        target="0x" + raw[:20].hex(),
        settlement_chain_id=int.from_bytes(raw[20:52], "big"),
        protocol_version=int.from_bytes(raw[52:60], "big"),
        runtime_hash=raw[60:92],
        configuration_hash=raw[92:124],
        magic=raw[124:128],
        phase=phase,
        generation=int.from_bytes(raw[129:137], "big"),
    )


def authorization_identity(
    market_chain_id: int, market_address: str, auth: TargetAuthorization
) -> bytes:
    """Commit the exact authorized target identity into one fixed word."""

    if type(auth) is not TargetAuthorization:
        raise TransitionRejected("invalid target authorization")
    return hash_fixed(
        D_AUTHORIZATION,
        u256(market_chain_id),
        address20(market_address, "market address"),
        u256(auth.settlement_chain_id),
        u64(auth.protocol_version),
        address20(auth.target, "authorized target"),
        _bytes32(auth.runtime_hash, "runtime hash"),
        _bytes32(auth.configuration_hash, "configuration hash"),
        _bytes4(auth.expected_magic, "expected magic"),
    )


def tranche_identity(
    authorization_id: bytes,
    generation: int,
    operator: str,
    bond_amount: int,
    creation_sequence: int,
) -> bytes:
    """Encode one immutable bond-tranche identity without dynamic fields."""

    return hash_fixed(
        D_TRANCHE,
        _bytes32(authorization_id, "authorization ID"),
        u64(generation),
        address20(operator, "operator"),
        u256(bond_amount),
        u256(creation_sequence),
    )


def offer_identity(
    authorization_id: bytes,
    generation: int,
    tranche_id: bytes,
    payout: str,
    ask_wei_per_second: int,
    eligible_at_timestamp: int,
    eligible_at_block: int,
    quote_sequence: int,
) -> bytes:
    """Encode one quote identity with the complete immutable quote tuple."""

    return hash_fixed(
        D_OFFER,
        _bytes32(authorization_id, "authorization ID"),
        u64(generation),
        _bytes32(tranche_id, "tranche ID"),
        address20(payout, "payout"),
        u256(ask_wei_per_second),
        u256(eligible_at_timestamp),
        u256(eligible_at_block),
        u256(quote_sequence),
    )


def bond_credit_identity(
    market_chain_id: int,
    market_address: str,
    tranche_id: bytes,
    disposition: BondDisposition,
) -> bytes:
    """Encode the sole OWNER or PENALTY credit for one tranche."""

    if type(disposition) is not BondDisposition or disposition not in (
        BondDisposition.OWNER_CREDITED,
        BondDisposition.PENALTY_CREDITED,
    ):
        raise TransitionRejected("credit disposition must be terminal")
    return hash_fixed(
        D_CREDIT,
        u256(market_chain_id),
        address20(market_address, "market address"),
        _bytes32(tranche_id, "tranche ID"),
        u8(disposition.value),
    )


@dataclass
class TransitionResult:
    offer: Offer | None = None
    tranche: BondTranche | None = None
    displaced_offer_id: bytes | None = None
    credit_id: bytes | None = None
    purged_count: int = 0
    amount: int = 0
    code: ResultCode | None = None
    stage: Stage | None = None
    reserve_id: bytes | None = None
    premium_credit_id: bytes | None = None
    deadline: int | None = None


TransferCallback = Callable[[str, int, "SeatMarket"], None]


class SeatMarket:
    """A small, strict state machine for Task-2 design validation."""

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "_penalty_sink",
            "_sla_bond",
            "_immutable_maximum_ask",
            "_seat_runway_seconds",
            "_handover_delay_seconds",
            "_stage_grace_seconds",
            "_maximum_inclusion_seconds",
            "_premium_claim_delay_seconds",
            "_release_challenge_seconds",
            "_reorg_stability_seconds",
            "_evidence_delay_seconds",
            "_release_manager",
        } and name in self.__dict__:
            raise AttributeError(f"{name[1:]} is immutable")
        object.__setattr__(self, name, value)

    def __init__(
        self,
        *,
        market_chain_id: int,
        market_address: str,
        sla_bond: int,
        immutable_maximum_ask: int,
        quote_maturity_seconds: int,
        quote_maturity_blocks: int,
        exit_delay_seconds: int,
        penalty_sink: str,
        authorization: TargetAuthorization,
        insertion_enabled: bool,
        cached_generation: int | None,
        release_manager: ReleaseManager,
        target_runtime: TargetRuntime,
        starting_quote_sequence: int = 0,
        starting_creation_sequence: int = 0,
        seat_runway_seconds: int = 100,
        handover_delay_seconds: int = 5,
        stage_grace_seconds: int = 5,
        maximum_inclusion_seconds: int = 5,
        premium_claim_delay_seconds: int = 10,
        release_challenge_seconds: int = 20,
        reorg_stability_seconds: int = 30,
        evidence_delay_seconds: int = 40,
    ) -> None:
        self.market_chain_id = _uint(market_chain_id, "market chain id")
        self.market_address = _canonical_address(market_address, "market address")
        self._penalty_sink = _canonical_address(penalty_sink, "penalty sink")
        self._sla_bond = _uint(sla_bond, "SLA bond")
        if self._sla_bond == 0:
            raise TransitionRejected("SLA bond must be nonzero")
        self._immutable_maximum_ask = _uint(
            immutable_maximum_ask, "immutable maximum ask"
        )
        self.quote_maturity_seconds = _uint(
            quote_maturity_seconds, "quote maturity seconds"
        )
        self.quote_maturity_blocks = _uint(
            quote_maturity_blocks, "quote maturity blocks"
        )
        self.exit_delay_seconds = _uint(exit_delay_seconds, "exit delay seconds")
        self._seat_runway_seconds = _uint(
            seat_runway_seconds, "seat runway seconds"
        )
        self._handover_delay_seconds = _uint(
            handover_delay_seconds, "handover delay seconds"
        )
        self._stage_grace_seconds = _uint(
            stage_grace_seconds, "stage grace seconds"
        )
        self._maximum_inclusion_seconds = _uint(
            maximum_inclusion_seconds, "maximum inclusion seconds"
        )
        self._premium_claim_delay_seconds = _uint(
            premium_claim_delay_seconds, "premium claim delay seconds"
        )
        self._release_challenge_seconds = _uint(
            release_challenge_seconds, "release challenge seconds"
        )
        self._reorg_stability_seconds = _uint(
            reorg_stability_seconds, "reorg stability seconds"
        )
        self._evidence_delay_seconds = _uint(
            evidence_delay_seconds, "evidence delay seconds"
        )
        exact_quote_sequence = _uint(
            starting_quote_sequence, "starting quote sequence"
        )
        exact_creation_sequence = _uint(
            starting_creation_sequence, "starting creation sequence"
        )
        exact_cached_generation = (
            None
            if cached_generation is None
            else int.from_bytes(u64(cached_generation), "big")
        )
        self._validate_authorization_record(authorization)
        if type(insertion_enabled) is not bool:
            raise TransitionRejected("insertion-enabled flag must be boolean")
        initial_authorization_id = authorization_identity(
            self.market_chain_id, self.market_address, authorization
        )
        if (
            type(release_manager) is not ReleaseManager
            or release_manager.activation_authority is None
        ):
            raise TransitionRejected("release manager must be an exact object")
        _canonical_address(release_manager.address, "release manager")
        if (
            type(target_runtime) is not TargetRuntime
            or target_runtime.authorization != authorization
        ):
            raise TransitionRejected("initial target runtime is not exact")
        if (
            release_manager.authorizations.get(initial_authorization_id)
            != authorization
            or release_manager.target_runtimes.get(initial_authorization_id)
            is not target_runtime
            or release_manager.target_bindings.get(initial_authorization_id)
            != (self.market_chain_id, self.market_address)
            or authorization.target not in release_manager.used_target_addresses
        ):
            raise TransitionRejected("initial target is not manager-authenticated")
        self._release_manager = release_manager
        self.authorizations: dict[bytes, TargetAuthorization] = {
            initial_authorization_id: authorization
        }
        self.target_runtimes: dict[bytes, TargetRuntime] = {
            initial_authorization_id: target_runtime
        }
        self.authorization_enabled: dict[bytes, bool] = {
            initial_authorization_id: insertion_enabled
        }
        self.current_authorization_id = initial_authorization_id
        self.consumed_activation_receipts: set[tuple[int, bytes]] = set()
        self.cached_generation = exact_cached_generation
        self.quote_sequence = exact_quote_sequence
        self.creation_sequence = exact_creation_sequence

        self.offers: dict[bytes, Offer] = {}
        self.tranches: dict[bytes, BondTranche] = {}
        self.credits: dict[bytes, ExactCredit] = {}
        self.premium_credits: dict[bytes, PremiumCredit] = {}
        self.pending_offer_ids: list[bytes] = []
        self.stage: Stage | None = None
        self.accounting = MarketAccounting()
        self.actual_balance = 0
        self.premium_credit_sequence = 0
        self.claim_active = False
        self.claim_class: str | None = None
        self.fault_point: str | None = None
        self.assert_valid()

    def __eq__(self, other: object) -> bool:
        return isinstance(other, SeatMarket) and self.__dict__ == other.__dict__

    @property
    def penalty_sink(self) -> str:
        return self._penalty_sink

    @property
    def sla_bond(self) -> int:
        return self._sla_bond

    @property
    def immutable_maximum_ask(self) -> int:
        return self._immutable_maximum_ask

    @property
    def seat_runway_seconds(self) -> int:
        return self._seat_runway_seconds

    @property
    def handover_delay_seconds(self) -> int:
        return self._handover_delay_seconds

    @property
    def stage_grace_seconds(self) -> int:
        return self._stage_grace_seconds

    @property
    def maximum_inclusion_seconds(self) -> int:
        return self._maximum_inclusion_seconds

    @property
    def premium_claim_delay_seconds(self) -> int:
        return self._premium_claim_delay_seconds

    @property
    def release_challenge_seconds(self) -> int:
        return self._release_challenge_seconds

    @property
    def reorg_stability_seconds(self) -> int:
        return self._reorg_stability_seconds

    @property
    def evidence_delay_seconds(self) -> int:
        return self._evidence_delay_seconds

    @property
    def authorization(self) -> TargetAuthorization:
        return self.authorizations[self.current_authorization_id]

    @property
    def release_manager(self) -> ReleaseManager:
        return self._release_manager

    @property
    def insertion_enabled(self) -> bool:
        return self.authorization_enabled[self.current_authorization_id]

    @staticmethod
    def _validate_clock(clock: Clock) -> None:
        if type(clock) is not Clock:
            raise TransitionRejected("invalid clock")
        _uint(clock.timestamp, "clock timestamp")
        _uint(clock.block_number, "clock block number")

    @staticmethod
    def _validate_authorization_record(auth: TargetAuthorization) -> None:
        if type(auth) is not TargetAuthorization:
            raise TransitionRejected("invalid target authorization")
        _canonical_address(auth.target, "authorized target")
        _uint(auth.settlement_chain_id, "settlement chain id")
        u64(auth.protocol_version)
        for name, raw in (
            ("runtime hash", auth.runtime_hash),
            ("configuration hash", auth.configuration_hash),
        ):
            _bytes32(raw, name)
        _bytes4(auth.expected_magic, "expected magic")

    @property
    def pending_count(self) -> int:
        return len(self.pending_offer_ids)

    @property
    def staged_count(self) -> int:
        return 0 if self.stage is None else 1

    @property
    def pending_offers(self) -> list[Offer]:
        return [self.offers[offer_id] for offer_id in self.pending_offer_ids]

    @property
    def surplus(self) -> int:
        return checked_sub(self.actual_balance, self.accounting.accounted_balance)

    def _transaction_snapshot(self) -> dict[str, object]:
        manager = self._release_manager
        runtimes = dict(self.target_runtimes)
        state = copy.deepcopy({
            key: value
            for key, value in self.__dict__.items()
            if key not in {"_release_manager", "target_runtimes"}
        })
        return {
            "state": state,
            "manager": manager,
            "runtimes": runtimes,
            "runtime_states": {
                authorization_id: (
                    runtime.authority,
                    copy.deepcopy({
                        key: value for key, value in runtime.__dict__.items()
                        if key != "authority"
                    }),
                )
                for authorization_id, runtime in runtimes.items()
            },
            "manager_runtime_states": {
                authorization_id: (
                    runtime.authority,
                    copy.deepcopy({
                        key: value for key, value in runtime.__dict__.items()
                        if key != "authority"
                    }),
                )
                for authorization_id, runtime
                in manager.target_runtimes.items()
            },
        }

    def _restore_transaction(self, snapshot: dict[str, object]) -> None:
        runtimes = snapshot["runtimes"]
        runtime_states = snapshot["runtime_states"]
        manager = snapshot["manager"]
        for authorization_id, (authority, state) in snapshot[
            "manager_runtime_states"
        ].items():
            runtime = manager.target_runtimes[authorization_id]
            runtime.__dict__.clear()
            runtime.__dict__.update(state)
            runtime.authority = authority
        for authorization_id, runtime in runtimes.items():
            authority, state = runtime_states[authorization_id]
            runtime.__dict__.clear()
            runtime.__dict__.update(state)
            runtime.authority = authority
        self.__dict__.clear()
        self.__dict__.update(snapshot["state"])
        self._release_manager = manager
        self.target_runtimes = runtimes

    def _atomic(self, transition: Callable[[], TransitionResult]) -> TransitionResult:
        snapshot = self._transaction_snapshot()
        try:
            try:
                self.assert_valid()
            except AssertionError as exc:
                raise TransitionRejected("invalid pre-transition state") from exc
            result = transition()
            self.assert_valid()
            return result
        except BaseException:
            self._restore_transaction(snapshot)
            raise

    def _fault(self, name: str) -> None:
        """Deterministic model-only fault injection; never an authority input."""

        if self.fault_point == name:
            raise RuntimeError(f"injected fault: {name}")

    def sponsor_premium(self, amount: int) -> TransitionResult:
        """Attribute an exact native-ETH sponsorship to the free-premium bucket."""

        def transition() -> TransitionResult:
            value = _uint(amount, "premium sponsorship")
            self.actual_balance = checked_add(self.actual_balance, value)
            self.accounting.free_premium = checked_add(
                self.accounting.free_premium, value
            )
            return TransitionResult(amount=value)

        return self._atomic(transition)

    @staticmethod
    def _validate_lineup(snapshot: LineupSnapshot) -> None:
        if type(snapshot) is not LineupSnapshot:
            raise TransitionRejected("malformed lineup snapshot")
        _canonical_address(snapshot.target, "lineup target")
        _bytes32(snapshot.authorization_id, "lineup authorization ID")
        u64(snapshot.generation)
        _bytes32(snapshot.commitment, "lineup commitment")
        if type(snapshot.terms) is not tuple or len(snapshot.terms) > 4:
            raise TransitionRejected("lineup exceeds fixed four-term geometry")
        seen: set[bytes] = set()
        for term in snapshot.terms:
            if type(term) is not LineupTerm:
                raise TransitionRejected("malformed lineup term")
            _bytes32(term.term_id, "lineup term ID")
            _bytes32(term.tranche_id, "lineup tranche ID")
            _bytes32(term.offer_id, "lineup offer ID")
            _canonical_address(term.operator, "lineup operator")
            _canonical_address(term.payout, "lineup payout")
            _uint(term.ask_wei_per_second, "lineup ask")
            _uint(term.minimum_tenure_until, "minimum tenure until")
            _uint(term.service_eligible_until, "service eligible until")
            if type(term.healthy) is not bool:
                raise TransitionRejected("lineup health must be boolean")
            if term.term_id in seen:
                raise TransitionRejected("duplicate lineup term")
            seen.add(term.term_id)

    def _validate_lineup_authority(self, snapshot: LineupSnapshot) -> None:
        self._validate_lineup(snapshot)
        if (
            snapshot.target != self.authorization.target
            or snapshot.authorization_id != self.current_authorization_id
            or self.cached_generation is None
            or snapshot.generation != self.cached_generation
            or not self.insertion_enabled
        ):
            raise TransitionRejected("lineup authority is stale")

    def _validate_service_view(
        self, view: ServiceView, tranche: BondTranche
    ) -> PremiumReserve | None:
        if type(view) is not ServiceView:
            raise TransitionRejected("malformed service view")
        _canonical_address(view.target, "service target")
        _bytes32(view.authorization_id, "service authorization ID")
        _uint(view.settlement_chain_id, "service Settlement chain ID")
        u64(view.protocol_version)
        _bytes32(view.runtime_hash, "service runtime hash")
        _bytes32(view.configuration_hash, "service configuration hash")
        _bytes4(view.magic, "service magic")
        u64(view.generation)
        _bytes32(view.term_id, "service term ID")
        _bytes32(view.tranche_id, "service tranche ID")
        _bytes32(view.offer_id, "service offer ID")
        _canonical_address(view.operator, "service operator")
        _canonical_address(view.payout, "service payout")
        _uint(view.ask_wei_per_second, "service ask")
        for name, value in (
            ("responsibility start", view.responsibility_start),
            ("premium funded until", view.premium_funded_until),
            ("settlement cap", view.settlement_cap),
            ("disposition at", view.disposition_at),
            ("last liability at", view.last_liability_at),
            ("breach recorded at", view.breach_recorded_at),
        ):
            if value is not None:
                _uint(value, name)
        for name, value in (
            ("closed", view.closed),
            ("refundable", view.refundable),
            ("breached", view.breached),
            ("roster occupied", view.roster_occupied),
            ("history retained", view.history_retained),
        ):
            if type(value) is not bool:
                raise TransitionRejected(f"{name} flag must be boolean")
        if view.duty_id is not None:
            _bytes32(view.duty_id, "duty ID")
        if view.duty_disposition is not None and type(view.duty_disposition) is not str:
            raise TransitionRejected("duty disposition must be exact text")
        offer = self.offers.get(tranche.current_offer_id)
        auth = self.authorizations.get(tranche.authorization_id)
        exact = (
            tranche.usage is TrancheUsage.INSTALLED
            and tranche.installed_term_id == view.term_id
            and tranche.tranche_id == view.tranche_id
            and auth is not None
            and view.authorization_id == tranche.authorization_id
            and view.target == auth.target
            and view.settlement_chain_id == auth.settlement_chain_id
            and view.protocol_version == auth.protocol_version
            and view.runtime_hash == auth.runtime_hash
            and view.configuration_hash == auth.configuration_hash
            and view.magic == auth.expected_magic
            and tranche.generation == view.generation
            and offer is not None
            and offer.offer_id == view.offer_id
            and offer.operator == view.operator == tranche.operator
            and offer.payout == view.payout
            and offer.ask_wei_per_second == view.ask_wei_per_second
        )
        if not exact:
            raise TransitionRejected("service view does not match immutable binding")
        return self.accounting.live_reserves.get(view.term_id)

    @staticmethod
    def _validate_installed_duty_view(view: ServiceView) -> None:
        """Fail closed on every installed release/enforcement history tuple."""

        if view.last_liability_at is None:
            raise TransitionRejected(
                "installed term lacks exact last-liability timestamp"
            )
        _uint(view.last_liability_at, "last liability at")
        disposition = view.duty_disposition
        if disposition == "NO_DUTY":
            if (
                view.duty_id is not None
                or view.disposition_at is not None
                or view.breached
                or view.breach_recorded_at is not None
            ):
                raise TransitionRejected("NO_DUTY history is inconsistent")
            return
        if disposition in ("SATISFIED", "EXCUSED", "EXCUSED_MIGRATION"):
            if (
                view.duty_id is None
                or view.disposition_at is None
                or view.breached
                or view.breach_recorded_at is not None
            ):
                raise TransitionRejected("refundable duty history is inconsistent")
            return
        if disposition == "BREACHED":
            if (
                view.duty_id is None
                or view.disposition_at is None
                or not view.breached
                or view.breach_recorded_at is None
                or view.disposition_at != view.breach_recorded_at
            ):
                raise TransitionRejected("breach duty history is inconsistent")
            return
        if disposition == "OPEN":
            if (
                view.duty_id is None
                or view.disposition_at is not None
                or view.breached
                or view.breach_recorded_at is not None
            ):
                raise TransitionRejected("open duty history is inconsistent")
            return
        raise TransitionRejected("unknown installed duty disposition")

    def _require_current_authority(self, target: str, generation: int) -> None:
        if not self.insertion_enabled:
            raise TransitionRejected("offer insertion is disabled")
        if self.cached_generation is None:
            raise TransitionRejected("generation cache is uninitialized")
        _canonical_address(target, "target")
        if target != self.authorization.target:
            raise TransitionRejected("wrong installation target")
        generation_value = int.from_bytes(u64(generation), "big")
        if generation_value != self.cached_generation:
            raise TransitionRejected("stale generation")

    def _validate_exact_target_view(
        self, view: ExactTargetView, *, expected_phase: str = "ACTIVE"
    ) -> int:
        if type(view) is not ExactTargetView:
            raise TransitionRejected("malformed target view")
        _canonical_address(view.target, "view target")
        _uint(view.settlement_chain_id, "view settlement chain id")
        u64(view.protocol_version)
        _bytes32(view.runtime_hash, "view runtime hash")
        _bytes32(view.configuration_hash, "view configuration hash")
        _bytes4(view.magic, "view magic")
        if type(view.phase) is not str or view.phase != expected_phase:
            raise TransitionRejected(f"view phase is not exact {expected_phase}")
        return int.from_bytes(u64(view.generation), "big")

    def _read_authorized_target(
        self, authorization_id: bytes, *, expected_phase: str
    ) -> ExactTargetView:
        auth = self.authorizations.get(authorization_id)
        runtime = self.target_runtimes.get(authorization_id)
        if auth is None or runtime is None:
            raise TransitionRejected("authorized target runtime is absent")
        if (
            self._release_manager.authorizations.get(authorization_id) != auth
            or self._release_manager.target_runtimes.get(authorization_id)
            is not runtime
            or runtime.authorization != auth
        ):
            raise TransitionRejected("authorized target runtime identity changed")
        raw = runtime.read_exact_target(auth.target)
        view = decode_exact_target_view(raw)
        self._validate_exact_target_view(view, expected_phase=expected_phase)
        exact = (
            view.target == auth.target
            and view.settlement_chain_id == auth.settlement_chain_id
            and view.protocol_version == auth.protocol_version
            and view.runtime_hash == auth.runtime_hash
            and view.configuration_hash == auth.configuration_hash
            and view.magic == auth.expected_magic
        )
        if not exact:
            raise TransitionRejected("target view does not match authorization")
        return view

    def _new_tranche_id(
        self,
        operator: str,
        sequence: int,
        authorization_id: bytes,
        generation: int,
    ) -> bytes:
        return tranche_identity(
            authorization_id,
            generation,
            operator,
            self.sla_bond,
            sequence,
        )

    def _new_offer_id(
        self,
        *,
        tranche_id: bytes,
        sequence: int,
        authorization_id: bytes,
        generation: int,
        payout: str,
        ask: int,
        eligible_at_timestamp: int,
        eligible_at_block: int,
    ) -> bytes:
        return offer_identity(
            authorization_id,
            generation,
            tranche_id,
            payout,
            ask,
            eligible_at_timestamp,
            eligible_at_block,
            sequence,
        )

    def credit_id(self, tranche_id: bytes, disposition: BondDisposition) -> bytes:
        return bond_credit_identity(
            self.market_chain_id,
            self.market_address,
            tranche_id,
            disposition,
        )

    def _fresh_quote_sequence(self) -> int:
        sequence = checked_add(self.quote_sequence, 1)
        self.quote_sequence = sequence
        return sequence

    def _fresh_creation_sequence(self) -> int:
        sequence = checked_add(self.creation_sequence, 1)
        self.creation_sequence = sequence
        return sequence

    def _sort_pending(self) -> None:
        self.pending_offer_ids.sort(key=lambda offer_id: self.offers[offer_id].order_key)

    def insert_offer(
        self,
        *,
        caller: str,
        payout: str,
        ask_wei_per_second: int,
        target: str,
        generation: int,
        clock: Clock,
        value: int,
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            operator = _canonical_address(caller, "caller")
            payout_value = _canonical_address(payout, "payout")
            self._validate_clock(clock)
            self._require_current_authority(target, generation)
            ask = _uint(ask_wei_per_second, "ask")
            if ask > self.immutable_maximum_ask:
                raise TransitionRejected("ask exceeds immutable maximum")
            if _uint(value, "inserted value") != self.sla_bond:
                raise TransitionRejected("insertion must escrow exactly one SLA bond")

            creation_sequence = self._fresh_creation_sequence()
            quote_sequence = self._fresh_quote_sequence()
            authorization_id = self.current_authorization_id
            eligible_at_timestamp = checked_add(
                clock.timestamp, self.quote_maturity_seconds
            )
            eligible_at_block = checked_add(
                clock.block_number, self.quote_maturity_blocks
            )
            tranche_id = self._new_tranche_id(
                operator, creation_sequence, authorization_id, generation
            )
            offer_id = self._new_offer_id(
                tranche_id=tranche_id,
                sequence=quote_sequence,
                authorization_id=authorization_id,
                generation=generation,
                payout=payout_value,
                ask=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
            )
            if tranche_id in self.tranches or offer_id in self.offers:
                raise TransitionRejected("identity collision")
            offer = Offer(
                offer_id=offer_id,
                tranche_id=tranche_id,
                operator=operator,
                payout=payout_value,
                ask_wei_per_second=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
                quote_sequence=quote_sequence,
                target=target,
                authorization_id=authorization_id,
                generation=generation,
            )
            tranche = BondTranche(
                tranche_id=tranche_id,
                operator=operator,
                bond_amount=self.sla_bond,
                creation_sequence=creation_sequence,
                authorization_id=authorization_id,
                generation=generation,
                usage=TrancheUsage.OFFER,
                current_offer_id=offer_id,
            )

            capacity = PENDING_COUNT - self.staged_count
            displaced_offer_id = None
            credit_id = None
            if self.pending_count >= capacity:
                if capacity == 0:
                    raise TransitionRejected("no pending capacity")
                worst = self.pending_offers[-1]
                if not offer.order_key < worst.order_key:
                    raise TransitionRejected("fifth offer does not strictly beat worst")
                displaced_offer_id = worst.offer_id
                displaced_tranche_id = worst.tranche_id
                self.pending_offer_ids.remove(worst.offer_id)
                worst.location = OfferLocation.NONE
                displaced = self.tranches[displaced_tranche_id]
                displaced.usage = TrancheUsage.CLOSED_UNINSTALLED
                credit_id = self._terminalize_owner(displaced_tranche_id)

            self.offers[offer_id] = offer
            self.tranches[tranche_id] = tranche
            self.pending_offer_ids.append(offer_id)
            self._sort_pending()
            self.accounting.bond_escrow = checked_add(
                self.accounting.bond_escrow, self.sla_bond
            )
            self.actual_balance = checked_add(self.actual_balance, value)
            return TransitionResult(
                offer=offer,
                tranche=tranche,
                displaced_offer_id=displaced_offer_id,
                credit_id=credit_id,
            )

        return self._atomic(transition)

    def requote(
        self,
        *,
        caller: str,
        offer_id: bytes,
        payout: str,
        ask_wei_per_second: int,
        target: str,
        generation: int,
        clock: Clock,
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            self._require_current_authority(target, generation)
            old_offer = self.offers.get(offer_id)
            if old_offer is None:
                raise TransitionRejected("unknown or stale offer ID")
            tranche = self.tranches.get(old_offer.tranche_id)
            if tranche is None or tranche.current_offer_id != offer_id:
                raise TransitionRejected("offer/tranche binding mismatch")
            caller_value = _canonical_address(caller, "caller")
            if caller_value != tranche.operator or caller_value != old_offer.operator:
                raise TransitionRejected("only immutable operator may requote")
            if (
                old_offer.location is not OfferLocation.PENDING
                or tranche.usage is not TrancheUsage.OFFER
                or tranche.disposition is not BondDisposition.NONE
                or offer_id not in self.pending_offer_ids
                or tranche.pending_refund_at is not None
            ):
                raise TransitionRejected("requote requires a live pending offer")
            if old_offer.target != target or old_offer.generation != generation:
                raise TransitionRejected("stale offer authority")
            payout_value = _canonical_address(payout, "payout")
            ask = _uint(ask_wei_per_second, "ask")
            if ask > self.immutable_maximum_ask:
                raise TransitionRejected("ask exceeds immutable maximum")
            if ask > old_offer.ask_wei_per_second:
                raise TransitionRejected("ask increase is forbidden")
            if ask == old_offer.ask_wei_per_second and payout_value == old_offer.payout:
                raise TransitionRejected("requote is a no-op")

            quote_sequence = self._fresh_quote_sequence()
            eligible_at_timestamp = checked_add(
                clock.timestamp, self.quote_maturity_seconds
            )
            eligible_at_block = checked_add(
                clock.block_number, self.quote_maturity_blocks
            )
            new_offer_id = self._new_offer_id(
                tranche_id=tranche.tranche_id,
                sequence=quote_sequence,
                authorization_id=tranche.authorization_id,
                generation=tranche.generation,
                payout=payout_value,
                ask=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
            )
            if new_offer_id in self.offers:
                raise TransitionRejected("offer identity collision")
            new_offer = Offer(
                offer_id=new_offer_id,
                tranche_id=tranche.tranche_id,
                operator=tranche.operator,
                payout=payout_value,
                ask_wei_per_second=ask,
                eligible_at_timestamp=eligible_at_timestamp,
                eligible_at_block=eligible_at_block,
                quote_sequence=quote_sequence,
                target=target,
                authorization_id=tranche.authorization_id,
                generation=generation,
            )
            old_offer.location = OfferLocation.NONE
            self.pending_offer_ids.remove(offer_id)
            self.offers[new_offer_id] = new_offer
            self.pending_offer_ids.append(new_offer_id)
            tranche.current_offer_id = new_offer_id
            self._sort_pending()
            return TransitionResult(offer=new_offer, tranche=tranche)

        return self._atomic(transition)

    def request_pending_exit(
        self, caller: str, offer_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            offer = self.offers.get(offer_id)
            if offer is None:
                raise TransitionRejected("unknown or stale offer ID")
            tranche = self.tranches.get(offer.tranche_id)
            if tranche is None or tranche.current_offer_id != offer_id:
                raise TransitionRejected("offer/tranche binding mismatch")
            caller_value = _canonical_address(caller, "caller")
            if caller_value != tranche.operator or caller_value != offer.operator:
                raise TransitionRejected("only immutable operator may exit")
            if (
                offer.location is not OfferLocation.PENDING
                or tranche.usage is not TrancheUsage.OFFER
                or tranche.disposition is not BondDisposition.NONE
                or offer_id not in self.pending_offer_ids
                or tranche.pending_refund_at is not None
            ):
                raise TransitionRejected("pending exit requires a live pending offer")
            offer.location = OfferLocation.NONE
            self.pending_offer_ids.remove(offer_id)
            tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
            tranche.pending_refund_at = checked_add(
                clock.timestamp, self.exit_delay_seconds
            )
            return TransitionResult(offer=offer, tranche=tranche)

        return self._atomic(transition)

    def finalize_pending_exit(
        self, tranche_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(tranche_id)
            if tranche is None:
                raise TransitionRejected("unknown tranche")
            offer = (
                self.offers.get(tranche.current_offer_id)
                if tranche.current_offer_id is not None
                else None
            )
            if (
                tranche.usage is not TrancheUsage.CLOSED_UNINSTALLED
                or tranche.disposition is not BondDisposition.NONE
                or tranche.pending_refund_at is None
                or offer is None
                or offer.location is not OfferLocation.NONE
            ):
                raise TransitionRejected("tranche is not awaiting pending refund")
            if clock.timestamp < tranche.pending_refund_at:
                raise TransitionRejected("pending refund is not mature")
            credit_id = self._terminalize_owner(tranche_id)
            return TransitionResult(
                offer=offer, tranche=tranche, credit_id=credit_id
            )

        return self._atomic(transition)

    def _settlement_stage_best(
        self, snapshot: LineupSnapshot, clock: Clock
    ) -> TransitionResult:
        """Select and reserve the first mature structurally-feasible offer.

        This is a Market-side unit primitive.  Task 4 invokes it only inside a
        two-component transaction together with Settlement stage recording.
        """

        def transition() -> TransitionResult:
            self._validate_clock(clock)
            self._validate_lineup_authority(snapshot)
            if self.stage is not None:
                raise TransitionRejected("one stage already exists")
            free_snapshot = self.accounting.free_premium
            candidate: Offer | None = None
            selected_rank = 0
            outgoing: bytes | None = None
            reserve_wei = 0
            for offer_id in tuple(self.pending_offer_ids[:PENDING_COUNT]):
                offer = self.offers[offer_id]
                tranche = self.tranches[offer.tranche_id]
                if (
                    clock.timestamp < offer.eligible_at_timestamp
                    or clock.block_number < offer.eligible_at_block
                ):
                    continue
                if (
                    offer.location is not OfferLocation.PENDING
                    or tranche.usage is not TrancheUsage.OFFER
                    or tranche.disposition is not BondDisposition.NONE
                    or tranche.pending_refund_at is not None
                    or offer.authorization_id != self.current_authorization_id
                    or offer.generation != snapshot.generation
                ):
                    continue

                terms = snapshot.terms
                structural = False
                rank = 0
                outgoing_term: bytes | None = None
                if len(terms) == 0:
                    structural = True
                else:
                    active = terms[0]
                    if active.healthy:
                        short_handover = checked_add(
                            clock.timestamp, self.handover_delay_seconds
                        )
                        if offer.ask_wei_per_second < active.ask_wei_per_second:
                            expires = checked_add(
                                max(active.minimum_tenure_until, short_handover),
                                self.stage_grace_seconds,
                            )
                            has_headroom = (
                                checked_add(
                                    expires, self.maximum_inclusion_seconds
                                )
                                <= active.service_eligible_until
                            )
                            structural = has_headroom
                            outgoing_term = active.term_id
                            rank = 0
                        elif len(terms) < 4:
                            # Standby fill never reads or waits for the primary's
                            # minimum tenure because it does not replace service.
                            expires = checked_add(
                                short_handover, self.stage_grace_seconds
                            )
                            has_headroom = (
                                checked_add(
                                    expires, self.maximum_inclusion_seconds
                                )
                                <= active.service_eligible_until
                            )
                            structural = has_headroom
                            # Preserve the primary and insert among standby asks.
                            rank = 1
                            while (
                                rank < len(terms)
                                and terms[rank].ask_wei_per_second
                                <= offer.ask_wei_per_second
                            ):
                                rank += 1
                if not structural:
                    continue
                reserve = checked_mul(
                    offer.ask_wei_per_second, self.seat_runway_seconds
                )
                candidate = offer
                selected_rank = rank
                outgoing = outgoing_term
                reserve_wei = reserve
                self._fault("after_candidate_selection")
                if reserve > free_snapshot:
                    return TransitionResult(
                        code=ResultCode.UNDERFUNDED,
                        offer=offer,
                        tranche=tranche,
                        amount=reserve,
                    )
                break

            if candidate is None:
                return TransitionResult(code=ResultCode.NO_FEASIBLE_OFFER)

            handover_floor = checked_add(
                clock.timestamp, self.handover_delay_seconds
            )
            if outgoing is not None:
                handover_at = max(
                    snapshot.terms[0].minimum_tenure_until, handover_floor
                )
            else:
                handover_at = handover_floor
            expires_at = checked_add(handover_at, self.stage_grace_seconds)
            stage_id = hash_fixed(
                D_STAGE,
                self.current_authorization_id,
                u64(snapshot.generation),
                snapshot.commitment,
                candidate.offer_id,
                u256(selected_rank),
                u256(handover_at),
                u256(expires_at),
            )
            reserve_id = stage_id if reserve_wei != 0 else None
            self.accounting.free_premium = checked_sub(
                self.accounting.free_premium, reserve_wei
            )
            self.accounting.reserved_premium = checked_add(
                self.accounting.reserved_premium, reserve_wei
            )
            if reserve_id is not None:
                if reserve_id in self.accounting.live_reserves:
                    raise TransitionRejected("stage reserve identity collision")
                self.accounting.live_reserves[reserve_id] = PremiumReserve(
                    reserve_id=reserve_id,
                    reserved_wei=reserve_wei,
                    lifecycle=ReserveLifecycle.UNSTARTED,
                    tranche_id=candidate.tranche_id,
                    owner_id=stage_id,
                    payout=candidate.payout,
                    ask_wei_per_second=candidate.ask_wei_per_second,
                )
            self._fault("after_reserve_debit")
            self.pending_offer_ids.remove(candidate.offer_id)
            candidate.location = OfferLocation.STAGED
            self._fault("after_offer_location_change")
            tranche = self.tranches[candidate.tranche_id]
            tranche.usage = TrancheUsage.STAGED
            self._fault("after_tranche_usage_change")
            self.stage = Stage(
                stage_id=stage_id,
                offer_id=candidate.offer_id,
                selected_rank=selected_rank,
                outgoing_primary_term_id=outgoing,
                lineup_commitment=snapshot.commitment,
                handover_at=handover_at,
                expires_at=expires_at,
                reserve_id=reserve_id,
            )
            return TransitionResult(
                code=ResultCode.STAGED,
                offer=candidate,
                tranche=tranche,
                stage=self.stage,
                reserve_id=reserve_id,
                amount=reserve_wei,
            )

        return self._atomic(transition)

    def _restore_stage(self, stage_id: bytes) -> TransitionResult:
        stage = self.stage
        if stage is None or stage.stage_id != _bytes32(stage_id, "stage ID"):
            raise TransitionRejected("stage identity mismatch")
        offer = self.offers[stage.offer_id]
        tranche = self.tranches[offer.tranche_id]
        if (
            offer.location is not OfferLocation.STAGED
            or tranche.usage is not TrancheUsage.STAGED
            or tranche.disposition is not BondDisposition.NONE
        ):
            raise TransitionRejected("stage binding is not restorable")
        if self.pending_count >= PENDING_COUNT:
            raise TransitionRejected("reserved stage capacity was consumed")
        if stage.reserve_id is not None:
            reserve = self.accounting.live_reserves.pop(stage.reserve_id, None)
            if (
                reserve is None
                or reserve.lifecycle is not ReserveLifecycle.UNSTARTED
                or reserve.owner_id != stage.stage_id
            ):
                raise TransitionRejected("stage reserve is not exact and unstarted")
            self.accounting.reserved_premium = checked_sub(
                self.accounting.reserved_premium, reserve.reserved_wei
            )
            self.accounting.free_premium = checked_add(
                self.accounting.free_premium, reserve.reserved_wei
            )
        offer.location = OfferLocation.PENDING
        tranche.usage = TrancheUsage.OFFER
        self.pending_offer_ids.append(offer.offer_id)
        self._sort_pending()
        self.stage = None
        self._fault("after_stage_clear")
        return TransitionResult(offer=offer, tranche=tranche, amount=0)

    def _settlement_expire_stage(
        self, stage_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            if self.stage is None or clock.timestamp < self.stage.expires_at:
                raise TransitionRejected("stage has not expired")
            return self._restore_stage(stage_id)

        return self._atomic(transition)

    def _settlement_invalidate_stage(
        self, stage_id: bytes, lineup_commitment: bytes
    ) -> TransitionResult:
        """Reconcile an exact Settlement lineup-invalidation tombstone."""

        def transition() -> TransitionResult:
            if (
                self.stage is None
                or self.stage.lineup_commitment
                != _bytes32(lineup_commitment, "lineup commitment")
            ):
                raise TransitionRejected("lineup tombstone does not bind stage")
            return self._restore_stage(stage_id)

        return self._atomic(transition)

    def _settlement_cancel_stage_for_migration(
        self, stage_id: bytes, lineup_commitment: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            stage = self.stage
            if (
                stage is None
                or stage.stage_id != _bytes32(stage_id, "stage ID")
                or stage.lineup_commitment
                != _bytes32(lineup_commitment, "lineup commitment")
            ):
                raise TransitionRejected("migration tombstone does not bind stage")
            offer = self.offers[stage.offer_id]
            tranche = self.tranches[offer.tranche_id]
            if stage.reserve_id is not None:
                reserve = self.accounting.live_reserves.pop(stage.reserve_id)
                self.accounting.reserved_premium = checked_sub(
                    self.accounting.reserved_premium, reserve.reserved_wei
                )
                self.accounting.free_premium = checked_add(
                    self.accounting.free_premium, reserve.reserved_wei
                )
            offer.location = OfferLocation.NONE
            self._fault("after_offer_location_change")
            tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
            self._fault("after_tranche_usage_change")
            credit_id = self._terminalize_owner(
                tranche.tranche_id, terminalized_at=clock.timestamp
            )
            self.stage = None
            self._fault("after_stage_clear")
            return TransitionResult(
                offer=offer, tranche=tranche, credit_id=credit_id
            )

        return self._atomic(transition)

    def _settlement_install_stage(
        self, view: InstallationView
    ) -> TransitionResult:
        """Consume/rekey the Market half of an exact Settlement installation."""

        def transition() -> TransitionResult:
            stage = self.stage
            if type(view) is not InstallationView:
                raise TransitionRejected("malformed installation view")
            _canonical_address(view.target, "installation target")
            _bytes32(view.authorization_id, "installation authorization ID")
            generation = int.from_bytes(u64(view.generation), "big")
            stage_id = _bytes32(view.stage_id, "stage ID")
            term = _bytes32(view.term_id, "term ID")
            offer_id = _bytes32(view.offer_id, "installation offer ID")
            commitment = _bytes32(
                view.lineup_commitment, "installation lineup commitment"
            )
            applied_at = _uint(view.applied_at, "installation applied at")
            if (
                view.target != self.authorization.target
                or view.authorization_id != self.current_authorization_id
                or self.cached_generation is None
                or generation != self.cached_generation
            ):
                raise TransitionRejected("installation authority is stale")
            if stage is None or stage.stage_id != stage_id:
                raise TransitionRejected("stage identity mismatch")
            if (
                stage.offer_id != offer_id
                or stage.lineup_commitment != commitment
            ):
                raise TransitionRejected("installation view does not bind exact stage")
            if applied_at < stage.handover_at or applied_at > stage.expires_at:
                raise TransitionRejected("installation is outside exact stage interval")
            offer = self.offers[stage.offer_id]
            tranche = self.tranches[offer.tranche_id]
            if (
                offer.location is not OfferLocation.STAGED
                or tranche.usage is not TrancheUsage.STAGED
                or tranche.installed_term_id is not None
                or tranche.disposition is not BondDisposition.NONE
            ):
                raise TransitionRejected("stage is not installable")
            if stage.reserve_id is not None:
                reserve = self.accounting.live_reserves.pop(stage.reserve_id)
                if term in self.accounting.live_reserves:
                    raise TransitionRejected("term reserve identity collision")
                reserve.reserve_id = term
                reserve.owner_id = term
                reserve.term_id = term
                self.accounting.live_reserves[term] = reserve
                self._fault("after_reserve_rekey")
            offer.location = OfferLocation.NONE
            self._fault("after_offer_location_change")
            tranche.usage = TrancheUsage.INSTALLED
            tranche.installed_term_id = term
            self._fault("after_tranche_usage_change")
            self.stage = None
            self._fault("after_stage_clear")
            return TransitionResult(
                offer=offer,
                tranche=tranche,
                reserve_id=term if stage.reserve_id is not None else None,
            )

        return self._atomic(transition)

    def _terminalize_owner(
        self,
        tranche_id: bytes,
        *,
        terminalized_at: int | None = None,
        terminal_horizon_at: int | None = None,
    ) -> bytes:
        return self._terminalize(
            tranche_id,
            BondDisposition.OWNER_CREDITED,
            terminalized_at=terminalized_at,
            terminal_horizon_at=terminal_horizon_at,
        )

    def _terminalize_penalty(
        self,
        tranche_id: bytes,
        *,
        terminalized_at: int | None = None,
        terminal_horizon_at: int | None = None,
    ) -> bytes:
        """Model-only primitive for Task-3 breach tests; not a public transition."""

        return self._terminalize(
            tranche_id,
            BondDisposition.PENALTY_CREDITED,
            terminalized_at=terminalized_at,
            terminal_horizon_at=terminal_horizon_at,
        )

    def _terminalize(
        self,
        tranche_id: bytes,
        disposition: BondDisposition,
        *,
        terminalized_at: int | None = None,
        terminal_horizon_at: int | None = None,
    ) -> bytes:
        tranche = self.tranches.get(tranche_id)
        if tranche is None:
            raise TransitionRejected("unknown tranche")
        if tranche.disposition is not BondDisposition.NONE:
            raise TransitionRejected("bond already terminalized")
        if (
            disposition is BondDisposition.OWNER_CREDITED
            and tranche.usage
            not in (TrancheUsage.CLOSED_UNINSTALLED, TrancheUsage.INSTALLED)
        ):
            raise TransitionRejected("owner credit requires a closed uninstalled tranche")
        if (
            disposition is BondDisposition.PENALTY_CREDITED
            and tranche.usage is not TrancheUsage.INSTALLED
        ):
            raise TransitionRejected("penalty credit requires an installed tranche")
        if disposition not in (
            BondDisposition.OWNER_CREDITED,
            BondDisposition.PENALTY_CREDITED,
        ):
            raise TransitionRejected("invalid terminal disposition")
        credit_id = self.credit_id(tranche_id, disposition)
        if credit_id in self.credits:
            raise TransitionRejected("deterministic credit already exists")
        beneficiary = (
            tranche.operator
            if disposition is BondDisposition.OWNER_CREDITED
            else self.penalty_sink
        )
        credit = ExactCredit(
            credit_id=credit_id,
            tranche_id=tranche_id,
            beneficiary=beneficiary,
            amount=tranche.bond_amount,
            disposition=disposition,
        )
        self.accounting.bond_escrow = checked_sub(
            self.accounting.bond_escrow, tranche.bond_amount
        )
        if disposition is BondDisposition.OWNER_CREDITED:
            self.accounting.outstanding_owner_credits = checked_add(
                self.accounting.outstanding_owner_credits, tranche.bond_amount
            )
        else:
            self.accounting.outstanding_penalty_credits = checked_add(
                self.accounting.outstanding_penalty_credits, tranche.bond_amount
            )
        tranche.disposition = disposition
        if terminalized_at is not None:
            tranche.terminalized_at = _uint(terminalized_at, "terminalized at")
        if terminal_horizon_at is not None:
            tranche.terminal_horizon_at = _uint(
                terminal_horizon_at, "terminal horizon at"
            )
        self.credits[credit_id] = credit
        self._fault("after_credit_creation")
        return credit_id

    def _lazy_start_reserve(
        self, reserve: PremiumReserve, view: ServiceView
    ) -> None:
        if reserve.lifecycle is not ReserveLifecycle.UNSTARTED:
            return
        if view.responsibility_start is None:
            return
        if view.premium_funded_until is None:
            raise TransitionRejected("started service lacks funded-until timestamp")
        expected_funded = checked_add(
            view.responsibility_start, self.seat_runway_seconds
        )
        if view.premium_funded_until != expected_funded:
            raise TransitionRejected("service funded interval is not exact runway")
        expected_reserve = checked_mul(
            view.ask_wei_per_second, self.seat_runway_seconds
        )
        if reserve.reserved_wei != expected_reserve:
            raise TransitionRejected("unstarted reserve differs from exact runway")
        reserve.lifecycle = ReserveLifecycle.OPEN
        reserve.last_accrued_at = view.responsibility_start
        reserve.premium_funded_until = view.premium_funded_until

    def _fresh_premium_credit_sequence(self) -> int:
        self.premium_credit_sequence = checked_add(
            self.premium_credit_sequence, 1
        )
        return self.premium_credit_sequence

    def _credit_premium(
        self, reserve: PremiumReserve, amount: int
    ) -> bytes | None:
        amount = _uint(amount, "premium credit amount")
        if amount == 0:
            return None
        if reserve.payout is None:
            raise TransitionRejected("reserve lost immutable payout")
        if amount > reserve.reserved_wei:
            raise TransitionRejected("premium credit exceeds reserve")
        sequence = self._fresh_premium_credit_sequence()
        credit_id = hash_fixed(
            D_PREMIUM_CREDIT,
            u256(self.market_chain_id),
            address20(self.market_address, "market address"),
            _bytes32(reserve.reserve_id, "reserve ID"),
            address20(reserve.payout, "premium payout"),
            u256(amount),
            u256(sequence),
        )
        if credit_id in self.premium_credits:
            raise TransitionRejected("premium credit identity collision")
        reserve.reserved_wei = checked_sub(reserve.reserved_wei, amount)
        self.accounting.reserved_premium = checked_sub(
            self.accounting.reserved_premium, amount
        )
        self.accounting.outstanding_premium_claims = checked_add(
            self.accounting.outstanding_premium_claims, amount
        )
        self.premium_credits[credit_id] = PremiumCredit(
            credit_id=credit_id,
            reserve_id=reserve.reserve_id,
            beneficiary=reserve.payout,
            amount=amount,
            sequence=sequence,
        )
        self._fault("after_credit_creation")
        return credit_id

    def _settlement_accrue_premium(
        self, view: ServiceView, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(view.tranche_id) if type(view) is ServiceView else None
            if tranche is None:
                raise TransitionRejected("unknown installed tranche")
            reserve = self._validate_service_view(view, tranche)
            if view.closed and view.settlement_cap is None:
                raise TransitionRejected(
                    "closed historical accrual requires its permanent cap"
                )
            if reserve is None:
                if view.ask_wei_per_second != 0:
                    raise TransitionRejected("nonzero ask has no reserve")
                return TransitionResult(tranche=tranche, amount=0)
            self._lazy_start_reserve(reserve, view)
            if reserve.lifecycle is ReserveLifecycle.UNSTARTED:
                return TransitionResult(
                    tranche=tranche, reserve_id=reserve.reserve_id, amount=0
                )
            if reserve.lifecycle is not ReserveLifecycle.OPEN:
                raise TransitionRejected("ordinary accrual requires OPEN reserve")
            if (
                reserve.last_accrued_at is None
                or reserve.premium_funded_until is None
                or view.settlement_cap is None
            ):
                raise TransitionRejected("started reserve lacks exact cap metadata")
            cap = _uint(view.settlement_cap, "Settlement premium cap")
            matured_through = (
                0
                if clock.timestamp < self.premium_claim_delay_seconds
                else checked_sub(clock.timestamp, self.premium_claim_delay_seconds)
            )
            accrue_to = max(
                reserve.last_accrued_at,
                min(matured_through, cap, reserve.premium_funded_until),
            )
            elapsed = checked_sub(accrue_to, reserve.last_accrued_at)
            earned = checked_mul(reserve.ask_wei_per_second, elapsed)
            reserve.last_accrued_at = accrue_to
            credit_id = self._credit_premium(reserve, earned)
            return TransitionResult(
                tranche=tranche,
                reserve_id=reserve.reserve_id,
                premium_credit_id=credit_id,
                amount=earned,
            )

        return self._atomic(transition)

    def _settlement_close_reserve(
        self,
        view: ServiceView,
        clock: Clock,
        *,
        atomic_healthy: bool = True,
    ) -> TransitionResult:
        """Partition a healthy close or reconcile an asynchronous exact close."""

        def transition() -> TransitionResult:
            self._validate_clock(clock)
            if type(atomic_healthy) is not bool:
                raise TransitionRejected("close mode must be boolean")
            tranche = self.tranches.get(view.tranche_id) if type(view) is ServiceView else None
            if tranche is None:
                raise TransitionRejected("unknown installed tranche")
            reserve = self._validate_service_view(view, tranche)
            if not view.closed or view.settlement_cap is None:
                raise TransitionRejected("close requires exact permanent Settlement cap")
            cap = _uint(view.settlement_cap, "Settlement premium cap")
            if reserve is None:
                if view.ask_wei_per_second != 0:
                    raise TransitionRejected("nonzero ask has no reserve")
                return TransitionResult(tranche=tranche, amount=0)
            self._lazy_start_reserve(reserve, view)
            if reserve.lifecycle is ReserveLifecycle.CLOSED_TAIL:
                raise TransitionRejected("reserve already closed to a tail")
            if reserve.lifecycle is ReserveLifecycle.UNSTARTED:
                returned = reserve.reserved_wei
                self.accounting.reserved_premium = checked_sub(
                    self.accounting.reserved_premium, returned
                )
                self.accounting.free_premium = checked_add(
                    self.accounting.free_premium, returned
                )
                del self.accounting.live_reserves[view.term_id]
                return TransitionResult(
                    tranche=tranche, reserve_id=view.term_id, amount=returned
                )
            if (
                reserve.lifecycle is not ReserveLifecycle.OPEN
                or reserve.last_accrued_at is None
                or reserve.premium_funded_until is None
            ):
                raise TransitionRejected("reserve is not reconcilable")
            a = reserve.last_accrued_at
            f = reserve.premium_funded_until
            c = min(cap, f)
            if not a <= c <= f:
                raise TransitionRejected("close interval is nonmonotone")
            mature_at = checked_add(c, self.premium_claim_delay_seconds)
            if not atomic_healthy and clock.timestamp < mature_at:
                raise TransitionRejected("asynchronous reserve is not mature")
            matured_through = (
                0
                if clock.timestamp < self.premium_claim_delay_seconds
                else checked_sub(clock.timestamp, self.premium_claim_delay_seconds)
            )
            m = max(a, min(c, matured_through))
            matured = checked_mul(reserve.ask_wei_per_second, checked_sub(m, a))
            tail = checked_mul(reserve.ask_wei_per_second, checked_sub(c, m))
            unearned = checked_mul(reserve.ask_wei_per_second, checked_sub(f, c))
            if checked_add(checked_add(matured, tail), unearned) != reserve.reserved_wei:
                raise TransitionRejected("premium close partition is not conservative")
            credit_id = self._credit_premium(reserve, matured)
            reserve.reserved_wei = checked_sub(reserve.reserved_wei, unearned)
            self.accounting.reserved_premium = checked_sub(
                self.accounting.reserved_premium, unearned
            )
            self.accounting.free_premium = checked_add(
                self.accounting.free_premium, unearned
            )
            if tail == 0:
                del self.accounting.live_reserves[view.term_id]
            else:
                reserve.lifecycle = ReserveLifecycle.CLOSED_TAIL
                reserve.last_accrued_at = c
                reserve.premium_funded_until = c
                reserve.settlement_cap = c
                reserve.reserve_mature_at = mature_at
            return TransitionResult(
                tranche=tranche,
                reserve_id=view.term_id,
                premium_credit_id=credit_id,
                amount=matured,
                deadline=mature_at,
            )

        return self._atomic(transition)

    def _settlement_reconcile_tail(
        self, term_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            term = _bytes32(term_id, "term ID")
            reserve = self.accounting.live_reserves.get(term)
            if (
                reserve is None
                or reserve.lifecycle is not ReserveLifecycle.CLOSED_TAIL
                or reserve.reserve_mature_at is None
            ):
                raise TransitionRejected("term has no closed premium tail")
            if clock.timestamp < reserve.reserve_mature_at:
                raise TransitionRejected("closed premium tail is not mature")
            amount = reserve.reserved_wei
            credit_id = self._credit_premium(reserve, amount)
            if reserve.reserved_wei != 0:
                raise TransitionRejected("tail credit did not exhaust reserve")
            del self.accounting.live_reserves[term]
            return TransitionResult(
                tranche=self.tranches[reserve.tranche_id],
                reserve_id=term,
                premium_credit_id=credit_id,
                amount=amount,
            )

        return self._atomic(transition)

    def _reserve_mature_at(self, view: ServiceView) -> int:
        reserve = self.accounting.live_reserves.get(view.term_id)
        if reserve is None:
            return 0
        # Start authority is Settlement's permanent service record, never the
        # Market lifecycle sentinel.  A canonically promoted standby may still
        # be locally UNSTARTED on its first release/enforcement call.
        if view.responsibility_start is None:
            if reserve.lifecycle is not ReserveLifecycle.UNSTARTED:
                raise TransitionRejected("started reserve lacks service start")
            return 0
        if view.settlement_cap is None:
            raise TransitionRejected("started reserve lacks Settlement cap")
        return checked_add(view.settlement_cap, self.premium_claim_delay_seconds)

    def _release_times(
        self, tranche: BondTranche, view: ServiceView
    ) -> tuple[int, int, int, int]:
        self._validate_installed_duty_view(view)
        if tranche.release_requested_at is None:
            raise TransitionRejected("release was not requested")
        challenge = checked_add(
            tranche.release_requested_at, self.release_challenge_seconds
        )
        disposition_stable = (
            0
            if view.disposition_at is None
            else checked_add(view.disposition_at, self.reorg_stability_seconds)
        )
        evidence_safe = checked_add(
            checked_add(view.last_liability_at, self.evidence_delay_seconds),
            self.reorg_stability_seconds,
        )
        finalize_at = max(challenge, disposition_stable, evidence_safe)
        reserve_mature_at = self._reserve_mature_at(view)
        return (
            disposition_stable,
            evidence_safe,
            finalize_at,
            max(finalize_at, reserve_mature_at),
        )

    def _settlement_request_release(
        self, tranche_id: bytes, view: ServiceView, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(_bytes32(tranche_id, "tranche ID"))
            if tranche is None:
                raise TransitionRejected("unknown installed tranche")
            self._validate_service_view(view, tranche)
            self._validate_installed_duty_view(view)
            if (
                tranche.usage is not TrancheUsage.INSTALLED
                or tranche.disposition is not BondDisposition.NONE
                or not view.closed
                or not view.refundable
                or view.breached
                or view.duty_disposition
                not in (
                    "SATISFIED",
                    "EXCUSED",
                    "EXCUSED_MIGRATION",
                    "NO_DUTY",
                )
            ):
                raise TransitionRejected("installed tranche is not releasable")
            if tranche.release_requested_at is None:
                tranche.release_requested_at = clock.timestamp
            return TransitionResult(tranche=tranche, deadline=tranche.release_requested_at)

        return self._atomic(transition)

    def _settlement_finalize_release(
        self, tranche_id: bytes, view: ServiceView, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(_bytes32(tranche_id, "tranche ID"))
            if tranche is None:
                raise TransitionRejected("unknown installed tranche")
            self._validate_service_view(view, tranche)
            self._validate_installed_duty_view(view)
            if (
                tranche.usage is not TrancheUsage.INSTALLED
                or tranche.disposition is not BondDisposition.NONE
                or not view.closed
                or not view.refundable
                or view.breached
                or view.duty_disposition
                not in (
                    "SATISFIED",
                    "EXCUSED",
                    "EXCUSED_MIGRATION",
                    "NO_DUTY",
                )
            ):
                raise TransitionRejected("installed release is no longer refundable")
            _, _, _, owner_at = self._release_times(tranche, view)
            if clock.timestamp < owner_at:
                raise TransitionRejected("installed owner release is not mature")
            reserve = self.accounting.live_reserves.get(view.term_id)
            if reserve is not None:
                if reserve.lifecycle is ReserveLifecycle.CLOSED_TAIL:
                    self._settlement_reconcile_tail(view.term_id, clock)
                else:
                    self._settlement_close_reserve(
                        view, clock, atomic_healthy=False
                    )
            if view.term_id in self.accounting.live_reserves:
                raise TransitionRejected("reserve remains live at owner terminalization")
            credit_id = self._terminalize_owner(
                tranche.tranche_id,
                terminalized_at=clock.timestamp,
                terminal_horizon_at=owner_at,
            )
            return TransitionResult(
                tranche=tranche, credit_id=credit_id, deadline=owner_at
            )

        return self._atomic(transition)

    def _settlement_enforce_breach(
        self, tranche_id: bytes, view: ServiceView, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            tranche = self.tranches.get(_bytes32(tranche_id, "tranche ID"))
            if tranche is None:
                raise TransitionRejected("unknown installed tranche")
            self._validate_service_view(view, tranche)
            self._validate_installed_duty_view(view)
            if (
                tranche.usage is not TrancheUsage.INSTALLED
                or tranche.disposition is not BondDisposition.NONE
                or not view.closed
                or not view.breached
                or view.breach_recorded_at is None
                or view.duty_disposition != "BREACHED"
            ):
                raise TransitionRejected("exact stable breach is absent")
            receipt_stable = checked_add(
                view.breach_recorded_at, self.reorg_stability_seconds
            )
            penalty_at = max(receipt_stable, self._reserve_mature_at(view))
            if clock.timestamp < penalty_at:
                raise TransitionRejected("breach penalty is not mature")
            reserve = self.accounting.live_reserves.get(view.term_id)
            if reserve is not None:
                if reserve.lifecycle is ReserveLifecycle.CLOSED_TAIL:
                    self._settlement_reconcile_tail(view.term_id, clock)
                else:
                    self._settlement_close_reserve(
                        view, clock, atomic_healthy=False
                    )
            if view.term_id in self.accounting.live_reserves:
                raise TransitionRejected("reserve remains live at penalty terminalization")
            credit_id = self._terminalize_penalty(
                tranche.tranche_id,
                terminalized_at=clock.timestamp,
                terminal_horizon_at=penalty_at,
            )
            return TransitionResult(
                tranche=tranche, credit_id=credit_id, deadline=penalty_at
            )

        return self._atomic(transition)

    def _settlement_is_duty_history_safe(
        self,
        duty_id: bytes,
        seat_term_id: bytes,
        tranche_id: bytes,
        view: ServiceView,
        clock: Clock,
    ) -> bool:
        """Return the monotone Market reclamation predicate for one exact binding."""

        try:
            self._validate_clock(clock)
            duty = _bytes32(duty_id, "duty ID")
            term = _bytes32(seat_term_id, "seat term ID")
            tranche = self.tranches.get(_bytes32(tranche_id, "tranche ID"))
            if tranche is None:
                return False
            self._validate_service_view(view, tranche)
            self._validate_installed_duty_view(view)
            offer = self.offers[tranche.current_offer_id]
            stage_uses_tranche = False
            if self.stage is not None:
                staged_offer = self.offers.get(self.stage.offer_id)
                stage_uses_tranche = (
                    staged_offer is not None
                    and staged_offer.tranche_id == tranche.tranche_id
                )
            horizon_is_exact = False
            evidence_history_safe_at = checked_add(
                checked_add(view.last_liability_at, self.evidence_delay_seconds),
                self.reorg_stability_seconds,
            )
            if tranche.terminal_horizon_at is not None:
                if tranche.disposition is BondDisposition.OWNER_CREDITED:
                    _, _, finalize_at, _ = self._release_times(tranche, view)
                    horizon_is_exact = tranche.terminal_horizon_at >= finalize_at
                elif (
                    tranche.disposition is BondDisposition.PENALTY_CREDITED
                    and view.breach_recorded_at is not None
                ):
                    horizon_is_exact = tranche.terminal_horizon_at >= checked_add(
                        view.breach_recorded_at, self.reorg_stability_seconds
                    )
            exact = (
                view.duty_id == duty
                and view.term_id == term
                and view.tranche_id == tranche.tranche_id
                and view.history_retained
                and view.closed
                and not view.roster_occupied
                and offer.location is OfferLocation.NONE
                and not stage_uses_tranche
                and term not in self.accounting.live_reserves
                and tranche.usage is TrancheUsage.INSTALLED
                and tranche.disposition
                in (
                    BondDisposition.OWNER_CREDITED,
                    BondDisposition.PENALTY_CREDITED,
                )
                and tranche.terminalized_at is not None
                and tranche.terminal_horizon_at is not None
                and horizon_is_exact
                and clock.timestamp >= tranche.terminal_horizon_at
                and clock.timestamp >= evidence_history_safe_at
            )
            return bool(exact)
        except (TransitionRejected, ArithmeticFault, KeyError, TypeError, ValueError):
            return False

    def sync_seat_generation(self) -> TransitionResult:
        def transition() -> TransitionResult:
            view = self._read_authorized_target(
                self.current_authorization_id, expected_phase="ACTIVE"
            )
            generation = self._validate_exact_target_view(view)
            if self.cached_generation is not None and generation < self.cached_generation:
                raise TransitionRejected("generation cannot decrease")
            if generation == self.cached_generation:
                return TransitionResult(purged_count=0)

            purged = 0
            for offer_id in tuple(self.pending_offer_ids):
                offer = self.offers[offer_id]
                tranche = self.tranches[offer.tranche_id]
                if (
                    offer.location is not OfferLocation.PENDING
                    or tranche.usage is not TrancheUsage.OFFER
                    or tranche.disposition is not BondDisposition.NONE
                ):
                    raise TransitionRejected("corrupt pending cell")
                self.pending_offer_ids.remove(offer_id)
                offer.location = OfferLocation.NONE
                tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
                self._terminalize_owner(tranche.tranche_id)
                purged = checked_add(purged, 1)
            # Cache commits last, after every bounded purge and credit succeeds.
            self.cached_generation = generation
            return TransitionResult(purged_count=purged)

        return self._atomic(transition)

    def _rotate_installation_target(
        self,
        *,
        manager: ReleaseManager,
        receipt_key: tuple[int, bytes],
        clock: Clock,
        migration_stage_authenticated: bool,
    ) -> TransitionResult:
        """Atomically consume one exact manager-owned activation receipt."""

        def transition() -> TransitionResult:
            self._validate_clock(clock)
            if manager is not self._release_manager:
                raise TransitionRejected("rotation missed immutable release manager")
            if (
                type(receipt_key) is not tuple
                or len(receipt_key) != 2
                or type(receipt_key[0]) is not int
                or type(receipt_key[1]) is not bytes
                or len(receipt_key[1]) != 32
            ):
                raise TransitionRejected("rotation receipt key is malformed")
            receipt = manager.activation_receipt(receipt_key)
            if (
                type(receipt) is not ActivationReceiptView
                or receipt.key != receipt_key
                or receipt_key in self.consumed_activation_receipts
                or receipt.old_authorization_id
                != self.current_authorization_id
                or receipt.new_protocol_version <= receipt.old_protocol_version
            ):
                raise TransitionRejected("rotation receipt is stale or mismatched")
            old_auth = self.authorizations.get(receipt.old_authorization_id)
            if (
                old_auth is None
                or receipt.old_target != old_auth.target
                or receipt.old_protocol_version != old_auth.protocol_version
            ):
                raise TransitionRejected("rotation cursor authorization differs")
            new_auth = manager.authorizations.get(receipt.new_authorization_id)
            new_runtime = manager.target_runtimes.get(receipt.new_authorization_id)
            if (
                new_auth is None
                or new_runtime is None
                or receipt.new_target != new_auth.target
                or receipt.new_protocol_version != new_auth.protocol_version
                or authorization_identity(
                    self.market_chain_id, self.market_address, new_auth
                ) != receipt.new_authorization_id
                or (
                    receipt.new_authorization_id in self.authorizations
                    and receipt.new_authorization_id
                    != self.current_authorization_id
                )
            ):
                raise TransitionRejected("new target authorization is not exact")
            old_view = self._read_authorized_target(
                receipt.old_authorization_id, expected_phase="FROZEN"
            )
            # The new target is manager-authorized but not yet Market-current.
            raw_new = new_runtime.read_exact_target(new_auth.target)
            new_view = decode_exact_target_view(raw_new)
            if new_view.phase not in {"ACTIVE", "FROZEN"}:
                raise TransitionRejected("rotation new target is not activated")
            self._validate_exact_target_view(
                new_view, expected_phase=new_view.phase
            )
            if (
                new_view.target != new_auth.target
                or new_view.settlement_chain_id != new_auth.settlement_chain_id
                or new_view.protocol_version != new_auth.protocol_version
                or new_view.runtime_hash != new_auth.runtime_hash
                or new_view.configuration_hash != new_auth.configuration_hash
                or new_view.magic != new_auth.expected_magic
                or old_view.generation != receipt.seat_generation
                or new_view.generation < receipt.seat_generation
            ):
                raise TransitionRejected("rotation target states do not bind receipt")
            router = manager.activation_authority
            if router is None:
                raise TransitionRejected("rotation Router authority is absent")
            if new_view.phase == "ACTIVE":
                registration = getattr(router, "registrations", {}).get(
                    new_auth.protocol_version
                )
                if (
                    getattr(router, "active_version", None)
                    != new_auth.protocol_version
                    or registration is None
                    or registration.settlement is not new_runtime.authority
                ):
                    raise TransitionRejected("ACTIVE rotation tip is not router-current")
            else:
                next_key = getattr(
                    router,
                    "successor_receipt_key_by_old_authorization_id",
                    {},
                ).get(receipt.new_authorization_id)
                next_receipt = manager.activation_receipt(next_key)
                if (
                    next_receipt is None
                    or next_receipt.old_authorization_id
                    != receipt.new_authorization_id
                    or next_receipt.seat_generation != new_view.generation
                ):
                    raise TransitionRejected("FROZEN rotation hop has no exact successor")

            if receipt.migration_stage_id is not None:
                if (
                    not migration_stage_authenticated
                    or receipt.migration_lineup_commitment is None
                    or self.stage is None
                ):
                    raise TransitionRejected("migration stage was not authenticated")
                if (
                    receipt.migration_stage_id != self.stage.stage_id
                    or receipt.migration_lineup_commitment
                    != self.stage.lineup_commitment
                ):
                    raise TransitionRejected("receipt does not bind live stage")
                self._settlement_cancel_stage_for_migration(
                    self.stage.stage_id,
                    self.stage.lineup_commitment,
                    clock,
                )
                self._fault("after_migration_stage_cancellation")
            elif (
                receipt.migration_lineup_commitment is not None
                or migration_stage_authenticated
            ):
                raise TransitionRejected("rotation stage authentication is spurious")

            purged = 0
            for offer_id in tuple(self.pending_offer_ids):
                offer = self.offers[offer_id]
                tranche = self.tranches[offer.tranche_id]
                if (
                    offer.authorization_id != receipt.old_authorization_id
                    or offer.location is not OfferLocation.PENDING
                    or tranche.usage is not TrancheUsage.OFFER
                    or tranche.disposition is not BondDisposition.NONE
                ):
                    raise TransitionRejected("rotation found a corrupt pending cell")
                self.pending_offer_ids.remove(offer_id)
                offer.location = OfferLocation.NONE
                tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
                self._terminalize_owner(
                    tranche.tranche_id, terminalized_at=clock.timestamp
                )
                purged = checked_add(purged, 1)
                self._fault(f"after_rotation_pending_purge_{purged}")

            self.authorization_enabled[receipt.old_authorization_id] = False
            self._fault("after_old_target_disablement")
            self.authorizations[receipt.new_authorization_id] = new_auth
            self.target_runtimes[receipt.new_authorization_id] = new_runtime
            self.authorization_enabled[receipt.new_authorization_id] = (
                new_view.phase == "ACTIVE"
            )
            self._fault("after_new_target_enablement")
            self.cached_generation = None
            self._fault("after_generation_cache_reset")
            # The single current authorization is also the bounded rotation
            # cursor.  An intermediate FROZEN hop is current but disabled;
            # only the exact ACTIVE router tip becomes installable.
            self.current_authorization_id = receipt.new_authorization_id
            self._fault("after_current_target_update")
            self.consumed_activation_receipts.add(receipt_key)
            self._fault("after_activation_receipt_consumption")
            return TransitionResult(purged_count=purged)

        return self._atomic(transition)

    def claim_credit(
        self, credit_id: bytes, transfer: TransferCallback
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            if self.claim_active and self.claim_class != "BOND":
                raise TransitionRejected("credit claim reentrancy")
            credit = self.credits.get(credit_id)
            if credit is None:
                raise TransitionRejected("unknown exact credit")
            if credit.claimed:
                raise TransitionRejected("exact credit already claimed")
            if credit.amount == 0:
                raise TransitionRejected("zero credit cannot be claimed")
            if not callable(transfer):
                raise TransitionRejected("transfer callback is not callable")

            # Effects precede interaction.  Any exception restores the complete
            # pre-call snapshot, including successful nested model transitions.
            previous_active = self.claim_active
            previous_class = self.claim_class
            self.claim_active = True
            self.claim_class = "BOND"
            credit.claimed = True
            if credit.disposition is BondDisposition.OWNER_CREDITED:
                self.accounting.outstanding_owner_credits = checked_sub(
                    self.accounting.outstanding_owner_credits, credit.amount
                )
            elif credit.disposition is BondDisposition.PENALTY_CREDITED:
                self.accounting.outstanding_penalty_credits = checked_sub(
                    self.accounting.outstanding_penalty_credits, credit.amount
                )
            else:
                raise TransitionRejected("credit has nonterminal disposition")
            self.actual_balance = checked_sub(self.actual_balance, credit.amount)
            transfer(credit.beneficiary, credit.amount, self)
            self.claim_active = previous_active
            self.claim_class = previous_class
            return TransitionResult(
                tranche=self.tranches[credit.tranche_id],
                credit_id=credit_id,
                amount=credit.amount,
            )

        return self._atomic(transition)

    def claim_premium_credit(
        self, credit_id: bytes, transfer: TransferCallback
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            if self.claim_active:
                raise TransitionRejected("credit claim reentrancy")
            credit = self.premium_credits.get(credit_id)
            if credit is None:
                raise TransitionRejected("unknown premium credit")
            if credit.claimed:
                raise TransitionRejected("premium credit already claimed")
            if credit.amount == 0:
                raise TransitionRejected("zero premium credit cannot be claimed")
            if not callable(transfer):
                raise TransitionRejected("transfer callback is not callable")
            self.claim_active = True
            self.claim_class = "PREMIUM"
            credit.claimed = True
            self.accounting.outstanding_premium_claims = checked_sub(
                self.accounting.outstanding_premium_claims, credit.amount
            )
            self.actual_balance = checked_sub(self.actual_balance, credit.amount)
            transfer(credit.beneficiary, credit.amount, self)
            self.claim_active = False
            self.claim_class = None
            return TransitionResult(
                premium_credit_id=credit_id, amount=credit.amount
            )

        return self._atomic(transition)

    def force_eth(self, amount: int) -> None:
        snapshot = self._transaction_snapshot()
        try:
            try:
                self.assert_valid()
            except AssertionError as exc:
                raise TransitionRejected("invalid pre-transition state") from exc
            self.actual_balance = checked_add(self.actual_balance, amount)
            self.assert_valid()
        except BaseException:
            self._restore_transaction(snapshot)
            raise

    def assert_valid(self) -> None:
        try:
            self._assert_valid()
        except (TransitionRejected, KeyError, TypeError, ValueError) as exc:
            raise AssertionError(str(exc)) from exc

    def _assert_valid(self) -> None:
        _uint(self.market_chain_id, "market chain id")
        _canonical_address(self.market_address, "market address")
        _canonical_address(self.penalty_sink, "penalty sink")
        if self.sla_bond == 0:
            raise AssertionError("SLA bond must be nonzero")
        _uint(self.sla_bond, "SLA bond")
        _uint(self.quote_sequence, "quote sequence")
        _uint(self.creation_sequence, "creation sequence")
        _uint(self.premium_credit_sequence, "premium credit sequence")
        if type(self.claim_active) is not bool:
            raise AssertionError("claim reentrancy flag is not boolean")
        if self.claim_class not in (None, "BOND", "PREMIUM"):
            raise AssertionError("unknown claim reentrancy class")
        if self.claim_active != (self.claim_class is not None):
            raise AssertionError("claim reentrancy state is inconsistent")
        known_faults = {
            None,
            "after_candidate_selection",
            "after_reserve_debit",
            "after_offer_location_change",
            "after_reserve_rekey",
            "after_tranche_usage_change",
            "after_credit_creation",
            "after_stage_clear",
            "after_migration_stage_cancellation",
            "after_rotation_pending_purge_1",
            "after_rotation_pending_purge_2",
            "after_rotation_pending_purge_3",
            "after_rotation_pending_purge_4",
            "after_old_target_disablement",
            "after_new_target_enablement",
            "after_generation_cache_reset",
            "after_current_target_update",
            "after_activation_receipt_consumption",
            "after_migration_tombstone_ack",
        }
        if self.fault_point not in known_faults:
            raise AssertionError("unknown model-only fault point")
        _bytes32(self.current_authorization_id, "current authorization ID")
        if set(self.authorizations) != set(self.authorization_enabled):
            raise AssertionError("authorization registry/enabled keys differ")
        if set(self.authorizations) != set(self.target_runtimes):
            raise AssertionError("authorization/runtime keys differ")
        if type(self._release_manager) is not ReleaseManager:
            raise AssertionError("immutable release manager object changed")
        if self.current_authorization_id not in self.authorizations:
            raise AssertionError("current authorization is not registered")
        for authorization_id, auth in self.authorizations.items():
            _bytes32(authorization_id, "registered authorization ID")
            self._validate_authorization_record(auth)
            if (
                authorization_identity(
                    self.market_chain_id, self.market_address, auth
                )
                != authorization_id
            ):
                raise AssertionError("registered immutable authorization changed")
            if type(self.authorization_enabled[authorization_id]) is not bool:
                raise AssertionError("authorization enabled state is not boolean")
            runtime = self.target_runtimes[authorization_id]
            if (
                type(runtime) is not TargetRuntime
                or runtime.authorization != auth
                or self._release_manager.authorizations.get(authorization_id)
                != auth
                or self._release_manager.target_runtimes.get(authorization_id)
                is not runtime
                or self._release_manager.target_bindings.get(authorization_id)
                != (self.market_chain_id, self.market_address)
            ):
                raise AssertionError("authorization runtime route changed")
        for receipt_key in self.consumed_activation_receipts:
            if self._release_manager.activation_receipt(receipt_key) is None:
                raise AssertionError("consumed activation receipt is unknown")
        if self._release_manager.used_target_addresses != {
            auth.target for auth in self._release_manager.authorizations.values()
        }:
            raise AssertionError("release-manager target reverse index differs")
        if self.cached_generation is not None:
            u64(self.cached_generation)
        if self.staged_count > MAX_STAGE:
            raise AssertionError("more than one stage")
        if self.pending_count + self.staged_count > PENDING_COUNT:
            raise AssertionError("shared pending/staged capacity exceeded")
        if len(set(self.pending_offer_ids)) != self.pending_count:
            raise AssertionError("duplicate pending cell")
        pending_ids = set(self.pending_offer_ids)
        for offer_id in self.pending_offer_ids:
            _bytes32(offer_id, "pending offer ID")
            if offer_id not in self.offers:
                raise AssertionError("pending cell references unknown offer")
        if self.pending_offer_ids != sorted(
            self.pending_offer_ids, key=lambda offer_id: self.offers[offer_id].order_key
        ):
            raise AssertionError("pending book is not in complete deterministic order")
        staged_offer_id = None
        if self.stage is not None:
            _bytes32(self.stage.stage_id, "stage ID")
            _bytes32(self.stage.offer_id, "staged offer ID")
            _uint(self.stage.selected_rank, "selected rank")
            if self.stage.selected_rank >= 4:
                raise AssertionError("selected rank exceeds fixed lineup")
            if self.stage.outgoing_primary_term_id is not None:
                _bytes32(
                    self.stage.outgoing_primary_term_id,
                    "outgoing primary term ID",
                )
            _bytes32(self.stage.lineup_commitment, "lineup commitment")
            _uint(self.stage.handover_at, "handover at")
            _uint(self.stage.expires_at, "stage expires at")
            if self.stage.expires_at < self.stage.handover_at:
                raise AssertionError("stage expiry precedes handover")
            if self.stage.reserve_id is not None:
                _bytes32(self.stage.reserve_id, "stage reserve ID")
                stage_reserve = self.accounting.live_reserves.get(
                    self.stage.reserve_id
                )
                if (
                    stage_reserve is None
                    or stage_reserve.lifecycle is not ReserveLifecycle.UNSTARTED
                    or stage_reserve.owner_id != self.stage.stage_id
                ):
                    raise AssertionError("stage reserve binding mismatch")
            staged_offer_id = self.stage.offer_id
            staged_offer = self.offers.get(self.stage.offer_id)
            if staged_offer is None or staged_offer.location is not OfferLocation.STAGED:
                raise AssertionError("stage does not bind a staged offer")
            staged_tranche = self.tranches.get(staged_offer.tranche_id)
            if (
                staged_tranche is None
                or staged_tranche.usage is not TrancheUsage.STAGED
                or staged_tranche.current_offer_id != staged_offer.offer_id
                or staged_tranche.disposition is not BondDisposition.NONE
            ):
                raise AssertionError("stage/tranche state mismatch")

        quote_sequences: set[int] = set()
        for offer_id, offer in self.offers.items():
            _bytes32(offer_id, "offer key")
            if offer.offer_id != offer_id:
                raise AssertionError("offer key mismatch")
            _bytes32(offer.tranche_id, "offer tranche ID")
            _bytes32(offer.authorization_id, "offer authorization ID")
            _canonical_address(offer.operator, "offer operator")
            _canonical_address(offer.payout, "offer payout")
            _canonical_address(offer.target, "offer target")
            _uint(offer.ask_wei_per_second, "offer ask")
            _uint(offer.eligible_at_timestamp, "offer eligible timestamp")
            _uint(offer.eligible_at_block, "offer eligible block")
            _uint(offer.quote_sequence, "offer quote sequence")
            u64(offer.generation)
            if offer.quote_sequence in quote_sequences:
                raise AssertionError("quote sequence was reused")
            quote_sequences.add(offer.quote_sequence)
            if offer.quote_sequence > self.quote_sequence:
                raise AssertionError("offer quote sequence exceeds counter")
            expected_offer_id = self._new_offer_id(
                tranche_id=offer.tranche_id,
                sequence=offer.quote_sequence,
                authorization_id=offer.authorization_id,
                generation=offer.generation,
                payout=offer.payout,
                ask=offer.ask_wei_per_second,
                eligible_at_timestamp=offer.eligible_at_timestamp,
                eligible_at_block=offer.eligible_at_block,
            )
            if expected_offer_id != offer_id:
                raise AssertionError("offer ID does not commit immutable fields")
            tranche = self.tranches.get(offer.tranche_id)
            if tranche is None:
                raise AssertionError("offer references unknown tranche")
            if offer.operator != tranche.operator:
                raise AssertionError("offer/tranche operator mismatch")
            auth = self.authorizations.get(offer.authorization_id)
            if auth is None:
                raise AssertionError("offer authorization is not registered")
            if (
                offer.authorization_id != tranche.authorization_id
                or offer.generation != tranche.generation
                or offer.target != auth.target
            ):
                raise AssertionError("offer/tranche authority mismatch")

            is_current = tranche.current_offer_id == offer_id
            in_pending = offer_id in pending_ids
            in_stage = staged_offer_id == offer_id
            if offer.location is OfferLocation.PENDING:
                if not is_current or not in_pending or in_stage:
                    raise AssertionError("orphan or multiply-located pending offer")
                if (
                    offer.authorization_id != self.current_authorization_id
                    or not self.authorization_enabled[offer.authorization_id]
                    or self.cached_generation is None
                    or offer.generation != self.cached_generation
                ):
                    raise AssertionError("stale or disabled authorization remains ranked")
            elif offer.location is OfferLocation.STAGED:
                if not is_current or in_pending or not in_stage:
                    raise AssertionError("orphan or multiply-located staged offer")
                if (
                    offer.authorization_id != self.current_authorization_id
                    or not self.authorization_enabled[offer.authorization_id]
                ):
                    raise AssertionError("stale or disabled authorization remains staged")
            elif offer.location is OfferLocation.NONE:
                if in_pending or in_stage:
                    raise AssertionError("NONE offer occupies waiting capacity")
            else:
                raise AssertionError("unknown offer location")
            if not is_current and offer.location is not OfferLocation.NONE:
                raise AssertionError("superseded offer remains live")

        escrow = 0
        owner_outstanding = 0
        penalty_outstanding = 0
        expected_credit_ids: set[bytes] = set()
        creation_sequences: set[int] = set()
        for tranche_id, tranche in self.tranches.items():
            _bytes32(tranche_id, "tranche key")
            if tranche.tranche_id != tranche_id:
                raise AssertionError("tranche key mismatch")
            _canonical_address(tranche.operator, "tranche operator")
            _uint(tranche.creation_sequence, "tranche creation sequence")
            u64(tranche.generation)
            _bytes32(tranche.authorization_id, "tranche authorization ID")
            if tranche.bond_amount != self.sla_bond:
                raise AssertionError("tranche bond differs from immutable SLA bond")
            if tranche.creation_sequence in creation_sequences:
                raise AssertionError("creation sequence was reused")
            creation_sequences.add(tranche.creation_sequence)
            if tranche.creation_sequence > self.creation_sequence:
                raise AssertionError("tranche creation sequence exceeds counter")
            if tranche.authorization_id not in self.authorizations:
                raise AssertionError("tranche authorization identity is unknown")
            expected_tranche_id = self._new_tranche_id(
                tranche.operator,
                tranche.creation_sequence,
                tranche.authorization_id,
                tranche.generation,
            )
            if expected_tranche_id != tranche_id:
                raise AssertionError("tranche ID does not commit immutable fields")
            if tranche.current_offer_id is None:
                raise AssertionError("tranche lost its current offer binding")
            _bytes32(tranche.current_offer_id, "current offer ID")
            current_offer = self.offers.get(tranche.current_offer_id)
            if current_offer is None or current_offer.tranche_id != tranche_id:
                raise AssertionError("current offer/tranche binding mismatch")
            if current_offer.operator != tranche.operator:
                raise AssertionError("current offer operator changed")
            if tranche.release_requested_at is not None:
                _uint(tranche.release_requested_at, "release requested at")
                if tranche.usage is not TrancheUsage.INSTALLED:
                    raise AssertionError("never-installed tranche requested release")
            if tranche.terminalized_at is not None:
                _uint(tranche.terminalized_at, "terminalized at")
            if tranche.terminal_horizon_at is not None:
                _uint(tranche.terminal_horizon_at, "terminal horizon at")
                if tranche.terminalized_at is None:
                    raise AssertionError("terminal horizon lacks terminal timestamp")

            if tranche.usage is TrancheUsage.OFFER:
                if current_offer.location is not OfferLocation.PENDING:
                    raise AssertionError("OFFER tranche is not pending")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("live offer has a pending refund")
            elif tranche.usage is TrancheUsage.STAGED:
                if current_offer.location is not OfferLocation.STAGED:
                    raise AssertionError("STAGED tranche is not in the stage")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("staged tranche has a pending refund")
            elif tranche.usage is TrancheUsage.CLOSED_UNINSTALLED:
                if current_offer.location is not OfferLocation.NONE:
                    raise AssertionError("closed tranche still occupies waiting capacity")
                if (
                    tranche.disposition is BondDisposition.NONE
                    and tranche.pending_refund_at is None
                ):
                    raise AssertionError("uncredited pending exit has no refund deadline")
            elif tranche.usage is TrancheUsage.INSTALLED:
                if current_offer.location is not OfferLocation.NONE:
                    raise AssertionError("installed tranche still occupies waiting capacity")
                _bytes32(tranche.installed_term_id, "installed term ID")
                if tranche.pending_refund_at is not None:
                    raise AssertionError("installed tranche uses pending refund path")
            else:
                raise AssertionError("unknown tranche usage")
            if (
                tranche.usage is not TrancheUsage.INSTALLED
                and tranche.installed_term_id is not None
            ):
                raise AssertionError("never-installed tranche has installed term ID")

            owner_id = self.credit_id(tranche_id, BondDisposition.OWNER_CREDITED)
            penalty_id = self.credit_id(tranche_id, BondDisposition.PENALTY_CREDITED)
            owner_credit = self.credits.get(owner_id)
            penalty_credit = self.credits.get(penalty_id)
            if tranche.disposition is BondDisposition.NONE:
                if owner_credit is not None or penalty_credit is not None:
                    raise AssertionError("unterminated tranche has terminal credit")
                escrow = checked_add(escrow, tranche.bond_amount)
            elif tranche.disposition is BondDisposition.OWNER_CREDITED:
                if tranche.usage not in (
                    TrancheUsage.CLOSED_UNINSTALLED,
                    TrancheUsage.INSTALLED,
                ):
                    raise AssertionError("owner credit is attached to live waiting tranche")
                if owner_credit is None or penalty_credit is not None:
                    raise AssertionError("owner terminalization is not exclusive")
                expected_credit_ids.add(owner_id)
                if not owner_credit.claimed:
                    owner_outstanding = checked_add(owner_outstanding, owner_credit.amount)
            elif tranche.disposition is BondDisposition.PENALTY_CREDITED:
                if tranche.usage is not TrancheUsage.INSTALLED:
                    raise AssertionError("penalty credit is attached to never-installed tranche")
                if penalty_credit is None or owner_credit is not None:
                    raise AssertionError("penalty terminalization is not exclusive")
                expected_credit_ids.add(penalty_id)
                if not penalty_credit.claimed:
                    penalty_outstanding = checked_add(
                        penalty_outstanding, penalty_credit.amount
                    )
            else:  # pragma: no cover - Enum prevents this absent hostile mutation
                raise AssertionError("unknown bond disposition")

        if set(self.credits) != expected_credit_ids:
            raise AssertionError("credit set is not exactly one per terminal tranche")
        for credit_id, credit in self.credits.items():
            _bytes32(credit_id, "credit key")
            if credit.credit_id != credit_id:
                raise AssertionError("credit key mismatch")
            tranche = self.tranches.get(credit.tranche_id)
            if tranche is None:
                raise AssertionError("credit references unknown tranche")
            if credit.disposition not in (
                BondDisposition.OWNER_CREDITED,
                BondDisposition.PENALTY_CREDITED,
            ):
                raise AssertionError("credit has nonterminal disposition")
            if self.credit_id(credit.tranche_id, credit.disposition) != credit_id:
                raise AssertionError("credit key is not its deterministic identity")
            expected_beneficiary = (
                tranche.operator
                if credit.disposition is BondDisposition.OWNER_CREDITED
                else self.penalty_sink
            )
            if (
                credit.amount != self.sla_bond
                or credit.beneficiary != expected_beneficiary
            ):
                raise AssertionError("exact credit changed immutable beneficiary or amount")
            if credit.disposition is not tranche.disposition:
                raise AssertionError("credit and tranche dispositions differ")
            if type(credit.claimed) is not bool:
                raise AssertionError("credit claimed flag is not boolean")
        premium_outstanding = 0
        premium_sequences: set[int] = set()
        for premium_credit_id, credit in self.premium_credits.items():
            _bytes32(premium_credit_id, "premium credit key")
            if credit.credit_id != premium_credit_id:
                raise AssertionError("premium credit key mismatch")
            _bytes32(credit.reserve_id, "premium credit reserve ID")
            _canonical_address(credit.beneficiary, "premium beneficiary")
            _uint(credit.amount, "premium credit amount")
            _uint(credit.sequence, "premium credit sequence")
            if credit.amount == 0:
                raise AssertionError("zero premium credit exists")
            if credit.sequence in premium_sequences:
                raise AssertionError("premium credit sequence reused")
            if credit.sequence > self.premium_credit_sequence:
                raise AssertionError("premium credit sequence exceeds counter")
            premium_sequences.add(credit.sequence)
            if type(credit.claimed) is not bool:
                raise AssertionError("premium claimed flag is not boolean")
            expected_id = hash_fixed(
                D_PREMIUM_CREDIT,
                u256(self.market_chain_id),
                address20(self.market_address, "market address"),
                credit.reserve_id,
                address20(credit.beneficiary, "premium payout"),
                u256(credit.amount),
                u256(credit.sequence),
            )
            if expected_id != premium_credit_id:
                raise AssertionError("premium credit immutable identity changed")
            if not credit.claimed:
                premium_outstanding = checked_add(
                    premium_outstanding, credit.amount
                )
        if premium_outstanding != self.accounting.outstanding_premium_claims:
            raise AssertionError("premium-credit summary mismatch")

        for reserve_id, reserve in self.accounting.live_reserves.items():
            _bytes32(reserve_id, "live reserve ID")
            if reserve.reserve_id != reserve_id:
                raise AssertionError("live reserve key mismatch")
            _uint(reserve.reserved_wei, "reserve amount")
            if type(reserve.lifecycle) is not ReserveLifecycle or reserve.lifecycle is ReserveLifecycle.ABSENT:
                raise AssertionError("invalid stored reserve lifecycle")
            if (
                reserve.reserved_wei == 0
                and reserve.lifecycle is not ReserveLifecycle.OPEN
            ):
                raise AssertionError("only a fully accrued OPEN reserve may be zero")
            if reserve.tranche_id is None or reserve.tranche_id not in self.tranches:
                raise AssertionError("reserve references unknown tranche")
            _bytes32(reserve.owner_id, "reserve owner ID")
            if reserve.term_id is not None:
                _bytes32(reserve.term_id, "reserve term ID")
                if reserve.term_id != reserve_id:
                    raise AssertionError("term reserve is not keyed by term")
            if reserve.payout is None:
                raise AssertionError("reserve lacks immutable payout")
            _canonical_address(reserve.payout, "reserve payout")
            _uint(reserve.ask_wei_per_second, "reserve ask")
            if reserve.lifecycle is ReserveLifecycle.UNSTARTED:
                if any(
                    value is not None
                    for value in (
                        reserve.premium_funded_until,
                        reserve.last_accrued_at,
                        reserve.settlement_cap,
                        reserve.reserve_mature_at,
                    )
                ):
                    raise AssertionError("unstarted reserve has started metadata")
            elif reserve.lifecycle is ReserveLifecycle.OPEN:
                if (
                    reserve.premium_funded_until is None
                    or reserve.last_accrued_at is None
                    or reserve.settlement_cap is not None
                    or reserve.reserve_mature_at is not None
                ):
                    raise AssertionError("open reserve metadata is malformed")
            elif reserve.lifecycle is ReserveLifecycle.CLOSED_TAIL:
                if (
                    reserve.premium_funded_until is None
                    or reserve.last_accrued_at is None
                    or reserve.settlement_cap is None
                    or reserve.reserve_mature_at is None
                ):
                    raise AssertionError("closed-tail metadata is incomplete")
        if escrow != self.accounting.bond_escrow:
            raise AssertionError("bond escrow summary mismatch")
        if owner_outstanding != self.accounting.outstanding_owner_credits:
            raise AssertionError("owner-credit summary mismatch")
        if penalty_outstanding != self.accounting.outstanding_penalty_credits:
            raise AssertionError("penalty-credit summary mismatch")
        self.accounting.assert_valid(self.actual_balance)


if __name__ == "__main__":
    raise SystemExit("run test-seat-market.py")
