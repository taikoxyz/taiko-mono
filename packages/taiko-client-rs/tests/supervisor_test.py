"""Real child-process supervision with a controlled private trust peer."""
import base64
import contextlib
import importlib.util
import fcntl
import io
import json
import os
from pathlib import Path
import re
import shutil
import socket
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
# A validator's listed-peer P2P configuration (START-10-6): no peer exchange, no inbound slot and,
# with no ETNA_P2P_INBOUND_PEER_IDS, no unconditional peer.
VALIDATOR_P2P = "[p2p]\npex = false\nmax_num_inbound_peers = 0\n"
# One stock Ed25519 node key and its libp2p peer ID, as the signer's Go tests pin them
# (TestTransportPeerIDVector).
PEER_ID_VECTOR = ('{"priv_key":{"type":"tendermint/PrivKeyEd25519","value":"nZGcTgiuNXtFuZUZGISAcSje3hVT+bGhna2LmuPCFRKyPL6KLy400isFcvbvDSQ5ljD7QR05nMHahbB+NhZltA=="}}',
                  "12D3KooWMp8TizWt75VicSKSACXjXQ8pByDngq47VN51SMPF5mfh")


def supervisor_module(name="etna_validator_under_test"):
    spec = importlib.util.spec_from_file_location(name, ROOT / "script/etna_validator.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_manifest(path, executable, floor="1s"):
    """A deployment manifest that pins executable for this host's platform, as the shipped one
    pins the official linux/amd64 executable, and the validators' timeout_commit floor `floor`:
    by default stock Comet's 1 s, which a config.toml without timeout_commit meets."""
    module = supervisor_module("etna_manifest_writer")
    path.write_text(json.dumps(dict(schema=2, engine="cometbft", release="v0.40.0",
                                    source_commit="0880b4d378f347ab16e54ec677ff50d803f37d62",
                                    platforms={module.comet_platform(): dict(sha256=module.sha256_file(executable))},
                                    configuration={"consensus.timeout_commit": dict(min=floor)})))


def write_node_key(path):
    """A fresh stock Ed25519 node-key file; returns its libp2p peer ID."""
    raw = base64.b64encode(os.urandom(64)).decode()
    path.write_text(json.dumps(dict(priv_key=dict(type="tendermint/PrivKeyEd25519", value=raw))))
    path.chmod(0o600)
    return supervisor_module("etna_peer_id").ed25519_peer_id(path, "test key")


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
                response = dict(schema_version=2, session_id=self.session, chain_id=self.chain,
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

    def wait(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while not predicate() and time.monotonic() < deadline:
            time.sleep(.05)
        if not predicate():
            # A separate reader leaves the child's shared stdout offset untouched.
            runtime = Path(self.log.name).read_text(errors="replace")
            self.fail("supervisor did not perform the expected lifecycle transition; "
                      f"supervisor exit status: {self.proc.poll()}\nruntime.log:\n{runtime}")


class SupervisorLifecycle(TrustPeer):
    """Lifecycle gates every signer transport repeats; UnixSupervisorTests and
    NoiseSupervisorTests supply the transport."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-supervisor-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        self.transport_env = {}
        self.configure_transport()
        self.base_config = (self.home / "config/config.toml").read_text()
        (self.home / "config/config.toml").write_text(self.base_config + VALIDATOR_P2P)
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
        # The supervisor's signer-unsafe marker beside the log, which the signer refuses.
        self.marker = self.domains_log.parent / (self.chain + ".signer-unsafe")
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
            # signer_hang_on_term makes it ignore the supervisor's SIGTERM. Like the real signer
            # each start first publishes its connection (sequence 0, an empty session), unless
            # signer_skip_connect exists, and then records which earlier signers and which Comet
            # were still alive.
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
                       'if not (root/"signer_skip_connect").exists():\n'
                       ' events=Path(sys.argv[sys.argv.index("--denial-file")+1])\n'
                       ' t=events.with_name(".signer-observation-%d"%os.getpid())\n'
                       ' d=os.open(t,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)\n'
                       ' os.write(d,json.dumps(dict(sequence=0,session_id="")).encode());os.close(d);os.replace(t,events)\n'
                       'signers=Path(os.environ["SIGNERS"])\n'
                       'earlier=[json.loads(line)["pid"] for line in signers.read_text().splitlines()] if signers.exists() else []\n'
                       'comet=Path(os.environ["COMET_PID"])\n'
                       'seen=int(comet.read_text()) if comet.exists() else None\n'
                       'record=dict(pid=os.getpid(),argv=sys.argv[1:],alive=[pid for pid in earlier if alive(pid)],\n'
                       ' comet_seen=[seen,seen is not None and alive(seen)])\n'
                       'signers.open("a").write(json.dumps(record)+"\\n")\n'
                       'if code("signer_exit_on_start") is not None: sys.exit(code("signer_exit_on_start"))\n'
                       'def query():\n'
                       ' import socket\n'
                       ' with socket.socket(socket.AF_UNIX) as c:\n'
                       '  c.connect(sys.argv[sys.argv.index("--supervisor-socket")+1])\n'
                       '  body=(root/"signer_query").read_text().strip() or "comet"\n'
                       '  request=dict(schema=1,id=1,**(json.loads(body) if body.startswith("{") else dict(op=body)))\n'
                       '  c.sendall(json.dumps(request).encode()+b"\\n")\n'
                       '  return c.makefile("rb").readline()\n'
                       'while not Path(os.environ["COMET_PID"]).with_name("release_signer").exists():\n'
                       ' now=code("signer_exit_now")\n'
                       ' if now is not None: (root/"signer_exit_now").unlink(); sys.exit(now)\n'
                       ' if (root/"signer_query").exists() and not (root/"signer_reply").exists():\n'
                       '  reply=query()\n'
                       '  if json.loads(reply).get("comet", True) is not None: (root/"signer_reply").write_bytes(reply)\n'
                       ' time.sleep(.05)'),
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.manifest = self.root / "comet-manifest.json"
        write_manifest(self.manifest, self.bin / "cometbft")
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE_DIR=str(self.state_dir),
                        ETNA_DOMAINS_LOG=str(self.domains_log),
                        ETNA_CHAIN_ID=self.chain, ETNA_SIGNER_BIN=str(self.bin / "signer"),
                        ETNA_DENIAL_FILE=str(self.events), STARTS=str(self.count), COMET_PID=str(self.root / "comet.pid"),
                        SIGNERS=str(self.root / "signers"), ETNA_COMET_MANIFEST=str(self.manifest),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        for name in [name for name in self.env if name.startswith(("CMT", "TMHOME", "ETNA_P2P_"))]:
            del self.env[name]
        self.env.update(self.identity_env)
        self.env.update(self.transport_env)
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

    def comet_body(self):
        # Record the argv and working directory each Comet start receives. The pid file is
        # replaced atomically: a signer started with this Comet reads it concurrently. With the
        # control file comet_exit_on_start, Comet exits at once, as on a missed first connection.
        return ('from pathlib import Path\nimport json,os,sys,time\n'
                'with Path(os.environ["COMET_PID"]).with_name("comets").open("a") as out:\n'
                ' out.write(json.dumps(dict(argv=sys.argv[1:],cwd=os.getcwd(),pid=os.getpid(),script=sys.argv[0]))+"\\n")\n'
                'p=Path(os.environ["STARTS"])\np.open("a").write("start\\n")\n'
                'if Path(os.environ["COMET_PID"]).with_name("comet_exit_on_start").exists(): sys.exit(1)\n'
                'c=Path(os.environ["COMET_PID"]);t=c.with_name(".comet.pid.%d"%os.getpid())\n'
                't.write_text(str(os.getpid()));os.replace(t,c)\n\n'
                'printed=0\n'
                'while not Path(os.environ["COMET_PID"]).with_name("release_comet").exists():\n'
                ' r=Path(os.environ["COMET_PID"]).with_name("comet_records")\n'
                ' lines=r.read_text().splitlines() if r.exists() else []\n'
                ' for line in lines[printed:]: print(line, flush=True)\n'
                ' printed=len(lines)\n'
                ' time.sleep(.05)')

    def starts(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def saw_earlier_comet_alive(self, index):
        """Whether signer `index` started while an earlier pair's Comet was still alive. The pair
        starts together, so the Comet it saw may already be its own, the latest one."""
        seen, alive = self.signers()[index]["comet_seen"]
        return alive and seen != self.comets()[-1]["pid"]

    def comets(self):
        path = self.root / "comets"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def signer_address(self, index):
        argv = self.signers()[index]["argv"]
        return argv[argv.index("--comet-signer-addr") + 1]

    def listener_args(self, index):
        """What the supervisor appends to pair `index`'s Comet argv: its signer listener."""
        return ["--priv_validator_laddr", self.comet_listener(index)]

    def transport_args(self, index):
        """The signer argv the transport adds after --comet-signer-addr's value."""
        return []

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
        self.assertEqual([dict(argv=comet["argv"], cwd=comet["cwd"]) for comet in self.comets()],
                         [dict(argv=["start", "--home", home] + self.listener_args(0), cwd=home)])

    def test_comet_command_json_is_the_complete_argv(self):
        """The supervisor adds no --home to an explicit Comet argv."""
        self.restart_with(ETNA_COMET_COMMAND_JSON=json.dumps([str(self.bin / "cometbft"), "custom", "argv"]))
        self.assertEqual(self.comets()[-1]["argv"], ["custom", "argv"] + self.listener_args(-1))

    def test_signer_address_override_is_gone(self):
        """ETNA_SIGNER_ADDR no longer exists: the signer dials Comet's own listener."""
        self.restart_with(ETNA_SIGNER_ADDR="tcp://127.0.0.1:1")
        if self.fresh_listener_per_pair:
            self.assertEqual(self.signer_address(-1), self.comet_listener(-1))
        else:
            self.signer_address(-1)  # Noise: Comet's own listener, pinning its node key

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
        self.assertIn("did not stop", (self.store / "validator-supervisor.signer-unsafe").read_text())
        self.assertIn("etna_supervisor_signer_killed", Path(self.log.name).read_text(errors="replace"))
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
        self.wait(lambda: self.starts() == 2)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertTrue(self.ops)
        self.assertEqual(set(self.ops), {"observe"})

    def test_signer_exit_during_observation_restarts_signer(self):
        """A signer killed after tick's first poll is reaped by the recovery stop, then restarted.

        The kill is not the supervisor's, so the pair restarts with a fresh signer and Comet
        together, after both old children were reaped, and the HRS is untouched.
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
                self.wait(lambda: len(self.signers()) == 3 and self.starts() == 3)
                self.assertNotIn("--await-trust", self.signers()[2]["argv"])
                self.assertEqual(self.signers()[2]["alive"], [])
                self.assertFalse(self.saw_earlier_comet_alive(2))
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
        ready = dict(schema_version=2, session_id=self.session, chain_id=self.chain,
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
            "--supervisor-socket", str(self.store.resolve() / "supervisor/signer.sock"),
            "--chain-id", self.chain, "--priv-key", str(root / "key.json"),
            "--priv-state", str(root / "hrs" / (self.chain + ".json")),
            "--domains-log", str(root / "domains/domains.log"),
            "--comet-signer-addr", self.signer_address(0), "--denial-file", str(self.events.resolve()),
            *self.transport_args(0)])

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

    def test_session_change_alone_does_not_restart(self):
        """An app restart gives the app a new session; the signer begins one for its next
        signing request and holds it there, so only a published refusal restarts Comet."""
        self.session = "app-restarted:0"
        time.sleep(.6)
        self.assertEqual((self.starts(), len(self.signers())), (1, 1))

    def test_another_refusal_repeats_the_guarded_restart(self):
        """The restarted pair's replayed step can be refused again; once trust is Ready the
        supervisor restarts the pair again (SYNC-9-12), with the HRS untouched."""
        self.ready, self.phase = False, "acquiring"
        self.publish(1, self.session)
        time.sleep(.4)
        self.assertEqual(self.starts(), 1)
        self.ready, self.phase = True, "ready"
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.publish(1, "second-pair-session")
        self.wait(lambda: self.starts() == 3 and len(self.signers()) == 3)
        time.sleep(.4)
        self.assertEqual((self.starts(), len(self.signers())), (3, 3))
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
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

    def test_refusal_restarts_the_pair_together_once_ready(self):
        """The refused step comes back only through a restarted Comet's WAL replay. Once trust
        is Ready, both old children are reaped and the signer and Comet start together; the
        signer connects promptly and holds the replayed step for its new session (SYNC-9-12)."""
        self.ready, self.phase = False, "acquiring"
        self.publish(1, self.session)
        time.sleep(.6)
        self.assertEqual((self.starts(), len(self.signers())), (1, 1))
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.ready, self.phase = True, "ready"
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.assertNotIn("--await-trust", self.signers()[1]["argv"])
        self.assertEqual(self.signers()[1]["alive"], [])
        self.assertFalse(self.saw_earlier_comet_alive(1))
        time.sleep(.6)
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_signer_sigkill_restarts_pair_with_fresh_session(self):
        """A crashed signer restarts with its pair: Comet is reaped first, then the new signer
        and Comet start together on a fresh transport, where the signer begins a new closed
        session (SYNC-9-12/14). The HRS path is the same and its bytes are untouched
        (RECOV-8.2-1)."""
        os.kill(self.signers()[0]["pid"], signal.SIGKILL)
        self.wait(lambda: len(self.signers()) == 2 and self.starts() == 2)
        self.assertNotIn("--await-trust", self.signers()[1]["argv"])
        # No overlap: the dead signer was reaped and Comet stopped before the new signer ran.
        self.assertEqual(self.signers()[1]["alive"], [])
        self.assertFalse(self.saw_earlier_comet_alive(1))
        self.assertEqual(self.signers()[1]["argv"][:10], self.signers()[0]["argv"][:10])
        time.sleep(.3)
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        if self.fresh_listener_per_pair:  # Unix: the restarted pair never reuses the dead pair's socket
            self.assertEqual(self.signer_address(1), self.comet_listener(1))
            self.assertNotEqual(self.comet_listener(0), self.comet_listener(1))
            self.assertFalse(os.path.lexists(self.comet_listener(0).removeprefix("unix://")))

    def assert_crash_restarts(self, code):
        (self.root / "signer_exit_now").write_text(str(code))
        self.wait(lambda: len(self.signers()) == 2 and self.starts() == 2)
        self.assertFalse((self.root / "signer_exit_now").exists())
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
        self.assertIn("unsafe signing state", self.marker.read_text())
        time.sleep(.5)
        # The restart started the pair together; the second signer's exit 3 stopped its Comet.
        self.assertEqual((len(self.signers()), self.starts()), (2, 2))
        self.assertFalse(self.alive(int((self.root / "comet.pid").read_text())))
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
        self.assertIn("unsafe signing state", self.marker.read_text())
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
        # The initial pair and four restarted pairs.
        self.assertEqual((len(self.signers()), self.starts()), (5, 5))
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
        self.assertIn("did not stop", (self.store / "validator-supervisor.signer-unsafe").read_text())
        time.sleep(.5)
        self.assertEqual(len(self.signers()), 1)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())
        self.assertFalse(any(signer for signer in self.signers() if self.alive(signer["pid"])))
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_kill_record_is_durable_before_the_sigkill_and_survives_supervisor_death(self):
        """A signer blocked in a failed fsync or its fence write on a failing volume is in D-state:
        SIGKILL cannot reap it until that I/O returns, and the supervisor may itself be killed
        during that wait (the kubelet's grace period). So the kill is recorded durably, apart from
        any first-cause latch, in the app store and beside the domains log, before the SIGKILL is
        sent (RECOV-8.2-3). D-state cannot be produced portably, so the signer's reap after SIGKILL
        never returns here: the supervisor dies in it."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=10), 0)
        spec = importlib.util.spec_from_file_location("etna_kill_record", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        latch, record = self.store / "validator-supervisor.halted", self.store / "validator-supervisor.signer-unsafe"
        marker = self.marker
        events = []

        class SupervisorKilled(BaseException):
            pass

        class Unreapable:
            """The real signer process, except that the wait after SIGKILL never returns."""
            def __init__(self, child):
                self.child = child

            def __getattr__(self, name):
                return getattr(self.child, name)

            def kill(self):
                events.append(("kill", record.read_text() if record.exists() else None,
                               marker.read_text() if marker.exists() else None))
                self.child.kill()

            def wait(self, timeout=None):
                if timeout is not None:
                    return self.child.wait(timeout=timeout)
                events.append(("wait", record.exists()))
                raise SupervisorKilled()

        (self.root / "signer_hang_on_term").touch()
        output = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True):
            runtime = module.Supervisor()
            runtime.acquire_owner()
            real = None
            try:
                runtime.start()
                self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
                real = runtime.signer
                runtime.signer = Unreapable(real)
                with contextlib.redirect_stdout(output), self.assertRaises(SupervisorKilled):
                    runtime.stop()
            finally:
                if real is not None:
                    real.kill()
                    real.wait(timeout=5)
                for descriptor in runtime.owner_fds:
                    os.close(descriptor)
        self.assertEqual(len(events), 2, events)
        self.assertEqual(events[0][0], "kill")
        self.assertIn("did not stop", events[0][1] or "", "the kill was sent before its record existed")
        self.assertIn("did not stop", events[0][2] or "", "the kill was sent before its marker existed")
        self.assertEqual(events[1], ("wait", True))
        self.assertIn("etna_supervisor_signer_killed", output.getvalue())
        self.assertIn("recording before SIGKILL", output.getvalue())
        self.assertIn("etna_supervisor_signer_kill_recorded", output.getvalue())
        self.assertFalse(latch.exists(), "the supervisor died before any latch")
        # The next supervisor refuses to start the signer over that state.
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(latch.exists)
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertIn("signer-unsafe record", latch.read_text())
        self.assertIn("did not stop", record.read_text())
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_kill_inside_halt_is_recorded_beside_the_first_cause(self):
        """A signer that must be killed while halting for another cause leaves its kill record
        beside that first cause, so repairing only the first cause never restarts it."""
        (self.root / "signer_hang_on_term").touch()
        self.phase = "halted"
        latch, record = self.store / "validator-supervisor.halted", self.store / "validator-supervisor.signer-unsafe"
        self.wait(record.exists, timeout=15)
        self.wait(lambda: "etna_supervisor_halted" in Path(self.log.name).read_text(errors="replace"), timeout=15)
        self.assertEqual(latch.read_text(), "terminal app trust or deployment identity\n")
        self.assertIn("did not stop", record.read_text())
        self.assertIn("etna_supervisor_signer_killed", Path(self.log.name).read_text(errors="replace"))
        # The operator repairs only the app cause.
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=10), 0)
        latch.unlink()
        self.phase = "ready"
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(latch.exists)
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertIn("signer-unsafe record", latch.read_text())
        self.assertEqual((self.starts(), len(self.signers())), (1, 1))
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_fresh_app_store_with_the_same_domains_log_refuses(self):
        """A signer the supervisor had to kill may have been stuck after a failed fsync and before
        its fence, so the app-store record is not the only evidence: the marker beside the domains
        log survives a fresh app store, as after a re-import, and a supervisor for the same
        chain_id refuses it there (RECOV-8.2-3, ACCEPTANCE §7.7). The signer refuses it too
        (TestServeRefusalMatrix)."""
        (self.root / "signer_hang_on_term").touch()
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=15), 0)
        self.assertIn("did not stop", self.marker.read_text())
        fresh = self.root / "fresh-app"
        fresh.mkdir()
        self.env["ETNA_APP_STORE"] = str(fresh)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        latch = fresh / "validator-supervisor.halted"
        self.wait(latch.exists)
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertIn("signer-unsafe record or marker", latch.read_text())
        self.assertTrue((fresh / "validator-supervisor.signer-unsafe").exists())
        self.assertEqual((self.starts(), len(self.signers())), (1, 1))
        self.assertIn("did not stop", self.marker.read_text())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_unwritable_marker_holds_back_the_sigkill(self):
        """The app-store record and the marker beside the domains log persist in one loop: while
        the marker cannot be written, the signer is never SIGKILLed although the record already
        exists, and the SIGKILL follows only once both are durable (RECOV-8.2-3, SYNC-9-13)."""
        if os.geteuid() == 0:
            self.skipTest("root bypasses directory-write permission faults")
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=10), 0)
        spec = importlib.util.spec_from_file_location("etna_marker_loop", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        record, marker, domains = self.store / "validator-supervisor.signer-unsafe", self.marker, self.domains_log.parent
        kills = []

        class Watched:
            """The real signer process, noting whether the marker existed at its SIGKILL."""
            def __init__(self, child):
                self.child = child

            def __getattr__(self, name):
                return getattr(self.child, name)

            def kill(self):
                kills.append(marker.exists())
                self.child.kill()

        (self.root / "signer_hang_on_term").touch()
        output = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True):
            runtime = module.Supervisor()
            runtime.acquire_owner()
            real = stopper = None
            try:
                runtime.start()
                self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
                real = runtime.signer
                runtime.signer = Watched(real)
                domains.chmod(0o500)
                with contextlib.redirect_stdout(output):
                    stopper = threading.Thread(target=runtime.stop)
                    stopper.start()
                    self.wait(record.exists, timeout=15)
                    time.sleep(1)
                    self.assertEqual(kills, [], "SIGKILL sent while the marker could not be written")
                    self.assertTrue(self.alive(real.pid))
                    self.assertFalse(marker.exists())
                    domains.chmod(0o700)
                    stopper.join(timeout=10)
                    self.assertFalse(stopper.is_alive())
            finally:
                domains.chmod(0o700)
                if real is not None and real.poll() is None:
                    real.kill()
                    real.wait(timeout=5)
                if stopper is not None:
                    stopper.join(timeout=10)
                for descriptor in runtime.owner_fds:
                    os.close(descriptor)
        self.assertEqual(kills, [True])
        self.assertIn("did not stop", marker.read_text())
        self.assertIn("etna_supervisor_halt_persistence_pending", output.getvalue())
        self.assertIn("etna_supervisor_signer_kill_recorded", output.getvalue())

    @staticmethod
    def alive(pid):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        return True

    def store_instance(self):
        return (self.home / "data/etna-store-instance").read_text()

    def channel_reply(self, op="comet"):
        """The signer's query over the supervisor channel, as the running fake signer makes it
        once asked to."""
        (self.root / "signer_reply").unlink(missing_ok=True)
        (self.root / "signer_query").write_text(op)
        self.wait(lambda: (self.root / "signer_reply").exists())
        (self.root / "signer_query").unlink()
        return json.loads((self.root / "signer_reply").read_text())

    def test_store_instance_is_assigned_once_and_reported_to_the_signer(self):
        """A home without a store instance ID gets a fresh one before Comet starts, durably and
        privately; the signer channel reports, to the signer, the Comet process the supervisor
        runs (PID and kernel start time) and that ID; a restart keeps the ID (RECOV-8.2-2)."""
        instance = self.store_instance()
        self.assertRegex(instance, r"^[0-9a-f]{32}\n$")
        self.assertEqual(stat.S_IMODE((self.home / "data/etna-store-instance").stat().st_mode), 0o600)
        self.assertIn(f"etna_supervisor_store_instance_assigned: {instance.strip()}", Path(self.log.name).read_text())
        comet = self.comets()[-1]["pid"]
        start = Path(f"/proc/{comet}/stat").read_bytes().rsplit(b")", 1)[1].split()[19].decode()
        self.assertEqual(self.channel_reply(), dict(schema=1, id=1, comet=dict(pid=comet, start=start, store_instance=instance.strip(), replay=None)))
        self.restart_with()
        self.assertEqual(self.store_instance(), instance)
        self.assertEqual(self.channel_reply()["comet"]["pid"], self.comets()[-1]["pid"])
        self.assertEqual(Path(self.log.name).read_text().count("etna_supervisor_store_instance_assigned"), 1)

    def test_stores_without_an_instance_id_get_a_fresh_one(self):
        """Stores whose ID file is gone are treated as rebuilt: the next start assigns a fresh ID,
        so the signer's binding changes and it fences its last signed height (RECOV-8.2-2)."""
        before = self.store_instance()
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        (self.home / "data/blockstore.db").mkdir()
        (self.home / "data/etna-store-instance").unlink()
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.assertNotEqual(self.store_instance(), before)
        self.assertEqual(self.channel_reply()["comet"]["store_instance"], self.store_instance().strip())

    def test_channel_refuses_every_peer_but_the_signer(self):
        """Only the signer the supervisor started may use the channel: another process of the same
        user is refused by its peer credentials and gets no answer."""
        with socket.socket(socket.AF_UNIX) as peer:
            peer.settimeout(3)
            peer.connect(str(self.store / "supervisor/signer.sock"))
            peer.sendall(b'{"schema":1,"id":1,"op":"comet"}\n')
            try:
                answer = peer.recv(1024)
            except ConnectionResetError:
                answer = b""
            self.assertEqual(answer, b"")
        self.wait(lambda: "etna_supervisor_channel_refused" in Path(self.log.name).read_text())
        self.assertEqual(stat.S_IMODE((self.store / "supervisor").stat().st_mode), 0o700)

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


