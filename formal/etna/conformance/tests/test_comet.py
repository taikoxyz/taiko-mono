"""Reject plausible false-positive Go execution records."""
import copy
import contextlib
import io
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

PATH = Path(__file__).resolve().parents[1] / "run_comet.py"
spec = importlib.util.spec_from_file_location("etna_comet", PATH)
MODULE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(MODULE)
NAMES = ["equal-times", "parent-dominates", "later-anchor", "wrong-bft-time",
         "wrong-initial-height", "retained-last-block-id", "nonempty-last-commit"]


def native_mutant_lines():
    # Literal native Go output from both actual calls, not a successful package
    # label or failure identity alone. Source line numbers are incidental.
    return [
        "=== RUN   TestFirstBlockBoundary/wrong-bft-time",
        "    first_block_test.go:186: wrong BFT time offset=1s; actual=1970-01-01T00:00:04Z genesis=1970-01-01T00:00:03Z",
        '    first_block_test.go:187: expected exact rejection "block time 1970-01-01 00:00:04 +0000 UTC is not equal to genesis time 1970-01-01 00:00:03 +0000 UTC", got <nil>',
        "    first_block_test.go:187: rejected header reached evidence pool 1 times",
        "    first_block_test.go:186: wrong BFT time offset=1ns; actual=1970-01-01T00:00:03.000000001Z genesis=1970-01-01T00:00:03Z",
        '    first_block_test.go:187: expected exact rejection "block time 1970-01-01 00:00:03.000000001 +0000 UTC is not equal to genesis time 1970-01-01 00:00:03 +0000 UTC", got <nil>',
        "    first_block_test.go:187: rejected header reached evidence pool 1 times",
        "--- FAIL: TestFirstBlockBoundary/wrong-bft-time (0.00s)",
    ]


def events(mutant=False):
    package = "example.org/etna-comet-first-block"
    rows = [{"Action": "start", "Package": package},
            {"Action": "run", "Package": package, "Test": "TestFirstBlockBoundary"}]
    for name in NAMES:
        identity = "TestFirstBlockBoundary/" + name
        rows.append({"Action": "run", "Package": package, "Test": identity})
        if mutant and name == "wrong-bft-time":
            rows.extend({"Action": "output", "Package": package, "Test": identity, "Output": line + "\n"}
                        for line in native_mutant_lines())
        rows.append({"Action": "fail" if mutant and name == "wrong-bft-time" else "pass",
                     "Package": package, "Test": identity})
    action = "fail" if mutant else "pass"
    rows.extend([{"Action": action, "Package": package, "Test": "TestFirstBlockBoundary"},
                 {"Action": action, "Package": package}])
    return rows


def raw(rows):
    return "\n".join(json.dumps(row) for row in rows).encode()


