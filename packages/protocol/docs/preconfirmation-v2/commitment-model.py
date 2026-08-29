#!/usr/bin/env python3
"""Golden vectors for Slot-Chain v2.16 consensus commitments.

This fixture covers the commitments that cross Solidity, clients and circuits:
EIP-712 domain/struct/digest, canonical/base identity, ABI statement hashing,
registry/admission/entry/tranche trees, the depth-32 forced vector and canonical
range proof, session MMR, data chunks/manifests, dispositions, recovery ID and
blob framing. It intentionally does not pretend that zero KZG bytes are a valid
opening; a valid c-kzg vector remains a production conformance gate.

The executionProfileHash values below are test fixtures, not the missing
initial executable profile or evidence that its bytecode/verifier bindings
exist. Section 13 of the design records that blocker explicitly.
"""

from __future__ import annotations

import runpy
from dataclasses import dataclass, replace
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
FORCE_DEPTH = 32
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
D_FORCE_BRIDGE = b"slot-chain-force-bridge-v9"
D_FORCE_DESCRIPTOR_LIST = b"slot-chain-force-descriptor-list-v2"
D_FORCE_EMPTY = b"slot-chain-force-empty-v2"
D_FORCE_NODE = b"slot-chain-force-node-v2"
D_FORCE_ROOT = b"slot-chain-force-root-v2"
D_MMR_LEAF = b"slot-chain-data-leaf-v1"
D_MMR_NODE = b"slot-chain-data-node-v1"
D_MMR_BAG = b"slot-chain-data-bag-v1"
D_MANIFEST_EMPTY = b"slot-chain-manifest-empty-v1"
D_MANIFEST_LEAF = b"slot-chain-manifest-leaf-v1"
D_MANIFEST_NODE = b"slot-chain-manifest-node-v1"
D_MANIFEST_ROOT = b"slot-chain-manifest-root-v1"
D_DISPOSITIONS = b"slot-chain-dispositions-v1"
D_BRIDGE_RESULT = b"slot-chain-bridge-credit-result-v8"
D_BRIDGE_CREDIT_ID = b"slot-chain-bridge-credit-id-v5"
D_BRIDGE_ESCROW = b"slot-chain-bridge-escrow-v1"
D_INBOX_CREDIT_SLOT = b"slot-chain-inbox-credit-slot-v4"
D_TERMINAL_EMPTY = b"slot-chain-terminal-empty-v1"
D_TERMINAL_LEAF = b"slot-chain-terminal-leaf-v1"
D_TERMINAL_NODE = b"slot-chain-terminal-node-v1"
D_TERMINAL_ROOT = b"slot-chain-terminal-root-v1"
D_SOURCE_DOMAIN = b"slot-chain-source-domain-v4"
D_DESTINATION_DOMAIN = b"slot-chain-destination-domain-v4"
D_BRIDGE_EXECUTION = b"slot-chain-frozen-bridge-execution-v2"
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
    calldata_hash: bytes
    refund_vault: int
    refund_capsule_hash: bytes
    escrow_id: bytes
    byte_length: int
    accounted_gas: int
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


def bridge_descriptor(envelope: BridgeEnvelope) -> bytes:
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
        + u64(envelope.fee) + b32(envelope.calldata_hash)
        + address20(envelope.refund_vault) + b32(envelope.refund_capsule_hash)
        + b32(envelope.escrow_id) + u32(envelope.byte_length)
        + u64(envelope.accounted_gas) + address20(envelope.refund)
        + u64(envelope.enqueued_at) + u64(envelope.due_at)
        + u256(envelope.deposit)
    )


def forced_leaf(index: int, envelope: ForcedEnvelope) -> bytes:
    descriptor = forced_descriptor(envelope)
    assert len(descriptor) == 220
    return keccak256(D_FORCE_USER + u32(index) + descriptor)


