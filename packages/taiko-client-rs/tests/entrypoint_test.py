"""Exercise the real entrypoint with disposable Cargo/Docker/helper executables."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


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
        for key in ("ETNA_RECOVERY_IMAGE", "ETNA_EL_BIN", "ETNA_EL_IMPORT_BIN", "NEXTEST_PROFILE", "ALETHIA_RETH_IMAGE"):
            self.env.pop(key, None)
        self.executable("bin/cargo", '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(['cargo'] + sys.argv[1:]) + '\\n')
if sys.argv[2] == 'list':
    if os.environ.get('LIST_WAIT'):
        pathlib.Path(os.environ['LIST_WAIT']).touch()
        time.sleep(60)
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
if sys.argv[1:3] == ['image', 'inspect'] and sys.argv[3].startswith('alethia-reth:etna-') and os.environ.get('EL_IMAGE_MISSING'): sys.exit(1)
if sys.argv[1] == 'ps': print('owned-container')
if sys.argv[1:3] == ['network', 'ls']: print('owned-network')
''')
        for name in ("etna_signer", "stock_comet", "etna_el_import", "etna_el_runtime", "recovery_runtime"):
            self.executable(f"script/build_{name}.sh", f'''#!/bin/bash
printf '["build", "{name}", "%s", "%s"]\\n' "${{ETNA_BUILD_TARGET:-}}" "${{ETNA_RECOVERY_IMAGE:-}}" >> "$CALLS"
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

    def test_standalone_reth_only_prepares_docker(self):
        self.select("standalone_reth", "occupied_initial_auth_port_recovers_and_preserves_restart_endpoints")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.builds(), [])
        self.assertIn(["docker", "info"], self.calls())

    def test_missing_default_el_image_builds_the_pinned_runtime(self):
        self.select("standalone_reth", "occupied_initial_auth_port_recovers_and_preserves_restart_endpoints")
        self.env["EL_IMAGE_MISSING"] = "1"
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        builds = [row for row in self.calls() if row[:2] == ["build", "recovery_runtime"]]
        self.assertEqual(len(builds), 1)
        self.assertEqual(builds[0][2], "execution-runtime")
        self.assertTrue(builds[0][3].startswith("alethia-reth:etna-"))
        self.assertFalse(any(row[:2] == ["docker", "pull"] and row[-1] == builds[0][3] for row in self.calls()))

    def test_explicit_el_image_keeps_the_callers_override(self):
        self.select("standalone_reth", "occupied_initial_auth_port_recovers_and_preserves_restart_endpoints")
        self.env["EL_IMAGE_MISSING"] = "1"
        self.env["ALETHIA_RETH_IMAGE"] = "reviewed:external"
        self.env["PULL_POLICY"] = "always"
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.builds(), [])
        self.assertIn(["docker", "pull", "--quiet", "reviewed:external"], self.calls())

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


class RuntimeImageBuild(unittest.TestCase):
    def test_actual_builder_accepts_empty_and_explicit_targets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            package = root / "packages/taiko-client-rs"
            (package / "script").mkdir(parents=True)
            script = package / "script/build_recovery_runtime.sh"
            shutil.copy(ROOT / "script/build_recovery_runtime.sh", script)
            (package / "Dockerfile").write_text("FROM scratch\n")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "-C", str(root), "add", "packages"], check=True)
            (root / "bin").mkdir()
            docker = root / "bin/docker"
            docker.write_text('''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1] == 'info': print('arm64')
else:
    with open(os.environ['CALLS'], 'w') as output: json.dump(sys.argv[1:], output)
''')
            docker.chmod(0o755)
            calls = root / "calls.json"
            env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}",
                       CALLS=str(calls), ETNA_RECOVERY_IMAGE="owned:test",
                       TAIKO_CLIENT_RS_TEST_RUN="builder-test")
            for target in ("", "execution-runtime"):
                with self.subTest(target=target):
                    result = subprocess.run(["/bin/bash", str(script)],
                                            env=dict(env, ETNA_BUILD_TARGET=target),
                                            text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(calls.is_file(), f"builder never invoked Docker: {result.stderr}")
                    args = json.loads(calls.read_text())
                    self.assertEqual(args[:3], ["build", "--platform", "linux/arm64"])
                    if target:
                        self.assertEqual(args[args.index("--target") + 1], target)
                    else:
                        self.assertNotIn("--target", args)
                    self.assertEqual(args[args.index("-t") + 1], "owned:test")


if __name__ == "__main__":
    unittest.main()
