#!/usr/bin/env python3
"""Golden vectors for Slot-Chain v3.0 consensus commitments.

This fixture covers the commitments that cross Solidity, clients and circuits:
EIP-712 domain/struct/digest, canonical/base identity, ABI statement hashing,
registry/admission/entry/tranche trees, the depth-64 kind-0 forced vector and
canonical range proof, the ForcedQueue views, session MMR, data chunks and
manifests, reward receipts, the BuilderRegistry mutation/proof grammar, the
ScheduleOracle fork-verifier route, recovery ID and blob framing. It
intentionally does not pretend that zero KZG bytes are a valid opening; a
valid c-kzg vector remains a production conformance gate.

The v3.0 revision has no anchor system transaction, no V2 bridge/custody
objects, no execution-profile word layout and no protocol-root or migration
journals; every vector for those v2.28 structures was removed.
"""

from __future__ import annotations

import ast
import hashlib
import json
import runpy
import sys
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
# Fixed by this normative profile revision, without adding an ABI word. A fork
# policy change requires a new reviewed revision and new release certificates.
L1_RESOURCE_POLICY = "Ethereum Fusaka: EIP-7623 and EIP-7825"
L1_TRANSACTION_GAS_LIMIT = 16_777_216
COMPONENT_CONFIG_GETTER_GAS_LIMIT = 50_000
FORCE_DEPTH = 64
REGISTRY_DEPTH = 6
ADMISSION_DEPTH = 11
ENTRY_DEPTH = 6
TRANCHE_DEPTH = 9


def checked_l1_gas(value: int) -> int:
    """Reject non-integers and overflow in the uint64 resource model."""

    assert type(value) is int and 0 <= value <= UINT64_MAX
    return value


def l1_transaction_required_gas(zero_bytes: int, nonzero_bytes: int,
                                execution_gas: int) -> int:
    """EIP-7623 non-creation budget; execution includes every prefix/suffix.

    No refund is deducted: feasibility must fund execution before refunds.
    The floor and ordinary intrinsic-plus-execution charge are alternatives,
    so adding the floor to execution would count calldata twice.
    """

    tokens = checked_l1_gas(
        checked_l1_gas(zero_bytes) + 4 * checked_l1_gas(nonzero_bytes))
    ordinary = checked_l1_gas(
        21_000 + 4 * tokens + checked_l1_gas(execution_gas))
    floor = checked_l1_gas(21_000 + 10 * tokens)
    return max(ordinary, floor)


def l1_gas_with_headroom(required_gas: int) -> int:
    """Checked ceil(1.30 * required_gas), including exact-boundary rounding."""

    return checked_l1_gas(130 * checked_l1_gas(required_gas) + 99) // 100


def validate_l1_transaction_gas(required_gas: int,
                                supported_block_gas_limit: int) -> None:
    assert 0 < checked_l1_gas(supported_block_gas_limit)
    assert l1_gas_with_headroom(required_gas) <= min(
        supported_block_gas_limit, L1_TRANSACTION_GAS_LIMIT)


def l1_call_sequence_minimum_gas(stipends: tuple[int, ...],
                                retained_reserve: int) -> int:
    """Necessary full-stipend/EIP-150 bound, excluding unmeasured overhead.

    This is a lower bound on a compiled execution certificate, not a gas
    measurement. The reserve and EIP-150 retention overlap at each call.
    """

    required = checked_l1_gas(retained_reserve)
    for stipend in reversed(stipends):
        assert 0 < checked_l1_gas(stipend)
        forwarding = checked_l1_gas(stipend + 62) // 63
        required = checked_l1_gas(stipend + max(forwarding, required))
    return required

BUILDER_REGISTRY_FUNCTION_SIGNATURES = {
    "admission_state_selector": b"admissionStateV1()",
    "schedule_registry_state_selector": b"scheduleRegistryStateV1()",
    "register_builder_selector": b"registerBuilderV1(uint192,uint64,uint8,bytes)",
    "reserve_builder_window_selector": b"reserveBuilderWindowV1(uint64,uint64,bytes)",
    "request_builder_exit_selector": b"requestBuilderExitV1(uint64)",
    "process_builder_maintenance_selector": b"processBuilderMaintenanceV1(uint8,bytes)",
    "normalize_builder_tranches_selector": b"normalizeBuilderTranchesV1(address,uint64,bytes)",
    "release_builder_tranche_selector": b"releaseBuilderTrancheV1(address,uint64,uint64,bytes)",
    "release_builder_generation_selector": b"releaseBuilderGenerationV1(address,uint64,bytes)",
    "claim_builder_lease_credit_selector": b"claimBuilderLeaseCreditV1(address)",
    "submit_builder_equivocation_selector": b"submitBuilderEquivocationV1(bytes)",
    "schedule_window_release_selector": b"scheduleWindowReleaseStateV1(uint64)",
    "expire_schedule_windows_selector": b"expireScheduleWindowsV1(uint8)",
    "settlement_schedule_release_selector": b"settlementScheduleReleaseStateV1(uint64)",
}
BUILDER_REGISTRY_SELECTORS = {
    name: keccak256(signature)[:4]
    for name, signature in BUILDER_REGISTRY_FUNCTION_SIGNATURES.items()
}
BUILDER_PROOF_CONFIG_SELECTOR = bytes.fromhex("0d1c9932")
BUILDER_PROOF_IDENTITY_SELECTOR = bytes.fromhex("7c09d62d")
BUILDER_PROOF_REQUEST_SELECTOR = bytes.fromhex("a9ca9190")
BUILDER_PROOF_FIXED_ROW = (
    1, 64, 1_136, 2_048, 512, 6, 11, 9, 18,
    350_000, 120_000, 160_000, 700_000, 450_000,
)
BUILDER_REGISTRY_HEADER_SLOT = bytes.fromhex(
    "e7ce7a505bf18b9ed57a0785851385323c9487991c55b422861381f92e5c245a"
)
BUILDER_REGISTRY_ROOT_SLOT = bytes.fromhex(
    "4dc6f1bf199f7518c646d40ed35ca04703f646273e6de1d7eace0746cc7100a6"
)

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
D_FORCE_USER_ADMISSION = b"slot-chain-force-user-admission-v2"
D_FORCE_DESCRIPTOR_LIST = b"slot-chain-force-descriptor-list-v2"
D_FORCE_EMPTY = b"slot-chain-force-empty-v2"
D_FORCE_NODE = b"slot-chain-force-node-v2"
D_FORCE_ROOT = b"slot-chain-force-root-v2"
D_FORCED_DESCRIPTOR_SCHEMA = b"slot-chain-force-descriptor-schema-v12"
D_FORCED_QUEUE_CONFIG = b"slot-chain-forced-queue-config-v1"
D_DATA_SESSION_CONFIG = b"slot-chain-data-session-config-v1"
D_MMR_LEAF = b"slot-chain-data-leaf-v1"
D_MMR_NODE = b"slot-chain-data-node-v1"
D_MMR_BAG = b"slot-chain-data-bag-v1"
D_MANIFEST_EMPTY = b"slot-chain-manifest-empty-v1"
D_MANIFEST_LEAF = b"slot-chain-manifest-leaf-v1"
D_MANIFEST_NODE = b"slot-chain-manifest-node-v1"
D_MANIFEST_ROOT = b"slot-chain-manifest-root-v1"
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
REWARD_EVENT_SIGNATURES = {
    "candidate_committed_v2_topic": (
        b"CandidateCommittedV2(bytes32,address,uint8,uint256,uint64,bool,"
        b"uint8,bytes32)"
    ),
    "reward_class_funded_v1_topic": (
        b"RewardClassFundedV1(uint8,address,uint256,uint256,uint256)"
    ),
    "reward_claimed_v1_topic": (
        b"RewardClaimedV1(bytes32,address,uint8,uint256)"
    ),
}
COMPONENT_CONFIG_GETTER_SELECTOR = keccak256(
    b"componentConfigHashV2()")[:4]
REWARD_CLASS_V1_SELECTOR = keccak256(b"rewardClassV1(uint8)")[:4]
REWARD_CLASS_V1_MAGIC = b"RCV1"
REWARD_CLASS_V1_RETURN_LENGTH = 7 * 32
FUND_REWARD_CLASS_V1_SELECTOR = keccak256(
    b"fundRewardClassV1(uint8)")[:4]
CLAIM_REWARD_V1_SELECTOR = keccak256(b"claimRewardV1(bytes32)")[:4]
REWARD_RECEIPT_V1_SELECTOR = keccak256(b"rewardReceiptV1(bytes32)")[:4]
REWARD_RECEIPT_V1_MAGIC = b"RRV1"
REWARD_RECEIPT_V1_RETURN_LENGTH = 12 * 32
D_SCHEDULE_FORK_CONSTANTS = b"slot-chain-schedule-fork-constants-v1"
D_SCHEDULE_FORK_VERIFIER_CONFIG = (
    b"slot-chain-schedule-fork-verifier-config-v1"
)
D_SCHEDULE_CARRIER_STATEMENT = b"slot-chain-schedule-carrier-statement-v1"
SCHEDULE_FORK_OUTPUT_SCHEMA_LITERAL = (
    b"ScheduleCarrierOutputV1(bytes32 statementHash,uint64 parentSlot,"
    b"uint64 parentExecutionBlockNumber,uint64 payloadTimestamp,bytes32 blockHash,"
    b"bytes32 stateRoot,bytes32 prevRandao)"
)
FORCED_QUEUE_CONFIG_SELECTOR = keccak256(b"forcedQueueConfigV1()")[:4]
FORCED_QUEUE_STATE_SELECTOR = keccak256(b"forcedQueueStateV1()")[:4]
FORCED_QUEUE_FRONTIER_SELECTOR = keccak256(b"forcedQueueFrontierV1()")[:4]
FORCED_QUEUE_DESCRIPTOR_SELECTOR = keccak256(
    b"forcedQueueDescriptorV1(uint64)")[:4]
FORCED_QUEUE_DUE_AT_SELECTOR = keccak256(b"dueAt(uint64)")[:4]
FORCED_QUEUE_ADVANCE_SELECTOR = keccak256(
    b"advanceCursor(uint64,uint64,address)")[:4]
FORCED_QUEUE_WITHDRAW_SELECTOR = keccak256(
    b"withdrawForcedQueueClaimV1(address)")[:4]
SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR = keccak256(
    b"settlementForcedIngressFloorV1()")[:4]
SETTLEMENT_FORCED_INGRESS_FLOOR_GAS = 50_000
FORCED_QUEUE_EVENT_TOPICS = {
    "forced_queue_appended_topic": keccak256(
        b"ForcedQueueAppended(uint64,uint8,bytes32,bytes32,uint64,uint64,uint256)"
    ),
    "forced_queue_cursor_advanced_topic": keccak256(
        b"ForcedQueueCursorAdvanced(uint64,uint64,address,uint256)"
    ),
    "forced_queue_claim_withdrawn_topic": keccak256(
        b"ForcedQueueClaimWithdrawn(address,address,uint256)"
    ),
}
SEAT_TARGET_STATE_SELECTOR = bytes.fromhex("cf52185b")
SEAT_MARKET_TERM_SELECTOR = bytes.fromhex("76d5ecd4")
SEAT_MARKET_DUTY_SELECTOR = bytes.fromhex("9a649489")
SEAT_AUTHORITY_READ_GAS = 100_000
INSTALL_FORK_VERIFIER_SELECTOR = bytes.fromhex("9bb6fe73")
REPLACE_PENDING_FORK_VERIFIER_SELECTOR = bytes.fromhex("b48bbef1")
SPLIT_LATEST_FORK_VERIFIER_SELECTOR = bytes.fromhex("455b4ff5")
FORK_VERIFIER_REGISTRATION_SELECTOR = bytes.fromhex("c614591c")
SCHEDULE_FORK_VERIFIER_CONFIG_SELECTOR = bytes.fromhex("44efa773")
SCHEDULE_FORK_ROUTE_STATE_SELECTOR = bytes.fromhex("7e9f3c0d")
VERIFY_SCHEDULE_CARRIER_SELECTOR = bytes.fromhex("7e981e0b")
INSTALL_FORK_VERIFIER_GAS = 4_000_000
FORK_VERIFIER_GETTER_GAS = 100_000
FORK_ROUTE_STATE_GETTER_GAS = 50_000
MINIMUM_FORK_VERIFIER_GAS = 100_000
MAXIMUM_FORK_VERIFIER_GAS = 5_000_000
MAXIMUM_SCHEDULE_WITNESS_BYTES = 131_072
FORK_VERIFIER_INSTALL_MAGIC = bytes.fromhex("46564931")  # FVI1
FORK_VERIFIER_REGISTRATION_MAGIC = bytes.fromhex("46565231")  # FVR1
SCHEDULE_FORK_ROUTE_STATE_MAGIC = bytes.fromhex("46525331")  # FRS1
SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC = bytes.fromhex("53465631")  # SFV1
SCHEDULE_FORK_CARRIER_MAGIC = bytes.fromhex("53464331")  # SFC1
ENQUEUE_FORCED_TRANSACTION_SELECTOR = keccak256(
    b"enqueueForcedTransactionV2(bytes,uint64,address)")[:4]
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
D_OUTPUTS = b"slot-chain-outputs-v3"
D_STATEMENT = b"slot-chain-statement-v3"
D_REWARD_RECEIPT_V1 = b"slot-chain-reward-receipt-v1"
D_NORMAL_CONTEXT = b"slot-chain-normal-context-v1"

# Opaque 32-byte fixtures that v2.28 derived from the removed ExecutionProfileV2
# word layout. They keep the surviving statement, reward-receipt, data-session
# and BuilderRegistry vectors byte-stable; none of them encodes a profile.
PROFILE_HASH_FIXTURE = bytes.fromhex(
    "e2e555222a3cece2d92ae55d4014899671be8f760e9db24e8c4eefd45f7c919e")
BUILDER_REGISTRY_RUNTIME_HASH_FIXTURE = bytes.fromhex(
    "029e6e222dce38d7d61e3607db8841d135592c4a5e47c26a4d6c657bd139902a")
BUILDER_REGISTRY_CONFIGURATION_HASH_FIXTURE = bytes.fromhex(
    "5c2fe6d16935d1557c545b24c0b5982391f7a8ac702d7db3a6c55e467427ed79")
# Fixture ScheduleOracle account bound into the carrier statement.
SCHEDULE_ORACLE_FIXTURE_ADDRESS = 0xA101


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


def canonical_packed_slot_chain_block(
    values: tuple[int | bytes, ...],
) -> bytes:
    """Encode the exact 521-byte signed-header tuple used by BEV1."""

    assert len(values) == 24
    encoded = b"".join((
        u256(values[0]), u256(values[1]), u256(values[2]),
        address20(values[3]), u64(values[4]),
        *(b32(values[index]) for index in range(5, 9)),
        u64(values[9]), b32(values[10]), b32(values[11]),
        u64(values[12]), u64(values[13]), u64(values[14]),
        b32(values[15]), address20(values[16]),
        int(values[17]).to_bytes(1, "big"), b32(values[18]),
        u64(values[19]), b32(values[20]), u64(values[21]),
        u64(values[22]), b32(values[23]),
    ))
    assert len(encoded) == 521 and int(values[17]) in (1, 2)
    return encoded


def builder_dynamic_bytes_calldata(
    selector: bytes, static_words: tuple[bytes, ...], payload: bytes
) -> bytes:
    """Encode one ABI whose sole dynamic bytes argument is last."""

    assert len(selector) == 4 and all(len(value) == 32 for value in static_words)
    offset = 32 * (len(static_words) + 1)
    encoded = (
        selector + b"".join(static_words) + u256(offset)
        + abi_bytes_tail(payload)
    )
    assert len(encoded) == 4 + offset + 32 + ceil32(len(payload))
    return encoded


def builder_proof_verifier_configuration_hash_v1() -> bytes:
    """Derive BPV1 from the exact 71-byte noncircular packed preimage."""

    values = BUILDER_PROOF_FIXED_ROW
    packed = b"".join((
        u8(values[0]), *(u16(value) for value in values[1:5]),
        *(u8(value) for value in values[5:9]),
        *(u32(value) for value in values[9:14]),
        BUILDER_PROOF_IDENTITY_SELECTOR, BUILDER_PROOF_REQUEST_SELECTOR,
        b"BPV1", b"EIV1", b"BPR1", b"BPO1",
        *(u16(value) for value in (512, 320, 192, 432, 531, 6_770, 2_727)),
    ))
    assert len(packed) == 71
    return keccak256(
        b"slot-chain-builder-proof-verifier-config-v1" + u16(len(packed))
        + packed
    )


def builder_proof_verifier_config_return_v1() -> bytes:
    values = BUILDER_PROOF_FIXED_ROW
    encoded = b"".join((
        bytes4_word(b"BPV1"), *(u256(value) for value in values),
        builder_proof_verifier_configuration_hash_v1(),
    ))
    assert len(encoded) == 512
    return encoded


def builder_proof_identity_calldata_v1(
    expected_settlement_chain_id: int, evidence: bytes,
) -> bytes:
    assert len(evidence) == 2_366 and expected_settlement_chain_id > 0
    encoded = (
        BUILDER_PROOF_IDENTITY_SELECTOR + u256(expected_settlement_chain_id)
        + u256(64) + abi_bytes_tail(evidence)
    )
    assert len(encoded) == 2_468 and encoded[-2:] == bytes(2)
    return encoded


def builder_proof_identity_commitment_v1(
    evidence_hash: bytes, expected_settlement_chain_id: int,
    protocol_version: int, verifying_contract: int, window: int,
    signed_admission_version: int, signed_admission_root: bytes, builder: int,
) -> bytes:
    config_hash = builder_proof_verifier_configuration_hash_v1()
    preimage = b"".join((
        config_hash, b32(evidence_hash), u256(expected_settlement_chain_id),
        u64(protocol_version), address20(verifying_contract), u64(window),
        u64(signed_admission_version), b32(signed_admission_root),
        address20(builder),
    ))
    assert len(preimage) == 192
    return keccak256(
        b"slot-chain-builder-equivocation-identity-v1" + u16(len(preimage))
        + preimage
    )


def builder_proof_identity_return_v1(
    evidence_hash: bytes, identity_commitment: bytes, builder: int, window: int,
    protocol_version: int, verifying_contract: int,
    signed_admission_version: int, signed_admission_root: bytes,
) -> bytes:
    encoded = b"".join((
        bytes4_word(b"EIV1"), builder_proof_verifier_configuration_hash_v1(),
        b32(evidence_hash), b32(identity_commitment), address_word(builder),
        u256(window), u256(protocol_version), address_word(verifying_contract),
        u256(signed_admission_version), b32(signed_admission_root),
    ))
    assert len(encoded) == 320
    return encoded


def builder_proof_request_commitment_v1(request: bytes) -> bytes:
    assert request[:4] == b"BPR1" and 5 <= len(request) <= 6_770
    return keccak256(
        b"slot-chain-builder-proof-request-v1" + u32(len(request)) + request
    )


def builder_proof_request_calldata_v1(request: bytes) -> bytes:
    builder_proof_request_commitment_v1(request)
    encoded = BUILDER_PROOF_REQUEST_SELECTOR + u256(32) + abi_bytes_tail(request)
    assert len(encoded) == 68 + ceil32(len(request))
    return encoded


def builder_proof_return_v1(
    request: bytes, new_registry_root: bytes = bytes(32),
    new_admission_root: bytes = bytes(32),
    new_tranche_root: bytes = bytes(32),
) -> bytes:
    zero = bytes(32)
    opcode = request[4] if len(request) >= 5 else 0
    if opcode == 1:
        assert new_registry_root != zero and new_admission_root == new_tranche_root == zero
    elif opcode == 2:
        assert new_admission_root != zero and new_registry_root == new_tranche_root == zero
    elif opcode == 3:
        assert new_tranche_root != zero and new_registry_root == new_admission_root == zero
    elif opcode == 4:
        assert len(request) == 2_727 and new_tranche_root != zero
        current_location = request[2_495]
        tombstone = int.from_bytes(request[2_662:2_670], "big")
        assert current_location in (1, 2)
        assert (new_registry_root != zero) == (current_location == 1)
        assert (new_admission_root != zero) == (tombstone == UINT64_MAX)
    else:
        raise AssertionError("unknown Builder proof opcode")
    encoded = b"".join((
        bytes4_word(b"BPO1"), builder_proof_verifier_configuration_hash_v1(),
        builder_proof_request_commitment_v1(request), b32(new_registry_root),
        b32(new_admission_root), b32(new_tranche_root),
    ))
    assert len(encoded) == 192
    return encoded


def builder_registry_cell_v1(cell) -> bytes:
    encoded = b"".join((
        address20(cell.address), u192(cell.bond), u64(cell.registration_index),
        u64(cell.effective_l2_slot), b32(cell.tranche_root),
        u64(cell.tombstoned_at_l2_slot),
    ))
    assert len(encoded) == 100
    return encoded


def builder_admission_cell_v1(cell) -> bytes:
    encoded = b"".join((
        address20(cell.address), u192(cell.bond), u64(cell.registration_index),
        u64(cell.effective_l2_slot), u64(cell.tombstoned_at_l2_slot),
    ))
    assert len(encoded) == 68
    return encoded


def builder_tranche_cell_v1(
    index: int, window: int, state: int, amount: int, deadline: int,
) -> bytes:
    encoded = u16(index) + u64(window) + u8(state) + u192(amount) + u64(deadline)
    assert len(encoded) == 43
    return encoded


def builder_proof_registry_replace_request_v1(
    root: bytes, index: int, old_cell: bytes | None, new_cell: bytes | None,
    siblings: tuple[bytes, ...],
) -> bytes:
    assert 0 <= index < 64 and len(siblings) == 6
    encoded = b"".join((
        b"BPR1\x01", b32(root), u8(index), u8(old_cell is not None),
        bytes(100) if old_cell is None else old_cell,
        u8(new_cell is not None), bytes(100) if new_cell is None else new_cell,
        *(b32(sibling) for sibling in siblings),
    ))
    assert len(encoded) == 432
    return encoded


def builder_proof_admission_replace_request_v1(
    root: bytes, position: int, old_location: int, old_cell: bytes | None,
    new_location: int, new_cell: bytes | None, siblings: tuple[bytes, ...],
) -> bytes:
    assert 0 <= position < 1_136 and len(siblings) == 11
    assert (old_cell is None and old_location == 0) or old_location in (1, 2)
    assert (new_cell is None and new_location == 0) or new_location in (1, 2)
    encoded = b"".join((
        b"BPR1\x02", b32(root), u16(position), u8(old_cell is not None),
        u8(old_location), bytes(68) if old_cell is None else old_cell,
        u8(new_cell is not None), u8(new_location),
        bytes(68) if new_cell is None else new_cell,
        *(b32(sibling) for sibling in siblings),
    ))
    assert len(encoded) == 531
    return encoded


def builder_proof_tranche_batch_request_v1(
    root: bytes,
    transitions: tuple[tuple[bytes, bytes, tuple[bytes, ...]], ...],
) -> bytes:
    assert 1 <= len(transitions) <= 18
    encoded = bytearray(b"BPR1\x03" + b32(root) + u8(len(transitions)))
    for old_leaf, new_leaf, siblings in transitions:
        assert len(old_leaf) == len(new_leaf) == 43 and len(siblings) == 9
        encoded.extend(old_leaf + new_leaf)
        encoded.extend(b"".join(b32(sibling) for sibling in siblings))
    result = bytes(encoded)
    assert len(result) == 38 + 374 * len(transitions) <= 6_770
    return result


def builder_proof_equivocation_request_v1(
    evidence: bytes, expected_settlement_chain_id: int,
    identity_commitment: bytes, builder: int, registration_index: int,
    current_location: int, current_admission_position: int,
    current_l2_slot: int, registry_root_: bytes, admission_root_: bytes,
    current_generation_cell: bytes, reservation_base_window: int,
    reservation_bitmap: int, unreleased_tranche_count: int,
    current_tranche_leaf: bytes,
) -> bytes:
    assert (len(evidence) == 2_366 and current_location in (1, 2)
            and 0 <= current_admission_position < 1_136
            and len(current_generation_cell) == 100
            and 0 <= reservation_bitmap < 1 << 32
            and 0 <= unreleased_tranche_count < 1 << 16
            and len(current_tranche_leaf) == 43)
    encoded = b"".join((
        b"BPR1\x04", evidence, u256(expected_settlement_chain_id),
        keccak256(evidence), b32(identity_commitment), address20(builder),
        u64(registration_index), u8(current_location),
        u16(current_admission_position), u64(current_l2_slot),
        b32(registry_root_), b32(admission_root_), current_generation_cell,
        u64(reservation_base_window), u32(reservation_bitmap),
        u16(unreleased_tranche_count), current_tranche_leaf,
    ))
    assert len(encoded) == 2_727
    return encoded


def builder_close_records(
    records: tuple[tuple[int, tuple[bytes, ...]], ...]
) -> bytes:
    """Encode strictly ascending 296-byte tranche-close records."""

    assert len(records) <= 17
    previous = -1
    encoded = bytearray()
    for window, proof in records:
        assert window > previous and len(proof) == TRANCHE_DEPTH
        assert all(len(sibling) == 32 for sibling in proof)
        encoded.extend(u64(window))
        encoded.extend(b"".join(proof))
        previous = window
    assert len(encoded) == 296 * len(records)
    return bytes(encoded)


def builder_move_witness(
    records: tuple[tuple[int, tuple[bytes, ...]], ...],
    registry_path: tuple[bytes, ...],
    liability_path: tuple[bytes, ...],
    active_path: tuple[bytes, ...],
) -> bytes:
    assert len(registry_path) == REGISTRY_DEPTH
    assert len(liability_path) == len(active_path) == ADMISSION_DEPTH
    encoded = (
        len(records).to_bytes(1, "big") + builder_close_records(records)
        + b"".join(registry_path) + b"".join(liability_path)
        + b"".join(active_path)
    )
    assert len(encoded) == 897 + 296 * len(records)
    return encoded


def builder_normalize_witness(
    records: tuple[tuple[int, tuple[bytes, ...]], ...],
    registry_path: tuple[bytes, ...],
) -> bytes:
    assert len(registry_path) == REGISTRY_DEPTH
    if not records:
        return b"\x00"
    encoded = (
        len(records).to_bytes(1, "big") + builder_close_records(records)
        + b"".join(registry_path)
    )
    assert len(encoded) == 193 + 296 * len(records)
    return encoded


def builder_reserve_witness(
    records: tuple[tuple[int, tuple[bytes, ...]], ...],
    target_path: tuple[bytes, ...],
    registry_path: tuple[bytes, ...],
) -> bytes:
    assert len(target_path) == TRANCHE_DEPTH
    assert len(registry_path) == REGISTRY_DEPTH
    encoded = (
        len(records).to_bytes(1, "big") + builder_close_records(records)
        + b"".join(target_path) + b"".join(registry_path)
    )
    assert len(encoded) == 481 + 296 * len(records)
    return encoded


def builder_equivocation_witness(
    block_a: bytes,
    signature_a: bytes,
    block_b: bytes,
    signature_b: bytes,
    historical_position: int,
    historical_path: tuple[bytes, ...],
    window: int,
    tranche_path: tuple[bytes, ...],
    current_admission_path: tuple[bytes, ...],
    current_registry_path: tuple[bytes, ...],
    *,
    active: bool,
) -> bytes:
    assert len(block_a) == len(block_b) == 521
    assert len(signature_a) == len(signature_b) == 65
    assert len(historical_path) == len(current_admission_path) == ADMISSION_DEPTH
    assert len(tranche_path) == TRANCHE_DEPTH
    assert len(current_registry_path) == REGISTRY_DEPTH
    if not active:
        assert current_registry_path == (bytes(32),) * REGISTRY_DEPTH
    encoded = b"".join((
        block_a, signature_a, block_b, signature_b,
        historical_position.to_bytes(2, "big"), b"".join(historical_path),
        u64(window), b"".join(tranche_path),
        b"".join(current_admission_path), b"".join(current_registry_path),
    ))
    assert len(encoded) == 2_366
    return encoded


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


def encode_settlement_forced_ingress_floor_return(
        minimum_due_at: int) -> bytes:
    assert 0 <= minimum_due_at <= UINT64_MAX
    return bytes4_word(b"SIF1") + u256(minimum_due_at)


def decode_settlement_forced_ingress_floor_return(returndata: bytes) -> int:
    assert len(returndata) == 64 and returndata[:32] == bytes4_word(b"SIF1")
    minimum_due_at = uint_word_value(returndata[32:], 64)
    assert returndata == encode_settlement_forced_ingress_floor_return(
        minimum_due_at)
    return minimum_due_at


