"""Collector checks built from the Go JSON format and independently frozen rows."""

import copy
from importlib import util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest


ETNA = Path(__file__).resolve().parents[2]
PACKAGE = "example.org/etna-vote-wire"
PARENT = "TestEtnaVoteWire"
TIME = "2026-01-01T00:00:00.000000001Z"


def event(action, test=None, output=None, kind=None):
    row = {"Time": TIME, "Action": action, "Package": PACKAGE}
    if test is not None:
        row["Test"] = test
    if output is not None:
        row["Output"] = output
    if kind is not None:
        row["OutputType"] = kind
    if action == "pass":
        row["Elapsed"] = 0.001
    return row


def begin(test):
    return [event("run", test), event("output", test, f"=== RUN   {test}\n", "frame")]


def finish(test):
    return [event("output", test, f"--- PASS: {test} (0.00s)\n", "frame"), event("pass", test)]


def capture(rows):
    events = [event("start"), *begin(PARENT)]
    for row in rows:
        test = f"{PARENT}/{row['id']}"
        payload = json.dumps(row, separators=(",", ":"))
        events.extend([*begin(test), event("output", test, f"    vote_wire_test.go:71: receipt={payload}\n"),
                       *finish(test)])
    events.extend([*finish(PARENT), event("output", output="PASS\n", kind="frame"),
                   event("output", output=f"ok  \t{PACKAGE}\t0.002s\n"), event("pass")])
    return events


def stream(events):
    return b"".join(json.dumps(row).encode() + b"\n" for row in events)


class VoteWireRunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = util.spec_from_file_location("unsigned_wire_runner", ETNA / "conformance/run_vote_wire.py")
        cls.runner = util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        cls.corpus = json.loads((ETNA / "draft_rules/vote_wire_vectors.json").read_bytes())
        cls.expected = json.loads((ETNA / "draft_rules/vote_wire_native_expectations.json").read_bytes())

    def observations(self):
        rows = copy.deepcopy(self.expected["rows"])
        for index, row in enumerate(rows):
            vector = self.corpus["vectors"][index]
            self.assertEqual(vector["id"], row["id"])
            if row["wireHex"] is not None:
                self.assertEqual(row["wireHex"], f"/vectors/{index}/wireHex")
                row["wireHex"] = vector["wireHex"]
        return rows

    def test_project_only_inputs_in_frozen_order(self):
        corpus = copy.deepcopy(self.corpus)
        corpus["vectors"][0]["input"]["annotation"] = "must not be mounted"
        projected = self.runner.project_inputs(corpus)
        self.assertEqual(set(projected), {"schema", "chainId", "rows"})
        self.assertEqual(projected["chainId"], self.corpus["chainId"])
        self.assertEqual(projected["rows"], [{"id": row["id"], "input": row["input"]}
                                            for row in self.corpus["vectors"]])
        self.assertEqual(self.runner.project_inputs(corpus, ["nil-epoch"])["rows"], projected["rows"][:1])
        for ids in ([], ["nil-epoch", "nil-epoch"], ["missing"]):
            with self.subTest(ids=ids), self.assertRaises(ValueError):
                self.runner.project_inputs(corpus, ids)

    def test_exact_full_and_smoke_event_streams(self):
        rows = self.observations()
        for selection, observations in ((None, rows), ([rows[0]["id"]], rows[:1])):
            receipt = self.runner.collect_native(stream(capture(observations)), 0, self.corpus,
                                                 self.expected, ids=selection)
            self.assertEqual(receipt["observations"], observations)

    def test_wrong_row_identity_boolean_bytes_and_oracle_reference(self):
        baseline = self.observations()
        self.runner.validate_observations(self.corpus, self.expected, baseline)
        for change in ({"id": "nil-prevote"}, {"blockIdIsZero": 1}, {"timestampAccepted": False},
                       {"marshalAttempted": False}, {"panicked": True}, {"wireHex": "00"},
                       {"blockIdComplete": True}, {"wireHex": None}, {"status": "PASS"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.runner.validate_observations(self.corpus, self.expected,
                                                  [baseline[0] | change, *baseline[1:]])
        for rows in (baseline[:-1], baseline + baseline[:1], baseline[::-1]):
            with self.subTest(count=len(rows)), self.assertRaises(ValueError):
                self.runner.validate_observations(self.corpus, self.expected, rows)
        expected = copy.deepcopy(self.expected)
        # Identical bytes for nil-epoch and nil-empty-slices still have distinct identities.
        expected["rows"][0]["wireHex"] = "/vectors/2/wireHex"
        with self.assertRaises(ValueError):
            self.runner.validate_observations(self.corpus, expected, baseline)

    def test_event_custody_and_terminal_status(self):
        observations = self.observations()[:1]
        ids = [observations[0]["id"]]
        valid = capture(observations)
        for index, changes in ((0, {"Package": "other"}), (3, {"Test": PARENT + "/other"}),
                               (5, {"OutputType": "frame"}), (5, {"Output": "PASS\n"}),
                               (6, {"Action": "skip"}), (7, {"Action": "fail"})):
            wrong = copy.deepcopy(valid)
            wrong[index].update(changes)
            with self.subTest(index=index, changes=changes), self.assertRaises(ValueError):
                self.runner.collect_native(stream(wrong), 0, self.corpus, self.expected, ids)
        for raw, status in ((stream(valid[1:]), 0), (stream(valid[:-1]), 0),
                            (stream(valid[:5] + valid[6:]), 0), (stream(valid[:6] + valid[5:]), 0),
                            (stream(valid) + stream(valid[-1:]), 0), (stream(valid) + b"garbage\n", 0),
                            (stream(valid), 1), (stream(valid), False),
                            (b'{"observations":[],"status":"PASS"}\n', 0)):
            with self.subTest(status=status, size=len(raw)), self.assertRaises(ValueError):
                self.runner.collect_native(raw, status, self.corpus, self.expected, ids)

    def test_duplicate_json_keys_and_malformed_receipt(self):
        valid = capture(self.observations()[:1])
        test = valid[5]["Test"]
        for raw in (
            stream(valid).replace(b'"Action": "start"', b'"Action":"start","Action":"start"', 1),
            stream(valid[:5] + [event("output", test, valid[5]["Output"].replace(
                '"panicked":false', '"panicked":false,"panicked":false'))] + valid[6:]),
            stream(valid[:5] + [event("output", test, valid[5]["Output"].rstrip() + " x\n")] + valid[6:]),
        ):
            with self.assertRaises(ValueError):
                self.runner.collect_native(raw, 0, self.corpus, self.expected, ["nil-epoch"])

    def test_smoke_revalidates_raw_capture_bytes_staging_and_physical_custody(self):
        runner = self.runner
        common = runner.native_helpers()
        inputs = runner.StockInputs(common)
        self.assertEqual(runner.SMOKE, "zero32-hash-only")
        row = next(row for row in self.observations() if row["id"] == runner.SMOKE)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "smoke"
            directory.mkdir()
            args = SimpleNamespace(source=root / "source", go_root=root / "sdk",
                                   module_cache=root / "modules", build_cache=root / "build",
                                   smoke_output=directory)
            files = inputs.stage_files([runner.SMOKE])
            for name, data in files.items():
                path = directory / name
                path.parent.mkdir(exist_ok=True)
                path.write_bytes(data)
            staged = runner.stage_inventory(common, directory, files)
            physical = {"sharedCacheLock": {"device": 7, "inode": 41}}
            selected = "^TestEtnaVoteWire$/^zero32-hash-only$"
            command = common.isolation_command(None, directory, args.source, args, selected)
            raw = stream(capture([row]))
            log = directory / "combined.log"
            log.write_bytes(raw)
            record = dict(schema="etna-vote-wire-execution-1", phase="smoke", package=PACKAGE,
                          parent=PARENT, filter=selected, command=command,
                          supervisorCommand=[sys.executable, "-B", str(common.LEASED.PATH),
                                             "--_supervise_leased", "5", "123", "110", str(runner.ROOT), *command],
                          supervisorReturncode=200, returncode=0, timedOut=False, seconds=0.012,
                          streamsCombined=True, outputDecoding="utf-8-errors-replace",
                          combinedOutputSha256=runner.digest(raw), before=physical, after=physical,
                          stagedBefore=staged, stagedAfter=staged, observations=[row])
            execution = directory / "execution.json"
            execution.write_bytes(runner.encoded(record))
            summary = dict(schema="etna-vote-wire-result-1", phase="smoke", status="PASS",
                           executionSha256=runner.digest(execution.read_bytes()),
                           combinedOutputSha256=runner.digest(raw), cases=1)
            (directory / "summary.json").write_bytes(runner.encoded(summary))
            self.assertEqual(runner.require_smoke(common, args, inputs, physical)["cases"], 1)
            for change in ({"returncode": False}, {"timedOut": True}, {"phase": "full"},
                           {"supervisorReturncode": 0}, {"command": command[:-1]}, {"before": {}},
                           {"stagedAfter": {}}, {"observations": [row | {"blockIdIsZero": True}]}):
                execution.write_bytes(runner.encoded(record | change))
                with self.subTest(change=next(iter(change))), self.assertRaises(ValueError):
                    runner.require_smoke(common, args, inputs, physical)
            execution.write_bytes(runner.encoded(record))
            with self.assertRaises(ValueError):
                runner.require_smoke(common, args, inputs, {"sharedCacheLock": {"device": 7, "inode": 42}})
            log.write_bytes(raw + b"extra\n")
            with self.assertRaises(ValueError):
                runner.require_smoke(common, args, inputs, physical)
            log.write_bytes(raw)
            extra = directory / "inputs/unexpected.go"
            extra.write_text("package other\n")
            with self.assertRaises(ValueError):
                runner.require_smoke(common, args, inputs, physical)
            extra.unlink()
            (directory / "modfiles/go.mod").write_bytes(files["inputs/go.mod"])
            with self.assertRaises(ValueError):
                runner.require_smoke(common, args, inputs, physical)

    def test_single_physical_lock_and_contention(self):
        common = self.runner.native_helpers()
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "build.lock"
            path.touch()
            with self.runner.build_lease(common, path) as (fd, identity):
                self.assertGreaterEqual(fd, 3)
                self.assertEqual(identity, common.identity(path))
                with self.assertRaises(BlockingIOError), self.runner.build_lease(common, path):
                    self.fail("a second open file description acquired the lease")
            alias = path.with_suffix(".alias")
            alias.symlink_to(path)
            with self.assertRaises(ValueError), self.runner.build_lease(common, alias):
                self.fail("a symlink acquired the lease")
