"""Current positional Registry encoding and recovery-snapshot regression cases."""
from copy import deepcopy
import hashlib
import importlib
import json
import tempfile
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
CONFORMANCE = ROOT / "formal/etna/conformance"
sys.path.insert(0, str(CONFORMANCE))
from run_comet_apphash import keccak256

Q = 10**23
NO_EXIT = 2**48 - 1
MAX_POWER = (2**63 - 1) // 8
CHAIN_ID = 167001
# Public curve points only; there are no signing or secret-key inputs.
KEY_A = (2, 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798)
KEY_B = (2, 0xC6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5)
KEY_C = (2, 0xF9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9)
EMPTY = (0, 0, 0, 0, 0)


def entry(key, eff=4 * Q, active=2, exit_at=NO_EXIT):
    return (*key, eff, active, exit_at)


def word(value):
    return value.to_bytes(32, "big")


def tagged(tag, fields):
    """ENC-A-5 bytes32 tag and static words, independent of the producer."""
    return tag.encode("ascii").ljust(32, b"\0") + b"".join(word(v) for v in fields)


def leaf(position, row):
    return keccak256(tagged("ETNA_REG_ENTRY_V1", (position, *row)))


def set_key(key, chain_id=CHAIN_ID):
    return keccak256(tagged("ETNA_SET_KEY_V1", (chain_id, *key)))


def literal_root(rows):
    nodes = [leaf(i, row) for i, row in enumerate(rows)]
    if not nodes:
        return bytes(32)
    width = 1 << (len(nodes) - 1).bit_length()
    nodes.extend([bytes(32)] * (width - len(nodes)))
    while len(nodes) > 1:
        nodes = [keccak256(nodes[i] + nodes[i + 1]) for i in range(0, len(nodes), 2)]
    return nodes[0]


class RegistrySnapshotEncoding(unittest.TestCase):
    def module(self):
        self.assertTrue((CONFORMANCE / "registry_snapshot.py").is_file(),
                        "positional Registry snapshot producer is missing")
        return importlib.import_module("registry_snapshot")

    def test_internal_hole_preserves_slot_one_and_authenticated_width(self):
        producer = self.module()
        rows = (EMPTY, entry(KEY_B))
        expected = keccak256(leaf(0, EMPTY) + leaf(1, rows[1]))
        self.assertEqual(producer.entries_root(rows, 2), expected)
        self.assertNotEqual(expected, leaf(0, rows[1]))
        self.assertNotEqual(expected, keccak256(bytes(32) + leaf(1, rows[1])))

    def test_checkpoint_packs_block_then_width_from_least_significant_bits(self):
        producer = self.module()
        rows = (EMPTY, entry(KEY_B))
        encoded = producer.encode_checkpoint(5, 2, rows)
        self.assertEqual(encoded, word(5 | (2 << 48)) + literal_root(rows))
        self.assertEqual(len(encoded), 64)

    def test_true_padding_is_raw_zero_not_a_hashed_empty_slot(self):
        producer = self.module()
        rows = (entry(KEY_A), EMPTY, entry(KEY_C))
        expected = keccak256(keccak256(leaf(0, rows[0]) + leaf(1, EMPTY))
                             + keccak256(leaf(2, rows[2]) + bytes(32)))
        self.assertEqual(producer.entries_root(rows, 3), expected)
        self.assertNotEqual(expected, producer.entries_root((*rows, EMPTY), 4))

    def test_zero_width_and_single_entry_have_the_specified_roots(self):
        producer = self.module()
        self.assertEqual(producer.entries_root((), 0), bytes(32))
        self.assertEqual(producer.entries_root((entry(KEY_A),), 1), leaf(0, entry(KEY_A)))

    def test_width_cannot_be_inferred_from_occupied_count(self):
        producer = self.module()
        rows = (EMPTY, entry(KEY_B))
        for width in (0, 1, 3, True, 4097, -1):
            with self.subTest(width=width), self.assertRaises((ValueError, TypeError)):
                producer.entries_root(rows, width)

    def test_fixed_width_integer_fields_do_not_truncate_or_accept_bool(self):
        producer = self.module()
        for at in (-1, 2**48, True):
            with self.subTest(at=at), self.assertRaises((ValueError, TypeError)):
                producer.encode_checkpoint(at, 1, (entry(KEY_A),))
        for index, value in ((0, 256), (1, 2**256), (2, 2**256), (3, 2**48), (4, -1), (3, True)):
            row = list(entry(KEY_A))
            row[index] = value
            with self.subTest(index=index, value=value), self.assertRaises((ValueError, TypeError)):
                producer.entries_root((tuple(row),), 1)

    def test_entries_are_closed_positional_tuples(self):
        producer = self.module()
        for rows in ([entry(KEY_A)], ((2, 1, 4 * Q, 2),), ((0, 0, 1, 0, 0),)):
            with self.subTest(rows=rows), self.assertRaises((ValueError, TypeError)):
                producer.entries_root(rows, 1)