def encode_forced_queue_config_return(
        active_settlement_router: int,
        initial_active_settlement: int) -> bytes:
    configuration_hash = forced_queue_config_hash(
        active_settlement_router, initial_active_settlement)
    return (
        bytes4_word(b"FQC1") + address_word(active_settlement_router)
        + address_word(initial_active_settlement) + u256(FORCE_DEPTH)
        + u256(UINT64_MAX) + keccak256(D_FORCE_EMPTY)
        + keccak256(D_FORCED_DESCRIPTOR_SCHEMA) + configuration_hash
    )


def decode_forced_queue_config_return(
        returndata: bytes) -> tuple[int, int, bytes]:
    assert len(returndata) == 256 and returndata[:32] == bytes4_word(b"FQC1")
    router = address_word_value(returndata[32:64])
    initial = address_word_value(returndata[64:96])
    assert (uint_word_value(returndata[96:128], 8) == FORCE_DEPTH
            and uint_word_value(returndata[128:160], 64) == UINT64_MAX
            and returndata[160:192] == keccak256(D_FORCE_EMPTY)
            and returndata[192:224] == keccak256(D_FORCED_DESCRIPTOR_SCHEMA))
    configuration_hash = returndata[224:256]
    assert returndata == encode_forced_queue_config_return(router, initial)
    return router, initial, configuration_hash


def encode_forced_queue_state_return(
        active_settlement: int, root: bytes, count: int, cursor: int,
        last_due_at: int, unconsumed_escrow: int, total_claimable: int,
        accounted_liability: int, configuration_hash: bytes) -> bytes:
    assert (active_settlement != 0 and len(root) == 32
            and 0 <= cursor <= count <= UINT64_MAX
            and 0 <= last_due_at <= UINT64_MAX
            and configuration_hash != bytes(32))
    assert accounted_liability == unconsumed_escrow + total_claimable
    return (
        bytes4_word(b"FQS1") + address_word(active_settlement) + root
        + u256(count) + u256(cursor) + u256(last_due_at)
        + u256(unconsumed_escrow) + u256(total_claimable)
        + u256(accounted_liability) + configuration_hash
    )


def decode_forced_queue_state_return(
        returndata: bytes) -> tuple[int, bytes, int, int, int, int, int, int, bytes]:
    assert len(returndata) == 320 and returndata[:32] == bytes4_word(b"FQS1")
    result = (
        address_word_value(returndata[32:64]), returndata[64:96],
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64),
        uint_word_value(returndata[160:192], 64),
        uint_word_value(returndata[192:224]),
        uint_word_value(returndata[224:256]),
        uint_word_value(returndata[256:288]), returndata[288:320],
    )
    assert returndata == encode_forced_queue_state_return(*result)
    return result


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
                   next_excess_blob_gas: int) -> bytes:
    return keccak256(D_CORE + u64(l2_block_number) + b32(tip_hash)
                     + u64(tip_slot) + b32(state_root)
                     + u64(cursor) + b32(data_commitment)
                     + u256(next_base_fee) + u64(next_excess_blob_gas))


def base_canonical(core_hash: bytes, canonicalized_at_block: int) -> bytes:
    return keccak256(D_CANONICAL + b32(core_hash) + u64(canonicalized_at_block))


def normal_context(base_hash: bytes, admission_version: int,
                   admission_root_hash: bytes, anchor_number: int,
                   anchor_hash: bytes) -> bytes:
    return keccak256(D_NORMAL_CONTEXT + b32(base_hash) + u64(admission_version)
                     + b32(admission_root_hash) + u64(anchor_number)
                     + b32(anchor_hash))


def candidate_commitment(base_hash: bytes,
                         rows: tuple[tuple[int, bytes, bytes, bytes, bytes, int], ...]) -> bytes:
    slots = tuple(slot for slot, *_ in rows)
    assert (1 <= len(rows) <= 4_096
            and all(type(slot) is int and 0 <= slot <= UINT64_MAX
                    for slot in slots)
            and all(left < right for left, right in zip(slots, slots[1:])))
    payload = b"".join(u64(slot) + b32(block_struct) + b32(block_hash)
                       + b32(body_root_hash) + b32(data_manifest_root)
                       + u64(message_end)
                       for slot, block_struct, block_hash, body_root_hash,
                       data_manifest_root, message_end in rows)
    return keccak256(D_CANDIDATE + b32(base_hash) + u16(len(rows)) + payload)


def winning_data(candidate_hash: bytes, sessions_hash: bytes) -> bytes:
    return keccak256(D_WINNING_DATA + b32(candidate_hash) + b32(sessions_hash))


def schedule_list(rows: tuple[tuple[int, bytes, bytes], ...]) -> bytes:
    windows = tuple(window for window, _, _ in rows)
    assert (len(rows) <= 12
            and all(type(window) is int and 0 <= window <= UINT64_MAX
                    for window in windows)
            and all(left < right for left, right in zip(windows, windows[1:])))
    return keccak256(D_SCHEDULE_LIST + u8(len(rows)) + b"".join(
        u64(window) + b32(entry_root_hash) + b32(seed_hash)
        for window, entry_root_hash, seed_hash in rows))


def session_list(rows: tuple[tuple[bytes, int, bytes], ...]) -> bytes:
    session_ids = tuple(b32(session) for session, _, _ in rows)
    assert (len(rows) <= 16
            and all(type(count) is int and 0 <= count <= 2_100
                    for _, count, _ in rows)
            and all(left < right
                    for left, right in zip(session_ids, session_ids[1:])))
    return keccak256(D_SESSION_LIST + u8(len(rows)) + b"".join(
        b32(session) + u16(count) + b32(root) for session, count, root in rows))


def execution_outputs(state_root: bytes, transactions_root: bytes,
                      receipts_root: bytes, logs_bloom_hash: bytes,
                      withdrawals_root: bytes) -> bytes:
    return keccak256(D_OUTPUTS + b32(state_root) + b32(transactions_root)
                     + b32(receipts_root) + b32(logs_bloom_hash)
                     + b32(withdrawals_root))


STATEMENT_KINDS = (
    "uint", "uint", "uint", "bytes", "address",
    "uint", "bytes", "bytes", "uint", "uint", "bytes", "uint", "uint", "bytes",
    "uint", "bytes", "uint", "uint", "uint",
    "uint", "bytes", "bytes", "uint", "bytes", "uint", "bytes", "uint",
    "uint", "bytes", "uint", "uint", "bytes", "bytes", "uint", "bytes",
    "uint", "uint", "uint", "uint", "bytes", "address",
)


def statement_hash(values: tuple[int | bytes, ...]) -> bytes:
    assert len(values) == len(STATEMENT_KINDS)
    assert (type(values[37]) is int
            and 0 <= values[37] < 1 << 256
            and type(values[38]) is int
            and 0 <= values[38] <= UINT64_MAX)
    encoded = []
    for kind, value in zip(STATEMENT_KINDS, values):
        encoded.append(address_word(value) if kind == "address" else word(value))
    return keccak256(D_STATEMENT + b"".join(encoded))


def validate_candidate_statement_tiers(
        statement_values: tuple[int | bytes, ...], candidate_tier: int,
        block_values_rows: tuple[tuple[int | bytes, ...], ...]) -> None:
    """Reject any candidate whose statement or block tier is inconsistent."""

    assert (len(statement_values) == len(STATEMENT_KINDS)
            and type(candidate_tier) is int
            and candidate_tier in (1, 2, 3)
            and type(statement_values[5]) is int
            and statement_values[5] == candidate_tier
            and len(block_values_rows) > 0)
    for block_values_row in block_values_rows:
        assert (type(block_values_row) is tuple
                and len(block_values_row) == 24
                and type(block_values_row[17]) is int
                and block_values_row[17] == candidate_tier)


def reward_receipt_v1_commitment(
        candidate_id: bytes, beneficiary: int, reward_class: int,
        reward_execution_gas: int, reward_published_bytes: int,
        execution_profile_hash_: bytes, committed_at_block: int,
        committed_at_timestamp: int, claim_until: int) -> bytes:
    """Commit the exact immutable RewardReceiptV1 entitlement fields."""

    assert (type(candidate_id) is bytes and len(candidate_id) == 32
            and candidate_id != bytes(32)
            and type(beneficiary) is int and beneficiary != 0
            and type(reward_class) is int and reward_class in (1, 2, 3)
            and type(reward_execution_gas) is int
            and 0 <= reward_execution_gas < 1 << 256
            and type(reward_published_bytes) is int
            and 0 <= reward_published_bytes <= UINT64_MAX
            and type(execution_profile_hash_) is bytes
            and len(execution_profile_hash_) == 32
            and execution_profile_hash_ != bytes(32)
            and type(committed_at_block) is int
            and 0 < committed_at_block <= UINT64_MAX
            and type(committed_at_timestamp) is int
            and type(claim_until) is int
            and 0 < committed_at_timestamp < claim_until <= UINT64_MAX)
    return keccak256(
        D_REWARD_RECEIPT_V1 + b32(candidate_id) + address20(beneficiary)
        + u8(reward_class) + u256(reward_execution_gas)
        + u64(reward_published_bytes) + b32(execution_profile_hash_)
        + u64(committed_at_block) + u64(committed_at_timestamp)
        + u64(claim_until))


def encode_reward_receipt_v1_calldata(candidate_id: bytes) -> bytes:
    assert (type(candidate_id) is bytes and len(candidate_id) == 32
            and candidate_id != bytes(32))
    encoded = REWARD_RECEIPT_V1_SELECTOR + candidate_id
    assert len(encoded) == 36
    return encoded


def decode_reward_receipt_v1_calldata(calldata: bytes) -> bytes:
    assert (len(calldata) == 36
            and calldata[:4] == REWARD_RECEIPT_V1_SELECTOR)
    candidate_id = b32(calldata[4:])
    assert candidate_id != bytes(32)
    assert calldata == encode_reward_receipt_v1_calldata(candidate_id)
    return candidate_id


def encode_reward_receipt_v1_present_return(
        candidate_id: bytes, beneficiary: int, reward_class: int,
        reward_execution_gas: int, reward_published_bytes: int,
        execution_profile_hash_: bytes, committed_at_block: int,
        committed_at_timestamp: int, claim_until: int,
        claimed: bool) -> bytes:
    assert type(claimed) is bool
    commitment = reward_receipt_v1_commitment(
        candidate_id, beneficiary, reward_class, reward_execution_gas,
        reward_published_bytes, execution_profile_hash_, committed_at_block,
        committed_at_timestamp, claim_until)
    encoded = (
        bytes4_word(REWARD_RECEIPT_V1_MAGIC) + u256(1)
        + address_word(beneficiary) + u256(reward_class)
        + u256(reward_execution_gas) + u256(reward_published_bytes)
        + b32(execution_profile_hash_) + u256(committed_at_block)
        + u256(committed_at_timestamp) + u256(claim_until)
        + u256(1 if claimed else 0) + commitment)
    assert len(encoded) == REWARD_RECEIPT_V1_RETURN_LENGTH
    return encoded


def encode_reward_receipt_v1_missing_return() -> bytes:
    encoded = bytes4_word(REWARD_RECEIPT_V1_MAGIC) + bytes(11 * 32)
    assert len(encoded) == REWARD_RECEIPT_V1_RETURN_LENGTH
    return encoded


def reward_receipt_v1_view_return(
        query_candidate_id: bytes,
        stored_receipt_arguments: tuple[object, ...] | None,
        claimed: bool = False) -> bytes:
    encode_reward_receipt_v1_calldata(query_candidate_id)
    if stored_receipt_arguments is None:
        return encode_reward_receipt_v1_missing_return()
    assert len(stored_receipt_arguments) == 9
    reward_receipt_v1_commitment(*stored_receipt_arguments)
    if stored_receipt_arguments[0] != query_candidate_id:
        return encode_reward_receipt_v1_missing_return()
    return encode_reward_receipt_v1_present_return(
        *stored_receipt_arguments, claimed)


def decode_reward_receipt_v1_return(
        returndata: bytes, expected_candidate_id: bytes
) -> tuple[bool, int, int, int, int, bytes, int, int, int, bool, bytes]:
    encode_reward_receipt_v1_calldata(expected_candidate_id)
    assert (len(returndata) == REWARD_RECEIPT_V1_RETURN_LENGTH
            and bytes4_word_value(returndata[:32])
                == REWARD_RECEIPT_V1_MAGIC)
    present_word = uint_word_value(returndata[32:64], 8)
    assert present_word in (0, 1)
    if present_word == 0:
        assert returndata == encode_reward_receipt_v1_missing_return()
        return (False, 0, 0, 0, 0, bytes(32), 0, 0, 0, False,
                bytes(32))
    claimed_word = uint_word_value(returndata[320:352], 8)
    assert claimed_word in (0, 1)
    result = (
        True, address_word_value(returndata[64:96]),
        uint_word_value(returndata[96:128], 8),
        uint_word_value(returndata[128:160]),
        uint_word_value(returndata[160:192], 64),
        b32(returndata[192:224]),
        uint_word_value(returndata[224:256], 64),
        uint_word_value(returndata[256:288], 64),
        uint_word_value(returndata[288:320], 64),
        claimed_word == 1, b32(returndata[352:384]),
    )
    canonical = encode_reward_receipt_v1_present_return(
        expected_candidate_id, result[1], result[2], result[3], result[4],
        result[5], result[6], result[7], result[8], result[9])
    assert returndata == canonical and result[10] == canonical[-32:]
    return result


def encode_fund_reward_class_v1_calldata(reward_class: int) -> bytes:
    assert type(reward_class) is int and reward_class in (1, 2, 3)
    encoded = FUND_REWARD_CLASS_V1_SELECTOR + u256(reward_class)
    assert len(encoded) == 36
    return encoded


def decode_fund_reward_class_v1_calldata(calldata: bytes) -> int:
    assert (len(calldata) == 36
            and calldata[:4] == FUND_REWARD_CLASS_V1_SELECTOR)
    reward_class = uint_word_value(calldata[4:], 8)
    assert reward_class in (1, 2, 3)
    assert calldata == encode_fund_reward_class_v1_calldata(reward_class)
    return reward_class


def decode_fund_reward_class_v1_return(returndata: bytes) -> None:
    assert type(returndata) is bytes and returndata == b""


def encode_claim_reward_v1_calldata(candidate_id: bytes) -> bytes:
    assert (type(candidate_id) is bytes and len(candidate_id) == 32
            and candidate_id != bytes(32))
    encoded = CLAIM_REWARD_V1_SELECTOR + candidate_id
    assert len(encoded) == 36
    return encoded


def decode_claim_reward_v1_calldata(calldata: bytes) -> bytes:
    assert len(calldata) == 36 and calldata[:4] == CLAIM_REWARD_V1_SELECTOR
    candidate_id = b32(calldata[4:])
    assert candidate_id != bytes(32)
    assert calldata == encode_claim_reward_v1_calldata(candidate_id)
    return candidate_id


def encode_claim_reward_v1_return(paid_wei: int) -> bytes:
    assert type(paid_wei) is int and 0 <= paid_wei < 1 << 256
    encoded = u256(paid_wei)
    assert len(encoded) == 32
    return encoded


def decode_claim_reward_v1_return(returndata: bytes) -> int:
    assert len(returndata) == 32
    paid_wei = uint_word_value(returndata)
    assert returndata == encode_claim_reward_v1_return(paid_wei)
    return paid_wei


def encode_candidate_committed_v2_log(
        candidate_id: bytes, beneficiary: int, reward_class: int,
        reward_execution_gas: int, reward_published_bytes: int,
        receipt_stored: bool, receipt_index: int,
        receipt_commitment: bytes) -> tuple[tuple[bytes, ...], bytes]:
    assert (type(candidate_id) is bytes and len(candidate_id) == 32
            and candidate_id != bytes(32)
            and type(beneficiary) is int and beneficiary != 0
            and type(reward_class) is int and reward_class in (1, 2, 3)
            and type(reward_execution_gas) is int
            and 0 <= reward_execution_gas < 1 << 256
            and type(reward_published_bytes) is int
            and 0 <= reward_published_bytes <= UINT64_MAX
            and type(receipt_stored) is bool
            and type(receipt_index) is int
            and receipt_index == candidate_id[-1]
            and type(receipt_commitment) is bytes
            and len(receipt_commitment) == 32
            and (not receipt_stored or receipt_commitment != bytes(32)))
    topics = (
        keccak256(REWARD_EVENT_SIGNATURES["candidate_committed_v2_topic"]),
        candidate_id, address_word(beneficiary),
    )
    data = (
        u256(reward_class) + u256(reward_execution_gas)
        + u256(reward_published_bytes) + u256(1 if receipt_stored else 0)
        + u256(receipt_index) + receipt_commitment)
    assert len(topics) == 3 and len(data) == 192
    return topics, data


def decode_candidate_committed_v2_log(
        topics: tuple[bytes, ...], data: bytes
) -> tuple[bytes, int, int, int, int, bool, int, bytes]:
    assert (type(topics) is tuple and len(topics) == 3
            and topics[0]
                == keccak256(
                    REWARD_EVENT_SIGNATURES["candidate_committed_v2_topic"])
            and len(data) == 192)
    receipt_stored_word = uint_word_value(data[96:128], 8)
    assert receipt_stored_word in (0, 1)
    result = (
        b32(topics[1]), address_word_value(topics[2]),
        uint_word_value(data[:32], 8),
        uint_word_value(data[32:64]),
        uint_word_value(data[64:96], 64),
        receipt_stored_word == 1,
        uint_word_value(data[128:160], 8), b32(data[160:192]),
    )
    assert (topics, data) == encode_candidate_committed_v2_log(*result)
    return result


def encode_reward_class_funded_v1_log(
        reward_class: int, funder: int, amount: int,
        class_funding_after: int,
        total_funding_after: int) -> tuple[tuple[bytes, ...], bytes]:
    assert (type(reward_class) is int and reward_class in (1, 2, 3)
            and type(funder) is int and funder != 0
            and all(type(value) is int and 0 <= value < 1 << 256
                    for value in (
                        amount, class_funding_after, total_funding_after))
            and amount > 0 and class_funding_after >= amount
            and total_funding_after >= class_funding_after)
    topics = (
        keccak256(REWARD_EVENT_SIGNATURES["reward_class_funded_v1_topic"]),
        u256(reward_class), address_word(funder),
    )
    data = u256(amount) + u256(class_funding_after) + u256(total_funding_after)
    assert len(topics) == 3 and len(data) == 96
    return topics, data


def decode_reward_class_funded_v1_log(
        topics: tuple[bytes, ...], data: bytes
) -> tuple[int, int, int, int, int]:
    assert (type(topics) is tuple and len(topics) == 3
            and topics[0]
                == keccak256(
                    REWARD_EVENT_SIGNATURES[
                        "reward_class_funded_v1_topic"])
            and len(data) == 96)
    result = (
        uint_word_value(topics[1], 8), address_word_value(topics[2]),
        uint_word_value(data[:32]), uint_word_value(data[32:64]),
        uint_word_value(data[64:96]),
    )
    assert (topics, data) == encode_reward_class_funded_v1_log(*result)
    return result


def encode_reward_claimed_v1_log(
        candidate_id: bytes, beneficiary: int, reward_class: int,
        paid_wei: int) -> tuple[tuple[bytes, ...], bytes]:
    assert (type(candidate_id) is bytes and len(candidate_id) == 32
            and candidate_id != bytes(32)
            and type(beneficiary) is int and beneficiary != 0
            and type(reward_class) is int and reward_class in (1, 2, 3)
            and type(paid_wei) is int and 0 <= paid_wei < 1 << 256)
    topics = (
        keccak256(REWARD_EVENT_SIGNATURES["reward_claimed_v1_topic"]),
        candidate_id, address_word(beneficiary),
    )
    data = u256(reward_class) + u256(paid_wei)
    assert len(topics) == 3 and len(data) == 64
    return topics, data


def decode_reward_claimed_v1_log(
        topics: tuple[bytes, ...], data: bytes
) -> tuple[bytes, int, int, int]:
    assert (type(topics) is tuple and len(topics) == 3
            and topics[0]
                == keccak256(REWARD_EVENT_SIGNATURES["reward_claimed_v1_topic"])
            and len(data) == 64)
    result = (
        b32(topics[1]), address_word_value(topics[2]),
        uint_word_value(data[:32], 8), uint_word_value(data[32:64]),
    )
    assert (topics, data) == encode_reward_claimed_v1_log(*result)
    return result


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


def fixed_tree_proof(leaves: list[bytes], index: int,
                     node_domain: bytes) -> tuple[bytes, ...]:
    """Return bottom-up siblings for one leaf in a perfect fixed tree."""

    assert (leaves and len(leaves) & (len(leaves) - 1) == 0
            and type(index) is int and 0 <= index < len(leaves))
    level = [b32(leaf) for leaf in leaves]
    position = index
    proof: list[bytes] = []
    height = 0
    while len(level) > 1:
        proof.append(level[position ^ 1])
        level = [keccak256(node_domain + u8(height) + level[i] + level[i + 1])
                 for i in range(0, len(level), 2)]
        position >>= 1
        height += 1
    return tuple(proof)


def verify_fixed_tree_proof(leaf: bytes, index: int, depth: int,
                            siblings: tuple[bytes, ...], node_domain: bytes,
                            expected_root: bytes) -> bool:
    """Verify the unique exact-depth proof; orientation comes only from index."""

    if (type(index) is not int or type(depth) is not int or depth < 0
            or not 0 <= index < 1 << depth
            or type(siblings) is not tuple or len(siblings) != depth):
        return False
    try:
        node = b32(leaf)
        root = b32(expected_root)
        for height, sibling in enumerate(siblings):
            sibling = b32(sibling)
            node = (keccak256(node_domain + u8(height) + sibling + node)
                    if (index >> height) & 1 else
                    keccak256(node_domain + u8(height) + node + sibling))
        return node == root
    except AssertionError:
        return False


def root_from_fixed_tree_proof(leaf: bytes, index: int, depth: int,
                               siblings: tuple[bytes, ...],
                               node_domain: bytes) -> bytes:
    """Return the unique root for an exact-depth, index-oriented proof."""

    assert (type(index) is int and type(depth) is int and depth >= 0
            and 0 <= index < 1 << depth and type(siblings) is tuple
            and len(siblings) == depth)
    node = b32(leaf)
    for height, sibling in enumerate(siblings):
        sibling = b32(sibling)
        node = (keccak256(node_domain + u8(height) + sibling + node)
                if (index >> height) & 1 else
                keccak256(node_domain + u8(height) + node + sibling))
    return node


def builder_registry_header(active_count: int, registry_mutation_version: int,
                            admission_version: int,
                            next_registration_index: int) -> bytes:
    """Encode the exact BRH1 raw storage word."""

    assert 0 <= active_count <= 64
    assert 0 <= next_registration_index <= UINT64_MAX + 1
    registration_exhausted = int(next_registration_index > UINT64_MAX)
    next_registration_index_low64 = (
        0 if registration_exhausted else next_registration_index
    )
    return (b"BRH1" + u8(1) + u8(active_count)
            + u8(registration_exhausted) + u8(0)
            + u64(registry_mutation_version) + u64(admission_version)
            + u64(next_registration_index_low64))


def decode_builder_registry_header(
    raw_word: bytes,
) -> tuple[int, int, int, int]:
    """Decode a canonical BRH1 word and reconstruct its uint256 counter."""

    if (type(raw_word) is not bytes or len(raw_word) != 32
            or raw_word[:5] != b"BRH1\x01" or raw_word[5] > 64
            or raw_word[6] not in (0, 1) or raw_word[7] != 0):
        raise ValueError("noncanonical BRH1 header")
    registration_exhausted = raw_word[6]
    next_registration_index_low64 = int.from_bytes(raw_word[24:32], "big")
    if registration_exhausted and next_registration_index_low64 != 0:
        raise ValueError("noncanonical BRH1 exhausted sentinel")
    next_registration_index = (
        UINT64_MAX + 1
        if registration_exhausted else next_registration_index_low64
    )
    return (
        raw_word[5],
        int.from_bytes(raw_word[8:16], "big"),
        int.from_bytes(raw_word[16:24], "big"),
        next_registration_index,
    )


def verify_registry_proof(leaf: bytes, index: int,
                          siblings: tuple[bytes, ...], expected_root: bytes) -> bool:
    return verify_fixed_tree_proof(
        leaf, index, REGISTRY_DEPTH, siblings, D_REG_NODE, expected_root)


def verify_admission_proof(leaf: bytes, index: int,
                           siblings: tuple[bytes, ...], expected_root: bytes) -> bool:
    return verify_fixed_tree_proof(
        leaf, index, ADMISSION_DEPTH, siblings, D_ADM_NODE, expected_root)


def verify_entry_proof(leaf: bytes, index: int,
                       siblings: tuple[bytes, ...], expected_root: bytes) -> bool:
    return verify_fixed_tree_proof(
        leaf, index, ENTRY_DEPTH, siblings, D_ENTRY_NODE, expected_root)


def verify_tranche_proof(leaf: bytes, index: int,
                         siblings: tuple[bytes, ...], expected_root: bytes) -> bool:
    return verify_fixed_tree_proof(
        leaf, index, TRANCHE_DEPTH, siblings, D_TRANCHE_NODE, expected_root)


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


def canonical_admission_leaves(
        active: tuple[RegistryCell | None, ...],
        liabilities: tuple[RegistryCell | None, ...]) -> list[bytes]:
    """Materialize the exact 2,048 position-bound admission leaves."""

    assert len(active) == 64 and len(liabilities) == 1_072
    records: dict[int, tuple[int, RegistryCell]] = {}
    records.update({index: (1, cell) for index, cell in enumerate(active)
                    if cell is not None})
    records.update({64 + index: (2, cell)
                    for index, cell in enumerate(liabilities)
                    if cell is not None})
    return [admission_leaf(i, *(records[i] if i in records else (0, None)))
            for i in range(2_048)]


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


def forced_descriptor(envelope: ForcedEnvelope) -> bytes:
    return (
        address20(envelope.sender) + u64(envelope.nonce)
        + u256(envelope.chain_id) + b32(envelope.raw_tx_hash)
        + u32(envelope.byte_length) + u64(envelope.gas_limit)
        + u64(envelope.accounted_gas) + u256(envelope.max_fee)
        + u64(envelope.valid_until) + address20(envelope.refund)
        + u64(envelope.enqueued_at) + u64(envelope.due_at) + u256(envelope.deposit)
    )


def forced_admission(envelope: ForcedEnvelope) -> bytes:
    encoded = (
        address20(envelope.sender) + u64(envelope.nonce)
        + u256(envelope.chain_id) + b32(envelope.raw_tx_hash)
        + u32(envelope.byte_length) + u64(envelope.gas_limit)
        + u64(envelope.accounted_gas) + u256(envelope.max_fee)
        + u64(envelope.valid_until) + address20(envelope.refund)
        + u256(envelope.deposit)
    )
    assert len(encoded) == 204
    return encoded


def forced_leaf(index: int, envelope: ForcedEnvelope) -> bytes:
    descriptor = forced_descriptor(envelope)
    assert len(descriptor) == 220
    return keccak256(D_FORCE_USER + u64(index) + descriptor)


def encode_reward_class_v1_calldata(reward_class: int) -> bytes:
    assert type(reward_class) is int and reward_class in (1, 2, 3)
    encoded = REWARD_CLASS_V1_SELECTOR + u256(reward_class)
    assert len(encoded) == 36
    return encoded


def decode_reward_class_v1_calldata(calldata: bytes) -> int:
    assert (len(calldata) == 36
            and calldata[:4] == REWARD_CLASS_V1_SELECTOR)
    reward_class = uint_word_value(calldata[4:], 8)
    assert reward_class in (1, 2, 3)
    assert calldata == encode_reward_class_v1_calldata(reward_class)
    return reward_class


def encode_reward_class_v1_return(
        builder_registry_configuration_hash: bytes, returned_class_id: int,
        fixed_wei: int, per_execution_gas_wei: int,
        per_published_byte_wei: int, cap_wei: int) -> bytes:
    assert (type(builder_registry_configuration_hash) is bytes
            and len(builder_registry_configuration_hash) == 32
            and builder_registry_configuration_hash != bytes(32)
            and type(returned_class_id) is int
            and returned_class_id in (1, 2, 3)
            and all(type(value) is int and 0 <= value < 1 << 256
                    for value in (fixed_wei, per_execution_gas_wei,
                                  per_published_byte_wei, cap_wei)))
    encoded = (
        bytes4_word(REWARD_CLASS_V1_MAGIC)
        + b32(builder_registry_configuration_hash)
        + u256(returned_class_id) + u256(fixed_wei)
        + u256(per_execution_gas_wei) + u256(per_published_byte_wei)
        + u256(cap_wei))
    assert len(encoded) == REWARD_CLASS_V1_RETURN_LENGTH
    return encoded


