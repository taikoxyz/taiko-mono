"""Data-only framing for Etna product readback. No semantic verdict here."""

from dataclasses import dataclass
import hashlib
from pathlib import Path
import re

from tlc_values import MAX_CHARS, Refusal, integer, parse_log, record


@dataclass(frozen=True)
class FramedTrace:
    raw_digest: str
    invariant: str | None
    counts: dict
    complete: bool
    frames: tuple


@dataclass(frozen=True)
class Frame:
    index: int
    state: object
    receipt: object
    cursor: int
    probe: int | None = None


def read_pinned_raw(path, digest, outcome, *, allow_probe=False):
    if re.fullmatch(r"[0-9a-f]{64}", digest) is None:
        raise Refusal("expected lowercase SHA256 of raw TLC log")
    with Path(path).open("rb") as stream:
        raw = stream.read(MAX_CHARS + 1)
    if len(raw) > MAX_CHARS:
        raise Refusal("raw TLC trace exceeds byte limit")
    if hashlib.sha256(raw).hexdigest() != digest:
        raise Refusal("raw TLC trace SHA256 mismatch")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise Refusal("raw TLC trace is not UTF-8") from exc
    if "\x00" in text:
        raise Refusal("unexpected NUL in raw TLC log")
    parsed = parse_log(text, outcome)
    frames = []
    for step in parsed.states:
        row = step.values
        core = {"s", "receipt", "cursor"}
        if set(row) != core and not (allow_probe and set(row) == core | {"probe"}):
            raise Refusal(f"TLC variable domain does not match at state {step.number}")
        record(row["s"])
        cursor = integer(row["cursor"], low=0)
        probe = None
        if "probe" in row:
            probe = integer(row["probe"], low=0, high=7)
            if cursor != 0 or (not frames and probe != 0):
                raise Refusal("observer must start at zero over fixed Micro cursor zero")
            if frames and probe not in (frames[-1].probe, frames[-1].probe + 1):
                raise Refusal("observer regressed or advanced by more than one")
        frames.append(Frame(step.number, row["s"], row["receipt"], cursor, probe))
    return FramedTrace(digest, parsed.invariant, parsed.counts,
                       parsed.complete, tuple(frames))


def unchanged(previous, successor, label):
    if previous != successor:
        raise Refusal(f"frame unexpectedly changes {label}")


def equal(actual, expected, label):
    if actual != expected:
        raise Refusal(f"literal comparison failed for {label}")


def exact_record(value, names):
    return record(value, fields=names)


def sequence(value):
    if value.kind != "tuple":
        raise Refusal("expected ordered TLC sequence")
    return value.data
