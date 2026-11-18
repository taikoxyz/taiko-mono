"""Focused regression tests for N01 input and output boundaries."""
import copy
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1] / "conformance"
SPEC = importlib.util.spec_from_file_location("etna_comet_signed", ROOT / "run_comet_signed.py")
SIGNED = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIGNED)


def signed_stream(expected, fail=False, split_receipt=False):
    leaf = SIGNED.PARENT + "/" + next(iter(expected))
    status = "fail" if fail else "pass"
    rows = []

    def append(action, name=None, payload=None, kind=None):
        item = {"Package": SIGNED.PACKAGE, "Action": action}
        if name is not None:
            item["Test"] = name
        if payload is not None:
            item["Output"] = payload
        if kind is not None:
            item["OutputType"] = kind
        rows.append(item)

    append("start")
    append("run", SIGNED.PARENT)
    append("output", SIGNED.PARENT, "=== RUN   " + SIGNED.PARENT + "\n", "frame")
    append("run", leaf)
    append("output", leaf, "=== RUN   " + leaf + "\n", "frame")
    receipt = "    signed_test.go:12: receipt=" + json.dumps(next(iter(expected.values()))) + "\n"
    size = SIGNED.GO_OUTPUT_BUFFER if split_receipt else len(receipt)
    for offset in range(0, len(receipt), size):
        append("output", leaf, receipt[offset:offset + size])
    if fail:
        append("output", leaf, "    signed_test.go:13: " + SIGNED.FAULT_DIAGNOSTIC + "\n", "error")
    for name in (leaf, SIGNED.PARENT):
        append("output", name, f"--- {status.upper()}: {name} (0.00s)\n", "frame")
        append(status, name)
    append("output", payload=status.upper() + "\n", kind="frame")
    prefix = "FAIL\t" if fail else "ok  \t"
    append("output", payload=f"{prefix}{SIGNED.PACKAGE}\t0.001s\n", kind="frame" if fail else None)
    append(status)
    return rows


def executed_input_hashes(pins):
    # Effective module bytes and fixture identities read back from genuine Go records.
    return {f"inputs/{name}": digest for name, digest in pins["inputsSha256"].items()} | {
        "modfiles/go.mod": "ce9bc5560e8aa13e0043832ca34619e6fa9596127ae2ad9c2b51913f4ea91059",
        "modfiles/go.sum": "f79af3ec03edcbd7f173a87cca9318677d139fda4f3cb629873546b3ec71842a",
    }


def input_map_mutations(hashes):
    for name in hashes:
        yield f"missing {name}", {key: digest for key, digest in hashes.items() if key != name}
        yield f"changed {name}", hashes | {name: "0" * 64}
    yield "extra path", hashes | {"modfiles/unexpected": "1" * 64}


def signed_execution_record(directory, pins, phase, expected):
    raw = "\n".join(map(json.dumps, signed_stream(expected))).encode()
    snapshot = dict(commit=pins["source"]["commit"], files=pins["source"]["files"],
                    status="INPUTS_VERIFIED")
    executed = executed_input_hashes(pins)
    selected_filter = f"^{SIGNED.PARENT}$"
    if phase == "smoke":
        selected_filter += f"/^{SIGNED.SMOKE}$"
    record = dict(
        phase=phase, timedOut=False, combinedOutputSha256=SIGNED.COMET.digest(raw),
        toolsSha256=pins["goToolSha256"], selectedFilter=selected_filter,
        sourceBefore=snapshot, sourceAfter=snapshot, returncode=0,
        executedInputsBefore=executed, executedInputsAfter=executed,
        outcomes={f"{SIGNED.PARENT}/{name}": "pass" for name in expected},
    )
    directory.mkdir()
    (directory / "combined.log").write_bytes(raw)
    (directory / "execution.json").write_text(json.dumps(record))
    return record