def decode_reward_class_v1_return(
        returndata: bytes, expected_configuration_hash: bytes,
        expected_class_id: int) -> tuple[bytes, int, int, int, int, int]:
    assert (len(returndata) == REWARD_CLASS_V1_RETURN_LENGTH
            and bytes4_word_value(returndata[:32])
                == REWARD_CLASS_V1_MAGIC
            and b32(returndata[32:64]) == expected_configuration_hash
            and expected_configuration_hash != bytes(32))
    result = (
        b32(returndata[32:64]), uint_word_value(returndata[64:96], 8),
        uint_word_value(returndata[96:128]),
        uint_word_value(returndata[128:160]),
        uint_word_value(returndata[160:192]),
        uint_word_value(returndata[192:224]),
    )
    assert (type(expected_class_id) is int
            and expected_class_id in (1, 2, 3)
            and result[1] == expected_class_id
            and returndata == encode_reward_class_v1_return(*result))
    return result


def validate_reward_class_v1_getter(
        expected_runtime_hash: bytes, observed_extcodehash: bytes,
        expected_configuration_hash: bytes, expected_class_id: int,
        calldata: bytes, gas_limit: int,
        returndata: bytes) -> tuple[bytes, int, int, int, int, int]:
    """Model the profile-owned BuilderRegistry class-table read."""

    assert (expected_runtime_hash != bytes(32)
            and observed_extcodehash == expected_runtime_hash
            and gas_limit == COMPONENT_CONFIG_GETTER_GAS_LIMIT
            and decode_reward_class_v1_calldata(calldata)
                == expected_class_id)
    return decode_reward_class_v1_return(
        returndata, expected_configuration_hash, expected_class_id)


def forced_queue_config_hash(active_settlement_router: int,
                             initial_active_settlement: int) -> bytes:
    assert active_settlement_router != initial_active_settlement
    encoded = (address20(active_settlement_router)
               + address20(initial_active_settlement) + u8(FORCE_DEPTH)
               + u64(UINT64_MAX) + b32(keccak256(D_FORCE_EMPTY))
               + b32(keccak256(D_FORCED_DESCRIPTOR_SCHEMA)))
    assert len(encoded) == 113
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


@dataclass(frozen=True)
class RegisterForkVerifierPayloadV1:
    fork_digest: bytes
    first_parent_slot: int
    last_parent_slot_exclusive: int
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


SETTLEMENT_VALIDITY_VERIFIER_SELECTOR = keccak256(
    b"verify(bytes,uint256[2])")[:4]
SETTLEMENT_VALIDITY_PUBLIC_INPUT_SCHEMA_HASH = keccak256(
    b"slot-chain-settlement-validity-public-input-schema-v3")
SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES = 65_536
SETTLEMENT_VALIDITY_MAXIMUM_GAS = L1_TRANSACTION_GAS_LIMIT
SETTLEMENT_VALIDITY_VERIFIER_CALL_ENVELOPE_GAS = 10_000
SETTLEMENT_VALIDITY_VERIFIER_RETURN_COPY_GAS = 6
SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPE = (
    b"SettlementValidityVerifierConfigV2(bytes32 verifyingKeyHash,"
    b"bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,"
    b"uint32 maximumProofBytes,uint64 verificationGasLimit,"
    b"uint64 postVerificationReserveGas)")
SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH = keccak256(
    SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPE)
SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_TYPE = (
    b"SettlementValidityVerifierDescriptorV2(address verifier,"
    b"bytes32 runtimeHash,bytes32 configurationHash,bytes32 verifyingKeyHash,"
    b"bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,"
    b"uint32 maximumProofBytes,uint64 verificationGasLimit,"
    b"uint64 postVerificationReserveGas)")
SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
    SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_TYPE)
SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_GETTER_SELECTOR = keccak256(
    b"settlementValidityVerifierDescriptorV2()")[:4]
SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_MAGIC = b"SVD2"
SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_RETURN_LENGTH = 352
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
DATA_SESSION_ACCOUNTING_SELECTOR = keccak256(
    b"dataSessionAccountingV1()")[:4]
DATA_SESSION_ACCOUNTING_MAGIC = b"DSV1"
DATA_SESSION_ACCOUNTING_LENGTH = 512


def eip2935_read_configuration_hash_v1(first_supported_block: int) -> bytes:
    assert 0 < first_supported_block <= UINT64_MAX
    return keccak256(
        EIP2935_READ_CONFIG_DOMAIN
        + address20(L1_EIP2935_HISTORY_STORAGE_ADDRESS)
        + L1_EIP2935_HISTORY_STORAGE_RUNTIME_HASH
        + u64(first_supported_block)
        + u64(EIP2935_HISTORY_SERVE_WINDOW)
        + u64(EIP2935_HISTORY_READ_GAS))


def encode_data_session_accounting_v1(
        live_count: int, refund_count: int, occupied_count: int,
        gc_cursor: int, next_session_sequence: int,
        live_bond_liability: int, refund_bond_liability: int,
        migration_refund_generation: int,
        migration_refund_claim_deadline: int, guard_entered: bool,
        data_session_configuration_hash: bytes,
        reward_funding_class_1: int, reward_funding_class_2: int,
        reward_funding_class_3: int, total_reward_funding: int) -> bytes:
    assert (all(type(value) is int and 0 <= value < 1 << 16
                for value in (live_count, refund_count, occupied_count,
                              gc_cursor))
            and live_count + refund_count == occupied_count
            and all(type(value) is int and 0 <= value <= UINT64_MAX
                    for value in (next_session_sequence,
                                  migration_refund_generation,
                                  migration_refund_claim_deadline))
            and type(guard_entered) is bool
            and type(data_session_configuration_hash) is bytes
            and len(data_session_configuration_hash) == 32
            and data_session_configuration_hash != bytes(32)
            and all(type(value) is int and 0 <= value < 1 << 256
                    for value in (
                        live_bond_liability, refund_bond_liability,
                        reward_funding_class_1, reward_funding_class_2,
                        reward_funding_class_3, total_reward_funding))
            and reward_funding_class_1 + reward_funding_class_2
                + reward_funding_class_3 == total_reward_funding
            and total_reward_funding < 1 << 256)
    encoded = (
        bytes4_word(DATA_SESSION_ACCOUNTING_MAGIC)
        + u256(live_count) + u256(refund_count) + u256(occupied_count)
        + u256(gc_cursor) + u256(next_session_sequence)
        + u256(live_bond_liability) + u256(refund_bond_liability)
        + u256(migration_refund_generation)
        + u256(migration_refund_claim_deadline)
        + u256(1 if guard_entered else 0)
        + b32(data_session_configuration_hash)
        + u256(reward_funding_class_1) + u256(reward_funding_class_2)
        + u256(reward_funding_class_3) + u256(total_reward_funding))
    assert len(encoded) == DATA_SESSION_ACCOUNTING_LENGTH
    return encoded


def encode_empty_data_session_accounting_v1(
        data_session_configuration_hash: bytes) -> bytes:
    return encode_data_session_accounting_v1(
        0, 0, 0, 0, 0, 0, 0, 0, 0, False,
        data_session_configuration_hash, 0, 0, 0, 0)


def decode_data_session_accounting_v1(
        returndata: bytes, expected_configuration_hash: bytes,
        *, require_empty: bool = False
) -> tuple[int, int, int, int, int, int, int, int, int, bool,
           bytes, int, int, int, int]:
    assert (len(returndata) == DATA_SESSION_ACCOUNTING_LENGTH
            and bytes4_word_value(returndata[:32])
                == DATA_SESSION_ACCOUNTING_MAGIC)
    guard_word = uint_word_value(returndata[320:352], 8)
    assert guard_word in (0, 1)
    result = (
        uint_word_value(returndata[32:64], 16),
        uint_word_value(returndata[64:96], 16),
        uint_word_value(returndata[96:128], 16),
        uint_word_value(returndata[128:160], 16),
        uint_word_value(returndata[160:192], 64),
        uint_word_value(returndata[192:224]),
        uint_word_value(returndata[224:256]),
        uint_word_value(returndata[256:288], 64),
        uint_word_value(returndata[288:320], 64),
        guard_word == 1, b32(returndata[352:384]),
        uint_word_value(returndata[384:416]),
        uint_word_value(returndata[416:448]),
        uint_word_value(returndata[448:480]),
        uint_word_value(returndata[480:512]),
    )
    assert (result[10] == expected_configuration_hash
            and expected_configuration_hash != bytes(32)
            and returndata == encode_data_session_accounting_v1(*result))
    if require_empty:
        assert all(value in (0, False) for value in (*result[:10], *result[11:]))
    return result


def settlement_validity_verifier_required_gas_v2(
        verification_gas: int, reserve_gas: int) -> int:
    assert (0 < checked_l1_gas(verification_gas)
            <= SETTLEMENT_VALIDITY_MAXIMUM_GAS
            and 0 < checked_l1_gas(reserve_gas)
            <= SETTLEMENT_VALIDITY_MAXIMUM_GAS)
    return checked_l1_gas(
        l1_call_sequence_minimum_gas((verification_gas,), reserve_gas)
        + SETTLEMENT_VALIDITY_VERIFIER_CALL_ENVELOPE_GAS
        + SETTLEMENT_VALIDITY_VERIFIER_RETURN_COPY_GAS)


def validate_settlement_validity_resources_v2(
        maximum_proof_bytes: int, verification_gas: int, reserve_gas: int,
        supported_block_gas_limit: int) -> None:
    assert 0 < maximum_proof_bytes <= SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES
    required = settlement_validity_verifier_required_gas_v2(
        verification_gas, reserve_gas)
    # Only the maximum proof bytes are counted here: the verifier's internal
    # ABI is not the top-level transaction ABI. This necessary profile bound
    # cannot certify the omitted top-level calldata, prefix, and full suffix.
    validate_l1_transaction_gas(l1_transaction_required_gas(
        0, maximum_proof_bytes, required), supported_block_gas_limit)


def encode_register_fork_verifier_payload(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    assert (len(payload.fork_digest) == 4
            and payload.fork_digest != bytes(4)
            and 0 <= payload.first_parent_slot < payload.last_parent_slot_exclusive
                <= UINT64_MAX
            and payload.verifier != 0 and payload.runtime_hash != bytes(32)
            and payload.beacon_slot_gindex == 8
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
        bytes4_word(payload.fork_digest) + u256(payload.first_parent_slot)
        + u256(payload.last_parent_slot_exclusive)
        + address_word(payload.verifier) + b32(payload.runtime_hash)
        + u256(payload.beacon_slot_gindex)
        + u256(payload.execution_payload_gindex)
        + u256(payload.state_root_gindex) + u256(payload.prev_randao_gindex)
        + u256(payload.timestamp_gindex) + u256(payload.block_hash_gindex)
        + b32(payload.witness_schema_hash) + b32(payload.configuration_hash)
        + bytes4_word(payload.selector)
        + u256(payload.gas_limit))
    assert len(encoded) == 15 * 32
    return encoded


def decode_register_fork_verifier_payload(
        encoded: bytes) -> RegisterForkVerifierPayloadV1:
    assert len(encoded) == 15 * 32
    words = tuple(encoded[index * 32:(index + 1) * 32]
                  for index in range(15))
    payload = RegisterForkVerifierPayloadV1(
        bytes4_word_value(words[0]), uint_word_value(words[1], 64),
        uint_word_value(words[2], 64), address_word_value(words[3]),
        b32(words[4]),
        *(uint_word_value(words[index], 64) for index in range(5, 11)),
        b32(words[11]), b32(words[12]), bytes4_word_value(words[13]),
        uint_word_value(words[14], 64))
    assert encoded == encode_register_fork_verifier_payload(payload)
    return payload


def schedule_fork_registration_hash(
        payload: RegisterForkVerifierPayloadV1) -> bytes:
    encoded = encode_register_fork_verifier_payload(payload)
    return keccak256(
        b"slot-chain-schedule-fork-registration-v1"
        + len(encoded).to_bytes(2, "big") + encoded)


def schedule_fork_sparse_root(
        leaf_domain: bytes, leaves: dict[bytes, bytes]) -> bytes:
    assert (leaf_domain and all(
        len(key) == 4 and key != bytes(4)
        and len(value) == 32 and value != bytes(32)
        for key, value in leaves.items()
    ))
    defaults = [keccak256(leaf_domain + b"\x00")]
    for _ in range(32):
        defaults.append(keccak256(
            leaf_domain + b"\x01" + defaults[-1] + defaults[-1]
        ))
    nodes = {
        int.from_bytes(key, "big"):
            keccak256(leaf_domain + b"\x02" + key + value)
        for key, value in leaves.items()
    }
    for level in range(32):
        parents: dict[int, bytes] = {}
        for parent in {index >> 1 for index in nodes}:
            left = nodes.get(parent << 1, defaults[level])
            right = nodes.get((parent << 1) | 1, defaults[level])
            parents[parent] = keccak256(
                leaf_domain + b"\x01" + left + right
            )
        nodes = parents
    return nodes.get(0, defaults[32])


def schedule_fork_order_hash(order: tuple[bytes, ...]) -> bytes:
    assert (order and len(order) == len(set(order))
            and all(len(digest) == 4 and digest != bytes(4)
                    for digest in order))
    result = keccak256(b"slot-chain-schedule-fork-order-empty-v1")
    for index, digest in enumerate(order):
        result = keccak256(
            b"slot-chain-schedule-fork-order-step-v1"
            + result + u64(index) + digest
        )
    return result


def schedule_fork_route_state_hash(
        registrations: dict[bytes, RegisterForkVerifierPayloadV1],
        order: tuple[bytes, ...], used_fork_digests: frozenset[bytes]) -> bytes:
    assert (order and len(order) == len(set(order))
            and all(digest in registrations for digest in order)
            and all(len(digest) == 4 and digest != bytes(4)
                    for digest in registrations)
            and all(len(digest) == 4 and digest != bytes(4)
                    for digest in used_fork_digests))
    registration_root = schedule_fork_sparse_root(
        b"slot-chain-schedule-fork-registration-smt-v1",
        {
            digest: schedule_fork_registration_hash(payload)
            for digest, payload in registrations.items()
        },
    )
    used_root = schedule_fork_sparse_root(
        b"slot-chain-schedule-fork-used-smt-v1",
        {digest: keccak256(
            b"slot-chain-schedule-fork-used-leaf-v1" + digest
        ) for digest in used_fork_digests},
    )
    return keccak256(
        b"slot-chain-schedule-fork-route-state-v1"
        + schedule_fork_order_hash(order)
        + registration_root + used_root
        + u64(len(order)) + u64(len(registrations))
        + u64(len(used_fork_digests)))


def encode_schedule_fork_route_state_return(
        registrations: dict[bytes, RegisterForkVerifierPayloadV1],
        order: tuple[bytes, ...], used_fork_digests: frozenset[bytes]) -> bytes:
    encoded = (
        bytes4_word(SCHEDULE_FORK_ROUTE_STATE_MAGIC)
        + schedule_fork_route_state_hash(
            registrations, order, used_fork_digests)
        + u256(len(order)) + u256(len(registrations))
        + u256(len(used_fork_digests)))
    assert len(encoded) == 160
    return encoded


def decode_schedule_fork_route_state_return(
        returndata: bytes) -> tuple[bytes, int, int, int]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == SCHEDULE_FORK_ROUTE_STATE_MAGIC)
    result = (
        b32(returndata[32:64]),
        uint_word_value(returndata[64:96], 64),
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64),
    )
    assert result[0] != bytes(32)
    return result


@dataclass(frozen=True)
class ForkVerifierRegistrationV1:
    fork_digest: bytes
    first_parent_slot: int
    successor_fork_digest: bytes
    last_parent_slot_exclusive: int
    verifier: int
    runtime_hash: bytes
    configuration_hash: bytes
    selector: bytes
    gas_limit: int


@dataclass(frozen=True)
class ScheduleCarrierOutputV1:
    statement_hash: bytes
    parent_slot: int
    parent_execution_block_number: int
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
            and payload.beacon_slot_gindex == 8
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
    assert len(encoded) == 484
    return encoded


def decode_install_fork_verifier_calldata(
        calldata: bytes) -> RegisterForkVerifierPayloadV1:
    assert calldata[:4] == INSTALL_FORK_VERIFIER_SELECTOR
    payload = decode_register_fork_verifier_payload(calldata[4:])
    assert calldata == encode_install_fork_verifier_calldata(payload)
    return payload


def encode_install_fork_verifier_return(
        fork_digest: bytes, first_parent_slot: int) -> bytes:
    assert (len(fork_digest) == 4 and fork_digest != bytes(4)
            and 0 <= first_parent_slot <= UINT64_MAX)
    encoded = (bytes4_word(FORK_VERIFIER_INSTALL_MAGIC)
               + bytes4_word(fork_digest) + u256(first_parent_slot))
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


def encode_replace_pending_fork_verifier_calldata(
        expected_predecessor_registration_hash: bytes,
        expected_old_registration_hash: bytes,
        replacement: RegisterForkVerifierPayloadV1) -> bytes:
    assert (expected_predecessor_registration_hash != bytes(32)
            and expected_old_registration_hash != bytes(32))
    encoded = (REPLACE_PENDING_FORK_VERIFIER_SELECTOR
               + b32(expected_predecessor_registration_hash)
               + b32(expected_old_registration_hash)
               + encode_register_fork_verifier_payload(replacement))
    assert len(encoded) == 548
    return encoded


def decode_replace_pending_fork_verifier_calldata(
        calldata: bytes
        ) -> tuple[bytes, bytes, RegisterForkVerifierPayloadV1]:
    assert (len(calldata) == 548
            and calldata[:4] == REPLACE_PENDING_FORK_VERIFIER_SELECTOR)
    result = (
        b32(calldata[4:36]), b32(calldata[36:68]),
        decode_register_fork_verifier_payload(calldata[68:]),
    )
    assert calldata == encode_replace_pending_fork_verifier_calldata(*result)
    return result


def encode_split_latest_fork_verifier_calldata(
        expected_old_registration_hash: bytes,
        successor: RegisterForkVerifierPayloadV1) -> bytes:
    assert expected_old_registration_hash != bytes(32)
    encoded = (SPLIT_LATEST_FORK_VERIFIER_SELECTOR
               + b32(expected_old_registration_hash)
               + encode_register_fork_verifier_payload(successor))
    assert len(encoded) == 516
    return encoded


def decode_split_latest_fork_verifier_calldata(
        calldata: bytes) -> tuple[bytes, RegisterForkVerifierPayloadV1]:
    assert (len(calldata) == 516
            and calldata[:4] == SPLIT_LATEST_FORK_VERIFIER_SELECTOR)
    result = (b32(calldata[4:36]),
              decode_register_fork_verifier_payload(calldata[36:]))
    assert calldata == encode_split_latest_fork_verifier_calldata(*result)
    return result


def encode_replace_pending_fork_verifier_return(
        old_digest: bytes, new_digest: bytes,
        new_first_parent_slot: int,
        new_last_parent_slot_exclusive: int) -> bytes:
    assert (len(old_digest) == len(new_digest) == 4
            and old_digest != bytes(4) and new_digest != bytes(4)
            and 0 <= new_first_parent_slot < new_last_parent_slot_exclusive
                <= UINT64_MAX)
    encoded = (bytes4_word(bytes.fromhex("46565031"))
               + bytes4_word(old_digest) + bytes4_word(new_digest)
               + u256(new_first_parent_slot)
               + u256(new_last_parent_slot_exclusive))
    assert len(encoded) == 160
    return encoded


def decode_replace_pending_fork_verifier_return(
        returndata: bytes) -> tuple[bytes, bytes, int, int]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == bytes.fromhex("46565031"))
    result = (
        bytes4_word_value(returndata[32:64]),
        bytes4_word_value(returndata[64:96]),
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64),
    )
    assert returndata == encode_replace_pending_fork_verifier_return(*result)
    return result


def encode_split_latest_fork_verifier_return(
        old_digest: bytes, successor_digest: bytes,
        boundary_parent_slot: int,
        successor_last_parent_slot_exclusive: int) -> bytes:
    assert (len(old_digest) == len(successor_digest) == 4
            and old_digest != bytes(4) and successor_digest != bytes(4)
            and old_digest != successor_digest
            and 0 <= boundary_parent_slot
                < successor_last_parent_slot_exclusive <= UINT64_MAX)
    encoded = (bytes4_word(bytes.fromhex("46565331"))
               + bytes4_word(old_digest) + bytes4_word(successor_digest)
               + u256(boundary_parent_slot)
               + u256(successor_last_parent_slot_exclusive))
    assert len(encoded) == 160
    return encoded


def decode_split_latest_fork_verifier_return(
        returndata: bytes) -> tuple[bytes, bytes, int, int]:
    assert (len(returndata) == 160
            and bytes4_word_value(returndata[:32])
                == bytes.fromhex("46565331"))
    result = (
        bytes4_word_value(returndata[32:64]),
        bytes4_word_value(returndata[64:96]),
        uint_word_value(returndata[96:128], 64),
        uint_word_value(returndata[128:160], 64),
    )
    assert returndata == encode_split_latest_fork_verifier_return(*result)
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
            and 0 <= row.first_parent_slot < row.last_parent_slot_exclusive
                <= UINT64_MAX
            and row.verifier != 0 and row.runtime_hash != bytes(32)
            and row.configuration_hash != bytes(32)
            and row.selector == VERIFY_SCHEDULE_CARRIER_SELECTOR
            and MINIMUM_FORK_VERIFIER_GAS <= row.gas_limit
                <= MAXIMUM_FORK_VERIFIER_GAS)
    if row.successor_fork_digest != bytes(4):
        assert (len(row.successor_fork_digest) == 4
                and row.successor_fork_digest != row.fork_digest)
    encoded = (
        bytes4_word(FORK_VERIFIER_REGISTRATION_MAGIC)
        + bytes4_word(row.fork_digest) + u256(row.first_parent_slot)
        + bytes4_word(row.successor_fork_digest)
        + u256(row.last_parent_slot_exclusive) + address_word(row.verifier)
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


def fork_verifier_registration_covers_parent_slot(
        row: ForkVerifierRegistrationV1, parent_slot: int) -> bool:
    assert 0 <= parent_slot <= UINT64_MAX
    encode_fork_verifier_registration_return(row)
    return (row.first_parent_slot <= parent_slot
            < row.last_parent_slot_exclusive)


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
        first_parent_slot: int, last_parent_slot_exclusive: int, selector: bytes,
        gas_limit: int) -> RegisterForkVerifierPayloadV1:
    assert (len(returndata) == 320
            and bytes4_word_value(returndata[:32])
                == SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC)
    payload = RegisterForkVerifierPayloadV1(
        bytes4_word_value(returndata[32:64]), first_parent_slot,
        last_parent_slot_exclusive, verifier, b32(runtime_hash),
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
        parent_execution_block_number: int, payload_timestamp: int,
        block_hash: bytes, state_root: bytes, prev_randao: bytes) -> bytes:
    narrow = (
        window, parent_slot, parent_execution_block_number, payload_timestamp
    )
    assert (settlement_chain_id > 0 and schedule_oracle != 0
            and len(fork_digest) == 4 and fork_digest != bytes(4)
            and all(0 <= value <= UINT64_MAX for value in narrow)
            and all(value != bytes(32) for value in (
                beacon_block_root, block_hash, state_root, prev_randao)))
    return keccak256(
        D_SCHEDULE_CARRIER_STATEMENT + u256(settlement_chain_id)
        + address20(schedule_oracle) + fork_digest + u64(window)
        + b32(beacon_block_root) + u64(parent_slot)
        + u64(parent_execution_block_number) + u64(payload_timestamp)
        + b32(block_hash) + b32(state_root) + b32(prev_randao))


def schedule_execution_payload_is_parent(
        parent_execution_block_number: int,
        carrier_header_block_number: int) -> bool:
    assert (0 <= parent_execution_block_number <= UINT64_MAX
            and 0 <= carrier_header_block_number <= UINT64_MAX)
    return (parent_execution_block_number < UINT64_MAX
            and parent_execution_block_number + 1
                == carrier_header_block_number)


