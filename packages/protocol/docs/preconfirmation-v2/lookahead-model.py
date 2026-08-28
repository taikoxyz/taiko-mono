#!/usr/bin/env python3
"""Executable consensus model for the slot-chain lookahead (§3.2).

The production path has exactly one scheduling algorithm:

1. snapshot integer bond weights and registration indices at a finalized height;
2. apportion at most Q_MAX tickets to each address with capped D'Hondt;
3. represent unfillable tickets explicitly as VACANT (a protocol gap); and
4. place tickets with a seeded, feasibility-preserving permutation that never
   puts the same real builder in adjacent slots.

Run directly; it has no dependencies:
    python3 lookahead-model.py
"""

import hashlib
import random
from dataclasses import dataclass

L1_PER_L2 = 12
W_SIZE = 384
H_LOOK = 768
L1_EPOCH = 32
F_FINAL_L1 = 2 * L1_EPOCH
D_SNAP_L1 = 5 * L1_EPOCH
W_MAX_NUM, W_MAX_DEN = 1, 5
Q_MAX = W_SIZE * W_MAX_NUM // W_MAX_DEN  # 76, deliberately rounded down
N_CAPACITY = (W_SIZE + Q_MAX - 1) // Q_MAX  # 6, not ceil(1/0.2)=5
GENESIS_L1 = 10_000
VACANT = "0x0000000000000000000000000000000000000000"


@dataclass(frozen=True)
class Entry:
    address: str
    bond: int
    registration_index: int


def h(*xs) -> int:
    m = hashlib.sha256()
    for x in xs:
        m.update(str(x).encode())
        m.update(b"|")
    return int.from_bytes(m.digest(), "big")


def window_of(slot: int) -> int:
    return slot // W_SIZE


def l1_slot_of(l2_slot: int) -> int:
    return GENESIS_L1 + l2_slot // L1_PER_L2


def snapshot_height(window: int) -> int:
    return l1_slot_of(window * W_SIZE) - D_SNAP_L1


def seed(window: int, l1_randao) -> int:
    return h("slot-chain-seed-v1", window, l1_randao(snapshot_height(window)))


def _better_quotient(a: Entry, b: Entry, alloc: dict[str, int], tie_seed: int) -> bool:
    """Exact comparison of bond/(allocated+1), with no floating point."""
    left = a.bond * (alloc[b.address] + 1)
    right = b.bond * (alloc[a.address] + 1)
    if left != right:
        return left > right
    return h("quota-tie", tie_seed, a.registration_index) < h(
        "quota-tie", tie_seed, b.registration_index
    )


def quotas(entries: list[Entry], tie_seed: int) -> dict[str, int]:
    """Capped D'Hondt apportionment; any unfillable capacity becomes VACANT."""
    assert entries and len({e.address for e in entries}) == len(entries)
    assert all(e.bond > 0 for e in entries)
    ordered = sorted(entries, key=lambda e: e.registration_index)
    alloc = {e.address: 0 for e in ordered}
    for _ in range(W_SIZE):
        eligible = [e for e in ordered if alloc[e.address] < Q_MAX]
        if not eligible:
            break
        best = eligible[0]
        for candidate in eligible[1:]:
            if _better_quotient(candidate, best, alloc, tie_seed):
                best = candidate
        alloc[best.address] += 1
    alloc[VACANT] = W_SIZE - sum(alloc.values())
    return alloc


def _future_feasible(remaining: dict[str, int]) -> bool:
    """A real address can still be arranged without an adjacent self-run."""
    total = sum(remaining.values())
    return all(
        count <= (total - count) + 1
        for address, count in remaining.items()
        if address != VACANT
    )


def place_tickets(alloc: dict[str, int], schedule_seed: int) -> list[str]:
    """Seeded multiset permutation with a hard real-address max-run of one."""
    remaining = dict(alloc)
    assert sum(remaining.values()) == W_SIZE and _future_feasible(remaining)
    schedule: list[str] = []
    for position in range(W_SIZE):
        previous = schedule[-1] if schedule else None
        feasible = []
        for address, count in remaining.items():
            if count == 0 or (address != VACANT and address == previous):
                continue
            remaining[address] -= 1
            if _future_feasible(remaining):
                feasible.append(address)
            remaining[address] += 1
        assert feasible, "quota placement became infeasible"
        chosen = min(feasible, key=lambda a: h("slot-order", schedule_seed, position, a))
        schedule.append(chosen)
        remaining[chosen] -= 1
    assert all(v == 0 for v in remaining.values())
    return schedule


