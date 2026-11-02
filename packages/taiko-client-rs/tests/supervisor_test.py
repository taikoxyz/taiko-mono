"""Real child-process supervision with a controlled private trust peer."""
import importlib.util
import fcntl
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
        self.ready = True
        self.phase = "ready"
        self.session = "same-session"
        self.extra = {}
        self.ops = []
        self.requests, self.observations = [], []
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

    def test_terminal_group_interrupt_stops_comet_before_signer(self):
        self.assertEqual(os.getpgid(self.proc.pid), self.proc.pid)
        os.killpg(self.proc.pid, signal.SIGINT)
        self.assertEqual(self.proc.wait(timeout=5), 0)
        lifecycle = self.root / "lifecycle"
        self.assertTrue(lifecycle.exists(), "terminal SIGINT bypassed ordered supervisor stop")
        self.assertEqual(lifecycle.read_text().splitlines()[-2:], ["comet_reaped", "signer_stopped"])

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

    def test_generation_one_first_start_keeps_closed_handshake(self):
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

    def test_unsafe_relative_transports_are_rejected_without_state_changes(self):
        self.stop_supervisor()
        latch = self.store / "validator-supervisor.halted"
        latch.write_text("retained safety latch")
        for address in ("../run/signer.sock", "run/../run/signer.sock", "outside/signer.sock", "run/nested/signer.sock"):
            (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://' + address + '"\n')
            self.assert_refused()
            self.assertEqual(latch.read_text(), "retained safety latch")

    def test_relative_prepared_transport_uses_home_cwd(self):
        self.stop_supervisor()
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://run/signer.sock"\n')
        comet = self.bin / "cometbft"
        comet.write_text("#!/usr/bin/env python3\nimport os\nassert os.getcwd() == " + repr(str(self.home.resolve())) + "\n" + self.comet_body())
        self.restart_supervisor()
        self.wait(lambda: self.starts() == 2)
        signer_args = self.signers()[-1]["argv"]
        self.assertEqual(signer_args[signer_args.index("--comet-signer-addr") + 1],
                         "unix://" + str(self.transport.resolve()))

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
