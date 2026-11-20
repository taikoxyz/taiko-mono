"""Finite two-chain projection of SWITCH section 7 and START-10-5d.

Proof validity, checkpoint availability, and rehearsal inputs are premises.
Block times are logical guard fixtures. Receipt hashes and events are symbolic.
"""

from collections.abc import Mapping
from dataclasses import dataclass, replace
from hashlib import sha256
from types import MappingProxyType

from .explorer import Edge, Exploration, Refused, RefusedEdge, Transition, explore


@dataclass(frozen=True, slots=True)
class L1Config:
    fork_time: int
    fi_cutoff: int
    proposal_cutoff: int
    unzen_implementation: str
    inbox_implementation: str
    guest_images: tuple[str, ...]
    checkpoint_store: str
    unrelated: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Installation:
    address: str
    fork_time: int
    version: int = 1
    syncer: str = "anchor"


@dataclass(frozen=True, slots=True)
class Schedule:
    l1: L1Config
    l2: Installation
    release_hashes: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Route:
    l1_chain: int = 1
    l2_chain: int = 2
    dao: str = "dao"
    l1_bridge: str = "l1-bridge"
    controller: str = "controller"
    l1_signal_service: str = "l1-signal"
    l2_signal_service: str = "l2-signal"
    inbox: str = "etna-inbox"


@dataclass(frozen=True, slots=True)
class Plan:
    operation_id: str
    old: Schedule
    new: Schedule
    route: Route
    predecessors: tuple[str, ...]
    a: int = 10
    e: int = 20
    b: int = 30
    c: int = 40
    rollout_budget: int = 70
    proposal_lead: int = 80
    fi_margin: int = 60
    proposal_margin: int = 12
    gas_limit: int = 100_000


@dataclass(frozen=True, slots=True)
class Message:
    message_id: int
    source_chain: int
    target_chain: int
    source: str
    target: str
    execution_id: int
    gas_limit: int
    deadline: int
    predecessors: tuple[str, ...]
    installation: Installation
    plan: Plan | None


@dataclass(frozen=True, slots=True)
class Receipt:
    message: Message
    message_hash: str
    sent_at: int


@dataclass(frozen=True, slots=True)
class Delivery:
    receipt: Receipt
    status: str = "NEW"


@dataclass(frozen=True, slots=True)
class Operation:
    plan: Plan
    prepared_at: int
    delivery: Delivery | None = None
    abandoned: bool = False
    cancelled_at: int | None = None
    committed: bool = False


@dataclass(frozen=True, slots=True)
class Acknowledgment:
    operation_id: str
    old: Schedule
    new: Schedule
    l1_chain: int
    l2_chain: int
    target: str


@dataclass(frozen=True, slots=True)
class Emission:
    source: str
    acknowledgment: Acknowledgment


@dataclass(frozen=True, slots=True)
class L2Block:
    timestamp: int
    installation: Installation
    # Logs belong to their execution block. SignalService slots survive in descendants.
    acknowledgments: tuple[Emission, ...] = ()
    stored_signals: tuple[Emission, ...] = ()


@dataclass(frozen=True, slots=True)
class Checkpoint:
    block: L2Block
    proven_at: int


@dataclass(frozen=True, slots=True)
class RelayProof:
    checkpoint_l1_timestamp: int
    signal_service: str
    active_implementation: str
    source_chain: int
    source: str
    message_hash: str
    usable: bool = True
    authenticated: bool = True
    canonical: bool = True


@dataclass(frozen=True, slots=True)
class FinalizedProof:
    checkpoint: Checkpoint
    finalized_at: int
    authenticated: bool = True
    canonical: bool = True
    finalized: bool = True


@dataclass(frozen=True, slots=True)
class AckProof:
    finality: FinalizedProof
    acknowledgment: Acknowledgment
    source_chain: int
    source: str
    signal_service: str


@dataclass(frozen=True, slots=True)
class InstalledConfigProof:
    config: L1Config
    included_at: int
    finalized_at: int
    authenticated: bool = True
    canonical: bool = True
    finalized: bool = True


@dataclass(frozen=True, slots=True)
class PhaseAProof:
    operation_id: str
    observed_at: int
    finalized_at: int
    cancelled: bool = False
    authenticated: bool = True
    canonical: bool = True
    finalized: bool = True


@dataclass(frozen=True, slots=True)
class State:
    l1_timestamp: int
    l1: L1Config
    selected: Schedule
    l2: L2Block
    route: Route
    checkpoints: tuple[Checkpoint, ...]
    operations: tuple[Operation, ...] = ()
    earlier_l2_blocks: tuple[L2Block, ...] = ()
    initial_delivery: Delivery | None = None
    next_message_id: int = 7
    start_written: bool = False
    committed_at: int | None = None


@dataclass(frozen=True, slots=True)
class AdvanceL1:
    timestamp: int


@dataclass(frozen=True, slots=True)
class AdvanceL2:
    timestamp: int


