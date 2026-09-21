#!/usr/bin/env python3
"""Executable state-machine model for Slot-Chain settlement and recovery.

Cryptographic verification is represented by explicit booleans. Byte-exact
Merkle and commitment fixtures live in commitment-model.py. Unlike the earlier
model, historical headers are immutable and due coverage is a boundary check,
not a scan hidden inside trusted Python state.
"""

from __future__ import annotations

import copy
from dataclasses import (
    InitVar, dataclass, field, fields as dataclass_fields, is_dataclass, replace,
)
from enum import Enum, IntEnum, IntFlag, auto
import hashlib
import sys
try:
    from Crypto.Hash import keccak as _native_keccak
except ImportError:  # Keep the executable specification independently runnable.
    _native_keccak = None
from types import MappingProxyType
from typing import Any, Callable, Optional


_KECCAK_MASK64 = (1 << 64) - 1
_KECCAK_ROT = (
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39,
    41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
)
_KECCAK_RC = (
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
    0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
    0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
    0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
    0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
    0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
    0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
)


def _keccak_rol(value: int, count: int) -> int:
    return (
        ((value << count) | (value >> (64 - count))) & _KECCAK_MASK64
        if count else value
    )


def _keccak_f(state: list[int]) -> None:
    for rc in _KECCAK_RC:
        c = [
            state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            for x in range(5)
        ]
        d = [c[(x - 1) % 5] ^ _keccak_rol(c[(x + 1) % 5], 1) for x in range(5)]
        for y in range(5):
            for x in range(5):
                state[x + 5 * y] ^= d[x]
        b = [0] * 25
        for y in range(5):
            for x in range(5):
                b[y + 5 * ((2 * x + 3 * y) % 5)] = _keccak_rol(
                    state[x + 5 * y], _KECCAK_ROT[x + 5 * y]
                )
        for y in range(5):
            for x in range(5):
                state[x + 5 * y] = b[x + 5 * y] ^ (
                    ((~b[(x + 1) % 5 + 5 * y]) & _KECCAK_MASK64)
                    & b[(x + 2) % 5 + 5 * y]
                )
        state[0] ^= rc


def _keccak256_pure(data: bytes) -> bytes:
    rate = 136
    padded = bytearray(data)
    remaining = rate - (len(padded) % rate)
    if remaining == 1:
        padded.append(0x81)
    else:
        padded.append(0x01)
        padded.extend(b"\x00" * (remaining - 2))
        padded.append(0x80)
    state = [0] * 25
    for offset in range(0, len(padded), rate):
        block = padded[offset:offset + rate]
        for lane in range(rate // 8):
            state[lane] ^= int.from_bytes(block[8 * lane:8 * lane + 8], "little")
        _keccak_f(state)
    return b"".join(lane.to_bytes(8, "little") for lane in state)[:32]


def keccak256(data: bytes) -> bytes:
    if _native_keccak is not None:
        digest = _native_keccak.new(digest_bits=256)
        digest.update(data)
        return digest.digest()
    return _keccak256_pure(data)

GENESIS_TIMESTAMP = 1_000_000
W_SETTLE_SECONDS = 1_200
T_INCLUDE_MAX_SECONDS = 120
DELTA_FINAL_LAG = 3_600
DELTA_TIP = 1_200
P_PROVE_MAX = 900
F_L1 = 64
T_DEPTH_MAX = 900
CLOCK_SKEW = 24
ESCAPE_OFFSET = 1_900
FORCE_DELAY = 1_500
MAX_FORCE_VALIDITY_SECONDS = 7 * 86_400
FORCE_GAS_BUDGET = 20_000_000
FORCE_BYTES_BUDGET = 1_048_576
MAX_FORCE_MESSAGES = 64
MAX_FORCE_CANDIDATE_MESSAGES = 256
MAX_FORCE_CANDIDATE_BYTES = 4 * 1_048_576
MAX_FORCE_CANDIDATE_GAS = 80_000_000
MAX_FORCE_MESSAGE_GAS = 5_000_000
MAX_FORCE_MESSAGE_BYTES = 131_072
UINT32_MAX = (1 << 32) - 1
MIN_FORCE_ACCOUNTED_GAS = 21_000
MAX_FORCE_RANGE_PROOF_HASHES = 257
FORCE_TREE_DEPTH = 64
MAX_FORCE_QUEUE_ITEMS = (1 << FORCE_TREE_DEPTH) - 1
L2_BLOCK_GAS_LIMIT = 30_000_000
# No protocol system transactions: steady blocks are 20m forced + 5m margin.
FORCE_GAS_MARGIN = 5_000_000
MAX_BLOCKS_PER_CANDIDATE = 4_096
MAX_WINDOWS_PER_CANDIDATE = 12
MAX_DATA_SESSIONS_PER_CANDIDATE = 16
MAX_DATA_RECORDS_PER_CANDIDATE = 2_100
MAX_DATA_RECORDS_PER_SESSION = 2_100
DATA_MMR_FRONTIER_DEPTH = 12
MAX_LIVE_DATA_SESSIONS = 1_024
MAX_DATA_SESSIONS_PER_OWNER = 2
MAX_GC_STEPS = 8
SESSION_MAINTENANCE_NOOP = 0
SESSION_MAINTENANCE_SYNCED = 1
SESSION_MAINTENANCE_SCANNED = 2
MAX_LIVE_WINDOWS = 268
MAX_BUILDERS = 64
ENTRY_DELAY_WINDOWS = 8
MAX_TRANCHE_AHEAD_WINDOWS = 16
EVIDENCE_DELAY_SECONDS = 86_400
MAX_REPLACEMENTS_PER_WINDOW = 4
MAX_LIABILITY_GENERATIONS = MAX_REPLACEMENTS_PER_WINDOW * MAX_LIVE_WINDOWS
MAX_LIVE_RESERVATIONS = 64 * (MAX_TRANCHE_AHEAD_WINDOWS + 1)
DATA_TTL_SECONDS = 86_400
REORG_MARGIN_SECONDS = 1_800
POINT_EVALUATION_PRECOMPILE = "0x000000000000000000000000000000000000000a"
POINT_EVALUATION_GAS = 50_000
FIELD_ELEMENTS_PER_BLOB = 4_096
BLS_MODULUS = (
    52_435_875_175_126_190_479_447_740_508_185_965_837_690_552_500_527_637_822_603_658_699_938_581_184_513
)
POINT_EVALUATION_OK = (
    FIELD_ELEMENTS_PER_BLOB.to_bytes(32, "big")
    + BLS_MODULUS.to_bytes(32, "big")
)
UINT64_MAX = (1 << 64) - 1
# ``ICheckpointStore`` keys checkpoints by ``uint48`` L2 block numbers.
UINT48_MAX = (1 << 48) - 1
L1_RESOURCE_POLICY = "Ethereum Fusaka: EIP-7623 and EIP-7825"
L1_TRANSACTION_GAS_LIMIT = 16_777_216


def checked_l1_gas(value: int) -> int:
    if type(value) is not int or not 0 <= value <= UINT64_MAX:
        raise ValueError("L1 gas arithmetic exceeds uint64")
    return value


def l1_transaction_required_gas(zero_bytes: int, nonzero_bytes: int,
                                execution_gas: int) -> int:
    """Whole non-creation transaction budget, without a refund discount."""

    tokens = checked_l1_gas(checked_l1_gas(zero_bytes)
                            + 4 * checked_l1_gas(nonzero_bytes))
    return max(checked_l1_gas(21_000 + 4 * tokens + checked_l1_gas(execution_gas)),
               checked_l1_gas(21_000 + 10 * tokens))


def l1_gas_with_headroom(required_gas: int) -> int:
    return checked_l1_gas(130 * checked_l1_gas(required_gas) + 99) // 100


def validate_l1_transaction_gas(required_gas: int,
                                supported_block_gas_limit: int) -> None:
    if (checked_l1_gas(supported_block_gas_limit) == 0
            or l1_gas_with_headroom(required_gas) > min(
                supported_block_gas_limit, L1_TRANSACTION_GAS_LIMIT)):
        raise ValueError("L1 transaction cannot preserve 30 percent gas headroom")


def l1_call_sequence_minimum_gas(stipends: tuple[int, ...],
                                retained_reserve: int) -> int:
    """Necessary forwarding bound; unmeasured compiler overhead is excluded."""

    required = checked_l1_gas(retained_reserve)
    for stipend in reversed(stipends):
        if checked_l1_gas(stipend) == 0:
            raise ValueError("L1 call stipend is zero")
        required = checked_l1_gas(
            stipend + max(checked_l1_gas(stipend + 62) // 63, required))
    return required


def validate_settlement_validity_resources_v2(
        maximum_proof_bytes: int, verification_gas: int, reserve_gas: int,
        supported_block_gas_limit: int) -> None:
    if not 0 < maximum_proof_bytes <= SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES:
        raise ValueError("ordinary proof length is unsupported")
    required = settlement_validity_verifier_required_gas_v2(verification_gas, reserve_gas)
    # Only maximum proof bytes are counted. Complete top-level calldata,
    # prefix and suffix remain mandatory compiled-certificate inputs.
    validate_l1_transaction_gas(l1_transaction_required_gas(
        0, maximum_proof_bytes, required), supported_block_gas_limit)


SCHEDULE_WINDOW_SLOTS = 384
SCHEDULE_LOOKAHEAD_SECONDS = 768
MAX_SCHEDULE_CARRIER_SCAN_SLOTS = 64
# A uint64 slot domain contains one final partial 256-slot interval.
LAST_FULL_SLOT_WINDOW = (
    UINT64_MAX - (SCHEDULE_WINDOW_SLOTS - 1)
) // SCHEDULE_WINDOW_SLOTS


def derive_last_managed_schedule_window(
    genesis_timestamp: int,
    evidence_delay_seconds: int,
    reorg_margin_seconds: int,
) -> int:
    """Last window whose full slot and inclusive replay deadline fit uint64."""

    if any(type(value) is not int or not 0 <= value <= UINT64_MAX for value in (
            genesis_timestamp, evidence_delay_seconds,
            reorg_margin_seconds)):
        raise ValueError("schedule terminal inputs are outside uint64")
    fixed = (genesis_timestamp + evidence_delay_seconds
             + reorg_margin_seconds)
    if fixed > UINT64_MAX - 1 - SCHEDULE_WINDOW_SLOTS:
        raise ValueError("schedule has no deadline-safe complete window")
    timestamp_bound = (
        (UINT64_MAX - 1 - fixed) // SCHEDULE_WINDOW_SLOTS
    ) - 1
    return min(LAST_FULL_SLOT_WINDOW, timestamp_bound)


LAST_MANAGED_SCHEDULE_WINDOW = derive_last_managed_schedule_window(
    GENESIS_TIMESTAMP, EVIDENCE_DELAY_SECONDS, REORG_MARGIN_SECONDS
)
SEAT_UINT256_MAX = (1 << 256) - 1
MAX_REWARD_RECEIPTS = 256
REWARD_CLAIM_WINDOW_SECONDS = 86_400
REWARD_RECEIPT_DOMAIN_V1 = b"slot-chain-reward-receipt-v1"
REWARD_CLASS_V1_SELECTOR = bytes.fromhex("3d273ee7")
REWARD_CLASS_V1_MAGIC = b"RCV1"
REWARD_CLASS_READ_GAS = 50_000
REWARD_RECEIPT_V1_SELECTOR = bytes.fromhex("3ed526c7")
REWARD_RECEIPT_V1_MAGIC = b"RRV1"
REWARD_RECEIPT_READ_GAS = 100_000
REWARD_RECEIPT_RETURN_LENGTH = 384
BUILDER_REGISTRY_PROFILE_ADDRESS = "0x" + keccak256(
    b"slot-chain-execution-profile-fixture-v2:builder-registry"
)[-20:].hex()
BUILDER_REGISTRY_PROFILE_RUNTIME_HASH = keccak256(
    b"slot-chain-execution-profile-fixture-v2:builder-registry-runtime"
)
BUILDER_REGISTRY_PROFILE_CONFIGURATION_HASH = keccak256(
    b"slot-chain-execution-profile-fixture-v2:builder-registry-config"
)
if keccak256(b"rewardClassV1(uint8)")[:4] != REWARD_CLASS_V1_SELECTOR:
    raise AssertionError("rewardClassV1 selector drifted")
if keccak256(b"rewardReceiptV1(bytes32)")[:4] \
        != REWARD_RECEIPT_V1_SELECTOR:
    raise AssertionError("rewardReceiptV1 selector drifted")
G_MAX = DELTA_FINAL_LAG


def strict_slot_lag_exceeds(current: int, reference: int, limit: int) -> bool:
    """Compare a uint64 slot lag without subtracting a future reference."""

    if any(
        type(value) is not int or not 0 <= value <= UINT64_MAX
        for value in (current, reference, limit)
    ):
        raise ValueError("slot-lag input is outside uint64")
    return current > reference and current - reference > limit


SEAT_COUNT = 4
DUTY_RING_CAPACITY = SEAT_COUNT
DELTA_RECOVERY_LAG = 1_200
DELTA_SLASH_LAG = 5_164
MIN_PRIMARY_TENURE_SECONDS = 1_000
MIN_STANDBY_TENURE_SECONDS = 600
HANDOVER_DELAY_SECONDS = 5
STAGE_GRACE_SECONDS = 5
EXIT_DELAY_SECONDS = 20
SLA_TAIL_SECONDS = DELTA_SLASH_LAG - DELTA_RECOVERY_LAG
HANDOVER_EXECUTION_BUFFER_SECONDS = (
    HANDOVER_DELAY_SECONDS + STAGE_GRACE_SECONDS + T_INCLUDE_MAX_SECONDS
)
SEAT_RUNWAY_SECONDS = 6_000
MAX_STANDBY_LEASE_SECONDS = SEAT_RUNWAY_SECONDS
MIN_ASK_IMPROVEMENT_WEI_PER_SECOND = 1
MIN_ASK_IMPROVEMENT_BPS = 100
def seat_u256(value: int, name: str) -> int:
    if type(value) is not int or value < 0 or value > SEAT_UINT256_MAX:
        raise ValueError(f"{name} is outside uint256")
    return value


def _seat_bytes32(value: bytes, name: str) -> bytes:
    if type(value) is not bytes or len(value) != 32:
        raise ValueError(f"{name} is not bytes32")
    return value


def _seat_u64_bytes(value: int, name: str) -> bytes:
    if type(value) is not int or not 0 <= value <= UINT64_MAX:
        raise ValueError(f"{name} is outside uint64")
    return value.to_bytes(8, "big")


def seat_duty_id_v1(
    term_id: bytes,
    duty_sequence: int,
    base_canonical_sequence: int,
    base_tip_slot: int,
) -> bytes:
    """Exact legacy-Keccak TAIKO_SEAT_DUTY_V1 identity."""

    return keccak256(b"".join((
        b"TAIKO_SEAT_DUTY_V1",
        _seat_bytes32(term_id, "duty term"),
        _seat_u64_bytes(duty_sequence, "duty sequence"),
        _seat_u64_bytes(base_canonical_sequence, "duty base sequence"),
        _seat_u64_bytes(base_tip_slot, "duty base tip"),
    )))


def seat_selection_id_v1(
    term_id: bytes,
    tranche_id: bytes,
    offer_id: bytes,
    selected_canonical_sequence: int,
    selected_at: int,
    target_tip: int,
    source: "SelectionSource",
    predecessor_duty_id: bytes | None,
) -> bytes:
    """Exact legacy-Keccak TAIKO_SEAT_SELECTION_V1 identity."""

    if type(source) is not SelectionSource:
        raise ValueError("selection source is not canonical")
    predecessor = (
        bytes(32)
        if predecessor_duty_id is None
        else _seat_bytes32(predecessor_duty_id, "selection predecessor")
    )
    return keccak256(b"".join((
        b"TAIKO_SEAT_SELECTION_V1",
        _seat_bytes32(term_id, "selection term"),
        _seat_bytes32(tranche_id, "selection tranche"),
        _seat_bytes32(offer_id, "selection offer"),
        _seat_u64_bytes(
            selected_canonical_sequence, "selection canonical sequence"
        ),
        _seat_u64_bytes(selected_at, "selection time"),
        _seat_u64_bytes(target_tip, "selection target tip"),
        source.value.to_bytes(1, "big"),
        predecessor,
    )))


def seat_checked_add(left: int, right: int, name: str) -> int:
    result = seat_u256(left, f"{name} left") + seat_u256(right, f"{name} right")
    if result > SEAT_UINT256_MAX:
        raise ValueError(f"{name} overflows uint256")
    return result


def checked_u64_add(left: int, right: int, name: str) -> int:
    """Add two exact uint64 words and reject rather than widen on overflow."""

    if (type(left) is not int or type(right) is not int
            or not 0 <= left <= UINT64_MAX
            or not 0 <= right <= UINT64_MAX
            or left > UINT64_MAX - right):
        raise ValueError(f"{name} overflows uint64")
    return left + right


def checked_u256_mul(left: int, right: int, name: str) -> int:
    left = seat_u256(left, f"{name} left")
    right = seat_u256(right, f"{name} right")
    if left and right > SEAT_UINT256_MAX // left:
        raise ValueError(f"{name} overflows uint256")
    return left * right


def ingress_deposit_for_schedule(
    accounted_gas: int,
    byte_length: int,
    fee_schedule: tuple[int, int, int, int, int],
) -> int:
    if (type(fee_schedule) is not tuple or len(fee_schedule) != 5
            or any(type(word) is not int or word < 0
                   or word > SEAT_UINT256_MAX for word in fee_schedule)):
        raise ValueError("ingress fee schedule is not canonical")
    fixed, execution_rate, proof_rate, permanent_rate, cap = fee_schedule
    if any(word <= 0 for word in fee_schedule):
        raise ValueError("ingress fee schedule contains an inactive coefficient")
    gas_rate = seat_checked_add(
        execution_rate, proof_rate, "ingress gas rates",
    )
    required = seat_checked_add(
        seat_checked_add(
            fixed,
            checked_u256_mul(
                accounted_gas, gas_rate, "ingress gas cost"
            ),
            "ingress fixed and gas cost",
        ),
        checked_u256_mul(
            byte_length, permanent_rate, "ingress permanent cost",
        ),
        "ingress total cost",
    )
    if required > cap:
        raise ValueError("ingress fee is outside the release cap")
    return required


def validate_ingress_fee_schedule(
    fee_schedule: tuple[int, int, int, int, int],
) -> tuple[int, int, int, int, int]:
    """Prove the advertised queue geometry is fundable without overflow."""

    ingress_deposit_for_schedule(
        MAX_FORCE_MESSAGE_GAS, MAX_FORCE_MESSAGE_BYTES, fee_schedule
    )
    checked_u256_mul(
        MAX_FORCE_QUEUE_ITEMS,
        fee_schedule[4],
        "maximum forced queue escrow",
    )
    return fee_schedule


def canonical_ingress_deposit(accounted_gas: int, byte_length: int) -> int:
    return ingress_deposit_for_schedule(
        accounted_gas,
        byte_length,
        (
            INGRESS_FIXED_WEI,
            INGRESS_EXECUTION_WEI_PER_GAS,
            INGRESS_PROOF_WEI_PER_GAS,
            INGRESS_PERMANENT_WEI_PER_BYTE,
            INGRESS_MAXIMUM_ACCEPTED_FEE_WEI,
        ),
    )


def seat_checked_sub(left: int, right: int, name: str) -> int:
    left = seat_u256(left, f"{name} left")
    right = seat_u256(right, f"{name} right")
    if right > left:
        raise ValueError(f"{name} underflows uint256")
    return left - right
MAX_ARM_AGE_BLOCKS = 255
EIP2935_HISTORY_ENTRIES = 8_191
SCHEDULE_SEAL_FINALITY_BLOCKS = 64
L1_SLOT_SECONDS = 12
L1_EIP2935_FIRST_SUPPORTED_BLOCK = 1
EIP2935_HISTORY_SERVE_WINDOW = 8_191
EIP2935_HISTORY_READ_GAS = 50_000
MODEL_SETTLEMENT_CHAIN_CONTEXT_ID = 1
INGRESS_FIXED_WEI = 100
INGRESS_EXECUTION_WEI_PER_GAS = 1
INGRESS_PROOF_WEI_PER_GAS = 1
INGRESS_PERMANENT_WEI_PER_BYTE = 10
INGRESS_MAXIMUM_ACCEPTED_FEE_WEI = 12_000_000
COMPONENT_CONFIG_GETTER_SELECTOR = bytes.fromhex("f6c0f7d2")
COMPONENT_CONFIG_GETTER_GAS = 50_000
def maximum_liability_residence_windows_v1(
    evidence_delay_seconds: int, reorg_margin_seconds: int,
) -> int:
    """Return the exact launch-bound residence for one displaced generation."""

    if any(type(value) is not int or not 0 <= value <= UINT64_MAX for value in (
            evidence_delay_seconds, reorg_margin_seconds)):
        raise ValueError("liability residence inputs are outside uint64")
    return (
        MAX_TRANCHE_AHEAD_WINDOWS + 1
        + (evidence_delay_seconds + reorg_margin_seconds + 383) // 384
        + 2
    )


MAX_LIABILITY_RESIDENCE_WINDOWS = maximum_liability_residence_windows_v1(
    EVIDENCE_DELAY_SECONDS, REORG_MARGIN_SECONDS
)
class Mode(Enum):
    NORMAL = auto()
    RECOVERY = auto()


class Cause(IntFlag):
    NONE = 0
    SLA = 1
    FORCE_DUE = 2


class Tier(Enum):
    NORMAL_SIGNED = 1
    RECOVERY_SIGNED = 2
    ESCAPE_UNSIGNED = 3


class ForceKind(Enum):
    """Only kind 0 is assigned; value 1 is unassigned/reserved."""

    USER_TX = 0


@dataclass(frozen=True)
class Clock:
    block_number: int
    timestamp: int

    @property
    def l2_slot(self) -> int:
        return max(0, self.timestamp - GENESIS_TIMESTAMP)


@dataclass(frozen=True)
class L1Header:
    block_hash: str
    timestamp: int
    state_root: str
    force_root: str
    force_cutoff: int


@dataclass(frozen=True, eq=False)
class EIP2935SystemReadTestAdapter:
    """Test adapter for direct reads from the fixed EIP-2935 system contract.

    This is not a deployable or replaceable protocol authority.  ``header``
    composes the byte-exact history hash cell with the model's already decoded
    canonical-header fixture; production additionally checks canonical RLP.
    """

    _headers: object = field(repr=False)
    first_supported_block: int = L1_EIP2935_FIRST_SUPPORTED_BLOCK

    def __post_init__(self) -> None:
        if (
            type(self._headers) is not dict
            or type(self.first_supported_block) is not int
            or not 0 < self.first_supported_block <= UINT64_MAX
            or any(
                type(number) is not int
                or number < 0
                or type(header) is not L1Header
                for number, header in self._headers.items()
            )
        ):
            raise ValueError("EIP-2935 history fixture is invalid")
        object.__setattr__(
            self, "_headers", MappingProxyType(dict(self._headers))
        )

    def __deepcopy__(
        self, memo: dict[int, object]
    ) -> "EIP2935SystemReadTestAdapter":
        return self

    def read_hash(
        self, requested_block: int, current_block: int, calldata: bytes, *,
        gas_limit: int = EIP2935_HISTORY_READ_GAS, value: int = 0,
    ) -> bytes:
        """Model the selector-free, fixed-address EIP-2935 STATICCALL."""

        if (type(requested_block) is not int
                or type(current_block) is not int
                or requested_block < self.first_supported_block
                or not max(0, current_block - EIP2935_HISTORY_SERVE_WINDOW)
                    <= requested_block < current_block
                or calldata != _model_uint(
                    requested_block, 32, "EIP-2935 requested block"
                )
                or gas_limit != EIP2935_HISTORY_READ_GAS
                or value != 0):
            raise ValueError("EIP-2935 system read frame is not exact")
        header = self.header(requested_block)
        try:
            result = bytes.fromhex(header.block_hash.removeprefix("0x"))
        except (ValueError, AttributeError) as exc:
            raise ValueError("EIP-2935 history cell is malformed") from exc
        if len(result) != 32 or result == bytes(32):
            raise ValueError("EIP-2935 history cell is empty")
        return result

    def header(self, block_number: int) -> L1Header:
        if type(block_number) is not int or block_number < 0:
            raise KeyError("invalid L1 header number")
        return self._headers[block_number]

    def fork_for_test(
        self, substitutions: dict[int, L1Header]
    ) -> "EIP2935SystemReadTestAdapter":
        headers = dict(self._headers)
        headers.update(substitutions)
        return EIP2935SystemReadTestAdapter(
            headers, self.first_supported_block
        )


class ForcedTxFork(IntEnum):
    """Fork rules exercised by the abstract forced-transaction decoder."""

    BERLIN = 0
    LONDON = 1
    SHANGHAI = 2
    PRAGUE = 3
    FUSAKA = 4


class ForcedDisposition(IntEnum):
    EXPIRED_NO_TX = 0
    NONCE_NO_TX = 1
    FUNDS_NO_TX = 2
    FEE_NO_TX = 3
    INCLUDED_TX = 4
    # Code 5 is unassigned.
    INVALID_NO_TX = 6


FORCED_TX_TYPES = frozenset({0, 1, 2})
@dataclass(frozen=True)
class ForcedTransactionFacts:
    """Abstract output of canonical raw decoding, not a raw-tx verifier.

    Only chain-protected legacy, access-list and dynamic-fee transactions are
    supported. Blob, authorization-list, system and unknown types reject.
    These facts and Message's existing signature/chain witnesses are NOT added
    to the durable 220-byte descriptor. Production derives them from the raw
    bytes bound by payload_hash and verifies signature recovery independently.
    """

    tx_type: int = 2
    canonical_encoding: bool = True
    chain_protected: bool = True
    destination: bytes | None = bytes.fromhex("11" * 20)
    value: int = 0
    max_priority_fee: int = 0
    data: bytes = b""
    access_list: tuple[tuple[bytes, tuple[bytes, ...]], ...] = ()

    def structurally_valid(self) -> bool:
        return (
            type(self.tx_type) is int
            and type(self.canonical_encoding) is bool
            and type(self.chain_protected) is bool
            and (self.destination is None or
                 type(self.destination) is bytes and len(self.destination) == 20)
            and type(self.value) is int and 0 <= self.value <= SEAT_UINT256_MAX
            and type(self.max_priority_fee) is int
            and 0 <= self.max_priority_fee <= SEAT_UINT256_MAX
            and type(self.data) is bytes
            and type(self.access_list) is tuple
            and all(type(entry) is tuple and len(entry) == 2
                    and type(entry[0]) is bytes and len(entry[0]) == 20
                    and type(entry[1]) is tuple
                    and all(type(key) is bytes and len(key) == 32
                            for key in entry[1]) for entry in self.access_list)
        )


@dataclass(frozen=True)
class ForcedSenderState:
    nonce: int = 0
    balance: int = SEAT_UINT256_MAX
    code: bytes = b""

    def structurally_valid(self) -> bool:
        return (type(self.nonce) is int and 0 <= self.nonce <= UINT64_MAX
                and type(self.balance) is int
                and 0 <= self.balance <= SEAT_UINT256_MAX
                and type(self.code) is bytes)


class ForcedEvmOutcome(Enum):
    SUCCESS = auto()
    REVERT = auto()
    EXCEPTIONAL_HALT = auto()


@dataclass(frozen=True)
class ForcedRawAuthentication:
    """Abstract canonical-signature recovery and chain decoding from raw bytes.

    The external proof authenticates these outputs against payload_hash;
    Python does not verify ECDSA. None represents a proved signature failure,
    not a missing proof. Message's admission-only flags are never consulted.
    """

    recovered_sender: str | None
    chain_id: int

    def structurally_valid(self) -> bool:
        return (
            (self.recovered_sender is None or
             type(self.recovered_sender) is str and bool(self.recovered_sender))
            and type(self.chain_id) is int
            and 0 <= self.chain_id <= SEAT_UINT256_MAX
        )


@dataclass(frozen=True)
class ForcedTxExecutionWitness:
    """Sequential EVM prestate after tx0/tx1 and preceding included txs.

    Authenticating this state and the decoded raw bytes, and executing the
    resulting transaction, belong to the existing external validity proof.
    This model checks classification, not MPT proofs, ECDSA or EVM execution.
    EVM outcomes are deliberately not transaction-invalid error flags.
    """

    queue_index: int
    payload_hash: str
    transaction: ForcedTransactionFacts
    sender: ForcedSenderState = field(default_factory=ForcedSenderState)
    outcome: ForcedEvmOutcome = ForcedEvmOutcome.SUCCESS
    authentication: ForcedRawAuthentication = field(kw_only=True)


def forced_transaction_gas(
    tx: ForcedTransactionFacts, fork: ForcedTxFork,
) -> tuple[int, int]:
    """Ordinary intrinsic and EIP-7623 floor, without counting either twice."""

    if (type(tx) is not ForcedTransactionFacts or not tx.structurally_valid()
            or type(fork) is not ForcedTxFork):
        raise ValueError("forced transaction gas inputs are malformed")
    tokens = sum(1 if value == 0 else 4 for value in tx.data)
    intrinsic = (21_000 + 4 * tokens + 2400 * len(tx.access_list)
                 + 1900 * sum(len(entry[1]) for entry in tx.access_list))
    if tx.destination is None:
        intrinsic += 32_000
        if fork >= ForcedTxFork.SHANGHAI:
            intrinsic += 2 * ((len(tx.data) + 31) // 32)
    floor = 21_000 + 10 * tokens if fork >= ForcedTxFork.PRAGUE else 0
    return intrinsic, floor


def forced_transaction_static_errors(
    row: "Message", tx: ForcedTransactionFacts, fork: ForcedTxFork,
    chain_id: int, authentication: ForcedRawAuthentication | None = None,
) -> tuple[str, ...]:
    """Byte-detectable validity failures under the specified execution fork."""

    if (type(tx) is not ForcedTransactionFacts or not tx.structurally_valid()
            or type(fork) is not ForcedTxFork):
        return ("MALFORMED_TRANSACTION",)
    errors: list[str] = []
    if not tx.canonical_encoding:
        errors.append("NONCANONICAL_ENCODING")
    if (tx.tx_type not in FORCED_TX_TYPES
            or tx.tx_type == 2 and fork < ForcedTxFork.LONDON):
        errors.append("UNSUPPORTED_TYPE")
    if (not tx.chain_protected or row.l2_chain_id != chain_id
            or authentication is not None
                and authentication.chain_id != row.l2_chain_id):
        errors.append("CHAIN_ID")
    if (not row.sender or authentication is not None
            and authentication.recovered_sender != row.sender):
        errors.append("SIGNATURE")
    if type(row.nonce) is not int or not 0 <= row.nonce < UINT64_MAX:
        errors.append("NONCE_LIMIT")
    if (type(row.max_fee) is not int or not 0 <= row.max_fee <= SEAT_UINT256_MAX
            or tx.max_priority_fee > row.max_fee
            or tx.tx_type != 2 and tx.max_priority_fee != 0):
        errors.append("FEE_FIELDS")
    if tx.tx_type == 0 and tx.access_list:
        errors.append("LEGACY_ACCESS_LIST")
    if (tx.destination is None and fork >= ForcedTxFork.SHANGHAI
            and len(tx.data) > 49_152):
        errors.append("INITCODE_SIZE")
    intrinsic, floor = forced_transaction_gas(tx, fork)
    if (type(row.gas_limit) is not int
            or not max(intrinsic, floor) <= row.gas_limit <= UINT64_MAX):
        errors.append("INTRINSIC_OR_FLOOR_GAS")
    if (fork >= ForcedTxFork.FUSAKA and type(row.gas_limit) is int
            and row.gas_limit > 16_777_216):
        errors.append("TRANSACTION_GAS_CAP")
    if (type(row.gas_limit) is int and type(row.max_fee) is int
            and row.gas_limit * row.max_fee + tx.value > SEAT_UINT256_MAX):
        errors.append("UPFRONT_COST_OVERFLOW")
    return tuple(errors)


def classify_forced_transaction(
    row: "Message", *, timestamp: int, fork: ForcedTxFork,
    chain_id: int, base_fee: int, witness: ForcedTxExecutionWitness | None,
    raw_available: bool,
) -> ForcedDisposition:
    """Total classification for admitted rows and authenticated reachable state.

    Missing/malformed proof inputs reject the candidate; they are never a
    discard reason. Expiry requires no raw bytes or state witness. No-tx reasons
    have exact precedence 0,1,2,3,6; ordinary EVM failure still includes tx4.
    """

    if (type(row) is not Message or row.kind is not ForceKind.USER_TX
            or type(timestamp) is not int or not 0 <= timestamp <= UINT64_MAX
            or type(fork) is not ForcedTxFork or type(chain_id) is not int
            or not 0 < chain_id <= UINT64_MAX or type(base_fee) is not int
            or not 0 <= base_fee <= SEAT_UINT256_MAX):
        raise ValueError("forced transaction context is malformed")
    if row.valid_until < timestamp:
        return ForcedDisposition.EXPIRED_NO_TX
    if (not raw_available or type(witness) is not ForcedTxExecutionWitness
            or witness.payload_hash != row.payload_hash
            or type(witness.transaction) is not ForcedTransactionFacts
            or not witness.transaction.structurally_valid()
            or type(witness.authentication) is not ForcedRawAuthentication
            or not witness.authentication.structurally_valid()
            or type(witness.sender) is not ForcedSenderState
            or not witness.sender.structurally_valid()
            or type(witness.outcome) is not ForcedEvmOutcome):
        raise ValueError("unexpired forced transaction needs raw and state witnesses")
    tx, sender = witness.transaction, witness.sender
    if row.nonce != sender.nonce:
        return ForcedDisposition.NONCE_NO_TX
    if sender.balance < row.gas_limit * row.max_fee + tx.value:
        return ForcedDisposition.FUNDS_NO_TX
    if row.max_fee < base_fee:
        return ForcedDisposition.FEE_NO_TX
    delegated = len(sender.code) == 23 and sender.code[:3] == b"\xef\x01\x00"
    if (forced_transaction_static_errors(
            row, tx, fork, chain_id, witness.authentication)
            or sender.code and not (fork >= ForcedTxFork.PRAGUE and delegated)):
        return ForcedDisposition.INVALID_NO_TX
    return ForcedDisposition.INCLUDED_TX


@dataclass(frozen=True)
class Message:
    enqueued_at: int
    accounted_gas: int
    byte_length: int
    payload_hash: str
    kind: ForceKind = ForceKind.USER_TX
    sender: str = "sender"
    nonce: int = 0
    chain_id_ok: bool = True
    signature_ok: bool = True
    outer_authorized: bool = True
    intrinsic_gas: int = 21_000
    valid_until: int = UINT64_MAX
    due_at: int = 0
    prepaid: int = 1
    payload_available: bool = True
    raw_tx_length: int = 0
    l2_chain_id: int = 0
    gas_limit: int = 0
    max_fee: int = 0
    refund_address: str = ""
    # Abstract admission decoder output; deliberately absent from durable hash.
    transaction: ForcedTransactionFacts = field(default_factory=ForcedTransactionFacts)


def _model_fixed_bytes32(value: object, *, zero_if_empty: bool = False) -> bytes:
    """Map an abstract model identity to one deterministic ABI bytes32 word."""

    if zero_if_empty and value in {"", b""}:
        return bytes(32)
    if type(value) is bytes and len(value) == 32:
        return value
    if type(value) is str and len(value.removeprefix("0x")) == 64:
        try:
            return bytes.fromhex(value.removeprefix("0x"))
        except ValueError:
            pass
    return hashlib.sha256(
        b"TAIKO_MODEL_FIXED_BYTES32_V1\x00" + repr(value).encode()
    ).digest()


def _model_address20(value: object, *, zero_if_empty: bool = False) -> bytes:
    """Map an abstract model account to one deterministic packed address."""

    if zero_if_empty and value in {"", b""}:
        return bytes(20)
    if type(value) is str and len(value.removeprefix("0x")) == 40:
        try:
            return bytes.fromhex(value.removeprefix("0x"))
        except ValueError:
            pass
    return hashlib.sha256(
        b"TAIKO_MODEL_ADDRESS20_V1\x00" + repr(value).encode()
    ).digest()[-20:]


def _model_uint(value: int, width: int, name: str) -> bytes:
    if (type(value) is not int or width <= 0
            or not 0 <= value < 1 << (width * 8)):
        raise ValueError(f"{name} is outside uint{width * 8}")
    return value.to_bytes(width, "big")


def durable_queue_leaf_fields(row: Message) -> tuple[object, ...]:
    """Return only the normative durable fields, never admission witnesses."""

    if type(row) is Message and row.kind is ForceKind.USER_TX:
        return (
                row.kind.value,
                row.enqueued_at,
                row.due_at,
                row.accounted_gas,
                row.byte_length,
                row.payload_hash,
                row.sender,
                row.nonce,
                row.valid_until,
                row.prepaid,
                row.l2_chain_id,
                row.gas_limit,
                row.max_fee,
                row.refund_address,
            )
    raise ValueError("forced queue descriptor type is not canonical")


def durable_queue_leaf_hash(row: Message, index: int = 0) -> str:
    if type(index) is not int or not 0 <= index <= UINT64_MAX:
        raise ValueError("forced queue leaf index is outside uint64")
    if type(row) is Message and row.kind is ForceKind.USER_TX:
        descriptor = b"".join((
            _model_address20(row.sender),
            _model_uint(row.nonce, 8, "forced nonce"),
            _model_uint(row.l2_chain_id, 32, "forced L2 chain id"),
            _model_fixed_bytes32(row.payload_hash),
            _model_uint(row.byte_length, 4, "forced byte length"),
            _model_uint(row.gas_limit, 8, "forced gas limit"),
            _model_uint(row.accounted_gas, 8, "forced accounted gas"),
            _model_uint(row.max_fee, 32, "forced maximum fee"),
            _model_uint(row.valid_until, 8, "forced validity"),
            _model_address20(row.refund_address),
            _model_uint(row.enqueued_at, 8, "forced enqueue time"),
            _model_uint(row.due_at, 8, "forced due time"),
            _model_uint(row.prepaid, 32, "forced deposit"),
        ))
        if len(descriptor) != 220:
            raise AssertionError("kind-0 descriptor width drifted")
        domain = b"slot-chain-force-user-v2"
    else:
        raise ValueError("forced queue descriptor type is not canonical")
    return keccak256(
        domain + _model_uint(index, 8, "forced queue leaf index") + descriptor
    ).hex()


def _force_hash(namespace: bytes, *parts: bytes) -> bytes:
    """Domain-separated hash primitive for the fixed-depth forced vector."""

    if (type(namespace) is not bytes
            or any(type(part) is not bytes for part in parts)):
        raise ValueError("forced vector hash preimage is not canonical")
    return keccak256(namespace + b"".join(parts))


def force_zero_hashes() -> tuple[bytes, ...]:
    """Canonical empty subtrees for heights zero through 64."""

    rows = [_force_hash(b"slot-chain-force-empty-v2")]
    for height in range(FORCE_TREE_DEPTH):
        rows.append(_force_hash(
            b"slot-chain-force-node-v2",
            height.to_bytes(1, "big"), rows[-1], rows[-1],
        ))
    return tuple(rows)


FORCE_ZERO_HASHES = force_zero_hashes()


def _frontier_tree_root(
    *,
    frontier: list[bytes],
    count: int,
    zero_hashes: tuple[bytes, ...],
    node_domain: bytes,
) -> bytes:
    """Fold one exact depth-64 append frontier without reading old leaves."""

    if (type(frontier) is not list or len(frontier) != FORCE_TREE_DEPTH
            or any(type(row) is not bytes or len(row) != 32
                   for row in frontier)
            or type(count) is not int or not 0 <= count <= UINT64_MAX
            or len(zero_hashes) != FORCE_TREE_DEPTH + 1):
        raise ValueError("fixed-depth frontier state is malformed")
    node = zero_hashes[0]
    for height in range(FORCE_TREE_DEPTH):
        node = keccak256(b"".join((
            node_domain,
            height.to_bytes(1, "big"),
            frontier[height] if (count >> height) & 1 else node,
            node if (count >> height) & 1 else zero_hashes[height],
        )))
    return node


def _append_frontier_leaf(
    frontier: list[bytes],
    count: int,
    leaf: bytes,
    *,
    node_domain: bytes,
) -> list[bytes]:
    """Return the post-append 64-word frontier using trailing-one carry."""

    if (type(frontier) is not list or len(frontier) != FORCE_TREE_DEPTH
            or any(type(row) is not bytes or len(row) != 32
                   for row in frontier)
            or type(count) is not int or not 0 <= count < UINT64_MAX
            or type(leaf) is not bytes or len(leaf) != 32):
        raise ValueError("fixed-depth frontier append is malformed")
    updated = list(frontier)
    carry = leaf
    height = 0
    cursor = count
    while cursor & 1:
        carry = keccak256(b"".join((
            node_domain,
            height.to_bytes(1, "big"),
            updated[height],
            carry,
        )))
        cursor >>= 1
        height += 1
    updated[height] = carry
    return updated


def force_wrapped_root(frontier: list[bytes], count: int) -> str:
    tree_root = _frontier_tree_root(
        frontier=frontier,
        count=count,
        zero_hashes=FORCE_ZERO_HASHES,
        node_domain=b"slot-chain-force-node-v2",
    )
    return _force_hash(
        b"slot-chain-force-root-v2",
        _model_uint(count, 8, "forced queue count"),
        tree_root,
    ).hex()


def force_frontier_from_descriptors(
    descriptors: tuple[Message, ...] | list[Message],
) -> list[bytes]:
    """Off-chain independent oracle; production append never calls this."""

    if type(descriptors) not in {tuple, list} or len(descriptors) > UINT64_MAX:
        raise ValueError("forced descriptor oracle is malformed")
    frontier = [bytes(32) for _ in range(FORCE_TREE_DEPTH)]
    for index, row in enumerate(descriptors):
        frontier = _append_frontier_leaf(
            frontier,
            index,
            bytes.fromhex(durable_queue_leaf_hash(row, index)),
            node_domain=b"slot-chain-force-node-v2",
        )
    return frontier


def model_force_root(descriptors: list[Message]) -> str:
    """Off-chain full-history oracle for frontier/full-tree equivalence."""

    if type(descriptors) is not list or len(descriptors) > UINT64_MAX:
        raise ValueError("forced descriptor oracle is malformed")
    nodes = {
        index: bytes.fromhex(durable_queue_leaf_hash(row, index))
        for index, row in enumerate(descriptors)
    }
    for height in range(FORCE_TREE_DEPTH):
        parents: dict[int, bytes] = {}
        for parent in {index >> 1 for index in nodes}:
            left = nodes.get(parent << 1, FORCE_ZERO_HASHES[height])
            right = nodes.get((parent << 1) | 1,
                              FORCE_ZERO_HASHES[height])
            parents[parent] = _force_hash(
                b"slot-chain-force-node-v2",
                height.to_bytes(1, "big"), left, right,
            )
        nodes = parents
    tree_root = nodes.get(0, FORCE_ZERO_HASHES[FORCE_TREE_DEPTH])
    return _force_hash(
        b"slot-chain-force-root-v2",
        _model_uint(len(descriptors), 8, "forced queue count"),
        tree_root,
    ).hex()


def data_session_id(
    settlement_chain_id: int,
    settlement_address: str,
    owner: str,
    session_sequence: int,
) -> str:
    """Derive the protocol session ID; no caller-selected alias is accepted."""

    if (type(settlement_chain_id) is not int
            or not 0 < settlement_chain_id <= SEAT_UINT256_MAX
            or not settlement_address or not owner
            or type(session_sequence) is not int
            or not 0 <= session_sequence < UINT64_MAX):
        raise ValueError("data session identity tuple is malformed")
    return keccak256(b"".join((
        b"slot-chain-session-v1",
        _model_uint(settlement_chain_id, 32, "settlement chain id"),
        _model_address20(settlement_address),
        _model_address20(owner),
        _model_uint(session_sequence, 8, "data-session sequence"),
    ))).hex()


def data_mmr_root(frontier: list[bytes], count: int) -> str:
    """Bag fixed peaks rightmost-first (ascending height)."""

    if (type(frontier) is not list
            or len(frontier) != DATA_MMR_FRONTIER_DEPTH
            or any(type(row) is not bytes or len(row) != 32
                   for row in frontier)
            or type(count) is not int
            or not 0 <= count <= MAX_DATA_RECORDS_PER_SESSION):
        raise ValueError("data MMR frontier is malformed")
    # Frontier peaks are stored left-to-right in decreasing height. Bagging is
    # rightmost-to-leftmost, hence ascending height here.
    heights = [height for height in range(DATA_MMR_FRONTIER_DEPTH)
               if (count >> height) & 1]
    return data_mmr_bagged_root({
        height: frontier[height] for height in heights
    }, count)


def data_mmr_bagged_root(peaks: dict[int, bytes], count: int) -> str:
    """Hash the exact rightmost-first peak set for one public count."""

    expected_heights = [
        height for height in range(DATA_MMR_FRONTIER_DEPTH)
        if (count >> height) & 1
    ]
    if (type(peaks) is not dict
            or type(count) is not int
            or not 0 <= count <= MAX_DATA_RECORDS_PER_SESSION
            or sorted(peaks) != expected_heights
            or any(type(peak) is not bytes or len(peak) != 32
                   for peak in peaks.values())):
        raise ValueError("data MMR peak set does not bind count")
    return keccak256(b"".join((
        b"slot-chain-data-bag-v1",
        _model_uint(count, 2, "data MMR count"),
        _model_uint(len(expected_heights), 1, "data MMR peak count"),
        *(height.to_bytes(1, "big") + peaks[height]
          for height in expected_heights),
    ))).hex()


def append_data_mmr(
    frontier: list[bytes], count: int, canonical_leaf: bytes,
) -> tuple[list[bytes], int, str]:
    """Append one already byte-exact Appendix leaf through 12 words."""

    if (type(frontier) is not list
            or len(frontier) != DATA_MMR_FRONTIER_DEPTH
            or any(type(row) is not bytes or len(row) != 32
                   for row in frontier)
            or type(count) is not int
            or not 0 <= count < MAX_DATA_RECORDS_PER_SESSION
            or type(canonical_leaf) is not bytes
            or len(canonical_leaf) != 32):
        raise ValueError("data MMR append is malformed")
    carry = canonical_leaf
    updated = list(frontier)
    cursor = count
    height = 0
    while cursor & 1:
        carry = keccak256(b"".join((
            b"slot-chain-data-node-v1",
            height.to_bytes(1, "big"),
            updated[height],
            carry,
        )))
        cursor >>= 1
        height += 1
    if height >= DATA_MMR_FRONTIER_DEPTH:
        raise ValueError("data MMR frontier capacity is exhausted")
    updated[height] = carry
    next_count = count + 1
    return updated, next_count, data_mmr_root(updated, next_count)


def model_data_mmr_root(
    canonical_leaves: tuple[bytes, ...] | list[bytes],
) -> str:
    """Independent full-leaf oracle; it never invokes frontier append."""

    if (type(canonical_leaves) not in {tuple, list}
            or len(canonical_leaves) > MAX_DATA_RECORDS_PER_SESSION
            or any(type(leaf) is not bytes or len(leaf) != 32
                   for leaf in canonical_leaves)):
        raise ValueError("data record oracle is malformed")
    leaves = list(canonical_leaves)
    peaks: dict[int, bytes] = {}
    offset = 0
    for height in reversed(range(DATA_MMR_FRONTIER_DEPTH)):
        if not (len(leaves) >> height) & 1:
            continue
        width = 1 << height
        nodes = leaves[offset:offset + width]
        for child_height in range(height):
            nodes = [keccak256(b"".join((
                b"slot-chain-data-node-v1",
                child_height.to_bytes(1, "big"),
                nodes[index],
                nodes[index + 1],
            ))) for index in range(0, len(nodes), 2)]
        if len(nodes) != 1:
            raise AssertionError("independent data MMR peak did not collapse")
        peaks[height] = nodes[0]
        offset += width
    if offset != len(leaves):
        raise AssertionError("independent data MMR did not cover all leaves")
    return data_mmr_bagged_root(peaks, len(leaves))


@dataclass(frozen=True)
class DataMmrProof:
    count: int
    index: int
    siblings: tuple[str, ...]
    other_peaks: tuple[tuple[int, str], ...]


def _data_mmr_mountains(count: int) -> tuple[tuple[int, int, int], ...]:
    """Return left-to-right (start,end,height) mountains derived from count."""

    if (type(count) is not int
            or not 0 <= count <= MAX_DATA_RECORDS_PER_SESSION):
        raise ValueError("data MMR count is outside the session bound")
    offset = 0
    rows: list[tuple[int, int, int]] = []
    for height in reversed(range(DATA_MMR_FRONTIER_DEPTH)):
        if (count >> height) & 1:
            end = offset + (1 << height)
            rows.append((offset, end, height))
            offset = end
    if offset != count:
        raise AssertionError("data MMR mountain geometry drifted")
    return tuple(rows)


def verify_data_mmr_proof(
    canonical_leaf: bytes, proof: DataMmrProof, expected_root: str,
) -> bool:
    """Verify an exact proof with count-derived mountain and directions."""

    if (type(proof) is not DataMmrProof
            or type(canonical_leaf) is not bytes or len(canonical_leaf) != 32
            or type(expected_root) is not str or len(expected_root) != 64
            or not 0 <= proof.index < proof.count
            or proof.count > MAX_DATA_RECORDS_PER_SESSION):
        return False
    target = next((row for row in _data_mmr_mountains(proof.count)
                   if row[0] <= proof.index < row[1]), None)
    if target is None:
        return False
    start, _, target_height = target
    expected_other_heights = tuple(
        height for height in range(DATA_MMR_FRONTIER_DEPTH)
        if (proof.count >> height) & 1 and height != target_height
    )
    if (type(proof.siblings) is not tuple
            or len(proof.siblings) != target_height
            or type(proof.other_peaks) is not tuple
            or tuple(row[0] for row in proof.other_peaks)
                != expected_other_heights
            or any(type(row) is not tuple or len(row) != 2
                   or type(row[0]) is not int
                   or type(row[1]) is not str or len(row[1]) != 64
                   for row in proof.other_peaks)):
        return False
    try:
        node = canonical_leaf
        sibling_bytes = tuple(bytes.fromhex(row) for row in proof.siblings)
        peaks = {height: bytes.fromhex(peak)
                 for height, peak in proof.other_peaks}
    except ValueError:
        return False
    local_index = proof.index - start
    for child_height, sibling in enumerate(sibling_bytes):
        left, right = (
            (node, sibling) if ((local_index >> child_height) & 1) == 0
            else (sibling, node)
        )
        node = keccak256(b"".join((
            b"slot-chain-data-node-v1",
            child_height.to_bytes(1, "big"),
            left,
            right,
        )))
    peaks[target_height] = node
    try:
        return data_mmr_bagged_root(peaks, proof.count) == expected_root
    except ValueError:
        return False


def model_data_mmr_proof(
    canonical_leaves: tuple[bytes, ...] | list[bytes],
    index: int,
) -> tuple[bytes, DataMmrProof]:
    """Off-chain proof oracle independent of the canonical frontier."""

    if (type(canonical_leaves) not in {tuple, list}
            or not 0 <= index < len(canonical_leaves)
            or len(canonical_leaves) > MAX_DATA_RECORDS_PER_SESSION
            or any(type(leaf) is not bytes or len(leaf) != 32
                   for leaf in canonical_leaves)):
        raise ValueError("data MMR proof request is malformed")
    leaves = list(canonical_leaves)
    peaks: dict[int, bytes] = {}
    target_siblings: tuple[str, ...] | None = None
    target_height: int | None = None
    for start, end, height in _data_mmr_mountains(len(leaves)):
        nodes = leaves[start:end]
        cursor = index - start if start <= index < end else None
        siblings: list[str] = []
        for child_height in range(height):
            if cursor is not None:
                siblings.append(nodes[cursor ^ 1].hex())
                cursor >>= 1
            nodes = [keccak256(b"".join((
                b"slot-chain-data-node-v1",
                child_height.to_bytes(1, "big"),
                nodes[offset],
                nodes[offset + 1],
            ))) for offset in range(0, len(nodes), 2)]
        peaks[height] = nodes[0]
        if start <= index < end:
            target_siblings = tuple(siblings)
            target_height = height
    if target_siblings is None or target_height is None:
        raise AssertionError("data MMR proof target mountain is missing")
    proof = DataMmrProof(
        len(leaves),
        index,
        target_siblings,
        tuple((height, peaks[height].hex())
              for height in sorted(peaks) if height != target_height),
    )
    return leaves[index], proof


@dataclass(frozen=True)
class DataRecord:
    session_id: str
    index: int
    versioned_hash: bytes
    canonical_leaf: bytes
    chunk_byte_length: int = 0


@dataclass(frozen=True)
class SessionOpenedEvent:
    session_id: str
    owner: str
    cell: int
    sequence: int
    expiry: int
    bond_wei: int
    base_rent_wei: int


@dataclass(frozen=True)
class SessionSealedEvent:
    session_id: str
    count: int
    root: str
    expiry: int


@dataclass(frozen=True)
class SessionLiveToRefundEvent:
    session_id: str
    owner: str
    cell: int
    claim_deadline: int


@dataclass(frozen=True)
class SessionBondClaimedEvent:
    session_id: str
    owner: str
    recipient: str
    amount: int


@dataclass(frozen=True)
class SessionRefundForfeitedEvent:
    session_id: str
    owner: str
    cell: int
    amount: int


@dataclass(frozen=True)
class SessionSurplusSweptEvent:
    sink: str
    amount: int


@dataclass(frozen=True)
class DataSessionsMaintainedEvent:
    mode: int
    start_cursor: int
    next_cursor: int
    inspected: int
    changed: int


@dataclass(frozen=True)
class DataPost:
    """Caller-supplied static tuple; consensus fields are derived internally."""

    full_body_root: bytes
    block_ordinal: int
    chunk_index: int
    chunk_count: int
    chunk_byte_length: int
    chunk_root: bytes
    y: int
    commitment_hi: bytes
    commitment_lo: bytes
    proof_hi: bytes
    proof_lo: bytes

    def structurally_valid(self) -> bool:
        return (type(self.full_body_root) is bytes
                and len(self.full_body_root) == 32
                and type(self.block_ordinal) is int
                and 0 <= self.block_ordinal <= 65_535
                and type(self.chunk_index) is int
                and type(self.chunk_count) is int
                and 0 <= self.chunk_index < self.chunk_count <= 9
                and type(self.chunk_byte_length) is int
                and 0 <= self.chunk_byte_length <= 126_972
                and type(self.chunk_root) is bytes
                and len(self.chunk_root) == 32
                and type(self.y) is int and 0 <= self.y < BLS_MODULUS
                and type(self.commitment_hi) is bytes
                and len(self.commitment_hi) == 32
                and type(self.commitment_lo) is bytes
                and len(self.commitment_lo) == 16
                and type(self.proof_hi) is bytes
                and len(self.proof_hi) == 32
                and type(self.proof_lo) is bytes
                and len(self.proof_lo) == 16)

    @property
    def commitment(self) -> bytes:
        if not self.structurally_valid():
            raise ValueError("data POST tuple is malformed")
        return self.commitment_hi + self.commitment_lo

    @property
    def proof(self) -> bytes:
        if not self.structurally_valid():
            raise ValueError("data POST tuple is malformed")
        return self.proof_hi + self.proof_lo


@dataclass(frozen=True)
class PointEvaluationAdapter:
    """Exact STATICCALL environment model for EIP-4844 address 0x0A."""

    address: str = POINT_EVALUATION_PRECOMPILE
    gas: int = POINT_EVALUATION_GAS
    success: bool = True
    return_data: bytes = POINT_EVALUATION_OK

    def structurally_valid(self) -> bool:
        return (self.address == POINT_EVALUATION_PRECOMPILE
                and self.gas == POINT_EVALUATION_GAS
                and type(self.success) is bool
                and type(self.return_data) is bytes)

    def staticcall(
        self, *, address: str, gas: int, input_data: bytes
    ) -> tuple[bool, bytes]:
        if (not self.structurally_valid()
                or address != POINT_EVALUATION_PRECOMPILE
                or gas != POINT_EVALUATION_GAS
                or type(input_data) is not bytes
                or len(input_data) != 192
                or input_data[:32]
                    != kzg_commitment_to_versioned_hash(input_data[96:144])):
            return False, b""
        return self.success, self.return_data


def kzg_commitment_to_versioned_hash(commitment: bytes) -> bytes:
    """Return the exact EIP-4844 KZG versioned hash for one commitment."""

    if type(commitment) is not bytes or len(commitment) != 48:
        raise ValueError("KZG commitment must be exactly 48 bytes")
    digest = hashlib.sha256(commitment).digest()
    return b"\x01" + digest[1:]


def data_post_for_test(
    *,
    chunk_byte_length: int = 1,
    salt: bytes = b"blob",
    block_ordinal: int = 0,
    chunk_index: int = 0,
    chunk_count: int = 1,
    y: int = 0,
) -> DataPost:
    """Build one structurally exact tuple for behavioral model fixtures."""

    if type(salt) is not bytes or not salt:
        raise ValueError("data POST fixture salt is malformed")
    commitment = keccak256(b"commitment:" + salt) + keccak256(
        b"commitment-tail:" + salt
    )[:16]
    proof = keccak256(b"proof:" + salt) + keccak256(
        b"proof-tail:" + salt
    )[:16]
    return DataPost(
        keccak256(b"body:" + salt),
        block_ordinal,
        chunk_index,
        chunk_count,
        chunk_byte_length,
        keccak256(b"chunk:" + salt),
        y,
        commitment[:32],
        commitment[32:],
        proof[:32],
        proof[32:],
    )


@dataclass
class DataSession:
    session_id: str
    owner: str
    expiry: int
    refundable_bond: int = 0
    cell_index: int = -1
    sequence: int = 0
    count: int = 0
    frontier: list[bytes] = field(
        default_factory=lambda: [bytes(32)
                                 for _ in range(DATA_MMR_FRONTIER_DEPTH)]
    )
    root: str = ""
    sealed: bool = False

    def __post_init__(self) -> None:
        if (not self.session_id or not self.owner
                or type(self.expiry) is not int
                or type(self.refundable_bond) is not int
                or not 0 <= self.refundable_bond <= SEAT_UINT256_MAX
                or type(self.cell_index) is not int
                or not -1 <= self.cell_index < MAX_LIVE_DATA_SESSIONS
                or type(self.sequence) is not int
                or not 0 <= self.sequence < UINT64_MAX
                or type(self.count) is not int
                or not 0 <= self.count <= MAX_DATA_RECORDS_PER_SESSION
                or type(self.frontier) is not list
                or len(self.frontier) != DATA_MMR_FRONTIER_DEPTH
                or any(type(row) is not bytes or len(row) != 32
                       for row in self.frontier)):
            raise ValueError("data session state is malformed")
        expected = data_mmr_root(self.frontier, self.count)
        if self.root not in {"", expected}:
            raise ValueError("data session root does not match its frontier")
        self.root = expected


class DataSessionCellTag(Enum):
    FREE = 0
    LIVE = 1
    REFUND = 2


class DataSessionMaintenanceMode(Enum):
    ORDINARY = 1


class DataSessionRevert(RuntimeError):
    """Exact transaction-revert signal for session custody selectors."""


class SharedSettlementReentrancy(RuntimeError):
    """A nested mutating Settlement selector hit the shared call guard."""


class RewardClaimRevert(RuntimeError):
    """Exact transaction-revert signal for reward claims."""


class RewardFundingRevert(RuntimeError):
    """Exact transaction-revert signal for reward-class funding."""


@dataclass
class DataSessionCell:
    tag: DataSessionCellTag = DataSessionCellTag.FREE
    session: DataSession | None = None
    refund_claim_deadline: int = 0

    def structurally_valid(self, index: int) -> bool:
        if (type(index) is not int
                or not 0 <= index < MAX_LIVE_DATA_SESSIONS
                or type(self.tag) is not DataSessionCellTag
                or type(self.refund_claim_deadline) is not int
                or not 0 <= self.refund_claim_deadline <= UINT64_MAX):
            return False
        if self.tag is DataSessionCellTag.FREE:
            return (self.refund_claim_deadline == 0
                    and (self.session is None
                         or type(self.session) is DataSession
                         and self.session.cell_index == index))
        if (type(self.session) is not DataSession
                or self.session.cell_index != index):
            return False
        if self.tag is DataSessionCellTag.LIVE:
            return self.refund_claim_deadline == 0
        return self.refund_claim_deadline > 0


@dataclass(frozen=True)
class DataSessionCellView:
    tag: int = 0
    session_id: str = ""
    owner: str = ""
    refundable_bond: int = 0
    refund_claim_deadline: int = 0
    sequence: int = 0
    expiry: int = 0
    count: int = 0
    sealed: bool = False
    root: str = ""
    frontier: tuple[bytes, ...] = field(
        default_factory=lambda: tuple(
            bytes(32) for _ in range(DATA_MMR_FRONTIER_DEPTH)
        )
    )


@dataclass(frozen=True)
class DataSessionCellAbiV1:
    tag: int = 0
    session_id: bytes = bytes(32)
    owner: bytes = bytes(20)
    sequence: int = 0
    expiry: int = 0
    count: int = 0
    sealed: bool = False
    root: bytes = bytes(32)
    peaks: tuple[bytes, ...] = field(
        default_factory=lambda: tuple(
            bytes(32) for _ in range(DATA_MMR_FRONTIER_DEPTH)
        )
    )
    bond_wei: int = 0
    claim_deadline: int = 0


@dataclass(frozen=True)
class DataSessionByIdAbiV1:
    cell_plus_one: int = 0
    tag: int = 0
    owner: bytes = bytes(20)
    sequence: int = 0
    expiry: int = 0
    count: int = 0
    sealed: bool = False
    root: bytes = bytes(32)
    bond_wei: int = 0
    claim_deadline: int = 0


def _abi_bool_word(value: bool) -> bytes:
    if type(value) is not bool:
        raise ValueError("ABI Boolean is malformed")
    return bytes(31) + bytes((int(value),))


def _validate_data_session_cell_abi(row: DataSessionCellAbiV1) -> None:
    if (type(row) is not DataSessionCellAbiV1
            or row.tag not in (0, 1, 2)
            or type(row.session_id) is not bytes or len(row.session_id) != 32
            or type(row.owner) is not bytes or len(row.owner) != 20
            or type(row.root) is not bytes or len(row.root) != 32
            or type(row.peaks) is not tuple
            or len(row.peaks) != DATA_MMR_FRONTIER_DEPTH
            or any(type(peak) is not bytes or len(peak) != 32
                   for peak in row.peaks)
            or type(row.sealed) is not bool):
        raise ValueError("data-session cell view is malformed")
    _model_uint(row.sequence, 8, "session sequence")
    _model_uint(row.expiry, 8, "session expiry")
    _model_uint(row.count, 2, "record count")
    _model_uint(row.bond_wei, 32, "session bond")
    _model_uint(row.claim_deadline, 8, "claim deadline")
    zero_peaks = tuple(bytes(32) for _ in range(DATA_MMR_FRONTIER_DEPTH))
    if row.tag == 0 and row != DataSessionCellAbiV1():
        raise ValueError("FREE session cell is not canonically masked")
    if (row.tag == 1
            and (row.session_id == bytes(32) or row.owner == bytes(20)
                 or row.claim_deadline != 0)):
        raise ValueError("LIVE session cell is malformed")
    if (row.tag == 2
            and (row.session_id == bytes(32) or row.owner == bytes(20)
                 or row.bond_wei == 0 or row.claim_deadline == 0
                 or row.sequence != 0 or row.expiry != 0 or row.count != 0
                 or row.sealed or row.root != bytes(32)
                 or row.peaks != zero_peaks)):
        raise ValueError("REFUND session cell is not canonically masked")


def encode_data_session_cell_v1(row: DataSessionCellAbiV1) -> bytes:
    _validate_data_session_cell_abi(row)
    return b"".join((
        bytes(31) + bytes((row.tag,)),
        row.session_id,
        bytes(12) + row.owner,
        bytes(24) + _model_uint(row.sequence, 8, "session sequence"),
        bytes(24) + _model_uint(row.expiry, 8, "session expiry"),
        bytes(30) + _model_uint(row.count, 2, "record count"),
        _abi_bool_word(row.sealed),
        row.root,
        *row.peaks,
        _model_uint(row.bond_wei, 32, "session bond"),
        bytes(24) + _model_uint(row.claim_deadline, 8, "claim deadline"),
    ))


def decode_data_session_cell_v1(raw: bytes) -> DataSessionCellAbiV1:
    if type(raw) is not bytes or len(raw) != 704:
        raise ValueError("data-session cell returndata length is invalid")
    words = tuple(raw[offset:offset + 32] for offset in range(0, 704, 32))
    if (words[0][:31] != bytes(31) or words[0][-1] not in (0, 1, 2)
            or words[2][:12] != bytes(12)
            or words[3][:24] != bytes(24)
            or words[4][:24] != bytes(24)
            or words[5][:30] != bytes(30)
            or words[6][:31] != bytes(31) or words[6][-1] not in (0, 1)
            or words[21][:24] != bytes(24)):
        raise ValueError("data-session cell returndata is noncanonical")
    row = DataSessionCellAbiV1(
        words[0][-1], words[1], words[2][12:],
        int.from_bytes(words[3][24:], "big"),
        int.from_bytes(words[4][24:], "big"),
        int.from_bytes(words[5][30:], "big"), bool(words[6][-1]), words[7],
        tuple(words[8:20]), int.from_bytes(words[20], "big"),
        int.from_bytes(words[21][24:], "big"),
    )
    _validate_data_session_cell_abi(row)
    return row


def encode_data_session_by_id_v1(row: DataSessionByIdAbiV1) -> bytes:
    if (type(row) is not DataSessionByIdAbiV1
            or not 0 <= row.cell_plus_one <= MAX_LIVE_DATA_SESSIONS
            or row.tag not in (0, 1, 2)
            or type(row.owner) is not bytes or len(row.owner) != 20
            or type(row.sealed) is not bool
            or type(row.root) is not bytes or len(row.root) != 32):
        raise ValueError("data-session by-ID view is malformed")
    _model_uint(row.sequence, 8, "session sequence")
    _model_uint(row.expiry, 8, "session expiry")
    _model_uint(row.count, 2, "record count")
    _model_uint(row.bond_wei, 32, "session bond")
    _model_uint(row.claim_deadline, 8, "claim deadline")
    if row.tag == 0 and row != DataSessionByIdAbiV1():
        raise ValueError("missing by-ID view is not canonical zero")
    if row.tag != 0 and row.cell_plus_one == 0:
        raise ValueError("present by-ID view has zero cell index")
    if (row.tag == 2
            and (row.owner == bytes(20) or row.bond_wei == 0
                 or row.claim_deadline == 0 or row.sequence != 0
                 or row.expiry != 0 or row.count != 0 or row.sealed
                 or row.root != bytes(32))):
        raise ValueError("REFUND by-ID view is not canonically masked")
    return b"".join((
        bytes(30) + _model_uint(row.cell_plus_one, 2, "cell plus one"),
        bytes(31) + bytes((row.tag,)), bytes(12) + row.owner,
        bytes(24) + _model_uint(row.sequence, 8, "session sequence"),
        bytes(24) + _model_uint(row.expiry, 8, "session expiry"),
        bytes(30) + _model_uint(row.count, 2, "record count"),
        _abi_bool_word(row.sealed), row.root,
        _model_uint(row.bond_wei, 32, "session bond"),
        bytes(24) + _model_uint(row.claim_deadline, 8, "claim deadline"),
    ))


def decode_data_session_by_id_v1(raw: bytes) -> DataSessionByIdAbiV1:
    if type(raw) is not bytes or len(raw) != 320:
        raise ValueError("data-session by-ID returndata length is invalid")
    words = tuple(raw[offset:offset + 32] for offset in range(0, 320, 32))
    if (words[0][:30] != bytes(30)
            or words[1][:31] != bytes(31) or words[1][-1] not in (0, 1, 2)
            or words[2][:12] != bytes(12)
            or words[3][:24] != bytes(24)
            or words[4][:24] != bytes(24)
            or words[5][:30] != bytes(30)
            or words[6][:31] != bytes(31) or words[6][-1] not in (0, 1)
            or words[9][:24] != bytes(24)):
        raise ValueError("data-session by-ID returndata is noncanonical")
    row = DataSessionByIdAbiV1(
        int.from_bytes(words[0][30:], "big"), words[1][-1], words[2][12:],
        int.from_bytes(words[3][24:], "big"),
        int.from_bytes(words[4][24:], "big"),
        int.from_bytes(words[5][30:], "big"), bool(words[6][-1]), words[7],
        int.from_bytes(words[8], "big"),
        int.from_bytes(words[9][24:], "big"),
    )
    if encode_data_session_by_id_v1(row) != raw:
        raise ValueError("data-session by-ID returndata is invalid")
    return row


@dataclass
class DataSessionBondReceiver:
    address: str
    rejects: bool = False
    balance: int = 0
    callback: Callable[["Protocol", str], None] | None = field(
        default=None, compare=False, repr=False
    )

    def receive(
        self, protocol: "Protocol", session_id: str, amount: int
    ) -> bool:
        if self.rejects or not self.address or amount <= 0:
            return False
        self.balance = seat_checked_add(
            self.balance, amount, "data-session receiver balance"
        )
        if self.callback is not None:
            self.callback(protocol, session_id)
        return True


@dataclass
class DataRentSink:
    address: str = "data-rent-sink"
    rejects: bool = False
    balance: int = 0
    callback: Callable[["Protocol"], None] | None = field(
        default=None, compare=False, repr=False
    )

    def receive(self, protocol: "Protocol", amount: int) -> bool:
        if self.rejects or not self.address or amount <= 0:
            return False
        self.balance = seat_checked_add(
            self.balance, amount, "data-rent sink balance"
        )
        if self.callback is not None:
            self.callback(protocol)
        return True


@dataclass(frozen=True)
class SessionRef:
    session_id: str
    count: int
    root: str


@dataclass(frozen=True)
class Block:
    slot: int
    evm_timestamp: int
    block_hash: str
    parent_hash: str
    window: int
    scheduled_signature_ok: bool
    message_start: int
    message_end: int
    anchor_number: int
    anchor_hash: str
    anchor_timestamp: int
    force_root: str
    force_cutoff: int
    context_id: str
    admission_version: int
    admission_root: str
    tier: Tier
    data_records: tuple[tuple[str, int], ...] = ()
    # Proof-side flag: the circuit-internal forced classification is exact.
    dispositions_ok: bool = True
    discretionary_body: bool = True
    gas_used: int = 0
    # EVM header/prestate proof inputs; no change to queue or Inbox row ABI.
    forced_tx_fork: ForcedTxFork = ForcedTxFork.FUSAKA
    forced_tx_chain_id: int = 167_000
    forced_tx_base_fee: int = 100
    forced_tx_witnesses: tuple[ForcedTxExecutionWitness, ...] = ()


@dataclass(frozen=True)
class Candidate:
    candidate_id: str
    base_canonical_hash: str
    blocks: tuple[Block, ...]
    tier: Tier
    end_state_root: str
    winning_data_commitment: str
    next_due_at: int
    end_l2_block_number: int
    next_base_fee: int = 101
    next_excess_blob_gas: int = 0
    proof_ok: bool = True
    force_range_proof_ok: bool = True
    episode: int = 0
    recovery_revision: int = 0
    recovery_id: str = ""
    session_refs: tuple[SessionRef, ...] = ()
    manifest_exact: bool = True
    beneficiary: str = "prover"
    reward_execution_gas: int = 0
    reward_published_bytes: int = 0
    recovery_fields_zero: bool = True
    available_payload_hashes: frozenset[str] = frozenset()

    @property
    def tip(self) -> Block:
        return self.blocks[-1]

    @property
    def count(self) -> int:
        return len(self.blocks)

    @property
    def order(self) -> tuple[int, int, int]:
        return (self.count, self.tip.slot, -int(self.tip.block_hash, 16))


@dataclass(frozen=True)
class RewardClassV1:
    class_id: int
    fixed_wei: int
    per_execution_gas_wei: int
    per_published_byte_wei: int
    cap_wei: int

    def __post_init__(self) -> None:
        if (type(self.class_id) is not int
                or self.class_id not in {tier.value for tier in Tier}
                or any(type(value) is not int
                       or not 0 <= value <= SEAT_UINT256_MAX
                       for value in (
                           self.fixed_wei,
                           self.per_execution_gas_wei,
                           self.per_published_byte_wei,
                           self.cap_wei,
                       ))):
            raise ValueError("reward class is not a bounded tier schedule")


def default_reward_class_rows_v1() -> tuple[RewardClassV1, ...]:
    """Return fixture rows owned only by the queried BuilderRegistry."""

    return (
        RewardClassV1(1, 10, 1, 1, 1_000_000),
        RewardClassV1(2, 20, 2, 2, 2_000_000),
        RewardClassV1(3, 30, 3, 3, 3_000_000),
    )


def encode_reward_class_return_v1(
    row: RewardClassV1, configuration_hash: bytes
) -> bytes:
    if type(row) is not RewardClassV1:
        raise ValueError("reward class getter row is malformed")
    exact_configuration_hash = _model_fixed_bytes32(configuration_hash)
    if exact_configuration_hash == bytes(32):
        raise ValueError("reward class configuration hash is zero")
    encoded = b"".join((
        REWARD_CLASS_V1_MAGIC + bytes(28),
        exact_configuration_hash,
        _model_uint(row.class_id, 32, "returned reward class"),
        _model_uint(row.fixed_wei, 32, "returned reward fixed amount"),
        _model_uint(
            row.per_execution_gas_wei, 32,
            "returned reward execution-gas rate",
        ),
        _model_uint(
            row.per_published_byte_wei, 32,
            "returned reward published-byte rate",
        ),
        _model_uint(row.cap_wei, 32, "returned reward cap"),
    ))
    if len(encoded) != 224:
        raise AssertionError("rewardClassV1 return must be exactly 224 bytes")
    return encoded


def decode_reward_class_return_v1(
    returndata: bytes, expected_class_id: int,
    expected_configuration_hash: bytes,
) -> RewardClassV1:
    exact_configuration_hash = _model_fixed_bytes32(
        expected_configuration_hash
    )
    if (type(returndata) is not bytes or len(returndata) != 224
            or type(expected_class_id) is not int
            or expected_class_id not in (1, 2, 3)
            or exact_configuration_hash == bytes(32)):
        raise ValueError("rewardClassV1 return length or class is invalid")
    words = tuple(
        returndata[offset:offset + 32]
        for offset in range(0, len(returndata), 32)
    )
    if (words[0] != REWARD_CLASS_V1_MAGIC + bytes(28)
            or words[1] != exact_configuration_hash):
        raise ValueError("rewardClassV1 magic or configuration is invalid")
    row = RewardClassV1(
        _decode_uint_word_v1(words[2], 8, "returned reward class"),
        int.from_bytes(words[3], "big"),
        int.from_bytes(words[4], "big"),
        int.from_bytes(words[5], "big"),
        int.from_bytes(words[6], "big"),
    )
    if (row.class_id != expected_class_id
            or encode_reward_class_return_v1(
                row, exact_configuration_hash
            ) != returndata):
        raise ValueError("rewardClassV1 echo or padding is invalid")
    return row


@dataclass
class RewardClassRegistryV1:
    rows: tuple[RewardClassV1, ...] = field(
        default_factory=default_reward_class_rows_v1
    )
    address: str = BUILDER_REGISTRY_PROFILE_ADDRESS
    runtime_hash: bytes = BUILDER_REGISTRY_PROFILE_RUNTIME_HASH
    configuration_hash: bytes = BUILDER_REGISTRY_PROFILE_CONFIGURATION_HASH
    return_overrides: dict[int, bytes] = field(
        default_factory=dict, compare=False, repr=False
    )
    faulted_classes: set[int] = field(
        default_factory=set, compare=False, repr=False
    )
    component_config_return_override: bytes | None = field(
        default=None, compare=False, repr=False
    )
    component_config_call_fault: bool = field(
        default=False, compare=False, repr=False
    )
    observed_runtime_hash_override: bytes | None = field(
        default=None, compare=False, repr=False
    )
    codehash_call_fault: bool = field(
        default=False, compare=False, repr=False
    )
    calls: list[tuple[str, int]] = field(
        default_factory=list, compare=False, repr=False
    )
    component_config_calls: list[str] = field(
        default_factory=list, compare=False, repr=False
    )
    codehash_calls: list[str] = field(
        default_factory=list, compare=False, repr=False
    )

    def __post_init__(self) -> None:
        if (type(self.rows) is not tuple
                or tuple(row.class_id for row in self.rows) != (1, 2, 3)
                or any(type(row) is not RewardClassV1 for row in self.rows)
                or not self.address
                or type(self.runtime_hash) is not bytes
                or len(self.runtime_hash) != 32
                or self.runtime_hash == bytes(32)
                or type(self.configuration_hash) is not bytes
                or len(self.configuration_hash) != 32
                or self.configuration_hash == bytes(32)
                or self.return_overrides or self.faulted_classes
                or self.component_config_return_override is not None
                or self.component_config_call_fault
                or self.observed_runtime_hash_override is not None
                or self.codehash_call_fault
                or self.calls or self.component_config_calls
                or self.codehash_calls):
            raise ValueError("reward class registry is not immutable and empty")

    def class_by_id(self, class_id: int) -> RewardClassV1:
        if type(class_id) is not int or class_id not in (1, 2, 3):
            raise ValueError("reward class is outside the tier schedule")
        row = self.rows[class_id - 1]
        if row.class_id != class_id:
            raise ValueError("reward class schedule changed")
        return row

    def extcodehash(self, *, caller: str) -> bytes:
        if not caller:
            raise ValueError("BuilderRegistry EXTCODEHASH caller is empty")
        self.codehash_calls.append(caller)
        if self.codehash_call_fault:
            raise ValueError("BuilderRegistry EXTCODEHASH failed")
        return (
            self.runtime_hash
            if self.observed_runtime_hash_override is None
            else self.observed_runtime_hash_override
        )

    def component_config_staticcall(
        self, calldata: bytes, *, caller: str, gas: int, value: int
    ) -> bytes:
        if (calldata != COMPONENT_CONFIG_GETTER_SELECTOR
                or not caller or gas != COMPONENT_CONFIG_GETTER_GAS
                or value != 0):
            raise ValueError("componentConfigHashV2 STATICCALL frame is inexact")
        self.component_config_calls.append(caller)
        if self.component_config_call_fault:
            raise ValueError("componentConfigHashV2 STATICCALL failed")
        return (
            self.configuration_hash
            if self.component_config_return_override is None
            else self.component_config_return_override
        )

    def staticcall(
        self, calldata: bytes, *, caller: str, gas: int, value: int
    ) -> bytes:
        if (type(calldata) is not bytes or len(calldata) != 36
                or calldata[:4] != REWARD_CLASS_V1_SELECTOR
                or calldata[4:35] != bytes(31)
                or not caller or gas != REWARD_CLASS_READ_GAS or value != 0):
            raise ValueError("rewardClassV1 STATICCALL frame is inexact")
        class_id = calldata[35]
        row = self.class_by_id(class_id)
        self.calls.append((caller, class_id))
        if class_id in self.faulted_classes:
            raise ValueError("rewardClassV1 STATICCALL failed")
        return self.return_overrides.get(
            class_id,
            encode_reward_class_return_v1(row, self.configuration_hash),
        )


@dataclass(frozen=True)
class RewardReceiptV1:
    candidate_id: bytes
    beneficiary: str
    reward_class: int
    reward_execution_gas: int
    reward_published_bytes: int
    execution_profile_hash: bytes
    committed_at_block: int
    committed_at_timestamp: int
    claim_until: int

    def __post_init__(self) -> None:
        if (type(self.candidate_id) is not bytes
                or len(self.candidate_id) != 32
                or self.candidate_id == bytes(32)
                or not self.beneficiary
                or type(self.reward_class) is not int
                or self.reward_class not in (1, 2, 3)
                or type(self.reward_execution_gas) is not int
                or not 0 <= self.reward_execution_gas <= SEAT_UINT256_MAX
                or type(self.reward_published_bytes) is not int
                or not 0 <= self.reward_published_bytes <= UINT64_MAX
                or type(self.execution_profile_hash) is not bytes
                or len(self.execution_profile_hash) != 32
                or self.execution_profile_hash == bytes(32)
                or any(type(value) is not int
                       or not 0 < value <= UINT64_MAX
                       for value in (
                           self.committed_at_block,
                           self.committed_at_timestamp,
                           self.claim_until,
                       ))
                or self.claim_until <= self.committed_at_timestamp):
            raise ValueError("reward receipt is not a canonical V1 entitlement")
        _model_address20(self.beneficiary)

    @property
    def commitment(self) -> bytes:
        return keccak256(b"".join((
            REWARD_RECEIPT_DOMAIN_V1,
            self.candidate_id,
            _model_address20(self.beneficiary),
            _model_uint(self.reward_class, 1, "receipt reward class"),
            _model_uint(
                self.reward_execution_gas, 32, "receipt execution gas"
            ),
            _model_uint(
                self.reward_published_bytes, 8, "receipt published bytes"
            ),
            self.execution_profile_hash,
            _model_uint(
                self.committed_at_block, 8, "receipt commit block"
            ),
            _model_uint(
                self.committed_at_timestamp, 8, "receipt commit timestamp"
            ),
            _model_uint(self.claim_until, 8, "receipt claim deadline"),
        )))


@dataclass
class RewardReceiptCellV1:
    receipt: RewardReceiptV1 | None = None
    claimed: bool = False


class RewardReceiptAllocationOutcomeV1(Enum):
    STORE = "STORE"
    SKIP_ID_CONVERSION = "SKIP_ID_CONVERSION"
    SKIP_DEADLINE_OVERFLOW = "SKIP_DEADLINE_OVERFLOW"
    SKIP_LIVE_COLLISION = "SKIP_LIVE_COLLISION"
    REJECT_CANDIDATE_INVARIANT = "REJECT_CANDIDATE_INVARIANT"
    REJECT_SETTLEMENT_INVARIANT = "REJECT_SETTLEMENT_INVARIANT"


@dataclass(frozen=True)
class RewardReceiptAllocationDecisionV1:
    outcome: RewardReceiptAllocationOutcomeV1
    candidate_id: bytes = bytes(32)
    beneficiary: str = ""
    reward_class: int = 0
    reward_execution_gas: int = 0
    reward_published_bytes: int = 0
    receipt_index: int = 0
    receipt: RewardReceiptV1 | None = None

    @property
    def skips_receipt(self) -> bool:
        return self.outcome in {
            RewardReceiptAllocationOutcomeV1.SKIP_ID_CONVERSION,
            RewardReceiptAllocationOutcomeV1.SKIP_DEADLINE_OVERFLOW,
            RewardReceiptAllocationOutcomeV1.SKIP_LIVE_COLLISION,
        }


@dataclass(frozen=True)
class CandidateCommittedV2:
    candidate_id: bytes
    beneficiary: str
    reward_class: int
    reward_execution_gas: int
    reward_published_bytes: int
    receipt_stored: bool
    receipt_index: int
    receipt_commitment: bytes


@dataclass(frozen=True)
class RewardClassFundedV1:
    reward_class: int
    funder: str
    amount: int
    class_funding_after: int
    total_funding_after: int


@dataclass(frozen=True)
class RewardClaimedV1:
    candidate_id: bytes
    beneficiary: str
    reward_class: int
    paid_wei: int


def encode_reward_receipt_return_v1(
    receipt: RewardReceiptV1 | None, claimed: bool = False
) -> bytes:
    if receipt is None:
        if claimed:
            raise ValueError("absent reward receipt cannot be claimed")
        encoded = b"".join((
            REWARD_RECEIPT_V1_MAGIC + bytes(28),
            bytes(32),
            *(bytes(32) for _ in range(10)),
        ))
    else:
        if type(receipt) is not RewardReceiptV1 or type(claimed) is not bool:
            raise ValueError("reward receipt view state is malformed")
        encoded = b"".join((
            REWARD_RECEIPT_V1_MAGIC + bytes(28),
            bytes(31) + b"\x01",
            bytes(12) + _model_address20(receipt.beneficiary),
            _model_uint(receipt.reward_class, 32, "view reward class"),
            _model_uint(
                receipt.reward_execution_gas, 32, "view reward execution gas"
            ),
            _model_uint(
                receipt.reward_published_bytes, 32,
                "view reward published bytes",
            ),
            receipt.execution_profile_hash,
            _model_uint(
                receipt.committed_at_block, 32, "view reward commit block"
            ),
            _model_uint(
                receipt.committed_at_timestamp, 32,
                "view reward commit timestamp",
            ),
            _model_uint(receipt.claim_until, 32, "view reward deadline"),
            bytes(31) + bytes((int(claimed),)),
            receipt.commitment,
        ))
    if len(encoded) != REWARD_RECEIPT_RETURN_LENGTH:
        raise AssertionError("rewardReceiptV1 return must be exactly 384 bytes")
    return encoded


def reward_receipt_index_v1(candidate_id: object) -> int:
    exact = _model_fixed_bytes32(candidate_id)
    if exact == bytes(32):
        raise ValueError("zero candidate identity has no reward-ring cell")
    return exact[-1]


def reward_candidate_id_word_v1(candidate_id: object) -> bytes | None:
    """Convert supported model identities without exceptions or fallback repr."""

    if type(candidate_id) is bytes:
        return candidate_id if len(candidate_id) == 32 else None
    if type(candidate_id) is not str:
        return None
    unprefixed = candidate_id.removeprefix("0x")
    if (len(unprefixed) == 64
            and all(character in "0123456789abcdefABCDEF"
                    for character in unprefixed)):
        return bytes.fromhex(unprefixed)
    return hashlib.sha256(
        b"TAIKO_MODEL_FIXED_BYTES32_V1\x00" + repr(candidate_id).encode()
    ).digest()


def reward_candidate_metrics_v1(
    protocol: object, candidate: object
) -> tuple[int, int]:
    """Derive reward metrics from executed blocks and consumed data records."""

    if (type(candidate) is not Candidate
            or not hasattr(protocol, "data_record_events")):
        raise ValueError("reward metric source is malformed")
    execution_gas = 0
    for block in candidate.blocks:
        if (type(block) is not Block or type(block.gas_used) is not int
                or not 0 <= block.gas_used <= SEAT_UINT256_MAX):
            raise ValueError("candidate block gasUsed is malformed")
        execution_gas = seat_checked_add(
            execution_gas, block.gas_used, "candidate reward execution gas"
        )
    records: dict[tuple[str, int], DataRecord] = {}
    for record in protocol.data_record_events:
        if (type(record) is not DataRecord
                or type(record.chunk_byte_length) is not int
                or not 0 <= record.chunk_byte_length <= UINT64_MAX):
            raise ValueError("reward data record is malformed")
        key = (record.session_id, record.index)
        if key in records:
            raise ValueError("reward data record identity is duplicated")
        records[key] = record
    consumed = tuple(
        record_id for block in candidate.blocks
        for record_id in block.data_records
    )
    if len(consumed) != len(set(consumed)):
        raise ValueError("reward data record was consumed twice")
    published_bytes = 0
    for record_id in consumed:
        record = records.get(record_id)
        if record is None:
            raise ValueError("consumed reward data record is unavailable")
        if published_bytes > UINT64_MAX - record.chunk_byte_length:
            raise ValueError("candidate reward published bytes overflow uint64")
        published_bytes += record.chunk_byte_length
    return execution_gas, published_bytes


def reward_candidate_metrics_valid_v1(
    candidate: object, protocol: object | None = None
) -> bool:
    if (type(candidate) is not Candidate
            or type(candidate.reward_execution_gas) is not int
            or not 0 <= candidate.reward_execution_gas <= SEAT_UINT256_MAX
            or type(candidate.reward_published_bytes) is not int
            or not 0 <= candidate.reward_published_bytes <= UINT64_MAX):
        return False
    if protocol is None:
        return True
    try:
        return reward_candidate_metrics_v1(protocol, candidate) == (
            candidate.reward_execution_gas,
            candidate.reward_published_bytes,
        )
    except (TypeError, ValueError, OverflowError):
        return False


@dataclass
class CanonicalCore:
    l2_block_number: int
    tip_hash: str
    tip_slot: int
    state_root: str
    message_cursor: int
    winning_data_commitment: str = "empty"
    next_base_fee: int = 100
    next_excess_blob_gas: int = 0


@dataclass
class Canonical:
    core: CanonicalCore
    canonicalized_at_block: int

    @property
    def base_hash(self) -> str:
        c = self.core
        return (f"canonical:{c.l2_block_number}:{c.tip_hash}:{c.tip_slot}:{c.state_root}:"
                f"{c.message_cursor}:{c.winning_data_commitment}:"
                f"{c.next_base_fee}:{c.next_excess_blob_gas}:"
                f"{self.canonicalized_at_block}")


@dataclass
class RecoveryRound:
    episode: int
    revision: int
    base_canonical_hash: str
    round_start_slot: int
    anchor_number: int
    anchor_hash: str
    force_root: str
    force_cutoff: int
    admission_version: int
    admission_root: str
    escape_slot: int
    expires_at: int
    causes: Cause

    @property
    def recovery_id(self) -> str:
        return (f"recovery:{self.episode}:{self.revision}:{self.base_canonical_hash}:"
                f"{self.round_start_slot}:{self.anchor_number}:{self.anchor_hash}:"
                f"{self.force_root}:{self.force_cutoff}:"
                f"{self.admission_version}:{self.admission_root}:"
                f"{self.escape_slot}:{int(self.causes)}")


class DutyStatus(Enum):
    OPEN = 1
    FAILED_OVER = 2
    SATISFIED = 3
    BREACHED = 4
    EXCUSED = 5
    EXCUSED_MIGRATION = 6


class DutyAttachmentStatus(Enum):
    ATTACHED = 1
    RING_FULL = 2
    SEQUENCE_EXHAUSTED = 3


class SelectionSource(Enum):
    DUTY_FAILOVER = 1
    HEALTHY_EXPIRY = 2


@dataclass(frozen=True)
class SeatTerm:
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    operator: str
    payout: str
    ask: int
    installed_at: int
    authorization_id: bytes | None = None
    generation: int | None = None
    install_revision: int = 0


@dataclass
class SeatService:
    responsibility_start: int | None
    minimum_tenure_until: int
    premium_funded_until: int | None
    service_eligible_until: int | None
    closed_at: int | None = None
    close_reason: str | None = None
    ring_full_recovery_at: int | None = None
    exit_requested_at: int | None = None
    duty_base_tip_slot: int | None = None
    duty_base_sequence: int | None = None
    prospective_target_tip: int | None = None
    prospective_recovery_at: int | None = None
    prospective_failover_at: int | None = None
    prospective_slash_at: int | None = None
    term_removed_at: int | None = None
    standby_lease_expires_at: int | None = None


@dataclass
class Duty:
    duty_id: bytes
    term_id: bytes
    tranche_id: bytes
    operator: str
    sequence: int
    ring_index: int
    base_sequence: int
    base_tip_slot: int
    target_tip: int
    recovery_at: int
    failover_at: int
    slash_at: int
    satisfied_at: int | None = None
    disposition_at: int | None = None
    breach_recorded_at: int | None = None
    status: DutyStatus = DutyStatus.OPEN


@dataclass
class SeatDutyCell:
    sequence: int = 0
    duty_id: bytes | None = None
    reusable: bool = True


@dataclass(frozen=True)
class SeatDutyScanOutcome:
    changed: bool
    reusable_index: int | None
    sla_missed: bool
    satisfied: int


@dataclass(frozen=True)
class DutyAttachmentOutcome:
    status: DutyAttachmentStatus
    duty: Duty | None = None


@dataclass(frozen=True)
class SelectionRecord:
    selection_id: bytes
    term_id: bytes
    tranche_id: bytes
    offer_id: bytes
    selected_canonical_sequence: int
    selected_at: int
    target_tip: int
    source: SelectionSource
    predecessor_duty_id: bytes | None = None


@dataclass(frozen=True)
class SettlementSeatStage:
    stage_id: bytes
    offer_id: bytes
    tranche_id: bytes
    operator: str
    payout: str
    ask: int
    selected_rank: int
    outgoing_primary_term_id: bytes | None
    lineup_commitment: bytes
    handover_at: int
    expires_at: int
    target: str
    authorization_id: bytes
    generation: int


@dataclass
class StageTombstone:
    stage_id: bytes
    lineup_commitment: bytes
    reason: str
    reconciled: bool = False


SETTLEMENT_FORCED_INGRESS_FLOOR_MAGIC = b"SIF1"
SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR = bytes.fromhex("fe2a2914")
SETTLEMENT_FORCED_INGRESS_FLOOR_LENGTH = 64
SETTLEMENT_FORCED_INGRESS_FLOOR_GAS = 50_000
DATA_SESSION_ACCOUNTING_MAGIC = b"DSV1"
DATA_SESSION_ACCOUNTING_LENGTH = 448
@dataclass(frozen=True)
class DataSessionAccountingV1:
    live_count: int
    refund_count: int
    occupied_count: int
    gc_cursor: int
    next_session_sequence: int
    live_bond_liability: int
    refund_bond_liability: int
    guard_entered: bool
    data_session_config_hash: bytes
    reward_funding_class_1: int = 0
    reward_funding_class_2: int = 0
    reward_funding_class_3: int = 0
    total_reward_funding: int = 0


def encode_settlement_forced_ingress_floor_v1(minimum_due_at: int) -> bytes:
    """Encode the exact active-Settlement SIF1 forced-ingress floor."""

    return (
        SETTLEMENT_FORCED_INGRESS_FLOOR_MAGIC + bytes(28)
        + bytes(24) + _model_uint(
            minimum_due_at, 8, "Settlement forced-ingress minimum dueAt"
        )
    )


def decode_settlement_forced_ingress_floor_v1(raw: bytes) -> int:
    """Strictly decode the exact 64-byte SIF1 response."""

    if (type(raw) is not bytes
            or len(raw) != SETTLEMENT_FORCED_INGRESS_FLOOR_LENGTH
            or raw[:32]
                != SETTLEMENT_FORCED_INGRESS_FLOOR_MAGIC + bytes(28)
            or raw[32:56] != bytes(24)):
        raise ValueError("Settlement forced-ingress floor is noncanonical")
    minimum_due_at = int.from_bytes(raw[56:64], "big")
    if encode_settlement_forced_ingress_floor_v1(minimum_due_at) != raw:
        raise ValueError("Settlement forced-ingress floor is invalid")
    return minimum_due_at


def encode_data_session_accounting_v1(
    state: DataSessionAccountingV1,
) -> bytes:
    if (type(state) is not DataSessionAccountingV1
            or type(state.guard_entered) is not bool
            or type(state.data_session_config_hash) is not bytes
            or len(state.data_session_config_hash) != 32
            or state.data_session_config_hash == bytes(32)
            or any(type(value) is not int
                   or not 0 <= value <= SEAT_UINT256_MAX
                   for value in (
                       state.reward_funding_class_1,
                       state.reward_funding_class_2,
                       state.reward_funding_class_3,
                       state.total_reward_funding,
                   ))
            or state.total_reward_funding != sum((
                state.reward_funding_class_1,
                state.reward_funding_class_2,
                state.reward_funding_class_3,
            ))):
        raise ValueError("data-session accounting is malformed")
    return b"".join((
        DATA_SESSION_ACCOUNTING_MAGIC + bytes(28),
        bytes(30) + _model_uint(state.live_count, 2, "live count"),
        bytes(30) + _model_uint(state.refund_count, 2, "refund count"),
        bytes(30) + _model_uint(state.occupied_count, 2, "occupied count"),
        bytes(30) + _model_uint(state.gc_cursor, 2, "GC cursor"),
        bytes(24) + _model_uint(
            state.next_session_sequence, 8, "next session sequence"
        ),
        _model_uint(state.live_bond_liability, 32, "live bond liability"),
        _model_uint(state.refund_bond_liability, 32, "refund bond liability"),
        bytes(31) + bytes((int(state.guard_entered),)),
        state.data_session_config_hash,
        _model_uint(
            state.reward_funding_class_1, 32, "class-one reward funding"
        ),
        _model_uint(
            state.reward_funding_class_2, 32, "class-two reward funding"
        ),
        _model_uint(
            state.reward_funding_class_3, 32, "class-three reward funding"
        ),
        _model_uint(
            state.total_reward_funding, 32, "total reward funding"
        ),
    ))


def decode_data_session_accounting_v1(raw: bytes) -> DataSessionAccountingV1:
    if type(raw) is not bytes or len(raw) != DATA_SESSION_ACCOUNTING_LENGTH:
        raise ValueError("data-session accounting returndata length is invalid")
    words = tuple(raw[offset:offset + 32] for offset in range(0, len(raw), 32))
    if (words[0] != DATA_SESSION_ACCOUNTING_MAGIC + bytes(28)
            or any(words[index][:30] != bytes(30) for index in (1, 2, 3, 4))
            or words[5][:24] != bytes(24)
            or words[8][:31] != bytes(31)
            or words[8][-1] not in (0, 1)):
        raise ValueError("data-session accounting returndata is noncanonical")
    state = DataSessionAccountingV1(
        int.from_bytes(words[1][30:], "big"),
        int.from_bytes(words[2][30:], "big"),
        int.from_bytes(words[3][30:], "big"),
        int.from_bytes(words[4][30:], "big"),
        int.from_bytes(words[5][24:], "big"),
        int.from_bytes(words[6], "big"),
        int.from_bytes(words[7], "big"),
        bool(words[8][-1]),
        words[9],
        int.from_bytes(words[10], "big"),
        int.from_bytes(words[11], "big"),
        int.from_bytes(words[12], "big"),
        int.from_bytes(words[13], "big"),
    )
    if encode_data_session_accounting_v1(state) != raw:
        raise ValueError("data-session accounting returndata is invalid")
    return state


@dataclass(frozen=True)
class Generation:
    address: str
    bond: int
    registration_index: int
    effective_window: int
    max_reserved_window: int = 0
    reservations_closed: bool = False
    tombstoned_at_l2_slot: int = UINT64_MAX
    reservation_base_window: int = 0
    reservation_bitmap: int = 0
    unreleased_tranche_count: int = 0
    maximum_liable_until: int = 0
    exit_sequence: int | None = None
    effective_l2_slot: int | None = None


class TrancheState(Enum):
    EMPTY = 0
    FREE = 1
    RESERVED = 2
    LIABLE = 3
    RELEASED = 4
    SLASHED = 5


@dataclass(frozen=True)
class TrancheLifecycle:
    window: int
    state: TrancheState
    amount: int
    liable_until: int


@dataclass
class BuilderExitRequest:
    sequence: int
    registration_index: int
    request_window: int
    mature_window: int
    resolved: bool = False


class ScheduleReleaseState(Enum):
    UNSEALED = 0
    SEALED = 1
    VACANT = 2
    EXPIRED = 3


EMPTY_RANKED_ENTRY_ROOT = bytes.fromhex(
    "986d3e795bd9ddfabe213b93cea0211eea5a663e895bfc112d90c5bf2fff1564"
)

SCHEDULE_WINDOW_MAGIC = b"SWV1"
SCHEDULE_FINALIZE_EXPIRY_SELECTOR = bytes.fromhex("774167d9")
SCHEDULE_FINALIZE_EXPIRY_MAGIC = b"SWT1"
SETTLEMENT_SCHEDULE_TERMINAL_SELECTOR = bytes.fromhex("9338be7d")
SETTLEMENT_SCHEDULE_TERMINAL_MAGIC = b"STS1"
SCHEDULE_SEAL_WITNESS_VERSION = 1
MAX_SCHEDULE_FORK_WITNESS_BYTES = 131_072
MAX_SCHEDULE_SEAL_WITNESS_BYTES = 280_000
MAX_SCHEDULE_CARRIER_HEADER_BYTES = 2_048
MAX_SCHEDULE_HEADER_FIELDS = 32
MIN_SCHEDULE_HEADER_FIELDS = 20
MAX_SCHEDULE_MPT_PATH_NODES = 65
MAX_SCHEDULE_MPT_NODE_BYTES = 600
MAX_SCHEDULE_MPT_BYTES = 117_393
SCHEDULE_REGISTRY_CELL_BYTES = 101
SCHEDULE_TRANCHE_RECORD_BYTES = 329
SCHEDULE_FORK_REGISTRATION_SELECTOR = bytes.fromhex("c614591c")
SCHEDULE_FORK_CONFIG_SELECTOR = bytes.fromhex("44efa773")
SCHEDULE_FORK_ROUTE_STATE_SELECTOR = bytes.fromhex("7e9f3c0d")
SCHEDULE_FORK_ROUTE_READ_GAS = 50_000
SCHEDULE_FORK_REGISTRATION_READ_GAS = 100_000
SCHEDULE_FORK_VERIFIER_CONFIG_READ_GAS = 100_000
SCHEDULE_FORK_MUTATION_GAS = 4_000_000
def _canonical_rlp_list_field_count(
    encoded: bytes, *, allow_inline_lists: bool = False
) -> int:
    """Return the immediate field count for one complete canonical RLP list."""

    if type(encoded) is not bytes or not encoded:
        raise ValueError("RLP item is empty")

    def item(offset: int) -> tuple[int, bool, int, int]:
        if offset >= len(encoded):
            raise ValueError("RLP item is truncated")
        prefix = encoded[offset]
        if prefix <= 0x7F:
            return offset + 1, False, offset, offset + 1
        if prefix <= 0xB7:
            size = prefix - 0x80
            start = offset + 1
            end = start + size
            if end > len(encoded) or (size == 1 and encoded[start] <= 0x7F):
                raise ValueError("RLP short string is noncanonical")
            return end, False, start, end
        if prefix <= 0xBF:
            size_bytes = prefix - 0xB7
            size_start = offset + 1
            size_end = size_start + size_bytes
            if size_end > len(encoded) or encoded[size_start] == 0:
                raise ValueError("RLP long-string length is noncanonical")
            size = int.from_bytes(encoded[size_start:size_end], "big")
            if size <= 55 or size_end + size > len(encoded):
                raise ValueError("RLP long string is noncanonical")
            return size_end + size, False, size_end, size_end + size
        if prefix <= 0xF7:
            size = prefix - 0xC0
            start = offset + 1
            end = start + size
            if end > len(encoded):
                raise ValueError("RLP short list is truncated")
            return end, True, start, end
        size_bytes = prefix - 0xF7
        size_start = offset + 1
        size_end = size_start + size_bytes
        if size_end > len(encoded) or encoded[size_start] == 0:
            raise ValueError("RLP long-list length is noncanonical")
        size = int.from_bytes(encoded[size_start:size_end], "big")
        if size <= 55 or size_end + size > len(encoded):
            raise ValueError("RLP long list is noncanonical")
        return size_end + size, True, size_end, size_end + size

    end, is_list, payload_start, payload_end = item(0)
    if end != len(encoded) or not is_list:
        raise ValueError("RLP value is not one complete list")
    count = 0
    cursor = payload_start
    while cursor < payload_end:
        child_end, child_is_list, child_start, child_payload_end = item(cursor)
        if child_end > payload_end:
            raise ValueError("RLP child exceeds its parent")
        if child_is_list and not allow_inline_lists:
            raise ValueError("RLP list contains a nested list")
        cursor = child_end
        count += 1
    if cursor != payload_end:
        raise ValueError("RLP list has a suffix")
    return count


@dataclass(frozen=True)
class ScheduleMptPathV1:
    nodes: tuple[bytes, ...]

    def encode(self) -> bytes:
        if (not 1 <= len(self.nodes) <= MAX_SCHEDULE_MPT_PATH_NODES
                or any(type(node) is not bytes
                       or not 0 < len(node) <= MAX_SCHEDULE_MPT_NODE_BYTES
                       for node in self.nodes)):
            raise ValueError("Schedule MPT path bounds are invalid")
        for node in self.nodes:
            _canonical_rlp_list_field_count(node, allow_inline_lists=True)
        return bytes((len(self.nodes),)) + b"".join(
            len(node).to_bytes(2, "big") + node for node in self.nodes
        )


@dataclass(frozen=True)
class ScheduleRegistryCellWitnessV1:
    present: int
    builder: bytes
    bond: int
    registration_index: int
    effective_l2_slot: int
    tranche_root: bytes
    tombstoned_at_l2_slot: int

    def encode(self) -> bytes:
        if self.present not in {0, 1}:
            raise ValueError("Schedule registry presence bit is invalid")
        if (type(self.builder) is not bytes or len(self.builder) != 20
                or type(self.tranche_root) is not bytes
                or len(self.tranche_root) != 32):
            raise ValueError("Schedule registry cell bytes are malformed")
        if self.present == 0:
            if self != ScheduleRegistryCellWitnessV1(
                    0, bytes(20), 0, 0, 0, bytes(32), 0):
                raise ValueError("absent Schedule registry cell is not zero")
        elif (self.builder == bytes(20) or self.bond == 0
              or self.tranche_root == bytes(32)):
            raise ValueError("present Schedule registry cell is empty")
        encoded = b"".join((
            bytes((self.present,)), self.builder,
            _model_uint(self.bond, 24, "Schedule registry bond"),
            _model_uint(
                self.registration_index, 8, "Schedule registration index"
            ),
            _model_uint(
                self.effective_l2_slot, 8, "Schedule effective L2 slot"
            ),
            self.tranche_root,
            _model_uint(
                self.tombstoned_at_l2_slot, 8,
                "Schedule tombstone L2 slot",
            ),
        ))
        if len(encoded) != SCHEDULE_REGISTRY_CELL_BYTES:
            raise AssertionError("Schedule registry cell width drifted")
        return encoded


@dataclass(frozen=True)
class ScheduleTrancheRecordWitnessV1:
    stored_window: int
    state: int
    amount: int
    liable_until: int
    siblings: tuple[bytes, ...]

    def encode(self) -> bytes:
        if (self.state not in range(6) or len(self.siblings) != 9
                or any(type(row) is not bytes or len(row) != 32
                       for row in self.siblings)):
            raise ValueError("Schedule tranche record is malformed")
        if self.state == TrancheState.EMPTY.value and (
                self.stored_window != UINT64_MAX
                or self.amount != 0 or self.liable_until != 0):
            raise ValueError("Schedule EMPTY tranche is noncanonical")
        encoded = b"".join((
            _model_uint(self.stored_window, 8, "Schedule tranche window"),
            bytes((self.state,)),
            _model_uint(self.amount, 24, "Schedule tranche amount"),
            _model_uint(self.liable_until, 8, "Schedule tranche deadline"),
            *self.siblings,
        ))
        if len(encoded) != SCHEDULE_TRANCHE_RECORD_BYTES:
            raise AssertionError("Schedule tranche record width drifted")
        return encoded


@dataclass(frozen=True)
class ScheduleSealWitnessV1:
    fork_witness: bytes
    carrier_header_rlp: bytes
    account_path: ScheduleMptPathV1
    header_slot_path: ScheduleMptPathV1
    root_slot_path: ScheduleMptPathV1
    cells: tuple[ScheduleRegistryCellWitnessV1, ...]
    tranche_records: tuple[ScheduleTrancheRecordWitnessV1, ...]

    def encode(self) -> bytes:
        if (type(self.fork_witness) is not bytes
                or not 1 <= len(self.fork_witness)
                    <= MAX_SCHEDULE_FORK_WITNESS_BYTES
                or type(self.carrier_header_rlp) is not bytes
                or not 1 <= len(self.carrier_header_rlp)
                    <= MAX_SCHEDULE_CARRIER_HEADER_BYTES
                or len(self.cells) != 64
                or len(self.tranche_records)
                    != sum(cell.present for cell in self.cells)):
            raise ValueError("Schedule seal witness geometry is invalid")
        fields = _canonical_rlp_list_field_count(self.carrier_header_rlp)
        if not MIN_SCHEDULE_HEADER_FIELDS <= fields <= MAX_SCHEDULE_HEADER_FIELDS:
            raise ValueError("Schedule carrier header field count is invalid")
        paths = (
            self.account_path.encode() + self.header_slot_path.encode()
            + self.root_slot_path.encode()
        )
        if len(paths) > MAX_SCHEDULE_MPT_BYTES:
            raise ValueError("Schedule MPT paths exceed the aggregate cap")
        encoded = b"".join((
            bytes((SCHEDULE_SEAL_WITNESS_VERSION,)),
            len(self.fork_witness).to_bytes(4, "big"), self.fork_witness,
            len(self.carrier_header_rlp).to_bytes(2, "big"),
            self.carrier_header_rlp, paths,
            *(cell.encode() for cell in self.cells),
            *(record.encode() for record in self.tranche_records),
        ))
        if len(encoded) > MAX_SCHEDULE_SEAL_WITNESS_BYTES:
            raise ValueError("Schedule seal witness exceeds its absolute cap")
        return encoded


def _decode_schedule_mpt_path_v1(
    data: bytes, offset: int,
) -> tuple[ScheduleMptPathV1, int]:
    if offset >= len(data):
        raise ValueError("Schedule MPT path count is missing")
    count = data[offset]
    offset += 1
    nodes: list[bytes] = []
    for _ in range(count):
        if offset + 2 > len(data):
            raise ValueError("Schedule MPT node length is missing")
        size = int.from_bytes(data[offset:offset + 2], "big")
        offset += 2
        if offset + size > len(data):
            raise ValueError("Schedule MPT node is truncated")
        nodes.append(data[offset:offset + size])
        offset += size
    path = ScheduleMptPathV1(tuple(nodes))
    path.encode()
    return path, offset


def decode_schedule_seal_witness_v1(data: bytes) -> ScheduleSealWitnessV1:
    if (type(data) is not bytes or not data
            or len(data) > MAX_SCHEDULE_SEAL_WITNESS_BYTES
            or data[0] != SCHEDULE_SEAL_WITNESS_VERSION):
        raise ValueError("Schedule seal witness version or size is invalid")
    offset = 1
    if offset + 4 > len(data):
        raise ValueError("Schedule fork witness length is missing")
    fork_size = int.from_bytes(data[offset:offset + 4], "big")
    offset += 4
    fork_witness = data[offset:offset + fork_size]
    offset += fork_size
    if len(fork_witness) != fork_size or offset + 2 > len(data):
        raise ValueError("Schedule fork witness is truncated")
    header_size = int.from_bytes(data[offset:offset + 2], "big")
    offset += 2
    header = data[offset:offset + header_size]
    offset += header_size
    if len(header) != header_size:
        raise ValueError("Schedule carrier header is truncated")
    account, offset = _decode_schedule_mpt_path_v1(data, offset)
    header_path, offset = _decode_schedule_mpt_path_v1(data, offset)
    root_path, offset = _decode_schedule_mpt_path_v1(data, offset)
    cells: list[ScheduleRegistryCellWitnessV1] = []
    for _ in range(64):
        end = offset + SCHEDULE_REGISTRY_CELL_BYTES
        if end > len(data):
            raise ValueError("Schedule registry cell list is truncated")
        raw = data[offset:end]
        cell = ScheduleRegistryCellWitnessV1(
            raw[0], raw[1:21], int.from_bytes(raw[21:45], "big"),
            int.from_bytes(raw[45:53], "big"),
            int.from_bytes(raw[53:61], "big"), raw[61:93],
            int.from_bytes(raw[93:101], "big"),
        )
        cell.encode()
        cells.append(cell)
        offset = end
    records: list[ScheduleTrancheRecordWitnessV1] = []
    for _ in range(sum(cell.present for cell in cells)):
        end = offset + SCHEDULE_TRANCHE_RECORD_BYTES
        if end > len(data):
            raise ValueError("Schedule tranche records are truncated")
        raw = data[offset:end]
        record = ScheduleTrancheRecordWitnessV1(
            int.from_bytes(raw[0:8], "big"), raw[8],
            int.from_bytes(raw[9:33], "big"),
            int.from_bytes(raw[33:41], "big"),
            tuple(raw[index:index + 32] for index in range(41, 329, 32)),
        )
        record.encode()
        records.append(record)
        offset = end
    if offset != len(data):
        raise ValueError("Schedule seal witness has a suffix")
    witness = ScheduleSealWitnessV1(
        fork_witness, header, account, header_path, root_path,
        tuple(cells), tuple(records),
    )
    if witness.encode() != data:
        raise ValueError("Schedule seal witness is not canonical")
    return witness


def encode_schedule_window_return_v1(
    window: int, state: ScheduleReleaseState, entry_root: bytes, seed: bytes,
) -> bytes:
    if type(state) is not ScheduleReleaseState:
        raise ValueError("Schedule window state is invalid")
    if state is ScheduleReleaseState.SEALED:
        if entry_root == bytes(32) or seed == bytes(32):
            raise ValueError("SEALED Schedule window is empty")
    elif state is ScheduleReleaseState.VACANT:
        if entry_root != EMPTY_RANKED_ENTRY_ROOT or seed != bytes(32):
            raise ValueError("VACANT Schedule window projection is invalid")
    elif entry_root != bytes(32) or seed != bytes(32):
        raise ValueError("inactive Schedule window projection is nonzero")
    encoded = b"".join((
        SCHEDULE_WINDOW_MAGIC + bytes(28),
        _model_uint(window, 32, "Schedule window return window"),
        _model_uint(state.value, 32, "Schedule window return state"),
        _model_fixed_bytes32(entry_root), _model_fixed_bytes32(seed),
    ))
    if len(encoded) != 160:
        raise AssertionError("SWV1 return width drifted")
    return encoded


def encode_schedule_finalize_expiry_return_v1(
    first_expired_window: int,
    last_managed_window: int,
    next_release_window: int,
) -> bytes:
    if (type(first_expired_window) is not int
            or type(last_managed_window) is not int
            or type(next_release_window) is not int
            or not 0 <= first_expired_window <= last_managed_window
            <= LAST_FULL_SLOT_WINDOW
            or next_release_window != UINT64_MAX):
        raise ValueError("Schedule terminal return is invalid")
    encoded = b"".join((
        SCHEDULE_FINALIZE_EXPIRY_MAGIC + bytes(28),
        _model_uint(first_expired_window, 32,
                    "Schedule terminal first window"),
        _model_uint(last_managed_window, 32,
                    "Schedule terminal last window"),
        _model_uint(next_release_window, 32,
                    "Schedule terminal cursor"),
    ))
    if len(encoded) != 128:
        raise AssertionError("SWT1 return width drifted")
    return encoded


@dataclass
class ScheduleReleaseCursor:
    """Monotonic proof that pruned schedule-ring windows were once expired."""

    schedule_oracle: str = "schedule-oracle"
    genesis_timestamp: int = GENESIS_TIMESTAMP
    evidence_delay_seconds: int = EVIDENCE_DELAY_SECONDS
    reorg_margin_seconds: int = REORG_MARGIN_SECONDS
    first_managed_window: int = 0
    last_managed_window: int | None = None
    next_release_window: int | None = None
    sealed_entry_roots: dict[int, bytes] = field(default_factory=dict)
    sealed_seeds: dict[int, bytes] = field(default_factory=dict)
    objectively_vacant: set[int] = field(default_factory=set)

    def __post_init__(self) -> None:
        derived_last_managed_window = derive_last_managed_schedule_window(
            self.genesis_timestamp,
            self.evidence_delay_seconds,
            self.reorg_margin_seconds,
        )
        if self.last_managed_window is None:
            self.last_managed_window = derived_last_managed_window
        elif self.last_managed_window != derived_last_managed_window:
            raise ValueError("Schedule cursor terminal bound is inconsistent")
        if self.next_release_window is None:
            self.next_release_window = self.first_managed_window
        if (not self.schedule_oracle
                or type(self.first_managed_window) is not int
                or type(self.next_release_window) is not int
                or type(self.last_managed_window) is not int
                or not 0 <= self.first_managed_window
                <= self.last_managed_window <= LAST_FULL_SLOT_WINDOW
                or not (
                    self.first_managed_window <= self.next_release_window
                    <= self.last_managed_window
                    or self.next_release_window == UINT64_MAX
                )):
            raise ValueError("malformed schedule release cursor")

    def expire(self, window: int, *, releasable: bool) -> bool:
        assert self.last_managed_window is not None
        assert self.next_release_window is not None
        if (type(window) is not int or window != self.next_release_window
                or not releasable or window > self.last_managed_window):
            return False
        self.next_release_window = (
            UINT64_MAX
            if window == self.last_managed_window else window + 1
        )
        return True

    def release_state(
        self, window: int
    ) -> tuple[ScheduleReleaseState, bytes]:
        """Return the exact SWR1 state/root projection."""

        assert self.last_managed_window is not None
        assert self.next_release_window is not None
        if type(window) is not int or not 0 <= window <= UINT64_MAX:
            raise ValueError("release-state window is outside uint64")
        if (window < self.first_managed_window
                or window > self.last_managed_window):
            return ScheduleReleaseState.UNSEALED, bytes(32)
        if window < self.next_release_window:
            return ScheduleReleaseState.EXPIRED, bytes(32)
        root = self.sealed_entry_roots.get(window)
        if root is not None:
            if type(root) is not bytes or len(root) != 32 or root == bytes(32):
                raise ValueError("sealed entry root is malformed")
            return ScheduleReleaseState.SEALED, root
        if window in self.objectively_vacant:
            return ScheduleReleaseState.VACANT, EMPTY_RANKED_ENTRY_ROOT
        return ScheduleReleaseState.UNSEALED, bytes(32)

    def window_state(
        self, window: int,
    ) -> tuple[ScheduleReleaseState, bytes, bytes]:
        """Return the exact SWV1 state/root/seed projection."""

        state, root = self.release_state(window)
        if state is ScheduleReleaseState.SEALED:
            seed = self.sealed_seeds.get(window)
            if type(seed) is not bytes or len(seed) != 32 \
                    or seed == bytes(32):
                raise ValueError("sealed Schedule seed is malformed")
            return state, root, seed
        if state is ScheduleReleaseState.VACANT:
            return state, root, bytes(32)
        return state, bytes(32), bytes(32)

    def expire_batch(
        self,
        max_windows: int,
        authenticated_releasable: Callable[[int], bool],
    ) -> int:
        """Commit the maximal safe prefix; rollback on authentication faults."""

        if type(max_windows) is not int or not 1 <= max_windows <= 8:
            raise ValueError("schedule expiry batch is outside 1..8")
        if not callable(authenticated_releasable):
            raise ValueError("schedule release authenticator is absent")
        assert self.next_release_window is not None
        pre_cursor = self.next_release_window
        expired = 0
        try:
            while expired < max_windows:
                window = self.next_release_window
                if window == UINT64_MAX:
                    break
                state, _ = self.release_state(window)
                if state not in (
                    ScheduleReleaseState.SEALED,
                    ScheduleReleaseState.VACANT,
                ):
                    break
                if not authenticated_releasable(window):
                    break
                self.next_release_window = (
                    UINT64_MAX
                    if window == self.last_managed_window else window + 1
                )
                expired += 1
        except BaseException:
            self.next_release_window = pre_cursor
            raise
        return expired

    def finalize_expiry(
        self,
        now: int,
        expected_protocol_version: int,
        authenticated_terminal_state: Callable[[int], bytes],
    ) -> bool:
        """O(1) terminal jump justified by the last window's predicates.

        Window ends and replay deadlines are monotonic in W.  Therefore an
        authenticated proof that the final managed window is unreferenced and
        past its replay deadline simultaneously proves every earlier managed
        window safe, regardless of cursor-maintenance backlog.
        """

        assert self.last_managed_window is not None
        assert self.next_release_window is not None
        if (self.next_release_window == UINT64_MAX
                or type(now) is not int or now < 0
                or type(expected_protocol_version) is not int
                or not 0 < expected_protocol_version <= UINT64_MAX
                or not callable(authenticated_terminal_state)):
            return False
        replay_deadline = (
            self.genesis_timestamp
            + SCHEDULE_WINDOW_SLOTS * (self.last_managed_window + 1)
            + self.evidence_delay_seconds + self.reorg_margin_seconds
        )
        if now <= replay_deadline:
            return False
        pre_cursor = self.next_release_window
        try:
            raw = authenticated_terminal_state(self.last_managed_window)
            if type(raw) is not bytes or len(raw) != 160:
                raise ValueError("STS1 call envelope is noncanonical")
            words = tuple(raw[offset:offset + 32]
                          for offset in range(0, len(raw), 32))
            if words[0] != SETTLEMENT_SCHEDULE_TERMINAL_MAGIC + bytes(28):
                raise ValueError("STS1 magic is invalid")
            returned_window = _decode_uint_word_v1(
                words[1], 64, "STS1 returned window"
            )
            returned_version = _decode_uint_word_v1(
                words[2], 64, "STS1 protocol version"
            )
            capped_global_min = _decode_uint_word_v1(
                words[3], 64, "STS1 capped global minimum"
            )
            reference_mask = _decode_uint_word_v1(
                words[4], 8, "STS1 reference mask"
            )
            last_end = (
                SCHEDULE_WINDOW_SLOTS * (self.last_managed_window + 1) - 1
            )
            if (returned_window != self.last_managed_window
                    or returned_version != expected_protocol_version
                    or reference_mask != 0
                    or not last_end < capped_global_min):
                return False
            self.next_release_window = UINT64_MAX
            return True
        except BaseException:
            self.next_release_window = pre_cursor
            raise

    def is_expired(self, window: int) -> bool:
        assert self.last_managed_window is not None
        assert self.next_release_window is not None
        return (type(window) is int
                and self.first_managed_window <= window
                <= self.last_managed_window
                and (self.next_release_window == UINT64_MAX
                     or window < self.next_release_window))


def admission_move_proof_order(
    pre_root: bytes,
    *,
    liability_position: int,
    active_position: int,
    liability_proof_root: bytes,
    active_proof_root: bytes | None,
) -> tuple[bytes, bytes]:
    """Pin liability-first, active-second sequential admission proof roots."""

    if (type(pre_root) is not bytes or len(pre_root) != 32
            or type(liability_proof_root) is not bytes
            or len(liability_proof_root) != 32
            or liability_proof_root != pre_root
            or type(liability_position) is not int
            or not 64 <= liability_position < 64 + MAX_LIABILITY_GENERATIONS
            or type(active_position) is not int
            or not 0 <= active_position < 64):
        raise ValueError("malformed liability-first admission proof")
    intermediate = keccak256(
        b"slot-chain-admission-move-liability-v1"
        + pre_root
        + liability_position.to_bytes(2, "big")
    )
    if active_proof_root is not None and active_proof_root != intermediate:
        raise ValueError("active proof is not anchored to liability post-root")
    final = keccak256(
        b"slot-chain-admission-move-active-v1"
        + intermediate
        + active_position.to_bytes(1, "big")
    )
    return intermediate, final


@dataclass
class RegistryLifecycle:
    active: list[Generation | None]
    registry_address: str = "builder-registry"
    settlement_chain_id: int = 1
    schedule_oracle: str = "schedule-oracle"
    genesis_timestamp: int = GENESIS_TIMESTAMP
    evidence_delay_seconds: int = EVIDENCE_DELAY_SECONDS
    reorg_margin_seconds: int = REORG_MARGIN_SECONDS
    first_managed_window: int = 0
    last_managed_window: int | None = None
    liability_ring: list[tuple[Generation, int] | None] = field(
        default_factory=lambda: [None] * MAX_LIABILITY_GENERATIONS)
    replacements: dict[int, int] = field(default_factory=dict)
    movement_sequence: int = 0
    open_reservations: set[tuple[int, int]] = field(default_factory=set)
    liable_reservations: set[tuple[int, int]] = field(default_factory=set)
    lease_per_window_atomic: int = 1
    maximum_bond_atomic: int = (1 << 192) - 1
    penalty_sink: str = "builder-penalty-sink"
    tranches: dict[tuple[int, int], TrancheLifecycle] = field(
        default_factory=dict)
    tranche_ring_windows: dict[tuple[int, int], int] = field(
        default_factory=dict)
    credits: dict[str, int] = field(default_factory=dict)
    total_credit_liability: int = field(default=0, init=False)
    base_bond_escrow: int = 0
    tranche_escrow: int = 0
    token_balance: int = 0
    exit_requests: dict[int, BuilderExitRequest] = field(default_factory=dict)
    exit_by_registration: dict[int, int] = field(default_factory=dict)
    next_exit_sequence: int = 0
    exit_head_sequence: int = 0
    next_registration_index: int | None = None
    generation_locations: dict[int, tuple[str, int]] = field(
        default_factory=dict, init=False)
    live_registration_index_plus_one: dict[str, int] = field(
        default_factory=dict, init=False)
    lifecycle_fault_point: str | None = field(
        default=None, compare=False, repr=False)

    def __post_init__(self) -> None:
        derived_last_managed_window = derive_last_managed_schedule_window(
            self.genesis_timestamp,
            self.evidence_delay_seconds,
            self.reorg_margin_seconds,
        )
        if self.last_managed_window is None:
            self.last_managed_window = derived_last_managed_window
        elif self.last_managed_window != derived_last_managed_window:
            raise ValueError("Builder last managed window is inconsistent")
        if (not self.registry_address
                or type(self.settlement_chain_id) is not int
                or self.settlement_chain_id <= 0
                or not self.schedule_oracle
                or not self.penalty_sink
                or self.penalty_sink == self.registry_address
                or type(self.first_managed_window) is not int
                or not 0 <= self.first_managed_window
                <= self.last_managed_window
                or maximum_liability_residence_windows_v1(
                    self.evidence_delay_seconds, self.reorg_margin_seconds
                ) >= MAX_LIVE_WINDOWS
                or len(self.active) > 64
                or len(self.liability_ring) != MAX_LIABILITY_GENERATIONS
                or type(self.lease_per_window_atomic) is not int
                or self.lease_per_window_atomic <= 0
                or type(self.maximum_bond_atomic) is not int
                or not self.lease_per_window_atomic
                <= self.maximum_bond_atomic < 1 << 192):
            raise ValueError("malformed BuilderRegistry geometry")
        seen_addresses: set[str] = set()
        seen_registrations: set[int] = set()
        generation_locations: dict[int, tuple[str, int]] = {}
        live_registration_index_plus_one: dict[str, int] = {}
        for index, generation in enumerate(self.active):
            if generation is None:
                continue
            if (generation.address in seen_addresses
                    or generation.registration_index in seen_registrations
                    or not 0 <= generation.registration_index <= UINT64_MAX
                    or not self.lease_per_window_atomic
                    <= generation.bond <= self.maximum_bond_atomic):
                raise ValueError("duplicate or malformed active generation")
            seen_addresses.add(generation.address)
            seen_registrations.add(generation.registration_index)
            generation_locations[generation.registration_index] = (
                "ACTIVE", index
            )
            live_registration_index_plus_one[generation.address] = (
                generation.registration_index + 1
            )
        for index, occupant in enumerate(self.liability_ring):
            if occupant is None:
                continue
            generation = occupant[0]
            if (generation.address in seen_addresses
                    or generation.registration_index in seen_registrations
                    or not 0 <= generation.registration_index <= UINT64_MAX
                    or not self.lease_per_window_atomic
                    <= generation.bond <= self.maximum_bond_atomic):
                raise ValueError("duplicate or malformed liability generation")
            seen_addresses.add(generation.address)
            seen_registrations.add(generation.registration_index)
            generation_locations[generation.registration_index] = (
                "LIABILITY", index
            )
            # This is a uint256-style plus-one sentinel.  In particular,
            # uint64.max is live as uint64.max+1 rather than wrapping to zero.
            live_registration_index_plus_one[generation.address] = (
                generation.registration_index + 1
            )
        self.active.extend([None] * (64 - len(self.active)))
        derived_next_registration_index = (
            0 if not seen_registrations else max(seen_registrations) + 1
        )
        if self.next_registration_index is None:
            self.next_registration_index = derived_next_registration_index
        elif (type(self.next_registration_index) is not int
              or self.next_registration_index < derived_next_registration_index
              or not 0 <= self.next_registration_index <= UINT64_MAX + 1):
            raise ValueError("malformed next registration index")
        self.generation_locations = generation_locations
        self.live_registration_index_plus_one = (
            live_registration_index_plus_one
        )
        initial_base = sum(
            generation.bond for generation in self.active
            if generation is not None
        ) + sum(
            occupant[0].bond for occupant in self.liability_ring
            if occupant is not None
        )
        if any((self.base_bond_escrow, self.tranche_escrow,
                self.token_balance, self.credits)):
            raise ValueError("custom initial custody is not canonical")
        self.base_bond_escrow = initial_base
        self.token_balance = initial_base
        self.assert_custody_conservation()
        self.audit_lifecycle_invariants()

    @property
    def active_count(self) -> int:
        return sum(generation is not None for generation in self.active)

    @property
    def liabilities(self) -> list[Generation]:
        return [item[0] for item in self.liability_ring if item is not None]

    @property
    def accounted_builder_token(self) -> int:
        return (self.base_bond_escrow + self.tranche_escrow
                + self.total_credit_liability)

    def assert_custody_conservation(self) -> None:
        if (min(self.base_bond_escrow, self.tranche_escrow,
                self.token_balance, self.total_credit_liability) < 0
                or self.accounted_builder_token > self.token_balance):
            raise AssertionError("builder-token custody is not conserved")

    def audit_lifecycle_invariants(self) -> None:
        """Expensive model-only recount; no production transition calls it."""

        expected_locations: dict[int, tuple[str, int]] = {}
        expected_live: dict[str, int] = {}
        generations: dict[int, Generation] = {}
        for index, generation in enumerate(self.active):
            if generation is None:
                continue
            if (generation.registration_index in expected_locations
                    or generation.address in expected_live):
                raise AssertionError("active generation index is duplicated")
            expected_locations[generation.registration_index] = (
                "ACTIVE", index
            )
            expected_live[generation.address] = (
                generation.registration_index + 1
            )
            generations[generation.registration_index] = generation
        for index, occupant in enumerate(self.liability_ring):
            if occupant is None:
                continue
            generation = occupant[0]
            if (generation.registration_index in expected_locations
                    or generation.address in expected_live):
                raise AssertionError("liability generation index is duplicated")
            expected_locations[generation.registration_index] = (
                "LIABILITY", index
            )
            expected_live[generation.address] = (
                generation.registration_index + 1
            )
            generations[generation.registration_index] = generation
        if (self.generation_locations != expected_locations
                or self.live_registration_index_plus_one != expected_live):
            raise AssertionError("generation reverse index is inconsistent")
        live_tranche_counts = {registration_index: 0
                               for registration_index in generations}
        expected_open: set[tuple[int, int]] = set()
        expected_liable: set[tuple[int, int]] = set()
        for key, tranche in self.tranches.items():
            registration_index, window = key
            if tranche.state is TrancheState.RESERVED:
                expected_open.add(key)
                live_tranche_counts[registration_index] = (
                    live_tranche_counts.get(registration_index, 0) + 1
                )
            elif tranche.state is TrancheState.LIABLE:
                expected_liable.add(key)
                live_tranche_counts[registration_index] = (
                    live_tranche_counts.get(registration_index, 0) + 1
                )
            if tranche.window != window:
                raise AssertionError("tranche key/window is inconsistent")
        if (self.open_reservations != expected_open
                or self.liable_reservations != expected_liable):
            raise AssertionError("reservation state index is inconsistent")
        for registration_index, generation in generations.items():
            if (generation.unreleased_tranche_count
                    != live_tranche_counts.get(registration_index, 0)):
                raise AssertionError("unreleased tranche counter is inconsistent")
            if generation.reservation_bitmap >> (
                    MAX_TRANCHE_AHEAD_WINDOWS + 1):
                raise AssertionError("reservation bitmap exceeds 17 bits")
            expected_bitmap = 0
            if expected_locations[registration_index][0] == "ACTIVE":
                for key in expected_open:
                    if key[0] != registration_index:
                        continue
                    offset = key[1] - generation.reservation_base_window
                    if not 0 <= offset <= MAX_TRANCHE_AHEAD_WINDOWS:
                        raise AssertionError(
                            "open reservation escaped generation bitmap"
                        )
                    expected_bitmap |= 1 << offset
            if generation.reservation_bitmap != expected_bitmap:
                raise AssertionError("reservation bitmap is inconsistent")
        if (any(type(amount) is not int or amount < 0
                for amount in self.credits.values())
                or sum(self.credits.values()) != self.total_credit_liability):
            raise AssertionError("builder pull-credit total is inconsistent")
        self.assert_custody_conservation()

    def moves_used(self, current_window: int) -> int:
        return self.replacements.get(current_window, 0)

    def _schedule_cursor_matches(
        self, schedule_cursor: ScheduleReleaseCursor,
    ) -> bool:
        return (
            type(schedule_cursor) is ScheduleReleaseCursor
            and schedule_cursor.schedule_oracle == self.schedule_oracle
            and schedule_cursor.genesis_timestamp == self.genesis_timestamp
            and schedule_cursor.evidence_delay_seconds
            == self.evidence_delay_seconds
            and schedule_cursor.reorg_margin_seconds
            == self.reorg_margin_seconds
            and schedule_cursor.first_managed_window
            == self.first_managed_window
            and schedule_cursor.last_managed_window
            == self.last_managed_window
        )

    def tranche_deadline(self, window: int) -> int:
        assert self.last_managed_window is not None
        if (type(window) is not int
                or not self.first_managed_window
                <= window <= self.last_managed_window):
            raise ValueError("tranche window is outside uint64")
        deadline = (
            self.genesis_timestamp + SCHEDULE_WINDOW_SLOTS * (window + 1)
            + self.evidence_delay_seconds + self.reorg_margin_seconds
        )
        if deadline > UINT64_MAX:
            raise ValueError("tranche deadline overflows uint64")
        return deadline

    def tranche_state(self, registration_index: int,
                      window: int) -> TrancheState:
        tranche = self.tranches.get((registration_index, window))
        return TrancheState.EMPTY if tranche is None else tranche.state

    def tranche_ring_window(self, registration_index: int,
                            window: int) -> int | None:
        return self.tranche_ring_windows.get(
            (registration_index, window % 512))

    def _active_index(self, *, address: str | None = None,
                      registration_index: int | None = None) -> int | None:
        if address is None and registration_index is None:
            raise ValueError("active generation lookup has no key")
        if address is not None:
            plus_one = self.live_registration_index_plus_one.get(address, 0)
            if plus_one == 0:
                return None
            indexed_registration = plus_one - 1
            if (not 0 <= indexed_registration <= UINT64_MAX
                    or (registration_index is not None
                        and registration_index != indexed_registration)):
                raise AssertionError("live builder reverse index is malformed")
            registration_index = indexed_registration
        assert registration_index is not None
        location = self._generation_location(registration_index)
        if location is None or location[0] != "ACTIVE":
            return None
        if address is not None and location[2].address != address:
            raise AssertionError("live builder reverse index selects another builder")
        return location[1]

    def _generation_location(
        self, registration_index: int,
    ) -> tuple[str, int, Generation] | None:
        locator = self.generation_locations.get(registration_index)
        if locator is None:
            return None
        if type(locator) is not tuple or len(locator) != 2:
            raise AssertionError("generation locator is malformed")
        location, index = locator
        if location == "ACTIVE" and 0 <= index < MAX_BUILDERS:
            generation = self.active[index]
        elif (location == "LIABILITY"
              and 0 <= index < MAX_LIABILITY_GENERATIONS):
            occupant = self.liability_ring[index]
            generation = None if occupant is None else occupant[0]
        else:
            raise AssertionError("generation locator position is malformed")
        if (generation is None
                or generation.registration_index != registration_index
                or self.live_registration_index_plus_one.get(
                    generation.address, 0
                ) != registration_index + 1):
            raise AssertionError("generation locator does not match occupancy")
        return location, index, generation

    def _index_new_generation(
        self, generation: Generation, location: str, index: int,
    ) -> None:
        if (generation.registration_index in self.generation_locations
                or generation.address in self.live_registration_index_plus_one):
            raise AssertionError("generation is already live")
        self.generation_locations[generation.registration_index] = (
            location, index
        )
        self.live_registration_index_plus_one[generation.address] = (
            generation.registration_index + 1
        )

    def _move_generation_index(
        self, generation: Generation, *, old: tuple[str, int],
        new: tuple[str, int],
    ) -> None:
        if (self.generation_locations.get(generation.registration_index) != old
                or self.live_registration_index_plus_one.get(
                    generation.address, 0
                ) != generation.registration_index + 1):
            raise AssertionError("generation move index prestate is inconsistent")
        self.generation_locations[generation.registration_index] = new

    def _clear_generation_index(
        self, generation: Generation, *, expected: tuple[str, int],
    ) -> None:
        if (self.generation_locations.get(generation.registration_index)
                != expected
                or self.live_registration_index_plus_one.get(
                    generation.address, 0
                ) != generation.registration_index + 1):
            raise AssertionError("generation clear index prestate is inconsistent")
        del self.generation_locations[generation.registration_index]
        del self.live_registration_index_plus_one[generation.address]

    def _write_generation(self, location: str, index: int,
                          generation: Generation) -> None:
        if location == "ACTIVE":
            self.active[index] = generation
        else:
            occupant = self.liability_ring[index]
            assert occupant is not None
            self.liability_ring[index] = (generation, occupant[1])

    def _credit(self, beneficiary: str, amount: int) -> None:
        if not beneficiary or amount < 0:
            raise ValueError("malformed builder-token credit")
        if amount:
            self.credits[beneficiary] = self.credits.get(beneficiary, 0) + amount
            self.total_credit_liability += amount

    def claim_credit(self, owner: str, recipient: str, *, caller: str) -> int:
        if caller != owner or not recipient:
            raise ValueError("builder-token credit claim lacks self-consent")
        amount = self.credits.get(owner, 0)
        if amount == 0:
            raise ValueError("builder-token credit is empty")
        del self.credits[owner]
        self.total_credit_liability -= amount
        self.token_balance -= amount
        self.assert_custody_conservation()
        return amount

    def force_token_surplus(self, amount: int) -> None:
        if type(amount) is not int or amount < 0:
            raise ValueError("malformed forced builder-token surplus")
        self.token_balance += amount
        self.assert_custody_conservation()

    @staticmethod
    def _bitmap_offsets(bitmap: int) -> tuple[int, ...]:
        if (type(bitmap) is not int or bitmap < 0
                or bitmap >> (MAX_TRANCHE_AHEAD_WINDOWS + 1)):
            raise AssertionError("reservation bitmap exceeds 17 bits")
        offsets: list[int] = []
        while bitmap:
            lowest = bitmap & -bitmap
            offsets.append(lowest.bit_length() - 1)
            bitmap ^= lowest
        return tuple(offsets)

    def _reservation_keys_for_mask(
        self, generation: Generation, mask: int,
    ) -> tuple[tuple[int, int], ...]:
        keys = tuple(
            (generation.registration_index,
             generation.reservation_base_window + offset)
            for offset in self._bitmap_offsets(mask)
        )
        for key in keys:
            tranche = self.tranches.get(key)
            if (key not in self.open_reservations
                    or tranche is None
                    or tranche.state is not TrancheState.RESERVED):
                raise AssertionError(
                    "reservation bitmap does not select a RESERVED tranche"
                )
        return keys

    def normalize_reservations(
        self,
        registration_index: int,
        current_window: int,
        schedule_cursor: ScheduleReleaseCursor | None = None,
    ) -> int:
        """Bound one generation's RESERVED->LIABLE normalization to 17 leaves.

        Normalization never releases escrow.  Only ``release_tranche`` with an
        authenticated schedule-release cursor and strict timestamp may create
        a builder credit.
        """

        location = self._generation_location(registration_index)
        if (location is None or location[0] != "ACTIVE"
                or type(current_window) is not int or current_window < 0):
            return 0
        assert self.last_managed_window is not None
        if current_window > self.last_managed_window:
            # The ordinary path stores ``current_window`` as a uint64 bitmap
            # base.  Once the finite schedule has ended, never narrow an
            # arbitrarily late wall-clock window.  The terminal cursor proves
            # every possible reservation is stale; close all represented
            # leaves and retain the already-representable bitmap base.
            if (schedule_cursor is None
                    or not self._schedule_cursor_matches(schedule_cursor)
                    or schedule_cursor.next_release_window != UINT64_MAX):
                return 0
            generation = location[2]
            closed = self._move_reservations_to_liability(
                generation
            )
            self.active[location[1]] = replace(
                generation,
                reservation_bitmap=0,
            )
            return closed
        generation = location[2]
        if current_window < generation.reservation_base_window:
            raise AssertionError("reservation bitmap base moved backward")
        shift = current_window - generation.reservation_base_window
        expired_mask = (
            generation.reservation_bitmap
            if shift > MAX_TRANCHE_AHEAD_WINDOWS
            else generation.reservation_bitmap & ((1 << shift) - 1)
        )
        expired = self._reservation_keys_for_mask(generation, expired_mask)
        for key in expired:
            self.open_reservations.remove(key)
            self.liable_reservations.add(key)
            tranche = self.tranches.get(key)
            assert tranche is not None
            self.tranches[key] = replace(
                tranche, state=TrancheState.LIABLE)
        bitmap = (0 if shift > MAX_TRANCHE_AHEAD_WINDOWS
                  else generation.reservation_bitmap >> shift)
        self.active[location[1]] = replace(
            generation,
            reservation_base_window=current_window,
            reservation_bitmap=bitmap,
        )
        return len(expired)

    def reserve(self, address: str, window: int, current_window: int,
                *, caller: str | None = None) -> bool:
        assert self.last_managed_window is not None
        if (type(window) is not int
                or type(current_window) is not int
                or window < current_window
                or window < self.first_managed_window
                or window > current_window + MAX_TRANCHE_AHEAD_WINDOWS
                or window > self.last_managed_window):
            return False
        caller = address if caller is None else caller
        if caller != address:
            return False
        index = self._active_index(address=address)
        if index is None:
            return False
        generation = self.active[index]
        assert generation is not None
        if (generation.reservations_closed
                or generation.tombstoned_at_l2_slot != UINT64_MAX):
            return False
        self.normalize_reservations(
            generation.registration_index, current_window)
        generation = self.active[index]
        assert generation is not None
        key = (generation.registration_index, window)
        existing = self.tranches.get(key)
        if existing is not None and existing.state is TrancheState.RESERVED:
            offset = window - generation.reservation_base_window
            if (not 0 <= offset <= MAX_TRANCHE_AHEAD_WINDOWS
                    or not generation.reservation_bitmap & (1 << offset)
                    or key not in self.open_reservations):
                raise AssertionError("idempotent reservation is not indexed")
            return True
        old_window = self.tranche_ring_windows.get(
            (generation.registration_index, window % 512))
        if old_window == window:
            return False
        if old_window is not None:
            old = self.tranches[(generation.registration_index, old_window)]
            if not (old_window < window and old.state in {
                    TrancheState.RELEASED, TrancheState.SLASHED}):
                return False
        liable_until = self.tranche_deadline(window)
        self.tranches[key] = TrancheLifecycle(
            window, TrancheState.RESERVED,
            self.lease_per_window_atomic, liable_until,
        )
        self.tranche_ring_windows[
            (generation.registration_index, window % 512)] = window
        self.open_reservations.add(key)
        self.tranche_escrow += self.lease_per_window_atomic
        self.token_balance += self.lease_per_window_atomic
        generation = replace(
            generation,
            max_reserved_window=max(generation.max_reserved_window, window),
            reservation_bitmap=(
                generation.reservation_bitmap
                | (1 << (window - generation.reservation_base_window))
            ),
            unreleased_tranche_count=generation.unreleased_tranche_count + 1,
            maximum_liable_until=max(
                generation.maximum_liable_until, liable_until),
        )
        self.active[index] = generation
        assert len(self.open_reservations) <= MAX_LIVE_RESERVATIONS
        self.assert_custody_conservation()
        return True

    def _move_reservations_to_liability(self, generation: Generation) -> int:
        moved = self._reservation_keys_for_mask(
            generation, generation.reservation_bitmap
        )
        for key in moved:
            self.open_reservations.remove(key)
            self.liable_reservations.add(key)
            tranche = self.tranches[key]
            self.tranches[key] = replace(
                tranche, state=TrancheState.LIABLE)
        return len(moved)

    @staticmethod
    def _key_snapshot(mapping: dict, keys: tuple[object, ...]) -> dict:
        return {
            key: (key in mapping, copy.deepcopy(mapping.get(key)))
            for key in keys
        }

    @staticmethod
    def _restore_key_snapshot(mapping: dict, snapshot: dict) -> None:
        for key, (present, value) in snapshot.items():
            if present:
                mapping[key] = value
            else:
                mapping.pop(key, None)

    def _bounded_lifecycle_snapshot(
        self, *, generations: tuple[Generation, ...] = (),
        active_indices: tuple[int, ...] = (),
        liability_indices: tuple[int, ...] = (),
        reservation_keys: tuple[tuple[int, int], ...] = (),
        credit_owners: tuple[str, ...] = (),
        replacement_windows: tuple[int, ...] = (),
    ) -> dict[str, object]:
        """Capture only cells and reverse-index keys one transition can touch."""

        registrations = tuple(dict.fromkeys(
            generation.registration_index for generation in generations
        ))
        builders = tuple(dict.fromkeys(
            generation.address for generation in generations
        ))
        exit_sequences = tuple(dict.fromkeys(
            sequence
            for registration_index in registrations
            for sequence in (self.exit_by_registration.get(registration_index),)
            if sequence is not None
        ))
        return {
            "active": {index: self.active[index] for index in active_indices},
            "liability": {
                index: self.liability_ring[index] for index in liability_indices
            },
            "locations": self._key_snapshot(
                self.generation_locations, registrations
            ),
            "live": self._key_snapshot(
                self.live_registration_index_plus_one, builders
            ),
            "tranches": self._key_snapshot(self.tranches, reservation_keys),
            "open": {key: key in self.open_reservations
                     for key in reservation_keys},
            "liable": {key: key in self.liable_reservations
                       for key in reservation_keys},
            "credits": self._key_snapshot(
                self.credits, tuple(dict.fromkeys(credit_owners))
            ),
            "exit_requests": self._key_snapshot(
                self.exit_requests, exit_sequences
            ),
            "replacements": self._key_snapshot(
                self.replacements, replacement_windows
            ),
            "scalars": (
                self.movement_sequence, self.base_bond_escrow,
                self.tranche_escrow, self.token_balance,
                self.total_credit_liability,
            ),
        }

    def _restore_bounded_lifecycle_snapshot(
        self, snapshot: dict[str, object],
    ) -> None:
        for index, generation in snapshot["active"].items():
            self.active[index] = generation
        for index, occupant in snapshot["liability"].items():
            self.liability_ring[index] = occupant
        self._restore_key_snapshot(
            self.generation_locations, snapshot["locations"]
        )
        self._restore_key_snapshot(
            self.live_registration_index_plus_one, snapshot["live"]
        )
        self._restore_key_snapshot(self.tranches, snapshot["tranches"])
        for key, present in snapshot["open"].items():
            if present:
                self.open_reservations.add(key)
            else:
                self.open_reservations.discard(key)
        for key, present in snapshot["liable"].items():
            if present:
                self.liable_reservations.add(key)
            else:
                self.liable_reservations.discard(key)
        self._restore_key_snapshot(self.credits, snapshot["credits"])
        self._restore_key_snapshot(
            self.exit_requests, snapshot["exit_requests"]
        )
        self._restore_key_snapshot(
            self.replacements, snapshot["replacements"]
        )
        (self.movement_sequence, self.base_bond_escrow,
         self.tranche_escrow, self.token_balance,
         self.total_credit_liability) = snapshot["scalars"]

    def release_liability(
        self,
        ring_index: int,
        current_window: int,
        *,
        now: int | None = None,
        schedule_cursor: ScheduleReleaseCursor | None = None,
    ) -> bool:
        if not 0 <= ring_index < MAX_LIABILITY_GENERATIONS:
            return False
        occupant = self.liability_ring[ring_index]
        if occupant is None:
            return False
        assert self.last_managed_window is not None
        terminal_release = (
            schedule_cursor is not None
            and self._schedule_cursor_matches(schedule_cursor)
            and schedule_cursor.next_release_window == UINT64_MAX
            and type(now) is int
            and occupant[0].maximum_liable_until < now
        )
        if occupant[1] > current_window and not terminal_release:
            return False
        registration_index = occupant[0].registration_index
        if occupant[0].unreleased_tranche_count != 0:
            return False
        generation = occupant[0]
        snapshot = self._bounded_lifecycle_snapshot(
            generations=(generation,), liability_indices=(ring_index,),
            credit_owners=(generation.address,),
        )
        try:
            self.base_bond_escrow -= generation.bond
            self._credit(generation.address, generation.bond)
            self.liability_ring[ring_index] = None
            self._clear_generation_index(
                generation, expected=("LIABILITY", ring_index)
            )
            if self.lifecycle_fault_point == "after_generation_clear_index":
                raise RuntimeError("injected generation clear-index fault")
            self._mark_exit_resolved(registration_index)
            self.assert_custody_conservation()
            return True
        except BaseException:
            self._restore_bounded_lifecycle_snapshot(snapshot)
            raise

    def _mark_exit_resolved(self, registration_index: int) -> None:
        sequence = self.exit_by_registration.get(registration_index)
        if sequence is not None and sequence in self.exit_requests:
            self.exit_requests[sequence].resolved = True

    def _move_active_to_liability(
        self,
        active_index: int,
        current_window: int,
        current_l2_slot: int,
        replacement: Generation | None,
    ) -> bool:
        if self.moves_used(current_window) >= MAX_REPLACEMENTS_PER_WINDOW:
            return False
        victim = self.active[active_index]
        if victim is None:
            return False
        ring_index = self.movement_sequence % MAX_LIABILITY_GENERATIONS
        prior_occupant = self.liability_ring[ring_index]
        prior_generation = (
            None if prior_occupant is None else prior_occupant[0]
        )
        generations = tuple(
            generation for generation in (
                victim, replacement, prior_generation
            ) if generation is not None
        )
        reservation_keys = self._reservation_keys_for_mask(
            victim, victim.reservation_bitmap
        )
        snapshot = self._bounded_lifecycle_snapshot(
            generations=generations,
            active_indices=(active_index,),
            liability_indices=(ring_index,),
            reservation_keys=reservation_keys,
            credit_owners=(
                () if prior_generation is None
                else (prior_generation.address,)
            ),
            replacement_windows=(current_window,),
        )
        try:
            if (prior_occupant is not None
                    and not self.release_liability(
                        ring_index, current_window
                    )):
                return False
            self._move_reservations_to_liability(victim)
            retained = replace(
                victim,
                reservations_closed=True,
                reservation_base_window=current_window,
                reservation_bitmap=0,
            )
            release_window = (
                victim.max_reserved_window + 1
                + (
                    self.evidence_delay_seconds + self.reorg_margin_seconds
                    + SCHEDULE_WINDOW_SLOTS - 1
                ) // SCHEDULE_WINDOW_SLOTS + 2
            )
            if release_window > UINT64_MAX:
                raise OverflowError("liability release window overflows uint64")
            self.liability_ring[ring_index] = (retained, release_window)
            self.active[active_index] = replacement
            self._move_generation_index(
                victim, old=("ACTIVE", active_index),
                new=("LIABILITY", ring_index),
            )
            if replacement is not None:
                self._index_new_generation(
                    replacement, "ACTIVE", active_index
                )
            if self.lifecycle_fault_point == "after_generation_move_index":
                raise RuntimeError("injected generation move-index fault")
            self.movement_sequence += 1
            self.replacements[current_window] = (
                self.moves_used(current_window) + 1
            )
            self._mark_exit_resolved(victim.registration_index)
            return True
        except BaseException:
            self._restore_bounded_lifecycle_snapshot(snapshot)
            raise

    def _mature_live_exit_pending(
        self, current_window: int, max_inspections: int = 64,
    ) -> bool:
        sequence = self.exit_head_sequence
        inspected = 0
        while (sequence < self.next_exit_sequence
               and inspected < max_inspections):
            request = self.exit_requests.get(sequence)
            inspected += 1
            if request is None or request.resolved:
                sequence += 1
                continue
            location = self._generation_location(request.registration_index)
            if location is None or location[0] != "ACTIVE":
                sequence += 1
                continue
            return request.mature_window <= current_window
        # A registration never scans a 65th record.  It conservatively requires
        # bounded maintenance even if that unseen record might already be
        # resolved, so adversarial churn cannot make admission unbounded.
        return sequence < self.next_exit_sequence

    def admit(self, entry: Generation, current_window: int, *,
              caller: str | None = None,
              current_l2_slot: int | None = None) -> bool:
        caller = entry.address if caller is None else caller
        current_l2_slot = (current_window * 384 if current_l2_slot is None
                           else current_l2_slot)
        assert self.next_registration_index is not None
        assert self.last_managed_window is not None
        if (caller != entry.address or entry.address == ""
                or not self.lease_per_window_atomic <= entry.bond
                <= self.maximum_bond_atomic
                or self.next_registration_index > UINT64_MAX
                or entry.registration_index != self.next_registration_index
                or not 0 <= current_l2_slot <= UINT64_MAX
                or entry.address in self.live_registration_index_plus_one):
            return False
        effective_l2_slot = current_l2_slot + ENTRY_DELAY_WINDOWS * 384
        if (effective_l2_slot > UINT64_MAX
                or effective_l2_slot // SCHEDULE_WINDOW_SLOTS
                > self.last_managed_window):
            return False
        entry = replace(
            entry,
            effective_window=effective_l2_slot // 384,
            effective_l2_slot=effective_l2_slot,
            max_reserved_window=0,
            reservations_closed=False,
            tombstoned_at_l2_slot=UINT64_MAX,
            reservation_base_window=current_window,
            reservation_bitmap=0,
            unreleased_tranche_count=0,
            maximum_liable_until=0,
            exit_sequence=None,
        )
        vacant_index = next(
            (index for index, generation in enumerate(self.active)
             if generation is None), None)
        if vacant_index is not None:
            self.active[vacant_index] = entry
            self._index_new_generation(entry, "ACTIVE", vacant_index)
            self.base_bond_escrow += entry.bond
            self.token_balance += entry.bond
            self.next_registration_index += 1
            self.assert_custody_conservation()
            return True
        if (self.moves_used(current_window) >= MAX_REPLACEMENTS_PER_WINDOW
                or self._mature_live_exit_pending(current_window)
                or any(g is not None
                       and g.tombstoned_at_l2_slot != UINT64_MAX
                       for g in self.active)):
            return False
        candidates = [
            (index, generation) for index, generation in enumerate(self.active)
            if (generation is not None
                and generation.tombstoned_at_l2_slot == UINT64_MAX)
        ]
        if not candidates:
            return False
        victim_index, victim = min(
            candidates,
            key=lambda item: (item[1].bond, -item[1].registration_index),
        )
        if entry.bond <= victim.bond:
            return False
        if victim.max_reserved_window > current_window + MAX_TRANCHE_AHEAD_WINDOWS:
            return False
        if not self._move_active_to_liability(
                victim_index, current_window, current_l2_slot, entry):
            return False
        self.base_bond_escrow += entry.bond
        self.token_balance += entry.bond
        self.next_registration_index += 1
        self.assert_custody_conservation()
        return True

    def request_exit(self, address: str, current_window: int, *,
                     caller: str | None = None) -> bool:
        assert self.last_managed_window is not None
        caller = address if caller is None else caller
        index = self._active_index(address=address)
        if (caller != address or index is None
                or current_window > self.last_managed_window):
            return False
        generation = self.active[index]
        assert generation is not None
        if (generation.reservations_closed
                or generation.tombstoned_at_l2_slot != UINT64_MAX
                or generation.registration_index in self.exit_by_registration
                or self.next_exit_sequence == UINT64_MAX):
            return False
        sequence = self.next_exit_sequence
        mature_window = current_window + MAX_LIVE_WINDOWS
        if mature_window > UINT64_MAX:
            return False
        self.next_exit_sequence += 1
        self.exit_requests[sequence] = BuilderExitRequest(
            sequence, generation.registration_index,
            current_window, mature_window,
        )
        self.exit_by_registration[generation.registration_index] = sequence
        self.active[index] = replace(
            generation, reservations_closed=True, exit_sequence=sequence)
        return True

    def process_maintenance(
        self,
        current_window: int,
        *,
        current_l2_slot: int,
        max_inspections: int = 64,
    ) -> tuple[int, int]:
        assert self.last_managed_window is not None
        if (type(max_inspections) is not int
                or not 0 <= max_inspections <= 64):
            raise ValueError("exit inspection bound is outside 0..64")
        # Once every managed Schedule window is globally expired, active
        # generations use the collision-free terminal close/release path
        # below.  Ordinary movement into the liability ring is then disabled.
        if current_window > self.last_managed_window:
            return 0, 0
        inspected = 0
        moved = 0
        while (self.exit_head_sequence < self.next_exit_sequence
               and inspected < max_inspections):
            request = self.exit_requests.get(self.exit_head_sequence)
            inspected += 1
            if request is None or request.resolved:
                self.exit_head_sequence += 1
                continue
            location = self._generation_location(request.registration_index)
            if location is None or location[0] != "ACTIVE":
                request.resolved = True
                self.exit_head_sequence += 1
                continue
            if request.mature_window > current_window:
                break
            if not self._move_active_to_liability(
                    location[1], current_window, current_l2_slot, None):
                break
            request.resolved = True
            self.exit_head_sequence += 1
            moved += 1
        if self._mature_live_exit_pending(current_window):
            return inspected, moved
        while self.moves_used(current_window) < MAX_REPLACEMENTS_PER_WINDOW:
            tombstones = [
                (generation.tombstoned_at_l2_slot,
                 generation.registration_index, index)
                for index, generation in enumerate(self.active)
                if generation is not None
                and generation.tombstoned_at_l2_slot != UINT64_MAX
            ]
            if not tombstones:
                break
            _, _, index = min(tombstones)
            if not self._move_active_to_liability(
                    index, current_window, current_l2_slot, None):
                break
            moved += 1
        return inspected, moved

    def release_terminal_active(
        self,
        active_index: int,
        now: int,
        schedule_cursor: ScheduleReleaseCursor,
    ) -> bool:
        """Release one fully terminal active generation without ring movement."""

        assert self.last_managed_window is not None
        if (not 0 <= active_index < MAX_BUILDERS
                or type(now) is not int or now < 0
                or not self._schedule_cursor_matches(schedule_cursor)
                or schedule_cursor.next_release_window != UINT64_MAX):
            return False
        generation = self.active[active_index]
        if (generation is None
                or generation.unreleased_tranche_count != 0
                or now <= generation.maximum_liable_until):
            return False
        snapshot = self._bounded_lifecycle_snapshot(
            generations=(generation,), active_indices=(active_index,),
            credit_owners=(generation.address,),
        )
        try:
            self.base_bond_escrow -= generation.bond
            self._credit(generation.address, generation.bond)
            self.active[active_index] = None
            self._clear_generation_index(
                generation, expected=("ACTIVE", active_index)
            )
            if self.lifecycle_fault_point == "after_generation_clear_index":
                raise RuntimeError("injected generation clear-index fault")
            self._mark_exit_resolved(generation.registration_index)
            self.assert_custody_conservation()
            return True
        except BaseException:
            self._restore_bounded_lifecycle_snapshot(snapshot)
            raise

    def slash_tranche(
        self,
        registration_index: int,
        window: int,
        now: int,
        *,
        reporter: str,
        reporter_cap_atomic: int,
        current_l2_slot: int,
        signed_settlement_chain_id: int | None = None,
    ) -> bool:
        if signed_settlement_chain_id is None:
            signed_settlement_chain_id = self.settlement_chain_id
        location = self._generation_location(registration_index)
        tranche = self.tranches.get((registration_index, window))
        if (location is None or tranche is None
                or signed_settlement_chain_id != self.settlement_chain_id
                or tranche.state not in {
                    TrancheState.RESERVED, TrancheState.LIABLE,
                }
                or now > tranche.liable_until
                or reporter_cap_atomic < 0):
            return False
        if location[2].unreleased_tranche_count <= 0:
            raise AssertionError("slash would underflow unreleased tranche count")
        reservation_bitmap = location[2].reservation_bitmap
        offset = window - location[2].reservation_base_window
        if location[0] == "ACTIVE" and tranche.state is TrancheState.RESERVED:
            if (not 0 <= offset <= MAX_TRANCHE_AHEAD_WINDOWS
                    or not reservation_bitmap & (1 << offset)
                    or (registration_index, window)
                        not in self.open_reservations):
                raise AssertionError("slash reservation bitmap is inconsistent")
        elif (location[0] == "LIABILITY" and reservation_bitmap != 0):
            raise AssertionError("liability generation retains reservation bits")
        reward = min(reporter_cap_atomic, tranche.amount)
        penalty = tranche.amount - reward
        self.tranche_escrow -= tranche.amount
        self._credit(reporter, reward)
        self._credit(self.penalty_sink, penalty)
        self.tranches[(registration_index, window)] = replace(
            tranche, state=TrancheState.SLASHED, amount=0)
        self.open_reservations.discard((registration_index, window))
        self.liable_reservations.discard((registration_index, window))
        if location[0] == "ACTIVE" and 0 <= offset <= 16:
            reservation_bitmap &= ~(1 << offset)
        generation = replace(
            location[2],
            unreleased_tranche_count=location[2].unreleased_tranche_count - 1,
            reservation_bitmap=reservation_bitmap,
            tombstoned_at_l2_slot=(
                current_l2_slot
                if location[2].tombstoned_at_l2_slot == UINT64_MAX
                else location[2].tombstoned_at_l2_slot
            ),
            reservations_closed=True,
        )
        self._write_generation(location[0], location[1], generation)
        self.assert_custody_conservation()
        return True

    def release_tranche(
        self,
        registration_index: int,
        window: int,
        now: int,
        schedule_cursor: ScheduleReleaseCursor,
    ) -> bool:
        location = self._generation_location(registration_index)
        tranche = self.tranches.get((registration_index, window))
        if (location is None or tranche is None
                or tranche.state is not TrancheState.LIABLE
                or now <= tranche.liable_until
                or not self._schedule_cursor_matches(schedule_cursor)
                or not schedule_cursor.is_expired(window)):
            return False
        if location[2].unreleased_tranche_count <= 0:
            raise AssertionError("release would underflow unreleased tranche count")
        self.tranche_escrow -= tranche.amount
        self._credit(location[2].address, tranche.amount)
        self.tranches[(registration_index, window)] = replace(
            tranche, state=TrancheState.RELEASED, amount=0)
        self.liable_reservations.discard((registration_index, window))
        generation = replace(
            location[2],
            unreleased_tranche_count=location[2].unreleased_tranche_count - 1,
        )
        self._write_generation(location[0], location[1], generation)
        self.assert_custody_conservation()
        return True


def tranche_releasable(
    window: int,
    global_min_referenced_slot: int,
    now: int,
    evidence_and_reorg_deadline: int,
    last_managed_window: int = LAST_MANAGED_SCHEDULE_WINDOW,
) -> bool:
    if (type(window) is not int
            or not 0 <= window <= last_managed_window
            or type(global_min_referenced_slot) is not int
            or not 0 <= global_min_referenced_slot <= UINT64_MAX):
        return False
    window_end_slot = SCHEDULE_WINDOW_SLOTS * (window + 1) - 1
    return (window_end_slot < global_min_referenced_slot
            and now > evidence_and_reorg_deadline)


def capped_schedule_terminal_global_min(
    actual_global_min_referenced_slot: int,
) -> int:
    """STS1's conservative uint64 projection of an unbounded live floor."""

    if (type(actual_global_min_referenced_slot) is not int
            or actual_global_min_referenced_slot < 0):
        raise ValueError("terminal global minimum is malformed")
    return min(actual_global_min_referenced_slot, UINT64_MAX)


def encode_settlement_schedule_terminal_state_v1(
    window: int,
    protocol_version: int,
    actual_global_min_referenced_slot: int,
    reference_mask_for_window: int,
    *,
    caller: str,
    pinned_schedule_oracle: str,
) -> bytes:
    capped = capped_schedule_terminal_global_min(
        actual_global_min_referenced_slot
    )
    if (not pinned_schedule_oracle or caller != pinned_schedule_oracle
            or type(reference_mask_for_window) is not int
            or not 0 <= reference_mask_for_window <= 0xFF):
        raise ValueError("terminal reference mask is malformed")
    encoded = b"".join((
        SETTLEMENT_SCHEDULE_TERMINAL_MAGIC + bytes(28),
        _model_uint(window, 32, "STS1 returned window"),
        _model_uint(protocol_version, 32, "STS1 protocol version"),
        _model_uint(capped, 32, "STS1 capped global minimum"),
        _model_uint(reference_mask_for_window, 32,
                    "STS1 reference mask"),
    ))
    if len(encoded) != 160:
        raise AssertionError("STS1 return width drifted")
    return encoded


def normal_context_id(base_hash: str, admission_version: int, admission_root: str,
                      anchor_number: int, anchor_hash: str) -> str:
    return (f"normal:{base_hash}:{admission_version}:{admission_root}:"
            f"{anchor_number}:{anchor_hash}")


@dataclass
class Protocol:
    canonical: Canonical
    header_oracle: EIP2935SystemReadTestAdapter
    forced_queue: "QueueContinuity"
    settlement_address: str = "model-settlement"
    mode: Mode = Mode.NORMAL
    queue_capacity: int = MAX_FORCE_QUEUE_ITEMS  # model-only capacity override
    # Abstract counterpart of the fork/chain policy pinned by the L2 profile.
    forced_tx_fork: ForcedTxFork = ForcedTxFork.FUSAKA
    forced_tx_chain_id: int = 167_000
    episode: int = 0
    recovery: RecoveryRound | None = None
    normal_best: Candidate | None = None
    normal_best_min_data_expiry: int = UINT64_MAX
    normal_deadline: int | None = None
    normal_required_through: int | None = None
    normal_min_admissible: int | None = None
    normal_admission_version: int | None = None
    normal_admission_root: str | None = None
    normal_anchor_number: int | None = None
    normal_anchor_hash: str | None = None
    normal_context_id: str | None = None
    normal_arm_block_number: int | None = None
    admission_version: int = 0
    admission_root: str = "admission:0"
    seat_terms: dict[bytes, SeatTerm] = field(default_factory=dict)
    seat_term_by_tranche: dict[bytes, bytes] = field(default_factory=dict)
    seat_services: dict[bytes, SeatService] = field(default_factory=dict)
    seat_lineup: list[bytes] = field(default_factory=list)
    seat_duties: dict[bytes, Duty] = field(default_factory=dict)
    term_duty: dict[bytes, bytes] = field(default_factory=dict)
    duty_ring: list[SeatDutyCell] = field(
        default_factory=lambda: [SeatDutyCell() for _ in range(DUTY_RING_CAPACITY)]
    )
    duty_sequence: int = 0
    # Exact count of OPEN or FAILED_OVER duties.  Retained duty history is
    # append-only, so nothing in production may scan it.
    unresolved_duty_count: int = 0
    seat_selections: dict[bytes, SelectionRecord] = field(default_factory=dict)
    term_selection: dict[bytes, bytes] = field(default_factory=dict)
    seat_selection: SelectionRecord | None = None
    settlement_seat_stage: SettlementSeatStage | None = None
    stage_tombstones: dict[bytes, StageTombstone] = field(default_factory=dict)
    outstanding_stage_tombstone_id: bytes | None = None
    seat_generation: int = 7
    seat_lineup_revision: int = 0
    # Settlement-local count of canonical transitions; seat duty/selection
    # identities bind to it.  It is not an L1 history ring or sequence: the
    # historical record is the L1 SignalService checkpoint mapping.
    seat_canonical_sequence: int = 0
    seat_authorization_id: bytes | None = None
    seat_market_address: str | None = None
    seat_runway_seconds: int = SEAT_RUNWAY_SECONDS
    minimum_primary_tenure_seconds: int = MIN_PRIMARY_TENURE_SECONDS
    minimum_standby_tenure_seconds: int = MIN_STANDBY_TENURE_SECONDS
    maximum_standby_lease_seconds: int = MAX_STANDBY_LEASE_SECONDS
    exit_delay_seconds: int = EXIT_DELAY_SECONDS
    seat_fault_point: str | None = None
    seat_scan_count: int = 0
    seat_scan_visits_total: int = 0
    seat_sla_trigger_pending: bool = False
    session_cells: list[DataSessionCell] = field(
        default_factory=lambda: [
            DataSessionCell() for _ in range(MAX_LIVE_DATA_SESSIONS)
        ]
    )
    # Values are physical cell indices plus one, matching a Solidity mapping
    # whose zero value means "absent".  It is bounded by occupied cells because
    # both LIVE and REFUND cells retain exactly one entry.
    session_cell_by_id: dict[str, int] = field(default_factory=dict)
    # One global checked allocator avoids both identifier reuse and permanent
    # per-Sybil-owner nonce state.  UINT64_MAX is the unused exhaustion value.
    next_session_sequence: int = 0
    # This map contains only owners of LIVE cells and is deleted at zero.
    session_owner_live_count: dict[str, int] = field(default_factory=dict)
    session_live_count: int = 0
    session_refund_count: int = 0
    session_occupied_count: int = 0
    settlement_eth_balance: int = 0
    data_session_live_bond_liability: int = 0
    data_session_refund_bond_liability: int = 0
    data_session_required_bond: int = 10
    data_session_base_rent_wei: int = 0
    data_session_rent_per_published_byte_wei: int = 0
    data_session_blob_base_fee_multiplier_bps: int = 10_000
    data_session_max_blobs_per_post: int = 6
    data_session_protocol_version: int = 1
    point_evaluation_adapter: PointEvaluationAdapter = field(
        default_factory=PointEvaluationAdapter
    )
    refund_claim_window_seconds: int = DATA_TTL_SECONDS
    reward_reorg_margin_seconds: int = REORG_MARGIN_SECONDS
    data_rent_sink: DataRentSink = field(default_factory=DataRentSink)
    data_session_callback_entered: bool = field(
        default=False, compare=False, repr=False
    )
    forced_ingress_floor_return_override: bytes | None = field(
        default=None, compare=False, repr=False
    )
    forced_ingress_floor_fault_point: str | None = field(
        default=None, compare=False, repr=False
    )
    data_record_events: list[DataRecord] = field(
        default_factory=list, compare=False
    )
    data_session_events: list[object] = field(
        default_factory=list, compare=False
    )
    reward_execution_profile_hash: bytes = field(
        default_factory=lambda: keccak256(
            b"slot-chain-model-execution-profile-v1"
        )
    )
    reward_class_registry: RewardClassRegistryV1 = field(
        default_factory=RewardClassRegistryV1
    )
    reward_class_registry_address: str = BUILDER_REGISTRY_PROFILE_ADDRESS
    reward_class_registry_runtime_hash: bytes = (
        BUILDER_REGISTRY_PROFILE_RUNTIME_HASH
    )
    reward_class_registry_configuration_hash: bytes = (
        BUILDER_REGISTRY_PROFILE_CONFIGURATION_HASH
    )
    reward_funded_by_class: dict[int, int] = field(
        default_factory=lambda: {1: 0, 2: 0, 3: 0}
    )
    total_reward_funding: int = 0
    reward_receipts: dict[int, list[RewardReceiptCellV1]] = field(
        default_factory=lambda: {
            reward_class: [
                RewardReceiptCellV1() for _ in range(MAX_REWARD_RECEIPTS)
            ]
            for reward_class in (1, 2, 3)
        }
    )
    reward_events: list[CandidateCommittedV2] = field(
        default_factory=list, compare=False
    )
    reward_payments: list[tuple[bytes, str, int, int]] = field(
        default_factory=list, compare=False
    )
    reward_accounting_events: list[
        RewardClassFundedV1 | RewardClaimedV1
    ] = field(default_factory=list, compare=False)
    gc_cursor: int = 0
    events: list[str] = field(default_factory=list)
    boundary_queries: int = 0
    canonical_state_witness_available: bool = True
    canonical_code_preimages_available: bool = True
    seat_profile_ready: bool = True
    seat_configuration_ready: bool = True
    # Checkpoints written to the L1 SignalService (``saveCheckpoint`` from the
    # Inbox proxy) inside the same canonical transition, keyed by L2 block
    # number.  This mapping is the historical record; there is no history ring.
    l1_signal_service_checkpoints: dict[int, dict[str, str]] = field(
        default_factory=dict
    )

    def __post_init__(self) -> None:
        if (type(self.session_cells) is not list
                or len(self.session_cells) != MAX_LIVE_DATA_SESSIONS
                or any(type(cell) is not DataSessionCell
                       or not cell.structurally_valid(index)
                       or cell.tag is not DataSessionCellTag.FREE
                       or cell.session is not None
                       for index, cell in enumerate(self.session_cells))
                or type(self.gc_cursor) is not int
                or self.gc_cursor != 0
                or self.session_cell_by_id
                or self.session_owner_live_count
                or type(self.next_session_sequence) is not int
                or self.next_session_sequence != 0
                or self.session_live_count != 0
                or self.session_refund_count != 0
                or self.session_occupied_count != 0
                or type(self.settlement_eth_balance) is not int
                or self.settlement_eth_balance < 0
                or self.data_session_live_bond_liability != 0
                or self.data_session_refund_bond_liability != 0
                or type(self.data_session_required_bond) is not int
                or not 0 < self.data_session_required_bond <= SEAT_UINT256_MAX
                or type(self.data_session_base_rent_wei) is not int
                or not 0 <= self.data_session_base_rent_wei <= SEAT_UINT256_MAX
                or type(self.data_session_rent_per_published_byte_wei) is not int
                or not 0 <= self.data_session_rent_per_published_byte_wei
                    <= SEAT_UINT256_MAX
                or type(self.data_session_blob_base_fee_multiplier_bps) is not int
                or not 0 <= self.data_session_blob_base_fee_multiplier_bps
                    <= 10_000
                or type(self.data_session_max_blobs_per_post) is not int
                or not 0 < self.data_session_max_blobs_per_post <= 6
                or type(self.data_session_protocol_version) is not int
                or not 0 < self.data_session_protocol_version
                    <= SEAT_UINT256_MAX
                or type(self.point_evaluation_adapter)
                    is not PointEvaluationAdapter
                or not self.point_evaluation_adapter.structurally_valid()
                or type(self.refund_claim_window_seconds) is not int
                or not 0 < self.refund_claim_window_seconds <= UINT64_MAX
                or type(self.reward_reorg_margin_seconds) is not int
                or not 0 <= self.reward_reorg_margin_seconds <= UINT64_MAX
                or self.l1_signal_service_checkpoints
                or type(self.data_rent_sink) is not DataRentSink
                or not self.data_rent_sink.address
                or self.data_session_callback_entered
                or self.data_record_events
                or self.data_session_events
                or type(self.reward_execution_profile_hash) is not bytes
                or len(self.reward_execution_profile_hash) != 32
                or self.reward_execution_profile_hash == bytes(32)
                or type(self.reward_class_registry)
                    is not RewardClassRegistryV1
                or self.reward_class_registry.address
                    != self.reward_class_registry_address
                or self.reward_class_registry.runtime_hash
                    != self.reward_class_registry_runtime_hash
                or self.reward_class_registry.configuration_hash
                    != self.reward_class_registry_configuration_hash
                or not self.reward_class_registry_address
                or type(self.reward_class_registry_runtime_hash) is not bytes
                or len(self.reward_class_registry_runtime_hash) != 32
                or self.reward_class_registry_runtime_hash == bytes(32)
                or type(self.reward_class_registry_configuration_hash)
                    is not bytes
                or len(self.reward_class_registry_configuration_hash) != 32
                or self.reward_class_registry_configuration_hash == bytes(32)
                or self.reward_funded_by_class != {1: 0, 2: 0, 3: 0}
                or type(self.total_reward_funding) is not int
                or self.total_reward_funding != 0
                or type(self.reward_receipts) is not dict
                or set(self.reward_receipts) != {1, 2, 3}
                or any(type(ring) is not list
                       or len(ring) != MAX_REWARD_RECEIPTS
                       or any(type(cell) is not RewardReceiptCellV1
                              or cell.receipt is not None or cell.claimed
                              for cell in ring)
                       for ring in self.reward_receipts.values())
                or self.reward_events
                or self.reward_payments
                or self.reward_accounting_events):
            # Protocol construction starts with an empty bounded ring. Tests
            # that need occupied cells use the explicit fixture installer.
            raise ValueError("initial data-session ring is malformed")
        # Activation binds the existing ForcedQueue to this Settlement (the
        # Inbox proxy); the queue rejects enqueue until then.
        if not self.forced_queue._bind_settlement_once(self):
            raise ValueError("forced queue is not bound to this Settlement")

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "header_oracle", "forced_queue", "settlement_address",
            "data_session_required_bond", "refund_claim_window_seconds",
            "reward_reorg_margin_seconds",
            "data_session_base_rent_wei",
            "data_session_rent_per_published_byte_wei",
            "data_session_blob_base_fee_multiplier_bps",
            "data_session_max_blobs_per_post",
            "data_session_protocol_version",
            "point_evaluation_adapter",
            "data_rent_sink",
            "reward_execution_profile_hash", "reward_class_registry",
            "reward_class_registry_address",
            "reward_class_registry_runtime_hash",
            "reward_class_registry_configuration_hash",
        } and name in self.__dict__:
            raise AttributeError(f"Protocol {name} is immutable")
        object.__setattr__(self, name, value)

    @property
    def core(self) -> CanonicalCore:
        return self.canonical.core

    def _active_reward_execution_profile_hash_v1(self) -> bytes:
        return self.reward_execution_profile_hash

    def _reward_profile_bindings_valid_v1(self) -> bool:
        """Check immutable reward timings and BuilderRegistry profile pins."""

        if (type(self.refund_claim_window_seconds) is not int
                or not 0 < self.refund_claim_window_seconds <= UINT64_MAX
                or type(self.reward_reorg_margin_seconds) is not int
                or not 0 <= self.reward_reorg_margin_seconds <= UINT64_MAX
                or type(self.reward_execution_profile_hash) is not bytes
                or len(self.reward_execution_profile_hash) != 32
                or self.reward_execution_profile_hash == bytes(32)
                or type(self.reward_class_registry_address) is not str
                or not self.reward_class_registry_address
                or type(self.reward_class_registry_runtime_hash) is not bytes
                or len(self.reward_class_registry_runtime_hash) != 32
                or self.reward_class_registry_runtime_hash == bytes(32)
                or type(self.reward_class_registry_configuration_hash)
                    is not bytes
                or len(self.reward_class_registry_configuration_hash) != 32
                or self.reward_class_registry_configuration_hash == bytes(32)):
            return False
        return True

    def _reward_receipt_state_valid_v1(self) -> bool:
        """Validate all three class-local rings without mutating state."""

        if (not self._reward_profile_bindings_valid_v1()
                or type(self.reward_receipts) is not dict
                or set(self.reward_receipts) != {1, 2, 3}):
            return False
        candidate_ids: set[bytes] = set()
        for reward_class in (1, 2, 3):
            ring = self.reward_receipts[reward_class]
            if type(ring) is not list or len(ring) != MAX_REWARD_RECEIPTS:
                return False
            for index, cell in enumerate(ring):
                if (type(cell) is not RewardReceiptCellV1
                        or type(cell.claimed) is not bool):
                    return False
                receipt = cell.receipt
                if receipt is None:
                    if cell.claimed:
                        return False
                    continue
                if (type(receipt) is not RewardReceiptV1
                        or receipt.reward_class != reward_class
                        or receipt.candidate_id[-1] != index
                        or receipt.candidate_id in candidate_ids
                        or receipt.committed_at_timestamp
                            > UINT64_MAX - self.refund_claim_window_seconds
                        or receipt.claim_until
                            != receipt.committed_at_timestamp
                                + self.refund_claim_window_seconds):
                    return False
                candidate_ids.add(receipt.candidate_id)
        return True

    def _reward_receipt_allocation_decision_v1(
        self, candidate: object, clock: object
    ) -> RewardReceiptAllocationDecisionV1:
        """Return one explicit allocation outcome; this decision never throws."""

        if (not self._reward_profile_bindings_valid_v1()
                or type(self.reward_class_registry)
                    is not RewardClassRegistryV1
                or type(self.reward_receipts) is not dict
                or set(self.reward_receipts) != {1, 2, 3}):
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.REJECT_SETTLEMENT_INVARIANT
            )
        if (type(candidate) is not Candidate
                or type(clock) is not Clock
                or type(candidate.beneficiary) is not str
                or not candidate.beneficiary
                or type(candidate.tier) is not Tier
                or any(type(block) is not Block
                       or block.tier is not candidate.tier
                       for block in candidate.blocks)
                or not reward_candidate_metrics_valid_v1(candidate, self)
                or type(clock.block_number) is not int
                or not 0 < clock.block_number <= UINT64_MAX
                or type(clock.timestamp) is not int
                or not 0 < clock.timestamp <= UINT64_MAX):
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.REJECT_CANDIDATE_INVARIANT
            )
        candidate_id = reward_candidate_id_word_v1(candidate.candidate_id)
        if candidate_id is None or candidate_id == bytes(32):
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.SKIP_ID_CONVERSION,
                beneficiary=candidate.beneficiary,
                reward_class=candidate.tier.value,
                reward_execution_gas=candidate.reward_execution_gas,
                reward_published_bytes=candidate.reward_published_bytes,
            )
        reward_class = candidate.tier.value
        receipt_index = candidate_id[-1]
        common = dict(
            candidate_id=candidate_id,
            beneficiary=candidate.beneficiary,
            reward_class=reward_class,
            reward_execution_gas=candidate.reward_execution_gas,
            reward_published_bytes=candidate.reward_published_bytes,
            receipt_index=receipt_index,
        )
        if clock.timestamp > UINT64_MAX - self.refund_claim_window_seconds:
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.SKIP_DEADLINE_OVERFLOW,
                **common,
            )
        ring = self.reward_receipts[reward_class]
        if type(ring) is not list or len(ring) != MAX_REWARD_RECEIPTS:
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.REJECT_SETTLEMENT_INVARIANT,
                **common,
            )
        cell = ring[receipt_index]
        if (type(cell) is not RewardReceiptCellV1
                or type(cell.claimed) is not bool
                or (cell.receipt is None and cell.claimed)):
            return RewardReceiptAllocationDecisionV1(
                RewardReceiptAllocationOutcomeV1.REJECT_SETTLEMENT_INVARIANT,
                **common,
            )
        prior = cell.receipt
        if prior is not None:
            if (type(prior) is not RewardReceiptV1
                    or prior.reward_class != reward_class
                    or prior.candidate_id[-1] != receipt_index
                    or prior.committed_at_timestamp
                        > UINT64_MAX - self.refund_claim_window_seconds
                    or prior.claim_until
                        != prior.committed_at_timestamp
                            + self.refund_claim_window_seconds):
                return RewardReceiptAllocationDecisionV1(
                    RewardReceiptAllocationOutcomeV1.REJECT_SETTLEMENT_INVARIANT,
                    **common,
                )
            if cell.claimed:
                reusable = (
                    prior.committed_at_timestamp
                        <= UINT64_MAX - self.reward_reorg_margin_seconds
                    and clock.timestamp >= prior.committed_at_timestamp
                        + self.reward_reorg_margin_seconds
                )
            else:
                reusable = (
                    prior.claim_until
                        <= UINT64_MAX - self.reward_reorg_margin_seconds
                    and clock.timestamp > prior.claim_until
                    and clock.timestamp >= prior.claim_until
                        + self.reward_reorg_margin_seconds
                )
            if not reusable:
                return RewardReceiptAllocationDecisionV1(
                    RewardReceiptAllocationOutcomeV1.SKIP_LIVE_COLLISION,
                    **common,
                )
        receipt = RewardReceiptV1(
            candidate_id,
            candidate.beneficiary,
            reward_class,
            candidate.reward_execution_gas,
            candidate.reward_published_bytes,
            self._active_reward_execution_profile_hash_v1(),
            clock.block_number,
            clock.timestamp,
            clock.timestamp + self.refund_claim_window_seconds,
        )
        return RewardReceiptAllocationDecisionV1(
            RewardReceiptAllocationOutcomeV1.STORE,
            receipt=receipt,
            **common,
        )

    def _record_reward_receipt_v1(
        self, candidate: Candidate, clock: Clock
    ) -> CandidateCommittedV2:
        """Apply the explicit bounded allocation decision after commit."""

        decision = self._reward_receipt_allocation_decision_v1(
            candidate, clock
        )
        if decision.outcome in {
            RewardReceiptAllocationOutcomeV1.REJECT_CANDIDATE_INVARIANT,
            RewardReceiptAllocationOutcomeV1.REJECT_SETTLEMENT_INVARIANT,
        }:
            raise AssertionError(
                f"reward receipt invariant failed: {decision.outcome.value}"
            )
        receipt = decision.receipt
        stored = decision.outcome is RewardReceiptAllocationOutcomeV1.STORE
        if stored:
            if type(receipt) is not RewardReceiptV1:
                raise AssertionError("stored reward decision has no receipt")
            cell = self.reward_receipts[
                decision.reward_class
            ][decision.receipt_index]
            cell.receipt = receipt
            cell.claimed = False
        event = CandidateCommittedV2(
            decision.candidate_id,
            decision.beneficiary,
            decision.reward_class,
            decision.reward_execution_gas,
            decision.reward_published_bytes,
            stored,
            decision.receipt_index,
            bytes(32) if receipt is None else receipt.commitment,
        )
        self.reward_events.append(event)
        return event

    def _reward_receipt_match_v1(
        self, exact_candidate_id: bytes
    ) -> tuple[RewardReceiptV1 | None, bool, RewardReceiptCellV1 | None]:
        """Scan exactly one low-byte cell in each of the three class rings."""

        if (type(exact_candidate_id) is not bytes
                or len(exact_candidate_id) != 32
                or exact_candidate_id == bytes(32)):
            return None, False, None
        index = exact_candidate_id[-1]
        matches: list[tuple[RewardReceiptV1, bool, RewardReceiptCellV1]] = []
        for reward_class in (1, 2, 3):
            if (type(self.reward_receipts) is not dict
                    or set(self.reward_receipts) != {1, 2, 3}
                    or type(self.reward_receipts[reward_class]) is not list
                    or len(self.reward_receipts[reward_class])
                        != MAX_REWARD_RECEIPTS):
                raise ValueError("reward receipt ring geometry is malformed")
            cell = self.reward_receipts[reward_class][index]
            if (type(cell) is not RewardReceiptCellV1
                    or type(cell.claimed) is not bool
                    or (cell.receipt is None and cell.claimed)):
                raise ValueError("probed reward receipt cell is malformed")
            receipt = cell.receipt
            if (receipt is not None
                    and (type(receipt) is not RewardReceiptV1
                         or receipt.reward_class != reward_class
                         or receipt.candidate_id[-1] != index)):
                raise ValueError("probed reward receipt is malformed")
            if receipt is not None and receipt.candidate_id == exact_candidate_id:
                matches.append((receipt, cell.claimed, cell))
        if len(matches) > 1:
            raise ValueError("candidate identity appears in multiple reward rings")
        return (None, False, None) if not matches else matches[0]

    def reward_receipt_state_v1(
        self, candidate_id: object
    ) -> tuple[RewardReceiptV1 | None, bool]:
        exact = reward_candidate_id_word_v1(candidate_id)
        if exact is None:
            return None, False
        receipt, claimed, _cell = self._reward_receipt_match_v1(exact)
        return receipt, claimed

    def reward_receipt_v1(
        self, calldata: bytes, *, caller: str, gas: int, value: int
    ) -> bytes:
        """Model the exact live 36-byte RRV1 ring view call."""

        if (type(calldata) is not bytes or len(calldata) != 36
                or calldata[:4] != REWARD_RECEIPT_V1_SELECTOR
                or not caller or gas != REWARD_RECEIPT_READ_GAS
                or value != 0):
            raise ValueError("rewardReceiptV1 call frame is inexact")
        receipt, claimed = self.reward_receipt_state_v1(calldata[4:])
        return encode_reward_receipt_return_v1(receipt, claimed)

    def _reward_class_registry_exact_v1(self) -> RewardClassRegistryV1:
        """Return the profile-pinned BuilderRegistry reward-class reader."""

        registry = self.reward_class_registry
        if (type(registry) is not RewardClassRegistryV1
                or not self._reward_profile_bindings_valid_v1()
                or registry.address != self.reward_class_registry_address):
            raise ValueError("reward class registry binding changed")
        if registry.extcodehash(
                caller=self.settlement_address
        ) != self.reward_class_registry_runtime_hash:
            raise ValueError("BuilderRegistry observed code hash changed")
        return registry

    def fund_reward_class_v1(
        self, class_id: int, amount: int, *, funder: str
    ) -> RewardClassFundedV1:
        """Credit one immutable reward-class bucket with received ETH."""

        try:
            if self.data_session_callback_entered:
                raise SharedSettlementReentrancy(
                    "nested reward funding hit the shared Settlement guard"
                )
            _model_address20(funder)
            if type(class_id) is not int or class_id not in (1, 2, 3):
                raise ValueError("reward class is outside authenticated tiers")
            if not self._reward_funding_state_valid_v1():
                raise ValueError("reward funding scalars are inconsistent")
            funded = self.reward_funded_by_class[class_id]
            if (type(amount) is not int or amount <= 0
                    or amount > SEAT_UINT256_MAX
                    or type(funded) is not int or funded < 0
                    or funded > SEAT_UINT256_MAX - amount
                    or type(self.total_reward_funding) is not int
                    or not 0 <= self.total_reward_funding <= SEAT_UINT256_MAX
                    or self.total_reward_funding
                        > SEAT_UINT256_MAX - amount
                    or type(self.settlement_eth_balance) is not int
                    or not 0 <= self.settlement_eth_balance <= SEAT_UINT256_MAX
                    or self.settlement_eth_balance
                        > SEAT_UINT256_MAX - amount):
                raise ValueError("reward funding is outside uint256")
            event = RewardClassFundedV1(
                class_id,
                funder,
                amount,
                funded + amount,
                self.total_reward_funding + amount,
            )
        except SharedSettlementReentrancy:
            raise
        except BaseException as exc:
            raise RewardFundingRevert("reward funding reverted") from exc
        self.reward_funded_by_class[class_id] = event.class_funding_after
        self.total_reward_funding = event.total_funding_after
        self.settlement_eth_balance += amount
        self.reward_accounting_events.append(event)
        return event

    def force_reward_eth_v1(self, amount: int) -> bool:
        """Model forced ETH, which increases balance but no funded bucket."""

        return self.force_data_session_eth(amount)

    @staticmethod
    def _capped_reward_product_v1(
        total: int, rate: int, units: int, cap: int
    ) -> int:
        """Return min(cap,total+rate*units) without a wide intermediate."""

        if total >= cap or rate == 0 or units == 0:
            return min(total, cap)
        remaining = cap - total
        if units > remaining // rate:
            return cap
        return total + rate * units

    def reward_amount_v1(
        self,
        receipt: RewardReceiptV1,
        reward_class: RewardClassV1,
    ) -> int:
        """Compute from the one exact profile-pinned getter row."""

        if (type(receipt) is not RewardReceiptV1
                or type(reward_class) is not RewardClassV1
                or receipt.execution_profile_hash
                    != self._active_reward_execution_profile_hash_v1()
                or receipt.committed_at_timestamp
                    > UINT64_MAX
                        - self.refund_claim_window_seconds
                or receipt.claim_until
                    != receipt.committed_at_timestamp
                        + self.refund_claim_window_seconds
                or reward_class.class_id != receipt.reward_class):
            raise ValueError("reward receipt uses another immutable schedule")
        row = reward_class
        total = min(row.fixed_wei, row.cap_wei)
        total = self._capped_reward_product_v1(
            total,
            row.per_execution_gas_wei,
            receipt.reward_execution_gas,
            row.cap_wei,
        )
        return self._capped_reward_product_v1(
            total,
            row.per_published_byte_wei,
            receipt.reward_published_bytes,
            row.cap_wei,
        )

    def claim_reward_v1(
        self,
        candidate_id: object,
        clock: Clock,
        *,
        transfer: Callable[[str, int, "Protocol"], bool] | None = None,
    ) -> int:
        """Consume and pay the exact live reward receipt, if fully funded."""

        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "nested reward claim hit the shared Settlement guard"
            )
        if (type(clock) is not Clock
                or type(clock.timestamp) is not int
                or not 0 <= clock.timestamp <= UINT64_MAX):
            raise RewardClaimRevert("reward claim clock is malformed")
        snapshot = self._canonical_transaction_snapshot()
        guard_held = False
        try:
            exact_candidate_id = _model_fixed_bytes32(candidate_id)
            receipt, claimed, claimed_cell = self._reward_receipt_match_v1(
                exact_candidate_id
            )
            if (receipt is None or claimed
                    or clock.timestamp > receipt.claim_until):
                raise ValueError("reward receipt is absent, claimed or expired")
            registry = self._reward_class_registry_exact_v1()
            component_configuration = registry.component_config_staticcall(
                COMPONENT_CONFIG_GETTER_SELECTOR,
                caller=self.settlement_address,
                gas=COMPONENT_CONFIG_GETTER_GAS,
                value=0,
            )
            if (type(component_configuration) is not bytes
                    or len(component_configuration) != 32
                    or component_configuration
                        != self.reward_class_registry_configuration_hash):
                raise ValueError("BuilderRegistry configuration read differs")
            calldata = (
                REWARD_CLASS_V1_SELECTOR
                + bytes(31)
                + bytes((receipt.reward_class,))
            )
            returned_class = decode_reward_class_return_v1(
                registry.staticcall(
                    calldata,
                    caller=self.settlement_address,
                    gas=REWARD_CLASS_READ_GAS,
                    value=0,
                ),
                receipt.reward_class,
                self.reward_class_registry_configuration_hash,
            )
            amount = self.reward_amount_v1(receipt, returned_class)
            funded = self.reward_funded_by_class[receipt.reward_class]
            if (type(funded) is not int or funded < amount
                    or type(self.total_reward_funding) is not int
                    or self.total_reward_funding < amount
                    or type(self.settlement_eth_balance) is not int
                    or self.settlement_eth_balance < amount):
                raise ValueError("reward class funding is insufficient")
            if (type(claimed_cell) is not RewardReceiptCellV1
                    or claimed_cell.receipt is not receipt
                    or claimed_cell.claimed):
                raise ValueError("reward ring cell changed before consumption")
            self.data_session_callback_entered = True
            guard_held = True
            # Checks-effects-interactions: Settlement owns the claim bit and
            # class bucket, and updates both before the beneficiary call.
            claimed_cell.claimed = True
            self.reward_funded_by_class[receipt.reward_class] -= amount
            self.total_reward_funding -= amount
            self.settlement_eth_balance -= amount
            if amount == 0:
                self.reward_payments.append((
                    receipt.candidate_id,
                    receipt.beneficiary,
                    receipt.reward_class,
                    0,
                ))
                self.reward_accounting_events.append(RewardClaimedV1(
                    receipt.candidate_id,
                    receipt.beneficiary,
                    receipt.reward_class,
                    0,
                ))
                if not self._reward_funding_state_valid_v1():
                    raise AssertionError("zero reward broke funding solvency")
                return 0
            succeeded = (
                True
                if transfer is None
                else transfer(receipt.beneficiary, amount, self)
            )
            if succeeded is not True:
                raise RuntimeError("reward transfer rejected")
            self.reward_payments.append((
                receipt.candidate_id,
                receipt.beneficiary,
                receipt.reward_class,
                amount,
            ))
            self.reward_accounting_events.append(RewardClaimedV1(
                receipt.candidate_id,
                receipt.beneficiary,
                receipt.reward_class,
                amount,
            ))
            if not self._reward_funding_state_valid_v1():
                raise AssertionError("reward claim broke funding solvency")
            return amount
        except BaseException as exc:
            self._restore_canonical_transaction(snapshot)
            guard_held = False
            raise RewardClaimRevert("reward claim reverted") from exc
        finally:
            if guard_held:
                self.data_session_callback_entered = False

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

    def _seat_current_canonical_sequence(self) -> int:
        sequence = self.seat_canonical_sequence
        if not 0 <= sequence <= UINT64_MAX:
            raise ValueError("seat canonical sequence is outside uint64")
        return sequence

    def _seat_fault(self, name: str) -> None:
        if self.seat_fault_point == name:
            raise RuntimeError(f"injected Settlement seat fault: {name}")

    @property
    def selected_successor_term_id(self) -> bytes | None:
        return self.seat_selection.term_id if self.seat_selection is not None else None

    @property
    def active_primary_term_id(self) -> bytes | None:
        if not self.seat_lineup:
            return None
        term_id = self.seat_lineup[0]
        service = self.seat_services[term_id]
        if (
            term_id == self.selected_successor_term_id
            or service.responsibility_start is None
            or service.closed_at is not None
        ):
            return None
        return term_id

    def seat_lineup_commitment(self) -> bytes:
        fixed_ids = list(self.seat_lineup[:SEAT_COUNT])
        fixed_ids.extend([bytes(32)] * (SEAT_COUNT - len(fixed_ids)))
        if any(type(term_id) is not bytes or len(term_id) != 32
               for term_id in fixed_ids):
            raise ValueError("lineup term ID is not exact bytes32")
        return keccak256(
            b"TAIKO_SEAT_LINEUP_V1"
            + _model_uint(self.seat_lineup_revision, 8, "lineup revision")
            + b"".join(fixed_ids)
        )

    def _advance_lineup_revision(self) -> None:
        self.seat_lineup_revision = seat_checked_add(
            self.seat_lineup_revision, 1, "seat lineup revision"
        )

    def _seat_term_id(
        self,
        authorization_id: bytes,
        generation: int,
        offer_id: bytes,
        tranche_id: bytes,
        installed_at: int,
        lineup_revision_at_install: int,
    ) -> bytes:
        """Bind a final term to its exact applied lifecycle identity."""

        if any(type(value) is not bytes or len(value) != 32 for value in (
            authorization_id, offer_id, tranche_id,
        )):
            raise ValueError("seat term identity input is not exact bytes32")
        return keccak256(
            b"TAIKO_SEAT_TERM_V1" + authorization_id
            + _model_uint(generation, 8, "seat generation")
            + offer_id + tranche_id
            + _model_uint(installed_at, 8, "installed at")
            + _model_uint(
                lineup_revision_at_install, 8, "install revision"
            )
        )

    def _record_seat_term(self, term: SeatTerm) -> None:
        """Install one permanent term/tranche reverse binding in O(1)."""

        if (
            term.term_id in self.seat_terms
            or term.tranche_id in self.seat_term_by_tranche
        ):
            raise ValueError("term installation collides with retained history")
        self.seat_terms[term.term_id] = term
        self.seat_term_by_tranche[term.tranche_id] = term.term_id

    def _assert_seat_valid(self) -> None:
        seat_u256(self.seat_lineup_revision, "seat lineup revision")
        if (
            type(self.duty_sequence) is not int
            or not 0 <= self.duty_sequence <= UINT64_MAX
        ):
            raise AssertionError("duty sequence is outside uint64")
        if len(self.seat_lineup) > SEAT_COUNT:
            raise AssertionError("seat lineup exceeds four terms")
        if len(self.seat_lineup) != len(set(self.seat_lineup)):
            raise AssertionError("seat lineup contains duplicate terms")
        if len(self.duty_ring) != DUTY_RING_CAPACITY:
            raise AssertionError("duty ring geometry changed")
        if (
            type(self.unresolved_duty_count) is not int
            or not 0 <= self.unresolved_duty_count <= DUTY_RING_CAPACITY
            or self.unresolved_duty_count != sum(
                duty.status in (DutyStatus.OPEN, DutyStatus.FAILED_OVER)
                for duty in self.seat_duties.values()
            )
        ):
            raise AssertionError("unresolved duty counter is inconsistent")
        if self.seat_selection is not None:
            selection = self.seat_selection
            if (
                not self.seat_lineup
                or self.seat_lineup[0] != selection.term_id
            ):
                raise AssertionError("selected successor is not rank zero")
            selected_term = self.seat_terms[selection.term_id]
            selected_service = self.seat_services[selection.term_id]
            if selected_service.responsibility_start is not None:
                raise AssertionError("selected successor started before a cure/revision")
            if (
                selection.tranche_id != selected_term.tranche_id
                or selection.offer_id != selected_term.offer_id
            ):
                raise AssertionError("selected successor identity is not exact")
            if (
                selection.predecessor_duty_id is not None
                and selection.predecessor_duty_id not in self.seat_duties
            ):
                raise AssertionError("selected successor trigger duty is unknown")
            if (
                (selection.source is SelectionSource.DUTY_FAILOVER)
                != (selection.predecessor_duty_id is not None)
            ):
                raise AssertionError("selection source/duty binding is ambiguous")
            expected_selection_id = seat_selection_id_v1(
                selection.term_id,
                selection.tranche_id,
                selection.offer_id,
                selection.selected_canonical_sequence,
                selection.selected_at,
                selection.target_tip,
                selection.source,
                selection.predecessor_duty_id,
            )
            if selection.selection_id != expected_selection_id:
                raise AssertionError("selected successor record commitment changed")
            if (
                self.seat_selections.get(selection.selection_id) != selection
                or self.term_selection.get(selection.term_id)
                    != selection.selection_id
            ):
                raise AssertionError("live selection is not retained exactly")
        seen_selected_terms: set[bytes] = set()
        for selection_id, selection in self.seat_selections.items():
            term = self.seat_terms.get(selection.term_id)
            if (
                selection_id != selection.selection_id
                or term is None
                or selection.term_id in seen_selected_terms
                or self.term_selection.get(selection.term_id) != selection_id
                or selection.tranche_id != term.tranche_id
                or selection.offer_id != term.offer_id
                or (
                    (selection.source is SelectionSource.DUTY_FAILOVER)
                    != (selection.predecessor_duty_id is not None)
                )
                or selection.selection_id
                    != seat_selection_id_v1(
                        selection.term_id,
                        selection.tranche_id,
                        selection.offer_id,
                        selection.selected_canonical_sequence,
                        selection.selected_at,
                        selection.target_tip,
                        selection.source,
                        selection.predecessor_duty_id,
                    )
            ):
                raise AssertionError("retained selection history is not exact")
            seen_selected_terms.add(selection.term_id)
        if set(self.term_selection) != seen_selected_terms:
            raise AssertionError("selection reverse index is incomplete")
        seen_tranches: dict[bytes, bytes] = {}
        for term_id, term in self.seat_terms.items():
            if term_id != term.term_id or len(term_id) != 32:
                raise AssertionError("seat term identity mismatch")
            if (term.authorization_id is None) != (term.generation is None):
                raise AssertionError("seat term authority tuple is partial")
            if term.authorization_id is not None and (
                type(term.authorization_id) is not bytes
                or len(term.authorization_id) != 32
                or type(term.generation) is not int
                or not 0 <= term.generation <= self.seat_generation
                or term.install_revision == 0
                or term.term_id != self._seat_term_id(
                    term.authorization_id,
                    term.generation,
                    term.offer_id,
                    term.tranche_id,
                    term.installed_at,
                    term.install_revision,
                )
            ):
                raise AssertionError("seat term authority tuple is malformed")
            if term.tranche_id in seen_tranches:
                raise AssertionError("installed tranche bound more than once")
            seen_tranches[term.tranche_id] = term_id
            if term_id not in self.seat_services:
                raise AssertionError("seat term lacks service record")
            service = self.seat_services[term_id]
            expected_standby_expiry = seat_checked_add(
                term.installed_at,
                self.maximum_standby_lease_seconds,
                "standby lease expiry",
            )
            if service.standby_lease_expires_at != expected_standby_expiry:
                raise AssertionError("standby lease expiry changed")
            if (term_id in self.seat_lineup) == (
                service.term_removed_at is not None
            ):
                raise AssertionError("seat roster removal timestamp is inconsistent")
            if service.term_removed_at is not None and (
                service.closed_at is None
                or service.term_removed_at < service.closed_at
            ):
                raise AssertionError("seat removal predates immutable closure")
            prospective = (
                service.duty_base_tip_slot,
                service.duty_base_sequence,
                service.prospective_target_tip,
                service.prospective_recovery_at,
                service.prospective_failover_at,
                service.prospective_slash_at,
            )
            if service.responsibility_start is None:
                if any(value is not None for value in prospective):
                    raise AssertionError("unstarted standby has prospective duty state")
            elif any(value is None for value in prospective):
                raise AssertionError("started service lost prospective duty state")
            else:
                tip_time = seat_checked_add(
                    GENESIS_TIMESTAMP,
                    service.duty_base_tip_slot,
                    "prospective duty tip time",
                )
                if (
                    service.prospective_recovery_at
                    < service.responsibility_start
                    or service.prospective_failover_at
                    < service.responsibility_start
                    or service.prospective_slash_at
                    < service.responsibility_start
                    or service.prospective_target_tip
                    != seat_checked_add(
                        service.duty_base_tip_slot,
                        DELTA_RECOVERY_LAG,
                        "prospective duty target",
                    )
                    or service.prospective_recovery_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_RECOVERY_LAG,
                        "prospective duty recovery",
                    )
                    or service.prospective_failover_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_FINAL_LAG,
                        "prospective duty failover",
                    )
                    or service.prospective_slash_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_SLASH_LAG,
                        "prospective duty slash",
                    )
                ):
                    raise AssertionError(
                        "prospective duty thresholds changed or predate service"
                    )
        if self.seat_term_by_tranche != seen_tranches:
            raise AssertionError("term/tranche reverse index is incomplete")
        for term_id, duty_id in self.term_duty.items():
            duty = self.seat_duties.get(duty_id)
            if duty is None or duty.term_id != term_id:
                raise AssertionError("term/duty binding mismatch")
        for duty_id, duty in self.seat_duties.items():
            term = self.seat_terms.get(duty.term_id)
            tip_time = seat_checked_add(
                GENESIS_TIMESTAMP, duty.base_tip_slot, "retained duty tip time"
            )
            if (
                duty_id != duty.duty_id
                or term is None
                or self.term_duty.get(duty.term_id) != duty_id
                or duty.tranche_id != term.tranche_id
                or duty.operator != term.operator
                or duty.duty_id
                    != seat_duty_id_v1(
                        duty.term_id,
                        duty.sequence,
                        duty.base_sequence,
                        duty.base_tip_slot,
                    )
                or not 0 < duty.sequence <= self.duty_sequence
                or not 0 <= duty.ring_index < DUTY_RING_CAPACITY
                or duty.target_tip
                    != seat_checked_add(
                        duty.base_tip_slot,
                        DELTA_RECOVERY_LAG,
                        "retained duty target",
                    )
                or duty.recovery_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_RECOVERY_LAG,
                        "retained duty recovery",
                    )
                or duty.failover_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_FINAL_LAG,
                        "retained duty failover",
                    )
                or duty.slash_at
                    != seat_checked_add(
                        tip_time,
                        DELTA_SLASH_LAG,
                        "retained duty slash",
                    )
            ):
                raise AssertionError("retained duty lost its exact reverse binding")
            service = self.seat_services[duty.term_id]
            if (
                service.duty_base_tip_slot != duty.base_tip_slot
                or service.duty_base_sequence != duty.base_sequence
                or service.prospective_target_tip != duty.target_tip
                or service.prospective_recovery_at != duty.recovery_at
                or service.prospective_failover_at != duty.failover_at
                or service.prospective_slash_at != duty.slash_at
            ):
                raise AssertionError("service/duty objective base changed")
            if duty.status is DutyStatus.OPEN and any(
                value is not None
                for value in (
                    duty.satisfied_at,
                    duty.disposition_at,
                    duty.breach_recorded_at,
                )
            ):
                raise AssertionError("open duty has a terminal timestamp")
            if duty.status is DutyStatus.FAILED_OVER and (
                duty.satisfied_at is not None
                or duty.disposition_at != duty.failover_at
                or duty.breach_recorded_at is not None
            ):
                raise AssertionError("failed-over duty timestamps are inconsistent")
            if duty.status is DutyStatus.SATISFIED and (
                duty.satisfied_at is None
                or duty.disposition_at != duty.satisfied_at
                or duty.satisfied_at > duty.slash_at
                or duty.breach_recorded_at is not None
            ):
                raise AssertionError("satisfied duty timestamps are inconsistent")
            if duty.status is DutyStatus.BREACHED and (
                duty.satisfied_at is not None
                or duty.breach_recorded_at is None
                or duty.disposition_at != duty.breach_recorded_at
                or duty.breach_recorded_at <= duty.slash_at
            ):
                raise AssertionError("breached duty timestamps are inconsistent")
            if duty.status in (
                DutyStatus.EXCUSED, DutyStatus.EXCUSED_MIGRATION
            ) and (
                duty.satisfied_at is not None
                or duty.disposition_at is None
                or duty.breach_recorded_at is not None
            ):
                raise AssertionError("excused duty timestamps are inconsistent")
        occupied: set[bytes] = set()
        for index, cell in enumerate(self.duty_ring):
            if cell.reusable:
                continue
            if cell.duty_id is None or cell.duty_id in occupied:
                raise AssertionError("live duty cell is empty or duplicated")
            duty = self.seat_duties.get(cell.duty_id)
            if (
                duty is None
                or duty.ring_index != index
                or duty.sequence != cell.sequence
            ):
                raise AssertionError("duty ring sequence tag mismatch")
            occupied.add(cell.duty_id)
        if self.settlement_seat_stage is not None:
            stage = self.settlement_seat_stage
            if stage.stage_id in self.stage_tombstones:
                raise AssertionError("live stage also has a tombstone")

    def _invalidate_local_stage(self, reason: str) -> None:
        stage = self.settlement_seat_stage
        if stage is None:
            return
        self.stage_tombstones[stage.stage_id] = StageTombstone(
            stage.stage_id, stage.lineup_commitment, reason
        )
        self.outstanding_stage_tombstone_id = stage.stage_id
        self.settlement_seat_stage = None
        self._seat_fault("after_stage_tombstone")

    def _close_service(self, term_id: bytes, close_at: int, reason: str) -> None:
        service = self.seat_services[term_id]
        if service.closed_at is None:
            service.closed_at = close_at
            service.close_reason = reason
        elif service.closed_at != close_at:
            raise AssertionError("immutable service close changed")

    def _record_term_removal(self, term_id: bytes, removed_at: int) -> None:
        """Persist the exact roster-removal time once for liability horizons."""

        service = self.seat_services[term_id]
        removed_at = seat_u256(removed_at, "seat term removal time")
        if service.term_removed_at is None:
            service.term_removed_at = removed_at
        elif service.term_removed_at != removed_at:
            raise AssertionError("immutable seat term removal time changed")

    def _remove_lineup_term(self, term_id: bytes, removed_at: int) -> None:
        if term_id not in self.seat_lineup:
            raise AssertionError("seat term is not roster occupied")
        self._record_term_removal(term_id, removed_at)
        self.seat_lineup.remove(term_id)

    def _runway_feasible(self) -> bool:
        return self.seat_runway_seconds >= (
            self.minimum_primary_tenure_seconds
            + HANDOVER_EXECUTION_BUFFER_SECONDS
            + SLA_TAIL_SECONDS
        )

    def _vacate_entire_lineup(
        self,
        close_at: int,
        reason: str,
        *,
        removed_at: int | None = None,
    ) -> None:
        self._invalidate_local_stage(reason)
        exact_removed_at = close_at if removed_at is None else removed_at
        had_lineup = bool(self.seat_lineup)
        for term_id in tuple(self.seat_lineup):
            self._close_service(term_id, close_at, reason)
            self._record_term_removal(term_id, exact_removed_at)
        self.seat_lineup.clear()
        self._clear_selected_successor()
        if had_lineup:
            self._advance_lineup_revision()
        self.events.append(f"SEAT_VACANT:{reason}:{close_at}")

    def _clear_selected_successor(self) -> None:
        self.seat_selection = None

    def _fresh_service_base_tip(self, responsibility_start: int) -> int:
        """Never backdate a newly assumed primary duty before its start clock."""

        return max(
            self.core.tip_slot,
            seat_checked_sub(
                responsibility_start,
                GENESIS_TIMESTAMP,
                "fresh service responsibility slot",
            ),
        )

    def _set_prospective_duty(
        self, term_id: bytes, base_tip_slot: int, base_sequence: int
    ) -> None:
        """Roll the unallocated next-duty interval to a healthy canonical tip."""

        if term_id in self.term_duty:
            raise AssertionError("activated duty base cannot be refreshed")
        service = self.seat_services[term_id]
        tip_time = seat_checked_add(
            GENESIS_TIMESTAMP, base_tip_slot, "prospective duty tip time"
        )
        service.duty_base_tip_slot = seat_u256(
            base_tip_slot, "prospective duty base tip"
        )
        service.duty_base_sequence = seat_u256(
            base_sequence, "prospective duty base sequence"
        )
        service.prospective_target_tip = seat_checked_add(
            base_tip_slot, DELTA_RECOVERY_LAG, "prospective duty target"
        )
        service.prospective_recovery_at = seat_checked_add(
            tip_time, DELTA_RECOVERY_LAG, "prospective duty recovery"
        )
        service.prospective_failover_at = seat_checked_add(
            tip_time, DELTA_FINAL_LAG, "prospective duty failover"
        )
        service.prospective_slash_at = seat_checked_add(
            tip_time, DELTA_SLASH_LAG, "prospective duty slash"
        )
        service.ring_full_recovery_at = None

    def _attach_duty(
        self,
        term_id: bytes,
        base_tip_slot: int | None = None,
        base_sequence: int | None = None,
        *,
        chosen_ring_index: int | None = None,
    ) -> DutyAttachmentOutcome:
        if term_id in self.term_duty:
            raise AssertionError("one duty per seat term")
        service = self.seat_services[term_id]
        exact_base_tip_slot = service.duty_base_tip_slot
        exact_base_sequence = service.duty_base_sequence
        if exact_base_tip_slot is None or exact_base_sequence is None:
            raise AssertionError("prospective duty lacks immutable base")
        if (
            base_tip_slot is not None and base_tip_slot != exact_base_tip_slot
        ) or (
            base_sequence is not None and base_sequence != exact_base_sequence
        ):
            raise AssertionError("pending duty clock was reset")
        chosen = chosen_ring_index
        if chosen is not None:
            if (
                not 0 <= chosen < DUTY_RING_CAPACITY
                or not self.duty_ring[chosen].reusable
            ):
                raise AssertionError("cached duty cell is not reusable")
        else:
            start_index = self.duty_sequence % DUTY_RING_CAPACITY
            self.seat_scan_count = 0
            for offset in range(DUTY_RING_CAPACITY):
                self.seat_scan_count += 1
                self.seat_scan_visits_total += 1
                index = (start_index + offset) % DUTY_RING_CAPACITY
                if self.duty_ring[index].reusable:
                    chosen = index
                    break
        tip_time = seat_checked_add(
            GENESIS_TIMESTAMP, exact_base_tip_slot, "duty tip time"
        )
        target_tip = service.prospective_target_tip
        recovery_at = service.prospective_recovery_at
        failover_at = service.prospective_failover_at
        slash_at = service.prospective_slash_at
        if None in (target_tip, recovery_at, failover_at, slash_at):
            raise AssertionError("prospective duty thresholds are incomplete")
        if chosen is None:
            service.ring_full_recovery_at = seat_checked_add(
                tip_time, DELTA_RECOVERY_LAG, "ring-full recovery"
            )
            return DutyAttachmentOutcome(DutyAttachmentStatus.RING_FULL)
        if self.duty_sequence >= UINT64_MAX:
            service.ring_full_recovery_at = seat_checked_add(
                tip_time, DELTA_RECOVERY_LAG, "sequence-exhausted recovery"
            )
            return DutyAttachmentOutcome(
                DutyAttachmentStatus.SEQUENCE_EXHAUSTED
            )
        self.duty_sequence += 1
        sequence = self.duty_sequence
        duty_id = seat_duty_id_v1(
            term_id, sequence, exact_base_sequence, exact_base_tip_slot
        )
        duty = Duty(
            duty_id=duty_id,
            term_id=term_id,
            tranche_id=self.seat_terms[term_id].tranche_id,
            operator=self.seat_terms[term_id].operator,
            sequence=sequence,
            ring_index=chosen,
            base_sequence=exact_base_sequence,
            base_tip_slot=exact_base_tip_slot,
            target_tip=target_tip,
            recovery_at=recovery_at,
            failover_at=failover_at,
            slash_at=slash_at,
        )
        self.seat_duties[duty_id] = duty
        self.term_duty[term_id] = duty_id
        self.duty_ring[chosen] = SeatDutyCell(sequence, duty_id, False)
        self.unresolved_duty_count = seat_checked_add(
            self.unresolved_duty_count, 1, "unresolved duty count"
        )
        if self.unresolved_duty_count > DUTY_RING_CAPACITY:
            raise AssertionError("unresolved duty count exceeds the fixed ring")
        service.ring_full_recovery_at = None
        return DutyAttachmentOutcome(DutyAttachmentStatus.ATTACHED, duty)

    def _transition_duty_status(
        self, duty: Duty, new_status: DutyStatus
    ) -> None:
        """Maintain the exact bounded unresolved counter on every transition."""

        if type(duty) is not Duty or type(new_status) is not DutyStatus:
            raise TypeError("duty status transition is malformed")
        old_unresolved = duty.status in (
            DutyStatus.OPEN, DutyStatus.FAILED_OVER
        )
        new_unresolved = new_status in (
            DutyStatus.OPEN, DutyStatus.FAILED_OVER
        )
        if old_unresolved and not new_unresolved:
            if self.unresolved_duty_count <= 0:
                raise AssertionError("unresolved duty counter underflow")
            self.unresolved_duty_count -= 1
        elif new_unresolved and not old_unresolved:
            self.unresolved_duty_count = seat_checked_add(
                self.unresolved_duty_count, 1, "unresolved duty count"
            )
            if self.unresolved_duty_count > DUTY_RING_CAPACITY:
                raise AssertionError(
                    "unresolved duty count exceeds the fixed ring"
                )
        duty.status = new_status

    def _start_seat_service(
        self,
        term_id: bytes,
        start: int,
        *,
        base_tip_slot: int,
        base_sequence: int,
    ) -> bool:
        service = self.seat_services[term_id]
        if service.closed_at is not None or service.responsibility_start is not None:
            raise AssertionError("seat service cannot start twice")
        if not self._runway_feasible():
            self._vacate_entire_lineup(start, "PROMOTION_RUNWAY_INFEASIBLE")
            return False
        minimum_tenure_until = seat_checked_add(
            start, self.minimum_primary_tenure_seconds, "minimum primary tenure"
        )
        premium_funded_until = seat_checked_add(
            start, self.seat_runway_seconds, "premium funded until"
        )
        service_eligible_until = seat_checked_sub(
            premium_funded_until,
            SLA_TAIL_SECONDS,
            "service eligible until",
        )
        service.responsibility_start = start
        service.minimum_tenure_until = minimum_tenure_until
        service.premium_funded_until = premium_funded_until
        service.service_eligible_until = service_eligible_until
        self._set_prospective_duty(term_id, base_tip_slot, base_sequence)
        self._clear_selected_successor()
        return True

    def install_seat_term_for_test(
        self,
        term: SeatTerm,
        *,
        rank: int,
        start_primary: bool,
    ) -> None:
        """Focused fixture primitive; production installation uses apply_stage."""

        if (
            type(term) is not SeatTerm
            or len(term.term_id) != 32
            or len(term.tranche_id) != 32
            or len(term.offer_id) != 32
            or term.term_id in self.seat_terms
            or term.tranche_id in self.seat_term_by_tranche
            or not 0 <= rank <= len(self.seat_lineup) < SEAT_COUNT
        ):
            raise ValueError("invalid synthetic seat term")
        self._record_seat_term(term)
        self.seat_services[term.term_id] = SeatService(
            None,
            seat_checked_add(
                term.installed_at,
                self.minimum_standby_tenure_seconds,
                "minimum standby tenure",
            ),
            None,
            None,
            standby_lease_expires_at=seat_checked_add(
                term.installed_at,
                self.maximum_standby_lease_seconds,
                "standby lease expiry",
            ),
        )
        revision_before = self.seat_lineup_revision
        self.seat_lineup.insert(rank, term.term_id)
        if start_primary:
            if rank != 0 or self.active_primary_term_id is not None:
                raise ValueError("direct service must fill a primary vacancy")
            self._start_seat_service(
                term.term_id,
                term.installed_at,
                base_tip_slot=self._fresh_service_base_tip(term.installed_at),
                base_sequence=self._seat_current_canonical_sequence(),
            )
        if self.seat_lineup_revision == revision_before:
            self._advance_lineup_revision()
        self._assert_seat_valid()

    def preview_premium_cap(self, term_id: bytes) -> int:
        """Bounded canonical-local upper cap, including omitted sync effects."""

        service = self.seat_services.get(term_id)
        if service is None:
            raise KeyError("unknown seat term")
        candidates: list[int] = []
        if service.closed_at is not None:
            candidates.append(service.closed_at)
        duty_id = self.term_duty.get(term_id)
        if duty_id is not None:
            duty = self.seat_duties[duty_id]
            # Premium stops at the first objective missed-service boundary.
            # A later canonical cure preserves chain liveness but cannot make
            # post-recovery non-service compensable.
            candidates.append(duty.recovery_at)
            if duty.satisfied_at is not None:
                candidates.append(duty.satisfied_at)
        else:
            recovery_at = service.prospective_recovery_at
            eligible_at = service.service_eligible_until
            if (
                recovery_at is not None
                and eligible_at is not None
                and recovery_at < eligible_at
            ):
                if (
                    self.duty_sequence < UINT64_MAX
                    and any(cell.reusable for cell in self.duty_ring)
                ):
                    # The prospective duty will make this exact recovery
                    # boundary permanent.  Do not provision premium through
                    # failover: service missing after recovery is never
                    # compensable even if a later commit preserves liveness.
                    candidates.append(recovery_at)
                else:
                    candidates.append(recovery_at)
            elif eligible_at is not None:
                candidates.append(eligible_at)
            elif recovery_at is not None:
                candidates.append(recovery_at)
        if not candidates:
            return 0
        return min(candidates)

    def _select_successor(
        self,
        *,
        selected_at: int,
        source: SelectionSource,
        trigger_duty_id: bytes | None = None,
        target_tip: int | None = None,
    ) -> None:
        if not self.seat_lineup:
            self._clear_selected_successor()
            return
        if (
            (source is SelectionSource.DUTY_FAILOVER)
            != (trigger_duty_id is not None)
        ):
            raise ValueError("selection source requires one exact predecessor duty")
        selected_at = seat_u256(selected_at, "successor selection time")
        term = self.seat_terms[self.seat_lineup[0]]
        if term.term_id in self.term_selection:
            self._vacate_entire_lineup(selected_at, "SELECTION_REPLAY")
            return
        exact_target_tip = (
            seat_checked_add(
                self.core.tip_slot,
                DELTA_RECOVERY_LAG,
                "selected successor target tip",
            )
            if target_tip is None
            else seat_u256(target_tip, "selected successor target tip")
        )
        selection_id = seat_selection_id_v1(
            term.term_id,
            term.tranche_id,
            term.offer_id,
            self._seat_current_canonical_sequence(),
            selected_at,
            exact_target_tip,
            source,
            trigger_duty_id,
        )
        self.seat_selection = SelectionRecord(
            selection_id,
            term.term_id,
            term.tranche_id,
            term.offer_id,
            self._seat_current_canonical_sequence(),
            selected_at,
            exact_target_tip,
            source,
            trigger_duty_id,
        )
        if selection_id in self.seat_selections:
            self._vacate_entire_lineup(selected_at, "SELECTION_ID_COLLISION")
            return
        self.seat_selections[selection_id] = self.seat_selection
        self.term_selection[term.term_id] = selection_id

    def _promote_selected(
        self, start: int, *, advance_lineup_revision: bool = True
    ) -> bool:
        term_id = self.selected_successor_term_id
        if term_id is None:
            return False
        if not self._recovery_revision_usable(start):
            self._vacate_entire_lineup(start, "PROMOTION_REVISION_UNUSABLE")
            return False
        fresh_base_tip = self._fresh_service_base_tip(start)
        started = self._start_seat_service(
            term_id,
            start,
            base_tip_slot=fresh_base_tip,
            base_sequence=self._seat_current_canonical_sequence(),
        )
        if started:
            self._invalidate_local_stage("PROMOTION")
        if started and advance_lineup_revision:
            self._advance_lineup_revision()
        return started

    def _recovery_revision_usable(self, start: int) -> bool:
        """Authenticate every canonical fact needed before successor liability."""

        if (
            self.seat_selection is None
            or not self.canonical_state_witness_available
            or not self.canonical_code_preimages_available
            or not self.seat_profile_ready
            or not self.seat_configuration_ready
            or not self._runway_feasible()
        ):
            return False
        selection = self.seat_selection
        term = self.seat_terms.get(selection.term_id)
        service = self.seat_services.get(selection.term_id)
        if (
            term is None
            or service is None
            or selection.term_id not in self.seat_lineup
            or self.seat_lineup[0] != selection.term_id
            or service.responsibility_start is not None
            or service.closed_at is not None
            or service.standby_lease_expires_at is None
            or start >= service.standby_lease_expires_at
            or term.tranche_id != selection.tranche_id
            or term.offer_id != selection.offer_id
        ):
            return False
        if selection.source is SelectionSource.DUTY_FAILOVER:
            duty = self.seat_duties.get(selection.predecessor_duty_id)
            if (
                duty is None
                or duty.status not in (
                    DutyStatus.FAILED_OVER,
                    DutyStatus.SATISFIED,
                    DutyStatus.BREACHED,
                )
            ):
                return False
        try:
            exact_start = seat_u256(start, "selected responsibility start")
            fresh_base_tip = self._fresh_service_base_tip(exact_start)
            tip_time = seat_checked_add(
                GENESIS_TIMESTAMP,
                fresh_base_tip,
                "selected prospective tip time",
            )
            seat_checked_add(
                fresh_base_tip,
                DELTA_RECOVERY_LAG,
                "selected prospective target",
            )
            seat_checked_add(
                tip_time,
                DELTA_RECOVERY_LAG,
                "selected prospective recovery",
            )
            seat_checked_add(
                tip_time,
                DELTA_FINAL_LAG,
                "selected prospective failover",
            )
            seat_checked_add(
                tip_time,
                DELTA_SLASH_LAG,
                "selected prospective slash",
            )
            seat_checked_add(
                exact_start,
                self.minimum_primary_tenure_seconds,
                "selected primary tenure",
            )
            funded_until = seat_checked_add(
                exact_start,
                self.seat_runway_seconds,
                "selected premium runway",
            )
            seat_checked_sub(
                funded_until,
                SLA_TAIL_SECONDS,
                "selected service eligibility",
            )
        except ValueError:
            return False
        return True

    def _process_activated_duty(self, duty: Duty, clock: Clock) -> bool:
        """Apply objective outcomes to one exact already-allocated duty."""

        changed = False
        if duty.status is DutyStatus.OPEN and clock.timestamp > duty.failover_at:
            self._transition_duty_status(duty, DutyStatus.FAILED_OVER)
            duty.disposition_at = duty.failover_at
            if self.seat_services[duty.term_id].closed_at is None:
                self._close_service(duty.term_id, duty.failover_at, "FAILED_OVER")
            if duty.term_id in self.seat_lineup:
                was_primary = self.seat_lineup[0] == duty.term_id
                self._remove_lineup_term(duty.term_id, clock.timestamp)
                if was_primary:
                    self._select_successor(
                        selected_at=clock.timestamp,
                        source=SelectionSource.DUTY_FAILOVER,
                        trigger_duty_id=duty.duty_id,
                        target_tip=duty.target_tip,
                    )
                self._advance_lineup_revision()
                self._invalidate_local_stage("FAILOVER")
            self.events.append(f"SEAT_FAILED_OVER:{duty.duty_id.hex()}")
            changed = True
        if duty.status is DutyStatus.FAILED_OVER and clock.timestamp > duty.slash_at:
            self._transition_duty_status(duty, DutyStatus.BREACHED)
            duty.disposition_at = clock.timestamp
            duty.breach_recorded_at = clock.timestamp
            self.events.append(f"SEAT_BREACH_RECORDED:{duty.duty_id.hex()}")
            changed = True
        return changed

    def _satisfy_activated_duty(self, duty: Duty, clock: Clock) -> bool:
        if duty.status not in (DutyStatus.OPEN, DutyStatus.FAILED_OVER):
            return False
        cured_after_failover = duty.status is DutyStatus.FAILED_OVER
        revision_before = self.seat_lineup_revision
        self._transition_duty_status(duty, DutyStatus.SATISFIED)
        if duty.satisfied_at is None:
            duty.satisfied_at = clock.timestamp
            duty.disposition_at = clock.timestamp
        start_successor = (
            cured_after_failover
            and self.seat_selection is not None
            and self.seat_selection.predecessor_duty_id == duty.duty_id
        )
        roster_changed = False
        if duty.term_id in self.seat_lineup:
            was_primary = self.seat_lineup[0] == duty.term_id
            self._close_service(duty.term_id, clock.timestamp, "SATISFIED")
            self._remove_lineup_term(duty.term_id, clock.timestamp)
            roster_changed = True
            if was_primary:
                self._select_successor(
                    selected_at=clock.timestamp,
                    source=SelectionSource.DUTY_FAILOVER,
                    trigger_duty_id=duty.duty_id,
                    target_tip=duty.target_tip,
                )
                start_successor = True
            self._invalidate_local_stage("DUTY_SATISFIED")
        if start_successor and self.selected_successor_term_id is not None:
            self._promote_selected(
                clock.timestamp,
                advance_lineup_revision=not roster_changed,
            )
        if roster_changed and self.seat_lineup_revision == revision_before:
            self._advance_lineup_revision()
        return True

    def _scan_seat_duties(
        self,
        clock: Clock,
        *,
        allow_cure: bool,
    ) -> SeatDutyScanOutcome:
        """Visit each ring cell once: objective outcome, cure, then excuse."""

        changed = False
        reusable_index: int | None = None
        satisfied = 0
        start_successor = False
        sla_missed = self.seat_sla_trigger_pending
        self.seat_scan_count = 0
        for index, cell in enumerate(tuple(self.duty_ring)):
            self.seat_scan_count += 1
            self.seat_scan_visits_total += 1
            if cell.reusable:
                if reusable_index is None:
                    reusable_index = index
                continue
            if cell.duty_id is None:
                continue
            duty = self.seat_duties[cell.duty_id]
            changed |= self._process_activated_duty(duty, clock)
            if (
                allow_cure
                and duty.status in (DutyStatus.OPEN, DutyStatus.FAILED_OVER)
                and clock.timestamp <= duty.slash_at
                and duty.operator == self.seat_terms[duty.term_id].operator
                and duty.tranche_id == self.seat_terms[duty.term_id].tranche_id
                and duty.term_id == self.seat_terms[duty.term_id].term_id
                and self._seat_current_canonical_sequence() > duty.base_sequence
                and self.core.tip_slot >= duty.target_tip
            ):
                self._satisfy_activated_duty(duty, clock)
                satisfied += 1
                changed = True
            if (
                allow_cure
                and duty.status is DutyStatus.FAILED_OVER
                and self.seat_selection is not None
                and self.seat_selection.predecessor_duty_id == duty.duty_id
                and self._seat_current_canonical_sequence() > duty.base_sequence
                and self.core.tip_slot >= duty.target_tip
            ):
                # Failover is economically irreversible, but the first usable
                # later canonical transition still starts the exact selected
                # successor so the optional seat service can recover.
                start_successor = True
            if (
                duty.status in (DutyStatus.OPEN, DutyStatus.FAILED_OVER)
                and clock.timestamp > duty.recovery_at
            ):
                sla_missed = True
        if (
            allow_cure
            and not start_successor
            and self.seat_selection is not None
            and self.seat_selection.predecessor_duty_id is None
            and self._seat_current_canonical_sequence()
                > self.seat_selection.selected_canonical_sequence
            and self.core.tip_slot >= self.seat_selection.target_tip
        ):
            start_successor = True
        if start_successor and self.selected_successor_term_id is not None:
            changed |= self._promote_selected(clock.timestamp)
        return SeatDutyScanOutcome(
            changed, reusable_index, sla_missed, satisfied
        )

    def _refresh_prospective_after_commit(self) -> bool:
        active = self.active_primary_term_id
        if active is None or active in self.term_duty:
            return False
        service = self.seat_services[active]
        if (
            service.duty_base_sequence is None
            or service.prospective_target_tip is None
            or self._seat_current_canonical_sequence()
                <= service.duty_base_sequence
            or self.core.tip_slot < service.prospective_target_tip
        ):
            return False
        self._set_prospective_duty(
            active,
            self.core.tip_slot,
            self._seat_current_canonical_sequence(),
        )
        return True

    def _sync_prospective_deadline(
        self,
        clock: Clock,
        reusable_index: int | None,
    ) -> tuple[bool, bool]:
        changed = False
        sla_missed = False
        # Resolve an implied duty before healthy expiry whenever its objective
        # recovery boundary is due through the funded cutoff.  A reclaimed
        # cell may attach only with the immutable original base; otherwise the
        # ring-full outcome wins at that same objective recovery timestamp.
        active = self.active_primary_term_id
        if active is not None and active not in self.term_duty:
            service = self.seat_services[active]
            eligible_at = service.service_eligible_until
            recovery_at = service.prospective_recovery_at
            if (
                eligible_at is not None
                and recovery_at is not None
                and recovery_at < eligible_at
                and clock.timestamp > recovery_at
            ):
                if reusable_index is not None:
                    attachment = self._attach_duty(
                        active, chosen_ring_index=reusable_index
                    )
                    if attachment.status is DutyAttachmentStatus.ATTACHED:
                        attached = attachment.duty
                        if attached is None:
                            raise AssertionError("attached duty result is empty")
                        changed = True
                        changed |= self._process_activated_duty(attached, clock)
                        sla_missed = attached.status in (
                            DutyStatus.OPEN, DutyStatus.FAILED_OVER
                        )
                    else:
                        service.ring_full_recovery_at = recovery_at
                        self.seat_sla_trigger_pending = True
                        reason = (
                            "DUTY_SEQUENCE_EXHAUSTED"
                            if attachment.status
                            is DutyAttachmentStatus.SEQUENCE_EXHAUSTED
                            else "DUTY_RING_FULL"
                        )
                        self._vacate_entire_lineup(
                            recovery_at,
                            reason,
                            removed_at=clock.timestamp,
                        )
                        return True, True
                else:
                    service.ring_full_recovery_at = recovery_at
                    self.seat_sla_trigger_pending = True
                    self._vacate_entire_lineup(
                        recovery_at,
                        "DUTY_RING_FULL",
                        removed_at=clock.timestamp,
                    )
                    return True, True
            elif eligible_at is not None and clock.timestamp >= eligible_at:
                self._close_service(active, eligible_at, "FUNDING_EXPIRED")
                self._remove_lineup_term(active, clock.timestamp)
                target_tip = (
                    service.prospective_target_tip
                    if service.prospective_target_tip is not None
                    else self.core.tip_slot
                )
                self._select_successor(
                    selected_at=clock.timestamp,
                    source=SelectionSource.HEALTHY_EXPIRY,
                    target_tip=target_tip,
                )
                self._advance_lineup_revision()
                self._invalidate_local_stage("FUNDING_EXPIRED")
                self._assert_seat_valid()
                return True, False
        self._assert_seat_valid()
        return changed, sla_missed

    def _sync_seat_deadlines(self, clock: Clock) -> bool:
        """Test/maintenance wrapper for a no-commit single-scan sync."""

        standby_changed = self._expire_standby_leases(clock)
        scan = self._scan_seat_duties(clock, allow_cure=False)
        prospective_changed, _ = self._sync_prospective_deadline(
            clock, scan.reusable_index
        )
        return standby_changed or scan.changed or prospective_changed

    def _expire_standby_leases(self, clock: Clock) -> bool:
        """Remove every due unstarted standby in one bounded roster pass."""

        due: list[tuple[bytes, int]] = []
        # The selected successor occupies rank zero while no primary serves;
        # it remains an unstarted standby and must not escape its immutable
        # lease merely because selection moved it out of ranks 1..3.
        for term_id in tuple(self.seat_lineup[:SEAT_COUNT]):
            service = self.seat_services[term_id]
            expiry = service.standby_lease_expires_at
            if (
                service.responsibility_start is None
                and expiry is not None
                and clock.timestamp >= expiry
            ):
                due.append((term_id, expiry))
        if not due:
            return False
        prior_selection = copy.deepcopy(self.seat_selection)
        for term_id, expiry in due:
            if self.selected_successor_term_id == term_id:
                self._clear_selected_successor()
            self._close_service(term_id, expiry, "STANDBY_LEASE_EXPIRED")
            # Liability ends at the objective lease boundary, even when a
            # keeper performs the bounded cleanup later.
            self._remove_lineup_term(term_id, expiry)
            self.events.append(f"SEAT_STANDBY_LEASE_EXPIRED:{term_id.hex()}")
        # Preserve the bounded liveness attempt with the next unexpired
        # standby, while permanently retaining the expired selection record.
        if prior_selection is not None and self.seat_selection is None:
            self._select_successor(
                selected_at=clock.timestamp,
                source=prior_selection.source,
                trigger_duty_id=prior_selection.predecessor_duty_id,
                target_tip=prior_selection.target_tip,
            )
        self._advance_lineup_revision()
        self._invalidate_local_stage("STANDBY_LEASE_EXPIRED")
        self._assert_seat_valid()
        return True

    def _latch_canonical_cures(self, clock: Clock) -> int:
        """Compatibility probe over the one canonical four-cell scan."""

        scan = self._scan_seat_duties(clock, allow_cure=True)
        self._refresh_prospective_after_commit()
        self._assert_seat_valid()
        return scan.satisfied

    @staticmethod
    def _market_module(market: object) -> Any:
        module = sys.modules.get(market.__class__.__module__)
        if module is None:
            raise TypeError("Market model module is unavailable")
        required = (
            "Clock",
            "InstallationView",
            "LineupSnapshot",
            "LineupTerm",
            "ServiceView",
            "ResultCode",
        )
        if any(not hasattr(module, name) for name in required):
            raise TypeError("object is not the exact SeatMarket model")
        return module

    @staticmethod
    def _restore_object(target: object, snapshot: dict[str, object]) -> None:
        target.__dict__.clear()
        target.__dict__.update(snapshot)

    def _canonical_transaction_snapshot(self) -> dict[str, object]:
        """Snapshot only L1 state; live L2 objects are outside the journal."""

        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "shared Settlement mutation guard is entered"
            )
        data_rent_sink = self.data_rent_sink
        return {
            "protocol": copy.deepcopy({
                key: value for key, value in self.__dict__.items()
                if key not in {
                    "normal_best", "header_oracle", "forced_queue",
                    "data_rent_sink",
                }
            }),
            "normal_best": self.normal_best,
            "header_oracle": self.header_oracle,
            "forced_queue": self.forced_queue,
            "forced_queue_state": self.forced_queue._transaction_snapshot(),
            "data_rent_sink": data_rent_sink,
            "data_rent_sink_state": copy.deepcopy(data_rent_sink.__dict__),
        }

    def _restore_canonical_transaction(
        self, snapshot: dict[str, object]
    ) -> None:
        """Restore a failed canonical transaction without breaking aliases."""

        queue = snapshot["forced_queue"]
        data_rent_sink = snapshot["data_rent_sink"]
        self._restore_object(self, snapshot["protocol"])
        object.__setattr__(self, "header_oracle", snapshot["header_oracle"])
        queue._restore_transaction_snapshot(snapshot["forced_queue_state"])
        self._restore_object(
            data_rent_sink, snapshot["data_rent_sink_state"]
        )
        object.__setattr__(self, "forced_queue", queue)
        object.__setattr__(self, "data_rent_sink", data_rent_sink)
        self.normal_best = snapshot["normal_best"]

    def _composed_seat_call(
        self, market: object, transition: Callable[[], object]
    ) -> object:
        settlement_snapshot = self._canonical_transaction_snapshot()
        market_snapshotter = getattr(market, "_transaction_snapshot", None)
        market_restorer = getattr(market, "_restore_transaction", None)
        if not callable(market_snapshotter) or not callable(market_restorer):
            raise ValueError("Market lacks the exact rollback surface")
        market_snapshot = market_snapshotter()
        try:
            self._assert_seat_valid()
            market.assert_valid()
            result = transition()
            self._assert_seat_valid()
            market.assert_valid()
            return result
        except BaseException:
            self._restore_canonical_transaction(settlement_snapshot)
            market_restorer(market_snapshot)
            raise

    def _leading_seat_sync(self, clock: Clock) -> bool:
        """Run canonical sync without persisting model-only read counters."""

        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "nested seat mutation hit the shared Settlement guard"
            )
        boundary_queries = self.boundary_queries
        seat_scan_count = self.seat_scan_count
        seat_scan_visits_total = self.seat_scan_visits_total
        changed = self.sync(clock)
        if not changed:
            self.boundary_queries = boundary_queries
            self.seat_scan_count = seat_scan_count
            self.seat_scan_visits_total = seat_scan_visits_total
        return changed

    def bind_seat_market_for_test(self, market: object) -> None:
        """Model fixture for immutable constructor/release-manager bindings."""

        self._market_module(market)
        if (
            market.authorization.target != self.settlement_address
            or market.cached_generation != self.seat_generation
            or market.seat_runway_seconds != self.seat_runway_seconds
            or market.handover_delay_seconds != HANDOVER_DELAY_SECONDS
            or market.stage_grace_seconds != STAGE_GRACE_SECONDS
            or market.maximum_inclusion_seconds != T_INCLUDE_MAX_SECONDS
            or market.maximum_standby_lease_seconds
            != self.maximum_standby_lease_seconds
            or market.minimum_standby_tenure_seconds
            != self.minimum_standby_tenure_seconds
        ):
            raise ValueError("Market/Settlement immutable configuration mismatch")
        if self.seat_authorization_id not in (None, market.current_authorization_id):
            raise ValueError("Settlement authorization binding changed")
        if self.seat_market_address not in (None, market.market_address):
            raise ValueError("Settlement Market target binding changed")
        self.seat_authorization_id = market.current_authorization_id
        self.seat_market_address = market.market_address

    def _bound_market_module(self, market: object) -> Any:
        module = self._market_module(market)
        if (
            self.seat_market_address is None
            or market.market_address != self.seat_market_address
        ):
            raise ValueError("call did not reach the immutable Market target")
        return module

    def _lineup_snapshot_for_market(self, market: object) -> object:
        module = self._bound_market_module(market)
        if self.seat_authorization_id is None:
            raise ValueError("Settlement has no installed Market authorization")
        rows = []
        active = self.active_primary_term_id
        for term_id in self.seat_lineup[:SEAT_COUNT]:
            term = self.seat_terms[term_id]
            service = self.seat_services[term_id]
            rows.append(
                module.LineupTerm(
                    term_id=term.term_id,
                    tranche_id=term.tranche_id,
                    offer_id=term.offer_id,
                    operator=term.operator,
                    payout=term.payout,
                    ask_wei_per_second=term.ask,
                    minimum_tenure_until=service.minimum_tenure_until,
                    service_eligible_until=(
                        service.service_eligible_until
                        if service.service_eligible_until is not None
                        else service.minimum_tenure_until
                    ),
                    healthy=(term_id == active),
                    installed_at=term.installed_at,
                )
            )
        return module.LineupSnapshot(
            target=self.settlement_address,
            authorization_id=self.seat_authorization_id,
            generation=self.seat_generation,
            commitment=self.seat_lineup_commitment(),
            terms=tuple(rows),
        )

    @staticmethod
    def _seat_history_disposition_v1(
        duty: Duty | None,
    ) -> tuple[int, int, int, int]:
        """Return disposition, timestamp, breach timestamp and unresolved count."""

        if duty is None:
            return 0, 0, 0, 0
        if duty.status is DutyStatus.OPEN:
            return 1, 0, 0, 1
        if duty.status is DutyStatus.FAILED_OVER:
            return 2, duty.disposition_at or duty.failover_at, 0, 1
        if duty.status is DutyStatus.SATISFIED:
            return 3, duty.disposition_at or duty.satisfied_at or 0, 0, 0
        if duty.status is DutyStatus.BREACHED:
            return (
                4,
                duty.disposition_at or duty.breach_recorded_at or 0,
                duty.breach_recorded_at or 0,
                0,
            )
        if duty.status is DutyStatus.EXCUSED:
            return 5, duty.disposition_at or 0, 0, 0
        if duty.status is DutyStatus.EXCUSED_MIGRATION:
            return 6, duty.disposition_at or 0, 0, 0
        raise AssertionError("unknown duty history disposition")

    @staticmethod
    def _seat_breach_receipt_id_v1(
        duty_id: bytes,
        term_id: bytes,
        tranche_id: bytes,
        breach_recorded_at: int,
    ) -> bytes:
        if (
            type(duty_id) is not bytes
            or len(duty_id) != 32
            or type(term_id) is not bytes
            or len(term_id) != 32
            or type(tranche_id) is not bytes
            or len(tranche_id) != 32
        ):
            raise ValueError("breach receipt identity is malformed")
        return keccak256(b"".join((
            b"TAIKO_SEAT_BREACH_V1",
            duty_id,
            term_id,
            tranche_id,
            _model_uint(breach_recorded_at, 8, "breach recorded at"),
        )))

    def _seat_history_rows_v1(
        self, term_id: bytes
    ) -> tuple[bytes, bytes | None]:
        """Encode the target-local permanent SHR1 term and optional duty rows."""

        term = self.seat_terms.get(term_id)
        service = self.seat_services.get(term_id)
        if term is None or service is None:
            raise ValueError("unknown SHR1 seat term")
        authorization_id = (
            self.seat_authorization_id
            if term.authorization_id is None
            else term.authorization_id
        )
        generation = (
            self.seat_generation if term.generation is None else term.generation
        )
        duty_id = self.term_duty.get(term_id)
        duty = self.seat_duties.get(duty_id) if duty_id is not None else None
        disposition, disposition_at, breach_at, unresolved = (
            self._seat_history_disposition_v1(duty)
        )
        breach_receipt_id = (
            bytes(32)
            if breach_at == 0 or duty is None
            else self._seat_breach_receipt_id_v1(
                duty.duty_id, term.term_id, term.tranche_id, breach_at
            )
        )
        duty_liability_at = 0 if duty is None else duty.slash_at
        last_liability_at = max(
            value
            for value in (
                term.installed_at,
                service.responsibility_start,
                service.closed_at,
                service.term_removed_at,
                duty_liability_at,
                disposition_at,
                breach_at,
                (
                    service.prospective_slash_at
                    if service.closed_at is None
                    else None
                ),
            )
            if value is not None
        )
        term_words = (
            b"SHR1" + bytes(28),
            authorization_id,
            _model_uint(generation, 32, "SHR1 generation"),
            term.term_id,
            term.tranche_id,
            bytes(12) + _model_address20(term.operator),
            _model_uint(
                service.responsibility_start or 0, 32, "SHR1 start"
            ),
            _model_uint(self.preview_premium_cap(term_id), 32, "SHR1 cap"),
            _model_uint(service.closed_at or 0, 32, "SHR1 close"),
            _model_uint(service.term_removed_at or 0, 32, "SHR1 removed"),
            _model_uint(last_liability_at, 32, "SHR1 liability"),
            _model_uint(unresolved, 32, "SHR1 unresolved count"),
            bytes(32) if duty is None else duty.duty_id,
            _model_uint(disposition, 32, "SHR1 disposition"),
            _model_uint(disposition_at, 32, "SHR1 disposition at"),
            breach_receipt_id,
            _model_uint(breach_at, 32, "SHR1 breach at"),
        )
        term_raw = b"".join(term_words)
        if len(term_raw) != 544:
            raise AssertionError("SHR1 term row length changed")
        if duty is None:
            return term_raw, None
        duty_words = (
            b"SHR1" + bytes(28),
            authorization_id,
            _model_uint(generation, 32, "SHR1 duty generation"),
            duty.duty_id,
            duty.term_id,
            duty.tranche_id,
            _model_uint(disposition, 32, "SHR1 duty disposition"),
            _model_uint(disposition_at, 32, "SHR1 duty disposition at"),
            _model_uint(last_liability_at, 32, "SHR1 duty liability"),
            breach_receipt_id,
            _model_uint(breach_at, 32, "SHR1 duty breach at"),
        )
        duty_raw = b"".join(duty_words)
        if len(duty_raw) != 352:
            raise AssertionError("SHR1 duty row length changed")
        return term_raw, duty_raw

    def seat_market_record_v1(self, term_id: bytes) -> bytes:
        return self._seat_history_rows_v1(term_id)[0]

    def seat_install_record_v1(self, term_id: bytes) -> bytes:
        term = self.seat_terms.get(term_id)
        if (
            term is None
            or term.authorization_id is None
            or term.generation is None
            or term.install_revision == 0
        ):
            raise ValueError("unknown canonical SIR1 install record")
        raw = b"".join((
            b"SIR1" + bytes(28),
            term.authorization_id,
            _model_uint(term.generation, 32, "SIR1 generation"),
            term.term_id,
            term.tranche_id,
            term.offer_id,
            bytes(12) + _model_address20(term.operator),
            bytes(12) + _model_address20(term.payout),
            _model_uint(term.ask, 32, "SIR1 ask"),
            _model_uint(term.installed_at, 32, "SIR1 installed at"),
            _model_uint(term.install_revision, 32, "SIR1 install revision"),
        ))
        if len(raw) != 352:
            raise AssertionError("SIR1 record length changed")
        return raw

    def seat_duty_record_v1(self, duty_id: bytes) -> bytes:
        duty = self.seat_duties.get(duty_id)
        if duty is None:
            raise ValueError("unknown SHR1 duty")
        duty_raw = self._seat_history_rows_v1(duty.term_id)[1]
        if duty_raw is None:
            raise AssertionError("known duty lost its SHR1 row")
        return duty_raw

    def _market_service_view(self, market: object, term_id: bytes) -> object:
        """Encode retained Settlement facts for the legacy behavioral oracle.

        Production Market entrypoints derive their own tranche/authorization
        and exact-decode SHR1 rows; this helper deliberately reads no Market
        storage or runtime object.
        """

        module = self._bound_market_module(market)
        term = self.seat_terms.get(term_id)
        service = self.seat_services.get(term_id)
        if term is None or service is None:
            raise ValueError("unknown exact seat term")
        # Production economic entrypoints derive their authorization and read
        # the target-local SHR1 row; this behavioral oracle reads the Market's
        # authorization for the same facts.
        auth = market.authorizations.get(self.seat_authorization_id)
        if auth is None:
            raise ValueError("Market authorization is absent")
        target = self.settlement_address
        settlement_chain_id = auth.settlement_chain_id
        protocol_version = auth.protocol_version
        runtime_hash = auth.runtime_hash
        configuration_hash = auth.configuration_hash
        magic = auth.expected_magic
        duty_id = self.term_duty.get(term_id)
        duty = self.seat_duties.get(duty_id) if duty_id is not None else None
        if duty is None:
            disposition = "NO_DUTY"
            disposition_at = None
            breached = False
            breach_at = None
            last_liability_at = max(
                value
                for value in (
                    term.installed_at,
                    service.responsibility_start,
                    service.closed_at,
                    service.term_removed_at,
                    (
                        service.prospective_slash_at
                        if service.closed_at is None
                        else None
                    ),
                )
                if value is not None
            )
        elif duty.status is DutyStatus.OPEN:
            disposition = "OPEN"
            disposition_at = None
            breached = False
            breach_at = None
            last_liability_at = duty.slash_at
        elif duty.status is DutyStatus.FAILED_OVER:
            disposition = "FAILED_OVER"
            disposition_at = duty.disposition_at
            breached = False
            breach_at = None
            last_liability_at = duty.slash_at
        elif duty.status is DutyStatus.SATISFIED:
            disposition = "SATISFIED"
            disposition_at = duty.disposition_at
            breached = False
            breach_at = None
            last_liability_at = duty.slash_at
        elif duty.status is DutyStatus.BREACHED:
            disposition = "BREACHED"
            disposition_at = duty.disposition_at
            breached = True
            breach_at = duty.breach_recorded_at
            last_liability_at = duty.slash_at
        elif duty.status is DutyStatus.EXCUSED_MIGRATION:
            disposition = "EXCUSED_MIGRATION"
            disposition_at = duty.disposition_at
            breached = False
            breach_at = None
            last_liability_at = duty.slash_at
        else:
            disposition = "EXCUSED"
            disposition_at = duty.disposition_at
            breached = False
            breach_at = None
            last_liability_at = duty.slash_at
        last_liability_at = max(
            value
            for value in (
                last_liability_at,
                duty.disposition_at if duty is not None else None,
                duty.breach_recorded_at if duty is not None else None,
                service.responsibility_start,
                service.closed_at,
                service.term_removed_at,
            )
            if value is not None
        )
        refundable = (
            service.closed_at is not None
            and disposition in {
                "NO_DUTY", "SATISFIED", "EXCUSED", "EXCUSED_MIGRATION"
            }
        )
        return module.ServiceView(
            target=target,
            authorization_id=(
                self.seat_authorization_id
                if term.authorization_id is None
                else term.authorization_id
            ),
            settlement_chain_id=settlement_chain_id,
            protocol_version=protocol_version,
            runtime_hash=runtime_hash,
            configuration_hash=configuration_hash,
            magic=magic,
            generation=(
                self.seat_generation
                if term.generation is None
                else term.generation
            ),
            term_id=term.term_id,
            tranche_id=term.tranche_id,
            offer_id=term.offer_id,
            operator=term.operator,
            payout=term.payout,
            ask_wei_per_second=term.ask,
            responsibility_start=service.responsibility_start,
            premium_funded_until=service.premium_funded_until,
            settlement_cap=self.preview_premium_cap(term_id),
            closed=service.closed_at is not None,
            refundable=refundable,
            disposition_at=disposition_at,
            last_liability_at=last_liability_at,
            duty_id=duty_id,
            duty_disposition=disposition,
            breached=breached,
            breach_recorded_at=breach_at,
            roster_occupied=term_id in self.seat_lineup,
            history_retained=True,
            service_close_at=service.closed_at,
            term_removed_at=service.term_removed_at,
        )

    def stage_best(self, market: object, clock: Clock) -> object:
        """Noncanonical façade; raw caller-supplied lineup views are not accepted."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        if self.mode is not Mode.NORMAL:
            raise ValueError("seat staging is unavailable")

        def transition() -> object:
            module = self._bound_market_module(market)
            snapshot = self._lineup_snapshot_for_market(market)
            result = market._settlement_stage_best(
                snapshot, module.Clock(clock.timestamp, clock.block_number)
            )
            if result.code is not module.ResultCode.STAGED:
                return result
            self._seat_fault("after_market_stage")
            market_stage = result.stage
            self.settlement_seat_stage = SettlementSeatStage(
                stage_id=market_stage.stage_id,
                offer_id=result.offer.offer_id,
                tranche_id=result.tranche.tranche_id,
                operator=result.offer.operator,
                payout=result.offer.payout,
                ask=result.offer.ask_wei_per_second,
                selected_rank=market_stage.selected_rank,
                outgoing_primary_term_id=market_stage.outgoing_primary_term_id,
                lineup_commitment=market_stage.lineup_commitment,
                handover_at=market_stage.handover_at,
                expires_at=market_stage.expires_at,
                target=self.settlement_address,
                authorization_id=self.seat_authorization_id,
                generation=self.seat_generation,
            )
            self._seat_fault("after_stage_recording")
            return result

        return self._composed_seat_call(market, transition)

    def apply_stage(self, market: object, clock: Clock) -> object:
        """Noncanonical exact-stage installation in one two-component domain."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        if self.mode is not Mode.NORMAL:
            raise ValueError("seat stage cannot apply outside healthy active mode")

        def transition() -> object:
            module = self._bound_market_module(market)
            stage = self.settlement_seat_stage
            if stage is None:
                raise ValueError("Settlement has no live stage")
            if (
                stage.target != self.settlement_address
                or stage.authorization_id != self.seat_authorization_id
                or stage.generation != self.seat_generation
                or stage.lineup_commitment != self.seat_lineup_commitment()
                or clock.timestamp < stage.handover_at
                or clock.timestamp > stage.expires_at
            ):
                raise ValueError("stage is stale or outside its exact interval")
            install_revision = seat_checked_add(
                self.seat_lineup_revision,
                1,
                "installed seat lineup revision",
            )
            term_id = self._seat_term_id(
                stage.authorization_id,
                stage.generation,
                stage.offer_id,
                stage.tranche_id,
                clock.timestamp,
                install_revision,
            )
            outgoing = stage.outgoing_primary_term_id
            if outgoing is not None:
                active = self.active_primary_term_id
                service = self.seat_services.get(outgoing)
                if service is None or service.closed_at is not None:
                    raise ValueError("outgoing seat is no longer live")
                if active == outgoing:
                    required_headroom_until = seat_checked_add(
                        stage.expires_at,
                        T_INCLUDE_MAX_SECONDS,
                        "stage inclusion headroom",
                    )
                    if (
                        service.service_eligible_until is None
                        or required_headroom_until
                        > service.service_eligible_until
                    ):
                        raise ValueError(
                            "outgoing primary is no longer healthy/funded"
                        )
                    close_reason = "HEALTHY_HANDOVER"
                else:
                    term = self.seat_terms[outgoing]
                    lease_expiry = seat_checked_add(
                        term.installed_at,
                        self.maximum_standby_lease_seconds,
                        "standby lease expiry",
                    )
                    if (
                        outgoing not in self.seat_lineup[1:]
                        or service.responsibility_start is not None
                        or clock.timestamp < service.minimum_tenure_until
                        or clock.timestamp >= lease_expiry
                    ):
                        raise ValueError("outgoing standby is not replaceable")
                    close_reason = "COMPETITIVE_STANDBY_REPLACEMENT"
                self._close_service(outgoing, clock.timestamp, close_reason)
                self._remove_lineup_term(outgoing, clock.timestamp)
                self._seat_fault("after_outgoing_close")
            install = module.InstallationView(
                target=stage.target,
                authorization_id=stage.authorization_id,
                generation=stage.generation,
                stage_id=stage.stage_id,
                term_id=term_id,
                offer_id=stage.offer_id,
                lineup_commitment=stage.lineup_commitment,
                applied_at=clock.timestamp,
            )
            term = SeatTerm(
                term_id,
                stage.tranche_id,
                stage.offer_id,
                stage.operator,
                stage.payout,
                stage.ask,
                clock.timestamp,
                stage.authorization_id,
                stage.generation,
                install_revision,
            )
            if (
                term.term_id in self.seat_terms
                or term.tranche_id in self.seat_term_by_tranche
                or not 0 <= stage.selected_rank <= len(self.seat_lineup)
                or len(self.seat_lineup) >= SEAT_COUNT
            ):
                raise ValueError("term installation collides with retained history")
            self._record_seat_term(term)
            self.seat_services[term.term_id] = SeatService(
                None,
                seat_checked_add(
                    clock.timestamp,
                    self.minimum_standby_tenure_seconds,
                    "minimum standby tenure",
                ),
                None,
                None,
                standby_lease_expires_at=seat_checked_add(
                    clock.timestamp,
                    self.maximum_standby_lease_seconds,
                    "standby lease expiry",
                ),
            )
            self.seat_lineup.insert(stage.selected_rank, term.term_id)
            if stage.selected_rank == 0:
                self._start_seat_service(
                    term.term_id,
                    clock.timestamp,
                    base_tip_slot=self._fresh_service_base_tip(clock.timestamp),
                    base_sequence=self._seat_current_canonical_sequence(),
                )
            if self.seat_lineup_revision != install_revision - 1:
                raise AssertionError("compound install changed lineup revision twice")
            self.seat_lineup_revision = install_revision
            self._seat_fault("after_term_install")
            self.settlement_seat_stage = None
            self._seat_fault("after_settlement_stage_clear")
            market_result = market._settlement_apply_stage_atomic(
                install,
                self._lineup_snapshot_for_market(market),
                module.Clock(clock.timestamp, clock.block_number),
            )
            self._seat_fault("after_market_install")
            return market_result

        return self._composed_seat_call(market, transition)

    def expire_stage(self, market: object, clock: Clock) -> object:
        """Permissionless ordinary expiry, atomic across both components."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"

        def transition() -> object:
            module = self._bound_market_module(market)
            stage = self.settlement_seat_stage
            if stage is None or clock.timestamp <= stage.expires_at:
                raise ValueError("exact stage has not expired")
            result = market._settlement_expire_stage(
                stage.stage_id, module.Clock(clock.timestamp, clock.block_number)
            )
            self._seat_fault("after_market_expiry")
            self.settlement_seat_stage = None
            self._seat_fault("after_settlement_stage_clear")
            return result

        return self._composed_seat_call(market, transition)

    def reconcile_stage_invalidation(
        self,
        market: object,
        stage_id: bytes,
        lineup_commitment: bytes,
        clock: Clock,
    ) -> object:
        """Authenticate one permanent canonical tombstone before Market restore."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"

        def transition() -> object:
            tombstone = self.stage_tombstones.get(stage_id)
            if (
                tombstone is None
                or tombstone.reconciled
                or tombstone.stage_id != stage_id
                or tombstone.lineup_commitment != lineup_commitment
            ):
                raise ValueError("stale or mismatched stage tombstone")
            result = market._settlement_invalidate_stage(
                stage_id, lineup_commitment
            )
            self._seat_fault("after_market_invalidation")
            tombstone.reconciled = True
            if self.outstanding_stage_tombstone_id == stage_id:
                self.outstanding_stage_tombstone_id = None
            self._seat_fault("after_tombstone_reconciliation")
            return result

        return self._composed_seat_call(market, transition)

    def installed_exit_at(self, term_id: bytes) -> int:
        term = self.seat_terms.get(term_id)
        service = self.seat_services.get(term_id)
        if term is None or service is None or service.exit_requested_at is None:
            raise ValueError("installed exit was not requested")
        delay_at = seat_checked_add(
            service.exit_requested_at, self.exit_delay_seconds, "installed exit delay"
        )
        if self.active_primary_term_id == term_id:
            return max(delay_at, service.minimum_tenure_until)
        return max(
            delay_at,
            seat_checked_add(
                term.installed_at,
                self.minimum_standby_tenure_seconds,
                "standby exit tenure",
            ),
        )

    def request_installed_exit(
        self, caller: str, term_id: bytes, clock: Clock
    ) -> object:
        """Immutable operator-only request; a leading sync owns due changes."""

        if self._leading_seat_sync(clock):
            return "SYNCED"
        term = self.seat_terms.get(term_id)
        service = self.seat_services.get(term_id)
        if (
            term is None
            or service is None
            or caller != term.operator
            or term_id not in self.seat_lineup
            or term_id == self.selected_successor_term_id
        ):
            raise ValueError("installed term cannot request exit")
        if service.exit_requested_at is None:
            delay_at = seat_checked_add(
                clock.timestamp, self.exit_delay_seconds, "installed exit delay"
            )
            role_floor = (
                service.minimum_tenure_until
                if self.active_primary_term_id == term_id
                else seat_checked_add(
                    term.installed_at,
                    self.minimum_standby_tenure_seconds,
                    "standby exit tenure",
                )
            )
            service.exit_requested_at = clock.timestamp
            deadline = max(delay_at, role_floor)
        else:
            deadline = self.installed_exit_at(term_id)
        self._assert_seat_valid()
        return deadline

    def finalize_installed_exit(
        self, market: object, term_id: bytes, clock: Clock
    ) -> object:
        """Settlement-local roster removal; reserve reconciliation is later."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"

        def transition() -> object:
            if (
                term_id not in self.seat_lineup
                or term_id == self.selected_successor_term_id
                or clock.timestamp < self.installed_exit_at(term_id)
            ):
                raise ValueError("installed exit is not removable")
            was_primary = self.active_primary_term_id == term_id
            revision_before = self.seat_lineup_revision
            self._close_service(term_id, clock.timestamp, "VOLUNTARY_EXIT")
            self._remove_lineup_term(term_id, clock.timestamp)
            self._seat_fault("after_exit_roster_removal")
            if was_primary and self.seat_lineup:
                successor = self.seat_lineup[0]
                if self.seat_services[successor].responsibility_start is not None:
                    raise AssertionError("voluntary successor already started")
                self._start_seat_service(
                    successor,
                    clock.timestamp,
                    base_tip_slot=self._fresh_service_base_tip(clock.timestamp),
                    base_sequence=self._seat_current_canonical_sequence(),
                )
            if self.seat_lineup_revision == revision_before:
                self._advance_lineup_revision()
            self._invalidate_local_stage("VOLUNTARY_EXIT")
            return "REMOVED"

        return self._composed_seat_call(market, transition)

    def accrue_seat_premium(
        self, market: object, term_id: bytes, clock: Clock
    ) -> object:
        """Production façade: callers supply an ID, never a dynamic ServiceView."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        if term_id == self.selected_successor_term_id:
            raise ValueError("selected successor has not started service")
        module = self._bound_market_module(market)
        return market._settlement_accrue_premium(
            self._market_service_view(market, term_id),
            module.Clock(clock.timestamp, clock.block_number),
        )

    def reconcile_seat_reserve(
        self, market: object, term_id: bytes, clock: Clock
    ) -> object:
        """Permissionless asynchronous close using only the bound term ID."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        module = self._bound_market_module(market)
        return self._composed_seat_call(
            market,
            lambda: market._settlement_close_reserve(
                self._market_service_view(market, term_id),
                module.Clock(clock.timestamp, clock.block_number),
                atomic_healthy=False,
            ),
        )

    def request_bond_release(
        self, market: object, tranche_id: bytes, term_id: bytes, clock: Clock
    ) -> object:
        """Permissionless façade deriving the exact retained Settlement view."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        module = self._bound_market_module(market)
        return market._settlement_request_release(
            tranche_id,
            self._market_service_view(market, term_id),
            module.Clock(clock.timestamp, clock.block_number),
        )

    def finalize_bond_release(
        self, market: object, tranche_id: bytes, term_id: bytes, clock: Clock
    ) -> object:
        """Permissionless terminalization with a coordinator-derived view."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        module = self._bound_market_module(market)
        return self._composed_seat_call(
            market,
            lambda: market._settlement_finalize_release(
                tranche_id,
                self._market_service_view(market, term_id),
                module.Clock(clock.timestamp, clock.block_number),
            ),
        )

    def enforce_seat_breach(
        self, market: object, tranche_id: bytes, term_id: bytes, clock: Clock
    ) -> object:
        """Permissionless breach façade; no caller-supplied receipt/view exists."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        module = self._bound_market_module(market)
        return self._composed_seat_call(
            market,
            lambda: market._settlement_enforce_breach(
                tranche_id,
                self._market_service_view(market, term_id),
                module.Clock(clock.timestamp, clock.block_number),
            ),
        )

    def reclaim_duty_cell(
        self,
        market: object,
        duty_id: bytes,
        term_id: bytes,
        tranche_id: bytes,
        clock: Clock,
    ) -> object:
        """Cache exact Market safety; leading sync defeats late ring-full races."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"

        def transition() -> object:
            duty = self.seat_duties.get(duty_id)
            if (
                duty is None
                or duty.term_id != term_id
                or duty.tranche_id != tranche_id
                or duty.status
                    not in (
                        DutyStatus.SATISFIED,
                        DutyStatus.BREACHED,
                        DutyStatus.EXCUSED,
                        DutyStatus.EXCUSED_MIGRATION,
                    )
            ):
                raise ValueError("duty binding is not terminal and exact")
            cell = self.duty_ring[duty.ring_index]
            if (
                cell.reusable
                or cell.duty_id != duty_id
                or cell.sequence != duty.sequence
            ):
                raise ValueError("duty cell tag is stale or already reusable")
            module = self._bound_market_module(market)
            safe = market._settlement_is_duty_history_safe(
                duty_id,
                term_id,
                tranche_id,
                self._market_service_view(market, term_id),
                module.Clock(clock.timestamp, clock.block_number),
            )
            self._seat_fault("after_market_history_read")
            if safe is not True:
                raise ValueError("Market duty history is not yet safe")
            cell.reusable = True
            self._seat_fault("after_duty_reusable_cache")
            return True

        return self._composed_seat_call(market, transition)

    @property
    def messages(self) -> list[Message]:
        """Compatibility view: Protocol owns no independent message list."""
        return self.forced_queue.descriptors

    def force_root(self, cutoff: int) -> str:
        if cutoff != self.forced_queue.count:
            raise ValueError("only the live forced-queue root can be frozen")
        # Production freezes the queue's stored append frontier.  Folding its
        # fixed 64 words is independent of retained descriptor history and
        # also fails closed if the stored wrapped root is inconsistent.
        root = force_wrapped_root(self.forced_queue.frontier, cutoff)
        assert root == self.forced_queue.root
        return root

    @staticmethod
    def _due_at(message: Message) -> int:
        return max(message.enqueued_at + FORCE_DELAY, message.due_at)

    def next_due_at(self, cursor: int, cutoff: int | None = None) -> int:
        self.boundary_queries += 1
        limit = len(self.messages) if cutoff is None else cutoff
        return self._due_at(self.messages[cursor]) if cursor < limit else UINT64_MAX

    def _boundary_due(self, cursor: int, clock: Clock) -> bool:
        """Return due only for a present queue boundary.

        ``UINT64_MAX`` is both a valid final deadline and the public getter's
        absent-value sentinel, so the existence bit must be checked first.
        """
        return (
            cursor < self.forced_queue.count
            and self.next_due_at(cursor) <= clock.timestamp
        )

    def force_due(self, clock: Clock) -> bool:
        return self._boundary_due(self.core.message_cursor, clock)

    def _prefix_end(self, start: int, cutoff: int,
                    gas_budget: int = FORCE_GAS_BUDGET) -> int:
        gas = size = count = 0
        cursor = start
        while cursor < min(cutoff, len(self.messages)):
            msg = self.messages[cursor]
            if (count + 1 > MAX_FORCE_MESSAGES
                    or gas + msg.accounted_gas > gas_budget
                    or size + msg.byte_length > FORCE_BYTES_BUDGET):
                break
            count += 1
            gas += msg.accounted_gas
            size += msg.byte_length
            cursor += 1
        return cursor

    def _clear_normal(self) -> None:
        self.normal_best = None
        self.normal_best_min_data_expiry = UINT64_MAX
        self.normal_deadline = None
        self.normal_required_through = None
        self.normal_min_admissible = None
        self.normal_admission_version = None
        self.normal_admission_root = None
        self.normal_anchor_number = None
        self.normal_anchor_hash = None
        self.normal_context_id = None
        self.normal_arm_block_number = None

    def arm_normal_context(self, clock: Clock) -> str:
        if self.sync(clock):
            return "SYNCED"
        if self.mode is not Mode.NORMAL:
            return "IGNORED"
        if self.normal_arm_block_number is not None:
            if clock.block_number <= self.normal_arm_block_number + MAX_ARM_AGE_BLOCKS:
                return "IGNORED"
            self.normal_arm_block_number = clock.block_number
            self.events.append(f"NORMAL_REARMED:{clock.block_number}")
            return "REARMED"
        self.normal_arm_block_number = clock.block_number
        self.events.append(f"NORMAL_ARMED:{clock.block_number}")
        return "ARMED"

    def activate_normal_context(self, clock: Clock) -> str:
        if self.sync(clock):
            return "SYNCED"
        armed = self.normal_arm_block_number
        if (self.mode is not Mode.NORMAL or armed is None
                or not armed < clock.block_number <= armed + MAX_ARM_AGE_BLOCKS):
            return "REJECTED"
        header = self.header_oracle.header(armed)
        self.normal_deadline = clock.timestamp + W_SETTLE_SECONDS
        self.normal_required_through = self.normal_deadline + T_INCLUDE_MAX_SECONDS
        self.normal_min_admissible = max(0, clock.l2_slot - DELTA_TIP)
        self.normal_admission_version = self.admission_version
        self.normal_admission_root = self.admission_root
        self.normal_anchor_number = armed
        self.normal_anchor_hash = header.block_hash
        self.normal_context_id = normal_context_id(
            self.canonical.base_hash, self.admission_version,
            self.admission_root, armed, header.block_hash)
        self.events.append(f"NORMAL_ACTIVATED:{self.normal_context_id}")
        return "ACTIVATED"

    def _close_mature_normal(
        self, clock: Clock
    ) -> tuple[bool, SeatDutyScanOutcome | None]:
        if self.normal_deadline is None or clock.timestamp < self.normal_deadline:
            return False, None
        protocol_snapshot = self._canonical_transaction_snapshot()
        try:
            outcome = None
            if (self.normal_best is not None
                    and not self._boundary_due(
                        self.normal_best.tip.message_end, clock
                    )
                    and clock.timestamp + REORG_MARGIN_SECONDS
                        <= self.normal_best_min_data_expiry):
                outcome = self._commit(self.normal_best, clock)
                self.events.append("NORMAL_COMMITTED")
            else:
                self.events.append("NORMAL_CANCELED_FORCE_OMISSION")
            self._clear_normal()
            return True, outcome
        except BaseException:
            self._restore_canonical_transaction(protocol_snapshot)
            raise

    def _new_round(
        self,
        clock: Clock,
        causes: Cause,
        revision: int,
        *,
        episode: int | None = None,
    ) -> RecoveryRound:
        anchor_number = clock.block_number - 1
        anchor = self.header_oracle.header(anchor_number)
        cutoff = self.forced_queue.count
        escape_slot = max(clock.l2_slot + ESCAPE_OFFSET, self.core.tip_slot + 1)
        round_episode = self.episode if episode is None else episode
        checked_u64_add(round_episode, 0, "recovery episode")
        checked_u64_add(revision, 0, "recovery revision")
        expires_at = checked_u64_add(
            checked_u64_add(
                GENESIS_TIMESTAMP,
                escape_slot,
                "recovery round absolute escape slot",
            ),
            DELTA_TIP,
            "recovery round expiry",
        )
        if expires_at == UINT64_MAX:
            raise ValueError("recovery expiry leaves no forced-ingress successor")
        return RecoveryRound(
            round_episode, revision, self.canonical.base_hash, clock.l2_slot,
            anchor_number, anchor.block_hash,
            self.force_root(cutoff), cutoff, self.admission_version,
            self.admission_root, escape_slot,
            expires_at, causes,
        )

    def _activate(self, clock: Clock, causes: Cause) -> None:
        next_episode = checked_u64_add(
            self.episode, 1, "recovery episode"
        )
        next_round = self._new_round(
            clock, causes, 1, episode=next_episode
        )
        self._clear_normal()
        self._invalidate_local_stage("RECOVERY_OPEN")
        self.seat_sla_trigger_pending = False
        self.mode = Mode.RECOVERY
        self.episode = next_episode
        self.recovery = next_round
        self.events.append(f"RECOVERY_OPEN:{self.episode}:{int(causes)}")

    def _roll_recovery(self, clock: Clock) -> bool:
        assert self.recovery is not None
        if clock.timestamp <= self.recovery.expires_at:
            return False
        old = self.recovery
        next_revision = checked_u64_add(
            old.revision, 1, "recovery revision"
        )
        self.recovery = self._new_round(
            clock, old.causes, next_revision
        )
        if self.selected_successor_term_id is not None:
            self._promote_selected(clock.timestamp)
        self.events.append(f"RECOVERY_ROLLED:{self.recovery.revision}")
        return True

    def data_session_config_hash_v1(self) -> bytes:
        """Commit every frozen immutable DataSession geometry/value input."""

        protocol_version = self._active_data_session_protocol_version()
        descriptor = b"".join((
            _model_uint(
                MODEL_SETTLEMENT_CHAIN_CONTEXT_ID, 32,
                "settlement chain id",
            ),
            _model_uint(protocol_version, 8, "protocol version"),
            _model_address20(self.settlement_address),
            _model_address20(self.data_rent_sink.address),
            _model_uint(self.data_session_required_bond, 32, "session bond"),
            _model_uint(self.data_session_base_rent_wei, 32, "base rent"),
            _model_uint(
                self.data_session_rent_per_published_byte_wei, 32,
                "byte rent",
            ),
            _model_uint(
                self.data_session_blob_base_fee_multiplier_bps, 2,
                "blob multiplier BPS",
            ),
            _model_uint(DATA_TTL_SECONDS, 8, "maximum TTL"),
            _model_uint(
                self.refund_claim_window_seconds, 8, "refund claim window"
            ),
            _model_uint(MAX_LIVE_DATA_SESSIONS, 2, "session cells"),
            _model_uint(MAX_DATA_SESSIONS_PER_OWNER, 2, "owner cap"),
            _model_uint(MAX_DATA_RECORDS_PER_SESSION, 2, "record cap"),
            _model_uint(MAX_GC_STEPS, 1, "maintenance steps"),
            _model_uint(self.data_session_max_blobs_per_post, 1, "blob cap"),
            _model_address20(POINT_EVALUATION_PRECOMPILE),
            _model_uint(POINT_EVALUATION_GAS, 4, "point evaluation gas"),
            _model_uint(BLS_MODULUS, 32, "BLS modulus"),
            _model_uint(131_072, 4, "blob gas used"),
            _model_uint(126_972, 4, "maximum blob payload"),
            _model_uint(9, 2, "chunk count cap"),
        ))
        if len(descriptor) != 268:
            raise AssertionError("DataSession config descriptor width drifted")
        return keccak256(
            b"slot-chain-data-session-config-v1"
            + _model_uint(len(descriptor), 4, "config descriptor length")
            + descriptor
        )

    def settlement_forced_ingress_floor_v1(self) -> bytes:
        """Return the exact due-time floor (SIF1) read by the ForcedQueue."""

        if self.forced_ingress_floor_fault_point in {"revert", "oog"}:
            raise RuntimeError("injected SIF1 staticcall fault")
        if self.mode is Mode.NORMAL:
            if self.recovery is not None:
                raise ValueError("normal Settlement retains a recovery round")
            minimum_due_at = 0
        elif self.mode is Mode.RECOVERY:
            if self.recovery is None:
                raise ValueError("recovery Settlement has no current round")
            minimum_due_at = checked_u64_add(
                self.recovery.expires_at,
                1,
                "Settlement forced-ingress recovery floor",
            )
        else:
            raise ValueError("unknown Settlement mode")
        result = encode_settlement_forced_ingress_floor_v1(minimum_due_at)
        return (
            result
            if self.forced_ingress_floor_return_override is None
            else self.forced_ingress_floor_return_override
        )

    def staticcall_settlement_forced_ingress_floor_v1(
        self, calldata: bytes, *, caller: str, value: int, gas: int,
    ) -> bytes:
        """Execute the selector-only, zero-value, exact-gas SIF1 envelope."""

        _ = caller
        if (type(calldata) is not bytes
                or calldata != SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR
                or value != 0
                or gas != SETTLEMENT_FORCED_INGRESS_FLOOR_GAS):
            raise ValueError("SIF1 staticcall envelope is noncanonical")
        return self.settlement_forced_ingress_floor_v1()

    def data_session_accounting_v1(self) -> bytes:
        self._assert_data_session_state(require_solvency=False)
        return encode_data_session_accounting_v1(DataSessionAccountingV1(
            self.session_live_count,
            self.session_refund_count,
            self.session_occupied_count,
            self.gc_cursor,
            self.next_session_sequence,
            self.data_session_live_bond_liability,
            self.data_session_refund_bond_liability,
            self.data_session_callback_entered,
            self.data_session_config_hash_v1(),
            self.reward_funded_by_class[1],
            self.reward_funded_by_class[2],
            self.reward_funded_by_class[3],
            self.total_reward_funding,
        ))

    def sync(self, clock: Clock) -> bool:
        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "nested sync hit the shared Settlement guard"
            )
        snapshot = self._canonical_transaction_snapshot()
        try:
            return self._sync_impl(clock)
        except BaseException:
            self._restore_canonical_transaction(snapshot)
            raise

    def _sync_impl(self, clock: Clock) -> bool:
        normal_changed = False
        standby_changed = self._expire_standby_leases(clock)
        commit_outcome: SeatDutyScanOutcome | None = None
        if (
            self.mode is Mode.NORMAL
            and self.normal_deadline is not None
            and clock.timestamp >= self.normal_deadline
        ):
            normal_changed, commit_outcome = self._close_mature_normal(clock)
        if commit_outcome is None:
            scan = self._scan_seat_duties(clock, allow_cure=False)
            prospective_changed, prospective_sla = \
                self._sync_prospective_deadline(
                    clock,
                    scan.reusable_index,
                )
            seat_changed = standby_changed or scan.changed or prospective_changed
            seat_sla_missed = scan.sla_missed or prospective_sla
        else:
            seat_changed = standby_changed or commit_outcome.changed
            seat_sla_missed = commit_outcome.sla_missed
        if self.mode is Mode.RECOVERY:
            return self._roll_recovery(clock) or seat_changed or normal_changed
        changed = seat_changed or normal_changed
        due = self.force_due(clock)
        if due and self.normal_deadline is not None and clock.timestamp < self.normal_deadline:
            self._clear_normal()
            self.events.append("NORMAL_CANCELED_FORCE_DUE")
            changed = True
        causes = Cause.NONE
        if seat_sla_missed:
            causes |= Cause.SLA
        elif (
            self.active_primary_term_id is None
            and strict_slot_lag_exceeds(
                clock.l2_slot, self.core.tip_slot, DELTA_FINAL_LAG
            )
        ):
            causes |= Cause.SLA
        if self.force_due(clock):
            causes |= Cause.FORCE_DUE
        if causes:
            self._activate(clock, causes)
            changed = True
        return changed

    def tombstone(self) -> None:
        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "nested admission mutation hit the shared Settlement guard"
            )
        self.admission_version += 1
        self.admission_root = f"admission:{self.admission_version}"

    def next_data_session_id(self, owner: str) -> str:
        return data_session_id(
            MODEL_SETTLEMENT_CHAIN_CONTEXT_ID,
            self.settlement_address,
            owner,
            self.next_session_sequence,
        )

    @property
    def sessions(self) -> dict[str, DataSession]:
        """Compatibility view of LIVE cells; never canonical stored state."""

        return {
            cell.session.session_id: cell.session
            for cell in self.session_cells
            if cell.tag is DataSessionCellTag.LIVE and cell.session is not None
        }

    @staticmethod
    def _sat_add64(left: int, right: int) -> int:
        if (type(left) is not int or type(right) is not int
                or not 0 <= left <= UINT64_MAX
                or not 0 <= right <= UINT64_MAX):
            raise ValueError("uint64 saturating-add input is malformed")
        return min(UINT64_MAX, left + right)

    def _data_session_cell(
        self, session_id: str
    ) -> tuple[int, DataSessionCell] | None:
        cell_plus_one = self.session_cell_by_id.get(session_id, 0)
        if not cell_plus_one:
            return None
        index = cell_plus_one - 1
        if not 0 <= index < MAX_LIVE_DATA_SESSIONS:
            raise AssertionError("data-session id index is out of range")
        cell = self.session_cells[index]
        if (not cell.structurally_valid(index)
                or cell.tag is DataSessionCellTag.FREE
                or cell.session is None
                or cell.session.session_id != session_id):
            raise AssertionError("data-session ring/index state diverged")
        return index, cell

    def _live_data_session(self, session_id: str) -> DataSession | None:
        located = self._data_session_cell(session_id)
        if located is None or located[1].tag is not DataSessionCellTag.LIVE:
            return None
        return located[1].session

    def data_session_cell_view(self, index: int) -> DataSessionCellView:
        """Mask stale union words into one canonical external view."""

        if type(index) is not int or not 0 <= index < MAX_LIVE_DATA_SESSIONS:
            return DataSessionCellView()
        cell = self.session_cells[index]
        if cell.tag is DataSessionCellTag.FREE or cell.session is None:
            return DataSessionCellView()
        session = cell.session
        if cell.tag is DataSessionCellTag.REFUND:
            return DataSessionCellView(
                DataSessionCellTag.REFUND.value,
                session.session_id,
                session.owner,
                session.refundable_bond,
                cell.refund_claim_deadline,
            )
        return DataSessionCellView(
            DataSessionCellTag.LIVE.value,
            session.session_id,
            session.owner,
            session.refundable_bond,
            0,
            session.sequence,
            session.expiry,
            session.count,
            session.sealed,
            session.root,
            tuple(session.frontier),
        )

    def data_session_view(self, session_id: str) -> DataSessionCellView:
        cell_plus_one = self.session_cell_by_id.get(session_id, 0)
        return self.data_session_cell_view(cell_plus_one - 1)

    @staticmethod
    def _exact_session_bytes32(value: str, name: str) -> bytes:
        if type(value) is not str or len(value) != 64:
            raise ValueError(f"{name} is not exact bytes32")
        try:
            return bytes.fromhex(value)
        except ValueError as exc:
            raise ValueError(f"{name} is not exact bytes32") from exc

    def data_session_cell_v1(self, index: int) -> bytes:
        view = self.data_session_cell_view(index)
        if view.tag == 0:
            row = DataSessionCellAbiV1()
        else:
            row = DataSessionCellAbiV1(
                view.tag,
                self._exact_session_bytes32(view.session_id, "session id"),
                _model_address20(view.owner),
                view.sequence,
                view.expiry,
                view.count,
                view.sealed,
                (bytes(32) if not view.root
                 else self._exact_session_bytes32(view.root, "session root")),
                view.frontier,
                view.refundable_bond,
                view.refund_claim_deadline,
            )
        return encode_data_session_cell_v1(row)

    def data_session_by_id_v1(self, session_id: str) -> bytes:
        cell_plus_one = self.session_cell_by_id.get(session_id, 0)
        if cell_plus_one == 0:
            row = DataSessionByIdAbiV1()
        else:
            view = self.data_session_cell_view(cell_plus_one - 1)
            row = DataSessionByIdAbiV1(
                cell_plus_one,
                view.tag,
                _model_address20(view.owner),
                view.sequence,
                view.expiry,
                view.count,
                view.sealed,
                (bytes(32) if not view.root
                 else self._exact_session_bytes32(view.root, "session root")),
                view.refundable_bond,
                view.refund_claim_deadline,
            )
        return encode_data_session_by_id_v1(row)

    def _assert_data_session_state(self, *, require_solvency: bool = True) -> None:
        try:
            self.reward_accounted_funding_v1
        except ValueError as exc:
            raise AssertionError("reward funding accounting diverged") from exc
        live = refund = occupied = 0
        owner_counts: dict[str, int] = {}
        live_liability = refund_liability = 0
        seen: dict[str, int] = {}
        for index, cell in enumerate(self.session_cells):
            if not cell.structurally_valid(index):
                raise AssertionError("data-session cell is malformed")
            if cell.tag is DataSessionCellTag.FREE:
                continue
            assert cell.session is not None
            session = cell.session
            if session.session_id in seen:
                raise AssertionError("data-session id is duplicated")
            seen[session.session_id] = index + 1
            occupied += 1
            if cell.tag is DataSessionCellTag.LIVE:
                live += 1
                owner_counts[session.owner] = owner_counts.get(session.owner, 0) + 1
                live_liability += session.refundable_bond
            else:
                refund += 1
                refund_liability += session.refundable_bond
        if (seen != self.session_cell_by_id
                or owner_counts != self.session_owner_live_count
                or any(count <= 0 or count > MAX_DATA_SESSIONS_PER_OWNER
                       for count in owner_counts.values())
                or type(self.session_live_count) is not int
                or not 0 <= self.session_live_count <= MAX_LIVE_DATA_SESSIONS
                or type(self.session_refund_count) is not int
                or not 0 <= self.session_refund_count <= MAX_LIVE_DATA_SESSIONS
                or type(self.session_occupied_count) is not int
                or not 0 <= self.session_occupied_count
                    <= MAX_LIVE_DATA_SESSIONS
                or live != self.session_live_count
                or refund != self.session_refund_count
                or occupied != self.session_occupied_count
                or occupied != live + refund
                or live_liability != self.data_session_live_bond_liability
                or refund_liability
                    != self.data_session_refund_bond_liability
                or type(self.gc_cursor) is not int
                or not 0 <= self.gc_cursor < MAX_LIVE_DATA_SESSIONS
                or (require_solvency
                    and self.settlement_eth_balance
                        < self.data_session_accounted_liabilities)):
            raise AssertionError("data-session bounded accounting diverged")

    def _install_data_session_for_test(
        self,
        session: DataSession,
        cell: int,
        *,
        tag: DataSessionCellTag = DataSessionCellTag.LIVE,
        refund_claim_deadline: int = 0,
    ) -> DataSession:
        """Seed one exact physical cell without weakening production OPEN."""

        if (type(session) is not DataSession
                or type(cell) is not int
                or not 0 <= cell < MAX_LIVE_DATA_SESSIONS
                or self.session_cells[cell].tag is not DataSessionCellTag.FREE
                or session.session_id in self.session_cell_by_id
                or tag not in {
                    DataSessionCellTag.LIVE, DataSessionCellTag.REFUND
                }
                or (tag is DataSessionCellTag.LIVE
                    and self.session_owner_live_count.get(session.owner, 0)
                        >= MAX_DATA_SESSIONS_PER_OWNER)
                or (tag is DataSessionCellTag.LIVE
                    and refund_claim_deadline != 0)
                or (tag is DataSessionCellTag.REFUND
                    and not 0 < refund_claim_deadline <= UINT64_MAX)):
            raise ValueError("data-session fixture cell is unavailable")
        installed = replace(session, cell_index=cell)
        self.session_cells[cell] = DataSessionCell(
            tag, installed, refund_claim_deadline
        )
        self.session_cell_by_id[installed.session_id] = cell + 1
        self.next_session_sequence = max(
            self.next_session_sequence, installed.sequence + 1
        )
        self.session_occupied_count += 1
        self.settlement_eth_balance += installed.refundable_bond
        if tag is DataSessionCellTag.LIVE:
            self.session_live_count += 1
            self.session_owner_live_count[installed.owner] = (
                self.session_owner_live_count.get(installed.owner, 0) + 1
            )
            self.data_session_live_bond_liability += installed.refundable_bond
        else:
            self.session_refund_count += 1
            self.data_session_refund_bond_liability += installed.refundable_bond
        self._assert_data_session_state()
        return installed

    def _live_to_refund(
        self,
        index: int,
        claim_deadline: int,
        *,
        emit_event: bool = True,
    ) -> DataSession:
        cell = self.session_cells[index]
        session = cell.session
        if (cell.tag is not DataSessionCellTag.LIVE
                or session is None
                or not 0 < claim_deadline <= UINT64_MAX
                or self.session_owner_live_count.get(session.owner, 0) <= 0
                or self.session_live_count <= 0
                or session.refundable_bond
                    > self.data_session_live_bond_liability):
            raise AssertionError("data-session ring/index state diverged")
        self.session_live_count -= 1
        self.session_refund_count += 1
        next_owner_count = self.session_owner_live_count[session.owner] - 1
        if next_owner_count:
            self.session_owner_live_count[session.owner] = next_owner_count
        else:
            del self.session_owner_live_count[session.owner]
        self.data_session_live_bond_liability -= session.refundable_bond
        self.data_session_refund_bond_liability = seat_checked_add(
            self.data_session_refund_bond_liability,
            session.refundable_bond,
            "data-session refund bond liability",
        )
        self.session_cells[index] = DataSessionCell(
            DataSessionCellTag.REFUND, session, claim_deadline
        )
        if emit_event:
            self.data_session_events.append(SessionLiveToRefundEvent(
                session.session_id,
                session.owner,
                index,
                claim_deadline,
            ))
        self._assert_data_session_state()
        return session

    def _clear_refund_cell(
        self, index: int, *, emit_forfeit: bool = False
    ) -> DataSession:
        cell = self.session_cells[index]
        session = cell.session
        if (cell.tag is not DataSessionCellTag.REFUND
                or session is None
                or self.session_refund_count <= 0
                or self.session_occupied_count <= 0
                or self.session_cell_by_id.get(session.session_id) != index + 1
                or session.refundable_bond
                    > self.data_session_refund_bond_liability):
            raise AssertionError("data-session refund state diverged")
        del self.session_cell_by_id[session.session_id]
        self.session_cells[index] = DataSessionCell()
        self.session_refund_count -= 1
        self.session_occupied_count -= 1
        self.data_session_refund_bond_liability -= session.refundable_bond
        if emit_forfeit:
            self.data_session_events.append(SessionRefundForfeitedEvent(
                session.session_id,
                session.owner,
                index,
                session.refundable_bond,
            ))
        return session

    @property
    def reward_accounted_funding_v1(self) -> int:
        if (type(self.reward_funded_by_class) is not dict
                or set(self.reward_funded_by_class) != {1, 2, 3}):
            raise ValueError("reward funding buckets are malformed")
        total = 0
        for class_id in (1, 2, 3):
            value = self.reward_funded_by_class[class_id]
            total = seat_checked_add(
                total, value, "reward funding bucket sum"
            )
        if (type(self.total_reward_funding) is not int
                or total != self.total_reward_funding):
            raise ValueError("total reward funding diverged")
        return total

    def _reward_funding_state_valid_v1(self) -> bool:
        """Check only the three buckets and aggregate custody scalars."""

        try:
            liabilities = self.data_session_accounted_liabilities
        except (TypeError, ValueError):
            return False
        return (type(self.settlement_eth_balance) is int
                and 0 <= liabilities <= self.settlement_eth_balance
                    <= SEAT_UINT256_MAX)

    @property
    def data_session_accounted_liabilities(self) -> int:
        session_liabilities = seat_checked_add(
            self.data_session_live_bond_liability,
            self.data_session_refund_bond_liability,
            "data-session accounted liabilities",
        )
        return seat_checked_add(
            session_liabilities,
            self.reward_accounted_funding_v1,
            "Settlement session/reward liabilities",
        )

    def force_data_session_eth(self, amount: int) -> bool:
        """Forced ETH is surplus and never becomes a refundable liability."""

        if type(amount) is not int or amount <= 0:
            return False
        self.settlement_eth_balance = seat_checked_add(
            self.settlement_eth_balance, amount, "Settlement forced balance"
        )
        return (self.settlement_eth_balance
                >= self.data_session_accounted_liabilities)

    def _scan_data_session_ring(
        self,
        clock: Clock,
        *,
        action: DataSessionMaintenanceMode,
    ) -> tuple[int, int]:
        """Inspect exactly eight consecutive cells; callbacks are impossible."""

        if (type(clock) is not Clock
                or type(action) is not DataSessionMaintenanceMode):
            raise ValueError("data-session GC clock is malformed")
        retained = (
            {ref.session_id for ref in self.normal_best.session_refs}
            if action is DataSessionMaintenanceMode.ORDINARY
            and self.normal_best is not None else set()
        )
        start = self.gc_cursor
        changed = 0
        for inspected in range(MAX_GC_STEPS):
            index = (start + inspected) % MAX_LIVE_DATA_SESSIONS
            cell = self.session_cells[index]
            if cell.tag is DataSessionCellTag.FREE:
                continue
            session = cell.session
            if (session is None
                    or self.session_cell_by_id.get(session.session_id)
                        != index + 1):
                raise AssertionError("data-session physical cell is stale")
            # A cell converted in this call cannot also be forfeited in it.
            if cell.tag is DataSessionCellTag.LIVE:
                if (action is DataSessionMaintenanceMode.ORDINARY
                        and session.expiry <= clock.timestamp
                        and session.session_id not in retained):
                    self._live_to_refund(
                        index,
                        self._sat_add64(
                            session.expiry, self.refund_claim_window_seconds
                        ),
                    )
                    changed += 1
            elif clock.timestamp > cell.refund_claim_deadline:
                # Forfeiture leaves ETH as sweepable rent/surplus.
                self._clear_refund_cell(index, emit_forfeit=True)
                changed += 1
        self.gc_cursor = (start + MAX_GC_STEPS) % MAX_LIVE_DATA_SESSIONS
        self.data_session_events.append(DataSessionsMaintainedEvent(
            action.value,
            start,
            self.gc_cursor,
            MAX_GC_STEPS,
            changed,
        ))
        self._assert_data_session_state()
        return changed, MAX_GC_STEPS

    def open_session(
        self,
        clock: Clock,
        owner: str,
        expected_empty_cell: int,
        expiry: int,
        *,
        payment: int = 0,
    ) -> str:
        """Atomically allocate one caller-selected FREE cell; never scans."""

        if self.data_session_callback_entered:
            raise DataSessionRevert("data-session OPEN authority rejected")
        session_sequence = self.next_session_sequence
        if (type(clock) is not Clock
                or not owner
                or type(expected_empty_cell) is not int
                or not 0 <= expected_empty_cell < MAX_LIVE_DATA_SESSIONS
                or self.session_cells[expected_empty_cell].tag
                    is not DataSessionCellTag.FREE
                or type(payment) is not int
                or type(expiry) is not int
                or not 0 <= expiry <= UINT64_MAX
                or expiry < clock.timestamp + P_PROVE_MAX
                    + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
                or expiry > clock.timestamp + DATA_TTL_SECONDS
                or session_sequence >= UINT64_MAX
                or self.session_owner_live_count.get(owner, 0)
                    >= MAX_DATA_SESSIONS_PER_OWNER
                or self.session_occupied_count >= MAX_LIVE_DATA_SESSIONS):
            raise DataSessionRevert("data-session OPEN preflight rejected")
        try:
            expected_payment = seat_checked_add(
                self.data_session_required_bond,
                self.data_session_base_rent_wei,
                "data-session OPEN payment",
            )
        except ValueError:
            raise DataSessionRevert("data-session OPEN fee overflow")
        if payment != expected_payment:
            raise DataSessionRevert("data-session OPEN payment is not exact")
        session_id = data_session_id(
            MODEL_SETTLEMENT_CHAIN_CONTEXT_ID,
            self.settlement_address,
            owner,
            session_sequence,
        )
        if session_id in self.session_cell_by_id:
            raise DataSessionRevert("data-session OPEN id collision")
        try:
            next_balance = seat_checked_add(
                self.settlement_eth_balance,
                payment,
                "data-session open balance",
            )
            next_live_liability = seat_checked_add(
                self.data_session_live_bond_liability,
                self.data_session_required_bond,
                "data-session live bond liability",
            )
        except ValueError:
            raise DataSessionRevert("data-session OPEN accounting overflow")
        session = DataSession(
            session_id,
            owner,
            expiry,
            refundable_bond=self.data_session_required_bond,
            cell_index=expected_empty_cell,
            sequence=session_sequence,
        )
        self.session_cells[expected_empty_cell] = DataSessionCell(
            DataSessionCellTag.LIVE, session, 0
        )
        self.session_cell_by_id[session_id] = expected_empty_cell + 1
        self.next_session_sequence = session_sequence + 1
        self.session_owner_live_count[owner] = (
            self.session_owner_live_count.get(owner, 0) + 1
        )
        self.session_live_count += 1
        self.session_occupied_count += 1
        self.settlement_eth_balance = next_balance
        self.data_session_live_bond_liability = next_live_liability
        self._assert_data_session_state()
        self.data_session_events.append(SessionOpenedEvent(
            session_id,
            owner,
            expected_empty_cell,
            session_sequence,
            expiry,
            self.data_session_required_bond,
            self.data_session_base_rent_wei,
        ))
        return session_id

    def _active_data_session_protocol_version(self) -> int:
        return self.data_session_protocol_version

    def derive_data_post(
        self,
        session: DataSession,
        record_index: int,
        post: DataPost,
        versioned_hash: bytes,
    ) -> tuple[bytes, int, bytes]:
        """Derive FS challenge, Appendix leaf, and exact precompile input."""

        if (type(session) is not DataSession
                or len(session.session_id) != 64
                or type(record_index) is not int
                or not 0 <= record_index < MAX_DATA_RECORDS_PER_SESSION
                or type(post) is not DataPost
                or not post.structurally_valid()
                or type(versioned_hash) is not bytes
                or len(versioned_hash) != 32
                or versioned_hash == bytes(32)
                or versioned_hash
                    != kzg_commitment_to_versioned_hash(post.commitment)):
            raise ValueError("derived data POST tuple is malformed")
        session_bytes = bytes.fromhex(session.session_id)
        publisher = _model_address20(session.owner)
        exact = b"".join((
            _model_uint(
                MODEL_SETTLEMENT_CHAIN_CONTEXT_ID, 32,
                "settlement chain id",
            ),
            _model_uint(
                self._active_data_session_protocol_version(), 32,
                "protocol version",
            ),
            session_bytes,
            versioned_hash,
            post.full_body_root,
            _model_uint(post.block_ordinal, 2, "block ordinal"),
            _model_uint(post.chunk_index, 2, "chunk index"),
            _model_uint(post.chunk_count, 2, "chunk count"),
            _model_uint(post.chunk_byte_length, 4, "chunk byte length"),
            post.chunk_root,
            publisher,
            _model_uint(session.expiry, 8, "session expiry"),
        ))
        z = int.from_bytes(
            keccak256(b"slot-chain-data-fs-v2" + exact), "big"
        ) % BLS_MODULUS
        leaf = keccak256(b"".join((
            b"slot-chain-data-leaf-v1",
            session_bytes,
            _model_uint(record_index, 2, "data record index"),
            versioned_hash,
            post.full_body_root,
            _model_uint(post.block_ordinal, 2, "block ordinal"),
            _model_uint(post.chunk_index, 2, "chunk index"),
            _model_uint(post.chunk_count, 2, "chunk count"),
            _model_uint(post.chunk_byte_length, 4, "chunk byte length"),
            post.chunk_root,
            publisher,
            _model_uint(session.expiry, 8, "session expiry"),
            _model_uint(z, 32, "FS challenge"),
            _model_uint(post.y, 32, "point evaluation y"),
        )))
        point_input = b"".join((
            versioned_hash,
            _model_uint(z, 32, "point evaluation z"),
            _model_uint(post.y, 32, "point evaluation y"),
            post.commitment,
            post.proof,
        ))
        if len(point_input) != 192:
            raise AssertionError("point-evaluation input length drifted")
        return leaf, z, point_input

    def data_session_post_fee(
        self,
        chunk_byte_lengths: tuple[int, ...],
        blob_count: int,
        blob_base_fee: int,
    ) -> int:
        """Exact checked fee order used by the payable POST selector."""

        if (type(chunk_byte_lengths) is not tuple
                or type(blob_count) is not int
                or not 0 < blob_count <= self.data_session_max_blobs_per_post
                or len(chunk_byte_lengths) != blob_count
                or any(type(length) is not int
                       or not 0 <= length <= 126_972
                       for length in chunk_byte_lengths)):
            raise ValueError("data-session POST geometry is malformed")
        total_bytes = 0
        for length in chunk_byte_lengths:
            total_bytes = seat_checked_add(
                total_bytes, length, "data-session published bytes"
            )
        byte_rent = checked_u256_mul(
            total_bytes,
            self.data_session_rent_per_published_byte_wei,
            "data-session byte rent",
        )
        blob_bytes = checked_u256_mul(
            131_072, blob_count, "data-session blob bytes"
        )
        blob_weight = checked_u256_mul(
            blob_bytes,
            self.data_session_blob_base_fee_multiplier_bps,
            "data-session blob weight",
        )
        blob_base_fee = seat_u256(blob_base_fee, "data-session blob base fee")
        # Solidity must use full-precision mulDivUp.  Python's unbounded
        # intermediate is the independent exact oracle; only the quotient is
        # required to fit one uint256 word.
        rounded_blob_cost = (
            blob_weight * blob_base_fee + 9_999
        ) // 10_000
        seat_u256(rounded_blob_cost, "data-session blob surcharge")
        return seat_checked_add(
            byte_rent, rounded_blob_cost, "data-session POST payment"
        )

    def post_data(
        self,
        clock: Clock,
        session_id: str,
        caller: str,
        *,
        posts: tuple[DataPost, ...],
        tx_blob_hashes: tuple[bytes, ...],
        blob_base_fee: int,
        payment: int,
    ) -> tuple[int, int, str]:
        if self.data_session_callback_entered:
            raise DataSessionRevert("data-session POST authority rejected")
        session = self._live_data_session(session_id)
        if (type(clock) is not Clock
                or session is None or session.owner != caller or session.sealed
                or session.expiry <= clock.timestamp
                or type(posts) is not tuple
                or type(tx_blob_hashes) is not tuple
                or not posts
                or any(type(post) is not DataPost
                       or not post.structurally_valid() for post in posts)
                or len(posts) != len(tx_blob_hashes)
                or any(type(versioned_hash) is not bytes
                       or len(versioned_hash) != 32
                       or versioned_hash == bytes(32)
                       for versioned_hash in tx_blob_hashes)
                or len(posts)
                    > self.data_session_max_blobs_per_post
                or type(payment) is not int
                or session.count + len(posts)
                    > MAX_DATA_RECORDS_PER_SESSION):
            raise DataSessionRevert("data-session POST preflight rejected")
        first_record_index = session.count
        derived_records: list[tuple[bytes, bytes, int]] = []
        for offset, (post, versioned_hash) in enumerate(
            zip(posts, tx_blob_hashes)
        ):
            try:
                leaf, _, point_input = self.derive_data_post(
                    session, session.count + offset, post, versioned_hash
                )
            except ValueError:
                raise DataSessionRevert("data-session POST derivation rejected")
            success, return_data = self.point_evaluation_adapter.staticcall(
                address=POINT_EVALUATION_PRECOMPILE,
                gas=POINT_EVALUATION_GAS,
                input_data=point_input,
            )
            if (not success
                    or len(return_data) != 64
                    or return_data != POINT_EVALUATION_OK):
                raise DataSessionRevert("data-session POST point evaluation rejected")
            derived_records.append((
                leaf, versioned_hash, post.chunk_byte_length
            ))
        try:
            expected_payment = self.data_session_post_fee(
                tuple(post.chunk_byte_length for post in posts),
                len(posts),
                blob_base_fee,
            )
        except ValueError:
            raise DataSessionRevert("data-session POST fee rejected")
        if payment != expected_payment:
            raise DataSessionRevert("data-session POST payment is not exact")
        try:
            next_balance = seat_checked_add(
                self.settlement_eth_balance,
                payment,
                "data-session POST balance",
            )
        except ValueError:
            raise DataSessionRevert("data-session POST balance overflow")
        next_frontier = list(session.frontier)
        next_count = session.count
        next_root = session.root
        pending_events: list[DataRecord] = []
        try:
            for (canonical_leaf, versioned_hash,
                 chunk_byte_length) in derived_records:
                index = next_count
                next_frontier, next_count, next_root = append_data_mmr(
                    next_frontier, next_count, canonical_leaf
                )
                pending_events.append(DataRecord(
                    session.session_id, index, versioned_hash, canonical_leaf,
                    chunk_byte_length,
                ))
        except ValueError:
            raise DataSessionRevert("data-session POST MMR append rejected")
        session.frontier = next_frontier
        session.count = next_count
        session.root = next_root
        self.settlement_eth_balance = next_balance
        self.data_record_events.extend(pending_events)
        self.data_session_events.extend(pending_events)
        self._assert_data_session_state()
        return first_record_index, next_count, next_root

    def seal_session(
        self, clock: Clock, session_id: str, caller: str
    ) -> tuple[int, str, int]:
        if self.data_session_callback_entered:
            raise DataSessionRevert("data-session SEAL authority rejected")
        session = self._live_data_session(session_id)
        if (type(clock) is not Clock
                or session is None or session.owner != caller
                or clock.timestamp >= session.expiry
                or session.sealed or session.count == 0):
            raise DataSessionRevert("data-session SEAL preflight rejected")
        session.sealed = True
        self.data_session_events.append(SessionSealedEvent(
            session.session_id, session.count, session.root, session.expiry
        ))
        return session.count, session.root, session.expiry

    def claim_data_session_refund(
        self,
        clock: Clock,
        session_id: str,
        caller: str,
        recipient: DataSessionBondReceiver,
    ) -> int:
        """Owner-only O(1) CEI claim; transfer failure restores exact state."""

        if self.data_session_callback_entered:
            raise DataSessionRevert("reentrant data-session claim")
        try:
            liabilities = self.data_session_accounted_liabilities
        except ValueError as exc:
            raise DataSessionRevert(
                "data-session custody liabilities overflowed"
            ) from exc
        if self.settlement_eth_balance < liabilities:
            raise DataSessionRevert("data-session custody is insolvent")
        if (type(clock) is not Clock
                or not session_id or not caller
                or type(recipient) is not DataSessionBondReceiver
                or not recipient.address):
            raise DataSessionRevert("data-session claim preflight failed")
        located = self._data_session_cell(session_id)
        if located is None:
            raise DataSessionRevert("data-session refund id is absent")
        index, cell = located
        session = cell.session
        if session is None or session.owner != caller:
            raise DataSessionRevert("data-session refund owner is invalid")
        claim_deadline = cell.refund_claim_deadline
        if cell.tag is DataSessionCellTag.LIVE:
            retained = (
                {ref.session_id for ref in self.normal_best.session_refs}
                if self.normal_best is not None else set()
            )
            if (session.expiry <= clock.timestamp
                    and session_id not in retained):
                claim_deadline = self._sat_add64(
                    session.expiry, self.refund_claim_window_seconds
                )
            else:
                raise DataSessionRevert("LIVE data-session refund is ineligible")
        elif cell.tag is not DataSessionCellTag.REFUND:
            raise DataSessionRevert("data-session refund tag is invalid")
        if not 0 < claim_deadline or clock.timestamp > claim_deadline:
            raise DataSessionRevert("data-session refund deadline elapsed")
        amount = session.refundable_bond
        if amount <= 0:
            raise DataSessionRevert("data-session refund bond is zero")
        snapshot = self._canonical_transaction_snapshot()
        before_receiver_state = copy.deepcopy(recipient.__dict__)
        self.data_session_callback_entered = True
        try:
            if cell.tag is DataSessionCellTag.LIVE:
                self._live_to_refund(
                    index, claim_deadline, emit_event=False
                )
            self._clear_refund_cell(index)
            self.settlement_eth_balance -= amount
            if not recipient.receive(self, session_id, amount):
                raise RuntimeError("data-session refund receiver rejected")
            self.data_session_events.append(SessionBondClaimedEvent(
                session_id, caller, recipient.address, amount
            ))
            self._assert_data_session_state()
            return amount
        except BaseException as exc:
            self._restore_canonical_transaction(snapshot)
            self._restore_object(recipient, before_receiver_state)
            self._assert_data_session_state()
            raise DataSessionRevert(
                "data-session refund transfer reverted"
            ) from exc
        finally:
            self.data_session_callback_entered = False

    def sweep_session_surplus(self) -> int:
        """Permissionless non-gating sweep to the immutable data-rent sink."""

        if self.data_session_callback_entered:
            raise DataSessionRevert("reentrant data-session surplus sweep")
        try:
            liabilities = self.data_session_accounted_liabilities
        except ValueError as exc:
            raise DataSessionRevert(
                "data-session custody liabilities overflowed"
            ) from exc
        if self.settlement_eth_balance < liabilities:
            raise DataSessionRevert("data-session custody is insolvent")
        amount = self.settlement_eth_balance - liabilities
        if amount == 0:
            return 0
        snapshot = self._canonical_transaction_snapshot()
        self.data_session_callback_entered = True
        try:
            self.settlement_eth_balance -= amount
            if not self.data_rent_sink.receive(self, amount):
                raise RuntimeError("data-rent sink rejected")
            self.data_session_events.append(SessionSurplusSweptEvent(
                self.data_rent_sink.address, amount
            ))
            self._assert_data_session_state()
            return amount
        except BaseException as exc:
            self._restore_canonical_transaction(snapshot)
            self._assert_data_session_state()
            raise DataSessionRevert(
                "data-rent sink transfer reverted"
            ) from exc
        finally:
            self.data_session_callback_entered = False

    def maintain_data_sessions(
        self, clock: Clock
    ) -> tuple[int, int, int, int]:
        """Return exact status, explicit inspections, transitions and cursor."""

        if (self.data_session_callback_entered
                or type(clock) is not Clock):
            return SESSION_MAINTENANCE_NOOP, 0, 0, self.gc_cursor
        # An ordinary scan never follows a changed leading sync.
        if self.sync(clock):
            return SESSION_MAINTENANCE_SYNCED, 0, 0, self.gc_cursor
        changed, inspected = self._scan_data_session_ring(
            clock, action=DataSessionMaintenanceMode.ORDINARY
        )
        return (
            SESSION_MAINTENANCE_SCANNED,
            inspected,
            changed,
            self.gc_cursor,
        )

    def gc_sessions(self, clock: Clock) -> tuple[int, int, int, int]:
        """Compatibility alias for fixed-work session maintenance."""

        return self.maintain_data_sessions(clock)

    def _sessions_ok(self, candidate: Candidate, clock: Clock) -> bool:
        session_ids = tuple(ref.session_id for ref in candidate.session_refs)
        if (len(candidate.session_refs) > MAX_DATA_SESSIONS_PER_CANDIDATE
                or session_ids != tuple(sorted(session_ids))
                or len(set(session_ids)) != len(session_ids)
                or any(type(ref.session_id) is not str
                       or len(ref.session_id) != 64
                       or type(ref.count) is not int
                       or not 0 < ref.count <= MAX_DATA_RECORDS_PER_SESSION
                       or type(ref.root) is not str
                       or len(ref.root) != 64
                       for ref in candidate.session_refs)):
            return False
        used = [r for b in candidate.blocks for r in b.data_records]
        if len(used) > MAX_DATA_RECORDS_PER_CANDIDATE or len(used) != len(set(used)):
            return False
        declared = {r.session_id: r for r in candidate.session_refs}
        for ref in candidate.session_refs:
            session = self.sessions.get(ref.session_id)
            if (session is None or not session.sealed
                    or session.expiry < clock.timestamp + REORG_MARGIN_SECONDS
                    or ref.count != session.count or ref.root != session.root):
                return False
        return candidate.manifest_exact and all(
            sid in declared and 0 <= index < declared[sid].count for sid, index in used)

    def _anchor_ok(self, candidate: Candidate, clock: Clock) -> bool:
        anchors = {(b.anchor_number, b.anchor_hash, b.anchor_timestamp,
                    b.force_root, b.force_cutoff) for b in candidate.blocks}
        if len(anchors) != 1:
            return False
        block = candidate.blocks[0]
        try:
            header = self.header_oracle.header(block.anchor_number)
        except KeyError:
            header = None
        if (header is None or block.anchor_number >= clock.block_number
                or header.block_hash != block.anchor_hash
                or header.timestamp != block.anchor_timestamp
                or block.anchor_timestamp > GENESIS_TIMESTAMP + block.slot):
            return False
        if candidate.tier is Tier.NORMAL_SIGNED:
            return (self.normal_anchor_number is not None
                    and block.anchor_number == self.normal_anchor_number
                    and block.anchor_hash == self.normal_anchor_hash
                    and header.force_root == block.force_root
                    and header.force_cutoff == block.force_cutoff)
        assert self.recovery is not None
        return (block.force_root == self.recovery.force_root
                and block.force_cutoff == self.recovery.force_cutoff)

    def _validate_common(self, candidate: Candidate, clock: Clock, min_slot: int) -> bool:
        if (not self.canonical_state_witness_available
                or not self.canonical_code_preimages_available
                or not candidate.proof_ok or not candidate.force_range_proof_ok
                or candidate.base_canonical_hash != self.canonical.base_hash
                or not 0 < candidate.count <= MAX_BLOCKS_PER_CANDIDATE
                or candidate.end_l2_block_number
                    != self.core.l2_block_number + candidate.count
                or candidate.end_l2_block_number > UINT48_MAX
                or candidate.next_base_fee <= 0
                or candidate.next_excess_blob_gas < 0
                or not self._reward_profile_bindings_valid_v1()
                or not reward_candidate_metrics_valid_v1(candidate, self)
                or any(type(block) is not Block
                       or block.tier is not candidate.tier
                       for block in candidate.blocks)
                or len({b.window for b in candidate.blocks}) > MAX_WINDOWS_PER_CANDIDATE
                or candidate.blocks[0].slot <= self.core.tip_slot
                or any(b.slot < min_slot for b in candidate.blocks)
                or candidate.tip.slot > clock.l2_slot + CLOCK_SKEW
                or not candidate.beneficiary or not self._anchor_ok(candidate, clock)
                or not self._sessions_ok(candidate, clock)):
            return False
        parent, cursor, prior_slot = self.core.tip_hash, self.core.message_cursor, self.core.tip_slot
        first = candidate.blocks[0]
        total_items = total_bytes = total_gas = 0
        for block in candidate.blocks:
            if (block.evm_timestamp != GENESIS_TIMESTAMP + block.slot
                    or block.forced_tx_fork is not self.forced_tx_fork
                    or block.forced_tx_chain_id != self.forced_tx_chain_id
                    or block is first and block.forced_tx_base_fee
                        != self.core.next_base_fee
                    or block.parent_hash != parent or block.slot <= prior_slot
                    or (candidate.tier is Tier.NORMAL_SIGNED
                        and block.slot - prior_slot > G_MAX)
                    or block.message_start != cursor or not block.dispositions_ok
                    or block.anchor_number != first.anchor_number
                    or block.force_cutoff != first.force_cutoff
                    or block.force_root != first.force_root):
                return False
            expected = self._prefix_end(cursor, block.force_cutoff)
            if block.message_end != expected:
                return False
            try:
                forced_block_rows(
                    self.messages, block, candidate.available_payload_hashes
                )
            except ValueError:
                return False
            for msg in self.messages[cursor:block.message_end]:
                if (msg.payload_hash
                            not in candidate.available_payload_hashes
                        and msg.valid_until >= GENESIS_TIMESTAMP + block.slot):
                    return False
                total_items += 1
                total_bytes += msg.byte_length
                total_gas += msg.accounted_gas
            parent, prior_slot, cursor = block.block_hash, block.slot, block.message_end
        return (total_items <= MAX_FORCE_CANDIDATE_MESSAGES
                and total_bytes <= MAX_FORCE_CANDIDATE_BYTES
                and total_gas <= MAX_FORCE_CANDIDATE_GAS
                and candidate.next_due_at == self.next_due_at(cursor, first.force_cutoff))

    def _valid_normal(self, candidate: Candidate, clock: Clock) -> bool:
        if (candidate.tier is not Tier.NORMAL_SIGNED
                or not candidate.recovery_fields_zero
                or self.normal_deadline is None
                or self.normal_min_admissible is None
                or self.normal_admission_version is None
                or self.normal_admission_root is None
                or self.normal_context_id is None):
            return False
        minimum = self.normal_min_admissible
        version = self.normal_admission_version
        root = self.normal_admission_root
        context = self.normal_context_id
        deadline = self.normal_deadline
        assert self.normal_required_through is not None
        required_through = self.normal_required_through
        return (self._validate_common(candidate, clock, minimum)
                and all(b.scheduled_signature_ok and b.admission_version == version
                        and b.admission_root == root
                        and b.context_id == context
                        for b in candidate.blocks)
                and all(self.sessions[r.session_id].expiry
                        >= deadline + REORG_MARGIN_SECONDS for r in candidate.session_refs)
                and self.next_due_at(candidate.tip.message_end) > required_through)

    def _valid_recovery(self, candidate: Candidate, clock: Clock) -> bool:
        round_ = self.recovery
        if round_ is None or not self._validate_common(candidate, clock, round_.round_start_slot):
            return False
        first = candidate.blocks[0]
        if (candidate.episode != round_.episode
                or candidate.recovery_revision != round_.revision
                or candidate.recovery_id != round_.recovery_id
                or candidate.base_canonical_hash != round_.base_canonical_hash
                or first.anchor_number != round_.anchor_number
                or first.anchor_hash != round_.anchor_hash
                or any(b.context_id != round_.recovery_id
                       for b in candidate.blocks)
                or any(b.admission_version != round_.admission_version
                       or b.admission_root != round_.admission_root for b in candidate.blocks)
                or clock.block_number - round_.anchor_number < F_L1
                or strict_slot_lag_exceeds(
                    clock.l2_slot, candidate.tip.slot, DELTA_TIP
                )
                or clock.timestamp > round_.expires_at):
            return False
        if round_.causes & Cause.FORCE_DUE and candidate.tip.message_end <= self.core.message_cursor:
            return False
        if candidate.tier is Tier.RECOVERY_SIGNED:
            return all(b.scheduled_signature_ok for b in candidate.blocks)
        if candidate.tier is Tier.ESCAPE_UNSIGNED:
            return (candidate.count == 1 and candidate.tip.slot == round_.escape_slot
                    and not first.scheduled_signature_ok and not first.discretionary_body
                    and not first.data_records and not candidate.session_refs)
        return False

    def submit(self, candidate: Candidate, clock: Clock) -> str:
        if self.data_session_callback_entered:
            raise SharedSettlementReentrancy(
                "nested candidate submission hit the shared Settlement guard"
            )
        if self.mode is Mode.RECOVERY:
            round_ = self.recovery
            if round_ is None or clock.timestamp > round_.expires_at:
                return "SYNCED" if self.sync(clock) else "REJECTED"
            if not self._valid_recovery(candidate, clock):
                return "SYNCED" if self.sync(clock) else "REJECTED"
            self._commit(candidate, clock)
            self.mode = Mode.NORMAL
            self.recovery = None
            self.events.append("RECOVERY_COMMITTED")
            return "COMMITTED"
        if self.sync(clock):
            return "SYNCED"
        if self.mode is Mode.NORMAL:
            if not self._valid_normal(candidate, clock):
                return "REJECTED"
            if self.normal_best is None or candidate.order > self.normal_best.order:
                self.normal_best = candidate
                self.normal_best_min_data_expiry = min(
                    (self.sessions[ref.session_id].expiry
                     for ref in candidate.session_refs),
                    default=UINT64_MAX,
                )
                return "ACCEPTED"
            return "IGNORED"
        raise AssertionError("non-recovery submit reached recovery branch")

    def _save_checkpoint_to_l1_signal_service(self) -> None:
        """Model ``SignalService.saveCheckpoint`` called from the Inbox proxy.

        Settlement performs this write inside the same internal transition
        that writes ``Canonical`` (normal close, recovery commit, escape
        commit), exactly once per canonical L2 block number.  The call MUST
        succeed: a revert rolls the canonical commit back.  It cannot be
        front-run or omitted, and it is keyed by ``uint48`` L2 block number.
        """

        core = self.core
        if not 0 <= core.l2_block_number <= UINT48_MAX:
            raise AssertionError("checkpoint L2 block number exceeds uint48")
        if core.l2_block_number in self.l1_signal_service_checkpoints:
            raise AssertionError(
                "L1 checkpoint is saved exactly once per L2 block number"
            )
        self.l1_signal_service_checkpoints[core.l2_block_number] = {
            "tipHash": core.tip_hash,
            "stateRoot": core.state_root,
        }

    def _commit(
        self,
        candidate: Candidate,
        clock: Clock,
    ) -> SeatDutyScanOutcome:
        protocol_snapshot = self._canonical_transaction_snapshot()
        try:
            assert self.forced_queue.cursor == self.core.message_cursor
            if not self.forced_queue.advance_cursor(
                settlement=self,
                expected_start=candidate.blocks[0].message_start,
                end=candidate.tip.message_end,
                beneficiary=candidate.beneficiary,
            ):
                raise AssertionError(
                    "canonical queue advance authority is invalid"
                )
            self.canonical = Canonical(
                CanonicalCore(candidate.end_l2_block_number,
                              candidate.tip.block_hash, candidate.tip.slot,
                              candidate.end_state_root, candidate.tip.message_end,
                              candidate.winning_data_commitment,
                              candidate.next_base_fee,
                              candidate.next_excess_blob_gas),
                clock.block_number,
            )
            # Same-transaction L1 SignalService checkpoint write.
            self._save_checkpoint_to_l1_signal_service()
            self._seat_fault("after_checkpoint_save")
            if self.seat_canonical_sequence >= UINT64_MAX:
                raise AssertionError("seat canonical sequence exhausted")
            self.seat_canonical_sequence += 1
            scan = self._scan_seat_duties(clock, allow_cure=True)
            refreshed = self._refresh_prospective_after_commit()
            prospective_changed, prospective_sla = \
                self._sync_prospective_deadline(
                    clock,
                    scan.reusable_index,
                )
            outcome = SeatDutyScanOutcome(
                scan.changed or refreshed or prospective_changed,
                scan.reusable_index,
                scan.sla_missed or prospective_sla,
                scan.satisfied,
            )
            self._record_reward_receipt_v1(candidate, clock)
            self.events.append(f"CANONICAL:{candidate.candidate_id}")
            self._assert_seat_valid()
            return outcome
        except BaseException:
            self._restore_canonical_transaction(protocol_snapshot)
            raise


def valid_forced_ingress_static(
    descriptor: Message, *, clock: Clock, deposit: int,
    fork: ForcedTxFork = ForcedTxFork.FUSAKA,
) -> bool:
    """Kind-0 admission grammar checked by ``enqueueForcedTransactionV2``."""

    if (type(descriptor) is not Message
            or type(clock) is not Clock
            or type(deposit) is not int or isinstance(deposit, bool)
            or deposit <= 0 or not descriptor.payload_hash
            or descriptor.kind is not ForceKind.USER_TX):
        return False
    if (any(type(value) is not int for value in (
            descriptor.nonce, descriptor.intrinsic_gas, descriptor.valid_until,
            descriptor.byte_length, descriptor.raw_tx_length,
            descriptor.l2_chain_id, descriptor.gas_limit,
            descriptor.max_fee, descriptor.accounted_gas))
            or any(type(value) is not bool for value in (
                descriptor.outer_authorized, descriptor.chain_id_ok,
                descriptor.signature_ok))
            or type(descriptor.payload_hash) is not str
            or type(descriptor.sender) is not str
            or not 0 <= descriptor.valid_until <= UINT64_MAX):
        return False
    if forced_transaction_static_errors(
            descriptor, descriptor.transaction, fork, descriptor.l2_chain_id):
        return False
    intrinsic, _ = forced_transaction_gas(descriptor.transaction, fork)
    return (
        descriptor.outer_authorized
        and descriptor.intrinsic_gas == intrinsic
        and descriptor.chain_id_ok
        and descriptor.signature_ok
        and bool(descriptor.sender)
        and descriptor.valid_until > clock.timestamp
        and descriptor.valid_until
            <= clock.timestamp + MAX_FORCE_VALIDITY_SECONDS
        and 0 < descriptor.byte_length <= MAX_FORCE_MESSAGE_BYTES
        and descriptor.raw_tx_length == descriptor.byte_length
        and 0 < descriptor.l2_chain_id <= UINT64_MAX
        and intrinsic <= descriptor.gas_limit <= UINT64_MAX
        and 0 < descriptor.max_fee <= SEAT_UINT256_MAX
        and descriptor.refund_address == descriptor.sender
        and descriptor.accounted_gas == max(
            descriptor.gas_limit,
            descriptor.intrinsic_gas,
            MIN_FORCE_ACCOUNTED_GAS,
        )
        and descriptor.accounted_gas <= MAX_FORCE_MESSAGE_GAS
    )


ForcedDispositionRow = tuple[int, int, int, str]


def forced_block_rows(
    messages: list[Message], block: Block,
    available_payload_hashes: frozenset[str],
) -> tuple[ForcedDispositionRow, ...]:
    """Derive every disposition and FIFO tx index from typed proof inputs.

    Dispositions are circuit-internal: the validity proof enforces the
    ``0 -> 1 -> 2 -> 3 -> 6 -> 4`` classification and the maximal prefix, and
    nothing writes them to L2 or L1.  Each row is ``(queueIndex, code,
    txIndex or UINT32_MAX, payloadHash or "")``.
    """

    witnesses = block.forced_tx_witnesses
    if (type(witnesses) is not tuple
            or any(type(row) is not ForcedTxExecutionWitness
                   or type(row.queue_index) is not int for row in witnesses)):
        raise ValueError("forced witness range is malformed")
    expected_indices = tuple(
        index for index in range(block.message_start, block.message_end)
        if type(messages[index]) is Message
        and messages[index].valid_until >= block.evm_timestamp
    )
    if tuple(row.queue_index for row in witnesses) != expected_indices:
        raise ValueError("forced witnesses are not the exact unexpired range")
    by_index = {row.queue_index: row for row in witnesses}
    rows: list[ForcedDispositionRow] = []
    # There are no protocol system transactions: the included forced prefix
    # opens the block body at transaction index zero.
    tx_index = 0
    for index in range(block.message_start, block.message_end):
        queued = messages[index]
        outcome = classify_forced_transaction(
            queued, timestamp=block.evm_timestamp, fork=block.forced_tx_fork,
            chain_id=block.forced_tx_chain_id, base_fee=block.forced_tx_base_fee,
            witness=by_index.get(index),
            raw_available=queued.payload_hash in available_payload_hashes,
        )
        included = outcome is ForcedDisposition.INCLUDED_TX
        rows.append((index, int(outcome), tx_index if included else UINT32_MAX,
                     queued.payload_hash if included else ""))
        tx_index += int(included)
    return tuple(rows)


def forced_execution_witnesses_for_test(
    messages: list[Message], start: int, end: int,
    timestamp: int, fork: ForcedTxFork, chain_id: int, base_fee: int,
) -> tuple[ForcedTxExecutionWitness, ...]:
    """Synthetic inert-recipient fixtures; not a general EVM interpreter.

    Nontrivial EVM state changes require explicit sequential witnesses. Default
    fixtures execute empty-code recipients and update the sender nonce/balance;
    they no longer claim every unexpired transaction was discarded as expired.
    """

    states: dict[str, ForcedSenderState] = {}
    witnesses: list[ForcedTxExecutionWitness] = []
    for index in range(start, end):
        row = messages[index]
        if type(row) is not Message or row.valid_until < timestamp:
            continue
        sender = states.get(row.sender, ForcedSenderState())
        witness = ForcedTxExecutionWitness(
            index, row.payload_hash, row.transaction, sender,
            authentication=ForcedRawAuthentication(row.sender, row.l2_chain_id),
        )
        witnesses.append(witness)
        disposition = classify_forced_transaction(
            row, timestamp=timestamp, fork=fork, chain_id=chain_id,
            base_fee=base_fee, witness=witness, raw_available=True,
        )
        if disposition is ForcedDisposition.INCLUDED_TX:
            intrinsic, floor = forced_transaction_gas(row.transaction, fork)
            gas_price = (min(row.max_fee, base_fee + row.transaction.max_priority_fee)
                         if row.transaction.tx_type == 2 else row.max_fee)
            states[row.sender] = replace(
                sender, nonce=sender.nonce + 1,
                balance=sender.balance - max(intrinsic, floor) * gas_price
                    - row.transaction.value,
            )
    return tuple(witnesses)


@dataclass
class QueueContinuity:
    """ForcedQueue: depth-64 frontier, kind-0 envelopes, direct ingress.

    ``enqueue`` is the permissionless ``enqueueForcedTransactionV2`` entry
    point that lives directly on the ForcedQueue contract.  It reads the
    Settlement's forced-ingress floor (SIF1) by a bounded static call to the
    Inbox proxy and computes ``enqueuedAt``/``dueAt`` itself.  Only the
    Settlement (the Inbox proxy address, a constructor immutable) may advance
    the cursor.  The queue rejects enqueue before activation binds it.
    """

    address: str
    root: str
    count: int
    cursor: int
    escrow_balance: int
    last_due_at: int
    descriptors: list[Message] = field(default_factory=list)
    frontier: list[bytes] = field(default_factory=list)
    settlement_address: str = ""
    l2_chain_id: int = 167_000
    ingress_fee_schedule: tuple[int, int, int, int, int] = field(
        default_factory=lambda: (
            INGRESS_FIXED_WEI,
            INGRESS_EXECUTION_WEI_PER_GAS,
            INGRESS_PROOF_WEI_PER_GAS,
            INGRESS_PERMANENT_WEI_PER_BYTE,
            INGRESS_MAXIMUM_ACCEPTED_FEE_WEI,
        )
    )
    claimable: dict[str, int] = field(default_factory=dict)
    runtime_hash: str = "code:forced-queue:v3"
    config_hash: str = "config:forced-queue:depth64:v3"
    deposit_prefix: list[int] = field(default_factory=list)
    unconsumed_escrow: int | None = None
    total_claimable: int | None = None
    append_fault_point: str | None = field(default=None, compare=False)
    ingress_entered: bool = field(default=False, compare=False)
    _settlement: object | None = field(
        default=None, init=False, compare=False, repr=False
    )

    def __setattr__(self, name: str, value: object) -> None:
        immutable = {
            "address", "settlement_address", "l2_chain_id",
            "ingress_fee_schedule", "runtime_hash", "config_hash",
            "_settlement",
        }
        if name in immutable and name in self.__dict__:
            raise AttributeError(f"forced queue {name} is immutable")
        object.__setattr__(self, name, value)

    def __post_init__(self) -> None:
        if (type(self.count) is not int
                or not 0 <= self.count <= MAX_FORCE_QUEUE_ITEMS
                or len(self.descriptors) != self.count):
            raise ValueError("forced queue count does not bind descriptors")
        if (type(self.settlement_address) is not str
                or not self.settlement_address
                or type(self.l2_chain_id) is not int
                or not 0 < self.l2_chain_id <= UINT64_MAX):
            raise ValueError("forced queue Settlement binding is malformed")
        validate_ingress_fee_schedule(self.ingress_fee_schedule)
        # Constructor reconstruction is a deployment-fixture oracle.  Production
        # append below touches only one descriptor and 64 frontier words; it
        # never recomputes over descriptor history.
        expected_frontier = force_frontier_from_descriptors(self.descriptors)
        if not self.frontier:
            self.frontier = expected_frontier
        if (type(self.frontier) is not list
                or len(self.frontier) != FORCE_TREE_DEPTH
                or any(type(row) is not bytes or len(row) != 32
                       for row in self.frontier)
                or self.frontier != expected_frontier
                or self.root != force_wrapped_root(self.frontier, self.count)):
            raise ValueError("forced queue frontier/root is inconsistent")
        if not self.deposit_prefix:
            self.deposit_prefix = [0]
            for row in self.descriptors:
                self.deposit_prefix.append(
                    self.deposit_prefix[-1] + row.prepaid)
        assert len(self.deposit_prefix) == self.count + 1
        if self.unconsumed_escrow is None:
            self.unconsumed_escrow = (
                self.deposit_prefix[self.count]
                - self.deposit_prefix[self.cursor])
        if self.total_claimable is None:
            self.total_claimable = sum(self.claimable.values())
        assert (self.escrow_balance
                >= self.unconsumed_escrow + self.total_claimable)

    def __deepcopy__(self, memo: dict[int, object]) -> "QueueContinuity":
        """Copy state; the bound Settlement follows the memo, never a clone."""

        duplicate = object.__new__(type(self))
        memo[id(self)] = duplicate
        for key, value in self.__dict__.items():
            if key == "_settlement":
                object.__setattr__(duplicate, key, memo.get(id(value), value))
            else:
                object.__setattr__(duplicate, key, copy.deepcopy(value, memo))
        return duplicate

    def _bind_settlement_once(self, settlement: object) -> bool:
        """Bind the one Settlement (Inbox proxy) at activation."""

        if (self._settlement is not None
                or getattr(settlement, "forced_queue", None) is not self
                or getattr(settlement, "settlement_address", None)
                    != self.settlement_address):
            return False
        object.__setattr__(self, "_settlement", settlement)
        return True

    def _transaction_snapshot(self) -> dict[str, object]:
        return copy.deepcopy({
            key: value for key, value in self.__dict__.items()
            if key != "_settlement"
        })

    def _restore_transaction_snapshot(
        self, snapshot: dict[str, object]
    ) -> None:
        settlement = self._settlement
        self.__dict__.clear()
        self.__dict__.update(snapshot)
        object.__setattr__(self, "_settlement", settlement)

    @property
    def accounted_liabilities(self) -> int:
        assert self.unconsumed_escrow is not None
        assert self.total_claimable is not None
        return self.unconsumed_escrow + self.total_claimable

    def force_eth(self, amount: int) -> bool:
        """Model ETH received outside append (for example SELFDESTRUCT)."""
        if amount <= 0:
            return False
        self.escrow_balance += amount
        assert self.escrow_balance >= self.accounted_liabilities
        return True

    def required_ingress_deposit(self, descriptor: Message) -> int:
        """``fixedIngressWei + accountedGas * (execution + proof) + bytes``."""

        return ingress_deposit_for_schedule(
            descriptor.accounted_gas,
            descriptor.byte_length,
            self.ingress_fee_schedule,
        )

    def _append(
        self, descriptor: Message, *, deposit: int, due_at: int,
    ) -> int | None:
        if (not descriptor.payload_hash or deposit <= 0
                or descriptor.prepaid != deposit
                or due_at < self.last_due_at
                or self.count >= MAX_FORCE_QUEUE_ITEMS
                or self.count != len(self.descriptors)):
            return None
        index = self.count
        stored = replace(descriptor, due_at=due_at)
        leaf = bytes.fromhex(durable_queue_leaf_hash(stored, index))
        next_frontier = _append_frontier_leaf(
            self.frontier,
            index,
            leaf,
            node_domain=b"slot-chain-force-node-v2",
        )
        next_count = index + 1
        next_root = force_wrapped_root(next_frontier, next_count)
        self.descriptors.append(stored)
        if self.append_fault_point == "after_descriptor":
            raise RuntimeError("injected queue append fault: after_descriptor")
        self.frontier = next_frontier
        self.count = next_count
        self.escrow_balance += deposit
        assert self.unconsumed_escrow is not None
        self.unconsumed_escrow += deposit
        self.deposit_prefix.append(self.deposit_prefix[-1] + deposit)
        self.last_due_at = due_at
        self.root = next_root
        return index

    def enqueue(
        self, clock: Clock, envelope: Message, *, caller: str, deposit: int,
    ) -> str:
        """``enqueueForcedTransactionV2``: payable, permissionless, kind 0.

        ``dueAt = max(enqueuedAt + FORCE_DELAY, lastDueAt, minimumDueAt)``
        where ``minimumDueAt`` is Settlement's SIF1 floor read by an exact
        bounded static call.  A live but expired recovery floor rejects until
        the Settlement is synced; nothing here mutates the Settlement.
        """

        settlement = self._settlement
        if settlement is None:
            raise ValueError("forced queue rejects enqueue before activation")
        if (type(clock) is not Clock or type(envelope) is not Message
                or not caller or caller != envelope.sender
                or envelope.kind is not ForceKind.USER_TX
                or envelope.l2_chain_id != self.l2_chain_id
                or type(deposit) is not int or isinstance(deposit, bool)
                or deposit <= 0 or envelope.prepaid != deposit
                or deposit != self.required_ingress_deposit(envelope)
                or not valid_forced_ingress_static(
                    envelope, clock=clock, deposit=deposit,
                    fork=settlement.forced_tx_fork,
                )):
            raise ValueError("kind-0 payable ingress precheck reverted")
        if self.ingress_entered:
            raise RuntimeError("forced queue ingress is non-reentrant")
        if self.count >= settlement.queue_capacity:
            raise ValueError("forced queue is at capacity")
        queue_before = self._transaction_snapshot()
        self.ingress_entered = True
        try:
            enqueued_at = checked_u64_add(
                clock.timestamp, 0, "forced ingress enqueuedAt"
            )
            base_due_at = checked_u64_add(
                enqueued_at, FORCE_DELAY, "forced ingress base dueAt"
            )
            last_due_at = checked_u64_add(
                self.last_due_at, 0, "forced ingress previous dueAt"
            )
            try:
                minimum_due_at = decode_settlement_forced_ingress_floor_v1(
                    settlement.staticcall_settlement_forced_ingress_floor_v1(
                        SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR,
                        caller=self.address,
                        value=0,
                        gas=SETTLEMENT_FORCED_INGRESS_FLOOR_GAS,
                    )
                )
            except (ValueError, OverflowError, RuntimeError) as exc:
                raise ValueError(
                    "Settlement forced-ingress floor is invalid"
                ) from exc
            if minimum_due_at != 0 and clock.timestamp >= minimum_due_at:
                raise ValueError(
                    "active recovery forced-ingress floor is expired"
                )
            due_at = max(base_due_at, last_due_at, minimum_due_at)
            expected_index = self.count
            index = self._append(
                replace(envelope, enqueued_at=enqueued_at),
                deposit=deposit,
                due_at=due_at,
            )
            if index != expected_index:
                raise ValueError("forced queue rejected validated append")
            return f"QUEUED:{index}"
        except BaseException:
            self._restore_transaction_snapshot(queue_before)
            raise
        finally:
            self.ingress_entered = False

    def _advance_accounting(
        self, expected_start: int, end: int, beneficiary: str
    ) -> bool:
        if (not beneficiary or expected_start != self.cursor
                or not expected_start <= end <= self.count):
            return False
        consumed_deposit = (self.deposit_prefix[end]
                            - self.deposit_prefix[expected_start])
        if consumed_deposit:
            self.claimable[beneficiary] = (
                self.claimable.get(beneficiary, 0) + consumed_deposit)
            assert (self.unconsumed_escrow is not None
                    and self.total_claimable is not None
                    and consumed_deposit <= self.unconsumed_escrow)
            self.unconsumed_escrow -= consumed_deposit
            self.total_claimable += consumed_deposit
        self.cursor = end
        assert self.escrow_balance >= self.accounted_liabilities
        return True

    def advance_cursor(
        self, *, settlement: object, expected_start: int, end: int,
        beneficiary: str,
    ) -> bool:
        """``advanceCursor``: only the bound Settlement (Inbox proxy) may call."""

        if (settlement is None or settlement is not self._settlement
                or getattr(settlement, "forced_queue", None) is not self):
            return False
        return self._advance_accounting(expected_start, end, beneficiary)

    def withdraw_claimable(self, beneficiary: str) -> int:
        amount = self.claimable.get(beneficiary, 0)
        if amount <= 0 or amount > self.escrow_balance:
            return 0
        self.claimable[beneficiary] = 0
        assert self.total_claimable is not None
        self.total_claimable -= amount
        self.escrow_balance -= amount
        assert self.escrow_balance >= self.accounted_liabilities
        return amount


# ScheduleOracle fork-verifier change parameters.  Fork verifier registration
# is an owner-only operation executed through the DAO's existing delayed
# governance process; the delay below is the reviewed lead time it assumes.
PROTOCOL_CHANGE_DELAY_SECONDS = 604_800
FORK_CHANGE_EXECUTION_WINDOW_SECONDS = 86_400
# A successful fork transition must leave enough reviewed horizon to broadcast
# a follow-up immediately, include its queue transaction within the pinned
# availability allowance, and execute at the end of its finite validity window.
FORK_CHANGE_QUEUE_INCLUSION_ALLOWANCE_SECONDS = T_DEPTH_MAX
FORK_CHANGE_RENEWAL_RUNWAY_WINDOWS = (
    (FORK_CHANGE_QUEUE_INCLUSION_ALLOWANCE_SECONDS
     + PROTOCOL_CHANGE_DELAY_SECONDS + FORK_CHANGE_EXECUTION_WINDOW_SECONDS
     + SCHEDULE_WINDOW_SLOTS - 1) // SCHEDULE_WINDOW_SLOTS
    + 8
)
SETTLEMENT_VALIDITY_VERIFIER_CALL_ENVELOPE_GAS = 10_000
SETTLEMENT_VALIDITY_VERIFIER_RETURN_COPY_GAS = 6
SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES = 65_536
SETTLEMENT_VALIDITY_MAXIMUM_GAS = L1_TRANSACTION_GAS_LIMIT
REGISTER_FORK_VERIFIER = 2
REPLACE_PENDING_FORK_VERIFIER = 5
SPLIT_LATEST_FORK_VERIFIER = 6
def _decode_uint_word_v1(word: bytes, bits: int, name: str) -> int:
    if type(word) is not bytes or len(word) != 32:
        raise ValueError(f"{name} word length is invalid")
    value = int.from_bytes(word, "big")
    if value >= 1 << bits:
        raise ValueError(f"{name} high padding is nonzero")
    return value


def _decode_address_word_v1(word: bytes, name: str) -> bytes:
    if type(word) is not bytes or len(word) != 32 or word[:12] != bytes(12):
        raise ValueError(f"{name} address padding is invalid")
    if word[12:] == bytes(20):
        raise ValueError(f"{name} address is zero")
    return word[12:]


def _decode_bytes4_word_v1(word: bytes, name: str) -> bytes:
    if type(word) is not bytes or len(word) != 32 or word[4:] != bytes(28):
        raise ValueError(f"{name} bytes4 padding is invalid")
    if word[:4] == bytes(4):
        raise ValueError(f"{name} bytes4 is zero")
    return word[:4]


def _protocol_change_words(payload: bytes, count: int) -> tuple[bytes, ...]:
    if type(payload) is not bytes or len(payload) != count * 32:
        raise ValueError("protocol change payload length is invalid")
    return tuple(payload[index * 32:(index + 1) * 32]
                 for index in range(count))


@dataclass(frozen=True)
class RegisterForkVerifierPayloadV1:
    fork_digest: bytes
    first_parent_slot: int
    last_parent_slot_exclusive: int
    verifier: bytes
    runtime_hash: bytes
    beacon_slot_gindex: int
    execution_payload_gindex: int
    state_root_gindex: int
    prev_randao_gindex: int
    timestamp_gindex: int
    block_hash_gindex: int
    witness_schema_hash: bytes
    configuration_hash: bytes
    selector: bytes
    gas_limit: int


@dataclass(frozen=True)
class ForkReviewEnvelopeV1:
    reviewed_through_parent_slot_exclusive: int
    review_evidence_hash: bytes
    review_certificate_hash: bytes


@dataclass(frozen=True)
class RegisterForkVerifierChangePayloadV1:
    registration: RegisterForkVerifierPayloadV1
    review: ForkReviewEnvelopeV1


def schedule_fork_registration_hash_v1(
    row: RegisterForkVerifierPayloadV1,
) -> bytes:
    encoded = encode_register_fork_verifier_payload_v1(row)
    return keccak256(
        b"slot-chain-schedule-fork-registration-v1"
        + _model_uint(len(encoded), 2, "fork registration bytes") + encoded
    )


def schedule_fork_review_certificate_hash_v1(
    settlement_chain_id: int,
    schedule_oracle: object,
    operation_kind: int,
    change_rows: bytes,
    reviewed_through_parent_slot_exclusive: int,
    review_evidence_hash: bytes,
) -> bytes:
    if (operation_kind not in {
            REGISTER_FORK_VERIFIER, REPLACE_PENDING_FORK_VERIFIER,
            SPLIT_LATEST_FORK_VERIFIER,
        }
            or type(change_rows) is not bytes or not change_rows
            or reviewed_through_parent_slot_exclusive <= 0
            or review_evidence_hash == bytes(32)):
        raise ValueError("fork review certificate inputs are malformed")
    return keccak256(b"".join((
        b"slot-chain-schedule-fork-review-certificate-v1",
        _model_uint(settlement_chain_id, 32, "fork review chain ID"),
        _model_address20(schedule_oracle),
        _model_uint(operation_kind, 1, "fork review operation kind"),
        _model_uint(len(change_rows), 2, "fork review row bytes"),
        keccak256(change_rows),
        _model_uint(
            reviewed_through_parent_slot_exclusive,
            8,
            "fork reviewed-through parent slot",
        ),
        _model_fixed_bytes32(review_evidence_hash),
    )))


def encode_fork_review_envelope_v1(review: ForkReviewEnvelopeV1) -> bytes:
    if (type(review) is not ForkReviewEnvelopeV1
            or not 0 < review.reviewed_through_parent_slot_exclusive
                <= UINT64_MAX
            or review.review_evidence_hash == bytes(32)
            or review.review_certificate_hash == bytes(32)):
        raise ValueError("fork review envelope is malformed")
    return b"".join((
        _model_uint(
            review.reviewed_through_parent_slot_exclusive,
            32,
            "fork reviewed-through parent slot",
        ),
        review.review_evidence_hash,
        review.review_certificate_hash,
    ))


def encode_register_fork_verifier_change_payload_v1(
    payload: RegisterForkVerifierChangePayloadV1,
) -> bytes:
    if type(payload) is not RegisterForkVerifierChangePayloadV1:
        raise ValueError("REGISTER fork change payload is malformed")
    return (
        encode_register_fork_verifier_payload_v1(payload.registration)
        + encode_fork_review_envelope_v1(payload.review)
    )


def encode_register_fork_verifier_payload_v1(
    row: RegisterForkVerifierPayloadV1,
) -> bytes:
    if type(row) is not RegisterForkVerifierPayloadV1:
        raise ValueError("fork verifier payload row is malformed")
    encoded = b"".join((
        row.fork_digest + bytes(28),
        _model_uint(row.first_parent_slot, 32, "fork first parent slot"),
        _model_uint(row.last_parent_slot_exclusive, 32,
                    "fork last parent slot"),
        bytes(12) + row.verifier, row.runtime_hash,
        *(_model_uint(value, 32, "fork generalized index") for value in (
            row.beacon_slot_gindex, row.execution_payload_gindex,
            row.state_root_gindex, row.prev_randao_gindex,
            row.timestamp_gindex, row.block_hash_gindex,
        )),
        row.witness_schema_hash, row.configuration_hash,
        row.selector + bytes(28),
        _model_uint(row.gas_limit, 32, "fork verifier gas"),
    ))
    if decode_register_fork_verifier_payload_v1(encoded) != row:
        raise ValueError("fork verifier payload cannot round-trip")
    return encoded


SCHEDULE_FORK_CONSTANTS_DOMAIN = b"slot-chain-schedule-fork-constants-v1"
SCHEDULE_FORK_CONFIG_DOMAIN = \
    b"slot-chain-schedule-fork-verifier-config-v1"
SCHEDULE_FORK_OUTPUT_SCHEMA_LITERAL = (
    b"ScheduleCarrierOutputV1(bytes32 statementHash,uint64 parentSlot,"
    b"uint64 parentExecutionBlockNumber,uint64 payloadTimestamp,bytes32 blockHash,"
    b"bytes32 stateRoot,bytes32 prevRandao)"
)
CURRENT_SCHEDULE_FORK_GINDICES = (8, 201, 6_434, 6_437, 6_441, 6_444)
CURRENT_SCHEDULE_HELPER_GINDICES = (
    6_445, 6_440, 6_436, 6_435, 3_223, 3_221, 3_219, 3_216,
    403, 200, 101, 51, 24, 13, 9, 7, 5,
)


def schedule_fork_constants_hash_v1(
    gindices: tuple[int, int, int, int, int, int],
) -> bytes:
    if len(gindices) != 6 or any(not 0 < row <= UINT64_MAX
                                 for row in gindices):
        raise ValueError("Schedule fork generalized indices are invalid")
    return keccak256(
        SCHEDULE_FORK_CONSTANTS_DOMAIN
        + b"".join(_model_uint(row, 8, "fork generalized index")
                   for row in gindices)
    )


def current_schedule_ssz_multiproof_schema_hash_v1() -> bytes:
    return keccak256(b"".join((
        b"slot-chain-schedule-ssz-multiproof-v1",
        schedule_fork_constants_hash_v1(CURRENT_SCHEDULE_FORK_GINDICES),
        _model_uint(672, 4, "current Schedule witness bytes"),
        _model_uint(
            len(CURRENT_SCHEDULE_HELPER_GINDICES), 2,
            "current Schedule helper count",
        ),
        *(_model_uint(row, 8, "current Schedule helper gindex")
          for row in CURRENT_SCHEDULE_HELPER_GINDICES),
    )))


def validate_current_schedule_ssz_multiproof_witness_v1(
    witness: bytes, window: int,
) -> None:
    if (type(witness) is not bytes or len(witness) != 672
            or int.from_bytes(witness[0:8], "big") != window
            or int.from_bytes(witness[16:24], "big") == 0
            or int.from_bytes(witness[24:32], "big") == 0
            or witness[32:64] == bytes(32)
            or witness[64:96] == bytes(32)
            or witness[96:128] == bytes(32)):
        raise ValueError("current Schedule SSZ multiproof witness is malformed")


def current_schedule_ssz_multiproof_root_v1(
    witness: bytes, window: int,
) -> bytes:
    """Execute the frozen current-fork SSZ SHA-256 multiproof."""

    validate_current_schedule_ssz_multiproof_witness_v1(witness, window)
    parent_slot = int.from_bytes(witness[8:16], "big")
    payload_timestamp = int.from_bytes(witness[24:32], "big")
    target_gindices = (
        CURRENT_SCHEDULE_FORK_GINDICES[0],
        *CURRENT_SCHEDULE_FORK_GINDICES[2:],
    )
    target_nodes = (
        parent_slot.to_bytes(8, "little") + bytes(24),
        witness[64:96],
        witness[96:128],
        payload_timestamp.to_bytes(8, "little") + bytes(24),
        witness[32:64],
    )
    positions = target_gindices + CURRENT_SCHEDULE_HELPER_GINDICES
    if len(set(positions)) != len(positions) or 1 in positions:
        raise ValueError("current Schedule SSZ positions are not a frontier")
    nodes = dict(zip(positions, target_nodes + tuple(
        witness[offset:offset + 32] for offset in range(128, 672, 32)
    )))
    derived: set[int] = set()
    while set(nodes) != {1}:
        pairs = sorted(
            (
                gindex for gindex in nodes
                if gindex > 1 and not gindex & 1
                and gindex + 1 in nodes
            ),
            reverse=True,
        )
        if not pairs:
            raise ValueError("current Schedule SSZ proof is incomplete")
        for left_index in pairs:
            right_index = left_index + 1
            if left_index not in nodes or right_index not in nodes:
                continue
            parent = left_index >> 1
            if parent in nodes or parent in derived:
                raise ValueError("current Schedule SSZ parent is ambiguous")
            parent_node = hashlib.sha256(
                nodes[left_index] + nodes[right_index]
            ).digest()
            del nodes[left_index]
            del nodes[right_index]
            nodes[parent] = parent_node
            derived.add(parent)
    return nodes[1]


def verify_current_schedule_ssz_multiproof_witness_v1(
    witness: bytes, window: int, beacon_block_root: bytes,
) -> None:
    if (type(beacon_block_root) is not bytes
            or len(beacon_block_root) != 32
            or beacon_block_root == bytes(32)
            or current_schedule_ssz_multiproof_root_v1(witness, window)
            != beacon_block_root):
        raise ValueError("current Schedule SSZ root mismatch")


def validate_schedule_execution_payload_adjacency_v1(
    parent_execution_block_number: int, carrier_header_block_number: int,
) -> None:
    if (type(parent_execution_block_number) is not int
            or type(carrier_header_block_number) is not int
            or not 0 <= parent_execution_block_number < UINT64_MAX
            or not 0 <= carrier_header_block_number <= UINT64_MAX
            or parent_execution_block_number + 1
                != carrier_header_block_number):
        raise ValueError("carrier execution block is not the payload successor")


def _canonical_rlp_header_fields_v1(encoded: bytes) -> tuple[bytes, ...]:
    """Decode the already-canonical flat execution-header string fields."""

    _canonical_rlp_list_field_count(encoded)
    prefix = encoded[0]
    if prefix <= 0xF7:
        cursor = 1
        payload_end = 1 + prefix - 0xC0
    else:
        size_bytes = prefix - 0xF7
        size_end = 1 + size_bytes
        cursor = size_end
        payload_end = size_end + int.from_bytes(encoded[1:size_end], "big")
    fields: list[bytes] = []
    while cursor < payload_end:
        prefix = encoded[cursor]
        if prefix <= 0x7F:
            fields.append(encoded[cursor:cursor + 1])
            cursor += 1
        elif prefix <= 0xB7:
            size = prefix - 0x80
            start = cursor + 1
            cursor = start + size
            fields.append(encoded[start:cursor])
        else:
            size_bytes = prefix - 0xB7
            size_end = cursor + 1 + size_bytes
            size = int.from_bytes(encoded[cursor + 1:size_end], "big")
            cursor = size_end + size
            fields.append(encoded[size_end:cursor])
    if cursor != payload_end:
        raise ValueError("execution header RLP is truncated")
    return tuple(fields)


def _decode_header_uint64_v1(encoded: bytes, name: str) -> int:
    if len(encoded) > 8 or (encoded and encoded[0] == 0):
        raise ValueError(f"{name} is not a minimal uint64")
    return int.from_bytes(encoded, "big")


@dataclass(frozen=True)
class ScheduleCarrierSystemContextV1:
    """Exact mocked results of the contract-selected system reads."""

    beacon_query_results: tuple[bytes | None, ...]
    history_block_hash: bytes

    def first_success(self) -> tuple[int, bytes]:
        if (not 1 <= len(self.beacon_query_results) <= 64
                or any(row is not None
                       for row in self.beacon_query_results[:-1])):
            raise ValueError("EIP-4788 scan does not stop at first success")
        root = self.beacon_query_results[-1]
        if type(root) is not bytes or len(root) != 32 or root == bytes(32):
            raise ValueError("EIP-4788 first success is malformed")
        if (type(self.history_block_hash) is not bytes
                or len(self.history_block_hash) != 32
                or self.history_block_hash == bytes(32)):
            raise ValueError("EIP-2935 return is malformed")
        return len(self.beacon_query_results), root


def schedule_carrier_statement_hash_v1(
    settlement_chain_id: int,
    schedule_oracle: str,
    fork_digest: bytes,
    window: int,
    beacon_block_root: bytes,
    parent_slot: int,
    parent_execution_block_number: int,
    payload_timestamp: int,
    block_hash: bytes,
    state_root: bytes,
    prev_randao: bytes,
) -> bytes:
    return keccak256(b"".join((
        b"slot-chain-schedule-carrier-statement-v1",
        _model_uint(settlement_chain_id, 32, "settlement chain ID"),
        _model_address20(schedule_oracle),
        fork_digest,
        _model_uint(window, 8, "Schedule window"),
        _model_fixed_bytes32(beacon_block_root),
        _model_uint(parent_slot, 8, "parent Beacon slot"),
        _model_uint(
            parent_execution_block_number, 8,
            "parent execution block number",
        ),
        _model_uint(payload_timestamp, 8, "parent payload timestamp"),
        _model_fixed_bytes32(block_hash),
        _model_fixed_bytes32(state_root),
        _model_fixed_bytes32(prev_randao),
    )))


def schedule_fork_verifier_configuration_hash_v1(
    fork_digest: bytes, gindices: tuple[int, int, int, int, int, int],
    witness_schema_hash: bytes, selector: bytes, gas_limit: int,
) -> bytes:
    if (len(fork_digest) != 4 or fork_digest == bytes(4)
            or len(gindices) != 6 or any(not 0 < row <= UINT64_MAX
                                        for row in gindices)
            or gindices[0] != 8
            or witness_schema_hash == bytes(32)
            or selector != bytes.fromhex("7e981e0b")
            or not 100_000 <= gas_limit <= 5_000_000):
        raise ValueError("Schedule fork verifier configuration is unsupported")
    constants = schedule_fork_constants_hash_v1(gindices)
    output_schema = keccak256(SCHEDULE_FORK_OUTPUT_SCHEMA_LITERAL)
    return keccak256(
        SCHEDULE_FORK_CONFIG_DOMAIN + fork_digest + constants
        + witness_schema_hash + output_schema + selector
        + _model_uint(gas_limit, 8, "fork verifier gas")
    )


def encode_schedule_fork_verifier_config_return_v1(
    row: RegisterForkVerifierPayloadV1,
) -> bytes:
    encoded = b"".join((
        b"SFV1" + bytes(28),
        row.fork_digest + bytes(28),
        *(
            _model_uint(value, 32, "fork generalized index")
            for value in (
                row.beacon_slot_gindex,
                row.execution_payload_gindex,
                row.state_root_gindex,
                row.prev_randao_gindex,
                row.timestamp_gindex,
                row.block_hash_gindex,
            )
        ),
        row.witness_schema_hash,
        row.configuration_hash,
    ))
    if len(encoded) != 320:
        raise AssertionError("SFV1 must be exactly 320 bytes")
    return encoded


@dataclass
class ScheduleForkVerifierArtifactV1:
    address: bytes
    runtime_hash: bytes
    configuration_return: bytes
    runtime_override: bytes | None = None
    configuration_override: bytes | None = None
    fault: bool = False

    def extcodehash(self) -> bytes:
        if self.fault:
            raise ValueError("fork verifier EXTCODEHASH observation failed")
        return (
            self.runtime_hash
            if self.runtime_override is None else self.runtime_override
        )

    def schedule_fork_verifier_config_v1(self) -> bytes:
        if self.fault:
            raise ValueError("fork verifier SFV1 call failed")
        return (
            self.configuration_return
            if self.configuration_override is None
            else self.configuration_override
        )

    def staticcall_schedule_fork_verifier_config_v1(
        self, calldata: bytes, *, gas_limit: int, value: int,
    ) -> bytes:
        if (calldata != SCHEDULE_FORK_CONFIG_SELECTOR
                or gas_limit != SCHEDULE_FORK_VERIFIER_CONFIG_READ_GAS
                or value != 0):
            raise ValueError("fork verifier SFV1 call frame is inexact")
        return self.schedule_fork_verifier_config_v1()


@dataclass
class ScheduleForkVerifierWorldV1:
    artifacts: dict[bytes, ScheduleForkVerifierArtifactV1] = field(
        default_factory=dict
    )

    def publish(self, row: RegisterForkVerifierPayloadV1) -> None:
        encode_register_fork_verifier_payload_v1(row)
        artifact = ScheduleForkVerifierArtifactV1(
            row.verifier,
            row.runtime_hash,
            encode_schedule_fork_verifier_config_return_v1(row),
        )
        existing = self.artifacts.get(row.verifier)
        if existing is not None and (
                existing.runtime_hash != artifact.runtime_hash
                or existing.configuration_return
                    != artifact.configuration_return):
            raise ValueError("fork verifier address cannot change artifact")
        if existing is None:
            self.artifacts[row.verifier] = artifact

    def artifact(self, verifier: bytes) -> ScheduleForkVerifierArtifactV1:
        artifact = self.artifacts.get(verifier)
        if artifact is None:
            raise ValueError("fork verifier artifact is not deployed")
        return artifact


def decode_register_fork_verifier_payload_v1(
    payload: bytes,
) -> RegisterForkVerifierPayloadV1:
    words = _protocol_change_words(payload, 15)
    fork_digest = _decode_bytes4_word_v1(words[0], "fork digest")
    first_parent_slot = _decode_uint_word_v1(
        words[1], 64, "first parent slot"
    )
    last_parent_slot_exclusive = _decode_uint_word_v1(
        words[2], 64, "last parent slot"
    )
    verifier = _decode_address_word_v1(words[3], "fork verifier")
    if verifier == bytes(20) or words[4] == bytes(32) or words[11] == bytes(32) \
            or words[12] == bytes(32):
        raise ValueError("fork verifier descriptor contains a zero hash")
    gindices = tuple(
        _decode_uint_word_v1(words[index], 64, "fork generalized index")
        for index in range(5, 11)
    )
    for index, name in zip(range(5, 11), (
            "beacon slot gindex", "execution payload gindex",
            "state root gindex", "prevRandao gindex", "timestamp gindex",
            "block hash gindex")):
        if _decode_uint_word_v1(words[index], 64, name) == 0:
            raise ValueError(f"{name} is zero")
    selector = _decode_bytes4_word_v1(words[13], "fork verifier selector")
    gas_limit = _decode_uint_word_v1(words[14], 64, "fork verifier gas")
    if (not first_parent_slot < last_parent_slot_exclusive
            or gindices[0] != 8
            or selector != bytes.fromhex("7e981e0b")
            or not gas_limit):
        raise ValueError("fork verifier route is unsupported")
    expected_config = schedule_fork_verifier_configuration_hash_v1(
        fork_digest, gindices, words[11], selector, gas_limit
    )
    if words[12] != expected_config:
        raise ValueError("fork verifier configuration hash is inconsistent")
    return RegisterForkVerifierPayloadV1(
        fork_digest, first_parent_slot, last_parent_slot_exclusive, verifier,
        words[4], *gindices, words[11], words[12], selector, gas_limit,
    )


@dataclass
class ScheduleForkRouteAccumulatorV1:
    """Incremental production-shaped FRS1 commitment state.

    Full mapping enumeration remains only in
    ``schedule_fork_route_state_hash_v1`` as an independent differential
    oracle. Mutations here touch a fixed 32-level path per changed leaf.
    """

    order_prefixes: list[bytes] = field(default_factory=lambda: [
        keccak256(b"slot-chain-schedule-fork-order-empty-v1")
    ])
    registration_nodes: dict[tuple[int, int], bytes] = field(
        default_factory=dict
    )
    used_nodes: dict[tuple[int, int], bytes] = field(default_factory=dict)

    @staticmethod
    def _defaults(domain: bytes) -> tuple[bytes, ...]:
        values = [keccak256(domain + b"\x00")]
        for _ in range(32):
            values.append(keccak256(
                domain + b"\x01" + values[-1] + values[-1]
            ))
        return tuple(values)

    @staticmethod
    def _update_path(
        domain: bytes,
        nodes: dict[tuple[int, int], bytes],
        digest: bytes,
        value: bytes | None,
    ) -> None:
        if type(digest) is not bytes or len(digest) != 4 \
                or digest == bytes(4):
            raise ValueError("Schedule route SMT digest is invalid")
        if value is not None and (type(value) is not bytes or len(value) != 32):
            raise ValueError("Schedule route SMT value is invalid")
        defaults = ScheduleForkRouteAccumulatorV1._defaults(domain)
        index = int.from_bytes(digest, "big")
        leaf = (defaults[0] if value is None else
                keccak256(domain + b"\x02" + digest + value))
        if leaf == defaults[0]:
            nodes.pop((0, index), None)
        else:
            nodes[(0, index)] = leaf
        for level in range(32):
            sibling = nodes.get((level, index ^ 1), defaults[level])
            if index & 1:
                left, right = sibling, leaf
            else:
                left, right = leaf, sibling
            parent = keccak256(domain + b"\x01" + left + right)
            index >>= 1
            if parent == defaults[level + 1]:
                nodes.pop((level + 1, index), None)
            else:
                nodes[(level + 1, index)] = parent
            leaf = parent

    @classmethod
    def from_state(
        cls,
        registrations: dict[bytes, RegisterForkVerifierPayloadV1],
        order: list[bytes],
        used_fork_digests: set[bytes],
    ) -> "ScheduleForkRouteAccumulatorV1":
        accumulator = cls()
        for digest in order:
            accumulator.append_order(digest)
        for digest, row in registrations.items():
            accumulator.set_registration(
                digest, schedule_fork_registration_hash_v1(row)
            )
        for digest in used_fork_digests:
            accumulator.set_used(digest)
        return accumulator

    def clone(self) -> "ScheduleForkRouteAccumulatorV1":
        return ScheduleForkRouteAccumulatorV1(
            list(self.order_prefixes), dict(self.registration_nodes),
            dict(self.used_nodes),
        )

    def append_order(self, digest: bytes) -> None:
        index = len(self.order_prefixes) - 1
        self.order_prefixes.append(keccak256(b"".join((
            b"slot-chain-schedule-fork-order-step-v1",
            self.order_prefixes[-1],
            _model_uint(index, 8, "Schedule route index"), digest,
        ))))

    def replace_last_order(self, digest: bytes) -> None:
        if len(self.order_prefixes) < 2:
            raise ValueError("Schedule route order has no replaceable row")
        index = len(self.order_prefixes) - 2
        self.order_prefixes[-1] = keccak256(b"".join((
            b"slot-chain-schedule-fork-order-step-v1",
            self.order_prefixes[-2],
            _model_uint(index, 8, "Schedule route index"), digest,
        )))

    def set_registration(self, digest: bytes, registration_hash: bytes) -> None:
        self._update_path(
            b"slot-chain-schedule-fork-registration-smt-v1",
            self.registration_nodes, digest, registration_hash,
        )

    def delete_registration(self, digest: bytes) -> None:
        self._update_path(
            b"slot-chain-schedule-fork-registration-smt-v1",
            self.registration_nodes, digest, None,
        )

    def set_used(self, digest: bytes) -> None:
        self._update_path(
            b"slot-chain-schedule-fork-used-smt-v1",
            self.used_nodes, digest,
            keccak256(b"slot-chain-schedule-fork-used-leaf-v1" + digest),
        )

    def route_state_hash(
        self, ordered_count: int, mapped_count: int, used_count: int,
    ) -> bytes:
        if (ordered_count + 1 != len(self.order_prefixes)
                or not 0 < ordered_count <= mapped_count <= used_count):
            raise ValueError("Schedule route accumulator counts are invalid")
        registration_defaults = self._defaults(
            b"slot-chain-schedule-fork-registration-smt-v1"
        )
        used_defaults = self._defaults(
            b"slot-chain-schedule-fork-used-smt-v1"
        )
        registration_root = self.registration_nodes.get(
            (32, 0), registration_defaults[32]
        )
        used_root = self.used_nodes.get((32, 0), used_defaults[32])
        return keccak256(b"".join((
            b"slot-chain-schedule-fork-route-state-v1",
            self.order_prefixes[-1], registration_root, used_root,
            _model_uint(ordered_count, 8, "Schedule route count"),
            _model_uint(mapped_count, 8, "Schedule mapping count"),
            _model_uint(used_count, 8, "Schedule used count"),
        )))


def encode_schedule_fork_route_accumulator_return_v1(
    accumulator: ScheduleForkRouteAccumulatorV1,
    ordered_count: int,
    mapped_count: int,
    used_count: int,
) -> bytes:
    encoded = b"".join((
        b"FRS1" + bytes(28),
        accumulator.route_state_hash(ordered_count, mapped_count, used_count),
        _model_uint(ordered_count, 32, "Schedule route count"),
        _model_uint(mapped_count, 32, "Schedule mapping count"),
        _model_uint(used_count, 32, "Schedule used count"),
    ))
    if len(encoded) != 160:
        raise AssertionError("FRS1 must be exactly 160 bytes")
    return encoded


@dataclass
class ScheduleOracleV1:
    """Protocol-lifetime fork registry and no-write VACANT consumption model.

    This file models the registered 15-word fork route and authenticated
    256-byte carrier as one verifier boundary.  Exact EIP-4788/SSZ generalized
    index leaf recomputation is composed from ``lookahead-model.py`` rather
    than duplicated here; release conformance runs both executable models.
    """

    address: str
    # The DAO owner of the ScheduleOracle proxy (fork verifier registration
    # goes through the DAO's existing delayed governance process).
    owner: str
    initial_fork: RegisterForkVerifierPayloadV1
    settlement_chain_id: int = 1
    history_first_supported_block: int = 1
    deployed_at_timestamp: int = GENESIS_TIMESTAMP
    fork_verifier_world: ScheduleForkVerifierWorldV1 = field(
        default_factory=ScheduleForkVerifierWorldV1
    )
    first_managed_window: int = 0
    genesis_timestamp: int = GENESIS_TIMESTAMP
    evidence_delay_seconds: int = EVIDENCE_DELAY_SECONDS
    reorg_margin_seconds: int = REORG_MARGIN_SECONDS
    beacon_genesis_time: int = 0
    last_managed_window: int | None = None
    registrations: dict[bytes, RegisterForkVerifierPayloadV1] = field(
        default_factory=dict
    )
    order: list[bytes] = field(default_factory=list)
    fork_index_by_digest: dict[bytes, int] = field(default_factory=dict)
    used_fork_digests: set[bytes] = field(default_factory=set)
    sealed_windows: dict[int, bytes] = field(default_factory=dict)
    fork_route_accumulator: ScheduleForkRouteAccumulatorV1 | None = field(
        default=None, compare=False
    )
    fault_point: str | None = field(default=None, compare=False)
    getter_override: bytes | None = field(default=None, compare=False)
    getter_response_script: list[bytes] = field(
        default_factory=list, compare=False, repr=False
    )
    route_state_override: bytes | None = field(default=None, compare=False)
    read_faults: set[str] = field(default_factory=set, compare=False)

    def __post_init__(self) -> None:
        derived = derive_last_managed_schedule_window(
            self.genesis_timestamp, self.evidence_delay_seconds,
            self.reorg_margin_seconds,
        )
        if self.last_managed_window is None:
            self.last_managed_window = derived
        elif self.last_managed_window != derived:
            raise ValueError("Schedule last managed window is inconsistent")
        if (type(self.first_managed_window) is not int
                or not 0 <= self.first_managed_window
                <= self.last_managed_window):
            raise ValueError("Schedule managed interval is inconsistent")
        if (type(self.settlement_chain_id) is not int
                or not 0 < self.settlement_chain_id < 1 << 256
                or type(self.history_first_supported_block) is not int
                or not 0 < self.history_first_supported_block <= UINT64_MAX):
            raise ValueError("Schedule settlement/history domain is invalid")
        if (type(self.deployed_at_timestamp) is not int
                or not 0 <= self.deployed_at_timestamp <= UINT64_MAX):
            raise ValueError("Schedule deployment timestamp is invalid")
        if (type(self.beacon_genesis_time) is not int
                or not 0 <= self.beacon_genesis_time <= UINT64_MAX):
            raise ValueError("Schedule beacon schema horizon is inconsistent")
        if (self.first_managed_window
                > (UINT64_MAX - self.genesis_timestamp)
                    // SCHEDULE_WINDOW_SLOTS
                or self.beacon_genesis_time > UINT64_MAX - 3_072):
            raise ValueError("Schedule first managed window overflows")
        first_window_start = (
            self.genesis_timestamp
            + SCHEDULE_WINDOW_SLOTS * self.first_managed_window
        )
        if (first_window_start < 768
                or first_window_start < self.beacon_genesis_time + 3_072):
            raise ValueError("Schedule first managed window is too early")
        if (self.registrations or self.order or self.fork_index_by_digest
                or self.used_fork_digests
                or self.fork_route_accumulator is not None):
            raise ValueError("Schedule constructor fork state is prepopulated")
        if self.initial_fork.first_parent_slot != 0:
            raise ValueError("initial Schedule fork must start at slot zero")
        encode_register_fork_verifier_payload_v1(self.initial_fork)
        if self.initial_fork.last_parent_slot_exclusive > UINT64_MAX:
            raise ValueError("initial Schedule fork horizon exceeds uint64")
        self._validate_live_fork_verifier(self.initial_fork)
        self.registrations[self.initial_fork.fork_digest] = self.initial_fork
        self.order.append(self.initial_fork.fork_digest)
        self.fork_index_by_digest[self.initial_fork.fork_digest] = 0
        self.used_fork_digests.add(self.initial_fork.fork_digest)
        self.fork_route_accumulator = ScheduleForkRouteAccumulatorV1.from_state(
            self.registrations, self.order, self.used_fork_digests
        )
        initial_protected_target = self.target_slot(
            self.current_window_at(self.deployed_at_timestamp)
            + FORK_CHANGE_RENEWAL_RUNWAY_WINDOWS
        )
        if (initial_protected_target
                + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                >= self.initial_fork.last_parent_slot_exclusive):
            raise ValueError("initial Schedule fork horizon is already unsafe")

    def current_window_at(self, timestamp: int) -> int:
        if type(timestamp) is not int or not 0 <= timestamp <= UINT64_MAX:
            raise ValueError("Schedule timestamp is outside uint64")
        if timestamp <= self.genesis_timestamp:
            return 0
        return (timestamp - self.genesis_timestamp) // SCHEDULE_WINDOW_SLOTS

    def target_slot(self, window: int) -> int:
        if type(window) is not int or not 0 <= window <= UINT64_MAX:
            raise ValueError("Schedule target window is outside uint64")
        window_start = self.genesis_timestamp + SCHEDULE_WINDOW_SLOTS * window
        snapshot_lag_seconds = 256 * L1_SLOT_SECONDS
        if window_start < self.beacon_genesis_time + snapshot_lag_seconds:
            raise ValueError("Schedule target precedes the Beacon slot domain")
        return ((window_start - snapshot_lag_seconds
                 - self.beacon_genesis_time) // L1_SLOT_SECONDS)

    @property
    def latest_last_parent_slot_exclusive(self) -> int:
        if not self.order:
            return 0
        return self.registrations[
            self.order[-1]
        ].last_parent_slot_exclusive

    def _snapshot(self) -> tuple[object, ...]:
        return (
            dict(self.registrations), list(self.order),
            dict(self.fork_index_by_digest), set(self.used_fork_digests),
            dict(self.sealed_windows),
            self.fork_route_accumulator.clone(),
        )

    def _restore(self, snapshot: tuple[object, ...]) -> None:
        (registrations, order, index_by_digest, used_digests, seals,
         accumulator) = snapshot
        self.registrations = registrations
        self.order = order
        self.fork_index_by_digest = index_by_digest
        self.used_fork_digests = used_digests
        self.sealed_windows = seals
        self.fork_route_accumulator = accumulator

    def _validate_live_fork_verifier(
        self, row: RegisterForkVerifierPayloadV1,
    ) -> None:
        artifact = self.fork_verifier_world.artifact(row.verifier)
        if (artifact.extcodehash() != row.runtime_hash
                or artifact.staticcall_schedule_fork_verifier_config_v1(
                    SCHEDULE_FORK_CONFIG_SELECTOR,
                    gas_limit=SCHEDULE_FORK_VERIFIER_CONFIG_READ_GAS,
                    value=0,
                )
                    != encode_schedule_fork_verifier_config_return_v1(row)):
            raise ValueError("live Schedule fork verifier is inconsistent")

    def install_fork_verifier_v1(
        self, row: RegisterForkVerifierPayloadV1, *, caller: str,
        clock: Clock, gas_limit: int, value: int,
    ) -> bytes:
        if (caller != self.owner
                or gas_limit != SCHEDULE_FORK_MUTATION_GAS or value != 0):
            raise ValueError("Schedule fork installation is stale or unauthorized")
        installation_kind = self._fork_installation_kind(row, clock=clock)
        snapshot = self._snapshot()
        try:
            self.registrations[row.fork_digest] = row
            if installation_kind == "append":
                self.order.append(row.fork_digest)
                self.fork_index_by_digest[row.fork_digest] = len(self.order) - 1
                self.used_fork_digests.add(row.fork_digest)
                self.fork_route_accumulator.append_order(row.fork_digest)
                self.fork_route_accumulator.set_used(row.fork_digest)
            self.fork_route_accumulator.set_registration(
                row.fork_digest, schedule_fork_registration_hash_v1(row)
            )
            if self.fault_point == "after_install":
                raise RuntimeError("injected Schedule install fault")
            return (
                b"FVI1" + bytes(28) + row.fork_digest + bytes(28)
                + _model_uint(row.first_parent_slot, 32,
                              "fork first parent slot")
            )
        except BaseException:
            self._restore(snapshot)
            raise

    def _fork_installation_kind(
        self, row: RegisterForkVerifierPayloadV1, *, clock: Clock,
    ) -> str:
        encode_register_fork_verifier_payload_v1(row)
        self._validate_live_fork_verifier(row)
        if (row.beacon_slot_gindex != 8
                or not 0 <= row.first_parent_slot
                    < row.last_parent_slot_exclusive <= UINT64_MAX):
            raise ValueError("Schedule fork interval is unsupported")
        latest_digest = self.order[-1]
        latest = self.registrations[latest_digest]
        protected_target = self.target_slot(
            self.current_window_at(clock.timestamp) + 8
        )
        renewal_target = self.target_slot(
            self.current_window_at(clock.timestamp)
            + FORK_CHANGE_RENEWAL_RUNWAY_WINDOWS
        )
        if row.fork_digest == latest_digest:
            same_descriptor = (
                row.first_parent_slot == latest.first_parent_slot
                and row.verifier == latest.verifier
                and row.runtime_hash == latest.runtime_hash
                and row.beacon_slot_gindex == latest.beacon_slot_gindex
                and row.execution_payload_gindex
                    == latest.execution_payload_gindex
                and row.state_root_gindex == latest.state_root_gindex
                and row.prev_randao_gindex == latest.prev_randao_gindex
                and row.timestamp_gindex == latest.timestamp_gindex
                and row.block_hash_gindex == latest.block_hash_gindex
                and row.witness_schema_hash == latest.witness_schema_hash
                and row.configuration_hash == latest.configuration_hash
                and row.selector == latest.selector
                and row.gas_limit == latest.gas_limit
            )
            if (not same_descriptor
                    or row.last_parent_slot_exclusive
                        <= latest.last_parent_slot_exclusive
                    or protected_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                        >= latest.last_parent_slot_exclusive
                    or renewal_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                        >= row.last_parent_slot_exclusive):
                raise ValueError("Schedule horizon extension is unsafe")
            return "extend"
        if (row.fork_digest in self.used_fork_digests
                or row.first_parent_slot
                    != latest.last_parent_slot_exclusive
                or protected_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= row.first_parent_slot
                or renewal_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= row.first_parent_slot
                or renewal_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= row.last_parent_slot_exclusive):
            raise ValueError("Schedule fork append is stale or noncontiguous")
        return "append"

    def replace_pending_fork_verifier_v1(
        self, expected_predecessor_registration_hash: bytes,
        expected_old_registration_hash: bytes,
        replacement_row: RegisterForkVerifierPayloadV1, *, caller: str,
        clock: Clock, gas_limit: int, value: int,
    ) -> bytes:
        if (caller != self.owner
                or gas_limit != SCHEDULE_FORK_MUTATION_GAS or value != 0
                or len(expected_predecessor_registration_hash) != 32
                or len(expected_old_registration_hash) != 32
                or len(self.order) < 2):
            raise ValueError("pending Schedule replacement is unauthorized")
        old_digest = self.order[-1]
        old = self.registrations[old_digest]
        if schedule_fork_registration_hash_v1(old) \
                != expected_old_registration_hash:
            raise ValueError("pending Schedule replacement old row is stale")
        encode_register_fork_verifier_payload_v1(replacement_row)
        self._validate_live_fork_verifier(replacement_row)
        protected_target = self.target_slot(
            self.current_window_at(clock.timestamp) + 8
        )
        renewal_target = self.target_slot(
            self.current_window_at(clock.timestamp)
            + FORK_CHANGE_RENEWAL_RUNWAY_WINDOWS
        )
        predecessor_digest = self.order[-2]
        predecessor = self.registrations[predecessor_digest]
        if schedule_fork_registration_hash_v1(predecessor) \
                != expected_predecessor_registration_hash:
            raise ValueError("pending Schedule replacement predecessor is stale")
        if (replacement_row.beacon_slot_gindex != 8
                or protected_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS >= min(
                    old.first_parent_slot,
                    replacement_row.first_parent_slot,
                )
                or renewal_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= replacement_row.last_parent_slot_exclusive
                or not predecessor.first_parent_slot
                    < replacement_row.first_parent_slot
                    < replacement_row.last_parent_slot_exclusive <= UINT64_MAX
                or (replacement_row.fork_digest != old_digest
                    and replacement_row.fork_digest
                        in self.used_fork_digests)):
            raise ValueError("pending Schedule replacement is unsafe")
        snapshot = self._snapshot()
        try:
            rewritten_predecessor = replace(
                predecessor,
                last_parent_slot_exclusive=replacement_row.first_parent_slot,
            )
            self.registrations[predecessor_digest] = rewritten_predecessor
            self.fork_route_accumulator.set_registration(
                predecessor_digest,
                schedule_fork_registration_hash_v1(rewritten_predecessor),
            )
            if replacement_row.fork_digest != old_digest:
                del self.registrations[old_digest]
                del self.fork_index_by_digest[old_digest]
                self.fork_route_accumulator.delete_registration(old_digest)
            self.registrations[replacement_row.fork_digest] = replacement_row
            self.order[-1] = replacement_row.fork_digest
            self.fork_index_by_digest[replacement_row.fork_digest] = (
                len(self.order) - 1
            )
            self.used_fork_digests.add(replacement_row.fork_digest)
            self.fork_route_accumulator.set_registration(
                replacement_row.fork_digest,
                schedule_fork_registration_hash_v1(replacement_row),
            )
            self.fork_route_accumulator.replace_last_order(
                replacement_row.fork_digest
            )
            self.fork_route_accumulator.set_used(replacement_row.fork_digest)
            if self.fault_point == "after_replace":
                raise RuntimeError("injected Schedule replacement fault")
            return b"".join((
                b"FVP1" + bytes(28), old_digest + bytes(28),
                replacement_row.fork_digest + bytes(28),
                _model_uint(replacement_row.first_parent_slot, 32,
                            "replacement first parent slot"),
                _model_uint(replacement_row.last_parent_slot_exclusive, 32,
                            "replacement last parent slot"),
            ))
        except BaseException:
            self._restore(snapshot)
            raise

    def split_latest_fork_verifier_v1(
        self, expected_old_registration_hash: bytes,
        successor_row: RegisterForkVerifierPayloadV1, *, caller: str,
        clock: Clock, gas_limit: int, value: int,
    ) -> bytes:
        if (caller != self.owner
                or gas_limit != SCHEDULE_FORK_MUTATION_GAS or value != 0
                or len(expected_old_registration_hash) != 32):
            raise ValueError("latest Schedule fork split is unauthorized")
        old_digest = self.order[-1]
        old = self.registrations[old_digest]
        if schedule_fork_registration_hash_v1(old) \
                != expected_old_registration_hash:
            raise ValueError("latest Schedule fork split old row is stale")
        encode_register_fork_verifier_payload_v1(successor_row)
        self._validate_live_fork_verifier(successor_row)
        protected_target = self.target_slot(
            self.current_window_at(clock.timestamp) + 8
        )
        renewal_target = self.target_slot(
            self.current_window_at(clock.timestamp)
            + FORK_CHANGE_RENEWAL_RUNWAY_WINDOWS
        )
        if (successor_row.beacon_slot_gindex != 8
                or successor_row.fork_digest == old_digest
                or successor_row.fork_digest in self.used_fork_digests
                or protected_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= successor_row.first_parent_slot
                or renewal_target + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                    >= successor_row.last_parent_slot_exclusive
                or not old.first_parent_slot
                    < successor_row.first_parent_slot
                    < old.last_parent_slot_exclusive
                or not successor_row.first_parent_slot
                    < successor_row.last_parent_slot_exclusive <= UINT64_MAX):
            raise ValueError("latest Schedule fork split is unsafe")
        snapshot = self._snapshot()
        try:
            shortened = replace(
                old,
                last_parent_slot_exclusive=successor_row.first_parent_slot,
            )
            self.registrations[old_digest] = shortened
            self.registrations[successor_row.fork_digest] = successor_row
            self.order.append(successor_row.fork_digest)
            self.fork_index_by_digest[successor_row.fork_digest] = (
                len(self.order) - 1
            )
            self.used_fork_digests.add(successor_row.fork_digest)
            self.fork_route_accumulator.set_registration(
                old_digest, schedule_fork_registration_hash_v1(shortened)
            )
            self.fork_route_accumulator.set_registration(
                successor_row.fork_digest,
                schedule_fork_registration_hash_v1(successor_row),
            )
            self.fork_route_accumulator.append_order(
                successor_row.fork_digest
            )
            self.fork_route_accumulator.set_used(successor_row.fork_digest)
            if self.fault_point == "after_split":
                raise RuntimeError("injected Schedule split fault")
            return b"".join((
                b"FVS1" + bytes(28), old_digest + bytes(28),
                successor_row.fork_digest + bytes(28),
                _model_uint(successor_row.first_parent_slot, 32,
                            "split first parent slot"),
                _model_uint(successor_row.last_parent_slot_exclusive, 32,
                            "split last parent slot"),
            ))
        except BaseException:
            self._restore(snapshot)
            raise

    def fork_verifier_registration_v1(self, fork_digest: bytes) -> bytes:
        row = self.registrations.get(fork_digest)
        if row is None:
            raise ValueError("unknown Schedule fork verifier")
        index = self.fork_index_by_digest.get(fork_digest)
        if (index is None or index >= len(self.order)
                or self.order[index] != fork_digest):
            raise ValueError("Schedule fork reverse index is inconsistent")
        successor = (
            self.registrations[self.order[index + 1]]
            if index + 1 < len(self.order) else None
        )
        encoded = b"".join((
            b"FVR1" + bytes(28), fork_digest + bytes(28),
            _model_uint(row.first_parent_slot, 32, "fork first parent slot"),
            (bytes(32) if successor is None
             else successor.fork_digest + bytes(28)),
            _model_uint(row.last_parent_slot_exclusive, 32,
                        "fork last parent slot"),
            bytes(12) + row.verifier, row.runtime_hash,
            row.configuration_hash, row.selector + bytes(28),
            _model_uint(row.gas_limit, 32, "fork verifier gas"),
        ))
        if len(encoded) != 320:
            raise AssertionError("FVR1 must be exactly 320 bytes")
        if self.getter_response_script:
            return self.getter_response_script.pop(0)
        return self.getter_override if self.getter_override is not None else encoded

    def staticcall_fork_verifier_registration_v1(
        self, calldata: bytes, *, gas_limit: int, value: int,
    ) -> bytes:
        if ("FVR1" in self.read_faults
                or type(calldata) is not bytes or len(calldata) != 36
                or calldata[:4] != SCHEDULE_FORK_REGISTRATION_SELECTOR
                or calldata[8:] != bytes(28)
                or gas_limit != SCHEDULE_FORK_REGISTRATION_READ_GAS
                or value != 0):
            raise ValueError("Schedule FVR1 call frame is inexact")
        return self.fork_verifier_registration_v1(calldata[4:8])

    def schedule_fork_verifier_config_v1(self, fork_digest: bytes) -> bytes:
        row = self.registrations.get(fork_digest)
        if row is None:
            raise ValueError("unknown Schedule fork configuration")
        return self.fork_verifier_world.artifact(
            row.verifier
        ).schedule_fork_verifier_config_v1()

    def schedule_fork_route_state_v1(self) -> bytes:
        encoded = encode_schedule_fork_route_accumulator_return_v1(
            self.fork_route_accumulator, len(self.order),
            len(self.registrations), len(self.used_fork_digests),
        )
        return (
            encoded if self.route_state_override is None
            else self.route_state_override
        )

    def staticcall_schedule_fork_route_state_v1(
        self, calldata: bytes, *, gas_limit: int, value: int,
    ) -> bytes:
        if ("FRS1" in self.read_faults
                or calldata != SCHEDULE_FORK_ROUTE_STATE_SELECTOR
                or gas_limit != SCHEDULE_FORK_ROUTE_READ_GAS
                or value != 0):
            raise ValueError("Schedule FRS1 call frame is inexact")
        return self.schedule_fork_route_state_v1()

    def _eligible_row(
        self, target_slot: int, fork_digest: bytes,
    ) -> RegisterForkVerifierPayloadV1 | None:
        row = self.registrations.get(fork_digest)
        # The upper bound cannot be applied to targetSlot: a missed slot at a
        # fork boundary may authenticate the predecessor interval's parent.
        if row is None or target_slot < row.first_parent_slot:
            return None
        return row

    def seal_window_v1(
        self, window: int, fork_digest: bytes, witness: bytes,
        verifier_return: bytes, *, system: ScheduleCarrierSystemContextV1,
        clock: Clock,
    ) -> bytes:
        seal_deadline = (
            self.genesis_timestamp + SCHEDULE_WINDOW_SLOTS * window
            - SCHEDULE_LOOKAHEAD_SECONDS
        )
        if (window in self.sealed_windows
                or not self.first_managed_window
                <= window <= self.last_managed_window
                or window < self.current_window_at(clock.timestamp)
                or window - self.current_window_at(clock.timestamp) > 8
                or clock.timestamp >= seal_deadline):
            raise ValueError("Schedule seal attempt is not live")
        target_slot = self.target_slot(window)
        if (target_slot + MAX_SCHEDULE_CARRIER_SCAN_SLOTS
                >= self.latest_last_parent_slot_exclusive):
            raise ValueError("Schedule target exceeds the reviewed fork horizon")
        query_index, beacon_block_root = system.first_success()
        target_timestamp = (
            self.beacon_genesis_time + target_slot * L1_SLOT_SECONDS
        )
        query_timestamp = target_timestamp + query_index * L1_SLOT_SECONDS
        row = self._eligible_row(target_slot, fork_digest)
        if (row is None or len(verifier_return) != 256
                or verifier_return[:32] != b"SFC1" + bytes(28)):
            raise ValueError("Schedule carrier verifier rejected without write")
        self._validate_live_fork_verifier(row)
        parent_slot = _decode_uint_word_v1(
            verifier_return[64:96], 64, "authenticated parent slot"
        )
        if (not row.first_parent_slot <= parent_slot
                < row.last_parent_slot_exclusive
                or parent_slot > target_slot):
            raise ValueError("authenticated parent slot is outside fork route")
        parent_execution_block_number = _decode_uint_word_v1(
            verifier_return[96:128], 64,
            "authenticated parent execution block number",
        )
        decoded_witness = decode_schedule_seal_witness_v1(witness)
        header_fields = _canonical_rlp_header_fields_v1(
            decoded_witness.carrier_header_rlp
        )
        if len(header_fields) <= 19:
            raise ValueError("Schedule carrier header omits required fields")
        parent_hash = header_fields[0]
        carrier_header_block_number = _decode_header_uint64_v1(
            header_fields[8], "carrier header block number"
        )
        carrier_header_timestamp = _decode_header_uint64_v1(
            header_fields[11], "carrier header timestamp"
        )
        parent_beacon_block_root = header_fields[19]
        oldest_history_block = max(
            self.history_first_supported_block,
            max(0, clock.block_number - EIP2935_HISTORY_ENTRIES),
        )
        if (len(parent_hash) != 32
                or len(parent_beacon_block_root) != 32
                or carrier_header_timestamp != query_timestamp
                or parent_beacon_block_root != beacon_block_root
                or not oldest_history_block <= carrier_header_block_number
                    < clock.block_number
                or clock.block_number - carrier_header_block_number
                    < SCHEDULE_SEAL_FINALITY_BLOCKS
                or keccak256(decoded_witness.carrier_header_rlp)
                    != system.history_block_hash):
            raise ValueError("Schedule carrier system/header join is invalid")
        if row.witness_schema_hash \
                == current_schedule_ssz_multiproof_schema_hash_v1():
            verify_current_schedule_ssz_multiproof_witness_v1(
                decoded_witness.fork_witness, window, beacon_block_root
            )
            if int.from_bytes(
                    decoded_witness.fork_witness[8:16], "big") != parent_slot:
                raise ValueError("fork witness parent slot is inconsistent")
            if int.from_bytes(
                    decoded_witness.fork_witness[16:24], "big") \
                    != parent_execution_block_number:
                raise ValueError("fork witness execution number is inconsistent")
        validate_schedule_execution_payload_adjacency_v1(
            parent_execution_block_number, carrier_header_block_number
        )
        payload_timestamp = _decode_uint_word_v1(
            verifier_return[128:160], 64,
            "authenticated parent payload timestamp",
        )
        block_hash = verifier_return[160:192]
        state_root = verifier_return[192:224]
        prev_randao = verifier_return[224:256]
        expected_payload_timestamp = (
            self.beacon_genesis_time + parent_slot * L1_SLOT_SECONDS
        )
        if (expected_payload_timestamp > UINT64_MAX
                or payload_timestamp != expected_payload_timestamp
                or block_hash == bytes(32)
                or state_root == bytes(32)
                or prev_randao == bytes(32)
                or block_hash != parent_hash):
            raise ValueError("Schedule parent payload/header join is invalid")
        statement = verifier_return[32:64]
        expected_statement = schedule_carrier_statement_hash_v1(
            self.settlement_chain_id,
            self.address,
            fork_digest,
            window,
            beacon_block_root,
            parent_slot,
            parent_execution_block_number,
            payload_timestamp,
            block_hash,
            state_root,
            prev_randao,
        )
        if statement != expected_statement:
            raise ValueError("Schedule carrier statement is inconsistent")
        seal = keccak256(
            b"slot-chain-schedule-seal-model-v1"
            + _model_uint(window, 8, "schedule window")
            + fork_digest + statement + keccak256(witness)
        )
        self.sealed_windows[window] = seal
        return seal

    def consume_window_v1(
        self, window: int, *, clock: Clock,
    ) -> bytes:
        if (type(window) is not int
                or not self.first_managed_window
                <= window <= self.last_managed_window):
            raise ValueError("Schedule consume window is unmanaged")
        seal = self.sealed_windows.get(window)
        if seal is not None:
            return seal
        seal_deadline = (
            self.genesis_timestamp + SCHEDULE_WINDOW_SLOTS * window
            - SCHEDULE_LOOKAHEAD_SECONDS
        )
        if clock.timestamp < seal_deadline:
            raise ValueError("unsealed Schedule window is not yet consumable")
        # VACANT is synthesized by the consumer and never stored by an
        # attacker or maintenance caller.
        return bytes(32)


def settlement_validity_verifier_required_gas_v2(
    verification_gas_limit: int, post_verification_reserve_gas: int,
) -> int:
    """Return the EIP-150-safe caller gas required before verifier STATICCALL."""

    if (type(verification_gas_limit) is not int
            or type(post_verification_reserve_gas) is not int
            or not 0 < verification_gas_limit
                <= SETTLEMENT_VALIDITY_MAXIMUM_GAS
            or not 0 < post_verification_reserve_gas
                <= SETTLEMENT_VALIDITY_MAXIMUM_GAS):
        raise ValueError("Settlement validity verifier gas bounds are invalid")
    eip150_headroom = (verification_gas_limit + 62) // 63
    return checked_l1_gas(verification_gas_limit
            + max(eip150_headroom, post_verification_reserve_gas)
            + SETTLEMENT_VALIDITY_VERIFIER_CALL_ENVELOPE_GAS
            + SETTLEMENT_VALIDITY_VERIFIER_RETURN_COPY_GAS)


PASS: list[str] = []


def check(name: str, condition: bool) -> None:
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def payable_reverted(call: Callable[[], object]) -> bool:
    try:
        call()
    except (TypeError, ValueError, RuntimeError):
        return True
    return False


def clock(number: int, l2_slot: int) -> Clock:
    return Clock(number, GENESIS_TIMESTAMP + l2_slot)


def message(enqueued_l2: int, ident: str, gas: int = 100_000, size: int = 100
            ) -> Message:
    """Kind-0 forced envelope fixture (the only ForcedKind)."""

    accounted_gas = (
        max(gas, 21_000, MIN_FORCE_ACCOUNTED_GAS)
    )
    row = Message(
        GENESIS_TIMESTAMP + enqueued_l2,
        accounted_gas,
        size,
        ident,
        sender="sender",
        valid_until=GENESIS_TIMESTAMP + enqueued_l2 + DATA_TTL_SECONDS,
        prepaid=canonical_ingress_deposit(accounted_gas, size),
        raw_tx_length=size,
        l2_chain_id=167_000,
        gas_limit=gas,
        max_fee=1_000_000,
        refund_address="sender",
    )
    return row


def enqueue_forced_for_test(p: "Protocol", c: Clock, row: Message) -> str:
    """Direct ``enqueueForcedTransactionV2`` on the ForcedQueue for tests."""

    return p.forced_queue.enqueue(
        c, row, caller=row.sender, deposit=row.prepaid
    )


def make_header_oracle(
    messages: list[Message] | None = None,
    first_supported_block: int = L1_EIP2935_FIRST_SUPPORTED_BLOCK,
) -> EIP2935SystemReadTestAdapter:
    queue = list(messages or [])
    root = model_force_root(queue)
    headers = {
        n: L1Header(
            f"{n:064x}", GENESIS_TIMESTAMP + n,
            f"state-{n}", root, len(queue),
        )
        for n in range(1, 20_000)
    }
    return EIP2935SystemReadTestAdapter(headers, first_supported_block)


def protocol(tip_slot: int = 1_000, cursor: int = 0, seat: bool = True,
             mode: Mode = Mode.NORMAL, messages: list[Message] | None = None,
             forced_queue: QueueContinuity | None = None,
             header_oracle: EIP2935SystemReadTestAdapter | None = None,
             settlement_address: str = "model-settlement",
             data_session_required_bond: int = 10,
             data_session_base_rent_wei: int = 0,
             data_session_rent_per_published_byte_wei: int = 0,
             data_session_blob_base_fee_multiplier_bps: int = 10_000,
             data_session_max_blobs_per_post: int = 6,
             data_session_protocol_version: int = 1,
             point_evaluation_adapter: PointEvaluationAdapter | None = None,
             refund_claim_window_seconds: int = DATA_TTL_SECONDS,
             reward_reorg_margin_seconds: int = REORG_MARGIN_SECONDS,
             data_rent_sink: DataRentSink | None = None,
             reward_class_registry: RewardClassRegistryV1 | None = None,
             reward_execution_profile_hash: bytes | None = None) -> Protocol:
    # The Protocol below is the post-import state of the existing Inbox proxy
    # (drain-and-activate): the canonical core is the imported V1 header.
    msgs = list(messages or [])
    if forced_queue is None:
        root = model_force_root(msgs)
        forced_queue = QueueContinuity(
            "model-forced-queue", root, len(msgs), cursor,
            sum(row.prepaid for row in msgs),
            max((row.due_at for row in msgs), default=0), msgs,
            settlement_address=settlement_address)
    else:
        assert not messages or forced_queue.descriptors == msgs
        msgs = forced_queue.descriptors
    if header_oracle is None:
        header_oracle = make_header_oracle(msgs)
    exact_reward_registry = (
        RewardClassRegistryV1()
        if reward_class_registry is None else reward_class_registry
    )
    canonical = Canonical(CanonicalCore(900, "a" * 64, tip_slot, "b" * 64, cursor), 900)
    result = Protocol(
        canonical, header_oracle, forced_queue,
        settlement_address=settlement_address, mode=mode,
        data_session_required_bond=data_session_required_bond,
        data_session_base_rent_wei=data_session_base_rent_wei,
        data_session_rent_per_published_byte_wei=(
            data_session_rent_per_published_byte_wei
        ),
        data_session_blob_base_fee_multiplier_bps=(
            data_session_blob_base_fee_multiplier_bps
        ),
        data_session_max_blobs_per_post=data_session_max_blobs_per_post,
        data_session_protocol_version=data_session_protocol_version,
        point_evaluation_adapter=(
            PointEvaluationAdapter()
            if point_evaluation_adapter is None else point_evaluation_adapter
        ),
        refund_claim_window_seconds=refund_claim_window_seconds,
        reward_reorg_margin_seconds=reward_reorg_margin_seconds,
        data_rent_sink=(DataRentSink()
                        if data_rent_sink is None else data_rent_sink),
        reward_class_registry=exact_reward_registry,
        reward_class_registry_address=exact_reward_registry.address,
        reward_class_registry_runtime_hash=exact_reward_registry.runtime_hash,
        reward_class_registry_configuration_hash=(
            exact_reward_registry.configuration_hash
        ),
        reward_execution_profile_hash=(
            keccak256(b"slot-chain-model-execution-profile-v1")
            if reward_execution_profile_hash is None
            else reward_execution_profile_hash
        ),
    )
    if seat:
        installed_at = GENESIS_TIMESTAMP + tip_slot
        primary = SeatTerm(
            b"P" * 32, b"p" * 32, b"o" * 32,
            "aggregator", "aggregator-payout", 1, installed_at,
        )
        standby = SeatTerm(
            b"S" * 32, b"s" * 32, b"q" * 32,
            "standby", "standby-payout", 2, installed_at,
        )
        result.install_seat_term_for_test(primary, rank=0, start_primary=True)
        result.install_seat_term_for_test(standby, rank=1, start_primary=False)
    return result

def block(p: Protocol, c: Clock, ident: str, *, slot: int | None = None,
          signed: bool = True, message_end: int | None = None,
          dispositions_ok: bool = True, discretionary: bool = True,
          tier: Tier = Tier.NORMAL_SIGNED,
          gas_used: int = 0,
          forced_tx_witnesses: tuple[ForcedTxExecutionWitness, ...] | None = None,
          data_records: tuple[tuple[str, int], ...] = ()) -> Block:
    if slot is None:
        slot = (c.l2_slot if p.mode is Mode.RECOVERY
                else c.l2_slot)
    if p.mode is Mode.RECOVERY and p.recovery:
        r = p.recovery
        anchor_number, force_root, cutoff = r.anchor_number, r.force_root, r.force_cutoff
        version, root = r.admission_version, r.admission_root
    else:
        anchor_number = (p.normal_anchor_number if p.normal_anchor_number is not None
                         else min(c.block_number - 1, slot))
        header = p.header_oracle.header(anchor_number)
        force_root, cutoff = header.force_root, header.force_cutoff
        version = p.normal_admission_version if p.normal_admission_version is not None else p.admission_version
        root = p.normal_admission_root or p.admission_root
    header = p.header_oracle.header(anchor_number)
    start = p.core.message_cursor
    end = (p._prefix_end(start, cutoff)
           if message_end is None else message_end)
    context = (p.recovery.recovery_id if p.mode is Mode.RECOVERY and p.recovery
               else normal_context_id(p.canonical.base_hash, version, root,
                                      anchor_number, header.block_hash))
    if forced_tx_witnesses is None:
        forced_tx_witnesses = forced_execution_witnesses_for_test(
            p.messages, start, end, GENESIS_TIMESTAMP + slot,
            p.forced_tx_fork, p.forced_tx_chain_id, p.core.next_base_fee,
        )
    return Block(slot, GENESIS_TIMESTAMP + slot,
                 f"{abs(hash(ident)) % (1 << 256):064x}", p.core.tip_hash,
                 slot // 384, signed, start, end, anchor_number, header.block_hash,
                 header.timestamp, force_root, cutoff,
                 context,
                 version, root, tier,
                 dispositions_ok=dispositions_ok,
                 discretionary_body=discretionary,
                 data_records=data_records,
                 forced_tx_fork=p.forced_tx_fork,
                 forced_tx_chain_id=p.forced_tx_chain_id,
                 forced_tx_base_fee=p.core.next_base_fee,
                 forced_tx_witnesses=forced_tx_witnesses,
                 gas_used=gas_used)


def candidate(p: Protocol, c: Clock, ident="candidate", *, tier=Tier.NORMAL_SIGNED,
              signed=True, slot=None, message_end=None, discretionary=True,
              force_range_proof_ok=True, recovery_fields_zero=True,
              available_payload_hashes: frozenset[str] | None = None,
              beneficiary: str = "prover",
              gas_used: int = 0,
              forced_tx_witnesses: tuple[ForcedTxExecutionWitness, ...] | None = None,
              data_records: tuple[tuple[str, int], ...] = ()) -> Candidate:
    b = block(p, c, ident, slot=slot, signed=signed, message_end=message_end,
              discretionary=discretionary,
              tier=tier,
              gas_used=gas_used,
              forced_tx_witnesses=forced_tx_witnesses,
              data_records=data_records)
    r = p.recovery
    next_due = p.next_due_at(b.message_end, b.force_cutoff)
    if available_payload_hashes is None:
        # Availability is a candidate proof witness.  It is deliberately
        # independent of the admission-only test oracle retained on Message;
        # that oracle is neither stored in the durable leaf nor committed by
        # forceRoot.
        available_payload_hashes = frozenset(
            row.payload_hash for row in p.messages if type(row) is Message
        )
    result = Candidate(
        ident, p.canonical.base_hash, (b,), tier,
        f"state:{ident}", "empty", next_due,
        p.core.l2_block_number + 1,
        available_payload_hashes=available_payload_hashes,
        beneficiary=beneficiary,
        proof_ok=True, force_range_proof_ok=force_range_proof_ok,
        episode=r.episode if r else 0,
        recovery_revision=r.revision if r else 0,
        recovery_id=r.recovery_id if r else "",
        recovery_fields_zero=recovery_fields_zero,
    )
    reward_execution_gas, reward_published_bytes = reward_candidate_metrics_v1(
        p, result
    )
    result = replace(
        result,
        reward_execution_gas=reward_execution_gas,
        reward_published_bytes=reward_published_bytes,
    )
    return result

def activate_normal(p: Protocol, c: Clock) -> None:
    arm_clock = Clock(c.block_number - 1, c.timestamp - 12)
    check("normal context arms", p.arm_normal_context(arm_clock) == "ARMED")
    check("normal context activates", p.activate_normal_context(c) == "ACTIVATED")


def open_recovery(p: Protocol, block_number=1_100) -> Clock:
    trigger = clock(block_number, p.core.tip_slot + DELTA_FINAL_LAG + 1)
    check("P1 objective sync opens recovery", p.sync(trigger))
    return trigger


def recovery_submit_clock(p: Protocol) -> Clock:
    assert p.recovery is not None
    return clock(p.recovery.anchor_number + F_L1, p.recovery.escape_slot + 1)


def escape_candidate(p: Protocol, c: Clock, ident="escape") -> Candidate:
    assert p.recovery is not None
    return candidate(p, c, ident, tier=Tier.ESCAPE_UNSIGNED, signed=False,
                     slot=p.recovery.escape_slot, discretionary=False,
                     recovery_fields_zero=False)

def test_canonical_outputs_and_checkpoint() -> None:
    q = protocol()
    c = clock(1_100, 1_100)
    activate_normal(q, c)
    cand = candidate(q, c, "explicit-output")
    check("P6 activated candidate accepted", q.submit(cand, c) == "ACCEPTED")
    close = Clock(1_234, q.normal_deadline)
    check("P7 imported canonical core carries no L1 checkpoint of its own",
          not q.l1_signal_service_checkpoints)
    q.sync(close)
    check("P7 L1 stamps landing block and proof advances EVM height/context",
          q.canonical.canonicalized_at_block == 1_234
          and q.core.state_root == "state:explicit-output"
          and q.core.l2_block_number == 901
          and q.core.next_base_fee == 101)
    check("P7a canonical close saves exactly one L1 SignalService checkpoint",
          q.l1_signal_service_checkpoints == {
              901: {
                  "tipHash": cand.tip.block_hash,
                  "stateRoot": "state:explicit-output",
              },
          })
    escape = protocol(seat=False)
    open_recovery(escape)
    escape_clock = recovery_submit_clock(escape)
    escaped = escape_candidate(escape, escape_clock)
    check("P7b escape commit saves the same checkpoint effect",
          escape.submit(escaped, escape_clock) == "COMMITTED"
          and escape.l1_signal_service_checkpoints == {
              901: {
                  "tipHash": escaped.tip.block_hash,
                  "stateRoot": escaped.end_state_root,
              },
          })

def test_admission_freeze_and_tier_canonicalization() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    activate_normal(p, c)
    first = candidate(p, c, "first")
    check("P8 normal candidate accepted", p.submit(first, c) == "ACCEPTED")
    frozen = (p.normal_admission_version, p.normal_admission_root)
    p.tombstone()
    check("P9 version and root move together", frozen != (p.admission_version, p.admission_root))
    replacement = candidate(p, clock(1_101, 1_101), "frozen")
    check("P10 open normal retains pair", p.submit(replacement, clock(1_101, 1_101)) in {"ACCEPTED", "IGNORED"})
    q = protocol()
    preopen = candidate(q, c, "preopen")
    check("P11 pre-activation signatures are not candidates",
          q.submit(preopen, c) == "REJECTED")
    activate_normal(q, c)
    malformed = candidate(q, c, "unused", recovery_fields_zero=False)
    check("P11 tier-1 unused recovery fields must be zero", q.submit(malformed, c) == "REJECTED")
    bad_time = candidate(q, c, "bad-time")
    bad_time = replace(
        bad_time,
        blocks=(replace(bad_time.blocks[0], evm_timestamp=bad_time.blocks[0].evm_timestamp + 1),),
    )
    check("P11a signed slot must equal EVM header time",
          q.submit(bad_time, c) == "REJECTED")
    armed = protocol()
    arm_clock = clock(1_099, 1_088)
    assert armed.arm_normal_context(arm_clock) == "ARMED"
    fork_a, fork_b = armed.snapshot(), armed.snapshot()
    fork_header = fork_b.header_oracle.header(1_099)
    object.__setattr__(
        fork_b,
        "header_oracle",
        fork_b.header_oracle.fork_for_test({
            1_099: replace(fork_header, block_hash="f" * 64)
        }),
    )
    assert fork_a.activate_normal_context(c) == "ACTIVATED"
    assert fork_b.activate_normal_context(c) == "ACTIVATED"
    check("P11b reorged arm blocks cannot share a slash context",
          fork_a.normal_context_id != fork_b.normal_context_id)
    surviving = armed.snapshot()
    assert surviving.activate_normal_context(c) == "ACTIVATED"
    check("P11c surviving arm block deliberately preserves its context",
          surviving.normal_context_id == fork_a.normal_context_id)
    stale_arm = protocol()
    assert stale_arm.arm_normal_context(clock(100, 100)) == "ARMED"
    check("P11d arm hash must remain natively readable",
          stale_arm.activate_normal_context(clock(356, 356)) == "REJECTED")
    check("P11e stale arm is permissionlessly replaced",
          stale_arm.arm_normal_context(clock(356, 356)) == "REARMED"
          and stale_arm.normal_arm_block_number == 356)

def test_force_merkle_bounds_and_auth() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    bad = replace(message(1_100, "bad"), outer_authorized=False)
    check("P12 outer sender authorization required",
          payable_reverted(lambda: enqueue_forced_for_test(p, c, bad)))
    for i in range(100):
        row = message(
            1_100, f"m{i}", gas=MIN_FORCE_ACCOUNTED_GAS, size=1
        )
        assert enqueue_forced_for_test(p, c, row) == f"QUEUED:{i}"
    check("P13 per-block count cap", p._prefix_end(0, 100) == 64)
    check("P14 range proof has a fixed bound",
          FORCE_TREE_DEPTH == 64 and MAX_FORCE_RANGE_PROOF_HASHES == 257)
    anchored = protocol(messages=[message(1_100, "a")])
    activate_normal(anchored, c)
    good = candidate(anchored, c, "good")
    forged = replace(good, force_range_proof_ok=False)
    check("P15 skip/reorder proof rejects", anchored.submit(forged, c) == "REJECTED")
    check("P17 gas geometry",
          FORCE_GAS_BUDGET + FORCE_GAS_MARGIN <= L2_BLOCK_GAS_LIMIT)
    too_long = replace(message(1_100, "too-long"),
                       valid_until=c.timestamp + MAX_FORCE_VALIDITY_SECONDS + 1)
    bounded_protocol = protocol()
    check("P17a user payload validity is bounded",
          payable_reverted(lambda: enqueue_forced_for_test(
              bounded_protocol, c, too_long)))
    check("P17b depth-64 frontier leaves final index unused",
          MAX_FORCE_QUEUE_ITEMS == (1 << 64) - 1)
    surplus_protocol = protocol()
    surplus_queue = surplus_protocol.forced_queue
    surplus_message = message(1_100, "forced-surplus")
    assert enqueue_forced_for_test(
        surplus_protocol, c, surplus_message
    ) == "QUEUED:0"
    original_liability = surplus_queue.accounted_liabilities
    assert surplus_queue._advance_accounting(0, 1, "surplus-prover")
    check("P17d forced ETH is surplus and cannot DoS queue liabilities",
          surplus_queue.force_eth(1)
          and surplus_queue.accounted_liabilities == original_liability
          and surplus_queue.withdraw_claimable("surplus-prover")
              == original_liability
          and surplus_queue.escrow_balance == 1
          and surplus_queue.accounted_liabilities == 0)

def test_late_close_and_constant_boundary() -> None:
    p = protocol()
    opened = clock(1_100, 1_100)
    activate_normal(p, opened)
    best = candidate(p, opened, "ordinary")
    check("P18 normal accepts", p.submit(best, opened) == "ACCEPTED")
    enqueue_l2 = opened.l2_slot + 1
    append_clock = clock(1_101, enqueue_l2)
    late_message = message(enqueue_l2, "late")
    check("P19 post-open append admits", enqueue_forced_for_test(
        p, append_clock, late_message) == "QUEUED:0")
    delayed = clock(1_300, enqueue_l2 + FORCE_DELAY + 1)
    before = p.core.tip_hash
    check("P20 delayed close transitions", p.sync(delayed))
    check("P21 newly due omitted head never commits", p.core.tip_hash == before and p.mode is Mode.RECOVERY)

    q = protocol(tip_slot=100, messages=[message(0, "covered")])
    accepted_at = clock(150, FORCE_DELAY - W_SETTLE_SECONDS - T_INCLUDE_MAX_SECONDS - 1)
    activate_normal(q, accepted_at)
    covered = candidate(q, accepted_at, "covered")
    check("P22 horizon-covering candidate accepted", q.submit(covered, accepted_at) == "ACCEPTED")
    close = Clock(400, q.normal_deadline)
    check("P23 covered best commits", q.sync(close) and q.core.tip_hash == covered.tip.block_hash)
    many = protocol(messages=[message(i, str(i)) for i in range(200_000)])
    queries = many.boundary_queries
    many.force_due(clock(500, 0))
    check("P24 due decision is one boundary read for 200k backlog", many.boundary_queries == queries + 1)
    check("P25 force geometry includes landing horizon", FORCE_DELAY >= W_SETTLE_SECONDS + T_INCLUDE_MAX_SECONDS)

    old_anchor = protocol(tip_slot=100)
    enqueue = clock(100, 100)
    post_anchor = message(100, "post-anchor")
    assert enqueue_forced_for_test(
        old_anchor, enqueue, post_anchor
    ) == "QUEUED:0"
    submit_at = clock(250, 300)
    activate_normal(old_anchor, submit_at)
    omitted = candidate(old_anchor, submit_at, "old-anchor-omits")
    check("P26 current-root boundary rejects post-anchor due omission",
          old_anchor.submit(omitted, submit_at) == "REJECTED")

    gap = protocol(tip_slot=100, seat=False)
    gap_clock = clock(200, 100 + G_MAX)
    activate_normal(gap, gap_clock)
    exact_gap = candidate(gap, gap_clock, "exact-gap", slot=100 + G_MAX)
    check("P26a exact tier-1 parent gap is accepted",
          gap.submit(exact_gap, gap_clock) == "ACCEPTED")
    beyond = protocol(tip_slot=100, seat=False)
    assert beyond.arm_normal_context(clock(199, 100 + G_MAX - 12)) == "ARMED"
    check("P26aa gap beyond G_MAX objectively enters recovery",
          beyond.activate_normal_context(clock(200, 100 + G_MAX + 1)) == "SYNCED"
          and beyond.mode is Mode.RECOVERY)
    evidence_path_blocks = (
        MAX_ARM_AGE_BLOCKS
        + (W_SETTLE_SECONDS + CLOCK_SKEW + 384 + EVIDENCE_DELAY_SECONDS
           + REORG_MARGIN_SECONDS + L1_SLOT_SECONDS - 1) // L1_SLOT_SECONDS
        + 2
    )
    check("P26ab G_MAX and EIP-2935 geometries are pinned",
          G_MAX == DELTA_FINAL_LAG
          and (G_MAX + CLOCK_SKEW + 383) // 384 <= MAX_WINDOWS_PER_CANDIDATE
          and evidence_path_blocks < EIP2935_HISTORY_ENTRIES)

    lost = replace(message(0, "lost"), payload_available=False,
                   valid_until=GENESIS_TIMESTAMP + 10)
    expired = protocol(tip_slot=0, messages=[lost])
    expired_clock = clock(10, 20)
    activate_normal(expired, expired_clock)
    check("P26b expired payload is consumable from durable descriptor",
          expired.submit(candidate(expired, expired_clock, "expired-meta"),
                         expired_clock) == "ACCEPTED")
    unexpired = protocol(tip_slot=0, messages=[
        replace(lost, valid_until=GENESIS_TIMESTAMP + 100)])
    activate_normal(unexpired, expired_clock)
    check("P26c unavailable unexpired payload rejects",
          unexpired.submit(candidate(
              unexpired, expired_clock, "missing-bytes",
              available_payload_hashes=frozenset()),
                           expired_clock) == "REJECTED")

def test_recovery_refresh_and_historical_immutability() -> None:
    p = protocol(seat=False, messages=[message(0, "forced")])
    trigger = open_recovery(p)
    original = copy.deepcopy(p.recovery)
    parent_before = p.header_oracle.header(original.anchor_number)
    during = clock(trigger.block_number + 1, trigger.l2_slot + 1)
    during_message = message(during.l2_slot, "during")
    check("P27 append during recovery admits", enqueue_forced_for_test(
        p, during, during_message) == "QUEUED:1")
    check("P28 append defers beyond live round", p.messages[-1].due_at == original.expires_at + 1)
    check(
        "P29 historical parent is never rewritten",
        p.header_oracle.header(original.anchor_number) == parent_before,
    )
    early = clock(original.anchor_number + F_L1 - 1, original.escape_slot + 1)
    check("P30 insufficient depth rejects", p.submit(escape_candidate(p, early), early) == "REJECTED")
    old = escape_candidate(p, recovery_submit_clock(p), "old")
    late = Clock(5_000, original.expires_at + 1)
    check("P31 expiry rolls before parsing", p.submit(old, late) == "SYNCED")
    check("P32 refreshed round has current queue and current start", p.recovery.force_cutoff == 2 and p.recovery.round_start_slot == late.l2_slot)
    fresh_clock = recovery_submit_clock(p)
    check("P33 stale proof rejects", p.submit(old, fresh_clock) == "REJECTED")
    fresh = escape_candidate(p, fresh_clock, "fresh")
    p.canonical_state_witness_available = False
    check("P33a a state root alone cannot reconstruct a lost prestate",
          p.submit(fresh, fresh_clock) == "REJECTED")
    p.canonical_state_witness_available = True
    p.canonical_code_preimages_available = False
    check("P33b trie nodes without code preimages cannot execute the prestate",
          p.submit(fresh, fresh_clock) == "REJECTED")
    p.canonical_code_preimages_available = True
    check("P34 current deterministic target commits", p.submit(fresh, fresh_clock) == "COMMITTED")

    stale = protocol(seat=False)
    open_recovery(stale)
    assert stale.recovery is not None
    stale_clock = clock(stale.recovery.anchor_number + F_L1,
                        stale.recovery.round_start_slot + DELTA_TIP + 1)
    stale_signed = candidate(stale, stale_clock, "stale-signed",
                             tier=Tier.RECOVERY_SIGNED,
                             slot=stale.recovery.round_start_slot,
                             recovery_fields_zero=False)
    check("P34a stale tier-2 tip rejects",
          stale.submit(stale_signed, stale_clock) == "REJECTED")

def test_registry_liability_and_release_units() -> None:
    active = [Generation(f"builder-{i}", 100 + (i // 2), i, 0) for i in range(64)]
    registry = RegistryLifecycle(active)
    # Builders 0 and 1 tie at minimum bond; greatest registration index loses.
    newcomer = Generation("new", 101, 64, ENTRY_DELAY_WINDOWS)
    check("P35 full-table replacement is delayed and strict", registry.admit(newcomer, 0))
    check("P36 deterministic tie victim moves to liability", registry.liabilities[0].registration_index == 1)
    check("P36a reverse indexes retain displaced slashable generation",
          registry.generation_locations[1] == ("LIABILITY", 0)
          and registry.live_registration_index_plus_one["builder-1"] == 2
          and registry.generation_locations[64] == ("ACTIVE", 1)
          and registry.live_registration_index_plus_one["new"] == 65)
    check("P37 displaced generation remains retained", len(registry.active) == 64 and len(registry.liabilities) == 1)
    check("P37a liability generation cannot extend reservations",
          not registry.reserve("builder-1", 1, 0))
    retained = registry.liability_ring[0]
    assert retained is not None
    reuse = Generation("builder-1", 50_000, 65,
                       retained[1] + ENTRY_DELAY_WINDOWS)
    check("P37b retained address cannot be reused", not registry.admit(reuse, retained[1]))
    assert registry.release_liability(0, retained[1])
    check("P37c address reuse after safe release gets a new generation",
          registry.admit(reuse, retained[1])
          and registry.total_credit_liability == retained[0].bond
          and registry.live_registration_index_plus_one["builder-1"] == 66
          and 1 not in registry.generation_locations)
    exhausted = RegistryLifecycle([])
    exhausted.next_registration_index = UINT64_MAX
    maximum_generation = Generation(
        "maximum-generation", 1, UINT64_MAX, 0
    )
    check("P37d uint64-max generation uses a width-safe exhausted sentinel",
          exhausted.admit(maximum_generation, 0)
          and exhausted.next_registration_index == UINT64_MAX + 1
          and exhausted.live_registration_index_plus_one[
              maximum_generation.address
          ] == UINT64_MAX + 1
          and not exhausted.admit(
              Generation("post-exhaustion", 2, 0, 0), 0
          ))
    low = Generation("low", 1, 66, ENTRY_DELAY_WINDOWS)
    check("P38 lower bond cannot displace", not registry.admit(low, 0))
    for j in range(3):
        next_registration = registry.next_registration_index
        assert next_registration is not None
        assert registry.admit(Generation(
            f"high-{j}", 10_000 + j, next_registration,
            ENTRY_DELAY_WINDOWS), 0)
    check("P39 per-window replacement rate is hard", not registry.admit(
        Generation("fifth", 20_000, registry.next_registration_index,
                   ENTRY_DELAY_WINDOWS), 0))
    check("P40 liability residence is strictly below ring horizon",
          MAX_LIABILITY_RESIDENCE_WINDOWS < MAX_LIVE_WINDOWS)
    check("P41 tranche release compares slots with slots",
          not tranche_releasable(5, 384 * 6 - 1, 10_000, 9_000)
          and tranche_releasable(5, 384 * 6, 10_000, 9_000))

    churn = RegistryLifecycle([
        Generation(f"base-{i}", 100 + i, i, 0, 16) for i in range(64)
    ])
    serial = 10_000
    for window in range(MAX_LIVE_WINDOWS + 1):
        for _ in range(MAX_REPLACEMENTS_PER_WINDOW):
            serial += 1
            assert churn.admit(
                Generation(f"churn-{serial}", 1_000_000 + serial,
                           churn.next_registration_index,
                           window + ENTRY_DELAY_WINDOWS,
                           window + MAX_TRANCHE_AHEAD_WINDOWS),
                window,
            )
    check("P41a max-churn ring reuses only released positions",
          churn.movement_sequence == 4 * (MAX_LIVE_WINDOWS + 1)
          and len(churn.liabilities) == MAX_LIABILITY_GENERATIONS)

    bounded = RegistryLifecycle(
        [Generation("long-lived", 10, 0, 0)])
    release_cursor = ScheduleReleaseCursor(first_managed_window=0)
    for current_window in range(2_000):
        if current_window:
            # Advance the schedule-release proof one window at a time and
            # release the tranche that reserve() normalized into liability.
            # Without this permissionless maintenance, the 512-cell ring is
            # intentionally fail-closed rather than overwriting live escrow.
            bounded.normalize_reservations(0, current_window)
            expired_window = current_window - 1
            assert release_cursor.expire(expired_window, releasable=True)
            if expired_window >= MAX_TRANCHE_AHEAD_WINDOWS:
                assert bounded.release_tranche(
                    0,
                    expired_window,
                    bounded.tranche_deadline(expired_window) + 1,
                    release_cursor,
                )
        assert bounded.reserve("long-lived", current_window + 16,
                               current_window)
        assert len(bounded.open_reservations) <= 17
    check("P41b historical reservations enter evidence-safe liability",
          len(bounded.open_reservations) == 17
          and bounded.normalize_reservations(0, 2_015) == 16
          and len(bounded.open_reservations) == 1)

    reservation_churn = RegistryLifecycle(
        [Generation(f"seat-{index}", index + 1, index, 0)
         for index in range(64)])
    next_registration = 64
    for current_window in range(MAX_TRANCHE_AHEAD_WINDOWS + 1):
        for generation in tuple(reservation_churn.active):
            for target_window in range(
                    current_window,
                    current_window + MAX_TRANCHE_AHEAD_WINDOWS + 1):
                assert reservation_churn.reserve(
                    generation.address, target_window, current_window)
        for move in range(MAX_REPLACEMENTS_PER_WINDOW):
            newcomer = Generation(
                f"replacement-{current_window}-{move}",
                10_000 + next_registration, next_registration,
                current_window + ENTRY_DELAY_WINDOWS)
            next_registration += 1
            assert reservation_churn.admit(newcomer, current_window)
            for target_window in range(
                    current_window,
                    current_window + MAX_TRANCHE_AHEAD_WINDOWS + 1):
                assert reservation_churn.reserve(
                    newcomer.address, target_window, current_window)
    check("P41c replacement converts future reservations to claim-only liability",
          MAX_LIVE_RESERVATIONS == 1_088
          and len(reservation_churn.open_reservations)
              == MAX_LIVE_RESERVATIONS
          and len(reservation_churn.liable_reservations) == 2_180
          and all(row[1] >= MAX_TRANCHE_AHEAD_WINDOWS
                  for row in reservation_churn.open_reservations))

def test_data_gc_reorg_and_geometry() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    expiry = c.timestamp + P_PROVE_MAX + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
    alice_session = p.next_data_session_id("alice")
    check("P42 session opens", p.open_session(
        c, "alice", 0, expiry, payment=10
    ) == alice_session)
    def post_terms(salt: bytes) -> dict[str, object]:
        post = data_post_for_test()
        return dict(
            posts=(post,),
            tx_blob_hashes=(
                kzg_commitment_to_versioned_hash(post.commitment),
            ),
            blob_base_fee=0,
            payment=0,
        )
    check("P43 wrong owner cannot post", payable_reverted(lambda: p.post_data(
        c, alice_session, "mallory", **post_terms(b"x"))))
    post_result = p.post_data(
        c, alice_session, "alice", **post_terms(b"x")
    )
    check("P44 authenticated chunk posts", post_result[:2] == (0, 1))
    seal_result = p.seal_session(c, alice_session, "alice")
    check("P45 immutable seal", seal_result[:2] == (1, post_result[2])
          and payable_reverted(lambda: p.post_data(
              c, alice_session, "alice", **post_terms(b"y"))))
    for i in range(20):
        p._install_data_session_for_test(
            DataSession(
                f"expired-{i:02}", str(i), c.timestamp - 1,
                refundable_bond=1,
            ),
            i + 8,
        )
    gc_result = p.gc_sessions(c)
    check("P46 one GC call is bounded",
          gc_result[0] == SESSION_MAINTENANCE_SCANNED
          and gc_result[1] == MAX_GC_STEPS)
    pre = protocol().snapshot()
    post = pre.snapshot()
    activate_normal(post, c)
    post.submit(candidate(post, c, "reorg"), c)
    post.sync(Clock(1_200, post.normal_deadline))
    post = pre.snapshot()
    check("P47 replay truncates all effects", post.identical(pre))
    end_to_end = T_INCLUDE_MAX_SECONDS + ESCAPE_OFFSET + T_INCLUDE_MAX_SECONDS + CLOCK_SKEW
    check("P48 recovery fits final lag", end_to_end <= DELTA_FINAL_LAG)
    check("P49 escape covers depth and proof", ESCAPE_OFFSET >= T_DEPTH_MAX + P_PROVE_MAX)
    check("P50 candidate totals are independent", MAX_FORCE_CANDIDATE_MESSAGES == 256 and MAX_FORCE_CANDIDATE_GAS == 80_000_000)

    delayed = protocol()
    opened = clock(1_100, 1_100)
    data_expiry = opened.timestamp + P_PROVE_MAX + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
    late_data = delayed.next_data_session_id("alice")
    assert delayed.open_session(
        opened, "alice", 0, data_expiry, payment=10
    ) == late_data
    delayed_post = delayed.post_data(
        opened, late_data, "alice", **post_terms(b"body")
    )
    assert delayed_post[:2] == (0, 1)
    assert delayed.seal_session(opened, late_data, "alice") == (
        1, delayed_post[2], data_expiry
    )
    activate_normal(delayed, opened)
    base = candidate(delayed, opened, "data-best")
    data_block = replace(base.tip, data_records=((late_data, 0),))
    with_data = replace(
        base,
        blocks=(data_block,),
        session_refs=(SessionRef(late_data, 1, delayed.sessions[late_data].root),),
    )
    reward_execution_gas, reward_published_bytes = reward_candidate_metrics_v1(
        delayed, with_data
    )
    with_data = replace(
        with_data,
        reward_execution_gas=reward_execution_gas,
        reward_published_bytes=reward_published_bytes,
    )
    assert delayed.submit(with_data, opened) == "ACCEPTED"
    after_expiry = Clock(2_000, data_expiry + 1)
    old_tip = delayed.core.tip_hash
    check("P50a delayed close cannot commit expired data",
          delayed.sync(after_expiry) and delayed.core.tip_hash == old_tip)
    delayed.gc_sessions(after_expiry)
    while late_data in delayed.sessions:
        delayed.gc_sessions(after_expiry)
    check("P50b GC retained the best until sync cleared it",
          late_data not in delayed.sessions)

if __name__ == "__main__":
    for test in (
        test_canonical_outputs_and_checkpoint,
        test_admission_freeze_and_tier_canonicalization,
        test_force_merkle_bounds_and_auth,
        test_late_close_and_constant_boundary,
        test_recovery_refresh_and_historical_immutability,
        test_registry_liability_and_release_units,
        test_data_gc_reorg_and_geometry,
    ):
        test()
    print("RESULTS: settlement/recovery model — ALL PROPERTIES PASS")
    for index, name in enumerate(PASS, 1):
        print(f"  [{index:03d}] {name}")
