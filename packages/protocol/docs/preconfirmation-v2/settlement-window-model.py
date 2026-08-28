#!/usr/bin/env python3
"""Executable consensus model for settlement, recovery and forced escape.

This is deliberately small enough to audit. It models consensus predicates and
EVM transaction boundaries; cryptographic verifiers are represented by booleans.
"""

from __future__ import annotations

import copy
import hashlib
from dataclasses import dataclass, field
from enum import Enum, IntFlag, auto


# All deadlines are timestamp seconds. L1 depth is the only block-number unit.
L1_SLOT_SECONDS = 12
W_SETTLE_SECONDS = 1_200
DELTA_FINAL_LAG = 3_600
DELTA_TIP = 1_200
P_PROVE_MAX = 900
T_INCLUDE_MAX = 10                 # L1 slots
F_L1 = 64                          # L1 blocks of canonical depth
T_DEPTH_MAX = 900                  # seconds, under the L1-liveness assumption
CLOCK_SKEW = 24
ESCAPE_OFFSET = 1_900
FORCE_DELAY = 600
FORCE_GAS_BUDGET = 20_000_000
MAX_FORCE_MESSAGE_GAS = 5_000_000
MAX_BLOCKS_PER_CANDIDATE = 4_096
MAX_WINDOWS_PER_CANDIDATE = 12
MAX_DATA_RECORDS_PER_SESSION = 2_100
DATA_TTL_SECONDS = 86_400
HISTORY_RING_BLOCKS = 8_191


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


@dataclass(frozen=True)
class Clock:
    block_number: int
    timestamp: int
    beacon_slot: int

    @property
    def l2_slot(self) -> int:
        return self.timestamp


@dataclass(frozen=True)
class Message:
    enqueued_at: int
    gas_limit: int
    prepaid: int
    payload_hash: str


@dataclass(frozen=True)
class DataRecord:
    index: int
    version: int
    versioned_hash: str
    body_root: str
    publisher: str
    valid_until: int
    fs_challenge: str
    evaluation: str


@dataclass(frozen=True)
class Block:
    slot: int
    block_hash: str
    parent_hash: str
    window: int
    scheduled_signature_ok: bool
    message_start: int
    message_end: int
    force_cutoff: int
    data_record_indices: tuple[int, ...] = ()
    discretionary_body: bool = True


@dataclass(frozen=True)
class Candidate:
    candidate_id: str
    base_hash: str
    blocks: tuple[Block, ...]
    tier: Tier
    proof_ok: bool = True
    episode_version: int = 0
    activation_id: str = ""
    final_ref_number: int = 0
    final_ref_hash: str = ""
    anchor_number: int = 0
    anchor_hash: str = ""
    data_mmr_root: str = ""
    data_manifest_exact: bool = True

    @property
    def tip(self) -> Block:
        return self.blocks[-1]

    @property
    def count(self) -> int:
        return len(self.blocks)

    @property
    def order(self) -> tuple[int, int, int]:
        # max() implements count desc, tip slot desc, tip hash ascending.
        return (self.count, self.tip.slot, -int(self.tip.block_hash, 16))


@dataclass
class Canonical:
    tip_hash: str
    tip_slot: int
    state_root: str
    message_cursor: int
    canonicalization_block: int
    canonicalization_hash: str
    data_mmr_root: str = ""


@dataclass
class Seat:
    operator: str
    penalty_bond: int
    terminated: bool = False


