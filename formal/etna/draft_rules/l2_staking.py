"""Conditional symbolic boundaries of unmerged Etna design PR22425.

Keys and anchors are already validated/authenticated premises. This module does
not execute a protocol, authenticate storage, or establish production units.
"""

from collections.abc import Mapping
from dataclasses import dataclass, replace
from typing import Literal


UINT256_MAX = 2**256 - 1
UINT48_MAX = 2**48 - 1
MAX_POWER = (2**63 - 1) // 8


@dataclass(frozen=True, slots=True)
class Config:
    vp_unit: int
    min_stake: int
    n_max: int
    miss_limit: int
    miss_slash_bps: int


@dataclass(frozen=True, slots=True)
class Member:
    key: str
    power: int
    valid_key: bool = True
    reserved_bits: int = 0


@dataclass(frozen=True, slots=True)
class Snapshot:
    height: int
    total_stake: int
    members: tuple[Member, ...]


@dataclass(frozen=True, slots=True)
class Anchor:
    min_total_stake: int
    fallback_keys: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Bond:
    bond_id: int
    key: str
    stake: int
    seat: int | None = None
    exit_height: int | None = None


@dataclass(frozen=True, slots=True)
class Action:
    kind: Literal["register", "top_up", "exit"]
    bond_id: int
    key: str = ""
    amount: int = 0


@dataclass(frozen=True, slots=True)
class Selection:
    members: tuple[Member, ...]
    source: Literal["origin", "candidate", "fallback"]


@dataclass(frozen=True, slots=True)
class State:
    config: Config
    generation: int
    origin: int
    height: int
    origin_fallback: tuple[str, ...]
    bonds: tuple[Bond, ...]
    misses: tuple[int, ...]
    snapshot: Snapshot
    stored_generation: int
    current_signers: Selection
    next_signers: Selection
    pending_signers: Selection


@dataclass(frozen=True, slots=True)
class Transition:
    state: State
    miss_bitmap: int
    penalties: tuple[tuple[int, int], ...]
    updates: tuple[Member, ...]
    call_succeeded: bool


def _integer(value: object, minimum: int = 0, maximum: int = UINT256_MAX) -> bool:
    return type(value) is int and minimum <= value <= maximum


def _key(value: object) -> bool:
    return type(value) is str and bool(value)


def _keys(keys: object) -> bool:
    return (type(keys) is tuple and 1 <= len(keys) <= 128
            and all(_key(key) for key in keys)
            and tuple(sorted(set(keys))) == keys)


def _members(members: object) -> bool:
    if type(members) is not tuple or not 1 <= len(members) <= 128:
        return False
    seen = set()
    total = 0
    for member in members:
        if (not isinstance(member, Member) or not _key(member.key)
                or member.valid_key is not True or type(member.reserved_bits) is not int
                or member.reserved_bits != 0 or not _integer(member.power, 1, MAX_POWER)
                or member.key in seen):
            return False
        seen.add(member.key)
        total += member.power
    return total <= MAX_POWER


def _anchor(anchor: Anchor) -> None:
    if (not isinstance(anchor, Anchor) or not _integer(anchor.min_total_stake)
            or not _keys(anchor.fallback_keys)):
        raise ValueError("invalid authenticated-anchor premise")


def _config(config: Config) -> None:
    if (not isinstance(config, Config) or not _integer(config.vp_unit, 1)
            or not _integer(config.min_stake, config.vp_unit)
            or not _integer(config.n_max, 1, 128)
            or not _integer(config.miss_limit, 1, 65535)
            or not _integer(config.miss_slash_bps, 1, 10000)):
        raise ValueError("invalid conditional model configuration")


def _selection(selection: Selection, *, empty: bool = False) -> None:
    if (not isinstance(selection, Selection)
            or selection.source not in ("origin", "candidate", "fallback")
            or not (_members(selection.members) or (empty and selection.members == ()))):
        raise ValueError("invalid signing-set premise")


def _identity(selection: Selection) -> tuple[tuple[str, int], ...]:
    return tuple(sorted((member.key, member.power) for member in selection.members))