class RegistrySnapshotSelection(unittest.TestCase):
    def module(self):
        self.assertTrue((CONFORMANCE / "registry_snapshot.py").is_file(),
                        "positional Registry snapshot producer is missing")
        return importlib.import_module("registry_snapshot")

    def select(self, rows, *, snapshot=7, s_min=4 * Q, vp_unit=2 * Q, n_max=2):
        return self.module().select_committee(rows, snapshot, s_min, vp_unit, n_max, CHAIN_ID)

    def test_eff_three_is_ineligible_while_eff_four_has_power_two(self):
        rows = (entry(KEY_A, 3 * Q), entry(KEY_B, 4 * Q))
        self.assertEqual(self.select(rows), ((*KEY_B, 4 * Q, 2),))

    def test_voting_unit_is_an_independent_eligibility_threshold(self):
        rows = (entry(KEY_A, 3 * Q), entry(KEY_B, 4 * Q))
        self.assertEqual(self.select(rows, s_min=2 * Q, vp_unit=4 * Q), ((*KEY_B, 4 * Q, 1),))

    def test_active_and_exit_boundaries_use_snapshot_not_live_time(self):
        rows = (entry(KEY_A, active=7, exit_at=8), entry(KEY_B, active=8))
        self.assertEqual(self.select(rows, snapshot=7), ((*KEY_A, 4 * Q, 2),))
        self.assertEqual(self.select(rows, snapshot=8), ((*KEY_B, 4 * Q, 2),))

    def test_equal_stake_is_ranked_by_set_key_not_slot_or_compressed_key(self):
        ordered = tuple(sorted((KEY_A, KEY_B, KEY_C), key=set_key))
        # Largest set key is in the first slot; smallest in the last slot.
        rows = tuple(entry(key) for key in reversed(ordered))
        self.assertEqual(self.select(rows, n_max=1), ((*ordered[0], 4 * Q, 2),))

    def test_rank_selection_then_output_set_key_order_are_separate(self):
        keys = tuple(sorted((KEY_A, KEY_B, KEY_C), key=set_key))
        rows = (entry(keys[2], 7 * Q), entry(keys[0], 5 * Q), entry(keys[1], 6 * Q))
        self.assertEqual(self.select(rows), ((*keys[1], 6 * Q, 3), (*keys[2], 7 * Q, 3)))

    def test_floor_power_is_not_ceil_or_raw_stake(self):
        self.assertEqual(self.select((entry(KEY_C, 5 * Q),)), ((*KEY_C, 5 * Q, 2),))

    def test_duplicate_eligible_keys_are_invalid_not_added_power(self):
        with self.assertRaises(ValueError):
            self.select((entry(KEY_A), entry(KEY_A, 5 * Q)))

    def test_empty_or_overflowing_committee_is_rejected_without_scaling(self):
        for rows, unit in (((EMPTY,), 2 * Q), ((entry(KEY_A, MAX_POWER + 1),), 1)):
            with self.subTest(rows=rows, unit=unit), self.assertRaises(ValueError):
                self.select(rows, s_min=1, vp_unit=unit)

    def test_selection_rejects_bool_and_nonpositive_parameters(self):
        for values in ((True, 4 * Q, 2 * Q, 1, CHAIN_ID),
                       (7, 4 * Q, 0, 1, CHAIN_ID), (7, 4 * Q, 2 * Q, 0, CHAIN_ID),
                       (7, 4 * Q, 2 * Q, 1, True)):
            with self.subTest(values=values), self.assertRaises((ValueError, TypeError)):
                self.module().select_committee((entry(KEY_A),), *values)