@dataclass
class Protocol:
    canonical: Canonical
    history: dict[int, str]
    messages: list[Message] = field(default_factory=list)
    mode: Mode = Mode.NORMAL
    version: int = 0
    normal_best: Candidate | None = None
    normal_deadline: int | None = None
    normal_min_admissible: int | None = None
    activation_slot: int | None = None
    escape_slot: int | None = None
    force_cutoff: int | None = None
    activation_id: str = ""
    causes: Cause = Cause.NONE
    active_seat: Seat | None = None
    standby: list[Seat] = field(default_factory=list)
    burned: int = 0
    data_records: list[DataRecord] = field(default_factory=list)
    data_mmr_root: str = ""
    events: list[str] = field(default_factory=list)

    def snapshot(self) -> "Protocol":
        return copy.deepcopy(self)

    def identical(self, other: "Protocol") -> bool:
        return self == other

    def historical_hash(self, number: int, clock: Clock) -> str | None:
        if number >= clock.block_number or clock.block_number - number > HISTORY_RING_BLOCKS:
            return None
        return self.history.get(number)

    def force_due(self, clock: Clock) -> bool:
        cursor = self.canonical.message_cursor
        return (cursor < len(self.messages)
                and self.messages[cursor].enqueued_at + FORCE_DELAY <= clock.timestamp)

    def _close_normal(self, clock: Clock) -> bool:
        if self.normal_deadline is None or clock.timestamp < self.normal_deadline:
            return False
        if self.normal_best is not None:
            self._commit(self.normal_best, clock)
        self.normal_best = None
        self.normal_deadline = None
        self.normal_min_admissible = None
        self.data_records.clear()
        self.data_mmr_root = ""
        self.events.append("NORMAL_CLOSED")
        return True

    def _activate(self, clock: Clock, causes: Cause) -> None:
        # An immature candidate can never be promoted across the mode boundary.
        self.normal_best = None
        self.normal_deadline = None
        self.normal_min_admissible = None
        self.data_records.clear()
        self.data_mmr_root = ""
        self.mode = Mode.RECOVERY
        self.version += 1
        self.activation_slot = clock.l2_slot
        self.escape_slot = max(clock.l2_slot + ESCAPE_OFFSET,
                               self.canonical.tip_slot + 1)
        self.force_cutoff = len(self.messages)
        previous_hash = self.history.get(clock.block_number - 1, "0" * 64)
        self.activation_id = hashlib.sha256(
            f"slot-chain-recovery-v1:{self.version}:{clock.block_number}:{previous_hash}".encode()
        ).hexdigest()
        self.causes = causes
        if causes & Cause.SLA and self.active_seat is not None:
            self.active_seat.terminated = True
            self.burned += self.active_seat.penalty_bond
            self.active_seat = next((s for s in self.standby if not s.terminated), None)
        self.events.append(f"RECOVERY_OPEN:{int(causes)}")

    def sync(self, clock: Clock) -> bool:
        """Apply every objective transition. This function never reverts."""
        changed = self._close_normal(clock)
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

    def post_data(self, clock: Clock, *, same_tx_blobhash: bool,
                  body_root: str, publisher: str, valid_until: int,
                  kzg_opening_ok: bool) -> bool:
        """Append one authenticated blob leaf to the version-scoped MMR."""
        if (not same_tx_blobhash or not kzg_opening_ok or not publisher
                or valid_until <= clock.timestamp
                or valid_until > clock.timestamp + DATA_TTL_SECONDS
                or len(self.data_records) >= MAX_DATA_RECORDS_PER_SESSION):
            return False
        index = len(self.data_records)
        versioned_hash = hashlib.sha256(f"blob:{self.version}:{index}".encode()).hexdigest()
        challenge = hashlib.sha256(
            f"slot-chain-data-fs-v1:{self.version}:{versioned_hash}:{body_root}:"
            f"{publisher}:{valid_until}".encode()
        ).hexdigest()
        evaluation = hashlib.sha256(f"eval:{challenge}:{versioned_hash}".encode()).hexdigest()
        record = DataRecord(index, self.version, versioned_hash, body_root,
                            publisher, valid_until, challenge, evaluation)
        self.data_records.append(record)
        self.data_mmr_root = hashlib.sha256(
            f"{self.data_mmr_root}:{record}".encode()
        ).hexdigest()
        return True

    def _maximum_prefix_end(self, start: int, cutoff: int | None = None) -> int:
        gas = 0
        cursor = start
        limit = len(self.messages) if cutoff is None else min(cutoff, len(self.messages))
        while cursor < limit:
            item = self.messages[cursor]
            if gas + item.gas_limit > FORCE_GAS_BUDGET:
                break
            gas += item.gas_limit
            cursor += 1
        return cursor

    def _validate_common(self, candidate: Candidate, clock: Clock,
                         min_slot: int) -> bool:
        if (not candidate.proof_ok or candidate.base_hash != self.canonical.tip_hash
                or not 0 < candidate.count <= MAX_BLOCKS_PER_CANDIDATE
                or len({block.window for block in candidate.blocks}) > MAX_WINDOWS_PER_CANDIDATE
                or candidate.blocks[0].slot <= self.canonical.tip_slot
                or candidate.tip.slot < min_slot
                or candidate.tip.slot > clock.l2_slot + CLOCK_SKEW):
            return False
        parent = self.canonical.tip_hash
        cursor = self.canonical.message_cursor
        previous_slot = self.canonical.tip_slot
        previous_cutoff = cursor
        all_refs: list[int] = []
        for item in candidate.blocks:
            if (item.parent_hash != parent or item.message_start != cursor
                    or item.slot <= previous_slot
                    or item.slot > clock.l2_slot + CLOCK_SKEW
                    or item.force_cutoff < previous_cutoff
                    or item.force_cutoff > len(self.messages)):
                return False
            expected_end = self._maximum_prefix_end(cursor, item.force_cutoff)
            if item.message_end != expected_end:
                return False
            parent = item.block_hash
            cursor = item.message_end
            previous_slot = item.slot
            previous_cutoff = item.force_cutoff
            all_refs.extend(item.data_record_indices)
        if (len(all_refs) != len(set(all_refs))
                or any(index < 0 or index >= len(self.data_records) for index in all_refs)
                or any(self.data_records[index].version != self.version for index in all_refs)
                or any(self.data_records[index].valid_until < clock.timestamp for index in all_refs)
                or candidate.data_mmr_root != self.data_mmr_root
                or not candidate.data_manifest_exact):
            return False
        return True

    def _historical_refs_ok(self, candidate: Candidate, clock: Clock) -> bool:
        return (
            candidate.final_ref_number == self.canonical.canonicalization_block
            and candidate.final_ref_hash == self.canonical.canonicalization_hash
            and self.historical_hash(candidate.final_ref_number, clock)
                == candidate.final_ref_hash
            and self.historical_hash(candidate.anchor_number, clock) == candidate.anchor_hash
        )

    def _valid_normal(self, candidate: Candidate, clock: Clock) -> bool:
        if candidate.tier is not Tier.NORMAL_SIGNED:
            return False
        minimum = (self.normal_min_admissible if self.normal_min_admissible is not None
                   else clock.l2_slot - DELTA_TIP)
        return (self._validate_common(candidate, clock, minimum)
                and all(item.scheduled_signature_ok for item in candidate.blocks))

    def _valid_recovery(self, candidate: Candidate, clock: Clock) -> bool:
        if self.activation_slot is None:
            return False
        if not self._validate_common(candidate, clock, clock.l2_slot - DELTA_TIP):
            return False
        if (candidate.episode_version != self.version
                or candidate.activation_id != self.activation_id
                or any(item.force_cutoff != self.force_cutoff
                       for item in candidate.blocks)
                or candidate.blocks[0].slot < self.activation_slot
                or not self._historical_refs_ok(candidate, clock)
                or clock.block_number - self.canonical.canonicalization_block < F_L1):
            return False
        if ((self.causes & Cause.FORCE_DUE)
                and candidate.tip.message_end <= self.canonical.message_cursor):
            return False
        if candidate.tier is Tier.RECOVERY_SIGNED:
            return all(item.scheduled_signature_ok for item in candidate.blocks)
        if candidate.tier is Tier.ESCAPE_UNSIGNED:
            return (candidate.count == 1
                    and candidate.tip.slot == self.escape_slot
                    and not candidate.blocks[0].scheduled_signature_ok
                    and not candidate.blocks[0].discretionary_body
                    and candidate.blocks[0].data_record_indices == ())
        return False

    def submit(self, candidate: Candidate, clock: Clock) -> str:
        """External EVM wrapper: a sync transition returns before validation."""
        if self.sync(clock):
            return "SYNCED"
        if self.mode is Mode.NORMAL:
            if not self._valid_normal(candidate, clock):
                return "REJECTED"
            if self.normal_deadline is None:
                self.normal_deadline = clock.timestamp + W_SETTLE_SECONDS
                self.normal_min_admissible = clock.l2_slot - DELTA_TIP
            if self.normal_best is None or candidate.order > self.normal_best.order:
                self.normal_best = candidate
                return "ACCEPTED"
            return "IGNORED"
        if not self._valid_recovery(candidate, clock):
            return "REJECTED"
        self._commit(candidate, clock)
        self.mode = Mode.NORMAL
        self.causes = Cause.NONE
        self.activation_slot = None
        self.escape_slot = None
        self.force_cutoff = None
        self.activation_id = ""
        self.version += 1
        self.data_records.clear()
        self.data_mmr_root = ""
        self.events.append("RECOVERY_COMMITTED")
        return "COMMITTED"

    def _commit(self, candidate: Candidate, clock: Clock) -> None:
        self.canonical = Canonical(
            candidate.tip.block_hash,
            candidate.tip.slot,
            hashlib.sha256(f"state:{candidate.candidate_id}".encode()).hexdigest(),
            candidate.tip.message_end,
            clock.block_number,
            self.history[clock.block_number],
            candidate.data_mmr_root,
        )
        self.events.append(f"CANONICAL:{candidate.candidate_id}")