def _state(state: State) -> None:
    if not isinstance(state, State):
        raise ValueError("invalid state")
    _config(state.config)
    if (not _integer(state.origin, 0, UINT48_MAX)
            or not _integer(state.height, state.origin, UINT48_MAX)
            or not _integer(state.generation, 0, UINT48_MAX)
            or not _integer(state.stored_generation, 0, state.generation)
            or not _keys(state.origin_fallback)
            or type(state.bonds) is not tuple
            or type(state.misses) is not tuple
            or len(state.misses) != state.config.n_max
            or not isinstance(state.snapshot, Snapshot)
            or type(state.snapshot.members) is not tuple):
        raise ValueError("invalid state fields")
    occupied = set()
    keys = set()
    for index, bond in enumerate(state.bonds):
        if (not isinstance(bond, Bond) or not _integer(bond.bond_id)
                or bond.bond_id != index or not _key(bond.key) or bond.key in keys
                or not _integer(bond.stake)
                or (bond.exit_height is not None
                    and not _integer(bond.exit_height, 0, min(state.height, UINT48_MAX - 1)))):
            raise ValueError("invalid permanent checkpoint bond identity")
        keys.add(bond.key)
        eligible = bond.exit_height is None and bond.stake >= state.config.min_stake
        if bond.seat is None:
            if eligible:
                raise ValueError("eligible bond has no seat")
        elif (not _integer(bond.seat, 0, state.config.n_max - 1)
              or bond.seat in occupied or not eligible):
            raise ValueError("invalid live seat assignment")
        else:
            occupied.add(bond.seat)
    for count in state.misses:
        if not _integer(count, 0, state.config.miss_limit - 1):
            raise ValueError("invalid live miss counter")
    if sum(bond.stake for bond in state.bonds if bond.seat is not None) > UINT256_MAX:
        raise ValueError("snapshot stake total overflows uint256")
    _selection(state.current_signers, empty=state.height == state.origin)
    _selection(state.next_signers)
    _selection(state.pending_signers)
    if state.height == state.origin:
        origin_members = tuple(Member(key, 1) for key in state.origin_fallback)
        if (state.current_signers.members != () or state.next_signers.members != origin_members
                or state.pending_signers.members != origin_members):
            raise ValueError("invalid origin signer pipeline")


def initial_state(
    config: Config, *, origin: int = 0, generation: int = 0,
    origin_fallback: tuple[str, ...], bonds: tuple[Bond, ...] = (),
    snapshot: Snapshot | None = None, stored_generation: int = 0,
    misses: tuple[int, ...] | None = None,
) -> State:
    """Create a fresh origin with explicit trusted checkpoint staking state.

    Supply every issued bond identity and checkpoint counters on recovery.
    No parameter admits an old generation's pending validator updates.
    """
    _config(config)
    if not _keys(origin_fallback):
        raise ValueError("invalid origin fallback premise")
    first = Selection(tuple(Member(key, 1) for key in origin_fallback), "origin")
    state = State(config, generation, origin, origin, origin_fallback, bonds,
                  (0,) * config.n_max if misses is None else misses,
                  Snapshot(origin, 0, ()) if snapshot is None else snapshot,
                  stored_generation, Selection((), "origin"), first, first)
    _state(state)
    return state


def derive_set(height: int, snapshot: Snapshot, anchor: Anchor) -> Selection:
    """Select H+2, treating malformed candidate words as unusable."""
    if not _integer(height, 0, UINT48_MAX):
        raise ValueError("invalid deciding height")
    _anchor(anchor)
    if not isinstance(snapshot, Snapshot):
        raise ValueError("invalid snapshot record")
    if (anchor.min_total_stake != UINT256_MAX
            and _integer(snapshot.height) and snapshot.height == height
            and _integer(snapshot.total_stake)
            and _members(snapshot.members)
            and snapshot.total_stake >= anchor.min_total_stake):
        return Selection(snapshot.members, "candidate")
    return Selection(tuple(Member(key, 1) for key in anchor.fallback_keys), "fallback")


def _take_seat(bond: Bond, bonds: list[Bond], misses: list[int], config: Config) -> Bond:
    occupied = {item.seat for item in bonds if item.seat is not None}
    seat = next((seat for seat in range(config.n_max) if seat not in occupied), None)
    if seat is None:
        raise ValueError("no empty seat: admission backstop")
    misses[seat] = 0
    return replace(bond, seat=seat)


