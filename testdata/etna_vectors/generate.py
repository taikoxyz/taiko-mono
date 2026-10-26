#!/usr/bin/env python3
"""Regenerates testdata/etna_vectors/vectors.json (schema "4").

Run from the repository root with Foundry's `cast` on PATH and the workspace's pnpm dependencies
installed (the output is formatted with the repository's prettier):

    python3 testdata/etna_vectors/generate.py

Every ABI encoding, hash and storage slot below is computed by `cast` (`abi-encode`, `keccak`,
`index`, `index-erc7201`, `format-bytes32-string`, `sig`, `calldata`, `wallet address`),
independently of the Solidity contracts and of taiko-client-rs, which both read the output. The
secp256k1 public keys come from a small pure-Python helper and are cross-checked against
`cast wallet address`. Only the inputs, the packing table and the storage slot numbers are written
by hand, following the Etna spec's appendix A (encodings) and appendix B (storage layout). All
integers are decimal strings so that every value survives JSON parsing exactly.
"""

import base64
import json
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUTPUT = HERE / "vectors.json"

WORD_MOD = 2**256
U48_MAX = 2**48 - 1
NO_EXIT = U48_MAX  # exitEffectiveL1 = 2^48 - 1 means no exit is set
K = 6  # landing grid interval

# secp256k1 curve parameters (SEC 2).
SECP_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
SECP_G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)

DEPLOYMENT = {
    "l1_chain_id": 1,
    "l2_chain_id": 167001,
    "inbox": "0x1111111111111111111111111111111111111111",
    "registry": "0x2222222222222222222222222222222222222222",
    "l2_block_gas_limit": 45_000_000,
}
OTHER_INBOX = "0x3333333333333333333333333333333333333333"


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


def dec(value):
    return str(value)


