"""Strict executable model for the Slot-Chain economic profile.

The JSON example is deliberately uncalibrated.  Structural validation accepts
that state, while :func:`production_blockers` rejects it and every incomplete,
mis-bound, overflowing, or arithmetically inconsistent production profile.
"""

from __future__ import annotations

from dataclasses import dataclass
import copy
import hashlib
import json
from pathlib import Path
import re
import runpy
from typing import Any, Callable

try:
    from Crypto.Hash import keccak as _native_keccak
except ImportError:  # Keep the executable specification dependency-free.
    _native_keccak = None

_PURE_KECCAK256 = runpy.run_path(
    str(Path(__file__).with_name("lookahead-model.py"))
)["keccak256"]


UINT64_MAX = (1 << 64) - 1
UINT256_MAX = (1 << 256) - 1
DATA_BYTES_PER_BLOB = 4_096 * 31 - 4
ECONOMIC_PROFILE_DOMAIN = b"slot-chain-economic-profile-v2"
BUILDER_REGISTRY_ECONOMIC_CONFIG_DOMAIN = (
    b"slot-chain-builder-registry-economic-config-v2"
)


@dataclass(frozen=True)
class FieldRule:
    kind: str
    nullable: bool = False
    exact: Any = None
    minimum: int = 0
    maximum: int = UINT256_MAX


EXACT = lambda value: FieldRule("exact", exact=value)
UINT = FieldRule("uint")
POSITIVE_UINT = FieldRule("uint", minimum=1)
NULLABLE_UINT = FieldRule("uint", nullable=True)
NULLABLE_POSITIVE_UINT = FieldRule("uint", nullable=True, minimum=1)
UINT8 = FieldRule("uint", maximum=(1 << 8) - 1)
UINT64 = FieldRule("uint", maximum=UINT64_MAX)
NULLABLE_UINT64 = FieldRule("uint", nullable=True, maximum=UINT64_MAX)
DECIMAL = FieldRule("decimal")
NULLABLE_DECIMAL = FieldRule("decimal", nullable=True)
NULLABLE_BPS_DECIMAL = FieldRule("decimal", nullable=True, maximum=10_000)
POSITIVE_DECIMAL = FieldRule("decimal", minimum=1)
NULLABLE_POSITIVE_DECIMAL = FieldRule("decimal", nullable=True, minimum=1)
HASH = FieldRule("hash")
NULLABLE_HASH = FieldRule("hash", nullable=True)
ADDRESS = FieldRule("address")
NULLABLE_ADDRESS = FieldRule("address", nullable=True)
NONEMPTY_STRING = FieldRule("string")


REWARD_CLASS_SCHEMA = {
    "classId": UINT8,
    "name": NONEMPTY_STRING,
    "fixedWei": DECIMAL,
    "perExecutionGasWei": DECIMAL,
    "perPublishedByteWei": DECIMAL,
    "capWei": DECIMAL,
}


# This is the complete permitted-key tree.  A schema change must edit this
# constant and its example in the same reviewed change.
EXPECTED_SCHEMA = {
    "schema": EXACT("taiko.slot-chain.economic-profile.v2"),
    "status": FieldRule("status"),
    "profileId": NULLABLE_HASH,
    "measurementCommit": NULLABLE_HASH,
    "units": {
        "nativeAmount": EXACT("wei"),
        "nativeRate": EXACT("wei/second"),
        "builderAmount": EXACT("atomic"),
        "time": EXACT("seconds"),
        "gas": EXACT("gas"),
        "size": EXACT("bytes"),
        "ratio": EXACT("basis-points"),
    },
    "geometry": {
        "slotSeconds": POSITIVE_UINT,
        "windowSlots": POSITIVE_UINT,
        "l1SlotSeconds": POSITIVE_UINT,
        "l1EpochSlots": POSITIVE_UINT,
        "maximumBuilders": POSITIVE_UINT,
        "maximumAssignedSlots": POSITIVE_UINT,
        "entryDelayWindows": POSITIVE_UINT,
        "maximumLiveWindows": POSITIVE_UINT,
        "maximumTrancheAheadWindows": POSITIVE_UINT,
        "maximumGenerationMovesPerWindow": POSITIVE_UINT,
        "maximumLiabilityGenerations": POSITIVE_UINT,
        "snapshotEpochs": POSITIVE_UINT,
        "finalityEpochs": POSITIVE_UINT,
        "carrierScanSlots": POSITIVE_UINT,
        "sealMarginSlots": POSITIVE_UINT,
        "lookaheadSlots": POSITIVE_UINT,
        "maximumParentGapSlots": POSITIVE_UINT,
        "maximumCandidateBlocks": POSITIVE_UINT,
        "maximumCandidateWindows": POSITIVE_UINT,
        "maximumCandidateAnchors": POSITIVE_UINT,
        "maximumCandidateSessions": POSITIVE_UINT,
        "maximumCandidateRecords": POSITIVE_UINT,
        "maximumCandidateForcedItems": POSITIVE_UINT,
        "maximumCandidateForcedBytes": POSITIVE_UINT,
        "maximumCandidateForcedGas": POSITIVE_UINT,
        "maximumEarlySealWindows": POSITIVE_UINT,
        "canonicalHistoryCells": POSITIVE_UINT,
        "eip2935HistoryBlocks": POSITIVE_UINT,
        "maximumArmAgeBlocks": POSITIVE_UINT,
        "seatCount": EXACT(4),
        "standbyCount": EXACT(3),
        "pendingCount": EXACT(4),
        "bookSize": POSITIVE_UINT,
        "maximumRewardClasses": POSITIVE_UINT,
    },
    "assets": {
        "builderLease": {
            "kind": EXACT("ERC20_NO_HOOK"),
            "chainId": NULLABLE_UINT64,
            "address": NULLABLE_ADDRESS,
            "runtimeHash": NULLABLE_HASH,
            "decimals": FieldRule("uint", nullable=True, maximum=255),
        },
        "nativeCustody": {
            "kind": EXACT("NATIVE_ETH"),
            "chainId": NULLABLE_UINT64,
        },
    },
    "builder": {
        "leasePerWindowAtomic": NULLABLE_POSITIVE_DECIMAL,
        "maximumBondAtomic": NULLABLE_POSITIVE_DECIMAL,
        "reporterRewardCapAtomic": NULLABLE_DECIMAL,
        "evidenceDelaySeconds": POSITIVE_UINT,
        "reorgMarginSeconds": POSITIVE_UINT,
    },
    "recovery": {
        "settlementWindowSeconds": POSITIVE_UINT,
        "tipLagSeconds": POSITIVE_UINT,
        "finalLagSeconds": POSITIVE_UINT,
        "l1FinalityBlocks": POSITIVE_UINT,
        "depthTimeMaxSeconds": POSITIVE_UINT,
        "proofTimeMaxSeconds": POSITIVE_UINT,
        "proofMarginSeconds": POSITIVE_UINT,
        "activationInclusionSeconds": POSITIVE_UINT,
        "submissionInclusionSeconds": POSITIVE_UINT,
        "clockSkewSeconds": UINT,
        "escapeOffsetSeconds": POSITIVE_UINT,
        "forceDelaySeconds": POSITIVE_UINT,
    },
    "gasProfile": {
        "l2BlockGas": EXACT(30_000_000),
        "steadyAnchorGas": EXACT(1_000_000),
        "steadyForcedGas": EXACT(20_000_000),
        "activationAnchorGas": EXACT(12_000_000),
        "activationForcedGas": EXACT(13_000_000),
        "systemMarginGas": EXACT(5_000_000),
        "minimumForceAccountedGas": EXACT(21_000),
    },
    "dataSession": {
        "ttlSeconds": EXACT(86_400),
        "refundClaimWindowSeconds": EXACT(86_400),
        "maximumLiveSessions": EXACT(1_024),
        "maximumLiveSessionsPerOwner": EXACT(2),
        "maximumRecordsPerSession": EXACT(2_100),
        "maximumGcSteps": EXACT(8),
        "maximumBlobsPerPost": EXACT(6),
        "refundableBondWei": NULLABLE_POSITIVE_DECIMAL,
        "baseRentWei": NULLABLE_POSITIVE_DECIMAL,
        "rentPerPublishedByteWei": NULLABLE_DECIMAL,
        "blobBaseFeeMultiplierBps": NULLABLE_BPS_DECIMAL,
    },
    "forcedEnvelope": {
        "fixedIngressWei": NULLABLE_POSITIVE_DECIMAL,
        "executionWeiPerAccountedGas": NULLABLE_POSITIVE_DECIMAL,
        "proofWeiPerAccountedGas": NULLABLE_POSITIVE_DECIMAL,
        "permanentWeiPerByte": NULLABLE_POSITIVE_DECIMAL,
        "maximumAcceptedFeeWei": NULLABLE_POSITIVE_DECIMAL,
        "claimWindowSeconds": POSITIVE_UINT,
        "maximumValiditySeconds": POSITIVE_UINT,
        "maximumItemBytes": POSITIVE_UINT,
        "maximumItemAccountedGas": POSITIVE_UINT,
        "maximumPrefixItems": POSITIVE_UINT,
        "maximumPrefixBytes": POSITIVE_UINT,
        "maximumPrefixAccountedGas": POSITIVE_UINT,
        "queueDepth": EXACT(64),
        "maximumQueueCount": POSITIVE_DECIMAL,
        "maximumRangeProofHashes": EXACT(257),
    },
    "bridge": {
        "maximumEnqueueDelaySeconds": POSITIVE_UINT,
        "processTtlSeconds": POSITIVE_UINT,
        "supportFinalityBlocks": POSITIVE_UINT,
        "maximumDomainEntriesPerRelease": POSITIVE_UINT,
        "refundCapsuleWords": POSITIVE_UINT,
        "refundErc721Ids": POSITIVE_UINT,
        "refundErc1155Pairs": POSITIVE_UINT,
        "terminalAccumulatorDepth": EXACT(64),
        "maximumTerminalCount": POSITIVE_DECIMAL,
        "registrationProofMaximumNodesPerPath": EXACT(66),
        "registrationProofPathCount": EXACT(2),
        "registrationProofMaximumTotalNodes": EXACT(132),
        "registrationProofMaximumNodeBytes": EXACT(600),
        "registrationProofMaximumBytes": EXACT(80_000),
        "registrationProofMaximumGas": EXACT(8_000_000),
    },
    "seat": {
        "slaBondWei": NULLABLE_POSITIVE_DECIMAL,
        "maximumAskWeiPerSecond": NULLABLE_POSITIVE_DECIMAL,
        "minimumAskImprovementWeiPerSecond": NULLABLE_DECIMAL,
        "minimumAskImprovementBps": NULLABLE_BPS_DECIMAL,
        "quoteMaturitySeconds": NULLABLE_POSITIVE_UINT,
        "quoteMaturityBlocks": NULLABLE_POSITIVE_UINT,
        "minimumPrimaryTenureSeconds": NULLABLE_POSITIVE_UINT,
        "minimumStandbyTenureSeconds": NULLABLE_POSITIVE_UINT,
        "maximumStandbyLeaseSeconds": NULLABLE_POSITIVE_UINT,
        "handoverDelaySeconds": NULLABLE_POSITIVE_UINT,
        "stageGraceSeconds": NULLABLE_POSITIVE_UINT,
        "maximumInclusionSeconds": POSITIVE_UINT,
        "handoverExecutionBufferSeconds": NULLABLE_POSITIVE_UINT,
        "exitDelaySeconds": NULLABLE_POSITIVE_UINT,
        "releaseChallengeSeconds": NULLABLE_POSITIVE_UINT,
        "evidenceDelaySeconds": NULLABLE_POSITIVE_UINT,
        "premiumClaimDelaySeconds": NULLABLE_POSITIVE_UINT,
        "reorgStabilitySeconds": POSITIVE_UINT,
        "recoveryLagSeconds": POSITIVE_UINT,
        "slashLagSeconds": POSITIVE_UINT,
        "seatRunwaySeconds": NULLABLE_POSITIVE_UINT,
        "maximumAvoidedServiceCostWei": NULLABLE_DECIMAL,
        "collusionSafetyMarginWei": NULLABLE_POSITIVE_DECIMAL,
    },
    "rewards": {
        "claimWindowSeconds": POSITIVE_UINT,
        "classes": FieldRule("reward_classes"),
    },
    "sinks": {
        "builderPenalty": {
            "asset": EXACT("BUILDER_LEASE"),
            "address": NULLABLE_ADDRESS,
        },
        "dataRent": {
            "asset": EXACT("NATIVE_ETH"),
            "address": NULLABLE_ADDRESS,
        },
        "seatPenalty": {
            "asset": EXACT("NATIVE_ETH"),
            "address": NULLABLE_ADDRESS,
        },
        "forcedExpiry": {
            "asset": EXACT("NATIVE_ETH"),
            "address": NULLABLE_ADDRESS,
        },
        "bridgeSurplus": {
            "asset": EXACT("NATIVE_ETH"),
            "address": NULLABLE_ADDRESS,
        },
    },
}