def dynamic_anti_vector(tag, fields):
    label = tag.encode("ascii")
    return (word(32 * (len(fields) + 1)) + b"".join(word(v) for v in fields)
            + word(len(label)) + label + bytes(-len(label) % 32))


class RegistrySnapshotDomainTags(unittest.TestCase):
    def module(self):
        return importlib.import_module("registry_snapshot")

    def test_regleaf_preimage_is_224_static_bytes_without_offset_or_tail(self):
        row = entry(KEY_A)
        fields = (0, *row)
        literal = b"ETNA_REG_ENTRY_V1".ljust(32, b"\0") + b"".join(map(word, fields))
        self.assertEqual(len(literal), 224)
        self.assertEqual(tagged("ETNA_REG_ENTRY_V1", fields), literal)
        root = self.module().entries_root((row,), 1)
        self.assertEqual(root, keccak256(literal))
        self.assertNotEqual(root, keccak256(dynamic_anti_vector("ETNA_REG_ENTRY_V1", fields)))

    def test_set_key_preimage_is_128_static_bytes_and_changes_actual_tie_ranking(self):
        keys = (KEY_A, KEY_B, KEY_C)
        discriminators = 0
        for chain in (1, 2, 17, CHAIN_ID):
            def literal(key):
                return b"ETNA_SET_KEY_V1".ljust(32, b"\0") + word(chain) + word(key[0]) + word(key[1])
            self.assertEqual(len(literal(KEY_A)), 128)
            correct = min(keys, key=lambda key: keccak256(literal(key)))
            old = min(keys, key=lambda key: keccak256(dynamic_anti_vector("ETNA_SET_KEY_V1", (chain, *key))))
            discriminators += correct != old
            with self.subTest(chain=chain):
                selected = self.module().select_committee(tuple(entry(key) for key in keys), 7,
                                                          4 * Q, 2 * Q, 1, chain)
                self.assertEqual(selected, ((*correct, 4 * Q, 2),))
        self.assertGreaterEqual(discriminators, 1, "literal dynamic anti-vector must distinguish a rank")

    def test_entry_storage_prefix_is_lowest_byte_then_two_48bit_blocks(self):
        row = entry(KEY_B, 5 * Q, active=7, exit_at=123)
        expected = word(KEY_B[1]) + word(5 * Q) + word(KEY_B[0] | (7 << 8) | (123 << 56))
        self.assertEqual(self.module().encode_entry(row), expected)
        self.assertEqual(self.module().encode_entry(EMPTY), bytes(96))


def empty_bond():
    return dict(issued=False, withdrawn=False, key=-1, owner=0, eff=0, pending=0,
                ready=0, active=0, exit=0, confirmed=0, holds=False, slot=-1)


def empty_row():
    return dict(key=-1, eff=0, active=0, exit=0)