class SignedBoundary(unittest.TestCase):
    def test_projection_exact_types_and_fields(self):
        case_dir = ROOT / "comet_signed"
        data = SIGNED.load_projection((case_dir / "public-votes.json").read_bytes())
        self.assertEqual(tuple(map(len, (data["voteCases"], data["votePairs"],
                                        data["chainDomains"], data["spectators"]))), (23, 14, 5, 3))
        raw = json.dumps(data).encode()
        with self.assertRaises(ValueError):
            SIGNED.load_projection(b'{"schema":"duplicate",' + raw[1:])
        for field, value in (("height", True), ("height", "9223372036854775808"),
                             ("round", "01"), ("partsTotal", 1),
                             ("timestampSeconds", "-0"), ("timestampSecondsU64", "0"),
                             ("timestampNanos", "1000000000"), ("unexpected", None)):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                changed = copy.deepcopy(data)
                changed["voteCases"][0]["vote"][field] = value
                SIGNED.load_projection(json.dumps(changed).encode())
        for mutation in ("repeated-case", "missing-pair", "dangling-reference", "wrong-domain"):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                changed = copy.deepcopy(data)
                if mutation == "repeated-case":
                    changed["voteCases"][1]["name"] = changed["voteCases"][0]["name"]
                elif mutation == "missing-pair":
                    changed["votePairs"].pop()
                elif mutation == "dangling-reference":
                    changed["votePairs"][0]["a"] = "missing"
                else:
                    changed["voteCases"][0]["vote"]["generation"] = "1"
                SIGNED.load_projection(json.dumps(changed).encode())

    def parse(self, rows, expected, phase, returncode):
        raw = "\n".join(json.dumps(row) for row in rows).encode()
        return SIGNED.require_go_outcomes(raw, returncode, phase, expected)

    def test_exact_native_lifecycle(self):
        expected = {"precommit_a": {"verified": True}}
        rows = signed_stream(expected)
        self.assertEqual(len(self.parse(rows, expected, "smoke", 0)), 1)
        for changed in (rows[:8] + rows[9:], rows + [rows[-1]], rows[:4] + rows[5:],
                        rows[:4] + [dict(rows[4], Test="unexpected")] + rows[5:],
                        rows[:5] + [dict(rows[5], Output="unrelated\n")] + rows[6:],
                        rows[:7] + [dict(rows[7], Action="skip")] + rows[8:],
                        rows[:8] + [rows[8], rows[7]] + rows[9:]):
            with self.assertRaises(ValueError):
                self.parse(changed, expected, "smoke", 0)
        with self.assertRaises(ValueError):
            self.parse(rows, expected, "smoke", 1)
        with self.assertRaises(ValueError):
            self.parse(rows, {"precommit_a": {"verified": 1}}, "smoke", 0)

    def test_equal_outcome_refusals_reject_a_different_attempt(self):
        fixture = ROOT / "comet_signed"
        projection = SIGNED.load_projection((fixture / "public-votes.json").read_bytes())
        pins = SIGNED.strict_json((fixture / "pins.json").read_bytes())
        expected = SIGNED.frozen_expectations(projection, pins)
        pairs = (("vote-wrong-generation", "vote-wrong-inbox"),
                 ("vote-height", "vote-round"), ("vote-round", "vote-type"))
        for left, right in pairs:
            for name, other in ((left, right), (right, left)):
                with self.subTest(name=name, other=other):
                    target = {name: expected[name]}
                    identity = SIGNED.PARENT + "/" + name
                    self.assertEqual(self.parse(signed_stream(target, split_receipt=True), target, "normal", 0),
                                     {identity: "pass"})
                    alias = signed_stream({name: expected[other]}, split_receipt=True)
                    with self.assertRaisesRegex(ValueError, "wrong native observation for " + identity):
                        self.parse(alias, target, "normal", 0)

    def test_fragmented_receipt_stays_in_the_exact_leaf(self):
        expected = {"pol-above": {"block": "ab" * 650}}
        rows = signed_stream(expected)
        payload = rows[5]["Output"]
        chunks = [dict(rows[5], Output=payload[:1024]), dict(rows[5], Output=payload[1024:])]
        fragmented = rows[:5] + chunks + rows[6:]
        self.assertEqual(len(self.parse(fragmented, expected, "normal", 0)), 1)
        for bad in (dict(chunks[1], Test=SIGNED.PARENT),
                    dict(chunks[1], OutputType="error"),
                    dict(chunks[1], OutputType="frame"),
                    dict(chunks[1], Output=chunks[1]["Output"] + "extraneous\n")):
            with self.assertRaises(ValueError):
                self.parse(rows[:5] + [chunks[0], bad] + rows[6:], expected, "normal", 0)
        for sequence in ([chunks[0], *chunks], [*chunks, chunks[1]]):
            with self.assertRaises(ValueError):
                self.parse(rows[:5] + sequence + rows[6:], expected, "normal", 0)
        with self.assertRaises(ValueError):
            truncated = dict(chunks[0], Output=chunks[0]["Output"][:-1])
            self.parse(rows[:5] + [truncated, chunks[1]] + rows[6:], expected, "normal", 0)

    def test_pinned_output_type_is_required_for_errors_and_frames(self):
        expected = {SIGNED.FAULT_LEAF: {"commit": "accept"}}
        rows = signed_stream(expected, fail=True)
        for index in (2, 6, len(rows) - 2):
            with self.subTest(event=rows[index]["OutputType"]), self.assertRaises(ValueError):
                changed = copy.deepcopy(rows)
                del changed[index]["OutputType"]
                self.parse(changed, expected, "mutant", 1)
        changed = copy.deepcopy(rows)
        changed[5]["OutputType"] = ""
        with self.assertRaises(ValueError):
            self.parse(changed, expected, "mutant", 1)

    def test_each_receipt_event_has_the_pinned_byte_limit(self):
        expected = {"pol-above": {"block": "a" * 1265}}
        rows = signed_stream(expected)
        self.assertEqual(len(rows[5]["Output"].encode()), 1310)
        with self.assertRaises(ValueError):
            self.parse(rows, expected, "normal", 0)
        expected = {"pol-above": {"block": "ab" * 1100}}
        rows = signed_stream(expected)
        payload = rows[5]["Output"]
        chunks = [dict(rows[5], Output=payload[:1024]), dict(rows[5], Output=payload[1024:])]
        self.assertGreater(len(chunks[-1]["Output"].encode()), 1024)
        with self.assertRaises(ValueError):
            self.parse(rows[:5] + chunks + rows[6:], expected, "normal", 0)

    def test_elapsed_is_only_a_nonnegative_finite_terminal_duration(self):
        expected = {"precommit_a": {"verified": True}}
        rows = signed_stream(expected)
        for index, duration in ((0, 0), (0, "overflow"), (5, 0.02), (7, -0.2), (7, "overflow")):
            with self.subTest(index=index, duration=duration), self.assertRaises(ValueError):
                changed = copy.deepcopy(rows)
                changed[index]["Elapsed"] = duration
                raw = "\n".join(json.dumps(row) for row in changed).encode()
                raw = raw.replace(b'"Elapsed": "overflow"', b'"Elapsed": 1e9999')
                SIGNED.require_go_outcomes(raw, 0, "smoke", expected)

    def test_wrong_fault_diagnostic_and_unrelated_output_refused(self):
        expected = {SIGNED.FAULT_LEAF: {"commit": "accept"}}
        rows = signed_stream(expected, fail=True)
        self.assertEqual(len(self.parse(rows, expected, "mutant", 1)), 1)
        fault = 6
        for changed in (rows[:fault] + rows[fault+1:],
                        rows[:fault] + [dict(rows[fault], Output="    signed_test.go:13: other\n")] + rows[fault+1:],
                        rows[:fault] + [rows[fault]] + rows[fault:],
                        rows[:fault] + [dict(rows[fault], OutputType="")] + rows[fault+1:]):
            with self.assertRaises(ValueError):
                self.parse(changed, expected, "mutant", 1)

    def test_smoke_requires_exact_executed_build_maps(self):
        pins = SIGNED.strict_json((ROOT / "comet_signed/pins.json").read_bytes())
        expected = {SIGNED.SMOKE: {"verified": True}}
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            record = signed_execution_record(output / "smoke", pins, "smoke", expected)
            self.assertEqual(SIGNED.validate_smoke(output, expected, pins)["rawSha256"],
                             record["combinedOutputSha256"])
            for mutation, hashes in input_map_mutations(record["executedInputsBefore"]):
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    record_path = output / "smoke/execution.json"
                    record_path.write_text(json.dumps(record | {
                        "executedInputsBefore": hashes, "executedInputsAfter": hashes,
                    }))
                    SIGNED.validate_smoke(output, expected, pins)

    def test_trial_refuses_corrupt_effective_module_before_execution(self):
        pins = SIGNED.strict_json((ROOT / "comet_signed/pins.json").read_bytes())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            private = root / "upstream"
            private.mkdir()
            args = SimpleNamespace(output=root / "output", go_root=root / "go",
                                   module_cache=root / "modules", build_cache=root / "cache",
                                   timeout=60)
            sample = private / "fixture"
            sample.write_bytes(b"source")
            manifest = dict(schema="etna-source-snapshot-1", commit=pins["source"]["commit"],
                            files={sample.name: SIGNED.COMET.file_entry(sample.read_bytes())})
            target = args.output / "smoke/modfiles/go.mod"
            write_bytes = Path.write_bytes

            def corrupt_module(path, data):
                if path == target:
                    data = data.replace(b"/tmp/upstream", b"/tmp/unreviewed")
                return write_bytes(path, data)

            expected = {SIGNED.SMOKE: {"verified": True}}
            completed = dict(output="\n".join(map(json.dumps, signed_stream(expected))),
                             supervisor_argv=[], returncode=0, timeout=False, seconds=0)
            with patch.object(Path, "write_bytes", corrupt_module), patch.object(
                    SIGNED.COMET.EXECUTION, "execute", return_value=completed) as execute:
                with self.assertRaisesRegex(ValueError, "executed inputs changed"):
                    SIGNED.trial("smoke", private, manifest, args, pins, {}, {}, expected)
                execute.assert_not_called()

    def test_frozen_input_drift_and_missing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "watched"
            path.write_bytes(b"frozen")
            watched = {path: SIGNED.COMET.digest(b"frozen")}
            SIGNED.require_stable(watched, "fixture")
            path.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "changed"):
                SIGNED.require_stable(watched, "fixture")
            path.unlink()
            with self.assertRaisesRegex(ValueError, "changed"):
                SIGNED.require_stable(watched, "fixture")