def encode_schedule_carrier_return(output: ScheduleCarrierOutputV1) -> bytes:
    assert (output.statement_hash != bytes(32)
            and all(0 <= value <= UINT64_MAX for value in (
                output.parent_slot, output.parent_execution_block_number,
                output.payload_timestamp))
            and all(value != bytes(32) for value in (
                output.block_hash, output.state_root, output.prev_randao)))
    encoded = (
        bytes4_word(SCHEDULE_FORK_CARRIER_MAGIC) + b32(output.statement_hash)
        + u256(output.parent_slot)
        + u256(output.parent_execution_block_number)
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


def force_descriptor_list(start: int,
                          consumed: tuple[tuple[int, bytes], ...],
                          boundary: tuple[int, bytes] | None) -> bytes:
    rows = consumed + (() if boundary is None else (boundary,))
    assert (type(start) is int and 0 <= start <= UINT64_MAX
            and len(consumed) <= 256 and len(rows) <= 257
            and (not rows or len(rows) <= UINT64_MAX - start))
    assert all(
        type(kind) is int and kind == 0
        and type(descriptor) is bytes
        and len(descriptor) == 220
        for kind, descriptor in rows
    )
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


def data_node(height: int, left: bytes, right: bytes) -> bytes:
    """Hash one fixed data-MMR node without performing frontier traversal."""

    return keccak256(D_MMR_NODE + u8(height) + b32(left) + b32(right))


def data_bag(count: int, peaks: tuple[tuple[int, bytes], ...]) -> bytes:
    """Hash the unique ascending-height peak encoding for one record count."""

    expected_heights = tuple(
        height for height in range(12) if (count >> height) & 1)
    assert (type(count) is int and 0 <= count <= 2_100
            and tuple(height for height, _ in peaks) == expected_heights)
    encoded = b"".join(u8(height) + b32(node) for height, node in peaks)
    return keccak256(D_MMR_BAG + u16(count) + u8(len(peaks)) + encoded)


def mmr_root(leaves: tuple[bytes, ...]) -> bytes:
    assert len(leaves) <= 2_100
    peaks: list[tuple[int, bytes]] = []
    for leaf in leaves:
        height, node = 0, b32(leaf)
        while peaks and peaks[-1][0] == height:
            _, left = peaks.pop()
            node = data_node(height, left, node)
            height += 1
        peaks.append((height, node))
    return data_bag(len(leaves), tuple(reversed(peaks)))


def append_mmr_frontier(frontier: tuple[bytes, ...], count: int,
                        leaf: bytes) -> tuple[bytes, ...]:
    """Append one exact Appendix data leaf to the 12-word session frontier."""

    assert len(frontier) == 12 and 0 <= count < 2_100
    updated = [b32(node) for node in frontier]
    carry, height = b32(leaf), 0
    while (count >> height) & 1:
        carry = data_node(height, updated[height], carry)
        height += 1
    updated[height] = carry
    return tuple(updated)


def mmr_frontier_root(frontier: tuple[bytes, ...], count: int) -> bytes:
    """Bag set-bit peaks rightmost-to-leftmost: ascending stored height."""

    assert len(frontier) == 12 and 0 <= count <= 2_100
    heights = tuple(height for height in range(12) if (count >> height) & 1)
    return data_bag(
        count, tuple((height, frontier[height]) for height in heights))


@dataclass(frozen=True)
class DataMmrProofV1:
    """Minimal proof: every height, base and orientation is derived."""

    mountain_siblings: tuple[bytes, ...]
    other_peaks: tuple[bytes, ...]

    def __post_init__(self) -> None:
        assert (type(self.mountain_siblings) is tuple
                and type(self.other_peaks) is tuple)
        for node in self.mountain_siblings + self.other_peaks:
            b32(node)


def data_mmr_target(count: int, index: int) -> tuple[int, int]:
    """Derive the unique target mountain height and base from public inputs."""

    assert (type(count) is int and type(index) is int
            and 0 < count <= 2_100 and 0 <= index < count)
    base = 0
    for height in range(11, -1, -1):
        if not (count >> height) & 1:
            continue
        next_base = base + (1 << height)
        if index < next_base:
            return height, base
        base = next_base
    raise AssertionError("MMR target mountain not found")


def data_mmr_proof(leaves: tuple[bytes, ...], index: int) -> DataMmrProofV1:
    """Generate the canonical minimal inclusion proof for one data-MMR leaf."""

    count = len(leaves)
    target_height, target_base = data_mmr_target(count, index)
    peaks: dict[int, bytes] = {}
    base = 0
    target_siblings: tuple[bytes, ...] | None = None
    for height in range(11, -1, -1):
        if not (count >> height) & 1:
            continue
        size = 1 << height
        mountain = [b32(leaf) for leaf in leaves[base:base + size]]
        peaks[height] = (mountain[0] if height == 0
                         else fixed_root(mountain, D_MMR_NODE))
        if height == target_height and base == target_base:
            target_siblings = fixed_tree_proof(
                mountain, index - base, D_MMR_NODE)
        base += size
    assert base == count and target_siblings is not None
    other_peaks = tuple(
        peaks[height] for height in range(12)
        if (count >> height) & 1 and height != target_height)
    return DataMmrProofV1(target_siblings, other_peaks)


def verify_data_mmr_proof(count: int, index: int, leaf: bytes,
                          proof: DataMmrProofV1,
                          expected_root: bytes) -> bool:
    """Verify DataMmrProofV1 without caller-supplied height/orientation metadata."""

    if type(proof) is not DataMmrProofV1:
        return False
    try:
        target_height, target_base = data_mmr_target(count, index)
        if (len(proof.mountain_siblings) != target_height
                or len(proof.other_peaks) != bin(count).count("1") - 1):
            return False
        node = b32(leaf)
        local_index = index - target_base
        for height, sibling in enumerate(proof.mountain_siblings):
            sibling = b32(sibling)
            node = (data_node(height, sibling, node)
                    if (local_index >> height) & 1 else
                    data_node(height, node, sibling))
        peaks: list[tuple[int, bytes]] = []
        other_at = 0
        for height in range(12):
            if not (count >> height) & 1:
                continue
            if height == target_height:
                peaks.append((height, node))
            else:
                peaks.append((height, b32(proof.other_peaks[other_at])))
                other_at += 1
        return (other_at == len(proof.other_peaks)
                and data_bag(count, tuple(peaks)) == b32(expected_root))
    except (AssertionError, IndexError):
        return False


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


def manifest_node(height: int, left: bytes, right: bytes) -> bytes:
    """Hash one fixed manifest-tree node without performing tree construction."""

    return keccak256(D_MANIFEST_NODE + u8(height) + b32(left) + b32(right))


def manifest_root(expected_block_ordinal: int,
                  entries: tuple[ManifestEntry, ...]) -> bytes:
    assert (type(expected_block_ordinal) is int
            and 0 <= expected_block_ordinal < 4_096
            and len(entries) <= 2_100
            and all(entry.block_ordinal == expected_block_ordinal
                    for entry in entries))
    if not entries:
        return keccak256(D_MANIFEST_ROOT + u16(0) + keccak256(D_MANIFEST_EMPTY))
    leaves = [manifest_leaf(i, entry) for i, entry in enumerate(entries)]
    size = 1
    while size < len(leaves):
        size *= 2
    leaves.extend([keccak256(D_MANIFEST_EMPTY)] * (size - len(leaves)))
    return keccak256(D_MANIFEST_ROOT + u16(len(entries))
                     + fixed_root(leaves, D_MANIFEST_NODE))


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
    profile_hash = PROFILE_HASH_FIXTURE
    tranche = tranche_leaf(7, 519, 2, 10**17, 999_999)
    cell = RegistryCell(0x1234, 10**18, 9, 777, bytes.fromhex("11" * 32), UINT64_MAX)
    cells = [None] * 64
    cells[3] = cell
    reg_root = registry_root(tuple(cells))
    empty_registry_root = registry_root((None,) * 64)
    liabilities = [None] * 1_072
    liabilities[0] = cell
    adm_root = canonical_admission_root(tuple(cells), tuple(liabilities))
    empty_admission_root = canonical_admission_root(
        (None,) * 64, (None,) * 1_072)
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
    empty_entry_root = fixed_root(
        [entry_leaf(i, None, None) for i in range(64)], D_ENTRY_NODE)
    registry_proof = fixed_tree_proof(
        [registry_leaf(i, value) for i, value in enumerate(cells)], 3,
        D_REG_NODE)
    proof_liabilities = (cell, *((None,) * 1_071))
    admission_leaves = canonical_admission_leaves(
        tuple(cells), proof_liabilities)
    admission_proof = fixed_tree_proof(admission_leaves, 64, D_ADM_NODE)
    entry_proof = fixed_tree_proof(entries, 0, D_ENTRY_NODE)
    tranche_leaves = [
        tranche if index == 7
        else tranche_leaf(index, UINT64_MAX, 0, 0, 0)
        for index in range(512)
    ]
    tranche_root_hash = fixed_root(tranche_leaves, D_TRANCHE_NODE)
    empty_tranche_root = fixed_root(
        [tranche_leaf(index, UINT64_MAX, 0, 0, 0)
         for index in range(512)], D_TRANCHE_NODE)
    tranche_proof = fixed_tree_proof(tranche_leaves, 7, D_TRANCHE_NODE)
    registry_leaf_3 = registry_leaf(3, cell)
    admission_leaf_64 = admission_leaf(64, 2, cell)
    entry_leaf_0 = entries[0]
    assert (len(registry_proof) == REGISTRY_DEPTH
            and len(admission_proof) == ADMISSION_DEPTH
            and len(entry_proof) == ENTRY_DEPTH
            and len(tranche_proof) == TRANCHE_DEPTH)
    assert verify_registry_proof(
        registry_leaf_3, 3, registry_proof, reg_root)
    assert verify_admission_proof(
        admission_leaf_64, 64, admission_proof, adm_root)
    assert verify_entry_proof(entry_leaf_0, 0, entry_proof, ent_root)
    assert verify_tranche_proof(tranche, 7, tranche_proof, tranche_root_hash)
    assert (registry_leaf(0, None) != registry_leaf(1, None)
            and admission_leaf(0, 0, None) != admission_leaf(1, 0, None)
            and entry_leaf(0, None, None) != entry_leaf(1, None, None)
            and tranche_leaf(0, UINT64_MAX, 0, 0, 0)
                != tranche_leaf(1, UINT64_MAX, 0, 0, 0))
    assert not verify_registry_proof(
        registry_leaf_3, 2, registry_proof, reg_root), \
        "fixed-tree proof accepted caller orientation through a wrong index"
    assert not verify_registry_proof(
        registry_leaf_3, 3, registry_proof[:-1], reg_root), \
        "fixed-tree proof accepted a missing sibling"
    assert not verify_registry_proof(
        registry_leaf_3, 3, registry_proof + (bytes(32),), reg_root), \
        "fixed-tree proof accepted an extra sibling"
    assert not verify_registry_proof(
        registry_leaf_3, 3, tuple(reversed(registry_proof)), reg_root), \
        "fixed-tree proof accepted reversed sibling heights"
    changed_registry_proof = (
        bytes.fromhex("a3" * 32), *registry_proof[1:])
    assert not verify_registry_proof(
        registry_leaf_3, 3, changed_registry_proof, reg_root), \
        "fixed-tree proof accepted a substituted sibling"
    assert not verify_registry_proof(
        registry_leaf_3, 3, registry_proof, bytes.fromhex("a4" * 32)), \
        "fixed-tree proof accepted the wrong root"

    # BuilderRegistry's move grammar is liability-first.  The active proof is
    # necessarily rooted in the intermediate tree, not the common pre-root.
    move_victim = RegistryCell(
        0xB001, 1_000, 1, 3_072, empty_tranche_root, UINT64_MAX)
    move_replacement = RegistryCell(
        0xB002, 1_001, 2, 3_073, empty_tranche_root, UINT64_MAX)
    move_active = [None] * 64
    move_active[0] = move_victim
    move_liabilities = [None] * 1_072
    move_pre_leaves = canonical_admission_leaves(
        tuple(move_active), tuple(move_liabilities))
    move_pre_root = fixed_root(move_pre_leaves, D_ADM_NODE)
    liability_64_proof = fixed_tree_proof(
        move_pre_leaves, 64, D_ADM_NODE)
    move_intermediate_root = root_from_fixed_tree_proof(
        admission_leaf(64, 2, move_victim), 64, ADMISSION_DEPTH,
        liability_64_proof, D_ADM_NODE)
    move_liabilities[0] = move_victim
    move_intermediate_leaves = canonical_admission_leaves(
        tuple(move_active), tuple(move_liabilities))
    assert fixed_root(move_intermediate_leaves, D_ADM_NODE) \
        == move_intermediate_root
    active_0_intermediate_proof = fixed_tree_proof(
        move_intermediate_leaves, 0, D_ADM_NODE)
    active_0_pre_proof = fixed_tree_proof(move_pre_leaves, 0, D_ADM_NODE)
    move_final_root = root_from_fixed_tree_proof(
        admission_leaf(0, 1, move_replacement), 0, ADMISSION_DEPTH,
        active_0_intermediate_proof, D_ADM_NODE)
    assert not verify_admission_proof(
        admission_leaf(0, 1, move_replacement), 0, active_0_pre_proof,
        move_final_root), "pair proofs against one pre-root were accepted"
    move_active[0] = move_replacement
    assert canonical_admission_root(
        tuple(move_active), tuple(move_liabilities)) == move_final_root

    cell_63_active = [None] * 64
    cell_63_active[63] = move_replacement
    cell_63_admission_root = canonical_admission_root(
        tuple(cell_63_active), (None,) * 1_072)
    cell_63_leaves = canonical_admission_leaves(
        tuple(cell_63_active), (None,) * 1_072)
    cell_63_proof = fixed_tree_proof(cell_63_leaves, 63, D_ADM_NODE)
    assert verify_admission_proof(
        admission_leaf(63, 1, move_replacement), 63, cell_63_proof,
        cell_63_admission_root)

    br_header = builder_registry_header(63, 0x0102030405060708,
                                        0x1112131415161718,
                                        0x2122232425262728)
    assert len(br_header) == 32 and br_header[:8] == b"BRH1\x01?\x00\x00"
    assert decode_builder_registry_header(br_header) == (
        63, 0x0102030405060708, 0x1112131415161718,
        0x2122232425262728,
    )
    br_exhausted_header = builder_registry_header(
        64, UINT64_MAX, UINT64_MAX, UINT64_MAX + 1
    )
    assert br_exhausted_header[:8] == b"BRH1\x01@\x01\x00"
    assert br_exhausted_header[24:] == bytes(8)
    assert decode_builder_registry_header(br_exhausted_header) == (
        64, UINT64_MAX, UINT64_MAX, UINT64_MAX + 1,
    )
    for noncanonical_br_header in (
        br_exhausted_header[:6] + b"\x02" + br_exhausted_header[7:],
        br_exhausted_header[:7] + b"\x01" + br_exhausted_header[8:],
        br_exhausted_header[:24] + u64(1),
    ):
        try:
            decode_builder_registry_header(noncanonical_br_header)
        except ValueError:
            pass
        else:
            raise AssertionError("noncanonical BRH1 word was accepted")
    br_header_trie_key = keccak256(BUILDER_REGISTRY_HEADER_SLOT)
    br_root_trie_key = keccak256(BUILDER_REGISTRY_ROOT_SLOT)
    assert br_header_trie_key.hex() == (
        "3dc336ad17079f9525d2b0708a8773321ab29957d522a6f2d10fc522b7362aec"
    )
    assert br_root_trie_key.hex() == (
        "04bafd6333ae949248e59a002ce1fbccb8a4bc8da3a0c3228ae523d727170880"
    )
    assert BUILDER_REGISTRY_SELECTORS == {
        "admission_state_selector": bytes.fromhex("4a9dfa3f"),
        "schedule_registry_state_selector": bytes.fromhex("ad95cea1"),
        "register_builder_selector": bytes.fromhex("5fc42c69"),
        "reserve_builder_window_selector": bytes.fromhex("46a53315"),
        "request_builder_exit_selector": bytes.fromhex("c8f20b55"),
        "process_builder_maintenance_selector": bytes.fromhex("0e1ffc68"),
        "normalize_builder_tranches_selector": bytes.fromhex("5e7c8a" "fe"),
        "release_builder_tranche_selector": bytes.fromhex("f8668bb9"),
        "release_builder_generation_selector": bytes.fromhex("e7bae370"),
        "claim_builder_lease_credit_selector": bytes.fromhex("8f73793c"),
        "submit_builder_equivocation_selector": bytes.fromhex("979c1f72"),
        "schedule_window_release_selector": bytes.fromhex("f4cd9a5e"),
        "expire_schedule_windows_selector": bytes.fromhex("b1357479"),
        "settlement_schedule_release_selector": bytes.fromhex("a4574c77"),
    }
    admission_state_return = (
        bytes4_word(b"ADS1") + u256(7) + move_final_root)
    schedule_registry_state_return = (
        bytes4_word(b"BRS1") + u256(1) + u256(63) + u256(9)
        + u256(7) + u256(42) + reg_root)
    schedule_window_release_return = (
        bytes4_word(b"SWR1") + u256(512) + u256(3) + u256(513) + ent_root)
    settlement_schedule_release_return = (
        bytes4_word(b"SSR1") + u256(512) + u256(2) + u256(200_000)
        + u256(197_000) + u256(0))
    assert (len(admission_state_return) == 96
            and len(schedule_registry_state_return) == 224
            and len(schedule_window_release_return) == 160
            and len(settlement_schedule_release_return) == 192)
    assert (1071 % 1072 == 1071 and 64 + 1071 == 1135
            and 1072 % 1072 == 0 and 64 + 0 == 64)
    envs = tuple(ForcedEnvelope(0xCAFE, i, l2_chain_id, keccak256(u64(i)), 123, 80_000,
                                80_000, 10**12, 9_999, 0xBEEF, 555,
                                2_055 + i, 10**15) for i in range(70))
    force_leaves = tuple(forced_leaf(i, env) for i, env in enumerate(envs))
    force = ForceVector(force_leaves)
    proof = force.range_proof(2, 66)
    force_frontier_after_1 = append_fixed_frontier(
        tuple(bytes(32) for _ in range(FORCE_DEPTH)), 0, force_leaves[0],
        D_FORCE_NODE)
    force_frontier_root_1 = force_frontier_root(force_frontier_after_1, 1)
    assert force_frontier_root_1 == ForceVector(force_leaves[:1]).root
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

    empty_data_session_accounting_return = \
        encode_empty_data_session_accounting_v1(session_config_hash)
    funded_data_session_accounting_return = encode_data_session_accounting_v1(
        0, 0, 0, 0, 0, 0, 0, 0, 0, False, session_config_hash,
        1_000, 2_000, 3_000, 6_000)
    assert decode_data_session_accounting_v1(
        empty_data_session_accounting_return, session_config_hash,
        require_empty=True)[11:] == (0, 0, 0, 0)
    assert decode_data_session_accounting_v1(
        funded_data_session_accounting_return, session_config_hash)[11:] \
        == (1_000, 2_000, 3_000, 6_000)
    for malformed_accounting_return in (
            funded_data_session_accounting_return[:-1],
            funded_data_session_accounting_return + b"\x00",
            b"BAD!" + funded_data_session_accounting_return[4:],
            funded_data_session_accounting_return[:32] + b"\x01"
                + funded_data_session_accounting_return[33:],
            funded_data_session_accounting_return[:320] + u256(2)
                + funded_data_session_accounting_return[352:],
            funded_data_session_accounting_return[:480] + u256(6_001)):
        assert_rejects(
            lambda value=malformed_accounting_return:
                decode_data_session_accounting_v1(value, session_config_hash),
            "malformed 512-byte DataSession accounting return accepted")
    assert_rejects(
        lambda: decode_data_session_accounting_v1(
            funded_data_session_accounting_return,
            bytes.fromhex("a5" * 32)),
        "wrong DataSession configuration accepted by accounting view")
    assert (DATA_SESSION_ACCOUNTING_SELECTOR
                == keccak256(b"dataSessionAccountingV1()")[:4]
            and len(empty_data_session_accounting_return) == 512)
    session_function_selectors = {
        key: keccak256(signature)[:4]
        for key, signature in DATA_SESSION_FUNCTION_SIGNATURES.items()
    }
    session_event_topics = {
        key: keccak256(signature)
        for key, signature in DATA_SESSION_EVENT_SIGNATURES.items()
    }
    reward_event_topics = {
        key: keccak256(signature)
        for key, signature in REWARD_EVENT_SIGNATURES.items()
    }
    assert reward_event_topics["candidate_committed_v2_topic"].hex() == (
        "51629f6515f461b4c6f912a8eecad46d8ff89ab5e8235d95c30004be2c9ac738"
    )
    assert reward_event_topics["reward_class_funded_v1_topic"].hex() == (
        "d979ecc5f5821fb9e6643744111b04290fc1da57eebaba07def52e526c6eb49e"
    )
    assert reward_event_topics["reward_claimed_v1_topic"].hex() == (
        "9f41046da255bf29062408ae9f20e06ea2453df29227caf32b709ccfed59d506"
    )
    assert len(set(session_function_selectors.values())) == len(
        session_function_selectors
    )
    assert len(set(session_event_topics.values())) == len(session_event_topics)
    body = body_root((bytes.fromhex("0102"), bytes.fromhex("030405")))
    chunk0, chunk1, chunk2 = b"alpha", b"beta", b"gamma"
    c0, c1 = chunk_root(body, 0, 0, 2, chunk0), chunk_root(body, 0, 1, 2, chunk1)
    leaf0 = data_leaf(sid, 0, bytes.fromhex("33" * 32), body, 0, 0, 2,
                      chunk0, 0xCAFE, 9_999, 5, 6)
    leaf1 = data_leaf(sid, 1, bytes.fromhex("55" * 32), body, 0, 1, 2,
                      chunk1, 0xCAFE, 9_999, 7, 8)
    leaf2 = data_leaf(sid, 2, bytes.fromhex("77" * 32), body, 1, 0, 1,
                      chunk2, 0xBEEF, 10_001, 9, 10)
    mmr_frontier = tuple(bytes(32) for _ in range(12))
    mmr_frontier = append_mmr_frontier(mmr_frontier, 0, leaf0)
    mmr_frontier = append_mmr_frontier(mmr_frontier, 1, leaf1)
    assert mmr_frontier_root(mmr_frontier, 2) == mmr_root((leaf0, leaf1))
    data_mmr_frontier_after_3 = append_mmr_frontier(
        mmr_frontier, 2, leaf2)
    data_mmr_frontier_root_3 = mmr_frontier_root(
        data_mmr_frontier_after_3, 3)
    assert data_mmr_frontier_root_3 == mmr_root((leaf0, leaf1, leaf2))
    mmr_node_01 = data_node(0, leaf0, leaf1)
    mmr_root_3 = mmr_root((leaf0, leaf1, leaf2))
    assert mmr_root(()) == data_bag(0, ())
    assert mmr_root_3 == data_bag(3, ((0, leaf2), (1, mmr_node_01)))
    assert_rejects(
        lambda: data_bag(3, ((1, mmr_node_01), (0, leaf2))),
        "descending data-bag peaks accepted")
    proof_leaves = tuple(
        keccak256(b"slot-chain-round3-mmr-proof-fixture-v1" + u16(index))
        for index in range(15)
    )
    data_mmr_proof_count = len(proof_leaves)
    data_mmr_proof_index = 10
    data_mmr_proof_leaf = proof_leaves[data_mmr_proof_index]
    data_mmr_proof_root = mmr_root(proof_leaves)
    data_mmr_proof_fixture = data_mmr_proof(
        proof_leaves, data_mmr_proof_index)
    assert (tuple(field.name for field in fields(DataMmrProofV1)) == (
                "mountain_siblings", "other_peaks")
            and data_mmr_target(
                data_mmr_proof_count, data_mmr_proof_index) == (2, 8)
            and len(data_mmr_proof_fixture.mountain_siblings) == 2
            and len(data_mmr_proof_fixture.other_peaks) == 3)
    assert verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        data_mmr_proof_fixture, data_mmr_proof_root)
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index + 1, data_mmr_proof_leaf,
        data_mmr_proof_fixture, data_mmr_proof_root), \
        "data MMR proof accepted a wrong index"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count - 1, data_mmr_proof_index, data_mmr_proof_leaf,
        data_mmr_proof_fixture, data_mmr_proof_root), \
        "data MMR proof accepted a wrong count"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        data_mmr_proof_fixture, bytes.fromhex("d3" * 32)), \
        "data MMR proof accepted a wrong wrapped root"
    wrong_target_proof = data_mmr_proof(proof_leaves, 2)
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        wrong_target_proof, data_mmr_proof_root), \
        "data MMR proof accepted siblings from the wrong target mountain/base"
    wrong_orientation_proof = data_mmr_proof(
        proof_leaves, data_mmr_proof_index + 1)
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        wrong_orientation_proof, data_mmr_proof_root), \
        "data MMR proof accepted sibling orientation from another leaf"
    changed_mountain_siblings = (
        bytes.fromhex("d4" * 32),
        *data_mmr_proof_fixture.mountain_siblings[1:])
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                mountain_siblings=changed_mountain_siblings),
        data_mmr_proof_root), \
        "data MMR proof accepted a substituted mountain sibling"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                mountain_siblings=data_mmr_proof_fixture.mountain_siblings[:-1]),
        data_mmr_proof_root), \
        "data MMR proof accepted a missing mountain sibling"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                mountain_siblings=(
                    *data_mmr_proof_fixture.mountain_siblings, bytes(32))),
        data_mmr_proof_root), \
        "data MMR proof accepted an extra mountain sibling"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                other_peaks=tuple(reversed(data_mmr_proof_fixture.other_peaks))),
        data_mmr_proof_root), \
        "data MMR proof accepted reversed other-peak order"
    changed_other_peaks = (
        bytes.fromhex("d5" * 32), *data_mmr_proof_fixture.other_peaks[1:])
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture, other_peaks=changed_other_peaks),
        data_mmr_proof_root), \
        "data MMR proof accepted a substituted other peak"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                other_peaks=data_mmr_proof_fixture.other_peaks[:-1]),
        data_mmr_proof_root), \
        "data MMR proof accepted a missing other peak"
    assert not verify_data_mmr_proof(
        data_mmr_proof_count, data_mmr_proof_index, data_mmr_proof_leaf,
        replace(data_mmr_proof_fixture,
                other_peaks=(*data_mmr_proof_fixture.other_peaks, bytes(32))),
        data_mmr_proof_root), \
        "data MMR proof accepted an extra other peak"

    asymmetric_block_ordinal = 3
    asymmetric_record_index = 7
    asymmetric_chunk_index = 1
    asymmetric_chunk_count = 9
    asymmetric_chunk = b"asymmetric-data-record"
    asymmetric_body = bytes.fromhex("61" * 32)
    asymmetric_versioned_hash = bytes.fromhex("57" * 32)
    asymmetric_chunk_root = chunk_root(
        asymmetric_body, asymmetric_block_ordinal, asymmetric_chunk_index,
        asymmetric_chunk_count, asymmetric_chunk)
    asymmetric_data_leaf = data_leaf(
        sid, asymmetric_record_index, asymmetric_versioned_hash,
        asymmetric_body, asymmetric_block_ordinal, asymmetric_chunk_index,
        asymmetric_chunk_count, asymmetric_chunk, 0xDADA, 65_535, 11, 13)
    swapped_data_leaf = keccak256(
        D_MMR_LEAF + b32(sid) + u16(asymmetric_chunk_index)
        + b32(asymmetric_versioned_hash) + b32(asymmetric_body)
        + u16(asymmetric_block_ordinal) + u16(asymmetric_record_index)
        + u16(asymmetric_chunk_count) + u32(len(asymmetric_chunk))
        + asymmetric_chunk_root + address20(0xDADA) + u64(65_535)
        + u256(11) + u256(13))
    assert asymmetric_data_leaf != swapped_data_leaf
    data_node_height_7 = data_node(
        7, asymmetric_data_leaf, bytes.fromhex("a7" * 32))
    assert data_node_height_7 != data_node(
        0, asymmetric_data_leaf, bytes.fromhex("a7" * 32))

    asymmetric_manifest_entry = ManifestEntry(
        asymmetric_block_ordinal, sid, asymmetric_record_index,
        asymmetric_chunk_index, asymmetric_chunk_count,
        len(asymmetric_chunk), asymmetric_body, asymmetric_chunk_root)
    asymmetric_manifest_leaf = manifest_leaf(11, asymmetric_manifest_entry)
    swapped_manifest_entry = replace(
        asymmetric_manifest_entry,
        record_index=asymmetric_manifest_entry.chunk_index,
        chunk_index=asymmetric_manifest_entry.record_index)
    assert asymmetric_manifest_leaf != manifest_leaf(11, swapped_manifest_entry)
    manifest_node_height_5 = manifest_node(
        5, asymmetric_manifest_leaf, bytes.fromhex("b5" * 32))
    assert manifest_node_height_5 != manifest_node(
        0, asymmetric_manifest_leaf, bytes.fromhex("b5" * 32))
    manifest = manifest_root(0, (
        ManifestEntry(0, sid, 0, 0, 2, len(chunk0), body, c0),
        ManifestEntry(0, sid, 1, 1, 2, len(chunk1), body, c1),
    ))
    manifest_block_1 = manifest_root(1, (
        ManifestEntry(1, sid, 0, 0, 2, len(chunk0), body, c0),
        ManifestEntry(1, sid, 1, 1, 2, len(chunk1), body, c1),
    ))
    core = canonical_core(
        8_000, bytes.fromhex("77" * 32), 8_000, bytes.fromhex("66" * 32),
        2, manifest, 100, 0)
    base = base_canonical(core, 1_000)
    schedules_hash = schedule_list(((20, ent_root, bytes.fromhex("12" * 32)),))
    sessions_hash = session_list(((sid, 2, mmr_root((leaf0, leaf1))),))
    outputs_hash = execution_outputs(bytes.fromhex("66" * 32),
                                     bytes.fromhex("13" * 32),
                                     bytes.fromhex("14" * 32),
                                     bytes.fromhex("15" * 32),
                                     bytes.fromhex("16" * 32))
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
    reward_execution_gas = 12_345_678
    reward_published_bytes = len(chunk0) + len(chunk1)
    statement_values = (
        settlement_chain_id, l2_chain_id, 2, profile_hash, contract,
        1, base,
        candidate_hash, 1, 8_001, bytes.fromhex("88" * 32), 8_001, 8_001,
        bytes.fromhex("66" * 32), 66,
        winning, envs[66].due_at,
        101, 0, 1_000, bytes.fromhex("99" * 32), bytes.fromhex("aa" * 32), 999,
        force.root, len(envs), forced_descriptors, 2, 12, adm_root,
        0, 0, bytes(32), schedules_hash, 1,
        sessions_hash, 1, 2, reward_execution_gas,
        reward_published_bytes, outputs_hash, 0xCAFE,
    )
    statement_commitment = statement_hash(statement_values)
    assert len(STATEMENT_KINDS) == len(statement_values) == 41
    candidate_tier = 1
    block_tier_rows = (block_values, block_values, block_values)
    validate_candidate_statement_tiers(
        statement_values, candidate_tier, block_tier_rows)
    for block_position in (0, 1, 2):
        changed_block_tier_rows = list(block_tier_rows)
        changed_block = list(changed_block_tier_rows[block_position])
        changed_block[17] = 2
        changed_block_tier_rows[block_position] = tuple(changed_block)
        assert_rejects(
            lambda rows=tuple(changed_block_tier_rows):
                validate_candidate_statement_tiers(
                    statement_values, candidate_tier, rows),
            "first/middle/last block tier substitution accepted")
    assert_rejects(
        lambda: validate_candidate_statement_tiers(
            statement_values, 2, block_tier_rows),
        "candidate tier disagreed with Settlement statement tier")
    for index, replacement_value in (
            (37, reward_execution_gas + 1),
            (38, reward_published_bytes + 1)):
        changed_statement = list(statement_values)
        changed_statement[index] = replacement_value
        assert statement_hash(tuple(changed_statement)) != statement_commitment
    invalid_statement = list(statement_values)
    invalid_statement[38] = 1 << 64
    assert_rejects(
        lambda: statement_hash(tuple(invalid_statement)),
        "wide rewardPublishedBytes accepted by SettlementStatementV2")
    invalid_statement[38] = reward_published_bytes
    invalid_statement[37] = 1 << 256
    assert_rejects(
        lambda: statement_hash(tuple(invalid_statement)),
        "wide rewardExecutionGas accepted by SettlementStatementV2")
    reward_receipt_arguments = (
        statement_commitment, 0xCAFE, 1, reward_execution_gas,
        reward_published_bytes, profile_hash, 1_234_567, 1_800_000_000,
        1_800_086_400,
    )
    reward_receipt_commitment = reward_receipt_v1_commitment(
        *reward_receipt_arguments)
    for index, replacement_value in enumerate((
            bytes.fromhex("a1" * 32), 0xCAFF, 2,
            reward_execution_gas + 1, reward_published_bytes + 1,
            bytes.fromhex("a2" * 32), 1_234_568, 1_800_000_001,
            1_800_086_401)):
        changed_receipt = list(reward_receipt_arguments)
        changed_receipt[index] = replacement_value
        assert (reward_receipt_v1_commitment(*changed_receipt)
                != reward_receipt_commitment)
    reward_receipt_calldata = encode_reward_receipt_v1_calldata(
        statement_commitment)
    reward_receipt_present_return = reward_receipt_v1_view_return(
        statement_commitment, reward_receipt_arguments)
    collision_candidate_id = (
        bytes.fromhex("a4" * 31) + statement_commitment[-1:])
    assert (collision_candidate_id != statement_commitment
            and collision_candidate_id[-1] == statement_commitment[-1])
    reward_receipt_missing_return = reward_receipt_v1_view_return(
        collision_candidate_id, reward_receipt_arguments)
    assert (reward_receipt_missing_return
                == reward_receipt_v1_view_return(
                    collision_candidate_id, None)
            == encode_reward_receipt_v1_missing_return()
            and decode_reward_receipt_v1_calldata(reward_receipt_calldata)
                == statement_commitment
            and decode_reward_receipt_v1_return(
                reward_receipt_present_return, statement_commitment)[-1]
                == reward_receipt_commitment
            and decode_reward_receipt_v1_return(
                reward_receipt_missing_return, collision_candidate_id)
                == (False, 0, 0, 0, 0, bytes(32), 0, 0, 0, False,
                    bytes(32))
            and len(reward_receipt_calldata) == 36
            and len(reward_receipt_present_return)
                == len(reward_receipt_missing_return)
                == REWARD_RECEIPT_V1_RETURN_LENGTH == 384
            and FUND_REWARD_CLASS_V1_SELECTOR.hex() == "15e08308"
            and CLAIM_REWARD_V1_SELECTOR.hex() == "aa5498cb"
            and REWARD_RECEIPT_V1_SELECTOR.hex() == "3ed526c7")
    for malformed_receipt_calldata in (
            reward_receipt_calldata[:-1], reward_receipt_calldata + b"\x00",
            bytes.fromhex("00000000") + reward_receipt_calldata[4:],
            REWARD_RECEIPT_V1_SELECTOR + bytes(32)):
        assert_rejects(
            lambda value=malformed_receipt_calldata:
                decode_reward_receipt_v1_calldata(value),
            "malformed rewardReceiptV1 calldata accepted")
    for malformed_receipt_return in (
            reward_receipt_present_return[:-1],
            reward_receipt_present_return + b"\x00",
            b"BAD!" + reward_receipt_present_return[4:],
            reward_receipt_present_return[:4] + b"\x01"
                + reward_receipt_present_return[5:],
            reward_receipt_present_return[:32] + u256(2)
                + reward_receipt_present_return[64:],
            reward_receipt_present_return[:64] + b"\x01"
                + reward_receipt_present_return[65:],
            reward_receipt_present_return[:96] + b"\x01"
                + reward_receipt_present_return[97:],
            reward_receipt_present_return[:160] + b"\x01"
                + reward_receipt_present_return[161:],
            reward_receipt_present_return[:224] + b"\x01"
                + reward_receipt_present_return[225:],
            reward_receipt_present_return[:320] + u256(2)
                + reward_receipt_present_return[352:],
            reward_receipt_present_return[:-32] + bytes.fromhex("a5" * 32),
            reward_receipt_missing_return[:64] + u256(1)
                + reward_receipt_missing_return[96:]):
        assert_rejects(
            lambda value=malformed_receipt_return:
                decode_reward_receipt_v1_return(
                    value, statement_commitment),
            "malformed rewardReceiptV1 return accepted")
    assert_rejects(
        lambda: decode_reward_receipt_v1_return(
            reward_receipt_present_return, collision_candidate_id),
        "rewardReceiptV1 accepted another candidate identity")
    builder_registry_runtime_hash = BUILDER_REGISTRY_RUNTIME_HASH_FIXTURE
    builder_registry_configuration_hash = (
        BUILDER_REGISTRY_CONFIGURATION_HASH_FIXTURE)
    reward_class_id = 1
    reward_class_terms = (100, 2, 1, 1_000_000)
    reward_class_calldata = encode_reward_class_v1_calldata(reward_class_id)
    reward_class_return = encode_reward_class_v1_return(
        builder_registry_configuration_hash, reward_class_id,
        *reward_class_terms)
    expected_reward_class_result = (
        builder_registry_configuration_hash, reward_class_id,
        *reward_class_terms)
    assert (REWARD_CLASS_V1_SELECTOR.hex() == "3d273ee7"
            and len(reward_class_calldata) == 36
            and len(reward_class_return) == REWARD_CLASS_V1_RETURN_LENGTH
            == 224
            and validate_reward_class_v1_getter(
                builder_registry_runtime_hash,
                builder_registry_runtime_hash,
                builder_registry_configuration_hash, reward_class_id,
                reward_class_calldata, COMPONENT_CONFIG_GETTER_GAS_LIMIT,
                reward_class_return) == expected_reward_class_result)
    for malformed_reward_class_calldata in (
            reward_class_calldata[:-1], reward_class_calldata + b"\x00",
            bytes.fromhex("00000000") + reward_class_calldata[4:],
            reward_class_calldata[:4] + b"\x01"
                + reward_class_calldata[5:]):
        assert_rejects(
            lambda value=malformed_reward_class_calldata:
                decode_reward_class_v1_calldata(value),
            "malformed rewardClassV1 calldata accepted")
    for observed_runtime_hash, gas_limit in (
            (bytes.fromhex("a4" * 32), COMPONENT_CONFIG_GETTER_GAS_LIMIT),
            (builder_registry_runtime_hash,
             COMPONENT_CONFIG_GETTER_GAS_LIMIT - 1)):
        assert_rejects(
            lambda runtime=observed_runtime_hash, gas=gas_limit:
                validate_reward_class_v1_getter(
                    builder_registry_runtime_hash, runtime,
                    builder_registry_configuration_hash, reward_class_id,
                    reward_class_calldata, gas, reward_class_return),
            "unbound rewardClassV1 call accepted")
    for malformed_reward_class_return in (
            reward_class_return[:-1], reward_class_return + b"\x00",
            b"BAD!" + reward_class_return[4:],
            reward_class_return[:4] + b"\x01"
                + reward_class_return[5:],
            reward_class_return[:64] + b"\x01"
                + reward_class_return[65:]):
        assert_rejects(
            lambda value=malformed_reward_class_return:
                decode_reward_class_v1_return(
                    value, builder_registry_configuration_hash,
                    reward_class_id),
            "malformed rewardClassV1 return accepted")
    assert_rejects(
        lambda: decode_reward_class_v1_return(
            reward_class_return, bytes.fromhex("a3" * 32), reward_class_id),
        "wrong BuilderRegistry configuration accepted by rewardClassV1")
    assert_rejects(
        lambda: decode_reward_class_v1_return(
            reward_class_return, builder_registry_configuration_hash, 2),
        "wrong requested-class echo accepted by rewardClassV1")
    for index, replacement_value in enumerate((
            101, 3, 2, 1_000_001), start=2):
        changed_reward_class = list(expected_reward_class_result)
        changed_reward_class[index] = replacement_value
        assert (encode_reward_class_v1_return(*changed_reward_class)
                != reward_class_return)
    fund_reward_class_calldata = encode_fund_reward_class_v1_calldata(
        reward_class_id)
    fund_reward_class_returndata = b""
    claim_reward_calldata = encode_claim_reward_v1_calldata(
        statement_commitment)
    claim_reward_paid_wei = min(
        reward_class_terms[3],
        reward_class_terms[0]
        + reward_class_terms[1] * reward_execution_gas
        + reward_class_terms[2] * reward_published_bytes)
    claim_reward_return = encode_claim_reward_v1_return(
        claim_reward_paid_wei)
    assert (decode_fund_reward_class_v1_calldata(
                fund_reward_class_calldata) == reward_class_id == 1
            and len(fund_reward_class_calldata) == 36
            and decode_fund_reward_class_v1_return(
                fund_reward_class_returndata) is None
            and decode_claim_reward_v1_calldata(claim_reward_calldata)
                == statement_commitment
            and len(claim_reward_calldata) == 36
            and decode_claim_reward_v1_return(claim_reward_return)
                == claim_reward_paid_wei == 1_000_000
            and len(claim_reward_return) == 32)
    for malformed_fund_calldata in (
            fund_reward_class_calldata[:-1],
            fund_reward_class_calldata + b"\x00",
            bytes.fromhex("00000000") + fund_reward_class_calldata[4:],
            fund_reward_class_calldata[:4] + b"\x01"
                + fund_reward_class_calldata[5:]):
        assert_rejects(
            lambda value=malformed_fund_calldata:
                decode_fund_reward_class_v1_calldata(value),
            "malformed fundRewardClassV1 calldata accepted")
    assert (keccak256(encode_fund_reward_class_v1_calldata(2))
            != keccak256(fund_reward_class_calldata))
    assert_rejects(
        lambda: decode_fund_reward_class_v1_return(b"\x00"),
        "trailing fundRewardClassV1 returndata accepted")
    for malformed_claim_calldata in (
            claim_reward_calldata[:-1], claim_reward_calldata + b"\x00",
            bytes.fromhex("00000000") + claim_reward_calldata[4:],
            CLAIM_REWARD_V1_SELECTOR + bytes(32)):
        assert_rejects(
            lambda value=malformed_claim_calldata:
                decode_claim_reward_v1_calldata(value),
            "malformed claimRewardV1 calldata accepted")
    assert (keccak256(encode_claim_reward_v1_calldata(
                collision_candidate_id)) != keccak256(claim_reward_calldata)
            and keccak256(encode_claim_reward_v1_return(
                claim_reward_paid_wei + 1)) != keccak256(claim_reward_return))
    for malformed_claim_return in (
            claim_reward_return[:-1], claim_reward_return + b"\x00"):
        assert_rejects(
            lambda value=malformed_claim_return:
                decode_claim_reward_v1_return(value),
            "malformed claimRewardV1 return accepted")
    candidate_committed_log = encode_candidate_committed_v2_log(
        statement_commitment, 0xCAFE, reward_class_id,
        reward_execution_gas, reward_published_bytes, True,
        statement_commitment[-1], reward_receipt_commitment)
    reward_class_funded_log = encode_reward_class_funded_v1_log(
        reward_class_id, 0xF00D, 1_000_000, 1_000_000, 6_000_000)
    reward_claimed_log = encode_reward_claimed_v1_log(
        statement_commitment, 0xCAFE, reward_class_id,
        claim_reward_paid_wei)
    candidate_log_topics, candidate_log_data = candidate_committed_log
    funded_log_topics, funded_log_data = reward_class_funded_log
    claimed_log_topics, claimed_log_data = reward_claimed_log
    assert (candidate_log_topics == (
                reward_event_topics["candidate_committed_v2_topic"],
                statement_commitment, address_word(0xCAFE))
            and funded_log_topics == (
                reward_event_topics["reward_class_funded_v1_topic"],
                u256(reward_class_id), address_word(0xF00D))
            and claimed_log_topics == (
                reward_event_topics["reward_claimed_v1_topic"],
                statement_commitment, address_word(0xCAFE))
            and decode_candidate_committed_v2_log(
                *candidate_committed_log) == (
                    statement_commitment, 0xCAFE, reward_class_id,
                    reward_execution_gas, reward_published_bytes, True,
                    statement_commitment[-1], reward_receipt_commitment)
            and decode_reward_class_funded_v1_log(
                *reward_class_funded_log)
                == (reward_class_id, 0xF00D, 1_000_000,
                    1_000_000, 6_000_000)
            and decode_reward_claimed_v1_log(*reward_claimed_log)
                == (statement_commitment, 0xCAFE, reward_class_id,
                    claim_reward_paid_wei))
    for malformed_topics, malformed_data in (
            (candidate_log_topics[:-1], candidate_log_data),
            (candidate_log_topics + (bytes(32),), candidate_log_data),
            ((bytes.fromhex("a6" * 32), *candidate_log_topics[1:]),
             candidate_log_data),
            ((candidate_log_topics[0], bytes(32), candidate_log_topics[2]),
             candidate_log_data),
            ((candidate_log_topics[0], candidate_log_topics[1],
              b"\x01" + candidate_log_topics[2][1:]), candidate_log_data),
            (candidate_log_topics, candidate_log_data[:-1]),
            (candidate_log_topics, candidate_log_data + b"\x00"),
            (candidate_log_topics,
             b"\x01" + candidate_log_data[1:]),
            (candidate_log_topics,
             candidate_log_data[:64] + b"\x01"
                + candidate_log_data[65:]),
            (candidate_log_topics,
             candidate_log_data[:96] + u256(2)
                + candidate_log_data[128:]),
            (candidate_log_topics,
             candidate_log_data[:128] + u256(
                (statement_commitment[-1] + 1) % 256)
                + candidate_log_data[160:])):
        assert_rejects(
            lambda topics=malformed_topics, data=malformed_data:
                decode_candidate_committed_v2_log(topics, data),
            "malformed CandidateCommittedV2 log accepted")
    for malformed_topics, malformed_data in (
            (funded_log_topics[:-1], funded_log_data),
            (funded_log_topics + (bytes(32),), funded_log_data),
            ((bytes.fromhex("a7" * 32), *funded_log_topics[1:]),
             funded_log_data),
            ((funded_log_topics[0], b"\x01" + funded_log_topics[1][1:],
              funded_log_topics[2]), funded_log_data),
            ((funded_log_topics[0], funded_log_topics[1],
              b"\x01" + funded_log_topics[2][1:]), funded_log_data),
            (funded_log_topics, funded_log_data[:-1]),
            (funded_log_topics, funded_log_data + b"\x00")):
        assert_rejects(
            lambda topics=malformed_topics, data=malformed_data:
                decode_reward_class_funded_v1_log(topics, data),
            "malformed RewardClassFundedV1 log accepted")
    for malformed_topics, malformed_data in (
            (claimed_log_topics[:-1], claimed_log_data),
            (claimed_log_topics + (bytes(32),), claimed_log_data),
            ((bytes.fromhex("a8" * 32), *claimed_log_topics[1:]),
             claimed_log_data),
            ((claimed_log_topics[0], bytes(32), claimed_log_topics[2]),
             claimed_log_data),
            ((claimed_log_topics[0], claimed_log_topics[1],
              b"\x01" + claimed_log_topics[2][1:]), claimed_log_data),
            (claimed_log_topics, claimed_log_data[:-1]),
            (claimed_log_topics, claimed_log_data + b"\x00"),
            (claimed_log_topics, b"\x01" + claimed_log_data[1:])):
        assert_rejects(
            lambda topics=malformed_topics, data=malformed_data:
                decode_reward_claimed_v1_log(topics, data),
            "malformed RewardClaimedV1 log accepted")
    assert (encode_candidate_committed_v2_log(
                collision_candidate_id, 0xCAFE, reward_class_id,
                reward_execution_gas, reward_published_bytes, False,
                collision_candidate_id[-1], reward_receipt_commitment)
            != candidate_committed_log
            and encode_reward_class_funded_v1_log(
                2, 0xF00D, 1_000_000, 1_000_000, 6_000_000)
            != reward_class_funded_log
            and encode_reward_claimed_v1_log(
                collision_candidate_id, 0xCAFE, reward_class_id,
                claim_reward_paid_wei) != reward_claimed_log)
    normal_forced_ingress_floor_return = (
        encode_settlement_forced_ingress_floor_return(0))
    recovery_forced_ingress_floor_return = (
        encode_settlement_forced_ingress_floor_return(UINT64_MAX))
    assert (SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR.hex() == "fe2a2914"
            and decode_settlement_forced_ingress_floor_return(
                normal_forced_ingress_floor_return) == 0
            and decode_settlement_forced_ingress_floor_return(
                recovery_forced_ingress_floor_return) == UINT64_MAX)
    for malformed_forced_ingress_floor in (
        normal_forced_ingress_floor_return[:-1],
        normal_forced_ingress_floor_return + b"\x00",
        b"BAD!" + normal_forced_ingress_floor_return[4:],
        normal_forced_ingress_floor_return[:32] + b"\x01"
        + normal_forced_ingress_floor_return[33:],
    ):
        assert_rejects(
            lambda value=malformed_forced_ingress_floor:
                decode_settlement_forced_ingress_floor_return(value),
            "malformed Settlement forced-ingress floor accepted")
    empty_queue_root = ForceVector(()).root
    queue_config_return = encode_forced_queue_config_return(0xAD01, 0xB001)
    queue_empty_state_return = encode_forced_queue_state_return(
        0xB001, empty_queue_root, 0, 0, 0, 0, 0, 0,
        forced_queue_config_hash(0xAD01, 0xB001))
    assert decode_forced_queue_config_return(queue_config_return) == (
        0xAD01, 0xB001, forced_queue_config_hash(0xAD01, 0xB001))
    assert decode_forced_queue_state_return(queue_empty_state_return) == (
        0xB001, empty_queue_root, 0, 0, 0, 0, 0, 0,
        forced_queue_config_hash(0xAD01, 0xB001))
    for malformed_queue_view, decoder in (
        (queue_config_return[:-1], decode_forced_queue_config_return),
        (b"BAD!" + queue_config_return[4:], decode_forced_queue_config_return),
        (queue_empty_state_return + b"\x00", decode_forced_queue_state_return),
        (queue_empty_state_return[:32] + b"\x01"
         + queue_empty_state_return[33:], decode_forced_queue_state_return),
    ):
        assert_rejects(
            lambda value=malformed_queue_view, fn=decoder: fn(value),
            "malformed ForcedQueue view accepted")
    register_fork_payload = RegisterForkVerifierPayloadV1(
        bytes.fromhex("46554c55"), 2_048, 4_096, 0x6800,
        bytes.fromhex("68" * 32), 8, 201, 6_434, 6_437, 6_441, 6_444,
        bytes.fromhex("67" * 32), bytes(32),
        bytes.fromhex("7e981e0b"), 4_000_000)
    register_fork_payload = replace(
        register_fork_payload,
        configuration_hash=schedule_fork_verifier_configuration_hash(
            register_fork_payload))
    register_fork_row_abi = encode_register_fork_verifier_payload(
        register_fork_payload)
    predecessor_fork_payload = replace(
        register_fork_payload,
        fork_digest=bytes.fromhex("44454e42"),
        first_parent_slot=1_024,
        last_parent_slot_exclusive=2_048,
        configuration_hash=bytes(32),
    )
    predecessor_fork_payload = replace(
        predecessor_fork_payload,
        configuration_hash=schedule_fork_verifier_configuration_hash(
            predecessor_fork_payload
        ),
    )
    predecessor_fork_row_abi = encode_register_fork_verifier_payload(
        predecessor_fork_payload
    )
    replacement_fork_payload = replace(
        register_fork_payload, fork_digest=bytes.fromhex("474c4f41"),
        first_parent_slot=3_072, last_parent_slot_exclusive=8_192,
        configuration_hash=bytes(32))
    replacement_fork_payload = replace(
        replacement_fork_payload,
        configuration_hash=schedule_fork_verifier_configuration_hash(
            replacement_fork_payload))
    install_fork_verifier_calldata = encode_install_fork_verifier_calldata(
        register_fork_payload)
    install_fork_verifier_return = encode_install_fork_verifier_return(
        register_fork_payload.fork_digest,
        register_fork_payload.first_parent_slot)
    fork_verifier_registration = ForkVerifierRegistrationV1(
        register_fork_payload.fork_digest,
        register_fork_payload.first_parent_slot, bytes(4),
        register_fork_payload.last_parent_slot_exclusive,
        register_fork_payload.verifier,
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
    initial_fork_payload = replace(
        register_fork_payload,
        fork_digest=bytes.fromhex("44454e42"),
        first_parent_slot=0,
        last_parent_slot_exclusive=register_fork_payload.first_parent_slot,
        verifier=0x6801,
        runtime_hash=bytes.fromhex("6a" * 32),
        configuration_hash=bytes(32),
    )
    initial_fork_payload = replace(
        initial_fork_payload,
        configuration_hash=schedule_fork_verifier_configuration_hash(
            initial_fork_payload
        ),
    )
    initial_fork_registration = ForkVerifierRegistrationV1(
        initial_fork_payload.fork_digest,
        initial_fork_payload.first_parent_slot, bytes(4),
        initial_fork_payload.last_parent_slot_exclusive,
        initial_fork_payload.verifier, initial_fork_payload.runtime_hash,
        initial_fork_payload.configuration_hash,
        initial_fork_payload.selector, initial_fork_payload.gas_limit,
    )
    initial_fork_registration_return = (
        encode_fork_verifier_registration_return(initial_fork_registration)
    )
    initial_fork_verifier_config_return = (
        encode_schedule_fork_verifier_config_return(initial_fork_payload)
    )
    initial_fork_route_state_return = encode_schedule_fork_route_state_return(
        {initial_fork_payload.fork_digest: initial_fork_payload},
        (initial_fork_payload.fork_digest,),
        frozenset((initial_fork_payload.fork_digest,)),
    )
    fork_route_registrations = {
        initial_fork_payload.fork_digest: initial_fork_payload,
        register_fork_payload.fork_digest: register_fork_payload,
        replacement_fork_payload.fork_digest: replacement_fork_payload,
    }
    fork_route_order = (
        initial_fork_payload.fork_digest,
        register_fork_payload.fork_digest,
    )
    fork_route_used_digests = frozenset((
        initial_fork_payload.fork_digest,
        register_fork_payload.fork_digest,
        replacement_fork_payload.fork_digest,
        bytes.fromhex("544f4d42"),
    ))
    schedule_fork_route_state_return = (
        encode_schedule_fork_route_state_return(
            fork_route_registrations,
            fork_route_order,
            fork_route_used_digests,
        )
    )
    schedule_carrier_witness = bytes.fromhex("a1617701")
    schedule_beacon_block_root = bytes.fromhex("d0" * 32)
    verify_schedule_carrier_calldata = encode_verify_schedule_carrier_calldata(
        schedule_carrier_witness, schedule_beacon_block_root)
    schedule_statement_hash = schedule_carrier_statement_hash(
        settlement_chain_id, SCHEDULE_ORACLE_FIXTURE_ADDRESS,
        register_fork_payload.fork_digest, 2_048, schedule_beacon_block_root,
        2_047, 20_000_000, 1_800_000_000, bytes.fromhex("d1" * 32),
        bytes.fromhex("d2" * 32), bytes.fromhex("d3" * 32))
    schedule_carrier_output = ScheduleCarrierOutputV1(
        schedule_statement_hash, 2_047, 20_000_000, 1_800_000_000,
        bytes.fromhex("d1" * 32), bytes.fromhex("d2" * 32),
        bytes.fromhex("d3" * 32))
    schedule_carrier_return = encode_schedule_carrier_return(
        schedule_carrier_output)
    assert (SEAT_TARGET_STATE_SELECTOR.hex() == "cf52185b"
            and SEAT_MARKET_TERM_SELECTOR.hex() == "76d5ecd4"
            and SEAT_MARKET_DUTY_SELECTOR.hex() == "9a649489")
    assert (INSTALL_FORK_VERIFIER_SELECTOR.hex() == "9bb6fe73"
            and FORK_VERIFIER_REGISTRATION_SELECTOR.hex() == "c614591c"
            and SCHEDULE_FORK_VERIFIER_CONFIG_SELECTOR.hex() == "44efa773"
            and SCHEDULE_FORK_ROUTE_STATE_SELECTOR.hex() == "7e9f3c0d"
            and VERIFY_SCHEDULE_CARRIER_SELECTOR.hex() == "7e981e0b")
    assert SEAT_AUTHORITY_READ_GAS == 100_000
    assert FORK_VERIFIER_INSTALL_MAGIC == b"FVI1"
    assert FORK_VERIFIER_REGISTRATION_MAGIC == b"FVR1"
    assert SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC == b"SFV1"
    assert SCHEDULE_FORK_ROUTE_STATE_MAGIC == b"FRS1"
    assert SCHEDULE_FORK_CARRIER_MAGIC == b"SFC1"
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
            register_fork_payload.first_parent_slot)
    expected_predecessor_registration_hash = schedule_fork_registration_hash(
        predecessor_fork_payload
    )
    expected_old_registration_hash = schedule_fork_registration_hash(
        register_fork_payload)
    replace_fork_calldata = encode_replace_pending_fork_verifier_calldata(
        expected_predecessor_registration_hash,
        expected_old_registration_hash,
        replacement_fork_payload)
    assert decode_replace_pending_fork_verifier_calldata(
        replace_fork_calldata) == (
            expected_predecessor_registration_hash,
            expected_old_registration_hash, replacement_fork_payload)
    replace_fork_return = encode_replace_pending_fork_verifier_return(
        register_fork_payload.fork_digest,
        replacement_fork_payload.fork_digest,
        replacement_fork_payload.first_parent_slot,
        replacement_fork_payload.last_parent_slot_exclusive)
    assert decode_replace_pending_fork_verifier_return(
        replace_fork_return
    ) == (
        register_fork_payload.fork_digest,
        replacement_fork_payload.fork_digest,
        replacement_fork_payload.first_parent_slot,
        replacement_fork_payload.last_parent_slot_exclusive,
    )
    split_fork_calldata = encode_split_latest_fork_verifier_calldata(
        expected_old_registration_hash, replacement_fork_payload
    )
    assert decode_split_latest_fork_verifier_calldata(
        split_fork_calldata
    ) == (expected_old_registration_hash, replacement_fork_payload)
    split_fork_return = encode_split_latest_fork_verifier_return(
        register_fork_payload.fork_digest,
        replacement_fork_payload.fork_digest,
        replacement_fork_payload.first_parent_slot,
        replacement_fork_payload.last_parent_slot_exclusive,
    )
    assert decode_split_latest_fork_verifier_return(
        split_fork_return
    ) == (
        register_fork_payload.fork_digest,
        replacement_fork_payload.fork_digest,
        replacement_fork_payload.first_parent_slot,
        replacement_fork_payload.last_parent_slot_exclusive,
    )
    assert decode_fork_verifier_registration_calldata(
        fork_verifier_registration_calldata) \
        == register_fork_payload.fork_digest
    assert decode_fork_verifier_registration_return(
        fork_verifier_registration_return) == fork_verifier_registration
    assert decode_schedule_fork_verifier_config_return(
        schedule_fork_verifier_config_return,
        register_fork_payload.verifier, register_fork_payload.runtime_hash,
        register_fork_payload.first_parent_slot,
        register_fork_payload.last_parent_slot_exclusive,
        register_fork_payload.selector,
        register_fork_payload.gas_limit) == register_fork_payload
    assert decode_schedule_fork_route_state_return(
        schedule_fork_route_state_return
    ) == (
        schedule_fork_route_state_hash(
            fork_route_registrations,
            fork_route_order,
            fork_route_used_digests,
        ),
        len(fork_route_order),
        len(fork_route_registrations),
        len(fork_route_used_digests),
    )
    assert schedule_fork_route_state_hash(
        fork_route_registrations,
        tuple(reversed(fork_route_order)),
        fork_route_used_digests,
    ) != schedule_fork_route_state_hash(
        fork_route_registrations,
        fork_route_order,
        fork_route_used_digests,
    )
    assert decode_fork_verifier_registration_return(
        initial_fork_registration_return
    ) == initial_fork_registration
    assert decode_schedule_fork_verifier_config_return(
        initial_fork_verifier_config_return,
        initial_fork_payload.verifier, initial_fork_payload.runtime_hash,
        initial_fork_payload.first_parent_slot,
        initial_fork_payload.last_parent_slot_exclusive,
        initial_fork_payload.selector, initial_fork_payload.gas_limit,
    ) == initial_fork_payload
    assert decode_schedule_fork_route_state_return(
        initial_fork_route_state_return
    ) == (
        schedule_fork_route_state_hash(
            {initial_fork_payload.fork_digest: initial_fork_payload},
            (initial_fork_payload.fork_digest,),
            frozenset((initial_fork_payload.fork_digest,)),
        ),
        1, 1, 1,
    )
    assert schedule_fork_route_state_hash(
        fork_route_registrations,
        fork_route_order,
        fork_route_used_digests - {bytes.fromhex("544f4d42")},
    ) != schedule_fork_route_state_hash(
        fork_route_registrations,
        fork_route_order,
        fork_route_used_digests,
    )
    assert decode_verify_schedule_carrier_calldata(
        verify_schedule_carrier_calldata) == (
            schedule_carrier_witness, schedule_beacon_block_root)
    assert decode_schedule_carrier_return(
        schedule_carrier_return,
        schedule_statement_hash) == schedule_carrier_output
    assert schedule_execution_payload_is_parent(7, 8)
    assert not schedule_execution_payload_is_parent(7, 7)
    assert not schedule_execution_payload_is_parent(7, 9)
    assert not schedule_execution_payload_is_parent(UINT64_MAX, 0)
    assert_all_fields_bound(
        schedule_carrier_output, encode_schedule_carrier_return)
    assert not fork_verifier_registration_covers_parent_slot(
        fork_verifier_registration,
        register_fork_payload.first_parent_slot - 1)
    assert fork_verifier_registration_covers_parent_slot(
        fork_verifier_registration, register_fork_payload.first_parent_slot)
    assert fork_verifier_registration_covers_parent_slot(
        fork_verifier_registration,
        register_fork_payload.last_parent_slot_exclusive - 1)
    assert not fork_verifier_registration_covers_parent_slot(
        fork_verifier_registration,
        register_fork_payload.last_parent_slot_exclusive)
    prior_fork_registration = ForkVerifierRegistrationV1(
        bytes.fromhex("44454e42"), 0, register_fork_payload.fork_digest,
        register_fork_payload.first_parent_slot, 0x6801,
        bytes.fromhex("6a" * 32),
        bytes.fromhex("6b" * 32), VERIFY_SCHEDULE_CARRIER_SELECTOR,
        4_000_000)
    assert fork_verifier_registration_covers_parent_slot(
        prior_fork_registration,
        register_fork_payload.first_parent_slot - 1)
    assert not fork_verifier_registration_covers_parent_slot(
        prior_fork_registration, register_fork_payload.first_parent_slot)
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
             register_fork_payload.first_parent_slot,
             register_fork_payload.last_parent_slot_exclusive,
             register_fork_payload.selector,
             register_fork_payload.gas_limit)),
        (schedule_fork_route_state_return[:-1],
         decode_schedule_fork_route_state_return),
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
    kind0_admission = forced_admission(envs[0])
    assert len(kind0_admission) == 204
    assert len(register_fork_row_abi) == 480
    assert forced_descriptor(envs[0]) == (
        kind0_admission[:-32] + u64(envs[0].enqueued_at)
        + u64(envs[0].due_at) + kind0_admission[-32:]
    )
    raw_transaction = b"\x02" + bytes(range(1, 34))
    enqueue_forced_calldata = encode_enqueue_forced_transaction_calldata(
        raw_transaction, 9_999, 0xBEEF)
    empty_body = body_root(())
    empty_manifest = manifest_root(0, ())
    empty_sessions = session_list(())
    assert ENQUEUE_FORCED_TRANSACTION_SELECTOR.hex() == "9f06b1b4"
    assert decode_enqueue_forced_transaction_calldata(
        enqueue_forced_calldata) == (raw_transaction, 9_999, 0xBEEF)
    for malformed_enqueue_calldata in (
        enqueue_forced_calldata + bytes(32),
        enqueue_forced_calldata[:-1] + b"\x01",
        enqueue_forced_calldata[:36] + u256(1 << 64)
        + enqueue_forced_calldata[68:],
    ):
        assert_rejects(
            lambda value=malformed_enqueue_calldata:
                decode_enqueue_forced_transaction_calldata(value),
            "malformed enqueueForcedTransactionV2 calldata accepted")
    # Exact BuilderRegistry proof tails, full calldata and fixed returns.  The
    # fixture covers every prestate-derived witness branch rather than freezing
    # selectors alone.
    vacancy_registry_path = fixed_tree_proof(
        [registry_leaf(i, value) for i, value in enumerate(cells)],
        1, D_REG_NODE,
    )
    vacancy_admission_path = fixed_tree_proof(
        admission_leaves, 1, D_ADM_NODE
    )
    vacancy_registration_witness = (
        b"".join(vacancy_registry_path) + b"".join(vacancy_admission_path)
    )
    assert len(vacancy_registration_witness) == 544
    move_registry_path = fixed_tree_proof(
        [registry_leaf(i, value) for i, value in enumerate(move_active)],
        0, D_REG_NODE,
    )
    close_records = ((519, tranche_proof),)
    movement_witness = builder_move_witness(
        close_records, move_registry_path,
        liability_64_proof, active_0_intermediate_proof,
    )
    maintenance_witness = len(movement_witness).to_bytes(4, "big") \
        + movement_witness
    normalize_noop_witness = builder_normalize_witness((), registry_proof)
    normalize_witness = builder_normalize_witness(close_records, registry_proof)
    reserve_witness = builder_reserve_witness(
        close_records, tranche_proof, registry_proof
    )
    active_tranche_release_witness = (
        b"".join(tranche_proof) + b"".join(registry_proof)
    )
    liability_tranche_release_witness = b"".join(tranche_proof)
    generation_release_witness = b"".join(admission_proof)
    block_a = canonical_packed_slot_chain_block(block_values)
    block_b_values = list(block_values)
    block_b_values[6] = bytes.fromhex("89" * 32)
    block_b = canonical_packed_slot_chain_block(tuple(block_b_values))
    signature_a = (1).to_bytes(32, "big") + (1).to_bytes(32, "big") + b"\x1b"
    signature_b = (2).to_bytes(32, "big") + (2).to_bytes(32, "big") + b"\x1c"
    active_equivocation_witness = builder_equivocation_witness(
        block_a, signature_a, block_b, signature_b,
        64, admission_proof, 20, tranche_proof,
        active_0_pre_proof, registry_proof, active=True,
    )
    liability_equivocation_witness = builder_equivocation_witness(
        block_a, signature_a, block_b, signature_b,
        64, admission_proof, 20, tranche_proof,
        admission_proof, (bytes(32),) * REGISTRY_DEPTH, active=False,
    )

    proof_verifier_config_hash = builder_proof_verifier_configuration_hash_v1()
    proof_verifier_config_return = builder_proof_verifier_config_return_v1()
    evidence_hash = keccak256(active_equivocation_witness)
    evidence_identity_commitment = builder_proof_identity_commitment_v1(
        evidence_hash, settlement_chain_id, 2, contract, 20, 12, adm_root,
        cell.address,
    )
    evidence_identity_calldata = builder_proof_identity_calldata_v1(
        settlement_chain_id, active_equivocation_witness
    )
    evidence_identity_return = builder_proof_identity_return_v1(
        evidence_hash, evidence_identity_commitment, cell.address, 20, 2,
        contract, 12, adm_root,
    )
    registry_replace_request = builder_proof_registry_replace_request_v1(
        reg_root, 3, builder_registry_cell_v1(cell),
        builder_registry_cell_v1(tranche_mutation), registry_proof,
    )
    registry_replace_calldata = builder_proof_request_calldata_v1(
        registry_replace_request
    )
    registry_replace_return = builder_proof_return_v1(
        registry_replace_request,
        new_registry_root=registry_root(tuple(mutated_cells)),
    )
    admission_replace_request = builder_proof_admission_replace_request_v1(
        adm_root, 64, 2, builder_admission_cell_v1(cell), 2,
        builder_admission_cell_v1(replacement_cell), admission_proof,
    )
    admission_replace_calldata = builder_proof_request_calldata_v1(
        admission_replace_request
    )
    admission_replace_return = builder_proof_return_v1(
        admission_replace_request, new_admission_root=adm_reuse_root,
    )
    old_tranche_cell = builder_tranche_cell_v1(7, 519, 2, 10**17, 999_999)
    new_tranche_cell = builder_tranche_cell_v1(7, 519, 3, 0, 999_999)
    tranche_batch_request = builder_proof_tranche_batch_request_v1(
        tranche_root_hash, ((old_tranche_cell, new_tranche_cell,
                             tranche_proof),),
    )
    new_tranche_leaves = list(tranche_leaves)
    new_tranche_leaves[7] = tranche_leaf(7, 519, 3, 0, 999_999)
    tranche_batch_return = builder_proof_return_v1(
        tranche_batch_request,
        new_tranche_root=fixed_root(new_tranche_leaves, D_TRANCHE_NODE),
    )
    tranche_batch_calldata = builder_proof_request_calldata_v1(
        tranche_batch_request
    )
    evidence_request = builder_proof_equivocation_request_v1(
        active_equivocation_witness, settlement_chain_id,
        evidence_identity_commitment, cell.address, cell.registration_index,
        1, 3, 8_002, reg_root, adm_root, builder_registry_cell_v1(cell),
        512, 1 << 7, 1, old_tranche_cell,
    )
    evidence_request_calldata = builder_proof_request_calldata_v1(
        evidence_request
    )
    evidence_request_return = builder_proof_return_v1(
        evidence_request, new_registry_root=registry_root(tuple(mutated_cells)),
        new_admission_root=adm_root,
        new_tranche_root=fixed_root(new_tranche_leaves, D_TRANCHE_NODE),
    )
    tombstoned_cell = replace(cell, tombstoned_at_l2_slot=8_001)
    active_tombstoned_evidence_request = builder_proof_equivocation_request_v1(
        active_equivocation_witness, settlement_chain_id,
        evidence_identity_commitment, cell.address, cell.registration_index,
        1, 3, 8_002, reg_root, adm_root,
        builder_registry_cell_v1(tombstoned_cell), 512, 1 << 7, 1,
        old_tranche_cell,
    )
    active_tombstoned_evidence_return = builder_proof_return_v1(
        active_tombstoned_evidence_request,
        new_registry_root=registry_root(tuple(mutated_cells)),
        new_tranche_root=fixed_root(new_tranche_leaves, D_TRANCHE_NODE),
    )
    liability_evidence_hash = keccak256(liability_equivocation_witness)
    liability_identity_commitment = builder_proof_identity_commitment_v1(
        liability_evidence_hash, settlement_chain_id, 2, contract, 20, 12,
        adm_root, cell.address,
    )
    liability_evidence_request = builder_proof_equivocation_request_v1(
        liability_equivocation_witness, settlement_chain_id,
        liability_identity_commitment, cell.address, cell.registration_index,
        2, 64, 8_002, reg_root, adm_root, builder_registry_cell_v1(cell),
        512, 1 << 7, 1, old_tranche_cell,
    )
    liability_evidence_return = builder_proof_return_v1(
        liability_evidence_request, new_admission_root=adm_root,
        new_tranche_root=fixed_root(new_tranche_leaves, D_TRANCHE_NODE),
    )
    liability_tombstoned_evidence_request = \
        builder_proof_equivocation_request_v1(
            liability_equivocation_witness, settlement_chain_id,
            liability_identity_commitment, cell.address,
            cell.registration_index, 2, 64, 8_002, reg_root, adm_root,
            builder_registry_cell_v1(tombstoned_cell), 512, 1 << 7, 1,
            old_tranche_cell,
        )
    liability_tombstoned_evidence_return = builder_proof_return_v1(
        liability_tombstoned_evidence_request,
        new_tranche_root=fixed_root(new_tranche_leaves, D_TRANCHE_NODE),
    )
    assert (proof_verifier_config_hash
            == proof_verifier_config_return[-32:]
            and len(evidence_identity_calldata) == 2_468
            and len(evidence_identity_return) == 320
            and len(registry_replace_request) == 432
            and len(admission_replace_request) == 531
            and len(tranche_batch_request) == 412
            and len(evidence_request) == 2_727)
    assert tuple(
        (value[3 * 32:4 * 32] != bytes(32),
         value[4 * 32:5 * 32] != bytes(32),
         value[5 * 32:6 * 32] != bytes(32))
        for value in (
            evidence_request_return, active_tombstoned_evidence_return,
            liability_evidence_return, liability_tombstoned_evidence_return,
        )
    ) == ((True, True, True), (True, False, True),
          (False, True, True), (False, False, True))
    assert builder_proof_request_commitment_v1(
        registry_replace_request
    ) != builder_proof_request_commitment_v1(
        registry_replace_request[:37] + b"\x02" + registry_replace_request[38:]
    )

    register_builder_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["register_builder_selector"],
        (u256(1_000), u256(42), u256(1)), vacancy_registration_witness,
    )
    reserve_builder_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["reserve_builder_window_selector"],
        (u256(42), u256(519)), reserve_witness,
    )
    request_exit_calldata = (
        BUILDER_REGISTRY_SELECTORS["request_builder_exit_selector"] + u256(42)
    )
    maintenance_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["process_builder_maintenance_selector"],
        (u256(1),), maintenance_witness,
    )
    normalize_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["normalize_builder_tranches_selector"],
        (address_word(cell.address), u256(cell.registration_index)),
        normalize_witness,
    )
    release_tranche_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["release_builder_tranche_selector"],
        (address_word(cell.address), u256(cell.registration_index), u256(519)),
        active_tranche_release_witness,
    )
    release_generation_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["release_builder_generation_selector"],
        (address_word(cell.address), u256(cell.registration_index)),
        generation_release_witness,
    )
    claim_builder_credit_calldata = (
        BUILDER_REGISTRY_SELECTORS["claim_builder_lease_credit_selector"]
        + address_word(0xCAFE)
    )
    equivocation_calldata = builder_dynamic_bytes_calldata(
        BUILDER_REGISTRY_SELECTORS["submit_builder_equivocation_selector"],
        (), active_equivocation_witness,
    )
    expire_schedule_calldata = (
        BUILDER_REGISTRY_SELECTORS["expire_schedule_windows_selector"] + u256(8)
    )

    register_builder_return = (
        bytes4_word(b"BRG1") + u256(42) + u256(1) + u256(3_456)
        + u256(8) + move_final_root
    )
    reserve_builder_return = (
        bytes4_word(b"BRV1") + u256(42) + u256(519) + u256(10) + reg_root
    )
    request_exit_return = (
        bytes4_word(bytes.fromhex("42524531")) + u256(42) + u256(800) + u256(1)
    )
    maintenance_return = (
        bytes4_word(b"BRM1") + u256(7) + u256(1) + u256(8) + move_final_root
    )
    normalize_return = (
        bytes4_word(b"BRN1") + u256(42) + u256(1) + u256(10) + reg_root
    )
    release_tranche_return = (
        bytes4_word(b"BTR1") + u256(42) + u256(519)
        + address_word(cell.address) + u256(10**17) + u256(10) + reg_root
    )
    release_generation_return = (
        bytes4_word(b"BGR1") + u256(42) + address_word(cell.address)
        + u256(cell.bond) + u256(8) + move_final_root
    )
    claim_builder_credit_return = (
        bytes4_word(b"BCL1") + address_word(0xCAFE) + u256(10**17)
    )
    equivocation_return = (
        bytes4_word(b"BEV1") + u256(42) + u256(20)
        + address_word(cell.address) + u256(10**16) + u256(9 * 10**16)
        + u256(8) + move_final_root
    )
    expire_schedule_return = bytes4_word(b"SWE1") + u256(8) + u256(521)
    assert tuple(map(len, (
        register_builder_return, reserve_builder_return, request_exit_return,
        maintenance_return, normalize_return, release_tranche_return,
        release_generation_return, claim_builder_credit_return,
        equivocation_return, expire_schedule_return,
    ))) == (192, 160, 128, 160, 160, 224, 192, 96, 256, 96)

    # Keep this assertion beside the vector: 64 consumed plus one boundary.
    assert verify_force_range(len(envs), 2, force_leaves[2:67], proof, force.root)
    return {
        "typehash": keccak256(TYPE_STRING.encode()).hex(),
        "domain_separator": eip712_domain(settlement_chain_id, contract).hex(),
        "block_struct_hash": block_struct_hash(block_values).hex(),
        "eip712_digest": eip712_digest(settlement_chain_id, contract, block_values).hex(),
        "canonical_core": core.hex(),
        "base_canonical": base.hex(),
        "candidate_commitment": candidate_hash.hex(),
        "candidate_commitment_2": candidate_hash_2.hex(),
        "normal_context": context.hex(),
        "winning_data": winning.hex(),
        "forced_descriptors": forced_descriptors.hex(),
        "schedule_list": schedules_hash.hex(),
        "session_list": sessions_hash.hex(),
        "execution_outputs": outputs_hash.hex(),
        "statement_hash": statement_commitment.hex(),
        "statement_reward_execution_gas": str(reward_execution_gas),
        "statement_reward_published_bytes": str(reward_published_bytes),
        "reward_receipt_v1_commitment": reward_receipt_commitment.hex(),
        "fund_reward_class_v1_selector":
            FUND_REWARD_CLASS_V1_SELECTOR.hex(),
        "fund_reward_class_v1_calldata_hash":
            keccak256(fund_reward_class_calldata).hex(),
        "fund_reward_class_v1_calldata_length":
            str(len(fund_reward_class_calldata)),
        "fund_reward_class_v1_return_length":
            str(len(fund_reward_class_returndata)),
        "claim_reward_v1_selector": CLAIM_REWARD_V1_SELECTOR.hex(),
        "claim_reward_v1_calldata_hash":
            keccak256(claim_reward_calldata).hex(),
        "claim_reward_v1_calldata_length": str(len(claim_reward_calldata)),
        "claim_reward_v1_return_hash": keccak256(
            claim_reward_return).hex(),
        "claim_reward_v1_return_length": str(len(claim_reward_return)),
        "claim_reward_v1_paid_wei": str(claim_reward_paid_wei),
        "reward_receipt_v1_selector": REWARD_RECEIPT_V1_SELECTOR.hex(),
        "reward_receipt_v1_calldata_hash":
            keccak256(reward_receipt_calldata).hex(),
        "reward_receipt_v1_calldata_length":
            str(len(reward_receipt_calldata)),
        "reward_receipt_v1_magic": REWARD_RECEIPT_V1_MAGIC.hex(),
        "reward_receipt_v1_present_return_hash":
            keccak256(reward_receipt_present_return).hex(),
        "reward_receipt_v1_missing_return_hash":
            keccak256(reward_receipt_missing_return).hex(),
        "reward_receipt_v1_return_length":
            str(len(reward_receipt_present_return)),
        "reward_receipt_v1_collision_candidate_id":
            collision_candidate_id.hex(),
        "registry_root": reg_root.hex(),
        "empty_registry_root": empty_registry_root.hex(),
        "admission_root": adm_root.hex(),
        "empty_admission_root": empty_admission_root.hex(),
        "admission_reuse_root": adm_reuse_root.hex(),
        "entry_root": ent_root.hex(),
        "empty_entry_root": empty_entry_root.hex(),
        "tranche_leaf": tranche.hex(),
        "registry_proof_digest": keccak256(b"".join(registry_proof)).hex(),
        "admission_proof_digest": keccak256(b"".join(admission_proof)).hex(),
        "entry_proof_digest": keccak256(b"".join(entry_proof)).hex(),
        "tranche_root": tranche_root_hash.hex(),
        "empty_tranche_root": empty_tranche_root.hex(),
        "tranche_proof_digest": keccak256(b"".join(tranche_proof)).hex(),
        "builder_registry_header_slot": BUILDER_REGISTRY_HEADER_SLOT.hex(),
        "builder_registry_root_slot": BUILDER_REGISTRY_ROOT_SLOT.hex(),
        "builder_registry_header_trie_key": br_header_trie_key.hex(),
        "builder_registry_root_trie_key": br_root_trie_key.hex(),
        "builder_registry_header_word": br_header.hex(),
        "builder_registry_exhausted_header_word":
            br_exhausted_header.hex(),
        "builder_move_pre_root": move_pre_root.hex(),
        "builder_move_intermediate_root": move_intermediate_root.hex(),
        "builder_move_final_root": move_final_root.hex(),
        "builder_cell_63_admission_root": cell_63_admission_root.hex(),
        "builder_admission_state_return_hash":
            keccak256(admission_state_return).hex(),
        "builder_schedule_registry_state_return_hash":
            keccak256(schedule_registry_state_return).hex(),
        "builder_schedule_window_release_return_hash":
            keccak256(schedule_window_release_return).hex(),
        "builder_settlement_schedule_release_return_hash":
            keccak256(settlement_schedule_release_return).hex(),
        "builder_vacancy_registration_witness_hash":
            keccak256(vacancy_registration_witness).hex(),
        "builder_vacancy_registration_witness_length":
            str(len(vacancy_registration_witness)),
        "builder_movement_witness_hash": keccak256(movement_witness).hex(),
        "builder_movement_witness_length": str(len(movement_witness)),
        "builder_maintenance_witness_hash":
            keccak256(maintenance_witness).hex(),
        "builder_maintenance_witness_length": str(len(maintenance_witness)),
        "builder_normalize_noop_witness_hash":
            keccak256(normalize_noop_witness).hex(),
        "builder_normalize_noop_witness_length":
            str(len(normalize_noop_witness)),
        "builder_normalize_witness_hash": keccak256(normalize_witness).hex(),
        "builder_normalize_witness_length": str(len(normalize_witness)),
        "builder_reserve_witness_hash": keccak256(reserve_witness).hex(),
        "builder_reserve_witness_length": str(len(reserve_witness)),
        "builder_active_tranche_release_witness_hash":
            keccak256(active_tranche_release_witness).hex(),
        "builder_active_tranche_release_witness_length":
            str(len(active_tranche_release_witness)),
        "builder_liability_tranche_release_witness_hash":
            keccak256(liability_tranche_release_witness).hex(),
        "builder_liability_tranche_release_witness_length":
            str(len(liability_tranche_release_witness)),
        "builder_generation_release_witness_hash":
            keccak256(generation_release_witness).hex(),
        "builder_generation_release_witness_length":
            str(len(generation_release_witness)),
        "builder_active_equivocation_witness_hash":
            keccak256(active_equivocation_witness).hex(),
        "builder_active_equivocation_witness_length":
            str(len(active_equivocation_witness)),
        "builder_liability_equivocation_witness_hash":
            keccak256(liability_equivocation_witness).hex(),
        "builder_liability_equivocation_witness_length":
            str(len(liability_equivocation_witness)),
        "builder_proof_verifier_config_selector":
            BUILDER_PROOF_CONFIG_SELECTOR.hex(),
        "builder_proof_verifier_config_hash": proof_verifier_config_hash.hex(),
        "builder_proof_verifier_config_return_hash":
            keccak256(proof_verifier_config_return).hex(),
        "builder_proof_identity_selector":
            BUILDER_PROOF_IDENTITY_SELECTOR.hex(),
        "builder_proof_identity_calldata_hash":
            keccak256(evidence_identity_calldata).hex(),
        "builder_proof_identity_calldata_length":
            str(len(evidence_identity_calldata)),
        "builder_proof_identity_return_hash":
            keccak256(evidence_identity_return).hex(),
        "builder_proof_identity_return_length":
            str(len(evidence_identity_return)),
        "builder_proof_request_selector": BUILDER_PROOF_REQUEST_SELECTOR.hex(),
        "builder_proof_registry_request_hash":
            keccak256(registry_replace_request).hex(),
        "builder_proof_registry_request_length":
            str(len(registry_replace_request)),
        "builder_proof_registry_calldata_hash":
            keccak256(registry_replace_calldata).hex(),
        "builder_proof_registry_return_hash":
            keccak256(registry_replace_return).hex(),
        "builder_proof_admission_request_hash":
            keccak256(admission_replace_request).hex(),
        "builder_proof_admission_request_length":
            str(len(admission_replace_request)),
        "builder_proof_admission_calldata_hash":
            keccak256(admission_replace_calldata).hex(),
        "builder_proof_admission_return_hash":
            keccak256(admission_replace_return).hex(),
        "builder_proof_tranche_request_hash":
            keccak256(tranche_batch_request).hex(),
        "builder_proof_tranche_request_length":
            str(len(tranche_batch_request)),
        "builder_proof_tranche_calldata_hash":
            keccak256(tranche_batch_calldata).hex(),
        "builder_proof_tranche_return_hash":
            keccak256(tranche_batch_return).hex(),
        "builder_proof_evidence_request_hash":
            keccak256(evidence_request).hex(),
        "builder_proof_evidence_request_length": str(len(evidence_request)),
        "builder_proof_evidence_calldata_hash":
            keccak256(evidence_request_calldata).hex(),
        "builder_proof_evidence_return_hash":
            keccak256(evidence_request_return).hex(),
        "builder_proof_evidence_active_tombstoned_request_hash":
            keccak256(active_tombstoned_evidence_request).hex(),
        "builder_proof_evidence_active_tombstoned_return_hash":
            keccak256(active_tombstoned_evidence_return).hex(),
        "builder_proof_evidence_liability_first_request_hash":
            keccak256(liability_evidence_request).hex(),
        "builder_proof_evidence_liability_first_return_hash":
            keccak256(liability_evidence_return).hex(),
        "builder_proof_evidence_liability_tombstoned_request_hash":
            keccak256(liability_tombstoned_evidence_request).hex(),
        "builder_proof_evidence_liability_tombstoned_return_hash":
            keccak256(liability_tombstoned_evidence_return).hex(),
        "builder_register_calldata_hash":
            keccak256(register_builder_calldata).hex(),
        "builder_register_calldata_length": str(len(register_builder_calldata)),
        "builder_register_return_hash": keccak256(register_builder_return).hex(),
        "builder_register_return_length": str(len(register_builder_return)),
        "builder_reserve_calldata_hash":
            keccak256(reserve_builder_calldata).hex(),
        "builder_reserve_calldata_length": str(len(reserve_builder_calldata)),
        "builder_reserve_return_hash": keccak256(reserve_builder_return).hex(),
        "builder_reserve_return_length": str(len(reserve_builder_return)),
        "builder_request_exit_calldata_hash":
            keccak256(request_exit_calldata).hex(),
        "builder_request_exit_calldata_length": str(len(request_exit_calldata)),
        "builder_request_exit_return_hash": keccak256(request_exit_return).hex(),
        "builder_request_exit_return_length": str(len(request_exit_return)),
        "builder_maintenance_calldata_hash": keccak256(maintenance_calldata).hex(),
        "builder_maintenance_calldata_length": str(len(maintenance_calldata)),
        "builder_maintenance_return_hash": keccak256(maintenance_return).hex(),
        "builder_maintenance_return_length": str(len(maintenance_return)),
        "builder_normalize_calldata_hash": keccak256(normalize_calldata).hex(),
        "builder_normalize_calldata_length": str(len(normalize_calldata)),
        "builder_normalize_return_hash": keccak256(normalize_return).hex(),
        "builder_normalize_return_length": str(len(normalize_return)),
        "builder_release_tranche_calldata_hash":
            keccak256(release_tranche_calldata).hex(),
        "builder_release_tranche_calldata_length":
            str(len(release_tranche_calldata)),
        "builder_release_tranche_return_hash":
            keccak256(release_tranche_return).hex(),
        "builder_release_tranche_return_length": str(len(release_tranche_return)),
        "builder_release_generation_calldata_hash":
            keccak256(release_generation_calldata).hex(),
        "builder_release_generation_calldata_length":
            str(len(release_generation_calldata)),
        "builder_release_generation_return_hash":
            keccak256(release_generation_return).hex(),
        "builder_release_generation_return_length":
            str(len(release_generation_return)),
        "builder_claim_credit_calldata_hash":
            keccak256(claim_builder_credit_calldata).hex(),
        "builder_claim_credit_calldata_length":
            str(len(claim_builder_credit_calldata)),
        "builder_claim_credit_return_hash":
            keccak256(claim_builder_credit_return).hex(),
        "builder_claim_credit_return_length": str(len(claim_builder_credit_return)),
        "builder_equivocation_calldata_hash": keccak256(equivocation_calldata).hex(),
        "builder_equivocation_calldata_length": str(len(equivocation_calldata)),
        "builder_equivocation_return_hash": keccak256(equivocation_return).hex(),
        "builder_equivocation_return_length": str(len(equivocation_return)),
        "builder_expire_schedule_calldata_hash":
            keccak256(expire_schedule_calldata).hex(),
        "builder_expire_schedule_calldata_length": str(len(expire_schedule_calldata)),
        "builder_expire_schedule_return_hash":
            keccak256(expire_schedule_return).hex(),
        "builder_expire_schedule_return_length": str(len(expire_schedule_return)),
        **{
            f"builder_{name}": selector.hex()
            for name, selector in BUILDER_REGISTRY_SELECTORS.items()
        },
        "forced_leaf": force_leaves[0].hex(),
        "component_config_getter_selector":
            COMPONENT_CONFIG_GETTER_SELECTOR.hex(),
        "component_config_getter_gas_limit":
            str(COMPONENT_CONFIG_GETTER_GAS_LIMIT),
        "builder_registry_configuration_hash":
            builder_registry_configuration_hash.hex(),
        "reward_class_v1_selector": REWARD_CLASS_V1_SELECTOR.hex(),
        "reward_class_v1_calldata_hash":
            keccak256(reward_class_calldata).hex(),
        "reward_class_v1_calldata_length":
            str(len(reward_class_calldata)),
        "reward_class_v1_magic": REWARD_CLASS_V1_MAGIC.hex(),
        "reward_class_v1_return_hash": keccak256(
            reward_class_return).hex(),
        "reward_class_v1_return_length": str(len(reward_class_return)),
        "reward_class_v1_class_id": str(reward_class_id),
        "reward_class_v1_call_gas":
            str(COMPONENT_CONFIG_GETTER_GAS_LIMIT),
        "enqueue_forced_transaction_selector":
            ENQUEUE_FORCED_TRANSACTION_SELECTOR.hex(),
        "enqueue_forced_transaction_calldata_hash":
            keccak256(enqueue_forced_calldata).hex(),
        "enqueue_forced_transaction_calldata_length":
            str(len(enqueue_forced_calldata)),
        "empty_data_session_accounting_return_hash":
            keccak256(empty_data_session_accounting_return).hex(),
        "funded_data_session_accounting_return_hash":
            keccak256(funded_data_session_accounting_return).hex(),
        "data_session_accounting_return_length":
            str(len(empty_data_session_accounting_return)),
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
        "schedule_fork_route_state_selector":
            SCHEDULE_FORK_ROUTE_STATE_SELECTOR.hex(),
        "verify_schedule_carrier_selector":
            VERIFY_SCHEDULE_CARRIER_SELECTOR.hex(),
        "fork_verifier_install_magic": FORK_VERIFIER_INSTALL_MAGIC.hex(),
        "fork_verifier_registration_magic":
            FORK_VERIFIER_REGISTRATION_MAGIC.hex(),
        "schedule_fork_verifier_config_magic":
            SCHEDULE_FORK_VERIFIER_CONFIG_MAGIC.hex(),
        "schedule_fork_route_state_magic":
            SCHEDULE_FORK_ROUTE_STATE_MAGIC.hex(),
        "schedule_fork_carrier_magic": SCHEDULE_FORK_CARRIER_MAGIC.hex(),
        "install_fork_verifier_calldata_hash": keccak256(
            install_fork_verifier_calldata).hex(),
        "initial_fork_registration_return_hash": keccak256(
            initial_fork_registration_return).hex(),
        "initial_fork_route_state_return_hash": keccak256(
            initial_fork_route_state_return).hex(),
        "initial_fork_verifier_config_return_hash": keccak256(
            initial_fork_verifier_config_return).hex(),
        "fork_verifier_registration_return_hash": keccak256(
            fork_verifier_registration_return).hex(),
        "schedule_fork_verifier_config_return_hash": keccak256(
            schedule_fork_verifier_config_return).hex(),
        "schedule_fork_route_state_hash": schedule_fork_route_state_hash(
            fork_route_registrations,
            fork_route_order,
            fork_route_used_digests,
        ).hex(),
        "schedule_fork_route_state_return_hash": keccak256(
            schedule_fork_route_state_return).hex(),
        "schedule_fork_route_state_return_length":
            str(len(schedule_fork_route_state_return)),
        "verify_schedule_carrier_calldata_hash": keccak256(
            verify_schedule_carrier_calldata).hex(),
        "verify_schedule_carrier_calldata_length":
            str(len(verify_schedule_carrier_calldata)),
        "schedule_carrier_statement_hash": schedule_statement_hash.hex(),
        "schedule_carrier_return_hash":
            keccak256(schedule_carrier_return).hex(),
        "expected_predecessor_fork_registration_hash":
            expected_predecessor_registration_hash.hex(),
        "expected_old_fork_registration_hash":
            expected_old_registration_hash.hex(),
        "replace_pending_fork_verifier_selector":
            REPLACE_PENDING_FORK_VERIFIER_SELECTOR.hex(),
        "replace_pending_fork_verifier_calldata_hash":
            keccak256(replace_fork_calldata).hex(),
        "replace_pending_fork_verifier_calldata_length":
            str(len(replace_fork_calldata)),
        "replace_pending_fork_verifier_return_hash":
            keccak256(replace_fork_return).hex(),
        "replace_pending_fork_verifier_return_length":
            str(len(replace_fork_return)),
        "split_latest_fork_verifier_selector":
            SPLIT_LATEST_FORK_VERIFIER_SELECTOR.hex(),
        "split_latest_fork_verifier_calldata_hash":
            keccak256(split_fork_calldata).hex(),
        "split_latest_fork_verifier_calldata_length":
            str(len(split_fork_calldata)),
        "split_latest_fork_verifier_return_hash":
            keccak256(split_fork_return).hex(),
        "split_latest_fork_verifier_return_length":
            str(len(split_fork_return)),
        "forced_queue_config_hash": forced_queue_config_hash(0xAD01, 0xB001).hex(),
        "kind0_forced_admission_schema_hash":
            keccak256(D_FORCE_USER_ADMISSION).hex(),
        "kind0_forced_admission_hash": keccak256(kind0_admission).hex(),
        "kind0_forced_admission_length": str(len(kind0_admission)),
        "forced_queue_config_selector": FORCED_QUEUE_CONFIG_SELECTOR.hex(),
        "forced_queue_state_selector": FORCED_QUEUE_STATE_SELECTOR.hex(),
        "forced_queue_frontier_selector": FORCED_QUEUE_FRONTIER_SELECTOR.hex(),
        "forced_queue_descriptor_selector": FORCED_QUEUE_DESCRIPTOR_SELECTOR.hex(),
        "forced_queue_due_at_selector": FORCED_QUEUE_DUE_AT_SELECTOR.hex(),
        "forced_queue_advance_selector": FORCED_QUEUE_ADVANCE_SELECTOR.hex(),
        "forced_queue_withdraw_selector": FORCED_QUEUE_WITHDRAW_SELECTOR.hex(),
        "settlement_forced_ingress_floor_selector":
            SETTLEMENT_FORCED_INGRESS_FLOOR_SELECTOR.hex(),
        "settlement_forced_ingress_floor_magic": b"SIF1".hex(),
        "settlement_forced_ingress_floor_call_gas":
            str(SETTLEMENT_FORCED_INGRESS_FLOOR_GAS),
        "settlement_forced_ingress_floor_normal_return_hash":
            keccak256(normal_forced_ingress_floor_return).hex(),
        "settlement_forced_ingress_floor_recovery_return_hash":
            keccak256(recovery_forced_ingress_floor_return).hex(),
        "settlement_forced_ingress_floor_return_length":
            str(len(normal_forced_ingress_floor_return)),
        "forced_queue_config_return_hash":
            keccak256(queue_config_return).hex(),
        "forced_queue_config_return_length":
            str(len(queue_config_return)),
        "forced_queue_empty_state_return_hash":
            keccak256(queue_empty_state_return).hex(),
        "forced_queue_state_return_length":
            str(len(queue_empty_state_return)),
        **{
            key: value.hex()
            for key, value in FORCED_QUEUE_EVENT_TOPICS.items()
        },
        "data_session_config_hash": session_config_hash.hex(),
        **{
            key: value.hex()
            for key, value in session_function_selectors.items()
        },
        **{key: value.hex() for key, value in session_event_topics.items()},
        **{key: value.hex() for key, value in reward_event_topics.items()},
        "candidate_committed_v2_topic_count":
            str(len(candidate_log_topics)),
        "candidate_committed_v2_topic1_candidate_id":
            candidate_log_topics[1].hex(),
        "candidate_committed_v2_topic2_beneficiary":
            candidate_log_topics[2].hex(),
        "candidate_committed_v2_topics_hash":
            keccak256(b"".join(candidate_log_topics)).hex(),
        "candidate_committed_v2_data_hash":
            keccak256(candidate_log_data).hex(),
        "candidate_committed_v2_data_length": str(len(candidate_log_data)),
        "reward_class_funded_v1_topic_count":
            str(len(funded_log_topics)),
        "reward_class_funded_v1_topic1_reward_class":
            funded_log_topics[1].hex(),
        "reward_class_funded_v1_topic2_funder":
            funded_log_topics[2].hex(),
        "reward_class_funded_v1_topics_hash":
            keccak256(b"".join(funded_log_topics)).hex(),
        "reward_class_funded_v1_data_hash":
            keccak256(funded_log_data).hex(),
        "reward_class_funded_v1_data_length": str(len(funded_log_data)),
        "reward_claimed_v1_topic_count": str(len(claimed_log_topics)),
        "reward_claimed_v1_topic1_candidate_id":
            claimed_log_topics[1].hex(),
        "reward_claimed_v1_topic2_beneficiary":
            claimed_log_topics[2].hex(),
        "reward_claimed_v1_topics_hash":
            keccak256(b"".join(claimed_log_topics)).hex(),
        "reward_claimed_v1_data_hash": keccak256(claimed_log_data).hex(),
        "reward_claimed_v1_data_length": str(len(claimed_log_data)),
        "forced_root": force.root.hex(),
        "empty_forced_root": ForceVector(()).root.hex(),
        "force_range_digest": keccak256(b"".join(proof)).hex(),
        "force_frontier_after_1_digest": keccak256(
            b"".join(force_frontier_after_1)).hex(),
        "force_frontier_root_1": force_frontier_root_1.hex(),
        "session_id": sid.hex(),
        "empty_data_bag": mmr_root(()).hex(),
        "mmr_root_2": mmr_root((leaf0, leaf1)).hex(),
        "mmr_root_3": mmr_root_3.hex(),
        "data_mmr_frontier_after_3_digest": keccak256(
            b"".join(data_mmr_frontier_after_3)).hex(),
        "data_mmr_frontier_root_3": data_mmr_frontier_root_3.hex(),
        "data_mmr_proof_count": str(data_mmr_proof_count),
        "data_mmr_proof_index": str(data_mmr_proof_index),
        "data_mmr_proof_leaf": data_mmr_proof_leaf.hex(),
        "data_mmr_proof_root": data_mmr_proof_root.hex(),
        "data_mmr_mountain_siblings_digest": keccak256(
            b"".join(data_mmr_proof_fixture.mountain_siblings)).hex(),
        "data_mmr_other_peaks_digest": keccak256(
            b"".join(data_mmr_proof_fixture.other_peaks)).hex(),
        "asymmetric_data_leaf": asymmetric_data_leaf.hex(),
        "data_node_height_7": data_node_height_7.hex(),
        "manifest_root": manifest.hex(),
        "manifest_root_block_1": manifest_block_1.hex(),
        "asymmetric_manifest_leaf": asymmetric_manifest_leaf.hex(),
        "manifest_node_height_5": manifest_node_height_5.hex(),
        "empty_body_root": empty_body.hex(),
        "empty_manifest_root": empty_manifest.hex(),
        "empty_session_list": empty_sessions.hex(),
        "recovery_id": recovery_id(settlement_chain_id, contract, 4, 2, base, 8_000,
                                   1_000, bytes.fromhex("88" * 32), force.root,
                                   len(envs), 12, adm_root, 9_000, 3).hex(),
        "body_root": body.hex(),
        "chunk_root_0": c0.hex(),
    }