@dataclass(frozen=True, slots=True)
class Prepare:
    plan: Plan
    intervals_fit: bool = True


@dataclass(frozen=True, slots=True)
class Abandon:
    operation_id: str


@dataclass(frozen=True, slots=True)
class Cancel:
    operation_id: str
    authorized: bool = True


@dataclass(frozen=True, slots=True)
class Send:
    operation_id: str
    authorized: bool = True


@dataclass(frozen=True, slots=True)
class Invocation:
    gas_ok: bool = True
    observed_address: str | None = None
    observed_fork_time: int | None = None
    signal_ok: bool = True


@dataclass(frozen=True, slots=True)
class Process:
    receipt: Receipt
    proof: RelayProof
    invocation: Invocation = Invocation()
    caller: str = "relayer"


@dataclass(frozen=True, slots=True)
class Retry:
    receipt: Receipt
    invocation: Invocation = Invocation()
    last_attempt: bool = False
    caller: str = "relayer"


@dataclass(frozen=True, slots=True)
class ProveUnzen:
    block: L2Block
    admitted: bool = True
    caller: str = "unrelated-prover"


@dataclass(frozen=True, slots=True)
class Commit:
    operation_id: str
    proof: AckProof
    authorized: bool = True
    installed: L1Config | None = None


@dataclass(frozen=True, slots=True)
class CheckReadiness:
    proof: FinalizedProof | None
    schedule: Schedule
    phase_a_proofs: tuple[PhaseAProof, ...] = ()
    other_checks: bool = True
    config_proof: InstalledConfigProof | None = None


Action = (AdvanceL1 | AdvanceL2 | Prepare | Abandon | Cancel | Send | Process | Retry
          | ProveUnzen | Commit | CheckReadiness)
PRE_ETNA = Installation("signal-pre-etna", 0)


def _schedule(fork_time: int, revision: int) -> Schedule:
    return Schedule(
        L1Config(fork_time, fork_time - 60, fork_time - 12, f"unzen-v{revision}",
                 f"inbox-v{revision}", (f"guest-v{revision}",), "etna-inbox",
                 ("bond-config", "forced-inclusion-delay", "registry")),
        Installation(f"signal-v{revision}", fork_time), (f"client-release-v{revision}",),
    )


def default_plan(*, operation_id: str = "first", e: int = 20,
                 new_fork_time: int = 200) -> Plan:
    """One scalar protocol profile, with named deadline and new-lead vectors."""
    old = _schedule(100, 1)
    return Plan(operation_id, old, _schedule(new_fork_time, 2), Route(),
                (PRE_ETNA.address, old.l2.address), e=e)


def _receipt(message: Message, sent_at: int) -> Receipt:
    # Bind the modeled payload, including the Bridge-assigned ID. No ABI encoding.
    return Receipt(message, sha256(repr(message).encode()).hexdigest(), sent_at)


def initial(*, initial_pending: bool = False) -> State:
    plan = default_plan()
    route = plan.route
    initial_delivery = None
    l2 = plan.old.l2
    if initial_pending:
        message = Message(6, route.l1_chain, route.l2_chain, route.dao, route.controller,
                          0, plan.gas_limit, plan.old.l1.proposal_cutoff,
                          (PRE_ETNA.address,), plan.old.l2, None)
        initial_delivery = Delivery(_receipt(message, 0))
        l2 = PRE_ETNA
    # A preexisting checkpoint survived installation of the initial L1 schedule.
    return State(2, plan.old.l1, plan.old, L2Block(1, l2), route,
                 (Checkpoint(L2Block(0, PRE_ETNA), 1),), initial_delivery=initial_delivery)


def _operation(state: State, operation_id: str) -> Operation:
    for operation in state.operations:
        if operation.plan.operation_id == operation_id:
            return operation
    raise Refused("unknown operation ID")


def _update(state: State, changed: Operation) -> State:
    return replace(state, operations=tuple(
        changed if entry.plan.operation_id == changed.plan.operation_id else entry
        for entry in state.operations
    ))


def _ack(plan: Plan, *, operation_id: str) -> Acknowledgment:
    return Acknowledgment(operation_id, plan.old, plan.new, plan.route.l1_chain,
                          plan.route.l2_chain, plan.new.l2.address)


def relay_proof(state: State, receipt: Receipt) -> RelayProof:
    """Offer the selected usable-checkpoint premise for this exact receipt."""
    return RelayProof(
        receipt.sent_at, state.route.l2_signal_service, state.l2.installation.address,
        state.route.l1_chain, state.route.l1_bridge, receipt.message_hash,
    )


def ack_proof(state: State, finality: FinalizedProof, *, operation_id: str | None = None) -> AckProof:
    """Select the requested stored signal, or the only signal in the fixture."""
    (emission,) = tuple(signal for signal in finality.checkpoint.block.stored_signals
                        if operation_id is None or signal.acknowledgment.operation_id == operation_id)
    return AckProof(finality, emission.acknowledgment, state.route.l2_chain,
                    emission.source, state.route.l1_signal_service)


