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
D_LIQUIDITY_TICKET = b"slot-chain-liquidity-ticket-v1"
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
    b"bytes32 legacySignalCheckpointHash,bytes32 deploymentCommitment,"
    b"uint64 preInboxLastAppliedPlusOne,uint64 postInboxLastAppliedPlusOne)"
)
MIGRATION_TRANSITION_STATEMENT_TYPEHASH = keccak256(
    MIGRATION_TRANSITION_STATEMENT_TYPE)
DEPLOYMENT_COMMITMENT_TYPE = (
    b"DeploymentCommitmentV2(uint8 transitionKind,uint64 targetProtocolVersion,"
    b"bytes32 targetManifestHash,bytes32 destinationInfrastructureHash,"
    b"bytes32 componentsHash,bytes32 poolConfigurationHash,"
    b"uint64 retirementQueueCount,bytes32 prestatePolicyHash,"
    b"bytes32 poststatePolicyHash)"
)
DEPLOYMENT_COMMITMENT_TYPEHASH = keccak256(DEPLOYMENT_COMMITMENT_TYPE)
D_DEPLOYMENT_PRESTATE_POLICY = b"slot-chain-deployment-prestate-policy-v2"
D_DEPLOYMENT_POSTSTATE_POLICY = b"slot-chain-deployment-poststate-policy-v2"
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
LIQUIDITY_RESERVATION_STATE_SELECTOR = keccak256(
    b"liquidityReservationStateV2(bytes32)")[:4]
EXECUTE_ATTEMPT_SIGNATURE = (
    b"executeAttemptV2((uint64,uint64,uint32,address,uint64,address,uint64,"
    b"address,address,uint256,bytes),(uint64,uint8,bytes32,bytes32,bytes32,"
    b"uint64,address,bytes32,uint64,uint64),(uint256,bytes32,address,"
    b"bytes32,bytes32),address,uint8,bool)"
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
    assert len(config) == (80, 136, 21, 73, 60, 52, 80, 21, 52, 164)[kind - 1]
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
            and 0 <= statement.retirement_queue_count <= UINT64_MAX
            and statement.prestate_policy_hash
                == deployment_prestate_policy_hash(statement.transition_kind)
            and statement.poststate_policy_hash
                == deployment_poststate_policy_hash(statement.transition_kind))
    encoded = (
        u256(statement.transition_kind)
        + u256(statement.target_protocol_version)
        + b32(statement.target_manifest_hash)
        + b32(statement.destination_infrastructure_hash)
        + b32(statement.components_hash)
        + b32(statement.pool_configuration_hash)
        + u256(statement.retirement_queue_count)
        + b32(statement.prestate_policy_hash)
        + b32(statement.poststate_policy_hash)
    )
    assert len(encoded) == 9 * 32
    return keccak256(DEPLOYMENT_COMMITMENT_TYPEHASH + encoded)


def legacy_signal_checkpoint_hash(header_number: int, imported_header_hash: bytes,
                                  imported_state_root: bytes) -> bytes:
    assert (0 <= header_number < 1 << 48
            and imported_header_hash != bytes(32)
            and imported_state_root != bytes(32))
    return keccak256(D_LEGACY_CHECKPOINT + header_number.to_bytes(6, "big")
                     + b32(imported_header_hash) + b32(imported_state_root))


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
            and statement.release_system_tx_position == 0
            and statement.inbox_system_tx_position == 1)
    imported = (
        statement.imported_header_hash, statement.imported_state_root,
        statement.legacy_signal_checkpoint_hash,
    )
    if statement.transition_kind == 1:
        assert all(value != bytes(32) for value in imported)
    else:
        assert imported == (bytes(32), bytes(32), bytes(32))
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
        + b32(statement.deployment_commitment)
        + u256(statement.pre_inbox_last_applied_plus_one)
        + u256(statement.post_inbox_last_applied_plus_one)
    )
    assert len(encoded) == 42 * 32
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
                and statement.legacy_signal_checkpoint_hash == bytes(32))
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


def decode_liquidity_reservation_state_return(
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


def decode_verify_inbox_credit_return(
        returndata: bytes) -> tuple[bytes, int, int, int, int, bytes]:
    assert len(returndata) == 6 * 32
    return (b32(returndata[:32]), uint_word_value(returndata[32:64], 64),
            uint_word_value(returndata[64:96]),
            uint_word_value(returndata[96:128], 64),
            uint_word_value(returndata[128:160], 64),
            b32(returndata[160:192]))


def encode_execute_attempt_calldata(
        message: MessageV1, source_context: SourceContextV2,
        destination_context: DestinationContextV2, processor: int,
        expected_entry_status: int, is_last_attempt: bool) -> bytes:
    assert 0 <= expected_entry_status < 1 << 8
    source_words = source_context_abi(source_context)
    destination_words = destination_context_abi(destination_context)
    encoded = (
        EXECUTE_ATTEMPT_SELECTOR + u256(19 * 32) + source_words
        + destination_words + address_word(processor)
        + u256(expected_entry_status) + u256(1 if is_last_attempt else 0)
        + canonical_message_v1(message)
    )
    assert len(encoded) == 996 + ceil32(len(message.data))
    return encoded


def decode_execute_attempt_calldata(
        calldata: bytes
) -> tuple[MessageV1, SourceContextV2, DestinationContextV2, int, int, bool]:
    assert len(calldata) >= 996 and calldata[:4] == EXECUTE_ATTEMPT_SELECTOR
    arguments = calldata[4:]
    assert uint_word_value(arguments[:32]) == 19 * 32
    source = decode_source_context_abi(arguments[32:11 * 32])
    destination = decode_destination_context_abi(arguments[11 * 32:16 * 32])
    processor = address_word_value(arguments[16 * 32:17 * 32])
    status = uint_word_value(arguments[17 * 32:18 * 32], 8)
    last = uint_word_value(arguments[18 * 32:19 * 32], 8)
    assert last in (0, 1)
    message = decode_canonical_message_v1(arguments[19 * 32:])
    result = (message, source, destination, processor, status, bool(last))
    assert calldata == encode_execute_attempt_calldata(*result)
    return result


def encode_status_return(resulting_status: int, status_reason: int) -> bytes:
    assert 0 <= resulting_status < 1 << 8 and 0 <= status_reason < 1 << 8
    return u256(resulting_status) + u256(status_reason)


def decode_status_return(returndata: bytes) -> tuple[int, int]:
    assert len(returndata) == 64
    return (uint_word_value(returndata[:32], 8),
            uint_word_value(returndata[32:], 8))


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
                        l1_recipient: int, ticket_sequence: int) -> bytes:
    assert (destination_chain_id > 0 and pool != 0 and depositor != 0
            and l1_recipient != 0 and 0 <= ticket_sequence <= UINT64_MAX)
    return keccak256(
        D_LIQUIDITY_TICKET + u256(destination_chain_id) + address20(pool)
        + address20(depositor) + address20(l1_recipient)
        + u64(ticket_sequence))


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