EXPECTED = {'admission_proof_digest': '65a5501dc5440301031bc0d21ac6506ce1f98b226139c93ab54251883d5bd12d',
 'admission_reuse_root': 'a1e22890dd835872055e53dcad82d9e12759a2920853fe6e9f735d7f2c87ceca',
 'admission_root': '3bf2dcaf78292c832108e29205bf99cc2d22137a0545e4528d8da7309d4b482b',
 'asymmetric_data_leaf': '204849a6179174bd92e677b252370e3e2904cf4eb2a94fe1ba154e1310b9cd64',
 'asymmetric_manifest_leaf': '92ed7b0f26f1048042ad681be312e3d79d6942ea6da03445c1cc8fd6b1eb1d6b',
 'base_canonical': '7209a0d225dd6f54483f24072ebf0fe258d73815ee54735f0ee6f505856c2857',
 'block_struct_hash': '55021a9fe6408f6bbe52bad826bf24e65cbee639fac8f5266817f3b5c3cf0d78',
 'body_root': '0f4e161a46c8b18c2a86f23a0a4e7169a838a12af8b389f65e97b547a99707e9',
 'builder_active_equivocation_witness_hash': '188ff80cdad2d9fa2ddd8ad27b943a478dca3558d5467405494abd29e9f4a792',
 'builder_active_equivocation_witness_length': '2366',
 'builder_active_tranche_release_witness_hash': '2246b6c4067d8dbfffd57072507c4fa03fa9f59b18747907fdde87cf4fbc2c8d',
 'builder_active_tranche_release_witness_length': '480',
 'builder_admission_state_return_hash': '4adb66ffb320e14ef37f1630bacdd71f03bcdfbb006d0c1a15a0312c3b80a91d',
 'builder_admission_state_selector': '4a9dfa3f',
 'builder_cell_63_admission_root': 'a7331d780dab70d17c02c0cedf929a63f970b0baef2c456688c21537efcd1845',
 'builder_claim_builder_lease_credit_selector': '8f73793c',
 'builder_claim_credit_calldata_hash': '870c91e9f2ed3494f25ca60447440e8af94c7fe849aeaca24c7020cbe2dad7c2',
 'builder_claim_credit_calldata_length': '36',
 'builder_claim_credit_return_hash': '84a21bcf213c894bd35733058dfa3a592bbe8a1ae5f74e36ff3be371c0c3be9b',
 'builder_claim_credit_return_length': '96',
 'builder_equivocation_calldata_hash': 'bd470ac24fe185aca71cff7e8c27944e78baae430628101075916cfb15ffbf0b',
 'builder_equivocation_calldata_length': '2436',
 'builder_equivocation_return_hash': 'eb9cab44a43adcc764cf488ade4f8e8fab85dab8cab6a5762cd6e3cbd9939eb6',
 'builder_equivocation_return_length': '256',
 'builder_expire_schedule_calldata_hash': '4f1b5f49458cc8f4f22f9745a61accc177cd37d4412bfadd74c9c5006b9083f5',
 'builder_expire_schedule_calldata_length': '36',
 'builder_expire_schedule_return_hash': '347b76314feb452be5b5f8dfa655b368cf0ae1656b7e14e0488b4bc170d0ac6f',
 'builder_expire_schedule_return_length': '96',
 'builder_expire_schedule_windows_selector': 'b1357479',
 'builder_generation_release_witness_hash': '65a5501dc5440301031bc0d21ac6506ce1f98b226139c93ab54251883d5bd12d',
 'builder_generation_release_witness_length': '352',
 'builder_liability_equivocation_witness_hash': '0519c74fd1e6a928712e539113d78caf24abf2cd39bb6fc8fe3e807861403897',
 'builder_liability_equivocation_witness_length': '2366',
 'builder_liability_tranche_release_witness_hash': '8d56574545d36cb4cbb7f1452055275a3dbd8e5b2aa9062e717095f387a0a2d8',
 'builder_liability_tranche_release_witness_length': '288',
 'builder_maintenance_calldata_hash': '43c78baee19458e9328ff2b4da6b599d2837762bc2c59fd3bd2c99c9a4ef90ae',
 'builder_maintenance_calldata_length': '1316',
 'builder_maintenance_return_hash': '71d89327348795bdfb10797b1a4d8fbed80736e9e283d99f004dd4a3eeb3ca55',
 'builder_maintenance_return_length': '160',
 'builder_maintenance_witness_hash': 'd39a171735fce188e821a1f30d45690e429d1980c8a9ca784d197fc9146fd67b',
 'builder_maintenance_witness_length': '1197',
 'builder_move_final_root': '6ffdad931d0bc04bd668e66d5deb74ce13feb987ad05525f2e1634e1dc4ccc95',
 'builder_move_intermediate_root': 'e65acea99c98a79044078e8835688758b97b5fb9931f449ab785b3aa3ab3809c',
 'builder_move_pre_root': '3e961c42d94ba762f1d8e855bc9ac168bcdcd35177c381403574ae2c5fa03a0e',
 'builder_movement_witness_hash': '03028017c34313fc451f9327085f6cbe2f2d24c05303a7d29c69c035b9e689d0',
 'builder_movement_witness_length': '1193',
 'builder_normalize_builder_tranches_selector': '5e7c8afe',
 'builder_normalize_calldata_hash': 'a5fe18f847780330e44bfd30b196a3aefb5bdd60a0c5bcfc2160d1dcf4738f65',
 'builder_normalize_calldata_length': '644',
 'builder_normalize_noop_witness_hash': 'bc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a',
 'builder_normalize_noop_witness_length': '1',
 'builder_normalize_return_hash': 'a1074a8b86686267c3a23a084c9a9ae67808925eb857e4c87f66904cb354e098',
 'builder_normalize_return_length': '160',
 'builder_normalize_witness_hash': '41aa2500f6787f0ff38398f6a481ab02641b948e56609939ae1ac4311a05eaa7',
 'builder_normalize_witness_length': '489',
 'builder_process_builder_maintenance_selector': '0e1ffc68',
 'builder_proof_admission_calldata_hash': '419032e2b6eb7dc900b2ad948d4fa3c0ad0eae90a8f4bf3a87d3883ee3fd3ea8',
 'builder_proof_admission_request_hash': '99c130943aa4780be4a2888146d65d62bad146f46ab501c39b38f19a267e667d',
 'builder_proof_admission_request_length': '531',
 'builder_proof_admission_return_hash': '3079820b97ad6bad7583cc6cb30ee43305609059f8e84065e1525dc9e24c31a1',
 'builder_proof_evidence_active_tombstoned_request_hash': '360f07315cde09617cb4212a97b19f0fda328685d736895ef8c6094012e7cce9',
 'builder_proof_evidence_active_tombstoned_return_hash': '85dacb33edf0ea6c19a74451d98362c2450fd2b59e32af6668350b9ead352907',
 'builder_proof_evidence_calldata_hash': '58b74233e9726648d037a57a88cd38fbccb218a1d29372927de0e0d00e225796',
 'builder_proof_evidence_liability_first_request_hash': '38bd6788fb25962a5999192cb1297e2b418c47d813202f9000e2eb18773e0278',
 'builder_proof_evidence_liability_first_return_hash': '9f27ea85a06bc785ab2dfbb6c72a416d8250e1751bfa855d459f6647ee7bdff0',
 'builder_proof_evidence_liability_tombstoned_request_hash': '338141019dd003d9f78753bdaee43182f3975d13a8e6dbf849a3d50646c115f4',
 'builder_proof_evidence_liability_tombstoned_return_hash': '0720e4d2652e04c3bc2650eb4f98352e2fdb802ff5a86949b49ca001bcac2850',
 'builder_proof_evidence_request_hash': '536d3467985ad79a2fe9f6e678d99074fcecc5520dbb61726f3aee3dc3f44e12',
 'builder_proof_evidence_request_length': '2727',
 'builder_proof_evidence_return_hash': '86e51e0573d4086a0099a49683b1277bd2df6f087a1884c6bf952854c7e2916f',
 'builder_proof_identity_calldata_hash': '0efda928731baac8c13e31a788b6856c167cb3d5cb43cc8460414ddba5c757ff',
 'builder_proof_identity_calldata_length': '2468',
 'builder_proof_identity_return_hash': '3e2522216063d4d132365c2b2c6547f1dad4e364ce430373da37ccabede24600',
 'builder_proof_identity_return_length': '320',
 'builder_proof_identity_selector': '7c09d62d',
 'builder_proof_registry_calldata_hash': '3bc203afce7c1aeb21360ea97544bc6991a216025b5ce2c37e065a4bc1588246',
 'builder_proof_registry_request_hash': '63fa85a7efd66ff4db6c06fdd6dbfa44541d8274c1ca8739daa9796f382ff10a',
 'builder_proof_registry_request_length': '432',
 'builder_proof_registry_return_hash': '254f7c15aa1a9533874d6e6409c2ea709f696d80474c8f485c22d355f2ffd3ca',
 'builder_proof_request_selector': 'a9ca9190',
 'builder_proof_tranche_calldata_hash': '5b5ed9cdd24cab6214555f3c72269b69c17bb2d2f344dbf4c213b9b840ca023c',
 'builder_proof_tranche_request_hash': 'f565dd15d53c115c993356953af777950dc0408106a85a53501da7b54fdb762d',
 'builder_proof_tranche_request_length': '412',
 'builder_proof_tranche_return_hash': 'c5980443c2976303be7176297d57a75020e23dbf0fd9717f384e3a6012264594',
 'builder_proof_verifier_config_hash': 'f1a01e067ec17b34e4f190810b2ebedfddd92a125705d2fd60134ce361ffac1a',
 'builder_proof_verifier_config_return_hash': 'eb1e75edfa0e3c8e1809071f51985fbdc2848eb8f65d7378d979a62b6d1ac862',
 'builder_proof_verifier_config_selector': '0d1c9932',
 'builder_register_builder_selector': '5fc42c69',
 'builder_register_calldata_hash': '9f18fd55e769f2cb66a0886f78c2c27e975a5cc1bd6a91cc505587350ecf12d3',
 'builder_register_calldata_length': '708',
 'builder_register_return_hash': '4297459afb1ea5b55dfde89615c2fc6fcf9a3c5169992544cf455ac40b34d3fd',
 'builder_register_return_length': '192',
 'builder_registry_configuration_hash': '5c2fe6d16935d1557c545b24c0b5982391f7a8ac702d7db3a6c55e467427ed79',
 'builder_registry_exhausted_header_word': '4252483101400100ffffffffffffffffffffffffffffffff0000000000000000',
 'builder_registry_header_slot': 'e7ce7a505bf18b9ed57a0785851385323c9487991c55b422861381f92e5c245a',
 'builder_registry_header_trie_key': '3dc336ad17079f9525d2b0708a8773321ab29957d522a6f2d10fc522b7362aec',
 'builder_registry_header_word': '42524831013f0000010203040506070811121314151617182122232425262728',
 'builder_registry_root_slot': '4dc6f1bf199f7518c646d40ed35ca04703f646273e6de1d7eace0746cc7100a6',
 'builder_registry_root_trie_key': '04bafd6333ae949248e59a002ce1fbccb8a4bc8da3a0c3228ae523d727170880',
 'builder_release_builder_generation_selector': 'e7bae370',
 'builder_release_builder_tranche_selector': 'f8668bb9',
 'builder_release_generation_calldata_hash': '3a737cfe76c2cd421f226d122366b8eb4b2c0d15ff8ce9ee9662fb1ebdbd0ef5',
 'builder_release_generation_calldata_length': '484',
 'builder_release_generation_return_hash': 'e10ddf1201ccd056229850f387844bb41a5dc22095e1d6eaff44aaee1dda7705',
 'builder_release_generation_return_length': '192',
 'builder_release_tranche_calldata_hash': '3abab4635081cb16695ba53983b7f77f512196f554b9d02a4f523dc265e87fea',
 'builder_release_tranche_calldata_length': '644',
 'builder_release_tranche_return_hash': '0775b71ba1f5c778f429c183127db5b39699a4c28a34acd8c9c7e43e59472d3f',
 'builder_release_tranche_return_length': '224',
 'builder_request_builder_exit_selector': 'c8f20b55',
 'builder_request_exit_calldata_hash': '83df22506dc47e476d2f4ffac8545afbda7c63d90e099ff0f531d81928a48297',
 'builder_request_exit_calldata_length': '36',
 'builder_request_exit_return_hash': '2b6bf8ef73a6acb0795c0cd086f3c906b83d2883f555b6b163a468bf41645fb9',
 'builder_request_exit_return_length': '128',
 'builder_reserve_builder_window_selector': '46a53315',
 'builder_reserve_calldata_hash': '7042284258b75a7e1154eb3d9ed48780c1099ef78ac5cb4d1f71222064dfd3f7',
 'builder_reserve_calldata_length': '932',
 'builder_reserve_return_hash': '84d4b9be382a7c941e0af0304e4feec46929c40ca71770121c21b08afef7aced',
 'builder_reserve_return_length': '160',
 'builder_reserve_witness_hash': 'e41b49dd7050df0b699dfe13a197c0ca366bfed9f06d8f823771f678a565d409',
 'builder_reserve_witness_length': '777',
 'builder_schedule_registry_state_return_hash': '4abc972ad2bcb73d21e82e60a4fba80df1c6646fa376fe873da7eecae3baa492',
 'builder_schedule_registry_state_selector': 'ad95cea1',
 'builder_schedule_window_release_return_hash': 'f0160669e33a104e916a3d5bdf5c3051fbe0f06ab42a445ccd7708631e64b77e',
 'builder_schedule_window_release_selector': 'f4cd9a5e',
 'builder_settlement_schedule_release_return_hash': 'dad610bad2145e2431a6a6298f62dc7e08fc01f5a80d6f933a91b557a4ee9a84',
 'builder_settlement_schedule_release_selector': 'a4574c77',
 'builder_submit_builder_equivocation_selector': '979c1f72',
 'builder_vacancy_registration_witness_hash': '5338baeca36696fec8f42f2f4f9d183c182f5ebc479478e0e4c9e59c9355771b',
 'builder_vacancy_registration_witness_length': '544',
 'candidate_commitment': '1478b5999deac0929581369516027f5bf1c5b353a27356ea1530cd6646dd0308',
 'candidate_commitment_2': 'c6bf847e5660ae4b6d914d00d28506d5dec24955f7130722c8f0e616cd69974d',
 'candidate_committed_v2_data_hash': 'f48d42355288f3da84b490bc7c2a08935b3a62130fd5ab316aac8d87eaf88c3e',
 'candidate_committed_v2_data_length': '192',
 'candidate_committed_v2_topic': '51629f6515f461b4c6f912a8eecad46d8ff89ab5e8235d95c30004be2c9ac738',
 'candidate_committed_v2_topic1_candidate_id': '39c621a869a95ddaf350d45f0c67094a57ac24d7b36a9bd1f57a75d5310dce2b',
 'candidate_committed_v2_topic2_beneficiary': '000000000000000000000000000000000000000000000000000000000000cafe',
 'candidate_committed_v2_topic_count': '3',
 'candidate_committed_v2_topics_hash': '2bd53ab73ae6841a50e7e17af3fb0204ffe1bab823e523017bbb0cf0b32072e4',
 'canonical_core': '0362d14c4c2fc6293710a0ca8cf2e19f83a5555ecab59bd19b4f58a75d587091',
 'chunk_root_0': 'e652cb05b1f44f3c09c650870b7b9ade4132548bd0c769bdda35b5bfcac5139e',
 'claim_reward_v1_calldata_hash': 'dc435de2896a3f9fba5006cb40107aee657dfdd19153f52a09e6fc537aa9922d',
 'claim_reward_v1_calldata_length': '36',
 'claim_reward_v1_paid_wei': '1000000',
 'claim_reward_v1_return_hash': 'c1af4b94166cd32fc49b7b926cbb91ee421de2d04450e8ae57857b9b56ac7e53',
 'claim_reward_v1_return_length': '32',
 'claim_reward_v1_selector': 'aa5498cb',
 'component_config_getter_gas_limit': '50000',
 'component_config_getter_selector': 'f6c0f7d2',
 'data_mmr_frontier_after_3_digest': '7e141a72088ecc5ed590e1e619b607fb5d97aafb003c4a56230cff2832c2af01',
 'data_mmr_frontier_root_3': 'dea2c7de9f14ce6f9c59fda963520ced2cb6e6ebef7c6abe6cb773afab888e89',
 'data_mmr_mountain_siblings_digest': '3ad2e114ce1d543a3a479e69b945dfeabdfdd0fc6df543b28c069469ea5e26fa',
 'data_mmr_other_peaks_digest': 'd5b32274fe3e21ffa9dbaf5853b469ecaaf4ac295e788fc95c16b4220a00b196',
 'data_mmr_proof_count': '15',
 'data_mmr_proof_index': '10',
 'data_mmr_proof_leaf': '39d13a13b5803fd94af45496a7b19e2e666957cd75780ed2508c702a703ca85b',
 'data_mmr_proof_root': '7c7185dfbebadab3501e051b2960e8fb4b22dd11821fc4e474ef14b2edb27b22',
 'data_node_height_7': 'e60d61327adb017addbf3012131b62c0a5897d30e302fcfac9ffad46d0fe848a',
 'data_record_appended_topic': '30ee2de166c53a480d028e5b94d4f8759dbd84b5f7b6af1f23e0c5889ea17f8c',
 'data_session_accounting_return_length': '512',
 'data_session_config_hash': '34595a6d8a662ccfd6df02d62878d8056d9a66e7b437ea8e4ae71547c245befe',
 'data_sessions_maintained_topic': '920669b9670911aa86cd718dceebaa1372d224ca0fdac50a63dc1d45a53e1e89',
 'domain_separator': 'e68571dca46842abc561c1ea35b556152b15d93a1d29f5c441ae2fdcdd01725c',
 'eip712_digest': '71dbc886b2be3e2a2b692976ca6b0e42957915d83df76859637a08c92f7a24d1',
 'empty_admission_root': '71a511ce5247c6c3b0411e182c8e4b4dcbd0adc97163c585cac94ca3b031ac54',
 'empty_body_root': 'f0e00da8dbc00feb028a8bc92342c0771372b947acf5989b2d4a5f23bb2f459a',
 'empty_data_bag': 'b3caa2379816b63eebbf789e33e7d84ef29d6d350179803dd000102e8182f66a',
 'empty_data_session_accounting_return_hash': 'd67be4bb9b559b619c0324ce0f890e8446e55f420593a63d6eb1739f4dd28e4e',
 'empty_entry_root': '986d3e795bd9ddfabe213b93cea0211eea5a663e895bfc112d90c5bf2fff1564',
 'empty_forced_root': '4001bca0d3c5171a99a50118f1219024e1bef9302262ea3b075ecbed36be7592',
 'empty_manifest_root': '0bb15f38645cecc1748b17fe3bd966ba8016c169ebd1266fd38150766177b5f6',
 'empty_registry_root': '2f40c290594200091bcd31881e40bf56ba1960016a24c9931cf3b1a9a8705ae8',
 'empty_session_list': '8827f09b5799bab18f29ea5b9cb9cbb5a88ddb96bc4b3ffc4d69cbcbdfe50279',
 'empty_tranche_root': 'dee49bfb4494eee086cf6485f471866cd49591358b3490d4a156813702501768',
 'enqueue_forced_transaction_calldata_hash': '3e802e6f72e50c267cc18d256c2863d04446eb8f2d47bc474bbcb9c68876d19a',
 'enqueue_forced_transaction_calldata_length': '196',
 'enqueue_forced_transaction_selector': '9f06b1b4',
 'entry_proof_digest': '89655918472451054bf7362e8e7b19bbded634877c532efdfb545e0ca36667f3',
 'entry_root': 'acee83a690b868a4a7960c55a9f7228f91cad26b704e24106d4db87e9c7a8f34',
 'execution_outputs': '01ab23ac7b0a92af32ace3220c3b181ef983f4be274c997ef2d4b50d9c7669cd',
 'expected_old_fork_registration_hash': 'eed5e788c296e7b8449f4aacb62cd9e5b15ec488dc667f4cf3e3aa48a244c6c5',
 'expected_predecessor_fork_registration_hash': '233d72ef0935f897e49377ce160962e2ea7ea14c37c309bb094b78e0b50bb118',
 'force_frontier_after_1_digest': '1ba50296675195de90944defd33d2e346c1a996aa6edbb5bfb1b187cc64b3c1d',
 'force_frontier_root_1': '5cb37cac8283fe7742e0f8e40bacececf85c1f8c15a05c8a9c9dc2018ac532e8',
 'force_range_digest': '75c75611d9eaa6c05e56a1fb646cea4c9d796adfd205df5c5ff1b0b52cc93dd2',
 'forced_descriptors': 'ccc81a65638181195f6ebd5b5902bc3a62716d7c3e70b32cbabdd250b9ebf42f',
 'forced_leaf': 'c75c50d8b8573f217a20c9018a3d23d7fa5cda240f2a2e9eb4260c4af4c367e4',
 'forced_queue_advance_selector': 'd59ff200',
 'forced_queue_appended_topic': '79250628d474df83f40598f02c49d25e713fb04a8ef4bd4457fa70055a86f489',
 'forced_queue_claim_withdrawn_topic': '93cc2e9cd74702c3df0d771c2b1901ca496935e81636c3e6f0e5d7e0d7f5dd74',
 'forced_queue_config_hash': '22308d0cff70d354e3a7d3121641c832c08f017f5921bb51e323d73075f5b42e',
 'forced_queue_config_return_hash': '82d2db524021dc52e9290e6788f12ae0ac79a8942ee492f73821a87aac05da55',
 'forced_queue_config_return_length': '256',
 'forced_queue_config_selector': '8136fe31',
 'forced_queue_cursor_advanced_topic': '972ed56e80520f8e90eb897f4f0e5b59f1167d96d3b28e0432f80c96c53aff17',
 'forced_queue_descriptor_selector': 'bd9534db',
 'forced_queue_due_at_selector': '530fd138',
 'forced_queue_empty_state_return_hash': '7bedaeca0f43c5716622c50492355e983d8fbf676a52aa92216e29cd4cfee967',
 'forced_queue_frontier_selector': '7c339ff7',
 'forced_queue_state_return_length': '320',
 'forced_queue_state_selector': '03e0d70b',
 'forced_queue_withdraw_selector': 'c28aa0e8',
 'forced_root': 'a54e9f797ffe7f04dd5ca7df4c858edf02ce45a81808522633fc9cee8fe72e57',
 'fork_verifier_install_magic': '46564931',
 'fork_verifier_registration_magic': '46565231',
 'fork_verifier_registration_return_hash': '252a8f9b5199a2b88f07e01d89d4fabb49903713d19500ca1cf34ad3fbf9c00f',
 'fork_verifier_registration_selector': 'c614591c',
 'fund_reward_class_v1_calldata_hash': '1086e7c6ffda5d1b4d31999795549a413160e18f638c43801cf6bd8293b430f1',
 'fund_reward_class_v1_calldata_length': '36',
 'fund_reward_class_v1_return_length': '0',
 'fund_reward_class_v1_selector': '15e08308',
 'funded_data_session_accounting_return_hash': '55cd2bd22ee66b28bc689013b9fc33c299c4d3802f250e67375b1cabbbb1c756',
 'initial_fork_registration_return_hash': 'd2044ac981fb5358a1354c6ba4ad2bee5f994361fe188f99099e89ba6b62c6dc',
 'initial_fork_route_state_return_hash': 'ce1242ef9f6de662b939f857e86aa5c8a585bfd78fa3b285d3804b154ac16dbb',
 'initial_fork_verifier_config_return_hash': 'ed485e43081733b49a3da6e22a1d1e54126837f94cb816d888bd29f3d3e12b1c',
 'install_fork_verifier_calldata_hash': '67ab3af72e37b0366daf3887450a66395aa7d45fb4114d323d6d80a083ae6dbf',
 'install_fork_verifier_selector': '9bb6fe73',
 'kind0_forced_admission_hash': '3733764f042a48dfc4376c14c2f9c253f3a0ae0fc8e72a1e9e5ffd00aa9a0f3d',
 'kind0_forced_admission_length': '204',
 'kind0_forced_admission_schema_hash': '6c5da3090966e605a84a39083d1e31c8a975527faff01d52a6728eea90c03700',
 'manifest_node_height_5': '9f4c64a89c253d4d65f93cba1f55e7a17a3e4027be7351650060632ed1bc70f0',
 'manifest_root': '417be737a57e38eb410f2d6e65c77ee19d5c314cdaf432067861c6a36c6a990f',
 'manifest_root_block_1': 'c58ab29bdccb3e06cc5431fbbcea1abc6d6f1a38120c5d896e18b7f1ca1cf43e',
 'mmr_root_2': 'd20459aeb2fe916a18dd584d39b2ae25075c6b6c14104d9d64a8b1d7882eb4df',
 'mmr_root_3': 'dea2c7de9f14ce6f9c59fda963520ced2cb6e6ebef7c6abe6cb773afab888e89',
 'normal_context': 'f13be874ddd561c733c4bebe725fde7f7770661520f73e4bb99c383f40f579e6',
 'recovery_id': '1d70fb5798b55f7a4b4b2f4b0f8b4472e63b9ff6853011680c516cf614293057',
 'registry_proof_digest': '188d53708f68cd601ace09953d87031b89c92f5b9d7bffd847e324ab7adc8261',
 'registry_root': '0bf297d7b9b6a5529a319a06cb08484923a89bab15d51f8baeaf5c30bebdf3fd',
 'replace_pending_fork_verifier_calldata_hash': '7f5672e814198405380028deb977bebdad7c69273d1b9b2c72edf8ca26982aca',
 'replace_pending_fork_verifier_calldata_length': '548',
 'replace_pending_fork_verifier_return_hash': '9b9e757b4ebf73b65db810d4bd2da658f26d189916c4b97595c5470ad7972534',
 'replace_pending_fork_verifier_return_length': '160',
 'replace_pending_fork_verifier_selector': 'b48bbef1',
 'reward_claimed_v1_data_hash': 'db2be80ad7fe2991fbabee31c9917dca99f927a94e09c6a4e810cec6d4a8cbae',
 'reward_claimed_v1_data_length': '64',
 'reward_claimed_v1_topic': '9f41046da255bf29062408ae9f20e06ea2453df29227caf32b709ccfed59d506',
 'reward_claimed_v1_topic1_candidate_id': '39c621a869a95ddaf350d45f0c67094a57ac24d7b36a9bd1f57a75d5310dce2b',
 'reward_claimed_v1_topic2_beneficiary': '000000000000000000000000000000000000000000000000000000000000cafe',
 'reward_claimed_v1_topic_count': '3',
 'reward_claimed_v1_topics_hash': '774116b1e415ba1f16dd1c36bdf890120b091c4bddec662346eeb2a1e1c0f0d9',
 'reward_class_funded_v1_data_hash': 'e1aede520e7a9dc85a896fcdc9cc395ef1f2fd03d93f7e4f6acbd5fda09bf690',
 'reward_class_funded_v1_data_length': '96',
 'reward_class_funded_v1_topic': 'd979ecc5f5821fb9e6643744111b04290fc1da57eebaba07def52e526c6eb49e',
 'reward_class_funded_v1_topic1_reward_class': '0000000000000000000000000000000000000000000000000000000000000001',
 'reward_class_funded_v1_topic2_funder': '000000000000000000000000000000000000000000000000000000000000f00d',
 'reward_class_funded_v1_topic_count': '3',
 'reward_class_funded_v1_topics_hash': 'dec401d3769ac3d7c894189f394a778a66106bd32460f51135caea4824360efe',
 'reward_class_v1_call_gas': '50000',
 'reward_class_v1_calldata_hash': '3717990a97396f7a0a947025434cf954d9937932f5e00fdf793c129bfbfb3006',
 'reward_class_v1_calldata_length': '36',
 'reward_class_v1_class_id': '1',
 'reward_class_v1_magic': '52435631',
 'reward_class_v1_return_hash': '3d21e30cd424ac4eb52ed85673aac8960a703cce5dd930fceb901b0ce5e93490',
 'reward_class_v1_return_length': '224',
 'reward_class_v1_selector': '3d273ee7',
 'reward_receipt_v1_calldata_hash': '2a66098a253be726163d7f52e6d14eb134b5fd3651913b5b5a21526cbcc2fefb',
 'reward_receipt_v1_calldata_length': '36',
 'reward_receipt_v1_collision_candidate_id': 'a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a4a42b',
 'reward_receipt_v1_commitment': 'e1e5ebd069f797767f88a333cdfc5e3c718a2cbba3ef6aa1ebb6192f307f2923',
 'reward_receipt_v1_magic': '52525631',
 'reward_receipt_v1_missing_return_hash': '910614e273a7326ae3c583449cfdf24c64d9ef3d7d6f448b6d3042d3ba95ae80',
 'reward_receipt_v1_present_return_hash': '23160ce91822c00eda504d61fb874db8cdfaa2a0597332d37661540eebb6b62e',
 'reward_receipt_v1_return_length': '384',
 'reward_receipt_v1_selector': '3ed526c7',
 'schedule_carrier_return_hash': '3e7028adb7b81c521979a0024999718518559b1ddec5cde8e3a9379d6cef3125',
 'schedule_carrier_statement_hash': 'e5e7ef6967d544c41242fd48103d1a53c28f1d6da31a1649d34f4bd11025e123',
 'schedule_fork_carrier_magic': '53464331',
 'schedule_fork_constants_hash': 'c17afdd5367849af551b3a2f322a2c351321e916ad913a78b646586fe34f59fc',
 'schedule_fork_output_schema_hash': '623a145841922b79691d33358ec5233f02cf68a4176d9e7c2cfafaeb357fa63a',
 'schedule_fork_route_state_hash': '4ada318df9f5ffeb65fa6a0ce68aa2b019746320323628be080fc142dbe255e9',
 'schedule_fork_route_state_magic': '46525331',
 'schedule_fork_route_state_return_hash': 'f4433ec078e97ab1615b273d74599b14f3458581e83e7d4dbb1f77dfc65d891e',
 'schedule_fork_route_state_return_length': '160',
 'schedule_fork_route_state_selector': '7e9f3c0d',
 'schedule_fork_verifier_config_magic': '53465631',
 'schedule_fork_verifier_config_return_hash': 'd71c98eddf7e49dfebf8278d29f45aa24a115e507fb309965fcaf8f523409dba',
 'schedule_fork_verifier_config_selector': '44efa773',
 'schedule_fork_verifier_configuration_hash': '9256c85ac8b81181ff7538f757939218a42c945cb7228ed5755d10f5e4ef643d',
 'schedule_list': '7ab789362dd8b411e1bc42af1270bcb14d2a7571fc28ab614c6afcc33b7de8e7',
 'seat_authority_read_gas': '100000',
 'seat_market_duty_selector': '9a649489',
 'seat_market_term_selector': '76d5ecd4',
 'seat_target_state_selector': 'cf52185b',
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
 'settlement_forced_ingress_floor_call_gas': '50000',
 'settlement_forced_ingress_floor_magic': '53494631',
 'settlement_forced_ingress_floor_normal_return_hash': '4bfd11163f0bfe60df7c73b3e4e72749e76d7419593668cac1443ea28b0b09b5',
 'settlement_forced_ingress_floor_recovery_return_hash': 'f4d8a492be93a1541f573cae536d3d4811b6251de4ee66c43887342d6597d05f',
 'settlement_forced_ingress_floor_return_length': '64',
 'settlement_forced_ingress_floor_selector': 'fe2a2914',
 'split_latest_fork_verifier_calldata_hash': '793eb33ab7e71b38a63b6b04704dbdc816de18915df79b09af7d75c4e812b41b',
 'split_latest_fork_verifier_calldata_length': '516',
 'split_latest_fork_verifier_return_hash': 'a3e070e8b9e742f15f072cb46690cf08b62bf018a99b83666455adec80e54833',
 'split_latest_fork_verifier_return_length': '160',
 'split_latest_fork_verifier_selector': '455b4ff5',
 'statement_hash': '39c621a869a95ddaf350d45f0c67094a57ac24d7b36a9bd1f57a75d5310dce2b',
 'statement_reward_execution_gas': '12345678',
 'statement_reward_published_bytes': '9',
 'tranche_leaf': '80fce6c2421807d961f9207d30b439bd423c05e206a18021b93217513ecc5551',
 'tranche_proof_digest': '8d56574545d36cb4cbb7f1452055275a3dbd8e5b2aa9062e717095f387a0a2d8',
 'tranche_root': '12ce6da6104ea0fb21edbc0e932f7500fabf18173911a48bc5e1d4d2af1cc336',
 'typehash': 'ee6a8c8e31e8245cd527869508f6e464d6084893991203876f734d1855aed87c',
 'verify_schedule_carrier_calldata_hash': 'a6f4b2260cd81afd71756624c295b886d29e85c0c9e9b1cdc89f0148bbd0fb79',
 'verify_schedule_carrier_calldata_length': '132',
 'verify_schedule_carrier_selector': '7e981e0b',
 'winning_data': '8e96cd4712fddeabda80eaa349916e5b2cbf10ccf0df0edcb7c5a2ffd52652fc'}

