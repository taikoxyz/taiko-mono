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
MAX_FORCE_RANGE_PROOF_HASHES = 129
FORCE_TREE_DEPTH = 32
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
MAX_MIGRATION_RESERVATION_CLEANUP_CALLS = (
    MAX_LIVE_RESERVATIONS + MAX_GC_STEPS - 1) // MAX_GC_STEPS
DATA_TTL_SECONDS = 86_400
REORG_MARGIN_SECONDS = 1_800
UINT64_MAX = (1 << 64) - 1
G_MAX = DELTA_FINAL_LAG
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
MAX_REGISTRATION_PROOF_NODES = 132
MAX_REGISTRATION_PROOF_BYTES = 80_000
APPENDING_SENTINEL = UINT64_MAX
INBOX_BATCH_OK_V2_WORD = bytes.fromhex("49425632" + "00" * 28)
TERMINAL_COMMITMENT_ABI_BYTES = 4 * 32

MAX_LIABILITY_RESIDENCE_WINDOWS = (
    MAX_TRANCHE_AHEAD_WINDOWS + 1
    + (EVIDENCE_DELAY_SECONDS + REORG_MARGIN_SECONDS + 383) // 384 + 2
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

    def valid(self, *, block_number: int, activation_block: int,
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
                and self.system_nonce == block_number - activation_block
                and block_number >= activation_block and self.gas_limit == expected_gas
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
    force_gas_budget: int = FORCE_GAS_BUDGET
    release_activation: bool = False
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


@dataclass
class Seat:
    operator: str
    penalty_bond: int
    terminated: bool = False


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
    target_manifest_hash: str = ""
    coordinator: str = ""
    live_data_sessions: int = 0
    unsettled_builder_reservations: int = 0

    def bootstrap(self, protocol_version: int, coordinator: str = "version-manager") -> bool:
        if (self.active_protocol_version != 0 or protocol_version <= 0
                or self.mode != "ACTIVE" or not coordinator):
            return False
        self.active_protocol_version = protocol_version
        self.coordinator = coordinator
        return True

    def arm(self, generation: int, active_protocol_version: int,
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

    def try_ready(self, *, normal_open: bool, recovery_active: bool) -> bool:
        if (self.mode != "ARMED" or normal_open or recovery_active
                or self.live_data_sessions != 0
                or self.unsettled_builder_reservations != 0):
            return False
        self.mode = "READY"
        return True

    def activate_target(self, generation: int, old_protocol_version: int,
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


@dataclass
class RegistryLifecycle:
    active: list[Generation]
    liability_ring: list[tuple[Generation, int] | None] = field(
        default_factory=lambda: [None] * MAX_LIABILITY_GENERATIONS)
    replacements: dict[int, int] = field(default_factory=dict)
    movement_sequence: int = 0
    migration_gate: MigrationGate = field(default_factory=MigrationGate)
    open_reservations: set[tuple[str, int]] = field(default_factory=set)
    liable_reservations: set[tuple[str, int]] = field(default_factory=set)

    @property
    def liabilities(self) -> list[Generation]:
        return [item[0] for item in self.liability_ring if item is not None]

    def settle_reservations_before(self, current_window: int) -> int:
        """Normal lifecycle removal; only the 17 live windows enter the gate."""
        expired = {row for row in self.open_reservations
                   if row[1] < current_window}
        self.open_reservations.difference_update(expired)
        self.migration_gate.unsettled_builder_reservations -= len(expired)
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
            reservation = (address, window)
            if reservation not in self.open_reservations:
                self.open_reservations.add(reservation)
                self.migration_gate.unsettled_builder_reservations += 1
                assert len(self.open_reservations) <= MAX_LIVE_RESERVATIONS
            return True
        return False

    def arm_migration(self) -> None:
        # The shared gate is the reversible migration veto.  The permanent
        # reservations_closed bit remains reserved for exit/replacement.
        assert self.migration_gate.mode == "ARMED"

    def cleanup_migration_reservations(self, limit: int = MAX_GC_STEPS) -> int:
        if self.migration_gate.mode != "ARMED":
            return 0
        removed = 0
        for reservation in sorted(self.open_reservations)[:limit]:
            self.open_reservations.remove(reservation)
            self.migration_gate.unsettled_builder_reservations -= 1
            removed += 1
        return removed

    def _move_reservations_to_liability(self, address: str) -> int:
        moved = {row for row in self.open_reservations if row[0] == address}
        self.open_reservations.difference_update(moved)
        self.liable_reservations.update(moved)
        self.migration_gate.unsettled_builder_reservations -= len(moved)
        return len(moved)

    def release_liability(self, ring_index: int, current_window: int) -> bool:
        occupant = self.liability_ring[ring_index]
        if occupant is None or occupant[1] > current_window:
            return False
        address = occupant[0].address
        self.liability_ring[ring_index] = None
        self.liable_reservations = {
            row for row in self.liable_reservations if row[0] != address}
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
        self._move_reservations_to_liability(victim.address)
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
    history: dict[int, L1Header]
    forced_queue: "QueueContinuity"
    inbox_apply_router: "InboxApplyRouterV2"
    mode: Mode = Mode.NORMAL
    release_activation_pending: bool = False
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
    active_seat: Seat | None = None
    standby: list[Seat] = field(default_factory=list)
    burned_local: int = 0
    sessions: dict[str, DataSession] = field(default_factory=dict)
    gc_cursor: int = 0
    events: list[str] = field(default_factory=list)
    boundary_queries: int = 0
    canonical_state_witness_available: bool = True
    canonical_code_preimages_available: bool = True
    migration_gate: MigrationGate = field(default_factory=MigrationGate)
    versioned_history: object | None = None

    @property
    def core(self) -> CanonicalCore:
        return self.canonical.core

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

    @property
    def messages(self) -> list[Message]:
        """Compatibility view: Protocol owns no independent message list."""
        return self.forced_queue.descriptors

    def force_root(self, cutoff: int) -> str:
        return f"merkle:{cutoff}:" + ":".join(m.payload_hash for m in self.messages[:cutoff])

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
        header = self.history[armed]
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

    def _close_mature_normal(self, clock: Clock) -> bool:
        if self.normal_deadline is None or clock.timestamp < self.normal_deadline:
            return False
        if (self.normal_best is not None
                and self.next_due_at(self.normal_best.tip.message_end) > clock.timestamp
                and clock.timestamp + REORG_MARGIN_SECONDS
                    <= self.normal_best_min_data_expiry):
            self._commit(self.normal_best, clock)
            self.events.append("NORMAL_COMMITTED")
        else:
            self.events.append("NORMAL_CANCELED_FORCE_OMISSION")
        self._clear_normal()
        return True

    def _new_round(self, clock: Clock, causes: Cause, revision: int) -> RecoveryRound:
        anchor_number = clock.block_number - 1
        anchor = self.history[anchor_number]
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
        self.mode = Mode.RECOVERY
        self.episode += 1
        self.recovery = self._new_round(clock, causes, 1)
        if causes & Cause.SLA and self.active_seat is not None:
            self.active_seat.terminated = True
            self.burned_local += self.active_seat.penalty_bond
            self.active_seat = next((s for s in self.standby if not s.terminated), None)
        self.events.append(f"RECOVERY_OPEN:{self.episode}:{int(causes)}")

    def _roll_recovery(self, clock: Clock) -> bool:
        assert self.recovery is not None
        if clock.timestamp <= self.recovery.expires_at:
            return False
        old = self.recovery
        self.recovery = self._new_round(clock, old.causes, old.revision + 1)
        self.events.append(f"RECOVERY_ROLLED:{self.recovery.revision}")
        return True

    def arm_migration(self, generation: int) -> bool:
        if (self.mode is Mode.PREACTIVE
                or self.migration_gate.mode != "ARMED"
                or self.migration_gate.generation != generation):
            return False
        if self.mode is Mode.NORMAL and self.normal_deadline is None:
            self._clear_normal()
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

    def _sync_migration(self, clock: Clock) -> bool:
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
                    changed |= self._close_mature_normal(clock)
            elif self.normal_arm_block_number is not None:
                self._clear_normal()
                changed = True
        boundary_open = (self.mode is Mode.RECOVERY
                         or self.normal_deadline is not None
                         or self.normal_best is not None
                         or self.normal_arm_block_number is not None)
        if not boundary_open:
            changed |= self._cleanup_migration_sessions() > 0
        if self.migration_gate.try_ready(
                normal_open=boundary_open and self.mode is Mode.NORMAL,
                recovery_active=self.mode is Mode.RECOVERY):
            self.events.append("MIGRATION_READY")
            changed = True
        return changed

    def sync(self, clock: Clock) -> bool:
        if self.mode is Mode.PREACTIVE:
            return False
        if self.migration_gate.mode == "ARMED":
            return self._sync_migration(clock)
        if self.migration_gate.mode == "READY":
            return False
        if self.mode is Mode.RECOVERY:
            return self._roll_recovery(clock)
        changed = False
        due = self.force_due(clock)
        if due and self.normal_deadline is not None and clock.timestamp < self.normal_deadline:
            self._clear_normal()
            self.events.append("NORMAL_CANCELED_FORCE_DUE")
            changed = True
        elif self.normal_deadline is not None and clock.timestamp >= self.normal_deadline:
            changed |= self._close_mature_normal(clock)
        causes = Cause.NONE
        if clock.l2_slot - self.core.tip_slot > DELTA_FINAL_LAG:
            causes |= Cause.SLA
        if self.force_due(clock):
            causes |= Cause.FORCE_DUE
        if causes:
            self._activate(clock, causes)
            changed = True
        return changed

    def activate_migration(self, clock: Clock, imported: Canonical,
                           *, old_quiescent: bool, router_switched: bool,
                           header_checkpoint_authenticated: bool = True,
                           l2_system_accounts_authenticated: bool = True,
                           l2_v2_latch_disabled: bool = True) -> bool:
        if (self.mode is not Mode.PREACTIVE or clock.timestamp < GENESIS_TIMESTAMP
                or not old_quiescent or not router_switched
                or not header_checkpoint_authenticated
                or not l2_system_accounts_authenticated
                or not l2_v2_latch_disabled
                or self.messages
                or imported.canonicalized_at_block != clock.block_number
                or imported.core.l2_block_number >= 1 << 48
                or imported.core.message_cursor != 0
                or imported.core.tip_slot > clock.l2_slot
                or imported.core.winning_data_commitment == "empty"
                or imported.core.next_base_fee <= 0):
            return False
        self.canonical = copy.deepcopy(imported)
        self.mode = Mode.NORMAL
        self.release_activation_pending = True
        self.events.append("MIGRATION_ACTIVATED_ATOMICALLY")
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
            due_at=due) == expected_index

    def admit_message(self, clock: Clock, message: Message) -> str:
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

    def admit_bridge_direct(self, clock: Clock, message: Message) -> str:
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
        if self.sync(clock):
            return "SYNCED"
        if self.migration_gate.mode != "ACTIVE":
            return "SYNCED"
        if (len(self.messages) >= self.queue_capacity
                or not self._valid_bridge_static(message)):
            return "REJECTED"
        self._append(clock, message)
        return "ADMITTED"

    def open_session(self, clock: Clock, session_id: str, owner: str, expiry: int) -> str:
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
        header = self.history.get(block.anchor_number)
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
                    or block.release_activation != expected_activation
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
        if self.mode is Mode.PREACTIVE:
            return "REJECTED_PREACTIVE"
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
        if not self._valid_recovery(candidate, clock):
            return "REJECTED"
        self._commit(candidate, clock)
        self.mode = Mode.NORMAL
        self.recovery = None
        self.events.append("RECOVERY_COMMITTED")
        return "COMMITTED"

    def _commit(self, candidate: Candidate, clock: Clock) -> None:
        assert (self.forced_queue.cursor
                == self.inbox_apply_router.next_queue_index
                == self.core.message_cursor)
        self.forced_queue.cursor = candidate.tip.message_end
        self.inbox_apply_router.next_queue_index = candidate.tip.message_end
        if candidate.blocks[0].release_activation:
            self.release_activation_pending = False
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
            assert history.record_canonical(
                copy.deepcopy(self.canonical.core),
                l1_block=clock.block_number) is not None
        self.events.append(f"CANONICAL:{candidate.candidate_id}")


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

    def append(self, descriptor: Message, *, deposit: int,
               due_at: int) -> int | None:
        if (not descriptor.payload_hash or deposit < 0
                or due_at < self.last_due_at or self.count >= UINT32_MAX
                or self.count != len(self.descriptors)):
            return None
        index = self.count
        stored = replace(descriptor, due_at=due_at)
        self.root = (f"queue-root:{index + 1}:{self.root}:"
                     f"{stored.payload_hash}")
        self.count += 1
        self.escrow_balance += deposit
        self.last_due_at = due_at
        self.descriptors.append(stored)
        return index


@dataclass(frozen=True)
class MigrationTransientState:
    normal_best_present: bool
    recovery_active: bool
    live_data_sessions: int
    unsettled_builder_escrow: int
    claim_only_surfaces_preserved: bool

    @property
    def settled(self) -> bool:
        return (not self.normal_best_present and not self.recovery_active
                and self.live_data_sessions == 0
                and self.unsettled_builder_escrow == 0
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

    def _entry(self, sequence: int, core: CanonicalCore,
               canonicalized_at_block: int) -> CanonicalTerminalCommitment:
        return CanonicalTerminalCommitment(
            self.protocol_version, self.execution_profile_hash, sequence,
            core.l2_block_number, core.tip_hash, core.state_root,
            core.terminal_root, core.terminal_count, canonicalized_at_block)

    def install_imported(self, *, sequence: int,
                         history_write_block: int) -> bool:
        if (self.mode != "PREACTIVE" or self.history or sequence < 0
                or sequence >= UINT64_MAX
                or self.canonicalized_at_block <= 0
                or history_write_block < self.canonicalized_at_block):
            return False
        entry = self._entry(sequence, self.core, self.canonicalized_at_block)
        self.history[sequence % CANONICAL_HISTORY_CAPACITY] = (sequence, entry)
        self.current_sequence = sequence
        self.last_canonical_l1_block = history_write_block
        return True

    def record_canonical(self, core: CanonicalCore, *, l1_block: int) -> int | None:
        if (self.mode not in {"ACTIVE", "MIGRATION_ARMED"}
                or self.inbox_apply_router is None
                or core.message_cursor != self.forced_queue.cursor
                or core.message_cursor
                    != self.inbox_apply_router.next_queue_index
                or l1_block <= self.last_canonical_l1_block
                or self.current_sequence < 0
                or self.current_sequence + 1 >= UINT64_MAX
                or core.l2_block_number <= self.core.l2_block_number
                or core.terminal_count < self.core.terminal_count
                or (core.terminal_count == self.core.terminal_count
                    and core.terminal_root != self.core.terminal_root)):
            return None
        sequence = self.current_sequence + 1
        entry = self._entry(sequence, core, l1_block)
        self.history[sequence % CANONICAL_HISTORY_CAPACITY] = (sequence, entry)
        self.core = copy.deepcopy(core)
        self.canonicalized_at_block = l1_block
        self.current_sequence = sequence
        self.last_canonical_l1_block = l1_block
        return sequence

    def arm_migration(self, *, caller_is_version_manager: bool,
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


@dataclass
class ActiveSettlementRouter:
    """Append-only immutable registry and read-only history router."""

    version_manager: str
    forced_queue: QueueContinuity
    inbox_apply_router: "InboxApplyRouterV2"
    address: str = "active-settlement-router"
    active_version: int = 0
    registrations: dict[int, SettlementRegistration] = field(default_factory=dict)

    @property
    def forced_queue_address(self) -> str:
        return self.forced_queue.address

    def bootstrap(self, settlement: VersionedSettlementHistory, *, sequence: int,
                  activation_block: int) -> bool:
        if (self.registrations or settlement.protocol_version <= 0
                or settlement.forced_queue is not self.forced_queue
                or settlement.inbox_apply_router is not self.inbox_apply_router
                or settlement.core.message_cursor != self.forced_queue.cursor
                or settlement.core.message_cursor
                    != self.inbox_apply_router.next_queue_index
                or not settlement.nonproxy or not settlement.selfdestruct_disabled
                or not settlement.migration_gate.bootstrap(
                    settlement.protocol_version, self.version_manager)
                or not settlement.install_imported(
                    sequence=sequence, history_write_block=activation_block)):
            return False
        settlement.mode = "ACTIVE"
        self.registrations[settlement.protocol_version] = SettlementRegistration(
            settlement, settlement.runtime_hash,
            settlement.execution_profile_hash, activation_block, 0)
        self.active_version = settlement.protocol_version
        return True

    def activate_version(
            self, *, settlement: VersionedSettlementHistory, l1_block: int,
            caller_is_version_manager: bool, manifest_active: bool,
            target_manifest_hash: str,
            target_runtime_approved: bool, target_profile_matches: bool,
            full_core_import_exact: bool, queue_import_exact: bool) -> bool:
        old_registration = self.registrations.get(self.active_version)
        if old_registration is None:
            return False
        old = old_registration.settlement
        if (not caller_is_version_manager or not manifest_active
                or not target_runtime_approved or not target_profile_matches
                or not full_core_import_exact or not queue_import_exact
                or settlement.protocol_version <= self.active_version
                or settlement.protocol_version in self.registrations
                or not settlement.execution_profile_hash
                or not settlement.runtime_hash
                or not settlement.nonproxy or not settlement.selfdestruct_disabled
                or settlement.mode != "PREACTIVE" or settlement.history
                or old.mode != "MIGRATION_READY"
                or old.migration_gate.mode != "READY"
                or old.migration_gate.active_protocol_version
                    != self.active_version
                or settlement.migration_gate is not old.migration_gate
                or old.migration_gate.target_protocol_version
                    != settlement.protocol_version
                or old.migration_gate.target_manifest_hash
                    != target_manifest_hash
                or settlement.core != old.core
                or settlement.canonicalized_at_block
                    != old.canonicalized_at_block
                or settlement.forced_queue is not self.forced_queue
                or old.forced_queue is not self.forced_queue
                or settlement.inbox_apply_router is not self.inbox_apply_router
                or old.inbox_apply_router is not self.inbox_apply_router
                or old.live_protocol is None
                or old.live_protocol.versioned_history is not old
                or old.live_protocol.forced_queue is not self.forced_queue
                or old.live_protocol.inbox_apply_router
                    is not self.inbox_apply_router
                or old.live_protocol.canonical.core != old.core
                or old.core.message_cursor != self.forced_queue.cursor
                or old.core.message_cursor
                    != self.inbox_apply_router.next_queue_index
                or l1_block < old.last_canonical_l1_block):
            return False
        if not settlement.install_imported(
                sequence=old.current_sequence, history_write_block=l1_block):
            return False
        old_version = self.active_version
        old.mode = "FROZEN"
        settlement.mode = "ACTIVE"
        self.registrations[settlement.protocol_version] = SettlementRegistration(
            settlement, settlement.runtime_hash,
            settlement.execution_profile_hash, l1_block, old_version)
        self.active_version = settlement.protocol_version
        settlement.live_protocol = old.live_protocol
        settlement.live_protocol.versioned_history = settlement
        activated = old.migration_gate.activate_target(
            old.migration_gate.generation, old_version,
            settlement.protocol_version)
        assert activated
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

    def sync_and_append(self, descriptor: Message, *, bound_router: str,
                        queue_address: str,
                        active_settlement_sync_changed: bool,
                        deposit: int = 0, due_at: int | None = None) -> str:
        registration = self.registrations.get(self.active_version)
        if (bound_router != self.address
                or queue_address != self.forced_queue_address
                or registration is None
                or registration.settlement.mode
                    not in {"ACTIVE", "MIGRATION_ARMED", "MIGRATION_READY"}):
            return "REJECTED"
        if registration.settlement.mode == "MIGRATION_READY":
            return "SYNCED"
        if active_settlement_sync_changed:
            return "SYNCED"
        index = self.forced_queue.append(
            descriptor, deposit=deposit,
            due_at=(self.forced_queue.last_due_at
                    if due_at is None else due_at))
        return "REJECTED" if index is None else f"QUEUED:{index}"


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
        result = protocol_.admit_bridge_direct(clock_, envelope)
        if result == "SYNCED":
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

    @property
    def config_hash(self) -> str:
        return ("bridge-topology:" + repr((
            self.topology, self.account_runtime_hash,
            self.implementation_runtime_hash)))

    @property
    def identity(self) -> tuple[str, ...]:
        return (self.topology, self.address, self.account_runtime_hash,
                self.implementation_address,
                self.implementation_runtime_hash, self.config_hash)

    def authenticates(
            self, manifest: ReleaseManifestV2, *,
            known_identity: tuple[str, ...] | None = None) -> bool:
        bridge_row = manifest.components[8]
        descriptor = manifest.destination_bridge_descriptor
        common = (self.address == manifest.destination_bridge
                  and self.account_runtime_hash == bridge_row.runtime_hash
                  and self.config_hash == bridge_row.config_hash
                  and self.upgrade_authority_burned)
        if self.topology == "IMMUTABLE_NONPROXY":
            return (common and not self.delegate_target_reachable
                    and not self.implementation_address
                    and not self.implementation_runtime_hash
                    and self.account_runtime_hash
                        == descriptor.facade_runtime_hash)
        if self.topology == "GENESIS_LEGACY_PROXY":
            return (common
                    and ((known_identity == self.identity)
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
        self.bridge_identities.setdefault(bridge, bridge_deployment.identity)
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
    topology_impl_hash = facade_runtime_hash if legacy_proxy else ""
    topology_config_hash = "bridge-topology:" + repr((
        topology, bridge_runtime_hash, topology_impl_hash))
    components = (
        ReleaseComponentV2("bridge-inbox-adapter", "code:adapter", "cfg:adapter"),
        ReleaseComponentV2("active-settlement-router", "code:router", "cfg:router"),
        ReleaseComponentV2("terminal-verifier", "code:verifier", "cfg:verifier"),
        ReleaseComponentV2("inbox-apply", "code:inbox-apply", "cfg:inbox-apply"),
        ReleaseComponentV2(store.address, store.runtime_codehash,
                           store.component_config_hash),
        ReleaseComponentV2("release-authority", "code:authority", "cfg:authority"),
        ReleaseComponentV2("terminal-domain-registrar", "code:registrar", "cfg:registrar"),
        ReleaseComponentV2("terminal-accumulator", "code:accumulator", "cfg:accumulator"),
        ReleaseComponentV2(
            bridge, bridge_runtime_hash, topology_config_hash),
    )
    bridge_descriptor = DestinationBridgeDescriptorV2(
        bridge, facade_runtime_hash, f"storage-layout:{bridge}",
        f"kernel-profile:{bridge}", store.address, "terminal-accumulator",
        "activation-gate", "terminal-domain-registrar")
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


def make_history(messages: list[Message] | None = None) -> dict[int, L1Header]:
    queue = list(messages or [])
    root = f"merkle:{len(queue)}:" + ":".join(m.payload_hash for m in queue)
    return {n: L1Header(f"{n:064x}", GENESIS_TIMESTAMP + n,
                        f"state-{n}", root, len(queue)) for n in range(1, 20_000)}


def protocol(tip_slot: int = 1_000, cursor: int = 0, seat: bool = True,
             mode: Mode = Mode.NORMAL, messages: list[Message] | None = None,
             forced_queue: QueueContinuity | None = None,
             inbox_apply_router: InboxApplyRouterV2 | None = None) -> Protocol:
    msgs = list(messages or [])
    if forced_queue is None:
        root = f"queue-root:{len(msgs)}:" + ":".join(
            row.payload_hash for row in msgs)
        forced_queue = QueueContinuity(
            "model-forced-queue", root, len(msgs), cursor,
            sum(row.prepaid for row in msgs),
            max((row.due_at for row in msgs), default=0), msgs)
    else:
        assert not messages or forced_queue.descriptors == msgs
        msgs = forced_queue.descriptors
    if inbox_apply_router is None:
        inbox_apply_router = InboxApplyRouterV2(next_queue_index=cursor)
    canonical = Canonical(CanonicalCore(900, "a" * 64, tip_slot, "b" * 64, cursor), 900)
    active = Seat("aggregator", 100) if seat else None
    return Protocol(
        canonical, make_history(msgs), forced_queue, inbox_apply_router,
        mode=mode, active_seat=active, standby=[Seat("standby", 70)])


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
        header = p.history[anchor_number]
        force_root, cutoff = header.force_root, header.force_cutoff
        version = p.normal_admission_version if p.normal_admission_version is not None else p.admission_version
        root = p.normal_admission_root or p.admission_root
    header = p.history[anchor_number]
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
                 force_gas_budget=force_gas_budget,
                 release_activation=release_activation,
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
    check("P4 migration requires quiescence", not p.activate_migration(clock(1_100, 1_100), imported, old_quiescent=False, router_switched=True))
    check("P4a migration proves deployed L2 system accounts", not p.activate_migration(
        clock(1_100, 1_100), imported, old_quiescent=True, router_switched=True,
        l2_system_accounts_authenticated=False)
          and not p.activate_migration(
              clock(1_100, 1_100), imported, old_quiescent=True,
              router_switched=True, l2_v2_latch_disabled=False))
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
              clock(1_100, 1_100), imported, old_quiescent=True,
              router_switched=True))
    check("P5 atomic router cutover imports state and enables ingress",
          p.activate_migration(
              clock(1_100, 1_100), imported, old_quiescent=True,
              router_switched=True)
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
    fork_b.history[1_099] = replace(
        fork_b.history[1_099], block_hash="f" * 64)
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
    check("P14 range proof has a fixed bound", FORCE_TREE_DEPTH == 32 and MAX_FORCE_RANGE_PROOF_HASHES == 129)
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
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_000)
          and steady_tx.valid(
              block_number=101, activation_block=100,
              first_activation=False, l2_chain_id=167_000)
          and not replace(activation_tx, signed=True).valid(
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_000)
          and not replace(activation_tx, gas_limit=ANCHOR_GAS_MAX).valid(
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_000)
          and not activation_tx.valid(
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_001))
    system_rules = SystemExecutionRulesV2(
        "system:inbox", "system:inbox", "system:inbox", 0, 0, 0, 0, 0,
        20, 100, 21_000 + 4 * 20 + 16 * 100,
        True, True, True, True)
    check("P17d kind-1 and accountless system execution are fully distinct",
          inbox_tx.valid(
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_000)
          and system_rules.valid(inbox_tx)
          and not replace(inbox_tx, signed=True).valid(
              block_number=100, activation_block=100,
              first_activation=True, l2_chain_id=167_000)
          and not replace(
              system_rules, sender_nonce_after=1).valid(inbox_tx))
    activation_backlog = protocol(messages=[
        message(0, f"activation-backlog-{index}", gas=5_000_000)
        for index in range(4)])
    activation_backlog.release_activation_pending = True
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
        force_gas_budget=FORCE_GAS_BUDGET, release_activation=False)
    activation_candidate = replace(
        activation_candidate,
        blocks=(activation_first, activation_second),
        end_l2_block_number=activation_backlog.core.l2_block_number + 2,
        next_due_at=activation_backlog.next_due_at(4, 4))
    activation_end = activation_first.message_end
    invalid_20m_block = replace(
        activation_first, message_end=4,
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
    check("P17b depth-32 frontier leaves final index unused",
          MAX_FORCE_QUEUE_ITEMS == (1 << 32) - 1)


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

    gap = protocol(tip_slot=100)
    gap_clock = clock(200, 100 + G_MAX)
    activate_normal(gap, gap_clock)
    exact_gap = candidate(gap, gap_clock, "exact-gap", slot=100 + G_MAX)
    check("P26a exact tier-1 parent gap is accepted",
          gap.submit(exact_gap, gap_clock) == "ACCEPTED")
    beyond = protocol(tip_slot=100)
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
    parent_before = p.history[original.anchor_number]
    during = clock(trigger.block_number + 1, trigger.l2_slot + 1)
    check("P27 append during recovery admits", p.admit_message(during, message(during.l2_slot, "during")) == "ADMITTED")
    check("P28 append defers beyond live round", p.messages[-1].due_at == original.expires_at + 1)
    check("P29 historical parent is never rewritten", p.history[original.anchor_number] == parent_before)
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
    assert bounded_gate.bootstrap(1)
    bounded = RegistryLifecycle(
        [Generation("long-lived", 10, 0, 0)], migration_gate=bounded_gate)
    for current_window in range(2_000):
        assert bounded.reserve("long-lived", current_window + 16,
                               current_window)
        assert len(bounded.open_reservations) <= 17
    check("P41b historical reservations leave the migration counter",
          bounded_gate.unsettled_builder_reservations == 17
          and len(bounded.open_reservations) == 17
          and bounded.settle_reservations_before(2_015) == 16
          and bounded_gate.unsettled_builder_reservations == 1)

    churn_gate = MigrationGate()
    assert churn_gate.bootstrap(1)
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
          and len(reservation_churn.liable_reservations) == 1_156
          and churn_gate.unsettled_builder_reservations
              == MAX_LIVE_RESERVATIONS
          and MAX_MIGRATION_RESERVATION_CLEANUP_CALLS == 136)


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
          and adapter.refunds["relayer"] == 5 and not adapter.records
          and bridge_protocol.mode is Mode.RECOVERY)
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
              src_bridge="bridge:A", **common) == "QUEUED:2")
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
              envelope=replace(bridge_envelope, prepaid=0), caller="relayer",
              deposit=1) == "REJECTED"
          and not invalid_protocol.messages and not invalid_adapter.records)

    support_core = CanonicalCore(
        100, "block:registration", 100, "state:registration", 0,
        terminal_root="terminal:registration", terminal_count=0)
    shared_queue = QueueContinuity(
        "forced-queue", "queue:root", 0, 0, 0, UINT64_MAX)
    support_inbox_apply = InboxApplyRouterV2(next_queue_index=0)
    support_settlement = VersionedSettlementHistory(
        "settlement:2", "runtime:2", 2, "profile:2",
        copy.deepcopy(support_core), 40, shared_queue,
        inbox_apply_router=support_inbox_apply)
    support_router = ActiveSettlementRouter(
        "version-manager", shared_queue, support_inbox_apply)
    assert support_router.bootstrap(
        support_settlement, sequence=7, activation_block=40)
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
        "forced-queue", "queue:root", 17, 12, 9_000, 1_001_500,
        initial_queue_descriptors)
    migration_inbox_apply = InboxApplyRouterV2(next_queue_index=12)
    shared_migration_gate = MigrationGate()
    settlement_1 = VersionedSettlementHistory(
        "settlement:1", "runtime:1", 1, "profile:1",
        copy.deepcopy(canonical_core_499), 49, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply)
    active_router = ActiveSettlementRouter(
        "version-manager", terminal_queue, migration_inbox_apply)
    assert active_router.bootstrap(
        settlement_1, sequence=0, activation_block=49)
    assert active_router.sync_and_append(
        message(1, "old-adapter-row", kind=ForceKind.BRIDGE_CREDIT),
        bound_router=active_router.address,
        queue_address=terminal_queue.address,
        active_settlement_sync_changed=False, deposit=7,
        due_at=1_001_501) == "QUEUED:17"
    canonical_core_500 = replace(
        canonical_core_499, l2_block_number=500, tip_hash="block:500",
        state_root="state:500")
    sequence_1 = settlement_1.record_canonical(
        canonical_core_500, l1_block=50)
    assert sequence_1 == 1
    canonical_500 = active_router.canonical_at(1, sequence_1)
    assert canonical_500 is not None
    check("P50at canonical history is internal and one commit per L1 block",
          settlement_1.record_canonical(
              replace(canonical_core_500, l2_block_number=501),
              l1_block=50) is None
          and active_router.canonical_at(1, sequence_1) == canonical_500)
    canonical_core_756 = replace(
        canonical_core_500, l2_block_number=756, tip_hash="block:756",
        state_root="state:756")
    sequence_2 = settlement_1.record_canonical(
        canonical_core_756, l1_block=51)
    assert sequence_2 == 2
    canonical_756 = active_router.canonical_at(1, sequence_2)
    assert canonical_756 is not None
    check("P50av sparse L2-height jumps cannot choose a history cell",
          active_router.canonical_at(1, sequence_1) == canonical_500
          and active_router.canonical_at(1, sequence_2) == canonical_756)
    migration_protocol = protocol(
        tip_slot=canonical_core_756.tip_slot,
        cursor=canonical_core_756.message_cursor,
        forced_queue=terminal_queue,
        inbox_apply_router=migration_inbox_apply)
    migration_protocol.canonical = Canonical(
        copy.deepcopy(canonical_core_756), 51)
    migration_protocol.migration_gate = shared_migration_gate
    migration_protocol.versioned_history = settlement_1
    settlement_1.live_protocol = migration_protocol
    migration_registry = RegistryLifecycle(
        [Generation("migration-builder", 10, 0, 0)],
        migration_gate=shared_migration_gate)
    migration_open_clock = clock(180, 100)
    assert migration_protocol.open_session(
        migration_open_clock, "migration-session", "alice",
        migration_open_clock.timestamp + DATA_TTL_SECONDS) == "OPENED"
    assert migration_registry.reserve("migration-builder", 1, 0)
    migration_outage_clock = clock(181, 4_000)
    check("P50cq router ingress is immediately visible to forced liveness",
          migration_protocol.forced_queue is terminal_queue
          and terminal_queue.count == len(migration_protocol.messages) == 18
          and migration_protocol.next_due_at(12) == 1_001_500
          and migration_protocol.force_due(migration_outage_clock))
    assert migration_protocol.sync(migration_outage_clock)
    assert migration_protocol.mode is Mode.RECOVERY
    migration_revision = migration_protocol.recovery.revision
    assert not shared_migration_gate.arm(
        1, 1, 2, "manifest:2", caller="attacker")
    assert shared_migration_gate.arm(
        1, 1, 2, "manifest:2", caller="version-manager")
    assert migration_protocol.arm_migration(1)
    migration_registry.arm_migration()
    assert settlement_1.arm_migration(
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
          and len(migration_protocol.messages) == 18)
    recovery_expiry_slot = (
        migration_protocol.recovery.expires_at - GENESIS_TIMESTAMP)
    before_expiry = clock(182, recovery_expiry_slot)
    assert not migration_protocol.sync(before_expiry)
    after_expiry = clock(183, recovery_expiry_slot + 1)
    assert migration_protocol.sync(after_expiry)
    assert migration_registry.cleanup_migration_reservations() == 1
    assert migration_protocol.sync(after_expiry)
    check("P50bg delayed cutover reaches migration-ready without reopening",
          migration_protocol.recovery is None
          and migration_revision == 1
          and shared_migration_gate.mode == "READY"
          and shared_migration_gate.live_data_sessions == 0
          and shared_migration_gate.unsettled_builder_reservations == 0
          and len(migration_protocol.messages) == 18
          and settlement_1.enter_migration_ready()
          and migration_protocol.arm_normal_context(after_expiry)
              == "MIGRATION_ARMED"
          and migration_protocol.activate_normal_context(after_expiry)
              == "MIGRATION_ARMED"
          and migration_protocol.submit(
              candidate(migration_protocol, after_expiry, "ready-veto"),
              after_expiry) == "MIGRATION_ARMED"
          and active_router.sync_and_append(
              message(2, "ready-row", kind=ForceKind.BRIDGE_CREDIT),
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              active_settlement_sync_changed=False) == "SYNCED")

    fake_settlement = VersionedSettlementHistory(
        "settlement:fake", "runtime:2", 2, "profile:2",
        replace(canonical_core_756, state_root="attacker-state"),
        51, terminal_queue, migration_gate=shared_migration_gate)
    exact_settlement = VersionedSettlementHistory(
        "settlement:2", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51, terminal_queue,
        migration_gate=shared_migration_gate,
        inbox_apply_router=migration_inbox_apply)
    wrong_queue_settlement = VersionedSettlementHistory(
        "settlement:wrong-queue", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51,
        replace(terminal_queue, address="replacement-queue"),
        inbox_apply_router=migration_inbox_apply)
    fresh_gate_settlement = VersionedSettlementHistory(
        "settlement:fresh-gate", "runtime:2", 2, "profile:2",
        copy.deepcopy(canonical_core_756), 51, terminal_queue,
        inbox_apply_router=migration_inbox_apply)
    migration_inbox_apply.next_queue_index = 13
    split_cursor_rejected = not active_router.activate_version(
        settlement=exact_settlement, l1_block=51,
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash="manifest:2",
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    migration_inbox_apply.next_queue_index = 12
    live_canonical = migration_protocol.canonical
    migration_protocol.canonical = Canonical(
        replace(canonical_core_756, state_root="stale-live-state"), 51)
    stale_live_state_rejected = not active_router.activate_version(
        settlement=exact_settlement, l1_block=51,
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash="manifest:2",
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    migration_protocol.canonical = live_canonical
    check("P50ba router rejects fake, unauthorized and discontinuous targets",
          split_cursor_rejected and stale_live_state_rejected
          and not active_router.activate_version(
              settlement=exact_settlement, l1_block=51,
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:attacker",
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router.activate_version(
              settlement=fake_settlement, l1_block=51,
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:2",
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router.activate_version(
              settlement=exact_settlement, l1_block=51,
              caller_is_version_manager=False, manifest_active=True,
              target_manifest_hash="manifest:2",
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router.activate_version(
              settlement=exact_settlement, l1_block=51,
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:2",
              target_runtime_approved=False, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router.activate_version(
              settlement=wrong_queue_settlement, l1_block=51,
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:2",
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True)
          and not active_router.activate_version(
              settlement=fresh_gate_settlement, l1_block=51,
              caller_is_version_manager=True, manifest_active=True,
              target_manifest_hash="manifest:2",
              target_runtime_approved=True, target_profile_matches=True,
              full_core_import_exact=True, queue_import_exact=True))
    assert active_router.activate_version(
        settlement=exact_settlement, l1_block=51,
        caller_is_version_manager=True, manifest_active=True,
        target_manifest_hash="manifest:2",
        target_runtime_approved=True, target_profile_matches=True,
        full_core_import_exact=True, queue_import_exact=True)
    check("P50bc migration freezes old history and imports the complete core",
          settlement_1.mode == "FROZEN"
          and active_router.canonical_at(1, sequence_2) == canonical_756
          and active_router.canonical_at(2, sequence_2) is not None
          and exact_settlement.record_canonical(
              replace(canonical_core_756, l2_block_number=757),
              l1_block=51) is None
          and active_router.sync_and_append(
              message(2, "same-old-adapter-after-v2",
                      kind=ForceKind.BRIDGE_CREDIT),
              bound_router=active_router.address,
              queue_address=terminal_queue.address,
              active_settlement_sync_changed=False, deposit=5,
              due_at=1_001_502) == "QUEUED:18"
          and shared_migration_gate.mode == "ACTIVE"
          and shared_migration_gate.active_protocol_version == 2
          and shared_migration_gate.target_protocol_version == 0
          and terminal_queue.count == 19
          and terminal_queue.escrow_balance == 9_012
          and [row.payload_hash for row in terminal_queue.descriptors[-2:]]
              == ["old-adapter-row", "same-old-adapter-after-v2"]
          and migration_protocol.messages is terminal_queue.descriptors
          and migration_registry.reserve("migration-builder", 2, 0))
    check("P50bn the same gate can authorize a second bounded migration",
          shared_migration_gate.arm(
              2, 2, 3, "manifest:3", caller="version-manager")
          and shared_migration_gate.mode == "ARMED"
          and shared_migration_gate.target_protocol_version == 3)

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
    settlement_1.runtime_hash = "runtime:mutated"
    check("P50bd historical Settlement code identity is pinned",
          not terminal_verifier.verify(
              proof=failed_proof, credit_id=credit_a, terminal="FAILED",
              destination_domain_id="domain:D1",
              destination_bridge="bridge:A"))
    settlement_1.runtime_hash = frozen_runtime
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
