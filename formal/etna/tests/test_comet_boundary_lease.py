"""Exercise the actual campaign cache lease with a disposable Linux child."""
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch


CONFORMANCE = Path(__file__).resolve().parents[1] / "conformance"
CHILD_ENV = {"PATH": os.defpath, "LANG": "C.UTF-8"}
ORIGINAL = b"original snapshot\n"
MUTANT = b"private fault\n"
DUMMY_WRITER = r"""
import os
from pathlib import Path
import sys
import time

ready, cache, lock = map(Path, sys.argv[1:])
lock_info = lock.stat()
for entry in Path('/proc/self/fd').iterdir():
    try:
        fd_info = os.fstat(int(entry.name))
    except OSError:
        continue
    if (fd_info.st_dev, fd_info.st_ino) == (lock_info.st_dev, lock_info.st_ino):
        raise RuntimeError('writer inherited the cache lease')
with (cache / 'writer.log').open('w') as log:
    pending = ready.with_suffix('.pending')
    pending.write_text(f'{os.getppid()} {os.getpid()}')
    pending.replace(ready)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        log.write('active\n')
        log.flush()
        time.sleep(0.025)
"""


def dummy_stream(profile):
    rows = []

    def event(action, test=None, output=None, kind=None):
        row = {"Package": profile.package, "Action": action}
        if test is not None:
            row["Test"] = test
        if output is not None:
            row["Output"] = output
        if kind is not None:
            row["OutputType"] = kind
        rows.append(json.dumps(row))

    parent, case = profile.parent, profile.parent + "/" + profile.smoke
    event("start")
    for test in (parent, case):
        event("run", test)
        event("output", test, "=== RUN   " + test + "\n", "frame")
    event("output", case, '    dummy_test.go:1: receipt={"case":"writer"}\n')
    for test in (case, parent):
        event("output", test, "--- PASS: " + test + " (0.00s)\n", "frame")
        event("pass", test)
    event("output", output="PASS\n", kind="frame")
    event("output", output="ok  \t" + profile.package + "\t0.001s\n")
    event("pass")
    return "\n".join(rows)


def run_dummy_campaign(root, active_phase):
    sys.path.insert(0, str(CONFORMANCE))
    import comet_boundary_common as common

    args = SimpleNamespace(**{name: root / name for name in (
        "source", "go_root", "module_cache", "build_cache", "build_lock", "output",
        "workspace_root")}, timeout=100, smoke=True)
    reuse = args.output.exists()
    if not reuse:
        for path in (args.source, args.go_root, args.module_cache, args.build_cache):
            path.mkdir()
        args.build_lock.touch()
        (args.source / "source.txt").write_bytes(ORIGINAL)
    fixture = CONFORMANCE / "comet_boundary"
    inputs = {name: fixture / name for name in ("go.mod", "go.sum")}
    hashes = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in inputs.items()}
    commit = "a" * 40
    manifest = dict(schema="etna-source-snapshot-1", commit=commit,
                    files={"source.txt": common.COMET.file_entry(ORIGINAL)})
    pins = dict(goToolSha256={}, source=dict(commit=commit), inputsSha256=hashes,
                sourceFault=dict(mutantSha256=hashlib.sha256(MUTANT).hexdigest()))

    def audit(raw, *, source_fault):
        if source_fault or raw != b'{"case":"writer"}':
            raise ValueError("unexpected dummy receipt")
        return {"case": "writer"}

    profile = common.BoundaryProfile("cache-lease-test", "comet_boundary", "example.org/dummy",
                                     "TestCacheLease", "writer", ("writer",), (), audit,
                                     "source.txt", ORIGINAL, MUTANT, "writer", ())

    paused = False
    real_verify = common.COMET.verify_snapshot
    real_inventory = common.require_inventory
    real_write = Path.write_bytes
    private_file = root / "output/private-upstream/source.txt"

    def pause_window():
        nonlocal paused
        if paused:
            return
        paused = True
        (root / "window-ready").write_text(active_phase)
        deadline = time.monotonic() + 5
        while not (root / "window-resume").exists():
            if time.monotonic() >= deadline:
                raise ValueError("dummy window gate timed out")
            time.sleep(0.01)

    def verify_window(*values, **options):
        if (active_phase == "pre-native" and Path(values[0]) == private_file.parent
                and private_file.read_bytes() == MUTANT):
            pause_window()
        return real_verify(*values, **options)

    def inventory_window(*values, **options):
        if (active_phase == "post-native" and values[2] == "staged native input identities"
                and private_file.exists() and private_file.read_bytes() == MUTANT):
            pause_window()
        return real_inventory(*values, **options)

    def write_window(path, data):
        if active_phase == "restoration" and path == private_file and data == ORIGINAL:
            pause_window()
        return real_write(path, data)

    def isolation_dummy(profile, trial, source, args, selected):
        if trial.name == active_phase:
            return [sys.executable, "-IB", "-c", DUMMY_WRITER,
                    str(root / "ready"), str(args.build_cache), str(args.build_lock)]
        exit_status = 200 if active_phase == "reserved-exit" and trial.name == "normal" else 0
        return [sys.executable, "-IB", "-c", "import sys; print(sys.argv[1]); sys.exit(int(sys.argv[2]))",
                dummy_stream(profile), str(exit_status)]

    with (patch.object(common, "load_inputs", return_value=(pins, manifest, inputs, {})),
          patch.object(common, "reviewed_boundary", return_value={"workspace": {"documents": {}}}),
          patch.object(common, "isolation_command", side_effect=isolation_dummy),
          patch.object(common.COMET, "verify_snapshot", side_effect=verify_window),
          patch.object(common, "require_inventory", side_effect=inventory_window),
          patch.object(Path, "write_bytes", write_window)):
        args.smoke_output = root / "smoke-output"
        if not reuse:
            args.output = args.smoke_output
            common.run_profile(profile, args)
        args.output, args.smoke = root / "output", False
        common.run_profile(profile, args)


