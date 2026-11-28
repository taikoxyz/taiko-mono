"""Canonical positional Registry witnesses and config-bound committee selection.

The snapshot block, checkpoint count/root and config hash come from an
authenticated caller. This projection does not verify their L1 provenance.
"""

from dataclasses import dataclass
from pathlib import Path
import sys

from ..conformance.run_comet_apphash import keccak256


# The unchanged Registry hash helper still uses sibling absolute imports.
_CONFORMANCE = str(Path(__file__).resolve().parents[1] / "conformance")
sys.path.insert(0, _CONFORMANCE)
try:
    from ..conformance.registry_snapshot import entries_root as _entries_root
finally:
    del sys.path[0]

Entry = tuple[int, int, int, int, int]
Member = tuple[int, int, int, int]
EMPTY: Entry = (0, 0, 0, 0, 0)
MAX_SLOTS = 4096
MIN_VP_UNIT = 867_361_738
FIXED_SUPPLY = 10**27
MAX_POWER = (2**63 - 1) // 8


@dataclass(frozen=True, slots=True)
class Config:
    l2_chain_id: int
    registry: int
    vp_unit: int
    min_stake: int
    n_max: int
    u: int


def _uint(value: int, bits: int, label: str) -> int:
    if type(value) is not int or not 0 <= value < 1 << bits:
        raise ValueError(f"{label} must be uint{bits}")
    return value


def _check_bytes32(value: bytes, label: str) -> None:
    if type(value) is not bytes or len(value) != 32:
        raise ValueError(f"{label} must be bytes32")


def _abi(tag: bytes, *words: int) -> bytes:
    return tag.ljust(32, b"\0") + b"".join(word.to_bytes(32, "big") for word in words)


def config_preimage(config: Config) -> bytes:
    """Encode the typed seven-word committee config (ENC-A-36)."""
    if type(config) is not Config:
        raise ValueError("committee config must be a Config")
    return _abi(
        b"ETNA_PARENT_ANCHOR_V1",
        _uint(config.l2_chain_id, 256, "L2 chain id"),
        _uint(config.registry, 160, "registry address"),
        _uint(config.vp_unit, 256, "vp_unit"),
        _uint(config.min_stake, 256, "min_stake"),
        _uint(config.n_max, 256, "n_max"),
        _uint(config.u, 256, "U"),
    )


def config_hash(config: Config) -> bytes:
    return keccak256(config_preimage(config))


def _check_rows(rows: tuple[Entry, ...]) -> None:
    if type(rows) is not tuple or len(rows) > MAX_SLOTS:
        raise ValueError("Registry rows must be a positional tuple of at most 4096 slots")
    for row in rows:
        if type(row) is not tuple or len(row) != 5:
            raise ValueError("Registry row must be a five-word tuple")
        prefix, x, stake, active, exit_at = row
        _uint(prefix, 8, "key prefix")
        _uint(x, 256, "key X")
        _uint(stake, 256, "effective stake")
        _uint(active, 48, "activation block")
        _uint(exit_at, 48, "effective exit")
        if row != EMPTY and prefix not in (2, 3):
            raise ValueError("occupied Registry row lacks a compressed key prefix")


def _check_canonical_rows(entries: tuple[Entry, ...]) -> None:
    _check_rows(entries)
    if entries and entries[-1] == EMPTY:
        raise ValueError("snapshot has a trailing empty slot")


def canonical_entries(slots: tuple[Entry, ...]) -> tuple[Entry, ...]:
    """Project through the last occupied slot, even if its stake is zero."""
    _check_rows(slots)
    count = len(slots)
    while count and slots[count - 1] == EMPTY:
        count -= 1
    return slots[:count]


def validate_snapshot(entries: tuple[Entry, ...], count: int, root: bytes) -> None:
    """Check canonical shape and verify the supplied checkpoint commitment."""
    _uint(count, 48, "checkpoint count")
    _check_canonical_rows(entries)
    if len(entries) != count:
        raise ValueError("entry count mismatch")
    _check_bytes32(root, "entries root")
    if _entries_root(entries, count) != root:
        raise ValueError("entries root mismatch")


def select(
    entries: tuple[Entry, ...], snapshot: int, config: Config, expected_config_hash: bytes,
) -> tuple[Member, ...]:
    """Derive the set after the caller has checked the checkpoint with validate_snapshot."""
    _check_bytes32(expected_config_hash, "committee config hash")
    if config_hash(config) != expected_config_hash:
        raise ValueError("committee config hash mismatch")
    if not 1 <= config.n_max <= MAX_SLOTS or not 1 <= config.u <= 65536:
        raise ValueError("n_max or U outside deployment bounds")
    if config.vp_unit < MIN_VP_UNIT:
        raise ValueError("vp_unit below deployment floor")
    if config.min_stake < config.vp_unit:
        raise ValueError("min_stake must be at least vp_unit")
    if MAX_SLOTS * config.min_stake <= FIXED_SUPPLY:
        raise ValueError("min_stake must exceed the fixed supply per slot")

    _uint(snapshot, 48, "selection snapshot")
    _check_canonical_rows(entries)
    eligible = []
    keys = set()
    for prefix, x, stake, active, exit_at in entries:
        if active <= snapshot < exit_at and stake >= config.min_stake:
            key = (prefix, x)
            if key in keys:
                raise ValueError("duplicate eligible consensus key")
            keys.add(key)
            set_key = keccak256(_abi(b"ETNA_SET_KEY_V1", config.l2_chain_id, *key))
            eligible.append((stake, set_key, key))
    if not eligible:
        raise ValueError("empty selected set")

    ranked = sorted(eligible, key=lambda item: (-item[0], item[1]))[:config.n_max]
    ordered = sorted(ranked, key=lambda item: item[1])
    members = tuple((*key, stake, stake // config.vp_unit) for stake, _, key in ordered)
    if any(not 0 < power < 2**64 for _, _, _, power in members):
        raise ValueError("selected member lacks positive uint64 power")
    if sum(power for _, _, _, power in members) > MAX_POWER:
        raise ValueError("selected total power exceeds the CometBFT maximum")
    return members