class SourceFaultCleanup(unittest.TestCase):
    def setUp(self):
        container = self.enterContext(tempfile.TemporaryDirectory())
        self.private = Path(container) / "private"
        self.target = self.private / SIGNED.FAULT_PATH
        self.target.parent.mkdir(parents=True)
        self.original = SIGNED.FAULT_FUNCTION + b") error {\n" + SIGNED.FAULT_BEFORE
        self.target.write_bytes(self.original)
        self.target.chmod(0o444)
        self.manifest = {
            "schema": "etna-source-snapshot-1", "commit": "a" * 40,
            "files": {SIGNED.FAULT_PATH: SIGNED.COMET.file_entry(self.original)},
        }
        self.receipt = Path(container) / "restoration.json"

    def assert_restored(self):
        self.assertEqual(self.target.read_bytes(), self.original)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o444)
        evidence = json.loads(self.receipt.read_bytes())
        self.assertEqual(evidence["files"], 1)
        self.assertEqual(evidence["mode"], "0444")

    def test_partial_fault_write_restores_real_bytes_and_mode(self):
        write_bytes = Path.write_bytes

        def partial_write(path, data):
            if path == self.target and data != self.original:
                write_bytes(path, data[:11])
                self.assertEqual(path.read_bytes(), data[:11])
                raise OSError("injected partial fault write")
            return write_bytes(path, data)

        with patch.object(Path, "write_bytes", partial_write):
            with self.assertRaisesRegex(OSError, "injected partial fault write"):
                with SIGNED.private_source_fault(self.private, self.manifest, self.receipt):
                    self.fail("partial fault write entered the native trial")
        self.assert_restored()

    def test_failed_drift_readback_still_restores_real_bytes_and_mode(self):
        read_bytes = Path.read_bytes
        fail_read = False

        def transient_read(path):
            nonlocal fail_read
            if path == self.target and fail_read:
                fail_read = False
                raise OSError("injected pre-restore read failure")
            return read_bytes(path)

        with patch.object(Path, "read_bytes", transient_read):
            with self.assertRaisesRegex(OSError, "injected pre-restore read failure"):
                with SIGNED.private_source_fault(self.private, self.manifest, self.receipt) as mutant:
                    self.assertEqual(SIGNED.COMET.file_entry(self.target.read_bytes()),
                                     mutant["files"][SIGNED.FAULT_PATH])
                    fail_read = True
        self.assert_restored()


if __name__ == "__main__":
    unittest.main()
