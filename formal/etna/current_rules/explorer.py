"""Exhaust a declared finite action bank and retain its individual observations."""

from collections import deque
from collections.abc import Callable, Hashable, Iterable, Mapping
from dataclasses import dataclass
from types import MappingProxyType
from typing import Generic, TypeVar


StateT = TypeVar("StateT", bound=Hashable)
ActionT = TypeVar("ActionT")


class Refused(ValueError):
    """A modeled atomic refusal of the offered action."""


@dataclass(frozen=True, slots=True)
class Transition(Generic[StateT]):
    state: StateT
    events: tuple = ()


@dataclass(frozen=True, slots=True)
class Edge(Generic[StateT, ActionT]):
    pre: StateT
    action: ActionT
    post: StateT
    events: tuple


@dataclass(frozen=True, slots=True)
class RefusedEdge(Generic[StateT, ActionT]):
    pre: StateT
    action: ActionT
    reason: str


@dataclass(frozen=True, slots=True)
class Exploration(Generic[StateT, ActionT]):
    states: frozenset[StateT]
    accepted: tuple[Edge[StateT, ActionT], ...]
    refused: tuple[RefusedEdge[StateT, ActionT], ...]
    _parents: Mapping[StateT, Edge[StateT, ActionT] | None]

    def path_to(self, state: StateT) -> tuple[Edge[StateT, ActionT], ...]:
        """Reconstruct one shortest accepted path from its BFS predecessors."""
        path = []
        while (edge := self._parents[state]) is not None:
            path.append(edge)
            state = edge.pre
        return tuple(reversed(path))


def explore(
    initial: StateT,
    actions: Callable[[StateT], Iterable[ActionT]],
    step: Callable[[StateT, ActionT], Transition[StateT]],
    check: Callable[[StateT, ActionT, Transition[StateT]], None],
    *,
    max_states: int,
) -> Exploration[StateT, ActionT]:
    """Check every accepted edge. Model refusals and failed checks stay distinct."""
    if not __debug__:
        raise RuntimeError("INCONCLUSIVE: exploration requires Python assertions enabled")
    if max_states < 1:
        raise RuntimeError(f"INCONCLUSIVE: state cap {max_states} excludes the initial state")
    queue = deque([initial])
    parents = {initial: None}
    accepted = []
    refused = []
    while queue:
        pre = queue.popleft()
        for action in actions(pre):
            try:
                outcome = step(pre, action)
            except Refused as error:
                refused.append(RefusedEdge(pre, action, str(error)))
                continue
            check(pre, action, outcome)
            edge = Edge(pre, action, outcome.state, outcome.events)
            accepted.append(edge)
            if edge.post not in parents:
                if len(parents) == max_states:
                    raise RuntimeError(f"INCONCLUSIVE: state cap {max_states} reached")
                parents[edge.post] = edge
                queue.append(edge.post)
    return Exploration(frozenset(parents), tuple(accepted), tuple(refused),
                       MappingProxyType(parents))
