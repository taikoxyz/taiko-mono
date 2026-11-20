"""Finite switching-start projection for the exact f556 Etna documents.

Finality, Unzen proof acceptance, SignalService reads and writes, L2 state
authentication and external Etna proofs enter as symbolic premises. The branch
and timing fixtures are partial histories. Events are projected observations.
"""

from dataclasses import dataclass, replace
from types import MappingProxyType

from .explorer import Exploration, Refused, Transition, explore


UINT48_MAX = 2**48 - 1
BUILTIN_IMPLEMENTATION = "etna-implementation"
UNZEN_INBOX = "unzen-inbox"


@dataclass(frozen=True, slots=True)
class Checkpoint:
    height: int
    block_hash: str | None
    state_root: str | None


@dataclass(frozen=True, slots=True)
class UnzenCore:
    next_proposal_id: int
    last_finalized_id: int
    last_finalized_hash: str | None
    pending: tuple[Checkpoint, ...] | None = None
    fi_head: int = 0
    fi_tail: int = 0


@dataclass(frozen=True, slots=True)
class Header:
    height: int
    block_hash: str
    state_root: str
    timestamp: int


@dataclass(frozen=True, slots=True)
class Start:
    height: int
    block_hash: str
    state_root: str
    l1_block: int


@dataclass(frozen=True, slots=True)
class Slot285:
    height: int
    block_hash: str
    comet_hash: str | None
    fi_head: int
    parent_height: int
    generation: int


@dataclass(frozen=True, slots=True)
class GenerationOrigin:
    generation: int
    height: int
    l1_block: int
    timestamp: int


@dataclass(frozen=True, slots=True)
class FinalizedView:
    start: Start | None
    target: Slot285 | None
    fork_time: int
    unzen_last_hash: str | None


@dataclass(frozen=True, slots=True)
class State:
    branch: str
    l1_block: int
    timestamp: int
    initialized: bool
    unzen_inbox: str | None
    fork_time: int
    propose_cutoff: int
    fi_cutoff: int
    epoch_len: int
    genesis_cutoff: int
    unzen: UnzenCore
    unzen_checkpoints: tuple[Checkpoint, ...]
    start: Start | None = None
    last_checkpoint: tuple[int, str] | None = None
    slot285: tuple[Slot285, ...] = ()
    generation_origins: tuple[GenerationOrigin, ...] = ()
    etna_checkpoints: tuple[Checkpoint, ...] = ()
    fi_head: int = 0
    fi_tail: int = 0
    active_committee_snapshot: int = 0
    generation: int = 0
    recovery_nonce: int = 0
    finalized: FinalizedView | None = None
    cutoff_readable: bool = True
    core_readable: bool = True
    checkpoint_readable: bool = True


@dataclass(frozen=True, slots=True)
class NodeEvidence:
    target: Slot285
    effective_fork_time: int
    getter_address: str | None
    getter_fork_time: int | None
    header: Header | None = None
    proxy_implementation: str | None = None
    state_authenticated: bool = True


@dataclass(frozen=True, slots=True)
class GuestEvidence:
    header: Header
    proxy_implementation: str | None
    storage_proof_authenticated: bool = True


@dataclass(frozen=True, slots=True)
class SetOrigin:
    height: int


@dataclass(frozen=True, slots=True)
class ForwardCheckpoint:
    caller: str
    checkpoint: Checkpoint
    signal_accepts: bool = True


@dataclass(frozen=True, slots=True)
class SaveForcedInclusion:
    """Other ordinary Etna queue preconditions are admitted."""


@dataclass(frozen=True, slots=True)
class SaveUnzenForcedInclusion:
    """Other ordinary Unzen queue preconditions are admitted."""


@dataclass(frozen=True, slots=True)
class Propose:
    checkpoint: Checkpoint


@dataclass(frozen=True, slots=True)
class Prove:
    proof_authenticated: bool = True
    signal_accepts: bool = True


@dataclass(frozen=True, slots=True)
class Advance:
    l1_block: int
    timestamp: int


@dataclass(frozen=True, slots=True)
class Finalize:
    """An authenticated own L1 finalized view of the offered branch state."""

    authenticated: bool = True


