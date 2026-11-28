"""Slot 293 and recovery authorization projection (Z01).

A landing and a verifier-failure rollback carry authenticated premises. Origins,
landing records, recovery lists, and the rest of the DAO upgrade are outside
this projection. Refusal is atomic by construction of the immutable state.
"""

from collections.abc import Iterator
from dataclasses import dataclass, replace

from .explorer import Edge, Exploration, Refused, RefusedEdge, Transition


MAX_ANCHOR_AGE = 1296
MAX48 = 2**48 - 1
TIMESTAMPS = (0, 1, 2, 1296, 1297, 2592, 2593)
MAX_GENERATION = 2
MAX_CHECKPOINT = 2
MAX_NONCE = 3
MAX_RULES = 3
Schedule = tuple[int, int, int, int]


@dataclass(frozen=True, slots=True)
class State:
    timestamp: int = 0
    generation: int = 0
    c: int = 0
    nonce: int = 0
    schedule: Schedule = (0, 0, 0, 0)
    initialized: bool = True
    started: bool = True


@dataclass(frozen=True, slots=True)
class ScheduleRules:
    expected_generation: int
    rules: int
    time: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class ScheduleStop:
    expected_generation: int
    time: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class Recover:
    expected_generation: int
    expected_c: int
    expected_nonce: int
    valid_until: int
    rules: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class InvalidateNonce:
    expected_nonce: int
    owner: bool = True


@dataclass(frozen=True, slots=True)
class Land:
    c: int


@dataclass(frozen=True, slots=True)
class Rollback:
    trusted_c: int


@dataclass(frozen=True, slots=True)
class AdvanceTime:
    timestamp: int


Action = ScheduleRules | ScheduleStop | Recover | InvalidateNonce | Land | Rollback | AdvanceTime


@dataclass(frozen=True, slots=True)
class BoundOmission:
    action: Action
    fields: tuple[str, ...]


def initial() -> State:
    return State()


def rules_at(schedule: Schedule, timestamp: int) -> int:
    """Select the ruleset from an authenticated slot (START-10.1-3f)."""
    active_rules, next_rules, rules_time, _ = schedule
    return next_rules if timestamp >= rules_time else active_rules


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise Refused(reason)


def _uint(value: int, bits: int) -> int:
    _require(0 <= value < 2**bits, f"value does not fit uint{bits}")
    return value


def _updated(post: State) -> Transition[State]:
    # STOR-B-23..25 put four uint48 fields in listed order from the low bit.
    value = sum(_uint(field, 48) << (48 * offset)
                for offset, field in enumerate(post.schedule))
    return Transition(post, (("RulesScheduleUpdated", value),))


def step(state: State, action: Action) -> Transition[State]:
    now = state.timestamp
    active, next_rules, rules_time, stop_time = state.schedule

    if isinstance(action, (ScheduleRules, ScheduleStop, Recover, InvalidateNonce)):
        _require(action.owner, "Inbox owner required")
        _require(state.initialized, "Inbox uninitialized")

    if isinstance(action, (ScheduleRules, ScheduleStop)):
        # START-10.1-5c. Keep the sum wide, even when the compared slot field
        # cannot express a nonzero time that meets the minimum lead.
        _require(action.expected_generation == state.generation, "stale generation")
        threshold = _uint(now + MAX_ANCHOR_AGE, 256)
        _uint(action.time, 48)

        if isinstance(action, ScheduleStop):
            _require(stop_time == 0 or threshold < stop_time, "pending stop locked")
            _require(action.time == 0 or action.time >= threshold, "stop lead too short")
            return _updated(replace(state, schedule=(active, next_rules, rules_time, action.time)))

        if now >= rules_time:
            active = next_rules
        else:
            _require(threshold < rules_time, "pending rules locked")
        _uint(action.rules, 48)
        _require(action.rules in (next_rules, next_rules + 1), "invalid rules number")
        _require(action.time >= threshold, "rules lead too short")
        return _updated(replace(state, schedule=(active, action.rules, action.time, stop_time)))

    if isinstance(action, Recover):
        # RECOV-8-47/47a and 8.3, for the empty-list schedule projection.
        _require(state.started, "Etna start missing")
        _require(action.expected_generation == state.generation, "stale generation")
        _require(action.expected_c == state.c, "stale checkpoint")
        _require(action.expected_nonce == state.nonce, "stale nonce")
        _require(now <= _uint(action.valid_until, 256), "recovery authorization expired")
        generation = _uint(state.generation + 1, 48)
        nonce = _uint(state.nonce + 1, 256)
        _uint(action.rules, 48)
        if action.rules:
            _require(action.rules == next_rules + 1, "invalid structural rules")
            active = next_rules = action.rules
            rules_time = 0
        schedule = (active, next_rules, rules_time, 0)
        return _updated(replace(state, generation=generation, nonce=nonce, schedule=schedule))

    if isinstance(action, InvalidateNonce):
        _require(action.expected_nonce == state.nonce, "stale nonce")
        return Transition(replace(state, nonce=_uint(state.nonce + 1, 256)))

    if isinstance(action, Rollback):
        # The supplied checkpoint is the earlier trusted checkpoint selected
        # by the authorized verifier-failure upgrade (RECOV-8-31/32).
        _require(0 <= action.trusted_c < state.c, "rollback requires an earlier checkpoint")
        return Transition(replace(state, c=action.trusted_c, nonce=_uint(state.nonce + 1, 256)))

    if isinstance(action, Land):
        # The proof and admissible terminal height are premises of this action.
        _require(action.c > state.c, "landing must advance checkpoint")
        return Transition(replace(state, c=action.c))

    if isinstance(action, AdvanceTime):
        _require(_uint(action.timestamp, 256) > now, "time must advance")
        return Transition(replace(state, timestamp=action.timestamp))

    raise TypeError(f"unknown governance action: {action!r}")


