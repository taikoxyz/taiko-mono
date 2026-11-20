"""Z05 bounded, symbolic projection of the f556 final-R selection rules.

The seeds assume prior authenticated history, a started Inbox and the indicated
mature deposit and landing/confirmation. They do not reconstruct that history.
Stake 4, unit 2 and increment 1 are conditional arithmetic units. Symbolic key
ranks represent fixed set-key order. The projection has two slots and the bank
offers three distinct permanent identities. No quotient or deployment claim
follows from these choices.

Byte commitments, PoP, transfers, DAO authorization, signer authentication,
canonical finality and valid landing proofs/signatures are outside the model.
The relevant successful checks are premises or explicit inputs. Each action is
atomic. There is no EVM, FI or rules-upgrade model here.
"""

from collections.abc import Iterator
from dataclasses import dataclass, replace

from .explorer import Edge, Refused, RefusedEdge, Transition, explore


R = 7
ACTIVATION_DELAY = 1
EXIT_DELAY = 1
WITHDRAWAL_DELAY = 1
MIN_STAKE = 4
VP_UNIT = 2
N_MAX = 1
SLOT_COUNT = 2
EPOCH_LENGTH = 5
FORFEIT_BPS = 5000
MAX_POWER = (2**63 - 1) // 8
UINT48_MAX = 2**48 - 1
UINT256_MAX = 2**256 - 1
KEY_ORDER = ("C", "A", "B")
DAO = "dao"


@dataclass(frozen=True, slots=True)
class Entry:
    key: str
    effective: int
    active_from: int
    exit_at: int | None


@dataclass(frozen=True, slots=True)
class Bond:
    # Its position in State.bonds is its permanently issued bond ID.
    key: str
    owner: str | None
    slot: int | None
    active_from: int
    effective: int
    exit_at: int | None = None
    pending: int = 0
    ready_at: int = 0
    confirmed_at: int = 0
    forfeited: bool = False


@dataclass(frozen=True, slots=True)
class RegistryCheckpoint:
    block: int
    entries: tuple[Entry | None, ...]

    @property
    def count(self) -> int:
        return len(self.entries)


@dataclass(frozen=True, slots=True)
class Origin:
    generation: int
    height: int
    block: int
    timestamp: int


@dataclass(frozen=True, slots=True)
class Committee:
    generation: int
    target_epoch: int
    cutoff: int
    members: tuple[tuple[str, int], ...]

    @property
    def total_power(self) -> int:
        return sum(power for _, power in self.members)


@dataclass(frozen=True, slots=True)
class FinalizedView:
    origin: Origin
    checkpoint: RegistryCheckpoint
    signer_verified: bool


@dataclass(frozen=True, slots=True)
class Landing:
    height: int
    generation: int
    snapshot: int


@dataclass(frozen=True, slots=True)
class State:
    block: int
    timestamp: int
    closed: bool
    entry_changed: bool
    bonds: tuple[Bond, ...]
    checkpoints: tuple[RegistryCheckpoint, ...]
    origins: tuple[Origin, ...]
    nonce: int
    view: FinalizedView | None
    committee: Committee | None
    pending_update: tuple[int, ...]
    last_landed: Landing
    sink: int
    withdrawn: int

    @property
    def can_sign(self) -> bool:
        return self.view is not None and self.view.signer_verified and self.committee is not None


@dataclass(frozen=True, slots=True)
class Recover:
    generation: int
    height: int
    nonce: int
    valid_until: int
    exclusions: tuple[int, ...] = ()
    caller: str = DAO


@dataclass(frozen=True, slots=True)
class Forfeit:
    bond_id: int
    valid_until: int
    caller: str = DAO
    incident: str = "incident"


@dataclass(frozen=True, slots=True)
class Register:
    key: str
    owner: str
    amount: int


@dataclass(frozen=True, slots=True)
class TopUp:
    bond_id: int
    owner: str
    amount: int


@dataclass(frozen=True, slots=True)
class ActivateTopUp:
    bond_id: int