@dataclass(frozen=True, slots=True)
class Reorg:
    candidate: State
    authenticated: bool = True


@dataclass(frozen=True, slots=True)
class Land:
    origin_height: int
    checkpoint: Checkpoint
    comet_hash: str
    fi_head: int
    active_committee_snapshot: int
    proof_authenticated: bool = True


@dataclass(frozen=True, slots=True)
class Recover:
    """Other ordinary recovery predicates are an admitted DAO-call premise."""

    authorized: bool = True


@dataclass(frozen=True, slots=True)
class RollbackFirstLanding:
    authorized: bool = True


@dataclass(frozen=True, slots=True)
class CheckNode:
    evidence: NodeEvidence


@dataclass(frozen=True, slots=True)
class CheckGuest:
    height: int
    evidence: GuestEvidence | None


Action = (SetOrigin | ForwardCheckpoint | SaveForcedInclusion | SaveUnzenForcedInclusion |
          Propose | Prove | Advance | Finalize | Reorg | Land | Recover |
          RollbackFirstLanding | CheckNode | CheckGuest)


def initial(branch: str = "A", *, timestamp: int = 87) -> State:
    """Unzen activation proposal 0 already finalized, with an existing checkpoint."""
    cp = Checkpoint(1, f"{branch}-h1", f"{branch}-r1")
    # Conditional FI margin: propose margin 12 + delay 2 + proposal gap 12.
    return State(
        branch, {87: 7, 88: 8, 99: 9, 100: 10}[timestamp], timestamp,
        True, UNZEN_INBOX, 100, 88, 74, 5, 6,
        UnzenCore(1, 0, cp.block_hash, fi_head=3, fi_tail=4), (cp,),
        active_committee_snapshot=6,
    )


def _slot(state: State, height: int) -> Slot285 | None:
    return next((record for record in state.slot285 if record.height == height), None)


def node_can_sign(state: State, evidence: NodeEvidence) -> bool:
    """Evaluate this observer's own finalized trust view under SYNC-9-5a."""
    view = state.finalized
    if view is None or view.start is None or view.target is None or not evidence.state_authenticated:
        return False
    start, target = view.start, view.target
    if (evidence.target.height, evidence.target.block_hash, evidence.target.comet_hash) != (
        target.height, target.block_hash, target.comet_hash
    ):
        return False
    if not (
        evidence.getter_address == BUILTIN_IMPLEMENTATION
        and evidence.getter_fork_time == view.fork_time == evidence.effective_fork_time
    ):
        return False
    if target.height != start.height:
        return True
    header = evidence.header
    return (
        header is not None and header.height == start.height
        and header.block_hash == start.block_hash == view.unzen_last_hash
        and header.state_root == start.state_root and header.timestamp < view.fork_time
        and evidence.proxy_implementation == BUILTIN_IMPLEMENTATION
    )


def guest_accepts_origin(state: State, origin_height: int, evidence: GuestEvidence | None) -> bool:
    """Check the special statement at S under PROOF-6.2-46a."""
    record = _slot(state, origin_height)
    if record is None or state.start is None:
        return False
    if origin_height != state.start.height:
        return True
    # A symbolic hash has no preimage binding of its own. This equality
    # represents that binding, without adding an on-chain guest read of slot 274.
    return (
        evidence is not None and evidence.storage_proof_authenticated
        and evidence.header.height == origin_height
        and evidence.header.block_hash == record.block_hash
        and evidence.header.state_root == state.start.state_root
        and evidence.header.timestamp < state.fork_time
        and evidence.proxy_implementation == BUILTIN_IMPLEMENTATION
    )


