from __future__ import annotations

import copy
import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
MAIN_TEX = ROOT / "tex" / "main.tex"
UINT64_MAX = (1 << 64) - 1
UINT256_MAX = (1 << 256) - 1
DATA_BYTES_PER_BLOB = 4_096 * 31 - 4


def exact_rule(value):
    return ("exact", type(value).__name__, value)


RULE_UINT = ("uint", False, 0, UINT256_MAX)
RULE_POSITIVE_UINT = ("uint", False, 1, UINT256_MAX)
RULE_NULLABLE_UINT = ("uint", True, 0, UINT256_MAX)
RULE_NULLABLE_POSITIVE_UINT = ("uint", True, 1, UINT256_MAX)
RULE_UINT8 = ("uint", False, 0, 255)
RULE_NULLABLE_UINT8 = ("uint", True, 0, 255)
RULE_NULLABLE_UINT64 = ("uint", True, 0, UINT64_MAX)
RULE_DECIMAL = ("decimal", False, 0, UINT256_MAX)
RULE_POSITIVE_DECIMAL = ("decimal", False, 1, UINT256_MAX)
RULE_NULLABLE_DECIMAL = ("decimal", True, 0, UINT256_MAX)
RULE_NULLABLE_BPS_DECIMAL = ("decimal", True, 0, 10_000)
RULE_NULLABLE_POSITIVE_DECIMAL = ("decimal", True, 1, UINT256_MAX)
RULE_NULLABLE_HASH = ("hash", True)
RULE_NULLABLE_ADDRESS = ("address", True)
RULE_STRING = ("string", False)
RULE_STATUS = ("status", False)
RULE_REWARD_CLASSES = ("reward_classes", False)


# Independent, reviewed schema oracle.  This intentionally does not derive any
# path or rule from the implementation schema or the checked-in fixture.
EXPECTED_SCHEMA_RULES = {
    "schema": exact_rule("taiko.slot-chain.economic-profile.v2"),
    "status": RULE_STATUS,
    "profileId": RULE_NULLABLE_HASH,
    "measurementCommit": RULE_NULLABLE_HASH,
    "units.nativeAmount": exact_rule("wei"),
    "units.nativeRate": exact_rule("wei/second"),
    "units.builderAmount": exact_rule("atomic"),
    "units.time": exact_rule("seconds"),
    "units.gas": exact_rule("gas"),
    "units.size": exact_rule("bytes"),
    "units.ratio": exact_rule("basis-points"),
    "geometry.slotSeconds": RULE_POSITIVE_UINT,
    "geometry.windowSlots": RULE_POSITIVE_UINT,
    "geometry.l1SlotSeconds": RULE_POSITIVE_UINT,
    "geometry.l1EpochSlots": RULE_POSITIVE_UINT,
    "geometry.maximumBuilders": RULE_POSITIVE_UINT,
    "geometry.maximumAssignedSlots": RULE_POSITIVE_UINT,
    "geometry.entryDelayWindows": RULE_POSITIVE_UINT,
    "geometry.maximumLiveWindows": RULE_POSITIVE_UINT,
    "geometry.maximumTrancheAheadWindows": RULE_POSITIVE_UINT,
    "geometry.maximumGenerationMovesPerWindow": RULE_POSITIVE_UINT,
    "geometry.maximumLiabilityGenerations": RULE_POSITIVE_UINT,
    "geometry.snapshotEpochs": RULE_POSITIVE_UINT,
    "geometry.finalityEpochs": RULE_POSITIVE_UINT,
    "geometry.carrierScanSlots": RULE_POSITIVE_UINT,
    "geometry.sealMarginSlots": RULE_POSITIVE_UINT,
    "geometry.lookaheadSlots": RULE_POSITIVE_UINT,
    "geometry.maximumParentGapSlots": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateBlocks": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateWindows": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateAnchors": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateSessions": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateRecords": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateForcedItems": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateForcedBytes": RULE_POSITIVE_UINT,
    "geometry.maximumCandidateForcedGas": RULE_POSITIVE_UINT,
    "geometry.maximumEarlySealWindows": RULE_POSITIVE_UINT,
    "geometry.canonicalHistoryCells": RULE_POSITIVE_UINT,
    "geometry.eip2935HistoryBlocks": RULE_POSITIVE_UINT,
    "geometry.maximumArmAgeBlocks": RULE_POSITIVE_UINT,
    "geometry.seatCount": exact_rule(4),
    "geometry.standbyCount": exact_rule(3),
    "geometry.pendingCount": exact_rule(4),
    "geometry.bookSize": RULE_POSITIVE_UINT,
    "geometry.maximumRewardClasses": RULE_POSITIVE_UINT,
    "assets.builderLease.kind": exact_rule("ERC20_NO_HOOK"),
    "assets.builderLease.chainId": RULE_NULLABLE_UINT64,
    "assets.builderLease.address": RULE_NULLABLE_ADDRESS,
    "assets.builderLease.runtimeHash": RULE_NULLABLE_HASH,
    "assets.builderLease.decimals": RULE_NULLABLE_UINT8,
    "assets.nativeCustody.kind": exact_rule("NATIVE_ETH"),
    "assets.nativeCustody.chainId": RULE_NULLABLE_UINT64,
    "builder.leasePerWindowAtomic": RULE_NULLABLE_POSITIVE_DECIMAL,
    "builder.maximumBondAtomic": RULE_NULLABLE_POSITIVE_DECIMAL,
    "builder.reporterRewardCapAtomic": RULE_NULLABLE_DECIMAL,
    "builder.evidenceDelaySeconds": RULE_POSITIVE_UINT,
    "builder.reorgMarginSeconds": RULE_POSITIVE_UINT,
    "recovery.settlementWindowSeconds": RULE_POSITIVE_UINT,
    "recovery.tipLagSeconds": RULE_POSITIVE_UINT,
    "recovery.finalLagSeconds": RULE_POSITIVE_UINT,
    "recovery.l1FinalityBlocks": RULE_POSITIVE_UINT,
    "recovery.depthTimeMaxSeconds": RULE_POSITIVE_UINT,
    "recovery.proofTimeMaxSeconds": RULE_POSITIVE_UINT,
    "recovery.proofMarginSeconds": RULE_POSITIVE_UINT,
    "recovery.activationInclusionSeconds": RULE_POSITIVE_UINT,
    "recovery.submissionInclusionSeconds": RULE_POSITIVE_UINT,
    "recovery.clockSkewSeconds": RULE_UINT,
    "recovery.escapeOffsetSeconds": RULE_POSITIVE_UINT,
    "recovery.forceDelaySeconds": RULE_POSITIVE_UINT,
    "gasProfile.l2BlockGas": exact_rule(30_000_000),
    "gasProfile.steadyAnchorGas": exact_rule(1_000_000),
    "gasProfile.steadyForcedGas": exact_rule(20_000_000),
    "gasProfile.activationAnchorGas": exact_rule(12_000_000),
    "gasProfile.activationForcedGas": exact_rule(13_000_000),
    "gasProfile.systemMarginGas": exact_rule(5_000_000),
    "gasProfile.minimumForceAccountedGas": exact_rule(21_000),
    "dataSession.ttlSeconds": exact_rule(86_400),
    "dataSession.refundClaimWindowSeconds": exact_rule(86_400),
    "dataSession.maximumLiveSessions": exact_rule(1_024),
    "dataSession.maximumLiveSessionsPerOwner": exact_rule(2),
    "dataSession.maximumRecordsPerSession": exact_rule(2_100),
    "dataSession.maximumGcSteps": exact_rule(8),
    "dataSession.maximumBlobsPerPost": exact_rule(6),
    "dataSession.refundableBondWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "dataSession.baseRentWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "dataSession.rentPerPublishedByteWei": RULE_NULLABLE_DECIMAL,
    "dataSession.blobBaseFeeMultiplierBps": RULE_NULLABLE_BPS_DECIMAL,
    "forcedEnvelope.fixedIngressWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "forcedEnvelope.executionWeiPerAccountedGas": RULE_NULLABLE_POSITIVE_DECIMAL,
    "forcedEnvelope.proofWeiPerAccountedGas": RULE_NULLABLE_POSITIVE_DECIMAL,
    "forcedEnvelope.permanentWeiPerByte": RULE_NULLABLE_POSITIVE_DECIMAL,
    "forcedEnvelope.maximumAcceptedFeeWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "forcedEnvelope.claimWindowSeconds": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumValiditySeconds": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumItemBytes": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumItemAccountedGas": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumPrefixItems": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumPrefixBytes": RULE_POSITIVE_UINT,
    "forcedEnvelope.maximumPrefixAccountedGas": RULE_POSITIVE_UINT,
    "forcedEnvelope.queueDepth": exact_rule(64),
    "forcedEnvelope.maximumQueueCount": RULE_POSITIVE_DECIMAL,
    "forcedEnvelope.maximumRangeProofHashes": exact_rule(257),
    "bridge.maximumEnqueueDelaySeconds": RULE_POSITIVE_UINT,
    "bridge.processTtlSeconds": RULE_POSITIVE_UINT,
    "bridge.supportFinalityBlocks": RULE_POSITIVE_UINT,
    "bridge.maximumDomainEntriesPerRelease": RULE_POSITIVE_UINT,
    "bridge.refundCapsuleWords": RULE_POSITIVE_UINT,
    "bridge.refundErc721Ids": RULE_POSITIVE_UINT,
    "bridge.refundErc1155Pairs": RULE_POSITIVE_UINT,
    "bridge.terminalAccumulatorDepth": exact_rule(64),
    "bridge.maximumTerminalCount": RULE_POSITIVE_DECIMAL,
    "bridge.registrationProofMaximumNodesPerPath": exact_rule(66),
    "bridge.registrationProofPathCount": exact_rule(2),
    "bridge.registrationProofMaximumTotalNodes": exact_rule(132),
    "bridge.registrationProofMaximumNodeBytes": exact_rule(600),
    "bridge.registrationProofMaximumBytes": exact_rule(80_000),
    "bridge.registrationProofMaximumGas": exact_rule(8_000_000),
    "seat.slaBondWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "seat.maximumAskWeiPerSecond": RULE_NULLABLE_POSITIVE_DECIMAL,
    "seat.minimumAskImprovementWeiPerSecond": RULE_NULLABLE_DECIMAL,
    "seat.minimumAskImprovementBps": RULE_NULLABLE_BPS_DECIMAL,
    "seat.quoteMaturitySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.quoteMaturityBlocks": RULE_NULLABLE_POSITIVE_UINT,
    "seat.minimumPrimaryTenureSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.minimumStandbyTenureSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.maximumStandbyLeaseSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.handoverDelaySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.stageGraceSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.maximumInclusionSeconds": RULE_POSITIVE_UINT,
    "seat.handoverExecutionBufferSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.exitDelaySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.releaseChallengeSeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.evidenceDelaySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.premiumClaimDelaySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.reorgStabilitySeconds": RULE_POSITIVE_UINT,
    "seat.recoveryLagSeconds": RULE_POSITIVE_UINT,
    "seat.slashLagSeconds": RULE_POSITIVE_UINT,
    "seat.seatRunwaySeconds": RULE_NULLABLE_POSITIVE_UINT,
    "seat.maximumAvoidedServiceCostWei": RULE_NULLABLE_DECIMAL,
    "seat.collusionSafetyMarginWei": RULE_NULLABLE_POSITIVE_DECIMAL,
    "rewards.claimWindowSeconds": RULE_POSITIVE_UINT,
    "rewards.classes": RULE_REWARD_CLASSES,
    "sinks.builderPenalty.asset": exact_rule("BUILDER_LEASE"),
    "sinks.builderPenalty.address": RULE_NULLABLE_ADDRESS,
    "sinks.dataRent.asset": exact_rule("NATIVE_ETH"),
    "sinks.dataRent.address": RULE_NULLABLE_ADDRESS,
    "sinks.seatPenalty.asset": exact_rule("NATIVE_ETH"),
    "sinks.seatPenalty.address": RULE_NULLABLE_ADDRESS,
    "sinks.forcedExpiry.asset": exact_rule("NATIVE_ETH"),
    "sinks.forcedExpiry.address": RULE_NULLABLE_ADDRESS,
    "sinks.bridgeSurplus.asset": exact_rule("NATIVE_ETH"),
    "sinks.bridgeSurplus.address": RULE_NULLABLE_ADDRESS,
    "rewards.classes[].classId": RULE_UINT8,
    "rewards.classes[].name": RULE_STRING,
    "rewards.classes[].fixedWei": RULE_DECIMAL,
    "rewards.classes[].perExecutionGasWei": RULE_DECIMAL,
    "rewards.classes[].perPublishedByteWei": RULE_DECIMAL,
    "rewards.classes[].capWei": RULE_DECIMAL,
}