def bridge_leaf(index: int, envelope: BridgeEnvelope) -> bytes:
    descriptor = bridge_descriptor(envelope)
    assert len(descriptor) == 532
    return keccak256(D_FORCE_BRIDGE + u32(index) + descriptor)


@dataclass(frozen=True)
class FrozenBridgeDescriptor:
    bridge: int
    credit_registry: int
    terminal_verifier: int
    facade_runtime_hash: bytes
    storage_layout_hash: bytes
    profile_hash: bytes


def canonical_frozen_bridge_descriptor(descriptor: FrozenBridgeDescriptor) -> bytes:
    assert (descriptor.bridge != 0 and descriptor.credit_registry != 0
            and descriptor.terminal_verifier != 0
            and descriptor.facade_runtime_hash != bytes(32)
            and descriptor.storage_layout_hash != bytes(32)
            and descriptor.profile_hash != bytes(32))
    return (address20(descriptor.bridge) + address20(descriptor.credit_registry)
            + address20(descriptor.terminal_verifier)
            + b32(descriptor.facade_runtime_hash)
            + b32(descriptor.storage_layout_hash) + b32(descriptor.profile_hash))


def bridge_execution_hash(descriptor: FrozenBridgeDescriptor) -> bytes:
    encoded = canonical_frozen_bridge_descriptor(descriptor)
    return keccak256(D_BRIDGE_EXECUTION + u32(len(encoded)) + encoded)


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
                          checkpoint_store: int, terminal_verifier: int,
                          inbox_apply: int, inbox_credit_store: int,
                          terminal_accumulator: int, bridge: int,
                          bridge_execution_hash: bytes,
                          infrastructure_hash: bytes,
                          namespace: bytes) -> bytes:
    assert (genesis_hash != bytes(32) and namespace != bytes(32)
            and bridge_execution_hash != bytes(32)
            and infrastructure_hash != bytes(32)
            and bridge_inbox_adapter != 0
            and active_settlement_router != 0
            and checkpoint_store != 0 and terminal_verifier != 0
            and inbox_apply != 0 and inbox_credit_store != 0
            and terminal_accumulator != 0 and bridge != 0)
    return keccak256(D_DESTINATION_DOMAIN + u64(dest_chain_id)
                     + b32(genesis_hash)
                     + address20(bridge_inbox_adapter)
                     + address20(active_settlement_router)
                     + address20(checkpoint_store)
                     + address20(terminal_verifier)
                     + address20(inbox_apply)
                     + address20(inbox_credit_store)
                     + address20(terminal_accumulator)
                     + address20(bridge)
                     + b32(bridge_execution_hash)
                     + b32(infrastructure_hash)
                     + b32(namespace))


def force_descriptor_list(start: int,
                          consumed: tuple[tuple[int, bytes], ...],
                          boundary: tuple[int, bytes] | None) -> bytes:
    rows = consumed + (() if boundary is None else (boundary,))
    payload = b"".join(
        u32(start + offset) + u8(kind) + u16(len(descriptor)) + descriptor
        for offset, (kind, descriptor) in enumerate(rows)
    )
    return keccak256(D_FORCE_DESCRIPTOR_LIST + u64(start) + u16(len(consumed))
                     + u8(boundary is not None) + payload)


FORCE_EMPTY: list[bytes] = [keccak256(D_FORCE_EMPTY)]
for _height in range(FORCE_DEPTH):
    FORCE_EMPTY.append(keccak256(D_FORCE_NODE + u8(_height)
                                 + FORCE_EMPTY[-1] + FORCE_EMPTY[-1]))


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
    assert 0 <= old_count < UINT32_MAX
    for height in range(FORCE_DEPTH):
        if not (old_count >> height) & 1:
            return height
    raise AssertionError("unreachable below UINT32_MAX")


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
            envelope.msg_hash)
        + b32(envelope.msg_hash)
        + u256(envelope.src_chain_id) + b32(envelope.source_domain_id)
        + u64(envelope.src_epoch)
        + address20(envelope.src_bridge)
        + b32(envelope.bridge_execution_hash) + u64(envelope.emitted_at_block)
        + b32(envelope.destination_domain_id) + u256(envelope.dest_chain_id)
        + u64(envelope.enqueue_by)
        + address20(envelope.sender) + address20(envelope.src_owner)
        + address20(envelope.dest_owner) + u256(envelope.value)
        + u64(envelope.fee) + b32(envelope.calldata_hash)
        + address20(envelope.refund_vault) + b32(envelope.refund_capsule_hash)
        + b32(envelope.escrow_id)
    )