def _input_bank(state: State) -> Iterator[Action]:
    """Offer named variations on individual guards, avoiding crossed input grids."""
    now, g, c, nonce = state.timestamp, state.generation, state.c, state.nonce
    lead = now + MAX_ANCHOR_AGE
    next_rules = state.schedule[1]
    stale_g = g - 1 if g else 1

    # Clock, valid landing, and rollback to the trusted initial checkpoint.
    yield from (AdvanceTime(timestamp) for timestamp in TIMESTAMPS if timestamp > now)
    yield Land(c + 1)
    if c:
        yield Rollback(0)

    # Rule number, minimum/short lead, pending replacement, and cancellation.
    yield ScheduleRules(g, next_rules + 1, lead)
    yield ScheduleRules(g, next_rules, lead)
    yield ScheduleRules(g, next_rules + 2, lead)
    yield ScheduleRules(g, next_rules + 1, lead - 1)
    yield ScheduleRules(g, next_rules, MAX48)
    yield ScheduleStop(g, lead)
    yield ScheduleStop(g, lead - 1)
    yield ScheduleStop(g, 0)
    if now == 0:
        yield ScheduleRules(g, next_rules + 1, 1297)
        yield ScheduleStop(g, 1297)
        yield ScheduleRules(g, next_rules + 1, 2592)
        yield ScheduleStop(g, 2592)

    if g:
        yield ScheduleRules(stale_g, next_rules + 1, lead)
        yield ScheduleRules(stale_g, next_rules, MAX48)
        yield ScheduleStop(stale_g, lead)
        yield ScheduleStop(stale_g, 0)

    recover = Recover(g, c, nonce, now, 0)
    yield recover
    yield replace(recover, rules=next_rules + 1)
    yield replace(recover, rules=next_rules + 2)
    yield replace(recover, expected_generation=stale_g)
    yield replace(recover, expected_c=c + 1)
    yield replace(recover, expected_nonce=nonce - 1 if nonce else 1)
    if now:
        yield replace(recover, valid_until=now - 1)
    yield InvalidateNonce(nonce)
    yield InvalidateNonce(nonce - 1 if nonce else 1)


def _omitted_fields(state: State, action: Action) -> tuple[str, ...]:
    # Keep every protocol refusal, including invalid calls whose hypothetical
    # writes would cross a model bound. A successful out-of-bound write is
    # separately observable and never classified as a protocol refusal.
    if not (
        isinstance(action, Land) and action.c > MAX_CHECKPOINT
        or isinstance(action, (Recover, InvalidateNonce, Rollback)) and state.nonce == MAX_NONCE
        or isinstance(action, Recover) and (state.generation == MAX_GENERATION or action.rules > MAX_RULES)
        or isinstance(action, ScheduleRules) and action.rules > MAX_RULES
    ):
        return ()
    try:
        post = step(state, action).state
    except Refused:
        return ()
    fields = (
        ("generation", post.generation, MAX_GENERATION),
        ("c", post.c, MAX_CHECKPOINT),
        ("nonce", post.nonce, MAX_NONCE),
        ("activeRules", post.schedule[0], MAX_RULES),
        ("nextRules", post.schedule[1], MAX_RULES),
    )
    return tuple(name for name, value, bound in fields if value > bound)


def actions(state: State) -> Iterator[Action]:
    return (action for action in _input_bank(state) if not _omitted_fields(state, action))


def bound_omissions(state: State) -> Iterator[BoundOmission]:
    for action in _input_bank(state):
        if fields := _omitted_fields(state, action):
            yield BoundOmission(action, fields)