def oracle_get(profile, path):
    value = profile
    for component in path.split("."):
        value = value[int(component)] if isinstance(value, list) else value[component]
    return int(value) if isinstance(value, str) and value.isdecimal() else value


def oracle_ceil_div(numerator, denominator):
    return (numerator + denominator - 1) // denominator


def relation_spec(
    name,
    operands,
    operator,
    boundary_path,
    boundary_value,
    boundary_expected,
    source_anchor="sec:parameters",
):
    return {
        "name": name,
        "source_anchor": source_anchor,
        "operands": operands,
        "operator": operator,
        "boundary_path": boundary_path,
        "boundary_value": boundary_value,
        "boundary_expected": boundary_expected,
    }


def oracle_window_seconds(profile):
    return oracle_get(profile, "geometry.windowSlots") * oracle_get(
        profile, "geometry.slotSeconds"
    )


def oracle_liability_residence(profile):
    return (
        oracle_get(profile, "geometry.maximumTrancheAheadWindows")
        + 1
        + oracle_ceil_div(
            oracle_get(profile, "builder.evidenceDelaySeconds")
            + oracle_get(profile, "builder.reorgMarginSeconds"),
            oracle_window_seconds(profile),
        )
        + 2
    )


def oracle_snapshot_epochs(profile):
    schedule_seconds = (
        oracle_get(profile, "geometry.lookaheadSlots")
        + oracle_get(profile, "geometry.windowSlots")
    ) * oracle_get(profile, "geometry.slotSeconds")
    required_l1_slots = (
        oracle_get(profile, "geometry.carrierScanSlots")
        + oracle_get(profile, "geometry.finalityEpochs")
        * oracle_get(profile, "geometry.l1EpochSlots")
        + oracle_get(profile, "geometry.sealMarginSlots")
        + oracle_ceil_div(
            schedule_seconds, oracle_get(profile, "geometry.l1SlotSeconds")
        )
    )
    return oracle_ceil_div(
        required_l1_slots, oracle_get(profile, "geometry.l1EpochSlots")
    )


def oracle_candidate_windows_for_gap(profile):
    gap_slots = oracle_get(profile, "geometry.maximumParentGapSlots")
    skew_slots = oracle_ceil_div(
        oracle_get(profile, "recovery.clockSkewSeconds"),
        oracle_get(profile, "geometry.slotSeconds"),
    )
    return oracle_ceil_div(
        gap_slots + skew_slots, oracle_get(profile, "geometry.windowSlots")
    )


def oracle_recovery_lower_bound(profile):
    return (
        oracle_get(profile, "recovery.finalLagSeconds")
        + oracle_get(profile, "recovery.tipLagSeconds")
        + oracle_get(profile, "builder.reorgMarginSeconds")
    )


def oracle_eip2935_horizon(profile):
    replay_seconds = (
        oracle_get(profile, "recovery.settlementWindowSeconds")
        + oracle_get(profile, "recovery.clockSkewSeconds")
        + oracle_window_seconds(profile)
        + oracle_get(profile, "builder.evidenceDelaySeconds")
        + oracle_get(profile, "builder.reorgMarginSeconds")
    )
    return (
        oracle_get(profile, "geometry.maximumArmAgeBlocks")
        + oracle_ceil_div(
            replay_seconds, oracle_get(profile, "geometry.l1SlotSeconds")
        )
        + 2
    )


def oracle_schedule_ring(profile):
    retention_seconds = (
        oracle_get(profile, "recovery.settlementWindowSeconds")
        + oracle_get(profile, "recovery.finalLagSeconds")
        + oracle_get(profile, "recovery.tipLagSeconds")
        + oracle_get(profile, "builder.reorgMarginSeconds")
        + oracle_get(profile, "builder.evidenceDelaySeconds")
    )
    return (
        oracle_get(profile, "geometry.maximumEarlySealWindows")
        + oracle_get(profile, "geometry.maximumCandidateWindows")
        + oracle_ceil_div(retention_seconds, oracle_window_seconds(profile))
        + 2
    )


def oracle_sla_tail(profile):
    return oracle_get(profile, "seat.slashLagSeconds") - oracle_get(
        profile, "seat.recoveryLagSeconds"
    )


