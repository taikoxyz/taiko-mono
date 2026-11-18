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
        pins = CASES.EXEC.read_json(CASES.PIN_PATH)
        case = pins["pairs"]["same_block_later_time"]
        bad_proxy = bytes.fromhex("33" * 20).rjust(32, b"\0")
        selector = CASES.hex_bytes(pins["selectors"][case["result"]], 4).ljust(32, b"\0")
        payload = b"".join(
            [bad_proxy, PROXY, selector, selector, CASES.word(0), CASES.word(1),
             CASES.word(1), CASES.word(1), CASES.hex_bytes(pins["effects"]["preRoot"])]
            + [CASES.hex_bytes(pins["effects"]["preRoot"])]
            + [CASES.word(n) for n in pins["effects"]["before"]]
        )
        self.tests[REFUSAL] = row(payload)
        self.expected[REFUSAL] = lambda receipt, logs: CASES.pair_receipt(receipt, logs, case, pins)
        with self.assertRaisesRegex(ValueError, "exact revert origin"):
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


if __name__ == "__main__":
    unittest.main()