def _set_origin(state: State, call: SetOrigin) -> Transition[State]:
    if not state.initialized:
        raise Refused("not initialized")
    if state.start is not None:
        raise Refused("start already written")
    if not state.unzen_inbox or not state.fork_time:
        raise Refused("missing immutable")
    if type(call.height) is not int or not 0 < call.height <= UINT48_MAX:
        raise Refused("start height outside uint48")
    if state.timestamp < state.fork_time:
        raise Refused("fork not reached")
    if not state.cutoff_readable:
        raise Refused("proposal cutoff read failed")
    if not state.propose_cutoff or state.timestamp < state.propose_cutoff:
        raise Refused("proposal cutoff open")
    if not state.core_readable:
        raise Refused("Unzen core read failed")
    if state.unzen.next_proposal_id != state.unzen.last_finalized_id + 1:
        raise Refused("unfinalized proposals")
    if not state.checkpoint_readable:
        raise Refused("SignalService checkpoint read failed")
    cp = next((cp for cp in state.unzen_checkpoints if cp.height == call.height), None)
    if cp is None:
        raise Refused("missing checkpoint")
    if not cp.block_hash or cp.block_hash != state.unzen.last_finalized_hash:
        raise Refused("finalized hash mismatch")
    if not cp.state_root:
        raise Refused("missing state root")
    if not 0 <= state.l1_block <= UINT48_MAX:
        raise Refused("L1 start block outside uint48")

    start = Start(call.height, state.unzen.last_finalized_hash, cp.state_root, state.l1_block)
    record = Slot285(call.height, start.block_hash, None, 0, call.height, 0)
    origin = GenerationOrigin(0, call.height, state.l1_block, state.timestamp)
    return Transition(replace(
        state, start=start, last_checkpoint=(call.height, start.block_hash),
        slot285=(record,), generation_origins=(origin,), fi_head=0, fi_tail=0,
    ), (("start", start, record, origin),))


def _forward(state: State, call: ForwardCheckpoint) -> Transition[State]:
    if not state.unzen_inbox or call.caller != state.unzen_inbox:
        raise Refused("wrong forwarder")
    if state.start is not None:
        raise Refused("forwarding closed")
    if not call.signal_accepts:
        raise Refused("SignalService refused checkpoint")
    by_height = {cp.height: cp for cp in state.unzen_checkpoints}
    by_height[call.checkpoint.height] = call.checkpoint
    checkpoints = tuple(by_height[height] for height in sorted(by_height))
    return Transition(replace(state, unzen_checkpoints=checkpoints), (("forward", call.checkpoint),))


def _prove(state: State, call: Prove) -> Transition[State]:
    if not call.proof_authenticated or not state.unzen.pending:
        raise Refused("Unzen proof not accepted")
    cp, *remaining = state.unzen.pending
    forwarded = _forward(state, ForwardCheckpoint(state.unzen_inbox, cp, call.signal_accepts))
    finalized_id = state.unzen.last_finalized_id + 1
    return Transition(replace(
        forwarded.state, unzen=replace(
            state.unzen, last_finalized_id=finalized_id, last_finalized_hash=cp.block_hash,
            pending=tuple(remaining) or None,
        ),
    ), (*forwarded.events, ("unzen-proof", finalized_id, cp)))


def _land(state: State, call: Land) -> Transition[State]:
    if not call.proof_authenticated:
        raise Refused("external proof not accepted")
    if state.start is None:
        raise Refused("start not written")
    parent_height = state.last_checkpoint[0]
    if state.generation_origins[-1].height > parent_height:
        raise Refused("generation origin is above restored checkpoint")
    cp = call.checkpoint
    origin_height = state.generation_origins[-1].height
    origin = _slot(state, call.origin_height)
    if not (
        origin is not None and origin.block_hash
        and (origin.generation == state.generation or origin.height == origin_height)
        and origin_height <= call.origin_height <= parent_height < cp.height <= UINT48_MAX
        and cp.block_hash and cp.state_root and call.comet_hash
        and state.fi_head <= call.fi_head <= state.fi_tail
    ):
        raise Refused("landing frame mismatch")
    record = Slot285(cp.height, cp.block_hash, call.comet_hash, call.fi_head, parent_height, state.generation)
    return Transition(replace(
        state, last_checkpoint=(cp.height, cp.block_hash), slot285=(*state.slot285, record),
        etna_checkpoints=(*state.etna_checkpoints, cp), fi_head=call.fi_head,
        active_committee_snapshot=call.active_committee_snapshot,
    ), (("land", cp, record, call.active_committee_snapshot),))


