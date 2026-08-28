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
MIN_FORCE_ACCOUNTED_GAS = 21_000
MAX_FORCE_RANGE_PROOF_HASHES = 129
FORCE_TREE_DEPTH = 32
MAX_FORCE_QUEUE_ITEMS = (1 << FORCE_TREE_DEPTH) - 1
L2_BLOCK_GAS_LIMIT = 30_000_000
ANCHOR_GAS_MAX = 1_000_000
SYSTEM_GAS_MARGIN = 5_000_000
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
DATA_TTL_SECONDS = 86_400
REORG_MARGIN_SECONDS = 1_800
UINT64_MAX = (1 << 64) - 1
G_MAX = DELTA_FINAL_LAG
MAX_ARM_AGE_BLOCKS = 255
EIP2935_HISTORY_ENTRIES = 8_191
L1_SLOT_SECONDS = 12

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
class RegistryLifecycle:
    active: list[Generation]
    liability_ring: list[tuple[Generation, int] | None] = field(
        default_factory=lambda: [None] * MAX_LIABILITY_GENERATIONS)
    replacements: dict[int, int] = field(default_factory=dict)
    movement_sequence: int = 0

    @property
    def liabilities(self) -> list[Generation]:
        return [item[0] for item in self.liability_ring if item is not None]

    def reserve(self, address: str, window: int, current_window: int) -> bool:
        for index, generation in enumerate(self.active):
            if generation.address != address:
                continue
            if (generation.reservations_closed
                    or window < current_window
                    or window > current_window + MAX_TRANCHE_AHEAD_WINDOWS):
                return False
            self.active[index] = replace(
                generation, max_reserved_window=max(generation.max_reserved_window, window))
            return True
        return False

    def release_liability(self, ring_index: int, current_window: int) -> bool:
        occupant = self.liability_ring[ring_index]
        if occupant is None or occupant[1] > current_window:
            return False
        self.liability_ring[ring_index] = None
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
    mode: Mode = Mode.NORMAL
    messages: list[Message] = field(default_factory=list)
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

    @property
    def core(self) -> CanonicalCore:
        return self.canonical.core

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

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

    def _prefix_end(self, start: int, cutoff: int) -> int:
        gas = size = count = 0
        cursor = start
        while cursor < min(cutoff, len(self.messages)):
            msg = self.messages[cursor]
            if (count + 1 > MAX_FORCE_MESSAGES
                    or gas + msg.accounted_gas > FORCE_GAS_BUDGET
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

    def sync(self, clock: Clock) -> bool:
        if self.mode is Mode.PREACTIVE:
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
                           l2_system_accounts_authenticated: bool = True) -> bool:
        if (self.mode is not Mode.PREACTIVE or clock.timestamp < GENESIS_TIMESTAMP
                or not old_quiescent or not router_switched
                or not header_checkpoint_authenticated
                or not l2_system_accounts_authenticated
                or imported.canonicalized_at_block != clock.block_number
                or imported.core.l2_block_number >= 1 << 48
                or imported.core.message_cursor != 0
                or imported.core.tip_slot > clock.l2_slot
                or imported.core.winning_data_commitment == "empty"
                or imported.core.next_base_fee <= 0):
            return False
        self.canonical = copy.deepcopy(imported)
        self.mode = Mode.NORMAL
        self.events.append("MIGRATION_ACTIVATED_ATOMICALLY")
        return True

    def tombstone(self) -> None:
        self.admission_version += 1
        self.admission_root = f"admission:{self.admission_version}"

    def admit_message(self, clock: Clock, message: Message) -> str:
        if self.sync(clock):
            return "SYNCED"
        if len(self.messages) >= MAX_FORCE_QUEUE_ITEMS:
            return "REJECTED"
        if message.kind is ForceKind.USER_TX:
            invalid = (not message.chain_id_ok or not message.signature_ok
                       or not message.outer_authorized or not message.sender
                       or message.valid_until <= clock.timestamp
                       or message.valid_until
                           > message.enqueued_at + MAX_FORCE_VALIDITY_SECONDS)
        else:
            invalid = not message.outer_authorized or message.valid_until != UINT64_MAX
        if (invalid or message.intrinsic_gas <= 0
                or message.accounted_gas < max(message.intrinsic_gas, MIN_FORCE_ACCOUNTED_GAS)
                or message.accounted_gas > MAX_FORCE_MESSAGE_GAS
                or not 0 < message.byte_length <= MAX_FORCE_MESSAGE_BYTES
                or message.prepaid <= 0):
            return "REJECTED"
        prior_due = self._due_at(self.messages[-1]) if self.messages else 0
        deferred = (self.recovery.expires_at + 1
                    if self.mode is Mode.RECOVERY and self.recovery else 0)
        due = max(message.enqueued_at + FORCE_DELAY, prior_due, deferred)
        index = len(self.messages)
        self.messages.append(replace(message, due_at=due))
        return "ADMITTED"

    def open_session(self, clock: Clock, session_id: str, owner: str, expiry: int) -> str:
        if self.sync(clock):
            return "SYNCED"
        self.gc_sessions(clock)
        if (not owner or session_id in self.sessions
                or expiry < clock.timestamp + P_PROVE_MAX + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
                or expiry > clock.timestamp + DATA_TTL_SECONDS
                or len(self.sessions) >= MAX_LIVE_DATA_SESSIONS
                or sum(s.owner == owner for s in self.sessions.values()) >= MAX_DATA_SESSIONS_PER_OWNER):
            return "REJECTED"
        self.sessions[session_id] = DataSession(session_id, owner, expiry)
        return "OPENED"

    def post_data(self, clock: Clock, session_id: str, caller: str, *,
                  body_root: str, same_tx_blobhash: bool, kzg_opening_ok: bool) -> str:
        if self.sync(clock):
            return "SYNCED"
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
            if (block.evm_timestamp != GENESIS_TIMESTAMP + block.slot
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
        self.canonical = Canonical(
            CanonicalCore(candidate.end_l2_block_number,
                          candidate.tip.block_hash, candidate.tip.slot,
                          candidate.end_state_root, candidate.tip.message_end,
                          candidate.winning_data_commitment,
                          candidate.next_base_fee,
                          candidate.next_excess_blob_gas),
            clock.block_number,
        )
        self.events.append(f"CANONICAL:{candidate.candidate_id}")


@dataclass
class BridgeAdapter:
    records: dict[str, tuple[str, Message, int | None]] = field(default_factory=dict)

    @staticmethod
    def credit_id(src_chain_id: int, src_bridge: str, msg_hash: str) -> str:
        return f"credit:{src_chain_id}:{src_bridge}:{msg_hash}"

    def prepare(self, src_chain_id: int, src_bridge: str, msg_hash: str,
                envelope: Message, source_authorized_at_emission: bool = True
                ) -> str | None:
        credit_id = self.credit_id(src_chain_id, src_bridge, msg_hash)
        if (credit_id in self.records
                or envelope.kind is not ForceKind.BRIDGE_CREDIT
                or not source_authorized_at_emission):
            return None
        self.records[credit_id] = ("PENDING", envelope, None)
        return credit_id

    def finalize(self, protocol_: Protocol, clock_: Clock, credit_id: str) -> str:
        state, envelope, index = self.records[credit_id]
        if state == "QUEUED":
            return f"QUEUED:{index}"
        result = protocol_.admit_message(clock_, envelope)
        if result == "ADMITTED":
            index = len(protocol_.messages) - 1
            self.records[credit_id] = ("QUEUED", envelope, index)
            return f"QUEUED:{index}"
        return result


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
             mode: Mode = Mode.NORMAL, messages: list[Message] | None = None) -> Protocol:
    msgs = list(messages or [])
    canonical = Canonical(CanonicalCore(900, "a" * 64, tip_slot, "b" * 64, cursor), 900)
    active = Seat("aggregator", 100) if seat else None
    return Protocol(canonical, make_history(msgs), mode, msgs, active_seat=active,
                    standby=[Seat("standby", 70)])