_DECIMAL_RE = re.compile(r"(?:0|[1-9][0-9]*)\Z")
_ADDRESS_RE = re.compile(r"0x[0-9a-f]{40}\Z")
_HASH_RE = re.compile(r"0x[0-9a-f]{64}\Z")


def checked_add_u256(a: int, b: int) -> int:
    """Return ``a + b`` or reject non-uint256 input/overflow."""

    if (
        type(a) is not int
        or type(b) is not int
        or not 0 <= a <= UINT256_MAX
        or not 0 <= b <= UINT256_MAX
    ):
        raise ValueError("uint256 addition overflow")
    result = a + b
    if result > UINT256_MAX:
        raise ValueError("uint256 addition overflow")
    return result


def checked_mul_u256(a: int, b: int) -> int:
    """Return ``a * b`` or reject non-uint256 input/overflow."""

    if (
        type(a) is not int
        or type(b) is not int
        or not 0 <= a <= UINT256_MAX
        or not 0 <= b <= UINT256_MAX
    ):
        raise ValueError("uint256 multiplication overflow")
    result = a * b
    if result > UINT256_MAX:
        raise ValueError("uint256 multiplication overflow")
    return result


def ceil_div_u256(numerator: int, denominator: int) -> int:
    """Checked ceiling division without an overflowing ``n + d - 1``."""

    if (
        type(numerator) is not int
        or type(denominator) is not int
        or numerator < 0
        or numerator > UINT256_MAX
        or denominator <= 0
        or denominator > UINT256_MAX
    ):
        raise ValueError("invalid uint256 ceiling division")
    quotient, remainder = divmod(numerator, denominator)
    return checked_add_u256(quotient, int(remainder != 0))


def _sum_u256(*values: int) -> int:
    total = 0
    for value in values:
        total = checked_add_u256(total, value)
    return total


def _duplicate_safe_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate key {key}")
        result[key] = value
    return result


def load_economic_profile(path: str) -> dict:
    """Load JSON while rejecting duplicate object keys before validation."""

    with open(path, encoding="utf-8") as stream:
        value = json.load(stream, object_pairs_hook=_duplicate_safe_object)
    if not isinstance(value, dict):
        raise ValueError("economic profile must be an object")
    return value


def get_path(profile: dict, path: str) -> Any:
    value: Any = profile
    for component in path.split("."):
        if isinstance(value, list):
            value = value[int(component)]
        else:
            value = value[component]
    return value


def set_path(profile: dict, path: str, value: Any) -> None:
    """Set a test/profile path while retaining a decimal leaf's JSON type."""

    components = path.split(".")
    target: Any = profile
    for component in components[:-1]:
        target = target[int(component)] if isinstance(target, list) else target[component]
    leaf: Any = int(components[-1]) if isinstance(target, list) else components[-1]
    current = target[leaf]
    if isinstance(current, str) and type(value) is int and _DECIMAL_RE.fullmatch(current):
        value = str(value)
    target[leaf] = value


def _canonical_decimal(value: Any, maximum: int = UINT256_MAX) -> bool:
    if not isinstance(value, str) or _DECIMAL_RE.fullmatch(value) is None:
        return False
    maximum_text = str(maximum)
    return len(value) < len(maximum_text) or (
        len(value) == len(maximum_text) and value <= maximum_text
    )


def _as_u256(value: Any) -> int:
    if type(value) is int and 0 <= value <= UINT256_MAX:
        return value
    if _canonical_decimal(value):
        return int(value)
    raise ValueError("not a uint256")


def _at(profile: dict, path: str) -> int:
    return _as_u256(get_path(profile, path))


def _field_error(path: str, rule: FieldRule, value: Any) -> str | None:
    if value is None:
        return None if rule.nullable else f"{path} must not be null"
    if rule.kind == "exact":
        if type(value) is not type(rule.exact) or value != rule.exact:
            return f"{path} must equal {rule.exact}"
    elif rule.kind == "status":
        if value not in ("UNCALIBRATED", "CALIBRATED"):
            return f"{path} must be UNCALIBRATED or CALIBRATED"
    elif rule.kind == "uint":
        if type(value) is not int or not rule.minimum <= value <= rule.maximum:
            if rule.minimum == 1:
                return f"{path} must be a positive integer"
            return f"{path} must be a non-negative integer"
    elif rule.kind == "decimal":
        if not _canonical_decimal(value):
            return f"{path} must be a canonical uint256 decimal string"
        parsed = int(value)
        if parsed > rule.maximum:
            return f"{path} must be <= {rule.maximum}"
        if rule.minimum == 1 and parsed == 0:
            return f"{path} must be a positive uint256 decimal string"
    elif rule.kind == "address":
        if not isinstance(value, str) or _ADDRESS_RE.fullmatch(value) is None:
            return f"{path} must be a lowercase 20-byte address"
    elif rule.kind == "hash":
        if not isinstance(value, str) or _HASH_RE.fullmatch(value) is None:
            return f"{path} must be a lowercase 32-byte hash"
    elif rule.kind == "string":
        if not isinstance(value, str) or not value:
            return f"{path} must be a non-empty string"
    return None


def _key_prefix(path: str) -> str:
    return f"{path}: " if path else ""


def _key_sort(key: Any) -> tuple[str, str]:
    return type(key).__name__, repr(key)


def _display_key(key: Any) -> str:
    return key if isinstance(key, str) else repr(key)


def _validate_object(
    value: Any, expected: dict[str, Any], path: str, errors: list[str]
) -> None:
    if not isinstance(value, dict):
        errors.append(f"{path or 'profile'} must be an object")
        return
    prefix = _key_prefix(path)
    for key in sorted(set(expected) - set(value)):
        errors.append(f"{prefix}missing key {key}")
    for key in sorted(set(value) - set(expected), key=_key_sort):
        errors.append(f"{prefix}unknown key {_display_key(key)}")
    for key in sorted(set(expected) & set(value)):
        child_path = f"{path}.{key}" if path else key
        rule = expected[key]
        if isinstance(rule, dict):
            _validate_object(value[key], rule, child_path, errors)
        elif rule.kind == "reward_classes":
            _validate_reward_classes(value[key], child_path, errors)
        else:
            error = _field_error(child_path, rule, value[key])
            if error is not None:
                errors.append(error)


def _validate_reward_classes(value: Any, path: str, errors: list[str]) -> None:
    if not isinstance(value, list):
        errors.append(f"{path} must be an array")
        return
    class_ids: list[int] = []
    for index, reward_class in enumerate(value):
        item_path = f"{path}.{index}"
        _validate_object(reward_class, REWARD_CLASS_SCHEMA, item_path, errors)
        if isinstance(reward_class, dict):
            class_id = reward_class.get("classId")
            if type(class_id) is int and 0 <= class_id <= 255:
                class_ids.append(class_id)
    if class_ids != sorted(set(class_ids)) or len(class_ids) != len(value):
        errors.append(f"{path} must be strictly sorted by unique classId")


def validate_schema(profile: Any) -> tuple[str, ...]:
    """Return stable structural errors for the complete v2 schema."""

    errors: list[str] = []
    _validate_object(profile, EXPECTED_SCHEMA, "", errors)
    return tuple(sorted(set(errors)))


