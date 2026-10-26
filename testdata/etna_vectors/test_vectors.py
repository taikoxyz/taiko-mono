#!/usr/bin/env python3
"""Structural checks of vectors.json against the Etna spec's appendix A (encodings) and B (storage).

Run from the repository root (standard library only; no `cast`, `go` or network):

    python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v

`generate.py` computes every hash and slot with `cast`. These tests decode the generated preimages
and words and check what can be checked without keccak: word order and count, field widths and
packing offsets, the 48-byte chain id, key compression, and the shape of each case.
"""

import base64
import json
import pathlib
import unittest

V = json.loads((pathlib.Path(__file__).resolve().parent / "vectors.json").read_text())

K = 6
U48_MAX = 2**48 - 1
SECP_P = 2**256 - 2**32 - 977
KECCAK_EMPTY = "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
CHAIN_ID_ALPHABET = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")


def hexbytes(value):
    assert value.startswith("0x"), value
    return bytes.fromhex(value[2:])


def words(value):
    data = hexbytes(value)
    assert len(data) % 32 == 0, value
    return ["0x" + data[i : i + 32].hex() for i in range(0, len(data), 32)]


def word(value, index):
    return words(value)[index]


def tag(name):
    """A right-zero-padded `bytes32` ASCII domain tag."""
    return "0x" + name.encode().ljust(32, b"\0").hex()


def uint(value):
    return "0x" + format(int(value), "064x")


def address(value):
    return "0x" + hexbytes(value).rjust(32, b"\0").hex()


def by_name(cases, name):
    matches = [case for case in cases if case["name"] == name]
    assert len(matches) == 1, name
    return matches[0]


