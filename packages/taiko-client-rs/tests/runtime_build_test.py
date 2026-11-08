"""Exercise script/build_etna_el_runtime.sh and script/build_recovery_runtime.sh with disposable
uname/Docker/Cargo/git executables, keep the alethia-reth pins in agreement, and keep the test
recovery image equal to the production runtime stages."""
import json
import os
from pathlib import Path
import posixpath
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ARG = "ARG ALETHIA_RETH_IMAGE="
PINNED = (ROOT / "Dockerfile").read_text().splitlines()[0].removeprefix(ARG)
LOG = "with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps([{name!r}] + sys.argv[1:]) + '\\n')\n"


class FakeHost:
    """A temporary directory whose bin/ holds logging uname and docker fakes, first on PATH."""

    def fake_host(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "bin").mkdir()
        self.log = self.root / "calls"
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}", CALLS=str(self.log),
                        UNAME_S="Linux", UNAME_M="x86_64", DOCKER_ARCH="x86_64",
                        TAIKO_CLIENT_RS_TEST_RUN="fixture-run")
        for key in ("ETNA_EL_BIN", "ALETHIA_RETH_IMAGE", "CARGO_TARGET_DIR", "ETNA_RECOVERY_IMAGE",
                    "ETNA_HOST_OS_RELEASE"):
            self.env.pop(key, None)
        self.executable("bin/uname", "#!/usr/bin/env python3\nimport json, os, sys\n" + LOG.format(name="uname") +
                        "print(os.environ[{'-s': 'UNAME_S', '-m': 'UNAME_M'}[sys.argv[1]]])\n")
        self.executable("bin/docker", "#!/usr/bin/env python3\nimport json, os, pathlib, shutil, sys\n" + LOG.format(name="docker") + '''
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
if sys.argv[1] == 'build':  # keep the context, which the script removes on exit
    shutil.copytree(sys.argv[-1], os.environ['CONTEXT_COPY'], symlinks=True)
''')

    def executable(self, name, contents):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        path.chmod(0o755)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []


class ElRuntime(FakeHost, unittest.TestCase):
    def setUp(self):
        self.fake_host()
        (self.root / "script").mkdir()
        shutil.copy(ROOT / "script/build_etna_el_runtime.sh", self.root / "script")
        shutil.copy(ROOT / "Dockerfile", self.root)
        self.output = self.root / "target/etna-signer/alethia-reth"
        for name in ("cargo", "git"):
            self.executable(f"bin/{name}", "#!/usr/bin/env python3\nimport json, os, sys\n" + LOG.format(name=name) + "sys.exit(1)\n")

    def run_script(self, **env):
        self.log.unlink(missing_ok=True)
        shutil.rmtree(self.root / "target", ignore_errors=True)
        return subprocess.run(["bash", str(self.root / "script/build_etna_el_runtime.sh")],
                              env={**self.env, **env}, text=True, capture_output=True, timeout=15)

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


def dockerfile_stages(path):
    """[(stage name or None, instructions)] with continuation lines joined; comments and blank lines dropped."""
    stages, parts = [], []
    for line in path.read_text().splitlines():
        if not parts and (not line.strip() or line.lstrip().startswith("#")):
            continue
        parts.append(line.removesuffix("\\").strip())
        if line.endswith("\\"):
            continue
        instruction, parts = " ".join(parts), []
        if instruction.startswith("FROM "):
            words = instruction.split()
            stages.append((words[3] if len(words) == 4 and words[2].upper() == "AS" else None, [instruction]))
        elif stages:
            stages[-1][1].append(instruction)
    return stages