def step(state: State, action: Action) -> Transition[State]:
    """Apply one atomic projected action, or refuse without producing an outcome."""
    match action:
        case SetOrigin():
            return _set_origin(state, action)
        case ForwardCheckpoint():
            return _forward(state, action)
        case Prove():
            return _prove(state, action)
        case Propose(cp):
            if state.propose_cutoff and state.timestamp >= state.propose_cutoff:
                raise Refused("proposal cutoff closed")
            core = state.unzen
            proposal_id = core.next_proposal_id
            return Transition(replace(
                state, unzen=replace(
                    core, next_proposal_id=proposal_id + 1, pending=(*(core.pending or ()), cp),
                ),
            ), (("unzen-proposal", proposal_id, cp),))
        case SaveUnzenForcedInclusion():
            if state.fi_cutoff and state.timestamp >= state.fi_cutoff:
                raise Refused("Unzen FI cutoff closed")
            tail = state.unzen.fi_tail
            return Transition(replace(state, unzen=replace(state.unzen, fi_tail=tail + 1)),
                              (("unzen-fi", tail),))
        case SaveForcedInclusion():
            if state.start is None:
                raise Refused("start not written")
            return Transition(replace(state, fi_tail=state.fi_tail + 1), (("fi", state.fi_tail),))
        case Advance(block, timestamp):
            if block <= state.l1_block or timestamp <= state.timestamp:
                raise Refused("clock must advance")
            return Transition(replace(state, l1_block=block, timestamp=timestamp))
        case Finalize(authenticated):
            if not authenticated:
                raise Refused("L1 finality not authenticated")
            target = state.slot285[-1] if state.slot285 else None
            view = FinalizedView(state.start, target, state.fork_time, state.unzen.last_finalized_hash)
            return Transition(replace(state, finalized=view), (("finalized", view),))
        case Reorg(candidate, authenticated):
            if not authenticated or candidate.branch == state.branch:
                raise Refused("replacement canonical branch not authenticated")
            if state.finalized is not None and state.finalized.start is not None:
                raise Refused("cannot orphan a finalized start")
            return Transition(candidate, (("reorg", state.branch, candidate.branch),))
        case Land():
            return _land(state, action)
        case Recover(authorized):
            if not authorized:
                raise Refused("recovery authorization not authenticated")
            if not state.initialized or state.start is None:
                raise Refused("start not written")
            if not 0 <= state.l1_block <= UINT48_MAX:
                raise Refused("L1 recovery block outside uint48")
            fixed = GenerationOrigin(state.generation + 1, state.last_checkpoint[0],
                                     state.l1_block, state.timestamp)
            return Transition(replace(
                state, generation=fixed.generation, recovery_nonce=state.recovery_nonce + 1,
                generation_origins=(*state.generation_origins, fixed),
            ), (("recover", fixed),))
        case RollbackFirstLanding(authorized):
            if not authorized:
                raise Refused("rollback authorization not authenticated")
            if not state.etna_checkpoints:
                raise Refused("no Etna landing to void")
            first = state.etna_checkpoints[0]
            start_record = state.slot285[0]
            return Transition(replace(
                state, last_checkpoint=(start_record.height, start_record.block_hash),
                etna_checkpoints=(), slot285=(start_record,), fi_head=start_record.fi_head,
                active_committee_snapshot=state.genesis_cutoff, recovery_nonce=state.recovery_nonce + 1,
            ), (("rollback-first", first, start_record),))
        case CheckNode(evidence):
            return Transition(state, (("node", node_can_sign(state, evidence)),))
        case CheckGuest(height, evidence):
            return Transition(state, (("guest", guest_accepts_origin(state, height, evidence)),))
    raise TypeError(f"unknown origin action: {action!r}")