class VectorsTest(unittest.TestCase):
    def test_schema_version_is_4(self):
        self.assertEqual(V["schema_version"], "4")

    def test_deployment(self):
        self.assertEqual(
            V["deployment"],
            {
                "l1_chain_id": "1",
                "l2_chain_id": "167001",
                "inbox": "0x1111111111111111111111111111111111111111",
                "registry": "0x2222222222222222222222222222222222222222",
                "l2_block_gas_limit": "45000000",
            },
        )

    def test_config_is_seven_words(self):
        cfg = V["committee_config"]
        inputs = cfg["inputs"]
        self.assertEqual(len(hexbytes(cfg["preimage"])), 224)
        self.assertEqual(inputs["tag"], "ETNA_PARENT_ANCHOR_V1")
        self.assertEqual(inputs["unsettled_limit"], "3600")
        self.assertEqual(inputs["registry"], V["deployment"]["registry"])
        self.assertEqual(
            words(cfg["preimage"]),
            [
                tag("ETNA_PARENT_ANCHOR_V1"),
                uint(inputs["l2_chain_id"]),
                address(inputs["registry"]),
                uint(inputs["vp_unit"]),
                uint(inputs["s_min"]),
                uint(inputs["n_max"]),
                uint(inputs["unsettled_limit"]),
            ],
        )

    def test_statements_are_21_words(self):
        statements = V["land_statements"]
        self.assertEqual([s["name"] for s in statements], ["genesis", "nonzero"])
        for statement in statements:
            inputs = statement["inputs"]
            p, h = int(inputs["parent_height"]), int(inputs["last_height"])
            self.assertEqual(len(hexbytes(statement["preimage"])), 672)
            self.assertEqual(p % K, 0)
            self.assertEqual(h % K, 0)
            self.assertEqual(word(statement["preimage"], 0), tag("TAIKO_ETNA_LAND_V1"))
            self.assertEqual(word(statement["preimage"], 20), inputs["cut_hash"])
            self.assertEqual(inputs["committee_config_hash"], V["committee_config"]["hash"])
            cut = [
                c
                for c in V["cuts"]["cut_hashes"]
                if (int(c["generation"]), int(c["parent_height"]), int(c["last_height"]))
                == (int(inputs["generation"]), p, h)
            ]
            self.assertEqual(len(cut), 1)
            self.assertEqual(inputs["cut_hash"], cut[0]["cut_hash"])
            self.assertEqual(
                words(statement["preimage"]),
                [
                    tag(inputs["tag"]),
                    uint(inputs["l1_chain_id"]),
                    uint(inputs["l2_chain_id"]),
                    address(inputs["inbox"]),
                    address(inputs["registry"]),
                    uint(inputs["generation"]),
                    uint(p),
                    inputs["parent_hash"],
                    inputs["parent_comet_hash"],
                    inputs["committee_config_hash"],
                    uint(h),
                    inputs["last_block_hash"],
                    inputs["last_comet_hash"],
                    inputs["last_state_root"],
                    uint(inputs["l1_reference_block_number"]),
                    inputs["l1_reference_block_hash"],
                    statement["blob_hashes_hash"],
                    uint(inputs["forced_inclusion_head_before"]),
                    uint(inputs["forced_inclusion_head_after"]),
                    uint(inputs["active_committee_snapshot"]),
                    inputs["cut_hash"],
                ],
            )
            for blob in inputs["blob_hashes"]:
                self.assertEqual(len(hexbytes(blob)), 32)
                self.assertEqual(hexbytes(blob)[0], 0x01)

    def test_cut_leaves_are_four_words(self):
        table = V["cuts"]["table"]
        self.assertEqual([int(c["height"]) for c in table], list(range(19)))
        for cut in table:
            x = int(cut["height"])
            self.assertEqual(len(hexbytes(cut["preimage"])), 128)
            self.assertEqual(int(cut["forced_head"]), x // K)
            self.assertEqual(cut["block_hash"], uint(100 + x))
            self.assertEqual(cut["comet_hash"], uint(0 if x == 0 else 200 + x))
            self.assertEqual(
                words(cut["preimage"]),
                [uint(x), cut["block_hash"], cut["comet_hash"], uint(cut["forced_head"])],
            )

    def test_empty_cut_list_hashes_empty_string(self):
        empty = [
            c
            for c in V["cuts"]["cut_hashes"]
            if int(c["last_height"]) == int(c["parent_height"]) + K
        ]
        self.assertTrue(empty)
        for case in empty:
            self.assertEqual(case["leaves"], [])
            self.assertEqual(case["leaves_hash"], KECCAK_EMPTY)

    def test_cut_hash_leaf_count(self):
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        cases = V["cuts"]["cut_hashes"]
        self.assertEqual(
            [(int(c["generation"]), int(c["parent_height"]), int(c["last_height"])) for c in cases],
            [(0, 0, 6), (0, 0, 12), (0, 0, 18), (1, 6, 18), (0, 0, 300)],
        )
        for case in cases:
            p, h = int(case["parent_height"]), int(case["last_height"])
            self.assertEqual(len(case["leaves"]), (h - p) // K - 1)
            self.assertEqual(len(hexbytes(case["preimage"])), 160)
            self.assertEqual(
                words(case["preimage"]),
                [
                    tag("ETNA_LAND_CUTS_V1"),
                    uint(case["generation"]),
                    uint(p),
                    uint(h),
                    case["leaves_hash"],
                ],
            )
            for index, leaf in enumerate(case["leaves"]):
                height = p + K * (index + 1)
                if height in table:
                    self.assertEqual(leaf, table[height])
        self.assertEqual(len(cases[-1]["leaves"]), 49)

    def test_chain_ids_are_48_ascii_bytes(self):
        domains = V["chain_domains"]
        inbox = V["deployment"]["inbox"]
        self.assertEqual(
            [(d["inbox"], int(d["generation"])) for d in domains],
            [(inbox, 0), (inbox, 1), (inbox, 2), (inbox, U48_MAX), ("0x" + "33" * 20, 0)],
        )
        chain_ids = set()
        for domain in domains:
            chain_id = domain["chain_id"]
            self.assertTrue(chain_id.startswith("etna-"))
            self.assertEqual(len(chain_id.encode("ascii")), 48)
            rest = chain_id[len("etna-") :]
            self.assertTrue(set(rest) <= CHAIN_ID_ALPHABET)
            self.assertEqual(base64.urlsafe_b64decode(rest + "="), hexbytes(domain["chain_domain"]))
            self.assertEqual(
                words(domain["preimage"]),
                [
                    tag("ETNA_COMET_DOMAIN_V1"),
                    uint(domain["l1_chain_id"]),
                    uint(domain["l2_chain_id"]),
                    address(domain["inbox"]),
                    uint(domain["generation"]),
                ],
            )
            chain_ids.add(chain_id)
        self.assertEqual(len(chain_ids), len(domains))

    def test_extra_data_is_13_bytes(self):
        cases = V["extra_data"]
        self.assertEqual(
            [(int(c["generation"]), int(c["anchor_number"])) for c in cases],
            [(0, 0), (5, 7), (U48_MAX, U48_MAX)],
        )
        for case in cases:
            data = hexbytes(case["extra_data"])
            self.assertEqual(len(data), 13)
            self.assertEqual(data[0], 0x64)
            self.assertEqual(int.from_bytes(data[1:7], "big"), int(case["generation"]))
            self.assertEqual(int.from_bytes(data[7:13], "big"), int(case["anchor_number"]))
        self.assertEqual(cases[1]["extra_data"], "0x64000000000005000000000007")

    def test_packed_words_decode_to_inputs(self):
        packing = {
            "inbox_272": V["layout"]["inbox"]["packing"]["genesis_packed"],
            "inbox_280_word2": V["layout"]["inbox"]["packing"]["forced_inclusion_entry_word2"],
            "inbox_281": V["layout"]["inbox"]["packing"]["forced_inclusion_head_tail"],
            "inbox_282": V["layout"]["inbox"]["packing"]["forced_inclusion_config"],
            "inbox_285_word1": V["layout"]["inbox"]["packing"]["landing_word1"],
            "registry_checkpoint_word1": V["layout"]["registry"]["packing"]["checkpoint_word1"],
            "registry_entry_word3": V["layout"]["registry"]["packing"]["entry_word3"],
        }
        self.assertEqual(set(V["packed_words"]), set(packing))
        for kind, items in V["packed_words"].items():
            fields = packing[kind]
            # Fields sit in the listed order from bit 0: ckPrefix 8 bits, everything else 48.
            offset = 0
            for name, lane in fields.items():
                self.assertEqual(int(lane["offset"]), offset, (kind, name))
                self.assertEqual(int(lane["bits"]), 8 if name == "ck_prefix" else 48, (kind, name))
                offset += int(lane["bits"])
            self.assertGreaterEqual(len(items), 2, kind)
            saw_max = False
            for item in items:
                self.assertEqual(list(item), [*fields, "word"], kind)
                value = int(item["word"], 16)
                self.assertEqual(len(hexbytes(item["word"])), 32)
                for name, lane in fields.items():
                    bits = int(lane["bits"])
                    lane_value = (value >> int(lane["offset"])) & ((1 << bits) - 1)
                    self.assertEqual(lane_value, int(item[name]), (kind, name))
                self.assertEqual(value >> offset, 0, kind)
                saw_max |= all(
                    int(item[name]) == (3 if name == "ck_prefix" else U48_MAX) for name in fields
                )
            self.assertTrue(saw_max, kind)

    def test_origin_words_are_three_full_words(self):
        origins = V["origin_words"]
        self.assertEqual([int(o["generation"]) for o in origins], [0, 1])
        for origin in origins:
            self.assertEqual(
                list(origin), ["generation", "start_height", "l1_block_number", "l1_timestamp"]
            )
            for name in ("start_height", "l1_block_number", "l1_timestamp"):
                self.assertLessEqual(int(origin[name]), U48_MAX)
        fields = ("start_height", "l1_block_number", "l1_timestamp")
        self.assertTrue(any(all(int(o[n]) == U48_MAX for n in fields) for o in origins))

    def test_layout_anchor_and_reserved_slots(self):
        inbox = V["layout"]["inbox"]
        self.assertEqual(inbox["anchor_slots"], ["268", "270", "271", "281"])
        self.assertEqual(inbox["reserved_slots"], ["283", "286", "287", "288", "289", "291"])
        self.assertEqual(inbox["initialized_status"], "3")
        self.assertEqual(
            inbox["slots"],
            {
                "initialization_status": "258",
                "recovery_generation": "268",
                "committee_config_hash": "269",
                "last_checkpoint_height": "270",
                "last_checkpoint_hash": "271",
                "genesis_packed": "272",
                "genesis_block_hash": "273",
                "genesis_state_root": "274",
                "genesis_committee_record_hash": "278",
                "genesis_cutoff": "279",
                "forced_inclusion_queue": "280",
                "forced_inclusion_head_tail": "281",
                "forced_inclusion_config": "282",
                "active_committee_snapshot": "284",
                "landings": "285",
                "origins": "290",
            },
        )
        used = set(inbox["slots"].values())
        self.assertFalse(used & set(inbox["reserved_slots"]))

    def test_layout_mapping_slots_are_consecutive(self):
        inbox = V["layout"]["inbox"]
        for key, field, count, ids in (
            ("forced_inclusion_entry_slots", "index", 2, ["0", "7"]),
            ("landing_slots", "height", 3, ["0", "6", "18"]),
            ("origin_slots", "generation", 3, ["0", "1"]),
        ):
            self.assertEqual([item[field] for item in inbox[key]], ids, key)
            for item in inbox[key]:
                slots = [int(s, 16) for s in item["slots"]]
                self.assertEqual(len(slots), count, key)
                self.assertEqual(slots, [slots[0] + w for w in range(count)], key)

    def test_registry_entries_have_three_words(self):
        registry = V["layout"]["registry"]
        base = int(registry["base"], 16)
        self.assertEqual(registry["namespace"], "taiko.etna.registry")
        self.assertEqual(registry["no_exit"], str(U48_MAX))
        self.assertEqual(int(registry["checkpoints_slot"], 16), base)
        self.assertEqual(int(registry["entries_slot"], 16), base + 1)
        self.assertEqual(base & 0xFF, 0)  # ERC-7201 clears the low byte

        entries = registry["entry_slots"]
        self.assertEqual([e["index"] for e in entries], ["0", "1", "4095"])
        entry_data = int(entries[0]["slots"][0], 16)
        for entry in entries:
            slots = [int(s, 16) for s in entry["slots"]]
            self.assertEqual(slots, [entry_data + 3 * int(entry["index"]) + w for w in range(3)])

        checkpoints = registry["checkpoint_slots"]
        self.assertEqual([c["index"] for c in checkpoints], ["0", "1", "5"])
        checkpoint_data = int(checkpoints[0]["slots"][0], 16)
        for checkpoint in checkpoints:
            slots = [int(s, 16) for s in checkpoint["slots"]]
            self.assertEqual(
                slots, [checkpoint_data + 2 * int(checkpoint["index"]) + w for w in range(2)]
            )

        snapshots = registry["snapshot_slots"]
        self.assertEqual(
            [(s["index"], s["has_next"]) for s in snapshots],
            [("0", False), ("0", True), ("3", True)],
        )
        for snapshot in snapshots:
            cp = checkpoint_data + 2 * int(snapshot["index"])
            expected = [base, cp, cp + 1] + ([cp + 2] if snapshot["has_next"] else [])
            self.assertEqual([int(s, 16) for s in snapshot["slots"]], expected)

        for key, namespace in (
            ("owners", "taiko.etna.registry.owners"),
            ("exit_confirmations", "taiko.etna.registry.exit-confirmations"),
        ):
            self.assertEqual(registry[key]["namespace"], namespace)
            self.assertEqual(int(registry[key]["base"], 16) & 0xFF, 0)
            self.assertEqual([s["bond_id"] for s in registry[key]["slots"]], ["0", "4095"])

    def test_registry_entries_match_keys(self):
        reg = V["registry_entries"]
        self.assertEqual(len(reg["entries"]), 5)
        self.assertEqual(len(reg["leaves"]), 5)
        for i, (entry, key) in enumerate(zip(reg["entries"], V["keys"])):
            self.assertEqual(entry["ck_prefix"], key["ck_prefix"])
            self.assertEqual(entry["ck_x"], key["ck_x"])
            self.assertEqual(int(entry["eff_stake"]), (i + 1) * 10**18)
            self.assertEqual(int(entry["active_from_l1"]), 10 + i)
            self.assertEqual(int(entry["exit_effective_l1"]), 1000 + i if i % 2 else U48_MAX)
        roots = reg["roots"]
        self.assertEqual([int(r["count"]) for r in roots], list(range(7)))
        self.assertEqual(roots[0]["entries_root"], uint(0))
        self.assertEqual(roots[1]["entries_root"], reg["leaves"][0])

    def test_released_leaf_uses_zero_fields(self):
        released = V["registry_entries"]["released"]
        self.assertEqual(released["index"], "5")
        self.assertEqual(len(hexbytes(released["leaf"])), 32)
        self.assertNotEqual(released["leaf"], uint(0))
        self.assertNotIn(released["leaf"], V["registry_entries"]["leaves"])

    def test_keys_compress_to_33_bytes(self):
        keys = V["keys"]
        self.assertEqual(
            [k["name"] for k in keys], ["a1", "a2", "a3", "a4", "a5", "leading_zero_x"]
        )
        for i, key in enumerate(keys[:5]):
            self.assertEqual(int(key["private_key"], 16), 0xA1 + i)
        for key in keys:
            x, y = int(key["ck_x"], 16), int(key["ck_y"], 16)
            prefix = 2 + (y & 1)
            public_key = hexbytes(key["public_key"])
            self.assertEqual(int(key["ck_prefix"]), prefix)
            self.assertEqual(len(public_key), 33)
            self.assertEqual(public_key, bytes([prefix]) + hexbytes(key["ck_x"]))
            self.assertEqual(len(hexbytes(key["ck_x"])), 32)
            self.assertEqual(len(hexbytes(key["ck_y"])), 32)
            self.assertEqual(len(hexbytes(key["ck_addr"])), 20)
            self.assertEqual(len(hexbytes(key["entry_key"])), 32)
            self.assertEqual((y * y - x * x * x - 7) % SECP_P, 0)
        lead = keys[-1]
        self.assertEqual(hexbytes(lead["ck_x"])[0], 0)
        self.assertEqual(hexbytes(lead["public_key"])[1], 0)

    def test_committee_sets_match_appendix_a(self):
        cases = V["committee_sets"]
        self.assertEqual([len(c["members"]) for c in cases], [0, 1, 3, 5])
        # Spec 4.3 step 4: an empty committee is rejected, so it has no root or record.
        self.assertEqual(cases[0], {"members": [], "valid": False, "reason": "empty_committee"})
        vp_unit = int(V["committee_config"]["inputs"]["vp_unit"])
        for case in cases[1:]:
            self.assertTrue(case["valid"])
            k = int(case["target_epoch"]) + 1
            self.assertEqual(int(case["set_version"]), k)
            members = case["members"]
            set_keys = [int(m["set_key"], 16) for m in members]
            self.assertEqual(set_keys, sorted(set_keys))
            for i, member in enumerate(members):
                self.assertEqual(int(member["power"]), int(member["eff_stake"]) // vp_unit)
                self.assertEqual(
                    words(case["set_leaf_preimages"][i]),
                    [
                        tag("ETNA_SET_LEAF_V1"),
                        uint(case["l2_chain_id"]),
                        uint(k),
                        uint(i),
                        uint(member["ck_prefix"]),
                        member["ck_x"],
                        uint(member["eff_stake"]),
                        uint(member["power"]),
                    ],
                )
            self.assertEqual(len(case["set_leaves"]), len(members))
            self.assertEqual(int(case["total_power"]), sum(int(m["power"]) for m in members))
            if len(members) == 1:
                self.assertEqual(case["set_root"], case["set_leaves"][0])
            self.assertEqual(
                words(case["record_preimage"]),
                [
                    tag("ETNA_COMMITTEE_V1"),
                    uint(case["l2_chain_id"]),
                    uint(case["target_epoch"]),
                    uint(case["cutoff_l1_block"]),
                    uint(case["checkpoint_index"]),
                    case["set_root"],
                    uint(case["total_power"]),
                ],
            )

    def test_land_abi_encodes_the_nonzero_statement(self):
        abi = V["land_abi"]
        self.assertEqual(
            abi["signature"],
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256,uint256),bytes32[],bytes)",
        )
        self.assertEqual(abi["statement"], "nonzero")
        inputs = by_name(V["land_statements"], "nonzero")["inputs"]
        table = {int(c["height"]): c["leaf"] for c in V["cuts"]["table"]}
        self.assertEqual(abi["leaves"], [table[12]])
        self.assertEqual(abi["proof"], "0x00")
        calldata = hexbytes(abi["calldata"])
        self.assertEqual(calldata[:4], hexbytes(abi["selector"]))
        self.assertEqual(
            ["0x" + calldata[4 + 32 * i : 36 + 32 * i].hex() for i in range(8)],
            [
                uint(inputs["parent_height"]),
                uint(inputs["last_height"]),
                inputs["last_block_hash"],
                inputs["last_comet_hash"],
                inputs["last_state_root"],
                uint(inputs["l1_reference_block_number"]),
                uint(inputs["forced_inclusion_head_after"]),
                uint(inputs["active_committee_snapshot"]),
            ],
        )


if __name__ == "__main__":
    unittest.main()
