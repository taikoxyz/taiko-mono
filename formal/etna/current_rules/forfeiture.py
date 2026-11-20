"""Finite registry and Inbox projection for lifetime bond forfeiture.

Each step is one atomic transaction or a change of L1 context. Caller, key
authentication, token transfer and admitted Inbox operations are input premises.
The modeled 14 units and short block delays are scaled fixtures.
Key and ckAddr labels stand for authenticated nonzero consensus identities.
The owner and reporter are the two selected withdrawal recipient accounts.
"""

from dataclasses import dataclass, replace

from .explorer import Refused, Transition


MAX48 = (1 << 48) - 1
MAX256 = (1 << 256) - 1
SLOT_COUNT = 4096
ACTIVATION_DELAY = 2
EXIT_DELAY = 1
WITHDRAWAL_DELAY = 2
MIN_STAKE = 1
PRINCIPAL = 14
OWNER = "owner"
INCIDENT = bytes.fromhex("40" * 32)
DEADLINE = 1048


@dataclass(frozen=True, slots=True)
class Bond:
    bond_id: int
    key: str
    ck_addr: str
    owner: str | None
    slot: int | None
    eff: int
    pending: int
    ready_at: int
    active_from: int
    exit_effective: int = MAX48
    confirmed_at: int = 0
    withdrawn: bool = False
    forfeited: bool = False

    @property
    def balance(self):
        return self.eff + self.pending


@dataclass(frozen=True, slots=True)
class State:
    bonds: tuple[Bond, ...]
    owner_reserve: int
    reporter: int = 0
    sink: int = 0
    block: int = 100
    timestamp: int = 1000
    active_snapshot: int = 99
    checkpoint_block: int = 99
    generation: int = 0
    c: int = 0
    nonce: int = 0
    initialized: bool = True
    started: bool = True
    forfeit_bps: int = 3333
    slash_bounty_bps: int = 1000


@dataclass(frozen=True, slots=True)
class Advance:
    block: int
    timestamp: int


@dataclass(frozen=True, slots=True)
class Land:
    snapshot: int
    admitted: bool = True


@dataclass(frozen=True, slots=True)
class InvalidateNonce:
    expected_nonce: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class Recover:
    expected_generation: int
    expected_c: int
    expected_nonce: int
    valid_until: int
    owner: bool = True
    admitted: bool = True


@dataclass(frozen=True, slots=True)
class Rollback:
    trusted_c: int
    trusted_snapshot: int
    admitted: bool = True


@dataclass(frozen=True, slots=True)
class Register:
    key: str
    ck_addr: str
    amount: int
    valid_pop: bool = True
    transfer_ok: bool = True


@dataclass(frozen=True, slots=True)
class TopUp:
    bond_id: int
    amount: int
    owner: bool = True
    transfer_ok: bool = True


@dataclass(frozen=True, slots=True)
class ActivateTopUp:
    bond_id: int


@dataclass(frozen=True, slots=True)
class RequestExit:
    bond_id: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class ConfirmExit:
    bond_id: int


@dataclass(frozen=True, slots=True)
class Withdraw:
    bond_id: int
    owner: bool = True
    to_owner: bool = True
    transfer_ok: bool = True


@dataclass(frozen=True, slots=True)
class Forfeit:
    bond_id: int
    incident_id: bytes
    valid_until: int
    owner: bool = True
    transfer_ok: bool = True


@dataclass(frozen=True, slots=True)
class Slash:
    bond_id: int
    key: str
    self_report: bool = False
    valid_evidence: bool = True
    evidence_generation: int = 0
    transfer_ok: bool = True


def _require(condition, reason):
    if not condition:
        raise Refused(reason)


def _uint(value, maximum, label):
    _require(type(value) is int and 0 <= value <= maximum, label)


def penalty(balance, bps):
    _uint(balance, MAX256, "balance must fit uint256")
    _require(type(bps) is int and 0 < bps <= 10_000, "invalid forfeiture rate")
    return (balance * bps + 9_999) // 10_000


def bounty(balance, bps):
    _uint(balance, MAX256, "balance must fit uint256")
    _require(type(bps) is int and 0 <= bps < 10_000, "invalid bounty rate")
    return balance * bps // 10_000


def initial(seed=(9, 4, 1)):
    eff, pending, reserve = seed
    if min(seed) < 0 or sum(seed) != PRINCIPAL:
        raise ValueError("seed must partition the tracked principal")
    bond = Bond(0, "key0", "address0", OWNER, 0, eff, pending, 102 if pending else 0, 99)
    return State((bond,), reserve)


