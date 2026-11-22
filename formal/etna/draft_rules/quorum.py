"""Symbolic power and availability gates for the historical boundary model.

Parent vote flags and current key availability are premises. This module
checks their power and height domains without authenticating a commit.
"""

from dataclasses import dataclass

from .l2_staking import (
    UINT48_MAX,
    Action,
    Anchor,
    Selection,
    State,
    Transition,
    _integer,
    _key,
    _selection,
    _state,
    advance,
)


@dataclass(frozen=True, slots=True)
class FlagVote:
    key: str
    flag: str


@dataclass(frozen=True, slots=True)
class LastCommit:
    generation: int
    height: int
    votes: tuple[FlagVote, ...]


@dataclass(frozen=True, slots=True)
class Availability:
    generation: int
    height: int
    keys: tuple[str, ...]


def _validate_domain(
    actual_generation: int, actual_height: int, *, generation: int, height: int,
) -> None:
    if (not all(_integer(value, 0, UINT48_MAX)
                for value in (actual_generation, actual_height, generation, height))
            or actual_generation != generation or actual_height != height):
        raise ValueError("invalid generation or height for quorum premise")


def _validate_source_power(selection: Selection) -> None:
    if (selection.source in ("origin", "fallback")
            and any(member.power != 1 for member in selection.members)):
        raise ValueError("origin and fallback signing keys must have unit power")


def _selected_powers(selection: Selection) -> dict[str, int]:
    _selection(selection)
    _validate_source_power(selection)
    return {member.key: member.power for member in selection.members}


def _strict_quorum(power: int, total: int) -> int:
    if 3 * power <= 2 * total:
        raise ValueError("power does not meet a strict quorum")
    return power


def committed_power(
    selection: Selection, commit: LastCommit, *, generation: int, height: int,
) -> int:
    """Validate one flag per parent member and return strict commit power."""
    powers = _selected_powers(selection)
    if not isinstance(commit, LastCommit):
        raise ValueError("invalid parent commit premise")
    _validate_domain(commit.generation, commit.height, generation=generation, height=height)
    if type(commit.votes) is not tuple or len(commit.votes) != len(powers):
        raise ValueError("parent commit must contain one vote per signing key")
    seen = set()
    power = 0
    for vote in commit.votes:
        if (not isinstance(vote, FlagVote) or not _key(vote.key)
                or vote.key not in powers or vote.key in seen
                or type(vote.flag) is not str or vote.flag not in ("commit", "nil", "absent")):
            raise ValueError("invalid or duplicate parent vote")
        seen.add(vote.key)
        if vote.flag == "commit":
            power += powers[vote.key]
    return _strict_quorum(power, sum(powers.values()))


def available_power(
    selection: Selection, availability: Availability, *, generation: int, height: int,
) -> int:
    """Validate a set of eligible signing keys and return strict available power."""
    powers = _selected_powers(selection)
    if not isinstance(availability, Availability):
        raise ValueError("invalid availability premise")
    _validate_domain(
        availability.generation, availability.height, generation=generation, height=height
    )
    if type(availability.keys) is not tuple:
        raise ValueError("availability keys must be an immutable tuple")
    seen = set()
    power = 0
    for key in availability.keys:
        if not _key(key) or key not in powers or key in seen:
            raise ValueError("invalid or duplicate available key")
        seen.add(key)
        power += powers[key]
    return _strict_quorum(power, sum(powers.values()))


def advance_with_quorum(
    state: State, anchor: Anchor, *, parent: LastCommit | None, available: Availability,
    previous_available: Availability | None = None, actions: tuple[Action, ...] = (),
    block_start_ok: bool = True,
) -> Transition:
    """Admit one symbolic advance against the parent and current signing sets."""
    _state(state)
    # An admitted block also moves the pending set into next_signers.
    for selection in (state.current_signers, state.next_signers, state.pending_signers):
        _validate_source_power(selection)
    if state.height == UINT48_MAX:
        raise ValueError("height overflow")
    missing_keys = ()
    if state.height == state.origin:
        if parent is not None or previous_available is not None:
            raise ValueError("origin has no parent commit or parent availability")
    else:
        if parent is None:
            raise ValueError("parent commit is required")
        committed_power(
            state.current_signers, parent, generation=state.generation, height=state.height
        )
        if previous_available is not None:
            available_power(
                state.current_signers, previous_available,
                generation=state.generation, height=state.height,
            )
            eligible = set(previous_available.keys)
            if any(vote.key not in eligible and vote.flag != "absent" for vote in parent.votes):
                raise ValueError("unavailable parent key has a commit or nil vote")
        missing_keys = tuple(vote.key for vote in parent.votes if vote.flag != "commit")
    available_power(
        state.next_signers, available, generation=state.generation, height=state.height + 1
    )
    return advance(
        state, anchor, actions=actions, missing_keys=missing_keys, block_start_ok=block_start_ok
    )