def check(pre: State, action: Action, result: Transition[State]) -> None:
    post = result.state
    assert post.initialized == pre.initialized and post.started == pre.started
    assert post.timestamp == (action.timestamp if isinstance(action, AdvanceTime) else pre.timestamp)
    assert post.generation - pre.generation == int(isinstance(action, Recover))
    assert post.nonce - pre.nonce == int(isinstance(action, (Recover, InvalidateNonce, Rollback)))
    if isinstance(action, Land):
        assert post.c == action.c > pre.c
    elif isinstance(action, Rollback):
        assert post.c == action.trusted_c < pre.c
    else:
        assert post.c == pre.c

    if isinstance(action, (ScheduleRules, ScheduleStop, Recover)):
        assert action.owner and pre.initialized
        assert action.expected_generation == pre.generation, "stale schedule or recovery accepted"
        ((event, value),) = result.events
        assert event == "RulesScheduleUpdated"
        encoded = value.to_bytes(32, "little")
        assert not any(encoded[24:])
        assert post.schedule == tuple(int.from_bytes(encoded[offset:offset + 6], "little")
                                      for offset in range(0, 24, 6))
    else:
        assert post.schedule == pre.schedule and result.events == ()

    if isinstance(action, ScheduleRules):
        _, next_rules, rules_time, stop_time = pre.schedule
        assert action.rules - next_rules in (0, 1)
        assert pre.timestamp + MAX_ANCHOR_AGE <= action.time
        assert pre.timestamp >= rules_time or pre.timestamp < rules_time - MAX_ANCHOR_AGE
        assert post.schedule == (rules_at(pre.schedule, pre.timestamp), action.rules,
                                 action.time, stop_time)
    elif isinstance(action, ScheduleStop):
        assert action.time == 0 or pre.timestamp <= action.time - MAX_ANCHOR_AGE
        assert pre.schedule[3] == 0 or pre.timestamp < pre.schedule[3] - MAX_ANCHOR_AGE
        assert post.schedule[:3] == pre.schedule[:3] and post.schedule[3] == action.time
    elif isinstance(action, Recover):
        assert pre.started and action.expected_c == pre.c and action.expected_nonce == pre.nonce
        assert pre.timestamp <= action.valid_until
        assert post.schedule[3] == 0
        if action.rules == 0:
            assert post.schedule[:3] == pre.schedule[:3]
        else:
            assert pre.schedule[1] + 1 == action.rules
            assert post.schedule[:3] == (action.rules, action.rules, 0)
    elif isinstance(action, InvalidateNonce):
        assert pre.initialized and action.owner and action.expected_nonce == pre.nonce


GovernanceGraph = Exploration[State, Action]


def witness_minimum_lead(graph: GovernanceGraph) -> Edge[State, Action] | None:
    return next((edge for edge in graph.accepted
                 if isinstance(edge.action, ScheduleStop)
                 and edge.action.time == 1296 and edge.pre.timestamp == 0
                 and edge.post.schedule == (0, 0, 0, 1296)), None)


def witness_carried_rules(graph: GovernanceGraph) -> Edge[State, Action] | None:
    return next((edge for edge in graph.accepted
                 if isinstance(edge.action, Recover) and edge.action.rules == 0
                 and edge.pre.schedule == (0, 1, 1297, 1297)
                 and edge.post.schedule == (0, 1, 1297, 0)), None)


def witness_structural_upgrade(graph: GovernanceGraph) -> Edge[State, Action] | None:
    return next((edge for edge in graph.accepted
                 if isinstance(edge.action, Recover) and edge.action.rules == 2
                 and edge.pre.schedule == (0, 1, 1297, 1297)
                 and edge.post.schedule == (2, 2, 0, 0)), None)


def witness_post_rollback_schedule(
    graph: GovernanceGraph,
) -> tuple[Edge[State, Action], Edge[State, Action]] | None:
    cancellations = {edge.pre: edge for edge in graph.accepted
                     if isinstance(edge.action, ScheduleStop) and edge.action.time == 0
                     and edge.pre.schedule[3] != 0 and edge.pre.generation > 0}
    for edge in graph.accepted:
        if isinstance(edge.action, Rollback) and edge.post in cancellations:
            return edge, cancellations[edge.post]
    return None


def witness_stale_schedule(graph: GovernanceGraph) -> tuple[RefusedEdge[State, Action], ...] | None:
    pending = State(generation=1, nonce=1, schedule=(0, 1, 2592, 2592))
    stale = {edge.action: edge for edge in graph.refused
             if edge.pre == pending and edge.reason == "stale generation"}
    changes = {edge.action for edge in graph.accepted
               if edge.pre == pending and edge.post.schedule != pending.schedule}
    requests = (ScheduleRules(0, 2, 1296), ScheduleRules(0, 1, MAX48),
                ScheduleStop(0, 1296), ScheduleStop(0, 0))
    if all(request in stale and replace(request, expected_generation=1) in changes
           for request in requests):
        return tuple(stale[request] for request in requests)
    return None


def witness_locked_cancellation(graph: GovernanceGraph) -> RefusedEdge[State, Action] | None:
    return next((edge for edge in graph.refused
                 if edge.pre.timestamp == 1 and edge.pre.schedule[3] == 1297
                 and isinstance(edge.action, ScheduleStop) and edge.action.time == 0
                 and edge.reason == "pending stop locked"), None)