def bridge_credit_id(src_chain_id: int, source_domain_id_: bytes, src_epoch: int,
                     src_bridge: int, destination_domain_id_: bytes,
                     msg_hash: bytes) -> bytes:
    return keccak256(D_BRIDGE_CREDIT_ID + u64(src_chain_id)
                     + b32(source_domain_id_) + u64(src_epoch)
                     + address20(src_bridge) + b32(destination_domain_id_)
                     + b32(msg_hash))


def inbox_credit_slot(source_domain_id_: bytes, src_bridge: int,
                      destination_domain_id_: bytes, credit_id: bytes) -> bytes:
    return keccak256(D_INBOX_CREDIT_SLOT + b32(source_domain_id_)
                     + address20(src_bridge) + b32(destination_domain_id_)
                     + b32(credit_id))


def terminal_leaf(index: int, destination_domain_id_: bytes,
                  destination_bridge: int, credit_id: bytes,
                  terminal: int) -> bytes:
    assert terminal in (1, 2)
    return keccak256(D_TERMINAL_LEAF + u64(index)
                     + b32(destination_domain_id_)
                     + address20(destination_bridge) + b32(credit_id)
                     + u8(terminal))


TERMINAL_EMPTY: list[bytes] = [keccak256(D_TERMINAL_EMPTY)]
for _height in range(TERMINAL_DEPTH):
    TERMINAL_EMPTY.append(keccak256(D_TERMINAL_NODE + u8(_height)
                                    + TERMINAL_EMPTY[-1]
                                    + TERMINAL_EMPTY[-1]))


class TerminalVector:
    def __init__(self, leaves: tuple[bytes, ...]):
        assert len(leaves) < UINT64_MAX
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


def verify_terminal_proof(count: int, index: int, leaf: bytes,
                          proof: tuple[bytes, ...], expected_root: bytes) -> bool:
    if not (0 <= index < count < UINT64_MAX) or len(proof) != TERMINAL_DEPTH:
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
                     msg_hash: bytes, result_hash: bytes) -> bool:
    if src_bridge == 0 or msg_hash == bytes(32) or result_hash == bytes(32):
        return False
    credit_id = bridge_credit_id(
        src_chain_id, source_domain_id_, src_epoch, src_bridge,
        destination_domain_id_, msg_hash)
    key = inbox_credit_slot(
        source_domain_id_, src_bridge, destination_domain_id_, credit_id)
    existing = store.get(key)
    if existing is None:
        store[key] = result_hash
        return True
    return existing == result_hash


