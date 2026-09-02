#!/usr/bin/env python3
"""Executable model for the bounded perpetual seat reverse auction.

The model owns waiting offers, SLA bonds, premium reserves, exact pull credits,
installed-bond release and breach enforcement.  Canonical lineup/duty authority
is deliberately represented only by immutable exact-view inputs: Task 4 composes
these Market primitives with the Settlement model in one simulated revert domain.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field, replace
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
D_TERM = b"TAIKO_SEAT_TERM_V1"
D_LINEUP = b"TAIKO_SEAT_LINEUP_V1"
D_LEGACY_WIRE_INTENT = b"TAIKO_SEAT_LEGACY_WIRE_INTENT_V1"
TARGET_VIEW_RESPONSE_LENGTH = 8 * 32
ZERO_BYTES32 = bytes(32)
ZERO_ADDRESS = "0x" + "00" * 20
SPONSOR_PREMIUM_SELECTOR = bytes.fromhex("7004fb96")
WIRE_CODEC_REVISION = 1
MWV1_MAGIC = b"MWV1"
SMI1_MAGIC = b"SMI1"
SLV1_MAGIC = b"SLV1"
SIR1_MAGIC = b"SIR1"
SMR1_MAGIC = b"SMR1"
MEC1_MAGIC = b"MEC1"
MHS1_MAGIC = b"MHS1"
MRO1_MAGIC = b"MRO1"
SHR1_MAGIC = b"SHR1"
ASV1_MAGIC = b"ASV1"
ARV1_MAGIC = b"ARV1"
D_WIRE_RECEIPT = b"slot-chain-seat-mutation-receipt-v1"
D_WIRE_INTENT = b"slot-chain-seat-mutation-intent-v1"
D_BREACH_RECEIPT = b"TAIKO_SEAT_BREACH_V1"


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


def checked_mul_div_up(left: int, right: int, denominator: int) -> int:
    """Full-precision ``ceil(left*right/denominator)`` with uint256 output."""

    left = _uint(left, "left multiplicand")
    right = _uint(right, "right multiplicand")
    denominator = _uint(denominator, "denominator")
    if denominator == 0:
        raise ArithmeticFault("division by zero")
    result = (left * right + denominator - 1) // denominator
    if result > UINT256_MAX:
        raise ArithmeticFault("mulDiv result is outside uint256")
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


def _model_component_hash(value: object, name: str) -> bytes:
    """Normalize a behavioral-model component label to its bytes32 identity."""

    if type(value) is bytes:
        return _bytes32(value, name)
    if type(value) is str and value:
        return keccak256(value.encode("utf-8"))
    raise TransitionRejected(f"{name} is not a component identity")


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


def _wire_address(value: str, name: str, *, allow_zero: bool = False) -> str:
    if type(value) is not str or _CANONICAL_ADDRESS.fullmatch(value) is None:
        raise TransitionRejected(f"{name} is not a canonical address")
    if not allow_zero and value == ZERO_ADDRESS:
        raise TransitionRejected(f"{name} must be nonzero")
    return value


def _abi_uint_word(value: int, bits: int, name: str) -> bytes:
    exact = _uint(value, name)
    if bits not in (8, 16, 64, 256) or exact >= 1 << bits:
        raise TransitionRejected(f"{name} is outside uint{bits}")
    return exact.to_bytes(32, "big")


def _abi_address_word(value: str, name: str, *, allow_zero: bool = False) -> bytes:
    exact = _wire_address(value, name, allow_zero=allow_zero)
    return bytes(12) + bytes.fromhex(exact[2:])


def _abi_magic_word(value: bytes) -> bytes:
    return _bytes4(value, "wire magic") + bytes(28)


def _decode_uint_word(word: bytes, bits: int, name: str) -> int:
    if bits not in (8, 16, 64, 256):
        raise AssertionError("unsupported ABI integer width")
    padding = 32 - bits // 8
    if word[:padding] != bytes(padding):
        raise TransitionRejected(f"{name} has noncanonical uint{bits} padding")
    return int.from_bytes(word[padding:], "big")


def _decode_address_word(word: bytes, name: str, *, allow_zero: bool = False) -> str:
    if word[:12] != bytes(12):
        raise TransitionRejected(f"{name} has noncanonical address padding")
    return _wire_address(
        "0x" + word[12:].hex(), name, allow_zero=allow_zero
    )


def _fixed_wire_words(raw: bytes, word_count: int, magic: bytes, name: str) -> list[bytes]:
    if type(raw) is not bytes or len(raw) != word_count * 32:
        raise TransitionRejected(f"{name} has noncanonical length")
    words = [raw[index:index + 32] for index in range(0, len(raw), 32)]
    if words[0] != _abi_magic_word(magic):
        raise TransitionRejected(f"{name} has wrong magic/revision")
    return words


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


class WireJournal(Enum):
    IDLE = 0
    EXECUTING = 1


class WireIntentStatus(Enum):
    NONE = 0
    PENDING = 1
    EXECUTING = 2


class WireOperation(Enum):
    NONE = 0
    STAGE = 1
    APPLY = 2
    EXPIRE = 3
    INVALIDATE = 4
    MIGRATION_CANCEL = 5


class WirePrimaryState(Enum):
    VACANT = 0
    HEALTHY = 1
    NONSERVING = 2


class WireResult(Enum):
    NO_FEASIBLE = 0
    UNDERFUNDED = 1
    STAGED = 2
    APPLIED = 3
    RESTORED = 4
    OWNER_TERMINALIZED = 5


class EconomicResult(Enum):
    NOOP = 0
    UPDATED = 1
    CREDITED = 2
    TERMINALIZED = 3


class MarketRotationResult(Enum):
    RECONCILIATION_REQUIRED = 0
    ADVANCED = 1
    BOOTSTRAPPED = 2


class HistoryDisposition(Enum):
    NO_DUTY = 0
    OPEN = 1
    FAILED_OVER = 2
    SATISFIED = 3
    BREACHED = 4
    EXCUSED = 5
    EXCUSED_MIGRATION = 6


class ActivationTransitionKind(Enum):
    GENESIS_IMPORT = 1
    VERSION_MIGRATION = 2


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
    installed_at: int = 0


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
    service_close_at: int | None = None
    term_removed_at: int | None = None


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
    target_manifest_hash: bytes
    target_registration_hash: bytes


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


@dataclass(frozen=True)
class MarketWireStateV1:
    journal: WireJournal
    market_state_version: int
    cross_wire_nonce: int
    last_receipt_hash: bytes
    current_authorization_id: bytes
    generation_initialized: bool
    cached_generation: int
    stage_present: bool
    stage_id: bytes
    stage_authorization_id: bytes
    stage_generation: int
    offer_id: bytes
    tranche_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    selected_rank: int
    outgoing_term_id: bytes
    lineup_commitment: bytes
    handover_at: int
    expires_at: int
    reserve_id: bytes
    reserve_wei: int


@dataclass(frozen=True)
class SeatMutationIntentV1:
    status: WireIntentStatus
    operation: WireOperation
    intent_sequence: int
    authorization_id: bytes
    generation: int
    expected_market_state_version: int
    expected_cross_wire_nonce: int
    expected_last_receipt_hash: bytes
    stage_id: bytes
    pre_lineup_commitment: bytes
    post_lineup_commitment: bytes
    incoming_term_id: bytes
    outgoing_term_id: bytes
    install_revision: int
    intent_hash: bytes


@dataclass(frozen=True)
class SeatLineupWireV1:
    authorization_id: bytes
    generation: int
    lineup_revision: int
    lineup_commitment: bytes
    count: int
    primary_state: WirePrimaryState
    term_ids: tuple[bytes, bytes, bytes, bytes]
    asks: tuple[int, int, int, int]
    primary_minimum_tenure_until: int
    primary_service_eligible_until: int


@dataclass(frozen=True)
class SeatInstallRecordV1:
    authorization_id: bytes
    generation: int
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    installed_at: int
    install_revision: int


@dataclass(frozen=True)
class SeatMutationReceiptV1:
    result: WireResult
    operation: WireOperation
    intent_sequence: int
    intent_hash: bytes
    pre_state_version: int
    post_state_version: int
    pre_wire_nonce: int
    post_wire_nonce: int
    pre_last_receipt_hash: bytes
    receipt_hash: bytes
    stage_id: bytes
    offer_id: bytes
    tranche_id: bytes
    operator: str
    payout: str
    ask_wei_per_second: int
    selected_rank: int
    outgoing_term_id: bytes
    handover_at: int
    expires_at: int
    reserve_id: bytes
    reserve_wei: int
    credit_id: bytes
    amount: int


@dataclass(frozen=True)
class MarketEconomicReceiptV1:
    result: EconomicResult
    term_id: bytes
    credit_id: bytes
    amount: int
    deadline: int


@dataclass(frozen=True)
class MarketHistorySafetyV1:
    safe: bool


@dataclass(frozen=True)
class SeatMarketRecordV1:
    authorization_id: bytes
    seat_generation: int
    term_id: bytes
    tranche_id: bytes
    operator: str
    responsibility_start: int
    premium_cap: int
    service_close_at: int
    term_removed_at: int
    last_liability_at: int
    live_duty_count: int
    latest_duty_id: bytes
    latest_duty_disposition: HistoryDisposition
    latest_duty_disposition_at: int
    breach_receipt_id: bytes
    breach_recorded_at: int


@dataclass(frozen=True)
class SeatDutyRecordV1:
    authorization_id: bytes
    seat_generation: int
    duty_id: bytes
    term_id: bytes
    tranche_id: bytes
    disposition: HistoryDisposition
    disposition_at: int
    last_liability_at: int
    breach_receipt_id: bytes
    breach_recorded_at: int


@dataclass(frozen=True)
class MarketRotationReceiptV1:
    result: MarketRotationResult
    purged_count: int
    old_authorization_id: bytes
    new_authorization_id: bytes
    activation_receipt_id: bytes
    successor_index: int
    blocking_stage_id: bytes


@dataclass(frozen=True)
class SuccessorReceiptV1:
    receipt_id: bytes
    successor_index: int


@dataclass(frozen=True)
class ActivationReceiptV1:
    receipt_id: bytes
    settlement_chain_id: int
    router: str
    router_generation: int
    successor_index: int
    transition_kind: ActivationTransitionKind
    source_protocol_version: int
    target_protocol_version: int
    source_manifest_hash: bytes
    target_manifest_hash: bytes
    source_authorization_id: bytes
    target_authorization_id: bytes
    target_registration_hash: bytes
    source_settlement: str
    target_settlement: str
    old_destination_domain_id: bytes
    new_destination_domain_id: bytes
    old_destination_bridge: str
    new_destination_bridge: str
    queue_watermark: int
    candidate_digest: bytes
    output_canonical_hash: bytes
    output_canonical_sequence: int
    activation_context_hash: bytes
    transition_auxiliary_hash: bytes
    source_post_state_commitment: bytes
    adoption_commitment: bytes
    queue_post_state_commitment: bytes
    seat_generation: int
    activated_at_block: int
    sealed: bool


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
    history_fault: str | None = None
    term_history_override: bytes | None = None
    duty_history_override: bytes | None = None
    install_record_override: bytes | None = None
    read_count: int = field(default=0, compare=False)
    history_read_count: int = field(default=0, compare=False)

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
            return raw[:160] + b"FAIL" + raw[164:]
        return raw

    def _read_history(
        self,
        *,
        target: str,
        record_id: bytes,
        method_name: str,
        override: bytes | None,
    ) -> bytes:
        self.history_read_count += 1
        if target != self.authorization.target:
            raise TransitionRejected("history read used the wrong target")
        _bytes32(record_id, "history record ID")
        if self.history_fault == "revert":
            raise RuntimeError("history read reverted")
        if self.history_fault == "oog":
            raise MemoryError("history read exhausted its bound")
        reader = getattr(self.authority, method_name, None)
        if override is None:
            if not callable(reader):
                raise TransitionRejected("target authority lacks SHR1 surface")
            raw = reader(record_id)
        else:
            raw = override
        if type(raw) is not bytes:
            raise TransitionRejected("target authority returned non-bytes SHR1")
        if self.history_fault == "short":
            return raw[:-1]
        if self.history_fault == "long":
            return raw + b"\x00"
        if self.history_fault == "wrong_magic" and len(raw) >= 4:
            return b"FAIL" + raw[4:]
        return raw

    def read_seat_market_record(self, term_id: bytes) -> bytes:
        return self._read_history(
            target=self.authorization.target,
            record_id=term_id,
            method_name="seat_market_record_v1",
            override=self.term_history_override,
        )

    def read_seat_install_record(self, term_id: bytes) -> bytes:
        return self._read_history(
            target=self.authorization.target,
            record_id=term_id,
            method_name="seat_install_record_v1",
            override=self.install_record_override,
        )

    def read_seat_duty_record(self, duty_id: bytes) -> bytes:
        return self._read_history(
            target=self.authorization.target,
            record_id=duty_id,
            method_name="seat_duty_record_v1",
            override=self.duty_history_override,
        )


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
        authorization: TargetAuthorization | None,
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
        b"\x00" * 12 + address20(view.target, "view target"),
        u256(view.settlement_chain_id),
        b"\x00" * 24 + protocol_version,
        runtime_hash,
        config_hash,
        magic + b"\x00" * 28,
        b"\x00" * 31 + bytes((phases[view.phase],)),
        b"\x00" * 24 + u64(view.generation),
    ))


def decode_exact_target_view(raw: bytes) -> ExactTargetView:
    if type(raw) is not bytes or len(raw) != TARGET_VIEW_RESPONSE_LENGTH:
        raise TransitionRejected("target view has noncanonical length")
    phases = {1: "ACTIVE", 2: "ARMED", 3: "READY", 4: "FROZEN"}
    if (
        raw[:12] != b"\x00" * 12
        or raw[64:88] != b"\x00" * 24
        or raw[164:192] != b"\x00" * 28
        or raw[192:223] != b"\x00" * 31
        or raw[224:248] != b"\x00" * 24
    ):
        raise TransitionRejected("target view has noncanonical ABI padding")
    phase = phases.get(raw[223])
    if phase is None:
        raise TransitionRejected("target view phase is invalid")
    return ExactTargetView(
        target="0x" + raw[12:32].hex(),
        settlement_chain_id=int.from_bytes(raw[32:64], "big"),
        protocol_version=int.from_bytes(raw[88:96], "big"),
        runtime_hash=raw[96:128],
        configuration_hash=raw[128:160],
        magic=raw[160:164],
        phase=phase,
        generation=int.from_bytes(raw[248:256], "big"),
    )


MWV1_RESPONSE_LENGTH = 24 * 32
SMI1_RESPONSE_LENGTH = 16 * 32
SLV1_RESPONSE_LENGTH = 17 * 32
SIR1_RESPONSE_LENGTH = 11 * 32
SMR1_RESPONSE_LENGTH = 25 * 32
MEC1_RESPONSE_LENGTH = 6 * 32
MHS1_RESPONSE_LENGTH = 2 * 32
MRO1_RESPONSE_LENGTH = 8 * 32
SEAT_MARKET_RECORD_V1_RESPONSE_LENGTH = 17 * 32
SEAT_DUTY_RECORD_V1_RESPONSE_LENGTH = 11 * 32
ASV1_RESPONSE_LENGTH = 3 * 32
ARV1_RESPONSE_LENGTH = 32 * 32


def _wire_enum(value: Enum, enum_type: type[Enum], name: str) -> int:
    if type(value) is not enum_type:
        raise TransitionRejected(f"{name} is not an exact wire enum")
    return int(value.value)


def _decode_wire_enum(
    word: bytes, enum_type: type[Enum], name: str
) -> Enum:
    raw = _decode_uint_word(word, 8, name)
    try:
        return enum_type(raw)
    except ValueError as exc:
        raise TransitionRejected(f"{name} is invalid") from exc


def _wire_bool(value: bool, name: str) -> bytes:
    if type(value) is not bool:
        raise TransitionRejected(f"{name} is not an exact bool")
    return _abi_uint_word(int(value), 8, name)


def _decode_wire_bool(word: bytes, name: str) -> bool:
    value = _decode_uint_word(word, 8, name)
    if value not in (0, 1):
        raise TransitionRejected(f"{name} is not an exact bool")
    return bool(value)


def _wire_bytes32_tuple(
    value: tuple[bytes, bytes, bytes, bytes], name: str
) -> tuple[bytes, bytes, bytes, bytes]:
    if type(value) is not tuple or len(value) != 4:
        raise TransitionRejected(f"{name} must have exactly four entries")
    return tuple(_bytes32(item, f"{name} entry") for item in value)  # type: ignore[return-value]


def _wire_uint_tuple(
    value: tuple[int, int, int, int], name: str
) -> tuple[int, int, int, int]:
    if type(value) is not tuple or len(value) != 4:
        raise TransitionRejected(f"{name} must have exactly four entries")
    return tuple(_uint(item, f"{name} entry") for item in value)  # type: ignore[return-value]


def encode_market_wire_state_v1(view: MarketWireStateV1) -> bytes:
    """Canonical fixed-width MWV1 oracle; no dynamic ABI values exist."""

    if type(view) is not MarketWireStateV1:
        raise TransitionRejected("malformed MWV1 state")
    journal = _wire_enum(view.journal, WireJournal, "MWV1 journal")
    _uint(view.market_state_version, "MWV1 state version")
    _uint(view.cross_wire_nonce, "MWV1 wire nonce")
    _bytes32(view.last_receipt_hash, "MWV1 last receipt hash")
    _bytes32(view.current_authorization_id, "MWV1 current authorization")
    if type(view.generation_initialized) is not bool:
        raise TransitionRejected("MWV1 generation flag is not bool")
    u64(view.cached_generation)
    if not view.generation_initialized and view.cached_generation != 0:
        raise TransitionRejected("MWV1 absent generation must be zero")
    if type(view.stage_present) is not bool:
        raise TransitionRejected("MWV1 stage flag is not bool")
    stage_words = (
        view.stage_id,
        view.stage_authorization_id,
        view.offer_id,
        view.tranche_id,
        view.outgoing_term_id,
        view.lineup_commitment,
        view.reserve_id,
    )
    for name, raw in zip(
        (
            "stage ID", "stage authorization", "offer ID", "tranche ID",
            "outgoing term", "lineup commitment", "reserve ID",
        ),
        stage_words,
    ):
        _bytes32(raw, f"MWV1 {name}")
    for name, value in (
        ("stage generation", view.stage_generation),
        ("handover", view.handover_at),
        ("expiry", view.expires_at),
    ):
        u64(value)
    _uint(view.ask_wei_per_second, "MWV1 ask")
    _uint(view.reserve_wei, "MWV1 reserve")
    if not 0 <= view.selected_rank < 4:
        raise TransitionRejected("MWV1 selected rank is outside four seats")
    if not view.stage_present:
        unused = (
            *stage_words,
            view.stage_generation,
            view.operator != ZERO_ADDRESS,
            view.payout != ZERO_ADDRESS,
            view.ask_wei_per_second,
            view.selected_rank,
            view.handover_at,
            view.expires_at,
            view.reserve_wei,
        )
        if any(item not in (0, False, ZERO_BYTES32) for item in unused):
            raise TransitionRejected("MWV1 absent-stage fields must be zero")
        _wire_address(view.operator, "MWV1 operator", allow_zero=True)
        _wire_address(view.payout, "MWV1 payout", allow_zero=True)
    else:
        for name, raw in (
            ("stage ID", view.stage_id),
            ("stage authorization", view.stage_authorization_id),
            ("offer ID", view.offer_id),
            ("tranche ID", view.tranche_id),
            ("lineup commitment", view.lineup_commitment),
        ):
            if raw == ZERO_BYTES32:
                raise TransitionRejected(f"MWV1 {name} must be nonzero")
        _wire_address(view.operator, "MWV1 operator")
        _wire_address(view.payout, "MWV1 payout")
        if view.expires_at < view.handover_at:
            raise TransitionRejected("MWV1 stage expiry precedes handover")
        if view.reserve_wei == 0:
            if view.ask_wei_per_second != 0 or view.reserve_id != ZERO_BYTES32:
                raise TransitionRejected("MWV1 zero reserve is not canonical")
        elif view.ask_wei_per_second == 0 or view.reserve_id == ZERO_BYTES32:
            raise TransitionRejected("MWV1 funded reserve is incomplete")
    return b"".join((
        _abi_magic_word(MWV1_MAGIC),
        _abi_uint_word(journal, 8, "MWV1 journal"),
        u256(view.market_state_version),
        u256(view.cross_wire_nonce),
        view.last_receipt_hash,
        view.current_authorization_id,
        _wire_bool(view.generation_initialized, "MWV1 generation flag"),
        _abi_uint_word(view.cached_generation, 64, "MWV1 cached generation"),
        _wire_bool(view.stage_present, "MWV1 stage flag"),
        view.stage_id,
        view.stage_authorization_id,
        _abi_uint_word(view.stage_generation, 64, "MWV1 stage generation"),
        view.offer_id,
        view.tranche_id,
        _abi_address_word(view.operator, "MWV1 operator", allow_zero=True),
        _abi_address_word(view.payout, "MWV1 payout", allow_zero=True),
        u256(view.ask_wei_per_second),
        _abi_uint_word(view.selected_rank, 8, "MWV1 selected rank"),
        view.outgoing_term_id,
        view.lineup_commitment,
        _abi_uint_word(view.handover_at, 64, "MWV1 handover"),
        _abi_uint_word(view.expires_at, 64, "MWV1 expiry"),
        view.reserve_id,
        u256(view.reserve_wei),
    ))


def decode_market_wire_state_v1(raw: bytes) -> MarketWireStateV1:
    words = _fixed_wire_words(raw, 24, MWV1_MAGIC, "MWV1")
    view = MarketWireStateV1(
        _decode_wire_enum(words[1], WireJournal, "MWV1 journal"),  # type: ignore[arg-type]
        _decode_uint_word(words[2], 256, "MWV1 state version"),
        _decode_uint_word(words[3], 256, "MWV1 wire nonce"),
        words[4], words[5],
        _decode_wire_bool(words[6], "MWV1 generation flag"),
        _decode_uint_word(words[7], 64, "MWV1 cached generation"),
        _decode_wire_bool(words[8], "MWV1 stage flag"),
        words[9], words[10],
        _decode_uint_word(words[11], 64, "MWV1 stage generation"),
        words[12], words[13],
        _decode_address_word(words[14], "MWV1 operator", allow_zero=True),
        _decode_address_word(words[15], "MWV1 payout", allow_zero=True),
        _decode_uint_word(words[16], 256, "MWV1 ask"),
        _decode_uint_word(words[17], 8, "MWV1 selected rank"),
        words[18], words[19],
        _decode_uint_word(words[20], 64, "MWV1 handover"),
        _decode_uint_word(words[21], 64, "MWV1 expiry"),
        words[22],
        _decode_uint_word(words[23], 256, "MWV1 reserve"),
    )
    if encode_market_wire_state_v1(view) != raw:
        raise TransitionRejected("MWV1 is not canonical")
    return view


def encode_seat_mutation_intent_v1(intent: SeatMutationIntentV1) -> bytes:
    if type(intent) is not SeatMutationIntentV1:
        raise TransitionRejected("malformed SMI1 intent")
    status = _wire_enum(intent.status, WireIntentStatus, "SMI1 status")
    operation = _wire_enum(intent.operation, WireOperation, "SMI1 operation")
    for name, raw in (
        ("authorization", intent.authorization_id),
        ("last receipt", intent.expected_last_receipt_hash),
        ("stage", intent.stage_id),
        ("pre-lineup", intent.pre_lineup_commitment),
        ("post-lineup", intent.post_lineup_commitment),
        ("incoming term", intent.incoming_term_id),
        ("outgoing term", intent.outgoing_term_id),
        ("intent hash", intent.intent_hash),
    ):
        _bytes32(raw, f"SMI1 {name}")
    _uint(intent.intent_sequence, "SMI1 sequence")
    u64(intent.generation)
    _uint(intent.expected_market_state_version, "SMI1 state version")
    _uint(intent.expected_cross_wire_nonce, "SMI1 wire nonce")
    u64(intent.install_revision)
    zero_semantic = (
        intent.intent_sequence == 0
        and intent.authorization_id == ZERO_BYTES32
        and intent.generation == 0
        and intent.expected_market_state_version == 0
        and intent.expected_cross_wire_nonce == 0
        and intent.expected_last_receipt_hash == ZERO_BYTES32
        and intent.stage_id == ZERO_BYTES32
        and intent.pre_lineup_commitment == ZERO_BYTES32
        and intent.post_lineup_commitment == ZERO_BYTES32
        and intent.incoming_term_id == ZERO_BYTES32
        and intent.outgoing_term_id == ZERO_BYTES32
        and intent.install_revision == 0
        and intent.intent_hash == ZERO_BYTES32
    )
    if intent.status is WireIntentStatus.NONE:
        if intent.operation is not WireOperation.NONE or not zero_semantic:
            raise TransitionRejected("SMI1 NONE intent has nonzero fields")
    else:
        if intent.operation is WireOperation.NONE:
            raise TransitionRejected("SMI1 live intent has zero operation")
        if (
            intent.intent_sequence == 0
            or intent.authorization_id == ZERO_BYTES32
            or intent.intent_hash == ZERO_BYTES32
        ):
            raise TransitionRejected("SMI1 live identity is incomplete")
        if intent.status is WireIntentStatus.PENDING:
            if intent.operation not in (
                WireOperation.INVALIDATE, WireOperation.MIGRATION_CANCEL
            ):
                raise TransitionRejected("SMI1 PENDING operation is not asynchronous")
            if (
                intent.expected_market_state_version != 0
                or intent.expected_cross_wire_nonce != 0
                or intent.expected_last_receipt_hash != ZERO_BYTES32
            ):
                raise TransitionRejected("SMI1 PENDING prestate must be zero")
        else:
            if intent.expected_cross_wire_nonce > intent.expected_market_state_version:
                raise TransitionRejected("SMI1 wire nonce exceeds state version")
            if (
                (intent.expected_cross_wire_nonce == 0)
                != (intent.expected_last_receipt_hash == ZERO_BYTES32)
            ):
                raise TransitionRejected("SMI1 receipt-chain prestate is inconsistent")
        if intent.operation is WireOperation.STAGE:
            if intent.status is not WireIntentStatus.EXECUTING:
                raise TransitionRejected("SMI1 STAGE must be EXECUTING")
            if any((
                intent.stage_id != ZERO_BYTES32,
                intent.post_lineup_commitment != ZERO_BYTES32,
                intent.incoming_term_id != ZERO_BYTES32,
                intent.outgoing_term_id != ZERO_BYTES32,
                intent.install_revision != 0,
            )):
                raise TransitionRejected("SMI1 STAGE unused fields must be zero")
            if intent.pre_lineup_commitment == ZERO_BYTES32:
                raise TransitionRejected("SMI1 STAGE lacks pre-lineup")
        elif intent.operation is WireOperation.APPLY:
            if intent.status is not WireIntentStatus.EXECUTING:
                raise TransitionRejected("SMI1 APPLY must be EXECUTING")
            if (
                intent.stage_id == ZERO_BYTES32
                or intent.pre_lineup_commitment == ZERO_BYTES32
                or intent.post_lineup_commitment == ZERO_BYTES32
                or intent.incoming_term_id == ZERO_BYTES32
                or intent.install_revision == 0
            ):
                raise TransitionRejected("SMI1 APPLY identity is incomplete")
        else:
            if (
                intent.stage_id == ZERO_BYTES32
                or intent.pre_lineup_commitment == ZERO_BYTES32
                or intent.post_lineup_commitment != ZERO_BYTES32
                or intent.incoming_term_id != ZERO_BYTES32
                or intent.outgoing_term_id != ZERO_BYTES32
                or intent.install_revision != 0
            ):
                raise TransitionRejected("SMI1 terminal-stage fields are noncanonical")
    return b"".join((
        _abi_magic_word(SMI1_MAGIC),
        _abi_uint_word(status, 8, "SMI1 status"),
        _abi_uint_word(operation, 8, "SMI1 operation"),
        u256(intent.intent_sequence),
        intent.authorization_id,
        _abi_uint_word(intent.generation, 64, "SMI1 generation"),
        u256(intent.expected_market_state_version),
        u256(intent.expected_cross_wire_nonce),
        intent.expected_last_receipt_hash,
        intent.stage_id,
        intent.pre_lineup_commitment,
        intent.post_lineup_commitment,
        intent.incoming_term_id,
        intent.outgoing_term_id,
        _abi_uint_word(intent.install_revision, 64, "SMI1 install revision"),
        intent.intent_hash,
    ))


def seat_mutation_intent_hash_v1(
    chain_id: int,
    settlement: str,
    market: str,
    intent: SeatMutationIntentV1,
) -> bytes:
    """Derive the context-bound hash for the first fifteen SMI1 words."""

    if type(intent) is not SeatMutationIntentV1:
        raise TransitionRejected("malformed SMI1 intent")
    status = _wire_enum(intent.status, WireIntentStatus, "SMI1 status")
    operation = _wire_enum(intent.operation, WireOperation, "SMI1 operation")
    return keccak256(b"".join((
        D_WIRE_INTENT,
        u256(chain_id),
        address20(settlement, "SMI1 Settlement"),
        address20(market, "SMI1 Market"),
        u8(status),
        u8(operation),
        u256(intent.intent_sequence),
        _bytes32(intent.authorization_id, "SMI1 authorization"),
        u64(intent.generation),
        u256(intent.expected_market_state_version),
        u256(intent.expected_cross_wire_nonce),
        _bytes32(intent.expected_last_receipt_hash, "SMI1 last receipt"),
        _bytes32(intent.stage_id, "SMI1 stage"),
        _bytes32(intent.pre_lineup_commitment, "SMI1 pre-lineup"),
        _bytes32(intent.post_lineup_commitment, "SMI1 post-lineup"),
        _bytes32(intent.incoming_term_id, "SMI1 incoming term"),
        _bytes32(intent.outgoing_term_id, "SMI1 outgoing term"),
        u64(intent.install_revision),
    )))


def decode_seat_mutation_intent_v1(raw: bytes) -> SeatMutationIntentV1:
    words = _fixed_wire_words(raw, 16, SMI1_MAGIC, "SMI1")
    intent = SeatMutationIntentV1(
        _decode_wire_enum(words[1], WireIntentStatus, "SMI1 status"),  # type: ignore[arg-type]
        _decode_wire_enum(words[2], WireOperation, "SMI1 operation"),  # type: ignore[arg-type]
        _decode_uint_word(words[3], 256, "SMI1 sequence"),
        words[4],
        _decode_uint_word(words[5], 64, "SMI1 generation"),
        _decode_uint_word(words[6], 256, "SMI1 state version"),
        _decode_uint_word(words[7], 256, "SMI1 wire nonce"),
        words[8], words[9], words[10], words[11], words[12], words[13],
        _decode_uint_word(words[14], 64, "SMI1 install revision"),
        words[15],
    )
    if encode_seat_mutation_intent_v1(intent) != raw:
        raise TransitionRejected("SMI1 is not canonical")
    return intent


def encode_seat_lineup_wire_v1(view: SeatLineupWireV1) -> bytes:
    if type(view) is not SeatLineupWireV1:
        raise TransitionRejected("malformed SLV1 lineup")
    _bytes32(view.authorization_id, "SLV1 authorization")
    u64(view.generation)
    u64(view.lineup_revision)
    _bytes32(view.lineup_commitment, "SLV1 lineup commitment")
    if not 0 <= view.count <= 4:
        raise TransitionRejected("SLV1 count exceeds four")
    primary_state = _wire_enum(view.primary_state, WirePrimaryState, "SLV1 primary")
    terms = _wire_bytes32_tuple(view.term_ids, "SLV1 terms")
    asks = _wire_uint_tuple(view.asks, "SLV1 asks")
    u64(view.primary_minimum_tenure_until)
    u64(view.primary_service_eligible_until)
    if view.lineup_commitment != seat_lineup_commitment_v1(
        view.lineup_revision, terms
    ):
        raise TransitionRejected("SLV1 lineup commitment is not derived")
    if view.count == 0:
        if (
            view.primary_state is not WirePrimaryState.VACANT
            or any(term != ZERO_BYTES32 for term in terms)
            or any(asks)
            or view.primary_minimum_tenure_until != 0
            or view.primary_service_eligible_until != 0
        ):
            raise TransitionRejected("SLV1 vacant unused fields must be zero")
    else:
        if view.primary_state is WirePrimaryState.VACANT:
            raise TransitionRejected("SLV1 occupied lineup cannot be vacant")
        if any(term == ZERO_BYTES32 for term in terms[:view.count]):
            raise TransitionRejected("SLV1 occupied term is zero")
        if any(term != ZERO_BYTES32 for term in terms[view.count:]) or any(
            asks[view.count:]
        ):
            raise TransitionRejected("SLV1 unused array cells must be zero")
        if len(set(terms[:view.count])) != view.count:
            raise TransitionRejected("SLV1 term is duplicated")
        if list(asks[1:view.count]) != sorted(asks[1:view.count]):
            raise TransitionRejected("SLV1 standby asks are not monotone")
        if view.primary_state is WirePrimaryState.HEALTHY:
            if (
                view.primary_service_eligible_until
                < view.primary_minimum_tenure_until
            ):
                raise TransitionRejected("SLV1 primary interval is inverted")
        elif (
            view.primary_minimum_tenure_until != 0
            or view.primary_service_eligible_until != 0
        ):
            raise TransitionRejected("SLV1 nonserving clocks must be zero")
    return b"".join((
        _abi_magic_word(SLV1_MAGIC),
        view.authorization_id,
        _abi_uint_word(view.generation, 64, "SLV1 generation"),
        _abi_uint_word(view.lineup_revision, 64, "SLV1 revision"),
        view.lineup_commitment,
        _abi_uint_word(view.count, 8, "SLV1 count"),
        _abi_uint_word(primary_state, 8, "SLV1 primary"),
        *terms,
        *(u256(ask) for ask in asks),
        _abi_uint_word(
            view.primary_minimum_tenure_until, 64, "SLV1 minimum tenure"
        ),
        _abi_uint_word(
            view.primary_service_eligible_until, 64, "SLV1 service eligible"
        ),
    ))


def decode_seat_lineup_wire_v1(raw: bytes) -> SeatLineupWireV1:
    words = _fixed_wire_words(raw, 17, SLV1_MAGIC, "SLV1")
    view = SeatLineupWireV1(
        words[1],
        _decode_uint_word(words[2], 64, "SLV1 generation"),
        _decode_uint_word(words[3], 64, "SLV1 revision"),
        words[4],
        _decode_uint_word(words[5], 8, "SLV1 count"),
        _decode_wire_enum(words[6], WirePrimaryState, "SLV1 primary"),  # type: ignore[arg-type]
        tuple(words[7:11]),  # type: ignore[arg-type]
        tuple(_decode_uint_word(word, 256, "SLV1 ask") for word in words[11:15]),  # type: ignore[arg-type]
        _decode_uint_word(words[15], 64, "SLV1 minimum tenure"),
        _decode_uint_word(words[16], 64, "SLV1 service eligible"),
    )
    if encode_seat_lineup_wire_v1(view) != raw:
        raise TransitionRejected("SLV1 is not canonical")
    return view


def encode_seat_install_record_v1(view: SeatInstallRecordV1) -> bytes:
    if type(view) is not SeatInstallRecordV1:
        raise TransitionRejected("malformed SIR1 install record")
    for name, raw in (
        ("authorization", view.authorization_id),
        ("term", view.term_id),
        ("tranche", view.tranche_id),
        ("offer", view.offer_id),
    ):
        if _bytes32(raw, f"SIR1 {name}") == ZERO_BYTES32:
            raise TransitionRejected(f"SIR1 {name} must be nonzero")
    u64(view.generation)
    _wire_address(view.operator, "SIR1 operator")
    _wire_address(view.payout, "SIR1 payout")
    _uint(view.ask_wei_per_second, "SIR1 ask")
    u64(view.installed_at)
    u64(view.install_revision)
    if view.installed_at == 0 or view.install_revision == 0:
        raise TransitionRejected("SIR1 install clock/revision must be nonzero")
    if view.term_id != seat_term_identity_v1(
        view.authorization_id,
        view.generation,
        view.offer_id,
        view.tranche_id,
        view.installed_at,
        view.install_revision,
    ):
        raise TransitionRejected("SIR1 term ID is not derived")
    return b"".join((
        _abi_magic_word(SIR1_MAGIC),
        view.authorization_id,
        _abi_uint_word(view.generation, 64, "SIR1 generation"),
        view.term_id, view.tranche_id, view.offer_id,
        _abi_address_word(view.operator, "SIR1 operator"),
        _abi_address_word(view.payout, "SIR1 payout"),
        u256(view.ask_wei_per_second),
        _abi_uint_word(view.installed_at, 64, "SIR1 installed at"),
        _abi_uint_word(view.install_revision, 64, "SIR1 install revision"),
    ))


def decode_seat_install_record_v1(raw: bytes) -> SeatInstallRecordV1:
    words = _fixed_wire_words(raw, 11, SIR1_MAGIC, "SIR1")
    view = SeatInstallRecordV1(
        words[1],
        _decode_uint_word(words[2], 64, "SIR1 generation"),
        words[3], words[4], words[5],
        _decode_address_word(words[6], "SIR1 operator"),
        _decode_address_word(words[7], "SIR1 payout"),
        _decode_uint_word(words[8], 256, "SIR1 ask"),
        _decode_uint_word(words[9], 64, "SIR1 installed at"),
        _decode_uint_word(words[10], 64, "SIR1 install revision"),
    )
    if encode_seat_install_record_v1(view) != raw:
        raise TransitionRejected("SIR1 is not canonical")
    return view


def seat_breach_receipt_id_v1(
    duty_id: bytes,
    term_id: bytes,
    tranche_id: bytes,
    breach_recorded_at: int,
) -> bytes:
    """Derive the immutable breach identity shared by both SHR1 rows."""

    return keccak256(b"".join((
        D_BREACH_RECEIPT,
        _bytes32(duty_id, "breach duty"),
        _bytes32(term_id, "breach term"),
        _bytes32(tranche_id, "breach tranche"),
        u64(breach_recorded_at),
    )))


def _validate_history_disposition_v1(
    disposition: HistoryDisposition,
    disposition_at: int,
    breach_receipt_id: bytes,
    breach_recorded_at: int,
    *,
    permit_no_duty: bool,
) -> None:
    _wire_enum(disposition, HistoryDisposition, "SHR1 disposition")
    u64(disposition_at)
    _bytes32(breach_receipt_id, "SHR1 breach receipt")
    u64(breach_recorded_at)
    if disposition is HistoryDisposition.NO_DUTY:
        if not permit_no_duty or any((
            disposition_at, breach_recorded_at,
            breach_receipt_id != ZERO_BYTES32,
        )):
            raise TransitionRejected("SHR1 NO_DUTY mask is invalid")
    elif disposition is HistoryDisposition.OPEN:
        if any((
            disposition_at, breach_recorded_at,
            breach_receipt_id != ZERO_BYTES32,
        )):
            raise TransitionRejected("SHR1 OPEN mask is invalid")
    elif disposition in (
        HistoryDisposition.FAILED_OVER,
        HistoryDisposition.SATISFIED,
        HistoryDisposition.EXCUSED,
        HistoryDisposition.EXCUSED_MIGRATION,
    ):
        if (
            disposition_at == 0
            or breach_recorded_at != 0
            or breach_receipt_id != ZERO_BYTES32
        ):
            raise TransitionRejected("SHR1 nonbreach terminal mask is invalid")
    elif (
        disposition_at == 0
        or breach_recorded_at == 0
        or breach_receipt_id == ZERO_BYTES32
    ):
        raise TransitionRejected("SHR1 BREACHED mask is invalid")


def encode_seat_market_record_v1(view: SeatMarketRecordV1) -> bytes:
    """Encode the exact permanent 17-word Settlement term history row."""

    if type(view) is not SeatMarketRecordV1:
        raise TransitionRejected("malformed SHR1 term record")
    for name, raw in (
        ("authorization", view.authorization_id),
        ("term", view.term_id),
        ("tranche", view.tranche_id),
        ("latest duty", view.latest_duty_id),
        ("breach receipt", view.breach_receipt_id),
    ):
        _bytes32(raw, f"SHR1 {name}")
    if any(raw == ZERO_BYTES32 for raw in (
        view.authorization_id, view.term_id, view.tranche_id
    )):
        raise TransitionRejected("SHR1 term identity is incomplete")
    _wire_address(view.operator, "SHR1 operator")
    u64(view.seat_generation)
    for name, value in (
        ("responsibility start", view.responsibility_start),
        ("premium cap", view.premium_cap),
        ("service close", view.service_close_at),
        ("term removed", view.term_removed_at),
        ("last liability", view.last_liability_at),
        ("latest disposition", view.latest_duty_disposition_at),
        ("breach recorded", view.breach_recorded_at),
    ):
        u64(value)
    if view.live_duty_count not in (0, 1):
        raise TransitionRejected("SHR1 unresolved duty count is not 0/1")
    if view.last_liability_at == 0:
        raise TransitionRejected("SHR1 last liability must be nonzero")
    if (view.service_close_at == 0) != (view.term_removed_at == 0):
        raise TransitionRejected("SHR1 close/removal pair is partial")
    if view.service_close_at and view.term_removed_at < view.service_close_at:
        raise TransitionRejected("SHR1 removal predates close")
    _validate_history_disposition_v1(
        view.latest_duty_disposition,
        view.latest_duty_disposition_at,
        view.breach_receipt_id,
        view.breach_recorded_at,
        permit_no_duty=True,
    )
    if view.latest_duty_disposition is HistoryDisposition.NO_DUTY:
        if view.live_duty_count != 0 or view.latest_duty_id != ZERO_BYTES32:
            raise TransitionRejected("SHR1 NO_DUTY identity mask is invalid")
    elif view.latest_duty_id == ZERO_BYTES32:
        raise TransitionRejected("SHR1 latest duty identity is absent")
    elif (
        view.latest_duty_disposition
        in (HistoryDisposition.OPEN, HistoryDisposition.FAILED_OVER)
    ) != (view.live_duty_count == 1):
        raise TransitionRejected("SHR1 unresolved duty count is inconsistent")
    clocks = (
        view.responsibility_start,
        view.premium_cap,
        view.service_close_at,
        view.term_removed_at,
        view.latest_duty_disposition_at,
        view.breach_recorded_at,
    )
    if any(value > view.last_liability_at for value in clocks):
        raise TransitionRejected("SHR1 clock exceeds last liability")
    return b"".join((
        _abi_magic_word(SHR1_MAGIC),
        view.authorization_id,
        _abi_uint_word(view.seat_generation, 64, "SHR1 generation"),
        view.term_id,
        view.tranche_id,
        _abi_address_word(view.operator, "SHR1 operator"),
        _abi_uint_word(view.responsibility_start, 64, "SHR1 start"),
        _abi_uint_word(view.premium_cap, 64, "SHR1 premium cap"),
        _abi_uint_word(view.service_close_at, 64, "SHR1 close"),
        _abi_uint_word(view.term_removed_at, 64, "SHR1 removed"),
        _abi_uint_word(view.last_liability_at, 64, "SHR1 liability"),
        _abi_uint_word(view.live_duty_count, 16, "SHR1 duty count"),
        view.latest_duty_id,
        _abi_uint_word(
            view.latest_duty_disposition.value, 8, "SHR1 disposition"
        ),
        _abi_uint_word(
            view.latest_duty_disposition_at, 64, "SHR1 disposition at"
        ),
        view.breach_receipt_id,
        _abi_uint_word(
            view.breach_recorded_at, 64, "SHR1 breach recorded"
        ),
    ))


def decode_seat_market_record_v1(raw: bytes) -> SeatMarketRecordV1:
    words = _fixed_wire_words(raw, 17, SHR1_MAGIC, "SHR1 term")
    view = SeatMarketRecordV1(
        words[1],
        _decode_uint_word(words[2], 64, "SHR1 generation"),
        words[3], words[4],
        _decode_address_word(words[5], "SHR1 operator"),
        _decode_uint_word(words[6], 64, "SHR1 start"),
        _decode_uint_word(words[7], 64, "SHR1 premium cap"),
        _decode_uint_word(words[8], 64, "SHR1 close"),
        _decode_uint_word(words[9], 64, "SHR1 removed"),
        _decode_uint_word(words[10], 64, "SHR1 liability"),
        _decode_uint_word(words[11], 16, "SHR1 duty count"),
        words[12],
        _decode_wire_enum(
            words[13], HistoryDisposition, "SHR1 disposition"
        ),  # type: ignore[arg-type]
        _decode_uint_word(words[14], 64, "SHR1 disposition at"),
        words[15],
        _decode_uint_word(words[16], 64, "SHR1 breach recorded"),
    )
    if encode_seat_market_record_v1(view) != raw:
        raise TransitionRejected("SHR1 term row is not canonical")
    return view


def encode_seat_duty_record_v1(view: SeatDutyRecordV1) -> bytes:
    """Encode the exact permanent 11-word Settlement duty history row."""

    if type(view) is not SeatDutyRecordV1:
        raise TransitionRejected("malformed SHR1 duty record")
    for name, raw in (
        ("authorization", view.authorization_id),
        ("duty", view.duty_id),
        ("term", view.term_id),
        ("tranche", view.tranche_id),
        ("breach receipt", view.breach_receipt_id),
    ):
        _bytes32(raw, f"SHR1 duty {name}")
    if any(raw == ZERO_BYTES32 for raw in (
        view.authorization_id, view.duty_id, view.term_id, view.tranche_id
    )):
        raise TransitionRejected("SHR1 duty identity is incomplete")
    u64(view.seat_generation)
    u64(view.disposition_at)
    u64(view.last_liability_at)
    u64(view.breach_recorded_at)
    if view.last_liability_at == 0:
        raise TransitionRejected("SHR1 duty liability must be nonzero")
    _validate_history_disposition_v1(
        view.disposition,
        view.disposition_at,
        view.breach_receipt_id,
        view.breach_recorded_at,
        permit_no_duty=False,
    )
    if max(view.disposition_at, view.breach_recorded_at) > view.last_liability_at:
        raise TransitionRejected("SHR1 duty clock exceeds liability")
    if view.disposition is HistoryDisposition.BREACHED and (
        view.breach_receipt_id
        != seat_breach_receipt_id_v1(
            view.duty_id,
            view.term_id,
            view.tranche_id,
            view.breach_recorded_at,
        )
    ):
        raise TransitionRejected("SHR1 breach receipt is not derived")
    return b"".join((
        _abi_magic_word(SHR1_MAGIC),
        view.authorization_id,
        _abi_uint_word(view.seat_generation, 64, "SHR1 duty generation"),
        view.duty_id,
        view.term_id,
        view.tranche_id,
        _abi_uint_word(view.disposition.value, 8, "SHR1 duty disposition"),
        _abi_uint_word(view.disposition_at, 64, "SHR1 duty disposition at"),
        _abi_uint_word(view.last_liability_at, 64, "SHR1 duty liability"),
        view.breach_receipt_id,
        _abi_uint_word(view.breach_recorded_at, 64, "SHR1 duty breach at"),
    ))


def decode_seat_duty_record_v1(raw: bytes) -> SeatDutyRecordV1:
    words = _fixed_wire_words(raw, 11, SHR1_MAGIC, "SHR1 duty")
    view = SeatDutyRecordV1(
        words[1],
        _decode_uint_word(words[2], 64, "SHR1 duty generation"),
        words[3], words[4], words[5],
        _decode_wire_enum(
            words[6], HistoryDisposition, "SHR1 duty disposition"
        ),  # type: ignore[arg-type]
        _decode_uint_word(words[7], 64, "SHR1 duty disposition at"),
        _decode_uint_word(words[8], 64, "SHR1 duty liability"),
        words[9],
        _decode_uint_word(words[10], 64, "SHR1 duty breach at"),
    )
    if encode_seat_duty_record_v1(view) != raw:
        raise TransitionRejected("SHR1 duty row is not canonical")
    return view


def _encode_seat_mutation_receipt_words(
    receipt: SeatMutationReceiptV1, receipt_hash: bytes
) -> bytes:
    return b"".join((
        _abi_magic_word(SMR1_MAGIC),
        _abi_uint_word(receipt.result.value, 8, "SMR1 result"),
        _abi_uint_word(receipt.operation.value, 8, "SMR1 operation"),
        u256(receipt.intent_sequence),
        receipt.intent_hash,
        u256(receipt.pre_state_version),
        u256(receipt.post_state_version),
        u256(receipt.pre_wire_nonce),
        u256(receipt.post_wire_nonce),
        receipt.pre_last_receipt_hash,
        receipt_hash,
        receipt.stage_id,
        receipt.offer_id,
        receipt.tranche_id,
        _abi_address_word(receipt.operator, "SMR1 operator", allow_zero=True),
        _abi_address_word(receipt.payout, "SMR1 payout", allow_zero=True),
        u256(receipt.ask_wei_per_second),
        _abi_uint_word(receipt.selected_rank, 8, "SMR1 selected rank"),
        receipt.outgoing_term_id,
        _abi_uint_word(receipt.handover_at, 64, "SMR1 handover"),
        _abi_uint_word(receipt.expires_at, 64, "SMR1 expiry"),
        receipt.reserve_id,
        u256(receipt.reserve_wei),
        receipt.credit_id,
        u256(receipt.amount),
    ))


def seat_mutation_receipt_hash(receipt: SeatMutationReceiptV1) -> bytes:
    if type(receipt) is not SeatMutationReceiptV1:
        raise TransitionRejected("malformed SMR1 receipt")
    raw = _encode_seat_mutation_receipt_words(receipt, ZERO_BYTES32)
    return keccak256(D_WIRE_RECEIPT + len(raw).to_bytes(2, "big") + raw)


def encode_seat_mutation_receipt_v1(receipt: SeatMutationReceiptV1) -> bytes:
    if type(receipt) is not SeatMutationReceiptV1:
        raise TransitionRejected("malformed SMR1 receipt")
    _wire_enum(receipt.result, WireResult, "SMR1 result")
    _wire_enum(receipt.operation, WireOperation, "SMR1 operation")
    if receipt.operation is WireOperation.NONE:
        raise TransitionRejected("SMR1 operation must be live")
    _uint(receipt.intent_sequence, "SMR1 intent sequence")
    if receipt.intent_sequence == 0:
        raise TransitionRejected("SMR1 sequence must be nonzero")
    for name, raw in (
        ("intent hash", receipt.intent_hash),
        ("pre-last receipt", receipt.pre_last_receipt_hash),
        ("receipt hash", receipt.receipt_hash),
        ("stage", receipt.stage_id),
        ("offer", receipt.offer_id),
        ("tranche", receipt.tranche_id),
        ("outgoing term", receipt.outgoing_term_id),
        ("reserve", receipt.reserve_id),
        ("credit", receipt.credit_id),
    ):
        _bytes32(raw, f"SMR1 {name}")
    if receipt.intent_hash == ZERO_BYTES32:
        raise TransitionRejected("SMR1 intent hash must be nonzero")
    for name, value in (
        ("pre-state version", receipt.pre_state_version),
        ("post-state version", receipt.post_state_version),
        ("pre-wire nonce", receipt.pre_wire_nonce),
        ("post-wire nonce", receipt.post_wire_nonce),
        ("ask", receipt.ask_wei_per_second),
        ("reserve", receipt.reserve_wei),
        ("amount", receipt.amount),
    ):
        _uint(value, f"SMR1 {name}")
    u64(receipt.handover_at)
    u64(receipt.expires_at)
    if not 0 <= receipt.selected_rank < 4:
        raise TransitionRejected("SMR1 selected rank exceeds four seats")
    _wire_address(receipt.operator, "SMR1 operator", allow_zero=True)
    _wire_address(receipt.payout, "SMR1 payout", allow_zero=True)
    no_op = receipt.result in (WireResult.NO_FEASIBLE, WireResult.UNDERFUNDED)
    if receipt.pre_wire_nonce > receipt.pre_state_version:
        raise TransitionRejected("SMR1 wire nonce exceeds state version")
    if (
        (receipt.pre_wire_nonce == 0)
        != (receipt.pre_last_receipt_hash == ZERO_BYTES32)
    ):
        raise TransitionRejected("SMR1 receipt-chain prestate is inconsistent")
    payload = (
        receipt.stage_id,
        receipt.offer_id,
        receipt.tranche_id,
        receipt.operator != ZERO_ADDRESS,
        receipt.payout != ZERO_ADDRESS,
        receipt.ask_wei_per_second,
        receipt.selected_rank,
        receipt.outgoing_term_id,
        receipt.handover_at,
        receipt.expires_at,
        receipt.reserve_id,
        receipt.reserve_wei,
        receipt.credit_id,
        receipt.amount,
    )
    if no_op:
        if receipt.operation is not WireOperation.STAGE:
            raise TransitionRejected("SMR1 no-op is only valid for STAGE")
        if (
            receipt.post_state_version != receipt.pre_state_version
            or receipt.post_wire_nonce != receipt.pre_wire_nonce
            or receipt.receipt_hash != ZERO_BYTES32
            or any(item not in (0, False, ZERO_BYTES32) for item in payload)
        ):
            raise TransitionRejected("SMR1 no-op changed state or used payload")
    else:
        if (
            receipt.post_state_version
            != checked_add(receipt.pre_state_version, 1)
            or receipt.post_wire_nonce != checked_add(receipt.pre_wire_nonce, 1)
        ):
            raise TransitionRejected("SMR1 mutation counters are not consecutive")
        if receipt.receipt_hash != seat_mutation_receipt_hash(receipt):
            raise TransitionRejected("SMR1 receipt hash is not canonical")
        if (
            receipt.stage_id == ZERO_BYTES32
            or receipt.offer_id == ZERO_BYTES32
            or receipt.tranche_id == ZERO_BYTES32
            or receipt.operator == ZERO_ADDRESS
            or receipt.payout == ZERO_ADDRESS
        ):
            raise TransitionRejected("SMR1 mutation identity is incomplete")
        if receipt.handover_at == 0 or receipt.expires_at < receipt.handover_at:
            raise TransitionRejected("SMR1 mutation stage interval is invalid")
        if receipt.result is WireResult.STAGED:
            if receipt.operation is not WireOperation.STAGE:
                raise TransitionRejected("SMR1 STAGED operation mismatch")
            if receipt.reserve_wei == 0:
                if receipt.ask_wei_per_second != 0 or receipt.reserve_id != ZERO_BYTES32:
                    raise TransitionRejected("SMR1 zero reserve is not canonical")
            elif receipt.ask_wei_per_second == 0 or receipt.reserve_id == ZERO_BYTES32:
                raise TransitionRejected("SMR1 funded reserve is incomplete")
            if receipt.credit_id != ZERO_BYTES32 or receipt.amount != receipt.reserve_wei:
                raise TransitionRejected("SMR1 STAGED economic payload is noncanonical")
        elif receipt.result is WireResult.APPLIED:
            if receipt.operation is not WireOperation.APPLY:
                raise TransitionRejected("SMR1 APPLIED operation mismatch")
            if receipt.reserve_wei == 0:
                if receipt.ask_wei_per_second != 0 or receipt.reserve_id != ZERO_BYTES32:
                    raise TransitionRejected("SMR1 APPLIED zero reserve is noncanonical")
            elif receipt.ask_wei_per_second == 0 or receipt.reserve_id == ZERO_BYTES32:
                raise TransitionRejected("SMR1 APPLIED funded reserve is incomplete")
            if (receipt.credit_id == ZERO_BYTES32) != (receipt.amount == 0):
                raise TransitionRejected("SMR1 APPLIED premium credit pair is incomplete")
            if receipt.outgoing_term_id == ZERO_BYTES32 and (
                receipt.credit_id != ZERO_BYTES32 or receipt.amount != 0
            ):
                raise TransitionRejected("SMR1 APPLIED has credit without outgoing term")
        elif receipt.result is WireResult.RESTORED:
            if receipt.operation not in (
                WireOperation.EXPIRE, WireOperation.INVALIDATE
            ):
                raise TransitionRejected("SMR1 RESTORED operation mismatch")
            if (
                receipt.reserve_id != ZERO_BYTES32
                or receipt.reserve_wei != 0
                or receipt.credit_id != ZERO_BYTES32
                or (receipt.ask_wei_per_second == 0) != (receipt.amount == 0)
            ):
                raise TransitionRejected("SMR1 RESTORED economics are noncanonical")
        elif receipt.result is WireResult.OWNER_TERMINALIZED:
            if receipt.operation not in (
                WireOperation.EXPIRE,
                WireOperation.INVALIDATE,
                WireOperation.MIGRATION_CANCEL,
            ):
                raise TransitionRejected("SMR1 terminal operation mismatch")
            if (
                receipt.reserve_id != ZERO_BYTES32
                or receipt.reserve_wei != 0
                or receipt.credit_id == ZERO_BYTES32
                or receipt.amount == 0
            ):
                raise TransitionRejected("SMR1 owner terminal credit is incomplete")
    return _encode_seat_mutation_receipt_words(receipt, receipt.receipt_hash)


def decode_seat_mutation_receipt_v1(raw: bytes) -> SeatMutationReceiptV1:
    words = _fixed_wire_words(raw, 25, SMR1_MAGIC, "SMR1")
    receipt = SeatMutationReceiptV1(
        _decode_wire_enum(words[1], WireResult, "SMR1 result"),  # type: ignore[arg-type]
        _decode_wire_enum(words[2], WireOperation, "SMR1 operation"),  # type: ignore[arg-type]
        _decode_uint_word(words[3], 256, "SMR1 sequence"),
        words[4],
        _decode_uint_word(words[5], 256, "SMR1 pre-state version"),
        _decode_uint_word(words[6], 256, "SMR1 post-state version"),
        _decode_uint_word(words[7], 256, "SMR1 pre-wire nonce"),
        _decode_uint_word(words[8], 256, "SMR1 post-wire nonce"),
        words[9], words[10], words[11], words[12], words[13],
        _decode_address_word(words[14], "SMR1 operator", allow_zero=True),
        _decode_address_word(words[15], "SMR1 payout", allow_zero=True),
        _decode_uint_word(words[16], 256, "SMR1 ask"),
        _decode_uint_word(words[17], 8, "SMR1 rank"),
        words[18],
        _decode_uint_word(words[19], 64, "SMR1 handover"),
        _decode_uint_word(words[20], 64, "SMR1 expiry"),
        words[21],
        _decode_uint_word(words[22], 256, "SMR1 reserve"),
        words[23],
        _decode_uint_word(words[24], 256, "SMR1 amount"),
    )
    if encode_seat_mutation_receipt_v1(receipt) != raw:
        raise TransitionRejected("SMR1 is not canonical")
    return receipt


def encode_market_economic_receipt_v1(view: MarketEconomicReceiptV1) -> bytes:
    if type(view) is not MarketEconomicReceiptV1:
        raise TransitionRejected("malformed MEC1 receipt")
    result = _wire_enum(view.result, EconomicResult, "MEC1 result")
    if _bytes32(view.term_id, "MEC1 term") == ZERO_BYTES32:
        raise TransitionRejected("MEC1 term must be nonzero")
    _bytes32(view.credit_id, "MEC1 credit")
    _uint(view.amount, "MEC1 amount")
    u64(view.deadline)
    if view.result in (EconomicResult.CREDITED, EconomicResult.TERMINALIZED):
        if view.credit_id == ZERO_BYTES32 or view.amount == 0:
            raise TransitionRejected("MEC1 credit result is incomplete")
    elif view.credit_id != ZERO_BYTES32:
        raise TransitionRejected("MEC1 unused credit must be zero")
    if view.result is EconomicResult.NOOP and view.amount != 0:
        raise TransitionRejected("MEC1 no-op amount must be zero")
    return b"".join((
        _abi_magic_word(MEC1_MAGIC),
        _abi_uint_word(result, 8, "MEC1 result"),
        view.term_id,
        view.credit_id,
        u256(view.amount),
        _abi_uint_word(view.deadline, 64, "MEC1 deadline"),
    ))


def decode_market_economic_receipt_v1(raw: bytes) -> MarketEconomicReceiptV1:
    words = _fixed_wire_words(raw, 6, MEC1_MAGIC, "MEC1")
    view = MarketEconomicReceiptV1(
        _decode_wire_enum(words[1], EconomicResult, "MEC1 result"),  # type: ignore[arg-type]
        words[2], words[3],
        _decode_uint_word(words[4], 256, "MEC1 amount"),
        _decode_uint_word(words[5], 64, "MEC1 deadline"),
    )
    if encode_market_economic_receipt_v1(view) != raw:
        raise TransitionRejected("MEC1 is not canonical")
    return view


def encode_market_history_safety_v1(view: MarketHistorySafetyV1) -> bytes:
    if type(view) is not MarketHistorySafetyV1:
        raise TransitionRejected("malformed MHS1 result")
    return _abi_magic_word(MHS1_MAGIC) + _wire_bool(view.safe, "MHS1 safe")


def decode_market_history_safety_v1(raw: bytes) -> MarketHistorySafetyV1:
    words = _fixed_wire_words(raw, 2, MHS1_MAGIC, "MHS1")
    view = MarketHistorySafetyV1(_decode_wire_bool(words[1], "MHS1 safe"))
    if encode_market_history_safety_v1(view) != raw:
        raise TransitionRejected("MHS1 is not canonical")
    return view


def encode_market_rotation_receipt_v1(view: MarketRotationReceiptV1) -> bytes:
    """Canonical fixed-width MRO1 rotation result."""

    if type(view) is not MarketRotationReceiptV1:
        raise TransitionRejected("malformed MRO1 result")
    result = _wire_enum(view.result, MarketRotationResult, "MRO1 result")
    if not 0 <= view.purged_count <= PENDING_COUNT:
        raise TransitionRejected("MRO1 purge count exceeds bounded book")
    for name, raw in (
        ("old authorization", view.old_authorization_id),
        ("new authorization", view.new_authorization_id),
        ("activation receipt", view.activation_receipt_id),
        ("blocking stage", view.blocking_stage_id),
    ):
        _bytes32(raw, f"MRO1 {name}")
    u64(view.successor_index)
    if view.result is MarketRotationResult.RECONCILIATION_REQUIRED:
        if (
            view.old_authorization_id == ZERO_BYTES32
            or view.blocking_stage_id == ZERO_BYTES32
            or view.purged_count != 0
            or view.new_authorization_id != ZERO_BYTES32
            or view.activation_receipt_id != ZERO_BYTES32
            or view.successor_index != 0
        ):
            raise TransitionRejected("MRO1 reconciliation result is noncanonical")
    elif view.result is MarketRotationResult.BOOTSTRAPPED:
        if (
            view.old_authorization_id != ZERO_BYTES32
            or view.purged_count != 0
            or view.new_authorization_id == ZERO_BYTES32
            or view.activation_receipt_id == ZERO_BYTES32
            or view.successor_index == 0
            or view.blocking_stage_id != ZERO_BYTES32
        ):
            raise TransitionRejected("MRO1 bootstrap result is noncanonical")
    elif (
        view.old_authorization_id == ZERO_BYTES32
        or view.new_authorization_id == ZERO_BYTES32
        or view.activation_receipt_id == ZERO_BYTES32
        or view.successor_index == 0
        or view.blocking_stage_id != ZERO_BYTES32
    ):
        raise TransitionRejected("MRO1 advanced result is incomplete")
    return b"".join((
        _abi_magic_word(MRO1_MAGIC),
        _abi_uint_word(result, 8, "MRO1 result"),
        _abi_uint_word(view.purged_count, 8, "MRO1 purge count"),
        view.old_authorization_id,
        view.new_authorization_id,
        view.activation_receipt_id,
        _abi_uint_word(view.successor_index, 64, "MRO1 successor index"),
        view.blocking_stage_id,
    ))


def decode_market_rotation_receipt_v1(raw: bytes) -> MarketRotationReceiptV1:
    words = _fixed_wire_words(raw, 8, MRO1_MAGIC, "MRO1")
    view = MarketRotationReceiptV1(
        _decode_wire_enum(words[1], MarketRotationResult, "MRO1 result"),  # type: ignore[arg-type]
        _decode_uint_word(words[2], 8, "MRO1 purge count"),
        words[3], words[4], words[5],
        _decode_uint_word(words[6], 64, "MRO1 successor index"),
        words[7],
    )
    if encode_market_rotation_receipt_v1(view) != raw:
        raise TransitionRejected("MRO1 is not canonical")
    return view


def activation_receipt_id_v1(view: ActivationReceiptV1) -> bytes:
    if type(view) is not ActivationReceiptV1:
        raise TransitionRejected("malformed ARV1 receipt")
    return keccak256(b"".join((
        b"TAIKO_ACTIVATION_RECEIPT_V1",
        u256(view.settlement_chain_id),
        address20(view.router, "ARV1 router"),
        u64(view.router_generation),
        u64(view.successor_index),
        u8(_wire_enum(
            view.transition_kind, ActivationTransitionKind,
            "ARV1 transition kind",
        )),
        u64(view.source_protocol_version),
        u64(view.target_protocol_version),
        _bytes32(view.source_manifest_hash, "ARV1 source manifest"),
        _bytes32(view.target_manifest_hash, "ARV1 target manifest"),
        _bytes32(view.source_authorization_id, "ARV1 source authorization"),
        _bytes32(view.target_authorization_id, "ARV1 target authorization"),
        _bytes32(view.target_registration_hash, "ARV1 registration"),
        address20(view.source_settlement, "ARV1 source Settlement"),
        address20(view.target_settlement, "ARV1 target Settlement"),
        _bytes32(view.old_destination_domain_id, "ARV1 old domain"),
        _bytes32(view.new_destination_domain_id, "ARV1 new domain"),
        bytes.fromhex(_wire_address(
            view.old_destination_bridge, "ARV1 old bridge", allow_zero=True
        )[2:]),
        bytes.fromhex(_wire_address(
            view.new_destination_bridge, "ARV1 new bridge", allow_zero=True
        )[2:]),
        u64(view.queue_watermark),
        _bytes32(view.candidate_digest, "ARV1 candidate"),
        _bytes32(view.output_canonical_hash, "ARV1 output"),
        u64(view.output_canonical_sequence),
        _bytes32(view.activation_context_hash, "ARV1 context"),
        _bytes32(view.transition_auxiliary_hash, "ARV1 auxiliary"),
        _bytes32(view.source_post_state_commitment, "ARV1 source poststate"),
        _bytes32(view.adoption_commitment, "ARV1 adoption"),
        _bytes32(view.queue_post_state_commitment, "ARV1 queue poststate"),
        u64(view.seat_generation),
        u64(view.activated_at_block),
    )))


def encode_successor_receipt_v1(view: SuccessorReceiptV1) -> bytes:
    if type(view) is not SuccessorReceiptV1:
        raise TransitionRejected("malformed ASV1 receipt")
    if _bytes32(view.receipt_id, "ASV1 receipt") == ZERO_BYTES32:
        raise TransitionRejected("ASV1 receipt must be nonzero")
    if int.from_bytes(u64(view.successor_index), "big") == 0:
        raise TransitionRejected("ASV1 successor index must be nonzero")
    return b"".join((
        view.receipt_id,
        _abi_uint_word(view.successor_index, 64, "ASV1 successor index"),
        _abi_magic_word(ASV1_MAGIC),
    ))


def decode_successor_receipt_v1(raw: bytes) -> SuccessorReceiptV1:
    if type(raw) is not bytes or len(raw) != ASV1_RESPONSE_LENGTH:
        raise TransitionRejected("ASV1 has noncanonical length")
    words = [raw[index:index + 32] for index in range(0, len(raw), 32)]
    if words[2] != _abi_magic_word(ASV1_MAGIC):
        raise TransitionRejected("ASV1 has wrong magic/revision")
    view = SuccessorReceiptV1(
        words[0], _decode_uint_word(words[1], 64, "ASV1 successor index")
    )
    if encode_successor_receipt_v1(view) != raw:
        raise TransitionRejected("ASV1 is not canonical")
    return view


def encode_activation_receipt_v1(view: ActivationReceiptV1) -> bytes:
    if type(view) is not ActivationReceiptV1:
        raise TransitionRejected("malformed ARV1 receipt")
    for name, raw in (
        ("receipt", view.receipt_id),
        ("source manifest", view.source_manifest_hash),
        ("target manifest", view.target_manifest_hash),
        ("source authorization", view.source_authorization_id),
        ("target authorization", view.target_authorization_id),
        ("target registration", view.target_registration_hash),
        ("old destination domain", view.old_destination_domain_id),
        ("new destination domain", view.new_destination_domain_id),
        ("candidate", view.candidate_digest),
        ("output", view.output_canonical_hash),
        ("activation context", view.activation_context_hash),
        ("transition auxiliary", view.transition_auxiliary_hash),
        ("source poststate", view.source_post_state_commitment),
        ("adoption", view.adoption_commitment),
        ("queue poststate", view.queue_post_state_commitment),
    ):
        _bytes32(raw, f"ARV1 {name}")
    _uint(view.settlement_chain_id, "ARV1 Settlement chain ID")
    _wire_address(view.router, "ARV1 router")
    for value in (
        view.router_generation, view.successor_index,
        view.source_protocol_version, view.target_protocol_version,
        view.queue_watermark, view.output_canonical_sequence,
        view.seat_generation, view.activated_at_block,
    ):
        u64(value)
    _wire_enum(view.transition_kind, ActivationTransitionKind, "ARV1 kind")
    _wire_address(view.source_settlement, "ARV1 source Settlement")
    _wire_address(view.target_settlement, "ARV1 target Settlement")
    _wire_address(view.old_destination_bridge, "ARV1 old bridge", allow_zero=True)
    _wire_address(view.new_destination_bridge, "ARV1 new bridge", allow_zero=True)
    if type(view.sealed) is not bool or not view.sealed:
        raise TransitionRejected("ARV1 receipt is not sealed")
    common_nonzero = (
        view.receipt_id,
        view.source_manifest_hash,
        view.target_manifest_hash,
        view.target_authorization_id,
        view.target_registration_hash,
        view.new_destination_domain_id,
        view.candidate_digest,
        view.output_canonical_hash,
        view.activation_context_hash,
        view.source_post_state_commitment,
        view.adoption_commitment,
        view.queue_post_state_commitment,
    )
    if (
        any(raw == ZERO_BYTES32 for raw in common_nonzero)
        or view.router_generation == 0
        or view.successor_index == 0
        or view.target_protocol_version <= view.source_protocol_version
        or view.activated_at_block == 0
        or view.source_settlement == view.target_settlement
        or view.new_destination_bridge == ZERO_ADDRESS
    ):
        raise TransitionRejected("ARV1 common identity is incomplete")
    if view.transition_kind is ActivationTransitionKind.VERSION_MIGRATION:
        if (
            view.source_authorization_id == ZERO_BYTES32
            or view.old_destination_domain_id == ZERO_BYTES32
            or view.new_destination_domain_id == ZERO_BYTES32
            or view.old_destination_bridge == ZERO_ADDRESS
            or view.new_destination_bridge == ZERO_ADDRESS
            or view.transition_auxiliary_hash != ZERO_BYTES32
            or view.seat_generation == 0
        ):
            raise TransitionRejected("ARV1 migration mask is incomplete")
    else:
        if (
            view.source_authorization_id != ZERO_BYTES32
            or view.old_destination_domain_id != ZERO_BYTES32
            or view.old_destination_bridge != ZERO_ADDRESS
            or view.transition_auxiliary_hash == ZERO_BYTES32
            or view.source_protocol_version != 0
            or view.seat_generation != 0
        ):
            raise TransitionRejected("ARV1 genesis mask is invalid")
    if view.receipt_id != activation_receipt_id_v1(view):
        raise TransitionRejected("ARV1 receipt ID is not derived")
    return b"".join((
        _abi_magic_word(ARV1_MAGIC),
        view.receipt_id,
        u256(view.settlement_chain_id),
        _abi_address_word(view.router, "ARV1 router"),
        _abi_uint_word(view.router_generation, 64, "ARV1 generation"),
        _abi_uint_word(view.successor_index, 64, "ARV1 successor index"),
        _abi_uint_word(view.transition_kind.value, 8, "ARV1 kind"),
        _abi_uint_word(view.source_protocol_version, 64, "ARV1 source version"),
        _abi_uint_word(view.target_protocol_version, 64, "ARV1 target version"),
        view.source_manifest_hash,
        view.target_manifest_hash,
        view.source_authorization_id,
        view.target_authorization_id,
        view.target_registration_hash,
        _abi_address_word(view.source_settlement, "ARV1 source Settlement"),
        _abi_address_word(view.target_settlement, "ARV1 target Settlement"),
        view.old_destination_domain_id,
        view.new_destination_domain_id,
        _abi_address_word(
            view.old_destination_bridge, "ARV1 old bridge", allow_zero=True
        ),
        _abi_address_word(
            view.new_destination_bridge, "ARV1 new bridge", allow_zero=True
        ),
        _abi_uint_word(view.queue_watermark, 64, "ARV1 Queue watermark"),
        view.candidate_digest,
        view.output_canonical_hash,
        _abi_uint_word(
            view.output_canonical_sequence, 64, "ARV1 output sequence"
        ),
        view.activation_context_hash,
        view.transition_auxiliary_hash,
        view.source_post_state_commitment,
        view.adoption_commitment,
        view.queue_post_state_commitment,
        _abi_uint_word(view.seat_generation, 64, "ARV1 seat generation"),
        _abi_uint_word(view.activated_at_block, 64, "ARV1 activated block"),
        _wire_bool(view.sealed, "ARV1 sealed"),
    ))


def decode_activation_receipt_v1(raw: bytes) -> ActivationReceiptV1:
    words = _fixed_wire_words(raw, 32, ARV1_MAGIC, "ARV1")
    view = ActivationReceiptV1(
        words[1],
        _decode_uint_word(words[2], 256, "ARV1 Settlement chain ID"),
        _decode_address_word(words[3], "ARV1 router"),
        _decode_uint_word(words[4], 64, "ARV1 generation"),
        _decode_uint_word(words[5], 64, "ARV1 successor index"),
        _decode_wire_enum(
            words[6], ActivationTransitionKind, "ARV1 kind"
        ),  # type: ignore[arg-type]
        _decode_uint_word(words[7], 64, "ARV1 source version"),
        _decode_uint_word(words[8], 64, "ARV1 target version"),
        words[9], words[10], words[11], words[12], words[13],
        _decode_address_word(words[14], "ARV1 source Settlement"),
        _decode_address_word(words[15], "ARV1 target Settlement"),
        words[16], words[17],
        _decode_address_word(words[18], "ARV1 old bridge", allow_zero=True),
        _decode_address_word(words[19], "ARV1 new bridge", allow_zero=True),
        _decode_uint_word(words[20], 64, "ARV1 Queue watermark"),
        words[21], words[22],
        _decode_uint_word(words[23], 64, "ARV1 output sequence"),
        words[24], words[25], words[26], words[27], words[28],
        _decode_uint_word(words[29], 64, "ARV1 seat generation"),
        _decode_uint_word(words[30], 64, "ARV1 activated block"),
        _decode_wire_bool(words[31], "ARV1 sealed"),
    )
    if encode_activation_receipt_v1(view) != raw:
        raise TransitionRejected("ARV1 is not canonical")
    return view


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
        _bytes32(auth.target_manifest_hash, "target manifest hash"),
        _bytes32(auth.target_registration_hash, "target registration hash"),
    )


def seat_term_identity_v1(
    authorization_id: bytes,
    generation: int,
    offer_id: bytes,
    tranche_id: bytes,
    installed_at: int,
    install_revision: int,
) -> bytes:
    """Derive the normative installed-term identity."""

    return hash_fixed(
        D_TERM,
        _bytes32(authorization_id, "term authorization ID"),
        u64(generation),
        _bytes32(offer_id, "term offer ID"),
        _bytes32(tranche_id, "term tranche ID"),
        u64(installed_at),
        u64(install_revision),
    )


def seat_lineup_commitment_v1(
    lineup_revision: int,
    term_ids: tuple[bytes, bytes, bytes, bytes],
) -> bytes:
    """Derive the normative fixed-four-cell lineup commitment."""

    terms = _wire_bytes32_tuple(term_ids, "lineup commitment terms")
    return hash_fixed(D_LINEUP, u64(lineup_revision), *terms)


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
            "_maximum_standby_lease_seconds",
            "_minimum_standby_tenure_seconds",
            "_minimum_ask_improvement_wei_per_second",
            "_minimum_ask_improvement_bps",
            "_premium_claim_delay_seconds",
            "_release_challenge_seconds",
            "_reorg_stability_seconds",
            "_evidence_delay_seconds",
            "_release_manager",
            "_activation_router",
            "_protocol_version_manager_address",
            "_activation_router_address",
            "_activation_router_runtime_hash",
            "_activation_router_configuration_hash",
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
        release_manager: ReleaseManager | None,
        target_runtime: TargetRuntime | None,
        activation_router: object | None = None,
        genesis_pending: bool = False,
        protocol_version_manager_address: str | None = None,
        activation_router_address: str | None = None,
        activation_router_runtime_hash: bytes = b"R" * 32,
        activation_router_configuration_hash: bytes = b"C" * 32,
        starting_quote_sequence: int = 0,
        starting_creation_sequence: int = 0,
        seat_runway_seconds: int = 100,
        handover_delay_seconds: int = 5,
        stage_grace_seconds: int = 5,
        maximum_inclusion_seconds: int = 5,
        maximum_standby_lease_seconds: int = 100,
        minimum_standby_tenure_seconds: int = 10,
        minimum_ask_improvement_wei_per_second: int = 1,
        minimum_ask_improvement_bps: int = 0,
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
        checked_mul(self.immutable_maximum_ask, self._seat_runway_seconds)
        self._handover_delay_seconds = _uint(
            handover_delay_seconds, "handover delay seconds"
        )
        self._stage_grace_seconds = _uint(
            stage_grace_seconds, "stage grace seconds"
        )
        self._maximum_inclusion_seconds = _uint(
            maximum_inclusion_seconds, "maximum inclusion seconds"
        )
        self._maximum_standby_lease_seconds = _uint(
            maximum_standby_lease_seconds, "maximum standby lease seconds"
        )
        self._minimum_standby_tenure_seconds = _uint(
            minimum_standby_tenure_seconds, "minimum standby tenure seconds"
        )
        self._minimum_ask_improvement_wei_per_second = _uint(
            minimum_ask_improvement_wei_per_second,
            "minimum ask improvement wei per second",
        )
        self._minimum_ask_improvement_bps = _uint(
            minimum_ask_improvement_bps, "minimum ask improvement bps"
        )
        if self._minimum_ask_improvement_bps > 10_000 or (
            self._minimum_ask_improvement_wei_per_second == 0
            and self._minimum_ask_improvement_bps == 0
        ):
            raise TransitionRejected("standby improvement policy is invalid")
        lease_floor = checked_add(
            self._minimum_standby_tenure_seconds,
            checked_add(
                self._handover_delay_seconds,
                checked_add(
                    self._stage_grace_seconds,
                    self._maximum_inclusion_seconds,
                ),
            ),
        )
        if self._maximum_standby_lease_seconds < lease_floor:
            raise TransitionRejected("standby lease cannot cover one replacement")
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
        if type(insertion_enabled) is not bool:
            raise TransitionRejected("insertion-enabled flag must be boolean")
        if type(genesis_pending) is not bool or (
            genesis_pending
            and (
                insertion_enabled
                or exact_cached_generation is not None
                or authorization is not None
                or target_runtime is not None
            )
        ):
            raise TransitionRejected("genesis-pending Market must be empty/disabled")
        if not genesis_pending:
            self._validate_authorization_record(authorization)
        initial_authorization_id = (
            ZERO_BYTES32
            if authorization is None
            else authorization_identity(
                self.market_chain_id, self.market_address, authorization
            )
        )
        if release_manager is not None:
            if (type(release_manager) is not ReleaseManager
                    or release_manager.activation_authority is None):
                raise TransitionRejected(
                    "legacy release manager must be an exact object"
                )
            _canonical_address(release_manager.address, "release manager")
        router = (
            None if release_manager is None
            else release_manager.activation_authority
        ) if activation_router is None else activation_router
        if router is None:
            raise TransitionRejected("activation Router must be bound directly")
        legacy_router_adapter = (
            activation_router is None
            and release_manager is not None
            and any(getattr(router, field, None) is None for field in (
                "address", "runtime_hash", "configuration_hash"
            ))
        )
        if not genesis_pending:
            if type(release_manager) is not ReleaseManager:
                raise TransitionRejected(
                    "initialized legacy fixture requires ReleaseManager"
                )
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
                or authorization.target
                    not in release_manager.used_target_addresses
            ):
                raise TransitionRejected("initial target is not manager-authenticated")
        self._release_manager = release_manager
        self._activation_router = router
        default_pvm_address = (
            release_manager.address
            if release_manager is not None
            else getattr(router, "version_manager", None)
        )
        self._protocol_version_manager_address = _canonical_address(
            default_pvm_address if protocol_version_manager_address is None
            else protocol_version_manager_address,
            "ProtocolVersionManager address",
        )
        self._activation_router_address = _canonical_address(
            (
                release_manager.address
                if legacy_router_adapter else getattr(router, "address", None)
            )
            if activation_router_address is None
            else activation_router_address,
            "activation Router address",
        )
        self._activation_router_runtime_hash = _bytes32(
            activation_router_runtime_hash,
            "activation Router runtime hash",
        )
        self._activation_router_configuration_hash = _bytes32(
            activation_router_configuration_hash,
            "activation Router configuration hash",
        )
        if (
            self._activation_router_runtime_hash == ZERO_BYTES32
            or self._activation_router_configuration_hash == ZERO_BYTES32
            or (not legacy_router_adapter and (
                _canonical_address(
                    getattr(router, "address", None),
                    "bound activation Router address",
                ) != self._activation_router_address
                or _model_component_hash(
                    getattr(router, "runtime_hash", None),
                    "bound activation Router runtime",
                ) != self._activation_router_runtime_hash
                or _model_component_hash(
                    getattr(router, "configuration_hash", None),
                    "bound activation Router configuration",
                ) != self._activation_router_configuration_hash
            ))
        ):
            raise TransitionRejected("activation Router binding is inexact")
        self.authorizations: dict[bytes, TargetAuthorization] = (
            {} if genesis_pending else {initial_authorization_id: authorization}
        )
        self.authorization_id_by_target: dict[str, bytes] = (
            {} if genesis_pending else {authorization.target: initial_authorization_id}
        )
        self.target_runtimes: dict[bytes, TargetRuntime] = (
            {} if genesis_pending else {initial_authorization_id: target_runtime}
        )
        self.authorization_enabled: dict[bytes, bool] = (
            {} if genesis_pending else {initial_authorization_id: insertion_enabled}
        )
        self.bootstrap_complete = not genesis_pending
        self.current_authorization_id = (
            initial_authorization_id if self.bootstrap_complete else ZERO_BYTES32
        )
        # Production rotation consumes the Router's exact ARV1 identity and
        # monotone global successor index.
        self.consumed_activation_receipt_ids: set[bytes] = set()
        self.last_activation_successor_index = 0
        self.cached_generation = exact_cached_generation
        self.quote_sequence = exact_quote_sequence
        self.creation_sequence = exact_creation_sequence

        self.offers: dict[bytes, Offer] = {}
        self.tranches: dict[bytes, BondTranche] = {}
        self.tranche_id_by_term: dict[bytes, bytes] = {}
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
        # Production-wire oracle state.  The existing Python façade remains a
        # unit model, but every successful outer Market mutation advances the
        # global version at most once.  Only actual Settlement roster-wire
        # mutations also advance cross_wire_nonce and replace one receipt hash.
        self.market_state_version = 0
        self.cross_wire_nonce = 0
        self.last_receipt_hash = ZERO_BYTES32
        self._atomic_depth = 0
        self.assert_valid()

    def __eq__(self, other: object) -> bool:
        return isinstance(other, SeatMarket) and self.__dict__ == other.__dict__

    def __deepcopy__(self, memo: dict[int, object]) -> "SeatMarket":
        duplicate = object.__new__(type(self))
        memo[id(self)] = duplicate
        for key, value in self.__dict__.items():
            object.__setattr__(
                duplicate,
                key,
                value if key in {"_release_manager", "_activation_router"}
                else copy.deepcopy(value, memo),
            )
        return duplicate

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
    def maximum_standby_lease_seconds(self) -> int:
        return self._maximum_standby_lease_seconds

    @property
    def minimum_standby_tenure_seconds(self) -> int:
        return self._minimum_standby_tenure_seconds

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
        authorization = self.authorizations.get(self.current_authorization_id)
        if authorization is None:
            raise TransitionRejected("Market genesis activation is pending")
        return authorization

    @property
    def release_manager(self) -> ReleaseManager | None:
        return self._release_manager

    @property
    def activation_router(self) -> object:
        return self._activation_router

    @property
    def activation_router_address(self) -> str:
        return self._activation_router_address

    @property
    def insertion_enabled(self) -> bool:
        return self.authorization_enabled.get(self.current_authorization_id, False)

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
            ("target manifest hash", auth.target_manifest_hash),
            ("target registration hash", auth.target_registration_hash),
        ):
            if _bytes32(raw, name) == ZERO_BYTES32:
                raise TransitionRejected(f"{name} must be nonzero")
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

    def market_wire_state_v1(self) -> MarketWireStateV1:
        """Return the strict MWV1 projection used by the production wire oracle."""

        stage = self.stage
        if stage is None:
            return MarketWireStateV1(
                WireJournal.EXECUTING if self._atomic_depth else WireJournal.IDLE,
                self.market_state_version,
                self.cross_wire_nonce,
                self.last_receipt_hash,
                self.current_authorization_id,
                self.cached_generation is not None,
                0 if self.cached_generation is None else self.cached_generation,
                False,
                ZERO_BYTES32,
                ZERO_BYTES32,
                0,
                ZERO_BYTES32,
                ZERO_BYTES32,
                ZERO_ADDRESS,
                ZERO_ADDRESS,
                0,
                0,
                ZERO_BYTES32,
                ZERO_BYTES32,
                0,
                0,
                ZERO_BYTES32,
                0,
            )
        offer = self.offers[stage.offer_id]
        reserve = (
            None
            if stage.reserve_id is None
            else self.accounting.live_reserves[stage.reserve_id]
        )
        return MarketWireStateV1(
            WireJournal.EXECUTING if self._atomic_depth else WireJournal.IDLE,
            self.market_state_version,
            self.cross_wire_nonce,
            self.last_receipt_hash,
            self.current_authorization_id,
            self.cached_generation is not None,
            0 if self.cached_generation is None else self.cached_generation,
            True,
            stage.stage_id,
            offer.authorization_id,
            offer.generation,
            offer.offer_id,
            offer.tranche_id,
            offer.operator,
            offer.payout,
            offer.ask_wei_per_second,
            stage.selected_rank,
            (
                ZERO_BYTES32
                if stage.outgoing_primary_term_id is None
                else stage.outgoing_primary_term_id
            ),
            stage.lineup_commitment,
            stage.handover_at,
            stage.expires_at,
            ZERO_BYTES32 if stage.reserve_id is None else stage.reserve_id,
            0 if reserve is None else reserve.reserved_wei,
        )

    def encode_market_wire_state_v1(self) -> bytes:
        return encode_market_wire_state_v1(self.market_wire_state_v1())

    def _versioned_state_projection(
        self, state: dict[str, object] | None = None
    ) -> object:
        """Exclude read/fault instrumentation and the three version words."""

        source = self.__dict__ if state is None else state
        return (
            source["authorizations"],
            source["authorization_id_by_target"],
            source["authorization_enabled"],
            source["bootstrap_complete"],
            source["current_authorization_id"],
            source["consumed_activation_receipt_ids"],
            source["last_activation_successor_index"],
            source["cached_generation"],
            source["quote_sequence"],
            source["creation_sequence"],
            source["offers"],
            source["tranches"],
            source["tranche_id_by_term"],
            source["credits"],
            source["premium_credits"],
            source["pending_offer_ids"],
            source["stage"],
            source["accounting"],
            source["actual_balance"],
            source["premium_credit_sequence"],
            source["claim_active"],
            source["claim_class"],
        )

    def _transaction_snapshot(self) -> dict[str, object]:
        manager = self._release_manager
        router = self._activation_router
        runtimes = dict(self.target_runtimes)
        state = copy.deepcopy({
            key: value
            for key, value in self.__dict__.items()
            if key not in {
                "_release_manager", "_activation_router", "target_runtimes"
            }
        })
        return {
            "state": state,
            "manager": manager,
            "router": router,
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
            "manager_runtime_states": {} if manager is None else {
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
            assert manager is not None
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
        self._activation_router = snapshot["router"]
        self.target_runtimes = runtimes

    def _wire_receipt_for_transition(
        self,
        operation: WireOperation,
        result: TransitionResult,
        prior_stage: Stage | None,
        pre_state_version: int,
        pre_wire_nonce: int,
        pre_last_receipt_hash: bytes,
    ) -> SeatMutationReceiptV1:
        stage = result.stage if result.stage is not None else prior_stage
        if stage is None:
            raise TransitionRejected("wire mutation lost its exact stage")
        offer = result.offer
        if offer is None:
            offer = self.offers.get(stage.offer_id)
        tranche = result.tranche
        if offer is None or tranche is None:
            raise TransitionRejected("wire mutation lost offer/tranche binding")
        if operation is WireOperation.STAGE:
            wire_result = WireResult.STAGED
        elif operation is WireOperation.APPLY:
            wire_result = WireResult.APPLIED
        elif result.credit_id is not None:
            wire_result = WireResult.OWNER_TERMINALIZED
        else:
            wire_result = WireResult.RESTORED
        post_state_version = checked_add(pre_state_version, 1)
        post_wire_nonce = checked_add(pre_wire_nonce, 1)
        intent_hash = hash_fixed(
            D_LEGACY_WIRE_INTENT,
            u8(operation.value),
            _bytes32(offer.authorization_id, "wire offer authorization"),
            u64(offer.generation),
            _bytes32(stage.stage_id, "wire stage ID"),
            u256(post_wire_nonce),
        )
        reserve_wei = 0
        reserve_id = ZERO_BYTES32
        if wire_result in (WireResult.STAGED, WireResult.APPLIED):
            reserve_key = result.reserve_id
            if reserve_key is not None:
                reserve_id = reserve_key
                reserve = self.accounting.live_reserves.get(reserve_key)
                if reserve is not None:
                    reserve_wei = reserve.reserved_wei
                elif wire_result is WireResult.STAGED:
                    reserve_wei = result.amount
        result_credit_id = (
            result.credit_id
            if result.credit_id is not None
            else result.premium_credit_id
        )
        credit_id = ZERO_BYTES32 if result_credit_id is None else result_credit_id
        amount = self.sla_bond if result.credit_id is not None else result.amount
        draft = SeatMutationReceiptV1(
            wire_result,
            operation,
            post_wire_nonce,
            intent_hash,
            pre_state_version,
            post_state_version,
            pre_wire_nonce,
            post_wire_nonce,
            pre_last_receipt_hash,
            ZERO_BYTES32,
            stage.stage_id,
            offer.offer_id,
            tranche.tranche_id,
            offer.operator,
            offer.payout,
            offer.ask_wei_per_second,
            stage.selected_rank,
            (
                ZERO_BYTES32
                if stage.outgoing_primary_term_id is None
                else stage.outgoing_primary_term_id
            ),
            stage.handover_at,
            stage.expires_at,
            reserve_id,
            reserve_wei,
            credit_id,
            amount,
        )
        return replace(draft, receipt_hash=seat_mutation_receipt_hash(draft))

    def _atomic(
        self,
        transition: Callable[[], TransitionResult],
        *,
        wire_operation: WireOperation | None = None,
    ) -> TransitionResult:
        snapshot = self._transaction_snapshot()
        outermost = self._atomic_depth == 0
        pre_projection = (
            self._versioned_state_projection(snapshot["state"])
            if outermost else None
        )
        pre_state_version = self.market_state_version
        pre_wire_nonce = self.cross_wire_nonce
        pre_last_receipt_hash = self.last_receipt_hash
        prior_stage = copy.deepcopy(self.stage)
        try:
            try:
                self.assert_valid()
            except AssertionError as exc:
                raise TransitionRejected("invalid pre-transition state") from exc
            self._atomic_depth += 1
            result = transition()
            self.assert_valid()
            self._atomic_depth -= 1
            if outermost and self._versioned_state_projection() != pre_projection:
                post_state_version = checked_add(pre_state_version, 1)
                if wire_operation is not None:
                    receipt = self._wire_receipt_for_transition(
                        wire_operation,
                        result,
                        prior_stage,
                        pre_state_version,
                        pre_wire_nonce,
                        pre_last_receipt_hash,
                    )
                    # Strict encode is part of the oracle: no noncanonical
                    # receipt can survive even in the legacy façade.
                    encode_seat_mutation_receipt_v1(receipt)
                    self.cross_wire_nonce = receipt.post_wire_nonce
                    self.last_receipt_hash = receipt.receipt_hash
                self.market_state_version = post_state_version
                self.assert_valid()
            return result
        except BaseException:
            self._restore_transaction(snapshot)
            raise

    def _fault(self, name: str) -> None:
        """Deterministic model-only fault injection; never an authority input."""

        if self.fault_point == name:
            raise RuntimeError(f"injected fault: {name}")

    def sponsor_premium_v1(
        self, caller: str, amount: int,
    ) -> TransitionResult:
        """Model payable permissionless ``sponsorPremiumV1()``.

        The call has no calldata arguments or value callback.  Forced ETH is
        deliberately excluded because only this selector attributes balance
        to the spendable free-premium bucket.
        """

        if SPONSOR_PREMIUM_SELECTOR != keccak256(b"sponsorPremiumV1()")[:4]:
            raise AssertionError("premium sponsorship selector drifted")
        _canonical_address(caller, "premium sponsor")
        if self._atomic_depth != 0 or self.claim_active:
            raise TransitionRejected("premium sponsorship reentrancy")

        def transition() -> TransitionResult:
            value = _uint(amount, "premium sponsorship")
            if value == 0:
                raise TransitionRejected("premium sponsorship must be nonzero")
            self.actual_balance = checked_add(self.actual_balance, value)
            self.accounting.free_premium = checked_add(
                self.accounting.free_premium, value
            )
            return TransitionResult(amount=value)

        return self._atomic(transition)

    def sponsor_premium(self, amount: int) -> TransitionResult:
        """Fixture convenience wrapper for the exact payable V1 entry."""

        return self.sponsor_premium_v1(self.market_address, amount)

    def _settlement_apply_stage_atomic(
        self,
        install: InstallationView,
        post_lineup: LineupSnapshot,
        clock: Clock,
    ) -> TransitionResult:
        """Install one stage while leaving outgoing reserve reconciliation async.

        This is the behavioral oracle for the single APPLY roster wire.  An
        outgoing reserve remains independently conserved until a later exact,
        permissionless reconciliation call consumes its permanent close row.
        """

        def transition() -> TransitionResult:
            self._validate_clock(clock)
            stage = self.stage
            if stage is None:
                raise TransitionRejected("APPLY has no exact Market stage")
            if install.applied_at != clock.timestamp:
                raise TransitionRejected("APPLY clock differs from installation")
            self._validate_lineup_authority(post_lineup)
            if (
                post_lineup.commitment == stage.lineup_commitment
                or install.term_id not in {
                    term.term_id for term in post_lineup.terms
                }
                or (
                    stage.outgoing_primary_term_id is not None
                    and stage.outgoing_primary_term_id in {
                        term.term_id for term in post_lineup.terms
                    }
                )
                or not 0 <= stage.selected_rank < len(post_lineup.terms)
                or post_lineup.terms[stage.selected_rank].term_id
                    != install.term_id
            ):
                raise TransitionRejected("APPLY post-lineup is not exact")
            return self._settlement_install_stage(install)

        return self._atomic(transition, wire_operation=WireOperation.APPLY)

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
            _uint(term.installed_at, "lineup installed at")
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
            ("service close at", view.service_close_at),
            ("term removed at", view.term_removed_at),
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
        if view.closed != (view.service_close_at is not None):
            raise TransitionRejected("service close flag/timestamp disagree")
        if (view.service_close_at is None) != (view.term_removed_at is None):
            raise TransitionRejected("service close/removal pair is partial")
        if (
            view.service_close_at is not None
            and view.term_removed_at < view.service_close_at
        ):
            raise TransitionRejected("term removal predates service close")
        if view.roster_occupied == (view.term_removed_at is not None):
            raise TransitionRejected("roster occupancy/removal disagree")
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
        if disposition == "FAILED_OVER":
            if (
                view.duty_id is None
                or view.disposition_at is None
                or view.breached
                or view.breach_recorded_at is not None
            ):
                raise TransitionRejected("failed-over duty history is inconsistent")
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
        if runtime.authorization != auth:
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

    def _insert_offer(
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
            observed = self._read_authorized_target(
                self.current_authorization_id, expected_phase="ACTIVE"
            )
            observed_generation = self._validate_exact_target_view(observed)
            if (self.cached_generation is None
                    or observed_generation != self.cached_generation):
                raise TransitionRejected(
                    "offer submission requires the exact cached ACTIVE generation"
                )
            self._require_current_authority(target, generation)
            ask = _uint(ask_wei_per_second, "ask")
            if ask > self.immutable_maximum_ask:
                raise TransitionRejected("ask exceeds immutable maximum")
            # Reject arithmetic-poison offers at admission rather than leaving
            # a quote that can never pass the later reserve calculation.
            checked_mul(ask, self.seat_runway_seconds)
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

    def submit_seat_offer_v1(
        self,
        *,
        caller: str,
        payout: str,
        ask_wei_per_second: int,
        clock: Clock,
        value: int,
    ) -> TransitionResult:
        """Exact public offer shape; target and generation are derived."""

        if self.cached_generation is None:
            raise TransitionRejected("generation cache is uninitialized")
        return self._insert_offer(
            caller=caller,
            payout=payout,
            ask_wei_per_second=ask_wei_per_second,
            target=self.authorization.target,
            generation=self.cached_generation,
            clock=clock,
            value=value,
        )

    def _requote(
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
            # Maturity is the admission delay of the bonded tranche, not a
            # clock that an incumbent may push forward with each revision.
            # Copy both dimensions exactly: recomputing either one lets four
            # zero-ask offers occupy every waiting cell forever by requoting
            # immediately before maturity.
            eligible_at_timestamp = old_offer.eligible_at_timestamp
            eligible_at_block = old_offer.eligible_at_block
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
            self.pending_offer_ids.remove(offer_id)
            # A superseded pending quote has never crossed the Settlement
            # boundary and has no protocol consumer.  Delete it rather than
            # permitting payout-only revisions to grow permanent Market
            # storage without adding another bond.
            del self.offers[offer_id]
            self.offers[new_offer_id] = new_offer
            self.pending_offer_ids.append(new_offer_id)
            tranche.current_offer_id = new_offer_id
            self._sort_pending()
            return TransitionResult(offer=new_offer, tranche=tranche)

        return self._atomic(transition)

    def requote_seat_offer_v1(
        self,
        *,
        caller: str,
        offer_id: bytes,
        payout: str,
        ask_wei_per_second: int,
        clock: Clock,
    ) -> TransitionResult:
        """Exact public requote shape; authority comes from owned state."""

        if self.cached_generation is None:
            raise TransitionRejected("generation cache is uninitialized")
        return self._requote(
            caller=caller,
            offer_id=offer_id,
            payout=payout,
            ask_wei_per_second=ask_wei_per_second,
            target=self.authorization.target,
            generation=self.cached_generation,
            clock=clock,
        )

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

            def replaceable_standby(
                offer: Offer,
                terms: tuple[LineupTerm, ...],
                short_handover: int,
            ) -> tuple[bytes, int] | None:
                """Return the deterministic full-lineup standby replacement."""

                if len(terms) != 4:
                    return None
                worst = terms[-1]
                if offer.ask_wei_per_second >= worst.ask_wei_per_second:
                    return None
                improvement = checked_sub(
                    worst.ask_wei_per_second, offer.ask_wei_per_second
                )
                relative = checked_mul_div_up(
                    worst.ask_wei_per_second,
                    self._minimum_ask_improvement_bps,
                    10_000,
                )
                required = min(
                    worst.ask_wei_per_second,
                    max(
                        self._minimum_ask_improvement_wei_per_second,
                        relative,
                    ),
                )
                if improvement < required:
                    return None
                runtime = self.target_runtimes.get(
                    self.current_authorization_id
                )
                if runtime is None:
                    raise TransitionRejected(
                        "standby replacement lacks SIR1 route"
                    )
                install_record = decode_seat_install_record_v1(
                    runtime.read_seat_install_record(worst.term_id)
                )
                if (
                    install_record.authorization_id
                        != self.current_authorization_id
                    or install_record.generation != snapshot.generation
                    or install_record.term_id != worst.term_id
                    or install_record.tranche_id != worst.tranche_id
                    or install_record.offer_id != worst.offer_id
                    or install_record.operator != worst.operator
                    or install_record.payout != worst.payout
                    or install_record.ask_wei_per_second
                        != worst.ask_wei_per_second
                    or install_record.installed_at != worst.installed_at
                ):
                    raise TransitionRejected(
                        "worst standby SIR1 differs from SLV1"
                    )
                lease_expiry = checked_add(
                    install_record.installed_at,
                    self.maximum_standby_lease_seconds,
                )
                u64(lease_expiry)
                minimum_tenure_until = checked_add(
                    install_record.installed_at,
                    self.minimum_standby_tenure_seconds,
                )
                u64(minimum_tenure_until)
                bounded_apply = checked_add(
                    checked_add(short_handover, self.stage_grace_seconds),
                    self.maximum_inclusion_seconds,
                )
                u64(bounded_apply)
                if (
                    clock.timestamp < minimum_tenure_until
                    or bounded_apply > lease_expiry
                ):
                    return None
                rank = 1
                while (
                    rank < len(terms) - 1
                    and terms[rank].ask_wei_per_second
                        <= offer.ask_wei_per_second
                ):
                    rank += 1
                return worst.term_id, rank

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
                        if not structural and len(terms) < 4:
                            # Standby fill never reads or waits for the primary's
                            # minimum tenure because it does not replace service.
                            # This lane remains available when a cheaper primary
                            # challenge cannot fit its longer handover deadline.
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
                            if structural:
                                outgoing_term = None
                                # Preserve the primary and insert after every
                                # existing standby with an equal ask.
                                rank = 1
                                while (
                                    rank < len(terms)
                                    and terms[rank].ask_wei_per_second
                                    <= offer.ask_wei_per_second
                                ):
                                    rank += 1
                if not structural and len(terms) == 4:
                    replacement = replaceable_standby(
                        offer,
                        terms,
                        checked_add(
                            clock.timestamp, self.handover_delay_seconds
                        ),
                    )
                    if replacement is not None:
                        structural = True
                        outgoing_term, rank = replacement
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
            if outgoing is not None and selected_rank == 0:
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

        return self._atomic(transition, wire_operation=WireOperation.STAGE)

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
        restore_current = (
            offer.authorization_id == self.current_authorization_id
            and self.authorization_enabled.get(offer.authorization_id) is True
            and self.cached_generation is not None
            and offer.generation == self.cached_generation
        )
        if restore_current and self.pending_count >= PENDING_COUNT:
            raise TransitionRejected("reserved stage capacity was consumed")
        released_reserve = 0
        if stage.reserve_id is not None:
            reserve = self.accounting.live_reserves.pop(stage.reserve_id, None)
            if (
                reserve is None
                or reserve.lifecycle is not ReserveLifecycle.UNSTARTED
                or reserve.owner_id != stage.stage_id
            ):
                raise TransitionRejected("stage reserve is not exact and unstarted")
            released_reserve = reserve.reserved_wei
            self.accounting.reserved_premium = checked_sub(
                self.accounting.reserved_premium, reserve.reserved_wei
            )
            self.accounting.free_premium = checked_add(
                self.accounting.free_premium, reserve.reserved_wei
            )
        credit_id = None
        if restore_current:
            offer.location = OfferLocation.PENDING
            tranche.usage = TrancheUsage.OFFER
            self.pending_offer_ids.append(offer.offer_id)
            self._sort_pending()
        else:
            # A generation/auth rotation may race delayed stage reconciliation.
            # Restoring that quote would strand a stale PENDING row because an
            # unchanged later sync has no reason to purge it.  Terminalize the
            # exact never-installed tranche instead.
            offer.location = OfferLocation.NONE
            tranche.usage = TrancheUsage.CLOSED_UNINSTALLED
            credit_id = self._terminalize_owner(tranche.tranche_id)
        self.stage = None
        self._fault("after_stage_clear")
        return TransitionResult(
            offer=offer,
            tranche=tranche,
            credit_id=credit_id,
            amount=released_reserve,
        )

    def _settlement_expire_stage(
        self, stage_id: bytes, clock: Clock
    ) -> TransitionResult:
        def transition() -> TransitionResult:
            self._validate_clock(clock)
            if self.stage is None or clock.timestamp <= self.stage.expires_at:
                raise TransitionRejected("stage has not expired")
            return self._restore_stage(stage_id)

        return self._atomic(transition, wire_operation=WireOperation.EXPIRE)

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

        return self._atomic(transition, wire_operation=WireOperation.INVALIDATE)

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
            released = 0
            if stage.reserve_id is not None:
                reserve = self.accounting.live_reserves.pop(stage.reserve_id)
                released = reserve.reserved_wei
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

        return self._atomic(
            transition, wire_operation=WireOperation.MIGRATION_CANCEL
        )

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
            if term in self.tranche_id_by_term:
                raise TransitionRejected("installed term reverse-index collision")
            self.tranche_id_by_term[term] = tranche.tranche_id
            self._fault("after_tranche_usage_change")
            self.stage = None
            self._fault("after_stage_clear")
            return TransitionResult(
                offer=offer,
                tranche=tranche,
                reserve_id=term if stage.reserve_id is not None else None,
            )

        return self._atomic(transition, wire_operation=WireOperation.APPLY)

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

    @staticmethod
    def _history_disposition_text(
        disposition: HistoryDisposition,
    ) -> str:
        return {
            HistoryDisposition.NO_DUTY: "NO_DUTY",
            HistoryDisposition.OPEN: "OPEN",
            HistoryDisposition.FAILED_OVER: "FAILED_OVER",
            HistoryDisposition.SATISFIED: "SATISFIED",
            HistoryDisposition.BREACHED: "BREACHED",
            HistoryDisposition.EXCUSED: "EXCUSED",
            HistoryDisposition.EXCUSED_MIGRATION: "EXCUSED_MIGRATION",
        }[disposition]

    def _read_historical_service_v1(
        self, term_id: bytes
    ) -> tuple[BondTranche, ServiceView, SeatMarketRecordV1,
               SeatDutyRecordV1 | None]:
        """Read and authenticate the exact target-local SHR1 history rows."""

        term = _bytes32(term_id, "historical term ID")
        tranche_id = self.tranche_id_by_term.get(term)
        tranche = None if tranche_id is None else self.tranches.get(tranche_id)
        if tranche is None or tranche.usage is not TrancheUsage.INSTALLED:
            raise TransitionRejected("historical term is not locally installed")
        auth = self.authorizations.get(tranche.authorization_id)
        runtime = self.target_runtimes.get(tranche.authorization_id)
        if auth is None or runtime is None or runtime.authorization != auth:
            raise TransitionRejected("historical authorization route is absent")
        term_row = decode_seat_market_record_v1(
            runtime.read_seat_market_record(term)
        )
        offer = self.offers.get(tranche.current_offer_id)
        if (
            offer is None
            or term_row.authorization_id != tranche.authorization_id
            or term_row.seat_generation != tranche.generation
            or term_row.term_id != term
            or term_row.tranche_id != tranche.tranche_id
            or term_row.operator != tranche.operator
            or offer.operator != tranche.operator
        ):
            raise TransitionRejected("SHR1 term row differs from Market binding")
        duty_row = None
        if term_row.latest_duty_id != ZERO_BYTES32:
            duty_row = decode_seat_duty_record_v1(
                runtime.read_seat_duty_record(term_row.latest_duty_id)
            )
            if (
                duty_row.authorization_id != term_row.authorization_id
                or duty_row.seat_generation != term_row.seat_generation
                or duty_row.duty_id != term_row.latest_duty_id
                or duty_row.term_id != term_row.term_id
                or duty_row.tranche_id != term_row.tranche_id
                or duty_row.disposition
                    is not term_row.latest_duty_disposition
                or duty_row.disposition_at
                    != term_row.latest_duty_disposition_at
                or duty_row.last_liability_at > term_row.last_liability_at
                or duty_row.breach_receipt_id != term_row.breach_receipt_id
                or duty_row.breach_recorded_at != term_row.breach_recorded_at
                or (
                    term_row.latest_duty_disposition
                    in (HistoryDisposition.OPEN, HistoryDisposition.FAILED_OVER)
                ) != (term_row.live_duty_count == 1)
            ):
                raise TransitionRejected("SHR1 term/duty rows disagree")
        elif term_row.live_duty_count != 0:
            raise TransitionRejected("SHR1 term row omits a live duty")
        start = (
            None
            if term_row.responsibility_start == 0
            else term_row.responsibility_start
        )
        funded_until = (
            None if start is None else checked_add(start, self.seat_runway_seconds)
        )
        disposition = self._history_disposition_text(
            term_row.latest_duty_disposition
        )
        refundable = (
            term_row.service_close_at != 0
            and term_row.term_removed_at != 0
            and term_row.latest_duty_disposition in {
                HistoryDisposition.NO_DUTY,
                HistoryDisposition.SATISFIED,
                HistoryDisposition.EXCUSED,
                HistoryDisposition.EXCUSED_MIGRATION,
            }
        )
        view = ServiceView(
            target=auth.target,
            authorization_id=term_row.authorization_id,
            settlement_chain_id=auth.settlement_chain_id,
            protocol_version=auth.protocol_version,
            runtime_hash=auth.runtime_hash,
            configuration_hash=auth.configuration_hash,
            magic=auth.expected_magic,
            generation=term_row.seat_generation,
            term_id=term_row.term_id,
            tranche_id=term_row.tranche_id,
            offer_id=offer.offer_id,
            operator=offer.operator,
            payout=offer.payout,
            ask_wei_per_second=offer.ask_wei_per_second,
            responsibility_start=start,
            premium_funded_until=funded_until,
            settlement_cap=term_row.premium_cap,
            closed=term_row.service_close_at != 0,
            refundable=refundable,
            disposition_at=(
                None
                if term_row.latest_duty_disposition_at == 0
                else term_row.latest_duty_disposition_at
            ),
            last_liability_at=term_row.last_liability_at,
            duty_id=(
                None
                if term_row.latest_duty_id == ZERO_BYTES32
                else term_row.latest_duty_id
            ),
            duty_disposition=disposition,
            breached=(
                term_row.latest_duty_disposition
                is HistoryDisposition.BREACHED
            ),
            breach_recorded_at=(
                None
                if term_row.breach_recorded_at == 0
                else term_row.breach_recorded_at
            ),
            roster_occupied=term_row.term_removed_at == 0,
            history_retained=True,
            service_close_at=(
                None if term_row.service_close_at == 0
                else term_row.service_close_at
            ),
            term_removed_at=(
                None if term_row.term_removed_at == 0
                else term_row.term_removed_at
            ),
        )
        self._validate_service_view(view, tranche)
        self._validate_installed_duty_view(view)
        return tranche, view, term_row, duty_row

    @staticmethod
    def _economic_receipt_v1(
        term_id: bytes, result: TransitionResult
    ) -> bytes:
        credit_id = result.credit_id or result.premium_credit_id or ZERO_BYTES32
        deadline = 0 if result.deadline is None else result.deadline
        if result.credit_id is not None:
            code = EconomicResult.TERMINALIZED
        elif result.premium_credit_id is not None:
            code = EconomicResult.CREDITED
        elif result.amount != 0 or deadline != 0:
            code = EconomicResult.UPDATED
        else:
            code = EconomicResult.NOOP
        return encode_market_economic_receipt_v1(MarketEconomicReceiptV1(
            code, term_id, credit_id, result.amount, deadline
        ))

    def accrue_seat_premium_v1(self, term_id: bytes, clock: Clock) -> bytes:
        def transition() -> bytes:
            _, view, _, _ = self._read_historical_service_v1(term_id)
            return self._economic_receipt_v1(
                view.term_id, self._settlement_accrue_premium(view, clock)
            )

        return self._atomic(transition)

    def reconcile_seat_reserve_v1(self, term_id: bytes, clock: Clock) -> bytes:
        def transition() -> bytes:
            _, view, _, _ = self._read_historical_service_v1(term_id)
            return self._economic_receipt_v1(
                view.term_id,
                self._settlement_close_reserve(
                    view, clock, atomic_healthy=False
                ),
            )

        return self._atomic(transition)

    def request_seat_bond_release_v1(
        self, term_id: bytes, clock: Clock
    ) -> bytes:
        def transition() -> bytes:
            tranche, view, _, _ = self._read_historical_service_v1(term_id)
            return self._economic_receipt_v1(
                view.term_id,
                self._settlement_request_release(
                    tranche.tranche_id, view, clock
                ),
            )

        return self._atomic(transition)

    def finalize_seat_bond_release_v1(
        self, term_id: bytes, clock: Clock
    ) -> bytes:
        def transition() -> bytes:
            tranche, view, _, _ = self._read_historical_service_v1(term_id)
            return self._economic_receipt_v1(
                view.term_id,
                self._settlement_finalize_release(
                    tranche.tranche_id, view, clock
                ),
            )

        return self._atomic(transition)

    def enforce_seat_breach_v1(self, term_id: bytes, clock: Clock) -> bytes:
        def transition() -> bytes:
            tranche, view, _, _ = self._read_historical_service_v1(term_id)
            return self._economic_receipt_v1(
                view.term_id,
                self._settlement_enforce_breach(
                    tranche.tranche_id, view, clock
                ),
            )

        return self._atomic(transition)

    def is_duty_history_safe_v1(
        self,
        duty_id: bytes,
        term_id: bytes,
        tranche_id: bytes,
        clock: Clock,
    ) -> bytes:
        tranche, view, _, duty = self._read_historical_service_v1(term_id)
        exact_duty = _bytes32(duty_id, "history-safe duty")
        exact_tranche = _bytes32(tranche_id, "history-safe tranche")
        if (
            duty is None
            or duty.duty_id != exact_duty
            or tranche.tranche_id != exact_tranche
        ):
            raise TransitionRejected("history-safe identifiers are not exact")
        safe = self._settlement_is_duty_history_safe(
            exact_duty, view.term_id, exact_tranche, view, clock
        )
        return encode_market_history_safety_v1(MarketHistorySafetyV1(safe))

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
                tranche=tranche, credit_id=credit_id,
                amount=self.sla_bond, deadline=owner_at
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
                tranche=tranche, credit_id=credit_id,
                amount=self.sla_bond, deadline=penalty_at
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

    def rotate_settlement_authorization_v1(self, clock: Clock) -> bytes:
        """Advance one authorization hop from exact Router ASV1/ARV1 rows.

        ``clock`` models the EVM block environment; it is not an authority
        input.  The caller supplies no receipt key, target, generation, or
        validity Boolean.
        """

        def transition() -> bytes:
            self._validate_clock(clock)
            router = self._activation_router
            successor_reader = getattr(router, "seat_successor_receipt_v1", None)
            receipt_reader = getattr(router, "activation_receipt_v1", None)
            if (
                not callable(successor_reader)
                or not callable(receipt_reader)
                or getattr(router, "address", None)
                    != self._activation_router_address
                or _model_component_hash(
                    getattr(router, "runtime_hash", None),
                    "activation Router runtime hash",
                ) != self._activation_router_runtime_hash
                or _model_component_hash(
                    getattr(router, "configuration_hash", None),
                    "activation Router configuration hash",
                ) != self._activation_router_configuration_hash
            ):
                raise TransitionRejected("activation Router identity is inexact")

            def read_successor(authorization_id: bytes) -> SuccessorReceiptV1:
                try:
                    return decode_successor_receipt_v1(
                        successor_reader(authorization_id)
                    )
                except (ArithmeticFault, KeyError, TypeError, ValueError) as exc:
                    raise TransitionRejected(
                        "activation successor exact-read failed"
                    ) from exc

            def read_receipt(receipt_id: bytes) -> ActivationReceiptV1:
                try:
                    return decode_activation_receipt_v1(
                        receipt_reader(receipt_id)
                    )
                except (ArithmeticFault, KeyError, TypeError, ValueError) as exc:
                    raise TransitionRejected(
                        "activation receipt exact-read failed"
                    ) from exc

            old_id = self.current_authorization_id
            successor = read_successor(old_id)
            receipt = read_receipt(successor.receipt_id)
            bootstrap = old_id == ZERO_BYTES32
            if (
                receipt.receipt_id != successor.receipt_id
                or receipt.successor_index != successor.successor_index
                or receipt.router != self._activation_router_address
                or receipt.source_authorization_id != old_id
                or receipt.receipt_id in self.consumed_activation_receipt_ids
                or receipt.successor_index
                    <= self.last_activation_successor_index
            ):
                raise TransitionRejected("activation receipt is stale or mismatched")

            old_auth = self.authorizations.get(old_id)
            new_id = receipt.target_authorization_id
            new_auth = self.authorizations.get(new_id)
            new_runtime = self.target_runtimes.get(new_id)
            if (
                new_auth is None
                or new_runtime is None
                or receipt.settlement_chain_id != new_auth.settlement_chain_id
                or receipt.target_protocol_version != new_auth.protocol_version
                or receipt.target_protocol_version
                    <= receipt.source_protocol_version
                or receipt.target_settlement != new_auth.target
                or receipt.target_manifest_hash
                    != new_auth.target_manifest_hash
                or receipt.target_registration_hash
                    != new_auth.target_registration_hash
                or self.authorization_enabled.get(new_id) is not False
                or self.authorization_id_by_target.get(new_auth.target) != new_id
                or authorization_identity(
                    self.market_chain_id, self.market_address, new_auth
                ) != new_id
            ):
                raise TransitionRejected("target authorization was not preinstalled")

            if bootstrap:
                if (
                    self.bootstrap_complete
                    or receipt.transition_kind
                        is not ActivationTransitionKind.GENESIS_IMPORT
                    or receipt.source_protocol_version != 0
                    or receipt.source_authorization_id != ZERO_BYTES32
                    or receipt.seat_generation != 0
                    or receipt.successor_index != 1
                    or any(self.authorization_enabled.values())
                    or self.cached_generation is not None
                    or self.offers
                    or self.tranches
                    or self.stage is not None
                ):
                    raise TransitionRejected("genesis Market activation is inexact")
            elif (
                not self.bootstrap_complete
                or old_auth is None
                or receipt.transition_kind
                    is not ActivationTransitionKind.VERSION_MIGRATION
                or receipt.source_protocol_version != old_auth.protocol_version
                or receipt.source_settlement != old_auth.target
                or receipt.source_manifest_hash
                    != old_auth.target_manifest_hash
            ):
                raise TransitionRejected("migration predecessor is inexact")

            old_view = (
                None
                if bootstrap
                else self._read_authorized_target(old_id, expected_phase="FROZEN")
            )
            new_view = decode_exact_target_view(
                new_runtime.read_exact_target(new_auth.target)
            )
            if new_view.phase not in {"ACTIVE", "FROZEN"}:
                raise TransitionRejected("successor target is not activated")
            self._validate_exact_target_view(
                new_view, expected_phase=new_view.phase
            )
            if (
                new_view.target != receipt.target_settlement
                or new_view.settlement_chain_id != new_auth.settlement_chain_id
                or new_view.protocol_version != new_auth.protocol_version
                or new_view.runtime_hash != new_auth.runtime_hash
                or new_view.configuration_hash != new_auth.configuration_hash
                or new_view.magic != new_auth.expected_magic
                or (
                    not bootstrap
                    and (
                        old_view is None
                        or old_view.generation != receipt.seat_generation
                        or old_view.target != receipt.source_settlement
                    )
                )
            ):
                raise TransitionRejected("target state does not bind ARV1")
            if new_view.phase == "ACTIVE":
                if (
                    new_view.generation != receipt.seat_generation
                    or getattr(router, "active_version", None)
                        != new_auth.protocol_version
                ):
                    raise TransitionRejected("ACTIVE successor is not Router-current")
            else:
                # A skipped successor's live generation has advanced since
                # the receipt that first activated it.  Bind that mutable
                # FROZEN state to the next immutable receipt before advancing.
                next_successor = read_successor(new_id)
                next_receipt = read_receipt(next_successor.receipt_id)
                if (
                    next_successor.successor_index <= receipt.successor_index
                    or next_receipt.receipt_id != next_successor.receipt_id
                    or next_receipt.successor_index
                        != next_successor.successor_index
                    or next_receipt.transition_kind
                        is not ActivationTransitionKind.VERSION_MIGRATION
                    or next_receipt.source_authorization_id != new_id
                    or next_receipt.source_protocol_version
                        != new_auth.protocol_version
                    or next_receipt.source_settlement != new_auth.target
                    or next_receipt.source_manifest_hash
                        != new_auth.target_manifest_hash
                    or next_receipt.seat_generation != new_view.generation
                ):
                    raise TransitionRejected("FROZEN successor has no later hop")

            if self.stage is not None:
                # Strict no-write response: the caller must reconcile the
                # exact stage through the ordinary mutation wire first.
                return encode_market_rotation_receipt_v1(MarketRotationReceiptV1(
                    MarketRotationResult.RECONCILIATION_REQUIRED,
                    0,
                    old_id,
                    ZERO_BYTES32,
                    ZERO_BYTES32,
                    0,
                    self.stage.stage_id,
                ))

            purged = 0
            for offer_id in tuple(self.pending_offer_ids):
                offer = self.offers[offer_id]
                tranche = self.tranches[offer.tranche_id]
                if (
                    offer.authorization_id != old_id
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

            if not bootstrap:
                self.authorization_enabled[old_id] = False
                self._fault("after_old_target_disablement")
            self.authorization_enabled[new_id] = new_view.phase == "ACTIVE"
            self._fault("after_new_target_enablement")
            # Genesis exact-read the canonical zero constructor generation;
            # preserve it as initialized. Later migrations clear the cache.
            self.cached_generation = 0 if bootstrap else None
            self._fault("after_generation_cache_reset")
            self.current_authorization_id = new_id
            self.bootstrap_complete = True
            self._fault("after_current_target_update")
            self.consumed_activation_receipt_ids.add(receipt.receipt_id)
            self.last_activation_successor_index = receipt.successor_index
            self._fault("after_activation_receipt_consumption")
            return encode_market_rotation_receipt_v1(MarketRotationReceiptV1(
                (
                    MarketRotationResult.BOOTSTRAPPED
                    if bootstrap
                    else MarketRotationResult.ADVANCED
                ),
                purged,
                old_id,
                new_id,
                receipt.receipt_id,
                receipt.successor_index,
                ZERO_BYTES32,
            ))

        return self._atomic(transition)

    def _pvm_preinstall_authorization(
        self,
        manager: ReleaseManager,
        authorization_id: bytes,
    ) -> TransitionResult:
        """Model the REGISTER_RELEASE Market install before activation.

        Production admits this mutation only from the immutable PVM APPLYING
        frame.  The focused model uses the immutable ReleaseManager object as
        that already-authenticated registration source.
        """

        def transition() -> TransitionResult:
            if manager is not self._release_manager:
                raise TransitionRejected("preinstall missed immutable manager")
            _bytes32(authorization_id, "preinstalled authorization ID")
            authorization = manager.authorizations.get(authorization_id)
            runtime = manager.target_runtimes.get(authorization_id)
            if (
                authorization is None
                or runtime is None
                or manager.target_bindings.get(authorization_id)
                != (self.market_chain_id, self.market_address)
                or authorization_identity(
                    self.market_chain_id, self.market_address, authorization
                ) != authorization_id
                or runtime.authorization != authorization
                or authorization_id in self.authorizations
                or authorization.target in self.authorization_id_by_target
            ):
                raise TransitionRejected("preinstalled authorization is not exact")
            self.authorizations[authorization_id] = authorization
            self.target_runtimes[authorization_id] = runtime
            self.authorization_enabled[authorization_id] = False
            self.authorization_id_by_target[authorization.target] = authorization_id
            return TransitionResult()

        return self._atomic(transition)

    def _pvm_authorization_snapshot_v1(self) -> tuple[object, ...]:
        """Snapshot the exact stores mutated by REGISTER_RELEASE."""

        return (
            dict(self.authorizations), dict(self.target_runtimes),
            dict(self.authorization_enabled),
            dict(self.authorization_id_by_target), self.market_state_version,
        )

    def _restore_pvm_authorization_snapshot_v1(
        self, snapshot: tuple[object, ...],
    ) -> None:
        (
            authorizations, runtimes, enabled, by_target,
            self.market_state_version,
        ) = snapshot
        self.authorizations = authorizations  # type: ignore[assignment]
        self.target_runtimes = runtimes  # type: ignore[assignment]
        self.authorization_enabled = enabled  # type: ignore[assignment]
        self.authorization_id_by_target = by_target  # type: ignore[assignment]

    def install_settlement_authorization_from_pvm_v1(
        self, row: object, *, manager: object, router: object,
    ) -> bytes:
        """Install SAT1 into the same stores consumed by live rotation."""

        required = (
            "protocol_version", "target", "runtime_hash",
            "configuration_hash", "expected_magic", "target_manifest_hash",
            "target_registration_hash", "authorization_id",
        )
        if any(not hasattr(row, name) for name in required):
            raise TransitionRejected("PVM authorization row is malformed")
        if (
            getattr(manager, "address", None)
                != self._protocol_version_manager_address
            or getattr(manager, "lifecycle", None) != "APPLYING"
            or getattr(manager, "_active_operation_kind", None) != 1
            or getattr(manager, "_active_operation_consumed", None) is not True
            or getattr(manager, "router", None) is not router
            or getattr(getattr(manager, "market", None), "storage_backend", None)
                is not self
            or getattr(router, "address", None)
                != self._activation_router_address
            or _model_component_hash(
                getattr(router, "runtime_hash", ""), "Router runtime"
            ) != self._activation_router_runtime_hash
            or _model_component_hash(
                getattr(router, "configuration_hash", ""),
                "Router configuration",
            ) != self._activation_router_configuration_hash
        ):
            raise TransitionRejected("Market installation is outside PVM frame")

        target = "0x" + bytes(getattr(row, "target")).hex()
        authorization = TargetAuthorization(
            target=target,
            settlement_chain_id=self.market_chain_id,
            protocol_version=int(getattr(row, "protocol_version")),
            runtime_hash=bytes(getattr(row, "runtime_hash")),
            configuration_hash=bytes(getattr(row, "configuration_hash")),
            expected_magic=bytes(getattr(row, "expected_magic")),
            target_manifest_hash=bytes(getattr(row, "target_manifest_hash")),
            target_registration_hash=bytes(
                getattr(row, "target_registration_hash")
            ),
        )
        authorization_id = bytes(getattr(row, "authorization_id"))

        def transition() -> bytes:
            witnesses = getattr(manager, "release_witnesses", None)
            witness = (
                None
                if type(witnesses) is not dict
                else witnesses.get(authorization.protocol_version)
            )
            authority = getattr(witness, "settlement", None)
            runtime = TargetRuntime(authorization, authority)
            if (
                authorization_identity(
                    self.market_chain_id, self.market_address, authorization
                ) != authorization_id
                or authority is None
                or getattr(authority, "address", None) != authorization.target
                or _model_component_hash(
                    getattr(authority, "runtime_hash", ""),
                    "target runtime",
                ) != authorization.runtime_hash
                or getattr(authority, "market_settlement_chain_id", None)
                    != authorization.settlement_chain_id
                or getattr(authority, "protocol_version", None)
                    != authorization.protocol_version
                or getattr(authority, "market_configuration_hash", None)
                    != authorization.configuration_hash
                or getattr(authority, "market_magic", None)
                    != authorization.expected_magic
                or authorization_id in self.authorizations
                or authorization.target in self.authorization_id_by_target
            ):
                raise TransitionRejected("PVM authorization is not exact")
            self.authorizations[authorization_id] = authorization
            self.target_runtimes[authorization_id] = runtime
            self.authorization_enabled[authorization_id] = False
            self.authorization_id_by_target[authorization.target] = authorization_id
            self.market_state_version = checked_add(
                self.market_state_version, 1
            )
            return b"SAI1" + bytes(28) + authorization_id

        return self._atomic(transition)

    def settlement_authorization_from_pvm_v1(
        self, authorization_id: bytes,
    ) -> bytes:
        """Return the exact 256-byte SAT1 row from rotation's live store."""

        authorization = self.authorizations.get(authorization_id)
        if authorization is None:
            raise TransitionRejected("unknown Settlement authorization")
        return b"".join((
            b"SAT1" + bytes(28),
            u256(authorization.protocol_version),
            _abi_address_word(authorization.target, "SAT1 target"),
            authorization.runtime_hash,
            authorization.configuration_hash,
            _abi_magic_word(authorization.expected_magic),
            authorization.target_manifest_hash,
            authorization.target_registration_hash,
        ))

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
        _uint(self.market_state_version, "Market state version")
        _uint(self.cross_wire_nonce, "cross-wire nonce")
        _bytes32(self.last_receipt_hash, "last wire receipt hash")
        if (
            type(self._atomic_depth) is not int
            or self._atomic_depth < 0
            or self._atomic_depth > 8
        ):
            raise AssertionError("Market atomic depth is invalid")
        if self.cross_wire_nonce > self.market_state_version:
            raise AssertionError("cross-wire nonce exceeds Market state version")
        if (self.cross_wire_nonce == 0) != (
            self.last_receipt_hash == ZERO_BYTES32
        ):
            raise AssertionError("wire nonce/last receipt state is inconsistent")
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
            "after_rotation_pending_purge_1",
            "after_rotation_pending_purge_2",
            "after_rotation_pending_purge_3",
            "after_rotation_pending_purge_4",
            "after_old_target_disablement",
            "after_new_target_enablement",
            "after_generation_cache_reset",
            "after_current_target_update",
            "after_activation_receipt_consumption",
        }
        if self.fault_point not in known_faults:
            raise AssertionError("unknown model-only fault point")
        _bytes32(self.current_authorization_id, "current authorization ID")
        if set(self.authorizations) != set(self.authorization_enabled):
            raise AssertionError("authorization registry/enabled keys differ")
        if set(self.authorizations) != set(self.target_runtimes):
            raise AssertionError("authorization/runtime keys differ")
        if (
            len(self.authorization_id_by_target) != len(self.authorizations)
            or set(self.authorization_id_by_target.values())
            != set(self.authorizations)
        ):
            raise AssertionError("authorization target reverse index differs")
        if (self._release_manager is not None
                and type(self._release_manager) is not ReleaseManager):
            raise AssertionError("legacy release manager object changed")
        if self._activation_router is None:
            raise AssertionError("immutable activation Router is absent")
        if type(self.bootstrap_complete) is not bool:
            raise AssertionError("Market bootstrap flag is malformed")
        if self.bootstrap_complete:
            if self.current_authorization_id not in self.authorizations:
                raise AssertionError("current authorization is not registered")
        elif (
            self.current_authorization_id != ZERO_BYTES32
            or any(self.authorization_enabled.values())
            or self.cached_generation is not None
            or self.offers
            or self.tranches
            or self.pending_offer_ids
            or self.stage is not None
            or self.accounting.accounted_balance != 0
        ):
            raise AssertionError("genesis-pending Market state is not empty/disabled")
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
            if self.authorization_id_by_target.get(auth.target) != authorization_id:
                raise AssertionError("authorization target reverse lookup changed")
            runtime = self.target_runtimes[authorization_id]
            if (
                type(runtime) is not TargetRuntime
                or runtime.authorization != auth
            ):
                raise AssertionError("authorization runtime route changed")
        _uint(
            self.last_activation_successor_index,
            "last activation successor index",
        )
        if self.last_activation_successor_index > UINT64_MAX:
            raise AssertionError("activation successor index exceeds uint64")
        if bool(self.consumed_activation_receipt_ids) != (
            self.last_activation_successor_index > 0
        ):
            raise AssertionError("direct rotation cursor/receipt set is inconsistent")
        for receipt_id in self.consumed_activation_receipt_ids:
            _bytes32(receipt_id, "consumed ARV1 receipt ID")
            if receipt_id == ZERO_BYTES32:
                raise AssertionError("consumed ARV1 receipt ID is zero")
        if (self._release_manager is not None
                and self._release_manager.used_target_addresses != {
                    auth.target
                    for auth in self._release_manager.authorizations.values()
                }):
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
                    "outgoing term ID",
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

        expected_term_index = {
            tranche.installed_term_id: tranche_id
            for tranche_id, tranche in self.tranches.items()
            if tranche.usage is TrancheUsage.INSTALLED
        }
        if self.tranche_id_by_term != expected_term_index:
            raise AssertionError("installed term reverse index is not exact")

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