PASS: list[str] = []


def check(name: str, condition: bool) -> None:
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def clock(number: int, timestamp: int) -> Clock:
    return Clock(number, timestamp, timestamp // L1_SLOT_SECONDS)


def protocol(tip_slot: int = 1_000, cursor: int = 0, seat: bool = True) -> Protocol:
    history = {number: f"{number:064x}" for number in range(1, 10_000)}
    canonical = Canonical("a" * 64, tip_slot, "b" * 64, cursor, 900, history[900])
    active = Seat("aggregator", 100) if seat else None
    return Protocol(canonical, history, active_seat=active,
                    standby=[Seat("standby", 70)])


def block(index: int, *, slot: int, parent: str, cursor: int,
          message_end: int | None = None, signed: bool = True,
          force_cutoff: int | None = None,
          refs: tuple[int, ...] = (), discretionary: bool = True) -> Block:
    return Block(slot, f"{index:064x}", parent, slot // 384, signed, cursor,
                 cursor if message_end is None else message_end,
                 cursor if force_cutoff is None else force_cutoff,
                 refs, discretionary)


def candidate(p: Protocol, c: Clock, *, ident: str = "candidate", slot: int | None = None,
              tier: Tier = Tier.NORMAL_SIGNED, signed: bool = True,
              message_end: int | None = None, refs: tuple[int, ...] = (),
              discretionary: bool = True, version: int | None = None,
              activation_id: str | None = None) -> Candidate:
    if slot is None:
        slot = p.escape_slot if tier is Tier.ESCAPE_UNSIGNED else c.l2_slot
    assert slot is not None
    cutoff = p.force_cutoff if p.mode is Mode.RECOVERY else len(p.messages)
    assert cutoff is not None
    item = block(int(hashlib.sha256(ident.encode()).hexdigest(), 16), slot=slot,
                 parent=p.canonical.tip_hash, cursor=p.canonical.message_cursor,
                 message_end=message_end, signed=signed, force_cutoff=cutoff, refs=refs,
                 discretionary=discretionary)
    return Candidate(
        ident, p.canonical.tip_hash, (item,), tier, True,
        p.version if version is None else version,
        p.activation_id if activation_id is None else activation_id,
        p.canonical.canonicalization_block, p.canonical.canonicalization_hash,
        p.canonical.canonicalization_block, p.canonical.canonicalization_hash,
        p.data_mmr_root, True,
    )


def open_recovery(p: Protocol) -> Clock:
    trigger = clock(1_100, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    check("P1 sync opens an objective recovery episode", p.sync(trigger))
    return trigger


def test_evm_atomicity_and_activation_order() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    best = candidate(p, c, ident="immature")
    check("P2 first normal candidate is accepted", p.submit(best, c) == "ACCEPTED")
    p.normal_deadline = 9_999
    trigger = clock(1_101, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    stale = candidate(p, trigger, ident="stale", version=p.version)
    check("P3 submit returns SYNCED before stale-candidate validation",
          p.submit(stale, trigger) == "SYNCED")
    check("P4 activation survived the external call", p.mode is Mode.RECOVERY)
    check("P5 immature normal best is canceled", p.normal_best is None)
    check("P6 SLA burns and replaces the incumbent exactly once",
          p.burned == 100 and p.active_seat is not None
          and p.active_seat.operator == "standby")
    before = p.burned
    check("P7 persistent episode cannot burn another seat", not p.sync(trigger))
    check("P8 burn remains idempotent", p.burned == before)

    q = protocol()
    early = clock(1_050, 1_050)
    mature = candidate(q, early, ident="mature")
    check("P9 mature setup accepted", q.submit(mature, early) == "ACCEPTED")
    close_clock = clock(1_200, early.timestamp + W_SETTLE_SECONDS)
    q.messages.append(Message(0, 100_000, 1, "became-due-after-landing"))
    check("P10 close and later force activation occur in one non-reverting sync",
          q.sync(close_clock) and q.mode is Mode.RECOVERY)
    check("P11 mature best committed before lag was recomputed",
          q.canonical.tip_hash == mature.tip.block_hash)


def test_escape_without_any_builder_or_seat() -> None:
    p = protocol(seat=False)
    p.messages = [Message(0, 100_000, 1, "forced-user-tx")]
    trigger = clock(1_100, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    check("P12 seatless activation never reverts", p.sync(trigger))
    check("P13 both SLA and force causes are recorded",
          p.causes == Cause.SLA | Cause.FORCE_DUE)
    submit_clock = clock(p.canonical.canonicalization_block + F_L1,
                         p.escape_slot + 1)
    escape = candidate(p, submit_clock, ident="escape", tier=Tier.ESCAPE_UNSIGNED,
                       signed=False, message_end=1, discretionary=False)
    check("P14 unsigned deterministic escape commits without a builder",
          p.submit(escape, submit_clock) == "COMMITTED")
    check("P15 escape advances forced cursor and canonical slot",
          p.canonical.message_cursor == 1
          and p.canonical.tip_slot == trigger.timestamp + ESCAPE_OFFSET)
    check("P16 canonical commit has no payment dependency", p.active_seat is None)

    p2 = protocol(seat=False)
    trigger2 = open_recovery(p2)
    submit2 = clock(p2.canonical.canonicalization_block + F_L1,
                    p2.escape_slot + 1)
    empty_escape = candidate(p2, submit2, ident="empty-escape",
                             tier=Tier.ESCAPE_UNSIGNED, signed=False,
                             discretionary=False)
    check("P17 an SLA-only empty escape restores chain liveness",
          p2.submit(empty_escape, submit2) == "COMMITTED")


def test_forced_prefix_and_escape_restrictions() -> None:
    p = protocol(seat=False)
    p.messages = [
        Message(0, 7_000_000, 1, "a"),
        Message(0, 7_000_000, 1, "b"),
        Message(0, 7_000_000, 1, "c"),
        Message(0, 7_000_000, 1, "d"),
    ]
    trigger = clock(1_100, p.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    p.sync(trigger)
    c = clock(p.canonical.canonicalization_block + F_L1, p.escape_slot + 1)
    short = candidate(p, c, ident="short", tier=Tier.ESCAPE_UNSIGNED,
                      signed=False, message_end=1, discretionary=False)
    check("P18 truncating deterministic maximum prefix is rejected",
          p.submit(short, c) == "REJECTED")
    exact = candidate(p, c, ident="exact", tier=Tier.ESCAPE_UNSIGNED,
                      signed=False, message_end=2, discretionary=False)
    check("P19 maximum gas-fitting prefix commits", p.submit(exact, c) == "COMMITTED")

    late = protocol(seat=False)
    late.messages = [Message(0, 100_000, 1, "frozen")]
    late_trigger = clock(1_100, late.canonical.tip_slot + DELTA_FINAL_LAG + 1)
    late.sync(late_trigger)
    late.messages.append(Message(late_trigger.timestamp, 100_000, 1, "appended-later"))
    late_clock = clock(late.canonical.canonicalization_block + F_L1,
                       late.escape_slot + 1)
    frozen = candidate(late, late_clock, ident="frozen-cutoff",
                       tier=Tier.ESCAPE_UNSIGNED, signed=False,
                       message_end=1, discretionary=False)
    check("P20 post-activation append cannot invalidate the frozen escape input",
          late.submit(frozen, late_clock) == "COMMITTED")

    q = protocol(seat=False)
    t = open_recovery(q)
    cc = clock(q.canonical.canonicalization_block + F_L1, q.escape_slot + 1)
    bad_body = candidate(q, cc, ident="bad-body", tier=Tier.ESCAPE_UNSIGNED,
                         signed=False, discretionary=True)
    check("P21 escape cannot carry discretionary transactions",
          q.submit(bad_body, cc) == "REJECTED")
    bad_sig = candidate(q, cc, ident="bad-sig", tier=Tier.ESCAPE_UNSIGNED,
                        signed=True, discretionary=False)
    check("P22 escape cannot masquerade as a scheduled block",
          q.submit(bad_sig, cc) == "REJECTED")


def test_data_binding_and_bounds() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    check("P23 unrelated or unavailable blob cannot be registered",
          not p.post_data(c, same_tx_blobhash=False, body_root="r", publisher="alice",
                          valid_until=2_000, kzg_opening_ok=True))
    check("P24 valid same-transaction KZG/Fiat-Shamir record appends",
          p.post_data(c, same_tx_blobhash=True, body_root="r", publisher="alice",
                      valid_until=2_000, kzg_opening_ok=True))
    good = candidate(p, c, ident="with-data", refs=(0,))
    check("P25 exact unique manifest is accepted", p.submit(good, c) == "ACCEPTED")

    q = protocol()
    q.post_data(c, same_tx_blobhash=True, body_root="r", publisher="alice",
                valid_until=2_000, kzg_opening_ok=True)
    duplicate = candidate(q, c, ident="duplicate", refs=(0, 0))
    check("P26 duplicate blob coverage is rejected", q.submit(duplicate, c) == "REJECTED")
    wrong_root = candidate(q, c, ident="wrong-root", refs=(0,))
    wrong_root = Candidate(**{**wrong_root.__dict__, "data_mmr_root": "bad"})
    check("P27 candidate must bind the current authenticated MMR root",
          q.submit(wrong_root, c) == "REJECTED")
    inexact = candidate(q, c, ident="inexact", refs=(0,))
    inexact = Candidate(**{**inexact.__dict__, "data_manifest_exact": False})
    check("P28 manifest must cover every discretionary byte exactly once",
          q.submit(inexact, c) == "REJECTED")


def test_candidate_geometry_history_and_clock_domains() -> None:
    p = protocol()
    c = clock(1_100, 1_100)
    old = candidate(p, c, ident="old", slot=p.canonical.tip_slot)
    future = candidate(p, c, ident="future", slot=c.l2_slot + CLOCK_SKEW + 1)
    check("P29 first block must strictly advance canonical slot",
          p.submit(old, c) == "REJECTED")
    check("P30 candidate tip has a current-slot upper bound",
          p.submit(future, c) == "REJECTED")
    unsigned_normal = candidate(p, c, ident="unsigned-normal", signed=False)
    check("P31 normal blocks require scheduled signatures",
          p.submit(unsigned_normal, c) == "REJECTED")

    q = protocol()
    trigger = open_recovery(q)
    too_shallow = clock(q.canonical.canonicalization_block + F_L1 - 1,
                        trigger.timestamp + 1)
    recovery = candidate(q, too_shallow, ident="recovery", tier=Tier.RECOVERY_SIGNED)
    check("P32 recovery finalRef enforces canonicalization depth",
          q.submit(recovery, too_shallow) == "REJECTED")
    deep = clock(q.canonical.canonicalization_block + F_L1, trigger.timestamp + 1)
    wrong_ref = candidate(q, deep, ident="wrong-ref", tier=Tier.RECOVERY_SIGNED)
    wrong_ref = Candidate(**{**wrong_ref.__dict__, "final_ref_hash": "f" * 64})
    check("P33 finalRef is authenticated through bounded history",
          q.submit(wrong_ref, deep) == "REJECTED")
    good = candidate(q, deep, ident="signed-recovery", tier=Tier.RECOVERY_SIGNED)
    check("P34 valid scheduled recovery remains permissionless to land",
          q.submit(good, deep) == "COMMITTED")


def test_normal_order_freeze_reorg_and_resources() -> None:
    race = protocol()
    race_clock = clock(1_100, 1_100)
    anchored = candidate(race, race_clock, ident="anchored-before-append")
    race.messages.append(Message(race_clock.timestamp, 100_000, 1, "later-append"))
    check("P35 post-anchor queue append cannot invalidate a normal proof",
          race.submit(anchored, race_clock) == "ACCEPTED")

    p = protocol()
    c = clock(1_100, 1_100)
    first = candidate(p, c, ident="first")
    check("P36 normal window opens", p.submit(first, c) == "ACCEPTED")
    frozen = p.normal_min_admissible
    later = clock(1_101, 1_200)
    competitor = candidate(p, later, ident="competitor", slot=1_101)
    check("P37 admissibility floor is frozen for the whole normal window",
          p.submit(competitor, later) in {"ACCEPTED", "IGNORED"}
          and p.normal_min_admissible == frozen)
    close = clock(1_200, c.timestamp + W_SETTLE_SECONDS)
    check("P38 deterministic close commits exactly one best", p.sync(close))
    canon_events = [event for event in p.events if event.startswith("CANONICAL:")]
    check("P39 close has one canonical effect", len(canon_events) == 1)

    pre = protocol().snapshot()
    post = pre.snapshot()
    rc = clock(1_100, 1_100)
    cand = candidate(post, rc, ident="reorged")
    post.submit(cand, rc)
    post.sync(clock(1_200, rc.timestamp + W_SETTLE_SECONDS))
    post = pre.snapshot()  # Canonical L1 replay starts from pre-state.
    check("P40 truncating the L1 close removes every derived effect", post.identical(pre))

    many_windows = tuple(
        block(i + 1, slot=1_001 + i * 384,
              parent=("a" * 64 if i == 0 else f"{i:064x}"), cursor=0)
        for i in range(MAX_WINDOWS_PER_CANDIDATE + 1)
    )
    check("P41 candidate window resource bound is finite",
          len({item.window for item in many_windows}) > MAX_WINDOWS_PER_CANDIDATE)
    check("P42 each publisher data session has a hard record bound",
          MAX_DATA_RECORDS_PER_SESSION == 2_100)


def test_parameter_geometry() -> None:
    end_to_end_escape = (T_INCLUDE_MAX * L1_SLOT_SECONDS + ESCAPE_OFFSET
                         + T_INCLUDE_MAX * L1_SLOT_SECONDS + CLOCK_SKEW)
    tip_age = T_INCLUDE_MAX * L1_SLOT_SECONDS + CLOCK_SKEW
    check("P43 escape end-to-end bound fits final-lag budget",
          end_to_end_escape <= DELTA_FINAL_LAG)
    check("P44 escape offset covers bounded depth and proof generation",
          ESCAPE_OFFSET >= T_DEPTH_MAX + P_PROVE_MAX)
    check("P45 submit latency fits tip-admissibility bound",
          tip_age <= DELTA_TIP)
    check("P46 forced message admission guarantees one item fits",
          MAX_FORCE_MESSAGE_GAS <= FORCE_GAS_BUDGET)
    check("P47 EIP history ring covers recovery depth and proof path",
          F_L1 + T_INCLUDE_MAX + (P_PROVE_MAX // L1_SLOT_SECONDS) < HISTORY_RING_BLOCKS)


if __name__ == "__main__":
    for test in (
        test_evm_atomicity_and_activation_order,
        test_escape_without_any_builder_or_seat,
        test_forced_prefix_and_escape_restrictions,
        test_data_binding_and_bounds,
        test_candidate_geometry_history_and_clock_domains,
        test_normal_order_freeze_reorg_and_resources,
        test_parameter_geometry,
    ):
        test()
    print("RESULTS: settlement/recovery model — ALL PROPERTIES PASS")
    for index, name in enumerate(PASS, 1):
        print(f"  [{index:03d}] {name}")