EXPECTED_RELATION_SPECS = (
    relation_spec(
        "standby-lease-tenure-handover",
        (
            "seat.maximumStandbyLeaseSeconds",
            "seat.minimumStandbyTenureSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        "seat.maximumStandbyLeaseSeconds",
        lambda p: sum(oracle_get(p, path) for path in (
            "seat.minimumStandbyTenureSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.maximumInclusionSeconds",
        )),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "builder-bond-product",
        ("builder.maximumBondAtomic", "geometry.maximumAssignedSlots"),
        "<",
        "builder.maximumBondAtomic",
        lambda p: UINT256_MAX
        // (oracle_get(p, "geometry.maximumAssignedSlots") + 1),
        (True, True, False),
    ),
    relation_spec(
        "builder-bond-uint192-cap",
        ("builder.maximumBondAtomic",),
        "<=",
        "builder.maximumBondAtomic",
        lambda _p: (1 << 192) - 1,
        (True, True, False),
    ),
    relation_spec(
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
        "geometry.maximumLiveWindows",
        oracle_liability_residence,
        (False, False, True),
    ),
    relation_spec(
        "liability-generation-capacity",
        (
            "geometry.maximumLiabilityGenerations",
            "geometry.maximumGenerationMovesPerWindow",
            "geometry.maximumLiveWindows",
        ),
        ">=",
        "geometry.maximumLiabilityGenerations",
        lambda p: oracle_get(p, "geometry.maximumGenerationMovesPerWindow")
        * oracle_get(p, "geometry.maximumLiveWindows"),
        (False, True, True),
    ),
    relation_spec(
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
        "geometry.snapshotEpochs",
        oracle_snapshot_epochs,
        (False, True, True),
    ),
    relation_spec(
        "lookahead-window-slack",
        ("geometry.lookaheadSlots", "geometry.windowSlots"),
        ">=",
        "geometry.lookaheadSlots",
        lambda p: 2 * oracle_get(p, "geometry.windowSlots"),
        (False, True, True),
    ),
    relation_spec(
        "parent-gap-final-lag-identity",
        (
            "geometry.maximumParentGapSlots",
            "geometry.slotSeconds",
            "recovery.finalLagSeconds",
        ),
        "==",
        "geometry.maximumParentGapSlots",
        lambda p: oracle_get(p, "recovery.finalLagSeconds")
        // oracle_get(p, "geometry.slotSeconds"),
        (False, True, False),
    ),
    relation_spec(
        "parent-gap-candidate-cap",
        (
            "geometry.maximumParentGapSlots",
            "recovery.clockSkewSeconds",
            "geometry.slotSeconds",
            "geometry.windowSlots",
            "geometry.maximumCandidateWindows",
        ),
        "<=",
        "geometry.maximumCandidateWindows",
        oracle_candidate_windows_for_gap,
        (False, True, True),
    ),
    relation_spec(
        "candidate-block-window-cap",
        (
            "geometry.maximumCandidateBlocks",
            "geometry.maximumCandidateWindows",
            "geometry.windowSlots",
        ),
        "<=",
        "geometry.maximumCandidateWindows",
        lambda p: oracle_ceil_div(
            oracle_get(p, "geometry.maximumCandidateBlocks"),
            oracle_get(p, "geometry.windowSlots"),
        ),
        (False, True, True),
    ),
    relation_spec(
        "tip-inclusion-skew",
        (
            "recovery.tipLagSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.clockSkewSeconds",
        ),
        ">=",
        "recovery.tipLagSeconds",
        lambda p: oracle_get(p, "recovery.submissionInclusionSeconds")
        + oracle_get(p, "recovery.clockSkewSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "final-lag-recovery-geometry",
        (
            "recovery.finalLagSeconds",
            "recovery.activationInclusionSeconds",
            "recovery.escapeOffsetSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.clockSkewSeconds",
        ),
        ">=",
        "recovery.finalLagSeconds",
        lambda p: oracle_get(p, "recovery.activationInclusionSeconds")
        + oracle_get(p, "recovery.escapeOffsetSeconds")
        + oracle_get(p, "recovery.submissionInclusionSeconds")
        + oracle_get(p, "recovery.clockSkewSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "escape-offset-depth-proof-margin",
        (
            "recovery.escapeOffsetSeconds",
            "recovery.depthTimeMaxSeconds",
            "recovery.proofTimeMaxSeconds",
            "recovery.proofMarginSeconds",
        ),
        ">=",
        "recovery.escapeOffsetSeconds",
        lambda p: oracle_get(p, "recovery.depthTimeMaxSeconds")
        + oracle_get(p, "recovery.proofTimeMaxSeconds")
        + oracle_get(p, "recovery.proofMarginSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "force-delay-settlement-inclusion",
        (
            "recovery.forceDelaySeconds",
            "recovery.settlementWindowSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        "recovery.forceDelaySeconds",
        lambda p: oracle_get(p, "recovery.settlementWindowSeconds")
        + oracle_get(p, "seat.maximumInclusionSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "forced-item-count-prefix",
        ("forcedEnvelope.maximumPrefixItems",),
        ">=",
        "forcedEnvelope.maximumPrefixItems",
        lambda _p: 1,
        (False, True, True),
    ),
    relation_spec(
        "forced-prefix-count-candidate",
        (
            "forcedEnvelope.maximumPrefixItems",
            "geometry.maximumCandidateForcedItems",
        ),
        "<=",
        "forcedEnvelope.maximumPrefixItems",
        lambda p: oracle_get(p, "geometry.maximumCandidateForcedItems"),
        (True, True, False),
    ),
    relation_spec(
        "forced-prefix-queue-capacity",
        (
            "forcedEnvelope.maximumPrefixItems",
            "forcedEnvelope.maximumQueueCount",
        ),
        "<=",
        "forcedEnvelope.maximumPrefixItems",
        lambda p: oracle_get(p, "forcedEnvelope.maximumQueueCount"),
        (True, True, False),
    ),
    relation_spec(
        "forced-range-proof-boundary",
        (
            "forcedEnvelope.maximumRangeProofHashes",
            "geometry.maximumCandidateForcedItems",
        ),
        "<=",
        "forcedEnvelope.maximumRangeProofHashes",
        lambda p: oracle_get(p, "geometry.maximumCandidateForcedItems") + 1,
        (True, True, False),
    ),
    relation_spec(
        "forced-item-bytes-prefix",
        (
            "forcedEnvelope.maximumItemBytes",
            "forcedEnvelope.maximumPrefixBytes",
        ),
        "<=",
        "forcedEnvelope.maximumItemBytes",
        lambda p: oracle_get(p, "forcedEnvelope.maximumPrefixBytes"),
        (True, True, False),
    ),
    relation_spec(
        "forced-prefix-bytes-candidate",
        (
            "forcedEnvelope.maximumPrefixBytes",
            "geometry.maximumCandidateForcedBytes",
        ),
        "<=",
        "forcedEnvelope.maximumPrefixBytes",
        lambda p: oracle_get(p, "geometry.maximumCandidateForcedBytes"),
        (True, True, False),
    ),
    relation_spec(
        "forced-item-gas-prefix",
        (
            "forcedEnvelope.maximumItemAccountedGas",
            "forcedEnvelope.maximumPrefixAccountedGas",
        ),
        "<=",
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: oracle_get(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        (True, True, False),
    ),
    relation_spec(
        "forced-minimum-accounted-gas-cap",
        (
            "gasProfile.minimumForceAccountedGas",
            "forcedEnvelope.maximumItemAccountedGas",
        ),
        "<=",
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: oracle_get(p, "gasProfile.minimumForceAccountedGas"),
        (False, True, True),
    ),
    relation_spec(
        "activation-forced-head-capacity",
        (
            "forcedEnvelope.maximumItemAccountedGas",
            "gasProfile.activationForcedGas",
        ),
        "<=",
        "forcedEnvelope.maximumItemAccountedGas",
        lambda p: oracle_get(p, "gasProfile.activationForcedGas"),
        (True, True, False),
    ),
    relation_spec(
        "forced-prefix-gas-candidate",
        (
            "forcedEnvelope.maximumPrefixAccountedGas",
            "geometry.maximumCandidateForcedGas",
        ),
        "<=",
        "forcedEnvelope.maximumPrefixAccountedGas",
        lambda p: oracle_get(p, "geometry.maximumCandidateForcedGas"),
        (True, True, False),
    ),
    relation_spec(
        "forced-queue-count-u64",
        ("forcedEnvelope.maximumQueueCount",),
        "==",
        "forcedEnvelope.maximumQueueCount",
        lambda _p: UINT64_MAX,
        (False, True, False),
    ),
    relation_spec(
        "forced-queue-prefix-u256",
        (
            "forcedEnvelope.maximumQueueCount",
            "forcedEnvelope.maximumAcceptedFeeWei",
        ),
        "<=",
        "forcedEnvelope.maximumAcceptedFeeWei",
        lambda p: UINT256_MAX
        // oracle_get(p, "forcedEnvelope.maximumQueueCount"),
        (True, True, False),
    ),
    relation_spec(
        "terminal-count-u64",
        ("bridge.maximumTerminalCount",),
        "==",
        "bridge.maximumTerminalCount",
        lambda _p: UINT64_MAX,
        (False, True, False),
    ),
    relation_spec(
        "refund-erc721-word-cap",
        ("bridge.refundErc721Ids", "bridge.refundCapsuleWords"),
        "<=",
        "bridge.refundErc721Ids",
        lambda p: oracle_get(p, "bridge.refundCapsuleWords"),
        (True, True, False),
    ),
    relation_spec(
        "refund-erc1155-word-cap",
        ("bridge.refundErc1155Pairs", "bridge.refundCapsuleWords"),
        "<=",
        "bridge.refundErc1155Pairs",
        lambda p: oracle_get(p, "bridge.refundCapsuleWords") // 2,
        (True, True, False),
    ),
    relation_spec(
        "kind0-validity-lower-bound",
        (
            "forcedEnvelope.maximumValiditySeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        "forcedEnvelope.maximumValiditySeconds",
        oracle_recovery_lower_bound,
        (False, True, True),
    ),
    relation_spec(
        "kind1-enqueue-lower-bound",
        (
            "bridge.maximumEnqueueDelaySeconds",
            "recovery.finalLagSeconds",
            "recovery.tipLagSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        "bridge.maximumEnqueueDelaySeconds",
        oracle_recovery_lower_bound,
        (False, True, True),
    ),
    relation_spec(
        "bridge-process-ttl-lower-bound",
        (
            "bridge.processTtlSeconds",
            "bridge.maximumEnqueueDelaySeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        "bridge.processTtlSeconds",
        lambda p: oracle_get(p, "bridge.maximumEnqueueDelaySeconds")
        + oracle_get(p, "builder.reorgMarginSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "support-finality-reorg-depth",
        (
            "bridge.supportFinalityBlocks",
            "recovery.l1FinalityBlocks",
            "builder.reorgMarginSeconds",
            "geometry.l1SlotSeconds",
        ),
        "==",
        "bridge.supportFinalityBlocks",
        lambda p: oracle_get(p, "recovery.l1FinalityBlocks")
        + oracle_ceil_div(
            oracle_get(p, "builder.reorgMarginSeconds"),
            oracle_get(p, "geometry.l1SlotSeconds"),
        ),
        (False, True, False),
    ),
    relation_spec(
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
        "dataSession.ttlSeconds",
        lambda p: oracle_get(p, "recovery.settlementWindowSeconds")
        + oracle_get(p, "recovery.finalLagSeconds")
        + oracle_get(p, "recovery.tipLagSeconds")
        + oracle_get(p, "builder.reorgMarginSeconds")
        + oracle_get(p, "seat.maximumInclusionSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "data-session-open-expiry-horizon",
        (
            "dataSession.ttlSeconds",
            "recovery.proofTimeMaxSeconds",
            "recovery.settlementWindowSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        "dataSession.ttlSeconds",
        lambda p: oracle_get(p, "recovery.proofTimeMaxSeconds")
        + oracle_get(p, "recovery.settlementWindowSeconds")
        + oracle_get(p, "builder.reorgMarginSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "data-refund-claim-horizon",
        (
            "dataSession.refundClaimWindowSeconds",
            "seat.maximumInclusionSeconds",
            "builder.reorgMarginSeconds",
        ),
        ">=",
        "dataSession.refundClaimWindowSeconds",
        lambda p: oracle_get(p, "seat.maximumInclusionSeconds")
        + oracle_get(p, "builder.reorgMarginSeconds"),
        (False, True, True),
    ),
    relation_spec(
        "reward-claim-window-profile-word",
        (
            "rewards.claimWindowSeconds",
            "dataSession.refundClaimWindowSeconds",
        ),
        "==",
        "rewards.claimWindowSeconds",
        lambda p: oracle_get(p, "dataSession.refundClaimWindowSeconds"),
        (False, True, False),
    ),
    relation_spec(
        "canonical-history-reorg-capacity",
        (
            "geometry.canonicalHistoryCells",
            "seat.maximumInclusionSeconds",
            "builder.reorgMarginSeconds",
            "geometry.l1SlotSeconds",
        ),
        ">",
        "geometry.canonicalHistoryCells",
        lambda p: oracle_ceil_div(
            oracle_get(p, "seat.maximumInclusionSeconds")
            + oracle_get(p, "builder.reorgMarginSeconds"),
            oracle_get(p, "geometry.l1SlotSeconds"),
        )
        + 2,
        (False, False, True),
    ),
    relation_spec(
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
        "geometry.eip2935HistoryBlocks",
        oracle_eip2935_horizon,
        (False, False, True),
    ),
    relation_spec(
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
        "geometry.maximumLiveWindows",
        oracle_schedule_ring,
        (False, True, True),
    ),
    relation_spec(
        "data-session-capacity",
        (
            "dataSession.maximumLiveSessions",
            "geometry.maximumCandidateSessions",
        ),
        ">=",
        "dataSession.maximumLiveSessions",
        lambda p: oracle_get(p, "geometry.maximumCandidateSessions"),
        (False, True, True),
    ),
    relation_spec(
        "session-record-capacity",
        (
            "dataSession.maximumRecordsPerSession",
            "geometry.maximumCandidateRecords",
        ),
        ">=",
        "dataSession.maximumRecordsPerSession",
        lambda p: oracle_get(p, "geometry.maximumCandidateRecords"),
        (False, True, True),
    ),
    relation_spec(
        "session-ring-gc-capacity",
        ("dataSession.maximumLiveSessions", "dataSession.maximumGcSteps"),
        ">=",
        "dataSession.maximumLiveSessions",
        lambda p: oracle_get(p, "dataSession.maximumGcSteps"),
        (False, True, True),
    ),
    relation_spec(
        "session-bond-liability-u256",
        (
            "dataSession.maximumLiveSessions",
            "dataSession.refundableBondWei",
        ),
        "<=",
        "dataSession.refundableBondWei",
        lambda p: UINT256_MAX
        // oracle_get(p, "dataSession.maximumLiveSessions"),
        (True, True, False),
    ),
    relation_spec(
        "session-open-value-u256",
        (
            "dataSession.refundableBondWei",
            "dataSession.baseRentWei",
        ),
        "<=",
        "dataSession.baseRentWei",
        lambda p: UINT256_MAX
        - oracle_get(p, "dataSession.refundableBondWei"),
        (True, True, False),
    ),
    relation_spec(
        "session-byte-rent-u256",
        (
            "dataSession.maximumRecordsPerSession",
            "dataSession.rentPerPublishedByteWei",
        ),
        "<=",
        "dataSession.rentPerPublishedByteWei",
        lambda p: UINT256_MAX
        // (
            oracle_get(p, "dataSession.maximumRecordsPerSession")
            * DATA_BYTES_PER_BLOB
        ),
        (True, True, False),
    ),
    relation_spec(
        "seat-book-capacity",
        (
            "geometry.bookSize",
            "geometry.seatCount",
            "geometry.pendingCount",
        ),
        "==",
        "geometry.bookSize",
        lambda p: oracle_get(p, "geometry.seatCount")
        + oracle_get(p, "geometry.pendingCount"),
        (False, True, False),
        "sec:economics",
    ),
    relation_spec(
        "slash-lag-recovery-order",
        ("seat.slashLagSeconds", "seat.recoveryLagSeconds"),
        ">",
        "seat.slashLagSeconds",
        lambda p: oracle_get(p, "seat.recoveryLagSeconds"),
        (False, False, True),
        "sec:economics",
    ),
    relation_spec(
        "premium-claim-reorg-stability",
        ("seat.premiumClaimDelaySeconds", "seat.reorgStabilitySeconds"),
        ">=",
        "seat.premiumClaimDelaySeconds",
        lambda p: oracle_get(p, "seat.reorgStabilitySeconds"),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "seat-runway-primary-handover-sla",
        (
            "seat.seatRunwaySeconds",
            "seat.minimumPrimaryTenureSeconds",
            "seat.handoverExecutionBufferSeconds",
            "seat.slashLagSeconds",
            "seat.recoveryLagSeconds",
        ),
        ">=",
        "seat.seatRunwaySeconds",
        lambda p: oracle_get(p, "seat.minimumPrimaryTenureSeconds")
        + oracle_get(p, "seat.handoverExecutionBufferSeconds")
        + oracle_sla_tail(p),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "seat-maximum-reserve-u256",
        (
            "seat.maximumAskWeiPerSecond",
            "seat.seatRunwaySeconds",
        ),
        "<=",
        "seat.maximumAskWeiPerSecond",
        lambda p: UINT256_MAX // oracle_get(p, "seat.seatRunwaySeconds"),
        (True, True, False),
        "sec:economics",
    ),
    relation_spec(
        "handover-buffer-delay-grace-inclusion",
        (
            "seat.handoverExecutionBufferSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.maximumInclusionSeconds",
        ),
        ">=",
        "seat.handoverExecutionBufferSeconds",
        lambda p: oracle_get(p, "seat.handoverDelaySeconds")
        + oracle_get(p, "seat.stageGraceSeconds")
        + oracle_get(p, "seat.maximumInclusionSeconds"),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "sla-bond-claim-tail",
        (
            "seat.slaBondWei",
            "seat.maximumAskWeiPerSecond",
            "seat.premiumClaimDelaySeconds",
        ),
        ">=",
        "seat.slaBondWei",
        lambda p: oracle_get(p, "seat.maximumAskWeiPerSecond")
        * oracle_get(p, "seat.premiumClaimDelaySeconds"),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "sla-bond-collusion",
        (
            "seat.slaBondWei",
            "seat.maximumAskWeiPerSecond",
            "seat.minimumPrimaryTenureSeconds",
            "seat.maximumAvoidedServiceCostWei",
            "seat.collusionSafetyMarginWei",
        ),
        ">=",
        "seat.slaBondWei",
        lambda p: oracle_get(p, "seat.maximumAskWeiPerSecond")
        * oracle_get(p, "seat.minimumPrimaryTenureSeconds")
        + oracle_get(p, "seat.maximumAvoidedServiceCostWei")
        + oracle_get(p, "seat.collusionSafetyMarginWei"),
        (False, True, True),
        "sec:economics",
    ),
    relation_spec(
        "steady-forced-profile-identity",
        (
            "gasProfile.steadyForcedGas",
            "forcedEnvelope.maximumPrefixAccountedGas",
        ),
        "==",
        "gasProfile.steadyForcedGas",
        lambda p: oracle_get(p, "forcedEnvelope.maximumPrefixAccountedGas"),
        (False, True, False),
    ),
    relation_spec(
        "steady-gas-envelope",
        (
            "gasProfile.l2BlockGas",
            "gasProfile.steadyAnchorGas",
            "gasProfile.steadyForcedGas",
            "gasProfile.systemMarginGas",
        ),
        "<=",
        "gasProfile.l2BlockGas",
        lambda p: oracle_get(p, "gasProfile.steadyAnchorGas")
        + oracle_get(p, "gasProfile.steadyForcedGas")
        + oracle_get(p, "gasProfile.systemMarginGas"),
        (False, True, True),
    ),
    relation_spec(
        "activation-gas-envelope",
        (
            "gasProfile.l2BlockGas",
            "gasProfile.activationAnchorGas",
            "gasProfile.activationForcedGas",
            "gasProfile.systemMarginGas",
        ),
        "<=",
        "gasProfile.l2BlockGas",
        lambda p: oracle_get(p, "gasProfile.activationAnchorGas")
        + oracle_get(p, "gasProfile.activationForcedGas")
        + oracle_get(p, "gasProfile.systemMarginGas"),
        (False, True, True),
    ),
    relation_spec(
        "registration-proof-total-nodes",
        (
            "bridge.registrationProofMaximumNodesPerPath",
            "bridge.registrationProofPathCount",
            "bridge.registrationProofMaximumTotalNodes",
        ),
        "==",
        "bridge.registrationProofMaximumTotalNodes",
        lambda p: oracle_get(p, "bridge.registrationProofMaximumNodesPerPath")
        * oracle_get(p, "bridge.registrationProofPathCount"),
        (False, True, False),
    ),
    relation_spec(
        "registration-proof-byte-capacity",
        (
            "bridge.registrationProofMaximumTotalNodes",
            "bridge.registrationProofMaximumNodeBytes",
            "bridge.registrationProofMaximumBytes",
        ),
        "<=",
        "bridge.registrationProofMaximumBytes",
        lambda p: oracle_get(p, "bridge.registrationProofMaximumTotalNodes")
        * oracle_get(p, "bridge.registrationProofMaximumNodeBytes"),
        (False, True, True),
    ),
)


def load_module(filename: str, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, ROOT / filename)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class EconomicProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = load_module(
            "economic-profile-model.py", "economic_profile_model"
        )
        cls.example = cls.model.load_economic_profile(
            str(ROOT / "economic-profile.example.json")
        )

    def calibrated_profile(self):
        profile = copy.deepcopy(self.example)
        profile.update(
            status="CALIBRATED",
            profileId=None,
            measurementCommit="0x" + "22" * 32,
        )
        profile["assets"]["builderLease"].update(
            chainId=167,
            address="0x" + "33" * 20,
            runtimeHash="0x" + "44" * 32,
            decimals=18,
        )
        profile["assets"]["nativeCustody"]["chainId"] = 167
        profile["builder"].update(
            leasePerWindowAtomic="1000000",
            maximumBondAtomic=str((1 << 192) - 1),
            reporterRewardCapAtomic="100",
        )
        profile["dataSession"].update(
            refundableBondWei="1000",
            baseRentWei="10",
            rentPerPublishedByteWei="2",
            blobBaseFeeMultiplierBps="10000",
        )
        profile["forcedEnvelope"].update(
            fixedIngressWei="1000",
            executionWeiPerAccountedGas="2",
            proofWeiPerAccountedGas="3",
            permanentWeiPerByte="4",
            maximumAcceptedFeeWei="1000000000",
        )
        profile["seat"].update(
            slaBondWei="100000",
            maximumAskWeiPerSecond="10",
            minimumAskImprovementWeiPerSecond="1",
            minimumAskImprovementBps="100",
            quoteMaturitySeconds=120,
            quoteMaturityBlocks=10,
            minimumPrimaryTenureSeconds=5000,
            minimumStandbyTenureSeconds=1000,
            maximumStandbyLeaseSeconds=10000,
            handoverDelaySeconds=100,
            stageGraceSeconds=100,
            handoverExecutionBufferSeconds=400,
            exitDelaySeconds=1200,
            releaseChallengeSeconds=1800,
            evidenceDelaySeconds=86400,
            premiumClaimDelaySeconds=1800,
            seatRunwaySeconds=10000,
            maximumAvoidedServiceCostWei="1000",
            collusionSafetyMarginWei="500",
        )
        profile["rewards"]["classes"] = [
            {
                "classId": 1,
                "name": "tier-1-proof",
                "fixedWei": "100",
                "perExecutionGasWei": "2",
                "perPublishedByteWei": "1",
                "capWei": "1000000",
            },
            {
                "classId": 2,
                "name": "tier-2-proof",
                "fixedWei": "200",
                "perExecutionGasWei": "3",
                "perPublishedByteWei": "2",
                "capWei": "2000000",
            },
            {
                "classId": 3,
                "name": "tier-3-recovery",
                "fixedWei": "300",
                "perExecutionGasWei": "4",
                "perPublishedByteWei": "3",
                "capWei": "3000000",
            },
        ]
        for index, sink in enumerate(profile["sinks"].values(), start=5):
            sink["address"] = "0x" + f"{index:02x}" * 20
        profile["profileId"] = (
            "0x" + self.model.economic_profile_hash_v2(profile).hex()
        )
        return profile

    def test_example_is_structurally_valid_but_not_production_valid(self):
        self.assertEqual(self.model.validate_schema(self.example), ())
        self.assertIn(
            "status must be CALIBRATED",
            self.model.production_blockers(self.example),
        )

    def test_calibrated_profile_has_no_blockers(self):
        profile = self.calibrated_profile()
        self.assertEqual(self.model.validate_schema(profile), ())
        self.assertEqual(self.model.production_blockers(profile), ())

    def test_execution_profile_join_binds_hash_and_every_duplicated_value(self):
        profile = self.calibrated_profile()
        projection = self.model.execution_profile_economic_projection_v2(
            profile
        )
        words = [bytes(32) for _ in range(267)]
        for index, value in projection.items():
            words[index] = value
        self.assertEqual(
            self.model.execution_profile_economic_binding_blockers(
                profile, tuple(words)
            ),
            (),
        )
        for index in sorted(projection):
            malformed = list(words)
            malformed[index] = bytes([malformed[index][0] ^ 1]) + malformed[index][1:]
            self.assertEqual(
                self.model.execution_profile_economic_binding_blockers(
                    profile, tuple(malformed)
                ),
                (
                    f"ExecutionProfileV2 word {index} differs from the economic profile",
                ),
            )
        self.assertEqual(
            self.model.execution_profile_economic_binding_blockers(
                self.example, tuple(words)
            ),
            ("economic profile projection is unavailable",),
        )

    def test_reward_claim_window_is_the_existing_profile_word_106(self):
        profile = self.calibrated_profile()
        self.assertEqual(
            self.model.get_path(profile, "rewards.claimWindowSeconds"),
            self.model.get_path(
                profile, "dataSession.refundClaimWindowSeconds"
            ),
        )
        projection = self.model.execution_profile_economic_projection_v2(
            profile
        )
        self.assertEqual(
            int.from_bytes(projection[106], "big"),
            self.model.get_path(profile, "rewards.claimWindowSeconds"),
        )

        mismatched = copy.deepcopy(profile)
        mismatched["rewards"]["claimWindowSeconds"] += 1
        mismatched["profileId"] = None
        mismatched["profileId"] = (
            "0x" + self.model.economic_profile_hash_v2(mismatched).hex()
        )
        self.assertIn(
            "relation reward-claim-window-profile-word failed",
            self.model.production_blockers(mismatched),
        )
        self.assertEqual(
            self.model.execution_profile_economic_binding_blockers(
                mismatched, tuple(bytes(32) for _ in range(267))
            ),
            ("economic profile projection is unavailable",),
        )

    def test_every_v2_executable_constant_is_independently_pinned(self):
        expected_paths = {
            "geometry.slotSeconds", "geometry.windowSlots",
            "geometry.l1SlotSeconds", "geometry.l1EpochSlots",
            "geometry.maximumBuilders", "geometry.maximumAssignedSlots",
            "geometry.entryDelayWindows", "geometry.maximumLiveWindows",
            "geometry.maximumTrancheAheadWindows",
            "geometry.maximumGenerationMovesPerWindow",
            "geometry.maximumLiabilityGenerations", "geometry.snapshotEpochs",
            "geometry.finalityEpochs", "geometry.carrierScanSlots",
            "geometry.sealMarginSlots", "geometry.lookaheadSlots",
            "geometry.maximumCandidateBlocks",
            "geometry.maximumCandidateWindows",
            "geometry.maximumCandidateAnchors",
            "geometry.maximumCandidateSessions",
            "geometry.maximumCandidateRecords",
            "geometry.maximumCandidateForcedItems",
            "geometry.maximumCandidateForcedBytes",
            "geometry.maximumCandidateForcedGas",
            "geometry.maximumEarlySealWindows",
            "geometry.canonicalHistoryCells",
            "geometry.eip2935HistoryBlocks", "geometry.maximumArmAgeBlocks",
            "geometry.seatCount", "geometry.standbyCount",
            "geometry.pendingCount", "geometry.bookSize",
            "geometry.maximumRewardClasses",
            "forcedEnvelope.claimWindowSeconds",
            "forcedEnvelope.maximumItemBytes",
            "forcedEnvelope.maximumItemAccountedGas",
            "forcedEnvelope.maximumPrefixItems",
            "forcedEnvelope.maximumPrefixBytes",
            "forcedEnvelope.maximumPrefixAccountedGas",
            "forcedEnvelope.queueDepth", "forcedEnvelope.maximumQueueCount",
            "forcedEnvelope.maximumRangeProofHashes",
            "bridge.maximumEnqueueDelaySeconds", "bridge.processTtlSeconds",
            "bridge.supportFinalityBlocks",
            "bridge.maximumDomainEntriesPerRelease",
            "bridge.refundCapsuleWords", "bridge.refundErc721Ids",
            "bridge.refundErc1155Pairs", "bridge.terminalAccumulatorDepth",
            "bridge.maximumTerminalCount",
            "bridge.registrationProofMaximumNodesPerPath",
            "bridge.registrationProofPathCount",
            "bridge.registrationProofMaximumTotalNodes",
            "bridge.registrationProofMaximumNodeBytes",
            "bridge.registrationProofMaximumBytes",
            "bridge.registrationProofMaximumGas", "rewards.claimWindowSeconds",
        }
        self.assertEqual(
            set(self.model.EXECUTABLE_CONSTANTS_V2), expected_paths
        )
        for path, expected in self.model.EXECUTABLE_CONSTANTS_V2.items():
            with self.subTest(path=path):
                profile = self.calibrated_profile()
                replacement = (
                    str(int(expected) - 1)
                    if isinstance(expected, str)
                    else expected + 1
                )
                self.model.set_path(profile, path, replacement)
                profile["profileId"] = None
                profile["profileId"] = (
                    "0x" + self.model.economic_profile_hash_v2(profile).hex()
                )
                self.assertIn(
                    f"{path} must equal the V2 executable constant {expected}",
                    self.model.production_blockers(profile),
                )

    def test_every_narrow_projected_numeric_rejects_its_first_unencodable_value(self):
        u8 = {
            "assets.builderLease.decimals",
            "geometry.maximumGenerationMovesPerWindow",
            "geometry.slotSeconds", "geometry.seatCount",
            "forcedEnvelope.queueDepth", "dataSession.maximumGcSteps",
            "dataSession.maximumBlobsPerPost",
        }
        u16 = {
            "geometry.maximumBuilders", "geometry.maximumAssignedSlots",
            "geometry.entryDelayWindows", "geometry.maximumLiveWindows",
            "geometry.maximumTrancheAheadWindows",
            "geometry.maximumLiabilityGenerations", "geometry.windowSlots",
            "seat.minimumAskImprovementBps",
            "dataSession.blobBaseFeeMultiplierBps",
            "dataSession.maximumLiveSessions",
            "dataSession.maximumLiveSessionsPerOwner",
            "dataSession.maximumRecordsPerSession",
            "geometry.canonicalHistoryCells",
        }
        u64 = {
            "builder.evidenceDelaySeconds", "builder.reorgMarginSeconds",
            "geometry.maximumParentGapSlots",
            "recovery.settlementWindowSeconds", "recovery.tipLagSeconds",
            "recovery.finalLagSeconds", "recovery.l1FinalityBlocks",
            "recovery.depthTimeMaxSeconds", "recovery.proofTimeMaxSeconds",
            "recovery.activationInclusionSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.clockSkewSeconds", "recovery.escapeOffsetSeconds",
            "recovery.forceDelaySeconds",
            "forcedEnvelope.maximumValiditySeconds",
            "seat.seatRunwaySeconds", "seat.minimumPrimaryTenureSeconds",
            "seat.minimumStandbyTenureSeconds", "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds", "seat.maximumInclusionSeconds",
            "seat.exitDelaySeconds", "seat.recoveryLagSeconds",
            "seat.slashLagSeconds", "seat.premiumClaimDelaySeconds",
            "seat.reorgStabilitySeconds", "seat.releaseChallengeSeconds",
            "seat.evidenceDelaySeconds", "seat.quoteMaturitySeconds",
            "seat.quoteMaturityBlocks", "seat.maximumStandbyLeaseSeconds",
            "dataSession.ttlSeconds",
            "dataSession.refundClaimWindowSeconds", "gasProfile.l2BlockGas",
            "rewards.claimWindowSeconds",
        }
        expected = ({path: 8 for path in u8}
                    | {path: 16 for path in u16}
                    | {path: 64 for path in u64})
        self.assertEqual(
            self.model.PROFILE_NARROW_NUMERIC_WIDTHS_V2, expected
        )
        for path, width in expected.items():
            with self.subTest(path=path, width=width):
                profile = self.calibrated_profile()
                self.model.set_path(profile, path, 1 << width)
                profile["profileId"] = None
                profile["profileId"] = (
                    "0x" + self.model.economic_profile_hash_v2(profile).hex()
                )
                self.assertIn(
                    f"{path} must fit uint{width}",
                    self.model.production_blockers(profile),
                )

    def test_builder_registry_hash_binds_every_dynamic_builder_and_reward_leaf(self):
        profile = self.calibrated_profile()
        expected = self.model.builder_registry_configuration_hash_v2(profile)
        self.assertEqual(
            self.model.execution_profile_economic_projection_v2(profile)[31],
            expected,
        )
        paths = (
            "assets.builderLease.chainId", "assets.builderLease.address",
            "assets.builderLease.runtimeHash", "assets.builderLease.decimals",
            "builder.leasePerWindowAtomic", "builder.maximumBondAtomic",
            "builder.reporterRewardCapAtomic", "builder.evidenceDelaySeconds",
            "builder.reorgMarginSeconds", "geometry.maximumBuilders",
            "geometry.maximumAssignedSlots", "geometry.entryDelayWindows",
            "geometry.maximumLiveWindows",
            "geometry.maximumTrancheAheadWindows",
            "geometry.maximumGenerationMovesPerWindow",
            "geometry.maximumLiabilityGenerations",
            "sinks.builderPenalty.address", "rewards.claimWindowSeconds",
            "rewards.classes.0.classId", "rewards.classes.0.name",
            "rewards.classes.0.fixedWei",
            "rewards.classes.0.perExecutionGasWei",
            "rewards.classes.0.perPublishedByteWei",
            "rewards.classes.0.capWei",
        )
        for path in paths:
            with self.subTest(path=path):
                mutated = copy.deepcopy(profile)
                old = self.model.get_path(mutated, path)
                if "address" in path.lower():
                    replacement = "0x" + "ab" * 20
                elif "runtimeHash" in path:
                    replacement = "0x" + "cd" * 32
                elif path.endswith("name"):
                    replacement = old + "-mutated"
                else:
                    replacement = int(old) + 1
                self.model.set_path(mutated, path, replacement)
                self.assertNotEqual(
                    self.model.builder_registry_configuration_hash_v2(mutated),
                    expected,
                )

    def test_exact_schema_rejects_unknown_and_missing_keys_at_any_level(self):
        cases = []
        unknown_top = copy.deepcopy(self.example)
        unknown_top["surprise"] = 1
        cases.append((unknown_top, "unknown key surprise"))
        missing_top = copy.deepcopy(self.example)
        del missing_top["bridge"]
        cases.append((missing_top, "missing key bridge"))
        unknown_nested = copy.deepcopy(self.example)
        unknown_nested["seat"]["surprise"] = 1
        cases.append((unknown_nested, "seat: unknown key surprise"))
        missing_nested = copy.deepcopy(self.example)
        del missing_nested["forcedEnvelope"]["maximumPrefixAccountedGas"]
        cases.append(
            (
                missing_nested,
                "forcedEnvelope: missing key maximumPrefixAccountedGas",
            )
        )
        for profile, expected in cases:
            with self.subTest(expected=expected):
                self.assertIn(expected, self.model.validate_schema(profile))

    def test_expected_schema_is_the_complete_permitted_key_tree(self):
        def descriptor(rule):
            if rule.kind == "exact":
                return exact_rule(rule.exact)
            if rule.kind in ("uint", "decimal"):
                return (rule.kind, rule.nullable, rule.minimum, rule.maximum)
            return (rule.kind, rule.nullable)

        def flatten_schema(tree, prefix=""):
            flattened = {}
            for key, child in tree.items():
                path = f"{prefix}.{key}" if prefix else key
                if isinstance(child, dict):
                    flattened.update(flatten_schema(child, path))
                else:
                    flattened[path] = descriptor(child)
            return flattened

        def flatten_fixture(tree, prefix=""):
            flattened = set()
            for key, child in tree.items():
                path = f"{prefix}.{key}" if prefix else key
                if isinstance(child, dict):
                    flattened.update(flatten_fixture(child, path))
                else:
                    flattened.add(path)
            return flattened

        actual_rules = flatten_schema(self.model.EXPECTED_SCHEMA)
        actual_rules.update(
            flatten_schema(self.model.REWARD_CLASS_SCHEMA, "rewards.classes[]")
        )
        self.assertEqual(actual_rules, EXPECTED_SCHEMA_RULES)

        fixture_paths = flatten_fixture(self.example)
        expected_fixture_paths = {
            path for path in EXPECTED_SCHEMA_RULES if "[]" not in path
        }
        self.assertEqual(fixture_paths, expected_fixture_paths)

    def test_independent_schema_oracle_detects_joint_field_deletion(self):
        def delete_path(tree, path):
            components = path.split(".")
            parent = tree
            for component in components[:-1]:
                parent = parent[component]
            del parent[components[-1]]

        def flatten_paths(tree, prefix=""):
            flattened = set()
            for key, child in tree.items():
                path = f"{prefix}.{key}" if prefix else key
                if isinstance(child, dict):
                    flattened.update(flatten_paths(child, path))
                else:
                    flattened.add(path)
            return flattened

        expected_fixture_paths = {
            path for path in EXPECTED_SCHEMA_RULES if "[]" not in path
        }
        for path in sorted(expected_fixture_paths):
            schema = copy.deepcopy(self.model.EXPECTED_SCHEMA)
            fixture = copy.deepcopy(self.example)
            delete_path(schema, path)
            delete_path(fixture, path)
            with self.subTest(path=path):
                self.assertNotEqual(flatten_paths(schema), expected_fixture_paths)
                self.assertNotEqual(flatten_paths(fixture), expected_fixture_paths)
                self.assertNotIn(path, flatten_paths(schema))
                self.assertNotIn(path, flatten_paths(fixture))

        expected_reward_paths = {
            path for path in EXPECTED_SCHEMA_RULES if "[]" in path
        }
        for path in sorted(expected_reward_paths):
            reward_schema = copy.deepcopy(self.model.REWARD_CLASS_SCHEMA)
            delete_path(reward_schema, path.removeprefix("rewards.classes[]."))
            observed = {
                f"rewards.classes[].{leaf}" for leaf in flatten_paths(reward_schema)
            }
            with self.subTest(path=path):
                self.assertNotEqual(observed, expected_reward_paths)
                self.assertNotIn(path, observed)

    def test_fixed_normative_constants_and_seat_geometry_are_exact(self):
        fixed = {
            "geometry.seatCount": 4,
            "geometry.standbyCount": 3,
            "geometry.pendingCount": 4,
            "forcedEnvelope.queueDepth": 64,
            "forcedEnvelope.maximumRangeProofHashes": 257,
            "bridge.terminalAccumulatorDepth": 64,
            "gasProfile.l2BlockGas": 30000000,
            "gasProfile.steadyAnchorGas": 1000000,
            "gasProfile.steadyForcedGas": 20000000,
            "gasProfile.activationAnchorGas": 12000000,
            "gasProfile.activationForcedGas": 13000000,
            "gasProfile.systemMarginGas": 5000000,
            "gasProfile.minimumForceAccountedGas": 21000,
            "dataSession.ttlSeconds": 86400,
            "dataSession.refundClaimWindowSeconds": 86400,
            "dataSession.maximumLiveSessions": 1024,
            "dataSession.maximumLiveSessionsPerOwner": 2,
            "dataSession.maximumRecordsPerSession": 2100,
            "dataSession.maximumGcSteps": 8,
            "dataSession.maximumBlobsPerPost": 6,
            "bridge.registrationProofMaximumNodesPerPath": 66,
            "bridge.registrationProofPathCount": 2,
            "bridge.registrationProofMaximumTotalNodes": 132,
            "bridge.registrationProofMaximumNodeBytes": 600,
            "bridge.registrationProofMaximumBytes": 80000,
            "bridge.registrationProofMaximumGas": 8000000,
        }
        for path, expected in fixed.items():
            self.assertEqual(oracle_get(self.example, path), expected, path)
            profile = copy.deepcopy(self.example)
            self.model.set_path(profile, path, expected + 1)
            with self.subTest(path=path):
                self.assertIn(
                    f"{path} must equal {expected}",
                    self.model.validate_schema(profile),
                )

    def test_numeric_exact_fields_reject_json_float_and_boolean_aliases(self):
        numeric_exact = {
            path: descriptor[2]
            for path, descriptor in EXPECTED_SCHEMA_RULES.items()
            if descriptor[0] == "exact" and descriptor[1] == "int"
        }
        self.assertEqual(len(numeric_exact), 26)
        for path, exact in numeric_exact.items():
            for replacement in (float(exact), True, False):
                profile = copy.deepcopy(self.example)
                self.model.set_path(profile, path, replacement)
                with tempfile.NamedTemporaryFile(
                    mode="w", suffix=".json", encoding="utf-8"
                ) as stream:
                    json.dump(profile, stream)
                    stream.flush()
                    loaded = self.model.load_economic_profile(stream.name)
                expected_error = f"{path} must equal {exact}"
                with self.subTest(path=path, replacement=repr(replacement)):
                    self.assertIn(
                        expected_error,
                        self.model.validate_schema(loaded),
                    )
                    self.assertIn(
                        f"schema error: {expected_error}",
                        self.model.production_blockers(loaded),
                    )

    def test_normative_capacities_reject_zero(self):
        positive_paths = (
            "geometry.slotSeconds",
            "geometry.windowSlots",
            "geometry.l1SlotSeconds",
            "geometry.maximumBuilders",
            "geometry.maximumAssignedSlots",
            "geometry.maximumLiveWindows",
            "geometry.maximumLiabilityGenerations",
            "geometry.maximumCandidateBlocks",
            "geometry.maximumCandidateWindows",
            "geometry.maximumCandidateSessions",
            "geometry.maximumCandidateRecords",
            "geometry.maximumCandidateForcedItems",
            "geometry.maximumCandidateForcedBytes",
            "geometry.maximumCandidateForcedGas",
            "forcedEnvelope.maximumItemBytes",
            "forcedEnvelope.maximumItemAccountedGas",
            "forcedEnvelope.maximumPrefixItems",
            "forcedEnvelope.maximumPrefixBytes",
            "forcedEnvelope.maximumPrefixAccountedGas",
            "bridge.maximumDomainEntriesPerRelease",
            "bridge.refundCapsuleWords",
            "bridge.refundErc721Ids",
            "bridge.refundErc1155Pairs",
            "seat.maximumInclusionSeconds",
            "recovery.settlementWindowSeconds",
            "recovery.tipLagSeconds",
            "recovery.finalLagSeconds",
            "recovery.l1FinalityBlocks",
            "recovery.depthTimeMaxSeconds",
            "recovery.proofTimeMaxSeconds",
            "recovery.proofMarginSeconds",
            "recovery.activationInclusionSeconds",
            "recovery.submissionInclusionSeconds",
            "recovery.escapeOffsetSeconds",
            "recovery.forceDelaySeconds",
        )
        for path in positive_paths:
            profile = self.calibrated_profile()
            self.model.set_path(profile, path, 0)
            with self.subTest(path=path):
                self.assertIn(
                    f"{path} must be a positive integer",
                    self.model.validate_schema(profile),
                )

    def test_at_least_one_ask_improvement_dimension_is_positive(self):
        profile = self.calibrated_profile()
        profile["seat"]["minimumAskImprovementWeiPerSecond"] = "0"
        profile["seat"]["minimumAskImprovementBps"] = "0"
        self.assertIn(
            "seat ask improvement must be positive",
            self.model.production_blockers(profile),
        )
        profile["seat"]["minimumAskImprovementWeiPerSecond"] = "1"
        self.assertNotIn(
            "seat ask improvement must be positive",
            self.model.production_blockers(profile),
        )

    def test_minimum_ask_improvement_bps_rejects_above_one_hundred_percent(self):
        profile = self.calibrated_profile()
        profile["seat"]["minimumAskImprovementBps"] = "10001"
        self.assertIn(
            "seat.minimumAskImprovementBps must be <= 10000",
            self.model.validate_schema(profile),
        )

    def test_security_critical_economic_fields_reject_zero(self):
        decimal_paths = (
            "builder.leasePerWindowAtomic",
            "builder.maximumBondAtomic",
            "dataSession.refundableBondWei",
            "dataSession.baseRentWei",
            "forcedEnvelope.fixedIngressWei",
            "forcedEnvelope.executionWeiPerAccountedGas",
            "forcedEnvelope.proofWeiPerAccountedGas",
            "forcedEnvelope.permanentWeiPerByte",
            "forcedEnvelope.maximumAcceptedFeeWei",
            "forcedEnvelope.maximumQueueCount",
            "bridge.maximumTerminalCount",
            "seat.slaBondWei",
            "seat.maximumAskWeiPerSecond",
            "seat.collusionSafetyMarginWei",
        )
        for path in decimal_paths:
            profile = self.calibrated_profile()
            self.model.set_path(profile, path, "0")
            with self.subTest(path=path):
                self.assertTrue(
                    any(
                        error.startswith(path)
                        for error in self.model.validate_schema(profile)
                    )
                )

        integer_paths = (
            "seat.quoteMaturitySeconds",
            "seat.quoteMaturityBlocks",
            "seat.minimumPrimaryTenureSeconds",
            "seat.minimumStandbyTenureSeconds",
            "seat.handoverDelaySeconds",
            "seat.stageGraceSeconds",
            "seat.handoverExecutionBufferSeconds",
            "seat.exitDelaySeconds",
            "seat.releaseChallengeSeconds",
            "seat.evidenceDelaySeconds",
            "seat.premiumClaimDelaySeconds",
            "seat.seatRunwaySeconds",
        )
        for path in integer_paths:
            profile = self.calibrated_profile()
            self.model.set_path(profile, path, 0)
            with self.subTest(path=path):
                self.assertIn(
                    f"{path} must be a positive integer",
                    self.model.validate_schema(profile),
                )

    def test_non_one_second_slots_use_dimensionally_correct_relations(self):
        relations = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        profile = self.calibrated_profile()
        profile["geometry"]["slotSeconds"] = 2

        self.assertFalse(relations["parent-gap-final-lag-identity"].evaluate(profile))
        profile["geometry"]["maximumParentGapSlots"] = 1800
        self.assertTrue(relations["parent-gap-final-lag-identity"].evaluate(profile))

        profile["geometry"]["maximumCandidateWindows"] = 4
        self.assertFalse(relations["parent-gap-candidate-cap"].evaluate(profile))
        profile["geometry"]["maximumCandidateWindows"] = 5
        self.assertTrue(relations["parent-gap-candidate-cap"].evaluate(profile))

        profile["geometry"]["maximumLiveWindows"] = 200
        self.assertTrue(relations["liability-residence"].evaluate(profile))
        profile["geometry"]["maximumLiveWindows"] = oracle_schedule_ring(profile)
        self.assertTrue(relations["schedule-ring-capacity"].evaluate(profile))

        profile["geometry"]["snapshotEpochs"] = 8
        self.assertFalse(
            relations["snapshot-finality-seal-lookahead"].evaluate(profile)
        )

    def test_boolean_is_never_accepted_as_an_integer(self):
        for path in (
            "geometry.slotSeconds",
            "assets.builderLease.chainId",
            "seat.maximumInclusionSeconds",
            "rewards.classes.0.classId",
        ):
            profile = self.calibrated_profile()
            self.model.set_path(profile, path, True)
            with self.subTest(path=path):
                self.assertTrue(
                    any(
                        "integer" in error
                        for error in self.model.validate_schema(profile)
                    )
                )

    def test_negative_integers_are_rejected(self):
        profile = self.calibrated_profile()
        profile["geometry"]["slotSeconds"] = -1
        self.assertIn(
            "geometry.slotSeconds must be a positive integer",
            self.model.validate_schema(profile),
        )

    def test_malformed_decimal_strings_are_rejected(self):
        malformed = ("", "00", "+1", "-1", "1.0", " 1", "1e3", True, 1)
        for value in malformed:
            profile = self.calibrated_profile()
            profile["seat"]["slaBondWei"] = value
            with self.subTest(value=value):
                self.assertIn(
                    "seat.slaBondWei must be a canonical uint256 decimal string",
                    self.model.validate_schema(profile),
                )

    def test_decimal_string_uint256_boundary(self):
        profile = self.calibrated_profile()
        profile["seat"]["slaBondWei"] = str(self.model.UINT256_MAX)
        self.assertEqual(self.model.validate_schema(profile), ())
        profile["seat"]["slaBondWei"] = str(self.model.UINT256_MAX + 1)
        self.assertIn(
            "seat.slaBondWei must be a canonical uint256 decimal string",
            self.model.validate_schema(profile),
        )

    def test_huge_decimal_is_rejected_without_integer_conversion(self):
        profile = self.calibrated_profile()
        profile["seat"]["slaBondWei"] = "9" * 5000
        self.assertIn(
            "seat.slaBondWei must be a canonical uint256 decimal string",
            self.model.validate_schema(profile),
        )
        blockers = self.model.production_blockers(profile)
        self.assertTrue(blockers)

    def test_validation_is_total_for_non_objects_and_mixed_key_types(self):
        for malformed in (
            [],
            ["profile"],
            {1: "integer key", "status": []},
            {"status": "CALIBRATED", 2: {"nested": True}},
        ):
            with self.subTest(malformed=repr(malformed)):
                first = self.model.production_blockers(malformed)
                second = self.model.production_blockers(malformed)
                self.assertIsInstance(first, tuple)
                self.assertTrue(first)
                self.assertEqual(first, second)

    def test_unit_and_asset_bindings_are_exact(self):
        profile = copy.deepcopy(self.example)
        profile["units"]["nativeRate"] = "gwei/second"
        profile["sinks"]["builderPenalty"]["asset"] = "NATIVE_ETH"
        profile["sinks"]["seatPenalty"]["asset"] = "BUILDER_LEASE"
        profile["sinks"]["bridgeSurplus"]["asset"] = "BUILDER_LEASE"
        errors = self.model.validate_schema(profile)
        self.assertIn("units.nativeRate must equal wei/second", errors)
        self.assertIn(
            "sinks.builderPenalty.asset must equal BUILDER_LEASE", errors
        )
        self.assertIn("sinks.seatPenalty.asset must equal NATIVE_ETH", errors)
        self.assertIn("sinks.bridgeSurplus.asset must equal NATIVE_ETH", errors)

    def test_nested_or_duplicate_sink_sources_are_rejected(self):
        nested = copy.deepcopy(self.example)
        nested["dataSession"]["rentSink"] = "0x" + "77" * 20
        self.assertIn(
            "dataSession: unknown key rentSink",
            self.model.validate_schema(nested),
        )

        bridge_local = copy.deepcopy(self.example)
        bridge_local["bridge"]["surplusSink"] = "0x" + "88" * 20
        self.assertIn(
            "bridge: unknown key surplusSink",
            self.model.validate_schema(bridge_local),
        )

        malformed_sink = copy.deepcopy(self.example)
        malformed_sink["sinks"]["bridgeSurplus"]["beneficiary"] = (
            "0x" + "99" * 20
        )
        self.assertIn(
            "sinks.bridgeSurplus: unknown key beneficiary",
            self.model.validate_schema(malformed_sink),
        )

        duplicate_json = "{\"schema\":1,\"schema\":2}"
        with tempfile.NamedTemporaryFile("w", suffix=".json") as stream:
            stream.write(duplicate_json)
            stream.flush()
            with self.assertRaisesRegex(ValueError, "duplicate key schema"):
                self.model.load_economic_profile(stream.name)

    def test_production_rejects_null_and_zero_identities(self):
        null_blockers = self.model.production_blockers(self.example)
        for blocker in (
            "profileId must be non-null",
            "measurementCommit must be non-null",
            "assets.builderLease.address must be non-null",
            "sinks.builderPenalty.address must be non-null",
            "sinks.bridgeSurplus.address must be non-null",
        ):
            self.assertIn(blocker, null_blockers)

        profile = self.calibrated_profile()
        profile["profileId"] = "0x" + "00" * 32
        profile["assets"]["builderLease"]["address"] = "0x" + "00" * 20
        profile["sinks"]["bridgeSurplus"]["address"] = "0x" + "00" * 20
        blockers = self.model.production_blockers(profile)
        self.assertIn("profileId must be nonzero", blockers)
        self.assertIn("assets.builderLease.address must be nonzero", blockers)
        self.assertIn("sinks.bridgeSurplus.address must be nonzero", blockers)

    def test_production_requires_unique_sink_addresses(self):
        expected_sink_paths = (
            "sinks.builderPenalty.address",
            "sinks.dataRent.address",
            "sinks.seatPenalty.address",
            "sinks.forcedExpiry.address",
            "sinks.bridgeSurplus.address",
        )
        self.assertEqual(self.model._SINK_ADDRESS_PATHS, expected_sink_paths)

        profile = self.calibrated_profile()
        profile["sinks"]["bridgeSurplus"]["address"] = profile["sinks"][
            "dataRent"
        ]["address"]
        self.assertIn(
            "sink addresses must be unique",
            self.model.production_blockers(profile),
        )

        profile["sinks"]["bridgeSurplus"]["address"] = "0x" + "0a" * 20
        self.assertNotIn(
            "sink addresses must be unique",
            self.model.production_blockers(profile),
        )

    def test_production_rejects_inconsistent_chain_ids(self):
        profile = self.calibrated_profile()
        profile["assets"]["nativeCustody"]["chainId"] = 168
        self.assertIn(
            "asset chain IDs must equal",
            self.model.production_blockers(profile),
        )

    def test_reward_classes_are_strict_complete_sorted_and_unique(self):
        profile = self.calibrated_profile()
        second = copy.deepcopy(profile["rewards"]["classes"][0])
        second["classId"] = 0
        profile["rewards"]["classes"].append(second)
        self.assertIn(
            "rewards.classes must be strictly sorted by unique classId",
            self.model.validate_schema(profile),
        )
        profile = self.calibrated_profile()
        del profile["rewards"]["classes"][0]["capWei"]
        self.assertIn(
            "rewards.classes.0: missing key capWei",
            self.model.validate_schema(profile),
        )

    def test_production_requires_exact_tier_reward_classes(self):
        profile = self.calibrated_profile()
        profile["rewards"]["classes"].pop()
        self.assertIn(
            "rewards.classes must define exactly tier class IDs 1, 2, and 3",
            self.model.production_blockers(profile),
        )

    def test_checked_u256_arithmetic_boundaries_and_type_checks(self):
        self.assertEqual(
            self.model.checked_add_u256(self.model.UINT256_MAX, 0),
            self.model.UINT256_MAX,
        )
        self.assertEqual(
            self.model.checked_mul_u256(self.model.UINT256_MAX, 1),
            self.model.UINT256_MAX,
        )
        self.assertEqual(
            self.model.ceil_div_u256(self.model.UINT256_MAX, 1),
            self.model.UINT256_MAX,
        )
        for function, operands in (
            (self.model.checked_add_u256, (self.model.UINT256_MAX, 1)),
            (self.model.checked_mul_u256, (self.model.UINT256_MAX, 2)),
            (self.model.checked_mul_u256, (self.model.UINT256_MAX + 1, 0)),
            (self.model.checked_add_u256, (self.model.UINT256_MAX + 1, 0)),
            (self.model.checked_add_u256, (-1, 1)),
            (self.model.checked_mul_u256, (True, 1)),
            (self.model.ceil_div_u256, (1, 0)),
            (self.model.ceil_div_u256, (True, 1)),
        ):
            with self.subTest(function=function.__name__, operands=operands):
                with self.assertRaises(ValueError):
                    function(*operands)

    def test_every_relation_addition_and_multiplication_is_checked(self):
        overflow_cases = (
            ("builder-bond-product", {"geometry.maximumAssignedSlots": UINT256_MAX}),
            ("liability-residence", {"builder.evidenceDelaySeconds": UINT256_MAX}),
            (
                "liability-residence",
                {"geometry.windowSlots": UINT256_MAX, "geometry.slotSeconds": 2},
            ),
            (
                "liability-generation-capacity",
                {"geometry.maximumGenerationMovesPerWindow": UINT256_MAX},
            ),
            (
                "snapshot-finality-seal-lookahead",
                {"geometry.finalityEpochs": UINT256_MAX},
            ),
            (
                "snapshot-finality-seal-lookahead",
                {"geometry.lookaheadSlots": UINT256_MAX},
            ),
            ("lookahead-window-slack", {"geometry.windowSlots": UINT256_MAX}),
            (
                "parent-gap-final-lag-identity",
                {
                    "geometry.maximumParentGapSlots": UINT256_MAX,
                    "geometry.slotSeconds": 2,
                },
            ),
            (
                "parent-gap-candidate-cap",
                {"recovery.clockSkewSeconds": UINT256_MAX},
            ),
            (
                "candidate-block-window-cap",
                {"geometry.maximumCandidateWindows": UINT256_MAX},
            ),
            ("tip-inclusion-skew", {"recovery.submissionInclusionSeconds": UINT256_MAX}),
            (
                "final-lag-recovery-geometry",
                {"recovery.activationInclusionSeconds": UINT256_MAX},
            ),
            (
                "escape-offset-depth-proof-margin",
                {"recovery.depthTimeMaxSeconds": UINT256_MAX},
            ),
            (
                "force-delay-settlement-inclusion",
                {"recovery.settlementWindowSeconds": UINT256_MAX},
            ),
            (
                "forced-range-proof-boundary",
                {"geometry.maximumCandidateForcedItems": UINT256_MAX},
            ),
            ("refund-erc1155-word-cap", {"bridge.refundErc1155Pairs": UINT256_MAX}),
            ("kind0-validity-lower-bound", {"recovery.finalLagSeconds": UINT256_MAX}),
            ("kind1-enqueue-lower-bound", {"recovery.finalLagSeconds": UINT256_MAX}),
            (
                "bridge-process-ttl-lower-bound",
                {"bridge.maximumEnqueueDelaySeconds": UINT256_MAX},
            ),
            ("support-finality-reorg-depth", {"recovery.l1FinalityBlocks": UINT256_MAX}),
            (
                "data-ttl-recovery-lower-bound",
                {"recovery.settlementWindowSeconds": UINT256_MAX},
            ),
            (
                "canonical-history-reorg-capacity",
                {"seat.maximumInclusionSeconds": UINT256_MAX},
            ),
            ("eip2935-replay-horizon", {"builder.evidenceDelaySeconds": UINT256_MAX}),
            ("schedule-ring-capacity", {"builder.evidenceDelaySeconds": UINT256_MAX}),
            (
                "schedule-ring-capacity",
                {"geometry.windowSlots": UINT256_MAX, "geometry.slotSeconds": 2},
            ),
            (
                "seat-book-capacity",
                {"geometry.seatCount": UINT256_MAX},
            ),
            (
                "seat-runway-primary-handover-sla",
                {"seat.minimumPrimaryTenureSeconds": UINT256_MAX},
            ),
            (
                "seat-maximum-reserve-u256",
                {"seat.maximumAskWeiPerSecond": UINT256_MAX},
            ),
            (
                "handover-buffer-delay-grace-inclusion",
                {"seat.handoverDelaySeconds": UINT256_MAX},
            ),
            ("sla-bond-claim-tail", {"seat.maximumAskWeiPerSecond": UINT256_MAX}),
            ("sla-bond-collusion", {"seat.maximumAskWeiPerSecond": UINT256_MAX}),
            ("steady-gas-envelope", {"gasProfile.steadyAnchorGas": UINT256_MAX}),
            (
                "activation-gas-envelope",
                {"gasProfile.activationAnchorGas": UINT256_MAX},
            ),
            (
                "registration-proof-total-nodes",
                {"bridge.registrationProofMaximumNodesPerPath": UINT256_MAX},
            ),
            (
                "registration-proof-byte-capacity",
                {"bridge.registrationProofMaximumTotalNodes": UINT256_MAX},
            ),
        )
        relations = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        self.assertEqual({name for name, _ in overflow_cases} - set(relations), set())
        for name, mutations in overflow_cases:
            profile = self.calibrated_profile()
            for path, value in mutations.items():
                self.model.set_path(profile, path, value)
            with self.subTest(relation=name, mutations=mutations):
                with self.assertRaises(ValueError):
                    relations[name].evaluate(profile)

    def test_profile_relations_inventory_is_complete_and_latex_anchored(self):
        expected = {spec["name"]: spec for spec in EXPECTED_RELATION_SPECS}
        actual = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        self.assertEqual(len(expected), 59)
        self.assertEqual(set(actual), set(expected))
        tex = MAIN_TEX.read_text()
        profile = self.calibrated_profile()
        for name, spec in expected.items():
            relation = actual[name]
            with self.subTest(relation=name):
                self.assertEqual(relation.source_anchor, spec["source_anchor"])
                self.assertEqual(relation.operands, spec["operands"])
                self.assertEqual(relation.operator, spec["operator"])
                self.assertEqual(relation.boundary_path, spec["boundary_path"])
                self.assertEqual(
                    relation.boundary_expected, spec["boundary_expected"]
                )
                self.assertEqual(
                    relation.boundary_value(profile),
                    spec["boundary_value"](profile),
                )
                self.assertTrue(relation.operands)
                self.assertTrue(callable(relation.evaluate))
                self.assertIn(f"\\label{{{relation.source_anchor}}}", tex)

    def test_every_relation_has_one_below_equal_one_above_behavior(self):
        relations = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        for spec in EXPECTED_RELATION_SPECS:
            relation = relations[spec["name"]]
            profile = self.calibrated_profile()
            boundary = spec["boundary_value"](profile)
            self.assertGreater(boundary, 0, relation.name)
            observed = []
            for value in (boundary - 1, boundary, boundary + 1):
                candidate = copy.deepcopy(profile)
                self.model.set_path(candidate, relation.boundary_path, value)
                try:
                    observed.append(relation.evaluate(candidate))
                except ValueError:
                    observed.append(False)
            with self.subTest(relation=relation.name, boundary=boundary):
                self.assertEqual(tuple(observed), spec["boundary_expected"])

    def test_relation_boundary_updates_preserve_decimal_json_types(self):
        profile = self.calibrated_profile()
        relations = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        for spec in EXPECTED_RELATION_SPECS:
            relation = relations[spec["name"]]
            current = self.model.get_path(profile, relation.boundary_path)
            if isinstance(current, str) and current.isdecimal():
                candidate = copy.deepcopy(profile)
                self.model.set_path(
                    candidate,
                    relation.boundary_path,
                    spec["boundary_value"](candidate),
                )
                with self.subTest(relation=relation.name):
                    self.assertIsInstance(
                        self.model.get_path(candidate, relation.boundary_path), str
                    )
                    self.assertEqual(self.model.validate_schema(candidate), ())

    def test_production_evaluates_every_profile_relation(self):
        relations = {
            relation.name: relation for relation in self.model.PROFILE_RELATIONS
        }
        for spec in EXPECTED_RELATION_SPECS:
            relation = relations[spec["name"]]
            profile = self.calibrated_profile()
            boundary = spec["boundary_value"](profile)
            failing_delta = spec["boundary_expected"].index(False) - 1
            self.model.set_path(
                profile,
                relation.boundary_path,
                boundary + failing_delta,
            )
            with self.subTest(relation=relation.name):
                blockers = self.model.production_blockers(profile)
                self.assertTrue(
                    f"relation {relation.name} failed" in blockers
                    or f"relation {relation.name} overflow" in blockers,
                    blockers,
                )

    def test_relation_overflow_is_a_stable_production_blocker(self):
        profile = self.calibrated_profile()
        profile["seat"]["maximumAskWeiPerSecond"] = str(
            self.model.UINT256_MAX
        )
        blockers = self.model.production_blockers(profile)
        self.assertIn("relation seat-maximum-reserve-u256 overflow", blockers)
        self.assertIn("relation sla-bond-claim-tail overflow", blockers)
        self.assertIn("relation sla-bond-collusion overflow", blockers)

    def test_reporter_reward_split_caps_reward_and_routes_only_remainder(self):
        profile = self.calibrated_profile()
        below = self.model.reporter_reward_split(profile, 40)
        self.assertEqual(below["reporterRewardAtomic"], 40)
        self.assertEqual(below["builderPenaltyAtomic"], 0)
        above = self.model.reporter_reward_split(profile, 140)
        self.assertEqual(above["reporterRewardAtomic"], 100)
        self.assertEqual(above["builderPenaltyAtomic"], 40)
        self.assertEqual(
            above["builderPenaltySink"], profile["sinks"]["builderPenalty"]
        )
        self.assertNotIn("seatPenalty", above)
        self.assertEqual(
            above["reporterRewardAtomic"] + above["builderPenaltyAtomic"],
            140,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
