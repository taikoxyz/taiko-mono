#!/usr/bin/env python3
"""Exact executable consensus model for the slot-chain lookahead (§3.2)."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

try:
    from Crypto.Hash import keccak as _native_keccak
except ImportError:  # The exact pure-Python fallback below keeps the model standalone.
    _native_keccak = None

SETTLEMENT_CHAIN_ID = 1
GENESIS_TIMESTAMP = 1_000_000
BEACON_GENESIS_TIME = 900_000
BEACON_SLOT_SECONDS = 12
W_SIZE = 384
H_LOOK = 768
L1_EPOCH = 32
F_FINAL_L1_BLOCKS = 64
T_DEPTH_MAX_SECONDS = 900
D_SNAP_L1 = 8 * L1_EPOCH
MAX_SNAPSHOT_MISSES = 64
SEAL_MARGIN_L1 = 32
Q_MAX = W_SIZE // 5
N_MAX = 64
N_CAPACITY = (W_SIZE + Q_MAX - 1) // Q_MAX
MAX_EARLY_SEAL_WINDOWS = 8
MAX_LIVE_WINDOWS = 268
VACANT = 0
BOND_MAX = (1 << 192) - 1
MASK64 = (1 << 64) - 1

DOMAIN_SEED = b"slot-chain-seed-v2"
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
    effective_l2_slot: int = 0
    tombstoned_at_l2_slot: int | None = None

    def valid_registration(self) -> bool:
        return (self.address != VACANT and 0 < self.address < 1 << 160
                and 0 < self.bond <= BOND_MAX
                and 0 <= self.registration_index < 1 << 64)


@dataclass(frozen=True)
class Snapshot:
    target_slot: int
    carrier_slot: int
    carrier_block_number: int
    source_slot: int
    source_timestamp: int
    source_l2_slot: int
    randao: bytes
    entries: tuple[Entry, ...]


@dataclass(frozen=True)
class ExecutionBlock:
    beacon_slot: int
    block_number: int
    timestamp: int


def window_of(slot: int) -> int:
    return slot // W_SIZE


def beacon_slot_at(timestamp: int) -> int:
    return max(0, (timestamp - BEACON_GENESIS_TIME) // BEACON_SLOT_SECONDS)


def snapshot_target_slot(window: int) -> int:
    window_start = GENESIS_TIMESTAMP + window * W_SIZE
    return beacon_slot_at(window_start) - D_SNAP_L1


def seal_deadline_l2(window: int) -> int:
    return window * W_SIZE - H_LOOK


def make_snapshot(window: int, execution_blocks: tuple[ExecutionBlock, ...],
                  entries: tuple[Entry, ...]) -> Snapshot | None:
    """Model EIP-4788: the first carrier after target returns its parent root."""
    target = snapshot_target_slot(window)
    carriers = [block for block in execution_blocks
                if target < block.beacon_slot <= target + MAX_SNAPSHOT_MISSES]
    if not carriers:
        return None
    carrier = min(carriers, key=lambda block: block.beacon_slot)
    sources = [block for block in execution_blocks
               if block.beacon_slot < carrier.beacon_slot]
    if not sources:
        return None
    source = max(sources, key=lambda block: block.beacon_slot)
    if source.beacon_slot > target:
        return None
    randao = keccak256(b"test-randao-v1" + u64(source.beacon_slot))
    source_l2_slot = max(0, source.timestamp - GENESIS_TIMESTAMP)
    return Snapshot(target, carrier.beacon_slot, carrier.block_number,
                    source.beacon_slot, source.timestamp, source_l2_slot,
                    randao, entries)


def seal_window(window: int, seal_l2_slot: int, current_block_number: int,
                execution_blocks: tuple[ExecutionBlock, ...],
                entries: tuple[Entry, ...], *, witness_ok: bool = True) -> Snapshot | None:
    """A late or unfinalized seal permanently resolves to all VACANT."""
    if seal_l2_slot >= seal_deadline_l2(window):
        return None
    snapshot = make_snapshot(window, execution_blocks, entries)
    if snapshot is None:
        return None
    if not witness_ok:
        raise ValueError("malformed witness reverts; it does not seal VACANT")
    if current_block_number - snapshot.carrier_block_number < F_FINAL_L1_BLOCKS:
        return None
    return snapshot


def seed(window: int, snapshot: Snapshot) -> bytes:
    return keccak256(DOMAIN_SEED + u256(SETTLEMENT_CHAIN_ID)
                     + u256(window) + snapshot.randao)


def eligible_entries(snapshot: Snapshot, window: int) -> list[Entry]:
    eligible = [
        entry for entry in snapshot.entries
        if entry.valid_registration()
        and entry.effective_l2_slot <= snapshot.source_l2_slot
        and window in entry.tranche_windows
        and (entry.tombstoned_at_l2_slot is None
             or entry.tombstoned_at_l2_slot > snapshot.source_l2_slot)
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
    if snapshot is None:
        return [VACANT] * W_SIZE
    assert snapshot.source_slot <= snapshot.target_slot < snapshot.carrier_slot
    seed_bytes = seed(window, snapshot)
    return place_tickets(quotas(eligible_entries(snapshot, window), seed_bytes), seed_bytes)


def lookahead(slot: int, snapshot_provider,
              tombstone_effective: dict[int, int] | None = None,
              frozen_admission: bool = False) -> int:
    window = window_of(slot)
    scheduled = schedule_for_window(window, snapshot_provider)[slot % W_SIZE]
    effective = (tombstone_effective or {}).get(scheduled)
    return (VACANT if not frozen_admission and effective is not None
            and effective <= slot else scheduled)


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
EXECUTION_BLOCKS = tuple(
    ExecutionBlock(slot, 20_000 + ordinal,
                   BEACON_GENESIS_TIME + slot * BEACON_SLOT_SECONDS)
    for ordinal, slot in enumerate(range(7_500, 14_000)) if slot % 17 != 0
)
CURRENT_EXECUTION_BLOCK = 40_000


def provider(entries=REG, execution_blocks=EXECUTION_BLOCKS):
    return lambda window: seal_window(
        window, seal_deadline_l2(window) - 1, CURRENT_EXECUTION_BLOCK,
        execution_blocks, tuple(entries)
    )


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
    assert snapshot is not None
    check("L2 exact seed golden vector",
          seed(0, snapshot).hex()
          == "54c14caf9644741f706662347eb5a567f763302ea4b023d122ec7db03e812a94")
    check("L3 exact full-schedule golden vector",
          digest_schedule(list(base_schedule()))
          == "a995246db69a7f133e333ce45934d7edc4dbe6a7431be0b232f7f12295274362")


def test_determinism_geometry_and_missed_slots():
    check("L4 schedule is a stable immutable vector",
          tuple(base_schedule()) == base_schedule())
    check("L5 one aligned window has one target snapshot",
          len({snapshot_target_slot(window_of(slot)) for slot in range(W_SIZE)}) == 1)
    snapshot = provider()(0)
    assert snapshot is not None
    check("L6 EIP-4788 carrier authenticates greatest source at/before target",
          snapshot.source_slot <= snapshot.target_slot < snapshot.carrier_slot
          and snapshot.source_slot in {b.beacon_slot for b in EXECUTION_BLOCKS}
          and snapshot.carrier_slot in {b.beacon_slot for b in EXECUTION_BLOCKS}
          and not any(snapshot.source_slot < b.beacon_slot < snapshot.carrier_slot
                      for b in EXECUTION_BLOCKS))
    ok = True
    for now in range(0, 4 * W_SIZE, 97):
        far = now + H_LOOK
        now_timestamp = GENESIS_TIMESTAMP + now
        target_timestamp = (BEACON_GENESIS_TIME
                            + BEACON_SLOT_SECONDS * snapshot_target_slot(window_of(far)))
        latest_carrier_timestamp = target_timestamp + BEACON_SLOT_SECONDS * MAX_SNAPSHOT_MISSES
        ok &= latest_carrier_timestamp + T_DEPTH_MAX_SECONDS <= now_timestamp
    check("L7 every slot in H_LOOK has time for execution-block finality", ok)
    check("L7a strict seal geometry has positive slack",
          D_SNAP_L1 * BEACON_SLOT_SECONDS
          > (H_LOOK + MAX_SNAPSHOT_MISSES * BEACON_SLOT_SECONDS
             + T_DEPTH_MAX_SECONDS + SEAL_MARGIN_L1 * BEACON_SLOT_SECONDS))
    no_carrier = tuple(block for block in EXECUTION_BLOCKS
                       if not (snapshot.target_slot < block.beacon_slot
                               <= snapshot.target_slot + MAX_SNAPSHOT_MISSES))
    check("L8 missing bounded carrier fails closed",
          make_snapshot(0, no_carrier, REG) is None
          and schedule_for_window(0, lambda _w: None) == [VACANT] * W_SIZE)
    check("L9 late seal cannot mutate an advertised vacant window",
          seal_window(0, seal_deadline_l2(0), CURRENT_EXECUTION_BLOCK,
                      EXECUTION_BLOCKS, REG) is None)
    check("L9a finality is execution-block depth, not beacon-slot subtraction",
          seal_window(0, seal_deadline_l2(0) - 1,
                      snapshot.carrier_block_number + F_FINAL_L1_BLOCKS - 1,
                      EXECUTION_BLOCKS, REG) is None)
    reverted = False
    try:
        seal_window(0, seal_deadline_l2(0) - 1, CURRENT_EXECUTION_BLOCK,
                    EXECUTION_BLOCKS, REG, witness_ok=False)
    except ValueError:
        reverted = True
    check("L9b malformed witness reverts instead of sealing VACANT", reverted)


def test_empty_sentinel_eligibility_and_tombstone():
    check("L10 zero eligible builders yields all VACANT",
          schedule_for_window(0, provider(entries=())).count(VACANT) == W_SIZE)
    bad = Entry(VACANT, 10, 1, frozenset({0}))
    check("L11 VACANT/address(0) is invalid", not bad.valid_registration())
    unfunded_whale = Entry(addr(50), BOND_MAX, 50, frozenset())
    funded = [Entry(addr(i), 1, i, frozenset({0, 1})) for i in range(6)]
    eligible = eligible_entries(provider(entries=(unfunded_whale, *funded))(0), 0)
    check("L12 tranche-ineligible whale filtered before ranking",
          unfunded_whale.address not in {entry.address for entry in eligible})
    check("L12a six present plus 58 absent cells seal without VACANT",
          VACANT not in schedule_for_window(0, provider(entries=tuple(funded))))
    snapshot = provider()(1)
    assert snapshot is not None
    tombstoned = Entry(addr(60), BOND_MAX, 60, ALL_WINDOWS,
                       tombstoned_at_l2_slot=snapshot.source_l2_slot)
    eligible_after = eligible_entries(
        provider(entries=(tombstoned, *funded))(1), 1
    )
    check("L13 tombstoned key excluded from later snapshot",
          tombstoned.address not in {entry.address for entry in eligible_after})
    early = Entry(addr(61), BOND_MAX, 61, ALL_WINDOWS,
                  effective_l2_slot=snapshot.source_l2_slot + 1)
    check("L13a not-yet-effective registration is excluded in L2 clock",
          early.address not in {entry.address for entry in eligible_entries(
              provider(entries=(early, *funded))(1), 1)})
    scheduled = next(address for address in base_schedule() if address != VACANT)
    position = base_schedule().index(scheduled)
    check("L14 post-seal tombstone affects only slots at/after effective slot",
          lookahead(position, provider(), {scheduled: position + 1}) == scheduled
          and lookahead(position, provider(), {scheduled: position}) == VACANT)
    check("L14a frozen candidate context survives a later tombstone",
          lookahead(position, provider(), {scheduled: position},
                    frozen_admission=True) == scheduled)


def test_quota_and_run_bounds():
    registries = [
        REG,
        tuple(Entry(addr(i), 1, i, ALL_WINDOWS) for i in range(6)),
        tuple(Entry(addr(i), BOND_MAX if i == 0 else 1, i, ALL_WINDOWS)
              for i in range(64)),
        (Entry(addr(0), 1, 0, ALL_WINDOWS),),
    ]
    for case, entries in enumerate(registries):
        snapshot = make_snapshot(0, EXECUTION_BLOCKS, tuple(entries))
        assert snapshot is not None
        trial_seed = keccak256(seed(0, snapshot) + u64(47 + case))
        alloc = quotas(eligible_entries(snapshot, 0), trial_seed)
        check(f"L15.{case} quotas fill the window", sum(alloc.values()) == W_SIZE)
        check(f"L16.{case} hard address quota holds",
              all(count <= Q_MAX for address, count in alloc.items()
                  if address != VACANT))
        if case in (1, 2):
            schedule = place_tickets(alloc, trial_seed)
            actual = {address: schedule.count(address) for address in alloc}
            check(f"L17.{case} placement preserves quotas", actual == alloc)
            check(f"L18.{case} no real adjacent self-run",
                  all(a == VACANT or a != b for a, b in zip(schedule, schedule[1:])))


def test_capacity_and_old_sampler_regression():
    total = sum(entry.bond for entry in REG)
    old_effective = {entry.address: min(entry.bond * 5, total) for entry in REG}
    old_share = old_effective[addr(3)] / sum(old_effective.values())
    actual = base_schedule().count(addr(3))
    check("L19 exact fill capacity is six addresses", N_CAPACITY == 6)
    check("L20 old renormalized whale sampler exceeded 54 percent", old_share > 0.54)
    check("L21 production quota caps whale at 76", actual <= Q_MAX)
    current = 10_000
    oldest_live = current - (MAX_LIVE_WINDOWS - MAX_EARLY_SEAL_WINDOWS - 1)
    earliest_sealed = current + MAX_EARLY_SEAL_WINDOWS
    check("L22 early-seal and retained-window ring indices cannot collide",
          earliest_sealed - oldest_live < MAX_LIVE_WINDOWS
          and earliest_sealed % MAX_LIVE_WINDOWS != oldest_live % MAX_LIVE_WINDOWS)


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