def _well_formed(plan: Plan, route: Route) -> bool:
    old, new = plan.old, plan.new
    predecessors = {PRE_ETNA.address, old.l2.address}
    return (
        bool(plan.operation_id) and plan.route == route and plan.gas_limit > 0
        and route.l1_chain > 0 and route.l2_chain > 0 and route.l1_chain != route.l2_chain
        and plan.c == min(old.l1.fi_cutoff, old.l1.proposal_cutoff)
        and plan.rollout_budget > 0
        and plan.b == min(plan.c, old.l1.fork_time - plan.rollout_budget)
        and 0 <= plan.a < plan.e < plan.b <= plan.c
        and plan.proposal_lead > plan.fi_margin > plan.proposal_margin >= 12
        and old.l1.fork_time < new.l1.fork_time
        and len(set(plan.predecessors)) == len(plan.predecessors)
        and bool(plan.predecessors) and set(plan.predecessors) <= predecessors
        and new.l2.address not in predecessors
        and new.l2.version == old.l2.version and new.l2.syncer == old.l2.syncer
        and old.l1.unrelated == new.l1.unrelated
        and all(
            schedule.l1.fi_cutoff == schedule.l1.fork_time - plan.fi_margin
            and schedule.l1.proposal_cutoff == schedule.l1.fork_time - plan.proposal_margin
            and schedule.l1.checkpoint_store == route.inbox
            and schedule.l1.fork_time == schedule.l2.fork_time
            and bool(schedule.l2.address and schedule.l1.unzen_implementation
                     and schedule.l1.inbox_implementation)
            and bool(schedule.l1.guest_images and schedule.release_hashes)
            for schedule in (old, new)
        )
    )


def _prepare(state: State, action: Prepare) -> Transition[State]:
    plan = action.plan
    if any(entry.plan.operation_id == plan.operation_id for entry in state.operations):
        raise Refused("operation ID already used")
    if not _well_formed(plan, state.route) or plan.old != state.selected or plan.old.l1 != state.l1:
        raise Refused("invalid replacement plan")
    if not action.intervals_fit:
        raise Refused("rehearsal intervals do not fit")
    # Compliant preparation serializes operations; abandonment cannot clear a split.
    if (any(not (entry.abandoned or entry.committed or entry.cancelled_at is not None)
            for entry in state.operations)
            or state.l2.installation not in (PRE_ETNA, state.selected.l2)):
        raise Refused("governance upgrade still pending")
    entry = Operation(plan, state.l1_timestamp)
    return Transition(replace(state, operations=(*state.operations, entry)), (("prepare", plan),))


def _dao_checks(state: State, operation: Operation, authorized: bool) -> None:
    if not authorized:
        raise Refused("DAO authorization")
    if state.start_written:
        raise Refused("start written")
    if state.l1 != operation.plan.old.l1:
        raise Refused("unexpected old L1 configuration")


def _send(state: State, action: Send) -> Transition[State]:
    entry = _operation(state, action.operation_id)
    plan = entry.plan
    _dao_checks(state, entry, action.authorized)
    if entry.delivery is not None:
        raise Refused("phase A already sent")
    if entry.cancelled_at is not None:
        raise Refused("phase A cancelled")
    if state.l1_timestamp >= plan.a:
        raise Refused("phase A deadline")
    route = plan.route
    message = Message(state.next_message_id, route.l1_chain, route.l2_chain, route.dao,
                      route.controller, 0, plan.gas_limit, plan.e, plan.predecessors,
                      plan.new.l2, plan)
    sent = _receipt(message, state.l1_timestamp)
    updated = _update(state, replace(entry, delivery=Delivery(sent)))
    return Transition(replace(updated, next_message_id=state.next_message_id + 1),
                      (("message-sent", sent),))


def _delivery(state: State, receipt: Receipt) -> tuple[Operation | None, Delivery]:
    if state.initial_delivery is not None and state.initial_delivery.receipt == receipt:
        return None, state.initial_delivery
    for entry in state.operations:
        if entry.delivery is not None and entry.delivery.receipt == receipt:
            return entry, entry.delivery
    raise Refused("exact sent message required")


def _invocation_failure(block: L2Block, message: Message, call: Invocation) -> str | None:
    if not call.gas_ok:
        return "invocation gas"
    if block.timestamp >= message.deadline:
        return "L2 deadline"
    if block.installation.address not in message.predecessors:
        return "L2 predecessor"
    if ((call.observed_address is not None and call.observed_address != message.installation.address)
            or (call.observed_fork_time is not None
                and call.observed_fork_time != message.installation.fork_time)):
        return "L2 postcondition"
    if message.plan is not None and not call.signal_ok:
        return "ack emission failed"
    return None


