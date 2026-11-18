"""Focused tests for raw Forge evidence admission and private fault restoration."""
import copy
from contextlib import redirect_stderr
import io
import importlib.util
import json
import re
import stat
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

if __package__:
    from .test_comet_signed import input_map_mutations, signed_execution_record
else:
    from test_comet_signed import input_map_mutations, signed_execution_record

ROOT = Path(__file__).resolve().parents[1] / "conformance"
SPEC = importlib.util.spec_from_file_location("etna_registry_cases", ROOT / "run_registry_cases.py")
CASES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CASES)

SUITE = "test/layer1/etna/conformance/Example.t.sol:Example"
PASS = "test_wire()"
REFUSAL = "test_pair()"
PAYLOAD = b"\x12\x34"
EMITTER = "0x7fa9385be102ac3eac297483dd6233d62b3e1496"
PROXY = bytes.fromhex("22" * 20).rjust(32, b"\0")


def native_log(payload):
    return dict(address=EMITTER, topics=[CASES.RECEIPT_TOPIC],
                data="0x" + (CASES.word(32) + CASES.word(len(payload)) +
                             payload.ljust((len(payload) + 31) // 32 * 32, b"\0")).hex())


def row(payload, *, reason=None):
    return dict(status="Failure" if reason else "Success", reason=reason, counterexample=None,
                logs=[] if payload is None else [native_log(payload)], decoded_logs=[],
                kind={"Unit": {"gas": 1}}, traces=[], labeled_addresses={}, duration="1ms",
                breakpoints={}, gas_snapshots={})


class ForgeBoundary(unittest.TestCase):
    def setUp(self):
        self.tests = {PASS: row(PAYLOAD), REFUSAL: row(PROXY)}
        self.expected = {PASS: PAYLOAD, REFUSAL: PROXY}

    def check(self, data=None, *, returncode=0, failure=None):
        raw = json.dumps({SUITE: dict(duration="2ms", test_results=self.tests)})
        return CASES.require_forge_outcomes(raw if data is None else data, returncode,
                                           SUITE, self.expected, failure=failure)

    def test_accepts_exact_identity_and_receipt(self):
        self.assertEqual(set(self.check()), set(self.tests))

    def test_rejects_wrong_missing_extra_and_duplicate_identities(self):
        raw = json.dumps({SUITE: dict(duration="2ms", test_results=self.tests)})
        for data in (raw.replace(SUITE, SUITE + "Suffix"), raw.replace(PASS, "test_other()"),
                     raw.replace(PASS, REFUSAL), raw[:-1] + ',"unexpected":{}}'):
            with self.subTest(data=data[:95]), self.assertRaises(ValueError):
                self.check(data)
        del self.tests[PASS]
        with self.assertRaises(ValueError):
            self.check()

    def test_rejects_wrong_test_receipt_emitter(self):
        self.tests[PASS]["logs"][0]["address"] = "0x" + "76" * 20
        with self.assertRaisesRegex(ValueError, "receipt"):
            self.check()

    def test_rejects_wrong_revert_origin(self):
        pins, expected, *_ = CASES.inputs()
        name = "same_block_later_time"
        case = pins["pairs"][name]
        call = self.pair_call(case)
        bad_proxy = bytes.fromhex("33" * 20).rjust(32, b"\0")
        selector = CASES.hex_bytes(pins["selectors"][case["result"]], 4).ljust(32, b"\0")
        payload = b"".join(
            [bad_proxy, PROXY, selector, selector, CASES.word(0), CASES.word(1),
             CASES.word(1), CASES.word(1), CASES.hex_bytes(pins["effects"]["preRoot"])]
            + [CASES.hex_bytes(pins["effects"]["preRoot"])]
            + [CASES.word(n) for n in pins["effects"]["before"]]
        )
        self.tests[REFUSAL] = row(payload + CASES.pair_binding(name, call))
        self.expected[REFUSAL] = expected[f"test_pair_{name}()"]
        with self.assertRaisesRegex(ValueError, "exact revert origin"):
            self.check()

    def pair_call(self, case, *, swap=False):
        projection = CASES.STOCK.load_projection((ROOT / "comet_signed/public-votes.json").read_bytes())
        votes = {row["name"]: row for row in projection["voteCases"]}
        first, second = votes[case["a"]], votes[case["b"]]
        return CASES.slash_calldata(second, first) if swap else CASES.slash_calldata(first, second)

    def test_pair_binding_rejects_other_evidence_under_the_same_leaf(self):
        pins, expected, *_ = CASES.inputs()
        for name, other in (("precommit_conflict", "backdated_conflict"),
                            ("different_round", "different_height")):
            self.expected[REFUSAL] = expected[f"test_pair_{name}()"]
            primary = self.pair_call(pins["pairs"][name])
            for case_id, action in ((other, primary), (name, self.pair_call(pins["pairs"][other])),
                                    (name, self.pair_call(pins["pairs"][name], swap=True))):
                with self.subTest(name=name, case_id=case_id), self.assertRaisesRegex(ValueError, "ordered call data"):
                    binding = CASES.pair_binding(case_id, action)
                    self.tests[REFUSAL] = row(bytes(CASES.PAIR_RESULT_BYTES) + binding)
                    self.check()

    def test_pair_binding_rejects_modified_signed_metadata_or_signature(self):
        pins, expected, *_ = CASES.inputs()
        name = "backdated_conflict"
        self.expected[REFUSAL] = expected[f"test_pair_{name}()"]
        exact = self.pair_call(pins["pairs"][name])
        tuple_start = 4 + 3 * 32
        for offset in (0, 4 + 31, tuple_start + 6 * 32 + 31,
                       tuple_start + 8 * 32 + 31, tuple_start + 11 * 32):
            with self.subTest(offset=offset), self.assertRaisesRegex(ValueError, "ordered call data"):
                wrong = bytearray(exact)
                wrong[offset] ^= 1
                binding = CASES.pair_binding(name, bytes(wrong))
                self.tests[REFUSAL] = row(bytes(CASES.PAIR_RESULT_BYTES) + binding)
                self.check()

    def test_forge_allows_empty_data_for_indexed_only_events(self):
        log = {"address": EMITTER, "topics": [CASES.RECEIPT_TOPIC], "data": "0x"}
        CASES.validate_native_logs([log])
        with self.assertRaises(ValueError):
            CASES.validate_native_logs([log | {"data": "0x0"}])
        with self.assertRaises(ValueError):
            CASES.decode_receipt(log)

    def test_rejects_stale_status_or_truncated_evidence(self):
        for raw in ('{"truncated"', '{}', ''):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                self.check(raw)
        self.tests[PASS]["logs"][0]["data"] = self.tests[PASS]["logs"][0]["data"][:-2]
        with self.assertRaisesRegex(ValueError, "receipt"):
            self.check()
        self.tests[PASS] = row(PAYLOAD)
        self.tests[PASS]["status"] = "Skipped"
        with self.assertRaises(ValueError):
            self.check()

    def test_only_the_targeted_diagnostic_counts_as_a_fault(self):
        failure = (REFUSAL, "same-block fault", None)
        self.tests[REFUSAL] = row(None, reason=failure[1])
        self.assertEqual(self.check(returncode=1, failure=failure)[REFUSAL]["status"], "Failure")
        for returncode, name, reason in ((1, REFUSAL, "setup"), (1, PASS, failure[1]),
                                         (124, REFUSAL, failure[1])):
            with self.subTest(returncode=returncode, name=name, reason=reason):
                original = copy.deepcopy(self.tests)
                self.tests[name] = row(None, reason=reason)
                with self.assertRaises(ValueError):
                    self.check(returncode=returncode, failure=failure)
                self.tests = original

    def test_forge_filter_matches_the_complete_abi_signature(self):
        directory = Path("/tmp/fixture")
        command = CASES.isolation_command(
            directory, directory, directory, directory, directory,
            {name: directory / name for name in CASES.TOOLS}, {CASES.SMOKE_TEST}, 30,
        )
        pattern = command[command.index("--match-test") + 1]
        self.assertIsNotNone(re.fullmatch(pattern, CASES.SMOKE_TEST))
        self.assertIsNone(re.fullmatch(pattern, CASES.SMOKE_TEST.removesuffix("()")))
        self.assertIsNone(re.fullmatch(pattern, "test_pair_different_height()"))

    def test_hash_guard_rejects_bad_input(self):
        fixture = ROOT / "comet_signed/public-votes.json"
        CASES.require_hash(fixture, "34932f8ddf991ae41eb1be94c873e99524f51cf96d427faed4a1bfc443dc960e")
        with self.assertRaisesRegex(ValueError, "hash"):
            CASES.require_hash(fixture, "0" * 64)


class StockEvidence(unittest.TestCase):
    def test_stock_comparison_requires_exact_executed_build_maps(self):
        pins = CASES.STOCK.strict_json((ROOT / "comet_signed/pins.json").read_bytes())
        expected = {"precommit_a": {"signBytes": "0x1234"}}
        wire = {"precommit_a": 2}
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "normal"
            record = signed_execution_record(output, pins, "normal", expected)
            comparison, _ = CASES.stock_evidence(output, pins, expected, wire)
            self.assertEqual(comparison, {"test_wire_precommit_a()": "0x1234"})
            for mutation, hashes in input_map_mutations(record["executedInputsBefore"]):
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    (output / "execution.json").write_text(json.dumps(record | {
                        "executedInputsBefore": hashes, "executedInputsAfter": hashes,
                    }))
                    CASES.stock_evidence(output, pins, expected, wire)


class PairNativeLogs(unittest.TestCase):
    def setUp(self):
        self.pins = CASES.EXEC.read_json(CASES.PIN_PATH)
        self.pre = bytes.fromhex(self.pins["effects"]["preRoot"][2:])
        self.post = bytes.fromhex(self.pins["effects"]["postRoot"][2:])
        self.event = self.pins["pairs"]["precommit_conflict"]["event"]
        # The two lanes share the first registration, independently pinned in N04.
        register = self.pins["atomicity"]["test_register_allowance_rollback_and_retry()"]
        self.setup = [*register["setupLogs"][:7], register["setupLogs"][5], {
            "address": "0x" + "22" * 20,
            "topics": ["0x784a6d56e445d4ededf7abef18f427bf7500a6296ef170b71109d09ce6eae57a",
                       "0x" + "00" * 32],
            "data": "0x" + format(4, "064x") + format(14, "064x"),
        }]
        checkpoint, payment = self.setup[4:6]
        slash = {
            "address": "0x" + "22" * 20,
            "topics": ["0x2ba37af98a310ee7f58eada0f1ee56a60eaf088d2a320ab8c63fb2ad4c804330",
                       "0x" + "00" * 32, "0x" + format(0x4444, "064x")],
            "data": "0x" + "".join(format(value, "064x") for value in (8, 2, 0, 1000, 0, 2)),
        }
        self.suffix = [
            checkpoint | {"topics": [checkpoint["topics"][0], "0x" + format(1, "064x")],
                          "data": "0x" + format(13, "064x") + format(1, "064x") + self.post.hex()},
            *(payment | {"topics": [payment["topics"][0], "0x" + PROXY.hex(), "0x" + format(payee, "064x")],
                         "data": "0x" + format(amount, "064x")}
              for payee, amount in ((0x4444, 2), (0x5555, 6))),
            slash,
        ]

    def check(self, logs, phase):
        name = "precommit_conflict" if phase == "slash" else "same_block_later_time"
        leaf = f"test_pair_{name}()"
        case = self.pins["pairs"][name]
        calldata = b"\x12\x34\x56\x78"
        failure = None
        if phase == "fault":
            failure = (leaf, CASES.FAULT_DIAGNOSTIC,
                       lambda observed: CASES.require_pair_logs(observed, self.pre, self.post, self.event))
            native = row(None, reason=failure[1])
            native["logs"] = logs
        else:
            success = phase == "slash"
            selectors = self.pins["selectors"]
            selector = lambda name: bytes.fromhex(selectors[name][2:]).ljust(32, b"\0")
            before, after = CASES.word(1), CASES.word(2 if success else 1)
            payload = b"".join([
                PROXY, PROXY, bytes(32) if success else selector(case["result"]),
                selector("NothingToSlash" if success else case["result"]),
                CASES.word(case["currentGeneration"]), before, after, after, self.pre,
                self.post if success else self.pre,
                *map(CASES.word, self.pins["effects"]["slashed" if success else "before"]),
            ])
            native = row(payload + CASES.pair_binding(name, calldata))
            native["logs"][0:0] = logs

        raw = json.dumps({CASES.SUITE: dict(duration="2ms", test_results={leaf: native})})
        expected = {leaf: lambda receipt, observed: CASES.pair_receipt(
            receipt, observed, case, self.pins, name, calldata)}
        return CASES.require_forge_outcomes(raw, int(failure is not None), CASES.SUITE,
                                           expected, failure=failure)[leaf]

    def test_complete_logs_preserve_selected_summary(self):
        selected_setup = [self.setup[index] for index in (4, 5, 7)]
        self.assertEqual(self.check(self.setup, "refusal")["actionLogs"], selected_setup)
        self.assertEqual(self.check(self.setup + self.suffix, "slash")["actionLogs"],
                         selected_setup + self.suffix)
        self.assertEqual(self.check(self.setup + self.suffix, "fault"),
                         dict(status="Failure", reason=CASES.FAULT_DIAGNOSTIC))

    def test_previously_ignored_events_are_bound_on_refusal_slash_and_fault(self):
        registration = self.setup[6]
        for phase in ("refusal", "slash", "fault"):
            suffix = [] if phase == "refusal" else self.suffix
            logs = self.setup + suffix
            changes = {
                "omitted Registered": logs[:6] + logs[7:],
                "extra Registered after setup": self.setup + [registration] + suffix,
                "reordered Registered": logs[:6] + [logs[7], registration] + logs[8:],
                "wrong Registered address": logs[:6] + [registration | {"address": EMITTER}] + logs[7:],
                "wrong Registered data": logs[:6] + [registration | {"data": "0x"}] + logs[7:],
                "wrong Registered topics": logs[:6] + [registration | {
                    "topics": registration["topics"][:2] + list(reversed(registration["topics"][2:])),
                }] + logs[7:],
                "omitted TopUpDeposited": logs[:8] + logs[9:],
                "extra unknown event": logs + [registration | {"topics": []}],
            }
            for mutation, changed in changes.items():
                with self.subTest(phase=phase, mutation=mutation), self.assertRaises(ValueError):
                    self.check(changed, phase)

    def test_action_suffix_has_exact_values_order_and_count(self):
        other_emitter = self.suffix[1] | {"address": EMITTER}
        changes = (self.suffix[:-1], self.suffix + self.suffix[:1],
                   [self.suffix[0], self.suffix[2], self.suffix[1], self.suffix[3]],
                   [self.suffix[0], other_emitter, *self.suffix[2:]])
        for phase in ("slash", "fault"):
            for index, changed in enumerate(changes):
                with self.subTest(phase=phase, mutation=index), self.assertRaises(ValueError):
                    self.check(self.setup + changed, phase)
        with self.assertRaises(ValueError):
            self.check(self.setup + [native_log(PAYLOAD)] + self.suffix, "fault")


class Restoration(unittest.TestCase):
    def test_restores_bytes_and_mode_after_partial_write_or_failed_readback(self):
        original = CASES.FAULT_FUNCTION + b"\n" + CASES.FAULT_BEFORE
        for operation in ("write", "read"):
            with self.subTest(operation=operation), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                source = base / "source"
                target = source / CASES.FAULT_PATH
                target.parent.mkdir(parents=True)
                target.write_bytes(original)
                target.chmod(0o444)
                manifest = {
                    "schema": "etna-source-snapshot-1", "commit": "fixture",
                    "files": {CASES.FAULT_PATH: CASES.STOCK.COMET.file_entry(original)},
                }
                read = Path.read_bytes
                write = Path.write_bytes
                reads = 0

                def damaged_write(path, data):
                    if operation == "write" and path == target and data != original:
                        return write(path, data[:13])
                    return write(path, data)

                def missed_read(path):
                    nonlocal reads
                    if path == target:
                        reads += 1
                        if operation == "read" and reads == 2:
                            raise OSError("fault readback")
                    return read(path)

                with patch.object(Path, "write_bytes", damaged_write), patch.object(Path, "read_bytes", missed_read):
                    with self.assertRaises(OSError), CASES.private_source_fault(source, manifest, base):
                        pass
                self.assertEqual(target.read_bytes(), original)
                self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o444)
                self.assertEqual(CASES.EXEC.read_json(base / "restoration.json")["mode"], "0o444")


class LifecycleBoundary(unittest.TestCase):
    def setUp(self):
        self.oracle = CASES.EXEC.read_json(CASES.PIN_PATH)["lifecycle"]
        self.leaf = "test_exit_withdraw_and_reuse()"
        self.expected = {self.leaf: lambda receipt, logs: CASES.lifecycle_receipt(receipt, logs, self.oracle)}

    def check(self, native_row, *, fault=False):
        suite = CASES.LIFECYCLE_SUITE
        raw = json.dumps({suite: dict(duration="2ms", test_results={self.leaf: native_row})})
        failure = CASES.lifecycle_failure(self.oracle) if fault else None
        return CASES.require_forge_outcomes(raw, int(fault), suite, self.expected, failure=failure)

    def test_rejects_missing_lifecycle_receipt(self):
        with self.assertRaisesRegex(ValueError, "missing, extra or misplaced receipt"):
            self.check(row(None))

    def test_rejects_unrelated_lifecycle_mutation_diagnostic(self):
        with self.assertRaisesRegex(ValueError, "wrong Forge fault diagnostic"):
            self.check(row(None, reason="lifecycle: unrelated setup failure"), fault=True)

    def test_rejects_correct_lifecycle_diagnostic_without_expected_trace(self):
        failure = CASES.lifecycle_failure(self.oracle)
        with self.assertRaisesRegex(ValueError, "wrong ordered lifecycle action logs"):
            self.check(row(None, reason=failure[1]), fault=True)

    def test_binds_lifecycle_receipt_to_every_observed_context(self):
        steps = self.oracle["journal"]
        observed = row(b"".join(map(CASES.lifecycle_binding, steps)))
        observed["logs"][0:0] = self.oracle["setupLogs"] + self.oracle["actionLogs"]
        self.assertIn(self.leaf, self.check(observed))
        for name, field, value in (
            ("withdraw_early", "height", 16),
            ("confirm_uncovered", "snapshot", 15),
            ("exit_other_owner", "actor", "0x" + "aa" * 20),
            ("withdraw_reused", "calldata", steps[-1]["calldata"][:-65] + "1" + steps[-1]["calldata"][-64:]),
            ("reuse_slot", "afterState", "0x" + "ff" * 32),
            ("confirm_exact", "logCount", 0),
        ):
            with self.subTest(step=name, field=field), self.assertRaisesRegex(ValueError, "lifecycle receipt"):
                changed = [step | {field: value} if step["name"] == name else step for step in steps]
                bad = copy.deepcopy(observed)
                bad["logs"][-1] = native_log(b"".join(map(CASES.lifecycle_binding, changed)))
                self.check(bad)

    def test_lifecycle_does_not_require_stock_go_evidence(self):
        args = ["--scenario", "lifecycle", "--runtime", "runtime", "--output", "output"]
        with patch.object(CASES, "run") as run:
            self.assertEqual(CASES.main(args), 0)
        self.assertIsNone(run.call_args.args[0].go_normal)
        stderr = io.StringIO()
        with redirect_stderr(stderr), self.assertRaises(SystemExit) as exited:
            CASES.main(args[:1] + ["double-sign"] + args[2:])
        self.assertEqual(exited.exception.code, 2)
        self.assertTrue(stderr.getvalue().endswith("error: --go-normal is required for double-sign\n"))


class AtomicityBoundary(unittest.TestCase):
    def setUp(self):
        target = "0x" + "22" * 20
        token = "0x5615deb798bb3e4dfa0139dfa1b3d433cc23b72f"
        self.refusal = dict(
            name="topup_refusal", height=12, snapshot=9, actor="0x" + "aa" * 20,
            target=target, ok=False, beforeState="0x" + "12" * 32, afterState="0x" + "12" * 32,
            logCount=0, tokenTarget=token, tokenReverted=True, allowanceWrite=[1, 4, 0],
            calldata="0x12345678", result="0x08c379a0", tokenCalldata="0x23b872dd",
        )
        self.retry = self.refusal | dict(
            name="topup_retry", ok=True, afterState="0x" + "34" * 32,
            tokenReverted=False, result="0x",
        )
        frames = dict(
            delegate=[1, 1, "0x" + "44" * 20, self.refusal["actor"], 2, True],
            token=[4, 0, token, target, 3, True],
        )
        resumed = [3, 6, frames["delegate"][2], self.refusal["actor"], 2, True]
        transitions = (
            ("9ec5706da37609ac710f31f391f514e2721a7d03114dd165392f232cefc7074a", 0, 4),
            ("9ec5706da37609ac710f31f391f514e2721a7d03114dd165392f232cefc7074b", 0, 14),
            ("47815a5b6cc18ba684fce844040895d6aad392a3de9e10ad601cd48bc4875b84", 16384, 32768),
            ("bf413d0ecf5c801a2029e0accdcc0c0daa3d0a93324b144d16c809b7a830f7e4", 16384, 16385),
        )
        self.witness = frames | dict(
            before=[0, 0, 16384, 16384], restored=[0, 0, 16384, 16384],
            writes=[[resumed.copy(), index, target, "0x" + slot, old, new, True]
                    for index, (slot, old, new) in enumerate(transitions)],
        )
        self.oracle = dict(journal=[self.refusal, self.retry], setupLogs=[], actionLogs=[],
                           topUpWitness=copy.deepcopy(self.witness))

    def encode(self, step):
        # Independent framing of the fixed head and three dynamic byte strings.
        word = lambda value: value.to_bytes(32, "big")
        head = [step["name"].encode().ljust(32, b"\0"), word(step["height"]), word(step["snapshot"]),
                bytes.fromhex(step["actor"][2:]).rjust(32, b"\0"),
                bytes.fromhex(step["target"][2:]).rjust(32, b"\0"), word(int(step["ok"])),
                bytes.fromhex(step["beforeState"][2:]), bytes.fromhex(step["afterState"][2:]),
                word(step["logCount"]), bytes.fromhex(step["tokenTarget"][2:]).rjust(32, b"\0"),
                word(int(step["tokenReverted"])), *map(word, step["allowanceWrite"])]
        tail = b""
        for field in ("calldata", "result", "tokenCalldata"):
            head.append(word(17 * 32 + len(tail)))
            data = bytes.fromhex(step[field][2:])
            tail += word(len(data)) + data.ljust((len(data) + 31) // 32 * 32, b"\0")
        body = b"".join(head) + tail
        return word(len(body)) + body

    def encode_witness(self, witness):
        # Independently encode the static tuples and one dynamic byte string.
        def encode(fields):
            return b"".join(
                int(field, 16).to_bytes(32, "big") if isinstance(field, str)
                else int(field).to_bytes(32, "big")
                for field in fields
            )
        observed = [*witness["delegate"], *witness["token"],
                    *witness["before"], *witness["restored"]]
        writes = b"".join(encode([*frame, *storage]) for frame, *storage in witness["writes"])
        return encode([22 * 32 + len(writes), *observed, 21 * 32, len(writes)]) + writes

    def receipt(self, *, refusal=None, retry=None, witness=None):
        return (b"etna-registry-atomicity-2".ljust(32, b"\0")
                + (self.encode(self.refusal) if refusal is None else refusal)
                + (self.encode_witness(self.witness) if witness is None else witness)
                + (self.encode(self.retry) if retry is None else retry))

    def check(self, receipt):
        suite = "test/layer1/etna/conformance/EtnaRegistryAtomicityCases.t.sol:EtnaRegistryAtomicityCasesTest"
        leaf = "test_topup_balance_rollback_and_retry()"
        native = json.dumps({suite: dict(duration="2ms", test_results={leaf: row(receipt)})})
        return CASES.require_forge_outcomes(
            native, 0, suite, {leaf: lambda payload, logs: CASES.atomicity_receipt(payload, logs, self.oracle)},
        )[leaf]["journal"]

    def test_accepts_exact_atomicity_journal(self):
        journal = self.check(self.receipt())
        self.assertEqual(journal[0]["allowanceWrite"], [1, 4, 0])
        self.assertEqual(journal[0]["topUpWitness"], self.witness)
        self.assertEqual(journal[1]["calldata"], journal[0]["calldata"])

    def test_rejects_legacy_atomicity_receipt(self):
        # The legacy receipt has the same token failure, raw rollback and retry.
        with self.assertRaisesRegex(ValueError, "atomicity receipt schema"):
            self.check(self.encode(self.refusal) + self.encode(self.retry))

    def test_rejects_missing_duplicate_or_reordered_registry_writes_on_native_success(self):
        writes = self.witness["writes"]
        for altered in ([], writes[1:], writes + writes[:1], writes[1::-1] + writes[2:]):
            with self.subTest(altered=altered), self.assertRaisesRegex(ValueError, "Registry write witness"):
                self.check(self.receipt(witness=self.encode_witness(self.witness | {"writes": altered})))
        with self.assertRaisesRegex(ValueError, "Registry write witness"):
            self.check(self.receipt(witness=b""))

    def test_rejects_altered_witness_fields_on_native_success(self):
        for index, value in (
            (1, 99), (2, "0x" + "77" * 20), (3, "0x" + "ff" * 32),
            (4, 9), (5, 9), (6, False),
        ):
            witness = copy.deepcopy(self.witness)
            witness["writes"][0][index] = value
            with self.subTest(index=index), self.assertRaisesRegex(ValueError, "Registry write witness"):
                self.check(self.receipt(witness=self.encode_witness(witness)))

        for index, value in (
            (0, self.witness["token"][0]), (0, self.witness["token"][0] + 1),
            (1, 3), (2, "0x" + "77" * 20),
            (3, "0x" + "77" * 20), (4, 3), (5, False),
        ):
            witness = copy.deepcopy(self.witness)
            witness["writes"][0][0][index] = value
            with self.subTest(frame_index=index), self.assertRaisesRegex(ValueError, "Registry write witness"):
                self.check(self.receipt(witness=self.encode_witness(witness)))

        for field, index, value in (("before", 0, 1), ("restored", 1, 14), ("token", 0, 2), ("delegate", 4, 3)):
            witness = copy.deepcopy(self.witness)
            witness[field][index] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "Registry write witness"):
                self.check(self.receipt(witness=self.encode_witness(witness)))

    def test_rejects_wrong_nested_token_refusal(self):
        for field, value in (
            ("tokenTarget", "0x" + "00" * 20), ("tokenCalldata", "0x23b872dc"),
            ("tokenReverted", False), ("result", "0x08c379a1"), ("allowanceWrite", [0, 0, 0]),
        ):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "topup_refusal"):
                self.check(self.receipt(refusal=self.encode(self.refusal | {field: value})))

    def test_rejects_missing_or_changed_rollback_post_state(self):
        step = self.encode(self.refusal)
        offset = 32 + 7 * 32
        for post in (b"", bytes(32)):
            with self.subTest(post=post), self.assertRaisesRegex(ValueError, "topup_refusal"):
                self.check(self.receipt(refusal=step[:offset] + post + step[offset + 32:]))

    def test_rejects_nonidentical_retry(self):
        for field, value in (
            ("calldata", "0x12345679"), ("tokenCalldata", "0x23b872dc"), ("height", 13),
            ("snapshot", 8), ("actor", "0x" + "bb" * 20), ("beforeState", "0x" + "66" * 32),
        ):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "topup_retry"):
                self.check(self.receipt(retry=self.encode(self.retry | {field: value})))

    def test_validates_frozen_atomicity_context(self):
        pins, expected, *_ = CASES.inputs("atomicity")
        self.assertEqual(set(expected), {CASES.ATOMICITY_REGISTER, CASES.ATOMICITY_TOPUP})
        leaves = copy.deepcopy(pins["atomicity"])
        witness = leaves[CASES.ATOMICITY_TOPUP]["topUpWitness"]
        witness["writes"][0][0][0] = witness["token"][0]
        with self.assertRaisesRegex(ValueError, "token boundary"):
            CASES.require_atomicity_oracle(leaves)

    def test_atomicity_does_not_require_stock_go_evidence(self):
        args = ["--scenario", "atomicity", "--runtime", "runtime", "--output", "output", "--smoke"]
        with patch.object(CASES, "run") as run:
            self.assertEqual(CASES.main(args), 0)
        self.assertEqual(run.call_args.args[0].scenario, "atomicity")
        self.assertIsNone(run.call_args.args[0].go_normal)
        self.assertTrue(run.call_args.args[0].smoke)


if __name__ == "__main__":
    unittest.main()
