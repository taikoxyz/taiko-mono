#!/usr/bin/env python3
"""Golden vectors for Slot-Chain consensus encodings and commitments."""

from __future__ import annotations

import runpy
from dataclasses import dataclass
from pathlib import Path

LOOK = runpy.run_path(str(Path(__file__).with_name("lookahead-model.py")))
keccak256 = LOOK["keccak256"]
u16 = LOOK["u16"]
u64 = LOOK["u64"]
u256 = LOOK["u256"]

BLS_MODULUS = int("73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001", 16)

TYPE_STRING = (
    "SlotChainBlock(uint256 chainId,uint256 protocolVersion,address verifyingContract,"
    "uint64 slot,bytes32 parentHash,bytes32 blockHash,bytes32 stateRoot,bytes32 bodyRoot,"
    "uint64 anchorNumber,bytes32 anchorHash,bytes32 forceRoot,uint64 forceCutoff,"
    "uint64 messageStart,uint64 messageEnd,bytes32 dataManifestRoot,address coinbase,"
    "uint8 tier,uint64 admissionVersion,uint64 episode,uint64 recoveryRevision,"
    "bytes32 recoveryId)"
)

D_REG_LEAF = b"slot-chain-registry-leaf-v1"
D_REG_NODE = b"slot-chain-registry-node-v1"
D_FORCE_LEAF = b"slot-chain-force-leaf-v1"
D_FORCE_INIT = b"slot-chain-force-init-v1"
D_FORCE_NODE = b"slot-chain-force-node-v1"
D_MMR_LEAF = b"slot-chain-data-leaf-v1"
D_MMR_NODE = b"slot-chain-data-node-v1"
D_MMR_BAG = b"slot-chain-data-bag-v1"
D_RECOVERY = b"slot-chain-recovery-v2"
D_BODY = b"slot-chain-body-v1"
D_SESSION = b"slot-chain-session-v1"
D_FS = b"slot-chain-data-fs-v1"


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


def b32(value: int | bytes) -> bytes:
    raw = value.to_bytes(32, "big") if isinstance(value, int) else value
    assert len(raw) == 32
    return raw


@dataclass(frozen=True)
class RegistryCell:
    address: int
    bond: int
    registration_index: int
    effective_slot: int
    tranche_root: bytes
    tombstone_slot: int


def registry_leaf(index: int, cell: RegistryCell | None) -> bytes:
    if cell is None:
        payload = u8(index) + u8(0) + bytes(20 + 24 + 8 + 8 + 32 + 8)
    else:
        payload = (u8(index) + u8(1) + address20(cell.address) + u192(cell.bond)
                   + u64(cell.registration_index) + u64(cell.effective_slot)
                   + b32(cell.tranche_root) + u64(cell.tombstone_slot))
    return keccak256(D_REG_LEAF + payload)


def registry_root(cells: tuple[RegistryCell | None, ...]) -> bytes:
    assert len(cells) == 64
    level = [registry_leaf(i, cell) for i, cell in enumerate(cells)]
    height = 0
    while len(level) > 1:
        level = [keccak256(D_REG_NODE + u8(height) + level[i] + level[i + 1])
                 for i in range(0, len(level), 2)]
        height += 1
    return level[0]


@dataclass(frozen=True)
class ForcedEnvelope:
    kind: int
    sender: int
    nonce: int
    chain_id: int
    raw_tx_hash: bytes
    byte_length: int
    accounted_gas: int
    max_fee: int
    valid_until: int
    refund: int
    enqueued_at: int
    due_at: int
    deposit: int


def forced_leaf(index: int, envelope: ForcedEnvelope) -> bytes:
    return keccak256(
        D_FORCE_LEAF + u64(index) + u8(envelope.kind)
        + address20(envelope.sender) + u64(envelope.nonce)
        + u256(envelope.chain_id) + b32(envelope.raw_tx_hash)
        + u32(envelope.byte_length) + u64(envelope.accounted_gas)
        + u256(envelope.max_fee) + u64(envelope.valid_until)
        + address20(envelope.refund) + u64(envelope.enqueued_at) + u64(envelope.due_at)
        + u256(envelope.deposit)
    )


def forced_root(envelopes: tuple[ForcedEnvelope, ...]) -> bytes:
    root = keccak256(D_FORCE_INIT)
    for index, envelope in enumerate(envelopes):
        root = keccak256(D_FORCE_NODE + root + forced_leaf(index, envelope) + u64(index + 1))
    return root


def session_id(chain_id: int, contract: int, owner: int, nonce: int) -> bytes:
    return keccak256(D_SESSION + u256(chain_id) + address20(contract)
                     + address20(owner) + u64(nonce))


def data_leaf(session: bytes, index: int, versioned_hash: bytes, body_root: bytes,
              publisher: int, valid_until: int, z: int, y: int) -> bytes:
    return keccak256(D_MMR_LEAF + b32(session) + u16(index) + b32(versioned_hash)
                     + b32(body_root) + address20(publisher) + u64(valid_until)
                     + u256(z) + u256(y))


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