def slot_holder(state, slot):
    _uint(slot, SLOT_COUNT - 1, "slot index must be an integer in 0..4095")
    for bond in state.bonds:
        if bond.slot == slot:
            return True, bond.bond_id
    return False, 0


def key_bond(state, ck_addr):
    for bond in state.bonds:
        if bond.ck_addr == ck_addr:
            return True, bond.bond_id
    return False, 0


def _entry(bond):
    return (bond.key, bond.eff, bond.active_from, bond.exit_effective)


def _update_bond(state, before, after, **changes):
    bonds = state.bonds[:before.bond_id] + (after,) + state.bonds[before.bond_id + 1:]
    if before.slot is not None and (after.slot is None or _entry(before) != _entry(after)):
        changes["checkpoint_block"] = state.block
    return replace(state, bonds=bonds, **changes)


def step(state, action):
    """Return the committed projection and the selected specified ABI events."""
    if isinstance(action, Advance):
        _uint(action.block, MAX48, "L1 block must fit uint48")
        _uint(action.timestamp, MAX256, "L1 timestamp must fit uint256")
        _require(action.block > state.block and action.timestamp > state.timestamp,
                 "L1 context must advance")
        return Transition(replace(state, block=action.block, timestamp=action.timestamp))

    if isinstance(action, Land):
        _require(state.initialized and state.started and action.admitted, "unadmitted landing")
        _require(state.active_snapshot <= action.snapshot < state.block, "invalid landed snapshot")
        return Transition(replace(state, c=state.c + 1, active_snapshot=action.snapshot))

    if isinstance(action, (InvalidateNonce, Recover)):
        _require(state.initialized and action.owner, "Inbox initialization and owner required")
        if isinstance(action, Recover):
            _require(state.started and action.admitted, "unadmitted recovery")
            _require(action.expected_generation == state.generation, "stale generation")
            _require(action.expected_c == state.c, "stale checkpoint")
            _uint(action.valid_until, MAX256, "validUntil must fit uint256")
            _require(state.timestamp <= action.valid_until, "recovery expired")
        _require(action.expected_nonce == state.nonce, "stale recovery nonce")
        _uint(state.nonce + 1, MAX256, "recovery nonce overflow")
        if isinstance(action, Recover):
            _uint(state.generation + 1, MAX48, "generation overflow")
            return Transition(replace(state, generation=state.generation + 1, nonce=state.nonce + 1))
        events = (("RecoveryNonceInvalidated", state.nonce, state.nonce + 1),)
        return Transition(replace(state, nonce=state.nonce + 1), events)

    if isinstance(action, Rollback):
        _require(state.initialized and state.started and action.admitted, "unadmitted rollback")
        _require(0 <= action.trusted_c < state.c, "rollback must restore an earlier checkpoint")
        _require(0 <= action.trusted_snapshot <= state.active_snapshot, "invalid restored snapshot")
        _uint(state.nonce + 1, MAX256, "recovery nonce overflow")
        bonds = tuple(
            replace(bond, confirmed_at=0)
            if bond.confirmed_at and action.trusted_snapshot < bond.exit_effective else bond
            for bond in state.bonds
        )
        return Transition(replace(state, bonds=bonds, c=action.trusted_c, nonce=state.nonce + 1,
                                  active_snapshot=action.trusted_snapshot))

    if isinstance(action, Register):
        _uint(action.amount, MAX256, "deposit must fit uint256")
        _require(action.amount >= MIN_STAKE, "deposit below minimum stake")
        _require(action.valid_pop and action.key and action.ck_addr, "invalid authenticated key")
        _require(not key_bond(state, action.ck_addr)[0], "key already registered")
        occupied = {bond.slot for bond in state.bonds}
        slot = next((slot for slot in range(SLOT_COUNT) if slot not in occupied), None)
        _require(slot is not None, "no empty registry slot")
        _uint(len(state.bonds), MAX256, "bond ID overflow")
        _uint(state.block + ACTIVATION_DELAY, MAX48, "activation block overflow")
        _require(action.transfer_ok and state.owner_reserve >= action.amount, "deposit transfer failed")
        bond = Bond(len(state.bonds), action.key, action.ck_addr, OWNER, slot, action.amount, 0, 0,
                    state.block + ACTIVATION_DELAY)
        return Transition(replace(state, bonds=state.bonds + (bond,), checkpoint_block=state.block,
                                  owner_reserve=state.owner_reserve - action.amount))

    _uint(action.bond_id, MAX256, "bond ID must fit uint256")
    _require(action.bond_id < len(state.bonds), "unissued bond")
    bond = state.bonds[action.bond_id]
    _require(not bond.withdrawn, "withdrawn bond")

    if isinstance(action, TopUp):
        _require(action.owner, "bond owner required")
        _require(bond.exit_effective == MAX48, "exit already set")
        _require(state.block >= bond.active_from and bond.eff > 0, "bond not active and funded")
        _require(bond.pending == 0, "top-up already pending")
        _uint(action.amount, MAX256, "top-up amount must fit uint256")
        _require(action.amount > 0, "top-up must be positive")
        _uint(bond.eff + action.amount, MAX256, "balance overflow")
        ready_at = state.block + ACTIVATION_DELAY
        _uint(ready_at, MAX48, "top-up ready block overflow")
        _require(action.transfer_ok and state.owner_reserve >= action.amount, "top-up transfer failed")
        after = replace(bond, pending=action.amount, ready_at=ready_at)
        return Transition(_update_bond(state, bond, after, owner_reserve=state.owner_reserve - action.amount),
                          (("TopUpDeposited", bond.bond_id, action.amount, ready_at),))

    if isinstance(action, ActivateTopUp):
        _require(bond.exit_effective == MAX48, "exit already set")
        _require(bond.pending > 0, "no pending top-up")
        _require(state.block >= bond.ready_at, "top-up maturity not reached")
        after = replace(bond, eff=bond.balance, pending=0, ready_at=0)
        return Transition(_update_bond(state, bond, after),
                          (("TopUpActivated", bond.bond_id, bond.pending),))

    if isinstance(action, RequestExit):
        _require(action.owner, "bond owner required")
        _require(bond.exit_effective == MAX48, "exit already set")
        block = max(state.block, bond.active_from) + EXIT_DELAY
        _uint(block, MAX48 - 1, "exit block reaches reserved sentinel")
        return Transition(_update_bond(state, bond, replace(bond, exit_effective=block)))

    if isinstance(action, ConfirmExit):
        _require(state.initialized, "Inbox initialization required")
        _require(bond.exit_effective != MAX48, "no exit to confirm")
        _require(state.active_snapshot >= bond.exit_effective, "landed snapshot precedes exit")
        if bond.confirmed_at:
            return Transition(state)
        return Transition(_update_bond(state, bond, replace(bond, confirmed_at=state.block)))

    if isinstance(action, Withdraw):
        _require(bond.confirmed_at > 0, "exit is unconfirmed")
        _require(state.block >= bond.confirmed_at + WITHDRAWAL_DELAY, "withdrawal delay not elapsed")
        if bond.balance:
            _require(action.owner, "bond owner required for positive withdrawal")
            _require(action.transfer_ok, "withdrawal transfer failed")
        after = replace(bond, owner=None, slot=None, eff=0, pending=0, ready_at=0,
                        confirmed_at=0, withdrawn=True)
        if action.to_owner:
            return Transition(_update_bond(state, bond, after, owner_reserve=state.owner_reserve + bond.balance))
        return Transition(_update_bond(state, bond, after, reporter=state.reporter + bond.balance))

    if isinstance(action, Forfeit):
        _require(state.initialized and action.owner, "Inbox initialization and registry owner required")
        _uint(action.valid_until, MAX256, "validUntil must fit uint256")
        _require(type(action.incident_id) is bytes and len(action.incident_id) == 32, "incident must fit bytes32")
        _require(not bond.forfeited, "bond already forfeited")
        _require(state.timestamp <= action.valid_until, "forfeiture expired")
        _require(bond.balance > 0, "zero balance")
        paid = penalty(bond.balance, state.forfeit_bps)
        effective_paid = min(bond.eff, paid)
        pending = bond.pending - (paid - effective_paid)
        after = replace(bond, eff=bond.eff - effective_paid, pending=pending,
                        ready_at=bond.ready_at if pending else 0, forfeited=True,
                        exit_effective=min(bond.exit_effective, state.block))
        _require(action.transfer_ok, "forfeiture transfer failed")
        return Transition(_update_bond(state, bond, after, sink=state.sink + paid),
                          (("Forfeited", bond.bond_id, action.incident_id, bond.balance, paid),))

    if isinstance(action, Slash):
        _require(state.initialized, "Inbox initialization required")
        _require(action.valid_evidence and action.key == bond.key
                 and 0 <= action.evidence_generation <= state.generation, "invalid double-sign evidence")
        _require(bond.balance > 0, "zero balance")
        reward = bounty(bond.balance, state.slash_bounty_bps)
        after = replace(bond, eff=0, pending=0, ready_at=0,
                        exit_effective=min(bond.exit_effective, state.block))
        _require(action.transfer_ok, "slash transfer failed")
        return Transition(_update_bond(
            state, bond, after, sink=state.sink + bond.balance - reward,
            owner_reserve=state.owner_reserve + (reward if action.self_report else 0),
            reporter=state.reporter + (0 if action.self_report else reward),
        ))

    raise TypeError(f"unknown action {type(action).__name__}")