def decimals(value):
    """`value` with every integer, at any depth, as a decimal string (booleans stay booleans)."""
    if isinstance(value, dict):
        return {k: decimals(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decimals(v) for v in value]
    if isinstance(value, (bool, str)):
        return value
    return dec(value)


# --- secp256k1 -----------------------------------------------------------------------------------


def _add(a, b):
    """Affine point addition; `None` is the point at infinity."""
    if a is None:
        return b
    if b is None:
        return a
    (x1, y1), (x2, y2) = a, b
    if x1 == x2 and (y1 + y2) % SECP_P == 0:
        return None
    if a == b:
        slope = 3 * x1 * x1 * pow(2 * y1, -1, SECP_P) % SECP_P
    else:
        slope = (y2 - y1) * pow(x2 - x1, -1, SECP_P) % SECP_P
    x3 = (slope * slope - x1 - x2) % SECP_P
    return x3, (slope * (x1 - x3) - y1) % SECP_P


def point(k):
    """`k·G` by double-and-add."""
    assert 1 <= k < SECP_N
    result, addend = None, SECP_G
    while k:
        if k & 1:
            result = _add(result, addend)
        addend = _add(addend, addend)
        k >>= 1
    return result


def compress(x, y):
    """SEC1 compressed encoding: `0x02 | (y & 1)` followed by the 32-byte big-endian X."""
    return bytes([2 + (y & 1)]) + x.to_bytes(32, "big")


# --- deployment and keys -------------------------------------------------------------------------


def deployment():
    return decimals(DEPLOYMENT)


def leading_zero_x_scalar():
    """The first scalar k >= 1 whose public key X has a zero top byte."""
    k, current = 1, SECP_G
    while current[0] >> 248:
        k += 1
        current = _add(current, SECP_G)
    assert point(k) == current
    return k


def keys():
    """Consensus keys 0xA1..0xA5 plus the first key whose X starts with a zero byte."""
    scalars = [(f"a{i}", 0xA0 + i) for i in range(1, 6)]
    scalars.append(("leading_zero_x", leading_zero_x_scalar()))
    out = []
    for name, k in scalars:
        x, y = point(k)
        private_key = word(k)
        ck_x, ck_y = word(x), word(y)
        ck_prefix = 2 + (y & 1)
        ck_addr = "0x" + keccak(concat(ck_x, ck_y))[-40:]
        assert ck_addr == cast("wallet", "address", "--private-key", private_key).lower(), name
        out.append(
            {
                "name": name,
                "private_key": private_key,
                "public_key": "0x" + compress(x, y).hex(),
                "ck_prefix": ck_prefix,
                "ck_x": ck_x,
                "ck_y": ck_y,
                "ck_addr": ck_addr,
                "entry_key": keccak(abi_encode("f(uint256,bytes32)", ck_prefix, ck_x)),
            }
        )
    return decimals(out)


# --- committee configuration, registry entries, committee sets -----------------------------------


def committee_config():
    """`committeeConfigHash`: seven static words (224 bytes)."""
    inputs = {
        "tag": "ETNA_PARENT_ANCHOR_V1",
        "l2_chain_id": DEPLOYMENT["l2_chain_id"],
        "registry": DEPLOYMENT["registry"],
        "vp_unit": 10**9,
        "s_min": 10**18,
        "n_max": 128,
        "unsettled_limit": 3600,
    }
    preimage = abi_encode(
        "f(bytes32,uint256,address,uint256,uint256,uint256,uint256)",
        tag(inputs["tag"]),
        inputs["l2_chain_id"],
        inputs["registry"],
        inputs["vp_unit"],
        inputs["s_min"],
        inputs["n_max"],
        inputs["unsettled_limit"],
    )
    return {"inputs": decimals(inputs), "preimage": preimage, "hash": keccak(preimage)}


def reg_leaf(index, entry):
    return keccak(
        abi_encode(
            "f(bytes32,uint256,uint256,bytes32,uint256,uint256,uint256)",
            tag("ETNA_REG_ENTRY_V1"),
            index,
            entry["ck_prefix"],
            entry["ck_x"],
            entry["eff_stake"],
            entry["active_from_l1"],
            entry["exit_effective_l1"],
        )
    )


def entries_root(leaves):
    """Leaves zero-padded to a power of two, inner nodes keccak256(left || right); none gives 0."""
    if not leaves:
        return word(0)
    width = 1
    while width < len(leaves):
        width *= 2
    level = leaves + [word(0)] * (width - len(leaves))
    while len(level) > 1:
        level = [keccak(concat(level[j], level[j + 1])) for j in range(0, len(level), 2)]
    return level[0]


def registry_entries(key_list):
    """Entries 0..4 from keys a1..a5, their leaves, a released slot 5 and every prefix root.

    Entry `i`: `i + 1` TAIKO, active from `10 + i`, exit at `1000 + i` for odd `i` (no exit,
    `2^48 - 1`, for even `i`). Slot 5 is released: its entry has all-zero fields.
    """
    entries = []
    for i, key in enumerate(key_list[:5]):
        entries.append(
            {
                "ck_prefix": int(key["ck_prefix"]),
                "ck_x": key["ck_x"],
                "eff_stake": (i + 1) * 10**18,
                "active_from_l1": 10 + i,
                "exit_effective_l1": 1000 + i if i % 2 == 1 else NO_EXIT,
            }
        )
    leaves = [reg_leaf(i, entry) for i, entry in enumerate(entries)]
    zero_entry = {
        "ck_prefix": 0,
        "ck_x": word(0),
        "eff_stake": 0,
        "active_from_l1": 0,
        "exit_effective_l1": 0,
    }
    released = {"index": 5, "leaf": reg_leaf(5, zero_entry)}
    all_leaves = leaves + [released["leaf"]]
    return decimals(
        {
            "entries": entries,
            "leaves": leaves,
            "released": released,
            "roots": [
                {"count": n, "entries_root": entries_root(all_leaves[:n])} for n in range(7)
            ],
        }
    )


def committee_sets(entries, config):
    """Committee sets of 0, 1, 3 and 5 members (the first registry entries), per appendix A.

    Members are in ascending set-key order; leaves and nodes use `k = targetEpoch + 1`; an odd last
    node is promoted unchanged. Spec 4.3 rejects an empty committee, so the 0-member case carries
    no root or record.
    """
    chain_id = DEPLOYMENT["l2_chain_id"]
    vp_unit = int(config["inputs"]["vp_unit"])
    target_epoch, cutoff, checkpoint = 7, 100, 3
    k = target_epoch + 1
    cases = []
    for count in (0, 1, 3, 5):
        if count == 0:
            cases.append({"members": [], "valid": False, "reason": "empty_committee"})
            continue
        members = []
        for entry in entries[:count]:
            stake = int(entry["eff_stake"])
            members.append(
                {
                    "ck_prefix": int(entry["ck_prefix"]),
                    "ck_x": entry["ck_x"],
                    "eff_stake": stake,
                    "power": stake // vp_unit,
                    "set_key": keccak(
                        abi_encode(
                            "f(bytes32,uint256,uint256,bytes32)",
                            tag("ETNA_SET_KEY_V1"),
                            chain_id,
                            entry["ck_prefix"],
                            entry["ck_x"],
                        )
                    ),
                }
            )
        members.sort(key=lambda member: int(member["set_key"], 16))
        preimages = [
            abi_encode(
                "f(bytes32,uint256,uint256,uint256,uint256,bytes32,uint256,uint256)",
                tag("ETNA_SET_LEAF_V1"),
                chain_id,
                k,
                index,
                member["ck_prefix"],
                member["ck_x"],
                member["eff_stake"],
                member["power"],
            )
            for index, member in enumerate(members)
        ]
        leaves = [keccak(preimage) for preimage in preimages]
        level = leaves[:]
        while len(level) > 1:
            level = [
                keccak(
                    abi_encode(
                        "f(bytes32,uint256,uint256,bytes32,bytes32)",
                        tag("ETNA_SET_NODE"),
                        chain_id,
                        k,
                        level[i],
                        level[i + 1],
                    )
                )
                if i + 1 < len(level)
                else level[i]
                for i in range(0, len(level), 2)
            ]
        root = level[0]
        total_power = sum(member["power"] for member in members)
        record_preimage = abi_encode(
            "f(bytes32,uint256,uint256,uint256,uint256,bytes32,uint256)",
            tag("ETNA_COMMITTEE_V1"),
            chain_id,
            target_epoch,
            cutoff,
            checkpoint,
            root,
            total_power,
        )
        cases.append(
            {
                "valid": True,
                "l2_chain_id": chain_id,
                "target_epoch": target_epoch,
                "set_version": k,
                "cutoff_l1_block": cutoff,
                "checkpoint_index": checkpoint,
                "members": members,
                "set_leaf_preimages": preimages,
                "set_leaves": leaves,
                "set_root": root,
                "total_power": total_power,
                "record_preimage": record_preimage,
                "record_hash": keccak(record_preimage),
            }
        )
    return decimals(cases)


# --- cuts, statements, land ABI ------------------------------------------------------------------


def cut_at(x):
    """The Lean model's `Examples.cutAt`: EL hash 100 + x, Comet hash 200 + x (0 at x = 0), FI
    cursor x / 6."""
    return {
        "height": x,
        "block_hash": word(100 + x),
        "comet_hash": word(0 if x == 0 else 200 + x),
        "forced_head": x // K,
    }


_LEAVES = {}


def cut_leaf(x):
    """`(preimage, leaf)` of cutLeaf(x): four words (x, blockHash, cometHash, forcedHead)."""
    if x not in _LEAVES:
        cut = cut_at(x)
        preimage = abi_encode(
            "f(uint256,bytes32,bytes32,uint256)",
            x,
            cut["block_hash"],
            cut["comet_hash"],
            cut["forced_head"],
        )
        _LEAVES[x] = (preimage, keccak(preimage))
    return _LEAVES[x]


CUT_CASES = (
    ("g0_p0_h6", 0, 0, 6),
    ("g0_p0_h12", 0, 0, 12),
    ("g0_p0_h18", 0, 0, 18),
    ("g1_p6_h18", 1, 6, 18),
    ("g0_p0_h300", 0, 0, 300),
)


def cuts():
    table = []
    for x in range(19):
        preimage, leaf = cut_leaf(x)
        table.append({**cut_at(x), "preimage": preimage, "leaf": leaf})
    cut_hashes = []
    for name, generation, p, h in CUT_CASES:
        leaves = [cut_leaf(x)[1] for x in range(p + K, h, K)]
        assert len(leaves) == (h - p) // K - 1
        leaves_hash = keccak(concat(*leaves))
        preimage = abi_encode(
            "f(bytes32,uint256,uint256,uint256,bytes32)",
            tag("ETNA_LAND_CUTS_V1"),
            generation,
            p,
            h,
            leaves_hash,
        )
        cut_hashes.append(
            {
                "name": name,
                "generation": generation,
                "parent_height": p,
                "last_height": h,
                "leaves": leaves,
                "leaves_hash": leaves_hash,
                "preimage": preimage,
                "cut_hash": keccak(preimage),
            }
        )
    return decimals({"table": table, "cut_hashes": cut_hashes})


def cut_hash_for(cut_vectors, generation, p, h):
    (case,) = [
        c
        for c in cut_vectors["cut_hashes"]
        if (int(c["generation"]), int(c["parent_height"]), int(c["last_height"]))
        == (generation, p, h)
    ]
    return case["cut_hash"]


STATEMENT_SIGNATURE = (
    "f(bytes32,uint256,uint256,address,address,uint256,uint256,bytes32,bytes32,bytes32,uint256,"
    "bytes32,bytes32,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256,bytes32)"
)
STATEMENT_CASES = (
    # name, generation, p, h, FI head before (at p), FI head after (at h)
    ("genesis", 0, 0, 18, 0, 3),
    ("nonzero", 1, 6, 18, 1, 3),
)


def land_statements(config, cut_vectors):
    """Twenty-one static words (672 bytes); origin and terminal values follow `cut_at`."""
    out = []
    for name, generation, p, h, head_before, head_after in STATEMENT_CASES:
        origin, last = cut_at(p), cut_at(h)
        assert (origin["forced_head"], last["forced_head"]) == (head_before, head_after)
        inputs = {
            "tag": "TAIKO_ETNA_LAND_V1",
            "l1_chain_id": DEPLOYMENT["l1_chain_id"],
            "l2_chain_id": DEPLOYMENT["l2_chain_id"],
            "inbox": DEPLOYMENT["inbox"],
            "registry": DEPLOYMENT["registry"],
            "generation": generation,
            "parent_height": p,
            "parent_hash": origin["block_hash"],
            "parent_comet_hash": origin["comet_hash"],
            "committee_config_hash": config["hash"],
            "last_height": h,
            "last_block_hash": last["block_hash"],
            "last_comet_hash": last["comet_hash"],
            "last_state_root": word(300 + h),
            "l1_reference_block_number": 19_000_000,
            "l1_reference_block_hash": word(0x44),
            "blob_hashes": ["0x01" + "aa" * 31, "0x01" + "bb" * 31],
            "forced_inclusion_head_before": head_before,
            "forced_inclusion_head_after": head_after,
            "active_committee_snapshot": 18_999_000,
            "cut_hash": cut_hash_for(cut_vectors, generation, p, h),
        }
        blob_hashes_hash = keccak(concat(*inputs["blob_hashes"]))
        preimage = abi_encode(
            STATEMENT_SIGNATURE,
            tag(inputs["tag"]),
            inputs["l1_chain_id"],
            inputs["l2_chain_id"],
            inputs["inbox"],
            inputs["registry"],
            inputs["generation"],
            inputs["parent_height"],
            inputs["parent_hash"],
            inputs["parent_comet_hash"],
            inputs["committee_config_hash"],
            inputs["last_height"],
            inputs["last_block_hash"],
            inputs["last_comet_hash"],
            inputs["last_state_root"],
            inputs["l1_reference_block_number"],
            inputs["l1_reference_block_hash"],
            blob_hashes_hash,
            inputs["forced_inclusion_head_before"],
            inputs["forced_inclusion_head_after"],
            inputs["active_committee_snapshot"],
            inputs["cut_hash"],
        )
        out.append(
            {
                "name": name,
                "inputs": decimals(inputs),
                "blob_hashes_hash": blob_hashes_hash,
                "preimage": preimage,
                "hash": keccak(preimage),
            }
        )
    return out


LAND_SIGNATURE = (
    "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256),bytes32[],bytes)"
)


def land_abi(statements):
    """Calldata of `land(input, leaves, proof)` for the `nonzero` statement (p 6, h 18)."""
    (statement,) = [s for s in statements if s["name"] == "nonzero"]
    inputs = statement["inputs"]
    p, h = int(inputs["parent_height"]), int(inputs["last_height"])
    leaves = [cut_leaf(x)[1] for x in range(p + K, h, K)]
    proof = "0x00"
    land_input = "(" + ",".join(
        [
            inputs["parent_height"],
            inputs["last_height"],
            inputs["last_block_hash"],
            inputs["last_comet_hash"],
            inputs["last_state_root"],
            inputs["l1_reference_block_number"],
            inputs["forced_inclusion_head_after"],
            inputs["active_committee_snapshot"],
        ]
    ) + ")"
    return {
        "signature": LAND_SIGNATURE,
        "selector": cast("sig", LAND_SIGNATURE),
        "statement": "nonzero",
        "leaves": leaves,
        "proof": proof,
        "calldata": cast(
            "calldata", LAND_SIGNATURE, land_input, "[" + ",".join(leaves) + "]", proof
        ),
    }


# --- chain identity and block header -------------------------------------------------------------


def chain_domains():
    """chainDomain and the 48-byte CometBFT chain_id = "etna-" + base64url_no_padding(digest)."""
    l1, l2, inbox = DEPLOYMENT["l1_chain_id"], DEPLOYMENT["l2_chain_id"], DEPLOYMENT["inbox"]
    cases = [(inbox, g) for g in (0, 1, 2, U48_MAX)] + [(OTHER_INBOX, 0)]
    out = []
    for case_inbox, generation in cases:
        preimage = abi_encode(
            "f(bytes32,uint256,uint256,address,uint256)",
            tag("ETNA_COMET_DOMAIN_V1"),
            l1,
            l2,
            case_inbox,
            generation,
        )
        digest = keccak(preimage)
        encoded = base64.urlsafe_b64encode(bytes.fromhex(digest[2:])).decode()
        chain_id = "etna-" + encoded.rstrip("=")
        assert len(chain_id) == 48
        out.append(
            {
                "l1_chain_id": l1,
                "l2_chain_id": l2,
                "inbox": case_inbox,
                "generation": generation,
                "preimage": preimage,
                "chain_domain": digest,
                "chain_id": chain_id,
            }
        )
    return decimals(out)


def extra_data():
    """extraData = 0x64 || uint48_be(generation) || uint48_be(anchorNumber): 13 bytes."""
    out = []
    for generation, anchor_number in ((0, 0), (5, 7), (U48_MAX, U48_MAX)):
        out.append(
            {
                "generation": generation,
                "anchor_number": anchor_number,
                "extra_data": "0x64" + format(generation, "012x") + format(anchor_number, "012x"),
            }
        )
    return decimals(out)


# --- storage layout ------------------------------------------------------------------------------

# Packed words (appendix B): fields in the listed order from the least-significant bit; ckPrefix
# takes 8 bits and every other field 48; unused high bits are zero.
# Each entry: vector key -> (layout table, packing name, fields, ordinary values); every kind also
# gets an all-max item (2^48 - 1, ckPrefix 3).
PACKED = {
    "inbox_272": (
        "inbox",
        "genesis_packed",
        ("genesis_height", "l1_block", "epoch_len_l2"),
        (6, 19_000_000, 3_600),
    ),
    "inbox_280_word2": (
        "inbox",
        "forced_inclusion_entry_word2",
        ("timestamp", "l1_block"),
        (1_700_000_000, 19_000_123),
    ),
    "inbox_281": ("inbox", "forced_inclusion_head_tail", ("head", "tail"), (1, 3)),
    "inbox_282": (
        "inbox",
        "forced_inclusion_config",
        ("forced_inclusion_delay", "max_anchor_age"),
        (384, 1_152),
    ),
    "inbox_285_word1": (
        "inbox",
        "landing_word1",
        ("parent_height", "generation", "head"),
        (12, 1, 3),
    ),
    "registry_checkpoint_word1": (
        "registry",
        "checkpoint_word1",
        ("l1_block", "count"),
        (19_000_000, 5),
    ),
    "registry_entry_word3": (
        "registry",
        "entry_word3",
        ("ck_prefix", "active_from_l1", "exit_effective_l1"),
        (2, 10, 1_001),
    ),
}


def bits_of(field_name):
    return 8 if field_name == "ck_prefix" else 48


def packing(table):
    out = {}
    for _, (layout_table, name, fields, _) in PACKED.items():
        if layout_table != table:
            continue
        offset, lanes = 0, {}
        for field_name in fields:
            lanes[field_name] = {"offset": offset, "bits": bits_of(field_name)}
            offset += bits_of(field_name)
        out[name] = lanes
    return out


def pack(fields, values):
    packed, offset = 0, 0
    for field_name, value in zip(fields, values):
        bits = bits_of(field_name)
        assert 0 <= value < 2**bits, (field_name, value)
        packed |= value << offset
        offset += bits
    return word(packed)


def packed_words():
    out = {}
    for key, (_, _, fields, ordinary) in PACKED.items():
        maximum = tuple(3 if f == "ck_prefix" else U48_MAX for f in fields)
        out[key] = [
            {**dict(zip(fields, values)), "word": pack(fields, values)}
            for values in (ordinary, maximum)
        ]
    return decimals(out)


def origin_words():
    """Slot 290 origins: (startHeight, l1BlockNumber, l1Timestamp), one full word each."""
    fields = ("start_height", "l1_block_number", "l1_timestamp")
    cases = ((0, (0, 19_000_000, 1_700_000_000)), (1, (U48_MAX, U48_MAX, U48_MAX)))
    return decimals(
        [{"generation": generation, **dict(zip(fields, values))} for generation, values in cases]
    )


INBOX_SLOTS = {
    "initialization_status": 258,
    "recovery_generation": 268,
    "committee_config_hash": 269,
    "last_checkpoint_height": 270,
    "last_checkpoint_hash": 271,
    "genesis_packed": 272,
    "genesis_block_hash": 273,
    "genesis_state_root": 274,
    "genesis_committee_record_hash": 278,
    "genesis_cutoff": 279,
    "forced_inclusion_queue": 280,
    "forced_inclusion_head_tail": 281,
    "forced_inclusion_config": 282,
    "active_committee_snapshot": 284,
    "landings": 285,
    "origins": 290,
}
RESERVED_SLOTS = (283, 286, 287, 288, 289, 291)
ANCHOR_SLOTS = (268, 270, 271, 281)


def mapping_slots(key, slot, count):
    first = int(cast("index", "uint256", key, slot), 16)
    return [word(first + w) for w in range(count)]


def layout():
    """The node-facing storage layout of the Inbox and the staking registry (appendix B)."""
    base = cast("index-erc7201", "taiko.etna.registry")
    base_int = int(base, 16)
    checkpoint_data = int(keccak(base), 16)
    entries_slot = word(base_int + 1)
    entry_data = int(keccak(entries_slot), 16)

    def cp(i):
        return checkpoint_data + 2 * i

    def namespace(name):
        ns_base = cast("index-erc7201", name)
        return {
            "namespace": name,
            "base": ns_base,
            "slots": [
                {"bond_id": bond_id, "slot": cast("index", "uint256", bond_id, ns_base)}
                for bond_id in (0, 4095)
            ],
        }

    inbox = {
        "slots": INBOX_SLOTS,
        "reserved_slots": list(RESERVED_SLOTS),
        "packing": packing("inbox"),
        "initialized_status": 3,
        "anchor_slots": list(ANCHOR_SLOTS),
        "forced_inclusion_entry_slots": [
            {"index": i, "slots": mapping_slots(i, INBOX_SLOTS["forced_inclusion_queue"], 2)}
            for i in (0, 7)
        ],
        "landing_slots": [
            {"height": h, "slots": mapping_slots(h, INBOX_SLOTS["landings"], 3)}
            for h in (0, 6, 18)
        ],
        "origin_slots": [
            {"generation": g, "slots": mapping_slots(g, INBOX_SLOTS["origins"], 3)}
            for g in (0, 1)
        ],
    }
    registry = {
        "namespace": "taiko.etna.registry",
        "base": base,
        "checkpoints_slot": base,
        "entries_slot": entries_slot,
        "no_exit": NO_EXIT,
        "packing": packing("registry"),
        "checkpoint_slots": [
            {"index": i, "slots": [word(cp(i) + w) for w in range(2)]} for i in (0, 1, 5)
        ],
        "entry_slots": [
            {"index": j, "slots": [word(entry_data + 3 * j + w) for w in range(3)]}
            for j in (0, 1, 4095)
        ],
        "snapshot_slots": [
            {
                "index": i,
                "has_next": has_next,
                "slots": [base, word(cp(i)), word(cp(i) + 1)]
                + ([word(cp(i + 1))] if has_next else []),
            }
            for i, has_next in ((0, False), (0, True), (3, True))
        ],
        "owners": namespace("taiko.etna.registry.owners"),
        "exit_confirmations": namespace("taiko.etna.registry.exit-confirmations"),
    }
    return decimals({"inbox": inbox, "registry": registry})


def main():
    key_list = keys()
    config = committee_config()
    entries = registry_entries(key_list)
    cut_vectors = cuts()
    statements = land_statements(config, cut_vectors)
    vectors = {
        "schema_version": "4",
        "deployment": deployment(),
        "keys": key_list,
        "committee_config": config,
        "registry_entries": entries,
        "committee_sets": committee_sets(entries["entries"], config),
        "cuts": cut_vectors,
        "land_statements": statements,
        "land_abi": land_abi(statements),
        "chain_domains": chain_domains(),
        "extra_data": extra_data(),
        "packed_words": packed_words(),
        "origin_words": origin_words(),
        "layout": layout(),
    }
    OUTPUT.write_text(json.dumps(vectors, indent=2) + "\n")
    subprocess.run(["pnpm", "exec", "prettier", "--write", str(OUTPUT)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
