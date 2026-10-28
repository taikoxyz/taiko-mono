"""Real child-process supervision with a controlled private trust peer."""
import importlib.util
import json
import os
from pathlib import Path
import socket
import signal
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-supervisor-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        self.configure_transport()
        (self.home / "config/genesis.json").write_text('{"chain_id":"etna-test"}')
        self.store = self.root / "app"
        self.store.mkdir()
        self.key = self.root / "key.json"
        self.state = self.root / "state.json"
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.count = self.root / "starts"
        self.events = self.root / "denial.json"
        self.ready = True
        self.phase = "ready"
        self.generation = 0
        self.session = "same-session"
        self.extra = {}
        self.ops = []
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.bind(str(self.store / "checkpoint-trust.sock"))
        self.socket.listen()
        self.socket.settimeout(.1)
        self.done = threading.Event()
        self.server = threading.Thread(target=self.serve)
        self.server.start()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "cometbft": self.comet_body(),
            "signer": 'import json,os,sys,time\nopen(os.environ["SIGNERS"],"a").write(json.dumps(dict(pid=os.getpid(),argv=sys.argv[1:]))+"\\n")\ntime.sleep(60)',
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE=str(self.state),
                        ETNA_CHAIN_ID="etna-test", ETNA_SIGNER_BIN=str(self.bin / "signer"),
                        ETNA_DENIAL_FILE=str(self.events), STARTS=str(self.count), COMET_PID=str(self.root / "comet.pid"),
                        SIGNERS=str(self.root / "signers"),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.log = (self.root / "runtime.log").open("w+")
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")], env=self.env,
                                     stdout=self.log, stderr=self.log)
        try:
            # The recovery tests count signer incarnations, so wait for the first one too.
            self.wait(lambda: self.starts() == 1 and len(self.signers()) == 1)
        except Exception:
            self.tearDown()
            raise

    def configure_transport(self):
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "tcp://127.0.0.1:26659"\n')

    def comet_body(self):
        return 'from pathlib import Path\nimport os,time\np=Path(os.environ["STARTS"])\np.open("a").write("start\\n")\nPath(os.environ["COMET_PID"]).write_text(str(os.getpid()))\ntime.sleep(60)'

    def serve(self):
        while not self.done.is_set():
            try:
                peer, _ = self.socket.accept()
            except socket.timeout:
                continue
            with peer:
                request = json.loads(peer.makefile("rb").readline())
                self.ops.append(request["op"])
                response = dict(schema_version=1, session_id=self.session, chain_id="etna-test",
                                generation=self.generation, phase=self.phase, trust_ready=self.ready,
                                syncing=not self.ready, **self.extra)
                peer.sendall((json.dumps(response) + "\n").encode())

    def starts(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def publish(self, sequence, session):
        """Publish a signer observation atomically, as the real signer does."""
        temporary = self.events.with_name(self.events.name + ".tmp")
        temporary.write_text(json.dumps(dict(sequence=sequence, session_id=session)))
        os.replace(temporary, self.events)

    def signers(self):
        path = self.root / "signers"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def publish_recovery_session(self, session="recovered-session", ready=True, phase=None):
        """Play the recovery signer, which begins a fresh session and publishes it."""
        self.wait(lambda: len(self.signers()) == 2)
        self.assertIn("--await-trust", self.signers()[1]["argv"])
        self.ready = ready
        self.phase = phase or ("ready" if ready else "acquiring")
        self.session = session
        self.publish(0, session)

    def wait(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertTrue(predicate(), "supervisor did not perform the expected lifecycle transition")

    def tearDown(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.done.set()
        self.server.join()
        self.socket.close()
        self.log.close()
        self.tmp.cleanup()

    def test_signer_timeout_recovers_even_if_app_stayed_ready(self):
        self.publish(1, self.session)
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertTrue(self.ops)
        self.assertEqual(set(self.ops), {"observe"})

    def test_initial_transport_session_does_not_restart_healthy_comet(self):
        self.session = "fresh-session"
        self.publish(0, "fresh-session")
        time.sleep(.6)
        self.assertEqual(self.starts(), 1)

    def test_refusal_waits_for_trust_and_halt_never_restarts(self):
        self.ready = False
        self.phase = "acquiring"
        self.publish(1, self.session)
        time.sleep(.5)
        self.assertEqual(self.starts(), 1)
        self.phase = "halted"
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)

    def test_stale_generation_latches_across_supervisor_restart(self):
        self.generation = 1
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.generation = 0
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.5)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)

    def test_missing_authoritative_state_fails_closed(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.state.unlink()
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.assertNotEqual(self.proc.wait(timeout=5), 0)
        self.assertEqual(self.starts(), 1)
        self.assertFalse(self.state.exists())

    def test_fresh_session_closes_trust_until_revalidated(self):
        self.publish(1, "same-session")
        self.ready = False
        self.phase = "acquiring"
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.ready = True
        self.phase = "ready"
        self.publish_recovery_session("new-session", ready=False)
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.ready = True
        self.phase = "ready"
        self.wait(lambda: self.starts() == 2)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_comet_eof_after_observed_control_loss_recovers_only_when_ready(self):
        self.ready = False
        self.phase = "acquiring"
        time.sleep(.4)
        os.kill(int((self.root / "comet.pid").read_text()), signal.SIGTERM)
        time.sleep(.3)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.starts(), 1)
        self.ready = True
        self.phase = "ready"
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_comet_exit_with_continuously_ready_app_is_terminal(self):
        time.sleep(.3)
        os.kill(int((self.root / "comet.pid").read_text()), signal.SIGTERM)
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        time.sleep(.4)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())

    def test_initial_start_runs_signer_and_comet_together(self):
        # A node that is behind regains trust only after Comet syncs: never await it here.
        self.ready = False
        self.phase = "acquiring"
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertNotIn("--await-trust", self.signers()[0]["argv"])

    def test_recovery_starts_comet_only_after_fresh_session_is_trusted(self):
        # The refused step is replayed only by a restarted Comet, so the app must have
        # authenticated the new transport's session before Comet can ask again.
        self.publish(1, self.session)
        self.wait(lambda: len(self.signers()) == 2)
        self.assertIn("--await-trust", self.signers()[1]["argv"])
        # Before the signer publishes its session, Ready trust of the old one is no signal.
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.publish_recovery_session(ready=False)
        # Delayed authentication: the app checks the new session for several ticks.
        time.sleep(.6)
        self.assertEqual(self.starts(), 1)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.ready = True
        self.phase = "ready"
        self.wait(lambda: self.starts() == 2)
        time.sleep(.6)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(len(self.signers()), 2)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_exit_while_awaiting_trust_halts(self):
        self.publish(1, self.session)
        self.publish_recovery_session(ready=False)
        os.kill(self.signers()[1]["pid"], signal.SIGTERM)
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.ready = True
        self.phase = "ready"
        time.sleep(.4)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 2)
        self.assertIsNone(self.proc.poll())

    def test_checkpoint_above_committed_head_starts_comet_without_waiting(self):
        # Only Comet can commit up to such a checkpoint, so awaiting trust could never end.
        self.publish(1, self.session)
        self.extra = dict(target=dict(height=10), committed_head=dict(height=5))
        self.publish_recovery_session(ready=False, phase="catching_up")
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 3)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(len(self.signers()), 3)
        self.assertNotIn("--await-trust", self.signers()[2]["argv"])
        self.assertFalse((self.store / "validator-supervisor.halted").exists())