def _relay(state: State, action: Process | Retry) -> Transition[State]:
    entry, delivery = _delivery(state, action.receipt)
    message = delivery.receipt.message
    expected_status = "NEW" if isinstance(action, Process) else "RETRIABLE"
    if delivery.status != expected_status:
        raise Refused(f"{expected_status} status required")
    if isinstance(action, Process):
        proof = action.proof
        valid_window = (delivery.receipt.sent_at <= proof.checkpoint_l1_timestamp
                        <= state.l1_timestamp)
        if (not (proof.usable and proof.canonical and proof.authenticated and valid_window)
                or proof.signal_service != state.route.l2_signal_service
                or proof.active_implementation != state.l2.installation.address
                or proof.source_chain != message.source_chain
                or proof.source != state.route.l1_bridge
                or proof.message_hash != delivery.receipt.message_hash):
            raise Refused("unusable or inexact relay proof")
    elif action.last_attempt:
        # The prescribed workflow uses retryMessage(message, false).
        raise Refused("retry mode outside replacement workflow")

    if any(checkpoint.block.timestamp == state.l2.timestamp for checkpoint in state.checkpoints):
        raise Refused("L2 block already proven")
    failure = _invocation_failure(state.l2, message, action.invocation)
    if failure is not None and isinstance(action, Retry):
        raise Refused(f"retry failed: {failure}")
    status = "RETRIABLE" if failure is not None else "DONE"
    updated = replace(delivery, status=status)
    post = (replace(state, initial_delivery=updated) if entry is None
            else _update(state, replace(entry, delivery=updated)))
    events = (("bridge", delivery.receipt, status, failure),)
    if failure is not None:
        return Transition(post, events)
    installed = replace(state.l2, installation=message.installation)
    events += (("l2-install", installed.timestamp, message.installation),)
    if message.plan is not None:
        emission = Emission(message.target, _ack(message.plan, operation_id=message.plan.operation_id))
        installed = replace(installed, acknowledgments=(*installed.acknowledgments, emission),
                            stored_signals=(*installed.stored_signals, emission))
        events += (("ack", installed.timestamp, emission),)
    return Transition(replace(post, l2=installed), events)


def _prove(state: State, action: ProveUnzen) -> Transition[State]:
    block = action.block
    if (not action.admitted or block not in (state.l2, *state.earlier_l2_blocks)
            or not state.checkpoints[-1].block.timestamp < block.timestamp < state.l1.fork_time):
        raise Refused("Unzen checkpoint proof refused")
    checkpoint = Checkpoint(block, state.l1_timestamp)
    return Transition(replace(state, checkpoints=(*state.checkpoints, checkpoint)),
                      (("checkpoint", checkpoint),))


def _finalized(state: State, proof: FinalizedProof | None) -> bool:
    return (proof is not None and proof.authenticated and proof.canonical and proof.finalized
            and proof.checkpoint in state.checkpoints
            and proof.checkpoint.proven_at < proof.finalized_at <= state.l1_timestamp)


def _commit(state: State, action: Commit) -> Transition[State]:
    entry = _operation(state, action.operation_id)
    plan = entry.plan
    _dao_checks(state, entry, action.authorized)
    if state.l1_timestamp >= plan.b:
        raise Refused("phase B deadline")
    if plan.new.l1.fork_time - state.l1_timestamp < plan.proposal_lead:
        raise Refused("insufficient new proposal lead")
    proof = action.proof
    if not _finalized(state, proof.finality):
        raise Refused("matching finalized Unzen proof required")
    route = plan.route
    if (proof.source_chain, proof.source, proof.signal_service) != (
            route.l2_chain, route.controller, route.l1_signal_service):
        raise Refused("wrong ack route")
    acknowledgment = proof.acknowledgment
    if acknowledgment.operation_id != plan.operation_id:
        raise Refused("wrong ack operation")
    if acknowledgment != _ack(plan, operation_id=acknowledgment.operation_id):
        raise Refused("wrong ack context")
    # The L1 SignalService authenticates the stored signal. Release readiness
    # separately checks the installation proved by the checkpoint.
    block = proof.finality.checkpoint.block
    if Emission(proof.source, acknowledgment) not in block.stored_signals:
        raise Refused("ack signal absent from finalized checkpoint")

    if action.installed is not None and action.installed != plan.new.l1:
        raise Refused("L1 postcondition mismatch")
    post = _update(state, replace(entry, committed=True))
    return Transition(
        replace(post, l1=plan.new.l1, selected=plan.new, committed_at=state.l1_timestamp),
        (("phase-b", plan.operation_id, plan.new.l1),),
    )


def _phase_a_extinguished(state: State, entry: Operation, proof: PhaseAProof) -> bool:
    if (proof.operation_id != entry.plan.operation_id
            or not (proof.authenticated and proof.canonical and proof.finalized)
            or not entry.prepared_at <= proof.observed_at < proof.finalized_at <= state.l1_timestamp):
        return False
    if proof.cancelled:
        return entry.cancelled_at is not None and entry.cancelled_at <= proof.observed_at
    return proof.observed_at >= entry.plan.a


