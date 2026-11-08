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
                response = dict(schema_version=1, session_id=self.session, chain_id=self.chain,
                                generation=self.generation, phase=self.phase, target=None,
                                committed_head=None, trusted_consensus_head=None, reason=None,
                                recovery_origin=self.origin if self.ready else None)
                response.update(self.extra)
                self.observations.append(response)
                held = self.observation_hold
                if held is not None:
                    held[0].set()
                    held[1].wait(timeout=5)
                peer.sendall((json.dumps(response) + "\n").encode())

    def publish(self, sequence, session):
        """Publish a signer observation atomically, as the real signer does."""
        descriptor, temporary = tempfile.mkstemp(prefix=".signer-observation-", dir=self.events.parent)
        with os.fdopen(descriptor, "w") as out:
            out.write(json.dumps(dict(sequence=sequence, session_id=session)))
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

    def wait(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
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
        self.chain, self.generation, self.origin = "etna-test", 0, None
        self.identity_env = {}
        self.configure_identity()
        (self.home / "config/genesis.json").write_text(json.dumps(dict(chain_id=self.chain)))
        self.store = self.root / "app"
        self.store.mkdir()
        self.key = self.root / "key.json"
        # init-state's layout: one HRS per chain_id, the domains log in another directory.
        self.state_dir, self.domains_log = self.root / "hrs", self.root / "domains/domains.log"
        self.state = self.state_dir / (self.chain + ".json")
        self.state_dir.mkdir()
        self.domains_log.parent.mkdir()
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.domains_log.write_text("etna-signer-domains-v1\n" + self.chain + "\n")
        self.count = self.root / "starts"
        self.events = self.root / "denial.json"
        self.start_peer()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "cometbft": self.comet_body(),
            # The control files signer_exit_on_start and signer_exit_on_term hold the exit code
            # the next signer uses right after starting, or when the supervisor stops it;
            # signer_exit_now makes the running signer exit with its code once, as a crash, and
            # signer_hang_on_term makes it ignore the supervisor's SIGTERM. Each start records
            # which earlier signers and which Comet were still alive.
            "signer": ('import json,os,signal,sys,time\nfrom pathlib import Path\n'
                       'root=Path(os.environ["COMET_PID"]).parent\n'
                       'def code(name):\n'
                       ' p=root/name\n'
                       ' return int(p.read_text()) if p.exists() else None\n'
                       'def alive(pid):\n'
                       ' try: os.kill(pid,0); return True\n'
                       ' except ProcessLookupError: return False\n'
                       'def stop(*_):\n'
                       ' p=Path(os.environ["COMET_PID"])\n'
                       ' event="comet_alive" if alive(int(p.read_text())) else "comet_reaped"\n'
                       ' with p.with_name("lifecycle").open("a") as out: out.write(event+"\\nsigner_stopped\\n")\n'
                       ' if (root/"signer_hang_on_term").exists():\n'
                       '  while True: time.sleep(1)\n'
                       ' sys.exit(code("signer_exit_on_term") or 0)\n'
                       'signal.signal(signal.SIGTERM,stop)\n'
                       'signers=Path(os.environ["SIGNERS"])\n'
                       'earlier=[json.loads(line)["pid"] for line in signers.read_text().splitlines()] if signers.exists() else []\n'
                       'comet=Path(os.environ["COMET_PID"])\n'
                       'record=dict(pid=os.getpid(),argv=sys.argv[1:],alive=[pid for pid in earlier if alive(pid)],\n'
                       ' comet_alive=comet.exists() and alive(int(comet.read_text())))\n'
                       'signers.open("a").write(json.dumps(record)+"\\n")\n'
                       'if code("signer_exit_on_start") is not None: sys.exit(code("signer_exit_on_start"))\n'
                       'while not Path(os.environ["COMET_PID"]).with_name("release_signer").exists():\n'
                       ' now=code("signer_exit_now")\n'
                       ' if now is not None: (root/"signer_exit_now").unlink(); sys.exit(now)\n'
                       ' time.sleep(.05)'),
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE_DIR=str(self.state_dir),
                        ETNA_DOMAINS_LOG=str(self.domains_log),
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
        # Record the argv and working directory each Comet start receives.
        return ('from pathlib import Path\nimport json,os,sys,time\n'
                'with Path(os.environ["COMET_PID"]).with_name("comets").open("a") as out:\n'
                ' out.write(json.dumps(dict(argv=sys.argv[1:],cwd=os.getcwd()))+"\\n")\n'
                'p=Path(os.environ["STARTS"])\np.open("a").write("start\\n")\nPath(os.environ["COMET_PID"]).write_text(str(os.getpid()))\n\n'
                'while not Path(os.environ["COMET_PID"]).with_name("release_comet").exists(): time.sleep(.05)')

    def starts(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def comets(self):
        path = self.root / "comets"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def signer_address(self, index):
        argv = self.signers()[index]["argv"]
        return argv[argv.index("--comet-signer-addr") + 1]

    def listener_args(self, index):
        """What the supervisor appends to pair `index`'s Comet argv: nothing over TCP."""
        return []

    def comet_listener(self, index):
        """Over TCP, Comet listens on its configured address."""
        return "tcp://127.0.0.1:26659"

    def restart_with(self, **changes):
        """Restart the supervisor with a changed environment; wait for its first pair."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        self.env.update(changes)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)

    def test_default_comet_argv(self):
        """Without ETNA_COMET_COMMAND_JSON, Comet runs `cometbft start --home <home>` in the home."""
        home = str(self.home.resolve())
        self.assertEqual(self.comets(), [dict(argv=["start", "--home", home] + self.listener_args(0), cwd=home)])

    def test_comet_command_json_is_the_complete_argv(self):
        """The supervisor adds no --home to an explicit Comet argv."""
        self.restart_with(ETNA_COMET_COMMAND_JSON=json.dumps([str(self.bin / "cometbft"), "custom", "argv"]))
        self.assertEqual(self.comets()[-1]["argv"], ["custom", "argv"] + self.listener_args(-1))

    def test_signer_address_override_is_gone(self):
        """ETNA_SIGNER_ADDR no longer exists: the signer dials Comet's own listener."""
        self.restart_with(ETNA_SIGNER_ADDR="tcp://127.0.0.1:1")
        self.assertEqual(self.signer_address(-1), self.comet_listener(-1))

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

    def test_supervisor_sigterm_retains_signer_failure_for_restart(self):
        """An unsafe signer exit, or a signer needing SIGKILL, during external shutdown must
        survive restartAlways; an ordinary exit 1 there is restarted like any crash."""
        latch = self.store / "validator-supervisor.halted"
        def stop_and_restart(starts):
            self.proc.terminate()
            self.assertEqual(self.proc.wait(timeout=10), 0)
            self.assertEqual((self.root / "lifecycle").read_text().splitlines()[-2:],
                             ["comet_reaped", "signer_stopped"])
            self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                         env=self.env, stdout=self.log, stderr=self.log)
            if starts is not None:
                self.wait(lambda: self.starts() == starts and len(self.signers()) == starts)
        stop_and_restart(2)
        self.assertFalse(latch.exists(), "healthy signal shutdown became terminal")
        (self.root / "signer_exit_on_term").write_text("1")
        stop_and_restart(3)
        self.assertFalse(latch.exists(), "an ordinary signer exit during shutdown became terminal")
        (self.root / "signer_exit_on_term").write_text("3")
        stop_and_restart(None)
        self.assertTrue(latch.exists(), "external supervisor shutdown discarded the unsafe signer exit")
        self.assertIn("unsafe signing state", latch.read_text())
        evidence = latch.read_bytes()
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 3, "restartAlways rearmed failed signing authority")
        self.assertEqual(len(self.signers()), 3)
        self.assertEqual(latch.read_bytes(), evidence)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.key.read_text(), "existing key")

    def test_supervisor_sigterm_latches_a_signer_it_must_kill(self):
        """A signer still running 5 s after the shutdown SIGTERM may be blocked on a failing state
        volume, past a failed fsync but before its fence (M1): the latch survives restartAlways."""
        (self.root / "signer_hang_on_term").touch()
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=15), 0)
        latch = self.store / "validator-supervisor.halted"
        self.assertTrue(latch.exists(), "a signer killed at shutdown was not latched")
        self.assertIn("did not stop", latch.read_text())
        self.assertEqual((self.root / "lifecycle").read_text().splitlines()[-2:],
                         ["comet_reaped", "signer_stopped"])
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

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

    def test_signer_exit_during_observation_restarts_signer(self):
        """A signer killed after tick's first poll is reaped by the recovery stop, then restarted.

        The kill is not the supervisor's, so the pair restarts with a fresh --await-trust signer;
        Comet waits for its session, and the HRS is untouched.
        """
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
                self.assertFalse((self.store / "validator-supervisor.halted").exists(),
                                 "an ordinary signer crash during observation latched")
                self.wait(lambda: len(self.signers()) == 3)
                self.assertIn("--await-trust", self.signers()[2]["argv"])
                self.assertEqual(self.signers()[2]["alive"], [])
                self.assertFalse(self.signers()[2]["comet_alive"])
                self.assertEqual(self.starts(), 2, "Comet started before the new session was Ready")
                self.assertEqual(self.state.read_text(), "authoritative HRS")
            finally:
                release.set()
                if worker is not None:
                    worker.join(timeout=5)
                runtime.stop()
                for descriptor in runtime.owner_fds:
                    os.close(descriptor)
                self.observation_hold = None

    def test_ready_is_phase_and_identity(self):
        """Readiness is the app's trust phase plus this chain_id (SYNC-9-15).

        The full chain_id binds the generation, so a recovered generation is Ready under its
        own chain_id like any other (RECOV-8.2-5).
        """
        spec = importlib.util.spec_from_file_location("etna_ready_phase", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runtime = object.__new__(module.Supervisor)
        runtime.chain = self.chain
        ready = dict(schema_version=1, session_id=self.session, chain_id=self.chain,
                     generation=self.generation, recovery_origin=self.origin, phase="ready",
                     target=None, committed_head=None, trusted_consensus_head=None, reason=None)
        self.assertTrue(runtime.ready(ready))
        for phase in ("acquiring", "catching_up", "halted", "Ready", "", None):
            self.assertFalse(runtime.ready(dict(ready, phase=phase)), phase)
        self.assertFalse(runtime.ready({key: value for key, value in ready.items() if key != "phase"}))
        self.assertFalse(runtime.ready(dict(ready, chain_id="other-chain")))
        self.assertFalse(runtime.ready({key: value for key, value in ready.items() if key != "chain_id"}))
        recovered = dict(ready, generation=3, recovery_origin=dict(generation=3, height=6))
        self.assertTrue(runtime.ready(recovered))

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

    def test_other_chain_observation_latches(self):
        """Another chain_id, such as another generation's, is a terminal identity mismatch.

        The latch survives a supervisor restart; the HRS is never touched.
        """
        configured = self.chain
        self.chain = "etna-other"
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists)
        self.assertEqual(latch.read_text(), "terminal deployment identity\n")
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.chain = configured
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.5)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_gets_state_path_and_domains_log(self):
        """The signer serves <ETNA_PRIV_STATE_DIR>/<chain_id>.json, checked against the log.

        The complete argv: no generation, deployment or enrollment option exists.
        """
        root = self.root.resolve()
        self.assertEqual(self.signers()[0]["argv"], [
            "--trust-socket", str(self.store.resolve() / "checkpoint-trust.sock"),
            "--chain-id", self.chain, "--priv-key", str(root / "key.json"),
            "--priv-state", str(root / "hrs" / (self.chain + ".json")),
            "--domains-log", str(root / "domains/domains.log"),
            "--comet-signer-addr", self.signer_address(0), "--denial-file", str(self.events.resolve())])

    def test_domains_log_inside_comet_home_or_app_store_is_refused(self):
        """Comet's UID never reaches signer storage, and the app store is disposable."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        for variable, inside in [("ETNA_DOMAINS_LOG", self.home / "domains.log"),
                                 ("ETNA_DOMAINS_LOG", self.store / "domains/domains.log"),
                                 ("ETNA_PRIV_STATE_DIR", self.home / "hrs"),
                                 ("ETNA_PRIV_STATE_DIR", self.store),
                                 ("ETNA_PRIV_KEY", self.home / "key.json")]:
            with self.subTest(variable=variable, path=inside):
                refused = subprocess.run(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                         env=dict(self.env, **{variable: str(inside)}), capture_output=True, timeout=5)
                self.assertNotEqual(refused.returncode, 0)
                self.assertIn(b"must be outside the Comet home and app store", refused.stderr)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.domains_log.read_text(), "etna-signer-domains-v1\n" + self.chain + "\n")

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

    def test_signer_exit_while_awaiting_trust_restarts(self):
        """A recovery signer that exits while awaiting trust is replaced by another fresh one."""
        self.publish(1, self.session)
        self.publish_recovery_session(ready=False)
        os.kill(self.signers()[1]["pid"], signal.SIGTERM)
        self.wait(lambda: len(self.signers()) == 3)
        self.assertIn("--await-trust", self.signers()[2]["argv"])
        self.assertEqual(self.signers()[2]["alive"], [])
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.starts(), 1)
        self.ready, self.phase, self.session = True, "ready", "third-session"
        self.publish(0, "third-session")
        self.wait(lambda: self.starts() == 2)
        self.assertEqual(len(self.signers()), 3)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_sigkill_restarts_pair_with_fresh_session(self):
        """A crashed signer restarts with its pair: Comet is reaped first, the new signer begins a
        new closed session, and Comet starts only once that session is Ready (SYNC-9-12/14). The
        HRS path is the same and its bytes are untouched (RECOV-8.2-1)."""
        os.kill(self.signers()[0]["pid"], signal.SIGKILL)
        self.wait(lambda: len(self.signers()) == 2)
        self.assertIn("--await-trust", self.signers()[1]["argv"])
        # No overlap: the dead signer was reaped and Comet stopped before the new signer ran.
        self.assertEqual(self.signers()[1]["alive"], [])
        self.assertFalse(self.signers()[1]["comet_alive"])
        self.assertEqual(self.signers()[1]["argv"][:10], self.signers()[0]["argv"][:10])
        time.sleep(.3)
        self.assertEqual(self.starts(), 1, "Comet restarted before the new session was Ready")
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        time.sleep(.3)
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertEqual(self.signer_address(1), self.comet_listener(1))
        if self.listener_args(1):  # Unix: the restarted pair never reuses the dead pair's socket
            self.assertNotEqual(self.comet_listener(0), self.comet_listener(1))
            self.assertFalse(os.path.lexists(self.comet_listener(0).removeprefix("unix://")))

    def assert_crash_restarts(self, code):
        (self.root / "signer_exit_now").write_text(str(code))
        self.wait(lambda: len(self.signers()) == 2)
        self.assertFalse((self.root / "signer_exit_now").exists())
        self.publish_recovery_session()
        self.wait(lambda: self.starts() == 2)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertIsNone(self.proc.poll())

    def test_signer_exit_one_restarts_pair(self):
        """A configuration, transport or lock error (exit 1) is a crash: restart."""
        self.assert_crash_restarts(1)

    def test_signer_exit_two_restarts_pair(self):
        """A Go panic (exit 2), such as a failed stock state write, released no signature: restart."""
        self.assert_crash_restarts(2)

    def test_signer_unsafe_exit_latches_without_restart(self):
        """Exit 3 is unsafe signing state (RECOV-8.2-3): latch, never restart (SYNC-9-14)."""
        (self.root / "signer_exit_on_start").write_text("3")
        os.kill(self.signers()[0]["pid"], signal.SIGKILL)
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists)
        self.assertIn("unsafe signing state", latch.read_text())
        time.sleep(.5)
        self.assertEqual(len(self.signers()), 2)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_retained_fence_latches_after_ordinary_exit(self):
        """A fence beside the HRS makes any signer exit unsafe: latch, never restart."""
        fence = self.state.with_name(self.state.name + ".uncertain")
        fence.write_text("fsync failed")
        os.kill(self.signers()[0]["pid"], signal.SIGKILL)
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists)
        self.assertIn("unsafe signing state", latch.read_text())
        time.sleep(.5)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(fence.read_text(), "fsync failed")
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_crash_loop_latches_after_limit(self):
        """Five non-unsafe exits within 600 s latch instead of restarting again (SYNC-9-14)."""
        (self.root / "signer_exit_on_start").write_text("1")
        os.kill(self.signers()[0]["pid"], signal.SIGKILL)
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists)
        self.assertTrue(latch.read_text().startswith("signer exited 5 times within 600s"), latch.read_text())
        time.sleep(.5)
        self.assertEqual(len(self.signers()), 5)  # the initial signer and four restarts
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_needing_sigkill_during_recovery_stop_latches(self):
        """A signer still running 5 s after the recovery stop's SIGTERM is SIGKILLed and latched,
        never restarted: it may be blocked on a failing state volume after a failed fsync and
        before its fence, and a restart on this boot could see that fsync error consumed (M1)."""
        (self.root / "signer_hang_on_term").touch()
        self.publish(1, self.session)
        latch = self.store / "validator-supervisor.halted"
        self.wait(latch.exists, timeout=15)
        self.assertIn("did not stop", latch.read_text())
        time.sleep(.5)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())
        self.assertFalse(any(signer for signer in self.signers() if self.alive(signer["pid"])))
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    @staticmethod
    def alive(pid):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        return True

    def test_half_a_comet_identity_is_refused_before_children(self):
        """ETNA_COMET_UID and ETNA_COMET_GID are set together or not at all, as for the full node."""
        for variable, value in (("ETNA_COMET_UID", os.geteuid()), ("ETNA_COMET_GID", os.getegid())):
            with self.subTest(variable=variable):
                env = {key: item for key, item in self.env.items() if key not in ("ETNA_COMET_UID", "ETNA_COMET_GID")}
                env[variable] = str(value)
                refused = subprocess.run(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                         env=env, capture_output=True, timeout=5)
                self.assertEqual(refused.returncode, 1, refused.stderr)
                self.assertIn(b"ETNA_COMET_UID and ETNA_COMET_GID must be set together", refused.stderr)
                self.assertNotIn(b"Traceback", refused.stderr)
        self.assertEqual(self.starts(), 1)
        self.assertEqual(len(self.signers()), 1)

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
    """Repeat lifecycle gates over Unix sockets; like stock Comet, the listener leaves its inode."""

    def configure_transport(self):
        (self.home / "run").mkdir(mode=0o700)
        # Only the scheme matters: the supervisor assigns every pair its own socket name.
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://run/signer.sock"\n')

    def comet_body(self):
        # Bind the assigned listener and never unlink it, as after an unclean stock exit.
        return ('import socket,sys\n'
                'address=sys.argv[sys.argv.index("--priv_validator_laddr")+1]\n'
                's=socket.socket(socket.AF_UNIX)\ns.bind(address.removeprefix("unix://"))\ns.listen()\n'
                + super().comet_body())

    def listener_args(self, index):
        """Unix mode appends only the pair's fresh listener, which its signer dials."""
        address = self.signer_address(index)
        self.assertRegex(address, "^unix://" + re.escape(str(self.home.resolve() / "run"))
                         + r"/signer-[0-9a-f]{16}\.sock$")
        return ["--priv_validator_laddr", address]

    def comet_listener(self, index):
        return self.comets()[index]["argv"][-1]

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

    def assert_misconfigured_run_refused(self, message):
        """Refuse before removing anything, so the first start reports the misconfiguration."""
        run = self.home / "run"
        before = {entry.name: entry.lstat().st_ino for entry in run.iterdir()}
        self.assertTrue(before, "the previous listener must remain as a stale entry")
        self.assert_refused()
        self.assertIn(message, Path(self.log.name).read_text(errors="replace"))
        self.assertEqual({entry.name: entry.lstat().st_ino for entry in run.iterdir()}, before)

    def test_sticky_run_directory_is_refused(self):
        # Without CAP_FOWNER a sticky run/ would block removing Comet's stale socket.
        self.stop_supervisor()
        (self.home / "run").chmod(0o1700)
        self.assert_misconfigured_run_refused(f"{self.home.resolve() / 'run'} must not be sticky")

    def test_run_directory_not_owned_by_comet_uid_is_refused(self):
        self.stop_supervisor()
        other = os.geteuid() + 1
        self.env = dict(self.env, ETNA_COMET_UID=str(other), ETNA_COMET_GID=str(os.getegid()))
        self.assert_misconfigured_run_refused(
            f"{self.home.resolve() / 'run'} must be owned by the Comet UID {other}, not {os.geteuid()}")

    def test_unremovable_prefixed_entry_is_refused(self):
        self.stop_supervisor()
        blocker = self.home / "run" / "signer-dddd.sock"
        blocker.mkdir()
        self.assert_refused()
        self.assertIn("signer-dddd.sock", Path(self.log.name).read_text(errors="replace"))
        self.assertTrue(blocker.is_dir())

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