class UnixSupervisorTests(SupervisorTests):
    """Repeat lifecycle gates with a real listener which leaves its socket inode."""

    def configure_transport(self):
        (self.home / "run").mkdir()
        self.transport = self.home / "run/signer.sock"
        (self.home / "config/config.toml").write_text(f'priv_validator_laddr = "unix://{self.transport}"\n')

    def comet_body(self):
        # Like stock Comet, this listener leaves its transport inode after exit.
        return (f'import socket\ns=socket.socket(socket.AF_UNIX)\ns.bind({str(self.transport)!r})\ns.listen()\n'
                + super().comet_body())

    def stop_supervisor(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.assertTrue(self.transport.is_socket())

    def restart_supervisor(self):
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)

    def assert_refused(self):
        self.restart_supervisor()
        self.assertNotEqual(self.proc.wait(timeout=5), 0)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")

    def test_stale_socket_restart_retains_authority(self):
        self.stop_supervisor()
        self.restart_supervisor()
        self.wait(lambda: self.starts() == 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")
        self.assertFalse((self.store / "validator-supervisor.halted").exists())

    def test_live_socket_is_never_removed(self):
        self.stop_supervisor()
        self.transport.unlink()
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(self.transport))
            listener.listen()
            inode = self.transport.lstat().st_ino
            self.assert_refused()
            self.assertEqual(self.transport.lstat().st_ino, inode)

    def test_regular_file_is_never_removed(self):
        self.stop_supervisor()
        self.transport.unlink()
        self.transport.write_text("foreign transport file")
        self.assert_refused()
        self.assertEqual(self.transport.read_text(), "foreign transport file")

    def test_symlink_is_never_followed_or_removed(self):
        self.stop_supervisor()
        self.transport.unlink()
        self.transport.symlink_to(self.key)
        self.assert_refused()
        self.assertTrue(self.transport.is_symlink())

    def test_outside_run_socket_is_never_removed(self):
        self.stop_supervisor()
        outside = self.root / "foreign.sock"
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(outside))
        (self.home / "config/config.toml").write_text(f'priv_validator_laddr = "unix://{outside}"\n')
        inode = outside.lstat().st_ino
        self.assert_refused()
        self.assertEqual(outside.lstat().st_ino, inode)

    def assert_replacement_after_final_stat_survives(self, kind):
        self.stop_supervisor()
        spec = importlib.util.spec_from_file_location("etna_validator_under_test", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        real_fstat = os.fstat
        replaced = []
        directory = self.transport.parent.stat()
        with socket.socket(socket.AF_UNIX) as listener:
            def replace_after_endpoint_stat(descriptor):
                observed = real_fstat(descriptor)
                if not replaced and (observed.st_dev, observed.st_ino) == (directory.st_dev, directory.st_ino):
                    # fstat is the final directory check, after endpoint identity
                    # validation. Exercise a real replacement in that exact gap.
                    self.transport.unlink()
                    if kind == "file":
                        self.transport.write_text("concurrent replacement must survive")
                    elif kind == "symlink":
                        self.transport.symlink_to(self.key)
                    else:
                        listener.bind(str(self.transport))
                        listener.listen()
                    replaced.append(self.transport.lstat().st_ino)
                return observed
            with patch.dict(os.environ, self.env), patch.object(module.os, "fstat", replace_after_endpoint_stat):
                supervisor = module.Supervisor()
                with self.assertRaisesRegex(ValueError, "preserved at"):
                    supervisor.prepare_transport()
            self.assertTrue(replaced, "replacement interleaving was not exercised")
            self.assertEqual(self.transport.lstat().st_ino, replaced[0])
            if kind == "file":
                self.assertEqual(self.transport.read_text(), "concurrent replacement must survive")
            elif kind == "symlink":
                self.assertTrue(self.transport.is_symlink())
            else:
                with socket.socket(socket.AF_UNIX) as peer:
                    peer.connect(str(self.transport))
            backups = list(self.transport.parent.glob(".etna-transport-*/capture/endpoint"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].lstat().st_ino, replaced[0])
            # A writer can remove the restored public name; protected evidence
            # must still survive for operator diagnosis.
            self.transport.unlink()
            self.assertEqual(backups[0].lstat().st_ino, replaced[0])
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")

    def test_file_replacement_after_final_stat_survives(self):
        self.assert_replacement_after_final_stat_survives("file")

    def test_symlink_replacement_after_final_stat_survives(self):
        self.assert_replacement_after_final_stat_survives("symlink")

    def test_live_socket_replacement_after_final_stat_survives(self):
        self.assert_replacement_after_final_stat_survives("socket")

    def test_substituted_quarantine_preserves_prior_evidence(self):
        self.stop_supervisor()
        spec = importlib.util.spec_from_file_location("etna_validator_under_test", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        old = self.transport.parent / "retained-quarantine"
        old.mkdir(mode=0o700)
        (old / "endpoint").write_text("prior mismatch evidence")
        evidence_inode = (old / "endpoint").stat().st_ino
        socket_inode = self.transport.stat().st_ino
        real_open = os.open
        substituted = []
        def substitute_before_open(path, flags, *args, **kwargs):
            if not substituted and isinstance(path, str) and path.startswith(".etna-transport-"):
                descriptor = kwargs["dir_fd"]
                os.rename(old.name, path, src_dir_fd=descriptor, dst_dir_fd=descriptor)
                substituted.append(old.parent / path)
            return real_open(path, flags, *args, **kwargs)
        with patch.dict(os.environ, self.env), patch.object(module.os, "open", substitute_before_open):
            error = None
            try:
                module.Supervisor().prepare_transport()
            except (OSError, ValueError) as failure:
                error = failure
        self.assertTrue(substituted, "mkdir-to-open substitution was not exercised")
        evidence = substituted[0] / "endpoint"
        self.assertTrue(evidence.exists(), "cleanup overwrote prior quarantine evidence")
        self.assertEqual(evidence.read_text(), "prior mismatch evidence")
        self.assertEqual(evidence.stat().st_ino, evidence_inode)
        self.assertIsNotNone(error, "startup must refuse a nonempty substituted quarantine")
        self.assertEqual(self.transport.stat().st_ino, socket_inode)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_symlinked_run_directory_is_never_followed(self):
        self.stop_supervisor()
        directory = self.home / "run"
        moved = self.home / "real-run"
        directory.rename(moved)
        directory.symlink_to(moved, target_is_directory=True)
        self.assert_refused()
        self.assertTrue((moved / "signer.sock").is_socket())


if __name__ == "__main__":
    unittest.main()
