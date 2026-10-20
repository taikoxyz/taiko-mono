#!/usr/bin/env python3
"""Regenerates testdata/etna_vectors/vectors.json.

Run from the repository root with Foundry's `cast` on PATH and the workspace's pnpm dependencies
installed (the output is formatted with the repository's prettier):

    python3 testdata/etna_vectors/generate.py

Every ABI encoding, hash and storage slot below is computed by `cast` (`abi-encode`, `keccak`,
`index`, `index-erc7201`, `format-bytes32-string`), independently of the Solidity contracts and of
taiko-client-rs, which both read the output. Only the inputs and the storage layout table are
written by hand; the readers check that table against the deployed contracts and the node's
decoders. All integers are decimal strings so that every value survives JSON parsing exactly.
"""

import json
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUTPUT = HERE / "vectors.json"

U32_MAX = 2**32 - 1
U64_MAX = 2**64 - 1
WORD_MOD = 2**256


def cast(*args):
    return subprocess.check_output(["cast", *map(str, args)], text=True).strip()


def keccak(data):
    return cast("keccak", data)


def abi_encode(signature, *args):
    return cast("abi-encode", signature, *args)


def tag(name):
    """A right-padded `bytes32` domain tag."""
    return cast("format-bytes32-string", name)


def word(value):
    """A 32-byte big-endian word."""
    return "0x" + format(value % WORD_MOD, "064x")


def concat(*hexes):
    return "0x" + "".join(h[2:] for h in hexes)


def repeated(byte):
    return "0x" + format(byte, "02x") * 32


def dec(value):
    return str(value)