def bank_actions(state: State):
    """Offer the complete finite bank; limits here are fixture bounds."""
    proposed = Checkpoint(2, f"{state.branch}-h2", f"{state.branch}-r2")
    historic = Checkpoint(0, f"{state.branch}-h0", f"{state.branch}-r0")
    yield SetOrigin(1)
    yield SetOrigin(2)
    yield ForwardCheckpoint(UNZEN_INBOX, historic)
    yield ForwardCheckpoint("unrelated", historic)
    yield ForwardCheckpoint(UNZEN_INBOX, historic, False)
    if state.unzen.next_proposal_id == 1 or state.timestamp >= state.propose_cutoff:
        yield Propose(proposed)
    if state.unzen.fi_tail == 4 or state.timestamp >= state.fi_cutoff:
        yield SaveUnzenForcedInclusion()
    yield Prove()
    yield Prove(False)
    yield Prove(signal_accepts=False)
    # The first proof may consume an FI queued at the start anchor. It cannot
    # consume an entry queued in the as-yet unfinalized landing block.
    if state.fi_tail == 0 and state.timestamp <= 100:
        yield SaveForcedInclusion()
    for block, timestamp in ((8, 88), (9, 99), (10, 100)):
        if state.timestamp < timestamp:
            yield Advance(block, timestamp)
    if state.branch == "A" and state.timestamp <= 100:
        replacement = initial("B", timestamp=100)
        yield Reorg(replacement)
        yield Reorg(replacement, False)
    if state.start is None:
        return

    start = state.start
    # S=1 is the initial checkpoint. S=2 can carry its proposal time 87.
    header = Header(start.height, start.block_hash, start.state_root, 75 if start.height == 1 else 87)
    latest = state.slot285[-1]
    at_start = latest.height == start.height
    # Later phases admit the external finalized anchor and then observation of
    # the landing, including the DAO whole-landing audit premise for recovery.
    if state.timestamp == 100:
        yield Advance(40, 460)
    if state.timestamp == 460 and not at_start:
        yield Advance(80, 940)
    if state.timestamp == (460 if at_start else 940):
        yield Finalize()
        yield Finalize(False)
    node = NodeEvidence(
        latest, 100, BUILTIN_IMPLEMENTATION, 100,
        header if at_start else None, BUILTIN_IMPLEMENTATION if at_start else None,
    )
    yield CheckNode(node)
    yield CheckNode(replace(node, effective_fork_time=101))
    yield CheckNode(replace(node, getter_address="signal-service-proxy"))
    if at_start:
        yield CheckNode(replace(node, proxy_implementation="pre-etna"))
        yield CheckNode(replace(node, header=replace(header, timestamp=100)))
    guest = GuestEvidence(header, BUILTIN_IMPLEMENTATION)
    yield CheckGuest(start.height, guest)
    yield CheckGuest(start.height, replace(guest, proxy_implementation="pre-etna"))
    yield CheckGuest(start.height, replace(guest, header=replace(header, timestamp=100)))
    yield CheckGuest(start.height, replace(guest, header=replace(header, state_root="inconsistent")))
    yield CheckGuest(start.height, replace(guest, storage_proof_authenticated=False))

    if state.finalized is not None:
        return
    first_landing = state.timestamp == 460 and state.recovery_nonce == 0
    voided_origin = state.timestamp == 940 and state.generation > 0
    if at_start and (first_landing or voided_origin):
        height = start.height + 1
        cp = Checkpoint(height, f"{state.branch}-etna-{height}", f"{state.branch}-root-{height}")
        landing = Land(
            start.height, cp, f"{state.branch}-comet-{height}", state.fi_tail, state.genesis_cutoff,
        )
        yield landing
        yield replace(landing, proof_authenticated=False)
    elif not at_start and state.timestamp == 940:
        if state.generation == 0:
            yield Recover()
            yield Recover(False)
        yield RollbackFirstLanding()
        yield RollbackFirstLanding(False)