@dataclass(frozen=True)
class ProfileRelation:
    """One frozen normative relation and its reviewable boundary behavior."""

    name: str
    source_anchor: str
    operands: tuple[str, ...]
    operator: str
    evaluate: Callable[[dict], bool]
    boundary_path: str
    boundary_value: Callable[[dict], int]
    boundary_expected: tuple[bool, bool, bool]


def _relation(
    name: str,
    operands: tuple[str, ...],
    operator: str,
    evaluate: Callable[[dict], bool],
    boundary_path: str,
    boundary_value: Callable[[dict], int],
    boundary_expected: tuple[bool, bool, bool],
    source_anchor: str = "sec:parameters",
) -> ProfileRelation:
    return ProfileRelation(
        name,
        source_anchor,
        operands,
        operator,
        evaluate,
        boundary_path,
        boundary_value,
        boundary_expected,
    )


def _window_seconds(profile: dict) -> int:
    return checked_mul_u256(
        _at(profile, "geometry.windowSlots"),
        _at(profile, "geometry.slotSeconds"),
    )


def _liability_residence(profile: dict) -> int:
    seconds = _sum_u256(
        _at(profile, "builder.evidenceDelaySeconds"),
        _at(profile, "builder.reorgMarginSeconds"),
    )
    evidence_windows = ceil_div_u256(seconds, _window_seconds(profile))
    return _sum_u256(
        _at(profile, "geometry.maximumTrancheAheadWindows"),
        1,
        evidence_windows,
        2,
    )


def _snapshot_required_slots(profile: dict) -> int:
    finality_slots = checked_mul_u256(
        _at(profile, "geometry.finalityEpochs"),
        _at(profile, "geometry.l1EpochSlots"),
    )
    advertised_schedule_slots = checked_add_u256(
        _at(profile, "geometry.lookaheadSlots"),
        _at(profile, "geometry.windowSlots"),
    )
    advertised_schedule_seconds = checked_mul_u256(
        advertised_schedule_slots,
        _at(profile, "geometry.slotSeconds"),
    )
    schedule_l1_slots = ceil_div_u256(
        advertised_schedule_seconds,
        _at(profile, "geometry.l1SlotSeconds"),
    )
    return _sum_u256(
        _at(profile, "geometry.carrierScanSlots"),
        finality_slots,
        _at(profile, "geometry.sealMarginSlots"),
        schedule_l1_slots,
    )


def _snapshot_required_epochs(profile: dict) -> int:
    return ceil_div_u256(
        _snapshot_required_slots(profile),
        _at(profile, "geometry.l1EpochSlots"),
    )


def _candidate_windows_for_gap(profile: dict) -> int:
    skew_slots = ceil_div_u256(
        _at(profile, "recovery.clockSkewSeconds"),
        _at(profile, "geometry.slotSeconds"),
    )
    total_slots = checked_add_u256(
        _at(profile, "geometry.maximumParentGapSlots"), skew_slots
    )
    return ceil_div_u256(total_slots, _at(profile, "geometry.windowSlots"))


def _recovery_lower_bound(profile: dict) -> int:
    return _sum_u256(
        _at(profile, "recovery.finalLagSeconds"),
        _at(profile, "recovery.tipLagSeconds"),
        _at(profile, "builder.reorgMarginSeconds"),
    )


def _eip2935_horizon(profile: dict) -> int:
    window_seconds = _window_seconds(profile)
    replay_seconds = _sum_u256(
        _at(profile, "recovery.settlementWindowSeconds"),
        _at(profile, "recovery.clockSkewSeconds"),
        window_seconds,
        _at(profile, "builder.evidenceDelaySeconds"),
        _at(profile, "builder.reorgMarginSeconds"),
    )
    return _sum_u256(
        _at(profile, "geometry.maximumArmAgeBlocks"),
        ceil_div_u256(replay_seconds, _at(profile, "geometry.l1SlotSeconds")),
        2,
    )


def _schedule_ring_requirement(profile: dict) -> int:
    retention_seconds = _sum_u256(
        _at(profile, "recovery.settlementWindowSeconds"),
        _at(profile, "recovery.finalLagSeconds"),
        _at(profile, "recovery.tipLagSeconds"),
        _at(profile, "builder.reorgMarginSeconds"),
        _at(profile, "builder.evidenceDelaySeconds"),
    )
    window_seconds = _window_seconds(profile)
    return _sum_u256(
        _at(profile, "geometry.maximumEarlySealWindows"),
        _at(profile, "geometry.maximumCandidateWindows"),
        ceil_div_u256(retention_seconds, window_seconds),
        2,
    )


def _sla_tail(profile: dict) -> int:
    slash = _at(profile, "seat.slashLagSeconds")
    recovery = _at(profile, "seat.recoveryLagSeconds")
    if slash < recovery:
        raise ValueError("negative SLA tail")
    return slash - recovery


def _seat_runway_requirement(profile: dict) -> int:
    return _sum_u256(
        _at(profile, "seat.minimumPrimaryTenureSeconds"),
        _at(profile, "seat.handoverExecutionBufferSeconds"),
        _sla_tail(profile),
    )


def _seat_collusion_requirement(profile: dict) -> int:
    service = checked_mul_u256(
        _at(profile, "seat.maximumAskWeiPerSecond"),
        _at(profile, "seat.minimumPrimaryTenureSeconds"),
    )
    return _sum_u256(
        service,
        _at(profile, "seat.maximumAvoidedServiceCostWei"),
        _at(profile, "seat.collusionSafetyMarginWei"),
    )


