"""Real child-process supervision with a controlled private trust peer."""
import importlib.util
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import socket
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class TrustPeer:
    """The app's private trust socket and the signer's published observations."""

    def start_peer(self):
        self.ready = True
        self.phase = "ready"
        self.session = "same-session"
        self.extra = {}
        self.ops = []
        self.observation_hold = None
        self.requests, self.observations = [], []
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.bind(str(self.store / "checkpoint-trust.sock"))
        self.socket.listen()
        self.socket.settimeout(.1)
        self.done = threading.Event()
        self.server = threading.Thread(target=self.serve)
        self.server.start()

    def stop_peer(self):
        self.done.set()
        self.server.join()
        self.socket.close()

    def serve(self):
        while not self.done.is_set():
            try:
                peer, _ = self.socket.accept()
            except socket.timeout:
                continue
            with peer:
                request = json.loads(peer.makefile("rb").readline())
                self.ops.append(request["op"])
                self.requests.append(request)
                response = dict(schema_version=self.schema, session_id=self.session, chain_id=self.chain,
                                generation=self.generation, phase=self.phase, trust_ready=self.ready,
                                syncing=not self.ready, target=None, committed_head=None,
                                trusted_consensus_head=None, reason=None)
                response.update(self.extra)
                if self.schema == 2:
                    response["recovery_origin"] = self.origin if self.ready else None
                self.observations.append(response)
                held = self.observation_hold
                if held is not None:
                    held[0].set()
                    held[1].wait(timeout=5)
                peer.sendall((json.dumps(response) + "\n").encode())

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
        if not predicate():
            # A separate reader leaves the child's shared stdout offset untouched.
            runtime = Path(self.log.name).read_text(errors="replace")
            self.fail("supervisor did not perform the expected lifecycle transition; "
                      f"supervisor exit status: {self.proc.poll()}\nruntime.log:\n{runtime}")