def _readiness(state: State, action: CheckReadiness) -> tuple[str, str]:
    # Other go/no-go and local trust checks remain prerequisites outside this projection.
    if not action.other_checks or action.schedule != state.selected or action.schedule.l1 != state.l1:
        return "CLOSED", "schedule or other switch checks"
    config = action.config_proof
    if state.committed_at is not None and not (
            config is not None and config.authenticated and config.canonical and config.finalized
            and config.config == state.l1 and config.included_at == state.committed_at
            and config.included_at < config.finalized_at <= state.l1_timestamp):
        return "CLOSED", "phase B not finalized in local view"
    if not _finalized(state, action.proof):
        return "CLOSED", "missing finalized Unzen proof"
    block = action.proof.checkpoint.block
    if block.installation != action.schedule.l2:
        return "CLOSED", "proven L2 implementation or fork mismatch"
    applicable = tuple(entry for entry in state.operations if entry.plan.old == action.schedule)
    if any(entry.delivery is not None and block.timestamp < entry.plan.e for entry in applicable):
        return "CLOSED", "sent L2 deadline still open at proven block"
    if any(entry.delivery is None and not any(
            _phase_a_extinguished(state, entry, proof) for proof in action.phase_a_proofs
    ) for entry in applicable):
        return "CLOSED", "unsent phase A may execute"
    return "OPEN", "replacement checks satisfied"


def step(state: State, action: Action) -> Transition[State]:
    if isinstance(action, AdvanceL1):
        if action.timestamp <= state.l1_timestamp:
            raise Refused("L1 clock must advance")
        return Transition(replace(state, l1_timestamp=action.timestamp))
    if isinstance(action, AdvanceL2):
        if action.timestamp <= state.l2.timestamp:
            raise Refused("L2 clock must advance")
        descendant = replace(state.l2, timestamp=action.timestamp, acknowledgments=())
        return Transition(replace(state, l2=descendant,
                                  earlier_l2_blocks=(*state.earlier_l2_blocks, state.l2)))
    if isinstance(action, Prepare):
        return _prepare(state, action)
    if isinstance(action, Abandon):
        entry = _operation(state, action.operation_id)
        if entry.committed:
            raise Refused("operation committed")
        return Transition(_update(state, replace(entry, abandoned=True)), (("abandon", action.operation_id),))
    if isinstance(action, Cancel):
        entry = _operation(state, action.operation_id)
        if not action.authorized or entry.delivery is not None or entry.cancelled_at is not None:
            raise Refused("phase A cannot be cancelled")
        return Transition(_update(state, replace(entry, cancelled_at=state.l1_timestamp)),
                          (("cancel", action.operation_id, state.l1_timestamp),))
    if isinstance(action, Send):
        return _send(state, action)
    if isinstance(action, (Process, Retry)):
        return _relay(state, action)
    if isinstance(action, ProveUnzen):
        return _prove(state, action)
    if isinstance(action, Commit):
        return _commit(state, action)
    if isinstance(action, CheckReadiness):
        return Transition(state, (("readiness", *_readiness(state, action)),))
    raise TypeError(f"unsupported replacement action: {action!r}")


# Each bank uses the same selected L1 slots. L2 can take any increasing subsequence
# of its offered timestamps. The bank holds L1 at 21 for the L2 invocation block(s)
# and allows proving only in the later L1 slot 26 before evidence is usable at 29.
L1_TIMES = (2, 9, 10, 21, 26, 29, 30, 31, 45)
BANKS = MappingProxyType({
    "initial-installed": (False, (19, 20)),
    "initial-pending": (True, (19, 20)),
    "two-abandonable": (False, (19, 20, 24, 25)),
})