PROFILE_RELATIONS = (
    _relation(
        "standby-lease-tenure-handover",
        (
            "seat.maximumStandbyLeaseSeconds",
            "seat.minimumStandbyTenureSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        lambda p: _at(p, "seat.maximumStandbyLeaseSeconds")
        >= _sum_u256(
            _at(p, "seat.minimumStandbyTenureSeconds"),
            _at(p, "seat.handoverDelaySeconds"),
            _at(p, "seat.stageGraceSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        "seat.maximumStandbyLeaseSeconds",
        lambda p: _sum_u256(
            _at(p, "seat.minimumStandbyTenureSeconds"),
            _at(p, "seat.handoverDelaySeconds"),
            _at(p, "seat.stageGraceSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "builder-bond-product",
        ("builder.maximumBondAtomic", "geometry.maximumAssignedSlots"),
        "<",
        lambda p: checked_mul_u256(
            _at(p, "builder.maximumBondAtomic"),
            checked_add_u256(_at(p, "geometry.maximumAssignedSlots"), 1),
        )
        < (1 << 256),
        "builder.maximumBondAtomic",
        lambda p: UINT256_MAX
        // checked_add_u256(_at(p, "geometry.maximumAssignedSlots"), 1),
        (True, True, False),
    ),
    _relation(
        "builder-bond-uint192-cap",
        ("builder.maximumBondAtomic",),
        "<=",
        lambda p: _at(p, "builder.maximumBondAtomic") <= (1 << 192) - 1,
        "builder.maximumBondAtomic",
        lambda _p: (1 << 192) - 1,
        (True, True, False),
    ),
    _relation(
        "builder-reporter-reward-uint192-cap",
        ("builder.reporterRewardCapAtomic",),
        "<=",
        lambda p: _at(p, "builder.reporterRewardCapAtomic") <= (1 << 192) - 1,
        "builder.reporterRewardCapAtomic",
        lambda _p: (1 << 192) - 1,
        (True, True, False),
    ),
    _relation(
        "builder-reporter-reward-sink-floor",
        (
            "builder.reporterRewardCapAtomic",
            "builder.leasePerWindowAtomic",
        ),
        "5* <=",
        lambda p: checked_mul_u256(
            _at(p, "builder.reporterRewardCapAtomic"), 5,
        ) <= _at(p, "builder.leasePerWindowAtomic"),
        "builder.reporterRewardCapAtomic",
        lambda p: _at(p, "builder.leasePerWindowAtomic") // 5,
        (True, True, False),
    ),
    _relation(
        "liability-residence",
        (
            "geometry.maximumTrancheAheadWindows",
            "builder.evidenceDelaySeconds",
            "builder.reorgMarginSeconds",
            "geometry.windowSlots",
            "geometry.slotSeconds",
            "geometry.maximumLiveWindows",
        ),
        "<",
        lambda p: _liability_residence(p) < _at(p, "geometry.maximumLiveWindows"),
        "geometry.maximumLiveWindows",
        _liability_residence,
        (False, False, True),
    ),
    _relation(
        "liability-generation-capacity",
        (
            "geometry.maximumLiabilityGenerations",
            "geometry.maximumGenerationMovesPerWindow",
            "geometry.maximumLiveWindows",
        ),
        ">=",
        lambda p: _at(p, "geometry.maximumLiabilityGenerations")
        >= checked_mul_u256(
            _at(p, "geometry.maximumGenerationMovesPerWindow"),
            _at(p, "geometry.maximumLiveWindows"),
        ),
        "geometry.maximumLiabilityGenerations",
        lambda p: checked_mul_u256(
            _at(p, "geometry.maximumGenerationMovesPerWindow"),
            _at(p, "geometry.maximumLiveWindows"),
        ),
        (False, True, True),
    ),
    _relation(
        "snapshot-finality-seal-lookahead",
        (
            "geometry.snapshotEpochs",
            "geometry.l1EpochSlots",
            "geometry.carrierScanSlots",
            "geometry.finalityEpochs",
            "geometry.sealMarginSlots",
            "geometry.lookaheadSlots",
            "geometry.windowSlots",
            "geometry.slotSeconds",
            "geometry.l1SlotSeconds",
        ),
        ">=",
        lambda p: _at(p, "geometry.snapshotEpochs")
        >= _snapshot_required_epochs(p),
        "geometry.snapshotEpochs",
        _snapshot_required_epochs,
        (False, True, True),
    ),
    _relation(
        "lookahead-window-slack",
        ("geometry.lookaheadSlots", "geometry.windowSlots"),
        ">=",
        lambda p: _at(p, "geometry.lookaheadSlots")
        >= checked_mul_u256(_at(p, "geometry.windowSlots"), 2),
        "geometry.lookaheadSlots",
        lambda p: checked_mul_u256(_at(p, "geometry.windowSlots"), 2),
        (False, True, True),
    ),
    _relation(
        "parent-gap-final-lag-identity",
        (
            "geometry.maximumParentGapSlots",
            "geometry.slotSeconds",
            "recovery.finalLagSeconds",
        ),
        "==",
        lambda p: checked_mul_u256(
            _at(p, "geometry.maximumParentGapSlots"),
            _at(p, "geometry.slotSeconds"),
        )
        == _at(p, "recovery.finalLagSeconds"),
        "geometry.maximumParentGapSlots",
        lambda p: _at(p, "recovery.finalLagSeconds")
        // _at(p, "geometry.slotSeconds"),
        (False, True, False),
    ),
    _relation(
        "parent-gap-candidate-cap",
        (
            "geometry.maximumParentGapSlots",
            "recovery.clockSkewSeconds",
            "geometry.slotSeconds",
            "geometry.windowSlots",
            "geometry.maximumCandidateWindows",
        ),
        "<=",
        lambda p: _candidate_windows_for_gap(p)
        <= _at(p, "geometry.maximumCandidateWindows"),
        "geometry.maximumCandidateWindows",
        _candidate_windows_for_gap,
        (False, True, True),
    ),
    _relation(
        "candidate-block-window-cap",
        (
            "geometry.maximumCandidateBlocks",
            "geometry.maximumCandidateWindows",
            "geometry.windowSlots",
        ),
        "<=",
        lambda p: _at(p, "geometry.maximumCandidateBlocks")
        <= checked_mul_u256(
            _at(p, "geometry.maximumCandidateWindows"),
            _at(p, "geometry.windowSlots"),
        ),
        "geometry.maximumCandidateWindows",
        lambda p: ceil_div_u256(
            _at(p, "geometry.maximumCandidateBlocks"),
            _at(p, "geometry.windowSlots"),
        ),
        (False, True, True),
    ),
    _relation(
        "tip-inclusion-skew",
        (
            "recovery.tipLagSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.clockSkewSeconds",
        ),
        ">=",
        lambda p: _at(p, "recovery.tipLagSeconds")
        >= _sum_u256(
            _at(p, "recovery.submissionInclusionSeconds"),
            _at(p, "recovery.clockSkewSeconds"),
        ),
        "recovery.tipLagSeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.submissionInclusionSeconds"),
            _at(p, "recovery.clockSkewSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "final-lag-recovery-geometry",
        (
            "recovery.finalLagSeconds",
            "recovery.activationInclusionSeconds",
            "recovery.escapeOffsetSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.clockSkewSeconds",
        ),
        ">=",
        lambda p: _at(p, "recovery.finalLagSeconds")
        >= _sum_u256(
            _at(p, "recovery.activationInclusionSeconds"),
            _at(p, "recovery.escapeOffsetSeconds"),
            _at(p, "recovery.submissionInclusionSeconds"),
            _at(p, "recovery.clockSkewSeconds"),
        ),
        "recovery.finalLagSeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.activationInclusionSeconds"),
            _at(p, "recovery.escapeOffsetSeconds"),
            _at(p, "recovery.submissionInclusionSeconds"),
            _at(p, "recovery.clockSkewSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "escape-offset-depth-proof-margin",
        (
            "recovery.escapeOffsetSeconds",
            "recovery.depthTimeMaxSeconds",
            "recovery.proofTimeMaxSeconds",
            "recovery.proofMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "recovery.escapeOffsetSeconds")
        >= _sum_u256(
            _at(p, "recovery.depthTimeMaxSeconds"),
            _at(p, "recovery.proofTimeMaxSeconds"),
            _at(p, "recovery.proofMarginSeconds"),
        ),
        "recovery.escapeOffsetSeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.depthTimeMaxSeconds"),
            _at(p, "recovery.proofTimeMaxSeconds"),
            _at(p, "recovery.proofMarginSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "force-delay-settlement-inclusion",
        (
            "recovery.forceDelaySeconds",
            "recovery.settlementWindowSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        lambda p: _at(p, "recovery.forceDelaySeconds")
        >= _sum_u256(
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        "recovery.forceDelaySeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "forced-item-count-prefix",
        ("forcedEnvelope.maximumPrefixItems",),
        ">=",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixItems") >= 1,
        "forcedEnvelope.maximumPrefixItems",
        lambda _p: 1,
        (False, True, True),
    ),
    _relation(
        "forced-prefix-count-candidate",
        (
            "forcedEnvelope.maximumPrefixItems",
            "geometry.maximumCandidateForcedItems",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixItems")
        <= _at(p, "geometry.maximumCandidateForcedItems"),
        "forcedEnvelope.maximumPrefixItems",
        lambda p: _at(p, "geometry.maximumCandidateForcedItems"),
        (True, True, False),
    ),
    _relation(
        "forced-prefix-queue-capacity",
        (
            "forcedEnvelope.maximumPrefixItems",
            "forcedEnvelope.maximumQueueCount",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixItems")
        <= _at(p, "forcedEnvelope.maximumQueueCount"),
        "forcedEnvelope.maximumPrefixItems",
        lambda p: _at(p, "forcedEnvelope.maximumQueueCount"),
        (True, True, False),
    ),
    _relation(
        "forced-range-proof-boundary",
        (
            "forcedEnvelope.maximumRangeProofHashes",
            "geometry.maximumCandidateForcedItems",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumRangeProofHashes")
        <= checked_add_u256(_at(p, "geometry.maximumCandidateForcedItems"), 1),
        "forcedEnvelope.maximumRangeProofHashes",
        lambda p: checked_add_u256(
            _at(p, "geometry.maximumCandidateForcedItems"), 1
        ),
        (True, True, False),
    ),
    _relation(
        "forced-item-bytes-prefix",
        (
            "forcedEnvelope.maximumItemBytes",
            "forcedEnvelope.maximumPrefixBytes",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumItemBytes")
        <= _at(p, "forcedEnvelope.maximumPrefixBytes"),
        "forcedEnvelope.maximumItemBytes",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixBytes"),
        (True, True, False),
    ),
    _relation(
        "forced-prefix-bytes-candidate",
        (
            "forcedEnvelope.maximumPrefixBytes",
            "geometry.maximumCandidateForcedBytes",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixBytes")
        <= _at(p, "geometry.maximumCandidateForcedBytes"),
        "forcedEnvelope.maximumPrefixBytes",
        lambda p: _at(p, "geometry.maximumCandidateForcedBytes"),
        (True, True, False),
    ),
    _relation(
        "forced-item-gas-prefix",
        (
            "forcedEnvelope.maximumItemAccountedGas",
            "forcedEnvelope.maximumPrefixAccountedGas",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumItemAccountedGas")
        <= _at(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        (True, True, False),
    ),
    _relation(
        "forced-minimum-accounted-gas-cap",
        (
            "gasProfile.minimumForceAccountedGas",
            "forcedEnvelope.maximumItemAccountedGas",
        ),
        "<=",
        lambda p: _at(p, "gasProfile.minimumForceAccountedGas")
        <= _at(p, "forcedEnvelope.maximumItemAccountedGas"),
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: _at(p, "gasProfile.minimumForceAccountedGas"),
        (False, True, True),
    ),
    _relation(
        "activation-forced-head-capacity",
        (
            "forcedEnvelope.maximumItemAccountedGas",
            "gasProfile.activationForcedGas",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumItemAccountedGas")
        <= _at(p, "gasProfile.activationForcedGas"),
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: _at(p, "gasProfile.activationForcedGas"),
        (True, True, False),
    ),
    _relation(
        "forced-prefix-gas-candidate",
        (
            "forcedEnvelope.maximumPrefixAccountedGas",
            "geometry.maximumCandidateForcedGas",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixAccountedGas")
        <= _at(p, "geometry.maximumCandidateForcedGas"),
        "forcedEnvelope.maximumPrefixAccountedGas",
        lambda p: _at(p, "geometry.maximumCandidateForcedGas"),
        (True, True, False),
    ),
    _relation(
        "forced-queue-count-u64",
        ("forcedEnvelope.maximumQueueCount",),
        "==",
        lambda p: _at(p, "forcedEnvelope.maximumQueueCount") == UINT64_MAX,
        "forcedEnvelope.maximumQueueCount",
        lambda _p: UINT64_MAX,
        (False, True, False),
    ),
    _relation(
        "forced-queue-prefix-u256",
        (
            "forcedEnvelope.maximumQueueCount",
            "forcedEnvelope.maximumAcceptedFeeWei",
        ),
        "<=",
        lambda p: _at(p, "forcedEnvelope.maximumAcceptedFeeWei")
        <= UINT256_MAX // _at(p, "forcedEnvelope.maximumQueueCount"),
        "forcedEnvelope.maximumAcceptedFeeWei",
        lambda p: UINT256_MAX // _at(p, "forcedEnvelope.maximumQueueCount"),
        (True, True, False),
    ),
    _relation(
        "terminal-count-u64",
        ("bridge.maximumTerminalCount",),
        "==",
        lambda p: _at(p, "bridge.maximumTerminalCount") == UINT64_MAX,
        "bridge.maximumTerminalCount",
        lambda _p: UINT64_MAX,
        (False, True, False),
    ),
    _relation(
        "refund-erc721-word-cap",
        ("bridge.refundErc721Ids", "bridge.refundCapsuleWords"),
        "<=",
        lambda p: _at(p, "bridge.refundErc721Ids")
        <= _at(p, "bridge.refundCapsuleWords"),
        "bridge.refundErc721Ids",
        lambda p: _at(p, "bridge.refundCapsuleWords"),
        (True, True, False),
    ),
    _relation(
        "refund-erc1155-word-cap",
        ("bridge.refundErc1155Pairs", "bridge.refundCapsuleWords"),
        "<=",
        lambda p: checked_mul_u256(_at(p, "bridge.refundErc1155Pairs"), 2)
        <= _at(p, "bridge.refundCapsuleWords"),
        "bridge.refundErc1155Pairs",
        lambda p: _at(p, "bridge.refundCapsuleWords") // 2,
        (True, True, False),
    ),
    _relation(
        "kind0-validity-lower-bound",
        (
            "forcedEnvelope.maximumValiditySeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "forcedEnvelope.maximumValiditySeconds")
        >= _recovery_lower_bound(p),
        "forcedEnvelope.maximumValiditySeconds",
        _recovery_lower_bound,
        (False, True, True),
    ),
    _relation(
        "kind1-enqueue-lower-bound",
        (
            "bridge.maximumEnqueueDelaySeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "bridge.maximumEnqueueDelaySeconds")
        >= _recovery_lower_bound(p),
        "bridge.maximumEnqueueDelaySeconds",
        _recovery_lower_bound,
        (False, True, True),
    ),
    _relation(
        "bridge-process-ttl-lower-bound",
        (
            "bridge.processTtlSeconds",
            "bridge.maximumEnqueueDelaySeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "bridge.processTtlSeconds")
        >= _sum_u256(
            _at(p, "bridge.maximumEnqueueDelaySeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        "bridge.processTtlSeconds",
        lambda p: _sum_u256(
            _at(p, "bridge.maximumEnqueueDelaySeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "support-finality-reorg-depth",
        (
            "bridge.supportFinalityBlocks",
            "recovery.l1FinalityBlocks",
            "builder.reorgMarginSeconds",
            "geometry.l1SlotSeconds",
        ),
        "==",
        lambda p: _at(p, "bridge.supportFinalityBlocks")
        == _sum_u256(
            _at(p, "recovery.l1FinalityBlocks"),
            ceil_div_u256(
                _at(p, "builder.reorgMarginSeconds"),
                _at(p, "geometry.l1SlotSeconds"),
            ),
        ),
        "bridge.supportFinalityBlocks",
        lambda p: _sum_u256(
            _at(p, "recovery.l1FinalityBlocks"),
            ceil_div_u256(
                _at(p, "builder.reorgMarginSeconds"),
                _at(p, "geometry.l1SlotSeconds"),
            ),
        ),
        (False, True, False),
    ),
    _relation(
        "data-ttl-recovery-lower-bound",
        (
            "dataSession.ttlSeconds",
            "recovery.settlementWindowSeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        lambda p: _at(p, "dataSession.ttlSeconds")
        >= _sum_u256(
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "recovery.finalLagSeconds"),
            _at(p, "recovery.tipLagSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        "dataSession.ttlSeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "recovery.finalLagSeconds"),
            _at(p, "recovery.tipLagSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "data-session-open-expiry-horizon",
        (
            "dataSession.ttlSeconds",
            "recovery.proofTimeMaxSeconds",
            "recovery.settlementWindowSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "dataSession.ttlSeconds")
        >= _sum_u256(
            _at(p, "recovery.proofTimeMaxSeconds"),
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        "dataSession.ttlSeconds",
        lambda p: _sum_u256(
            _at(p, "recovery.proofTimeMaxSeconds"),
            _at(p, "recovery.settlementWindowSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "data-refund-claim-horizon",
        (
            "dataSession.refundClaimWindowSeconds",
            "seat.maximumInclusionSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        lambda p: _at(p, "dataSession.refundClaimWindowSeconds")
        >= _sum_u256(
            _at(p, "seat.maximumInclusionSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        "dataSession.refundClaimWindowSeconds",
        lambda p: _sum_u256(
            _at(p, "seat.maximumInclusionSeconds"),
            _at(p, "builder.reorgMarginSeconds"),
        ),
        (False, True, True),
    ),
    _relation(
        "reward-claim-window-profile-word",
        (
            "rewards.claimWindowSeconds",
            "dataSession.refundClaimWindowSeconds",
        ),
        "==",
        lambda p: _at(p, "rewards.claimWindowSeconds")
        == _at(p, "dataSession.refundClaimWindowSeconds"),
        "rewards.claimWindowSeconds",
        lambda p: _at(p, "dataSession.refundClaimWindowSeconds"),
        (False, True, False),
    ),
    _relation(
        "canonical-history-reorg-capacity",
        (
            "geometry.canonicalHistoryCells",
            "seat.maximumInclusionSeconds",
            "builder.reorgMarginSeconds",
            "geometry.l1SlotSeconds",
        ),
        ">",
        lambda p: _at(p, "geometry.canonicalHistoryCells")
        > _sum_u256(
            ceil_div_u256(
                _sum_u256(
                    _at(p, "seat.maximumInclusionSeconds"),
                    _at(p, "builder.reorgMarginSeconds"),
                ),
                _at(p, "geometry.l1SlotSeconds"),
            ),
            2,
        ),
        "geometry.canonicalHistoryCells",
        lambda p: _sum_u256(
            ceil_div_u256(
                _sum_u256(
                    _at(p, "seat.maximumInclusionSeconds"),
                    _at(p, "builder.reorgMarginSeconds"),
                ),
                _at(p, "geometry.l1SlotSeconds"),
            ),
            2,
        ),
        (False, False, True),
    ),
    _relation(
        "eip2935-replay-horizon",
        (
            "geometry.eip2935HistoryBlocks",
            "geometry.maximumArmAgeBlocks",
            "recovery.settlementWindowSeconds",
            "recovery.clockSkewSeconds",
            "geometry.windowSlots",
            "geometry.slotSeconds",
            "builder.evidenceDelaySeconds",
            "builder.reorgMarginSeconds",
            "geometry.l1SlotSeconds",
        ),
        ">",
        lambda p: _at(p, "geometry.eip2935HistoryBlocks")
        > _eip2935_horizon(p),
        "geometry.eip2935HistoryBlocks",
        _eip2935_horizon,
        (False, False, True),
    ),
    _relation(
        "schedule-ring-capacity",
        (
            "geometry.maximumLiveWindows",
            "geometry.maximumEarlySealWindows",
            "geometry.maximumCandidateWindows",
            "recovery.settlementWindowSeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
            "builder.evidenceDelaySeconds",
            "geometry.windowSlots",
            "geometry.slotSeconds",
        ),
        ">=",
        lambda p: _at(p, "geometry.maximumLiveWindows")
        >= _schedule_ring_requirement(p),
        "geometry.maximumLiveWindows",
        _schedule_ring_requirement,
        (False, True, True),
    ),
    _relation(
        "data-session-capacity",
        (
            "dataSession.maximumLiveSessions",
            "geometry.maximumCandidateSessions",
        ),
        ">=",
        lambda p: _at(p, "dataSession.maximumLiveSessions")
        >= _at(p, "geometry.maximumCandidateSessions"),
        "dataSession.maximumLiveSessions",
        lambda p: _at(p, "geometry.maximumCandidateSessions"),
        (False, True, True),
    ),
    _relation(
        "session-record-capacity",
        (
            "dataSession.maximumRecordsPerSession",
            "geometry.maximumCandidateRecords",
        ),
        ">=",
        lambda p: _at(p, "dataSession.maximumRecordsPerSession")
        >= _at(p, "geometry.maximumCandidateRecords"),
        "dataSession.maximumRecordsPerSession",
        lambda p: _at(p, "geometry.maximumCandidateRecords"),
        (False, True, True),
    ),
    _relation(
        "session-ring-gc-capacity",
        ("dataSession.maximumLiveSessions", "dataSession.maximumGcSteps"),
        ">=",
        lambda p: _at(p, "dataSession.maximumLiveSessions")
        >= _at(p, "dataSession.maximumGcSteps"),
        "dataSession.maximumLiveSessions",
        lambda p: _at(p, "dataSession.maximumGcSteps"),
        (False, True, True),
    ),
    _relation(
        "session-bond-liability-u256",
        (
            "dataSession.maximumLiveSessions",
            "dataSession.refundableBondWei",
        ),
        "<=",
        lambda p: _at(p, "dataSession.refundableBondWei")
        <= UINT256_MAX // _at(p, "dataSession.maximumLiveSessions"),
        "dataSession.refundableBondWei",
        lambda p: UINT256_MAX // _at(p, "dataSession.maximumLiveSessions"),
        (True, True, False),
    ),
    _relation(
        "session-open-value-u256",
        (
            "dataSession.refundableBondWei",
            "dataSession.baseRentWei",
        ),
        "<=",
        lambda p: _at(p, "dataSession.baseRentWei")
        <= UINT256_MAX - _at(p, "dataSession.refundableBondWei"),
        "dataSession.baseRentWei",
        lambda p: UINT256_MAX - _at(p, "dataSession.refundableBondWei"),
        (True, True, False),
    ),
    _relation(
        "session-byte-rent-u256",
        (
            "dataSession.maximumRecordsPerSession",
            "dataSession.rentPerPublishedByteWei",
        ),
        "<=",
        lambda p: _at(p, "dataSession.rentPerPublishedByteWei")
        <= UINT256_MAX
        // checked_mul_u256(
            _at(p, "dataSession.maximumRecordsPerSession"),
            DATA_BYTES_PER_BLOB,
        ),
        "dataSession.rentPerPublishedByteWei",
        lambda p: UINT256_MAX
        // checked_mul_u256(
            _at(p, "dataSession.maximumRecordsPerSession"),
            DATA_BYTES_PER_BLOB,
        ),
        (True, True, False),
    ),
    _relation(
        "seat-book-capacity",
        (
            "geometry.bookSize",
            "geometry.seatCount",
            "geometry.pendingCount",
        ),
        "==",
        lambda p: _at(p, "geometry.bookSize")
        == checked_add_u256(
            _at(p, "geometry.seatCount"),
            _at(p, "geometry.pendingCount"),
        ),
        "geometry.bookSize",
        lambda p: checked_add_u256(
            _at(p, "geometry.seatCount"),
            _at(p, "geometry.pendingCount"),
        ),
        (False, True, False),
        "sec:economics",
    ),
    _relation(
        "slash-lag-recovery-order",
        ("seat.slashLagSeconds", "seat.recoveryLagSeconds"),
        ">",
        lambda p: _at(p, "seat.slashLagSeconds")
        > _at(p, "seat.recoveryLagSeconds"),
        "seat.slashLagSeconds",
        lambda p: _at(p, "seat.recoveryLagSeconds"),
        (False, False, True),
        "sec:economics",
    ),
    _relation(
        "premium-claim-reorg-stability",
        ("seat.premiumClaimDelaySeconds", "seat.reorgStabilitySeconds"),
        ">=",
        lambda p: _at(p, "seat.premiumClaimDelaySeconds")
        >= _at(p, "seat.reorgStabilitySeconds"),
        "seat.premiumClaimDelaySeconds",
        lambda p: _at(p, "seat.reorgStabilitySeconds"),
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "seat-runway-primary-handover-sla",
        (
            "seat.seatRunwaySeconds",
            "seat.minimumPrimaryTenureSeconds",
            "seat.handoverExecutionBufferSeconds",
            "seat.slashLagSeconds",
            "seat.recoveryLagSeconds",
        ),
        ">=",
        lambda p: _at(p, "seat.seatRunwaySeconds")
        >= _seat_runway_requirement(p),
        "seat.seatRunwaySeconds",
        _seat_runway_requirement,
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "seat-maximum-reserve-u256",
        (
            "seat.maximumAskWeiPerSecond",
            "seat.seatRunwaySeconds",
        ),
        "<=",
        lambda p: checked_mul_u256(
            _at(p, "seat.maximumAskWeiPerSecond"),
            _at(p, "seat.seatRunwaySeconds"),
        )
        <= UINT256_MAX,
        "seat.maximumAskWeiPerSecond",
        lambda p: UINT256_MAX // _at(p, "seat.seatRunwaySeconds"),
        (True, True, False),
        "sec:economics",
    ),
    _relation(
        "handover-buffer-delay-grace-inclusion",
        (
            "seat.handoverExecutionBufferSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        lambda p: _at(p, "seat.handoverExecutionBufferSeconds")
        >= _sum_u256(
            _at(p, "seat.handoverDelaySeconds"),
            _at(p, "seat.stageGraceSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        "seat.handoverExecutionBufferSeconds",
        lambda p: _sum_u256(
            _at(p, "seat.handoverDelaySeconds"),
            _at(p, "seat.stageGraceSeconds"),
            _at(p, "seat.maximumInclusionSeconds"),
        ),
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "sla-bond-claim-tail",
        (
            "seat.slaBondWei",
            "seat.maximumAskWeiPerSecond",
            "seat.premiumClaimDelaySeconds",
        ),
        ">=",
        lambda p: _at(p, "seat.slaBondWei")
        >= checked_mul_u256(
            _at(p, "seat.maximumAskWeiPerSecond"),
            _at(p, "seat.premiumClaimDelaySeconds"),
        ),
        "seat.slaBondWei",
        lambda p: checked_mul_u256(
            _at(p, "seat.maximumAskWeiPerSecond"),
            _at(p, "seat.premiumClaimDelaySeconds"),
        ),
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "sla-bond-collusion",
        (
            "seat.slaBondWei",
            "seat.maximumAskWeiPerSecond",
            "seat.minimumPrimaryTenureSeconds",
            "seat.maximumAvoidedServiceCostWei",
            "seat.collusionSafetyMarginWei",
        ),
        ">=",
        lambda p: _at(p, "seat.slaBondWei") >= _seat_collusion_requirement(p),
        "seat.slaBondWei",
        _seat_collusion_requirement,
        (False, True, True),
        "sec:economics",
    ),
    _relation(
        "steady-forced-profile-identity",
        (
            "gasProfile.steadyForcedGas",
            "forcedEnvelope.maximumPrefixAccountedGas",
        ),
        "==",
        lambda p: _at(p, "gasProfile.steadyForcedGas")
        == _at(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        "gasProfile.steadyForcedGas",
        lambda p: _at(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        (False, True, False),
    ),
    _relation(
        "steady-gas-envelope",
        (
            "gasProfile.l2BlockGas",
            "gasProfile.steadyAnchorGas",
            "gasProfile.steadyForcedGas",
            "gasProfile.systemMarginGas",
        ),
        "<=",
        lambda p: _sum_u256(
            _at(p, "gasProfile.steadyAnchorGas"),
            _at(p, "gasProfile.steadyForcedGas"),
            _at(p, "gasProfile.systemMarginGas"),
        )
        <= _at(p, "gasProfile.l2BlockGas"),
        "gasProfile.l2BlockGas",
        lambda p: _sum_u256(
            _at(p, "gasProfile.steadyAnchorGas"),
            _at(p, "gasProfile.steadyForcedGas"),
            _at(p, "gasProfile.systemMarginGas"),
        ),
        (False, True, True),
    ),
    _relation(
        "activation-gas-envelope",
        (
            "gasProfile.l2BlockGas",
            "gasProfile.activationAnchorGas",
            "gasProfile.activationForcedGas",
            "gasProfile.systemMarginGas",
        ),
        "<=",
        lambda p: _sum_u256(
            _at(p, "gasProfile.activationAnchorGas"),
            _at(p, "gasProfile.activationForcedGas"),
            _at(p, "gasProfile.systemMarginGas"),
        )
        <= _at(p, "gasProfile.l2BlockGas"),
        "gasProfile.l2BlockGas",
        lambda p: _sum_u256(
            _at(p, "gasProfile.activationAnchorGas"),
            _at(p, "gasProfile.activationForcedGas"),
            _at(p, "gasProfile.systemMarginGas"),
        ),
        (False, True, True),
    ),
    _relation(
        "registration-proof-total-nodes",
        (
            "bridge.registrationProofMaximumNodesPerPath",
            "bridge.registrationProofPathCount",
            "bridge.registrationProofMaximumTotalNodes",
        ),
        "==",
        lambda p: checked_mul_u256(
            _at(p, "bridge.registrationProofMaximumNodesPerPath"),
            _at(p, "bridge.registrationProofPathCount"),
        )
        == _at(p, "bridge.registrationProofMaximumTotalNodes"),
        "bridge.registrationProofMaximumTotalNodes",
        lambda p: checked_mul_u256(
            _at(p, "bridge.registrationProofMaximumNodesPerPath"),
            _at(p, "bridge.registrationProofPathCount"),
        ),
        (False, True, False),
    ),
    _relation(
        "registration-proof-byte-capacity",
        (
            "bridge.registrationProofMaximumTotalNodes",
            "bridge.registrationProofMaximumNodeBytes",
            "bridge.registrationProofMaximumBytes",
        ),
        "<=",
        lambda p: checked_mul_u256(
            _at(p, "bridge.registrationProofMaximumTotalNodes"),
            _at(p, "bridge.registrationProofMaximumNodeBytes"),
        )
        <= _at(p, "bridge.registrationProofMaximumBytes"),
        "bridge.registrationProofMaximumBytes",
        lambda p: checked_mul_u256(
            _at(p, "bridge.registrationProofMaximumTotalNodes"),
            _at(p, "bridge.registrationProofMaximumNodeBytes"),
        ),
        (False, True, True),
    ),
)


_SINK_ADDRESS_PATHS = tuple(
    f"sinks.{sink_name}.address" for sink_name in EXPECTED_SCHEMA["sinks"]
)


_IDENTITY_PATHS = (
    "profileId",
    "measurementCommit",
    "assets.builderLease.address",
    "assets.builderLease.runtimeHash",
) + _SINK_ADDRESS_PATHS


# EconomicProfileV2 also records version-fixed executable geometry.  These
# leaves are not deployment-time calibration knobs: the corresponding V2
# implementations compile the same literals into their bounded loops, rings,
# proof widths, and retention horizons.  Release tooling must therefore reject
# a freshly re-hashed JSON object that advertises different capacity.
EXECUTABLE_CONSTANTS_V2 = {
    "geometry.slotSeconds": 1,
    "geometry.windowSlots": 384,
    "geometry.l1SlotSeconds": 12,
    "geometry.l1EpochSlots": 32,
    "geometry.maximumBuilders": 64,
    "geometry.maximumAssignedSlots": 76,
    "geometry.entryDelayWindows": 8,
    "geometry.maximumLiveWindows": 268,
    "geometry.maximumTrancheAheadWindows": 16,
    "geometry.maximumGenerationMovesPerWindow": 4,
    "geometry.maximumLiabilityGenerations": 1_072,
    "geometry.snapshotEpochs": 8,
    "geometry.finalityEpochs": 2,
    "geometry.carrierScanSlots": 64,
    "geometry.sealMarginSlots": 32,
    "geometry.lookaheadSlots": 768,
    "geometry.maximumCandidateBlocks": 4_096,
    "geometry.maximumCandidateWindows": 12,
    "geometry.maximumCandidateAnchors": 1,
    "geometry.maximumCandidateSessions": 16,
    "geometry.maximumCandidateRecords": 2_100,
    "geometry.maximumCandidateForcedItems": 256,
    "geometry.maximumCandidateForcedBytes": 4_194_304,
    "geometry.maximumCandidateForcedGas": 80_000_000,
    "geometry.maximumEarlySealWindows": 8,
    "geometry.canonicalHistoryCells": 256,
    "geometry.eip2935HistoryBlocks": 8_191,
    "geometry.maximumArmAgeBlocks": 255,
    "geometry.seatCount": 4,
    "geometry.standbyCount": 3,
    "geometry.pendingCount": 4,
    "geometry.bookSize": 8,
    "geometry.maximumRewardClasses": 16,
    "forcedEnvelope.claimWindowSeconds": 86_400,
    "forcedEnvelope.maximumItemBytes": 131_072,
    "forcedEnvelope.maximumItemAccountedGas": 5_000_000,
    "forcedEnvelope.maximumPrefixItems": 64,
    "forcedEnvelope.maximumPrefixBytes": 1_048_576,
    "forcedEnvelope.maximumPrefixAccountedGas": 20_000_000,
    "forcedEnvelope.queueDepth": 64,
    "forcedEnvelope.maximumQueueCount": str(UINT64_MAX),
    "forcedEnvelope.maximumRangeProofHashes": 257,
    "bridge.maximumEnqueueDelaySeconds": 604_800,
    "bridge.processTtlSeconds": 2_592_000,
    "bridge.supportFinalityBlocks": 214,
    "bridge.maximumDomainEntriesPerRelease": 64,
    "bridge.refundCapsuleWords": 256,
    "bridge.refundErc721Ids": 256,
    "bridge.refundErc1155Pairs": 128,
    "bridge.terminalAccumulatorDepth": 64,
    "bridge.maximumTerminalCount": str(UINT64_MAX),
    "bridge.registrationProofMaximumNodesPerPath": 66,
    "bridge.registrationProofPathCount": 2,
    "bridge.registrationProofMaximumTotalNodes": 132,
    "bridge.registrationProofMaximumNodeBytes": 600,
    "bridge.registrationProofMaximumBytes": 80_000,
    "bridge.registrationProofMaximumGas": 8_000_000,
    "rewards.claimWindowSeconds": 86_400,
}


# Every JSON leaf narrowed by either ExecutionProfileV2 or the derived
# BuilderRegistry configuration.  A canonical hash cannot make an out-of-range
# value deployable, so production calibration rejects it before projection.
PROFILE_NARROW_NUMERIC_WIDTHS_V2 = {
    "assets.builderLease.decimals": 8,
    "builder.evidenceDelaySeconds": 64,
    "builder.reorgMarginSeconds": 64,
    "geometry.maximumBuilders": 16,
    "geometry.maximumAssignedSlots": 16,
    "geometry.entryDelayWindows": 16,
    "geometry.maximumLiveWindows": 16,
    "geometry.maximumTrancheAheadWindows": 16,
    "geometry.maximumGenerationMovesPerWindow": 8,
    "geometry.maximumLiabilityGenerations": 16,
    "geometry.maximumParentGapSlots": 64,
    "recovery.settlementWindowSeconds": 64,
    "recovery.tipLagSeconds": 64,
    "recovery.finalLagSeconds": 64,
    "recovery.l1FinalityBlocks": 64,
    "recovery.depthTimeMaxSeconds": 64,
    "recovery.proofTimeMaxSeconds": 64,
    "recovery.activationInclusionSeconds": 64,
    "recovery.submissionInclusionSeconds": 64,
    "recovery.clockSkewSeconds": 64,
    "recovery.escapeOffsetSeconds": 64,
    "recovery.forceDelaySeconds": 64,
    "forcedEnvelope.maximumValiditySeconds": 64,
    "seat.seatRunwaySeconds": 64,
    "seat.minimumPrimaryTenureSeconds": 64,
    "seat.minimumStandbyTenureSeconds": 64,
    "seat.handoverDelaySeconds": 64,
    "seat.stageGraceSeconds": 64,
    "seat.maximumInclusionSeconds": 64,
    "seat.exitDelaySeconds": 64,
    "seat.recoveryLagSeconds": 64,
    "seat.slashLagSeconds": 64,
    "seat.premiumClaimDelaySeconds": 64,
    "seat.reorgStabilitySeconds": 64,
    "seat.releaseChallengeSeconds": 64,
    "seat.evidenceDelaySeconds": 64,
    "seat.quoteMaturitySeconds": 64,
    "seat.quoteMaturityBlocks": 64,
    "seat.maximumStandbyLeaseSeconds": 64,
    "seat.minimumAskImprovementBps": 16,
    "dataSession.blobBaseFeeMultiplierBps": 16,
    "dataSession.ttlSeconds": 64,
    "dataSession.refundClaimWindowSeconds": 64,
    "geometry.slotSeconds": 8,
    "geometry.windowSlots": 16,
    "geometry.seatCount": 8,
    "forcedEnvelope.queueDepth": 8,
    "dataSession.maximumLiveSessions": 16,
    "dataSession.maximumLiveSessionsPerOwner": 16,
    "dataSession.maximumRecordsPerSession": 16,
    "dataSession.maximumGcSteps": 8,
    "dataSession.maximumBlobsPerPost": 8,
    "geometry.canonicalHistoryCells": 16,
    "gasProfile.l2BlockGas": 64,
    "rewards.claimWindowSeconds": 64,
}


def _walk_nullable(
    profile: dict, schema: dict[str, Any], prefix: str = ""
) -> list[str]:
    blockers: list[str] = []
    if not isinstance(profile, dict):
        return blockers
    for key, rule in schema.items():
        if key not in profile:
            continue
        path = f"{prefix}.{key}" if prefix else key
        value = profile[key]
        if isinstance(rule, dict):
            blockers.extend(_walk_nullable(value, rule, path))
        elif rule.nullable and value is None:
            blockers.append(f"{path} must be non-null")
    return blockers


def production_blockers(profile: Any) -> tuple[str, ...]:
    """Return every deterministic blocker to using ``profile`` in production."""

    blockers: set[str] = set()
    for error in validate_schema(profile):
        blockers.add(f"schema error: {error}")
    if not isinstance(profile, dict):
        blockers.add("status must be CALIBRATED")
        return tuple(sorted(blockers))
    if profile.get("status") != "CALIBRATED":
        blockers.add("status must be CALIBRATED")
    blockers.update(_walk_nullable(profile, EXPECTED_SCHEMA))
    try:
        expected_profile_id = "0x" + economic_profile_hash_v2(profile).hex()
        if profile.get("profileId") != expected_profile_id:
            blockers.add("profileId must equal the canonical economic profile hash")
    except (TypeError, ValueError, OverflowError):
        blockers.add("canonical economic profile hash is unavailable")

    for path in _IDENTITY_PATHS:
        try:
            value = get_path(profile, path)
        except (KeyError, IndexError, TypeError, ValueError):
            continue
        if isinstance(value, str) and value.startswith("0x"):
            try:
                if int(value[2:], 16) == 0:
                    blockers.add(f"{path} must be nonzero")
            except ValueError:
                pass

    for path in (
        "assets.builderLease.chainId",
        "assets.nativeCustody.chainId",
    ):
        try:
            value = get_path(profile, path)
        except (KeyError, TypeError):
            continue
        if value == 0:
            blockers.add(f"{path} must be nonzero")
    try:
        builder_chain = get_path(profile, "assets.builderLease.chainId")
        native_chain = get_path(profile, "assets.nativeCustody.chainId")
        if (
            builder_chain is not None
            and native_chain is not None
            and builder_chain != native_chain
        ):
            blockers.add("asset chain IDs must equal")
    except (KeyError, TypeError):
        pass

    try:
        sink_addresses = [get_path(profile, path) for path in _SINK_ADDRESS_PATHS]
        populated_sink_addresses = [
            address for address in sink_addresses if address is not None
        ]
        if len(populated_sink_addresses) != len(set(populated_sink_addresses)):
            blockers.add("sink addresses must be unique")
    except (KeyError, TypeError):
        pass

    try:
        reward_classes = get_path(profile, "rewards.classes")
        if not reward_classes:
            blockers.add("rewards.classes must contain at least one class")
        elif len(reward_classes) > _at(profile, "geometry.maximumRewardClasses"):
            blockers.add("rewards.classes exceeds maximumRewardClasses")
        elif [reward_class.get("classId") for reward_class in reward_classes] != [
            1,
            2,
            3,
        ]:
            blockers.add(
                "rewards.classes must define exactly tier class IDs 1, 2, and 3"
            )
    except (KeyError, TypeError, ValueError):
        blockers.add("rewards.classes unavailable")

    for path, expected in EXECUTABLE_CONSTANTS_V2.items():
        try:
            actual = get_path(profile, path)
        except (KeyError, IndexError, TypeError, ValueError):
            continue
        if actual != expected:
            blockers.add(
                f"{path} must equal the V2 executable constant {expected}"
            )

    for path, width in PROFILE_NARROW_NUMERIC_WIDTHS_V2.items():
        try:
            value = _at(profile, path)
        except (KeyError, IndexError, TypeError, ValueError):
            continue
        if value >= 1 << width:
            blockers.add(f"{path} must fit uint{width}")

    try:
        if (
            _at(profile, "seat.minimumAskImprovementWeiPerSecond") == 0
            and _at(profile, "seat.minimumAskImprovementBps") == 0
        ):
            blockers.add("seat ask improvement must be positive")
    except (KeyError, IndexError, TypeError, ValueError):
        pass

    for relation in PROFILE_RELATIONS:
        try:
            passed = relation.evaluate(profile)
        except (KeyError, IndexError, TypeError):
            blockers.add(f"relation {relation.name} unavailable")
        except ValueError:
            blockers.add(f"relation {relation.name} overflow")
        else:
            if not passed:
                blockers.add(f"relation {relation.name} failed")
    return tuple(sorted(blockers))


def canonical_economic_profile_bytes_v2(profile: Any) -> bytes:
    """Return deterministic JSON bytes with the self-reference cleared."""

    if not isinstance(profile, dict):
        raise TypeError("economic profile must be an object")
    payload = copy.deepcopy(profile)
    if "profileId" not in payload:
        raise ValueError("economic profile lacks profileId")
    payload["profileId"] = None
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def economic_profile_hash_v2(profile: Any) -> bytes:
    """Domain/length-separated SHA-256 identity of canonical profile bytes."""

    payload = canonical_economic_profile_bytes_v2(profile)
    if len(payload) >= 1 << 32:
        raise ValueError("economic profile is too large")
    return hashlib.sha256(
        ECONOMIC_PROFILE_DOMAIN + len(payload).to_bytes(4, "big") + payload
    ).digest()


def _keccak256(value: bytes) -> bytes:
    if _native_keccak is None:
        return _PURE_KECCAK256(value)
    digest = _native_keccak.new(digest_bits=256)
    digest.update(value)
    return digest.digest()


def builder_registry_configuration_hash_v2(profile: dict) -> bytes:
    """Bind the executable builder-token, lease, slash and reward schedule."""

    def narrow(value: int, size: int, name: str) -> bytes:
        exact = _as_u256(value)
        if exact >= 1 << (size * 8):
            raise ValueError(f"{name} exceeds uint{size * 8}")
        return exact.to_bytes(size, "big")

    def address(path: str) -> bytes:
        raw = get_path(profile, path)
        if not isinstance(raw, str) or re.fullmatch(r"0x[0-9a-fA-F]{40}", raw) is None:
            raise ValueError(f"{path} is not a canonical address")
        return bytes.fromhex(raw[2:])

    def hash32(path: str) -> bytes:
        raw = get_path(profile, path)
        if not isinstance(raw, str) or re.fullmatch(r"0x[0-9a-fA-F]{64}", raw) is None:
            raise ValueError(f"{path} is not a canonical hash")
        return bytes.fromhex(raw[2:])

    classes = get_path(profile, "rewards.classes")
    if not isinstance(classes, list) or len(classes) > 255:
        raise ValueError("reward class schedule is malformed")
    class_rows = []
    for reward_class in classes:
        if not isinstance(reward_class, dict):
            raise ValueError("reward class row is malformed")
        name = reward_class.get("name")
        if not isinstance(name, str) or not name:
            raise ValueError("reward class name is malformed")
        class_rows.append(b"".join((
            narrow(reward_class["classId"], 1, "reward class ID"),
            _keccak256(name.encode("utf-8")),
            *(
                _as_u256(reward_class[field]).to_bytes(32, "big")
                for field in (
                    "fixedWei", "perExecutionGasWei",
                    "perPublishedByteWei", "capWei",
                )
            ),
        )))
    payload = b"".join((
        _at(profile, "assets.builderLease.chainId").to_bytes(32, "big"),
        address("assets.builderLease.address"),
        hash32("assets.builderLease.runtimeHash"),
        narrow(_at(profile, "assets.builderLease.decimals"), 1, "decimals"),
        *(
            _at(profile, path).to_bytes(32, "big")
            for path in (
                "builder.leasePerWindowAtomic", "builder.maximumBondAtomic",
                "builder.reporterRewardCapAtomic",
            )
        ),
        narrow(_at(profile, "builder.evidenceDelaySeconds"), 8, "evidence delay"),
        narrow(_at(profile, "builder.reorgMarginSeconds"), 8, "reorg margin"),
        *(
            narrow(_at(profile, path), 2, path)
            for path in (
                "geometry.maximumBuilders", "geometry.maximumAssignedSlots",
                "geometry.entryDelayWindows", "geometry.maximumLiveWindows",
                "geometry.maximumTrancheAheadWindows",
                "geometry.maximumLiabilityGenerations",
            )
        ),
        narrow(
            _at(profile, "geometry.maximumGenerationMovesPerWindow"), 1,
            "generation moves",
        ),
        address("sinks.builderPenalty.address"),
        narrow(_at(profile, "rewards.claimWindowSeconds"), 8, "reward claim window"),
        narrow(len(classes), 1, "reward class count"),
        *class_rows,
    ))
    if len(payload) >= 1 << 32:
        raise ValueError("builder registry economic configuration is too large")
    return _keccak256(
        BUILDER_REGISTRY_ECONOMIC_CONFIG_DOMAIN
        + len(payload).to_bytes(4, "big") + payload
    )


def execution_profile_economic_projection_v2(
    profile: dict,
) -> dict[int, bytes]:
    """Project every reviewed economic value carried by ExecutionProfileV2.

    Release tooling uses this projection as a one-way join: the canonical JSON
    is hashed once, while every duplicated on-chain field must equal the value
    in that same calibrated object.  A nonzero but unrelated word-266 hash is
    therefore insufficient.
    """

    blockers = production_blockers(profile)
    if blockers:
        raise ValueError("economic profile is not production-calibrated")

    def word(value: int) -> bytes:
        return _as_u256(value).to_bytes(32, "big")

    def address(path: str) -> bytes:
        raw = get_path(profile, path)
        if not isinstance(raw, str) or re.fullmatch(r"0x[0-9a-fA-F]{40}", raw) is None:
            raise ValueError(f"{path} is not a canonical address")
        return bytes(12) + bytes.fromhex(raw[2:])

    def hash_word(path: str) -> bytes:
        raw = get_path(profile, path)
        if not isinstance(raw, str) or re.fullmatch(r"0x[0-9a-fA-F]{64}", raw) is None:
            raise ValueError(f"{path} is not a canonical hash")
        return bytes.fromhex(raw[2:])

    include_values = {
        _at(profile, "recovery.activationInclusionSeconds"),
        _at(profile, "recovery.submissionInclusionSeconds"),
        _at(profile, "seat.maximumInclusionSeconds"),
    }
    evidence_values = {
        _at(profile, "builder.evidenceDelaySeconds"),
        _at(profile, "seat.evidenceDelaySeconds"),
    }
    if len(include_values) != 1 or len(evidence_values) != 1:
        raise ValueError("duplicated economic clocks disagree")

    numeric_paths = {
        72: "recovery.settlementWindowSeconds",
        74: "recovery.finalLagSeconds",
        75: "recovery.tipLagSeconds",
        76: "recovery.proofTimeMaxSeconds",
        77: "recovery.l1FinalityBlocks",
        78: "recovery.depthTimeMaxSeconds",
        79: "recovery.clockSkewSeconds",
        80: "recovery.escapeOffsetSeconds",
        81: "recovery.forceDelaySeconds",
        82: "geometry.maximumParentGapSlots",
        83: "forcedEnvelope.maximumValiditySeconds",
        85: "builder.reorgMarginSeconds",
        86: "seat.seatRunwaySeconds",
        87: "seat.minimumPrimaryTenureSeconds",
        88: "seat.minimumStandbyTenureSeconds",
        89: "seat.handoverDelaySeconds",
        90: "seat.stageGraceSeconds",
        91: "seat.exitDelaySeconds",
        92: "seat.recoveryLagSeconds",
        93: "seat.slashLagSeconds",
        94: "seat.premiumClaimDelaySeconds",
        95: "seat.reorgStabilitySeconds",
        96: "seat.releaseChallengeSeconds",
        97: "seat.maximumAskWeiPerSecond",
        98: "seat.slaBondWei",
        99: "seat.maximumAvoidedServiceCostWei",
        100: "seat.collusionSafetyMarginWei",
        101: "dataSession.refundableBondWei",
        102: "dataSession.baseRentWei",
        103: "dataSession.rentPerPublishedByteWei",
        104: "dataSession.blobBaseFeeMultiplierBps",
        105: "dataSession.ttlSeconds",
        106: "dataSession.refundClaimWindowSeconds",
        118: "geometry.slotSeconds",
        119: "geometry.windowSlots",
        120: "geometry.seatCount",
        122: "forcedEnvelope.queueDepth",
        124: "dataSession.maximumLiveSessions",
        125: "dataSession.maximumLiveSessionsPerOwner",
        126: "dataSession.maximumRecordsPerSession",
        127: "dataSession.maximumGcSteps",
        128: "dataSession.maximumBlobsPerPost",
        129: "geometry.canonicalHistoryCells",
        230: "forcedEnvelope.fixedIngressWei",
        231: "forcedEnvelope.executionWeiPerAccountedGas",
        232: "forcedEnvelope.proofWeiPerAccountedGas",
        233: "forcedEnvelope.permanentWeiPerByte",
        234: "forcedEnvelope.maximumAcceptedFeeWei",
        235: "gasProfile.l2BlockGas",
        252: "seat.quoteMaturitySeconds",
        253: "seat.quoteMaturityBlocks",
        263: "seat.maximumStandbyLeaseSeconds",
        264: "seat.minimumAskImprovementWeiPerSecond",
        265: "seat.minimumAskImprovementBps",
    }
    projection = {
        index: word(_at(profile, path))
        for index, path in numeric_paths.items()
    }
    chain_id = _at(profile, "assets.nativeCustody.chainId")
    if chain_id != _at(profile, "assets.builderLease.chainId"):
        raise ValueError("economic asset chain IDs disagree")
    projection.update({
        2: word(chain_id),
        31: builder_registry_configuration_hash_v2(profile),
        63: address("assets.builderLease.address"),
        64: hash_word("assets.builderLease.runtimeHash"),
        65: word(_at(profile, "assets.builderLease.decimals")),
        66: address("sinks.builderPenalty.address"),
        67: address("sinks.dataRent.address"),
        68: address("sinks.seatPenalty.address"),
        69: address("sinks.forcedExpiry.address"),
        70: address("sinks.bridgeSurplus.address"),
        73: word(next(iter(include_values))),
        84: word(next(iter(evidence_values))),
        266: economic_profile_hash_v2(profile),
    })
    return projection


def execution_profile_economic_binding_blockers(
    profile: Any, execution_profile_words: Any,
) -> tuple[str, ...]:
    """Return exact release blockers for the JSON/ExecutionProfileV2 join."""

    try:
        expected = execution_profile_economic_projection_v2(profile)
    except (KeyError, TypeError, ValueError, OverflowError):
        return ("economic profile projection is unavailable",)
    if (
        not isinstance(execution_profile_words, (tuple, list))
        or len(execution_profile_words) not in (267, 268)
        or any(type(item) is not bytes or len(item) != 32
               for item in execution_profile_words)
    ):
        return ("ExecutionProfileV2 words are malformed",)
    return tuple(
        f"ExecutionProfileV2 word {index} differs from the economic profile"
        for index, value in sorted(expected.items())
        if execution_profile_words[index] != value
    )


def reporter_reward_split(profile: dict, builder_slash_amount: int) -> dict[str, Any]:
    """Split one builder-token slash without changing its asset or sink."""

    slash = _as_u256(builder_slash_amount)
    cap = _at(profile, "builder.reporterRewardCapAtomic")
    reporter_reward = min(cap, slash)
    builder_penalty = slash - reporter_reward
    sink = get_path(profile, "sinks.builderPenalty")
    if sink.get("asset") != "BUILDER_LEASE":
        raise ValueError("builder penalty sink asset mismatch")
    return {
        "reporterRewardAtomic": reporter_reward,
        "builderPenaltyAtomic": builder_penalty,
        "builderPenaltySink": dict(sink),
    }