def wait_for(check, seconds):
    deadline = time.monotonic() + seconds
    while not check() and time.monotonic() < deadline:
        time.sleep(0.02)
    return check()


def exited(pidfd, milliseconds=0):
    poll = select.poll()
    poll.register(pidfd, select.POLLIN)
    return bool(poll.poll(milliseconds))


def stopped(pid):
    lines = Path(f"/proc/{pid}/status").read_text().splitlines()
    return any(line.split()[1] == "T" for line in lines if line.startswith("State:"))


@unittest.skipUnless(sys.platform == "linux" and hasattr(os, "pidfd_open")
                     and hasattr(signal, "pidfd_send_signal"), "Linux pidfd supervisor required")
class CometBoundaryLease(unittest.TestCase):
    @contextmanager
    def campaign_with_stopped_supervisor(self, phase):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ready = root / "ready"
            command = [sys.executable, "-IB", __file__, "--dummy-campaign", str(root), phase]
            with (root / "campaign.log").open("wb") as log:
                campaign = subprocess.Popen(command, env=CHILD_ENV, stdin=subprocess.DEVNULL,
                                            stdout=log, stderr=subprocess.STDOUT)
            supervisor_fd = writer_fd = None
            try:
                self.assertTrue(wait_for(lambda: ready.is_file() or campaign.poll() is not None, 5),
                                "dummy writer did not start")
                self.assertTrue(ready.is_file(), (root / "campaign.log").read_text())
                supervisor, writer = map(int, ready.read_text().split())
                supervisor_fd = os.pidfd_open(supervisor)
                writer_fd = os.pidfd_open(writer)
                private = root / "output/private-upstream/source.txt"
                self.assertEqual(private.read_bytes(), MUTANT if phase == "mutant" else ORIGINAL)
                # Keep the supervisor alive but unable to clean up until the
                # caller and lock-contender observations have been made.
                signal.pidfd_send_signal(supervisor_fd, signal.SIGSTOP)
                self.assertTrue(wait_for(lambda: stopped(supervisor), 3))
                yield root, command, private, campaign, supervisor_fd, writer_fd, writer
            finally:
                if campaign.poll() is None:
                    campaign.kill()
                    campaign.wait(timeout=3)
                if supervisor_fd is not None:
                    if not exited(supervisor_fd):
                        try:
                            signal.pidfd_send_signal(supervisor_fd, signal.SIGCONT)
                        except ProcessLookupError:
                            pass
                        exited(supervisor_fd, 5000)
                    os.close(supervisor_fd)
                if writer_fd is not None:
                    if not exited(writer_fd):
                        try:
                            signal.pidfd_send_signal(writer_fd, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        exited(writer_fd, 3000)
                    os.close(writer_fd)

    def assert_writer_reaped(self, supervisor_fd, writer_fd, writer):
        signal.pidfd_send_signal(supervisor_fd, signal.SIGCONT)
        self.assertTrue(exited(supervisor_fd, 5000), "supervisor did not finish cleanup")
        self.assertTrue(exited(writer_fd), "supervisor exited with a live writer")
        self.assertFalse(Path(f"/proc/{writer}").exists(), "writer was not reaped")

    def assert_cache_leased(self, contender, writer_fd):
        self.assertFalse(exited(writer_fd), "dummy writer exited before lock probe")
        with self.assertRaises(BlockingIOError, msg="cache unlocked while a writer is live"):
            fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_killed_campaign_keeps_cache_leased_until_writer_is_reaped(self):
        for phase in ("normal", "mutant"):
            with self.subTest(phase=phase), self.campaign_with_stopped_supervisor(phase) as running:
                root, command, private, campaign, supervisor_fd, writer_fd, writer = running
                with (root / "build_lock").open("rb") as contender:
                    self.assert_cache_leased(contender, writer_fd)
                    campaign.kill()
                    self.assertEqual(campaign.wait(timeout=3), -signal.SIGKILL)
                    self.assert_cache_leased(contender, writer_fd)
                    self.assert_writer_reaped(supervisor_fd, writer_fd, writer)
                    fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual((root / "source/source.txt").read_bytes(), ORIGINAL)
                self.assertEqual(private.read_bytes(), MUTANT if phase == "mutant" else ORIGINAL)
                self.assertFalse((root / "output/summary.json").exists())
                self.assertFalse((root / "output/actual-restoration.json").exists())
                retry = subprocess.run(command, env=CHILD_ENV, stdin=subprocess.DEVNULL,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
                self.assertNotEqual(retry.returncode, 0)
                self.assertIn(b"a fresh output directory", retry.stdout)

    def test_repeated_termination_waits_before_restoring_private_source(self):
        for phase in ("normal", "mutant"):
            with self.subTest(phase=phase), self.campaign_with_stopped_supervisor(phase) as running:
                root, _, private, campaign, supervisor_fd, writer_fd, writer = running
                with (root / "build_lock").open("rb") as contender:
                    for _ in range(3):
                        campaign.terminate()
                        time.sleep(0.1)
                    self.assertIsNone(campaign.poll(), "caller exited before writer quiescence")
                    self.assertEqual(private.read_bytes(), MUTANT if phase == "mutant" else ORIGINAL)
                    self.assert_cache_leased(contender, writer_fd)
                    self.assert_writer_reaped(supervisor_fd, writer_fd, writer)
                    self.assertNotEqual(campaign.wait(timeout=5), 0)
                    fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual(private.read_bytes(), ORIGINAL)
                self.assertEqual((root / "source/source.txt").read_bytes(), ORIGINAL)
                self.assertEqual((root / "output/actual-restoration.json").is_file(), phase == "mutant")
                self.assertFalse((root / "output/summary.json").exists())

    def test_unknown_supervisor_exit_leaves_live_caller_holding_lease(self):
        with self.campaign_with_stopped_supervisor("mutant") as running:
            root, _, private, campaign, supervisor_fd, writer_fd, _ = running
            signal.pidfd_send_signal(supervisor_fd, signal.SIGKILL)
            self.assertTrue(exited(supervisor_fd, 3000))
            log = root / "campaign.log"
            self.assertTrue(wait_for(lambda: "cache lease retained" in log.read_text(), 3))
            self.assertIsNone(campaign.poll())
            with (root / "build_lock").open("rb") as contender:
                self.assert_cache_leased(contender, writer_fd)
            self.assertEqual(private.read_bytes(), MUTANT)
            self.assertFalse((root / "output/actual-restoration.json").exists())
            self.assertFalse((root / "output/summary.json").exists())
            # External recovery must first establish that the surviving writer
            # is dead before stopping the caller that still owns the lease.
            signal.pidfd_send_signal(writer_fd, signal.SIGKILL)
            self.assertTrue(exited(writer_fd, 3000))

    def test_graceful_termination_covers_staging_audit_and_restoration(self):
        for phase in ("pre-native", "post-native", "restoration"):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                command = [sys.executable, "-IB", __file__, "--dummy-campaign", str(root), phase]
                with (root / "campaign.log").open("wb") as log:
                    campaign = subprocess.Popen(command, env=CHILD_ENV, stdin=subprocess.DEVNULL,
                                                stdout=log, stderr=subprocess.STDOUT)
                try:
                    marker = root / "window-ready"
                    self.assertTrue(wait_for(lambda: marker.exists() or campaign.poll() is not None, 5))
                    self.assertTrue(marker.exists(), (root / "campaign.log").read_text())
                    private = root / "output/private-upstream/source.txt"
                    self.assertEqual(private.read_bytes(), MUTANT)
                    for _ in range(3):
                        campaign.terminate()
                        time.sleep(.025)
                    self.assertIsNone(campaign.poll(), "TERM interrupted a quiescent mutation window")
                    (root / "window-resume").touch()
                    self.assertNotEqual(campaign.wait(timeout=5), 0)
                    self.assertEqual(private.read_bytes(), ORIGINAL)
                    self.assertEqual((root / "source/source.txt").read_bytes(), ORIGINAL)
                    self.assertTrue((root / "output/actual-restoration.json").is_file())
                    self.assertFalse((root / "output/summary.json").exists())
                    self.assertFalse((root / "output/restored").exists())
                finally:
                    (root / "window-resume").touch()
                    if campaign.poll() is None:
                        campaign.kill()
                        campaign.wait(timeout=3)

    def test_reserved_worker_exit_cannot_forge_confirmed_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            command = [sys.executable, "-IB", __file__, "--dummy-campaign", str(root), "reserved-exit"]
            result = subprocess.run(command, env=CHILD_ENV, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            normal = root / "output/normal"
            self.assertTrue((normal / "execution.json").is_file(), result.stdout.decode())
            record = json.loads((normal / "execution.json").read_bytes())
            self.assertEqual(record["returncode"], 125)
            self.assertEqual(record["supervisorReturncode"], 203)
            raw = (normal / "combined.log").read_bytes()
            self.assertIn(b'"Action": "pass"', raw)
            self.assertEqual(record["combinedOutputSha256"], hashlib.sha256(raw).hexdigest())
            self.assertFalse((root / "output/summary.json").exists())


if __name__ == "__main__":
    if sys.argv[1:2] == ["--dummy-campaign"]:
        run_dummy_campaign(Path(sys.argv[2]), sys.argv[3])
    else:
        unittest.main()