def _expected(state: State, action: Action) -> Transition[State] | str:
    """Compute the complete independent frame and refusal reason for each offered edge."""
    match action:
        case SetOrigin(height):
            core = state.unzen
            cp = {item.height: item for item in state.unzen_checkpoints}.get(height)
            failures = (
                (not state.initialized, "not initialized"),
                (state.start is not None, "start already written"),
                (not (state.unzen_inbox and state.fork_time), "missing immutable"),
                (type(height) is not int or height not in range(1, 2**48), "start height outside uint48"),
                (state.timestamp < state.fork_time, "fork not reached"),
                (not state.cutoff_readable, "proposal cutoff read failed"),
                (not (0 < state.propose_cutoff <= state.timestamp), "proposal cutoff open"),
                (not state.core_readable, "Unzen core read failed"),
                (core.next_proposal_id - core.last_finalized_id != 1, "unfinalized proposals"),
                (not state.checkpoint_readable, "SignalService checkpoint read failed"),
                (cp is None, "missing checkpoint"),
                (cp is not None and (not core.last_finalized_hash or cp.block_hash != core.last_finalized_hash),
                 "finalized hash mismatch"),
                (cp is not None and not cp.state_root, "missing state root"),
                (state.l1_block not in range(2**48), "L1 start block outside uint48"),
            )
            for rejected, reason in failures:
                if rejected:
                    return reason
            start = Start(height, cp.block_hash, cp.state_root, state.l1_block)
            record = Slot285(height, cp.block_hash, None, 0, height, 0)
            fixed = GenerationOrigin(0, height, state.l1_block, state.timestamp)
            return Transition(replace(
                state, start=start, last_checkpoint=(height, cp.block_hash),
                slot285=(record,), generation_origins=(fixed,), fi_head=0, fi_tail=0,
            ), (("start", start, record, fixed),))
        case ForwardCheckpoint(caller, cp, accepts):
            if caller != state.unzen_inbox or not state.unzen_inbox:
                return "wrong forwarder"
            if state.start is not None:
                return "forwarding closed"
            if not accepts:
                return "SignalService refused checkpoint"
            checkpoints = tuple(
                sorted((cp, *(x for x in state.unzen_checkpoints if x.height != cp.height)),
                       key=lambda item: item.height)
            )
            return Transition(replace(state, unzen_checkpoints=checkpoints), (("forward", cp),))
        case Prove(authenticated, accepts):
            core = state.unzen
            if core.pending is None or not authenticated:
                return "Unzen proof not accepted"
            if state.start is not None:
                return "forwarding closed"
            if not accepts:
                return "SignalService refused checkpoint"
            cp = core.pending[0]
            checkpoints = tuple(
                sorted((cp, *(x for x in state.unzen_checkpoints if x.height != cp.height)),
                       key=lambda item: item.height)
            )
            finalized_id = core.last_finalized_id + 1
            return Transition(replace(
                state, unzen=replace(
                    core, last_finalized_id=finalized_id, last_finalized_hash=cp.block_hash,
                    pending=core.pending[1:] or None,
                ), unzen_checkpoints=checkpoints,
            ), (("forward", cp), ("unzen-proof", finalized_id, cp)))
        case Propose(cp):
            if state.timestamp != 87:
                return "proposal cutoff closed"
            return Transition(replace(
                state, unzen=replace(
                    state.unzen, next_proposal_id=2, pending=(cp,),
                ),
            ), (("unzen-proposal", 1, cp),))
        case SaveUnzenForcedInclusion():
            return "Unzen FI cutoff closed"
        case SaveForcedInclusion():
            if state.start is None:
                return "start not written"
            return Transition(replace(state, fi_tail=1), (("fi", 0),))
        case Advance(block, timestamp):
            return Transition(replace(state, l1_block=block, timestamp=timestamp))
        case Finalize(authenticated):
            if not authenticated:
                return "L1 finality not authenticated"
            target = {r.height: r for r in state.slot285}[state.last_checkpoint[0]]
            view = FinalizedView(state.start, target, 100, state.unzen.last_finalized_hash)
            return Transition(replace(state, finalized=view), (("finalized", view),))
        case Reorg(candidate, authenticated):
            if not authenticated:
                return "replacement canonical branch not authenticated"
            if state.finalized is not None and state.finalized.start is not None:
                return "cannot orphan a finalized start"
            return Transition(candidate, (("reorg", "A", "B"),))
        case Land(origin, cp, comet, head, _, authenticated):
            if not authenticated:
                return "external proof not accepted"
            if state.generation_origins[-1].height > state.start.height:
                return "generation origin is above restored checkpoint"
            record = Slot285(cp.height, cp.block_hash, comet, head, origin, state.generation)
            return Transition(replace(
                state, last_checkpoint=(cp.height, cp.block_hash), slot285=(*state.slot285, record),
                etna_checkpoints=(cp,), fi_head=head, active_committee_snapshot=6,
            ), (("land", cp, record, 6),))
        case Recover(authorized):
            if not authorized:
                return "recovery authorization not authenticated"
            fixed = GenerationOrigin(1, state.last_checkpoint[0], state.l1_block, state.timestamp)
            return Transition(replace(
                state, generation=1, recovery_nonce=state.recovery_nonce + 1,
                generation_origins=(*state.generation_origins, fixed),
            ), (("recover", fixed),))
        case RollbackFirstLanding(authorized):
            if not authorized:
                return "rollback authorization not authenticated"
            return Transition(replace(
                state, last_checkpoint=(state.start.height, state.start.block_hash),
                etna_checkpoints=(), slot285=state.slot285[:1], fi_head=0,
                active_committee_snapshot=6, recovery_nonce=state.recovery_nonce + 1,
            ), (("rollback-first", state.etna_checkpoints[0], state.slot285[0]),))
        case CheckNode(evidence):
            view = state.finalized
            valid = (
                view is not None and view.target == evidence.target
                and evidence.effective_fork_time == 100
                and evidence.getter_address == "etna-implementation"
                and (evidence.target.height > state.start.height
                     or (evidence.header.timestamp < 100
                         and evidence.proxy_implementation == "etna-implementation"))
            )
            return Transition(state, (("node", valid),))
        case CheckGuest(_, evidence):
            valid = (
                evidence.storage_proof_authenticated and evidence.header.timestamp < 100
                and evidence.header.state_root == state.start.state_root
                and evidence.proxy_implementation == "etna-implementation"
            )
            return Transition(state, (("guest", valid),))
    raise TypeError(f"unknown bank action: {action!r}")


