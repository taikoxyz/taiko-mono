#!/usr/bin/env python3
"""Golden vectors for Slot-Chain v2.25 consensus commitments.

This fixture covers the commitments that cross Solidity, clients and circuits:
EIP-712 domain/struct/digest, canonical/base identity, ABI statement hashing,
registry/admission/entry/tranche trees, the depth-64 forced vector and canonical
range proof, session MMR, data chunks/manifests, dispositions, recovery ID and
blob framing. It intentionally does not pretend that zero KZG bytes are a valid
opening; a valid c-kzg vector remains a production conformance gate.

The executionProfileHash values below are test fixtures, not the missing
initial executable profile or evidence that its bytecode/verifier bindings
exist. Section 13 of the design records that blocker explicitly.
"""

from __future__ import annotations

import ast
import runpy
from dataclasses import dataclass, fields, replace
from functools import lru_cache
from pathlib import Path

LOOK = runpy.run_path(str(Path(__file__).with_name("lookahead-model.py")))
keccak256 = LOOK["keccak256"]
u16 = LOOK["u16"]
u64 = LOOK["u64"]
u256 = LOOK["u256"]

BLS_MODULUS = int("73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001", 16)
UINT64_MAX = (1 << 64) - 1
UINT32_MAX = (1 << 32) - 1
MAX_MIGRATION_PROOF_BYTES = 131_072
LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL = 10
LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL = 21
LEGACY_MAX_PROPOSAL_ROW_BYTES = 3_808
LEGACY_MAX_FORCED_ROW_BYTES = 256
LEGACY_MAX_SCAN_BYTES = 4_194_304
COMPONENT_CONFIG_GETTER_GAS_LIMIT = 50_000
SOURCE_CREDIT_READ_GAS_LIMIT = 200_000
FORCE_DEPTH = 64
TERMINAL_DEPTH = 64

TYPE_STRING = (
    "SlotChainBlock(uint256 settlementChainId,uint256 l2ChainId,"
    "uint256 protocolVersion,address verifyingContract,"
    "uint64 slot,bytes32 parentHash,bytes32 blockHash,bytes32 stateRoot,bytes32 bodyRoot,"
    "uint64 anchorNumber,bytes32 anchorHash,bytes32 forceRoot,uint64 forceCutoff,"
    "uint64 messageStart,uint64 messageEnd,bytes32 dataManifestRoot,address coinbase,"
    "uint8 tier,bytes32 contextId,uint64 admissionVersion,bytes32 admissionRoot,"
    "uint64 episode,uint64 recoveryRevision,"
    "bytes32 recoveryId)"
)
DOMAIN_TYPE = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"

D_REG_LEAF = b"slot-chain-registry-leaf-v1"
D_REG_NODE = b"slot-chain-registry-node-v1"
D_ADM_LEAF = b"slot-chain-admission-leaf-v1"
D_ADM_NODE = b"slot-chain-admission-node-v1"
D_ENTRY_LEAF = b"slot-chain-entry-leaf-v1"
D_ENTRY_NODE = b"slot-chain-entry-node-v1"
D_TRANCHE_LEAF = b"slot-chain-tranche-leaf-v1"
D_TRANCHE_NODE = b"slot-chain-tranche-node-v1"
D_FORCE_USER = b"slot-chain-force-user-v2"
D_FORCE_BRIDGE = b"slot-chain-force-bridge-v11"
D_FORCE_DESCRIPTOR_LIST = b"slot-chain-force-descriptor-list-v2"
D_FORCE_EMPTY = b"slot-chain-force-empty-v2"
D_FORCE_NODE = b"slot-chain-force-node-v2"
D_FORCE_ROOT = b"slot-chain-force-root-v2"
D_FORCED_DESCRIPTOR_SCHEMA = b"slot-chain-force-descriptor-schema-v11"
D_FORCED_QUEUE_CONFIG = b"slot-chain-forced-queue-config-v1"
D_DATA_SESSION_CONFIG = b"slot-chain-data-session-config-v1"
D_MMR_LEAF = b"slot-chain-data-leaf-v1"
D_MMR_NODE = b"slot-chain-data-node-v1"
D_MMR_BAG = b"slot-chain-data-bag-v1"
D_MANIFEST_EMPTY = b"slot-chain-manifest-empty-v1"
D_MANIFEST_LEAF = b"slot-chain-manifest-leaf-v1"
D_MANIFEST_NODE = b"slot-chain-manifest-node-v1"
D_MANIFEST_ROOT = b"slot-chain-manifest-root-v1"
D_DISPOSITIONS = b"slot-chain-dispositions-v1"
D_BRIDGE_RESULT = b"slot-chain-bridge-credit-result-v11"
D_BRIDGE_CREDIT_ID = b"slot-chain-bridge-credit-id-v6"
D_BRIDGE_ESCROW = b"slot-chain-bridge-escrow-v2"
D_INBOX_CREDIT_SLOT = b"slot-chain-inbox-credit-slot-v4"
D_INBOX_ROUTE_CONFIG = b"slot-chain-inbox-route-config-v1"
D_TERMINAL_EMPTY = b"slot-chain-terminal-empty-v2"
D_TERMINAL_LEAF = b"slot-chain-terminal-leaf-v2"
D_TERMINAL_NODE = b"slot-chain-terminal-node-v2"
D_TERMINAL_ROOT = b"slot-chain-terminal-root-v2"
D_LIQUIDITY_SETTLEMENT = b"slot-chain-liquidity-settlement-v1"
D_LIQUIDITY_TICKET = b"slot-chain-liquidity-ticket-v2"
D_LIQUIDITY_ATTEMPT = b"slot-chain-native-liquidity-attempt-v1"
D_LIQUIDITY_ACCEPTANCE = b"slot-chain-native-liquidity-acceptance-v3"
D_SOURCE_DOMAIN = b"slot-chain-source-domain-v4"
D_DESTINATION_DOMAIN = b"slot-chain-destination-domain-v7"
D_BRIDGE_EXECUTION = b"slot-chain-source-bridge-execution-v4"
D_DESTINATION_BRIDGE_EXECUTION = b"slot-chain-destination-bridge-execution-v3"
D_BRIDGE_KERNEL = b"slot-chain-bridge-kernel-profile-v2"
D_COMPONENT_CONFIG = b"slot-chain-component-config-v1"
DATA_SESSION_FUNCTION_SIGNATURES = {
    "session_open_selector": b"openSession(uint16,uint64)",
    "session_post_selector": (
        b"postData(bytes32,(bytes32,uint16,uint16,uint16,uint32,bytes32,"
        b"bytes32,bytes32,bytes16,bytes32,bytes16)[])"
    ),
    "session_seal_selector": b"sealSession(bytes32)",
    "session_maintain_selector": b"maintainDataSessions()",
    "session_claim_selector": b"claimSessionBond(bytes32,address)",
    "session_sweep_selector": b"sweepSessionSurplus()",
    "session_cell_selector": b"dataSessionCellV1(uint16)",
    "session_by_id_selector": b"dataSessionByIdV1(bytes32)",
    "session_accounting_selector": b"dataSessionAccountingV1()",
}
ROUTER_SESSION_GATE_FUNCTION_SIGNATURES = {
    "active_settlement_state_selector": b"activeSettlementStateV1()",
    "migration_readiness_selector": b"migrationReadinessV1()",
    "mark_migration_ready_selector": b"markMigrationReadyV1(uint64)",
}
ROUTER_SESSION_GATE_MAGICS = {
    "active_settlement_state_magic": b"ASR1",
    "migration_readiness_magic": b"MRS1",
    "mark_migration_ready_magic": b"MRDY",
}
DATA_SESSION_EVENT_SIGNATURES = {
    "session_opened_topic": (
        b"SessionOpened(bytes32,address,uint16,uint64,uint64,uint256,uint256)"
    ),
    "data_record_appended_topic": (
        b"DataRecordAppended(bytes32,uint16,bytes32,bytes32)"
    ),
    "session_sealed_topic": b"SessionSealed(bytes32,uint16,bytes32,uint64)",
    "session_live_to_refund_topic": (
        b"SessionLiveToRefund(bytes32,address,uint16,uint64,uint64)"
    ),
    "session_bond_claimed_topic": (
        b"SessionBondClaimed(bytes32,address,address,uint256)"
    ),
    "session_refund_forfeited_topic": (
        b"SessionRefundForfeited(bytes32,address,uint16,uint256)"
    ),
    "session_surplus_swept_topic": b"SessionSurplusSwept(address,uint256)",
    "data_sessions_maintained_topic": (
        b"DataSessionsMaintained(uint8,uint16,uint16,uint8,uint8)"
    ),
}
COMPONENT_CONFIG_GETTER_SELECTOR = keccak256(
    b"componentConfigHashV2()")[:4]
D_DESTINATION_INFRASTRUCTURE = b"slot-chain-destination-infrastructure-v3"
D_DESTINATION_REGISTRATION = b"slot-chain-destination-registration-v1"
D_SETTLEMENT_DEPLOYMENT = b"slot-chain-settlement-deployment-v1"
D_L1_ADOPTION = b"slot-chain-l1-adoption-v1"
D_L1_ACTIVATION_CONTEXT = b"slot-chain-l1-activation-context-v1"
D_SOURCE_FREEZE_POSTSTATE = b"slot-chain-source-freeze-poststate-v1"
D_QUEUE_MIGRATION_POSTSTATE = b"slot-chain-queue-migration-poststate-v1"
D_PROTOCOL_CHANGE_OPERATION = b"slot-chain-protocol-change-operation-v1"
D_PROTOCOL_CHANGE_TIMELOCK = b"slot-chain-protocol-change-timelock-v1"
D_PROTOCOL_VERSION_MANAGER_CONFIG = (
    b"slot-chain-protocol-version-manager-config-v1"
)
D_PROTOCOL_VERSION_MANAGER = b"slot-chain-protocol-version-manager-v1"
D_VERSION_MIGRATION_ARM = b"slot-chain-version-migration-arm-v2"
D_TARGET_REGISTRATION_V2 = b"slot-chain-target-registration-v2"
D_EXECUTION_PROFILE = b"slot-chain-execution-profile-v2"
D_SEAT_TARGET_AUTHORIZATION = b"TAIKO_SEAT_TARGET_AUTHORIZATION_V1"
D_SCHEDULE_FORK_CONSTANTS = b"slot-chain-schedule-fork-constants-v1"
D_SCHEDULE_FORK_VERIFIER_CONFIG = (
    b"slot-chain-schedule-fork-verifier-config-v1"
)
D_SCHEDULE_CARRIER_STATEMENT = b"slot-chain-schedule-carrier-statement-v1"
D_MIGRATION_ACTIVATION_PROFILE = b"slot-chain-migration-activation-profile-v2"
SCHEDULE_FORK_OUTPUT_SCHEMA_LITERAL = (
    b"ScheduleCarrierOutputV1(bytes32 statementHash,uint64 parentSlot,"
    b"uint64 executionBlockNumber,uint64 payloadTimestamp,bytes32 blockHash,"
    b"bytes32 stateRoot,bytes32 prevRandao)"
)
PROTOCOL_CHANGE_DELAY_SECONDS = 604_800
MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS = 604_800
PROTOCOL_CHANGE_MAX_PAYLOAD_BYTES = 131_072
PROTOCOL_VERSION_REVIEW_FINALITY_BLOCKS = 64
D_LEGACY_GENESIS_DEPLOYMENT = b"slot-chain-legacy-genesis-deployment-v1"
D_LEGACY_GENESIS_INBOX_CONFIG = b"slot-chain-legacy-genesis-inbox-config-v1"
D_LEGACY_GENESIS_CAMPAIGN = b"slot-chain-legacy-genesis-campaign-v1"
D_LEGACY_GENESIS_SCAN = b"slot-chain-legacy-genesis-scan-v1"
D_LEGACY_GENESIS_PROPOSAL_ROWS_EMPTY = (
    b"slot-chain-legacy-genesis-proposal-rows-empty-v1"
)
D_LEGACY_GENESIS_PROPOSAL_ROW = b"slot-chain-legacy-genesis-proposal-row-v1"
D_LEGACY_GENESIS_FORCED_ROWS_EMPTY = (
    b"slot-chain-legacy-genesis-forced-rows-empty-v1"
)
D_LEGACY_GENESIS_FORCED_ROW = b"slot-chain-legacy-genesis-forced-row-v1"
D_LEGACY_GENESIS_CAMPAIGN_FENCE = (
    b"slot-chain-legacy-genesis-campaign-fence-v1"
)
D_LEGACY_GENESIS_RESUME_VERIFIER_ROUTE = (
    b"slot-chain-legacy-genesis-resume-verifier-route-v1"
)
D_LEGACY_GENESIS_RISC0_KEY_POLICY = (
    b"slot-chain-legacy-genesis-risc0-key-policy-v1"
)
D_LEGACY_GENESIS_SP1_KEY_POLICY = (
    b"slot-chain-legacy-genesis-sp1-key-policy-v1"
)
D_LEGACY_GENESIS_RISC0_VERIFIER = (
    b"slot-chain-legacy-genesis-risc0-verifier-v1"
)
D_LEGACY_GENESIS_SP1_VERIFIER = (
    b"slot-chain-legacy-genesis-sp1-verifier-v1"
)
D_LEGACY_GENESIS_PROOF_VERIFIER_GRAPH = (
    b"slot-chain-legacy-genesis-proof-verifier-graph-v1"
)
D_LEGACY_GENESIS_PROPOSER_CHECKER = (
    b"slot-chain-legacy-genesis-proposer-checker-v1"
)
D_LEGACY_GENESIS_PUBLIC_PROVING = (
    b"slot-chain-legacy-genesis-public-proving-v1"
)
D_LEGACY_GENESIS_CHECKPOINT_LAYOUT = (
    b"slot-chain-legacy-genesis-checkpoint-layout-v1"
)
D_LEGACY_GENESIS_CHECKPOINT_RECORD_LITERAL = (
    b"CheckpointRecord(bytes32 blockHash,bytes32 stateRoot)"
)
D_LEGACY_GENESIS_SIGNAL_SERVICE_CHECKPOINT = (
    b"slot-chain-legacy-genesis-signal-service-checkpoint-v1"
)
D_LEGACY_GENESIS_RESUME_PROFILE = b"slot-chain-legacy-genesis-resume-profile-v2"
D_LEGACY_GENESIS_REVIEW = b"slot-chain-legacy-genesis-review-v1"
D_LEGACY_GENESIS_ABANDONMENT_RECEIPT = (
    b"slot-chain-legacy-genesis-abandonment-receipt-v1"
)
LEGACY_GENESIS_RESUME_TIME_POLICY_LITERAL = (
    b"LegacyGenesisResumeTimePolicyV2(sameProofPreserved=false,"
    b"ageIndependentRouteRequired=true,publicProvingRequired=true,"
    b"minBond=0,livenessBond=0,"
    b"noContest=true,forcedDueOnlyStrengthens=true,"
    b"withdrawalOnlyMatures=true)"
)
D_LEGACY_GENESIS_ARM = b"slot-chain-legacy-genesis-arm-v1"
D_LEGACY_GENESIS_BOUNDARY = b"slot-chain-legacy-genesis-boundary-v1"
D_LEGACY_GENESIS_LAUNCH = b"slot-chain-legacy-genesis-launch-v1"
D_LEGACY_GENESIS_POSTSTATE = b"slot-chain-legacy-genesis-poststate-v1"
D_RELEASE_MANIFEST_SLOT = b"slot-chain-protocol-version-manager.releaseManifestHash.v1"
D_REGISTRATION_SLOT = b"slot-chain-terminal-domain-registrar.registrationCommitment.v1"
RELEASE_MANIFEST_TYPE = (
    b"ReleaseManifestV2(uint64 protocolVersion,uint256 settlementChainId,"
    b"uint256 destinationChainId,bytes32 destinationGenesisHash,"
    b"bytes32 executionProfileHash,bytes32 manifestNamespace,"
    b"bytes32 destinationNamespace,address anchorV4,bytes32 anchorRuntimeHash,"
    b"bytes32 destinationDomainId,address destinationBridge,"
    b"bytes32 destinationBridgeExecutionHash,"
    b"DestinationBridgeDescriptorV2 destinationBridgeDescriptor,"
    b"bytes32 destinationInfrastructureHash,bytes32 migrationVerifierDescriptorHash,"
    b"bytes32 ingressAuthorizationRoot,address nativeLiquidityPool,"
    b"bytes32 poolRuntimeHash,bytes32 poolConfigurationHash,"
    b"ComponentDescriptorV2[10] components)"
    b"ComponentDescriptorV2(address component,bytes32 runtimeHash,bytes32 configHash)"
    b"DestinationBridgeDescriptorV2(address bridge,bytes32 runtimeHash,"
    b"bytes32 configurationHash,bytes32 storageLayoutHash,"
    b"bytes32 bridgeKernelProfileHash,address inboxCreditStore,"
    b"address terminalAccumulator,address terminalDomainRegistrar,"
    b"address quotaManager,address nativeLiquidityPool)"
)
RELEASE_MANIFEST_TYPEHASH = keccak256(RELEASE_MANIFEST_TYPE)
ACTIVATE_RELEASE_V2_SIGNATURE = (
    b"activateRelease((uint64,uint256,uint256,bytes32,bytes32,bytes32,bytes32,"
    b"address,bytes32,bytes32,address,bytes32,"
    b"(address,bytes32,bytes32,bytes32,bytes32,address,address,address,address,address),"
    b"bytes32,bytes32,bytes32,address,bytes32,bytes32,"
    b"(address,bytes32,bytes32)[10]),uint64)"
)
ACTIVATE_VERSION_WITH_MIGRATION_SIGNATURE = (
    b"activateVersionWithMigration((uint8,uint64,uint64,uint64,uint64,bytes32,"
    b"(uint48,bytes32,uint64,bytes32,uint64,bytes32,uint256,uint64,bytes32,"
    b"uint64),address,uint256,bytes32,uint64,uint64),"
    b"(uint64,uint256,uint256,bytes32,bytes32,bytes32,bytes32,address,bytes32,"
    b"bytes32,address,bytes32,(address,bytes32,bytes32,bytes32,bytes32,address,"
    b"address,address,address,address),bytes32,bytes32,bytes32,address,bytes32,"
    b"bytes32,(address,bytes32,bytes32)[10]),"
    b"(uint64,uint8,uint32,bytes32,bytes)[],bytes,bytes)"
)
ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR = keccak256(
    ACTIVATE_VERSION_WITH_MIGRATION_SIGNATURE)[:4]
MIGRATION_VERIFIER_CONFIG_TYPE = (
    b"MigrationTransitionVerifierConfigV2(bytes32 verifyingKeyHash,"
    b"bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,"
    b"uint32 maximumProofBytes,uint64 verificationGasLimit)"
)
MIGRATION_VERIFIER_CONFIG_TYPEHASH = keccak256(
    MIGRATION_VERIFIER_CONFIG_TYPE)
MIGRATION_VERIFIER_DESCRIPTOR_TYPE = (
    b"MigrationTransitionVerifierDescriptorV2(address verifier,"
    b"bytes32 runtimeHash,bytes32 configurationHash,bytes32 verifyingKeyHash,"
    b"bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,"
    b"uint32 maximumProofBytes,uint64 verificationGasLimit)"
)
MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
    MIGRATION_VERIFIER_DESCRIPTOR_TYPE)
MIGRATION_VERIFIER_CONFIG_GETTER_SELECTOR = keccak256(
    b"migrationVerifierConfigHashV2()")[:4]
MIGRATION_TRANSITION_STATEMENT_TYPE = (
    b"MigrationTransitionStatementV2(uint256 settlementChainId,"
    b"address activeSettlementRouter,bytes32 routerRuntimeHash,"
    b"bytes32 routerConfigurationHash,uint8 transitionKind,"
    b"uint64 migrationGeneration,uint64 sourceProtocolVersion,"
    b"uint64 targetProtocolVersion,uint64 sourceCanonicalSequence,"
    b"bytes32 executionProfileHash,bytes32 targetManifestHash,"
    b"bytes32 targetRegistrationHash,"
    b"bytes32 candidateDigest,bytes32 baseCanonicalHash,"
    b"bytes32 outputCanonicalHash,address forcedQueue,bytes32 queueRuntimeHash,"
    b"bytes32 queueConfigurationHash,bytes32 queueRoot,uint64 queueCount,"
    b"uint64 startCursor,uint64 endCursor,bytes32 forcedDescriptorCommitment,"
    b"address proofBeneficiary,uint256 anchorNumber,bytes32 anchorHash,"
    b"bytes32 forceRoot,uint64 forceCutoff,bytes32 sourceDomainId,"
    b"uint64 sourceRegistrationEpoch,bytes32 sourceBridgeExecutionHash,"
    b"bytes32 releaseSystemCalldataHash,bytes32 inboxSystemCalldataHash,"
    b"bytes32 releaseSystemTxHash,bytes32 inboxSystemTxHash,"
    b"uint8 releaseSystemTxPosition,uint8 inboxSystemTxPosition,"
    b"bytes32 importedHeaderHash,bytes32 importedStateRoot,"
    b"bytes32 legacySignalCheckpointHash,bytes32 legacyDeploymentHash,"
    b"bytes32 legacyArmId,bytes32 legacyLaunchId,"
    b"bytes32 deploymentCommitment,"
    b"uint64 preInboxLastAppliedPlusOne,uint64 postInboxLastAppliedPlusOne)"
)
MIGRATION_TRANSITION_STATEMENT_TYPEHASH = keccak256(
    MIGRATION_TRANSITION_STATEMENT_TYPE)
DEPLOYMENT_COMMITMENT_TYPE = (
    b"DeploymentCommitmentV2(uint8 transitionKind,uint64 targetProtocolVersion,"
    b"bytes32 targetManifestHash,bytes32 targetRegistrationHash,"
    b"bytes32 destinationInfrastructureHash,"
    b"bytes32 componentsHash,bytes32 poolConfigurationHash,"
    b"uint64 retirementQueueCount,bytes32 prestatePolicyHash,"
    b"bytes32 poststatePolicyHash)"
)
DEPLOYMENT_COMMITMENT_TYPEHASH = keccak256(DEPLOYMENT_COMMITMENT_TYPE)
D_DEPLOYMENT_PRESTATE_POLICY = b"slot-chain-deployment-prestate-policy-v2"
D_DEPLOYMENT_POSTSTATE_POLICY = b"slot-chain-deployment-poststate-policy-v2"
ADOPT_MIGRATION_CANONICAL_SIGNATURE = (
    b"adoptMigrationCanonicalV1(uint8,uint64,uint64,uint64,uint64,bytes32,"
    b"bytes32,(uint48,bytes32,uint64,bytes32,uint64,bytes32,uint256,uint64,"
    b"bytes32,uint64))"
)
ADOPT_MIGRATION_CANONICAL_SELECTOR = keccak256(
    ADOPT_MIGRATION_CANONICAL_SIGNATURE)[:4]
FREEZE_MIGRATION_SOURCE_SELECTOR = keccak256(
    b"freezeMigrationSourceV1(bytes32)")[:4]
MIGRATE_ACTIVE_SETTLEMENT_SELECTOR = keccak256(
    b"migrateAuthorityForActivationV1(bytes32,address,address,bytes32,uint64,"
    b"uint64,uint64,address)")[:4]
MIGRATION_ACTIVATION_CONTEXT_SELECTOR = keccak256(
    b"migrationActivationContextV1()")[:4]
MIGRATION_ACTIVATION_POST_STATE_SELECTOR = keccak256(
    b"migrationActivationPostStateV1(bytes32)")[:4]
LEGACY_GENESIS_STATE_SELECTOR = keccak256(b"legacyGenesisStateV1()")[:4]
LEGACY_GENESIS_CAMPAIGN_SELECTOR = keccak256(
    b"legacyGenesisCampaignV1()")[:4]
LEGACY_GENESIS_PREPARATION_SELECTOR = keccak256(
    b"legacyGenesisPreparationV1()")[:4]
LEGACY_GENESIS_BEGIN_SCAN_SELECTOR = keccak256(
    b"beginLegacyGenesisScanV1(uint64,bytes32)")[:4]
LEGACY_GENESIS_SCAN_PROPOSALS_SELECTOR = keccak256(
    b"scanLegacyGenesisProposalsV1(uint64,bytes32,bytes[])")[:4]
LEGACY_GENESIS_SCAN_FORCED_SELECTOR = keccak256(
    b"scanLegacyGenesisForcedV1(uint64,bytes32,uint16)")[:4]
LEGACY_GENESIS_SCAN_STATE_SELECTOR = keccak256(
    b"legacyGenesisScanStateV1()")[:4]
LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR = keccak256(
    b"enterLegacyGenesisQuiescenceV1(uint64,bytes32)")[:4]
LEGACY_GENESIS_RESUME_SELECTOR = keccak256(
    b"resumeLegacyGenesisV1(uint64,bytes32)")[:4]
LEGACY_GENESIS_EXPIRE_SELECTOR = keccak256(
    b"expireLegacyGenesisCampaignV1(uint64,bytes32)")[:4]
LEGACY_GENESIS_ARM_SELECTOR = keccak256(
    b"checkpointLegacyGenesisV1(uint64,bytes32)")[:4]
LEGACY_GENESIS_FINALIZE_SELECTOR = keccak256(
    b"finalizeLegacyGenesisV1(uint64,uint64,bytes32,bytes32,bytes32,bytes32)")[:4]
LEGACY_RESUME_VERIFIER_CONFIG_SELECTOR = keccak256(
    b"legacyResumeVerifierConfigV1()")[:4]
LEGACY_RESUME_RISC0_CONFIG_SELECTOR = keccak256(
    b"legacyResumeRisc0ConfigV1()")[:4]
LEGACY_RESUME_SP1_CONFIG_SELECTOR = keccak256(
    b"legacyResumeSp1ConfigV1()")[:4]
LEGACY_CHECKPOINT_CONFIG_SELECTOR = keccak256(
    b"legacyCheckpointConfigV1()")[:4]
LEGACY_DESCRIPTOR_IMPL_SELECTOR = keccak256(b"impl()")[:4]
LEGACY_INBOX_CONFIG_SELECTOR = keccak256(b"getConfig()")[:4]
LEGACY_OPERATOR_COUNT_SELECTOR = keccak256(b"operatorCount()")[:4]
LEGACY_CURRENT_OPERATOR_SELECTOR = keccak256(
    b"getOperatorForCurrentEpoch()")[:4]
LEGACY_NEXT_OPERATOR_SELECTOR = keccak256(
    b"getOperatorForNextEpoch()")[:4]
LEGACY_SIGNAL_SERVICE_VERSION_SELECTOR = keccak256(b"VERSION()")[:4]
LEGACY_DESCRIPTOR_CALL_GAS = 100_000
PROTOCOL_AUTHORITY_READ_GAS = 100_000
QUEUE_PROTOCOL_CHANGE_SELECTOR = keccak256(
    b"queueProtocolChangeV1(uint8,bytes)")[:4]
EXECUTE_PROTOCOL_CHANGE_SELECTOR = keccak256(
    b"executeProtocolChangeV1(uint64,uint8,bytes)")[:4]
CANCEL_PROTOCOL_CHANGE_SELECTOR = keccak256(
    b"cancelProtocolChangeV1(uint64,uint8,bytes)")[:4]
APPLY_PROTOCOL_CHANGE_SELECTOR = keccak256(
    b"applyProtocolChangeV1(uint64,uint8,bytes)")[:4]
PROTOCOL_CHANGE_TIMELOCK_CONFIG_SELECTOR = keccak256(
    b"protocolChangeTimelockConfigV1()")[:4]
PROTOCOL_VERSION_MANAGER_CONFIG_SELECTOR = keccak256(
    b"protocolVersionManagerConfigV1()")[:4]
PROTOCOL_CHANGE_OPERATION_SELECTOR = keccak256(
    b"protocolChangeOperationV1(bytes32)")[:4]
LIVE_VERSION_MIGRATION_LEASE_SELECTOR = keccak256(
    b"liveVersionMigrationLeaseV1()")[:4]
PERMISSIONLESS_ABORT_EXPIRED_MIGRATION_SELECTOR = keccak256(
    b"permissionlessAbortExpiredMigrationV1()")[:4]
INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR = keccak256(
    b"installSettlementAuthorizationV1(uint64,address,bytes32,bytes32,bytes4,"
    b"bytes32)")[:4]
SETTLEMENT_AUTHORIZATION_SELECTOR = keccak256(
    b"settlementAuthorizationV1(bytes32)")[:4]
SEAT_TARGET_STATE_SELECTOR = bytes.fromhex("cf52185b")
SEAT_MARKET_TERM_SELECTOR = bytes.fromhex("76d5ecd4")
SEAT_MARKET_DUTY_SELECTOR = bytes.fromhex("9a649489")
SEAT_AUTHORITY_READ_GAS = 100_000
REGISTER_TARGET_RELEASE_SELECTOR = bytes.fromhex("9aa71eff")
TARGET_RELEASE_REGISTRATION_SELECTOR = bytes.fromhex("f588fec3")
PROFILE_INGRESS_ROOT_SELECTOR = bytes.fromhex("2d2bbe23")
PROFILE_INGRESS_AUTHORIZATION_SELECTOR = bytes.fromhex("2181b974")
MIGRATION_ACTIVATION_PROFILE_SELECTOR = bytes.fromhex("c65ff64e")
REGISTER_TARGET_RELEASE_GAS = 3_000_000
INSTALL_SETTLEMENT_AUTHORIZATION_GAS = 500_000
PROTOCOL_REGISTRATION_POSTREAD_GAS = 100_000
INSTALL_FORK_VERIFIER_SELECTOR = bytes.fromhex("f171816c")
FORK_VERIFIER_REGISTRATION_SELECTOR = bytes.fromhex("c614591c")
SCHEDULE_FORK_VERIFIER_CONFIG_SELECTOR = bytes.fromhex("44efa773")
VERIFY_SCHEDULE_CARRIER_SELECTOR = bytes.fromhex("7e981e0b")
INSTALL_FORK_VERIFIER_GAS = 500_000
FORK_VERIFIER_GETTER_GAS = 100_000
MINIMUM_FORK_VERIFIER_GAS = 100_000
MAXIMUM_FORK_VERIFIER_GAS = 5_000_000
MAXIMUM_SCHEDULE_WITNESS_BYTES = 131_072
PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR = bytes.fromhex("5f0ed7f5")
ARM_VERSION_MIGRATION_SELECTOR = bytes.fromhex("e3bcfcb4")
ABORT_EXPIRED_VERSION_MIGRATION_SELECTOR = bytes.fromhex("c4eee12d")
PVM_ROUTER_MUTATION_GAS = 8_000_000
MIGRATION_CANONICAL_MAGIC = bytes.fromhex("4d43414e")  # MCAN
MIGRATION_FREEZE_MAGIC = bytes.fromhex("4d46525a")  # MFRZ
QUEUE_MIGRATION_MAGIC = bytes.fromhex("514d4947")  # QMIG
MIGRATION_ACTIVATION_CONTEXT_MAGIC = bytes.fromhex("4d414354")  # MACT
MIGRATION_ACTIVATION_POST_STATE_MAGIC = bytes.fromhex("4d415053")  # MAPS
LEGACY_GENESIS_STATE_MAGIC = bytes.fromhex("4c475331")  # LGS1
LEGACY_GENESIS_CAMPAIGN_MAGIC = bytes.fromhex("4c474331")  # LGC1
LEGACY_GENESIS_PREPARATION_MAGIC = bytes.fromhex("4c475052")  # LGPR
LEGACY_GENESIS_BEGIN_SCAN_MAGIC = bytes.fromhex("4c474253")  # LGBS
LEGACY_GENESIS_SCAN_PROPOSALS_MAGIC = bytes.fromhex("4c475350")  # LGSP
LEGACY_GENESIS_SCAN_FORCED_MAGIC = bytes.fromhex("4c475346")  # LGSF
LEGACY_GENESIS_SCAN_STATE_MAGIC = bytes.fromhex("4c475353")  # LGSS
LEGACY_GENESIS_QUIESCENCE_MAGIC = bytes.fromhex("4c475153")  # LGQS
LEGACY_GENESIS_RESUME_MAGIC = bytes.fromhex("4c475253")  # LGRS
LEGACY_GENESIS_EXPIRE_MAGIC = bytes.fromhex("4c474558")  # LGEX
LEGACY_GENESIS_ARM_MAGIC = bytes.fromhex("4c474152")  # LGAR
LEGACY_GENESIS_FINALIZE_MAGIC = bytes.fromhex("4c47464e")  # LGFN
LEGACY_RESUME_VERIFIER_CONFIG_MAGIC = bytes.fromhex("4c525631")  # LRV1
LEGACY_RESUME_RISC0_CONFIG_MAGIC = bytes.fromhex("4c523031")  # LR01
LEGACY_RESUME_SP1_CONFIG_MAGIC = bytes.fromhex("4c535031")  # LSP1
LEGACY_CHECKPOINT_CONFIG_MAGIC = bytes.fromhex("4c434b31")  # LCK1
PROTOCOL_CHANGE_TIMELOCK_CONFIG_MAGIC = bytes.fromhex("50435431")  # PCT1
PROTOCOL_VERSION_MANAGER_CONFIG_MAGIC = bytes.fromhex("50564d31")  # PVM1
PROTOCOL_CHANGE_OPERATION_MAGIC = bytes.fromhex("50434f31")  # PCO1
PROTOCOL_APPLY_MAGIC = bytes.fromhex("50415031")  # PAP1
VERSION_MIGRATION_LEASE_MAGIC = bytes.fromhex("564d4c31")  # VML1
SETTLEMENT_AUTHORIZATION_INSTALL_MAGIC = bytes.fromhex("53414931")  # SAI1
SETTLEMENT_AUTHORIZATION_GETTER_MAGIC = bytes.fromhex("53415431")  # SAT1
SEAT_TARGET_EXPECTED_MAGIC = bytes.fromhex("53454154")  # SEAT
TARGET_RELEASE_REGISTRATION_MAGIC = bytes.fromhex("52545232")  # RTR2
PROFILE_INGRESS_ROOT_MAGIC = bytes.fromhex("50495232")  # PIR2
PROFILE_INGRESS_AUTHORIZATION_MAGIC = bytes.fromhex("50494132")  # PIA2
MIGRATION_ACTIVATION_PROFILE_MAGIC = bytes.fromhex("4d505232")  # MPR2
FORK_VERIFIER_INSTALL_MAGIC = bytes.fromhex("46564931")  # FVI1
FORK_VERIFIER_REGISTRATION_MAGIC = bytes.fromhex("46565231")  # FVR1
SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC = bytes.fromhex("53465631")  # SFV1
SCHEDULE_FORK_CARRIER_MAGIC = bytes.fromhex("53464331")  # SFC1
LEGACY_GENESIS_PUBLISH_MAGIC = bytes.fromhex("4c475031")  # LGP1
VERSION_MIGRATION_ARM_MAGIC = bytes.fromhex("564d4131")  # VMA1
VERSION_MIGRATION_ABORT_MAGIC = bytes.fromhex("564d4231")  # VMB1
D_LEGACY_CHECKPOINT = b"slot-chain-legacy-checkpoint-v1"
REGISTRATION_STORAGE_STATEMENT_TYPE = (
    b"RegistrationStorageStatementV2(uint256 settlementChainId,"
    b"address activeSettlementRouter,address bridgeDomainRegistry,"
    b"bytes32 routeKey,uint256 destinationChainId,uint64 protocolVersion,"
    b"uint64 canonicalSequence,bytes32 stateRoot,"
    b"address terminalDomainRegistrar,bytes32 registrarCodeHash,"
    b"bytes32 storageTrieKey,bytes32 expectedValue)"
)
REGISTRATION_STORAGE_STATEMENT_TYPEHASH = keccak256(
    REGISTRATION_STORAGE_STATEMENT_TYPE)
REGISTRATION_ROUTE_KEY_TYPE = (
    b"BridgeRouteKeyV2(bytes32 sourceDomainId,bytes32 bridgeExecutionHash,"
    b"bytes32 destinationDomainId)"
)
REGISTRATION_ROUTE_KEY_TYPEHASH = keccak256(REGISTRATION_ROUTE_KEY_TYPE)
VERIFY_REGISTRATION_SIGNATURE = (
    b"verifyRegistration((uint256,address,address,bytes32,uint256,uint64,"
    b"uint64,bytes32,address,bytes32,bytes32,bytes32),bytes)"
)
VERIFY_REGISTRATION_SELECTOR = keccak256(VERIFY_REGISTRATION_SIGNATURE)[:4]
REGISTRATION_MPT_PROOF_SCHEMA_LITERAL = (
    b"MptProofV1=be16(accountNodeCount)||be16(storageNodeCount)||"
    b"(be16(nodeLength)||canonicalRlpNode)*accountNodeCount||"
    b"(be16(nodeLength)||canonicalRlpNode)*storageNodeCount;"
    b"rootToLeaf;EthereumKeccak;canonicalHexPrefix;canonicalRlp;"
    b"absenceRejected;valueRequired"
)
REGISTRATION_MPT_PROOF_SCHEMA_HASH = keccak256(
    REGISTRATION_MPT_PROOF_SCHEMA_LITERAL)
REGISTRATION_MPT_VERIFIER_CONFIG_TYPE = (
    b"RegistrationMptVerifierConfigV2(bytes32 publicInputSchemaHash,"
    b"bytes32 proofSchemaHash,bytes4 selector,uint16 maximumNodesPerPath,"
    b"uint16 maximumTotalNodes,uint16 maximumNodeBytes,"
    b"uint32 maximumProofBytes,uint64 verificationGasLimit)"
)
REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH = keccak256(
    REGISTRATION_MPT_VERIFIER_CONFIG_TYPE)
REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPE = (
    b"RegistrationMptVerifierDescriptorV2(address verifier,"
    b"bytes32 runtimeHash,bytes32 configurationHash,"
    b"bytes32 publicInputSchemaHash,bytes32 proofSchemaHash,bytes4 selector,"
    b"uint16 maximumNodesPerPath,uint16 maximumTotalNodes,"
    b"uint16 maximumNodeBytes,uint32 maximumProofBytes,"
    b"uint64 verificationGasLimit)"
)
REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
    REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPE)
REGISTRATION_MPT_VERIFIER_CONFIG_GETTER_SELECTOR = keccak256(
    b"registrationMptVerifierConfigHashV2()")[:4]
SEND_MESSAGE_V2_SIGNATURE = (
    b"sendMessageV2((uint64,uint64,uint32,address,uint64,address,uint64,"
    b"address,address,uint256,bytes),uint64)"
)
ENQUEUE_BRIDGE_CREDIT_V2_SIGNATURE = (
    b"enqueueBridgeCreditV2((uint64,uint64,uint32,address,uint64,address,"
    b"uint64,address,address,uint256,bytes),uint64)"
)
SEND_MESSAGE_V2_SELECTOR = keccak256(SEND_MESSAGE_V2_SIGNATURE)[:4]
ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR = keccak256(
    ENQUEUE_BRIDGE_CREDIT_V2_SIGNATURE)[:4]
CREDIT_AUTHORIZATION_V2_SELECTOR = keccak256(
    b"creditAuthorizationV2(bytes32)")[:4]
CREDIT_LIABILITY_V2_SELECTOR = keccak256(
    b"creditLiabilityV2(bytes32)")[:4]
INBOX_APPLY_SIGNATURE = b"apply(uint64,(uint64,uint8,uint32,bytes32,bytes)[])"
INBOX_APPLY_SELECTOR = keccak256(INBOX_APPLY_SIGNATURE)[:4]
MARK_INBOX_BATCH_SIGNATURE = (
    b"markReceivedFromInboxBatch((uint64,uint64,bytes32,uint64,address,"
    b"bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64)[])"
)
MARK_INBOX_BATCH_SELECTOR = keccak256(MARK_INBOX_BATCH_SIGNATURE)[:4]
INBOX_BATCH_MAGIC = bytes.fromhex("49425632")  # IBV2
ROUTE_CONFIG_GETTER_SELECTOR = keccak256(b"routeConfigHashV2()")[:4]
VERIFY_INBOX_CREDIT_SELECTOR = keccak256(
    b"verifyInboxCredit(uint64,bytes32,uint64,address,bytes32,bytes32)")[:4]
GET_INBOX_CREDIT_SLOT_SELECTOR = keccak256(
    b"getInboxCreditSlot(bytes32,address,bytes32,bytes32)")[:4]
LIQUIDITY_QUOTE_SELECTOR = keccak256(b"liquidityQuoteV2(bytes32)")[:4]
LIQUIDITY_FUNDING_STATE_SELECTOR = keccak256(
    b"liquidityFundingStateV2(bytes32)")[:4]
DEPOSIT_LIQUIDITY_V2_SELECTOR = keccak256(
    b"depositLiquidityV2(address,bytes32)")[:4]
WITHDRAW_LIQUIDITY_V2_SELECTOR = keccak256(
    b"withdrawLiquidityV2(bytes32,address,uint256)")[:4]
TICKET_ACCOUNTING_V2_SELECTOR = keccak256(
    b"ticketAccountingV2(bytes32)")[:4]
POOL_ACCOUNTING_V2_SELECTOR = keccak256(b"poolAccountingV2()")[:4]
CONSUME_AUTHORIZED_LIQUIDITY_V2_SELECTOR = keccak256(
    b"consumeAuthorizedLiquidityV2(bytes32,bytes32,address,uint256,bytes32)")[:4]
ACCEPT_LIQUIDITY_VALUE_V2_SELECTOR = keccak256(
    b"acceptLiquidityValueV2(bytes32,bytes32,uint256)")[:4]
POOL_ACCOUNTING_MAGIC = bytes.fromhex("504c4132")  # PLA2
POOL_VALUE_MAGIC = bytes.fromhex("4e4c5632")  # NLV2
POOL_BRIDGE_RESULT_MAGIC = bytes.fromhex("4c415632")  # LAV2
POOL_EXTERNAL_READ_GAS = 50_000
POOL_AUTH_CLEANUP_GAS = 50_000
POOL_VALUE_CALLBACK_GAS = 100_000
LIQUIDITY_DEPOSITED_V2_TOPIC = keccak256(
    b"LiquidityDepositedV2(bytes32,address,address,uint256,uint256)")
LIQUIDITY_CONSUMED_V2_TOPIC = keccak256(
    b"LiquidityConsumedV2(bytes32,bytes32,bytes32,address,address,address,uint256)")
LIQUIDITY_WITHDRAWN_V2_TOPIC = keccak256(
    b"LiquidityWithdrawnV2(bytes32,address,address,uint256,uint256)")
PROCESS_WITH_LIQUIDITY_V2_SIGNATURE = (
    b"processWithLiquidityV2(bytes32,address,(uint64,uint64,uint32,address,"
    b"uint64,address,uint64,address,address,uint256,bytes),(uint64,uint8,"
    b"bytes32,bytes32,bytes32,uint64,address,bytes32,uint64,uint64),"
    b"(uint256,bytes32,address,bytes32,bytes32))"
)
RETRY_WITH_LIQUIDITY_V2_SIGNATURE = (
    b"retryWithLiquidityV2(bytes32,address,(uint64,uint64,uint32,address,"
    b"uint64,address,uint64,address,address,uint256,bytes),(uint64,uint8,"
    b"bytes32,bytes32,bytes32,uint64,address,bytes32,uint64,uint64),"
    b"(uint256,bytes32,address,bytes32,bytes32),bool)"
)
PROCESS_WITH_LIQUIDITY_V2_SELECTOR = keccak256(
    PROCESS_WITH_LIQUIDITY_V2_SIGNATURE)[:4]
RETRY_WITH_LIQUIDITY_V2_SELECTOR = keccak256(
    RETRY_WITH_LIQUIDITY_V2_SIGNATURE)[:4]
POOL_BRIDGE_ATTEMPT_SIGNATURE = (
    b"attemptFromLiquidityPoolV2(bytes32,address,(uint64,uint64,uint32,"
    b"address,uint64,address,uint64,address,address,uint256,bytes),(uint64,"
    b"uint8,bytes32,bytes32,bytes32,uint64,address,bytes32,uint64,uint64),"
    b"(uint256,bytes32,address,bytes32,bytes32),uint8,bool,bytes32)"
)
POOL_BRIDGE_ATTEMPT_SELECTOR = keccak256(POOL_BRIDGE_ATTEMPT_SIGNATURE)[:4]
EXECUTE_ATTEMPT_SIGNATURE = (
    b"executeAttemptV2((uint64,uint64,uint32,address,uint64,address,uint64,"
    b"address,address,uint256,bytes),(uint64,uint8,bytes32,bytes32,bytes32,"
    b"uint64,address,bytes32,uint64,uint64),(uint256,bytes32,address,"
    b"bytes32,bytes32),address,uint8,bool,bytes32,bytes32)"
)
EXECUTE_ATTEMPT_SELECTOR = keccak256(EXECUTE_ATTEMPT_SIGNATURE)[:4]
FINALIZE_FAILED_ATTEMPT_SELECTOR = keccak256(
    b"finalizeFailedAttemptV2(bytes32)")[:4]
TARGET_CALL_FAILED_SELECTOR = keccak256(b"TargetCallFailedV2(bytes32)")[:4]
APPEND_TERMINAL_SELECTOR = keccak256(
    b"appendTerminalV2(bytes32)")[:4]
TERMINAL_COMMITMENT_SELECTOR = keccak256(
    b"terminalCommitmentV2(bytes32)")[:4]
TERMINAL_STATE_SELECTOR = keccak256(b"terminalStateV2()")[:4]
INVOCATION_POLICY_TYPE = (
    b"InvocationPolicyV2(uint16 count,bytes32 addressesHash,bytes4 hookSelector)"
)
INVOCATION_POLICY_TYPEHASH = keccak256(INVOCATION_POLICY_TYPE)
INVOCATION_POLICY_GETTER_SELECTOR = keccak256(
    b"invocationPolicyV2(bytes32,address)")[:4]
MESSAGE_INVOCATION_HOOK_SELECTOR = keccak256(
    b"onMessageInvocation(bytes)")[:4]
INVOCATION_POLICY_MAGIC = bytes.fromhex("49505632")  # IPV2
ENQUEUE_FORCED_TRANSACTION_SELECTOR = keccak256(
    b"enqueueForcedTransactionV2(bytes,uint64,address)")[:4]
SYNC_INGRESS_SELECTOR = keccak256(b"syncIngressV2()")[:4]
APPEND_FROM_ADAPTER_SELECTOR = keccak256(
    b"appendFromAdapterV2(uint64,uint64,uint8,bytes)")[:4]
SOURCE_CONTEXT_TYPE = (
    b"SourceContextV2(uint64 protocolVersion,uint8 kind,bytes32 creditId,"
    b"bytes32 msgHash,bytes32 sourceDomainId,uint64 sourceRegistrationEpoch,"
    b"address sourceBridge,bytes32 sourceBridgeExecutionHash,"
    b"uint64 emittedAtBlock,uint64 queueIndex)"
)
SOURCE_CONTEXT_TYPEHASH = keccak256(SOURCE_CONTEXT_TYPE)
DESTINATION_CONTEXT_TYPE = (
    b"DestinationContextV2(uint256 destinationChainId,"
    b"bytes32 destinationDomainId,address destinationBridge,"
    b"bytes32 releaseManifestHash,bytes32 executionProfileHash)"
)
DESTINATION_CONTEXT_TYPEHASH = keccak256(DESTINATION_CONTEXT_TYPE)
INGRESS_AUTHORIZATION_TYPE = (
    b"ProfileIngressAuthorizationV2(uint8 kind,address adapter,"
    b"bytes32 adapterRuntimeHash,bytes32 adapterConfigurationHash,"
    b"address activeSettlementRouter,bytes32 routerRuntimeHash,"
    b"bytes32 routerConfigurationHash,address forcedQueue,"
    b"bytes32 queueRuntimeHash,bytes32 queueConfigurationHash,"
    b"bytes32 sourceDomainId,uint64 sourceRegistrationEpoch,"
    b"bytes32 sourceBridgeExecutionHash,uint256 destinationChainId,"
    b"bytes32 destinationDomainId,address destinationBridge,"
    b"bytes32 destinationBridgeExecutionHash,"
    b"bytes32 destinationInfrastructureHash,uint256 fixedIngressWei,"
    b"uint256 executionWeiPerAccountedGas,uint256 proofWeiPerAccountedGas,"
    b"uint256 permanentWeiPerByte,uint256 maximumAcceptedFeeWei)"
)
INGRESS_AUTHORIZATION_TYPEHASH = keccak256(INGRESS_AUTHORIZATION_TYPE)
INGRESS_AUTHORIZATION_ROOT_TYPE = (
    b"IngressAuthorizationRootV2(uint16 count,bytes32 idsHash)"
)
INGRESS_AUTHORIZATION_ROOT_TYPEHASH = keccak256(
    INGRESS_AUTHORIZATION_ROOT_TYPE)
D_DESTINATION_ACTIVATION_RECEIPT = b"slot-chain-destination-activation-receipt-v2"
D_ACTIVATION_RECEIPT = b"TAIKO_ACTIVATION_RECEIPT_V1"
DESTINATION_ACTIVATION_RECEIPT_MAGIC = bytes.fromhex("44525632")  # DRV2
DESTINATION_SUCCESSOR_RECEIPT_MAGIC = bytes.fromhex("44535632")  # DSV2
ACTIVATION_RECEIPT_MAGIC = bytes.fromhex("41525631")  # ARV1
ACTIVATION_SUCCESSOR_RECEIPT_MAGIC = bytes.fromhex("41535631")  # ASV1
ACTIVATION_RECEIPT_SELECTOR = keccak256(
    b"activationReceiptV1(bytes32)")[:4]
LEGACY_GENESIS_ABANDONMENT_SEALED_TOPIC = keccak256(
    b"LegacyGenesisAbandonmentSealed(bytes32,bytes32,bytes32,bytes32,"
    b"uint48,uint48,uint48,uint16,uint16,uint32,bytes32,uint48,uint48,"
    b"uint16,uint32,bytes32,uint256,uint256,uint64,bytes32)")
D_RECOVERY = b"slot-chain-recovery-v2"
D_BODY = b"slot-chain-body-v1"
D_CHUNK = b"slot-chain-body-chunk-v1"
D_SESSION = b"slot-chain-session-v1"
D_FS = b"slot-chain-data-fs-v2"
D_CORE = b"slot-chain-core-v3"
D_CANONICAL = b"slot-chain-canonical-v2"
D_CANDIDATE = b"slot-chain-candidate-v2"
D_WINNING_DATA = b"slot-chain-winning-data-v1"
D_SCHEDULE_LIST = b"slot-chain-schedule-list-v1"
D_SESSION_LIST = b"slot-chain-session-list-v1"
D_OUTPUTS = b"slot-chain-outputs-v2"
D_STATEMENT = b"slot-chain-statement-v2"
D_NORMAL_CONTEXT = b"slot-chain-normal-context-v1"
D_MIGRATION_DATA = b"slot-chain-migration-data-v2"


def u8(value: int) -> bytes:
    assert 0 <= value < 1 << 8
    return bytes([value])


def u32(value: int) -> bytes:
    assert 0 <= value < 1 << 32
    return value.to_bytes(4, "big")


def u48(value: int) -> bytes:
    assert 0 <= value < 1 << 48
    return value.to_bytes(6, "big")


def u192(value: int) -> bytes:
    assert 0 <= value < 1 << 192
    return value.to_bytes(24, "big")


def address20(value: int) -> bytes:
    assert 0 <= value < 1 << 160
    return value.to_bytes(20, "big")


def b4(value: bytes) -> bytes:
    assert len(value) == 4
    return value


def b32(value: int | bytes) -> bytes:
    raw = value.to_bytes(32, "big") if isinstance(value, int) else value
    assert len(raw) == 32
    return raw


def word(value: int | bytes) -> bytes:
    if isinstance(value, int):
        return u256(value)
    return b32(value)


def address_word(value: int) -> bytes:
    return bytes(12) + address20(value)


def bytes4_word(value: bytes) -> bytes:
    return b4(value) + bytes(28)


def ceil32(length: int) -> int:
    assert 0 <= length < 1 << 256
    return (length + 31) & ~31


def abi_bytes_tail(value: bytes) -> bytes:
    return u256(len(value)) + value + bytes(ceil32(len(value)) - len(value))


def uint_word_value(encoded: bytes, bits: int = 256) -> int:
    assert len(encoded) == 32 and 0 < bits <= 256
    value = int.from_bytes(encoded, "big")
    assert value < 1 << bits
    return value


def address_word_value(encoded: bytes) -> int:
    return uint_word_value(encoded, 160)


def bytes4_word_value(encoded: bytes) -> bytes:
    assert len(encoded) == 32 and encoded[4:] == bytes(28)
    return encoded[:4]


def assert_rejects(action, message: str) -> None:
    try:
        action()
        raise AssertionError(message)
    except AssertionError as error:
        assert str(error) != message


def changed_field_value(value):
    if isinstance(value, int):
        return value + 1
    if isinstance(value, bytes):
        assert len(value) > 0
        return value[:-1] + bytes([value[-1] ^ 1])
    if isinstance(value, tuple):
        assert value
        return (changed_field_value(value[0]),) + value[1:]
    nested_fields = fields(value)
    assert nested_fields
    first = nested_fields[0]
    return replace(
        value,
        **{first.name: changed_field_value(getattr(value, first.name))})


def assert_all_fields_bound(instance, encoder) -> None:
    baseline = encoder(instance)
    checked = 0
    for field in fields(instance):
        changed = replace(
            instance,
            **{field.name: changed_field_value(getattr(instance, field.name))})
        try:
            candidate = encoder(changed)
        except AssertionError:
            checked += 1
            continue
        assert candidate != baseline
        checked += 1
    assert checked == len(fields(instance))


def encode_enqueue_forced_transaction_calldata(
        raw_transaction: bytes, valid_until: int, refund_address: int) -> bytes:
    assert (raw_transaction and 0 <= valid_until <= UINT64_MAX
            and refund_address != 0)
    encoded = (ENQUEUE_FORCED_TRANSACTION_SELECTOR + u256(3 * 32)
               + u256(valid_until) + address_word(refund_address)
               + abi_bytes_tail(raw_transaction))
    assert len(encoded) == 132 + ceil32(len(raw_transaction))
    return encoded


def decode_enqueue_forced_transaction_calldata(
        calldata: bytes) -> tuple[bytes, int, int]:
    assert (len(calldata) >= 164
            and calldata[:4] == ENQUEUE_FORCED_TRANSACTION_SELECTOR)
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 3 * 32
    valid_until = uint_word_value(arguments[32:64], 64)
    refund_address = address_word_value(arguments[64:96])
    raw_length = uint_word_value(arguments[96:128])
    raw_transaction = arguments[128:128 + raw_length]
    result = (raw_transaction, valid_until, refund_address)
    assert calldata == encode_enqueue_forced_transaction_calldata(*result)
    return result


def encode_sync_ingress_return(result: int, active_protocol_version: int,
                               router_generation: int) -> bytes:
    assert (result in (1, 2)
            and 0 <= active_protocol_version <= UINT64_MAX
            and 0 <= router_generation <= UINT64_MAX)
    if result == 1:
        assert active_protocol_version > 0 and router_generation > 0
    else:
        assert active_protocol_version == 0 and router_generation == 0
    return (u256(result) + u256(active_protocol_version)
            + u256(router_generation))


def decode_sync_ingress_return(returndata: bytes) -> tuple[int, int, int]:
    assert len(returndata) == 96
    result = (uint_word_value(returndata[:32], 8),
              uint_word_value(returndata[32:64], 64),
              uint_word_value(returndata[64:96], 64))
    assert returndata == encode_sync_ingress_return(*result)
    return result


def encode_append_from_adapter_calldata(
        active_protocol_version: int, router_generation: int, kind: int,
        descriptor: bytes) -> bytes:
    assert (0 < active_protocol_version <= UINT64_MAX
            and 0 < router_generation <= UINT64_MAX and kind in (0, 1))
    assert len(descriptor) == (220 if kind == 0 else 541)
    encoded = (APPEND_FROM_ADAPTER_SELECTOR + u256(active_protocol_version)
               + u256(router_generation) + u256(kind) + u256(4 * 32)
               + abi_bytes_tail(descriptor))
    assert len(encoded) == (388 if kind == 0 else 708)
    return encoded


def decode_append_from_adapter_calldata(
        calldata: bytes) -> tuple[int, int, int, bytes]:
    assert (len(calldata) in (388, 708)
            and calldata[:4] == APPEND_FROM_ADAPTER_SELECTOR)
    arguments = calldata[4:]
    version = uint_word_value(arguments[:32], 64)
    generation = uint_word_value(arguments[32:64], 64)
    kind = uint_word_value(arguments[64:96], 8)
    assert uint_word_value(arguments[96:128]) == 4 * 32
    descriptor_length = uint_word_value(arguments[128:160])
    descriptor = arguments[160:160 + descriptor_length]
    result = (version, generation, kind, descriptor)
    assert calldata == encode_append_from_adapter_calldata(*result)
    return result


def encode_queued_return(queue_index: int) -> bytes:
    assert 0 <= queue_index < UINT64_MAX
    return u256(1) + u256(queue_index)


def decode_queued_return(returndata: bytes) -> int:
    assert len(returndata) == 64 and uint_word_value(returndata[:32], 8) == 1
    queue_index = uint_word_value(returndata[32:], 64)
    assert queue_index < UINT64_MAX
    return queue_index


def _decode_canonical_rlp_item(encoded: bytes, start: int) -> tuple[int, bool]:
    assert start < len(encoded)
    prefix = encoded[start]
    if prefix <= 0x7F:
        return start + 1, False
    if prefix <= 0xB7:
        length = prefix - 0x80
        end = start + 1 + length
        assert end <= len(encoded)
        assert not (length == 1 and encoded[start + 1] <= 0x7F)
        return end, False
    if prefix <= 0xBF:
        length_of_length = prefix - 0xB7
        length_start = start + 1
        length_end = length_start + length_of_length
        assert length_end <= len(encoded) and encoded[length_start] != 0
        length = int.from_bytes(encoded[length_start:length_end], "big")
        assert length >= 56
        end = length_end + length
        assert end <= len(encoded)
        return end, False
    if prefix <= 0xF7:
        length = prefix - 0xC0
        payload_start = start + 1
        end = payload_start + length
        assert end <= len(encoded)
    else:
        length_of_length = prefix - 0xF7
        length_start = start + 1
        length_end = length_start + length_of_length
        assert length_end <= len(encoded) and encoded[length_start] != 0
        length = int.from_bytes(encoded[length_start:length_end], "big")
        assert length >= 56
        payload_start = length_end
        end = payload_start + length
        assert end <= len(encoded)
    cursor = payload_start
    while cursor < end:
        cursor, _ = _decode_canonical_rlp_item(encoded, cursor)
        assert cursor <= end
    assert cursor == end
    return end, True


def canonical_rlp_list(encoded: bytes) -> bool:
    try:
        end, is_list = _decode_canonical_rlp_item(encoded, 0)
    except (AssertionError, RecursionError):
        return False
    return is_list and end == len(encoded)


def eip712_domain(chain_id: int, contract: int) -> bytes:
    return keccak256(keccak256(DOMAIN_TYPE.encode())
                     + keccak256(b"SlotChain") + keccak256(b"2")
                     + u256(chain_id) + address_word(contract))


def block_struct_hash(values: tuple[int | bytes, ...]) -> bytes:
    assert len(values) == 24
    address_indices = {3, 16}
    encoded = []
    for index, value in enumerate(values):
        encoded.append(address_word(value) if index in address_indices else word(value))
    return keccak256(keccak256(TYPE_STRING.encode()) + b"".join(encoded))


def eip712_digest(chain_id: int, contract: int,
                  values: tuple[int | bytes, ...]) -> bytes:
    return keccak256(b"\x19\x01" + eip712_domain(chain_id, contract)
                     + block_struct_hash(values))


def canonical_core(l2_block_number: int, tip_hash: bytes, tip_slot: int, state_root: bytes,
                   cursor: int, data_commitment: bytes, next_base_fee: int,
                   next_excess_blob_gas: int, terminal_root: bytes,
                   terminal_count: int) -> bytes:
    return keccak256(D_CORE + u64(l2_block_number) + b32(tip_hash)
                     + u64(tip_slot) + b32(state_root)
                     + u64(cursor) + b32(data_commitment)
                     + u256(next_base_fee) + u64(next_excess_blob_gas)
                     + b32(terminal_root) + u64(terminal_count))


def base_canonical(core_hash: bytes, canonicalized_at_block: int) -> bytes:
    return keccak256(D_CANONICAL + b32(core_hash) + u64(canonicalized_at_block))


def normal_context(base_hash: bytes, admission_version: int,
                   admission_root_hash: bytes, anchor_number: int,
                   anchor_hash: bytes) -> bytes:
    return keccak256(D_NORMAL_CONTEXT + b32(base_hash) + u64(admission_version)
                     + b32(admission_root_hash) + u64(anchor_number)
                     + b32(anchor_hash))


def migration_data(settlement_chain_id: int, l2_chain_id: int,
                   tip_hash: bytes, state_root: bytes,
                   terminal_root: bytes, terminal_count: int) -> bytes:
    return keccak256(D_MIGRATION_DATA + u256(settlement_chain_id)
                     + u256(l2_chain_id) + b32(tip_hash) + b32(state_root)
                     + b32(terminal_root) + u64(terminal_count))


def candidate_commitment(base_hash: bytes,
                         rows: tuple[tuple[int, bytes, bytes, bytes, bytes, int], ...]) -> bytes:
    payload = b"".join(u64(slot) + b32(block_struct) + b32(block_hash)
                       + b32(body_root_hash) + b32(data_manifest_root)
                       + u64(message_end)
                       for slot, block_struct, block_hash, body_root_hash,
                       data_manifest_root, message_end in rows)
    return keccak256(D_CANDIDATE + b32(base_hash) + u16(len(rows)) + payload)


def winning_data(candidate_hash: bytes, sessions_hash: bytes) -> bytes:
    return keccak256(D_WINNING_DATA + b32(candidate_hash) + b32(sessions_hash))


def schedule_list(rows: tuple[tuple[int, bytes, bytes], ...]) -> bytes:
    assert tuple(sorted(window for window, _, _ in rows)) == tuple(window for window, _, _ in rows)
    return keccak256(D_SCHEDULE_LIST + u8(len(rows)) + b"".join(
        u64(window) + b32(entry_root_hash) + b32(seed_hash)
        for window, entry_root_hash, seed_hash in rows))


def session_list(rows: tuple[tuple[bytes, int, bytes], ...]) -> bytes:
    assert tuple(sorted(session for session, _, _ in rows)) == tuple(session for session, _, _ in rows)
    return keccak256(D_SESSION_LIST + u8(len(rows)) + b"".join(
        b32(session) + u16(count) + b32(root) for session, count, root in rows))


def execution_outputs(state_root: bytes, transactions_root: bytes,
                      receipts_root: bytes, logs_bloom_hash: bytes,
                      withdrawals_root: bytes, terminal_root: bytes,
                      terminal_count: int) -> bytes:
    return keccak256(D_OUTPUTS + b32(state_root) + b32(transactions_root)
                     + b32(receipts_root) + b32(logs_bloom_hash)
                     + b32(withdrawals_root) + b32(terminal_root)
                     + u64(terminal_count))


STATEMENT_KINDS = (
    "uint", "uint", "uint", "bytes", "address",
    "uint", "bytes",
    "uint", "bytes", "bytes", "uint", "uint", "bytes", "uint", "uint",
    "bytes", "bytes", "uint", "uint", "bytes", "uint", "uint", "uint",
    "uint", "bytes", "bytes", "uint", "bytes", "uint", "bytes", "uint",
    "uint", "bytes", "uint", "uint", "bytes", "bytes", "uint", "bytes",
    "uint", "uint", "bytes", "address",
)


def statement_hash(values: tuple[int | bytes, ...]) -> bytes:
    assert len(values) == len(STATEMENT_KINDS)
    encoded = []
    for kind, value in zip(STATEMENT_KINDS, values):
        encoded.append(address_word(value) if kind == "address" else word(value))
    return keccak256(D_STATEMENT + b"".join(encoded))


@dataclass(frozen=True)
class RegistryCell:
    address: int
    bond: int
    registration_index: int
    effective_l2_slot: int
    tranche_root: bytes
    tombstoned_at_l2_slot: int


def registry_leaf(index: int, cell: RegistryCell | None) -> bytes:
    if cell is None:
        payload = u8(index) + u8(0) + bytes(20 + 24 + 8 + 8 + 32 + 8)
    else:
        payload = (u8(index) + u8(1) + address20(cell.address) + u192(cell.bond)
                   + u64(cell.registration_index) + u64(cell.effective_l2_slot)
                   + b32(cell.tranche_root) + u64(cell.tombstoned_at_l2_slot))
    return keccak256(D_REG_LEAF + payload)


def fixed_root(leaves: list[bytes], node_domain: bytes) -> bytes:
    assert leaves and len(leaves) & (len(leaves) - 1) == 0
    level, height = list(leaves), 0
    while len(level) > 1:
        level = [keccak256(node_domain + u8(height) + level[i] + level[i + 1])
                 for i in range(0, len(level), 2)]
        height += 1
    return level[0]


def registry_root(cells: tuple[RegistryCell | None, ...]) -> bytes:
    assert len(cells) == 64
    return fixed_root([registry_leaf(i, cell) for i, cell in enumerate(cells)], D_REG_NODE)


def admission_leaf(index: int, location: int, cell: RegistryCell | None) -> bytes:
    if cell is None:
        payload = u16(index) + u8(0) + bytes(1 + 20 + 24 + 8 + 8 + 8)
    else:
        payload = (u16(index) + u8(1) + u8(location) + address20(cell.address)
                   + u192(cell.bond) + u64(cell.registration_index)
                   + u64(cell.effective_l2_slot)
                   + u64(cell.tombstoned_at_l2_slot))
    return keccak256(D_ADM_LEAF + payload)


def admission_root(records: dict[int, tuple[int, RegistryCell]]) -> bytes:
    leaves = [admission_leaf(i, *(records[i] if i in records else (0, None)))
              for i in range(2048)]
    return fixed_root(leaves, D_ADM_NODE)


def canonical_admission_root(active: tuple[RegistryCell | None, ...],
                             liabilities: tuple[RegistryCell | None, ...]) -> bytes:
    assert len(active) == 64 and len(liabilities) == 1_072
    records: dict[int, tuple[int, RegistryCell]] = {}
    records.update({index: (1, cell) for index, cell in enumerate(active)
                    if cell is not None})
    records.update({64 + index: (2, cell)
                    for index, cell in enumerate(liabilities)
                    if cell is not None})
    return admission_root(records)


def tranche_leaf(index: int, window: int, state: int, amount: int,
                 liable_until: int) -> bytes:
    return keccak256(D_TRANCHE_LEAF + u16(index) + u64(window) + u8(state)
                     + u192(amount) + u64(liable_until))


def entry_leaf(rank: int, cell: RegistryCell | None, tranche_hash: bytes | None) -> bytes:
    if cell is None:
        return keccak256(D_ENTRY_LEAF + u8(rank) + u8(0) + bytes(20 + 24 + 8 + 8 + 8 + 32))
    assert tranche_hash is not None
    return keccak256(D_ENTRY_LEAF + u8(rank) + u8(1) + address20(cell.address)
                     + u192(cell.bond) + u64(cell.registration_index)
                     + u64(cell.effective_l2_slot) + u64(cell.tombstoned_at_l2_slot)
                     + b32(tranche_hash))


@dataclass(frozen=True)
class ForcedEnvelope:
    sender: int
    nonce: int
    chain_id: int
    raw_tx_hash: bytes
    byte_length: int
    gas_limit: int
    accounted_gas: int
    max_fee: int
    valid_until: int
    refund: int
    enqueued_at: int
    due_at: int
    deposit: int


@dataclass(frozen=True)
class BridgeEnvelope:
    msg_hash: bytes
    src_chain_id: int
    source_domain_id: bytes
    src_epoch: int
    src_bridge: int
    bridge_execution_hash: bytes
    emitted_at_block: int
    destination_domain_id: bytes
    dest_chain_id: int
    enqueue_by: int
    sender: int
    src_owner: int
    dest_owner: int
    value: int
    fee: int
    liquidity_fee: int
    calldata_hash: bytes
    refund_mode: int
    refund_vault: int
    refund_capsule_hash: bytes
    escrow_id: bytes
    byte_length: int
    accounted_gas: int
    refund: int
    enqueued_at: int
    due_at: int
    deposit: int


@dataclass(frozen=True)
class CreditAuthorizationV2:
    source_domain_id: bytes
    src_epoch: int
    src_bridge: int
    bridge_execution_hash: bytes
    emitted_at_block: int
    msg_hash: bytes
    destination_domain_id: bytes
    dest_chain_id: int
    enqueue_by: int
    sender: int
    src_owner: int
    dest_owner: int
    value: int
    fee: int
    liquidity_fee: int
    calldata_hash: bytes
    calldata_length: int
    escrow_id: bytes


@dataclass(frozen=True)
class SourceLiabilityV2:
    value: int
    execution_fee: int
    liquidity_fee: int
    status: int
    queue_index: int
    pull_class: int
    pull_beneficiary: int
    pull_amount: int
    total_live_liability: int


def credit_authorization_from_envelope(
        envelope: BridgeEnvelope) -> CreditAuthorizationV2:
    return CreditAuthorizationV2(
        envelope.source_domain_id, envelope.src_epoch, envelope.src_bridge,
        envelope.bridge_execution_hash, envelope.emitted_at_block,
        envelope.msg_hash, envelope.destination_domain_id,
        envelope.dest_chain_id, envelope.enqueue_by, envelope.sender,
        envelope.src_owner, envelope.dest_owner, envelope.value, envelope.fee,
        envelope.liquidity_fee, envelope.calldata_hash, envelope.byte_length,
        envelope.escrow_id)


def encode_credit_authorization_return(
        authorization: CreditAuthorizationV2) -> bytes:
    encoded = (
        b32(authorization.source_domain_id) + u256(authorization.src_epoch)
        + address_word(authorization.src_bridge)
        + b32(authorization.bridge_execution_hash)
        + u256(authorization.emitted_at_block) + b32(authorization.msg_hash)
        + b32(authorization.destination_domain_id)
        + u256(authorization.dest_chain_id) + u256(authorization.enqueue_by)
        + address_word(authorization.sender)
        + address_word(authorization.src_owner)
        + address_word(authorization.dest_owner) + u256(authorization.value)
        + u256(authorization.fee) + u256(authorization.liquidity_fee)
        + b32(authorization.calldata_hash)
        + u256(authorization.calldata_length) + b32(authorization.escrow_id))
    assert (authorization.src_epoch <= UINT64_MAX
            and authorization.emitted_at_block <= UINT64_MAX
            and authorization.dest_chain_id <= UINT64_MAX
            and authorization.enqueue_by <= UINT64_MAX
            and authorization.fee <= UINT64_MAX
            and authorization.liquidity_fee <= UINT64_MAX
            and authorization.calldata_length <= UINT32_MAX
            and len(encoded) == 576)
    return encoded


def decode_credit_authorization_return(
        returndata: bytes) -> CreditAuthorizationV2:
    assert len(returndata) == 576
    words = tuple(returndata[offset:offset + 32]
                  for offset in range(0, len(returndata), 32))
    result = CreditAuthorizationV2(
        b32(words[0]), uint_word_value(words[1], 64),
        address_word_value(words[2]), b32(words[3]),
        uint_word_value(words[4], 64), b32(words[5]), b32(words[6]),
        uint_word_value(words[7], 64), uint_word_value(words[8], 64),
        address_word_value(words[9]), address_word_value(words[10]),
        address_word_value(words[11]), uint_word_value(words[12]),
        uint_word_value(words[13], 64), uint_word_value(words[14], 64),
        b32(words[15]), uint_word_value(words[16], 32), b32(words[17]))
    assert returndata == encode_credit_authorization_return(result)
    return result


def encode_credit_liability_return(liability: SourceLiabilityV2) -> bytes:
    encoded = (
        u256(liability.value) + u256(liability.execution_fee)
        + u256(liability.liquidity_fee) + u256(liability.status)
        + u256(liability.queue_index) + u256(liability.pull_class)
        + address_word(liability.pull_beneficiary)
        + u256(liability.pull_amount) + u256(liability.total_live_liability))
    assert (liability.execution_fee <= UINT64_MAX
            and liability.liquidity_fee <= UINT64_MAX
            and liability.status < 1 << 8
            and liability.queue_index <= UINT64_MAX
            and liability.pull_class < 1 << 8
            and len(encoded) == 288)
    return encoded


def decode_credit_liability_return(returndata: bytes) -> SourceLiabilityV2:
    assert len(returndata) == 288
    words = tuple(returndata[offset:offset + 32]
                  for offset in range(0, len(returndata), 32))
    result = SourceLiabilityV2(
        uint_word_value(words[0]), uint_word_value(words[1], 64),
        uint_word_value(words[2], 64), uint_word_value(words[3], 8),
        uint_word_value(words[4], 64), uint_word_value(words[5], 8),
        address_word_value(words[6]), uint_word_value(words[7]),
        uint_word_value(words[8]))
    assert returndata == encode_credit_liability_return(result)
    return result


def encode_source_credit_read_calldata(selector: bytes,
                                       credit_id: bytes) -> bytes:
    assert selector in (
        CREDIT_AUTHORIZATION_V2_SELECTOR, CREDIT_LIABILITY_V2_SELECTOR)
    encoded = selector + b32(credit_id)
    assert len(encoded) == 36
    return encoded


def decode_source_credit_read_call(
        calldata: bytes, expected_credit_id: bytes, gas_limit: int,
        returndata: bytes) -> CreditAuthorizationV2 | SourceLiabilityV2:
    assert (len(calldata) == 36
            and calldata[4:] == b32(expected_credit_id)
            and gas_limit == SOURCE_CREDIT_READ_GAS_LIMIT)
    if calldata[:4] == CREDIT_AUTHORIZATION_V2_SELECTOR:
        return decode_credit_authorization_return(returndata)
    assert calldata[:4] == CREDIT_LIABILITY_V2_SELECTOR
    return decode_credit_liability_return(returndata)


def validate_source_liability_semantics(
        authorization: CreditAuthorizationV2, liability: SourceLiabilityV2,
        observed_balance_account: int,
        observed_source_bridge_balance: int) -> None:
    credit_liability = (
        liability.value + liability.execution_fee + liability.liquidity_fee)
    assert (credit_liability < 1 << 256
            and observed_balance_account == authorization.src_bridge
            and liability.value == authorization.value
            and liability.execution_fee == authorization.fee
            and liability.liquidity_fee == authorization.liquidity_fee
            and liability.status == 1
            and liability.queue_index == UINT64_MAX
            and liability.pull_class == 0
            and liability.pull_beneficiary == 0
            and liability.pull_amount == 0
            and liability.total_live_liability >= credit_liability
            and observed_source_bridge_balance >= liability.total_live_liability)


def validate_source_credit_read(
        authorization: CreditAuthorizationV2, liability: SourceLiabilityV2,
        expected_authorization: CreditAuthorizationV2,
        expected_liability: SourceLiabilityV2,
        observed_balance_account: int,
        observed_source_bridge_balance: int) -> None:
    assert (authorization == expected_authorization
            and liability == expected_liability)
    validate_source_liability_semantics(
        authorization, liability, observed_balance_account,
        observed_source_bridge_balance)


def forced_descriptor(envelope: ForcedEnvelope) -> bytes:
    return (
        address20(envelope.sender) + u64(envelope.nonce)
        + u256(envelope.chain_id) + b32(envelope.raw_tx_hash)
        + u32(envelope.byte_length) + u64(envelope.gas_limit)
        + u64(envelope.accounted_gas) + u256(envelope.max_fee)
        + u64(envelope.valid_until) + address20(envelope.refund)
        + u64(envelope.enqueued_at) + u64(envelope.due_at) + u256(envelope.deposit)
    )


def bridge_descriptor(envelope: BridgeEnvelope) -> bytes:
    assert (envelope.liquidity_fee > 0 and envelope.refund_mode == 1
            and envelope.refund_vault == 0
            and envelope.refund_capsule_hash == bytes(32)
            and 0 < envelope.value + envelope.fee < 1 << 256)
    return (
        b32(envelope.msg_hash)
        + u256(envelope.src_chain_id) + b32(envelope.source_domain_id)
        + u64(envelope.src_epoch)
        + address20(envelope.src_bridge)
        + b32(envelope.bridge_execution_hash) + u64(envelope.emitted_at_block)
        + b32(envelope.destination_domain_id) + u256(envelope.dest_chain_id)
        + u64(envelope.enqueue_by)
        + address20(envelope.sender) + address20(envelope.src_owner)
        + address20(envelope.dest_owner) + u256(envelope.value)
        + u64(envelope.fee) + u64(envelope.liquidity_fee)
        + b32(envelope.calldata_hash)
        + u8(envelope.refund_mode) + address20(envelope.refund_vault)
        + b32(envelope.refund_capsule_hash)
        + b32(envelope.escrow_id) + u32(envelope.byte_length)
        + u64(envelope.accounted_gas) + address20(envelope.refund)
        + u64(envelope.enqueued_at) + u64(envelope.due_at)
        + u256(envelope.deposit)
    )


def forced_leaf(index: int, envelope: ForcedEnvelope) -> bytes:
    descriptor = forced_descriptor(envelope)
    assert len(descriptor) == 220
    return keccak256(D_FORCE_USER + u64(index) + descriptor)


def bridge_leaf(index: int, envelope: BridgeEnvelope) -> bytes:
    descriptor = bridge_descriptor(envelope)
    assert len(descriptor) == 541
    return keccak256(D_FORCE_BRIDGE + u64(index) + descriptor)


@dataclass(frozen=True)
class SourceBridgeDescriptor:
    factory: int
    factory_runtime_hash: bytes
    factory_configuration_hash: bytes
    bundle_salt: bytes
    bundle_init_code_hash: bytes
    bundle_deployer: int
    bundle_deployer_runtime_hash: bytes
    legacy_v1_bridge: int
    source_bridge: int
    bridge_runtime_hash: bytes
    bridge_config_hash: bytes
    storage_layout_hash: bytes
    credit_registry: int
    registry_runtime_hash: bytes
    registry_config_hash: bytes
    quota_manager: int
    quota_runtime_hash: bytes
    quota_config_hash: bytes
    support_registry: int
    support_registry_runtime_hash: bytes
    support_registry_configuration_hash: bytes
    terminal_verifier: int
    terminal_verifier_runtime_hash: bytes
    terminal_verifier_config_hash: bytes
    pauser: int
    signal_service: int
    bridge_kernel_profile_hash: bytes
    src_epoch: int


def create2_address(factory: int, salt: bytes,
                    init_code_hash: bytes) -> int:
    digest = keccak256(
        b"\xff" + address20(factory) + b32(salt) + b32(init_code_hash))
    return int.from_bytes(digest[12:], "big")


def create_address_from_nonce(deployer: int, nonce: int) -> int:
    assert 1 <= nonce <= 3
    digest = keccak256(b"\xd6\x94" + address20(deployer) + u8(nonce))
    return int.from_bytes(digest[12:], "big")


def canonical_source_bridge_descriptor(descriptor: SourceBridgeDescriptor) -> bytes:
    addresses = (
        descriptor.factory, descriptor.bundle_deployer,
        descriptor.legacy_v1_bridge,
        descriptor.source_bridge, descriptor.credit_registry,
        descriptor.quota_manager, descriptor.support_registry,
        descriptor.terminal_verifier, descriptor.pauser,
        descriptor.signal_service,
    )
    hashes = (
        descriptor.factory_runtime_hash, descriptor.factory_configuration_hash,
        descriptor.bundle_salt, descriptor.bundle_init_code_hash,
        descriptor.bundle_deployer_runtime_hash,
        descriptor.bridge_runtime_hash, descriptor.bridge_config_hash,
        descriptor.storage_layout_hash,
        descriptor.registry_runtime_hash, descriptor.registry_config_hash,
        descriptor.quota_runtime_hash,
        descriptor.quota_config_hash,
        descriptor.support_registry_runtime_hash,
        descriptor.support_registry_configuration_hash,
        descriptor.terminal_verifier_runtime_hash,
        descriptor.terminal_verifier_config_hash,
        descriptor.bridge_kernel_profile_hash,
    )
    assert (all(address != 0 for address in addresses)
            and len({descriptor.factory, descriptor.bundle_deployer,
                     descriptor.legacy_v1_bridge,
                     descriptor.source_bridge, descriptor.credit_registry,
                     descriptor.quota_manager}) == 6
            and descriptor.bundle_deployer == create2_address(
                descriptor.factory, descriptor.bundle_salt,
                descriptor.bundle_init_code_hash)
            and descriptor.source_bridge == create_address_from_nonce(
                descriptor.bundle_deployer, 1)
            and descriptor.credit_registry == create_address_from_nonce(
                descriptor.bundle_deployer, 2)
            and descriptor.quota_manager == create_address_from_nonce(
                descriptor.bundle_deployer, 3)
            and all(value != bytes(32) for value in hashes)
            and descriptor.src_epoch > 0)
    encoded = (
        address20(descriptor.factory) + b32(descriptor.factory_runtime_hash)
        + b32(descriptor.factory_configuration_hash)
        + b32(descriptor.bundle_salt) + b32(descriptor.bundle_init_code_hash)
        + address20(descriptor.bundle_deployer)
        + b32(descriptor.bundle_deployer_runtime_hash)
        + address20(descriptor.legacy_v1_bridge)
        + address20(descriptor.source_bridge)
        + b32(descriptor.bridge_runtime_hash)
        + b32(descriptor.bridge_config_hash)
        + b32(descriptor.storage_layout_hash)
        + address20(descriptor.credit_registry)
        + b32(descriptor.registry_runtime_hash)
        + b32(descriptor.registry_config_hash)
        + address20(descriptor.quota_manager)
        + b32(descriptor.quota_runtime_hash)
        + b32(descriptor.quota_config_hash)
        + address20(descriptor.support_registry)
        + b32(descriptor.support_registry_runtime_hash)
        + b32(descriptor.support_registry_configuration_hash)
        + address20(descriptor.terminal_verifier)
        + b32(descriptor.terminal_verifier_runtime_hash)
        + b32(descriptor.terminal_verifier_config_hash)
        + address20(descriptor.pauser)
        + address20(descriptor.signal_service)
        + b32(descriptor.bridge_kernel_profile_hash)
        + u64(descriptor.src_epoch)
    )
    assert len(encoded) == 752
    return encoded


def validate_source_bridge_descriptor_encoding(
        descriptor: SourceBridgeDescriptor, encoded: bytes) -> bytes:
    assert len(encoded) == 752
    assert encoded == canonical_source_bridge_descriptor(descriptor)
    return encoded


def validate_component_config_getter(
        expected_runtime_hash: bytes, observed_extcodehash: bytes,
        expected_configuration_hash: bytes, calldata: bytes,
        gas_limit: int, returndata: bytes) -> bytes:
    """Model the fixed EXTCODEHASH-then-bounded-STATICCALL identity check."""
    assert (expected_runtime_hash != bytes(32)
            and observed_extcodehash == expected_runtime_hash
            and calldata == COMPONENT_CONFIG_GETTER_SELECTOR
            and gas_limit == COMPONENT_CONFIG_GETTER_GAS_LIMIT)
    return decode_configuration_hash_return(
        returndata, expected_configuration_hash)


def bridge_kernel_profile_hash(bridge_v2_abi_hash: bytes,
                               status_transition_hash: bytes,
                               custody_rules_hash: bytes) -> bytes:
    """Acyclic Bridge kernel commitment; it deliberately contains no domain."""
    descriptor = (u16(2) + u8(1)
                  + u64(604_800) + u64(2_592_000)
                  + b32(bridge_v2_abi_hash)
                  + b32(status_transition_hash)
                  + b32(custody_rules_hash))
    assert len(descriptor) == 115
    return keccak256(D_BRIDGE_KERNEL + u32(len(descriptor)) + descriptor)


def bridge_execution_hash(descriptor: SourceBridgeDescriptor) -> bytes:
    encoded = canonical_source_bridge_descriptor(descriptor)
    return keccak256(D_BRIDGE_EXECUTION + u32(len(encoded)) + encoded)


def validate_source_terminal_verifier_binding(
        descriptor: SourceBridgeDescriptor,
        component: ComponentDescriptor) -> None:
    assert (
        (descriptor.terminal_verifier,
         descriptor.terminal_verifier_runtime_hash,
         descriptor.terminal_verifier_config_hash)
        == (component.address, component.runtime_hash, component.config_hash))


def fixture_source_bridge_descriptor(
        bridge_kernel_profile_hash_: bytes,
        terminal_verifier: ComponentDescriptor) -> SourceBridgeDescriptor:
    factory = 0xF123
    bundle_salt = bytes.fromhex("30" * 32)
    bundle_init_code_hash = bytes.fromhex("31" * 32)
    bundle_deployer = create2_address(
        factory, bundle_salt, bundle_init_code_hash)
    source_bridge = create_address_from_nonce(bundle_deployer, 1)
    return SourceBridgeDescriptor(
        factory, bytes.fromhex("2e" * 32), bytes.fromhex("2f" * 32),
        bundle_salt, bundle_init_code_hash, bundle_deployer,
        bytes.fromhex("2d" * 32), 0xB000, source_bridge,
        bytes.fromhex("32" * 32),
        bytes.fromhex("34" * 32), bytes.fromhex("33" * 32),
        create_address_from_nonce(bundle_deployer, 2),
        bytes.fromhex("35" * 32),
        bytes.fromhex("36" * 32),
        create_address_from_nonce(bundle_deployer, 3),
        bytes.fromhex("37" * 32),
        bytes.fromhex("38" * 32),
        0xD004, bytes.fromhex("39" * 32), bytes.fromhex("3a" * 32),
        terminal_verifier.address, terminal_verifier.runtime_hash,
        terminal_verifier.config_hash, 0xD005, 0xD006,
        bridge_kernel_profile_hash_, 7)


@dataclass(frozen=True)
class DestinationBridgeDescriptor:
    bridge: int
    runtime_hash: bytes
    configuration_hash: bytes
    storage_layout_hash: bytes
    bridge_kernel_profile_hash: bytes
    inbox_credit_store: int
    terminal_accumulator: int
    terminal_domain_registrar: int
    quota_manager: int
    native_liquidity_pool: int


def canonical_destination_bridge_descriptor(
        descriptor: DestinationBridgeDescriptor) -> bytes:
    assert (descriptor.bridge != 0
            and descriptor.runtime_hash != bytes(32)
            and descriptor.configuration_hash != bytes(32)
            and descriptor.storage_layout_hash != bytes(32)
            and descriptor.bridge_kernel_profile_hash != bytes(32)
            and descriptor.inbox_credit_store != 0
            and descriptor.terminal_accumulator != 0
            and descriptor.terminal_domain_registrar != 0
            and descriptor.quota_manager != 0
            and descriptor.native_liquidity_pool != 0)
    encoded = (address20(descriptor.bridge)
               + b32(descriptor.runtime_hash)
               + b32(descriptor.configuration_hash)
               + b32(descriptor.storage_layout_hash)
               + b32(descriptor.bridge_kernel_profile_hash)
               + address20(descriptor.inbox_credit_store)
               + address20(descriptor.terminal_accumulator)
               + address20(descriptor.terminal_domain_registrar)
               + address20(descriptor.quota_manager)
               + address20(descriptor.native_liquidity_pool))
    assert len(encoded) == 248
    return encoded


def destination_bridge_execution_hash(
        descriptor: DestinationBridgeDescriptor) -> bytes:
    encoded = canonical_destination_bridge_descriptor(descriptor)
    return keccak256(
        D_DESTINATION_BRIDGE_EXECUTION + u32(len(encoded)) + encoded)


@dataclass(frozen=True)
class ComponentDescriptor:
    address: int
    runtime_hash: bytes
    config_hash: bytes


def component_config_hash(kind: int, config: bytes) -> bytes:
    assert 1 <= kind <= 10 and 0 < len(config) < 1 << 16
    assert len(config) == (80, 168, 21, 73, 60, 52, 80, 21, 76, 164)[kind - 1]
    return keccak256(D_COMPONENT_CONFIG + u8(kind) + u16(len(config)) + config)


def forced_queue_config_hash(active_settlement_router: int) -> bytes:
    encoded = (address20(active_settlement_router) + u8(FORCE_DEPTH)
               + u64(UINT64_MAX) + b32(keccak256(D_FORCE_EMPTY))
               + b32(keccak256(D_FORCED_DESCRIPTOR_SCHEMA)))
    assert len(encoded) == 93
    return keccak256(D_FORCED_QUEUE_CONFIG + u16(len(encoded)) + encoded)


@dataclass(frozen=True)
class DataSessionConfigV1:
    settlement_chain_id: int
    protocol_version: int
    settlement: int
    active_settlement_router: int
    protocol_version_manager: int
    data_rent: int
    execution_profile_hash: bytes
    bond: int
    base: int
    byte_rent: int
    blob_bps: int


def data_session_config_hash(config: DataSessionConfigV1) -> bytes:
    assert (
        config.settlement_chain_id > 0
        and 0 < config.protocol_version <= UINT64_MAX
        and config.settlement != 0
        and config.active_settlement_router != 0
        and config.protocol_version_manager != 0
        and config.data_rent != 0
        and b32(config.execution_profile_hash) != bytes(32)
        and config.bond > 0
        and config.base > 0
        and config.byte_rent >= 0
        and 0 <= config.blob_bps <= 10_000
    )
    encoded = (
        u256(config.settlement_chain_id) + u64(config.protocol_version)
        + address20(config.settlement)
        + address20(config.active_settlement_router)
        + address20(config.protocol_version_manager)
        + address20(config.data_rent)
        + b32(config.execution_profile_hash) + u256(config.bond)
        + u256(config.base) + u256(config.byte_rent) + u16(config.blob_bps)
        + u64(86_400) + u64(86_400)
        + u16(1_024) + u16(2) + u16(2_100) + u8(8) + u8(6)
        + address20(0x0A) + u32(50_000) + u256(BLS_MODULUS)
        + u32(131_072) + u32(126_972) + u16(9)
    )
    assert len(encoded) == 340
    return keccak256(D_DATA_SESSION_CONFIG + u32(len(encoded)) + encoded)


def destination_bridge_component_config(
        storage_layout_hash: bytes, bridge_kernel_profile_hash: bytes,
        inbox_credit_store: int, terminal_accumulator: int,
        terminal_domain_registrar: int, quota_manager: int,
        native_liquidity_pool: int) -> bytes:
    assert (storage_layout_hash != bytes(32)
            and bridge_kernel_profile_hash != bytes(32)
            and inbox_credit_store != 0 and terminal_accumulator != 0
            and terminal_domain_registrar != 0 and quota_manager != 0
            and native_liquidity_pool != 0)
    encoded = (b32(storage_layout_hash) + b32(bridge_kernel_profile_hash)
               + address20(inbox_credit_store)
               + address20(terminal_accumulator)
               + address20(terminal_domain_registrar)
               + address20(quota_manager)
               + address20(native_liquidity_pool))
    assert len(encoded) == 164
    return encoded


def destination_infrastructure_hash(
        components: tuple[ComponentDescriptor, ...]) -> bytes:
    assert len(components) == 10
    encoded = b""
    for component in components:
        assert (component.address != 0 and component.runtime_hash != bytes(32)
                and component.config_hash != bytes(32))
        encoded += (address20(component.address) + b32(component.runtime_hash)
                    + b32(component.config_hash))
    assert len(encoded) == 840
    return keccak256(D_DESTINATION_INFRASTRUCTURE
                     + u32(len(encoded)) + encoded)


@dataclass(frozen=True)
class MigrationVerifierDescriptor:
    verifier: int
    runtime_hash: bytes
    configuration_hash: bytes
    verifying_key_hash: bytes
    proof_system_id: bytes
    public_input_schema_hash: bytes
    selector: bytes
    maximum_proof_bytes: int
    verification_gas_limit: int


def _migration_verifier_configuration_hash(
        descriptor: MigrationVerifierDescriptor) -> bytes:
    assert (descriptor.verifier != 0
            and descriptor.runtime_hash != bytes(32)
            and descriptor.verifying_key_hash != bytes(32)
            and descriptor.proof_system_id != bytes(32)
            and descriptor.public_input_schema_hash != bytes(32)
            and descriptor.selector != bytes(4)
            and 0 < descriptor.maximum_proof_bytes
                <= MAX_MIGRATION_PROOF_BYTES
            and 0 < descriptor.verification_gas_limit <= UINT64_MAX)
    return keccak256(
        MIGRATION_VERIFIER_CONFIG_TYPEHASH
        + b32(descriptor.verifying_key_hash)
        + b32(descriptor.proof_system_id)
        + b32(descriptor.public_input_schema_hash)
        + bytes4_word(descriptor.selector)
        + u256(descriptor.maximum_proof_bytes)
        + u256(descriptor.verification_gas_limit)
    )


def migration_verifier_configuration_hash(
        descriptor: MigrationVerifierDescriptor) -> bytes:
    configuration_hash = _migration_verifier_configuration_hash(descriptor)
    assert descriptor.configuration_hash == configuration_hash
    return configuration_hash


def migration_verifier_descriptor_hash(
        descriptor: MigrationVerifierDescriptor) -> bytes:
    configuration_hash = migration_verifier_configuration_hash(descriptor)
    return keccak256(
        MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH
        + address_word(descriptor.verifier)
        + b32(descriptor.runtime_hash)
        + b32(descriptor.configuration_hash)
        + b32(descriptor.verifying_key_hash)
        + b32(descriptor.proof_system_id)
        + b32(descriptor.public_input_schema_hash)
        + bytes4_word(descriptor.selector)
        + u256(descriptor.maximum_proof_bytes)
        + u256(descriptor.verification_gas_limit)
    )


@dataclass(frozen=True)
class DeploymentCommitmentV2:
    transition_kind: int
    target_protocol_version: int
    target_manifest_hash: bytes
    target_registration_hash: bytes
    destination_infrastructure_hash: bytes
    components_hash: bytes
    pool_configuration_hash: bytes
    retirement_queue_count: int
    prestate_policy_hash: bytes
    poststate_policy_hash: bytes


def deployment_prestate_policy_hash(transition_kind: int) -> bytes:
    assert transition_kind in (1, 2)
    return keccak256(D_DEPLOYMENT_PRESTATE_POLICY + u8(transition_kind))


def deployment_poststate_policy_hash(transition_kind: int) -> bytes:
    assert transition_kind in (1, 2)
    return keccak256(D_DEPLOYMENT_POSTSTATE_POLICY + u8(transition_kind))


def manifest_components_hash(
        components: tuple[ComponentDescriptor, ...]) -> bytes:
    assert len(components) == 10
    encoded = b"".join(
        address_word(component.address) + b32(component.runtime_hash)
        + b32(component.config_hash)
        for component in components)
    assert len(encoded) == 30 * 32
    return keccak256(encoded)


def deployment_commitment_hash(statement: DeploymentCommitmentV2) -> bytes:
    assert (statement.transition_kind in (1, 2)
            and 0 < statement.target_protocol_version <= UINT64_MAX
            and statement.target_registration_hash != bytes(32)
            and 0 <= statement.retirement_queue_count <= UINT64_MAX
            and statement.prestate_policy_hash
                == deployment_prestate_policy_hash(statement.transition_kind)
            and statement.poststate_policy_hash
                == deployment_poststate_policy_hash(statement.transition_kind))
    encoded = (
        u256(statement.transition_kind)
        + u256(statement.target_protocol_version)
        + b32(statement.target_manifest_hash)
        + b32(statement.target_registration_hash)
        + b32(statement.destination_infrastructure_hash)
        + b32(statement.components_hash)
        + b32(statement.pool_configuration_hash)
        + u256(statement.retirement_queue_count)
        + b32(statement.prestate_policy_hash)
        + b32(statement.poststate_policy_hash)
    )
    assert len(encoded) == 10 * 32
    return keccak256(DEPLOYMENT_COMMITMENT_TYPEHASH + encoded)


def legacy_signal_checkpoint_hash(header_number: int, imported_header_hash: bytes,
                                  imported_state_root: bytes) -> bytes:
    assert (0 <= header_number < 1 << 48
            and imported_header_hash != bytes(32)
            and imported_state_root != bytes(32))
    return keccak256(D_LEGACY_CHECKPOINT + header_number.to_bytes(6, "big")
                     + b32(imported_header_hash) + b32(imported_state_root))


@dataclass(frozen=True)
class LegacyInboxConfigV1:
    proof_verifier: int
    proposer_checker: int
    prover_whitelist: int
    signal_service: int
    bond_token: int
    min_bond: int
    liveness_bond: int
    withdrawal_delay: int
    proving_window: int
    permissionless_proving_delay: int
    max_proof_submission_delay: int
    ring_buffer_size: int
    basefee_sharing_pctg: int
    forced_inclusion_delay: int
    forced_inclusion_fee_in_gwei: int
    forced_inclusion_fee_double_threshold: int
    permissionless_inclusion_multiplier: int


def legacy_inbox_configuration_hash(config: LegacyInboxConfigV1) -> bytes:
    addresses = (config.proof_verifier, config.proposer_checker,
                 config.signal_service, config.bond_token)
    assert (all(address != 0 for address in addresses)
            and len(set(addresses)) == len(addresses)
            and 0 <= config.prover_whitelist < 1 << 160
            and 0 <= config.min_bond <= UINT64_MAX
            and 0 <= config.liveness_bond <= UINT64_MAX
            and 0 <= config.withdrawal_delay < 1 << 48
            and 0 <= config.proving_window < 1 << 48
            and 0 <= config.permissionless_proving_delay < 1 << 48
            and 0 <= config.max_proof_submission_delay < 1 << 48
            and 0 < config.ring_buffer_size < 1 << 48
            and 0 <= config.basefee_sharing_pctg < 1 << 8
            and 0 < config.forced_inclusion_delay < 1 << 16
            and 0 < config.forced_inclusion_fee_in_gwei <= UINT64_MAX
            and 0 < config.forced_inclusion_fee_double_threshold <= UINT64_MAX
            and 0 < config.permissionless_inclusion_multiplier < 1 << 8)
    return keccak256(
        D_LEGACY_GENESIS_INBOX_CONFIG
        + address20(config.proof_verifier)
        + address20(config.proposer_checker)
        + address20(config.prover_whitelist)
        + address20(config.signal_service) + address20(config.bond_token)
        + u64(config.min_bond) + u64(config.liveness_bond)
        + u48(config.withdrawal_delay) + u48(config.proving_window)
        + u48(config.permissionless_proving_delay)
        + u48(config.max_proof_submission_delay)
        + u48(config.ring_buffer_size) + u8(config.basefee_sharing_pctg)
        + u16(config.forced_inclusion_delay)
        + u64(config.forced_inclusion_fee_in_gwei)
        + u64(config.forced_inclusion_fee_double_threshold)
        + u8(config.permissionless_inclusion_multiplier))


def encode_legacy_inbox_config_return(config: LegacyInboxConfigV1) -> bytes:
    legacy_inbox_configuration_hash(config)
    encoded = (
        address_word(config.proof_verifier)
        + address_word(config.proposer_checker)
        + address_word(config.prover_whitelist)
        + address_word(config.signal_service) + address_word(config.bond_token)
        + u256(config.min_bond) + u256(config.liveness_bond)
        + u256(config.withdrawal_delay) + u256(config.proving_window)
        + u256(config.permissionless_proving_delay)
        + u256(config.max_proof_submission_delay)
        + u256(config.ring_buffer_size) + u256(config.basefee_sharing_pctg)
        + u256(config.forced_inclusion_delay)
        + u256(config.forced_inclusion_fee_in_gwei)
        + u256(config.forced_inclusion_fee_double_threshold)
        + u256(config.permissionless_inclusion_multiplier))
    assert len(encoded) == 17 * 32
    return encoded


def decode_legacy_inbox_config_return(returndata: bytes) -> LegacyInboxConfigV1:
    assert len(returndata) == 17 * 32
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(17))
    config = LegacyInboxConfigV1(
        *(address_word_value(words[index]) for index in range(5)),
        uint_word_value(words[5], 64), uint_word_value(words[6], 64),
        *(uint_word_value(words[index], 48) for index in range(7, 12)),
        uint_word_value(words[12], 8), uint_word_value(words[13], 16),
        uint_word_value(words[14], 64), uint_word_value(words[15], 64),
        uint_word_value(words[16], 8))
    assert returndata == encode_legacy_inbox_config_return(config)
    return config


def legacy_genesis_deployment_hash(
        chain_id: int, proxy: int, proxy_runtime_hash: bytes,
        implementation: int, implementation_runtime_hash: bytes,
        configuration_hash: bytes, router: int) -> bytes:
    assert (chain_id > 0 and proxy != 0 and implementation != 0 and router != 0
            and len({proxy, implementation, router}) == 3
            and proxy_runtime_hash != bytes(32)
            and implementation_runtime_hash != bytes(32)
            and configuration_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_DEPLOYMENT + u256(chain_id) + address20(proxy)
        + b32(proxy_runtime_hash) + address20(implementation)
        + b32(implementation_runtime_hash) + b32(configuration_hash)
        + address20(router))


@dataclass(frozen=True)
class LegacyGenesisCampaignV1:
    status: int
    nonce: int
    generation: int
    force_cutoff_block: int
    proposal_cutoff_block: int
    quiesce_not_before_block: int
    resume_by_block: int
    resume_by_timestamp: int
    review_finalized_by_block: int
    target_settlement: int
    target_protocol_version: int
    target_manifest_hash: bytes
    target_registration_hash: bytes
    review_commitment: bytes
    campaign_id: bytes


@dataclass(frozen=True)
class ProtocolChangeOperationIdentityV1:
    settlement_chain_id: int
    protocol_change_timelock: int
    protocol_version_manager: int
    operation_nonce: int
    operation_kind: int
    payload: bytes


@dataclass(frozen=True)
class GovernanceDelayAuthorityDescriptorV1:
    settlement_chain_id: int
    protocol_change_timelock: int
    protocol_change_timelock_runtime_hash: bytes
    dao_proposer: int
    protocol_version_manager: int


@dataclass(frozen=True)
class ProtocolVersionManagerConfigurationV1:
    settlement_chain_id: int
    protocol_change_timelock: int
    governance_delay_authority_descriptor_hash: bytes
    active_settlement_router: int
    forced_queue: int
    builder_registry: int
    schedule_oracle: int
    aggregator_seat_market: int
    aggregator_seat_market_runtime_hash: bytes
    aggregator_seat_market_configuration_hash: bytes
    active_settlement_router_runtime_hash: bytes
    active_settlement_router_configuration_hash: bytes
    forced_queue_runtime_hash: bytes
    forced_queue_configuration_hash: bytes
    builder_registry_runtime_hash: bytes
    builder_registry_configuration_hash: bytes
    schedule_oracle_runtime_hash: bytes
    schedule_oracle_configuration_hash: bytes
    bridge_domain_registry_runtime_hash: bytes
    bridge_domain_registry_configuration_hash: bytes
    bridge_credit_registry_runtime_hash: bytes
    bridge_credit_registry_configuration_hash: bytes
    bridge_domain_registry: int
    bridge_credit_registry: int
    manifest_namespace: bytes
    release_router_registration_gas: int
    release_market_installation_gas: int
    release_postread_gas: int
    release_post_callback_reserve_gas: int


@dataclass(frozen=True)
class ProtocolVersionManagerDescriptorV1:
    protocol_version_manager: int
    protocol_version_manager_runtime_hash: bytes
    protocol_version_manager_configuration_hash: bytes


@dataclass(frozen=True)
class ProtocolChangeOperationRowV1:
    state: int
    nonce: int
    operation_kind: int
    payload_bytes: int
    payload_hash: bytes
    queued_at: int
    execute_after: int


@dataclass(frozen=True)
class VersionMigrationLeaseV1:
    state: int
    generation: int
    source_protocol_version: int
    target_protocol_version: int
    target_manifest_hash: bytes
    target_registration_hash: bytes
    arm_id: bytes
    armed_at_timestamp: int
    abort_after_timestamp: int


@dataclass(frozen=True)
class SettlementDeploymentDescriptorV1:
    factory: int
    factory_runtime_hash: bytes
    factory_configuration_hash: bytes
    salt: bytes
    init_code_hash: bytes
    target_settlement: int
    target_runtime_hash: bytes
    target_configuration_hash: bytes


def protocol_change_operation_domain_hash() -> bytes:
    return keccak256(D_PROTOCOL_CHANGE_OPERATION)


def protocol_change_operation_id(
        operation: ProtocolChangeOperationIdentityV1) -> bytes:
    assert (0 < operation.settlement_chain_id < 1 << 256
            and operation.protocol_change_timelock != 0
            and operation.protocol_version_manager != 0
            and operation.protocol_change_timelock
                != operation.protocol_version_manager
            and 0 < operation.operation_nonce <= UINT64_MAX
            and 1 <= operation.operation_kind <= 4
            and 0 < len(operation.payload)
                <= PROTOCOL_CHANGE_MAX_PAYLOAD_BYTES)
    validate_protocol_change_payload(operation.operation_kind,
                                     operation.payload)
    return keccak256(
        D_PROTOCOL_CHANGE_OPERATION + u256(operation.settlement_chain_id)
        + address20(operation.protocol_change_timelock)
        + address20(operation.protocol_version_manager)
        + u64(operation.operation_nonce) + u8(operation.operation_kind)
        + u32(len(operation.payload)) + keccak256(operation.payload))


def governance_delay_authority_descriptor_hash(
        descriptor: GovernanceDelayAuthorityDescriptorV1) -> bytes:
    assert (0 < descriptor.settlement_chain_id < 1 << 256
            and descriptor.protocol_change_timelock != 0
            and descriptor.protocol_change_timelock_runtime_hash != bytes(32)
            and descriptor.dao_proposer != 0
            and descriptor.protocol_version_manager != 0
            and len({descriptor.protocol_change_timelock,
                     descriptor.dao_proposer,
                     descriptor.protocol_version_manager}) == 3)
    return keccak256(
        D_PROTOCOL_CHANGE_TIMELOCK + u256(descriptor.settlement_chain_id)
        + address20(descriptor.protocol_change_timelock)
        + b32(descriptor.protocol_change_timelock_runtime_hash)
        + address20(descriptor.dao_proposer)
        + address20(descriptor.protocol_version_manager)
        + u64(PROTOCOL_CHANGE_DELAY_SECONDS)
        + protocol_change_operation_domain_hash())


def protocol_version_manager_configuration_hash(
        config: ProtocolVersionManagerConfigurationV1) -> bytes:
    addresses = (
        config.protocol_change_timelock, config.active_settlement_router,
        config.forced_queue, config.builder_registry, config.schedule_oracle,
        config.aggregator_seat_market, config.bridge_domain_registry,
        config.bridge_credit_registry)
    assert (0 < config.settlement_chain_id < 1 << 256
            and all(address != 0 for address in addresses)
            and len(set(addresses)) == len(addresses)
            and config.governance_delay_authority_descriptor_hash != bytes(32)
            and config.aggregator_seat_market_runtime_hash != bytes(32)
            and config.aggregator_seat_market_configuration_hash != bytes(32)
            and all(value != bytes(32) for value in (
                config.active_settlement_router_runtime_hash,
                config.active_settlement_router_configuration_hash,
                config.forced_queue_runtime_hash,
                config.forced_queue_configuration_hash,
                config.builder_registry_runtime_hash,
                config.builder_registry_configuration_hash,
                config.schedule_oracle_runtime_hash,
                config.schedule_oracle_configuration_hash,
                config.bridge_domain_registry_runtime_hash,
                config.bridge_domain_registry_configuration_hash,
                config.bridge_credit_registry_runtime_hash,
                config.bridge_credit_registry_configuration_hash,
            ))
            and config.manifest_namespace != bytes(32)
            and all(0 < value <= UINT64_MAX for value in (
                config.release_router_registration_gas,
                config.release_market_installation_gas,
                config.release_postread_gas,
                config.release_post_callback_reserve_gas)))
    return keccak256(
        D_PROTOCOL_VERSION_MANAGER_CONFIG + u256(config.settlement_chain_id)
        + address20(config.protocol_change_timelock)
        + b32(config.governance_delay_authority_descriptor_hash)
        + address20(config.active_settlement_router)
        + b32(config.active_settlement_router_runtime_hash)
        + b32(config.active_settlement_router_configuration_hash)
        + address20(config.forced_queue)
        + b32(config.forced_queue_runtime_hash)
        + b32(config.forced_queue_configuration_hash)
        + address20(config.builder_registry)
        + b32(config.builder_registry_runtime_hash)
        + b32(config.builder_registry_configuration_hash)
        + address20(config.schedule_oracle)
        + b32(config.schedule_oracle_runtime_hash)
        + b32(config.schedule_oracle_configuration_hash)
        + address20(config.aggregator_seat_market)
        + b32(config.aggregator_seat_market_runtime_hash)
        + b32(config.aggregator_seat_market_configuration_hash)
        + address20(config.bridge_domain_registry)
        + b32(config.bridge_domain_registry_runtime_hash)
        + b32(config.bridge_domain_registry_configuration_hash)
        + address20(config.bridge_credit_registry)
        + b32(config.bridge_credit_registry_runtime_hash)
        + b32(config.bridge_credit_registry_configuration_hash)
        + b32(config.manifest_namespace)
        + u64(PROTOCOL_CHANGE_DELAY_SECONDS)
        + u64(MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS)
        + u16(PROTOCOL_VERSION_REVIEW_FINALITY_BLOCKS)
        + u64(config.release_router_registration_gas)
        + u64(config.release_market_installation_gas)
        + u64(config.release_postread_gas)
        + u64(config.release_post_callback_reserve_gas))


def protocol_version_manager_descriptor_hash(
        descriptor: ProtocolVersionManagerDescriptorV1) -> bytes:
    assert (descriptor.protocol_version_manager != 0
            and descriptor.protocol_version_manager_runtime_hash != bytes(32)
            and descriptor.protocol_version_manager_configuration_hash
                != bytes(32))
    return keccak256(
        D_PROTOCOL_VERSION_MANAGER
        + address20(descriptor.protocol_version_manager)
        + b32(descriptor.protocol_version_manager_runtime_hash)
        + b32(descriptor.protocol_version_manager_configuration_hash))


def fixture_protocol_authority() -> tuple[
        GovernanceDelayAuthorityDescriptorV1, bytes,
        ProtocolVersionManagerConfigurationV1,
        ProtocolVersionManagerDescriptorV1, bytes]:
    timelock_descriptor = GovernanceDelayAuthorityDescriptorV1(
        1, 0xD201, bytes.fromhex("4c" * 32), 0xD202, 0xD200)
    timelock_descriptor_hash = governance_delay_authority_descriptor_hash(
        timelock_descriptor)
    market_configuration = pvm_derived_market_authority_configuration_hash_v1(
        1, 0xA102, 1, 0xD200, 0xAD01)
    manager_config = ProtocolVersionManagerConfigurationV1(
        1, 0xD201, timelock_descriptor_hash, 0xAD01, 0xF000, 0xA100,
        0xA101, 0xA102, bytes.fromhex("a4" * 32), market_configuration,
        bytes.fromhex("b1" * 32), bytes.fromhex("b2" * 32),
        bytes.fromhex("b3" * 32), bytes.fromhex("b4" * 32),
        bytes.fromhex("b5" * 32), bytes.fromhex("b6" * 32),
        bytes.fromhex("b7" * 32), bytes.fromhex("b8" * 32),
        bytes.fromhex("b9" * 32), bytes.fromhex("ba" * 32),
        bytes.fromhex("bb" * 32), bytes.fromhex("bc" * 32),
        0xA103, 0x5106, bytes.fromhex("37" * 32),
        15_000_000, 1_000_000, 500_000, 2_000_000)
    manager_config_hash = protocol_version_manager_configuration_hash(
        manager_config)
    manager_descriptor = ProtocolVersionManagerDescriptorV1(
        0xD200, bytes.fromhex("4d" * 32), manager_config_hash)
    manager_descriptor_hash = protocol_version_manager_descriptor_hash(
        manager_descriptor)
    return (timelock_descriptor, timelock_descriptor_hash, manager_config,
            manager_descriptor, manager_descriptor_hash)


def encode_protocol_change_timelock_config_return(
        dao_proposer: int, protocol_version_manager: int) -> bytes:
    assert (dao_proposer != 0 and protocol_version_manager != 0
            and dao_proposer != protocol_version_manager)
    encoded = (
        bytes4_word(PROTOCOL_CHANGE_TIMELOCK_CONFIG_MAGIC)
        + address_word(dao_proposer) + address_word(protocol_version_manager)
        + u256(PROTOCOL_CHANGE_DELAY_SECONDS)
        + b32(protocol_change_operation_domain_hash()))
    assert len(encoded) == 160
    return encoded


def decode_protocol_change_timelock_config_return(
        returndata: bytes) -> tuple[int, int]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == PROTOCOL_CHANGE_TIMELOCK_CONFIG_MAGIC
            and uint_word_value(returndata[96:128], 64)
                == PROTOCOL_CHANGE_DELAY_SECONDS
            and b32(returndata[128:160])
                == protocol_change_operation_domain_hash())
    result = (address_word_value(returndata[32:64]),
              address_word_value(returndata[64:96]))
    assert returndata == encode_protocol_change_timelock_config_return(*result)
    return result


def encode_protocol_version_manager_config_return(
        config: ProtocolVersionManagerConfigurationV1) -> bytes:
    protocol_version_manager_configuration_hash(config)
    encoded = (
        bytes4_word(PROTOCOL_VERSION_MANAGER_CONFIG_MAGIC)
        + u256(config.settlement_chain_id)
        + address_word(config.protocol_change_timelock)
        + address_word(config.active_settlement_router)
        + address_word(config.forced_queue) + address_word(config.builder_registry)
        + address_word(config.schedule_oracle)
        + address_word(config.aggregator_seat_market)
        + b32(config.aggregator_seat_market_runtime_hash)
        + b32(config.aggregator_seat_market_configuration_hash)
        + address_word(config.bridge_domain_registry)
        + address_word(config.bridge_credit_registry)
        + b32(config.governance_delay_authority_descriptor_hash)
        + b32(config.manifest_namespace)
        + u256(PROTOCOL_CHANGE_DELAY_SECONDS)
        + u256(MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS)
        + u256(PROTOCOL_VERSION_REVIEW_FINALITY_BLOCKS)
        + u256(config.release_router_registration_gas)
        + u256(config.release_market_installation_gas)
        + u256(config.release_postread_gas)
        + u256(config.release_post_callback_reserve_gas)
        + b32(config.active_settlement_router_runtime_hash)
        + b32(config.active_settlement_router_configuration_hash)
        + b32(config.forced_queue_runtime_hash)
        + b32(config.forced_queue_configuration_hash)
        + b32(config.builder_registry_runtime_hash)
        + b32(config.builder_registry_configuration_hash)
        + b32(config.schedule_oracle_runtime_hash)
        + b32(config.schedule_oracle_configuration_hash)
        + b32(config.bridge_domain_registry_runtime_hash)
        + b32(config.bridge_domain_registry_configuration_hash)
        + b32(config.bridge_credit_registry_runtime_hash)
        + b32(config.bridge_credit_registry_configuration_hash))
    assert len(encoded) == 1_056
    return encoded


def decode_protocol_version_manager_config_return(
        returndata: bytes) -> ProtocolVersionManagerConfigurationV1:
    assert (len(returndata) == 1_056
            and bytes4_word_value(returndata[:32])
                == PROTOCOL_VERSION_MANAGER_CONFIG_MAGIC
            and uint_word_value(returndata[448:480], 64)
                == PROTOCOL_CHANGE_DELAY_SECONDS
            and uint_word_value(returndata[480:512], 64)
                == MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS
            and uint_word_value(returndata[512:544], 16)
                == PROTOCOL_VERSION_REVIEW_FINALITY_BLOCKS
            and all(uint_word_value(returndata[offset:offset + 32], 64) > 0
                    for offset in range(544, 672, 32)))
    config = ProtocolVersionManagerConfigurationV1(
        uint_word_value(returndata[32:64]),
        address_word_value(returndata[64:96]), b32(returndata[384:416]),
        address_word_value(returndata[96:128]),
        address_word_value(returndata[128:160]),
        address_word_value(returndata[160:192]),
        address_word_value(returndata[192:224]),
        address_word_value(returndata[224:256]),
        b32(returndata[256:288]), b32(returndata[288:320]),
        *(b32(returndata[offset:offset + 32])
          for offset in range(672, 1_056, 32)),
        address_word_value(returndata[320:352]),
        address_word_value(returndata[352:384]), b32(returndata[416:448]),
        *(uint_word_value(returndata[offset:offset + 32], 64)
          for offset in range(544, 672, 32)))
    assert returndata == encode_protocol_version_manager_config_return(config)
    return config


def encode_protocol_change_operation_return(
        row: ProtocolChangeOperationRowV1) -> bytes:
    if row.state == 0:
        assert row == ProtocolChangeOperationRowV1(
            0, 0, 0, 0, bytes(32), 0, 0)
    else:
        assert (1 <= row.state <= 4 and 0 < row.nonce <= UINT64_MAX
                and 1 <= row.operation_kind <= 4
                and 0 < row.payload_bytes <= PROTOCOL_CHANGE_MAX_PAYLOAD_BYTES
                and row.payload_hash != bytes(32)
                and 0 < row.queued_at <= UINT64_MAX
                and row.queued_at + PROTOCOL_CHANGE_DELAY_SECONDS
                    <= UINT64_MAX
                and row.execute_after
                    == row.queued_at + PROTOCOL_CHANGE_DELAY_SECONDS)
    encoded = (
        bytes4_word(PROTOCOL_CHANGE_OPERATION_MAGIC) + u256(row.state)
        + u256(row.nonce) + u256(row.operation_kind)
        + u256(row.payload_bytes) + b32(row.payload_hash)
        + u256(row.queued_at) + u256(row.execute_after))
    assert len(encoded) == 256
    return encoded


def decode_protocol_change_operation_return(
        returndata: bytes) -> ProtocolChangeOperationRowV1:
    assert (len(returndata) == 256
            and bytes4_word_value(returndata[:32])
                == PROTOCOL_CHANGE_OPERATION_MAGIC)
    row = ProtocolChangeOperationRowV1(
        uint_word_value(returndata[32:64], 8),
        uint_word_value(returndata[64:96], 64),
        uint_word_value(returndata[96:128], 8),
        uint_word_value(returndata[128:160], 32), b32(returndata[160:192]),
        uint_word_value(returndata[192:224], 64),
        uint_word_value(returndata[224:256], 64))
    assert returndata == encode_protocol_change_operation_return(row)
    return row


def protocol_change_execute_allowed(
        row: ProtocolChangeOperationRowV1, block_timestamp: int) -> bool:
    assert 0 <= block_timestamp <= UINT64_MAX
    return row.state == 1 and block_timestamp >= row.execute_after


def protocol_change_cancel_allowed(
        row: ProtocolChangeOperationRowV1, caller: int,
        dao_proposer: int) -> bool:
    assert caller != 0 and dao_proposer != 0
    return row.state == 1 and caller == dao_proposer


def encode_protocol_change_operation_calldata(operation_id: bytes) -> bytes:
    assert operation_id != bytes(32)
    return PROTOCOL_CHANGE_OPERATION_SELECTOR + b32(operation_id)


def decode_protocol_change_operation_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == PROTOCOL_CHANGE_OPERATION_SELECTOR)
    operation_id = b32(calldata[4:36])
    assert calldata == encode_protocol_change_operation_calldata(operation_id)
    return operation_id


def encode_protocol_apply_return() -> bytes:
    return bytes4_word(PROTOCOL_APPLY_MAGIC)


def decode_protocol_apply_return(returndata: bytes) -> None:
    assert returndata == encode_protocol_apply_return()


def version_migration_arm_id(
        settlement_chain_id: int, protocol_version_manager: int,
        generation: int, source_protocol_version: int,
        target_protocol_version: int, target_manifest_hash: bytes,
        target_registration_hash: bytes, armed_at_timestamp: int,
        abort_after_timestamp: int,
        protocol_change_operation_id: bytes) -> bytes:
    assert (0 < settlement_chain_id < 1 << 256
            and protocol_version_manager != 0
            and 0 < generation <= UINT64_MAX
            and 0 < source_protocol_version < target_protocol_version
                <= UINT64_MAX
            and target_manifest_hash != bytes(32)
            and target_registration_hash != bytes(32)
            and 0 < armed_at_timestamp <= UINT64_MAX
            and armed_at_timestamp + MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS
                <= UINT64_MAX
            and abort_after_timestamp
                == armed_at_timestamp + MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS
            and protocol_change_operation_id != bytes(32))
    return keccak256(
        D_VERSION_MIGRATION_ARM + u256(settlement_chain_id)
        + address20(protocol_version_manager) + u64(generation)
        + u64(source_protocol_version) + u64(target_protocol_version)
        + b32(target_manifest_hash) + b32(target_registration_hash)
        + u64(armed_at_timestamp) + u64(abort_after_timestamp)
        + b32(protocol_change_operation_id))


def create_version_migration_lease(
        settlement_chain_id: int, protocol_version_manager: int,
        generation: int, source_protocol_version: int,
        target_protocol_version: int, target_manifest_hash: bytes,
        target_registration_hash: bytes, armed_at_timestamp: int,
        protocol_change_operation_id: bytes) -> VersionMigrationLeaseV1:
    abort_after_timestamp = (
        armed_at_timestamp + MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS)
    assert abort_after_timestamp <= UINT64_MAX
    arm_id = version_migration_arm_id(
        settlement_chain_id, protocol_version_manager, generation,
        source_protocol_version, target_protocol_version, target_manifest_hash,
        target_registration_hash, armed_at_timestamp, abort_after_timestamp,
        protocol_change_operation_id)
    return VersionMigrationLeaseV1(
        1, generation, source_protocol_version, target_protocol_version,
        target_manifest_hash, target_registration_hash, arm_id,
        armed_at_timestamp, abort_after_timestamp)


def encode_live_version_migration_lease_return(
        lease: VersionMigrationLeaseV1) -> bytes:
    if lease.state == 0:
        assert lease == VersionMigrationLeaseV1(
            0, 0, 0, 0, bytes(32), bytes(32), bytes(32), 0, 0)
    else:
        assert (lease.state == 1 and 0 < lease.generation <= UINT64_MAX
                and 0 < lease.source_protocol_version
                    < lease.target_protocol_version <= UINT64_MAX
                and lease.target_manifest_hash != bytes(32)
                and lease.target_registration_hash != bytes(32)
                and lease.arm_id != bytes(32)
                and 0 < lease.armed_at_timestamp <= UINT64_MAX
                and lease.abort_after_timestamp
                    == lease.armed_at_timestamp
                        + MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS
                and lease.abort_after_timestamp <= UINT64_MAX)
    encoded = (
        bytes4_word(VERSION_MIGRATION_LEASE_MAGIC) + u256(lease.state)
        + u256(lease.generation) + u256(lease.source_protocol_version)
        + u256(lease.target_protocol_version)
        + b32(lease.target_manifest_hash) + b32(lease.target_registration_hash)
        + b32(lease.arm_id) + u256(lease.armed_at_timestamp)
        + u256(lease.abort_after_timestamp))
    assert len(encoded) == 320
    return encoded


def decode_live_version_migration_lease_return(
        returndata: bytes) -> VersionMigrationLeaseV1:
    assert (len(returndata) == 320
            and bytes4_word_value(returndata[:32])
                == VERSION_MIGRATION_LEASE_MAGIC)
    lease = VersionMigrationLeaseV1(
        uint_word_value(returndata[32:64], 8),
        uint_word_value(returndata[64:96], 64),
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64), b32(returndata[160:192]),
        b32(returndata[192:224]), b32(returndata[224:256]),
        uint_word_value(returndata[256:288], 64),
        uint_word_value(returndata[288:320], 64))
    assert returndata == encode_live_version_migration_lease_return(lease)
    return lease


def validate_version_migration_lease(
        lease: VersionMigrationLeaseV1, settlement_chain_id: int,
        protocol_version_manager: int,
        protocol_change_operation_id: bytes) -> None:
    assert lease.state == 1
    assert lease.arm_id == version_migration_arm_id(
        settlement_chain_id, protocol_version_manager, lease.generation,
        lease.source_protocol_version, lease.target_protocol_version,
        lease.target_manifest_hash, lease.target_registration_hash,
        lease.armed_at_timestamp, lease.abort_after_timestamp,
        protocol_change_operation_id)


def version_migration_activation_allowed(
        lease: VersionMigrationLeaseV1, block_timestamp: int) -> bool:
    assert 0 <= block_timestamp <= UINT64_MAX
    return lease.state == 1 and block_timestamp < lease.abort_after_timestamp


def permissionless_abort_expired_migration_allowed(
        lease: VersionMigrationLeaseV1, block_timestamp: int) -> bool:
    assert 0 <= block_timestamp <= UINT64_MAX
    return lease.state == 1 and block_timestamp >= lease.abort_after_timestamp


@dataclass(frozen=True)
class SettlementAuthorizationV1:
    protocol_version: int
    target: int
    runtime_hash: bytes
    configuration_hash: bytes
    expected_magic: bytes
    target_registration_hash: bytes


def settlement_authorization_id(
        market_chain_id: int, market: int, settlement_chain_id: int,
        authorization: SettlementAuthorizationV1) -> bytes:
    assert (market_chain_id > 0 and market != 0 and settlement_chain_id > 0
            and 0 < authorization.protocol_version <= UINT64_MAX
            and authorization.target != 0
            and authorization.runtime_hash != bytes(32)
            and authorization.configuration_hash != bytes(32)
            and len(authorization.expected_magic) == 4
            and authorization.expected_magic != bytes(4)
            and authorization.target_registration_hash != bytes(32))
    return keccak256(
        D_SEAT_TARGET_AUTHORIZATION + u256(market_chain_id)
        + address20(market) + u256(settlement_chain_id)
        + u64(authorization.protocol_version)
        + address20(authorization.target) + b32(authorization.runtime_hash)
        + b32(authorization.configuration_hash)
        + authorization.expected_magic)


def encode_install_settlement_authorization_calldata(
        authorization: SettlementAuthorizationV1) -> bytes:
    settlement_authorization_id(1, 1, 1, authorization)
    encoded = (
        INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR
        + u256(authorization.protocol_version) + address_word(authorization.target)
        + b32(authorization.runtime_hash)
        + b32(authorization.configuration_hash)
        + bytes4_word(authorization.expected_magic)
        + b32(authorization.target_registration_hash))
    assert len(encoded) == 4 + 6 * 32
    return encoded


def decode_install_settlement_authorization_calldata(
        calldata: bytes) -> SettlementAuthorizationV1:
    assert (len(calldata) == 4 + 6 * 32
            and calldata[:4] == INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR)
    words = tuple(calldata[4 + index * 32:4 + (index + 1) * 32]
                  for index in range(6))
    authorization = SettlementAuthorizationV1(
        uint_word_value(words[0], 64), address_word_value(words[1]),
        b32(words[2]), b32(words[3]), bytes4_word_value(words[4]),
        b32(words[5]))
    assert calldata == encode_install_settlement_authorization_calldata(
        authorization)
    return authorization


def encode_install_settlement_authorization_return(
        authorization_id: bytes) -> bytes:
    assert authorization_id != bytes(32)
    encoded = (bytes4_word(SETTLEMENT_AUTHORIZATION_INSTALL_MAGIC)
               + b32(authorization_id))
    assert len(encoded) == 64
    return encoded


def decode_install_settlement_authorization_return(returndata: bytes) -> bytes:
    assert (len(returndata) == 64
            and bytes4_word_value(returndata[:32])
                == SETTLEMENT_AUTHORIZATION_INSTALL_MAGIC)
    authorization_id = b32(returndata[32:64])
    assert returndata == encode_install_settlement_authorization_return(
        authorization_id)
    return authorization_id


def encode_settlement_authorization_calldata(
        authorization_id: bytes) -> bytes:
    assert authorization_id != bytes(32)
    return SETTLEMENT_AUTHORIZATION_SELECTOR + b32(authorization_id)


def decode_settlement_authorization_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == SETTLEMENT_AUTHORIZATION_SELECTOR)
    authorization_id = b32(calldata[4:36])
    assert calldata == encode_settlement_authorization_calldata(
        authorization_id)
    return authorization_id


def encode_settlement_authorization_return(
        authorization: SettlementAuthorizationV1) -> bytes:
    settlement_authorization_id(1, 1, 1, authorization)
    encoded = (
        bytes4_word(SETTLEMENT_AUTHORIZATION_GETTER_MAGIC)
        + u256(authorization.protocol_version) + address_word(authorization.target)
        + b32(authorization.runtime_hash)
        + b32(authorization.configuration_hash)
        + bytes4_word(authorization.expected_magic)
        + b32(authorization.target_registration_hash))
    assert len(encoded) == 224
    return encoded


def decode_settlement_authorization_return(
        returndata: bytes) -> SettlementAuthorizationV1:
    assert (len(returndata) == 224
            and bytes4_word_value(returndata[:32])
                == SETTLEMENT_AUTHORIZATION_GETTER_MAGIC)
    authorization = decode_install_settlement_authorization_calldata(
        INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR + returndata[32:])
    assert returndata == encode_settlement_authorization_return(authorization)
    return authorization


@dataclass(frozen=True)
class LegacyBlobSlice:
    blob_hashes: tuple[bytes, ...]
    offset: int
    timestamp: int


@dataclass(frozen=True)
class LegacyDerivationSource:
    is_forced_inclusion: bool
    blob_slice: LegacyBlobSlice


@dataclass(frozen=True)
class LegacyProposal:
    proposal_id: int
    timestamp: int
    end_of_submission_window_timestamp: int
    proposer: int
    parent_proposal_hash: bytes
    origin_block_number: int
    origin_block_hash: bytes
    basefee_sharing_pctg: int
    sources: tuple[LegacyDerivationSource, ...]


@dataclass(frozen=True)
class LegacyForcedInclusion:
    fee_in_gwei: int
    blob_slice: LegacyBlobSlice


@dataclass(frozen=True)
class LegacyGenesisScanV1:
    campaign_id: bytes
    proposal_scan_start: int
    next_proposal_id: int
    proposal_count: int
    proposal_bytes: int
    proposal_rows_root: bytes
    forced_head: int
    forced_tail: int
    forced_count: int
    forced_bytes: int
    forced_rows_root: bytes
    abandoned_native_wei: int
    min_data_expiry: int
    legacy_resume_profile_hash: bytes


@dataclass(frozen=True)
class LegacyGenesisResumeProfileV1:
    legacy_deployment_hash: bytes
    legacy_campaign_fence_descriptor_hash: bytes
    proof_verifier_graph_hash: bytes
    legacy_resume_verifier_route_hash: bytes
    signal_service_checkpoint_descriptor_hash: bytes
    proposer_checker_descriptor_hash: bytes
    prover_whitelist_descriptor_hash: bytes
    min_bond: int
    liveness_bond: int
    withdrawal_delay: int
    proving_window: int
    permissionless_proving_delay: int
    max_proof_submission_delay: int
    ring_buffer_size: int
    forced_inclusion_delay: int
    forced_inclusion_fee_in_gwei: int
    forced_inclusion_fee_double_threshold: int
    permissionless_inclusion_multiplier: int
    max_forced_inclusions_per_proposal: int
    max_normal_blob_hashes_per_proposal: int
    legacy_blob_retention_seconds: int
    legacy_resume_proof_generation_max_seconds: int


@dataclass(frozen=True)
class LegacyGenesisAbandonmentReceiptV1:
    campaign_id: bytes
    scan_commitment: bytes
    proposal_scan_start: int
    abandoned_proposal_start: int
    proposal_end: int
    scanned_proposal_count: int
    abandoned_proposal_count: int
    proposal_bytes: int
    proposal_rows_root: bytes
    forced_start: int
    forced_end: int
    forced_count: int
    forced_bytes: int
    forced_rows_root: bytes
    abandoned_native_wei: int
    abandoned_bond_liability_wei: int
    min_data_expiry: int
    legacy_resume_profile_hash: bytes


def _encode_legacy_blob_slice_body(blob_slice: LegacyBlobSlice) -> bytes:
    assert (1 <= len(blob_slice.blob_hashes) < 1 << 16
            and all(blob_hash != bytes(32)
                    for blob_hash in blob_slice.blob_hashes)
            and 0 <= blob_slice.offset < 1 << 24
            and 0 < blob_slice.timestamp < 1 << 48)
    encoded = (
        u256(3 * 32) + u256(blob_slice.offset) + u256(blob_slice.timestamp)
        + u256(len(blob_slice.blob_hashes))
        + b"".join(b32(blob_hash) for blob_hash in blob_slice.blob_hashes))
    assert len(encoded) == 4 * 32 + len(blob_slice.blob_hashes) * 32
    return encoded


def _decode_legacy_blob_slice_body(encoded: bytes) -> LegacyBlobSlice:
    assert len(encoded) >= 5 * 32 and len(encoded) % 32 == 0
    assert uint_word_value(encoded[0:32]) == 3 * 32
    offset = uint_word_value(encoded[32:64], 24)
    timestamp = uint_word_value(encoded[64:96], 48)
    count = uint_word_value(encoded[96:128])
    assert 1 <= count < 1 << 16 and len(encoded) == (4 + count) * 32
    blob_slice = LegacyBlobSlice(
        tuple(b32(encoded[(4 + index) * 32:(5 + index) * 32])
              for index in range(count)),
        offset, timestamp)
    assert encoded == _encode_legacy_blob_slice_body(blob_slice)
    return blob_slice


def encode_legacy_blob_slice(blob_slice: LegacyBlobSlice) -> bytes:
    encoded = u256(32) + _encode_legacy_blob_slice_body(blob_slice)
    assert len(encoded) == (5 + len(blob_slice.blob_hashes)) * 32
    return encoded


def decode_legacy_blob_slice(encoded: bytes) -> LegacyBlobSlice:
    assert len(encoded) >= 6 * 32 and uint_word_value(encoded[:32]) == 32
    blob_slice = _decode_legacy_blob_slice_body(encoded[32:])
    assert encoded == encode_legacy_blob_slice(blob_slice)
    return blob_slice


def _validate_legacy_derivation_source(source: LegacyDerivationSource) -> None:
    _encode_legacy_blob_slice_body(source.blob_slice)
    if source.is_forced_inclusion:
        assert len(source.blob_slice.blob_hashes) == 1
    else:
        assert (1 <= len(source.blob_slice.blob_hashes)
                <= LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL)


def _encode_legacy_derivation_source_body(
        source: LegacyDerivationSource) -> bytes:
    _validate_legacy_derivation_source(source)
    encoded = (
        u256(1 if source.is_forced_inclusion else 0) + u256(2 * 32)
        + _encode_legacy_blob_slice_body(source.blob_slice))
    assert len(encoded) == 6 * 32 + len(source.blob_slice.blob_hashes) * 32
    return encoded


def _decode_legacy_derivation_source_body(
        encoded: bytes) -> LegacyDerivationSource:
    assert len(encoded) >= 7 * 32 and len(encoded) % 32 == 0
    is_forced = uint_word_value(encoded[0:32], 8)
    assert is_forced in (0, 1)
    assert uint_word_value(encoded[32:64]) == 2 * 32
    source = LegacyDerivationSource(
        bool(is_forced), _decode_legacy_blob_slice_body(encoded[64:]))
    assert encoded == _encode_legacy_derivation_source_body(source)
    return source


def encode_legacy_derivation_source(source: LegacyDerivationSource) -> bytes:
    encoded = u256(32) + _encode_legacy_derivation_source_body(source)
    assert len(encoded) == 7 * 32 + len(source.blob_slice.blob_hashes) * 32
    return encoded


def decode_legacy_derivation_source(encoded: bytes) -> LegacyDerivationSource:
    assert len(encoded) >= 8 * 32 and uint_word_value(encoded[:32]) == 32
    source = _decode_legacy_derivation_source_body(encoded[32:])
    assert encoded == encode_legacy_derivation_source(source)
    return source


def _validate_legacy_proposal(proposal: LegacyProposal) -> None:
    assert (0 <= proposal.proposal_id < 1 << 48
            and 0 < proposal.timestamp < 1 << 48
            and 0 <= proposal.end_of_submission_window_timestamp < 1 << 48
            and (proposal.end_of_submission_window_timestamp == 0
                 or proposal.end_of_submission_window_timestamp
                    >= proposal.timestamp)
            and proposal.proposer != 0
            and (proposal.proposal_id == 0
                 or proposal.parent_proposal_hash != bytes(32))
            and 0 < proposal.origin_block_number < 1 << 48
            and proposal.origin_block_hash != bytes(32)
            and 0 <= proposal.basefee_sharing_pctg <= 100
            and 1 <= len(proposal.sources)
                <= LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL + 1)
    for index, source in enumerate(proposal.sources):
        _validate_legacy_derivation_source(source)
        assert source.blob_slice.timestamp <= proposal.timestamp
        if index + 1 == len(proposal.sources):
            assert (not source.is_forced_inclusion
                    and source.blob_slice.timestamp == proposal.timestamp)
        else:
            assert source.is_forced_inclusion


def encode_legacy_proposal(proposal: LegacyProposal) -> bytes:
    _validate_legacy_proposal(proposal)
    source_bodies = tuple(
        _encode_legacy_derivation_source_body(source)
        for source in proposal.sources)
    source_offsets: list[bytes] = []
    cursor = len(source_bodies) * 32
    for source_body in source_bodies:
        source_offsets.append(u256(cursor))
        cursor += len(source_body)
    sources_encoding = (
        u256(len(source_bodies)) + b"".join(source_offsets)
        + b"".join(source_bodies))
    proposal_body = (
        u256(proposal.proposal_id) + u256(proposal.timestamp)
        + u256(proposal.end_of_submission_window_timestamp)
        + address_word(proposal.proposer) + b32(proposal.parent_proposal_hash)
        + u256(proposal.origin_block_number) + b32(proposal.origin_block_hash)
        + u256(proposal.basefee_sharing_pctg) + u256(9 * 32)
        + sources_encoding)
    encoded = u256(32) + proposal_body
    assert (len(encoded) % 32 == 0
            and len(encoded) <= LEGACY_MAX_PROPOSAL_ROW_BYTES)
    return encoded


def decode_legacy_proposal(encoded: bytes) -> LegacyProposal:
    assert (len(encoded) >= 19 * 32
            and len(encoded) <= LEGACY_MAX_PROPOSAL_ROW_BYTES
            and len(encoded) % 32 == 0
            and uint_word_value(encoded[:32]) == 32)
    body = encoded[32:]
    assert uint_word_value(body[8 * 32:9 * 32]) == 9 * 32
    sources_encoding = body[9 * 32:]
    source_count = uint_word_value(sources_encoding[:32])
    assert (1 <= source_count
            <= LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL + 1)
    assert len(sources_encoding) >= (1 + source_count) * 32
    offsets = tuple(
        uint_word_value(sources_encoding[(1 + index) * 32:(2 + index) * 32])
        for index in range(source_count))
    expected_offset = source_count * 32
    sources: list[LegacyDerivationSource] = []
    for index, offset in enumerate(offsets):
        assert offset == expected_offset
        source_start = 32 + offset
        source_end = (
            32 + offsets[index + 1]
            if index + 1 < source_count else len(sources_encoding))
        assert source_start < source_end <= len(sources_encoding)
        source = _decode_legacy_derivation_source_body(
            sources_encoding[source_start:source_end])
        sources.append(source)
        expected_offset += source_end - source_start
    proposal = LegacyProposal(
        uint_word_value(body[0:32], 48),
        uint_word_value(body[32:64], 48),
        uint_word_value(body[64:96], 48),
        address_word_value(body[96:128]), b32(body[128:160]),
        uint_word_value(body[160:192], 48), b32(body[192:224]),
        uint_word_value(body[224:256], 8), tuple(sources))
    assert encoded == encode_legacy_proposal(proposal)
    return proposal


def encode_legacy_forced_inclusion(
        inclusion: LegacyForcedInclusion) -> bytes:
    assert (0 < inclusion.fee_in_gwei <= UINT64_MAX
            and len(inclusion.blob_slice.blob_hashes) == 1)
    blob_body = _encode_legacy_blob_slice_body(inclusion.blob_slice)
    encoded = u256(32) + u256(inclusion.fee_in_gwei) + u256(2 * 32) + blob_body
    assert len(encoded) == LEGACY_MAX_FORCED_ROW_BYTES
    return encoded


def decode_legacy_forced_inclusion(encoded: bytes) -> LegacyForcedInclusion:
    assert (len(encoded) == LEGACY_MAX_FORCED_ROW_BYTES
            and uint_word_value(encoded[:32]) == 32
            and uint_word_value(encoded[64:96]) == 2 * 32)
    inclusion = LegacyForcedInclusion(
        uint_word_value(encoded[32:64], 64),
        _decode_legacy_blob_slice_body(encoded[96:]))
    assert encoded == encode_legacy_forced_inclusion(inclusion)
    return inclusion


def legacy_proposal_row(
        proposal: LegacyProposal,
        legacy_blob_retention_seconds: int) -> tuple[int, int, bytes, int, int]:
    encoded = encode_legacy_proposal(proposal)
    decoded = decode_legacy_proposal(encoded)
    assert decoded == proposal
    data_expiry = min(
        legacy_genesis_row_data_expiry(
            source.blob_slice.timestamp, legacy_blob_retention_seconds)
        for source in proposal.sources)
    return (proposal.proposal_id, len(encoded), keccak256(encoded),
            data_expiry, 0)


def legacy_forced_inclusion_row(
        index: int, inclusion: LegacyForcedInclusion,
        legacy_blob_retention_seconds: int) -> tuple[int, int, bytes, int, int]:
    assert 0 <= index < 1 << 48
    encoded = encode_legacy_forced_inclusion(inclusion)
    decoded = decode_legacy_forced_inclusion(encoded)
    assert decoded == inclusion
    row_hash = legacy_genesis_forced_record_hash(encoded)
    data_expiry = legacy_genesis_row_data_expiry(
        inclusion.blob_slice.timestamp, legacy_blob_retention_seconds)
    abandoned_native_wei = inclusion.fee_in_gwei * 10**9
    assert abandoned_native_wei < 1 << 256
    return (index, len(encoded), row_hash, data_expiry,
            abandoned_native_wei)


def legacy_genesis_campaign_fence_descriptor_hash(
        router: int, legacy_proxy: int) -> bytes:
    assert router != 0 and legacy_proxy != 0 and router != legacy_proxy
    return keccak256(
        D_LEGACY_GENESIS_CAMPAIGN_FENCE
        + address20(router) + address20(legacy_proxy)
        + LEGACY_GENESIS_CAMPAIGN_SELECTOR + LEGACY_GENESIS_CAMPAIGN_MAGIC
        + u16(512) + u32(LEGACY_DESCRIPTOR_CALL_GAS)
        + LEGACY_GENESIS_STATE_SELECTOR + LEGACY_GENESIS_STATE_MAGIC
        + u16(512) + u32(LEGACY_DESCRIPTOR_CALL_GAS)
        + LEGACY_GENESIS_SCAN_STATE_SELECTOR + LEGACY_GENESIS_SCAN_STATE_MAGIC
        + u16(608) + u32(LEGACY_DESCRIPTOR_CALL_GAS))


def legacy_genesis_risc0_resume_key_policy_hash(
        block_image_id: bytes, aggregation_image_id: bytes) -> bytes:
    assert block_image_id != bytes(32) and aggregation_image_id != bytes(32)
    return keccak256(
        D_LEGACY_GENESIS_RISC0_KEY_POLICY
        + b32(block_image_id) + b32(aggregation_image_id))


def legacy_genesis_sp1_resume_key_policy_hash(
        block_program_vkey: bytes, aggregation_program_vkey: bytes) -> bytes:
    assert (block_program_vkey != bytes(32)
            and aggregation_program_vkey != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_SP1_KEY_POLICY
        + b32(block_program_vkey) + b32(aggregation_program_vkey))


def legacy_genesis_risc0_reth_verifier_descriptor_hash(
        adapter: int, adapter_runtime_hash: bytes, l2_chain_id: int,
        remote_verifier: int, remote_verifier_runtime_hash: bytes,
        key_policy_hash: bytes) -> bytes:
    assert (adapter != 0 and adapter_runtime_hash != bytes(32)
            and 0 < l2_chain_id <= UINT64_MAX
            and remote_verifier != 0 and remote_verifier != adapter
            and remote_verifier_runtime_hash != bytes(32)
            and key_policy_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_RISC0_VERIFIER
        + address20(adapter) + b32(adapter_runtime_hash)
        + u64(l2_chain_id) + address20(remote_verifier)
        + b32(remote_verifier_runtime_hash) + b32(key_policy_hash))


def legacy_genesis_sp1_reth_verifier_descriptor_hash(
        adapter: int, adapter_runtime_hash: bytes, l2_chain_id: int,
        remote_verifier: int, remote_verifier_runtime_hash: bytes,
        key_policy_hash: bytes) -> bytes:
    assert (adapter != 0 and adapter_runtime_hash != bytes(32)
            and 0 < l2_chain_id <= UINT64_MAX
            and remote_verifier != 0 and remote_verifier != adapter
            and remote_verifier_runtime_hash != bytes(32)
            and key_policy_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_SP1_VERIFIER
        + address20(adapter) + b32(adapter_runtime_hash)
        + u64(l2_chain_id) + address20(remote_verifier)
        + b32(remote_verifier_runtime_hash) + b32(key_policy_hash))


def legacy_genesis_proof_verifier_graph_hash(
        resume_pair_root: int, resume_pair_root_runtime_hash: bytes,
        risc0_adapter: int, risc0_reth_verifier_descriptor_hash: bytes,
        sp1_adapter: int, sp1_reth_verifier_descriptor_hash: bytes) -> bytes:
    assert (resume_pair_root != 0
            and resume_pair_root_runtime_hash != bytes(32)
            and risc0_adapter != 0 and sp1_adapter != 0
            and len({resume_pair_root, risc0_adapter, sp1_adapter}) == 3
            and risc0_reth_verifier_descriptor_hash != bytes(32)
            and sp1_reth_verifier_descriptor_hash != bytes(32)
            and risc0_reth_verifier_descriptor_hash
                != sp1_reth_verifier_descriptor_hash)
    return keccak256(
        D_LEGACY_GENESIS_PROOF_VERIFIER_GRAPH
        + address20(resume_pair_root) + b32(resume_pair_root_runtime_hash)
        + u8(2)
        + u8(5) + address20(risc0_adapter)
        + b32(risc0_reth_verifier_descriptor_hash)
        + u8(6) + address20(sp1_adapter)
        + b32(sp1_reth_verifier_descriptor_hash))


def legacy_genesis_resume_verifier_route_hash(
        proof_verifier_graph_hash: bytes,
        risc0_reth_verifier_descriptor_hash: bytes,
        risc0_resume_key_policy_hash: bytes,
        sp1_reth_verifier_descriptor_hash: bytes,
        sp1_resume_key_policy_hash: bytes) -> bytes:
    assert (proof_verifier_graph_hash != bytes(32)
            and risc0_reth_verifier_descriptor_hash != bytes(32)
            and risc0_resume_key_policy_hash != bytes(32)
            and sp1_reth_verifier_descriptor_hash != bytes(32)
            and sp1_resume_key_policy_hash != bytes(32)
            and risc0_reth_verifier_descriptor_hash
                != sp1_reth_verifier_descriptor_hash)
    return keccak256(
        D_LEGACY_GENESIS_RESUME_VERIFIER_ROUTE
        + b32(proof_verifier_graph_hash) + u8(2)
        + u8(5) + b32(risc0_reth_verifier_descriptor_hash)
        + b32(risc0_resume_key_policy_hash)
        + u8(6) + b32(sp1_reth_verifier_descriptor_hash)
        + b32(sp1_resume_key_policy_hash))


def legacy_genesis_proposer_checker_descriptor_hash(
        proposer_checker_proxy: int,
        proposer_checker_proxy_runtime_hash: bytes,
        proposer_checker_implementation: int,
        proposer_checker_implementation_runtime_hash: bytes,
        legacy_campaign_fence_descriptor_hash: bytes) -> bytes:
    assert (proposer_checker_proxy != 0
            and proposer_checker_proxy_runtime_hash != bytes(32)
            and proposer_checker_implementation != 0
            and proposer_checker_implementation != proposer_checker_proxy
            and proposer_checker_implementation_runtime_hash != bytes(32)
            and legacy_campaign_fence_descriptor_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_PROPOSER_CHECKER
        + address20(proposer_checker_proxy)
        + b32(proposer_checker_proxy_runtime_hash)
        + address20(proposer_checker_implementation)
        + b32(proposer_checker_implementation_runtime_hash)
        + u16(64) + b32(legacy_campaign_fence_descriptor_hash))


def legacy_genesis_prover_whitelist_descriptor_hash() -> bytes:
    return keccak256(
        D_LEGACY_GENESIS_PUBLIC_PROVING + address20(0) + u8(1))


def legacy_genesis_checkpoint_storage_layout_hash() -> bytes:
    return keccak256(
        D_LEGACY_GENESIS_CHECKPOINT_LAYOUT + u256(1) + u16(254)
        + keccak256(D_LEGACY_GENESIS_CHECKPOINT_RECORD_LITERAL))


def legacy_genesis_signal_service_checkpoint_descriptor_hash(
        signal_service_proxy: int, signal_service_proxy_runtime_hash: bytes,
        signal_service_direct_implementation: int,
        signal_service_direct_implementation_runtime_hash: bytes,
        signal_service_version: int, signal_service_authorized_syncer: int,
        remote_signal_service: int, signal_service_pauser: int,
        checkpoint_storage_layout_hash: bytes,
        legacy_campaign_fence_descriptor_hash: bytes) -> bytes:
    assert (signal_service_proxy != 0
            and signal_service_proxy_runtime_hash != bytes(32)
            and signal_service_direct_implementation != 0
            and signal_service_direct_implementation != signal_service_proxy
            and signal_service_direct_implementation_runtime_hash != bytes(32)
            and signal_service_version == 1
            and signal_service_authorized_syncer != 0
            and remote_signal_service != 0 and signal_service_pauser != 0
            and checkpoint_storage_layout_hash != bytes(32)
            and legacy_campaign_fence_descriptor_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_SIGNAL_SERVICE_CHECKPOINT
        + address20(signal_service_proxy)
        + b32(signal_service_proxy_runtime_hash)
        + address20(signal_service_direct_implementation)
        + b32(signal_service_direct_implementation_runtime_hash)
        + u256(signal_service_version)
        + address20(signal_service_authorized_syncer)
        + address20(remote_signal_service) + address20(signal_service_pauser)
        + b32(checkpoint_storage_layout_hash)
        + b32(legacy_campaign_fence_descriptor_hash))


def encode_legacy_resume_verifier_config_return(
        risc0_adapter: int, sp1_adapter: int,
        risc0_key_policy_hash: bytes, sp1_key_policy_hash: bytes) -> bytes:
    assert (risc0_adapter != 0 and sp1_adapter != 0
            and risc0_adapter != sp1_adapter
            and risc0_key_policy_hash != bytes(32)
            and sp1_key_policy_hash != bytes(32)
            and risc0_key_policy_hash != sp1_key_policy_hash)
    encoded = (
        bytes4_word(LEGACY_RESUME_VERIFIER_CONFIG_MAGIC)
        + address_word(risc0_adapter) + address_word(sp1_adapter)
        + b32(risc0_key_policy_hash) + b32(sp1_key_policy_hash))
    assert len(encoded) == 160
    return encoded


def decode_legacy_resume_verifier_config_return(
        returndata: bytes) -> tuple[int, int, bytes, bytes]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == LEGACY_RESUME_VERIFIER_CONFIG_MAGIC)
    result = (
        address_word_value(returndata[32:64]),
        address_word_value(returndata[64:96]), b32(returndata[96:128]),
        b32(returndata[128:160]))
    assert returndata == encode_legacy_resume_verifier_config_return(*result)
    return result


def _encode_legacy_resume_adapter_config_return(
        magic: bytes, l2_chain_id: int, remote_verifier: int,
        remote_runtime_hash: bytes, block_key: bytes,
        aggregation_key: bytes) -> bytes:
    assert (magic in (LEGACY_RESUME_RISC0_CONFIG_MAGIC,
                      LEGACY_RESUME_SP1_CONFIG_MAGIC)
            and 0 < l2_chain_id <= UINT64_MAX and remote_verifier != 0
            and remote_runtime_hash != bytes(32) and block_key != bytes(32)
            and aggregation_key != bytes(32))
    encoded = (
        bytes4_word(magic) + u256(l2_chain_id)
        + address_word(remote_verifier) + b32(remote_runtime_hash)
        + b32(block_key) + b32(aggregation_key))
    assert len(encoded) == 192
    return encoded


def _decode_legacy_resume_adapter_config_return(
        returndata: bytes, magic: bytes) -> tuple[int, int, bytes, bytes, bytes]:
    assert (len(returndata) == 192
            and bytes4_word_value(returndata[:32]) == magic)
    result = (
        uint_word_value(returndata[32:64], 64),
        address_word_value(returndata[64:96]), b32(returndata[96:128]),
        b32(returndata[128:160]), b32(returndata[160:192]))
    assert returndata == _encode_legacy_resume_adapter_config_return(
        magic, *result)
    return result


def encode_legacy_resume_risc0_config_return(
        l2_chain_id: int, remote_verifier: int,
        remote_runtime_hash: bytes, block_image_id: bytes,
        aggregation_image_id: bytes) -> bytes:
    return _encode_legacy_resume_adapter_config_return(
        LEGACY_RESUME_RISC0_CONFIG_MAGIC, l2_chain_id, remote_verifier,
        remote_runtime_hash, block_image_id, aggregation_image_id)


def decode_legacy_resume_risc0_config_return(
        returndata: bytes) -> tuple[int, int, bytes, bytes, bytes]:
    return _decode_legacy_resume_adapter_config_return(
        returndata, LEGACY_RESUME_RISC0_CONFIG_MAGIC)


def encode_legacy_resume_sp1_config_return(
        l2_chain_id: int, remote_verifier: int,
        remote_runtime_hash: bytes, block_program_vkey: bytes,
        aggregation_program_vkey: bytes) -> bytes:
    return _encode_legacy_resume_adapter_config_return(
        LEGACY_RESUME_SP1_CONFIG_MAGIC, l2_chain_id, remote_verifier,
        remote_runtime_hash, block_program_vkey, aggregation_program_vkey)


def decode_legacy_resume_sp1_config_return(
        returndata: bytes) -> tuple[int, int, bytes, bytes, bytes]:
    return _decode_legacy_resume_adapter_config_return(
        returndata, LEGACY_RESUME_SP1_CONFIG_MAGIC)


def encode_legacy_checkpoint_config_return(
        authorized_syncer: int, remote_signal_service: int, pauser: int,
        checkpoint_storage_layout_hash: bytes,
        campaign_fence_descriptor_hash: bytes) -> bytes:
    assert (authorized_syncer != 0 and remote_signal_service != 0
            and pauser != 0 and checkpoint_storage_layout_hash != bytes(32)
            and campaign_fence_descriptor_hash != bytes(32))
    encoded = (
        bytes4_word(LEGACY_CHECKPOINT_CONFIG_MAGIC)
        + address_word(authorized_syncer)
        + address_word(remote_signal_service) + address_word(pauser)
        + b32(checkpoint_storage_layout_hash)
        + b32(campaign_fence_descriptor_hash))
    assert len(encoded) == 192
    return encoded


def decode_legacy_checkpoint_config_return(
        returndata: bytes) -> tuple[int, int, int, bytes, bytes]:
    assert (len(returndata) == 192
            and bytes4_word_value(returndata[:32])
                == LEGACY_CHECKPOINT_CONFIG_MAGIC)
    result = (
        address_word_value(returndata[32:64]),
        address_word_value(returndata[64:96]),
        address_word_value(returndata[96:128]), b32(returndata[128:160]),
        b32(returndata[160:192]))
    assert returndata == encode_legacy_checkpoint_config_return(*result)
    return result


def encode_legacy_address_getter_return(address: int) -> bytes:
    assert address != 0
    return address_word(address)


def decode_legacy_address_getter_return(returndata: bytes) -> int:
    assert len(returndata) == 32
    address = address_word_value(returndata)
    assert returndata == encode_legacy_address_getter_return(address)
    return address


def encode_legacy_operator_count_return(operator_count: int) -> bytes:
    assert 1 <= operator_count <= 64
    return u256(operator_count)


def decode_legacy_operator_count_return(returndata: bytes) -> int:
    assert len(returndata) == 32
    operator_count = uint_word_value(returndata, 16)
    assert returndata == encode_legacy_operator_count_return(operator_count)
    return operator_count


def encode_legacy_signal_service_version_return() -> bytes:
    return u256(1)


def decode_legacy_signal_service_version_return(returndata: bytes) -> int:
    assert len(returndata) == 32 and uint_word_value(returndata) == 1
    assert returndata == encode_legacy_signal_service_version_return()
    return 1


def legacy_genesis_resume_time_policy_hash() -> bytes:
    return keccak256(LEGACY_GENESIS_RESUME_TIME_POLICY_LITERAL)


def _legacy_genesis_resume_profile_body(
        profile: LegacyGenesisResumeProfileV1) -> bytes:
    return (
        b32(profile.legacy_deployment_hash)
        + b32(profile.legacy_campaign_fence_descriptor_hash)
        + b32(profile.proof_verifier_graph_hash)
        + b32(profile.legacy_resume_verifier_route_hash)
        + b32(profile.signal_service_checkpoint_descriptor_hash)
        + b32(profile.proposer_checker_descriptor_hash)
        + b32(profile.prover_whitelist_descriptor_hash)
        + u64(profile.min_bond) + u64(profile.liveness_bond)
        + u64(profile.withdrawal_delay) + u64(profile.proving_window)
        + u64(profile.permissionless_proving_delay)
        + u64(profile.max_proof_submission_delay)
        + u48(profile.ring_buffer_size)
        + u16(profile.forced_inclusion_delay)
        + u64(profile.forced_inclusion_fee_in_gwei)
        + u64(profile.forced_inclusion_fee_double_threshold)
        + u16(profile.permissionless_inclusion_multiplier)
        + u16(profile.max_forced_inclusions_per_proposal)
        + u16(profile.max_normal_blob_hashes_per_proposal)
        + u64(profile.legacy_blob_retention_seconds)
        + u64(profile.legacy_resume_proof_generation_max_seconds)
        + legacy_genesis_resume_time_policy_hash())


def legacy_genesis_resume_profile_hash(
        profile: LegacyGenesisResumeProfileV1) -> bytes:
    assert (profile.legacy_deployment_hash != bytes(32)
            and profile.legacy_campaign_fence_descriptor_hash != bytes(32)
            and profile.proof_verifier_graph_hash != bytes(32)
            and profile.legacy_resume_verifier_route_hash != bytes(32)
            and profile.signal_service_checkpoint_descriptor_hash
                != bytes(32)
            and profile.proposer_checker_descriptor_hash != bytes(32)
            and profile.prover_whitelist_descriptor_hash != bytes(32)
            and 0 <= profile.min_bond <= UINT64_MAX
            and 0 <= profile.liveness_bond <= UINT64_MAX
            and 0 <= profile.withdrawal_delay <= UINT64_MAX
            and 0 <= profile.proving_window <= UINT64_MAX
            and 0 <= profile.permissionless_proving_delay <= UINT64_MAX
            and 0 <= profile.max_proof_submission_delay <= UINT64_MAX
            and 0 <= profile.ring_buffer_size < 1 << 48
            and 0 <= profile.forced_inclusion_delay < 1 << 16
            and 0 <= profile.forced_inclusion_fee_in_gwei <= UINT64_MAX
            and 0 <= profile.forced_inclusion_fee_double_threshold <= UINT64_MAX
            and 0 <= profile.permissionless_inclusion_multiplier < 1 << 16
            and profile.max_forced_inclusions_per_proposal
                == LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL
            and profile.max_normal_blob_hashes_per_proposal
                == LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL
            and 0 < profile.legacy_blob_retention_seconds <= UINT64_MAX
            and 0 < profile.legacy_resume_proof_generation_max_seconds
                <= UINT64_MAX)
    return keccak256(
        D_LEGACY_GENESIS_RESUME_PROFILE
        + _legacy_genesis_resume_profile_body(profile))


def legacy_genesis_row_data_expiry(
        blob_timestamp: int | None,
        legacy_blob_retention_seconds: int) -> int:
    assert 0 < legacy_blob_retention_seconds <= UINT64_MAX
    if blob_timestamp is None:
        return UINT64_MAX
    assert 0 < blob_timestamp < 1 << 48
    expiry = blob_timestamp + legacy_blob_retention_seconds
    assert expiry <= UINT64_MAX
    return expiry


def legacy_genesis_review_commitment(
        legacy_deployment_hash: bytes, legacy_resume_profile_hash: bytes,
        target_protocol_version: int, target_manifest_hash: bytes,
        target_registration_hash: bytes) -> bytes:
    assert (legacy_deployment_hash != bytes(32)
            and legacy_resume_profile_hash != bytes(32)
            and 0 < target_protocol_version <= UINT64_MAX
            and target_manifest_hash != bytes(32)
            and target_registration_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_REVIEW + b32(legacy_deployment_hash)
        + b32(legacy_resume_profile_hash) + u64(target_protocol_version)
        + b32(target_manifest_hash) + b32(target_registration_hash))


def legacy_genesis_abandonment_receipt_hash(
        receipt: LegacyGenesisAbandonmentReceiptV1) -> bytes:
    assert (receipt.campaign_id != bytes(32)
            and receipt.scan_commitment != bytes(32)
            and 0 <= receipt.proposal_scan_start
                <= receipt.abandoned_proposal_start
                <= receipt.proposal_end < 1 << 48
            and receipt.scanned_proposal_count
                == receipt.proposal_end - receipt.proposal_scan_start
            and receipt.abandoned_proposal_count
                == receipt.proposal_end - receipt.abandoned_proposal_start
            and 0 <= receipt.scanned_proposal_count < 1 << 16
            and 0 <= receipt.abandoned_proposal_count < 1 << 16
            and 0 <= receipt.proposal_bytes <= UINT32_MAX
            and receipt.proposal_rows_root != bytes(32)
            and 0 <= receipt.forced_start <= receipt.forced_end < 1 << 48
            and receipt.forced_count
                == receipt.forced_end - receipt.forced_start
            and 0 <= receipt.forced_count < 1 << 16
            and 0 <= receipt.forced_bytes <= UINT32_MAX
            and receipt.forced_rows_root != bytes(32)
            and 0 <= receipt.abandoned_native_wei < 1 << 256
            and receipt.abandoned_bond_liability_wei == 0
            and 0 < receipt.min_data_expiry <= UINT64_MAX
            and receipt.legacy_resume_profile_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_ABANDONMENT_RECEIPT + b32(receipt.campaign_id)
        + b32(receipt.scan_commitment) + u48(receipt.proposal_scan_start)
        + u48(receipt.abandoned_proposal_start)
        + u48(receipt.proposal_end) + u16(receipt.scanned_proposal_count)
        + u16(receipt.abandoned_proposal_count)
        + u32(receipt.proposal_bytes) + b32(receipt.proposal_rows_root)
        + u48(receipt.forced_start) + u48(receipt.forced_end)
        + u16(receipt.forced_count) + u32(receipt.forced_bytes)
        + b32(receipt.forced_rows_root) + u256(receipt.abandoned_native_wei)
        + u256(receipt.abandoned_bond_liability_wei)
        + u64(receipt.min_data_expiry)
        + b32(receipt.legacy_resume_profile_hash))


def legacy_genesis_campaign_id(
        legacy_deployment_hash: bytes,
        campaign: LegacyGenesisCampaignV1) -> bytes:
    assert (legacy_deployment_hash != bytes(32)
            and 0 < campaign.nonce <= UINT64_MAX
            and 0 < campaign.generation <= UINT64_MAX
            and 0 <= campaign.review_finalized_by_block
                < campaign.force_cutoff_block
                < campaign.proposal_cutoff_block
                < campaign.quiesce_not_before_block
                < campaign.resume_by_block <= UINT64_MAX
            and 0 < campaign.resume_by_timestamp <= UINT64_MAX
            and campaign.target_settlement != 0
            and 0 < campaign.target_protocol_version <= UINT64_MAX
            and campaign.target_manifest_hash != bytes(32)
            and campaign.target_registration_hash != bytes(32)
            and campaign.review_commitment != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_CAMPAIGN
        + b32(legacy_deployment_hash)
        + u64(campaign.nonce) + u64(campaign.generation)
        + u64(campaign.force_cutoff_block)
        + u64(campaign.proposal_cutoff_block)
        + u64(campaign.quiesce_not_before_block)
        + u64(campaign.resume_by_block)
        + u64(campaign.resume_by_timestamp)
        + u64(campaign.review_finalized_by_block)
        + address20(campaign.target_settlement)
        + u64(campaign.target_protocol_version)
        + b32(campaign.target_manifest_hash)
        + b32(campaign.target_registration_hash)
        + b32(campaign.review_commitment))


def encode_legacy_genesis_campaign_return(
        campaign: LegacyGenesisCampaignV1,
        legacy_deployment_hash: bytes) -> bytes:
    assert campaign.status in (0, 1, 2, 3, 4)
    if campaign.status == 0:
        assert all(value == 0 or value == bytes(32) for value in (
            campaign.nonce, campaign.generation, campaign.force_cutoff_block,
            campaign.proposal_cutoff_block,
            campaign.quiesce_not_before_block, campaign.resume_by_block,
            campaign.resume_by_timestamp,
            campaign.review_finalized_by_block, campaign.target_settlement,
            campaign.target_protocol_version, campaign.target_manifest_hash,
            campaign.target_registration_hash, campaign.review_commitment,
            campaign.campaign_id))
    else:
        assert (campaign.campaign_id != bytes(32)
                and campaign.campaign_id == legacy_genesis_campaign_id(
                    legacy_deployment_hash, campaign))
    encoded = (
        bytes4_word(LEGACY_GENESIS_CAMPAIGN_MAGIC) + u256(campaign.status)
        + u256(campaign.nonce) + u256(campaign.generation)
        + u256(campaign.force_cutoff_block)
        + u256(campaign.proposal_cutoff_block)
        + u256(campaign.quiesce_not_before_block)
        + u256(campaign.resume_by_block)
        + u256(campaign.resume_by_timestamp)
        + u256(campaign.review_finalized_by_block)
        + address_word(campaign.target_settlement)
        + u256(campaign.target_protocol_version)
        + b32(campaign.target_manifest_hash)
        + b32(campaign.target_registration_hash)
        + b32(campaign.review_commitment) + b32(campaign.campaign_id)
    )
    assert len(encoded) == 512
    return encoded


def decode_legacy_genesis_campaign_return(
        returndata: bytes,
        legacy_deployment_hash: bytes) -> LegacyGenesisCampaignV1:
    assert len(returndata) == 512
    assert bytes4_word_value(returndata[:32]) == LEGACY_GENESIS_CAMPAIGN_MAGIC
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 16))
    campaign = LegacyGenesisCampaignV1(
        uint_word_value(words[0], 8), uint_word_value(words[1], 64),
        uint_word_value(words[2], 64), uint_word_value(words[3], 64),
        uint_word_value(words[4], 64), uint_word_value(words[5], 64),
        uint_word_value(words[6], 64), uint_word_value(words[7], 64),
        uint_word_value(words[8], 64), address_word_value(words[9]),
        uint_word_value(words[10], 64), b32(words[11]), b32(words[12]),
        b32(words[13]), b32(words[14]))
    assert returndata == encode_legacy_genesis_campaign_return(
        campaign, legacy_deployment_hash)
    return campaign


def encode_legacy_genesis_preparation_return(
        next_proposal_id: int, last_finalized_proposal_id: int,
        forced_head: int, forced_tail: int,
        unfinalized_proposal_count: int, pending_forced_count: int,
        maximum_scan_bytes: int,
        legacy_resume_profile_hash: bytes) -> bytes:
    assert (0 <= last_finalized_proposal_id < next_proposal_id < 1 << 48
            and 0 <= forced_head <= forced_tail < 1 << 48
            and unfinalized_proposal_count
                == next_proposal_id - last_finalized_proposal_id - 1
            and pending_forced_count == forced_tail - forced_head
            and 0 <= unfinalized_proposal_count < 1 << 16
            and 0 <= pending_forced_count < 1 << 16
            and 0 < maximum_scan_bytes <= UINT32_MAX
            and legacy_resume_profile_hash != bytes(32))
    encoded = (
        bytes4_word(LEGACY_GENESIS_PREPARATION_MAGIC)
        + u256(next_proposal_id) + u256(last_finalized_proposal_id)
        + u256(forced_head) + u256(forced_tail)
        + u256(unfinalized_proposal_count) + u256(pending_forced_count)
        + u256(maximum_scan_bytes) + b32(legacy_resume_profile_hash))
    assert len(encoded) == 288
    return encoded


def decode_legacy_genesis_preparation_return(
        returndata: bytes) -> tuple[int, int, int, int, int, int, int, bytes]:
    assert len(returndata) == 288
    assert bytes4_word_value(returndata[:32]) \
        == LEGACY_GENESIS_PREPARATION_MAGIC
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 9))
    result = (
        uint_word_value(words[0], 48), uint_word_value(words[1], 48),
        uint_word_value(words[2], 48), uint_word_value(words[3], 48),
        uint_word_value(words[4], 16), uint_word_value(words[5], 16),
        uint_word_value(words[6], 32), b32(words[7]))
    assert returndata == encode_legacy_genesis_preparation_return(*result)
    return result


def encode_begin_legacy_genesis_scan_return(
        proposal_start: int, proposal_end: int,
        forced_start: int, forced_end: int) -> bytes:
    assert (0 <= proposal_start <= proposal_end < 1 << 48
            and 0 <= forced_start <= forced_end < 1 << 48)
    encoded = (
        bytes4_word(LEGACY_GENESIS_BEGIN_SCAN_MAGIC)
        + u256(proposal_start) + u256(proposal_end)
        + u256(forced_start) + u256(forced_end))
    assert len(encoded) == 160
    return encoded


def decode_begin_legacy_genesis_scan_return(
        returndata: bytes) -> tuple[int, int, int, int]:
    assert len(returndata) == 160
    assert bytes4_word_value(returndata[:32]) \
        == LEGACY_GENESIS_BEGIN_SCAN_MAGIC
    result = tuple(
        uint_word_value(returndata[index * 32:(index + 1) * 32], 48)
        for index in range(1, 5))
    assert returndata == encode_begin_legacy_genesis_scan_return(*result)
    return result


def encode_scan_legacy_genesis_proposals_calldata(
        generation: int, campaign_id: bytes,
        canonical_preimages: tuple[bytes, ...]) -> bytes:
    assert (0 < generation <= UINT64_MAX and campaign_id != bytes(32)
            and 1 <= len(canonical_preimages) <= 16
            and all(preimage for preimage in canonical_preimages))
    proposals = tuple(
        decode_legacy_proposal(preimage) for preimage in canonical_preimages)
    assert all(
        proposals[index].proposal_id + 1 == proposals[index + 1].proposal_id
        for index in range(len(proposals) - 1))
    assert sum(map(len, canonical_preimages)) \
        <= 16 * LEGACY_MAX_PROPOSAL_ROW_BYTES
    tails = tuple(abi_bytes_tail(preimage) for preimage in canonical_preimages)
    offsets: list[bytes] = []
    cursor = len(tails) * 32
    for tail in tails:
        offsets.append(u256(cursor))
        cursor += len(tail)
    array_encoding = (
        u256(len(tails)) + b"".join(offsets) + b"".join(tails))
    encoded = (
        LEGACY_GENESIS_SCAN_PROPOSALS_SELECTOR + u256(generation)
        + b32(campaign_id) + u256(3 * 32) + array_encoding)
    return encoded


def validate_legacy_genesis_scan_batch_size(
        cursor: int, end: int, requested_rows: int) -> None:
    assert 0 <= cursor < end < 1 << 48
    assert requested_rows == min(16, end - cursor)


def decode_scan_legacy_genesis_proposals_calldata(
        calldata: bytes) -> tuple[int, bytes, tuple[bytes, ...]]:
    assert (len(calldata) >= 4 + 4 * 32
            and calldata[:4] == LEGACY_GENESIS_SCAN_PROPOSALS_SELECTOR)
    arguments = calldata[4:]
    generation = uint_word_value(arguments[0:32], 64)
    campaign_id = b32(arguments[32:64])
    array_offset = uint_word_value(arguments[64:96])
    assert array_offset == 3 * 32 and array_offset + 32 <= len(arguments)
    array = arguments[array_offset:]
    count = uint_word_value(array[:32])
    assert 1 <= count <= 16 and len(array) >= 32 + count * 32
    element_head = array[32:32 + count * 32]
    element_tail = array[32 + count * 32:]
    preimages: list[bytes] = []
    expected_offset = count * 32
    for index in range(count):
        offset = uint_word_value(element_head[index * 32:(index + 1) * 32])
        assert offset == expected_offset
        tail_start = offset - count * 32
        assert tail_start + 32 <= len(element_tail)
        length = uint_word_value(element_tail[tail_start:tail_start + 32])
        padded_length = ceil32(length)
        tail_end = tail_start + 32 + padded_length
        assert tail_end <= len(element_tail)
        preimage = element_tail[tail_start + 32:tail_start + 32 + length]
        assert preimage
        assert element_tail[tail_start + 32 + length:tail_end] \
            == bytes(padded_length - length)
        preimages.append(preimage)
        expected_offset += 32 + padded_length
    result = (generation, campaign_id, tuple(preimages))
    assert calldata == encode_scan_legacy_genesis_proposals_calldata(*result)
    return result


def encode_scan_legacy_genesis_proposals_return(
        next_cursor: int, root: bytes, bytes_scanned: int,
        min_data_expiry: int) -> bytes:
    assert (0 <= next_cursor < 1 << 48 and root != bytes(32)
            and 0 <= bytes_scanned <= UINT32_MAX
            and 0 < min_data_expiry <= UINT64_MAX)
    encoded = (
        bytes4_word(LEGACY_GENESIS_SCAN_PROPOSALS_MAGIC)
        + u256(next_cursor) + b32(root) + u256(bytes_scanned)
        + u256(min_data_expiry))
    assert len(encoded) == 160
    return encoded


def decode_scan_legacy_genesis_proposals_return(
        returndata: bytes) -> tuple[int, bytes, int, int]:
    assert len(returndata) == 160
    assert bytes4_word_value(returndata[:32]) \
        == LEGACY_GENESIS_SCAN_PROPOSALS_MAGIC
    result = (
        uint_word_value(returndata[32:64], 48), b32(returndata[64:96]),
        uint_word_value(returndata[96:128], 32),
        uint_word_value(returndata[128:160], 64))
    assert returndata == encode_scan_legacy_genesis_proposals_return(*result)
    return result


def encode_scan_legacy_genesis_forced_calldata(
        generation: int, campaign_id: bytes, count: int) -> bytes:
    assert (0 < generation <= UINT64_MAX and campaign_id != bytes(32)
            and 1 <= count <= 16)
    encoded = (
        LEGACY_GENESIS_SCAN_FORCED_SELECTOR + u256(generation)
        + b32(campaign_id) + u256(count))
    assert len(encoded) == 100
    return encoded


def decode_scan_legacy_genesis_forced_calldata(
        calldata: bytes) -> tuple[int, bytes, int]:
    assert (len(calldata) == 100
            and calldata[:4] == LEGACY_GENESIS_SCAN_FORCED_SELECTOR)
    arguments = calldata[4:]
    result = (
        uint_word_value(arguments[0:32], 64), b32(arguments[32:64]),
        uint_word_value(arguments[64:96], 16))
    assert calldata == encode_scan_legacy_genesis_forced_calldata(*result)
    return result


def encode_scan_legacy_genesis_forced_return(
        next_cursor: int, root: bytes, bytes_scanned: int,
        abandoned_native_wei: int, min_data_expiry: int) -> bytes:
    assert (0 <= next_cursor < 1 << 48 and root != bytes(32)
            and 0 <= bytes_scanned <= UINT32_MAX
            and 0 <= abandoned_native_wei < 1 << 256
            and 0 < min_data_expiry <= UINT64_MAX)
    encoded = (
        bytes4_word(LEGACY_GENESIS_SCAN_FORCED_MAGIC)
        + u256(next_cursor) + b32(root) + u256(bytes_scanned)
        + u256(abandoned_native_wei) + u256(min_data_expiry))
    assert len(encoded) == 192
    return encoded


def decode_scan_legacy_genesis_forced_return(
        returndata: bytes) -> tuple[int, bytes, int, int, int]:
    assert len(returndata) == 192
    assert bytes4_word_value(returndata[:32]) \
        == LEGACY_GENESIS_SCAN_FORCED_MAGIC
    result = (
        uint_word_value(returndata[32:64], 48), b32(returndata[64:96]),
        uint_word_value(returndata[96:128], 32),
        uint_word_value(returndata[128:160]),
        uint_word_value(returndata[160:192], 64))
    assert returndata == encode_scan_legacy_genesis_forced_return(*result)
    return result


def encode_legacy_genesis_scan_state_return(
        generation: int, campaign_id: bytes,
        proposal_start: int, proposal_cursor: int, proposal_end: int,
        proposal_count: int, proposal_bytes: int, proposal_root: bytes,
        forced_start: int, forced_cursor: int, forced_end: int,
        forced_count: int, forced_bytes: int, forced_root: bytes,
        abandoned_native_wei: int, min_data_expiry: int,
        legacy_resume_profile_hash: bytes, scan_phase: int) -> bytes:
    assert scan_phase in (0, 1, 2)
    if scan_phase == 0:
        assert all(value == 0 or value == bytes(32) for value in (
            generation, campaign_id, proposal_start, proposal_cursor,
            proposal_end, proposal_count, proposal_bytes, proposal_root,
            forced_start, forced_cursor, forced_end, forced_count,
            forced_bytes, forced_root, abandoned_native_wei,
            min_data_expiry, legacy_resume_profile_hash))
    else:
        assert (0 < generation <= UINT64_MAX and campaign_id != bytes(32)
                and 0 <= proposal_start <= proposal_cursor
                    <= proposal_end < 1 << 48
                and proposal_count == proposal_cursor - proposal_start
                and 0 <= proposal_count < 1 << 16
                and 0 <= proposal_bytes <= UINT32_MAX
                and proposal_root != bytes(32)
                and 0 <= forced_start <= forced_cursor <= forced_end < 1 << 48
                and forced_count == forced_cursor - forced_start
                and 0 <= forced_count < 1 << 16
                and 0 <= forced_bytes <= UINT32_MAX
                and forced_root != bytes(32)
                and 0 <= abandoned_native_wei < 1 << 256
                and 0 < min_data_expiry <= UINT64_MAX
                and legacy_resume_profile_hash != bytes(32))
        if scan_phase == 1:
            assert (proposal_cursor < proposal_end
                    or forced_cursor < forced_end)
            if proposal_cursor < proposal_end:
                assert forced_cursor == forced_start
        if scan_phase == 2:
            assert (proposal_cursor == proposal_end
                    and forced_cursor == forced_end)
    encoded = (
        bytes4_word(LEGACY_GENESIS_SCAN_STATE_MAGIC) + u256(generation)
        + b32(campaign_id) + u256(proposal_start) + u256(proposal_cursor)
        + u256(proposal_end) + u256(proposal_count) + u256(proposal_bytes)
        + b32(proposal_root) + u256(forced_start) + u256(forced_cursor)
        + u256(forced_end) + u256(forced_count) + u256(forced_bytes)
        + b32(forced_root) + u256(abandoned_native_wei)
        + u256(min_data_expiry) + b32(legacy_resume_profile_hash)
        + u256(scan_phase))
    assert len(encoded) == 608
    return encoded


def decode_legacy_genesis_scan_state_return(
        returndata: bytes
) -> tuple[int, bytes, int, int, int, int, int, bytes, int, int, int, int,
           int, bytes, int, int, bytes, int]:
    assert len(returndata) == 608
    assert bytes4_word_value(returndata[:32]) == LEGACY_GENESIS_SCAN_STATE_MAGIC
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 19))
    result = (
        uint_word_value(words[0], 64), b32(words[1]),
        uint_word_value(words[2], 48), uint_word_value(words[3], 48),
        uint_word_value(words[4], 48), uint_word_value(words[5], 16),
        uint_word_value(words[6], 32), b32(words[7]),
        uint_word_value(words[8], 48), uint_word_value(words[9], 48),
        uint_word_value(words[10], 48), uint_word_value(words[11], 16),
        uint_word_value(words[12], 32), b32(words[13]),
        uint_word_value(words[14]), uint_word_value(words[15], 64),
        b32(words[16]), uint_word_value(words[17], 8))
    assert returndata == encode_legacy_genesis_scan_state_return(*result)
    return result


def encode_legacy_genesis_quiescence_return(
        generation: int, scan_commitment: bytes) -> bytes:
    assert (0 < generation <= UINT64_MAX and scan_commitment != bytes(32))
    encoded = (bytes4_word(LEGACY_GENESIS_QUIESCENCE_MAGIC)
               + u256(generation) + b32(scan_commitment))
    assert len(encoded) == 96
    return encoded


def decode_legacy_genesis_quiescence_return(
        returndata: bytes) -> tuple[int, bytes]:
    assert len(returndata) == 96
    assert bytes4_word_value(returndata[:32]) \
        == LEGACY_GENESIS_QUIESCENCE_MAGIC
    result = (uint_word_value(returndata[32:64], 64), b32(returndata[64:96]))
    assert returndata == encode_legacy_genesis_quiescence_return(*result)
    return result


def encode_legacy_genesis_resume_return(
        generation: int, campaign_id: bytes) -> bytes:
    assert 0 < generation <= UINT64_MAX and campaign_id != bytes(32)
    encoded = (bytes4_word(LEGACY_GENESIS_RESUME_MAGIC)
               + u256(generation) + b32(campaign_id))
    assert len(encoded) == 96
    return encoded


def decode_legacy_genesis_resume_return(
        returndata: bytes) -> tuple[int, bytes]:
    assert len(returndata) == 96
    assert bytes4_word_value(returndata[:32]) == LEGACY_GENESIS_RESUME_MAGIC
    result = (uint_word_value(returndata[32:64], 64), b32(returndata[64:96]))
    assert returndata == encode_legacy_genesis_resume_return(*result)
    return result


def encode_legacy_genesis_expire_return() -> bytes:
    return bytes4_word(LEGACY_GENESIS_EXPIRE_MAGIC)


def decode_legacy_genesis_expire_return(returndata: bytes) -> None:
    assert len(returndata) == 32
    assert bytes4_word_value(returndata) == LEGACY_GENESIS_EXPIRE_MAGIC
    assert returndata == encode_legacy_genesis_expire_return()


def legacy_genesis_rows_empty_root(kind: str) -> bytes:
    assert kind in ("proposal", "forced")
    domain = (D_LEGACY_GENESIS_PROPOSAL_ROWS_EMPTY
              if kind == "proposal" else D_LEGACY_GENESIS_FORCED_ROWS_EMPTY)
    return keccak256(domain)


def legacy_genesis_forced_record_hash(canonical_abi_encoding: bytes) -> bytes:
    assert canonical_abi_encoding
    return keccak256(
        b"slot-chain-legacy-genesis-forced-record-v1"
        + canonical_abi_encoding)


def append_legacy_genesis_row(
        kind: str, prior_root: bytes, index: int, encoded_bytes: int,
        row_hash: bytes,
        data_expiry: int, abandoned_native_wei: int) -> bytes:
    assert (kind in ("proposal", "forced") and prior_root != bytes(32)
            and 0 <= index < 1 << 48
            and 0 < encoded_bytes <= UINT32_MAX
            and row_hash != bytes(32)
            and 0 <= data_expiry <= UINT64_MAX
            and 0 <= abandoned_native_wei < 1 << 256)
    if kind == "proposal":
        assert abandoned_native_wei == 0
    domain = (D_LEGACY_GENESIS_PROPOSAL_ROW
              if kind == "proposal" else D_LEGACY_GENESIS_FORCED_ROW)
    return keccak256(
        domain + b32(prior_root) + u48(index) + u32(encoded_bytes)
        + b32(row_hash) + u64(data_expiry)
        + u256(abandoned_native_wei))


def legacy_genesis_rows_root(
        kind: str,
        rows: tuple[tuple[int, int, bytes, int, int], ...]
) -> tuple[bytes, int, int]:
    root = legacy_genesis_rows_empty_root(kind)
    total_bytes = 0
    total_abandoned_native_wei = 0
    previous_index: int | None = None
    for (index, encoded_bytes, row_hash, data_expiry,
         abandoned_native_wei) in rows:
        if previous_index is not None:
            assert index == previous_index + 1
        root = append_legacy_genesis_row(
            kind, root, index, encoded_bytes, row_hash, data_expiry,
            abandoned_native_wei)
        total_bytes += encoded_bytes
        total_abandoned_native_wei += abandoned_native_wei
        assert (total_bytes <= UINT32_MAX
                and total_abandoned_native_wei < 1 << 256)
        previous_index = index
    return root, total_bytes, total_abandoned_native_wei


def legacy_genesis_scan_commitment(scan: LegacyGenesisScanV1) -> bytes:
    assert (scan.campaign_id != bytes(32)
            and 0 <= scan.proposal_scan_start <= scan.next_proposal_id < 1 << 48
            and scan.proposal_count
                == scan.next_proposal_id - scan.proposal_scan_start
            and 0 <= scan.proposal_count < 1 << 16
            and 0 <= scan.proposal_bytes <= UINT32_MAX
            and scan.proposal_rows_root != bytes(32)
            and 0 <= scan.forced_head <= scan.forced_tail < 1 << 48
            and scan.forced_count == scan.forced_tail - scan.forced_head
            and 0 <= scan.forced_count < 1 << 16
            and 0 <= scan.forced_bytes <= UINT32_MAX
            and scan.forced_rows_root != bytes(32)
            and 0 <= scan.abandoned_native_wei < 1 << 256
            and 0 < scan.min_data_expiry <= UINT64_MAX
            and scan.legacy_resume_profile_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_SCAN + b32(scan.campaign_id)
        + u48(scan.proposal_scan_start) + u48(scan.next_proposal_id)
        + u16(scan.proposal_count) + u32(scan.proposal_bytes)
        + b32(scan.proposal_rows_root) + u48(scan.forced_head)
        + u48(scan.forced_tail) + u16(scan.forced_count)
        + u32(scan.forced_bytes) + b32(scan.forced_rows_root)
        + u256(scan.abandoned_native_wei)
        + u64(scan.min_data_expiry)
        + b32(scan.legacy_resume_profile_hash))


def validate_legacy_genesis_scan_resume_horizon(
        scan: LegacyGenesisScanV1, campaign: LegacyGenesisCampaignV1,
        reorg_margin_seconds: int, include_max_seconds: int) -> None:
    assert (scan.campaign_id == campaign.campaign_id
            and 0 <= reorg_margin_seconds <= UINT64_MAX
            and 0 <= include_max_seconds <= UINT64_MAX)
    required_expiry = (campaign.resume_by_timestamp + reorg_margin_seconds
                       + include_max_seconds)
    assert required_expiry <= UINT64_MAX
    assert scan.min_data_expiry >= required_expiry


def legacy_genesis_arm_id(
        deployment_hash: bytes, generation: int, campaign_id: bytes,
        scan_commitment: bytes, boundary_hash: bytes) -> bytes:
    assert (deployment_hash != bytes(32)
            and 0 < generation <= UINT64_MAX
            and campaign_id != bytes(32)
            and scan_commitment != bytes(32)
            and boundary_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_ARM + b32(deployment_hash) + u64(generation)
        + b32(campaign_id) + b32(scan_commitment) + b32(boundary_hash))


def legacy_genesis_boundary_hash(
        next_proposal_id: int, last_finalized_proposal_id: int,
        last_finalized_block_hash: bytes, forced_head: int,
        forced_tail: int) -> bytes:
    assert (0 <= last_finalized_proposal_id < 1 << 48
            and next_proposal_id > last_finalized_proposal_id
            and next_proposal_id < 1 << 48
            and last_finalized_block_hash != bytes(32)
            and 0 <= forced_head <= forced_tail < 1 << 48)
    return keccak256(
        D_LEGACY_GENESIS_BOUNDARY + u48(next_proposal_id)
        + u48(last_finalized_proposal_id) + b32(last_finalized_block_hash)
        + u48(forced_head) + u48(forced_tail))


def legacy_genesis_launch_id(
        arm_id: bytes, target_protocol_version: int,
        target_manifest_hash: bytes, target_registration_hash: bytes) -> bytes:
    assert (arm_id != bytes(32)
            and 0 < target_protocol_version <= UINT64_MAX
            and target_manifest_hash != bytes(32)
            and target_registration_hash != bytes(32))
    return keccak256(D_LEGACY_GENESIS_LAUNCH + b32(arm_id)
                     + u64(target_protocol_version)
                     + b32(target_manifest_hash)
                     + b32(target_registration_hash))


def legacy_genesis_post_state_commitment(
        launch_id: bytes, candidate_digest: bytes, output_core_hash: bytes,
        activated_at_block: int, boundary_hash: bytes) -> bytes:
    assert (launch_id != bytes(32) and candidate_digest != bytes(32)
            and output_core_hash != bytes(32)
            and 0 <= activated_at_block <= UINT64_MAX
            and boundary_hash != bytes(32))
    return keccak256(
        D_LEGACY_GENESIS_POSTSTATE + b32(launch_id) + b32(candidate_digest)
        + b32(output_core_hash) + u64(0) + u64(activated_at_block)
        + u8(4) + b32(boundary_hash))


def encode_legacy_genesis_control_calldata(
        selector: bytes, generation: int, campaign_id: bytes) -> bytes:
    assert selector in (
        LEGACY_GENESIS_BEGIN_SCAN_SELECTOR,
        LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR,
        LEGACY_GENESIS_RESUME_SELECTOR,
        LEGACY_GENESIS_EXPIRE_SELECTOR,
        LEGACY_GENESIS_ARM_SELECTOR,
    )
    assert 0 < generation <= UINT64_MAX and campaign_id != bytes(32)
    encoded = selector + u256(generation) + b32(campaign_id)
    assert len(encoded) == 68
    return encoded


def decode_legacy_genesis_control_calldata(
        calldata: bytes, selector: bytes) -> tuple[int, bytes]:
    assert selector in (
        LEGACY_GENESIS_BEGIN_SCAN_SELECTOR,
        LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR,
        LEGACY_GENESIS_RESUME_SELECTOR,
        LEGACY_GENESIS_EXPIRE_SELECTOR,
        LEGACY_GENESIS_ARM_SELECTOR,
    )
    assert len(calldata) == 68 and calldata[:4] == selector
    arguments = calldata[4:]
    result = (uint_word_value(arguments[:32], 64), b32(arguments[32:64]))
    assert calldata == encode_legacy_genesis_control_calldata(selector, *result)
    return result


def encode_legacy_genesis_control_return(
        magic: bytes, generation: int, campaign_id: bytes,
        arm_id: bytes) -> bytes:
    assert (magic == LEGACY_GENESIS_ARM_MAGIC
            and 0 < generation <= UINT64_MAX
            and campaign_id != bytes(32) and arm_id != bytes(32))
    encoded = (bytes4_word(magic) + u256(generation) + b32(campaign_id)
               + b32(arm_id))
    assert len(encoded) == 128
    return encoded


def decode_legacy_genesis_control_return(
        returndata: bytes, magic: bytes) -> tuple[int, bytes, bytes]:
    assert len(returndata) == 128
    assert bytes4_word_value(returndata[:32]) == magic
    result = (uint_word_value(returndata[32:64], 64),
              b32(returndata[64:96]), b32(returndata[96:128]))
    assert returndata == encode_legacy_genesis_control_return(magic, *result)
    return result


def encode_finalize_legacy_genesis_calldata(
        generation: int, target_protocol_version: int,
        target_manifest_hash: bytes, target_registration_hash: bytes,
        candidate_digest: bytes, output_core_hash: bytes) -> bytes:
    assert (0 < generation <= UINT64_MAX
            and 0 < target_protocol_version <= UINT64_MAX
            and target_manifest_hash != bytes(32)
            and target_registration_hash != bytes(32)
            and candidate_digest != bytes(32)
            and output_core_hash != bytes(32))
    encoded = (
        LEGACY_GENESIS_FINALIZE_SELECTOR + u256(generation)
        + u256(target_protocol_version) + b32(target_manifest_hash)
        + b32(target_registration_hash) + b32(candidate_digest)
        + b32(output_core_hash)
    )
    assert len(encoded) == 196
    return encoded


def decode_finalize_legacy_genesis_calldata(
        calldata: bytes) -> tuple[int, int, bytes, bytes, bytes, bytes]:
    assert (len(calldata) == 196
            and calldata[:4] == LEGACY_GENESIS_FINALIZE_SELECTOR)
    arguments = calldata[4:]
    result = (
        uint_word_value(arguments[0:32], 64),
        uint_word_value(arguments[32:64], 64), b32(arguments[64:96]),
        b32(arguments[96:128]), b32(arguments[128:160]),
        b32(arguments[160:192]),
    )
    assert calldata == encode_finalize_legacy_genesis_calldata(*result)
    return result


def encode_finalize_legacy_genesis_return(
        launch_id: bytes, post_state_commitment: bytes) -> bytes:
    assert launch_id != bytes(32) and post_state_commitment != bytes(32)
    return (bytes4_word(LEGACY_GENESIS_FINALIZE_MAGIC) + b32(launch_id)
            + b32(post_state_commitment))


def decode_finalize_legacy_genesis_return(
        returndata: bytes) -> tuple[bytes, bytes]:
    assert len(returndata) == 96
    assert bytes4_word_value(returndata[:32]) == LEGACY_GENESIS_FINALIZE_MAGIC
    result = (b32(returndata[32:64]), b32(returndata[64:96]))
    assert returndata == encode_finalize_legacy_genesis_return(*result)
    return result


def encode_legacy_genesis_state_return(
        phase: int, generation: int, campaign_id: bytes,
        scan_commitment: bytes, target_protocol_version: int,
        target_manifest_hash: bytes, target_registration_hash: bytes,
        arm_id: bytes, launch_id: bytes, next_proposal_id: int,
        last_finalized_proposal_id: int, last_finalized_block_hash: bytes,
        forced_head: int, forced_tail: int,
        post_state_commitment: bytes) -> bytes:
    assert (phase in (0, 2, 3, 4) and 0 <= generation <= UINT64_MAX
            and 0 <= target_protocol_version <= UINT64_MAX
            and 0 <= next_proposal_id < 1 << 48
            and 0 <= last_finalized_proposal_id < 1 << 48
            and 0 <= forced_head <= forced_tail < 1 << 48)
    if phase == 0:
        assert (generation == 0 and target_protocol_version == 0
                and campaign_id == bytes(32)
                and scan_commitment == bytes(32)
                and target_manifest_hash == bytes(32)
                and target_registration_hash == bytes(32)
                and arm_id == bytes(32) and launch_id == bytes(32)
                and post_state_commitment == bytes(32))
    if phase in (2, 3, 4):
        assert (generation > 0 and campaign_id != bytes(32)
                and scan_commitment != bytes(32)
                and next_proposal_id > last_finalized_proposal_id
                and last_finalized_block_hash != bytes(32))
    if phase in (2, 3):
        assert (target_protocol_version == 0
                and target_manifest_hash == bytes(32)
                and target_registration_hash == bytes(32)
                and launch_id == bytes(32)
                and post_state_commitment == bytes(32))
    if phase == 2:
        assert arm_id == bytes(32)
    if phase == 3:
        assert arm_id != bytes(32)
    if phase == 4:
        assert (target_protocol_version > 0
                and target_manifest_hash != bytes(32)
                and target_registration_hash != bytes(32)
                and launch_id != bytes(32)
                and post_state_commitment != bytes(32))
    return (
        bytes4_word(LEGACY_GENESIS_STATE_MAGIC) + u256(phase)
        + u256(generation) + b32(campaign_id) + b32(scan_commitment)
        + u256(target_protocol_version)
        + b32(target_manifest_hash) + b32(target_registration_hash)
        + b32(arm_id) + b32(launch_id) + u256(next_proposal_id)
        + u256(last_finalized_proposal_id) + b32(last_finalized_block_hash)
        + u256(forced_head) + u256(forced_tail)
        + b32(post_state_commitment)
    )


def decode_legacy_genesis_state_return(
        returndata: bytes
) -> tuple[int, int, bytes, bytes, int, bytes, bytes, bytes, bytes, int, int,
           bytes, int, int, bytes]:
    assert len(returndata) == 512
    assert bytes4_word_value(returndata[:32]) == LEGACY_GENESIS_STATE_MAGIC
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 16))
    result = (
        uint_word_value(words[0], 8), uint_word_value(words[1], 64),
        b32(words[2]), b32(words[3]), uint_word_value(words[4], 64),
        b32(words[5]), b32(words[6]), b32(words[7]), b32(words[8]),
        uint_word_value(words[9], 48), uint_word_value(words[10], 48),
        b32(words[11]), uint_word_value(words[12], 48),
        uint_word_value(words[13], 48), b32(words[14]),
    )
    assert returndata == encode_legacy_genesis_state_return(*result)
    return result


def validate_legacy_genesis_state_semantics(
        state: tuple[int, int, bytes, bytes, int, bytes, bytes, bytes, bytes,
                     int, int, bytes, int, int, bytes],
        legacy_deployment_hash: bytes,
        candidate_digest: bytes | None = None,
        output_core_hash: bytes | None = None,
        activated_at_block: int | None = None) -> None:
    (phase, generation, campaign_id, scan_commitment,
     target_protocol_version, target_manifest_hash,
     target_registration_hash, arm_id, launch_id, next_proposal_id,
     last_finalized_proposal_id, last_finalized_block_hash, forced_head,
     forced_tail, post_state_commitment) = state
    encode_legacy_genesis_state_return(*state)
    if phase == 0:
        assert (candidate_digest is None and output_core_hash is None
                and activated_at_block is None)
        return
    assert phase in (2, 3, 4)
    boundary_hash = legacy_genesis_boundary_hash(
        next_proposal_id, last_finalized_proposal_id,
        last_finalized_block_hash, forced_head, forced_tail)
    expected_arm_id = legacy_genesis_arm_id(
        legacy_deployment_hash, generation, campaign_id, scan_commitment,
        boundary_hash)
    if phase == 2:
        assert arm_id == bytes(32)
        assert (candidate_digest is None and output_core_hash is None
                and activated_at_block is None)
        return
    assert arm_id == expected_arm_id
    if phase == 3:
        assert (candidate_digest is None and output_core_hash is None
                and activated_at_block is None)
        return
    expected_launch_id = legacy_genesis_launch_id(
        expected_arm_id, target_protocol_version, target_manifest_hash,
        target_registration_hash)
    assert launch_id == expected_launch_id
    assert (candidate_digest is not None and output_core_hash is not None
            and activated_at_block is not None)
    assert post_state_commitment == legacy_genesis_post_state_commitment(
        launch_id, candidate_digest, output_core_hash, activated_at_block,
        boundary_hash)


def plus_one_cursor(block_number: int | None) -> int:
    if block_number is None:
        return 0
    assert 0 <= block_number < UINT64_MAX
    return block_number + 1


@dataclass(frozen=True)
class MigrationTransitionStatementV2:
    settlement_chain_id: int
    active_settlement_router: int
    router_runtime_hash: bytes
    router_configuration_hash: bytes
    transition_kind: int
    migration_generation: int
    source_protocol_version: int
    target_protocol_version: int
    source_canonical_sequence: int
    execution_profile_hash: bytes
    target_manifest_hash: bytes
    target_registration_hash: bytes
    candidate_digest: bytes
    base_canonical_hash: bytes
    output_canonical_hash: bytes
    forced_queue: int
    queue_runtime_hash: bytes
    queue_configuration_hash: bytes
    queue_root: bytes
    queue_count: int
    start_cursor: int
    end_cursor: int
    forced_descriptor_commitment: bytes
    proof_beneficiary: int
    anchor_number: int
    anchor_hash: bytes
    force_root: bytes
    force_cutoff: int
    source_domain_id: bytes
    source_registration_epoch: int
    source_bridge_execution_hash: bytes
    release_system_calldata_hash: bytes
    inbox_system_calldata_hash: bytes
    release_system_tx_hash: bytes
    inbox_system_tx_hash: bytes
    release_system_tx_position: int
    inbox_system_tx_position: int
    imported_header_hash: bytes
    imported_state_root: bytes
    legacy_signal_checkpoint_hash: bytes
    legacy_deployment_hash: bytes
    legacy_arm_id: bytes
    legacy_launch_id: bytes
    deployment_commitment: bytes
    pre_inbox_last_applied_plus_one: int
    post_inbox_last_applied_plus_one: int


def canonical_migration_transition_statement(
        statement: MigrationTransitionStatementV2) -> bytes:
    u64_values = (
        statement.migration_generation, statement.source_protocol_version,
        statement.target_protocol_version, statement.source_canonical_sequence,
        statement.queue_count, statement.start_cursor, statement.end_cursor,
        statement.force_cutoff, statement.source_registration_epoch,
        statement.pre_inbox_last_applied_plus_one,
        statement.post_inbox_last_applied_plus_one,
    )
    assert (statement.transition_kind in (1, 2)
            and all(0 <= value <= UINT64_MAX for value in u64_values)
            and statement.target_registration_hash != bytes(32)
            and statement.release_system_tx_position == 0
            and statement.inbox_system_tx_position == 1)
    imported = (
        statement.imported_header_hash, statement.imported_state_root,
        statement.legacy_signal_checkpoint_hash,
    )
    legacy_control = (
        statement.legacy_deployment_hash, statement.legacy_arm_id,
        statement.legacy_launch_id,
    )
    if statement.transition_kind == 1:
        assert (all(value != bytes(32) for value in imported)
                and all(value != bytes(32) for value in legacy_control)
                and statement.source_canonical_sequence == 0
                and statement.queue_count == 0
                and statement.start_cursor == 0
                and statement.end_cursor == 0
                and statement.force_cutoff == 0
                and statement.queue_root == statement.force_root
                and statement.forced_descriptor_commitment
                    == force_descriptor_list(0, (), None)
                and statement.source_domain_id == bytes(32)
                and statement.source_registration_epoch == 0
                and statement.source_bridge_execution_hash == bytes(32)
                and statement.pre_inbox_last_applied_plus_one == 0
                and statement.post_inbox_last_applied_plus_one == 0)
    else:
        assert (imported == (bytes(32), bytes(32), bytes(32))
                and legacy_control == (bytes(32), bytes(32), bytes(32)))
    encoded = (
        u256(statement.settlement_chain_id)
        + address_word(statement.active_settlement_router)
        + b32(statement.router_runtime_hash)
        + b32(statement.router_configuration_hash)
        + u256(statement.transition_kind)
        + u256(statement.migration_generation)
        + u256(statement.source_protocol_version)
        + u256(statement.target_protocol_version)
        + u256(statement.source_canonical_sequence)
        + b32(statement.execution_profile_hash)
        + b32(statement.target_manifest_hash)
        + b32(statement.target_registration_hash)
        + b32(statement.candidate_digest)
        + b32(statement.base_canonical_hash)
        + b32(statement.output_canonical_hash)
        + address_word(statement.forced_queue)
        + b32(statement.queue_runtime_hash)
        + b32(statement.queue_configuration_hash)
        + b32(statement.queue_root)
        + u256(statement.queue_count)
        + u256(statement.start_cursor)
        + u256(statement.end_cursor)
        + b32(statement.forced_descriptor_commitment)
        + address_word(statement.proof_beneficiary)
        + u256(statement.anchor_number)
        + b32(statement.anchor_hash)
        + b32(statement.force_root)
        + u256(statement.force_cutoff)
        + b32(statement.source_domain_id)
        + u256(statement.source_registration_epoch)
        + b32(statement.source_bridge_execution_hash)
        + b32(statement.release_system_calldata_hash)
        + b32(statement.inbox_system_calldata_hash)
        + b32(statement.release_system_tx_hash)
        + b32(statement.inbox_system_tx_hash)
        + u256(statement.release_system_tx_position)
        + u256(statement.inbox_system_tx_position)
        + b32(statement.imported_header_hash)
        + b32(statement.imported_state_root)
        + b32(statement.legacy_signal_checkpoint_hash)
        + b32(statement.legacy_deployment_hash)
        + b32(statement.legacy_arm_id)
        + b32(statement.legacy_launch_id)
        + b32(statement.deployment_commitment)
        + u256(statement.pre_inbox_last_applied_plus_one)
        + u256(statement.post_inbox_last_applied_plus_one)
    )
    assert len(encoded) == 46 * 32
    return encoded


def migration_transition_statement_hash(
        statement: MigrationTransitionStatementV2) -> bytes:
    return keccak256(MIGRATION_TRANSITION_STATEMENT_TYPEHASH
                     + canonical_migration_transition_statement(statement))


def genesis_import_checkpoint_valid(statement: MigrationTransitionStatementV2,
                                    imported_header_number: int | None) -> bool:
    if statement.transition_kind == 2:
        return (imported_header_number is None
                and statement.imported_header_hash == bytes(32)
                and statement.imported_state_root == bytes(32)
                and statement.legacy_signal_checkpoint_hash == bytes(32)
                and statement.legacy_deployment_hash == bytes(32)
                and statement.legacy_arm_id == bytes(32)
                and statement.legacy_launch_id == bytes(32))
    return (statement.transition_kind == 1 and imported_header_number is not None
            and statement.legacy_signal_checkpoint_hash
            == legacy_signal_checkpoint_hash(
                imported_header_number, statement.imported_header_hash,
                statement.imported_state_root))


@dataclass(frozen=True)
class RegistrationStorageStatementV2:
    settlement_chain_id: int
    active_settlement_router: int
    bridge_domain_registry: int
    route_key: bytes
    destination_chain_id: int
    protocol_version: int
    canonical_sequence: int
    state_root: bytes
    terminal_domain_registrar: int
    registrar_code_hash: bytes
    storage_trie_key: bytes
    expected_value: bytes


def registration_route_key(source_domain_id_: bytes, bridge_execution_hash_: bytes,
                           destination_domain_id_: bytes) -> bytes:
    return keccak256(REGISTRATION_ROUTE_KEY_TYPEHASH
                     + b32(source_domain_id_)
                     + b32(bridge_execution_hash_)
                     + b32(destination_domain_id_))


def canonical_registration_storage_statement(
        statement: RegistrationStorageStatementV2) -> bytes:
    assert (0 <= statement.protocol_version <= UINT64_MAX
            and 0 <= statement.canonical_sequence <= UINT64_MAX)
    encoded = (
        u256(statement.settlement_chain_id)
        + address_word(statement.active_settlement_router)
        + address_word(statement.bridge_domain_registry)
        + b32(statement.route_key)
        + u256(statement.destination_chain_id)
        + u256(statement.protocol_version)
        + u256(statement.canonical_sequence)
        + b32(statement.state_root)
        + address_word(statement.terminal_domain_registrar)
        + b32(statement.registrar_code_hash)
        + b32(statement.storage_trie_key)
        + b32(statement.expected_value)
    )
    assert len(encoded) == 12 * 32
    return encoded


def registration_storage_statement_hash(
        statement: RegistrationStorageStatementV2) -> bytes:
    return keccak256(REGISTRATION_STORAGE_STATEMENT_TYPEHASH
                     + canonical_registration_storage_statement(statement))


@dataclass(frozen=True)
class RegistrationMptVerifierDescriptorV2:
    verifier: int
    runtime_hash: bytes
    configuration_hash: bytes
    public_input_schema_hash: bytes
    proof_schema_hash: bytes
    selector: bytes
    maximum_nodes_per_path: int
    maximum_total_nodes: int
    maximum_node_bytes: int
    maximum_proof_bytes: int
    verification_gas_limit: int


def _registration_mpt_verifier_configuration_hash(
        descriptor: RegistrationMptVerifierDescriptorV2) -> bytes:
    assert (descriptor.verifier != 0
            and descriptor.runtime_hash != bytes(32)
            and descriptor.public_input_schema_hash
                == REGISTRATION_STORAGE_STATEMENT_TYPEHASH
            and descriptor.proof_schema_hash
                == REGISTRATION_MPT_PROOF_SCHEMA_HASH
            and descriptor.selector == VERIFY_REGISTRATION_SELECTOR
            and descriptor.maximum_nodes_per_path == 66
            and descriptor.maximum_total_nodes == 132
            and descriptor.maximum_node_bytes == 600
            and descriptor.maximum_proof_bytes == 80_000
            and descriptor.verification_gas_limit == 8_000_000)
    encoded = (
        REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH
        + b32(descriptor.public_input_schema_hash)
        + b32(descriptor.proof_schema_hash)
        + bytes4_word(descriptor.selector)
        + u256(descriptor.maximum_nodes_per_path)
        + u256(descriptor.maximum_total_nodes)
        + u256(descriptor.maximum_node_bytes)
        + u256(descriptor.maximum_proof_bytes)
        + u256(descriptor.verification_gas_limit)
    )
    assert len(encoded) == 9 * 32
    return keccak256(encoded)


def registration_mpt_verifier_configuration_hash(
        descriptor: RegistrationMptVerifierDescriptorV2) -> bytes:
    configuration_hash = _registration_mpt_verifier_configuration_hash(descriptor)
    assert descriptor.configuration_hash == configuration_hash
    return configuration_hash


def registration_mpt_verifier_descriptor_hash(
        descriptor: RegistrationMptVerifierDescriptorV2) -> bytes:
    configuration_hash = registration_mpt_verifier_configuration_hash(descriptor)
    encoded = (
        REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPEHASH
        + address_word(descriptor.verifier) + b32(descriptor.runtime_hash)
        + b32(descriptor.configuration_hash)
        + b32(descriptor.public_input_schema_hash)
        + b32(descriptor.proof_schema_hash)
        + bytes4_word(descriptor.selector)
        + u256(descriptor.maximum_nodes_per_path)
        + u256(descriptor.maximum_total_nodes)
        + u256(descriptor.maximum_node_bytes)
        + u256(descriptor.maximum_proof_bytes)
        + u256(descriptor.verification_gas_limit)
    )
    assert len(encoded) == 12 * 32
    return keccak256(encoded)


def encode_verify_registration_calldata(
        statement: RegistrationStorageStatementV2, proof: bytes) -> bytes:
    assert len(proof) <= 80_000
    encoded = (VERIFY_REGISTRATION_SELECTOR
               + canonical_registration_storage_statement(statement)
               + u256(13 * 32) + abi_bytes_tail(proof))
    assert len(encoded) == 452 + ceil32(len(proof))
    return encoded


def decode_verify_registration_calldata(
        calldata: bytes) -> tuple[RegistrationStorageStatementV2, bytes]:
    assert len(calldata) >= 452 and calldata[:4] == VERIFY_REGISTRATION_SELECTOR
    arguments = calldata[4:]
    assert uint_word_value(arguments[12 * 32:13 * 32]) == 13 * 32
    words = tuple(arguments[index * 32:(index + 1) * 32]
                  for index in range(12))
    statement = RegistrationStorageStatementV2(
        uint_word_value(words[0]), address_word_value(words[1]),
        address_word_value(words[2]), b32(words[3]), uint_word_value(words[4]),
        uint_word_value(words[5], 64), uint_word_value(words[6], 64),
        b32(words[7]), address_word_value(words[8]), b32(words[9]),
        b32(words[10]), b32(words[11]))
    proof_length = uint_word_value(arguments[13 * 32:14 * 32])
    assert proof_length <= 80_000
    proof_start = 14 * 32
    proof = arguments[proof_start:proof_start + proof_length]
    assert calldata == encode_verify_registration_calldata(statement, proof)
    return statement, proof


def decode_registration_verifier_return(returndata: bytes,
                                        expected_hash: bytes) -> bytes:
    assert len(returndata) == 32 and b32(returndata) == b32(expected_hash)
    return returndata


def decode_configuration_hash_return(returndata: bytes,
                                     expected_hash: bytes) -> bytes:
    assert len(returndata) == 32 and b32(returndata) == b32(expected_hash)
    return returndata


@dataclass(frozen=True)
class MessageV1:
    id: int
    fee: int
    gas_limit: int
    sender: int
    src_chain_id: int
    src_owner: int
    dest_chain_id: int
    dest_owner: int
    target: int
    value: int
    data: bytes


def canonical_message_v1(message: MessageV1) -> bytes:
    assert (0 <= message.id <= UINT64_MAX
            and 0 <= message.fee <= UINT64_MAX
            and 0 <= message.gas_limit <= UINT32_MAX
            and 0 <= message.src_chain_id <= UINT64_MAX
            and 0 <= message.dest_chain_id <= UINT64_MAX
            and 0 < message.value + message.fee < 1 << 256)
    encoded = (
        u256(message.id) + u256(message.fee) + u256(message.gas_limit)
        + address_word(message.sender) + u256(message.src_chain_id)
        + address_word(message.src_owner) + u256(message.dest_chain_id)
        + address_word(message.dest_owner) + address_word(message.target)
        + u256(message.value) + u256(11 * 32) + abi_bytes_tail(message.data)
    )
    assert len(encoded) == 12 * 32 + ceil32(len(message.data))
    return encoded


def decode_canonical_message_v1(encoded: bytes) -> MessageV1:
    assert len(encoded) >= 12 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(11))
    assert uint_word_value(words[10]) == 11 * 32
    data_length = uint_word_value(encoded[11 * 32:12 * 32])
    message = MessageV1(
        uint_word_value(words[0], 64), uint_word_value(words[1], 64),
        uint_word_value(words[2], 32), address_word_value(words[3]),
        uint_word_value(words[4], 64), address_word_value(words[5]),
        uint_word_value(words[6], 64), address_word_value(words[7]),
        address_word_value(words[8]), uint_word_value(words[9]),
        encoded[12 * 32:12 * 32 + data_length])
    assert encoded == canonical_message_v1(message)
    return message


def encode_message_v2_calldata(selector: bytes, message: MessageV1,
                               liquidity_fee: int) -> bytes:
    assert (selector in (SEND_MESSAGE_V2_SELECTOR,
                         ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR)
            and 0 < liquidity_fee <= UINT64_MAX)
    encoded = (selector + u256(2 * 32) + u256(liquidity_fee)
               + canonical_message_v1(message))
    assert len(encoded) == 452 + ceil32(len(message.data))
    return encoded


def decode_message_v2_calldata(
        calldata: bytes) -> tuple[bytes, MessageV1, int]:
    assert (len(calldata) >= 452
            and calldata[:4] in (SEND_MESSAGE_V2_SELECTOR,
                                 ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR))
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 2 * 32
    liquidity_fee = uint_word_value(arguments[32:64], 64)
    message = decode_canonical_message_v1(arguments[64:])
    assert calldata == encode_message_v2_calldata(
        calldata[:4], message, liquidity_fee)
    return calldata[:4], message, liquidity_fee


def normalized_message_hash_preimage(message: MessageV1) -> bytes:
    string_value = b"TAIKO_MESSAGE"
    encoded = (u256(2 * 32) + u256(4 * 32) + abi_bytes_tail(string_value)
               + canonical_message_v1(message))
    assert len(encoded) == 512 + ceil32(len(message.data))
    return encoded


def normalized_message_hash(message: MessageV1) -> bytes:
    return keccak256(normalized_message_hash_preimage(message))


def encode_send_message_v2_return(msg_hash: bytes, message: MessageV1) -> bytes:
    return b32(msg_hash) + u256(2 * 32) + canonical_message_v1(message)


def decode_send_message_v2_return(
        returndata: bytes) -> tuple[bytes, MessageV1]:
    assert len(returndata) >= 2 * 32
    msg_hash = b32(returndata[:32])
    assert uint_word_value(returndata[32:64]) == 2 * 32
    message = decode_canonical_message_v1(returndata[64:])
    assert returndata == encode_send_message_v2_return(msg_hash, message)
    return msg_hash, message


@dataclass(frozen=True)
class SourceContextV2:
    protocol_version: int
    kind: int
    credit_id: bytes
    msg_hash: bytes
    source_domain_id: bytes
    source_registration_epoch: int
    source_bridge: int
    source_bridge_execution_hash: bytes
    emitted_at_block: int
    queue_index: int


def source_context_abi(context: SourceContextV2) -> bytes:
    assert (0 < context.protocol_version <= UINT64_MAX
            and context.kind == 1
            and 0 <= context.source_registration_epoch <= UINT64_MAX
            and 0 <= context.emitted_at_block <= UINT64_MAX
            and 0 <= context.queue_index <= UINT64_MAX)
    encoded = (
        u256(context.protocol_version) + u256(context.kind)
        + b32(context.credit_id) + b32(context.msg_hash)
        + b32(context.source_domain_id)
        + u256(context.source_registration_epoch)
        + address_word(context.source_bridge)
        + b32(context.source_bridge_execution_hash)
        + u256(context.emitted_at_block) + u256(context.queue_index)
    )
    assert len(encoded) == 10 * 32
    return encoded


def decode_source_context_abi(encoded: bytes) -> SourceContextV2:
    assert len(encoded) == 10 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(10))
    context = SourceContextV2(
        uint_word_value(words[0], 64), uint_word_value(words[1], 8),
        b32(words[2]), b32(words[3]), b32(words[4]),
        uint_word_value(words[5], 64), address_word_value(words[6]),
        b32(words[7]), uint_word_value(words[8], 64),
        uint_word_value(words[9], 64))
    assert encoded == source_context_abi(context)
    return context


def source_context_hash(context: SourceContextV2) -> bytes:
    encoded = source_context_abi(context)
    return keccak256(SOURCE_CONTEXT_TYPEHASH + encoded)


@dataclass(frozen=True)
class DestinationContextV2:
    destination_chain_id: int
    destination_domain_id: bytes
    destination_bridge: int
    release_manifest_hash: bytes
    execution_profile_hash: bytes


def destination_context_abi(context: DestinationContextV2) -> bytes:
    encoded = (
        u256(context.destination_chain_id) + b32(context.destination_domain_id)
        + address_word(context.destination_bridge)
        + b32(context.release_manifest_hash)
        + b32(context.execution_profile_hash)
    )
    assert len(encoded) == 5 * 32
    return encoded


def decode_destination_context_abi(encoded: bytes) -> DestinationContextV2:
    assert len(encoded) == 5 * 32
    context = DestinationContextV2(
        uint_word_value(encoded[:32]), b32(encoded[32:64]),
        address_word_value(encoded[64:96]), b32(encoded[96:128]),
        b32(encoded[128:160]))
    assert encoded == destination_context_abi(context)
    return context


def destination_context_hash(context: DestinationContextV2) -> bytes:
    encoded = destination_context_abi(context)
    return keccak256(DESTINATION_CONTEXT_TYPEHASH + encoded)


@dataclass(frozen=True)
class InboxRowV2:
    queue_index: int
    disposition: int
    tx_index: int
    result_hash: bytes
    kind1_descriptor: bytes


def canonical_inbox_row(row: InboxRowV2) -> bytes:
    assert (0 <= row.queue_index <= UINT64_MAX
            and 0 <= row.disposition <= 5
            and 0 <= row.tx_index <= UINT32_MAX)
    if row.disposition == 5:
        assert len(row.kind1_descriptor) == 541
    else:
        assert row.kind1_descriptor == b""
    encoded = (
        u256(row.queue_index) + u256(row.disposition) + u256(row.tx_index)
        + b32(row.result_hash) + u256(5 * 32)
        + abi_bytes_tail(row.kind1_descriptor)
    )
    assert len(encoded) == 6 * 32 + ceil32(len(row.kind1_descriptor))
    return encoded


def canonical_inbox_rows_tail(rows: tuple[InboxRowV2, ...]) -> bytes:
    assert len(rows) <= 64
    elements = tuple(canonical_inbox_row(row) for row in rows)
    cursor = len(rows) * 32
    offsets = []
    for element in elements:
        offsets.append(u256(cursor))
        cursor += len(element)
    return u256(len(rows)) + b"".join(offsets) + b"".join(elements)


def decode_canonical_inbox_rows_tail(encoded: bytes) -> tuple[InboxRowV2, ...]:
    assert len(encoded) >= 32
    count = uint_word_value(encoded[:32])
    assert count <= 64 and len(encoded) >= 32 + count * 32
    element_base = 32
    expected_offset = count * 32
    rows = []
    for index in range(count):
        offset = uint_word_value(encoded[32 + index * 32:64 + index * 32])
        assert offset == expected_offset
        start = element_base + offset
        assert len(encoded) >= start + 6 * 32
        words = tuple(encoded[start + word_index * 32:
                              start + (word_index + 1) * 32]
                      for word_index in range(5))
        assert uint_word_value(words[4]) == 5 * 32
        descriptor_length = uint_word_value(
            encoded[start + 5 * 32:start + 6 * 32])
        end = start + 6 * 32 + ceil32(descriptor_length)
        assert end <= len(encoded)
        row = InboxRowV2(
            uint_word_value(words[0], 64), uint_word_value(words[1], 8),
            uint_word_value(words[2], 32), b32(words[3]),
            encoded[start + 6 * 32:start + 6 * 32 + descriptor_length])
        assert encoded[start:end] == canonical_inbox_row(row)
        rows.append(row)
        expected_offset += end - start
    result = tuple(rows)
    assert encoded == canonical_inbox_rows_tail(result)
    return result


def encode_inbox_apply_calldata(force_start: int,
                                rows: tuple[InboxRowV2, ...]) -> bytes:
    assert 0 <= force_start <= UINT64_MAX and len(rows) <= 64
    rows_tail = canonical_inbox_rows_tail(rows)
    encoded = (INBOX_APPLY_SELECTOR + u256(force_start) + u256(2 * 32)
               + rows_tail)
    assert len(encoded) == 68 + len(rows_tail)
    return encoded


def decode_inbox_apply_calldata(
        calldata: bytes) -> tuple[int, tuple[InboxRowV2, ...]]:
    assert len(calldata) >= 100 and calldata[:4] == INBOX_APPLY_SELECTOR
    arguments = calldata[4:]
    force_start = uint_word_value(arguments[:32], 64)
    assert uint_word_value(arguments[32:64]) == 2 * 32
    rows = decode_canonical_inbox_rows_tail(arguments[64:])
    assert calldata == encode_inbox_apply_calldata(force_start, rows)
    return force_start, rows


@dataclass(frozen=True)
class InboxCreditV2:
    queue_index: int
    src_chain_id: int
    source_domain_id: bytes
    src_epoch: int
    src_bridge: int
    destination_domain_id: bytes
    msg_hash: bytes
    result_hash: bytes
    source_context_hash: bytes
    value: int
    execution_fee: int
    liquidity_fee: int


def canonical_inbox_credit(row: InboxCreditV2) -> bytes:
    assert (0 <= row.queue_index <= UINT64_MAX
            and 0 <= row.src_chain_id <= UINT64_MAX
            and 0 <= row.src_epoch <= UINT64_MAX
            and 0 <= row.execution_fee <= UINT64_MAX
            and 0 <= row.liquidity_fee <= UINT64_MAX)
    encoded = (
        u256(row.queue_index) + u256(row.src_chain_id)
        + b32(row.source_domain_id) + u256(row.src_epoch)
        + address_word(row.src_bridge) + b32(row.destination_domain_id)
        + b32(row.msg_hash) + b32(row.result_hash)
        + b32(row.source_context_hash) + u256(row.value)
        + u256(row.execution_fee) + u256(row.liquidity_fee)
    )
    assert len(encoded) == 12 * 32
    return encoded


def encode_mark_inbox_batch_calldata(rows: tuple[InboxCreditV2, ...]) -> bytes:
    encoded = (MARK_INBOX_BATCH_SELECTOR + u256(32) + u256(len(rows))
               + b"".join(canonical_inbox_credit(row) for row in rows))
    assert len(encoded) == 68 + 12 * 32 * len(rows)
    return encoded


def decode_mark_inbox_batch_calldata(calldata: bytes) -> tuple[InboxCreditV2, ...]:
    assert len(calldata) >= 68 and calldata[:4] == MARK_INBOX_BATCH_SELECTOR
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 32
    count = uint_word_value(arguments[32:64])
    assert len(arguments) == 64 + count * 12 * 32
    rows = []
    for index in range(count):
        start = 64 + index * 12 * 32
        words = tuple(arguments[start + word_index * 32:
                                start + (word_index + 1) * 32]
                      for word_index in range(12))
        rows.append(InboxCreditV2(
            uint_word_value(words[0], 64), uint_word_value(words[1], 64),
            b32(words[2]), uint_word_value(words[3], 64),
            address_word_value(words[4]), b32(words[5]), b32(words[6]),
            b32(words[7]), b32(words[8]), uint_word_value(words[9]),
            uint_word_value(words[10], 64), uint_word_value(words[11], 64)))
    result = tuple(rows)
    assert calldata == encode_mark_inbox_batch_calldata(result)
    return result


def inbox_batch_magic_return() -> bytes:
    return bytes4_word(INBOX_BATCH_MAGIC)


def decode_inbox_batch_magic_return(returndata: bytes) -> bytes:
    assert bytes4_word_value(returndata) == INBOX_BATCH_MAGIC
    return INBOX_BATCH_MAGIC


def decode_liquidity_quote_return(
        returndata: bytes) -> tuple[bytes, int, int, int, int]:
    assert len(returndata) == 5 * 32
    result = (b32(returndata[:32]), uint_word_value(returndata[32:64]),
              uint_word_value(returndata[64:96], 64),
              uint_word_value(returndata[96:128], 64),
              uint_word_value(returndata[128:160], 64))
    assert result[0] != bytes(32)
    return result


def decode_liquidity_funding_state_return(
        returndata: bytes) -> tuple[bytes, int, int, int, int]:
    assert len(returndata) == 5 * 32
    result = (b32(returndata[:32]), address_word_value(returndata[32:64]),
              address_word_value(returndata[64:96]),
              uint_word_value(returndata[96:128], 8),
              uint_word_value(returndata[128:160], 64))
    status, terminal_index_plus_one = result[3], result[4]
    assert (result[0] != bytes(32) and result[1] != 0 and result[2] != 0
            and status <= 4)
    assert ((status in (0, 1) and terminal_index_plus_one == 0)
            or (status in (2, 3, 4) and terminal_index_plus_one > 0))
    return result


def encode_pool_word_calldata(selector: bytes, *words: bytes) -> bytes:
    assert len(selector) == 4 and all(len(word) == 32 for word in words)
    return selector + b"".join(words)


def decode_pool_word_calldata(
        calldata: bytes, selector: bytes, decoders: tuple) -> tuple:
    assert len(selector) == 4 and len(calldata) == 4 + 32 * len(decoders)
    assert calldata[:4] == selector
    return tuple(
        decoder(calldata[4 + index * 32:36 + index * 32])
        for index, decoder in enumerate(decoders)
    )


def decode_pool_ticket_accounting_return(
        returndata: bytes) -> tuple[int, int, int]:
    assert len(returndata) == 3 * 32
    result = (
        address_word_value(returndata[0:32]),
        address_word_value(returndata[32:64]),
        uint_word_value(returndata[64:96]),
    )
    assert (result == (0, 0, 0)
            or (result[0] != 0 and result[1] != 0 and result[2] > 0))
    return result


def decode_pool_accounting_return(
        returndata: bytes
) -> tuple[bytes, bool, bool, bytes, int, int, int]:
    assert len(returndata) == 8 * 32
    assert bytes4_word_value(returndata[0:32]) == POOL_ACCOUNTING_MAGIC
    configuration_hash = b32(returndata[32:64])
    active = uint_word_value(returndata[64:96], 8)
    entered = uint_word_value(returndata[96:128], 8)
    result = (
        configuration_hash, bool(active), bool(entered),
        b32(returndata[128:160]),
        uint_word_value(returndata[160:192]),
        uint_word_value(returndata[192:224]),
        uint_word_value(returndata[224:256]),
    )
    assert active <= 1 and entered <= 1 and configuration_hash != bytes(32)
    assert (bool(entered) == (result[3] != bytes(32))
            and result[5] >= result[4]
            and result[6] == result[5] - result[4])
    return result


def decode_pool_deposit_return(returndata: bytes) -> tuple[bytes, int]:
    assert len(returndata) == 64
    result = (b32(returndata[0:32]), uint_word_value(returndata[32:64]))
    assert result[0] != bytes(32) and result[1] > 0
    return result


def decode_pool_withdraw_return(returndata: bytes) -> int:
    assert len(returndata) == 32
    return uint_word_value(returndata)


def decode_pool_consume_return(returndata: bytes) -> tuple[bytes, int, int]:
    assert len(returndata) == 96
    result = (b32(returndata[0:32]),
              address_word_value(returndata[32:64]),
              uint_word_value(returndata[64:96]))
    assert result[0] != bytes(32) and result[1] != 0 and result[2] > 0
    return result


def decode_pool_value_magic_return(returndata: bytes) -> bytes:
    assert bytes4_word_value(returndata) == POOL_VALUE_MAGIC
    return POOL_VALUE_MAGIC


def decode_verify_inbox_credit_return(
        returndata: bytes) -> tuple[bytes, int, int, int, int, bytes]:
    assert len(returndata) == 6 * 32
    return (b32(returndata[:32]), uint_word_value(returndata[32:64], 64),
            uint_word_value(returndata[64:96]),
            uint_word_value(returndata[96:128], 64),
            uint_word_value(returndata[128:160], 64),
            b32(returndata[160:192]))


def encode_process_with_liquidity_calldata(
        ticket_id: bytes, destination_bridge: int, message: MessageV1,
        source_context: SourceContextV2,
        destination_context: DestinationContextV2) -> bytes:
    assert b32(ticket_id) != bytes(32) and 0 < destination_bridge < 1 << 160
    encoded = (
        PROCESS_WITH_LIQUIDITY_V2_SELECTOR + b32(ticket_id)
        + address_word(destination_bridge) + u256(18 * 32)
        + source_context_abi(source_context)
        + destination_context_abi(destination_context)
        + canonical_message_v1(message)
    )
    assert len(encoded) == 964 + ceil32(len(message.data))
    return encoded


def decode_process_with_liquidity_calldata(
        calldata: bytes
) -> tuple[bytes, int, MessageV1, SourceContextV2, DestinationContextV2]:
    assert (len(calldata) >= 964
            and calldata[:4] == PROCESS_WITH_LIQUIDITY_V2_SELECTOR)
    arguments = calldata[4:]
    ticket_id = b32(arguments[:32])
    destination_bridge = address_word_value(arguments[32:64])
    assert ticket_id != bytes(32) and destination_bridge != 0
    assert uint_word_value(arguments[64:96]) == 18 * 32
    source = decode_source_context_abi(arguments[3 * 32:13 * 32])
    destination = decode_destination_context_abi(arguments[13 * 32:18 * 32])
    message = decode_canonical_message_v1(arguments[18 * 32:])
    result = (ticket_id, destination_bridge, message, source, destination)
    assert calldata == encode_process_with_liquidity_calldata(*result)
    return result


def encode_retry_with_liquidity_calldata(
        ticket_id: bytes, destination_bridge: int, message: MessageV1,
        source_context: SourceContextV2,
        destination_context: DestinationContextV2,
        is_last_attempt: bool) -> bytes:
    assert b32(ticket_id) != bytes(32) and 0 < destination_bridge < 1 << 160
    encoded = (
        RETRY_WITH_LIQUIDITY_V2_SELECTOR + b32(ticket_id)
        + address_word(destination_bridge) + u256(19 * 32)
        + source_context_abi(source_context)
        + destination_context_abi(destination_context)
        + u256(1 if is_last_attempt else 0) + canonical_message_v1(message)
    )
    assert len(encoded) == 996 + ceil32(len(message.data))
    return encoded


def decode_retry_with_liquidity_calldata(
        calldata: bytes
) -> tuple[bytes, int, MessageV1, SourceContextV2,
           DestinationContextV2, bool]:
    assert (len(calldata) >= 996
            and calldata[:4] == RETRY_WITH_LIQUIDITY_V2_SELECTOR)
    arguments = calldata[4:]
    ticket_id = b32(arguments[:32])
    destination_bridge = address_word_value(arguments[32:64])
    assert ticket_id != bytes(32) and destination_bridge != 0
    assert uint_word_value(arguments[64:96]) == 19 * 32
    source = decode_source_context_abi(arguments[3 * 32:13 * 32])
    destination = decode_destination_context_abi(arguments[13 * 32:18 * 32])
    last = uint_word_value(arguments[18 * 32:19 * 32], 8)
    assert last in (0, 1)
    message = decode_canonical_message_v1(arguments[19 * 32:])
    result = (ticket_id, destination_bridge, message, source, destination,
              bool(last))
    assert calldata == encode_retry_with_liquidity_calldata(*result)
    return result


def encode_pool_bridge_attempt_calldata(
        ticket_id: bytes, depositor: int, message: MessageV1,
        source_context: SourceContextV2,
        destination_context: DestinationContextV2, operation: int,
        is_last_attempt: bool, authorization_hash: bytes) -> bytes:
    assert (b32(ticket_id) != bytes(32) and 0 < depositor < 1 << 160
            and operation in (1, 2)
            and (not is_last_attempt or operation == 2)
            and b32(authorization_hash) != bytes(32))
    encoded = (
        POOL_BRIDGE_ATTEMPT_SELECTOR + b32(ticket_id)
        + address_word(depositor) + u256(21 * 32)
        + source_context_abi(source_context)
        + destination_context_abi(destination_context) + u256(operation)
        + u256(1 if is_last_attempt else 0) + b32(authorization_hash)
        + canonical_message_v1(message)
    )
    assert len(encoded) == 1060 + ceil32(len(message.data))
    return encoded


def decode_pool_bridge_attempt_calldata(
        calldata: bytes
) -> tuple[bytes, int, MessageV1, SourceContextV2, DestinationContextV2,
           int, bool, bytes]:
    assert (len(calldata) >= 1060
            and calldata[:4] == POOL_BRIDGE_ATTEMPT_SELECTOR)
    arguments = calldata[4:]
    ticket_id = b32(arguments[:32])
    depositor = address_word_value(arguments[32:64])
    assert ticket_id != bytes(32) and depositor != 0
    assert uint_word_value(arguments[64:96]) == 21 * 32
    source = decode_source_context_abi(arguments[3 * 32:13 * 32])
    destination = decode_destination_context_abi(arguments[13 * 32:18 * 32])
    operation = uint_word_value(arguments[18 * 32:19 * 32], 8)
    last = uint_word_value(arguments[19 * 32:20 * 32], 8)
    assert operation in (1, 2) and last in (0, 1)
    assert last == 0 or operation == 2
    authorization_hash = b32(arguments[20 * 32:21 * 32])
    assert authorization_hash != bytes(32)
    message = decode_canonical_message_v1(arguments[21 * 32:])
    result = (ticket_id, depositor, message, source, destination, operation,
              bool(last), authorization_hash)
    assert calldata == encode_pool_bridge_attempt_calldata(*result)
    return result


def encode_execute_attempt_calldata(
        message: MessageV1, source_context: SourceContextV2,
        destination_context: DestinationContextV2, processor: int,
        expected_entry_status: int, is_last_attempt: bool,
        ticket_id: bytes, authorization_hash: bytes) -> bytes:
    assert 0 <= expected_entry_status < 1 << 8
    source_words = source_context_abi(source_context)
    destination_words = destination_context_abi(destination_context)
    encoded = (
        EXECUTE_ATTEMPT_SELECTOR + u256(21 * 32) + source_words
        + destination_words + address_word(processor)
        + u256(expected_entry_status) + u256(1 if is_last_attempt else 0)
        + b32(ticket_id) + b32(authorization_hash)
        + canonical_message_v1(message)
    )
    assert len(encoded) == 1060 + ceil32(len(message.data))
    return encoded


def decode_execute_attempt_calldata(
        calldata: bytes
) -> tuple[MessageV1, SourceContextV2, DestinationContextV2,
           int, int, bool, bytes, bytes]:
    assert len(calldata) >= 1060 and calldata[:4] == EXECUTE_ATTEMPT_SELECTOR
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 21 * 32
    source = decode_source_context_abi(arguments[32:11 * 32])
    destination = decode_destination_context_abi(arguments[11 * 32:16 * 32])
    processor = address_word_value(arguments[16 * 32:17 * 32])
    status = uint_word_value(arguments[17 * 32:18 * 32], 8)
    last = uint_word_value(arguments[18 * 32:19 * 32], 8)
    assert last in (0, 1)
    ticket_id = b32(arguments[19 * 32:20 * 32])
    authorization_hash = b32(arguments[20 * 32:21 * 32])
    assert ticket_id != bytes(32) and authorization_hash != bytes(32)
    message = decode_canonical_message_v1(arguments[21 * 32:])
    result = (message, source, destination, processor, status, bool(last),
              ticket_id, authorization_hash)
    assert calldata == encode_execute_attempt_calldata(*result)
    return result


def encode_status_return(resulting_status: int, status_reason: int) -> bytes:
    assert 0 <= resulting_status < 1 << 8 and 0 <= status_reason < 1 << 8
    return u256(resulting_status) + u256(status_reason)


def decode_status_return(returndata: bytes) -> tuple[int, int]:
    assert len(returndata) == 64
    return (uint_word_value(returndata[:32], 8),
            uint_word_value(returndata[32:], 8))


def encode_pool_bridge_result_return(
        credit_id: bytes, status: int, reason: int,
        terminal_index_plus_one: int, settlement_hash: bytes) -> bytes:
    assert (credit_id != bytes(32) and 0 <= reason < 1 << 8
            and 0 <= terminal_index_plus_one <= UINT64_MAX)
    if status in (0, 1):
        assert terminal_index_plus_one == 0 and settlement_hash == bytes(32)
    elif status == 2:
        assert terminal_index_plus_one > 0 and settlement_hash != bytes(32)
    elif status == 3:
        assert terminal_index_plus_one > 0 and settlement_hash == bytes(32)
    else:
        raise AssertionError("invalid Pool-Bridge result status")
    return (bytes4_word(POOL_BRIDGE_RESULT_MAGIC) + b32(credit_id)
            + u256(status) + u256(reason) + u256(terminal_index_plus_one)
            + b32(settlement_hash))


def decode_pool_bridge_result_return(
        returndata: bytes) -> tuple[bytes, int, int, int, bytes]:
    assert len(returndata) == 6 * 32
    assert bytes4_word_value(returndata[:32]) == POOL_BRIDGE_RESULT_MAGIC
    result = (
        b32(returndata[32:64]),
        uint_word_value(returndata[64:96], 8),
        uint_word_value(returndata[96:128], 8),
        uint_word_value(returndata[128:160], 64),
        b32(returndata[160:192]),
    )
    assert returndata == encode_pool_bridge_result_return(*result)
    return result


def target_call_failed_error(attempt_digest: bytes) -> bytes:
    return TARGET_CALL_FAILED_SELECTOR + b32(attempt_digest)


def decode_target_call_failed_error(returndata: bytes,
                                    expected_digest: bytes) -> bytes:
    assert len(returndata) == 36 and returndata[:4] == TARGET_CALL_FAILED_SELECTOR
    digest = b32(returndata[4:])
    assert digest == b32(expected_digest)
    return digest


def encode_terminal_commitment_return(destination_domain_id_: bytes,
                                      destination_bridge: int, terminal: int,
                                      terminal_index: int,
                                      settlement_hash: bytes) -> bytes:
    assert terminal in (1, 2) and terminal_index == UINT64_MAX
    if terminal == 1:
        assert settlement_hash != bytes(32)
    else:
        assert settlement_hash == bytes(32)
    return (b32(destination_domain_id_) + address_word(destination_bridge)
            + u256(terminal) + u256(terminal_index) + b32(settlement_hash))


def decode_terminal_commitment_return(
        returndata: bytes) -> tuple[bytes, int, int, int, bytes]:
    assert len(returndata) == 5 * 32
    result = (b32(returndata[:32]), address_word_value(returndata[32:64]),
              uint_word_value(returndata[64:96], 8),
              uint_word_value(returndata[96:128], 64),
              b32(returndata[128:160]))
    assert returndata == encode_terminal_commitment_return(*result)
    return result


def encode_terminal_state_return(count: int, root: bytes) -> bytes:
    assert 0 <= count <= UINT64_MAX
    return u256(count) + b32(root)


def decode_terminal_state_return(returndata: bytes) -> tuple[int, bytes]:
    assert len(returndata) == 64
    return uint_word_value(returndata[:32], 64), b32(returndata[32:])


def decode_terminal_append_return(returndata: bytes) -> int:
    assert len(returndata) == 32
    return uint_word_value(returndata, 64)


def liquidity_ticket_id(destination_chain_id: int, pool: int, depositor: int,
                        l1_recipient: int, salt: bytes) -> bytes:
    assert (destination_chain_id > 0 and pool != 0 and depositor != 0
            and l1_recipient != 0)
    ticket_id = keccak256(
        D_LIQUIDITY_TICKET + u256(destination_chain_id) + address20(pool)
        + address20(depositor) + address20(l1_recipient)
        + b32(salt))
    assert ticket_id != bytes(32)
    return ticket_id


def liquidity_attempt_authorization(
        destination_chain_id: int, destination_domain_id_: bytes, pool: int,
        destination_bridge: int, inbox_credit_store: int, credit_id: bytes,
        ticket_id: bytes, depositor: int, result_hash: bytes, amount: int,
        source_context_hash_: bytes, destination_context_hash_: bytes,
        operation: int, is_last_attempt: bool) -> bytes:
    assert (destination_chain_id > 0 and destination_domain_id_ != bytes(32)
            and pool != 0 and destination_bridge != 0
            and inbox_credit_store != 0 and credit_id != bytes(32)
            and ticket_id != bytes(32) and depositor != 0
            and result_hash != bytes(32) and amount > 0
            and source_context_hash_ != bytes(32)
            and destination_context_hash_ != bytes(32)
            and operation in (1, 2))
    return keccak256(
        D_LIQUIDITY_ATTEMPT + u256(destination_chain_id)
        + b32(destination_domain_id_) + address20(pool)
        + address20(destination_bridge) + address20(inbox_credit_store)
        + b32(credit_id) + b32(ticket_id) + address20(depositor)
        + b32(result_hash) + u256(amount) + b32(source_context_hash_)
        + b32(destination_context_hash_) + u8(operation)
        + u8(1 if is_last_attempt else 0))


def liquidity_acceptance_commitment(
        destination_chain_id: int, destination_domain_id_: bytes,
        destination_bridge: int, pool: int, credit_id: bytes,
        ticket_id: bytes, depositor: int, result_hash: bytes, amount: int,
        attempt_digest: bytes) -> bytes:
    """Bind the Bridge's one exact expected Pool value callback."""

    assert (destination_chain_id > 0 and destination_domain_id_ != bytes(32)
            and destination_bridge != 0 and pool != 0
            and credit_id != bytes(32) and ticket_id != bytes(32)
            and depositor != 0 and result_hash != bytes(32)
            and amount > 0 and attempt_digest != bytes(32))
    return keccak256(
        D_LIQUIDITY_ACCEPTANCE + u256(destination_chain_id)
        + b32(destination_domain_id_) + address20(destination_bridge)
        + address20(pool) + b32(credit_id) + b32(ticket_id)
        + address20(depositor) + b32(result_hash) + u256(amount)
        + b32(attempt_digest))


def invocation_policy_hash(denied: tuple[int, ...]) -> bytes:
    assert len(denied) <= 64
    assert denied == tuple(sorted(denied)) and len(set(denied)) == len(denied)
    addresses_hash = keccak256(b"".join(address20(target) for target in denied))
    return keccak256(
        INVOCATION_POLICY_TYPEHASH + u256(len(denied)) + addresses_hash
        + bytes4_word(MESSAGE_INVOCATION_HOOK_SELECTOR))


def encode_invocation_policy_return(policy_hash: bytes, denied: bool) -> bytes:
    return (b32(policy_hash) + u256(1 if denied else 0)
            + bytes4_word(INVOCATION_POLICY_MAGIC))


def decode_invocation_policy_return(returndata: bytes) -> tuple[bytes, bool]:
    assert len(returndata) == 96
    policy_hash = b32(returndata[:32])
    denied = uint_word_value(returndata[32:64], 8)
    assert denied in (0, 1)
    assert bytes4_word_value(returndata[64:96]) == INVOCATION_POLICY_MAGIC
    return policy_hash, bool(denied)


@dataclass(frozen=True)
class ProfileIngressAuthorizationV2:
    kind: int
    adapter: int
    adapter_runtime_hash: bytes
    adapter_configuration_hash: bytes
    active_settlement_router: int
    router_runtime_hash: bytes
    router_configuration_hash: bytes
    forced_queue: int
    queue_runtime_hash: bytes
    queue_configuration_hash: bytes
    source_domain_id: bytes
    source_registration_epoch: int
    source_bridge_execution_hash: bytes
    destination_chain_id: int
    destination_domain_id: bytes
    destination_bridge: int
    destination_bridge_execution_hash: bytes
    destination_infrastructure_hash: bytes
    fixed_ingress_wei: int
    execution_wei_per_accounted_gas: int
    proof_wei_per_accounted_gas: int
    permanent_wei_per_byte: int
    maximum_accepted_fee_wei: int


def canonical_profile_ingress_authorization_abi(
        row: ProfileIngressAuthorizationV2) -> bytes:
    source_fields = (
        row.source_domain_id, row.source_bridge_execution_hash,
    )
    destination_fields = (
        row.destination_domain_id, row.destination_bridge_execution_hash,
        row.destination_infrastructure_hash,
    )
    common_addresses = (
        row.adapter, row.active_settlement_router, row.forced_queue,
    )
    common_hashes = (
        row.adapter_runtime_hash, row.adapter_configuration_hash,
        row.router_runtime_hash, row.router_configuration_hash,
        row.queue_runtime_hash, row.queue_configuration_hash,
    )
    fees = (
        row.fixed_ingress_wei, row.execution_wei_per_accounted_gas,
        row.proof_wei_per_accounted_gas, row.permanent_wei_per_byte,
        row.maximum_accepted_fee_wei,
    )
    assert (row.kind in (0, 1)
            and all(address != 0 for address in common_addresses)
            and all(value != bytes(32) for value in common_hashes)
            and 0 <= row.source_registration_epoch <= UINT64_MAX
            and row.destination_chain_id > 0
            and all(fee > 0 for fee in fees))
    if row.kind == 0:
        assert (source_fields == (bytes(32), bytes(32))
                and row.source_registration_epoch == 0
                and destination_fields == (bytes(32), bytes(32), bytes(32))
                and row.destination_bridge == 0)
    else:
        assert (all(value != bytes(32) for value in source_fields)
                and row.source_registration_epoch > 0
                and all(value != bytes(32) for value in destination_fields)
                and row.destination_bridge != 0)
    encoded = (
        u256(row.kind) + address_word(row.adapter)
        + b32(row.adapter_runtime_hash) + b32(row.adapter_configuration_hash)
        + address_word(row.active_settlement_router)
        + b32(row.router_runtime_hash) + b32(row.router_configuration_hash)
        + address_word(row.forced_queue) + b32(row.queue_runtime_hash)
        + b32(row.queue_configuration_hash) + b32(row.source_domain_id)
        + u256(row.source_registration_epoch)
        + b32(row.source_bridge_execution_hash)
        + u256(row.destination_chain_id) + b32(row.destination_domain_id)
        + address_word(row.destination_bridge)
        + b32(row.destination_bridge_execution_hash)
        + b32(row.destination_infrastructure_hash)
        + u256(row.fixed_ingress_wei)
        + u256(row.execution_wei_per_accounted_gas)
        + u256(row.proof_wei_per_accounted_gas)
        + u256(row.permanent_wei_per_byte)
        + u256(row.maximum_accepted_fee_wei)
    )
    assert len(encoded) == 23 * 32
    return encoded


def ingress_authorization_id(row: ProfileIngressAuthorizationV2) -> bytes:
    return keccak256(
        INGRESS_AUTHORIZATION_TYPEHASH
        + canonical_profile_ingress_authorization_abi(row))


def decode_canonical_profile_ingress_authorization_abi(
        encoded: bytes) -> ProfileIngressAuthorizationV2:
    assert len(encoded) == 23 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(23))
    row = ProfileIngressAuthorizationV2(
        uint_word_value(words[0], 8), address_word_value(words[1]),
        b32(words[2]), b32(words[3]), address_word_value(words[4]),
        b32(words[5]), b32(words[6]), address_word_value(words[7]),
        b32(words[8]), b32(words[9]), b32(words[10]),
        uint_word_value(words[11], 64), b32(words[12]),
        uint_word_value(words[13]), b32(words[14]),
        address_word_value(words[15]), b32(words[16]), b32(words[17]),
        *(uint_word_value(words[index]) for index in range(18, 23)))
    assert encoded == canonical_profile_ingress_authorization_abi(row)
    return row


def encode_profile_ingress_root_calldata(protocol_version: int) -> bytes:
    assert 0 < protocol_version <= UINT64_MAX
    return PROFILE_INGRESS_ROOT_SELECTOR + u256(protocol_version)


def decode_profile_ingress_root_calldata(calldata: bytes) -> int:
    assert (len(calldata) == 36 and calldata[:4] == PROFILE_INGRESS_ROOT_SELECTOR)
    protocol_version = uint_word_value(calldata[4:36], 64)
    assert calldata == encode_profile_ingress_root_calldata(protocol_version)
    return protocol_version


def encode_profile_ingress_root_return(
        protocol_version: int, count: int, root: bytes) -> bytes:
    assert (0 < protocol_version <= UINT64_MAX and count == 2
            and root != bytes(32))
    encoded = (bytes4_word(PROFILE_INGRESS_ROOT_MAGIC)
               + u256(protocol_version) + u256(count) + b32(root))
    assert len(encoded) == 128
    return encoded


def decode_profile_ingress_root_return(
        returndata: bytes) -> tuple[int, int, bytes]:
    assert (len(returndata) == 128
            and bytes4_word_value(returndata[:32])
                == PROFILE_INGRESS_ROOT_MAGIC)
    result = (uint_word_value(returndata[32:64], 64),
              uint_word_value(returndata[64:96], 16),
              b32(returndata[96:128]))
    assert returndata == encode_profile_ingress_root_return(*result)
    return result


def encode_profile_ingress_authorization_calldata(
        authorization_id: bytes) -> bytes:
    assert authorization_id != bytes(32)
    return PROFILE_INGRESS_AUTHORIZATION_SELECTOR + b32(authorization_id)


def decode_profile_ingress_authorization_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == PROFILE_INGRESS_AUTHORIZATION_SELECTOR)
    authorization_id = b32(calldata[4:36])
    assert calldata == encode_profile_ingress_authorization_calldata(
        authorization_id)
    return authorization_id


def encode_profile_ingress_authorization_return(
        row: ProfileIngressAuthorizationV2) -> bytes:
    authorization_id = ingress_authorization_id(row)
    encoded = (bytes4_word(PROFILE_INGRESS_AUTHORIZATION_MAGIC)
               + b32(authorization_id)
               + canonical_profile_ingress_authorization_abi(row))
    assert len(encoded) == 800
    return encoded


def decode_profile_ingress_authorization_return(
        returndata: bytes) -> tuple[bytes, ProfileIngressAuthorizationV2]:
    assert (len(returndata) == 800
            and bytes4_word_value(returndata[:32])
                == PROFILE_INGRESS_AUTHORIZATION_MAGIC)
    authorization_id = b32(returndata[32:64])
    row = decode_canonical_profile_ingress_authorization_abi(returndata[64:])
    assert authorization_id == ingress_authorization_id(row)
    assert returndata == encode_profile_ingress_authorization_return(row)
    return authorization_id, row


def validate_release_registration_postreads(
        payload: RegisterReleasePayloadV1,
        target_row: TargetReleaseRegistrationV2,
        activation_profile: MigrationActivationProfileRecordV2,
        expected_data_session_configuration_hash: bytes,
        ingress_rows: tuple[ProfileIngressAuthorizationV2, ...],
        market_authorization: SettlementAuthorizationV1,
        returned_manifest_hash: bytes,
        returned_target_registration_hash: bytes) -> bytes:
    manifest = payload.release_manifest
    deployment = payload.settlement_deployment_descriptor
    manifest_hash = release_manifest_hash(manifest)
    activation_profile_hash = migration_activation_profile_record_hash(
        activation_profile)
    target_registration_hash = target_registration_v2_hash(
        payload.expected_predecessor_protocol_version, manifest, deployment,
        activation_profile_hash)
    verifier_descriptor = MigrationVerifierDescriptor(
        activation_profile.verifier, activation_profile.verifier_runtime_hash,
        activation_profile.verifier_configuration_hash,
        activation_profile.verifying_key_hash,
        activation_profile.proof_system_id,
        activation_profile.public_input_schema_hash,
        activation_profile.verifier_selector,
        activation_profile.maximum_proof_bytes,
        activation_profile.verification_gas_limit)
    assert (activation_profile.activation_profile_record_hash
                == activation_profile_hash
            and activation_profile.protocol_version == manifest.protocol_version
            and activation_profile.execution_profile_hash
                == manifest.execution_profile_hash
            and migration_verifier_descriptor_hash(verifier_descriptor)
                == manifest.migration_verifier_descriptor_hash
            and target_row == TargetReleaseRegistrationV2(
                manifest.protocol_version,
                payload.expected_predecessor_protocol_version,
                deployment.target_settlement, deployment.target_runtime_hash,
                deployment.target_configuration_hash,
                settlement_deployment_descriptor_hash(deployment),
                manifest.execution_profile_hash, activation_profile_hash,
                expected_data_session_configuration_hash,
                manifest_hash, target_registration_hash)
            and ingress_authorization_root(ingress_rows)
                == manifest.ingress_authorization_root
            and market_authorization == SettlementAuthorizationV1(
                manifest.protocol_version, deployment.target_settlement,
                deployment.target_runtime_hash,
                deployment.target_configuration_hash,
                SEAT_TARGET_EXPECTED_MAGIC, target_registration_hash)
            and returned_manifest_hash == manifest_hash
            and returned_target_registration_hash
                == target_registration_hash)
    return target_registration_hash


def ingress_authorization_root(
        rows: tuple[ProfileIngressAuthorizationV2, ...]) -> bytes:
    assert len(rows) == 2
    ids = tuple(ingress_authorization_id(row) for row in rows)
    assert len(set(ids)) == len(ids)
    assert len({row.adapter for row in rows}) == len(rows)
    assert tuple(sorted(row.kind for row in rows)) == (0, 1)
    sorted_ids = tuple(sorted(ids))
    ids_hash = keccak256(b"".join(sorted_ids))
    return keccak256(INGRESS_AUTHORIZATION_ROOT_TYPEHASH
                     + u256(len(sorted_ids)) + ids_hash)


@dataclass(frozen=True)
class IngressProfileGraphV2:
    active_settlement_router: int
    router_runtime_hash: bytes
    router_configuration_hash: bytes
    forced_queue: int
    queue_runtime_hash: bytes
    queue_configuration_hash: bytes
    source_domain_id: bytes
    source_registration_epoch: int
    source_bridge_execution_hash: bytes
    destination_chain_id: int
    destination_domain_id: bytes
    destination_bridge: int
    destination_bridge_execution_hash: bytes
    destination_infrastructure_hash: bytes
    kind0_adapter: int
    kind0_adapter_runtime_hash: bytes
    kind0_adapter_configuration_hash: bytes
    kind1_adapter: int
    kind1_adapter_runtime_hash: bytes
    kind1_adapter_configuration_hash: bytes


def validate_ingress_authorization_set(
        rows: tuple[ProfileIngressAuthorizationV2, ...],
        graph: IngressProfileGraphV2) -> bytes:
    assert len(rows) == 2 and tuple(sorted(row.kind for row in rows)) == (0, 1)
    fee_schedules = {
        (row.fixed_ingress_wei, row.execution_wei_per_accounted_gas,
         row.proof_wei_per_accounted_gas, row.permanent_wei_per_byte,
         row.maximum_accepted_fee_wei)
        for row in rows
    }
    assert len(fee_schedules) == 1
    common = (
        graph.active_settlement_router, graph.router_runtime_hash,
        graph.router_configuration_hash, graph.forced_queue,
        graph.queue_runtime_hash, graph.queue_configuration_hash,
        graph.destination_chain_id,
    )
    for row in rows:
        assert (
            (row.active_settlement_router, row.router_runtime_hash,
             row.router_configuration_hash, row.forced_queue,
             row.queue_runtime_hash, row.queue_configuration_hash,
             row.destination_chain_id) == common)
    kind0 = next(row for row in rows if row.kind == 0)
    kind1 = next(row for row in rows if row.kind == 1)
    assert (
        (kind0.source_domain_id, kind0.source_registration_epoch,
         kind0.source_bridge_execution_hash, kind0.destination_domain_id,
         kind0.destination_bridge, kind0.destination_bridge_execution_hash,
         kind0.destination_infrastructure_hash)
        == (bytes(32), 0, bytes(32), bytes(32), 0, bytes(32), bytes(32)))
    assert (
        (kind0.adapter, kind0.adapter_runtime_hash,
         kind0.adapter_configuration_hash)
        == (graph.kind0_adapter, graph.kind0_adapter_runtime_hash,
            graph.kind0_adapter_configuration_hash))
    assert (
        (kind1.source_domain_id, kind1.source_registration_epoch,
         kind1.source_bridge_execution_hash, kind1.destination_domain_id,
         kind1.destination_bridge, kind1.destination_bridge_execution_hash,
         kind1.destination_infrastructure_hash)
        == (graph.source_domain_id, graph.source_registration_epoch,
            graph.source_bridge_execution_hash, graph.destination_domain_id,
            graph.destination_bridge, graph.destination_bridge_execution_hash,
            graph.destination_infrastructure_hash))
    assert (
        (kind1.adapter, kind1.adapter_runtime_hash,
         kind1.adapter_configuration_hash)
        == (graph.kind1_adapter, graph.kind1_adapter_runtime_hash,
            graph.kind1_adapter_configuration_hash))
    fees = next(iter(fee_schedules))
    fixed_fee, execution_rate, proof_rate, byte_rate, cap = fees
    maximum_cost = fixed_fee + 5_000_000 * (execution_rate + proof_rate) \
        + 131_072 * byte_rate
    assert (all(value > 0 for value in fees)
            and maximum_cost <= cap
            and UINT64_MAX * cap < 1 << 256)
    return ingress_authorization_root(rows)


@dataclass(frozen=True)
class DestinationActivationReceiptV2:
    destination_chain_id: int
    terminal_domain_registrar: int
    successor_index: int
    old_protocol_version: int
    new_protocol_version: int
    old_manifest_hash: bytes
    new_manifest_hash: bytes
    old_destination_domain_id: bytes
    new_destination_domain_id: bytes
    old_destination_bridge: int
    new_destination_bridge: int
    retirement_queue_count: int
    activated_at_block: int


def destination_activation_receipt_id(
        receipt: DestinationActivationReceiptV2) -> bytes:
    narrow = (
        receipt.successor_index, receipt.old_protocol_version,
        receipt.new_protocol_version, receipt.retirement_queue_count,
        receipt.activated_at_block,
    )
    assert all(0 <= value <= UINT64_MAX for value in narrow)
    return keccak256(
        D_DESTINATION_ACTIVATION_RECEIPT
        + u256(receipt.destination_chain_id)
        + address20(receipt.terminal_domain_registrar)
        + u64(receipt.successor_index) + u64(receipt.old_protocol_version)
        + u64(receipt.new_protocol_version) + b32(receipt.old_manifest_hash)
        + b32(receipt.new_manifest_hash)
        + b32(receipt.old_destination_domain_id)
        + b32(receipt.new_destination_domain_id)
        + address20(receipt.old_destination_bridge)
        + address20(receipt.new_destination_bridge)
        + u64(receipt.retirement_queue_count)
        + u64(receipt.activated_at_block))


@dataclass(frozen=True)
class ActivationReceiptV1:
    settlement_chain_id: int
    router: int
    router_generation: int
    successor_index: int
    transition_kind: int
    source_protocol_version: int
    target_protocol_version: int
    source_manifest_hash: bytes
    target_manifest_hash: bytes
    source_authorization_id: bytes
    target_authorization_id: bytes
    target_registration_hash: bytes
    source_settlement: int
    target_settlement: int
    old_destination_domain_id: bytes
    new_destination_domain_id: bytes
    old_destination_bridge: int
    new_destination_bridge: int
    queue_watermark: int
    candidate_digest: bytes
    output_canonical_hash: bytes
    output_canonical_sequence: int
    activation_context_hash: bytes
    transition_auxiliary_hash: bytes
    source_post_state_commitment: bytes
    adoption_commitment: bytes
    queue_post_state_commitment: bytes
    activated_at_block: int


def activation_receipt_id(receipt: ActivationReceiptV1) -> bytes:
    narrow = (
        receipt.router_generation, receipt.successor_index,
        receipt.source_protocol_version, receipt.target_protocol_version,
        receipt.queue_watermark, receipt.output_canonical_sequence,
        receipt.activated_at_block,
    )
    assert (receipt.transition_kind in (1, 2)
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and receipt.router != 0 and receipt.source_settlement != 0
            and receipt.target_settlement != 0
            and receipt.source_manifest_hash != bytes(32)
            and receipt.target_manifest_hash != bytes(32)
            and receipt.target_authorization_id != bytes(32)
            and receipt.target_registration_hash != bytes(32)
            and receipt.candidate_digest != bytes(32)
            and receipt.output_canonical_hash != bytes(32)
            and receipt.activation_context_hash != bytes(32)
            and receipt.source_post_state_commitment != bytes(32)
            and receipt.adoption_commitment != bytes(32)
            and receipt.queue_post_state_commitment != bytes(32))
    if receipt.transition_kind == 1:
        assert (receipt.source_authorization_id == bytes(32)
                and receipt.old_destination_domain_id == bytes(32)
                and receipt.old_destination_bridge == 0
                and receipt.queue_watermark == 0
                and receipt.output_canonical_sequence == 0
                and receipt.transition_auxiliary_hash != bytes(32))
    else:
        assert (receipt.source_authorization_id != bytes(32)
                and receipt.old_destination_domain_id != bytes(32)
                and receipt.old_destination_bridge != 0
                and receipt.queue_watermark > 0
                and receipt.output_canonical_sequence > 0
                and receipt.transition_auxiliary_hash == bytes(32))
    return keccak256(
        D_ACTIVATION_RECEIPT + u256(receipt.settlement_chain_id)
        + address20(receipt.router) + u64(receipt.router_generation)
        + u64(receipt.successor_index) + u8(receipt.transition_kind)
        + u64(receipt.source_protocol_version)
        + u64(receipt.target_protocol_version)
        + b32(receipt.source_manifest_hash) + b32(receipt.target_manifest_hash)
        + b32(receipt.source_authorization_id)
        + b32(receipt.target_authorization_id)
        + b32(receipt.target_registration_hash)
        + address20(receipt.source_settlement)
        + address20(receipt.target_settlement)
        + b32(receipt.old_destination_domain_id)
        + b32(receipt.new_destination_domain_id)
        + address20(receipt.old_destination_bridge)
        + address20(receipt.new_destination_bridge)
        + u64(receipt.queue_watermark) + b32(receipt.candidate_digest)
        + b32(receipt.output_canonical_hash)
        + u64(receipt.output_canonical_sequence)
        + b32(receipt.activation_context_hash)
        + b32(receipt.transition_auxiliary_hash)
        + b32(receipt.source_post_state_commitment)
        + b32(receipt.adoption_commitment)
        + b32(receipt.queue_post_state_commitment)
        + u64(receipt.activated_at_block))


def encode_activation_receipt_calldata(receipt_id: bytes) -> bytes:
    assert receipt_id != bytes(32)
    encoded = ACTIVATION_RECEIPT_SELECTOR + b32(receipt_id)
    assert len(encoded) == 36
    return encoded


def decode_activation_receipt_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == ACTIVATION_RECEIPT_SELECTOR)
    receipt_id = b32(calldata[4:36])
    assert calldata == encode_activation_receipt_calldata(receipt_id)
    return receipt_id


def encode_activation_receipt_return(receipt: ActivationReceiptV1) -> bytes:
    receipt_id = activation_receipt_id(receipt)
    encoded = (
        bytes4_word(ACTIVATION_RECEIPT_MAGIC) + b32(receipt_id)
        + u256(receipt.settlement_chain_id) + address_word(receipt.router)
        + u256(receipt.router_generation) + u256(receipt.successor_index)
        + u256(receipt.transition_kind)
        + u256(receipt.source_protocol_version)
        + u256(receipt.target_protocol_version)
        + b32(receipt.source_manifest_hash) + b32(receipt.target_manifest_hash)
        + b32(receipt.source_authorization_id)
        + b32(receipt.target_authorization_id)
        + b32(receipt.target_registration_hash)
        + address_word(receipt.source_settlement)
        + address_word(receipt.target_settlement)
        + b32(receipt.old_destination_domain_id)
        + b32(receipt.new_destination_domain_id)
        + address_word(receipt.old_destination_bridge)
        + address_word(receipt.new_destination_bridge)
        + u256(receipt.queue_watermark) + b32(receipt.candidate_digest)
        + b32(receipt.output_canonical_hash)
        + u256(receipt.output_canonical_sequence)
        + b32(receipt.activation_context_hash)
        + b32(receipt.transition_auxiliary_hash)
        + b32(receipt.source_post_state_commitment)
        + b32(receipt.adoption_commitment)
        + b32(receipt.queue_post_state_commitment)
        + u256(receipt.activated_at_block) + u256(1))
    assert len(encoded) == 992
    return encoded


def decode_activation_receipt_return(
        returndata: bytes) -> tuple[bytes, ActivationReceiptV1]:
    assert len(returndata) == 992
    assert bytes4_word_value(returndata[:32]) == ACTIVATION_RECEIPT_MAGIC
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 31))
    returned_receipt_id = b32(words[0])
    receipt = ActivationReceiptV1(
        uint_word_value(words[1]), address_word_value(words[2]),
        uint_word_value(words[3], 64), uint_word_value(words[4], 64),
        uint_word_value(words[5], 8), uint_word_value(words[6], 64),
        uint_word_value(words[7], 64), b32(words[8]), b32(words[9]),
        b32(words[10]), b32(words[11]), b32(words[12]),
        address_word_value(words[13]), address_word_value(words[14]),
        b32(words[15]), b32(words[16]), address_word_value(words[17]),
        address_word_value(words[18]), uint_word_value(words[19], 64),
        b32(words[20]), b32(words[21]), uint_word_value(words[22], 64),
        b32(words[23]), b32(words[24]), b32(words[25]), b32(words[26]),
        b32(words[27]), uint_word_value(words[28], 64))
    assert uint_word_value(words[29], 8) == 1
    assert returned_receipt_id == activation_receipt_id(receipt)
    assert returndata == encode_activation_receipt_return(receipt)
    return returned_receipt_id, receipt


@dataclass(frozen=True)
class ReleaseManifestDescriptor:
    protocol_version: int
    settlement_chain_id: int
    destination_chain_id: int
    destination_genesis_hash: bytes
    execution_profile_hash: bytes
    manifest_namespace: bytes
    destination_namespace: bytes
    anchor: int
    anchor_runtime_hash: bytes
    destination_domain_id: bytes
    destination_bridge: int
    destination_bridge_execution_hash: bytes
    destination_bridge_descriptor: DestinationBridgeDescriptor
    destination_infrastructure_hash: bytes
    migration_verifier_descriptor_hash: bytes
    ingress_authorization_root: bytes
    native_liquidity_pool: int
    pool_runtime_hash: bytes
    pool_configuration_hash: bytes
    components: tuple[ComponentDescriptor, ...]


PROFILE_FORBIDDEN_REVERSE_DEPENDENCIES = frozenset({
    "releaseManifestHash", "registrationCommitment",
    "destinationRegistrationCommitment",
})


def execution_profile_dependency_keys_valid(keys: tuple[str, ...]) -> bool:
    """The profile is an ancestor of the manifest, never its descendant."""
    return (len(keys) == len(set(keys))
            and not PROFILE_FORBIDDEN_REVERSE_DEPENDENCIES.intersection(keys))


def canonical_release_manifest(descriptor: ReleaseManifestDescriptor) -> bytes:
    assert (0 < descriptor.protocol_version <= UINT64_MAX
            and 0 < descriptor.settlement_chain_id < 1 << 256
            and 0 < descriptor.destination_chain_id <= UINT64_MAX
            and descriptor.destination_genesis_hash != bytes(32)
            and descriptor.execution_profile_hash != bytes(32)
            and descriptor.manifest_namespace != bytes(32)
            and descriptor.destination_namespace != bytes(32)
            and descriptor.anchor != 0
            and descriptor.anchor_runtime_hash != bytes(32)
            and descriptor.destination_domain_id != bytes(32)
            and descriptor.destination_bridge != 0
            and descriptor.migration_verifier_descriptor_hash != bytes(32)
            and descriptor.ingress_authorization_root != bytes(32)
            and descriptor.native_liquidity_pool != 0
            and descriptor.pool_runtime_hash != bytes(32)
            and descriptor.pool_configuration_hash != bytes(32)
            and descriptor.destination_bridge_execution_hash
                == destination_bridge_execution_hash(
                    descriptor.destination_bridge_descriptor)
            and descriptor.destination_infrastructure_hash
                == destination_infrastructure_hash(descriptor.components)
            and descriptor.components[9].address
                == descriptor.destination_bridge
            and descriptor.components[8].address
                == descriptor.native_liquidity_pool
            and descriptor.components[8].runtime_hash
                == descriptor.pool_runtime_hash
            and descriptor.components[8].config_hash
                == descriptor.pool_configuration_hash
            and descriptor.destination_bridge_descriptor.bridge
                == descriptor.destination_bridge
            and descriptor.destination_bridge_descriptor.runtime_hash
                == descriptor.components[9].runtime_hash
            and descriptor.destination_bridge_descriptor.configuration_hash
                == descriptor.components[9].config_hash
            and descriptor.destination_bridge_descriptor.inbox_credit_store
                == descriptor.components[4].address
            and descriptor.destination_bridge_descriptor.terminal_accumulator
                == descriptor.components[7].address
            and descriptor.destination_bridge_descriptor.terminal_domain_registrar
                == descriptor.components[6].address
            and descriptor.destination_bridge_descriptor.native_liquidity_pool
                == descriptor.native_liquidity_pool
            and descriptor.destination_domain_id == destination_domain_id(
                descriptor.destination_chain_id,
                descriptor.destination_genesis_hash,
                descriptor.components[0].address,
                descriptor.components[1].address,
                descriptor.components[2].address,
                descriptor.components[3].address,
                descriptor.components[4].address,
                descriptor.components[5].address,
                descriptor.components[6].address,
                descriptor.components[7].address,
                descriptor.components[8].address,
                descriptor.destination_bridge,
                descriptor.destination_bridge_execution_hash,
                descriptor.destination_infrastructure_hash,
                descriptor.destination_namespace))
    addresses = tuple(component.address for component in descriptor.components)
    assert len(set(addresses)) == 10
    encoded = (
        u256(descriptor.protocol_version)
        + u256(descriptor.settlement_chain_id)
        + u256(descriptor.destination_chain_id)
        + b32(descriptor.destination_genesis_hash)
        + b32(descriptor.execution_profile_hash)
        + b32(descriptor.manifest_namespace)
        + b32(descriptor.destination_namespace)
        + address_word(descriptor.anchor)
        + b32(descriptor.anchor_runtime_hash)
        + b32(descriptor.destination_domain_id)
        + address_word(descriptor.destination_bridge)
        + b32(descriptor.destination_bridge_execution_hash)
        + address_word(descriptor.destination_bridge_descriptor.bridge)
        + b32(descriptor.destination_bridge_descriptor.runtime_hash)
        + b32(descriptor.destination_bridge_descriptor.configuration_hash)
        + b32(descriptor.destination_bridge_descriptor.storage_layout_hash)
        + b32(descriptor.destination_bridge_descriptor.bridge_kernel_profile_hash)
        + address_word(descriptor.destination_bridge_descriptor.inbox_credit_store)
        + address_word(descriptor.destination_bridge_descriptor.terminal_accumulator)
        + address_word(descriptor.destination_bridge_descriptor.terminal_domain_registrar)
        + address_word(descriptor.destination_bridge_descriptor.quota_manager)
        + address_word(descriptor.destination_bridge_descriptor.native_liquidity_pool)
        + b32(descriptor.destination_infrastructure_hash)
        + b32(descriptor.migration_verifier_descriptor_hash)
        + b32(descriptor.ingress_authorization_root)
        + address_word(descriptor.native_liquidity_pool)
        + b32(descriptor.pool_runtime_hash)
        + b32(descriptor.pool_configuration_hash)
        + b"".join(address_word(component.address)
                    + b32(component.runtime_hash)
                    + b32(component.config_hash)
                    for component in descriptor.components))
    assert len(encoded) == 1_856
    return encoded


def release_manifest_hash(descriptor: ReleaseManifestDescriptor) -> bytes:
    encoded = canonical_release_manifest(descriptor)
    return keccak256(RELEASE_MANIFEST_TYPEHASH + encoded)


def decode_canonical_release_manifest(
        encoded: bytes) -> ReleaseManifestDescriptor:
    assert len(encoded) == 58 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(58))
    bridge_descriptor = DestinationBridgeDescriptor(
        address_word_value(words[12]), b32(words[13]), b32(words[14]),
        b32(words[15]), b32(words[16]), address_word_value(words[17]),
        address_word_value(words[18]), address_word_value(words[19]),
        address_word_value(words[20]), address_word_value(words[21]))
    components = tuple(
        ComponentDescriptor(
            address_word_value(words[28 + index * 3]),
            b32(words[29 + index * 3]), b32(words[30 + index * 3]))
        for index in range(10))
    descriptor = ReleaseManifestDescriptor(
        uint_word_value(words[0], 64), uint_word_value(words[1]),
        uint_word_value(words[2], 64), b32(words[3]), b32(words[4]),
        b32(words[5]), b32(words[6]), address_word_value(words[7]),
        b32(words[8]), b32(words[9]), address_word_value(words[10]),
        b32(words[11]), bridge_descriptor, b32(words[22]), b32(words[23]),
        b32(words[24]), address_word_value(words[25]), b32(words[26]),
        b32(words[27]), components)
    assert encoded == canonical_release_manifest(descriptor)
    return descriptor


@dataclass(frozen=True)
class RegisterReleasePayloadV1:
    expected_predecessor_protocol_version: int
    release_manifest: ReleaseManifestDescriptor
    settlement_deployment_descriptor: SettlementDeploymentDescriptorV1
    profile_bytes: bytes


@dataclass(frozen=True)
class RegisterForkVerifierPayloadV1:
    fork_digest: bytes
    first_window: int
    verifier: int
    runtime_hash: bytes
    beacon_slot_gindex: int
    execution_payload_gindex: int
    state_root_gindex: int
    prev_randao_gindex: int
    timestamp_gindex: int
    block_hash_gindex: int
    witness_schema_hash: bytes
    configuration_hash: bytes
    selector: bytes
    gas_limit: int


@dataclass(frozen=True)
class PublishGenesisCampaignPayloadV1:
    force_cutoff_block: int
    proposal_cutoff_block: int
    quiesce_not_before_block: int
    resume_by_block: int
    resume_by_timestamp: int
    review_finalized_by_block: int
    target_settlement: int
    target_protocol_version: int
    target_manifest_hash: bytes
    target_registration_hash: bytes


@dataclass(frozen=True)
class PublishMigrationArmPayloadV1:
    expected_source_protocol_version: int
    target_protocol_version: int
    target_manifest_hash: bytes
    target_registration_hash: bytes


def target_registration_v2_hash(
        expected_predecessor_protocol_version: int,
        manifest: ReleaseManifestDescriptor,
        deployment: SettlementDeploymentDescriptorV1,
        migration_activation_profile_record_hash_: bytes) -> bytes:
    assert (0 <= expected_predecessor_protocol_version
            < manifest.protocol_version
            <= UINT64_MAX
            and manifest.settlement_chain_id > 0
            and migration_activation_profile_record_hash_ != bytes(32))
    deployment_hash = settlement_deployment_descriptor_hash(deployment)
    manifest_hash = release_manifest_hash(manifest)
    return keccak256(
        D_TARGET_REGISTRATION_V2 + u64(manifest.protocol_version)
        + address20(deployment.target_settlement)
        + b32(deployment.target_runtime_hash)
        + b32(deployment.target_configuration_hash) + b32(deployment_hash)
        + b32(manifest.execution_profile_hash)
        + b32(migration_activation_profile_record_hash_) + b32(manifest_hash)
        + u64(expected_predecessor_protocol_version)
        + u64(manifest.settlement_chain_id)
        + b32(manifest.ingress_authorization_root)
        + b32(manifest.migration_verifier_descriptor_hash))


def execution_profile_hash(profile_bytes: bytes) -> bytes:
    assert 1 <= len(profile_bytes) <= 65_536
    return keccak256(
        D_EXECUTION_PROFILE + u32(len(profile_bytes)) + profile_bytes)


EXECUTION_PROFILE_VALUE_WORDS = 252
EXECUTION_PROFILE_STATIC_WORDS = 253
EXECUTION_PROFILE_STATIC_BYTES = EXECUTION_PROFILE_STATIC_WORDS * 32
EIP3860_MAX_INITCODE_BYTES = 49_152
EIP170_MAX_RUNTIME_BYTES = 24_576
TARGET_PARAMETERS_V2_WORDS = EXECUTION_PROFILE_VALUE_WORDS
TARGET_CONSTRUCTOR_TRAILER_BYTES = (TARGET_PARAMETERS_V2_WORDS + 4) * 32
TARGET_CREATION_CODE_MAX_BYTES = (
    EIP3860_MAX_INITCODE_BYTES - TARGET_CONSTRUCTOR_TRAILER_BYTES)
L1_EIP2935_HISTORY_STORAGE_ADDRESS = int(
    "0000F90827F1C53a10cb7A02335B175320002935", 16)
L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH = bytes.fromhex(
    "6e49e66782037c0555897870e29fa5e552daf4719552131a0abce779daec0a5d")
L1_EIP2935_FIRST_SUPPORTED_BLOCK = 1
L2_EIP2935_HISTORY_STORAGE_ADDRESS = int(
    "0000F90827F1C53a10cb7A02335B175320002935", 16)
L2_EIP2935_HISTORY_STORAGE_RUNTIME_HASH = bytes.fromhex(
    "6e49e66782037c0555897870e29fa5e552daf4719552131a0abce779daec0a5d")
L2_EIP2935_HISTORY_STORAGE_ACTIVATION_BLOCK = 1
EIP2935_HISTORY_SERVE_WINDOW = 8_191
EIP2935_HISTORY_READ_GAS = 50_000
EIP2935_READ_CONFIG_DOMAIN = b"slot-chain-eip2935-read-config-v1"
SETTLEMENT_FACTORY_DEPLOY_SELECTOR = bytes.fromhex("4af63f02")
SETTLEMENT_FACTORY_CONFIG_DOMAIN = \
    b"slot-chain-erc2470-factory-config-v1"
SETTLEMENT_FACTORY_ADDRESS_V2 = int(
    "ce0042b868300000d44a59004da54a005ffdcf9f", 16)
SETTLEMENT_FACTORY_RUNTIME_HASH_V2 = bytes.fromhex(
    "c4d5542b53a8b779595a20a8ddd60e58a6c49d3c3decc2df83ced1c69c8ca807")
SETTLEMENT_FACTORY_CREATION_CODE_HASH_V2 = bytes.fromhex(
    "122b6b28aeddfd05fa3ce4348e93d357b3ce50d9ab7dda4e8ee524a5b9a6ab3b")
SETTLEMENT_FACTORY_DEPLOYMENT_TRANSACTION_HASH_V2 = bytes.fromhex(
    "803351deb6d745e91545a6a3e1c0ea3e9a6a02a1a4193b70edfcd2f40f71a01c")
SETTLEMENT_FACTORY_SINGLE_USE_DEPLOYER_V2 = int(
    "bb6e024b9cffacb947a71991e386681b1cd1477d", 16)
TARGET_CONSTRUCTOR_POSTSTATE_DOMAIN = \
    b"slot-chain-target-constructor-poststate-v2"
TARGET_CONSTRUCTOR_STATE_SELECTOR = keccak256(
    b"targetConstructorStateV2()")[:4]
TARGET_CONSTRUCTOR_STATE_MAGIC = b"TCS2"
TARGET_CONSTRUCTOR_STATE_LENGTH = 96
DATA_SESSION_ACCOUNTING_SELECTOR = keccak256(
    b"dataSessionAccountingV1()")[:4]
DATA_SESSION_ACCOUNTING_MAGIC = b"DSV1"
DATA_SESSION_ACCOUNTING_LENGTH = 384


def eip2935_read_configuration_hash_v1(first_supported_block: int) -> bytes:
    assert 0 < first_supported_block <= UINT64_MAX
    return keccak256(
        EIP2935_READ_CONFIG_DOMAIN
        + address20(L1_EIP2935_HISTORY_STORAGE_ADDRESS)
        + L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
        + u64(first_supported_block)
        + u64(EIP2935_HISTORY_SERVE_WINDOW)
        + u64(EIP2935_HISTORY_READ_GAS))


def settlement_factory_configuration_hash_v2() -> bytes:
    return keccak256(
        SETTLEMENT_FACTORY_CONFIG_DOMAIN + u16(147)
        + address20(SETTLEMENT_FACTORY_ADDRESS_V2)
        + SETTLEMENT_FACTORY_RUNTIME_HASH_V2
        + SETTLEMENT_FACTORY_CREATION_CODE_HASH_V2
        + SETTLEMENT_FACTORY_DEPLOYMENT_TRANSACTION_HASH_V2
        + address20(SETTLEMENT_FACTORY_SINGLE_USE_DEPLOYER_V2)
        + SETTLEMENT_FACTORY_DEPLOY_SELECTOR
        + u32(EIP3860_MAX_INITCODE_BYTES) + u16(32) + u8(1))


def pvm_derived_market_authority_configuration_hash_v1(
        market_chain_id: int, market_address: int,
        settlement_chain_id: int, protocol_version_manager: int,
        active_settlement_router: int) -> bytes:
    addresses = (
        market_address, protocol_version_manager, active_settlement_router)
    assert (0 < market_chain_id < 1 << 256
            and 0 < settlement_chain_id < 1 << 256
            and all(0 < value < 1 << 160 for value in addresses)
            and len(set(addresses)) == 3)
    payload = (
        u256(market_chain_id) + address20(market_address)
        + u256(settlement_chain_id) + address20(protocol_version_manager)
        + address20(active_settlement_router))
    assert len(payload) == 124
    return keccak256(
        b"slot-chain-pvm-derived-market-authority-config-v1"
        + u16(len(payload)) + payload)


def target_constructor_inventory_v2(
        profile_bytes: bytes,
        derived: "DerivedRegisterReleaseAuthorityV2") -> tuple[bytes, ...]:
    words = decode_execution_profile_v2(profile_bytes)
    inventory = (
        *words[:EXECUTION_PROFILE_VALUE_WORDS],
        derived.execution_profile_hash,
        derived.migration_activation_profile.activation_profile_record_hash,
        words[48], derived.target_artifact_hash,
        derived.target_parameters_hash, derived.data_session_configuration_hash,
        derived.settlement_deployment_descriptor.target_configuration_hash,
    )
    assert len(inventory) == 259
    return inventory


def target_constructor_poststate_commitment_v2(
        inventory: tuple[bytes, ...]) -> bytes:
    assert (len(inventory) == 259
            and all(type(word) is bytes and len(word) == 32
                    for word in inventory))
    return keccak256(
        TARGET_CONSTRUCTOR_POSTSTATE_DOMAIN
        + u16(EXECUTION_PROFILE_VALUE_WORDS) + b"".join(inventory))


def encode_target_constructor_state_return_v2(
        constructor_poststate_commitment: bytes,
        target_configuration_hash: bytes) -> bytes:
    assert (constructor_poststate_commitment != bytes(32)
            and target_configuration_hash != bytes(32))
    encoded = (TARGET_CONSTRUCTOR_STATE_MAGIC + bytes(28)
               + b32(constructor_poststate_commitment)
               + b32(target_configuration_hash))
    assert len(encoded) == TARGET_CONSTRUCTOR_STATE_LENGTH
    return encoded


def encode_empty_data_session_accounting_v1(
        data_session_configuration_hash: bytes) -> bytes:
    assert data_session_configuration_hash != bytes(32)
    encoded = (DATA_SESSION_ACCOUNTING_MAGIC + bytes(28)
               + u256(0) * 10 + b32(data_session_configuration_hash))
    assert len(encoded) == DATA_SESSION_ACCOUNTING_LENGTH
    return encoded


def live_registration_validation_commitment_v2(
        derived: "DerivedRegisterReleaseAuthorityV2",
        accounting_return: bytes,
        constructor_return: bytes) -> bytes:
    assert (len(accounting_return) == DATA_SESSION_ACCOUNTING_LENGTH
            and len(constructor_return) == TARGET_CONSTRUCTOR_STATE_LENGTH)
    return keccak256(
        b"slot-chain-live-deployment-validation-v2"
        + settlement_deployment_descriptor_hash(
            derived.settlement_deployment_descriptor)
        + derived.target_registration_hash + keccak256(accounting_return)
        + keccak256(constructor_return))
EXECUTION_PROFILE_KIND_CODES = (
    # core
    ("u64", "u64", "u256", "u256", "h", "h", "f", "u64", "u64",
     "h", "h", "h", "h", "a", "h", "h")
    # control
    + ("a", "h", "h", "a") + ("a", "h", "h") * 8
    # artifact, target infrastructure, sinks
    + ("a", "h", "h") + ("h",) * 10
    + ("a", "h", "h") * 2
    + ("a", "h", "u8", "a", "a", "a", "a", "a", "a")
    # recovery, seat, DataSession, target gas
    + ("u64",) * 14 + ("u64",) * 11 + ("u256",) * 4
    + ("u256", "u256z", "u256z", "u16z", "u64", "u64")
    + ("u64",) * 11
    # compile-time rules
    + ("u8", "u16", "u8", "u8", "u8", "u8", "u16", "u16",
       "u16", "u8", "u8", "u16", "u8", "u8", "a", "u32",
       "u256", "u32", "u32", "u16")
    # MPR2
    + ("a", "h", "h", "h", "h", "h", "f", "u32") + ("u64",) * 12
    # destination
    + ("a", "a") + ("a", "h", "h") * 10 + ("h",) * 5
    + ("a", "h", "h", "u256", "u64", "u64", "u64")
    # source
    + ("a", "h", "h", "h", "h", "a", "h", "a", "a", "h", "h",
       "h", "a", "h", "h", "a", "h", "h", "a", "h", "h", "a",
       "a", "u64", "h", "h")
    # ingress and execution
    + ("a", "h") + ("u256",) * 5
    + ("u64",) * 5 + ("h",) * 4 + ("u64", "h", "u64") + ("h",) * 5
)


def governance_delay_authority_descriptor_from_profile_v1(
        words: tuple[bytes, ...]) -> bytes:
    descriptor = GovernanceDelayAuthorityDescriptorV1(
        uint_word_value(words[2]), address_word_value(words[16]), words[17],
        address_word_value(words[19]), address_word_value(words[20]))
    return governance_delay_authority_descriptor_hash(descriptor)


def protocol_version_manager_configuration_from_profile_v1(
        words: tuple[bytes, ...]) -> bytes:
    config = ProtocolVersionManagerConfigurationV1(
        uint_word_value(words[2]), address_word_value(words[16]), words[18],
        address_word_value(words[23]), address_word_value(words[26]),
        address_word_value(words[29]), address_word_value(words[32]),
        address_word_value(words[35]), words[36], words[37],
        words[24], words[25], words[27], words[28], words[30], words[31],
        words[33], words[34], words[39], words[40], words[42], words[43],
        address_word_value(words[38]), address_word_value(words[41]), words[9],
        15_000_000, 1_000_000, 500_000, 2_000_000)
    return protocol_version_manager_configuration_hash(config)


def canonical_execution_profile_cross_model_fixture_v2() -> bytes:
    assert len(EXECUTION_PROFILE_KIND_CODES) == EXECUTION_PROFILE_VALUE_WORDS
    words: list[bytes] = []
    for index, kind in enumerate(EXECUTION_PROFILE_KIND_CODES):
        seed = keccak256(
            b"slot-chain-execution-profile-cross-model-v2" + u16(index))
        if kind == "a":
            words.append(bytes(12) + seed[12:])
        elif kind == "f":
            words.append(seed[:4] + bytes(28))
        elif kind.startswith("u"):
            words.append(u256(1))
        else:
            words.append(seed)
    creation_code = b"\x60\x00\x60\x00\xf3"
    runtime_code = b"\x60\x00\x60\x00\xf3"
    words[0] = u256(2)
    words[1] = u256(2)
    words[2] = u256(1)
    words[3] = u256(16_788)
    words[48] = keccak256(runtime_code)
    words[49] = keccak256(creation_code)
    words[44] = address_word(SETTLEMENT_FACTORY_ADDRESS_V2)
    words[45] = SETTLEMENT_FACTORY_RUNTIME_HASH_V2
    words[46] = settlement_factory_configuration_hash_v2()
    words[37] = pvm_derived_market_authority_configuration_hash_v1(
        uint_word_value(words[2]), int.from_bytes(words[35][12:], "big"),
        uint_word_value(words[2]), int.from_bytes(words[20][12:], "big"),
        int.from_bytes(words[23][12:], "big"))
    words[55] = keccak256(
        b"slot-chain-solc-immutable-references-v1" + bytes(4))
    words[56] = keccak256(
        b"slot-chain-solc-link-references-v1" + bytes(4))
    for index, value in enumerate((
            1, 384, 4, 4, 64, 12, 1_024, 2, 2_100, 8, 6, 256, 10, 2),
            start=118):
        words[index] = u256(value)
    words[132] = address_word(10)
    words[133] = u256(50_000)
    words[134] = u256(BLS_MODULUS)
    words[135] = u256(131_072)
    words[136] = u256(126_972)
    words[137] = u256(9)
    compile_bytes = b"".join(words[118:138])
    words[54] = keccak256(
        b"slot-chain-target-compile-time-rules-v2"
        + u16(len(compile_bytes)) + compile_bytes)
    words[144] = keccak256(
        b"verifyMigrationTransition(bytes,uint256[2])")[:4] + bytes(28)
    words[114] = words[152]
    words[115] = words[153]
    words[116] = words[150]
    words[117] = words[157]
    words[111] = u256(50_000)
    words[57] = address_word(L1_EIP2935_HISTORY_STORAGE_ADDRESS)
    words[58] = L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
    words[244] = u256(L1_EIP2935_FIRST_SUPPORTED_BLOCK)
    words[245] = L2_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
    words[59] = eip2935_read_configuration_hash_v1(
        L1_EIP2935_FIRST_SUPPORTED_BLOCK)
    words[246] = u256(L2_EIP2935_HISTORY_STORAGE_ACTIVATION_BLOCK)
    artifact = (u32(len(creation_code)) + creation_code
                + u32(len(runtime_code)) + runtime_code)
    encoded = (u256(32) + b"".join(words)
               + u256(EXECUTION_PROFILE_STATIC_BYTES)
               + abi_bytes_tail(artifact))
    encoded = canonicalize_execution_profile_authority_graph_v2(encoded)
    decode_execution_profile_v2(encoded)
    return encoded


def decode_execution_profile_v2(
        encoded: bytes, *, validate_authority_graph: bool = True
        ) -> tuple[bytes, ...]:
    assert (32 + EXECUTION_PROFILE_STATIC_BYTES + 64 <= len(encoded) <= 65_536
            and len(encoded) % 32 == 0 and encoded[:32] == u256(32))
    base = 32
    words = tuple(
        encoded[base + index * 32:base + (index + 1) * 32]
        for index in range(EXECUTION_PROFILE_STATIC_WORDS))
    assert len(words) == EXECUTION_PROFILE_STATIC_WORDS
    assert uint_word_value(words[-1]) == EXECUTION_PROFILE_STATIC_BYTES
    for word_, kind in zip(words[:-1], EXECUTION_PROFILE_KIND_CODES):
        if kind == "a":
            assert word_[:12] == bytes(12) and word_[12:] != bytes(20)
        elif kind == "f":
            assert word_[:4] != bytes(4) and word_[4:] == bytes(28)
        elif kind.startswith("u"):
            allow_zero = kind.endswith("z")
            bits = int(kind.removeprefix("u").removesuffix("z"))
            value = uint_word_value(word_, bits)
            assert allow_zero or value != 0
        else:
            assert word_ != bytes(32)
    assert uint_word_value(words[0], 64) == 2
    artifact_head = base + EXECUTION_PROFILE_STATIC_BYTES
    artifact_length = uint_word_value(encoded[artifact_head:artifact_head + 32])
    artifact = encoded[artifact_head + 32:artifact_head + 32 + artifact_length]
    assert encoded == (encoded[:artifact_head] + abi_bytes_tail(artifact))
    creation_length = int.from_bytes(artifact[:4], "big")
    creation = artifact[4:4 + creation_length]
    runtime_offset = 4 + creation_length
    runtime_length = int.from_bytes(artifact[runtime_offset:runtime_offset + 4],
                                    "big")
    runtime = artifact[runtime_offset + 4:]
    assert (0 < creation_length <= TARGET_CREATION_CODE_MAX_BYTES
            and 0 < runtime_length <= EIP170_MAX_RUNTIME_BYTES
            and len(runtime) == runtime_length
            and words[49] == keccak256(creation)
            and words[48] == keccak256(runtime))
    assert words[55] == keccak256(
        b"slot-chain-solc-immutable-references-v1" + bytes(4))
    assert words[56] == keccak256(
        b"slot-chain-solc-link-references-v1" + bytes(4))
    assert (words[44] == address_word(SETTLEMENT_FACTORY_ADDRESS_V2)
            and words[45] == SETTLEMENT_FACTORY_RUNTIME_HASH_V2
            and words[46] == settlement_factory_configuration_hash_v2())
    assert words[37] == pvm_derived_market_authority_configuration_hash_v1(
        uint_word_value(words[2]), int.from_bytes(words[35][12:], "big"),
        uint_word_value(words[2]), int.from_bytes(words[20][12:], "big"),
        int.from_bytes(words[23][12:], "big"))
    if validate_authority_graph:
        assert words[18] == \
            governance_delay_authority_descriptor_from_profile_v1(words)
    compile_bytes = b"".join(words[118:138])
    assert words[54] == keccak256(
        b"slot-chain-target-compile-time-rules-v2"
        + u16(len(compile_bytes)) + compile_bytes)
    for index, expected in enumerate((
            1, 384, 4, 4, 64, 12, 1_024, 2, 2_100, 8, 6, 256, 10, 2),
            start=118):
        assert uint_word_value(words[index]) == expected
    assert (words[132] == address_word(10)
            and uint_word_value(words[133]) == 50_000
            and uint_word_value(words[134]) == BLS_MODULUS
            and uint_word_value(words[135]) == 131_072
            and uint_word_value(words[136]) == 126_972
            and uint_word_value(words[137]) == 9)
    assert words[144] == keccak256(
        b"verifyMigrationTransition(bytes,uint256[2])")[:4] + bytes(28)
    assert (words[114] == words[152] and words[115] == words[153]
            and words[116] == words[150] and words[117] == words[157])
    assert uint_word_value(words[106], 64) >= uint_word_value(words[105], 64)
    assert uint_word_value(words[111], 64) == 50_000
    l1_first_supported = uint_word_value(words[244], 64)
    l2_activation = uint_word_value(words[246], 64)
    assert (words[57] == address_word(L1_EIP2935_HISTORY_STORAGE_ADDRESS)
            and words[58] == L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
            and words[245] == L2_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
            and words[59] == eip2935_read_configuration_hash_v1(
                l1_first_supported)
            and uint_word_value(words[7], 64) >= l2_activation)
    return words


def canonicalize_execution_profile_authority_graph_v2(encoded: bytes) -> bytes:
    """Materialize the source/destination joins used by cross-model fixtures."""

    words = list(decode_execution_profile_v2(
        encoded, validate_authority_graph=False))
    words[37] = pvm_derived_market_authority_configuration_hash_v1(
        uint_word_value(words[2]), int.from_bytes(words[35][12:], "big"),
        uint_word_value(words[2]), int.from_bytes(words[20][12:], "big"),
        int.from_bytes(words[23][12:], "big"))
    words[18] = governance_delay_authority_descriptor_from_profile_v1(
        tuple(words))
    words[22] = protocol_version_manager_configuration_from_profile_v1(
        tuple(words))
    selector = bytes4_word_value(words[144])
    words[140] = keccak256(
        MIGRATION_VERIFIER_CONFIG_TYPEHASH + words[141] + words[142]
        + words[143] + bytes4_word(selector)
        + u256(uint_word_value(words[145], 32))
        + u256(uint_word_value(words[146], 64)))
    factory = address_word_value(words[202])
    deployer = create2_address(factory, words[205], words[206])
    words[207] = address_word(deployer)
    words[210] = address_word(create_address_from_nonce(deployer, 1))
    words[214] = address_word(create_address_from_nonce(deployer, 2))
    words[217] = address_word(create_address_from_nonce(deployer, 3))
    words[163:166] = words[23:26]
    kind1_config = (
        words[214][12:] + words[210][12:] + words[23][12:] + words[20][12:]
    )
    words[162] = component_config_hash(1, kind1_config)
    bridge_config = (
        words[190] + words[191] + words[172][12:] + words[181][12:]
        + words[178][12:] + words[195][12:] + words[184][12:]
    )
    words[189] = component_config_hash(10, bridge_config)
    words[230:235] = (u256(1), u256(1), u256(1), u256(1),
                      u256(20_000_000))
    rewritten = (encoded[:32] + b"".join(words)
                 + encoded[32 + EXECUTION_PROFILE_STATIC_BYTES:])
    decode_execution_profile_v2(rewritten)
    return rewritten


def encode_register_release_payload(
        payload: RegisterReleasePayloadV1) -> bytes:
    derived = derive_register_release_authority_v2(
        payload.profile_bytes,
        payload.expected_predecessor_protocol_version)
    assert (payload.release_manifest == derived.release_manifest
            and payload.settlement_deployment_descriptor
                == derived.settlement_deployment_descriptor)
    head = (
        u256(payload.expected_predecessor_protocol_version)
        + canonical_release_manifest(payload.release_manifest)
        + encode_settlement_deployment_descriptor_abi(
            payload.settlement_deployment_descriptor)
        + u256(68 * 32))
    assert len(head) == 68 * 32
    encoded = head + abi_bytes_tail(payload.profile_bytes)
    assert len(encoded) == 2_208 + ceil32(len(payload.profile_bytes))
    return encoded


def decode_register_release_payload(encoded: bytes) -> RegisterReleasePayloadV1:
    assert len(encoded) >= 2_240
    assert uint_word_value(encoded[67 * 32:68 * 32]) == 68 * 32
    profile_length = uint_word_value(encoded[68 * 32:69 * 32])
    profile_start = 69 * 32
    profile_bytes = encoded[profile_start:profile_start + profile_length]
    payload = RegisterReleasePayloadV1(
        uint_word_value(encoded[:32], 64),
        decode_canonical_release_manifest(encoded[32:59 * 32]),
        decode_settlement_deployment_descriptor_abi(encoded[59 * 32:67 * 32]),
        profile_bytes)
    assert encoded == encode_register_release_payload(payload)
    return payload


@dataclass(frozen=True)
class MigrationActivationProfileRecordV2:
    protocol_version: int
    execution_profile_hash: bytes
    activation_profile_record_hash: bytes
    verifier: int
    verifier_runtime_hash: bytes
    verifier_configuration_hash: bytes
    verifying_key_hash: bytes
    proof_system_id: bytes
    public_input_schema_hash: bytes
    verifier_selector: bytes
    maximum_proof_bytes: int
    verification_gas_limit: int
    supported_l1_block_gas_limit: int
    worst_case_activation_adoption_gas: int
    source_freeze_gas_limit: int
    target_adoption_gas_limit: int
    queue_migration_gas_limit: int
    activation_context_read_gas_limit: int
    post_state_read_gas_limit: int
    legacy_state_read_gas_limit: int
    legacy_arm_gas_limit: int
    legacy_finalize_gas_limit: int
    post_callback_reserve_gas: int


def migration_activation_profile_record_hash(
        record: MigrationActivationProfileRecordV2) -> bytes:
    hashes = (
        record.execution_profile_hash, record.verifier_runtime_hash,
        record.verifier_configuration_hash, record.verifying_key_hash,
        record.proof_system_id, record.public_input_schema_hash)
    gas_values = (
        record.verification_gas_limit, record.supported_l1_block_gas_limit,
        record.worst_case_activation_adoption_gas,
        record.source_freeze_gas_limit, record.target_adoption_gas_limit,
        record.queue_migration_gas_limit,
        record.activation_context_read_gas_limit,
        record.post_state_read_gas_limit, record.legacy_state_read_gas_limit,
        record.legacy_arm_gas_limit, record.legacy_finalize_gas_limit,
        record.post_callback_reserve_gas)
    assert (0 < record.protocol_version <= UINT64_MAX
            and all(value != bytes(32) for value in hashes)
            and record.verifier != 0
            and len(record.verifier_selector) == 4
            and record.verifier_selector != bytes(4)
            and 0 < record.maximum_proof_bytes <= UINT32_MAX
            and all(0 < value <= UINT64_MAX for value in gas_values))
    return keccak256(
        D_MIGRATION_ACTIVATION_PROFILE + u64(record.protocol_version)
        + b32(record.execution_profile_hash) + address20(record.verifier)
        + b32(record.verifier_runtime_hash)
        + b32(record.verifier_configuration_hash)
        + b32(record.verifying_key_hash) + b32(record.proof_system_id)
        + b32(record.public_input_schema_hash) + record.verifier_selector
        + u32(record.maximum_proof_bytes)
        + b"".join(u64(value) for value in gas_values))


@dataclass(frozen=True)
class DerivedRegisterReleaseAuthorityV2:
    execution_profile_hash: bytes
    migration_activation_profile: MigrationActivationProfileRecordV2
    migration_verifier_descriptor_hash: bytes
    target_parameters_hash: bytes
    target_artifact_hash: bytes
    data_session_configuration_hash: bytes
    settlement_deployment_descriptor: SettlementDeploymentDescriptorV1
    source_bridge_descriptor: SourceBridgeDescriptor
    source_domain_id: bytes
    source_bridge_execution_hash: bytes
    destination_components: tuple[ComponentDescriptor, ...]
    destination_bridge_descriptor: DestinationBridgeDescriptor
    destination_domain_id: bytes
    destination_bridge_execution_hash: bytes
    destination_infrastructure_hash: bytes
    ingress_rows: tuple[ProfileIngressAuthorizationV2, ...]
    ingress_authorization_root: bytes
    release_manifest: ReleaseManifestDescriptor
    release_manifest_hash: bytes
    target_registration_hash: bytes


def _execution_profile_artifact_v2(profile_bytes: bytes) -> tuple[bytes, bytes]:
    decode_execution_profile_v2(profile_bytes)
    head = 32 + EXECUTION_PROFILE_STATIC_BYTES
    artifact_length = uint_word_value(profile_bytes[head:head + 32])
    artifact = profile_bytes[head + 32:head + 32 + artifact_length]
    creation_length = int.from_bytes(artifact[:4], "big")
    creation = artifact[4:4 + creation_length]
    runtime_offset = 4 + creation_length
    runtime_length = int.from_bytes(artifact[runtime_offset:runtime_offset + 4],
                                    "big")
    runtime = artifact[runtime_offset + 4:runtime_offset + 4 + runtime_length]
    assert runtime_offset + 4 + runtime_length == len(artifact)
    return creation, runtime


def _migration_activation_profile_from_words_v2(
        words: tuple[bytes, ...], profile_hash: bytes
        ) -> tuple[MigrationActivationProfileRecordV2, bytes]:
    selector = bytes4_word_value(words[144])
    expected_config = keccak256(
        MIGRATION_VERIFIER_CONFIG_TYPEHASH + words[141] + words[142]
        + words[143] + bytes4_word(selector)
        + u256(uint_word_value(words[145], 32))
        + u256(uint_word_value(words[146], 64)))
    assert words[140] == expected_config
    descriptor = MigrationVerifierDescriptor(
        address_word_value(words[138]), words[139], words[140], words[141],
        words[142], words[143], selector, uint_word_value(words[145], 32),
        uint_word_value(words[146], 64))
    descriptor_hash = migration_verifier_descriptor_hash(descriptor)
    gases = tuple(uint_word_value(word, 64) for word in words[146:158])
    unbound = MigrationActivationProfileRecordV2(
        uint_word_value(words[1], 64), profile_hash, bytes(32),
        descriptor.verifier, descriptor.runtime_hash,
        descriptor.configuration_hash, descriptor.verifying_key_hash,
        descriptor.proof_system_id, descriptor.public_input_schema_hash,
        descriptor.selector, descriptor.maximum_proof_bytes, *gases)
    record = replace(
        unbound,
        activation_profile_record_hash=migration_activation_profile_record_hash(
            unbound))
    return record, descriptor_hash


def derive_register_release_authority_v2(
        profile_bytes: bytes,
        expected_predecessor_protocol_version: int
        ) -> DerivedRegisterReleaseAuthorityV2:
    """Pure authority derivation used by both encode and strict decode."""

    words = decode_execution_profile_v2(profile_bytes)
    protocol_version = uint_word_value(words[1], 64)
    settlement_chain_id = uint_word_value(words[2])
    destination_chain_id_ = uint_word_value(words[3])
    assert (0 <= expected_predecessor_protocol_version < protocol_version
            and 0 < settlement_chain_id <= UINT64_MAX
            and 0 < destination_chain_id_ <= UINT64_MAX)
    profile_hash = execution_profile_hash(profile_bytes)
    activation, migration_descriptor_hash = (
        _migration_activation_profile_from_words_v2(words, profile_hash))
    creation, runtime = _execution_profile_artifact_v2(profile_bytes)
    target_parameters = b"".join(words[:EXECUTION_PROFILE_VALUE_WORDS])
    assert len(target_parameters) == 8_064
    target_parameters_hash = keccak256(
        b"slot-chain-target-parameters-v2" + u16(len(target_parameters))
        + target_parameters)
    artifact_words = (
        words[49], words[48], words[50], words[51], words[52], words[53],
        words[54], words[55], words[56])
    artifact_preimage = b"".join(artifact_words)
    target_artifact_hash = keccak256(
        b"slot-chain-settlement-artifact-v2" + u16(len(artifact_preimage))
        + artifact_preimage)
    constructor_tail = (
        target_parameters + profile_hash
        + activation.activation_profile_record_hash + words[48]
        + target_artifact_hash)
    assert len(constructor_tail) == TARGET_CONSTRUCTOR_TRAILER_BYTES
    init_code = creation + constructor_tail
    assert len(creation) <= TARGET_CREATION_CODE_MAX_BYTES
    init_code_hash = keccak256(init_code)
    factory = address_word_value(words[44])
    target = create2_address(factory, words[47], init_code_hash)
    data_descriptor = (
        words[2] + words[1][-8:] + address20(target) + words[23][12:]
        + words[20][12:] + words[67][12:] + profile_hash + words[101]
        + words[102] + words[103] + words[104][-2:] + words[105][-8:]
        + words[106][-8:] + words[124][-2:] + words[125][-2:]
        + words[126][-2:] + words[127][-1:] + words[128][-1:]
        + words[132][12:] + words[133][-4:] + words[134]
        + words[135][-4:] + words[136][-4:] + words[137][-2:])
    assert len(data_descriptor) == 340
    data_config_hash = keccak256(
        D_DATA_SESSION_CONFIG + u32(len(data_descriptor)) + data_descriptor)
    target_config_preimage = (
        address20(target) + words[48] + profile_hash
        + activation.activation_profile_record_hash + target_parameters_hash
        + target_artifact_hash + data_config_hash)
    assert len(target_config_preimage) == 212
    target_config_hash = keccak256(
        b"slot-chain-settlement-config-v2"
        + u16(len(target_config_preimage)) + target_config_preimage)
    deployment = SettlementDeploymentDescriptorV1(
        factory, words[45], words[46], words[47], init_code_hash, target,
        words[48], target_config_hash)
    settlement_deployment_descriptor_hash(deployment)

    components = tuple(
        ComponentDescriptor(
            address_word_value(words[160 + index * 3]),
            words[161 + index * 3], words[162 + index * 3])
        for index in range(10))
    assert components[1] == ComponentDescriptor(
        address_word_value(words[23]), words[24], words[25])
    source = SourceBridgeDescriptor(
        address_word_value(words[202]), words[203], words[204], words[205],
        words[206], address_word_value(words[207]), words[208],
        address_word_value(words[209]), address_word_value(words[210]),
        words[211], words[212], words[213], address_word_value(words[214]),
        words[215], words[216], address_word_value(words[217]), words[218],
        words[219], address_word_value(words[220]), words[221], words[222],
        components[2].address, components[2].runtime_hash,
        components[2].config_hash, address_word_value(words[223]),
        address_word_value(words[224]), words[191],
        uint_word_value(words[225], 64))
    source_execution_hash = bridge_execution_hash(source)
    source_domain = source_domain_id(
        settlement_chain_id, words[227], source.credit_registry,
        source.terminal_verifier, source.source_bridge, source_execution_hash,
        words[226])
    expected_kind1_config = component_config_hash(
        1, address20(source.credit_registry) + address20(source.source_bridge)
        + address20(components[1].address) + address20(
            address_word_value(words[20])))
    assert components[0].config_hash == expected_kind1_config
    destination_bridge = DestinationBridgeDescriptor(
        components[9].address, components[9].runtime_hash,
        components[9].config_hash, words[190], words[191],
        components[4].address, components[7].address, components[6].address,
        address_word_value(words[195]), components[8].address)
    expected_bridge_config = component_config_hash(
        10, destination_bridge_component_config(
            words[190], words[191], components[4].address,
            components[7].address, components[6].address,
            address_word_value(words[195]), components[8].address))
    assert components[9].config_hash == expected_bridge_config
    destination_execution_hash = destination_bridge_execution_hash(
        destination_bridge)
    infrastructure_hash = destination_infrastructure_hash(components)
    destination_domain = destination_domain_id(
        destination_chain_id_, words[5], components[0].address,
        components[1].address, components[2].address, components[3].address,
        components[4].address, components[5].address, components[6].address,
        components[7].address, components[8].address, components[9].address,
        destination_execution_hash, infrastructure_hash, words[10])
    fees = tuple(uint_word_value(words[index]) for index in range(230, 235))
    kind0_config_preimage = (
        words[2] + words[1][-8:] + words[23][12:] + words[24] + words[25]
        + words[26][12:] + words[27] + words[28] + words[20][12:] + words[3])
    assert len(kind0_config_preimage) == 260
    kind0_config = keccak256(
        b"slot-chain-kind0-ingress-config-v1"
        + u32(len(kind0_config_preimage)) + kind0_config_preimage)
    common = dict(
        active_settlement_router=address_word_value(words[23]),
        router_runtime_hash=words[24], router_configuration_hash=words[25],
        forced_queue=address_word_value(words[26]),
        queue_runtime_hash=words[27], queue_configuration_hash=words[28],
        destination_chain_id=destination_chain_id_,
        fixed_ingress_wei=fees[0], execution_wei_per_accounted_gas=fees[1],
        proof_wei_per_accounted_gas=fees[2], permanent_wei_per_byte=fees[3],
        maximum_accepted_fee_wei=fees[4])
    ingress_rows = (
        ProfileIngressAuthorizationV2(
            0, address_word_value(words[228]), words[229], kind0_config,
            source_domain_id=bytes(32), source_registration_epoch=0,
            source_bridge_execution_hash=bytes(32),
            destination_domain_id=bytes(32), destination_bridge=0,
            destination_bridge_execution_hash=bytes(32),
            destination_infrastructure_hash=bytes(32), **common),
        ProfileIngressAuthorizationV2(
            1, components[0].address, components[0].runtime_hash,
            components[0].config_hash, source_domain_id=source_domain,
            source_registration_epoch=source.src_epoch,
            source_bridge_execution_hash=source_execution_hash,
            destination_domain_id=destination_domain,
            destination_bridge=destination_bridge.bridge,
            destination_bridge_execution_hash=destination_execution_hash,
            destination_infrastructure_hash=infrastructure_hash, **common),
    )
    ingress_root = validate_ingress_authorization_set(
        ingress_rows,
        IngressProfileGraphV2(
            common["active_settlement_router"], common["router_runtime_hash"],
            common["router_configuration_hash"], common["forced_queue"],
            common["queue_runtime_hash"], common["queue_configuration_hash"],
            source_domain, source.src_epoch, source_execution_hash,
            destination_chain_id_, destination_domain,
            destination_bridge.bridge, destination_execution_hash,
            infrastructure_hash, address_word_value(words[228]), words[229],
            kind0_config, components[0].address, components[0].runtime_hash,
            components[0].config_hash))
    manifest = ReleaseManifestDescriptor(
        protocol_version, settlement_chain_id, destination_chain_id_, words[5],
        profile_hash, words[9], words[10], address_word_value(words[13]),
        words[14], destination_domain, destination_bridge.bridge,
        destination_execution_hash, destination_bridge, infrastructure_hash,
        migration_descriptor_hash, ingress_root, components[8].address,
        components[8].runtime_hash, components[8].config_hash, components)
    manifest_hash = release_manifest_hash(manifest)
    registration_hash = target_registration_v2_hash(
        expected_predecessor_protocol_version, manifest, deployment,
        activation.activation_profile_record_hash)
    return DerivedRegisterReleaseAuthorityV2(
        profile_hash, activation, migration_descriptor_hash,
        target_parameters_hash, target_artifact_hash, data_config_hash,
        deployment, source, source_domain, source_execution_hash, components,
        destination_bridge, destination_domain, destination_execution_hash,
        infrastructure_hash, ingress_rows, ingress_root, manifest,
        manifest_hash, registration_hash)


def encode_migration_activation_profile_calldata(
        protocol_version: int) -> bytes:
    assert 0 < protocol_version <= UINT64_MAX
    return MIGRATION_ACTIVATION_PROFILE_SELECTOR + u256(protocol_version)


def decode_migration_activation_profile_calldata(calldata: bytes) -> int:
    assert (len(calldata) == 36
            and calldata[:4] == MIGRATION_ACTIVATION_PROFILE_SELECTOR)
    protocol_version = uint_word_value(calldata[4:36], 64)
    assert calldata == encode_migration_activation_profile_calldata(
        protocol_version)
    return protocol_version


def encode_migration_activation_profile_return(
        record: MigrationActivationProfileRecordV2) -> bytes:
    assert record.activation_profile_record_hash \
        == migration_activation_profile_record_hash(record)
    encoded = (
        bytes4_word(MIGRATION_ACTIVATION_PROFILE_MAGIC)
        + u256(record.protocol_version) + b32(record.execution_profile_hash)
        + b32(record.activation_profile_record_hash)
        + address_word(record.verifier) + b32(record.verifier_runtime_hash)
        + b32(record.verifier_configuration_hash)
        + b32(record.verifying_key_hash) + b32(record.proof_system_id)
        + b32(record.public_input_schema_hash)
        + bytes4_word(record.verifier_selector)
        + u256(record.maximum_proof_bytes)
        + u256(record.verification_gas_limit)
        + u256(record.supported_l1_block_gas_limit)
        + u256(record.worst_case_activation_adoption_gas)
        + u256(record.source_freeze_gas_limit)
        + u256(record.target_adoption_gas_limit)
        + u256(record.queue_migration_gas_limit)
        + u256(record.activation_context_read_gas_limit)
        + u256(record.post_state_read_gas_limit)
        + u256(record.legacy_state_read_gas_limit)
        + u256(record.legacy_arm_gas_limit)
        + u256(record.legacy_finalize_gas_limit)
        + u256(record.post_callback_reserve_gas))
    assert len(encoded) == 768
    return encoded


def decode_migration_activation_profile_return(
        returndata: bytes) -> MigrationActivationProfileRecordV2:
    assert (len(returndata) == 768
            and bytes4_word_value(returndata[:32])
                == MIGRATION_ACTIVATION_PROFILE_MAGIC)
    words = tuple(returndata[index * 32:(index + 1) * 32]
                  for index in range(1, 24))
    record = MigrationActivationProfileRecordV2(
        uint_word_value(words[0], 64), b32(words[1]), b32(words[2]),
        address_word_value(words[3]), b32(words[4]), b32(words[5]),
        b32(words[6]), b32(words[7]), b32(words[8]),
        bytes4_word_value(words[9]), uint_word_value(words[10], 32),
        *(uint_word_value(words[index], 64) for index in range(11, 23)))
    assert returndata == encode_migration_activation_profile_return(record)
    return record


@dataclass(frozen=True)
class TargetReleaseRegistrationV2:
    protocol_version: int
    expected_predecessor_protocol_version: int
    target_settlement: int
    target_runtime_hash: bytes
    target_configuration_hash: bytes
    settlement_deployment_descriptor_hash: bytes
    execution_profile_hash: bytes
    migration_activation_profile_record_hash: bytes
    data_session_configuration_hash: bytes
    release_manifest_hash: bytes
    target_registration_hash: bytes


def encode_register_target_release_calldata(
        payload: RegisterReleasePayloadV1) -> bytes:
    encoded = REGISTER_TARGET_RELEASE_SELECTOR + encode_register_release_payload(
        payload)
    assert len(encoded) == 4 + 2_208 + ceil32(len(payload.profile_bytes))
    return encoded


def decode_register_target_release_calldata(
        calldata: bytes) -> RegisterReleasePayloadV1:
    assert calldata[:4] == REGISTER_TARGET_RELEASE_SELECTOR
    payload = decode_register_release_payload(calldata[4:])
    assert calldata == encode_register_target_release_calldata(payload)
    return payload


def encode_register_target_release_return(
        manifest_hash: bytes, target_registration_hash: bytes) -> bytes:
    assert (manifest_hash != bytes(32)
            and target_registration_hash != bytes(32))
    encoded = (bytes4_word(TARGET_RELEASE_REGISTRATION_MAGIC)
               + b32(manifest_hash) + b32(target_registration_hash))
    assert len(encoded) == 96
    return encoded


def decode_register_target_release_return(
        returndata: bytes) -> tuple[bytes, bytes]:
    assert (len(returndata) == 96
            and bytes4_word_value(returndata[:32])
                == TARGET_RELEASE_REGISTRATION_MAGIC)
    result = (b32(returndata[32:64]), b32(returndata[64:96]))
    assert returndata == encode_register_target_release_return(*result)
    return result


def encode_target_release_registration_calldata(
        protocol_version: int) -> bytes:
    assert 0 < protocol_version <= UINT64_MAX
    return TARGET_RELEASE_REGISTRATION_SELECTOR + u256(protocol_version)


def decode_target_release_registration_calldata(calldata: bytes) -> int:
    assert (len(calldata) == 36
            and calldata[:4] == TARGET_RELEASE_REGISTRATION_SELECTOR)
    protocol_version = uint_word_value(calldata[4:36], 64)
    assert calldata == encode_target_release_registration_calldata(
        protocol_version)
    return protocol_version


def encode_target_release_registration_return(
        registration: TargetReleaseRegistrationV2) -> bytes:
    assert (0 <= registration.expected_predecessor_protocol_version
            < registration.protocol_version <= UINT64_MAX
            and registration.target_settlement != 0
            and all(value != bytes(32) for value in (
                registration.target_runtime_hash,
                registration.target_configuration_hash,
                registration.settlement_deployment_descriptor_hash,
                registration.execution_profile_hash,
                registration.migration_activation_profile_record_hash,
                registration.data_session_configuration_hash,
                registration.release_manifest_hash,
                registration.target_registration_hash)))
    encoded = (
        bytes4_word(TARGET_RELEASE_REGISTRATION_MAGIC)
        + u256(registration.protocol_version)
        + u256(registration.expected_predecessor_protocol_version)
        + address_word(registration.target_settlement)
        + b32(registration.target_runtime_hash)
        + b32(registration.target_configuration_hash)
        + b32(registration.settlement_deployment_descriptor_hash)
        + b32(registration.execution_profile_hash)
        + b32(registration.migration_activation_profile_record_hash)
        + b32(registration.data_session_configuration_hash)
        + b32(registration.release_manifest_hash)
        + b32(registration.target_registration_hash))
    assert len(encoded) == 384
    return encoded


def decode_target_release_registration_return(
        returndata: bytes) -> TargetReleaseRegistrationV2:
    assert (len(returndata) == 384
            and bytes4_word_value(returndata[:32])
                == TARGET_RELEASE_REGISTRATION_MAGIC)
    registration = TargetReleaseRegistrationV2(
        uint_word_value(returndata[32:64], 64),
        uint_word_value(returndata[64:96], 64),
        address_word_value(returndata[96:128]), b32(returndata[128:160]),
        b32(returndata[160:192]), b32(returndata[192:224]),
        b32(returndata[224:256]), b32(returndata[256:288]),
        b32(returndata[288:320]), b32(returndata[320:352]),
        b32(returndata[352:384]))
    assert returndata == encode_target_release_registration_return(
        registration)
    return registration


def encode_register_fork_verifier_payload(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    assert (len(payload.fork_digest) == 4
            and payload.fork_digest != bytes(4)
            and 0 < payload.first_window <= UINT64_MAX
            and payload.verifier != 0 and payload.runtime_hash != bytes(32)
            and all(0 < value <= UINT64_MAX for value in (
                payload.beacon_slot_gindex,
                payload.execution_payload_gindex,
                payload.state_root_gindex, payload.prev_randao_gindex,
                payload.timestamp_gindex, payload.block_hash_gindex))
            and payload.witness_schema_hash != bytes(32)
            and payload.configuration_hash != bytes(32)
            and payload.selector == bytes.fromhex("7e981e0b")
            and MINIMUM_FORK_VERIFIER_GAS <= payload.gas_limit
                <= MAXIMUM_FORK_VERIFIER_GAS)
    assert payload.configuration_hash == schedule_fork_verifier_configuration_hash(
        payload)
    encoded = (
        bytes4_word(payload.fork_digest) + u256(payload.first_window)
        + address_word(payload.verifier) + b32(payload.runtime_hash)
        + u256(payload.beacon_slot_gindex)
        + u256(payload.execution_payload_gindex)
        + u256(payload.state_root_gindex) + u256(payload.prev_randao_gindex)
        + u256(payload.timestamp_gindex) + u256(payload.block_hash_gindex)
        + b32(payload.witness_schema_hash) + b32(payload.configuration_hash)
        + bytes4_word(payload.selector)
        + u256(payload.gas_limit))
    assert len(encoded) == 14 * 32
    return encoded


def decode_register_fork_verifier_payload(
        encoded: bytes) -> RegisterForkVerifierPayloadV1:
    assert len(encoded) == 14 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(14))
    payload = RegisterForkVerifierPayloadV1(
        bytes4_word_value(words[0]), uint_word_value(words[1], 64),
        address_word_value(words[2]), b32(words[3]),
        *(uint_word_value(words[index], 64) for index in range(4, 10)),
        b32(words[10]), b32(words[11]), bytes4_word_value(words[12]),
        uint_word_value(words[13], 64))
    assert encoded == encode_register_fork_verifier_payload(payload)
    return payload


@dataclass(frozen=True)
class ForkVerifierRegistrationV1:
    fork_digest: bytes
    first_window: int
    successor_fork_digest: bytes
    successor_first_window: int
    verifier: int
    runtime_hash: bytes
    configuration_hash: bytes
    selector: bytes
    gas_limit: int


@dataclass(frozen=True)
class ScheduleCarrierOutputV1:
    statement_hash: bytes
    parent_slot: int
    execution_block_number: int
    payload_timestamp: int
    block_hash: bytes
    state_root: bytes
    prev_randao: bytes


def schedule_fork_constants_hash(
        beacon_slot_gindex: int, execution_payload_gindex: int,
        state_root_gindex: int, prev_randao_gindex: int,
        timestamp_gindex: int, block_hash_gindex: int) -> bytes:
    values = (beacon_slot_gindex, execution_payload_gindex,
              state_root_gindex, prev_randao_gindex, timestamp_gindex,
              block_hash_gindex)
    assert all(0 < value <= UINT64_MAX for value in values)
    return keccak256(D_SCHEDULE_FORK_CONSTANTS
                     + b"".join(u64(value) for value in values))


def schedule_fork_output_schema_hash() -> bytes:
    return keccak256(SCHEDULE_FORK_OUTPUT_SCHEMA_LITERAL)


def schedule_fork_verifier_configuration_hash(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    assert (len(payload.fork_digest) == 4
            and payload.fork_digest != bytes(4)
            and payload.witness_schema_hash != bytes(32)
            and payload.selector == VERIFY_SCHEDULE_CARRIER_SELECTOR
            and MINIMUM_FORK_VERIFIER_GAS <= payload.gas_limit
                <= MAXIMUM_FORK_VERIFIER_GAS)
    constants_hash = schedule_fork_constants_hash(
        payload.beacon_slot_gindex, payload.execution_payload_gindex,
        payload.state_root_gindex, payload.prev_randao_gindex,
        payload.timestamp_gindex, payload.block_hash_gindex)
    return keccak256(
        D_SCHEDULE_FORK_VERIFIER_CONFIG + payload.fork_digest
        + constants_hash + b32(payload.witness_schema_hash)
        + schedule_fork_output_schema_hash() + payload.selector
        + u64(payload.gas_limit))


def encode_install_fork_verifier_calldata(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    encoded = INSTALL_FORK_VERIFIER_SELECTOR \
        + encode_register_fork_verifier_payload(payload)
    assert len(encoded) == 452
    return encoded


def decode_install_fork_verifier_calldata(
        calldata: bytes) -> RegisterForkVerifierPayloadV1:
    assert calldata[:4] == INSTALL_FORK_VERIFIER_SELECTOR
    payload = decode_register_fork_verifier_payload(calldata[4:])
    assert calldata == encode_install_fork_verifier_calldata(payload)
    return payload


def encode_install_fork_verifier_return(
        fork_digest: bytes, first_window: int) -> bytes:
    assert (len(fork_digest) == 4 and fork_digest != bytes(4)
            and 0 <= first_window <= UINT64_MAX)
    encoded = (bytes4_word(FORK_VERIFIER_INSTALL_MAGIC)
               + bytes4_word(fork_digest) + u256(first_window))
    assert len(encoded) == 96
    return encoded


def decode_install_fork_verifier_return(returndata: bytes) -> tuple[bytes, int]:
    assert (len(returndata) == 96
            and bytes4_word_value(returndata[:32])
                == FORK_VERIFIER_INSTALL_MAGIC)
    result = (bytes4_word_value(returndata[32:64]),
              uint_word_value(returndata[64:96], 64))
    assert returndata == encode_install_fork_verifier_return(*result)
    return result


def encode_fork_verifier_registration_calldata(fork_digest: bytes) -> bytes:
    assert len(fork_digest) == 4 and fork_digest != bytes(4)
    return FORK_VERIFIER_REGISTRATION_SELECTOR + bytes4_word(fork_digest)


def decode_fork_verifier_registration_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == FORK_VERIFIER_REGISTRATION_SELECTOR)
    fork_digest = bytes4_word_value(calldata[4:36])
    assert calldata == encode_fork_verifier_registration_calldata(fork_digest)
    return fork_digest


def encode_fork_verifier_registration_return(
        row: ForkVerifierRegistrationV1) -> bytes:
    assert (len(row.fork_digest) == 4 and row.fork_digest != bytes(4)
            and 0 <= row.first_window <= UINT64_MAX
            and row.verifier != 0 and row.runtime_hash != bytes(32)
            and row.configuration_hash != bytes(32)
            and row.selector == VERIFY_SCHEDULE_CARRIER_SELECTOR
            and MINIMUM_FORK_VERIFIER_GAS <= row.gas_limit
                <= MAXIMUM_FORK_VERIFIER_GAS)
    if row.successor_fork_digest == bytes(4):
        assert row.successor_first_window == 0
    else:
        assert (len(row.successor_fork_digest) == 4
                and row.successor_fork_digest != row.fork_digest
                and row.successor_first_window > row.first_window
                and row.successor_first_window <= UINT64_MAX)
    encoded = (
        bytes4_word(FORK_VERIFIER_REGISTRATION_MAGIC)
        + bytes4_word(row.fork_digest) + u256(row.first_window)
        + bytes4_word(row.successor_fork_digest)
        + u256(row.successor_first_window) + address_word(row.verifier)
        + b32(row.runtime_hash) + b32(row.configuration_hash)
        + bytes4_word(row.selector) + u256(row.gas_limit))
    assert len(encoded) == 320
    return encoded


def decode_fork_verifier_registration_return(
        returndata: bytes) -> ForkVerifierRegistrationV1:
    assert (len(returndata) == 320
            and bytes4_word_value(returndata[:32])
                == FORK_VERIFIER_REGISTRATION_MAGIC)
    row = ForkVerifierRegistrationV1(
        bytes4_word_value(returndata[32:64]),
        uint_word_value(returndata[64:96], 64),
        bytes4_word_value(returndata[96:128]),
        uint_word_value(returndata[128:160], 64),
        address_word_value(returndata[160:192]), b32(returndata[192:224]),
        b32(returndata[224:256]), bytes4_word_value(returndata[256:288]),
        uint_word_value(returndata[288:320], 64))
    assert returndata == encode_fork_verifier_registration_return(row)
    return row


def fork_verifier_registration_covers_window(
        row: ForkVerifierRegistrationV1, window: int) -> bool:
    assert 0 <= window <= UINT64_MAX
    encode_fork_verifier_registration_return(row)
    return (row.first_window <= window
            and (row.successor_fork_digest == bytes(4)
                 or window < row.successor_first_window))


def encode_schedule_fork_verifier_config_return(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    assert payload.configuration_hash \
        == schedule_fork_verifier_configuration_hash(payload)
    encoded = (
        bytes4_word(SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC)
        + bytes4_word(payload.fork_digest)
        + u256(payload.beacon_slot_gindex)
        + u256(payload.execution_payload_gindex)
        + u256(payload.state_root_gindex) + u256(payload.prev_randao_gindex)
        + u256(payload.timestamp_gindex) + u256(payload.block_hash_gindex)
        + b32(payload.witness_schema_hash) + b32(payload.configuration_hash))
    assert len(encoded) == 320
    return encoded


def decode_schedule_fork_verifier_config_return(
        returndata: bytes, verifier: int, runtime_hash: bytes,
        first_window: int, selector: bytes,
        gas_limit: int) -> RegisterForkVerifierPayloadV1:
    assert (len(returndata) == 320
            and bytes4_word_value(returndata[:32])
                == SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC)
    payload = RegisterForkVerifierPayloadV1(
        bytes4_word_value(returndata[32:64]), first_window, verifier,
        b32(runtime_hash),
        *(uint_word_value(returndata[index * 32:(index + 1) * 32], 64)
          for index in range(2, 8)),
        b32(returndata[256:288]), b32(returndata[288:320]), selector,
        gas_limit)
    assert returndata == encode_schedule_fork_verifier_config_return(payload)
    return payload


def encode_verify_schedule_carrier_calldata(
        witness: bytes, beacon_block_root: bytes) -> bytes:
    assert (1 <= len(witness) <= MAXIMUM_SCHEDULE_WITNESS_BYTES
            and beacon_block_root != bytes(32))
    encoded = (VERIFY_SCHEDULE_CARRIER_SELECTOR + u256(2 * 32)
               + b32(beacon_block_root) + abi_bytes_tail(witness))
    assert len(encoded) == 100 + ceil32(len(witness))
    return encoded


def decode_verify_schedule_carrier_calldata(
        calldata: bytes) -> tuple[bytes, bytes]:
    assert (len(calldata) >= 132
            and calldata[:4] == VERIFY_SCHEDULE_CARRIER_SELECTOR)
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 2 * 32
    beacon_block_root = b32(arguments[32:64])
    witness_length = uint_word_value(arguments[64:96])
    witness = arguments[96:96 + witness_length]
    result = (witness, beacon_block_root)
    assert calldata == encode_verify_schedule_carrier_calldata(*result)
    return result


def schedule_carrier_statement_hash(
        settlement_chain_id: int, schedule_oracle: int, fork_digest: bytes,
        window: int, beacon_block_root: bytes, parent_slot: int,
        execution_block_number: int, payload_timestamp: int,
        block_hash: bytes, state_root: bytes, prev_randao: bytes) -> bytes:
    narrow = (window, parent_slot, execution_block_number, payload_timestamp)
    assert (settlement_chain_id > 0 and schedule_oracle != 0
            and len(fork_digest) == 4 and fork_digest != bytes(4)
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and all(value != bytes(32) for value in (
                beacon_block_root, block_hash, state_root, prev_randao)))
    return keccak256(
        D_SCHEDULE_CARRIER_STATEMENT + u256(settlement_chain_id)
        + address20(schedule_oracle) + fork_digest + u64(window)
        + b32(beacon_block_root) + u64(parent_slot)
        + u64(execution_block_number) + u64(payload_timestamp)
        + b32(block_hash) + b32(state_root) + b32(prev_randao))


def encode_schedule_carrier_return(output: ScheduleCarrierOutputV1) -> bytes:
    assert (output.statement_hash != bytes(32)
            and all(0 <= value <= UINT64_MAX for value in (
                output.parent_slot, output.execution_block_number,
                output.payload_timestamp))
            and all(value != bytes(32) for value in (
                output.block_hash, output.state_root, output.prev_randao)))
    encoded = (
        bytes4_word(SCHEDULE_FORK_CARRIER_MAGIC) + b32(output.statement_hash)
        + u256(output.parent_slot) + u256(output.execution_block_number)
        + u256(output.payload_timestamp) + b32(output.block_hash)
        + b32(output.state_root) + b32(output.prev_randao))
    assert len(encoded) == 256
    return encoded


def decode_schedule_carrier_return(
        returndata: bytes, expected_statement_hash: bytes
        | None = None) -> ScheduleCarrierOutputV1:
    assert (len(returndata) == 256
            and bytes4_word_value(returndata[:32])
                == SCHEDULE_FORK_CARRIER_MAGIC)
    output = ScheduleCarrierOutputV1(
        b32(returndata[32:64]), uint_word_value(returndata[64:96], 64),
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64), b32(returndata[160:192]),
        b32(returndata[192:224]), b32(returndata[224:256]))
    if expected_statement_hash is not None:
        assert output.statement_hash == expected_statement_hash
    assert returndata == encode_schedule_carrier_return(output)
    return output


def schedule_unsealed_window_is_vacant(
        is_sealed: bool, block_timestamp: int, seal_deadline: int) -> bool:
    assert (0 <= block_timestamp <= UINT64_MAX
            and 0 <= seal_deadline <= UINT64_MAX)
    return not is_sealed and block_timestamp >= seal_deadline


def encode_publish_genesis_campaign_payload(
        payload: PublishGenesisCampaignPayloadV1) -> bytes:
    block_values = (
        payload.force_cutoff_block, payload.proposal_cutoff_block,
        payload.quiesce_not_before_block, payload.resume_by_block,
        payload.resume_by_timestamp, payload.review_finalized_by_block,
        payload.target_protocol_version)
    assert (all(0 < value <= UINT64_MAX for value in block_values)
            and payload.target_settlement != 0
            and payload.target_manifest_hash != bytes(32)
            and payload.target_registration_hash != bytes(32))
    encoded = (
        u256(payload.force_cutoff_block) + u256(payload.proposal_cutoff_block)
        + u256(payload.quiesce_not_before_block) + u256(payload.resume_by_block)
        + u256(payload.resume_by_timestamp)
        + u256(payload.review_finalized_by_block)
        + address_word(payload.target_settlement)
        + u256(payload.target_protocol_version)
        + b32(payload.target_manifest_hash)
        + b32(payload.target_registration_hash))
    assert len(encoded) == 10 * 32
    return encoded


def decode_publish_genesis_campaign_payload(
        encoded: bytes) -> PublishGenesisCampaignPayloadV1:
    assert len(encoded) == 10 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(10))
    payload = PublishGenesisCampaignPayloadV1(
        *(uint_word_value(words[index], 64) for index in range(6)),
        address_word_value(words[6]), uint_word_value(words[7], 64),
        b32(words[8]), b32(words[9]))
    assert encoded == encode_publish_genesis_campaign_payload(payload)
    return payload


def encode_publish_migration_arm_payload(
        payload: PublishMigrationArmPayloadV1) -> bytes:
    assert (0 < payload.expected_source_protocol_version
            < payload.target_protocol_version <= UINT64_MAX
            and payload.target_manifest_hash != bytes(32)
            and payload.target_registration_hash != bytes(32))
    encoded = (
        u256(payload.expected_source_protocol_version)
        + u256(payload.target_protocol_version)
        + b32(payload.target_manifest_hash)
        + b32(payload.target_registration_hash))
    assert len(encoded) == 4 * 32
    return encoded


def decode_publish_migration_arm_payload(
        encoded: bytes) -> PublishMigrationArmPayloadV1:
    assert len(encoded) == 4 * 32
    payload = PublishMigrationArmPayloadV1(
        uint_word_value(encoded[:32], 64),
        uint_word_value(encoded[32:64], 64), b32(encoded[64:96]),
        b32(encoded[96:128]))
    assert encoded == encode_publish_migration_arm_payload(payload)
    return payload


def encode_publish_legacy_genesis_campaign_calldata(
        operation_id: bytes, execute_after: int,
        payload: PublishGenesisCampaignPayloadV1) -> bytes:
    assert (operation_id != bytes(32) and 0 < execute_after <= UINT64_MAX)
    encoded = (
        PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR + b32(operation_id)
        + u256(execute_after) + encode_publish_genesis_campaign_payload(payload))
    assert len(encoded) == 388
    return encoded


def decode_publish_legacy_genesis_campaign_calldata(
        calldata: bytes) -> tuple[bytes, int, PublishGenesisCampaignPayloadV1]:
    assert (len(calldata) == 388
            and calldata[:4] == PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR)
    result = (
        b32(calldata[4:36]), uint_word_value(calldata[36:68], 64),
        decode_publish_genesis_campaign_payload(calldata[68:388]))
    assert calldata == encode_publish_legacy_genesis_campaign_calldata(*result)
    return result


def encode_publish_legacy_genesis_campaign_return(
        nonce: int, generation: int, review_commitment: bytes,
        campaign_id: bytes) -> bytes:
    assert (0 < nonce <= UINT64_MAX and 0 < generation <= UINT64_MAX
            and review_commitment != bytes(32) and campaign_id != bytes(32))
    encoded = (
        bytes4_word(LEGACY_GENESIS_PUBLISH_MAGIC) + u256(nonce)
        + u256(generation) + b32(review_commitment) + b32(campaign_id))
    assert len(encoded) == 160
    return encoded


def decode_publish_legacy_genesis_campaign_return(
        returndata: bytes) -> tuple[int, int, bytes, bytes]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == LEGACY_GENESIS_PUBLISH_MAGIC)
    result = (
        uint_word_value(returndata[32:64], 64),
        uint_word_value(returndata[64:96], 64), b32(returndata[96:128]),
        b32(returndata[128:160]))
    assert returndata == encode_publish_legacy_genesis_campaign_return(*result)
    return result


def encode_arm_version_migration_calldata(
        operation_id: bytes, lease: VersionMigrationLeaseV1) -> bytes:
    assert operation_id != bytes(32) and lease.state == 1
    encoded = (
        ARM_VERSION_MIGRATION_SELECTOR + b32(operation_id) + b32(lease.arm_id)
        + u256(lease.armed_at_timestamp) + u256(lease.abort_after_timestamp)
        + u256(lease.source_protocol_version)
        + u256(lease.target_protocol_version)
        + b32(lease.target_manifest_hash)
        + b32(lease.target_registration_hash))
    assert len(encoded) == 260
    return encoded


def decode_arm_version_migration_calldata(
        calldata: bytes) -> tuple[bytes, bytes, int, int, int, int, bytes, bytes]:
    assert (len(calldata) == 260
            and calldata[:4] == ARM_VERSION_MIGRATION_SELECTOR)
    operation_id = b32(calldata[4:36])
    result = (
        operation_id, b32(calldata[36:68]),
        uint_word_value(calldata[68:100], 64),
        uint_word_value(calldata[100:132], 64),
        uint_word_value(calldata[132:164], 64),
        uint_word_value(calldata[164:196], 64), b32(calldata[196:228]),
        b32(calldata[228:260]))
    reconstructed_lease = VersionMigrationLeaseV1(
        1, 1, result[4], result[5], result[6], result[7], result[1],
        result[2], result[3])
    assert calldata == encode_arm_version_migration_calldata(
        operation_id, reconstructed_lease)
    return result


def encode_arm_version_migration_return(
        generation: int, arm_id: bytes) -> bytes:
    assert 0 < generation <= UINT64_MAX and arm_id != bytes(32)
    encoded = (bytes4_word(VERSION_MIGRATION_ARM_MAGIC) + u256(generation)
               + b32(arm_id))
    assert len(encoded) == 96
    return encoded


def decode_arm_version_migration_return(
        returndata: bytes) -> tuple[int, bytes]:
    assert (len(returndata) == 96
            and bytes4_word_value(returndata[:32])
                == VERSION_MIGRATION_ARM_MAGIC)
    result = (uint_word_value(returndata[32:64], 64),
              b32(returndata[64:96]))
    assert returndata == encode_arm_version_migration_return(*result)
    return result


def encode_abort_expired_version_migration_calldata(arm_id: bytes) -> bytes:
    assert arm_id != bytes(32)
    return ABORT_EXPIRED_VERSION_MIGRATION_SELECTOR + b32(arm_id)


def decode_abort_expired_version_migration_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == ABORT_EXPIRED_VERSION_MIGRATION_SELECTOR)
    arm_id = b32(calldata[4:36])
    assert calldata == encode_abort_expired_version_migration_calldata(arm_id)
    return arm_id


def encode_abort_expired_version_migration_return(
        arm_id: bytes, generation: int) -> bytes:
    assert arm_id != bytes(32) and 0 < generation <= UINT64_MAX
    encoded = (bytes4_word(VERSION_MIGRATION_ABORT_MAGIC) + b32(arm_id)
               + u256(generation))
    assert len(encoded) == 96
    return encoded


def decode_abort_expired_version_migration_return(
        returndata: bytes) -> tuple[bytes, int]:
    assert (len(returndata) == 96
            and bytes4_word_value(returndata[:32])
                == VERSION_MIGRATION_ABORT_MAGIC)
    result = (b32(returndata[32:64]),
              uint_word_value(returndata[64:96], 64))
    assert returndata == encode_abort_expired_version_migration_return(*result)
    return result


def protocol_control_plane_entry_allowed(
        manager_lifecycle: int, router_lifecycle: int) -> bool:
    assert 0 <= manager_lifecycle <= 2 and 0 <= router_lifecycle <= 6
    return manager_lifecycle == 0 and router_lifecycle == 0


def validate_protocol_change_payload(operation_kind: int, payload: bytes):
    decoders = {
        1: decode_register_release_payload,
        2: decode_register_fork_verifier_payload,
        3: decode_publish_genesis_campaign_payload,
        4: decode_publish_migration_arm_payload,
    }
    assert operation_kind in decoders
    return decoders[operation_kind](payload)


def _encode_protocol_change_dynamic_calldata(
        selector: bytes, nonce: int | None, operation_kind: int,
        payload: bytes) -> bytes:
    validate_protocol_change_payload(operation_kind, payload)
    assert nonce is None or 0 < nonce <= UINT64_MAX
    head = ((u256(operation_kind) + u256(2 * 32)) if nonce is None else
            (u256(nonce) + u256(operation_kind) + u256(3 * 32)))
    encoded = selector + head + abi_bytes_tail(payload)
    expected = 4 + len(head) + 32 + ceil32(len(payload))
    assert len(encoded) == expected
    return encoded


def _decode_protocol_change_dynamic_calldata(
        calldata: bytes, selector: bytes,
        has_nonce: bool) -> tuple[int | None, int, bytes]:
    head_words = 3 if has_nonce else 2
    minimum = 4 + (head_words + 1) * 32
    assert len(calldata) >= minimum and calldata[:4] == selector
    arguments = calldata[4:]
    if has_nonce:
        nonce = uint_word_value(arguments[:32], 64)
        operation_kind = uint_word_value(arguments[32:64], 8)
        assert uint_word_value(arguments[64:96]) == 3 * 32
    else:
        nonce = None
        operation_kind = uint_word_value(arguments[:32], 8)
        assert uint_word_value(arguments[32:64]) == 2 * 32
    payload_length_offset = head_words * 32
    payload_length = uint_word_value(
        arguments[payload_length_offset:payload_length_offset + 32])
    payload_start = payload_length_offset + 32
    payload = arguments[payload_start:payload_start + payload_length]
    result = (nonce, operation_kind, payload)
    assert calldata == _encode_protocol_change_dynamic_calldata(
        selector, *result)
    return result


def encode_queue_protocol_change_calldata(
        operation_kind: int, payload: bytes) -> bytes:
    return _encode_protocol_change_dynamic_calldata(
        QUEUE_PROTOCOL_CHANGE_SELECTOR, None, operation_kind, payload)


def decode_queue_protocol_change_calldata(
        calldata: bytes) -> tuple[int, bytes]:
    nonce, operation_kind, payload = _decode_protocol_change_dynamic_calldata(
        calldata, QUEUE_PROTOCOL_CHANGE_SELECTOR, False)
    assert nonce is None
    return operation_kind, payload


def encode_execute_protocol_change_calldata(
        nonce: int, operation_kind: int, payload: bytes) -> bytes:
    return _encode_protocol_change_dynamic_calldata(
        EXECUTE_PROTOCOL_CHANGE_SELECTOR, nonce, operation_kind, payload)


def decode_execute_protocol_change_calldata(
        calldata: bytes) -> tuple[int, int, bytes]:
    nonce, operation_kind, payload = _decode_protocol_change_dynamic_calldata(
        calldata, EXECUTE_PROTOCOL_CHANGE_SELECTOR, True)
    assert nonce is not None
    return nonce, operation_kind, payload


def encode_cancel_protocol_change_calldata(
        nonce: int, operation_kind: int, payload: bytes) -> bytes:
    return _encode_protocol_change_dynamic_calldata(
        CANCEL_PROTOCOL_CHANGE_SELECTOR, nonce, operation_kind, payload)


def decode_cancel_protocol_change_calldata(
        calldata: bytes) -> tuple[int, int, bytes]:
    nonce, operation_kind, payload = _decode_protocol_change_dynamic_calldata(
        calldata, CANCEL_PROTOCOL_CHANGE_SELECTOR, True)
    assert nonce is not None
    return nonce, operation_kind, payload


def encode_apply_protocol_change_calldata(
        nonce: int, operation_kind: int, payload: bytes) -> bytes:
    return _encode_protocol_change_dynamic_calldata(
        APPLY_PROTOCOL_CHANGE_SELECTOR, nonce, operation_kind, payload)


def decode_apply_protocol_change_calldata(
        calldata: bytes) -> tuple[int, int, bytes]:
    nonce, operation_kind, payload = _decode_protocol_change_dynamic_calldata(
        calldata, APPLY_PROTOCOL_CHANGE_SELECTOR, True)
    assert nonce is not None
    return nonce, operation_kind, payload


@dataclass(frozen=True)
class CanonicalCoreV2:
    l2_block_number: int
    tip_hash: bytes
    tip_slot: int
    state_root: bytes
    message_cursor: int
    winning_data_commitment: bytes
    next_base_fee: int
    next_excess_blob_gas: int
    terminal_root: bytes
    terminal_count: int


def canonical_core_v2_abi(core: CanonicalCoreV2) -> bytes:
    assert (0 <= core.l2_block_number < 1 << 48
            and 0 <= core.tip_slot <= UINT64_MAX
            and 0 <= core.message_cursor <= UINT64_MAX
            and 0 <= core.next_excess_blob_gas <= UINT64_MAX
            and 0 <= core.terminal_count <= UINT64_MAX)
    encoded = (
        u256(core.l2_block_number) + b32(core.tip_hash) + u256(core.tip_slot)
        + b32(core.state_root) + u256(core.message_cursor)
        + b32(core.winning_data_commitment) + u256(core.next_base_fee)
        + u256(core.next_excess_blob_gas) + b32(core.terminal_root)
        + u256(core.terminal_count)
    )
    assert len(encoded) == 10 * 32
    return encoded


def decode_canonical_core_v2_abi(encoded: bytes) -> CanonicalCoreV2:
    assert len(encoded) == 10 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(10))
    core = CanonicalCoreV2(
        uint_word_value(words[0], 48), b32(words[1]),
        uint_word_value(words[2], 64), b32(words[3]),
        uint_word_value(words[4], 64), b32(words[5]),
        uint_word_value(words[6]), uint_word_value(words[7], 64),
        b32(words[8]), uint_word_value(words[9], 64))
    assert encoded == canonical_core_v2_abi(core)
    return core


def canonical_core_v2_hash(core: CanonicalCoreV2) -> bytes:
    return canonical_core(
        core.l2_block_number, core.tip_hash, core.tip_slot, core.state_root,
        core.message_cursor, core.winning_data_commitment,
        core.next_base_fee, core.next_excess_blob_gas, core.terminal_root,
        core.terminal_count)


def canonical_settlement_deployment_descriptor_packed(
        descriptor: SettlementDeploymentDescriptorV1) -> bytes:
    assert (descriptor.factory != 0
            and descriptor.factory_runtime_hash != bytes(32)
            and descriptor.factory_configuration_hash != bytes(32)
            and descriptor.salt != bytes(32)
            and descriptor.init_code_hash != bytes(32)
            and descriptor.target_settlement != 0
            and descriptor.target_runtime_hash != bytes(32)
            and descriptor.target_configuration_hash != bytes(32)
            and descriptor.target_settlement == create2_address(
                descriptor.factory, descriptor.salt,
                descriptor.init_code_hash))
    encoded = (
        address20(descriptor.factory) + b32(descriptor.factory_runtime_hash)
        + b32(descriptor.factory_configuration_hash) + b32(descriptor.salt)
        + b32(descriptor.init_code_hash)
        + address20(descriptor.target_settlement)
        + b32(descriptor.target_runtime_hash)
        + b32(descriptor.target_configuration_hash))
    assert len(encoded) == 232
    return encoded


def settlement_deployment_descriptor_hash(
        descriptor: SettlementDeploymentDescriptorV1) -> bytes:
    encoded = canonical_settlement_deployment_descriptor_packed(descriptor)
    return keccak256(D_SETTLEMENT_DEPLOYMENT + u32(len(encoded)) + encoded)


def encode_settlement_deployment_descriptor_abi(
        descriptor: SettlementDeploymentDescriptorV1) -> bytes:
    canonical_settlement_deployment_descriptor_packed(descriptor)
    encoded = (
        address_word(descriptor.factory) + b32(descriptor.factory_runtime_hash)
        + b32(descriptor.factory_configuration_hash) + b32(descriptor.salt)
        + b32(descriptor.init_code_hash)
        + address_word(descriptor.target_settlement)
        + b32(descriptor.target_runtime_hash)
        + b32(descriptor.target_configuration_hash))
    assert len(encoded) == 8 * 32
    return encoded


def decode_settlement_deployment_descriptor_abi(
        encoded: bytes) -> SettlementDeploymentDescriptorV1:
    assert len(encoded) == 8 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(8))
    descriptor = SettlementDeploymentDescriptorV1(
        address_word_value(words[0]), b32(words[1]), b32(words[2]),
        b32(words[3]), b32(words[4]), address_word_value(words[5]),
        b32(words[6]), b32(words[7]))
    assert encoded == encode_settlement_deployment_descriptor_abi(descriptor)
    return descriptor


def fixture_settlement_deployment_descriptors() -> tuple[
        SettlementDeploymentDescriptorV1,
        SettlementDeploymentDescriptorV1]:
    factory = 0xFA01
    first_salt = bytes.fromhex("92" * 32)
    first_init_code_hash = bytes.fromhex("93" * 32)
    second_salt = bytes.fromhex("96" * 32)
    second_init_code_hash = bytes.fromhex("97" * 32)
    first = SettlementDeploymentDescriptorV1(
        factory, bytes.fromhex("90" * 32), bytes.fromhex("91" * 32),
        first_salt, first_init_code_hash,
        create2_address(factory, first_salt, first_init_code_hash),
        bytes.fromhex("94" * 32), bytes.fromhex("95" * 32))
    second = SettlementDeploymentDescriptorV1(
        factory, bytes.fromhex("90" * 32), bytes.fromhex("91" * 32),
        second_salt, second_init_code_hash,
        create2_address(factory, second_salt, second_init_code_hash),
        bytes.fromhex("98" * 32), bytes.fromhex("99" * 32))
    canonical_settlement_deployment_descriptor_packed(first)
    canonical_settlement_deployment_descriptor_packed(second)
    return first, second


def migration_target_sequence(transition_kind: int,
                              source_canonical_sequence: int) -> int:
    assert transition_kind in (1, 2)
    assert 0 <= source_canonical_sequence <= UINT64_MAX
    if transition_kind == 1:
        return 0
    assert source_canonical_sequence < UINT64_MAX
    return source_canonical_sequence + 1


def migration_adoption_commitment(
        settlement_chain_id: int, router: int, target_settlement: int,
        activation_context_hash: bytes,
        transition_kind: int, migration_generation: int,
        source_protocol_version: int, target_protocol_version: int,
        source_canonical_sequence: int, target_manifest_hash: bytes,
        candidate_digest: bytes, output_core: CanonicalCoreV2,
        activated_at_block: int) -> bytes:
    target_sequence = migration_target_sequence(
        transition_kind, source_canonical_sequence)
    narrow = (migration_generation, source_protocol_version,
              target_protocol_version, source_canonical_sequence,
              target_sequence, activated_at_block)
    assert (settlement_chain_id > 0 and router != 0 and target_settlement != 0
            and activation_context_hash != bytes(32)
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and target_manifest_hash != bytes(32)
            and candidate_digest != bytes(32))
    return keccak256(
        D_L1_ADOPTION + u256(settlement_chain_id) + address20(router)
        + address20(target_settlement) + b32(activation_context_hash)
        + u8(transition_kind)
        + u64(migration_generation) + u64(source_protocol_version)
        + u64(target_protocol_version) + u64(source_canonical_sequence)
        + b32(target_manifest_hash) + b32(candidate_digest)
        + canonical_core_v2_hash(output_core) + u64(target_sequence)
        + u64(activated_at_block))


def migration_activation_context_hash(
        settlement_chain_id: int, router: int, transition_kind: int,
        migration_generation: int, source_protocol_version: int,
        target_protocol_version: int, source_manifest_hash: bytes,
        target_manifest_hash: bytes, target_registration_hash: bytes,
        source_settlement: int, target_settlement: int,
        source_canonical_sequence: int, base_canonical_hash: bytes,
        statement_hash: bytes, candidate_digest: bytes,
        output_core: CanonicalCoreV2, forced_queue: int, queue_root: bytes,
        queue_count: int, start_cursor: int, end_cursor: int,
        proof_beneficiary: int, activated_at_block: int) -> bytes:
    target_sequence = migration_target_sequence(
        transition_kind, source_canonical_sequence)
    narrow = (migration_generation, source_protocol_version,
              target_protocol_version, source_canonical_sequence,
              target_sequence, queue_count, start_cursor, end_cursor,
              activated_at_block)
    assert (settlement_chain_id > 0 and router != 0 and target_settlement != 0
            and forced_queue != 0 and proof_beneficiary != 0
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and start_cursor <= end_cursor <= queue_count
            and source_manifest_hash != bytes(32)
            and target_manifest_hash != bytes(32)
            and target_registration_hash != bytes(32)
            and base_canonical_hash != bytes(32)
            and statement_hash != bytes(32) and candidate_digest != bytes(32)
            and queue_root != bytes(32))
    return keccak256(
        D_L1_ACTIVATION_CONTEXT + u256(settlement_chain_id)
        + address20(router) + u8(transition_kind)
        + u64(migration_generation) + u64(source_protocol_version)
        + u64(target_protocol_version) + b32(source_manifest_hash)
        + b32(target_manifest_hash) + b32(target_registration_hash)
        + address20(source_settlement) + address20(target_settlement)
        + u64(source_canonical_sequence) + b32(base_canonical_hash)
        + b32(statement_hash) + b32(candidate_digest)
        + canonical_core_v2_hash(output_core) + u64(target_sequence)
        + address20(forced_queue) + b32(queue_root) + u64(queue_count)
        + u64(start_cursor) + u64(end_cursor) + address20(proof_beneficiary)
        + u64(activated_at_block))


def source_freeze_post_state_commitment(
        activation_context_hash: bytes, source_settlement: int,
        generation: int, source_protocol_version: int,
        source_canonical_sequence: int, base_canonical_hash: bytes,
        frozen_at_block: int) -> bytes:
    narrow = (generation, source_protocol_version,
              source_canonical_sequence, frozen_at_block)
    assert (activation_context_hash != bytes(32) and source_settlement != 0
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and base_canonical_hash != bytes(32))
    return keccak256(
        D_SOURCE_FREEZE_POSTSTATE + b32(activation_context_hash)
        + address20(source_settlement) + u8(4) + u64(generation)
        + u64(source_protocol_version) + u64(source_canonical_sequence)
        + b32(base_canonical_hash) + u64(frozen_at_block))


def queue_migration_post_state_commitment(
        activation_context_hash: bytes, queue: int, target_settlement: int,
        queue_root: bytes, queue_count: int, end_cursor: int,
        proof_beneficiary: int, credited_wei: int,
        post_accounted_liability_wei: int,
        post_total_pull_claimable_wei: int) -> bytes:
    assert (activation_context_hash != bytes(32) and queue != 0
            and target_settlement != 0 and queue_root != bytes(32)
            and 0 <= end_cursor <= queue_count <= UINT64_MAX
            and proof_beneficiary != 0 and credited_wei >= 0
            and post_accounted_liability_wei >= 0
            and post_total_pull_claimable_wei >= 0)
    return keccak256(
        D_QUEUE_MIGRATION_POSTSTATE + b32(activation_context_hash)
        + address20(queue) + address20(target_settlement) + b32(queue_root)
        + u64(queue_count) + u64(end_cursor) + address20(proof_beneficiary)
        + u256(credited_wei) + u256(post_accounted_liability_wei)
        + u256(post_total_pull_claimable_wei))


def encode_adopt_migration_canonical_calldata(
        transition_kind: int, migration_generation: int,
        source_protocol_version: int, target_protocol_version: int,
        source_canonical_sequence: int, target_manifest_hash: bytes,
        candidate_digest: bytes, output_core: CanonicalCoreV2) -> bytes:
    migration_target_sequence(transition_kind, source_canonical_sequence)
    encoded = (
        ADOPT_MIGRATION_CANONICAL_SELECTOR + u256(transition_kind)
        + u256(migration_generation) + u256(source_protocol_version)
        + u256(target_protocol_version) + u256(source_canonical_sequence)
        + b32(target_manifest_hash) + b32(candidate_digest)
        + canonical_core_v2_abi(output_core)
    )
    assert len(encoded) == 548
    return encoded


def decode_adopt_migration_canonical_calldata(
        calldata: bytes
) -> tuple[int, int, int, int, int, bytes, bytes, CanonicalCoreV2]:
    assert (len(calldata) == 548
            and calldata[:4] == ADOPT_MIGRATION_CANONICAL_SELECTOR)
    arguments = calldata[4:]
    result = (
        uint_word_value(arguments[0:32], 8),
        uint_word_value(arguments[32:64], 64),
        uint_word_value(arguments[64:96], 64),
        uint_word_value(arguments[96:128], 64),
        uint_word_value(arguments[128:160], 64),
        b32(arguments[160:192]), b32(arguments[192:224]),
        decode_canonical_core_v2_abi(arguments[224:544]),
    )
    migration_target_sequence(result[0], result[4])
    assert calldata == encode_adopt_migration_canonical_calldata(*result)
    return result


def encode_migration_canonical_return(sequence: int,
                                      post_state_commitment: bytes) -> bytes:
    assert 0 <= sequence <= UINT64_MAX and post_state_commitment != bytes(32)
    return (bytes4_word(MIGRATION_CANONICAL_MAGIC) + u256(sequence)
            + b32(post_state_commitment))


def decode_migration_canonical_return(returndata: bytes) -> tuple[int, bytes]:
    assert len(returndata) == 96
    assert bytes4_word_value(returndata[:32]) == MIGRATION_CANONICAL_MAGIC
    result = (uint_word_value(returndata[32:64], 64),
              b32(returndata[64:96]))
    assert returndata == encode_migration_canonical_return(*result)
    return result


def encode_freeze_migration_source_calldata(
        activation_context_hash: bytes) -> bytes:
    assert activation_context_hash != bytes(32)
    return FREEZE_MIGRATION_SOURCE_SELECTOR + b32(activation_context_hash)


def decode_freeze_migration_source_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == FREEZE_MIGRATION_SOURCE_SELECTOR)
    result = b32(calldata[4:36])
    assert calldata == encode_freeze_migration_source_calldata(result)
    return result


def encode_migration_freeze_return(
        activation_context_hash: bytes, post_state_commitment: bytes) -> bytes:
    assert (activation_context_hash != bytes(32)
            and post_state_commitment != bytes(32))
    return (bytes4_word(MIGRATION_FREEZE_MAGIC)
            + b32(activation_context_hash) + b32(post_state_commitment))


def decode_migration_freeze_return(
        returndata: bytes) -> tuple[bytes, bytes]:
    assert len(returndata) == 96
    assert bytes4_word_value(returndata[:32]) == MIGRATION_FREEZE_MAGIC
    result = (b32(returndata[32:64]), b32(returndata[64:96]))
    assert returndata == encode_migration_freeze_return(*result)
    return result


def encode_queue_migration_calldata(
        activation_context_hash: bytes, source_settlement: int,
        target_settlement: int, expected_root: bytes, expected_count: int,
        start_cursor: int, end_cursor: int, proof_beneficiary: int) -> bytes:
    assert (activation_context_hash != bytes(32)
            and source_settlement != target_settlement
            and target_settlement != 0 and expected_root != bytes(32)
            and 0 <= start_cursor <= end_cursor <= expected_count <= UINT64_MAX
            and proof_beneficiary != 0)
    encoded = (
        MIGRATE_ACTIVE_SETTLEMENT_SELECTOR + b32(activation_context_hash)
        + address_word(source_settlement) + address_word(target_settlement)
        + b32(expected_root) + u256(expected_count) + u256(start_cursor)
        + u256(end_cursor) + address_word(proof_beneficiary)
    )
    assert len(encoded) == 260
    return encoded


def encode_queue_migration_return(
        activation_context_hash: bytes, credited_wei: int,
        post_state_commitment: bytes) -> bytes:
    assert (activation_context_hash != bytes(32) and credited_wei >= 0
            and post_state_commitment != bytes(32))
    return (bytes4_word(QUEUE_MIGRATION_MAGIC) + b32(activation_context_hash)
            + u256(credited_wei) + b32(post_state_commitment))


def decode_queue_migration_calldata(
        calldata: bytes
) -> tuple[bytes, int, int, bytes, int, int, int, int]:
    assert (len(calldata) == 260
            and calldata[:4] == MIGRATE_ACTIVE_SETTLEMENT_SELECTOR)
    arguments = calldata[4:]
    result = (
        b32(arguments[0:32]), address_word_value(arguments[32:64]),
        address_word_value(arguments[64:96]), b32(arguments[96:128]),
        uint_word_value(arguments[128:160], 64),
        uint_word_value(arguments[160:192], 64),
        uint_word_value(arguments[192:224], 64),
        address_word_value(arguments[224:256]),
    )
    assert calldata == encode_queue_migration_calldata(*result)
    return result


def decode_queue_migration_return(
        returndata: bytes) -> tuple[bytes, int, bytes]:
    assert len(returndata) == 128
    assert bytes4_word_value(returndata[:32]) == QUEUE_MIGRATION_MAGIC
    result = (b32(returndata[32:64]), uint_word_value(returndata[64:96]),
              b32(returndata[96:128]))
    assert returndata == encode_queue_migration_return(*result)
    return result


def encode_migration_post_state_calldata(
        activation_context_hash: bytes) -> bytes:
    assert activation_context_hash != bytes(32)
    return (MIGRATION_ACTIVATION_POST_STATE_SELECTOR
            + b32(activation_context_hash))


def decode_migration_post_state_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == MIGRATION_ACTIVATION_POST_STATE_SELECTOR)
    result = b32(calldata[4:36])
    assert calldata == encode_migration_post_state_calldata(result)
    return result


def encode_migration_post_state_return(
        role: int, activation_context_hash: bytes,
        post_state_commitment: bytes) -> bytes:
    assert (role in (1, 2, 3) and activation_context_hash != bytes(32)
            and post_state_commitment != bytes(32))
    return (bytes4_word(MIGRATION_ACTIVATION_POST_STATE_MAGIC) + u256(role)
            + b32(activation_context_hash) + b32(post_state_commitment))


def decode_migration_post_state_return(
        returndata: bytes) -> tuple[int, bytes, bytes]:
    assert len(returndata) == 128
    assert (bytes4_word_value(returndata[:32])
            == MIGRATION_ACTIVATION_POST_STATE_MAGIC)
    result = (uint_word_value(returndata[32:64], 8),
              b32(returndata[64:96]), b32(returndata[96:128]))
    assert returndata == encode_migration_post_state_return(*result)
    return result


def encode_migration_activation_context_return(
        lifecycle: int, activation_context_hash: bytes,
        source_settlement: int, target_settlement: int, generation: int,
        source_protocol_version: int, target_protocol_version: int,
        target_manifest_hash: bytes, target_registration_hash: bytes) -> bytes:
    assert lifecycle in range(5)
    if lifecycle == 4:
        assert (activation_context_hash != bytes(32)
                and target_settlement != 0
                and 0 <= generation <= UINT64_MAX
                and 0 <= source_protocol_version <= UINT64_MAX
                and 0 < target_protocol_version <= UINT64_MAX
                and target_manifest_hash != bytes(32)
                and target_registration_hash != bytes(32))
    else:
        assert (activation_context_hash == bytes(32)
                and source_settlement == 0 and target_settlement == 0
                and generation == 0 and source_protocol_version == 0
                and target_protocol_version == 0
                and target_manifest_hash == bytes(32)
                and target_registration_hash == bytes(32))
    encoded = (
        bytes4_word(MIGRATION_ACTIVATION_CONTEXT_MAGIC) + u256(lifecycle)
        + b32(activation_context_hash) + address_word(source_settlement)
        + address_word(target_settlement) + u256(generation)
        + u256(source_protocol_version) + u256(target_protocol_version)
        + b32(target_manifest_hash) + b32(target_registration_hash)
    )
    assert len(encoded) == 320
    return encoded


def decode_migration_activation_context_return(
        returndata: bytes) -> tuple[int, bytes, int, int, int, int, int,
                                           bytes, bytes]:
    assert len(returndata) == 320
    assert (bytes4_word_value(returndata[:32])
            == MIGRATION_ACTIVATION_CONTEXT_MAGIC)
    result = (
        uint_word_value(returndata[32:64], 8), b32(returndata[64:96]),
        address_word_value(returndata[96:128]),
        address_word_value(returndata[128:160]),
        uint_word_value(returndata[160:192], 64),
        uint_word_value(returndata[192:224], 64),
        uint_word_value(returndata[224:256], 64),
        b32(returndata[256:288]), b32(returndata[288:320]),
    )
    assert returndata == encode_migration_activation_context_return(*result)
    return result


@dataclass(frozen=True)
class MigrationActivationFixedV2:
    transition_kind: int
    migration_generation: int
    source_protocol_version: int
    target_protocol_version: int
    source_canonical_sequence: int
    candidate_digest: bytes
    output_core: CanonicalCoreV2
    proof_beneficiary: int
    anchor_number: int
    anchor_hash: bytes
    force_cutoff: int
    pre_inbox_last_applied_plus_one: int


def canonical_migration_activation_fixed(
        fixed: MigrationActivationFixedV2) -> bytes:
    narrow = (
        fixed.migration_generation, fixed.source_protocol_version,
        fixed.target_protocol_version, fixed.source_canonical_sequence,
        fixed.force_cutoff, fixed.pre_inbox_last_applied_plus_one,
    )
    assert (fixed.transition_kind in (1, 2)
            and all(0 <= value <= UINT64_MAX for value in narrow))
    if fixed.transition_kind == 1:
        assert (fixed.source_canonical_sequence == 0
                and fixed.force_cutoff == 0
                and fixed.pre_inbox_last_applied_plus_one == 0
                and fixed.output_core.message_cursor == 0)
    encoded = (
        u256(fixed.transition_kind) + u256(fixed.migration_generation)
        + u256(fixed.source_protocol_version)
        + u256(fixed.target_protocol_version)
        + u256(fixed.source_canonical_sequence) + b32(fixed.candidate_digest)
        + canonical_core_v2_abi(fixed.output_core)
        + address_word(fixed.proof_beneficiary) + u256(fixed.anchor_number)
        + b32(fixed.anchor_hash) + u256(fixed.force_cutoff)
        + u256(fixed.pre_inbox_last_applied_plus_one)
    )
    assert len(encoded) == 21 * 32
    return encoded


def encode_activate_version_with_migration_calldata(
        fixed: MigrationActivationFixedV2,
        manifest: ReleaseManifestDescriptor,
        rows: tuple[InboxRowV2, ...], imported_header_rlp: bytes, proof: bytes,
        descriptor_maximum_proof_bytes: int) -> bytes:
    assert (manifest.protocol_version == fixed.target_protocol_version
            and 0 < descriptor_maximum_proof_bytes
                <= MAX_MIGRATION_PROOF_BYTES
            and 0 < len(proof) <= descriptor_maximum_proof_bytes)
    if fixed.transition_kind == 1:
        assert (0 < len(imported_header_rlp) <= 2_048
                and canonical_rlp_list(imported_header_rlp)
                and rows == ())
    else:
        assert imported_header_rlp == b""
    rows_tail = canonical_inbox_rows_tail(rows)
    rows_offset = 82 * 32
    header_offset = rows_offset + len(rows_tail)
    header_tail = abi_bytes_tail(imported_header_rlp)
    proof_offset = header_offset + len(header_tail)
    encoded = (
        ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR
        + canonical_migration_activation_fixed(fixed)
        + canonical_release_manifest(manifest)
        + u256(rows_offset) + u256(header_offset) + u256(proof_offset)
        + rows_tail + header_tail + abi_bytes_tail(proof)
    )
    assert len(encoded) == 4 + proof_offset + 32 + ceil32(len(proof))
    return encoded


def decode_activate_version_with_migration_calldata(
        calldata: bytes, expected_fixed: MigrationActivationFixedV2,
        expected_manifest: ReleaseManifestDescriptor,
        descriptor_maximum_proof_bytes: int
) -> tuple[tuple[InboxRowV2, ...], bytes, bytes]:
    assert (len(calldata) >= 4 + 82 * 32 + 3 * 32
            and calldata[:4] == ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR)
    arguments = calldata[4:]
    fixed_end = 21 * 32
    manifest_end = fixed_end + 58 * 32
    assert (arguments[:fixed_end]
            == canonical_migration_activation_fixed(expected_fixed))
    assert (arguments[fixed_end:manifest_end]
            == canonical_release_manifest(expected_manifest))
    rows_offset = uint_word_value(arguments[79 * 32:80 * 32])
    header_offset = uint_word_value(arguments[80 * 32:81 * 32])
    proof_offset = uint_word_value(arguments[81 * 32:82 * 32])
    assert rows_offset == 82 * 32
    assert rows_offset < header_offset < proof_offset < len(arguments)
    rows = decode_canonical_inbox_rows_tail(
        arguments[rows_offset:header_offset])
    header_length = uint_word_value(arguments[header_offset:header_offset + 32])
    header = arguments[header_offset + 32:header_offset + 32 + header_length]
    assert arguments[header_offset:proof_offset] == abi_bytes_tail(header)
    proof_length = uint_word_value(arguments[proof_offset:proof_offset + 32])
    proof = arguments[proof_offset + 32:proof_offset + 32 + proof_length]
    result = (rows, header, proof)
    assert calldata == encode_activate_version_with_migration_calldata(
        expected_fixed, expected_manifest, *result,
        descriptor_maximum_proof_bytes)
    return result


def validate_activation_journal_consistency(
        statement: MigrationTransitionStatementV2,
        fixed: MigrationActivationFixedV2,
        base_core: CanonicalCoreV2,
        base_hash: bytes,
        rows: tuple[InboxRowV2, ...],
        source_manifest_hash: bytes,
        source_settlement: int,
        target_settlement: int,
        activated_at_block: int,
        activation_context_hash: bytes,
        queue_migration_calldata: bytes) -> None:
    """Validate that every object in one activation journal uses one state."""

    assert (statement.transition_kind == fixed.transition_kind
            and statement.migration_generation == fixed.migration_generation
            and statement.source_protocol_version
                == fixed.source_protocol_version
            and statement.target_protocol_version
                == fixed.target_protocol_version
            and statement.source_canonical_sequence
                == fixed.source_canonical_sequence
            and statement.candidate_digest == fixed.candidate_digest
            and statement.output_canonical_hash
                == canonical_core_v2_hash(fixed.output_core)
            and statement.proof_beneficiary == fixed.proof_beneficiary
            and statement.anchor_number == fixed.anchor_number
            and statement.anchor_hash == fixed.anchor_hash
            and statement.force_cutoff == fixed.force_cutoff
            and statement.pre_inbox_last_applied_plus_one
                == fixed.pre_inbox_last_applied_plus_one)
    assert (statement.base_canonical_hash == base_hash
            and base_core.message_cursor == statement.start_cursor
            and fixed.output_core.message_cursor == statement.end_cursor
            and statement.start_cursor <= statement.end_cursor
                <= statement.queue_count
            and len(rows) == statement.end_cursor - statement.start_cursor
            and tuple(row.queue_index for row in rows)
                == tuple(range(statement.start_cursor, statement.end_cursor))
            and statement.queue_root == statement.force_root
            and statement.inbox_system_calldata_hash
                == keccak256(encode_inbox_apply_calldata(
                    statement.start_cursor, rows)))
    statement_hash = migration_transition_statement_hash(statement)
    assert activation_context_hash == migration_activation_context_hash(
        statement.settlement_chain_id, statement.active_settlement_router,
        statement.transition_kind, statement.migration_generation,
        statement.source_protocol_version, statement.target_protocol_version,
        source_manifest_hash, statement.target_manifest_hash,
        statement.target_registration_hash, source_settlement,
        target_settlement, statement.source_canonical_sequence, base_hash,
        statement_hash, statement.candidate_digest, fixed.output_core,
        statement.forced_queue, statement.queue_root, statement.queue_count,
        statement.start_cursor, statement.end_cursor,
        statement.proof_beneficiary, activated_at_block)
    assert decode_queue_migration_calldata(queue_migration_calldata) == (
        activation_context_hash, source_settlement, target_settlement,
        statement.queue_root, statement.queue_count, statement.start_cursor,
        statement.end_cursor, statement.proof_beneficiary)


def destination_registration_commitment(
        protocol_version: int, manifest_hash: bytes,
        destination_chain_id: int, destination_namespace: bytes,
        destination_domain: bytes, destination_bridge: int,
        destination_infrastructure: bytes,
        execution_profile_hash: bytes) -> bytes:
    assert (protocol_version > 0 and manifest_hash != bytes(32)
            and 0 < destination_chain_id <= UINT64_MAX
            and destination_namespace != bytes(32)
            and destination_domain != bytes(32) and destination_bridge != 0
            and destination_infrastructure != bytes(32)
            and execution_profile_hash != bytes(32))
    encoded = (u64(protocol_version) + b32(manifest_hash)
               + u256(destination_chain_id) + b32(destination_namespace)
               + b32(destination_domain) + address20(destination_bridge)
               + b32(destination_infrastructure)
               + b32(execution_profile_hash))
    assert len(encoded) == 220
    return keccak256(D_DESTINATION_REGISTRATION + encoded)


def registration_commitment_base_slot() -> bytes:
    return keccak256(D_REGISTRATION_SLOT)


def registration_commitment_slot(protocol_version: int) -> bytes:
    assert protocol_version > 0
    return keccak256(u256(protocol_version)
                     + registration_commitment_base_slot())


def registration_commitment_trie_key(protocol_version: int) -> bytes:
    return keccak256(registration_commitment_slot(protocol_version))


def release_manifest_base_slot() -> bytes:
    return keccak256(D_RELEASE_MANIFEST_SLOT)


def release_manifest_slot(protocol_version: int) -> bytes:
    assert protocol_version > 0
    return keccak256(u256(protocol_version) + release_manifest_base_slot())


def release_manifest_trie_key(protocol_version: int) -> bytes:
    return keccak256(release_manifest_slot(protocol_version))


def inbox_route_config_hash(inbox_apply_router: int, destination_bridge: int,
                            terminal_registrar: int,
                            destination_domain: bytes) -> bytes:
    assert (inbox_apply_router != 0 and destination_bridge != 0
            and terminal_registrar != 0
            and destination_domain != bytes(32))
    return keccak256(
        D_INBOX_ROUTE_CONFIG + address20(inbox_apply_router)
        + address20(destination_bridge) + address20(terminal_registrar)
        + b32(destination_domain))


def fixture_destination_components(
        protocol_version_manager_descriptor_hash_: bytes
        | None = None) -> tuple[ComponentDescriptor, ...]:
    """Fully derived fixture for the ten canonical component grammars."""
    if protocol_version_manager_descriptor_hash_ is None:
        protocol_version_manager_descriptor_hash_ = fixture_protocol_authority()[4]
    assert protocol_version_manager_descriptor_hash_ != bytes(32)
    queue_config = forced_queue_config_hash(0xAD01)
    bundle_deployer = create2_address(
        0xF123, bytes.fromhex("30" * 32), bytes.fromhex("31" * 32))
    source_bridge = create_address_from_nonce(bundle_deployer, 1)
    source_registry = create_address_from_nonce(bundle_deployer, 2)
    bridge_kernel = bridge_kernel_profile_hash(
        bytes.fromhex("2a" * 32), bytes.fromhex("2b" * 32),
        bytes.fromhex("2c" * 32))
    configs = (
        address20(source_registry) + address20(source_bridge)
        + address20(0xAD01)
        + address20(0xD200),
        address20(0xD200) + b32(protocol_version_manager_descriptor_hash_)
        + address20(0xF000)
        + bytes.fromhex("5a" * 32) + queue_config
        + bytes.fromhex("41" * 32),
        address20(0xAD01) + u8(64),
        address20(0x5103) + address20(0x5105)
        + bytes.fromhex("43" * 32) + u8(64),
        address20(0x5100) + address20(0xB200) + address20(0x5103),
        address20(0x5105) + bytes.fromhex("43" * 32),
        address20(0x5106) + address20(0x5100) + address20(0x5102)
        + address20(0x5104),
        address20(0x5103) + u8(64),
        address20(0x5103) + bytes.fromhex("44" * 32)
        + u64(POOL_EXTERNAL_READ_GAS)
        + u64(POOL_AUTH_CLEANUP_GAS)
        + u64(POOL_VALUE_CALLBACK_GAS),
        destination_bridge_component_config(
            bytes.fromhex("42" * 32), bridge_kernel,
            0x5101, 0x5102, 0x5103, 0x5107, 0x5104),
    )
    addresses = (0xAD00, 0xAD01, 0xD101, 0x5100, 0x5101,
                 0x5106, 0x5103, 0x5102, 0x5104, 0xB200)
    return tuple(ComponentDescriptor(
        address, bytes([0x50 + index]) * 32,
        component_config_hash(index + 1, configs[index]))
        for index, address in enumerate(addresses))


def source_domain_id(src_chain_id: int, genesis_hash: bytes,
                     registry: int, terminal_verifier: int, bridge: int,
                     execution_hash: bytes,
                     registry_namespace: bytes) -> bytes:
    assert (genesis_hash != bytes(32) and registry_namespace != bytes(32)
            and execution_hash != bytes(32) and registry != 0
            and terminal_verifier != 0 and bridge != 0)
    return keccak256(D_SOURCE_DOMAIN + u64(src_chain_id) + b32(genesis_hash)
                     + address20(registry) + address20(terminal_verifier)
                     + address20(bridge) + b32(execution_hash)
                     + b32(registry_namespace))


def destination_domain_id(dest_chain_id: int, genesis_hash: bytes,
                          bridge_inbox_adapter: int,
                          active_settlement_router: int,
                          terminal_verifier: int,
                          inbox_apply: int, inbox_credit_store: int,
                          protocol_release_authority: int,
                          terminal_domain_registrar: int,
                          terminal_accumulator: int,
                          native_liquidity_pool: int, bridge: int,
                          bridge_execution_hash: bytes,
                          infrastructure_hash: bytes,
                          namespace: bytes) -> bytes:
    assert (genesis_hash != bytes(32) and namespace != bytes(32)
            and bridge_execution_hash != bytes(32)
            and infrastructure_hash != bytes(32)
            and bridge_inbox_adapter != 0
            and active_settlement_router != 0
            and terminal_verifier != 0
            and inbox_apply != 0 and inbox_credit_store != 0
            and protocol_release_authority != 0
            and terminal_domain_registrar != 0
            and terminal_accumulator != 0
            and native_liquidity_pool != 0 and bridge != 0)
    return keccak256(D_DESTINATION_DOMAIN + u64(dest_chain_id)
                     + b32(genesis_hash)
                     + address20(bridge_inbox_adapter)
                     + address20(active_settlement_router)
                     + address20(terminal_verifier)
                     + address20(inbox_apply)
                     + address20(inbox_credit_store)
                     + address20(protocol_release_authority)
                     + address20(terminal_domain_registrar)
                     + address20(terminal_accumulator)
                     + address20(native_liquidity_pool)
                     + address20(bridge)
                     + b32(bridge_execution_hash)
                     + b32(infrastructure_hash)
                     + b32(namespace))


def force_descriptor_list(start: int,
                          consumed: tuple[tuple[int, bytes], ...],
                          boundary: tuple[int, bytes] | None) -> bytes:
    rows = consumed + (() if boundary is None else (boundary,))
    payload = b"".join(
        u64(start + offset) + u8(kind) + u16(len(descriptor)) + descriptor
        for offset, (kind, descriptor) in enumerate(rows)
    )
    return keccak256(D_FORCE_DESCRIPTOR_LIST + u64(start) + u16(len(consumed))
                     + u8(boundary is not None) + payload)


FORCE_EMPTY: list[bytes] = [keccak256(D_FORCE_EMPTY)]
for _height in range(FORCE_DEPTH):
    FORCE_EMPTY.append(keccak256(D_FORCE_NODE + u8(_height)
                                 + FORCE_EMPTY[-1] + FORCE_EMPTY[-1]))


def append_fixed_frontier(frontier: tuple[bytes, ...], count: int,
                          leaf: bytes, node_domain: bytes,
                          depth: int = FORCE_DEPTH) -> tuple[bytes, ...]:
    """Append one leaf to a fixed-width frontier without historical leaves."""

    assert len(frontier) == depth and 0 <= count < (1 << depth) - 1
    updated = [b32(node) for node in frontier]
    carry, height = b32(leaf), 0
    while (count >> height) & 1:
        carry = keccak256(node_domain + u8(height)
                          + updated[height] + carry)
        height += 1
    updated[height] = carry
    return tuple(updated)


def fixed_frontier_tree_root(frontier: tuple[bytes, ...], count: int,
                             zero_hashes: list[bytes], node_domain: bytes,
                             depth: int = FORCE_DEPTH) -> bytes:
    """Fold a fixed-width frontier and canonical empty right subtrees."""

    assert (len(frontier) == depth and len(zero_hashes) == depth + 1
            and 0 <= count < 1 << depth)
    node = zero_hashes[0]
    for height in range(depth):
        if (count >> height) & 1:
            node = keccak256(node_domain + u8(height)
                             + b32(frontier[height]) + node)
        else:
            node = keccak256(node_domain + u8(height)
                             + node + zero_hashes[height])
    return node


def force_frontier_root(frontier: tuple[bytes, ...], count: int) -> bytes:
    return keccak256(D_FORCE_ROOT + u64(count)
                     + fixed_frontier_tree_root(
                         frontier, count, FORCE_EMPTY, D_FORCE_NODE))


class ForceVector:
    def __init__(self, leaves: tuple[bytes, ...]):
        assert len(leaves) < 1 << FORCE_DEPTH
        self.leaves = tuple(b32(leaf) for leaf in leaves)

    @lru_cache(maxsize=None)
    def node(self, height: int, node_index: int) -> bytes:
        start = node_index << height
        if start >= len(self.leaves):
            return FORCE_EMPTY[height]
        if height == 0:
            return self.leaves[start]
        return keccak256(D_FORCE_NODE + u8(height - 1)
                         + self.node(height - 1, node_index * 2)
                         + self.node(height - 1, node_index * 2 + 1))

    @property
    def root(self) -> bytes:
        return keccak256(D_FORCE_ROOT + u64(len(self.leaves)) + self.node(FORCE_DEPTH, 0))

    def range_proof(self, start: int, end_inclusive: int) -> tuple[bytes, ...]:
        assert 0 <= start <= end_inclusive < len(self.leaves)
        proof: list[bytes] = []

        def visit(height: int, node_index: int) -> None:
            left = node_index << height
            right = left + (1 << height) - 1
            if right < start or left > end_inclusive:
                proof.append(self.node(height, node_index))
            elif height:
                visit(height - 1, node_index * 2)
                visit(height - 1, node_index * 2 + 1)

        visit(FORCE_DEPTH, 0)
        return tuple(proof)


def append_frontier_height(old_count: int) -> int:
    assert 0 <= old_count < UINT64_MAX
    for height in range(FORCE_DEPTH):
        if not (old_count >> height) & 1:
            return height
    raise AssertionError("unreachable below UINT64_MAX")


def verify_force_range(count: int, start: int, revealed: tuple[bytes, ...],
                       proof: tuple[bytes, ...], expected_root: bytes) -> bool:
    if not revealed or start + len(revealed) > count:
        return False
    end = start + len(revealed) - 1
    proof_at = reveal_at = 0

    def visit(height: int, node_index: int) -> bytes:
        nonlocal proof_at, reveal_at
        left = node_index << height
        right = left + (1 << height) - 1
        if right < start or left > end:
            if proof_at >= len(proof):
                raise ValueError
            node = b32(proof[proof_at])
            proof_at += 1
            return node
        if height == 0:
            node = b32(revealed[reveal_at])
            reveal_at += 1
            return node
        return keccak256(D_FORCE_NODE + u8(height - 1)
                         + visit(height - 1, node_index * 2)
                         + visit(height - 1, node_index * 2 + 1))

    try:
        tree = visit(FORCE_DEPTH, 0)
    except (ValueError, AssertionError):
        return False
    root = keccak256(D_FORCE_ROOT + u64(count) + tree)
    return (proof_at == len(proof) and reveal_at == len(revealed)
            and root == expected_root)


def session_id(chain_id: int, contract: int, owner: int, nonce: int) -> bytes:
    return keccak256(D_SESSION + u256(chain_id) + address20(contract)
                     + address20(owner) + u64(nonce))


def chunk_root(full_body_root: bytes, block_ordinal: int, chunk_index: int,
               chunk_count: int, chunk: bytes) -> bytes:
    return keccak256(D_CHUNK + b32(full_body_root) + u16(block_ordinal)
                     + u16(chunk_index) + u16(chunk_count) + u32(len(chunk)) + chunk)


def data_leaf(session: bytes, index: int, versioned_hash: bytes,
              full_body_root: bytes, block_ordinal: int, chunk_index: int,
              chunk_count: int, chunk: bytes, publisher: int,
              valid_until: int, z: int, y: int) -> bytes:
    croot = chunk_root(full_body_root, block_ordinal, chunk_index, chunk_count, chunk)
    return keccak256(D_MMR_LEAF + b32(session) + u16(index) + b32(versioned_hash)
                     + b32(full_body_root) + u16(block_ordinal) + u16(chunk_index)
                     + u16(chunk_count) + u32(len(chunk)) + croot
                     + address20(publisher) + u64(valid_until) + u256(z) + u256(y))


def mmr_root(leaves: tuple[bytes, ...]) -> bytes:
    peaks: list[tuple[int, bytes]] = []
    for leaf in leaves:
        height, node = 0, b32(leaf)
        while peaks and peaks[-1][0] == height:
            _, left = peaks.pop()
            node = keccak256(D_MMR_NODE + u8(height) + left + node)
            height += 1
        peaks.append((height, node))
    encoded = b"".join(u8(height) + node for height, node in reversed(peaks))
    return keccak256(D_MMR_BAG + u16(len(leaves)) + u8(len(peaks)) + encoded)


def append_mmr_frontier(frontier: tuple[bytes, ...], count: int,
                        leaf: bytes) -> tuple[bytes, ...]:
    """Append one exact Appendix data leaf to the 12-word session frontier."""

    assert len(frontier) == 12 and 0 <= count < 2_100
    updated = [b32(node) for node in frontier]
    carry, height = b32(leaf), 0
    while (count >> height) & 1:
        carry = keccak256(D_MMR_NODE + u8(height)
                          + updated[height] + carry)
        height += 1
    updated[height] = carry
    return tuple(updated)


def mmr_frontier_root(frontier: tuple[bytes, ...], count: int) -> bytes:
    """Bag set-bit peaks rightmost-to-leftmost: ascending stored height."""

    assert len(frontier) == 12 and 0 <= count <= 2_100
    heights = tuple(height for height in range(12) if (count >> height) & 1)
    encoded = b"".join(u8(height) + b32(frontier[height])
                       for height in heights)
    return keccak256(D_MMR_BAG + u16(count) + u8(len(heights)) + encoded)


@dataclass(frozen=True)
class ManifestEntry:
    block_ordinal: int
    session: bytes
    record_index: int
    chunk_index: int
    chunk_count: int
    chunk_length: int
    full_body_root: bytes
    chunk_root: bytes


def manifest_leaf(position: int, entry: ManifestEntry) -> bytes:
    return keccak256(D_MANIFEST_LEAF + u16(position) + u16(entry.block_ordinal)
                     + b32(entry.session) + u16(entry.record_index)
                     + u16(entry.chunk_index) + u16(entry.chunk_count)
                     + u32(entry.chunk_length) + b32(entry.full_body_root)
                     + b32(entry.chunk_root))


def manifest_root(entries: tuple[ManifestEntry, ...]) -> bytes:
    if not entries:
        return keccak256(D_MANIFEST_ROOT + u16(0) + keccak256(D_MANIFEST_EMPTY))
    leaves = [manifest_leaf(i, entry) for i, entry in enumerate(entries)]
    size = 1
    while size < len(leaves):
        size *= 2
    leaves.extend([keccak256(D_MANIFEST_EMPTY)] * (size - len(leaves)))
    return keccak256(D_MANIFEST_ROOT + u16(len(entries))
                     + fixed_root(leaves, D_MANIFEST_NODE))


def dispositions(start: int, rows: tuple[tuple[int, int, int, bytes], ...]) -> bytes:
    end = start + len(rows)
    payload = b"".join(u64(index) + u8(code) + u32(tx_index) + b32(result)
                       for index, code, tx_index, result in rows)
    return keccak256(D_DISPOSITIONS + u64(start) + u64(end) + u16(len(rows)) + payload)


def bridge_credit_result(index: int, envelope: BridgeEnvelope) -> bytes:
    return keccak256(
        D_BRIDGE_RESULT + u64(index) + bridge_credit_id(
            envelope.src_chain_id, envelope.source_domain_id, envelope.src_epoch,
            envelope.src_bridge, envelope.destination_domain_id,
            envelope.msg_hash, envelope.liquidity_fee)
        + b32(envelope.msg_hash)
        + u256(envelope.src_chain_id) + b32(envelope.source_domain_id)
        + u64(envelope.src_epoch)
        + address20(envelope.src_bridge)
        + b32(envelope.bridge_execution_hash) + u64(envelope.emitted_at_block)
        + b32(envelope.destination_domain_id) + u256(envelope.dest_chain_id)
        + u64(envelope.enqueue_by)
        + address20(envelope.sender) + address20(envelope.src_owner)
        + address20(envelope.dest_owner) + u256(envelope.value)
        + u64(envelope.fee) + u64(envelope.liquidity_fee)
        + b32(envelope.calldata_hash)
        + u8(envelope.refund_mode) + address20(envelope.refund_vault)
        + b32(envelope.refund_capsule_hash)
        + b32(envelope.escrow_id)
    )


def bridge_credit_id(src_chain_id: int, source_domain_id_: bytes, src_epoch: int,
                     src_bridge: int, destination_domain_id_: bytes,
                     msg_hash: bytes, liquidity_fee: int) -> bytes:
    assert liquidity_fee > 0
    return keccak256(D_BRIDGE_CREDIT_ID + u64(src_chain_id)
                     + b32(source_domain_id_) + u64(src_epoch)
                     + address20(src_bridge) + b32(destination_domain_id_)
                     + b32(msg_hash) + u64(liquidity_fee))


def inbox_credit_slot(source_domain_id_: bytes, src_bridge: int,
                      destination_domain_id_: bytes, credit_id: bytes) -> bytes:
    return keccak256(D_INBOX_CREDIT_SLOT + b32(source_domain_id_)
                     + address20(src_bridge) + b32(destination_domain_id_)
                     + b32(credit_id))


def terminal_leaf(index: int, destination_domain_id_: bytes,
                  destination_bridge: int, credit_id: bytes,
                  terminal: int, liquidity_settlement_hash: bytes) -> bytes:
    assert terminal in (1, 2)
    assert ((terminal == 1 and liquidity_settlement_hash != bytes(32))
            or (terminal == 2 and liquidity_settlement_hash == bytes(32)))
    return keccak256(D_TERMINAL_LEAF + u64(index)
                     + b32(destination_domain_id_)
                     + address20(destination_bridge) + b32(credit_id)
                     + u8(terminal) + b32(liquidity_settlement_hash))


def liquidity_settlement_hash(ticket_id: bytes, l1_recipient: int,
                              settlement_amount: int) -> bytes:
    assert ticket_id != bytes(32) and l1_recipient != 0 and settlement_amount > 0
    return keccak256(D_LIQUIDITY_SETTLEMENT + b32(ticket_id)
                     + address20(l1_recipient) + u256(settlement_amount))


TERMINAL_EMPTY: list[bytes] = [keccak256(D_TERMINAL_EMPTY)]
for _height in range(TERMINAL_DEPTH):
    TERMINAL_EMPTY.append(keccak256(D_TERMINAL_NODE + u8(_height)
                                    + TERMINAL_EMPTY[-1]
                                    + TERMINAL_EMPTY[-1]))


class TerminalVector:
    def __init__(self, leaves: tuple[bytes, ...]):
        assert len(leaves) <= UINT64_MAX
        self.leaves = tuple(b32(leaf) for leaf in leaves)

    @lru_cache(maxsize=None)
    def node(self, height: int, node_index: int) -> bytes:
        start = node_index << height
        if start >= len(self.leaves):
            return TERMINAL_EMPTY[height]
        if height == 0:
            return self.leaves[start]
        return keccak256(D_TERMINAL_NODE + u8(height - 1)
                         + self.node(height - 1, node_index * 2)
                         + self.node(height - 1, node_index * 2 + 1))

    @property
    def root(self) -> bytes:
        return keccak256(D_TERMINAL_ROOT + u64(len(self.leaves))
                         + self.node(TERMINAL_DEPTH, 0))

    def proof(self, index: int) -> tuple[bytes, ...]:
        assert 0 <= index < len(self.leaves)
        return tuple(self.node(height, (index >> height) ^ 1)
                     for height in range(TERMINAL_DEPTH))


def terminal_frontier_root(frontier: tuple[bytes, ...], count: int) -> bytes:
    return keccak256(D_TERMINAL_ROOT + u64(count)
                     + fixed_frontier_tree_root(
                         frontier, count, TERMINAL_EMPTY, D_TERMINAL_NODE,
                         TERMINAL_DEPTH))


class PersistentTerminalTree:
    """Off-chain immutable proof oracle reconstructed from canonical events.

    A node is written only when its fixed interval becomes completely occupied.
    Thus no historical proof dependency is overwritten.  A node for any prefix
    count is reconstructed from completed subtrees and canonical empty nodes.
    TerminalAccumulatorV2 never stores this map: its entire canonical Merkle
    state is the 64-word append frontier, checked count and wrapped root.
    """

    def __init__(self) -> None:
        self.count = 0
        self.completed_nodes: dict[tuple[int, int], bytes] = {}

    def node_at(self, count: int, height: int, node_index: int) -> bytes:
        assert 0 <= count <= self.count
        assert 0 <= height <= TERMINAL_DEPTH and node_index >= 0
        start = node_index << height
        end = start + (1 << height)
        if start >= count:
            return TERMINAL_EMPTY[height]
        if end <= count:
            node = self.completed_nodes.get((height, node_index))
            assert node is not None
            return node
        assert height > 0
        return keccak256(
            D_TERMINAL_NODE + u8(height - 1)
            + self.node_at(count, height - 1, node_index * 2)
            + self.node_at(count, height - 1, node_index * 2 + 1))

    def root_at(self, count: int) -> bytes:
        assert 0 <= count <= self.count
        return keccak256(
            D_TERMINAL_ROOT + u64(count)
            + self.node_at(count, TERMINAL_DEPTH, 0))

    @property
    def root(self) -> bytes:
        return self.root_at(self.count)

    def append(self, leaf: bytes) -> int:
        assert self.count < UINT64_MAX
        index = self.count
        node = b32(leaf)
        self.completed_nodes[(0, index)] = node
        node_index = index
        height = 0
        while height < TERMINAL_DEPTH and node_index & 1:
            left = self.completed_nodes[(height, node_index - 1)]
            node = keccak256(D_TERMINAL_NODE + u8(height) + left + node)
            node_index >>= 1
            height += 1
            self.completed_nodes[(height, node_index)] = node
        self.count += 1
        return index

    def proof_at(self, count: int, index: int) -> tuple[bytes, ...]:
        assert 0 <= index < count <= self.count
        return tuple(self.node_at(count, height, (index >> height) ^ 1)
                     for height in range(TERMINAL_DEPTH))

    def proof(self, index: int) -> tuple[bytes, ...]:
        return self.proof_at(self.count, index)


def verify_terminal_proof(count: int, index: int, leaf: bytes,
                          proof: tuple[bytes, ...], expected_root: bytes) -> bool:
    if not (0 <= index < count <= UINT64_MAX) or len(proof) != TERMINAL_DEPTH:
        return False
    node = b32(leaf)
    for height, sibling in enumerate(proof):
        node = (keccak256(D_TERMINAL_NODE + u8(height) + sibling + node)
                if (index >> height) & 1 else
                keccak256(D_TERMINAL_NODE + u8(height) + node + sibling))
    return keccak256(D_TERMINAL_ROOT + u64(count) + node) == expected_root


def bridge_escrow_id(credit_id: bytes) -> bytes:
    return keccak256(D_BRIDGE_ESCROW + b32(credit_id))


def pin_inbox_credit(store: dict[bytes, bytes], src_chain_id: int,
                     source_domain_id_: bytes, src_epoch: int,
                     src_bridge: int, destination_domain_id_: bytes,
                     msg_hash: bytes, liquidity_fee: int,
                     result_hash: bytes) -> bool:
    if src_bridge == 0 or msg_hash == bytes(32) or result_hash == bytes(32):
        return False
    credit_id = bridge_credit_id(
        src_chain_id, source_domain_id_, src_epoch, src_bridge,
        destination_domain_id_, msg_hash, liquidity_fee)
    key = inbox_credit_slot(
        source_domain_id_, src_bridge, destination_domain_id_, credit_id)
    existing = store.get(key)
    if existing is None:
        store[key] = result_hash
        return True
    return existing == result_hash


def pin_inbox_credit_batch(
    store: dict[bytes, bytes],
    rows: tuple[tuple[int, int, bytes, int, int, bytes, bytes, int, bytes], ...],
) -> bool:
    if len(rows) > 64:
        return False
    indices = tuple(row[0] for row in rows)
    if indices != tuple(sorted(indices)) or len(set(indices)) != len(indices):
        return False
    staged = dict(store)
    seen: set[bytes] = set()
    for (_, src_chain_id, source_domain_id_, src_epoch, src_bridge,
         destination_domain_id_, msg_hash, liquidity_fee, result) in rows:
        credit_id = bridge_credit_id(
            src_chain_id, source_domain_id_, src_epoch, src_bridge,
            destination_domain_id_, msg_hash, liquidity_fee)
        if credit_id in seen or not pin_inbox_credit(
                staged, src_chain_id, source_domain_id_, src_epoch, src_bridge,
                destination_domain_id_, msg_hash, liquidity_fee, result):
            return False
        seen.add(credit_id)
    store.clear()
    store.update(staged)
    return True


def canonical_disposition(code: int, tx_index: int, result_hash: bytes,
                          raw_tx: bytes | None = None,
                          expected_bridge_result: bytes | None = None) -> bool:
    if code in range(4):
        return tx_index == UINT32_MAX and result_hash == bytes(32) and raw_tx is None
    if code == 4:
        return (tx_index != UINT32_MAX and raw_tx is not None
                and result_hash == keccak256(raw_tx))
    if code == 5:
        return (tx_index == UINT32_MAX and raw_tx is None
                and expected_bridge_result is not None
                and result_hash == expected_bridge_result)
    return False


def recovery_id(chain_id: int, contract: int, episode: int, revision: int,
                base_hash: bytes, round_start_slot: int, anchor_number: int,
                anchor_hash: bytes, force_root_hash: bytes, force_cutoff: int,
                admission_version: int, admission_root_hash: bytes,
                escape_slot: int, causes: int) -> bytes:
    return keccak256(D_RECOVERY + u256(chain_id) + address20(contract)
                     + u64(episode) + u64(revision) + b32(base_hash)
                     + u64(round_start_slot) + u64(anchor_number) + b32(anchor_hash)
                     + b32(force_root_hash) + u64(force_cutoff)
                     + u64(admission_version) + b32(admission_root_hash)
                     + u64(escape_slot) + u8(causes))


def body_bytes(transactions: tuple[bytes, ...]) -> bytes:
    return u32(len(transactions)) + b"".join(u32(len(tx)) + tx for tx in transactions)


def body_root(transactions: tuple[bytes, ...]) -> bytes:
    encoded = body_bytes(transactions)
    return keccak256(D_BODY + u32(len(encoded)) + encoded)


def encode_blob_payload(payload: bytes) -> bytes:
    framed = u32(len(payload)) + payload
    assert len(framed) <= 4096 * 31
    framed += bytes(4096 * 31 - len(framed))
    return b"".join(b"\x00" + framed[i:i + 31] for i in range(0, len(framed), 31))


def decode_blob_payload(blob: bytes) -> bytes:
    assert len(blob) == 4096 * 32
    chunks = []
    for i in range(0, len(blob), 32):
        element = blob[i:i + 32]
        assert element[0] == 0
        chunks.append(element[1:])
    framed = b"".join(chunks)
    length = int.from_bytes(framed[:4], "big")
    assert length <= 4096 * 31 - 4 and not any(framed[4 + length:])
    return framed[4:4 + length]


def fs_challenge(chain_id: int, version: int, session: bytes,
                 versioned_hash: bytes, full_body_root: bytes,
                 block_ordinal: int, chunk_index: int, chunk_count: int,
                 chunk_length: int, croot: bytes, publisher: int,
                 valid_until: int) -> int:
    digest = keccak256(D_FS + u256(chain_id) + u256(version) + b32(session)
                       + b32(versioned_hash) + b32(full_body_root)
                       + u16(block_ordinal) + u16(chunk_index) + u16(chunk_count)
                       + u32(chunk_length) + b32(croot) + address20(publisher)
                       + u64(valid_until))
    return int.from_bytes(digest, "big") % BLS_MODULUS


def vectors() -> dict[str, str]:
    settlement_chain_id, l2_chain_id, contract = 1, 16_788, 0xABCD
    profile_bytes = canonical_execution_profile_cross_model_fixture_v2()
    assert decode_execution_profile_v2(profile_bytes)
    for legacy_profile in (
        bytes.fromhex("a1617601"),
        bytes.fromhex("a4000101400241000380"),
    ):
        try:
            decode_execution_profile_v2(legacy_profile)
        except AssertionError:
            pass
        else:
            raise AssertionError("legacy CBOR execution profile was accepted")
    def replace_profile_word(index: int, value: bytes) -> bytes:
        assert len(value) == 32
        changed = bytearray(profile_bytes)
        changed[(1 + index) * 32:(2 + index) * 32] = value
        return bytes(changed)

    assert_rejects(
        lambda: decode_execution_profile_v2(replace_profile_word(
            46, bytes.fromhex("fe" * 32))),
        "publisher-selected Settlement factory configuration accepted")
    assert_rejects(
        lambda: decode_execution_profile_v2(replace_profile_word(244, u256(0))),
        "zero L1 EIP-2935 first-supported block accepted")
    dirty_l1_first = bytearray(profile_bytes)
    dirty_l1_first[(1 + 244) * 32] = 1
    assert_rejects(
        lambda: decode_execution_profile_v2(bytes(dirty_l1_first)),
        "dirty uint64 L1 EIP-2935 first-supported block accepted")
    assert_rejects(
        lambda: decode_execution_profile_v2(replace_profile_word(244, u256(2))),
        "L1 first-supported substitution without config join accepted")
    first_two = bytearray(replace_profile_word(244, u256(2)))
    first_two[(1 + 59) * 32:(2 + 59) * 32] = \
        eip2935_read_configuration_hash_v1(2)
    assert uint_word_value(decode_execution_profile_v2(bytes(first_two))[244],
                           64) == 2
    l2_two = bytearray(replace_profile_word(246, u256(2)))
    assert_rejects(
        lambda: decode_execution_profile_v2(bytes(l2_two)),
        "L2 activation later than first V2 block accepted")
    l2_two[(1 + 7) * 32:(2 + 7) * 32] = u256(2)
    assert uint_word_value(decode_execution_profile_v2(bytes(l2_two))[246],
                           64) == 2
    profile_hash = execution_profile_hash(profile_bytes)
    derived_release_authority = derive_register_release_authority_v2(
        profile_bytes, 0)
    target_constructor_inventory = target_constructor_inventory_v2(
        profile_bytes, derived_release_authority)
    target_constructor_state_return = \
        encode_target_constructor_state_return_v2(
            target_constructor_poststate_commitment_v2(
                target_constructor_inventory),
            derived_release_authority.settlement_deployment_descriptor
                .target_configuration_hash)
    empty_data_session_accounting_return = \
        encode_empty_data_session_accounting_v1(
            derived_release_authority.data_session_configuration_hash)
    live_registration_validation_commitment = \
        live_registration_validation_commitment_v2(
            derived_release_authority,
            empty_data_session_accounting_return,
            target_constructor_state_return)
    assert (SETTLEMENT_FACTORY_DEPLOY_SELECTOR.hex() == "4af63f02"
            and SETTLEMENT_FACTORY_ADDRESS_V2
                == int("ce0042b868300000d44a59004da54a005ffdcf9f", 16)
            and SETTLEMENT_FACTORY_RUNTIME_HASH_V2.hex()
                == "c4d5542b53a8b779595a20a8ddd60e58a6c49d3c3decc2df83ced1c69c8ca807"
            and SETTLEMENT_FACTORY_CREATION_CODE_HASH_V2.hex()
                == "122b6b28aeddfd05fa3ce4348e93d357b3ce50d9ab7dda4e8ee524a5b9a6ab3b"
            and SETTLEMENT_FACTORY_DEPLOYMENT_TRANSACTION_HASH_V2.hex()
                == "803351deb6d745e91545a6a3e1c0ea3e9a6a02a1a4193b70edfcd2f40f71a01c"
            and SETTLEMENT_FACTORY_SINGLE_USE_DEPLOYER_V2
                == int("bb6e024b9cffacb947a71991e386681b1cd1477d", 16)
            and TARGET_CONSTRUCTOR_STATE_SELECTOR
                == keccak256(b"targetConstructorStateV2()")[:4]
            and DATA_SESSION_ACCOUNTING_SELECTOR
                == keccak256(b"dataSessionAccountingV1()")[:4]
            and len(target_constructor_state_return) == 96
            and len(empty_data_session_accounting_return) == 384)
    deployment = derived_release_authority.settlement_deployment_descriptor
    assert (deployment.factory == SETTLEMENT_FACTORY_ADDRESS_V2
            and deployment.factory_runtime_hash
                == SETTLEMENT_FACTORY_RUNTIME_HASH_V2
            and deployment.factory_configuration_hash
                == settlement_factory_configuration_hash_v2())
    assert validate_component_config_getter(
        deployment.target_runtime_hash, deployment.target_runtime_hash,
        deployment.target_configuration_hash,
        COMPONENT_CONFIG_GETTER_SELECTOR,
        COMPONENT_CONFIG_GETTER_GAS_LIMIT,
        deployment.target_configuration_hash,
    ) == deployment.target_configuration_hash
    assert_rejects(
        lambda: validate_component_config_getter(
            deployment.target_runtime_hash, deployment.target_runtime_hash,
            deployment.target_configuration_hash,
            SETTLEMENT_FACTORY_DEPLOY_SELECTOR,
            COMPONENT_CONFIG_GETTER_GAS_LIMIT,
            deployment.target_configuration_hash),
        "factory selector accepted by target component getter")
    for bad_inventory in (
        target_constructor_inventory[:-1],
        (bytes.fromhex("ff" * 32),) + target_constructor_inventory[1:],
    ):
        if len(bad_inventory) != 259:
            assert_rejects(
                lambda value=bad_inventory:
                    target_constructor_poststate_commitment_v2(value),
                "malformed target constructor inventory accepted")
        else:
            assert (target_constructor_poststate_commitment_v2(bad_inventory)
                    != target_constructor_poststate_commitment_v2(
                        target_constructor_inventory))
    tranche = tranche_leaf(7, 519, 2, 10**17, 999_999)
    cell = RegistryCell(0x1234, 10**18, 9, 777, bytes.fromhex("11" * 32), UINT64_MAX)
    cells = [None] * 64
    cells[3] = cell
    reg_root = registry_root(tuple(cells))
    liabilities = [None] * 1_072
    liabilities[0] = cell
    adm_root = canonical_admission_root(tuple(cells), tuple(liabilities))
    tranche_mutation = replace(cell, tranche_root=bytes.fromhex("22" * 32))
    mutated_cells = list(cells)
    mutated_cells[3] = tranche_mutation
    assert canonical_admission_root(tuple(mutated_cells), tuple(liabilities)) == adm_root
    assert registry_root(tuple(mutated_cells)) != reg_root
    replacement_cell = RegistryCell(
        0x5678, 2 * 10**18, 10, 888, bytes.fromhex("24" * 32), UINT64_MAX)
    liabilities[0] = replacement_cell
    adm_reuse_root = canonical_admission_root(tuple(cells), tuple(liabilities))
    entries = [entry_leaf(0, cell, tranche)] + [entry_leaf(i, None, None) for i in range(1, 64)]
    ent_root = fixed_root(entries, D_ENTRY_NODE)
    envs = tuple(ForcedEnvelope(0xCAFE, i, l2_chain_id, keccak256(u64(i)), 123, 80_000,
                                80_000, 10**12, 9_999, 0xBEEF, 555,
                                2_055 + i, 10**15) for i in range(70))
    force_leaves = tuple(forced_leaf(i, env) for i, env in enumerate(envs))
    force = ForceVector(force_leaves)
    proof = force.range_proof(2, 66)
    force_frontier = tuple(bytes(32) for _ in range(FORCE_DEPTH))
    for count, force_leaf in enumerate(force_leaves):
        assert force_frontier_root(force_frontier, count) \
            == ForceVector(force_leaves[:count]).root
        force_frontier = append_fixed_frontier(
            force_frontier, count, force_leaf, D_FORCE_NODE)
    assert force_frontier_root(force_frontier, len(force_leaves)) == force.root
    stale_force_frontier = list(force_frontier)
    stale_force_frontier[0] = bytes.fromhex("ab" * 32)  # bit 0 of 70 is zero
    assert force_frontier_root(tuple(stale_force_frontier), 70) == force.root
    used_force_frontier = list(force_frontier)
    used_force_frontier[1] = bytes.fromhex("cd" * 32)  # bit 1 of 70 is one
    assert force_frontier_root(tuple(used_force_frontier), 70) != force.root
    sid = session_id(settlement_chain_id, contract, 0xCAFE, 2)
    session_config = DataSessionConfigV1(
        settlement_chain_id=settlement_chain_id,
        protocol_version=2,
        settlement=contract,
        active_settlement_router=0xAD01,
        protocol_version_manager=0xAD02,
        data_rent=0xAD03,
        execution_profile_hash=profile_hash,
        bond=10,
        base=1,
        byte_rent=2,
        blob_bps=10_000,
    )
    session_config_hash = data_session_config_hash(session_config)
    assert_all_fields_bound(session_config, data_session_config_hash)
    session_function_selectors = {
        key: keccak256(signature)[:4]
        for key, signature in DATA_SESSION_FUNCTION_SIGNATURES.items()
    }
    router_session_gate_selectors = {
        key: keccak256(signature)[:4]
        for key, signature in ROUTER_SESSION_GATE_FUNCTION_SIGNATURES.items()
    }
    session_event_topics = {
        key: keccak256(signature)
        for key, signature in DATA_SESSION_EVENT_SIGNATURES.items()
    }
    assert len(set(session_function_selectors.values())) == len(
        session_function_selectors
    )
    assert len(set(router_session_gate_selectors.values())) == len(
        router_session_gate_selectors
    )
    assert not (
        set(session_function_selectors.values())
        & set(router_session_gate_selectors.values())
    )
    assert len(set(session_event_topics.values())) == len(session_event_topics)
    body = body_root((bytes.fromhex("0102"), bytes.fromhex("030405")))
    chunk0, chunk1 = b"alpha", b"beta"
    c0, c1 = chunk_root(body, 0, 0, 2, chunk0), chunk_root(body, 0, 1, 2, chunk1)
    leaf0 = data_leaf(sid, 0, bytes.fromhex("33" * 32), body, 0, 0, 2,
                      chunk0, 0xCAFE, 9_999, 5, 6)
    leaf1 = data_leaf(sid, 1, bytes.fromhex("55" * 32), body, 0, 1, 2,
                      chunk1, 0xCAFE, 9_999, 7, 8)
    mmr_frontier = tuple(bytes(32) for _ in range(12))
    mmr_frontier = append_mmr_frontier(mmr_frontier, 0, leaf0)
    mmr_frontier = append_mmr_frontier(mmr_frontier, 1, leaf1)
    assert mmr_frontier_root(mmr_frontier, 2) == mmr_root((leaf0, leaf1))
    manifest = manifest_root((
        ManifestEntry(0, sid, 0, 0, 2, len(chunk0), body, c0),
        ManifestEntry(0, sid, 1, 1, 2, len(chunk1), body, c1),
    ))
    manifest_block_1 = manifest_root((
        ManifestEntry(1, sid, 0, 0, 2, len(chunk0), body, c0),
        ManifestEntry(1, sid, 1, 1, 2, len(chunk1), body, c1),
    ))
    empty_terminal = TerminalVector(())
    version_base_core = CanonicalCoreV2(
        8_000, bytes.fromhex("77" * 32), 8_000,
        bytes.fromhex("66" * 32), 2, manifest, 100, 0,
        empty_terminal.root, 0)
    core = canonical_core_v2_hash(version_base_core)
    base = base_canonical(core, 1_000)
    schedules_hash = schedule_list(((20, ent_root, bytes.fromhex("12" * 32)),))
    sessions_hash = session_list(((sid, 2, mmr_root((leaf0, leaf1))),))
    outputs_hash = execution_outputs(bytes.fromhex("66" * 32),
                                     bytes.fromhex("13" * 32),
                                     bytes.fromhex("14" * 32),
                                     bytes.fromhex("15" * 32),
                                     bytes.fromhex("16" * 32),
                                     empty_terminal.root, 0)
    context = normal_context(base, 12, adm_root, 1_000, bytes.fromhex("99" * 32))
    block_values = (
        settlement_chain_id, l2_chain_id, 2, contract,
        8_001, bytes.fromhex("77" * 32),
        bytes.fromhex("88" * 32), bytes.fromhex("66" * 32), body, 1_000,
        bytes.fromhex("99" * 32), force.root, len(envs), 2, 66, manifest,
        0xCAFE, 1, context, 12, adm_root, 0, 0, bytes(32),
    )
    block_struct = block_struct_hash(block_values)
    candidate_hash = candidate_commitment(base, ((8_001, block_struct,
                                                   bytes.fromhex("88" * 32),
                                                   body, manifest, 66),))
    candidate_hash_2 = candidate_commitment(base, (
        (8_001, block_struct, bytes.fromhex("88" * 32), body, manifest, 66),
        (8_002, bytes.fromhex("43" * 32), bytes.fromhex("44" * 32), body,
         manifest_block_1, 67),
    ))
    winning = winning_data(candidate_hash, sessions_hash)
    forced_descriptors = force_descriptor_list(
        2,
        tuple((0, forced_descriptor(envs[i])) for i in range(2, 66)),
        (0, forced_descriptor(envs[66])),
    )
    statement_values = (
        settlement_chain_id, l2_chain_id, 2, profile_hash, contract,
        2, bytes.fromhex("b7" * 32), 1, base,
        candidate_hash, 1, 8_001, bytes.fromhex("88" * 32), 8_001, 8_001,
        bytes.fromhex("66" * 32), empty_terminal.root, 0, 66,
        winning, envs[66].due_at,
        101, 0, 1_000, bytes.fromhex("99" * 32), bytes.fromhex("aa" * 32), 999,
        force.root, len(envs), forced_descriptors, 2, 12, adm_root,
        0, 0, bytes(32), schedules_hash, 1,
        sessions_hash, 1, 2, outputs_hash, 0xCAFE,
    )
    bridge_kernel = bridge_kernel_profile_hash(
        bytes.fromhex("2a" * 32), bytes.fromhex("2b" * 32),
        bytes.fromhex("2c" * 32))
    (timelock_descriptor, timelock_descriptor_hash, manager_config,
     manager_descriptor, manager_descriptor_hash) = fixture_protocol_authority()
    infrastructure_components = derived_release_authority.destination_components
    _unused_fixture_deployment, successor_deployment_descriptor = (
        fixture_settlement_deployment_descriptors())
    target_deployment_descriptor = (
        derived_release_authority.settlement_deployment_descriptor)
    target_settlement = target_deployment_descriptor.target_settlement
    successor_settlement = successor_deployment_descriptor.target_settlement
    source_bridge_descriptor = derived_release_authority.source_bridge_descriptor
    validate_source_terminal_verifier_binding(
        source_bridge_descriptor, infrastructure_components[2])
    source_bridge_address = source_bridge_descriptor.source_bridge
    canonical_source_descriptor = canonical_source_bridge_descriptor(
        source_bridge_descriptor)
    assert (source_bridge_descriptor.bundle_deployer == create2_address(
                source_bridge_descriptor.factory,
                source_bridge_descriptor.bundle_salt,
                source_bridge_descriptor.bundle_init_code_hash)
            and source_bridge_address == create_address_from_nonce(
                source_bridge_descriptor.bundle_deployer, 1)
            and source_bridge_descriptor.credit_registry
                == create_address_from_nonce(
                    source_bridge_descriptor.bundle_deployer, 2)
            and source_bridge_descriptor.quota_manager
                == create_address_from_nonce(
                    source_bridge_descriptor.bundle_deployer, 3))
    for superseded_descriptor_length in (572, 700, 764):
        assert_rejects(
            lambda length=superseded_descriptor_length:
                validate_source_bridge_descriptor_encoding(
                    source_bridge_descriptor, bytes(length)),
            "superseded source descriptor accepted")
    for derivation_substitution in (
        replace(source_bridge_descriptor,
                factory=source_bridge_descriptor.factory + 1),
        replace(source_bridge_descriptor,
                bundle_salt=bytes.fromhex("a0" * 32)),
        replace(source_bridge_descriptor,
                bundle_init_code_hash=bytes.fromhex("a1" * 32)),
        replace(source_bridge_descriptor,
                bundle_deployer=source_bridge_descriptor.bundle_deployer + 1),
        replace(source_bridge_descriptor,
                source_bridge=source_bridge_address + 1),
        replace(source_bridge_descriptor,
                credit_registry=source_bridge_descriptor.credit_registry + 1),
        replace(source_bridge_descriptor,
                quota_manager=source_bridge_descriptor.quota_manager + 1),
    ):
        assert_rejects(
            lambda descriptor=derivation_substitution:
                canonical_source_bridge_descriptor(descriptor),
            "substituted atomic-bundle derivation accepted")
    for changed_source_identity in (
        replace(source_bridge_descriptor,
                factory_runtime_hash=bytes.fromhex("a4" * 32)),
        replace(source_bridge_descriptor,
                factory_configuration_hash=bytes.fromhex("a5" * 32)),
        replace(source_bridge_descriptor,
                bundle_deployer_runtime_hash=bytes.fromhex("a3" * 32)),
        replace(source_bridge_descriptor,
                bridge_runtime_hash=bytes.fromhex("a6" * 32)),
        replace(source_bridge_descriptor,
                bridge_config_hash=bytes.fromhex("a7" * 32)),
        replace(source_bridge_descriptor,
                registry_runtime_hash=bytes.fromhex("a8" * 32)),
        replace(source_bridge_descriptor,
                registry_config_hash=bytes.fromhex("a9" * 32)),
        replace(source_bridge_descriptor,
                quota_runtime_hash=bytes.fromhex("aa" * 32)),
        replace(source_bridge_descriptor,
                quota_config_hash=bytes.fromhex("ab" * 32)),
        replace(source_bridge_descriptor,
                support_registry_runtime_hash=bytes.fromhex("ac" * 32)),
        replace(source_bridge_descriptor,
                support_registry_configuration_hash=bytes.fromhex("ad" * 32)),
        replace(source_bridge_descriptor,
                terminal_verifier_runtime_hash=bytes.fromhex("ae" * 32)),
        replace(source_bridge_descriptor,
                terminal_verifier_config_hash=bytes.fromhex("af" * 32)),
    ):
        assert (bridge_execution_hash(changed_source_identity)
                != bridge_execution_hash(source_bridge_descriptor))
    for colliding_source_account in (
        replace(source_bridge_descriptor,
                legacy_v1_bridge=source_bridge_descriptor.factory),
        replace(source_bridge_descriptor,
                bundle_deployer=source_bridge_descriptor.factory),
        replace(source_bridge_descriptor,
                source_bridge=source_bridge_descriptor.legacy_v1_bridge),
        replace(source_bridge_descriptor,
                credit_registry=source_bridge_descriptor.source_bridge),
        replace(source_bridge_descriptor,
                quota_manager=source_bridge_descriptor.credit_registry),
    ):
        assert_rejects(
            lambda descriptor=colliding_source_account:
                canonical_source_bridge_descriptor(descriptor),
            "colliding source CREATE2 account accepted")
    for mismatched_terminal_descriptor in (
        replace(source_bridge_descriptor, terminal_verifier=0xD102),
        replace(source_bridge_descriptor,
                terminal_verifier_runtime_hash=bytes.fromhex("98" * 32)),
        replace(source_bridge_descriptor,
                terminal_verifier_config_hash=bytes.fromhex("99" * 32)),
    ):
        assert_rejects(
            lambda descriptor=mismatched_terminal_descriptor:
                validate_source_terminal_verifier_binding(
                    descriptor, infrastructure_components[2]),
            "mismatched source terminal verifier binding accepted")
    source_configuration_identities = (
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash),
        (source_bridge_descriptor.bridge_runtime_hash,
         source_bridge_descriptor.bridge_config_hash),
        (source_bridge_descriptor.registry_runtime_hash,
         source_bridge_descriptor.registry_config_hash),
        (source_bridge_descriptor.quota_runtime_hash,
         source_bridge_descriptor.quota_config_hash),
        (source_bridge_descriptor.support_registry_runtime_hash,
         source_bridge_descriptor.support_registry_configuration_hash),
        (source_bridge_descriptor.terminal_verifier_runtime_hash,
         source_bridge_descriptor.terminal_verifier_config_hash),
    )
    for runtime_hash, configuration_hash in source_configuration_identities:
        assert validate_component_config_getter(
            runtime_hash, runtime_hash, configuration_hash,
            COMPONENT_CONFIG_GETTER_SELECTOR,
            COMPONENT_CONFIG_GETTER_GAS_LIMIT,
            configuration_hash) == configuration_hash
    for invalid_component_getter in (
        (source_bridge_descriptor.factory_runtime_hash, bytes.fromhex("b0" * 32),
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT,
         source_bridge_descriptor.factory_configuration_hash),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash, bytes.fromhex("00000000"),
         COMPONENT_CONFIG_GETTER_GAS_LIMIT,
         source_bridge_descriptor.factory_configuration_hash),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT - 1,
         source_bridge_descriptor.factory_configuration_hash),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT, b""),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT,
         source_bridge_descriptor.factory_configuration_hash[:-1]),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT,
         source_bridge_descriptor.factory_configuration_hash + b"\x00"),
        (source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_runtime_hash,
         source_bridge_descriptor.factory_configuration_hash,
         COMPONENT_CONFIG_GETTER_SELECTOR, COMPONENT_CONFIG_GETTER_GAS_LIMIT,
         bytes.fromhex("b1" * 32)),
    ):
        assert_rejects(
            lambda values=invalid_component_getter:
                validate_component_config_getter(*values),
            "malformed source component config getter accepted")
    bridge_execution = bridge_execution_hash(source_bridge_descriptor)
    source_domain = source_domain_id(
        1, bytes.fromhex("25" * 32), source_bridge_descriptor.credit_registry,
        source_bridge_descriptor.terminal_verifier, source_bridge_address,
        bridge_execution, bytes.fromhex("26" * 32))
    infrastructure = destination_infrastructure_hash(infrastructure_components)
    destination_bridge_descriptor = DestinationBridgeDescriptor(
        0xB200, infrastructure_components[9].runtime_hash,
        infrastructure_components[9].config_hash, bytes.fromhex("42" * 32),
        bridge_kernel, 0x5101, 0x5102, 0x5103, 0x5107, 0x5104)
    destination_bridge_execution = destination_bridge_execution_hash(
        destination_bridge_descriptor)
    destination_domain = destination_domain_id(
        l2_chain_id, bytes.fromhex("35" * 32), 0xAD00, 0xAD01,
        0xD101, 0x5100, 0x5101, 0x5106, 0x5103, 0x5102, 0x5104, 0xB200,
        destination_bridge_execution, infrastructure, bytes.fromhex("36" * 32))
    migration_verifier = MigrationVerifierDescriptor(
        0x6001, bytes.fromhex("71" * 32), bytes(32), bytes.fromhex("72" * 32),
        bytes.fromhex("73" * 32), MIGRATION_TRANSITION_STATEMENT_TYPEHASH,
        keccak256(b"verifyMigrationTransition(bytes,uint256[2])")[:4],
        131_072, 4_000_000)
    migration_verifier = replace(
        migration_verifier,
        configuration_hash=_migration_verifier_configuration_hash(
            migration_verifier))
    migration_verifier_config = migration_verifier_configuration_hash(
        migration_verifier)
    migration_verifier_descriptor = migration_verifier_descriptor_hash(
        migration_verifier)
    migration_activation_profile = MigrationActivationProfileRecordV2(
        2, profile_hash, bytes(32), migration_verifier.verifier,
        migration_verifier.runtime_hash, migration_verifier.configuration_hash,
        migration_verifier.verifying_key_hash,
        migration_verifier.proof_system_id,
        migration_verifier.public_input_schema_hash,
        migration_verifier.selector, migration_verifier.maximum_proof_bytes,
        migration_verifier.verification_gas_limit, 30_000_000, 20_000_000,
        1_000_000, 2_000_000, 3_000_000, 100_000, 100_000, 100_000,
        200_000, 200_000, 500_000)
    migration_activation_profile = replace(
        migration_activation_profile,
        activation_profile_record_hash=migration_activation_profile_record_hash(
            migration_activation_profile))
    successor_migration_activation_profile = replace(
        migration_activation_profile, protocol_version=3,
        activation_profile_record_hash=bytes(32))
    successor_migration_activation_profile = replace(
        successor_migration_activation_profile,
        activation_profile_record_hash=migration_activation_profile_record_hash(
            successor_migration_activation_profile))
    assert migration_verifier_config != migration_verifier_descriptor
    for changed_identity in (
        replace(migration_verifier, verifier=0x6002),
        replace(migration_verifier, runtime_hash=bytes.fromhex("75" * 32)),
    ):
        assert (migration_verifier_configuration_hash(changed_identity)
                == migration_verifier_config)
        assert (migration_verifier_descriptor_hash(changed_identity)
                != migration_verifier_descriptor)
    for changed_configuration_without_hash in (
        replace(migration_verifier,
                verifying_key_hash=bytes.fromhex("76" * 32)),
        replace(migration_verifier,
                proof_system_id=bytes.fromhex("77" * 32)),
        replace(migration_verifier,
                public_input_schema_hash=bytes.fromhex("78" * 32)),
        replace(migration_verifier, selector=bytes.fromhex("01020304")),
        replace(migration_verifier, maximum_proof_bytes=131_071),
        replace(migration_verifier, verification_gas_limit=3_999_999),
    ):
        changed_configuration = replace(
            changed_configuration_without_hash,
            configuration_hash=_migration_verifier_configuration_hash(
                changed_configuration_without_hash))
        assert (migration_verifier_configuration_hash(changed_configuration)
                != migration_verifier_config)
        assert (migration_verifier_descriptor_hash(changed_configuration)
                != migration_verifier_descriptor)
    ingress_fees = ((1 << 80) + 17, (1 << 64) + 19,
                    (1 << 64) + 23, (1 << 72) + 29, 1 << 128)
    ingress_common = dict(
        active_settlement_router=0xAD01,
        router_runtime_hash=infrastructure_components[1].runtime_hash,
        router_configuration_hash=infrastructure_components[1].config_hash,
        forced_queue=0xF000, queue_runtime_hash=bytes.fromhex("5a" * 32),
        queue_configuration_hash=forced_queue_config_hash(0xAD01),
        destination_chain_id=(1 << 255) + l2_chain_id,
        fixed_ingress_wei=ingress_fees[0],
        execution_wei_per_accounted_gas=ingress_fees[1],
        proof_wei_per_accounted_gas=ingress_fees[2],
        permanent_wei_per_byte=ingress_fees[3],
        maximum_accepted_fee_wei=ingress_fees[4])
    kind0_ingress = ProfileIngressAuthorizationV2(
        kind=0, adapter=0xAD10, adapter_runtime_hash=bytes.fromhex("91" * 32),
        adapter_configuration_hash=bytes.fromhex("92" * 32),
        source_domain_id=bytes(32), source_registration_epoch=0,
        source_bridge_execution_hash=bytes(32),
        destination_domain_id=bytes(32), destination_bridge=0,
        destination_bridge_execution_hash=bytes(32),
        destination_infrastructure_hash=bytes(32), **ingress_common)
    kind1_ingress = ProfileIngressAuthorizationV2(
        kind=1, adapter=0xAD11, adapter_runtime_hash=bytes.fromhex("93" * 32),
        adapter_configuration_hash=bytes.fromhex("94" * 32),
        source_domain_id=source_domain, source_registration_epoch=7,
        source_bridge_execution_hash=bridge_execution,
        destination_domain_id=destination_domain, destination_bridge=0xB200,
        destination_bridge_execution_hash=destination_bridge_execution,
        destination_infrastructure_hash=infrastructure, **ingress_common)
    ingress_graph = IngressProfileGraphV2(
        0xAD01, infrastructure_components[1].runtime_hash,
        infrastructure_components[1].config_hash, 0xF000,
        bytes.fromhex("5a" * 32), forced_queue_config_hash(0xAD01),
        source_domain, 7, bridge_execution, (1 << 255) + l2_chain_id,
        destination_domain, 0xB200, destination_bridge_execution,
        infrastructure, 0xAD10, bytes.fromhex("91" * 32),
        bytes.fromhex("92" * 32), 0xAD11, bytes.fromhex("93" * 32),
        bytes.fromhex("94" * 32))
    # The strict REGISTER_RELEASE authority is reconstructed solely from the
    # profile.  The synthetic graph above remains an independent codec corpus;
    # it is not permitted to populate the release journal.
    kind0_ingress, kind1_ingress = derived_release_authority.ingress_rows
    ingress_root = derived_release_authority.ingress_authorization_root
    ingress_graph = IngressProfileGraphV2(
        kind0_ingress.active_settlement_router,
        kind0_ingress.router_runtime_hash,
        kind0_ingress.router_configuration_hash,
        kind0_ingress.forced_queue,
        kind0_ingress.queue_runtime_hash,
        kind0_ingress.queue_configuration_hash,
        kind1_ingress.source_domain_id,
        kind1_ingress.source_registration_epoch,
        kind1_ingress.source_bridge_execution_hash,
        kind0_ingress.destination_chain_id,
        kind1_ingress.destination_domain_id,
        kind1_ingress.destination_bridge,
        kind1_ingress.destination_bridge_execution_hash,
        kind1_ingress.destination_infrastructure_hash,
        kind0_ingress.adapter,
        kind0_ingress.adapter_runtime_hash,
        kind0_ingress.adapter_configuration_hash,
        kind1_ingress.adapter,
        kind1_ingress.adapter_runtime_hash,
        kind1_ingress.adapter_configuration_hash)
    migration_activation_profile = (
        derived_release_authority.migration_activation_profile)
    migration_verifier_descriptor = (
        derived_release_authority.migration_verifier_descriptor_hash)
    infrastructure = derived_release_authority.destination_infrastructure_hash
    destination_domain = derived_release_authority.destination_domain_id
    destination_bridge_descriptor = (
        derived_release_authority.destination_bridge_descriptor)
    destination_bridge_execution = (
        derived_release_authority.destination_bridge_execution_hash)
    release_manifest = derived_release_authority.release_manifest
    release_hash = release_manifest_hash(release_manifest)
    successor_release_manifest = replace(release_manifest, protocol_version=3)
    successor_release_hash = release_manifest_hash(successor_release_manifest)
    registration = destination_registration_commitment(
        release_manifest.protocol_version, release_hash,
        release_manifest.destination_chain_id,
        release_manifest.destination_namespace, destination_domain,
        release_manifest.destination_bridge, infrastructure, profile_hash)
    components_commitment = manifest_components_hash(infrastructure_components)
    target_deployment_descriptor_hash = settlement_deployment_descriptor_hash(
        target_deployment_descriptor)
    successor_deployment_descriptor_hash = (
        settlement_deployment_descriptor_hash(successor_deployment_descriptor))
    target_registration_hash = target_registration_v2_hash(
        0, release_manifest, target_deployment_descriptor,
        migration_activation_profile.activation_profile_record_hash)
    successor_registration_hash = target_registration_v2_hash(
        2, successor_release_manifest, successor_deployment_descriptor,
        successor_migration_activation_profile.activation_profile_record_hash)
    settlement_authorization = SettlementAuthorizationV1(
        release_manifest.protocol_version, target_settlement,
        target_deployment_descriptor.target_runtime_hash,
        target_deployment_descriptor.target_configuration_hash,
        SEAT_TARGET_EXPECTED_MAGIC, target_registration_hash)
    settlement_authorization_hash = settlement_authorization_id(
        settlement_chain_id, manager_config.aggregator_seat_market,
        settlement_chain_id, settlement_authorization)
    install_settlement_authorization_calldata = (
        encode_install_settlement_authorization_calldata(
            settlement_authorization))
    install_settlement_authorization_return = (
        encode_install_settlement_authorization_return(
            settlement_authorization_hash))
    settlement_authorization_calldata = (
        encode_settlement_authorization_calldata(
            settlement_authorization_hash))
    settlement_authorization_return = encode_settlement_authorization_return(
        settlement_authorization)
    genesis_deployment = DeploymentCommitmentV2(
        1, 2, release_hash, target_registration_hash,
        infrastructure, components_commitment,
        infrastructure_components[8].config_hash, 0,
        deployment_prestate_policy_hash(1),
        deployment_poststate_policy_hash(1))
    genesis_deployment_hash = deployment_commitment_hash(genesis_deployment)
    version_deployment = DeploymentCommitmentV2(
        2, 3, successor_release_hash, successor_registration_hash,
        infrastructure,
        components_commitment, infrastructure_components[8].config_hash,
        len(envs), deployment_prestate_policy_hash(2),
        deployment_poststate_policy_hash(2))
    version_deployment_hash = deployment_commitment_hash(version_deployment)
    imported_header_hash = bytes.fromhex("82" * 32)
    imported_state_root = bytes.fromhex("83" * 32)
    imported_header_number = 1_234
    empty_queue_root = ForceVector(()).root
    empty_forced_descriptors = force_descriptor_list(0, (), None)
    empty_inbox_rows: tuple[InboxRowV2, ...] = ()
    version_inbox_rows = tuple(
        InboxRowV2(index, 0, UINT32_MAX, bytes(32), b"")
        for index in range(2, 66))
    genesis_inbox_apply_calldata = encode_inbox_apply_calldata(
        0, empty_inbox_rows)
    version_inbox_apply_calldata = encode_inbox_apply_calldata(
        2, version_inbox_rows)
    genesis_release_system_calldata = bytes.fromhex("7e01")
    version_release_system_calldata = bytes.fromhex("7e02")
    genesis_release_system_tx = b"\x7e" + genesis_release_system_calldata
    version_release_system_tx = b"\x7e" + version_release_system_calldata
    genesis_inbox_system_tx = b"\x7e" + genesis_inbox_apply_calldata
    version_inbox_system_tx = b"\x7e" + version_inbox_apply_calldata
    genesis_base_data = migration_data(
        settlement_chain_id, l2_chain_id, imported_header_hash,
        imported_state_root, empty_terminal.root, 0)
    genesis_base_core = CanonicalCoreV2(
        imported_header_number, imported_header_hash, imported_header_number,
        imported_state_root, 0, genesis_base_data, 100, 0,
        empty_terminal.root, 0)
    genesis_base = base_canonical(
        canonical_core_v2_hash(genesis_base_core), 1_000)
    genesis_block_hash = bytes.fromhex("78" * 32)
    genesis_block_body = body_root(())
    genesis_block_manifest = manifest_root(())
    genesis_candidate_hash = candidate_commitment(
        genesis_base,
        ((imported_header_number + 1,
          keccak256(b"slot-chain-genesis-block-struct-fixture-v1"),
          genesis_block_hash, genesis_block_body, genesis_block_manifest, 0),))
    genesis_winning = winning_data(genesis_candidate_hash, session_list(()))
    genesis_output_core = CanonicalCoreV2(
        imported_header_number + 1, genesis_block_hash,
        imported_header_number + 1, bytes.fromhex("79" * 32), 0,
        genesis_winning, 101, 0, empty_terminal.root, 0)
    version_output_core = CanonicalCoreV2(
        8_001, bytes.fromhex("77" * 32), 8_001,
        bytes.fromhex("66" * 32), 66, winning, 101, 0,
        empty_terminal.root, 0)
    checkpoint_hash = legacy_signal_checkpoint_hash(
        imported_header_number, imported_header_hash, imported_state_root)
    legacy_inbox_config = LegacyInboxConfigV1(
        0x6600, 0x6700, 0, 0x6300, 0x6200,
        0, 0, 604_800, 14_400, 432_000, 180, 21_600, 20,
        576, 1_000_000, 50, 160)
    legacy_inbox_config_hash = legacy_inbox_configuration_hash(
        legacy_inbox_config)
    legacy_inbox_config_return = encode_legacy_inbox_config_return(
        legacy_inbox_config)
    legacy_deployment_hash = legacy_genesis_deployment_hash(
        settlement_chain_id, 0x6100, bytes.fromhex("a0" * 32), 0x6101,
        bytes.fromhex("a1" * 32), legacy_inbox_config_hash, 0xAD01)
    legacy_campaign_fence_descriptor_hash = (
        legacy_genesis_campaign_fence_descriptor_hash(0xAD01, 0x6100))
    legacy_risc0_adapter = 0x6400
    legacy_risc0_adapter_runtime_hash = keccak256(
        b"legacy-risc0-adapter-runtime-fixture-v1")
    legacy_risc0_remote_verifier = 0x6401
    legacy_risc0_remote_runtime_hash = keccak256(
        b"legacy-risc0-remote-runtime-fixture-v1")
    legacy_sp1_adapter = 0x6500
    legacy_sp1_adapter_runtime_hash = keccak256(
        b"legacy-sp1-adapter-runtime-fixture-v1")
    legacy_sp1_remote_verifier = 0x6501
    legacy_sp1_remote_runtime_hash = keccak256(
        b"legacy-sp1-remote-runtime-fixture-v1")
    legacy_risc0_key_args = (
        keccak256(b"legacy-risc0-block-image-id-fixture-v1"),
        keccak256(b"legacy-risc0-aggregation-image-id-fixture-v1"))
    legacy_sp1_key_args = (
        keccak256(b"legacy-sp1-block-program-vkey-fixture-v1"),
        keccak256(b"legacy-sp1-aggregation-program-vkey-fixture-v1"))
    legacy_risc0_resume_key_policy_hash = (
        legacy_genesis_risc0_resume_key_policy_hash(*legacy_risc0_key_args))
    legacy_sp1_resume_key_policy_hash = (
        legacy_genesis_sp1_resume_key_policy_hash(*legacy_sp1_key_args))
    legacy_risc0_descriptor_args = (
        legacy_risc0_adapter, legacy_risc0_adapter_runtime_hash, l2_chain_id,
        legacy_risc0_remote_verifier, legacy_risc0_remote_runtime_hash,
        legacy_risc0_resume_key_policy_hash)
    legacy_risc0_reth_verifier_descriptor_hash = (
        legacy_genesis_risc0_reth_verifier_descriptor_hash(
            *legacy_risc0_descriptor_args))
    legacy_sp1_descriptor_args = (
        legacy_sp1_adapter, legacy_sp1_adapter_runtime_hash, l2_chain_id,
        legacy_sp1_remote_verifier, legacy_sp1_remote_runtime_hash,
        legacy_sp1_resume_key_policy_hash)
    legacy_sp1_reth_verifier_descriptor_hash = (
        legacy_genesis_sp1_reth_verifier_descriptor_hash(
            *legacy_sp1_descriptor_args))
    legacy_proof_verifier_graph_args = (
        0x6600, keccak256(b"legacy-fixed-pair-root-runtime-fixture-v1"),
        legacy_risc0_adapter, legacy_risc0_reth_verifier_descriptor_hash,
        legacy_sp1_adapter, legacy_sp1_reth_verifier_descriptor_hash)
    legacy_proof_verifier_graph_hash = (
        legacy_genesis_proof_verifier_graph_hash(
            *legacy_proof_verifier_graph_args))
    legacy_resume_verifier_route_hash = (
        legacy_genesis_resume_verifier_route_hash(
            legacy_proof_verifier_graph_hash,
            legacy_risc0_reth_verifier_descriptor_hash,
            legacy_risc0_resume_key_policy_hash,
            legacy_sp1_reth_verifier_descriptor_hash,
            legacy_sp1_resume_key_policy_hash))
    legacy_proposer_checker_descriptor_args = (
        0x6700, keccak256(b"legacy-proposer-proxy-runtime-fixture-v1"),
        0x6701, keccak256(b"legacy-proposer-implementation-runtime-fixture-v1"),
        legacy_campaign_fence_descriptor_hash)
    legacy_proposer_checker_descriptor_hash = (
        legacy_genesis_proposer_checker_descriptor_hash(
            *legacy_proposer_checker_descriptor_args))
    legacy_prover_whitelist_descriptor_hash = (
        legacy_genesis_prover_whitelist_descriptor_hash())
    legacy_checkpoint_storage_layout_hash = (
        legacy_genesis_checkpoint_storage_layout_hash())
    legacy_signal_service_descriptor_args = (
        0x6300, keccak256(b"legacy-signal-proxy-runtime-fixture-v1"),
        0x6301, keccak256(b"legacy-signal-implementation-runtime-fixture-v1"),
        1, 0x6100, 0x6302, 0x6303,
        legacy_checkpoint_storage_layout_hash,
        legacy_campaign_fence_descriptor_hash)
    legacy_signal_service_checkpoint_descriptor_hash = (
        legacy_genesis_signal_service_checkpoint_descriptor_hash(
            *legacy_signal_service_descriptor_args))
    legacy_resume_verifier_config_return = (
        encode_legacy_resume_verifier_config_return(
            legacy_risc0_adapter, legacy_sp1_adapter,
            legacy_risc0_resume_key_policy_hash,
            legacy_sp1_resume_key_policy_hash))
    legacy_resume_risc0_config_return = (
        encode_legacy_resume_risc0_config_return(
            l2_chain_id, legacy_risc0_remote_verifier,
            legacy_risc0_remote_runtime_hash, *legacy_risc0_key_args))
    legacy_resume_sp1_config_return = encode_legacy_resume_sp1_config_return(
        l2_chain_id, legacy_sp1_remote_verifier,
        legacy_sp1_remote_runtime_hash, *legacy_sp1_key_args)
    legacy_checkpoint_config_return = encode_legacy_checkpoint_config_return(
        0x6100, 0x6302, 0x6303, legacy_checkpoint_storage_layout_hash,
        legacy_campaign_fence_descriptor_hash)
    legacy_proposer_impl_return = encode_legacy_address_getter_return(0x6701)
    legacy_signal_impl_return = encode_legacy_address_getter_return(0x6301)
    legacy_operator_count_return = encode_legacy_operator_count_return(3)
    legacy_current_operator_return = encode_legacy_address_getter_return(
        0x6710)
    legacy_next_operator_return = encode_legacy_address_getter_return(0x6711)
    legacy_signal_version_return = (
        encode_legacy_signal_service_version_return())
    legacy_resume_profile = LegacyGenesisResumeProfileV1(
        legacy_deployment_hash, legacy_campaign_fence_descriptor_hash,
        legacy_proof_verifier_graph_hash,
        legacy_resume_verifier_route_hash,
        legacy_signal_service_checkpoint_descriptor_hash,
        legacy_proposer_checker_descriptor_hash,
        legacy_prover_whitelist_descriptor_hash,
        0, 0, 604_800, 14_400, 432_000, 180, 21_600, 576,
        1_000_000, 50, 160,
        LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL,
        LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL, 1_572_864, 900)
    legacy_resume_profile_hash = legacy_genesis_resume_profile_hash(
        legacy_resume_profile)
    legacy_review_commitment = legacy_genesis_review_commitment(
        legacy_deployment_hash, legacy_resume_profile_hash, 2,
        release_hash, target_registration_hash)
    legacy_campaign_unbound = LegacyGenesisCampaignV1(
        1, 7, 1, 1_000, 1_100, 1_400, 2_000, 7_000, 900,
        target_settlement, 2, release_hash, target_registration_hash,
        legacy_review_commitment, bytes(32))
    legacy_campaign = replace(
        legacy_campaign_unbound,
        campaign_id=legacy_genesis_campaign_id(
            legacy_deployment_hash, legacy_campaign_unbound))
    legacy_campaign_return = encode_legacy_genesis_campaign_return(
        legacy_campaign, legacy_deployment_hash)
    register_release_payload = RegisterReleasePayloadV1(
        0, release_manifest, target_deployment_descriptor, profile_bytes)
    register_release_payload_abi = encode_register_release_payload(
        register_release_payload)
    register_fork_payload = RegisterForkVerifierPayloadV1(
        bytes.fromhex("46554c55"), 2_048, 0x6800,
        bytes.fromhex("68" * 32), 8, 201, 6_434, 6_437, 6_441, 6_444,
        bytes.fromhex("67" * 32), bytes(32),
        bytes.fromhex("7e981e0b"), 4_000_000)
    register_fork_payload = replace(
        register_fork_payload,
        configuration_hash=schedule_fork_verifier_configuration_hash(
            register_fork_payload))
    register_fork_payload_abi = encode_register_fork_verifier_payload(
        register_fork_payload)
    publish_genesis_payload = PublishGenesisCampaignPayloadV1(
        legacy_campaign.force_cutoff_block,
        legacy_campaign.proposal_cutoff_block,
        legacy_campaign.quiesce_not_before_block,
        legacy_campaign.resume_by_block,
        legacy_campaign.resume_by_timestamp,
        legacy_campaign.review_finalized_by_block,
        target_settlement, 2, release_hash, target_registration_hash)
    publish_genesis_payload_abi = encode_publish_genesis_campaign_payload(
        publish_genesis_payload)
    publish_migration_payload = PublishMigrationArmPayloadV1(
        2, 3, successor_release_hash, successor_registration_hash)
    publish_migration_payload_abi = encode_publish_migration_arm_payload(
        publish_migration_payload)
    protocol_change_payloads = (
        register_release_payload_abi, register_fork_payload_abi,
        publish_genesis_payload_abi, publish_migration_payload_abi)
    protocol_change_operations = tuple(
        ProtocolChangeOperationIdentityV1(
            settlement_chain_id, timelock_descriptor.protocol_change_timelock,
            manager_descriptor.protocol_version_manager, index, index, payload)
        for index, payload in enumerate(protocol_change_payloads, 1))
    protocol_change_operation_ids = tuple(
        protocol_change_operation_id(operation)
        for operation in protocol_change_operations)
    protocol_change_timelock_config_return = (
        encode_protocol_change_timelock_config_return(
            timelock_descriptor.dao_proposer,
            manager_descriptor.protocol_version_manager))
    protocol_version_manager_config_return = (
        encode_protocol_version_manager_config_return(manager_config))
    queued_migration_operation = ProtocolChangeOperationRowV1(
        1, 4, 4, len(publish_migration_payload_abi),
        keccak256(publish_migration_payload_abi), 10_000,
        10_000 + PROTOCOL_CHANGE_DELAY_SECONDS)
    queued_migration_operation_return = encode_protocol_change_operation_return(
        queued_migration_operation)
    empty_protocol_change_operation_return = (
        encode_protocol_change_operation_return(
            ProtocolChangeOperationRowV1(
                0, 0, 0, 0, bytes(32), 0, 0)))
    protocol_change_operation_calldata = (
        encode_protocol_change_operation_calldata(
            protocol_change_operation_ids[3]))
    queue_protocol_change_calldata = encode_queue_protocol_change_calldata(
        1, register_release_payload_abi)
    execute_protocol_change_calldata = encode_execute_protocol_change_calldata(
        2, 2, register_fork_payload_abi)
    cancel_protocol_change_calldata = encode_cancel_protocol_change_calldata(
        3, 3, publish_genesis_payload_abi)
    apply_protocol_change_calldata = encode_apply_protocol_change_calldata(
        4, 4, publish_migration_payload_abi)
    version_migration_lease = create_version_migration_lease(
        settlement_chain_id, manager_descriptor.protocol_version_manager,
        2, 2, 3, successor_release_hash, successor_registration_hash,
        20_000, protocol_change_operation_ids[3])
    version_migration_lease_return = (
        encode_live_version_migration_lease_return(version_migration_lease))
    empty_version_migration_lease_return = (
        encode_live_version_migration_lease_return(VersionMigrationLeaseV1(
            0, 0, 0, 0, bytes(32), bytes(32), bytes(32), 0, 0)))
    target_release_registration = TargetReleaseRegistrationV2(
        2, 0, target_settlement,
        target_deployment_descriptor.target_runtime_hash,
        target_deployment_descriptor.target_configuration_hash,
        target_deployment_descriptor_hash, profile_hash,
        migration_activation_profile.activation_profile_record_hash,
        derived_release_authority.data_session_configuration_hash,
        release_hash,
        target_registration_hash)
    register_target_release_calldata = encode_register_target_release_calldata(
        register_release_payload)
    register_target_release_return = encode_register_target_release_return(
        release_hash, target_registration_hash)
    target_release_registration_calldata = (
        encode_target_release_registration_calldata(2))
    target_release_registration_return = (
        encode_target_release_registration_return(target_release_registration))
    migration_activation_profile_calldata = (
        encode_migration_activation_profile_calldata(2))
    migration_activation_profile_return = (
        encode_migration_activation_profile_return(
            migration_activation_profile))
    profile_ingress_root_calldata = encode_profile_ingress_root_calldata(2)
    profile_ingress_root_return = encode_profile_ingress_root_return(
        2, 2, ingress_root)
    profile_ingress_authorization_calldata = tuple(
        encode_profile_ingress_authorization_calldata(
            ingress_authorization_id(row))
        for row in (kind0_ingress, kind1_ingress))
    profile_ingress_authorization_returns = tuple(
        encode_profile_ingress_authorization_return(row)
        for row in (kind0_ingress, kind1_ingress))
    install_fork_verifier_calldata = encode_install_fork_verifier_calldata(
        register_fork_payload)
    install_fork_verifier_return = encode_install_fork_verifier_return(
        register_fork_payload.fork_digest, register_fork_payload.first_window)
    fork_verifier_registration = ForkVerifierRegistrationV1(
        register_fork_payload.fork_digest, register_fork_payload.first_window,
        bytes(4), 0, register_fork_payload.verifier,
        register_fork_payload.runtime_hash,
        register_fork_payload.configuration_hash,
        register_fork_payload.selector, register_fork_payload.gas_limit)
    fork_verifier_registration_calldata = (
        encode_fork_verifier_registration_calldata(
            register_fork_payload.fork_digest))
    fork_verifier_registration_return = (
        encode_fork_verifier_registration_return(
            fork_verifier_registration))
    schedule_fork_verifier_config_return = (
        encode_schedule_fork_verifier_config_return(register_fork_payload))
    schedule_carrier_witness = bytes.fromhex("a1617701")
    schedule_beacon_block_root = bytes.fromhex("d0" * 32)
    verify_schedule_carrier_calldata = encode_verify_schedule_carrier_calldata(
        schedule_carrier_witness, schedule_beacon_block_root)
    schedule_statement_hash = schedule_carrier_statement_hash(
        settlement_chain_id, manager_config.schedule_oracle,
        register_fork_payload.fork_digest, 2_048, schedule_beacon_block_root,
        2_047, 20_000_000, 1_800_000_000, bytes.fromhex("d1" * 32),
        bytes.fromhex("d2" * 32), bytes.fromhex("d3" * 32))
    schedule_carrier_output = ScheduleCarrierOutputV1(
        schedule_statement_hash, 2_047, 20_000_000, 1_800_000_000,
        bytes.fromhex("d1" * 32), bytes.fromhex("d2" * 32),
        bytes.fromhex("d3" * 32))
    schedule_carrier_return = encode_schedule_carrier_return(
        schedule_carrier_output)
    publish_legacy_genesis_campaign_calldata = (
        encode_publish_legacy_genesis_campaign_calldata(
            protocol_change_operation_ids[2], 30_000,
            publish_genesis_payload))
    publish_legacy_genesis_campaign_return = (
        encode_publish_legacy_genesis_campaign_return(
            legacy_campaign.nonce, legacy_campaign.generation,
            legacy_review_commitment, legacy_campaign.campaign_id))
    arm_version_migration_calldata = encode_arm_version_migration_calldata(
        protocol_change_operation_ids[3], version_migration_lease)
    arm_version_migration_return = encode_arm_version_migration_return(
        version_migration_lease.generation, version_migration_lease.arm_id)
    abort_expired_version_migration_calldata = (
        encode_abort_expired_version_migration_calldata(
            version_migration_lease.arm_id))
    abort_expired_version_migration_return = (
        encode_abort_expired_version_migration_return(
            version_migration_lease.arm_id,
            version_migration_lease.generation))
    assert QUEUE_PROTOCOL_CHANGE_SELECTOR == keccak256(
        b"queueProtocolChangeV1(uint8,bytes)")[:4]
    assert EXECUTE_PROTOCOL_CHANGE_SELECTOR == keccak256(
        b"executeProtocolChangeV1(uint64,uint8,bytes)")[:4]
    assert CANCEL_PROTOCOL_CHANGE_SELECTOR == keccak256(
        b"cancelProtocolChangeV1(uint64,uint8,bytes)")[:4]
    assert APPLY_PROTOCOL_CHANGE_SELECTOR == keccak256(
        b"applyProtocolChangeV1(uint64,uint8,bytes)")[:4]
    assert PROTOCOL_CHANGE_TIMELOCK_CONFIG_SELECTOR.hex() == "b80095ca"
    assert PROTOCOL_VERSION_MANAGER_CONFIG_SELECTOR.hex() == "4deb7821"
    assert PROTOCOL_CHANGE_OPERATION_SELECTOR.hex() == "4b80fe68"
    assert LIVE_VERSION_MIGRATION_LEASE_SELECTOR.hex() == "aaac4c97"
    assert PERMISSIONLESS_ABORT_EXPIRED_MIGRATION_SELECTOR.hex() == "ea3e96c2"
    assert INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR.hex() == "72a3e937"
    assert SETTLEMENT_AUTHORIZATION_SELECTOR.hex() == "1693ae01"
    assert (SEAT_TARGET_STATE_SELECTOR.hex() == "cf52185b"
            and SEAT_MARKET_TERM_SELECTOR.hex() == "76d5ecd4"
            and SEAT_MARKET_DUTY_SELECTOR.hex() == "9a649489")
    assert (INSTALL_FORK_VERIFIER_SELECTOR.hex() == "f171816c"
            and FORK_VERIFIER_REGISTRATION_SELECTOR.hex() == "c614591c"
            and SCHEDULE_FORK_VERIFIER_CONFIG_SELECTOR.hex() == "44efa773"
            and VERIFY_SCHEDULE_CARRIER_SELECTOR.hex() == "7e981e0b")
    assert MIGRATION_ACTIVATION_PROFILE_SELECTOR.hex() == "c65ff64e"
    assert (PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR.hex() == "5f0ed7f5"
            and ARM_VERSION_MIGRATION_SELECTOR.hex() == "e3bcfcb4"
            and ABORT_EXPIRED_VERSION_MIGRATION_SELECTOR.hex() == "c4eee12d")
    assert SEAT_AUTHORITY_READ_GAS == 100_000
    assert PROTOCOL_CHANGE_TIMELOCK_CONFIG_MAGIC == b"PCT1"
    assert PROTOCOL_VERSION_MANAGER_CONFIG_MAGIC == b"PVM1"
    assert PROTOCOL_CHANGE_OPERATION_MAGIC == b"PCO1"
    assert PROTOCOL_APPLY_MAGIC == b"PAP1"
    assert VERSION_MIGRATION_LEASE_MAGIC == b"VML1"
    assert SETTLEMENT_AUTHORIZATION_INSTALL_MAGIC == b"SAI1"
    assert SETTLEMENT_AUTHORIZATION_GETTER_MAGIC == b"SAT1"
    assert FORK_VERIFIER_INSTALL_MAGIC == b"FVI1"
    assert FORK_VERIFIER_REGISTRATION_MAGIC == b"FVR1"
    assert SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC == b"SFV1"
    assert SCHEDULE_FORK_CARRIER_MAGIC == b"SFC1"
    assert MIGRATION_ACTIVATION_PROFILE_MAGIC == b"MPR2"
    assert LEGACY_GENESIS_PUBLISH_MAGIC == b"LGP1"
    assert VERSION_MIGRATION_ARM_MAGIC == b"VMA1"
    assert VERSION_MIGRATION_ABORT_MAGIC == b"VMB1"
    assert (PROTOCOL_CHANGE_DELAY_SECONDS
            == MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS == 604_800)
    assert LEGACY_DESCRIPTOR_CALL_GAS == 100_000
    assert PROTOCOL_AUTHORITY_READ_GAS == 100_000
    assert_all_fields_bound(
        timelock_descriptor, governance_delay_authority_descriptor_hash)
    assert_all_fields_bound(
        manager_config, protocol_version_manager_configuration_hash)
    assert_all_fields_bound(
        manager_descriptor, protocol_version_manager_descriptor_hash)
    assert_all_fields_bound(
        target_deployment_descriptor,
        settlement_deployment_descriptor_hash)
    assert_all_fields_bound(
        successor_deployment_descriptor,
        settlement_deployment_descriptor_hash)
    assert target_registration_v2_hash(
        1, release_manifest, target_deployment_descriptor,
        migration_activation_profile.activation_profile_record_hash) \
        != target_registration_hash
    assert target_registration_v2_hash(
        1, successor_release_manifest, successor_deployment_descriptor,
        successor_migration_activation_profile.activation_profile_record_hash) \
        != successor_registration_hash
    for changed_manifest in (
        replace(release_manifest, protocol_version=3),
        replace(release_manifest,
                execution_profile_hash=bytes.fromhex("ee" * 32)),
        replace(release_manifest,
                ingress_authorization_root=bytes.fromhex("ed" * 32)),
        replace(release_manifest,
                migration_verifier_descriptor_hash=bytes.fromhex("ec" * 32)),
    ):
        assert target_registration_v2_hash(
            0, changed_manifest, target_deployment_descriptor,
            migration_activation_profile.activation_profile_record_hash) \
            != target_registration_hash
    assert target_registration_v2_hash(
        0, release_manifest, target_deployment_descriptor,
        successor_migration_activation_profile.activation_profile_record_hash) \
        != target_registration_hash
    assert_rejects(
        lambda: target_registration_v2_hash(
            2, release_manifest, target_deployment_descriptor,
            migration_activation_profile.activation_profile_record_hash),
        "non-predecessor target registration accepted")
    assert decode_canonical_release_manifest(
        canonical_release_manifest(release_manifest)) == release_manifest
    assert decode_settlement_deployment_descriptor_abi(
        encode_settlement_deployment_descriptor_abi(
            target_deployment_descriptor)) == target_deployment_descriptor
    assert decode_register_release_payload(
        register_release_payload_abi) == register_release_payload
    assert decode_register_fork_verifier_payload(
        register_fork_payload_abi) == register_fork_payload
    assert decode_publish_genesis_campaign_payload(
        publish_genesis_payload_abi) == publish_genesis_payload
    assert decode_publish_migration_arm_payload(
        publish_migration_payload_abi) == publish_migration_payload
    assert len(register_release_payload_abi) \
        == 2_208 + ceil32(len(profile_bytes))
    assert len(register_fork_payload_abi) == 448
    assert len(publish_genesis_payload_abi) == 320
    assert len(publish_migration_payload_abi) == 128
    assert_all_fields_bound(register_release_payload,
                            encode_register_release_payload)
    assert_all_fields_bound(register_fork_payload,
                            encode_register_fork_verifier_payload)
    assert_all_fields_bound(publish_genesis_payload,
                            encode_publish_genesis_campaign_payload)
    assert_all_fields_bound(publish_migration_payload,
                            encode_publish_migration_arm_payload)
    for operation in protocol_change_operations:
        assert_all_fields_bound(operation, protocol_change_operation_id)
    assert decode_protocol_change_timelock_config_return(
        protocol_change_timelock_config_return) == (
            timelock_descriptor.dao_proposer,
            manager_descriptor.protocol_version_manager)
    assert decode_protocol_version_manager_config_return(
        protocol_version_manager_config_return) == manager_config
    assert decode_protocol_change_operation_return(
        queued_migration_operation_return) == queued_migration_operation
    assert decode_protocol_change_operation_return(
        empty_protocol_change_operation_return).state == 0
    assert decode_protocol_change_operation_calldata(
        protocol_change_operation_calldata) == protocol_change_operation_ids[3]
    assert decode_queue_protocol_change_calldata(
        queue_protocol_change_calldata) == (1, register_release_payload_abi)
    assert decode_execute_protocol_change_calldata(
        execute_protocol_change_calldata) == (2, 2, register_fork_payload_abi)
    assert decode_cancel_protocol_change_calldata(
        cancel_protocol_change_calldata) == (3, 3,
                                              publish_genesis_payload_abi)
    assert decode_apply_protocol_change_calldata(
        apply_protocol_change_calldata) == (4, 4,
                                            publish_migration_payload_abi)
    assert decode_protocol_apply_return(encode_protocol_apply_return()) is None
    assert decode_live_version_migration_lease_return(
        version_migration_lease_return) == version_migration_lease
    assert decode_live_version_migration_lease_return(
        empty_version_migration_lease_return).state == 0
    assert decode_register_target_release_calldata(
        register_target_release_calldata) == register_release_payload
    assert decode_register_target_release_return(
        register_target_release_return) == (
            release_hash, target_registration_hash)
    assert decode_target_release_registration_calldata(
        target_release_registration_calldata) == 2
    assert decode_target_release_registration_return(
        target_release_registration_return) == target_release_registration
    assert decode_migration_activation_profile_calldata(
        migration_activation_profile_calldata) == 2
    assert decode_migration_activation_profile_return(
        migration_activation_profile_return) == migration_activation_profile
    assert decode_profile_ingress_root_calldata(
        profile_ingress_root_calldata) == 2
    assert decode_profile_ingress_root_return(
        profile_ingress_root_return) == (2, 2, ingress_root)
    for index, row in enumerate((kind0_ingress, kind1_ingress)):
        assert decode_profile_ingress_authorization_calldata(
            profile_ingress_authorization_calldata[index]) \
            == ingress_authorization_id(row)
        assert decode_profile_ingress_authorization_return(
            profile_ingress_authorization_returns[index]) == (
                ingress_authorization_id(row), row)
    release_session_config_hash = (
        derived_release_authority.data_session_configuration_hash)
    assert validate_release_registration_postreads(
        register_release_payload, target_release_registration,
        migration_activation_profile, release_session_config_hash,
        (kind0_ingress, kind1_ingress),
        settlement_authorization, release_hash,
        target_registration_hash) == target_registration_hash
    changed_activation_profile = replace(
        migration_activation_profile,
        source_freeze_gas_limit=(
            migration_activation_profile.source_freeze_gas_limit + 1),
        activation_profile_record_hash=bytes(32))
    changed_activation_profile = replace(
        changed_activation_profile,
        activation_profile_record_hash=migration_activation_profile_record_hash(
            changed_activation_profile))
    for changed_postreads in (
        (replace(target_release_registration,
         target_registration_hash=bytes.fromhex("ba" * 32)),
         migration_activation_profile, session_config_hash,
         (kind0_ingress, kind1_ingress),
         settlement_authorization, release_hash, target_registration_hash),
        (target_release_registration, changed_activation_profile,
         release_session_config_hash,
         (kind0_ingress, kind1_ingress), settlement_authorization,
         release_hash, target_registration_hash),
        (target_release_registration, migration_activation_profile,
         release_session_config_hash,
         (replace(kind0_ingress,
                  fixed_ingress_wei=kind0_ingress.fixed_ingress_wei + 1),
          kind1_ingress), settlement_authorization,
         release_hash, target_registration_hash),
        (target_release_registration, migration_activation_profile,
         release_session_config_hash,
         (kind0_ingress, kind1_ingress),
         replace(settlement_authorization,
                 target_registration_hash=bytes.fromhex("bb" * 32)),
         release_hash, target_registration_hash),
        (target_release_registration, migration_activation_profile,
         release_session_config_hash,
         (kind0_ingress, kind1_ingress), settlement_authorization,
         bytes.fromhex("bc" * 32), target_registration_hash),
    ):
        assert_rejects(
            lambda values=changed_postreads:
                validate_release_registration_postreads(
                    register_release_payload, *values),
            "inconsistent release-registration postread accepted")
    assert_all_fields_bound(
        target_release_registration,
        encode_target_release_registration_return)
    assert_all_fields_bound(
        migration_activation_profile,
        encode_migration_activation_profile_return)
    assert len(register_target_release_calldata) \
        == 4 + len(register_release_payload_abi)
    assert len(register_target_release_return) == 96
    assert len(target_release_registration_return) == 384
    assert len(migration_activation_profile_return) == 768
    assert len(profile_ingress_root_return) == 128
    assert all(len(value) == 800
               for value in profile_ingress_authorization_returns)
    assert (REGISTER_TARGET_RELEASE_GAS == 3_000_000
            and INSTALL_SETTLEMENT_AUTHORIZATION_GAS == 500_000
            and PROTOCOL_REGISTRATION_POSTREAD_GAS == 100_000)
    assert schedule_fork_constants_hash(
        8, 201, 6_434, 6_437, 6_441, 6_444) \
        == schedule_fork_constants_hash(
            register_fork_payload.beacon_slot_gindex,
            register_fork_payload.execution_payload_gindex,
            register_fork_payload.state_root_gindex,
            register_fork_payload.prev_randao_gindex,
            register_fork_payload.timestamp_gindex,
            register_fork_payload.block_hash_gindex)
    assert register_fork_payload.configuration_hash \
        == schedule_fork_verifier_configuration_hash(register_fork_payload)
    assert decode_install_fork_verifier_calldata(
        install_fork_verifier_calldata) == register_fork_payload
    assert decode_install_fork_verifier_return(
        install_fork_verifier_return) == (
            register_fork_payload.fork_digest,
            register_fork_payload.first_window)
    assert decode_fork_verifier_registration_calldata(
        fork_verifier_registration_calldata) \
        == register_fork_payload.fork_digest
    assert decode_fork_verifier_registration_return(
        fork_verifier_registration_return) == fork_verifier_registration
    assert decode_schedule_fork_verifier_config_return(
        schedule_fork_verifier_config_return,
        register_fork_payload.verifier, register_fork_payload.runtime_hash,
        register_fork_payload.first_window, register_fork_payload.selector,
        register_fork_payload.gas_limit) == register_fork_payload
    assert decode_verify_schedule_carrier_calldata(
        verify_schedule_carrier_calldata) == (
            schedule_carrier_witness, schedule_beacon_block_root)
    assert decode_schedule_carrier_return(
        schedule_carrier_return,
        schedule_statement_hash) == schedule_carrier_output
    assert decode_publish_legacy_genesis_campaign_calldata(
        publish_legacy_genesis_campaign_calldata) == (
            protocol_change_operation_ids[2], 30_000,
            publish_genesis_payload)
    assert decode_publish_legacy_genesis_campaign_return(
        publish_legacy_genesis_campaign_return) == (
            legacy_campaign.nonce, legacy_campaign.generation,
            legacy_review_commitment, legacy_campaign.campaign_id)
    assert decode_arm_version_migration_calldata(
        arm_version_migration_calldata) == (
            protocol_change_operation_ids[3], version_migration_lease.arm_id,
            version_migration_lease.armed_at_timestamp,
            version_migration_lease.abort_after_timestamp,
            version_migration_lease.source_protocol_version,
            version_migration_lease.target_protocol_version,
            version_migration_lease.target_manifest_hash,
            version_migration_lease.target_registration_hash)
    assert decode_arm_version_migration_return(
        arm_version_migration_return) == (
            version_migration_lease.generation,
            version_migration_lease.arm_id)
    assert decode_abort_expired_version_migration_calldata(
        abort_expired_version_migration_calldata) \
        == version_migration_lease.arm_id
    assert decode_abort_expired_version_migration_return(
        abort_expired_version_migration_return) == (
            version_migration_lease.arm_id,
            version_migration_lease.generation)
    assert PVM_ROUTER_MUTATION_GAS == 8_000_000
    assert protocol_control_plane_entry_allowed(0, 0)
    assert not protocol_control_plane_entry_allowed(1, 0)
    assert not protocol_control_plane_entry_allowed(0, 6)
    assert not protocol_control_plane_entry_allowed(2, 3)
    assert_all_fields_bound(
        schedule_carrier_output, encode_schedule_carrier_return)
    assert not fork_verifier_registration_covers_window(
        fork_verifier_registration,
        register_fork_payload.first_window - 1)
    assert fork_verifier_registration_covers_window(
        fork_verifier_registration, register_fork_payload.first_window)
    prior_fork_registration = ForkVerifierRegistrationV1(
        bytes.fromhex("44454e42"), 0, register_fork_payload.fork_digest,
        register_fork_payload.first_window, 0x6801, bytes.fromhex("6a" * 32),
        bytes.fromhex("6b" * 32), VERIFY_SCHEDULE_CARRIER_SELECTOR,
        4_000_000)
    assert fork_verifier_registration_covers_window(
        prior_fork_registration, register_fork_payload.first_window - 1)
    assert not fork_verifier_registration_covers_window(
        prior_fork_registration, register_fork_payload.first_window)
    assert not schedule_unsealed_window_is_vacant(False, 999, 1_000)
    assert schedule_unsealed_window_is_vacant(False, 1_000, 1_000)
    assert not schedule_unsealed_window_is_vacant(True, 1_000, 1_000)
    for malformed_schedule_abi, decoder in (
        (install_fork_verifier_calldata + bytes(32),
         decode_install_fork_verifier_calldata),
        (fork_verifier_registration_calldata[:8] + b"\x01"
         + fork_verifier_registration_calldata[9:],
         decode_fork_verifier_registration_calldata),
        (fork_verifier_registration_return[:-1],
         decode_fork_verifier_registration_return),
        (schedule_fork_verifier_config_return + bytes(32),
         lambda value: decode_schedule_fork_verifier_config_return(
             value, register_fork_payload.verifier,
             register_fork_payload.runtime_hash,
             register_fork_payload.first_window,
             register_fork_payload.selector,
             register_fork_payload.gas_limit)),
        (verify_schedule_carrier_calldata[:4] + u256(96)
         + verify_schedule_carrier_calldata[36:],
         decode_verify_schedule_carrier_calldata),
        (schedule_carrier_return[:4] + b"\x01"
         + schedule_carrier_return[5:],
         decode_schedule_carrier_return),
    ):
        assert_rejects(
            lambda value=malformed_schedule_abi, fn=decoder: fn(value),
            "malformed ScheduleOracle ABI accepted")
    for malformed_router_journal_abi, decoder in (
        (publish_legacy_genesis_campaign_calldata + bytes(32),
         decode_publish_legacy_genesis_campaign_calldata),
        (publish_legacy_genesis_campaign_return[:4] + b"\x01"
         + publish_legacy_genesis_campaign_return[5:],
         decode_publish_legacy_genesis_campaign_return),
        (arm_version_migration_calldata[:-1],
         decode_arm_version_migration_calldata),
        (arm_version_migration_return + bytes(32),
         decode_arm_version_migration_return),
        (abort_expired_version_migration_calldata + bytes(32),
         decode_abort_expired_version_migration_calldata),
        (abort_expired_version_migration_return[:-1],
         decode_abort_expired_version_migration_return),
    ):
        assert_rejects(
            lambda value=malformed_router_journal_abi, fn=decoder: fn(value),
            "malformed PVM-Router journal ABI accepted")
    assert settlement_authorization == SettlementAuthorizationV1(
        register_release_payload.release_manifest.protocol_version,
        register_release_payload.settlement_deployment_descriptor
            .target_settlement,
        register_release_payload.settlement_deployment_descriptor
            .target_runtime_hash,
        register_release_payload.settlement_deployment_descriptor
            .target_configuration_hash,
        SEAT_TARGET_EXPECTED_MAGIC,
        target_registration_v2_hash(
            register_release_payload.expected_predecessor_protocol_version,
            register_release_payload.release_manifest,
            register_release_payload.settlement_deployment_descriptor,
            migration_activation_profile.activation_profile_record_hash))
    assert decode_install_settlement_authorization_calldata(
        install_settlement_authorization_calldata) == settlement_authorization
    assert decode_install_settlement_authorization_return(
        install_settlement_authorization_return) \
        == settlement_authorization_hash
    assert decode_settlement_authorization_calldata(
        settlement_authorization_calldata) == settlement_authorization_hash
    assert decode_settlement_authorization_return(
        settlement_authorization_return) == settlement_authorization
    assert_all_fields_bound(
        settlement_authorization, encode_settlement_authorization_return)
    for field in fields(settlement_authorization)[:-1]:
        changed_authorization = replace(
            settlement_authorization,
            **{field.name: changed_field_value(
                getattr(settlement_authorization, field.name))})
        try:
            changed_authorization_id = settlement_authorization_id(
                settlement_chain_id, manager_config.aggregator_seat_market,
                settlement_chain_id, changed_authorization)
        except AssertionError:
            continue
        assert changed_authorization_id != settlement_authorization_hash
    assert settlement_authorization_id(
        settlement_chain_id, manager_config.aggregator_seat_market,
        settlement_chain_id, replace(
            settlement_authorization,
            target_registration_hash=bytes.fromhex("bc" * 32))) \
        == settlement_authorization_hash
    for malformed_authorization_abi, decoder in (
        (install_settlement_authorization_calldata + bytes(32),
         decode_install_settlement_authorization_calldata),
        (install_settlement_authorization_calldata[:8 + 4 * 32] + b"\x01"
         + install_settlement_authorization_calldata[9 + 4 * 32:],
         decode_install_settlement_authorization_calldata),
        (install_settlement_authorization_return[:-1],
         decode_install_settlement_authorization_return),
        (settlement_authorization_calldata + bytes(32),
         decode_settlement_authorization_calldata),
        (settlement_authorization_return[:4] + b"\x01"
         + settlement_authorization_return[5:],
         decode_settlement_authorization_return),
    ):
        assert_rejects(
            lambda value=malformed_authorization_abi, fn=decoder: fn(value),
            "malformed settlement authorization ABI accepted")
    validate_version_migration_lease(
        version_migration_lease, settlement_chain_id,
        manager_descriptor.protocol_version_manager,
        protocol_change_operation_ids[3])
    assert_all_fields_bound(queued_migration_operation,
                            encode_protocol_change_operation_return)
    assert_all_fields_bound(version_migration_lease,
                            encode_live_version_migration_lease_return)
    assert not protocol_change_execute_allowed(
        queued_migration_operation,
        queued_migration_operation.execute_after - 1)
    assert protocol_change_execute_allowed(
        queued_migration_operation, queued_migration_operation.execute_after)
    assert protocol_change_cancel_allowed(
        queued_migration_operation, timelock_descriptor.dao_proposer,
        timelock_descriptor.dao_proposer)
    assert not protocol_change_cancel_allowed(
        replace(queued_migration_operation, state=2),
        timelock_descriptor.dao_proposer,
        timelock_descriptor.dao_proposer)
    assert not protocol_change_cancel_allowed(
        queued_migration_operation, 0xDEAD,
        timelock_descriptor.dao_proposer)
    assert version_migration_activation_allowed(
        version_migration_lease,
        version_migration_lease.abort_after_timestamp - 1)
    assert not version_migration_activation_allowed(
        version_migration_lease,
        version_migration_lease.abort_after_timestamp)
    assert permissionless_abort_expired_migration_allowed(
        version_migration_lease,
        version_migration_lease.abort_after_timestamp)
    assert_rejects(
        lambda: encode_live_version_migration_lease_return(replace(
            version_migration_lease,
            abort_after_timestamp=(
                version_migration_lease.abort_after_timestamp + 1))),
        "extendable migration lease accepted")
    for malformed_protocol_change_payload in (
        register_release_payload_abi + bytes(32),
        u256(1 << 64) + register_release_payload_abi[32:],
        register_release_payload_abi[:67 * 32] + u256(2_208)
        + register_release_payload_abi[68 * 32:],
        register_fork_payload_abi[:4] + b"\x01"
        + register_fork_payload_abi[5:],
        publish_genesis_payload_abi[:-1],
        publish_migration_payload_abi + bytes(32),
    ):
        assert_rejects(
            lambda value=malformed_protocol_change_payload:
                validate_protocol_change_payload(
                    1 if len(value) >= 2_208 else
                    (2 if len(value) == 448 else
                     (3 if len(value) == 319 else 4)), value),
            "malformed protocol-change payload accepted")
    for malformed_protocol_change_calldata, decoder in (
        (queue_protocol_change_calldata + bytes(32),
         decode_queue_protocol_change_calldata),
        (queue_protocol_change_calldata[:36] + u256(96)
         + queue_protocol_change_calldata[68:],
         decode_queue_protocol_change_calldata),
        (execute_protocol_change_calldata[:-1],
         decode_execute_protocol_change_calldata),
        (cancel_protocol_change_calldata[:4] + b"\x01"
         + cancel_protocol_change_calldata[5:],
         decode_cancel_protocol_change_calldata),
        (apply_protocol_change_calldata + bytes(32),
         decode_apply_protocol_change_calldata),
    ):
        assert_rejects(
            lambda value=malformed_protocol_change_calldata, fn=decoder:
                fn(value),
            "malformed protocol-change calldata accepted")
    for malformed_protocol_return, decoder in (
        (protocol_change_timelock_config_return + bytes(32),
         decode_protocol_change_timelock_config_return),
        (b"BAD!" + protocol_change_timelock_config_return[4:],
         decode_protocol_change_timelock_config_return),
        (protocol_version_manager_config_return[:-1],
         decode_protocol_version_manager_config_return),
        (protocol_version_manager_config_return + bytes(32),
         decode_protocol_version_manager_config_return),
        (queued_migration_operation_return[:4] + b"\x01"
         + queued_migration_operation_return[5:],
         decode_protocol_change_operation_return),
        (version_migration_lease_return + bytes(32),
         decode_live_version_migration_lease_return),
        (encode_protocol_apply_return() + bytes(32),
         decode_protocol_apply_return),
    ):
        assert_rejects(
            lambda value=malformed_protocol_return, fn=decoder: fn(value),
            "malformed protocol authority return accepted")
    assert_rejects(
        lambda: protocol_change_operation_id(replace(
            protocol_change_operations[3], operation_kind=5)),
        "unsupported protocol-change operation kind accepted")
    assert LEGACY_INBOX_CONFIG_SELECTOR.hex() == "c3f909d4"
    assert LEGACY_DESCRIPTOR_IMPL_SELECTOR.hex() == "8abf6077"
    assert len(legacy_inbox_config_return) == 544
    assert decode_legacy_inbox_config_return(
        legacy_inbox_config_return) == legacy_inbox_config
    assert_all_fields_bound(
        legacy_inbox_config, legacy_inbox_configuration_hash)
    legacy_deployment_arguments = (
        settlement_chain_id, 0x6100, bytes.fromhex("a0" * 32), 0x6101,
        bytes.fromhex("a1" * 32), legacy_inbox_config_hash, 0xAD01)
    for index, argument in enumerate(legacy_deployment_arguments):
        changed_arguments = list(legacy_deployment_arguments)
        changed_arguments[index] = changed_field_value(argument)
        try:
            changed_deployment_hash = legacy_genesis_deployment_hash(
                *changed_arguments)
        except AssertionError:
            continue
        assert changed_deployment_hash != legacy_deployment_hash
    for malformed_legacy_config in (
        legacy_inbox_config_return[:-1],
        legacy_inbox_config_return + bytes(32),
        legacy_inbox_config_return[:12 * 32] + b"\x01"
        + legacy_inbox_config_return[12 * 32 + 1:],
    ):
        assert_rejects(
            lambda value=malformed_legacy_config:
                decode_legacy_inbox_config_return(value),
            "malformed legacy Inbox configuration accepted")
    legacy_maximum_scan_bytes = (
        2 * LEGACY_MAX_PROPOSAL_ROW_BYTES
        + 3 * LEGACY_MAX_FORCED_ROW_BYTES)
    legacy_preparation_return = encode_legacy_genesis_preparation_return(
        12, 9, 5, 8, 2, 3, legacy_maximum_scan_bytes,
        legacy_resume_profile_hash)
    legacy_begin_scan_calldata = encode_legacy_genesis_control_calldata(
        LEGACY_GENESIS_BEGIN_SCAN_SELECTOR, 1, legacy_campaign.campaign_id)
    legacy_begin_scan_return = encode_begin_legacy_genesis_scan_return(
        10, 12, 5, 8)
    def legacy_blob_hash(tag: bytes, index: int) -> bytes:
        return keccak256(b"slot-chain-legacy-codec-fixture-v1" + tag
                         + u16(index))

    def maximum_legacy_proposal(
            proposal_id: int, timestamp: int) -> LegacyProposal:
        forced_sources = tuple(
            LegacyDerivationSource(
                True,
                LegacyBlobSlice(
                    (legacy_blob_hash(b"forced", index),),
                    (1 << 24) - 1 - index, timestamp - 10 + index))
            for index in range(
                LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL))
        normal_source = LegacyDerivationSource(
            False,
            LegacyBlobSlice(
                tuple(legacy_blob_hash(b"normal", index) for index in range(
                    LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL)),
                (1 << 24) - 1, timestamp))
        return LegacyProposal(
            proposal_id, timestamp, timestamp + 60, 0xBEEF,
            keccak256(b"legacy-parent" + u48(proposal_id)),
            10_000 + proposal_id,
            keccak256(b"legacy-origin" + u48(proposal_id)), 100,
            forced_sources + (normal_source,))

    proposal_10 = LegacyProposal(
        10, 1_000, 1_050, 0xCAFE,
        keccak256(b"legacy-parent-10"), 9_999,
        keccak256(b"legacy-origin-10"), 75,
        (
            LegacyDerivationSource(
                True, LegacyBlobSlice(
                    (legacy_blob_hash(b"mixed-forced", 0),), 0, 900)),
            LegacyDerivationSource(
                True, LegacyBlobSlice(
                    (legacy_blob_hash(b"mixed-forced", 1),),
                    (1 << 24) - 1, 950)),
            LegacyDerivationSource(
                False, LegacyBlobSlice(
                    (legacy_blob_hash(b"mixed-normal", 0),
                     legacy_blob_hash(b"mixed-normal", 1)), 17, 1_000)),
        ))
    proposal_11 = maximum_legacy_proposal(11, 1_100)
    proposal_encodings = (
        encode_legacy_proposal(proposal_10),
        encode_legacy_proposal(proposal_11))
    proposal_rows = tuple(
        legacy_proposal_row(
            proposal, legacy_resume_profile.legacy_blob_retention_seconds)
        for proposal in (proposal_10, proposal_11))
    forced_inclusions = tuple(
        LegacyForcedInclusion(
            fee_gwei,
            LegacyBlobSlice(
                (legacy_blob_hash(b"queue-forced", index),),
                (0, (1 << 24) - 1, 42)[index], 1_100 + index * 100))
        for index, fee_gwei in enumerate((7, 11, 13)))
    forced_record_encodings = tuple(
        encode_legacy_forced_inclusion(inclusion)
        for inclusion in forced_inclusions)
    forced_rows = tuple(
        legacy_forced_inclusion_row(
            5 + index, inclusion,
            legacy_resume_profile.legacy_blob_retention_seconds)
        for index, inclusion in enumerate(forced_inclusions))
    maximum_proposal_encodings = tuple(
        encode_legacy_proposal(maximum_legacy_proposal(
            100 + index, 2_000 + index))
        for index in range(16))
    legacy_maximum_proposal_batch_raw_bytes = sum(
        map(len, maximum_proposal_encodings))
    legacy_full_scan_capacity_bytes = (
        1_024 * LEGACY_MAX_PROPOSAL_ROW_BYTES
        + 1_024 * LEGACY_MAX_FORCED_ROW_BYTES)
    (proposal_rows_root, proposal_bytes,
     proposal_abandoned_native_wei) = legacy_genesis_rows_root(
        "proposal", proposal_rows)
    (forced_rows_root, forced_bytes,
     forced_abandoned_native_wei) = legacy_genesis_rows_root(
        "forced", forced_rows)
    assert proposal_abandoned_native_wei == 0
    legacy_min_data_expiry = min(
        row[3] for row in proposal_rows + forced_rows)
    legacy_scan = LegacyGenesisScanV1(
        legacy_campaign.campaign_id, 10, 12, len(proposal_rows),
        proposal_bytes, proposal_rows_root, 5, 8, len(forced_rows),
        forced_bytes, forced_rows_root, forced_abandoned_native_wei,
        legacy_min_data_expiry, legacy_resume_profile_hash)
    legacy_scan_commitment = legacy_genesis_scan_commitment(legacy_scan)
    legacy_abandonment_receipt = LegacyGenesisAbandonmentReceiptV1(
        legacy_campaign.campaign_id, legacy_scan_commitment,
        10, 11, 12, 2, 1, proposal_bytes, proposal_rows_root,
        5, 8, 3, forced_bytes, forced_rows_root,
        forced_abandoned_native_wei, 0, legacy_min_data_expiry,
        legacy_resume_profile_hash)
    legacy_abandonment_receipt_hash = (
        legacy_genesis_abandonment_receipt_hash(
            legacy_abandonment_receipt))
    legacy_proposal_scan_one_calldata = (
        encode_scan_legacy_genesis_proposals_calldata(
            1, legacy_campaign.campaign_id,
            (proposal_encodings[1],)))
    legacy_proposal_scan_sixteen_calldata = (
        encode_scan_legacy_genesis_proposals_calldata(
            1, legacy_campaign.campaign_id,
            maximum_proposal_encodings))
    legacy_proposal_scan_return = (
        encode_scan_legacy_genesis_proposals_return(
            12, proposal_rows_root, proposal_bytes,
            legacy_min_data_expiry))
    legacy_forced_scan_calldata = encode_scan_legacy_genesis_forced_calldata(
        1, legacy_campaign.campaign_id, 3)
    legacy_forced_scan_return = encode_scan_legacy_genesis_forced_return(
        8, forced_rows_root, forced_bytes, forced_abandoned_native_wei,
        legacy_min_data_expiry)
    legacy_scan_state_return = encode_legacy_genesis_scan_state_return(
        1, legacy_campaign.campaign_id, 10, 12, 12, 2,
        proposal_bytes, proposal_rows_root, 5, 8, 8, 3,
        forced_bytes, forced_rows_root, forced_abandoned_native_wei,
        legacy_min_data_expiry, legacy_scan.legacy_resume_profile_hash, 2)
    legacy_quiescence_calldata = encode_legacy_genesis_control_calldata(
        LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR, 1,
        legacy_campaign.campaign_id)
    legacy_quiescence_return = encode_legacy_genesis_quiescence_return(
        1, legacy_scan_commitment)
    legacy_resume_calldata = encode_legacy_genesis_control_calldata(
        LEGACY_GENESIS_RESUME_SELECTOR, 1, legacy_campaign.campaign_id)
    legacy_resume_return = encode_legacy_genesis_resume_return(
        1, legacy_campaign.campaign_id)
    legacy_expire_calldata = encode_legacy_genesis_control_calldata(
        LEGACY_GENESIS_EXPIRE_SELECTOR, 1, legacy_campaign.campaign_id)
    legacy_expire_return = encode_legacy_genesis_expire_return()
    legacy_boundary_hash = legacy_genesis_boundary_hash(
        12, 10, imported_header_hash, 5, 8)
    legacy_arm_id = legacy_genesis_arm_id(
        legacy_deployment_hash, 1, legacy_campaign.campaign_id,
        legacy_scan_commitment, legacy_boundary_hash)
    legacy_launch_id = legacy_genesis_launch_id(
        legacy_arm_id, 2, release_hash, target_registration_hash)
    genesis_transition = MigrationTransitionStatementV2(
        settlement_chain_id, 0xAD01, infrastructure_components[1].runtime_hash,
        infrastructure_components[1].config_hash,
        1, 1, 1, 2, 0, profile_hash, release_hash,
        target_registration_hash,
        genesis_candidate_hash, genesis_base,
        canonical_core_v2_hash(genesis_output_core),
        0xF000, bytes.fromhex("5a" * 32),
        forced_queue_config_hash(0xAD01), empty_queue_root, 0, 0, 0,
        empty_forced_descriptors, 0xCAFE, 1_000, bytes.fromhex("99" * 32),
        empty_queue_root, 0, bytes(32), 0, bytes(32),
        keccak256(genesis_release_system_calldata),
        keccak256(genesis_inbox_apply_calldata),
        keccak256(genesis_release_system_tx),
        keccak256(genesis_inbox_system_tx), 0, 1,
        imported_header_hash, imported_state_root, checkpoint_hash,
        legacy_deployment_hash, legacy_arm_id, legacy_launch_id,
        genesis_deployment_hash, plus_one_cursor(None), plus_one_cursor(None))
    version_transition = MigrationTransitionStatementV2(
        settlement_chain_id, 0xAD01, infrastructure_components[1].runtime_hash,
        infrastructure_components[1].config_hash,
        2, 2, 2, 3, 2, profile_hash,
        successor_release_hash, successor_registration_hash,
        candidate_hash, base, canonical_core_v2_hash(version_output_core),
        0xF000, bytes.fromhex("5a" * 32),
        forced_queue_config_hash(0xAD01), force.root, len(envs), 2, 66,
        forced_descriptors, 0xCAFE, 1_000, bytes.fromhex("99" * 32),
        force.root, 66, source_domain, 7, bridge_execution,
        keccak256(version_release_system_calldata),
        keccak256(version_inbox_apply_calldata),
        keccak256(version_release_system_tx),
        keccak256(version_inbox_system_tx), 0, 1,
        bytes(32), bytes(32), bytes(32), bytes(32), bytes(32), bytes(32),
        version_deployment_hash, plus_one_cursor(8_000),
        plus_one_cursor(8_001))
    genesis_transition_hash = migration_transition_statement_hash(
        genesis_transition)
    version_transition_hash = migration_transition_statement_hash(
        version_transition)
    registration_statement = RegistrationStorageStatementV2(
        settlement_chain_id, 0xAD01, 0xD010,
        registration_route_key(source_domain, bridge_execution,
                               destination_domain),
        l2_chain_id, 2, 1, bytes.fromhex("66" * 32), 0x5103,
        infrastructure_components[6].runtime_hash,
        registration_commitment_trie_key(2), registration)
    registration_statement_hash = registration_storage_statement_hash(
        registration_statement)
    registration_mpt_verifier = RegistrationMptVerifierDescriptorV2(
        0x6002, bytes.fromhex("95" * 32), bytes(32),
        REGISTRATION_STORAGE_STATEMENT_TYPEHASH,
        REGISTRATION_MPT_PROOF_SCHEMA_HASH, VERIFY_REGISTRATION_SELECTOR,
        66, 132, 600, 80_000, 8_000_000)
    registration_mpt_verifier = replace(
        registration_mpt_verifier,
        configuration_hash=_registration_mpt_verifier_configuration_hash(
            registration_mpt_verifier))
    registration_mpt_configuration_hash = (
        registration_mpt_verifier_configuration_hash(
            registration_mpt_verifier))
    registration_mpt_descriptor_hash = (
        registration_mpt_verifier_descriptor_hash(registration_mpt_verifier))
    registration_proof = bytes.fromhex("f86a") + bytes(range(33))
    registration_verification_calldata = encode_verify_registration_calldata(
        registration_statement, registration_proof)
    registration_verifier_return = registration_statement_hash
    registration_config_getter_return = registration_mpt_configuration_hash
    destination_receipt = DestinationActivationReceiptV2(
        l2_chain_id, 0x5103, 2, 2, 3, release_hash,
        successor_release_hash, destination_domain,
        bytes.fromhex("89" * 32), 0xB200, 0xB201, len(envs), 1_234)
    destination_receipt_hash = destination_activation_receipt_id(
        destination_receipt)
    bridge_msg_hash = bytes.fromhex("21" * 32)
    liquidity_fee = 5_678
    bridge_credit = bridge_credit_id(
        1, source_domain, 7, source_bridge_address, destination_domain,
        bridge_msg_hash,
        liquidity_fee)
    bridge = BridgeEnvelope(
        bridge_msg_hash, 1, source_domain, 7, source_bridge_address,
        bridge_execution,
        12_300, destination_domain, l2_chain_id, 800_000,
        0x3333, 0x1111, 0x2222, 10**18, 1_234, liquidity_fee,
        bytes.fromhex("22" * 32), 1, 0, bytes(32),
        bridge_escrow_id(bridge_credit), 96, 120_000,
        0xBEEF, 700, 2_200, 10**16,
    )
    source_authorization = credit_authorization_from_envelope(bridge)
    source_liability = SourceLiabilityV2(
        bridge.value, bridge.fee, bridge.liquidity_fee, 1, UINT64_MAX,
        0, 0, 0, bridge.value + bridge.fee + bridge.liquidity_fee)
    credit_authorization_calldata = encode_source_credit_read_calldata(
        CREDIT_AUTHORIZATION_V2_SELECTOR, bridge_credit)
    credit_liability_calldata = encode_source_credit_read_calldata(
        CREDIT_LIABILITY_V2_SELECTOR, bridge_credit)
    credit_authorization_return = encode_credit_authorization_return(
        source_authorization)
    credit_liability_return = encode_credit_liability_return(source_liability)
    assert (CREDIT_AUTHORIZATION_V2_SELECTOR.hex() == "05ecb6c2"
            and CREDIT_LIABILITY_V2_SELECTOR.hex() == "c978978a"
            and decode_source_credit_read_call(
                credit_authorization_calldata, bridge_credit,
                SOURCE_CREDIT_READ_GAS_LIMIT,
                credit_authorization_return) == source_authorization
            and decode_source_credit_read_call(
                credit_liability_calldata, bridge_credit,
                SOURCE_CREDIT_READ_GAS_LIMIT,
                credit_liability_return) == source_liability)
    for invalid_source_call in (
        (credit_authorization_calldata, bridge_credit,
         SOURCE_CREDIT_READ_GAS_LIMIT - 1, credit_authorization_return),
        (credit_authorization_calldata + b"\x00", bridge_credit,
         SOURCE_CREDIT_READ_GAS_LIMIT, credit_authorization_return),
        (credit_authorization_calldata, bytes.fromhex("b9" * 32),
         SOURCE_CREDIT_READ_GAS_LIMIT, credit_authorization_return),
        (b"\x00\x00\x00\x00" + bridge_credit, bridge_credit,
         SOURCE_CREDIT_READ_GAS_LIMIT, credit_authorization_return),
    ):
        assert_rejects(
            lambda values=invalid_source_call:
                decode_source_credit_read_call(*values),
            "malformed source credit read call accepted")
    validate_source_credit_read(
        source_authorization, source_liability, source_authorization,
        source_liability,
        source_bridge_address,
        source_liability.total_live_liability)
    for semantically_invalid_liability in (
        replace(source_liability, status=2),
        replace(source_liability, queue_index=0),
        replace(source_liability, pull_class=1),
        replace(source_liability, pull_beneficiary=0xB8),
        replace(source_liability, pull_amount=1),
        replace(source_liability,
                total_live_liability=(source_liability.value
                                      + source_liability.execution_fee
                                      + source_liability.liquidity_fee - 1)),
    ):
        assert_rejects(
            lambda liability=semantically_invalid_liability:
                validate_source_liability_semantics(
                    source_authorization, liability,
                    source_bridge_address,
                    max(source_liability.total_live_liability,
                        liability.total_live_liability)),
            "invalid NEW source liability semantics accepted")
    assert_rejects(
        lambda: validate_source_liability_semantics(
            source_authorization, source_liability,
            source_bridge_address,
            source_liability.total_live_liability - 1),
        "insolvent source Bridge read accepted")
    assert_rejects(
        lambda: validate_source_liability_semantics(
            source_authorization, source_liability,
            source_bridge_address + 1,
            source_liability.total_live_liability),
        "balance from substituted source account accepted")
    for substituted_authorization in (
        replace(source_authorization,
                source_domain_id=bytes.fromhex("b2" * 32)),
        replace(source_authorization, src_epoch=source_authorization.src_epoch + 1),
        replace(source_authorization, src_bridge=source_authorization.src_bridge + 1),
        replace(source_authorization,
                bridge_execution_hash=bytes.fromhex("b3" * 32)),
        replace(source_authorization,
                emitted_at_block=source_authorization.emitted_at_block + 1),
        replace(source_authorization, msg_hash=bytes.fromhex("b4" * 32)),
        replace(source_authorization,
                destination_domain_id=bytes.fromhex("b5" * 32)),
        replace(source_authorization,
                dest_chain_id=source_authorization.dest_chain_id + 1),
        replace(source_authorization, enqueue_by=source_authorization.enqueue_by + 1),
        replace(source_authorization, sender=source_authorization.sender + 1),
        replace(source_authorization, src_owner=source_authorization.src_owner + 1),
        replace(source_authorization, dest_owner=source_authorization.dest_owner + 1),
        replace(source_authorization, value=source_authorization.value + 1),
        replace(source_authorization, fee=source_authorization.fee + 1),
        replace(source_authorization,
                liquidity_fee=source_authorization.liquidity_fee + 1),
        replace(source_authorization,
                calldata_hash=bytes.fromhex("b6" * 32)),
        replace(source_authorization,
                calldata_length=source_authorization.calldata_length + 1),
        replace(source_authorization, escrow_id=bytes.fromhex("b7" * 32)),
    ):
        decoded_substitution = decode_credit_authorization_return(
            encode_credit_authorization_return(substituted_authorization))
        assert_rejects(
            lambda authorization=decoded_substitution:
                validate_source_credit_read(
                    authorization, source_liability, source_authorization,
                    source_liability,
                    source_bridge_address,
                    source_liability.total_live_liability),
            "substituted source authorization field accepted")
    for substituted_liability in (
        replace(source_liability, value=source_liability.value + 1),
        replace(source_liability,
                execution_fee=source_liability.execution_fee + 1),
        replace(source_liability,
                liquidity_fee=source_liability.liquidity_fee + 1),
        replace(source_liability, status=2),
        replace(source_liability, queue_index=0),
        replace(source_liability, pull_class=1),
        replace(source_liability, pull_beneficiary=0xB8),
        replace(source_liability, pull_amount=1),
        replace(source_liability,
                total_live_liability=source_liability.total_live_liability + 1),
    ):
        decoded_substitution = decode_credit_liability_return(
            encode_credit_liability_return(substituted_liability))
        assert_rejects(
            lambda liability=decoded_substitution:
                validate_source_credit_read(
                    source_authorization, liability, source_authorization,
                    source_liability,
                    source_bridge_address,
                    source_liability.total_live_liability),
            "substituted source liability field accepted")
    for malformed_source_read in (
        credit_authorization_return[:-1],
        credit_authorization_return + b"\x00",
    ):
        assert_rejects(
            lambda value=malformed_source_read:
                decode_credit_authorization_return(value),
            "malformed source authorization return accepted")
    for noncanonical_word in (1, 2, 4, 7, 8, 9, 10, 11, 13, 14, 16):
        malformed_padding = (
            credit_authorization_return[:noncanonical_word * 32]
            + b"\x01"
            + credit_authorization_return[noncanonical_word * 32 + 1:])
        assert_rejects(
            lambda value=malformed_padding:
                decode_credit_authorization_return(value),
            "noncanonical source authorization padding accepted")
    for malformed_liability_read in (
        credit_liability_return[:-1],
        credit_liability_return + b"\x00",
    ):
        assert_rejects(
            lambda value=malformed_liability_read:
                decode_credit_liability_return(value),
            "malformed source liability return accepted")
    for noncanonical_word in (1, 2, 3, 4, 5, 6):
        malformed_padding = (
            credit_liability_return[:noncanonical_word * 32]
            + b"\x01"
            + credit_liability_return[noncanonical_word * 32 + 1:])
        assert_rejects(
            lambda value=malformed_padding:
                decode_credit_liability_return(value),
            "noncanonical source liability padding accepted")
    durable_bridge_descriptor = bridge_descriptor(bridge)
    inbox_rows = version_inbox_rows
    inbox_apply_calldata = version_inbox_apply_calldata
    activation_output_core = version_output_core
    legacy_post_state = legacy_genesis_post_state_commitment(
        legacy_launch_id, genesis_candidate_hash,
        canonical_core_v2_hash(genesis_output_core), 1_234,
        legacy_boundary_hash)
    legacy_arm_calldata = encode_legacy_genesis_control_calldata(
        LEGACY_GENESIS_ARM_SELECTOR, 1, legacy_campaign.campaign_id)
    legacy_arm_return = encode_legacy_genesis_control_return(
        LEGACY_GENESIS_ARM_MAGIC, 1, legacy_campaign.campaign_id,
        legacy_arm_id)
    legacy_finalize_calldata = encode_finalize_legacy_genesis_calldata(
        1, 2, release_hash, target_registration_hash, genesis_candidate_hash,
        canonical_core_v2_hash(genesis_output_core))
    legacy_finalize_return = encode_finalize_legacy_genesis_return(
        legacy_launch_id, legacy_post_state)
    legacy_state_return = encode_legacy_genesis_state_return(
        4, 1, legacy_campaign.campaign_id, legacy_scan_commitment, 2,
        release_hash, target_registration_hash, legacy_arm_id,
        legacy_launch_id, 12, 10, imported_header_hash, 5, 8,
        legacy_post_state)
    legacy_quiescent_state_return = encode_legacy_genesis_state_return(
        2, 1, legacy_campaign.campaign_id, legacy_scan_commitment, 0,
        bytes(32), bytes(32), bytes(32), bytes(32), 12, 10,
        imported_header_hash, 5, 8, bytes(32))
    legacy_ready_state_return = encode_legacy_genesis_state_return(
        3, 1, legacy_campaign.campaign_id, legacy_scan_commitment, 0,
        bytes(32), bytes(32), legacy_arm_id, bytes(32), 12, 10,
        imported_header_hash, 5, 8, bytes(32))
    genesis_activation_context_hash_v1 = migration_activation_context_hash(
        settlement_chain_id, 0xAD01, 1, 1, 1, 2, legacy_deployment_hash,
        release_hash, target_registration_hash, 0x6100, target_settlement, 0,
        genesis_base,
        genesis_transition_hash, genesis_candidate_hash, genesis_output_core,
        0xF000, empty_queue_root, 0, 0, 0, 0xCAFE, 1_234)
    genesis_adoption_post_state = migration_adoption_commitment(
        settlement_chain_id, 0xAD01, target_settlement,
        genesis_activation_context_hash_v1, 1, 1, 1, 2, 0, release_hash,
        genesis_candidate_hash, genesis_output_core, 1_234)
    genesis_queue_post_state = queue_migration_post_state_commitment(
        genesis_activation_context_hash_v1, 0xF000, target_settlement,
        empty_queue_root, 0, 0, 0xCAFE, 0, 0, 0)
    genesis_adopt_migration_calldata = (
        encode_adopt_migration_canonical_calldata(
            1, 1, 1, 2, 0, release_hash, genesis_candidate_hash,
            genesis_output_core))
    genesis_adopt_migration_return = encode_migration_canonical_return(
        0, genesis_adoption_post_state)
    genesis_queue_migration_calldata = encode_queue_migration_calldata(
        genesis_activation_context_hash_v1, 0x6100, target_settlement,
        empty_queue_root, 0, 0, 0, 0xCAFE)
    genesis_queue_migration_return = encode_queue_migration_return(
        genesis_activation_context_hash_v1, 0, genesis_queue_post_state)
    genesis_activation_context_return = (
        encode_migration_activation_context_return(
            4, genesis_activation_context_hash_v1, 0x6100, target_settlement,
            1, 1, 2, release_hash, target_registration_hash))
    genesis_source_post_state_return = encode_migration_post_state_return(
        1, genesis_activation_context_hash_v1, legacy_post_state)
    genesis_target_post_state_return = encode_migration_post_state_return(
        2, genesis_activation_context_hash_v1, genesis_adoption_post_state)
    genesis_queue_post_state_return = encode_migration_post_state_return(
        3, genesis_activation_context_hash_v1, genesis_queue_post_state)
    genesis_activation_receipt = ActivationReceiptV1(
        settlement_chain_id, 0xAD01, 1, 1, 1, 1, 2,
        legacy_deployment_hash, release_hash, bytes(32),
        bytes.fromhex("8b" * 32), target_registration_hash,
        0x6100, target_settlement, bytes(32), destination_domain, 0, 0xB200, 0,
        genesis_candidate_hash, canonical_core_v2_hash(genesis_output_core), 0,
        genesis_activation_context_hash_v1, legacy_abandonment_receipt_hash,
        legacy_post_state,
        genesis_adoption_post_state, genesis_queue_post_state, 1_234)
    genesis_activation_receipt_hash = activation_receipt_id(
        genesis_activation_receipt)
    genesis_activation_receipt_calldata = encode_activation_receipt_calldata(
        genesis_activation_receipt_hash)
    genesis_activation_receipt_return = encode_activation_receipt_return(
        genesis_activation_receipt)
    reorg_activation_block = 1_235
    reorg_legacy_post_state = legacy_genesis_post_state_commitment(
        legacy_launch_id, genesis_candidate_hash,
        canonical_core_v2_hash(genesis_output_core), reorg_activation_block,
        legacy_boundary_hash)
    reorg_genesis_context_hash = migration_activation_context_hash(
        settlement_chain_id, 0xAD01, 1, 1, 1, 2, legacy_deployment_hash,
        release_hash, target_registration_hash, 0x6100, target_settlement, 0,
        genesis_base, genesis_transition_hash, genesis_candidate_hash,
        genesis_output_core, 0xF000, empty_queue_root, 0, 0, 0, 0xCAFE,
        reorg_activation_block)
    reorg_genesis_adoption_post_state = migration_adoption_commitment(
        settlement_chain_id, 0xAD01, target_settlement,
        reorg_genesis_context_hash, 1, 1, 1, 2, 0, release_hash,
        genesis_candidate_hash, genesis_output_core, reorg_activation_block)
    reorg_genesis_queue_post_state = queue_migration_post_state_commitment(
        reorg_genesis_context_hash, 0xF000, target_settlement,
        empty_queue_root, 0, 0,
        0xCAFE, 0, 0, 0)
    reorg_genesis_receipt = replace(
        genesis_activation_receipt,
        activation_context_hash=reorg_genesis_context_hash,
        source_post_state_commitment=reorg_legacy_post_state,
        adoption_commitment=reorg_genesis_adoption_post_state,
        queue_post_state_commitment=reorg_genesis_queue_post_state,
        activated_at_block=reorg_activation_block)
    reorg_genesis_receipt_hash = activation_receipt_id(
        reorg_genesis_receipt)
    assert (reorg_legacy_post_state != legacy_post_state
            and reorg_genesis_context_hash
                != genesis_activation_context_hash_v1
            and reorg_genesis_receipt_hash
                != genesis_activation_receipt_hash)
    genesis_activation_fixed = MigrationActivationFixedV2(
        1, 1, 1, 2, 0, genesis_candidate_hash, genesis_output_core,
        0xCAFE, 1_000, bytes.fromhex("99" * 32), 0,
        plus_one_cursor(None))
    version_activation_fixed = MigrationActivationFixedV2(
        2, 2, 2, 3, 2, candidate_hash, version_output_core,
        0xCAFE, 1_000, bytes.fromhex("99" * 32), 66,
        plus_one_cursor(8_000))
    activation_block = 1_234
    activation_context_hash = migration_activation_context_hash(
        settlement_chain_id, 0xAD01, 2, 2, 2, 3, release_hash,
        successor_release_hash, successor_registration_hash,
        target_settlement, successor_settlement,
        2, base, version_transition_hash, candidate_hash,
        activation_output_core, 0xF000, force.root, len(envs), 2, 66,
        0xCAFE, activation_block)
    source_post_state = source_freeze_post_state_commitment(
        activation_context_hash, target_settlement, 2, 2, 2, base,
        activation_block)
    adoption_post_state = migration_adoption_commitment(
        settlement_chain_id, 0xAD01, successor_settlement,
        activation_context_hash,
        2, 2, 2, 3, 2, successor_release_hash, candidate_hash,
        activation_output_core, activation_block)
    credited_wei = sum(envelope.deposit for envelope in envs[2:66])
    queue_post_state = queue_migration_post_state_commitment(
        activation_context_hash, 0xF000, successor_settlement,
        force.root, len(envs), 66,
        0xCAFE, credited_wei, sum(envelope.deposit for envelope in envs),
        credited_wei)
    adopt_migration_calldata = encode_adopt_migration_canonical_calldata(
        2, 2, 2, 3, 2, successor_release_hash, candidate_hash,
        activation_output_core)
    adopt_migration_return = encode_migration_canonical_return(
        3, adoption_post_state)
    freeze_migration_calldata = encode_freeze_migration_source_calldata(
        activation_context_hash)
    freeze_migration_return = encode_migration_freeze_return(
        activation_context_hash, source_post_state)
    queue_migration_calldata = encode_queue_migration_calldata(
        activation_context_hash, target_settlement, successor_settlement,
        force.root, len(envs), 2, 66,
        0xCAFE)
    queue_migration_return = encode_queue_migration_return(
        activation_context_hash, credited_wei, queue_post_state)
    validate_activation_journal_consistency(
        genesis_transition, genesis_activation_fixed, genesis_base_core,
        genesis_base, empty_inbox_rows, legacy_deployment_hash, 0x6100,
        target_settlement, 1_234, genesis_activation_context_hash_v1,
        genesis_queue_migration_calldata)
    validate_activation_journal_consistency(
        version_transition, version_activation_fixed, version_base_core,
        base, version_inbox_rows, release_hash, target_settlement,
        successor_settlement,
        activation_block, activation_context_hash, queue_migration_calldata)
    for invalid_genesis_statement in (
        replace(genesis_transition, source_canonical_sequence=1),
        replace(genesis_transition, queue_count=1),
        replace(genesis_transition, force_cutoff=1),
        replace(genesis_transition, source_domain_id=source_domain),
    ):
        assert_rejects(
            lambda value=invalid_genesis_statement:
                migration_transition_statement_hash(value),
            "nonempty or ambiguous genesis transition accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest,
            (InboxRowV2(0, 0, UINT32_MAX, bytes(32), b""),),
            b"\xc0", b"\x01",
            migration_verifier.maximum_proof_bytes),
        "nonempty genesis inbox rows accepted")
    activation_context_return = encode_migration_activation_context_return(
        4, activation_context_hash, target_settlement,
        successor_settlement, 2, 2, 3,
        successor_release_hash, successor_registration_hash)
    arming_lifecycle_return = encode_migration_activation_context_return(
        1, bytes(32), 0, 0, 0, 0, 0, bytes(32), bytes(32))
    migration_post_state_calldata = encode_migration_post_state_calldata(
        activation_context_hash)
    source_post_state_return = encode_migration_post_state_return(
        1, activation_context_hash, source_post_state)
    target_post_state_return = encode_migration_post_state_return(
        2, activation_context_hash, adoption_post_state)
    queue_post_state_return = encode_migration_post_state_return(
        3, activation_context_hash, queue_post_state)
    activation_receipt = ActivationReceiptV1(
        settlement_chain_id, 0xAD01, 2, 2, 2, 2, 3, release_hash,
        successor_release_hash, bytes.fromhex("8a" * 32),
        bytes.fromhex("8b" * 32), successor_registration_hash,
        target_settlement, successor_settlement, destination_domain,
        bytes.fromhex("89" * 32), 0xB200, 0xB201, len(envs),
        candidate_hash, canonical_core_v2_hash(activation_output_core), 3,
        activation_context_hash, bytes(32), source_post_state,
        adoption_post_state,
        queue_post_state, activation_block)
    activation_receipt_hash = activation_receipt_id(activation_receipt)
    activation_receipt_return = encode_activation_receipt_return(
        activation_receipt)
    imported_header_rlp = b"\xe1\xa0" + bytes.fromhex("82" * 32)
    migration_proof = bytes.fromhex("a1" * 65)
    genesis_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, empty_inbox_rows,
            imported_header_rlp, migration_proof,
            migration_verifier.maximum_proof_bytes))
    version_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            version_activation_fixed, successor_release_manifest, inbox_rows, b"",
            migration_proof, migration_verifier.maximum_proof_bytes))
    maximum_genesis_header_rlp = (
        b"\xf9\x07\xfd\xb9\x07\xfa" + bytes(2_042))
    maximum_migration_proof = bytes.fromhex("a2") \
        * MAX_MIGRATION_PROOF_BYTES
    maximum_genesis_rows: tuple[InboxRowV2, ...] = ()
    maximum_version_rows = tuple(
        InboxRowV2(index, 0, UINT32_MAX, bytes(32), b"")
        for index in range(2, 64)) + (
            InboxRowV2(64, 5, UINT32_MAX, bridge_credit_result(70, bridge),
                       durable_bridge_descriptor),
            InboxRowV2(65, 5, UINT32_MAX, bridge_credit_result(70, bridge),
                       durable_bridge_descriptor),
        )
    maximum_genesis_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, maximum_genesis_rows,
            maximum_genesis_header_rlp, maximum_migration_proof,
            MAX_MIGRATION_PROOF_BYTES))
    maximum_version_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            version_activation_fixed, successor_release_manifest,
            maximum_version_rows,
            b"", maximum_migration_proof, MAX_MIGRATION_PROOF_BYTES))
    source_context = SourceContextV2(
        2, 1, bridge_credit, bridge_msg_hash, source_domain, 7,
        source_bridge_address,
        bridge_execution, bridge.emitted_at_block, 70)
    destination_context = DestinationContextV2(
        l2_chain_id, destination_domain, 0xB200, release_hash,
        profile_hash)
    normalized_message = MessageV1(
        71, 1_234, 800_000, 0x1111, 1, 0x2222, l2_chain_id,
        0x3333, 0x4444, 10**18, bytes(range(33)))
    inbox_credit = InboxCreditV2(
        70, 1, source_domain, 7, source_bridge_address, destination_domain,
        bridge_msg_hash, bridge_credit_result(70, bridge),
        source_context_hash(source_context), bridge.value, bridge.fee,
        bridge.liquidity_fee)
    inbox_batch_calldata = encode_mark_inbox_batch_calldata((inbox_credit,))
    liquidity_quote_return = (
        inbox_credit.result_hash + u256(inbox_credit.value)
        + u256(inbox_credit.execution_fee) + u256(inbox_credit.liquidity_fee)
        + u256(bridge.enqueue_by))
    funding_state_return = (
        destination_domain + address_word(0xB200) + address_word(0x5101)
        + u256(1) + u256(0))
    verify_inbox_return = (
        bridge_credit + u256(bridge.enqueue_by) + u256(bridge.value)
        + u256(bridge.fee) + u256(bridge.liquidity_fee)
        + source_context_hash(source_context))
    route_config_getter_calldata = ROUTE_CONFIG_GETTER_SELECTOR
    verify_inbox_calldata = (
        VERIFY_INBOX_CREDIT_SELECTOR + u256(1) + source_domain + u256(7)
        + address_word(source_bridge_address) + destination_domain
        + bridge_msg_hash)
    inbox_slot_calldata = (
        GET_INBOX_CREDIT_SLOT_SELECTOR + source_domain
        + address_word(source_bridge_address)
        + destination_domain + bridge_credit)
    liquidity_quote_calldata = LIQUIDITY_QUOTE_SELECTOR + bridge_credit
    funding_state_calldata = LIQUIDITY_FUNDING_STATE_SELECTOR + bridge_credit
    status_return = encode_status_return(1, 7)
    attempt_digest = bytes.fromhex("96" * 32)
    target_error = target_call_failed_error(attempt_digest)
    terminal_commitment_return = encode_terminal_commitment_return(
        destination_domain, 0xB200, 1, UINT64_MAX,
        liquidity_settlement_hash(bytes.fromhex("45" * 32), 0x7777,
                                  bridge.value + bridge.fee))
    terminal_state_return = encode_terminal_state_return(
        2, bytes.fromhex("97" * 32))
    finalize_failed_calldata = FINALIZE_FAILED_ATTEMPT_SELECTOR + bridge_credit
    append_terminal_calldata = APPEND_TERMINAL_SELECTOR + bridge_credit
    terminal_commitment_calldata = TERMINAL_COMMITMENT_SELECTOR + bridge_credit
    terminal_state_calldata = TERMINAL_STATE_SELECTOR
    terminal_append_return = u256(2)
    ticket_salt = bytes.fromhex("46" * 32)
    ticket_hash = liquidity_ticket_id(
        l2_chain_id, 0x5104, 0x8888, 0x9999, ticket_salt)
    pool_amount = bridge.value + bridge.fee
    pool_authorization = liquidity_attempt_authorization(
        l2_chain_id, destination_domain, 0x5104, 0xB200, 0x5101,
        bridge_credit, ticket_hash, 0x8888, inbox_credit.result_hash,
        pool_amount, source_context_hash(source_context),
        destination_context_hash(destination_context), 2, False)
    pool_process_calldata = encode_process_with_liquidity_calldata(
        ticket_hash, 0xB200, normalized_message, source_context,
        destination_context)
    pool_retry_calldata = encode_retry_with_liquidity_calldata(
        ticket_hash, 0xB200, normalized_message, source_context,
        destination_context, True)
    pool_bridge_attempt_calldata = encode_pool_bridge_attempt_calldata(
        ticket_hash, 0x8888, normalized_message, source_context,
        destination_context, 2, False, pool_authorization)
    execute_attempt_calldata = encode_execute_attempt_calldata(
        normalized_message, source_context, destination_context,
        0x8888, 1, False, ticket_hash, pool_authorization)
    pool_deposit_calldata = encode_pool_word_calldata(
        DEPOSIT_LIQUIDITY_V2_SELECTOR, address_word(0x9999), ticket_salt)
    pool_withdraw_calldata = encode_pool_word_calldata(
        WITHDRAW_LIQUIDITY_V2_SELECTOR, ticket_hash, address_word(0x8888),
        u256(5))
    pool_ticket_calldata = encode_pool_word_calldata(
        TICKET_ACCOUNTING_V2_SELECTOR, ticket_hash)
    pool_accounting_calldata = POOL_ACCOUNTING_V2_SELECTOR
    pool_consume_calldata = encode_pool_word_calldata(
        CONSUME_AUTHORIZED_LIQUIDITY_V2_SELECTOR, ticket_hash, bridge_credit,
        address_word(0x8888), u256(pool_amount), inbox_credit.result_hash)
    pool_callback_calldata = encode_pool_word_calldata(
        ACCEPT_LIQUIDITY_VALUE_V2_SELECTOR, bridge_credit, ticket_hash,
        u256(pool_amount))
    pool_deposit_return = ticket_hash + u256(7 + pool_amount)
    pool_withdraw_return = u256(2)
    pool_ticket_return = address_word(0x8888) + address_word(0x9999) + u256(
        7 + pool_amount)
    pool_balance = 7 + pool_amount + 5
    pool_accounting_return = (
        bytes4_word(POOL_ACCOUNTING_MAGIC)
        + infrastructure_components[8].config_hash
        + u256(1) + u256(0) + bytes(32)
        + u256(7 + pool_amount) + u256(pool_balance) + u256(5))
    pool_consume_return = ticket_hash + address_word(0x9999) + u256(pool_amount)
    pool_callback_return = bytes4_word(POOL_VALUE_MAGIC)
    pool_settlement_hash = liquidity_settlement_hash(
        ticket_hash, 0x9999, pool_amount)
    pool_bridge_result_return = encode_pool_bridge_result_return(
        bridge_credit, 2, 1, 3, pool_settlement_hash)
    pool_acceptance = liquidity_acceptance_commitment(
        l2_chain_id, destination_domain, 0xB200, 0x5104,
        bridge_credit, ticket_hash, 0x8888, inbox_credit.result_hash,
        pool_amount, attempt_digest)
    denied_targets = tuple(sorted((0, 0x5100, 0x5101, 0x5102, 0x5103,
                                   0x5104, 0x5107, 0xB200)))
    invocation_hash = invocation_policy_hash(denied_targets)
    invocation_return = encode_invocation_policy_return(invocation_hash, True)
    invocation_policy_calldata = (
        INVOCATION_POLICY_GETTER_SELECTOR + destination_domain
        + address_word(0xB200))
    normalized_preimage = normalized_message_hash_preimage(normalized_message)
    normalized_hash = normalized_message_hash(normalized_message)
    send_calldata = encode_message_v2_calldata(
        SEND_MESSAGE_V2_SELECTOR, normalized_message, 5_678)
    enqueue_calldata = encode_message_v2_calldata(
        ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR, normalized_message, 5_678)
    raw_transaction = b"\x02" + bytes(range(1, 34))
    enqueue_forced_calldata = encode_enqueue_forced_transaction_calldata(
        raw_transaction, 9_999, 0xBEEF)
    sync_stamp_return = encode_sync_ingress_return(1, 2, 7)
    sync_synced_return = encode_sync_ingress_return(2, 0, 0)
    append_kind0_calldata = encode_append_from_adapter_calldata(
        2, 7, 0, forced_descriptor(envs[2]))
    append_kind1_calldata = encode_append_from_adapter_calldata(
        2, 7, 1, durable_bridge_descriptor)
    queued_return = encode_queued_return(70)
    bridge_hash = bridge_leaf(70, bridge)
    settlement_hash = liquidity_settlement_hash(
        bytes.fromhex("45" * 32), 0x7777, bridge.value + bridge.fee)
    done_leaf = terminal_leaf(
        0, destination_domain, 0xB200, bridge_credit, 1, settlement_hash)
    failed_leaf = terminal_leaf(1, destination_domain, 0xB200,
                                bytes.fromhex("24" * 32), 2, bytes(32))
    terminal_vector = TerminalVector((done_leaf, failed_leaf))
    changed_liquidity_fee_leaf = bridge_leaf(
        70, replace(bridge, liquidity_fee=bridge.liquidity_fee + 1))
    changed_liquidity_fee_credit = bridge_credit_id(
        bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
        bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash,
        bridge.liquidity_fee + 1)
    changed_settlement_leaf = terminal_leaf(
        0, destination_domain, 0xB200, bridge_credit, 1,
        liquidity_settlement_hash(
            bytes.fromhex("45" * 32), 0x7777,
            bridge.value + bridge.fee + 1))
    changed_pool_components = (
        *infrastructure_components[:8],
        replace(infrastructure_components[8],
                config_hash=bytes.fromhex("6c" * 32)),
        infrastructure_components[9],
    )
    empty_body = body_root(())
    empty_manifest = manifest_root(())
    empty_sessions = session_list(())
    assert_all_fields_bound(genesis_deployment, deployment_commitment_hash)
    assert_all_fields_bound(version_deployment, deployment_commitment_hash)
    assert_all_fields_bound(genesis_transition,
                            migration_transition_statement_hash)
    assert_all_fields_bound(version_transition,
                            migration_transition_statement_hash)
    assert genesis_import_checkpoint_valid(
        genesis_transition, imported_header_number)
    assert not genesis_import_checkpoint_valid(
        genesis_transition, imported_header_number + 1)
    assert genesis_import_checkpoint_valid(version_transition, None)
    assert not genesis_import_checkpoint_valid(version_transition, 0)
    assert plus_one_cursor(None) == 0 and plus_one_cursor(0) == 1
    assert plus_one_cursor(UINT64_MAX - 1) == UINT64_MAX
    assert_rejects(lambda: plus_one_cursor(UINT64_MAX),
                   "overflow cursor accepted")
    assert_all_fields_bound(registration_statement,
                            registration_storage_statement_hash)
    assert decode_verify_registration_calldata(
        registration_verification_calldata) \
        == (registration_statement, registration_proof)
    assert decode_registration_verifier_return(
        registration_verifier_return, registration_statement_hash) \
        == registration_statement_hash
    assert decode_configuration_hash_return(
        registration_config_getter_return,
        registration_mpt_configuration_hash) \
        == registration_mpt_configuration_hash
    assert_rejects(
        lambda: decode_registration_verifier_return(
            registration_verifier_return + bytes(32),
            registration_statement_hash),
        "trailing registration verifier return accepted")
    assert_rejects(
        lambda: decode_registration_verifier_return(
            bytes.fromhex("99" * 32), registration_statement_hash),
        "mismatched registration statement return accepted")
    for malformed_registration_calldata in (
        registration_verification_calldata + bytes(32),
        registration_verification_calldata[:4 + 12 * 32] + u256(0)
        + registration_verification_calldata[4 + 13 * 32:],
        registration_verification_calldata[:-1] + b"\x01",
    ):
        assert_rejects(
            lambda value=malformed_registration_calldata:
                decode_verify_registration_calldata(value),
            "malformed registration calldata accepted")
    assert_all_fields_bound(source_context, source_context_hash)
    assert_all_fields_bound(destination_context, destination_context_hash)
    assert_all_fields_bound(destination_receipt,
                            destination_activation_receipt_id)
    assert_all_fields_bound(activation_receipt, activation_receipt_id)
    assert_all_fields_bound(kind0_ingress, ingress_authorization_id)
    assert_all_fields_bound(kind1_ingress, ingress_authorization_id)
    assert ingress_root == validate_ingress_authorization_set(
        (kind0_ingress, kind1_ingress), ingress_graph)
    assert_rejects(
        lambda: validate_ingress_authorization_set(
            (kind0_ingress,
             replace(kind1_ingress,
                     maximum_accepted_fee_wei=ingress_fees[4] + 1)),
            ingress_graph), "mixed ingress fee schedule accepted")
    assert_rejects(
        lambda: validate_ingress_authorization_set(
            (kind0_ingress,
             replace(kind1_ingress, forced_queue=kind1_ingress.forced_queue + 1)),
            ingress_graph), "mixed ingress graph accepted")
    assert_rejects(
        lambda: validate_ingress_authorization_set(
            (kind0_ingress,
             replace(kind1_ingress,
                     destination_domain_id=bytes.fromhex("98" * 32))),
            ingress_graph), "manifest-substituted ingress accepted")
    assert_rejects(
        lambda: validate_ingress_authorization_set(
            (replace(kind0_ingress,
                     adapter_configuration_hash=bytes.fromhex("99" * 32)),
             kind1_ingress), ingress_graph),
        "adapter-substituted ingress accepted")
    assert_rejects(
        lambda: ingress_authorization_root((kind0_ingress, kind0_ingress)),
        "duplicate ingress authorization accepted")
    assert_rejects(
        lambda: ingress_authorization_root((
            kind0_ingress,
            replace(kind1_ingress, adapter=kind0_ingress.adapter))),
        "duplicate ingress adapter accepted")
    assert_rejects(
        lambda: ingress_authorization_id(replace(kind1_ingress, kind=2)),
        "unknown ingress kind accepted")
    assert decode_message_v2_calldata(send_calldata) \
        == (SEND_MESSAGE_V2_SELECTOR, normalized_message, 5_678)
    assert_all_fields_bound(normalized_message, normalized_message_hash)
    assert decode_message_v2_calldata(enqueue_calldata) \
        == (ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR, normalized_message, 5_678)
    assert_rejects(
        lambda: encode_message_v2_calldata(
            SEND_MESSAGE_V2_SELECTOR, normalized_message, 0),
        "zero MessageV1 liquidity fee accepted")
    normalized_return = encode_send_message_v2_return(
        normalized_hash, normalized_message)
    assert decode_send_message_v2_return(normalized_return) \
        == (normalized_hash, normalized_message)
    assert_rejects(
        lambda: canonical_message_v1(
            replace(normalized_message, value=0, fee=0)),
        "zero MessageV1 settlement amount accepted")
    assert_rejects(
        lambda: canonical_message_v1(
            replace(normalized_message, value=(1 << 256) - 1, fee=1)),
        "overflow MessageV1 settlement amount accepted")
    assert_rejects(
        lambda: bridge_descriptor(replace(bridge, value=0, fee=0)),
        "zero V11 settlement amount accepted")
    assert_rejects(
        lambda: bridge_descriptor(
            replace(bridge, value=(1 << 256) - 1, fee=1)),
        "overflow V11 settlement amount accepted")
    assert ENQUEUE_FORCED_TRANSACTION_SELECTOR.hex() == "9f06b1b4"
    assert SYNC_INGRESS_SELECTOR.hex() == "6c880b72"
    assert APPEND_FROM_ADAPTER_SELECTOR.hex() == "1927261d"
    assert decode_enqueue_forced_transaction_calldata(
        enqueue_forced_calldata) == (raw_transaction, 9_999, 0xBEEF)
    assert decode_sync_ingress_return(sync_stamp_return) == (1, 2, 7)
    assert decode_sync_ingress_return(sync_synced_return) == (2, 0, 0)
    assert decode_append_from_adapter_calldata(append_kind0_calldata) \
        == (2, 7, 0, forced_descriptor(envs[2]))
    assert decode_append_from_adapter_calldata(append_kind1_calldata) \
        == (2, 7, 1, durable_bridge_descriptor)
    assert decode_queued_return(queued_return) == 70
    for malformed_adapter_value, decoder in (
        (enqueue_forced_calldata + bytes(32),
         decode_enqueue_forced_transaction_calldata),
        (enqueue_forced_calldata[:-1] + b"\x01",
         decode_enqueue_forced_transaction_calldata),
        (enqueue_forced_calldata[:36] + u256(1 << 64)
         + enqueue_forced_calldata[68:],
         decode_enqueue_forced_transaction_calldata),
        (sync_stamp_return[:-1], decode_sync_ingress_return),
        (u256(1) + u256(0) + u256(7), decode_sync_ingress_return),
        (u256(1 << 8) + u256(2) + u256(7), decode_sync_ingress_return),
        (append_kind0_calldata + bytes(32),
         decode_append_from_adapter_calldata),
        (append_kind0_calldata[:100] + u256(160)
         + append_kind0_calldata[132:],
         decode_append_from_adapter_calldata),
        (append_kind0_calldata[:68] + u256(1 << 8)
         + append_kind0_calldata[100:],
         decode_append_from_adapter_calldata),
        (append_kind1_calldata[:-1] + b"\x01",
         decode_append_from_adapter_calldata),
        (u256(2) + u256(70), decode_queued_return),
        (u256(1) + u256(UINT64_MAX), decode_queued_return),
    ):
        assert_rejects(
            lambda value=malformed_adapter_value, fn=decoder: fn(value),
            "malformed stamped Router ABI accepted")
    for malformed_message_calldata in (
        send_calldata + bytes(32),
        send_calldata[:4] + u256(96) + send_calldata[36:],
        send_calldata[:68] + u256(1 << 64) + send_calldata[100:],
        send_calldata[:68 + 10 * 32] + u256(12 * 32)
        + send_calldata[68 + 11 * 32:],
        send_calldata[:68 + 11 * 32] + u256(65)
        + send_calldata[68 + 12 * 32:],
        send_calldata[:68 + 3 * 32] + u256(1 << 160)
        + send_calldata[68 + 4 * 32:],
        send_calldata[:-1] + b"\x01",
    ):
        assert_rejects(
            lambda value=malformed_message_calldata:
                decode_message_v2_calldata(value),
            "malformed MessageV1 calldata accepted")
    assert decode_inbox_apply_calldata(inbox_apply_calldata) == (2, inbox_rows)
    assert ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR == keccak256(
        ACTIVATE_VERSION_WITH_MIGRATION_SIGNATURE)[:4]
    assert_all_fields_bound(activation_output_core, canonical_core_v2_abi)
    assert_all_fields_bound(genesis_activation_fixed,
                            canonical_migration_activation_fixed)
    assert decode_activate_version_with_migration_calldata(
        genesis_activation_calldata, genesis_activation_fixed,
        release_manifest, migration_verifier.maximum_proof_bytes) \
        == (empty_inbox_rows, imported_header_rlp, migration_proof)
    assert decode_activate_version_with_migration_calldata(
        version_activation_calldata, version_activation_fixed,
        successor_release_manifest,
        migration_verifier.maximum_proof_bytes) \
        == (inbox_rows, b"", migration_proof)
    assert decode_activate_version_with_migration_calldata(
        maximum_genesis_activation_calldata, genesis_activation_fixed,
        release_manifest, MAX_MIGRATION_PROOF_BYTES) \
        == (maximum_genesis_rows, maximum_genesis_header_rlp,
            maximum_migration_proof)
    assert decode_activate_version_with_migration_calldata(
        maximum_version_activation_calldata, version_activation_fixed,
        successor_release_manifest, MAX_MIGRATION_PROOF_BYTES) \
        == (maximum_version_rows, b"", maximum_migration_proof)
    assert ADOPT_MIGRATION_CANONICAL_SELECTOR.hex() == "557c4e13"
    assert FREEZE_MIGRATION_SOURCE_SELECTOR.hex() == "45a80913"
    assert MIGRATE_ACTIVE_SETTLEMENT_SELECTOR.hex() == "9461f698"
    assert MIGRATION_ACTIVATION_CONTEXT_SELECTOR.hex() == "7cf70319"
    assert MIGRATION_ACTIVATION_POST_STATE_SELECTOR.hex() == "66e664cb"
    assert LEGACY_GENESIS_STATE_SELECTOR.hex() == "9b698000"
    assert LEGACY_GENESIS_CAMPAIGN_SELECTOR.hex() == "718b2ac7"
    assert LEGACY_GENESIS_PREPARATION_SELECTOR.hex() == "6880cd05"
    assert LEGACY_GENESIS_BEGIN_SCAN_SELECTOR.hex() == "e9d1a07f"
    assert LEGACY_GENESIS_SCAN_PROPOSALS_SELECTOR.hex() == "7da66460"
    assert LEGACY_GENESIS_SCAN_FORCED_SELECTOR.hex() == "032ae99e"
    assert LEGACY_GENESIS_SCAN_STATE_SELECTOR.hex() == "ef3cdce0"
    assert LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR.hex() == "4c0ae8da"
    assert LEGACY_GENESIS_RESUME_SELECTOR.hex() == "2bf6b656"
    assert LEGACY_GENESIS_EXPIRE_SELECTOR.hex() == "a4a37936"
    assert LEGACY_GENESIS_ARM_SELECTOR.hex() == "8781a058"
    assert LEGACY_GENESIS_FINALIZE_SELECTOR.hex() == "c2de6417"
    assert decode_legacy_genesis_campaign_return(
        legacy_campaign_return, legacy_deployment_hash) == legacy_campaign
    empty_legacy_campaign = LegacyGenesisCampaignV1(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, bytes(32), bytes(32),
        bytes(32), bytes(32))
    assert decode_legacy_genesis_campaign_return(
        encode_legacy_genesis_campaign_return(
            empty_legacy_campaign, legacy_deployment_hash),
        legacy_deployment_hash) == empty_legacy_campaign
    for retained_status in (2, 3, 4):
        retained_campaign = replace(legacy_campaign, status=retained_status)
        assert decode_legacy_genesis_campaign_return(
            encode_legacy_genesis_campaign_return(
                retained_campaign, legacy_deployment_hash),
            legacy_deployment_hash) == retained_campaign
    assert LEGACY_RESUME_VERIFIER_CONFIG_SELECTOR.hex() == "7e52cacd"
    assert LEGACY_RESUME_RISC0_CONFIG_SELECTOR.hex() == "e516c43e"
    assert LEGACY_RESUME_SP1_CONFIG_SELECTOR.hex() == "e2b5d958"
    assert LEGACY_CHECKPOINT_CONFIG_SELECTOR.hex() == "68011023"
    assert LEGACY_DESCRIPTOR_IMPL_SELECTOR.hex() == "8abf6077"
    assert LEGACY_OPERATOR_COUNT_SELECTOR.hex() == "7c6f3158"
    assert LEGACY_CURRENT_OPERATOR_SELECTOR.hex() == "343f0a68"
    assert LEGACY_NEXT_OPERATOR_SELECTOR.hex() == "72a8a551"
    assert LEGACY_SIGNAL_SERVICE_VERSION_SELECTOR.hex() == "ffa1ad74"
    assert legacy_genesis_campaign_fence_descriptor_hash(0xAD01, 0x6100) \
        == legacy_campaign_fence_descriptor_hash
    for fence_args in ((0xAD02, 0x6100), (0xAD01, 0x6102)):
        assert legacy_genesis_campaign_fence_descriptor_hash(*fence_args) \
            != legacy_campaign_fence_descriptor_hash
    legacy_fence_body = (
        address20(0xAD01) + address20(0x6100)
        + LEGACY_GENESIS_CAMPAIGN_SELECTOR + LEGACY_GENESIS_CAMPAIGN_MAGIC
        + u16(512) + u32(LEGACY_DESCRIPTOR_CALL_GAS)
        + LEGACY_GENESIS_STATE_SELECTOR + LEGACY_GENESIS_STATE_MAGIC
        + u16(512) + u32(LEGACY_DESCRIPTOR_CALL_GAS)
        + LEGACY_GENESIS_SCAN_STATE_SELECTOR + LEGACY_GENESIS_SCAN_STATE_MAGIC
        + u16(608) + u32(LEGACY_DESCRIPTOR_CALL_GAS))
    assert keccak256(D_LEGACY_GENESIS_CAMPAIGN_FENCE + legacy_fence_body) \
        == legacy_campaign_fence_descriptor_hash
    for changed_fence_body in (
            legacy_fence_body[:40] + bytes.fromhex("00000000")
                + legacy_fence_body[44:],
            legacy_fence_body[:44] + bytes.fromhex("00000000")
                + legacy_fence_body[48:],
            legacy_fence_body[:48] + u16(511) + legacy_fence_body[50:],
            legacy_fence_body[:50] + u32(99_999) + legacy_fence_body[54:],
            legacy_fence_body[:54]
                + legacy_fence_body[68:82] + legacy_fence_body[54:68]
                + legacy_fence_body[82:]):
        assert keccak256(
            D_LEGACY_GENESIS_CAMPAIGN_FENCE + changed_fence_body) \
            != legacy_campaign_fence_descriptor_hash
    assert legacy_genesis_risc0_resume_key_policy_hash(
        *legacy_risc0_key_args) == legacy_risc0_resume_key_policy_hash
    assert legacy_genesis_sp1_resume_key_policy_hash(
        *legacy_sp1_key_args) == legacy_sp1_resume_key_policy_hash
    for key_policy_function, key_args, key_policy_hash in (
            (legacy_genesis_risc0_resume_key_policy_hash,
             legacy_risc0_key_args, legacy_risc0_resume_key_policy_hash),
            (legacy_genesis_sp1_resume_key_policy_hash,
             legacy_sp1_key_args, legacy_sp1_resume_key_policy_hash)):
        for key_index in range(2):
            changed_key_args = list(key_args)
            changed_key_args[key_index] = changed_field_value(
                changed_key_args[key_index])
            assert key_policy_function(*changed_key_args) != key_policy_hash
        assert key_policy_function(*reversed(key_args)) != key_policy_hash
    for descriptor_function, descriptor_args, descriptor_hash in (
            (legacy_genesis_risc0_reth_verifier_descriptor_hash,
             legacy_risc0_descriptor_args,
             legacy_risc0_reth_verifier_descriptor_hash),
            (legacy_genesis_sp1_reth_verifier_descriptor_hash,
             legacy_sp1_descriptor_args,
             legacy_sp1_reth_verifier_descriptor_hash)):
        assert descriptor_function(*descriptor_args) == descriptor_hash
        for descriptor_index in range(len(descriptor_args)):
            changed_descriptor_args = list(descriptor_args)
            changed_descriptor_args[descriptor_index] = changed_field_value(
                changed_descriptor_args[descriptor_index])
            try:
                changed_descriptor_hash = descriptor_function(
                    *changed_descriptor_args)
            except AssertionError:
                continue
            assert changed_descriptor_hash != descriptor_hash
    assert legacy_genesis_proof_verifier_graph_hash(
        *legacy_proof_verifier_graph_args) == legacy_proof_verifier_graph_hash
    for graph_index in range(len(legacy_proof_verifier_graph_args)):
        changed_graph_args = list(legacy_proof_verifier_graph_args)
        changed_graph_args[graph_index] = changed_field_value(
            changed_graph_args[graph_index])
        assert legacy_genesis_proof_verifier_graph_hash(*changed_graph_args) \
            != legacy_proof_verifier_graph_hash
    graph_prefix = (
        D_LEGACY_GENESIS_PROOF_VERIFIER_GRAPH
        + address20(legacy_proof_verifier_graph_args[0])
        + b32(legacy_proof_verifier_graph_args[1]))
    graph_members = (
        u8(5) + address20(legacy_proof_verifier_graph_args[2])
        + b32(legacy_proof_verifier_graph_args[3]),
        u8(6) + address20(legacy_proof_verifier_graph_args[4])
        + b32(legacy_proof_verifier_graph_args[5]))
    for changed_graph_suffix in (
            u8(3) + b"".join(graph_members),
            u8(2) + u8(6) + graph_members[0][1:] + graph_members[1],
            u8(2) + graph_members[1] + graph_members[0]):
        assert keccak256(graph_prefix + changed_graph_suffix) \
            != legacy_proof_verifier_graph_hash
    legacy_route_args = (
        legacy_resume_profile.proof_verifier_graph_hash,
        legacy_risc0_reth_verifier_descriptor_hash,
        legacy_risc0_resume_key_policy_hash,
        legacy_sp1_reth_verifier_descriptor_hash,
        legacy_sp1_resume_key_policy_hash)
    assert legacy_genesis_resume_verifier_route_hash(*legacy_route_args) \
        == legacy_resume_verifier_route_hash
    for route_index in range(len(legacy_route_args)):
        changed_route_args = list(legacy_route_args)
        changed_route_args[route_index] = changed_field_value(
            changed_route_args[route_index])
        assert legacy_genesis_resume_verifier_route_hash(
            *changed_route_args) != legacy_resume_verifier_route_hash
    assert keccak256(
        D_LEGACY_GENESIS_RESUME_VERIFIER_ROUTE
        + b32(legacy_route_args[0]) + u8(3)
        + u8(5) + b32(legacy_route_args[1])
        + b32(legacy_route_args[2])
        + u8(6) + b32(legacy_route_args[3])
        + b32(legacy_route_args[4])) \
        != legacy_resume_verifier_route_hash
    assert legacy_genesis_proposer_checker_descriptor_hash(
        *legacy_proposer_checker_descriptor_args) \
        == legacy_proposer_checker_descriptor_hash
    for proposer_index in range(len(legacy_proposer_checker_descriptor_args)):
        changed_proposer_args = list(legacy_proposer_checker_descriptor_args)
        changed_proposer_args[proposer_index] = changed_field_value(
            changed_proposer_args[proposer_index])
        try:
            changed_proposer_descriptor_hash = (
                legacy_genesis_proposer_checker_descriptor_hash(
                    *changed_proposer_args))
        except AssertionError:
            continue
        assert changed_proposer_descriptor_hash \
            != legacy_proposer_checker_descriptor_hash
    assert legacy_prover_whitelist_descriptor_hash == keccak256(
        D_LEGACY_GENESIS_PUBLIC_PROVING + address20(0) + u8(1))
    assert legacy_prover_whitelist_descriptor_hash != keccak256(
        D_LEGACY_GENESIS_PUBLIC_PROVING + address20(1) + u8(1))
    assert legacy_prover_whitelist_descriptor_hash != keccak256(
        D_LEGACY_GENESIS_PUBLIC_PROVING + address20(0) + u8(0))
    checkpoint_record_hash = keccak256(
        D_LEGACY_GENESIS_CHECKPOINT_RECORD_LITERAL)
    assert legacy_checkpoint_storage_layout_hash == keccak256(
        D_LEGACY_GENESIS_CHECKPOINT_LAYOUT + u256(1) + u16(254)
        + checkpoint_record_hash)
    for checkpoint_layout_preimage in (
            D_LEGACY_GENESIS_CHECKPOINT_LAYOUT + u256(2) + u16(254)
                + checkpoint_record_hash,
            D_LEGACY_GENESIS_CHECKPOINT_LAYOUT + u256(1) + u16(253)
                + checkpoint_record_hash,
            D_LEGACY_GENESIS_CHECKPOINT_LAYOUT + u256(1) + u16(254)
                + keccak256(b"CheckpointRecord(bytes32,bytes32)")):
        assert keccak256(checkpoint_layout_preimage) \
            != legacy_checkpoint_storage_layout_hash
    assert keccak256(
        D_LEGACY_GENESIS_RESUME_VERIFIER_ROUTE
        + b32(legacy_route_args[0]) + u8(2)
        + u8(6) + b32(legacy_route_args[1])
        + b32(legacy_route_args[2])
        + u8(5) + b32(legacy_route_args[3])
        + b32(legacy_route_args[4])) \
        != legacy_resume_verifier_route_hash
    assert keccak256(
        D_LEGACY_GENESIS_RESUME_VERIFIER_ROUTE
        + b32(legacy_route_args[0]) + u8(2)
        + u8(5) + b32(legacy_route_args[3])
        + b32(legacy_route_args[4])
        + u8(6) + b32(legacy_route_args[1])
        + b32(legacy_route_args[2])) \
        != legacy_resume_verifier_route_hash
    assert legacy_genesis_signal_service_checkpoint_descriptor_hash(
        *legacy_signal_service_descriptor_args) \
        == legacy_signal_service_checkpoint_descriptor_hash
    for descriptor_index in range(
            len(legacy_signal_service_descriptor_args)):
        changed_descriptor_args = list(legacy_signal_service_descriptor_args)
        changed_descriptor_args[descriptor_index] = changed_field_value(
            changed_descriptor_args[descriptor_index])
        try:
            changed_descriptor_hash = (
                legacy_genesis_signal_service_checkpoint_descriptor_hash(
                    *changed_descriptor_args))
        except AssertionError:
            continue
        assert changed_descriptor_hash \
            != legacy_signal_service_checkpoint_descriptor_hash
    assert decode_legacy_resume_verifier_config_return(
        legacy_resume_verifier_config_return) == (
            legacy_risc0_adapter, legacy_sp1_adapter,
            legacy_risc0_resume_key_policy_hash,
            legacy_sp1_resume_key_policy_hash)
    assert decode_legacy_resume_risc0_config_return(
        legacy_resume_risc0_config_return) == (
            l2_chain_id, legacy_risc0_remote_verifier,
            legacy_risc0_remote_runtime_hash, *legacy_risc0_key_args)
    assert decode_legacy_resume_sp1_config_return(
        legacy_resume_sp1_config_return) == (
            l2_chain_id, legacy_sp1_remote_verifier,
            legacy_sp1_remote_runtime_hash, *legacy_sp1_key_args)
    assert decode_legacy_checkpoint_config_return(
        legacy_checkpoint_config_return) == (
            0x6100, 0x6302, 0x6303,
            legacy_checkpoint_storage_layout_hash,
            legacy_campaign_fence_descriptor_hash)
    assert decode_legacy_address_getter_return(
        legacy_proposer_impl_return) == 0x6701
    assert decode_legacy_address_getter_return(
        legacy_signal_impl_return) == 0x6301
    assert decode_legacy_operator_count_return(
        legacy_operator_count_return) == 3
    assert decode_legacy_address_getter_return(
        legacy_current_operator_return) == 0x6710
    assert decode_legacy_address_getter_return(
        legacy_next_operator_return) == 0x6711
    assert decode_legacy_signal_service_version_return(
        legacy_signal_version_return) == 1
    assert LEGACY_GENESIS_RESUME_TIME_POLICY_LITERAL == (
        b"LegacyGenesisResumeTimePolicyV2(sameProofPreserved=false,"
        b"ageIndependentRouteRequired=true,publicProvingRequired=true,"
        b"minBond=0,livenessBond=0,"
        b"noContest=true,forcedDueOnlyStrengthens=true,"
        b"withdrawalOnlyMatures=true)")
    assert legacy_genesis_resume_time_policy_hash() != keccak256(
        b"LegacyGenesisResumeTimePolicyV1(ageIgnored=true,minBond=0,"
        b"livenessBond=0,noContest=true,forcedDueOnlyStrengthens=true,"
        b"withdrawalOnlyMatures=true)")
    assert legacy_resume_profile_hash != keccak256(
        b"slot-chain-legacy-genesis-resume-profile-v1"
        + _legacy_genesis_resume_profile_body(legacy_resume_profile))
    assert_all_fields_bound(
        legacy_resume_profile, legacy_genesis_resume_profile_hash)
    one_blob_slice = forced_inclusions[0].blob_slice
    maximum_blob_slice = proposal_11.sources[-1].blob_slice
    mixed_source = proposal_10.sources[-1]
    assert decode_legacy_blob_slice(
        encode_legacy_blob_slice(one_blob_slice)) == one_blob_slice
    assert decode_legacy_blob_slice(
        encode_legacy_blob_slice(maximum_blob_slice)) == maximum_blob_slice
    assert decode_legacy_derivation_source(
        encode_legacy_derivation_source(mixed_source)) == mixed_source
    assert decode_legacy_proposal(proposal_encodings[0]) == proposal_10
    assert decode_legacy_proposal(proposal_encodings[1]) == proposal_11
    assert decode_legacy_forced_inclusion(
        forced_record_encodings[0]) == forced_inclusions[0]
    assert_all_fields_bound(
        one_blob_slice,
        lambda value: keccak256(encode_legacy_blob_slice(value)))
    assert_all_fields_bound(
        forced_inclusions[0],
        lambda value: keccak256(encode_legacy_forced_inclusion(value)))
    proposal_10_hash = keccak256(proposal_encodings[0])
    for proposal_field in fields(proposal_10):
        if proposal_field.name == "sources":
            changed_sources = (
                replace(
                    proposal_10.sources[0],
                    blob_slice=replace(
                        proposal_10.sources[0].blob_slice,
                        blob_hashes=(bytes.fromhex("d1" * 32),))),
                *proposal_10.sources[1:])
            changed_proposal = replace(
                proposal_10, sources=changed_sources)
        else:
            changed_proposal = replace(
                proposal_10,
                **{proposal_field.name: changed_field_value(
                    getattr(proposal_10, proposal_field.name))})
        try:
            changed_proposal_hash = keccak256(
                encode_legacy_proposal(changed_proposal))
        except AssertionError:
            continue
        assert changed_proposal_hash != proposal_10_hash
    assert proposal_rows[0][2] == proposal_10_hash
    assert proposal_rows[1][2] == keccak256(proposal_encodings[1])
    assert forced_rows[0][2] == legacy_genesis_forced_record_hash(
        forced_record_encodings[0])
    assert len(proposal_encodings[1]) == LEGACY_MAX_PROPOSAL_ROW_BYTES \
        == 3_808
    assert all(len(encoded) == LEGACY_MAX_PROPOSAL_ROW_BYTES
               for encoded in maximum_proposal_encodings)
    assert len(forced_record_encodings[0]) == LEGACY_MAX_FORCED_ROW_BYTES \
        == 256
    assert legacy_maximum_proposal_batch_raw_bytes == 60_928
    assert len(legacy_proposal_scan_sixteen_calldata) == 62_084
    assert legacy_full_scan_capacity_bytes == 4_161_536
    assert LEGACY_MAX_SCAN_BYTES - legacy_full_scan_capacity_bytes == 32_768
    assert legacy_maximum_scan_bytes == 8_384
    assert legacy_genesis_row_data_expiry(
        None, legacy_resume_profile.legacy_blob_retention_seconds) \
        == UINT64_MAX
    assert legacy_genesis_row_data_expiry(
        1_000, legacy_resume_profile.legacy_blob_retention_seconds) \
        == 1_573_864
    assert_rejects(
        lambda: legacy_genesis_row_data_expiry(
            0, legacy_resume_profile.legacy_blob_retention_seconds),
        "zero legacy blob timestamp accepted")
    assert_rejects(
        lambda: legacy_genesis_row_data_expiry(
            (1 << 48) - 1, UINT64_MAX),
        "overflowing legacy blob expiry accepted")
    legacy_review_args = (
        legacy_deployment_hash, legacy_resume_profile_hash, 2,
        release_hash, target_registration_hash)
    assert legacy_genesis_review_commitment(
        *legacy_review_args) == legacy_review_commitment
    for index, replacement_value in enumerate((
            bytes.fromhex("c1" * 32), bytes.fromhex("c2" * 32), 3,
            bytes.fromhex("c3" * 32), bytes.fromhex("c4" * 32))):
        changed_review_args = list(legacy_review_args)
        changed_review_args[index] = replacement_value
        assert legacy_genesis_review_commitment(
            *changed_review_args) != legacy_review_commitment
    for campaign_field in fields(legacy_campaign):
        if campaign_field.name in ("status", "campaign_id"):
            continue
        changed_campaign = replace(
            legacy_campaign,
            **{campaign_field.name: changed_field_value(
                getattr(legacy_campaign, campaign_field.name))})
        try:
            changed_campaign_id = legacy_genesis_campaign_id(
                legacy_deployment_hash, changed_campaign)
        except AssertionError:
            continue
        assert changed_campaign_id != legacy_campaign.campaign_id
        assert legacy_genesis_arm_id(
            legacy_deployment_hash, 1, changed_campaign_id,
            legacy_scan_commitment, legacy_boundary_hash) != legacy_arm_id
    assert decode_legacy_genesis_preparation_return(
        legacy_preparation_return) == (
            12, 9, 5, 8, 2, 3, legacy_maximum_scan_bytes,
            legacy_scan.legacy_resume_profile_hash)
    assert decode_legacy_genesis_control_calldata(
        legacy_begin_scan_calldata, LEGACY_GENESIS_BEGIN_SCAN_SELECTOR) \
        == (1, legacy_campaign.campaign_id)
    assert decode_begin_legacy_genesis_scan_return(
        legacy_begin_scan_return) == (10, 12, 5, 8)
    assert decode_scan_legacy_genesis_proposals_calldata(
        legacy_proposal_scan_one_calldata) == (
            1, legacy_campaign.campaign_id,
            (proposal_encodings[1],))
    validate_legacy_genesis_scan_batch_size(11, 12, 1)
    assert decode_scan_legacy_genesis_proposals_calldata(
        legacy_proposal_scan_sixteen_calldata)[2] \
        == maximum_proposal_encodings
    validate_legacy_genesis_scan_batch_size(100, 116, 16)
    assert_rejects(
        lambda: validate_legacy_genesis_scan_batch_size(10, 12, 1),
        "non-final short proposal scan batch accepted")
    assert_rejects(
        lambda: validate_legacy_genesis_scan_batch_size(10, 26, 15),
        "short full proposal scan batch accepted")
    assert_rejects(
        lambda: encode_scan_legacy_genesis_proposals_calldata(
            1, legacy_campaign.campaign_id,
            (proposal_encodings[0], proposal_encodings[0])),
        "non-consecutive proposal preimages accepted")
    assert decode_scan_legacy_genesis_proposals_return(
        legacy_proposal_scan_return) == (
            12, proposal_rows_root, proposal_bytes,
            legacy_min_data_expiry)
    assert decode_scan_legacy_genesis_forced_calldata(
        legacy_forced_scan_calldata) == (1, legacy_campaign.campaign_id, 3)
    validate_legacy_genesis_scan_batch_size(5, 8, 3)
    assert_rejects(
        lambda: validate_legacy_genesis_scan_batch_size(5, 8, 2),
        "short forced scan batch accepted")
    assert decode_scan_legacy_genesis_forced_return(
        legacy_forced_scan_return) == (
            8, forced_rows_root, forced_bytes,
            forced_abandoned_native_wei, legacy_min_data_expiry)
    assert decode_legacy_genesis_scan_state_return(
        legacy_scan_state_return) == (
            1, legacy_campaign.campaign_id, 10, 12, 12, 2,
            proposal_bytes, proposal_rows_root, 5, 8, 8, 3,
            forced_bytes, forced_rows_root, forced_abandoned_native_wei,
            legacy_min_data_expiry,
            legacy_scan.legacy_resume_profile_hash, 2)
    empty_scan_state = encode_legacy_genesis_scan_state_return(
        0, bytes(32), 0, 0, 0, 0, 0, bytes(32), 0, 0, 0, 0, 0,
        bytes(32), 0, 0, bytes(32), 0)
    assert decode_legacy_genesis_scan_state_return(empty_scan_state) == (
        0, bytes(32), 0, 0, 0, 0, 0, bytes(32), 0, 0, 0, 0, 0,
        bytes(32), 0, 0, bytes(32), 0)
    scanning_state = encode_legacy_genesis_scan_state_return(
        1, legacy_campaign.campaign_id, 10, 10, 12, 0, 0,
        legacy_genesis_rows_empty_root("proposal"), 5, 5, 8, 0, 0,
        legacy_genesis_rows_empty_root("forced"), 0, UINT64_MAX,
        legacy_resume_profile_hash, 1)
    assert decode_legacy_genesis_scan_state_return(scanning_state)[-1] == 1
    assert decode_legacy_genesis_control_calldata(
        legacy_quiescence_calldata,
        LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR) \
        == (1, legacy_campaign.campaign_id)
    assert decode_legacy_genesis_quiescence_return(
        legacy_quiescence_return) == (1, legacy_scan_commitment)
    assert decode_legacy_genesis_control_calldata(
        legacy_resume_calldata, LEGACY_GENESIS_RESUME_SELECTOR) \
        == (1, legacy_campaign.campaign_id)
    assert decode_legacy_genesis_resume_return(legacy_resume_return) \
        == (1, legacy_campaign.campaign_id)
    assert decode_legacy_genesis_control_calldata(
        legacy_expire_calldata, LEGACY_GENESIS_EXPIRE_SELECTOR) \
        == (1, legacy_campaign.campaign_id)
    assert decode_legacy_genesis_expire_return(legacy_expire_return) is None
    assert_all_fields_bound(legacy_scan, legacy_genesis_scan_commitment)
    assert_all_fields_bound(
        legacy_abandonment_receipt,
        legacy_genesis_abandonment_receipt_hash)
    validate_legacy_genesis_scan_resume_horizon(
        legacy_scan, legacy_campaign, 500, 1_000)
    assert_rejects(
        lambda: validate_legacy_genesis_scan_resume_horizon(
            replace(legacy_scan, min_data_expiry=8_499),
            legacy_campaign, 500, 1_000),
        "insufficient legacy genesis data-expiry horizon accepted")
    expired_scanned_row_root = append_legacy_genesis_row(
        "proposal", legacy_genesis_rows_empty_root("proposal"), 10,
        proposal_rows[0][1],
        proposal_rows[0][2], 6_999, 0)
    assert expired_scanned_row_root != legacy_genesis_rows_empty_root(
        "proposal")
    assert_rejects(
        lambda: validate_legacy_genesis_scan_resume_horizon(
            replace(
                legacy_scan, proposal_rows_root=expired_scanned_row_root,
                min_data_expiry=6_999),
            legacy_campaign, 500, 1_000),
        "already-expired scanned row accepted for resumable quiescence")
    for scan_field in fields(legacy_scan):
        changed_scan = replace(
            legacy_scan,
            **{scan_field.name: changed_field_value(
                getattr(legacy_scan, scan_field.name))})
        try:
            changed_scan_commitment = legacy_genesis_scan_commitment(
                changed_scan)
        except AssertionError:
            continue
        assert changed_scan_commitment != legacy_scan_commitment
        assert legacy_genesis_arm_id(
            legacy_deployment_hash, 1, legacy_campaign.campaign_id,
            changed_scan_commitment, legacy_boundary_hash) != legacy_arm_id
    assert migration_transition_statement_hash(replace(
        genesis_transition, legacy_arm_id=bytes.fromhex("ee" * 32))) \
        != genesis_transition_hash
    assert decode_legacy_genesis_control_calldata(
        legacy_arm_calldata, LEGACY_GENESIS_ARM_SELECTOR) \
        == (1, legacy_campaign.campaign_id)
    assert decode_legacy_genesis_control_return(
        legacy_arm_return, LEGACY_GENESIS_ARM_MAGIC) == (
            1, legacy_campaign.campaign_id, legacy_arm_id)
    assert decode_finalize_legacy_genesis_calldata(
        legacy_finalize_calldata) == (
            1, 2, release_hash, target_registration_hash,
            genesis_candidate_hash, canonical_core_v2_hash(genesis_output_core))
    assert decode_finalize_legacy_genesis_return(legacy_finalize_return) == (
        legacy_launch_id, legacy_post_state)
    assert decode_legacy_genesis_state_return(legacy_state_return) == (
        4, 1, legacy_campaign.campaign_id, legacy_scan_commitment, 2,
        release_hash, target_registration_hash, legacy_arm_id,
        legacy_launch_id, 12, 10, imported_header_hash, 5, 8,
        legacy_post_state)
    legacy_quiescent_state = decode_legacy_genesis_state_return(
        legacy_quiescent_state_return)
    legacy_ready_state = decode_legacy_genesis_state_return(
        legacy_ready_state_return)
    legacy_frozen_state = decode_legacy_genesis_state_return(
        legacy_state_return)
    validate_legacy_genesis_state_semantics(
        legacy_quiescent_state, legacy_deployment_hash)
    validate_legacy_genesis_state_semantics(
        legacy_ready_state, legacy_deployment_hash)
    validate_legacy_genesis_state_semantics(
        legacy_frozen_state, legacy_deployment_hash,
        genesis_candidate_hash, canonical_core_v2_hash(genesis_output_core),
        1_234)
    reorg_legacy_frozen_state = decode_legacy_genesis_state_return(
        encode_legacy_genesis_state_return(
            4, 1, legacy_campaign.campaign_id, legacy_scan_commitment, 2,
            release_hash, target_registration_hash, legacy_arm_id,
            legacy_launch_id, 12, 10, imported_header_hash, 5, 8,
            reorg_legacy_post_state))
    validate_legacy_genesis_state_semantics(
        reorg_legacy_frozen_state, legacy_deployment_hash,
        genesis_candidate_hash, canonical_core_v2_hash(genesis_output_core),
        reorg_activation_block)
    assert_rejects(
        lambda: encode_legacy_genesis_state_return(
            0, 1, bytes(32), bytes(32), 0, bytes(32), bytes(32),
            bytes(32), bytes(32), 12, 10, imported_header_hash, 5, 8,
            bytes(32)),
        "ACTIVE legacy state accepted a nonzero generation")
    for invalid_legacy_state in (
        (1,) + legacy_ready_state[1:],
        legacy_quiescent_state[:7] + (bytes.fromhex("ab" * 32),)
            + legacy_quiescent_state[8:],
        legacy_ready_state[:7] + (bytes.fromhex("ab" * 32),)
            + legacy_ready_state[8:],
        legacy_ready_state[:8] + (bytes.fromhex("ac" * 32),)
            + legacy_ready_state[9:],
    ):
        assert_rejects(
            lambda value=invalid_legacy_state:
                validate_legacy_genesis_state_semantics(
                    value, legacy_deployment_hash),
            "invalid legacy genesis phase commitment accepted")
    assert decode_migration_activation_context_return(
        genesis_activation_context_return) == (
            4, genesis_activation_context_hash_v1, 0x6100,
            target_settlement,
            1, 1, 2, release_hash, target_registration_hash)
    assert decode_adopt_migration_canonical_calldata(
        genesis_adopt_migration_calldata) == (
            1, 1, 1, 2, 0, release_hash, genesis_candidate_hash,
            genesis_output_core)
    assert decode_migration_canonical_return(
        genesis_adopt_migration_return) == (0, genesis_adoption_post_state)
    assert decode_queue_migration_calldata(
        genesis_queue_migration_calldata) == (
            genesis_activation_context_hash_v1, 0x6100, target_settlement,
            empty_queue_root, 0, 0, 0, 0xCAFE)
    assert decode_queue_migration_return(
        genesis_queue_migration_return) == (
            genesis_activation_context_hash_v1, 0, genesis_queue_post_state)
    assert decode_migration_post_state_return(
        genesis_source_post_state_return) == (
            1, genesis_activation_context_hash_v1, legacy_post_state)
    assert decode_migration_post_state_return(
        genesis_target_post_state_return) == (
            2, genesis_activation_context_hash_v1,
            genesis_adoption_post_state)
    assert decode_migration_post_state_return(
        genesis_queue_post_state_return) == (
            3, genesis_activation_context_hash_v1, genesis_queue_post_state)
    assert_all_fields_bound(genesis_activation_receipt, activation_receipt_id)
    assert decode_activation_receipt_calldata(
        genesis_activation_receipt_calldata) \
        == genesis_activation_receipt_hash
    assert decode_activation_receipt_return(
        genesis_activation_receipt_return) == (
            genesis_activation_receipt_hash, genesis_activation_receipt)
    assert decode_activation_receipt_return(activation_receipt_return) == (
        activation_receipt_hash, activation_receipt)
    assert genesis_activation_receipt.transition_auxiliary_hash \
        == legacy_abandonment_receipt_hash
    assert activation_receipt.transition_auxiliary_hash == bytes(32)
    malformed_blob_slice = encode_legacy_blob_slice(one_blob_slice)
    malformed_source = encode_legacy_derivation_source(
        proposal_10.sources[0])
    malformed_proposal = proposal_encodings[0]
    malformed_forced = forced_record_encodings[0]
    assert_rejects(
        lambda: encode_legacy_proposal(replace(
            proposal_10,
            sources=(proposal_10.sources[-1], *proposal_10.sources[1:]))),
        "normal derivation source before forced source accepted")
    assert_rejects(
        lambda: encode_legacy_proposal(replace(
            proposal_11,
            sources=proposal_11.sources[:-1]
                + (proposal_11.sources[0], proposal_11.sources[-1]))),
        "eleven forced derivation sources accepted")
    assert_rejects(
        lambda: encode_legacy_proposal(replace(
            proposal_11,
            sources=proposal_11.sources[:-1] + (
                replace(
                    proposal_11.sources[-1],
                    blob_slice=replace(
                        proposal_11.sources[-1].blob_slice,
                        blob_hashes=(
                            *proposal_11.sources[-1].blob_slice.blob_hashes,
                            bytes.fromhex("ef" * 32)))),))),
        "twenty-two normal blob hashes accepted")
    assert_rejects(
        lambda: encode_legacy_forced_inclusion(replace(
            forced_inclusions[0],
            blob_slice=replace(
                forced_inclusions[0].blob_slice,
                blob_hashes=(
                    *forced_inclusions[0].blob_slice.blob_hashes,
                    bytes.fromhex("ed" * 32))))),
        "multi-blob forced inclusion accepted")
    for malformed_legacy_index, (malformed_legacy_value, decoder) in enumerate((
        (legacy_resume_verifier_config_return[:4] + b"\x01"
         + legacy_resume_verifier_config_return[5:],
         decode_legacy_resume_verifier_config_return),
        (legacy_resume_verifier_config_return[:32] + u256(1 << 160)
         + legacy_resume_verifier_config_return[64:],
         decode_legacy_resume_verifier_config_return),
        (legacy_resume_verifier_config_return + bytes(32),
         decode_legacy_resume_verifier_config_return),
        (legacy_resume_risc0_config_return[:32] + u256(1 << 64)
         + legacy_resume_risc0_config_return[64:],
         decode_legacy_resume_risc0_config_return),
        (bytes4_word(LEGACY_RESUME_SP1_CONFIG_MAGIC)
         + legacy_resume_risc0_config_return[32:],
         decode_legacy_resume_risc0_config_return),
        (legacy_resume_sp1_config_return + b"\x00",
         decode_legacy_resume_sp1_config_return),
        (legacy_checkpoint_config_return[:-1],
         decode_legacy_checkpoint_config_return),
        (legacy_checkpoint_config_return[:64] + u256(1 << 160)
         + legacy_checkpoint_config_return[96:],
         decode_legacy_checkpoint_config_return),
        (bytes(32), decode_legacy_address_getter_return),
        (u256(1 << 160), decode_legacy_address_getter_return),
        (legacy_proposer_impl_return + bytes(32),
         decode_legacy_address_getter_return),
        (u256(0), decode_legacy_operator_count_return),
        (u256(65), decode_legacy_operator_count_return),
        (u256(1 << 16), decode_legacy_operator_count_return),
        (u256(2), decode_legacy_signal_service_version_return),
        (legacy_signal_version_return + bytes(32),
         decode_legacy_signal_service_version_return),
        (u256(2 * 32) + malformed_blob_slice[32:],
         decode_legacy_blob_slice),
        (malformed_blob_slice[:32] + u256(4 * 32)
         + malformed_blob_slice[64:], decode_legacy_blob_slice),
        (malformed_blob_slice[:64] + u256(1 << 24)
         + malformed_blob_slice[96:], decode_legacy_blob_slice),
        (malformed_blob_slice[:96] + u256(0)
         + malformed_blob_slice[128:], decode_legacy_blob_slice),
        (malformed_blob_slice[:128] + u256(0)
         + malformed_blob_slice[160:], decode_legacy_blob_slice),
        (malformed_blob_slice + bytes(32), decode_legacy_blob_slice),
        (u256(2 * 32) + malformed_source[32:],
         decode_legacy_derivation_source),
        (malformed_source[:32] + u256(2) + malformed_source[64:],
         decode_legacy_derivation_source),
        (malformed_source[:64] + u256(3 * 32)
         + malformed_source[96:], decode_legacy_derivation_source),
        (malformed_source + bytes(32), decode_legacy_derivation_source),
        (u256(2 * 32) + malformed_proposal[32:],
         decode_legacy_proposal),
        (malformed_proposal[:32] + u256(1 << 48)
         + malformed_proposal[64:], decode_legacy_proposal),
        (malformed_proposal[:128] + u256(1 << 160)
         + malformed_proposal[160:], decode_legacy_proposal),
        (malformed_proposal[:288] + u256(10 * 32)
         + malformed_proposal[320:], decode_legacy_proposal),
        (malformed_proposal[:352] + u256(4 * 32)
         + malformed_proposal[384:], decode_legacy_proposal),
        (malformed_proposal[:448] + u256(2)
         + malformed_proposal[480:], decode_legacy_proposal),
        (malformed_proposal[:480] + u256(3 * 32)
         + malformed_proposal[512:], decode_legacy_proposal),
        (malformed_proposal + bytes(32), decode_legacy_proposal),
        (u256(2 * 32) + malformed_forced[32:],
         decode_legacy_forced_inclusion),
        (malformed_forced[:32] + u256(1 << 64)
         + malformed_forced[64:], decode_legacy_forced_inclusion),
        (malformed_forced[:64] + u256(3 * 32)
         + malformed_forced[96:], decode_legacy_forced_inclusion),
        (malformed_forced[:160] + u256(0)
         + malformed_forced[192:], decode_legacy_forced_inclusion),
        (malformed_forced + bytes(32), decode_legacy_forced_inclusion),
        (genesis_activation_receipt_return[:3 * 32] + b"\x01"
         + genesis_activation_receipt_return[3 * 32 + 1:],
         decode_activation_receipt_return),
        (genesis_activation_receipt_return[:-32] + u256(0),
         decode_activation_receipt_return),
        (genesis_activation_receipt_return + b"\x00",
         decode_activation_receipt_return),
        (legacy_campaign_return[:10 * 32] + b"\x01"
         + legacy_campaign_return[10 * 32 + 1:],
         lambda value: decode_legacy_genesis_campaign_return(
             value, legacy_deployment_hash)),
        (legacy_campaign_return + b"\x00",
         lambda value: decode_legacy_genesis_campaign_return(
             value, legacy_deployment_hash)),
        (legacy_preparation_return[:5 * 32] + u256(1 << 16)
         + legacy_preparation_return[6 * 32:],
         decode_legacy_genesis_preparation_return),
        (legacy_begin_scan_calldata + b"\x00",
         lambda value: decode_legacy_genesis_control_calldata(
             value, LEGACY_GENESIS_BEGIN_SCAN_SELECTOR)),
        (legacy_begin_scan_return[:32] + u256(1 << 48)
         + legacy_begin_scan_return[64:],
         decode_begin_legacy_genesis_scan_return),
        (legacy_proposal_scan_one_calldata[:68] + u256(4 * 32)
         + legacy_proposal_scan_one_calldata[100:],
         decode_scan_legacy_genesis_proposals_calldata),
        (legacy_proposal_scan_one_calldata[:164]
         + u256(len(proposal_encodings[1]) - 1)
         + legacy_proposal_scan_one_calldata[196:-1] + b"\x01",
         decode_scan_legacy_genesis_proposals_calldata),
        (legacy_proposal_scan_sixteen_calldata + b"\x00",
         decode_scan_legacy_genesis_proposals_calldata),
        (legacy_proposal_scan_return[:32] + u256(1 << 48)
         + legacy_proposal_scan_return[64:],
         decode_scan_legacy_genesis_proposals_return),
        (legacy_forced_scan_calldata[:68] + u256(1 << 16)
         + legacy_forced_scan_calldata[100:],
         decode_scan_legacy_genesis_forced_calldata),
        (legacy_forced_scan_return[:-1],
         decode_scan_legacy_genesis_forced_return),
        (legacy_scan_state_return[:-32] + u256(3),
         decode_legacy_genesis_scan_state_return),
        (legacy_quiescence_return + b"\x00",
         decode_legacy_genesis_quiescence_return),
        (legacy_resume_return[:32] + u256(1 << 64)
         + legacy_resume_return[64:], decode_legacy_genesis_resume_return),
        (legacy_expire_return + b"\x00", decode_legacy_genesis_expire_return),
        (legacy_arm_calldata + b"\x00",
         lambda value: decode_legacy_genesis_control_calldata(
             value, LEGACY_GENESIS_ARM_SELECTOR)),
        (legacy_arm_return[:32] + u256(1 << 64)
         + legacy_arm_return[64:],
         lambda value: decode_legacy_genesis_control_return(
             value, LEGACY_GENESIS_ARM_MAGIC)),
        (legacy_finalize_calldata[:4] + u256(0)
         + legacy_finalize_calldata[36:],
         decode_finalize_legacy_genesis_calldata),
        (legacy_finalize_return + b"\x00",
         decode_finalize_legacy_genesis_return),
        (legacy_state_return[:32] + u256(5) + legacy_state_return[64:],
         decode_legacy_genesis_state_return),
        (legacy_state_return[:-1], decode_legacy_genesis_state_return),
    )):
        assert_rejects(
            lambda value=malformed_legacy_value, fn=decoder: fn(value),
            f"malformed legacy genesis ABI accepted: {malformed_legacy_index}")
    assert decode_adopt_migration_canonical_calldata(
        adopt_migration_calldata) == (
            2, 2, 2, 3, 2, successor_release_hash, candidate_hash,
            activation_output_core)
    assert decode_migration_canonical_return(adopt_migration_return) \
        == (3, adoption_post_state)
    assert decode_freeze_migration_source_calldata(
        freeze_migration_calldata) == activation_context_hash
    assert decode_migration_freeze_return(freeze_migration_return) \
        == (activation_context_hash, source_post_state)
    assert decode_queue_migration_calldata(queue_migration_calldata) == (
        activation_context_hash, target_settlement, successor_settlement,
        force.root, len(envs), 2, 66,
        0xCAFE)
    assert decode_queue_migration_return(queue_migration_return) == (
        activation_context_hash, credited_wei, queue_post_state)
    assert decode_migration_activation_context_return(
        activation_context_return) == (
            4, activation_context_hash, target_settlement,
            successor_settlement, 2, 2, 3,
            successor_release_hash, successor_registration_hash)
    assert decode_migration_activation_context_return(
        arming_lifecycle_return) == (
            1, bytes(32), 0, 0, 0, 0, 0, bytes(32), bytes(32))
    assert decode_migration_post_state_calldata(
        migration_post_state_calldata) == activation_context_hash
    assert decode_migration_post_state_return(source_post_state_return) == (
        1, activation_context_hash, source_post_state)
    assert decode_migration_post_state_return(target_post_state_return) == (
        2, activation_context_hash, adoption_post_state)
    assert decode_migration_post_state_return(queue_post_state_return) == (
        3, activation_context_hash, queue_post_state)
    for malformed_activation_value, decoder in (
        (adopt_migration_calldata + b"\x00",
         decode_adopt_migration_canonical_calldata),
        (adopt_migration_calldata[:4] + u256(3)
         + adopt_migration_calldata[36:],
         decode_adopt_migration_canonical_calldata),
        (adopt_migration_return[:32] + u256(1 << 64)
         + adopt_migration_return[64:], decode_migration_canonical_return),
        (freeze_migration_return + b"\x00", decode_migration_freeze_return),
        (queue_migration_calldata[:36] + u256(1 << 160)
         + queue_migration_calldata[68:], decode_queue_migration_calldata),
        (queue_migration_return + b"\x00", decode_queue_migration_return),
        (activation_context_return[:32] + u256(5)
         + activation_context_return[64:],
         decode_migration_activation_context_return),
        (source_post_state_return[:32] + u256(4)
         + source_post_state_return[64:],
         decode_migration_post_state_return),
        (source_post_state_return[:-1], decode_migration_post_state_return),
    ):
        assert_rejects(
            lambda value=malformed_activation_value, fn=decoder: fn(value),
            "malformed activation callback ABI accepted")
    context_arguments = (
        settlement_chain_id, 0xAD01, 2, 2, 2, 3, release_hash,
        successor_release_hash, successor_registration_hash,
        target_settlement, successor_settlement,
        2, base, version_transition_hash, candidate_hash,
        activation_output_core, 0xF000, force.root, len(envs), 2, 66,
        0xCAFE, activation_block)
    for index, replacement_value in (
        (8, bytes.fromhex("aa" * 32)),
        (9, 0x6203), (10, 0x6203), (12, bytes.fromhex("ab" * 32)),
        (13, bytes.fromhex("ac" * 32)), (19, 3), (20, 65),
        (21, 0xCAFF), (22, activation_block + 1),
    ):
        changed = list(context_arguments)
        changed[index] = replacement_value
        assert migration_activation_context_hash(*changed) \
            != activation_context_hash
    assert_rejects(
        lambda: migration_target_sequence(2, UINT64_MAX),
        "overflow migration target sequence accepted")
    genesis_arguments = genesis_activation_calldata[4:]
    rows_offset = int.from_bytes(genesis_arguments[79 * 32:80 * 32], "big")
    header_offset = int.from_bytes(genesis_arguments[80 * 32:81 * 32], "big")
    proof_offset = int.from_bytes(genesis_arguments[81 * 32:82 * 32], "big")
    assert rows_offset == 0x0A40
    assert (header_offset
            == rows_offset + len(canonical_inbox_rows_tail(empty_inbox_rows))
            and proof_offset == header_offset
                + len(abi_bytes_tail(imported_header_rlp)))
    malformed_activation_calls = (
        genesis_activation_calldata + bytes(32),
        genesis_activation_calldata[:4 + 79 * 32] + u256(rows_offset + 32)
        + genesis_activation_calldata[4 + 80 * 32:],
        genesis_activation_calldata[:4 + 80 * 32] + u256(rows_offset)
        + genesis_activation_calldata[4 + 81 * 32:],
        genesis_activation_calldata[:4 + 80 * 32] + u256(header_offset + 32)
        + genesis_activation_calldata[4 + 81 * 32:],
        genesis_activation_calldata[:4 + 81 * 32] + u256(proof_offset + 32)
        + genesis_activation_calldata[4 + 82 * 32:],
        genesis_activation_calldata[:4 + rows_offset + 32] + u256(96)
        + genesis_activation_calldata[4 + rows_offset + 64:],
        genesis_activation_calldata[:4 + proof_offset - 1] + b"\x01"
        + genesis_activation_calldata[4 + proof_offset:],
        genesis_activation_calldata[:4 + proof_offset]
        + u256(MAX_MIGRATION_PROOF_BYTES + 1)
        + genesis_activation_calldata[4 + proof_offset + 32:],
    )
    for malformed_activation in malformed_activation_calls:
        assert_rejects(
            lambda value=malformed_activation:
                decode_activate_version_with_migration_calldata(
                    value, genesis_activation_fixed, release_manifest,
                    migration_verifier.maximum_proof_bytes),
            "malformed activation calldata accepted")
    for bad_header in (
            b"", b"\xb8\x01\x00", b"\xc1\x80\x00",
            maximum_genesis_header_rlp + b"\x00"):
        assert_rejects(
            lambda header=bad_header:
                encode_activate_version_with_migration_calldata(
                    genesis_activation_fixed, release_manifest,
                    empty_inbox_rows,
                    header, migration_proof,
                    migration_verifier.maximum_proof_bytes),
            "invalid genesis header accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            version_activation_fixed, successor_release_manifest, inbox_rows,
            imported_header_rlp, migration_proof,
            migration_verifier.maximum_proof_bytes),
        "version migration header accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, empty_inbox_rows,
            imported_header_rlp, b"",
            migration_verifier.maximum_proof_bytes),
        "empty migration proof accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, empty_inbox_rows,
            imported_header_rlp,
            bytes(MAX_MIGRATION_PROOF_BYTES + 1),
            MAX_MIGRATION_PROOF_BYTES),
        "oversize migration proof accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            version_activation_fixed, successor_release_manifest,
            tuple(InboxRowV2(index, 0, UINT32_MAX, bytes(32), b"")
                  for index in range(2, 67)),
            b"", migration_proof,
            migration_verifier.maximum_proof_bytes),
        "oversize activation row vector accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            version_activation_fixed, successor_release_manifest,
            (replace(maximum_version_rows[-1], kind1_descriptor=bytes(220)),),
            b"", migration_proof,
            migration_verifier.maximum_proof_bytes),
        "wrong activation descriptor length accepted")
    for proof_bound in (MAX_MIGRATION_PROOF_BYTES - 1,
                        MAX_MIGRATION_PROOF_BYTES):
        bounded = replace(migration_verifier, maximum_proof_bytes=proof_bound,
                          configuration_hash=bytes(32))
        bounded = replace(
            bounded,
            configuration_hash=_migration_verifier_configuration_hash(bounded))
        assert migration_verifier_configuration_hash(bounded) \
            == bounded.configuration_hash
        assert migration_verifier_descriptor_hash(bounded) != bytes(32)
    assert_rejects(
        lambda: _migration_verifier_configuration_hash(
            replace(migration_verifier,
                    maximum_proof_bytes=MAX_MIGRATION_PROOF_BYTES + 1)),
        "oversize migration verifier proof bound accepted")
    assert_rejects(
        lambda: migration_verifier_descriptor_hash(
            replace(migration_verifier,
                    maximum_proof_bytes=MAX_MIGRATION_PROOF_BYTES + 1)),
        "oversize migration verifier descriptor accepted")
    maximum_inbox_calldata = encode_inbox_apply_calldata(
        0, tuple(InboxRowV2(index, 5, UINT32_MAX,
                            bytes.fromhex("99" * 32),
                            durable_bridge_descriptor)
                 for index in range(64)))
    assert len(maximum_inbox_calldata) == 49_252
    for malformed_inbox_calldata in (
        inbox_apply_calldata + bytes(32),
        inbox_apply_calldata[:36] + u256(96) + inbox_apply_calldata[68:],
        inbox_apply_calldata[:100] + u256(96)
        + inbox_apply_calldata[132:],
        inbox_apply_calldata[:196] + u256(1 << 8)
        + inbox_apply_calldata[228:],
        inbox_apply_calldata[:-1] + b"\x01",
    ):
        assert_rejects(
            lambda value=malformed_inbox_calldata:
                decode_inbox_apply_calldata(value),
            "malformed InboxApply calldata accepted")
    assert decode_mark_inbox_batch_calldata(inbox_batch_calldata) \
        == (inbox_credit,)
    assert decode_inbox_batch_magic_return(inbox_batch_magic_return()) \
        == INBOX_BATCH_MAGIC
    assert_rejects(
        lambda: decode_inbox_batch_magic_return(
            inbox_batch_magic_return() + bytes(32)),
        "trailing Inbox Store magic accepted")
    assert decode_liquidity_quote_return(liquidity_quote_return) \
        == (inbox_credit.result_hash, inbox_credit.value, inbox_credit.execution_fee,
            inbox_credit.liquidity_fee, bridge.enqueue_by)
    assert decode_liquidity_funding_state_return(funding_state_return) \
        == (destination_domain, 0xB200, 0x5101, 1, 0)
    assert decode_verify_inbox_credit_return(verify_inbox_return) \
        == (bridge_credit, bridge.enqueue_by, bridge.value, bridge.fee,
            bridge.liquidity_fee, source_context_hash(source_context))
    assert (len(route_config_getter_calldata) == 4
            and len(verify_inbox_calldata) == 196
            and len(inbox_slot_calldata) == 132
            and len(liquidity_quote_calldata) == 36
            and len(funding_state_calldata) == 36)
    for malformed_view in (
        liquidity_quote_return[:-1], liquidity_quote_return + bytes(32),
        funding_state_return[:96] + u256(5)
        + funding_state_return[128:],
        funding_state_return[:128] + u256(1),
    ):
        decoder = (decode_liquidity_quote_return
                   if len(malformed_view) != len(funding_state_return)
                   else decode_liquidity_funding_state_return)
        assert_rejects(lambda value=malformed_view, fn=decoder: fn(value),
                       "malformed permanent view accepted")
    assert decode_process_with_liquidity_calldata(pool_process_calldata) \
        == (ticket_hash, 0xB200, normalized_message, source_context,
            destination_context)
    assert decode_retry_with_liquidity_calldata(pool_retry_calldata) \
        == (ticket_hash, 0xB200, normalized_message, source_context,
            destination_context, True)
    assert len(pool_process_calldata) == 964 + ceil32(
        len(normalized_message.data))
    assert len(pool_retry_calldata) == 996 + ceil32(
        len(normalized_message.data))
    for malformed_pool_call, decoder in (
        (pool_process_calldata[:68] + u256(17 * 32)
         + pool_process_calldata[100:],
         decode_process_with_liquidity_calldata),
        (pool_retry_calldata[:580] + u256(2)
         + pool_retry_calldata[612:],
         decode_retry_with_liquidity_calldata),
        (pool_process_calldata + bytes(32),
         decode_process_with_liquidity_calldata),
        (pool_retry_calldata[:-1], decode_retry_with_liquidity_calldata),
    ):
        assert_rejects(
            lambda value=malformed_pool_call, fn=decoder: fn(value),
            "malformed Pool attempt calldata accepted")
    assert decode_pool_bridge_attempt_calldata(pool_bridge_attempt_calldata) \
        == (ticket_hash, 0x8888, normalized_message, source_context,
            destination_context, 2, False, pool_authorization)
    assert len(pool_bridge_attempt_calldata) == 1060 + ceil32(
        len(normalized_message.data))
    for malformed_bridge_pool_call in (
        pool_bridge_attempt_calldata[:580] + u256(3)
        + pool_bridge_attempt_calldata[612:],
        pool_bridge_attempt_calldata[:612] + u256(2)
        + pool_bridge_attempt_calldata[644:],
        pool_bridge_attempt_calldata[:-1],
        pool_bridge_attempt_calldata + bytes(32),
    ):
        assert_rejects(
            lambda value=malformed_bridge_pool_call:
                decode_pool_bridge_attempt_calldata(value),
            "malformed Bridge Pool-attempt calldata accepted")
    assert decode_execute_attempt_calldata(execute_attempt_calldata) \
        == (normalized_message, source_context, destination_context,
            0x8888, 1, False, ticket_hash, pool_authorization)
    assert len(execute_attempt_calldata) == 1060 + ceil32(
        len(normalized_message.data))
    assert decode_status_return(status_return) == (1, 7)
    assert decode_target_call_failed_error(target_error, attempt_digest) \
        == attempt_digest
    assert_rejects(lambda: decode_status_return(status_return + bytes(32)),
                   "long Bridge status return accepted")
    assert_rejects(
        lambda: decode_target_call_failed_error(target_error[:-1], attempt_digest),
                   "short target error accepted")
    assert_rejects(
        lambda: decode_target_call_failed_error(
            target_error, bytes.fromhex("98" * 32)),
        "mismatched target error digest accepted")
    assert decode_terminal_commitment_return(terminal_commitment_return) \
        == (destination_domain, 0xB200, 1, UINT64_MAX,
            liquidity_settlement_hash(bytes.fromhex("45" * 32), 0x7777,
                                      bridge.value + bridge.fee))
    assert decode_terminal_state_return(terminal_state_return) \
        == (2, bytes.fromhex("97" * 32))
    assert decode_terminal_append_return(terminal_append_return) == 2
    assert (len(finalize_failed_calldata) == 36
            and len(append_terminal_calldata) == 36
            and len(terminal_commitment_calldata) == 36
            and len(terminal_state_calldata) == 4)
    ticket_arguments = (l2_chain_id, 0x5104, 0x8888, 0x9999, ticket_salt)
    for index, replacement_value in enumerate((
            l2_chain_id + 1, 0x5105, 0x8889, 0x999A,
            bytes.fromhex("47" * 32))):
        changed = list(ticket_arguments)
        changed[index] = replacement_value
        assert liquidity_ticket_id(*changed) != ticket_hash
    for index in (1, 2, 3):
        changed = list(ticket_arguments)
        changed[index] = 0
        assert_rejects(lambda args=tuple(changed): liquidity_ticket_id(*args),
                       "zero liquidity ticket identity accepted")
    assert decode_pool_word_calldata(
        pool_deposit_calldata, DEPOSIT_LIQUIDITY_V2_SELECTOR,
        (address_word_value, b32)) == (0x9999, ticket_salt)
    assert decode_pool_word_calldata(
        pool_withdraw_calldata, WITHDRAW_LIQUIDITY_V2_SELECTOR,
        (b32, address_word_value, uint_word_value)) \
        == (ticket_hash, 0x8888, 5)
    assert len(pool_ticket_calldata) == 36
    assert decode_pool_word_calldata(
        pool_ticket_calldata, TICKET_ACCOUNTING_V2_SELECTOR, (b32,)) \
        == (ticket_hash,)
    assert len(pool_consume_calldata) == 164
    assert decode_pool_word_calldata(
        pool_consume_calldata, CONSUME_AUTHORIZED_LIQUIDITY_V2_SELECTOR,
        (b32, b32, address_word_value, uint_word_value, b32)) == (
            ticket_hash, bridge_credit, 0x8888, pool_amount,
            inbox_credit.result_hash)
    assert decode_pool_word_calldata(
        pool_callback_calldata, ACCEPT_LIQUIDITY_VALUE_V2_SELECTOR,
        (b32, b32, uint_word_value)) \
        == (bridge_credit, ticket_hash, pool_amount)
    assert pool_accounting_calldata == POOL_ACCOUNTING_V2_SELECTOR
    assert decode_pool_deposit_return(pool_deposit_return) \
        == (ticket_hash, 7 + pool_amount)
    assert decode_pool_withdraw_return(pool_withdraw_return) == 2
    assert decode_pool_ticket_accounting_return(pool_ticket_return) \
        == (0x8888, 0x9999, 7 + pool_amount)
    assert decode_pool_ticket_accounting_return(bytes(96)) == (0, 0, 0)
    assert decode_pool_accounting_return(pool_accounting_return) == (
        infrastructure_components[8].config_hash, True, False, bytes(32),
        7 + pool_amount, pool_balance, 5)
    assert decode_pool_consume_return(pool_consume_return) \
        == (ticket_hash, 0x9999, pool_amount)
    assert decode_pool_value_magic_return(pool_callback_return) == POOL_VALUE_MAGIC
    assert decode_pool_bridge_result_return(pool_bridge_result_return) == (
        bridge_credit, 2, 1, 3, pool_settlement_hash)
    pool_authorization_arguments = (
        l2_chain_id, destination_domain, 0x5104, 0xB200, 0x5101,
        bridge_credit, ticket_hash, 0x8888, inbox_credit.result_hash,
        pool_amount, source_context_hash(source_context),
        destination_context_hash(destination_context), 2, False,
    )
    for index, replacement_value in enumerate((
            l2_chain_id + 1, bytes.fromhex("98" * 32), 0x5105, 0xB201,
            0x5102, bytes.fromhex("97" * 32), bytes.fromhex("96" * 32),
            0x8889, bytes.fromhex("95" * 32), pool_amount + 1,
            bytes.fromhex("94" * 32), bytes.fromhex("93" * 32), 1, True)):
        changed = list(pool_authorization_arguments)
        changed[index] = replacement_value
        assert liquidity_attempt_authorization(*changed) != pool_authorization
    pool_acceptance_arguments = (
        l2_chain_id, destination_domain, 0xB200, 0x5104,
        bridge_credit, ticket_hash, 0x8888, inbox_credit.result_hash,
        pool_amount, attempt_digest,
    )
    for index, replacement_value in enumerate((
            l2_chain_id + 1, bytes.fromhex("98" * 32), 0xB201, 0x5105,
            bytes.fromhex("97" * 32), bytes.fromhex("96" * 32), 0x8889,
            bytes.fromhex("95" * 32), pool_amount + 1,
            bytes.fromhex("94" * 32))):
        changed = list(pool_acceptance_arguments)
        changed[index] = replacement_value
        assert liquidity_acceptance_commitment(*changed) != pool_acceptance
    assert_rejects(
        lambda: liquidity_acceptance_commitment(
            *pool_acceptance_arguments[:8], 0,
            pool_acceptance_arguments[9]),
        "zero Pool acceptance amount accepted")
    assert_rejects(
        lambda: decode_pool_word_calldata(
            pool_consume_calldata + bytes(32),
            CONSUME_AUTHORIZED_LIQUIDITY_V2_SELECTOR,
            (b32, b32, address_word_value, uint_word_value, b32)),
        "trailing Pool calldata accepted")
    assert_rejects(
        lambda: decode_pool_word_calldata(
            DEPOSIT_LIQUIDITY_V2_SELECTOR + u256(1 << 160) + ticket_salt,
            DEPOSIT_LIQUIDITY_V2_SELECTOR, (address_word_value, b32)),
        "noncanonical Pool address accepted")
    for malformed, decoder in (
            (bytes(32) + pool_deposit_return[32:], decode_pool_deposit_return),
            (pool_ticket_return[:64] + u256(0),
             decode_pool_ticket_accounting_return),
            (pool_accounting_return[:64] + u256(2)
             + pool_accounting_return[96:], decode_pool_accounting_return),
            (pool_accounting_return[:192] + u256(1)
             + pool_accounting_return[224:], decode_pool_accounting_return),
            (pool_bridge_result_return[:64] + u256(4)
             + pool_bridge_result_return[96:],
             decode_pool_bridge_result_return),
            (pool_callback_return + bytes(32), decode_pool_value_magic_return)):
        assert_rejects(lambda value=malformed, fn=decoder: fn(value),
                       "malformed Pool ABI accepted")
    assert decode_invocation_policy_return(invocation_return) \
        == (invocation_hash, True)
    assert len(invocation_policy_calldata) == 68
    assert invocation_policy_hash(denied_targets) != invocation_policy_hash(
        (*denied_targets[:-1], denied_targets[-1] + 1))
    assert_rejects(lambda: invocation_policy_hash(tuple(reversed(denied_targets))),
                   "unsorted invocation denyset accepted")
    assert_rejects(lambda: invocation_policy_hash((0, 0)),
                   "duplicate invocation denyset accepted")
    assert_rejects(
        lambda: decode_invocation_policy_return(
            invocation_return[:32] + u256(2) + invocation_return[64:]),
        "noncanonical invocation Boolean accepted")
    assert_rejects(
        lambda: migration_verifier_descriptor_hash(
            replace(migration_verifier,
                    configuration_hash=bytes.fromhex("99" * 32))),
        "mismatched migration verifier config hash accepted")
    assert_rejects(
        lambda: registration_mpt_verifier_descriptor_hash(
            replace(registration_mpt_verifier,
                    configuration_hash=bytes.fromhex("99" * 32))),
        "mismatched registration verifier config hash accepted")
    assert_all_fields_bound(destination_receipt,
                            destination_activation_receipt_id)
    # Keep this assertion beside the vector: 64 consumed plus one boundary.
    assert verify_force_range(len(envs), 2, force_leaves[2:67], proof, force.root)
    return {
        "typehash": keccak256(TYPE_STRING.encode()).hex(),
        "domain_separator": eip712_domain(settlement_chain_id, contract).hex(),
        "block_struct_hash": block_struct_hash(block_values).hex(),
        "eip712_digest": eip712_digest(settlement_chain_id, contract, block_values).hex(),
        "canonical_core": core.hex(),
        "base_canonical": base.hex(),
        "migration_data": migration_data(settlement_chain_id, l2_chain_id,
                                           bytes.fromhex("77" * 32),
                                           bytes.fromhex("66" * 32),
                                           empty_terminal.root, 0).hex(),
        "candidate_commitment": candidate_hash.hex(),
        "candidate_commitment_2": candidate_hash_2.hex(),
        "normal_context": context.hex(),
        "winning_data": winning.hex(),
        "forced_descriptors": forced_descriptors.hex(),
        "schedule_list": schedules_hash.hex(),
        "session_list": sessions_hash.hex(),
        "execution_outputs": outputs_hash.hex(),
        "statement_hash": statement_hash(statement_values).hex(),
        "registry_root": reg_root.hex(),
        "admission_root": adm_root.hex(),
        "admission_reuse_root": adm_reuse_root.hex(),
        "entry_root": ent_root.hex(),
        "tranche_leaf": tranche.hex(),
        "forced_leaf": force_leaves[0].hex(),
        "bridge_leaf": bridge_hash.hex(),
        "bridge_result": bridge_credit_result(70, bridge).hex(),
        "bridge_credit_id": bridge_credit.hex(),
        "liquidity_fee_substitution_bridge_leaf":
            changed_liquidity_fee_leaf.hex(),
        "liquidity_fee_substitution_credit_id":
            changed_liquidity_fee_credit.hex(),
        "bridge_escrow_id": bridge_escrow_id(bridge_credit).hex(),
        "inbox_credit_slot": inbox_credit_slot(
            bridge.source_domain_id, bridge.src_bridge,
            bridge.destination_domain_id, bridge_credit).hex(),
        "terminal_done_leaf": done_leaf.hex(),
        "liquidity_settlement_hash": settlement_hash.hex(),
        "settlement_tuple_substitution_terminal_leaf":
            changed_settlement_leaf.hex(),
        "terminal_failed_leaf": failed_leaf.hex(),
        "terminal_root_2": terminal_vector.root.hex(),
        "empty_terminal_root": empty_terminal.root.hex(),
        "source_domain_id": source_domain.hex(),
        "destination_domain_id": destination_domain.hex(),
        "bridge_kernel_profile_hash": bridge_kernel.hex(),
        "source_bridge_descriptor_length":
            str(len(canonical_source_descriptor)),
        "derived_source_bridge_address":
            address20(source_bridge_address).hex(),
        "derived_source_bundle_deployer_address":
            address20(source_bridge_descriptor.bundle_deployer).hex(),
        "derived_source_registry_address":
            address20(source_bridge_descriptor.credit_registry).hex(),
        "derived_source_quota_address":
            address20(source_bridge_descriptor.quota_manager).hex(),
        "component_config_getter_selector":
            COMPONENT_CONFIG_GETTER_SELECTOR.hex(),
        "component_config_getter_gas_limit":
            str(COMPONENT_CONFIG_GETTER_GAS_LIMIT),
        "source_factory_config_getter_return":
            source_bridge_descriptor.factory_configuration_hash.hex(),
        "source_bridge_config_getter_return":
            source_bridge_descriptor.bridge_config_hash.hex(),
        "source_registry_config_getter_return":
            source_bridge_descriptor.registry_config_hash.hex(),
        "source_quota_config_getter_return":
            source_bridge_descriptor.quota_config_hash.hex(),
        "source_support_registry_config_getter_return":
            source_bridge_descriptor.support_registry_configuration_hash.hex(),
        "source_terminal_verifier_config_getter_return":
            source_bridge_descriptor.terminal_verifier_config_hash.hex(),
        "bridge_execution_hash": bridge_execution.hex(),
        "destination_bridge_execution_hash": destination_bridge_execution.hex(),
        "destination_infrastructure_hash": infrastructure.hex(),
        "pool_row_substitution_infrastructure_hash":
            destination_infrastructure_hash(changed_pool_components).hex(),
        "migration_verifier_config_typehash":
            MIGRATION_VERIFIER_CONFIG_TYPEHASH.hex(),
        "migration_verifier_configuration_hash":
            migration_verifier_config.hex(),
        "migration_verifier_descriptor_typehash":
            MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH.hex(),
        "migration_verifier_descriptor_hash":
            migration_verifier_descriptor.hex(),
        "migration_verifier_config_getter_selector":
            MIGRATION_VERIFIER_CONFIG_GETTER_SELECTOR.hex(),
        "migration_transition_statement_typehash":
            MIGRATION_TRANSITION_STATEMENT_TYPEHASH.hex(),
        "deployment_commitment_typehash":
            DEPLOYMENT_COMMITMENT_TYPEHASH.hex(),
        "manifest_components_hash": components_commitment.hex(),
        "genesis_deployment_commitment": genesis_deployment_hash.hex(),
        "version_deployment_commitment": version_deployment_hash.hex(),
        "legacy_signal_checkpoint_hash": checkpoint_hash.hex(),
        "genesis_migration_statement_hash": genesis_transition_hash.hex(),
        "version_migration_statement_hash": version_transition_hash.hex(),
        "genesis_base_core_hash": canonical_core_v2_hash(
            genesis_base_core).hex(),
        "genesis_base_canonical_hash": genesis_base.hex(),
        "genesis_candidate_commitment": genesis_candidate_hash.hex(),
        "genesis_output_core_hash": canonical_core_v2_hash(
            genesis_output_core).hex(),
        "registration_storage_statement_typehash":
            REGISTRATION_STORAGE_STATEMENT_TYPEHASH.hex(),
        "registration_route_key_typehash":
            REGISTRATION_ROUTE_KEY_TYPEHASH.hex(),
        "registration_route_key": registration_statement.route_key.hex(),
        "verify_registration_selector": VERIFY_REGISTRATION_SELECTOR.hex(),
        "registration_storage_statement_hash":
            registration_statement_hash.hex(),
        "registration_mpt_proof_schema_hash":
            REGISTRATION_MPT_PROOF_SCHEMA_HASH.hex(),
        "registration_mpt_verifier_config_typehash":
            REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH.hex(),
        "registration_mpt_verifier_configuration_hash":
            registration_mpt_configuration_hash.hex(),
        "registration_mpt_verifier_descriptor_typehash":
            REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPEHASH.hex(),
        "registration_mpt_verifier_descriptor_hash":
            registration_mpt_descriptor_hash.hex(),
        "registration_mpt_verifier_config_getter_selector":
            REGISTRATION_MPT_VERIFIER_CONFIG_GETTER_SELECTOR.hex(),
        "verify_registration_calldata_hash":
            keccak256(registration_verification_calldata).hex(),
        "verify_registration_calldata_length":
            str(len(registration_verification_calldata)),
        "registration_verifier_return": registration_verifier_return.hex(),
        "registration_config_getter_return":
            registration_config_getter_return.hex(),
        "source_context_typehash": SOURCE_CONTEXT_TYPEHASH.hex(),
        "source_context_hash": source_context_hash(source_context).hex(),
        "destination_context_typehash": DESTINATION_CONTEXT_TYPEHASH.hex(),
        "destination_context_hash":
            destination_context_hash(destination_context).hex(),
        "ingress_authorization_typehash":
            INGRESS_AUTHORIZATION_TYPEHASH.hex(),
        "kind0_ingress_authorization_id":
            ingress_authorization_id(kind0_ingress).hex(),
        "kind1_ingress_authorization_id":
            ingress_authorization_id(kind1_ingress).hex(),
        "ingress_authorization_root_typehash":
            INGRESS_AUTHORIZATION_ROOT_TYPEHASH.hex(),
        "ingress_authorization_root": ingress_root.hex(),
        "send_message_v2_selector": SEND_MESSAGE_V2_SELECTOR.hex(),
        "enqueue_bridge_credit_v2_selector":
            ENQUEUE_BRIDGE_CREDIT_V2_SELECTOR.hex(),
        "credit_authorization_v2_selector":
            CREDIT_AUTHORIZATION_V2_SELECTOR.hex(),
        "credit_authorization_v2_calldata_hash":
            keccak256(credit_authorization_calldata).hex(),
        "credit_authorization_v2_return_hash":
            keccak256(credit_authorization_return).hex(),
        "credit_authorization_v2_return_length":
            str(len(credit_authorization_return)),
        "credit_liability_v2_selector": CREDIT_LIABILITY_V2_SELECTOR.hex(),
        "credit_liability_v2_calldata_hash":
            keccak256(credit_liability_calldata).hex(),
        "credit_liability_v2_return_hash":
            keccak256(credit_liability_return).hex(),
        "credit_liability_v2_return_length":
            str(len(credit_liability_return)),
        "source_credit_read_gas_limit": str(SOURCE_CREDIT_READ_GAS_LIMIT),
        "message_v1_tuple_hash":
            keccak256(canonical_message_v1(normalized_message)).hex(),
        "message_v1_data_hash": keccak256(normalized_message.data).hex(),
        "send_message_v2_calldata_hash": keccak256(send_calldata).hex(),
        "send_message_v2_calldata_length": str(len(send_calldata)),
        "enqueue_bridge_credit_v2_calldata_hash":
            keccak256(enqueue_calldata).hex(),
        "normalized_message_hash_preimage_length":
            str(len(normalized_preimage)),
        "normalized_message_hash": normalized_hash.hex(),
        "normalized_message_return_hash":
            keccak256(normalized_return).hex(),
        "enqueue_forced_transaction_selector":
            ENQUEUE_FORCED_TRANSACTION_SELECTOR.hex(),
        "enqueue_forced_transaction_calldata_hash":
            keccak256(enqueue_forced_calldata).hex(),
        "enqueue_forced_transaction_calldata_length":
            str(len(enqueue_forced_calldata)),
        "sync_ingress_selector": SYNC_INGRESS_SELECTOR.hex(),
        "sync_ingress_stamp_return_hash":
            keccak256(sync_stamp_return).hex(),
        "sync_ingress_synced_return_hash":
            keccak256(sync_synced_return).hex(),
        "append_from_adapter_selector": APPEND_FROM_ADAPTER_SELECTOR.hex(),
        "append_kind0_calldata_hash": keccak256(append_kind0_calldata).hex(),
        "append_kind0_calldata_length": str(len(append_kind0_calldata)),
        "append_kind1_calldata_hash": keccak256(append_kind1_calldata).hex(),
        "append_kind1_calldata_length": str(len(append_kind1_calldata)),
        "queued_return_hash": keccak256(queued_return).hex(),
        "v11_bridge_descriptor": durable_bridge_descriptor.hex(),
        "inbox_apply_selector": INBOX_APPLY_SELECTOR.hex(),
        "inbox_apply_calldata_hash": keccak256(inbox_apply_calldata).hex(),
        "inbox_apply_calldata_length": str(len(inbox_apply_calldata)),
        "inbox_apply_maximum_calldata_hash":
            keccak256(maximum_inbox_calldata).hex(),
        "mark_inbox_batch_selector": MARK_INBOX_BATCH_SELECTOR.hex(),
        "mark_inbox_batch_calldata_hash":
            keccak256(inbox_batch_calldata).hex(),
        "inbox_batch_magic": INBOX_BATCH_MAGIC.hex(),
        "route_config_getter_selector": ROUTE_CONFIG_GETTER_SELECTOR.hex(),
        "verify_inbox_credit_calldata_hash":
            keccak256(verify_inbox_calldata).hex(),
        "verify_inbox_credit_selector": VERIFY_INBOX_CREDIT_SELECTOR.hex(),
        "get_inbox_credit_slot_selector":
            GET_INBOX_CREDIT_SLOT_SELECTOR.hex(),
        "get_inbox_credit_slot_calldata_hash":
            keccak256(inbox_slot_calldata).hex(),
        "liquidity_quote_selector": LIQUIDITY_QUOTE_SELECTOR.hex(),
        "liquidity_quote_calldata_hash":
            keccak256(liquidity_quote_calldata).hex(),
        "liquidity_quote_return_hash":
            keccak256(liquidity_quote_return).hex(),
        "liquidity_funding_state_selector":
            LIQUIDITY_FUNDING_STATE_SELECTOR.hex(),
        "liquidity_funding_state_calldata_hash":
            keccak256(funding_state_calldata).hex(),
        "liquidity_funding_state_return_hash":
            keccak256(funding_state_return).hex(),
        "execute_attempt_selector": EXECUTE_ATTEMPT_SELECTOR.hex(),
        "execute_attempt_calldata_hash":
            keccak256(execute_attempt_calldata).hex(),
        "execute_attempt_calldata_length": str(len(execute_attempt_calldata)),
        "finalize_failed_attempt_selector":
            FINALIZE_FAILED_ATTEMPT_SELECTOR.hex(),
        "finalize_failed_attempt_calldata_hash":
            keccak256(finalize_failed_calldata).hex(),
        "status_return_hash": keccak256(status_return).hex(),
        "target_call_failed_selector": TARGET_CALL_FAILED_SELECTOR.hex(),
        "target_call_failed_error_hash": keccak256(target_error).hex(),
        "append_terminal_selector": APPEND_TERMINAL_SELECTOR.hex(),
        "append_terminal_calldata_hash":
            keccak256(append_terminal_calldata).hex(),
        "terminal_commitment_selector": TERMINAL_COMMITMENT_SELECTOR.hex(),
        "terminal_commitment_calldata_hash":
            keccak256(terminal_commitment_calldata).hex(),
        "terminal_state_selector": TERMINAL_STATE_SELECTOR.hex(),
        "terminal_append_return": terminal_append_return.hex(),
        "terminal_commitment_return_hash":
            keccak256(terminal_commitment_return).hex(),
        "terminal_state_return_hash": keccak256(terminal_state_return).hex(),
        "liquidity_ticket_id": ticket_hash.hex(),
        "pool_component_configuration_hash":
            infrastructure_components[8].config_hash.hex(),
        "pool_external_read_gas": str(POOL_EXTERNAL_READ_GAS),
        "pool_auth_cleanup_gas": str(POOL_AUTH_CLEANUP_GAS),
        "pool_value_callback_gas": str(POOL_VALUE_CALLBACK_GAS),
        "pool_deposit_selector": DEPOSIT_LIQUIDITY_V2_SELECTOR.hex(),
        "pool_withdraw_selector": WITHDRAW_LIQUIDITY_V2_SELECTOR.hex(),
        "pool_process_selector": PROCESS_WITH_LIQUIDITY_V2_SELECTOR.hex(),
        "pool_retry_selector": RETRY_WITH_LIQUIDITY_V2_SELECTOR.hex(),
        "pool_process_calldata_hash":
            keccak256(pool_process_calldata).hex(),
        "pool_process_calldata_length": str(len(pool_process_calldata)),
        "pool_retry_calldata_hash": keccak256(pool_retry_calldata).hex(),
        "pool_retry_calldata_length": str(len(pool_retry_calldata)),
        "pool_bridge_attempt_selector": POOL_BRIDGE_ATTEMPT_SELECTOR.hex(),
        "pool_bridge_attempt_calldata_hash":
            keccak256(pool_bridge_attempt_calldata).hex(),
        "pool_bridge_attempt_calldata_length":
            str(len(pool_bridge_attempt_calldata)),
        "pool_ticket_selector": TICKET_ACCOUNTING_V2_SELECTOR.hex(),
        "pool_accounting_selector": POOL_ACCOUNTING_V2_SELECTOR.hex(),
        "pool_consume_selector":
            CONSUME_AUTHORIZED_LIQUIDITY_V2_SELECTOR.hex(),
        "pool_value_callback_selector":
            ACCEPT_LIQUIDITY_VALUE_V2_SELECTOR.hex(),
        "pool_accounting_magic": POOL_ACCOUNTING_MAGIC.hex(),
        "pool_value_magic": POOL_VALUE_MAGIC.hex(),
        "pool_bridge_result_magic": POOL_BRIDGE_RESULT_MAGIC.hex(),
        "pool_attempt_authorization": pool_authorization.hex(),
        "pool_value_acceptance_commitment": pool_acceptance.hex(),
        "pool_deposit_calldata_hash": keccak256(pool_deposit_calldata).hex(),
        "pool_withdraw_calldata_hash": keccak256(pool_withdraw_calldata).hex(),
        "pool_ticket_calldata_hash": keccak256(pool_ticket_calldata).hex(),
        "pool_accounting_calldata_hash":
            keccak256(pool_accounting_calldata).hex(),
        "pool_consume_calldata_hash": keccak256(pool_consume_calldata).hex(),
        "pool_value_callback_calldata_hash":
            keccak256(pool_callback_calldata).hex(),
        "pool_deposit_return_hash": keccak256(pool_deposit_return).hex(),
        "pool_withdraw_return_hash": keccak256(pool_withdraw_return).hex(),
        "pool_ticket_return_hash": keccak256(pool_ticket_return).hex(),
        "pool_accounting_return_hash":
            keccak256(pool_accounting_return).hex(),
        "pool_consume_return_hash": keccak256(pool_consume_return).hex(),
        "pool_value_callback_return_hash":
            keccak256(pool_callback_return).hex(),
        "pool_bridge_result_return_hash":
            keccak256(pool_bridge_result_return).hex(),
        "liquidity_deposited_topic": LIQUIDITY_DEPOSITED_V2_TOPIC.hex(),
        "liquidity_consumed_topic": LIQUIDITY_CONSUMED_V2_TOPIC.hex(),
        "liquidity_withdrawn_topic": LIQUIDITY_WITHDRAWN_V2_TOPIC.hex(),
        "invocation_policy_typehash": INVOCATION_POLICY_TYPEHASH.hex(),
        "invocation_policy_hash": invocation_hash.hex(),
        "invocation_policy_getter_selector":
            INVOCATION_POLICY_GETTER_SELECTOR.hex(),
        "invocation_policy_calldata_hash":
            keccak256(invocation_policy_calldata).hex(),
        "message_invocation_hook_selector":
            MESSAGE_INVOCATION_HOOK_SELECTOR.hex(),
        "invocation_policy_return_hash": keccak256(invocation_return).hex(),
        "invocation_policy_magic": INVOCATION_POLICY_MAGIC.hex(),
        "destination_activation_receipt_id": destination_receipt_hash.hex(),
        "destination_activation_receipt_magic":
            DESTINATION_ACTIVATION_RECEIPT_MAGIC.hex(),
        "destination_successor_receipt_magic":
            DESTINATION_SUCCESSOR_RECEIPT_MAGIC.hex(),
        "activation_receipt_id": activation_receipt_hash.hex(),
        "activation_receipt_magic": ACTIVATION_RECEIPT_MAGIC.hex(),
        "activation_successor_receipt_magic":
            ACTIVATION_SUCCESSOR_RECEIPT_MAGIC.hex(),
        "execution_profile_hash": profile_hash.hex(),
        "execution_profile_abi_length": str(len(profile_bytes)),
        "execution_profile_static_words": str(EXECUTION_PROFILE_STATIC_WORDS),
        "execution_profile_creation_offset":
            str(EXECUTION_PROFILE_STATIC_BYTES),
        "settlement_factory_deploy_selector":
            SETTLEMENT_FACTORY_DEPLOY_SELECTOR.hex(),
        "settlement_factory_configuration_hash":
            settlement_factory_configuration_hash_v2().hex(),
        "market_authority_configuration_hash":
            decode_execution_profile_v2(profile_bytes)[37].hex(),
        "target_constructor_state_selector":
            TARGET_CONSTRUCTOR_STATE_SELECTOR.hex(),
        "target_constructor_state_return_hash":
            keccak256(target_constructor_state_return).hex(),
        "empty_data_session_accounting_return_hash":
            keccak256(empty_data_session_accounting_return).hex(),
        "live_registration_validation_commitment":
            live_registration_validation_commitment.hex(),
        "register_release_profile_bytes_hash": keccak256(profile_bytes).hex(),
        "settlement_deployment_descriptor_hash":
            target_deployment_descriptor_hash.hex(),
        "settlement_deployment_descriptor_abi_hash": keccak256(
            encode_settlement_deployment_descriptor_abi(
                target_deployment_descriptor)).hex(),
        "settlement_deployment_descriptor_abi_length": "256",
        "successor_settlement_deployment_descriptor_hash":
            successor_deployment_descriptor_hash.hex(),
        "target_registration_hash":
            target_registration_hash.hex(),
        "successor_target_registration_hash":
            successor_registration_hash.hex(),
        "migration_activation_profile_record_hash":
            migration_activation_profile.activation_profile_record_hash.hex(),
        "successor_migration_activation_profile_record_hash":
            successor_migration_activation_profile
                .activation_profile_record_hash.hex(),
        "migration_activation_profile_selector":
            MIGRATION_ACTIVATION_PROFILE_SELECTOR.hex(),
        "migration_activation_profile_magic":
            MIGRATION_ACTIVATION_PROFILE_MAGIC.hex(),
        "migration_activation_profile_calldata_hash": keccak256(
            migration_activation_profile_calldata).hex(),
        "migration_activation_profile_return_hash": keccak256(
            migration_activation_profile_return).hex(),
        "migration_activation_profile_return_length":
            str(len(migration_activation_profile_return)),
        "protocol_change_operation_domain_hash":
            protocol_change_operation_domain_hash().hex(),
        "governance_delay_authority_descriptor_hash":
            timelock_descriptor_hash.hex(),
        "protocol_version_manager_configuration_hash":
            manager_descriptor.protocol_version_manager_configuration_hash.hex(),
        "protocol_version_manager_descriptor_hash":
            manager_descriptor_hash.hex(),
        "protocol_change_delay_seconds": str(PROTOCOL_CHANGE_DELAY_SECONDS),
        "maximum_live_version_migration_seconds":
            str(MAXIMUM_LIVE_VERSION_MIGRATION_SECONDS),
        "protocol_authority_read_gas": str(PROTOCOL_AUTHORITY_READ_GAS),
        "queue_protocol_change_selector": QUEUE_PROTOCOL_CHANGE_SELECTOR.hex(),
        "execute_protocol_change_selector":
            EXECUTE_PROTOCOL_CHANGE_SELECTOR.hex(),
        "cancel_protocol_change_selector":
            CANCEL_PROTOCOL_CHANGE_SELECTOR.hex(),
        "apply_protocol_change_selector": APPLY_PROTOCOL_CHANGE_SELECTOR.hex(),
        "protocol_change_timelock_config_selector":
            PROTOCOL_CHANGE_TIMELOCK_CONFIG_SELECTOR.hex(),
        "protocol_version_manager_config_selector":
            PROTOCOL_VERSION_MANAGER_CONFIG_SELECTOR.hex(),
        "protocol_change_operation_selector":
            PROTOCOL_CHANGE_OPERATION_SELECTOR.hex(),
        "protocol_change_timelock_config_magic":
            PROTOCOL_CHANGE_TIMELOCK_CONFIG_MAGIC.hex(),
        "protocol_version_manager_config_magic":
            PROTOCOL_VERSION_MANAGER_CONFIG_MAGIC.hex(),
        "protocol_change_operation_magic":
            PROTOCOL_CHANGE_OPERATION_MAGIC.hex(),
        "protocol_apply_magic": PROTOCOL_APPLY_MAGIC.hex(),
        "register_release_payload_hash":
            keccak256(register_release_payload_abi).hex(),
        "register_release_payload_length":
            str(len(register_release_payload_abi)),
        "register_fork_verifier_payload_hash":
            keccak256(register_fork_payload_abi).hex(),
        "register_fork_verifier_payload_length":
            str(len(register_fork_payload_abi)),
        "publish_genesis_campaign_payload_hash":
            keccak256(publish_genesis_payload_abi).hex(),
        "publish_genesis_campaign_payload_length":
            str(len(publish_genesis_payload_abi)),
        "publish_migration_arm_payload_hash":
            keccak256(publish_migration_payload_abi).hex(),
        "publish_migration_arm_payload_length":
            str(len(publish_migration_payload_abi)),
        "register_release_operation_id": protocol_change_operation_ids[0].hex(),
        "register_fork_verifier_operation_id":
            protocol_change_operation_ids[1].hex(),
        "publish_genesis_campaign_operation_id":
            protocol_change_operation_ids[2].hex(),
        "publish_migration_arm_operation_id":
            protocol_change_operation_ids[3].hex(),
        "queue_protocol_change_calldata_hash":
            keccak256(queue_protocol_change_calldata).hex(),
        "queue_protocol_change_calldata_length":
            str(len(queue_protocol_change_calldata)),
        "execute_protocol_change_calldata_hash":
            keccak256(execute_protocol_change_calldata).hex(),
        "execute_protocol_change_calldata_length":
            str(len(execute_protocol_change_calldata)),
        "cancel_protocol_change_calldata_hash":
            keccak256(cancel_protocol_change_calldata).hex(),
        "cancel_protocol_change_calldata_length":
            str(len(cancel_protocol_change_calldata)),
        "apply_protocol_change_calldata_hash":
            keccak256(apply_protocol_change_calldata).hex(),
        "apply_protocol_change_calldata_length":
            str(len(apply_protocol_change_calldata)),
        "protocol_change_timelock_config_return_hash": keccak256(
            protocol_change_timelock_config_return).hex(),
        "protocol_version_manager_config_return_hash": keccak256(
            protocol_version_manager_config_return).hex(),
        "protocol_change_operation_calldata_hash": keccak256(
            protocol_change_operation_calldata).hex(),
        "protocol_change_operation_return_hash": keccak256(
            queued_migration_operation_return).hex(),
        "protocol_apply_return_hash": keccak256(
            encode_protocol_apply_return()).hex(),
        "live_version_migration_lease_selector":
            LIVE_VERSION_MIGRATION_LEASE_SELECTOR.hex(),
        "permissionless_abort_expired_migration_selector":
            PERMISSIONLESS_ABORT_EXPIRED_MIGRATION_SELECTOR.hex(),
        "version_migration_lease_magic": VERSION_MIGRATION_LEASE_MAGIC.hex(),
        "version_migration_arm_id": version_migration_lease.arm_id.hex(),
        "version_migration_abort_after_timestamp":
            str(version_migration_lease.abort_after_timestamp),
        "version_migration_lease_return_hash": keccak256(
            version_migration_lease_return).hex(),
        "version_migration_lease_return_length":
            str(len(version_migration_lease_return)),
        "register_target_release_selector":
            REGISTER_TARGET_RELEASE_SELECTOR.hex(),
        "target_release_registration_selector":
            TARGET_RELEASE_REGISTRATION_SELECTOR.hex(),
        "target_release_registration_magic":
            TARGET_RELEASE_REGISTRATION_MAGIC.hex(),
        "register_target_release_calldata_hash": keccak256(
            register_target_release_calldata).hex(),
        "register_target_release_calldata_length":
            str(len(register_target_release_calldata)),
        "register_target_release_return_hash": keccak256(
            register_target_release_return).hex(),
        "target_release_registration_calldata_hash": keccak256(
            target_release_registration_calldata).hex(),
        "target_release_registration_return_hash": keccak256(
            target_release_registration_return).hex(),
        "target_release_registration_return_length":
            str(len(target_release_registration_return)),
        "profile_ingress_root_selector": PROFILE_INGRESS_ROOT_SELECTOR.hex(),
        "profile_ingress_authorization_selector":
            PROFILE_INGRESS_AUTHORIZATION_SELECTOR.hex(),
        "profile_ingress_root_magic": PROFILE_INGRESS_ROOT_MAGIC.hex(),
        "profile_ingress_authorization_magic":
            PROFILE_INGRESS_AUTHORIZATION_MAGIC.hex(),
        "profile_ingress_root_return_hash":
            keccak256(profile_ingress_root_return).hex(),
        "profile_ingress_authorization_zero_return_hash": keccak256(
            profile_ingress_authorization_returns[0]).hex(),
        "profile_ingress_authorization_one_return_hash": keccak256(
            profile_ingress_authorization_returns[1]).hex(),
        "install_settlement_authorization_selector":
            INSTALL_SETTLEMENT_AUTHORIZATION_SELECTOR.hex(),
        "settlement_authorization_selector":
            SETTLEMENT_AUTHORIZATION_SELECTOR.hex(),
        "settlement_authorization_install_magic":
            SETTLEMENT_AUTHORIZATION_INSTALL_MAGIC.hex(),
        "settlement_authorization_getter_magic":
            SETTLEMENT_AUTHORIZATION_GETTER_MAGIC.hex(),
        "settlement_authorization_id": settlement_authorization_hash.hex(),
        "install_settlement_authorization_calldata_hash": keccak256(
            install_settlement_authorization_calldata).hex(),
        "install_settlement_authorization_return_hash": keccak256(
            install_settlement_authorization_return).hex(),
        "settlement_authorization_return_hash": keccak256(
            settlement_authorization_return).hex(),
        "seat_target_state_selector": SEAT_TARGET_STATE_SELECTOR.hex(),
        "seat_market_term_selector": SEAT_MARKET_TERM_SELECTOR.hex(),
        "seat_market_duty_selector": SEAT_MARKET_DUTY_SELECTOR.hex(),
        "seat_authority_read_gas": str(SEAT_AUTHORITY_READ_GAS),
        "schedule_fork_constants_hash": schedule_fork_constants_hash(
            register_fork_payload.beacon_slot_gindex,
            register_fork_payload.execution_payload_gindex,
            register_fork_payload.state_root_gindex,
            register_fork_payload.prev_randao_gindex,
            register_fork_payload.timestamp_gindex,
            register_fork_payload.block_hash_gindex).hex(),
        "schedule_fork_output_schema_hash":
            schedule_fork_output_schema_hash().hex(),
        "schedule_fork_verifier_configuration_hash":
            register_fork_payload.configuration_hash.hex(),
        "install_fork_verifier_selector": INSTALL_FORK_VERIFIER_SELECTOR.hex(),
        "fork_verifier_registration_selector":
            FORK_VERIFIER_REGISTRATION_SELECTOR.hex(),
        "schedule_fork_verifier_config_selector":
            SCHEDULE_FORK_VERIFIER_CONFIG_SELECTOR.hex(),
        "verify_schedule_carrier_selector":
            VERIFY_SCHEDULE_CARRIER_SELECTOR.hex(),
        "fork_verifier_install_magic": FORK_VERIFIER_INSTALL_MAGIC.hex(),
        "fork_verifier_registration_magic":
            FORK_VERIFIER_REGISTRATION_MAGIC.hex(),
        "schedule_fork_verifier_config_magic":
            SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC.hex(),
        "schedule_fork_carrier_magic": SCHEDULE_FORK_CARRIER_MAGIC.hex(),
        "install_fork_verifier_calldata_hash": keccak256(
            install_fork_verifier_calldata).hex(),
        "fork_verifier_registration_return_hash": keccak256(
            fork_verifier_registration_return).hex(),
        "schedule_fork_verifier_config_return_hash": keccak256(
            schedule_fork_verifier_config_return).hex(),
        "verify_schedule_carrier_calldata_hash": keccak256(
            verify_schedule_carrier_calldata).hex(),
        "verify_schedule_carrier_calldata_length":
            str(len(verify_schedule_carrier_calldata)),
        "schedule_carrier_statement_hash": schedule_statement_hash.hex(),
        "schedule_carrier_return_hash":
            keccak256(schedule_carrier_return).hex(),
        "publish_legacy_genesis_campaign_selector":
            PUBLISH_LEGACY_GENESIS_CAMPAIGN_SELECTOR.hex(),
        "arm_version_migration_selector": ARM_VERSION_MIGRATION_SELECTOR.hex(),
        "abort_expired_version_migration_selector":
            ABORT_EXPIRED_VERSION_MIGRATION_SELECTOR.hex(),
        "legacy_genesis_publish_magic": LEGACY_GENESIS_PUBLISH_MAGIC.hex(),
        "version_migration_arm_magic": VERSION_MIGRATION_ARM_MAGIC.hex(),
        "version_migration_abort_magic": VERSION_MIGRATION_ABORT_MAGIC.hex(),
        "publish_legacy_genesis_campaign_calldata_hash": keccak256(
            publish_legacy_genesis_campaign_calldata).hex(),
        "publish_legacy_genesis_campaign_return_hash": keccak256(
            publish_legacy_genesis_campaign_return).hex(),
        "arm_version_migration_calldata_hash": keccak256(
            arm_version_migration_calldata).hex(),
        "arm_version_migration_return_hash": keccak256(
            arm_version_migration_return).hex(),
        "abort_expired_version_migration_calldata_hash": keccak256(
            abort_expired_version_migration_calldata).hex(),
        "abort_expired_version_migration_return_hash": keccak256(
            abort_expired_version_migration_return).hex(),
        "pvm_router_mutation_gas": str(PVM_ROUTER_MUTATION_GAS),
        "legacy_inbox_config_selector": LEGACY_INBOX_CONFIG_SELECTOR.hex(),
        "legacy_inbox_configuration_hash": legacy_inbox_config_hash.hex(),
        "legacy_inbox_config_return_hash":
            keccak256(legacy_inbox_config_return).hex(),
        "legacy_inbox_config_return_length":
            str(len(legacy_inbox_config_return)),
        "legacy_genesis_deployment_hash": legacy_deployment_hash.hex(),
        "legacy_genesis_campaign_fence_descriptor_hash":
            legacy_campaign_fence_descriptor_hash.hex(),
        "legacy_descriptor_call_gas": str(LEGACY_DESCRIPTOR_CALL_GAS),
        "legacy_genesis_resume_time_policy_hash":
            legacy_genesis_resume_time_policy_hash().hex(),
        "legacy_genesis_risc0_resume_key_policy_hash":
            legacy_risc0_resume_key_policy_hash.hex(),
        "legacy_genesis_sp1_resume_key_policy_hash":
            legacy_sp1_resume_key_policy_hash.hex(),
        "legacy_genesis_risc0_reth_verifier_descriptor_hash":
            legacy_risc0_reth_verifier_descriptor_hash.hex(),
        "legacy_genesis_sp1_reth_verifier_descriptor_hash":
            legacy_sp1_reth_verifier_descriptor_hash.hex(),
        "legacy_genesis_proof_verifier_graph_hash":
            legacy_proof_verifier_graph_hash.hex(),
        "legacy_genesis_resume_verifier_route_hash":
            legacy_resume_verifier_route_hash.hex(),
        "legacy_genesis_proposer_checker_descriptor_hash":
            legacy_proposer_checker_descriptor_hash.hex(),
        "legacy_genesis_prover_whitelist_descriptor_hash":
            legacy_prover_whitelist_descriptor_hash.hex(),
        "legacy_genesis_checkpoint_record_hash":
            keccak256(D_LEGACY_GENESIS_CHECKPOINT_RECORD_LITERAL).hex(),
        "legacy_genesis_checkpoint_storage_layout_hash":
            legacy_checkpoint_storage_layout_hash.hex(),
        "legacy_genesis_signal_service_checkpoint_descriptor_hash":
            legacy_signal_service_checkpoint_descriptor_hash.hex(),
        "legacy_resume_verifier_config_selector":
            LEGACY_RESUME_VERIFIER_CONFIG_SELECTOR.hex(),
        "legacy_resume_verifier_config_magic":
            LEGACY_RESUME_VERIFIER_CONFIG_MAGIC.hex(),
        "legacy_resume_verifier_config_return_hash":
            keccak256(legacy_resume_verifier_config_return).hex(),
        "legacy_resume_verifier_config_return_length":
            str(len(legacy_resume_verifier_config_return)),
        "legacy_resume_risc0_config_selector":
            LEGACY_RESUME_RISC0_CONFIG_SELECTOR.hex(),
        "legacy_resume_risc0_config_magic":
            LEGACY_RESUME_RISC0_CONFIG_MAGIC.hex(),
        "legacy_resume_risc0_config_return_hash":
            keccak256(legacy_resume_risc0_config_return).hex(),
        "legacy_resume_risc0_config_return_length":
            str(len(legacy_resume_risc0_config_return)),
        "legacy_resume_sp1_config_selector":
            LEGACY_RESUME_SP1_CONFIG_SELECTOR.hex(),
        "legacy_resume_sp1_config_magic":
            LEGACY_RESUME_SP1_CONFIG_MAGIC.hex(),
        "legacy_resume_sp1_config_return_hash":
            keccak256(legacy_resume_sp1_config_return).hex(),
        "legacy_resume_sp1_config_return_length":
            str(len(legacy_resume_sp1_config_return)),
        "legacy_checkpoint_config_selector":
            LEGACY_CHECKPOINT_CONFIG_SELECTOR.hex(),
        "legacy_checkpoint_config_magic": LEGACY_CHECKPOINT_CONFIG_MAGIC.hex(),
        "legacy_checkpoint_config_return_hash":
            keccak256(legacy_checkpoint_config_return).hex(),
        "legacy_checkpoint_config_return_length":
            str(len(legacy_checkpoint_config_return)),
        "legacy_descriptor_impl_selector":
            LEGACY_DESCRIPTOR_IMPL_SELECTOR.hex(),
        "legacy_operator_count_selector": LEGACY_OPERATOR_COUNT_SELECTOR.hex(),
        "legacy_current_operator_selector":
            LEGACY_CURRENT_OPERATOR_SELECTOR.hex(),
        "legacy_next_operator_selector": LEGACY_NEXT_OPERATOR_SELECTOR.hex(),
        "legacy_signal_service_version_selector":
            LEGACY_SIGNAL_SERVICE_VERSION_SELECTOR.hex(),
        "legacy_proposer_impl_return_hash":
            keccak256(legacy_proposer_impl_return).hex(),
        "legacy_signal_impl_return_hash":
            keccak256(legacy_signal_impl_return).hex(),
        "legacy_operator_count_return_hash":
            keccak256(legacy_operator_count_return).hex(),
        "legacy_current_operator_return_hash":
            keccak256(legacy_current_operator_return).hex(),
        "legacy_next_operator_return_hash":
            keccak256(legacy_next_operator_return).hex(),
        "legacy_signal_service_version_return_hash":
            keccak256(legacy_signal_version_return).hex(),
        "legacy_genesis_resume_profile_hash":
            legacy_resume_profile_hash.hex(),
        "legacy_blob_slice_one_hash":
            keccak256(encode_legacy_blob_slice(one_blob_slice)).hex(),
        "legacy_blob_slice_one_length":
            str(len(encode_legacy_blob_slice(one_blob_slice))),
        "legacy_blob_slice_maximum_hash":
            keccak256(encode_legacy_blob_slice(maximum_blob_slice)).hex(),
        "legacy_blob_slice_maximum_length":
            str(len(encode_legacy_blob_slice(maximum_blob_slice))),
        "legacy_derivation_source_mixed_hash":
            keccak256(encode_legacy_derivation_source(mixed_source)).hex(),
        "legacy_derivation_source_mixed_length":
            str(len(encode_legacy_derivation_source(mixed_source))),
        "legacy_proposal_mixed_encoding_hash":
            keccak256(proposal_encodings[0]).hex(),
        "legacy_proposal_mixed_encoding_length":
            str(len(proposal_encodings[0])),
        "legacy_proposal_maximum_encoding_hash":
            keccak256(proposal_encodings[1]).hex(),
        "legacy_proposal_maximum_encoding_length":
            str(len(proposal_encodings[1])),
        "legacy_forced_inclusion_encoding_hash":
            keccak256(forced_record_encodings[0]).hex(),
        "legacy_forced_inclusion_encoding_length":
            str(len(forced_record_encodings[0])),
        "legacy_profile_maximum_forced_inclusions_per_proposal":
            str(LEGACY_MAX_FORCED_INCLUSIONS_PER_PROPOSAL),
        "legacy_profile_maximum_normal_blob_hashes_per_proposal":
            str(LEGACY_MAX_NORMAL_BLOB_HASHES_PER_PROPOSAL),
        "legacy_resume_proof_generation_max_seconds":
            str(legacy_resume_profile.
                legacy_resume_proof_generation_max_seconds),
        "legacy_maximum_proposal_row_bytes":
            str(LEGACY_MAX_PROPOSAL_ROW_BYTES),
        "legacy_maximum_forced_row_bytes":
            str(LEGACY_MAX_FORCED_ROW_BYTES),
        "legacy_maximum_scan_bytes_bound": str(LEGACY_MAX_SCAN_BYTES),
        "legacy_maximum_sixteen_proposal_raw_bytes":
            str(legacy_maximum_proposal_batch_raw_bytes),
        "legacy_maximum_sixteen_proposal_scan_calldata_length":
            str(len(legacy_proposal_scan_sixteen_calldata)),
        "legacy_full_scan_capacity_bytes":
            str(legacy_full_scan_capacity_bytes),
        "legacy_full_scan_capacity_headroom_bytes":
            str(LEGACY_MAX_SCAN_BYTES - legacy_full_scan_capacity_bytes),
        "legacy_genesis_review_commitment": legacy_review_commitment.hex(),
        "legacy_genesis_blob_data_expiry": str(
            legacy_genesis_row_data_expiry(
                1_000,
                legacy_resume_profile.legacy_blob_retention_seconds)),
        "legacy_genesis_campaign_selector":
            LEGACY_GENESIS_CAMPAIGN_SELECTOR.hex(),
        "legacy_genesis_campaign_magic":
            LEGACY_GENESIS_CAMPAIGN_MAGIC.hex(),
        "legacy_genesis_campaign_id": legacy_campaign.campaign_id.hex(),
        "legacy_genesis_campaign_return_hash":
            keccak256(legacy_campaign_return).hex(),
        "legacy_genesis_campaign_return_length":
            str(len(legacy_campaign_return)),
        "legacy_genesis_preparation_selector":
            LEGACY_GENESIS_PREPARATION_SELECTOR.hex(),
        "legacy_genesis_preparation_return_hash":
            keccak256(legacy_preparation_return).hex(),
        "legacy_genesis_preparation_return_length":
            str(len(legacy_preparation_return)),
        "legacy_genesis_proposal_rows_empty_root":
            legacy_genesis_rows_empty_root("proposal").hex(),
        "legacy_genesis_proposal_rows_root": proposal_rows_root.hex(),
        "legacy_genesis_forced_rows_empty_root":
            legacy_genesis_rows_empty_root("forced").hex(),
        "legacy_genesis_forced_record_hash":
            legacy_genesis_forced_record_hash(
                forced_record_encodings[0]).hex(),
        "legacy_genesis_forced_rows_root": forced_rows_root.hex(),
        "legacy_genesis_scan_commitment": legacy_scan_commitment.hex(),
        "legacy_genesis_abandonment_receipt_hash":
            legacy_abandonment_receipt_hash.hex(),
        "legacy_genesis_abandonment_sealed_topic":
            LEGACY_GENESIS_ABANDONMENT_SEALED_TOPIC.hex(),
        "legacy_genesis_begin_scan_selector":
            LEGACY_GENESIS_BEGIN_SCAN_SELECTOR.hex(),
        "legacy_genesis_begin_scan_calldata_hash":
            keccak256(legacy_begin_scan_calldata).hex(),
        "legacy_genesis_begin_scan_return_hash":
            keccak256(legacy_begin_scan_return).hex(),
        "legacy_genesis_scan_proposals_selector":
            LEGACY_GENESIS_SCAN_PROPOSALS_SELECTOR.hex(),
        "legacy_genesis_scan_proposals_one_calldata_hash":
            keccak256(legacy_proposal_scan_one_calldata).hex(),
        "legacy_genesis_scan_proposals_one_calldata_length":
            str(len(legacy_proposal_scan_one_calldata)),
        "legacy_genesis_scan_proposals_sixteen_calldata_hash":
            keccak256(legacy_proposal_scan_sixteen_calldata).hex(),
        "legacy_genesis_scan_proposals_sixteen_calldata_length":
            str(len(legacy_proposal_scan_sixteen_calldata)),
        "legacy_genesis_scan_proposals_return_hash":
            keccak256(legacy_proposal_scan_return).hex(),
        "legacy_genesis_scan_forced_selector":
            LEGACY_GENESIS_SCAN_FORCED_SELECTOR.hex(),
        "legacy_genesis_scan_forced_calldata_hash":
            keccak256(legacy_forced_scan_calldata).hex(),
        "legacy_genesis_scan_forced_return_hash":
            keccak256(legacy_forced_scan_return).hex(),
        "legacy_genesis_scan_state_selector":
            LEGACY_GENESIS_SCAN_STATE_SELECTOR.hex(),
        "legacy_genesis_scan_state_return_hash":
            keccak256(legacy_scan_state_return).hex(),
        "legacy_genesis_scan_state_return_length":
            str(len(legacy_scan_state_return)),
        "legacy_genesis_quiescence_selector":
            LEGACY_GENESIS_ENTER_QUIESCENCE_SELECTOR.hex(),
        "legacy_genesis_quiescence_calldata_hash":
            keccak256(legacy_quiescence_calldata).hex(),
        "legacy_genesis_quiescence_return_hash":
            keccak256(legacy_quiescence_return).hex(),
        "legacy_genesis_resume_selector": LEGACY_GENESIS_RESUME_SELECTOR.hex(),
        "legacy_genesis_resume_calldata_hash":
            keccak256(legacy_resume_calldata).hex(),
        "legacy_genesis_resume_return_hash":
            keccak256(legacy_resume_return).hex(),
        "legacy_genesis_expire_selector": LEGACY_GENESIS_EXPIRE_SELECTOR.hex(),
        "legacy_genesis_expire_calldata_hash":
            keccak256(legacy_expire_calldata).hex(),
        "legacy_genesis_expire_return_hash":
            keccak256(legacy_expire_return).hex(),
        "legacy_genesis_arm_id": legacy_arm_id.hex(),
        "legacy_genesis_boundary_hash": legacy_boundary_hash.hex(),
        "legacy_genesis_launch_id": legacy_launch_id.hex(),
        "legacy_genesis_post_state_commitment": legacy_post_state.hex(),
        "legacy_genesis_state_selector": LEGACY_GENESIS_STATE_SELECTOR.hex(),
        "legacy_genesis_arm_selector": LEGACY_GENESIS_ARM_SELECTOR.hex(),
        "legacy_genesis_finalize_selector":
            LEGACY_GENESIS_FINALIZE_SELECTOR.hex(),
        "legacy_genesis_state_return_hash":
            keccak256(legacy_state_return).hex(),
        "legacy_genesis_quiescent_state_return_hash":
            keccak256(legacy_quiescent_state_return).hex(),
        "legacy_genesis_ready_state_return_hash":
            keccak256(legacy_ready_state_return).hex(),
        "legacy_genesis_state_return_length": str(len(legacy_state_return)),
        "legacy_genesis_arm_calldata_hash":
            keccak256(legacy_arm_calldata).hex(),
        "legacy_genesis_arm_calldata_length": str(len(legacy_arm_calldata)),
        "legacy_genesis_finalize_calldata_hash":
            keccak256(legacy_finalize_calldata).hex(),
        "legacy_genesis_finalize_calldata_length":
            str(len(legacy_finalize_calldata)),
        "legacy_genesis_arm_return_hash":
            keccak256(legacy_arm_return).hex(),
        "legacy_genesis_arm_return_length": str(len(legacy_arm_return)),
        "legacy_genesis_finalize_return_hash":
            keccak256(legacy_finalize_return).hex(),
        "activation_receipt_selector": ACTIVATION_RECEIPT_SELECTOR.hex(),
        "genesis_activation_receipt_calldata_hash":
            keccak256(genesis_activation_receipt_calldata).hex(),
        "genesis_activation_receipt_return_hash":
            keccak256(genesis_activation_receipt_return).hex(),
        "genesis_activation_receipt_return_length":
            str(len(genesis_activation_receipt_return)),
        "version_activation_receipt_return_hash":
            keccak256(activation_receipt_return).hex(),
        "genesis_activation_context_hash":
            genesis_activation_context_hash_v1.hex(),
        "genesis_activation_context_return_hash":
            keccak256(genesis_activation_context_return).hex(),
        "genesis_adoption_commitment": genesis_adoption_post_state.hex(),
        "genesis_adopt_migration_calldata_hash":
            keccak256(genesis_adopt_migration_calldata).hex(),
        "genesis_adopt_migration_return_hash":
            keccak256(genesis_adopt_migration_return).hex(),
        "genesis_queue_post_state_commitment":
            genesis_queue_post_state.hex(),
        "genesis_queue_migration_calldata_hash":
            keccak256(genesis_queue_migration_calldata).hex(),
        "genesis_queue_migration_return_hash":
            keccak256(genesis_queue_migration_return).hex(),
        "genesis_source_post_state_return_hash":
            keccak256(genesis_source_post_state_return).hex(),
        "genesis_target_post_state_return_hash":
            keccak256(genesis_target_post_state_return).hex(),
        "genesis_queue_post_state_return_hash":
            keccak256(genesis_queue_post_state_return).hex(),
        "genesis_activation_receipt_id":
            genesis_activation_receipt_hash.hex(),
        "reorg_genesis_post_state_commitment":
            reorg_legacy_post_state.hex(),
        "reorg_genesis_activation_context_hash":
            reorg_genesis_context_hash.hex(),
        "reorg_genesis_activation_receipt_id":
            reorg_genesis_receipt_hash.hex(),
        "migration_activation_context_hash": activation_context_hash.hex(),
        "migration_activation_context_selector":
            MIGRATION_ACTIVATION_CONTEXT_SELECTOR.hex(),
        "migration_activation_context_return_hash":
            keccak256(activation_context_return).hex(),
        "migration_activation_context_return_length":
            str(len(activation_context_return)),
        "migration_arming_lifecycle_return_hash":
            keccak256(arming_lifecycle_return).hex(),
        "adopt_migration_canonical_selector":
            ADOPT_MIGRATION_CANONICAL_SELECTOR.hex(),
        "adopt_migration_canonical_calldata_hash":
            keccak256(adopt_migration_calldata).hex(),
        "adopt_migration_canonical_calldata_length":
            str(len(adopt_migration_calldata)),
        "adopt_migration_canonical_return_hash":
            keccak256(adopt_migration_return).hex(),
        "source_freeze_post_state_commitment": source_post_state.hex(),
        "freeze_migration_source_selector":
            FREEZE_MIGRATION_SOURCE_SELECTOR.hex(),
        "freeze_migration_source_calldata_hash":
            keccak256(freeze_migration_calldata).hex(),
        "freeze_migration_source_return_hash":
            keccak256(freeze_migration_return).hex(),
        "queue_migration_post_state_commitment": queue_post_state.hex(),
        "queue_migration_credited_wei": str(credited_wei),
        "queue_migration_selector": MIGRATE_ACTIVE_SETTLEMENT_SELECTOR.hex(),
        "queue_migration_calldata_hash":
            keccak256(queue_migration_calldata).hex(),
        "queue_migration_calldata_length": str(len(queue_migration_calldata)),
        "queue_migration_return_hash":
            keccak256(queue_migration_return).hex(),
        "migration_adoption_commitment": adoption_post_state.hex(),
        "migration_post_state_selector":
            MIGRATION_ACTIVATION_POST_STATE_SELECTOR.hex(),
        "migration_post_state_calldata_hash":
            keccak256(migration_post_state_calldata).hex(),
        "source_post_state_return_hash":
            keccak256(source_post_state_return).hex(),
        "target_post_state_return_hash":
            keccak256(target_post_state_return).hex(),
        "queue_post_state_return_hash":
            keccak256(queue_post_state_return).hex(),
        "activate_version_with_migration_selector":
            ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR.hex(),
        "genesis_activation_fixed_hash":
            keccak256(canonical_migration_activation_fixed(
                genesis_activation_fixed)).hex(),
        "version_activation_fixed_hash":
            keccak256(canonical_migration_activation_fixed(
                version_activation_fixed)).hex(),
        "genesis_activation_calldata_hash":
            keccak256(genesis_activation_calldata).hex(),
        "genesis_activation_calldata_length":
            str(len(genesis_activation_calldata)),
        "version_activation_calldata_hash":
            keccak256(version_activation_calldata).hex(),
        "version_activation_calldata_length":
            str(len(version_activation_calldata)),
        "maximum_genesis_activation_calldata_hash":
            keccak256(maximum_genesis_activation_calldata).hex(),
        "maximum_genesis_activation_calldata_length":
            str(len(maximum_genesis_activation_calldata)),
        "maximum_version_activation_calldata_hash":
            keccak256(maximum_version_activation_calldata).hex(),
        "maximum_version_activation_calldata_length":
            str(len(maximum_version_activation_calldata)),
        "maximum_migration_proof_bytes": str(MAX_MIGRATION_PROOF_BYTES),
        "release_manifest_typehash": RELEASE_MANIFEST_TYPEHASH.hex(),
        "activate_release_selector":
            keccak256(ACTIVATE_RELEASE_V2_SIGNATURE)[:4].hex(),
        "release_manifest_hash": release_hash.hex(),
        "successor_release_manifest_hash": successor_release_hash.hex(),
        "destination_registration_commitment": registration.hex(),
        "registration_commitment_base_slot":
            registration_commitment_base_slot().hex(),
        "registration_commitment_slot": registration_commitment_slot(2).hex(),
        "registration_commitment_trie_key":
            registration_commitment_trie_key(2).hex(),
        "release_manifest_base_slot": release_manifest_base_slot().hex(),
        "release_manifest_slot": release_manifest_slot(2).hex(),
        "release_manifest_trie_key": release_manifest_trie_key(2).hex(),
        "inbox_route_config_hash": inbox_route_config_hash(
            0x5100, 0xB200, 0x5103, destination_domain).hex(),
        "forced_queue_config_hash": forced_queue_config_hash(0xAD01).hex(),
        "data_session_config_hash": session_config_hash.hex(),
        **{
            key: value.hex()
            for key, value in session_function_selectors.items()
        },
        **{
            key: value.hex()
            for key, value in router_session_gate_selectors.items()
        },
        **{
            key: value.hex()
            for key, value in ROUTER_SESSION_GATE_MAGICS.items()
        },
        **{key: value.hex() for key, value in session_event_topics.items()},
        "forced_root": force.root.hex(),
        "empty_forced_root": ForceVector(()).root.hex(),
        "force_range_digest": keccak256(b"".join(proof)).hex(),
        "session_id": sid.hex(),
        "mmr_root_2": mmr_root((leaf0, leaf1)).hex(),
        "manifest_root": manifest.hex(),
        "manifest_root_block_1": manifest_block_1.hex(),
        "empty_body_root": empty_body.hex(),
        "empty_manifest_root": empty_manifest.hex(),
        "empty_session_list": empty_sessions.hex(),
        "dispositions": dispositions(2, ((2, 1, UINT32_MAX, bytes(32)),
                                          (3, 4, 2, keccak256(b"raw-signed-tx")))).hex(),
        "recovery_id": recovery_id(settlement_chain_id, contract, 4, 2, base, 8_000,
                                   1_000, bytes.fromhex("88" * 32), force.root,
                                   len(envs), 12, adm_root, 9_000, 3).hex(),
        "body_root": body.hex(),
        "chunk_root_0": c0.hex(),
    }


EXPECTED = {'abort_expired_version_migration_calldata_hash': 'bc9fbd94a30dd30c4a3791631fc933841694cb9cc3b26e4aadbfb0585f0877ef',
 'abort_expired_version_migration_return_hash': 'cecc7a76c559e89ad8bdc8009067ff67163188d7fe5f16a9714837f7b499df8f',
 'abort_expired_version_migration_selector': 'c4eee12d',
 'activate_release_selector': '28f73572',
 'activate_version_with_migration_selector': '14c37693',
 'activation_receipt_id': 'b390074907519b7a2764d9e2e6d86d75904ccd07fcc86c40397a038ce08c081f',
 'activation_receipt_magic': '41525631',
 'activation_receipt_selector': '0a4434d0',
 'activation_successor_receipt_magic': '41535631',
 'active_settlement_state_magic': '41535231',
 'active_settlement_state_selector': '4a95c306',
 'admission_reuse_root': 'a1e22890dd835872055e53dcad82d9e12759a2920853fe6e9f735d7f2c87ceca',
 'admission_root': '3bf2dcaf78292c832108e29205bf99cc2d22137a0545e4528d8da7309d4b482b',
 'adopt_migration_canonical_calldata_hash': '92366259f576a370029e270ba4e032e74339fac39d850903440060f26093fb4c',
 'adopt_migration_canonical_calldata_length': '548',
 'adopt_migration_canonical_return_hash': '3fabfe7082e0ab3873d16ad30d157d5ad409f56c478596a9bb85c427b44ee974',
 'adopt_migration_canonical_selector': '557c4e13',
 'append_from_adapter_selector': '1927261d',
 'append_kind0_calldata_hash': 'caabdaadee6df8cea48fb88dacad863e6e24e13f5b0c06f99408d5c71611788a',
 'append_kind0_calldata_length': '388',
 'append_kind1_calldata_hash': '8bb6f931d1ceeb051f0de3bc0b32f788c0d45b856eda148128e330013a7d3e5e',
 'append_kind1_calldata_length': '708',
 'append_terminal_calldata_hash': 'c2daf944308e8785936774fd10b51f95a50a15d337059dd192682dd533adfa1e',
 'append_terminal_selector': 'abc194f5',
 'apply_protocol_change_calldata_hash': 'd9aeea7c3da04cda67187ee96f20669b496c7fe25510dc94e5157a54d45ad83f',
 'apply_protocol_change_calldata_length': '260',
 'apply_protocol_change_selector': 'af3927f6',
 'arm_version_migration_calldata_hash': '72c1e2958118bff66b6e530d9c52fac6e0f506d84b9142e4d3273660be3b2fe9',
 'arm_version_migration_return_hash': '7bc7e39e02fb4504dd4f1a7d70cbbfd4e88a1a8985163929c1bcc2d259373244',
 'arm_version_migration_selector': 'e3bcfcb4',
 'base_canonical': '67b52faab1709aff021dcb9c16acf86b5b4853de7eb5e36bf1b48566f448621e',
 'block_struct_hash': '6bc4d67c1c53b6793ace07f9e20b6466207dc7e8285232fbd063900c1bb7614e',
 'body_root': '0f4e161a46c8b18c2a86f23a0a4e7169a838a12af8b389f65e97b547a99707e9',
 'bridge_credit_id': 'dc227c06eecc3bdd1ea0d48345efc48b017188e40f43e7c33450314260ac5538',
 'bridge_escrow_id': 'cbb92e32149a19f26a3db755300df9f7d401fe51c4a7121b966ad77b598385d5',
 'bridge_execution_hash': 'f9832b2fbef2ef60a0fc7a1420fe8ae745c3840c86f6c932b2818c201b6b5df1',
 'bridge_kernel_profile_hash': 'a23f9994e8d1c475500768b67cf2b2d1f7a0f367df6f44bac5ccf1fa12bc1338',
 'bridge_leaf': 'f5bda35fb1e021706647269866a683dec01b7c15355b3b2aaa6dbddd6eeb8d69',
 'bridge_result': '675ef16e849ab97ac931e08c98e51ab4bd9b77219e8a98510742ff37bcec84cb',
 'cancel_protocol_change_calldata_hash': '765e3e164cb46e2abb9cc51e5d44a11f858d7c527f29cc92b209e460e07c5593',
 'cancel_protocol_change_calldata_length': '452',
 'cancel_protocol_change_selector': '5701c308',
 'candidate_commitment': '43e4ceb88ddf11a80441caccea6041c734aca203b5f9e377ecc21476898dd91c',
 'candidate_commitment_2': '9c86096381bc8c73a25b947de251960c9a0dc8ca32175b888b13fe0836dd2835',
 'canonical_core': 'f59591f1e2e274e4aace20509a2d855e42b88ecac33a5550fd1af781c83047eb',
 'chunk_root_0': 'e652cb05b1f44f3c09c650870b7b9ade4132548bd0c769bdda35b5bfcac5139e',
 'component_config_getter_gas_limit': '50000',
 'component_config_getter_selector': 'f6c0f7d2',
 'credit_authorization_v2_calldata_hash': '39dc6acec6ffaa50d80236d4477bc730a4836b2cf9c052df4d912fc9b378ae7b',
 'credit_authorization_v2_return_hash': '6ae80373b6d63263cebc2c6effd92e1c28f3cdd92685957d2c5494d370a06502',
 'credit_authorization_v2_return_length': '576',
 'credit_authorization_v2_selector': '05ecb6c2',
 'credit_liability_v2_calldata_hash': '0c7011cfb287b6b5e15b8db4b7b605549e1b5c59d3a4202e397c09ac1a951ff3',
 'credit_liability_v2_return_hash': 'ad3bba6e04fff6bfefacfdf034f4aaf7bba7149ef0f4dfa0625a5653290f9195',
 'credit_liability_v2_return_length': '288',
 'credit_liability_v2_selector': 'c978978a',
 'data_record_appended_topic': '30ee2de166c53a480d028e5b94d4f8759dbd84b5f7b6af1f23e0c5889ea17f8c',
 'data_session_config_hash': 'a9198362f19424d86fec60351e9883028b83fdbc7df2ae710325e5affec01173',
 'data_sessions_maintained_topic': '920669b9670911aa86cd718dceebaa1372d224ca0fdac50a63dc1d45a53e1e89',
 'deployment_commitment_typehash': 'babd40345cd96b87434cc1bcc50b0c693556c37283b9b3399abf60339dc363a0',
 'derived_source_bridge_address': '19ed48aa17648c30ffbec0ddd91eb364c42bc904',
 'derived_source_bundle_deployer_address': '8c3b5d66dfee6f26deb0fdf8ad09017ed7bb02a2',
 'derived_source_quota_address': 'f3e97a2afcf1f6017306435ab35a60eaff6a86a8',
 'derived_source_registry_address': '47e6e9139b4e0297baab4113a3787b271e3b7a54',
 'destination_activation_receipt_id': 'ce7817db42f84429f1fc630bd12c83871ac2f70e8ee58b015bcb4927391bab2d',
 'destination_activation_receipt_magic': '44525632',
 'destination_bridge_execution_hash': 'e356731fbadc537ccd8c8cf4db19e343016889c5233aa592cb5d2751ace3faf6',
 'destination_context_hash': 'c591b7156965ce659a5382725f8b1091dbc2188cc7cbdc2620a61b49eb04ace1',
 'destination_context_typehash': 'b8170dbf684e1fc4dd4dae8fb78ad24984cc0aa0c03cbd1e29b1b2eb5728eefb',
 'destination_domain_id': 'c5fa66479b2914cd0974c72102929ae9852311f9cb44d432b833a22692104af2',
 'destination_infrastructure_hash': '6dd1dbc5d01f345c9896b91cc0626baf2585b24ce791633cc9c704b4756549a7',
 'destination_registration_commitment': '40ce2a7d88dd92c6a71d192d66b234b363795061bbd566a2c8b2382af30bd135',
 'destination_successor_receipt_magic': '44535632',
 'dispositions': 'ab253c1204a53b6e095a887dfa6acfc8e8c0c6f89badcef5f73fee716fa94b93',
 'domain_separator': 'e68571dca46842abc561c1ea35b556152b15d93a1d29f5c441ae2fdcdd01725c',
 'eip712_digest': 'bf50900a66dd735bbed4a20b7ebe909b61d15185146813b3105b9d2eefa91c68',
 'empty_body_root': 'f0e00da8dbc00feb028a8bc92342c0771372b947acf5989b2d4a5f23bb2f459a',
 'empty_data_session_accounting_return_hash': 'cff427459be83a332f930298ce8326925e9ed5e74772f1fe4c91f9f6bb9417f5',
 'empty_forced_root': '4001bca0d3c5171a99a50118f1219024e1bef9302262ea3b075ecbed36be7592',
 'empty_manifest_root': '0bb15f38645cecc1748b17fe3bd966ba8016c169ebd1266fd38150766177b5f6',
 'empty_session_list': '8827f09b5799bab18f29ea5b9cb9cbb5a88ddb96bc4b3ffc4d69cbcbdfe50279',
 'empty_terminal_root': 'c5da197edc2f03c7023cc6afe137ccb77d01fc56514d322b6ba66a149315bcb0',
 'enqueue_bridge_credit_v2_calldata_hash': '02db9c77025d4c2bae1d3f79849020e6d8711c4b6b6c54ec45ce9181e48cfeb4',
 'enqueue_bridge_credit_v2_selector': '81805d6b',
 'enqueue_forced_transaction_calldata_hash': '3e802e6f72e50c267cc18d256c2863d04446eb8f2d47bc474bbcb9c68876d19a',
 'enqueue_forced_transaction_calldata_length': '196',
 'enqueue_forced_transaction_selector': '9f06b1b4',
 'entry_root': 'acee83a690b868a4a7960c55a9f7228f91cad26b704e24106d4db87e9c7a8f34',
 'execute_attempt_calldata_hash': 'ad5ad3f673a39e9f596125189e214718927567ddc017b50c6ae7df6fb4b9306c',
 'execute_attempt_calldata_length': '1124',
 'execute_attempt_selector': '4cbe2fe2',
 'execute_protocol_change_calldata_hash': '53ee103fb2f21efd57ad1fa188745e77fda1cdde4988e659a37036770a11dabf',
 'execute_protocol_change_calldata_length': '580',
 'execute_protocol_change_selector': '31d81ea2',
 'execution_outputs': 'd3b52765911a60935fb5e7c1b7047ad1611e07586803cf654d6d5b677f966d56',
 'execution_profile_abi_length': '8192',
 'execution_profile_creation_offset': '8096',
 'execution_profile_hash': '22292c4c1b89ea56c052352c2de7a52fa103da54ccef6238d6e2cfc25ab2eb56',
 'execution_profile_static_words': '253',
 'finalize_failed_attempt_calldata_hash': 'dc035692a14124eb319e335b2112532a8ef6126369f2a77e90e8819d97d9d2b3',
 'finalize_failed_attempt_selector': '745dcb69',
 'force_range_digest': '75c75611d9eaa6c05e56a1fb646cea4c9d796adfd205df5c5ff1b0b52cc93dd2',
 'forced_descriptors': 'ccc81a65638181195f6ebd5b5902bc3a62716d7c3e70b32cbabdd250b9ebf42f',
 'forced_leaf': 'c75c50d8b8573f217a20c9018a3d23d7fa5cda240f2a2e9eb4260c4af4c367e4',
 'forced_queue_config_hash': '72e27c19ebfab08e1fb27feeff50609c7c4bb69f0570a7bdb72eda7736c50f4e',
 'forced_root': 'a54e9f797ffe7f04dd5ca7df4c858edf02ce45a81808522633fc9cee8fe72e57',
 'fork_verifier_install_magic': '46564931',
 'fork_verifier_registration_magic': '46565231',
 'fork_verifier_registration_return_hash': 'ed8f0a8c03c6743ffad9ccf6ae618ac65bfcfc1d5c6cf924a3b58ddc69166140',
 'fork_verifier_registration_selector': 'c614591c',
 'freeze_migration_source_calldata_hash': 'a1f8fd6ac6f3f722f3b2ef1ee56a4a07cf3e1a0047125e9b03cca546c273fb23',
 'freeze_migration_source_return_hash': 'f1082d527fe0b2b8bd04a736726d2765d43648eddc746d0c345cd747330984c6',
 'freeze_migration_source_selector': '45a80913',
 'genesis_activation_calldata_hash': '899862123801d01e4d5f529c6a5fa785a07eb524fe850443e10dea2f73492cf9',
 'genesis_activation_calldata_length': '2884',
 'genesis_activation_context_hash': 'fa309b6a84746d1d6acee8f87f9321271cb68eeaecc264ac718812eacd8211ac',
 'genesis_activation_context_return_hash': 'ae5130794e17672433cf1df57dd6fd2c59e5a9e138606446393ad1d1a2db787f',
 'genesis_activation_fixed_hash': '51509fea7d67c057520beb2fbb8620f434d30e49134bd78e104c481b929c865e',
 'genesis_activation_receipt_calldata_hash': '5c33ca28ae8c87326903243bd8e7d3014da48062d3dc122d7f645dedad796f64',
 'genesis_activation_receipt_id': '3cc0a9c40dbdb83da7b507448f9d289f5b5efa51c20e6391fa6fba9caf72452d',
 'genesis_activation_receipt_return_hash': '5c7ccef17c99ea7b3e8531b30342cbd6201caec7bfaae09bafe28921a11247bc',
 'genesis_activation_receipt_return_length': '992',
 'genesis_adopt_migration_calldata_hash': '9203b4a9789a1063ae7241242ac7f2c19227de972cd0b1dab6699ade4ba4e6c1',
 'genesis_adopt_migration_return_hash': '0d6cc2c07afaf087428fdeea4c1a3450a2719c9985132945c14fc562b968e47b',
 'genesis_adoption_commitment': '69732105259421cf5c3c480543c2922061750cfb76793e615604dc95799b2d2f',
 'genesis_base_canonical_hash': '5081c70042287a8b7156b2626675ea4ed9623c755d5f51b5c83be94e90da3ff3',
 'genesis_base_core_hash': '12243b817561a9362bb03dffb36bb73f9314d47e3165673793419692cd8a8566',
 'genesis_candidate_commitment': '90949c0865a5e0226c6c0d736c0533f9e5f1d793dc9c5d21407a210ee3896338',
 'genesis_deployment_commitment': '1e0ba02cbe13e7b14cfb427684497a7526b5252f5db86e32c48f99f8f35c3a35',
 'genesis_migration_statement_hash': '6df922703aa5b22c9f1035ede611a2aec2ed4f160536b4e7076b5031ba2ded10',
 'genesis_output_core_hash': '46ecec937013339205139353730b413c8e508bc579ec9c0ede247161132134a8',
 'genesis_queue_migration_calldata_hash': '9dbafd23a937ec8aa2a5ab26845e0cafc95ddbacbfd9a9f9d4364415aa9c0467',
 'genesis_queue_migration_return_hash': 'c9ce547f713aa89aadbb5e3f65c73ead7a042233bbba470e7e01512b5b2014b0',
 'genesis_queue_post_state_commitment': 'd58031a42d100455f424a28e0c3aa0fc64d3dbaabc5fdef3c349f1f7b37c6e4e',
 'genesis_queue_post_state_return_hash': '2454a589b32353c19cbccb91c1e2fcadb330cc22aebf9496a4f8974b10d1f3c9',
 'genesis_source_post_state_return_hash': '437610375708fbcdf4d1f88757e3d344605b8670812deee3abf492ab9cd657f3',
 'genesis_target_post_state_return_hash': '726d07b3ddb51eeb54a37a48ac5806c4c24a55a1fe3b99957d402e0ce46ee27e',
 'get_inbox_credit_slot_calldata_hash': '6313403f45f417e865b55034330db4a74d46746e4b635ad6c840bf3c869d279d',
 'get_inbox_credit_slot_selector': '31e85ab1',
 'governance_delay_authority_descriptor_hash': '442d9b608ecc43eea4009fb7f95c764c747636f42c885174c1442681cc0ab495',
 'inbox_apply_calldata_hash': '65332d0b3230b33c0ae8bddd8a1f3be8473739f865e73fc8e52f4f99cecc89d7',
 'inbox_apply_calldata_length': '14436',
 'inbox_apply_maximum_calldata_hash': '9e49bada9e2768e61d8b197cc8543d0931a5ff6ac3bee93e17fffefb17916597',
 'inbox_apply_selector': '6b326168',
 'inbox_batch_magic': '49425632',
 'inbox_credit_slot': 'b6850870a89c5fd93129ea8d1c1d4fa02e810c2ba8c235cf594e8e8258d828aa',
 'inbox_route_config_hash': 'b7a461bc5970c971f2cc9abb3877e5e1c02cbc922ae4b3cac3b63737f68c7805',
 'ingress_authorization_root': '1f1a415674dea5e83de74f9f6931c65584ab76ae317eedfcec7f94a2fd09d7ae',
 'ingress_authorization_root_typehash': 'c7b11126d8d1984cc17cbc108be2a1be0ef9c4e8fd519fa9033c949962f1b042',
 'ingress_authorization_typehash': 'a2dccbd60c366ade3f5af12af640f3453bbb4106405ef8da5dd52484db8f2a82',
 'install_fork_verifier_calldata_hash': 'f986d1bbd6f3801e5ea25305cd72946eae312d78b512a7649e669e7c251e05a9',
 'install_fork_verifier_selector': 'f171816c',
 'install_settlement_authorization_calldata_hash': 'b5fce88f5bc4802175332ca337e8aa80c4903f7fbe04680d3db1e86bf5adb066',
 'install_settlement_authorization_return_hash': '1ed7ac691e6e73a073095e2f3f1eaac8debe962111b8358eae7d637e0a10ab39',
 'install_settlement_authorization_selector': '72a3e937',
 'invocation_policy_calldata_hash': 'f01466ef7479c70c7d2b11bdb8d91b06db6a9058fa39fa9ded3903ebc9543fd4',
 'invocation_policy_getter_selector': 'b2d0e286',
 'invocation_policy_hash': '5eb7c00399d64d91e416d5a3dbe75187c39dfc2a4645b867864b5fd9e649f3e3',
 'invocation_policy_magic': '49505632',
 'invocation_policy_return_hash': '93bc154411cabc321c6b7c452a338e3e52789f0b97229cc2c68ba0bb4e3f3a19',
 'invocation_policy_typehash': 'd702a337b74fc40bfc746fb1aeeaa705e60a95947bfc3076c76222703205b4b1',
 'kind0_ingress_authorization_id': '27af2fda507104b24da0f7a6095e048cc86de215f38027c2671f4455878a4317',
 'kind1_ingress_authorization_id': 'b67acf3b2b6184480794d8b2187f785c9e9cbebc82976e10a972dc893031ad3c',
 'legacy_blob_slice_maximum_hash': 'd9791c1e9f76963f86cdfe6423b8d897dcc5c0ef5ad4cc16363b2b2ab452240d',
 'legacy_blob_slice_maximum_length': '832',
 'legacy_blob_slice_one_hash': 'f0c8974a111225866a147954a2f98c29c679c1aa4680c42b15ac2eb3a1cea148',
 'legacy_blob_slice_one_length': '192',
 'legacy_checkpoint_config_magic': '4c434b31',
 'legacy_checkpoint_config_return_hash': '4ab6f89dcd323544a673c0243a0ad55779c74ae37d981d3308829092d7713534',
 'legacy_checkpoint_config_return_length': '192',
 'legacy_checkpoint_config_selector': '68011023',
 'legacy_current_operator_return_hash': '7606a1b3fbf7c1835d2aeeddf4207ed367c600f20c898605ba54d05cbbb3be39',
 'legacy_current_operator_selector': '343f0a68',
 'legacy_derivation_source_mixed_hash': '7e0699ca450524a9f618d63c9c6ac4690e44bf47ae3a24980346f4d91b3a8789',
 'legacy_derivation_source_mixed_length': '288',
 'legacy_descriptor_call_gas': '100000',
 'legacy_descriptor_impl_selector': '8abf6077',
 'legacy_forced_inclusion_encoding_hash': 'ffad3668322a174e4a6b3180869175b6395a8657c6940353ce2cdf442fe98cd4',
 'legacy_forced_inclusion_encoding_length': '256',
 'legacy_full_scan_capacity_bytes': '4161536',
 'legacy_full_scan_capacity_headroom_bytes': '32768',
 'legacy_genesis_abandonment_receipt_hash': '597abd3f5e890c11afa7d5bacc4f359834efd5bd1f60304fc2a4f77856d76e6a',
 'legacy_genesis_abandonment_sealed_topic': 'a3b978444273f8f347857235c224846aa45e8ce5bb73df549b9916e96371c8c9',
 'legacy_genesis_arm_calldata_hash': '6046c79779b7bbd02107a76627bff3186b9ddc1d18ad252436d23a9d338ac6d8',
 'legacy_genesis_arm_calldata_length': '68',
 'legacy_genesis_arm_id': '799c52565ab954d8ecf7e47b08534595f06c469fae36e69c3b185d4900044f0c',
 'legacy_genesis_arm_return_hash': '8ca209561c9268a32d8c67c0ad5a43772aad2e280806e146206c9e2cadb38f6c',
 'legacy_genesis_arm_return_length': '128',
 'legacy_genesis_arm_selector': '8781a058',
 'legacy_genesis_begin_scan_calldata_hash': '506cebf31bdf2bc86cafa84bc56c16592779b1fa793c3fb6d6280933e051f4f8',
 'legacy_genesis_begin_scan_return_hash': 'add644dde24164cfb29ab6a4598cb55acb73c55dd295b0c2a227dc3264c6f65c',
 'legacy_genesis_begin_scan_selector': 'e9d1a07f',
 'legacy_genesis_blob_data_expiry': '1573864',
 'legacy_genesis_boundary_hash': '0215b43e3b2143b3fcac2c97bc2f8cc32ab47ac695a6fd173d919abdcc170263',
 'legacy_genesis_campaign_fence_descriptor_hash': 'cf5cd470448a26b70eddedf8c30fa39533e66e874e2fc1aa2e310ab633c0d737',
 'legacy_genesis_campaign_id': 'aa06260ec9cdd07a71c6d23fc72dc5107cad200da425b76b0e1cb8c50425347f',
 'legacy_genesis_campaign_magic': '4c474331',
 'legacy_genesis_campaign_return_hash': 'cd3963cf1857195564f8c0960cc595b856c50f3d288bc18c6858c6a298765175',
 'legacy_genesis_campaign_return_length': '512',
 'legacy_genesis_campaign_selector': '718b2ac7',
 'legacy_genesis_checkpoint_record_hash': '1461a32136f8c498043934fce575dddec6830744145afbccde57eea1ea61c9b0',
 'legacy_genesis_checkpoint_storage_layout_hash': 'f9e5f221ec2368348e185feb34fee0cdb27a812a2533c56fa7dfe8ccf762ffe1',
 'legacy_genesis_deployment_hash': '98cc45a7619c75ff658f46edbe2e3c11c19e1ec424797cf04c760b9f07fd567c',
 'legacy_genesis_expire_calldata_hash': '06cbd562374561b29dd1f8150be16d226978a020da51da0f2ac5cab419286e03',
 'legacy_genesis_expire_return_hash': '9536645b48dce02dd376837692e40f53cd5ac18e6af5d0c31bade33be31d2e19',
 'legacy_genesis_expire_selector': 'a4a37936',
 'legacy_genesis_finalize_calldata_hash': '10105485328c76767b73403c4073bf762fbe76f0811230076f358276f9766b14',
 'legacy_genesis_finalize_calldata_length': '196',
 'legacy_genesis_finalize_return_hash': 'b924e354107dd8656f106cfd429a7636cc9d2576dc0b45c272f94fab4f791968',
 'legacy_genesis_finalize_selector': 'c2de6417',
 'legacy_genesis_forced_record_hash': 'dbda8510c73bc3eb57de26ae5c5bcc82a45bf6fedab68abf100d9baea6f4a380',
 'legacy_genesis_forced_rows_empty_root': '5631fad8f285ac1643b4e817c5454ee4f1e35174786dd255842a987b21c3fd92',
 'legacy_genesis_forced_rows_root': 'ab7f340cae89170a3a619086538cace009399987a1bffbee40c17da60c10fcc8',
 'legacy_genesis_launch_id': 'ff532c65eca209c3db2cd49f550ec18dd33dd9b93eee6ba38ad40f4318bb88f5',
 'legacy_genesis_post_state_commitment': 'b3ed034b75a6d707a7b7252c302bbd5187d0d5e20c5d574b59e93001de887aa6',
 'legacy_genesis_preparation_return_hash': '8c869f3dfe7df0f01a65e96d7691b5b0d095590acd9f034770c33a6c75472a98',
 'legacy_genesis_preparation_return_length': '288',
 'legacy_genesis_preparation_selector': '6880cd05',
 'legacy_genesis_proof_verifier_graph_hash': '4fc1c37502713218107f6aefba90f1a5720e9ccd5a5569abb590746e85f64efa',
 'legacy_genesis_proposal_rows_empty_root': '0736a35926f1618d1fcca0fdf57530d52f3d1694eb227f31c28b158b370793d5',
 'legacy_genesis_proposal_rows_root': 'aeacf67ac14d90928d567c659ff80316a0d780fc490ac6b4b69e9620836d2b46',
 'legacy_genesis_proposer_checker_descriptor_hash': '1bd9411f4082f5d010edfad3ba2a52ed5164a7a7ec345c1d56f11a2b3448515a',
 'legacy_genesis_prover_whitelist_descriptor_hash': 'afda6179076d7f2625ac4e691fd28ff557ef3419a708f22598bc8419b6a27c05',
 'legacy_genesis_publish_magic': '4c475031',
 'legacy_genesis_quiescence_calldata_hash': '7622002d111067b051b35e10a1098bb77f5720300d779960032d56ab4fe825b8',
 'legacy_genesis_quiescence_return_hash': '0bdeb36de78a895e7fc0f9fc43bd5e570eb3f789aa0be60756b1601607d9b95c',
 'legacy_genesis_quiescence_selector': '4c0ae8da',
 'legacy_genesis_quiescent_state_return_hash': '5bf2b30077f31f7358b9e9466110dc3a7559bf6250df27e053dbd9a7c7cac2e5',
 'legacy_genesis_ready_state_return_hash': '61ea987bd5cf6749c2cf1529a85d9a6e5720c6de9aaa2984407216f1aebc11b1',
 'legacy_genesis_resume_calldata_hash': '0908f0acdb096d176a7dd3722ccefb4dfb2d97b33bdedeaf2478ab29ee36e65b',
 'legacy_genesis_resume_profile_hash': '6a993ebf703937ddefdd8a5ae08911f15a19286ae47b40d0b91a08824cbb2812',
 'legacy_genesis_resume_return_hash': 'e9fe8a7d7e0737dca59cc76084c7a67384789ca762685ef1d320e2a510da0eb4',
 'legacy_genesis_resume_selector': '2bf6b656',
 'legacy_genesis_resume_time_policy_hash': 'ae8419c16fd9493a76f4192c6bef1396d6237a2f2d981dc2bb55acfb3086e5d6',
 'legacy_genesis_resume_verifier_route_hash': '527763e6ea020b909c9a74a7aa5b7c2fdb372c5d8f283644d4d454bc63c16275',
 'legacy_genesis_review_commitment': 'ad645ed9c3e81c995eb88dabbc1b0a6d93539c360679f230001abadd633494fb',
 'legacy_genesis_risc0_resume_key_policy_hash': '60651c05d2012e7254373988020eaf9dec6c635e84d535112e7ade81aac5584a',
 'legacy_genesis_risc0_reth_verifier_descriptor_hash': '4805e24aa165db57d51ab99349241fd843ca03e468afb8d33781d4a08ccca55b',
 'legacy_genesis_scan_commitment': 'd49046961e41f21e9073422d2a73190dcd0e78ee8e04c5ef3e6def287d47046b',
 'legacy_genesis_scan_forced_calldata_hash': '61a7e4c98610eb46b65d4b5019026e25959dc1ba17ca255dd2a9968dae330b57',
 'legacy_genesis_scan_forced_return_hash': '10dcb42db706d4c4a5afe207c6327f8cecbcbc4b298c0255fe2434662e6599d6',
 'legacy_genesis_scan_forced_selector': '032ae99e',
 'legacy_genesis_scan_proposals_one_calldata_hash': '87e956457ea296af8a317fe81f8d1f9b4943586702bb6ecee581dd808c398554',
 'legacy_genesis_scan_proposals_one_calldata_length': '4004',
 'legacy_genesis_scan_proposals_return_hash': '10e8d4b72d5c271bc6f13dd2b9c476d4efd217cd1eddc07d04f0753b645ada6a',
 'legacy_genesis_scan_proposals_selector': '7da66460',
 'legacy_genesis_scan_proposals_sixteen_calldata_hash': 'dcfd22339f0e3b2ceda7f014ceb1fcbdf8feb1311c12f20c7695dc84eb6e7ee9',
 'legacy_genesis_scan_proposals_sixteen_calldata_length': '62084',
 'legacy_genesis_scan_state_return_hash': '8e5e397d2f4ad82a793cc1fd0f8541e1b81a24e6cb6a0704da944d0085f2155f',
 'legacy_genesis_scan_state_return_length': '608',
 'legacy_genesis_scan_state_selector': 'ef3cdce0',
 'legacy_genesis_signal_service_checkpoint_descriptor_hash': '5e10f1f156d0913967b53921f75484530facf090ceb544306381abb78894143c',
 'legacy_genesis_sp1_resume_key_policy_hash': 'b449ce6092b398fd4178d946077f8f19c4f2451cc88d614bb682233134162f12',
 'legacy_genesis_sp1_reth_verifier_descriptor_hash': '523d245ce9369abd6a116dd7cc4b4a989fcfb8a9d1f8eb796e1cb35945f18bf6',
 'legacy_genesis_state_return_hash': '4f3e86d5ccbae57c51a441e9bdbad9cd481eceb37f3aa7e74a98390448c1cd65',
 'legacy_genesis_state_return_length': '512',
 'legacy_genesis_state_selector': '9b698000',
 'legacy_inbox_config_return_hash': '4d6b260943518f7ce988e85ddb9321b2a3111a42e9ba431f45342ff6f4f3cea7',
 'legacy_inbox_config_return_length': '544',
 'legacy_inbox_config_selector': 'c3f909d4',
 'legacy_inbox_configuration_hash': '22bc70c195669ace965e7565ae253f760d785e048965f94efa51845573b36808',
 'legacy_maximum_forced_row_bytes': '256',
 'legacy_maximum_proposal_row_bytes': '3808',
 'legacy_maximum_scan_bytes_bound': '4194304',
 'legacy_maximum_sixteen_proposal_raw_bytes': '60928',
 'legacy_maximum_sixteen_proposal_scan_calldata_length': '62084',
 'legacy_next_operator_return_hash': 'c7a0cb7d58c090fb9b48529de670e08db7fa5d48d0b8fb1a2c25f357ff0215ee',
 'legacy_next_operator_selector': '72a8a551',
 'legacy_operator_count_return_hash': 'c2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b',
 'legacy_operator_count_selector': '7c6f3158',
 'legacy_profile_maximum_forced_inclusions_per_proposal': '10',
 'legacy_profile_maximum_normal_blob_hashes_per_proposal': '21',
 'legacy_proposal_maximum_encoding_hash': 'ac882b6809d66ab7fa52d59ef700c30ef460ae5b45db8ccdd0ea6cfdc62fb298',
 'legacy_proposal_maximum_encoding_length': '3808',
 'legacy_proposal_mixed_encoding_hash': 'b83ae28a39b0d773dfaccf449234cc30a737b896dc3a1a2b1d4b15bcf2ae07d4',
 'legacy_proposal_mixed_encoding_length': '1152',
 'legacy_proposer_impl_return_hash': '760f5b3a5acc4b21ba8112ebe315c3946dc41e502bdb323e50afeac90a42ae8b',
 'legacy_resume_proof_generation_max_seconds': '900',
 'legacy_resume_risc0_config_magic': '4c523031',
 'legacy_resume_risc0_config_return_hash': 'c7b1f85e99c9b82651e09ced5b86de094ca46ef38aa0f5c22d94efa1d8222906',
 'legacy_resume_risc0_config_return_length': '192',
 'legacy_resume_risc0_config_selector': 'e516c43e',
 'legacy_resume_sp1_config_magic': '4c535031',
 'legacy_resume_sp1_config_return_hash': '864c870262c85ba745d71a95e0d667b76fddf17d60a5efe48512b289ae61a9b0',
 'legacy_resume_sp1_config_return_length': '192',
 'legacy_resume_sp1_config_selector': 'e2b5d958',
 'legacy_resume_verifier_config_magic': '4c525631',
 'legacy_resume_verifier_config_return_hash': '76ded5a00e4182d6eb5d2d40700d85414c53a99657ebed6dc9612205c703dded',
 'legacy_resume_verifier_config_return_length': '160',
 'legacy_resume_verifier_config_selector': '7e52cacd',
 'legacy_signal_checkpoint_hash': '6ab84b0c77035309ac300830aa1c31d95f68c44b697d97a6836f7f3f54bf0708',
 'legacy_signal_impl_return_hash': '8e4eff68fda06b95881cfa2df901251b566e87657e1a6ce77e69fd5546318034',
 'legacy_signal_service_version_return_hash': 'b10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6',
 'legacy_signal_service_version_selector': 'ffa1ad74',
 'liquidity_consumed_topic': '7f0ddd8af8190f3a3857af29a65ebb7546d6eecfa85fb39d4a697916bc75fca5',
 'liquidity_deposited_topic': '5eb65038b938ffac21aec1d6ecbbe2195bc6697ae085a31dfbca8fca3aaf9931',
 'liquidity_fee_substitution_bridge_leaf': '354d05b8bd4364ff8a7454f3e3975a4c014a3b268104430f4e825f376ab58505',
 'liquidity_fee_substitution_credit_id': '1fbc7c2842cbd1da217fa0629d43a13942e0f42d85b7f3a686b2126b800a80f6',
 'liquidity_funding_state_calldata_hash': '70538ed27eb15b05745ce184b2e379e75d4727d6aea99cca2002965881c850c0',
 'liquidity_funding_state_return_hash': '6df1cebf9a0cfe463f07eea36d2a529c86152ed68d1b46f4f0f772886a3f9b2f',
 'liquidity_funding_state_selector': '6a9a6c32',
 'liquidity_quote_calldata_hash': '3df0620780d6a374d4e5d69eac21e386c1a91aadc9efd1d5379050ca97a0854a',
 'liquidity_quote_return_hash': '478bb3115d3710875b9e946106519c01bd5e4d34fd15781196a8d47c2ddddc82',
 'liquidity_quote_selector': '43dc48e0',
 'liquidity_settlement_hash': '625ff42ed879b94a7499fecb7abc07988b348300d1c4e9cc1f7596968eaf2f19',
 'liquidity_ticket_id': '5dc074de7029f6762c8c386b15cbd61cc7ad94b9432c25a35a5ae48e72c3bf2b',
 'liquidity_withdrawn_topic': '1c7f587c4a1403966578e0bc3326f08fab3ad01d6c34b92e43af37a84ad98e38',
 'live_registration_validation_commitment': '68b469396d4e03e04091f15f1769d2f4bcb84918aa1c4a60549ce1728cd0531e',
 'live_version_migration_lease_selector': 'aaac4c97',
 'manifest_components_hash': '5bd86b4bfd5edcdd47c03ecfed7c198b292c14543cd36fae4b17340da2a8c040',
 'manifest_root': '417be737a57e38eb410f2d6e65c77ee19d5c314cdaf432067861c6a36c6a990f',
 'manifest_root_block_1': 'c58ab29bdccb3e06cc5431fbbcea1abc6d6f1a38120c5d896e18b7f1ca1cf43e',
 'mark_inbox_batch_calldata_hash': 'a6e34ddf755e1dbae1e15c05caaeba190795668ceaaff508b6a8537be236dd31',
 'mark_inbox_batch_selector': 'a92f72cd',
 'mark_migration_ready_magic': '4d524459',
 'mark_migration_ready_selector': 'e0c25827',
 'market_authority_configuration_hash': 'a1208db2d56b741c49ef2c81590172f3b6cf8df6462bdc55511b5d867a258d35',
 'maximum_genesis_activation_calldata_hash': '0f6f5587d90d0fa4dcb58c91f235246c1c3ba570e032e25c162bcc4b9610322e',
 'maximum_genesis_activation_calldata_length': '135844',
 'maximum_live_version_migration_seconds': '604800',
 'maximum_migration_proof_bytes': '131072',
 'maximum_version_activation_calldata_hash': '5c8e3968d6ad7e625ae370731bbfb691fb442c7f15757118cda6269842bd03fe',
 'maximum_version_activation_calldata_length': '149220',
 'message_invocation_hook_selector': '7f07c947',
 'message_v1_data_hash': 'f08683775f4a25dfef721c487073fb77026d45ac57e423424290e47af9fd2835',
 'message_v1_tuple_hash': '0e85a708462e96cbaca7158a1534011a25137c3b7aada7f381e4fc5b3afbe40d',
 'migration_activation_context_hash': '3873a3f2497d0112c2f5f264aa1b79543ab5647f8539bf46fb609c92032b5337',
 'migration_activation_context_return_hash': 'ee3341844bbb28d11b776e2c7b522022dd18969de50976eae7bc855cb0cd721f',
 'migration_activation_context_return_length': '320',
 'migration_activation_context_selector': '7cf70319',
 'migration_activation_profile_calldata_hash': '3dd403c33c2e7c4e6b324efac7461b5b0cc6f3696a2a8d8c94c9cb9bafcf9c85',
 'migration_activation_profile_magic': '4d505232',
 'migration_activation_profile_record_hash': 'd3d08370bbe36ceb6fade91f303d60bb7ae6b49029dc2ac734db6273ae088505',
 'migration_activation_profile_return_hash': '092aa880d8254032dfab09a85baf24a874caf97e04d2df9555f21e2f8b8de4f3',
 'migration_activation_profile_return_length': '768',
 'migration_activation_profile_selector': 'c65ff64e',
 'migration_adoption_commitment': '979cd5dd07672432be3768a6c57378f671d29bc8bed1f45b76c78dceed0855a7',
 'migration_arming_lifecycle_return_hash': '298524396c6b44dd68c8c21326e4ddb544cc51cfe8d5b89ed34bda45fa998753',
 'migration_data': '2c36740d76ae6192335d4c603f42edace094b33e8f54e959b40241a94c1f6deb',
 'migration_post_state_calldata_hash': '1143fe0083b3aaddd30e0ca1596ab8849d1dff7a71fc90454cb6b7f4c8df2b62',
 'migration_post_state_selector': '66e664cb',
 'migration_readiness_magic': '4d525331',
 'migration_readiness_selector': 'b36c83ce',
 'migration_transition_statement_typehash': '832785a7f9ce32f97dfa06fb39b9c583c13e65a5967c88f7c8c3fbda94fcef2b',
 'migration_verifier_config_getter_selector': '476b9aef',
 'migration_verifier_config_typehash': '0acb8f9e39dd43a4208edc38c8925bbd3433e72eb46f9e5fac584bd14a970b98',
 'migration_verifier_configuration_hash': '950691bac22ceef2dd834142420a79e589bc489165cb10815e889475c39d2613',
 'migration_verifier_descriptor_hash': 'ba4e50bfb5fabf8cd253f48ed38e4cc1a4f3fc04174ae94e4dd971b1d6e36eed',
 'migration_verifier_descriptor_typehash': '6f1be44c261607b4c2345985bfb5a081aabd621b9168982df9b7820c7dedebd6',
 'mmr_root_2': 'd20459aeb2fe916a18dd584d39b2ae25075c6b6c14104d9d64a8b1d7882eb4df',
 'normal_context': '5b93691b397d8ab377682acee7cf6cc77ff2726cd83a8a7b725084f5d6f468bd',
 'normalized_message_hash': 'f3010702b7b7bf10b6dbfe396a4c7ab07e7c560c28ffdbf6ff8d01d9a96ea4c7',
 'normalized_message_hash_preimage_length': '576',
 'normalized_message_return_hash': '9ae2f743a618dd71137457bbc5ce7a13bbd143fef8b1c70bb38508c0fcad7e17',
 'permissionless_abort_expired_migration_selector': 'ea3e96c2',
 'pool_accounting_calldata_hash': '354fc0013d46832830b1dff0379be91bf1b0060a34ce0b17d614f5065b61610e',
 'pool_accounting_magic': '504c4132',
 'pool_accounting_return_hash': 'fe5f0b1458dd3e41701c675116f35fa1a527569daa205b7be7a86457ed8014cf',
 'pool_accounting_selector': 'f2b3441e',
 'pool_attempt_authorization': '463e75e0954c32178675c0fb5e74427a069ec1eee06f0cf93caa6ca9e1925cef',
 'pool_auth_cleanup_gas': '50000',
 'pool_bridge_attempt_calldata_hash': 'a8a7b0c80117a3d96b2323365c06b655f62b39896e7b8bfc95c545e2b4541dd8',
 'pool_bridge_attempt_calldata_length': '1124',
 'pool_bridge_attempt_selector': 'a535a986',
 'pool_bridge_result_magic': '4c415632',
 'pool_bridge_result_return_hash': '36f4752069768edab1861fc87d8c4790fe8e6b81a095222ca5db748405380886',
 'pool_component_configuration_hash': '680054a7895708487ddd24a202ddf1069f2ef81238e909e826c368d1da396881',
 'pool_consume_calldata_hash': 'd34028acd39fb3a18d4799e5df98bd7697878d9cca21892aa14be7c5277b2483',
 'pool_consume_return_hash': '45e57d13eb0e9644c2d8c552e4f7c7d66bb0a4acd9e4862195bcabc68d5d9af6',
 'pool_consume_selector': '37093d2a',
 'pool_deposit_calldata_hash': '35c6d5e52bfa1f1d559b5061bb71be2155e607456b1e4242e400d398aaa3e180',
 'pool_deposit_return_hash': '7ba7804bc6c4c0cde5e2b1c55e724cc9e14b664c02eeb19db225db96f859c64e',
 'pool_deposit_selector': 'eda2a3f6',
 'pool_external_read_gas': '50000',
 'pool_process_calldata_hash': '67fd12a53168934d5c356c6e80b057b21b115967e032db4db3d619fb2b38bddc',
 'pool_process_calldata_length': '1028',
 'pool_process_selector': '5fbbe107',
 'pool_retry_calldata_hash': '1bbc3788d518e18333bae474d0677fab5f29fadc8b04a6a874d87b2575359a6b',
 'pool_retry_calldata_length': '1060',
 'pool_retry_selector': '031f93e7',
 'pool_row_substitution_infrastructure_hash': '777cd2fcbfad2cb6bba1046b82350d5f38af4e8940791a3775f108d184e1478c',
 'pool_ticket_calldata_hash': '7f489c048d7a27a5fe4624ac37cacdef2ae1ba1ba08d68471ad5e00dd7c47dfe',
 'pool_ticket_return_hash': '4cb85eb7ea2f272ca7a4d558694de56d4e9d2455a7cd3074c442c849213a9c31',
 'pool_ticket_selector': '5defa7e1',
 'pool_value_acceptance_commitment': '187074e8fe244fb77a42ac949f53e39cfe8bb151018109b8fc8f846c11e82d7d',
 'pool_value_callback_calldata_hash': 'e7510f93677daa354f44b1eae44af52ea01bf687af3933a71694cac0e600e2d4',
 'pool_value_callback_gas': '100000',
 'pool_value_callback_return_hash': '632cf02c0c8f06fd37a4ea096b77ae3cb51bbcd26f7920bb0bd053c5b0df10e2',
 'pool_value_callback_selector': 'a34908bb',
 'pool_value_magic': '4e4c5632',
 'pool_withdraw_calldata_hash': '6a23d1194b26c434dd47e8b8559a55f7b8c5e93bb7dc575588dae27cf6f60815',
 'pool_withdraw_return_hash': '405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace',
 'pool_withdraw_selector': 'fe4f5ccf',
 'profile_ingress_authorization_magic': '50494132',
 'profile_ingress_authorization_one_return_hash': '39491a71b47c4467196bca20f1f45f6c59be18480872cc9be2c69dfa702b4439',
 'profile_ingress_authorization_selector': '2181b974',
 'profile_ingress_authorization_zero_return_hash': '70b9c601b2d1f2852d14603d001ba507657f2eb32b0be8a38a986b4670c1873f',
 'profile_ingress_root_magic': '50495232',
 'profile_ingress_root_return_hash': '2cd5d7e58025a0c6283ae35b1090b0014f3a2640508ac28aca6109e95d893443',
 'profile_ingress_root_selector': '2d2bbe23',
 'protocol_apply_magic': '50415031',
 'protocol_apply_return_hash': 'f9361bdc99345939494c4794891942dafae95fa74ace38bcf4430ae53ac12c4a',
 'protocol_authority_read_gas': '100000',
 'protocol_change_delay_seconds': '604800',
 'protocol_change_operation_calldata_hash': '6247e74d2805dc8a531a1f1fc65b5d115dbc23baf9fb5812daf6a00d8e8fcea5',
 'protocol_change_operation_domain_hash': 'edc1be882290e6241a79546c41db66a1d975095ae60cf3b2b16f1ed876f6038b',
 'protocol_change_operation_magic': '50434f31',
 'protocol_change_operation_return_hash': 'aa46948d3f599dbb6034dfc5a39a01232791469392b2ef9981d7bd8d6611658e',
 'protocol_change_operation_selector': '4b80fe68',
 'protocol_change_timelock_config_magic': '50435431',
 'protocol_change_timelock_config_return_hash': '1813d922f5db2c6e82ca7be236e9cab4b8ca3c8b5f32231d60bd51b75e54b29c',
 'protocol_change_timelock_config_selector': 'b80095ca',
 'protocol_version_manager_config_magic': '50564d31',
 'protocol_version_manager_config_return_hash': '885cb456c37e6cd3eed4ab99af4ab704de544acd7ff014afa7c7683b7b652867',
 'protocol_version_manager_config_selector': '4deb7821',
 'protocol_version_manager_configuration_hash': 'f3d5898df7a23a84ed206deaf2038ad7fe52617f83df5ba2b8c5c4ecded7c2ad',
 'protocol_version_manager_descriptor_hash': '978f5d8ed5fa1d2e147bc26db6bfa3e11cca7ab234bf97a58c6892c63b00e4b6',
 'publish_genesis_campaign_operation_id': 'dabc210827740f6a5a2e02f0fcb40efc6b601165eb79876242505039296fbe94',
 'publish_genesis_campaign_payload_hash': 'ece311c62026f47db05309a2cebc937be659569c1f0c2172002da3075b380a2c',
 'publish_genesis_campaign_payload_length': '320',
 'publish_legacy_genesis_campaign_calldata_hash': 'b9a9831430cb2c6b82e820d5c290a806c26b456d1d8ec3f63d55e479ab3773e2',
 'publish_legacy_genesis_campaign_return_hash': '0367719a40e4be9f3cd78a96be149739f6700d1af4aee3273a7385e70a885f12',
 'publish_legacy_genesis_campaign_selector': '5f0ed7f5',
 'publish_migration_arm_operation_id': '59dd79759d954f74fc6c3c080a2b1838cd4392409cd196b7d1d666bbe9773a55',
 'publish_migration_arm_payload_hash': '49a908fa34da7bd43785ca7672208fbf262f162970c2490c05132b101465d8de',
 'publish_migration_arm_payload_length': '128',
 'pvm_router_mutation_gas': '8000000',
 'queue_migration_calldata_hash': '8a00ae30412e1f78da5a954be3303ec5dc311a54b894bdeea84fcbfc12918092',
 'queue_migration_calldata_length': '260',
 'queue_migration_credited_wei': '64000000000000000',
 'queue_migration_post_state_commitment': '1793a94b819a4330840685a6e379d413ba1f81219208984183c7e66c40d0a87c',
 'queue_migration_return_hash': '7fd65dcf44a26374708e64e3fced62b809bf70d01f104dc2cc71a7ea89e514d5',
 'queue_migration_selector': '9461f698',
 'queue_post_state_return_hash': 'bf63de5734b2b7980e64a5fc6da9f271ca4b2e68bc60df01c359f311448b2081',
 'queue_protocol_change_calldata_hash': '6a50ce249c8152fd61fd19fb02c93855949753183da138707002bbef8a3d8cc2',
 'queue_protocol_change_calldata_length': '10500',
 'queue_protocol_change_selector': 'bd5c80a8',
 'queued_return_hash': '76f821bd39721ec0e26efc55d7b667d20aab74992e0feae7d7755e386ecd694d',
 'recovery_id': 'fd0552b28542fa3e236c86807695f3d5a4bc0436add285daa8506d9a79511b15',
 'register_fork_verifier_operation_id': '6f3f09d83e85bf28f62fe18b37ac3abd378c8d03e1a5bffe67fc2e59540d4aeb',
 'register_fork_verifier_payload_hash': '060a82d25adb79cdf6382c783964efced57515aa1a1a7e79cde651e9ab190c00',
 'register_fork_verifier_payload_length': '448',
 'register_release_operation_id': '17c319270d7323aadd9e53315a63b2abb9df1292e6bc5fd70f05f937122aa8bb',
 'register_release_payload_hash': '3585c0dcb7691e9894921577646de9c71a166291be7d81f959c90a3cd9783ab9',
 'register_release_payload_length': '10400',
 'register_release_profile_bytes_hash': '2b4176a0142b3df849c56d4aa8a31c4b1c185f296a3229b5ef50398bd89e2d1c',
 'register_target_release_calldata_hash': 'eb1a079b1ffe45e57b02592b9d43dd9af89f4a0f6d4ca7410be087ad0109a22d',
 'register_target_release_calldata_length': '10404',
 'register_target_release_return_hash': 'be7b7db605e7d7c2d7c3edf06e009de1f61f3bae0ec006ebc5a83a685f38ec1d',
 'register_target_release_selector': '9aa71eff',
 'registration_commitment_base_slot': '20b3dfc457e3cecf32b0c047177351f0814e426c1548e87b79f58830655810c3',
 'registration_commitment_slot': 'dfa6283b763bbadeb604401a78e2fefeddb72000addcdb94ed2e3de5cc69846b',
 'registration_commitment_trie_key': '200031adff46d90b1cd5c67ff8e31098235d1dddb08ec98b0d20f5f8660c0ac8',
 'registration_config_getter_return': 'b266045c553f010d052a847ea18459bb268cbaacde008574e8cf4c738453911f',
 'registration_mpt_proof_schema_hash': '50ac70c83c4d85e9e0790d2413e35216b0c490814ee435879d0ce27e4a12e5e5',
 'registration_mpt_verifier_config_getter_selector': '59bfe418',
 'registration_mpt_verifier_config_typehash': '38f7fbc63e45f650bd5cbaffba0d81d5ca69f21ebdddfa74280d7e6eb5c319d6',
 'registration_mpt_verifier_configuration_hash': 'b266045c553f010d052a847ea18459bb268cbaacde008574e8cf4c738453911f',
 'registration_mpt_verifier_descriptor_hash': '99491cce6d0ea603e0b9862bd3a2509953ea05e50e9243f8086a19aa92b2f1bf',
 'registration_mpt_verifier_descriptor_typehash': '9533e2f6ac9bcf6830306a9ef5d14e21a06008f9ceb59208d09a8d7ab1e6100f',
 'registration_route_key': 'bd990f329adf106b96b5a019ad0db50503a1ebb0dd89bfdb9c37a3449f180b92',
 'registration_route_key_typehash': '4368ad9403b46ef3830e21af8cddcaedbd444c8c57bc3414ebc6fdd250e1e6da',
 'registration_storage_statement_hash': '85a07af10316e3a897e6abfc727b59a28dcfc76ee9894db98def647fa379c89d',
 'registration_storage_statement_typehash': 'c049f967468e58f1a5c9b9e1a147dfc233695ae69c5d4a95ec4ffb49b5687da0',
 'registration_verifier_return': '85a07af10316e3a897e6abfc727b59a28dcfc76ee9894db98def647fa379c89d',
 'registry_root': '0bf297d7b9b6a5529a319a06cb08484923a89bab15d51f8baeaf5c30bebdf3fd',
 'release_manifest_base_slot': 'a0b7a29a75032f37561036cd3741e7b375213309367f37b5ffec4ad55cf6154f',
 'release_manifest_hash': '59f4cfe5830d3620fc3f33f0890d0a6f0a10bc313bb08b8158a5c1ef318087ed',
 'release_manifest_slot': '719bb73ba856aeab1b203e322bfefc6d84a4c41a3222bcf1634b1b44e5b9aba8',
 'release_manifest_trie_key': 'dac8109059d03da2ad16ac3acc50d2e58897b8c3a7f6889ae77bfb20737e87a2',
 'release_manifest_typehash': '603555ff1d82bc9012b0e0c8a36df28e154b16cbd89be4eed9d01228c502965b',
 'reorg_genesis_activation_context_hash': 'ecc3841b57a7ca17da647379ad6cd73561bca5dee084d8755afcc7027d632b22',
 'reorg_genesis_activation_receipt_id': '053301fdcf9c3d44895d885890694c29f258cf743d9167a4a4f343161a1871f9',
 'reorg_genesis_post_state_commitment': '0f299dfa5e42d5075db83e4eb1b004cf7c33b63afba8513d02134d74be44d54f',
 'route_config_getter_selector': '4b64fa11',
 'schedule_carrier_return_hash': '3e7028adb7b81c521979a0024999718518559b1ddec5cde8e3a9379d6cef3125',
 'schedule_carrier_statement_hash': 'e5e7ef6967d544c41242fd48103d1a53c28f1d6da31a1649d34f4bd11025e123',
 'schedule_fork_carrier_magic': '53464331',
 'schedule_fork_constants_hash': 'c17afdd5367849af551b3a2f322a2c351321e916ad913a78b646586fe34f59fc',
 'schedule_fork_output_schema_hash': '3a480130319b3cebce02d217988e89c83c6bd6e71ff93c25bc4fc38e51fbe2c0',
 'schedule_fork_verifier_config_magic': '53465631',
 'schedule_fork_verifier_config_return_hash': '876e1109f517610df01f9c613f669d68ca2390fbee92c41b63e7a9a65a1924da',
 'schedule_fork_verifier_config_selector': '44efa773',
 'schedule_fork_verifier_configuration_hash': '95d9108bef4bb1eb4d6b63a79b04aecffcb7f8405b82cb22883c28dda04bb802',
 'schedule_list': '7ab789362dd8b411e1bc42af1270bcb14d2a7571fc28ab614c6afcc33b7de8e7',
 'seat_authority_read_gas': '100000',
 'seat_market_duty_selector': '9a649489',
 'seat_market_term_selector': '76d5ecd4',
 'seat_target_state_selector': 'cf52185b',
 'send_message_v2_calldata_hash': '9099cce58d3f36714ee59f37510261394e31583f8bd55da4551b653b5a060e12',
 'send_message_v2_calldata_length': '516',
 'send_message_v2_selector': '9211d7e9',
 'session_accounting_selector': 'e2a62969',
 'session_bond_claimed_topic': '69fe7d8d95811e3a02a4ad4b0d1a3e1360b683a31f7cb30b4c69546b258232fb',
 'session_by_id_selector': 'eeaad0bb',
 'session_cell_selector': '011efada',
 'session_claim_selector': 'fdd2b0db',
 'session_id': '98cbb8b158cb6732a806e2fac0e50c53e88feafd5e3dade0a0ed7edeb7a5a0b1',
 'session_list': '9cbf4ca60afc8aee2ccaa68a45bb6568a04812cf282aa703f194e017092fb264',
 'session_live_to_refund_topic': '086de7ad4d27cf66f63e9dc6ecb09c0c3122146dd43e7f480f3a875070eb984e',
 'session_maintain_selector': '1e7a916a',
 'session_open_selector': '7bda4d11',
 'session_opened_topic': 'a81132592bd8a549a0bfc83415ab47fbca586f0b48fff5f6cb5bfae0a9fd1f68',
 'session_post_selector': 'a1cc526a',
 'session_refund_forfeited_topic': 'f93f771339298d1fb502bd2c556fc18130b95d44599f35109de39d8d5731f957',
 'session_seal_selector': '340e11fb',
 'session_sealed_topic': 'f6d45ab0ecc3348b36ac48bc769f7391962fc2fa240c1c6bb43269ed3780078e',
 'session_surplus_swept_topic': '3a5f2fa0ab342d3b79fc2aa40be5e1296009e8fb31f86c3577c51839dd159a86',
 'session_sweep_selector': '9d083a2b',
 'settlement_authorization_getter_magic': '53415431',
 'settlement_authorization_id': '3996cb4bbeea670aa365269a1e4ad9dbddd171df2accf9f159c8063de75827a3',
 'settlement_authorization_install_magic': '53414931',
 'settlement_authorization_return_hash': '94b1dab2989ce801bf528219ef887c06541cecdbe87dbaf48acc9923655f4c32',
 'settlement_authorization_selector': '1693ae01',
 'settlement_deployment_descriptor_abi_hash': '46ed5ccd834b950444afe9731c8200361ee3a85b0b7661b87a29ea163c9f93ea',
 'settlement_deployment_descriptor_abi_length': '256',
 'settlement_deployment_descriptor_hash': '069af1541b5e7a6e6ee981274ca23dc30a2340e9d673e0c2752448877399b441',
 'settlement_factory_configuration_hash': '4bf4831c096e251d0ef171bc0fd0582319fdc7ad7a2bea91a6b9b64601aa2837',
 'settlement_factory_deploy_selector': '4af63f02',
 'settlement_tuple_substitution_terminal_leaf': 'bf20404f65a3471b2d10c0a93fd1e75ca365d2a202ff6a804a7dd7b3884af523',
 'source_bridge_config_getter_return': '7f8e990ebe1154e101998d40cbff22336f4a7f1d70f13d0c2af5235ea47ffa0e',
 'source_bridge_descriptor_length': '752',
 'source_context_hash': '5d7181ea8838cef6d576009cd977bbe2b6f0fd250d16d4f331a515b174bee2c0',
 'source_context_typehash': '6069dff5f628f94ceff984d5ce3ef62019eaeb4efd7e0627c45a14677bd13c70',
 'source_credit_read_gas_limit': '200000',
 'source_domain_id': '10f186337be2d4748ed71ae3965a781bd05036107aa1e058e107b2e7f4b1332b',
 'source_factory_config_getter_return': '79427a3d5c086eb2dd847fa1bfdacb7a604dd5d5fe272b32abf56169fcde9e9d',
 'source_freeze_post_state_commitment': 'f6cefc65013868fabdd502d608dfbc556d77ec3729647e05d7e72d42985e6bfc',
 'source_post_state_return_hash': 'c6b77ff997504e3da70d75aaa00c1c571573082e8c1ca4eb1ea552fd2b696898',
 'source_quota_config_getter_return': '09d21b4d09dadaabdb05c5b8c88db22757c4de82b7a3ebc1a6910606fe36ff0c',
 'source_registry_config_getter_return': '81d538ec2bf4cf246008838e0908d61eff83a01740a58abec23d7aa573087ee1',
 'source_support_registry_config_getter_return': 'c8beb33d334a9cf76d329ab18cb3b197276e878c5b5a54397c6f0e5c41904b0d',
 'source_terminal_verifier_config_getter_return': 'c7297de84fb29fa53cf5f96d02a6254e970e20ac10991766cb58b4981485290f',
 'statement_hash': '0223b45e5752d4ca03f59534e9c773481a390c46da8286b94927b4be8229b991',
 'status_return_hash': 'b39221ace053465ec3453ce2b36430bd138b997ecea25c1043da0c366812b828',
 'successor_migration_activation_profile_record_hash': '90e8e5b063bb8d9d670fcb0d1a07d8eb000a0e614cabe9ae88d9b2aa60a0391f',
 'successor_release_manifest_hash': 'a0a97cc0cd6dc54bbc07f52bacc7f4fcc3d349e0496754800864895ed6ae2b42',
 'successor_settlement_deployment_descriptor_hash': '377aa582c38874cf50ef87030c628b15c5e0302e6830e51b09d8542659bedc18',
 'successor_target_registration_hash': 'ba5b1a92c368645427501c5a1a17fc0c65df7f9862d3e7ea8544272569f51375',
 'sync_ingress_selector': '6c880b72',
 'sync_ingress_stamp_return_hash': '1fd01b194948c635358fbb51b4a5f32f8ceab4dc4153e0230215f8afc94ee434',
 'sync_ingress_synced_return_hash': 'ef662a629ce07c9ed715124d8141a6e430d0a3065f8ce8074a7ea95e8751f184',
 'target_call_failed_error_hash': '1e5dd0ffe211b83cfe975af6e5c84015b6cfae3a2135c70a7c42426b899a59ac',
 'target_call_failed_selector': 'f9cc2b44',
 'target_constructor_state_return_hash': '792365e22be230bc85de020399071020fd18355fae1625be85586dc429fb0e77',
 'target_constructor_state_selector': '654f7fce',
 'target_post_state_return_hash': '88c638b2c1aa55236cfb8e462651ea51d9fd55d14a61986b44af9c1b5e81260a',
 'target_registration_hash': 'e74c264997a32a867fa54d2948c5ca70bd79c2bc082b7aa33f0d660f3ab56fc4',
 'target_release_registration_calldata_hash': '5c5db1ed7485ad89b4d9125c80db863078603f32ddd3032552a6345bd0dba5ee',
 'target_release_registration_magic': '52545232',
 'target_release_registration_return_hash': 'dcd726cbaf9c71e1db52b4fb42d9522500f8d37885687c4df2c7184a9f26bad3',
 'target_release_registration_return_length': '384',
 'target_release_registration_selector': 'f588fec3',
 'terminal_append_return': '0000000000000000000000000000000000000000000000000000000000000002',
 'terminal_commitment_calldata_hash': '3325c0ac55e056cd36d9d1cd356f494fdb68a117961ebf6adc58690b6ab07dc3',
 'terminal_commitment_return_hash': 'ceeeed17fd0a2c95d1c49b05947c9f32a56e1f5e9d8a246dd55b3ad970752560',
 'terminal_commitment_selector': '2c984c97',
 'terminal_done_leaf': 'b24b3a75e604936efaf89218951ae097b2901b0aaa42c411f5cf9d6183e867f5',
 'terminal_failed_leaf': 'eb3a0ef753b87449dcc50b109f2f2f7d8405af7c43a1e55f4e0fad93d4756867',
 'terminal_root_2': '220a454b2a961a593546023497e32948752c63386a54085491c7fba5a6bec5a8',
 'terminal_state_return_hash': '3e3b1f39f0b0fc42adb4a6c15987dc52d6c0bac9497db88ab1b07b9fb96bfbcd',
 'terminal_state_selector': '998c57ed',
 'tranche_leaf': '80fce6c2421807d961f9207d30b439bd423c05e206a18021b93217513ecc5551',
 'typehash': 'ee6a8c8e31e8245cd527869508f6e464d6084893991203876f734d1855aed87c',
 'v11_bridge_descriptor': '2121212121212121212121212121212121212121212121212121212121212121000000000000000000000000000000000000000000000000000000000000000110f186337be2d4748ed71ae3965a781bd05036107aa1e058e107b2e7f4b1332b000000000000000719ed48aa17648c30ffbec0ddd91eb364c42bc904f9832b2fbef2ef60a0fc7a1420fe8ae745c3840c86f6c932b2818c201b6b5df1000000000000300cc5fa66479b2914cd0974c72102929ae9852311f9cb44d432b833a22692104af2000000000000000000000000000000000000000000000000000000000000419400000000000c35000000000000000000000000000000000000003333000000000000000000000000000000000000111100000000000000000000000000000000000022220000000000000000000000000000000000000000000000000de0b6b3a764000000000000000004d2000000000000162e22222222222222222222222222222222222222222222222222222222222222220100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cbb92e32149a19f26a3db755300df9f7d401fe51c4a7121b966ad77b598385d500000060000000000001d4c0000000000000000000000000000000000000beef00000000000002bc0000000000000898000000000000000000000000000000000000000000000000002386f26fc10000',
 'verify_inbox_credit_calldata_hash': '0c841b049e9e20e72d6e8a06f20aaf6c03e06b9dcbdb763d9e61c8a01a712027',
 'verify_inbox_credit_selector': '28933d28',
 'verify_registration_calldata_hash': 'ed003a9f0f69e694a6b3699efa64acd17acda445ff50a9dfb442c308dc4fdc55',
 'verify_registration_calldata_length': '516',
 'verify_registration_selector': '33639818',
 'verify_schedule_carrier_calldata_hash': 'a6f4b2260cd81afd71756624c295b886d29e85c0c9e9b1cdc89f0148bbd0fb79',
 'verify_schedule_carrier_calldata_length': '132',
 'verify_schedule_carrier_selector': '7e981e0b',
 'version_activation_calldata_hash': '56ebab6e19f1d9bfa240774f4271412d1922e540d6c68822648e853d477feca3',
 'version_activation_calldata_length': '17156',
 'version_activation_fixed_hash': '3c56ba661f3714e55644fb2ca1c83595efd27c20040727dba1efbbb564495308',
 'version_activation_receipt_return_hash': '25ed31f58de1cda586c28189c946c6aab9172c13218aea549edfcb25055b9336',
 'version_deployment_commitment': 'd6b1ce9a58632b12de3bf71d82c27b7d395ce72edb56734f2233570e84d5f91a',
 'version_migration_abort_after_timestamp': '624800',
 'version_migration_abort_magic': '564d4231',
 'version_migration_arm_id': '501b467e73f364446cd3e0ac98ace85bce64e88f97d25cb16c8bc92a294d99a8',
 'version_migration_arm_magic': '564d4131',
 'version_migration_lease_magic': '564d4c31',
 'version_migration_lease_return_hash': 'fdc598573486cc233fb6d7e730d6ef9c7ff92df5806684327d5cf3dd9a9d3bed',
 'version_migration_lease_return_length': '320',
 'version_migration_statement_hash': '760a32b760ea28beb032bb59d7f222e22350e8ae602cb5da3f961a3b69387db1',
 'winning_data': '4ae34aa9efb842528d353b175f94191d01cfd168b5ad828f64a0e7972a2ca9e3'}

if __name__ == "__main__":
    actual = vectors()
    if "UPDATE" in EXPECTED.values():
        for key, value in actual.items():
            print(f'    "{key}": "{value}",')
        raise SystemExit("populate EXPECTED with the vectors above")
    assert actual == EXPECTED
    assert keccak256(ACTIVATE_RELEASE_V2_SIGNATURE)[:4].hex() == "28f73572"
    payload = b"alpha" * 100
    blob = encode_blob_payload(payload)
    assert decode_blob_payload(blob) == payload

    # Negative queue properties: skip, reorder, boundary/count/root tampering.
    envs = tuple(ForcedEnvelope(1, i, 16_788, keccak256(u64(i)), 10, 21_000,
                                21_000, 1, 9_999, 2, 3, 4 + i, 5)
                 for i in range(70))
    leaves = tuple(forced_leaf(i, env) for i, env in enumerate(envs))
    vector = ForceVector(leaves)
    proof = vector.range_proof(2, 66)
    revealed = leaves[2:67]
    assert len(proof) <= 257
    singleton_proof = vector.range_proof(2, 2)
    assert len(singleton_proof) == FORCE_DEPTH
    assert verify_force_range(70, 2, leaves[2:3], singleton_proof, vector.root)
    assert not verify_force_range(
        70, 2, leaves[2:3], singleton_proof[:32], vector.root)
    assert verify_force_range(70, 2, revealed, proof, vector.root)
    assert not verify_force_range(70, 2, revealed[1:], proof, vector.root)
    assert not verify_force_range(70, 2, (revealed[1], revealed[0], *revealed[2:]), proof, vector.root)
    assert not verify_force_range(69, 2, revealed, proof, vector.root)
    assert not verify_force_range(70, 2, revealed, proof + (bytes(32),), vector.root)
    assert append_frontier_height(UINT64_MAX - 1) == 0
    descriptor_commitment = force_descriptor_list(
        2, tuple((0, forced_descriptor(envs[i])) for i in range(2, 66)),
        (0, forced_descriptor(envs[66])))
    assert descriptor_commitment != force_descriptor_list(
        2, tuple((0, forced_descriptor(envs[i])) for i in range(2, 66)), None)
    changed_boundary = replace(envs[66], byte_length=envs[66].byte_length + 1)
    assert descriptor_commitment != force_descriptor_list(
        2, tuple((0, forced_descriptor(envs[i])) for i in range(2, 66)),
        (0, forced_descriptor(changed_boundary)))

    raw_tx = b"raw-signed-tx"
    assert canonical_disposition(4, 2, keccak256(raw_tx), raw_tx)
    assert not canonical_disposition(4, 2, bytes.fromhex("44" * 32), raw_tx)
    assert canonical_disposition(0, UINT32_MAX, bytes(32))
    assert not canonical_disposition(0, 2, bytes(32))
    assert not canonical_disposition(6, UINT32_MAX, bytes(32))
    execution_hash = bytes.fromhex(actual["bridge_execution_hash"])
    source_bundle_deployer = create2_address(
        0xF123, bytes.fromhex("30" * 32), bytes.fromhex("31" * 32))
    source_bridge_address = create_address_from_nonce(source_bundle_deployer, 1)
    source_registry_address = create_address_from_nonce(source_bundle_deployer, 2)
    domain_r1 = source_domain_id(
        1, bytes.fromhex("25" * 32), source_registry_address, 0xD101,
        source_bridge_address,
        execution_hash, bytes.fromhex("26" * 32))
    destination_execution_hash = bytes.fromhex(
        actual["destination_bridge_execution_hash"])
    destination_domain = destination_domain_id(
        16_788, bytes.fromhex("35" * 32), 0xAD00, 0xAD01,
        0xD101, 0x5100, 0x5101, 0x5106, 0x5103, 0x5102, 0x5104, 0xB200,
        destination_execution_hash,
        bytes.fromhex(actual["destination_infrastructure_hash"]),
        bytes.fromhex("36" * 32))
    bridge_msg_hash = bytes.fromhex("21" * 32)
    liquidity_fee = 5_678
    bridge_credit = bridge_credit_id(
        1, domain_r1, 7, source_bridge_address, destination_domain,
        bridge_msg_hash,
        liquidity_fee)
    bridge = BridgeEnvelope(
        bridge_msg_hash, 1, domain_r1, 7, source_bridge_address,
        execution_hash,
        12_300, destination_domain, 16_788, 800_000,
        0x3333, 0x1111, 0x2222, 10**18, 1_234, liquidity_fee,
        bytes.fromhex("22" * 32), 1, 0, bytes(32),
        bridge_escrow_id(bridge_credit), 96, 120_000,
        0xBEEF, 700, 2_200, 10**16,
    )
    bridge_result = bridge_credit_result(70, bridge)
    assert canonical_disposition(5, UINT32_MAX, bridge_result,
                                 expected_bridge_result=bridge_result)
    assert not canonical_disposition(5, UINT32_MAX, bytes.fromhex("44" * 32),
                                     expected_bridge_result=bridge_result)
    rotated = replace(
        bridge, src_epoch=8, bridge_execution_hash=bytes.fromhex("33" * 32))
    assert bridge_leaf(70, rotated) != bridge_leaf(70, bridge)
    assert bridge_credit_result(70, rotated) != bridge_result
    changed_destination = replace(
        bridge, destination_domain_id=bytes.fromhex("34" * 32))
    assert (bridge_credit_id(
                changed_destination.src_chain_id,
                changed_destination.source_domain_id,
                changed_destination.src_epoch, changed_destination.src_bridge,
                changed_destination.destination_domain_id,
                changed_destination.msg_hash,
                changed_destination.liquidity_fee)
            != bridge_credit_id(
                bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
                bridge.src_bridge, bridge.destination_domain_id,
                bridge.msg_hash, bridge.liquidity_fee))
    changed_deadline = replace(bridge, enqueue_by=bridge.enqueue_by + 1)
    assert (bridge_leaf(70, changed_deadline) != bridge_leaf(70, bridge)
            and bridge_credit_result(70, changed_deadline) != bridge_result)
    changed_emission = replace(bridge, emitted_at_block=bridge.emitted_at_block + 1)
    assert (bridge_leaf(70, changed_emission) != bridge_leaf(70, bridge)
            and bridge_credit_result(70, changed_emission) != bridge_result)
    for changed_source_field in (
        replace(bridge, sender=bridge.sender + 1),
        replace(bridge, fee=bridge.fee + 1),
        replace(bridge, liquidity_fee=bridge.liquidity_fee + 1),
    ):
        assert (bridge_leaf(70, changed_source_field) != bridge_leaf(70, bridge)
                and bridge_credit_result(70, changed_source_field) != bridge_result)
    assert bridge_leaf(70, replace(
        bridge, liquidity_fee=bridge.liquidity_fee + 1)) \
        != bridge_leaf(70, bridge)
    changed_liquidity_fee_credit = bridge_credit_id(
        bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
        bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash,
        bridge.liquidity_fee + 1)
    assert changed_liquidity_fee_credit != bridge_credit
    for invalid_direct_projection in (
        replace(bridge, refund_mode=2),
        replace(bridge, refund_vault=0x4444),
        replace(bridge, refund_capsule_hash=bytes.fromhex("24" * 32)),
    ):
        try:
            bridge_leaf(70, invalid_direct_projection)
            raise AssertionError("non-DIRECT V11 projection accepted")
        except AssertionError as error:
            assert str(error) != "non-DIRECT V11 projection accepted"
    pins: dict[bytes, bytes] = {}
    assert pin_inbox_credit(pins, bridge.src_chain_id, bridge.source_domain_id,
                            bridge.src_epoch, bridge.src_bridge,
                            bridge.destination_domain_id,
                            bridge.msg_hash, bridge.liquidity_fee, bridge_result)
    assert pin_inbox_credit(pins, bridge.src_chain_id, bridge.source_domain_id,
                            bridge.src_epoch, bridge.src_bridge,
                            bridge.destination_domain_id,
                            bridge.msg_hash, bridge.liquidity_fee, bridge_result)
    rotated_result = bridge_credit_result(71, rotated)
    assert pin_inbox_credit(pins, rotated.src_chain_id, rotated.source_domain_id,
                            rotated.src_epoch, rotated.src_bridge,
                            rotated.destination_domain_id,
                            rotated.msg_hash, rotated.liquidity_fee, rotated_result)
    batch_rows = (
        (70, bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
         bridge.src_bridge, bridge.destination_domain_id,
         bridge.msg_hash, bridge.liquidity_fee, bridge_result),
        (71, rotated.src_chain_id, rotated.source_domain_id, rotated.src_epoch,
         rotated.src_bridge, rotated.destination_domain_id,
         rotated.msg_hash, rotated.liquidity_fee, rotated_result),
    )
    batch_store: dict[bytes, bytes] = {}
    assert pin_inbox_credit_batch(batch_store, batch_rows) and len(batch_store) == 2
    batch_snapshot = dict(batch_store)
    conflicting_rows = (batch_rows[0], (*batch_rows[1][:-1], bytes.fromhex("44" * 32)))
    assert (not pin_inbox_credit_batch(batch_store, tuple(reversed(batch_rows)))
            and batch_store == batch_snapshot
            and not pin_inbox_credit_batch(batch_store, conflicting_rows)
            and batch_store == batch_snapshot)
    assert not pin_inbox_credit(pins, bridge.src_chain_id, bridge.source_domain_id,
                                bridge.src_epoch, bridge.src_bridge,
                                bridge.destination_domain_id, bridge.msg_hash,
                                bridge.liquidity_fee, bytes.fromhex("44" * 32))
    bridge_credit = bridge_credit_id(
        bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
        bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash,
        bridge.liquidity_fee)
    assert pins[inbox_credit_slot(
        bridge.source_domain_id, bridge.src_bridge,
        bridge.destination_domain_id, bridge_credit)] == bridge_result
    reused = replace(bridge, src_epoch=9)
    reused_result = bridge_credit_result(72, reused)
    assert bridge_credit_id(reused.src_chain_id, reused.source_domain_id, reused.src_epoch,
                            reused.src_bridge, reused.destination_domain_id,
                            reused.msg_hash, reused.liquidity_fee) != bridge_credit_id(
                                bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
                                bridge.src_bridge, bridge.destination_domain_id,
                                bridge.msg_hash, bridge.liquidity_fee)
    assert pin_inbox_credit(pins, reused.src_chain_id, reused.source_domain_id,
                            reused.src_epoch,
                            reused.src_bridge, reused.destination_domain_id,
                            reused.msg_hash, reused.liquidity_fee, reused_result)
    domain_r2 = source_domain_id(
        1, bytes.fromhex("25" * 32), 0xD004, 0xD101,
        source_bridge_address,
        execution_hash, bytes.fromhex("27" * 32))
    replacement_registry = replace(
        bridge, source_domain_id=domain_r2, src_epoch=7,
        src_bridge=source_bridge_address)
    replacement_result = bridge_credit_result(73, replacement_registry)
    assert bridge_credit_id(
        replacement_registry.src_chain_id, replacement_registry.source_domain_id,
        replacement_registry.src_epoch, replacement_registry.src_bridge,
        replacement_registry.destination_domain_id,
        replacement_registry.msg_hash,
        replacement_registry.liquidity_fee) != bridge_credit_id(
            bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
            bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash,
            bridge.liquidity_fee)
    assert pin_inbox_credit(
        pins, replacement_registry.src_chain_id,
        replacement_registry.source_domain_id, replacement_registry.src_epoch,
        replacement_registry.src_bridge,
        replacement_registry.destination_domain_id,
        replacement_registry.msg_hash, replacement_registry.liquidity_fee,
        replacement_result)
    assert len(pins) == 4

    done_leaf = bytes.fromhex(actual["terminal_done_leaf"])
    failed_leaf = bytes.fromhex(actual["terminal_failed_leaf"])
    terminal_vector = TerminalVector((done_leaf, failed_leaf))
    terminal_frontier = tuple(bytes(32) for _ in range(TERMINAL_DEPTH))
    terminal_frontier = append_fixed_frontier(
        terminal_frontier, 0, done_leaf, D_TERMINAL_NODE)
    terminal_frontier = append_fixed_frontier(
        terminal_frontier, 1, failed_leaf, D_TERMINAL_NODE)
    assert terminal_frontier_root(terminal_frontier, 2) == terminal_vector.root
    stale_terminal_frontier = list(terminal_frontier)
    stale_terminal_frontier[0] = bytes.fromhex("ef" * 32)
    assert terminal_frontier_root(tuple(stale_terminal_frontier), 2) \
        == terminal_vector.root
    used_terminal_frontier = list(terminal_frontier)
    used_terminal_frontier[1] = bytes.fromhex("fe" * 32)
    assert terminal_frontier_root(tuple(used_terminal_frontier), 2) \
        != terminal_vector.root
    done_proof = terminal_vector.proof(0)
    assert terminal_vector.root.hex() == actual["terminal_root_2"]
    settlement_hash = liquidity_settlement_hash(
        bytes.fromhex("45" * 32), 0x7777, 10**18 + 1_234)
    assert settlement_hash.hex() == actual["liquidity_settlement_hash"]
    changed_settlement_leaf = terminal_leaf(
        0, destination_domain, 0xB200, bridge_credit, 1,
        liquidity_settlement_hash(
            bytes.fromhex("45" * 32), 0x7777, 10**18 + 1_235))
    assert changed_settlement_leaf != done_leaf
    assert verify_terminal_proof(
        2, 0, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 0, failed_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 0, changed_settlement_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 1, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        3, 0, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 0, done_leaf, done_proof[:-1], terminal_vector.root)

    persistent_terminal = PersistentTerminalTree()
    assert persistent_terminal.append(done_leaf) == 0
    first_root = persistent_terminal.root
    assert persistent_terminal.append(failed_leaf) == 1
    current_done_proof = persistent_terminal.proof(0)
    historical_done_proof = persistent_terminal.proof_at(1, 0)
    assert (persistent_terminal.root == terminal_vector.root
            and current_done_proof == done_proof
            and verify_terminal_proof(
                persistent_terminal.count, 0, done_leaf,
                current_done_proof, persistent_terminal.root)
            and verify_terminal_proof(
                1, 0, done_leaf, historical_done_proof, first_root)
            and first_root != persistent_terminal.root
            and len(persistent_terminal.completed_nodes)
                < 2 * persistent_terminal.count)

    bridge_kernel = bridge_kernel_profile_hash(
        bytes.fromhex("2a" * 32), bytes.fromhex("2b" * 32),
        bytes.fromhex("2c" * 32))
    descriptor = fixture_source_bridge_descriptor(
        bridge_kernel, fixture_destination_components()[2])
    assert bridge_kernel.hex() == actual["bridge_kernel_profile_hash"]
    assert bridge_kernel != bridge_kernel_profile_hash(
        bytes.fromhex("2d" * 32), bytes.fromhex("2b" * 32),
        bytes.fromhex("2c" * 32))
    assert (COMPONENT_CONFIG_GETTER_SELECTOR.hex() == "f6c0f7d2"
            and CREDIT_AUTHORIZATION_V2_SELECTOR.hex() == "05ecb6c2"
            and CREDIT_LIABILITY_V2_SELECTOR.hex() == "c978978a"
            and create_address_from_nonce(descriptor.bundle_deployer, 1)
                == descriptor.source_bridge
            and create_address_from_nonce(descriptor.bundle_deployer, 2)
                == descriptor.credit_registry
            and create_address_from_nonce(descriptor.bundle_deployer, 3)
                == descriptor.quota_manager)
    for invalid_nonce in (0, 4):
        assert_rejects(
            lambda nonce=invalid_nonce:
                create_address_from_nonce(descriptor.bundle_deployer, nonce),
            "noncanonical atomic-bundle CREATE nonce accepted")
    for invalid_descriptor in (
        replace(descriptor, bundle_deployer=0),
        replace(descriptor, source_bridge=0),
        replace(descriptor, credit_registry=0),
        replace(descriptor, terminal_verifier=0),
        replace(descriptor, bundle_deployer_runtime_hash=bytes(32)),
        replace(descriptor, bridge_runtime_hash=bytes(32)),
        replace(descriptor, storage_layout_hash=bytes(32)),
        replace(descriptor, support_registry_runtime_hash=bytes(32)),
        replace(descriptor, support_registry_configuration_hash=bytes(32)),
        replace(descriptor, bridge_kernel_profile_hash=bytes(32)),
    ):
        try:
            canonical_source_bridge_descriptor(invalid_descriptor)
            raise AssertionError("invalid source bridge descriptor accepted")
        except AssertionError as error:
            assert str(error) != "invalid source bridge descriptor accepted"

    components = fixture_destination_components()
    destination_descriptor = DestinationBridgeDescriptor(
        0xB200, components[9].runtime_hash, components[9].config_hash,
        bytes.fromhex("42" * 32), bridge_kernel,
        0x5101, 0x5102, 0x5103, 0x5107, 0x5104)
    for changed_destination_descriptor in (
        replace(destination_descriptor, bridge=0xB201),
        replace(destination_descriptor,
                runtime_hash=bytes.fromhex("5a" * 32)),
        replace(destination_descriptor,
                configuration_hash=bytes.fromhex("5b" * 32)),
        replace(destination_descriptor, inbox_credit_store=0x5111),
        replace(destination_descriptor, terminal_accumulator=0x5112),
        replace(destination_descriptor, terminal_domain_registrar=0x5113),
        replace(destination_descriptor, quota_manager=0x5114),
        replace(destination_descriptor, native_liquidity_pool=0x5115),
    ):
        assert (destination_bridge_execution_hash(changed_destination_descriptor)
                != destination_bridge_execution_hash(destination_descriptor))

    infrastructure = destination_infrastructure_hash(components)
    try:
        destination_bridge_component_config(
            bytes.fromhex("42" * 32), bridge_kernel,
            0x5101, 0x5102, 0x5103, 0x5107, 0)
        raise AssertionError("zero Bridge Pool binding accepted")
    except AssertionError as error:
        assert str(error) != "zero Bridge Pool binding accepted"
    assert destination_infrastructure_hash(tuple(reversed(components))) != infrastructure
    assert destination_infrastructure_hash(
        (replace(components[0], runtime_hash=bytes.fromhex("61" * 32)),
         *components[1:])) != infrastructure
    assert destination_infrastructure_hash(
        (replace(components[0], config_hash=bytes.fromhex("62" * 32)),
         *components[1:])) != infrastructure
    pool_row_substitution = destination_infrastructure_hash((
        *components[:8],
        replace(components[8], config_hash=bytes.fromhex("6c" * 32)),
        components[9],
    ))
    assert pool_row_substitution != infrastructure

    migration_verifier = MigrationVerifierDescriptor(
        0x6001, bytes.fromhex("71" * 32), bytes(32),
        bytes.fromhex("72" * 32), bytes.fromhex("73" * 32),
        MIGRATION_TRANSITION_STATEMENT_TYPEHASH,
        keccak256(b"verifyMigrationTransition(bytes,uint256[2])")[:4],
        131_072, 4_000_000)
    migration_verifier = replace(
        migration_verifier,
        configuration_hash=_migration_verifier_configuration_hash(
            migration_verifier))
    assert MIGRATION_VERIFIER_CONFIG_TYPEHASH.hex() \
        == actual["migration_verifier_config_typehash"]
    assert migration_verifier_configuration_hash(migration_verifier).hex() \
        == actual["migration_verifier_configuration_hash"]
    assert MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH.hex() \
        == actual["migration_verifier_descriptor_typehash"]
    assert MIGRATION_VERIFIER_CONFIG_GETTER_SELECTOR.hex() \
        == actual["migration_verifier_config_getter_selector"]

    strict_authority = derive_register_release_authority_v2(
        canonical_execution_profile_cross_model_fixture_v2(), 0)
    release_manifest = strict_authority.release_manifest
    components = strict_authority.destination_components
    destination_descriptor = strict_authority.destination_bridge_descriptor
    infrastructure = strict_authority.destination_infrastructure_hash
    destination_domain = strict_authority.destination_domain_id
    assert execution_profile_dependency_keys_valid((
        "manifestSchemaVersion", "protocolVersionManager",
        "protocolReleaseAuthority", "terminalDomainRegistrar",
        "manifestNamespace", "destinationNamespace", "activationRules"))
    assert not execution_profile_dependency_keys_valid((
        "manifestSchemaVersion", "releaseManifestHash"))
    assert not execution_profile_dependency_keys_valid((
        "registrationCommitment", "activationRules"))
    assert not execution_profile_dependency_keys_valid((
        "manifestSchemaVersion", "manifestSchemaVersion"))
    release_hash = release_manifest_hash(release_manifest)
    assert len(canonical_release_manifest(release_manifest)) == 1_856
    assert 4 + len(canonical_release_manifest(release_manifest)) + 32 == 1_892
    for changed_manifest in (
        replace(release_manifest, protocol_version=3),
        replace(release_manifest, settlement_chain_id=2),
        replace(release_manifest, destination_chain_id=16_789),
        replace(release_manifest,
                destination_genesis_hash=bytes.fromhex("37" * 32)),
        replace(release_manifest,
                execution_profile_hash=bytes.fromhex("fd" * 32)),
        replace(release_manifest,
                manifest_namespace=bytes.fromhex("38" * 32)),
        replace(release_manifest, anchor=0xA005),
        replace(release_manifest,
                anchor_runtime_hash=bytes.fromhex("a5" * 32)),
        replace(release_manifest,
                migration_verifier_descriptor_hash=bytes.fromhex("6d" * 32)),
        replace(release_manifest,
                ingress_authorization_root=bytes.fromhex("6e" * 32)),
        replace(release_manifest, native_liquidity_pool=0x5114),
        replace(release_manifest,
                pool_runtime_hash=bytes.fromhex("6f" * 32)),
        replace(release_manifest,
                pool_configuration_hash=bytes.fromhex("70" * 32)),
        replace(release_manifest,
                destination_domain_id=bytes.fromhex("39" * 32)),
        replace(release_manifest, destination_bridge=0xB201,
                components=(*components[:9],
                            replace(components[9], address=0xB201)),
                destination_infrastructure_hash=
                    destination_infrastructure_hash((
                        *components[:9],
                        replace(components[9], address=0xB201)))),
        replace(release_manifest,
                destination_bridge_execution_hash=bytes.fromhex("67" * 32)),
        replace(release_manifest, components=(
            replace(components[0], runtime_hash=bytes.fromhex("63" * 32)),
            *components[1:]),
            destination_infrastructure_hash=destination_infrastructure_hash((
                replace(components[0], runtime_hash=bytes.fromhex("63" * 32)),
                *components[1:]))),
    ):
        try:
            changed_hash = release_manifest_hash(changed_manifest)
        except AssertionError:
            continue
        assert changed_hash != release_hash
    for invalid_manifest in (
        replace(release_manifest, protocol_version=UINT64_MAX + 1),
        replace(release_manifest, settlement_chain_id=1 << 256),
        replace(release_manifest, destination_chain_id=UINT64_MAX + 1),
        replace(release_manifest,
                destination_bridge_descriptor=replace(
                    destination_descriptor,
                    runtime_hash=bytes.fromhex("5a" * 32))),
        replace(release_manifest,
                pool_configuration_hash=bytes.fromhex("6c" * 32)),
    ):
        try:
            release_manifest_hash(invalid_manifest)
            raise AssertionError("invalid manifest accepted")
        except AssertionError as error:
            assert str(error) != "invalid manifest accepted"

    registration_args = (
        release_manifest.protocol_version, release_hash,
        release_manifest.destination_chain_id,
        release_manifest.destination_namespace,
        release_manifest.destination_domain_id,
        release_manifest.destination_bridge, infrastructure,
        release_manifest.execution_profile_hash)
    registration = destination_registration_commitment(*registration_args)
    assert registration.hex() == actual["destination_registration_commitment"]
    for index, replacement_value in enumerate((
            3, bytes.fromhex("64" * 32), 16_789,
            bytes.fromhex("65" * 32), bytes.fromhex("66" * 32), 0xB201,
            bytes.fromhex("67" * 32), bytes.fromhex("68" * 32))):
        changed = list(registration_args)
        changed[index] = replacement_value
        assert destination_registration_commitment(*changed) != registration
    assert registration_commitment_base_slot().hex() \
        == actual["registration_commitment_base_slot"]
    assert registration_commitment_slot(2).hex() \
        == actual["registration_commitment_slot"]
    assert registration_commitment_trie_key(2).hex() \
        == actual["registration_commitment_trie_key"]
    assert registration_commitment_slot(3) != registration_commitment_slot(2)
    assert release_manifest_base_slot().hex() \
        == actual["release_manifest_base_slot"]
    assert release_manifest_slot(2).hex() == actual["release_manifest_slot"]
    assert release_manifest_trie_key(2).hex() \
        == actual["release_manifest_trie_key"]
    assert release_manifest_slot(3) != release_manifest_slot(2)
    route_config = inbox_route_config_hash(
        0x5100, 0xB200, 0x5103,
        bytes.fromhex(actual["destination_domain_id"]))
    assert route_config.hex() == actual["inbox_route_config_hash"]
    assert inbox_route_config_hash(
        0x5100, 0xB201, 0x5103,
        bytes.fromhex(actual["destination_domain_id"])) != route_config
    queue_config = forced_queue_config_hash(0xAD01)
    assert queue_config.hex() == actual["forced_queue_config_hash"]
    assert forced_queue_config_hash(0xAD02) != queue_config
    published = Path(__file__).with_name("tex").joinpath("main.tex").read_text()
    publication_keys = {
        "TYPEHASH": "typehash",
        "registryRoot": "registry_root",
        "admissionRoot": "admission_root",
        "entryRoot": "entry_root",
        "forcedRoot": "forced_root",
        "sourceDomain": "source_domain_id",
        "destDomain": "destination_domain_id",
        "bridgeKernel": "bridge_kernel_profile_hash",
        "bridgeExec": "bridge_execution_hash",
        "destBrExec": "destination_bridge_execution_hash",
        "destInfra": "destination_infrastructure_hash",
        "poolRowAlt": "pool_row_substitution_infrastructure_hash",
        "mvConfigType": "migration_verifier_config_typehash",
        "mvConfigHash": "migration_verifier_configuration_hash",
        "mvDescType": "migration_verifier_descriptor_typehash",
        "mvDescHash": "migration_verifier_descriptor_hash",
        "mvConfigSel": "migration_verifier_config_getter_selector",
        "relTypehash": "release_manifest_typehash",
        "activateSel": "activate_release_selector",
        "relManifest": "release_manifest_hash",
        "succManifest": "successor_release_manifest_hash",
        "destReg": "destination_registration_commitment",
        "migStmtType": "migration_transition_statement_typehash",
        "deployType": "deployment_commitment_typehash",
        "components": "manifest_components_hash",
        "genesisDeploy": "genesis_deployment_commitment",
        "versionDeploy": "version_deployment_commitment",
        "legacyCkpt": "legacy_signal_checkpoint_hash",
        "genesisStmt": "genesis_migration_statement_hash",
        "versionStmt": "version_migration_statement_hash",
        "genBaseCore": "genesis_base_core_hash",
        "genBase": "genesis_base_canonical_hash",
        "genCandidate": "genesis_candidate_commitment",
        "genOutput": "genesis_output_core_hash",
        "regStmtType": "registration_storage_statement_typehash",
        "regRouteType": "registration_route_key_typehash",
        "regRoute": "registration_route_key",
        "verifyRegSel": "verify_registration_selector",
        "regStmtHash": "registration_storage_statement_hash",
        "regProof": "registration_mpt_proof_schema_hash",
        "regCfgType": "registration_mpt_verifier_config_typehash",
        "regCfgHash": "registration_mpt_verifier_configuration_hash",
        "regDescType": "registration_mpt_verifier_descriptor_typehash",
        "regDescHash": "registration_mpt_verifier_descriptor_hash",
        "regCfgSel": "registration_mpt_verifier_config_getter_selector",
        "verifyRegCall": "verify_registration_calldata_hash",
        "verifyRegLen": "verify_registration_calldata_length",
        "srcCtxType": "source_context_typehash",
        "srcCtxHash": "source_context_hash",
        "dstCtxType": "destination_context_typehash",
        "dstCtxHash": "destination_context_hash",
        "ingAuthType": "ingress_authorization_typehash",
        "kind0Auth": "kind0_ingress_authorization_id",
        "kind1Auth": "kind1_ingress_authorization_id",
        "ingRootType": "ingress_authorization_root_typehash",
        "ingRoot": "ingress_authorization_root",
        "sendMsgSel": "send_message_v2_selector",
        "enqCreditSel": "enqueue_bridge_credit_v2_selector",
        "msgTuple": "message_v1_tuple_hash",
        "msgData": "message_v1_data_hash",
        "sendMsgCall": "send_message_v2_calldata_hash",
        "sendMsgLen": "send_message_v2_calldata_length",
        "enqCreditCall": "enqueue_bridge_credit_v2_calldata_hash",
        "msgPreLen": "normalized_message_hash_preimage_length",
        "normalizedMsg": "normalized_message_hash",
        "enqueueTxSel": "enqueue_forced_transaction_selector",
        "enqueueTxCall": "enqueue_forced_transaction_calldata_hash",
        "enqueueTxLen": "enqueue_forced_transaction_calldata_length",
        "syncSel": "sync_ingress_selector",
        "syncStamp": "sync_ingress_stamp_return_hash",
        "syncChanged": "sync_ingress_synced_return_hash",
        "appendSel": "append_from_adapter_selector",
        "appendK0": "append_kind0_calldata_hash",
        "appendK0Len": "append_kind0_calldata_length",
        "appendK1": "append_kind1_calldata_hash",
        "appendK1Len": "append_kind1_calldata_length",
        "queuedReturn": "queued_return_hash",
        "inboxApplySel": "inbox_apply_selector",
        "inboxApply": "inbox_apply_calldata_hash",
        "inboxApplyLen": "inbox_apply_calldata_length",
        "markBatchSel": "mark_inbox_batch_selector",
        "markBatch": "mark_inbox_batch_calldata_hash",
        "inboxMagic": "inbox_batch_magic",
        "routeCfgSel": "route_config_getter_selector",
        "verifyPinSel": "verify_inbox_credit_selector",
        "getPinSel": "get_inbox_credit_slot_selector",
        "liqQuoteSel": "liquidity_quote_selector",
        "fundStateSel": "liquidity_funding_state_selector",
        "attemptSel": "execute_attempt_selector",
        "attemptCall": "execute_attempt_calldata_hash",
        "attemptLen": "execute_attempt_calldata_length",
        "finalFailSel": "finalize_failed_attempt_selector",
        "targetErrSel": "target_call_failed_selector",
        "appendTermSel": "append_terminal_selector",
        "termCommitSel": "terminal_commitment_selector",
        "termStateSel": "terminal_state_selector",
        "ticketId": "liquidity_ticket_id",
        "poolCfg": "pool_component_configuration_hash",
        "poolReadGas": "pool_external_read_gas",
        "poolCleanGas": "pool_auth_cleanup_gas",
        "poolCbGas": "pool_value_callback_gas",
        "poolDepSel": "pool_deposit_selector",
        "poolWdrSel": "pool_withdraw_selector",
        "poolProcSel": "pool_process_selector",
        "poolRetrySel": "pool_retry_selector",
        "poolProcCall": "pool_process_calldata_hash",
        "poolProcLen": "pool_process_calldata_length",
        "poolRetryCall": "pool_retry_calldata_hash",
        "poolRetryLen": "pool_retry_calldata_length",
        "poolBridgeSel": "pool_bridge_attempt_selector",
        "poolBridgeCall": "pool_bridge_attempt_calldata_hash",
        "poolBridgeLen": "pool_bridge_attempt_calldata_length",
        "poolTickSel": "pool_ticket_selector",
        "poolAcctSel": "pool_accounting_selector",
        "poolConSel": "pool_consume_selector",
        "poolCbSel": "pool_value_callback_selector",
        "poolAccMagic": "pool_accounting_magic",
        "poolValMagic": "pool_value_magic",
        "poolResultMagic": "pool_bridge_result_magic",
        "poolAuth": "pool_attempt_authorization",
        "poolAccept": "pool_value_acceptance_commitment",
        "policyType": "invocation_policy_typehash",
        "policyHash": "invocation_policy_hash",
        "policySel": "invocation_policy_getter_selector",
        "hookSel": "message_invocation_hook_selector",
        "policyMagic": "invocation_policy_magic",
        "l2ReceiptId": "destination_activation_receipt_id",
        "l1ReceiptId": "activation_receipt_id",
        "execProfile": "execution_profile_hash",
        "factoryDeploySel": "settlement_factory_deploy_selector",
        "factoryCfg": "settlement_factory_configuration_hash",
        "marketAuthCfg": "market_authority_configuration_hash",
        "deployDesc": "settlement_deployment_descriptor_hash",
        "deployDescAbi": "settlement_deployment_descriptor_abi_hash",
        "deployDescLen": "settlement_deployment_descriptor_abi_length",
        "succDeployDesc":
            "successor_settlement_deployment_descriptor_hash",
        "targetReg": "target_registration_hash",
        "succTargetReg": "successor_target_registration_hash",
        "mprHash": "migration_activation_profile_record_hash",
        "succMprHash":
            "successor_migration_activation_profile_record_hash",
        "mprSel": "migration_activation_profile_selector",
        "mprMagic": "migration_activation_profile_magic",
        "mprCall": "migration_activation_profile_calldata_hash",
        "mprRet": "migration_activation_profile_return_hash",
        "mprLen": "migration_activation_profile_return_length",
        "opDomain": "protocol_change_operation_domain_hash",
        "timelockDesc": "governance_delay_authority_descriptor_hash",
        "pvmCfgHash": "protocol_version_manager_configuration_hash",
        "pvmDesc": "protocol_version_manager_descriptor_hash",
        "protoDelay": "protocol_change_delay_seconds",
        "maxMigLive": "maximum_live_version_migration_seconds",
        "protoReadGas": "protocol_authority_read_gas",
        "queueOpSel": "queue_protocol_change_selector",
        "execOpSel": "execute_protocol_change_selector",
        "cancelOpSel": "cancel_protocol_change_selector",
        "applyOpSel": "apply_protocol_change_selector",
        "timelockCfgSel": "protocol_change_timelock_config_selector",
        "pvmCfgSel": "protocol_version_manager_config_selector",
        "opGetSel": "protocol_change_operation_selector",
        "timelockMagic": "protocol_change_timelock_config_magic",
        "pvmMagic": "protocol_version_manager_config_magic",
        "opMagic": "protocol_change_operation_magic",
        "applyMagic": "protocol_apply_magic",
        "regRelPayload": "register_release_payload_hash",
        "regRelPayloadLen": "register_release_payload_length",
        "regForkPayload": "register_fork_verifier_payload_hash",
        "regForkPayloadLen": "register_fork_verifier_payload_length",
        "pubGenPayload": "publish_genesis_campaign_payload_hash",
        "pubGenPayloadLen": "publish_genesis_campaign_payload_length",
        "pubMigPayload": "publish_migration_arm_payload_hash",
        "pubMigPayloadLen": "publish_migration_arm_payload_length",
        "regRelOp": "register_release_operation_id",
        "regForkOp": "register_fork_verifier_operation_id",
        "pubGenOp": "publish_genesis_campaign_operation_id",
        "pubMigOp": "publish_migration_arm_operation_id",
        "queueOpCall": "queue_protocol_change_calldata_hash",
        "queueOpLen": "queue_protocol_change_calldata_length",
        "execOpCall": "execute_protocol_change_calldata_hash",
        "execOpLen": "execute_protocol_change_calldata_length",
        "cancelOpCall": "cancel_protocol_change_calldata_hash",
        "cancelOpLen": "cancel_protocol_change_calldata_length",
        "applyOpCall": "apply_protocol_change_calldata_hash",
        "applyOpLen": "apply_protocol_change_calldata_length",
        "timelockCfgRet": "protocol_change_timelock_config_return_hash",
        "pvmCfgRet": "protocol_version_manager_config_return_hash",
        "opGetCall": "protocol_change_operation_calldata_hash",
        "opGetRet": "protocol_change_operation_return_hash",
        "applyRet": "protocol_apply_return_hash",
        "leaseSel": "live_version_migration_lease_selector",
        "leaseAbortSel": "permissionless_abort_expired_migration_selector",
        "leaseMagic": "version_migration_lease_magic",
        "leaseArmId": "version_migration_arm_id",
        "leaseAbortAt": "version_migration_abort_after_timestamp",
        "leaseRet": "version_migration_lease_return_hash",
        "leaseLen": "version_migration_lease_return_length",
        "regTargetSel": "register_target_release_selector",
        "targetRowSel": "target_release_registration_selector",
        "targetRowMagic": "target_release_registration_magic",
        "regTargetCall": "register_target_release_calldata_hash",
        "regTargetLen": "register_target_release_calldata_length",
        "regTargetRet": "register_target_release_return_hash",
        "targetRowCall": "target_release_registration_calldata_hash",
        "targetRowRet": "target_release_registration_return_hash",
        "targetRowLen": "target_release_registration_return_length",
        "pirSel": "profile_ingress_root_selector",
        "piaSel": "profile_ingress_authorization_selector",
        "pirMagic": "profile_ingress_root_magic",
        "piaMagic": "profile_ingress_authorization_magic",
        "pirRet": "profile_ingress_root_return_hash",
        "pia0Ret": "profile_ingress_authorization_zero_return_hash",
        "pia1Ret": "profile_ingress_authorization_one_return_hash",
        "authInstallSel": "install_settlement_authorization_selector",
        "authGetSel": "settlement_authorization_selector",
        "authInstallMagic": "settlement_authorization_install_magic",
        "authGetMagic": "settlement_authorization_getter_magic",
        "authId": "settlement_authorization_id",
        "authInstallCall": "install_settlement_authorization_calldata_hash",
        "authInstallRet": "install_settlement_authorization_return_hash",
        "authGetRet": "settlement_authorization_return_hash",
        "seatStateSel": "seat_target_state_selector",
        "seatTermSel": "seat_market_term_selector",
        "seatDutySel": "seat_market_duty_selector",
        "seatAuthGas": "seat_authority_read_gas",
        "forkConst": "schedule_fork_constants_hash",
        "forkSchema": "schedule_fork_output_schema_hash",
        "forkCfg": "schedule_fork_verifier_configuration_hash",
        "forkInstallSel": "install_fork_verifier_selector",
        "forkRowSel": "fork_verifier_registration_selector",
        "forkCfgSel": "schedule_fork_verifier_config_selector",
        "forkVerifySel": "verify_schedule_carrier_selector",
        "forkInstallMagic": "fork_verifier_install_magic",
        "forkRowMagic": "fork_verifier_registration_magic",
        "forkCfgMagic": "schedule_fork_verifier_config_magic",
        "forkCarrierMagic": "schedule_fork_carrier_magic",
        "forkInstallCall": "install_fork_verifier_calldata_hash",
        "forkRowRet": "fork_verifier_registration_return_hash",
        "forkCfgRet": "schedule_fork_verifier_config_return_hash",
        "carrierCall": "verify_schedule_carrier_calldata_hash",
        "carrierCallLen": "verify_schedule_carrier_calldata_length",
        "carrierStmt": "schedule_carrier_statement_hash",
        "carrierRet": "schedule_carrier_return_hash",
        "publishLegacySel": "publish_legacy_genesis_campaign_selector",
        "armVersionSel": "arm_version_migration_selector",
        "abortVersionSel": "abort_expired_version_migration_selector",
        "publishLegacyMagic": "legacy_genesis_publish_magic",
        "armVersionMagic": "version_migration_arm_magic",
        "abortVersionMagic": "version_migration_abort_magic",
        "publishLegacyCall":
            "publish_legacy_genesis_campaign_calldata_hash",
        "publishLegacyRet": "publish_legacy_genesis_campaign_return_hash",
        "armVersionCall": "arm_version_migration_calldata_hash",
        "armVersionRet": "arm_version_migration_return_hash",
        "abortVersionCall":
            "abort_expired_version_migration_calldata_hash",
        "abortVersionRet": "abort_expired_version_migration_return_hash",
        "pvmRouterGas": "pvm_router_mutation_gas",
        "legacyInboxCfgSel": "legacy_inbox_config_selector",
        "legacyInboxCfg": "legacy_inbox_configuration_hash",
        "legacyInboxCfgRet": "legacy_inbox_config_return_hash",
        "legacyInboxCfgLen": "legacy_inbox_config_return_length",
        "legacyDeploy": "legacy_genesis_deployment_hash",
        "legacyFence": "legacy_genesis_campaign_fence_descriptor_hash",
        "legacyDescGas": "legacy_descriptor_call_gas",
        "legacyTimePolicy": "legacy_genesis_resume_time_policy_hash",
        "legacyRisc0Key":
            "legacy_genesis_risc0_resume_key_policy_hash",
        "legacySp1Key": "legacy_genesis_sp1_resume_key_policy_hash",
        "legacyRisc0Desc":
            "legacy_genesis_risc0_reth_verifier_descriptor_hash",
        "legacySp1Desc":
            "legacy_genesis_sp1_reth_verifier_descriptor_hash",
        "legacyProofGraph": "legacy_genesis_proof_verifier_graph_hash",
        "legacyRoute": "legacy_genesis_resume_verifier_route_hash",
        "legacyProposerDesc":
            "legacy_genesis_proposer_checker_descriptor_hash",
        "legacyPublicProving":
            "legacy_genesis_prover_whitelist_descriptor_hash",
        "legacyCkptRecord": "legacy_genesis_checkpoint_record_hash",
        "legacyCkptLayout":
            "legacy_genesis_checkpoint_storage_layout_hash",
        "legacySignalCkpt":
            "legacy_genesis_signal_service_checkpoint_descriptor_hash",
        "legacyVerifierCfgSel": "legacy_resume_verifier_config_selector",
        "legacyVerifierCfgMagic": "legacy_resume_verifier_config_magic",
        "legacyVerifierCfgRet": "legacy_resume_verifier_config_return_hash",
        "legacyVerifierCfgLen":
            "legacy_resume_verifier_config_return_length",
        "legacyRisc0CfgSel": "legacy_resume_risc0_config_selector",
        "legacyRisc0CfgMagic": "legacy_resume_risc0_config_magic",
        "legacyRisc0CfgRet": "legacy_resume_risc0_config_return_hash",
        "legacyRisc0CfgLen": "legacy_resume_risc0_config_return_length",
        "legacySp1CfgSel": "legacy_resume_sp1_config_selector",
        "legacySp1CfgMagic": "legacy_resume_sp1_config_magic",
        "legacySp1CfgRet": "legacy_resume_sp1_config_return_hash",
        "legacySp1CfgLen": "legacy_resume_sp1_config_return_length",
        "legacyCkptCfgSel": "legacy_checkpoint_config_selector",
        "legacyCkptCfgMagic": "legacy_checkpoint_config_magic",
        "legacyCkptCfgRet": "legacy_checkpoint_config_return_hash",
        "legacyCkptCfgLen": "legacy_checkpoint_config_return_length",
        "legacyImplSel": "legacy_descriptor_impl_selector",
        "legacyOpCountSel": "legacy_operator_count_selector",
        "legacyCurOpSel": "legacy_current_operator_selector",
        "legacyNextOpSel": "legacy_next_operator_selector",
        "legacyVersionSel": "legacy_signal_service_version_selector",
        "legacyPropImplRet": "legacy_proposer_impl_return_hash",
        "legacySignalImplRet": "legacy_signal_impl_return_hash",
        "legacyOpCountRet": "legacy_operator_count_return_hash",
        "legacyCurOpRet": "legacy_current_operator_return_hash",
        "legacyNextOpRet": "legacy_next_operator_return_hash",
        "legacyVersionRet": "legacy_signal_service_version_return_hash",
        "legacyResumeProfile": "legacy_genesis_resume_profile_hash",
        "legacyBlob1": "legacy_blob_slice_one_hash",
        "legacyBlob1Len": "legacy_blob_slice_one_length",
        "legacyBlobMax": "legacy_blob_slice_maximum_hash",
        "legacyBlobMaxLen": "legacy_blob_slice_maximum_length",
        "legacySourceMixed": "legacy_derivation_source_mixed_hash",
        "legacySourceMixedLen": "legacy_derivation_source_mixed_length",
        "legacyPropMixed": "legacy_proposal_mixed_encoding_hash",
        "legacyPropMixedLen": "legacy_proposal_mixed_encoding_length",
        "legacyPropMax": "legacy_proposal_maximum_encoding_hash",
        "legacyPropMaxLen": "legacy_proposal_maximum_encoding_length",
        "legacyForcedAbi": "legacy_forced_inclusion_encoding_hash",
        "legacyForcedAbiLen": "legacy_forced_inclusion_encoding_length",
        "legacyMaxForced":
            "legacy_profile_maximum_forced_inclusions_per_proposal",
        "legacyMaxNormalBlobs":
            "legacy_profile_maximum_normal_blob_hashes_per_proposal",
        "legacyProofGenMax":
            "legacy_resume_proof_generation_max_seconds",
        "legacyMaxPropBytes": "legacy_maximum_proposal_row_bytes",
        "legacyMaxForcedBytes": "legacy_maximum_forced_row_bytes",
        "legacyMaxScanBound": "legacy_maximum_scan_bytes_bound",
        "legacyMax16Raw": "legacy_maximum_sixteen_proposal_raw_bytes",
        "legacyMax16CallLen":
            "legacy_maximum_sixteen_proposal_scan_calldata_length",
        "legacyFullScanBytes": "legacy_full_scan_capacity_bytes",
        "legacyFullScanHeadroom":
            "legacy_full_scan_capacity_headroom_bytes",
        "legacyReview": "legacy_genesis_review_commitment",
        "legacyBlobExpiry": "legacy_genesis_blob_data_expiry",
        "legacyCampaignSel": "legacy_genesis_campaign_selector",
        "legacyCampaignId": "legacy_genesis_campaign_id",
        "legacyCampaignRet": "legacy_genesis_campaign_return_hash",
        "legacyPrepSel": "legacy_genesis_preparation_selector",
        "legacyPrepRet": "legacy_genesis_preparation_return_hash",
        "propRowsEmpty": "legacy_genesis_proposal_rows_empty_root",
        "propRowsRoot": "legacy_genesis_proposal_rows_root",
        "forcedRowsEmpty": "legacy_genesis_forced_rows_empty_root",
        "forcedRecord": "legacy_genesis_forced_record_hash",
        "forcedRowsRoot": "legacy_genesis_forced_rows_root",
        "legacyScanCommit": "legacy_genesis_scan_commitment",
        "legacyAbandon": "legacy_genesis_abandonment_receipt_hash",
        "legacyAbandonTopic": "legacy_genesis_abandonment_sealed_topic",
        "legacyBeginSel": "legacy_genesis_begin_scan_selector",
        "legacyBeginCall": "legacy_genesis_begin_scan_calldata_hash",
        "legacyBeginRet": "legacy_genesis_begin_scan_return_hash",
        "legacyScanPropSel": "legacy_genesis_scan_proposals_selector",
        "legacyScanProp1": "legacy_genesis_scan_proposals_one_calldata_hash",
        "legacyScanProp16":
            "legacy_genesis_scan_proposals_sixteen_calldata_hash",
        "legacyScanForcedSel": "legacy_genesis_scan_forced_selector",
        "legacyScanForcedCall": "legacy_genesis_scan_forced_calldata_hash",
        "legacyScanForcedRet": "legacy_genesis_scan_forced_return_hash",
        "legacyScanStateSel": "legacy_genesis_scan_state_selector",
        "legacyScanStateRet": "legacy_genesis_scan_state_return_hash",
        "legacyQuiesceSel": "legacy_genesis_quiescence_selector",
        "legacyQuiesceCall": "legacy_genesis_quiescence_calldata_hash",
        "legacyQuiesceRet": "legacy_genesis_quiescence_return_hash",
        "legacyResumeSel": "legacy_genesis_resume_selector",
        "legacyResumeCall": "legacy_genesis_resume_calldata_hash",
        "legacyResumeRet": "legacy_genesis_resume_return_hash",
        "legacyArmId": "legacy_genesis_arm_id",
        "legacyBoundary": "legacy_genesis_boundary_hash",
        "legacyLaunch": "legacy_genesis_launch_id",
        "legacyPost": "legacy_genesis_post_state_commitment",
        "legacyStateSel": "legacy_genesis_state_selector",
        "legacyArmSel": "legacy_genesis_arm_selector",
        "legacyFinalSel": "legacy_genesis_finalize_selector",
        "legacyStateRet": "legacy_genesis_state_return_hash",
        "legacyQuiescentRet":
            "legacy_genesis_quiescent_state_return_hash",
        "legacyReadyRet": "legacy_genesis_ready_state_return_hash",
        "legacyStateLen": "legacy_genesis_state_return_length",
        "legacyArmCall": "legacy_genesis_arm_calldata_hash",
        "legacyArmCallLen": "legacy_genesis_arm_calldata_length",
        "legacyFinalCall": "legacy_genesis_finalize_calldata_hash",
        "legacyFinalLen": "legacy_genesis_finalize_calldata_length",
        "legacyArmRet": "legacy_genesis_arm_return_hash",
        "legacyArmRetLen": "legacy_genesis_arm_return_length",
        "legacyFinalRet": "legacy_genesis_finalize_return_hash",
        "arv1Sel": "activation_receipt_selector",
        "genReceiptCall": "genesis_activation_receipt_calldata_hash",
        "genReceiptRet": "genesis_activation_receipt_return_hash",
        "versionReceiptRet": "version_activation_receipt_return_hash",
        "genCtx": "genesis_activation_context_hash",
        "genCtxRet": "genesis_activation_context_return_hash",
        "genAdopt": "genesis_adoption_commitment",
        "genAdoptCall": "genesis_adopt_migration_calldata_hash",
        "genAdoptRet": "genesis_adopt_migration_return_hash",
        "genQueuePost": "genesis_queue_post_state_commitment",
        "genQueueCall": "genesis_queue_migration_calldata_hash",
        "genQueueRet": "genesis_queue_migration_return_hash",
        "genSrcPostRet": "genesis_source_post_state_return_hash",
        "genTgtPostRet": "genesis_target_post_state_return_hash",
        "genQPostRet": "genesis_queue_post_state_return_hash",
        "genReceipt": "genesis_activation_receipt_id",
        "reorgLegacyPost": "reorg_genesis_post_state_commitment",
        "reorgGenCtx": "reorg_genesis_activation_context_hash",
        "reorgGenReceipt": "reorg_genesis_activation_receipt_id",
        "actContext": "migration_activation_context_hash",
        "mactSel": "migration_activation_context_selector",
        "mactRet": "migration_activation_context_return_hash",
        "mactLen": "migration_activation_context_return_length",
        "armLifeRet": "migration_arming_lifecycle_return_hash",
        "mcanSel": "adopt_migration_canonical_selector",
        "mcanCall": "adopt_migration_canonical_calldata_hash",
        "mcanLen": "adopt_migration_canonical_calldata_length",
        "mcanRet": "adopt_migration_canonical_return_hash",
        "sourceFreezePost": "source_freeze_post_state_commitment",
        "mfrzSel": "freeze_migration_source_selector",
        "mfrzCall": "freeze_migration_source_calldata_hash",
        "mfrzRet": "freeze_migration_source_return_hash",
        "queuePost": "queue_migration_post_state_commitment",
        "queueCredit": "queue_migration_credited_wei",
        "qmigSel": "queue_migration_selector",
        "qmigCall": "queue_migration_calldata_hash",
        "qmigLen": "queue_migration_calldata_length",
        "qmigRet": "queue_migration_return_hash",
        "adoptPost": "migration_adoption_commitment",
        "mapsSel": "migration_post_state_selector",
        "mapsCall": "migration_post_state_calldata_hash",
        "sourceMapsRet": "source_post_state_return_hash",
        "targetMapsRet": "target_post_state_return_hash",
        "queueMapsRet": "queue_post_state_return_hash",
        "activateVSel": "activate_version_with_migration_selector",
        "genesisFixed": "genesis_activation_fixed_hash",
        "versionFixed": "version_activation_fixed_hash",
        "genesisCall": "genesis_activation_calldata_hash",
        "genesisLen": "genesis_activation_calldata_length",
        "versionCall": "version_activation_calldata_hash",
        "versionLen": "version_activation_calldata_length",
        "maxGenesis": "maximum_genesis_activation_calldata_hash",
        "maxGenesisLen": "maximum_genesis_activation_calldata_length",
        "maxVersion": "maximum_version_activation_calldata_hash",
        "maxVersionLen": "maximum_version_activation_calldata_length",
        "regBase": "registration_commitment_base_slot",
        "regSlot": "registration_commitment_slot",
        "regTrie": "registration_commitment_trie_key",
        "relBase": "release_manifest_base_slot",
        "relSlot": "release_manifest_slot",
        "relTrie": "release_manifest_trie_key",
        "routeConfig": "inbox_route_config_hash",
        "queueConfig": "forced_queue_config_hash",
        "dataSessCfg": "data_session_config_hash",
        "dsOpenSel": "session_open_selector",
        "dsPostSel": "session_post_selector",
        "dsSealSel": "session_seal_selector",
        "dsMaintSel": "session_maintain_selector",
        "dsClaimSel": "session_claim_selector",
        "dsSweepSel": "session_sweep_selector",
        "dsCellSel": "session_cell_selector",
        "dsByIdSel": "session_by_id_selector",
        "dsAcctSel": "session_accounting_selector",
        "activeSetSel": "active_settlement_state_selector",
        "migReadySel": "migration_readiness_selector",
        "markReadySel": "mark_migration_ready_selector",
        "activeSetMagic": "active_settlement_state_magic",
        "migReadyMagic": "migration_readiness_magic",
        "markReadyMagic": "mark_migration_ready_magic",
        "dsOpenTopic": "session_opened_topic",
        "dsRecordTopic": "data_record_appended_topic",
        "dsSealTopic": "session_sealed_topic",
        "dsRefundTopic": "session_live_to_refund_topic",
        "dsClaimTopic": "session_bond_claimed_topic",
        "dsForfeitTopic": "session_refund_forfeited_topic",
        "dsSweepTopic": "session_surplus_swept_topic",
        "dsMaintTopic": "data_sessions_maintained_topic",
        "bridgeLeaf": "bridge_leaf",
        "feeLeafAlt": "liquidity_fee_substitution_bridge_leaf",
        "creditId": "bridge_credit_id",
        "feeCreditAlt": "liquidity_fee_substitution_credit_id",
        "escrowId": "bridge_escrow_id",
        "inboxSlot": "inbox_credit_slot",
        "terminalDone": "terminal_done_leaf",
        "liquiditySet": "liquidity_settlement_hash",
        "settleLeafAlt": "settlement_tuple_substitution_terminal_leaf",
        "terminalFail": "terminal_failed_leaf",
        "terminalRoot2": "terminal_root_2",
        "emptyTermRoot": "empty_terminal_root",
        "bridgeResult": "bridge_result",
        "manifestRoot": "manifest_root",
        "normalContext": "normal_context",
        "migrationData": "migration_data",
        "winningData": "winning_data",
        "statementHash": "statement_hash",
        "recoveryId": "recovery_id",
        "bodyRoot": "body_root",
    }
    publication_rows: dict[str, str] = {}
    in_vector_table = False
    for line in published.splitlines():
        if line.startswith("TYPEHASH      "):
            in_vector_table = True
        if not in_vector_table:
            continue
        if line == r"\end{verbatim}":
            break
        fields_ = line.split()
        assert len(fields_) == 2
        label, value = fields_
        assert label not in publication_rows
        publication_rows[label] = value
    assert set(publication_rows) == set(publication_keys)
    for label, key in publication_keys.items():
        assert publication_rows[label] == actual[key]

    assertion_sites = sum(
        isinstance(node, ast.Assert)
        for node in ast.walk(ast.parse(Path(__file__).read_text())))
    published_summary = (
        f"reports {len(actual)} golden vectors and "
        f"{assertion_sites} executable assertion sites")
    readme = Path(__file__).with_name("README.md").read_text()
    readme_summary = (
        f"{len(actual)} golden vectors / {assertion_sites} assertion sites")
    assert (published_summary in " ".join(published.split())
            and readme_summary in " ".join(readme.split()))

    sid = bytes.fromhex(actual["session_id"])
    root = bytes.fromhex(actual["body_root"])
    croot = bytes.fromhex(actual["chunk_root_0"])
    z = fs_challenge(1, 2, sid, bytes.fromhex("99" * 32), root,
                     0, 0, 2, 5, croot, 0xCAFE, 9_999)
    assert 0 <= z < BLS_MODULUS
    print(f"RESULTS: commitment encoding model — ALL {len(actual)} "
          f"GOLDEN VECTORS / {assertion_sites} ASSERTION SITES PASS")
    for key, value in actual.items():
        print(f"  {key}: {value}")
