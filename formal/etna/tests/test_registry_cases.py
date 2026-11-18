"""Focused tests for raw Forge evidence admission and private fault restoration."""
import copy
import importlib.util
import json
import re
import stat
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

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

    def test_native_token_emitter_cannot_be_substituted_consistently(self):
        address = "0x" + "88" * 20
        logs = [{"address": address, "topics": [topic], "data": "0x"}
                for topic in (CASES.CHECKPOINT_TOPIC, CASES.TRANSFER_TOPIC, CASES.TRANSFER_TOPIC)]
        with self.assertRaisesRegex(ValueError, "wrong token emitter"):
            CASES.require_pair_logs(logs, bytes(32), bytes(32), None)

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
        with self.assertRaises(SystemExit) as exited:
            CASES.main(args[:1] + ["double-sign"] + args[2:])
        self.assertEqual(exited.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