# The export schema is deliberately keyed by semantic meaning, never inferred
# from the spelling of a value.  Every name not in this explicit uint set is a
# hex record only after the complete canonical name-set fingerprint matches.
UINT_VECTOR_NAMES = frozenset({
    "builder_active_equivocation_witness_length",
    "builder_active_tranche_release_witness_length",
    "builder_claim_credit_calldata_length",
    "builder_claim_credit_return_length",
    "builder_equivocation_calldata_length",
    "builder_equivocation_return_length",
    "builder_expire_schedule_calldata_length",
    "builder_expire_schedule_return_length",
    "builder_generation_release_witness_length",
    "builder_liability_equivocation_witness_length",
    "builder_liability_tranche_release_witness_length",
    "builder_maintenance_calldata_length",
    "builder_maintenance_return_length",
    "builder_maintenance_witness_length",
    "builder_movement_witness_length",
    "builder_normalize_calldata_length",
    "builder_normalize_noop_witness_length",
    "builder_normalize_return_length",
    "builder_normalize_witness_length",
    "builder_proof_admission_request_length",
    "builder_proof_evidence_request_length",
    "builder_proof_identity_calldata_length",
    "builder_proof_identity_return_length",
    "builder_proof_registry_request_length",
    "builder_proof_tranche_request_length",
    "builder_register_calldata_length",
    "builder_register_return_length",
    "builder_release_generation_calldata_length",
    "builder_release_generation_return_length",
    "builder_release_tranche_calldata_length",
    "builder_release_tranche_return_length",
    "builder_request_exit_calldata_length",
    "builder_request_exit_return_length",
    "builder_reserve_calldata_length",
    "builder_reserve_return_length",
    "builder_reserve_witness_length",
    "builder_vacancy_registration_witness_length",
    "candidate_committed_v2_data_length",
    "candidate_committed_v2_topic_count",
    "claim_reward_v1_calldata_length",
    "claim_reward_v1_paid_wei",
    "claim_reward_v1_return_length",
    "component_config_getter_gas_limit",
    "data_mmr_proof_count",
    "data_mmr_proof_index",
    "data_session_accounting_return_length",
    "enqueue_forced_transaction_calldata_length",
    "forced_queue_config_return_length",
    "forced_queue_state_return_length",
    "fund_reward_class_v1_calldata_length",
    "fund_reward_class_v1_return_length",
    "kind0_forced_admission_length",
    "replace_pending_fork_verifier_calldata_length",
    "replace_pending_fork_verifier_return_length",
    "reward_claimed_v1_data_length",
    "reward_claimed_v1_topic_count",
    "reward_class_funded_v1_data_length",
    "reward_class_funded_v1_topic_count",
    "reward_class_v1_call_gas",
    "reward_class_v1_calldata_length",
    "reward_class_v1_class_id",
    "reward_class_v1_return_length",
    "reward_receipt_v1_calldata_length",
    "reward_receipt_v1_return_length",
    "schedule_fork_route_state_return_length",
    "seat_authority_read_gas",
    "settlement_forced_ingress_floor_call_gas",
    "settlement_forced_ingress_floor_return_length",
    "split_latest_fork_verifier_calldata_length",
    "split_latest_fork_verifier_return_length",
    "statement_reward_execution_gas",
    "statement_reward_published_bytes",
    "verify_schedule_carrier_calldata_length",
})
GOLDEN_VECTOR_COUNT = 323
VECTOR_NAME_SCHEMA_SHA256 = (
    "c511676c95f722207258c19d0410c971db099c6d23eecf52b30cb1027373f664"
)