def decimals(value):
    """`value` with every integer, at any depth, as a decimal string."""
    if isinstance(value, dict):
        return {k: decimals(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decimals(v) for v in value]
    return value if isinstance(value, str) else dec(value)


def committee_config():
    """The `ETNA_PARENT_ANCHOR_V5` configuration opening: ten static words (320 bytes)."""
    inputs = {
        "tag": "ETNA_PARENT_ANCHOR_V5",
        "l2_chain_id": 167001,
        "registry": "0x2222222222222222222222222222222222222222",
        "vp_unit": 10**9,
        "s_min": 10**18,
        "n_max": 128,
        "heartbeat_window": 32,
        "encoding_version": 2,
        "d_max": 12,
        "margin_v": 2,
    }
    preimage = abi_encode(
        "f(bytes32,uint256,address,uint256,uint256,uint64,uint64,uint8,uint64,uint64)",
        tag(inputs["tag"]),
        inputs["l2_chain_id"],
        inputs["registry"],
        inputs["vp_unit"],
        inputs["s_min"],
        inputs["n_max"],
        inputs["heartbeat_window"],
        inputs["encoding_version"],
        inputs["d_max"],
        inputs["margin_v"],
    )
    return {
        "inputs": {k: v if isinstance(v, str) else dec(v) for k, v in inputs.items()},
        "preimage": preimage,
        "hash": keccak(preimage),
    }


def land_statement(config_hash, base_fee_amount=1234567890123456789):
    """The V10 statement: twenty-one static words, independently encoded by cast."""
    inputs = {
        "tag": "TAIKO_ETNA_LAND_V10",
        "l1_chain_id": 1,
        "l2_chain_id": 167001,
        "inbox": "0x1111111111111111111111111111111111111111",
        "registry": "0x2222222222222222222222222222222222222222",
        "generation": 3,
        "parent_height": 100,
        "parent_hash": word(0x11),
        "committee_config_hash": config_hash,
        "last_height": 164,
        "last_block_hash": word(0x22),
        "last_state_root": word(0x33),
        "l1_reference_block_number": 19_000_000,
        "l1_reference_block_hash": word(0x44),
        "blob_hashes": [word(0x01AA), word(0x01BB)],
        "forced_inclusion_head_before": 3,
        "forced_inclusion_head_after": 5,
        "fee_recipient": "0x00000000000000000000000000000000000000aa",
        "l2_reward_recipient": "0x00000000000000000000000000000000000000bb",
        "base_fee_amount": base_fee_amount,
        "active_committee_snapshot": 18_999_000,
    }
    blob_hashes_hash = keccak(concat(*inputs["blob_hashes"]))
    preimage = abi_encode(
        "f(bytes32,uint256,uint64,address,address,uint64,uint64,bytes32,bytes32,uint64,bytes32,"
        "bytes32,uint64,bytes32,bytes32,uint48,uint48,address,address,uint256,uint64)",
        tag(inputs["tag"]),
        inputs["l1_chain_id"],
        inputs["l2_chain_id"],
        inputs["inbox"],
        inputs["registry"],
        inputs["generation"],
        inputs["parent_height"],
        inputs["parent_hash"],
        inputs["committee_config_hash"],
        inputs["last_height"],
        inputs["last_block_hash"],
        inputs["last_state_root"],
        inputs["l1_reference_block_number"],
        inputs["l1_reference_block_hash"],
        blob_hashes_hash,
        inputs["forced_inclusion_head_before"],
        inputs["forced_inclusion_head_after"],
        inputs["fee_recipient"],
        inputs["l2_reward_recipient"],
        inputs["base_fee_amount"],
        inputs["active_committee_snapshot"],
    )
    return {
        "inputs": decimals(inputs),
        "blob_hashes_hash": blob_hashes_hash,
        "preimage": preimage,
        "hash": keccak(preimage),
    }


def reward_receipt(landing):
    """Cast-derived batch identity, commitment and mapping-slot preimages."""
    inputs = landing["inputs"]
    preimage = abi_encode(
        "f(bytes32,uint256,uint64,address,uint64,uint64,bytes32,uint64,bytes32)",
        tag("ETNA_L2_REWARD_BATCH_V1"),
        inputs["l1_chain_id"],
        inputs["l2_chain_id"],
        inputs["inbox"],
        inputs["generation"],
        inputs["parent_height"],
        inputs["parent_hash"],
        inputs["last_height"],
        inputs["last_block_hash"],
    )
    batch_id = keccak(preimage)
    commitment_preimage = abi_encode(
        "f(bytes32,bytes32,address,uint256)",
        tag("ETNA_L2_REWARD_RECEIPT_V1"),
        batch_id,
        inputs["l2_reward_recipient"],
        inputs["base_fee_amount"],
    )
    slot_preimage = abi_encode("f(bytes32,uint256)", batch_id, 283)
    return {
        "batch_id_preimage": preimage,
        "batch_id": batch_id,
        "commitment_preimage": commitment_preimage,
        "commitment": keccak(commitment_preimage),
        "mapping_base_slot": "283",
        "slot_preimage": slot_preimage,
        "slot": keccak(slot_preimage),
    }


def committee_sets(entries):
    """Recipient-bound V2 leaves/records; set-key order and odd-node promotion are unchanged.

    Empty, singleton, odd-width and five-member cases fix tree behavior independently of the
    node's encoder. An empty root is represented for rejection tests and is never a valid committee.
    """
    cases = []
    chain_id, epoch, cutoff, checkpoint = 167001, 7, 100, 3
    # E0 is zero: record target epoch and set version k are distinct protocol inputs.
    set_version = epoch + 1
    for count in (0, 1, 3, 5):
        members = []
        for bond_id, entry in enumerate(entries[:count]):
            stake = int(entry["eff_stake"])
            members.append({
                "bond_id": dec(bond_id),
                "pubkey": entry["pubkey"],
                "eff_stake": dec(stake),
                "power": dec(stake // 10**9),
                "reward_recipient": entry["reward_recipient"],
                "set_key": keccak(abi_encode("f(bytes32,uint256,bytes32)",
                    tag("ETNA_SET_KEY"), chain_id, entry["pubkey"])),
            })
        members.sort(key=lambda member: int(member["set_key"], 16))
        preimages = [abi_encode("f(bytes32,uint256,uint256,uint256,bytes32,uint256,address)",
            tag("ETNA_SET_LEAF_V2"), chain_id, set_version, index,
            member["pubkey"], member["eff_stake"], member["reward_recipient"])
            for index, member in enumerate(members)]
        leaves = [keccak(preimage) for preimage in preimages]
        level = leaves[:]
        while len(level) > 1:
            level = [keccak(abi_encode("f(bytes32,uint256,uint256,bytes32,bytes32)",
                tag("ETNA_SET_NODE"), chain_id, set_version, level[i], level[i + 1]))
                if i + 1 < len(level) else level[i] for i in range(0, len(level), 2)]
        root = level[0] if level else word(0)
        total_stake = sum(int(member["eff_stake"]) for member in members)
        total_power = sum(int(member["power"]) for member in members)
        record_preimage = abi_encode(
            "f(bytes32,uint256,uint64,uint64,uint64,bytes32,uint256,uint64,uint8)",
            tag("ETNA_COMMITTEE_V2"), chain_id, epoch, cutoff, checkpoint,
            root, total_stake, total_power, 2)
        cases.append({
            "l2_chain_id": dec(chain_id), "target_epoch": dec(epoch),
            "set_version": dec(set_version),
            "cutoff_l1_block": dec(cutoff), "checkpoint_index": dec(checkpoint),
            "encoding_version": "2", "members": members,
            "set_leaf_preimages": preimages, "set_leaves": leaves, "set_root": root,
            "total_stake": dec(total_stake), "total_power": dec(total_power),
            "record_preimage": record_preimage, "record_hash": keccak(record_preimage),
        })
    return cases


def registry_entries():
    """Five registry entries, their `ETNA_REG_ENTRY_V2` leaves and the entries root of each prefix.

    Entry `i`: pubkey `0xa1 + i` repeated, `i + 1` TAIKO, active from `10 + i`, exit at
    `1000 + i` for odd `i` (none, `type(uint64).max`, for even `i`), heartbeat at `20 + i` with
    sequence `30 + i`, and L2 recipient `0xb1 + i` repeated to 20 bytes.
    """
    entries = []
    leaves = []
    for i in range(5):
        entry = {
            "pubkey": repeated(0xA1 + i),
            "eff_stake": (i + 1) * 10**18,
            "active_from_l1": 10 + i,
            "exit_effective_l1": 1000 + i if i % 2 == 1 else U64_MAX,
            "last_heartbeat_at": 20 + i,
            "last_heartbeat_seq": 30 + i,
            "reward_recipient": "0x" + format(0xB1 + i, "02x") * 20,
        }
        leaf = keccak(
            abi_encode(
                "f(bytes32,uint256,bytes32,uint256,uint64,uint64,uint64,uint64,address)",
                tag("ETNA_REG_ENTRY_V2"),
                i,
                entry["pubkey"],
                entry["eff_stake"],
                entry["active_from_l1"],
                entry["exit_effective_l1"],
                entry["last_heartbeat_at"],
                entry["last_heartbeat_seq"],
                entry["reward_recipient"],
            )
        )
        entries.append({k: v if isinstance(v, str) else dec(v) for k, v in entry.items()})
        leaves.append(leaf)

    def root(count):
        if count == 0:
            return word(0)
        level = leaves[:count]
        width = 1
        while width < count:
            width *= 2
        level += [word(0)] * (width - count)
        while len(level) > 1:
            level = [keccak(concat(level[j], level[j + 1])) for j in range(0, len(level), 2)]
        return level[0]

    return {
        "entries": entries,
        "leaves": leaves,
        "roots": [{"count": dec(n), "entries_root": root(n)} for n in range(6)],
    }


def field(offset, bits):
    return {"offset": dec(offset), "bits": dec(bits)}


def layout():
    """The node-facing storage layout of the Inbox and the staking registry."""
    base = cast("index-erc7201", "taiko.etna.registry")
    base_int = int(base, 16)
    checkpoint_data = int(keccak(base), 16)
    entries_slot = word(base_int + 1)
    entry_data = int(keccak(entries_slot), 16)

    def checkpoint_slots(i):
        first = checkpoint_data + 2 * i
        return [word(first), word(first + 1)]

    def entry_slots(j):
        first = entry_data + 4 * j
        return [word(first + w) for w in range(4)]

    def snapshot_slots(i, has_next):
        head, root = checkpoint_slots(i)
        slots = [base, head, root]
        if has_next:
            slots.append(word(int(root, 16) + 1))
        return slots

    def forced_entry_slots(index):
        first = int(cast("index", "uint256", index, 280), 16)
        return [word(first), word(first + 1)]

    inbox_slots = {
        "status": 258,
        "recovery_generation": 268,
        "committee_config_hash": 269,
        "last_checkpoint_height": 270,
        "last_checkpoint_hash": 271,
        "activation_packed": 272,
        "genesis_block_hash": 273,
        "genesis_state_root": 274,
        "genesis_committee_hash": 278,
        "genesis_cutoff": 279,
        "forced_inclusion_queue": 280,
        "forced_inclusion_head_tail": 281,
        "forced_inclusion_config": 282,
        "reward_receipts": 283,
        "active_committee_snapshot": 284,
    }
    return {
        "inbox": {
            "slots": {k: dec(v) for k, v in inbox_slots.items()},
            "packing": {
                "status": {"status": field(0, 8)},
                "recovery_generation": {"recovery_generation": field(0, 64)},
                "last_checkpoint_height": {"height": field(0, 64)},
                "activation_packed": {
                    "genesis_height": field(0, 64),
                    "l1_block": field(64, 64),
                    "epoch_len_l2": field(128, 64),
                },
                "genesis_cutoff": {"genesis_cutoff": field(0, 64)},
                "active_committee_snapshot": {"active_committee_snapshot": field(0, 64)},
                "forced_inclusion_head_tail": {"head": field(0, 48), "tail": field(48, 48)},
                "forced_inclusion_config": {"delay": field(0, 64), "max_anchor_age": field(64, 64)},
                "forced_inclusion_entry_metadata": {
                    "timestamp": field(0, 48),
                    "l1_block": field(48, 64),
                    "fee_in_gwei": field(112, 64),
                },
            },
            "status_active": "3",
            "anchor_slots": [dec(n) for n in (258, 268, 270, 271, 281)],
            "genesis_slots": [dec(n) for n in (258, 268, 272, 273, 274, 279, 278, 269, 282)],
            "forced_inclusion_entry_slots": [
                {"index": dec(i), "slots": forced_entry_slots(i)} for i in (0, 7)
            ],
        },
        "registry": {
            "namespace": "taiko.etna.registry",
            "base": base,
            "entries_length_slot": entries_slot,
            "inbox_slot": word(base_int + 8),
            "packing": {
                "checkpoint_head": {"l1_block": field(0, 64), "count": field(64, 32)},
                "entry_packed": {
                    "active_from_l1": field(0, 64),
                    "exit_effective_l1": field(64, 64),
                    "last_heartbeat_at": field(128, 64),
                    "last_heartbeat_seq": field(192, 64),
                },
            },
            "checkpoint_slots": [
                {"index": dec(i), "slots": checkpoint_slots(i)} for i in (0, 1, 5, U64_MAX)
            ],
            "entry_slots": [
                {"index": dec(j), "slots": entry_slots(j)} for j in (0, 1, 2, U64_MAX)
            ],
            "snapshot_slots": [
                {"index": dec(i), "has_next": has_next, "slots": snapshot_slots(i, has_next)}
                for i, has_next in ((0, False), (0, True), (3, True), (U64_MAX, True))
            ],
        },
    }


def main():
    config = committee_config()
    landing = land_statement(config["hash"])
    entries = registry_entries()
    zero = land_statement(config["hash"], base_fee_amount=0)
    vectors = {
        "schema_version": "3",
        "committee_config": config,
        "land_statement": landing,
        "reward_receipt": reward_receipt(landing),
        "land_selector": cast(
            "sig", "land((uint64,bytes32,bytes32,uint64,uint48,address,address,uint256,uint64),bytes)"
        ),
        "claim_selector": cast("sig", "claim((uint256,uint64,address,uint64,uint64,bytes32,uint64,bytes32,address,uint256),uint256,bytes[],bytes[])"),
        "zero_fee": {"land_statement": zero, "reward_receipt": reward_receipt(zero)},
        "committee_sets": committee_sets(entries["entries"]),
        "registry_entries": entries,
        "layout": layout(),
    }
    OUTPUT.write_text(json.dumps(vectors, indent=2) + "\n")
    subprocess.run(["pnpm", "exec", "prettier", "--write", str(OUTPUT)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
