"""Exercise the real entrypoint with disposable Cargo/Docker/helper executables, and keep its
hand-listed test selection attached to the Rust test tree."""
from collections import namedtuple
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

from selected_dependencies import LONG_FENCE, NATIVE_EL, RECOVERY_IMAGE

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "bin/client/tests"


class Entrypoint(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("tests", "script", "bin"):
            (self.root / name).mkdir()
        for source in (ROOT / "tests").glob("*"):
            if source.name in ("entrypoint.sh", "selected_dependencies.py"):
                shutil.copy(source, self.root / "tests" / source.name)
        self.log = self.root / "calls"
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        CALLS=str(self.log), SELECTION='{}', TAIKO_CLIENT_RS_TEST_RUN="fixture-run")
        for key in ("ETNA_RECOVERY_IMAGE", "ETNA_EL_BIN", "ETNA_EL_IMPORT_BIN", "NEXTEST_PROFILE"):
            self.env.pop(key, None)
        self.executable("bin/cargo", '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(['cargo'] + sys.argv[1:]) + '\\n')
if sys.argv[2] == 'list':
    if os.environ.get('LIST_WAIT'):
        pathlib.Path(os.environ['LIST_WAIT']).touch()
        time.sleep(60)
    for flag in ('--nocapture', '--no-capture'):
        if flag in sys.argv:
            print(f"error: unexpected argument '{flag}' found", file=sys.stderr)
            sys.exit(2)
    if '--message-format=human' in sys.argv:
        print('human listing')
        sys.exit(0)
    if os.environ.get('LIST_ERROR'):
        print(os.environ['LIST_ERROR'], file=sys.stderr)
        sys.exit(int(os.environ.get('LIST_STATUS', '2')))
    print(os.environ['SELECTION'])
else:
    if os.environ.get('WAIT'):
        pathlib.Path(os.environ['WAIT']).touch()
        time.sleep(60)
    sys.exit(int(os.environ.get('RUN_STATUS', '0')))
''')
        self.executable("bin/docker", '''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(['docker'] + sys.argv[1:]) + '\\n')
if sys.argv[1] == 'info' and os.environ.get('NO_DOCKER'): sys.exit(1)
if sys.argv[1] == 'ps': print('owned-container')
if sys.argv[1:3] == ['network', 'ls']: print('owned-network')
''')
        for name in ("etna_signer", "stock_comet", "etna_el_import", "etna_el_runtime", "recovery_runtime"):
            self.executable(f"script/build_{name}.sh", f'''#!/bin/bash
