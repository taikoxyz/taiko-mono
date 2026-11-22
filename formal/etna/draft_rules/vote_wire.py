"""Raw Etna canonical vote serialization for a preauthenticated chain domain."""

from dataclasses import dataclass
import re


@dataclass(frozen=True)
class VoteFields:
    vote_type: int
    height: int
    round: int
    block_hash: bytes
    parts_total: int
    parts_hash: bytes
    seconds: int
    nanos: int


def _varint(value):
    # Protobuf represents even a negative int32 as the varint of a full uint64.
    value &= (1 << 64) - 1
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def _delimited(tag, body):
    return tag + _varint(len(body)) + body


def _number(tag, value):
    return tag + _varint(value) if value else b""


def vote_sign_bytes(fields: VoteFields, chain_id: str) -> bytes:
    """Encode the original integer fields, including non-calendar timestamps."""
    if type(fields) is not VoteFields:
        raise ValueError("expected VoteFields")
    if type(chain_id) is not str or not re.fullmatch(r"etna-[a-zA-Z0-9_-]{43}", chain_id):
        raise ValueError("expected a 48-byte Etna chain ID")
    for name, value, low, high in (
        ("vote_type", fields.vote_type, -(1 << 31), 1 << 31),
        ("height", fields.height, -(1 << 63), 1 << 63),
        ("round", fields.round, -(1 << 31), 1 << 31),
        ("parts_total", fields.parts_total, 0, 1 << 32),
        ("seconds", fields.seconds, -(1 << 63), 1 << 63),
        ("nanos", fields.nanos, -(1 << 31), 1 << 31),
    ):
        if type(value) is not int or not low <= value < high:
            raise ValueError("wrong integer type or range for " + name)
    for value in (fields.block_hash, fields.parts_hash):
        if type(value) is not bytes or len(value) not in (0, 32):
            raise ValueError("hash must be empty or contain exactly 32 immutable bytes")

    vote = _number(b"\x08", fields.vote_type)
    if fields.height:
        vote += b"\x11" + fields.height.to_bytes(8, "little", signed=True)
    if fields.round:
        vote += b"\x19" + fields.round.to_bytes(8, "little", signed=True)
    if fields.block_hash or fields.parts_total or fields.parts_hash:
        part_set = _number(b"\x08", fields.parts_total)
        if fields.parts_hash:
            part_set += _delimited(b"\x12", fields.parts_hash)
        block = _delimited(b"\x0a", fields.block_hash) if fields.block_hash else b""
        vote += _delimited(b"\x22", block + _delimited(b"\x12", part_set))
    timestamp = _number(b"\x08", fields.seconds) + _number(b"\x10", fields.nanos)
    vote += _delimited(b"\x2a", timestamp) + _delimited(b"\x32", chain_id.encode("ascii"))
    return _varint(len(vote)) + vote