def recovery_id(chain_id: int, contract: int, episode: int, revision: int,
                base_tuple_hash: bytes, round_start_slot: int,
                anchor_number: int, anchor_hash: bytes,
                force_root_hash: bytes, force_cutoff: int,
                admission_version: int, admission_root: bytes, escape_slot: int,
                causes: int) -> bytes:
    return keccak256(
        D_RECOVERY + u256(chain_id) + address20(contract) + u64(episode) + u64(revision)
        + b32(base_tuple_hash) + u64(round_start_slot)
        + u64(anchor_number) + b32(anchor_hash)
        + b32(force_root_hash) + u64(force_cutoff) + u64(admission_version)
        + b32(admission_root) + u64(escape_slot) + u8(causes)
    )


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
                 versioned_hash: bytes, root: bytes, publisher: int,
                 valid_until: int) -> int:
    digest = keccak256(D_FS + u256(chain_id) + u256(version) + b32(session)
                       + b32(versioned_hash) + b32(root) + address20(publisher)
                       + u64(valid_until))
    return int.from_bytes(digest, "big") % BLS_MODULUS


def point_evaluation_input(versioned_hash: bytes, z: int, y: int,
                           commitment: bytes, proof: bytes) -> bytes:
    assert len(commitment) == 48 and len(proof) == 48
    return b32(versioned_hash) + u256(z) + u256(y) + commitment + proof


def vectors() -> dict[str, str]:
    cells = [None] * 64
    cells[3] = RegistryCell(0x1234, 10**18, 9, 777, bytes.fromhex("11" * 32), (1 << 64) - 1)
    env = ForcedEnvelope(0, 0xCAFE, 7, 16_788, bytes.fromhex("22" * 32), 123,
                         80_000, 10**12, 9_999, 0xBEEF, 555, 2_055, 10**15)
    sid = session_id(16_788, 0xABCD, 0xCAFE, 2)
    leaf0 = data_leaf(sid, 0, bytes.fromhex("33" * 32), bytes.fromhex("44" * 32),
                      0xCAFE, 9_999, 5, 6)
    leaf1 = data_leaf(sid, 1, bytes.fromhex("55" * 32), bytes.fromhex("66" * 32),
                      0xCAFE, 9_999, 7, 8)
    force = forced_root((env,))
    return {
        "typehash": keccak256(TYPE_STRING.encode()).hex(),
        "registry_root": registry_root(tuple(cells)).hex(),
        "forced_leaf": forced_leaf(0, env).hex(),
        "forced_root": force.hex(),
        "session_id": sid.hex(),
        "mmr_root_2": mmr_root((leaf0, leaf1)).hex(),
        "recovery_id": recovery_id(16_788, 0xABCD, 4, 2, bytes.fromhex("77" * 32),
                                   8_000, 1_000, bytes.fromhex("88" * 32), force,
                                   1, 12, bytes.fromhex("aa" * 32), 9_000, 3).hex(),
        "body_root": body_root((bytes.fromhex("0102"), bytes.fromhex("030405"))).hex(),
    }


EXPECTED = {
    "typehash": "0a0bfc3b8ba52a166f662055d09891465d916aa486808e78105890e98d65777f",
    "registry_root": "0bf297d7b9b6a5529a319a06cb08484923a89bab15d51f8baeaf5c30bebdf3fd",
    "forced_leaf": "8ad75dbe7165ea80f9615291e522e26253a9b2a3a0a385f5d6acb8e096feb1c6",
    "forced_root": "0e5416c12bf86837bad8fd0370f247683a401ceaa80f45e4a3fca52876ad448d",
    "session_id": "1c475ec71f05dcd709462a9ce2589faf47d4492913a1164d45b8ff59f722265b",
    "mmr_root_2": "f06fd107666ba9e51ad09606ba9c9f1f1c16177f586167f87b16f333806d485d",
    "recovery_id": "9970a429a00e56b8abc5e7fcb4a4a35795507e949821be66f2f737e888ded285",
    "body_root": "0f4e161a46c8b18c2a86f23a0a4e7169a838a12af8b389f65e97b547a99707e9",
}


if __name__ == "__main__":
    actual = vectors()
    if "UPDATE" in EXPECTED.values():
        for key, value in actual.items():
            print(f'{key} = "{value}"')
        raise SystemExit("populate EXPECTED with the vectors above")
    assert actual == EXPECTED
    payload = body_bytes((b"alpha", b"beta"))
    blob = encode_blob_payload(payload)
    assert decode_blob_payload(blob) == payload
    sid = bytes.fromhex(actual["session_id"])
    z = fs_challenge(16_788, 2, sid, bytes.fromhex("99" * 32),
                     bytes.fromhex(actual["body_root"]), 0xCAFE, 9_999)
    precompile = point_evaluation_input(bytes.fromhex("99" * 32), z, 1,
                                        bytes(48), bytes(48))
    assert len(precompile) == 192 and 0 <= z < BLS_MODULUS
    print("RESULTS: commitment encoding model — ALL 12 VECTORS/PROPERTIES PASS")
    for key, value in actual.items():
        print(f"  {key}: {value}")