printf '["build", "{name}"]\\n' >> "$CALLS"
''')

    def executable(self, name, contents):
        path = self.root / name
        path.write_text(contents)
        path.chmod(0o755)

    def select(self, binary, *names):
        package = {"governance_recovery": "taiko-client", "cleanup": "test-harness",
                   "standalone_reth": "test-harness"}.get(binary, "abci")
        self.env["SELECTION"] = json.dumps({"rust-suites": {"fixture": {
            "package-name": package, "binary-name": binary, "status": "listed",
            "testcases": {name: {"filter-match": {"status": "matches"}} for name in names}}}})

    def run_entrypoint(self, *args):
        return subprocess.run(["bash", str(self.root / "tests/entrypoint.sh"), *args],
                              env=self.env, text=True, capture_output=True, timeout=15)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def builds(self):
        return [row[1] for row in self.calls() if row[0] == "build"]

    def test_ordinary_scenario_avoids_native_builds_and_preserves_run_arguments(self):
        self.select("single_validator", "single_validator_produces_blocks_by_the_header_rules")
        args = ("--no-capture", "-E", "test(a) | test(b)", "--", "--exact", "--skip", "other")
        result = self.run_entrypoint(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.builds(), ["etna_signer"])
        calls = self.calls()
        self.assertEqual(calls[0][0:3], ["cargo", "nextest", "list"])
        run = next(row for row in calls if row[:3] == ["cargo", "nextest", "run"])
        self.assertEqual(run[-len(args):], list(args))
        listed = calls[0]
        self.assertNotIn("--no-capture", listed)
        self.assertIn("test(a) | test(b)", listed)
        self.assertEqual(run[3:run.index("--no-capture")], listed[3:listed.index("--message-format")])

    def test_nocapture_alias_is_run_only(self):
        self.select("single_validator", "single_validator_produces_blocks_by_the_header_rules")
        result = self.run_entrypoint("--nocapture", "restart")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        listed = calls[0]
        self.assertEqual(listed[:3], ["cargo", "nextest", "list"])
        run = next(row for row in calls if row[:3] == ["cargo", "nextest", "run"])
        self.assertNotIn("--nocapture", listed)
        self.assertEqual(run[-2:], ["--nocapture", "restart"])

    def test_standalone_reth_only_prepares_docker(self):
        self.select("standalone_reth", "occupied_initial_auth_port_recovers_and_preserves_restart_endpoints")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.builds(), [])
        self.assertIn(["docker", "info"], self.calls())

    def test_native_checkpoint_prepares_el_and_comet_without_recovery_image(self):
        self.select("governance_recovery", "support::checkpoint_import::registered_checkpoint_latest_signs_proposes_and_lands")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.builds()), {"etna_signer", "stock_comet", "etna_el_import", "etna_el_runtime"})

    def test_both_recovery_image_consumers_and_override(self):
        for name in ("governance_recovery_linux_comet_uid_reads_p2p_and_cannot_read_registered_key",
                     "governance_recovery_sigkill_boundaries_replay_without_duplicate_owners"):
            for override in (False, True):
                with self.subTest(name=name, override=override):
                    self.log.unlink(missing_ok=True)
                    self.select("governance_recovery", name)
                    if override:
                        self.env["ETNA_RECOVERY_IMAGE"] = "external:image"
                    else:
                        self.env.pop("ETNA_RECOVERY_IMAGE", None)
                    result = self.run_entrypoint()
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(set(self.builds()), {"etna_signer", "stock_comet"} |
                                     (set() if override else {"recovery_runtime"}))
                    removed = [row for row in self.calls() if row[:3] == ["docker", "image", "rm"]]
                    self.assertEqual(len(removed), 0 if override else 1)

    def test_non_consumers_and_filtered_cases_do_not_build_recovery(self):
        self.select("governance_recovery", "governance_recovery_command_produces_and_lands")
        data = json.loads(self.env["SELECTION"])
        data["rust-suites"]["fixture"]["testcases"]["governance_recovery_sigkill_boundaries_replay_without_duplicate_owners"] = {"filter-match": {"status": "mismatch"}}
        self.env["SELECTION"] = json.dumps(data)
        self.assertEqual(self.run_entrypoint().returncode, 0)
        self.assertEqual(set(self.builds()), {"etna_signer", "stock_comet"})

    def test_empty_selection_preserves_nextest_exit_without_docker(self):
        self.env["SELECTION"] = json.dumps({"rust-suites": {}})
        self.env["RUN_STATUS"] = "4"
        result = self.run_entrypoint("no-such-case")
        self.assertEqual(result.returncode, 4, result.stderr)
        self.assertEqual([row[0] for row in self.calls()], ["cargo", "cargo"])

    def test_docker_failure_precedes_all_helpers(self):
        self.select("governance_recovery", "governance_recovery_command_produces_and_lands")
        self.env["NO_DOCKER"] = "1"
        self.assertNotEqual(self.run_entrypoint().returncode, 0)
        self.assertEqual(self.builds(), [])

    def test_run_only_option_falls_back_without_losing_argv(self):
        self.env["LIST_ERROR"] = "error: unexpected argument '--retries' found"
        result = self.run_entrypoint("--retries", "1", "restart")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.builds()), {"etna_signer", "stock_comet", "etna_el_import", "etna_el_runtime", "recovery_runtime"})
        run = next(row for row in self.calls() if row[:3] == ["cargo", "nextest", "run"])
        self.assertEqual(run[-3:], ["--retries", "1", "restart"])

    def test_run_reporter_uses_conservative_preparation(self):
        self.select("single_validator", "single_validator_produces_blocks_by_the_header_rules")
        result = self.run_entrypoint("--message-format=human")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.builds()), {"etna_signer", "stock_comet", "etna_el_import", "etna_el_runtime", "recovery_runtime"})
        run = next(row for row in self.calls() if row[:3] == ["cargo", "nextest", "run"])
        self.assertEqual(run[-1], "--message-format=human")

    def test_native_fence_only_prepares_el(self):
        self.select("governance_recovery", "support::checkpoint_import::long_fence::native_long_fence_restarts_and_executes_with_body_pruned_parents")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.builds()), {"etna_el_import", "etna_el_runtime"})

    def test_sigterm_during_discovery_does_not_prepare_or_touch_docker(self):
        ready = self.root / "listing"
        self.env["LIST_WAIT"] = str(ready)
        with subprocess.Popen(["bash", str(self.root / "tests/entrypoint.sh")], env=self.env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as child:
            deadline = time.monotonic() + 10
            while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(ready.exists(), "entrypoint never started discovery")
            child.send_signal(signal.SIGTERM)
            self.assertEqual(child.wait(timeout=3), 143)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.calls()[0][:3], ["cargo", "nextest", "list"])

    def test_list_build_and_json_errors_fail_before_preparation(self):
        for error, status, selection in (("compilation failed", "101", '{}'),
                                          ("error: unexpected argument '--typo' found", "2", '{}'),
                                          ("", "0", 'invalid json')):
            with self.subTest(error=error, selection=selection):
                self.log.unlink(missing_ok=True)
                self.env.update(LIST_ERROR=error, LIST_STATUS=status, SELECTION=selection)
                self.assertNotEqual(self.run_entrypoint().returncode, 0)
                self.assertEqual(len(self.calls()), 1)

    def test_sigterm_forwards_and_cleans_only_its_run(self):
        self.select("cleanup", "sigterm_removes_owned_resources_and_preserves_sibling_devnets")
        ready = self.root / "ready"
        self.env["WAIT"] = str(ready)
        with subprocess.Popen(["bash", str(self.root / "tests/entrypoint.sh")], env=self.env,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as child:
            deadline = time.monotonic() + 10
            while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(ready.exists(), "entrypoint never reached its selected test")
            child.send_signal(signal.SIGTERM)
            self.assertEqual(child.wait(timeout=3), 143)
        self.assertEqual(self.builds(), [])
        self.assertIn(["docker", "ps", "-aq", "--filter", "label=taiko-client-rs.test-run=fixture-run"], self.calls())
        self.assertIn(["docker", "rm", "-f", "-v", "owned-container"], self.calls())
        self.assertIn(["docker", "network", "rm", "owned-network"], self.calls())


# Only callers that pass `with_import = true` reach `support::checkpoint_import::recovered`, and
# those callers are listed in NATIVE_EL by hand.
CONDITIONAL_EL_HELPERS = {"checkpoint_roundtrip"}
# Lander tests call `ContractConsensus::start` with docker Comet; only the native starts need the
# stock binary.
NATIVE_MARKERS = {
    "recovery": re.compile(r"\bLinuxRuntime::start\b"),
    "el": re.compile(r'"ETNA_EL_BIN"|"ETNA_EL_IMPORT_BIN"'),
    "comet_or_signer": re.compile(r'"ETNA_COMET_BIN"|\bContractConsensus::start_(?:native|registered)\b'),
}
FN = re.compile(r"^(?:pub(?:\(\w+\))? )?(?:async )?fn (\w+)", re.M)
ITEM = re.compile(r"^(?:#!?\[|//|(?:pub(?:\([^)]*\))? )?(?:(?:async|const|unsafe|extern) )*"
                  r"(?:(?:fn|impl|struct|enum|union|mod|use|const|static|type|trait)\b|macro_rules!))")
# `x::B(` calls B (and an associated fn of type x); `.B(` method calls never add an edge.
CALL = re.compile(r"(?<![.\w])(?:(\w+)::)?(\w+)\s*\(")


def rust_test_files(root=ROOT):
    return sorted((root / "bin/client/tests").rglob("*.rs")) + sorted((root / "crates").glob("*/tests/**/*.rs"))


def native_sources(root):
    """governance_recovery.rs and the support modules it declares (`X.rs`, `X/**`), keyed under bin/client/tests."""
    tests = root / "bin/client/tests"
    block = re.search(r"^mod support \{$(.*?)^\}$", (tests / "governance_recovery.rs").read_text(), re.M | re.S)
    if not block:
        raise AssertionError("governance_recovery.rs declares no `mod support { … }` block; extend the guard")
    paths = [tests / "governance_recovery.rs"]
    for name in re.findall(r"\bmod (\w+);", block.group(1)):
        module = tests / "support" / name
        paths += [path for path in [module.with_suffix(".rs")] if path.exists()] + sorted(module.rglob("*.rs"))
    return {path.relative_to(tests).as_posix(): path.read_text() for path in paths}


def stray_native_markers(root, native):
    """Native markers in any test file outside the governance_recovery binary's own modules."""
    tests = root / "bin/client/tests"
    return [f"{path.relative_to(root).as_posix()}:{line}: {key}" for path in rust_test_files(root)
            if not (path.is_relative_to(tests) and path.relative_to(tests).as_posix() in native)
            for line, key in native_markers(path.read_text())]


def module_prefix(relative):
    """`governance_recovery.rs` is a crate root; `support/a.rs` is `support::a::`; `mod.rs` is its directory."""
    parts = list(Path(relative).with_suffix("").parts)
    if parts[-1] == "mod":
        parts.pop()
    elif len(parts) == 1:
        parts = []
    return "".join(f"{part}::" for part in parts)


def column_zero_fns(path):
    tests = TESTS if TESTS in path.parents else ROOT / "crates" / path.relative_to(ROOT / "crates").parts[0] / "tests"
    prefix = module_prefix(path.relative_to(tests))
    return {prefix + match.group(1) for match in FN.finditer(path.read_text())}


def native_markers(text):
    """(line, marker) for every native runtime marker outside `//` comment lines."""
    for number, line in enumerate(text.splitlines(), 1):
        if not line.lstrip().startswith("//"):
            yield from ((number, key) for key, marker in NATIVE_MARKERS.items() if marker.search(line))


RustItem = namedtuple("RustItem", "kind name qualified docker code")


def rust_items(path, text):
    """Column-0 free fns and impl blocks. An impl block is one unit that any `Type::f(` call
    reaches (`Commands::for_node` reads ETNA_COMET_BIN); method calls on its values add no edge."""
    lines, items, attributes, covered, index = text.splitlines(), [], [], set(), 0
    while index < len(lines):
        line = lines[index]
        header = FN.match(line)
        if header or line.startswith("impl"):
            end = index
            while not lines[end].startswith("}") and end + 1 < len(lines) and not ITEM.match(lines[end + 1]):
                end += 1
            code = "\n".join(row for row in lines[index:end + 1] if not row.lstrip().startswith("//"))
            if header:
                docker = any(a.startswith("#[tokio::test") for a in attributes) and '#[ignore = "docker"]' in attributes
                items.append(RustItem("fn", header.group(1), module_prefix(path) + header.group(1), docker, code))
            else:
                target = line.split("{")[0].split(" for ")[-1]
                target = re.sub(r"^impl\s*(<[^>]*>)?", "", target).split("<")[0]
                items.append(RustItem("impl", re.findall(r"\w+", target)[-1], None, False, code))
            covered.update(range(index + 1, end + 2))
            attributes, index = [], end + 1
            continue
        if line.startswith(("#[", "//")):
            attributes.append(line)
        elif line.strip():
            attributes = []
        index += 1
    for number, key in native_markers(text):
        if number not in covered:
            raise AssertionError(f"{path}:{number}: {key} marker outside a column-0 fn or impl block; "
                                 "move it into a free fn or extend the guard")
    return items


def docker_tests(sources):
    return {item.qualified for path, text in sources.items() for item in rust_items(path, text) if item.docker}


def scan_native_consumers(sources):
    """Docker tests per native marker they can reach; names are global, so this over-approximates."""
    items = [item for path, text in sources.items() for item in rust_items(path, text)]
    reached = [{key for _, key in native_markers(item.code)} for item in items]
    callees = []
    for item in items:
        calls = CALL.findall(item.code)
        called = {("fn", name) for _, name in calls if name not in CONDITIONAL_EL_HELPERS}
        called |= {("impl", owner) for owner, _ in calls if owner}
        callees.append([other for other, callee in enumerate(items) if (callee.kind, callee.name) in called])
    changed = True
    while changed:
        changed = False
        for index, edges in enumerate(callees):
            merged = reached[index].union(*(reached[other] for other in edges))
            changed |= merged != reached[index]
            reached[index] = merged
    return {key: {item.qualified for item, found in zip(items, reached) if item.docker and key in found}
            for key in NATIVE_MARKERS}


class SelectionDrift(unittest.TestCase):
    """Keep the hand-listed native consumers and entrypoint filters attached to the Rust tests."""

    @staticmethod
    def docker_test(name, body):
        return f'#[tokio::test(flavor = "multi_thread")]\n#[ignore = "docker"]\nasync fn {name}() -> Result<()> {{\n    {body}\n}}\n'

    def test_scanner_flags_renamed_and_unlisted_consumers(self):
        helper = 'fn h() -> Option<std::ffi::OsString> {\n    std::env::var_os("ETNA_EL_BIN")\n}\n'
        scanned = scan_native_consumers({"governance_recovery.rs": self.docker_test("a", "h();"), "support/x.rs": helper})
        self.assertEqual(scanned["el"], {"a"})
        self.assertEqual(scanned["recovery"], set())
        scanned = scan_native_consumers({"governance_recovery.rs": self.docker_test("b", "LinuxRuntime::start(&f, &c, &commands)?;")})
        self.assertEqual(scanned["recovery"], {"b"})
        self.assertEqual(scanned["el"], set())

    def test_scanner_module_paths_edges_and_unscannable_markers(self):
        commands = ('pub struct Commands;\nimpl Commands {\n    pub fn new() -> Self {\n'
                    '        let _ = std::env::var_os("ETNA_COMET_BIN");\n        Self\n    }\n}\n')
        scanned = scan_native_consumers({
            "governance_recovery.rs": self.docker_test("method_only", "x.h();") + self.docker_test("conditional", "checkpoint_roundtrip(true);")
            + self.docker_test("docker_comet", "ContractConsensus::start(url).await?;")
            + self.docker_test("native_comet", "ContractConsensus::start_native(url).await?;")
            + "async fn checkpoint_roundtrip(with_import: bool) {\n    support::checkpoint_import::recovered();\n}\n",
            "support/checkpoint_import.rs": 'pub fn recovered() {\n    let _ = "ETNA_EL_IMPORT_BIN";\n}\n'
            + self.docker_test("direct", "recovered();"),
            "support/checkpoint_import/nested.rs": self.docker_test("nested", "super::recovered();"),
            "support/recovery/mod.rs": commands + self.docker_test("uses_commands", "support::recovery::Commands::new();"),
            "support/x.rs": 'fn h() {\n    let _ = "ETNA_EL_BIN";\n}\n',
        })
        self.assertEqual(scanned["el"], {"support::checkpoint_import::direct", "support::checkpoint_import::nested::nested"})
        self.assertEqual(scanned["comet_or_signer"], {"native_comet", "support::recovery::uses_commands"})
        self.assertEqual(scanned["recovery"], set())
        with self.assertRaisesRegex(AssertionError, r"support/x\.rs:2: .*move it into a free fn or extend the guard"):
            scan_native_consumers({"support/x.rs": '/// "ETNA_EL_BIN" in a comment is ignored.\nconst BIN: &str = "ETNA_EL_BIN";\n'})

    def test_markers_outside_declared_governance_recovery_modules_are_stray(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            files = {
                "bin/client/tests/governance_recovery.rs": "mod support {\n    pub mod checkpoint_import;\n    pub mod recovery;\n}\n",
                "bin/client/tests/support/checkpoint_import.rs": 'fn el() {\n    let _ = "ETNA_EL_BIN";\n}\n',
                "bin/client/tests/support/checkpoint_import/long_fence.rs": 'fn el() {\n    let _ = "ETNA_EL_IMPORT_BIN";\n}\n',
                "bin/client/tests/support/recovery/mod.rs": 'fn comet() {\n    let _ = "ETNA_COMET_BIN";\n}\n',
                "bin/client/tests/lander_cli.rs": "mod support {\n    pub mod lander;\n}\n",
                "bin/client/tests/support/lander.rs": 'pub fn start() {\n    let _ = "ETNA_COMET_BIN";\n}\n',
                "crates/lander/tests/staking.rs": "fn start() {\n    ContractConsensus::start(url);\n}\n",
            }
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text)
            native = native_sources(root)
            self.assertEqual(set(native), {"governance_recovery.rs", "support/checkpoint_import.rs",
                                           "support/checkpoint_import/long_fence.rs", "support/recovery/mod.rs"})
            self.assertEqual(stray_native_markers(root, native), ["bin/client/tests/support/lander.rs:2: comet_or_signer"])

    def test_listed_native_consumers_exist_and_cover_every_marker(self):
        sources = native_sources(ROOT)
        listed = RECOVERY_IMAGE | NATIVE_EL | {LONG_FENCE}
        self.assertEqual(listed - docker_tests(sources), set(), "listed consumers must be docker tests at that module path")
        scanned = scan_native_consumers(sources)
        self.assertEqual(scanned["recovery"], RECOVERY_IMAGE)
        self.assertEqual(scanned["el"] - (NATIVE_EL | {LONG_FENCE}), set(), "unlisted EL consumers")
        self.assertNotIn(LONG_FENCE, scanned["comet_or_signer"])
        self.assertEqual(stray_native_markers(ROOT, sources), [], "native markers outside the governance_recovery binary")

    def test_entrypoint_filter_names_exist(self):
        names = set(re.findall(r"test\(=([^)]+)\)", (ROOT / "tests/entrypoint.sh").read_text()))
        self.assertTrue(names)
        defined = {qualified for path in rust_test_files() for qualified in column_zero_fns(path)}
        self.assertEqual(names - defined, set(), "entrypoint filters name missing tests")


if __name__ == "__main__":
    unittest.main()