def actions(state: State, *, bank: str = "initial-installed"):
    """Offer the complete declared bank for this profile and state."""
    _, l2_times = BANKS[bank]
    multiple = bank == "two-abandonable"
    plans = (default_plan(), default_plan(operation_id="second", e=25)) if multiple else (default_plan(),)
    now = state.l1_timestamp
    if now < L1_TIMES[-1]:
        yield AdvanceL1(L1_TIMES[L1_TIMES.index(now) + 1])

    if now == 2:
        if not state.operations:
            yield Prepare(plans[0])
    if now in (9, 10):
        for entry in state.operations:
            yield Send(entry.plan.operation_id)
            if now == 9:
                if not entry.abandoned and not entry.committed:
                    yield Abandon(entry.plan.operation_id)
                if entry.delivery is None and entry.cancelled_at is None:
                    yield Cancel(entry.plan.operation_id)
        if now == 9 and multiple and len(state.operations) == 1:
            yield Prepare(plans[1])

    if now == 21:
        for timestamp in l2_times:
            if timestamp > state.l2.timestamp:
                yield AdvanceL2(timestamp)
        if state.l2.timestamp in l2_times:
            entries = tuple(entry.delivery for entry in state.operations if entry.delivery is not None)
            if state.initial_delivery is not None:
                entries = (state.initial_delivery, *entries)
            for entry in entries:
                receipt = entry.receipt
                if entry.status == "NEW":
                    proof = relay_proof(state, receipt)
                    yield Process(receipt, proof)
                    if state.l2.timestamp == 19:
                        yield Process(receipt, replace(proof, checkpoint_l1_timestamp=20))
                    yield Process(receipt, replace(proof, usable=False))
                    yield Process(receipt, proof, Invocation(gas_ok=False))
                else:
                    yield Retry(receipt, caller="second-relayer")
                    if entry.status == "RETRIABLE":
                        yield Retry(receipt, Invocation(gas_ok=False))

    if now == 26:
        for block in (state.l2, *state.earlier_l2_blocks):
            if block.timestamp in l2_times:
                yield ProveUnzen(block)
                yield ProveUnzen(block, admitted=False)

    if now in (29, 30, 31, 45):
        available = tuple(FinalizedProof(checkpoint, 28)
                          for checkpoint in state.checkpoints if checkpoint.proven_at == 26)
        for proof in available:
            if now != 45:
                for signal in proof.checkpoint.block.stored_signals:
                    ack = ack_proof(state, proof, operation_id=signal.acknowledgment.operation_id)
                    for entry in state.operations:
                        if entry.delivery is not None:
                            yield Commit(entry.plan.operation_id, ack)
            if now in (29, 31, 45):
                expiry_proofs = tuple(PhaseAProof(
                    entry.plan.operation_id,
                    10 if entry.cancelled_at is None else 9,
                    28,
                    cancelled=entry.cancelled_at is not None,
                ) for entry in state.operations if entry.delivery is None)
                yield CheckReadiness(proof, state.selected)
                if expiry_proofs:
                    yield CheckReadiness(proof, state.selected, expiry_proofs)
                if state.committed_at is not None and now == 45:
                    config = InstalledConfigProof(state.l1, 29, 42)
                    yield CheckReadiness(proof, state.selected, config_proof=config)
        if now in (29, 31, 45):
            yield CheckReadiness(None, state.selected)


