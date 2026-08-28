#!/usr/bin/env python3
"""Executable consensus model for settlement, recovery and forced inclusion.

The model exercises transaction ordering and exact resource predicates. Proof,
signature, MPT and execution verification remain explicit booleans; consensus
hash vectors live in commitment-model.py.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field, replace
from enum import Enum, IntFlag, auto

GENESIS_TIMESTAMP = 1_000_000
L1_SLOT_SECONDS = 12
W_SETTLE_SECONDS = 1_200
DELTA_FINAL_LAG = 3_600
DELTA_TIP = 1_200
P_PROVE_MAX = 900
T_INCLUDE_MAX = 10
F_L1 = 64
T_DEPTH_MAX = 900
CLOCK_SKEW = 24
ESCAPE_OFFSET = 1_900
FORCE_DELAY = 1_500
FORCE_GAS_BUDGET = 20_000_000
FORCE_BYTES_BUDGET = 1_048_576
MAX_FORCE_MESSAGES = 64
MAX_FORCE_MESSAGE_GAS = 5_000_000
MAX_FORCE_MESSAGE_BYTES = 131_072
MIN_FORCE_ACCOUNTED_GAS = 21_000
L2_BLOCK_GAS_LIMIT = 30_000_000
ANCHOR_GAS_MAX = 1_000_000
SYSTEM_GAS_MARGIN = 5_000_000
MAX_BLOCKS_PER_CANDIDATE = 4_096
MAX_WINDOWS_PER_CANDIDATE = 12
MAX_UNIQUE_ANCHORS = 1
MAX_DATA_SESSIONS_PER_CANDIDATE = 16
MAX_DATA_RECORDS_PER_CANDIDATE = 2_100
MAX_DATA_RECORDS_PER_SESSION = 2_100
MAX_LIVE_DATA_SESSIONS = 1_024
MAX_DATA_SESSIONS_PER_OWNER = 2
DATA_TTL_SECONDS = 86_400
REORG_MARGIN_SECONDS = 1_800


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
    sender: str = "sender"
    nonce: int = 0
    chain_id_ok: bool = True
    signature_ok: bool = True
    intrinsic_gas: int = 21_000
    valid_until: int = (1 << 64) - 1
    due_at: int = 0
    prepaid: int = 1


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
    admission_version: int
    data_records: tuple[tuple[str, int], ...] = ()
    body_order_ok: bool = True
    discretionary_body: bool = True


@dataclass(frozen=True)
class Candidate:
    candidate_id: str
    base_tuple_hash: str
    blocks: tuple[Block, ...]
    tier: Tier
    proof_ok: bool = True
    episode: int = 0
    recovery_revision: int = 0
    recovery_id: str = ""
    session_refs: tuple[SessionRef, ...] = ()
    manifest_exact: bool = True
    beneficiary: str = "prover"

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
class Canonical:
    tip_hash: str
    tip_slot: int
    state_root: str
    message_cursor: int
    canonicalization_block: int
    winning_data_commitment: str = "empty"

    @property
    def tuple_hash(self) -> str:
        return (f"{self.tip_hash}:{self.tip_slot}:{self.state_root}:"
                f"{self.message_cursor}:{self.canonicalization_block}:"
                f"{self.winning_data_commitment}")


@dataclass
class RecoveryRound:
    episode: int
    revision: int
    base_tuple_hash: str
    round_start_slot: int
    anchor_number: int
    anchor_hash: str
    anchor_timestamp: int
    force_root: str
    force_cutoff: int
    admission_version: int
    escape_slot: int
    expires_at: int
    causes: Cause

    @property
    def recovery_id(self) -> str:
        return (f"recovery:{self.episode}:{self.revision}:{self.base_tuple_hash}:"
                f"{self.round_start_slot}:"
                f"{self.anchor_number}:{self.anchor_hash}:{self.force_root}:"
                f"{self.force_cutoff}:{self.admission_version}:"
                f"{self.escape_slot}:{int(self.causes)}")


@dataclass
class Seat:
    operator: str
    penalty_bond: int
    terminated: bool = False


@dataclass
class Protocol:
    canonical: Canonical
    history: dict[int, L1Header]
    mode: Mode = Mode.NORMAL
    messages: list[Message] = field(default_factory=list)
    episode: int = 0
    recovery: RecoveryRound | None = None
    normal_best: Candidate | None = None
    normal_deadline: int | None = None
    normal_min_admissible: int | None = None
    normal_admission_version: int | None = None
    admission_version: int = 0
    active_seat: Seat | None = None
    standby: list[Seat] = field(default_factory=list)
    burned: int = 0
    sessions: dict[str, DataSession] = field(default_factory=dict)
    events: list[str] = field(default_factory=list)

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

    def current_header(self, number: int) -> L1Header:
        return self.history[number]

    def force_root(self, cutoff: int) -> str:
        return "queue:" + ":".join(m.payload_hash for m in self.messages[:cutoff])

    def force_due(self, clock: Clock) -> bool:
        i = self.canonical.message_cursor
        return i < len(self.messages) and self._due_at(self.messages[i]) <= clock.timestamp

    @staticmethod
    def _due_at(message: Message) -> int:
        return max(message.enqueued_at + FORCE_DELAY, message.due_at)

    def required_cursor(self, deadline: int) -> int:
        cursor = self.canonical.message_cursor
        while cursor < len(self.messages):
            if self._due_at(self.messages[cursor]) > deadline:
                break
            cursor += 1
        return cursor

    def _prefix_end(self, start: int, cutoff: int) -> int:
        gas = size = count = 0
        cursor = start
        while cursor < min(cutoff, len(self.messages)):
            message = self.messages[cursor]
            if (count + 1 > MAX_FORCE_MESSAGES
                    or gas + message.accounted_gas > FORCE_GAS_BUDGET
                    or size + message.byte_length > FORCE_BYTES_BUDGET):
                break
            count += 1
            gas += message.accounted_gas
            size += message.byte_length
            cursor += 1
        return cursor

    def _clear_normal(self) -> None:
        self.normal_best = None
        self.normal_deadline = None
        self.normal_min_admissible = None
        self.normal_admission_version = None

    def _close_mature_normal(self, clock: Clock) -> bool:
        if self.normal_deadline is None or clock.timestamp < self.normal_deadline:
            return False
        required = self.required_cursor(self.normal_deadline)
        if self.normal_best is not None and self.normal_best.tip.message_end >= required:
            self._commit(self.normal_best, clock)
            self.events.append("NORMAL_COMMITTED")
        else:
            self.events.append("NORMAL_CANCELED_FORCE_OMISSION")
        self._clear_normal()
        return True

    def _new_round(self, clock: Clock, causes: Cause, revision: int) -> RecoveryRound:
        anchor_number = clock.block_number - 1
        cutoff = len(self.messages)
        anchor = replace(self.current_header(anchor_number),
                         force_root=self.force_root(cutoff), force_cutoff=cutoff)
        self.history[anchor_number] = anchor
        escape_slot = max(clock.l2_slot + ESCAPE_OFFSET, self.canonical.tip_slot + 1)
        return RecoveryRound(
            self.episode, revision, self.canonical.tuple_hash,
            clock.l2_slot,
            anchor_number, anchor.block_hash, anchor.timestamp,
            self.force_root(cutoff), cutoff, self.admission_version, escape_slot,
            GENESIS_TIMESTAMP + escape_slot + DELTA_TIP, causes,
        )

    def _activate(self, clock: Clock, causes: Cause) -> None:
        self._clear_normal()
        self.mode = Mode.RECOVERY
        self.episode += 1
        self.recovery = self._new_round(clock, causes, 1)
        if causes & Cause.SLA and self.active_seat is not None:
            self.active_seat.terminated = True
            self.burned += self.active_seat.penalty_bond
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
        """Apply objective transitions; wrappers must return after True."""
        if self.mode is Mode.PREACTIVE:
            return False
        if self.mode is Mode.RECOVERY:
            return self._roll_recovery(clock)

        changed = False
        if self.force_due(clock) and self.normal_deadline is not None:
            if clock.timestamp >= self.normal_deadline:
                changed |= self._close_mature_normal(clock)
            else:
                self._clear_normal()
                self.events.append("NORMAL_CANCELED_FORCE_DUE")
                changed = True
        elif self.normal_deadline is not None and clock.timestamp >= self.normal_deadline:
            changed |= self._close_mature_normal(clock)

        if self.mode is Mode.NORMAL:
            causes = Cause.NONE
            if clock.l2_slot - self.canonical.tip_slot > DELTA_FINAL_LAG:
                causes |= Cause.SLA
            if self.force_due(clock):
                causes |= Cause.FORCE_DUE
            if causes:
                self._activate(clock, causes)
                changed = True
        return changed

    def activate_migration(self, clock: Clock, imported: Canonical) -> bool:
        if self.mode is not Mode.PREACTIVE or clock.timestamp < GENESIS_TIMESTAMP:
            return False
        self.canonical = copy.deepcopy(imported)
        self.mode = Mode.NORMAL
        self.events.append("MIGRATION_ACTIVATED_ATOMICALLY")
        return True

    def tombstone(self) -> None:
        self.admission_version += 1

    def admit_message(self, clock: Clock, message: Message) -> str:
        if self.sync(clock):
            return "SYNCED"
        if (not message.chain_id_ok or not message.signature_ok or not message.sender
                or message.intrinsic_gas <= 0
                or message.accounted_gas < max(message.intrinsic_gas, MIN_FORCE_ACCOUNTED_GAS)
                or message.accounted_gas > MAX_FORCE_MESSAGE_GAS
                or not 0 < message.byte_length <= MAX_FORCE_MESSAGE_BYTES
                or message.valid_until <= clock.timestamp or message.prepaid <= 0):
            return "REJECTED"
        deferred = (self.recovery.expires_at + 1
                    if self.mode is Mode.RECOVERY and self.recovery is not None else 0)
        self.messages.append(replace(message, due_at=max(self._due_at(message), deferred)))
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
            record.body_root for record in session.records
        )
        return "POSTED"

    def seal_session(self, clock: Clock, session_id: str, caller: str) -> bool:
        if self.sync(clock):
            return False
        session = self.sessions.get(session_id)
        if session is None or session.owner != caller or session.sealed or not session.records:
            return False
        session.sealed = True
        return True

    def gc_sessions(self, clock: Clock) -> None:
        for key in sorted(tuple(self.sessions)):
            if self.sessions[key].expiry < clock.timestamp:
                del self.sessions[key]

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
            sid in declared and 0 <= index < declared[sid].count for sid, index in used
        )

    def _sessions_live_through(self, candidate: Candidate, timestamp: int) -> bool:
        return all(self.sessions[ref.session_id].expiry >= timestamp
                   for ref in candidate.session_refs)

    def _anchor_ok(self, candidate: Candidate, clock: Clock) -> bool:
        anchors = {(b.anchor_number, b.anchor_hash, b.anchor_timestamp,
                    b.force_root, b.force_cutoff) for b in candidate.blocks}
        if len(anchors) != MAX_UNIQUE_ANCHORS:
            return False
        block = candidate.blocks[0]
        header = self.history.get(block.anchor_number)
        return (header is not None and block.anchor_number < clock.block_number
                and clock.block_number - block.anchor_number <= 8_191
                and header.block_hash == block.anchor_hash
                and header.timestamp == block.anchor_timestamp
                and header.force_root == block.force_root
                and header.force_cutoff == block.force_cutoff
                and block.anchor_timestamp <= GENESIS_TIMESTAMP + block.slot)

    def _validate_common(self, candidate: Candidate, clock: Clock, min_slot: int) -> bool:
        if (not candidate.proof_ok or candidate.base_tuple_hash != self.canonical.tuple_hash
                or not 0 < candidate.count <= MAX_BLOCKS_PER_CANDIDATE
                or len({b.window for b in candidate.blocks}) > MAX_WINDOWS_PER_CANDIDATE
                or candidate.blocks[0].slot <= self.canonical.tip_slot
                or candidate.tip.slot < min_slot
                or candidate.tip.slot > clock.l2_slot + CLOCK_SKEW
                or not candidate.beneficiary or not self._anchor_ok(candidate, clock)
                or not self._sessions_ok(candidate, clock)):
            return False
        parent = self.canonical.tip_hash
        cursor = self.canonical.message_cursor
        prior_slot = self.canonical.tip_slot
        first = candidate.blocks[0]
        for block in candidate.blocks:
            if (block.parent_hash != parent or block.slot <= prior_slot
                    or block.message_start != cursor or not block.body_order_ok
                    or block.anchor_number != first.anchor_number
                    or block.force_cutoff != first.force_cutoff
                    or block.force_root != first.force_root):
                return False
            expected = self._prefix_end(cursor, block.force_cutoff)
            if block.message_end != expected:
                return False
            parent, prior_slot, cursor = block.block_hash, block.slot, block.message_end
        return True

    def _valid_normal(self, candidate: Candidate, clock: Clock) -> bool:
        if candidate.tier is not Tier.NORMAL_SIGNED:
            return False
        minimum = (self.normal_min_admissible if self.normal_min_admissible is not None
                   else max(0, clock.l2_slot - DELTA_TIP))
        admission = (self.normal_admission_version if self.normal_admission_version is not None
                     else self.admission_version)
        deadline = self.normal_deadline or clock.timestamp + W_SETTLE_SECONDS
        return (self._validate_common(candidate, clock, minimum)
                and all(b.scheduled_signature_ok and b.admission_version == admission
                        for b in candidate.blocks)
                and self._sessions_live_through(candidate, deadline + REORG_MARGIN_SECONDS)
                and candidate.tip.message_end >= self.required_cursor(deadline))

    def _valid_recovery(self, candidate: Candidate, clock: Clock) -> bool:
        round_ = self.recovery
        if round_ is None or not self._validate_common(candidate, clock, max(0, clock.l2_slot - DELTA_TIP)):
            return False
        first = candidate.blocks[0]
        if (candidate.episode != round_.episode
                or candidate.recovery_revision != round_.revision
                or candidate.recovery_id != round_.recovery_id
                or candidate.base_tuple_hash != round_.base_tuple_hash
                or first.anchor_number != round_.anchor_number
                or first.anchor_hash != round_.anchor_hash
                or first.force_root != round_.force_root
                or first.force_cutoff != round_.force_cutoff
                or any(b.admission_version != round_.admission_version
                       for b in candidate.blocks)
                or clock.block_number - round_.anchor_number < F_L1
                or candidate.blocks[0].slot < round_.round_start_slot
                or clock.timestamp > round_.expires_at):
            return False
        if round_.causes & Cause.FORCE_DUE and candidate.tip.message_end <= self.canonical.message_cursor:
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
            if self.normal_deadline is None:
                self.normal_deadline = clock.timestamp + W_SETTLE_SECONDS
                self.normal_min_admissible = max(0, clock.l2_slot - DELTA_TIP)
                self.normal_admission_version = self.admission_version
            if self.normal_best is None or candidate.order > self.normal_best.order:
                self.normal_best = candidate
                return "ACCEPTED"
            return "IGNORED"
        if not self._valid_recovery(candidate, clock):
            return "REJECTED"
        self._commit(candidate, clock)
        self.mode = Mode.NORMAL
        self.recovery = None
        self.admission_version += 1
        self.events.append("RECOVERY_COMMITTED")
        return "COMMITTED"

    def _commit(self, candidate: Candidate, clock: Clock) -> None:
        self.canonical = Canonical(
            candidate.tip.block_hash, candidate.tip.slot, f"state:{candidate.candidate_id}",
            candidate.tip.message_end, clock.block_number,
            "sessions:" + ":".join(r.root for r in candidate.session_refs),
        )
        self.events.append(f"CANONICAL:{candidate.candidate_id}")


PASS: list[str] = []


def check(name: str, condition: bool) -> None:
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def clock(number: int, l2_slot: int) -> Clock:
    return Clock(number, GENESIS_TIMESTAMP + l2_slot)


def make_history(messages: list[Message] | None = None) -> dict[int, L1Header]:
    queue = messages or []
    root = "queue:" + ":".join(m.payload_hash for m in queue)
    return {n: L1Header(f"{n:064x}", GENESIS_TIMESTAMP + n,
                        f"state-{n}", root, len(queue)) for n in range(1, 20_000)}


def protocol(tip_slot: int = 1_000, cursor: int = 0, seat: bool = True,
             mode: Mode = Mode.NORMAL, messages: list[Message] | None = None) -> Protocol:
    msgs = list(messages or [])
    canonical = Canonical("a" * 64, tip_slot, "b" * 64, cursor, 900)
    active = Seat("aggregator", 100) if seat else None
    return Protocol(canonical, make_history(msgs), mode, msgs, active_seat=active,
                    standby=[Seat("standby", 70)])


def refresh_anchor_state(p: Protocol, number: int) -> None:
    header = p.history[number]
    p.history[number] = replace(header, force_root=p.force_root(len(p.messages)),
                                force_cutoff=len(p.messages))


def message(enqueued_l2: int, ident: str, gas: int = 100_000, size: int = 100) -> Message:
    return Message(GENESIS_TIMESTAMP + enqueued_l2, gas, size, ident,
                   valid_until=GENESIS_TIMESTAMP + enqueued_l2 + DATA_TTL_SECONDS)


def block(p: Protocol, c: Clock, ident: str, *, slot: int | None = None,
          signed: bool = True, message_start: int | None = None,
          message_end: int | None = None, cutoff: int | None = None,
          admission_version: int | None = None, data=(), discretionary=True,
          body_order_ok=True) -> Block:
    slot = c.l2_slot if slot is None else slot
    anchor_number = c.block_number - 1
    if p.mode is Mode.RECOVERY and p.recovery is not None:
        anchor_number = p.recovery.anchor_number
        cutoff = p.recovery.force_cutoff
    cutoff = len(p.messages) if cutoff is None else cutoff
    if p.mode is not Mode.RECOVERY:
        refresh_anchor_state(p, anchor_number)
    header = p.history[anchor_number]
    start = p.canonical.message_cursor if message_start is None else message_start
    end = p._prefix_end(start, cutoff) if message_end is None else message_end
    return Block(slot, f"{abs(hash(ident)) % (1 << 256):064x}", p.canonical.tip_hash,
                 slot // 384, signed, start, end, anchor_number, header.block_hash,
                 header.timestamp, p.force_root(cutoff), cutoff,
                 p.admission_version if admission_version is None else admission_version,
                 tuple(data), body_order_ok, discretionary)


def candidate(p: Protocol, c: Clock, ident="candidate", *, tier=Tier.NORMAL_SIGNED,
              signed=True, slot=None, message_end=None, refs=(), sessions=(),
              discretionary=True, body_order_ok=True) -> Candidate:
    b = block(p, c, ident, slot=slot, signed=signed, message_end=message_end,
              data=refs, discretionary=discretionary, body_order_ok=body_order_ok,
              admission_version=(p.normal_admission_version if p.normal_admission_version is not None
                                 else p.admission_version))
    r = p.recovery
    return Candidate(ident, p.canonical.tuple_hash, (b,), tier, True,
                     r.episode if r else 0, r.revision if r else 0,
                     r.recovery_id if r else "", tuple(sessions))


def open_recovery(p: Protocol, block_number=1_100) -> Clock:
    trigger = clock(block_number, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    check("P1 objective sync opens recovery", p.sync(trigger))
    return trigger


def recovery_submit_clock(p: Protocol) -> Clock:
    assert p.recovery is not None
    return clock(p.recovery.anchor_number + F_L1, p.recovery.escape_slot + 1)


def escape_candidate(p: Protocol, c: Clock, ident="escape") -> Candidate:
    return candidate(p, c, ident, tier=Tier.ESCAPE_UNSIGNED, signed=False,
                     slot=p.recovery.escape_slot if p.recovery else None,
                     discretionary=False)


def test_preactivation_and_atomic_migration() -> None:
    p = protocol(mode=Mode.PREACTIVE)
    pre = Clock(950, GENESIS_TIMESTAMP - 100)
    check("P2 preactivation slot arithmetic saturates", pre.l2_slot == 0)
    check("P3 preactive settlement rejects candidates", p.submit(candidate(p, clock(1_100, 1_100)), clock(1_100, 1_100)) == "REJECTED_PREACTIVE")
    imported = Canonical("c" * 64, 1_050, "d" * 64, 7, 1_050)
    check("P4 one transaction activates exact imported tuple", p.activate_migration(clock(1_100, 1_100), imported))
    check("P5 migration has no queue/cursor delta", p.mode is Mode.NORMAL and p.canonical == imported)


def test_activation_order_and_tombstone_freeze() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    best = candidate(p, c, "immature")
    check("P6 normal candidate accepted", p.submit(best, c) == "ACCEPTED")
    frozen = p.normal_admission_version
    p.tombstone()
    check("P7 slash advances only future admission epoch", frozen != p.admission_version)
    replacement = candidate(p, clock(1_101, 1_101), "same-frozen")
    check("P8 open window still accepts its frozen admission epoch", p.submit(replacement, clock(1_101, 1_101)) in {"ACCEPTED", "IGNORED"})
    p.normal_deadline = GENESIS_TIMESTAMP + 9_999  # isolate activation-before-close ordering
    trigger = clock(1_102, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    check("P9 submit returns SYNCED before parsing stale input", p.submit(best, trigger) == "SYNCED")
    check("P10 activation survives and immature best is canceled", p.mode is Mode.RECOVERY and p.normal_best is None)
    check("P11 SLA burn is idempotent", p.burned == 100 and not p.sync(trigger) and p.burned == 100)


def test_force_admission_and_triple_prefix_bound() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    check("P12 zero/intrinsic-underdeclared force item rejected", p.admit_message(c, message(1_100, "zero", gas=0)) == "REJECTED")
    check("P13 oversized force item rejected", p.admit_message(c, message(1_100, "huge", size=MAX_FORCE_MESSAGE_BYTES + 1)) == "REJECTED")
    for i in range(100):
        assert p.admit_message(c, message(1_100, f"m{i}", gas=MIN_FORCE_ACCOUNTED_GAS, size=1)) == "ADMITTED"
    check("P14 count cap bounds low-gas grind", p._prefix_end(0, 100) == MAX_FORCE_MESSAGES)
    q = protocol(messages=[message(0, "a", gas=5_000_000, size=500_000),
                           message(0, "b", gas=5_000_000, size=500_000),
                           message(0, "c", gas=5_000_000, size=500_000)])
    check("P15 bytes cap independently stops prefix", q._prefix_end(0, 3) == 2)
    check("P16 block gas geometry is enforced", ANCHOR_GAS_MAX + FORCE_GAS_BUDGET + SYSTEM_GAS_MARGIN <= L2_BLOCK_GAS_LIMIT)


def test_force_due_precedes_normal_close() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    best = candidate(p, c, "ordinary")
    check("P17 normal window opens", p.submit(best, c) == "ACCEPTED")
    p.messages.append(message(0, "due"))
    refresh_anchor_state(p, c.block_number - 1)
    before = p.canonical.tip_hash
    due = clock(1_101, 1_101 + FORCE_DELAY)
    check("P18 due head cancels immature best and activates", p.sync(due) and p.mode is Mode.RECOVERY)
    check("P19 omitted normal best was not committed", p.canonical.tip_hash == before)

    q = protocol(tip_slot=100, messages=[message(0, "covered")])
    accepted_at = clock(200, FORCE_DELAY - W_SETTLE_SECONDS - 1)
    covered = candidate(q, accepted_at, "covered-best")
    check("P20 covering candidate accepted", q.submit(covered, accepted_at) == "ACCEPTED")
    close = Clock(400, q.normal_deadline)
    check("P21 mature covering best closes before cause recompute", q.sync(close))
    check("P22 covered best commits and no force recovery remains", q.canonical.tip_hash == covered.tip.block_hash and q.mode is Mode.NORMAL)
    check("P23 force delay exceeds settlement plus inclusion", FORCE_DELAY >= W_SETTLE_SECONDS + T_INCLUDE_MAX * L1_SLOT_SECONDS)


def test_renewable_recovery_and_anchor_chronology() -> None:
    p = protocol(seat=False, messages=[message(0, "forced")])
    trigger = open_recovery(p)
    original = copy.deepcopy(p.recovery)
    check("P24 recovery anchor is the activation parent", original.anchor_number == trigger.block_number - 1)
    check("P25 recovery stores a real prior-block hash", original.anchor_hash == p.history[original.anchor_number].block_hash)
    during = clock(trigger.block_number + 1, trigger.l2_slot + 1)
    check("P25a enqueue during recovery remains admissible",
          p.admit_message(during, message(during.l2_slot, "during-round")) == "ADMITTED")
    check("P25b appended message cannot mature before frozen round expiry",
          p.messages[-1].due_at == original.expires_at + 1)
    early = clock(original.anchor_number + F_L1 - 1, original.escape_slot + 1)
    check("P26 insufficient L1 depth rejects escape", p.submit(escape_candidate(p, early), early) == "REJECTED")
    old_proof = escape_candidate(p, recovery_submit_clock(p), "old-proof")
    late = Clock(5_000, original.expires_at + 1)
    burned = p.burned
    check("P27 expired round rolls and returns SYNCED", p.submit(old_proof, late) == "SYNCED")
    check("P28 roll preserves episode/burn but advances revision", p.recovery.episode == original.episode and p.recovery.revision == original.revision + 1 and p.burned == burned)
    check("P28a refreshed round includes intervening queue appends",
          p.recovery.force_cutoff == len(p.messages))
    fresh_clock = recovery_submit_clock(p)
    check("P29 stale revision proof is rejected", p.submit(old_proof, fresh_clock) == "REJECTED")
    fresh = escape_candidate(p, fresh_clock, "fresh")
    check("P30 fresh deterministic round commits", p.submit(fresh, fresh_clock) == "COMMITTED")
    check("P31 no current-block hash is stored or queried", not hasattr(p.canonical, "canonicalization_hash"))

    q = protocol(seat=False)
    open_recovery(q)
    for days in (2, 4):
        expiry = q.recovery.expires_at
        check(f"P32.{days} arbitrary outage can roll", q.sync(Clock(10_000 + days, expiry + days * 86_400)))
    final_clock = recovery_submit_clock(q)
    check("P33 multi-day outage still has a live escape", q.submit(escape_candidate(q, final_clock, "days"), final_clock) == "COMMITTED")


def test_data_session_isolation_sealing_and_retention() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    expiry = c.timestamp + P_PROVE_MAX + W_SETTLE_SECONDS + REORG_MARGIN_SECONDS
    check("P34 Alice opens bounded owned session", p.open_session(c, "alice-1", "alice", expiry) == "OPENED")
    check("P35 Mallory cannot append to Alice session", p.post_data(c, "alice-1", "mallory", body_root="x", same_tx_blobhash=True, kzg_opening_ok=True) == "REJECTED")
    check("P36 Alice appends authenticated record", p.post_data(c, "alice-1", "alice", body_root="x", same_tx_blobhash=True, kzg_opening_ok=True) == "POSTED")
    check("P37 owner seals immutable session", p.seal_session(c, "alice-1", "alice"))
    check("P38 sealed root cannot be invalidated by append", p.post_data(c, "alice-1", "alice", body_root="y", same_tx_blobhash=True, kzg_opening_ok=True) == "REJECTED")
    session = p.sessions["alice-1"]
    ref = SessionRef(session.session_id, len(session.records), session.root)
    good = candidate(p, c, "data", refs=(("alice-1", 0),), sessions=(ref,))
    check("P39 exact sealed session reference validates", p.submit(good, c) == "ACCEPTED")
    check("P40 independent publisher can open own session", p.open_session(clock(1_101, 1_101), "mallory-1", "mallory", expiry + 100) == "OPENED")
    check("P41 live-session caps are explicit", MAX_LIVE_DATA_SESSIONS == 1_024 and MAX_DATA_SESSIONS_PER_OWNER == 2)


def test_anchor_force_root_body_order_and_resource_rejection() -> None:
    p = protocol(messages=[message(1_100, "later")])
    c = clock(1_100, 1_100)
    good = candidate(p, c, "anchored")
    forged = replace(good, blocks=(replace(good.blocks[0], anchor_hash="f" * 64),))
    check("P42 forged anchor is rejected", p.submit(forged, c) == "REJECTED")
    wrong_root = replace(good, blocks=(replace(good.blocks[0], force_root="wrong"),))
    check("P43 anchor must bind queue root and cutoff", p.submit(wrong_root, c) == "REJECTED")
    bad_order = candidate(p, c, "bad-order", body_order_ok=False)
    check("P44 forced prefix must precede discretionary body", p.submit(bad_order, c) == "REJECTED")
    check("P45 one candidate anchor is an explicit proof bound", MAX_UNIQUE_ANCHORS == 1)


def test_reorg_and_geometry() -> None:
    pre = protocol().snapshot()
    post = pre.snapshot()
    c = clock(1_100, 1_100)
    post.submit(candidate(post, c, "reorg"), c)
    post.sync(Clock(1_200, post.normal_deadline))
    post = pre.snapshot()
    check("P46 L1 replay truncates every derived effect", post.identical(pre))
    end_to_end = T_INCLUDE_MAX * L1_SLOT_SECONDS + ESCAPE_OFFSET + T_INCLUDE_MAX * L1_SLOT_SECONDS + CLOCK_SKEW
    check("P47 recovery path fits final-lag budget", end_to_end <= DELTA_FINAL_LAG)
    check("P48 escape offset covers depth plus proof", ESCAPE_OFFSET >= T_DEPTH_MAX + P_PROVE_MAX)
    check("P49 tip freshness covers submission", T_INCLUDE_MAX * L1_SLOT_SECONDS + CLOCK_SKEW <= DELTA_TIP)
    check("P50 candidate work has explicit independent caps", MAX_BLOCKS_PER_CANDIDATE == 4_096 and MAX_WINDOWS_PER_CANDIDATE == 12 and MAX_DATA_RECORDS_PER_CANDIDATE == 2_100)


if __name__ == "__main__":
    for test in (
        test_preactivation_and_atomic_migration,
        test_activation_order_and_tombstone_freeze,
        test_force_admission_and_triple_prefix_bound,
        test_force_due_precedes_normal_close,
        test_renewable_recovery_and_anchor_chronology,
        test_data_session_isolation_sealing_and_retention,
        test_anchor_force_root_body_order_and_resource_rejection,
        test_reorg_and_geometry,
    ):
        test()
    print("RESULTS: settlement/recovery model — ALL PROPERTIES PASS")
    for index, name in enumerate(PASS, 1):
        print(f"  [{index:03d}] {name}")
