"""Mandatory clean-env host-controller lane; real child workloads stay isolated.

A disposable sleeping SDK executable is solely a process-lifecycle fixture. It
never supplies Go admission evidence. The actual Go replay is a separate gate.
"""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENT = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8", "PYTHONDONTWRITEBYTECODE": "1"}


def descendants(pid):
    result = []
    pending = [pid]
    while pending:
        parent = pending.pop()
        try:
            children = [int(x) for x in Path(f"/proc/{parent}/task/{parent}/children").read_text().split()]
        except FileNotFoundError:
            children = []
        result.extend(children)
        pending.extend(children)
    return result


def reap_owned(pids):
    for pid in pids:
        try:
            os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            pass


class CometControllerLifecycle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
            raise RuntimeError("INCONCLUSIVE: Linux pidfd APIs unavailable")
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(36, 1, 0, 0, 0) != 0:
            error = ctypes.get_errno()
            raise RuntimeError(f"INCONCLUSIVE: subreaper prctl errno={error}: {os.strerror(error)}")

    def trial(self, mode):
        with tempfile.TemporaryDirectory(prefix="etna-comet-lifecycle-") as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            data = b"package fixture\n"
            (source / "source.go").write_bytes(data)
            manifest = {"schema": "etna-source-snapshot-1", "commit": "a" * 40,
                        "files": {"source.go": {"bytes": len(data),
                         "sha256": hashlib.sha256(data).hexdigest(),
                         "gitBlob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}}}
            sdk = root / "sdk"
            (sdk / "bin").mkdir(parents=True)
            sleeper = sdk / "bin/go"
            sleeper.write_text("#!/bin/sh\n: > /tmp/output/ready\nexec /usr/bin/sleep 30\n")
            sleeper.chmod(0o755)
            for name in ("modules", "writable-cache"):
                (root / name).mkdir()
            output = root / "output"
            driver = root / "controller.py"
            values = {"output": str(output), "go_root": str(sdk), "module_cache": str(root / "modules"),
                      "build_cache": str(root / "writable-cache"), "timeout": 2 if mode == "timeout" else 20}
            driver.write_text(
                "import importlib.util,json,pathlib,sys\nfrom types import SimpleNamespace\n"
                f"s=importlib.util.spec_from_file_location('comet',{str(ROOT / 'run_comet.py')!r})\n"
                "m=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n"
                f"v={values!r}\n"
                "v={k:pathlib.Path(x) if k!='timeout' else x for k,x in v.items()}\n"
                "try:\n"
                f" m.run_trial('normal',pathlib.Path({str(source)!r}),{manifest!r},SimpleNamespace(**v),{{'source':{{'commit':'a'*40}}}},{{}})\n"
                "except BaseException as error:\n"
                f" pathlib.Path({str(root / 'result.json')!r}).write_text(json.dumps({{'error':type(error).__name__}}))\n"
                " sys.exit(130)\n"
                "else:\n sys.exit(0)\n")
            sentinel = subprocess.Popen(["/usr/bin/sleep", "30"], env=ENVIRONMENT, start_new_session=True)
            process = subprocess.Popen([sys.executable, "-B", str(driver)], env=ENVIRONMENT,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
            handles = {}
            try:
                ready = output / "normal/work/ready"
                deadline = time.monotonic() + 5
                while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(.01)
                if not ready.exists():
                    if process.poll() is None:
                        process.terminate()
                    diagnostic = process.communicate(timeout=8)[0].decode(errors="replace")
                    for log_name in ("combined.log", "stderr.log"):
                        log = output / "normal" / log_name
                        if log.exists():
                            diagnostic += log.read_text(errors="replace")
                    self.fail("INCONCLUSIVE: actual child namespace failed to start: " + diagnostic)
                for pid in descendants(process.pid):
                    try:
                        handles[pid] = os.pidfd_open(pid)
                    except ProcessLookupError:
                        pass
                self.assertGreaterEqual(len(handles), 3, "actual nested namespace chain not observed")
                if mode == "caller-term":
                    process.send_signal(signal.SIGTERM)
                elif mode == "group-term":
                    os.killpg(process.pid, signal.SIGTERM)
                elif mode == "caller-int":
                    process.send_signal(signal.SIGINT)
                elif mode == "caller-kill":
                    process.kill()
                elif mode != "timeout":
                    self.fail("unknown lifecycle mode")
                process.communicate(timeout=10)
                self.assertNotEqual(process.returncode, 0, "cancel/timeout reported success")
                deadline = time.monotonic() + 1
                while time.monotonic() < deadline:
                    reap_owned(handles)
                    if all(not Path(f"/proc/{pid}").exists() for pid in handles):
                        break
                    time.sleep(.01)
                alive = [pid for pid in handles if Path(f"/proc/{pid}").exists()]
                self.assertEqual(alive, [], "owned namespace descendants survived " + mode)
                self.assertIsNone(sentinel.poll(), "unrelated sentinel was killed")
                self.assertFalse((output / "summary.json").exists(), "cancel/timeout recorded campaign PASS")
                record = output / "normal/execution.json"
                if record.exists():
                    self.assertNotIn("outcomes", json.loads(record.read_text()))
            finally:
                # Cleanup is scoped to this test's pinned identities, never pkill
                # or an unrelated process/group. Preserve the failure assertion.
                if process.poll() is None:
                    process.kill()
                for fd in handles.values():
                    try:
                        signal.pidfd_send_signal(fd, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                process.communicate(timeout=8)
                deadline = time.monotonic() + 2
                while time.monotonic() < deadline:
                    reap_owned(handles)
                    if all(not Path(f"/proc/{pid}").exists() for pid in handles):
                        break
                    time.sleep(.01)
                for fd in handles.values():
                    os.close(fd)
                sentinel.terminate()
                sentinel.wait(timeout=3)

    def test_caller_term_reaps_actual_namespace(self): self.trial("caller-term")
    def test_group_term_reaps_actual_namespace(self): self.trial("group-term")
    def test_caller_int_reaps_actual_namespace(self): self.trial("caller-int")
    def test_caller_kill_reaps_actual_namespace(self): self.trial("caller-kill")
    def test_timeout_reaps_actual_namespace(self): self.trial("timeout")


if __name__ == "__main__":
    unittest.main(verbosity=2)