def sample(route="main", recover_first=True):
    """Literal selected lifecycle fixture; uses no producer semantic helpers."""
    blank = dict(at=0, checkpointAt=0, width=2, entries=(empty_row(), empty_row()))
    state = dict(now=1, nextId=0, slots=(-1, -1), bonds=tuple(empty_bond() for _ in range(4)),
                 keys=(False,) * 3, entryChangedAt=0, snapshots=tuple(deepcopy(blank) for _ in range(8)),
                 closed=(False,) * 8, activeSnapshot=0, generation=0, recoveryAt=0,
                 origin=dict(at=0, entries=(), members=()))
    marks = dict(invalid=(False,) * 3, badLand=False, transientHole=False, closedHole=False,
                 order=(), atomic=True)
    stages = [(deepcopy(state), dict(kind="init", args=(), accepted=True), deepcopy(marks))]

    def put(values, index, value):
        return values[:index] + (value,) + values[index + 1:]

    def current_entries():
        return tuple(empty_row() if identity == -1 else
                     {field: state["bonds"][identity][field] for field in ("key", "eff", "active", "exit")}
                     for identity in state["slots"])

    def append(kind, args=(), accepted=True):
        stages.append((deepcopy(state), dict(kind=kind, args=args, accepted=accepted), deepcopy(marks)))

    def register(identity):
        slot = state["slots"].index(-1)
        state["slots"] = put(state["slots"], slot, identity)
        state["bonds"] = put(state["bonds"], identity, dict(empty_bond(), issued=True, key=identity,
            owner=identity + 1, eff=4, active=state["now"] + 1, exit=11, holds=True, slot=slot))
        state["keys"] = put(state["keys"], identity, True)
        state.update(nextId=identity + 1, entryChangedAt=state["now"])
        append("register", (identity, identity + 1, identity, 4))

    def close():
        now = state["now"]
        rows = current_entries()
        cp = dict(at=now, checkpointAt=state["entryChangedAt"], width=2, entries=rows)
        state["snapshots"] = put(state["snapshots"], now - 1, cp)
        state["closed"] = put(state["closed"], now - 1, True)
        if now == 7:
            key = 2 if route == "main" else 1
            amount = 5 if route == "main" else 4
            state["origin"] = dict(at=7, entries=deepcopy(rows), members=(dict(key=key, eff=amount, power=2),))
        if now == 5 and rows[0]["key"] == -1:
            marks["closedHole"] = True
        append("close", (now,))

    def tick():
        state["now"] += 1
        append("tick")

    def topup(identity, amount):
        old = state["bonds"][identity]
        state["bonds"] = put(state["bonds"], identity, dict(old, pending=amount, ready=state["now"] + 1))
        append("topup", (identity, identity + 1, amount))

    def activate(identity):
        old = state["bonds"][identity]
        state["bonds"] = put(state["bonds"], identity, dict(old, eff=old["eff"] + old["pending"], pending=0, ready=0))
        state["entryChangedAt"] = state["now"]
        if state["now"] == 7:
            marks["order"] += ("activate",)
        append("activate", (identity, 4))

    register(0)
    register(1)
    close()
    tick()
    state["bonds"] = put(state["bonds"], 0, dict(state["bonds"][0], exit=3))
    state["entryChangedAt"] = 2
    append("exit", (0, 1))
    close()
    tick()
    close()
    tick()
    state["activeSnapshot"] = 3
    append("terminal-land", (3,))
    state["bonds"] = put(state["bonds"], 0, dict(state["bonds"][0], confirmed=4))
    append("confirm", (0, 4))
    close()
    tick()
    state["bonds"] = put(state["bonds"], 0, dict(state["bonds"][0], withdrawn=True, owner=0, eff=0,
        pending=0, ready=0, confirmed=0, holds=False, slot=-1))
    state.update(slots=(-1, 1), entryChangedAt=5)
    marks["transientHole"] = True
    append("withdraw", (0, 1))
    if route == "main":
        register(2)
    close()
    tick()
    if route == "main":
        topup(2, 1)
    else:
        register(2)
    close()
    tick()
    topup(1, 2) if route == "main" else topup(2, 1)
    lists = ((dict(bond=0, key=0),), (dict(bond=1, key=1), dict(bond=3, key=3)),
             (dict(bond=0, key=2),), (dict(bond=1, key=1), dict(bond=0, key=0)))
    for index in (2, 3, 4):
        marks["invalid"] = put(marks["invalid"], index - 2, True)
        append("recover", (index, lists[index - 1]), False)
    if not recover_first and route == "main":
        activate(2)
    state.update(generation=1, recoveryAt=7)
    marks["order"] += ("recover",)
    append("recover", (1, lists[0]))
    if recover_first and route == "main":
        activate(2)
    close()
    tick()
    activate(1 if route == "main" else 2)
    marks["badLand"] = True
    append("land", (8,), False)
    state["activeSnapshot"] = 7
    append("land", (7,))
    close()
    return stages


def tlc(value):
    if type(value) is bool:
        return "TRUE" if value else "FALSE"
    if type(value) is int:
        return str(value)
    if type(value) is str:
        return json.dumps(value)
    if type(value) is dict:
        return "[" + ", ".join(f"{key} |-> {tlc(term)}" for key, term in value.items()) + "]"
    if type(value) is tuple:
        return "<<" + ", ".join(map(tlc, value)) + ">>"
    raise TypeError(type(value))


def raw(stages):
    return "".join(f"State {index}: <fixture>\n/\\ s = {tlc(state)}\n/\\ receipt = {tlc(receipt)}\n/\\ marks = {tlc(marks)}\n"
                   for index, (state, receipt, marks) in enumerate(stages, 1))