def _observe_refusal(state: State, action: Action) -> Transition[State]:
    before = repr(state)
    try:
        return step(state, action)
    except Refused as error:
        expected = _expected(state, action)
        if expected != str(error) or repr(state) != before:
            raise AssertionError(f"wrong refusal on {action!r}: {error}; expected {expected!r}") from error
        raise


def _check_accepted(state: State, action: Action, actual: Transition[State]) -> None:
    expected = _expected(state, action)
    if actual != expected:
        raise AssertionError(f"wrong accepted edge on {action!r}; expected {expected!r}; got {actual!r}")


@dataclass(frozen=True, slots=True)
class Witness:
    actions: tuple[str, ...]
    branch: str
    timestamp: int
    outcome: str


@dataclass(frozen=True, slots=True)
class Assessment:
    status: str
    exploration: Exploration[State, Action] | None
    witnesses: MappingProxyType
    error: str | None = None


REQUIRED_WITNESSES = (
    "proposal-at-cutoff", "unzen-fi-before-proposal-cutoff", "before-fork", "latch-activation",
    "latch-pending-refused", "same-block-proof-latch", "wrong-height-missing",
    "wrong-height-mismatch", "duplicate-latch", "forward-before", "forward-after",
    "fi-before", "fi-after", "node-before-finality", "node-finalized-at-start",
    "node-bad-implementation", "guest-bad-implementation", "guest-bad-timestamp",
    "local-override-node", "valid-guest-with-local-override", "external-land-before-own-finality",
    "pruned-node", "pruned-local-override", "first-landing-rollback", "rollback-after-recovery",
    "reorg-canonical-latch",
)