class SupervisorTests(TrustPeer, unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-supervisor-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        self.configure_transport()
        self.chain, self.generation, self.schema = "etna-test", 0, 1
        self.identity_env = {}
        self.configure_identity()
        (self.home / "config/genesis.json").write_text(json.dumps(dict(chain_id=self.chain)))
        self.store = self.root / "app"
        self.store.mkdir()
        self.key = self.root / "key.json"
        self.state = self.root / "state.json"
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.count = self.root / "starts"
        self.events = self.root / "denial.json"
        self.start_peer()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "cometbft": self.comet_body(),
            "signer": ('import json,os,signal,sys,time\nfrom pathlib import Path\n'
                       'def stop(*_):\n'
                       ' p=Path(os.environ["COMET_PID"])\n'
                       ' try: os.kill(int(p.read_text()),0); event="comet_alive"\n'
                       ' except ProcessLookupError: event="comet_reaped"\n'
                       ' with p.with_name("lifecycle").open("a") as out: out.write(event+"\\nsigner_stopped\\n")\n'
                       ' sys.exit(0)\n'
                       'signal.signal(signal.SIGTERM,stop)\n'
                       'open(os.environ["SIGNERS"],"a").write(json.dumps(dict(pid=os.getpid(),argv=sys.argv[1:],owner_join=os.environ.get("ETNA_OWNER_JOIN"),owner_fds=os.environ.get("ETNA_OWNER_FDS"),owner_lifetime=os.environ.get("ETNA_OWNER_LIFETIME_FD")))+"\\n")\nwhile not Path(os.environ["COMET_PID"]).with_name("release_signer").exists(): time.sleep(.05)'),
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE=str(self.state),
                        ETNA_CHAIN_ID=self.chain, ETNA_SIGNER_BIN=str(self.bin / "signer"),
                        ETNA_DENIAL_FILE=str(self.events), STARTS=str(self.count), COMET_PID=str(self.root / "comet.pid"),
                        SIGNERS=str(self.root / "signers"),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.env.update(self.identity_env)
        self.log = (self.root / "runtime.log").open("w+")
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")], env=self.env,
                                     stdout=self.log, stderr=self.log, start_new_session=True)
        try:
            # The recovery tests count signer incarnations, so wait for the first one too.
            self.wait(lambda: self.starts() == 1 and len(self.signers()) == 1)
        except Exception:
            self.tearDown()
            raise

    def configure_identity(self):
        pass

    def configure_transport(self):
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "tcp://127.0.0.1:26659"\n')

    def comet_body(self):
        return 'from pathlib import Path\nimport os,time\np=Path(os.environ["STARTS"])\np.open("a").write("start\\n")\nPath(os.environ["COMET_PID"]).write_text(str(os.getpid()))\n\nwhile not Path(os.environ["COMET_PID"]).with_name("release_comet").exists(): time.sleep(.05)'

    def starts(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def tearDown(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.stop_peer()
        self.log.close()
        self.tmp.cleanup()

    def test_terminal_group_interrupt_stops_comet_before_signer(self):
        self.assertEqual(os.getpgid(self.proc.pid), self.proc.pid)
        os.killpg(self.proc.pid, signal.SIGINT)
        self.assertEqual(self.proc.wait(timeout=5), 0)
        lifecycle = self.root / "lifecycle"
        self.assertTrue(lifecycle.exists(), "terminal SIGINT bypassed ordered supervisor stop")
        self.assertEqual(lifecycle.read_text().splitlines()[-2:], ["comet_reaped", "signer_stopped"])

    def test_terminal_latch_write_failure_quiesces_and_retries(self):
        """A read-only app store cannot turn a terminal stop into process restart."""
        if os.geteuid() == 0:
            self.skipTest("root bypasses directory-write permission faults")
        self.store.chmod(0o500)
        try:
            self.phase = "halted"
            self.wait(lambda: (self.root / "lifecycle").exists())
            self.assertIsNone(self.proc.poll(), "failed halt persistence exited the supervisor")
            self.assertEqual((self.root / "lifecycle").read_text().splitlines()[-2:],
                             ["comet_reaped", "signer_stopped"])
        finally:
            self.store.chmod(0o700)
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)

    def test_stale_observation_temporary_does_not_block_restart(self):
        """An interrupted diagnostic publish is neither terminal evidence nor signing state."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        temporary = self.events.with_name(self.events.name + ".tmp")
        # A crash can leave even a truncated write. Preserve it without reusing it.
        temporary.write_bytes(b'{"sequence":')
        temporary.chmod(0o600)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.assertEqual(temporary.read_bytes(), b'{"sequence":')

    def test_supervisor_sigterm_retains_signer_failure_for_restart(self):
        """A signer failure discovered during external shutdown must survive restartAlways."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        latch = self.store / "validator-supervisor.halted"
        self.assertFalse(latch.exists(), "healthy signal shutdown became terminal")
        signer = self.bin / "signer"
        signer.write_text(signer.read_text().replace("sys.exit(0)", "sys.exit(1)"))
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        self.assertTrue(latch.exists(), "external supervisor shutdown discarded the signer failure")
        evidence = latch.read_bytes()
        self.assertEqual((self.root / "lifecycle").read_text().splitlines()[-2:],
                         ["comet_reaped", "signer_stopped"])
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 2, "restartAlways rearmed failed signing authority")
        self.assertEqual(latch.read_bytes(), evidence)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")

    def test_inherited_scoped_grant_and_lifetime_reach_stock_children(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        lock_path = self.home.parent / ("." + self.home.name + ".etna-owner.lock")
        owner = os.open(lock_path, os.O_RDWR)
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        read_end, hold_end = socket.socketpair()
        read_end.settimeout(.2)
        environment = dict(self.env, ETNA_OWNER_FDS=str(owner),
                           ETNA_OWNER_JOIN="supervisor:" + str(owner),
                           ETNA_OWNER_LIFETIME_FD=str(hold_end.fileno()))
        try:
            self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                         env=environment, pass_fds=(owner, hold_end.fileno()),
                                         stdout=self.log, stderr=self.log)
            hold_end.close()
            os.close(owner)
            owner = None
            self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
            self.proc.kill()
            self.proc.wait(timeout=5)
            # Only descendants remain. A dropped supervisor must not manufacture EOF.
            with self.assertRaises(socket.timeout):
                read_end.recv(1)
            self.assertEqual(self.signers()[-1]["owner_join"], None)
            self.assertEqual(self.signers()[-1]["owner_fds"], None)
            self.assertEqual(self.signers()[-1]["owner_lifetime"], None)
        finally:
            if owner is not None:
                os.close(owner)
            hold_end.close()
            (self.root / "release_comet").touch()
            (self.root / "release_signer").touch()
            read_end.settimeout(3)
            self.assertEqual(read_end.recv(1), b"")
            read_end.close()

    def test_sigkill_supervisor_retains_descendant_ownership(self):
        self.proc.kill()
        self.proc.wait(timeout=5)
        owner_path = self.home.parent / ("." + self.home.name + ".etna-owner.lock")
        with owner_path.open("r+") as owner:
            try:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
                blocked = subprocess.run(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                         env=self.env, capture_output=True, timeout=3)
                self.assertNotEqual(blocked.returncode, 0)
                self.assertIn(b"ownership is busy", blocked.stderr)
                self.assertEqual(self.starts(), 1)
                # Even after Comet exits, the surviving signer keeps the same reservation.
                (self.root / "release_comet").touch()
                time.sleep(.2)
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertEqual(self.state.read_text(), "authoritative HRS")
                self.assertEqual(self.key.read_text(), "existing key")
            finally:
                (self.root / "release_comet").touch()
                (self.root / "release_signer").touch()
            def unlocked():
                try:
                    fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    return True
                except BlockingIOError:
                    return False
            self.wait(unlocked)

    def test_duplicate_supervisor_refuses_live_owner(self):
        other = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                 env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            _, error = other.communicate(timeout=2)
            self.assertNotEqual(other.returncode, 0)
            self.assertIn(b"ownership is busy", error)
            self.assertEqual(self.starts(), 1)
        finally:
            if other.poll() is None:
                other.terminate()
                other.communicate(timeout=5)

    def test_signer_timeout_recovers_even_if_app_stayed_ready(self):
        self.publish(1, self.session)
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertTrue(self.ops)
        self.assertEqual(set(self.ops), {"observe"})

    def test_signer_exit_during_observation_cannot_be_rearmed(self):
        """A signer dying after tick's first poll must halt before a pending restart."""
        self.proc.terminate()
        self.proc.wait(timeout=5)
        spec = importlib.util.spec_from_file_location("etna_guard_exit_race", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        entered, release = threading.Event(), threading.Event()
        worker = None
        with patch.dict(os.environ, self.env, clear=True):
            runtime = module.Supervisor()
            runtime.acquire_owner()
            try:
                runtime.start()
                self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
                self.ready, self.phase = False, "acquiring"
                self.publish(1, self.session)
                runtime.tick()  # Record an ordinary refusal while trust is still closed.
                self.ready, self.phase = True, "ready"
                self.observation_hold = (entered, release)
                worker = threading.Thread(target=runtime.tick)
                worker.start()
                self.assertTrue(entered.wait(timeout=3), "supervisor did not enter private observation")
                runtime.signer.kill()
                runtime.signer.wait(timeout=3)
                release.set()
                worker.join(timeout=5)
                self.assertFalse(worker.is_alive(), "supervisor recovery did not finish")
                self.assertTrue((self.store / "validator-supervisor.halted").exists(),
                                "a signer exit during observation bypassed the terminal latch")
                self.assertEqual(self.starts(), 2, "supervisor restarted abnormal signing authority")
                self.assertEqual(self.state.read_text(), "authoritative HRS")
            finally:
                release.set()
                if worker is not None:
                    worker.join(timeout=5)
                runtime.stop()
                for descriptor in runtime.owner_fds:
                    os.close(descriptor)
                self.observation_hold = None

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
        configured = self.generation
        self.generation += 1
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.generation = configured
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


class RecoveredSupervisorTests(SupervisorTests):
    """Repeat the lifecycle gates for an explicitly configured recovered domain."""

    def configure_identity(self):
        self.chain, self.generation, self.schema = "etna-recovered-test-domain", 1, 2
        self.authority = self.root / "private/authority"
        self.identity_env = dict(ETNA_GENERATION="1", ETNA_AUTHORITY_ROOT=str(self.authority),
                                 ETNA_L1_CHAIN_ID="31337", ETNA_L2_CHAIN_ID="167001",
                                 ETNA_INBOX="0x" + "11" * 20)
        self.origin = dict(generation=1, height=7, l1_number=10, l1_hash="0x" + "12" * 32,
                           l1_timestamp=123, el_hash="0x" + "23" * 32,
                           comet_hash="0x" + "34" * 32, forced_cursor=2,
                           committee_hash="0x" + "45" * 32)

    def test_later_generation_cannot_acknowledge_retained_signer_fence(self):
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        fence = self.state.with_name(self.state.name + ".uncertain")
        evidence = b'{"operation":"interrupted FilePV signing"'
        fence.write_bytes(evidence)
        latch = self.store / "validator-supervisor.halted"
        latch.write_text(json.dumps(dict(schema=1, kind="expected-generation-supersession",
                                        chain_id=self.chain, previous_generation=1, current_generation=2,
                                        evidence_digest="ab" * 32)))
        self.env["ETNA_GENERATION"] = "2"
        self.generation = 2
        self.origin["generation"] = 2
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: latch.read_bytes() == b"signer exited; inspect diagnostics\n")
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(fence.read_bytes(), evidence)
        self.assertEqual(self.key.read_text(), "existing key")
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_generation_one_start_retains_flags_while_trust_closes(self):
        """Check supervisor flags with sleeping peers; native recovery covers the handshake."""
        self.ready, self.phase = False, "acquiring"
        time.sleep(.3)
        args = self.signers()[0]["argv"]
        self.assertEqual(args[args.index("--generation") + 1], "1")
        self.assertEqual(args[args.index("--authority-root") + 1], str(self.authority.resolve()))
        self.assertNotIn("--await-trust", args)
        self.assertNotIn("--enroll-legacy", args)
        self.assertEqual(self.starts(), 1)
        self.ready, self.phase = True, "ready"
        time.sleep(.3)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual({request["schema_version"] for request in self.requests}, {2})

    def test_generation_one_trust_restart_preserves_signing_state(self):
        self.authority.mkdir(parents=True)
        recovered_state = self.authority / (self.chain + ".json")
        recovered_state.write_text("existing generation-one HRS")
        hrs_before_restart = self.state.read_bytes(), recovered_state.read_bytes()
        self.ready, self.phase = False, "acquiring"
        self.publish(1, self.session)
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.ready, self.phase = True, "ready"
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        observation = self.observations[-1]
        self.assertEqual(observation["generation"], 1)
        hrs_after_restart = self.state.read_bytes(), recovered_state.read_bytes()
        self.assertEqual(hrs_before_restart, hrs_after_restart)
        events = (self.root / "lifecycle").read_text().splitlines()
        self.assertEqual(events.index("comet_reaped") < events.index("signer_stopped"), True)

    def test_generation_two_observation_never_switches_or_enrolls(self):
        self.assert_observed_generation_halts(2)

    def test_old_generation_zero_observation_never_switches_or_enrolls(self):
        self.assert_observed_generation_halts(0)

    def assert_observed_generation_halts(self, generation):
        self.generation = generation
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.starts(), 1)
        self.assertFalse(self.authority.exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_restart_always_preserves_unrelated_fatal_latch(self):
        self.phase = "halted"
        self.extra = dict(reason="contradictory finalized checkpoint")
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists)
        evidence = latch.read_bytes()
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.env["ETNA_GENERATION"] = "2"
        self.generation = 2
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.4)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(latch.read_bytes(), evidence)

    def test_explicit_generation_two_starts_with_its_own_identity(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.generation = 2
        self.origin["generation"] = 2
        self.env["ETNA_GENERATION"] = "2"
        self.env["ETNA_ENROLL_LEGACY"] = "1"
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        args = self.signers()[1]["argv"]
        self.assertEqual(args[args.index("--generation") + 1], "2")
        self.assertIn("--enroll-legacy", args)
        time.sleep(.3)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())

    def assert_configuration_refused(self, changes):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.env.update(changes)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.assertNotEqual(self.proc.wait(timeout=5), 0)
        self.assertEqual(self.starts(), 1)

    def test_recovery_requires_complete_authority_configuration(self):
        self.assert_configuration_refused(dict(ETNA_AUTHORITY_ROOT=""))

    def test_generation_must_be_uint48(self):
        self.assert_configuration_refused(dict(ETNA_GENERATION=str(1 << 48)))

    def test_authority_root_must_be_outside_disposable_app_store(self):
        self.assert_configuration_refused(dict(ETNA_AUTHORITY_ROOT=str(self.store / "authority")))

    def test_incomplete_authority_tuple_fails_before_children_start(self):
        self.assert_configuration_refused(dict(ETNA_L2_CHAIN_ID=""))

    def test_enrollment_flag_must_be_explicit_boolean(self):
        self.assert_configuration_refused(dict(ETNA_ENROLL_LEGACY="yes"))

    def test_configured_chain_must_equal_genesis(self):
        self.assert_configuration_refused(dict(ETNA_CHAIN_ID="other-generation-domain"))