@dataclass(frozen=True, slots=True)
class RequestExit:
    bond_id: int
    owner: str


@dataclass(frozen=True, slots=True)
class ConfirmExit:
    bond_id: int


@dataclass(frozen=True, slots=True)
class Withdraw:
    bond_id: int
    caller: str


@dataclass(frozen=True, slots=True)
class Close:
    pass


@dataclass(frozen=True, slots=True)
class Advance:
    block: int
    timestamp: int


@dataclass(frozen=True, slots=True)
class Authenticate:
    origin: Origin
    checkpoint: RegistryCheckpoint
    verified: bool = True
    signer_verified: bool = True


@dataclass(frozen=True, slots=True)
class Select:
    pass


@dataclass(frozen=True, slots=True)
class Land:
    generation: int
    height: int
    signing_snapshot: int
    verified: bool = True


Action = (Recover | Forfeit | Register | TopUp | ActivateTopUp | RequestExit | ConfirmExit
          | Withdraw | Close | Advance | Authenticate | Select | Land)


def initial(*, withdrawable: bool = True) -> State:
    # A and B are registered and active by snapshot 3. A leads the earlier
    # selection. In the withdrawal seed, exit 5 has since been covered by a
    # landing and confirmed at 6. B's pre-R deposit is mature in both seeds.
    # The opaque pending-update height belongs to an unsettled old suffix.
    a = Bond("A", "owner-A", 0, 2, 6)
    b = Bond("B", "owner-B", 1, 3, 5, pending=1, ready_at=R)
    checkpoints = (RegistryCheckpoint(3, _entries((a, b))),)
    if withdrawable:
        a = replace(a, exit_at=5, confirmed_at=6)
        checkpoints += (RegistryCheckpoint(4, _entries((a, b))),)
    return State(R, 1000, False, False, (a, b), checkpoints,
                 (Origin(0, 0, 3, 400),), 0, None, None, (14,),
                 Landing(11, 0, 5 if withdrawable else 3), 0, 0)


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise Refused(reason)


def _entries(bonds: tuple[Bond, ...]) -> tuple[Entry | None, ...]:
    slots = [None] * SLOT_COUNT
    for bond in bonds:
        if bond.slot is not None:
            slots[bond.slot] = Entry(bond.key, bond.effective, bond.active_from, bond.exit_at)
    while slots and slots[-1] is None:
        slots.pop()
    return tuple(slots)


def _registry(state: State, bonds: tuple[Bond, ...], **changes) -> State:
    return replace(state, bonds=bonds, entry_changed=(
        state.entry_changed or _entries(state.bonds) != _entries(bonds)
    ), **changes)


def _lookup(state: State, bond_id: int) -> Bond:
    _require(type(bond_id) is int and 0 <= bond_id < len(state.bonds), "unissued bond")
    return state.bonds[bond_id]


def _earlier_exit(bond: Bond, block: int) -> int | None:
    if bond.exit_at is None and block == UINT48_MAX:
        return None
    return block if bond.exit_at is None else min(bond.exit_at, block)


def _change_bond(state: State, bond_id: int, after: Bond, event: tuple = (), **changes) -> Transition[State]:
    bonds = state.bonds[:bond_id] + (after,) + state.bonds[bond_id + 1:]
    return Transition(_registry(state, bonds, **changes), (event,) if event else ())


def _checkpoint_at(state: State, block: int) -> RegistryCheckpoint | None:
    return next((checkpoint for checkpoint in reversed(state.checkpoints)
                 if checkpoint.block <= block), None)


