"""Static evidence-boundary tests for the public FilePV runner."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / "conformance"
SPEC = importlib.util.spec_from_file_location("etna_comet_filepv", ROOT / "run_comet_filepv.py")
FILEPV = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FILEPV)


def native_stream(parent, name, receipt, fault=None):
    identity = f"{parent}/{name}"
    package = "command-line-arguments"
    rows = []

    def append(action, test=None, output=None, kind=None):
        event = {"Package": package, "Action": action}
        if test is not None:
            event["Test"] = test
        if output is not None:
            event["Output"] = output
        if kind is not None:
            event["OutputType"] = kind
        rows.append(event)

    append("start")
    for test in (parent, identity):
        append("run", test)
        append("output", test, f"=== RUN   {test}\n", "frame")
    line = "    filepv_test.go:100: receipt=" + json.dumps(receipt) + "\n"
    for offset in range(0, len(line), 1024):
        append("output", identity, line[offset:offset + 1024])
    outcome = "fail" if fault else "pass"
    if fault:
        append("output", identity, f"    filepv_test.go:101: {fault}\n", "error")
    for test in (identity, parent):
        append("output", test, f"--- {outcome.upper()}: {test} (0.00s)\n", "frame")
        append(outcome, test)
    append("output", output=outcome.upper() + "\n", kind="frame")
    prefix = "FAIL\t" if fault else "ok  \t"
    append("output", output=f"{prefix}{package}\t0.001s\n", kind="frame" if fault else None)
    append(outcome)
    return rows


class FilePVBoundary(unittest.TestCase):
    def test_only_exact_go_lifecycle_and_receipt_are_admitted(self):
        parent, name = "TestFilePVRead", "nil-exact"
        expected = {"attempt": "a" * 1032, "verified": True}
        receipt = expected | {"process": {"pid": 7, "namespace": "pid:[1007]", "startTicks": "11"}}
        rows = native_stream(parent, name, receipt)

        def parse(events, expectation=expected, returncode=0, faults=None):
            raw = "\n".join(map(json.dumps, events)).encode()
            return FILEPV.require_go_outcomes(
                raw, returncode, parent, {name: expectation}, faults or {},
            )

        self.assertEqual(parse(rows)["outcomes"], {f"{parent}/{name}": "pass"})
        for changed in (
            [], rows[:-1], rows + [rows[-1]], rows[:6] + rows[7:],
            rows[:6] + [rows[6] | {"Test": "Other"}] + rows[7:],
            rows[:5] + [rows[5] | {"Output": "    filepv_test.go:100: receipt={}\n"}] + rows[7:],
        ):
            with self.assertRaises(ValueError):
                parse(changed)
        with self.assertRaises(ValueError):
            parse(rows, expected | {"verified": 1})
        with self.assertRaises(ValueError):
            parse(rows, expected | {"attempt": "a" * 1031 + "b"})
        with self.assertRaises(ValueError):
            parse(rows, returncode=1)
        failure = "O01 omit-save kept the state path absent"
        self.assertEqual(
            parse(native_stream(parent, name, receipt, failure), returncode=1,
                  faults={name: failure})["outcomes"],
            {f"{parent}/{name}": "fail"},
        )
        with self.assertRaises(ValueError):
            parse(native_stream(parent, name, receipt, "panic: unrelated"), returncode=1,
                  faults={name: failure})

    def test_input_records_bind_every_named_and_effective_file_in_both_reads(self):
        expected = {
            "inputs/file.go": "1" * 64,
            "inputs/filepv_test.go": "2" * 64,
            "inputs/go.mod": "3" * 64,
            "inputs/go.sum": "4" * 64,
            "inputs/public-votes.json": "5" * 64,
            "modfiles/go.mod": "6" * 64,
            "modfiles/go.sum": "7" * 64,
        }
        record = {"executedInputsBefore": expected, "executedInputsAfter": expected}
        FILEPV.require_executed_inputs(record, expected)
        for key in record:
            for path in expected:
                for changed in ({name: value for name, value in expected.items() if name != path},
                                expected | {path: "0" * 64}):
                    with self.subTest(key=key, path=path), self.assertRaises(ValueError):
                        FILEPV.require_executed_inputs(record | {key: changed}, expected)
            with self.assertRaises(ValueError):
                FILEPV.require_executed_inputs(record | {key: expected | {"other": "8" * 64}}, expected)

    def test_state_path_requires_exact_bytes_and_unique_writer_owned_regular_file(self):
        expected = {"height": "1000", "round": 0, "step": 3, "signature": "eA==", "signbytes": "AA"}
        raw = json.dumps(expected, indent=2).encode()
        alternate = b'{"height":"1000","round":0,"step":3,"signature":"eA==","signbytes":"AA"}'
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            state = root / "state"
            state.mkdir(mode=0o700)
            path = state / "precommit_nil.json"
            with self.assertRaises(ValueError):
                FILEPV.require_disk(state, "precommit_nil", expected)
            path.write_bytes(raw)
            path.chmod(0o600)
            original = FILEPV.require_disk(state, "precommit_nil", expected)
            self.assertEqual(original["mode"], "0600")
            self.assertEqual(original["bytes"], len(raw))
            for value in (alternate, raw.replace(b'"round": 0', b'"round": false'),
                          raw.replace(b'"round": 0', b'"round": 0, "round": 0')):
                path.write_bytes(value)
                with self.assertRaises(ValueError):
                    FILEPV.require_disk(state, "precommit_nil", expected)
            path.write_bytes(raw)
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                FILEPV.require_disk(state, "precommit_nil", expected)
            path.chmod(0o600)
            linked = root / "copied-state.json"
            os.link(path, linked)
            with self.assertRaises(ValueError):
                FILEPV.require_disk(state, "precommit_nil", expected)
            path.unlink()
            path.symlink_to(linked)
            with self.assertRaises(ValueError):
                FILEPV.require_disk(state, "precommit_nil", expected)
            path.unlink()
            linked.rename(path)
            state.rename(root / "moved-state")
            state.symlink_to(root / "moved-state", target_is_directory=True)
            with self.assertRaises(ValueError):
                FILEPV.require_disk(state, "precommit_nil", expected)

    def test_pins_bind_both_disk_oracles_and_the_time_only_attempt(self):
        _, _, _, _, _, expected, _ = FILEPV.inputs()
        disk, writers, readers = expected
        self.assertEqual(tuple(disk), ("precommit_nil", "prevote_a_r1"))
        self.assertEqual(
            {seed: (row["diskAfter"]["bytes"], row["diskAfter"]["sha256"])
             for seed, row in writers.items()},
            {
                "precommit_nil": (319, "4e9095589653586cf29a7c84c61c247561981e2f8ef5d74e1113342f67183215"),
                "prevote_a_r1": (487, "6b1560e11d90e0670101afc0351568cdacab9dbc478e7774ecd411b5dd8037aa"),
            },
        )
        time_only = readers["nil-time"]
        self.assertEqual(time_only["attempt"]["vote"]["nanos"], 124)
        self.assertEqual(time_only["reply"]["vote"]["nanos"], 123)
        self.assertEqual(time_only["attempt"]["vote"]["signature"], "")
        self.assertEqual(time_only["reply"]["vote"]["signature"], writers["precommit_nil"]["attempt"]["signature"])
        self.assertEqual(
            FILEPV.COMET.digest(bytes.fromhex(time_only["attempt"]["vote"]["signBytes"])),
            "685d1cd1939e269cf0537b6257b3538beeae6588a1372040c84d0e5da95cd905",
        )

    def test_each_phase_stages_the_current_guarded_source_not_the_previous_copy(self):
        _, pins, _, _, native, _, _ = FILEPV.inputs()
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            private = root / "private"
            source = private / FILEPV.FAULT_PATH
            source.parent.mkdir(parents=True)
            for phase, content in (("normal", b"stock source"), ("mutant", b"changed source"),
                                   ("restored", b"stock source")):
                source.write_bytes(content)
                manifest = {"files": {FILEPV.FAULT_PATH: FILEPV.COMET.file_entry(content)}}
                output = root / phase
                executed = FILEPV.stage(output, private, manifest, pins, native)
                self.assertEqual((output / "inputs/file.go").read_bytes(), content)
                self.assertEqual(executed["inputs/file.go"], FILEPV.COMET.digest(content))
                self.assertEqual(
                    executed["modfiles/go.sum"],
                    FILEPV.COMET.digest((output / "modfiles/go.sum").read_bytes()),
                )
                self.assertEqual(
                    executed["modfiles/go.mod"],
                    FILEPV.COMET.digest((output / "modfiles/go.mod").read_bytes()),
                )
            source.write_bytes(b"stale source")
            with self.assertRaisesRegex(ValueError, "current guarded source"):
                FILEPV.stage(root / "stale", private, manifest, pins, native)