class RegistrySnapshotHistories(unittest.TestCase):
    def audit(self, stages, case="progress"):
        return importlib.import_module("registry_snapshot").audit(raw(stages), case)

    def find(self, stages, kind, args=None):
        return next(index for index, (_, receipt, _) in enumerate(stages)
                    if receipt["kind"] == kind and (args is None or receipt["args"] == args))

    def test_full_main_history_uses_final_r_and_preserves_later_snapshot(self):
        events = self.audit(sample())
        self.assertEqual(events[-1]["post"]["origin"]["members"], (dict(key=2, eff=5, power=2),))
        closes = [event for event in events if event["kind"] == "close"]
        self.assertEqual(len(closes), 8)
        self.assertNotEqual(closes[6]["checkpoint"], closes[7]["checkpoint"])
        self.assertEqual(closes[7]["post"]["origin"], closes[6]["post"]["origin"])

    def test_same_r_activation_before_and_after_recover_agree_at_close(self):
        before = self.audit(sample(recover_first=False), "activate-first")[-1]["post"]
        after = self.audit(sample(), "recover-first")[-1]["post"]
        self.assertEqual(before["origin"], after["origin"])
        self.assertEqual(before["origin"]["members"][0]["eff"], 5)

    def test_transient_hole_and_authenticated_closed_hole_are_distinct_routes(self):
        main = self.audit(sample())[-1]
        alternate = self.audit(sample("closed-hole"), "closed-hole-progress")[-1]
        self.assertFalse(main["marks"]["closedHole"])
        self.assertTrue(alternate["marks"]["closedHole"])
        hole = alternate["post"]["snapshots"][4]
        self.assertEqual(hole["entries"][0], empty_row())
        self.assertEqual(hole["entries"][1]["key"], 1)
        self.assertEqual(hole["width"], 2)
        self.assertEqual(main["post"]["snapshots"][4]["entries"][0]["key"], 2)

    def test_unissued_last_list_item_rejects_the_entire_recovery(self):
        stages = sample()
        at = self.find(stages, "recover", (2, (dict(bond=1, key=1), dict(bond=3, key=3))))
        stages[at][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "recover decision"):
            self.audit(stages)

    def test_wrong_key_cannot_turn_withdrawn_bond_into_new_slot_occupant(self):
        stages = sample()
        at = self.find(stages, "recover", (3, (dict(bond=0, key=2),)))
        stages[at][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "recover decision"):
            self.audit(stages)

    def test_invalid_list_cannot_leak_a_valid_prefix_exit(self):
        stages = sample()
        at = self.find(stages, "recover", (2, (dict(bond=1, key=1), dict(bond=3, key=3))))
        stages[at][0]["bonds"][1]["exit"] = 7
        with self.assertRaisesRegex(ValueError, "recover complete post-state"):
            self.audit(stages)

    def test_recovery_cannot_capture_the_transaction_time_committee(self):
        stages = sample()
        at = self.find(stages, "recover", (1, (dict(bond=0, key=0),)))
        stages[at][0]["origin"] = dict(at=7, entries=(), members=(dict(key=1, eff=4, power=2),))
        with self.assertRaisesRegex(ValueError, "recover complete post-state"):
            self.audit(stages)

    def test_final_horizon_requires_the_actual_close_eight_action(self):
        with self.assertRaisesRegex(ValueError, "endpoint not reached"):
            self.audit(sample()[:-1])

    def test_later_live_entries_cannot_replace_the_closed_r_snapshot(self):
        stages = sample()
        stages[-1][0]["snapshots"][6]["entries"][1]["eff"] = 6
        with self.assertRaisesRegex(ValueError, "close complete post-state"):
            self.audit(stages)

    def test_landing_cannot_use_the_later_live_snapshot(self):
        stages = sample()
        at = self.find(stages, "land", (8,))
        stages[at][1]["accepted"] = True
        with self.assertRaisesRegex(ValueError, "land decision"):
            self.audit(stages)

    def test_recover_does_not_advance_landed_coverage_early(self):
        stages = sample()
        at = self.find(stages, "recover", (1, (dict(bond=0, key=0),)))
        stages[at][0]["activeSnapshot"] = 7
        with self.assertRaisesRegex(ValueError, "recover complete post-state"):
            self.audit(stages)

    def test_boolean_alias_in_external_list_is_not_an_issued_bond(self):
        stages = sample()
        at = self.find(stages, "recover", (1, (dict(bond=0, key=0),)))
        stages[at][1]["args"] = (1, (dict(bond=False, key=0),))
        with self.assertRaisesRegex(ValueError, "fixed external list"):
            self.audit(stages)

    def test_complete_init_and_observer_frames_are_bound(self):
        stages = sample()
        stages[0][0]["bonds"][3]["issued"] = True
        with self.assertRaisesRegex(ValueError, "Init differs"):
            self.audit(stages)
        stages = sample()
        stages[-1][2]["invalid"] = (False, True, True)
        with self.assertRaisesRegex(ValueError, "observer frame"):
            self.audit(stages)