def _expected(state: State, action: Action) -> Transition[State] | str:
    """Predict the entire frame and observations for each offered bank edge."""
    if isinstance(action, AdvanceL1):
        return Transition(replace(state, l1_timestamp=action.timestamp))
    if isinstance(action, AdvanceL2):
        known = (*state.earlier_l2_blocks, state.l2)
        block = L2Block(action.timestamp, state.l2.installation, stored_signals=state.l2.stored_signals)
        return Transition(replace(state, l2=block, earlier_l2_blocks=known))
    if isinstance(action, Prepare):
        if state.operations and not (state.operations[0].abandoned
                                     or state.operations[0].cancelled_at == 9):
            return "governance upgrade still pending"
        prepared = Operation(action.plan, state.l1_timestamp)
        return Transition(replace(state, operations=(*state.operations, prepared)),
                          (("prepare", action.plan),))

    if isinstance(action, (Send, Cancel, Abandon, Commit)):
        index, operation = next(
            (index, entry) for index, entry in enumerate(state.operations)
            if entry.plan.operation_id == action.operation_id
        )
        plan = operation.plan
        if isinstance(action, Send):
            if operation.delivery:
                return "phase A already sent"
            if operation.cancelled_at == 9:
                return "phase A cancelled"
            if state.l1_timestamp == 10:
                return "phase A deadline"
            sequence = state.next_message_id
            message = Message(sequence, 1, 2, "dao", "controller", 0, 100_000, plan.e,
                              ("signal-pre-etna", "signal-v1"), Installation("signal-v2", 200), plan)
            receipt = Receipt(message, sha256(repr(message).encode()).hexdigest(), 9)
            updated = replace(operation, delivery=Delivery(receipt, "NEW"))
            post = replace(state, next_message_id=sequence + 1)
            event = ("message-sent", receipt)
        elif isinstance(action, Cancel):
            updated = replace(operation, cancelled_at=9)
            post, event = state, ("cancel", action.operation_id, 9)
        elif isinstance(action, Abandon):
            updated = replace(operation, abandoned=True)
            post, event = state, ("abandon", action.operation_id)
        else:
            if state.l1.fork_time == 200:
                return "unexpected old L1 configuration"
            if state.l1_timestamp in (30, 31):
                return "phase B deadline"
            if action.proof.acknowledgment.operation_id != action.operation_id:
                return "wrong ack operation"
            updated = replace(operation, committed=True)
            post = replace(state, l1=plan.new.l1, selected=plan.new, committed_at=29)
            event = ("phase-b", action.operation_id, plan.new.l1)
        return Transition(replace(post, operations=(
            *post.operations[:index], updated, *post.operations[index + 1:],
        )), (event,))

    if isinstance(action, (Process, Retry)):
        receipt = action.receipt
        initial_message = receipt.message.message_id == 6
        if initial_message:
            entry = state.initial_delivery
        else:
            index, operation = next((index, entry) for index, entry in enumerate(state.operations)
                                    if entry.delivery and entry.delivery.receipt == receipt)
            entry = operation.delivery
        if isinstance(action, Process) and not action.proof.usable:
            return "unusable or inexact relay proof"
        if isinstance(action, Retry) and entry.status == "DONE":
            return "RETRIABLE status required"
        deadline = 88 if initial_message else operation.plan.e
        prior = state.l2.installation.address
        failure = None
        if not action.invocation.gas_ok:
            failure = "invocation gas"
        elif state.l2.timestamp >= deadline:
            failure = "L2 deadline"
        elif prior == "signal-v2" or (initial_message and prior != "signal-pre-etna"):
            failure = "L2 predecessor"
        if failure and isinstance(action, Retry):
            return f"retry failed: {failure}"

        status = "RETRIABLE" if failure else "DONE"
        delivery = Delivery(receipt, status)
        events = (("bridge", receipt, status, failure),)
        block = state.l2
        if failure is None:
            installation = Installation("signal-v1", 100) if initial_message else Installation("signal-v2", 200)
            events += (("l2-install", block.timestamp, installation),)
            block = replace(block, installation=installation)
            if not initial_message:
                plan = operation.plan
                ack = Acknowledgment(plan.operation_id, plan.old, plan.new, 1, 2, "signal-v2")
                emission = Emission("controller", ack)
                block = replace(block, acknowledgments=(emission,), stored_signals=(emission,))
                events += (("ack", block.timestamp, emission),)
        if initial_message:
            return Transition(replace(state, l2=block, initial_delivery=delivery), events)
        updated = replace(operation, delivery=delivery)
        return Transition(replace(state, l2=block, operations=(
            *state.operations[:index], updated, *state.operations[index + 1:],
        )), events)

    if isinstance(action, ProveUnzen):
        if not action.admitted or state.checkpoints[-1].block.timestamp >= action.block.timestamp:
            return "Unzen checkpoint proof refused"
        checkpoint = Checkpoint(action.block, 26)
        return Transition(replace(state, checkpoints=(*state.checkpoints, checkpoint)),
                          (("checkpoint", checkpoint),))

    if isinstance(action, CheckReadiness):
        if state.l1.fork_time == 200 and action.config_proof is None:
            result = ("CLOSED", "phase B not finalized in local view")
        elif action.proof is None:
            result = ("CLOSED", "missing finalized Unzen proof")
        else:
            block = action.proof.checkpoint.block
            if block.installation.fork_time != state.l1.fork_time:
                result = ("CLOSED", "proven L2 implementation or fork mismatch")
            elif state.l1.fork_time == 100:
                sent_deadlines = tuple(entry.plan.e for entry in state.operations if entry.delivery)
                if block.timestamp < max(sent_deadlines, default=0):
                    result = ("CLOSED", "sent L2 deadline still open at proven block")
                elif len(action.phase_a_proofs) < sum(
                        entry.delivery is None for entry in state.operations):
                    result = ("CLOSED", "unsent phase A may execute")
                else:
                    result = ("OPEN", "replacement checks satisfied")
            else:
                result = ("OPEN", "replacement checks satisfied")
        return Transition(state, (("readiness", *result),))

    raise AssertionError(f"missing projection for offered action: {action!r}")


def check(pre: State, action: Action, post: Transition[State]) -> None:
    expected = _expected(pre, action)
    if post != expected:
        raise AssertionError(f"{type(action).__name__} expected {expected!r}, got {post!r}")


@dataclass(frozen=True, slots=True)
class Witness:
    bank: str
    path: tuple[Edge[State, Action], ...]
    refusal: RefusedEdge[State, Action] | None = None


@dataclass(frozen=True, slots=True)
class Assessment:
    status: str
    graphs: Mapping[str, Exploration[State, Action]]
    witnesses: Mapping[str, Witness]
    reason: str = ""


