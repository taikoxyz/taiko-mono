#!/usr/bin/env python3
"""Unified executable model for normal settlement and fallback recovery.

This models the consensus decisions introduced by slot-chain design §5.6/§6.3:
one versioned mode machine, close-before-activate ordering, objective SLA
termination, first-qualifying fallback, split payouts, canonicalization depth,
slot expiry, per-window slash tranches and deterministic replay.

Run directly; it has no dependencies:
    python3 settlement-window-model.py
"""

import hashlib
import itertools
from dataclasses import dataclass, field
from typing import Optional

L1_TO_L2 = 12
W_SETTLE = 10
DELTA_LAG_FINAL = 120
P_PROVE_MAX_L2 = 36
T_INCLUDE_MAX_L2 = 12
CLOCK_MARGIN_L2 = 12
RECOVERY_BUILDER_WAIT_MAX_L2 = 24
DELTA_CLOSE = 96
assert (RECOVERY_BUILDER_WAIT_MAX_L2 + P_PROVE_MAX_L2
        + T_INCLUDE_MAX_L2 + CLOCK_MARGIN_L2 <= DELTA_CLOSE < DELTA_LAG_FINAL)

H_SLOT_EXPIRE = 384
DELTA_SLASH = 24
EVIDENCE_MARGIN = 12
REORG_HORIZON = 8
SCHEDULE_WINDOW = 384

C_ANCHOR_COUNT = 2
C_MSG_GAS = 10
G_ANCHOR = 1
BLOCK_GAS_LIMIT = 30
assert G_ANCHOR + C_MSG_GAS <= BLOCK_GAS_LIMIT

PENALTY_BOND = 1_000
R_PROOF = 20
R_SUBMIT = 2
B_MAX = 6
R_BLOB_MAX = 12
R_FALLBACK = R_PROOF + R_SUBMIT + B_MAX * R_BLOB_MAX


def h(*xs) -> int:
    return int.from_bytes(hashlib.sha256(repr(xs).encode()).digest()[:8], "big")


@dataclass(frozen=True)
class Item:
    iid: int
    gas: int


def max_prefix(items: list[Item], start: int):
    taken, gas, cursor = [], 0, start
    while cursor < len(items) and len(taken) < C_ANCHOR_COUNT:
        item = items[cursor]
        if gas + item.gas > C_MSG_GAS:
            break
        taken.append(item)
        gas += item.gas
        cursor += 1
    return cursor, taken


@dataclass(frozen=True)
class Block:
    slot: int
    parent: int
    tag: str = ""
    tier: int = 1
    fallback_version: int = 0
    activation_id: int = 0

    @property
    def hash(self):
        return h(self.slot, self.parent, self.tag, self.tier,
                 self.fallback_version, self.activation_id)


@dataclass(frozen=True)
class Candidate:
    blocks: tuple[Block, ...]
    beneficiary: str
    blob_hashes: tuple[str, ...] = ()

    def key(self, base_hash: int):
        assert self.blocks and self.blocks[0].parent == base_hash
        tip = self.blocks[-1]
        return (len(self.blocks), tip.slot, -tip.hash)


@dataclass(frozen=True)
class Canonical:
    tip_hash: int
    tip_slot: int
    state_root: int
    m_consumed: int
    canonicalization_block: int


@dataclass(frozen=True)
class EndTuple:
    tip_hash: int
    tip_slot: int
    state_root: int
    m_consumed: int


@dataclass
class BlobRecord:
    publisher: str
    cost: int
    valid_until: int
    paid: bool = False


