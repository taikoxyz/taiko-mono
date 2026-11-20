"""Finite projection of Etna recovery lists and replay guards at exact f556.

Actions are indivisible transactions. No callback or intra-transaction state is
modeled. DAO execution, whole-landing audit, authenticated L1 views, governance
upgrades, land proofs and token transfers are premises or modeled inputs.
"""

from collections.abc import Iterator
from dataclasses import dataclass, replace

from .explorer import Refused, Transition


EMPTY_HASH = bytes.fromhex("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
INBOX_OWNER = "inbox-dao"
REGISTRY_OWNER = "registry-dao"
FORFEIT_BPS = 3333
UNSET_EXIT = 2**48 - 1


@dataclass(frozen=True, slots=True)
class Bond:
    bond_id: int
    slot: int | None
    key: str
    owner: str | None
    active_from: int
    effective: int
    pending: int
    ready_at: int | None
    exit_effective: int | None
    exit_confirmed: int | None
    withdrawn: bool
    forfeited: bool
    # Last change attributable to this bond's slot, including its release.
    registry_update_block: int


@dataclass(frozen=True, slots=True)
class ForcedInclusion:
    index: int
    tx_hash: bytes
    timestamp: int
    enqueue_block: int
    # Historical charge from the enqueue event, not a queue storage field.
    admission_fee: int


@dataclass(frozen=True, slots=True)
class Landing:
    c: int
    parent: int
    generation: int
    head: int
    el_hash: str
    comet_hash: str
    active_snapshot: int


@dataclass(frozen=True, slots=True)
class Origin:
    generation: int
    start_height: int
    l1_block: int
    l1_timestamp: int


@dataclass(frozen=True, slots=True)
class State:
    generation: int
    nonce: int
    block: int
    timestamp: int
    initialized: bool
    started: bool
    landings: tuple[Landing, ...]
    origins: tuple[Origin, ...]
    schedule: tuple[int, int, int, int]
    bonds: tuple[Bond, ...]
    slots: tuple[int, ...]
    fi: tuple[ForcedInclusion, ...]
    fi_tail: int
    inbox_balance: int
    sink: int

    @property
    def c(self) -> int:
        return self.landings[-1].c

    @property
    def fi_head(self) -> int:
        return self.landings[-1].head

    @property
    def active_snapshot(self) -> int:
        return self.landings[-1].active_snapshot


@dataclass(frozen=True, slots=True)
class Recover:
    expected_generation: int
    expected_c: int
    expected_nonce: int
    valid_until: int
    exclusions: tuple[int, ...] = ()
    fi_to_clear: tuple[int, ...] = ()
    rules: int = 0
    caller: str = INBOX_OWNER


@dataclass(frozen=True, slots=True)
class InvalidateNonce:
    expected_nonce: int
    caller: str = INBOX_OWNER


@dataclass(frozen=True, slots=True)
class Land:
    # Record for the actual c→h write of a supplied admitted landing.
    record: Landing
    admitted: bool = True


@dataclass(frozen=True, slots=True)
class Rollback:
    # Trusted checkpoint identified by a supplied verifier-failure upgrade.
    trusted_c: int
    admitted: bool = True


@dataclass(frozen=True, slots=True)
class Forfeit:
    bond_id: int
    incident: str
    valid_until: int
    caller: str = REGISTRY_OWNER
    transfer_succeeds: bool = True


@dataclass(frozen=True, slots=True)
class AdvanceBlock:
    number: int
    timestamp: int


Action = Recover | InvalidateNonce | Land | Rollback | Forfeit | AdvanceBlock


def initial() -> State:
    # Selected state from a partial history. Bond 2 holds bond 0's former
    # slot. With L=5, the snapshot at H=21 supports the earlier confirmation,
    # the rotation at H=26 supplies the active snapshot at c=30, and another
    # rotation can take effect at H=31. Historical authentication is a premise.
    return State(
        generation=0,
        nonce=0,
        block=100,
        timestamp=1000,
        initialized=True,
        started=True,
        landings=(
            Landing(21, 20, 0, 7, "el-21", "comet-21", 70),
            Landing(30, 21, 0, 7, "el-30", "comet-30", 80),
        ),
        origins=(Origin(0, 2, 50, 400),),
        schedule=(0, 1, 2600, 2700),
        bonds=(
            Bond(0, None, "key-0", None, 49, 0, 0, None, 60, None, True, True, 64),
            Bond(1, 1, "key-1", "owner-1", 55, 13, 4, 65, 70, 75, False, False, 69),
            Bond(2, 0, "key-2", "owner-2", 68, 13, 4, 102, None, None, False, False, 65),
        ),
        slots=(2, 1),
        fi=(
            ForcedInclusion(7, bytes.fromhex("11" * 32), 976, 98, 30_000_000_000),
            ForcedInclusion(8, bytes.fromhex("22" * 32), 988, 99, 45_000_000_000),
        ),
        fi_tail=9,
        inbox_balance=75_000_000_000,
        sink=0,
    )


def _require(predicate: bool, reason: str) -> None:
    if not predicate:
        raise Refused(reason)


def _uint(value: int, bits: int) -> int:
    _require(type(value) is int and 0 <= value < 2**bits, f"value outside uint{bits}")
    return value


def _ordered(indices: tuple[int, ...], kind: str) -> None:
    for index in indices:
        _uint(index, 256)
    _require(all(a < b for a, b in zip(indices, indices[1:])), f"{kind} order")


def _inbox_owner(state: State, caller: str) -> None:
    _require(caller == INBOX_OWNER, "Inbox owner required")
    _require(state.initialized, "Inbox initialization missing")


def _force_exit(bond: Bond, block: int) -> Bond:
    # STOR-B-22 uses the maximum uint48 word for an unset exit.
    current_exit = UNSET_EXIT if bond.exit_effective is None else bond.exit_effective
    if bond.withdrawn or current_exit <= block:
        return bond
    return replace(bond, exit_effective=block, registry_update_block=block)


def _rules_event(schedule: tuple[int, int, int, int]) -> tuple[str, int]:
    return "RulesScheduleUpdated", sum(value << (48 * index) for index, value in enumerate(schedule))


def origin_at(state: State, generation: int) -> Origin:
    """Read the written slot 290 record. Missing keys have no default origin."""
    _uint(generation, 48)
    for record in state.origins:
        if record.generation == generation:
            return record
    raise Refused("origin missing")


def _recover(state: State, action: Recover) -> Transition[State]:
    # RECOV-8-38..50 and 8.3. Validate the whole call before building effects.
    _inbox_owner(state, action.caller)
    _require(state.started, "Etna start missing")
    _require(_uint(action.expected_generation, 48) == state.generation, "stale generation")
    _require(_uint(action.expected_c, 48) == state.c, "stale checkpoint")
    _require(_uint(action.expected_nonce, 256) == state.nonce, "stale nonce")
    _require(state.timestamp <= _uint(action.valid_until, 256), "recovery authorization expired")
    generation = _uint(state.generation + 1, 48)
    nonce = _uint(state.nonce + 1, 256)
    _require(all(record.generation != generation for record in state.origins), "origin already written")

    active, upcoming, activation_time, _ = state.schedule
    rules = _uint(action.rules, 48)
    _require(rules == 0 or rules == upcoming + 1, "invalid structural rules")
    _ordered(action.exclusions, "bond")
    _ordered(action.fi_to_clear, "FI")
    issued = {bond.bond_id for bond in state.bonds}
    _require(all(bond_id in issued for bond_id in action.exclusions), "unissued bond")
    _require(all(state.fi_head <= index < state.fi_tail for index in action.fi_to_clear), "FI range")

    # Independent lists use the permanent bond ID and the absolute FI index.
    block = _uint(state.block, 48)
    origin = Origin(generation, state.c, block, _uint(state.timestamp, 256))
    bonds = tuple(_force_exit(bond, block) if bond.bond_id in action.exclusions else bond
                  for bond in state.bonds)
    fi = tuple(replace(item, tx_hash=EMPTY_HASH) if item.index in action.fi_to_clear else item
               for item in state.fi)
    schedule = (rules, rules, 0, 0) if rules else (active, upcoming, activation_time, 0)
    post = replace(state, generation=generation, nonce=nonce, origins=(*state.origins, origin),
                   bonds=bonds, fi=fi, schedule=schedule)
    details = ("Recovered", generation, state.c, block, state.timestamp, nonce,
               action.exclusions, action.fi_to_clear)
    return Transition(post, (details, _rules_event(schedule)))


def _forfeit(state: State, action: Forfeit) -> Transition[State]:
    # A separate FORF-4.4 transaction. No authorization is stored in the model.
    _require(action.caller == REGISTRY_OWNER, "registry owner required")
    _require(state.initialized, "Inbox initialization missing")
    _require(state.timestamp <= _uint(action.valid_until, 256), "forfeiture authorization expired")
    bond_id = _uint(action.bond_id, 256)
    bond = next((entry for entry in state.bonds if entry.bond_id == bond_id), None)
    _require(bond is not None, "unissued bond")
    _require(not bond.withdrawn, "withdrawn bond")
    _require(not bond.forfeited, "already forfeited")
    balance = bond.effective + bond.pending
    _require(balance > 0, "no principal")
    _require(action.transfer_succeeds, "failed sink transfer")

    penalty = (balance * FORFEIT_BPS + 9999) // 10000
    effective_paid = min(bond.effective, penalty)
    pending = bond.pending - (penalty - effective_paid)
    updated = _force_exit(bond, _uint(state.block, 48))
    updated = replace(updated, effective=bond.effective - effective_paid, pending=pending,
                      ready_at=bond.ready_at if pending else None, forfeited=True)
    if effective_paid:
        updated = replace(updated, registry_update_block=state.block)
    bonds = tuple(updated if entry.bond_id == bond_id else entry for entry in state.bonds)
    return Transition(replace(state, bonds=bonds, sink=state.sink + penalty),
                      (("Forfeited", bond_id, action.incident, balance, penalty),))


def step(state: State, action: Action) -> Transition[State]:
    """Execute one selected transaction or refuse without a state or event."""
    if isinstance(action, Recover):
        return _recover(state, action)
    if isinstance(action, InvalidateNonce):
        _inbox_owner(state, action.caller)
        _require(_uint(action.expected_nonce, 256) == state.nonce, "stale nonce")
        nonce = _uint(state.nonce + 1, 256)
        return Transition(replace(state, nonce=nonce),
                          (("RecoveryNonceInvalidated", state.nonce, nonce),))
    if isinstance(action, Forfeit):
        return _forfeit(state, action)

    if isinstance(action, Land):
        _require(action.admitted and state.initialized and state.started, "landing not admitted")
        record = action.record
        _require(_uint(record.generation, 48) == state.generation, "stale landing generation")
        _require(record.parent == state.c < _uint(record.c, 48), "landing must extend c")
        _require(origin_at(state, state.generation).start_height <= state.c, "origin above checkpoint")
        max_head = min(state.fi_tail, state.fi_head + record.c - state.c)
        _require(state.fi_head <= _uint(record.head, 48) <= max_head, "landing FI range")
        _require(state.active_snapshot <= _uint(record.active_snapshot, 48) < state.block,
                 "landing snapshot range")
        # This projection has no proof origin or cut hash for a Landed receipt.
        return Transition(replace(state, landings=(*state.landings, record)))

    if isinstance(action, Rollback):
        _require(action.admitted, "rollback not admitted")
        trusted_c = _uint(action.trusted_c, 48)
        for index, record in enumerate(state.landings[:-1]):
            if record.c == trusted_c:
                break
        else:
            raise Refused("earlier trusted checkpoint missing")
        nonce = _uint(state.nonce + 1, 256)
        bonds = tuple(replace(bond, exit_confirmed=None)
                      if bond.exit_confirmed is not None and bond.exit_effective > record.active_snapshot
                      else bond for bond in state.bonds)
        return Transition(replace(state, nonce=nonce, landings=state.landings[:index + 1], bonds=bonds))

    if isinstance(action, AdvanceBlock):
        number = _uint(action.number, 48)
        timestamp = _uint(action.timestamp, 256)
        _require(number > state.block and timestamp > state.timestamp, "block must advance")
        return Transition(replace(state, block=number, timestamp=timestamp))

    raise TypeError(f"unknown recovery action: {action!r}")


def actions(state: State) -> Iterator[Action]:
    """The complete named bank for clocks 100..101, c=30..31, g=0..1, nonce=0..3."""
    if state.block == 100:
        yield AdvanceBlock(101, 1012)
    if state.c == 30:
        if state.generation == 0:
            yield Land(Landing(31, 30, 0, 8, "el-31", "comet-31", 96))
        # The bank supplies a new-generation landing only for the fixture
        # whose live replacement remains available after the recovery block.
        elif (state.block > origin_at(state, state.generation).l1_block
              and state.bonds[2].exit_effective is None):
            yield Land(Landing(31, 30, 1, 8, "el-new", "comet-new", 100))
    elif state.nonce < 3:
        yield Rollback(30)
    if state.nonce < 3:
        yield InvalidateNonce(state.nonce)

    yield Forfeit(2, "incident", 1000)
    fixed = Recover(0, 30, 0, 1000)
    yield fixed
    if state.generation == 1 or state.nonce == 3:
        return

    matching = Recover(state.generation, state.c, state.nonce, state.timestamp)
    if matching != fixed:
        yield matching
    fi_index = state.fi_head
    yield replace(matching, exclusions=(0,))
    yield replace(matching, exclusions=(2,))
    yield replace(matching, fi_to_clear=(fi_index,))
    yield replace(matching, exclusions=(0, 1, 2), fi_to_clear=(fi_index,))
    yield replace(matching, rules=2)
    if state.c == 30:
        yield replace(matching, fi_to_clear=(7, 8))
    yield replace(matching, exclusions=(2, 3), fi_to_clear=(fi_index,))
    yield replace(matching, exclusions=(2,), fi_to_clear=(fi_index, 9))
    yield replace(matching, exclusions=(2, 1))
    yield replace(matching, exclusions=(2, 2))
    yield replace(matching, fi_to_clear=(8, 7))
    yield replace(matching, fi_to_clear=(fi_index, fi_index))
    yield replace(matching, expected_generation=1)
    yield replace(matching, expected_c=29)
    yield replace(matching, expected_nonce=state.nonce + 1)
    yield replace(matching, valid_until=state.timestamp - 1)
    yield replace(matching, rules=3)
    yield replace(matching, caller="operator")


def _expected_exit(bond: Bond, block: int) -> int | None:
    old_word = 281474976710655 if bond.exit_effective is None else bond.exit_effective
    new_word = min(old_word, block)
    return None if new_word == 281474976710655 else new_word


def _check_recovery(pre: State, action: Recover, result: Transition[State]) -> None:
    post = result.state
    # Independent assertions on inputs and on all permitted changes. No use of
    # the transition's validation, exit, counter, origin or event helpers.
    assert pre.initialized and pre.started and action.caller == "inbox-dao"
    assert (action.expected_generation, action.expected_c, action.expected_nonce) == (
        pre.generation, pre.c, pre.nonce)
    assert pre.timestamp <= action.valid_until < 2**256
    assert tuple(sorted(set(action.exclusions))) == action.exclusions
    assert tuple(sorted(set(action.fi_to_clear))) == action.fi_to_clear
    assert set(action.exclusions) <= {bond.bond_id for bond in pre.bonds}
    assert set(action.fi_to_clear) <= set(range(pre.fi_head, pre.fi_tail))
    assert (post.generation, post.nonce) == (pre.generation + 1, pre.nonce + 1)
    assert post.generation < 2**48 and post.nonce < 2**256
    assert post.origins[:-1] == pre.origins
    assert (post.origins[-1].generation, post.origins[-1].start_height,
            post.origins[-1].l1_block, post.origins[-1].l1_timestamp) == (
        post.generation, pre.c, pre.block, pre.timestamp)
    assert post.generation not in {origin.generation for origin in pre.origins}
    assert replace(post, generation=pre.generation, nonce=pre.nonce, origins=pre.origins,
                   bonds=pre.bonds, fi=pre.fi, schedule=pre.schedule) == pre

    for before, after in zip(pre.bonds, post.bonds, strict=True):
        if before.bond_id in action.exclusions and before.slot is not None:
            expected_exit = _expected_exit(before, pre.block)
            expected_update = pre.block if expected_exit != before.exit_effective else before.registry_update_block
            assert after == replace(before, exit_effective=expected_exit, registry_update_block=expected_update)
        else:
            assert after == before
    for before, after in zip(pre.fi, post.fi, strict=True):
        expected_hash = (EMPTY_HASH if before.index in action.fi_to_clear else before.tx_hash)
        assert after == replace(before, tx_hash=expected_hash)

    a, n, t, stop = post.schedule
    assert stop == 0
    if action.rules:
        assert a == n == action.rules == pre.schedule[1] + 1 and t == 0
    else:
        assert (a, n, t) == pre.schedule[:3]
    packed = a | (n << 48) | (t << 96)
    assert result.events == (
        ("Recovered", post.generation, pre.c, pre.block, pre.timestamp, post.nonce,
         action.exclusions, action.fi_to_clear),
        ("RulesScheduleUpdated", packed),
    )


def check(pre: State, action: Action, result: Transition[State]) -> None:
    """Check the entire projected state and events of each accepted edge."""
    post = result.state
    if isinstance(action, Recover):
        _check_recovery(pre, action, result)
    elif isinstance(action, InvalidateNonce):
        assert pre.initialized and action.caller == "inbox-dao" and action.expected_nonce == pre.nonce
        assert post == replace(pre, nonce=pre.nonce + 1) and post.nonce < 2**256
        assert result.events == (("RecoveryNonceInvalidated", pre.nonce, post.nonce),)
    elif isinstance(action, Land):
        assert action.admitted and pre.initialized and pre.started
        assert post.landings[:-1] == pre.landings and post.landings[-1] == action.record
        assert pre.c < post.c and action.record.parent == pre.c
        assert action.record.generation == pre.generation
        assert any(record.generation == pre.generation and record.start_height <= pre.c
                   for record in pre.origins)
        assert pre.fi_head <= post.fi_head <= pre.fi_tail
        assert post.fi_head - pre.fi_head <= post.c - pre.c
        assert pre.active_snapshot <= post.active_snapshot < pre.block
        assert replace(post, landings=pre.landings) == pre and result.events == ()
    elif isinstance(action, Rollback):
        assert action.admitted
        assert post.c == action.trusted_c < pre.c
        assert post.landings == tuple(landing for landing in pre.landings if landing.c <= post.c)
        assert post.nonce == pre.nonce + 1 and post.nonce < 2**256
        for before, after in zip(pre.bonds, post.bonds, strict=True):
            confirmation = before.exit_confirmed
            if confirmation is not None and before.exit_effective > post.active_snapshot:
                confirmation = None
            assert after == replace(before, exit_confirmed=confirmation)
        assert replace(post, landings=pre.landings, nonce=pre.nonce, bonds=pre.bonds) == pre
        assert result.events == ()
    elif isinstance(action, Forfeit):
        assert pre.initialized and action.caller == "registry-dao" and action.transfer_succeeds
        assert pre.timestamp <= action.valid_until < 2**256
        old = {bond.bond_id: bond for bond in pre.bonds}
        assert action.bond_id in old
        paid = post.sink - pre.sink
        for before, after in zip(pre.bonds, post.bonds, strict=True):
            if before.bond_id != action.bond_id:
                assert after == before
                continue
            assert not before.withdrawn and not before.forfeited and after.forfeited
            principal = before.effective + before.pending
            assert principal > 0 and 0 <= paid * 10000 - principal * 3333 < 10000
            assert after.effective + after.pending == principal - paid
            assert after.effective == max(0, before.effective - paid)
            assert after.ready_at == (before.ready_at if after.pending else None)
            new_exit = _expected_exit(before, pre.block)
            assert after.exit_effective == new_exit
            changed = after.effective != before.effective or new_exit != before.exit_effective
            assert after.registry_update_block == (pre.block if changed else before.registry_update_block)
            assert replace(after, effective=before.effective, pending=before.pending,
                           ready_at=before.ready_at, forfeited=before.forfeited,
                           exit_effective=before.exit_effective,
                           registry_update_block=before.registry_update_block) == before
            assert result.events == (("Forfeited", action.bond_id, action.incident, principal, paid),)
        assert replace(post, bonds=pre.bonds, sink=pre.sink) == pre
    elif isinstance(action, AdvanceBlock):
        assert action.number > pre.block and action.timestamp > pre.timestamp
        assert post == replace(pre, block=action.number, timestamp=action.timestamp) and result.events == ()
    else:
        raise TypeError(f"unknown recovery action: {action!r}")