def pin_inbox_credit_batch(
    store: dict[bytes, bytes],
    rows: tuple[tuple[int, int, bytes, int, int, bytes, bytes, bytes], ...],
) -> bool:
    if len(rows) > 64:
        return False
    indices = tuple(row[0] for row in rows)
    if indices != tuple(sorted(indices)) or len(set(indices)) != len(indices):
        return False
    staged = dict(store)
    seen: set[bytes] = set()
    for (_, src_chain_id, source_domain_id_, src_epoch, src_bridge,
         destination_domain_id_, msg_hash, result) in rows:
        credit_id = bridge_credit_id(
            src_chain_id, source_domain_id_, src_epoch, src_bridge,
            destination_domain_id_, msg_hash)
        if credit_id in seen or not pin_inbox_credit(
                staged, src_chain_id, source_domain_id_, src_epoch, src_bridge,
                destination_domain_id_, msg_hash, result):
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
    sid = session_id(settlement_chain_id, contract, 0xCAFE, 2)
    body = body_root((bytes.fromhex("0102"), bytes.fromhex("030405")))
    chunk0, chunk1 = b"alpha", b"beta"
    c0, c1 = chunk_root(body, 0, 0, 2, chunk0), chunk_root(body, 0, 1, 2, chunk1)
    leaf0 = data_leaf(sid, 0, bytes.fromhex("33" * 32), body, 0, 0, 2,
                      chunk0, 0xCAFE, 9_999, 5, 6)
    leaf1 = data_leaf(sid, 1, bytes.fromhex("55" * 32), body, 0, 1, 2,
                      chunk1, 0xCAFE, 9_999, 7, 8)
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
        settlement_chain_id, l2_chain_id, 2, bytes.fromhex("fe" * 32), contract, 1, base,
        candidate_hash, 1, 8_001, bytes.fromhex("88" * 32), 8_001, 8_001,
        bytes.fromhex("66" * 32), empty_terminal.root, 0, 66,
        winning, envs[66].due_at,
        101, 0, 1_000, bytes.fromhex("99" * 32), bytes.fromhex("aa" * 32), 999,
        force.root, len(envs), forced_descriptors, 2, 12, adm_root,
        0, 0, bytes(32), schedules_hash, 1,
        sessions_hash, 1, 2, outputs_hash, 0xCAFE,
    )
    frozen_bridge_descriptor = FrozenBridgeDescriptor(
        0xB123, 0xD001, 0xD003, bytes.fromhex("32" * 32),
        bytes.fromhex("33" * 32), bytes.fromhex("34" * 32))
    bridge_execution = bridge_execution_hash(frozen_bridge_descriptor)
    source_domain = source_domain_id(
        1, bytes.fromhex("25" * 32), 0xD001, 0xD003, 0xB123,
        bridge_execution, bytes.fromhex("26" * 32))
    destination_domain = destination_domain_id(
        l2_chain_id, bytes.fromhex("35" * 32), 0xAD00, 0xAD01,
        0xD100, 0xD101, 0x5100, 0x5101, 0x5102, 0xB200,
        bytes.fromhex("37" * 32), bytes.fromhex("38" * 32),
        bytes.fromhex("36" * 32))
    bridge_msg_hash = bytes.fromhex("21" * 32)
    bridge_credit = bridge_credit_id(
        1, source_domain, 7, 0xB123, destination_domain, bridge_msg_hash)
    bridge = BridgeEnvelope(
        bridge_msg_hash, 1, source_domain, 7, 0xB123, bridge_execution,
        12_300, destination_domain, l2_chain_id, 800_000,
        0x3333, 0x1111, 0x2222, 10**18, 1_234,
        bytes.fromhex("22" * 32), 0x4444, bytes.fromhex("23" * 32),
        bridge_escrow_id(bridge_credit), 96, 120_000,
        0xBEEF, 700, 2_200, 10**16,
    )
    bridge_hash = bridge_leaf(70, bridge)
    done_leaf = terminal_leaf(0, destination_domain, 0xB200, bridge_credit, 1)
    failed_leaf = terminal_leaf(1, destination_domain, 0xB200,
                                bytes.fromhex("24" * 32), 2)
    terminal_vector = TerminalVector((done_leaf, failed_leaf))
    empty_body = body_root(())
    empty_manifest = manifest_root(())
    empty_sessions = session_list(())
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
        "bridge_escrow_id": bridge_escrow_id(bridge_credit).hex(),
        "inbox_credit_slot": inbox_credit_slot(
            bridge.source_domain_id, bridge.src_bridge,
            bridge.destination_domain_id, bridge_credit).hex(),
        "terminal_done_leaf": done_leaf.hex(),
        "terminal_failed_leaf": failed_leaf.hex(),
        "terminal_root_2": terminal_vector.root.hex(),
        "empty_terminal_root": empty_terminal.root.hex(),
        "source_domain_id": source_domain.hex(),
        "destination_domain_id": destination_domain.hex(),
        "bridge_execution_hash": bridge_execution.hex(),
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
    "block_struct_hash": "51e1c13fa12530ad6a43ce5a9cb5d66d1656b4416c6ddb9734fd3a4acb5abce3",
    "eip712_digest": "cb59aa5955c50b9b02a12d18f95ad60f9df29928fc734d34dff63f45b933316e",
    "canonical_core": "20525f9b18a79b1db160ee06cd37198770e623b95aec0a597c6c76f5561c6b3f",
    "base_canonical": "19a015f3c2d65fe1dee2903d7a9afb82aa658e23d98265baad5ab278c8e35569",
    "migration_data": "a3588b50c1f4e768cb2c35a622452527ab3cb953520ef018af3ff2d2362b86a5",
    "candidate_commitment": "6c9ea7e1f8982c06c0586605902111d1e5ff4892643d92c62b23aff2017c7c35",
    "candidate_commitment_2": "154a2bf68205ffeaf92419b663352a12c033204f5a17a1f8793832dd572b4f1e",
    "normal_context": "bdec611a765250c0e964b4e3c95c648fec0c126a0f2c8f8fc3c13f691ede455b",
    "winning_data": "9b7418cffd7b88f9f3d3799fb287cd47dee2e34edb1d41590dbdd12f0859a34d",
    "forced_descriptors": "193cc93014b8472b5f951472c3b8a9d60ebfd294ff18e43c21d60af6e0853de3",
    "schedule_list": "7ab789362dd8b411e1bc42af1270bcb14d2a7571fc28ab614c6afcc33b7de8e7",
    "session_list": "9cbf4ca60afc8aee2ccaa68a45bb6568a04812cf282aa703f194e017092fb264",
    "execution_outputs": "585d5b4b9f931a3d89641ea4467eabaf5f87bc765a3ced91f9418c4db2b8f83a",
    "statement_hash": "17c45efbdb95e3511eb9e96d054fb3d1a4b4dec3b7aee5c499741b44863de0b6",
    "registry_root": "0bf297d7b9b6a5529a319a06cb08484923a89bab15d51f8baeaf5c30bebdf3fd",
    "admission_root": "3bf2dcaf78292c832108e29205bf99cc2d22137a0545e4528d8da7309d4b482b",
    "admission_reuse_root": "a1e22890dd835872055e53dcad82d9e12759a2920853fe6e9f735d7f2c87ceca",
    "entry_root": "acee83a690b868a4a7960c55a9f7228f91cad26b704e24106d4db87e9c7a8f34",
    "tranche_leaf": "80fce6c2421807d961f9207d30b439bd423c05e206a18021b93217513ecc5551",
    "forced_leaf": "d87daf7664bb204e89adb2cc983b182cfb0a084603d99d6e6c64496d14988837",
    "bridge_leaf": "76f3734736ada9d27506b799aec3ab548e18a7a6e7ec0d2d1476a4bda228d188",
    "bridge_result": "3716bbf7e3c2dd592f22451c41d64407341560282c3f40d0e20e8a3c82a7e2d6",
    "bridge_credit_id": "8090aea1a82caa2a6d6bbf37ab465f65baa5830885fe567e5793535ff0812552",
    "bridge_escrow_id": "0326050d230e0f94596ba258c32106677acfc766bc3b42d29b90571238dd6a19",
    "inbox_credit_slot": "065914265b8f183cf218df07e7452ee23585a8178ee7f22412e60ef7d2194a64",
    "terminal_done_leaf": "96cbf4e57bbf9c8eb2903744d39ed9628c9884d703f85d1124aea5a3d5a98098",
    "terminal_failed_leaf": "5166704c6342bbc2b35952f9ead59ae93c7b6dc0595ff2906d9eb28f9860e5de",
    "terminal_root_2": "1147f52c8931156dddef7b4a9b387f949563525a96a2c02d9b833c710a0574b6",
    "empty_terminal_root": "0a0a8606a440497456ab8cac6894ff589cd7a6464809113ea62b7affe1429cc2",
    "source_domain_id": "c95f5c31ea09c4bf997614e9bc345b0826eeb4daf56d6ae27716542117606ced",
    "destination_domain_id": "0748c195cb659279624bd51e9726cb484525894c945060d3677a88df96312700",
    "bridge_execution_hash": "8da04c9a8990e7ec330e832792299c52ceabc120f16ed9cf60664d53e047dd21",
    "forced_root": "ab03f105ee7d619fb2c81d31b38760720dff2cb35471bc28fdc063c31f71bd67",
    "empty_forced_root": "646c80c24e65a38013e25e1387d2a26166d33ca1ab34878b272fef83f41cd72e",
    "force_range_digest": "3c3e3735e00bee4aad3451ce63a8b5fbb7c821444defe7064c78af9de56cca64",
    "session_id": "98cbb8b158cb6732a806e2fac0e50c53e88feafd5e3dade0a0ed7edeb7a5a0b1",
    "mmr_root_2": "d20459aeb2fe916a18dd584d39b2ae25075c6b6c14104d9d64a8b1d7882eb4df",
    "manifest_root": "417be737a57e38eb410f2d6e65c77ee19d5c314cdaf432067861c6a36c6a990f",
    "manifest_root_block_1": "c58ab29bdccb3e06cc5431fbbcea1abc6d6f1a38120c5d896e18b7f1ca1cf43e",
    "empty_body_root": "f0e00da8dbc00feb028a8bc92342c0771372b947acf5989b2d4a5f23bb2f459a",
    "empty_manifest_root": "0bb15f38645cecc1748b17fe3bd966ba8016c169ebd1266fd38150766177b5f6",
    "empty_session_list": "8827f09b5799bab18f29ea5b9cb9cbb5a88ddb96bc4b3ffc4d69cbcbdfe50279",
    "dispositions": "ab253c1204a53b6e095a887dfa6acfc8e8c0c6f89badcef5f73fee716fa94b93",
    "recovery_id": "b710e3a0629fa9ba438e5661ece58060cf547a0444d8b59b266fd500a4020c3a",
    "body_root": "0f4e161a46c8b18c2a86f23a0a4e7169a838a12af8b389f65e97b547a99707e9",
    "chunk_root_0": "e652cb05b1f44f3c09c650870b7b9ade4132548bd0c769bdda35b5bfcac5139e",
}