class RecoveryImage(FakeHost, unittest.TestCase):
    """build_recovery_runtime.sh stages host-built binaries for tests/docker/recovery-runtime.Dockerfile on
    apt-based Linux hosts and builds the production Dockerfile everywhere else."""

    def setUp(self):
        self.fake_host()
        self.package = self.root / "packages/taiko-client-rs"
        shutil.copytree(ROOT / "script", self.package / "script", ignore=shutil.ignore_patterns("__pycache__"))
        (self.package / "tests/docker").mkdir(parents=True)
        shutil.copy(ROOT / "tests/docker/recovery-runtime.Dockerfile", self.package / "tests/docker")
        shutil.copy(ROOT / "Dockerfile", self.package)
        for name in ("etna-signer", "etna-comet-import", "cometbft"):
            self.executable(f"packages/taiko-client-rs/target/etna-signer/{name}", f"#!/bin/sh\necho {name}\n")
        self.client = self.root / "cargo-target/debug/taiko-client"
        self.executable("cargo-target/debug/taiko-client", "#!/bin/sh\necho host-built client\n")
        os_release = self.root / "os-release"
        os_release.write_text('PRETTY_NAME="Ubuntu 26.04 LTS"\nID_LIKE=debian\nID=ubuntu\nVERSION_ID="26.04"\n')
        self.context = self.root / "context"
        self.env.update(ETNA_HOST_OS_RELEASE=str(os_release), CONTEXT_COPY=str(self.context),
                        ETNA_RECOVERY_IMAGE="etna-client-recovery-test:fixture-run")

    def run_script(self, client=None, **env):
        self.log.unlink(missing_ok=True)
        shutil.rmtree(self.context, ignore_errors=True)
        return subprocess.run(["bash", str(self.package / "script/build_recovery_runtime.sh"), str(client or self.client)],
                              env={**self.env, **env}, text=True, capture_output=True, timeout=30)

    def build(self):
        builds = [row for row in self.calls() if row[:2] == ["docker", "build"]]
        self.assertEqual(len(builds), 1, self.calls())
        return builds[0]

    def assertOption(self, argv, flag, value):
        self.assertIn([flag, value], [argv[index:index + 2] for index in range(len(argv) - 1)], argv)

    def test_linux_stages_host_binaries_for_the_test_dockerfile(self):
        for machine, platform in (("x86_64", "linux/amd64"), ("aarch64", "linux/arm64")):
            with self.subTest(machine=machine):
                result = self.run_script(UNAME_M=machine, DOCKER_ARCH=machine)
                self.assertEqual(result.returncode, 0, result.stderr)
                build = self.build()
                for flag, value in (("--platform", platform), ("--build-arg", "BASE_IMAGE=ubuntu:26.04"),
                                    ("--build-arg", f"ALETHIA_RETH_IMAGE={PINNED}"),
                                    ("--label", "taiko-client-rs.test-run=fixture-run"),
                                    ("-t", "etna-client-recovery-test:fixture-run")):
                    self.assertOption(build, flag, value)
                self.assertNotIn("-f", build)
                self.assertEqual((self.context / "Dockerfile").read_text(),
                                 (ROOT / "tests/docker/recovery-runtime.Dockerfile").read_text())
                staged_client = self.context / "rootfs/app/taiko-client"
                self.assertEqual(staged_client.read_text(), self.client.read_text())
                self.assertTrue(os.access(staged_client, os.X_OK))

    def test_staged_layout_matches_production_runtime(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        rootfs = self.context / "rootfs"
        staged = {"/" + path.relative_to(rootfs).as_posix() for path in rootfs.rglob("*") if not path.is_dir()}
        production = dockerfile_stages(ROOT / "Dockerfile")
        runtime_tools, final = dict(production)["runtime-tools"], production[-1][1]
        self.assertEqual(final[0], "FROM runtime-tools", "the final stage must inherit runtime-tools' WORKDIR")
        workdir, copied = "/", {}
        for instruction in runtime_tools + final:
            keyword, _, arguments = instruction.partition(" ")
            if keyword == "WORKDIR":
                workdir = posixpath.join(workdir, arguments)
            elif keyword == "COPY":
                copied[posixpath.normpath(posixpath.join(workdir, arguments.split()[-1]))] = instruction
        # No recovery-image consumer imports; the production-image job covers the importer.
        self.assertEqual(set(copied) - {"/app/etna-el-import"}, staged | {"/app/alethia-reth"})
        test_image = dockerfile_stages(ROOT / "tests/docker/recovery-runtime.Dockerfile")[-1][1]
        expected = [instruction for instruction in runtime_tools if instruction.split()[0] in ("RUN", "WORKDIR", "ENV")]
        expected += [copied["/app/alethia-reth"], "COPY rootfs/ /",
                     [instruction for instruction in final if instruction.startswith("ENTRYPOINT ")][-1]]
        for instruction in expected:
            self.assertIn(instruction, test_image)

    def test_missing_host_binary_fails_before_docker_build(self):
        def assert_fails_before_build(result, named):
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(named, result.stderr)
            self.assertNotIn(["docker", "build"], [row[:2] for row in self.calls()])

        cometbft = self.package / "target/etna-signer/cometbft"
        cometbft.rename(self.root / "cometbft")
        assert_fails_before_build(self.run_script(), "target/etna-signer/cometbft")
        (self.root / "cometbft").rename(cometbft)
        missing_client = self.root / "nowhere/taiko-client"
        assert_fails_before_build(self.run_script(client=missing_client), str(missing_client))

    def test_other_hosts_build_the_production_dockerfile(self):
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)
        fedora = self.root / "fedora-os-release"
        fedora.write_text("ID=fedora\nVERSION_ID=43\n")
        for env in ({"UNAME_S": "Darwin"}, {"ETNA_HOST_OS_RELEASE": str(fedora)}, {"DOCKER_ARCH": "aarch64"}):
            with self.subTest(**env):
                result = self.run_script(**env)
                self.assertEqual(result.returncode, 0, result.stderr)
                build = self.build()
                self.assertEqual(build[build.index("-f") + 1], f"{build[-1]}/packages/taiko-client-rs/Dockerfile")
                self.assertTrue((self.context / "packages/taiko-client-rs/Dockerfile").is_file())
                self.assertEqual([arg for arg in build if arg.startswith("BASE_IMAGE=")], [])
                self.assertOption(build, "--label", "taiko-client-rs.test-run=fixture-run")
                self.assertOption(build, "-t", "etna-client-recovery-test:fixture-run")


if __name__ == "__main__":
    unittest.main()