class UnixSupervisorTests(SupervisorTests):
    """Repeat lifecycle gates over Unix sockets; like stock Comet, the listener leaves its inode."""

    def configure_transport(self):
        (self.home / "run").mkdir(mode=0o700)
        # Only the scheme matters: the supervisor assigns every pair its own socket name.
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://run/signer.sock"\n')

    def comet_body(self):
        # Bind the assigned listener and never unlink it, as after an unclean stock exit.
        return ('import json,os,socket,sys\nfrom pathlib import Path\n'
                'address=sys.argv[sys.argv.index("--priv_validator_laddr")+1]\n'
                's=socket.socket(socket.AF_UNIX)\ns.bind(address.removeprefix("unix://"))\ns.listen()\n'
                'with Path(os.environ["COMET_PID"]).with_name("comets").open("a") as out:\n'
                ' out.write(json.dumps(dict(argv=sys.argv[1:],cwd=os.getcwd()))+"\\n")\n'
                + super().comet_body())

    def comets(self):
        path = self.root / "comets"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def listener(self, index):
        return self.comets()[index]["argv"][-1].removeprefix("unix://")

    def stop_supervisor(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.assertTrue(Path(self.listener(-1)).is_socket())

    def restart_supervisor(self):
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)

    def assert_refused(self):
        self.restart_supervisor()
        self.assertNotEqual(self.proc.wait(timeout=5), 0)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")

    def test_each_pair_start_uses_one_fresh_socket(self):
        self.publish(1, self.session)
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        pattern = re.escape(str(self.home.resolve() / "run")) + r"/signer-[0-9a-f]{16}\.sock"
        addresses = []
        for comet, signer in zip(self.comets(), self.signers(), strict=True):
            address = comet["argv"][-1]
            self.assertEqual(comet["argv"][-2:], ["--priv_validator_laddr", address])
            self.assertRegex(address, "^unix://" + pattern + "$")
            self.assertEqual(comet["cwd"], str(self.home.resolve()))
            argv = signer["argv"]
            self.assertEqual(argv[argv.index("--comet-signer-addr") + 1], address)
            addresses.append(address)
        self.assertNotEqual(*addresses)
        self.assertFalse(os.path.lexists(addresses[0].removeprefix("unix://")))

    def test_stale_prefixed_entries_are_removed_before_start(self):
        self.stop_supervisor()
        run = self.home / "run"
        previous = self.listener(-1)
        with socket.socket(socket.AF_UNIX) as stale:
            stale.bind(str(run / "signer-aaaa.sock"))
        (run / "signer-bbbb.sock").write_text("stale regular file")
        (run / "signer-cccc.sock").symlink_to(self.key)
        for name in ("other.sock", "signer.sock"):
            with socket.socket(socket.AF_UNIX) as foreign:
                foreign.bind(str(run / name))
        kept = {name: (run / name).lstat().st_ino for name in ("other.sock", "signer.sock")}
        self.restart_supervisor()
        self.wait(lambda: self.starts() == 2)
        for path in (previous, run / "signer-aaaa.sock", run / "signer-bbbb.sock", run / "signer-cccc.sock"):
            self.assertFalse(os.path.lexists(path), path)
        self.assertEqual(self.key.read_text(), "existing key")
        self.assertEqual({name: (run / name).lstat().st_ino for name in kept}, kept)
        self.assertTrue(Path(self.listener(-1)).is_socket())

    def test_configured_unix_path_is_only_a_marker(self):
        self.stop_supervisor()
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        with socket.socket(socket.AF_UNIX) as stale:
            stale.bind(str(elsewhere / "signer-dddd.sock"))
        before = {entry.name: entry.lstat().st_ino for entry in elsewhere.iterdir()}
        (self.home / "config/config.toml").write_text(f'priv_validator_laddr = "unix://{elsewhere / "x.sock"}"\n')
        self.restart_supervisor()
        self.wait(lambda: self.starts() == 2)
        self.assertEqual({entry.name: entry.lstat().st_ino for entry in elsewhere.iterdir()}, before)
        self.assertEqual(Path(self.listener(-1)).parent, self.home.resolve() / "run")

    def test_symlinked_run_directory_is_refused(self):
        self.stop_supervisor()
        directory = self.home / "run"
        moved = self.home / "real-run"
        directory.rename(moved)
        directory.symlink_to(moved, target_is_directory=True)
        before = {entry.name: entry.lstat().st_ino for entry in moved.iterdir()}
        self.assertTrue(before, "the previous listener must remain as a stale entry")
        self.assert_refused()
        self.assertEqual({entry.name: entry.lstat().st_ino for entry in moved.iterdir()}, before)

    def test_missing_run_directory_is_refused(self):
        self.stop_supervisor()
        shutil.rmtree(self.home / "run")
        self.assert_refused()
        self.assertFalse(os.path.lexists(self.home / "run"))

    def test_overlong_socket_path_is_refused_before_children(self):
        self.stop_supervisor()
        home = self.root / ("x" * 80) / "comet"
        (home / "run").mkdir(mode=0o700, parents=True)
        shutil.copytree(self.home / "config", home / "config")
        refused = subprocess.run(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                 env=dict(self.env, ETNA_COMET_HOME=str(home)), capture_output=True, timeout=5)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn(b"Comet home too long for a Unix signer socket", refused.stderr)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(os.listdir(home / "run"), [])