class UnixSupervisorTests(SupervisorLifecycle, unittest.TestCase):
    """Lifecycle gates over Unix sockets; like stock Comet, the listener leaves its inode."""

    fresh_listener_per_pair = True

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
        (self.home / "config/config.toml").write_text(f'priv_validator_laddr = "unix://{elsewhere / "x.sock"}"\n' + VALIDATOR_P2P)
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

    def test_log_observer_follows_comet_through_its_own_pipe(self):
        """With the stock JSON log format and the consensus module at Info, the supervisor owns a
        fresh pipe for each Comet process's stdout: it forwards every line and follows the replay
        attempts it announces, which the signer's observe op reports after consuming every record
        already written (RECOV-8.2-2). Without them the observer is off for that start, reported,
        and the channel reports no replay."""
        self.assertIn("etna_supervisor_log_observer_disabled: log_format is ['plain']", Path(self.log.name).read_text())
        self.assertIsNone(self.channel_reply()["comet"]["replay"])
        self.assertIn("is unavailable", self.channel_reply("observe")["error"])
        records = self.root / "comet_records"
        records.write_text("\n".join(json.dumps(record) for record in [
            dict(level="info", module="consensus", _msg="Catchup by replaying consensus messages", height=7),
            dict(level="info", module="p2p", _msg="Replay: Done"),
        ]) + "\n")
        self.restart_over_settings('log_format = "json"\nlog_level = "consensus:info,*:error"')
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        # The first Comet, writing to the supervisor's own stdout, may have printed the same
        # records: wait for the observer itself, not for the log.
        self.wait(lambda: self.channel_reply("observe")["replay"]["attempt"] == 1)
        self.assertEqual(self.channel_reply("observe")["replay"],
                         dict(attempt=1, open=True, height=7, tainted=False, repaired=False))
        with records.open("a") as out:
            out.write(json.dumps(dict(level="info", module="consensus", _msg="Replay: Done")) + "\n")
        self.wait(lambda: self.channel_reply("observe")["replay"]["open"] is False)
        self.assertIn('{"level": "info", "module": "consensus", "_msg": "Replay: Done"}', Path(self.log.name).read_text())
        self.assertEqual(Path(self.log.name).read_text().count("etna_supervisor_log_observer_disabled"), 1)

    def test_log_observer_prerequisites_are_checked_at_every_comet_start(self):
        """START-10-6: the observer's prerequisites are checked again at every Comet start. A
        config.toml that leaves the JSON format while the pair runs turns the observer off for
        the next start: the supervisor reports the failed setting, gives that Comet no pipe and
        the channel reports no replay, so observer-dependent signing stays closed (RECOV-8.2-2)."""
        self.restart_over_settings('log_format = "json"')
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.wait(lambda: "replay" in self.channel_reply("observe"))
        log = lambda: Path(self.log.name).read_text(errors="replace")
        reported = log().count("etna_supervisor_log_observer_disabled")
        (self.home / "config/config.toml").write_text(self.base_config + 'log_format = "plain"\n' + VALIDATOR_P2P)
        self.publish(1, self.session)
        self.wait(lambda: self.starts() == 3 and len(self.signers()) == 3)
        self.wait(lambda: log().count("etna_supervisor_log_observer_disabled: log_format is ['plain']") == reported + 1)
        self.assertIsNone(self.channel_reply()["comet"]["replay"])
        self.assertIn("is unavailable", self.channel_reply("observe")["error"])

    def test_torn_wal_tail_restarts_the_pair_after_the_stock_repair(self):
        """RECOV-8.2-2 vector 2.l: when the startup check finds a torn tail after all bound input,
        the channel reports the replay as needing a repair (the signer keeps that height closed
        without a floor); once Comet's records show the stock repair and trust is Ready, the
        supervisor restarts the pair so a clean replay from the verified predecessor can confirm
        again. The WAL and store helpers run with the saved binding read from the signer state."""
        helper = self.bin / "helper"
        calls = self.root / "helper_calls"
        helper.write_text("#!/usr/bin/env python3\nimport json,sys\n"
                          f"open({str(calls)!r},'a').write(json.dumps(sys.argv[1:])+'\\n')\n"
                          "if sys.argv[1]=='comet-head': print(json.dumps(dict(height=4,hash='AB'*32)))\n"
                          "elif sys.argv[1]=='wal-preflight': print(json.dumps(dict(eligible=False,repair=True,reason='torn',"
                          "startup=dict(marker=4,wal_length=120,wal_sha256='cd'*32))))\n"
                          "else: print(json.dumps(dict(binding=None)))\n")
        helper.chmod(0o755)
        binding = dict(marker="4", predecessor="AB" * 32, wal_length="100", wal_sha256="CD" * 32)
        self.state.write_text(json.dumps(dict(schema=2, chain_id=self.chain, height="5", round=0, step=2, replay=binding)))
        (self.home / "data/state.db").mkdir()
        (self.root / "comet_records").write_text("\n".join(json.dumps(dict(level="info", module="consensus", _msg=message))
                                                       for message in ("the WAL file is corrupted; attempting repair",
                                                                       "successful WAL repair")) + "\n")
        self.env["ETNA_SIGNER_HELPER_JSON"] = json.dumps([str(helper)])
        self.restart_over_settings('log_format = "json"')
        # This stand-in repeats the repair at every start: the supervisor restarts at most three
        # times, then leaves the height closed.
        restarts = lambda: Path(self.log.name).read_text().count("etna_supervisor_restarted_after_wal_repair")
        self.wait(lambda: restarts() == 3 and self.starts() == 5 and len(self.signers()) == 5)
        time.sleep(1)
        self.assertEqual((restarts(), self.starts()), (3, 5))
        preflights = [json.loads(line) for line in calls.read_text().splitlines() if '"wal-preflight"' in line]
        self.assertEqual(len(preflights), 4)
        self.assertEqual(preflights[0][preflights[0].index("--length") + 1], "100")
        self.assertEqual(preflights[0][preflights[0].index("--predecessor") + 1], "ab" * 32)
        report = self.channel_reply()["comet"]["replay"]
        self.assertEqual(report, dict(height=5, repair=True, binding=dict(marker=4, predecessor="ab" * 32, wal_length=100, wal_sha256="cd" * 32),
                                      startup=dict(marker=4, predecessor="ab" * 32, wal_length=120, wal_sha256="cd" * 32)))

    def stop_on_precommit(self):
        """Run the operator's stop-on-precommit command against the running supervisor."""
        return subprocess.Popen([sys.executable, str(ROOT / "script/etna_validator.py"), "stop-on-precommit",
                                 "--timeout", "20"], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def replayable_signer_state(self):
        """A signer state whose last signature, at height 5, carries a replay binding."""
        self.state.write_text(json.dumps(dict(height="5", replay=dict(
            marker="4", predecessor="ab" * 32, wal_length="10", wal_sha256="00" * 32))))

    def test_stop_on_precommit_refuses_when_replay_could_not_confirm_it(self):
        """RECOV-8.2-2: the stop arms only if the upgraded node could confirm the precommit by
        same-height replay. With the log observer off, stores the startup check cannot read, or a
        last signature without a replay binding, the supervisor refuses with the reason: the
        command exits 1, nothing is armed, the request is withdrawn and the pair keeps running."""
        for settings, replayable, reason in (
                ("", True, "the log observer is off (log_format is ['plain']"),
                ('log_format = "json"\ndb_backend = "pebbledb"', True, "reads only goleveldb stores"),
                ('log_format = "json"', False, "last signature carries no replay binding")):
            with self.subTest(reason=reason):
                starts = self.starts() + 1
                self.restart_over_settings(settings)
                self.wait(lambda: self.starts() == starts and len(self.signers()) == starts)
                if replayable:
                    self.replayable_signer_state()
                else:
                    self.state.write_text("authoritative HRS")
                command = self.stop_on_precommit()
                output, error = command.communicate(timeout=20)
                self.assertEqual(command.returncode, 1, error)
                self.assertRegex(error.decode(), r"^etna supervisor: stop-on-precommit refused: .*" + re.escape(reason))
                self.assertEqual(output, b"")
                self.assertEqual(self.channel_reply("stop")["stop"], False)
                self.assertFalse((self.store / "supervisor/stop-on-precommit").exists())
                self.assertRegex(Path(self.log.name).read_text(), "etna_supervisor_stop_on_precommit_refused: .*" + re.escape(reason))
                self.assertIsNone(self.proc.poll())
                self.assertEqual(self.starts(), starts)

    def test_stop_on_precommit_for_a_planned_upgrade(self):
        """START-10.1-14b, RECOV-8.2-2: the operator's stop-on-precommit command arms the signer
        through the channel, while the log observer follows Comet and the signer's last signature
        carries a replay binding; once the signer reports that its gate closed after a precommit,
        the supervisor waits for Comet to record and send it, stops Comet and then the signer,
        prints the outcome through the command and stays quiescent without restarting the pair."""
        self.restart_over_settings('log_format = "json"')
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        self.replayable_signer_state()
        command = subprocess.Popen([sys.executable, str(ROOT / "script/etna_validator.py"), "stop-on-precommit",
                                    "--timeout", "20"], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            self.wait(lambda: (self.store / "supervisor/stop-on-precommit").exists())
            self.wait(lambda: "etna_supervisor_stop_on_precommit_armed" in Path(self.log.name).read_text())
            self.assertEqual(self.channel_reply("stop")["stop"], True)
            # Only an armed supervisor accepts the signer's report, and only with its HRS.
            self.assertEqual(self.channel_reply(json.dumps(dict(op="stopped", height=5, round=1)))["stopped"], True)
            output, error = command.communicate(timeout=20)
        finally:
            if command.poll() is None:
                command.kill()
                command.wait()
        self.assertEqual(command.returncode, 0, error)
        self.assertEqual(json.loads(output), dict(stopped=True, height=5, round=1))
        # The first pair stopped with its supervisor; the second for the upgrade, Comet first.
        lifecycle = (self.root / "lifecycle").read_text().splitlines()
        self.assertEqual(lifecycle, ["comet_reaped", "signer_stopped"] * 2)
        self.assertFalse((self.store / "supervisor/stop-on-precommit").exists())
        time.sleep(1)
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertIsNone(self.proc.poll())
        self.assertIn("etna_supervisor_stopped_for_upgrade", Path(self.log.name).read_text())
        self.assertFalse((self.store / "validator-supervisor.halted").exists())

    def test_malformed_store_instance_is_refused_before_children(self):
        """A store instance file that is not exactly one ID, or not a regular file, refuses the
        start: it is never repaired or replaced."""
        path = self.home / "data/etna-store-instance"
        for content in ("short\n", "00112233445566778899AABBCCDDEEFF\n", "00112233445566778899aabbccddeeff",
                        "00112233445566778899aabbccddeeff\nextra\n"):
            with self.subTest(content=content):
                path.write_text(content)
                self.assert_refused_before_children("is not a store instance ID")
                self.assertEqual(path.read_text(), content)
        path.unlink()
        path.symlink_to(self.root / "elsewhere")
        self.assert_refused_before_children("not a regular file")

    def test_unsafe_supervisor_run_directory_is_refused(self):
        """The signer channel lives in a directory private to the supervisor: one open to others,
        or a symlink, is refused before any child starts."""
        run = self.store / "supervisor"
        run.chmod(0o755)
        self.assert_refused_before_children("must be a directory private to the supervisor")
        run.chmod(0o700)
        os.rmdir(run) if not any(run.iterdir()) else shutil.rmtree(run)
        target = self.root / "run-elsewhere"
        target.mkdir(mode=0o700)
        run.symlink_to(target)
        self.assert_refused_before_children("must be a directory private to the supervisor")

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

    def restart_over_settings(self, settings, p2p=VALIDATOR_P2P, env=None, **streams):
        """Stop the running supervisor and start one whose config.toml adds `settings` and, last,
        the P2P table `p2p`, with `env` added to its environment."""
        if self.proc.poll() is None:
            self.proc.terminate()
            self.assertEqual(self.proc.wait(timeout=5), 0)
        (self.home / "config/config.toml").write_text(self.base_config + settings + "\n" + p2p)
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")], env={**self.env, **(env or {})},
                                     **(streams or dict(stdout=self.log, stderr=self.log)))

    def assert_refused_before_children(self, message, settings="", p2p=VALIDATOR_P2P, env=None):
        """A starting supervisor exits 1 with message, with no live owner, before any child."""
        if self.proc.poll() is None:
            self.proc.terminate()
            self.assertEqual(self.proc.wait(timeout=5), 0)
        before = (self.starts(), len(self.signers()))
        self.restart_over_settings(settings, p2p=p2p, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            _, error = self.proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            _, error = self.proc.communicate(timeout=5)
        self.assertEqual(self.proc.returncode, 1, error)
        self.assertIn(message.encode(), error)
        self.assertNotIn(b"Traceback", error)
        self.assertEqual((self.starts(), len(self.signers())), before)

    def assert_settings_refused(self, path, *variants, p2p=VALIDATOR_P2P):
        """Each variant is refused, naming the pinned setting (START-10-6)."""
        for settings in variants:
            with self.subTest(settings=settings):
                self.assert_refused_before_children(f"requires CometBFT {path} ", settings, p2p=p2p)

    def test_refuses_adaptive_sync(self):
        """Consensus running while block sync catches up can sign votes for heights already
        decided, which signer state does not prevent (START-10-6). Viper folds key case and
        reads a literal dotted key, so those spellings reach the same setting."""
        self.assert_settings_refused("blocksync.adaptive_sync", "[blocksync]\nadaptive_sync = true",
                                     "[BlockSync]\nAdaptive_Sync = true", '"blocksync.adaptive_sync" = true')

    def test_refuses_double_sign_check_height(self):
        """A nonzero height stops a restarted Comet whose key signed recent blocks, which would
        defeat the automatic restart (START-10-6)."""
        self.assert_settings_refused("consensus.double_sign_check_height",
                                     "[consensus]\ndouble_sign_check_height = 10",
                                     "[CONSENSUS]\nDOUBLE_SIGN_CHECK_HEIGHT = 10")

    def test_refuses_non_default_block_time_tolerance(self):
        """Only the stock 60 s tolerance (CONS-3.4-12); Comet reads a bare integer as nanoseconds."""
        self.assert_settings_refused("consensus.block_time_tolerance",
                                     '[consensus]\nblock_time_tolerance = "2m0s"',
                                     "[consensus]\nblock_time_tolerance = 60")

    def test_accepts_stock_defaults(self):
        """setUp's config.toml leaves all three settings absent, and its pair started; spelled
        out at their stock values, with each spelling of 60 s, they start the pair as well."""
        for count, tolerance in enumerate(("1m0s", "60s", "1m"), start=2):
            with self.subTest(tolerance=tolerance):
                self.restart_over_settings("[blocksync]\nadaptive_sync = false\n[consensus]\n"
                                           f'double_sign_check_height = 0\nblock_time_tolerance = "{tolerance}"')
                self.wait(lambda: self.starts() == count and len(self.signers()) == count)

    def test_refuses_peer_exchange(self):
        """Peer exchange off (START-10-6 vector 6.n); its stock default is on, so it must be set."""
        self.assert_settings_refused("p2p.pex", "", p2p="[p2p]\nmax_num_inbound_peers = 0\n")
        self.assert_settings_refused("p2p.pex", "", p2p="[p2p]\npex = true\nmax_num_inbound_peers = 0\n")

    def test_refuses_outbound_peers_beyond_the_list(self):
        """Outbound peers are only persistent_peers: no seeds, no seed mode, no unsafe RPC that
        dials arbitrary peers, and the stock switch rather than the experimental libp2p one."""
        seeds = "[p2p]\npex = false\nmax_num_inbound_peers = 0\nseeds = \"aa@127.0.0.1:26656\"\n"
        self.assert_settings_refused("p2p.seeds", "", p2p=seeds)
        self.assert_settings_refused("p2p.seed_mode", "", p2p=VALIDATOR_P2P + "seed_mode = true\n")
        self.assert_settings_refused("p2p.libp2p.enabled", "", p2p=VALIDATOR_P2P + "[p2p.libp2p]\nenabled = true\n")
        self.assert_settings_refused("rpc.unsafe", "[rpc]\nunsafe = true")

    def test_refuses_inbound_slots(self):
        """max_num_inbound_peers = 0, so only unconditional peers connect inbound (vectors 6.q/6.r);
        its stock default is 40, so it must be set."""
        self.assert_settings_refused("p2p.max_num_inbound_peers", "", p2p="[p2p]\npex = false\n")
        self.assert_settings_refused("p2p.max_num_inbound_peers", "", p2p="[p2p]\npex = false\nmax_num_inbound_peers = 1\n")

    def test_unconditional_peers_are_exactly_the_listed_inbound_peers(self):
        """unconditional_peer_ids holds exactly ETNA_P2P_INBOUND_PEER_IDS: a missing, an extra and
        an unlisted ID are refused; the listed set, in any order and spacing, starts the pair."""
        listed = {"ETNA_P2P_INBOUND_PEER_IDS": "aa" * 20 + ", " + "bb" * 20}
        for ids in ("", "aa" * 20, "aa" * 20 + "," + "bb" * 20 + "," + "cc" * 20, "cc" * 20):
            with self.subTest(ids=ids):
                self.assert_refused_before_children("requires CometBFT p2p.unconditional_peer_ids ",
                                                    p2p=VALIDATOR_P2P + f'unconditional_peer_ids = "{ids}"\n', env=listed)
        self.assert_refused_before_children("requires CometBFT p2p.unconditional_peer_ids ",
                                            p2p=VALIDATOR_P2P + f'unconditional_peer_ids = "{"aa" * 20}"\n')
        self.restart_over_settings("", p2p=VALIDATOR_P2P + f'unconditional_peer_ids = " {"bb" * 20} ,{"aa" * 20}"\n', env=listed)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)

    def test_environment_overrides_are_checked(self):
        """CMT_* overrides are checked as stock Comet would apply them, in both spellings, and one
        that cannot be evaluated exactly is refused; an override that agrees starts the pair."""
        for env, path in (({"CMT_P2P_PEX": "true"}, "p2p.pex"), ({"CMTP2P_PEX": "1"}, "p2p.pex"),
                          ({"CMT_P2P_MAX_NUM_INBOUND_PEERS": "40"}, "p2p.max_num_inbound_peers"),
                          ({"CMT_P2P_SEEDS": "aa@127.0.0.1:26656"}, "p2p.seeds"),
                          ({"CMT_P2P_UNCONDITIONAL_PEER_IDS": "cc" * 20}, "p2p.unconditional_peer_ids"),
                          ({"CMT_RPC_UNSAFE": "TRUE"}, "rpc.unsafe"),
                          ({"CMT_BLOCKSYNC_ADAPTIVE_SYNC": "t"}, "blocksync.adaptive_sync"),
                          ({"CMT_CONSENSUS_DOUBLE_SIGN_CHECK_HEIGHT": "10"}, "consensus.double_sign_check_height"),
                          ({"CMT_CONSENSUS_BLOCK_TIME_TOLERANCE": "2m"}, "consensus.block_time_tolerance")):
            with self.subTest(env=env):
                self.assert_refused_before_children(f"requires CometBFT {path} ", env=env)
        for env in ({"CMT_P2P_PEX": "no"}, {"CMT_P2P_MAX_NUM_INBOUND_PEERS": "00"}):
            with self.subTest(env=env):
                self.assert_refused_before_children("cannot evaluate", env=env)
        self.assert_refused_before_children("outside ETNA_COMET_HOME", env={"CMTHOME": str(self.root / "other")})
        # An override that only restates config.toml cannot move it, and an empty one is ignored.
        self.restart_over_settings("", env={"CMT_P2P_PEX": "false", "CMTP2P_MAX_NUM_INBOUND_PEERS": "0", "CMT_RPC_UNSAFE": ""})
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)

    def test_comet_argv_flags_for_pinned_settings_are_refused(self):
        """A flag would beat config.toml and the environment, so an explicit Comet argv may not
        set a pinned or read setting, nor the signer listener the supervisor assigns."""
        for flag in ("--p2p.pex", "--p2p.pex=true", "--p2p.seeds=aa@127.0.0.1:1", "--rpc.unsafe",
                     "--consensus.double_sign_check_height=1", "--db_dir=elsewhere", "--priv_validator_laddr=tcp://127.0.0.1:1"):
            with self.subTest(flag=flag):
                self.assert_refused_before_children(f"refuses a --{flag.lstrip('-').split('=')[0]} flag",
                                                    env={"ETNA_COMET_COMMAND_JSON": json.dumps([str(self.bin / "cometbft"), "start", flag])})

    def pin_floor(self, floor):
        """The deployment manifest the next supervisor reads pins the timeout_commit floor `floor`."""
        write_manifest(self.manifest, self.bin / "cometbft", floor)

    def test_timeout_commit_below_the_floor_is_refused_in_config_toml(self):
        """A validator sets timeout_commit no lower than the floor the deployment manifest pins.
        Every config.toml spelling is a candidate: Viper folds key case and reads a literal dotted
        key, and Comet reads a bare integer as nanoseconds. One candidate below the floor, or one
        that is no Go duration, refuses the start."""
        self.pin_floor("4s")
        self.assert_settings_refused("consensus.timeout_commit",
                                     '[consensus]\ntimeout_commit = "3999ms"',
                                     '[CONSENSUS]\nTimeout_Commit = "3.5s"',
                                     '"consensus.timeout_commit" = "1s"',
                                     "[consensus]\ntimeout_commit = 3999999999",
                                     '"consensus.timeout_commit" = "1s"\n[consensus]\ntimeout_commit = "4s"',
                                     '[consensus]\ntimeout_commit = "4"',
                                     "[consensus]\ntimeout_commit = 4.0")

    def test_timeout_commit_below_the_floor_is_refused_in_env(self):
        """CMT_* overrides of timeout_commit are candidates too, in both spellings, even over a
        config.toml value at the floor; Viper hands their text to Go's duration parser, so a bare
        integer, which it refuses, is refused here as well."""
        self.pin_floor("4s")
        at_floor = '[consensus]\ntimeout_commit = "4s"'
        for env in ({"CMT_CONSENSUS_TIMEOUT_COMMIT": "1s"}, {"CMTCONSENSUS_TIMEOUT_COMMIT": "3.999s"},
                    {"CMT_CONSENSUS_TIMEOUT_COMMIT": "4000000000"}):
            with self.subTest(env=env):
                self.assert_refused_before_children("requires CometBFT consensus.timeout_commit at least 4s",
                                                    at_floor, env=env)

    def test_timeout_commit_below_the_floor_is_refused_as_argv_flag(self):
        """A flag would beat config.toml and the environment, so an explicit Comet argv may not
        set timeout_commit."""
        self.pin_floor("4s")
        for argv in (["--consensus.timeout_commit=1s"], ["--consensus.timeout_commit", "1s"]):
            with self.subTest(argv=argv):
                self.assert_refused_before_children(
                    "refuses a --consensus.timeout_commit flag",
                    env={"ETNA_COMET_COMMAND_JSON": json.dumps([str(self.bin / "cometbft"), "start", *argv])})

    def test_timeout_commit_at_and_above_the_floor_starts(self):
        """An effective timeout_commit equal to the floor, in any spelling of that duration, or
        above it starts the pair, and so does an override that is; an empty override is ignored."""
        self.pin_floor("4s")
        starts = 1
        for settings, env in (('[consensus]\ntimeout_commit = "4s"', {}),
                              ('[consensus]\ntimeout_commit = "4000ms"', {}),
                              ("[consensus]\ntimeout_commit = 4000000000", {}),
                              ('[CONSENSUS]\nTIMEOUT_COMMIT = "3s1000ms"', {}),
                              ('[consensus]\ntimeout_commit = "1m0s"', {}),
                              ('[consensus]\ntimeout_commit = "5s"', {"CMT_CONSENSUS_TIMEOUT_COMMIT": "4s"}),
                              ('[consensus]\ntimeout_commit = "4s"',
                               {"CMTCONSENSUS_TIMEOUT_COMMIT": "4.5s", "CMT_CONSENSUS_TIMEOUT_COMMIT": ""})):
            starts += 1
            with self.subTest(settings=settings, env=env):
                self.restart_over_settings(settings, env=env)
                self.wait(lambda: self.starts() == starts and len(self.signers()) == starts)

    def test_absent_timeout_commit_is_stock_one_second(self):
        """Without timeout_commit in config.toml or the environment Comet uses its stock 1 s: a 4 s
        floor refuses the start, a 1 s floor accepts it."""
        self.pin_floor("4s")
        self.assert_refused_before_children("requires CometBFT consensus.timeout_commit at least 4s, the deployment "
                                            "manifest's floor; stock default gives '1s'")
        self.pin_floor("1s")
        self.restart_over_settings("")
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)

    def test_schema_1_manifest_is_refused(self):
        """The deployment manifest is schema 2, which pins the validators' timeout_commit floor: an
        earlier schema 1 manifest, and a schema 2 one without a valid floor, are refused before any
        child starts."""
        manifest = json.loads(self.manifest.read_text())
        earlier = {key: value for key, value in manifest.items() if key != "configuration"}
        self.manifest.write_text(json.dumps(dict(earlier, schema=1)))
        self.assert_refused_before_children("is not a schema 2 manifest for CometBFT v0.40.0")
        for configuration in ({}, {"consensus.timeout_commit": "4s"}, {"consensus.timeout_commit": {}},
                              {"consensus.timeout_commit": {"min": "4"}}, {"consensus.timeout_commit": {"min": 4}}):
            with self.subTest(configuration=configuration):
                self.manifest.write_text(json.dumps(dict(manifest, configuration=configuration)))
                self.assert_refused_before_children("pins no valid CometBFT consensus.timeout_commit floor")
        self.manifest.write_text(json.dumps(earlier))
        self.assert_refused_before_children("pins no valid CometBFT consensus.timeout_commit floor")

    def test_pending_evidence_store_is_deleted_before_every_comet_start(self):
        """With Comet stopped, every start deletes <db_dir>/evidence.db and nothing else: the WAL,
        block and state stores, the dummy FilePV state, the app store and the signer's files stay
        (CONS-3.1-10, LIMIT-12-22)."""
        data = self.home / "data"
        kept = {data / "blockstore.db/000001.ldb": "blocks", data / "state.db/000001.ldb": "state",
                data / "cs.wal/wal": "wal", data / "priv_validator_state.json": "dummy",
                data / "evidence.db.keep": "neighbour"}
        def populate(marker):
            (data / "evidence.db/sub").mkdir(parents=True, exist_ok=True)
            (data / "evidence.db/000001.ldb").write_text(marker)
            (data / "evidence.db/sub/LOCK").write_text(marker)
        for path, text in kept.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        populate("pending before restart")
        self.restart_over_settings("")
        self.wait(lambda: self.starts() == 2)
        self.assertFalse(os.path.lexists(data / "evidence.db"))
        # A guarded restart after a refusal deletes the store its Comet wrote again.
        populate("pending while running")
        self.publish(1, self.session)
        self.wait(lambda: self.starts() == 3)
        self.assertFalse(os.path.lexists(data / "evidence.db"))
        self.assertEqual({path: path.read_text() for path in kept}, kept)
        self.assertEqual((self.state.read_text(), self.key.read_text()), ("authoritative HRS", "existing key"))
        self.assertIn("etna_supervisor_pending_evidence_removed", Path(self.log.name).read_text(errors="replace"))
        # The store follows db_dir, and a symlinked store is refused rather than followed.
        elsewhere = self.home / "elsewhere"
        (elsewhere / "evidence.db").mkdir(parents=True)
        self.restart_over_settings('db_dir = "elsewhere"')
        self.wait(lambda: self.starts() == 4)
        self.assertFalse(os.path.lexists(elsewhere / "evidence.db"))
        target = self.root / "outside-evidence"
        target.mkdir()
        (target / "keep").write_text("outside")
        (data / "evidence.db").symlink_to(target, target_is_directory=True)
        self.assert_refused_before_children("must not be a symlink")
        self.assertEqual((target / "keep").read_text(), "outside")

    def test_comet_executable_must_match_the_manifest(self):
        """Only the executable whose digest the deployment manifest pins for this platform
        starts (CONS-3.1-1 vector 1.f), at startup and at every later Comet start."""
        manifest = json.loads(self.manifest.read_text())
        platform = next(iter(manifest["platforms"]))
        other = dict(manifest, platforms={platform: dict(sha256="00" * 32)})
        self.manifest.write_text(json.dumps(other))
        self.assert_refused_before_children("not the " + platform + " digest")
        unsupported = dict(manifest, platforms={}, unsupported_platforms={platform: "no official executable here"})
        self.manifest.write_text(json.dumps(unsupported))
        self.assert_refused_before_children("no official executable here (CONS-3.1-1)")
        for broken in (dict(manifest, release="v0.38.0"), dict(manifest, source_commit="00" * 20)):
            self.manifest.write_text(json.dumps(broken))
            self.assert_refused_before_children("is not a schema 2 manifest for CometBFT v0.40.0")
        self.assert_refused_before_children("deployment manifest", env={"ETNA_COMET_MANIFEST": str(self.root / "absent.json")})
        self.manifest.write_text(json.dumps(manifest))
        self.restart_over_settings("")
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        # The executable changes while the supervisor runs: the next Comet start is refused.
        comet = self.bin / "cometbft"
        comet.write_text(comet.read_text() + "# rebuilt\n")
        self.publish(1, self.session)
        self.assertEqual(self.proc.wait(timeout=10), 1)
        self.assertIn("the deployment manifest pins (CONS-3.1-1)", Path(self.log.name).read_text(errors="replace"))
        self.assertEqual((self.starts(), len(self.signers())), (2, 2))
        self.assertFalse(any(self.alive(signer["pid"]) for signer in self.signers()))

    def test_comet_runs_the_sealed_copy_it_hashed(self):
        """Every Comet start execs the sealed copy of the executable that its digest check hashed,
        through the copy's descriptor, never the path again (CONS-3.1-1): the stub, a script,
        names that descriptor as itself, at the first start and after a guarded restart."""
        self.publish(1, self.session)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        for comet in self.comets():
            self.assertRegex(comet["script"], r"^/proc/self/fd/\d+$")

    def test_comet_config_is_checked_again_before_every_comet_start(self):
        """The effective Comet configuration is read and checked again before every Comet start,
        not only when the supervisor starts (START-10-6): a pinned setting moved in config.toml
        while the pair runs stops the next start before any child runs, naming the setting, and
        signing stays closed."""
        (self.home / "config/config.toml").write_text(self.base_config + "[blocksync]\nadaptive_sync = true\n" + VALIDATOR_P2P)
        self.publish(1, self.session)
        self.assertEqual(self.proc.wait(timeout=10), 1)
        self.assertIn("requires CometBFT blocksync.adaptive_sync false", Path(self.log.name).read_text(errors="replace"))
        self.assertEqual((self.starts(), len(self.signers())), (1, 1))
        self.assertFalse(any(self.alive(signer["pid"]) for signer in self.signers()))

    def test_missed_first_connection_restarts_the_pair_without_a_latch(self):
        """Comet exits when the signer misses the 3 s accept of its first GetPubKey; the
        supervisor starts the pair again with the same signer state and no latch (START-10-6).
        Once the signer connects, the pair stays up."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        (self.root / "signer_skip_connect").touch()
        (self.root / "comet_exit_on_start").touch()
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() >= 4 and len(self.signers()) >= 4, timeout=10)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertFalse((self.store / "validator-supervisor.signer-unsafe").exists())
        self.assertIn("etna_supervisor_missed_first_connection", Path(self.log.name).read_text(errors="replace"))
        self.assertTrue(all(signer["alive"] == [] for signer in self.signers()[1:]))
        (self.root / "signer_skip_connect").unlink()
        (self.root / "comet_exit_on_start").unlink()
        self.wait(lambda: self.alive(int((self.root / "comet.pid").read_text())), timeout=10)
        settled = self.starts()
        time.sleep(1.5)
        self.assertEqual(self.starts(), settled)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_bare_tcp_signer_transport_is_refused(self):
        """Bare tcp://, whose stock listener generates a fresh identity at every start, and any
        other scheme are refused before any child starts (START-10-6 vector 6.p)."""
        for laddr in ("tcp://127.0.0.1:26659", "127.0.0.1:26659", ""):
            with self.subTest(laddr=laddr):
                self.base_config = f'priv_validator_laddr = "{laddr}"\n'
                self.assert_refused_before_children("priv_validator_laddr")

    def test_run_directory_open_to_others_is_refused(self):
        """The socket's directory restricts access to the bound Comet process and the signer:
        a run/ open to the group or others, where another user could replace the socket, is
        refused (START-10-6 vector 6.p)."""
        self.stop_supervisor()
        (self.home / "run").chmod(0o750)
        self.assert_misconfigured_run_refused(f"{self.home.resolve() / 'run'} must be private to the Comet UID (mode 0700), not 0750")


class NoiseSupervisorTests(SupervisorLifecycle, unittest.TestCase):
    """Lifecycle gates over stock Noise with both peer IDs pinned (START-10-6): Comet listens on
    its configured noise://<signer-peer-id>@<ip>:<port>, and the signer dials it with its own
    transport key, pinning the peer ID of Comet's persistent node key."""

    fresh_listener_per_pair = False

    def configure_transport(self):
        self.transport_key = self.root / "signer-transport.json"
        self.signer_peer = write_node_key(self.transport_key)
        self.comet_peer = write_node_key(self.home / "config/node_key.json")
        self.laddr = f"noise://{self.signer_peer}@127.0.0.1:26659"
        (self.home / "config/config.toml").write_text(f'priv_validator_laddr = "{self.laddr}"\n')
        self.transport_env = dict(ETNA_SIGNER_TRANSPORT_KEY=str(self.transport_key))

    def comet_listener(self, index):
        return self.laddr

    def signer_address(self, index):
        argv = self.signers()[index]["argv"]
        address = argv[argv.index("--comet-signer-addr") + 1]
        self.assertEqual(address, f"noise://{self.comet_peer}@127.0.0.1:26659")
        return address

    def transport_args(self, index):
        return ["--transport-key", str(self.transport_key.resolve())]

    def test_every_pair_pins_both_noise_peer_ids(self):
        """Every pair's Comet listens on the configured address and its signer pins Comet's node
        key with its own transport key, also after a guarded restart."""
        self.publish(1, self.session)
        self.wait(lambda: self.starts() == 2 and len(self.signers()) == 2)
        for index in (0, 1):
            self.assertEqual(self.comets()[index]["argv"][-2:], ["--priv_validator_laddr", self.laddr])
            argv = self.signers()[index]["argv"]
            self.assertEqual(argv[argv.index("--transport-key") + 1], str(self.transport_key.resolve()))
            self.signer_address(index)

    def test_noise_configuration_is_refused_before_children(self):
        """A missing or mismatched signer transport key, a key inside the Comet home, a missing
        Comet node key, which stock Comet would replace with a fresh identity, and a malformed
        address are refused before any child starts."""
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=5), 0)
        node_key = self.home / "config/node_key.json"
        other = self.root / "other-transport.json"
        write_node_key(other)
        inside = self.home / "transport.json"
        inside.write_text(self.transport_key.read_text())
        cases = [
            (dict(ETNA_SIGNER_TRANSPORT_KEY=""), "needs ETNA_SIGNER_TRANSPORT_KEY", None),
            (dict(ETNA_SIGNER_TRANSPORT_KEY=str(other)), "is not the signer", None),
            (dict(ETNA_SIGNER_TRANSPORT_KEY=str(inside)), "outside the Comet home", None),
            ({}, "Comet node key", "move-node-key"),
            ({}, "IP literal", f'priv_validator_laddr = "noise://{self.signer_peer}@localhost:26659"\n'),
            ({}, "IP literal", f'priv_validator_laddr = "noise://127.0.0.1:26659"\n'),
        ]
        for env, message, change in cases:
            with self.subTest(message=message, change=change):
                config = self.home / "config/config.toml"
                saved = config.read_text()
                if change == "move-node-key":
                    node_key.rename(self.root / "node_key.saved")
                elif change:
                    config.write_text(change + VALIDATOR_P2P)
                try:
                    refused = subprocess.run(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                             env={**self.env, **env}, capture_output=True, timeout=5)
                finally:
                    config.write_text(saved)
                    if change == "move-node-key":
                        (self.root / "node_key.saved").rename(node_key)
                self.assertEqual(refused.returncode, 1, refused.stderr)
                self.assertIn(message.encode(), refused.stderr)
                self.assertEqual((self.starts(), len(self.signers())), (1, 1))


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
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "unix://run/signer.sock"\n' + VALIDATOR_P2P)
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
            # Root signer: connect to Comet's listener, as the real signer dials it, and publish
            # the connection.
            "signer": ('import json,os,socket,sys,time\n'
                       'argv=sys.argv[1:]\n'
                       'open(os.environ["SIGNERS"],"a").write(json.dumps(dict(pid=os.getpid(),argv=argv))+"\\n")\n'
                       'path=argv[argv.index("--comet-signer-addr")+1].removeprefix("unix://")\n'
                       'while True:\n'
                       ' peer=socket.socket(socket.AF_UNIX)\n'
                       ' try: peer.connect(path); break\n'
                       ' except OSError: peer.close(); time.sleep(.05)\n'
                       'events=argv[argv.index("--denial-file")+1]\n'
                       'd=os.open(events+".tmp",os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)\n'
                       'os.write(d,json.dumps(dict(sequence=0,session_id="")).encode());os.close(d);os.replace(events+".tmp",events)\n'
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
                        ETNA_COMET_MANIFEST=str(self.root / "comet-manifest.json"),
                        SIGNERS=str(self.root / "signers"), PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        write_manifest(self.root / "comet-manifest.json", self.bin / "cometbft")
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

    def test_full_node_launcher_execs_stock_comet_and_refuses_a_validator_config(self):
        """The full-node launcher execs `cometbft start --home <home>` as is, and refuses a Comet
        config that names a priv_validator_laddr; it reads nothing from the app store."""
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            home = base / "ready/comet"
            (home / "config").mkdir(parents=True)
            argv, stub = base / "argv", base / "cometbft"
            stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "$0" "$@" > "{argv}"\n')
            stub.chmod(0o700)
            write_manifest(base / "comet-manifest.json", stub)
            env = dict(ETNA_COMET_HOME=str(home), ETNA_COMET_BIN=str(stub), PATH=os.defpath,
                       ETNA_COMET_MANIFEST=str(base / "comet-manifest.json"))
            launcher = [sys.executable, str(ROOT / "script/start_etna_full_node.py")]
            (home / "config/config.toml").write_text('priv_validator_laddr = ""\n')
            proc = subprocess.run(launcher, env=env, capture_output=True, timeout=30)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            # The shell runs the sealed copy the launcher hashed, which it names as its script.
            started = argv.read_text().splitlines()
            self.assertRegex(started[0], r"^/proc/self/fd/\d+$")
            self.assertEqual(started[1:], ["start", "--home", str(home)])
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
            write_manifest(base / "comet-manifest.json", stub)
            env = dict(ETNA_COMET_HOME=str(home), ETNA_COMET_BIN=str(stub), ETNA_COMET_UID=str(uid),
                       ETNA_COMET_GID=str(gid), PATH=os.defpath, ETNA_COMET_MANIFEST=str(base / "comet-manifest.json"))
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
    def test_observation_in_control_schema_1_is_refused(self):
        """The trust-control wire is version 2, whose recovery origin carries fallback_keys_hash
        in place of version 1's committee hash: the supervisor asks in version 2 and refuses a
        version-1 reply."""
        runtime = object.__new__(supervisor_module("etna_control_schema").Supervisor)
        requests = []
        with tempfile.TemporaryDirectory() as directory, socket.socket(socket.AF_UNIX) as server:
            runtime.store = Path(directory)
            server.bind(str(runtime.store / "checkpoint-trust.sock"))
            server.listen()

            def answer(version):
                peer, _ = server.accept()
                with peer:
                    requests.append(json.loads(peer.makefile("rb").readline()))
                    reply = dict(schema_version=version, session_id="session", recovery_origin=None)
                    peer.sendall((json.dumps(reply) + "\n").encode())

            for version in (2, 1):
                thread = threading.Thread(target=answer, args=(version,))
                thread.start()
                if version == 2:
                    self.assertEqual(runtime.observe()["schema_version"], 2)
                else:
                    with self.assertRaisesRegex(ValueError, "schema"):
                        runtime.observe()
                thread.join()
        self.assertEqual([request["schema_version"] for request in requests], [2, 2])

    def supersession_with_children(self, directory, signer_status):
        """Create a superseded app store and real children with controlled exit status."""
        spec = importlib.util.spec_from_file_location("etna_supersession_stop", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        store = Path(directory)
        runtime = object.__new__(module.Supervisor)
        runtime.store, runtime.chain = store, "old-chain"
        runtime.state = store / "hrs.json"
        runtime.domains_log = store / "domains/domains.log"
        runtime.domains_log.parent.mkdir()
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
                schema_version=2, session_id="old-session", phase="halted", chain_id="old-chain",
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
            self.assertIn(b"unsafe signing state", (runtime.store / "validator-supervisor.signer-unsafe").read_bytes())
            self.assertIn(b"unsafe signing state", (runtime.store / "domains/old-chain.signer-unsafe").read_bytes())
            for name, raw in preserved.items():
                self.assertEqual((runtime.store / name).read_bytes(), raw)

    def bare_runtime(self, directory):
        """A supervisor without children over its own app store, state directory and domains log."""
        spec = importlib.util.spec_from_file_location("etna_bare_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        base = Path(directory)
        runtime = object.__new__(module.Supervisor)
        runtime.store, runtime.chain = base / "app", "etna-test"
        runtime.state, runtime.domains_log = base / "hrs/etna-test.json", base / "domains/domains.log"
        for path in (runtime.store, runtime.state.parent, runtime.domains_log.parent):
            path.mkdir()
        runtime.latch = runtime.store / "validator-supervisor.halted"
        runtime.signer = runtime.comet = None
        runtime.crashes = []
        return runtime

    def test_unsafe_exits_write_the_marker_before_the_restart_decision(self):
        """Exit 3, a fence and a forced kill make the app-store record and the marker beside the
        domains log durable before the supervisor decides against a restart; an ordinary crash
        writes neither and restarts (RECOV-8.2-3, SYNC-9-14)."""
        for case in ("exit-3", "fence", "killed", "crash"):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                runtime = self.bare_runtime(directory)
                record = runtime.store / "validator-supervisor.signer-unsafe"
                marker = runtime.domains_log.parent / "etna-test.signer-unsafe"
                decisions = []
                runtime.halt = lambda reason: decisions.append(("halt", record.exists(), marker.exists()))
                runtime.start = lambda await_trust=False: decisions.append(("restart", record.exists(), marker.exists()))
                runtime.stop = lambda: None
                if case == "fence":
                    runtime.state.with_name(runtime.state.name + ".uncertain").write_text("fsync failed")
                if case == "killed":
                    runtime.signer_killed = True
                with contextlib.redirect_stdout(io.StringIO()):
                    runtime.signer_exited(3 if case == "exit-3" else 1)
                if case == "crash":
                    self.assertEqual(decisions, [("restart", False, False)])
                else:
                    self.assertEqual(decisions, [("halt", True, True)])
                    self.assertEqual(marker.read_text(), record.read_text())

    def test_noise_peer_id_matches_the_signer(self):
        """The supervisor's libp2p peer ID derivation matches the signer's (Go) for one vector."""
        module = supervisor_module()
        with tempfile.TemporaryDirectory() as directory:
            key = Path(directory) / "key.json"
            key.write_text(PEER_ID_VECTOR[0])
            self.assertEqual(module.ed25519_peer_id(key, "vector"), PEER_ID_VECTOR[1])
            key.write_text(PEER_ID_VECTOR[0].replace("PrivKeyEd25519", "PrivKeySecp256k1"))
            with self.assertRaisesRegex(ValueError, "not a stock Ed25519 node key"):
                module.ed25519_peer_id(key, "vector")

    def test_shipped_manifest_pins_the_official_executable(self):
        """comet-manifest.json names CometBFT v0.40.0 at its source commit; for linux/amd64 the
        official image's executable, with the digests the Dockerfile verifies; linux/arm64 as
        unsupported with its reason; and the configuration the supervisor enforces (CONS-3.1-1)."""
        module = supervisor_module()
        manifest = json.loads((ROOT / "comet-manifest.json").read_text())
        self.assertEqual((manifest["schema"], manifest["release"], manifest["source_commit"]),
                         (module.COMET_MANIFEST_SCHEMA, module.COMET_RELEASE, module.COMET_SOURCE_COMMIT))
        self.assertEqual(set(manifest["platforms"]), {"linux/amd64"})
        amd64 = manifest["platforms"]["linux/amd64"]
        dockerfile = (ROOT / "Dockerfile").read_text()
        self.assertIn(f'RUN echo "{amd64["sha256"]}  /usr/bin/cometbft" | sha256sum -c -', dockerfile)
        self.assertIn("cometbft/cometbft:v0.40.0@" + amd64["artifact"]["platform_manifest"] + " AS comet-amd64", dockerfile)
        self.assertTrue(amd64["artifact"]["image"].endswith("@sha256:0703fb881dac0987c8e41a5810cc09dbcb503bb59ac91705f6936c4b972ac798"))
        self.assertIn(amd64["artifact"]["image"].removeprefix("docker.io/"), (ROOT / "script/build_stock_comet.sh").read_text())
        self.assertEqual(amd64["build"]["build_info"]["vcs.revision"], module.COMET_SOURCE_COMMIT)
        self.assertIn(amd64["sha256"], manifest["unsupported_platforms"]["linux/arm64"])
        configuration = manifest["configuration"]
        for path, (default, kind, requirement, check) in module.PINNED_SETTINGS.items():
            self.assertIn(path, configuration)
            if not isinstance(configuration[path], str) or kind != "str":
                self.assertTrue(check(configuration[path], []), path)
        self.assertEqual(configuration["db_backend"], list(module.COMET_DB_BACKENDS))

    def test_shipped_manifest_pins_the_timeout_commit_floor(self):
        """comet-manifest.json, a schema 2 deployment manifest, pins the validators' timeout_commit
        floor for the 4 s block-time target, and the supervisor reads it as 4 s."""
        module = supervisor_module("etna_shipped_floor")
        manifest = json.loads((ROOT / "comet-manifest.json").read_text())
        self.assertEqual((manifest["schema"], module.COMET_MANIFEST_SCHEMA), (2, 2))
        self.assertEqual(manifest["configuration"]["consensus.timeout_commit"], {"min": "4s"})
        self.assertEqual(module.timeout_commit_floor(manifest), ("4s", 4 * 10**9))

    def test_durations_follow_go_parsing(self):
        """Comet reads a duration setting's string with Go's time.ParseDuration and a bare TOML
        integer as nanoseconds; the supervisor evaluates both the same way, float64 rounding of
        long fractions included (mostly Go's own vectors), and nothing else."""
        module = supervisor_module("etna_durations")
        second, minute, hour = 10**9, 60 * 10**9, 3600 * 10**9
        largest = (1 << 63) - 1
        for text, nanoseconds in (
                ("0", 0), ("5s", 5 * second), ("30s", 30 * second), ("1478s", 1478 * second),
                ("-5s", -5 * second), ("+5s", 5 * second), ("-0", 0), ("+0", 0),
                ("5.0s", 5 * second), ("5.6s", 5_600_000_000), ("5.s", 5 * second), (".5s", 500_000_000),
                ("1.0s", second), ("1.00s", second), ("1.004s", 1_004_000_000), ("1.0040s", 1_004_000_000),
                ("100.00100s", 100_001_000_000), ("10ns", 10), ("11us", 11_000), ("12\u00b5s", 12_000),
                ("12\u03bcs", 12_000), ("13ms", 13_000_000), ("14s", 14 * second), ("15m", 15 * minute),
                ("16h", 16 * hour), ("3h30m", 3 * hour + 30 * minute), ("10.5s4m", 4 * minute + 10_500_000_000),
                ("-2m3.4s", -(2 * minute + 3_400_000_000)),
                ("1h2m3s4ms5us6ns", hour + 2 * minute + 3 * second + 4_005_006),
                ("39h9m14.425s", 39 * hour + 9 * minute + 14_425_000_000), ("52763797000ns", 52763797000),
                ("0.3333333333333333333h", 20 * minute), ("9007199254740993ns", (1 << 53) + 1),
                ("9223372036854775807ns", largest), ("9223372036854775.807us", largest),
                ("9223372036s854ms775us807ns", largest), ("-9223372036854775808ns", -(1 << 63)),
                ("-9223372036854775.808us", -(1 << 63)), ("-9223372036s854ms775us808ns", -(1 << 63)),
                ("-2562047h47m16.854775808s", -(1 << 63)), ("0.100000000000000000000h", 6 * minute),
                ("0.830103483285477580700h", 49 * minute + 48 * second + 372539827),
                # Checked against Go: float64 rounding lands just below 4 s, and Go sums the
                # components in a uint64, so two 2^63 ns components wrap to zero.
                ("0.0666666666666666667m", 3_999_999_999), ("9223372036854775808ns9223372036854775808ns60s", minute),
                (4_000_000_000, 4 * second), (0, 0)):
            with self.subTest(value=text):
                self.assertEqual(module.duration(text), nanoseconds)
        for value in ("", "3", "-", "s", ".", "-.", ".s", "+.s", "1d", "\x85\x85", "\xffff",
                      "hello \xffff world", "\ufffd", "\ufffd hello \ufffd world", "9223372036854775810ns",
                      "9223372036854775808ns", "-9223372036854775809ns", "9223372036854776us", "3000000h",
                      "9223372036854775.808us", "9223372036854ms775us808ns", " 4s", "4s ", "4 s", "4S", "4s\udcff",
                      True, 4.0, None, ["4s"], {"min": "4s"}):
            with self.subTest(value=value):
                self.assertIsNone(module.duration(value))

    def test_unreadable_unsafe_evidence_counts_as_present(self):
        """A record or marker whose absence cannot be established (EACCES here, or EIO) counts as
        present, as a fence does: only ENOENT proves absence (RECOV-8.2-3)."""
        if os.geteuid() == 0:
            self.skipTest("root bypasses directory-search permission faults")
        for unreadable in ("app store", "domains log directory"):
            with self.subTest(unreadable=unreadable), tempfile.TemporaryDirectory() as directory:
                runtime = self.bare_runtime(directory)
                halts = []
                runtime.halt = halts.append
                path = runtime.store if unreadable == "app store" else runtime.domains_log.parent
                path.chmod(0)
                try:
                    self.assertTrue(runtime.signer_unsafe(None))
                    self.assertTrue(runtime.refuse_unsafe_start())
                finally:
                    path.chmod(0o700)
                self.assertEqual(len(halts), 1)
                self.assertIn("signer-unsafe record or marker", halts[0])

    def test_comet_identity_keeps_privileged_group_drop_and_same_uid_native_path(self):
        spec = importlib.util.spec_from_file_location("etna_identity_supervisor", ROOT / "script/etna_validator.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runtime = object.__new__(module.Supervisor)
        runtime.home, runtime.unix_run = Path("/private/runtime"), None
        runtime.comet_command, runtime.comet_listener = ["/cometbft", "start"], "unix:///private/runtime/run/signer.sock"
        runtime.child_options = lambda: dict(pass_fds=())
        runtime.observer_reason, runtime.preflight = "log observer disabled", None
        for current_uid, current_gid, uid, gid, expected in [
                (501, 20, 501, 20, {}),
                (0, 0, 10001, 10001, dict(user=10001, group=10001, extra_groups=[])),
                (501, 20, 10001, 10001, dict(user=10001, group=10001, extra_groups=[]))]:
            with self.subTest(current_uid=current_uid, uid=uid), patch.dict(os.environ, {"ETNA_COMET_UID":str(uid), "ETNA_COMET_GID":str(gid)}), patch.object(module.os, "geteuid", return_value=current_uid), patch.object(module.os, "getegid", return_value=current_gid), patch.object(module.subprocess, "Popen") as spawn:
                runtime.start_comet("00112233445566778899aabbccddeeff", 7)
                self.assertEqual(spawn.call_args.kwargs, dict(executable="/proc/self/fd/7", cwd=runtime.home,
                                                              pass_fds=(7,), **expected))

    def test_consensus_log_level_follows_stock_parsing(self):
        module = supervisor_module("etna_log_level")
        for value, level in [("info", "info"), ("debug", "debug"), ("error", "error"),
                             ("consensus:info,*:error", "info"), ("*:error", "error"),
                             ("consensus:error,*:info", "error"), ("p2p:debug", "info"),
                             ("consensus:none", "none"), ("consensus:loud", None), ("a:b:c", None)]:
            with self.subTest(value=value):
                self.assertEqual(module.consensus_log_level(value), level)

    def test_observer_refusal_reports_the_failed_setting(self):
        """START-10-6: the effective configuration, overrides included, must select the pinned JSON
        format and let the consensus module emit Info and Error; the failed setting is reported."""
        module = supervisor_module("etna_observer_refusal")
        runtime = object.__new__(module.Supervisor)
        runtime.comet_command = ["/cometbft", "start"]
        for config, env, argv, refusal in [
                ({}, {}, [], "log_format is ['plain']"),
                ({"log_format": ["json"]}, {}, [], None),
                ({"log_format": ["json"], "log_level": ["consensus:info,*:error"]}, {}, [], None),
                ({"log_format": ["json"], "log_level": ["*:error"]}, {}, [], "does not emit the consensus module's Info"),
                ({"log_format": ["json"], "log_level": ["consensus:error"]}, {}, [], "does not emit"),
                ({"log_format": ["json"]}, {"CMT_LOG_FORMAT": "plain"}, [], "log_format is"),
                ({"log_format": ["json"]}, {"CMT_LOG_LEVEL": "warn"}, [], "does not emit"),
                ({"log_format": ["json"]}, {}, ["--log_level=error"], "argv sets --log_level"),
                ({"log_format": ["json"]}, {}, ["--log_format", "plain"], "argv sets --log_format")]:
            with self.subTest(config=config, env=env, argv=argv), patch.dict(os.environ, env):
                for name in [name for name in os.environ if name.startswith("CMT") and name not in env]:
                    os.environ.pop(name)
                runtime.config_settings = config
                runtime.comet_command = ["/cometbft", "start", *argv]
                reason = runtime.observer_refusal()
                if refusal is None:
                    self.assertIsNone(reason)
                else:
                    self.assertIn(refusal, reason)

    def test_log_observer_follows_replay_attempts_losslessly(self):
        """Each record already written is consumed before a snapshot; Catchup opens an attempt,
        Replay: Done ends it, corruption, repair and replay-error records cancel it and taint the
        process, a second Catchup in one process taints it, other modules and malformed lines are
        ignored, committed block hashes are kept, and the pipe's end taints too."""
        module = supervisor_module("etna_log_observer")
        read_end, write_end = os.pipe()
        observer = module.LogObserver(read_end)
        def emit(*records, raw=b""):
            os.write(write_end, b"".join(json.dumps(record).encode() + b"\n" for record in records) + raw)
        consensus = lambda message, **fields: dict(level="info", module="consensus", _msg=message, **fields)
        with patch.object(module.LogObserver, "forward", staticmethod(lambda line: None)):
            emit(consensus("finalizing commit of block", height=4, hash="ABCD"), dict(level="info", module="p2p", _msg="Catchup by replaying consensus messages", height=9), raw=b"not json\n")
            self.assertEqual(observer.snapshot(), dict(attempt=0, open=False, height=0, tainted=False, repaired=False))
            self.assertEqual(observer.committed_hash(4), "abcd")
            emit(consensus("Catchup by replaying consensus messages", height=5))
            self.assertEqual(observer.snapshot(), dict(attempt=1, open=True, height=5, tainted=False, repaired=False))
            emit(consensus("Replay: Done"))
            self.assertEqual(observer.snapshot()["open"], False)
            emit(consensus("the WAL file is corrupted; attempting repair"), consensus("successful WAL repair"))
            self.assertEqual(observer.snapshot(), dict(attempt=1, open=False, height=5, tainted=True, repaired=True))
            emit(consensus("Catchup by replaying consensus messages", height=5))
            self.assertEqual(observer.snapshot()["open"], False)
        second_read, second_write = os.pipe()
        other = module.LogObserver(second_read)
        with patch.object(module.LogObserver, "forward", staticmethod(lambda line: None)):
            os.write(second_write, json.dumps(consensus("error on catchup replay; proceeding to start state anyway")).encode() + b"\n")
            self.assertEqual(other.snapshot()["tainted"], True)
            os.close(second_write)
            time.sleep(.3)
            self.assertEqual(other.snapshot()["tainted"], True)
        os.close(write_end)

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