class RegistrySnapshotReceiptParser(unittest.TestCase):
    def fixture(self, staged):
        producer = importlib.import_module("registry_snapshot")
        names = (producer.MODULE, "progress.cfg")
        formal = ROOT / "formal/etna"
        for name, source in ((names[0], formal / names[0]),
                             (names[1], formal / "products/registry-recovery-snapshot" / names[1])):
            (staged / name).write_bytes(source.read_bytes())
        # Parser fixture only, never evidence that Java or current-source selection ran.
        body = (producer.TLC_BANNER + "\nParsing file /tmp/etna-model/" + producer.MODULE + "\n"
                "Semantic processing of module EtnaRegistryRecoverySnapshot\n"
                "Error: Invariant NoProgress is violated.\nError: The behavior up to this point is:\n"
                + raw(sample()) + "100 states generated, 50 distinct states found, 4 states left on queue.\n"
                "The depth of the complete state graph search is 40.\n"
                "Finished in 00s at (2000-01-01 00:00:00)\n").encode()
        record = dict(schema="etna-registry-snapshot-execution-1", case="progress",
            argv=["/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
                  "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
                  "-deadlock", "-metadir", "/tmp/etna-out/states", "-config", "progress.cfg", producer.MODULE],
            cwd="/tmp/etna-model", returncode=12, timedOut=False, rawSha256=hashlib.sha256(body).hexdigest(),
            inputSha256={name: hashlib.sha256((staged / name).read_bytes()).hexdigest() for name in names})
        return producer, body, record

    def test_unchanged_parser_fixture_rejects_status_argv_domain_and_input_aliases(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            staged = Path(temporary)
            producer, body, record = self.fixture(staged)
            def consume(metadata=record, payload=body, **kwargs):
                return producer.current_receipt(ROOT, "progress", payload, staged_model=staged,
                                                execution=json.dumps(metadata).encode(), **kwargs)
            with patch.object(producer, "reviewed_boundary", return_value={}):
                self.assertEqual(consume()["outcome"], "NAMED_WITNESS_REPLAYED")
                changes = [dict(case="smoke"), dict(returncode=True), dict(timedOut=0), dict(cwd="/tmp/other"),
                           dict(rawSha256="0" * 64), dict(schema="other"), dict(inputSha256={})]
                for index, replacement in ((0, "/tmp/other-jre/bin/java"), (4, "/tmp/other.jar"),
                                           (12, "/tmp/other-states"), (14, "smoke.cfg")):
                    argv = record["argv"].copy()
                    argv[index] = replacement
                    changes.append(dict(argv=argv))
                changes.append(dict(argv=record["argv"] + ["-arbitrary"]))
                for change in changes:
                    with self.subTest(change=change), self.assertRaises(ValueError):
                        consume(dict(record, **change))
                with self.assertRaises(ValueError):
                    consume(expected_claim="funded-forfeiture")
                (staged / "progress.cfg").write_bytes(b"different")
                with self.assertRaisesRegex(ValueError, "staged source"):
                    consume()

    def test_native_fatal_diagnostic_cannot_be_hidden_by_a_valid_fixture_trailer(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            staged = Path(temporary)
            producer, body, record = self.fixture(staged)
            with patch.object(producer, "reviewed_boundary", return_value={}):
                for prefix in (b"java.lang.OutOfMemoryError: fixture\n", b"panic: fixture\n",
                               b'Exception in thread "main" java.lang.Error: fixture\n'):
                    payload = prefix + body
                    changed = dict(record, rawSha256=hashlib.sha256(payload).hexdigest())
                    with self.subTest(prefix=prefix), self.assertRaisesRegex(ValueError, "fatal native"):
                        producer.current_receipt(ROOT, "progress", payload, staged_model=staged,
                                                 execution=json.dumps(changed).encode())


if __name__ == "__main__":
    unittest.main()