def cap_eff(pid):
    """Effective capability mask of a live Linux process."""
    status = Path(f"/proc/{pid}/status").read_text().splitlines()
    return int(next(line.split()[1] for line in status if line.startswith("CapEff:")), 16)


DOCUMENTED_CAPS = (1 << 1) | (1 << 5) | (1 << 6) | (1 << 7)  # DAC_OVERRIDE|KILL|SETGID|SETUID == 0xe2


@unittest.skipUnless(sys.platform == "linux" and os.geteuid() == 0 and os.environ.get("ETNA_MIN_CAPS_TEST") == "1",
                     "needs Linux root holding only the documented capabilities; run just supervisor-caps-test")
class MinimalCapabilityTests(TrustPeer, unittest.TestCase):
    """Restart stock-like Comet under the documented supervisor capability set only."""

    COMET_UID = 10001

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-caps-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.root.chmod(0o755)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        self.chain, self.generation, self.schema = "etna-test", 0, 1
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://run/signer.sock"\n')
        (self.home / "config/genesis.json").write_text(json.dumps(dict(chain_id=self.chain)))
        # Without CAP_CHOWN, let the Comet UID create its own private run/ in a briefly open home.
        self.home.chmod(0o777)
        subprocess.run([sys.executable, "-c", "import os,sys; os.mkdir(sys.argv[1], 0o700)", str(self.home / "run")],
                       user=self.COMET_UID, group=self.COMET_UID, extra_groups=[], check=True)
        self.home.chmod(0o755)
        self.observed = self.root / "observed"
        self.observed.mkdir()
        self.observed.chmod(0o777)
        self.store = self.root / "app"
        self.store.mkdir()
        self.key, self.state = self.root / "key.json", self.root / "state.json"
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.events = self.root / "denial.json"
        self.latch = self.store / "validator-supervisor.halted"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            # Unprivileged stock-like Comet: bind the assigned listener, record it, never unlink it.
            "cometbft": ('import json,os,socket,sys,time\n'
                         'path=sys.argv[sys.argv.index("--priv_validator_laddr")+1].removeprefix("unix://")\n'
                         's=socket.socket(socket.AF_UNIX)\ns.bind(path)\ns.listen()\n'
                         'with open(os.path.join(os.environ["OBSERVED"],"comets"),"a") as out:\n'
                         ' out.write(json.dumps(dict(pid=os.getpid(),path=path))+"\\n")\n'
                         'while True: time.sleep(1)'),
            # Root signer: connect to Comet's listener, as the real signer dials it.
            "signer": ('import json,os,socket,sys,time\n'
                       'argv=sys.argv[1:]\n'
                       'open(os.environ["SIGNERS"],"a").write(json.dumps(dict(pid=os.getpid(),argv=argv))+"\\n")\n'
                       'path=argv[argv.index("--comet-signer-addr")+1].removeprefix("unix://")\n'
                       'while True:\n'
                       ' peer=socket.socket(socket.AF_UNIX)\n'
                       ' try: peer.connect(path); break\n'
                       ' except OSError: peer.close(); time.sleep(.05)\n'
                       'with open(os.path.join(os.environ["OBSERVED"],"connected"),"a") as out:\n'
                       ' out.write("connected "+path+"\\n")\n'
                       'while True: time.sleep(1)'),
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE=str(self.state),
                        ETNA_CHAIN_ID=self.chain, ETNA_SIGNER_BIN=str(self.bin / "signer"),
                        ETNA_DENIAL_FILE=str(self.events), ETNA_COMET_UID=str(self.COMET_UID),
                        ETNA_COMET_GID=str(self.COMET_UID), OBSERVED=str(self.observed),
                        SIGNERS=str(self.root / "signers"), PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.log = (self.root / "runtime.log").open("w+")
        self.proc = None
        self.start_peer()
        self.start_supervisor()

    def tearDown(self):
        if self.proc.poll() is None:
            self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        for pid in [comet["pid"] for comet in self.comets()] + [signer["pid"] for signer in self.signers()]:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        self.stop_peer()
        self.log.close()
        self.tmp.cleanup()

    def start_supervisor(self):
        if self.proc is not None:
            self.proc.wait(timeout=5)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")], env=self.env,
                                     stdout=self.log, stderr=self.log, start_new_session=True)

    def comets(self):
        path = self.observed / "comets"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def connected(self):
        path = self.observed / "connected"
        return [line.removeprefix("connected ") for line in path.read_text().splitlines()] if path.exists() else []

    def comet_pid(self):
        return self.comets()[-1]["pid"]

    def signer_pid(self):
        return self.signers()[-1]["pid"]

    def wait_socket(self, count):
        """Return the count-th Comet listener once the root signer has connected to it."""
        self.wait(lambda: len(self.comets()) >= count and len(self.connected()) >= count)
        return Path(self.comets()[count - 1]["path"])

    def test_unclean_comet_exit_stale_socket_supervisor_restarts_pair(self):
        self.assertEqual(cap_eff(self.proc.pid), DOCUMENTED_CAPS)
        stale = self.wait_socket(1)
        self.assertEqual(stale.lstat().st_uid, self.COMET_UID)
        if Path("/proc/sys/fs/protected_hardlinks").read_text().strip() == "1":
            with self.assertRaises(PermissionError):  # the old inode pin needed CAP_FOWNER
                os.link(stale, self.root / "pin")
        self.phase = "acquiring"
        time.sleep(.3)  # observed trust loss
        os.kill(self.comet_pid(), signal.SIGKILL)  # stock leaves its socket inode
        time.sleep(.3)  # the supervisor sees the exit while trust is still lost
        self.phase = "ready"
        self.publish_recovery_session()
        fresh = self.wait_socket(2)
        self.assertNotEqual(fresh, stale)
        self.assertFalse(os.path.lexists(stale))
        self.assertEqual(self.connected()[-1], str(fresh))
        self.assertFalse(self.latch.exists())
        self.assertIsNone(self.proc.poll())

    def test_killed_runtime_restarts_over_stale_socket(self):
        stale = self.wait_socket(1)
        for pid in (self.proc.pid, self.comet_pid(), self.signer_pid()):
            os.kill(pid, signal.SIGKILL)
        self.start_supervisor()
        fresh = self.wait_socket(2)
        self.assertFalse(os.path.lexists(stale))
        self.assertEqual(self.connected()[-1], str(fresh))


