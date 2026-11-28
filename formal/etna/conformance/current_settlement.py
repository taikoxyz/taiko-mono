"""Offline current-rule capture and settlement of one immutable proof transaction.

A blob input is its ordered versioned hash. Backend results represent verified
statements. L1 authentication, proof verification and blob construction are
premises of this finite adapter.
"""
from dataclasses import dataclass
from typing import NamedTuple

from run_comet_apphash import keccak256

MAX_BATCH = 6


def uint(value, bits=256):
    if type(value) is not int or not 0 <= value < 1 << bits:
        raise ValueError("unsigned integer outside ABI width")
    return value


def word(value):
    return uint(value).to_bytes(32, "big")


def digest(value):
    if type(value) is not bytes or len(value) != 32:
        raise ValueError("bytes32 required")
    return value


def tag(value):
    return value.ljust(32, b"\0")


@dataclass(frozen=True)
class Cut:
    height: int
    el: bytes
    comet: bytes
    fi: int

    def __post_init__(self):
        uint(self.height, 48)
        digest(self.el)
        digest(self.comet)
        uint(self.fi)


class Context(NamedTuple):
    l1: int
    l2: int
    inbox: int
    registry: int
    config: bytes
    root: bytes
    reference_hash: bytes
    snapshot: int


class Job(NamedTuple):
    generation: int
    reference: int
    cuts: tuple
    blobs: tuple
    context: Context
    leaves: tuple
    statement: bytes


def cut_preimage(cut):
    if type(cut) is not Cut:
        raise ValueError("typed cut required")
    return word(cut.height) + digest(cut.el) + digest(cut.comet) + word(cut.fi)


def range_hash(generation, p, h, leaves):
    uint(p, 48)
    uint(h, 48)
    if not 1 <= h - p <= MAX_BATCH or len(leaves) != h - p - 1:
        raise ValueError("interior count differs from range")
    inner = keccak256(b"".join(digest(leaves[i]) for i in range(h - p - 1)))
    return keccak256(tag(b"ETNA_LAND_CUTS_V1") + word(generation) + word(p) + word(h) + inner)


def statement(generation, reference, origin, terminal, blobs, leaves, context):
    if type(context) is not Context:
        raise ValueError("typed statement context required")
    if not any(digest(context.reference_hash)) or uint(context.snapshot) > uint(reference):
        raise ValueError("unavailable reference or future committee snapshot")
    fields = (tag(b"TAIKO_ETNA_LAND_V1"), word(context.l1), word(context.l2),
              word(uint(context.inbox, 160)), word(uint(context.registry, 160)),
              word(generation), word(origin.height), origin.el, origin.comet,
              digest(context.config), word(terminal.height), terminal.el, terminal.comet,
              digest(context.root), word(reference), context.reference_hash,
              keccak256(b"".join(blobs)), word(origin.fi), word(terminal.fi),
              word(context.snapshot), range_hash(generation, origin.height, terminal.height, leaves))
    return keccak256(b"".join(fields))


def checked_blobs(values):
    result = tuple(digest(value) for value in values)
    if any(value[0] != 1 for value in result):
        raise ValueError("expected version 1 blob hashes")
    return result


def capture(generation, reference, cuts, blobs, context):
    uint(generation, 48)
    count = len(blobs)
    if not 1 <= count <= MAX_BATCH or len(cuts) != count + 1:
        raise ValueError("capture range exceeds capacity or lacks complete data")
    # Only index the bounded number of items just checked.
    frozen = tuple(cuts[i] for i in range(count + 1))
    original = checked_blobs(blobs[i] for i in range(count))
    for index, cut in enumerate(frozen):
        if type(cut) is not Cut or cut.height != frozen[0].height + index:
            raise ValueError("cut interval must be contiguous")
        if index and not 0 <= cut.fi - frozen[index - 1].fi <= 1:
            raise ValueError("invalid per-block FI advance")
    leaves = tuple(keccak256(cut_preimage(cut)) for cut in frozen[1:-1])
    bound = statement(generation, reference, frozen[0], frozen[-1], original, leaves, context)
    return Job(generation, reference, frozen, original, context, leaves, bound)


def land(job, *, generation, start, origin, checkpoint, fi_head, now, window,
         capacity, blobs, leaves, proofs):
    if type(job) is not Job or type(checkpoint) is not Cut:
        raise ValueError("missing captured job or checkpoint")
    if type(origin) is not tuple or len(origin) != 2 or type(origin[1]) is not Cut:
        raise ValueError("missing recorded origin")
    if type(job.cuts) is not tuple or type(job.blobs) is not tuple or type(job.leaves) is not tuple:
        raise ValueError("captured job contains mutable inputs")
    if not 2 <= len(job.cuts) <= MAX_BATCH + 1 or len(job.leaves) != len(job.cuts) - 2:
        raise ValueError("invalid original capture shape")
    if type(job.cuts[0]) is not Cut or type(job.cuts[-1]) is not Cut:
        raise ValueError("invalid capture endpoints")
    record_generation, parent = origin
    terminal = job.cuts[-1]
    p, c, h = job.cuts[0].height, checkpoint.height, terminal.height
    batch = h - p
    if not uint(start, 48) <= p <= c < h or not 1 <= batch <= min(MAX_BATCH, uint(capacity)):
        raise ValueError("inadmissible proof interval")
    if len(leaves) != batch - 1 or len(blobs) != batch or len(proofs) != 2:
        raise ValueError("incomplete original transaction")
    digest(job.statement)
    for leaf in job.leaves:
        digest(leaf)
    if capture(job.generation, job.reference, job.cuts, job.blobs, job.context) != job:
        raise ValueError("captured metadata or statement is inconsistent")
    if job.generation != uint(generation, 48):
        raise ValueError("stale proof generation")
    if uint(record_generation, 48) != generation and p != start:
        raise ValueError("origin is outside this generation")
    if not any(parent.el) or parent != job.cuts[0]:
        raise ValueError("origin record differs from proof")
    if not job.reference < uint(now) <= job.reference + uint(window):
        raise ValueError("reference is outside the readable past")
    if uint(fi_head) != checkpoint.fi or not 0 <= terminal.fi - fi_head <= h - c:
        raise ValueError("current FI checkpoint or suffix advance disagrees")
    if p == c and checkpoint != parent:
        raise ValueError("origin disagrees with checkpoint")
    supplied = tuple(digest(leaves[i]) for i in range(batch - 1))
    if p < c and supplied[c - p - 1] != keccak256(cut_preimage(checkpoint)):
        raise ValueError("overlap cut differs from current record")
    original = checked_blobs(blobs[i] for i in range(batch))
    bound = statement(generation, job.reference, parent, terminal, original, supplied, job.context)
    if original != job.blobs or bound != job.statement or any(
            digest(proofs[i]) != bound for i in range(2)):
        raise ValueError("transaction or backend statement differs from capture")
    return generation, c, terminal, now