def schedule_for_window(window: int, l1_registry, l1_randao) -> list[str]:
    entries = l1_registry(snapshot_height(window))
    s = seed(window, l1_randao)
    return place_tickets(quotas(entries, s), s)


def lookahead(slot: int, l1_registry, l1_randao) -> str:
    window = window_of(slot)
    return schedule_for_window(window, l1_registry, l1_randao)[slot % W_SIZE]


PASS = []


def check(name, cond):
    assert cond, f"FAILED: {name}"
    PASS.append(name)


REG = [
    Entry("alice", 100, 0),
    Entry("bob", 50, 1),
    Entry("carol", 30, 2),
    Entry("whale", 900, 3),
]


def registry_at(_height):
    return list(REG)


def randao_at(height):
    return h("randao", height)


def test_determinism_and_geometry():
    a = [lookahead(s, registry_at, randao_at) for s in range(2 * W_SIZE)]
    b = [lookahead(s, registry_at, randao_at) for s in range(2 * W_SIZE)]
    check("L1 schedule is a deterministic pure function", a == b)
    check("L2 one aligned window has one snapshot",
          len({snapshot_height(window_of(s)) for s in range(W_SIZE)}) == 1)
    ok = True
    for now in range(0, 4 * W_SIZE, 97):
        far = now + H_LOOK
        ok &= snapshot_height(window_of(far)) <= l1_slot_of(now) - F_FINAL_L1
    check("L3 every slot in H_LOOK uses an L1-final snapshot", ok)


def test_production_path_enforces_quota():
    for window in range(20):
        schedule = schedule_for_window(window, registry_at, randao_at)
        counts = {a: schedule.count(a) for a in {e.address for e in REG}}
        check(f"L4.{window:02d} actual lookahead path obeys Q_MAX",
              len(schedule) == W_SIZE and all(v <= Q_MAX for v in counts.values()))
    check("L5 under-capacity registry produces explicit gaps, never undefined consensus",
          schedule_for_window(0, registry_at, randao_at).count(VACANT)
          == W_SIZE - len(REG) * Q_MAX)
    check("L6 exact capacity floor is ceil(W_SIZE/Q_MAX)=6", N_CAPACITY == 6)


def test_distribution_and_run_bound():
    registries = [
        REG,
        [Entry(f"e{i}", 1, i) for i in range(6)],
        [Entry(f"e{i}", 10**9 if i == 0 else 1, i) for i in range(64)],
        [Entry("solo", 1, 0)],
    ]
    rng = random.Random(47)
    for case, entries in enumerate(registries):
        for trial in range(20):
            s = rng.getrandbits(256)
            alloc = quotas(entries, s)
            schedule = place_tickets(alloc, s)
            actual = {a: schedule.count(a) for a in alloc}
            check(f"L7.{case}.{trial:02d} placement preserves every quota", actual == alloc)
            check(f"L8.{case}.{trial:02d} no real builder has adjacent slots",
                  all(a == VACANT or a != b for a, b in zip(schedule, schedule[1:])))


def test_old_sampler_regression():
    total = sum(e.bond for e in REG)
    old_effective = {e.address: min(e.bond * W_MAX_DEN, total * W_MAX_NUM) for e in REG}
    old_share = old_effective["whale"] / sum(old_effective.values())
    actual = schedule_for_window(0, registry_at, randao_at).count("whale")
    check("L9 old capped-weight sampler renormalized whale to 54.5%",
          abs(old_share - 0.5455) < 0.001)
    check("L10 production path gives whale at most 76 slots, not the old expectation",
          actual <= Q_MAX and actual < old_share * W_SIZE)


if __name__ == "__main__":
    for test in [
        test_determinism_and_geometry,
        test_production_path_enforces_quota,
        test_distribution_and_run_bound,
        test_old_sampler_regression,
    ]:
        test()
    print("RESULTS: lookahead model — ALL PROPERTIES PASS")
    for i, name in enumerate(PASS, 1):
        print(f"  [{i:03d}] {name}")