def typed_vectors() -> tuple[dict[str, str], ...]:
    """Return the canonical vectors as deterministic, explicitly typed rows."""

    if not __debug__:
        raise RuntimeError("typed vector export requires assertions")
    actual = vectors()
    assert actual == EXPECTED
    names = tuple(sorted(actual))
    assert (len(names) == GOLDEN_VECTOR_COUNT and len(set(names)) == len(names)
            and UINT_VECTOR_NAMES <= set(names)
            and hashlib.sha256(
                b"\0".join(name.encode("ascii") for name in names)
            ).hexdigest() == VECTOR_NAME_SCHEMA_SHA256)
    records: list[dict[str, str]] = []
    for name in names:
        value = actual[name]
        if name in UINT_VECTOR_NAMES:
            kind = "uint"
            assert (value != "" and all("0" <= char <= "9" for char in value)
                    and (value == "0" or value[0] != "0")
                    and str(int(value)) == value)
        else:
            kind = "hex"
            assert (value != "" and len(value) % 2 == 0
                    and all(char in "0123456789abcdef" for char in value)
                    and bytes.fromhex(value).hex() == value)
        records.append({"kind": kind, "name": name, "value": value})
    assert len(records) == len(actual)
    return tuple(records)


def typed_vectors_json() -> str:
    """Return compact JSON with stable row and object-key ordering."""

    return json.dumps(typed_vectors(), sort_keys=True, separators=(",", ":"))