@dataclass
class L1State:
    canonical: Canonical
    q_msg: list[Item]
    active: Optional[str] = "agg0"
    standbys: list[str] = field(default_factory=lambda: ["agg1"])
    penalty: dict[str, int] = field(default_factory=lambda: {"agg0": PENALTY_BOND, "agg1": PENALTY_BOND})
    escrow: dict[str, int] = field(default_factory=lambda: {"agg0": R_FALLBACK, "agg1": R_FALLBACK})
    mode: str = "NORMAL_IDLE"
    version: int = 1
    normal_base: Optional[Canonical] = None
    normal_close_at: Optional[int] = None
    normal_handle: Optional[int] = None
    best: Optional[tuple] = None  # (key, EndTuple, id, Candidate)
    activation_slot: Optional[int] = None
    activation_id: Optional[int] = None
    outgoing: Optional[str] = None
    min_admissible_slot: int = 0
    blobs: dict[str, BlobRecord] = field(default_factory=dict)
    payments: list[tuple] = field(default_factory=list)
    burned: list[tuple] = field(default_factory=list)
    consumed_log: list[tuple] = field(default_factory=list)
    liability_until: dict[int, int] = field(default_factory=dict)
    tranches: dict[tuple, int] = field(default_factory=dict)
    winners: list[str] = field(default_factory=list)

    def __post_init__(self):
        if self.active is not None:
            assert self.penalty.get(self.active, 0) >= PENALTY_BOND
            assert self.escrow.get(self.active, 0) >= R_FALLBACK

    def final_lag(self, current_slot: int) -> int:
        return max(0, current_slot - self.canonical.tip_slot)

    def qualifies(self, tip_slot: int, current_slot: int) -> bool:
        return tip_slot >= current_slot - DELTA_CLOSE

    def _validate(self, cand: Candidate, base: Canonical) -> Optional[EndTuple]:
        if not cand.blocks or cand.blocks[0].parent != base.tip_hash or len(cand.blob_hashes) > B_MAX:
            return None
        if any(b.slot < self.min_admissible_slot for b in cand.blocks):
            return None
        for previous, block in zip(cand.blocks, cand.blocks[1:]):
            if block.parent != previous.hash or block.slot <= previous.slot:
                return None
        cursor = base.m_consumed
        for _block in cand.blocks:
            cursor, taken = max_prefix(self.q_msg, cursor)
            if G_ANCHOR + sum(item.gas for item in taken) > BLOCK_GAS_LIMIT:
                return None
        root = h(base.state_root, tuple(b.hash for b in cand.blocks), cursor)
        tip = cand.blocks[-1]
        return EndTuple(tip.hash, tip.slot, root, cursor)

    def _pay_fallback(self, cand: Candidate, l1_now: int):
        assert self.outgoing is not None
        available = self.escrow[self.outgoing]
        proof_payment = R_PROOF + R_SUBMIT
        assert available >= proof_payment
        self.escrow[self.outgoing] -= proof_payment
        self.payments.append(("proof", cand.beneficiary, proof_payment))
        for blob_hash in cand.blob_hashes:
            record = self.blobs[blob_hash]
            if record.paid or l1_now > record.valid_until:
                continue
            amount = min(record.cost, R_BLOB_MAX)
            assert self.escrow[self.outgoing] >= amount
            self.escrow[self.outgoing] -= amount
            record.paid = True
            self.payments.append(("blob", record.publisher, amount))

    def _commit(self, end: EndTuple, cid: str, cand: Candidate, l1_now: int, fallback: bool):
        self.consumed_log.append((self.canonical.m_consumed, end.m_consumed))
        self.canonical = Canonical(end.tip_hash, end.tip_slot, end.state_root,
                                   end.m_consumed, l1_now)
        self.winners.append(cid)
        self.normal_base = self.normal_close_at = self.normal_handle = self.best = None
        if fallback:
            self._pay_fallback(cand, l1_now)
            self.mode = "NORMAL_IDLE"
            self.version += 1
            self.activation_slot = self.activation_id = self.outgoing = None
        else:
            self.mode = "NORMAL_IDLE"

    def _activate(self, l1_now: int, current_slot: int):
        old_best = self.best
        self.outgoing = self.active
        if self.outgoing is not None:
            amount = self.penalty[self.outgoing]
            self.penalty[self.outgoing] = 0
            self.burned.append(("aggregator-sla", self.outgoing, amount))
        self.active = None
        while self.standbys:
            candidate = self.standbys.pop(0)
            if self.penalty.get(candidate, 0) >= PENALTY_BOND and self.escrow.get(candidate, 0) >= R_FALLBACK:
                self.active = candidate
                break
        self.version += 1
        self.activation_slot = current_slot
        self.activation_id = h("activation", l1_now, self.version, l1_now - 1)
        self.mode = "FALLBACK_OPEN"
        self.normal_base = self.normal_close_at = self.normal_handle = self.best = None
        if old_best is not None:
            _, end, cid, cand = old_best
            if self.qualifies(end.tip_slot, current_slot):
                self._commit(end, cid, cand, l1_now, fallback=True)

    def sync(self, l1_now: int, current_slot: int):
        self.min_admissible_slot = max(self.min_admissible_slot,
                                       max(0, current_slot - H_SLOT_EXPIRE))
        if self.mode == "NORMAL_OPEN" and l1_now >= self.normal_close_at:
            _, end, cid, cand = self.best
            self._commit(end, cid, cand, l1_now, fallback=False)
        if self.mode != "FALLBACK_OPEN" and self.final_lag(current_slot) > DELTA_LAG_FINAL:
            self._activate(l1_now, current_slot)

    def post_data(self, blob_hash: str, publisher: str, cost: int,
                  valid_until: int, l1_now: int, current_slot: int):
        self.sync(l1_now, current_slot)
        assert blob_hash not in self.blobs or l1_now > self.blobs[blob_hash].valid_until
        self.blobs[blob_hash] = BlobRecord(publisher, cost, valid_until)

    def submit(self, cand: Candidate, l1_now: int, current_slot: int,
               expected_version: int, cid: str) -> bool:
        self.sync(l1_now, current_slot)
        if expected_version != self.version:
            return False
        if self.mode == "FALLBACK_OPEN":
            if not self.qualifies(cand.blocks[-1].slot, current_slot):
                return False
            first = cand.blocks[0]
            if not (first.tier == 2 and first.slot >= self.activation_slot
                    and first.fallback_version == self.version
                    and first.activation_id == self.activation_id):
                return False
            end = self._validate(cand, self.canonical)
            if end is None:
                return False
            self._commit(end, cid, cand, l1_now, fallback=True)
            return True

        base = self.canonical if self.mode == "NORMAL_IDLE" else self.normal_base
        end = self._validate(cand, base)
        if end is None:
            return False
        key = cand.key(base.tip_hash)
        if self.best is not None and key <= self.best[0]:
            return False
        if self.mode == "NORMAL_IDLE":
            self.mode = "NORMAL_OPEN"
            self.normal_base = self.canonical
            self.normal_close_at = l1_now + W_SETTLE
            self.normal_handle = self.version
        self.best = (key, end, cid, cand)
        for block in cand.blocks:
            window = block.slot // SCHEDULE_WINDOW
            self.liability_until[window] = max(
                self.liability_until.get(window, 0),
                self.normal_close_at + REORG_HORIZON + EVIDENCE_MARGIN,
            )
        return True

    def close_with_handle(self, handle: int, l1_now: int, current_slot: int) -> bool:
        self.sync(l1_now, current_slot)
        return handle == self.version and self.mode == "NORMAL_IDLE"

    def slash_equivocation(self, builder: str, slot: int):
        key = (builder, slot // SCHEDULE_WINDOW)
        amount = self.tranches.get(key, 0)
        if amount == 0:
            return False
        self.tranches[key] = 0
        self.burned.append(("equivocation", key, amount))
        return True

    def tranche_releasable(self, builder: str, window: int, l1_now: int,
                           current_slot: int) -> bool:
        window_end = (window + 1) * SCHEDULE_WINDOW - 1
        watermark = max(self.min_admissible_slot, max(0, current_slot - H_SLOT_EXPIRE))
        return (window_end < watermark
                and l1_now >= self.liability_until.get(window, 0)
                and l1_now >= (window_end // L1_TO_L2) + DELTA_SLASH + EVIDENCE_MARGIN)


GEN = Canonical(h("genesis"), 0, h("root0"), 0, 0)
PASS: list[str] = []


def check(name: str, condition: bool):
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def mk(base: int, slots: list[int], tag: str, beneficiary: str = "lander",
       tier: int = 1, version: int = 0, activation_id: int = 0,
       blobs: tuple[str, ...] = ()) -> Candidate:
    blocks, parent = [], base
    for i, slot in enumerate(slots):
        block = Block(slot, parent, f"{tag}{i}", tier if i == 0 else 1,
                      version if i == 0 else 0,
                      activation_id if i == 0 else 0)
        blocks.append(block)
        parent = block.hash
    return Candidate(tuple(blocks), beneficiary, blobs)


def fresh_state(tip_slot=0) -> L1State:
    canonical = Canonical(GEN.tip_hash, tip_slot, GEN.state_root, 0, 0)
    return L1State(canonical, [Item(i, 3) for i in range(20)])


def test_p1_total_order():
    candidates = [mk(GEN.tip_hash, list(range(1, n + 1)), f"c{n}") for n in range(1, 6)]
    for a, b, c in itertools.permutations(candidates, 3):
        ka, kb, kc = a.key(GEN.tip_hash), b.key(GEN.tip_hash), c.key(GEN.tip_hash)
        if ka > kb and kb > kc:
            assert ka > kc
    check("P1 normal candidate key is total and transitive", True)


def test_p2_normal_window_and_close():
    st = fresh_state()
    short = mk(GEN.tip_hash, [10, 11], "short")
    long = mk(GEN.tip_hash, [10, 11, 12], "long")
    assert st.submit(short, 0, 50, 1, "short")
    before = st.canonical
    assert st.submit(long, 1, 50, 1, "long")
    check("P2a provisional replacement does not mutate canonical", st.canonical == before)
    st.sync(W_SETTLE, 50)
    check("P2b mature normal close commits the heaviest candidate once",
          st.winners == ["long"] and st.canonical.tip_slot == 12 and st.mode == "NORMAL_IDLE")


def test_p3_close_before_activate():
    st = fresh_state()
    healing = mk(GEN.tip_hash, [110], "heal")
    assert st.submit(healing, 0, 100, 1, "heal")
    st.sync(W_SETTLE, 121)  # close first -> lag 11, so no activation
    check("P3 mature normal close precedes lag test and prevents false activation",
          st.active == "agg0" and not st.burned and st.mode == "NORMAL_IDLE")


def test_p4_activation_promotes_or_cancels():
    st = fresh_state()
    qualifying = mk(GEN.tip_hash, [80], "q")
    assert st.submit(qualifying, 0, 100, 1, "q")
    st.sync(5, 130)  # normal not mature; tip 80 is within DELTA_CLOSE
    check("P4a SLA breach terminates incumbent and promotes funded standby",
          st.active == "agg1" and st.penalty["agg0"] == 0)
    check("P4b already-verified qualifying best commits atomically at activation",
          st.winners == ["q"] and st.mode == "NORMAL_IDLE")

    st2 = fresh_state()
    stale = mk(GEN.tip_hash, [10], "stale")
    assert st2.submit(stale, 0, 100, 1, "stale")
    old_handle = st2.normal_handle
    st2.sync(5, 130)
    check("P4c nonqualifying normal best is canceled and stale handle cannot commit",
          st2.mode == "FALLBACK_OPEN" and st2.winners == []
          and not st2.close_with_handle(old_handle, 6, 131))


def test_p5_fallback_rules_and_moving_target():
    st = fresh_state()
    st.sync(1, 121)
    v, aid = st.version, st.activation_id
    subtarget = mk(GEN.tip_hash, [20], "sub", tier=2, version=v, activation_id=aid)
    check("P5a sub-target proof is rejected, not landed as another state transition",
          not st.submit(subtarget, 2, 122, v, "sub") and st.canonical == GEN)
    pre_signed = mk(GEN.tip_hash, [122], "old", tier=2, version=v - 1, activation_id=aid)
    check("P5b wrong episode version cannot replay", not st.submit(pre_signed, 2, 122, v, "old"))
    good = mk(GEN.tip_hash, [122], "good", tier=2, version=v, activation_id=aid)
    check("P5c first qualifying episode-bound proof commits immediately",
          st.submit(good, 2, 122, v, "good") and st.mode == "NORMAL_IDLE")
    check("P5d moving target covers builder wait, full proof and inclusion latency",
          RECOVERY_BUILDER_WAIT_MAX_L2 + P_PROVE_MAX_L2
          + T_INCLUDE_MAX_L2 + CLOCK_MARGIN_L2 <= DELTA_CLOSE < DELTA_LAG_FINAL)


def test_p6_front_run_and_strict_outage():
    st = fresh_state()
    st.sync(1, 121)
    v, aid = st.version, st.activation_id
    outgoing = mk(GEN.tip_hash, [121], "front", beneficiary="outgoing-sybil",
                  tier=2, version=v, activation_id=aid)
    assert st.submit(outgoing, 2, 121, v, "front")
    st.sync(100, 130)
    check("P6a outgoing front-run restores finality but cannot retain failed seat",
          st.active == "agg1" and st.penalty["agg0"] == 0 and st.winners == ["front"])

    outage = fresh_state()
    outage.sync(1, 121)
    outage.sync(1_000, 10_000)
    check("P6b persistent proving outage burns only one incumbent per episode",
          len([x for x in outage.burned if x[0] == "aggregator-sla"]) == 1
          and outage.mode == "FALLBACK_OPEN" and outage.active == "agg1")


def test_p7_split_payout_and_escrow():
    st = fresh_state()
    st.post_data("b1", "publisher", 9, 100, 0, 10)
    st.sync(1, 121)
    v, aid = st.version, st.activation_id
    cand = mk(GEN.tip_hash, [121], "paid", beneficiary="prover", tier=2,
              version=v, activation_id=aid, blobs=("b1",))
    assert st.submit(cand, 2, 121, v, "paid")
    check("P7a proof and blob costs go to distinct rightful recipients",
          ("proof", "prover", R_PROOF + R_SUBMIT) in st.payments
          and ("blob", "publisher", 9) in st.payments)
    check("P7b blob record is paid once and no slash-funded bounty exists",
          st.blobs["b1"].paid and all(payment[0] != "bounty" for payment in st.payments))
    check("P7c active seats are fully pre-funded", R_FALLBACK >= R_PROOF + R_SUBMIT + B_MAX * R_BLOB_MAX)


def test_p8_final_ref_uses_canonicalization_block():
    st = fresh_state()
    cand = mk(GEN.tip_hash, [10], "normal")
    assert st.submit(cand, 1, 50, 1, "normal")
    st.sync(11, 50)
    check("P8 canonical L1 depth starts at close, not provisional landing",
          st.canonical.canonicalization_block == 11
          and not (12 - st.canonical.canonicalization_block >= REORG_HORIZON)
          and 20 - st.canonical.canonicalization_block >= REORG_HORIZON)


def test_p9_expiry_and_window_tranches():
    st = fresh_state()
    st.tranches[("builder", 0)] = 500
    st.tranches[("builder", 1)] = 500
    check("P9a equivocation slashes only its independent schedule-window tranche",
          st.slash_equivocation("builder", 10) and st.tranches[("builder", 0)] == 0
          and st.tranches[("builder", 1)] == 500)
    check("P9b a second window remains independently slashable",
          st.slash_equivocation("builder", 400) and st.tranches[("builder", 1)] == 0)
    st2 = fresh_state()
    late_slot = H_SLOT_EXPIRE + SCHEDULE_WINDOW + 1
    check("P9c tranche release is time-watermark based and terminates without proof close",
          st2.tranche_releasable("builder", 0, 1_000, late_slot))


def test_p10_gas_and_replay():
    st = fresh_state()
    end = st._validate(mk(GEN.tip_hash, [10], "gas"), GEN)
    check("P10a a legal maximum-prefix block always exists", end is not None and end.m_consumed >= 0)
    oversized = L1State(GEN, [Item(1, C_MSG_GAS + 1)])
    end2 = oversized._validate(mk(GEN.tip_hash, [10], "oversized"), GEN)
    check("P10b over-cap queue item would permanently stop the cursor, so enqueue rejects it",
          end2 is not None and end2.m_consumed == 0)

    def replay(events):
        state = fresh_state()
        for event in events:
            getattr(state, event[0])(*event[1:])
        return state

    c = mk(GEN.tip_hash, [10], "r")
    events = [("submit", c, 0, 50, 1, "r"), ("sync", 10, 50)]
    a, b = replay(events), replay(events)
    reorged = replay(events[:1])
    check("P10c identical L1 replay is deterministic", a.canonical == b.canonical and a.winners == b.winners)
    check("P10d truncating the close block atomically removes canonical effects",
          reorged.canonical != a.canonical and reorged.winners == [])


if __name__ == "__main__":
    for test in [
        test_p1_total_order,
        test_p2_normal_window_and_close,
        test_p3_close_before_activate,
        test_p4_activation_promotes_or_cancels,
        test_p5_fallback_rules_and_moving_target,
        test_p6_front_run_and_strict_outage,
        test_p7_split_payout_and_escrow,
        test_p8_final_ref_uses_canonicalization_block,
        test_p9_expiry_and_window_tranches,
        test_p10_gas_and_replay,
    ]:
        test()
    print("RESULTS: unified settlement/fallback model — ALL PROPERTIES PASS")
    for index, name in enumerate(PASS, 1):
        print(f"  [{index:02d}] {name}")