class CometRecorderTests(unittest.TestCase):
    def test_exact_normal_and_restored(self):
        for phase in ("normal", "restored"):
            self.assertEqual(len(MODULE.require_go_outcomes(raw(events()), 0, phase)), 7)

    def test_exact_mutant_failure(self):
        self.assertEqual(len(MODULE.require_go_outcomes(raw(events(True)), 1, "mutant")), 7)

    def test_package_pass_without_tests_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.require_go_outcomes(raw([events()[-1]]), 0, "normal")

    def test_empty_log_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.require_go_outcomes(b"", 0, "normal")

    def test_missing_duplicate_skipped_unexpected_and_failed_rejected(self):
        baseline = events()
        variants = [baseline[:2] + baseline[4:], baseline + [baseline[2]],
                    copy.deepcopy(baseline), copy.deepcopy(baseline), copy.deepcopy(baseline)]
        variants[2][3]["Action"] = "skip"
        variants[3][2]["Test"] = "TestUnexpected"
        variants[4][3]["Action"] = "fail"
        for index, rows in enumerate(variants):
            with self.subTest(variant=index):
                with self.assertRaises(ValueError):
                    MODULE.require_go_outcomes(raw(rows), 0, "normal")

    def test_wrong_mutant_failure_or_returncode_rejected(self):
        rows = events(True)
        rows[3]["Action"] = "fail"
        for payload, code in [(events(), 0), (rows, 1), (events(True), 0), (events(True), 2)]:
            with self.assertRaises(ValueError):
                MODULE.require_go_outcomes(raw(payload), code, "mutant")

    def test_wrong_package_malformed_and_invalid_phase_rejected(self):
        rows = events()
        rows[2]["Package"] = "unrelated/package"
        for payload, phase in [(raw(rows), "normal"), (b"not json", "normal"),
                               (raw(events()), "unknown")]:
            with self.assertRaises(ValueError):
                MODULE.require_go_outcomes(payload, 0, phase)


    def test_missing_one_offset_duplicate_or_unrelated_semantics_rejected(self):
        baseline = events(True)
        output_positions = [i for i,row in enumerate(baseline) if row["Action"] == "output"]
        variants = [
            [row for row in baseline if row["Action"] != "output"],
            [row for i,row in enumerate(baseline) if i not in output_positions[4:7]],
            baseline + [baseline[output_positions[2]]],
        ]
        for index, replacement in [(1, "unrelated fixture setup failure\n"),
                                   (2, baseline[output_positions[2]]["Output"].replace("<nil>", "wrong Block.Header.AppHash")),
                                   (3, baseline[output_positions[3]]["Output"].replace("1 times", "0 times")),
                                   (4, baseline[output_positions[1]]["Output"]),
                                   (5, baseline[output_positions[2]]["Output"]),
                                   (7, "--- FAIL: unrelated frame\n")]:
            rows = copy.deepcopy(baseline)
            rows[output_positions[index]]["Output"] = replacement
            variants.append(rows)
        # Valid native diagnostics plus an unrelated error must also fail.
        extra = copy.deepcopy(baseline[output_positions[3]])
        extra["Output"] = "    first_block_test.go:187: unrelated fixture setup failure\n"
        variants.append(baseline + [extra])
        for index, rows in enumerate(variants):
            with self.subTest(variant=index):
                with self.assertRaisesRegex(ValueError, "time|diagnostic|semantic"):
                    MODULE.require_go_outcomes(raw(rows), 1, "mutant")


    def test_supervisor_cleanup_failure_result_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            data = b"package sample\n"
            (source / "source.go").write_bytes(data)
            manifest = {"schema": "etna-source-snapshot-1", "commit": "a" * 40,
                        "files": {"source.go": MODULE.file_entry(data)}}
            args = SimpleNamespace(output=root / "output", go_root=root / "sdk",
                                   module_cache=root / "modules", build_cache=root / "cache", timeout=1)
            failed_cleanup = {"returncode": 125, "timeout": False,
                              "supervisor_argv": ["scoped-supervisor"], "output": raw(events()).decode()}
            with mock.patch.object(MODULE.EXECUTION, "execute", return_value=failed_cleanup):
                with self.assertRaisesRegex(ValueError, "cleanup failed.*125"):
                    MODULE.run_trial("normal", source, manifest, args, {"source": {"commit": "a" * 40}}, {})
            record = json.loads((args.output / "normal/execution.json").read_text())
            self.assertEqual(record["returncode"], 125)
            self.assertNotIn("outcomes", record)
            self.assertTrue(record["streamsCombined"])
            self.assertNotIn("stdoutSha256", record)
            self.assertNotIn("stderrSha256", record)
            self.assertEqual((args.output / "normal/combined.log").read_bytes(), raw(events()))
            self.assertFalse((args.output / "summary.json").exists())


class CometLayoutTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="etna-comet-layout-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.formal = self.root / "formal"
        (self.formal / "conformance").mkdir(parents=True)
        helper = self.formal / "sensitivity/run.py"
        helper.parent.mkdir()
        helper.write_text("helper fixture")
        external = self.root / "external-inputs/SPEC.md"
        external.parent.mkdir()
        external.write_text("external watched fixture")
        self.watched = {helper: MODULE.digest(helper.read_bytes()), external: MODULE.digest(external.read_bytes())}
        self.paths = {name: self.root / name for name in ("source", "go_root", "module_cache", "build_cache")}
        for path in self.paths.values():
            path.mkdir()
        (self.paths["go_root"] / "bin").mkdir()
        (self.paths["go_root"] / "bin/go").write_text("unexecuted fixture")
        (self.paths["go_root"] / "VERSION").write_text("unexecuted fixture")
        self.paths["output"] = self.root / "output"

    def gate(self, accepted, **overrides):
        class ReachedSourceVerification(BaseException):
            pass
        values = {**self.paths, **overrides}
        output_existed = values["output"].exists()
        argv = [part for name,path in values.items() for part in ("--" + name.replace("_", "-"), str(path))]
        with mock.patch.object(MODULE, "ROOT", self.formal / "conformance"), \
             mock.patch.object(MODULE, "inputs", return_value=({"source": {"commit": "a" * 40}}, {}, self.watched)), \
             mock.patch.object(MODULE, "verify_snapshot", side_effect=ReachedSourceVerification), \
             contextlib.redirect_stderr(io.StringIO()):
            if accepted:
                with self.assertRaises(ReachedSourceVerification):
                    MODULE.main(argv)
            else:
                try:
                    code = MODULE.main(argv)
                except ReachedSourceVerification:
                    self.fail("unsafe layout reached source execution preparation")
                self.assertEqual(code, 1)
        self.assertEqual(values["output"].exists(), output_existed, "preflight created output state")

    def test_valid_disjoint_layout_reaches_source_verification(self):
        self.gate(True)

    def test_output_inside_build_cache_rejected(self):
        self.gate(False, output=self.paths["build_cache"] / "output")

    def test_output_equal_or_ancestor_of_cache_rejected(self):
        self.gate(False, output=self.paths["build_cache"])
        self.gate(False, output=self.root)

    def test_cache_covering_watched_sibling_helper_rejected(self):
        self.gate(False, build_cache=self.formal / "sensitivity")

    def test_cache_covering_external_watched_input_rejected(self):
        self.gate(False, build_cache=self.root / "external-inputs")

    def test_symlink_aliases_cannot_bypass_layout_checks(self):
        alias = self.root / "alias"
        alias.symlink_to(self.paths["build_cache"], target_is_directory=True)
        self.gate(False, output=alias / "output")
        alias.unlink()
        alias.symlink_to(self.formal / "sensitivity", target_is_directory=True)
        self.gate(False, build_cache=alias)


class CometSourceTests(unittest.TestCase):
    def test_extra_missing_changed_and_symlink_sources_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.go"
            source.write_bytes(b"package sample\n")
            manifest = {"schema": "etna-source-snapshot-1", "commit": "a" * 40,
                        "files": {"source.go": MODULE.file_entry(source.read_bytes())}}
            self.assertEqual(MODULE.verify_snapshot(root, manifest, "a" * 40)["files"], 1)
            extra = root / "extra.go"
            extra.write_bytes(b"package sample\n")
            with self.assertRaisesRegex(ValueError, "extra"):
                MODULE.verify_snapshot(root, manifest, "a" * 40)
            extra.unlink()
            source.write_bytes(b"package changed\n")
            with self.assertRaisesRegex(ValueError, "bytes differ"):
                MODULE.verify_snapshot(root, manifest, "a" * 40)
            source.unlink()
            with self.assertRaisesRegex(ValueError, "missing"):
                MODULE.verify_snapshot(root, manifest, "a" * 40)
            source.symlink_to("missing")
            with self.assertRaisesRegex(ValueError, "symlink"):
                MODULE.verify_snapshot(root, manifest, "a" * 40)

    def test_private_fault_changes_only_target_and_preserves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / "source"
            path = source / MODULE.FAULT_PATH
            path.parent.mkdir(parents=True)
            path.write_text("before\n" + MODULE.FAULT_BEFORE + "after\n")
            original = path.read_bytes()
            manifest = {"schema": "etna-source-snapshot-1", "commit": "a" * 40,
                        "files": {MODULE.FAULT_PATH: MODULE.file_entry(original)}}
            private = base / "private"
            mutant = MODULE.private_fault(source, private, manifest)
            self.assertEqual(path.read_bytes(), original)
            self.assertNotEqual(mutant["files"][MODULE.FAULT_PATH], manifest["files"][MODULE.FAULT_PATH])
            MODULE.verify_snapshot(private, mutant, "a" * 40)
            (private / MODULE.FAULT_PATH).write_bytes(original)
            MODULE.verify_snapshot(private, manifest, "a" * 40)
            path.write_text("selector absent")
            with self.assertRaisesRegex(ValueError, "exactly once"):
                MODULE.private_fault(source, base / "invalid", manifest)


if __name__ == "__main__":
    unittest.main()