PREAUTHORIZED = Forfeit(0, INCIDENT, DEADLINE)
RECOVERY = Recover(0, 0, 0, DEADLINE)
REPLACEMENT = Register("key1", "address1", 2)
CLOCK = ((100, 1000), (101, 1012), (102, 1024), (103, 1036), (104, 1048), (105, 1060))


def actions(state):
    """Offer the finite bank. Valid writes beyond its horizon are outside the bank."""
    for block, timestamp in CLOCK:
        if block == state.block + 1:
            yield Advance(block, timestamp)
    if state.c == 0 and state.block > CLOCK[0][0]:
        yield Land(state.block - 1)
    yield InvalidateNonce(0)
    yield RECOVERY

    yield TopUp(0, 9)
    yield ActivateTopUp(0)
    yield RequestExit(0)
    yield ConfirmExit(0)
    yield Withdraw(0)
    yield Withdraw(0, owner=False)
    yield PREAUTHORIZED
    yield replace(PREAUTHORIZED, transfer_ok=False)
    yield Forfeit(2, INCIDENT, DEADLINE)
    yield Slash(0, "key0")
    yield Slash(0, "key0", self_report=True)
    if len(state.bonds) == 1 and state.bonds[0].withdrawn:
        yield REPLACEMENT
    if len(state.bonds) == 2:
        yield Forfeit(1, INCIDENT, DEADLINE)