def _witnesses(name: str, graph: Exploration[State, Action], found: dict[str, Witness]) -> None:
    def record(label: str, edge: Edge[State, Action] | RefusedEdge[State, Action]):
        path = graph.path_to(edge.pre)
        if isinstance(edge, RefusedEdge):
            witness = Witness(name, path, edge)
        else:
            witness = Witness(name, (*path, edge))
        if label not in found or (len(witness.path) + (witness.refusal is not None)
                                 < len(found[label].path) + (found[label].refusal is not None)):
            found[label] = witness

    for edge in graph.accepted:
        action, pre = edge.action, edge.pre
        if isinstance(action, Send) and pre.l1_timestamp == 9:
            record("phase-a-before", edge)
        if isinstance(action, (Process, Retry)):
            if edge.events[0][2:] == ("DONE", None):
                if pre.l2.timestamp == 19 and action.receipt.message.plan is not None:
                    record("new-before-e" if isinstance(action, Process) else "retry-before-e", edge)
                elif action.receipt.message.plan is None:
                    record("initial-upgrade-first", edge)
                if (isinstance(action, Process) and action.receipt.message.plan is not None
                        and action.proof.checkpoint_l1_timestamp > pre.l2.timestamp):
                    record("relay-checkpoint-time-ahead-of-l2", edge)
            if edge.events[0][2:] == ("RETRIABLE", "L2 deadline") and pre.l2.timestamp == 20:
                record("new-at-e", edge)
            if (edge.events[0][2:] == ("RETRIABLE", "L2 predecessor")
                    and action.receipt.message.plan is None):
                record("late-initial-predecessor", edge)
            plan = action.receipt.message.plan
            if (edge.events[0][2:] == ("RETRIABLE", "L2 predecessor")
                    and plan is not None and plan.operation_id == "first"
                    and any(emission.acknowledgment.operation_id == "second"
                            for emission in pre.l2.acknowledgments)):
                record("late-replacement-predecessor", edge)
        if isinstance(action, Commit):
            record("exact-ack-commit", edge)
            block = action.proof.finality.checkpoint.block
            if not block.acknowledgments:
                record("descendant-checkpoint-commit", edge)
                if block.timestamp < pre.l2.timestamp:
                    record("non-tip-descendant-checkpoint-commit", edge)
        if isinstance(action, CheckReadiness):
            _, status, reason = edge.events[0]
            if pre.l1_timestamp >= 31 and pre.l1.fork_time == 100 and pre.l2.installation.fork_time == 200:
                if reason == "proven L2 implementation or fork mismatch":
                    record("missed-b-split", edge)
            if reason == "sent L2 deadline still open at proven block":
                timestamp = action.proof.checkpoint.block.timestamp
                sent = sum(entry.delivery is not None for entry in pre.operations)
                if timestamp == 19 and sent == 1:
                    record("early-old-observation", edge)
                if timestamp == 20 and sent == 2:
                    record("first-deadline-only", edge)
            if status == "OPEN":
                if pre.l1.fork_time == 200:
                    record("finalized-new-release", edge)
                elif len(pre.operations) == 2 and all(entry.delivery for entry in pre.operations):
                    record("two-sent-expiry", edge)
                elif action.phase_a_proofs:
                    if any(proof.cancelled for proof in action.phase_a_proofs):
                        record("unsent-cancelled", edge)
                    else:
                        record("unsent-expiry", edge)
            if reason == "unsent phase A may execute":
                record("unsent-no-final-evidence", edge)
    for edge in graph.refused:
        if isinstance(edge.action, Send) and edge.reason == "phase A deadline":
            record("phase-a-equality", edge)
        if isinstance(edge.action, Commit):
            if edge.reason == "wrong ack operation":
                record("authentic-other-operation", edge)
            if edge.reason == "phase B deadline" and edge.pre.l1_timestamp == 30:
                record("phase-b-equality", edge)
            if edge.reason == "phase B deadline" and edge.pre.l1_timestamp == 31:
                record("phase-b-after", edge)
        if isinstance(edge.action, Retry) and edge.reason == "retry failed: L2 deadline":
            if edge.pre.l2.timestamp == 20 and edge.action.receipt.message.deadline == 20:
                record("retry-at-e", edge)
        if (isinstance(edge.action, Process) and edge.action.receipt.message.plan is not None
                and edge.reason == "unusable or inexact relay proof"):
            record("withheld-relay-proof", edge)


REQUIRED_WITNESSES = frozenset({
    "phase-a-before", "phase-a-equality", "new-before-e", "new-at-e", "retry-before-e", "retry-at-e",
    "initial-upgrade-first", "late-initial-predecessor", "late-replacement-predecessor",
    "exact-ack-commit", "authentic-other-operation", "phase-b-equality", "phase-b-after",
    "missed-b-split", "early-old-observation", "first-deadline-only", "two-sent-expiry",
    "unsent-expiry", "unsent-cancelled", "unsent-no-final-evidence", "finalized-new-release",
    "withheld-relay-proof", "relay-checkpoint-time-ahead-of-l2", "descendant-checkpoint-commit",
    "non-tip-descendant-checkpoint-commit",
})


def assess_bank(*, max_states: int = 100_000) -> Assessment:
    graphs = {}
    witnesses = {}
    try:
        for name, (pending, _) in BANKS.items():
            graph = explore(initial(initial_pending=pending),
                            lambda state: actions(state, bank=name), step, check,
                            max_states=max_states)
            for edge in graph.refused:
                expected = _expected(edge.pre, edge.action)
                if edge.reason != expected:
                    raise AssertionError(f"{type(edge.action).__name__} expected {expected!r}, refused: {edge.reason}")
            graphs[name] = graph
            _witnesses(name, graph, witnesses)
        missing = REQUIRED_WITNESSES - witnesses.keys()
        if missing:
            raise AssertionError(f"missing required witnesses: {sorted(missing)}")
    except Exception as error:
        return Assessment("INCONCLUSIVE", MappingProxyType(graphs), MappingProxyType(witnesses),
                          str(error))
    return Assessment("EXHAUSTED", MappingProxyType(graphs), MappingProxyType(witnesses))