@unittest.skipUnless(os.environ.get("ETNA_MIN_CAPS_TEST") == "1",
                     "needs Linux root holding only the documented capabilities; run just supervisor-caps-test")
class MinimalCapabilityTests(TrustPeer, unittest.TestCase):
    """Restart stock-like Comet under the documented supervisor capability set only."""

    COMET_UID = 10001

    def setUp(self):
        # An explicit request must never pass vacuously, for example as full root.
        if sys.platform != "linux" or os.geteuid() != 0:
            self.fail("ETNA_MIN_CAPS_TEST=1 needs Linux root holding only the documented capabilities")
        self.assertEqual(cap_eff(os.getpid()), DOCUMENTED_CAPS,
                         "ETNA_MIN_CAPS_TEST=1 needs exactly SETUID, SETGID, KILL and DAC_OVERRIDE")
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-caps-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.root.chmod(0o755)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        self.chain, self.generation, self.origin = "etna-test", 0, None
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
        self.key, self.state_dir = self.root / "key.json", self.root / "hrs"
        self.state, self.domains_log = self.state_dir / (self.chain + ".json"), self.root / "domains/domains.log"
        self.state_dir.mkdir()
        self.domains_log.parent.mkdir()
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.domains_log.write_text("etna-signer-domains-v1\n" + self.chain + "\n")
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
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE_DIR=str(self.state_dir),
                        ETNA_DOMAINS_LOG=str(self.domains_log),
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

    def served(self, phase):
        """The supervisor's latest observation carried this phase.

        A tick polls Comet before it observes, and ticks run one at a time, so the tick that
        received this answer finishes before any later tick can see a Comet exit.
        """
        return bool(self.observations) and self.observations[-1]["phase"] == phase

    def test_unclean_comet_exit_stale_socket_supervisor_restarts_pair(self):
        self.assertEqual(cap_eff(self.proc.pid), DOCUMENTED_CAPS)
        stale = self.wait_socket(1)
        self.assertEqual(stale.lstat().st_uid, self.COMET_UID)
        if Path("/proc/sys/fs/protected_hardlinks").read_text().strip() == "1":
            with self.assertRaises(PermissionError):  # the old inode pin needed CAP_FOWNER
                os.link(stale, self.root / "pin")
        self.wait(lambda: self.served("ready"))  # the loss below follows observed trust
        self.phase = "acquiring"
        self.wait(lambda: self.served("acquiring"))  # observed trust loss
        comet = self.comet_pid()
        os.kill(comet, signal.SIGKILL)  # stock leaves its socket inode
        # Every earlier tick still read the loss, so the tick that reaps Comet sees its exit
        # with the loss observed, whatever phase it then reads.
        self.wait(lambda: not Path(f"/proc/{comet}").exists())
        self.phase = "ready"
        self.publish_recovery_session()
        fresh = self.wait_socket(2)
        self.assertNotEqual(fresh, stale)
        self.assertFalse(os.path.lexists(stale))
        self.assertEqual(self.connected()[-1], str(fresh))
        self.assertFalse(self.latch.exists())
        self.assertIsNone(self.proc.poll())
        # CAP_KILL suffices to stop the UID-10001 Comet before the root signer.
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=20), 0, Path(self.log.name).read_text(errors="replace"))

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
        spec = importlib.util.spec_from_file_location("etna_launcher_paths", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_full_node_launcher_execs_stock_comet_on_an_imported_store(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            app, home = base / "ready/app", base / "ready/comet"
            app.mkdir(parents=True); (home / "config").mkdir(parents=True)
            floor = {"number": 6, "hash": "0x" + "ab" * 32}
            (app / "abci-state.json").write_text(json.dumps({"execution_floor": floor}))
            argv, stub = base / "argv", base / "cometbft"
            stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "$0" "$@" > "{argv}"\n')
            stub.chmod(0o700)
            env = dict(ETNA_APP_STORE=str(app), ETNA_COMET_HOME=str(home), ETNA_COMET_BIN=str(stub), PATH=os.defpath)
            launcher = [sys.executable, str(ROOT / "script/start_etna_full_node.py")]
            (home / "config/config.toml").write_text('priv_validator_laddr = ""\n')
            proc = subprocess.run(launcher, env=env, capture_output=True, timeout=30)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(argv.read_text().splitlines(), [str(stub), "start", "--home", str(home)])
            argv.unlink()
            (home / "config/config.toml").write_text('priv_validator_laddr = "tcp://127.0.0.1:26659"\n')
            proc = subprocess.run(launcher, env=env, capture_output=True, timeout=30)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn(b"full-node startup refuses validator configuration", proc.stderr)
            self.assertFalse(argv.exists())

    def load_launcher(self):
        spec = importlib.util.spec_from_file_location("etna_full_node_launcher", ROOT / "script/start_etna_full_node.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_full_node_launcher_keeps_privileged_group_drop_and_same_uid_native_path(self):
        module = self.load_launcher()
        pair = {"ETNA_COMET_UID": "10001", "ETNA_COMET_GID": "10001"}
        for current_uid, current_gid, env, expected in [
                (501, 20, {}, []),
                (501, 20, {"ETNA_COMET_UID": "501", "ETNA_COMET_GID": "20"}, []),
                (0, 0, pair, [("setgroups", []), ("setgid", 10001), ("setuid", 10001)]),
                # Half a configuration and a foreign identity without privilege fail closed.
                (0, 0, {"ETNA_COMET_UID": "10001"}, "ETNA_COMET_UID and ETNA_COMET_GID must be set together"),
                (0, 0, {"ETNA_COMET_GID": "10001"}, "ETNA_COMET_UID and ETNA_COMET_GID must be set together"),
                (501, 20, pair, "cannot assume its configured OS identity")]:
            calls = []
            with self.subTest(current_uid=current_uid, env=env), patch.dict(os.environ, env, clear=True), \
                    patch.object(module.os, "geteuid", return_value=current_uid), \
                    patch.object(module.os, "getegid", return_value=current_gid), \
                    patch.object(module.os, "setgroups", lambda groups: calls.append(("setgroups", groups))), \
                    patch.object(module.os, "setgid", lambda gid: calls.append(("setgid", gid))), \
                    patch.object(module.os, "setuid", lambda uid: calls.append(("setuid", uid))):
                if isinstance(expected, str):
                    with self.assertRaisesRegex(ValueError, expected):
                        module.assume_comet_identity(*module.comet_identity())
                    self.assertEqual(calls, [])
                else:
                    module.assume_comet_identity(*module.comet_identity())
                    self.assertEqual(calls, expected)

    def test_full_node_launcher_refuses_half_a_comet_identity_before_its_lease(self):
        with tempfile.TemporaryDirectory() as tmp:
            ready = Path(tmp).resolve() / "ready"
            (ready / "comet/config").mkdir(parents=True)
            (ready / "comet/config/config.toml").write_text('priv_validator_laddr = ""\n')
            env = dict(ETNA_COMET_HOME=str(ready / "comet"), ETNA_COMET_BIN="/usr/bin/true",
                       ETNA_COMET_UID=str(os.geteuid()), PATH=os.defpath)
            proc = subprocess.run([sys.executable, str(ROOT / "script/start_etna_full_node.py")],
                                  env=env, capture_output=True, timeout=30)
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertIn(b"ETNA_COMET_UID and ETNA_COMET_GID must be set together", proc.stderr)
            self.assertNotIn(b"Traceback", proc.stderr)
            self.assertFalse((ready / ".comet.etna-owner.lock").exists())

    @unittest.skipUnless(os.geteuid() == 0 and sys.platform.startswith("linux"), "needs root to switch to another UID")
    def test_full_node_launcher_reaches_a_traverse_only_home_as_the_comet_uid(self):
        uid = gid = 65534
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            os.chmod(base, 0o711)
            root, ready, home = base / "root", base / "root/ready", base / "root/ready/comet"
            (home / "config").mkdir(parents=True)
            (home / "config/config.toml").write_text('priv_validator_laddr = ""\n')
            for path in (home, home / "config", home / "config/config.toml"):
                os.chown(path, uid, gid)
            stub = base / "cometbft"
            stub.write_text('#!/bin/sh\nid -u > launched\n')
            stub.chmod(0o755)
            env = dict(ETNA_COMET_HOME=str(home), ETNA_COMET_BIN=str(stub), ETNA_COMET_UID=str(uid),
                       ETNA_COMET_GID=str(gid), PATH=os.defpath)
            launcher = [sys.executable, str(ROOT / "script/start_etna_full_node.py")]
            # A private import root keeps the Comet UID out; the published traverse-only one lets it in.
            for mode, reached in ((0o700, False), (0o711, True)):
                with self.subTest(mode=oct(mode)):
                    os.chmod(root, mode)
                    os.chmod(ready, mode)
                    proc = subprocess.run(launcher, env=env, capture_output=True, timeout=30)
                    self.assertEqual(proc.returncode == 0, reached, proc.stderr)
                    self.assertEqual((home / "launched").exists(), reached)
            self.assertEqual((home / "launched").read_text().strip(), str(uid))

    def test_denial_routes_preserve_keys_state_wal_and_uncertain_files(self):
        module = self.load_module()
        for case in ("key", "state", "other-chain-state", "fence", "domains-log", "default-key", "foreign", "live-wal"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp).resolve()
                store, home, hrs, domains = base / "app", base / "home", base / "hrs", base / "domains"
                store.mkdir(); (home / "config").mkdir(parents=True); hrs.mkdir(); domains.mkdir()
                (home / "config/config.toml").write_text('priv_validator_laddr="tcp://127.0.0.1:12345"')
                (home / "config/genesis.json").write_text('{"chain_id":"test"}')
                default = store / "signer-denial.json"
                key = default if case == "default-key" else base / "key"
                state, log = hrs / "test.json", domains / "domains.log"
                wal = (home if case == "live-wal" else base / "older") / "data/cs.wal/wal"
                wal.parent.mkdir(parents=True);wal.write_bytes(b"old wal");key.write_bytes(b"registered key");state.write_bytes(b"authoritative HRS")
                log.write_bytes(b"etna-signer-domains-v1\ntest\n"); (hrs / "other.json").write_bytes(b"other HRS")
                env = dict(ETNA_APP_STORE=str(store), ETNA_COMET_HOME=str(home),ETNA_PRIV_KEY=str(key),
                           ETNA_PRIV_STATE_DIR=str(hrs), ETNA_DOMAINS_LOG=str(log), ETNA_CHAIN_ID="test", ETNA_SIGNER_BIN="/usr/bin/true")
                routes = {"key": key, "state": state, "other-chain-state": hrs / "other.json",
                          "fence": hrs / "test.json.uncertain", "domains-log": log, "live-wal": wal}
                if case in routes:
                    env["ETNA_DENIAL_FILE"] = str(routes[case])
                if case == "foreign": default.write_bytes(b"foreign preserved bytes")
                saved = {p: p.read_bytes() for p in (key,state,log,hrs / "other.json",wal,default) if p.exists()}
                with patch.dict(os.environ,env,clear=True), patch.object(module.subprocess,"Popen") as spawn:
                    with self.assertRaises(ValueError): module.Supervisor().start()
                    spawn.assert_not_called()
                for p, expected in saved.items(): self.assertEqual(p.read_bytes(),expected)
                self.assertFalse((hrs / "test.json.uncertain").exists())


class SupervisorUnitTests(unittest.TestCase):
    def supersession_with_children(self, directory, signer_status):
        """Create a superseded app store and real children with controlled exit status."""
        spec = importlib.util.spec_from_file_location("etna_supersession_stop", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        store = Path(directory)
        runtime = object.__new__(module.Supervisor)
        runtime.store, runtime.chain = store, "old-chain"
        runtime.state = store / "hrs.json"
        runtime.latch = store / "validator-supervisor.halted"
        preserved = {"abci-state.json": json.dumps(dict(chain_id="old-chain", generation=0)).encode(),
                     "fatal-evidence.txt": b"authenticated higher recovery generation",
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

    def test_superseded_halt_writes_generic_latch_and_preserves_store(self):
        """A halted app, e.g. a superseded generation (RECOV-8-16), gets only the generic latch.

        The latch is durable before Comet and then the signer are stopped, and every byte of the
        old store stays as it was; `abci-recover install` never reuses that store.
        """
        with tempfile.TemporaryDirectory() as directory:
            runtime, preserved = self.supersession_with_children(directory, 0)
            runtime.events, runtime.prior_observation = runtime.store / "absent-denial.json", None
            runtime.observe = lambda: dict(
                schema_version=1, session_id="old-session", phase="halted", chain_id="old-chain",
                generation=0, reason="recovery generation 0 superseded by 1", recovery_origin=None)
            runtime.tick()
            reason = b"terminal app trust or deployment identity\n"
            self.assertEqual(runtime.latch.read_bytes(), reason)
            for name in ("comet", "signer"):
                self.assertEqual((runtime.store / (name + ".halt")).read_bytes(), reason,
                                 f"{name} was stopped before the latch was durable")
            self.assertIsNone(runtime.comet)
            self.assertIsNone(runtime.signer)
            for name, raw in preserved.items():
                self.assertEqual((runtime.store / name).read_bytes(), raw)

    def test_existing_latch_cannot_hide_unsafe_signer_exit_during_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime, preserved = self.supersession_with_children(directory, 3)
            original = b"original generic safety halt\n"
            runtime.latch.write_bytes(original)
            runtime.tick()
            self.assertEqual(runtime.latch.read_bytes(), original)
            self.assertTrue(runtime.halted)
            for name, raw in preserved.items():
                self.assertEqual((runtime.store / name).read_bytes(), raw)

    def test_comet_identity_keeps_privileged_group_drop_and_same_uid_native_path(self):
        spec = importlib.util.spec_from_file_location("etna_identity_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runtime = object.__new__(module.Supervisor)
        runtime.home, runtime.unix_run = Path("/private/runtime"), None
        runtime.comet_command = ["/cometbft", "start"]
        runtime.child_options = lambda: {}
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


if __name__ == "__main__":
    unittest.main()