class LauncherPathTests(unittest.TestCase):
    def load_module(self):
        spec = importlib.util.spec_from_file_location("etna_guard_paths", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_both_launchers_refuse_late_escaped_detached_journal_before_children(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            app, home = base / "app", base / "comet"
            app.mkdir(); (home / "config").mkdir(parents=True)
            (home / "config/config.toml").write_text('priv_validator_laddr = ""')
            raw = b" " * 4096 + b'{"state":{},"schema":1,"installa' + b'\\u0074ion_id":"detached"}'
            self.assertEqual(json.loads(raw)["installation_id"], "detached")
            (app / "abci-state.json").write_bytes(raw)
            for script in ("start_etna_full_node.py", "etna_validator.py"):
                with self.subTest(script=script):
                    env = dict(ETNA_APP_STORE=str(app), ETNA_COMET_HOME=str(home), ETNA_COMET_BIN="/usr/bin/true", PATH=os.defpath)
                    proc = subprocess.run([os.sys.executable, str(ROOT / "script" / script)], env=env, capture_output=True)
                    self.assertNotEqual(proc.returncode, 0)
                    self.assertIn(b"incomplete or mixed import paths", proc.stderr)
                    self.assertEqual((app / "abci-state.json").read_bytes(), raw)

    def test_imported_rearm_uses_a_fresh_private_denial_route_and_preserves_prior_observation(self):
        module = self.load_module()
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            store, home = base / "app", base / "comet"
            store.mkdir(); (home / "config").mkdir(parents=True)
            (home / "config/config.toml").write_text('priv_validator_laddr="tcp://127.0.0.1:12345"')
            (home / "config/genesis.json").write_text('{"chain_id":"test"}')
            key, state = base / "key", base / "hrs"
            key.write_bytes(b"registered"); state.write_bytes(b"authoritative HRS")
            prior = store / "signer-denial.json"
            historical = b'{"sequence":5,"session_id":"old-private-session"}'
            prior.write_bytes(historical)
            imported = dict(signer_binary="/usr/bin/true", comet_binary="/usr/bin/true",
                            comet_identity=[os.geteuid(), os.getegid()])
            env = dict(ETNA_APP_STORE=str(store), ETNA_COMET_HOME=str(home), ETNA_PRIV_KEY=str(key),
                       ETNA_PRIV_STATE=str(state), ETNA_CHAIN_ID="test")
            with patch.dict(os.environ,env,clear=True), patch.object(module.etna_import_guard,"launch_info",return_value=imported), patch.object(module.subprocess,"Popen") as spawn:
                runtime = module.Supervisor()
                routes = []
                for _ in range(2):
                    runtime.start(await_trust=True)
                    argv = spawn.call_args.args[0]
                    actual = Path(argv[argv.index("--denial-file") + 1])
                    self.assertTrue(actual.is_relative_to(store))
                    self.assertNotEqual(actual, prior)
                    self.assertEqual(actual.parent.stat().st_mode & 0o077, 0)
                    self.assertFalse(actual.exists())
                    actual.write_text('{"sequence":0,"session_id":"fresh"}')
                    routes.append(actual)
                    runtime.stop()
                    self.assertFalse(actual.parent.exists())
                self.assertNotEqual(*routes)
            self.assertEqual(prior.read_bytes(), historical)
            self.assertEqual((key.read_bytes(), state.read_bytes()), (b"registered", b"authoritative HRS"))

    def test_denial_routes_preserve_keys_state_wal_and_uncertain_files(self):
        module = self.load_module()
        for case in ("key", "state", "old-wal", "default-key", "default-state", "scratch-hardlink",
                     "scratch-symlink", "default-foreign", "ordinary-foreign", "ordinary-live-wal"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp).resolve()
                store, home = base / "app", base / "home"
                store.mkdir(); (home / "config").mkdir(parents=True)
                (home / "config/config.toml").write_text('priv_validator_laddr="tcp://127.0.0.1:12345"')
                (home / "config/genesis.json").write_text('{"chain_id":"test"}')
                default = store / "signer-denial.json"
                key = default if case == "default-key" else base / "key"
                state = default if case == "default-state" else base / "state"
                wal = (home if case == "ordinary-live-wal" else base / "older") / "data/cs.wal/wal"
                wal.parent.mkdir(parents=True);wal.write_bytes(b"old wal");key.write_bytes(b"registered key");state.write_bytes(b"authoritative HRS")
                env = dict(ETNA_APP_STORE=str(store), ETNA_COMET_HOME=str(home),ETNA_PRIV_KEY=str(key),
                           ETNA_PRIV_STATE=str(state), ETNA_CHAIN_ID="test", ETNA_SIGNER_BIN="/usr/bin/true")
                if case in ("key","state","old-wal","ordinary-live-wal"):
                    env["ETNA_DENIAL_FILE"] = str({"key":key,"state":state}.get(case,wal))
                if case == "scratch-hardlink": os.link(state, str(default)+".tmp")
                if case == "scratch-symlink": Path(str(default)+".tmp").symlink_to(key)
                if case in ("default-foreign","ordinary-foreign"): default.write_bytes(b"foreign preserved bytes")
                saved = {p: p.read_bytes() for p in (key,state,wal,default) if p.exists()}
                imported = None if case.startswith("ordinary-") else dict(signer_binary="/usr/bin/true",comet_binary="/usr/bin/true",comet_identity=[os.geteuid(),os.getegid()])
                with patch.dict(os.environ,env,clear=True), patch.object(module.etna_import_guard,"launch_info",return_value=imported), patch.object(module.subprocess,"Popen") as spawn:
                    with self.assertRaises(ValueError): module.Supervisor().start()
                    spawn.assert_not_called()
                for p, expected in saved.items(): self.assertEqual(p.read_bytes(),expected)


class TypedSupersessionTests(unittest.TestCase):
    def supersession_with_children(self, directory, signer_status):
        """Create authentic first-cause bytes and real children with controlled exit status."""
        import hashlib
        spec = importlib.util.spec_from_file_location("etna_supersession_stop", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        store = Path(directory)
        runtime = object.__new__(module.Supervisor)
        runtime.store, runtime.chain, runtime.generation = store, "old-chain", 0
        runtime.state = store / "hrs.json"
        runtime.latch = store / "validator-supervisor.halted"
        runtime.imported, runtime.container, runtime.event_scratch = None, None, None
        state = json.dumps(dict(chain_id="old-chain", generation=0, inbox="0x01")).encode()
        fatal = b"authenticated higher recovery generation"
        evidence = dict(schema=1, chain_id="old-chain", previous_generation=0, current_generation=1,
                        inbox="0x01", state_digest=hashlib.sha256(state).hexdigest(),
                        fatal_digest=hashlib.sha256(fatal).hexdigest())
        preserved = {"abci-state.json": state, "fatal-evidence.txt": fatal,
                     "generation-superseded.json": json.dumps(evidence).encode(),
                     "key.json": b"registered key", "hrs.json": b"retained HRS"}
        for name, raw in preserved.items():
            (store / name).write_bytes(raw)
        children = []
        for name, status in (("comet", 0), ("signer", signer_status)):
            ready, observed = store / (name + ".ready"), store / (name + ".halt")
            body = ("import signal,sys,time\nfrom pathlib import Path\n"
                    "def stop(*_):\n"
                    " p=Path(sys.argv[1]); Path(sys.argv[2]).write_bytes(p.read_bytes() if p.exists() else b'absent')\n"
                    " sys.exit(int(sys.argv[4]))\n"
                    "signal.signal(signal.SIGTERM,stop)\n"
                    "Path(sys.argv[3]).touch()\ntime.sleep(30)\n")
            child = subprocess.Popen([os.sys.executable, "-c", body, str(runtime.latch), str(observed), str(ready), str(status)])
            children.append(child)
            setattr(runtime, name, child)
            deadline = time.monotonic() + 3
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(ready.exists(), "child did not install its stop handler")
        def cleanup():
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=3)
        self.addCleanup(cleanup)
        return runtime, preserved

    def test_supersession_publication_waits_for_clean_signer_shutdown(self):
        for signer_status in (0, 1):
            with self.subTest(signer_status=signer_status), tempfile.TemporaryDirectory() as directory:
                runtime, preserved = self.supersession_with_children(directory, signer_status)
                reason = "terminal app trust or deployment identity"
                runtime.halt(reason, dict(phase="halted", chain_id="old-chain", generation=0))
                self.assertEqual((runtime.store / "signer.halt").read_bytes(), (reason + "\n").encode(),
                                 "recovery became acknowledgeable before signer shutdown completed")
                if signer_status == 0:
                    latch = json.loads(runtime.latch.read_bytes())
                    self.assertEqual(latch["kind"], "expected-generation-supersession")
                else:
                    self.assertEqual(runtime.latch.read_bytes(), (reason + "\n").encode(),
                                     "failed signing authority left an acknowledgeable supersession")
                for name, raw in preserved.items():
                    self.assertEqual((runtime.store / name).read_bytes(), raw)

    def test_existing_latch_cannot_hide_signer_failure_during_stop(self):
        for generic in (False, True):
            with self.subTest(generic=generic), tempfile.TemporaryDirectory() as directory:
                runtime, preserved = self.supersession_with_children(directory, 1)
                if generic:
                    original = b"original generic safety halt\n"
                else:
                    original = json.dumps(runtime.expected_supersession(
                        dict(phase="halted", chain_id="old-chain", generation=0))).encode()
                runtime.latch.write_bytes(original)
                runtime.tick()
                if generic:
                    self.assertEqual(runtime.latch.read_bytes(), original)
                else:
                    with self.assertRaises(ValueError):
                        json.loads(runtime.latch.read_bytes())
                for name, raw in preserved.items():
                    self.assertEqual((runtime.store / name).read_bytes(), raw)

    def test_comet_identity_keeps_privileged_group_drop_and_same_uid_native_path(self):
        spec = importlib.util.spec_from_file_location("etna_identity_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runtime = object.__new__(module.Supervisor)
        runtime.imported = None
        runtime.container, runtime.home, runtime.unix_run = None, Path("/private/runtime"), None
        runtime.comet_command = ["/cometbft", "start"]
        runtime.child_options = lambda _: {}
        for current_uid, current_gid, uid, gid, expected in [
                (501, 20, 501, 20, {}),
                (0, 0, 10001, 10001, dict(user=10001, group=10001, extra_groups=[])),
                (501, 20, 10001, 10001, dict(user=10001, group=10001, extra_groups=[]))]:
            with self.subTest(current_uid=current_uid, uid=uid), patch.dict(os.environ, {"ETNA_COMET_UID":str(uid), "ETNA_COMET_GID":str(gid)}), patch.object(module.os, "geteuid", return_value=current_uid), patch.object(module.os, "getegid", return_value=current_gid), patch.object(module.subprocess, "Popen") as spawn:
                runtime.start_comet()
                self.assertEqual(spawn.call_args.kwargs, dict(cwd=runtime.home, **expected))

    def test_explicit_command_prefix_preserves_arguments_without_shell(self):
        spec = importlib.util.spec_from_file_location("etna_command_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        prefix = ["/usr/bin/python3", "/private/custom signer.py", "literal;$()"]
        with patch.dict(os.environ, {"ETNA_SIGNER_COMMAND_JSON": json.dumps(prefix)}):
            self.assertEqual(module.Supervisor.command_prefix("ETNA_SIGNER_COMMAND_JSON", ["/etna-signer"]), prefix)
        with patch.dict(os.environ, {"ETNA_SIGNER_COMMAND_JSON": "{bad}"}):
            with self.assertRaises(ValueError):
                module.Supervisor.command_prefix("ETNA_SIGNER_COMMAND_JSON", ["/etna-signer"])

    def test_child_overrides_cannot_replace_ownership_lifetime(self):
        spec = importlib.util.spec_from_file_location("etna_env_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runtime = object.__new__(module.Supervisor)
        runtime.imported = None
        runtime.owner_fds = []
        lifetime, peer = socket.socketpair()
        with lifetime, peer:
            with patch.dict(os.environ, {"ETNA_OWNER_LIFETIME_FD": str(lifetime.fileno()), "ETNA_COMET_ENV_JSON": json.dumps({"ETNA_OWNER_LIFETIME_FD":"99999", "ETNA_OWNER_JOIN":"foreign"})}):
                options = runtime.child_options("ETNA_COMET_ENV_JSON")
                self.assertEqual(options["pass_fds"], (lifetime.fileno(),))
                self.assertNotIn("ETNA_OWNER_LIFETIME_FD", options["env"])
                self.assertNotIn("ETNA_OWNER_JOIN", options["env"])

    def test_only_exact_first_cause_evidence_gets_structured_latch(self):
        import hashlib
        spec = importlib.util.spec_from_file_location("etna_typed_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for changed in (None, "imported", "large-import", "foreign-import", "missing", "fatal", "state", "domain", "generic"):
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory:
                store = Path(directory)
                runtime = object.__new__(module.Supervisor)
                runtime.store, runtime.chain, runtime.generation = store, "old-chain", 0
                runtime.state = store / "hrs.json"
                runtime.latch = store / "validator-supervisor.halted"
                runtime.stop = lambda: None
                state = json.dumps(dict(chain_id="old-chain", generation=0, inbox="0x01")).encode()
                runtime.imported = None
                if changed in ("imported", "large-import", "foreign-import"):
                    runtime.imported = {"installation_id": "0x" + "11" * 32}
                    identity = runtime.imported["installation_id"] if changed != "foreign-import" else "0x" + "22" * 32
                    state = json.dumps(dict(schema=1, installation_id=identity, state=json.loads(state))).encode()
                    if changed == "large-import":
                        state = b" " * (2 * 1024 * 1024) + state
                fatal = b"authenticated higher recovery generation"
                evidence = dict(schema=1, chain_id="old-chain", previous_generation=0,
                                current_generation=1, inbox="0x01", state_digest=hashlib.sha256(state).hexdigest(),
                                fatal_digest=hashlib.sha256(fatal).hexdigest())
                (store / "abci-state.json").write_bytes(state)
                (store / "fatal-evidence.txt").write_bytes(fatal)
                sidecar = store / "generation-superseded.json"
                sidecar.write_text(json.dumps(evidence))
                if changed == "missing": sidecar.unlink()
                if changed == "fatal": (store / "fatal-evidence.txt").write_text("unrelated safety failure")
                if changed == "state": (store / "abci-state.json").write_bytes(state + b" ")
                if changed == "domain": runtime.chain = "foreign"
                if changed == "generic": runtime.latch.write_text("terminal app trust or deployment identity\n")
                snapshot = dict(phase="halted", chain_id="old-chain", generation=0)
                runtime.halt("terminal app trust or deployment identity", snapshot)
                if changed in (None, "imported", "large-import"):
                    latch = json.loads(runtime.latch.read_text())
                    self.assertEqual(latch["kind"], "expected-generation-supersession")
                    self.assertEqual(latch["evidence_digest"], hashlib.sha256(sidecar.read_bytes()).hexdigest())
                else:
                    self.assertEqual(runtime.latch.read_text(), "terminal app trust or deployment identity\n")
                self.assertTrue((store / "fatal-evidence.txt").exists())


if __name__ == "__main__":
    unittest.main()