def ingress_authorization_id(row: ProfileIngressAuthorizationV2) -> bytes:
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
    return keccak256(INGRESS_AUTHORIZATION_TYPEHASH + encoded)


def ingress_authorization_root(
        rows: tuple[ProfileIngressAuthorizationV2, ...]) -> bytes:
    assert 1 <= len(rows) <= 64
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
    activated_at_block: int


def activation_receipt_id(receipt: ActivationReceiptV1) -> bytes:
    narrow = (
        receipt.router_generation, receipt.successor_index,
        receipt.source_protocol_version, receipt.target_protocol_version,
        receipt.queue_watermark, receipt.output_canonical_sequence,
        receipt.activated_at_block,
    )
    assert (receipt.transition_kind in (1, 2)
            and all(0 <= value <= UINT64_MAX for value in narrow))
    return keccak256(
        D_ACTIVATION_RECEIPT + u256(receipt.settlement_chain_id)
        + address20(receipt.router) + u64(receipt.router_generation)
        + u64(receipt.successor_index) + u8(receipt.transition_kind)
        + u64(receipt.source_protocol_version)
        + u64(receipt.target_protocol_version)
        + b32(receipt.source_manifest_hash) + b32(receipt.target_manifest_hash)
        + b32(receipt.source_authorization_id)
        + b32(receipt.target_authorization_id)
        + address20(receipt.source_settlement)
        + address20(receipt.target_settlement)
        + b32(receipt.old_destination_domain_id)
        + b32(receipt.new_destination_domain_id)
        + address20(receipt.old_destination_bridge)
        + address20(receipt.new_destination_bridge)
        + u64(receipt.queue_watermark) + b32(receipt.candidate_digest)
        + b32(receipt.output_canonical_hash)
        + u64(receipt.output_canonical_sequence)
        + u64(receipt.activated_at_block))


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
                and canonical_rlp_list(imported_header_rlp))
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


