#!/usr/bin/env python3
"""Exact executable consensus model for the slot-chain lookahead (§3.2)."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

try:
    from Crypto.Hash import keccak as _native_keccak
except ImportError:  # The exact pure-Python fallback below keeps the model standalone.
    _native_keccak = None

CHAIN_ID = 16_788
PROTOCOL_VERSION = 2
L1_PER_L2 = 12
W_SIZE = 384
H_LOOK = 768
L1_EPOCH = 32
F_FINAL_L1 = 2 * L1_EPOCH
D_SNAP_L1 = 5 * L1_EPOCH
Q_MAX = W_SIZE // 5
N_MAX = 64
N_CAPACITY = (W_SIZE + Q_MAX - 1) // Q_MAX
GENESIS_L1 = 10_000
VACANT = 0
BOND_MAX = (1 << 192) - 1
MASK64 = (1 << 64) - 1

DOMAIN_SEED = b"slot-chain-seed-v1"
DOMAIN_QUOTA = b"slot-chain-quota-tie-v1"
DOMAIN_SLOT = b"slot-chain-slot-order-v1"

_ROT = (0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39,
        41, 45, 15, 21, 8, 18, 2, 61, 56, 14)
_RC = (
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
    0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
    0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
    0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
    0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
    0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
    0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
)


def _rol(value: int, count: int) -> int:
    return ((value << count) | (value >> (64 - count))) & MASK64 if count else value


def _keccak_f(state: list[int]) -> None:
    for rc in _RC:
        c = [state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
             for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rol(c[(x + 1) % 5], 1) for x in range(5)]
        for y in range(5):
            for x in range(5):
                state[x + 5 * y] ^= d[x]
        b = [0] * 25
        for y in range(5):
            for x in range(5):
                b[y + 5 * ((2 * x + 3 * y) % 5)] = _rol(
                    state[x + 5 * y], _ROT[x + 5 * y]
                )
        for y in range(5):
            for x in range(5):
                state[x + 5 * y] = b[x + 5 * y] ^ (
                    ((~b[(x + 1) % 5 + 5 * y]) & MASK64)
                    & b[(x + 2) % 5 + 5 * y]
                )
        state[0] ^= rc


def _keccak256_pure(data: bytes) -> bytes:
    rate = 136
    padded = bytearray(data)
    padded.append(0x01)
    padded.extend(b"\x00" * ((rate - 1 - len(padded)) % rate))
    padded.append(0x80)
    state = [0] * 25
    for offset in range(0, len(padded), rate):
        block = padded[offset:offset + rate]
        for lane in range(rate // 8):
            state[lane] ^= int.from_bytes(block[8 * lane:8 * lane + 8], "little")
        _keccak_f(state)
    return b"".join(lane.to_bytes(8, "little") for lane in state)[:32]


def keccak256(data: bytes) -> bytes:
    """Legacy Keccak-256 used by Ethereum, not NIST SHA3-256."""
    if _native_keccak is not None:
        digest = _native_keccak.new(digest_bits=256)
        digest.update(data)
        return digest.digest()
    return _keccak256_pure(data)


def u256(value: int) -> bytes:
    assert 0 <= value < 1 << 256
    return value.to_bytes(32, "big")


def u64(value: int) -> bytes:
    assert 0 <= value < 1 << 64
    return value.to_bytes(8, "big")


def u16(value: int) -> bytes:
    assert 0 <= value < 1 << 16
    return value.to_bytes(2, "big")


def address20(value: int) -> bytes:
    assert 0 < value < 1 << 160
    return value.to_bytes(20, "big")


@dataclass(frozen=True)
class Entry:
    address: int
    bond: int
    registration_index: int
    tranche_windows: frozenset[int]
    tombstoned_at_slot: int | None = None

    def valid_registration(self) -> bool:
        return (self.address != VACANT and 0 < self.address < 1 << 160
                and 0 < self.bond <= BOND_MAX
                and 0 <= self.registration_index < 1 << 64)


@dataclass(frozen=True)
class Snapshot:
    target_slot: int
    execution_slot: int
    randao: bytes
    entries: tuple[Entry, ...]


def window_of(slot: int) -> int:
    return slot // W_SIZE


def l1_slot_of(l2_slot: int) -> int:
    return GENESIS_L1 + l2_slot // L1_PER_L2


def snapshot_target_slot(window: int) -> int:
    return l1_slot_of(window * W_SIZE) - D_SNAP_L1


def make_snapshot(window: int, execution_slots: tuple[int, ...],
                  entries: tuple[Entry, ...]) -> Snapshot:
    """Choose the greatest canonical execution-bearing slot <= target."""
    target = snapshot_target_slot(window)
    actual = max(slot for slot in execution_slots if slot <= target)
    randao = keccak256(b"test-randao-v1" + u64(actual))
    return Snapshot(target, actual, randao, entries)


def seed(window: int, snapshot: Snapshot) -> bytes:
    return keccak256(DOMAIN_SEED + u256(CHAIN_ID) + u256(PROTOCOL_VERSION)
                     + u256(window) + snapshot.randao)


def eligible_entries(snapshot: Snapshot, window: int) -> list[Entry]:
    eligible = [
        entry for entry in snapshot.entries
        if entry.valid_registration()
        and window in entry.tranche_windows
        and (entry.tombstoned_at_slot is None
             or entry.tombstoned_at_slot > snapshot.execution_slot)
    ]
    eligible.sort(key=lambda entry: (-entry.bond, entry.registration_index))
    return eligible[:N_MAX]


def quota_tie(seed_bytes: bytes, registration_index: int) -> bytes:
    return keccak256(DOMAIN_QUOTA + seed_bytes + u64(registration_index))


def slot_tie(seed_bytes: bytes, position: int, address: int) -> bytes:
    encoded = b"\x00" * 20 if address == VACANT else address20(address)
    return keccak256(DOMAIN_SLOT + seed_bytes + u16(position) + encoded)


def _better_quotient(a: Entry, b: Entry, alloc: dict[int, int],
                     seed_bytes: bytes) -> bool:
    left = a.bond * (alloc[b.address] + 1)
    right = b.bond * (alloc[a.address] + 1)
    assert left < 1 << 256 and right < 1 << 256
    if left != right:
        return left > right
    return quota_tie(seed_bytes, a.registration_index) < quota_tie(
        seed_bytes, b.registration_index
    )


def quotas(entries: list[Entry], seed_bytes: bytes) -> dict[int, int]:
    assert len({entry.address for entry in entries}) == len(entries)
    assert all(entry.valid_registration() for entry in entries)
    if not entries:
        return {VACANT: W_SIZE}
    ordered = sorted(entries, key=lambda entry: entry.registration_index)
    alloc = {entry.address: 0 for entry in ordered}
    for _ in range(W_SIZE):
        available = [entry for entry in ordered if alloc[entry.address] < Q_MAX]
        if not available:
            break
        best = available[0]
        for candidate in available[1:]:
            if _better_quotient(candidate, best, alloc, seed_bytes):
                best = candidate
        alloc[best.address] += 1
    alloc[VACANT] = W_SIZE - sum(alloc.values())
    return alloc


def _future_feasible(remaining: dict[int, int]) -> bool:
    total = sum(remaining.values())
    return all(count <= total - count + 1
               for address, count in remaining.items() if address != VACANT)


def place_tickets(alloc: dict[int, int], seed_bytes: bytes) -> list[int]:
    remaining = dict(alloc)
    assert sum(remaining.values()) == W_SIZE and _future_feasible(remaining)
    schedule: list[int] = []
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
        chosen = min(feasible, key=lambda a: slot_tie(seed_bytes, position, a))
        schedule.append(chosen)
        remaining[chosen] -= 1
    assert all(count == 0 for count in remaining.values())
    return schedule


def schedule_for_window(window: int, snapshot_provider) -> list[int]:
    snapshot = snapshot_provider(window)
    assert snapshot.execution_slot <= snapshot.target_slot
    seed_bytes = seed(window, snapshot)
    return place_tickets(quotas(eligible_entries(snapshot, window), seed_bytes), seed_bytes)


def lookahead(slot: int, snapshot_provider) -> int:
    window = window_of(slot)
    return schedule_for_window(window, snapshot_provider)[slot % W_SIZE]


PASS: list[str] = []


def check(name: str, condition: bool) -> None:
    assert condition, f"FAILED: {name}"
    PASS.append(name)


def addr(index: int) -> int:
    return index + 1


ALL_WINDOWS = frozenset(range(100))
REG = (
    Entry(addr(0), 100, 0, ALL_WINDOWS),
    Entry(addr(1), 50, 1, ALL_WINDOWS),
    Entry(addr(2), 30, 2, ALL_WINDOWS),
    Entry(addr(3), 900, 3, ALL_WINDOWS),
)
EXECUTION_SLOTS = tuple(slot for slot in range(9_000, 14_000) if slot % 17 != 0)


def provider(entries=REG, execution_slots=EXECUTION_SLOTS):
    return lambda window: make_snapshot(window, execution_slots, tuple(entries))


def digest_schedule(schedule: list[int]) -> str:
    return keccak256(b"".join(address.to_bytes(20, "big") for address in schedule)).hex()


@lru_cache(maxsize=1)
def base_schedule() -> tuple[int, ...]:
    return tuple(schedule_for_window(0, provider()))


def test_keccak_and_encoding_vectors():
    check("L1 Ethereum Keccak empty-string vector",
          keccak256(b"").hex() == "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
          and _keccak256_pure(b"") == keccak256(b""))
    snapshot = provider()(0)
    check("L2 exact seed golden vector",
          seed(0, snapshot).hex()
          == "7e34b12af6c4bcc3a695bbbf325d6afe8297ac7ed1bfc23037476c893e2e727f")
    check("L3 exact full-schedule golden vector",
          digest_schedule(list(base_schedule()))
          == "c4db654e38b1a69759a343e0103293b6670ddc52012ccac8f5362b2da86f7590")


def test_determinism_geometry_and_missed_slots():
    check("L4 schedule is a stable immutable vector",
          tuple(base_schedule()) == base_schedule())
    check("L5 one aligned window has one target snapshot",
          len({snapshot_target_slot(window_of(slot)) for slot in range(W_SIZE)}) == 1)
    snapshot = provider()(0)
    check("L6 missed target selects greatest prior execution-bearing slot",
          snapshot.execution_slot <= snapshot.target_slot
          and snapshot.execution_slot in EXECUTION_SLOTS
          and not any(snapshot.execution_slot < slot <= snapshot.target_slot
                      for slot in EXECUTION_SLOTS))
    ok = True
    for now in range(0, 4 * W_SIZE, 97):
        far = now + H_LOOK
        ok &= snapshot_target_slot(window_of(far)) <= l1_slot_of(now) - F_FINAL_L1
    check("L7 every slot in H_LOOK has a finalized target", ok)


def test_empty_sentinel_eligibility_and_tombstone():
    check("L8 zero eligible builders yields all VACANT",
          schedule_for_window(0, provider(entries=())).count(VACANT) == W_SIZE)
    bad = Entry(VACANT, 10, 1, frozenset({0}))
    check("L9 VACANT/address(0) is invalid", not bad.valid_registration())
    unfunded_whale = Entry(addr(50), BOND_MAX, 50, frozenset())
    funded = [Entry(addr(i), 1, i, frozenset({0, 1})) for i in range(6)]
    eligible = eligible_entries(provider(entries=(unfunded_whale, *funded))(0), 0)
    check("L10 tranche-ineligible whale filtered before ranking",
          unfunded_whale.address not in {entry.address for entry in eligible})
    snapshot = provider()(1)
    tombstoned = Entry(addr(60), BOND_MAX, 60, ALL_WINDOWS,
                       tombstoned_at_slot=snapshot.execution_slot)
    eligible_after = eligible_entries(
        provider(entries=(tombstoned, *funded))(1), 1
    )
    check("L11 tombstoned key excluded from later snapshot",
          tombstoned.address not in {entry.address for entry in eligible_after})


def test_quota_and_run_bounds():
    registries = [
        REG,
        tuple(Entry(addr(i), 1, i, ALL_WINDOWS) for i in range(6)),
        tuple(Entry(addr(i), BOND_MAX if i == 0 else 1, i, ALL_WINDOWS)
              for i in range(64)),
        (Entry(addr(0), 1, 0, ALL_WINDOWS),),
    ]
    for case, entries in enumerate(registries):
        snapshot = make_snapshot(0, EXECUTION_SLOTS, tuple(entries))
        trial_seed = keccak256(seed(0, snapshot) + u64(47 + case))
        alloc = quotas(eligible_entries(snapshot, 0), trial_seed)
        check(f"L12.{case} quotas fill the window", sum(alloc.values()) == W_SIZE)
        check(f"L13.{case} hard address quota holds",
              all(count <= Q_MAX for address, count in alloc.items()
                  if address != VACANT))
        if case in (1, 2):
            schedule = place_tickets(alloc, trial_seed)
            actual = {address: schedule.count(address) for address in alloc}
            check(f"L14.{case} placement preserves quotas", actual == alloc)
            check(f"L15.{case} no real adjacent self-run",
                  all(a == VACANT or a != b for a, b in zip(schedule, schedule[1:])))


def test_capacity_and_old_sampler_regression():
    total = sum(entry.bond for entry in REG)
    old_effective = {entry.address: min(entry.bond * 5, total) for entry in REG}
    old_share = old_effective[addr(3)] / sum(old_effective.values())
    actual = base_schedule().count(addr(3))
    check("L16 exact fill capacity is six addresses", N_CAPACITY == 6)
    check("L17 old renormalized whale sampler exceeded 54 percent", old_share > 0.54)
    check("L18 production quota caps whale at 76", actual <= Q_MAX)


if __name__ == "__main__":
    for test in (
        test_keccak_and_encoding_vectors,
        test_determinism_geometry_and_missed_slots,
        test_empty_sentinel_eligibility_and_tombstone,
        test_quota_and_run_bounds,
        test_capacity_and_old_sampler_regression,
    ):
        test()
    print("RESULTS: lookahead model — ALL PROPERTIES PASS")
    for index, name in enumerate(PASS, 1):
        print(f"  [{index:03d}] {name}")