def _actions(
    actions: tuple[Action, ...], bonds: list[Bond], misses: list[int], config: Config,
    height: int,
) -> None:
    if type(actions) is not tuple:
        raise ValueError("actions must be an immutable tuple")
    for action in actions:
        if (not isinstance(action, Action) or not _integer(action.bond_id)
                or not _integer(action.amount)):
            raise ValueError("invalid action fields")
        if action.kind == "register":
            # This id describes the expected returned identity, not an ABI input.
            if (action.bond_id != len(bonds) or not _key(action.key)
                    or any(bond.key == action.key for bond in bonds)
                    or action.amount < config.min_stake):
                raise ValueError("invalid registration identity or amount")
            bond = Bond(action.bond_id, action.key, action.amount)
            bonds.append(_take_seat(bond, bonds, misses, config))
            continue
        if (action.kind not in ("top_up", "exit") or action.key != ""
                or action.bond_id >= len(bonds)):
            raise ValueError("unknown action or unissued bond")
        bond = bonds[action.bond_id]
        if bond.exit_height is not None:
            raise ValueError("bond already exited")
        if action.kind == "top_up":
            if action.amount == 0 or bond.stake + action.amount > UINT256_MAX:
                raise ValueError("invalid top-up amount or overflow")
            bond = replace(bond, stake=bond.stake + action.amount)
            if bond.seat is None and bond.stake >= config.min_stake:
                bond = _take_seat(bond, bonds, misses, config)
        else:
            if action.amount != 0 or height >= UINT48_MAX:
                raise ValueError("invalid exit fields or height")
            bond = replace(bond, exit_height=height, seat=None)
        bonds[action.bond_id] = bond


def advance(
    state: State, anchor: Anchor, *, actions: tuple[Action, ...] = (),
    missing_keys: tuple[str, ...] = (), block_start_ok: bool = True,
) -> Transition:
    """Advance one symbolic block; refusal leaves the immutable input intact."""
    _state(state)
    _anchor(anchor)
    if state.height == UINT48_MAX:
        raise ValueError("height overflow")
    if (type(block_start_ok) is not bool or type(missing_keys) is not tuple
            or not all(_key(key) for key in missing_keys)
            or len(set(missing_keys)) != len(missing_keys)):
        raise ValueError("invalid block-start or missing-key input")
    height = state.height + 1
    bitmap = 0
    if height > state.origin + 1:
        parent_keys = {member.key for member in state.current_signers.members}
        if not set(missing_keys) <= parent_keys:
            raise ValueError("missing key is not a parent signer")
        # Use the live parent mapping, never the previous snapshot's seat index.
        for bond in state.bonds:
            if bond.seat is not None and bond.key in missing_keys:
                bitmap |= 1 << bond.seat
    bonds, misses = list(state.bonds), list(state.misses)
    penalties = []
    snapshot, stored_generation = state.snapshot, state.stored_generation
    if block_start_ok:
        stored_generation = state.generation
        for index, bond in enumerate(bonds):
            if bond.seat is None:
                continue
            seat = bond.seat
            misses[seat] = misses[seat] + 1 if bitmap & (1 << seat) else 0
            if misses[seat] == state.config.miss_limit:
                penalty = (bond.stake * state.config.miss_slash_bps + 9999) // 10000
                penalties.append((bond.bond_id, penalty))
                misses[seat] = 0
                bond = replace(bond, stake=bond.stake - penalty)
                if bond.stake < state.config.min_stake:
                    bond = replace(bond, seat=None)
                bonds[index] = bond
        seated = sorted((bond for bond in bonds if bond.seat is not None), key=lambda bond: bond.seat)
        total = sum(bond.stake for bond in seated)
        if total > UINT256_MAX:
            raise ValueError("snapshot stake total overflows uint256")
        snapshot = Snapshot(height, total, tuple(
            Member(bond.key, bond.stake // state.config.vp_unit) for bond in seated
        ))
    _actions(actions, bonds, misses, state.config, height)
    selected = derive_set(height, snapshot, anchor)
    old = dict(_identity(state.pending_signers))
    new = dict(_identity(selected))
    updates = tuple(Member(key, new.get(key, 0)) for key in sorted(old.keys() | new.keys())
                    if old.get(key, 0) != new.get(key, 0))
    result = replace(state, height=height, bonds=tuple(bonds), misses=tuple(misses),
                     snapshot=snapshot, stored_generation=stored_generation,
                     current_signers=state.next_signers, next_signers=state.pending_signers,
                     pending_signers=selected)
    _state(result)
    return Transition(result, bitmap, tuple(sorted(penalties)), updates, block_start_ok)


def required_commits(
    parent_height: int, last_height: int, sets: Mapping[int, Selection],
) -> tuple[int, ...]:
    """Return terminal plus interior successor key/power change boundaries."""
    if (not _integer(parent_height, 0, UINT48_MAX)
            or not _integer(last_height, 0, UINT48_MAX)
            or parent_height >= last_height or not isinstance(sets, Mapping)
            or any(not _integer(height, 0, UINT48_MAX) for height in sets)):
        raise ValueError("invalid commit range or set mapping")
    for height in range(parent_height + 1, last_height + 1):
        if height not in sets:
            raise ValueError("missing signing set")
        _selection(sets[height])
    return tuple(height for height in range(parent_height + 1, last_height)
                 if _identity(sets[height]) != _identity(sets[height + 1])) + (last_height,)
