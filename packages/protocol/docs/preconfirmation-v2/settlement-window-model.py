#!/usr/bin/env python3
"""Executable state-machine model for Slot-Chain settlement and recovery.

Cryptographic verification is represented by explicit booleans. Byte-exact
Merkle and commitment fixtures live in commitment-model.py. Unlike the earlier
model, historical headers are immutable and due coverage is a boundary check,
not a scan hidden inside trusted Python state.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field, replace
from enum import Enum, IntFlag, auto
import hashlib
import sys
from types import MappingProxyType
from typing import Any, Callable

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
ANCHOR_GAS_MAX = 1_000_000
ANCHOR_ACTIVATION_GAS_MAX = 12_000_000
ACTIVATION_FORCE_GAS_BUDGET = 13_000_000
SYSTEM_GAS_MARGIN = 5_000_000
INBOX_APPLY_GAS_MAX = SYSTEM_GAS_MARGIN
SYSTEM_TX_TYPE = 0x7F
SYSTEM_KIND_ANCHOR = 0
SYSTEM_KIND_INBOX_APPLY = 1
ANCHOR_STEADY_SELECTOR = "0x523e6854"
ANCHOR_ACTIVATION_SELECTOR = "0x0e58dc58"
INBOX_APPLY_SELECTOR = "0x6b326168"
MAX_BLOCKS_PER_CANDIDATE = 4_096
MAX_WINDOWS_PER_CANDIDATE = 12
MAX_DATA_SESSIONS_PER_CANDIDATE = 16
MAX_DATA_RECORDS_PER_CANDIDATE = 2_100
MAX_DATA_RECORDS_PER_SESSION = 2_100
MAX_LIVE_DATA_SESSIONS = 1_024
MAX_DATA_SESSIONS_PER_OWNER = 2
MAX_GC_STEPS = 8
MAX_LIVE_WINDOWS = 268
ENTRY_DELAY_WINDOWS = 8
MAX_TRANCHE_AHEAD_WINDOWS = 16
EVIDENCE_DELAY_SECONDS = 86_400
MAX_REPLACEMENTS_PER_WINDOW = 4
MAX_LIABILITY_GENERATIONS = MAX_REPLACEMENTS_PER_WINDOW * MAX_LIVE_WINDOWS
MAX_LIVE_RESERVATIONS = 64 * (MAX_TRANCHE_AHEAD_WINDOWS + 1)
DATA_TTL_SECONDS = 86_400
REORG_MARGIN_SECONDS = 1_800
UINT64_MAX = (1 << 64) - 1
SEAT_UINT256_MAX = (1 << 256) - 1
G_MAX = DELTA_FINAL_LAG
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
NON_PROTOCOL_MARKET_UNIT_PRIMITIVES = frozenset({
    "stage_best",
    "install_stage",
    "expire_stage",
    "invalidate_stage",
    "accrue_premium",
    "close_reserve",
    "request_release",
    "finalize_release",
    "enforce_breach",
    "is_duty_history_safe",
})
SEAT_ARMED_MAGIC = b"SARM"
SEAT_ABORTED_MAGIC = b"SABT"
SEAT_MIGRATION_RESPONSE_LENGTH = 4 + 8 + 8 + 8 + 32 + 8
SEAT_MIGRATION_MANIFEST_DELAY = 100
SEAT_MIGRATION_CANCEL_DELAY = 100


def seat_u256(value: int, name: str) -> int:
    if type(value) is not int or value < 0 or value > SEAT_UINT256_MAX:
        raise ValueError(f"{name} is outside uint256")
    return value


def seat_checked_add(left: int, right: int, name: str) -> int:
    result = seat_u256(left, f"{name} left") + seat_u256(right, f"{name} right")
    if result > SEAT_UINT256_MAX:
        raise ValueError(f"{name} overflows uint256")
    return result


def seat_checked_sub(left: int, right: int, name: str) -> int:
    left = seat_u256(left, f"{name} left")
    right = seat_u256(right, f"{name} right")
    if right > left:
        raise ValueError(f"{name} underflows uint256")
    return left - right
MAX_ARM_AGE_BLOCKS = 255
EIP2935_HISTORY_ENTRIES = 8_191
L1_SLOT_SECONDS = 12
SUPPORT_FINALITY_BLOCKS = F_L1 + (
    REORG_MARGIN_SECONDS + L1_SLOT_SECONDS - 1
) // L1_SLOT_SECONDS
MAX_BRIDGE_TOPOLOGIES_PER_PROFILE = 64
MAX_BRIDGE_ENQUEUE_DELAY = 7 * 86_400
BRIDGE_PROCESS_TTL_SECONDS = 30 * 86_400
CANONICAL_HISTORY_CAPACITY = 256
L1_HEADER_ORACLE_ADDRESS = "eip-2935-header-oracle"
L1_HEADER_ORACLE_RUNTIME_HASH = "code:eip2935-header-oracle:v1"
L1_HEADER_ORACLE_CONFIGURATION_HASH = "config:eip2935:8191:v1"
MAX_REGISTRATION_PROOF_NODES = 132
MAX_REGISTRATION_PROOF_BYTES = 80_000
APPENDING_SENTINEL = UINT64_MAX
INBOX_BATCH_OK_V2_WORD = bytes.fromhex("49425632" + "00" * 28)
TERMINAL_COMMITMENT_ABI_BYTES = 4 * 32

MAX_LIABILITY_RESIDENCE_WINDOWS = (
    MAX_TRANCHE_AHEAD_WINDOWS + 1
    + (EVIDENCE_DELAY_SECONDS + REORG_MARGIN_SECONDS + 383) // 384 + 2
)
RESERVATION_EVIDENCE_RETENTION_WINDOWS = (
    1 + (EVIDENCE_DELAY_SECONDS + REORG_MARGIN_SECONDS + 383) // 384 + 2
)


class Mode(Enum):
    PREACTIVE = auto()
    NORMAL = auto()
    RECOVERY = auto()


class Cause(IntFlag):
    NONE = 0
    SLA = 1
    FORCE_DUE = 2


@dataclass(frozen=True)
class SystemTransactionV2:
    tx_type: int
    chain_id: int
    system_kind: int
    system_nonce: int
    gas_limit: int
    to: str
    value: int
    selector: str
    signed: bool = False

    def valid(self, *, block_number: int, first_v2_block_number: int,
              launch_imported_l2_block_number: int,
              first_activation: bool, l2_chain_id: int,
              anchor_address: str = "anchor:v2",
              inbox_apply_address: str = "inbox-apply") -> bool:
        if self.system_kind == SYSTEM_KIND_ANCHOR:
            expected_selector = (ANCHOR_ACTIVATION_SELECTOR if first_activation
                                 else ANCHOR_STEADY_SELECTOR)
            expected_gas = (ANCHOR_ACTIVATION_GAS_MAX if first_activation
                            else ANCHOR_GAS_MAX)
            expected_to = anchor_address
        elif self.system_kind == SYSTEM_KIND_INBOX_APPLY:
            expected_selector = INBOX_APPLY_SELECTOR
            expected_gas = INBOX_APPLY_GAS_MAX
            expected_to = inbox_apply_address
        else:
            return False
        return (self.tx_type == SYSTEM_TX_TYPE
                and self.chain_id == l2_chain_id
                and 0 < l2_chain_id <= UINT64_MAX
                and first_v2_block_number
                    == launch_imported_l2_block_number + 1
                and self.system_nonce
                    == block_number - first_v2_block_number
                and block_number >= first_v2_block_number
                and self.gas_limit == expected_gas
                and self.to == expected_to and self.value == 0
                and self.selector == expected_selector and not self.signed)


@dataclass(frozen=True)
class SystemExecutionRulesV2:
    """Consensus effects not inherited from any ordinary account transaction."""

    reserved_sender: str
    caller: str
    origin: str
    sender_nonce_before: int
    sender_nonce_after: int
    sender_balance_before: int
    sender_balance_after: int
    gas_price_opcode: int
    zero_calldata_bytes: int
    nonzero_calldata_bytes: int
    intrinsic_gas: int
    sender_warm: bool
    target_warm: bool
    typed_tx_trie_value: bool
    typed_receipt_trie_value: bool

    def valid(self, tx: SystemTransactionV2) -> bool:
        expected_intrinsic = (21_000 + 4 * self.zero_calldata_bytes
                              + 16 * self.nonzero_calldata_bytes)
        return (self.caller == self.reserved_sender
                and self.origin == self.reserved_sender
                and self.sender_nonce_after == self.sender_nonce_before
                and self.sender_balance_after == self.sender_balance_before
                and self.gas_price_opcode == 0
                and self.zero_calldata_bytes >= 0
                and self.nonzero_calldata_bytes >= 4
                and self.intrinsic_gas == expected_intrinsic
                and self.intrinsic_gas <= tx.gas_limit
                and self.sender_warm and self.target_warm
                and self.typed_tx_trie_value
                and self.typed_receipt_trie_value)


@dataclass
class L2ActivationLatch:
    active: bool = False

    def activate_from_anchor(self, *, custom_system_tx: bool,
                             slot_chain_fork_active: bool,
                             l1_cutover_authenticated: bool) -> bool:
        if (self.active or not custom_system_tx or not slot_chain_fork_active
                or not l1_cutover_authenticated):
            return False
        self.active = True
        return True

    def inbox_apply(self, *, custom_system_tx: bool) -> bool:
        return self.active and custom_system_tx

    def bridge_v2_call(self) -> bool:
        return self.active


class Tier(Enum):
    NORMAL_SIGNED = 1
    RECOVERY_SIGNED = 2
    ESCAPE_UNSIGNED = 3


class ForceKind(Enum):
    USER_TX = 0
    BRIDGE_CREDIT = 1


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
class L1HeaderOracle:
    """Protocol-lifetime authenticated EIP-2935/system header source."""

    address: str
    runtime_hash: str
    configuration_hash: str
    _headers: object = field(repr=False)

    def __post_init__(self) -> None:
        if (
            not self.address
            or not self.runtime_hash
            or not self.configuration_hash
            or type(self._headers) is not dict
            or any(
                type(number) is not int
                or number < 0
                or type(header) is not L1Header
                for number, header in self._headers.items()
            )
        ):
            raise ValueError("L1 header oracle deployment is invalid")
        object.__setattr__(
            self, "_headers", MappingProxyType(dict(self._headers))
        )

    def __deepcopy__(self, memo: dict[int, object]) -> "L1HeaderOracle":
        return self

    def header(self, block_number: int) -> L1Header:
        if type(block_number) is not int or block_number < 0:
            raise KeyError("invalid L1 header number")
        return self._headers[block_number]

    def fork_for_test(
        self, substitutions: dict[int, L1Header]
    ) -> "L1HeaderOracle":
        headers = dict(self._headers)
        headers.update(substitutions)
        return L1HeaderOracle(
            self.address,
            self.runtime_hash,
            self.configuration_hash,
            headers,
        )


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


def model_force_root(descriptors: list[Message]) -> str:
    """Single behavioral queue-root oracle; byte-exact Merkle lives elsewhere."""
    return (f"merkle:{len(descriptors)}:"
            + ":".join(row.payload_hash for row in descriptors))


@dataclass(frozen=True)
class DataRecord:
    index: int
    body_root: str
    valid_until: int


@dataclass
class DataSession:
    session_id: str
    owner: str
    expiry: int
    records: list[DataRecord] = field(default_factory=list)
    root: str = "empty"
    sealed: bool = False


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
    inbox_pre_cursor: int = 0
    inbox_post_cursor: int = 0
    force_gas_budget: int = FORCE_GAS_BUDGET
    release_activation: bool = False
    release_protocol_version: int = 0
    release_manifest_hash: str = ""
    data_records: tuple[tuple[str, int], ...] = ()
    dispositions_ok: bool = True
    discretionary_body: bool = True


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
    recovery_fields_zero: bool = True
    end_terminal_root: str = "terminal:empty"
    end_terminal_count: int = 0

    @property
    def tip(self) -> Block:
        return self.blocks[-1]

    @property
    def count(self) -> int:
        return len(self.blocks)

    @property
    def order(self) -> tuple[int, int, int]:
        return (self.count, self.tip.slot, -int(self.tip.block_hash, 16))


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
    terminal_root: str = "terminal:empty"
    terminal_count: int = 0


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
                f"{c.terminal_root}:{c.terminal_count}:"
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
    migration_terminal: bool = False


class RouterPhase(Enum):
    ACTIVE = 1
    ARMED = 2
    READY = 3


@dataclass(frozen=True)
class RouterWord:
    generation: int
    active_version: int
    target_version: int
    target_manifest_hash: bytes
    phase: RouterPhase


@dataclass(frozen=True)
class SeatMigrationResponse:
    magic: bytes
    router_generation: int
    active_protocol_version: int
    target_protocol_version: int
    target_manifest_hash: bytes
    seat_generation: int


@dataclass(frozen=True)
class SeatMigrationArm:
    router_word: RouterWord
    seat_generation: int
    completed_at: int
    migration_stage_id: bytes | None = None
    migration_lineup_commitment: bytes | None = None


@dataclass(frozen=True)
class SeatMigrationAbort:
    canceled_arm: RouterWord
    seat_generation: int
    completed_at: int


@dataclass(frozen=True)
class ScheduledSeatMigration:
    generation: int
    active_protocol_version: int
    target_protocol_version: int
    target_manifest_hash: bytes
    scheduled_at: int
    executable_at: int
    old_authorization_id: bytes = b""
    new_authorization_id: bytes = b""

    @property
    def key(self) -> tuple[int, int, int, bytes]:
        return (
            self.generation,
            self.active_protocol_version,
            self.target_protocol_version,
            self.target_manifest_hash,
        )


def _migration_u64(value: int, name: str) -> bytes:
    value = seat_u256(value, name)
    if value > UINT64_MAX:
        raise ValueError(f"{name} is outside uint64")
    return value.to_bytes(8, "big")


def encode_seat_migration_response(response: SeatMigrationResponse) -> bytes:
    if type(response) is not SeatMigrationResponse:
        raise ValueError("malformed seat migration response")
    if response.magic not in (SEAT_ARMED_MAGIC, SEAT_ABORTED_MAGIC):
        raise ValueError("unknown seat migration response magic")
    if (
        type(response.target_manifest_hash) is not bytes
        or len(response.target_manifest_hash) != 32
    ):
        raise ValueError("migration manifest must be exact bytes32")
    return b"".join((
        response.magic,
        _migration_u64(response.router_generation, "router generation"),
        _migration_u64(response.active_protocol_version, "active protocol version"),
        _migration_u64(response.target_protocol_version, "target protocol version"),
        response.target_manifest_hash,
        _migration_u64(response.seat_generation, "seat generation"),
    ))


def decode_seat_migration_response(raw: bytes) -> SeatMigrationResponse:
    if type(raw) is not bytes or len(raw) != SEAT_MIGRATION_RESPONSE_LENGTH:
        raise ValueError("seat migration response has noncanonical length")
    magic = raw[:4]
    if magic not in (SEAT_ARMED_MAGIC, SEAT_ABORTED_MAGIC):
        raise ValueError("seat migration response has wrong magic")
    return SeatMigrationResponse(
        magic,
        int.from_bytes(raw[4:12], "big"),
        int.from_bytes(raw[12:20], "big"),
        int.from_bytes(raw[20:28], "big"),
        raw[28:60],
        int.from_bytes(raw[60:68], "big"),
    )


@dataclass(frozen=True)
class Generation:
    address: str
    bond: int
    registration_index: int
    effective_window: int
    max_reserved_window: int = 0
    reservations_closed: bool = False


@dataclass
class MigrationGate:
    """Shared generation gate; READY follows only authenticated live counters."""

    mode: str = "ACTIVE"
    generation: int = 0
    active_protocol_version: int = 0
    target_protocol_version: int = 0
    target_manifest_hash: str | bytes = ""
    coordinator: str = ""
    live_data_sessions: int = 0
    canceled_generations: set[int] = field(default_factory=set)
    canceled_words: dict[int, RouterWord] = field(default_factory=dict)

    def __setattr__(self, name: str, value: object) -> None:
        if name == "coordinator" and name in self.__dict__:
            raise AttributeError("migration coordinator is immutable")
        object.__setattr__(self, name, value)

    @property
    def router_word(self) -> RouterWord:
        phases = {
            "ACTIVE": RouterPhase.ACTIVE,
            "ARMED": RouterPhase.ARMED,
            "READY": RouterPhase.READY,
        }
        phase = phases.get(self.mode)
        if phase is None:
            raise ValueError("migration router phase is invalid")
        manifest = self.target_manifest_hash
        if manifest == "":
            exact_manifest = b"\x00" * 32
        elif type(manifest) is bytes and len(manifest) == 32:
            exact_manifest = manifest
        else:
            raise ValueError("migration router manifest is not exact bytes32")
        return RouterWord(
            self.generation,
            self.active_protocol_version,
            self.target_protocol_version,
            exact_manifest,
            phase,
        )

    def _bootstrap_from_router(
        self, protocol_version: int, coordinator: str = "version-manager"
    ) -> bool:
        if (self.active_protocol_version != 0 or protocol_version <= 0
                or self.mode != "ACTIVE" or self.coordinator != ""
                or not coordinator):
            return False
        self.active_protocol_version = protocol_version
        object.__setattr__(self, "coordinator", coordinator)
        return True

    def _arm_from_manager(self, generation: int, active_protocol_version: int,
            target_protocol_version: int, manifest_hash: str, *, caller: str) -> bool:
        if (self.mode == "ARMED" and generation == self.generation
                and active_protocol_version == self.active_protocol_version
                and target_protocol_version == self.target_protocol_version
                and manifest_hash == self.target_manifest_hash
                and caller == self.coordinator):
            return True
        if (self.mode != "ACTIVE" or generation != self.generation + 1
                or caller != self.coordinator or not manifest_hash
                or active_protocol_version != self.active_protocol_version
                or target_protocol_version <= active_protocol_version):
            return False
        self.generation = generation
        self.target_protocol_version = target_protocol_version
        self.target_manifest_hash = manifest_hash
        self.mode = "ARMED"
        return True

    def _try_ready_from_protocol(
        self,
        *,
        normal_open: bool,
        recovery_active: bool,
        local_arm_complete: bool = True,
    ) -> bool:
        if (self.mode != "ARMED" or normal_open or recovery_active
                or self.live_data_sessions != 0 or not local_arm_complete):
            return False
        self.mode = "READY"
        return True

    def _activate_from_router(self, generation: int, old_protocol_version: int,
                        new_protocol_version: int) -> bool:
        if (self.mode != "READY" or generation != self.generation
                or old_protocol_version != self.active_protocol_version
                or new_protocol_version != self.target_protocol_version):
            return False
        self.active_protocol_version = new_protocol_version
        self.target_protocol_version = 0
        self.target_manifest_hash = ""
        self.mode = "ACTIVE"
        return True

    def _abort_from_manager(self, generation: int, active_protocol_version: int,
              target_protocol_version: int, manifest_hash: str, *,
              cancel_manifest_active: bool, caller: str) -> bool:
        """Permissionless execution of a separately delayed exact cancel."""
        if (caller != self.coordinator
                or self.mode not in {"ARMED", "READY"}
                or not cancel_manifest_active
                or generation != self.generation
                or active_protocol_version != self.active_protocol_version
                or target_protocol_version != self.target_protocol_version
                or manifest_hash != self.target_manifest_hash):
            return False
        canceled_word = self.router_word
        self.canceled_generations.add(generation)
        self.canceled_words[generation] = canceled_word
        self.target_protocol_version = 0
        self.target_manifest_hash = ""
        self.mode = "ACTIVE"
        return True


@dataclass
class RegistryLifecycle:
    active: list[Generation]
    liability_ring: list[tuple[Generation, int] | None] = field(
        default_factory=lambda: [None] * MAX_LIABILITY_GENERATIONS)
    replacements: dict[int, int] = field(default_factory=dict)
    movement_sequence: int = 0
    migration_gate: MigrationGate = field(default_factory=MigrationGate)
    open_reservations: set[tuple[int, int]] = field(default_factory=set)
    liable_reservations: set[tuple[int, int]] = field(default_factory=set)

    @property
    def liabilities(self) -> list[Generation]:
        return [item[0] for item in self.liability_ring if item is not None]

    def _prune_liable_reservations(self, current_window: int) -> int:
        releasable = {
            row for row in self.liable_reservations
            if row[1] + RESERVATION_EVIDENCE_RETENTION_WINDOWS
            <= current_window
        }
        self.liable_reservations.difference_update(releasable)
        return len(releasable)

    def settle_reservations_before(self, current_window: int) -> int:
        """Ordinary evidence-safe lifecycle; migration never mutates tranches."""
        self._prune_liable_reservations(current_window)
        expired = {row for row in self.open_reservations
                   if row[1] < current_window}
        self.open_reservations.difference_update(expired)
        self.liable_reservations.update(expired)
        return len(expired)

    def reserve(self, address: str, window: int, current_window: int) -> bool:
        if self.migration_gate.mode != "ACTIVE":
            return False
        self.settle_reservations_before(current_window)
        for index, generation in enumerate(self.active):
            if generation.address != address:
                continue
            if (generation.reservations_closed
                    or window < current_window
                    or window > current_window + MAX_TRANCHE_AHEAD_WINDOWS):
                return False
            self.active[index] = replace(
                generation, max_reserved_window=max(generation.max_reserved_window, window))
            reservation = (generation.registration_index, window)
            if reservation in self.liable_reservations:
                return False
            if reservation not in self.open_reservations:
                self.open_reservations.add(reservation)
                assert len(self.open_reservations) <= MAX_LIVE_RESERVATIONS
            return True
        return False

    def arm_migration(self) -> None:
        # The shared gate is the reversible migration veto.  The permanent
        # reservations_closed bit remains reserved for exit/replacement.
        assert self.migration_gate.mode == "ARMED"

    def _move_reservations_to_liability(self, registration_index: int) -> int:
        moved = {row for row in self.open_reservations
                 if row[0] == registration_index}
        self.open_reservations.difference_update(moved)
        self.liable_reservations.update(moved)
        return len(moved)

    def release_liability(self, ring_index: int, current_window: int) -> bool:
        occupant = self.liability_ring[ring_index]
        if occupant is None or occupant[1] > current_window:
            return False
        registration_index = occupant[0].registration_index
        self.liability_ring[ring_index] = None
        self.liable_reservations = {
            row for row in self.liable_reservations
            if row[0] != registration_index}
        return True

    def admit(self, entry: Generation, current_window: int) -> bool:
        if any(g.address == entry.address for g in self.active + self.liabilities):
            return False
        if entry.effective_window < current_window + ENTRY_DELAY_WINDOWS:
            return False
        if len(self.active) < 64:
            self.active.append(entry)
            return True
        if self.replacements.get(current_window, 0) >= MAX_REPLACEMENTS_PER_WINDOW:
            return False
        victim = min(self.active, key=lambda item: (item.bond, -item.registration_index))
        if entry.bond <= victim.bond:
            return False
        if victim.max_reserved_window > current_window + MAX_TRANCHE_AHEAD_WINDOWS:
            return False
        ring_index = self.movement_sequence % MAX_LIABILITY_GENERATIONS
        occupant = self.liability_ring[ring_index]
        if occupant is not None and occupant[1] > current_window:
            return False
        release_window = (
            victim.max_reserved_window + 1
            + (EVIDENCE_DELAY_SECONDS + REORG_MARGIN_SECONDS + 383) // 384 + 2
        )
        self._move_reservations_to_liability(victim.registration_index)
        self.active.remove(victim)
        self.active.append(entry)
        self.liability_ring[ring_index] = (replace(victim, reservations_closed=True), release_window)
        self.movement_sequence += 1
        self.replacements[current_window] = self.replacements.get(current_window, 0) + 1
        return True


def tranche_releasable(window: int, global_min_referenced_slot: int,
                       now: int, evidence_and_reorg_deadline: int) -> bool:
    window_end_slot = 384 * (window + 1) - 1
    return (window_end_slot < global_min_referenced_slot
            and now > evidence_and_reorg_deadline)


def normal_context_id(base_hash: str, admission_version: int, admission_root: str,
                      anchor_number: int, anchor_hash: str) -> str:
    return (f"normal:{base_hash}:{admission_version}:{admission_root}:"
            f"{anchor_number}:{anchor_hash}")


@dataclass
class Protocol:
    canonical: Canonical
    header_oracle: L1HeaderOracle
    forced_queue: "QueueContinuity"
    inbox_apply_router: "InboxApplyRouterV2"
    settlement_address: str = "model-settlement"
    mode: Mode = Mode.NORMAL
    release_activation_pending: bool = False
    pending_release_protocol_version: int = 0
    pending_release_manifest_hash: str = ""
    first_v2_block_number: int = 0
    queue_capacity: int = MAX_FORCE_QUEUE_ITEMS  # model-only capacity override
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
    seat_services: dict[bytes, SeatService] = field(default_factory=dict)
    seat_lineup: list[bytes] = field(default_factory=list)
    seat_duties: dict[bytes, Duty] = field(default_factory=dict)
    term_duty: dict[bytes, bytes] = field(default_factory=dict)
    duty_ring: list[SeatDutyCell] = field(
        default_factory=lambda: [SeatDutyCell() for _ in range(DUTY_RING_CAPACITY)]
    )
    duty_sequence: int = 0
    seat_selections: dict[bytes, SelectionRecord] = field(default_factory=dict)
    term_selection: dict[bytes, bytes] = field(default_factory=dict)
    seat_selection: SelectionRecord | None = None
    settlement_seat_stage: SettlementSeatStage | None = None
    stage_tombstones: dict[bytes, StageTombstone] = field(default_factory=dict)
    outstanding_stage_tombstone_id: bytes | None = None
    seat_generation: int = 7
    seat_lineup_revision: int = 0
    seat_authorization_id: bytes | None = None
    seat_market_address: str | None = None
    seat_runway_seconds: int = SEAT_RUNWAY_SECONDS
    minimum_primary_tenure_seconds: int = MIN_PRIMARY_TENURE_SECONDS
    minimum_standby_tenure_seconds: int = MIN_STANDBY_TENURE_SECONDS
    exit_delay_seconds: int = EXIT_DELAY_SECONDS
    seat_fault_point: str | None = None
    seat_scan_count: int = 0
    seat_scan_visits_total: int = 0
    seat_sla_trigger_pending: bool = False
    seat_migration_arm: SeatMigrationArm | None = None
    seat_migration_abort: SeatMigrationAbort | None = None
    seat_migration_local_generation: int | None = None
    sessions: dict[str, DataSession] = field(default_factory=dict)
    gc_cursor: int = 0
    events: list[str] = field(default_factory=list)
    boundary_queries: int = 0
    canonical_state_witness_available: bool = True
    canonical_code_preimages_available: bool = True
    seat_profile_ready: bool = True
    seat_configuration_ready: bool = True
    migration_gate: MigrationGate = field(default_factory=MigrationGate)
    versioned_history: object | None = None

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "header_oracle", "forced_queue", "inbox_apply_router",
            "migration_gate", "settlement_address",
        } and name in self.__dict__:
            raise AttributeError(f"Protocol {name} is immutable")
        object.__setattr__(self, name, value)

    @property
    def core(self) -> CanonicalCore:
        return self.canonical.core

    def _is_current_settlement_target(self) -> bool:
        history = self.versioned_history
        if history is not None and not isinstance(
            history, VersionedSettlementHistory
        ):
            # Narrow unit-history adapters still exercise the transaction
            # rollback path; they do not model a router registration.
            return True
        if history is None:
            return True
        try:
            target_state = history.exact_market_target_state()
        except ValueError:
            return False
        return (
            target_state[0] == self.settlement_address
            and target_state[6] in {"ACTIVE", "ARMED", "READY"}
            and self.forced_queue.active_settlement_address
                == self.settlement_address
        )

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

    @staticmethod
    def _seat_hash(*parts: object) -> bytes:
        encoded = b"TAIKO_SETTLEMENT_SEAT_MODEL_V1"
        for part in parts:
            if isinstance(part, bytes):
                encoded += len(part).to_bytes(4, "big") + part
            elif isinstance(part, int) and not isinstance(part, bool) and part >= 0:
                encoded += seat_u256(part, "seat commitment integer").to_bytes(
                    32, "big"
                )
            elif isinstance(part, str):
                raw = part.encode("utf-8")
                encoded += len(raw).to_bytes(4, "big") + raw
            else:
                raise ValueError("seat commitment input is not canonical")
        return hashlib.sha256(encoded).digest()

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
        fixed_ids.extend([b""] * (SEAT_COUNT - len(fixed_ids)))
        return self._seat_hash(
            "LINEUP",
            self.seat_lineup_revision,
            fixed_ids[0],
            fixed_ids[1],
            fixed_ids[2],
            fixed_ids[3],
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

        return self._seat_hash(
            "TERM",
            authorization_id,
            generation,
            offer_id,
            tranche_id,
            installed_at,
            lineup_revision_at_install,
        )

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
            expected_selection_id = self._seat_hash(
                "SELECTION",
                selection.term_id,
                selection.tranche_id,
                selection.offer_id,
                selection.selected_canonical_sequence,
                selection.selected_at,
                selection.target_tip,
                selection.source.name,
                selection.predecessor_duty_id or b"",
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
                    != self._seat_hash(
                        "SELECTION",
                        selection.term_id,
                        selection.tranche_id,
                        selection.offer_id,
                        selection.selected_canonical_sequence,
                        selection.selected_at,
                        selection.target_tip,
                        selection.source.name,
                        selection.predecessor_duty_id or b"",
                    )
            ):
                raise AssertionError("retained selection history is not exact")
            seen_selected_terms.add(selection.term_id)
        if set(self.term_selection) != seen_selected_terms:
            raise AssertionError("selection reverse index is incomplete")
        seen_tranches: set[bytes] = set()
        for term_id, term in self.seat_terms.items():
            if term_id != term.term_id or len(term_id) != 32:
                raise AssertionError("seat term identity mismatch")
            if term.tranche_id in seen_tranches:
                raise AssertionError("installed tranche bound more than once")
            seen_tranches.add(term.tranche_id)
            if term_id not in self.seat_services:
                raise AssertionError("seat term lacks service record")
            service = self.seat_services[term_id]
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
                    service.prospective_target_tip
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
                    raise AssertionError("prospective duty thresholds changed")
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
                    != self._seat_hash(
                        "DUTY",
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
        duty_id = self._seat_hash(
            "DUTY", term_id, sequence, exact_base_sequence, exact_base_tip_slot
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
        service.ring_full_recovery_at = None
        return DutyAttachmentOutcome(DutyAttachmentStatus.ATTACHED, duty)

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
            or any(row.tranche_id == term.tranche_id for row in self.seat_terms.values())
            or not 0 <= rank <= len(self.seat_lineup) < SEAT_COUNT
        ):
            raise ValueError("invalid synthetic seat term")
        self.seat_terms[term.term_id] = term
        self.seat_services[term.term_id] = SeatService(
            None,
            seat_checked_add(
                term.installed_at,
                self.minimum_standby_tenure_seconds,
                "minimum standby tenure",
            ),
            None,
            None,
        )
        revision_before = self.seat_lineup_revision
        self.seat_lineup.insert(rank, term.term_id)
        if start_primary:
            if rank != 0 or self.active_primary_term_id is not None:
                raise ValueError("direct service must fill a primary vacancy")
            self._start_seat_service(
                term.term_id,
                term.installed_at,
                base_tip_slot=self.core.tip_slot,
                base_sequence=self.core.l2_block_number,
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
            candidates.append(duty.failover_at)
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
                    candidates.append(
                        seat_checked_add(
                            recovery_at,
                            DELTA_FINAL_LAG - DELTA_RECOVERY_LAG,
                            "implied duty failover",
                        )
                    )
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
        selection_id = self._seat_hash(
            "SELECTION",
            term.term_id,
            term.tranche_id,
            term.offer_id,
            self.core.l2_block_number,
            selected_at,
            exact_target_tip,
            source.name,
            trigger_duty_id or b"",
        )
        self.seat_selection = SelectionRecord(
            selection_id,
            term.term_id,
            term.tranche_id,
            term.offer_id,
            self.core.l2_block_number,
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
        fresh_base_tip = max(
            self.core.tip_slot,
            seat_checked_sub(start, GENESIS_TIMESTAMP, "promotion start slot"),
        )
        started = self._start_seat_service(
            term_id,
            start,
            base_tip_slot=fresh_base_tip,
            base_sequence=self.core.l2_block_number,
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
            fresh_base_tip = max(
                self.core.tip_slot,
                seat_checked_sub(
                    exact_start,
                    GENESIS_TIMESTAMP,
                    "selected responsibility slot",
                ),
            )
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
            duty.status = DutyStatus.FAILED_OVER
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
            duty.status = DutyStatus.BREACHED
            duty.disposition_at = clock.timestamp
            duty.breach_recorded_at = clock.timestamp
            self.events.append(f"SEAT_BREACH_RECORDED:{duty.duty_id.hex()}")
            changed = True
        return changed

    def _satisfy_activated_duty(self, duty: Duty, clock: Clock) -> bool:
        if duty.status not in (DutyStatus.OPEN, DutyStatus.FAILED_OVER):
            return False
        prior = duty.status
        revision_before = self.seat_lineup_revision
        duty.status = DutyStatus.SATISFIED
        if duty.satisfied_at is None:
            duty.satisfied_at = clock.timestamp
            duty.disposition_at = clock.timestamp
        start_successor = False
        roster_changed = False
        if prior is DutyStatus.OPEN and duty.term_id in self.seat_lineup:
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
        elif prior is DutyStatus.FAILED_OVER:
            start_successor = (
                self.seat_selection is not None
                and self.seat_selection.predecessor_duty_id == duty.duty_id
            )
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
        excuse_for_migration: bool = False,
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
                and self.core.l2_block_number > duty.base_sequence
                and self.core.tip_slot >= duty.target_tip
            ):
                self._satisfy_activated_duty(duty, clock)
                satisfied += 1
                changed = True
            if (
                excuse_for_migration
                and duty.status in (DutyStatus.OPEN, DutyStatus.FAILED_OVER)
            ):
                duty.status = DutyStatus.EXCUSED_MIGRATION
                duty.disposition_at = clock.timestamp
                changed = True
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
            and self.core.l2_block_number
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
            or self.core.l2_block_number <= service.duty_base_sequence
            or self.core.tip_slot < service.prospective_target_tip
        ):
            return False
        self._set_prospective_duty(
            active,
            self.core.tip_slot,
            self.core.l2_block_number,
        )
        return True

    def _sync_prospective_deadline(
        self,
        clock: Clock,
        reusable_index: int | None,
        *,
        excuse_for_migration: bool = False,
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
                        if (
                            excuse_for_migration
                            and attached.status
                            in (DutyStatus.OPEN, DutyStatus.FAILED_OVER)
                        ):
                            attached.status = DutyStatus.EXCUSED_MIGRATION
                            attached.disposition_at = clock.timestamp
                            changed = True
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

        scan = self._scan_seat_duties(clock, allow_cure=False)
        prospective_changed, _ = self._sync_prospective_deadline(
            clock, scan.reusable_index
        )
        return scan.changed or prospective_changed

    def _close_seats_for_migration(self, close_at: int) -> None:
        """Vacate the roster after the one-pass migration duty settlement."""

        close_at = seat_u256(close_at, "migration seat close")
        self._vacate_entire_lineup(close_at, "MIGRATION")
        self._assert_seat_valid()

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
        """Snapshot canonical state and every shared authoritative object."""

        history = self.versioned_history
        return {
            "protocol": copy.deepcopy(self.__dict__),
            "header_oracle": self.header_oracle,
            "forced_queue": self.forced_queue,
            "forced_queue_state": copy.deepcopy(self.forced_queue.__dict__),
            "inbox_apply_router": self.inbox_apply_router,
            "inbox_apply_router_state": copy.deepcopy(
                self.inbox_apply_router.__dict__
            ),
            "migration_gate": self.migration_gate,
            "migration_gate_state": copy.deepcopy(self.migration_gate.__dict__),
            "history": history,
            "history_router_authority": (
                getattr(history, "_router_authority", None)
                if history is not None else None
            ),
            "history_state": (
                copy.deepcopy({
                    key: value for key, value in history.__dict__.items()
                    if key != "_router_authority"
                })
                if history is not None else None
            ),
        }

    def _assert_canonical_history_binding(self) -> None:
        """Require the one active Settlement transaction/authority graph."""

        history = self.versioned_history
        if history is None:
            return
        if (
            getattr(history, "forced_queue", None) is not self.forced_queue
            or getattr(history, "inbox_apply_router", None)
            is not self.inbox_apply_router
            or getattr(history, "migration_gate", None) is not self.migration_gate
            or getattr(history, "live_protocol", None) is not self
        ):
            raise AssertionError("invalid canonical history authority graph")
        if isinstance(history, VersionedSettlementHistory):
            try:
                history.exact_market_target_state()
            except ValueError as exc:
                raise AssertionError(
                    "invalid canonical history authority graph"
                ) from exc

    def _restore_canonical_transaction(
        self, snapshot: dict[str, object]
    ) -> None:
        """Restore a failed canonical transaction without breaking aliases."""

        queue = snapshot["forced_queue"]
        router = snapshot["inbox_apply_router"]
        gate = snapshot["migration_gate"]
        history = snapshot["history"]
        self._restore_object(self, snapshot["protocol"])
        object.__setattr__(self, "header_oracle", snapshot["header_oracle"])
        self._restore_object(queue, snapshot["forced_queue_state"])
        self._restore_object(router, snapshot["inbox_apply_router_state"])
        self._restore_object(gate, snapshot["migration_gate_state"])
        object.__setattr__(self, "forced_queue", queue)
        object.__setattr__(self, "inbox_apply_router", router)
        object.__setattr__(self, "migration_gate", gate)
        self.versioned_history = history
        if history is None:
            return
        self._restore_object(history, snapshot["history_state"])
        object.__setattr__(history, "forced_queue", queue)
        object.__setattr__(history, "inbox_apply_router", router)
        object.__setattr__(history, "migration_gate", gate)
        history.live_protocol = self
        if hasattr(history, "_router_authority"):
            object.__setattr__(
                history,
                "_router_authority",
                snapshot["history_router_authority"],
            )

    def _composed_seat_call(
        self, market: object, transition: Callable[[], object]
    ) -> object:
        self._assert_canonical_history_binding()
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

        if (
            self.versioned_history is not None
            and self.versioned_history.mode == "FROZEN"
        ):
            # Historical economic calls read this target-local retained ledger;
            # they never replay current canonical maintenance through it.
            return False

        boundary_queries = self.boundary_queries
        seat_scan_count = self.seat_scan_count
        seat_scan_visits_total = self.seat_scan_visits_total
        changed = self.sync(clock)
        if not changed:
            self.boundary_queries = boundary_queries
            self.seat_scan_count = seat_scan_count
            self.seat_scan_visits_total = seat_scan_visits_total
        return changed

    def execute_market_target_rotation(
        self,
        market: object,
        manager: object,
        receipt_key: tuple[int, bytes],
        clock: Clock,
    ) -> object:
        """Compose exact frozen-tombstone acknowledgement with Market rotation."""

        history = self.versioned_history
        receipt_reader = getattr(manager, "activation_receipt", None)
        receipt = (
            None if not callable(receipt_reader) else receipt_reader(receipt_key)
        )
        if (
            history is None
            or history.live_protocol is not self
            or history.mode != "FROZEN"
            or self.settlement_address != history.address
            or getattr(market, "release_manager", None) is not manager
            or getattr(market, "market_address", None)
            != self.seat_market_address
            or receipt is None
            or receipt.old_target != self.settlement_address
            or receipt.old_protocol_version != history.protocol_version
            or receipt.old_authorization_id != self.seat_authorization_id
        ):
            raise ValueError("rotation missed the exact frozen Settlement target")
        runtime = manager.target_runtimes.get(receipt.old_authorization_id)
        if runtime is None or runtime.authority is not history:
            raise ValueError("rotation old-target read route is not exact")
        tombstone = None
        if receipt.migration_stage_id is not None:
            tombstone = self.stage_tombstones.get(receipt.migration_stage_id)
            if (
                tombstone is None
                or tombstone.reconciled
                or not tombstone.migration_terminal
                or tombstone.stage_id != receipt.migration_stage_id
                or tombstone.lineup_commitment
                != receipt.migration_lineup_commitment
            ):
                raise ValueError("migration stage tombstone is not exact")
        elif receipt.migration_lineup_commitment is not None:
            raise ValueError("migration stage tuple is partial")

        self._assert_canonical_history_binding()
        settlement_snapshot = self._canonical_transaction_snapshot()
        market_snapshot = market._transaction_snapshot()
        try:
            result = market._rotate_installation_target(
                manager=manager,
                receipt_key=receipt_key,
                clock=clock,
                migration_stage_authenticated=tombstone is not None,
            )
            if tombstone is not None:
                tombstone.reconciled = True
                if self.outstanding_stage_tombstone_id == tombstone.stage_id:
                    self.outstanding_stage_tombstone_id = None
                market._fault("after_migration_tombstone_ack")
            self._assert_seat_valid()
            market.assert_valid()
            return result
        except BaseException:
            self._restore_canonical_transaction(settlement_snapshot)
            market._restore_transaction(market_snapshot)
            raise

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
        if (
            self.seat_authorization_id is None
            or self.seat_authorization_id != market.current_authorization_id
            or market.authorization.target != self.settlement_address
            or market.cached_generation != self.seat_generation
        ):
            raise ValueError("Market is not the bound installation target")
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
                )
            )
        return module.LineupSnapshot(
            target=self.settlement_address,
            authorization_id=self.seat_authorization_id,
            generation=self.seat_generation,
            commitment=self.seat_lineup_commitment(),
            terms=tuple(rows),
        )

    def _market_service_view(self, market: object, term_id: bytes) -> object:
        """Derive the only ServiceView admitted by the production-facing façade."""

        module = self._bound_market_module(market)
        term = self.seat_terms.get(term_id)
        service = self.seat_services.get(term_id)
        if term is None or service is None:
            raise ValueError("unknown exact seat term")
        tranche = market.tranches.get(term.tranche_id)
        if tranche is None or tranche.installed_term_id != term_id:
            raise ValueError("Market lacks exact installed tranche binding")
        auth = market.authorizations.get(tranche.authorization_id)
        if auth is None or auth.target != self.settlement_address:
            raise ValueError("historical Settlement authorization is absent")
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
                )
                if value is not None
            )
        elif duty.status in (DutyStatus.OPEN, DutyStatus.FAILED_OVER):
            disposition = "OPEN"
            disposition_at = None
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
            target=auth.target,
            authorization_id=tranche.authorization_id,
            settlement_chain_id=auth.settlement_chain_id,
            protocol_version=auth.protocol_version,
            runtime_hash=auth.runtime_hash,
            configuration_hash=auth.configuration_hash,
            magic=auth.expected_magic,
            generation=tranche.generation,
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
        )

    def stage_best(self, market: object, clock: Clock) -> object:
        """Noncanonical façade; raw caller-supplied lineup views are not accepted."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        if self.mode is not Mode.NORMAL or self.migration_gate.mode != "ACTIVE":
            raise ValueError("seat staging is unavailable")
        if (
            self.versioned_history is not None
            and self.versioned_history.mode != "ACTIVE"
        ):
            raise ValueError("historical Settlement cannot stage seats")

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
        if self.mode is not Mode.NORMAL or self.migration_gate.mode != "ACTIVE":
            raise ValueError("seat stage cannot apply outside healthy active mode")
        if (
            self.versioned_history is not None
            and self.versioned_history.mode != "ACTIVE"
        ):
            raise ValueError("historical Settlement cannot apply a seat stage")

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
                or market.stage is None
                or market.stage.stage_id != stage.stage_id
                or market.stage.offer_id != stage.offer_id
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
                required_headroom_until = seat_checked_add(
                    stage.expires_at,
                    T_INCLUDE_MAX_SECONDS,
                    "stage inclusion headroom",
                )
                if (
                    active != outgoing
                    or service is None
                    or service.closed_at is not None
                    or service.service_eligible_until is None
                    or required_headroom_until > service.service_eligible_until
                ):
                    raise ValueError("outgoing primary is no longer healthy/funded")
                self._close_service(outgoing, clock.timestamp, "HEALTHY_HANDOVER")
                self._remove_lineup_term(outgoing, clock.timestamp)
                market._settlement_close_reserve(
                    self._market_service_view(market, outgoing),
                    module.Clock(clock.timestamp, clock.block_number),
                    atomic_healthy=True,
                )
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
            market_result = market._settlement_install_stage(install)
            self._seat_fault("after_market_install")
            term = SeatTerm(
                term_id,
                stage.tranche_id,
                stage.offer_id,
                stage.operator,
                stage.payout,
                stage.ask,
                clock.timestamp,
            )
            if (
                term.term_id in self.seat_terms
                or any(row.tranche_id == term.tranche_id
                       for row in self.seat_terms.values())
                or not 0 <= stage.selected_rank <= len(self.seat_lineup)
                or len(self.seat_lineup) >= SEAT_COUNT
            ):
                raise ValueError("term installation collides with retained history")
            self.seat_terms[term.term_id] = term
            self.seat_services[term.term_id] = SeatService(
                None,
                seat_checked_add(
                    clock.timestamp,
                    self.minimum_standby_tenure_seconds,
                    "minimum standby tenure",
                ),
                None,
                None,
            )
            self.seat_lineup.insert(stage.selected_rank, term.term_id)
            if stage.selected_rank == 0:
                self._start_seat_service(
                    term.term_id,
                    clock.timestamp,
                    base_tip_slot=self.core.tip_slot,
                    base_sequence=self.core.l2_block_number,
                )
            if self.seat_lineup_revision != install_revision - 1:
                raise AssertionError("compound install changed lineup revision twice")
            self.seat_lineup_revision = install_revision
            self._seat_fault("after_term_install")
            self.settlement_seat_stage = None
            self._seat_fault("after_settlement_stage_clear")
            return market_result

        return self._composed_seat_call(market, transition)

    def expire_stage(self, market: object, clock: Clock) -> object:
        """Permissionless ordinary expiry, atomic across both components."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"
        if (
            self.versioned_history is not None
            and self.versioned_history.mode != "ACTIVE"
        ):
            raise ValueError("historical Settlement cannot expire a seat stage")

        def transition() -> object:
            module = self._bound_market_module(market)
            stage = self.settlement_seat_stage
            if stage is None or clock.timestamp < stage.expires_at:
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
            history_active = (
                self.versioned_history is None
                or self.versioned_history.mode == "ACTIVE"
            )
            abort_cancel = (
                tombstone is not None
                and tombstone.migration_terminal
                and self.seat_migration_abort is not None
                and self.seat_migration_arm is not None
                and self.seat_migration_abort.canceled_arm.phase
                in (RouterPhase.ARMED, RouterPhase.READY)
                and self.migration_gate.canceled_words.get(
                    self.seat_migration_abort.canceled_arm.generation
                ) == self.seat_migration_abort.canceled_arm
                and self.seat_migration_abort.canceled_arm.generation
                == self.seat_migration_arm.router_word.generation
                and self.seat_migration_abort.canceled_arm.active_version
                == self.seat_migration_arm.router_word.active_version
                and self.seat_migration_abort.canceled_arm.target_version
                == self.seat_migration_arm.router_word.target_version
                and self.seat_migration_abort.canceled_arm.target_manifest_hash
                == self.seat_migration_arm.router_word.target_manifest_hash
                and self.seat_migration_arm.migration_stage_id
                == tombstone.stage_id
                and self.seat_migration_arm.migration_lineup_commitment
                == tombstone.lineup_commitment
                and history_active
            )
            if (
                tombstone is None
                or tombstone.reconciled
                or (tombstone.migration_terminal and not abort_cancel)
                or (
                    self.seat_migration_arm is not None
                    and self.seat_migration_abort is None
                    and not abort_cancel
                )
                or not history_active
                or tombstone.stage_id != stage_id
                or tombstone.lineup_commitment != lineup_commitment
            ):
                raise ValueError("stale or mismatched stage tombstone")
            result = (
                market._settlement_cancel_stage_for_migration(
                    stage_id, lineup_commitment, self._market_module(market).Clock(
                        clock.timestamp, clock.block_number
                    )
                )
                if abort_cancel
                else market._settlement_invalidate_stage(
                    stage_id, lineup_commitment
                )
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
        """Permissionless exact roster removal with mandatory leading sync."""

        market_before = copy.deepcopy(market)
        if self._leading_seat_sync(clock):
            if market != market_before:
                raise AssertionError("canonical leading sync called Market")
            return "SYNCED"

        def transition() -> object:
            module = self._bound_market_module(market)
            if (
                term_id not in self.seat_lineup
                or term_id == self.selected_successor_term_id
                or clock.timestamp < self.installed_exit_at(term_id)
            ):
                raise ValueError("installed exit is not removable")
            was_primary = self.active_primary_term_id == term_id
            duty_id = self.term_duty.get(term_id)
            duty = self.seat_duties.get(duty_id) if duty_id is not None else None
            unresolved = duty is not None and duty.status in (
                DutyStatus.OPEN, DutyStatus.FAILED_OVER
            )
            revision_before = self.seat_lineup_revision
            self._close_service(term_id, clock.timestamp, "VOLUNTARY_EXIT")
            self._remove_lineup_term(term_id, clock.timestamp)
            self._seat_fault("after_exit_roster_removal")
            result = market._settlement_close_reserve(
                self._market_service_view(market, term_id),
                module.Clock(clock.timestamp, clock.block_number),
                atomic_healthy=True,
            )
            self._seat_fault("after_exit_reserve_reconciliation")
            if was_primary and self.seat_lineup:
                successor = self.seat_lineup[0]
                if self.seat_services[successor].responsibility_start is not None:
                    raise AssertionError("voluntary successor already started")
                self._start_seat_service(
                    successor,
                    clock.timestamp,
                    base_tip_slot=max(
                        self.core.tip_slot,
                        seat_checked_sub(
                            clock.timestamp,
                            GENESIS_TIMESTAMP,
                            "voluntary successor start slot",
                        ),
                    ),
                    base_sequence=self.core.l2_block_number,
                )
            if self.seat_lineup_revision == revision_before:
                self._advance_lineup_revision()
            self._invalidate_local_stage("VOLUNTARY_EXIT")
            return result

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
        root = model_force_root(self.messages[:cutoff])
        if cutoff == self.forced_queue.count:
            assert root == self.forced_queue.root
        return root

    @staticmethod
    def _due_at(message: Message) -> int:
        return max(message.enqueued_at + FORCE_DELAY, message.due_at)

    def next_due_at(self, cursor: int, cutoff: int | None = None) -> int:
        self.boundary_queries += 1
        limit = len(self.messages) if cutoff is None else cutoff
        return self._due_at(self.messages[cursor]) if cursor < limit else UINT64_MAX

    def force_due(self, clock: Clock) -> bool:
        return self.next_due_at(self.core.message_cursor) <= clock.timestamp

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
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "MIGRATION_ARMED"
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
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "MIGRATION_ARMED"
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
        self, clock: Clock, *, excuse_for_migration: bool = False
    ) -> tuple[bool, SeatDutyScanOutcome | None]:
        if self.normal_deadline is None or clock.timestamp < self.normal_deadline:
            return False, None
        self._assert_canonical_history_binding()
        protocol_snapshot = self._canonical_transaction_snapshot()
        try:
            outcome = None
            if (self.normal_best is not None
                    and self.next_due_at(self.normal_best.tip.message_end)
                        > clock.timestamp
                    and clock.timestamp + REORG_MARGIN_SECONDS
                        <= self.normal_best_min_data_expiry):
                outcome = self._commit(
                    self.normal_best,
                    clock,
                    excuse_for_migration=excuse_for_migration,
                )
                self.events.append("NORMAL_COMMITTED")
            else:
                self.events.append("NORMAL_CANCELED_FORCE_OMISSION")
            self._clear_normal()
            return True, outcome
        except BaseException:
            self._restore_canonical_transaction(protocol_snapshot)
            raise

    def _new_round(self, clock: Clock, causes: Cause, revision: int) -> RecoveryRound:
        anchor_number = clock.block_number - 1
        anchor = self.header_oracle.header(anchor_number)
        cutoff = len(self.messages)
        escape_slot = max(clock.l2_slot + ESCAPE_OFFSET, self.core.tip_slot + 1)
        return RecoveryRound(
            self.episode, revision, self.canonical.base_hash, clock.l2_slot,
            anchor_number, anchor.block_hash,
            self.force_root(cutoff), cutoff, self.admission_version,
            self.admission_root, escape_slot,
            GENESIS_TIMESTAMP + escape_slot + DELTA_TIP, causes,
        )

    def _activate(self, clock: Clock, causes: Cause) -> None:
        self._clear_normal()
        self._invalidate_local_stage("RECOVERY_OPEN")
        self.seat_sla_trigger_pending = False
        self.mode = Mode.RECOVERY
        self.episode += 1
        self.recovery = self._new_round(clock, causes, 1)
        self.events.append(f"RECOVERY_OPEN:{self.episode}:{int(causes)}")

    def _roll_recovery(self, clock: Clock) -> bool:
        assert self.recovery is not None
        if clock.timestamp <= self.recovery.expires_at:
            return False
        old = self.recovery
        self.recovery = self._new_round(clock, old.causes, old.revision + 1)
        if self.selected_successor_term_id is not None:
            self._promote_selected(clock.timestamp)
        self.events.append(f"RECOVERY_ROLLED:{self.recovery.revision}")
        return True

    def _migration_callback_response(
        self, magic: bytes, word: RouterWord
    ) -> bytes:
        response = SeatMigrationResponse(
            magic,
            word.generation,
            word.active_version,
            word.target_version,
            word.target_manifest_hash,
            self.seat_generation,
        )
        raw = encode_seat_migration_response(response)
        prefix = "arm" if magic == SEAT_ARMED_MAGIC else "abort"
        if self.seat_fault_point == f"{prefix}_response_short":
            return raw[:-1]
        if self.seat_fault_point == f"{prefix}_response_empty":
            return b""
        if self.seat_fault_point in {
            f"{prefix}_response_long", f"{prefix}_response_trailing"
        }:
            return raw + b"\x00"
        if self.seat_fault_point == f"{prefix}_response_wrong_magic":
            return b"FAIL" + raw[4:]
        if self.seat_fault_point == f"{prefix}_response_wrong_generation":
            forged = replace(response, router_generation=response.router_generation + 1)
            return encode_seat_migration_response(forged)
        if self.seat_fault_point == f"{prefix}_response_wrong_active_version":
            forged = replace(
                response,
                active_protocol_version=response.active_protocol_version + 1,
            )
            return encode_seat_migration_response(forged)
        if self.seat_fault_point == f"{prefix}_response_wrong_target_version":
            forged = replace(
                response,
                target_protocol_version=response.target_protocol_version + 1,
            )
            return encode_seat_migration_response(forged)
        if self.seat_fault_point == f"{prefix}_response_wrong_manifest":
            forged = replace(response, target_manifest_hash=b"x" * 32)
            return encode_seat_migration_response(forged)
        if self.seat_fault_point == f"{prefix}_response_wrong_seat_generation":
            forged = replace(response, seat_generation=response.seat_generation + 1)
            return encode_seat_migration_response(forged)
        return raw

    def complete_seat_migration_arm(
        self,
        *,
        caller: str,
        router_word: RouterWord,
        clock: Clock,
    ) -> bytes:
        """Manager-only local completion; never returns generic ``SYNCED``."""

        if (
            caller != self.migration_gate.coordinator
            or type(router_word) is not RouterWord
            or router_word != self.migration_gate.router_word
            or router_word.phase is not RouterPhase.ARMED
            or router_word.active_version <= 0
            or router_word.target_version <= router_word.active_version
            or self.seat_migration_local_generation == router_word.generation
        ):
            raise ValueError("seat migration arm authority tuple is invalid")
        if self.versioned_history is not None and (
            self.versioned_history.protocol_version != router_word.active_version
            or self.versioned_history.live_protocol is not self
            or self.versioned_history.mode != "MIGRATION_ARMED"
        ):
            raise ValueError("seat migration arm history binding is invalid")

        snapshot = self._canonical_transaction_snapshot()
        try:
            stage = self.settlement_seat_stage
            stage_id = (
                stage.stage_id
                if stage is not None
                else self.outstanding_stage_tombstone_id
            )
            retained_tombstone = (
                None if stage_id is None else self.stage_tombstones.get(stage_id)
            )
            stage_commitment = (
                stage.lineup_commitment
                if stage is not None
                else (
                    None
                    if retained_tombstone is None
                    else retained_tombstone.lineup_commitment
                )
            )
            self._sync_impl(
                clock,
                allow_migration_ready=False,
                excuse_for_migration=True,
            )
            if self.migration_gate.router_word != router_word:
                raise AssertionError("local arm leading sync changed router word")
            if self.seat_generation >= UINT64_MAX:
                raise ValueError("seat generation is exhausted")
            self.seat_generation += 1
            self._close_seats_for_migration(clock.timestamp)
            # A leading sync may already have tombstoned the stage for a more
            # specific canonical reason.  The arm binds that same exact record
            # so rotation can terminally cancel the Market half once.
            if stage_id is not None:
                tombstone = self.stage_tombstones.get(stage_id)
                if (
                    tombstone is None
                    or tombstone.lineup_commitment != stage_commitment
                ):
                    raise AssertionError("migration lost the exact stage tombstone")
                tombstone.migration_terminal = True
            self.seat_migration_local_generation = router_word.generation
            self.seat_migration_arm = SeatMigrationArm(
                router_word,
                self.seat_generation,
                clock.timestamp,
                stage_id,
                stage_commitment,
            )
            self.seat_migration_abort = None
            self.events.append(
                f"SEAT_MIGRATION_ARMED:{router_word.generation}:"
                f"{self.seat_generation}"
            )
            self._seat_fault("after_local_migration_arm")
            self._assert_seat_valid()
            return self._migration_callback_response(SEAT_ARMED_MAGIC, router_word)
        except BaseException:
            self._restore_canonical_transaction(snapshot)
            raise

    def complete_seat_migration_abort(
        self,
        *,
        caller: str,
        canceled_arm: RouterWord,
        clock: Clock,
    ) -> bytes:
        """Authenticate the retained canceled tuple and complete post-abort sync."""

        active_word = self.migration_gate.router_word
        armed_word = (
            None
            if self.seat_migration_arm is None
            else self.seat_migration_arm.router_word
        )
        if (
            caller != self.migration_gate.coordinator
            or type(canceled_arm) is not RouterWord
            or canceled_arm.phase not in (RouterPhase.ARMED, RouterPhase.READY)
            or self.migration_gate.canceled_words.get(canceled_arm.generation)
            != canceled_arm
            or active_word.phase is not RouterPhase.ACTIVE
            or active_word.generation != canceled_arm.generation
            or active_word.active_version != canceled_arm.active_version
            or active_word.target_version != 0
            or active_word.target_manifest_hash != b"\x00" * 32
            or armed_word is None
            or armed_word.generation != canceled_arm.generation
            or armed_word.active_version != canceled_arm.active_version
            or armed_word.target_version != canceled_arm.target_version
            or armed_word.target_manifest_hash
            != canceled_arm.target_manifest_hash
            or armed_word.phase is not RouterPhase.ARMED
        ):
            raise ValueError("seat migration abort authority tuple is invalid")
        snapshot = self._canonical_transaction_snapshot()
        try:
            retained_generation = self.seat_generation
            self.sync(clock)
            if self.seat_generation != retained_generation:
                raise AssertionError("migration abort changed seat generation")
            self.seat_migration_abort = SeatMigrationAbort(
                canceled_arm, self.seat_generation, clock.timestamp
            )
            self.events.append(
                f"SEAT_MIGRATION_ABORTED:{canceled_arm.generation}:"
                f"{self.seat_generation}"
            )
            self._seat_fault("after_local_migration_abort")
            return self._migration_callback_response(
                SEAT_ABORTED_MAGIC, canceled_arm
            )
        except BaseException:
            self._restore_canonical_transaction(snapshot)
            raise

    def _arm_migration_for_test(self, generation: int) -> bool:
        """Legacy model fixture only; production uses ProtocolVersionManager."""

        if (self.mode is Mode.PREACTIVE
                or self.release_activation_pending
                or self.migration_gate.mode != "ARMED"
                or self.migration_gate.generation != generation):
            return False
        if self.mode is Mode.NORMAL and self.normal_deadline is None:
            self._clear_normal()
        self.seat_migration_local_generation = generation
        self.events.append(f"MIGRATION_ARMED:{generation}")
        return True

    def _cleanup_migration_sessions(self) -> int:
        removed = 0
        for key in sorted(tuple(self.sessions))[:MAX_GC_STEPS]:
            del self.sessions[key]
            self.migration_gate.live_data_sessions -= 1
            removed += 1
        if removed:
            self.events.append(f"MIGRATION_SESSION_REFUNDS:{removed}")
        return removed

    def _sync_migration(
        self, clock: Clock, *, allow_ready: bool = True
    ) -> bool:
        changed = False
        if self.mode is Mode.RECOVERY:
            assert self.recovery is not None
            if clock.timestamp > self.recovery.expires_at:
                self.recovery = None
                self.mode = Mode.NORMAL
                self.events.append("MIGRATION_RECOVERY_CANCELED")
                changed = True
        else:
            due = self.force_due(clock)
            if self.normal_deadline is not None:
                if due and clock.timestamp < self.normal_deadline:
                    self._clear_normal()
                    self.events.append("MIGRATION_NORMAL_CANCELED_FORCE_DUE")
                    changed = True
                elif clock.timestamp >= self.normal_deadline:
                    normal_closed, _ = self._close_mature_normal(clock)
                    changed |= normal_closed
            elif self.normal_arm_block_number is not None:
                self._clear_normal()
                changed = True
        boundary_open = (self.mode is Mode.RECOVERY
                         or self.normal_deadline is not None
                         or self.normal_best is not None
                         or self.normal_arm_block_number is not None)
        if not boundary_open:
            changed |= self._cleanup_migration_sessions() > 0
        if self.migration_gate._try_ready_from_protocol(
                normal_open=boundary_open and self.mode is Mode.NORMAL,
                recovery_active=self.mode is Mode.RECOVERY,
                local_arm_complete=(
                    allow_ready
                    and self.seat_migration_local_generation
                    == self.migration_gate.generation
                )):
            if (
                self.versioned_history is not None
                and self.versioned_history.mode == "MIGRATION_ARMED"
            ):
                self.versioned_history.mode = "MIGRATION_READY"
            self.events.append("MIGRATION_READY")
            changed = True
        return changed

    def sync(self, clock: Clock) -> bool:
        if self.mode is Mode.PREACTIVE:
            return False
        if not self._is_current_settlement_target():
            return False
        self._assert_canonical_history_binding()
        snapshot = self._canonical_transaction_snapshot()
        try:
            return self._sync_impl(clock)
        except BaseException:
            self._restore_canonical_transaction(snapshot)
            raise

    def _sync_impl(
        self,
        clock: Clock,
        *,
        allow_migration_ready: bool = True,
        excuse_for_migration: bool = False,
    ) -> bool:
        normal_changed = False
        commit_outcome: SeatDutyScanOutcome | None = None
        if (
            self.mode is Mode.NORMAL
            and self.normal_deadline is not None
            and clock.timestamp >= self.normal_deadline
        ):
            normal_changed, commit_outcome = self._close_mature_normal(
                clock, excuse_for_migration=excuse_for_migration
            )
        if commit_outcome is None:
            scan = self._scan_seat_duties(
                clock,
                allow_cure=False,
                excuse_for_migration=excuse_for_migration,
            )
            prospective_changed, prospective_sla = \
                self._sync_prospective_deadline(
                    clock,
                    scan.reusable_index,
                    excuse_for_migration=excuse_for_migration,
                )
            seat_changed = scan.changed or prospective_changed
            seat_sla_missed = scan.sla_missed or prospective_sla
        else:
            seat_changed = commit_outcome.changed
            seat_sla_missed = commit_outcome.sla_missed
        if self.migration_gate.mode == "ARMED":
            return (
                self._sync_migration(clock, allow_ready=allow_migration_ready)
                or seat_changed
                or normal_changed
            )
        if self.migration_gate.mode == "READY":
            return True
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
            and clock.l2_slot - self.core.tip_slot > DELTA_FINAL_LAG
        ):
            causes |= Cause.SLA
        if self.force_due(clock):
            causes |= Cause.FORCE_DUE
        if causes:
            self._activate(clock, causes)
            changed = True
        return changed

    def activate_migration(self, clock: Clock, imported: Canonical,
                           activation_output: Canonical | None = None,
                           *, old_quiescent: bool, router_switched: bool,
                           header_checkpoint_authenticated: bool = True,
                           l2_system_accounts_authenticated: bool = True,
                           l2_v2_latch_disabled: bool = True,
                           activation_proof_valid: bool = True,
                           target_components_valid: bool = True) -> bool:
        if (self.mode is not Mode.PREACTIVE or clock.timestamp < GENESIS_TIMESTAMP
                or not old_quiescent or not router_switched
                or not header_checkpoint_authenticated
                or not l2_system_accounts_authenticated
                or not l2_v2_latch_disabled
                or not activation_proof_valid or not target_components_valid
                or activation_output is None
                or self.messages
                or imported.canonicalized_at_block != clock.block_number
                or imported.core.l2_block_number >= (1 << 48) - 1
                or imported.core.message_cursor != 0
                or imported.core.tip_slot > clock.l2_slot
                or imported.core.winning_data_commitment == "empty"
                or imported.core.next_base_fee <= 0
                or activation_output.core.l2_block_number
                    != imported.core.l2_block_number + 1
                or activation_output.core.tip_slot <= imported.core.tip_slot
                or activation_output.core.message_cursor != 0
                or activation_output.core.terminal_root
                    != imported.core.terminal_root
                or activation_output.core.terminal_count
                    != imported.core.terminal_count
                or activation_output.core.next_base_fee <= 0):
            return False
        self.canonical = Canonical(
            copy.deepcopy(activation_output.core), clock.block_number)
        self.mode = Mode.NORMAL
        self.first_v2_block_number = imported.core.l2_block_number + 1
        self.events.append("MIGRATION_ACTIVATION_PROOF_ADOPTED_ATOMICALLY")
        return True

    def tombstone(self) -> None:
        self.admission_version += 1
        self.admission_root = f"admission:{self.admission_version}"

    @staticmethod
    def _valid_bridge_static(message: Message) -> bool:
        return (message.kind is ForceKind.BRIDGE_CREDIT
                and message.outer_authorized
                and message.valid_until == UINT64_MAX
                and message.intrinsic_gas > 0
                and message.accounted_gas
                    >= max(message.intrinsic_gas, MIN_FORCE_ACCOUNTED_GAS)
                and message.accounted_gas <= MAX_FORCE_MESSAGE_GAS
                and 0 < message.byte_length <= MAX_FORCE_MESSAGE_BYTES
                and message.prepaid > 0)

    def _append(self, clock: Clock, message: Message) -> None:
        prior_due = self._due_at(self.messages[-1]) if self.messages else 0
        deferred = (self.recovery.expires_at + 1
                    if self.mode is Mode.RECOVERY and self.recovery else 0)
        due = max(clock.timestamp + FORCE_DELAY, prior_due, deferred)
        assert self.forced_queue.count == len(self.messages)
        expected_index = self.forced_queue.count
        assert self.forced_queue.append(
            replace(message, enqueued_at=clock.timestamp),
            deposit=message.prepaid,
            due_at=due,
            caller=self.forced_queue.router_address) == expected_index

    def admit_message(self, clock: Clock, message: Message) -> str:
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "SYNCED"
        if (message.kind is not ForceKind.USER_TX
                or len(self.messages) >= self.queue_capacity):
            return "REJECTED"
        invalid = (not message.chain_id_ok or not message.signature_ok
                   or not message.outer_authorized or not message.sender
                   or message.valid_until <= clock.timestamp
                   or message.valid_until
                       > clock.timestamp + MAX_FORCE_VALIDITY_SECONDS)
        if (invalid or message.intrinsic_gas <= 0
                or message.accounted_gas < max(message.intrinsic_gas, MIN_FORCE_ACCOUNTED_GAS)
                or message.accounted_gas > MAX_FORCE_MESSAGE_GAS
                or not 0 < message.byte_length <= MAX_FORCE_MESSAGE_BYTES
                or message.prepaid <= 0):
            return "REJECTED"
        self._append(clock, message)
        return "ADMITTED"

    def sync_ingress(self, clock: Clock) -> tuple[str, tuple[int, int] | None]:
        """Nonpayable half: persist at most one sync decision and issue a stamp."""
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL", None
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE", None
        if self.sync(clock):
            return "SYNCED", None
        if self.migration_gate.mode != "ACTIVE":
            return "SYNCED", None
        return "ACTIVE", (self.migration_gate.active_protocol_version,
                           self.migration_gate.generation)

    def append_from_adapter(self, clock: Clock, message: Message,
                            stamp: tuple[int, int]) -> str:
        """Payable half: no second sync; require the exact still-live stamp."""
        if (self.mode is Mode.PREACTIVE
                or not self._is_current_settlement_target()
                or self.migration_gate.mode != "ACTIVE"
                or stamp != (self.migration_gate.active_protocol_version,
                             self.migration_gate.generation)):
            return "REJECTED_STALE_STAMP"
        if (len(self.messages) >= self.queue_capacity
                or not self._valid_bridge_static(message)):
            return "REJECTED"
        self._append(clock, message)
        return "ADMITTED"

    def admit_bridge_direct(self, clock: Clock, message: Message) -> str:
        """One top-level immutable-adapter trace over the stamped two-call ABI."""
        status, stamp = self.sync_ingress(clock)
        if stamp is None:
            return status
        return self.append_from_adapter(clock, message, stamp)

    def open_session(self, clock: Clock, session_id: str, owner: str, expiry: int) -> str:
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "MIGRATION_ARMED"
        self.gc_sessions(clock)
        if (not owner or session_id in self.sessions
                or expiry < clock.timestamp + P_PROVE_MAX + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
                or expiry > clock.timestamp + DATA_TTL_SECONDS
                or len(self.sessions) >= MAX_LIVE_DATA_SESSIONS
                or sum(s.owner == owner for s in self.sessions.values()) >= MAX_DATA_SESSIONS_PER_OWNER):
            return "REJECTED"
        self.sessions[session_id] = DataSession(session_id, owner, expiry)
        self.migration_gate.live_data_sessions += 1
        return "OPENED"

    def post_data(self, clock: Clock, session_id: str, caller: str, *,
                  body_root: str, same_tx_blobhash: bool, kzg_opening_ok: bool) -> str:
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "MIGRATION_ARMED"
        session = self.sessions.get(session_id)
        if (session is None or session.owner != caller or session.sealed
                or session.expiry <= clock.timestamp or not same_tx_blobhash
                or not kzg_opening_ok
                or len(session.records) >= MAX_DATA_RECORDS_PER_SESSION):
            return "REJECTED"
        index = len(session.records)
        session.records.append(DataRecord(index, body_root, session.expiry))
        session.root = f"mmr:{session.session_id}:{index + 1}:" + ":".join(
            record.body_root for record in session.records)
        return "POSTED"

    def seal_session(self, clock: Clock, session_id: str, caller: str) -> bool:
        if not self._is_current_settlement_target():
            return False
        if self.sync(clock):
            return False
        if self.migration_gate.mode != "ACTIVE":
            return False
        session = self.sessions.get(session_id)
        if session is None or session.owner != caller or session.sealed or not session.records:
            return False
        session.sealed = True
        return True

    def gc_sessions(self, clock: Clock) -> int:
        removed = 0
        retained = ({ref.session_id for ref in self.normal_best.session_refs}
                    if self.normal_best is not None else set())
        for key in sorted(tuple(self.sessions))[:MAX_GC_STEPS]:
            if self.sessions[key].expiry < clock.timestamp and key not in retained:
                del self.sessions[key]
                self.migration_gate.live_data_sessions -= 1
                removed += 1
        self.gc_cursor = (self.gc_cursor + MAX_GC_STEPS) % MAX_LIVE_DATA_SESSIONS
        return removed

    def _sessions_ok(self, candidate: Candidate, clock: Clock) -> bool:
        if (len(candidate.session_refs) > MAX_DATA_SESSIONS_PER_CANDIDATE
                or len({r.session_id for r in candidate.session_refs}) != len(candidate.session_refs)):
            return False
        used = [r for b in candidate.blocks for r in b.data_records]
        if len(used) > MAX_DATA_RECORDS_PER_CANDIDATE or len(used) != len(set(used)):
            return False
        declared = {r.session_id: r for r in candidate.session_refs}
        for ref in candidate.session_refs:
            session = self.sessions.get(ref.session_id)
            if (session is None or not session.sealed
                    or session.expiry < clock.timestamp + REORG_MARGIN_SECONDS
                    or ref.count != len(session.records) or ref.root != session.root):
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
                or candidate.next_base_fee <= 0
                or candidate.next_excess_blob_gas < 0
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
            expected_activation = (
                self.release_activation_pending
                and block is candidate.blocks[0])
            expected_force_gas_budget = (
                ACTIVATION_FORCE_GAS_BUDGET if expected_activation
                else FORCE_GAS_BUDGET)
            if (block.evm_timestamp != GENESIS_TIMESTAMP + block.slot
                    or block.parent_hash != parent or block.slot <= prior_slot
                    or (candidate.tier is Tier.NORMAL_SIGNED
                        and block.slot - prior_slot > G_MAX)
                    or block.message_start != cursor or not block.dispositions_ok
                    or block.anchor_number != first.anchor_number
                    or block.force_cutoff != first.force_cutoff
                    or block.force_root != first.force_root
                    or block.inbox_pre_cursor != block.message_start
                    or block.inbox_post_cursor != block.message_end
                    or block.release_activation != expected_activation
                    or block.release_protocol_version
                        != (self.pending_release_protocol_version
                            if expected_activation else 0)
                    or block.release_manifest_hash
                        != (self.pending_release_manifest_hash
                            if expected_activation else "")
                    or block.force_gas_budget != expected_force_gas_budget
                    or (expected_activation and block.discretionary_body)):
                return False
            expected = self._prefix_end(
                cursor, block.force_cutoff,
                gas_budget=block.force_gas_budget)
            if block.message_end != expected:
                return False
            for msg in self.messages[cursor:block.message_end]:
                if (msg.kind is ForceKind.USER_TX and not msg.payload_available
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
                or clock.l2_slot - candidate.tip.slot > DELTA_TIP
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
        if not self._is_current_settlement_target():
            return "REJECTED_HISTORICAL"
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
        if self.mode is Mode.RECOVERY:
            round_ = self.recovery
            if (
                round_ is None
                or self.migration_gate.mode == "READY"
                or clock.timestamp > round_.expires_at
            ):
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
        if (self.migration_gate.mode != "ACTIVE"
                and self.mode is not Mode.RECOVERY):
            return "MIGRATION_ARMED"
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

    def _commit(
        self,
        candidate: Candidate,
        clock: Clock,
        *,
        excuse_for_migration: bool = False,
    ) -> SeatDutyScanOutcome:
        self._assert_canonical_history_binding()
        protocol_snapshot = self._canonical_transaction_snapshot()
        try:
            assert (self.forced_queue.cursor
                    == self.inbox_apply_router.next_queue_index
                    == self.core.message_cursor)
            assert self.forced_queue.advance_cursor(
                candidate.blocks[0].inbox_pre_cursor,
                candidate.tip.inbox_post_cursor,
                caller=self.settlement_address,
                beneficiary=candidate.beneficiary)
            # This object represents adoption of the proof-authenticated L2
            # poststate; no L1 call writes the L2 router.
            self.inbox_apply_router.next_queue_index = \
                candidate.tip.inbox_post_cursor
            if candidate.blocks[0].release_activation:
                self.release_activation_pending = False
                self.pending_release_protocol_version = 0
                self.pending_release_manifest_hash = ""
            self.canonical = Canonical(
                CanonicalCore(candidate.end_l2_block_number,
                              candidate.tip.block_hash, candidate.tip.slot,
                              candidate.end_state_root, candidate.tip.message_end,
                              candidate.winning_data_commitment,
                              candidate.next_base_fee,
                              candidate.next_excess_blob_gas,
                              candidate.end_terminal_root,
                              candidate.end_terminal_count),
                clock.block_number,
            )
            if self.versioned_history is not None:
                history = self.versioned_history
                if history._record_canonical_from_protocol(
                    protocol=self, clock=clock
                ) is None:
                    raise AssertionError("atomic canonical-history write rejected")
                self._seat_fault("after_history_record")
            scan = self._scan_seat_duties(
                clock,
                allow_cure=True,
                excuse_for_migration=excuse_for_migration,
            )
            refreshed = self._refresh_prospective_after_commit()
            prospective_changed, prospective_sla = \
                self._sync_prospective_deadline(
                    clock,
                    scan.reusable_index,
                    excuse_for_migration=excuse_for_migration,
                )
            outcome = SeatDutyScanOutcome(
                scan.changed or refreshed or prospective_changed,
                scan.reusable_index,
                scan.sla_missed or prospective_sla,
                scan.satisfied,
            )
            self.events.append(f"CANONICAL:{candidate.candidate_id}")
            self._assert_seat_valid()
            return outcome
        except BaseException:
            self._restore_canonical_transaction(protocol_snapshot)
            raise


@dataclass(frozen=True)
class BridgeRecord:
    envelope: Message
    index: int
    caller: str
    deposit: int


@dataclass
class BridgeSupportEntry:
    protocol_version: int
    manifest_hash: str
    staged_at_block: int
    confirmed_at_block: int | None = None


@dataclass
class BridgeDomainRegistry:
    entries: dict[tuple[str, str, str], BridgeSupportEntry] = field(default_factory=dict)
    profile_additions: dict[int, int] = field(default_factory=dict)

    def stage(self, source_domain_id: str, execution_hash: str,
              destination_domain_id: str,
              protocol_version: int, manifest_hash: str,
              staged_at_block: int, *, caller_is_version_manager: bool,
              manifest_active: bool) -> bool:
        if (not caller_is_version_manager or not manifest_active
                or protocol_version <= 0 or not manifest_hash
                or not source_domain_id or not execution_hash
                or not destination_domain_id):
            return False
        key = (source_domain_id, execution_hash, destination_domain_id)
        entry = BridgeSupportEntry(
            protocol_version, manifest_hash, staged_at_block)
        if key in self.entries:
            return self.entries[key] == entry
        if self.profile_additions.get(protocol_version, 0) \
                >= MAX_BRIDGE_TOPOLOGIES_PER_PROFILE:
            return False
        self.entries[key] = entry
        self.profile_additions[protocol_version] = (
            self.profile_additions.get(protocol_version, 0) + 1)
        return True

    def confirm(self, source_domain_id: str, execution_hash: str,
                destination_domain_id: str, confirmed_at_block: int, *,
                protocol_version: int, canonical_sequence: int,
                router: ActiveSettlementRouter, proof_state_root: str,
                mpt_proof_valid: bool,
                proved_registration_commitment: str,
                expected_registration_commitment: str,
                proof_node_count: int, proof_byte_length: int) -> bool:
        entry = self.entries.get(
            (source_domain_id, execution_hash, destination_domain_id))
        canonical = router.canonical_at(protocol_version, canonical_sequence)
        if (entry is None or entry.confirmed_at_block is not None
                or entry.protocol_version != protocol_version
                or canonical is None
                or canonical.state_root != proof_state_root
                or confirmed_at_block
                    < canonical.canonicalized_at_block + F_L1
                or not mpt_proof_valid
                or not proved_registration_commitment
                or proved_registration_commitment
                    != expected_registration_commitment
                or not 0 < proof_node_count <= MAX_REGISTRATION_PROOF_NODES
                or not 0 < proof_byte_length <= MAX_REGISTRATION_PROOF_BYTES
                or confirmed_at_block < entry.staged_at_block):
            return False
        entry.confirmed_at_block = confirmed_at_block
        return True

    def final(self, source_domain_id: str, execution_hash: str,
              destination_domain_id: str,
              block_number: int) -> bool:
        entry = self.entries.get(
            (source_domain_id, execution_hash, destination_domain_id))
        return (entry is not None
                and entry.confirmed_at_block is not None
                and block_number
                    >= entry.confirmed_at_block + SUPPORT_FINALITY_BLOCKS)

    def remove(self, source_domain_id: str, execution_hash: str,
               destination_domain_id: str) -> bool:
        _ = (source_domain_id, execution_hash, destination_domain_id)
        return False


@dataclass(frozen=True)
class FrozenBridgeFacade:
    bridge: str
    runtime_hash: str
    storage_layout_hash: str
    terminal_verifier: str

    def accepts(self, *, bridge: str, runtime_hash: str,
                storage_layout_hash: str, terminal_verifier: str) -> bool:
        return (bridge == self.bridge and runtime_hash == self.runtime_hash
                and storage_layout_hash == self.storage_layout_hash
                and terminal_verifier == self.terminal_verifier)

    @staticmethod
    def delegate_target() -> None:
        return None

    @staticmethod
    def upgrade(_new_runtime_hash: str) -> bool:
        return False


@dataclass(frozen=True)
class CanonicalTerminalCommitment:
    protocol_version: int
    execution_profile_hash: str
    canonical_sequence: int
    l2_block_number: int
    block_hash: str
    state_root: str
    terminal_root: str
    terminal_count: int
    canonicalized_at_block: int


@dataclass
class QueueContinuity:
    address: str
    root: str
    count: int
    cursor: int
    escrow_balance: int
    last_due_at: int
    descriptors: list[Message] = field(default_factory=list)
    active_settlement_address: str = ""
    router_address: str = "active-settlement-router"
    claimable: dict[str, int] = field(default_factory=dict)
    runtime_hash: str = "code:forced-queue:v2"
    config_hash: str = "config:forced-queue:depth64:v2"
    nonproxy: bool = True
    selfdestruct_disabled: bool = True
    delegate_target_reachable: bool = False
    deposit_prefix: list[int] = field(default_factory=list)
    unconsumed_escrow: int | None = None
    total_claimable: int | None = None

    def __setattr__(self, name: str, value: object) -> None:
        immutable = {
            "address", "router_address", "runtime_hash", "config_hash",
            "nonproxy", "selfdestruct_disabled", "delegate_target_reachable",
        }
        if name in immutable and name in self.__dict__:
            raise AttributeError(f"forced queue {name} is immutable")
        object.__setattr__(self, name, value)

    def __post_init__(self) -> None:
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

    def append(self, descriptor: Message, *, deposit: int,
               due_at: int, caller: str) -> int | None:
        if (caller != self.router_address
                or not descriptor.payload_hash or deposit <= 0
                or descriptor.prepaid != deposit
                or due_at < self.last_due_at
                or self.count >= MAX_FORCE_QUEUE_ITEMS
                or self.count != len(self.descriptors)):
            return None
        index = self.count
        stored = replace(descriptor, due_at=due_at)
        self.count += 1
        self.escrow_balance += deposit
        assert self.unconsumed_escrow is not None
        self.unconsumed_escrow += deposit
        self.deposit_prefix.append(self.deposit_prefix[-1] + deposit)
        self.last_due_at = due_at
        self.descriptors.append(stored)
        self.root = model_force_root(self.descriptors)
        return index

    def set_active_settlement(self, *, expected_old: str, new: str,
                              caller: str) -> bool:
        if (caller != self.router_address or not new
                or self.active_settlement_address != expected_old):
            return False
        self.active_settlement_address = new
        return True

    def advance_cursor(self, expected_start: int, end: int, *,
                       caller: str, beneficiary: str) -> bool:
        if (caller != self.active_settlement_address
                or not beneficiary
                or expected_start != self.cursor
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


@dataclass(frozen=True)
class MigrationTransientState:
    normal_best_present: bool
    recovery_active: bool
    live_data_sessions: int
    unsettled_reward_preparation: int
    claim_only_surfaces_preserved: bool

    @property
    def settled(self) -> bool:
        return (not self.normal_best_present and not self.recovery_active
                and self.live_data_sessions == 0
                and self.unsettled_reward_preparation == 0
                and self.claim_only_surfaces_preserved)


@dataclass
class VersionedSettlementHistory:
    """Immutable Settlement whose history ring is written internally."""

    address: str
    runtime_hash: str
    protocol_version: int
    execution_profile_hash: str
    core: CanonicalCore
    canonicalized_at_block: int
    forced_queue: QueueContinuity
    mode: str = "PREACTIVE"
    nonproxy: bool = True
    selfdestruct_disabled: bool = True
    current_sequence: int = -1
    last_canonical_l1_block: int = 0
    history: dict[int, tuple[int, CanonicalTerminalCommitment]] = field(
        default_factory=dict)
    migration_gate: MigrationGate = field(default_factory=MigrationGate)
    live_protocol: Protocol | None = None
    inbox_apply_router: "InboxApplyRouterV2 | None" = None
    builder_registry_id: str = "builder-registry"
    schedule_oracle_id: str = "schedule-oracle"
    market_settlement_chain_id: int = 1
    market_runtime_hash: bytes = b"r" * 32
    market_configuration_hash: bytes = b"c" * 32
    market_magic: bytes = b"SEAT"
    header_oracle: L1HeaderOracle | None = field(default=None, compare=False)
    _router_authority: object | None = field(
        default=None, compare=False, repr=False
    )

    def __setattr__(self, name: str, value: object) -> None:
        immutable = {
            "address", "runtime_hash", "protocol_version",
            "execution_profile_hash", "forced_queue", "migration_gate",
            "inbox_apply_router", "builder_registry_id", "schedule_oracle_id",
            "market_settlement_chain_id", "market_runtime_hash",
            "market_configuration_hash", "market_magic", "header_oracle",
            "_router_authority",
        }
        if name in immutable and name in self.__dict__:
            raise AttributeError(f"Settlement {name} is immutable")
        object.__setattr__(self, name, value)

    def exact_market_target_state(self) -> tuple[object, ...]:
        """Derive the Market read word from this exact target-local graph."""

        phases = {
            "ACTIVE": "ACTIVE",
            "MIGRATION_ARMED": "ARMED",
            "MIGRATION_READY": "READY",
            "FROZEN": "FROZEN",
        }
        protocol = self.live_protocol
        router = self._router_authority
        registration = (
            None
            if type(router) is not ActiveSettlementRouter
            else router.registrations.get(self.protocol_version)
        )
        if (
            protocol is None
            or type(router) is not ActiveSettlementRouter
            or registration is None
            or registration.settlement is not self
            or (
                self.mode == "FROZEN"
                and router.active_version <= self.protocol_version
            )
            or (
                self.mode != "FROZEN"
                and router.active_version != self.protocol_version
            )
            or protocol.versioned_history is not self
            or protocol.settlement_address != self.address
            or self.header_oracle is not router.header_oracle
            or protocol.header_oracle is not router.header_oracle
            or self.forced_queue is not router.forced_queue
            or protocol.forced_queue is not router.forced_queue
            or self.inbox_apply_router is not router.inbox_apply_router
            or protocol.inbox_apply_router is not router.inbox_apply_router
            or self.migration_gate is not router.migration_gate
            or protocol.migration_gate is not self.migration_gate
            or self.mode not in phases
        ):
            raise ValueError("Settlement target/history graph is split")
        return (
            self.address,
            self.market_settlement_chain_id,
            self.protocol_version,
            self.market_runtime_hash,
            self.market_configuration_hash,
            self.market_magic,
            phases[self.mode],
            protocol.seat_generation,
        )

    def _entry(self, sequence: int, core: CanonicalCore,
               canonicalized_at_block: int) -> CanonicalTerminalCommitment:
        return CanonicalTerminalCommitment(
            self.protocol_version, self.execution_profile_hash, sequence,
            core.l2_block_number, core.tip_hash, core.state_root,
            core.terminal_root, core.terminal_count, canonicalized_at_block)

    def _install_imported_from_router(
        self,
        *,
        router: object,
        sequence: int,
        clock: Clock,
    ) -> bool:
        """Install one imported core only through the exact bound router."""

        if (type(router) is not ActiveSettlementRouter
                or type(clock) is not Clock
                or self.header_oracle is not router.header_oracle
                or self.migration_gate is not router.migration_gate
                or router.forced_queue is not self.forced_queue
                or router.inbox_apply_router is not self.inbox_apply_router
                or (
                    self._router_authority is not None
                    and self._router_authority is not router
                )
                or self.mode != "PREACTIVE" or self.history or sequence < 0
                or sequence >= UINT64_MAX
                or self.canonicalized_at_block <= 0
                or clock.block_number < self.canonicalized_at_block):
            return False
        entry = self._entry(sequence, self.core, self.canonicalized_at_block)
        self.history[sequence % CANONICAL_HISTORY_CAPACITY] = (sequence, entry)
        self.current_sequence = sequence
        self.last_canonical_l1_block = clock.block_number
        object.__setattr__(self, "_router_authority", router)
        return True

    def _record_canonical_from_protocol(
        self,
        *,
        protocol: object,
        clock: Clock,
    ) -> int | None:
        """Derive and append canonical state from the exact live Protocol."""

        router = self._router_authority
        registration = (
            None
            if type(router) is not ActiveSettlementRouter
            else router.registrations.get(self.protocol_version)
        )
        if (type(protocol) is not Protocol
                or type(clock) is not Clock
                or type(router) is not ActiveSettlementRouter
                or protocol is not self.live_protocol
                or protocol.header_oracle is not router.header_oracle
                or self.header_oracle is not router.header_oracle
                or self.migration_gate is not router.migration_gate
                or self.forced_queue is not router.forced_queue
                or self.inbox_apply_router is not router.inbox_apply_router
                or protocol.versioned_history is not self
                or protocol.forced_queue is not self.forced_queue
                or protocol.inbox_apply_router is not self.inbox_apply_router
                or protocol.migration_gate is not self.migration_gate
                or protocol.settlement_address != self.address
                or protocol.canonical.canonicalized_at_block
                    != clock.block_number
                or registration is None
                or registration.settlement is not self
                or router.active_version != self.protocol_version
                or self.mode not in {"ACTIVE", "MIGRATION_ARMED"}
                or self.inbox_apply_router is None
                or protocol.core.message_cursor != self.forced_queue.cursor
                or protocol.core.message_cursor
                    != self.inbox_apply_router.next_queue_index
                or clock.block_number <= self.last_canonical_l1_block
                or self.current_sequence < 0
                or self.current_sequence + 1 >= UINT64_MAX
                or protocol.core.l2_block_number <= self.core.l2_block_number
                or protocol.core.terminal_count < self.core.terminal_count
                or (protocol.core.terminal_count == self.core.terminal_count
                    and protocol.core.terminal_root != self.core.terminal_root)):
            return None
        sequence = self.current_sequence + 1
        core = copy.deepcopy(protocol.core)
        entry = self._entry(sequence, core, clock.block_number)
        self.history[sequence % CANONICAL_HISTORY_CAPACITY] = (sequence, entry)
        self.core = core
        self.canonicalized_at_block = clock.block_number
        self.current_sequence = sequence
        self.last_canonical_l1_block = clock.block_number
        return sequence

    def _arm_migration_for_test(self, *, caller_is_version_manager: bool,
                      delayed_manifest_active: bool,
                      generation: int = 1,
                      target_protocol_version: int = 2) -> bool:
        if (self.mode != "ACTIVE" or not caller_is_version_manager
                or not delayed_manifest_active
                or self.migration_gate.mode != "ARMED"
                or self.migration_gate.generation != generation
                or self.migration_gate.active_protocol_version
                    != self.protocol_version
                or self.migration_gate.target_protocol_version
                    != target_protocol_version):
            return False
        self.mode = "MIGRATION_ARMED"
        return True

    def enter_migration_ready(self) -> bool:
        if self.mode == "MIGRATION_READY" and self.migration_gate.mode == "READY":
            return True
        if (self.mode != "MIGRATION_ARMED"
                or self.migration_gate.mode != "READY"):
            return False
        self.mode = "MIGRATION_READY"
        return True

    def canonical_at(self, sequence: int) -> CanonicalTerminalCommitment | None:
        row = self.history.get(sequence % CANONICAL_HISTORY_CAPACITY)
        return row[1] if row is not None and row[0] == sequence else None


@dataclass(frozen=True)
class SettlementRegistration:
    settlement: VersionedSettlementHistory
    runtime_hash: str
    execution_profile_hash: str
    activation_block: int
    predecessor_version: int


@dataclass(frozen=True)
class MigrationActivationProof:
    base_core: CanonicalCore
    output_core: CanonicalCore
    target_protocol_version: int
    target_manifest_hash: str
    start_cursor: int
    end_cursor: int
    beneficiary: str
    release_activation: bool = True
    proof_valid: bool = True
    target_components_valid: bool = True


@dataclass(frozen=True)
class MigrationActivationReceipt:
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
    migration_stage_id: bytes | None
    migration_lineup_commitment: bytes | None

    @property
    def key(self) -> tuple[int, bytes]:
        return self.router_generation, self.target_manifest_hash


@dataclass
class ActiveSettlementRouter:
    """Append-only immutable registry and read-only history router."""

    version_manager: str
    forced_queue: QueueContinuity
    inbox_apply_router: "InboxApplyRouterV2"
    migration_gate: MigrationGate
    header_oracle: L1HeaderOracle
    address: str = "active-settlement-router"
    forced_queue_runtime_hash: str = "code:forced-queue:v2"
    forced_queue_config_hash: str = "config:forced-queue:depth64:v2"
    builder_registry_id: str = "builder-registry"
    schedule_oracle_id: str = "schedule-oracle"
    active_version: int = 0
    registrations: dict[int, SettlementRegistration] = field(default_factory=dict)
    activation_receipts: dict[
        tuple[int, bytes], MigrationActivationReceipt
    ] = field(default_factory=dict)
    activation_receipt_keys_by_generation: dict[
        int, tuple[int, bytes]
    ] = field(default_factory=dict)
    successor_receipt_key_by_old_authorization_id: dict[
        bytes, tuple[int, bytes]
    ] = field(default_factory=dict)
    used_target_addresses: set[str] = field(default_factory=set)
    authorized_ingress: frozenset[str] = field(
        default_factory=lambda: frozenset({
            "bridge-inbox-adapter", "kind0-adapter"
        })
    )

    def __post_init__(self) -> None:
        if (
            type(self.header_oracle) is not L1HeaderOracle
            or self.header_oracle.address != L1_HEADER_ORACLE_ADDRESS
            or self.header_oracle.runtime_hash
                != L1_HEADER_ORACLE_RUNTIME_HASH
            or self.header_oracle.configuration_hash
                != L1_HEADER_ORACLE_CONFIGURATION_HASH
        ):
            raise ValueError("active router header oracle is not exact")

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "version_manager", "forced_queue", "inbox_apply_router",
            "migration_gate", "header_oracle", "address",
            "forced_queue_runtime_hash", "forced_queue_config_hash",
            "builder_registry_id", "schedule_oracle_id", "authorized_ingress",
        } and name in self.__dict__:
            raise AttributeError(f"active-router {name} is immutable")
        object.__setattr__(self, name, value)

    @property
    def forced_queue_address(self) -> str:
        return self.forced_queue.address

    def bootstrap(self, settlement: VersionedSettlementHistory, *, sequence: int,
                  clock: Clock, caller: str) -> bool:
        if (type(clock) is not Clock or caller != self.version_manager
                or self.registrations or settlement.protocol_version <= 0
                or settlement.migration_gate is not self.migration_gate
                or settlement.header_oracle is not self.header_oracle
                or (
                    settlement.live_protocol is not None
                    and settlement.live_protocol.migration_gate
                        is not self.migration_gate
                )
                or (
                    settlement.live_protocol is not None
                    and settlement.live_protocol.header_oracle
                        is not self.header_oracle
                )
                or settlement.forced_queue is not self.forced_queue
                or self.forced_queue.router_address != self.address
                or self.forced_queue.runtime_hash
                    != self.forced_queue_runtime_hash
                or self.forced_queue.config_hash
                    != self.forced_queue_config_hash
                or not self.forced_queue.nonproxy
                or not self.forced_queue.selfdestruct_disabled
                or self.forced_queue.delegate_target_reachable
                or settlement.builder_registry_id != self.builder_registry_id
                or settlement.schedule_oracle_id != self.schedule_oracle_id
                or self.forced_queue.active_settlement_address
                    not in {"", settlement.address}
                or settlement.inbox_apply_router is not self.inbox_apply_router
                or settlement.core.message_cursor != self.forced_queue.cursor
                or settlement.core.message_cursor
                    != self.inbox_apply_router.next_queue_index
                or not settlement.nonproxy or not settlement.selfdestruct_disabled):
            return False
        authority_keys = {
            "migration_gate", "forced_queue", "inbox_apply_router", "live_protocol",
            "_router_authority",
        }
        settlement_snapshot = copy.deepcopy({
            key: value for key, value in settlement.__dict__.items()
            if key not in authority_keys
        })
        gate = settlement.migration_gate
        live_protocol = settlement.live_protocol
        prior_router_authority = settlement._router_authority
        gate_snapshot = copy.deepcopy(gate.__dict__)
        queue_snapshot = copy.deepcopy(self.forced_queue.__dict__)
        registrations_snapshot = dict(self.registrations)
        active_snapshot = self.active_version
        used_targets_snapshot = set(self.used_target_addresses)
        try:
            activation_block = clock.block_number
            if (
                not gate._bootstrap_from_router(
                    settlement.protocol_version, self.version_manager
                )
                or not settlement._install_imported_from_router(
                    router=self, sequence=sequence, clock=clock
                )
                or not self.forced_queue.set_active_settlement(
                    expected_old=self.forced_queue.active_settlement_address,
                    new=settlement.address,
                    caller=self.address,
                )
            ):
                raise ValueError("router bootstrap transition rejected")
            settlement.mode = "ACTIVE"
            self.registrations[settlement.protocol_version] = SettlementRegistration(
                settlement, settlement.runtime_hash,
                settlement.execution_profile_hash, activation_block, 0)
            self.active_version = settlement.protocol_version
            self.used_target_addresses.add(settlement.address)
            return True
        except BaseException:
            settlement.__dict__.clear()
            settlement.__dict__.update(settlement_snapshot)
            gate.__dict__.clear()
            gate.__dict__.update(gate_snapshot)
            self.forced_queue.__dict__.clear()
            self.forced_queue.__dict__.update(queue_snapshot)
            object.__setattr__(settlement, "migration_gate", gate)
            object.__setattr__(settlement, "forced_queue", self.forced_queue)
            object.__setattr__(
                settlement, "inbox_apply_router", self.inbox_apply_router
            )
            settlement.live_protocol = live_protocol
            object.__setattr__(
                settlement, "_router_authority", prior_router_authority
            )
            if live_protocol is not None:
                object.__setattr__(live_protocol, "migration_gate", gate)
                object.__setattr__(
                    live_protocol, "forced_queue", self.forced_queue
                )
                object.__setattr__(
                    live_protocol,
                    "inbox_apply_router",
                    self.inbox_apply_router,
                )
                live_protocol.versioned_history = settlement
            self.registrations = registrations_snapshot
            self.active_version = active_snapshot
            self.used_target_addresses = used_targets_snapshot
            return False

    def _activate_version_with_proof(
            self, *, settlement: VersionedSettlementHistory, clock: Clock,
            caller_is_version_manager: bool, manifest_active: bool,
            target_manifest_hash: str,
            activation_proof: MigrationActivationProof,
            target_runtime_approved: bool, target_profile_matches: bool,
            full_core_import_exact: bool, queue_import_exact: bool) -> bool:
        old_registration = self.registrations.get(self.active_version)
        if old_registration is None:
            return False
        old = old_registration.settlement
        target_protocol = settlement.live_protocol
        if (type(clock) is not Clock
                or not caller_is_version_manager or not manifest_active
                or not target_runtime_approved or not target_profile_matches
                or not full_core_import_exact or not queue_import_exact
                or not activation_proof.proof_valid
                or not activation_proof.target_components_valid
                or not activation_proof.release_activation
                or settlement.protocol_version <= self.active_version
                or settlement.protocol_version in self.registrations
                or settlement.address in self.used_target_addresses
                or not settlement.execution_profile_hash
                or not settlement.runtime_hash
                or not settlement.nonproxy or not settlement.selfdestruct_disabled
                or settlement.mode != "PREACTIVE" or settlement.history
                or settlement.current_sequence != -1
                or settlement.last_canonical_l1_block != 0
                or settlement._router_authority is not None
                or target_protocol is None
                or target_protocol is old.live_protocol
                or old.live_protocol is None
                or target_protocol.versioned_history is not settlement
                or target_protocol.header_oracle is not self.header_oracle
                or settlement.header_oracle is not self.header_oracle
                or old.header_oracle is not self.header_oracle
                or old.live_protocol is None
                or old.live_protocol.header_oracle is not self.header_oracle
                or target_protocol.mode is not Mode.PREACTIVE
                or target_protocol.settlement_address != settlement.address
                or target_protocol.canonical.core != settlement.core
                or target_protocol.canonical.canonicalized_at_block
                    != settlement.canonicalized_at_block
                or target_protocol.release_activation_pending
                or target_protocol.pending_release_protocol_version != 0
                or target_protocol.pending_release_manifest_hash != ""
                or target_protocol.first_v2_block_number != 0
                or target_protocol.episode != 0
                or target_protocol.recovery is not None
                or target_protocol.normal_best is not None
                or target_protocol.normal_best_min_data_expiry != UINT64_MAX
                or target_protocol.normal_deadline is not None
                or target_protocol.normal_required_through is not None
                or target_protocol.normal_min_admissible is not None
                or target_protocol.normal_admission_version is not None
                or target_protocol.normal_admission_root is not None
                or target_protocol.normal_anchor_number is not None
                or target_protocol.normal_anchor_hash is not None
                or target_protocol.normal_context_id is not None
                or target_protocol.normal_arm_block_number is not None
                or target_protocol.admission_version
                != old.live_protocol.admission_version
                or target_protocol.admission_root
                != old.live_protocol.admission_root
                or target_protocol.queue_capacity
                != old.live_protocol.queue_capacity
                or target_protocol.canonical is old.live_protocol.canonical
                or target_protocol.forced_queue is not self.forced_queue
                or target_protocol.inbox_apply_router is not self.inbox_apply_router
                or target_protocol.migration_gate is not settlement.migration_gate
                or target_protocol.seat_terms
                or target_protocol.seat_services
                or target_protocol.seat_lineup
                or target_protocol.seat_duties
                or target_protocol.term_duty
                or target_protocol.seat_selections
                or target_protocol.term_selection
                or target_protocol.seat_selection is not None
                or target_protocol.settlement_seat_stage is not None
                or target_protocol.stage_tombstones
                or target_protocol.outstanding_stage_tombstone_id is not None
                or target_protocol.seat_generation != 0
                or target_protocol.seat_lineup_revision != 0
                or target_protocol.duty_sequence != 0
                or target_protocol.seat_sla_trigger_pending
                or target_protocol.seat_migration_arm is not None
                or target_protocol.seat_migration_abort is not None
                or target_protocol.seat_migration_local_generation is not None
                or target_protocol.seat_scan_count != 0
                or target_protocol.seat_scan_visits_total != 0
                or target_protocol.events
                or target_protocol.gc_cursor != 0
                or target_protocol.boundary_queries != 0
                or target_protocol.seat_fault_point is not None
                or not target_protocol.canonical_state_witness_available
                or not target_protocol.canonical_code_preimages_available
                or target_protocol.sessions
                or target_protocol.seat_terms is old.live_protocol.seat_terms
                or target_protocol.seat_services is old.live_protocol.seat_services
                or target_protocol.seat_lineup is old.live_protocol.seat_lineup
                or target_protocol.seat_duties is old.live_protocol.seat_duties
                or target_protocol.term_duty is old.live_protocol.term_duty
                or target_protocol.duty_ring is old.live_protocol.duty_ring
                or target_protocol.seat_selections
                    is old.live_protocol.seat_selections
                or target_protocol.term_selection
                    is old.live_protocol.term_selection
                or target_protocol.stage_tombstones
                    is old.live_protocol.stage_tombstones
                or target_protocol.sessions is old.live_protocol.sessions
                or target_protocol.events is old.live_protocol.events
                or len(target_protocol.duty_ring) != DUTY_RING_CAPACITY
                or any(
                    cell != SeatDutyCell()
                    for cell in target_protocol.duty_ring
                )
                or old.mode != "MIGRATION_READY"
                or old.migration_gate.mode != "READY"
                or old.migration_gate.active_protocol_version
                    != self.active_version
                or old.migration_gate is not self.migration_gate
                or settlement.migration_gate is not self.migration_gate
                or target_protocol.migration_gate is not self.migration_gate
                or old.migration_gate.target_protocol_version
                    != settlement.protocol_version
                or old.migration_gate.target_manifest_hash
                    != target_manifest_hash
                or activation_proof.target_protocol_version
                    != settlement.protocol_version
                or activation_proof.target_manifest_hash
                    != target_manifest_hash
                or activation_proof.base_core != old.core
                or settlement.core != old.core
                or settlement.canonicalized_at_block
                    != old.canonicalized_at_block
                or settlement.forced_queue is not self.forced_queue
                or old.forced_queue is not self.forced_queue
                or self.forced_queue.active_settlement_address != old.address
                or self.forced_queue.runtime_hash
                    != self.forced_queue_runtime_hash
                or self.forced_queue.config_hash
                    != self.forced_queue_config_hash
                or not self.forced_queue.nonproxy
                or not self.forced_queue.selfdestruct_disabled
                or self.forced_queue.delegate_target_reachable
                or settlement.builder_registry_id != self.builder_registry_id
                or old.builder_registry_id != self.builder_registry_id
                or settlement.schedule_oracle_id != self.schedule_oracle_id
                or old.schedule_oracle_id != self.schedule_oracle_id
                or settlement.inbox_apply_router is not self.inbox_apply_router
                or old.inbox_apply_router is not self.inbox_apply_router
                or old.live_protocol is None
                or old.live_protocol.versioned_history is not old
                or old.live_protocol.forced_queue is not self.forced_queue
                or old.live_protocol.inbox_apply_router
                    is not self.inbox_apply_router
                or old.live_protocol.canonical.core != old.core
                or old.core.message_cursor != self.forced_queue.cursor
                or old.live_protocol.release_activation_pending
                or old.live_protocol.first_v2_block_number <= 0
                or activation_proof.start_cursor != old.core.message_cursor
                or not activation_proof.start_cursor
                    <= activation_proof.end_cursor <= self.forced_queue.count
                or not activation_proof.beneficiary
                or activation_proof.output_core.message_cursor
                    != activation_proof.end_cursor
                or activation_proof.output_core.l2_block_number
                    <= old.core.l2_block_number
                or activation_proof.output_core.tip_slot <= old.core.tip_slot
                or activation_proof.output_core.terminal_count
                    < old.core.terminal_count
                or (activation_proof.output_core.terminal_count
                    == old.core.terminal_count
                    and activation_proof.output_core.terminal_root
                        != old.core.terminal_root)
                or self.forced_queue.escrow_balance
                    < self.forced_queue.accounted_liabilities
                or old.current_sequence + 1 >= UINT64_MAX
                or clock.block_number <= old.last_canonical_l1_block):
            return False
        l1_block = clock.block_number
        old_version = self.active_version
        if not self.forced_queue.set_active_settlement(
                expected_old=old.address, new=settlement.address,
                caller=self.address):
            raise AssertionError("validated queue authority switch failed")
        if not self.forced_queue.advance_cursor(
                activation_proof.start_cursor, activation_proof.end_cursor,
                caller=settlement.address,
                beneficiary=activation_proof.beneficiary):
            raise AssertionError("validated activation queue advance failed")
        self.inbox_apply_router.next_queue_index = activation_proof.end_cursor
        settlement.core = copy.deepcopy(activation_proof.output_core)
        settlement.canonicalized_at_block = l1_block
        if not settlement._install_imported_from_router(
                router=self, sequence=old.current_sequence + 1, clock=clock):
            raise AssertionError("validated target history write failed")
        old.mode = "FROZEN"
        settlement.mode = "ACTIVE"
        self.registrations[settlement.protocol_version] = SettlementRegistration(
            settlement, settlement.runtime_hash,
            settlement.execution_profile_hash, l1_block, old_version)
        self.active_version = settlement.protocol_version
        self.used_target_addresses.add(settlement.address)
        successor = target_protocol
        active_gate = old.migration_gate
        successor.canonical = Canonical(
            copy.deepcopy(activation_proof.output_core), l1_block)
        successor.mode = Mode.NORMAL
        successor.seat_generation = old.live_protocol.seat_generation
        successor.first_v2_block_number = old.live_protocol.first_v2_block_number
        successor.release_activation_pending = False
        successor.pending_release_protocol_version = 0
        successor.pending_release_manifest_hash = ""
        activated = active_gate._activate_from_router(
            active_gate.generation, old_version,
            settlement.protocol_version)
        assert activated
        return True

    def _abort_migration_for_test(self, *, generation: int,
                        target_protocol_version: int,
                        target_manifest_hash: str,
                        cancel_manifest_active: bool,
                        clock: Clock) -> bool:
        """Permissionless execution after an exact delayed cancel manifest."""
        registration = self.registrations.get(self.active_version)
        if registration is None:
            return False
        old = registration.settlement
        if (old.mode not in {"MIGRATION_ARMED", "MIGRATION_READY"}
                or self.forced_queue.active_settlement_address != old.address
                or old.live_protocol is None
                or not old.migration_gate._abort_from_manager(
                    generation, self.active_version, target_protocol_version,
                    target_manifest_hash,
                    cancel_manifest_active=cancel_manifest_active,
                    caller=self.version_manager)):
            return False
        old.mode = "ACTIVE"
        old.live_protocol.sync(clock)
        return True

    def canonical_at(self, protocol_version: int,
                     sequence: int) -> CanonicalTerminalCommitment | None:
        registration = self.registrations.get(protocol_version)
        if registration is None:
            return None
        settlement = registration.settlement
        if (settlement.runtime_hash != registration.runtime_hash
                or settlement.execution_profile_hash
                    != registration.execution_profile_hash
                or not settlement.nonproxy or not settlement.selfdestruct_disabled
                or settlement.mode not in {
                    "ACTIVE", "MIGRATION_ARMED", "MIGRATION_READY", "FROZEN"}):
            return None
        entry = settlement.canonical_at(sequence)
        if (entry is None or entry.protocol_version != protocol_version
                or entry.execution_profile_hash
                    != registration.execution_profile_hash):
            return None
        return entry

    def sync_and_append(self, descriptor: Message, *, clock: Clock,
                        bound_router: str, queue_address: str,
                        deposit: int,
                        caller_adapter: str = "bridge-inbox-adapter") -> str:
        registration = self.registrations.get(self.active_version)
        if (bound_router != self.address
                or caller_adapter not in self.authorized_ingress
                or queue_address != self.forced_queue_address
                or registration is None
                or registration.settlement.live_protocol is None
                or registration.settlement.mode
                    not in {"ACTIVE", "MIGRATION_ARMED", "MIGRATION_READY"}):
            return "REJECTED"
        settlement = registration.settlement
        live_protocol = settlement.live_protocol
        if (settlement._router_authority is not self
                or settlement.header_oracle is not self.header_oracle
                or settlement.migration_gate is not self.migration_gate
                or settlement.forced_queue is not self.forced_queue
                or settlement.inbox_apply_router is not self.inbox_apply_router
                or live_protocol.versioned_history is not settlement
                or live_protocol.settlement_address != settlement.address
                or live_protocol.header_oracle is not self.header_oracle
                or live_protocol.migration_gate is not self.migration_gate
                or live_protocol.forced_queue is not self.forced_queue
                or live_protocol.inbox_apply_router is not self.inbox_apply_router):
            return "REJECTED"
        if settlement.mode != "ACTIVE":
            return "SYNCED"
        before = self.forced_queue.count
        result = live_protocol.admit_bridge_direct(
            clock, replace(descriptor, prepaid=deposit))
        if result == "ADMITTED":
            assert self.forced_queue.count == before + 1
            return f"QUEUED:{before}"
        return result


@dataclass
class ProtocolVersionManager:
    """Exact global migration coordinator bound to one immutable router."""

    address: str
    router: ActiveSettlementRouter
    release_manager: object | None = field(default=None, compare=False)
    market_chain_id: int = 0
    market_address: str = ""
    governance: str = "seat-governance"
    manifest_delay_seconds: int = SEAT_MIGRATION_MANIFEST_DELAY
    cancel_delay_seconds: int = SEAT_MIGRATION_CANCEL_DELAY
    arm_manifests: dict[
        tuple[int, int, int, bytes], ScheduledSeatMigration
    ] = field(default_factory=dict)
    cancel_manifests: dict[
        tuple[int, int, int, bytes], ScheduledSeatMigration
    ] = field(default_factory=dict)
    arm_responses: dict[int, bytes] = field(default_factory=dict)
    abort_responses: dict[int, bytes] = field(default_factory=dict)
    fault_point: str | None = None

    def __post_init__(self) -> None:
        bound = self.release_manager is not None
        if (
            type(self.router) is not ActiveSettlementRouter
            or self.router.version_manager != self.address
            or self.router.migration_gate.coordinator != self.address
            or bound != (self.market_chain_id > 0 and bool(self.market_address))
            or not self.governance
            or self.manifest_delay_seconds != SEAT_MIGRATION_MANIFEST_DELAY
            or self.cancel_delay_seconds != SEAT_MIGRATION_CANCEL_DELAY
            or (
                bound
                and getattr(self.release_manager, "activation_authority", None)
                is not self.router
            )
        ):
            raise ValueError("manager Market binding must be all-or-none")

    def __setattr__(self, name: str, value: object) -> None:
        if name in {
            "address", "router", "release_manager",
            "market_chain_id", "market_address", "governance",
            "manifest_delay_seconds", "cancel_delay_seconds",
        } and name in self.__dict__:
            raise AttributeError(f"{name} is immutable after deployment")
        object.__setattr__(self, name, value)

    def activate_seat_migration(
        self,
        *,
        manifest_key: tuple[int, int, int, bytes],
        activation_proof: MigrationActivationProof,
        executor: str,
        clock: Clock,
    ) -> MigrationActivationReceipt:
        """Consume the exact arm and activate a distinct target-local ledger."""

        old_history, old_protocol, gate = self._active_target()
        if type(clock) is not Clock:
            raise ValueError("activation requires the exact environment clock")
        l1_block = clock.block_number
        release_manager = self.release_manager
        market_chain_id = self.market_chain_id
        market_address = self.market_address
        manifest = self.arm_manifests.get(manifest_key)
        old_auth_id = manifest.old_authorization_id if manifest is not None else b""
        new_auth_id = manifest.new_authorization_id if manifest is not None else b""
        authorizations = getattr(release_manager, "authorizations", {})
        runtimes = getattr(release_manager, "target_runtimes", {})
        old_auth = authorizations.get(old_auth_id)
        new_auth = authorizations.get(new_auth_id)
        old_runtime = runtimes.get(old_auth_id)
        new_runtime = runtimes.get(new_auth_id)
        settlement = None if new_runtime is None else new_runtime.authority
        target_bindings = getattr(release_manager, "target_bindings", {})
        if (
            manifest is None
            or type(settlement) is not VersionedSettlementHistory
            or release_manager is None
            or not executor
            or manifest.generation not in self.arm_responses
            or gate.mode != "READY"
            or old_history.mode != "MIGRATION_READY"
            or manifest.generation != gate.generation
            or manifest.active_protocol_version != self.router.active_version
            or manifest.target_protocol_version != settlement.protocol_version
            or manifest.target_manifest_hash != activation_proof.target_manifest_hash
            or len(old_auth_id) != 32
            or len(new_auth_id) != 32
            or getattr(release_manager, "activation_authority", None)
            is not self.router
            or old_auth is None
            or new_auth is None
            or release_manager.exact_authorization_id(
                market_chain_id, market_address, old_auth
            ) != old_auth_id
            or release_manager.exact_authorization_id(
                market_chain_id, market_address, new_auth
            ) != new_auth_id
            or old_runtime is None
            or new_runtime is None
            or old_runtime.authority is not old_history
            or new_runtime.authority is not settlement
            or target_bindings.get(old_auth_id)
            != (market_chain_id, market_address)
            or target_bindings.get(new_auth_id)
            != (market_chain_id, market_address)
            or old_auth.target != old_history.address
            or new_auth.target != settlement.address
            or old_auth.settlement_chain_id
            != old_history.market_settlement_chain_id
            or new_auth.settlement_chain_id
            != settlement.market_settlement_chain_id
            or old_auth.protocol_version != old_history.protocol_version
            or new_auth.protocol_version != settlement.protocol_version
            or old_auth.runtime_hash != old_history.market_runtime_hash
            or new_auth.runtime_hash != settlement.market_runtime_hash
            or old_auth.configuration_hash
            != old_history.market_configuration_hash
            or new_auth.configuration_hash
            != settlement.market_configuration_hash
            or old_auth.expected_magic != old_history.market_magic
            or new_auth.expected_magic != settlement.market_magic
            or old_protocol.seat_market_address != market_address
            or old_protocol.seat_authorization_id != old_auth_id
            or settlement.live_protocol.seat_authorization_id != new_auth_id
            or settlement.live_protocol.seat_market_address != market_address
            or settlement.live_protocol.seat_runway_seconds
            != old_protocol.seat_runway_seconds
            or settlement.live_protocol.minimum_primary_tenure_seconds
            != old_protocol.minimum_primary_tenure_seconds
            or settlement.live_protocol.minimum_standby_tenure_seconds
            != old_protocol.minimum_standby_tenure_seconds
            or settlement.live_protocol.exit_delay_seconds
            != old_protocol.exit_delay_seconds
            or not settlement.live_protocol.seat_profile_ready
            or not settlement.live_protocol.seat_configuration_ready
        ):
            raise ValueError("seat migration activation authority is invalid")
        receipt_key = (manifest.generation, manifest.target_manifest_hash)
        if (
            receipt_key in self.router.activation_receipts
            or old_auth_id
            in self.router.successor_receipt_key_by_old_authorization_id
            or release_manager.activation_receipt(receipt_key) is not None
        ):
            raise ValueError("seat migration activation receipt was consumed")

        old_protocol._assert_canonical_history_binding()
        old_snapshot = old_protocol._canonical_transaction_snapshot()
        target_authority_refs = (
            settlement.forced_queue,
            settlement.inbox_apply_router,
            settlement.migration_gate,
            settlement.live_protocol,
            settlement._router_authority,
        )
        target_snapshot = copy.deepcopy({
            key: value for key, value in settlement.__dict__.items()
            if key not in {
                "forced_queue", "inbox_apply_router", "migration_gate", "live_protocol",
                "_router_authority",
            }
        })
        router_snapshot = (
            self.router.active_version,
            dict(self.router.registrations),
            dict(self.router.activation_receipts),
            dict(self.router.activation_receipt_keys_by_generation),
            dict(self.router.successor_receipt_key_by_old_authorization_id),
            set(self.router.used_target_addresses),
        )
        target_protocol_refs = (
            settlement.live_protocol.forced_queue,
            settlement.live_protocol.inbox_apply_router,
            settlement.live_protocol.migration_gate,
            settlement.live_protocol.versioned_history,
        )
        target_protocol_snapshot = copy.deepcopy({
            key: value for key, value in settlement.live_protocol.__dict__.items()
            if key not in {
                "forced_queue", "inbox_apply_router", "migration_gate",
                "versioned_history"
            }
        })
        try:
            activated = self.router._activate_version_with_proof(
                settlement=settlement,
                clock=clock,
                caller_is_version_manager=True,
                manifest_active=True,
                target_manifest_hash=manifest.target_manifest_hash,
                activation_proof=activation_proof,
                target_runtime_approved=True,
                target_profile_matches=True,
                full_core_import_exact=True,
                queue_import_exact=True,
            )
            if not activated:
                raise ValueError("seat migration activation proof was rejected")
            if self.fault_point == "after_target_import":
                raise RuntimeError("injected activation fault: after_target_import")
            successor = settlement.live_protocol
            if (
                successor is None
                or successor is old_protocol
                or successor.seat_lineup
                or successor.seat_duties
                or any(not cell.reusable for cell in successor.duty_ring)
                or successor.seat_generation != old_protocol.seat_generation
            ):
                raise AssertionError("activated target did not start as a fresh ledger")
            if (
                successor.seat_authorization_id != new_auth_id
                or successor.seat_market_address != market_address
            ):
                raise AssertionError("activated target authority binding changed")
            arm = old_protocol.seat_migration_arm
            if arm is None or arm.router_word.generation != manifest.generation:
                raise AssertionError("activation lost exact local arm")
            receipt = MigrationActivationReceipt(
                manifest.generation,
                manifest.active_protocol_version,
                manifest.target_protocol_version,
                old_history.address,
                settlement.address,
                manifest.target_manifest_hash,
                arm.seat_generation,
                old_auth_id,
                new_auth_id,
                l1_block,
                arm.migration_stage_id,
                arm.migration_lineup_commitment,
            )
            self.router.activation_receipts[receipt.key] = receipt
            self.router.activation_receipt_keys_by_generation[
                receipt.router_generation
            ] = receipt.key
            self.router.successor_receipt_key_by_old_authorization_id[
                receipt.old_authorization_id
            ] = receipt.key
            if self.fault_point == "after_activation_receipt_write":
                raise RuntimeError(
                    "injected activation fault: after_activation_receipt_write"
                )
            return receipt
        except BaseException:
            old_protocol._restore_canonical_transaction(old_snapshot)
            settlement.__dict__.clear()
            settlement.__dict__.update(target_snapshot)
            (
                settlement.forced_queue,
                settlement.inbox_apply_router,
                settlement.migration_gate,
                settlement.live_protocol,
                settlement._router_authority,
            ) = target_authority_refs
            (
                self.router.active_version,
                self.router.registrations,
                self.router.activation_receipts,
                self.router.activation_receipt_keys_by_generation,
                self.router.successor_receipt_key_by_old_authorization_id,
                self.router.used_target_addresses,
            ) = router_snapshot
            target_protocol = target_authority_refs[3]
            if target_protocol is not None:
                target_protocol.__dict__.clear()
                target_protocol.__dict__.update(target_protocol_snapshot)
                (
                    target_protocol.forced_queue,
                    target_protocol.inbox_apply_router,
                    target_protocol.migration_gate,
                    target_protocol.versioned_history,
                ) = target_protocol_refs
            raise

    def schedule_seat_migration(
        self,
        manifest: ScheduledSeatMigration,
        *,
        caller: str,
        clock: Clock,
        cancel: bool = False,
    ) -> tuple[int, int, int, bytes]:
        if (
            caller != self.governance
            or type(manifest) is not ScheduledSeatMigration
            or type(clock) is not Clock
            or manifest.scheduled_at != clock.timestamp
            or type(manifest.target_manifest_hash) is not bytes
            or len(manifest.target_manifest_hash) != 32
            or manifest.generation <= 0
            or manifest.active_protocol_version <= 0
            or manifest.target_protocol_version
            <= manifest.active_protocol_version
            or manifest.executable_at < 0
            or (
                (manifest.old_authorization_id, manifest.new_authorization_id)
                != (b"", b"")
                and (
                    type(manifest.old_authorization_id) is not bytes
                    or len(manifest.old_authorization_id) != 32
                    or type(manifest.new_authorization_id) is not bytes
                    or len(manifest.new_authorization_id) != 32
                )
            )
            or type(cancel) is not bool
        ):
            raise ValueError("scheduled seat migration manifest is invalid")
        delay = (
            self.cancel_delay_seconds if cancel else self.manifest_delay_seconds
        )
        if manifest.executable_at < seat_checked_add(
            clock.timestamp, delay, "seat migration schedule delay"
        ):
            raise ValueError("seat migration manifest delay is too short")
        records = self.cancel_manifests if cancel else self.arm_manifests
        if manifest.key in records:
            raise ValueError("scheduled seat migration manifest is append-only")
        records[manifest.key] = manifest
        return manifest.key

    def _active_target(
        self,
    ) -> tuple[VersionedSettlementHistory, Protocol, MigrationGate]:
        if (
            type(self.router) is not ActiveSettlementRouter
            or self.router.version_manager != self.address
        ):
            raise ValueError("version manager is not bound to the active router")
        registration = self.router.registrations.get(self.router.active_version)
        if registration is None:
            raise ValueError("active Settlement registration is absent")
        history = registration.settlement
        protocol = history.live_protocol
        if (
            protocol is None
            or protocol.versioned_history is not history
            or protocol.header_oracle is not self.router.header_oracle
            or history.header_oracle is not self.router.header_oracle
            or protocol.migration_gate is not self.router.migration_gate
            or history.migration_gate is not self.router.migration_gate
            or self.router.migration_gate.coordinator != self.address
            or protocol.forced_queue is not self.router.forced_queue
            or history.forced_queue is not self.router.forced_queue
            or protocol.inbox_apply_router is not self.router.inbox_apply_router
            or history.inbox_apply_router is not self.router.inbox_apply_router
            or protocol.settlement_address != history.address
            or history.protocol_version != self.router.active_version
        ):
            raise ValueError("active router/Settlement graph is split")
        return history, protocol, self.router.migration_gate

    @staticmethod
    def _response_matches(
        response: SeatMigrationResponse,
        magic: bytes,
        word: RouterWord,
        seat_generation: int,
    ) -> bool:
        return (
            response.magic == magic
            and response.router_generation == word.generation
            and response.active_protocol_version == word.active_version
            and response.target_protocol_version == word.target_version
            and response.target_manifest_hash == word.target_manifest_hash
            and response.seat_generation == seat_generation
        )

    def arm_seat_migration(
        self,
        *,
        manifest_key: tuple[int, int, int, bytes],
        executor: str,
        clock: Clock,
    ) -> bytes:
        history, protocol, gate = self._active_target()
        manifest = self.arm_manifests.get(manifest_key)
        if (
            manifest is None
            or not executor
            or clock.timestamp < manifest.executable_at
            or manifest.generation in self.arm_responses
            or gate.mode != "ACTIVE"
            or manifest.generation != gate.generation + 1
            or manifest.active_protocol_version != self.router.active_version
            or manifest.active_protocol_version != gate.active_protocol_version
            or history.mode != "ACTIVE"
        ):
            raise ValueError("global seat migration arm is invalid")
        protocol._assert_canonical_history_binding()
        protocol_snapshot = protocol._canonical_transaction_snapshot()
        manager_snapshot = copy.deepcopy(
            (self.arm_responses, self.abort_responses)
        )
        try:
            if not gate._arm_from_manager(
                manifest.generation,
                manifest.active_protocol_version,
                manifest.target_protocol_version,
                manifest.target_manifest_hash,
                caller=self.address,
            ):
                raise AssertionError("validated router arm failed")
            history.mode = "MIGRATION_ARMED"
            word = gate.router_word
            raw = protocol.complete_seat_migration_arm(
                caller=self.address, router_word=word, clock=clock
            )
            decoded = decode_seat_migration_response(raw)
            if not self._response_matches(
                decoded, SEAT_ARMED_MAGIC, word, protocol.seat_generation
            ):
                raise ValueError("local arm response does not bind global tuple")
            self.arm_responses[manifest.generation] = raw
            return raw
        except BaseException:
            protocol._restore_canonical_transaction(protocol_snapshot)
            self.arm_responses, self.abort_responses = manager_snapshot
            raise

    def abort_seat_migration(
        self,
        *,
        manifest_key: tuple[int, int, int, bytes],
        executor: str,
        clock: Clock,
    ) -> bytes:
        history, protocol, gate = self._active_target()
        manifest = self.cancel_manifests.get(manifest_key)
        if (
            manifest is None
            or not executor
            or clock.timestamp < manifest.executable_at
            or manifest.generation not in self.arm_responses
            or manifest.generation in self.abort_responses
            or gate.mode not in {"ARMED", "READY"}
            or manifest.generation != gate.generation
            or manifest.active_protocol_version != self.router.active_version
            or manifest.active_protocol_version != gate.active_protocol_version
            or manifest.target_protocol_version != gate.target_protocol_version
            or manifest.target_manifest_hash != gate.target_manifest_hash
            or history.mode not in {"MIGRATION_ARMED", "MIGRATION_READY"}
        ):
            raise ValueError("global seat migration abort is invalid")
        protocol._assert_canonical_history_binding()
        protocol_snapshot = protocol._canonical_transaction_snapshot()
        manager_snapshot = copy.deepcopy(
            (self.arm_responses, self.abort_responses)
        )
        try:
            canceled_word = gate.router_word
            if not gate._abort_from_manager(
                manifest.generation,
                manifest.active_protocol_version,
                manifest.target_protocol_version,
                manifest.target_manifest_hash,
                cancel_manifest_active=True,
                caller=self.address,
            ):
                raise AssertionError("validated router abort failed")
            history.mode = "ACTIVE"
            raw = protocol.complete_seat_migration_abort(
                caller=self.address,
                canceled_arm=canceled_word,
                clock=clock,
            )
            decoded = decode_seat_migration_response(raw)
            if not self._response_matches(
                decoded,
                SEAT_ABORTED_MAGIC,
                canceled_word,
                protocol.seat_generation,
            ):
                raise ValueError("local abort response does not bind canceled tuple")
            self.abort_responses[manifest.generation] = raw
            return raw
        except BaseException:
            protocol._restore_canonical_transaction(protocol_snapshot)
            self.arm_responses, self.abort_responses = manager_snapshot
            raise


@dataclass(frozen=True)
class TerminalProof:
    protocol_version: int
    canonical_sequence: int
    canonical: CanonicalTerminalCommitment
    leaf_index: int
    destination_bridge: str
    destination_domain_id: str
    credit_id: str
    terminal: str
    leaf_hash: str
    proof_root: str
    merkle_proof_valid: bool = True


@dataclass(frozen=True)
class TerminalSignalVerifier:
    router: ActiveSettlementRouter

    @staticmethod
    def terminal_leaf(index: int, destination_domain_id: str,
                      destination_bridge: str, credit_id: str,
                      terminal: str) -> str:
        return (f"terminal-leaf:{index}:{destination_domain_id}:"
                f"{destination_bridge}:{credit_id}:{terminal}")

    def verify(self, *, proof: TerminalProof, credit_id: str,
               terminal: str, destination_domain_id: str,
               destination_bridge: str) -> bool:
        expected_leaf = self.terminal_leaf(
            proof.leaf_index, destination_domain_id,
            destination_bridge, credit_id, terminal)
        return (terminal in {"DONE", "FAILED"}
                and proof.merkle_proof_valid
                and self.router.canonical_at(
                    proof.protocol_version, proof.canonical_sequence)
                    == proof.canonical
                and proof.canonical.protocol_version == proof.protocol_version
                and proof.canonical.canonical_sequence
                    == proof.canonical_sequence
                and proof.proof_root == proof.canonical.terminal_root
                and 0 <= proof.leaf_index < proof.canonical.terminal_count
                and proof.destination_bridge == destination_bridge
                and proof.destination_domain_id == destination_domain_id
                and proof.credit_id == credit_id
                and proof.terminal == terminal
                and proof.leaf_hash == expected_leaf)


def source_send_mode(selector: str) -> str:
    if selector == "sendMessage(Message)":
        return "V1"
    if selector == "sendMessageV2(Message)":
        return "V2_DIRECT"
    if selector == "sendMessageFromVaultV2(Message)":
        return "V2_CAPSULE"
    return "REJECTED"


@dataclass
class CreditAuthorization:
    enqueue_by: int
    owner: str
    value: int
    fee: int
    refund_mode: str = "DIRECT"
    refund_vault: str = ""
    destination_domain_id: str = "domain:D1"


@dataclass
class SourceCredit:
    value: int
    fee: int
    refund_capsule_hash: str = ""
    status: str = "NEW"
    queue_index: int | None = None


@dataclass
class SourceBridgeLedger:
    authorizations: dict[str, CreditAuthorization] = field(default_factory=dict)
    credits: dict[str, SourceCredit] = field(default_factory=dict)
    refunds: dict[str, int] = field(default_factory=dict)
    balance: int = 0
    total_live_liability: int = 0
    ether_quota: int = UINT64_MAX
    paused: bool = False
    destination_bridges: dict[str, str] = field(default_factory=lambda: {
        "domain:D1": "bridge:A", "domain:D2": "bridge:B"})

    def open(self, credit_id: str, *, now: int, enqueue_by: int,
             owner: str, value: int, fee: int, refund_vault: str = "",
             refund_capsule_hash: str = "", refund_mode: str = "DIRECT",
             caller: str = "", destination_domain_id: str = "domain:D1") -> bool:
        if (not credit_id or credit_id in self.authorizations or not owner
                or enqueue_by != now + MAX_BRIDGE_ENQUEUE_DELAY
                or value < 0 or fee < 0 or refund_capsule_hash
                or refund_mode not in {"DIRECT", "CAPSULE"}
                or (refund_mode == "DIRECT" and refund_vault)
                or (refund_mode == "CAPSULE"
                    and (not caller or refund_vault != caller))):
            return False
        self.authorizations[credit_id] = CreditAuthorization(
            enqueue_by, owner, value, fee, refund_mode, refund_vault,
            destination_domain_id)
        self.credits[credit_id] = SourceCredit(
            value, fee, "", "DRAFT" if refund_mode == "CAPSULE" else "NEW")
        self.balance += value + fee
        self.total_live_liability += value + fee
        return True

    def finalize_capsule(self, credit_id: str, *, caller: str,
                         capsule_hash: str,
                         vault_has_matching_capsule: bool) -> bool:
        authorization = self.authorizations.get(credit_id)
        credit = self.credits.get(credit_id)
        if (authorization is None or credit is None or credit.status != "DRAFT"
                or caller != authorization.refund_vault or not capsule_hash
                or not vault_has_matching_capsule):
            return False
        credit.refund_capsule_hash = capsule_hash
        credit.status = "NEW"
        return True

    def mark_queued(self, credit_id: str, queue_index: int,
                    *, caller_is_bound_adapter: bool) -> bool:
        credit = self.credits.get(credit_id)
        if (credit is None or credit.status != "NEW"
                or not caller_is_bound_adapter or queue_index < 0):
            return False
        credit.status = "QUEUED"
        credit.queue_index = queue_index
        self.total_live_liability -= credit.fee
        return True

    def cancel(self, credit_id: str, *, now: int) -> bool:
        credit = self.credits.get(credit_id)
        authorization = self.authorizations.get(credit_id)
        if (credit is None or credit.status not in {"DRAFT", "NEW"}
                or authorization is None or now <= authorization.enqueue_by):
            return False
        credit.status = "CANCELLED"
        self.refunds[authorization.owner] = (
            self.refunds.get(authorization.owner, 0) + credit.value + credit.fee)
        return True

    def finalize_done(self, credit_id: str, *, verifier: TerminalSignalVerifier,
                      proof: TerminalProof) -> bool:
        credit = self.credits.get(credit_id)
        authorization = self.authorizations.get(credit_id)
        destination_bridge = (None if authorization is None else
                              self.destination_bridges.get(
                                  authorization.destination_domain_id))
        if (credit is None or credit.status != "QUEUED"
                or authorization is None or destination_bridge is None
                or not verifier.verify(
                    proof=proof, credit_id=credit_id, terminal="DONE",
                    destination_domain_id=authorization.destination_domain_id,
                    destination_bridge=destination_bridge)):
            return False
        credit.status = "DELIVERED"
        self.total_live_liability -= credit.value
        return True

    def recall_failed(self, credit_id: str, *, verifier: TerminalSignalVerifier,
                      proof: TerminalProof) -> bool:
        credit = self.credits.get(credit_id)
        authorization = self.authorizations.get(credit_id)
        destination_bridge = (None if authorization is None else
                              self.destination_bridges.get(
                                  authorization.destination_domain_id))
        if (credit is None or credit.status != "QUEUED"
                or authorization is None or destination_bridge is None
                or not verifier.verify(
                    proof=proof, credit_id=credit_id, terminal="FAILED",
                    destination_domain_id=authorization.destination_domain_id,
                    destination_bridge=destination_bridge)):
            return False
        credit.status = "RECALLED"
        assert authorization is not None
        self.refunds[authorization.owner] = (
            self.refunds.get(authorization.owner, 0) + credit.value)
        return True

    def ordinary_payout(self, amount: int) -> bool:
        if (amount < 0 or amount > self.ether_quota
                or self.balance - amount < self.total_live_liability):
            return False
        self.balance -= amount
        self.ether_quota -= amount
        return True

    def withdraw_refund(self, owner: str) -> int:
        amount = self.refunds.pop(owner, 0)
        self.total_live_liability -= amount
        self.balance -= amount
        return amount


@dataclass
class RefundCapsule:
    owner: str
    amount: int
    capsule_hash: str
    claimed: bool = False


@dataclass
class RefundVaultLedger:
    balance: int
    reserved: int = 0
    token_quota: int = UINT64_MAX
    capsules: dict[str, RefundCapsule] = field(default_factory=dict)

    def register(self, credit_id: str, *, owner: str, amount: int,
                 capsule_hash: str, calldata_hash_matches: bool) -> bool:
        if (not credit_id or credit_id in self.capsules or not owner
                or amount <= 0 or not capsule_hash or not calldata_hash_matches
                or self.reserved + amount > self.balance):
            return False
        self.capsules[credit_id] = RefundCapsule(owner, amount, capsule_hash)
        self.reserved += amount
        return True

    def ordinary_payout(self, amount: int) -> bool:
        if (amount < 0 or amount > self.token_quota
                or self.balance - amount < self.reserved):
            return False
        self.balance -= amount
        self.token_quota -= amount
        return True

    def release_delivered(self, credit_id: str,
                          source: SourceBridgeLedger) -> bool:
        capsule = self.capsules.get(credit_id)
        credit = source.credits.get(credit_id)
        if (capsule is None or capsule.claimed or credit is None
                or credit.status != "DELIVERED"):
            return False
        capsule.claimed = True
        self.reserved -= capsule.amount
        return True

    def claim_refund(self, credit_id: str, *, caller: str,
                     source: SourceBridgeLedger,
                     transfer_succeeds: bool = True) -> bool:
        capsule = self.capsules.get(credit_id)
        credit = source.credits.get(credit_id)
        if (capsule is None or capsule.claimed or caller != capsule.owner
                or credit is None or credit.status not in {"CANCELLED", "RECALLED"}
                or not transfer_succeeds):
            return False
        capsule.claimed = True
        self.reserved -= capsule.amount
        self.balance -= capsule.amount
        return True


@dataclass
class RefundRestorableToken:
    frozen_vault: str
    paused: bool = False
    restored: set[str] = field(default_factory=set)

    def restore(self, credit_id: str, *, caller: str,
                capsule_matches: bool) -> bool:
        if (not credit_id or caller != self.frozen_vault
                or not capsule_matches or credit_id in self.restored):
            return False
        self.restored.add(credit_id)
        return True


@dataclass
class BridgeAdapter:
    source_bridge: str = "bridge:A"
    records: dict[str, BridgeRecord] = field(default_factory=dict)
    refunds: dict[str, int] = field(default_factory=dict)
    balance: int = 0

    @staticmethod
    def credit_id(src_chain_id: int, source_domain_id: str, src_epoch: int,
                  src_bridge: str, destination_domain_id: str,
                  msg_hash: str) -> str:
        return (f"credit:{src_chain_id}:{source_domain_id}:{src_epoch}:"
                f"{src_bridge}:{destination_domain_id}:{msg_hash}")

    def enqueue(self, protocol_: Protocol, clock_: Clock,
                source_ledger: SourceBridgeLedger, *, src_chain_id: int,
                source_domain_id: str, src_epoch: int, src_bridge: str,
                destination_domain_id: str, msg_hash: str, enqueue_by: int,
                envelope: Message, caller: str, deposit: int,
                source_record_present: bool = True,
                source_record_matches: bool = True,
                source_liability_live: bool = True,
                domain_authorized: bool = True,
                direct_call_bounded: bool = True) -> str:
        credit_id = self.credit_id(
            src_chain_id, source_domain_id, src_epoch, src_bridge,
            destination_domain_id, msg_hash)
        existing = self.records.get(credit_id)
        if existing is not None:
            return (f"QUEUED:{existing.index}" if deposit == 0
                    else "REJECTED_DUPLICATE_FUNDS")
        source_authorization = source_ledger.authorizations.get(credit_id)
        source_credit = source_ledger.credits.get(credit_id)
        if (not caller or deposit <= 0
                or envelope.kind is not ForceKind.BRIDGE_CREDIT
                or src_bridge != self.source_bridge
                or not source_record_present or not source_record_matches
                or not source_liability_live or not domain_authorized
                or not direct_call_bounded or source_credit is None
                or source_authorization is None
                or source_credit.status != "NEW"
                or source_authorization.enqueue_by != enqueue_by
                or clock_.timestamp > enqueue_by):
            return "REJECTED"
        queue_snapshot = copy.deepcopy(protocol_.forced_queue)
        result = protocol_.admit_bridge_direct(
            clock_, replace(envelope, prepaid=deposit))
        if result == "SYNCED":
            # msg.value never left the adapter because syncIngress was
            # nonpayable and no append call occurred.
            self.balance += deposit
            self.refunds[caller] = self.refunds.get(caller, 0) + deposit
            return "SYNCED_REFUNDED"
        if result == "ADMITTED":
            index = len(protocol_.messages) - 1
            if not source_ledger.mark_queued(
                    credit_id, index, caller_is_bound_adapter=domain_authorized):
                protocol_.forced_queue.__dict__.update(
                    queue_snapshot.__dict__)  # models atomic EVM rollback
                return "REJECTED"
            self.records[credit_id] = BridgeRecord(
                envelope, index, caller, deposit)
            return f"QUEUED:{index}"
        return result

    def withdraw_refund(self, caller: str) -> int:
        amount = self.refunds.pop(caller, 0)
        if amount > self.balance:
            self.refunds[caller] = amount
            return 0
        self.balance -= amount
        return amount


@dataclass(frozen=True)
class InboxPin:
    result_hash: str
    process_by: int


@dataclass
class InboxCreditStoreV2:
    authorized_inbox_apply: str
    destination_bridge: str
    destination_domain_id: str
    address: str = ""
    activation_gate: str = "activation-gate"
    terminal_registrar: str = "terminal-domain-registrar"
    pins: dict[str, InboxPin] = field(default_factory=dict)
    runtime_codehash: str = ""
    batch_return_data: bytes = INBOX_BATCH_OK_V2_WORD
    batch_writes_enabled: bool = True

    def __post_init__(self) -> None:
        if not self.address:
            suffix = self.destination_domain_id.split(":")[-1]
            self.address = f"inbox-store:{suffix}"
        if not self.runtime_codehash:
            suffix = self.destination_domain_id.split(":")[-1]
            self.runtime_codehash = f"codehash:store:{suffix}"

    @property
    def route_config_hash(self) -> str:
        return (f"config:{self.authorized_inbox_apply}:"
                f"{self.destination_bridge}:{self.activation_gate}:"
                f"{self.terminal_registrar}:{self.destination_domain_id}")

    @property
    def component_config_hash(self) -> str:
        return (f"component-config:{self.authorized_inbox_apply}:"
                f"{self.destination_bridge}:{self.activation_gate}:"
                f"{self.terminal_registrar}")

    def pin(self, credit_id: str, result_hash: str, *, now: int,
            caller: str) -> bool:
        if (caller != self.authorized_inbox_apply or not credit_id
                or not result_hash):
            return False
        expected = InboxPin(result_hash, now + BRIDGE_PROCESS_TTL_SECONDS)
        existing = self.pins.get(credit_id)
        if existing is not None:
            return existing.result_hash == result_hash
        self.pins[credit_id] = expected
        return True

    def read(self, credit_id: str, *, caller: str,
             destination_domain_id: str) -> InboxPin | None:
        if (caller != self.destination_bridge
                or destination_domain_id != self.destination_domain_id):
            return None
        return self.pins.get(credit_id)

    def pin_batch(self, rows: tuple[tuple[str, str], ...], *, now: int,
                  caller: str) -> bytes | None:
        if caller != self.authorized_inbox_apply:
            return None
        for credit_id, result_hash in rows:
            existing = self.pins.get(credit_id)
            if (not credit_id or not result_hash
                    or (existing is not None
                        and existing.result_hash != result_hash)):
                return None
        if self.batch_writes_enabled:
            for credit_id, result_hash in rows:
                if credit_id not in self.pins:
                    self.pins[credit_id] = InboxPin(
                        result_hash, now + BRIDGE_PROCESS_TTL_SECONDS)
        return self.batch_return_data


@dataclass(frozen=True)
class InboxRoute:
    store: InboxCreditStoreV2
    destination_bridge: str
    store_codehash: str
    store_config_hash: str


def inbox_kind1_descriptor(domain_id: str, credit_id: str) -> bytes:
    """Behavioral proxy; byte-exact 533-byte vectors live in commitment-model."""
    payload = domain_id.encode() + b"\x00" + credit_id.encode()
    assert 0 < len(payload) <= 531
    return len(payload).to_bytes(2, "big") + payload + bytes(531 - len(payload))


def decode_inbox_kind1_descriptor(descriptor: bytes) -> tuple[str, str] | None:
    if len(descriptor) != 533:
        return None
    length = int.from_bytes(descriptor[:2], "big")
    if not 0 < length <= 531 or any(descriptor[2 + length:]):
        return None
    try:
        domain_raw, credit_raw = descriptor[2:2 + length].split(b"\x00", 1)
        domain_id, credit_id = domain_raw.decode(), credit_raw.decode()
    except (UnicodeDecodeError, ValueError):
        return None
    if not domain_id or not credit_id:
        return None
    return domain_id, credit_id


def inbox_kind1_result(index: int, domain_id: str, credit_id: str) -> str:
    return f"result:{index}:{domain_id}:{credit_id}"


@dataclass
class InboxApplyRouterV2:
    """Lifetime dispatcher for mixed-domain forced-credit rows."""

    address: str = "inbox-apply"
    registrar: str = "terminal-domain-registrar"
    next_queue_index: int = 0
    last_applied_l2_block: int = -1
    routes: dict[str, InboxRoute] = field(default_factory=dict)

    def __setattr__(self, name: str, value: object) -> None:
        if name in {"address", "registrar"} and name in self.__dict__:
            raise AttributeError(f"InboxApply {name} is immutable")
        object.__setattr__(self, name, value)

    def register_route(self, domain_id: str, store: InboxCreditStoreV2,
                       destination_bridge: str, store_codehash: str, *,
                       caller: str, manifest_exact: bool) -> bool:
        if (caller != self.registrar or not manifest_exact or not domain_id
                or store.authorized_inbox_apply != self.address
                or store.destination_domain_id != domain_id
                or store.destination_bridge != destination_bridge
                or not store_codehash):
            return False
        if store.runtime_codehash != store_codehash:
            return False
        route = InboxRoute(
            store, destination_bridge, store_codehash,
            store.route_config_hash)
        existing = self.routes.get(domain_id)
        if existing is not None:
            return existing == route
        if any(row.store is store for row in self.routes.values()):
            return False
        self.routes[domain_id] = route
        return True

    def apply(self, force_start: int,
              rows: tuple[tuple[int, int, int, str, bytes], ...], *,
              now: int, l2_block_number: int,
              caller_is_system_sender: bool) -> bool:
        if (not caller_is_system_sender
                or not 0 <= len(rows) <= MAX_FORCE_MESSAGES
                or force_start != self.next_queue_index
                or l2_block_number <= self.last_applied_l2_block
                or tuple(row[0] for row in rows)
                    != tuple(range(
                        self.next_queue_index,
                        self.next_queue_index + len(rows)))):
            return False
        staged: list[tuple[str, InboxCreditStoreV2 | None, str, str]] = []
        seen_credits: set[tuple[str, str]] = set()
        for index, disposition, tx_index, result_hash, descriptor in rows:
            if disposition != 5:
                if (descriptor or disposition not in range(5)
                        or (disposition < 4 and
                            (tx_index != UINT32_MAX or result_hash))
                        or (disposition == 4 and
                            (not 0 <= tx_index < UINT32_MAX
                             or not result_hash))):
                    return False
                staged.append(("", None, "", ""))
                continue
            decoded = decode_inbox_kind1_descriptor(descriptor)
            if decoded is None or tx_index != UINT32_MAX:
                return False
            domain_id, credit_id = decoded
            route = self.routes.get(domain_id)
            expected_result = inbox_kind1_result(
                index, domain_id, credit_id)
            if (route is None or result_hash != expected_result
                    or route.store.runtime_codehash != route.store_codehash
                    or route.store.route_config_hash != route.store_config_hash
                    or route.store.authorized_inbox_apply != self.address
                    or route.store.destination_bridge
                        != route.destination_bridge
                    or route.store.destination_domain_id != domain_id
                    or (domain_id, credit_id) in seen_credits):
                return False
            seen_credits.add((domain_id, credit_id))
            existing = route.store.pins.get(credit_id)
            if existing is not None:
                if existing.result_hash != result_hash:
                    return False
            staged.append((domain_id, route.store, credit_id, result_hash))

        runs: list[tuple[InboxCreditStoreV2, list[tuple[str, str]]]] = []
        for _, store, credit_id, result_hash in staged:
            if store is None:
                if runs:
                    runs.append((None, []))
                continue
            if not runs or runs[-1][0] is not store:
                runs.append((store, []))
            runs[-1][1].append((credit_id, result_hash))
        journal: list[tuple[InboxCreditStoreV2, str, InboxPin | None]] = []
        for store, run in runs:
            if store is None:
                continue
            for credit_id, _ in run:
                journal.append((store, credit_id, store.pins.get(credit_id)))
            returned = store.pin_batch(
                tuple(run), now=now, caller=self.address)
            writes_match = all(
                store.pins.get(credit_id)
                    == InboxPin(result_hash,
                                now + BRIDGE_PROCESS_TTL_SECONDS)
                for credit_id, result_hash in run)
            if returned != INBOX_BATCH_OK_V2_WORD or not writes_match:
                for touched_store, credit_id, prior in reversed(journal):
                    if prior is None:
                        touched_store.pins.pop(credit_id, None)
                    else:
                        touched_store.pins[credit_id] = prior
                return False
        self.next_queue_index += len(rows)
        self.last_applied_l2_block = l2_block_number
        return True


@dataclass
class TerminalAccumulatorV2:
    """Protocol-lifetime append-only terminal vector with immutable old writers."""

    domains: dict[str, str]
    registrar: str = "terminal-domain-registrar"
    leaves: list[str] = field(default_factory=list)
    append_return_length: int = 32
    append_return_padding_ok: bool = True

    @property
    def count(self) -> int:
        return len(self.leaves)

    @property
    def root(self) -> str:
        return "terminal-root:" + "|".join(self.leaves)

    def register_domain(self, domain_id: str, bridge: str, *, caller: str,
                        release_active: bool, descriptor_valid: bool,
                        activation_order_valid: bool) -> bool:
        if (caller != self.registrar or not release_active
                or not descriptor_valid or not activation_order_valid):
            return False
        existing = self.domains.get(domain_id)
        if existing is not None:
            return existing == bridge
        if not domain_id or not bridge or bridge in self.domains.values():
            return False
        self.domains[domain_id] = bridge
        return True

    def append_terminal(self, *, caller: DestinationBridgeLedger,
                        credit_id: str) -> int | None:
        if (not caller.terminal_commitment_gas_ok
                or caller.terminal_commitment_return_length
                    != TERMINAL_COMMITMENT_ABI_BYTES):
            return None
        commitment = caller.terminal_commitment_v2(credit_id)
        if commitment is None:
            return None
        domain_id, bridge, terminal, terminal_index = commitment
        if (self.domains.get(domain_id) != bridge or bridge != caller.address
                or not credit_id or terminal not in {"DONE", "FAILED"}
                or terminal_index != APPENDING_SENTINEL):
            return None
        index = self.count
        self.leaves.append(TerminalSignalVerifier.terminal_leaf(
            index, domain_id, bridge, credit_id, terminal))
        return index


@dataclass(frozen=True)
class ReleaseComponentV2:
    address: str
    runtime_hash: str
    config_hash: str


@dataclass(frozen=True)
class DestinationBridgeDescriptorV2:
    bridge: str
    facade_runtime_hash: str
    storage_layout_hash: str
    bridge_kernel_profile_hash: str
    inbox_credit_store: str
    terminal_accumulator: str
    activation_gate: str
    terminal_domain_registrar: str

    @property
    def execution_hash(self) -> str:
        return "destination-bridge-execution:" + repr(self)


@dataclass(frozen=True)
class ReleaseManifestV2:
    protocol_version: int
    settlement_chain_id: int
    destination_chain_id: int
    destination_genesis_hash: str
    execution_profile_hash: str
    manifest_namespace: str
    destination_namespace: str
    anchor: str
    anchor_runtime_hash: str
    activation_gate: str
    activation_gate_runtime_hash: str
    destination_domain_id: str
    destination_bridge: str
    destination_bridge_execution_hash: str
    destination_bridge_descriptor: DestinationBridgeDescriptorV2
    destination_infrastructure_hash: str
    components: tuple[ReleaseComponentV2, ...]

    @property
    def commitment(self) -> str:
        """Behavioral proxy for the byte-exact 1,372-byte commitment model."""
        values = (
            self.protocol_version, self.settlement_chain_id,
            self.destination_chain_id, self.destination_genesis_hash,
            self.execution_profile_hash, self.manifest_namespace,
            self.destination_namespace, self.anchor,
            self.anchor_runtime_hash, self.activation_gate,
            self.activation_gate_runtime_hash, self.destination_domain_id,
            self.destination_bridge, self.destination_bridge_execution_hash,
            self.destination_bridge_descriptor,
            self.destination_infrastructure_hash,
            *((row.address, row.runtime_hash, row.config_hash)
              for row in self.components),
        )
        return "release-manifest:" + repr(values)

    @property
    def registration_commitment(self) -> str:
        values = (
            self.protocol_version, self.commitment,
            self.destination_chain_id, self.destination_namespace,
            self.destination_domain_id, self.destination_bridge,
            self.destination_infrastructure_hash, self.execution_profile_hash)
        return "destination-registration:" + repr(values)

    def structurally_valid(self) -> bool:
        addresses = tuple(row.address for row in self.components)
        return (self.protocol_version > 0
                and 0 < self.settlement_chain_id <= UINT64_MAX
                and 0 < self.destination_chain_id <= UINT64_MAX
                and all((self.destination_genesis_hash,
                         self.execution_profile_hash,
                         self.manifest_namespace, self.destination_namespace,
                         self.anchor,
                         self.anchor_runtime_hash, self.activation_gate,
                         self.activation_gate_runtime_hash,
                         self.destination_domain_id, self.destination_bridge,
                         self.destination_bridge_execution_hash,
                         self.destination_infrastructure_hash))
                and len(self.components) == 9
                and all(row.address and row.runtime_hash and row.config_hash
                        for row in self.components)
                and len(set(addresses)) == 9
                and self.components[8].address == self.destination_bridge
                and self.destination_bridge_descriptor.bridge
                    == self.destination_bridge
                and self.destination_bridge_descriptor.execution_hash
                    == self.destination_bridge_execution_hash
                and self.destination_bridge_descriptor.inbox_credit_store
                    == self.components[4].address
                and self.destination_bridge_descriptor.terminal_accumulator
                    == self.components[7].address
                and self.destination_bridge_descriptor.activation_gate
                    == self.activation_gate
                and self.destination_bridge_descriptor.terminal_domain_registrar
                    == self.components[6].address)


@dataclass
class EndpointActivationStateV2:
    """Only endpoint-local V2 namespaces start empty; V1 custody may not."""

    store_domain_unset: bool = True
    store_pins_empty: bool = True
    store_sealer_live: bool = True
    gate_active: bool = False
    gate_sealer_live: bool = True
    bridge_v2_domain_unset: bool = True
    bridge_v2_terminal_namespace_empty: bool = True
    bridge_sealer_live: bool = True
    legacy_v1_state_fingerprint: str = "arbitrary-preserved-v1-state"

    @property
    def activatable(self) -> bool:
        return (self.store_domain_unset and self.store_pins_empty
                and self.store_sealer_live and not self.gate_active
                and self.gate_sealer_live and self.bridge_v2_domain_unset
                and self.bridge_v2_terminal_namespace_empty
                and self.bridge_sealer_live
                and bool(self.legacy_v1_state_fingerprint))

    @property
    def exact_existing(self) -> bool:
        return (not self.store_domain_unset and not self.store_sealer_live
                and self.gate_active and not self.gate_sealer_live
                and not self.bridge_v2_domain_unset
                and not self.bridge_sealer_live
                and bool(self.legacy_v1_state_fingerprint))

    def seal(self) -> bool:
        if not self.activatable:
            return False
        self.store_domain_unset = False
        self.store_sealer_live = False
        self.gate_active = True
        self.gate_sealer_live = False
        self.bridge_v2_domain_unset = False
        self.bridge_sealer_live = False
        return True


@dataclass(frozen=True)
class BridgeDeploymentStateV2:
    """Only immutable facades or the one fork-attested legacy proxy qualify."""

    topology: str
    address: str
    account_runtime_hash: str
    implementation_address: str = ""
    implementation_runtime_hash: str = ""
    direct_prestate_slot_constraint: bool = False
    upgrade_authority_burned: bool = True
    delegate_target_reachable: bool = False

    def identity(self, manifest: ReleaseManifestV2) -> tuple[str, ...]:
        return (self.topology, self.address, self.account_runtime_hash,
                self.implementation_address,
                self.implementation_runtime_hash,
                manifest.components[8].config_hash)

    def authenticates(
            self, manifest: ReleaseManifestV2, *,
            known_identity: tuple[str, ...] | None = None) -> bool:
        bridge_row = manifest.components[8]
        descriptor = manifest.destination_bridge_descriptor
        topology_byte = {
            "IMMUTABLE_NONPROXY": 0,
            "GENESIS_LEGACY_PROXY": 1,
        }.get(self.topology)
        if topology_byte is None:
            return False
        expected_config_hash = "component-config:9:177:" + repr((
            topology_byte, self.account_runtime_hash,
            descriptor.facade_runtime_hash,
            descriptor.inbox_credit_store,
            descriptor.terminal_accumulator,
            descriptor.activation_gate,
            descriptor.terminal_domain_registrar,
            descriptor.storage_layout_hash))
        common = (self.address == manifest.destination_bridge
                  and self.account_runtime_hash == bridge_row.runtime_hash
                  and expected_config_hash == bridge_row.config_hash
                  and self.upgrade_authority_burned)
        if self.topology == "IMMUTABLE_NONPROXY":
            return (common and not self.delegate_target_reachable
                    and not self.implementation_address
                    and not self.implementation_runtime_hash
                    and self.account_runtime_hash
                        == descriptor.facade_runtime_hash)
        if self.topology == "GENESIS_LEGACY_PROXY":
            return (common
                    and ((known_identity == self.identity(manifest))
                         or (known_identity is None
                             and manifest.protocol_version == 1
                             and self.direct_prestate_slot_constraint))
                    and bool(self.implementation_address)
                    and self.implementation_runtime_hash
                        == descriptor.facade_runtime_hash)
        return False


@dataclass
class AnchorV4Model:
    address: str
    runtime_hash: str
    finalized_l1_manifest_hash: str
    active_release_manifest_hash: str = ""

    def authenticate(self, manifest: ReleaseManifestV2) -> bool:
        if (not manifest.structurally_valid()
                or manifest.anchor != self.address
                or manifest.anchor_runtime_hash != self.runtime_hash
                or manifest.commitment != self.finalized_l1_manifest_hash):
            return False
        self.active_release_manifest_hash = manifest.commitment
        return True


@dataclass
class ProtocolReleaseAuthorityV2:
    """Lifetime authority reached by the manifest Anchor in a system tx."""

    system_sender: str = "system:anchor"
    releases: dict[int, str] = field(default_factory=dict)

    def activate(self, manifest: ReleaseManifestV2, *, caller: AnchorV4Model,
                 tx_origin: str) -> bool:
        manifest_hash = manifest.commitment
        if (not manifest.structurally_valid()
                or caller.address != manifest.anchor
                or caller.runtime_hash != manifest.anchor_runtime_hash
                or tx_origin != self.system_sender
                or caller.active_release_manifest_hash != manifest_hash):
            return False
        existing = self.releases.get(manifest.protocol_version)
        if existing is not None:
            return existing == manifest_hash
        self.releases[manifest.protocol_version] = manifest_hash
        return True


@dataclass
class TerminalDomainRegistrarV2:
    """Lifetime registrar; endpoints come only from an authenticated manifest."""

    authority: ProtocolReleaseAuthorityV2
    accumulator: TerminalAccumulatorV2
    inbox_router: InboxApplyRouterV2
    address: str = "terminal-domain-registrar"
    registrations: dict[int, str] = field(default_factory=dict)
    bridge_identities: dict[str, tuple[str, ...]] = field(default_factory=dict)

    def activate_domain(self, manifest: ReleaseManifestV2,
                        store: InboxCreditStoreV2, *,
                        observed_l2_components:
                            tuple[ReleaseComponentV2, ...],
                        observed_bridge_descriptor:
                            DestinationBridgeDescriptorV2,
                        endpoint_state: EndpointActivationStateV2,
                        bridge_deployment: BridgeDeploymentStateV2) -> bool:
        protocol_version = manifest.protocol_version
        manifest_hash = manifest.commitment
        domain_id = manifest.destination_domain_id
        bridge = manifest.destination_bridge
        known_bridge_identity = self.bridge_identities.get(bridge)
        store_row = manifest.components[4] if len(manifest.components) == 9 \
            else ReleaseComponentV2("", "", "")
        if (not manifest.structurally_valid()
                or self.authority.releases.get(protocol_version) != manifest_hash
                or protocol_version in self.registrations
                or observed_l2_components != manifest.components[3:]
                or observed_bridge_descriptor
                    != manifest.destination_bridge_descriptor
                or store_row.address != store.address
                or store_row.runtime_hash != store.runtime_codehash
                or store_row.config_hash != store.component_config_hash
                or not (endpoint_state.activatable
                        or endpoint_state.exact_existing)
                or not bridge_deployment.authenticates(
                    manifest, known_identity=known_bridge_identity)):
            return False
        fresh_endpoint = endpoint_state.activatable
        prior_routes = dict(self.inbox_router.routes)
        prior_domains = dict(self.accumulator.domains)
        endpoint_snapshot = copy.deepcopy(endpoint_state)
        if (not self.inbox_router.register_route(
                domain_id, store, bridge, store_row.runtime_hash,
                caller=self.address,
                manifest_exact=True)
                or not self.accumulator.register_domain(
                    domain_id, bridge, caller=self.address,
                    release_active=True, descriptor_valid=True,
                    activation_order_valid=True)
                or (fresh_endpoint and not endpoint_state.seal())):
            self.inbox_router.routes = prior_routes
            self.accumulator.domains = prior_domains
            endpoint_state.__dict__.update(endpoint_snapshot.__dict__)
            return False
        self.bridge_identities.setdefault(
            bridge, bridge_deployment.identity(manifest))
        self.registrations[protocol_version] = manifest.registration_commitment
        return True


def release_manifest_fixture(protocol_version: int, domain_id: str,
                             bridge: str, store: InboxCreditStoreV2,
                             anchor: str | None = None, *,
                             legacy_proxy: bool = False) -> ReleaseManifestV2:
    anchor_address = anchor or f"anchor:v{protocol_version}"
    facade_runtime_hash = f"facade-code:{bridge}"
    topology = ("GENESIS_LEGACY_PROXY" if legacy_proxy
                else "IMMUTABLE_NONPROXY")
    bridge_runtime_hash = (f"proxy-code:{bridge}" if legacy_proxy
                           else facade_runtime_hash)
    topology_byte = 1 if legacy_proxy else 0
    base_components = (
        ReleaseComponentV2("bridge-inbox-adapter", "code:adapter", "cfg:adapter"),
        ReleaseComponentV2("active-settlement-router", "code:router", "cfg:router"),
        ReleaseComponentV2("terminal-verifier", "code:verifier", "cfg:verifier"),
        ReleaseComponentV2("inbox-apply", "code:inbox-apply", "cfg:inbox-apply"),
        ReleaseComponentV2(store.address, store.runtime_codehash,
                           store.component_config_hash),
        ReleaseComponentV2("release-authority", "code:authority", "cfg:authority"),
        ReleaseComponentV2("terminal-domain-registrar", "code:registrar", "cfg:registrar"),
        ReleaseComponentV2("terminal-accumulator", "code:accumulator", "cfg:accumulator"),
    )
    bridge_descriptor = DestinationBridgeDescriptorV2(
        bridge, facade_runtime_hash, f"storage-layout:{bridge}",
        f"kernel-profile:{bridge}", store.address, "terminal-accumulator",
        "activation-gate", "terminal-domain-registrar")
    topology_config_hash = "component-config:9:177:" + repr((
        topology_byte, bridge_runtime_hash, facade_runtime_hash,
        bridge_descriptor.inbox_credit_store,
        bridge_descriptor.terminal_accumulator,
        bridge_descriptor.activation_gate,
        bridge_descriptor.terminal_domain_registrar,
        bridge_descriptor.storage_layout_hash))
    components = (*base_components, ReleaseComponentV2(
        bridge, bridge_runtime_hash, topology_config_hash))
    return ReleaseManifestV2(
        protocol_version, 1, 167_000, "genesis:destination",
        f"profile:{protocol_version}", "manifest:v2", "domain-namespace:v2",
        anchor_address,
        f"code:{anchor_address}", "activation-gate", "code:activation-gate",
        domain_id, bridge, bridge_descriptor.execution_hash, bridge_descriptor,
        "infrastructure:" + repr(components), components)


def activate_release_transaction(
        authority: ProtocolReleaseAuthorityV2,
        registrar: TerminalDomainRegistrarV2, *,
        manifest: ReleaseManifestV2, transaction_sender: str,
        anchor: AnchorV4Model, store: InboxCreditStoreV2,
        observed_l2_components: tuple[ReleaseComponentV2, ...] | None = None,
        observed_bridge_descriptor: DestinationBridgeDescriptorV2 | None = None,
        endpoint_state: EndpointActivationStateV2 | None = None,
        bridge_deployment: BridgeDeploymentStateV2 | None = None,
        settlement_chain_id: int = 1,
        destination_chain_id: int = 167_000,
        direct_component_checks_succeed: bool = True) -> bool:
    """Model the single system transaction and its all-or-revert EVM calls."""
    releases = dict(authority.releases)
    registrations = dict(registrar.registrations)
    bridge_identities = dict(registrar.bridge_identities)
    routes = dict(registrar.inbox_router.routes)
    domains = dict(registrar.accumulator.domains)
    state = endpoint_state or EndpointActivationStateV2()
    endpoint_snapshot = copy.deepcopy(state)
    deployment = bridge_deployment or BridgeDeploymentStateV2(
        "IMMUTABLE_NONPROXY", manifest.destination_bridge,
        manifest.components[8].runtime_hash,
        upgrade_authority_burned=direct_component_checks_succeed)
    active_manifest = anchor.active_release_manifest_hash
    if (transaction_sender != authority.system_sender
            or manifest.settlement_chain_id != settlement_chain_id
            or manifest.destination_chain_id != destination_chain_id
            or not anchor.authenticate(manifest)
            or not authority.activate(
                manifest, caller=anchor, tx_origin=transaction_sender)
            or not registrar.activate_domain(
                manifest, store,
                observed_l2_components=(
                    manifest.components[3:] if observed_l2_components is None
                    else observed_l2_components),
                observed_bridge_descriptor=(
                    manifest.destination_bridge_descriptor
                    if observed_bridge_descriptor is None
                    else observed_bridge_descriptor),
                endpoint_state=state,
                bridge_deployment=deployment)):
        authority.releases = releases
        registrar.registrations = registrations
        registrar.bridge_identities = bridge_identities
        registrar.inbox_router.routes = routes
        registrar.accumulator.domains = domains
        anchor.active_release_manifest_hash = active_manifest
        state.__dict__.update(endpoint_snapshot.__dict__)
        return False
    return True


@dataclass
class DestinationBridgeLedger:
    address: str = "bridge:A"
    local_domain_id: str = "domain:D1"
    paused: bool = False
    inbox_store: InboxCreditStoreV2 = field(default_factory=lambda:
        InboxCreditStoreV2("inbox-apply", "bridge:A", "domain:D1"))
    terminal_accumulator: TerminalAccumulatorV2 = field(default_factory=lambda:
        TerminalAccumulatorV2({"domain:D1": "bridge:A"}))
    status: dict[str, str] = field(default_factory=dict)
    terminal_index: dict[str, int] = field(default_factory=dict)
    terminal_commitment_return_length: int = TERMINAL_COMMITMENT_ABI_BYTES
    terminal_commitment_gas_ok: bool = True

    def pin(self, credit_id: str, result_hash: str, *, now: int,
            caller_is_inbox_apply: bool) -> bool:
        accepted = self.inbox_store.pin(
            credit_id, result_hash, now=now,
            caller="inbox-apply" if caller_is_inbox_apply else "attacker")
        if accepted and credit_id not in self.status:
            self.status[credit_id] = "NEW"
        return accepted

    def _pin(self, credit_id: str, destination_domain_id: str) -> InboxPin | None:
        return self.inbox_store.read(
            credit_id, caller=self.address,
            destination_domain_id=destination_domain_id)

    def _terminalize(self, credit_id: str, terminal: str) -> bool:
        if credit_id in self.terminal_index:
            return False
        prior_status = self.status.get(credit_id)
        self.status[credit_id] = terminal
        self.terminal_index[credit_id] = APPENDING_SENTINEL
        index = self.terminal_accumulator.append_terminal(
            caller=self, credit_id=credit_id)
        if (index is None
                or self.terminal_accumulator.append_return_length != 32
                or not self.terminal_accumulator.append_return_padding_ok
                or not 0 <= index < UINT64_MAX):
            if index is not None:
                self.terminal_accumulator.leaves = \
                    self.terminal_accumulator.leaves[:index]
            self.status[credit_id] = prior_status if prior_status is not None else "NEW"
            self.terminal_index.pop(credit_id, None)
            return False
        self.terminal_index[credit_id] = index
        return True

    def terminal_commitment_v2(
            self, credit_id: str) -> tuple[str, str, str, int] | None:
        terminal = self.status.get(credit_id)
        index = self.terminal_index.get(credit_id)
        if terminal not in {"DONE", "FAILED"} or index is None:
            return None
        return self.local_domain_id, self.address, terminal, index

    def accepts_message_target(self, target: str, *, version: str) -> bool:
        return not (version == "V2" and target == "terminal-accumulator")

    def process(self, credit_id: str, *, now: int,
                message_available: bool, result_hash_matches: bool,
                callback_ok: bool,
                destination_domain_id: str = "domain:D1",
                context_dest_bridge: str = "bridge:A") -> str:
        pin = self._pin(credit_id, destination_domain_id)
        current = self.status.get(credit_id)
        if (self.paused or pin is None or current in {"DONE", "FAILED"}
                or now > pin.process_by or not result_hash_matches
                or context_dest_bridge != self.address
                or destination_domain_id != self.local_domain_id):
            return "REJECTED"
        if not message_available or not callback_ok:
            self.status[credit_id] = "RETRIABLE"
            return "RETRIABLE"
        return "DONE" if self._terminalize(credit_id, "DONE") else "REJECTED"

    def retry(self, credit_id: str, *, now: int, caller_is_dest_owner: bool,
              is_last_attempt: bool, message_available: bool,
              result_hash_matches: bool, callback_ok: bool,
              destination_domain_id: str = "domain:D1",
              context_dest_bridge: str = "bridge:A") -> str:
        if is_last_attempt and not caller_is_dest_owner:
            return "REJECTED"
        return self.process(
            credit_id, now=now, message_available=message_available,
            result_hash_matches=result_hash_matches, callback_ok=callback_ok,
            destination_domain_id=destination_domain_id,
            context_dest_bridge=context_dest_bridge)

    def manual_fail(self, credit_id: str, *, caller_is_dest_owner: bool,
                    destination_domain_id: str = "domain:D1",
                    context_dest_bridge: str = "bridge:A") -> bool:
        if (self.paused or not caller_is_dest_owner
                or self.status.get(credit_id) != "RETRIABLE"
                or context_dest_bridge != self.address
                or destination_domain_id != self.local_domain_id):
            return False
        return self._terminalize(credit_id, "FAILED")

    def expire(self, credit_id: str, *, now: int,
               destination_domain_id: str = "domain:D1",
               context_dest_bridge: str = "bridge:A") -> bool:
        pin = self._pin(credit_id, destination_domain_id)
        current = self.status.get(credit_id)
        if (pin is None or current not in {"NEW", "RETRIABLE"}
                or context_dest_bridge != self.address
                or destination_domain_id != self.local_domain_id
                or now <= pin.process_by):
            return False
        return self._terminalize(credit_id, "FAILED")


PASS: list[str] = []


def check(name: str, condition: bool) -> None:
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def clock(number: int, l2_slot: int) -> Clock:
    return Clock(number, GENESIS_TIMESTAMP + l2_slot)


def message(enqueued_l2: int, ident: str, gas: int = 100_000, size: int = 100,
            *, kind: ForceKind = ForceKind.USER_TX) -> Message:
    return Message(GENESIS_TIMESTAMP + enqueued_l2, gas, size, ident, kind=kind,
                   valid_until=(UINT64_MAX if kind is ForceKind.BRIDGE_CREDIT
                                else GENESIS_TIMESTAMP + enqueued_l2 + DATA_TTL_SECONDS))


def make_header_oracle(
    messages: list[Message] | None = None,
) -> L1HeaderOracle:
    queue = list(messages or [])
    root = model_force_root(queue)
    headers = {
        n: L1Header(
            f"{n:064x}", GENESIS_TIMESTAMP + n,
            f"state-{n}", root, len(queue),
        )
        for n in range(1, 20_000)
    }
    return L1HeaderOracle(
        L1_HEADER_ORACLE_ADDRESS,
        L1_HEADER_ORACLE_RUNTIME_HASH,
        L1_HEADER_ORACLE_CONFIGURATION_HASH,
        headers,
    )


def protocol(tip_slot: int = 1_000, cursor: int = 0, seat: bool = True,
             mode: Mode = Mode.NORMAL, messages: list[Message] | None = None,
             forced_queue: QueueContinuity | None = None,
             inbox_apply_router: InboxApplyRouterV2 | None = None,
             header_oracle: L1HeaderOracle | None = None,
             migration_gate: MigrationGate | None = None,
             settlement_address: str = "model-settlement") -> Protocol:
    msgs = list(messages or [])
    if forced_queue is None:
        root = model_force_root(msgs)
        forced_queue = QueueContinuity(
            "model-forced-queue", root, len(msgs), cursor,
            sum(row.prepaid for row in msgs),
            max((row.due_at for row in msgs), default=0), msgs,
            active_settlement_address=settlement_address)
    else:
        assert not messages or forced_queue.descriptors == msgs
        msgs = forced_queue.descriptors
    if inbox_apply_router is None:
        inbox_apply_router = InboxApplyRouterV2(next_queue_index=cursor)
    if header_oracle is None:
        header_oracle = make_header_oracle(msgs)
    if migration_gate is None:
        migration_gate = MigrationGate()
    canonical = Canonical(CanonicalCore(900, "a" * 64, tip_slot, "b" * 64, cursor), 900)
    result = Protocol(
        canonical, header_oracle, forced_queue, inbox_apply_router,
        settlement_address=settlement_address, mode=mode,
        migration_gate=migration_gate,
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
          release_activation: bool | None = None) -> Block:
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
    if release_activation is None:
        release_activation = p.release_activation_pending
    force_gas_budget = (ACTIVATION_FORCE_GAS_BUDGET if release_activation
                        else FORCE_GAS_BUDGET)
    end = (p._prefix_end(start, cutoff, gas_budget=force_gas_budget)
           if message_end is None else message_end)
    context = (p.recovery.recovery_id if p.mode is Mode.RECOVERY and p.recovery
               else normal_context_id(p.canonical.base_hash, version, root,
                                      anchor_number, header.block_hash))
    return Block(slot, GENESIS_TIMESTAMP + slot,
                 f"{abs(hash(ident)) % (1 << 256):064x}", p.core.tip_hash,
                 slot // 384, signed, start, end, anchor_number, header.block_hash,
                 header.timestamp, force_root, cutoff,
                 context,
                 version, root,
                 inbox_pre_cursor=start, inbox_post_cursor=end,
                 force_gas_budget=force_gas_budget,
                 release_activation=release_activation,
                 release_protocol_version=(
                     p.pending_release_protocol_version
                     if release_activation else 0),
                 release_manifest_hash=(
                     p.pending_release_manifest_hash
                     if release_activation else ""),
                 dispositions_ok=dispositions_ok, discretionary_body=discretionary)


def candidate(p: Protocol, c: Clock, ident="candidate", *, tier=Tier.NORMAL_SIGNED,
              signed=True, slot=None, message_end=None, discretionary=True,
              force_range_proof_ok=True, recovery_fields_zero=True,
              release_activation: bool | None = None) -> Candidate:
    b = block(p, c, ident, slot=slot, signed=signed, message_end=message_end,
              discretionary=discretionary,
              release_activation=release_activation)
    r = p.recovery
    next_due = p.next_due_at(b.message_end, b.force_cutoff)
    return Candidate(
        ident, p.canonical.base_hash, (b,), tier,
        f"state:{ident}", "empty", next_due,
        p.core.l2_block_number + 1,
        proof_ok=True, force_range_proof_ok=force_range_proof_ok,
        episode=r.episode if r else 0,
        recovery_revision=r.revision if r else 0,
        recovery_id=r.recovery_id if r else "",
        recovery_fields_zero=recovery_fields_zero,
        end_terminal_root=p.core.terminal_root,
        end_terminal_count=p.core.terminal_count,
    )


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


def test_canonical_outputs_and_migration() -> None:
    p = protocol(mode=Mode.PREACTIVE)
    pre = Clock(950, GENESIS_TIMESTAMP - 100)
    check("P2 preactivation slot saturates", pre.l2_slot == 0)
    check("P3 preactive rejects", p.submit(candidate(p, clock(1_100, 1_100)), clock(1_100, 1_100)) == "REJECTED_PREACTIVE")
    imported = Canonical(
        CanonicalCore(1_050, "c" * 64, 1_050, "d" * 64, 0,
                      "migration-sentinel", 101, 0),
        1_100,
    )
    activation_output = Canonical(
        replace(imported.core, l2_block_number=1_051, tip_slot=1_051,
                tip_hash="e" * 64, state_root="f" * 64,
                winning_data_commitment="activation-output"),
        1_100)
    check("P4 migration requires quiescence", not p.activate_migration(clock(1_100, 1_100), imported, activation_output, old_quiescent=False, router_switched=True))
    check("P4a migration proves deployed L2 system accounts", not p.activate_migration(
        clock(1_100, 1_100), imported, activation_output,
        old_quiescent=True, router_switched=True,
        l2_system_accounts_authenticated=False)
          and not p.activate_migration(
              clock(1_100, 1_100), imported, activation_output,
              old_quiescent=True,
              router_switched=True, l2_v2_latch_disabled=False))
    check("P4g launch never surrenders authority to an unproved target",
          not p.activate_migration(
              clock(1_100, 1_100), imported, activation_output,
              old_quiescent=True, router_switched=True,
              activation_proof_valid=False)
          and not p.activate_migration(
              clock(1_100, 1_100), imported, activation_output,
              old_quiescent=True, router_switched=True,
              target_components_valid=False)
          and p.mode is Mode.PREACTIVE)
    latch = L2ActivationLatch()
    check("P4e legacy calls cannot activate or invoke V2 system ingress",
          not latch.activate_from_anchor(
              custom_system_tx=False, slot_chain_fork_active=False,
              l1_cutover_authenticated=False)
          and not latch.inbox_apply(custom_system_tx=False)
          and not latch.bridge_v2_call()
          and not latch.active)
    check("P4f first post-cutover custom anchor activates the L2 latch",
          latch.activate_from_anchor(
              custom_system_tx=True, slot_chain_fork_active=True,
              l1_cutover_authenticated=True)
          and latch.inbox_apply(custom_system_tx=True)
          and latch.bridge_v2_call()
          and not latch.inbox_apply(custom_system_tx=False))
    preactive_adapter = BridgeAdapter()
    preactive_source = SourceBridgeLedger()
    preactive_id = preactive_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "preactive")
    preactive_now = clock(1_100, 1_100)
    assert preactive_source.open(
        preactive_id, now=preactive_now.timestamp,
        enqueue_by=preactive_now.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
        owner="alice", value=1, fee=1)
    check("P4b preactive bridge ingress cannot create a queue credit",
          preactive_adapter.enqueue(
              p, preactive_now, preactive_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1,
              src_bridge="bridge:A", destination_domain_id="domain:D1",
              msg_hash="preactive",
              enqueue_by=preactive_now.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
              envelope=message(1_100, "preactive", kind=ForceKind.BRIDGE_CREDIT),
              caller="relayer", deposit=1) == "REJECTED_PREACTIVE"
          and not preactive_adapter.records)
    preactive_user = message(1_100, "preactive-user")
    check("P4d preactive kind-0 ingress cannot create a queue leaf",
          p.admit_message(clock(1_100, 1_100), preactive_user)
              == "REJECTED_PREACTIVE"
          and not p.messages)
    dirty = protocol(mode=Mode.PREACTIVE,
                     messages=[message(1_100, "dirty")])
    check("P4c migration rejects a nonempty queue",
          not dirty.activate_migration(
              clock(1_100, 1_100), imported, activation_output,
              old_quiescent=True,
              router_switched=True))
    check("P5 atomic proof-first cutover adopts activation and enables ingress",
          p.activate_migration(
              clock(1_100, 1_100), imported, activation_output,
              old_quiescent=True,
              router_switched=True)
          and p.core == activation_output.core
          and not p.release_activation_pending
          and p.first_v2_block_number == 1_051
          and p.admit_message(clock(1_101, 1_101), preactive_user) == "ADMITTED")
    q = protocol()
    c = clock(1_100, 1_100)
    activate_normal(q, c)
    cand = candidate(q, c, "explicit-output")
    check("P6 activated candidate accepted", q.submit(cand, c) == "ACCEPTED")
    close = Clock(1_234, q.normal_deadline)
    q.sync(close)
    check("P7 L1 stamps landing block and proof advances EVM height/context",
          q.canonical.canonicalized_at_block == 1_234
          and q.core.state_root == "state:explicit-output"
          and q.core.l2_block_number == 901
          and q.core.next_base_fee == 101)


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
    check("P12 outer sender authorization required", p.admit_message(c, bad) == "REJECTED")
    for i in range(100):
        assert p.admit_message(c, message(1_100, f"m{i}", gas=MIN_FORCE_ACCOUNTED_GAS, size=1)) == "ADMITTED"
    check("P13 per-block count cap", p._prefix_end(0, 100) == 64)
    check("P14 range proof has a fixed bound",
          FORCE_TREE_DEPTH == 64 and MAX_FORCE_RANGE_PROOF_HASHES == 257)
    anchored = protocol(messages=[message(1_100, "a")])
    activate_normal(anchored, c)
    good = candidate(anchored, c, "good")
    forged = replace(good, force_range_proof_ok=False)
    check("P15 skip/reorder proof rejects", anchored.submit(forged, c) == "REJECTED")
    bridge = message(1_100, "bridge", kind=ForceKind.BRIDGE_CREDIT)
    bridge_protocol = protocol()
    check("P16 non-expiring bridge credit admits atomically",
          bridge_protocol.admit_bridge_direct(c, bridge) == "ADMITTED")
    check("P17 gas geometry",
          ANCHOR_GAS_MAX + FORCE_GAS_BUDGET + SYSTEM_GAS_MARGIN
              <= L2_BLOCK_GAS_LIMIT
          and ANCHOR_ACTIVATION_GAS_MAX + ACTIVATION_FORCE_GAS_BUDGET
              + SYSTEM_GAS_MARGIN <= L2_BLOCK_GAS_LIMIT)
    activation_tx = SystemTransactionV2(
        SYSTEM_TX_TYPE, 167_000, SYSTEM_KIND_ANCHOR, 0,
        ANCHOR_ACTIVATION_GAS_MAX, "anchor:v2", 0,
        ANCHOR_ACTIVATION_SELECTOR)
    steady_tx = replace(
        activation_tx, system_nonce=1, gas_limit=ANCHOR_GAS_MAX,
        selector=ANCHOR_STEADY_SELECTOR)
    inbox_tx = replace(
        activation_tx, system_kind=SYSTEM_KIND_INBOX_APPLY,
        gas_limit=INBOX_APPLY_GAS_MAX, to="inbox-apply",
        selector=INBOX_APPLY_SELECTOR)
    check("P17a one unsigned system envelope covers activation and steady Anchor",
          activation_tx.valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000)
          and steady_tx.valid(
              block_number=101, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=False, l2_chain_id=167_000)
          and not replace(activation_tx, signed=True).valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000)
          and not replace(activation_tx, gas_limit=ANCHOR_GAS_MAX).valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000)
          and not activation_tx.valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_001)
          and not activation_tx.valid(
              block_number=100, first_v2_block_number=99,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000))
    system_rules = SystemExecutionRulesV2(
        "system:inbox", "system:inbox", "system:inbox", 0, 0, 0, 0, 0,
        20, 100, 21_000 + 4 * 20 + 16 * 100,
        True, True, True, True)
    check("P17d kind-1 and accountless system execution are fully distinct",
          inbox_tx.valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000)
          and system_rules.valid(inbox_tx)
          and not replace(inbox_tx, signed=True).valid(
              block_number=100, first_v2_block_number=100,
              launch_imported_l2_block_number=99,
              first_activation=True, l2_chain_id=167_000)
          and not replace(
              system_rules, sender_nonce_after=1).valid(inbox_tx))
    activation_backlog = protocol(messages=[
        message(0, f"activation-backlog-{index}", gas=5_000_000)
        for index in range(4)])
    activation_backlog.release_activation_pending = True
    activation_backlog.pending_release_protocol_version = 1
    activation_backlog.pending_release_manifest_hash = "manifest:1"
    activation_clock = clock(1_100, 1_100)
    assert activation_backlog.arm_normal_context(
        clock(1_099, 1_099)) == "ARMED"
    assert activation_backlog.activate_normal_context(
        activation_clock) == "ACTIVATED"
    activation_candidate = candidate(
        activation_backlog, activation_clock, "activation-prefix",
        discretionary=False)
    activation_first = activation_candidate.tip
    activation_second = replace(
        activation_first, slot=activation_first.slot + 1,
        evm_timestamp=activation_first.evm_timestamp + 1,
        block_hash="activation-second", parent_hash=activation_first.block_hash,
        message_start=activation_first.message_end, message_end=4,
        inbox_pre_cursor=activation_first.message_end, inbox_post_cursor=4,
        force_gas_budget=FORCE_GAS_BUDGET, release_activation=False,
        release_protocol_version=0, release_manifest_hash="")
    activation_candidate = replace(
        activation_candidate,
        blocks=(activation_first, activation_second),
        end_l2_block_number=activation_backlog.core.l2_block_number + 2,
        next_due_at=activation_backlog.next_due_at(4, 4))
    activation_end = activation_first.message_end
    invalid_20m_block = replace(
        activation_first, message_end=4, inbox_post_cursor=4,
        force_gas_budget=FORCE_GAS_BUDGET)
    invalid_20m_candidate = replace(
        activation_candidate, blocks=(invalid_20m_block,),
        next_due_at=activation_backlog.next_due_at(4, 4))
    check("P17c activation uses its explicit 13m maximal-prefix budget",
          activation_end == 2
          and activation_backlog._prefix_end(activation_end, 4) == 4
          and not activation_backlog._valid_normal(
              invalid_20m_candidate, activation_clock)
          and activation_backlog.submit(
              activation_candidate, activation_clock) == "ACCEPTED"
          and ANCHOR_ACTIVATION_GAS_MAX
              + sum(row.accounted_gas
                    for row in activation_backlog.messages[:activation_end])
              + SYSTEM_GAS_MARGIN <= L2_BLOCK_GAS_LIMIT)
    too_long = replace(message(1_100, "too-long"),
                       valid_until=c.timestamp + MAX_FORCE_VALIDITY_SECONDS + 1)
    check("P17a user payload validity is bounded",
          protocol().admit_message(c, too_long) == "REJECTED")
    check("P17b depth-64 frontier leaves final index unused",
          MAX_FORCE_QUEUE_ITEMS == (1 << 64) - 1)
    surplus_protocol = protocol(messages=[message(1_100, "forced-surplus")])
    surplus_queue = surplus_protocol.forced_queue
    original_liability = surplus_queue.accounted_liabilities
    check("P17d forced ETH is surplus and cannot DoS queue liabilities",
          surplus_queue.force_eth(1)
          and surplus_queue.accounted_liabilities == original_liability
          and surplus_queue.advance_cursor(
              0, 1, caller="model-settlement", beneficiary="surplus-prover")
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
    check("P19 post-open append admits", p.admit_message(
        append_clock, message(enqueue_l2, "late")) == "ADMITTED")
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
    assert old_anchor.admit_message(enqueue, message(100, "post-anchor")) == "ADMITTED"
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
          unexpired.submit(candidate(unexpired, expired_clock, "missing-bytes"),
                           expired_clock) == "REJECTED")


def test_recovery_refresh_and_historical_immutability() -> None:
    p = protocol(seat=False, messages=[message(0, "forced")])
    trigger = open_recovery(p)
    original = copy.deepcopy(p.recovery)
    parent_before = p.header_oracle.header(original.anchor_number)
    during = clock(trigger.block_number + 1, trigger.l2_slot + 1)
    check("P27 append during recovery admits", p.admit_message(during, message(during.l2_slot, "during")) == "ADMITTED")
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
    newcomer = Generation("new", 101, 1000, ENTRY_DELAY_WINDOWS)
    check("P35 full-table replacement is delayed and strict", registry.admit(newcomer, 0))
    check("P36 deterministic tie victim moves to liability", registry.liabilities[0].registration_index == 1)
    check("P37 displaced generation remains retained", len(registry.active) == 64 and len(registry.liabilities) == 1)
    check("P37a liability generation cannot extend reservations",
          not registry.reserve("builder-1", 1, 0))
    retained = registry.liability_ring[0]
    assert retained is not None
    reuse = Generation("builder-1", 50_000, 9_999,
                       retained[1] + ENTRY_DELAY_WINDOWS)
    check("P37b retained address cannot be reused", not registry.admit(reuse, retained[1]))
    assert registry.release_liability(0, retained[1])
    check("P37c address reuse after safe release gets a new generation",
          registry.admit(reuse, retained[1]))
    low = Generation("low", 1, 1001, ENTRY_DELAY_WINDOWS)
    check("P38 lower bond cannot displace", not registry.admit(low, 0))
    for j in range(3):
        assert registry.admit(Generation(f"high-{j}", 10_000 + j, 2000 + j,
                                         ENTRY_DELAY_WINDOWS), 0)
    check("P39 per-window replacement rate is hard", not registry.admit(
        Generation("fifth", 20_000, 3000, ENTRY_DELAY_WINDOWS), 0))
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
                Generation(f"churn-{serial}", 1_000_000 + serial, serial,
                           window + ENTRY_DELAY_WINDOWS,
                           window + MAX_TRANCHE_AHEAD_WINDOWS),
                window,
            )
    check("P41a max-churn ring reuses only released positions",
          churn.movement_sequence == 4 * (MAX_LIVE_WINDOWS + 1)
          and len(churn.liabilities) == MAX_LIABILITY_GENERATIONS)

    bounded_gate = MigrationGate()
    assert bounded_gate._bootstrap_from_router(1)
    bounded = RegistryLifecycle(
        [Generation("long-lived", 10, 0, 0)], migration_gate=bounded_gate)
    for current_window in range(2_000):
        assert bounded.reserve("long-lived", current_window + 16,
                               current_window)
        assert len(bounded.open_reservations) <= 17
    check("P41b historical reservations enter evidence-safe liability",
          len(bounded.open_reservations) == 17
          and bounded.settle_reservations_before(2_015) == 16
          and len(bounded.open_reservations) == 1)

    churn_gate = MigrationGate()
    assert churn_gate._bootstrap_from_router(1)
    reservation_churn = RegistryLifecycle(
        [Generation(f"seat-{index}", index + 1, index, 0)
         for index in range(64)], migration_gate=churn_gate)
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
    check("P42 session opens", p.open_session(c, "alice", "alice", expiry) == "OPENED")
    check("P43 wrong owner cannot post", p.post_data(c, "alice", "mallory", body_root="x", same_tx_blobhash=True, kzg_opening_ok=True) == "REJECTED")
    check("P44 authenticated chunk posts", p.post_data(c, "alice", "alice", body_root="x", same_tx_blobhash=True, kzg_opening_ok=True) == "POSTED")
    check("P45 immutable seal", p.seal_session(c, "alice", "alice") and p.post_data(c, "alice", "alice", body_root="y", same_tx_blobhash=True, kzg_opening_ok=True) == "REJECTED")
    for i in range(20):
        p.sessions[f"expired-{i:02}"] = DataSession(f"expired-{i:02}", str(i), c.timestamp - 1)
    check("P46 one GC call is bounded", p.gc_sessions(c) <= MAX_GC_STEPS)
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
    assert delayed.open_session(opened, "late-data", "alice", data_expiry) == "OPENED"
    assert delayed.post_data(opened, "late-data", "alice", body_root="body",
                             same_tx_blobhash=True, kzg_opening_ok=True) == "POSTED"
    assert delayed.seal_session(opened, "late-data", "alice")
    activate_normal(delayed, opened)
    base = candidate(delayed, opened, "data-best")
    data_block = replace(base.tip, data_records=(("late-data", 0),))
    with_data = replace(
        base,
        blocks=(data_block,),
        session_refs=(SessionRef("late-data", 1, delayed.sessions["late-data"].root),),
    )
    assert delayed.submit(with_data, opened) == "ACCEPTED"
    after_expiry = Clock(2_000, data_expiry + 1)
    old_tip = delayed.core.tip_hash
    check("P50a delayed close cannot commit expired data",
          delayed.sync(after_expiry) and delayed.core.tip_hash == old_tip)
    delayed.gc_sessions(after_expiry)
    check("P50b GC retained the best until sync cleared it",
          "late-data" not in delayed.sessions)

    bridge_protocol = protocol()
    adapter = BridgeAdapter()
    source = SourceBridgeLedger()
    bridge_envelope = message(4_601, "bridge-record", kind=ForceKind.BRIDGE_CREDIT)
    prepared_clock = clock(1_099, 4_600)
    enqueue_by = prepared_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY

    def open_credit(epoch: int, bridge: str, msg_hash: str,
                    destination: str = "domain:D1", domain: str = "domain:R1",
                    ledger: SourceBridgeLedger = source) -> str:
        credit_id = adapter.credit_id(
            1, domain, epoch, bridge, destination, msg_hash)
        assert ledger.open(
            credit_id, now=prepared_clock.timestamp, enqueue_by=enqueue_by,
            owner="alice", value=10, fee=2,
            destination_domain_id=destination)
        return credit_id

    credit_a = open_credit(7, "bridge:A", "msg")
    credit_b = open_credit(8, "bridge:A", "msg")
    credit_a_reused = open_credit(9, "bridge:A", "msg")
    credit_d2 = open_credit(
        10, "bridge:A", "msg-d2", destination="domain:D2")
    check("P50e permanent source endpoint epochs have distinct identities",
          len({credit_a, credit_b, credit_a_reused}) == 3)
    transition_clock = clock(1_100, 4_601)
    common = dict(
        src_chain_id=1, source_domain_id="domain:R1",
        destination_domain_id="domain:D1", msg_hash="msg",
        enqueue_by=enqueue_by, envelope=bridge_envelope,
        caller="relayer", deposit=5)
    check("P50c router sync persists and fully refunds without an adapter record",
          adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **common) == "SYNCED_REFUNDED"
          and adapter.refunds["relayer"] == 5 and adapter.balance == 5
          and adapter.withdraw_refund("relayer") == 5
          and adapter.balance == 0 and not adapter.records
          and bridge_protocol.mode is Mode.RECOVERY)
    stamped_protocol = protocol(seat=False)
    assert stamped_protocol.migration_gate._bootstrap_from_router(1)
    stamp_status, ingress_stamp = stamped_protocol.sync_ingress(prepared_clock)
    assert ingress_stamp is not None
    assert stamped_protocol.migration_gate._arm_from_manager(
        1, 1, 2, "manifest:2", caller="version-manager")
    check("P50cu payable ingress cannot rerun sync or use a stale stamp",
          stamp_status == "ACTIVE"
          and stamped_protocol.append_from_adapter(
              prepared_clock,
              message(1_100, "stale-stamp", kind=ForceKind.BRIDGE_CREDIT),
              ingress_stamp) == "REJECTED_STALE_STAMP"
          and stamped_protocol.forced_queue.count == 0)
    check("P50d clean retry queues exactly once and funded duplicates reject",
          adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **common) == "QUEUED:0"
          and adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **{**common, "deposit": 0}) == "QUEUED:0"
          and adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **common) == "REJECTED_DUPLICATE_FUNDS"
          and len(bridge_protocol.messages) == 1)
    check("P50g same message from next source epoch queues independently",
          adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=8,
              src_bridge="bridge:A", **common) == "QUEUED:1")
    check("P50h a later permanent-endpoint epoch queues independently",
          adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=9,
              src_bridge="bridge:A", **common) == "QUEUED:2"
          and bridge_protocol.forced_queue.escrow_balance == 15)
    check("P50af pooled payouts cannot consume reserved V2 value",
          not source.ordinary_payout(7)
          and source.ordinary_payout(6)
          and source.balance >= source.total_live_liability)

    domain_credit = open_credit(
        7, "bridge:A", "msg", destination="domain:D2")
    check("P50i destination replacement has a distinct credit identity",
          domain_credit not in {credit_a, credit_b, credit_a_reused})
    check("P50f absent, mismatched, clone and unbounded direct reads reject",
          adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=10,
              src_bridge="clone", **{**common, "msg_hash": "forged"}) == "REJECTED"
          and adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **{**common, "msg_hash": "mismatch",
                                                "source_record_matches": False}) == "REJECTED"
          and adapter.enqueue(
              bridge_protocol, transition_clock, source, src_epoch=7,
              src_bridge="bridge:A", **{**common, "msg_hash": "oversized",
                                                "direct_call_bounded": False}) == "REJECTED")

    invalid_protocol = protocol(tip_slot=100)
    invalid_adapter = BridgeAdapter()
    invalid_source = SourceBridgeLedger()
    invalid_clock = clock(100, 100)
    invalid_id = invalid_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "invalid")
    assert invalid_source.open(
        invalid_id, now=invalid_clock.timestamp,
        enqueue_by=invalid_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
        owner="alice", value=1, fee=1)
    check("P50j static-invalid credit leaves no queue or adapter state",
          invalid_adapter.enqueue(
              invalid_protocol, invalid_clock, invalid_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
              destination_domain_id="domain:D1", msg_hash="invalid",
              enqueue_by=invalid_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
              envelope=replace(
                  bridge_envelope, accounted_gas=MAX_FORCE_MESSAGE_GAS + 1),
              caller="relayer",
              deposit=1) == "REJECTED"
          and not invalid_protocol.messages and not invalid_adapter.records)

    support_core = CanonicalCore(
        100, "block:registration", 100, "state:registration", 0,
        terminal_root="terminal:registration", terminal_count=0)
    shared_queue = QueueContinuity(
        "forced-queue", model_force_root([]), 0, 0, 0, UINT64_MAX)
    support_inbox_apply = InboxApplyRouterV2(next_queue_index=0)
    support_header_oracle = make_header_oracle([])
    support_settlement = VersionedSettlementHistory(
        "settlement:2", "runtime:2", 2, "profile:2",
        copy.deepcopy(support_core), 40, shared_queue,
        inbox_apply_router=support_inbox_apply,
        header_oracle=support_header_oracle)
    support_router = ActiveSettlementRouter(
        "version-manager", shared_queue, support_inbox_apply,
        support_settlement.migration_gate, support_header_oracle)
    assert support_router.bootstrap(
        support_settlement, sequence=7,
        clock=Clock(40, GENESIS_TIMESTAMP + support_core.tip_slot),
        caller=support_router.version_manager)
    support_proof = dict(
        protocol_version=2, canonical_sequence=7, router=support_router,
        proof_state_root="state:registration", mpt_proof_valid=True,
        proved_registration_commitment="registration:manifest:2:D1",
        expected_registration_commitment="registration:manifest:2:D1",
        proof_node_count=4,
        proof_byte_length=2_048)
    support = BridgeDomainRegistry()
    assert not support.stage(
        "domain:R1", "execution:B", "domain:D1", 2, "manifest:2", 100,
        caller_is_version_manager=False, manifest_active=True)
    assert not support.stage(
        "domain:R1", "execution:B", "domain:D1", 2, "manifest:2", 100,
        caller_is_version_manager=True, manifest_active=False)
    assert support.stage(
        "domain:R1", "execution:B", "domain:D1", 2, "manifest:2", 100,
        caller_is_version_manager=True, manifest_active=True)
    assert not support.final(
        "domain:R1", "execution:B", "domain:D1", 1000)
    assert not support.confirm(
        "domain:R1", "execution:B", "domain:D1", 110,
        **{**support_proof, "mpt_proof_valid": False})
    check("P50bf registration proof is bound to routed state and exact bounds",
          not support.confirm(
              "domain:R1", "execution:B", "domain:D1", 110,
              **{**support_proof, "proof_state_root": "attacker-root"})
          and not support.confirm(
              "domain:R1", "execution:B", "domain:D1", 110,
              **{**support_proof,
                 "proof_node_count": MAX_REGISTRATION_PROOF_NODES + 1})
          and not support.confirm(
              "domain:R1", "execution:B", "domain:D1", 110,
              **{**support_proof,
                 "proved_registration_commitment":
                     "registration:manifest:2:substituted"}))
    assert support.confirm(
        "domain:R1", "execution:B", "domain:D1", 110,
        **support_proof)
    check("P50u bridge endpoint support waits for active-profile finality",
          not support.final(
              "domain:R1", "execution:B", "domain:D1",
              110 + SUPPORT_FINALITY_BLOCKS - 1)
          and support.final(
              "domain:R1", "execution:B", "domain:D1",
              110 + SUPPORT_FINALITY_BLOCKS))
    assert support.stage(
        "domain:R1", "execution:B", "domain:D2", 2, "manifest:2", 150,
        caller_is_version_manager=True, manifest_active=True)
    assert support.confirm(
        "domain:R1", "execution:B", "domain:D2", 160,
        **support_proof)
    check("P50an old execution cannot use a new destination before tuple finality",
          not support.final(
              "domain:R1", "execution:B", "domain:D2",
              160 + SUPPORT_FINALITY_BLOCKS - 1)
          and support.final(
              "domain:R1", "execution:B", "domain:D2",
              160 + SUPPORT_FINALITY_BLOCKS))
    bounded_support = BridgeDomainRegistry()
    assert all(bounded_support.stage(
        "domain:R1", f"execution:{i}", "domain:D1", 3, "manifest:3", 200,
        caller_is_version_manager=True, manifest_active=True)
        for i in range(MAX_BRIDGE_TOPOLOGIES_PER_PROFILE))
    check("P50v historical support is immutable and profile additions bounded",
          not support.remove("domain:R1", "execution:B", "domain:D1")
          and support.final(
              "domain:R1", "execution:B", "domain:D1",
              110 + SUPPORT_FINALITY_BLOCKS)
          and not bounded_support.stage(
              "domain:R1", "execution:overflow", "domain:D1", 3,
              "manifest:3", 200, caller_is_version_manager=True,
              manifest_active=True)
          and bounded_support.stage(
              "domain:R2", "execution:new-profile", "domain:D2", 4,
              "manifest:4", 300, caller_is_version_manager=True,
              manifest_active=True))

    frozen_facade = FrozenBridgeFacade(
        "bridge:A", "runtime:frozen", "layout:v2", "verifier:v2")
    check("P50w Bridge facade is bytecode/layout/verifier bound",
          frozen_facade.accepts(
              bridge="bridge:A", runtime_hash="runtime:frozen",
              storage_layout_hash="layout:v2", terminal_verifier="verifier:v2")
          and not frozen_facade.accepts(
              bridge="bridge:A", runtime_hash="runtime:mutated",
              storage_layout_hash="layout:v2", terminal_verifier="verifier:v2"))
    check("P50x frozen facade has no delegated or upgradeable executor",
          frozen_facade.delegate_target() is None
          and not frozen_facade.upgrade("runtime:B"))
    check("P50ao V2 is additive and the legacy send selector stays exact V1",
          source_send_mode("sendMessage(Message)") == "V1"
          and source_send_mode("sendMessageV2(Message)") == "V2_DIRECT"
          and source_send_mode("sendMessageFromVaultV2(Message)")
              == "V2_CAPSULE"
          and source_send_mode("unknown") == "REJECTED")

    capacity_protocol = protocol(tip_slot=100)
    capacity_protocol.queue_capacity = 1
    capacity_clock = clock(101, 101)
    competing_user = replace(
        message(101, "competing-user"), valid_until=GENESIS_TIMESTAMP + 10_000)
    assert capacity_protocol.admit_message(capacity_clock, competing_user) == "ADMITTED"
    capacity_adapter = BridgeAdapter()
    capacity_source = SourceBridgeLedger()
    capacity_id = capacity_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "capacity")
    assert capacity_source.open(
        capacity_id, now=capacity_clock.timestamp,
        enqueue_by=capacity_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
        owner="alice", value=1, fee=1)
    check("P50k capacity loser leaves no partial bridge state",
          capacity_adapter.enqueue(
              capacity_protocol, capacity_clock, capacity_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
              destination_domain_id="domain:D1", msg_hash="capacity",
              enqueue_by=capacity_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
              envelope=bridge_envelope, caller="relayer", deposit=1) == "REJECTED"
          and not capacity_adapter.records)

    bridge_first = protocol(tip_slot=100)
    bridge_first.queue_capacity = 1
    first_adapter = BridgeAdapter()
    first_source = SourceBridgeLedger()
    first_id = first_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "first")
    assert first_source.open(
        first_id, now=capacity_clock.timestamp,
        enqueue_by=capacity_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
        owner="alice", value=1, fee=1)
    check("P50l bridge capacity winner is atomic against later user admission",
          first_adapter.enqueue(
              bridge_first, capacity_clock, first_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
              destination_domain_id="domain:D1", msg_hash="first",
              enqueue_by=capacity_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY,
              envelope=bridge_envelope, caller="relayer", deposit=1) == "QUEUED:0"
          and bridge_first.admit_message(capacity_clock, competing_user) == "REJECTED")

    delayed_protocol = protocol(tip_slot=100)
    delayed_adapter = BridgeAdapter()
    delayed_source = SourceBridgeLedger()
    delayed_start = clock(100, 100)
    delayed_enqueue_by = delayed_start.timestamp + MAX_BRIDGE_ENQUEUE_DELAY
    delayed_id = delayed_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "delayed")
    assert delayed_source.open(
        delayed_id, now=delayed_start.timestamp, enqueue_by=delayed_enqueue_by,
        owner="alice", value=1, fee=1)
    delayed_clock = clock(500, 500)
    check("P50m bridge due time starts at actual queue append",
          delayed_adapter.enqueue(
              delayed_protocol, delayed_clock, delayed_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
              destination_domain_id="domain:D1", msg_hash="delayed",
              enqueue_by=delayed_enqueue_by, envelope=bridge_envelope,
              caller="relayer", deposit=1) == "QUEUED:0"
          and delayed_protocol.messages[0].enqueued_at == delayed_clock.timestamp
          and delayed_protocol.messages[0].due_at
              == delayed_clock.timestamp + FORCE_DELAY
          and not delayed_protocol.force_due(delayed_clock))

    cancel_adapter = BridgeAdapter()
    cancel_source = SourceBridgeLedger()
    cancellation_id = cancel_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "lost-before-enqueue")
    assert cancel_source.open(
        cancellation_id, now=prepared_clock.timestamp, enqueue_by=enqueue_by,
        owner="alice", value=10, fee=2)
    cancel_source.paused = True
    cancel_source.ether_quota = 0
    check("P50y pre-enqueue data loss has a permissionless exact-deadline refund",
          not cancel_source.cancel(
              cancellation_id, now=enqueue_by)
          and cancel_source.cancel(
              cancellation_id, now=enqueue_by + 1)
          and cancel_source.refunds["alice"] == 12
          and not cancel_source.ordinary_payout(1)
          and cancel_source.withdraw_refund("alice") == 12
          and cancel_source.balance == cancel_source.total_live_liability == 0)
    check("P50ap V2 ETH restoration bypasses exhausted ordinary quota",
          cancel_source.ether_quota == 0
          and cancel_source.balance == 0)
    no_sync_protocol = protocol(tip_slot=enqueue_by - GENESIS_TIMESTAMP)
    check("P50z cancel wins the race and permanently rejects enqueue",
          cancel_adapter.enqueue(
              no_sync_protocol, Clock(2_000, enqueue_by + 1), cancel_source,
              src_chain_id=1, source_domain_id="domain:R1", src_epoch=1,
              src_bridge="bridge:A", destination_domain_id="domain:D1",
              msg_hash="lost-before-enqueue", enqueue_by=enqueue_by,
              envelope=bridge_envelope, caller="relayer", deposit=1) == "REJECTED")

    queued_race_adapter = BridgeAdapter()
    queued_race_source = SourceBridgeLedger()
    queued_race_id = queued_race_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "enqueue-wins")
    assert queued_race_source.open(
        queued_race_id, now=prepared_clock.timestamp, enqueue_by=enqueue_by,
        owner="alice", value=10, fee=2)
    race_protocol = protocol(tip_slot=enqueue_by - GENESIS_TIMESTAMP)
    check("P50aa enqueue at the deadline wins against later cancellation",
          queued_race_adapter.enqueue(
              race_protocol, Clock(2_001, enqueue_by), queued_race_source,
              src_chain_id=1, source_domain_id="domain:R1", src_epoch=1,
              src_bridge="bridge:A", destination_domain_id="domain:D1",
              msg_hash="enqueue-wins", enqueue_by=enqueue_by,
              envelope=bridge_envelope, caller="relayer", deposit=1) == "QUEUED:0"
          and not queued_race_source.cancel(
              queued_race_id, now=enqueue_by + 1))
    replacement_adapter = BridgeAdapter()
    check("P50ag adapter replacement cannot double-refund a queued credit",
          queued_race_id not in replacement_adapter.records
          and queued_race_source.credits[queued_race_id].status == "QUEUED"
          and not queued_race_source.cancel(
              queued_race_id, now=enqueue_by + 2))

    capsule_source = SourceBridgeLedger()
    capsule_id = adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "capsule")
    assert capsule_source.open(
        capsule_id, now=prepared_clock.timestamp, enqueue_by=enqueue_by,
        owner="alice", value=3, fee=1, refund_vault="erc721-vault",
        refund_mode="CAPSULE", caller="erc721-vault")
    check("P50az V2 refund mode is selector-explicit and cannot be inferred",
          not SourceBridgeLedger().open(
              "ambiguous", now=prepared_clock.timestamp, enqueue_by=enqueue_by,
              owner="alice", value=3, fee=1, refund_vault="erc721-vault")
          and not SourceBridgeLedger().open(
              "spoofed", now=prepared_clock.timestamp, enqueue_by=enqueue_by,
              owner="alice", value=3, fee=1, refund_vault="erc721-vault",
              refund_mode="CAPSULE", caller="attacker"))
    refund_vault = RefundVaultLedger(balance=100)
    assert refund_vault.register(
        capsule_id, owner="alice", amount=40, capsule_hash="capsule-hash",
        calldata_hash_matches=True)
    check("P50ah immutable authorization and mutable capsule finalize exactly once",
          capsule_source.credits[capsule_id].status == "DRAFT"
          and not capsule_source.finalize_capsule(
              capsule_id, caller="attacker", capsule_hash="capsule-hash",
              vault_has_matching_capsule=True)
          and capsule_source.finalize_capsule(
              capsule_id, caller="erc721-vault", capsule_hash="capsule-hash",
              vault_has_matching_capsule=True)
          and capsule_source.credits[capsule_id].status == "NEW"
          and not capsule_source.finalize_capsule(
              capsule_id, caller="erc721-vault", capsule_hash="capsule-hash",
              vault_has_matching_capsule=True))
    check("P50ak token reserve blocks pooled drain and capsule mismatch",
          not refund_vault.ordinary_payout(61)
          and not refund_vault.register(
              "bad", owner="alice", amount=1, capsule_hash="bad",
              calldata_hash_matches=False))
    assert capsule_source.cancel(capsule_id, now=enqueue_by + 1)
    refund_vault.token_quota = 0
    check("P50ai failed token delivery does not roll back terminal source state",
          not refund_vault.claim_refund(
              capsule_id, caller="alice", source=capsule_source,
              transfer_succeeds=False)
          and capsule_source.credits[capsule_id].status == "CANCELLED"
          and refund_vault.claim_refund(
              capsule_id, caller="alice", source=capsule_source)
          and refund_vault.balance == 60 and refund_vault.reserved == 0
          and refund_vault.token_quota == 0)
    check("P50aq reserved token restoration bypasses ordinary token quota",
          refund_vault.token_quota == 0 and refund_vault.reserved == 0)
    restorable_token = RefundRestorableToken("erc721-vault", paused=True)
    check("P50au frozen bridged-token restoration bypasses token pause exactly once",
          restorable_token.restore(
              capsule_id, caller="erc721-vault", capsule_matches=True)
          and not restorable_token.restore(
              capsule_id, caller="erc721-vault", capsule_matches=True)
          and not restorable_token.restore(
              "other", caller="attacker", capsule_matches=True))

    inbox_store = InboxCreditStoreV2(
        "inbox-apply", "bridge:A", "domain:D1")
    inbox_apply_router = InboxApplyRouterV2(next_queue_index=70)
    accumulator = TerminalAccumulatorV2({})
    release_authority = ProtocolReleaseAuthorityV2()
    registrar = TerminalDomainRegistrarV2(
        release_authority, accumulator, inbox_apply_router)
    manifest_v1 = release_manifest_fixture(
        1, "domain:D1", "bridge:A", inbox_store, legacy_proxy=True)
    anchor_v1 = AnchorV4Model(
        manifest_v1.anchor, manifest_v1.anchor_runtime_hash,
        manifest_v1.commitment)
    endpoint_v1 = EndpointActivationStateV2(
        legacy_v1_state_fingerprint="custody-and-status-v1:D1")
    legacy_bridge_v1 = BridgeDeploymentStateV2(
        "GENESIS_LEGACY_PROXY", manifest_v1.destination_bridge,
        manifest_v1.components[8].runtime_hash,
        "implementation:bridge:A",
        manifest_v1.destination_bridge_descriptor.facade_runtime_hash,
        direct_prestate_slot_constraint=True,
        upgrade_authority_burned=True,
        delegate_target_reachable=True)
    check("P50ca direct reserved-sender and Bridge release calls are rejected",
          not release_authority.activate(
              manifest_v1,
              caller=AnchorV4Model(
                  "system:anchor", "code:system:anchor",
                  manifest_v1.commitment, manifest_v1.commitment),
              tx_origin="system:anchor")
          and not release_authority.activate(
              manifest_v1,
              caller=AnchorV4Model(
                  "bridge:A", "code:bridge:A", manifest_v1.commitment,
                  manifest_v1.commitment),
              tx_origin="system:anchor"))
    check("P50cc Anchor release and registrar seal are one atomic system trace",
          activate_release_transaction(
              release_authority, registrar, manifest=manifest_v1,
              transaction_sender="system:anchor", anchor=anchor_v1,
              store=inbox_store, endpoint_state=endpoint_v1,
              bridge_deployment=legacy_bridge_v1)
          and endpoint_v1.gate_active
          and endpoint_v1.legacy_v1_state_fingerprint
              == "custody-and-status-v1:D1")
    failed_store = InboxCreditStoreV2(
        "inbox-apply", "bridge:C", "domain:D3")
    manifest_v3 = release_manifest_fixture(
        3, "domain:D3", "bridge:C", failed_store)
    anchor_v3 = AnchorV4Model(
        manifest_v3.anchor, manifest_v3.anchor_runtime_hash,
        manifest_v3.commitment)
    check("P50cd a failed registrar seal rolls release authority back",
          not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v3,
              transaction_sender="system:anchor", anchor=anchor_v3,
              store=failed_store,
              direct_component_checks_succeed=False)
          and 3 not in release_authority.releases
          and 3 not in registrar.registrations
          and "domain:D3" not in inbox_apply_router.routes)
    cross_chain_store = InboxCreditStoreV2(
        "inbox-apply", "bridge:D", "domain:D4")
    local_code_store = InboxCreditStoreV2(
        "inbox-apply", "bridge:E", "domain:D5")
    manifest_v4 = release_manifest_fixture(
        4, "domain:D4", "bridge:D", cross_chain_store)
    manifest_v5 = release_manifest_fixture(
        5, "domain:D5", "bridge:E", local_code_store)
    bad_l1_anchor = AnchorV4Model(
        manifest_v4.anchor, manifest_v4.anchor_runtime_hash,
        "manifest:foreign")
    anchor_v5 = AnchorV4Model(
        manifest_v5.anchor, manifest_v5.anchor_runtime_hash,
        manifest_v5.commitment)
    mismatched_l2 = list(manifest_v5.components[3:])
    mismatched_l2[1] = replace(mismatched_l2[1], runtime_hash="code:mutated")
    check("P50ci registrar requires proved L1 bindings and direct L2 code checks",
          not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v4,
              transaction_sender="system:anchor", anchor=bad_l1_anchor,
              store=cross_chain_store)
          and not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v5,
              transaction_sender="system:anchor", anchor=anchor_v5,
              store=local_code_store,
              observed_l2_components=tuple(mismatched_l2))
          and 4 not in release_authority.releases
          and 5 not in release_authority.releases)
    destination = DestinationBridgeLedger(
        inbox_store=inbox_store, terminal_accumulator=accumulator)
    pin_now = prepared_clock.timestamp
    assert destination.pin(
        credit_a, "result:A", now=pin_now, caller_is_inbox_apply=True)
    process_by = inbox_store.pins[credit_a].process_by
    check("P50ab inbox pin and deadline live in the immutable V2 store",
          inbox_store.pins[credit_a]
              == InboxPin("result:A", pin_now + BRIDGE_PROCESS_TTL_SECONDS)
          and inbox_store.read(
              credit_a, caller="bridge:B",
              destination_domain_id="domain:D1") is None)
    clone = DestinationBridgeLedger(
        address="bridge:B", local_domain_id="domain:D2",
        inbox_store=inbox_store, terminal_accumulator=accumulator)
    check("P50ar destination context cannot replay across funded Bridges",
          clone.process(
              credit_a, now=pin_now + 1, message_available=True,
              result_hash_matches=True, callback_ok=True,
              destination_domain_id="domain:D1",
              context_dest_bridge="bridge:A") == "REJECTED"
          and credit_a not in clone.terminal_index)
    assert destination.process(
        credit_a, now=pin_now + 1, message_available=False,
        result_hash_matches=True, callback_ok=True) == "RETRIABLE"
    check("P50bb Bridge authority cannot be confused by a message callback",
          accumulator.append_terminal(
              caller=destination, credit_id=credit_a) is None
          and destination.accepts_message_target(
              "terminal-accumulator", version="V1")
          and not destination.accepts_message_target(
              "terminal-accumulator", version="V2"))
    destination.paused = True
    check("P50ac lost post-pin Message becomes permissionlessly FAILED",
          not destination.expire(credit_a, now=process_by)
          and destination.expire(credit_a, now=process_by + 1)
          and destination.status[credit_a] == "FAILED"
          and destination.process(
              credit_a, now=process_by + 2, message_available=True,
              result_hash_matches=True, callback_ok=True) == "REJECTED")
    destination.paused = False
    assert destination.pin(
        credit_b, "result:B", now=pin_now, caller_is_inbox_apply=True)
    check("P50ad DONE is terminal and conflicting pins fail",
          destination.process(
              credit_b, now=pin_now + 1, message_available=True,
              result_hash_matches=True, callback_ok=True) == "DONE"
          and not destination.expire(
              credit_b, now=pin_now + BRIDGE_PROCESS_TTL_SECONDS + 1)
          and not destination.pin(
              credit_b, "conflict", now=pin_now,
              caller_is_inbox_apply=True))
    check("P50ae terminal leaves bind index, domain, Bridge, credit and result",
          TerminalSignalVerifier.terminal_leaf(
              0, "domain:D1", "bridge:A", credit_a, "FAILED")
              != TerminalSignalVerifier.terminal_leaf(
                  0, "domain:D2", "bridge:A", credit_a, "FAILED")
          and TerminalSignalVerifier.terminal_leaf(
              0, "domain:D1", "bridge:A", credit_b, "DONE")
              != TerminalSignalVerifier.terminal_leaf(
              0, "domain:D1", "bridge:A", credit_b, "FAILED"))
    malformed_terminal = DestinationBridgeLedger(
        inbox_store=InboxCreditStoreV2(
            "inbox-apply", "bridge:A", "domain:D1"),
        terminal_accumulator=accumulator)
    malformed_credit = "credit:malformed-terminal-return"
    assert malformed_terminal.pin(
        malformed_credit, "result:malformed", now=pin_now,
        caller_is_inbox_apply=True)
    count_before_malformed = accumulator.count
    malformed_terminal.terminal_commitment_return_length = 96
    short_terminal_rejected = malformed_terminal.process(
        malformed_credit, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True) == "REJECTED"
    malformed_terminal.terminal_commitment_return_length = 160
    long_terminal_rejected = malformed_terminal.process(
        malformed_credit, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True) == "REJECTED"
    malformed_terminal.terminal_commitment_return_length = 128
    malformed_terminal.terminal_commitment_gas_ok = False
    oog_terminal_rejected = malformed_terminal.process(
        malformed_credit, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True) == "REJECTED"
    malformed_terminal.terminal_commitment_gas_ok = True
    accumulator.append_return_length = 31
    short_append_rejected = malformed_terminal.process(
        malformed_credit, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True) == "REJECTED"
    accumulator.append_return_length = 33
    long_append_rejected = malformed_terminal.process(
        malformed_credit, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True) == "REJECTED"
    accumulator.append_return_length = 32
    check("P50ck malformed or OOG terminal commitment returndata is atomic",
          short_terminal_rejected and long_terminal_rejected
          and oog_terminal_rejected
          and short_append_rejected and long_append_rejected
          and malformed_terminal.status[malformed_credit] == "NEW"
          and malformed_credit not in malformed_terminal.terminal_index
          and accumulator.count == count_before_malformed)
    inbox_store_d2 = InboxCreditStoreV2(
        "inbox-apply", "bridge:B", "domain:D2")
    manifest_v2 = release_manifest_fixture(
        2, "domain:D2", "bridge:B", inbox_store_d2)
    anchor_v2 = AnchorV4Model(
        manifest_v2.anchor, manifest_v2.anchor_runtime_hash,
        manifest_v2.commitment)
    endpoint_v2 = EndpointActivationStateV2(
        legacy_v1_state_fingerprint="custody-and-status-v1:D2")
    preserved_routes = dict(inbox_apply_router.routes)
    preserved_releases = dict(release_authority.releases)
    preserved_domains = dict(accumulator.domains)
    preserved_root = accumulator.root
    preserved_count = accumulator.count
    check("P50ax new terminal domains cannot redirect an old domain writer",
          not accumulator.register_domain(
              "domain:squat", "bridge:squat", caller="attacker",
              release_active=True, descriptor_valid=True,
              activation_order_valid=True)
          and activate_release_transaction(
              release_authority, registrar, manifest=manifest_v2,
              transaction_sender="system:anchor", anchor=anchor_v2,
              store=inbox_store_d2, endpoint_state=endpoint_v2)
          and all(inbox_apply_router.routes[key] == value
                  for key, value in preserved_routes.items())
          and all(release_authority.releases[key] == value
                  for key, value in preserved_releases.items())
          and all(accumulator.domains[key] == value
                  for key, value in preserved_domains.items())
          and accumulator.root == preserved_root
          and accumulator.count == preserved_count
          and endpoint_v2.gate_active
          and endpoint_v2.legacy_v1_state_fingerprint
              == "custody-and-status-v1:D2"
          and accumulator.register_domain(
              "domain:D1", "bridge:A", caller="terminal-domain-registrar",
              release_active=True, descriptor_valid=True,
              activation_order_valid=True)
          and not accumulator.register_domain(
              "domain:D1", "bridge:B", caller="terminal-domain-registrar",
              release_active=True, descriptor_valid=True,
              activation_order_valid=True)
          and not accumulator.register_domain(
              "domain:D3", "bridge:A", caller="terminal-domain-registrar",
              release_active=True, descriptor_valid=True,
              activation_order_valid=True)
          and not accumulator.register_domain(
              "domain:D4", "bridge:D", caller="terminal-domain-registrar",
              release_active=True, descriptor_valid=True,
              activation_order_valid=False)
          and accumulator.domains["domain:D1"] == "bridge:A")
    reused_endpoint_state = copy.deepcopy(endpoint_v2)
    manifest_v7 = release_manifest_fixture(
        7, "domain:D2", "bridge:B", inbox_store_d2)
    partial_endpoint_state = copy.deepcopy(endpoint_v2)
    partial_endpoint_state.gate_sealer_live = True
    store_v6 = InboxCreditStoreV2(
        "inbox-apply", "bridge:F", "domain:D6")
    manifest_v6 = release_manifest_fixture(
        6, "domain:D6", "bridge:F", store_v6)
    check("P50co exact endpoint reuse skips seals; partial prestate rejects",
          activate_release_transaction(
              release_authority, registrar, manifest=manifest_v7,
              transaction_sender="system:anchor",
              anchor=AnchorV4Model(
                  manifest_v7.anchor, manifest_v7.anchor_runtime_hash,
                  manifest_v7.commitment), store=inbox_store_d2,
              endpoint_state=reused_endpoint_state)
          and not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v6,
              transaction_sender="system:anchor",
              anchor=AnchorV4Model(
                  manifest_v6.anchor, manifest_v6.anchor_runtime_hash,
                  manifest_v6.commitment), store=store_v6,
              endpoint_state=partial_endpoint_state)
          and 6 not in release_authority.releases)
    store_v8 = InboxCreditStoreV2(
        "inbox-apply", "bridge:G", "domain:D8")
    manifest_v8 = release_manifest_fixture(
        8, "domain:D8", "bridge:G", store_v8, legacy_proxy=True)
    delegated_proxy_lie = BridgeDeploymentStateV2(
        "GENESIS_LEGACY_PROXY", manifest_v8.destination_bridge,
        manifest_v8.components[8].runtime_hash,
        "implementation:attacker",
        manifest_v8.destination_bridge_descriptor.facade_runtime_hash,
        direct_prestate_slot_constraint=False,
        upgrade_authority_burned=True,
        delegate_target_reachable=True)
    check("P50cp chain IDs, Bridge preimages and topology are authenticated",
          not replace(
              manifest_v6,
              destination_chain_id=UINT64_MAX + 1).structurally_valid()
          and not replace(
              manifest_v6,
              destination_bridge_descriptor=replace(
                  manifest_v6.destination_bridge_descriptor,
                  facade_runtime_hash="attacker-facade")).structurally_valid()
          and not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v6,
              transaction_sender="system:anchor",
              anchor=AnchorV4Model(
                  manifest_v6.anchor, manifest_v6.anchor_runtime_hash,
                  manifest_v6.commitment), store=store_v6,
              observed_bridge_descriptor=replace(
                  manifest_v6.destination_bridge_descriptor,
                  facade_runtime_hash="observed-attacker-facade"))
          and not activate_release_transaction(
              release_authority, registrar, manifest=manifest_v8,
              transaction_sender="system:anchor",
              anchor=AnchorV4Model(
                  manifest_v8.anchor, manifest_v8.anchor_runtime_hash,
                  manifest_v8.commitment), store=store_v8,
              bridge_deployment=delegated_proxy_lie)
          and 8 not in release_authority.releases)
    destination_d2 = DestinationBridgeLedger(
        address="bridge:B", local_domain_id="domain:D2",
        inbox_store=inbox_store_d2, terminal_accumulator=accumulator)
    assert source.mark_queued(
        credit_d2, 99, caller_is_bound_adapter=True)
    assert destination_d2.pin(
        credit_d2, "result:D2", now=pin_now,
        caller_is_inbox_apply=True)
    assert destination_d2.process(
        credit_d2, now=pin_now + 1, message_available=True,
        result_hash_matches=True, callback_ok=True,
        destination_domain_id="domain:D2",
        context_dest_bridge="bridge:B") == "DONE"
    def bridge_inbox_row(index: int, domain_id: str,
                         credit_id: str) -> tuple[int, int, int, str, bytes]:
        return (index, 5, UINT32_MAX,
                inbox_kind1_result(index, domain_id, credit_id),
                inbox_kind1_descriptor(domain_id, credit_id))

    mixed_rows = (
        bridge_inbox_row(70, "domain:D1", "credit:D1:late"),
        bridge_inbox_row(71, "domain:D2", "credit:D2:new"),
        bridge_inbox_row(72, "domain:D1", "credit:D1:later"),
    )
    check("P50be old and new endpoint credits cannot wedge the shared FIFO",
          inbox_apply_router.apply(
              70, mixed_rows, now=pin_now, l2_block_number=1,
              caller_is_system_sender=True)
          and "credit:D1:late" in inbox_store.pins
          and "credit:D2:new" in inbox_store_d2.pins
          and not inbox_apply_router.apply(
              73,
              (bridge_inbox_row(73, "domain:D1", "credit:staged"),
               bridge_inbox_row(74, "domain:missing", "credit:missing")),
              now=pin_now, l2_block_number=2, caller_is_system_sender=True)
          and "credit:staged" not in inbox_store.pins
          and inbox_apply_router.next_queue_index == 73
          and not inbox_apply_router.register_route(
              "domain:D1", inbox_store_d2, "bridge:B", "codehash:store:D2",
              caller="terminal-domain-registrar", manifest_exact=True))
    original_d1_codehash = inbox_store.runtime_codehash
    inbox_store.runtime_codehash = "codehash:mutated"
    check("P50ce inbox routes recheck code before any pin write",
          not inbox_apply_router.apply(
              73, (bridge_inbox_row(
                  73, "domain:D1", "credit:code-mismatch"),),
              now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and "credit:code-mismatch" not in inbox_store.pins
          and inbox_apply_router.next_queue_index == 73)
    inbox_store.runtime_codehash = original_d1_codehash
    original_d1_bridge = inbox_store.destination_bridge
    inbox_store.destination_bridge = "bridge:mutated"
    check("P50cg inbox routes recheck immutable config before any pin write",
          not inbox_apply_router.apply(
              73, (bridge_inbox_row(
                  73, "domain:D1", "credit:config-mismatch"),),
              now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and "credit:config-mismatch" not in inbox_store.pins
          and inbox_apply_router.next_queue_index == 73)
    inbox_store.destination_bridge = original_d1_bridge
    inbox_store_d2.batch_return_data = b""
    check("P50cf a later contiguous-run failure rolls earlier pins back",
          not inbox_apply_router.apply(
              73,
              (bridge_inbox_row(73, "domain:D1", "credit:rolled-back"),
               bridge_inbox_row(74, "domain:D2", "credit:failing-run")),
              now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and "credit:rolled-back" not in inbox_store.pins
          and "credit:failing-run" not in inbox_store_d2.pins
          and inbox_apply_router.next_queue_index == 73)
    inbox_store_d2.batch_return_data = INBOX_BATCH_OK_V2_WORD
    inbox_store.batch_return_data = INBOX_BATCH_OK_V2_WORD[:-1]
    short_return_rejected = not inbox_apply_router.apply(
        73, (bridge_inbox_row(
            73, "domain:D1", "credit:short-return"),),
        now=pin_now, l2_block_number=2, caller_is_system_sender=True)
    inbox_store.batch_return_data = INBOX_BATCH_OK_V2_WORD + b"\x00"
    check("P50cj short and trailing inbox returndata fail closed",
          short_return_rejected
          and not inbox_apply_router.apply(
              73, (bridge_inbox_row(
                  73, "domain:D1", "credit:long-return"),),
              now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and "credit:short-return" not in inbox_store.pins
          and "credit:long-return" not in inbox_store.pins
          and inbox_apply_router.next_queue_index == 73)
    inbox_store.batch_return_data = INBOX_BATCH_OK_V2_WORD
    inbox_store.batch_writes_enabled = False
    check("P50cl magic-returning no-op store cannot advance the inbox cursor",
          not inbox_apply_router.apply(
              73, (bridge_inbox_row(
                  73, "domain:D1", "credit:no-op-store"),),
              now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and "credit:no-op-store" not in inbox_store.pins
          and inbox_apply_router.next_queue_index == 73)
    inbox_store.batch_writes_enabled = True
    check("P50bh empty InboxApply is canonical and once per L2 block",
          inbox_apply_router.apply(
              73, (), now=pin_now, l2_block_number=2,
              caller_is_system_sender=True)
          and inbox_apply_router.next_queue_index == 73
          and not inbox_apply_router.apply(
              73, (), now=pin_now, l2_block_number=2,
              caller_is_system_sender=True))
    manual_credit = "credit:manual-failure"
    assert destination.pin(
        manual_credit, "result:C", now=pin_now, caller_is_inbox_apply=True)
    check("P50al observers cannot force early failure or last-attempt retry",
          not destination.manual_fail(
              manual_credit, caller_is_dest_owner=True)
          and destination.process(
              manual_credit, now=pin_now + 1, message_available=True,
              result_hash_matches=True, callback_ok=False) == "RETRIABLE"
          and not destination.manual_fail(
              manual_credit, caller_is_dest_owner=False)
          and destination.retry(
              manual_credit, now=pin_now + 2, caller_is_dest_owner=False,
              is_last_attempt=True, message_available=True,
              result_hash_matches=True, callback_ok=True) == "REJECTED")
    destination.paused = True
    check("P50am manual failure is pausable but expiry is not",
          not destination.manual_fail(
              manual_credit, caller_is_dest_owner=True)
          and destination.expire(
              manual_credit,
              now=pin_now + BRIDGE_PROCESS_TTL_SECONDS + 1))
    destination.paused = False
    source.paused = True
    canonical_core_499 = CanonicalCore(
        499, "block:499", 499, "state:499", 12,
        winning_data_commitment="data:499", next_base_fee=100,
        next_excess_blob_gas=2, terminal_root=accumulator.root,
        terminal_count=accumulator.count)
    initial_queue_descriptors = [
        replace(message(0, f"preserved-{index}"), due_at=1_001_500)
        for index in range(17)]
    terminal_queue = QueueContinuity(
        "forced-queue", model_force_root(initial_queue_descriptors),
        17, 12, 17, 1_001_500, initial_queue_descriptors,
        claimable={"historical-prover": 12})
    migration_inbox_apply = InboxApplyRouterV2(next_queue_index=12)
    shared_migration_gate = MigrationGate()
    migration_header_oracle = make_header_oracle(initial_queue_descriptors)
    settlement_1 = VersionedSettlementHistory(
        "settlement:1", "runtime:1", 1, "profile:1",
        copy.deepcopy(canonical_core_499), 49, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle)
    active_router = ActiveSettlementRouter(
        "version-manager", terminal_queue, migration_inbox_apply,
        shared_migration_gate, migration_header_oracle)
    assert active_router.bootstrap(
        settlement_1, sequence=0,
        clock=Clock(49, GENESIS_TIMESTAMP + canonical_core_499.tip_slot),
        caller=active_router.version_manager)
    migration_protocol = protocol(
        tip_slot=canonical_core_499.tip_slot,
        cursor=canonical_core_499.message_cursor,
        seat=False,
        forced_queue=terminal_queue,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle,
        migration_gate=shared_migration_gate,
        settlement_address="settlement:1")
    migration_protocol.canonical = Canonical(
        copy.deepcopy(canonical_core_499), 49)
    migration_protocol.first_v2_block_number = 1
    migration_protocol.versioned_history = settlement_1
    settlement_1.live_protocol = migration_protocol
    assert active_router.sync_and_append(
        message(1, "old-adapter-row", kind=ForceKind.BRIDGE_CREDIT),
        clock=Clock(49, GENESIS_TIMESTAMP + 1),
        bound_router=active_router.address,
        queue_address=terminal_queue.address,
        deposit=7) == "QUEUED:17"
    canonical_core_500 = replace(
        canonical_core_499, l2_block_number=500, tip_hash="block:500",
        state_root="state:500")
    migration_protocol.canonical = Canonical(copy.deepcopy(canonical_core_500), 50)
    sequence_1 = settlement_1._record_canonical_from_protocol(
        protocol=migration_protocol, clock=Clock(50, GENESIS_TIMESTAMP + 2))
    assert sequence_1 == 1
    canonical_500 = active_router.canonical_at(1, sequence_1)
    assert canonical_500 is not None
    same_block_history = copy.deepcopy(settlement_1.history)
    same_block_core = copy.deepcopy(settlement_1.core)
    check("P50at canonical history is internal and one commit per L1 block",
          not hasattr(settlement_1, "record_canonical")
          and settlement_1._record_canonical_from_protocol(
              protocol=migration_protocol,
              clock=Clock(50, GENESIS_TIMESTAMP + 3)) is None
          and settlement_1.history == same_block_history
          and settlement_1.core == same_block_core
          and active_router.canonical_at(1, sequence_1) == canonical_500)
    canonical_core_756 = replace(
        canonical_core_500, l2_block_number=756, tip_hash="block:756",
        state_root="state:756")
    migration_protocol.canonical = Canonical(copy.deepcopy(canonical_core_756), 51)
    sequence_2 = settlement_1._record_canonical_from_protocol(
        protocol=migration_protocol, clock=Clock(51, GENESIS_TIMESTAMP + 4))
    assert sequence_2 == 2
    canonical_756 = active_router.canonical_at(1, sequence_2)
    assert canonical_756 is not None
    check("P50av sparse L2-height jumps cannot choose a history cell",
          active_router.canonical_at(1, sequence_1) == canonical_500
          and active_router.canonical_at(1, sequence_2) == canonical_756)
    migration_protocol.canonical = Canonical(
        copy.deepcopy(canonical_core_756), 51)
    migration_registry = RegistryLifecycle(
        [Generation("migration-builder" if index == 0
                    else f"migration-builder-{index}", 10, index, 0)
         for index in range(64)],
        migration_gate=shared_migration_gate)
    migration_open_clock = clock(180, 100)
    assert migration_protocol.open_session(
        migration_open_clock, "migration-session", "alice",
        migration_open_clock.timestamp + DATA_TTL_SECONDS) == "OPENED"
    for generation in migration_registry.active:
        for window in range(MAX_TRANCHE_AHEAD_WINDOWS + 1):
            assert migration_registry.reserve(
                generation.address, window, 0)
    migration_reservations_before = frozenset(
        migration_registry.open_reservations)
    assert len(migration_reservations_before) == MAX_LIVE_RESERVATIONS
    migration_outage_clock = clock(181, 4_000)
    check("P50cq router ingress is immediately visible to forced liveness",
          migration_protocol.forced_queue is terminal_queue
          and terminal_queue.count == len(migration_protocol.messages) == 18
          and terminal_queue.root
              == migration_protocol.force_root(terminal_queue.count)
          and migration_protocol.next_due_at(12) == 1_001_500
          and migration_protocol.force_due(migration_outage_clock))
    forged_root_protocol = protocol(messages=[message(0, "root-bound")])
    forged_root_protocol.forced_queue.root = "attacker-root"
    forged_root_rejected = False
    try:
        forged_root_protocol.force_root(1)
    except AssertionError:
        forged_root_rejected = True
    unauthorized_queue = QueueContinuity(
        "auth-queue", model_force_root([]), 0, 0, 0, 0)
    check("P50cr stored and snapshotted forced roots cannot diverge",
          forged_root_rejected
          and unauthorized_queue.append(
              message(0, "unauthorized-append"), deposit=1,
              due_at=GENESIS_TIMESTAMP + FORCE_DELAY,
              caller="attacker") is None
          and unauthorized_queue.count == 0
          and unauthorized_queue.root == model_force_root([]))

    atomic_protocol = protocol(messages=[message(0, "atomic-row")])
    atomic_history = VersionedSettlementHistory(
        "model-settlement", "runtime:atomic", 1, "profile:atomic",
        copy.deepcopy(atomic_protocol.core), 99,
        atomic_protocol.forced_queue, mode="ACTIVE", current_sequence=0,
        last_canonical_l1_block=100,
        migration_gate=atomic_protocol.migration_gate,
        live_protocol=atomic_protocol,
        inbox_apply_router=atomic_protocol.inbox_apply_router)
    atomic_protocol.versioned_history = atomic_history
    atomic_clock = clock(100, 1_100)
    atomic_candidate = candidate(atomic_protocol, atomic_clock, "atomic")
    atomic_queue = atomic_protocol.forced_queue
    atomic_inbox = atomic_protocol.inbox_apply_router
    atomic_gate = atomic_protocol.migration_gate
    atomic_history_before = (
        copy.deepcopy(atomic_history.core),
        atomic_history.canonicalized_at_block,
        atomic_history.current_sequence,
        atomic_history.last_canonical_l1_block,
        copy.deepcopy(atomic_history.history),
        copy.deepcopy(atomic_queue),
        copy.deepcopy(atomic_inbox),
        copy.deepcopy(atomic_gate),
    )
    atomic_before = (
        copy.deepcopy(atomic_protocol.canonical),
        atomic_protocol.forced_queue.cursor,
        atomic_protocol.inbox_apply_router.next_queue_index,
        atomic_protocol.release_activation_pending,
    )
    atomic_rejected = False
    try:
        atomic_protocol._commit(atomic_candidate, atomic_clock)
    except AssertionError:
        atomic_rejected = True
    check("P50cs late history rejection rolls every canonical stage back",
          atomic_rejected
          and atomic_protocol.canonical == atomic_before[0]
          and atomic_protocol.forced_queue.cursor == atomic_before[1]
          and atomic_protocol.inbox_apply_router.next_queue_index
              == atomic_before[2]
          and atomic_protocol.release_activation_pending == atomic_before[3]
          and atomic_history.core == atomic_history_before[0]
          and atomic_history.canonicalized_at_block == atomic_history_before[1]
          and atomic_history.current_sequence == atomic_history_before[2]
          and atomic_history.last_canonical_l1_block == atomic_history_before[3]
          and atomic_history.history == atomic_history_before[4]
          and atomic_queue == atomic_history_before[5]
          and atomic_inbox == atomic_history_before[6]
          and atomic_gate == atomic_history_before[7]
          and atomic_protocol.versioned_history is atomic_history
          and atomic_protocol.forced_queue is atomic_queue
          and atomic_protocol.inbox_apply_router is atomic_inbox
          and atomic_protocol.migration_gate is atomic_gate
          and atomic_history.forced_queue is atomic_queue
          and atomic_history.inbox_apply_router is atomic_inbox
          and atomic_history.migration_gate is atomic_gate
          and atomic_history.live_protocol is atomic_protocol)
    assert migration_protocol.sync(migration_outage_clock)
    assert migration_protocol.mode is Mode.RECOVERY
    migration_revision = migration_protocol.recovery.revision
    legacy_manifest_2 = b"2" * 32
    legacy_manifest_3_bad = b"x" * 32
    legacy_manifest_3 = b"3" * 32
    assert not shared_migration_gate._arm_from_manager(
        1, 1, 2, legacy_manifest_2, caller="attacker")
    assert shared_migration_gate._arm_from_manager(
        1, 1, 2, legacy_manifest_2, caller="version-manager")
    assert migration_protocol._arm_migration_for_test(1)
    migration_registry.arm_migration()
    assert settlement_1._arm_migration_for_test(
        caller_is_version_manager=True, delayed_manifest_active=True,
        generation=1, target_protocol_version=2)
    check("P50bm migration arm closes new transient and ingress work",
          migration_protocol.open_session(
              migration_outage_clock, "veto-session", "attacker",
              migration_outage_clock.timestamp + DATA_TTL_SECONDS)
              in {"SYNCED", "MIGRATION_ARMED"}
          and not migration_registry.reserve("migration-builder", 2, 0)
          and migration_protocol.admit_message(
              migration_outage_clock, message(4_000, "veto-ingress"))
              == "SYNCED"
          and active_router.sync_and_append(
              message(4_000, "veto-router-ingress",
                      kind=ForceKind.BRIDGE_CREDIT),
              clock=migration_outage_clock,
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              deposit=3) == "SYNCED"
          and active_router.sync_and_append(
              message(4_000, "unauthorized-router-ingress",
                      kind=ForceKind.BRIDGE_CREDIT),
              clock=migration_outage_clock,
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              deposit=3, caller_adapter="attacker") == "REJECTED"
          and len(migration_protocol.messages) == 18)
    recovery_expiry_slot = (
        migration_protocol.recovery.expires_at - GENESIS_TIMESTAMP)
    before_expiry = clock(182, recovery_expiry_slot)
    assert not migration_protocol.sync(before_expiry)
    after_expiry = clock(183, recovery_expiry_slot + 1)
    assert migration_protocol.sync(after_expiry)
    check("P50bg delayed cutover reaches migration-ready without reopening",
          migration_protocol.recovery is None
          and migration_revision == 1
          and shared_migration_gate.mode == "READY"
          and shared_migration_gate.live_data_sessions == 0
          and len(migration_protocol.messages) == 18
          and migration_registry.open_reservations
              == migration_reservations_before
          and not migration_registry.liable_reservations
          and settlement_1.enter_migration_ready()
          and migration_protocol.arm_normal_context(after_expiry)
              == "SYNCED"
          and migration_protocol.activate_normal_context(after_expiry)
              == "SYNCED"
          and migration_protocol.submit(
              candidate(migration_protocol, after_expiry, "ready-veto"),
              after_expiry) == "SYNCED"
          and active_router.sync_and_append(
              message(2, "ready-row", kind=ForceKind.BRIDGE_CREDIT),
              clock=after_expiry,
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              deposit=1) == "SYNCED")

    fake_settlement = VersionedSettlementHistory(
        "settlement:fake", "runtime:2", 2, "profile:2",
        replace(canonical_core_756, state_root="attacker-state"),
        51, terminal_queue, migration_gate=shared_migration_gate)
    exact_settlement = VersionedSettlementHistory(
        "settlement:2", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle)
    exact_target_protocol = protocol(
        tip_slot=canonical_core_756.tip_slot,
        cursor=canonical_core_756.message_cursor,
        seat=False,
        mode=Mode.PREACTIVE,
        forced_queue=terminal_queue,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle,
        migration_gate=shared_migration_gate,
        settlement_address=exact_settlement.address)
    exact_target_protocol.seat_generation = 0
    exact_target_protocol.canonical = Canonical(
        copy.deepcopy(canonical_core_756), 51)
    exact_target_protocol.versioned_history = exact_settlement
    exact_settlement.live_protocol = exact_target_protocol
    wrong_queue_settlement = VersionedSettlementHistory(
        "settlement:wrong-queue", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51,
        replace(terminal_queue, address="replacement-queue"),
        inbox_apply_router=migration_inbox_apply)
    fresh_gate_settlement = VersionedSettlementHistory(
        "settlement:fresh-gate", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51, terminal_queue,
        inbox_apply_router=migration_inbox_apply)
    wrong_schedule_settlement = VersionedSettlementHistory(
        "settlement:wrong-schedule", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply,
        schedule_oracle_id="replacement-schedule-oracle")
    activation_output_core = replace(
        canonical_core_756, l2_block_number=757, tip_hash="block:757",
        tip_slot=canonical_core_756.tip_slot + 1,
        state_root="state:release-2", message_cursor=terminal_queue.count)
    activation_proof = MigrationActivationProof(
        copy.deepcopy(canonical_core_756), activation_output_core,
        2, legacy_manifest_2, canonical_core_756.message_cursor,
        terminal_queue.count, "activation-prover")
    wrong_runtime_queue = replace(
        terminal_queue, runtime_hash="attacker-queue-runtime"
    )
    wrong_runtime_settlement = replace(
        exact_settlement, forced_queue=wrong_runtime_queue
    )
    queue_code_rejected = not active_router._activate_version_with_proof(
        settlement=wrong_runtime_settlement,
        clock=Clock(52, GENESIS_TIMESTAMP + 52),
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    live_canonical = migration_protocol.canonical
    migration_protocol.canonical = Canonical(
        replace(canonical_core_756, state_root="stale-live-state"), 51)
    stale_live_state_rejected = not active_router._activate_version_with_proof(
        settlement=exact_settlement,
        clock=Clock(52, GENESIS_TIMESTAMP + 52),
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    migration_protocol.canonical = live_canonical
    check("P50ba router rejects fake, unauthorized and discontinuous targets",
          queue_code_rejected and stale_live_state_rejected
          and not active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2,
              activation_proof=replace(activation_proof, proof_valid=False),
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2,
              activation_proof=replace(
                  activation_proof, target_components_valid=False),
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:attacker",
              activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=fake_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=False, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=False, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=wrong_queue_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=fresh_gate_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router._activate_version_with_proof(
              settlement=wrong_schedule_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True))
    assert active_router._activate_version_with_proof(
              settlement=exact_settlement,
              clock=Clock(52, GENESIS_TIMESTAMP + 52),
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash=legacy_manifest_2, activation_proof=activation_proof,
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    migration_protocol = exact_settlement.live_protocol
    assert migration_protocol is not settlement_1.live_protocol
    check("P50bc proof-first migration atomically adopts target activation",
          settlement_1.mode == "FROZEN"
          and active_router.canonical_at(1, sequence_2) == canonical_756
          and active_router.canonical_at(2, sequence_2 + 1) is not None
          and not hasattr(exact_settlement, "record_canonical")
          and exact_settlement._record_canonical_from_protocol(
              protocol=settlement_1.live_protocol,
              clock=Clock(52, GENESIS_TIMESTAMP + 5)) is None
          and active_router.sync_and_append(
              message(2, "same-old-adapter-after-v2",
                      kind=ForceKind.BRIDGE_CREDIT),
              clock=Clock(52, GENESIS_TIMESTAMP + 2),
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              deposit=5) == "QUEUED:18"
          and shared_migration_gate.mode == "ACTIVE"
          and shared_migration_gate.active_protocol_version == 2
          and shared_migration_gate.target_protocol_version == 0
          and terminal_queue.active_settlement_address == "settlement:2"
          and not terminal_queue.advance_cursor(
              18, 18, caller="settlement:1", beneficiary="old")
          and not terminal_queue.advance_cursor(
              18, 19, caller="attacker", beneficiary="attacker")
          and terminal_queue.count == 19
          and terminal_queue.cursor == 18
          and terminal_queue.escrow_balance == 29
          and terminal_queue.claimable.get("activation-prover") == 12
          and [row.payload_hash for row in terminal_queue.descriptors[-2:]]
              == ["old-adapter-row", "same-old-adapter-after-v2"]
          and migration_protocol.messages is terminal_queue.descriptors
          and not migration_protocol.release_activation_pending
          and migration_protocol.pending_release_protocol_version == 0
          and migration_protocol.pending_release_manifest_hash == ""
          and migration_registry.reserve("migration-builder", 1, 0)
          and migration_registry.reserve("migration-builder", 2, 0))
    migration_activation_trigger = clock(200, 4_001)
    assert migration_protocol.sync(migration_activation_trigger)
    migration_activation_clock = recovery_submit_clock(migration_protocol)
    migration_activation_candidate = escape_candidate(
        migration_protocol, migration_activation_clock,
        "migration-release-activation")
    forged_activation = replace(
        migration_activation_candidate,
        blocks=(replace(
            migration_activation_candidate.blocks[0],
            release_activation=True, release_protocol_version=2,
            release_manifest_hash="manifest:2",
            force_gas_budget=ACTIVATION_FORCE_GAS_BUDGET),))
    check("P50ct post-cutover work cannot replay release activation",
          not migration_activation_candidate.blocks[0].release_activation
          and migration_activation_candidate.blocks[0].release_protocol_version == 0
          and migration_activation_candidate.blocks[0].release_manifest_hash == ""
          and not migration_protocol._valid_recovery(
              forged_activation, migration_activation_clock)
          and migration_protocol.submit(
              migration_activation_candidate,
              migration_activation_clock) == "COMMITTED"
          and not migration_protocol.release_activation_pending
          and migration_protocol.core.message_cursor == 19
          and terminal_queue.claimable.get("prover") == 5
          and terminal_queue.withdraw_claimable("activation-prover") == 12
          and terminal_queue.withdraw_claimable("prover") == 5
          and terminal_queue.escrow_balance == 12
          and terminal_queue.unconsumed_escrow == 0
          and terminal_queue.total_claimable == 12
          and terminal_queue.escrow_balance
              >= terminal_queue.accounted_liabilities)
    assert shared_migration_gate._arm_from_manager(
        2, 2, 3, legacy_manifest_3_bad, caller="version-manager")
    assert migration_protocol._arm_migration_for_test(2)
    migration_registry.arm_migration()
    assert exact_settlement._arm_migration_for_test(
        caller_is_version_manager=True, delayed_manifest_active=True,
        generation=2, target_protocol_version=3)
    abort_ready_clock = Clock(
        migration_activation_clock.block_number + 1,
        migration_activation_clock.timestamp + 1)
    assert migration_protocol.sync(abort_ready_clock)
    assert exact_settlement.enter_migration_ready()
    assert not active_router._abort_migration_for_test(
        generation=2, target_protocol_version=3,
        target_manifest_hash=legacy_manifest_3_bad,
        cancel_manifest_active=False, clock=abort_ready_clock)
    assert active_router._abort_migration_for_test(
        generation=2, target_protocol_version=3,
        target_manifest_hash=legacy_manifest_3_bad,
        cancel_manifest_active=True, clock=abort_ready_clock)
    assert shared_migration_gate._arm_from_manager(
        3, 2, 3, legacy_manifest_3, caller="version-manager")
    assert migration_protocol._arm_migration_for_test(3)
    migration_registry.arm_migration()
    assert exact_settlement._arm_migration_for_test(
        caller_is_version_manager=True, delayed_manifest_active=True,
        generation=3, target_protocol_version=3)
    second_ready_clock = Clock(
        abort_ready_clock.block_number + 1, abort_ready_clock.timestamp + 1)
    assert migration_protocol.sync(second_ready_clock)
    assert exact_settlement.enter_migration_ready()
    settlement_3 = VersionedSettlementHistory(
        "settlement:3", "runtime:3", 3, "profile:3",
        copy.deepcopy(exact_settlement.core),
        exact_settlement.canonicalized_at_block, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle)
    target_protocol_3 = protocol(
        tip_slot=exact_settlement.core.tip_slot,
        cursor=exact_settlement.core.message_cursor,
        seat=False,
        mode=Mode.PREACTIVE,
        forced_queue=terminal_queue,
        inbox_apply_router=migration_inbox_apply,
        header_oracle=migration_header_oracle,
        migration_gate=shared_migration_gate,
        settlement_address=settlement_3.address)
    target_protocol_3.seat_generation = 0
    target_protocol_3.canonical = Canonical(
        copy.deepcopy(exact_settlement.core),
        exact_settlement.canonicalized_at_block)
    target_protocol_3.versioned_history = settlement_3
    settlement_3.live_protocol = target_protocol_3
    activation_output_3 = replace(
        exact_settlement.core,
        l2_block_number=exact_settlement.core.l2_block_number + 1,
        tip_hash="block:release-3", tip_slot=exact_settlement.core.tip_slot + 1,
        state_root="state:release-3")
    activation_proof_3 = MigrationActivationProof(
        copy.deepcopy(exact_settlement.core), activation_output_3,
        3, legacy_manifest_3, terminal_queue.cursor, terminal_queue.cursor,
        "activation-prover-3")
    second_cutover_block = max(
        second_ready_clock.block_number + 1,
        exact_settlement.last_canonical_l1_block + 1)
    assert active_router._activate_version_with_proof(
        settlement=settlement_3,
        clock=Clock(second_cutover_block, second_ready_clock.timestamp + 1),
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash=legacy_manifest_3, activation_proof=activation_proof_3,
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    check("P50bn abort is delayed and the same gate completes a later migration",
          2 in shared_migration_gate.canceled_generations
          and shared_migration_gate.generation == 3
          and shared_migration_gate.mode == "ACTIVE"
          and shared_migration_gate.active_protocol_version == 3
          and active_router.active_version == 3
          and exact_settlement.mode == "FROZEN"
          and settlement_3.mode == "ACTIVE"
          and terminal_queue.active_settlement_address == "settlement:3"
          and active_router.canonical_at(
              3, exact_settlement.current_sequence + 1) is not None
          and migration_registry.open_reservations
              == migration_reservations_before
          and not migration_registry.liable_reservations)

    terminal_verifier = TerminalSignalVerifier(active_router)
    failed_index = destination.terminal_index[credit_a]
    done_index = destination.terminal_index[credit_b]
    failed_proof = TerminalProof(
        1, sequence_2, canonical_756, failed_index, "bridge:A", "domain:D1",
        credit_a, "FAILED", accumulator.leaves[failed_index], accumulator.root)
    done_proof = TerminalProof(
        1, sequence_2, canonical_756, done_index, "bridge:A", "domain:D1",
        credit_b, "DONE", accumulator.leaves[done_index], accumulator.root)
    done_d2_index = destination_d2.terminal_index[credit_d2]
    d2_proof = TerminalProof(
        1, sequence_2, canonical_756, done_d2_index, "bridge:B", "domain:D2",
        credit_d2, "DONE", accumulator.leaves[done_d2_index],
        accumulator.root)
    legacy_signal_service_paused = True
    check("P50as V2 terminal verifier is independent of legacy SignalService pause",
          legacy_signal_service_paused
          and terminal_verifier.verify(
              proof=failed_proof, credit_id=credit_a, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A")
          and not terminal_verifier.verify(
              proof=replace(failed_proof, destination_bridge="bridge:B"),
              credit_id=credit_a, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A"))
    check("P50aw terminal proof substitutions fail closed",
          not terminal_verifier.verify(
              proof=failed_proof, credit_id=credit_b, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A")
          and not terminal_verifier.verify(
              proof=failed_proof, credit_id=credit_a, terminal="DONE",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A")
          and not terminal_verifier.verify(
              proof=replace(failed_proof, proof_root="forged"),
              credit_id=credit_a, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A")
          and not terminal_verifier.verify(
              proof=replace(failed_proof, canonical_sequence=99),
              credit_id=credit_a, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A"))
    check("P50cb one source verifier handles old D1 and later D2 endpoints",
          terminal_verifier.verify(
              proof=done_proof, credit_id=credit_b, terminal="DONE",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A")
          and not terminal_verifier.verify(
              proof=replace(d2_proof, destination_bridge="bridge:A"),
              credit_id=credit_d2, terminal="DONE",
              destination_domain_id="domain:D2",
              destination_bridge="bridge:B")
          and source.finalize_done(
              credit_d2, verifier=terminal_verifier, proof=d2_proof))
    frozen_runtime = settlement_1.runtime_hash
    try:
        settlement_1.runtime_hash = "runtime:mutated"
        runtime_replacement_rejected = False
    except AttributeError:
        runtime_replacement_rejected = True
    check("P50bd historical Settlement code identity is pinned",
          runtime_replacement_rejected
          and settlement_1.runtime_hash == frozen_runtime)
    check("P50aj permanent terminal proofs release exactly one source liability",
          source.recall_failed(
              credit_a, verifier=terminal_verifier, proof=failed_proof)
          and source.credits[credit_a].status == "RECALLED"
          and source.finalize_done(
              credit_b, verifier=terminal_verifier, proof=done_proof)
          and source.credits[credit_b].status == "DELIVERED"
          and not source.finalize_done(
              credit_a, verifier=terminal_verifier, proof=done_proof)
          and not source.recall_failed(
              credit_b, verifier=terminal_verifier, proof=failed_proof))

    reorg_protocol = protocol(tip_slot=100)
    reorg_adapter = BridgeAdapter()
    reorg_source = SourceBridgeLedger()
    reorg_clock = clock(100, 100)
    reorg_enqueue_by = reorg_clock.timestamp + MAX_BRIDGE_ENQUEUE_DELAY
    reorg_id = reorg_adapter.credit_id(
        1, "domain:R1", 1, "bridge:A", "domain:D1", "reorg")
    assert reorg_source.open(
        reorg_id, now=reorg_clock.timestamp, enqueue_by=reorg_enqueue_by,
        owner="alice", value=1, fee=1)
    pre_protocol = reorg_protocol.snapshot()
    pre_adapter = copy.deepcopy(reorg_adapter)
    pre_source = copy.deepcopy(reorg_source)
    assert reorg_adapter.enqueue(
        reorg_protocol, reorg_clock, reorg_source, src_chain_id=1,
        source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
        destination_domain_id="domain:D1", msg_hash="reorg",
        enqueue_by=reorg_enqueue_by, envelope=bridge_envelope,
        caller="relayer", deposit=1) == "QUEUED:0"
    reorg_protocol = pre_protocol
    reorg_adapter = pre_adapter
    reorg_source = pre_source
    check("P50o orphaned direct enqueue replays from the durable source record",
          reorg_adapter.enqueue(
              reorg_protocol, clock(101, 101), reorg_source, src_chain_id=1,
              source_domain_id="domain:R1", src_epoch=1, src_bridge="bridge:A",
              destination_domain_id="domain:D1", msg_hash="reorg",
              enqueue_by=reorg_enqueue_by, envelope=bridge_envelope,
              caller="relayer", deposit=1) == "QUEUED:0"
          and len(reorg_protocol.messages) == 1)


if __name__ == "__main__":
    for test in (
        test_canonical_outputs_and_migration,
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
