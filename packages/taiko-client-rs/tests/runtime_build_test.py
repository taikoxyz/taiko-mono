"""Exercise script/build_etna_el_runtime.sh with disposable uname/Docker/Cargo/git executables, and
keep the alethia-reth pins it copies from or builds in agreement."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ARG = "ARG ALETHIA_RETH_IMAGE="
PINNED = (ROOT / "Dockerfile").read_text().splitlines()[0].removeprefix(ARG)
LOG = "with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps([{name!r}] + sys.argv[1:]) + '\\n')\n"


class ElRuntime(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("script", "bin"):
            (self.root / name).mkdir()
        shutil.copy(ROOT / "script/build_etna_el_runtime.sh", self.root / "script")
        shutil.copy(ROOT / "Dockerfile", self.root)
        self.output = self.root / "target/etna-signer/alethia-reth"
        self.log = self.root / "calls"
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}", CALLS=str(self.log),
                        UNAME_S="Linux", UNAME_M="x86_64", DOCKER_ARCH="x86_64",
                        TAIKO_CLIENT_RS_TEST_RUN="fixture-run")
        for key in ("ETNA_EL_BIN", "ALETHIA_RETH_IMAGE", "CARGO_TARGET_DIR"):
            self.env.pop(key, None)
        self.executable("bin/uname", "#!/usr/bin/env python3\nimport json, os, sys\n" + LOG.format(name="uname") +
                        "print(os.environ[{'-s': 'UNAME_S', '-m': 'UNAME_M'}[sys.argv[1]]])\n")
        self.executable("bin/docker", "#!/usr/bin/env python3\nimport json, os, pathlib, sys\n" + LOG.format(name="docker") + '''
if sys.argv[1] == 'info': print(os.environ['DOCKER_ARCH'])
if sys.argv[1:3] == ['image', 'inspect'] and os.environ.get('MISSING_IMAGE'): sys.exit(1)
if sys.argv[1] == 'create': print('cid1')
if sys.argv[1] == 'cp':
    destination = pathlib.Path(sys.argv[3])
    if os.environ.get('CP_FAIL'):
        destination.write_text('#!/bin/sh\\n')  # an interrupted transfer
        sys.exit(1)
    destination.write_text('#!/bin/sh\\n' + ('exit 1\\n' if os.environ.get('SMOKE_FAIL') else 'echo alethia-reth fixture\\n'))
    destination.chmod(0o755)
''')
        for name in ("cargo", "git"):
            self.executable(f"bin/{name}", "#!/usr/bin/env python3\nimport json, os, sys\n" + LOG.format(name=name) + "sys.exit(1)\n")

    def executable(self, name, contents):
        path = self.root / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_script(self, **env):
        self.log.unlink(missing_ok=True)
        shutil.rmtree(self.root / "target", ignore_errors=True)
        return subprocess.run(["bash", str(self.root / "script/build_etna_el_runtime.sh")],
                              env={**self.env, **env}, text=True, capture_output=True, timeout=15)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_linux_copies_the_pinned_image_without_cargo(self):
        for machine, platform, image in (("x86_64", "linux/amd64", None), ("x86_64", "linux/amd64", PINNED),
                                         ("aarch64", "linux/arm64", None)):
            with self.subTest(machine=machine, image=image):
                env = {"UNAME_M": machine, "DOCKER_ARCH": machine} | ({"ALETHIA_RETH_IMAGE": image} if image else {})
                result = self.run_script(**env)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.calls()
                create = calls.index(["docker", "create", "--platform", platform, "--label",
                                      "taiko-client-rs.test-run=fixture-run", PINNED])
                copy = next(index for index, row in enumerate(calls) if row[:3] == ["docker", "cp", "cid1:/app/alethia-reth"])
                self.assertTrue(calls[copy][3].endswith("target/etna-signer/alethia-reth.tmp"), calls[copy])
                self.assertLess(create, copy)
                self.assertLess(copy, calls.index(["docker", "rm", "-f", "cid1"]))
                self.assertNotIn("cargo", [row[0] for row in calls])
                self.assertTrue(os.access(self.output, os.X_OK))
                self.assertFalse(self.output.with_name("alethia-reth.tmp").exists())

    def test_copy_failure_removes_the_container_and_leaves_no_binary(self):
        for failure in ("CP_FAIL", "SMOKE_FAIL"):
            with self.subTest(failure=failure):
                result = self.run_script(**{failure: "1"})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(["docker", "rm", "-f", "cid1"], self.calls())
                self.assertFalse(self.output.exists())
                self.assertFalse(self.output.with_name("alethia-reth.tmp").exists())

    def test_missing_image_is_pulled_first(self):
        result = self.run_script(MISSING_IMAGE="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        create = next(index for index, row in enumerate(calls) if row[:2] == ["docker", "create"])
        self.assertLess(calls.index(["docker", "pull", "--quiet", PINNED]), create)

    def test_macos_and_overridden_images_build_from_source(self):
        for env, before in (({"UNAME_S": "Darwin"}, []), ({"ALETHIA_RETH_IMAGE": "other:tag"}, []),
                            ({"DOCKER_ARCH": "aarch64"}, [["docker", "info", "--format", "{{.Architecture}}"]])):
            with self.subTest(**env):
                self.run_script(**env)
                calls = [row for row in self.calls() if row[0] != "uname"]
                self.assertEqual(calls[:len(before)], before)
                self.assertEqual(calls[len(before)][:2], ["cargo", "metadata"])
                self.assertNotIn(["docker", "create"], [row[:2] for row in calls])

    def test_alethia_pins_agree(self):
        def pin(path, pattern):
            match = re.search(pattern, (ROOT / path).read_text(), re.M)
            self.assertIsNotNone(match, f"{path} no longer matches {pattern}")
            return match.group(1)

        self.assertTrue((ROOT / "Dockerfile").read_text().startswith(ARG))
        self.assertEqual(pin("tests/entrypoint.sh", r"^export ALETHIA_RETH_IMAGE=\$\{ALETHIA_RETH_IMAGE:-([^}]+)\}$"), PINNED)
        self.assertEqual(pin("crates/test-harness/src/boot.rs", r'^pub\(crate\) const RETH_IMAGE: &str = "([^"]+)";$'), PINNED)
        tag = re.fullmatch(r"[^:@]+/alethia-reth:sha-([0-9a-f]{7})@sha256:[0-9a-f]{64}", PINNED)
        self.assertIsNotNone(tag, PINNED)
        revision = pin("script/build_etna_el_runtime.sh", r"^TASK_PINNED_REVISION=([0-9a-f]{40})$")
        self.assertEqual(pin("Cargo.toml", r'^alethia-reth-chainspec = \{.*\brev = "([0-9a-f]{40})"'), revision)
        self.assertEqual(tag.group(1), revision[:7])


if __name__ == "__main__":
    unittest.main()