def _witnesses(graph: Exploration[State, Action]) -> dict[str, Witness]:
    found = {}

    def record(label, edge, outcome, following=()):
        path = (*graph.path_to(edge.pre), edge, *following)
        action_names = tuple(type(item.action).__name__ for item in path)
        prior = found.get(label)
        if prior is None or len(action_names) < len(prior.actions):
            found[label] = Witness(action_names, edge.pre.branch, edge.pre.timestamp, outcome)

    latches = {e.pre: e for e in graph.accepted if isinstance(e.action, SetOrigin)}
    late_proofs = {e.post: e for e in graph.accepted
                   if isinstance(e.action, Prove) and e.pre.timestamp == 100}
    local_overrides = {e.pre: e for e in graph.accepted
                       if isinstance(e.action, CheckNode) and e.action.evidence.effective_fork_time == 101
                       and e.events == (("node", False),)}
    for edge in graph.accepted:
        pre, action, post = edge.pre, edge.action, edge.post
        match action:
            case SetOrigin(height):
                if height == 1 and pre.branch == "A":
                    record("latch-activation", edge, "accepted")
                if height == 2 and pre in late_proofs:
                    record("same-block-proof-latch", late_proofs[pre], "accepted", (edge,))
            case ForwardCheckpoint():
                record("forward-before", edge, "accepted")
            case SaveForcedInclusion():
                record("fi-after", edge, "accepted")
            case CheckNode(evidence):
                valid = edge.events == (("node", True),)
                at_start = evidence.target.height == pre.start.height
                if valid:
                    record("node-finalized-at-start" if at_start else "pruned-node", edge, "true")
                elif pre.finalized is None and evidence.effective_fork_time == 100:
                    record("node-before-finality", edge, "false")
                elif pre.finalized is not None and evidence.target == pre.finalized.target:
                    if evidence.effective_fork_time == 101:
                        record("local-override-node" if at_start else "pruned-local-override", edge, "false")
                    if evidence.proxy_implementation == "pre-etna":
                        record("node-bad-implementation", edge, "false")
            case CheckGuest(_, evidence):
                valid = edge.events == (("guest", True),)
                if (valid and pre in local_overrides and pre.finalized is not None
                        and pre.finalized.target == pre.slot285[0] == pre.slot285[-1]):
                    record("valid-guest-with-local-override", local_overrides[pre], "node false, guest true", (edge,))
                elif not valid and evidence.proxy_implementation == "pre-etna":
                    record("guest-bad-implementation", edge, "false")
                elif not valid and evidence.header.timestamp == 100:
                    record("guest-bad-timestamp", edge, "false")
            case Land():
                if pre.finalized is None:
                    record("external-land-before-own-finality", edge, "accepted")
            case RollbackFirstLanding():
                record("first-landing-rollback", edge, "accepted")
                if pre.generation == 1:
                    record("rollback-after-recovery", edge, "accepted")
            case Reorg():
                if (pre.start is not None and pre.start.height == 2 and pre.fi_tail
                        and post in latches):
                    record("reorg-canonical-latch", edge, "accepted", (latches[post],))

    reasons = {
        (Propose, "proposal cutoff closed"): "proposal-at-cutoff",
        (SaveUnzenForcedInclusion, "Unzen FI cutoff closed"): "unzen-fi-before-proposal-cutoff",
        (SetOrigin, "fork not reached"): "before-fork",
        (SetOrigin, "unfinalized proposals"): "latch-pending-refused",
        (SetOrigin, "missing checkpoint"): "wrong-height-missing",
        (SetOrigin, "finalized hash mismatch"): "wrong-height-mismatch",
        (SetOrigin, "start already written"): "duplicate-latch",
        (ForwardCheckpoint, "forwarding closed"): "forward-after",
        (SaveForcedInclusion, "start not written"): "fi-before",
    }
    for edge in graph.refused:
        label = reasons.get((type(edge.action), edge.reason))
        if label is None:
            continue
        if label == "proposal-at-cutoff" and edge.pre.timestamp != 88:
            continue
        if label == "unzen-fi-before-proposal-cutoff" and edge.pre.timestamp != 87:
            continue
        record(label, edge, edge.reason)
    return found


def assess_bank(*, max_states: int = 25_000) -> Assessment:
    """Exhaust the bank and require an observed witness for each selected interaction."""
    try:
        graph = explore(initial(), bank_actions, _observe_refusal, _check_accepted, max_states=max_states)
        witnesses = _witnesses(graph)
        missing = set(REQUIRED_WITNESSES) - witnesses.keys()
        if missing:
            return Assessment("INCONCLUSIVE", graph, MappingProxyType(witnesses),
                              f"missing witnesses: {sorted(missing)}")
        return Assessment("EXHAUSTED", graph, MappingProxyType(witnesses))
    except Exception as error:
        return Assessment("INCONCLUSIVE", None, MappingProxyType({}), f"{type(error).__name__}: {error}")