def block(p: Protocol, c: Clock, ident: str, *, slot: int | None = None,
          signed: bool = True, message_end: int | None = None,
          dispositions_ok: bool = True, discretionary: bool = True) -> Block:
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
    end = p._prefix_end(start, cutoff) if message_end is None else message_end
    context = (p.recovery.recovery_id if p.mode is Mode.RECOVERY and p.recovery
               else normal_context_id(p.canonical.base_hash, version, root,
                                      anchor_number, header.block_hash))
    return Block(slot, GENESIS_TIMESTAMP + slot,
                 f"{abs(hash(ident)) % (1 << 256):064x}", p.core.tip_hash,
                 slot // 384, signed, start, end, anchor_number, header.block_hash,
                 header.timestamp, force_root, cutoff,
                 context,
                 version, root,
                 dispositions_ok=dispositions_ok, discretionary_body=discretionary)


def candidate(p: Protocol, c: Clock, ident="candidate", *, tier=Tier.NORMAL_SIGNED,
              signed=True, slot=None, message_end=None, discretionary=True,
              force_range_proof_ok=True, recovery_fields_zero=True) -> Candidate:
    b = block(p, c, ident, slot=slot, signed=signed, message_end=message_end,
              discretionary=discretionary)
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
        l2_system_accounts_authenticated=False))
    check("P5 atomic router cutover imports exact state", p.activate_migration(clock(1_100, 1_100), imported, old_quiescent=True, router_switched=True))
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
    check("P16 non-expiring bridge credit admits", protocol().admit_message(c, bridge) == "ADMITTED")
    check("P17 gas geometry", ANCHOR_GAS_MAX + FORCE_GAS_BUDGET + SYSTEM_GAS_MARGIN <= L2_BLOCK_GAS_LIMIT)
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
    bridge_envelope = message(4_601, "bridge-record", kind=ForceKind.BRIDGE_CREDIT)
    credit_a = adapter.prepare(1, "bridge:A", "msg", bridge_envelope)
    credit_b = adapter.prepare(1, "bridge:B", "msg", bridge_envelope)
    check("P50e rotated authorized Bridges have distinct exactly-once identities",
          credit_a is not None and credit_b is not None and credit_a != credit_b
          and len(adapter.records) == 2
          and adapter.prepare(1, "bridge:A", "msg", bridge_envelope) is None)
    check("P50f unauthorized Bridge clone rejects at its emission height",
          adapter.prepare(1, "clone", "forged", bridge_envelope,
                          source_authorized_at_emission=False) is None)
    assert credit_a is not None and credit_b is not None
    transition_clock = clock(1_100, 4_601)
    check("P50c bridge SYNCED stays pending",
          adapter.finalize(bridge_protocol, transition_clock, credit_a) == "SYNCED"
          and adapter.records[credit_a][0] == "PENDING")
    check("P50d bridge retry queues exactly once",
          adapter.finalize(bridge_protocol, transition_clock, credit_a) == "QUEUED:0"
          and adapter.finalize(bridge_protocol, transition_clock, credit_a) == "QUEUED:0"
          and len(bridge_protocol.messages) == 1)
    check("P50g same message from next authorized epoch queues independently",
          adapter.finalize(bridge_protocol, transition_clock, credit_b) == "QUEUED:1"
          and len(bridge_protocol.messages) == 2)


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