def fixture_destination_components() -> tuple[ComponentDescriptor, ...]:
    """Fully derived fixture for the ten canonical component grammars."""
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
        address20(0xD200) + address20(0xF000)
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
        address20(0x5103) + bytes.fromhex("44" * 32),
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
        execution_profile_hash=bytes.fromhex("fe" * 32),
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
    core = canonical_core(8_000, bytes.fromhex("77" * 32), 8_000,
                          bytes.fromhex("66" * 32), 2, manifest, 100, 0,
                          empty_terminal.root, 0)
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
        settlement_chain_id, l2_chain_id, 2, bytes.fromhex("fe" * 32), contract,
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
    infrastructure_components = fixture_destination_components()
    source_bridge_descriptor = fixture_source_bridge_descriptor(
        bridge_kernel, infrastructure_components[2])
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
    ingress_root = validate_ingress_authorization_set(
        (kind1_ingress, kind0_ingress), ingress_graph)
    release_manifest = ReleaseManifestDescriptor(
        2, settlement_chain_id, l2_chain_id, bytes.fromhex("35" * 32),
        bytes.fromhex("fe" * 32), bytes.fromhex("37" * 32),
        bytes.fromhex("36" * 32),
        0xA004, bytes.fromhex("a4" * 32),
        destination_domain, 0xB200,
        destination_bridge_execution, destination_bridge_descriptor,
        infrastructure, migration_verifier_descriptor, ingress_root,
        0x5104, infrastructure_components[8].runtime_hash,
        infrastructure_components[8].config_hash,
        infrastructure_components)
    release_hash = release_manifest_hash(release_manifest)
    registration = destination_registration_commitment(
        2, release_hash, l2_chain_id, bytes.fromhex("36" * 32),
        destination_domain, 0xB200, infrastructure,
        bytes.fromhex("fe" * 32))
    components_commitment = manifest_components_hash(infrastructure_components)
    genesis_deployment = DeploymentCommitmentV2(
        1, 2, release_hash, infrastructure, components_commitment,
        infrastructure_components[8].config_hash, len(envs),
        deployment_prestate_policy_hash(1),
        deployment_poststate_policy_hash(1))
    genesis_deployment_hash = deployment_commitment_hash(genesis_deployment)
    version_deployment = DeploymentCommitmentV2(
        2, 3, bytes.fromhex("81" * 32), infrastructure,
        components_commitment, infrastructure_components[8].config_hash,
        len(envs), deployment_prestate_policy_hash(2),
        deployment_poststate_policy_hash(2))
    version_deployment_hash = deployment_commitment_hash(version_deployment)
    imported_header_hash = bytes.fromhex("82" * 32)
    imported_state_root = bytes.fromhex("83" * 32)
    imported_header_number = 1_234
    checkpoint_hash = legacy_signal_checkpoint_hash(
        imported_header_number, imported_header_hash, imported_state_root)
    genesis_transition = MigrationTransitionStatementV2(
        settlement_chain_id, 0xAD01, infrastructure_components[1].runtime_hash,
        infrastructure_components[1].config_hash,
        1, 1, 1, 2, 1, bytes.fromhex("fe" * 32), release_hash,
        candidate_hash, base, core, 0xF000, bytes.fromhex("5a" * 32),
        forced_queue_config_hash(0xAD01), force.root, len(envs), 2, 66,
        forced_descriptors, 0xCAFE, 1_000, bytes.fromhex("99" * 32),
        force.root, len(envs), source_domain, 7, bridge_execution,
        bytes.fromhex("84" * 32), bytes.fromhex("85" * 32),
        bytes.fromhex("86" * 32), bytes.fromhex("87" * 32), 0, 1,
        imported_header_hash, imported_state_root, checkpoint_hash,
        genesis_deployment_hash, plus_one_cursor(None), plus_one_cursor(8_000))
    version_transition = replace(
        genesis_transition, transition_kind=2, migration_generation=2,
        source_protocol_version=2, target_protocol_version=3,
        source_canonical_sequence=2, target_manifest_hash=bytes.fromhex("81" * 32),
        deployment_commitment=version_deployment_hash,
        imported_header_hash=bytes(32), imported_state_root=bytes(32),
        legacy_signal_checkpoint_hash=bytes(32),
        pre_inbox_last_applied_plus_one=plus_one_cursor(8_000),
        post_inbox_last_applied_plus_one=plus_one_cursor(8_001))
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
        bytes.fromhex("88" * 32), destination_domain,
        bytes.fromhex("89" * 32), 0xB200, 0xB201, len(envs), 1_234)
    destination_receipt_hash = destination_activation_receipt_id(
        destination_receipt)
    activation_receipt = ActivationReceiptV1(
        settlement_chain_id, 0xAD01, 2, 2, 2, 2, 3, release_hash,
        bytes.fromhex("88" * 32), bytes.fromhex("8a" * 32),
        bytes.fromhex("8b" * 32), 0x6200, 0x6201, destination_domain,
        bytes.fromhex("89" * 32), 0xB200, 0xB201, len(envs),
        candidate_hash, core, 2, 1_234)
    activation_receipt_hash = activation_receipt_id(activation_receipt)
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
    inbox_rows = (
        InboxRowV2(69, 0, UINT32_MAX, bytes(32), b""),
        InboxRowV2(70, 5, UINT32_MAX, bridge_credit_result(70, bridge),
                   durable_bridge_descriptor),
    )
    inbox_apply_calldata = encode_inbox_apply_calldata(69, inbox_rows)
    activation_output_core = CanonicalCoreV2(
        8_001, bytes.fromhex("77" * 32), 8_001, bytes.fromhex("66" * 32),
        71, winning, 101, 0, empty_terminal.root, 0)
    genesis_activation_fixed = MigrationActivationFixedV2(
        1, 1, 1, 2, 1, candidate_hash, activation_output_core,
        0xCAFE, 1_000, bytes.fromhex("99" * 32), 70,
        plus_one_cursor(None))
    version_activation_fixed = replace(
        genesis_activation_fixed, transition_kind=2, migration_generation=2,
        source_protocol_version=2,
        pre_inbox_last_applied_plus_one=plus_one_cursor(8_000))
    imported_header_rlp = b"\xe1\xa0" + bytes.fromhex("82" * 32)
    migration_proof = bytes.fromhex("a1" * 65)
    genesis_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, inbox_rows,
            imported_header_rlp, migration_proof,
            migration_verifier.maximum_proof_bytes))
    version_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            version_activation_fixed, release_manifest, inbox_rows, b"",
            migration_proof, migration_verifier.maximum_proof_bytes))
    maximum_genesis_header_rlp = (
        b"\xf9\x07\xfd\xb9\x07\xfa" + bytes(2_042))
    maximum_migration_proof = bytes.fromhex("a2") \
        * MAX_MIGRATION_PROOF_BYTES
    maximum_genesis_rows = tuple(
        InboxRowV2(index, 0, UINT32_MAX, bytes(32), b"")
        for index in range(64))
    maximum_version_rows = tuple(
        InboxRowV2(index, 0, UINT32_MAX, bytes(32), b"")
        for index in range(62)) + (
            InboxRowV2(62, 5, UINT32_MAX, bridge_credit_result(70, bridge),
                       durable_bridge_descriptor),
            InboxRowV2(63, 5, UINT32_MAX, bridge_credit_result(70, bridge),
                       durable_bridge_descriptor),
        )
    maximum_genesis_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, maximum_genesis_rows,
            maximum_genesis_header_rlp, maximum_migration_proof,
            MAX_MIGRATION_PROOF_BYTES))
    maximum_version_activation_calldata = (
        encode_activate_version_with_migration_calldata(
            version_activation_fixed, release_manifest, maximum_version_rows,
            b"", maximum_migration_proof, MAX_MIGRATION_PROOF_BYTES))
    source_context = SourceContextV2(
        2, 1, bridge_credit, bridge_msg_hash, source_domain, 7,
        source_bridge_address,
        bridge_execution, bridge.emitted_at_block, 70)
    destination_context = DestinationContextV2(
        l2_chain_id, destination_domain, 0xB200, release_hash,
        bytes.fromhex("fe" * 32))
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
    reservation_state_return = (
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
    reservation_state_calldata = (
        LIQUIDITY_RESERVATION_STATE_SELECTOR + bridge_credit)
    execute_attempt_calldata = encode_execute_attempt_calldata(
        normalized_message, source_context, destination_context,
        0x7777, 1, False)
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
    ticket_hash = liquidity_ticket_id(
        l2_chain_id, 0x5104, 0x8888, 0x9999, 7)
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
    assert decode_inbox_apply_calldata(inbox_apply_calldata) == (69, inbox_rows)
    assert ACTIVATE_VERSION_WITH_MIGRATION_SELECTOR == keccak256(
        ACTIVATE_VERSION_WITH_MIGRATION_SIGNATURE)[:4]
    assert_all_fields_bound(activation_output_core, canonical_core_v2_abi)
    assert_all_fields_bound(genesis_activation_fixed,
                            canonical_migration_activation_fixed)
    assert decode_activate_version_with_migration_calldata(
        genesis_activation_calldata, genesis_activation_fixed,
        release_manifest, migration_verifier.maximum_proof_bytes) \
        == (inbox_rows, imported_header_rlp, migration_proof)
    assert decode_activate_version_with_migration_calldata(
        version_activation_calldata, version_activation_fixed,
        release_manifest, migration_verifier.maximum_proof_bytes) \
        == (inbox_rows, b"", migration_proof)
    assert decode_activate_version_with_migration_calldata(
        maximum_genesis_activation_calldata, genesis_activation_fixed,
        release_manifest, MAX_MIGRATION_PROOF_BYTES) \
        == (maximum_genesis_rows, maximum_genesis_header_rlp,
            maximum_migration_proof)
    assert decode_activate_version_with_migration_calldata(
        maximum_version_activation_calldata, version_activation_fixed,
        release_manifest, MAX_MIGRATION_PROOF_BYTES) \
        == (maximum_version_rows, b"", maximum_migration_proof)
    genesis_arguments = genesis_activation_calldata[4:]
    rows_offset = int.from_bytes(genesis_arguments[79 * 32:80 * 32], "big")
    header_offset = int.from_bytes(genesis_arguments[80 * 32:81 * 32], "big")
    proof_offset = int.from_bytes(genesis_arguments[81 * 32:82 * 32], "big")
    assert rows_offset == 0x0A40
    assert (header_offset == rows_offset + len(canonical_inbox_rows_tail(inbox_rows))
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
                    genesis_activation_fixed, release_manifest, inbox_rows,
                    header, migration_proof,
                    migration_verifier.maximum_proof_bytes),
            "invalid genesis header accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            version_activation_fixed, release_manifest, inbox_rows,
            imported_header_rlp, migration_proof,
            migration_verifier.maximum_proof_bytes),
        "version migration header accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, inbox_rows,
            imported_header_rlp, b"",
            migration_verifier.maximum_proof_bytes),
        "empty migration proof accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest, inbox_rows,
            imported_header_rlp,
            bytes(MAX_MIGRATION_PROOF_BYTES + 1),
            MAX_MIGRATION_PROOF_BYTES),
        "oversize migration proof accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest,
            maximum_genesis_rows + (maximum_genesis_rows[0],),
            imported_header_rlp, migration_proof,
            migration_verifier.maximum_proof_bytes),
        "oversize activation row vector accepted")
    assert_rejects(
        lambda: encode_activate_version_with_migration_calldata(
            genesis_activation_fixed, release_manifest,
            (replace(inbox_rows[1], kind1_descriptor=bytes(220)),),
            imported_header_rlp, migration_proof,
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
    assert decode_liquidity_reservation_state_return(reservation_state_return) \
        == (destination_domain, 0xB200, 0x5101, 1, 0)
    assert decode_verify_inbox_credit_return(verify_inbox_return) \
        == (bridge_credit, bridge.enqueue_by, bridge.value, bridge.fee,
            bridge.liquidity_fee, source_context_hash(source_context))
    assert (len(route_config_getter_calldata) == 4
            and len(verify_inbox_calldata) == 196
            and len(inbox_slot_calldata) == 132
            and len(liquidity_quote_calldata) == 36
            and len(reservation_state_calldata) == 36)
    for malformed_view in (
        liquidity_quote_return[:-1], liquidity_quote_return + bytes(32),
        reservation_state_return[:96] + u256(5)
        + reservation_state_return[128:],
        reservation_state_return[:128] + u256(1),
    ):
        decoder = (decode_liquidity_quote_return
                   if len(malformed_view) != len(reservation_state_return)
                   else decode_liquidity_reservation_state_return)
        assert_rejects(lambda value=malformed_view, fn=decoder: fn(value),
                       "malformed permanent view accepted")
    assert decode_execute_attempt_calldata(execute_attempt_calldata) \
        == (normalized_message, source_context, destination_context,
            0x7777, 1, False)
    assert len(execute_attempt_calldata) == 996 + ceil32(
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
    ticket_arguments = (l2_chain_id, 0x5104, 0x8888, 0x9999, 7)
    for index, replacement_value in enumerate((
            l2_chain_id + 1, 0x5105, 0x8889, 0x999A, 8)):
        changed = list(ticket_arguments)
        changed[index] = replacement_value
        assert liquidity_ticket_id(*changed) != ticket_hash
    for index in (1, 2, 3):
        changed = list(ticket_arguments)
        changed[index] = 0
        assert_rejects(lambda args=tuple(changed): liquidity_ticket_id(*args),
                       "zero liquidity ticket identity accepted")
    assert_rejects(
        lambda: liquidity_ticket_id(*ticket_arguments[:-1], UINT64_MAX + 1),
        "overflow liquidity ticket sequence accepted")
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
        "liquidity_reservation_state_selector":
            LIQUIDITY_RESERVATION_STATE_SELECTOR.hex(),
        "liquidity_reservation_state_calldata_hash":
            keccak256(reservation_state_calldata).hex(),
        "liquidity_reservation_state_return_hash":
            keccak256(reservation_state_return).hex(),
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


EXPECTED = {
    "typehash": "ee6a8c8e31e8245cd527869508f6e464d6084893991203876f734d1855aed87c",
    "domain_separator": "e68571dca46842abc561c1ea35b556152b15d93a1d29f5c441ae2fdcdd01725c",
    "block_struct_hash": "6bc4d67c1c53b6793ace07f9e20b6466207dc7e8285232fbd063900c1bb7614e",
    "eip712_digest": "bf50900a66dd735bbed4a20b7ebe909b61d15185146813b3105b9d2eefa91c68",
    "canonical_core": "f59591f1e2e274e4aace20509a2d855e42b88ecac33a5550fd1af781c83047eb",
    "base_canonical": "67b52faab1709aff021dcb9c16acf86b5b4853de7eb5e36bf1b48566f448621e",
    "migration_data": "2c36740d76ae6192335d4c603f42edace094b33e8f54e959b40241a94c1f6deb",
    "candidate_commitment": "43e4ceb88ddf11a80441caccea6041c734aca203b5f9e377ecc21476898dd91c",
    "candidate_commitment_2": "9c86096381bc8c73a25b947de251960c9a0dc8ca32175b888b13fe0836dd2835",
    "normal_context": "5b93691b397d8ab377682acee7cf6cc77ff2726cd83a8a7b725084f5d6f468bd",
    "winning_data": "4ae34aa9efb842528d353b175f94191d01cfd168b5ad828f64a0e7972a2ca9e3",
    "forced_descriptors": "ccc81a65638181195f6ebd5b5902bc3a62716d7c3e70b32cbabdd250b9ebf42f",
    "schedule_list": "7ab789362dd8b411e1bc42af1270bcb14d2a7571fc28ab614c6afcc33b7de8e7",
    "session_list": "9cbf4ca60afc8aee2ccaa68a45bb6568a04812cf282aa703f194e017092fb264",
    "execution_outputs": "d3b52765911a60935fb5e7c1b7047ad1611e07586803cf654d6d5b677f966d56",
    "statement_hash": "5e3f9ad95b6ccfa825d4d860a724cdd4acde1951a0f7ba8649acaedd73eda2a0",
    "registry_root": "0bf297d7b9b6a5529a319a06cb08484923a89bab15d51f8baeaf5c30bebdf3fd",
    "admission_root": "3bf2dcaf78292c832108e29205bf99cc2d22137a0545e4528d8da7309d4b482b",
    "admission_reuse_root": "a1e22890dd835872055e53dcad82d9e12759a2920853fe6e9f735d7f2c87ceca",
    "entry_root": "acee83a690b868a4a7960c55a9f7228f91cad26b704e24106d4db87e9c7a8f34",
    "tranche_leaf": "80fce6c2421807d961f9207d30b439bd423c05e206a18021b93217513ecc5551",
    "forced_leaf": "c75c50d8b8573f217a20c9018a3d23d7fa5cda240f2a2e9eb4260c4af4c367e4",
    "bridge_leaf": "956ac8402556d0a89ca016866d374e6f69fa3fd205435aef24135287c44b9b76",
    "bridge_result": "20b827ea751b10e09d74228c914983753c5b11def4ea5db33ba98223020161c2",
    "bridge_credit_id": "44c7f6349cfc851f3d08f76268d0bf63986b3c2d66ad1de8aa22c3a684e922cb",
    "liquidity_fee_substitution_bridge_leaf": "24b35a966effbd11f3ac01e523adcc1bd534144f65ec2a51e0d0082ba782394f",
    "liquidity_fee_substitution_credit_id": "14094883c8f217eb0db2c615ec87bff6f96295dfe5fd67963e399f767f0a7630",
    "bridge_escrow_id": "c12559a405b00da5acac02621ba6f341a8d4d6adf17594254ed061d739980f6d",
    "inbox_credit_slot": "27723fe890a8d23e0b7d0b14880f03f3c34cc646f9600a83919840f6a0bd5b89",
    "terminal_done_leaf": "1c89cc4ea4844a4d892d59a0cede83ad74b12724acd7214bc0c11cb9403e7e33",
    "liquidity_settlement_hash": "625ff42ed879b94a7499fecb7abc07988b348300d1c4e9cc1f7596968eaf2f19",
    "settlement_tuple_substitution_terminal_leaf": "8db1f7f9e7fa1c5075075286eed748933d59e22759bd0f3011a91950ad9d67b7",
    "terminal_failed_leaf": "1391f7851ecffe7093f154cc399ac59891b7aa7766b32375df9a53c6d84b1d5f",
    "terminal_root_2": "121e62e05147e60c2db287e8e7d4de42fff6cdec8f51d53f6f67214457c97581",
    "empty_terminal_root": "c5da197edc2f03c7023cc6afe137ccb77d01fc56514d322b6ba66a149315bcb0",
    "source_domain_id": "3ca03af3984e7b2ece804a84fe1f80b20d1ca0c710a03b4483adfabd63a35376",
    "destination_domain_id": "97e53e2233611efb9ee4dbb5a8d97a108b4d33ec43711b3d7250bd0c33863cf0",
    "bridge_kernel_profile_hash": "a23f9994e8d1c475500768b67cf2b2d1f7a0f367df6f44bac5ccf1fa12bc1338",
    "source_bridge_descriptor_length": "752",
    "derived_source_bridge_address": "27e23fb6e5b1d8d4061ac47519cf1e7928cb0e79",
    "derived_source_bundle_deployer_address": "0f9fdc72ae0d799f5e32d5eb92ed94778fa64096",
    "derived_source_registry_address": "fa8fe1755643129e5556ea1bf83e95489f7a2794",
    "derived_source_quota_address": "53ea9364084256748b2087863a596e0e3a7d04ba",
    "component_config_getter_selector": "f6c0f7d2",
    "component_config_getter_gas_limit": "50000",
    "source_factory_config_getter_return": "2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f",
    "source_bridge_config_getter_return": "3434343434343434343434343434343434343434343434343434343434343434",
    "source_registry_config_getter_return": "3636363636363636363636363636363636363636363636363636363636363636",
    "source_quota_config_getter_return": "3838383838383838383838383838383838383838383838383838383838383838",
    "source_support_registry_config_getter_return": "3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a",
    "source_terminal_verifier_config_getter_return": "038f286c206e9799fe645cccf100577246b640a444341f877f51ce2b8214a669",
    "bridge_execution_hash": "fa1e986cef0ff6d8474aeb73698573487e761635dd5999ff1cce625ddf223dd3",
    "destination_bridge_execution_hash": "78c541f426d06c2d96470d6e9e226dc9186d7632c15c587a3199d0db2766c6c4",
    "destination_infrastructure_hash": "1dd64cb0e4fe42cf2f54a7daa9936854c654ef1f43f5339d664a6d07c10d27d1",
    "pool_row_substitution_infrastructure_hash": "af9e17cc8c95267b679e9ae20ec16363a8fa06ceb4e56d63e40bd6e671a05647",
    "migration_verifier_config_typehash": "0acb8f9e39dd43a4208edc38c8925bbd3433e72eb46f9e5fac584bd14a970b98",
    "migration_verifier_configuration_hash": "969a782016029488dab2179a992f96b0331759058a03d0105c6a157de09e206d",
    "migration_verifier_descriptor_typehash": "6f1be44c261607b4c2345985bfb5a081aabd621b9168982df9b7820c7dedebd6",
    "migration_verifier_descriptor_hash": "3717fd77ba3254853408d20623f95df4c88b5e6abc20cf436797b7155a5fb965",
    "migration_verifier_config_getter_selector": "476b9aef",
    "release_manifest_typehash": "603555ff1d82bc9012b0e0c8a36df28e154b16cbd89be4eed9d01228c502965b",
    "activate_release_selector": "28f73572",
    "release_manifest_hash": "b19d98a5c4494c4b37d5b84da44b1217fb66284376f6fd8b377e22b9dfa1f869",
    "destination_registration_commitment": "7e05192d70ce3bc37609173005691b2cfac0d7965a58969e342c3a849ec98c62",
    "registration_commitment_base_slot": "20b3dfc457e3cecf32b0c047177351f0814e426c1548e87b79f58830655810c3",
    "registration_commitment_slot": "dfa6283b763bbadeb604401a78e2fefeddb72000addcdb94ed2e3de5cc69846b",
    "registration_commitment_trie_key": "200031adff46d90b1cd5c67ff8e31098235d1dddb08ec98b0d20f5f8660c0ac8",
    "release_manifest_base_slot": "a0b7a29a75032f37561036cd3741e7b375213309367f37b5ffec4ad55cf6154f",
    "release_manifest_slot": "719bb73ba856aeab1b203e322bfefc6d84a4c41a3222bcf1634b1b44e5b9aba8",
    "release_manifest_trie_key": "dac8109059d03da2ad16ac3acc50d2e58897b8c3a7f6889ae77bfb20737e87a2",
    "inbox_route_config_hash": "2256dd6e98891531a80b2ee16b67a7f1d77db7e17d8523f9b5ab3fa540e9c4a3",
    "forced_queue_config_hash": "72e27c19ebfab08e1fb27feeff50609c7c4bb69f0570a7bdb72eda7736c50f4e",
    "data_session_config_hash": "83e7e252277ea66b70b59a490421d21454032a3fe64107c7390131f83a487b76",
    "session_open_selector": "7bda4d11",
    "session_post_selector": "a1cc526a",
    "session_seal_selector": "340e11fb",
    "session_maintain_selector": "1e7a916a",
    "session_claim_selector": "fdd2b0db",
    "session_sweep_selector": "9d083a2b",
    "session_cell_selector": "011efada",
    "session_by_id_selector": "eeaad0bb",
    "session_accounting_selector": "e2a62969",
    "active_settlement_state_selector": "4a95c306",
    "migration_readiness_selector": "b36c83ce",
    "mark_migration_ready_selector": "e0c25827",
    "active_settlement_state_magic": "41535231",
    "migration_readiness_magic": "4d525331",
    "mark_migration_ready_magic": "4d524459",
    "session_opened_topic": "a81132592bd8a549a0bfc83415ab47fbca586f0b48fff5f6cb5bfae0a9fd1f68",
    "data_record_appended_topic": "30ee2de166c53a480d028e5b94d4f8759dbd84b5f7b6af1f23e0c5889ea17f8c",
    "session_sealed_topic": "f6d45ab0ecc3348b36ac48bc769f7391962fc2fa240c1c6bb43269ed3780078e",
    "session_live_to_refund_topic": "086de7ad4d27cf66f63e9dc6ecb09c0c3122146dd43e7f480f3a875070eb984e",
    "session_bond_claimed_topic": "69fe7d8d95811e3a02a4ad4b0d1a3e1360b683a31f7cb30b4c69546b258232fb",
    "session_refund_forfeited_topic": "f93f771339298d1fb502bd2c556fc18130b95d44599f35109de39d8d5731f957",
    "session_surplus_swept_topic": "3a5f2fa0ab342d3b79fc2aa40be5e1296009e8fb31f86c3577c51839dd159a86",
    "data_sessions_maintained_topic": "920669b9670911aa86cd718dceebaa1372d224ca0fdac50a63dc1d45a53e1e89",
    "forced_root": "a54e9f797ffe7f04dd5ca7df4c858edf02ce45a81808522633fc9cee8fe72e57",
    "empty_forced_root": "4001bca0d3c5171a99a50118f1219024e1bef9302262ea3b075ecbed36be7592",
    "force_range_digest": "75c75611d9eaa6c05e56a1fb646cea4c9d796adfd205df5c5ff1b0b52cc93dd2",
    "session_id": "98cbb8b158cb6732a806e2fac0e50c53e88feafd5e3dade0a0ed7edeb7a5a0b1",
    "mmr_root_2": "d20459aeb2fe916a18dd584d39b2ae25075c6b6c14104d9d64a8b1d7882eb4df",
    "manifest_root": "417be737a57e38eb410f2d6e65c77ee19d5c314cdaf432067861c6a36c6a990f",
    "manifest_root_block_1": "c58ab29bdccb3e06cc5431fbbcea1abc6d6f1a38120c5d896e18b7f1ca1cf43e",
    "empty_body_root": "f0e00da8dbc00feb028a8bc92342c0771372b947acf5989b2d4a5f23bb2f459a",
    "empty_manifest_root": "0bb15f38645cecc1748b17fe3bd966ba8016c169ebd1266fd38150766177b5f6",
    "empty_session_list": "8827f09b5799bab18f29ea5b9cb9cbb5a88ddb96bc4b3ffc4d69cbcbdfe50279",
    "dispositions": "ab253c1204a53b6e095a887dfa6acfc8e8c0c6f89badcef5f73fee716fa94b93",
    "recovery_id": "fd0552b28542fa3e236c86807695f3d5a4bc0436add285daa8506d9a79511b15",
    "body_root": "0f4e161a46c8b18c2a86f23a0a4e7169a838a12af8b389f65e97b547a99707e9",
    "chunk_root_0": "e652cb05b1f44f3c09c650870b7b9ade4132548bd0c769bdda35b5bfcac5139e",
    "migration_transition_statement_typehash": "1c99db64554200a004b213159ac780ebbde4379622f59ad73f8f503afcbb2fe1",
    "deployment_commitment_typehash": "bcfcbbdc64e08793950be4f8cd516833c105b8aff92ed7f5482e7aa122df709e",
    "manifest_components_hash": "1ea18ec884a6b6589f5ffc6b26ed65ba1c2e1b1c2a236d01b56870a10599517c",
    "genesis_deployment_commitment": "d280ae426b49d9b76957272ec052ade6c5fb3689cb0422422a73cd6ed5d1f71f",
    "version_deployment_commitment": "050582303e9ccf3b2caed29c1f534b20072933a6d5438389638d0d70ffcbb007",
    "legacy_signal_checkpoint_hash": "6ab84b0c77035309ac300830aa1c31d95f68c44b697d97a6836f7f3f54bf0708",
    "genesis_migration_statement_hash": "437db4c7add4914d0663065bb6637e858a41af59b98299347a983f717bc92df4",
    "version_migration_statement_hash": "bfb307caed765013a6dc050dd0bfe21d7e86702cdfa6cb2714b567dc1b923b74",
    "registration_storage_statement_typehash": "c049f967468e58f1a5c9b9e1a147dfc233695ae69c5d4a95ec4ffb49b5687da0",
    "registration_route_key_typehash": "4368ad9403b46ef3830e21af8cddcaedbd444c8c57bc3414ebc6fdd250e1e6da",
    "registration_route_key": "7ff8e1d53c3ddb482fd789fa3b29c92cdc5fd42aed2151b7f684c70c5c40f7c6",
    "verify_registration_selector": "33639818",
    "registration_storage_statement_hash": "57421732f8694364afe5d47f05bd562b536c6469e7f891ae2c1b9ba61359f819",
    "registration_mpt_proof_schema_hash": "50ac70c83c4d85e9e0790d2413e35216b0c490814ee435879d0ce27e4a12e5e5",
    "registration_mpt_verifier_config_typehash": "38f7fbc63e45f650bd5cbaffba0d81d5ca69f21ebdddfa74280d7e6eb5c319d6",
    "registration_mpt_verifier_configuration_hash": "b266045c553f010d052a847ea18459bb268cbaacde008574e8cf4c738453911f",
    "registration_mpt_verifier_descriptor_typehash": "9533e2f6ac9bcf6830306a9ef5d14e21a06008f9ceb59208d09a8d7ab1e6100f",
    "registration_mpt_verifier_descriptor_hash": "99491cce6d0ea603e0b9862bd3a2509953ea05e50e9243f8086a19aa92b2f1bf",
    "registration_mpt_verifier_config_getter_selector": "59bfe418",
    "verify_registration_calldata_hash": "5254ee30ab9239869c34664d1cc4c6945615c21dc8434bd76d438c418d92ae36",
    "verify_registration_calldata_length": "516",
    "source_context_typehash": "6069dff5f628f94ceff984d5ce3ef62019eaeb4efd7e0627c45a14677bd13c70",
    "source_context_hash": "c76e3ae4a8d80df05787562d494ca2b66681d840c7bc6a870a8349bb125daf27",
    "destination_context_typehash": "b8170dbf684e1fc4dd4dae8fb78ad24984cc0aa0c03cbd1e29b1b2eb5728eefb",
    "destination_context_hash": "019ecba422e0615a07edc6e2ba112d112e35ed77e9004489025ac6a8b5764e52",
    "ingress_authorization_typehash": "a2dccbd60c366ade3f5af12af640f3453bbb4106405ef8da5dd52484db8f2a82",
    "kind0_ingress_authorization_id": "31e0887e3c9b8e063d322fccda4f8d01d2be91a8c8f0ee20d8cd9984ee972aaf",
    "kind1_ingress_authorization_id": "1cee9bf0f46a9f58aa5e47ee5fc2c0d1cb865f1cd70ce1353aa25497c38b272e",
    "ingress_authorization_root_typehash": "c7b11126d8d1984cc17cbc108be2a1be0ef9c4e8fd519fa9033c949962f1b042",
    "ingress_authorization_root": "e925350f82d47fa044d352e8e65a68f4641304abc0996a20985ea1ee8479ffac",
    "send_message_v2_selector": "9211d7e9",
    "enqueue_bridge_credit_v2_selector": "81805d6b",
    "credit_authorization_v2_selector": "05ecb6c2",
    "credit_authorization_v2_calldata_hash": "16c5b7feff695476e8e652ff3d0d1b8f67e097263dcd582be5bcd4bf71a895ea",
    "credit_authorization_v2_return_hash": "adb5fd5a08fa444f2c6b69896e6598dbe3cd3a386b8f86b59565c8a3a63395ac",
    "credit_authorization_v2_return_length": "576",
    "credit_liability_v2_selector": "c978978a",
    "credit_liability_v2_calldata_hash": "b3e44f619f0f33257810de654855f99ad49354966d1ea0de39d9eef1345ed94d",
    "credit_liability_v2_return_hash": "ad3bba6e04fff6bfefacfdf034f4aaf7bba7149ef0f4dfa0625a5653290f9195",
    "credit_liability_v2_return_length": "288",
    "source_credit_read_gas_limit": "200000",
    "message_v1_tuple_hash": "0e85a708462e96cbaca7158a1534011a25137c3b7aada7f381e4fc5b3afbe40d",
    "message_v1_data_hash": "f08683775f4a25dfef721c487073fb77026d45ac57e423424290e47af9fd2835",
    "send_message_v2_calldata_hash": "9099cce58d3f36714ee59f37510261394e31583f8bd55da4551b653b5a060e12",
    "send_message_v2_calldata_length": "516",
    "enqueue_bridge_credit_v2_calldata_hash": "02db9c77025d4c2bae1d3f79849020e6d8711c4b6b6c54ec45ce9181e48cfeb4",
    "normalized_message_hash_preimage_length": "576",
    "normalized_message_hash": "f3010702b7b7bf10b6dbfe396a4c7ab07e7c560c28ffdbf6ff8d01d9a96ea4c7",
    "normalized_message_return_hash": "9ae2f743a618dd71137457bbc5ce7a13bbd143fef8b1c70bb38508c0fcad7e17",
    "v11_bridge_descriptor": "212121212121212121212121212121212121212121212121212121212121212100000000000000000000000000000000000000000000000000000000000000013ca03af3984e7b2ece804a84fe1f80b20d1ca0c710a03b4483adfabd63a35376000000000000000727e23fb6e5b1d8d4061ac47519cf1e7928cb0e79fa1e986cef0ff6d8474aeb73698573487e761635dd5999ff1cce625ddf223dd3000000000000300c97e53e2233611efb9ee4dbb5a8d97a108b4d33ec43711b3d7250bd0c33863cf0000000000000000000000000000000000000000000000000000000000000419400000000000c35000000000000000000000000000000000000003333000000000000000000000000000000000000111100000000000000000000000000000000000022220000000000000000000000000000000000000000000000000de0b6b3a764000000000000000004d2000000000000162e22222222222222222222222222222222222222222222222222222222222222220100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c12559a405b00da5acac02621ba6f341a8d4d6adf17594254ed061d739980f6d00000060000000000001d4c0000000000000000000000000000000000000beef00000000000002bc0000000000000898000000000000000000000000000000000000000000000000002386f26fc10000",
    "inbox_apply_selector": "6b326168",
    "inbox_apply_calldata_hash": "c55aea0f32c9ad41c0999db1f4b7ba9375bb1780c9e6e28f10f182b44eba37fd",
    "inbox_apply_calldata_length": "1092",
    "inbox_apply_maximum_calldata_hash": "9fe9c4243b52d825cee194bf369006cdf574feefcb0649529905d6e22dc72bf8",
    "mark_inbox_batch_selector": "a92f72cd",
    "mark_inbox_batch_calldata_hash": "30a0a90e1ff8add20c78619d04749502540c0f2b3d405da3d71bc2ff1bd4b01f",
    "inbox_batch_magic": "49425632",
    "route_config_getter_selector": "4b64fa11",
    "verify_inbox_credit_selector": "28933d28",
    "get_inbox_credit_slot_selector": "31e85ab1",
    "liquidity_quote_selector": "43dc48e0",
    "liquidity_quote_return_hash": "64bbd1e5bf27db4819b6270f2f6a659ed9b5d3f78e2d047d767507d41fcf3709",
    "liquidity_reservation_state_selector": "45a933f1",
    "liquidity_reservation_state_return_hash": "b424d0be4a9d6b889ee2977b6001dbbf4b6238efc437bed9dabd823fc4d7aae5",
    "execute_attempt_selector": "b3e5c861",
    "execute_attempt_calldata_hash": "2d2c0279d18df6ac41cc77e6c9e4d3190a6110ae27e8f8f0358837aef66db5dd",
    "execute_attempt_calldata_length": "1060",
    "finalize_failed_attempt_selector": "745dcb69",
    "status_return_hash": "b39221ace053465ec3453ce2b36430bd138b997ecea25c1043da0c366812b828",
    "target_call_failed_selector": "f9cc2b44",
    "target_call_failed_error_hash": "1e5dd0ffe211b83cfe975af6e5c84015b6cfae3a2135c70a7c42426b899a59ac",
    "append_terminal_selector": "abc194f5",
    "terminal_commitment_selector": "2c984c97",
    "terminal_state_selector": "998c57ed",
    "terminal_commitment_return_hash": "f42301cb4f2f26d17b42ff046fbcd9d682a2c9833b9e195b4faa87d62af93185",
    "terminal_state_return_hash": "3e3b1f39f0b0fc42adb4a6c15987dc52d6c0bac9497db88ab1b07b9fb96bfbcd",
    "liquidity_ticket_id": "69e7a081b31736d338fa57ad67287ae534499bd1f800bc08272703f08b9a6ec9",
    "invocation_policy_typehash": "d702a337b74fc40bfc746fb1aeeaa705e60a95947bfc3076c76222703205b4b1",
    "invocation_policy_hash": "5eb7c00399d64d91e416d5a3dbe75187c39dfc2a4645b867864b5fd9e649f3e3",
    "invocation_policy_getter_selector": "b2d0e286",
    "message_invocation_hook_selector": "7f07c947",
    "invocation_policy_return_hash": "93bc154411cabc321c6b7c452a338e3e52789f0b97229cc2c68ba0bb4e3f3a19",
    "invocation_policy_magic": "49505632",
    "enqueue_forced_transaction_selector": "9f06b1b4",
    "enqueue_forced_transaction_calldata_hash": "3e802e6f72e50c267cc18d256c2863d04446eb8f2d47bc474bbcb9c68876d19a",
    "enqueue_forced_transaction_calldata_length": "196",
    "sync_ingress_selector": "6c880b72",
    "sync_ingress_stamp_return_hash": "1fd01b194948c635358fbb51b4a5f32f8ceab4dc4153e0230215f8afc94ee434",
    "sync_ingress_synced_return_hash": "ef662a629ce07c9ed715124d8141a6e430d0a3065f8ce8074a7ea95e8751f184",
    "append_from_adapter_selector": "1927261d",
    "append_kind0_calldata_hash": "caabdaadee6df8cea48fb88dacad863e6e24e13f5b0c06f99408d5c71611788a",
    "append_kind0_calldata_length": "388",
    "append_kind1_calldata_hash": "a1460e7adedb5855522f00a851f9025b96534ab3c6c83f513fd7841382f915de",
    "append_kind1_calldata_length": "708",
    "queued_return_hash": "76f821bd39721ec0e26efc55d7b667d20aab74992e0feae7d7755e386ecd694d",
    "registration_verifier_return": "57421732f8694364afe5d47f05bd562b536c6469e7f891ae2c1b9ba61359f819",
    "registration_config_getter_return": "b266045c553f010d052a847ea18459bb268cbaacde008574e8cf4c738453911f",
    "verify_inbox_credit_calldata_hash": "876a0f57d3964a756f5c629b7115857e7e427beb56c44997b8cb9ce16d3ecace",
    "get_inbox_credit_slot_calldata_hash": "ca784da1943d589a299d6f3f186559576c59dcb5a5a92120b61b9915655166cb",
    "liquidity_quote_calldata_hash": "dd77508525438b655ec5617344c3a4aeb345f47ebcde30baffc55ac26c1f4c7d",
    "liquidity_reservation_state_calldata_hash": "e94f73c9c4bc1deb40d0a851cf3ffdd5f664c3f61a18023690f659e90a2e2716",
    "finalize_failed_attempt_calldata_hash": "b4609d03d03f0c071f957851a75021abfcafa38d9237a011a1af59914642085d",
    "append_terminal_calldata_hash": "ea942e70299ca0a8862376459f38b0cfa618811f7a6d8df6b901aea468eafcac",
    "terminal_commitment_calldata_hash": "f40c1f313a0e7e7130501d1e71a32c301bc7fee02beaf4afc23f1715be430ba8",
    "terminal_append_return": "0000000000000000000000000000000000000000000000000000000000000002",
    "invocation_policy_calldata_hash": "c221beaf62c3e884aca944c70512560a9419bda2901eb936e2084ed8734e8109",
    "destination_activation_receipt_id": "6315904b1838529ad9b66ec508ef3e2ec6e1985db23f3a20bd0b0a4b41517c27",
    "destination_activation_receipt_magic": "44525632",
    "destination_successor_receipt_magic": "44535632",
    "activation_receipt_id": "9c73be9f9f317489fc99cc07ef6824f48a52b371637f1a8bead0e58e7dd5555c",
    "activation_receipt_magic": "41525631",
    "activation_successor_receipt_magic": "41535631",
    "activate_version_with_migration_selector": "14c37693",
    "genesis_activation_fixed_hash": "273742c984e16e7a4eac27323bbfface0e334cb90da2640dc482683114ac0c01",
    "version_activation_fixed_hash": "8ef8c50c81fa6748590f2affe7ac89e9d0adb4a6644d288edfa5dd2923dfc490",
    "genesis_activation_calldata_hash": "7b790b4826a04aae87637711542ba55dc17e0f4f2189a1d761406d55b5d6a0a2",
    "genesis_activation_calldata_length": "3876",
    "version_activation_calldata_hash": "18591525f0a1de1e05bda1dc26d8d975ce682f5c8add2fa8805a2d99f2792eee",
    "version_activation_calldata_length": "3812",
    "maximum_genesis_activation_calldata_hash": "3081eac3864cafad843262459d25e63909e5b891399129bf5517da2a0b745139",
    "maximum_genesis_activation_calldata_length": "150180",
    "maximum_version_activation_calldata_hash": "856b4e553a4819cda95fc6971945dc818b8a7e259318dc92b79f99d3880b9284",
    "maximum_version_activation_calldata_length": "149220",
    "maximum_migration_proof_bytes": "131072",
}


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
        bridge, liquidity_fee=bridge.liquidity_fee + 1)).hex() \
        == actual["liquidity_fee_substitution_bridge_leaf"]
    changed_liquidity_fee_credit = bridge_credit_id(
        bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
        bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash,
        bridge.liquidity_fee + 1)
    assert (changed_liquidity_fee_credit.hex()
            == actual["liquidity_fee_substitution_credit_id"]
            and changed_liquidity_fee_credit != bridge_credit)
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
    assert changed_settlement_leaf.hex() \
        == actual["settlement_tuple_substitution_terminal_leaf"]
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
    assert bridge_execution_hash(descriptor).hex() \
        == actual["bridge_execution_hash"]
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
    assert destination_bridge_execution_hash(destination_descriptor).hex() \
        == actual["destination_bridge_execution_hash"]
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
    assert infrastructure.hex() == actual["destination_infrastructure_hash"]
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
    assert pool_row_substitution.hex() \
        == actual["pool_row_substitution_infrastructure_hash"]
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
    assert migration_verifier_descriptor_hash(migration_verifier).hex() \
        == actual["migration_verifier_descriptor_hash"]
    assert MIGRATION_VERIFIER_CONFIG_GETTER_SELECTOR.hex() \
        == actual["migration_verifier_config_getter_selector"]

    release_manifest = ReleaseManifestDescriptor(
        2, 1, 16_788, bytes.fromhex("35" * 32),
        bytes.fromhex("fe" * 32), bytes.fromhex("37" * 32),
        bytes.fromhex("36" * 32),
        0xA004, bytes.fromhex("a4" * 32),
        bytes.fromhex(actual["destination_domain_id"]), 0xB200,
        bytes.fromhex(actual["destination_bridge_execution_hash"]),
        destination_descriptor,
        infrastructure, migration_verifier_descriptor_hash(migration_verifier),
        bytes.fromhex(actual["ingress_authorization_root"]),
        0x5104, components[8].runtime_hash, components[8].config_hash,
        components)
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
    assert release_hash.hex() == actual["release_manifest_hash"]
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

    registration = destination_registration_commitment(
        2, release_hash, 16_788, bytes.fromhex("36" * 32),
        bytes.fromhex(actual["destination_domain_id"]), 0xB200,
        infrastructure, bytes.fromhex("fe" * 32))
    assert registration.hex() == actual["destination_registration_commitment"]
    registration_args = (
        2, release_hash, 16_788, bytes.fromhex("36" * 32),
        bytes.fromhex(actual["destination_domain_id"]), 0xB200,
        infrastructure, bytes.fromhex("fe" * 32))
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
    assert components[1].config_hash == component_config_hash(
        2, address20(0xD200) + address20(0xF000)
        + bytes.fromhex("5a" * 32) + queue_config
        + bytes.fromhex("41" * 32))

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
        "destReg": "destination_registration_commitment",
        "migStmtType": "migration_transition_statement_typehash",
        "deployType": "deployment_commitment_typehash",
        "components": "manifest_components_hash",
        "genesisDeploy": "genesis_deployment_commitment",
        "versionDeploy": "version_deployment_commitment",
        "legacyCkpt": "legacy_signal_checkpoint_hash",
        "genesisStmt": "genesis_migration_statement_hash",
        "versionStmt": "version_migration_statement_hash",
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
        "reserveSel": "liquidity_reservation_state_selector",
        "attemptSel": "execute_attempt_selector",
        "attemptCall": "execute_attempt_calldata_hash",
        "attemptLen": "execute_attempt_calldata_length",
        "finalFailSel": "finalize_failed_attempt_selector",
        "targetErrSel": "target_call_failed_selector",
        "appendTermSel": "append_terminal_selector",
        "termCommitSel": "terminal_commitment_selector",
        "termStateSel": "terminal_state_selector",
        "ticketId": "liquidity_ticket_id",
        "policyType": "invocation_policy_typehash",
        "policyHash": "invocation_policy_hash",
        "policySel": "invocation_policy_getter_selector",
        "hookSel": "message_invocation_hook_selector",
        "policyMagic": "invocation_policy_magic",
        "l2ReceiptId": "destination_activation_receipt_id",
        "l1ReceiptId": "activation_receipt_id",
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