if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("commitment model refuses optimized Python")
    if sys.argv[1:]:
        if sys.argv[1:] != ["--export-json"]:
            raise SystemExit("usage: commitment-model.py [--export-json]")
        print(typed_vectors_json())
        raise SystemExit(0)
    actual = vectors()
    if "UPDATE" in EXPECTED.values():
        for key, value in actual.items():
            print(f'    "{key}": "{value}",')
        raise SystemExit("populate EXPECTED with the vectors above")
    if actual != EXPECTED:
        drift = {
            key: (EXPECTED.get(key), actual.get(key))
            for key in sorted(set(actual) | set(EXPECTED))
            if EXPECTED.get(key) != actual.get(key)
        }
        raise AssertionError(f"golden drift: {drift}")
    payload = b"alpha" * 100
    blob = encode_blob_payload(payload)
    assert decode_blob_payload(blob) == payload

    # Normative constructor boundaries reject before emitting a commitment.
    hash_a, hash_b = bytes.fromhex("11" * 32), bytes.fromhex("22" * 32)
    candidate_row = (1, hash_a, hash_b, hash_a, hash_b, 0)
    assert_rejects(
        lambda: candidate_commitment(hash_a, ()),
        "empty candidate accepted")
    assert_rejects(
        lambda: candidate_commitment(hash_a, (candidate_row,) * 4_097),
        "candidate block cap exceeded")
    assert_rejects(
        lambda: candidate_commitment(hash_a, (candidate_row, candidate_row)),
        "duplicate candidate slot accepted")
    assert_rejects(
        lambda: candidate_commitment(
            hash_a, ((2, *candidate_row[1:]), candidate_row)),
        "descending candidate slots accepted")
    assert_rejects(
        lambda: candidate_commitment(
            hash_a, ((-1, *candidate_row[1:]),)),
        "negative candidate slot accepted")
    assert_rejects(
        lambda: candidate_commitment(
            hash_a, ((UINT64_MAX + 1, *candidate_row[1:]),)),
        "candidate slot beyond uint64 accepted")

    schedule_row = (1, hash_a, hash_b)
    assert_rejects(
        lambda: schedule_list(tuple(
            (window, hash_a, hash_b) for window in range(13))),
        "schedule window cap exceeded")
    assert_rejects(
        lambda: schedule_list((schedule_row, schedule_row)),
        "duplicate schedule window accepted")
    assert_rejects(
        lambda: schedule_list(((2, hash_a, hash_b), schedule_row)),
        "descending schedule windows accepted")
    assert_rejects(
        lambda: schedule_list(((-1, hash_a, hash_b),)),
        "negative schedule window accepted")
    assert_rejects(
        lambda: schedule_list(((UINT64_MAX + 1, hash_a, hash_b),)),
        "schedule window beyond uint64 accepted")

    session_row = (bytes.fromhex("01" * 32), 0, hash_a)
    assert_rejects(
        lambda: session_list(tuple(
            (index.to_bytes(32, "big"), 0, hash_a)
            for index in range(1, 18))),
        "sealed-session cap exceeded")
    assert_rejects(
        lambda: session_list((session_row, session_row)),
        "duplicate sealed session accepted")
    assert_rejects(
        lambda: session_list((
            (bytes.fromhex("02" * 32), 0, hash_a), session_row)),
        "descending sealed sessions accepted")
    assert_rejects(
        lambda: session_list(((session_row[0], -1, session_row[2]),)),
        "negative session record count accepted")
    assert_rejects(
        lambda: session_list(((session_row[0], 2_101, session_row[2]),)),
        "session record cap exceeded")
    assert_rejects(
        lambda: mmr_root((hash_a,) * 2_101),
        "MMR record cap exceeded")

    manifest_entry = ManifestEntry(0, hash_a, 0, 0, 1, 0,
                                   hash_a, hash_b)
    assert_rejects(
        lambda: manifest_root(0, (manifest_entry,) * 2_101),
        "manifest record cap exceeded")
    assert_rejects(
        lambda: manifest_root(1, (manifest_entry,)),
        "cross-block manifest entry accepted")
    assert_rejects(
        lambda: manifest_root(-1, ()),
        "negative manifest block ordinal accepted")
    assert_rejects(
        lambda: manifest_root(4_096, ()),
        "manifest block ordinal beyond candidate cap accepted")
    assert len(manifest_root(4_095, ())) == 32

    # Negative queue properties: skip, reorder, boundary/count/root tampering.
    envs = tuple(ForcedEnvelope(1, i, 16_788, keccak256(u64(i)), 10, 21_000,
                                21_000, 1, 9_999, 2, 3, 4 + i, 5)
                 for i in range(70))
    kind0_descriptor = forced_descriptor(envs[0])
    maximum_consumed = ((0, kind0_descriptor),) * 256
    assert (len(force_descriptor_list(
        0, maximum_consumed, (0, kind0_descriptor))) == 32
        and len(force_descriptor_list(UINT64_MAX, (), None)) == 32)
    assert len(force_descriptor_list(
        UINT64_MAX - 1, ((0, kind0_descriptor),), None)) == 32
    assert len(force_descriptor_list(
        UINT64_MAX - 2, ((0, kind0_descriptor),),
        (0, kind0_descriptor))) == 32
    assert_rejects(
        lambda: force_descriptor_list(
            0, maximum_consumed + ((0, kind0_descriptor),), None),
        "forced consumed-item cap exceeded")
    assert_rejects(
        lambda: force_descriptor_list(
            0, maximum_consumed + ((0, kind0_descriptor),),
            (0, kind0_descriptor)),
        "forced total descriptor cap exceeded")
    for invalid_kind in (-1, 1, 2, True):
        assert_rejects(
            lambda invalid_kind=invalid_kind: force_descriptor_list(
                0, ((invalid_kind, kind0_descriptor),), None),
            "invalid forced descriptor kind accepted")
    for invalid_kind0 in (bytes(219), bytes(221), bytes(541)):
        assert_rejects(
            lambda invalid_kind0=invalid_kind0: force_descriptor_list(
                0, ((0, invalid_kind0),), None),
            "invalid kind-0 descriptor length accepted")
    assert_rejects(
        lambda: force_descriptor_list(-1, (), None),
        "negative forced descriptor start accepted")
    assert_rejects(
        lambda: force_descriptor_list(UINT64_MAX + 1, (), None),
        "forced descriptor start beyond uint64 accepted")
    assert_rejects(
        lambda: force_descriptor_list(
            UINT64_MAX, ((0, kind0_descriptor),), None),
        "unused final forced descriptor index accepted")
    assert_rejects(
        lambda: force_descriptor_list(
            UINT64_MAX - 1, ((0, kind0_descriptor),),
            (0, kind0_descriptor)),
        "forced descriptor boundary index overflow accepted")
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

    queue_config = forced_queue_config_hash(0xAD01, 0xB001)
    assert queue_config.hex() == actual["forced_queue_config_hash"]
    assert forced_queue_config_hash(0xAD02, 0xB001) != queue_config
    assert forced_queue_config_hash(0xAD01, 0xB002) != queue_config
    assert FORCED_QUEUE_CONFIG_SELECTOR == bytes.fromhex("8136fe31")
    assert FORCED_QUEUE_STATE_SELECTOR == bytes.fromhex("03e0d70b")
    assert FORCED_QUEUE_FRONTIER_SELECTOR == bytes.fromhex("7c339ff7")
    assert FORCED_QUEUE_DESCRIPTOR_SELECTOR == bytes.fromhex("bd9534db")
    assert FORCED_QUEUE_DUE_AT_SELECTOR == bytes.fromhex("530fd138")
    assert FORCED_QUEUE_ADVANCE_SELECTOR == bytes.fromhex("d59ff200")
    assert FORCED_QUEUE_WITHDRAW_SELECTOR == bytes.fromhex("c28aa0e8")

    assertion_sites = sum(
        isinstance(node, ast.Assert)
        for node in ast.walk(ast.parse(Path(__file__).read_text())))

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