def _slot_view(bonds):
    return tuple(sorted((bond.slot, bond.key, bond.eff, bond.active_from, bond.exit_effective)
                        for bond in bonds if bond.slot is not None))


def check(pre, action, result):
    """Check exact projected state and events for every accepted edge."""
    post = result.state
    assert pre.owner_reserve + pre.reporter + pre.sink + sum(b.balance for b in pre.bonds) == PRINCIPAL
    assert post.owner_reserve + post.reporter + post.sink + sum(b.balance for b in post.bonds) == PRINCIPAL
    assert min(post.owner_reserve, post.reporter, post.sink) >= 0
    assert len({b.ck_addr for b in post.bonds}) == len(post.bonds)
    occupied = {b.slot for b in post.bonds if b.slot is not None}
    assert len(occupied) == sum(not b.withdrawn for b in post.bonds)
    for i, bond in enumerate(post.bonds):
        assert bond.bond_id == i and min(bond.eff, bond.pending) >= 0
        assert (bond.ready_at > 0) == (bond.pending > 0)
        assert key_bond(post, bond.ck_addr) == (True, i)
        if bond.withdrawn:
            assert bond.owner is None and bond.slot is None and bond.balance == bond.confirmed_at == 0
        else:
            assert bond.owner == OWNER and 0 <= bond.slot < SLOT_COUNT
            assert slot_holder(post, bond.slot) == (True, i)
        if bond.confirmed_at:
            assert bond.exit_effective <= post.active_snapshot
        if i < len(pre.bonds):
            old = pre.bonds[i]
            assert (bond.key, bond.ck_addr) == (old.key, old.ck_addr)
            assert not old.forfeited or bond.forfeited
            assert not old.withdrawn or bond == old
            assert bond.exit_effective <= old.exit_effective

    expected = pre
    events = ()
    if isinstance(action, Advance):
        expected = replace(pre, block=action.block, timestamp=action.timestamp)
    elif isinstance(action, Land):
        expected = replace(pre, c=pre.c + 1, active_snapshot=action.snapshot)
    elif isinstance(action, InvalidateNonce):
        expected = replace(pre, nonce=pre.nonce + 1)
        events = (("RecoveryNonceInvalidated", pre.nonce, post.nonce),)
    elif isinstance(action, Recover):
        expected = replace(pre, nonce=pre.nonce + 1, generation=pre.generation + 1)
    elif isinstance(action, Rollback):
        bonds = tuple(bond if bond.exit_effective <= action.trusted_snapshot
                      else replace(bond, confirmed_at=0) for bond in pre.bonds)
        expected = replace(pre, bonds=bonds, c=action.trusted_c,
                           active_snapshot=action.trusted_snapshot, nonce=pre.nonce + 1)
    elif isinstance(action, Register):
        old_slots = {bond.slot for bond in pre.bonds}
        new_bond = post.bonds[-1]
        assert new_bond.slot not in old_slots and set(range(new_bond.slot)) <= old_slots
        expected_bond = Bond(len(pre.bonds), action.key, action.ck_addr, OWNER, new_bond.slot,
                             action.amount, 0, 0, pre.block + ACTIVATION_DELAY)
        expected = replace(pre, bonds=pre.bonds + (expected_bond,),
                           owner_reserve=pre.owner_reserve - action.amount)
    else:
        old = pre.bonds[action.bond_id]
        assert not old.withdrawn
        if isinstance(action, TopUp):
            ready_at = pre.block + ACTIVATION_DELAY
            new = replace(old, pending=action.amount, ready_at=ready_at)
            expected = replace(pre, owner_reserve=pre.owner_reserve - action.amount)
            events = (("TopUpDeposited", old.bond_id, action.amount, ready_at),)
        elif isinstance(action, ActivateTopUp):
            new = replace(old, eff=old.balance, pending=0, ready_at=0)
            events = (("TopUpActivated", old.bond_id, old.pending),)
        elif isinstance(action, RequestExit):
            new = replace(old, exit_effective=EXIT_DELAY + max(pre.block, old.active_from))
        elif isinstance(action, ConfirmExit):
            new = replace(old, confirmed_at=old.confirmed_at or pre.block)
        elif isinstance(action, Withdraw):
            new = replace(old, owner=None, slot=None, eff=0, pending=0, ready_at=0,
                          confirmed_at=0, withdrawn=True)
            expected = replace(pre, owner_reserve=pre.owner_reserve + (old.balance if action.to_owner else 0),
                               reporter=pre.reporter + (0 if action.to_owner else old.balance))
        elif isinstance(action, Forfeit):
            assert not old.forfeited and old.balance > 0 and pre.timestamp <= action.valid_until
            assert action.owner and action.transfer_ok and pre.initialized
            paid = post.sink - pre.sink
            assert (paid - 1) * 10_000 < old.balance * pre.forfeit_bps <= paid * 10_000
            remaining = old.balance - paid
            pending = min(remaining, old.pending)
            new = replace(old, eff=remaining - pending, pending=pending,
                          ready_at=old.ready_at if pending else 0, forfeited=True,
                          exit_effective=min(old.exit_effective, pre.block))
            expected = replace(pre, sink=pre.sink + paid)
            events = (("Forfeited", action.bond_id, action.incident_id, old.balance, paid),)
        elif isinstance(action, Slash):
            received = (post.owner_reserve - pre.owner_reserve if action.self_report
                        else post.reporter - pre.reporter)
            assert received * 10_000 <= old.balance * pre.slash_bounty_bps < (received + 1) * 10_000
            new = replace(old, eff=0, pending=0, ready_at=0,
                          exit_effective=min(old.exit_effective, pre.block))
            expected = replace(pre, sink=pre.sink + old.balance - received,
                               owner_reserve=pre.owner_reserve + (received if action.self_report else 0),
                               reporter=pre.reporter + (0 if action.self_report else received))
        else:
            raise AssertionError(f"unchecked action {type(action).__name__}")
        expected = replace(expected, bonds=tuple(new if b.bond_id == action.bond_id else b for b in pre.bonds))

    if _slot_view(expected.bonds) != _slot_view(pre.bonds):
        expected = replace(expected, checkpoint_block=pre.block)
    assert post == expected, (action, post, expected)
    assert result.events == events, (action, result.events, events)


def witness_live(edge):
    return edge.action == PREAUTHORIZED and not edge.pre.bonds[0].withdrawn and edge.post.bonds[0].forfeited


def witness_withdrawn(edge):
    return (edge.action == PREAUTHORIZED and edge.reason == "withdrawn bond"
            and edge.pre.bonds[0].withdrawn and edge.pre.bonds[0].forfeited)


def witness_reused(edge):
    return (witness_withdrawn(edge) and slot_holder(edge.pre, 0) == (True, 1)
            and not edge.pre.bonds[1].forfeited)


def witness_at_deadline(edge):
    return witness_live(edge) and edge.pre.timestamp == DEADLINE


def witness_expired(edge):
    return edge.action == PREAUTHORIZED and edge.reason == "forfeiture expired"


def witness_funded_topup(edge):
    return witness_live(edge) and edge.pre.owner_reserve == 1 and edge.pre.bonds[0].pending == 9