def derive(view: FinalizedView) -> Committee:
    """Derive from the authenticated symbolic checkpoint, at the origin block."""
    origin, checkpoint = view.origin, view.checkpoint
    _require(checkpoint.block <= origin.block and checkpoint.count <= SLOT_COUNT
             and (not checkpoint.entries or checkpoint.entries[-1] is not None),
             "invalid checkpoint shape")
    eligible = [entry for entry in checkpoint.entries
                if entry is not None and entry.active_from <= origin.block
                and origin.block < (UINT48_MAX if entry.exit_at is None else entry.exit_at)
                and entry.effective >= MIN_STAKE]
    keys = {entry.key for entry in eligible}
    _require(len(keys) == len(eligible), "duplicate eligible key")
    _require(keys.issubset(KEY_ORDER), "unknown symbolic key")
    eligible.sort(key=lambda entry: (-entry.effective, KEY_ORDER.index(entry.key)))
    chosen = sorted(eligible[:N_MAX], key=lambda entry: KEY_ORDER.index(entry.key))
    members = tuple((entry.key, entry.effective // VP_UNIT) for entry in chosen)
    _require(bool(members), "empty eligible set")
    _require(all(0 < power < 2**64 for _, power in members)
             and sum(power for _, power in members) <= MAX_POWER, "invalid committee power")
    return Committee(origin.generation, origin.height // EPOCH_LENGTH, origin.block, members)


def step(state: State, action: Action) -> Transition[State]:
    """Apply one transaction or observation and return its entire projected result."""
    origin = state.origins[-1]

    if isinstance(action, Close):
        _require(not state.closed, "block already closed")
        checkpoint = RegistryCheckpoint(state.block, _entries(state.bonds))
        events = (("Checkpoint", checkpoint),) if state.entry_changed else ()
        checkpoints = state.checkpoints + ((checkpoint,) if state.entry_changed else ())
        return Transition(replace(state, closed=True, entry_changed=False, checkpoints=checkpoints), events)

    if isinstance(action, Advance):
        _require(state.closed, "open block must close before advance")
        _require(state.block < action.block <= UINT48_MAX
                 and state.timestamp < action.timestamp <= UINT256_MAX,
                 "clock must advance within range")
        # Any skipped blocks are assumed to have no projected operations.
        return Transition(replace(state, block=action.block, timestamp=action.timestamp, closed=False))

    if isinstance(action, Authenticate):
        _require(origin.generation > 0 and action.origin == origin, "recovery origin mismatch")
        _require(origin.block < state.block or state.closed, "snapshot block still open")
        _require(action.verified, "finality authentication failed")
        _require(action.checkpoint == _checkpoint_at(state, origin.block), "final checkpoint mismatch")
        view = FinalizedView(origin, action.checkpoint, action.signer_verified)
        return Transition(replace(state, view=view), (("Authenticated", view),))

    if isinstance(action, Select):
        _require(state.view is not None, "authenticated final snapshot required")
        committee = derive(state.view)
        return Transition(replace(state, committee=committee), (("Selected", committee),))

    _require(not state.closed, "transaction requires open block")

    if isinstance(action, Recover):
        _require(action.caller == DAO, "Inbox owner required")
        _require((action.generation, action.height, action.nonce)
                 == (origin.generation, state.last_landed.height, state.nonce), "stale recovery")
        _require(state.timestamp <= action.valid_until <= UINT256_MAX, "recovery expired")
        _require(origin.generation < UINT48_MAX and state.nonce < UINT256_MAX, "recovery counter overflow")
        _require(tuple(sorted(set(action.exclusions))) == action.exclusions,
                 "exclusions must be strictly increasing")
        for bond_id in action.exclusions:
            _lookup(state, bond_id)
        bonds = tuple(replace(bond, exit_at=_earlier_exit(bond, state.block))
                      if bond_id in action.exclusions else bond
                      for bond_id, bond in enumerate(state.bonds))
        new_origin = Origin(origin.generation + 1, state.last_landed.height, state.block, state.timestamp)
        post = _registry(state, bonds, origins=state.origins + (new_origin,), nonce=state.nonce + 1,
                         view=None, committee=None, pending_update=())
        return Transition(post, (("Recovered", new_origin, post.nonce, action.exclusions),))

    if isinstance(action, Land):
        # This action represents a proof for a landing under the derived
        # genesis committee in this modeled history. Other Land flows are out of scope.
        _require(state.block > origin.block, "landing must follow the origin block")
        _require(action.verified, "landing proof or signature invalid")
        _require(action.generation == origin.generation, "landing generation mismatch")
        _require(state.last_landed.height < action.height < 2**48, "landing height must advance")
        _require(action.signing_snapshot == origin.block
                 and action.signing_snapshot >= state.last_landed.snapshot, "landing signing snapshot mismatch")
        # An external proof uses the canonical origin and checkpoint. This
        # observer may not have authenticated its view or opened its signer.
        checkpoint = _checkpoint_at(state, origin.block)
        _require(checkpoint is not None, "landing checkpoint missing")
        derive(FinalizedView(origin, checkpoint, signer_verified=False))
        landing = Landing(action.height, action.generation, action.signing_snapshot)
        return Transition(replace(state, last_landed=landing), (("Landed", landing),))

    if isinstance(action, Register):
        _require(action.key in KEY_ORDER and all(bond.key != action.key for bond in state.bonds),
                 "unknown or previously registered key")
        occupied = {bond.slot for bond in state.bonds}
        slot = next((slot for slot in range(SLOT_COUNT) if slot not in occupied), None)
        _require(slot is not None, "no vacant slot")
        _require(MIN_STAKE <= action.amount <= UINT256_MAX, "invalid registration amount")
        active_from = state.block + ACTIVATION_DELAY
        _require(active_from <= UINT48_MAX, "activation block overflow")
        bond = Bond(action.key, action.owner, slot, active_from, action.amount)
        return Transition(_registry(state, state.bonds + (bond,)),
                          (("Registered", len(state.bonds), slot, bond),))

    bond = _lookup(state, action.bond_id)
    _require(bond.slot is not None, "withdrawn bond")

    if isinstance(action, Forfeit):
        _require(action.caller == DAO, "registry owner required")
        _require(not bond.forfeited, "bond already forfeited")
        _require(state.timestamp <= action.valid_until <= UINT256_MAX, "forfeiture expired")
        balance = bond.effective + bond.pending
        _require(balance > 0, "zero forfeiture balance")
        penalty = (balance * FORFEIT_BPS + 9999) // 10000
        remaining = balance - penalty
        pending = min(bond.pending, remaining)
        after = replace(bond, effective=remaining - pending, pending=pending,
                        ready_at=bond.ready_at if pending else 0,
                        exit_at=_earlier_exit(bond, state.block), forfeited=True)
        return _change_bond(state, action.bond_id, after,
                            ("Forfeited", action.bond_id, action.incident, balance, penalty),
                            sink=state.sink + penalty)

    if isinstance(action, TopUp):
        _require(action.owner == bond.owner, "bond owner required")
        _require(bond.exit_at is None, "exit already set")
        _require(state.block >= bond.active_from and bond.effective > 0, "bond is not active and funded")
        _require(bond.pending == 0, "top-up already pending")
        _require(0 < action.amount <= UINT256_MAX - bond.effective, "invalid top-up amount")
        ready_at = state.block + ACTIVATION_DELAY
        _require(ready_at <= UINT48_MAX, "top-up ready block overflow")
        return _change_bond(state, action.bond_id, replace(bond, pending=action.amount, ready_at=ready_at))

    if isinstance(action, ActivateTopUp):
        _require(bond.exit_at is None, "exit already set")
        _require(bond.pending > 0 and state.block >= bond.ready_at, "no matured top-up")
        after = replace(bond, effective=bond.effective + bond.pending, pending=0, ready_at=0)
        return _change_bond(state, action.bond_id, after, ("Activated", action.bond_id, bond.pending))

    if isinstance(action, RequestExit):
        _require(action.owner == bond.owner, "bond owner required")
        _require(bond.exit_at is None, "exit already set")
        exit_at = max(state.block, bond.active_from) + EXIT_DELAY
        _require(exit_at < UINT48_MAX, "exit block overflow")
        return _change_bond(state, action.bond_id, replace(bond, exit_at=exit_at))

    if isinstance(action, ConfirmExit):
        _require(bond.exit_at is not None, "no exit to confirm")
        _require(state.last_landed.snapshot >= bond.exit_at, "landed snapshot precedes exit")
        after = replace(bond, confirmed_at=bond.confirmed_at or state.block)
        return _change_bond(state, action.bond_id, after)

    if isinstance(action, Withdraw):
        _require(bond.confirmed_at > 0, "exit unconfirmed")
        _require(state.block >= bond.confirmed_at + WITHDRAWAL_DELAY, "withdrawal delay not elapsed")
        balance = bond.effective + bond.pending
        _require(balance == 0 or action.caller == bond.owner, "bond owner required")
        after = replace(bond, owner=None, slot=None, effective=0, pending=0, ready_at=0, confirmed_at=0)
        return _change_bond(state, action.bond_id, after, ("Withdrawn", action.bond_id, balance),
                            withdrawn=state.withdrawn + balance)

    raise TypeError(f"unknown action {type(action).__name__}")


RECOVER_A = Recover(0, 11, 0, 1000, (0,))
RECOVER_B = Recover(0, 11, 0, 1000, (1,))
RECOVER_C = Recover(0, 11, 0, 1000, (2,))
RECOVER_EMPTY = Recover(0, 11, 0, 1000)
FORFEIT_B = Forfeit(1, 1012)
ACTIVATE_B = ActivateTopUp(1)
WITHDRAW_A = Withdraw(0, "owner-A")
REGISTER_C = Register("C", "owner-C", 4)
LAND = Land(1, 12, R)
CLOCK = {R: Advance(8, 1012), 8: Advance(110, 2236)}


def actions(state: State) -> Iterator[Action]:
    """One finite bank. Clock/location offers are exploration choices."""
    yield Close()
    yield Select()
    if state.block in CLOCK:
        yield CLOCK[state.block]
    if state.block == R:
        # C can first issue in this block. It cannot appear in the finalized
        # history required before DAO authorization, so keep only its
        # unissued-ID refusal here. Raw Recover execution remains independent.
        if len(state.bonds) == 2:
            yield RECOVER_C
        yield from (RECOVER_A, RECOVER_B, RECOVER_EMPTY, WITHDRAW_A, REGISTER_C,
                    RequestExit(1, "owner-B"))
    if state.block in (R, 8):
        yield from (FORFEIT_B, ACTIVATE_B, ConfirmExit(2), Withdraw(2, "owner-C"))
    if state.origins[-1].generation > 0:
        origin = state.origins[-1]
        checkpoint = _checkpoint_at(state, origin.block)
        view = Authenticate(origin, checkpoint)
        yield replace(view, verified=False)
        if state.block == R and not state.closed:
            yield view  # A premature claim must refuse even if marked verified.
        if state.block == 110:
            yield view
            yield replace(view, signer_verified=False)
            if checkpoint.block == R:
                yield replace(view, checkpoint=state.checkpoints[0])
    if state.block == 110:
        yield from (LAND, replace(LAND, verified=False), replace(LAND, signing_snapshot=8),
                    ConfirmExit(0), ConfirmExit(1), WITHDRAW_A)


def _expected_entries(bonds: tuple[Bond, ...]) -> tuple[Entry | None, ...]:
    by_slot = {b.slot: Entry(b.key, b.effective, b.active_from, b.exit_at)
               for b in bonds if b.slot is not None}
    assert len(by_slot) == sum(b.slot is not None for b in bonds)
    assert all(0 <= slot < SLOT_COUNT for slot in by_slot)
    return tuple(by_slot.get(i) for i in range(max(by_slot, default=-1) + 1))


def _check_result(pre: State, action: Action, actual: Transition[State]) -> None:
    """Independently specify the projected frame and event for each accepted edge."""
    expected = pre
    events = ()
    if isinstance(action, Close):
        expected = replace(pre, closed=True, entry_changed=False)
        if pre.entry_changed:
            checkpoint = RegistryCheckpoint(pre.block, _expected_entries(pre.bonds))
            expected = replace(expected, checkpoints=pre.checkpoints + (checkpoint,))
            events = (("Checkpoint", checkpoint),)
    elif isinstance(action, Advance):
        assert pre.block < action.block < 2**48 and pre.timestamp < action.timestamp < 2**256
        expected = replace(pre, closed=False, block=action.block, timestamp=action.timestamp)
    elif isinstance(action, Authenticate):
        origin = pre.origins[-1]
        checkpoints = tuple(cp for cp in pre.checkpoints if cp.block <= origin.block)
        assert checkpoints and (pre.block > origin.block or pre.closed)
        assert action.verified and (action.origin, action.checkpoint) == (origin, checkpoints[-1])
        view = FinalizedView(origin, checkpoints[-1], action.signer_verified)
        expected = replace(pre, view=view)
        events = (("Authenticated", view),)
    elif isinstance(action, Select):
        assert pre.view is not None
        origin = pre.origins[-1]
        checkpoints = tuple(cp for cp in pre.checkpoints if cp.block <= origin.block)
        assert checkpoints and (pre.block > origin.block or pre.closed)
        candidates = {}
        for row in checkpoints[-1].entries:
            if row and row.effective >= 4 and row.active_from <= origin.block:
                if row.exit_at is None or row.exit_at > origin.block:
                    assert row.key not in candidates
                    candidates[row.key] = row.effective
        ordered = sorted(candidates, key=lambda key: (-candidates[key], ("C", "A", "B").index(key)))
        assert ordered
        winner = ordered[0]
        committee = Committee(origin.generation, origin.height // 5, origin.block,
                              ((winner, candidates[winner] // 2),))
        expected = replace(pre, committee=committee)
        events = (("Selected", committee),)
    elif isinstance(action, Recover):
        assert not pre.closed and action.caller == DAO and action.valid_until >= pre.timestamp
        assert (action.generation, action.height, action.nonce) == (
            pre.origins[-1].generation, pre.last_landed.height, pre.nonce)
        assert tuple(sorted(set(action.exclusions))) == action.exclusions
        assert all(0 <= i < len(pre.bonds) for i in action.exclusions)
        bonds = list(pre.bonds)
        for bond_id in action.exclusions:
            bond = bonds[bond_id]
            if bond.exit_at is None and pre.block == 2**48 - 1:
                continue
            if bond.exit_at is None or bond.exit_at > pre.block:
                bonds[bond_id] = replace(bond, exit_at=pre.block)
        origin = Origin(action.generation + 1, action.height, pre.block, pre.timestamp)
        expected = replace(pre, bonds=tuple(bonds), origins=pre.origins + (origin,),
                           nonce=action.nonce + 1, view=None, committee=None, pending_update=())
        events = (("Recovered", origin, action.nonce + 1, action.exclusions),)
    elif isinstance(action, Land):
        assert not pre.closed and action.verified
        origin = pre.origins[-1]
        assert action.generation == origin.generation and pre.block > origin.block
        assert action.height > pre.last_landed.height
        assert action.signing_snapshot == origin.block >= pre.last_landed.snapshot
        checkpoint = max((cp for cp in pre.checkpoints if cp.block <= origin.block), key=lambda cp: cp.block)
        assert any(row and row.active_from <= origin.block and row.effective >= 4
                   and (row.exit_at is None or row.exit_at > origin.block) for row in checkpoint.entries)
        landing = Landing(action.height, action.generation, origin.block)
        expected = replace(pre, last_landed=landing)
        events = (("Landed", landing),)
    elif isinstance(action, Register):
        assert not pre.closed and action.amount >= 4 and action.key not in {b.key for b in pre.bonds}
        free = set(range(SLOT_COUNT)) - {b.slot for b in pre.bonds}
        bond = Bond(action.key, action.owner, min(free), pre.block + 1, action.amount)
        expected = replace(pre, bonds=pre.bonds + (bond,))
        events = (("Registered", len(pre.bonds), bond.slot, bond),)
    else:
        assert not pre.closed and 0 <= action.bond_id < len(pre.bonds)
        bonds = list(pre.bonds)
        bond = bonds[action.bond_id]
        assert bond.slot is not None
        match action:
            case Forfeit():
                assert not bond.forfeited and action.caller == DAO and pre.timestamp <= action.valid_until
                total = bond.effective + bond.pending
                assert total > 0
                paid = total - total // 2
                effective = max(0, bond.effective - paid)
                pending = total - paid - effective
                unset_exit = 2**48 - 1
                encoded_exit = min(pre.block, bond.exit_at if bond.exit_at is not None else unset_exit)
                exit_at = None if encoded_exit == unset_exit else encoded_exit
                after = replace(bond, effective=effective, pending=pending, exit_at=exit_at,
                                forfeited=True, ready_at=bond.ready_at if pending else 0)
                expected = replace(pre, sink=pre.sink + paid)
                events = (("Forfeited", action.bond_id, action.incident, total, paid),)
            case TopUp():
                assert bond.owner == action.owner and bond.exit_at is None and not bond.pending
                assert bond.active_from <= pre.block and min(bond.effective, action.amount) > 0
                after = replace(bond, pending=action.amount, ready_at=pre.block + 1)
            case ActivateTopUp():
                assert bond.exit_at is None and bond.pending > 0 and bond.ready_at <= pre.block
                after = replace(bond, effective=bond.effective + bond.pending, pending=0, ready_at=0)
                events = (("Activated", action.bond_id, bond.pending),)
            case RequestExit():
                assert action.owner == bond.owner and bond.exit_at is None
                after = replace(bond, exit_at=max(pre.block + 1, bond.active_from + 1))
            case ConfirmExit():
                assert bond.exit_at is not None and bond.exit_at <= pre.last_landed.snapshot
                after = bond if bond.confirmed_at else replace(bond, confirmed_at=pre.block)
            case Withdraw():
                assert 0 < bond.confirmed_at < pre.block
                amount = bond.effective + bond.pending
                assert not amount or action.caller == bond.owner
                after = Bond(bond.key, None, None, bond.active_from, 0, exit_at=bond.exit_at,
                             forfeited=bond.forfeited)
                expected = replace(pre, withdrawn=pre.withdrawn + amount)
                events = (("Withdrawn", action.bond_id, amount),)
            case _:
                raise AssertionError(f"unchecked action {action!r}")
        bonds[action.bond_id] = after
        expected = replace(expected, bonds=tuple(bonds))

    if expected.bonds != pre.bonds:
        dirty = pre.entry_changed or _expected_entries(expected.bonds) != _expected_entries(pre.bonds)
        expected = replace(expected, entry_changed=dirty)
    assert actual == Transition(expected, events), f"incorrect projected result for {action!r}"


def check(pre: State, action: Action, result: Transition[State]) -> None:
    try:
        _check_result(pre, action, result)
    except AssertionError as error:
        raise AssertionError(f"INCONCLUSIVE: accepted edge failed for {action!r}: {error}") from error


@dataclass(frozen=True, slots=True)
class Witness:
    name: str
    prefix: tuple[Edge[State, Action], ...]
    last: Edge[State, Action] | RefusedEdge[State, Action]


def _witnesses(graph, *, withdrawable: bool) -> tuple[Witness, ...]:
    accepted = graph.accepted
    refused = graph.refused
    needs = [
        ("activation before recover", accepted, lambda e: e.action == RECOVER_A
         and e.pre.bonds[1].effective == 6 and e.pre.bonds[1].exit_at is None),
        ("activation after recover", accepted, lambda e: e.action == ACTIVATE_B
         and e.pre.block == R and e.pre.origins[-1].generation == 1),
        ("selection before close", refused, lambda e: isinstance(e.action, Select)
         and e.pre.origins[-1].generation == 1 and not e.pre.closed and e.pre.block == R),
        ("authentication before close", refused, lambda e: isinstance(e.action, Authenticate)
         and e.reason == "snapshot block still open"),
        ("unauthenticated finality", refused, lambda e: isinstance(e.action, Authenticate)
         and e.reason == "finality authentication failed"),
        ("unissued recovery exclusion", refused, lambda e: e.action == RECOVER_C and e.reason == "unissued bond"),
        ("exit blocks mature top-up", refused, lambda e: e.action == ACTIVATE_B
         and e.pre.origins[-1].generation == 1 and e.pre.bonds[1].exit_at == R
         and e.pre.bonds[1].pending > 0 and e.reason == "exit already set"),
        ("occupied but no eligible key", refused, lambda e: isinstance(e.action, Select)
         and e.pre.view is not None and e.pre.view.checkpoint.count > 0 and e.reason == "empty eligible set"),
        ("selection after R+1 mutation", accepted, lambda e: isinstance(e.action, Select)
         and e.pre.checkpoints[-1].block == 8 and e.post.committee.cutoff == R
         and e.post.committee.members == (("B", 2),) and e.pre.bonds[1].effective == 6),
        ("landing advances slot 284", accepted, lambda e: e.action == LAND
         and e.pre.last_landed.snapshot < e.post.last_landed.snapshot == R),
        ("admitted external landing before local selection", accepted, lambda e: e.action == LAND
         and e.pre.view is None and e.post.last_landed.snapshot == R),
        ("landing after local selection", accepted, lambda e: e.action == LAND and e.pre.can_sign),
        ("empty eligible set cannot land", refused, lambda e: e.action == LAND
         and e.reason == "empty eligible set"),
        ("proof/signature refusal", refused, lambda e: isinstance(e.action, Land)
         and e.pre.can_sign and e.reason == "landing proof or signature invalid"),
    ]
    if withdrawable:
        needs += [
            ("reuse before recovery", accepted, lambda e: e.action == RECOVER_A
             and len(e.pre.bonds) == 3 and e.pre.bonds[0].slot is None),
            ("reuse after recovery", accepted, lambda e: e.action == REGISTER_C
             and e.pre.origins[-1].generation == 1 and e.pre.bonds[0].slot is None),
            ("replacement confirmation refusal", refused, lambda e: e.action == ConfirmExit(2)
             and len(e.pre.bonds) == 3 and e.reason == "no exit to confirm"),
        ]
    else:
        needs += [
            ("standby forfeiture before recovery", accepted, lambda e: e.action == RECOVER_A
             and e.pre.bonds[1].forfeited),
            ("standby forfeiture after recovery", accepted, lambda e: e.action == FORFEIT_B
             and e.pre.block == R and e.pre.bonds[0].exit_at == R and e.pre.bonds[1].exit_at is None),
            ("recover cannot confirm a new exit", refused, lambda e: e.action == ConfirmExit(0)
             and e.pre.origins[-1].generation == 1 and e.reason == "landed snapshot precedes exit"),
            ("landing enables confirmation", accepted, lambda e: e.action == ConfirmExit(0)
             and e.pre.bonds[0].exit_at == e.pre.last_landed.snapshot == R
             and e.post.bonds[0].confirmed_at > 0),
        ]
    witnesses = []
    for name, candidates, matches in needs:
        # BFS observation order is nondecreasing accepted-prefix length.
        edge = next((edge for edge in candidates if matches(edge)), None)
        if edge is None:
            raise RuntimeError(f"INCONCLUSIVE: missing witness {name}")
        witnesses.append(Witness(name, graph.path_to(edge.pre), edge))
    return tuple(witnesses)


def assess(*, max_states: int = 25_000):
    """Exhaust both seeds and require every positive and refusal control."""
    results = []
    for withdrawable in (True, False):
        try:
            graph = explore(initial(withdrawable=withdrawable), actions, step, check, max_states=max_states)
            offered = sum(len(tuple(actions(state))) for state in graph.states)
            if len(graph.accepted) + len(graph.refused) != offered:
                raise RuntimeError("incomplete action accounting")
            results.append((graph, _witnesses(graph, withdrawable=withdrawable)))
        except Exception as error:
            if str(error).startswith("INCONCLUSIVE:"):
                raise
            raise RuntimeError(f"INCONCLUSIVE: final-R graph failed: {error}") from error
    return tuple(results)