if __name__ == "__main__":
    actual = vectors()
    if "UPDATE" in EXPECTED.values():
        for key, value in actual.items():
            print(f'    "{key}": "{value}",')
        raise SystemExit("populate EXPECTED with the vectors above")
    assert actual == EXPECTED
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
    assert len(proof) <= 129
    assert verify_force_range(70, 2, revealed, proof, vector.root)
    assert not verify_force_range(70, 2, revealed[1:], proof, vector.root)
    assert not verify_force_range(70, 2, (revealed[1], revealed[0], *revealed[2:]), proof, vector.root)
    assert not verify_force_range(69, 2, revealed, proof, vector.root)
    assert not verify_force_range(70, 2, revealed, proof + (bytes(32),), vector.root)
    assert append_frontier_height(UINT32_MAX - 1) == 0
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
    domain_r1 = source_domain_id(
        1, bytes.fromhex("25" * 32), 0xD001, 0xD003, 0xB123,
        execution_hash, bytes.fromhex("26" * 32))
    destination_domain = destination_domain_id(
        16_788, bytes.fromhex("35" * 32), 0xAD00, 0xAD01,
        0xD100, 0xD101, 0x5100, 0x5101, 0x5102, 0xB200,
        bytes.fromhex("37" * 32), bytes.fromhex("38" * 32),
        bytes.fromhex("36" * 32))
    bridge_msg_hash = bytes.fromhex("21" * 32)
    bridge_credit = bridge_credit_id(
        1, domain_r1, 7, 0xB123, destination_domain, bridge_msg_hash)
    bridge = BridgeEnvelope(
        bridge_msg_hash, 1, domain_r1, 7, 0xB123, execution_hash,
        12_300, destination_domain, 16_788, 800_000,
        0x3333, 0x1111, 0x2222, 10**18, 1_234,
        bytes.fromhex("22" * 32), 0x4444, bytes.fromhex("23" * 32),
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
                changed_destination.msg_hash)
            != bridge_credit_id(
                bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
                bridge.src_bridge, bridge.destination_domain_id,
                bridge.msg_hash))
    changed_deadline = replace(bridge, enqueue_by=bridge.enqueue_by + 1)
    assert (bridge_leaf(70, changed_deadline) != bridge_leaf(70, bridge)
            and bridge_credit_result(70, changed_deadline) != bridge_result)
    changed_emission = replace(bridge, emitted_at_block=bridge.emitted_at_block + 1)
    assert (bridge_leaf(70, changed_emission) != bridge_leaf(70, bridge)
            and bridge_credit_result(70, changed_emission) != bridge_result)
    for changed_source_field in (
        replace(bridge, sender=bridge.sender + 1),
        replace(bridge, fee=bridge.fee + 1),
        replace(bridge, refund_vault=bridge.refund_vault + 1),
        replace(bridge, refund_capsule_hash=bytes.fromhex("24" * 32)),
    ):
        assert (bridge_leaf(70, changed_source_field) != bridge_leaf(70, bridge)
                and bridge_credit_result(70, changed_source_field) != bridge_result)
    pins: dict[bytes, bytes] = {}
    assert pin_inbox_credit(pins, bridge.src_chain_id, bridge.source_domain_id,
                            bridge.src_epoch, bridge.src_bridge,
                            bridge.destination_domain_id,
                            bridge.msg_hash, bridge_result)
    assert pin_inbox_credit(pins, bridge.src_chain_id, bridge.source_domain_id,
                            bridge.src_epoch, bridge.src_bridge,
                            bridge.destination_domain_id,
                            bridge.msg_hash, bridge_result)
    rotated_result = bridge_credit_result(71, rotated)
    assert pin_inbox_credit(pins, rotated.src_chain_id, rotated.source_domain_id,
                            rotated.src_epoch, rotated.src_bridge,
                            rotated.destination_domain_id,
                            rotated.msg_hash, rotated_result)
    batch_rows = (
        (70, bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
         bridge.src_bridge, bridge.destination_domain_id,
         bridge.msg_hash, bridge_result),
        (71, rotated.src_chain_id, rotated.source_domain_id, rotated.src_epoch,
         rotated.src_bridge, rotated.destination_domain_id,
         rotated.msg_hash, rotated_result),
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
                                bytes.fromhex("44" * 32))
    bridge_credit = bridge_credit_id(
        bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
        bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash)
    assert pins[inbox_credit_slot(
        bridge.source_domain_id, bridge.src_bridge,
        bridge.destination_domain_id, bridge_credit)] == bridge_result
    reused = replace(bridge, src_epoch=9)
    reused_result = bridge_credit_result(72, reused)
    assert bridge_credit_id(reused.src_chain_id, reused.source_domain_id, reused.src_epoch,
                            reused.src_bridge, reused.destination_domain_id,
                            reused.msg_hash) != bridge_credit_id(
                                bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
                                bridge.src_bridge, bridge.destination_domain_id,
                                bridge.msg_hash)
    assert pin_inbox_credit(pins, reused.src_chain_id, reused.source_domain_id,
                            reused.src_epoch,
                            reused.src_bridge, reused.destination_domain_id,
                            reused.msg_hash, reused_result)
    domain_r2 = source_domain_id(
        1, bytes.fromhex("25" * 32), 0xD004, 0xD003, 0xB123,
        execution_hash, bytes.fromhex("27" * 32))
    replacement_registry = replace(
        bridge, source_domain_id=domain_r2, src_epoch=7, src_bridge=0xB123)
    replacement_result = bridge_credit_result(73, replacement_registry)
    assert bridge_credit_id(
        replacement_registry.src_chain_id, replacement_registry.source_domain_id,
        replacement_registry.src_epoch, replacement_registry.src_bridge,
        replacement_registry.destination_domain_id,
        replacement_registry.msg_hash) != bridge_credit_id(
            bridge.src_chain_id, bridge.source_domain_id, bridge.src_epoch,
            bridge.src_bridge, bridge.destination_domain_id, bridge.msg_hash)
    assert pin_inbox_credit(
        pins, replacement_registry.src_chain_id,
        replacement_registry.source_domain_id, replacement_registry.src_epoch,
        replacement_registry.src_bridge,
        replacement_registry.destination_domain_id,
        replacement_registry.msg_hash,
        replacement_result)
    assert len(pins) == 4

    done_leaf = bytes.fromhex(actual["terminal_done_leaf"])
    failed_leaf = bytes.fromhex(actual["terminal_failed_leaf"])
    terminal_vector = TerminalVector((done_leaf, failed_leaf))
    done_proof = terminal_vector.proof(0)
    assert terminal_vector.root.hex() == actual["terminal_root_2"]
    assert verify_terminal_proof(
        2, 0, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 0, failed_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 1, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        3, 0, done_leaf, done_proof, terminal_vector.root)
    assert not verify_terminal_proof(
        2, 0, done_leaf, done_proof[:-1], terminal_vector.root)

    descriptor = FrozenBridgeDescriptor(
        0xB123, 0xD001, 0xD003, bytes.fromhex("32" * 32),
        bytes.fromhex("33" * 32), bytes.fromhex("34" * 32))
    assert bridge_execution_hash(descriptor).hex() \
        == actual["bridge_execution_hash"]
    for invalid_descriptor in (
        replace(descriptor, bridge=0),
        replace(descriptor, credit_registry=0),
        replace(descriptor, terminal_verifier=0),
        replace(descriptor, facade_runtime_hash=bytes(32)),
        replace(descriptor, storage_layout_hash=bytes(32)),
        replace(descriptor, profile_hash=bytes(32)),
    ):
        try:
            canonical_frozen_bridge_descriptor(invalid_descriptor)
            raise AssertionError("invalid frozen bridge descriptor accepted")
        except AssertionError as error:
            assert str(error) != "invalid frozen bridge descriptor accepted"

    published = Path(__file__).with_name("tex").joinpath("main.tex").read_text()
    for key in ("bridge_leaf", "bridge_result", "bridge_credit_id",
                "bridge_escrow_id",
                "inbox_credit_slot", "terminal_done_leaf",
                "terminal_failed_leaf", "terminal_root_2",
                "empty_terminal_root",
                "source_domain_id", "destination_domain_id",
                "bridge_execution_hash"):
        assert actual[key] in published

    sid = bytes.fromhex(actual["session_id"])
    root = bytes.fromhex(actual["body_root"])
    croot = bytes.fromhex(actual["chunk_root_0"])
    z = fs_challenge(1, 2, sid, bytes.fromhex("99" * 32), root,
                     0, 0, 2, 5, croot, 0xCAFE, 9_999)
    assert 0 <= z < BLS_MODULUS
    print("RESULTS: commitment encoding model — ALL 92 VECTORS/PROPERTIES PASS")
    for key, value in actual.items():
        print(f"  {key}: {value}")
